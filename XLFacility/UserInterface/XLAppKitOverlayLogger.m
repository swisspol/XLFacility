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

#import "XLAppKitOverlayLogger.h"

#define kOverlayFadeDuration 0.3

@interface XLAppKitOverlayLogger () {
@private
  NSWindow* _logWindow;
  NSTextView* _textView;
  NSTimer* _overlayTimer;
}
@end

@implementation XLAppKitOverlayLogger

+ (XLAppKitOverlayLogger*)sharedLogger {
  static XLAppKitOverlayLogger* logger = nil;
  static dispatch_once_t onceToken = 0;
  dispatch_once(&onceToken, ^{
    logger = [[XLAppKitOverlayLogger alloc] init];
  });
  return logger;
}

- (id)init {
  if ((self = [super init])) {
    _overlayOpacity = 0.75;
    _overlayDuration = 5.0;
    _textFont = [NSFont fontWithName:@"Monaco" size:11];
  }
  return self;
}

- (BOOL)open {
  _logWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 800, 200)
                                           styleMask:(NSBorderlessWindowMask | NSResizableWindowMask)
                                             backing:NSBackingStoreBuffered defer:YES];
  _logWindow.level = NSFloatingWindowLevel;
  _logWindow.excludedFromWindowsMenu = YES;
  _logWindow.movableByWindowBackground = YES;
  _logWindow.backgroundColor = [NSColor blackColor];
  _logWindow.hasShadow  = NO;
  [_logWindow setFrameUsingName:NSStringFromClass([self class])];
  _logWindow.frameAutosaveName = NSStringFromClass([self class]);
  
  NSRect bounds = [(NSView*)_logWindow.contentView bounds];
  NSScrollView* scrollView = [[NSScrollView alloc] initWithFrame:NSInsetRect(bounds, 4, 4)];
  scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  scrollView.drawsBackground = NO;
  scrollView.hasHorizontalScroller = NO;
  scrollView.hasVerticalScroller = YES;
  [_logWindow.contentView addSubview:scrollView];
  
  _textView = [[NSTextView alloc] initWithFrame:scrollView.bounds];
  _textView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  _textView.richText = NO;
  _textView.editable = NO;
  _textView.selectable = NO;
  _textView.drawsBackground = NO;
  _textView.string = @"";
  [scrollView setDocumentView:_textView];
  
  _overlayTimer = [[NSTimer alloc] initWithFireDate:[NSDate distantFuture] interval:HUGE_VALF target:self selector:@selector(_overlayTimer:) userInfo:nil repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:_overlayTimer forMode:NSRunLoopCommonModes];
  
  if (_overlayDuration <= 0.0) {
    [_logWindow orderFront:nil];
  } else {
    _logWindow.alphaValue = 0.0;
  }
  
  return YES;
}

- (void)_overlayTimer:(NSTimer*)timer {
  [NSAnimationContext beginGrouping];
  [[NSAnimationContext currentContext] setDuration:kOverlayFadeDuration];
  [[NSAnimationContext currentContext] setCompletionHandler:^{
    [_logWindow orderOut:nil];
    _textView.string = @"";
  }];
  [_logWindow.animator setAlphaValue:0.0];
  [NSAnimationContext endGrouping];
}

- (void)logRecord:(XLLogRecord*)record {
  NSString* formattedMessage = [self formatRecord:record];
  dispatch_async(dispatch_get_main_queue(), ^{
    NSDictionary* attributes = @{NSFontAttributeName: _textFont, NSForegroundColorAttributeName:[NSColor whiteColor]};
    NSAttributedString* string = [[NSAttributedString alloc] initWithString:formattedMessage attributes:attributes];
    [_textView.textStorage appendAttributedString:string];
    [_textView scrollRangeToVisible:NSMakeRange(_textView.textStorage.length, 0)];
    
    [_logWindow orderFront:nil];
    if (_overlayDuration > 0.0) {
      if (_logWindow.alphaValue < _overlayOpacity) {
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:kOverlayFadeDuration];
        [_logWindow.animator setAlphaValue:_overlayOpacity];
        [NSAnimationContext endGrouping];
      }
      [_overlayTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:_overlayDuration]];
    } else {
      _logWindow.alphaValue = _overlayOpacity;
    }
  });
}

- (void)close {
  [_overlayTimer invalidate];
  _overlayTimer = nil;
  [_logWindow close];
  _logWindow = nil;
  _textView = nil;
}

@end
