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
#error GCDNetworking requires ARC
#endif

#import <net/if.h>
#import <netdb.h>

#import "GCDNetworkingPrivate.h"

#define kReadBufferSize (64 * 1024)  // Max IP packet size

typedef union {
  struct sockaddr addr;
  struct sockaddr_in addr4;
  struct sockaddr_in6 addr6;
} SocketAddress;

static NSString* _IPAddressFromAddressData(const struct sockaddr* address) {
  NSString* string = nil;
  if (address) {
    char hostBuffer[NI_MAXHOST];
    if (getnameinfo(address, address->sa_len, hostBuffer, sizeof(hostBuffer), NULL, 0, NI_NUMERICHOST | NI_NOFQDN) >= 0) {
      string = [NSString stringWithUTF8String:hostBuffer];
    } else {
      _LOG_ERROR(@"Failed converting IP address data to string: %s", strerror(errno));
    }
  }
  return string;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-align"
#pragma clang diagnostic ignored "-Wunreachable-code-return"

static NSUInteger _PortFromAddressData(const struct sockaddr* address) {
  switch (address->sa_family) {
    case AF_INET: return ntohs(((const struct sockaddr_in*)address)->sin_port);
    case AF_INET6: return ntohs(((const struct sockaddr_in6*)address)->sin6_port);
  }
  _LOG_DEBUG_UNREACHABLE();
  return 0;
}

#pragma clang diagnostic pop

@interface GCDTCPConnection () {
@private
  dispatch_queue_t _lockQueue;
  GCDTCPConnectionState _state;
  dispatch_group_t _writeGroup;
}
@end

@implementation GCDTCPConnection

static int _CreateConnectedSocket(NSString* hostname, NSUInteger port, const struct sockaddr* addr, socklen_t len, NSTimeInterval timeout, BOOL isIPv6) {
  int connectedSocket = socket(isIPv6 ? PF_INET6 : PF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (connectedSocket >= 0) {
    BOOL success = NO;
    fcntl(connectedSocket, F_SETFL, O_NONBLOCK);
    
    _LOG_DEBUG(@"Connecting %s socket to \"%@:%i\" (%@)...", isIPv6 ? "IPv6" : "IPv4", hostname, (int)port, _IPAddressFromAddressData(addr));
    int result = connect(connectedSocket, addr, len);
    if ((result == -1) && (errno == EINPROGRESS)) {
      fd_set fdset;
      FD_ZERO(&fdset);
      FD_SET(connectedSocket, &fdset);
      struct timeval tv;
      tv.tv_sec = timeout;
      tv.tv_usec = fmod(timeout * 1000000.0, 1.0);
      result = select(connectedSocket + 1, NULL, &fdset, NULL, &tv);
      if (result == 1) {
        
        int error;
        socklen_t errorlen = sizeof(error);
        result = getsockopt(connectedSocket, SOL_SOCKET, SO_ERROR, &error, &errorlen);
        if (result == 0) {
          if (error == 0) {
            success = YES;
          } else {
            _LOG_ERROR(@"Failed connecting %s socket to \"%@:%i\" (%@): %s", isIPv6 ? "IPv6" : "IPv4", hostname, (int)port, _IPAddressFromAddressData(addr), strerror(error));
          }
        } else {
          _LOG_ERROR(@"Failed retrieving %s socket option: %s", isIPv6 ? "IPv6" : "IPv4", strerror(errno));
        }
        
      } else if (result == 0) {
        _LOG_ERROR(@"Timed out connecting %s socket to \"%@:%i\" (%@)", isIPv6 ? "IPv6" : "IPv4", hostname, (int)port, _IPAddressFromAddressData(addr));
      }
    } else {
      _LOG_ERROR(@"Failed connecting %s socket to \"%@:%i\" (%@): %s", isIPv6 ? "IPv6" : "IPv4", hostname, (int)port, _IPAddressFromAddressData(addr), strerror(errno));
    }
    
    if (success) {
      fcntl(connectedSocket, F_SETFL, 0);
    } else {
      close(connectedSocket);
      connectedSocket = -1;
    }
  } else {
    _LOG_ERROR(@"Failed creating %s socket: %s", isIPv6 ? "IPv6" : "IPv4", strerror(errno));
  }
  return connectedSocket;
}

+ (void)connectAsynchronouslyToHost:(NSString*)hostname port:(NSUInteger)port timeout:(NSTimeInterval)timeout completion:(void (^)(GCDTCPConnection* connection))completion {
  dispatch_async(GN_GLOBAL_DISPATCH_QUEUE, ^{
    GCDTCPConnection* connection = nil;
    
    CFHostRef host = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)hostname);  // Consider using low-level getaddrinfo() instead
    CFStreamError error = {0};
    if (CFHostStartInfoResolution(host, kCFHostAddresses, &error)) {
      NSArray* addressing = (__bridge NSArray*)CFHostGetAddressing(host, NULL);
      for (NSData* addressData in addressing) {
        SocketAddress address;
        bcopy(addressData.bytes, &address, addressData.length);
        if (((address.addr.sa_family == AF_INET) && (address.addr.sa_len == sizeof(struct sockaddr_in)))  // Allow IPv4 hosts
            || ((address.addr.sa_family == AF_INET6) && (address.addr.sa_len == sizeof(struct sockaddr_in6)))) {  // Allow IPv6 hosts
          
          if (address.addr.sa_family == AF_INET6) {
            address.addr6.sin6_port = htons(port);
          } else {
            address.addr4.sin_port = htons(port);
          }
          int socket = _CreateConnectedSocket(hostname, port, &address.addr, address.addr.sa_len, timeout, address.addr.sa_family == AF_INET6);
          if (socket >= 0) {
            connection = [[self alloc] initWithSocket:socket];
            if (connection) {
              break;
            } else {
              _LOG_ERROR(@"Failed creating %@ instance with connected socket", NSStringFromClass([self class]));
              close(socket);
            }
          }
          
        }
      }
    } else {
      _LOG_ERROR(@"Failed resolving host \"%@\": (%i, %i)", hostname, (int)error.domain, (int)error.error);
    }
    CFRelease(host);
    
    completion(connection);
  });
}

