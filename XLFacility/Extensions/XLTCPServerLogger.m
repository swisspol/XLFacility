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

#import "XLTCPServerLogger.h"
#import "XLFacilityPrivate.h"

static void* _associatedObjectKey = &_associatedObjectKey;

@interface XLTCPServerLogger () {
@private
  BOOL _useDatabase;
}
@end

@implementation XLTCPServerLogger

+ (Class)serverClass {
  return [GCDTCPServer class];
}

+ (Class)connectionClass {
  return [GCDTCPServerConnection class];
}

- (id)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithPort:(NSUInteger)port useDatabaseLogger:(BOOL)useDatabaseLogger {
  XLOG_DEBUG_CHECK([[[self class] serverClass] isSubclassOfClass:[GCDTCPServer class]]);
  if ((self = [super init])) {
    _TCPServer = [[[[self class] serverClass] alloc] initWithConnectionClass:[[self class] connectionClass] port:port];
    objc_setAssociatedObject(_TCPServer, _associatedObjectKey, self, OBJC_ASSOCIATION_ASSIGN);
    _useDatabase = useDatabaseLogger;
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
  
  if (![_TCPServer start]) {
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
}

- (void)close {
  [_TCPServer stop];
  
  if (_databaseLogger) {
    [_databaseLogger close];
    [[NSFileManager defaultManager] removeItemAtPath:_databaseLogger.databasePath error:NULL];
    _databaseLogger = nil;
  }
}

@end

@implementation GCDTCPServerConnection (XLTCPServerLogger)

- (XLTCPServerLogger*)logger {
  return objc_getAssociatedObject(self.peer, _associatedObjectKey);
}

@end
