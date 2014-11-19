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

#import "XLTCPClientLogger.h"
#import "XLFunctions.h"
#import "XLFacilityPrivate.h"

static void* _associatedObjectKey = &_associatedObjectKey;

@interface XLTCPClientLogger () {
@private
  BOOL _useDatabase;
}
@end

@implementation GCDTCPClientConnection (XLTCPClientLogger)

- (XLTCPClientLogger*)logger {
  return objc_getAssociatedObject(self.peer, _associatedObjectKey);
}

- (void)didOpen {
  XLTCPClientLogger* logger = (XLTCPClientLogger*)self.logger;
  if (logger.databaseLogger) {
    NSMutableString* string = [[NSMutableString alloc] init];
    [logger.databaseLogger enumerateRecordsAfterAbsoluteTime:0.0 backward:NO maxRecords:0 usingBlock:^(int appVersion, XLLogRecord* record, BOOL* stop) {
      [string appendString:[logger formatRecord:record]];
    }];
    if (string.length) {
      [self writeLogString:string withTimeout:logger.sendTimeout];
    }
  }
}

- (void)writeLogString:(NSString*)string withTimeout:(NSTimeInterval)timeout {
  NSData* data = XLConvertNSStringToUTF8String(string);
  if (timeout < 0.0) {
    [self writeDataAsynchronously:data completion:^(BOOL success) {
      if (!success) {
        [self close];
      }
    }];
  } else {
    if (![self writeData:data withTimeout:timeout]) {
      [self close];
    }
  }
}

@end

@implementation XLTCPClientLogger

+ (Class)clientClass {
  return [GCDTCPClient class];
}

+ (Class)connectionClass {
  return [GCDTCPClientConnection class];
}

- (id)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithHost:(NSString*)hostname port:(NSUInteger)port preserveHistory:(BOOL)preserveHistory {
  XLOG_DEBUG_CHECK([[[self class] clientClass] isSubclassOfClass:[GCDTCPClient class]]);
  if ((self = [super init])) {
    _TCPClient = [[[[self class] clientClass] alloc] initWithConnectionClass:[[self class] connectionClass] host:hostname port:port];
    objc_setAssociatedObject(_TCPClient, _associatedObjectKey, self, OBJC_ASSOCIATION_ASSIGN);
    _useDatabase = preserveHistory;
    _sendTimeout = -1.0;
  }
  return self;
}

- (BOOL)open {
  if (_useDatabase) {
    NSString* databasePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
    _databaseLogger = [[XLDatabaseLogger alloc] initWithDatabasePath:databasePath appVersion:0];
    if (![_databaseLogger open]) {
      _databaseLogger = nil;
      return NO;
    }
  }
  
  if (![_TCPClient start]) {
    [_databaseLogger close];
    [[NSFileManager defaultManager] removeItemAtPath:_databaseLogger.databasePath error:NULL];
    _databaseLogger = nil;
    return NO;
  }
  
  return YES;
}

- (void)logRecord:(XLLogRecord*)record {
  if (_databaseLogger) {
    [_databaseLogger logRecord:record];
  }
  
  [_TCPClient.connection writeLogString:[self formatRecord:record] withTimeout:_sendTimeout];
}

- (void)close {
  [_TCPClient stop];
  
  if (_databaseLogger) {
    [_databaseLogger close];
    [[NSFileManager defaultManager] removeItemAtPath:_databaseLogger.databasePath error:NULL];
    _databaseLogger = nil;
  }
}

@end