- (void)_setSocketOption:(int)option valuePtr:(const void*)valuePtr valueLength:(socklen_t)valueLength {
  if (setsockopt(_socket, SOL_SOCKET, option, valuePtr, valueLength)) {
    _LOG_ERROR(@"Failed setting socket option: %s", strerror(errno));
  }
}

- (void)_setSocketOption:(int)option withIntValue:(int)value {
  [self _setSocketOption:option valuePtr:&value valueLength:sizeof(int)];
}

- (id)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithSocket:(int)socket {
  _LOG_DEBUG_CHECK(socket >= 0);
  if ((self = [super init])) {
    _lockQueue = dispatch_queue_create(GN_QUEUE_LABEL, DISPATCH_QUEUE_SERIAL);
    _state = kXLTCPConnectionState_Initialized;
    _socket = socket;
    
    [self _setSocketOption:SO_NOSIGPIPE withIntValue:1];  // Make sure this socket cannot generate SIG_PIPE when closed
    [self _setSocketOption:SO_KEEPALIVE withIntValue:1];  // Enable TCP keep-alive
    
    struct sockaddr localSockAddr;
    socklen_t localAddrLen = sizeof(localSockAddr);
    if (getsockname(_socket, &localSockAddr, &localAddrLen) == 0) {
      _localAddressData = [[NSData alloc] initWithBytes:&localSockAddr length:localAddrLen];
    } else {
      _LOG_ERROR(@"Failed retrieving local socket address: %s", strerror(errno));
    }
    
    struct sockaddr remoteSockAddr;
    socklen_t remoteAddrLen = sizeof(remoteSockAddr);
    if (getpeername(_socket, &remoteSockAddr, &remoteAddrLen) == 0) {
      _remoteAddressData = [[NSData alloc] initWithBytes:&remoteSockAddr length:remoteAddrLen];
    } else {
      _LOG_ERROR(@"Failed retrieving remote socket address: %s", strerror(errno));
    }
  }
  return self;
}

