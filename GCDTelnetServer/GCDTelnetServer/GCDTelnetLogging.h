/*
 Copyright (c) 2012-2014, Pierre-Olivier Latour
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
 *  Automatically detect if XLFacility is available and if so use it as a
 *  logging facility.
 */

#if defined(__has_include) && __has_include("XLFacilityMacros.h")

#define __GCDNETWORKING_LOGGING_FACILITY_XLFACILITY__

#undef XLOG_TAG
#define XLOG_TAG @"gcdnetworking.internal"

#import "XLFacilityMacros.h"

#define GN_LOG_DEBUG(...) XLOG_DEBUG(__VA_ARGS__)
#define GN_LOG_VERBOSE(...) XLOG_VERBOSE(__VA_ARGS__)
#define GN_LOG_INFO(...) XLOG_INFO(__VA_ARGS__)
#define GN_LOG_WARNING(...) XLOG_WARNING(__VA_ARGS__)
#define GN_LOG_ERROR(...) XLOG_ERROR(__VA_ARGS__)
#define GN_LOG_EXCEPTION(__EXCEPTION__) XLOG_EXCEPTION(__EXCEPTION__)

#define GN_DCHECK(__CONDITION__) XLOG_DEBUG_CHECK(__CONDITION__)
#define GN_DNOT_REACHED() XLOG_DEBUG_UNREACHABLE()

/**
 *  Automatically detect if CocoaLumberJack is available and if so use
 *  it as a logging facility.
 */

#elif defined(__has_include) && __has_include("DDLogMacros.h")

#import "DDLogMacros.h"

#define __GCDNETWORKING_LOGGING_FACILITY_COCOALUMBERJACK__

#undef LOG_LEVEL_DEF
#define LOG_LEVEL_DEF GCDNetworkingLogLevel
extern int GCDNetworkingLogLevel;

#define GN_LOG_DEBUG(...) DDLogDebug(__VA_ARGS__)
#define GN_LOG_VERBOSE(...) DDLogVerbose(__VA_ARGS__)
#define GN_LOG_INFO(...) DDLogInfo(__VA_ARGS__)
#define GN_LOG_WARNING(...) DDLogWarn(__VA_ARGS__)
#define GN_LOG_ERROR(...) DDLogError(__VA_ARGS__)
#define GN_LOG_EXCEPTION(__EXCEPTION__) DDLogError(@"%@", __EXCEPTION__)

/**
 *  Check if a custom logging facility should be used instead.
 */

#elif defined(__GCDNETWORKING_LOGGING_HEADER__)

#define __GCDNETWORKING_LOGGING_FACILITY_CUSTOM__

#import __GCDNETWORKING_LOGGING_HEADER__

/**
 *  If all of the above fail, then use GCDNetworking built-in
 *  logging facility.
 */

#else

#define __GCDNETWORKING_LOGGING_FACILITY_BUILTIN__

typedef NS_ENUM(int, GCDNetworkingLoggingLevel) {
  kGCDNetworkingLoggingLevel_Debug = 0,
  kGCDNetworkingLoggingLevel_Verbose,
  kGCDNetworkingLoggingLevel_Info,
  kGCDNetworkingLoggingLevel_Warning,
  kGCDNetworkingLoggingLevel_Error,
  kGCDNetworkingLoggingLevel_Exception,
};

extern GCDNetworkingLoggingLevel GCDNetworkingLogLevel;
extern void GCDNetworkingLogMessage(GCDNetworkingLoggingLevel level, NSString* format, ...) NS_FORMAT_FUNCTION(2, 3);

#if DEBUG
#define GN_LOG_DEBUG(...) do { if (GCDNetworkingLogLevel <= kGCDNetworkingLoggingLevel_Debug) GCDNetworkingLogMessage(kGCDNetworkingLoggingLevel_Debug, __VA_ARGS__); } while (0)
#else
#define GN_LOG_DEBUG(...)
#endif
#define GN_LOG_VERBOSE(...) do { if (GCDNetworkingLogLevel <= kGCDNetworkingLoggingLevel_Verbose) GCDNetworkingLogMessage(kGCDNetworkingLoggingLevel_Verbose, __VA_ARGS__); } while (0)
#define GN_LOG_INFO(...) do { if (GCDNetworkingLogLevel <= kGCDNetworkingLoggingLevel_Info) GCDNetworkingLogMessage(kGCDNetworkingLoggingLevel_Info, __VA_ARGS__); } while (0)
#define GN_LOG_WARNING(...) do { if (GCDNetworkingLogLevel <= kGCDNetworkingLoggingLevel_Warning) GCDNetworkingLogMessage(kGCDNetworkingLoggingLevel_Warning, __VA_ARGS__); } while (0)
#define GN_LOG_ERROR(...) do { if (GCDNetworkingLogLevel <= kGCDNetworkingLoggingLevel_Error) GCDNetworkingLogMessage(kGCDNetworkingLoggingLevel_Error, __VA_ARGS__); } while (0)
#define GN_LOG_EXCEPTION(__EXCEPTION__) do { if (GCDNetworkingLogLevel <= kGCDNetworkingLoggingLevel_Exception) GCDNetworkingLogMessage(kGCDNetworkingLoggingLevel_Exception, @"%@", __EXCEPTION__); } while (0)

#endif

/**
 *  Consistency check macros used when building Debug only.
 */

#if !defined(GN_DCHECK) || !defined(GN_DNOT_REACHED)

#if DEBUG

#define GN_DCHECK(__CONDITION__) \
  do { \
    if (!(__CONDITION__)) { \
      abort(); \
    } \
  } while (0)
#define GN_DNOT_REACHED() abort()

#else

#define GN_DCHECK(__CONDITION__)
#define GN_DNOT_REACHED()

#endif

#endif
