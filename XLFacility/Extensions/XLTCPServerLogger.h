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

#import "XLDatabaseLogger.h"

@class XLTCPServerLogger;

/**
 *  The XLTCPServerConnection is an abstract class to implement connections
 *  for XLTCPServerLogger: it cannot be used directly.
 */
@interface XLTCPServerConnection : NSObject

/**
 *  Returns the XLTCPServerLogger that owns the connection.
 *
 *  @warning This returns nil after the connection has been closed.
 */
@property(nonatomic, assign, readonly) XLTCPServerLogger* server;

/**
 *  Returns the address of the local peer (i.e. server) of the connection
 *  as a raw "struct sockaddr".
 */
@property(nonatomic, readonly) NSData* localAddressData;

/**
 *  Returns the address of the remote peer (i.e. client) of the connection
 *  as a raw "struct sockaddr".
 */
@property(nonatomic, readonly) NSData* remoteAddressData;

/**
 *  Returns the underlying socket for the connection.
 *
 *  @warning Do not close the socket directly but use the -close method instead.
 */
@property(nonatomic, readonly) int socket;

/**
 *  Called by XLTCPServerLogger to open the connection after it has been created.
 *
 *  Default implementation does nothing but subclasses could override this method
 *  to start reading from the socket.
 */
- (void)open;

/**
 *  Called by XLTCPServerLogger to close the connection if it's still
 *  opened when the logger is being closed.
 *
 *  Subclasses can call this method directly to close the connection at any
 *  point in time.
 */
- (void)close;

@end

@interface XLTCPServerConnection (Extensions)

/**
 *  Returns the address of the local peer (i.e. server) of the connection
 *  as a dotted string.
 */
@property(nonatomic, readonly) NSString* localAddressString;

/**
 *  Returns the address of the remote peer (i.e. client) of the connection
 *  as a dotted string.
 */
@property(nonatomic, readonly) NSString* remoteAddressString;

/**
 *  Convenience method to read data asynchronously from the socket.
 *
 *  @warning The connection will be automatically closed on error right after
 *  the completion block has been called.
 */
- (void)readDataAsynchronously:(void (^)(dispatch_data_t data))completion;

/**
 *  Convenience method to write a buffer asynchronously to the socket.
 *
 *  @warning The connection will be automatically closed on error right after
 *  the completion block has been called.
 */
- (void)writeBufferAsynchronously:(dispatch_data_t)buffer completion:(void (^)(BOOL success))completion;

/**
 *  Convenience method to write data asynchronously to the socket.
 *
 *  @warning The connection will be automatically closed on error right after
 *  the completion block has been called.
 */
- (void)writeDataAsynchronously:(NSData*)data completion:(void (^)(BOOL success))completion;

/**
 *  Convenience method to write a C string asynchronously to the socket.
 *
 *  @warning The connection will be automatically closed on error right after
 *  the completion block has been called.
 */
- (void)writeCStringAsynchronously:(const char*)string completion:(void (^)(BOOL success))completion;

@end

/**
 *  The XLTCPServerLogger subclass of XLLogger is an abstract class for loggers
 *  that implement TCP servers: it cannot be used directly.
 *
 *  XLTCPServerLogger can optionally use a XLDatabaseLogger instance internally
 *  with a temporary database to preserve the history of log records received
 *  since the logger was opened.
 *
 *  @warning On iOS, connecting to the server will not work while your app has
 *  been suspended by the OS while in background.
 */
@interface XLTCPServerLogger : XLLogger

/**
 *  Returns the port as specified when the logger was initialized.
 */
@property(nonatomic, readonly) NSUInteger port;

/**
 *  Returns the XLDatabaseLogger used internally if any.
 */
@property(nonatomic, readonly) XLDatabaseLogger* databaseLogger;

/**
 *  Returns all currently opened server connections.
 */
@property(nonatomic, readonly) NSSet* connections;

/**
 *  Returns the class to use to instantiate server connections.
 *
 *  The default implementation returns [XLTCPServerConnection class].
 */
+ (Class)connectionClass;

/**
 *  This method is the designated initializer for the class.
 *
 *  @warning The TCP server is not running until the logger is opened.
 */
- (instancetype)initWithPort:(NSUInteger)port useDatabaseLogger:(BOOL)useDatabaseLogger;

/**
 *  Enumerates all currently opened server connections.
 */
- (void)enumerateConnectionsUsingBlock:(void (^)(XLTCPServerConnection* connection, BOOL* stop))block;

@end
