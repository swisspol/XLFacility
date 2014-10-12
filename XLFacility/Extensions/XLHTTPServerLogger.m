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

#import <net/if.h>
#import <netdb.h>

#import "XLHTTPServerLogger.h"
#import "XLPrivate.h"

#define kDefaultPort 8080
#define kMaxPendingConnections 4
#define kDispatchQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
#define kMinRefreshDelay 500  // In milliseconds
#define kMaxLongPollDuration 30  // In seconds

@interface XLHTTPServerConnection : NSObject
@property(nonatomic, readonly) int socket;
@property(nonatomic, readonly) dispatch_semaphore_t semaphore;
@property(nonatomic) BOOL longPolling;
@end

@implementation XLHTTPServerConnection

- (id)initWithSocket:(int)socket {
  if ((self = [super init])) {
    _socket = socket;
    _semaphore = dispatch_semaphore_create(0);
  }
  return self;
}

- (void)dealloc {
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(_semaphore);
#endif
  close(_socket);
}

@end

@interface XLHTTPServerLogger () {
@private
  NSDateFormatter* _dateFormatterRFC822;
  dispatch_semaphore_t _sourceSemaphore;
  dispatch_source_t _source;
  dispatch_queue_t _lockQueue;
  NSMutableSet* _connections;
}
@end

@implementation XLHTTPServerLogger

- (id)init {
  return [self initWithPort:kDefaultPort];
}

- (id)initWithPort:(NSUInteger)port {
  NSString* databasePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
  if ((self = [super initWithDatabasePath:databasePath appVersion:0])) {
    _port = port;
    
    _dateFormatterRFC822 = [[NSDateFormatter alloc] init];
    _dateFormatterRFC822.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    _dateFormatterRFC822.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'";
    _dateFormatterRFC822.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    _sourceSemaphore = dispatch_semaphore_create(0);
    _lockQueue = dispatch_queue_create(object_getClassName([self class]), DISPATCH_QUEUE_SERIAL);
    _connections = [[NSMutableSet alloc] init];
    
    self.format = @"<td>%t</td><td>%l</td><td>%m%c</td>";
  }
  return self;
}

- (void)dealloc {
  [[NSFileManager defaultManager] removeItemAtPath:self.databasePath error:NULL];
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(_lockQueue);
  dispatch_release(_sourceSemaphore);
#endif
}

