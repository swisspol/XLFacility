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

#ifndef __XLFacilityCMacros__
#define __XLFacilityCMacros__

/**
 *  These macros are the C counterpart of the Obj-C ones in XLFacilityMacros.h.
 *
 *  See XLFacilityMacros.h for more information.
 */

#ifndef XLOG_TAG
#if DEBUG
#define XLOG_STRINGIFY(x) #x
#define XLOG_STRINGIFY_(x) XLOG_STRINGIFY(x)
#define XLOG_LINE XLOG_STRINGIFY_(__LINE__)
#define XLOG_TAG (__FILE__ ":" XLOG_LINE)
#else
#define XLOG_TAG nil
#endif
#endif

#if DEBUG
#define XLOG_DEBUG(...) do { if (XLMinLogLevel <= 0) XLLogCMessage(XLOG_TAG, 0, __VA_ARGS__); } while (0)
#else
#define XLOG_DEBUG(...)
#endif
#define XLOG_VERBOSE(...) do { if (XLMinLogLevel <= 1) XLLogCMessage(XLOG_TAG, 1, __VA_ARGS__); } while (0)
#define XLOG_INFO(...) do { if (XLMinLogLevel <= 2) XLLogCMessage(XLOG_TAG, 2, __VA_ARGS__); } while (0)
#define XLOG_WARNING(...) do { if (XLMinLogLevel <= 3) XLLogCMessage(XLOG_TAG, 3, __VA_ARGS__); } while (0)
#define XLOG_ERROR(...) do { if (XLMinLogLevel <= 4) XLLogCMessage(XLOG_TAG, 4, __VA_ARGS__); } while (0)
#define XLOG_ABORT(...) do { if (XLMinLogLevel <= 6) XLLogCMessage(XLOG_TAG, 6, __VA_ARGS__); } while (0)

#define XLOG_CHECK(__CONDITION__) \
do { \
  if (!(__CONDITION__)) { \
    XLOG_ABORT("Condition failed: \"%s\"", #__CONDITION__); \
  } \
} while (0)

#define XLOG_UNREACHABLE() \
do { \
  XLOG_ABORT("Unreachable code executed in '%s': %s:%i", __FUNCTION__, __FILE__, (int)__LINE__); \
} while (0)

#if DEBUG
#define XLOG_DEBUG_CHECK(__CONDITION__) XLOG_CHECK(__CONDITION__)
#define XLOG_DEBUG_UNREACHABLE() XLOG_UNREACHABLE()
#else
#define XLOG_DEBUG_CHECK(__CONDITION__)
#define XLOG_DEBUG_UNREACHABLE()
#endif

extern int XLMinLogLevel;
extern void XLLogCMessage(const char* tag, int level, const char* format, ...);

#endif // __XLFacilityCMacros__
