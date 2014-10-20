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

#define kMaxPendingConnections 4

@implementation GCDTCPServerConnection
@end

@interface GCDTCPServer () {
@private
  dispatch_group_t _sourceGroup;
  dispatch_source_t _source4;
  dispatch_source_t _source6;
}
@end

@implementation GCDTCPServer

- (instancetype)initWithConnectionClass:(Class)connectionClass port:(NSUInteger)port {
  _LOG_DEBUG_CHECK([connectionClass isSubclassOfClass:[GCDTCPServerConnection class]]);
  if ((self = [super initWithConnectionClass:connectionClass])) {
    _port = port;
    
    _sourceGroup = dispatch_group_create();
  }
  return self;
}

#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE

- (void)dealloc {
  dispatch_release(_sourceGroup);
}

#endif

- (int)_createListeningSocket:(BOOL)useIPv6 localAddress:(const void*)address length:(socklen_t)length {
  int listeningSocket = socket(useIPv6 ? PF_INET6 : PF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (listeningSocket >= 0) {
    int yes = 1;
    setsockopt(listeningSocket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    
    if (bind(listeningSocket, address, length) == 0) {
      if (listen(listeningSocket, kMaxPendingConnections) == 0) {
        return listeningSocket;
      } else {
        _LOG_ERROR(@"Failed starting %s listening socket: %s", useIPv6 ? "IPv6" : "IPv4", strerror(errno));
        close(listeningSocket);
      }
    } else {
      _LOG_ERROR(@"Failed binding %s listening socket: %s", useIPv6 ? "IPv6" : "IPv4", strerror(errno));
      close(listeningSocket);
    }
  } else {
    _LOG_ERROR(@"Failed creating %s listening socket: %s", useIPv6 ? "IPv6" : "IPv4", strerror(errno));
  }
  return -1;
}

- (dispatch_source_t)_createDispatchSourceWithListeningSocket:(int)listeningSocket isIPv6:(BOOL)isIPv6 {
  dispatch_group_enter(_sourceGroup);
  dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, listeningSocket, 0, GN_GLOBAL_DISPATCH_QUEUE);
  dispatch_source_set_cancel_handler(source, ^{
    close(listeningSocket);
    dispatch_group_leave(_sourceGroup);
  });
  dispatch_source_set_event_handler(source, ^{
    @autoreleasepool {
      
      struct sockaddr remoteSockAddr;
      socklen_t remoteAddrLen = sizeof(remoteSockAddr);
      int socket = accept(listeningSocket, &remoteSockAddr, &remoteAddrLen);
      if (socket >= 0) {
        GCDTCPServerConnection* connection = [[self.connectionClass alloc] initWithSocket:socket];
        if (connection) {
          [self willOpenConnection:connection];
        } else {
          _LOG_ERROR(@"Failed creating %@ instance", NSStringFromClass(self.connectionClass));
          close(socket);
        }
      } else {
        _LOG_ERROR(@"Failed accepting %s socket: %s", isIPv6 ? "IPv6" : "IPv4", strerror(errno));
      }
      
    }
  });
  return source;
}

- (BOOL)willStart {
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
  
  if ((listeningSocket4 < 0) || (listeningSocket6 < 0)) {
    close(listeningSocket4);
    close(listeningSocket6);
    return NO;
  }
  
  _source4 = [self _createDispatchSourceWithListeningSocket:listeningSocket4 isIPv6:NO];
  dispatch_resume(_source4);
  
  _source6 = [self _createDispatchSourceWithListeningSocket:listeningSocket6 isIPv6:YES];
  dispatch_resume(_source6);
  
  return YES;
}

- (void)didStop {
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
}

@end