- (NSString*)sanitizeMessageFromRecord:(XLRecord*)record {
  NSString* message = [super sanitizeMessageFromRecord:record];
  message = [message stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
  message = [message stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
  message = [message stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
  message = [message stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
  return message;
}

- (NSString*)formatCallstackFromRecord:(XLRecord*)record {
  NSString* callstack = [super formatCallstackFromRecord:record];
  callstack = [callstack stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
  return callstack;
}

- (XLHTTPServerConnection*)_openConnectionOnSocket:(int)socket {
  __block XLHTTPServerConnection* connection;
  dispatch_sync(_lockQueue, ^{
    connection = [[XLHTTPServerConnection alloc] initWithSocket:socket];
    [_connections addObject:connection];
  });
  return connection;
}

- (void)_closeConnection:(XLHTTPServerConnection*)connection {
  dispatch_sync(_lockQueue, ^{
    [_connections removeObject:connection];
  });
}

- (BOOL)_writeHTTPResponse:(CFHTTPMessageRef)response forConnection:(XLHTTPServerConnection*)connection {
  BOOL success = NO;
  CFDataRef data = CFHTTPMessageCopySerializedMessage(response);
  if (data) {
    dispatch_data_t responseData = dispatch_data_create(CFDataGetBytePtr(data), CFDataGetLength(data), kDispatchQueue, ^{
      CFRelease(data);
    });
    dispatch_write(connection.socket, responseData, kDispatchQueue, ^(dispatch_data_t remainingData, int error) {
      if (error) {
        XLOG_INTERNAL(@"Failed writing HTTP response: %s", strerror(error));
      }
      [self _closeConnection:connection];
    });
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
    dispatch_release(responseData);
#endif
    success = YES;
  } else {
    XLOG_INTERNAL(@"%@", @"Failed serializing HTTP response");
  }
  return success;
}

- (BOOL)_writeHTMLResponse:(NSString*)htmlString forConnection:(XLHTTPServerConnection*)connection {
  BOOL success = NO;
  NSData* htmlData = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
  if (htmlData) {
    CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 200, NULL, kCFHTTPVersion1_1);
    CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Connection"), CFSTR("Close"));
    CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Server"), (__bridge CFStringRef)NSStringFromClass([self class]));
    CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Date"), (__bridge CFStringRef)[_dateFormatterRFC822 stringFromDate:[NSDate date]]);
    CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Type"), CFSTR("text/html; charset=utf-8"));
    CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Length"), (__bridge CFStringRef)[NSString stringWithFormat:@"%lu", (unsigned long)htmlData.length]);
    CFHTTPMessageSetBody(response, (__bridge CFDataRef)htmlData);
    success = [self _writeHTTPResponse:response forConnection:connection];
    CFRelease(response);
  } else {
    XLOG_INTERNAL(@"%@", @"Failed generating HTML response");
  }
  return success;
}

- (void)_appendLogRecordsToString:(NSMutableString*)string afterAbsoluteTime:(CFAbsoluteTime)time {
  __block CFAbsoluteTime maxTime = time;
  [self enumerateRecordsAfterAbsoluteTime:time backward:NO maxRecords:0 usingBlock:^(int appVersion, XLRecord* record, BOOL* stop) {
    const char* style = "color: dimgray;";
    if (record.logLevel == kXLLogLevel_Warning) {
      style = "color: orange;";
    } else if (record.logLevel == kXLLogLevel_Error) {
      style = "color: red;";
    } else if (record.logLevel >= kXLLogLevel_Exception) {
      style = "color: red; font-weight: bold;";
    }
    NSString* formattedMessage = [self formatRecord:record];
    [string appendFormat:@"<tr style=\"%s\">%@</tr>", style, formattedMessage];
    if (record.absoluteTime > maxTime) {
      maxTime = record.absoluteTime;
    }
  }];
  [string appendFormat:@"<tr id=\"maxTime\" data-value=\"%f\"></tr>", maxTime];
}

- (BOOL)_processHTTPRequest:(CFHTTPMessageRef)request forConnection:(XLHTTPServerConnection*)connection {
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
      
      success = [self _writeHTMLResponse:string forConnection:connection];
    } else if ([path isEqualToString:@"/log"] && [query hasPrefix:@"after="]) {
      NSMutableString* string = [[NSMutableString alloc] init];
      CFAbsoluteTime time = [[query substringFromIndex:6] doubleValue];
      
      dispatch_sync(_lockQueue, ^{
        connection.longPolling = YES;
      });
      dispatch_semaphore_wait(connection.semaphore, dispatch_time(DISPATCH_TIME_NOW, kMaxLongPollDuration * NSEC_PER_SEC));
      
      [self _appendLogRecordsToString:string afterAbsoluteTime:time];
      
      success = [self _writeHTMLResponse:string forConnection:connection];
    }
    
  } else {
    XLOG_INTERNAL(@"Unsupported HTTP method in request: %@", method);
  }
  return success;
}

- (void)_readHTTPRequestForConnection:(XLHTTPServerConnection*)connection {
  dispatch_read(connection.socket, SIZE_MAX, kDispatchQueue, ^(dispatch_data_t data, int error) {
    @autoreleasepool {
      BOOL success = NO;
      if (error == 0) {
        CFHTTPMessageRef message = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true);
        dispatch_data_apply(data, ^bool(dispatch_data_t region, size_t offset, const void* buffer, size_t length) {
          CFHTTPMessageAppendBytes(message, buffer, length);
          return true;
        });
        if (CFHTTPMessageIsHeaderComplete(message)) {
          success = [self _processHTTPRequest:message forConnection:connection];
        } else {
          XLOG_INTERNAL(@"%@", @"Failed parsing HTTP request headers");
        }
        CFRelease(message);
      } else {
        XLOG_INTERNAL(@"Failed reading socket: %s", strerror(error));
      }
      if (!success) {
        [self _closeConnection:connection];
      }
    }
  });
}

- (BOOL)open {
  BOOL success = NO;
  if ([super open]) {
    int listeningSocket = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (listeningSocket > 0) {
      int yes = 1;
      setsockopt(listeningSocket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
      
      struct sockaddr_in addr4;
      bzero(&addr4, sizeof(addr4));
      addr4.sin_len = sizeof(addr4);
      addr4.sin_family = AF_INET;
      addr4.sin_port = htons(_port);
      addr4.sin_addr.s_addr = htonl(INADDR_ANY);
      if (bind(listeningSocket, (void*)&addr4, sizeof(addr4)) == 0) {
        if (listen(listeningSocket, kMaxPendingConnections) == 0) {
          _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, listeningSocket, 0, kDispatchQueue);
          
          dispatch_source_set_cancel_handler(_source, ^{
            close(listeningSocket);
            dispatch_semaphore_signal(_sourceSemaphore);
          });
          
          dispatch_source_set_event_handler(_source, ^{
            @autoreleasepool {
              struct sockaddr remoteSockAddr;
              socklen_t remoteAddrLen = sizeof(remoteSockAddr);
              int socket = accept(listeningSocket, &remoteSockAddr, &remoteAddrLen);
              if (socket > 0) {
                int noSigPipe = 1;
                setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, sizeof(noSigPipe));  // Make sure this socket cannot generate SIG_PIPE
                XLHTTPServerConnection* connection = [self _openConnectionOnSocket:socket];
                [self _readHTTPRequestForConnection:connection];
              } else {
                XLOG_INTERNAL(@"Failed accepting socket: %s", strerror(errno));
              }
            }
          });
          
          dispatch_resume(_source);
          success = YES;
        } else {
          XLOG_INTERNAL(@"Failed starting listening socket: %s", strerror(errno));
          close(listeningSocket);
        }
      } else {
        XLOG_INTERNAL(@"Failed binding listening socket: %s", strerror(errno));
        close(listeningSocket);
      }
    } else {
      XLOG_INTERNAL(@"Failed creating listening socket: %s", strerror(errno));
    }
  }
  return success;
}

- (void)logRecord:(XLRecord*)record {
  [super logRecord:record];
  
  dispatch_sync(_lockQueue, ^{
    for (XLHTTPServerConnection* connection in _connections) {
      if (connection.longPolling) {
        dispatch_semaphore_signal(connection.semaphore);
        connection.longPolling = NO;
      }
    }
  });
}

- (void)close {
  dispatch_source_cancel(_source);
  dispatch_semaphore_wait(_sourceSemaphore, DISPATCH_TIME_FOREVER);  // Wait until the cancellation handler has been called which guarantees the listening socket is closed
#if !OS_OBJECT_USE_OBJC_RETAIN_RELEASE
  dispatch_release(_source);
#endif
  _source = NULL;
  
  [super close];
}

@end
