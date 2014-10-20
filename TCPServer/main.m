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

#import "GCDTCPServer.h"

@interface ServerConnection : GCDTCPServerConnection
@end

@implementation ServerConnection

- (void)_readForever {
  [self readDataAsynchronously:^(NSData* data) {
    if (data) {
      if (write(STDOUT_FILENO, data.bytes, data.length) <= 0) {
        [self close];
      } else {
        [self _readForever];
      }
    } else {
      [self close];
    }
  }];
}

- (void)didOpen {
  [super didOpen];
  
  fprintf(stdout, "\n=== CONNECTION OPENED ===\n\n");
  [self _readForever];
}

- (void)didClose {
  [super didClose];
  
  fprintf(stdout, "\n=== CONNECTION CLOSED ===\n\n");
}

@end

int main(int argc, const char* argv[]) {
  @autoreleasepool {
    GCDTCPServer* server = [[GCDTCPServer alloc] initWithConnectionClass:[ServerConnection class] port:8888];
    if (![server start]) {
      abort();
    }
    
    fprintf(stdout, "Server is running...\n\n");
    CFRunLoopRun();
  }
  return 0;
}
