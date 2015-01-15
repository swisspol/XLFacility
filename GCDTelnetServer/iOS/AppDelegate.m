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
#import "GCDTelnetServer.h"
#import "NSMutableString+ANSI.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
  _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  _window.backgroundColor = [UIColor whiteColor];
  _window.rootViewController = [[UIViewController alloc] init];
  _window.rootViewController.view = [[UIView alloc] init];
  [_window makeKeyAndVisible];
  
  GCDTCPServer* server = [[GCDTelnetServer alloc] initWithPort:2323 startHandler:^NSString*(GCDTelnetConnection* connection) {
    
    UIDevice* device = [UIDevice currentDevice];
    NSMutableString* welcome = [[NSMutableString alloc] init];
    [welcome appendANSIStringWithColor:kANSIColor_Green bold:NO format:@"You are connected from %@ using \"%@\"\n", connection.remoteIPAddress, connection.terminalType];
    [welcome appendANSIStringWithColor:kANSIColor_Green bold:NO format:@"Current device is %@ running %@ %@\n", device.model, device.systemName, device.systemVersion];
    return welcome;
    
  } commandHandler:^NSString*(GCDTelnetConnection* connection, NSString* command, NSArray* arguments) {
    
    if ([command isEqualToString:@"quit"]) {
      [connection close];
      return nil;
    } else if ([command isEqualToString:@"crash"]) {
      abort();
    } else if ([command isEqualToString:@"setwcolor"]) {
      if (arguments.count == 3) {
        dispatch_async(dispatch_get_main_queue(), ^{
          _window.backgroundColor = [UIColor colorWithRed:[arguments[0] doubleValue] green:[arguments[1] doubleValue] blue:[arguments[2] doubleValue] alpha:1.0];
        });
        return @"OK\n";
      }
      return @"Usage: setwcolor red green blue\n";
    }
    
    NSMutableString* error = [[NSMutableString alloc] init];
    [error appendANSIStringWithColor:kANSIColor_Red bold:YES format:@"UNKNOWN COMMAND = %@ (%@)\n", command, [arguments componentsJoinedByString:@", "]];
    return error;
    
  }];
  if (![server start]) {
    abort();
  }
  
  return YES;
}

@end
