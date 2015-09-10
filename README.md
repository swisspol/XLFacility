Overview
========

[![Build Status](https://travis-ci.org/swisspol/XLFacility.svg?branch=master)](https://travis-ci.org/swisspol/XLFacility)
[![Version](http://cocoapod-badges.herokuapp.com/v/XLFacility/badge.png)](http://cocoadocs.org/docsets/XLFacility)
[![Platform](http://cocoapod-badges.herokuapp.com/p/XLFacility/badge.png)](https://github.com/swisspol/XLFacility)
[![License](http://img.shields.io/cocoapods/l/XLFacility.svg)](LICENSE)

XLFacility, which stands for *Extensive Logging Facility*, is an elegant and powerful logging facility for OS X & iOS. It was written from scratch with the following goals in mind:
* Drop-in replacement of `NSLog()` along with trivial to use macros to log messages anywhere in your app without impacting performance
* Support a wide variety of logging destinations aka "loggers"
* Customizable logging formats
* Modern, clean and compact codebase fully taking advantage of the latest Obj-C runtime and Grand Central Dispatch
* Easy to understand architecture with the ability to write custom loggers in a few lines of code
* No dependencies on third-party source code
* Available under a friendly [New BSD License](LICENSE)

Built-in loggers:
* Standard output and standard error
* [Apple System Logger](https://developer.apple.com/library/mac/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/LoggingErrorsAndWarnings.html)
* Local file
* Local [SQLite](http://www.sqlite.org/) database
* Telnet server which can be accessed from a terminal on a different computer to monitor log messages as they arrive
* HTTP server which can be accessed from a web browser on a different computer to browse the past log messages and see live updates
* Raw TCP connection which can send log messages to a remote server as they happen
* User interface logging window overlay for OS X & iOS apps

Requirements:
* OS X 10.7 or later (x86_64)
* iOS 5.0 or later (armv7, armv7s or arm64)
* ARC memory management only

Getting Started
===============

Download or check out the [latest release](https://github.com/swisspol/XLFacility/releases) of XLFacility then add the "XLFacility", "GCDTelnetServer/GCDTelnetServer" and "GCDTelnetServer/GCDNetworking/GCDNetworking" subfolders to your Xcode project.

Alternatively, you can install XLFacility using [CocoaPods](http://cocoapods.org/) by simply adding this line to your Xcode project's Podfile:
```
pod "XLFacility", "~> 1.0"
```

This provides all loggers including the server ones but if you want just the "core" of XLFacility and the basic loggers, use instead:
```
pod "XLFacility/Core", "~> 1.0"
```

Drop-in NSLog Replacement
=========================

In the precompiled header file for your Xcode project, insert the following:
```objectivec
#ifdef __OBJC__
#import "XLFacilityMacros.h"
#define NSLog(...) XLOG_INFO(__VA_ARGS__)
#endif
```

From this point on, any calls to `NSLog()` in your app source code to log a message will be replaced by ones to XLFacility. Note that this will **not** affect calls to `NSLog()` done by Apple frameworks or third-party libraries in your app (see "Capturing Stderr and Stdout" further in this document for a potential solution).

Test-Driving Your (Modified) App
================================

So far nothing has really changed on the surface except that when running your app from Xcode, messages logged with `NSLog()` now appear in the console like this:
```
00:00:00.248 [INFO     ]> Hello World!
```
While previously they would look like that:
```
2014-10-12 02:41:29.842 TestApp[37006:2455985] Hello World!
```

That's the first big difference between XLFacility and `NSLog()`: you can customize the output to fit your taste. Try adding `#import "XLStandardLogger.h"` to the top of the `main.m` file of your app and then inserting this line inside `main()` before `UIApplication` or `NSApplication` gets called:
```objectivec
[[XLStandardLogger sharedErrorLogger] setFormat:XLLoggerFormatString_NSLog];
```
Run your app again and notice how messages in the console now look exactly like when using `NSLog()`.

Let's use a custom compact format instead:
```objectivec
[[XLStandardLogger sharedErrorLogger] setFormat:@"[%l | %q] %m"];
```
Run your app again and messages in the Xcode console should now look like this:
```
[INFO | com.apple.main-thread] Hello World!
```

*See [XLLogger.h](XLFacility/Core/XLLogger.h) for the full list of format specifiers supported by XLFacility.*

Logging Messages With XLFacility
================================

Like pretty much all logging systems, XLFacility defines various logging levels, which are by order of importance: `DEBUG`, `VERBOSE`, `INFO`, `WARNING`, `ERROR`, `EXCEPTION` and `ABORT`. The idea is that when logging a message, you also provide the corresponding importance level: for instance `VERBOSE` to trace and help debug what is happening in the code, versus `WARNING` and above to report actual issues. The logging system can then be configured to "drop" messages that are below a certain level, allowing the user to control the "signal-to-noise" ratio.

By default, when building your app in "Release" configuration, XLFacility ignores messages at the `DEBUG` and `VERBOSE` levels. When building in "Debug" configuration (requires the `DEBUG` preprocessor constant evaluating to non-zero), it keeps everything.

**IMPORTANT:** So far you've seen how to "override" `NSLog()` calls in your source code to redirect messages to XLFacility at the `INFO` level but this is not the best approach. Instead don't use `NSLog()` at all but call directly XLFacility functions to log messages.

You can log messages in XLFacility by calling the logging methods on the shared `XLFacility` instance or by using the macros from [XLFacilityMacros.h](XLFacility/Core/XLFacilityMacros.h). The latter is highly recommended as macros produce the exact same logging results but are quite easier to the eye, faster to type, and most importantly they avoid evaluating their arguments unless necessary.

The following macros are available to log messages at various levels:
* `XLOG_DEBUG(...)`: Becomes a no-op if building "Release" (i.e. if the `DEBUG` preprocessor constant evaluates to zero)
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
* `XLOG_DEBUG_CHECK(__CONDITION__)`: Same as `XLOG_CHECK()` but becomes a no-op if building in "Release" configuration (i.e. if the `DEBUG` preprocessor constant evaluates to zero)
* `XLOG_DEBUG_UNREACHABLE()`: Same as `XLOG_UNREACHABLE()` but becomes a no-op if building in "Release" configuration (i.e. if the `DEBUG` preprocessor constant evaluates to zero)

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

*Messages logged with XLFacility can be associated with an optional tag which is an arbitrary string. This is a powerful feature that lets you for instance capture as part of the log message the source file name and line number. See [XLFacilityMacros.h](XLFacility/Core/XLFacilityMacros.h) for more information.*

Fun With Remote Logging
=======================

Going back to the `main.m` file of your app, add `#import "XLTelnetServerLogger.h"` to the top, and insert this line before `UIApplication` or `NSApplication` gets called:
```objectivec
[XLSharedFacility addLogger:[[XLTelnetServerLogger alloc] init]];
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

What's really interesting and useful is connecting to your app while it's running on another Mac or on a real iPhone / iPad. As long as your home / office / WiFi network doesn't block communication on port `2323` (the default port used by `XLTelnetServerLogger`), you should be able to remotely connect by simply entering `telnet YOUR_DEVICE_IP_ADDRESS 2323` in Terminal on your computer.

Of course, like you've already done above with `XLStandardLogger`, you can customize the format used by `XLTelnetServerLogger`, for instance like this:
```objectivec
XLLogger* logger = [[XLTelnetServerLogger alloc] init];
logger.format = @"[%l | %q] %m";
[XLSharedFacility addLogger:logger];
```

You can even add multiples instances of `XLTelnetServerLogger` to XLFacility, each listening on a unique port and configured differently.

**IMPORTANT:** It's not recommended that you ship your app on the App Store with `XLTelnetServerLogger` active by default as this could be a security and / or privacy issue for your users. Since you can add and remove loggers at any point during the lifecyle of your app, you can instead expose a user interface setting that will dynamically add or remove `XLTelnetServerLogger` from XLFacility.

Log Monitoring From Your Web Browser
====================================

Do the same modification as you've done above to add suport for `XLTelnetServerLogger` but use `XLHTTPServerLogger` instead. When your app is running go to `http://127.0.0.1:8080/` or `http://YOUR_DEVICE_IP_ADDRESS:8080/` in your web browser. You should be able to see all the XLFacility log messages from your app since it started. The web page will even automatically refresh when new log messages are available.

**IMPORTANT:** For the same reasons than for `XLTelnetServerLogger`, it's also not recommended that you ship your app on the App Store with `XLHTTPServerLogger` active by default.

Onscreen Logging Overlay
========================

On OS X & iOS apps you can easily have an overlay logging window that appears whenever log messages are sent to XLFacility. Simply take advantage of `XLUIKitOverlayLogger` or `XLAppKitOverlayLogger` like this:

**iOS version**
```objectivec
#import "XLUIKitOverlayLogger.h"

@implementation MyAppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
  [XLSharedFacility addLogger:[XLUIKitOverlayLogger sharedLogger]];
  
  // Rest of your app initialization code goes here
}

@end
```

**OS X version**
```objectivec
#import "XLAppKitOverlayLogger.h"

@implementation MyAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
  [XLSharedFacility addLogger:[XLAppKitOverlayLogger sharedLogger]];
  
  // Rest of your app initialization code goes here
}

@end
```

Archiving Log Messages
======================

There are a couple ways to save persistently across app relaunches the log messages sent to XLFacility:

The simplest solution is to use `XLFileLogger` to save log messages to a plain text file like this:
```objectivec
XLFileLogger* fileLogger = [[XLFileLogger alloc] initWithFilePath:@"my-file.log" append:YES];
fileLogger.minLogLevel = kXLLogLevel_Error;
fileLogger.format = @"%d\t%m";
[XLSharedFacility addLogger:fileLogger];
```

The more powerful solution is to use `XLDatabaseLogger` which uses a [SQLite](http://www.sqlite.org/) database under the hood:
```objectivec
XLDatabaseLogger* databaseLogger = [[XLDatabaseLogger alloc] initWithDatabasePath:@"my-database.db" appVersion:0];
[XLSharedFacility addLogger:databaseLogger];
```

Note that `XLDatabaseLogger` serializes the log messages to the database as-is and does not format them i.e. its `format` property has no effect.

You can easily "replay" later the saved log messages, for instance to display them in a log window in your application interface or to send them to a server:
```objectivec
[databaseLogger enumerateRecordsAfterAbsoluteTime:0.0
                                         backward:NO
                                       maxRecords:0
                                       usingBlock:^(int appVersion, XLLogRecord* record, BOOL* stop) {
  // Do something with each log record
  printf("%s\n", [record.message UTF8String]);
}];
```

Filtering XLFacility Log Messages
=================================

Use the `minLogLevel` property on the `XLFacility` shared instance to have XLFacility ignore all log messages below a certain level.

You can also control the minimum and maximum log level on each logger using their `minLogLevel` and `maxLogLevel` properties. You can even set a fully custom log record filter on a logger like this:
```objectivec
myLogger.logRecordFilter = ^BOOL(XLLogger* logger, XLLogRecord* record) {
  return [record.tag hasPrefix:@"com.my-app."];
};
```

Logging Exceptions
==================

Call `[XLSharedFacility setLogsUncaughtExceptions:YES]` early enough in your app (typically from `main()` before `UIApplication` or `NSApplication` gets called) to have XLFacility install an uncaught exception handler to automatically call `XLOG_EXCEPTION()` passing the exception before the app terminates.

If you want instead to log *all* exceptions, as they are created and wether or not they are caught, use `[XLSharedFacility setLogsInitializedExceptions:YES]` instead. Note that this will also log exceptions that are not thrown either.

In both cases, XLFacility will capture the current callstack as part of the log message.

Capturing Stderr and Stdout
===========================

If you use XLFacility functions exclusively in your app to log messages, then everything you log from your source code will go to XLFacility. If you use third-party source code, you might be able to patch or override its calls to `NSLog()`, `printf()` or equivalent as demonstrated at the beginning of this document. However this will not work for Apple or third-party libraries or frameworks.

XLFacility has a powerful feature that allows to capture the standard output and standard error from your app. Just call `[XLSharedFacility setCapturesStandardError:YES]` (respectively `[XLSharedFacility setCapturesStandardOutput:YES]`) and from this point on anything written to the standard output (respectively standard error) will be split on newlines boundaries and automatically become separate log messages in XLFacility with the `INFO` (respectively `ERROR`) level.

Writing Custom Loggers
======================

You can write a custom logger in a few lines of code by using `XLCallbackLogger` like this:
```objectivec
[XLSharedFacility addLogger:[XLCallbackLogger loggerWithCallback:^(XLCallbackLogger* logger, XLLogRecord* record) {
  // Do something with the log record
  printf("%s\n", [record.message UTF8String]);
}]];
```

To implement more complex loggers, you will need to subclass `XLLogger` and implement at least the `-logRecord:` method:
```objectivec
@interface MyLogger : XLLogger
@end

@implementation MyLogger

- (void)logRecord:(XLLogRecord*)record {
  // Do something with the log record
  NSString* formattedMessage = [self formatRecord:record];
  printf("%s", [formattedMessage UTF8String]);
}

@end
```
If you need to perform specific setup and cleanup operations when an instance of your logger is added or removed from XLFacility, also implement the `-open` and `-close` methods.

**IMPORTANT:** Due to the way XLFacility works, logger instances do not need to be reentrant, but they need to be able to run on arbitrary threads.
