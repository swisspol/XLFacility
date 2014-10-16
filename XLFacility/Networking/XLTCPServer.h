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

@end

/**
 *  The XLTCPServer is a base class that implements a TCP server. It listens for
 *  IPv4 or IPv6 TCP connections on a port and then creates XLTCPServerConnection
 *  instances for each.
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
 *  Returns YES if the server is running.
 */
@property(nonatomic, readonly, getter=isRunning) BOOL running;

/**
 *  Returns all currently opened server connections.
 */
@property(nonatomic, readonly) NSSet* connections;

#if TARGET_OS_IPHONE
/**
 *  Sets if the server automatically stops and starts while entering background
 *  and foreground on iOS.
 *
 *  When an app enters background on iOS and is suspended, it cannot leave
 *  listening sockets open, so it must either close them or start a background
 *  task to prevent the app from getting suspended while in background.
 *
 *  If this property is set to NO then the server will automatically create a
 *  background task when it is started and end it when it is stopped. Note that
 *  this task can only run for a limited time while the app is in background
 *  before iOS eventually force ends it. At this point the server will be stopped
 *  no matter what.
 *
 *  The default value is NO.
 */
@property(nonatomic) BOOL suspendInBackground;
#endif

/**
 *  This method is the designated initializer for the class.
 *
 *  Connection class must be [XLTCPServerConnection class] or a subclass of it.
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
