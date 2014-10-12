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

extern const char* XLConvertNSStringToUTF8CString(NSString* string);

@class XLLogger;

// By default XLFacility has one logger pre-installed: [XLStandardLogger sharedStdErrLogger]
@interface XLFacility : NSObject
@property(nonatomic) XLLogLevel minLogLevel;  // Default is INFO (or DEBUG if the preprocessor constant "DEBUG" is non-zero at build time)
@property(nonatomic) XLLogLevel minCaptureCallstackLevel;  // Default is EXCEPTION
@property(nonatomic) BOOL callsLoggersConcurrently;  // Default is YES
@property(nonatomic, readonly) NSSet* loggers;
+ (XLFacility*)sharedFacility;

- (XLLogger*)addLogger:(XLLogger*)logger;  // Returns the logger if added successfully
- (BOOL)removeLogger:(XLLogger*)logger;  // Return YES if the logger was found (and therefore removed)
- (void)removeAllLoggers;

- (void)logMessage:(NSString*)message withLevel:(XLLogLevel)level;
- (void)logMessageWithLevel:(XLLogLevel)level format:(NSString*)format, ... NS_FORMAT_FUNCTION(2, 3);
- (void)logDebug:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);
- (void)logVerbose:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);
- (void)logInfo:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);
- (void)logWarning:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);
- (void)logError:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);
- (void)logException:(NSException*)exception;
- (void)logAbort:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);
@end

@interface XLFacility (Extensions)
+ (void)enableLoggingOfUncaughtExceptions;
+ (void)enableLoggingOfInitializedExceptions;
+ (void)enableCapturingOfStdOut;  // Redirects stdout to INFO and breaks automatically on newlines
+ (void)enableCapturingOfStdErr;  // Redirects stderr to ERROR and breaks automatically on newlines
@end

extern XLFacility* XLSharedFacility;  // Same as +[XLFacility sharedFacility]
