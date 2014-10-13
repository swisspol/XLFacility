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

#import <net/if.h>
#import <netdb.h>

#import "XLTelnetServerLogger.h"
#import "XLPrivate.h"

#define kMaxPendingConnections 4
#define kDispatchQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)

@interface XLTelnetServerLogger () {
@private
  BOOL _preserveHistory;
  dispatch_queue_t _lockQueue;
  NSMutableSet* _connections;
  dispatch_semaphore_t _sourceSemaphore;
  dispatch_source_t _source;
}
@end

@implementation XLTelnetServerLogger

- (id)init {
  return [self initWithPort:2323 preserveHistory:YES];
}

- (id)initWithPort:(NSUInteger)port preserveHistory:(BOOL)preserveHistory {
  NSString* databasePath = preserveHistory ? [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] : nil;
  if ((self = [super initWithDatabasePath:databasePath appVersion:0])) {
    _port = port;
    _preserveHistory = preserveHistory;
    _colorize = YES;
    
    _lockQueue = dispatch_queue_create(object_getClassName(self), DISPATCH_QUEUE_SERIAL);
    _connections = [[NSMutableSet alloc] init];
    _sourceSemaphore = dispatch_semaphore_create(0);
  }
  return self;
}

- (void)dealloc {
  if (_preserveHistory) {
    [[NSFileManager defaultManager] removeItemAtPath:self.databasePath error:NULL];
  }
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(_lockQueue);
  dispatch_release(_sourceSemaphore);
#endif
}

// https://en.wikipedia.org/wiki/ANSI_escape_code
- (NSString*)_formatRecord:(XLLogRecord*)record {
  NSString* formattedMessage = [self formatRecord:record];
  if (_colorize) {
    const char* code = NULL;
    if (record.logLevel == kXLLogLevel_Warning) {
      code = "\x1b[33m";  // Yellow
    } else if (record.logLevel == kXLLogLevel_Error) {
      code = "\x1b[31m";  // Red
    } else if (record.logLevel >= kXLLogLevel_Exception) {
      code = "\x1b[31;1m";  // Bold red
    }
    if (code) {
      formattedMessage = [NSString stringWithFormat:@"%s%@%s", code, formattedMessage, "\x1b[0m"];
    }
  }
  return formattedMessage;
}

- (void)_writeData:(dispatch_data_t)data toSocket:(NSNumber*)socket {
  dispatch_write([socket intValue], data, kDispatchQueue, ^(dispatch_data_t buffer, int error) {
    if (error) {
      if (error != EPIPE) {
        XLOG_INTERNAL(@"Failed writing to socket: %s", strerror(error));
      }
      dispatch_sync(_lockQueue, ^{
        if ([_connections containsObject:socket]) {
          close([socket intValue]);
          [_connections removeObject:socket];
        }
      });
    }
  });
}

- (void)_writeCString:(const char*)string toSocket:(NSNumber*)socket {
  dispatch_data_t data = dispatch_data_create(string, strlen(string), kDispatchQueue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  [self _writeData:data toSocket:socket];
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(data);
#endif
}

- (BOOL)open {
  BOOL success = NO;
  if (!_preserveHistory || [super open]) {
    int listeningSocket = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (listeningSocket > 0) {
      int yes = 1;
      setsockopt(listeningSocket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
      
      struct sockaddr_in addr4;
      bzero(&addr4, sizeof(addr4));
      addr4.sin_len = sizeof(addr4);
      addr4.sin_family = AF_INET;
      addr4.sin_port = htons(_port);
      addr4.sin_addr.s_addr = htonl(INADDR_ANY);
      if (bind(listeningSocket, (void*)&addr4, sizeof(addr4)) == 0) {
        if (listen(listeningSocket, kMaxPendingConnections) == 0) {
          _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, listeningSocket, 0, kDispatchQueue);
          
          dispatch_source_set_cancel_handler(_source, ^{
            close(listeningSocket);
            dispatch_semaphore_signal(_sourceSemaphore);
          });
          
          dispatch_source_set_event_handler(_source, ^{
            @autoreleasepool {
              struct sockaddr remoteSockAddr;
              socklen_t remoteAddrLen = sizeof(remoteSockAddr);
              int socket = accept(listeningSocket, &remoteSockAddr, &remoteAddrLen);
              if (socket > 0) {
                int noSigPipe = 1;
                setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, sizeof(noSigPipe));  // Make sure this socket cannot generate SIG_PIPE
                dispatch_sync(_lockQueue, ^{
                  NSNumber* number = [NSNumber numberWithInt:socket];
                  [_connections addObject:number];
                  
                  char buffer[256];
                  if (_colorize) {
                    snprintf(buffer, sizeof(buffer), "%sYou are connected to %s[%i] (in color!)%s\n\n", "\x1b[32m", getprogname(), getpid(), "\x1b[0m");
                  } else {
                    snprintf(buffer, sizeof(buffer), "You are connected to %s[%i]\n\n", getprogname(), getpid());
                  }
                  [self _writeCString:buffer toSocket:number];
                  
                  if (_preserveHistory) {
                    NSMutableString* history = [[NSMutableString alloc] init];
                    [self enumerateRecordsAfterAbsoluteTime:0.0 backward:NO maxRecords:0 usingBlock:^(int appVersion, XLLogRecord* record, BOOL* stop) {
                      [history appendString:[self _formatRecord:record]];
                    }];
                    [self _writeCString:XLConvertNSStringToUTF8CString(history) toSocket:number];
                  }
                });
              } else {
                XLOG_INTERNAL(@"Failed accepting socket: %s", strerror(errno));
              }
            }
          });
          
          dispatch_resume(_source);
          success = YES;
        } else {
          XLOG_INTERNAL(@"Failed starting listening socket: %s", strerror(errno));
          close(listeningSocket);
        }
      } else {
        XLOG_INTERNAL(@"Failed binding listening socket: %s", strerror(errno));
        close(listeningSocket);
      }
    } else {
      XLOG_INTERNAL(@"Failed creating listening socket: %s", strerror(errno));
    }
  }
  return success;
}

- (void)logRecord:(XLLogRecord*)record {
  if (_preserveHistory) {
    [super logRecord:record];
  }
  
  const char* string = XLConvertNSStringToUTF8CString([self _formatRecord:record]);
  dispatch_data_t data = dispatch_data_create(string, strlen(string), kDispatchQueue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  dispatch_async(_lockQueue, ^{
    for (NSNumber* socket in _connections) {
      [self _writeData:data toSocket:socket];
    }
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
    dispatch_release(data);
#endif
  });
}

- (void)close {
  dispatch_source_cancel(_source);
  dispatch_semaphore_wait(_sourceSemaphore, DISPATCH_TIME_FOREVER);  // Wait until the cancellation handler has been called which guarantees the listening socket is closed
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(_source);
#endif
  _source = NULL;
  
  dispatch_sync(_lockQueue, ^{
    for (NSNumber* socket in _connections) {
      close([socket intValue]);
    }
    [_connections removeAllObjects];
  });
  
  if (_preserveHistory) {
    [super close];
  }
}

@end
