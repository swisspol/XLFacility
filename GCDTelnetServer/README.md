Overview
========

[![Build Status](https://travis-ci.org/swisspol/GCDTelnetServer.svg?branch=master)](https://travis-ci.org/swisspol/GCDTelnetServer)
[![Version](http://cocoapod-badges.herokuapp.com/v/GCDTelnetServer/badge.png)](http://cocoadocs.org/docsets/GCDTelnetServer)
[![Platform](http://cocoapod-badges.herokuapp.com/p/GCDTelnetServer/badge.png)](https://github.com/swisspol/GCDTelnetServer)
[![License](http://img.shields.io/cocoapods/l/GCDTelnetServer.svg)](LICENSE)

GCDTelnetServer is a drop-in embedded Telnet server for iOS and OS X apps.

Features:
* Elegant and simple API
* Fully asynchronous (doesn't need the main thread)
* Entirely built using [Grand Central Dispatch](http://en.wikipedia.org/wiki/Grand_Central_Dispatch) for best performance and concurrency
* Support for ANSI colors with an extension on `NSMutableString`
* Can parse line inputs as command and arguments command line interface
* Full support for IPv4 and IPv6
* Automatically handles background and suspended modes on iOS
* No dependencies on third-party source code
* Available under a friendly [New BSD License](LICENSE)

Requirements:
* OS X 10.7 or later (x86_64)
* iOS 5.0 or later (armv7, armv7s or arm64)
* ARC memory management only

Getting Started
===============

Download or check out the [latest release](https://github.com/swisspol/GCDTelnetServer/releases) of GCDTelnetServer then add both the "GCDTelnetServer" and "GCDNetworking/GCDNetworking" subfolders to your Xcode project.

Alternatively, you can install GCDTelnetServer using [CocoaPods](http://cocoapods.org/) by simply adding this line to your Xcode project's Podfile:
```
pod "GCDTelnetServer", "~> 1.0"
```

Using GCDTelnetServer in Your App
=================================

```objectivec
#import "GCDTelnetServer.h"

GCDTCPServer* server = [[GCDTelnetServer alloc] initWithPort:2323 startHandler:^NSString*(GCDTelnetConnection* connection) {
  
  // Return welcome message
  return [NSString stringWithFormat:@"You are connected using \"%@\"\n", connection.terminalType];
  
} lineHandler:^NSString*(GCDTelnetConnection* connection, NSString* line) {
  
  // Simply echo back the received line but you could do anything here
  return [line stringByAppendingString:@"\n"];
  
}];
[server start];
```

Then launch Terminal on your Mac, and simply enter `telnet YOUR_COMPUTER_OR_IPHONE_IP_ADDRESS 2323` and voilà, you can communicate "live" with your app.

**GCDTelnetServer has an extensive customization API, be sure to peruse [GCDTelnetConnection.h](GCDTelnetServer/GCDTelnetConnection.h).**

Executing Remote Commands
=========================

The most interesting use of GCDTelnetServer is to execute commands inside your app while it's running on the device e.g. to query internal state, trigger actions while the app is in the background, etc...

This sample code demonstrate how to implement a welcome message with more information (and ANSI colors!), and also support 3 commands (`quit`, `crash` and `setwcolor` which takes some arguments):
```objectivec
#import "GCDTelnetServer.h"
#import "NSMutableString+ANSI.h"

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
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
  [server start];  // TODO: Handle error
  
  return YES;
}

```

And here's an example session:
```sh
$ telnet localhost 2323
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
You are connected from 127.0.0.1 using "XTERM-256COLOR"
Current device is iPad Simulator running iPhone OS 8.1
> test
UNKNOWN COMMAND = test ()
> setwcolor
Usage: setwcolor red green blue
> setwcolor 1 0 0
OK
> quitConnection closed by foreign host.
```
