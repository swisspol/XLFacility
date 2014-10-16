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

#import "XLTCPClient.h"
#import "XLPrivate.h"

@interface XLTCPClientConnection ()
@property(nonatomic, assign) XLTCPClient* client;
@end

@interface XLTCPClient () {
@private
  dispatch_queue_t _lockQueue;
  dispatch_group_t _syncGroup;
  XLTCPClientConnection* _connection;
  NSUInteger _generation;
  NSTimeInterval _reconnectionDelay;
}
@end

@implementation XLTCPClientConnection

- (void)didClose {
  [super didClose];
  
  [_client didCloseConnection:self];
  _client = nil;
}

@end

@implementation XLTCPClient

- (id)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithConnectionClass:(Class)connectionClass host:(NSString*)hostname port:(NSUInteger)port {
  if ((self = [super init])) {
    _connectionClass = connectionClass;
    _host = [hostname copy];
    _port = port;
    
    _lockQueue = dispatch_queue_create(XLDISPATCH_QUEUE_LABEL, DISPATCH_QUEUE_SERIAL);
    _connectionTimeout = 10.0;
    _automaticallyReconnects = YES;
    _minReconnectInterval = 1.0;
    _maxReconnectInterval = 300.0;
    _reconnectionDelay = 1.0;
    _syncGroup = dispatch_group_create();
  }
  return self;
}

#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE

- (void)dealloc {
  dispatch_release(_syncGroup);
  dispatch_release(_lockQueue);
}

#endif

- (XLTCPClientConnection*)connection {
  __block XLTCPClientConnection* connection;
  dispatch_sync(_lockQueue, ^{
    connection = _connection;
  });
  return connection;
}

// Must be called inside lock queue
- (void)_scheduleReconnection {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_reconnectionDelay * NSEC_PER_SEC)), XLGLOBAL_DISPATCH_QUEUE, ^{
    dispatch_sync(_lockQueue, ^{
      if (_reconnectionDelay > 0.0) {
        [self _reconnect];
      }
    });
  });
  _reconnectionDelay = MIN(2.0 * _reconnectionDelay, _maxReconnectInterval);
}

- (void)_reconnect {
  _generation += 1;
  NSUInteger lastGeneration = _generation;
  [_connectionClass connectAsynchronouslyToHost:_host port:_port timeout:_connectionTimeout completion:^(XLTCPConnection* connection) {
    if (connection) {
      if (lastGeneration == _generation) {
        
        [self willOpenConnection:(XLTCPClientConnection*)connection];
        
        dispatch_sync(_lockQueue, ^{
          _reconnectionDelay = _minReconnectInterval;
        });
        
      } else {
        XLOG_WARNING(@"TCP connection opened too late");
        [connection close];
      }
    } else if (_automaticallyReconnects) {
      dispatch_sync(_lockQueue, ^{
        if (_reconnectionDelay > 0.0) {
          [self _scheduleReconnection];
        }
      });
    }
  }];
}

- (BOOL)start {
  dispatch_sync(_lockQueue, ^{
    _reconnectionDelay = _minReconnectInterval;
  });
  
  [self _reconnect];
  return YES;
}

- (void)stop {
  dispatch_sync(_lockQueue, ^{
    _reconnectionDelay = 0.0;
  });
  
  XLTCPClientConnection* connection = self.connection;
  [connection close];  // No need to use "lockQueue" since no new connection can be created and it would deadlock with -didCloseConnection:
  dispatch_group_wait(_syncGroup, DISPATCH_TIME_FOREVER);  // Wait until connection is closed
}

@end

@implementation XLTCPClient (Subclassing)

- (void)willOpenConnection:(XLTCPClientConnection*)connection {
  connection.client = self;
  dispatch_sync(_lockQueue, ^{
    dispatch_group_enter(_syncGroup);
    _connection = connection;
  });
  [connection open];
}

- (void)didCloseConnection:(XLTCPClientConnection*)connection {
  dispatch_sync(_lockQueue, ^{
    if (_connection == connection) {
      _connection = nil;
      dispatch_group_leave(_syncGroup);
    }
    if (_reconnectionDelay > 0.0) {
      [self _scheduleReconnection];
    }
  });
}

@end
