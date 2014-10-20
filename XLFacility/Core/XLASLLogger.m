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

#import <asl.h>

#import "XLASLLogger.h"
#import "XLFunctions.h"
#import "XLFacilityPrivate.h"

@interface XLASLLogger () {
@private
  aslclient _client;
}
@end

@implementation XLASLLogger

+ (XLASLLogger*)sharedLogger {
  static XLASLLogger* logger = nil;
  static dispatch_once_t onceToken = 0;
  dispatch_once(&onceToken, ^{
    logger = [[XLASLLogger alloc] init];
  });
  return logger;
}

- (BOOL)open {
  _client = asl_open(NULL, NULL, ASL_OPT_NO_DELAY);
  if (!_client) {
    XLOG_ERROR(@"Failed connecting to the ASL server");
    return NO;
  }
  asl_set_filter(_client, ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG));  // Default is ASL_LEVEL_NOTICE
  return YES;
}

- (void)logRecord:(XLLogRecord*)record {
  static const char* levelMapping[] = {"7", "6", "5", "4", "3", "2", "1"};
  aslmsg message = asl_new(ASL_TYPE_MSG);
  asl_set(message, ASL_KEY_LEVEL, levelMapping[record.level]);
  asl_set(message, ASL_KEY_MSG, XLConvertNSStringToUTF8CString([self sanitizeMessageFromRecord:record]));
  asl_send(_client, message);  // This automatically sets ASL_KEY_TIME with no possibility to override
  asl_free(message);
}

- (void)close {
  asl_close(_client);
  _client = NULL;
}

@end
