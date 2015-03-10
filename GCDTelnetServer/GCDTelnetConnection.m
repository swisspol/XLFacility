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

#define kTelnetCommandStringsOffset kTelnetCommand_SE

#define kCSIPrefix "\x1b["  // https://en.wikipedia.org/wiki/ANSI_escape_code
#define kCarriageReturnString @"\r\n"

#define kSynchronousCommunicationTimeout 3.0

static const char* _telnetCommandStrings[] = {
  "SE", "NOP", "DM", "BRK", "IP", "AO", "AYT", "EC", "EL", "GA", "SB", "WILL", "WONT", "DO", "DONT", "IAC"
};

static const char* _telnetOptionStrings[] = {
  NULL, "Echo", NULL, "Supress Go Ahead", NULL, "Status", "Timing Mark", NULL, NULL, NULL,  // 0-9
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, // 10-29
  NULL, NULL, NULL, NULL, "Terminal Type", NULL, NULL, NULL, NULL, NULL, // 20-29
  NULL, "Window Size", "Terminal Speed", "Remote Flow Control", "Linemode", NULL, "Environment Variables", NULL, NULL, NULL // 30-39
};

static NSRegularExpression* _commandLineParser = nil;

@interface GCDTelnetConnection () {
@private
  NSMutableString* _lineBuffer;
  NSMutableArray* _historyLines;
  NSUInteger _historyIndex;
  NSString* _savedLine;
}
@end

@implementation GCDTelnetConnection

+ (void)initialize {
  if (self == [GCDTelnetConnection class]) {
    _commandLineParser = [[NSRegularExpression alloc] initWithPattern:@"(\"[^\"]+\"|'[^']+'|[^\\s\"]+)" options:0 error:NULL];
    _LOG_DEBUG_CHECK(_commandLineParser);
  }
}

- (instancetype)initWithSocket:(int)socket {
  if ((self = [super initWithSocket:socket])) {
    _lineBuffer = [[NSMutableString alloc] init];
    _prompt = @"> ";
    _tabPlaceholder = @"\t";
    _maxHistorySize = NSIntegerMax;
    _historyLines = [[NSMutableArray alloc] init];
    _historyIndex = NSNotFound;
  }
  return self;
}

static NSString* _StringFromIACBuffer(const unsigned char* buffer, NSUInteger length) {
  _LOG_DEBUG_CHECK(buffer[0] == kTelnetCommand_IAC);
  _LOG_DEBUG_CHECK(length >= 3);
  NSMutableString* string = [[NSMutableString alloc] init];
  NSUInteger i = 0;
  while (i < length) {
    [string appendFormat:@"%s, %s", _telnetCommandStrings[buffer[i] - kTelnetCommandStringsOffset], _telnetCommandStrings[buffer[i + 1] - kTelnetCommandStringsOffset]];
    i += 2;
    if ((buffer[i - 1] >= kTelnetCommand_WILL) && (buffer[i - 1] <= kTelnetCommand_DONT)) {
      [string appendFormat:@", %s", _telnetOptionStrings[buffer[i]]];
      ++i;
    } else if (buffer[i - 1] == kTelnetCommand_SB) {
      [string appendFormat:@", %s,", _telnetOptionStrings[buffer[i]]];
      ++i;
      while ((buffer[i] != kTelnetCommand_IAC) || (buffer[i + 1] != kTelnetCommand_SE)) {
        [string appendFormat:@" (%i)'%c'", buffer[i], buffer[i]];
        ++i;
      }
      [string appendFormat:@", %s, %s", _telnetCommandStrings[buffer[i] - kTelnetCommandStringsOffset], _telnetCommandStrings[buffer[i + 1] - kTelnetCommandStringsOffset]];
      i += 2;
    } else {
      [string appendFormat:@", %i", buffer[i]];
      ++i;
    }
  }
  return string;
}

