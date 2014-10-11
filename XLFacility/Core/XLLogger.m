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

#import <pthread.h>

#import "XLLogger.h"

#define kNoQueueLabel @"(null)"

typedef NS_ENUM(unsigned char, FormatToken) {
  kFormatToken_Unknown = 0,
  kFormatToken_Newline,
  kFormatToken_Return,
  kFormatToken_Tab,
  kFormatToken_Percent,
  kFormatToken_Backslash,
  kFormatToken_LevelName,
  kFormatToken_PaddedLevelName,
  kFormatToken_Message,
  kFormatToken_UserID,
  kFormatToken_ProcessID,
  kFormatToken_ProcessName,
  kFormatToken_ThreadID,
  kFormatToken_QueueLabel,
  kFormatToken_Timestamp,
  kFormatToken_DateTime,
  kFormatToken_ErrnoValue,
  kFormatToken_ErrnoString,
  kFormatToken_Callstack,
  kFormatToken_StringLUT  // Must be last token
};

@interface XLLogger () {
@private
  NSString* _format;
  NSMutableData* _tokens;
  NSMutableArray* _strings;
  NSDateFormatter* _datetimeFormatter;
}
@end

static NSString* _logLevelNames[] = {@"DEBUG", @"VERBOSE", @"INFO", @"WARNING", @"ERROR", @"EXCEPTION", @"ABORT"};
static NSString* _paddedLogLevelNames[] = {@"DEBUG    ", @"VERBOSE  ", @"INFO     ", @"WARNING  ", @"ERROR    ", @"EXCEPTION", @"ABORT    "};

static CFTimeInterval _startTime = 0.0;
static NSString* _pid = nil;
static NSString* _pname = nil;
static NSString* _uid = nil;

@implementation XLLogger

+ (void)load {
  _startTime = CFAbsoluteTimeGetCurrent();
  _pid = [[NSString alloc] initWithFormat:@"%i", getpid()];
  _pname = [[NSString alloc] initWithFormat:@"%s", getprogname()];
  _uid = [[NSString alloc] initWithFormat:@"%i", getuid()];
}

- (id)init {
  if ((self = [super init])) {
    _minLogLevel = kXLMinLogLevel;
    _maxLogLevel = kXLMaxLogLevel;
    _datetimeFormatter = [[NSDateFormatter alloc] init];
    _datetimeFormatter.timeZone = [NSTimeZone systemTimeZone];
    _datetimeFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    _datetimeFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    _callstackHeader = @"\n\n>>> Captured call stack:\n";
    
    self.format = @"%t [%L]> %m%c\n";
  }
  return self;
}

- (void)setFormat:(NSString*)format {
  _format = [format copy];
  
  _tokens = [[NSMutableData alloc] init];
  _strings = [[NSMutableArray alloc] init];
  if (_format.length) {
    NSCharacterSet* characterSet = [NSCharacterSet characterSetWithCharactersInString:@"%\\"];
    NSScanner* scanner = [NSScanner scannerWithString:_format];
    scanner.caseSensitive = YES;
    scanner.charactersToBeSkipped = nil;
    scanner.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    while (1) {
      NSString* string;
      if ([scanner scanUpToCharactersFromSet:characterSet intoString:&string]) {
        FormatToken token = kFormatToken_StringLUT + _strings.count;
        [_tokens appendBytes:&token length:sizeof(FormatToken)];
        [_strings addObject:string];
      }
      if ([scanner isAtEnd]) {
        break;
      }
      BOOL escapeMode = [_format characterAtIndex:scanner.scanLocation] == '\\';
      scanner.scanLocation = scanner.scanLocation + 1;
      if ([scanner isAtEnd]) {
        break;
      }
      unichar character = [_format characterAtIndex:scanner.scanLocation];
      FormatToken token = kFormatToken_Unknown;
      if (escapeMode) {
        switch (character) {
          case 'n': token = kFormatToken_Newline; break;
          case 'r': token = kFormatToken_Return; break;
          case 't': token = kFormatToken_Tab; break;
          case '%': token = kFormatToken_Percent; break;
          case '\\': token = kFormatToken_Backslash; break;
        }
      } else {
        switch (character) {
          case 'l': token = kFormatToken_LevelName; break;
          case 'L': token = kFormatToken_PaddedLevelName; break;
          case 'm': token = kFormatToken_Message; break;
          case 'u': token = kFormatToken_UserID; break;
          case 'p': token = kFormatToken_ProcessID; break;
          case 'P': token = kFormatToken_ProcessName; break;
          case 'r': token = kFormatToken_ThreadID; break;
          case 'q': token = kFormatToken_QueueLabel; break;
          case 't': token = kFormatToken_Timestamp; break;
          case 'd': token = kFormatToken_DateTime; break;
          case 'e': token = kFormatToken_ErrnoValue; break;
          case 'E': token = kFormatToken_ErrnoString; break;
          case 'c': token = kFormatToken_Callstack; break;
        }
      }
      if (token != kFormatToken_Unknown) {
        [_tokens appendBytes:&token length:sizeof(FormatToken)];
      }
      scanner.scanLocation = scanner.scanLocation + 1;
    }
  }
}

