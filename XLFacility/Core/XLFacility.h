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

#import <Foundation/Foundation.h>

/**
 *  Constants representing the supported log levels in XLFacility.
 */
typedef NS_ENUM(int, XLLogLevel) {
  kXLLogLevel_Debug = 0,
  kXLLogLevel_Verbose,
  kXLLogLevel_Info,
  kXLLogLevel_Warning,
  kXLLogLevel_Error,
  kXLLogLevel_Exception,
  kXLLogLevel_Abort,
  kXLMinLogLevel = kXLLogLevel_Debug,
  kXLMaxLogLevel = kXLLogLevel_Abort,
  kXLMuteLogLevel = INT_MAX
};

/**
 *  Constants representing the built-in tags in XLFacility.
 */
extern NSString* const XLFacilityTag_Internal;
extern NSString* const XLFacilityTag_CapturedStdOut;
extern NSString* const XLFacilityTag_CapturedStdErr;
extern NSString* const XLFacilityTag_UncaughtExceptions;
extern NSString* const XLFacilityTag_InitializedExceptions;

@class XLLogger;

/**
 *  The XLFacility class is the central class of the XLFacility system.
 *
 *  The shared XLFacility instance is automatically created when the process
 *  starts.
 *
 *  @warning By default XLFacility has the [XLStandardLogger sharedErrorLogger]
 *  logger pre-installed if stderr is connected to a terminal type device.
 *  To remove this logger add this line to the main() function of your app:
 *  [XLSharedFacility removeLogger:[XLStandardLogger sharedErrorLogger]]
 */
@interface XLFacility : NSObject

/**
 *  Sets the minimum log level below which log messages are ignored.
 *
 *  If you want to "mute" entirely XLFacility, simply set this property to
 *  "kXLMuteLogLevel".
 *
 *  The default value is INFO (or DEBUG if the preprocessor constant "DEBUG"
 *  evaluates to non-zero at build time). This default value can also be overridden
 *  at run time by setting the environment variable "XLFacilityMinLogLevel" to the
 *  integer value for the level.
 */
@property(nonatomic) XLLogLevel minLogLevel;

/**
 *  Sets the minimum log level below which callstack are not captured along with
 *  log messages.
 *
 *  The default value is EXCEPTION.
 */
@property(nonatomic) XLLogLevel minCaptureCallstackLevel;

/**
 *  Sets the minimum log level below which internal log messages from within
 *  XLFacility (which have the XLFacilityTag_Internal tag) are ignored.
 *
 *  If you want to "mute" entirely XLFacility internal log messages, simply set
 *  this property to "kXLMuteLogLevel".
 *
 *  The default value is the same as "minLogLevel".
 */
@property(nonatomic) XLLogLevel minInternalLogLevel;

/**
 *  Returns all currently added loggers.
 */
@property(nonatomic, readonly) NSSet* loggers;

/**
 *  Returns the shared XLFacility instance.
 *
 *  You can also use the "XLSharedFacility" global variable to make your code
 *  slightly more compact.
 */
+ (XLFacility*)sharedFacility;

/**
 *  Adds a logger to XLFacility.
 *
 *  Returns YES if the logger was added successfully.
 */
- (BOOL)addLogger:(XLLogger*)logger;

/**
 *  Removes a logger from XLFacility.
 */
- (void)removeLogger:(XLLogger*)logger;

/**
 *  Removes all loggers from XLFacility.
*/
- (void)removeAllLoggers;

@end

@interface XLFacility (Logging)

/**
 *  Logs a message with an optional tag and specific log level.
 *
 *  Pass nil for "tag" if you don't need one.
 */
- (void)logMessage:(NSString*)message withTag:(NSString*)tag level:(XLLogLevel)level;

/**
 *  Logs a message as a format string with an optional tag and specific log
 *  level.
 *
 *  Pass nil for "tag" if you don't need one.
 */
- (void)logMessageWithTag:(NSString*)tag level:(XLLogLevel)level format:(NSString*)format, ... NS_FORMAT_FUNCTION(3, 4);

/**
 *  Logs an exception with an optional tag and EXCEPTION log level.
 *
 *  The log message is automatically generated and the exception callstack is
 *  extracted.
 *
 *  Pass nil for "tag" if you don't need one.
 */
- (void)logException:(NSException*)exception withTag:(NSString*)tag;

@end

@interface XLFacility (Extensions)

/**
 *  Sets if XLFacility automatically logs uncaught exceptions.
 *
 *  The default value is NO.
 */
@property(nonatomic) BOOL logsUncaughtExceptions;

/**
 *  Sets if XLFacility automatically logs all exceptions at the moment they are
 *  created and wether or not they are caught.
 *
 *  The default value is NO.
 *
 *  @warning Note that this will also capture exceptions that are not thrown either.
 */
@property(nonatomic) BOOL logsInitializedExceptions;

/**
 *  Sets if XLFacility captures the standard output of the process and converts it
 *  into log messages at the INFO level after splitting on newlines boundaries.
 *
 *  The default value is NO.
 *
 *  @warning XLFacility achieves this by redirecting the file descriptor but since
 *  the original one is preserved so this method can still be used along with
 *  [XLStandardLogger sharedOutputLogger].
 */
@property(nonatomic) BOOL capturesStandardOutput;

/**
 *  Sets if XLFacility captures the standard output of the process and converts it
 *  into log messages at the ERROR level after splitting on newlines boundaries.
 *
 *  The default value is NO.
 *
 *  @warning XLFacility achieves this by redirecting the file descriptor but since
 *  the original one is preserved so this method can still be used along with
 *  [XLStandardLogger sharedErrorLogger].
 */
@property(nonatomic) BOOL capturesStandardError;

@end

/**
 *  Convenience global variable to access the global minimum log level.
 */
extern XLLogLevel XLMinLogLevel;

/**
 *  Convenience global variable to access the shared XLFacility instance.
 */
extern XLFacility* XLSharedFacility;