- (NSData*)_sendIACBuffer:(const unsigned char*)buffer length:(NSUInteger)length {
  _LOG_DEBUG_CHECK(buffer[0] == kTelnetCommand_IAC);
  
  if (![self writeBuffer:buffer length:length withTimeout:kSynchronousCommunicationTimeout]) {
    _LOG_ERROR(@"Failed sending Telnet command: %@", _StringFromIACBuffer(buffer, length));
    return nil;
  }
  _LOG_DEBUG(@"Telnet IAC (->) %@", _StringFromIACBuffer(buffer, length));
  
  NSData* data = [self readDataWithTimeout:kSynchronousCommunicationTimeout];
  if (!data.length) {
    return nil;
  }
  const unsigned char* bytes = data.bytes;
  if (bytes[0] != kTelnetCommand_IAC) {
    _LOG_ERROR(@"Invalid Telnet command received");
    return nil;
  }
  _LOG_DEBUG(@"Telnet IAC (<-) %@", _StringFromIACBuffer(data.bytes, data.length));
  
  return data;
}

- (BOOL)_setIACOption:(unsigned char)option {
  unsigned char buffer[] = {kTelnetCommand_IAC, kTelnetCommand_WILL, option};
  NSData* data = [self _sendIACBuffer:buffer length:sizeof(buffer)];
  if (data.length != 3) {
    return NO;
  }
  const unsigned char* bytes = data.bytes;
  if ((bytes[1] != kTelnetCommand_DO) || (bytes[2] != option)) {
    _LOG_ERROR(@"Failed setting Telnet option: %@", _StringFromIACBuffer(data.bytes, data.length));
    return NO;
  }
  return YES;
}

- (NSString*)_retrieveTerminalType {
  unsigned char buffer1[] = {kTelnetCommand_IAC, kTelnetCommand_DO, kTelnetOption_TerminalType};
  NSData* data1 = [self _sendIACBuffer:buffer1 length:sizeof(buffer1)];
  if (data1.length != 3) {
    return nil;
  }
  const unsigned char* bytes1 = data1.bytes;
  if ((bytes1[1] != kTelnetCommand_WILL) || (bytes1[2] != kTelnetOption_TerminalType)) {
    return nil;
  }
  
  unsigned char buffer2[] = {kTelnetCommand_IAC, kTelnetCommand_SB, kTelnetOption_TerminalType, 1, kTelnetCommand_IAC, kTelnetCommand_SE};
  NSData* data2 = [self _sendIACBuffer:buffer2 length:sizeof(buffer2)];
  if (data2.length < 6) {
    return nil;
  }
  const unsigned char* bytes2 = data2.bytes;
  NSUInteger length2 = data2.length;
  if ((bytes2[1] != kTelnetCommand_SB) || (bytes2[2] != kTelnetOption_TerminalType) || (bytes2[3] != 0)) {
    return nil;
  }
  if ((bytes2[length2 - 2] != kTelnetCommand_IAC) || (bytes2[length2 - 1] != kTelnetCommand_SE)) {
    return nil;
  }
  
  return [[NSString alloc] initWithBytes:&bytes2[4] length:(length2 - 6) encoding:NSASCIIStringEncoding];
}

- (void)_readInput {
  [self readDataAsynchronously:^(NSData* data) {
    if (data.length) {
      data = [self processRawInput:data];
      if (data) {
        [self writeDataAsynchronously:data completion:^(BOOL success) {
          if (success) {
            [self _readInput];
          } else {
            [self close];
          }
        }];
      } else {
        [self _readInput];
      }
    } else {
      [self close];
    }
  }];
}

