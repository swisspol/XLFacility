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

@implementation XLTCPClientConnection
@end

@interface XLTCPClient () {
@private
  NSUInteger _generation;
  NSTimeInterval _reconnectionDelay;
}
@end

@implementation XLTCPClient

- (id)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithConnectionClass:(Class)connectionClass host:(NSString*)hostname port:(NSUInteger)port {
  XLOG_DEBUG_CHECK([connectionClass isSubclassOfClass:[XLTCPClientConnection class]]);
  XLOG_DEBUG_CHECK(hostname);
  XLOG_DEBUG_CHECK(port > 0);
  if ((self = [super initWithConnectionClass:connectionClass])) {
    _host = [hostname copy];
    _port = port;
    
    _connectionTimeout = 10.0;
    _automaticallyReconnects = YES;
    _minReconnectInterval = 1.0;
    _maxReconnectInterval = 300.0;
    _reconnectionDelay = 1.0;
  }
  return self;
}

// Must be called inside lock queue
- (void)_scheduleReconnection {
  XLOG_DEBUG(@"%@ will attempt to reconnect to \"%@:%i\" in %.0f seconds", [self class], _host, (int)_port, _reconnectionDelay);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_reconnectionDelay * NSEC_PER_SEC)), XLGLOBAL_DISPATCH_QUEUE, ^{
    dispatch_sync(self.lockQueue, ^{
      if (_reconnectionDelay > 0.0) {
        [self _reconnect];
      }
    });
  });
  _reconnectionDelay = MIN(2.0 * _reconnectionDelay, _maxReconnectInterval);
}

- (void)_reconnect {
  XLOG_DEBUG(@"%@ attempting to connect to \"%@:%i\"", [self class], _host, (int)_port);
  _generation += 1;
  NSUInteger lastGeneration = _generation;
  [self.connectionClass connectAsynchronouslyToHost:_host port:_port timeout:_connectionTimeout completion:^(XLTCPConnection* connection) {
    if (connection) {
      if (lastGeneration == _generation) {
        
        [self willOpenConnection:(XLTCPPeerConnection*)connection];
        
        dispatch_sync(self.lockQueue, ^{
          _reconnectionDelay = _minReconnectInterval;
        });
        
      } else {
        XLOG_DEBUG(@"%@ ignoring stalled connection to \"%@:%i\"", [self class], _host, (int)_port);
        [connection close];
      }
    } else if (_automaticallyReconnects) {
      dispatch_sync(self.lockQueue, ^{
        if (_reconnectionDelay > 0.0) {
          [self _scheduleReconnection];
        }
      });
    }
  }];
}

- (BOOL)willStart {
  dispatch_sync(self.lockQueue, ^{
    _reconnectionDelay = _minReconnectInterval;
  });
  
  [self _reconnect];
  
  return YES;
}

- (void)didStop {
  dispatch_sync(self.lockQueue, ^{
    _reconnectionDelay = 0.0;
  });
}

- (void)didCloseConnection:(XLTCPPeerConnection*)connection {
  [super didCloseConnection:connection];
  
  dispatch_sync(self.lockQueue, ^{
    if (_reconnectionDelay > 0.0) {
      [self _scheduleReconnection];
    }
  });
}

@end

@implementation XLTCPClient (Extensions)

- (XLTCPClientConnection*)connection {
  return [self.connections anyObject];
}

@end
