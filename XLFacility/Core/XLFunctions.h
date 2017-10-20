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

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 *  Converts a XLLogLevel to an NSString.
 */
NSString* XLStringFromLogLevelName(XLLogLevel level);

/**
 *  Converts a NSString to an UTF-8 string.
 *
 *  Contrary to -[NSString dataUsingEncoding:] this function is guaranteed
 *  to return a non-nil result as long as the input string is not nil.
 */
NSData* _Nullable XLConvertNSStringToUTF8String(NSString* _Nullable string);

/**
 *  Converts a NSString to an UTF-8 NULL terminated C string.
 *
 *  Contrary to -[NSString UTF8String] this function is guaranteed to return
 *  a non-NULL result as long as the input string is not nil.
 */
const char* _Nullable XLConvertNSStringToUTF8CString(NSString* _Nullable string);

/**
 *  Check if a debugger is currently attached to the process.
 */
BOOL XLIsDebuggerAttached();

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
