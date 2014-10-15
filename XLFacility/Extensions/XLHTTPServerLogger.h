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
 *  The XLHTTPServerLogger runs a simple HTTP server you can connect to in your
 *  web browser by visiting "http://IP_ADDRESS:PORT/". Log records received by
 *  the logger are then printed directly in the connected.
 *
 *  XLHTTPServerLogger preserves the history of log records received since the
 *  logger was opened. When visiting the server URL, the webpage can therefore
 *  initially display all past log records.
 *
 *  XLHTTPServerLogger uses HTTP long-polling to automatically refresh the webpage
 *  when new log records are received by the logger.
 */
@interface XLHTTPServerLogger : XLTCPServerLogger

/**
 *  Initializes an HTTP server on port 8080.
 */
- (instancetype)init;

/**
 *  This method is the designated initializer for the class.
 *
 *  @warning The HTTP server is not running until the logger is opened.
 */
- (instancetype)initWithPort:(NSUInteger)port;

@end
