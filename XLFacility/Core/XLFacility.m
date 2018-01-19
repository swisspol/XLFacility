/*
 Copyright (c) 2014, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if !__has_feature(objc_arc)
#error XLFacility requires ARC
#endif

#import <pthread.h>
#import <objc/runtime.h>
#import <execinfo.h>
#import <netdb.h>

#import "XLStandardLogger.h"
#import "XLFunctions.h"
#import "XLFacilityPrivate.h"

#define kMinLogLevelEnvironmentVariable "XLFacilityMinLogLevel"

#define kFileDescriptorCaptureBufferSize 1024
#define kCapturedNSLogPrefix @"(NSLog) "

typedef id (*ExceptionInitializerIMP)(id self, SEL cmd, NSString* name, NSString* reason, NSDictionary* userInfo);

XLLogLevel XLMinLogLevel = 0;
XLFacility* XLSharedFacility = nil;
int XLOriginalStdOut = 0;
int XLOriginalStdErr = 0;

NSString* const XLFacilityTag_Internal = @"xlfacility.internal";
NSString* const XLFacilityTag_CapturedStdOut = @"xlfacility.captured-stdout";
NSString* const XLFacilityTag_CapturedStdErr = @"xlfacility.captured-stderr";
NSString* const XLFacilityTag_UncaughtExceptions = @"xlfacility.uncaught-exceptions";
NSString* const XLFacilityTag_InitializedExceptions = @"xlfacility.initialized-exceptions";

static NSUncaughtExceptionHandler* _originalExceptionHandler = NULL;
static ExceptionInitializerIMP _originalExceptionInitializerIMP = NULL;

static dispatch_source_t _stdOutCaptureSource = NULL;
static dispatch_source_t _stdErrCaptureSource = NULL;
static NSData* _newlineData = nil;

@implementation XLFacility {
  dispatch_queue_t _lockQueue;
  dispatch_group_t _syncGroup;
  NSMutableSet* _loggers;
  pthread_key_t _pthreadKey;
}

static void _ExitHandler() {
  @autoreleasepool {
    [XLSharedFacility _closeAllLoggers];
  }
}

// Keep around copies of the original stdout and stderr file descriptors from when process starts in cases they are replaced later on
+ (void)load {
  @autoreleasepool {
    XLOriginalStdOut = dup(STDOUT_FILENO);
    XLOriginalStdErr = dup(STDERR_FILENO);

#if DEBUG
    XLMinLogLevel = kXLLogLevel_Debug;
#else
    XLMinLogLevel = kXLLogLevel_Info;
#endif
    const char* logLevel = getenv(kMinLogLevelEnvironmentVariable);
    if (logLevel) {
      XLMinLogLevel = atoi(logLevel);
    }

    XLSharedFacility = [[XLFacility alloc] init];

    atexit(_ExitHandler);
  }
}

+ (XLFacility*)sharedFacility {
  return XLSharedFacility;
}

- (id)init {
  if ((self = [super init])) {
    _minCaptureCallstackLevel = kXLLogLevel_Exception;
    _minInternalLogLevel = XLMinLogLevel;

    _lockQueue = dispatch_queue_create(XL_DISPATCH_QUEUE_LABEL, DISPATCH_QUEUE_SERIAL);
    _syncGroup = dispatch_group_create();
    _loggers = [[NSMutableSet alloc] init];
    pthread_key_create(&_pthreadKey, NULL);

    if (isatty(XLOriginalStdErr)) {
      [self addLogger:[XLStandardLogger sharedErrorLogger]];
    }
  }
  return self;
}

- (XLLogLevel)minLogLevel {
  return XLMinLogLevel;
}

- (void)setMinLogLevel:(XLLogLevel)level {
  XLMinLogLevel = level;
}

- (NSSet*)loggers {
  __block NSSet* loggers;
  dispatch_sync(_lockQueue, ^{
    loggers = [_loggers copy];
  });
  return loggers;
}

- (BOOL)addLogger:(XLLogger*)logger {
  __block BOOL success = NO;
  if (logger) {
    dispatch_sync(logger.serialQueue, ^{
      success = [logger performOpen];
    });

    if (success) {
      dispatch_sync(_lockQueue, ^{
        [_loggers addObject:logger];
      });
    }
  } else {
    XLOG_DEBUG_UNREACHABLE();
  }
  return success;
}

- (void)removeLogger:(XLLogger*)logger {
  if (logger) {
    dispatch_sync(_lockQueue, ^{
      [_loggers removeObject:logger];
    });

    dispatch_sync(logger.serialQueue, ^{
      [logger performClose];
    });
  } else {
    XLOG_DEBUG_UNREACHABLE();
  }
}

- (void)_closeAllLoggers {
  for (XLLogger* logger in _loggers) {
    dispatch_sync(logger.serialQueue, ^{
      [logger performClose];
    });
  }
}

- (void)removeAllLoggers {
  dispatch_sync(_lockQueue, ^{
    [_loggers removeAllObjects];
  });

  [self _closeAllLoggers];
}

@end

@implementation XLFacility (Logging)

// Must be called on _lockQueue
- (void)_logRecord:(XLLogRecord*)record {
  // Call each logger asynchronously on its own serial queue
  for (XLLogger* logger in _loggers) {
    if ([logger shouldLogRecord:record]) {
      dispatch_group_async(_syncGroup, logger.serialQueue, ^{
        pthread_setspecific(_pthreadKey, &XLSharedFacility);
        [logger performLogRecord:record];
        pthread_setspecific(_pthreadKey, NULL);
      });
    }
  }

  // If the log record is at ERROR level or above, block XLFacility entirely until all loggers are done
  if (record.level >= kXLLogLevel_Error) {
    dispatch_group_wait(_syncGroup, DISPATCH_TIME_FOREVER);
  }

  // If the log record is at ABORT level, close all loggers and kill the process
  if (record.level >= kXLLogLevel_Abort) {
    [self _closeAllLoggers];
    abort();
  }
}

- (void)_logMessage:(NSString*)message withTag:(NSString*)tag level:(XLLogLevel)level callstack:(NSArray*)callstack metadata:(NSDictionary<NSString*, NSString*>*)metadata {
  if (message == nil) {
    XLOG_DEBUG_UNREACHABLE();
    return;
  }
  if ((level < kXLMinLogLevel) || (level > kXLMaxLogLevel)) {
    XLOG_DEBUG_UNREACHABLE();
    return;
  }

  // Ignore internal log messages if necessary
  if ((tag == XLFacilityTag_Internal) && (level < _minInternalLogLevel)) {
    return;
  }

#if DEBUG
  // If the log record is at ABORT level and we are being debugged, kill the process immediately
  if ((level >= kXLLogLevel_Abort) && XLIsDebuggerAttached()) {
    abort();
  }
#endif

  // Save current absolute time
  CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();

  // Capture current callstack if necessary (using the same format as -[NSException callStackSymbols])
  if ((level >= _minCaptureCallstackLevel) && !callstack) {
    void* backtraceFrames[128];
    int frameCount = backtrace(backtraceFrames, sizeof(backtraceFrames) / sizeof(void*));
    char** frameStrings = backtrace_symbols(backtraceFrames, frameCount);
    if (frameStrings) {
      callstack = [[NSMutableArray alloc] init];
      for (int i = 0; i < frameCount; ++i) {
        [(NSMutableArray*)callstack addObject:(id)[NSString stringWithUTF8String:frameStrings[i]]];
      }
      free(frameStrings);  // No need to free individual strings
    }
  }

#if DEBUG
  // Clean up the tag if it looks like it was generated from the __FILE__ preprocessor macro
  if (tag.length && ([tag characterAtIndex:0] == '/')) {
    const char* tagUTF8 = [tag UTF8String];
    const char* tagPtr = tagUTF8;
    const char* filePtr = __FILE__;
    while (*tagPtr && *filePtr) {
      if (*(tagPtr + 1) != *(filePtr + 1)) {
        break;
      }
      ++tagPtr;
      ++filePtr;
    }
    tag = [NSString stringWithUTF8String:tagPtr];  // Strip the common prefix between the tag and __FILE__ for this very file
  }
#endif

  // Create the log record and send to loggers
  XLLogRecord* record = [[XLLogRecord alloc] initWithAbsoluteTime:time tag:tag level:level message:message metadata:metadata callstack:callstack];
  if (pthread_getspecific(_pthreadKey)) {  // Avoid deadlock in in case of reentrancy on the same thread by exceptionally making the logging asynchronous
    dispatch_async(_lockQueue, ^{
      [self _logRecord:record];
    });
  } else {
    dispatch_sync(_lockQueue, ^{
      [self _logRecord:record];
    });
  }
}

static void _MetadataApplier(const void* key, const void* value, void* context) {
  NSMutableDictionary<NSString*, NSString*>* output = (__bridge NSMutableDictionary<NSString*, NSString*>*)context;
  [output setObject:[(__bridge NSString*)value description] forKey:(__bridge NSString*)key];
}

static NSDictionary<NSString*, NSString*>* _SanitizeMetadata(NSDictionary<NSString*, id>* input) {
  NSMutableDictionary<NSString*, NSString*>* output = nil;
  if (input.count) {
    output = [[NSMutableDictionary alloc] initWithCapacity:input.count];
    CFDictionaryApplyFunction((CFDictionaryRef)input, _MetadataApplier, (__bridge void*)output);
  }
  return output;
}

- (void)logMessage:(NSString*)message withTag:(NSString*)tag level:(XLLogLevel)level {
  if (level >= XLMinLogLevel) {
    [self _logMessage:[message copy] withTag:tag level:level callstack:nil metadata:nil];
  }
}

- (void)logMessage:(NSString*)message withTag:(NSString*)tag level:(XLLogLevel)level metadata:(NSDictionary<NSString*, id>*)metadata {
  if (level >= XLMinLogLevel) {
    [self _logMessage:[message copy] withTag:tag level:level callstack:nil metadata:_SanitizeMetadata(metadata)];
  }
}

- (void)logMessageWithTag:(NSString*)tag level:(XLLogLevel)level format:(NSString*)format, ... {
  if (level >= XLMinLogLevel) {
    va_list arguments;
    va_start(arguments, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [self _logMessage:message withTag:tag level:level callstack:nil metadata:nil];
  }
}

- (void)logMessageWithTag:(NSString*)tag level:(XLLogLevel)level metadata:(NSDictionary<NSString*, id>*)metadata format:(NSString*)format, ... {
  if (level >= XLMinLogLevel) {
    va_list arguments;
    va_start(arguments, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [self _logMessage:message withTag:tag level:level callstack:nil metadata:_SanitizeMetadata(metadata)];
  }
}

- (void)logException:(NSException*)exception withTag:(NSString*)tag {
  [self logException:exception withTag:tag metadata:nil];
}

- (void)logException:(NSException*)exception withTag:(NSString*)tag metadata:(NSDictionary<NSString*, id>*)metadata {
  if (kXLLogLevel_Exception >= XLMinLogLevel) {
    NSString* message = [NSString stringWithFormat:@"%@ %@", exception.name, exception.reason];
    [self _logMessage:message withTag:tag level:kXLLogLevel_Exception callstack:exception.callStackSymbols metadata:_SanitizeMetadata(metadata)];
  }
}

@end

@implementation XLFacility (Extensions)

static void _UncaughtExceptionHandler(NSException* exception) {
  [XLSharedFacility logException:exception withTag:XLFacilityTag_UncaughtExceptions];
  [XLSharedFacility _closeAllLoggers];
  if (_originalExceptionHandler) {
    (*_originalExceptionHandler)(exception);
  }
}

- (void)setLogsUncaughtExceptions:(BOOL)flag {
  NSUncaughtExceptionHandler* exceptionHandler = NSGetUncaughtExceptionHandler();
  if (flag && (exceptionHandler != _UncaughtExceptionHandler)) {
    NSSetUncaughtExceptionHandler(_UncaughtExceptionHandler);
    _originalExceptionHandler = exceptionHandler;
  } else if (!flag && (exceptionHandler == _UncaughtExceptionHandler)) {
    NSSetUncaughtExceptionHandler(_originalExceptionHandler);
    _originalExceptionHandler = NULL;
  }
}

- (BOOL)logsUncaughtExceptions {
  return (NSGetUncaughtExceptionHandler() == _UncaughtExceptionHandler);
}

static id _ExceptionInitializer(id self, SEL cmd, NSString* name, NSString* reason, NSDictionary* userInfo) {
  if ((self = _originalExceptionInitializerIMP(self, cmd, name, reason, userInfo))) {
    [XLSharedFacility logException:self withTag:XLFacilityTag_InitializedExceptions];
  }
  return self;
}

// It's not possible to patch @throw so we patch NSException initialization instead (the callstack will be nil at this time though)
- (void)setLogsInitializedExceptions:(BOOL)flag {
  Method method = class_getInstanceMethod([NSException class], @selector(initWithName:reason:userInfo:));
  if (flag && (_originalExceptionInitializerIMP == NULL)) {
    _originalExceptionInitializerIMP = (ExceptionInitializerIMP)method_setImplementation(method, (IMP)&_ExceptionInitializer);
  } else if (!flag && (_originalExceptionInitializerIMP != NULL)) {
    method_setImplementation(method, (IMP)_originalExceptionInitializerIMP);
  }
}

- (BOOL)logsInitializedExceptions {
  return (_originalExceptionInitializerIMP == NULL);
}

- (dispatch_source_t)_startCapturingWritingToFD:(int)fd logLevel:(XLLogLevel)level tag:(NSString*)tag detectNSLogFormatting:(BOOL)nsLog {
  if (_newlineData == nil) {
    _newlineData = [[NSData alloc] initWithBytes:"\n" length:1];
  }
  size_t prognameLength = strlen(getprogname());

  int fildes[2];
  pipe(fildes);  // [0] is read end of pipe while [1] is write end
  dup2(fildes[1], fd);  // Duplicate write end of pipe "onto" fd (this closes fd)
  close(fildes[1]);  // Close original write end of pipe
  fd = fildes[0];  // We can now monitor the read end of the pipe

  char* buffer = malloc(kFileDescriptorCaptureBufferSize);
  NSMutableData* data = [[NSMutableData alloc] init];
  fcntl(fd, F_SETFL, O_NONBLOCK);
  dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
  dispatch_source_set_cancel_handler(source, ^{
    free(buffer);
  });
  dispatch_source_set_event_handler(source, ^{
    @autoreleasepool {
      while (1) {
        ssize_t size = read(fd, buffer, kFileDescriptorCaptureBufferSize);
        if (size <= 0) {
          break;
        }
        [data appendBytes:buffer length:size];
        if (size < kFileDescriptorCaptureBufferSize) {
          break;
        }
      }

      while (1) {
        NSRange range = [data rangeOfData:_newlineData options:0 range:NSMakeRange(0, data.length)];
        if (range.location == NSNotFound) {
          break;
        }
        @try {
          NSUInteger offset = 0;

          if (nsLog && (range.location > 24 + prognameLength + 4)) {  // "yyyy-mm-dd HH:MM:ss.SSS progname[:] "
            const char* bytes = (const char*)data.bytes;
            if ((bytes[4] == '-') && (bytes[7] == '-') && (bytes[10] == ' ') && (bytes[13] == ':') && (bytes[16] == ':') && (bytes[19] == '.')) {
              if ((bytes[23] == ' ') && /*!strncmp(&bytes[24], pname, prognameLength) &&*/ (bytes[24 + prognameLength] == '[')) {
                const char* found = strnstr(&bytes[24 + prognameLength + 1], "] ", data.length - (24 + prognameLength + 1));
                if (found) {
                  offset = found - bytes + 2;
                }
              }
            }
          }

          NSString* message = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(offset, range.location - offset)] encoding:NSUTF8StringEncoding];
          if (message) {
            [XLSharedFacility logMessage:(offset ? [kCapturedNSLogPrefix stringByAppendingString:message] : message)withTag:tag level:level];
          } else {
            XLOG_ERROR(@"%@", @"Failed interpreting captured content from standard file descriptor as UTF8");
          }
        }
        @catch (NSException* exception) {
          XLOG_ERROR(@"Failed parsing captured content from standard file descriptor: %@", exception);
        }
        [data replaceBytesInRange:NSMakeRange(0, range.location + range.length) withBytes:NULL length:0];
      }
    }
  });
  dispatch_resume(source);
  return source;
}

