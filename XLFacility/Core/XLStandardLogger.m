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

#if !__has_feature(objc_arc)
#error XLFacility requires ARC
#endif

#import "XLStandardLogger.h"

static int _duplicateStdOut = 0;
static int _duplicateStdErr = 0;

@implementation XLStandardLogger

// Keep around copies of the original stdout and stderr file descriptors from when process starts in cases they are replaced later on
+ (void)load {
  _duplicateStdOut = dup(STDOUT_FILENO);
  _duplicateStdErr = dup(STDERR_FILENO);
}

+ (XLStandardLogger*)sharedStdOutLogger {
  static XLStandardLogger* logger = nil;
  static dispatch_once_t onceToken = 0;
  dispatch_once(&onceToken, ^{
    logger = [[XLStandardLogger alloc] initWithFileDescriptor:_duplicateStdOut closeOnDealloc:NO];
  });
  return logger;
}

+ (XLStandardLogger*)sharedStdErrLogger {
  static XLStandardLogger* logger = nil;
  static dispatch_once_t onceToken = 0;
  dispatch_once(&onceToken, ^{
    logger = [[XLStandardLogger alloc] initWithFileDescriptor:_duplicateStdErr closeOnDealloc:NO];
  });
  return logger;
}

@end
