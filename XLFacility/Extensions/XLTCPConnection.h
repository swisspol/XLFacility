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

#import <Foundation/Foundation.h>

/**
 *  The XLTCPConnection is a convenience class to handle TCP
 *  connections.
 */
@interface XLTCPConnection : NSObject

/**
 *  Returns the address of the local peer of the connection
 *  as a raw "struct sockaddr".
 */
@property(nonatomic, readonly) NSData* localAddressData;

/**
 *  Returns the address of the remote peer of the connection
 *  as a raw "struct sockaddr".
 */
@property(nonatomic, readonly) NSData* remoteAddressData;

/**
 *  Returns the underlying socket for the connection.
 *
 *  This will be 0 if the connection has been closed.
 *
 *  @warning Do not close the socket directly but use the -close method instead.
 */
@property(nonatomic, readonly) int socket;

/**
 *  Opens a new connection to a host.
 *
 *  The returned connection will be nil on error.
 */
+ (void)connectAsynchronouslyToHost:(NSString*)hostname port:(NSUInteger)port timeout:(NSTimeInterval)timeout completion:(void (^)(XLTCPConnection* connection))completion;

/**
 *  This method is the designated initializer for the class.
 *
 *  @warning The ownership of the socket is transferred to the connection.
 */
- (instancetype)initWithSocket:(int)socket;

/**
 *  Reads a buffer asynchronously from the socket.
 *
 *  @warning The connection will be automatically closed on error right after
 *  the completion block has been called.
 */
- (void)readBufferAsynchronously:(void (^)(dispatch_data_t buffer))completion;

/**
 *  Writes a buffer asynchronously to the socket.
 *
 *  @warning The connection will be automatically closed on error right after
 *  the completion block has been called.
 */
- (void)writeBufferAsynchronously:(dispatch_data_t)buffer completion:(void (^)(BOOL success))completion;

/**
 *  Closes the connection.
 */
- (void)close;

@end

@interface XLTCPConnection (Extensions)

/**
 *  Returns YES if the connection is closed.
 */
@property(nonatomic, readonly, getter=isClosed) BOOL closed;

/**
 *  Returns YES if the connection is using IPv6.
 */
@property(nonatomic, readonly, getter=isUsingIPv6) BOOL usingIPv6;

/**
 *  Returns the address of the local peer of the connection
 *  as a string.
 */
@property(nonatomic, readonly) NSString* localAddressString;

/**
 *  Returns the address of the remote peer of the connection
 *  as a string.
 */
@property(nonatomic, readonly) NSString* remoteAddressString;

/**
 *  Reads data asynchronously from the socket.
 *
 *  @warning The connection will be automatically closed on error right after
 *  the completion block has been called.
 */
- (void)readDataAsynchronously:(void (^)(NSData* data))completion;

/**
 *  Writes data asynchronously to the socket.
 *
 *  @warning The connection will be automatically closed on error right after
 *  the completion block has been called.
 */
- (void)writeDataAsynchronously:(NSData*)data completion:(void (^)(BOOL success))completion;

/**
 *  Writes a C string asynchronously to the socket.
 *
 *  @warning The connection will be automatically closed on error right after
 *  the completion block has been called.
 */
- (void)writeCStringAsynchronously:(const char*)string completion:(void (^)(BOOL success))completion;

@end
