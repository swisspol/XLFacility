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

#import "XLTCPServerLogger.h"

/**
 *  The XLTelnetServerLogger class runs a Telnet-like server you can connect to
 *  using "$ telnet IP_ADDRESS PORT" from a terminal. Log records received by
 *  the logger are then printed directly in the connected terminal.
 *
 *  XLTelnetServerLogger can optionally preserve the history of log records
 *  received since the logger was opened. If this feature is enabled, when
 *  connecting to the server, all past log records are initially printed in the
 *  terminal.
 */
@interface XLTelnetServerLogger : XLTCPServerLogger

/**
 *  Configures if the Telnet server is sending colored text output using ANSI
 *  escape codes. This requires a color terminal.
 *
 *  The default value is YES.
 */
@property(nonatomic) BOOL shouldColorize;

/**
 *  Configures how long the Telnet server should wait (and therefore potentially
 *  block XLFacility) when sending a log message to an unresponsive terminal
 *  before disconnecting it.
 *
 *  If the timeout is zero, the Telnet server will block indefinitely. If the
 *  timeout is negative, log messages will be sent asynchronously.
 *
 *  The default value is -1.0.
 */
@property(nonatomic) NSTimeInterval sendTimeout;

/**
 *  Initializes a Telnet server on port 2323 that preserves history.
 */
- (instancetype)init;

/**
 *  This method is the designated initializer for the class.
 *
 *  @warning The Telnet server is not running until the logger is opened.
 */
- (instancetype)initWithPort:(NSUInteger)port preserveHistory:(BOOL)preserveHistory;

@end
