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

#import "XLTCPServerLogger.h"
#import "XLPrivate.h"

#define kMaxPendingConnections 4
#define kDispatchQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)

@interface XLTCPServerLogger ()
- (void)didCloseConnection:(XLTCPServerConnection*)connection;
@end

@implementation XLTCPServerConnection

- (id)initWithServer:(XLTCPServerLogger*)server localAddress:(NSData*)localAddress remoteAddress:(NSData*)remoteAddress socket:(int)socket {
  if ((self = [super init])) {
    _server = server;
    _localAddressData = localAddress;
    _remoteAddressData = remoteAddress;
    _socket = socket;
  }
  return self;
}

- (void)open {
  ;
}

- (void)close {
  close(_socket);
  _socket = 0;
  [_server didCloseConnection:self];
  _server = nil;
}

@end

@implementation XLTCPServerConnection (Extensions)

- (BOOL)isUsingIPv6 {
  const struct sockaddr* localSockAddr = _localAddressData.bytes;
  return (localSockAddr->sa_family == AF_INET6);
}

static NSString* _StringFromAddressData(NSData* data) {
  NSString* string = nil;
  const struct sockaddr* addr = data.bytes;
  char hostBuffer[NI_MAXHOST];
  char serviceBuffer[NI_MAXSERV];
  if (getnameinfo(addr, addr->sa_len, hostBuffer, sizeof(hostBuffer), serviceBuffer, sizeof(serviceBuffer), NI_NUMERICHOST | NI_NUMERICSERV | NI_NOFQDN) >= 0) {
    string = [NSString stringWithFormat:@"%s:%s", hostBuffer, serviceBuffer];
  } else {
    XLOG_INTERNAL(@"Failed converting IP address data to string: %s", strerror(errno));
  }
  return string;
}

- (NSString*)localAddressString {
  return _StringFromAddressData(_localAddressData);
}

- (NSString*)remoteAddressString {
  return _StringFromAddressData(_remoteAddressData);
}

- (void)readDataAsynchronously:(void (^)(dispatch_data_t data))completion {
  dispatch_read(self.socket, SIZE_MAX, kDispatchQueue, ^(dispatch_data_t data, int error) {
    @autoreleasepool {
      if (error) {
        XLOG_INTERNAL(@"Failed reading socket: %s", strerror(error));
        if (completion) {
          completion(NULL);
        }
        [self close];
      } else if (completion) {
        completion(data);
      }
    }
  });
}

- (void)writeBufferAsynchronously:(dispatch_data_t)buffer completion:(void (^)(BOOL success))completion {
  dispatch_write(_socket, buffer, kDispatchQueue, ^(dispatch_data_t data, int error) {
    @autoreleasepool {
      if (error) {
        if (error != EPIPE) {
          XLOG_INTERNAL(@"Failed writing to socket: %s", strerror(error));
        }
        if (completion) {
          completion(NO);
        }
        [self close];
      } else if (completion) {
        completion(YES);
      }
    }
  });
}

- (void)writeDataAsynchronously:(NSData*)data completion:(void (^)(BOOL success))completion {
  dispatch_data_t buffer = dispatch_data_create(data.bytes, data.length, kDispatchQueue, ^{
    [data self];  // Keeps ARC from releasing data too early
  });
  [self writeBufferAsynchronously:buffer completion:completion];
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(buffer);
#endif
}

