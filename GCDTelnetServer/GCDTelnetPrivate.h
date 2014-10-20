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

/**
 *  All GCDTelnetServer headers.
 */

#import "GCDTelnetServer.h"
#import "_LoggingBridgePrivate.h"

/**
 *  GCDTelnetServer internal constants and APIs.
 */

// Network Virtual Terminal control codes
typedef NS_ENUM(unsigned char, ControlCode) {
  
  // Required
  kControlCode_NUL = 0, // NULL - No operation
  kControlCode_LF = 10,  // Line Feed - Moves the printer to the next print line, keeping the same horizontal position.
  kControlCode_CR = 13,  // Carriage Return - Moves the printer to the left margin of the current line.
  
  // Optional
  kControlCode_BEL = 7,  // BELL - Produces an audible or visible signal (which does NOT move the print head).
  kControlCode_BS = 8,  // Back Space - Moves the print head one character position towards the left margin. (On a printing device, this mechanism was commonly used to form composite characters by printing two basic characters on top of each other.)
  kControlCode_HT = 9,  // Horizontal Tab - Moves the printer to the next horizontal tab stop. It remains unspecified how either party determines or establishes where such tab stops are located.
  kControlCode_VT = 11,  // Vertical Tab - Moves the printer to the next vertical tab stop. It remains unspecified how either party determines or establishes where such tab stops are located.
  kControlCode_FF = 12  // Form Feed - Moves the printer to the top of the next page, keeping the same horizontal position. (On visual displays, this commonly clears the screen and moves the cursor to the top left corner.)
  
};

// Telnet commands
typedef NS_ENUM(unsigned char, TelnetCommand) {
  kTelnetCommand_SE = 240, // End of subnegotiation parameters
  kTelnetCommand_NOP = 241, // No operation
  kTelnetCommand_DM = 242, // Data mark - Indicates the position of a Synch event within the data stream. This should always be accompanied by a TCP urgent notification.
  kTelnetCommand_BRK = 243, // Break - Indicates that the "break" or "attention" key was hi.
  kTelnetCommand_IP = 244, // Suspend - Interrupt or abort the process to which the NVT is connected.
  kTelnetCommand_AO = 245, // Abort output - Allows the current process to run to completion but does not send its output to the user.
  kTelnetCommand_AYT = 246, // Are you there - Send back to the NVT some visible evidence that the AYT was received.
  kTelnetCommand_EC = 247, // Erase character - The receiver should delete the last preceding undeleted character from the data stream.
  kTelnetCommand_EL = 248, // Erase line - Delete characters from the data stream back to but not including the previous CRLF.
  kTelnetCommand_GA = 249, // Go ahead - Under certain circumstances used to tell the other end that it can transmit.
  kTelnetCommand_SB = 250, // Subnegotiation - Subnegotiation of the indicated option follows.
  kTelnetCommand_WILL = 251, // will - Indicates the desire to begin performing, or confirmation that you are now performing, the indicated option.
  kTelnetCommand_WONT = 252, // wont - Indicates the refusal to perform, or continue performing, the indicated option.
  kTelnetCommand_DO = 253, // do - Indicates the request that the other party perform, or confirmation that you are expecting the other party to perform, the indicated option.
  kTelnetCommand_DONT = 254, // dont - Indicates the demand that the other party stop performing, or confirmation that you are no longer expecting the other party to perform, the indicated option.
  kTelnetCommand_IAC = 255 // Interpret as command - Interpret as a command
};

typedef NS_ENUM(unsigned char, TelnetOption) {
  kTelnetOption_Echo = 1,  // RFC 857
  kTelnetOption_SuppressGoAhead = 3,  // RFC 858
  kTelnetOption_Status = 5,  // RFC 859
  kTelnetOption_TimingMark = 6,  // RFC 860
  kTelnetOption_TerminalType = 24,  // RFC 1091
  kTelnetOption_WindowSize = 31,  // RFC 1073
  kTelnetOption_TerminalSpeed = 32,  // RFC 1079
  kTelnetOption_RemoteFlowControl = 33,  // RFC 1372
  kTelnetOption_Linemode = 34,  // RFC 1184
  kTelnetOption_EnvironmentVariables = 36  // RFC 1408
};

@interface GCDTelnetServer ()
@property(nonatomic, readonly) GCDTelnetStartHandler startHandler;
@property(nonatomic, readonly) GCDTelnetLineHandler lineHandler;
@end
