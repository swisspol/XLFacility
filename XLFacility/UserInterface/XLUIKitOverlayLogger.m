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

#import "XLUIKitOverlayLogger.h"

#define kOverlayWindowLevel 100.0
#define kOverlayMargin 25.0
#define kOverlayCornerRadius 6.0
#define kOverlayFadeDuration 0.3

@interface XLUIKitOverlayLogger () {
@private
  UIWindow* _overlayWindow;
  UITextView* _textView;
  NSTimer* _overlayTimer;
}
@end

@implementation XLUIKitOverlayLogger

+ (XLUIKitOverlayLogger*)sharedLogger {
  static XLUIKitOverlayLogger* logger = nil;
  static dispatch_once_t onceToken = 0;
  dispatch_once(&onceToken, ^{
    logger = [[XLUIKitOverlayLogger alloc] init];
  });
  return logger;
}

- (id)init {
  if ((self = [super init])) {
    _overlayOpacity = 0.75;
    _overlayDuration = 5.0;
    _textFont = [UIFont fontWithName:@"Courier" size:13.0];
  }
  return self;
}

- (void)setOverlayOpacity:(float)opacity {
  _overlayOpacity = opacity;
  
  _textView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:_overlayOpacity];
}

- (void)setTextFont:(UIFont*)font {
  _textFont = font;
  
  _textView.font = font;
}

- (BOOL)open {
  _overlayWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  _overlayWindow.screen = [UIScreen mainScreen];
  _overlayWindow.windowLevel = kOverlayWindowLevel;
  _overlayWindow.userInteractionEnabled = NO;
  _overlayWindow.rootViewController = [[UIViewController alloc] init];
  _overlayWindow.rootViewController.view = [[UIView alloc] initWithFrame:_overlayWindow.bounds];
  
  CGRect bounds = _overlayWindow.rootViewController.view.frame;
  bounds.origin.x += kOverlayMargin;
  bounds.origin.y += kOverlayMargin;
  bounds.size.width -= 2.0 * kOverlayMargin;
  bounds.size.height -= 2.0 * kOverlayMargin;
  _textView = [[UITextView alloc] initWithFrame:bounds];
  _textView.layer.cornerRadius = kOverlayCornerRadius;
  _textView.opaque = NO;
  _textView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:_overlayOpacity];
  _textView.textColor = [UIColor whiteColor];
  _textView.font = _textFont;
  _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [_overlayWindow.rootViewController.view addSubview:_textView];
  _textView.text = @"";
  
  _overlayTimer = [[NSTimer alloc] initWithFireDate:[NSDate distantFuture] interval:HUGE_VALF target:self selector:@selector(_overlayTimer:) userInfo:nil repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:_overlayTimer forMode:NSRunLoopCommonModes];
  
  if (_overlayDuration <= 0.0) {
    _overlayWindow.hidden = NO;
  } else {
    _textView.alpha = 0.0;
  }
  
  return YES;
}

- (void)_overlayTimer:(NSTimer*)timer {
  [UIView animateWithDuration:kOverlayFadeDuration animations:^{
    _textView.alpha = 0.0;
  } completion:^(BOOL finished) {
    _overlayWindow.hidden = YES;
    _textView.text = @"";
  }];
}

- (void)logRecord:(XLLogRecord*)record {
  NSString* formattedMessage = [self formatRecord:record];
  dispatch_async(dispatch_get_main_queue(), ^{
    _textView.text = [_textView.text stringByAppendingString:formattedMessage];
    if (_textView.text.length > 2) {
      [_textView scrollRangeToVisible:NSMakeRange(_textView.text.length - 2, 2)];
    }
    
    _overlayWindow.hidden = NO;
    if (_overlayDuration > 0.0) {
      if (_textView.alpha < 1.0) {
        [UIView animateWithDuration:kOverlayFadeDuration animations:^{
          _textView.alpha = 1.0;
        }];
      }
      [_overlayTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:_overlayDuration]];
    } else {
      _textView.alpha = 1.0;
    }
  });
}

- (void)close {
  [_overlayTimer invalidate];
  _overlayTimer = nil;
  [_textView removeFromSuperview];
  _textView = nil;
  _overlayWindow.hidden = YES;
  _overlayWindow = nil;
}

@end