- (void)writeCStringAsynchronously:(const char*)string completion:(void (^)(BOOL success))completion {
  dispatch_data_t buffer = dispatch_data_create(string, strlen(string), NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
  [self writeBufferAsynchronously:buffer completion:completion];
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(buffer);
#endif
}

@end

@interface XLTCPServerLogger () {
@private
  BOOL _useDatabase;
  dispatch_group_t _syncGroup;
  dispatch_group_t _sourceGroup;
  NSMutableSet* _connections;
  dispatch_source_t _source4;
  dispatch_source_t _source6;
}
@end

@implementation XLTCPServerLogger

+ (Class)connectionClass {
  return [XLTCPServerConnection class];
}

- (id)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithPort:(NSUInteger)port useDatabaseLogger:(BOOL)useDatabaseLogger {
  if ((self = [super init])) {
    _port = port;
    _useDatabase = useDatabaseLogger;
    
    _syncGroup = dispatch_group_create();
    _sourceGroup = dispatch_group_create();
    _connections = [[NSMutableSet alloc] init];
  }
  return self;
}

#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE

- (void)dealloc {
  dispatch_release(_sourceGroup);
  dispatch_release(_syncGroup);
}

#endif

- (NSSet*)connections {
  __block NSSet* connections;
  dispatch_sync(self.lockQueue, ^{
    connections = [_connections copy];
  });
  return connections;
}

- (void)didCloseConnection:(XLTCPServerConnection*)connection {
  dispatch_sync(self.lockQueue, ^{
    if ([_connections containsObject:connection]) {
      [_connections removeObject:connection];
      dispatch_group_leave(_syncGroup);
    }
  });
}

- (int)_createListeningSocket:(BOOL)useIPv6 localAddress:(const void*)address length:(socklen_t)length {
  int listeningSocket = socket(useIPv6 ? PF_INET6 : PF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (listeningSocket > 0) {
    int yes = 1;
    setsockopt(listeningSocket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    
    if (bind(listeningSocket, address, length) == 0) {
      if (listen(listeningSocket, kMaxPendingConnections) == 0) {
        return listeningSocket;
      } else {
        XLOG_INTERNAL(@"Failed starting %s listening socket: %s", useIPv6 ? "IPv6" : "IPv4", strerror(errno));
        close(listeningSocket);
      }
    } else {
      XLOG_INTERNAL(@"Failed binding %s listening socket: %s", useIPv6 ? "IPv6" : "IPv4", strerror(errno));
      close(listeningSocket);
    }
  } else {
    XLOG_INTERNAL(@"Failed creating %s listening socket: %s", useIPv6 ? "IPv6" : "IPv4", strerror(errno));
  }
  return -1;
}

- (dispatch_source_t)_createDispatchSourceWithListeningSocket:(int)listeningSocket isIPv6:(BOOL)isIPv6 {
  dispatch_group_enter(_sourceGroup);
  dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, listeningSocket, 0, kDispatchQueue);
  dispatch_source_set_cancel_handler(source, ^{
    close(listeningSocket);
    dispatch_group_leave(_sourceGroup);
  });
  dispatch_source_set_event_handler(source, ^{
    @autoreleasepool {
      struct sockaddr remoteSockAddr;
      socklen_t remoteAddrLen = sizeof(remoteSockAddr);
      int socket = accept(listeningSocket, &remoteSockAddr, &remoteAddrLen);
      if (socket > 0) {
        int noSigPipe = 1;
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, sizeof(noSigPipe));  // Make sure this socket cannot generate SIG_PIPE
        
        NSData* remoteAddress = [NSData dataWithBytes:&remoteSockAddr length:remoteAddrLen];
        
        struct sockaddr localSockAddr;
        socklen_t localAddrLen = sizeof(localSockAddr);
        NSData* localAddress = nil;
        if (getsockname(socket, &localSockAddr, &localAddrLen) == 0) {
          localAddress = [NSData dataWithBytes:&localSockAddr length:localAddrLen];
        } else {
          XLOG_INTERNAL(@"Failed retrieving local %s socket address: %s", isIPv6 ? "IPv6" : "IPv4", strerror(errno));
        }
        
        XLTCPServerConnection* connection = [[[[self class] connectionClass] alloc] initWithServer:self localAddress:localAddress remoteAddress:remoteAddress socket:socket];
        dispatch_sync(self.lockQueue, ^{
          dispatch_group_enter(_syncGroup);
          [_connections addObject:connection];
        });
        [connection open];
      } else {
        XLOG_INTERNAL(@"Failed accepting %s socket: %s", isIPv6 ? "IPv6" : "IPv4", strerror(errno));
      }
    }
  });
  return source;
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
  
  struct sockaddr_in addr4;
  bzero(&addr4, sizeof(addr4));
  addr4.sin_len = sizeof(addr4);
  addr4.sin_family = AF_INET;
  addr4.sin_port = htons(_port);
  addr4.sin_addr.s_addr = htonl(INADDR_ANY);
  int listeningSocket4 = [self _createListeningSocket:NO localAddress:&addr4 length:sizeof(addr4)];
  
  struct sockaddr_in6 addr6;
  bzero(&addr6, sizeof(addr6));
  addr6.sin6_len = sizeof(addr6);
  addr6.sin6_family = AF_INET6;
  addr6.sin6_port = htons(_port);
  addr6.sin6_addr = in6addr_any;
  int listeningSocket6 = [self _createListeningSocket:YES localAddress:&addr6 length:sizeof(addr6)];
  
  if ((listeningSocket4 <= 0) || (listeningSocket6 <= 0)) {
    if (_databaseLogger) {
      [_databaseLogger close];
      [[NSFileManager defaultManager] removeItemAtPath:_databaseLogger.databasePath error:NULL];
      _databaseLogger = nil;
    }
    return NO;
  }
  
  _source4 = [self _createDispatchSourceWithListeningSocket:listeningSocket4 isIPv6:NO];
  dispatch_resume(_source4);
  
  _source6 = [self _createDispatchSourceWithListeningSocket:listeningSocket6 isIPv6:YES];
  dispatch_resume(_source6);
  
  return YES;
}

- (void)logRecord:(XLLogRecord*)record {
  if (_databaseLogger) {
    [_databaseLogger logRecord:record];
  }
}

- (void)close {
  dispatch_source_cancel(_source6);
  dispatch_source_cancel(_source4);
  dispatch_group_wait(_sourceGroup, DISPATCH_TIME_FOREVER);  // Wait until the cancellation handlers have been called which guarantees the listening sockets are closed
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(_source6);
#endif
  _source6 = NULL;
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(_source4);
#endif
  _source4 = NULL;
  
  NSSet* connections = self.connections;
  for (XLTCPServerConnection* connection in connections) {  // No need to use "_lockQueue" since no new connections can be created anymore and it would deadlock with -didCloseConnection:
    [connection close];
  }
  dispatch_group_wait(_syncGroup, DISPATCH_TIME_FOREVER);  // Wait until all connections are closed
  
  if (_databaseLogger) {
    [_databaseLogger close];
    [[NSFileManager defaultManager] removeItemAtPath:_databaseLogger.databasePath error:NULL];
    _databaseLogger = nil;
  }
}

- (void)enumerateConnectionsUsingBlock:(void (^)(XLTCPServerConnection* connection, BOOL* stop))block {
  dispatch_sync(self.lockQueue, ^{
    BOOL stop = NO;
    for (XLTCPServerConnection* connection in _connections) {
      block(connection, &stop);
      if (stop) {
        break;
      }
    }
  });
}

@end