- (void)didOpen {
  [self _setIACOption:kTelnetOption_SuppressGoAhead];
  [self _setIACOption:kTelnetOption_Echo];
  
  _terminalType = [self _retrieveTerminalType];
  if (_terminalType.length) {
    NSRange range = [_terminalType rangeOfString:@"color" options:NSCaseInsensitiveSearch];
    _colorTerminal = (range.location != NSNotFound);
  } else {
    _LOG_ERROR(@"Failed retrieving Telnet terminal type from %@", self.remoteIPAddress);
  }
  NSMutableString* string = [[NSMutableString alloc] init];
  NSString* start = [self start];
  if (start) {
    [string appendString:start];
  }
  if (_prompt) {
    [string appendString:_prompt];
  }
  if (string.length) {
    [self writeASCIIStringAsynchronously:string completion:^(BOOL success) {
      if (success) {
        [self _readInput];
      } else {
        [self close];
      }
    }];
  } else {
    [self _readInput];
  }
}

@end

@implementation GCDTelnetConnection (Subclassing)

- (NSMutableString*)lineBuffer {
  return _lineBuffer;
}

- (NSString*)start {
  GCDTelnetStartHandler handler = [(GCDTelnetServer*)self.peer startHandler];
  if (handler) {
    return [self sanitizeStringForTerminal:handler(self)];
  }
  return nil;
}

- (NSData*)_beepData {
  unsigned char buffer[] = {kControlCode_BEL};
  return [NSData dataWithBytes:buffer length:sizeof(buffer)];
}

