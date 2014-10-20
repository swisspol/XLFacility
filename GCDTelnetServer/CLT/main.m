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

#import "GCDTelnetServer.h"
#import "NSMutableString+ANSI.h"

int main(int argc, const char* argv[]) {
  @autoreleasepool {
    GCDTCPServer* server = [[GCDTelnetServer alloc] initWithPort:2323 startHandler:^NSString*(GCDTelnetConnection* connection) {
      
      NSMutableString* string = [[NSMutableString alloc] init];
      if (connection.colorTerminal) {
        [string appendANSIString:@"Welcome in color!" withColor:kANSIColor_Green bold:NO];
      } else {
        [string appendString:@"Welcome!"];
      }
      [string appendFormat:@"\nYou are connected using \"%@\"\n", connection.terminalType];
      return string;
      
    } lineHandler:^NSString*(GCDTelnetConnection* connection, NSString* line) {
      
      return [line stringByAppendingString:@"\n"];
      
    }];
    if (![server start]) {
      abort();
    }
    CFRunLoopRun();
  }
  return 0;
}
