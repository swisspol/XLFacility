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

#import "XLRecord.h"

/*
 %l: level name
 %L: level name padded to constant width with trailing spaces
 %m: message
 %M: message
 %u: user ID
 %p: process ID
 %P: process name
 %r: thread ID
 %q: queue label (or "(null)" if not available)
 %t: relative timestamp since process started in "HH:mm:ss.SSS" format
 %d: date-time formatted using the "datetimeFormatter" property
 %e: errno as an integer
 %E: errno as a string
 %c: Callstack (or nothing if not available)

 \n: newline character
 \r: return character
 \t: tab character
 \%: percent character
 \\: backslash character
*/

typedef BOOL (^XLRecordFilterBlock)(XLRecord* record);

@interface XLLogger : NSObject
@property(nonatomic) XLLogLevel minLogLevel;  // Default is DEBUG
@property(nonatomic) XLLogLevel maxLogLevel;  // Default is ABORT
@property(nonatomic, copy) XLRecordFilterBlock recordFilter;  // Default is NULL
- (BOOL)open;  // May be implemeted by subclasses - Default implementation does nothing
- (void)logRecord:(XLRecord*)record;  // Must be implemented by subclasses
- (void)close;  // May be implemeted by subclasses - Default implementation does nothing

@property(nonatomic, copy) NSString* format;  // Default is "%t [%L]> %m%c\n"
@property(nonatomic, readonly) NSDateFormatter* datetimeFormatter;  // Default format is "yyyy-MM-dd HH:mm:ss.SSS"
@property(nonatomic, copy) NSString* callstackHeader;  // Default is "\n\n>>> Captured call stack:\n"
@property(nonatomic, copy) NSString* callstackFooter;  // Default is nil
@property(nonatomic, copy) NSString* multilinesPrefix;  // Default is nil
- (NSString*)formatRecord:(XLRecord*)record;

- (BOOL)shouldLogRecord:(XLRecord*)record;  // Default implementation checks record against min & max log levels and applies record filter if defined
@end

@interface XLLogger (Extensions)
- (NSString*)sanitizeMessageFromRecord:(XLRecord*)record;  // Normalizes all newline characters
- (NSString*)formatCallstackFromRecord:(XLRecord*)record;  // Returns nil if record has no callstack
@end