- (NSMutableData*)_emptyLineData {
  unsigned char buffer[] = {
    kCSIPrefix[0], kCSIPrefix[1], '2', 'K',  // Clear entire line
    kCSIPrefix[0], kCSIPrefix[1], '1', 'G'  // Move cursor to column 1
  };
  NSMutableData* data = [NSMutableData dataWithBytes:buffer length:sizeof(buffer)];
  if (_prompt) {
    [data appendData:[_prompt dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
  }
  return data;
}

- (NSData*)_stringLineData:(NSString*)string {
  [_lineBuffer setString:string];
  NSMutableData* data = [self _emptyLineData];
  [data appendData:[string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
  return data;
}

- (NSData*)processCursorUp {
  if ((_historyIndex == NSNotFound) && _historyLines.count) {
    _savedLine = [_lineBuffer copy];
    _historyIndex = _historyLines.count - 1;
  } else if ((_historyIndex != NSNotFound) && (_historyIndex > 0)) {
    _historyIndex -= 1;
  } else {
    return [self _beepData];
  }
  return [self _stringLineData:_historyLines[_historyIndex]];
}

- (NSData*)processCursorDown {
  if (_historyIndex == NSNotFound) {
    return [self _beepData];
  }
  NSString* string;
  if (_historyIndex < _historyLines.count - 1) {
    _historyIndex += 1;
    string = _historyLines[_historyIndex];
  } else {
    string = _savedLine;
    _historyIndex = NSNotFound;
    _savedLine = nil;
  }
  return [self _stringLineData:string];
}

- (NSData*)processCursorForward {
  return [self _beepData];
}

- (NSData*)processCursorBack {
  return [self _beepData];
}

- (NSData*)processOtherANSIEscapeSequence:(NSData*)data {
  return [self _beepData];
}

- (NSData*)processTab {
  [_lineBuffer appendString:_tabPlaceholder];
  return [_tabPlaceholder dataUsingEncoding:NSASCIIStringEncoding];
}

- (NSData*)processDelete {
  if (_lineBuffer.length) {
    [_lineBuffer deleteCharactersInRange:NSMakeRange(_lineBuffer.length - 1, 1)];
    unsigned char buffer[] = {0x08, 0x20, 0x08};  // http://stackoverflow.com/questions/1689554/telnet-server-backspace-delete-not-working
    return [NSData dataWithBytes:buffer length:sizeof(buffer)];
  }
  return [self _beepData];
}

- (NSData*)processCarriageReturn {
  NSData* data;
  NSString* line = [_lineBuffer copy];
  NSString* result = [self processLine:line];
  if (result) {
    if (_maxHistorySize && line.length) {
      if (!_historyLines.count || ![line isEqualToString:[_historyLines lastObject]]) {
        [_historyLines addObject:line];
        if (_historyLines.count > _maxHistorySize) {
          [_historyLines removeObjectsInRange:NSMakeRange(0, _historyLines.count - _maxHistorySize)];
        }
      }
    }
    _historyIndex = NSNotFound;
    _savedLine = nil;
    
    NSMutableString* string = [[NSMutableString alloc] init];
    [string appendString:kCarriageReturnString];
    [string appendString:result];
    if (_prompt) {
      [string appendString:_prompt];
    }
    data = [string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
  } else {
    data = [self _emptyLineData];
  }
  [_lineBuffer setString:@""];
  return data;
}

- (NSData*)processOtherASCIICharacter:(unsigned char)character {
  [_lineBuffer appendFormat:@"%c", character];
  return [NSData dataWithBytes:&character length:1];
}

- (NSData*)processNonASCIICharacter:(unsigned char)character {
  return nil;
}

- (NSData*)processRawInput:(NSData*)input {
  const unsigned char* bytes = input.bytes;
  NSUInteger length = input.length;
  
  if ((length > 2) && (bytes[0] == kCSIPrefix[0]) && (bytes[1] == kCSIPrefix[1])) {
    if (length == 3) {
      switch (bytes[2]) {
        
        case 'A': return [self processCursorUp];
        case 'B': return [self processCursorDown];
        case 'C': return [self processCursorForward];
        case 'D': return [self processCursorBack];
        
      }
    }
    return [self processOtherANSIEscapeSequence:input];
  }
  
  NSMutableData* output = [[NSMutableData alloc] init];
  while (length) {
    NSData* data = nil;
    if ((length >= 2) && (bytes[0] == kControlCode_CR) && (bytes[1] == kControlCode_NUL)) {
      data = [self processCarriageReturn];
      bytes += 2;
      length -= 2;
    } else {
      switch (bytes[0]) {
        
        case 0x09:
          data = [self processTab];
          break;
        
        case 0x7F:
          data = [self processDelete];
          break;
        
        default:
          if (bytes[0] <= 127) {
            data = [self processOtherASCIICharacter:bytes[0]];
          } else {
            data = [self processNonASCIICharacter:bytes[0]];
          }
          break;
        
      }
      bytes += 1;
      length -= 1;
    }
    if (data.length) {
      [output appendData:data];
    }
  }
  
  return output;
}

- (NSString*)processLine:(NSString*)line {
  GCDTelnetLineHandler handler = [(GCDTelnetServer*)self.peer lineHandler];
  if (handler) {
    return [self sanitizeStringForTerminal:handler(self, line)];
  }
  return nil;
}

@end

@implementation GCDTelnetConnection (Extensions)

- (NSArray*)parseLineAsCommandAndArguments:(NSString*)line {
  NSMutableArray* array = [[NSMutableArray alloc] init];
  [_commandLineParser enumerateMatchesInString:line options:0 range:NSMakeRange(0, line.length) usingBlock:^(NSTextCheckingResult* result, NSMatchingFlags flags, BOOL* stop) {
    NSString* string = [line substringWithRange:result.range];
    if (([string hasPrefix:@"\""] && [string hasSuffix:@"\""]) || ([string hasPrefix:@"'"] && [string hasSuffix:@"'"])) {  // TODO: Strip quotes directly in Regex
      [array addObject:[string substringWithRange:NSMakeRange(1, string.length - 2)]];
    } else {
      [array addObject:string];
    }
  }];
  return array;
}

- (NSString*)sanitizeStringForTerminal:(NSString*)string {
  return [string stringByReplacingOccurrencesOfString:@"\n" withString:kCarriageReturnString];
}

- (BOOL)writeASCIIString:(NSString*)string withTimeout:(NSTimeInterval)timeout {
  return [self writeData:[string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] withTimeout:timeout];
}

- (void)writeASCIIStringAsynchronously:(NSString*)string completion:(void (^)(BOOL success))completion {
  [self writeDataAsynchronously:[string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] completion:completion];
}

@end
