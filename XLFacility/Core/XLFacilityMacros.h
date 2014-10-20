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
 *  These macros which are used like NSLog() are the most efficient way to log
 *  messages with XLFacility.
 *
 *  It's highly recommended you use them instead of calling the logging methods
 *  on the shared XLFacility instance. Not only are they faster to type and
 *  quite easier to the eye, but most importantly they avoid evaluating their
 *  arguments unless necessary. For instance, if the log level for XLFacility
 *  is set to ERROR, calling:
 *
 *    XLOG_WARNING(@"Unexpected value: %@", value)`
 *
 *  will almost be a no-op while calling the method:
 *
 *    [XLSharedFacility logMessageWithTag:nil
 *                                  level:kXLLogLevel_Warning
 *                                 format:@"Unexpected value: %@", value]
 *
 *  will still evaluate all the arguments (which can be quite expensive),
 *  compute the format string, and finally pass everything to the XLFacility
 *  shared instance where it will be ignored anyway.
 *
 *  Messages logged with XLFacility can be associated with an optional tag
 *  which is an arbitrary string. You can use it to put log messages in
 *  namespaces or anything you want. The tag to associate with logged messages
 *  can be specified in two ways:
 *
 *  1) Manually by passing a non-nil "tag" argument when using the logging
 *  methods on the shared XLFacility instance.
 *
 *  2) Automatically when using the macros and defining the preprocessor
 *  constant "XLOG_TAG" to a string *before* including XLFacilityMacros.h.
 *
 *  As a convenience, if the preprocessor constant "DEBUG" evaluates to
 *  non-zero at build time (which typically indicates a Debug build versus
 *  a release build) and if "XLOG_TAG" is not defined, then tags will be
 *  generated from the source file name and line number from where the message
 *  is being logged.
 */

#ifndef XLOG_TAG
#if DEBUG
#define XLOG_STRINGIFY(x) #x
#define XLOG_STRINGIFY_(x) XLOG_STRINGIFY(x)
#define XLOG_LINE XLOG_STRINGIFY_(__LINE__)
#define XLOG_TAG (@ __FILE__ ":" XLOG_LINE)
#else
#define XLOG_TAG nil
#endif
#endif

#if DEBUG
#define XLOG_DEBUG(...) do { if (XLMinLogLevel <= kXLLogLevel_Debug) [XLSharedFacility logMessageWithTag:XLOG_TAG level:kXLLogLevel_Debug format:__VA_ARGS__]; } while (0)
#else
#define XLOG_DEBUG(...)
#endif
#define XLOG_VERBOSE(...) do { if (XLMinLogLevel <= kXLLogLevel_Verbose) [XLSharedFacility logMessageWithTag:XLOG_TAG level:kXLLogLevel_Verbose format:__VA_ARGS__]; } while (0)
#define XLOG_INFO(...) do { if (XLMinLogLevel <= kXLLogLevel_Info) [XLSharedFacility logMessageWithTag:XLOG_TAG level:kXLLogLevel_Info format:__VA_ARGS__]; } while (0)
#define XLOG_WARNING(...) do { if (XLMinLogLevel <= kXLLogLevel_Warning) [XLSharedFacility logMessageWithTag:XLOG_TAG level:kXLLogLevel_Warning format:__VA_ARGS__]; } while (0)
#define XLOG_ERROR(...) do { if (XLMinLogLevel <= kXLLogLevel_Error) [XLSharedFacility logMessageWithTag:XLOG_TAG level:kXLLogLevel_Error format:__VA_ARGS__]; } while (0)
#define XLOG_EXCEPTION(__EXCEPTION__) do { if (XLMinLogLevel <= kXLLogLevel_Exception) [XLSharedFacility logException:__EXCEPTION__ withTag:XLOG_TAG]; } while (0)
#define XLOG_ABORT(...) do { if (XLMinLogLevel <= kXLLogLevel_Abort) [XLSharedFacility logMessageWithTag:XLOG_TAG level:kXLLogLevel_Abort format:__VA_ARGS__]; } while (0)

/**
 *  These other macros let you easily check conditions inside your code and
 *  log messages with XLFacility on failure.
 *
 *  You can use them instead of assert() or NSAssert().
 */

#define XLOG_CHECK(__CONDITION__) \
do { \
  if (!(__CONDITION__)) { \
    XLOG_ABORT(@"Condition failed: \"%s\"", #__CONDITION__); \
  } \
} while (0)

#define XLOG_UNREACHABLE() \
do { \
  XLOG_ABORT(@"Unreachable code executed in '%s': %s:%i", __FUNCTION__, __FILE__, (int)__LINE__); \
} while (0)

#if DEBUG
#define XLOG_DEBUG_CHECK(__CONDITION__) XLOG_CHECK(__CONDITION__)
#define XLOG_DEBUG_UNREACHABLE() XLOG_UNREACHABLE()
#else
#define XLOG_DEBUG_CHECK(__CONDITION__)
#define XLOG_DEBUG_UNREACHABLE()
#endif
