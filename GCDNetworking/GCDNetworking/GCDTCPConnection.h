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
#import <sys/socket.h>

/**
 *  Constants representing the state of a GCDTCPConnection.
 */
typedef NS_ENUM(int, GCDTCPConnectionState) {
  kXLTCPConnectionState_Closed = -1,
  kXLTCPConnectionState_Initialized = 0,
  kXLTCPConnectionState_Opened = 1
};

/**
 *  The GCDTCPConnection is a base class that handles TCP connections.
 */
@interface GCDTCPConnection : NSObject

/**
 *  Returns the state of the connection.
 */
@property(nonatomic, readonly) GCDTCPConnectionState state;

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
+ (void)connectAsynchronouslyToHost:(NSString*)hostname port:(NSUInteger)port timeout:(NSTimeInterval)timeout completion:(void (^)(GCDTCPConnection* connection))completion;

/**
 *  This method is the designated initializer for the class.
 *
 *  @warning The ownership of the socket is transferred to the connection.
 */
- (instancetype)initWithSocket:(int)socket;

/**
 *  Opens the connection (required before reading or writing from it).
 */
- (void)open;

/**
 *  Reads data synchronously to the socket.
 *
 *  Pass 0 as "timeout" to block indefinitely.
 */
- (NSData*)readDataWithTimeout:(NSTimeInterval)timeout;

/**
 *  Reads data asynchronously from the socket.
 */
- (void)readDataAsynchronously:(void (^)(NSData* data))completion;

/**
 *  Writes data synchronously to the socket.
 *
 *  Pass 0 as "timeout" to block indefinitely.
 */
- (BOOL)writeData:(NSData*)data withTimeout:(NSTimeInterval)timeout;

/**
 *  Writes data asynchronously to the socket.
 */
- (void)writeDataAsynchronously:(NSData*)data completion:(void (^)(BOOL success))completion;

/**
 *  Closes the connection.
 */
- (void)close;

@end

@interface GCDTCPConnection (Subclassing)

/**
 *  Called after the underlying socket was opened.
 *
 *  The default implementation does nothing.
 */
- (void)didOpen;

/**
 *  Called after the underlying socket was closed.
 *
 *  The default implementation does nothing.
 */
- (void)didClose;

@end

@interface GCDTCPConnection (Extensions)

/**
 *  Returns YES if the connection is using IPv6.
 */
@property(nonatomic, readonly, getter=isUsingIPv6) BOOL usingIPv6;

/**
 *  Returns the port of the local peer of the connection.
 */
@property(nonatomic, readonly) NSUInteger localPort;

/**
 *  Returns the IP address of the local peer of the connection as a string.
 */
@property(nonatomic, readonly) NSString* localIPAddress;

/**
 *  Returns the port of the remote peer of the connection.
 */
@property(nonatomic, readonly) NSUInteger remotePort;

/**
 *  Returns the IP address of the remote peer of the connection as a string.
 */
@property(nonatomic, readonly) NSString* remoteIPAddress;

/**
 *  Writes a buffer synchronously to the socket.
 */
- (BOOL)writeBuffer:(const void*)buffer length:(NSUInteger)length withTimeout:(NSTimeInterval)timeout;

/**
 *  Writes a NULL terminated string synchronously to the socket.
 */
- (BOOL)writeCString:(const char*)string withTimeout:(NSTimeInterval)timeout;

/**
 *  Writes string synchronously to the socket using UTF8 encoding.
 */
- (BOOL)writeString:(NSString*)string withTimeout:(NSTimeInterval)timeout;

/**
 *  Writes string asynchronously to the socket using UTF8 encoding.
 */
- (void)writeStringAsynchronously:(NSString*)string completion:(void (^)(BOOL success))completion;

@end
