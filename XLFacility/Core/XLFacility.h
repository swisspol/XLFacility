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
  kXLMaxLogLevel = kXLLogLevel_Abort
};

/**
 *  Converts a NSString to an UTF-8 string.
 *
 *  Contrary to -[NSString dataUsingEncoding:] this function is guaranteed
 *  to return a non-nil result as long as the input string is not nil.
 */
extern NSData* XLConvertNSStringToUTF8String(NSString* string);

/**
 *  Converts a NSString to an UTF-8 NULL terminated C string.
 *
 *  Contrary to -[NSString UTF8String] this function is guaranteed to return
 *  a non-NULL result as long as the input string is not nil.
 */
extern const char* XLConvertNSStringToUTF8CString(NSString* string);

@class XLLogger;

/**
 *  The XLFacility class is the central class of the XLFacility system.
 *
 *  The shared XLFacility instance is automatically created when the process
 *  starts.
 *
 *  @warning By default XLFacility has the [XLStandardLogger sharedStdErrLogger]
 *  logger pre-installed if stderr is connected to a terminal type device.
 *  To remove this logger add this line to the main() function of your app:
 *  [XLSharedFacility removeLogger:[XLStandardLogger sharedStdErrLogger]]
 */
@interface XLFacility : NSObject

/**
 *  Sets the minimum log level below which log messages are ignored.
 *
 *  The default value is INFO (or DEBUG if the preprocessor constant "DEBUG"
 *  evaluates to non-zero at build time). This default value can also be overridden
 *  at run time by setting the environment variable "XLFacilityMinLogLevel" to the
 *  integer value for the level.
 *
 *  If you want to "mute" entirely XLFacility, simply set the `minLogLevel` property
 *  to very a high value like `INT_MAX`.
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
 *  Returns the logger if added successfully (i.e. it was not already added and
 *  was opened successfully).
 */
- (XLLogger*)addLogger:(XLLogger*)logger;

/**
 *  Removes a logger from XLFacility.
 *
 *  Return YES if the logger was found (and therefore removed).
 */
- (void)removeLogger:(XLLogger*)logger;

/**
 *  Removes all loggers from XLFacility.
*/
- (void)removeAllLoggers;

@end

@interface XLFacility (Logging)

/**
 *  Logs a message with a specific log level.
 */
- (void)logMessage:(NSString*)message withLevel:(XLLogLevel)level;

/**
 *  Logs a message as a format string with a specific log level.
 */
- (void)logMessageWithLevel:(XLLogLevel)level format:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 *  Logs a message as a format string with the DEBUG log level.
 */
- (void)logDebug:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);

/**
 *  Logs a message as a format string with the VERBOSE log level.
 */
- (void)logVerbose:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);

/**
 *  Logs a message as a format string with the INFO log level.
 */
- (void)logInfo:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);

/**
 *  Logs a message as a format string with the WARNING log level.
 */
- (void)logWarning:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);

/**
 *  Logs a message as a format string with the ERROR log level.
 */
- (void)logError:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);

/**
 *  Logs an exception the DEBUG log level.
 *
 *  The log message is automatically generated.
 */
- (void)logException:(NSException*)exception;

/**
 *  Logs a message as a format string with the ABORT log level.
 */
- (void)logAbort:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);

@end

@interface XLFacility (Extensions)

/**
 *  Sets if XLFacility automatically logs of uncaught exceptions.
 *
 *  Default value is NO;
 */
@property(nonatomic) BOOL logsUncaughtExceptions;

/**
 *  Sets if XLFacility automatically logs all exceptions at the moment they are
 *  created and wether or not they are caught.
 *
 *  Default value is NO;
 *
 *  @warning Note that this will also capture exceptions that are not thrown either.
 */
@property(nonatomic) BOOL logsInitializedExceptions;

/**
 *  Sets if XLFacility captures the standard output of the process and converts it
 *  into log messages at the INFO level after splitting on newlines boundaries.
 *
 *  Default value is NO;
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
 *  Default value is NO;
 *
 *  @warning XLFacility achieves this by redirecting the file descriptor but since
 *  the original one is preserved so this method can still be used along with
 *  [XLStandardLogger sharedErrorLogger].
 */
@property(nonatomic) BOOL capturesStandardError;

@end

/**
 *  Convenience global variable to access the shared XLFacility instance.
 */
extern XLFacility* XLSharedFacility;
