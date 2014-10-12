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
#import <asl.h>

#import "XLPrivate.h"

#define kMinLogLevelEnvironmentVariable "XLFacilityMinLogLevel"

#define kFileDescriptorCaptureBufferSize 1024

XLFacility* XLSharedFacility = nil;

static NSUncaughtExceptionHandler* _originalExceptionHandler = NULL;
static IMP _originalExceptionInitializerIMP = NULL;

static dispatch_source_t _stdOutCaptureSource = NULL;
static dispatch_source_t _stdErrCaptureSource = NULL;

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

const char* XLConvertNSStringToUTF8CString(NSString* string) {
  const char* utf8String = NULL;
  if (string) {
    utf8String = [string UTF8String];
    if (!utf8String) {
      XLLogInternalError(@"Failed converting NSString to UTF8");
#if DEBUG
      abort();
#else
      utf8String = "<INVALID UTF8 STRING>";
#endif
    }
  }
  return utf8String;
}

@interface XLFacility () {
@private
  dispatch_queue_t _lockQueue;
  dispatch_group_t _destinationGroup;
  NSMutableSet* _loggers;
}
@end

@implementation XLFacility

static void _ExitHandler() {
  @autoreleasepool {
    [XLSharedFacility removeAllLoggers];
  }
}

+ (void)load {
  XLSharedFacility = [[XLFacility alloc] init];
  atexit(_ExitHandler);
}

+ (XLFacility*)sharedFacility {
  return XLSharedFacility;
}

- (id)init {
  if ((self = [super init])) {
#if DEBUG
    _minLogLevel = kXLLogLevel_Debug;
#else
    _minLogLevel= kXLLogLevel_Info;
#endif
    const char* logLevel = getenv(kMinLogLevelEnvironmentVariable);
    if (logLevel) {
      _minLogLevel = atoi(logLevel);
    }
    _minCaptureCallstackLevel = kXLLogLevel_Exception;
    
    _lockQueue = dispatch_queue_create(object_getClassName([self class]), DISPATCH_QUEUE_SERIAL);
    _destinationGroup = dispatch_group_create();
    _loggers = [[NSMutableSet alloc] init];
    _callsLoggersConcurrently = YES;
  }
  return self;
}

- (NSSet*)loggers {
  __block NSSet* loggers;
  dispatch_sync(_lockQueue, ^{
    loggers = [_loggers copy];
  });
  return loggers;
}

- (XLLogger*)addLogger:(XLLogger*)logger {
  __block XLLogger* addedLogger = nil;
  dispatch_sync(_lockQueue, ^{
    if (![_loggers containsObject:logger] && [logger open]) {
      [_loggers addObject:logger];
      addedLogger = logger;
    }
  });
  return addedLogger;
}

- (BOOL)removeLogger:(XLLogger*)logger {
  __block BOOL success = NO;
  dispatch_sync(_lockQueue, ^{
    if ([_loggers containsObject:logger]) {
      [logger close];
      [_loggers removeObject:logger];
      success = YES;
    }
  });
  return success;
}

- (void)removeAllLoggers {
  dispatch_sync(_lockQueue, ^{
    for (XLLogger* logger in _loggers) {
      [logger close];
    }
    [_loggers removeAllObjects];
  });
}

- (void)_logMessage:(NSString*)message withLevel:(XLLogLevel)level callstack:(NSArray*)callstack {
  CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
  if (level < kXLMinLogLevel) {
    level = kXLMinLogLevel;
  } else if (level > kXLMaxLogLevel) {
    level = kXLMaxLogLevel;
  }
  
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
  
  XLRecord* record = [[XLRecord alloc] initWithAbsoluteTime:time logLevel:level message:message callstack:callstack];
  dispatch_sync(_lockQueue, ^{
    dispatch_queue_t concurrentQueue = _loggers.count > 1 && _callsLoggersConcurrently ? dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) : NULL;
    for (XLLogger* logger in _loggers) {
      if ([logger shouldLogRecord:record]) {
        if (concurrentQueue) {
          dispatch_group_async(_destinationGroup, concurrentQueue, ^{
            [logger logRecord:record];
          });
        } else {
          [logger logRecord:record];
        }
      }
    }
    if (concurrentQueue) {
      dispatch_group_wait(_destinationGroup, DISPATCH_TIME_FOREVER);
    }
    
    if (level >= kXLLogLevel_Abort) {
      for (XLLogger* logger in _loggers) {
        [logger close];
      }
      abort();
    }
  });
}

- (void)logMessage:(NSString*)message withLevel:(XLLogLevel)level {
  [self _logMessage:message withLevel:level callstack:nil];
}

#define LOG_MESSAGE_WITH_LEVEL(__LEVEL__, __CALLSTACK__) \
  if (__LEVEL__ >= _minLogLevel) { \
    va_list arguments; \
    va_start(arguments, format); \
    NSString* message = [[NSString alloc] initWithFormat:format arguments:arguments]; \
    va_end(arguments); \
    [self _logMessage:message withLevel:__LEVEL__ callstack:__CALLSTACK__]; \
  }