- (void)dealloc {
  if (_socket >= 0) {
    close(_socket);
  }
  if (_state == kXLTCPConnectionState_Opened) {
    _state = kXLTCPConnectionState_Closed;
    [self didClose];
  }
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(_lockQueue);
#endif
}

- (GCDTCPConnectionState)state {
  __block GCDTCPConnectionState state;
  dispatch_sync(_lockQueue, ^{
    state = _state;
  });
  return state;
}

- (void)open {
  __block BOOL didOpen = NO;
  dispatch_sync(_lockQueue, ^{
    if (_state == kXLTCPConnectionState_Initialized) {
      _state = kXLTCPConnectionState_Opened;
      didOpen = YES;
    }
  });
  if (didOpen) {
    [self didOpen];
  }
}

- (NSData*)readDataWithTimeout:(NSTimeInterval)timeout {
  __block NSMutableData* data = nil;
  dispatch_sync(_lockQueue, ^{
    if (_state == kXLTCPConnectionState_Opened) {
      struct timeval tv;
      tv.tv_sec = timeout;
      tv.tv_usec = fmod(timeout * 1000000.0, 1.0);
      [self _setSocketOption:SO_RCVTIMEO valuePtr:&tv valueLength:sizeof(tv)];
      
      data = [[NSMutableData alloc] initWithLength:kReadBufferSize];
      ssize_t len = recv(_socket, data.mutableBytes, data.length, 0);
      if (len >= 0) {
        data.length = len;
      } else {
        if (errno != EAGAIN) {
          _LOG_ERROR(@"Failed reading synchronously from socket: %s", strerror(errno));
        }
        data = nil;
      }
    }
  });
  return data;
}

- (void)_readBufferAsynchronously:(void (^)(dispatch_data_t buffer))completion {
  dispatch_sync(_lockQueue, ^{
    if (_state == kXLTCPConnectionState_Opened) {
      dispatch_read(_socket, SIZE_MAX, GN_GLOBAL_DISPATCH_QUEUE, ^(dispatch_data_t data, int error) {
        @autoreleasepool {
          
          if (error) {
            _LOG_ERROR(@"Failed reading asynchronously from socket: %s", strerror(error));
            if (completion) {
              completion(NULL);
            }
          } else if (completion) {
            completion(data);
          }
          
        }
      });
    } else if (completion) {
      dispatch_async(GN_GLOBAL_DISPATCH_QUEUE, ^{
        @autoreleasepool {
          completion(NULL);
        }
      });
    }
  });
}

- (void)readDataAsynchronously:(void (^)(NSData* data))completion {
  [self _readBufferAsynchronously:^(dispatch_data_t buffer) {
    if (buffer) {
      NSMutableData* data = [[NSMutableData alloc] init];
      dispatch_data_apply(buffer, ^bool(dispatch_data_t region, size_t offset, const void* bytes, size_t length) {
        [data appendBytes:bytes length:length];
        return true;
      });
      completion(data);
    } else {
      completion(nil);
    }
  }];
}

- (BOOL)_writeBytes:(const void*)bytes length:(size_t)length withTimeout:(NSTimeInterval)timeout {
  __block BOOL result = NO;
  dispatch_sync(_lockQueue, ^{
    if (_state == kXLTCPConnectionState_Opened) {
      struct timeval tv;
      tv.tv_sec = timeout;
      tv.tv_usec = fmod(timeout * 1000000.0, 1.0);
      [self _setSocketOption:SO_SNDTIMEO valuePtr:&tv valueLength:sizeof(tv)];
      
      ssize_t len = send(_socket, bytes, length, 0);
      if (len == (ssize_t)length) {
        result = YES;
      } else if (errno != EAGAIN) {
        _LOG_ERROR(@"Failed writing synchronously to socket: %s", strerror(errno));
      }
    }
  });
  return result;
}

