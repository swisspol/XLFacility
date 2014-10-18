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

#import "XLHTTPServerLogger.h"
#import "XLFunctions.h"
#import "XLPrivate.h"

#define kMinRefreshDelay 500  // In milliseconds
#define kMaxLongPollDuration 30  // In seconds

@interface XLHTTPServerLogger ()
@property(nonatomic, readonly) NSDateFormatter* dateFormatterRFC822;
@end

@interface XLHTTPServerConnection : XLTCPServerLoggerConnection
@end

@interface XLHTTPServerConnection () {
@private
  dispatch_semaphore_t _pollingSemaphore;
  NSMutableData* _headerData;
}
@end

@implementation XLHTTPServerConnection

- (void)didReceiveLogRecord {
  if (_pollingSemaphore) {
    dispatch_semaphore_signal(_pollingSemaphore);
  }
}

- (BOOL)_writeHTTPResponseWithStatusCode:(NSInteger)statusCode htmlBody:(NSString*)htmlBody {
  BOOL success = NO;
  CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, statusCode, NULL, kCFHTTPVersion1_1);
  CFHTTPMessageCreateResponse(kCFAllocatorDefault, statusCode, NULL, kCFHTTPVersion1_1);
  CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Connection"), CFSTR("Close"));
  CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Server"), (__bridge CFStringRef)NSStringFromClass([self class]));
  CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Date"), (__bridge CFStringRef)[[(XLHTTPServerLogger*)self.logger dateFormatterRFC822] stringFromDate:[NSDate date]]);
  if (htmlBody) {
    NSData* htmlData = XLConvertNSStringToUTF8String(htmlBody);
    CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Type"), CFSTR("text/html; charset=utf-8"));
    CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Length"), (__bridge CFStringRef)[NSString stringWithFormat:@"%lu", (unsigned long)htmlData.length]);
    CFHTTPMessageSetBody(response, (__bridge CFDataRef)htmlData);
  }
  NSData* data = CFBridgingRelease(CFHTTPMessageCopySerializedMessage(response));
  if (data) {
    [self writeDataAsynchronously:data completion:^(BOOL ok) {
      [self close];
    }];
    success = YES;
  } else {
    XLOG_ERROR(@"Failed serializing HTTP response");
  }
  CFRelease(response);
  return success;
}

- (void)_appendLogRecordsToString:(NSMutableString*)string afterAbsoluteTime:(CFAbsoluteTime)time {
  XLHTTPServerLogger* logger = (XLHTTPServerLogger*)self.logger;
  __block CFAbsoluteTime maxTime = time;
  [logger.databaseLogger enumerateRecordsAfterAbsoluteTime:time backward:NO maxRecords:0 usingBlock:^(int appVersion, XLLogRecord* record, BOOL* stop) {
    const char* style = "color: dimgray;";
    if (record.level == kXLLogLevel_Warning) {
      style = "color: orange;";
    } else if (record.level == kXLLogLevel_Error) {
      style = "color: red;";
    } else if (record.level >= kXLLogLevel_Exception) {
      style = "color: red; font-weight: bold;";
    }
    NSString* formattedMessage = [logger formatRecord:record];
    [string appendFormat:@"<tr style=\"%s\">%@</tr>", style, formattedMessage];
    if (record.absoluteTime > maxTime) {
      maxTime = record.absoluteTime;
    }
  }];
  [string appendFormat:@"<tr id=\"maxTime\" data-value=\"%f\"></tr>", maxTime];
}

