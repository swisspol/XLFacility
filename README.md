Overview
========

[![Build Status](https://travis-ci.org/swisspol/XLFacility.svg?branch=master)](https://travis-ci.org/swisspol/XLFacility)

XLFacility is an elegant and extensive logging facility for OS X & iOS.

Requirements:
* OS X 10.7 or later (x86_64)
* iOS 5.0 or later (armv7, armv7s or arm64)
* ARC memory management only

Getting Started
===============

Download or check out the [latest release](https://github.com/swisspol/XLFacility/releases) of XLFacility then add the entire "XLFacility" subfolder to your Xcode project.

Alternatively, you can install XLFacility using [CocoaPods](http://cocoapods.org/) by simply adding this line to your Xcode project's Podfile:
```
pod "XLFacility", "~> 1.0"
```

Drop-in NSLog Replacement
=========================

**Step 1:** In the precompiled header file for your Xcode project, insert the following:
```objectivec
#import "XLFacilityMacros.h"
#define NSLog(...) XLOG_INFO(__VA_ARGS__)
```

**Step 2:** Then in the `main.m` file of your app, add `#import "XLStandardIOLogger.h"` to the top of the file, and insert this line inside `main()` before UIApplication or NSApplication starts:
```objectivec
[[XLFacility sharedFacility] addLogger:[XLStandardIOLogger sharedStdErrLogger]];
```

**You're done:** From this point on, any call to `NSLog()` in your app source code will be replaced by one to XLFacility. Note that this will **not** affect any calls to `NSLog()` done by Apple frameworks or third-party libraries in your app (see below for a solution to this).

Test-Driving Your (Modified) App
================================

So far nothing has really changed on the surface except that when running your app from Xcode, `NSLog()` output in the console now looks like this:
```
00:00:00.248 [INFO     ]> Hello World!
```
Instead of the previous:
```
2014-10-12 02:41:29.842 TestApp[37006:2455985] Hello World!
```

That's the first big difference between XLFacility and `NSLog()`: you can customize the output to fit your taste. Try adding this line inside `main()`:
```objectivec
[[XLStandardIOLogger sharedStdErrLogger] setFormat:XLLoggerFormatString_NSLog];
```
Run your app again and notice how messages in the console look exactly like when using `NSLog()`.

Let's use a custom compact format instead:
```objectivec
[[XLStandardIOLogger sharedStdErrLogger] setFormat:@"[%l | %q] %m\n"];
```
Run your app again and check for messages in the console which should now look like this:
```
[INFO | com.apple.main-thread] Hello World!
```

Here's the full list of format specifiers supported by XLFacility:
```
%l: level name
%L: level name padded to constant width with trailing spaces
%m: message
%M: message
%u: user ID
%p: process ID
%P: process name
%r: thread ID
%q: queue label (or "(null)" if not available)
%t: relative timestamp since process started in "HH:mm:ss.SSS" format
%d: absolute date-time formatted using the "datetimeFormatter" property
%e: errno as an integer
%E: errno as a string
%c: Callstack (or nothing if not available)

\n: newline character
\r: return character
\t: tab character
\%: percent character
\\: backslash character
```

Fun With Loggers
================

Still in the `main.m` file, add `#import "XLTelnetServerLogger.h"` to the top, and insert this other line above or below the one you inserted at the previous step:
```objectivec
[[XLFacility sharedFacility] addLogger:[[XLTelnetServerLogger alloc] init]];
```
What we are doing here is adding a secondary "logger" to XLFacility so that log messages are distributed to two places simultaneously.

Run your app locally on your computer (use the iOS Simulator for an iOS app) then enter his command in Terminal app:
```sh
telnet localhost 2323
```
You should see this output on screen:
```sh
$ telnet localhost 2323
Trying ::1...
telnet: connect to address ::1: Connection refused
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
You are connected to TestApp[37006] (in color!)

```

Any call to `NSLog()` in your app's source code is now being sent live to your Terminal window. And when you connect to your app, as a convenience to make sure you haven't missed anything,  `XLTelnetServerLogger` will immediately replay all messages logged since the app was launched (this behavior can be changed).

What's really interesting and useful however is connecting to your app while it's running on another Mac or on a real iPhone / iPad. As long as your home / office / WiFi network doesn't block communication on port `2323` (the default port used by `XLTelnetServerLogger`), you should be able to remotely connect by simply entering `telnet {YOUR_DEVICE_IP_ADDRESS} 2323` in Terminal on your computer. Note that connecting to your iOS app will not work while if it has been suspended by iOS while in background.

Of course, like you've already done above with `XLStandardIOLogger`, you can customize the format used by `XLTelnetServerLogger`, for instance like this:
```objectivec
XLLogger* logger = [[XLFacility sharedFacility] addLogger:[[XLTelnetServerLogger alloc] init]];
logger.format = @"[%l | %q] %m\n";
```

You can even add multiples instances of `XLTelnetServerLogger` to XLFacility, each listening on a unique port and configured differently.

**IMPORTANT:** It's not recommended that you ship your app on the App Store with `XLTelnetServerLogger` active by default as this could be a security and / or privacy issue for your users. Since you can add and remove loggers at any point during the lifecyle of your app, you can instead expose a user interface setting that will dynamically add or remove `XLTelnetServerLogger` from XLFacility.

Muting XLFacility
=================

Log levels
env var

Configuring Loggers
===================

format, min / max levels, custom filter

Capturing Stderr or Stdout
==========================

```objectivec
[[XLFacility sharedFacility] enableCapturingOfStdErr];
```

no infinite loop

Logging Messages With XLFacility
================================

TBD (macros / calls)

Exceptions
==========

TBD

Notes
=====
* thread-safety / reentrancy
* write buffering

