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

#import "XLFacility.h"

/**
 *  The XLLogRecord class encapsulates information about messages logged
 *  through XLFacility.
 */
@interface XLLogRecord : NSObject

/**
 *  Returns the absolute time when the message was logged.
 */
@property(nonatomic, readonly) CFAbsoluteTime absoluteTime;

/**
 *  Returns the tag used when logging the message.
 */
@property(nonatomic, readonly) NSString* tag;

/**
 *  Returns the log level used when logging the message.
 */
@property(nonatomic, readonly) XLLogLevel level;

/**
 *  Returns the log message.
 */
@property(nonatomic, readonly) NSString* message;

/**
 *  Returns the errno value when the message was logged.
 */
@property(nonatomic, readonly) int capturedErrno;

/**
 *  Returns the thread ID when the message was logged.
 */
@property(nonatomic, readonly) int capturedThreadID;

/**
 *  Returns the GCD queue label when the message was logged (may be nil).
 */
@property(nonatomic, readonly) NSString* capturedQueueLabel;

/**
 *  Returns the callstack when the message was logged (may be nil).
 */
@property(nonatomic, readonly) NSArray* callstack;

@end
