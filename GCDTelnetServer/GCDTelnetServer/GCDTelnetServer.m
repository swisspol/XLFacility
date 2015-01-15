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

#import "GCDTelnetPrivate.h"

/* Information Sources
 
 - http://support.microsoft.com/kb/231866
 - http://pcmicro.com/netfoss/telnet.html
 - http://mud-dev.wikidot.com/telnet:negotiation
 - http://tintin.sourceforge.net/mtts/
 
 */

/* Telnet Option Negotiation
 
 Sender Sent    Receiver Responds     Implication
 WILL           DO                    The sender would like to use a certain facility if the receiver can handle it. Option is now in effect.
 WILL           DONT                  Receiver says it cannot support the option.	Option is not in effect.
 DO             WILL                  The sender says it can handle traffic from the sender if the sender wishes to use a certain option. Option is now in effect.
 DO             WONT                  Receiver says it cannot support the option. Option is not in effect.
 WONT           DONT                  Option disabled. DONT is only valid response.
 DONT           WONT                  Option disabled. WONT is only valid response.
 
 */

/* Telnet Built-in CLT from OS X 10.10
 
 -> IAC, WILL, Echo,
 <- IAC, DO, Echo,
 
 -> IAC, WILL, Supress Go Ahead,
 <- IAC, DO, Supress Go Ahead,
 
 -> IAC, WILL, Status,
 <- IAC, DO, Status,
 
 (no response for Timing Mark)
 
 -> IAC, WILL, Terminal Type,
 <- IAC, DONT, Terminal Type,
 
 -> IAC, WILL, Window Size,
 <- IAC, DONT, Window Size,
 
 -> IAC, WILL, Terminal Speed,
 <- IAC, DONT, Terminal Speed,
 
 -> IAC, WILL, Remote Flow Control,
 <- IAC, DONT, Remote Flow Control,
 
 -> IAC, WILL, Linemode,
 <- IAC, DONT, Linemode,
 
 -> IAC, WILL, Environment Variables,
 <- IAC, DONT, Environment Variables,
 
 */

/* Telnet Built-in CLT from OS X 10.10
 
 -> IAC, DO, Echo,
 <- IAC, WONT, Echo,
 
 -> IAC, DO, Supress Go Ahead,
 <- IAC, WILL, Supress Go Ahead,
 
 -> IAC, DO, Status,
 <- IAC, WONT, Status,
 
 -> IAC, DO, Timing Mark,
 <- IAC, WILL, Timing Mark,
 
 -> IAC, DO, Terminal Type,
 <- IAC, WILL, Terminal Type,
 
 -> IAC, DO, Window Size,
 <- IAC, WILL, Window Size, IAC, SB, Window Size, 0 208 0 42, IAC, SE,
 
 -> IAC, DO, Terminal Speed,
 <- IAC, WILL, Terminal Speed,
 
 -> IAC, DO, Remote Flow Control,
 <- IAC, WILL, Remote Flow Control,
 
 -> IAC, DO, Linemode,
 <- IAC, DO, Supress Go Ahead, IAC, WILL, Linemode, IAC, SB, Linemode, 3 1 3 0 3 98 3 4 2 15 5 2 20 7 98 28 8 2 4 9 66 26 10 2 127 11 2 21 12 2 23 13 2 18 14 2 22 15 2 17 16 2 19 17 0 255 255 18 0 255 255, IAC, SE,
 
 -> IAC, DO, Environment Variables, 
 <- IAC, WONT, Environment Variables,
 
 */

@implementation GCDTelnetServer

- (instancetype)initWithConnectionClass:(Class)connectionClass port:(NSUInteger)port {
  return [self initWithConnectionClass:connectionClass port:port startHandler:NULL lineHandler:NULL];
}

- (instancetype)initWithPort:(NSUInteger)port startHandler:(GCDTelnetStartHandler)startHandler lineHandler:(GCDTelnetLineHandler)lineHandler {
  return [self initWithConnectionClass:[GCDTelnetConnection class] port:port startHandler:startHandler lineHandler:lineHandler];
}

- (instancetype)initWithPort:(NSUInteger)port startHandler:(GCDTelnetStartHandler)startHandler commandHandler:(GCDTelnetCommandHandler)commandHandler {
  return [self initWithPort:port startHandler:startHandler lineHandler:^NSString*(GCDTelnetConnection* connection, NSString* line) {
    NSArray* array = [connection parseLineAsCommandAndArguments:line];
    NSString* command = array[0];
    NSArray* arguments = [array subarrayWithRange:NSMakeRange(1, array.count - 1)];
    return commandHandler(connection, command, arguments);
  }];
}

- (instancetype)initWithConnectionClass:(Class)connectionClass
                                   port:(NSUInteger)port
                           startHandler:(GCDTelnetStartHandler)startHandler
                            lineHandler:(GCDTelnetLineHandler)lineHandler {
  _LOG_DEBUG_CHECK([connectionClass isSubclassOfClass:[GCDTelnetConnection class]]);
  if ((self = [super initWithConnectionClass:connectionClass port:port])) {
    _startHandler = startHandler;
    _lineHandler = lineHandler;
  }
  return self;
}

@end