- (void)logMessageWithLevel:(XLLogLevel)level format:(NSString*)format, ... {
  LOG_MESSAGE_WITH_LEVEL(level, nil)
}

- (void)logDebug:(NSString*)format, ... {
  LOG_MESSAGE_WITH_LEVEL(kXLLogLevel_Debug, nil)
}

- (void)logVerbose:(NSString*)format, ... {
  LOG_MESSAGE_WITH_LEVEL(kXLLogLevel_Verbose, nil)
}

- (void)logInfo:(NSString*)format, ... {
  LOG_MESSAGE_WITH_LEVEL(kXLLogLevel_Info, nil)
}

- (void)logWarning:(NSString*)format, ... {
  LOG_MESSAGE_WITH_LEVEL(kXLLogLevel_Warning, nil)
}

- (void)logError:(NSString*)format, ... {
  LOG_MESSAGE_WITH_LEVEL(kXLLogLevel_Error, nil)
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"

- (void)_logExceptionWithCallstack:(NSArray*)callstack format:(NSString*)format, ... {
  LOG_MESSAGE_WITH_LEVEL(kXLLogLevel_Exception, callstack)  // Clang is complaining here about a non-literal format string but only because the method name starts with an underscore?
}

#pragma clang diagnostic pop

- (void)logException:(NSException*)exception {
  [self _logExceptionWithCallstack:exception.callStackSymbols format:@"%@ %@", exception.name, exception.reason];
}

- (void)logAbort:(NSString*)format, ... {
  LOG_MESSAGE_WITH_LEVEL(kXLLogLevel_Abort, nil)
}

@end

@implementation XLFacility (Extensions)

static void _UncaughtExceptionHandler(NSException* exception) {
  [XLSharedFacility logException:exception];
  if (_originalExceptionHandler) {
    (*_originalExceptionHandler)(exception);
  }
}

+ (void)enableLoggingOfUncaughtExceptions {
  NSUncaughtExceptionHandler* exceptionHandler = NSGetUncaughtExceptionHandler();
  if (exceptionHandler != _UncaughtExceptionHandler) {
    _originalExceptionHandler = exceptionHandler;
    NSSetUncaughtExceptionHandler(_UncaughtExceptionHandler);
  }
}

static id _ExceptionInitializer(id self, SEL cmd, NSString* name, NSString* reason, NSDictionary* userInfo) {
  if ((self = _originalExceptionInitializerIMP(self, cmd, name, reason, userInfo))) {
    [XLSharedFacility logException:self];
  }
  return self;
}

// It's not possible to patch @throw so we patch NSException initialization instead (the callstack will be nil at this time though)
+ (void)enableLoggingOfInitializedExceptions {
  if (!_originalExceptionInitializerIMP) {
    Method method = class_getInstanceMethod([NSException class], @selector(initWithName:reason:userInfo:));
    _originalExceptionInitializerIMP = method_setImplementation(method, (IMP)&_ExceptionInitializer);
  }
}

static dispatch_source_t _CaptureWritingToFileDescriptor(int fd, XLLogLevel level) {
  int fildes[2];
  pipe(fildes);  // [0] is read end of pipe while [1] is write end
  dup2(fildes[1], fd);  // Duplicate write end of pipe "onto" fd (this closes fd)
  close(fildes[1]);  // Close original write end of pipe
  fd = fildes[0];  // We can now monitor the read end of the pipe
  
  char* buffer = malloc(kFileDescriptorCaptureBufferSize);
  NSMutableData* data = [[NSMutableData alloc] init];
  fcntl(fd, F_SETFL, O_NONBLOCK);
  dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
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
        NSRange range = [data rangeOfData:[NSData dataWithBytes:"\n" length:1] options:0 range:NSMakeRange(0, data.length)];
        if (range.location == NSNotFound) {
          break;
        }
        @try {
          NSString* message = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, range.location)] encoding:NSUTF8StringEncoding];
          [XLSharedFacility logMessage:message withLevel:level];
        }
        @catch (NSException* exception) {
          XLLogInternalError(@"Failed capturing writing to file descriptor: %@", exception);
        }
        [data replaceBytesInRange:NSMakeRange(0, range.location + range.length) withBytes:NULL length:0];
      }
    }
  });
  dispatch_resume(source);
  return source;
}

+ (void)enableCapturingOfStdOut {
  if (!_stdOutCaptureSource) {
    _stdOutCaptureSource = _CaptureWritingToFileDescriptor(STDOUT_FILENO, kXLLogLevel_Info);
  }
}

+ (void)enableCapturingOfStdErr {
  if (!_stdErrCaptureSource) {
    _stdErrCaptureSource = _CaptureWritingToFileDescriptor(STDERR_FILENO, kXLLogLevel_Error);
  }
}

@end
