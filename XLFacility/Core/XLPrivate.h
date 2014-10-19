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

#import "XLLogger.h"

/**
 *  Override default tag when logging messages from inside XLFacility.
 */

#undef XLOG_TAG
#define XLOG_TAG XLFacilityTag_Internal

#import "XLFacilityMacros.h"

/**
 *  XLFacility internal constants and APIs.
 */

#define XL_DISPATCH_QUEUE_LABEL object_getClassName(self)

#define XL_GLOBAL_DISPATCH_QUEUE dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)

extern int XLOriginalStdOut;
extern int XLOriginalStdErr;

extern NSString* XLPaddedStringFromLogLevelName(XLLogLevel level);

@interface XLLogRecord ()
- (id)initWithAbsoluteTime:(CFAbsoluteTime)absoluteTime
                       tag:(NSString*)tag
                     level:(XLLogLevel)level
                   message:(NSString*)message
             capturedErrno:(int)capturedErrno
          capturedThreadID:(int)capturedThreadID
        capturedQueueLabel:(NSString*)capturedQueueLabel
                 callstack:(NSArray*)callstack;
- (id)initWithAbsoluteTime:(CFAbsoluteTime)absoluteTime
                       tag:(NSString*)tag
                     level:(XLLogLevel)level
                   message:(NSString*)message
                 callstack:(NSArray*)callstack;
@end

@interface XLLogger ()
@property(nonatomic, readonly) dispatch_queue_t serialQueue;
@property(nonatomic, getter=isReady) BOOL ready;
- (BOOL)shouldLogRecord:(XLLogRecord*)record;
- (BOOL)performOpen;
- (void)performLogRecord:(XLLogRecord*)record;
- (void)performClose;
@end
