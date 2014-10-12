Overview
========

[![Build Status](https://travis-ci.org/swisspol/XLFacility.svg?branch=master)](https://travis-ci.org/swisspol/XLFacility)

XLFacility, which stands for *Extensive Logging Facility*, is an elegant and powerful logging facility for OS X & iOS. It was written from scratch with the following goals in mind:
* Making it trivial to log messages from anywhere the source code while maintaining app performance
* Providing several built-in loggers to save log messages to `stderr`, files, databases, remote connections like Telnet, UI overlays and more
* Customizable logging formats
* Modern and clean codebase fully taking advantage of the latest Obj-C runtime and Grand Central Dispatch
* Easy to understand architecture and ability to write write custom loggers in a few lines of code
* No dependencies on third-party source code
* Available under a friendly [New BSD License](LICENSE)

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

**There's not even a step 2:** From this point on, any call to `NSLog()` in your app source code will be replaced by one to XLFacility. Note that this will **not** affect any calls to `NSLog()` done by Apple frameworks or third-party libraries in your app (see below for a solution to this).

Test-Driving Your (Modified) App
================================

So far nothing has really changed on the surface except that when running your app from Xcode, messages logged with `NSLog()` now appear in the console like this:
```
00:00:00.248 [INFO     ]> Hello World!
```
Where previously they would look like that:
```
2014-10-12 02:41:29.842 TestApp[37006:2455985] Hello World!
```

That's the first big difference between XLFacility and `NSLog()`: you can customize the output to fit your taste. Try adding `#import "XLStandardLogger.h"` to the top of the `main.m` file of your app and then insert this line inside `main()` before `UIApplication` or `NSApplication` gets called:
```objectivec
[[XLStandardLogger sharedStdErrLogger] setFormat:XLLoggerFormatString_NSLog];
```
Run your app again and notice how messages in the console now look exactly like when using `NSLog()`.

Let's use a custom compact format instead:
```objectivec
[[XLStandardLogger sharedStdErrLogger] setFormat:@"[%l | %q] %m\n"];
```
Run your app again and messages in the Xcode console should now look like this:
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

Note that specifiers like the date-time, GCD queue label or `errno` value all reflect the state of the app at the time the message was sent to XLFacility, not when it is actually displayed in the Xcode console for instance.

Logging Messages With XLFacility
================================

Like pretty much all logging systems, XLFacility defines various logging levels, which are by order of importance: `DEBUG`, `VERBOSE`, `INFO`, `WARNING`, `ERROR`, `EXCEPTION` and `ABORT`. The idea is that when logging messages, you provide the appropriate importance level: for instance `VERBOSE` to trace and help debug what is happening in the code, versus `WARNING` and above to report actual issues. The logging system can then be configured to "drop" messages that are below a certain level, allowing the user to control the "signal-to-noise" ratio.

By default, when building your app in `Release` coniguration XLFacility ignores messages at the `DEBUG` and `VERBOSE` levels. When building in `Debug` configuration (requires the `DEBUG` preprocessor constant evaluating to non-zero), it keeps everything.

**IMPORTANT:** So far you've seen how to "override" `NSLog()` calls in your source code to redirect messages to FLFacility at the `INFO` level but this is not the best approach. Instead don't use `NSLog()` at all but call directly XLFacility functions to log messages.

You can log messages in XLFacility by calling the `-log...` methods on the shared `XLFacility` instance or by using the macros from `XLFacilityMacros.h`. The latter is highly recommended as macros produce the exact same logging results but are quite easier to the eye, faster to type, and most importantly they avoid evaluating their arguments unless necessary. (*)

The following macros are available to log messages at various levels:
* `XLOG_DEBUG(...)`: Becomes a no-op if building `Release` (i.e. if the `DEBUG` preprocessor constant evaluates to zero)
* `XLOG_VERBOSE(...)`
* `XLOG_INFO(...)`
* `XLOG_WARNING(...)`
* `XLOG_ERROR(...)`
* `XLOG_EXCEPTION(__EXCEPTION__)`: Takes an `NSException` and not a format string (the message is generated automatically from the exception)
* `XLOG_ABORT(...)`: Calls `abort()` to immediately terminate the app after logging the message

When calling the macros, except for `XLOG_EXCEPTION()`, use the standard format specifiers from Obj-C like in `NSLog()`, `+[NSString stringWithFormat:...]`, etc... For instance:
```objectivec
XLOG_WARNING(@"Unable to load URL \"%@\": %@", myURL, myError);
```

Other useful macros available to use in your source code:
* `XLOG_CHECK(__CONDITION__)`: Checks a condition and if false calls `XLOG_ABORT()` with an automatically generated message
* `XLOG_UNREACHABLE()`: Calls `XLOG_ABORT()` with an automatically generated message if the app reaches this point
* `XLOG_DEBUG_CHECK(__CONDITION__)`: Same as `XLOG_CHECK()` but becomes a no-op if building `Release` (i.e. if the `DEBUG` preprocessor constant evaluates to zero)
* `XLOG_DEBUG_UNREACHABLE()`: Same as `XLOG_UNREACHABLE()` but becomes a no-op if building `Release` (i.e. if the `DEBUG` preprocessor constant evaluates to zero)

Here are some example use cases:
```objectivec
- (void)processString:(NSString*)string {
  XLOG_CHECK(string);  // Passing a nil string is a serious programming error and we can't continue
  // Do something
}

- (void)checkString:(NSString*)string {
  if ([string hasPrefix:@"foo"]) {
    // Do something
  } else if ([string hasPrefix:@"bar"]) {
    // Do something
  } else {
    XLOG_DEBUG_UNREACHABLE();  // This should never happen
  }
}
```

(*) For instance, if the log level for XLFacility is set to `ERROR`, `XLOG_WARNING(@"Unexpected value: %@", value)` will almost be a no-op while `[[XLFacility sharedFacility] logWarning:@"Unexpected value: %@", value]` will still evaluate all the arguments (which can be quite expensive), compute the format string, and finally pass everything to the `XLFacility` shared instance where it will be ignored anyway.

Fun With Remote Logging
=======================

Going back to the `main.m` file of your app, add `#import "XLTelnetServerLogger.h"` to the top, and insert this line before `UIApplication` or `NSApplication` gets called:
```objectivec
[[XLFacility sharedFacility] addLogger:[[XLTelnetServerLogger alloc] init]];
```
What we are doing here is adding a secondary "logger" to XLFacility so that log messages are sent to two destinations simultaneously.

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

What's really interesting and useful however is connecting to your app while it's running on another Mac or on a real iPhone / iPad. As long as your home / office / WiFi network doesn't block communication on port `2323` (the default port used by `XLTelnetServerLogger`), you should be able to remotely connect by simply entering `telnet YOUR_DEVICE_IP_ADDRESS 2323` in Terminal on your computer. Note that connecting to your iOS app will not work while if it has been suspended by iOS while in background.

Of course, like you've already done above with `XLStandardLogger`, you can customize the format used by `XLTelnetServerLogger`, for instance like this:
```objectivec
XLLogger* logger = [[XLFacility sharedFacility] addLogger:[[XLTelnetServerLogger alloc] init]];
logger.format = @"[%l | %q] %m\n";
```

You can even add multiples instances of `XLTelnetServerLogger` to XLFacility, each listening on a unique port and configured differently.

**IMPORTANT:** It's not recommended that you ship your app on the App Store with `XLTelnetServerLogger` active by default as this could be a security and / or privacy issue for your users. Since you can add and remove loggers at any point during the lifecyle of your app, you can instead expose a user interface setting that will dynamically add or remove `XLTelnetServerLogger` from XLFacility.

Log Monitoring From Your Web Browser
====================================

Do the same modification as you've done above to add suport for `XLTelnetServerLogger` but use `XLHTTPServerLogger` instead. When your app is running go to `http://127.0.0.1:8080/` or `http://YOUR_DEVICE_IP_ADDRESS:8080/` in your web browser. You should be able to see all the XLFacility log messages from your app since it started. The web page will even automatically refresh when new log messages are available.

Onscreen Logging Overlay (iOS only)
===================================

For iOS apps, you can easily have an overlay logging window that appears whenever log messagesy are sent to XLFacility. Simply take advantage of `XLUIKitOverlayLogger` like this:
```objectivec
#import "XLUIKitOverlayLogger.h"

@implementation MyAppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
  [[XLFacility sharedFacility] addLogger:[XLUIKitOverlayLogger sharedLogger]];
  
  // Rest of your app initialization code goes here
}

@end
```

Archiving Log Messages
======================

TBD

Muting XLFacility
=================

Log levels
env var

Configuring Loggers
===================

format, min / max levels, custom filter

Capturing Exceptions
====================

TBD

Capturing Stderr or Stdout
==========================

```objectivec
[[XLFacility sharedFacility] enableCapturingOfStdErr];
```

no infinite loop

Writing Custom Loggers
======================

* Blocks
* Subclasses

Examples
========

* Logging to files
* Log to server e.g. Mixpanel

Architecture
============
* thread-safety / reentrancy
* write buffering