- (BOOL)_processHTTPRequest:(CFHTTPMessageRef)request {
  BOOL success = NO;
  NSString* method = CFBridgingRelease(CFHTTPMessageCopyRequestMethod(request));
  if ([method isEqualToString:@"GET"]) {
    NSURL* url = CFBridgingRelease(CFHTTPMessageCopyRequestURL(request));
    NSString* path = url.path;
    NSString* query = url.query;
    
    if ([path isEqualToString:@"/"]) {
      NSMutableString* string = [[NSMutableString alloc] init];
      
      [string appendString:@"<!DOCTYPE html><html lang=\"en\">"];
      [string appendString:@"<head><meta charset=\"utf-8\"></head>"];
      [string appendFormat:@"<title>%s[%i]</title>", getprogname(), getpid()];
      [string appendString:@"<style>\
        body {\n\
          margin: 0px;\n\
          font-family: Courier, monospace;\n\
          font-size: 0.8em;\n\
        }\n\
        table {\n\
          width: 100%;\n\
          border-collapse: collapse;\n\
        }\n\
        tr {\n\
          vertical-align: top;\n\
        }\n\
        tr:nth-child(odd) {\n\
          background-color: #eeeeee;\n\
        }\n\
        td {\n\
          padding: 2px 10px;\n\
        }\n\
        #footer {\n\
          text-align: center;\n\
          margin: 20px 0px;\n\
          color: darkgray;\n\
        }\n\
        .error {\n\
          color: red;\n\
          font-weight: bold;\n\
        }\n\
      </style>"];
      [string appendFormat:@"<script type=\"text/javascript\">\n\
        var refreshDelay = %i;\n\
        var footerElement = null;\n\
        function updateTimestamp() {\n\
          var now = new Date();\n\
          footerElement.innerHTML = \"Last updated on \" + now.toLocaleDateString() + \" \" + now.toLocaleTimeString();\n\
        }\n\
        function refresh() {\n\
          var timeElement = document.getElementById(\"maxTime\");\n\
          var maxTime = timeElement.getAttribute(\"data-value\");\n\
          timeElement.parentNode.removeChild(timeElement);\n\
          \n\
          var xmlhttp = new XMLHttpRequest();\n\
          xmlhttp.onreadystatechange = function() {\n\
            if (xmlhttp.readyState == 4) {\n\
              if (xmlhttp.status == 200) {\n\
                var contentElement = document.getElementById(\"content\");\n\
                contentElement.innerHTML = contentElement.innerHTML + xmlhttp.responseText;\n\
                updateTimestamp();\n\
                setTimeout(refresh, refreshDelay);\n\
              } else {\n\
                footerElement.innerHTML = \"<span class=\\\"error\\\">Connection failed! Reload page to try again.</span>\";\n\
              }\n\
            }\n\
          }\n\
          xmlhttp.open(\"GET\", \"/log?after=\" + maxTime, true);\n\
          xmlhttp.send();\n\
        }\n\
        window.onload = function() {\n\
          footerElement = document.getElementById(\"footer\");\n\
          updateTimestamp();\n\
          setTimeout(refresh, refreshDelay);\n\
        }\n\
      </script>", kMinRefreshDelay];
      [string appendString:@"</head>"];
      [string appendString:@"<body>"];
      [string appendString:@"<table><tbody id=\"content\">"];
      [self _appendLogRecordsToString:string afterAbsoluteTime:0.0];
      [string appendString:@"</tbody></table>"];
      [string appendString:@"<div id=\"footer\"></div>"];
      [string appendString:@"</body>"];
      [string appendString:@"</html>"];
      
      success = [self _writeHTTPResponseWithStatusCode:200 htmlBody:string];
    } else if ([path isEqualToString:@"/log"] && [query hasPrefix:@"after="]) {
      NSMutableString* string = [[NSMutableString alloc] init];
      CFAbsoluteTime time = [[query substringFromIndex:6] doubleValue];
      
      _pollingSemaphore = dispatch_semaphore_create(0);
      dispatch_semaphore_wait(_pollingSemaphore, dispatch_time(DISPATCH_TIME_NOW, kMaxLongPollDuration * NSEC_PER_SEC));
      if (self.peer) {  // Check for race-condition if the connection was closed while waiting
        [self _appendLogRecordsToString:string afterAbsoluteTime:time];
        success = [self _writeHTTPResponseWithStatusCode:200 htmlBody:string];
      }
    } else {
      XLOG_WARNING(@"Unsupported path in HTTP request: %@", path);
      success = [self _writeHTTPResponseWithStatusCode:404 htmlBody:nil];
    }
    
  } else {
    XLOG_WARNING(@"Unsupported method in HTTP request: %@", method);
    success = [self _writeHTTPResponseWithStatusCode:405 htmlBody:nil];
  }
  return success;
}

- (void)_readHeaders {
  [self readDataAsynchronously:^(NSData* data) {
    if (data) {
      [_headerData appendData:data];
      NSRange range = [_headerData rangeOfData:[NSData dataWithBytes:"\r\n\r\n" length:4] options:0 range:NSMakeRange(0, _headerData.length)];
      if (range.location != NSNotFound) {
        
        BOOL success = NO;
        CFHTTPMessageRef message = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true);
        CFHTTPMessageAppendBytes(message, data.bytes, data.length);
        if (CFHTTPMessageIsHeaderComplete(message)) {
          success = [self _processHTTPRequest:message];
        } else {
          XLOG_ERROR(@"Failed parsing HTTP request headers");
        }
        CFRelease(message);
        if (!success) {
          [self close];
        }
        
      } else {
        [self _readHeaders];
      }
    } else {
      [self close];
    }
  }];
}

- (void)didOpen {
  [super didOpen];
  
  _headerData = [[NSMutableData alloc] init];
  [self _readHeaders];
}

- (void)didClose {
  [super didClose];
  
  if (_pollingSemaphore) {
    dispatch_semaphore_signal(_pollingSemaphore);
  }
}

#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE

- (void)dealloc {
  if (_pollingSemaphore) {
    dispatch_release(_pollingSemaphore);
  }
}

#endif

@end

@implementation XLHTTPServerLogger

+ (Class)connectionClass {
  return [XLHTTPServerConnection class];
}

- (instancetype)init {
  return [self initWithPort:8080];
}

- (instancetype)initWithPort:(NSUInteger)port {
  if ((self = [super initWithPort:port useDatabaseLogger:YES])) {
    _dateFormatterRFC822 = [[NSDateFormatter alloc] init];
    _dateFormatterRFC822.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    _dateFormatterRFC822.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
    _dateFormatterRFC822.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    
    self.format = @"<td>%t</td><td>%l</td><td>%M%c</td>";
    self.appendNewlineToFormat = NO;
  }
  return self;
}

- (NSString*)sanitizeMessageFromRecord:(XLLogRecord*)record {
  NSString* message = [super sanitizeMessageFromRecord:record];
  message = [message stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
  message = [message stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
  message = [message stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
  message = [message stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
  return message;
}

- (NSString*)formatCallstackFromRecord:(XLLogRecord*)record {
  NSString* callstack = [super formatCallstackFromRecord:record];
  callstack = [callstack stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
  return callstack;
}

- (void)logRecord:(XLLogRecord*)record {
  [super logRecord:record];
  
  [self.TCPServer enumerateConnectionsUsingBlock:^(XLTCPPeerConnection* connection, BOOL* stop) {
    [(XLHTTPServerConnection*)connection didReceiveLogRecord];
  }];
}

@end
