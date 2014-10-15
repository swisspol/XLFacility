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

#import "XLTCPConnection.h"

@class XLTCPServer;

/**
 *  The XLTCPServerConnection is an abstract class to implement connections
 *  for XLTCPServer: it cannot be used directly.
 */
@interface XLTCPServerConnection : XLTCPConnection

/**
 *  Returns the XLTCPServer that owns the connection.
 *
 *  @warning This returns nil after the connection has been closed.
 */
@property(nonatomic, assign, readonly) XLTCPServer* server;

/**
 *  Called by XLTCPServer to open the connection after it has been created.
 *
 *  Default implementation does nothing but subclasses could override this method
 *  to start reading or writing to the socket.
 */
- (void)open;

/**
 *  Called by XLTCPServer to close the connection if it's still
 *  opened when the logger is being closed.
 *
 *  Subclasses can call this method directly to close the connection at any
 *  point in time.
 */
- (void)close;

@end

/**
 *  The XLTCPServer is a class that implements a basic TCP server.
 *
 *  It listens for IPv4 or IPv6 TCP connections on a port and then creates
 *  XLTCPServerConnection instances for each.
 *
 *  @warning On iOS, connecting to the server will not work while your app has
 *  been suspended by the OS while in background.
 */
@interface XLTCPServer : NSObject

/**
 *  Returns the connection class as specified when the server was initialized.
 */
@property(nonatomic, readonly) Class connectionClass;

/**
 *  Returns the port as specified when the server was initialized.
 */
@property(nonatomic, readonly) NSUInteger port;

/**
 *  Returns all currently opened server connections.
 */
@property(nonatomic, readonly) NSSet* connections;

/**
 *  This method is the designated initializer for the class.
 *
 *  Connection class must be [XLTCPServerConnection class] or a subclass of it.
 *
 *  @warning The TCP server until -start has been called.
 */
- (instancetype)initWithConnectionClass:(Class)connectionClass port:(NSUInteger)port;

/**
 *  Starts the server.
 *
 *  Returns NO on error.
 */
- (BOOL)start;

/**
 *  Stops the server.
 *
 *  @warning This blocks until all opened connections have been closed.
 */
- (void)stop;

@end

@interface XLTCPServer (Subclassing)

/**
 *  This method is called whenever a new connection is opened.
 *
 *  @warning This method can be called on arbitrary threads.
 */
- (void)willOpenConnection:(XLTCPServerConnection*)connection;

/**
 *  This method is called after a connection has been closed.
 *
 *  @warning This method can be called on arbitrary threads.
 */
- (void)didCloseConnection:(XLTCPServerConnection*)connection;

@end

@interface XLTCPServer (Extensions)

/**
 *  Enumerates all currently opened server connections.
 */
- (void)enumerateConnectionsUsingBlock:(void (^)(XLTCPServerConnection* connection, BOOL* stop))block;

@end