- (void)_stopCapturingWritingToFD:(int)fd originalFD:(int)originalFD dispatchSource:(dispatch_source_t)source {
  dispatch_source_cancel(source);
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(source);
#endif

  dup2(originalFD, fd);  // Duplicate original file descriptor "onto" fd (this closes fd)
}

- (void)setCapturesStandardOutput:(BOOL)flag {
  if (flag && (_stdOutCaptureSource == NULL)) {
    _stdOutCaptureSource = [self _startCapturingWritingToFD:STDOUT_FILENO logLevel:kXLLogLevel_Info tag:XLFacilityTag_CapturedStdOut detectNSLogFormatting:NO];
  } else if (!flag && (_stdOutCaptureSource != NULL)) {
    [self _stopCapturingWritingToFD:STDOUT_FILENO originalFD:XLOriginalStdOut dispatchSource:_stdOutCaptureSource];
    _stdOutCaptureSource = NULL;
  }
}

- (BOOL)capturesStandardOutput {
  return (_stdOutCaptureSource != NULL);
}

- (void)setCapturesStandardError:(BOOL)flag {
  if (flag && (_stdErrCaptureSource == NULL)) {
    _stdErrCaptureSource = [self _startCapturingWritingToFD:STDERR_FILENO logLevel:kXLLogLevel_Error tag:XLFacilityTag_CapturedStdErr detectNSLogFormatting:YES];
  } else if (!flag && (_stdErrCaptureSource != NULL)) {
    [self _stopCapturingWritingToFD:STDERR_FILENO originalFD:XLOriginalStdErr dispatchSource:_stdErrCaptureSource];
    _stdErrCaptureSource = NULL;
  }
}

- (BOOL)capturesStandardError {
  return (_stdErrCaptureSource != NULL);
}

@end
