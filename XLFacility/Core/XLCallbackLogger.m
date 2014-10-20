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

#import "XLCallbackLogger.h"
#import "XLFacilityPrivate.h"

@interface XLCallbackLogger () {
@private
  XLCallbackLoggerOpenBlock _openBlock;
  XLCallbackLoggerLogRecordBlock _logRecordBlock;
  XLCallbackLoggerCloseBlock _closeBlock;
}
@end

@implementation XLCallbackLogger

+ (instancetype)loggerWithCallback:(XLCallbackLoggerLogRecordBlock)callback {
  return [[[self class] alloc] initWithOpenCallback:NULL logRecordCallback:callback closeCallback:NULL];
}

- (id)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithOpenCallback:(XLCallbackLoggerOpenBlock)openCallback
                   logRecordCallback:(XLCallbackLoggerLogRecordBlock)logRecordCallback
                       closeCallback:(XLCallbackLoggerCloseBlock)closeCallback {
  
  XLOG_DEBUG_CHECK(logRecordCallback);
  if ((self = [super init])) {
    _openBlock = openCallback;
    _logRecordBlock = logRecordCallback;
    _closeBlock = closeCallback;
  }
  return self;
}

- (BOOL)open {
  return _openBlock ? _openBlock(self) : YES;
}

- (void)logRecord:(XLLogRecord*)record {
  _logRecordBlock(self, record);
}

- (void)close {
  if (_closeBlock) {
    _closeBlock(self);
  }
}

@end
