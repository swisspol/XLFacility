/*
 Copyright (c) 2012-2014, Pierre-Olivier Latour
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

#import "GCDTelnetConnection.h"

/**
 *  The GCDTelnetStartHandler is called by the Telnet server whenever a new
 *  connection is open with a remote terminal.
 *
 *  The handler can return a string (or nil) to be sent to the terminal.
 *  Note that the string will be converted to ASCII characters.
 *
 *  @warning This block will be executed on arbitrary threads.
 */
typedef NSString* (^GCDTelnetStartHandler)(GCDTelnetConnection* connection);

/**
 *  The GCDTelnetLineHandler is called whenever a new line has been received
 *  from the connected terminal.
 *
 *  The handler can return a string (or nil) to be sent back to the terminal.
 *  Note that the string will be converted to ASCII characters.
 *
 *  @warning This block will be executed on arbitrary threads.
 */
typedef NSString* (^GCDTelnetLineHandler)(GCDTelnetConnection* connection, NSString* line);

/**
 *  The GCDTelnetCommandHandler is a special line handler that pre-parses the
 *  line like a command line interface extracting the command and arguments.
 *
 *  @warning This block will be executed on arbitrary threads.
 */
typedef NSString* (^GCDTelnetCommandHandler)(GCDTelnetConnection* connection, NSString* command, NSArray* arguments);

/**
 *  The GCDTelnetServer class implements a Telnet server.
 */
@interface GCDTelnetServer : GCDTCPServer

/**
 *  Initializes a Telnet server on a given port and using the default
 *  GCDTelnetConnection class.
 */
- (instancetype)initWithPort:(NSUInteger)port startHandler:(GCDTelnetStartHandler)startHandler lineHandler:(GCDTelnetLineHandler)lineHandler;

/**
 *  Initializes a Telnet server on a given port and using the default
 *  GCDTelnetConnection class but with a command handler instead of a line hander.
 */
- (instancetype)initWithPort:(NSUInteger)port startHandler:(GCDTelnetStartHandler)startHandler commandHandler:(GCDTelnetCommandHandler)commandHandler;

/**
 *  This method is the designated initializer for the class.
 *
 *  Connection class must be [GCDTelnetConnection class] or a subclass of it.
 */
- (instancetype)initWithConnectionClass:(Class)connectionClass
                                   port:(NSUInteger)port
                           startHandler:(GCDTelnetStartHandler)startHandler
                            lineHandler:(GCDTelnetLineHandler)lineHandler;

@end
