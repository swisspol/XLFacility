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

#import "AppDelegate.h"
#import "XLFacilityMacros.h"
#import "XLUIKitOverlayLogger.h"
#import "XLTelnetServerLogger.h"

@implementation AppDelegate

- (void)_testLog:(id)sender {
  XLOG_INFO(@"%s", __FUNCTION__);
}

- (void)_testAbort:(id)sender {
  XLOG_ABORT(@"%s", __FUNCTION__);
}

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
  _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  _window.backgroundColor = [UIColor whiteColor];
  _window.rootViewController = [[UIViewController alloc] init];
  _window.rootViewController.view = [[UIView alloc] init];
  [_window makeKeyAndVisible];
  
  UIButton* button1 = [UIButton buttonWithType:UIButtonTypeSystem];
  [button1 setTitle:@"Test Log" forState:UIControlStateNormal];
  [button1 addTarget:self action:@selector(_testLog:) forControlEvents:UIControlEventTouchDown];
  button1.frame = CGRectMake(100, 100, 100, 50);
  [button1 sizeToFit];
  [_window.rootViewController.view addSubview:button1];
  
  UIButton* button2 = [UIButton buttonWithType:UIButtonTypeSystem];
  [button2 setTitle:@"Test Abort" forState:UIControlStateNormal];
  [button2 addTarget:self action:@selector(_testAbort:) forControlEvents:UIControlEventTouchDown];
  button2.frame = CGRectMake(300, 100, 100, 50);
  [button2 sizeToFit];
  [_window.rootViewController.view addSubview:button2];
  
  [XLSharedFacility addLogger:[[XLTelnetServerLogger alloc] init]];
  [XLSharedFacility addLogger:[XLUIKitOverlayLogger sharedLogger]];
  [[XLUIKitOverlayLogger sharedLogger] setOverlayOpacity:0.66];
  
  XLOG_INFO(@"%s", __FUNCTION__);
  
  return YES;
}

- (void)applicationDidBecomeActive:(UIApplication*)application {
  XLOG_INFO(@"%s", __FUNCTION__);
}

- (void)applicationWillResignActive:(UIApplication*)application {
  XLOG_INFO(@"%s", __FUNCTION__);
}

- (void)applicationDidEnterBackground:(UIApplication*)application {
  XLOG_WARNING(@"%s", __FUNCTION__);
}

- (void)applicationWillEnterForeground:(UIApplication*)application {
  XLOG_WARNING(@"%s", __FUNCTION__);
}

@end
