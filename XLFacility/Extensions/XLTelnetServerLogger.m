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
#import "XLFacilityPrivate.h"

#import "GCDTelnetServer.h"
#import "NSMutableString+ANSI.h"

@interface XLTelnetServerConnection : GCDTelnetConnection
@end

@implementation XLTelnetServerConnection

- (instancetype)initWithSocket:(int)socket {
  if ((self = [super initWithSocket:socket])) {
    self.prompt = nil;
  }
  return self;
}

- (NSString*)start {
  NSMutableString* string = [[NSMutableString alloc] init];
  
  if ([(XLTelnetServerLogger*)self.logger shouldColorize]) {
    [string appendANSIStringWithColor:kANSIColor_Green bold:NO format:@"You are connected to %s[%i] (in color!)", getprogname(), getpid()];
    [string appendString:@"\n\n"];
  } else {
    [string appendFormat:@"You are connected to %s[%i]\n\n", getprogname(), getpid()];
  }
  
  XLTelnetServerLogger* logger = (XLTelnetServerLogger*)self.logger;
  if (logger.databaseLogger) {
    [logger.databaseLogger enumerateRecordsAfterAbsoluteTime:0.0 backward:NO maxRecords:0 usingBlock:^(int appVersion, XLLogRecord* record, BOOL* stop) {
      [string appendString:[logger formatRecord:record]];
    }];
  }
  
  return [self sanitizeStringForTerminal:string];
}

@end

@implementation XLTelnetServerLogger

+ (Class)serverClass {
  return [GCDTelnetServer class];
}

+ (Class)connectionClass {
  return [XLTelnetServerConnection class];
}

- (instancetype)init {
  return [self initWithPort:2323 preserveHistory:YES];
}

- (instancetype)initWithPort:(NSUInteger)port preserveHistory:(BOOL)preserveHistory {
  if ((self = [super initWithPort:port useDatabaseLogger:preserveHistory])) {
    _shouldColorize = YES;
    _sendTimeout = -1.0;
  }
  return self;
}

- (NSString*)formatRecord:(XLLogRecord*)record {
  NSString* formattedMessage = [super formatRecord:record];
  if (_shouldColorize) {
    char color = -1;
    BOOL bold = NO;
    if (record.level == kXLLogLevel_Warning) {
      color = kANSIColor_Yellow;
    } else if (record.level == kXLLogLevel_Error) {
      color = kANSIColor_Red;
    } else if (record.level >= kXLLogLevel_Exception) {
      color = kANSIColor_Red;
      bold = YES;
    }
    if (color != -1) {
      NSMutableString* string = [[NSMutableString alloc] initWithCapacity:(formattedMessage.length + 16)];
      [string appendANSIString:formattedMessage withColor:color bold:bold];
      formattedMessage = string;
    }
  }
  return formattedMessage;
}

- (void)logRecord:(XLLogRecord*)record {
  [super logRecord:record];
  
  NSString* formattedMessage = [self formatRecord:record];
  [self.TCPServer enumerateConnectionsUsingBlock:^(GCDTCPPeerConnection* connection, BOOL* stop) {
    NSString* string = [(GCDTelnetConnection*)connection sanitizeStringForTerminal:formattedMessage];
    if (_sendTimeout < 0.0) {
      [(GCDTelnetConnection*)connection writeASCIIStringAsynchronously:string completion:^(BOOL success) {
        if (!success) {
          [connection close];
        }
      }];
    } else {
      if (![(GCDTelnetConnection*)connection writeASCIIString:string withTimeout:_sendTimeout]) {
        [connection close];
      }
    }
  }];
}

@end
