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

#import "GCDTCPPeer.h"

@class GCDTCPServer;

/**
 *  The GCDTCPServerConnection is an abstract class to implement connections
 *  for GCDTCPServer: it cannot be used directly.
 */
@interface GCDTCPServerConnection : GCDTCPPeerConnection
@end

/**
 *  The GCDTCPServer is a base class that implements a TCP server. It listens for
 *  IPv4 or IPv6 TCP connections on a port and then creates GCDTCPServerConnection
 *  instances for each.
 *
 *  @warning On iOS, connecting to the server will not work while your app has
 *  been suspended by the OS while in background.
 */
@interface GCDTCPServer : GCDTCPPeer

/**
 *  Returns the port as specified when the server was initialized.
 */
@property(nonatomic, readonly) NSUInteger port;

/**
 *  This method is the designated initializer for the class.
 *
 *  Connection class must be [GCDTCPServerConnection class] or a subclass of it.
 */
- (instancetype)initWithConnectionClass:(Class)connectionClass port:(NSUInteger)port;

@end
