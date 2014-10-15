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

#import "XLTCPConnection.h"
#import "XLPrivate.h"

#define kDispatchQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)

typedef union {
  struct sockaddr addr;
  struct sockaddr_in addr4;
  struct sockaddr_in6 addr6;
} SocketAddress;

@implementation XLTCPConnection

static int _CreateConnectedSocket(NSString* hostname, const struct sockaddr* addr, socklen_t len, NSTimeInterval timeout, BOOL isIPv6) {
  int connectedSocket = socket(isIPv6 ? PF_INET6 : PF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (connectedSocket >= 0) {
    BOOL success = NO;
    fcntl(connectedSocket, F_SETFL, O_NONBLOCK);
    
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
            XLOG_INTERNAL(@"Failed connecting %s socket to \"%@\" (%@): %s", isIPv6 ? "IPv6" : "IPv4", hostname, XLFacilityStringFromIPAddress(addr), strerror(error));
          }
        } else {
          XLOG_INTERNAL(@"Failed retrieving %s socket option: %s", isIPv6 ? "IPv6" : "IPv4", strerror(errno));
        }
        
      } else if (result == 0) {
        XLOG_INTERNAL(@"Timed out connecting %s socket to \"%@\" (%@)", isIPv6 ? "IPv6" : "IPv4", hostname, XLFacilityStringFromIPAddress(addr));
      }
    } else {
      XLOG_INTERNAL(@"Failed connecting %s socket to \"%@\" (%@): %s", isIPv6 ? "IPv6" : "IPv4", hostname, XLFacilityStringFromIPAddress(addr), strerror(errno));
    }
    
    if (success) {
      fcntl(connectedSocket, F_SETFL, 0);
    } else {
      close(connectedSocket);
      connectedSocket = -1;
    }
  } else {
    XLOG_INTERNAL(@"Failed creating %s socket: %s", isIPv6 ? "IPv6" : "IPv4", strerror(errno));
  }
  return connectedSocket;
}

+ (void)connectAsynchronouslyToHost:(NSString*)hostname port:(NSUInteger)port timeout:(NSTimeInterval)timeout completion:(void (^)(XLTCPConnection* connection))completion {
  dispatch_async(kDispatchQueue, ^{
    XLTCPConnection* connection = nil;
    
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
          int socket = _CreateConnectedSocket(hostname, &address.addr, address.addr.sa_len, timeout, address.addr.sa_family == AF_INET6);
          if (socket > 0) {
            connection = [[self alloc] initWithSocket:socket];
            if (connection) {
              break;
            } else {
              XLOG_INTERNAL(@"Failed creating %@ instance with connected socket", NSStringFromClass([self class]));
              close(socket);
            }
          }
          
        }
      }
    } else {
      XLOG_INTERNAL(@"Failed resolving host \"%@\": (%i, %i)", hostname, (int)error.domain, (int)error.error);
    }
    CFRelease(host);
    
    completion(connection);
  });
}

- (id)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithSocket:(int)socket {
  if ((self = [super init])) {
    _socket = socket;
    
    int noSigPipe = 1;
    setsockopt(_socket, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, sizeof(noSigPipe));  // Make sure this socket cannot generate SIG_PIPE when closed
    
    int keepAlive = 1;
    setsockopt(socket, SOL_SOCKET, SO_KEEPALIVE, &keepAlive, sizeof(keepAlive));
    
    struct sockaddr localSockAddr;
    socklen_t localAddrLen = sizeof(localSockAddr);
    if (getsockname(_socket, &localSockAddr, &localAddrLen) == 0) {
      _localAddressData = [[NSData alloc] initWithBytes:&localSockAddr length:localAddrLen];
    } else {
      XLOG_INTERNAL(@"Failed retrieving local socket address: %s", strerror(errno));
    }
    
    struct sockaddr remoteSockAddr;
    socklen_t remoteAddrLen = sizeof(remoteSockAddr);
    if (getsockname(_socket, &remoteSockAddr, &remoteAddrLen) == 0) {
      _remoteAddressData = [[NSData alloc] initWithBytes:&remoteSockAddr length:remoteAddrLen];
    } else {
      XLOG_INTERNAL(@"Failed retrieving remote socket address: %s", strerror(errno));
    }
  }
  return self;
}

- (void)readBufferAsynchronously:(void (^)(dispatch_data_t buffer))completion {
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

- (void)close {
  close(_socket);
  _socket = 0;
}

@end

@implementation XLTCPConnection (Extensions)

- (BOOL)isClosed {
  return (_socket <= 0);
}

- (BOOL)isUsingIPv6 {
  const struct sockaddr* localSockAddr = _localAddressData.bytes;
  return (localSockAddr->sa_family == AF_INET6);
}

- (NSString*)localAddressString {
  return XLFacilityStringFromIPAddress(_localAddressData.bytes);
}

- (NSString*)remoteAddressString {
  return XLFacilityStringFromIPAddress(_remoteAddressData.bytes);
}

- (void)readDataAsynchronously:(void (^)(NSData* data))completion {
  [self readBufferAsynchronously:^(dispatch_data_t buffer) {
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
