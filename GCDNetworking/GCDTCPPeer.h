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

#import "GCDTCPConnection.h"

@class GCDTCPPeer;

/**
 *  The GCDTCPPeerConnection is an abstract class to implement connections
 *  for GCDTCPPeer: it cannot be used directly.
 */
@interface GCDTCPPeerConnection : GCDTCPConnection

/**
 *  Returns the GCDTCPPeer that owns the connection.
 *
 *  @warning This returns nil after the connection has been closed.
 */
@property(nonatomic, assign, readonly) GCDTCPPeer* peer;

@end

/**
 *  The GCDTCPPeer is an abstract class to implement TCP peers: it cannot be
 *  used directly.
 */
@interface GCDTCPPeer : NSObject

/**
 *  Returns the connection class as specified when the peer was initialized.
 */
@property(nonatomic, readonly) Class connectionClass;

/**
 *  Returns YES if the peer is running.
 */
@property(nonatomic, readonly, getter=isRunning) BOOL running;

/**
 *  Returns all currently opened connections.
 */
@property(nonatomic, readonly) NSSet* connections;

#if TARGET_OS_IPHONE
/**
 *  Sets if the peer automatically stops and starts while entering background
 *  and foreground on iOS.
 *
 *  When an app enters background on iOS and is suspended, it cannot leave
 *  listening sockets open, so it must either close them or start a background
 *  task to prevent the app from getting suspended while in background.
 *
 *  If this property is set to NO then the peer will automatically create a
 *  background task when it is started and end it when it is stopped. Note that
 *  this task can only run for a limited time while the app is in background
 *  before iOS eventually force ends it. At this point the peer will be stopped
 *  no matter what.
 *
 *  The default value is NO.
 */
@property(nonatomic) BOOL suspendInBackground;
#endif

/**
 *  This method is the designated initializer for the class.
 *
 *  Connection class must be [GCDTCPPeerConnection class] or a subclass of it.
 */
- (instancetype)initWithConnectionClass:(Class)connectionClass;

/**
 *  Starts the peer.
 *
 *  Returns NO on error.
 */
- (BOOL)start;

/**
 *  Stops the peer.
 *
 *  @warning This blocks until all opened connections have been closed.
 */
- (void)stop;

@end

@interface GCDTCPPeer (Subclassing)

/**
 *  Returns a GCD serial queue subclasses can use to protect internal data
 *  that can be accessed concurrently from multiple threads.
 */
@property(nonatomic, readonly) dispatch_queue_t lockQueue;

/**
 *  This method is called whenever the peer starts.
 *
 *  @warning This method can be called on arbitrary threads.
 */
- (BOOL)willStart;

/**
 *  This method is called whenever a new connection is opened.
 *
 *  @warning This method can be called on arbitrary threads.
 */
- (void)willOpenConnection:(GCDTCPPeerConnection*)connection;

/**
 *  This method is called after a connection has been closed.
 *
 *  @warning This method can be called on arbitrary threads.
 */
- (void)didCloseConnection:(GCDTCPPeerConnection*)connection;

/**
 *  This method is called whenever the peer stops.
 *
 *  @warning This method can be called on arbitrary threads.
 */
- (void)didStop;

@end

@interface GCDTCPPeer (Extensions)

/**
 *  Enumerates all currently opened connections.
 */
- (void)enumerateConnectionsUsingBlock:(void (^)(GCDTCPPeerConnection* connection, BOOL* stop))block;

@end
