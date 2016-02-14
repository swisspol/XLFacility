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

#import "XLLogRecord.h"

@implementation XLLogRecord

- (id)initWithAbsoluteTime:(CFAbsoluteTime)absoluteTime
                 tag:(NSString*)tag
                     level:(XLLogLevel)level
                   message:(NSString*)message
             capturedErrno:(int)capturedErrno
          capturedThreadID:(int)capturedThreadID
        capturedQueueLabel:(NSString*)capturedQueueLabel
                 callstack:(NSArray*)callstack {
  if ((self = [super init])) {
    _absoluteTime = absoluteTime;
    _tag = tag;
    _level = level;
    _message = message;
    _capturedErrno = capturedErrno;
    _capturedThreadID = capturedThreadID;
    _capturedQueueLabel = capturedQueueLabel;
    _callstack = callstack;
  }
  return self;
}

- (id)initWithAbsoluteTime:(CFAbsoluteTime)absoluteTime
                       tag:(NSString*)tag
                     level:(XLLogLevel)level
                   message:(NSString*)message
                 callstack:(NSArray*)callstack {
  const char* label = NULL;
#if TARGET_OS_IPHONE
  if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0)
#else
  if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber10_9)
#endif
  {
    label = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);  // This returns garbage before iOS 7 and OS X 10.9 (e.g. an non-accessible string)
    if (!label[0]) {
      label = NULL;
    }
  }
  uint64_t threadID = 0;
  pthread_threadid_np(pthread_self(), &threadID);
  return [self initWithAbsoluteTime:absoluteTime
                                tag:tag
                              level:level
                            message:message
                      capturedErrno:errno
                   capturedThreadID:(int)threadID
                 capturedQueueLabel:(label ? [NSString stringWithUTF8String:label] : nil)
                          callstack:callstack];
}

- (BOOL)isEqual:(id)object {
  if ([object isKindOfClass:[XLLogRecord class]]) {
    XLLogRecord* other = object;
    if (fabs(other->_absoluteTime - _absoluteTime) >= 0.001) {  // 1ms
      return NO;
    }
    if ((_tag && !other->_tag) || (!_tag && other->_tag) || (_tag && other->_tag && ![_tag isEqualToString:other->_tag])) {
      return NO;
    }
    if (_level != other->_level) {
      return NO;
    }
    if ((_message && !other->_message) || (!_message && other->_message) || (_message && other->_message && ![_message isEqualToString:other->_message])) {
      return NO;
    }
    if (_capturedErrno != other->_capturedErrno) {
      return NO;
    }
    if (_capturedThreadID != other->_capturedThreadID) {
      return NO;
    }
    if ((_capturedQueueLabel && !other->_capturedQueueLabel) || (!_capturedQueueLabel && other->_capturedQueueLabel) || (_capturedQueueLabel && other->_capturedQueueLabel && ![_capturedQueueLabel isEqualToString:other->_capturedQueueLabel])) {
      return NO;
    }
    if ((_callstack && !other->_callstack) || (!_callstack && other->_callstack) || (_callstack && other->_callstack && ![_callstack isEqualToArray:other->_callstack])) {
      return NO;
    }
  }
  return YES;
}

- (NSString*)description {
  return [[NSString alloc] initWithFormat:@"(%@) %@", [NSDate dateWithTimeIntervalSinceReferenceDate:_absoluteTime], _message];
}

@end
