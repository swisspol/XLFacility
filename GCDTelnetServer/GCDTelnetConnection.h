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

#import "GCDNetworking.h"

/**
 *  The GCDTelnetConnection class is the class used to implement connections
 *  for GCDTelnetServer.
 */
@interface GCDTelnetConnection : GCDTCPServerConnection

/*
 *  Returns the type of the remote terminal.
 *
 *  @warning This will only be non-nil if the connected peer responded to the
 *  corresponding Telnet command.
 */
@property(nonatomic, readonly) NSString* terminalType;

/*
 *  Returns YES if the remote terminal is a color one.
 */
@property(nonatomic, readonly, getter=isColorTerminal) BOOL colorTerminal;

/*
 *  Sets the prompt to show at the beginning of a new line.
 *
 *  Set this value to nil to remove the prompt entirely.
 *
 *  The default value is "> ".
 *
 *  @warning Setting this value to a non-ASCII string or changing it outside
 *  of the scope of the GCDTelnetServer start handler is not supported.
 */
@property(nonatomic, copy) NSString* prompt;

/*
 *  Sets the placeholder string inserted when the tab key is pressed.
 *
 *  The default value is "\t".
 *
 *  @warning Setting this value to a non-ASCII string or changing it outside
 *  of the scope of the GCDTelnetServer start handler is not supported.
 */
@property(nonatomic, copy) NSString* tabPlaceholder;

/*
 *  Sets the maximum number of lines preserved by the history.
 *
 *  Set this value to 0 to disable the history entirely.
 *
 *  The default value is NSIntegerMax i.e. unlimited.
 *
 *  @warning Changing this value outside of the scope of the GCDTelnetServer
 *  start handler is not supported.
 */
@property(nonatomic) NSUInteger maxHistorySize;

@end

@interface GCDTelnetConnection (Subclassing)

/*
 *  Direct access to the line buffer used by the connection.
 *
 *  @warning This string must only contain ASCII characters.
 */
@property(nonatomic, readonly) NSMutableString* lineBuffer;

/*
 *  Called whenever a new connection has started with a remote terminal.
 *
 *  The default implementation calls the GCDTelnetServer start handler.
 */
- (NSString*)start;

/*
 *  Called when the arrow up key is pressed.
 *
 *  The default implementation navigates the history towards older entries.
 */
- (NSData*)processCursorUp;

/*
 *  Called when the arrow up key is pressed.
 *
 *  The default implementation navigates the history towards newer entries.
 */
- (NSData*)processCursorDown;

/*
 *  Called when the arrow right key is pressed.
 *
 *  The default implementation just beeps.
 */
- (NSData*)processCursorForward;

/*
 *  Called when the arrow left key is pressed.
 *
 *  The default implementation just beeps.
 */
- (NSData*)processCursorBack;

/*
 *  Called when an unimplemented ANSI escape sequence has been received.
 *
 *  The default implementation just beeps.
 */
- (NSData*)processOtherANSIEscapeSequence:(NSData*)data;

/*
 *  Called when the tab key is pressed.
 *
 *  The default implementation inserts the tab placeholder string.
 */
- (NSData*)processTab;

/*
 *  Called when the delete key is pressed.
 *
 *  The default implementation deletes the last character.
 */
- (NSData*)processDelete;

/*
 *  Called when the return key is pressed.
 *
 *  The default implementation calls -processLine: and updates the history.
 */
- (NSData*)processCarriageReturn;

/*
 *  Called when any other ASCII character has been received.
 *
 *  The default implementation inserts the character.
 */
- (NSData*)processOtherASCIICharacter:(unsigned char)character;

/*
 *  Called when a non-ASCII character has been received.
 *
 *  The default implementation does nothing.
 */
- (NSData*)processNonASCIICharacter:(unsigned char)character;

/*
 *  Called whenever input data has been received from the remote terminal.
 *
 *  The default implementation parses the data and calls one of the other
 *  methods.
 */
- (NSData*)processRawInput:(NSData*)input;

/*
 *  Called whenever a line has been fully received from the remote terminal.
 *
 *  The default implementation calls the GCDTelnetServer line handler.
 */
- (NSString*)processLine:(NSString*)line;

@end

@interface GCDTelnetConnection (Extensions)

/**
 *  Parses a line like a command line interface extracting the command and
 *  arguments.
 *
 *  This methods supports quoted arguments using single or double quotes.
 */
- (NSArray*)parseLineAsCommandAndArguments:(NSString*)line;

/**
 *  Returns a sanitized version of a string suitable for sending to the remote
 *  terminal.
 *
 *  The current implementation replaces all newline characters by carriage
 *  returns.
 */
- (NSString*)sanitizeStringForTerminal:(NSString*)string;

/*
 *  Convenience methods that writes a string to the connection using lossy
 *  ASCII encoding.
 */
- (BOOL)writeASCIIString:(NSString*)string withTimeout:(NSTimeInterval)timeout;

/*
 *  Convenience methods that writes a formatted string to the connection using
 *  lossy ASCII encoding.
 */
- (void)writeASCIIStringAsynchronously:(NSString*)string completion:(void (^)(BOOL success))completion;

@end