- (NSString*)formatRecord:(XLRecord*)record {
  NSMutableString* string = [[NSMutableString alloc] initWithCapacity:(2 * record.message.length)];  // Should be quite enough
  
  FormatToken* token = (FormatToken*)_tokens.bytes;
  for (int i = 0; i < (int)(_tokens.length / sizeof(FormatToken)); ++i, ++token) {
    switch (*token) {
      
      case kFormatToken_Newline: {
        [string appendString:@"\n"];
        break;
      }
      
      case kFormatToken_Return: {
        [string appendString:@"\r"];
        break;
      }
      
      case kFormatToken_Tab: {
        [string appendString:@"\t"];
        break;
      }
      
      case kFormatToken_Percent: {
        [string appendString:@"%"];
        break;
      }
      
      case kFormatToken_Backslash: {
        [string appendString:@"\\"];
        break;
      }
      
      case kFormatToken_LevelName: {
        [string appendString:_logLevelNames[record.logLevel]];
        break;
      }
      
      case kFormatToken_PaddedLevelName: {
        [string appendString:_paddedLogLevelNames[record.logLevel]];
        break;
      }
      
      case kFormatToken_Message: {
        [string appendString:[self sanitizeMessageFromRecord:record]];
        break;
      }
      
      case kFormatToken_UserID: {
        [string appendString:_uid];
        break;
      }
      
      case kFormatToken_ProcessID: {
        [string appendString:_pid];
        break;
      }
      
      case kFormatToken_ProcessName: {
        [string appendString:_pname];
        break;
      }
      
      case kFormatToken_ThreadID: {
        [string appendFormat:@"%lu", (unsigned long)record.capturedThreadID];
        break;
      }
      
      case kFormatToken_QueueLabel: {
        if (record.capturedQueueLabel) {
          [string appendString:record.capturedQueueLabel];
        } else {
          [string appendString:kNoQueueLabel];
        }
        break;
      }
      
      case kFormatToken_Timestamp: {
        CFTimeInterval timestamp = record.absoluteTime - _startTime;
        int milliseconds = fmod(timestamp, 1.0) * 1000.0;
        int seconds = timestamp;
        int minutes = seconds / 60;
        seconds -= minutes * 60;
        int hours = minutes / 60;
        minutes -= hours * 60;
        [string appendFormat:@"%02i:%02i:%02i.%03i", hours, minutes, seconds, milliseconds];
        break;
      }
      
      case kFormatToken_DateTime: {
        NSString* datetime = [_datetimeFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:record.absoluteTime]];
        if (datetime.length) {
          [string appendString:datetime];
        }
        break;
      }
      
      case kFormatToken_ErrnoValue: {
        [string appendFormat:@"%i", record.capturedErrno];
        break;
      }
      
      case kFormatToken_ErrnoString: {
        [string appendFormat:@"%s", strerror(record.capturedErrno)];
        break;
      }
      
      case kFormatToken_Callstack: {
        NSString* callstack = [self formatCallstackFromRecord:record];
        if (callstack) {
          [string appendString:callstack];
        }
        break;
      }
      
      default: {
        if (*token >= kFormatToken_StringLUT) {
          [string appendString:_strings[*token - kFormatToken_StringLUT]];
        }
        break;
      }
      
    }
  }
  
  if (_multilinesPrefix.length) {
    NSArray* components = [string componentsSeparatedByString:@"\n"];
    [string replaceCharactersInRange:NSMakeRange(0, string.length) withString:@""];
    [components enumerateObjectsUsingBlock:^(NSString* component, NSUInteger idx, BOOL* stop) {
      if (idx > 0) {
        [string appendString:@"\n"];
      }
      if (component.length) {
        if (idx > 0) {
          [string appendString:_multilinesPrefix];
        }
        [string appendString:component];
      }
    }];
  }
  
  return string;
}

- (BOOL)open {
  return YES;
}

- (BOOL)shouldLogRecord:(XLRecord*)record {
  if ((record.logLevel < _minLogLevel) || (record.logLevel > _maxLogLevel)) {
    return NO;
  }
  if (_recordFilter && !_recordFilter(record)) {
    return NO;
  }
  return YES;
}

- (void)logRecord:(XLRecord*)record {
  [self doesNotRecognizeSelector:_cmd];
}

- (void)close {
  ;
}

@end

@implementation XLLogger (Extensions)

- (NSString*)sanitizeMessageFromRecord:(XLRecord*)record {
  NSArray* components = [record.message componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
  return [components componentsJoinedByString:@"\n"];
}

- (NSString*)formatCallstackFromRecord:(XLRecord*)record {
  NSMutableString* string = nil;
  if (record.callstack) {
    string = [[NSMutableString alloc] initWithCapacity:1024];
    if (_callstackHeader) {
      [string appendString:_callstackHeader];
    }
    for (NSInteger i = 1, count = record.callstack.count; i < count - 1; ++i) {
      if (i > 1) {
        [string appendString:@"\n"];
      }
      [string appendString:record.callstack[i]];
    }
    if (_callstackFooter) {
      [string appendString:_callstackFooter];
    }
  }
  return string;
}

@end
