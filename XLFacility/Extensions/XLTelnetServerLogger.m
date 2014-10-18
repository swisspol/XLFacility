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

#if !__has_feature(objc_arc)
#error XLFacility requires ARC
#endif

#import "XLTelnetServerLogger.h"
#import "XLFunctions.h"
#import "XLPrivate.h"

@interface XLTelnetServerConnection : XLTCPServerLoggerConnection
@end

@implementation XLTelnetServerConnection

- (void)didOpen {
  [super didOpen];
  
  NSString* welcome;
  if ([(XLTelnetServerLogger*)self.logger colorize]) {
    welcome = [[NSString alloc] initWithFormat:@"%sYou are connected to %s[%i] (in color!)%s\n\n", "\x1b[32m", getprogname(), getpid(), "\x1b[0m"];
  } else {
    welcome = [[NSString alloc] initWithFormat:@"You are connected to %s[%i]\n\n", getprogname(), getpid()];
  }
  [self writeDataAsynchronously:XLConvertNSStringToUTF8String(welcome) completion:^(BOOL success1) {
    
    if (success1) {
      XLTelnetServerLogger* logger = (XLTelnetServerLogger*)self.logger;
      if (logger.databaseLogger) {
        NSMutableString* history = [[NSMutableString alloc] init];
        [logger.databaseLogger enumerateRecordsAfterAbsoluteTime:0.0 backward:NO maxRecords:0 usingBlock:^(int appVersion, XLLogRecord* record, BOOL* stop) {
          [history appendString:[logger formatRecord:record]];
        }];
        [self writeDataAsynchronously:XLConvertNSStringToUTF8String(history) completion:^(BOOL success2) {
          
          if (!success2) {
            [self close];
          }
          
        }];
      }
    } else {
      [self close];
    }
    
  }];
}

@end

@implementation XLTelnetServerLogger

+ (Class)connectionClass {
  return [XLTelnetServerConnection class];
}

- (instancetype)init {
  return [self initWithPort:2323 preserveHistory:YES];
}

- (instancetype)initWithPort:(NSUInteger)port preserveHistory:(BOOL)preserveHistory {
  if ((self = [super initWithPort:port useDatabaseLogger:preserveHistory])) {
    _colorize = YES;
    _sendTimeout = -1.0;
  }
  return self;
}

// https://en.wikipedia.org/wiki/ANSI_escape_code
- (NSString*)formatRecord:(XLLogRecord*)record {
  NSString* formattedMessage = [super formatRecord:record];
  if (_colorize) {
    const char* code = NULL;
    if (record.level == kXLLogLevel_Warning) {
      code = "\x1b[33m";  // Yellow
    } else if (record.level == kXLLogLevel_Error) {
      code = "\x1b[31m";  // Red
    } else if (record.level >= kXLLogLevel_Exception) {
      code = "\x1b[31;1m";  // Bold red
    }
    if (code) {
      formattedMessage = [NSString stringWithFormat:@"%s%@%s", code, formattedMessage, "\x1b[0m"];
    }
  }
  return formattedMessage;
}

- (void)logRecord:(XLLogRecord*)record {
  [super logRecord:record];
  
  NSData* data = XLConvertNSStringToUTF8String([self formatRecord:record]);
  [self.TCPServer enumerateConnectionsUsingBlock:^(XLTCPPeerConnection* connection, BOOL* stop) {
    if (_sendTimeout < 0.0) {
      [connection writeDataAsynchronously:data completion:^(BOOL success) {
        if (!success) {
          [self close];
        }
      }];
    } else {
      if (![connection writeData:data withTimeout:_sendTimeout]) {
        [self close];
      }
    }
  }];
}

@end
