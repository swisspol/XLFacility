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

#import "XLLogRecord.h"

/**
 *  The XLLogRecordFilterBlock is called by the logger for every log record received.
 *  It should return YES if the logger can proceed with the log record or NO if it
 *  should ignore it.
 *
 *  @warning This block will be executed on arbitrary thread and also needs to be
 *  reentrant if used with multiple XLLogger instances.
 */
typedef BOOL (^XLLogRecordFilterBlock)(XLLogger* logger, XLLogRecord* record);

/**
 *  The default format string for XLFacility ("%t [%L]> %m%c").
 */
extern NSString* const XLLoggerFormatString_Default;

/**
 *  The format string to match NSLog().
 */
extern NSString* const XLLoggerFormatString_NSLog;

/**
 *  The XLLogger class is an abstract class for loggers that receive log records
 *  from XLFacility: it cannot be used directly.
 */
@interface XLLogger : NSObject

/**
 *  Returns YES if the logger is open.
 */
@property(nonatomic, readonly, getter=isOpen) BOOL open;

/**
 *  Sets the minimum log level below which received log records are ignored.
 *
 *  The default value is DEBUG.
 */
@property(nonatomic) XLLogLevel minLogLevel;

/**
 *  Sets the maximum log level above which received log records are ignored.
 *
 *  The default value is ABORT.
 */
@property(nonatomic) XLLogLevel maxLogLevel;

/**
 *  Sets the log record filter block.
 *
 *  The default value is NULL.
 */
@property(nonatomic, copy) XLLogRecordFilterBlock logRecordFilter;

@end

/**
 *  These methods are the ones to be implemented by subclasses.
 *
 *  @warning Each logger has its own internal GCD serial queue and -open,
 *  -logRecord: and -close are always executed on it.
 */
@interface XLLogger (Subclassing)

/**
 *  Called when the logger is added to XLFacility.
 *
 *  Returning NO will prevent the logger to be added.
 *
 *  The default implementation does nothing.
 */
- (BOOL)open;

/**
 *  Called whenever a log record is received from XLFacility.
 *
 *  @warning This method must be implemented by subclasseses.
 */
- (void)logRecord:(XLLogRecord*)record;

/**
 *  Called when the logger is removed from XLFacility.
 *
 *  The default implementation does nothing.
 */
- (void)close;

@end

@interface XLLogger (Formatting)

/**
 *  Sets the format string used to format log records by loggers which require
 *  formatting. The following format specifiers are supported:
 *
 *  %g: tag (or the value of "tagPlaceholder" property if not set)
 *  %l: level name
 *  %L: level name padded to constant width with trailing spaces
 *  %m: message
 *  %M: sanitized message (uses -sanitizeMessageFromRecord:)
 *  %u: user ID
 *  %p: process ID
 *  %P: process name
 *  %r: thread ID
 *  %q: queue label (or the value of "queueLabelPlaceholder" property if not set)
 *  %t: relative timestamp since process started in "HH:mm:ss.SSS" format
 *  %d: absolute date-time formatted using the "datetimeFormatter" property
 *  %e: errno as an integer
 *  %E: errno as a string
 *  %c: Callstack (or nothing if not available)
 *
 *  \n: newline character
 *  \r: return character
 *  \t: tab character
 *  \%: percent character
 *  \\: backslash character
 *
 *  The default value is XLLoggerFormatString_Default.
 *
 *  @warning Note that specifiers like the date-time, GCD queue label or "errno"
 *  value all reflect the state of the process at the time the message was sent
 *  to XLFacility, not when it is actually displayed in the Xcode console for
 *  instance.
 */
@property(nonatomic, copy) NSString* format;

/**
 *  Sets if a trailing newline should automatically be added at the end of the
 *  string returned by -formatRecord:.
 *
 *  The default value is YES.
 */
@property(nonatomic) BOOL appendNewlineToFormat;

/**
 *  Returns the NSDateFormatter used when formatting date-times for the "%d"
 *  format specifier.
 *
 *  The default format is "yyyy-MM-dd HH:mm:ss.SSS".
 *
 *  @warning Because NSDateFormatter is not thread-safe on older iOS and OS X
 *  versions, this formatter should not be configured after the logger has
 *  been added to XLFacility.
 */
@property(nonatomic, readonly) NSDateFormatter* datetimeFormatter;

/**
 *  Sets the placeholder string used by the "%g" format specifier.
 *
 *  The default value is "(none)".
 */
@property(nonatomic, copy) NSString* tagPlaceholder;

/**
 *  Sets the placeholder string used by the "%q" format specifier.
 *
 *  The default value is "(none)".
 */
@property(nonatomic, copy) NSString* queueLabelPlaceholder;

/**
 *  Sets the header string used by -formatCallstackFromRecord: to be inserted
 *  before the callstack.
 *
 *  The default value is "\n\n>>> Captured call stack:\n".
 */
@property(nonatomic, copy) NSString* callstackHeader;

/**
 *  Sets the footer string used by -formatCallstackFromRecord: to be inserted
 *  after the callstack.
 *
 *  The default value is nil.
 */
@property(nonatomic, copy) NSString* callstackFooter;  // Default is nil

/**
 *  Sets the prefix string used by -formatRecord: to be inserted before each
 *  line after the first one (in case the result string spans multiple lines).
 *
 *  The default value is nil.
 */
@property(nonatomic, copy) NSString* multilinesPrefix;

/**
 *  Converts a log record into a string using the format set for the logger.
 */
- (NSString*)formatRecord:(XLLogRecord*)record;

/**
 *  Converts the callstack from a log record into a string.
 *
 *  This method returns nil if the log record has no callstack.
 */
- (NSString*)formatCallstackFromRecord:(XLLogRecord*)record;

/**
 *  Returns a sanitized version of the message from a log record.
 *
 *  The current implementation normalizes all newline characters in the message
 *  to be '\n'.
 */
- (NSString*)sanitizeMessageFromRecord:(XLLogRecord*)record;

@end
