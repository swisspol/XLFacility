#import "XLFacilityMacros.h"
#import "XLFileLogger.h"
#import "XLStandardLogger.h"
#import "XLDatabaseLogger.h"
#import "XLCallbackLogger.h"
#import "XLASLLogger.h"
#import "XLTelnetServerLogger.h"
#import "XLHTTPServerLogger.h"

int main(int argc, const char* argv[]) {
  @autoreleasepool {
    [XLFacility enableLoggingOfUncaughtExceptions];
    [XLFacility enableLoggingOfInitializedExceptions];
    [XLFacility enableCapturingOfStdErr];
    
    [[XLFacility sharedFacility] addLogger:[XLStandardLogger sharedStdErrLogger]];
    [[XLFacility sharedFacility] addLogger:[[XLFileLogger alloc] initWithFilePath:@"temp.log" append:NO]];
    XLDatabaseLogger* databaseLogger = [[XLDatabaseLogger alloc] initWithDatabasePath:@"temp.db" appVersion:1];
    databaseLogger.recordFilter = ^BOOL(XLRecord* record) {
      return record.logLevel >= kXLLogLevel_Error;
    };
    [[XLFacility sharedFacility] addLogger:databaseLogger];
    [[XLFacility sharedFacility] addLogger:[XLCallbackLogger loggerWithCallback:^(XLCallbackLogger* logger, XLRecord* record) {
      fprintf(stdout, "-> %s\n", XLConvertNSStringToUTF8CString(record.message));
      fflush(stdout);
    }]];
    [[XLFacility sharedFacility] addLogger:[XLASLLogger sharedLogger]];
    [[XLFacility sharedFacility] addLogger:[[XLTelnetServerLogger alloc] init]];
    [[XLFacility sharedFacility] addLogger:[[XLHTTPServerLogger alloc] init]];
    
    fprintf(stdout, "Hello World!\nAll is fine!\n");
    NSLog(@"We have started!");
    
//    XLOG_ABORT(@"HEY");
    
    XLOG_DEBUG(@"Hello %@", @"World!");
    XLOG_VERBOSE(@"Hello %@", @"World!");
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
    XLOG_INFO(@"Hello %@", @"World!");
    XLOG_WARNING(@"Hello %@", @"World!");
    XLOG_ERROR(@"Hello %@", @"World!");
    
    @try {
      [[NSArray array] objectAtIndex:1];
    }
    @catch (NSException* exception) {
#pragma unused(exception)
//      LOG_EXCEPTION(exception);
//      [exception raise];
    }
    
    [databaseLogger purgeRecordsBeforeAbsoluteTime:(CFAbsoluteTimeGetCurrent() - 10.0)];
    [databaseLogger enumerateRecordsAfterAbsoluteTime:0.0 backward:YES maxRecords:2 usingBlock:^(int appVersion, XLRecord* record, BOOL* stop) {
      NSLog(@"%i = %@", (int)appVersion, record.message);
    }];
    
    for (int i = 1; i <= 10; ++i) {
      [XLSharedFacility logMessageWithLevel:(kXLLogLevel_Verbose + i % 4) format:@"PING %i", (int)i];
      CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, false);
    }
    
    [[XLFacility sharedFacility] removeAllLoggers];
  }
  return 0;
}