- (BOOL)writeData:(NSData*)data withTimeout:(NSTimeInterval)timeout {
  return [self _writeBytes:data.bytes length:data.length withTimeout:timeout];
}

- (void)_writeBufferAsynchronously:(dispatch_data_t)buffer completion:(void (^)(BOOL success))completion {
  dispatch_sync(_lockQueue, ^{
    if (_state == kXLTCPConnectionState_Opened) {
      dispatch_write(_socket, buffer, GN_GLOBAL_DISPATCH_QUEUE, ^(dispatch_data_t data, int error) {
        @autoreleasepool {
          
          if (error) {
            if (error != EPIPE) {
              _LOG_ERROR(@"Failed writing asynchronously to socket: %s", strerror(error));
            }
            if (completion) {
              completion(NO);
            }
          } else if (completion) {
            completion(YES);
          }
          
        }
      });
    } else if (completion) {
      dispatch_async(GN_GLOBAL_DISPATCH_QUEUE, ^{
        @autoreleasepool {
          completion(NO);
        }
      });
    }
  });
}

- (void)writeDataAsynchronously:(NSData*)data completion:(void (^)(BOOL success))completion {
  dispatch_data_t buffer = dispatch_data_create(data.bytes, data.length, GN_GLOBAL_DISPATCH_QUEUE, ^{
    [data self];  // Keeps ARC from releasing data too early
  });
  [self _writeBufferAsynchronously:buffer completion:completion];
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(buffer);
#endif
}

- (void)close {
  __block BOOL didClose = NO;
  dispatch_sync(_lockQueue, ^{
    if (_state == kXLTCPConnectionState_Opened) {
      close(_socket);
      _socket = -1;
      _state = kXLTCPConnectionState_Closed;
      didClose = YES;
    }
  });
  if (didClose) {
    [self didClose];
  }
}

@end

@implementation GCDTCPConnection (Subclassing)

- (void)didOpen {
  _LOG_DEBUG(@"%@ did open over %s from %@ (%i) to %@ (%i)", [self class], self.usingIPv6 ? "IPv6" : "IPv4", self.localIPAddress, (int)self.localPort, self.remoteIPAddress, (int)self.remotePort);
}

- (void)didClose {
  _LOG_DEBUG(@"%@ did close over %s from %@ (%i) to %@ (%i)", [self class], self.usingIPv6 ? "IPv6" : "IPv4", self.localIPAddress, (int)self.localPort, self.remoteIPAddress, (int)self.remotePort);
}

@end

@implementation GCDTCPConnection (Extensions)

- (BOOL)isUsingIPv6 {
  const struct sockaddr* localSockAddr = _localAddressData.bytes;
  return (localSockAddr->sa_family == AF_INET6);
}

- (NSUInteger)localPort {
  return _PortFromAddressData(_localAddressData.bytes);
}

- (NSString*)localIPAddress {
  return _IPAddressFromAddressData(_localAddressData.bytes);
}

- (NSUInteger)remotePort {
  return _PortFromAddressData(_remoteAddressData.bytes);
}

- (NSString*)remoteIPAddress {
  return _IPAddressFromAddressData(_remoteAddressData.bytes);
}

- (BOOL)writeBuffer:(const void*)buffer length:(NSUInteger)length withTimeout:(NSTimeInterval)timeout {
  return [self _writeBytes:buffer length:length withTimeout:timeout];
}

- (BOOL)writeCString:(const char*)string withTimeout:(NSTimeInterval)timeout {
  return [self _writeBytes:string length:strlen(string) withTimeout:timeout];
}

- (BOOL)writeString:(NSString*)string withTimeout:(NSTimeInterval)timeout {
  return [self writeData:[string dataUsingEncoding:NSUTF8StringEncoding] withTimeout:timeout];
}

- (void)writeStringAsynchronously:(NSString*)string completion:(void (^)(BOOL success))completion {
  [self writeDataAsynchronously:[string dataUsingEncoding:NSUTF8StringEncoding] completion:completion];
}

@end
