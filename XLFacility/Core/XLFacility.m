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

#import <objc/runtime.h>
#import <execinfo.h>
#import <netdb.h>
#import <asl.h>

#import "XLStandardLogger.h"
#import "XLPrivate.h"

#define kMinLogLevelEnvironmentVariable "XLFacilityMinLogLevel"

#define kFileDescriptorCaptureBufferSize 1024
#define kCapturedNSLogPrefix @"(NSLog) "

#if !DEBUG
#define kInvalidUTF8Placeholder "<INVALID UTF8 STRING>"
#endif

typedef id (*ExceptionInitializerIMP)(id self, SEL cmd, NSString* name, NSString* reason, NSDictionary* userInfo);

XLLogLevel XLMinLogLevel = 0;
XLFacility* XLSharedFacility = nil;
int XLOriginalStdOut = 0;
int XLOriginalStdErr = 0;

NSString* const XLFacilityNamespace_Internal = @"xlfacility.internal";
NSString* const XLFacilityNamespace_CapturedStdOut = @"xlfacility.captured-stdout";
NSString* const XLFacilityNamespace_CapturedStdErr = @"xlfacility.captured-stderr";
NSString* const XLFacilityNamespace_UncaughtExceptions = @"xlfacility.uncaught-exceptions";
NSString* const XLFacilityNamespace_InitializedExceptions = @"xlfacility.initialized-exceptions";

static NSUncaughtExceptionHandler* _originalExceptionHandler = NULL;
static ExceptionInitializerIMP _originalExceptionInitializerIMP = NULL;

static dispatch_source_t _stdOutCaptureSource = NULL;
static dispatch_source_t _stdErrCaptureSource = NULL;
static NSData* _newlineData = nil;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"

void XLLogCMessage(const char* namespace, int level, const char* format, ...) {
  va_list arguments;
  va_start(arguments, format);
  NSString* message = [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:arguments];
  va_end(arguments);
  [XLSharedFacility logMessage:message withNamespace:(namespace ? [NSString stringWithUTF8String:namespace] : nil) level:level];
}

#pragma clang diagnostic pop

void XLLogInternalError(NSString* format, ...) {
  va_list arguments;
  va_start(arguments, format);
  NSString* string = [[NSString alloc] initWithFormat:format arguments:arguments];
  va_end(arguments);
  const char* utf8String = [string UTF8String];  // We can't use XLConvertNSStringToUTF8CString() here or we might end up with an infinite loop
  if (utf8String) {
    aslmsg message = asl_new(ASL_TYPE_MSG);
    asl_set(message, ASL_KEY_LEVEL, "3");  // ASL_LEVEL_ERR
    asl_set(message, ASL_KEY_MSG, utf8String);
    asl_send(NULL, message);
    asl_free(message);
  }
#if DEBUG
  else {
    abort();
  }
#endif
}

NSData* XLConvertNSStringToUTF8String(NSString* string) {
  NSData* utf8Data = nil;
  if (string) {
    utf8Data = [string dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!utf8Data) {
#if DEBUG
      abort();
#else
      utf8Data = [NSData dataWithBytesNoCopy:kInvalidUTF8Placeholder length:strlen(kInvalidUTF8Placeholder) freeWhenDone:NO];
#endif
    }
  }
  return utf8Data;
}

const char* XLConvertNSStringToUTF8CString(NSString* string) {
  const char* utf8String = NULL;
  if (string) {
    utf8String = [string UTF8String];
    if (!utf8String) {
      XLLogInternalError(@"Failed converting NSString to UTF8");
#if DEBUG
      abort();
#else
      utf8String = kInvalidUTF8Placeholder;
#endif
    }
  }
  return utf8String;
}

@interface XLFacility () {
@private
  dispatch_queue_t _lockQueue;
  dispatch_group_t _syncGroup;
  NSMutableSet* _loggers;
}
@end

@implementation XLFacility

static void _ExitHandler() {
  @autoreleasepool {
    [XLSharedFacility removeAllLoggers];
  }
}

// Keep around copies of the original stdout and stderr file descriptors from when process starts in cases they are replaced later on
+ (void)load {
  XLOriginalStdOut = dup(STDOUT_FILENO);
  XLOriginalStdErr = dup(STDERR_FILENO);
  
#if DEBUG
  XLMinLogLevel = kXLLogLevel_Debug;
#else
  XLMinLogLevel= kXLLogLevel_Info;
#endif
  const char* logLevel = getenv(kMinLogLevelEnvironmentVariable);
  if (logLevel) {
    XLMinLogLevel = atoi(logLevel);
  }
  
  XLSharedFacility = [[XLFacility alloc] init];
  
  atexit(_ExitHandler);
}

+ (XLFacility*)sharedFacility {
  return XLSharedFacility;
}

