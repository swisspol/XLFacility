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
 *  It's highly recommended you use them instead of calling the -[log...]
 *  methods on the shared XLFacility instance. Not only are they quite easier
 *  to the eye but most importantly they avoid evaluating their arguments
 *  unless necessary.
 
 *  For instance, if the log level for XLFacility is set to ERROR, calling
 *  XLOG_WARNING(@"Unexpected value: %@", value)` will almost be a no-op
 *  while [XLSharedFacility logWarning:@"Unexpected value: %@", value]
 *  will still evaluate all the arguments (which can be quite expensive),
 *  compute the format string, and finally pass everything to the XLFacility
 *  shared instance where it will be ignored anyway.
 */

#if DEBUG
#define XLOG_DEBUG(...) do { if (XLMinLogLevel <= kXLLogLevel_Debug) [XLSharedFacility logDebug:__VA_ARGS__]; } while (0)
#else
#define XLOG_DEBUG(...)
#endif
#define XLOG_VERBOSE(...) do { if (XLMinLogLevel <= kXLLogLevel_Verbose) [XLSharedFacility logVerbose:__VA_ARGS__]; } while (0)
#define XLOG_INFO(...) do { if (XLMinLogLevel <= kXLLogLevel_Info) [XLSharedFacility logInfo:__VA_ARGS__]; } while (0)
#define XLOG_WARNING(...) do { if (XLMinLogLevel <= kXLLogLevel_Warning) [XLSharedFacility logWarning:__VA_ARGS__]; } while (0)
#define XLOG_ERROR(...) do { if (XLMinLogLevel <= kXLLogLevel_Error) [XLSharedFacility logError:__VA_ARGS__]; } while (0)
#define XLOG_EXCEPTION(__EXCEPTION__) do { if (XLMinLogLevel <= kXLLogLevel_Exception) [XLSharedFacility logException:__EXCEPTION__]; } while (0)
#define XLOG_ABORT(...) do { if (XLMinLogLevel <= kXLLogLevel_Abort) [XLSharedFacility logAbort:__VA_ARGS__]; } while (0)

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
