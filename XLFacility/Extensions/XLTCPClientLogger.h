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
#import "GCDTCPClient.h"

/**
 *  The XLTCPClientLogger class is a base class for loggers that connect to TCP
 *  servers.
 *
 *  It simply sends log records formatted as a string to the server.
 *
 *  XLTCPClientLogger can optionally preserve the history of log records
 *  received since the logger was opened. If this feature is enabled, when
 *  connecting to the TCP server, all past log records are sent before any new
 *  ones.
 */
@interface XLTCPClientLogger : XLLogger

/**
 *  Returns the XLTCPClient used internally.
 */
@property(nonatomic, readonly) GCDTCPClient* TCPClient;

/**
 *  Returns the XLDatabaseLogger used internally if any.
 */
@property(nonatomic, readonly) XLDatabaseLogger* databaseLogger;

/**
 *  Configures how long the TCP client should wait (and therefore potentially
 *  block XLFacility) when sending a log message to an unresponsive server
 *  before disconnecting it.
 *
 *  If the timeout is zero, the TCP client will block indefinitely. If the
 *  timeout is negative, log messages will be sent asynchronously.
 *
 *  The default value is -1.0.
 */
@property(nonatomic) NSTimeInterval sendTimeout;

/**
 *  Returns the class to use to instantiate the client.
 *
 *  The default implementation returns [GCDTCPClient class].
 */
+ (Class)clientClass;

/**
 *  Returns the class to use to instantiate client connections.
 *
 *  The default implementation returns [GCDTCPClientConnection class].
 */
+ (Class)connectionClass;

/**
 *  This method is the designated initializer for the class.
 *
 *  @warning The TCP client is not running until the logger is opened.
 */
- (instancetype)initWithHost:(NSString*)hostname port:(NSUInteger)port preserveHistory:(BOOL)preserveHistory;

@end

@interface GCDTCPClientConnection (XLTCPClientLogger)

/**
 *  Returns the XLTCPClientLogger that owns the connection.
 *
 *  @warning This returns nil after the connection has been closed.
 */
@property(nonatomic, assign, readonly) XLTCPClientLogger* logger;

@end
