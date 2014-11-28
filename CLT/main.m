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

#import "XLFacilityMacros.h"
#import "XLStandardLogger.h"
#import "XLTelnetServerLogger.h"
#import "XLHTTPServerLogger.h"
#import "XLTCPClientLogger.h"

extern void c_test();

static int _counter = 0;

static void _RunLoopTimerCallBack(CFRunLoopTimerRef timer, void* info) {
  if (_counter % 2 == 0) {
    XLOG_VERBOSE(@"Tick");
  } else {
    XLOG_ERROR(@"Tock");
  }
  _counter += 1;
}

int main(int argc, const char* argv[]) {
  @autoreleasepool {
    [[XLStandardLogger sharedErrorLogger] setFormat:@"%t (%g) %l > %m%c"];
    [XLSharedFacility addLogger:[[XLTelnetServerLogger alloc] init]];
    [XLSharedFacility addLogger:[[XLHTTPServerLogger alloc] init]];
    
#if 0
    [XLSharedFacility addLogger:[[XLTCPClientLogger alloc] initWithHost:@"localhost" port:8888 preserveHistory:YES]];
#endif
    
    c_test();
    
    CFRunLoopTimerRef timer = CFRunLoopTimerCreate(kCFAllocatorDefault, 0.0, 1.0, 0, 0, _RunLoopTimerCallBack, NULL);
    CFRunLoopAddTimer(CFRunLoopGetMain(), timer, kCFRunLoopCommonModes);
    
    CFRunLoopRun();
  }
  return 0;
}