- (id)init {
  if ((self = [super init])) {
    _minCaptureCallstackLevel = kXLLogLevel_Exception;
    
    _lockQueue = dispatch_queue_create(XLDISPATCH_QUEUE_LABEL, DISPATCH_QUEUE_SERIAL);
    _syncGroup = dispatch_group_create();
    _loggers = [[NSMutableSet alloc] init];
    
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

- (XLLogger*)addLogger:(XLLogger*)logger {
  __block XLLogger* addedLogger;
  dispatch_sync(_lockQueue, ^{
    if (![_loggers containsObject:logger]) {
      dispatch_sync(logger.serialQueue, ^{
        addedLogger = [logger open] ? logger : nil;
      });
      if (addedLogger) {
        [_loggers addObject:addedLogger];
      }
    }
  });
  return addedLogger;
}

- (void)removeLogger:(XLLogger*)logger {
  dispatch_sync(_lockQueue, ^{
    if ([_loggers containsObject:logger]) {
      dispatch_sync(logger.serialQueue, ^{
        [logger close];
      });
      [_loggers removeObject:logger];
    }
  });
}

- (void)removeAllLoggers {
  dispatch_sync(_lockQueue, ^{
    for (XLLogger* logger in _loggers) {
      dispatch_sync(logger.serialQueue, ^{
        [logger close];
      });
    }
    [_loggers removeAllObjects];
  });
}

@end

@implementation XLFacility (Logging)

- (void)_logMessage:(NSString*)message withNamespace:(NSString*)namespace level:(XLLogLevel)level callstack:(NSArray*)callstack {
  if (level < kXLMinLogLevel) {
    level = kXLMinLogLevel;
  } else if (level > kXLMaxLogLevel) {
    level = kXLMaxLogLevel;
  }
  
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
        [(NSMutableArray*)callstack addObject:[NSString stringWithUTF8String:frameStrings[i]]];
      }
      free(frameStrings);  // No need to free individual strings
    }
  }
  
  // Create the log record and dispatch to all loggers
  XLLogRecord* record = [[XLLogRecord alloc] initWithAbsoluteTime:time namespace:namespace level:level message:message callstack:callstack];
  dispatch_sync(_lockQueue, ^{
    
    // Call each logger asynchronously on its own serial queue
    for (XLLogger* logger in _loggers) {
      if ([logger shouldLogRecord:record]) {
        dispatch_group_async(_syncGroup, logger.serialQueue, ^{
          [logger logRecord:record];
        });
      }
    }
    
    // If the log record is at ERROR level or above, block XLFacility entirely until all loggers are done
    if (level >= kXLLogLevel_Error) {
      dispatch_group_wait(_syncGroup, DISPATCH_TIME_FOREVER);
    }
    
    // If the log record is at ABORT level, close all loggers and kill the process
    if (level >= kXLLogLevel_Abort) {
      for (XLLogger* logger in _loggers) {
        dispatch_sync(logger.serialQueue, ^{
          [logger close];
        });
      }
      abort();
    }
    
  });
}

- (void)logMessage:(NSString*)message withNamespace:(NSString*)namespace level:(XLLogLevel)level {
  if (level >= XLMinLogLevel) {
    [self _logMessage:message withNamespace:namespace level:level callstack:nil];
  }
}

- (void)logMessageWithNamespace:(NSString*)namespace level:(XLLogLevel)level format:(NSString*)format, ... {
  if (level >= XLMinLogLevel) {
    va_list arguments;
    va_start(arguments, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [self _logMessage:message withNamespace:namespace level:level callstack:nil];
  }
}

- (void)logException:(NSException*)exception withNamespace:(NSString*)namespace {
  if (kXLLogLevel_Exception >= XLMinLogLevel) {
    NSString* message = [NSString stringWithFormat:@"%@ %@", exception.name, exception.reason];
    [self _logMessage:message withNamespace:namespace level:kXLLogLevel_Exception callstack:exception.callStackSymbols];
  }
}

@end

@implementation XLFacility (Extensions)

static void _UncaughtExceptionHandler(NSException* exception) {
  [XLSharedFacility logException:exception withNamespace:XLFacilityNamespace_UncaughtExceptions];
  [XLSharedFacility removeAllLoggers];
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
    [XLSharedFacility logException:self withNamespace:XLFacilityNamespace_InitializedExceptions];
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

- (dispatch_source_t)_startCapturingWritingToFD:(int)fd logLevel:(XLLogLevel)level namespace:(NSString*)namespace detectNSLogFormatting:(BOOL)nsLog {
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
  dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, XGLOBAL_DISPATCH_QUEUE);
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
            [XLSharedFacility logMessage:(offset ? [kCapturedNSLogPrefix stringByAppendingString:message] : message) withNamespace:namespace level:level];
          } else {
            XLLogInternalError(@"%@", @"Failed interpreting captured content from standard file descriptor as UTF8");
          }
        }
        @catch (NSException* exception) {
          XLLogInternalError(@"Failed parsing captured content from standard file descriptor: %@", exception);
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
    _stdOutCaptureSource = [self _startCapturingWritingToFD:STDOUT_FILENO logLevel:kXLLogLevel_Info namespace:XLFacilityNamespace_CapturedStdOut detectNSLogFormatting:NO];
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
    _stdErrCaptureSource = [self _startCapturingWritingToFD:STDERR_FILENO logLevel:kXLLogLevel_Error namespace:XLFacilityNamespace_CapturedStdErr detectNSLogFormatting:YES];
  } else if (!flag && (_stdErrCaptureSource != NULL)) {
    [self _stopCapturingWritingToFD:STDERR_FILENO originalFD:XLOriginalStdErr dispatchSource:_stdErrCaptureSource];
    _stdErrCaptureSource = NULL;
  }
}

- (BOOL)capturesStandardError {
  return (_stdErrCaptureSource != NULL);
}

@end
