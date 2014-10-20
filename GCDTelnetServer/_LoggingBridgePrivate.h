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
 *  Automatically detect if XLFacility is available.
 */

#if defined(__has_include) && __has_include("XLFacilityMacros.h")

#define __LOGGING_BRIDGE_XLFACILITY__

#import "XLFacilityMacros.h"

#define _LOG_DEBUG(...) XLOG_DEBUG(__VA_ARGS__)
#define _LOG_VERBOSE(...) XLOG_VERBOSE(__VA_ARGS__)
#define _LOG_INFO(...) XLOG_INFO(__VA_ARGS__)
#define _LOG_WARNING(...) XLOG_WARNING(__VA_ARGS__)
#define _LOG_ERROR(...) XLOG_ERROR(__VA_ARGS__)
#define _LOG_EXCEPTION(__EXCEPTION__) XLOG_EXCEPTION(__EXCEPTION__)

#define _LOG_DEBUG_CHECK(__CONDITION__) XLOG_DEBUG_CHECK(__CONDITION__)
#define _LOG_DEBUG_UNREACHABLE() XLOG_DEBUG_UNREACHABLE()

/**
 *  Automatically detect if CocoaLumberJack is available.
 */

#elif defined(__has_include) && __has_include("DDLogMacros.h")

#import "DDLogMacros.h"

#define __LOGGING_BRIDGE_COCOALUMBERJACK__

#undef LOG_LEVEL_DEF
#define LOG_LEVEL_DEF _LoggingMinLevel
extern int _LoggingMinLevel;

#define _LOG_DEBUG(...) DDLogDebug(__VA_ARGS__)
#define _LOG_VERBOSE(...) DDLogVerbose(__VA_ARGS__)
#define _LOG_INFO(...) DDLogInfo(__VA_ARGS__)
#define _LOG_WARNING(...) DDLogWarn(__VA_ARGS__)
#define _LOG_ERROR(...) DDLogError(__VA_ARGS__)
#define _LOG_EXCEPTION(__EXCEPTION__) DDLogError(@"%@", __EXCEPTION__)

/**
 *  Check if a custom logging header should be used instead.
 */

#elif defined(__LOGGING_CUSTOM_HEADER__)

#define __LOGGING_BRIDGE_CUSTOM__

#import __LOGGING_CUSTOM_HEADER__

/**
 *  If all of the above fail, fall back to NSLog().
 */

#else

#define __LOGGING_BRIDGE_BUILTIN__

#if DEBUG
#define _LOG_DEBUG(...) NSLog(__VA_ARGS__)
#define _LOG_VERBOSE(...) NSLog(__VA_ARGS__)
#define _LOG_INFO(...) NSLog(__VA_ARGS__)
#else
#define _LOG_DEBUG(...)
#define _LOG_VERBOSE(...)
#define _LOG_INFO(...)
#endif
#define _LOG_WARNING(...) NSLog(__VA_ARGS__)
#define _LOG_ERROR(...) NSLog(__VA_ARGS__)
#define _LOG_EXCEPTION(__EXCEPTION__)  NSLog(@"%@", __EXCEPTION__)

#endif

/**
 *  Consistency check macros.
 */

#if !defined(_LOG_CHECK)
  #define _LOG_CHECK(__CONDITION__) \
    do { \
      if (!(__CONDITION__)) { \
        abort(); \
      } \
    } while (0)
#endif

#if !defined(_LOG_DEBUG_CHECK)
  #if DEBUG
    #define _LOG_DEBUG_CHECK(__CONDITION__) _LOG_CHECK(__CONDITION__)
  #else
    #define _LOG_DEBUG_CHECK(__CONDITION__)
  #endif
#endif

#if !defined(_LOG_UNREACHABLE)
  #define _LOG_UNREACHABLE() abort()
#endif

#if !defined(_LOG_DEBUG_UNREACHABLE)
  #if DEBUG
    #define _LOG_DEBUG_UNREACHABLE() _LOG_UNREACHABLE()
  #else
    #define _LOG_DEBUG_UNREACHABLE()
  #endif
#endif
