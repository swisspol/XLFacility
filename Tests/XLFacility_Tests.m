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

#pragma clang diagnostic ignored "-Wgnu-zero-variadic-macro-arguments"
#pragma clang diagnostic ignored "-Wgnu-statement-expression"
#pragma clang diagnostic ignored "-Wsign-compare"

#import <XCTest/XCTest.h>
#import <asl.h>

#import "XLFacilityMacros.h"
#import "XLCallbackLogger.h"
#import "XLFileLogger.h"
#import "XLDatabaseLogger.h"
#import "XLASLLogger.h"

#define kSleepDelay (100 * 1000)

@interface XLFacility_Tests : XCTestCase
@end

@implementation XLFacility_Tests {
  NSMutableArray* _capturedRecords;
}

- (void)setUp {
  [super setUp];
  
  [XLSharedFacility setCapturesStandardOutput:NO];
  [XLSharedFacility setLogsInitializedExceptions:NO];
  [XLSharedFacility setMinLogLevel:kXLLogLevel_Debug];
  [XLSharedFacility removeAllLoggers];
  
  _capturedRecords = [[NSMutableArray alloc] init];
  [XLSharedFacility addLogger:[XLCallbackLogger loggerWithCallback:^(XLCallbackLogger* logger, XLLogRecord* record) {
    [_capturedRecords addObject:record];
  }]];
}

- (void)testLoggingLevels {
  XLOG_DEBUG(@"Hello Debug World!");
  XLOG_VERBOSE(@"Hello Verbose World!");
  XLOG_INFO(@"Hello Info World!");
  XLOG_WARNING(@"Hello Warning World!");
  XLOG_ERROR(@"Hello Error World!");
  
  usleep(kSleepDelay);
  
  XCTAssertEqual(_capturedRecords.count, 5);
  XLLogRecord* record = _capturedRecords[2];
  XCTAssertEqual(record.logLevel, kXLLogLevel_Info);
  XCTAssertEqualObjects(record.message, @"Hello Info World!");
}

- (void)testCapturingInitializedException {
  [XLSharedFacility setLogsInitializedExceptions:YES];
  
  @try {
    [[NSArray array] objectAtIndex:1];
  }
  @catch (NSException* exception) {
#pragma unused(exception)
  }
  
  usleep(kSleepDelay);
  
  XCTAssertEqual(_capturedRecords.count, 1);
  XLLogRecord* record = _capturedRecords[0];
  XCTAssertEqual(record.logLevel, kXLLogLevel_Exception);
  XCTAssertTrue([record.message hasPrefix:@"NSRangeException *** "]);
  XCTAssertNotNil(record.callstack);
  
  [XLSharedFacility setLogsInitializedExceptions:NO];
  
  @try {
    [[NSArray array] objectAtIndex:1];
  }
  @catch (NSException* exception) {
#pragma unused(exception)
  }
  
  usleep(kSleepDelay);
  
  XCTAssertEqual(_capturedRecords.count, 1);
}

- (void)testCapturingStdOut {
  [XLSharedFacility setCapturesStandardOutput:YES];
  
  fprintf(stdout, "Hello stdout!\n");
  fprintf(stdout, "Bonjour stdout!\n");
  fflush(stdout);
  
  usleep(kSleepDelay);
  
  XCTAssertEqual(_capturedRecords.count, 2);
  XLLogRecord* record1 = _capturedRecords[0];
  XCTAssertEqual(record1.logLevel, kXLLogLevel_Info);
  XLLogRecord* record2 = _capturedRecords[1];
  XCTAssertEqual(record2.logLevel, kXLLogLevel_Info);
  
  [XLSharedFacility setCapturesStandardOutput:NO];
  
  fprintf(stdout, "Hello again!\n");
  fflush(stdout);
  
  usleep(kSleepDelay);
  
  XCTAssertEqual(_capturedRecords.count, 2);
}

- (void)testFileLogger {
  NSString* filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
  XLLogger* logger = [XLSharedFacility addLogger:[[XLFileLogger alloc] initWithFilePath:filePath append:NO]];
  logger.format = @"[%L] %m";
  
  for (int i = 0; i < 10; ++i) {
    [XLSharedFacility logMessageWithLevel:(i % 5) format:@"Hello World #%i!", i + 1];
  }
  
  usleep(kSleepDelay);
  
  NSString* contents = [[NSString alloc] initWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:NULL];
  XCTAssertEqualObjects(contents, @"\
[DEBUG    ] Hello World #1!\n\
[VERBOSE  ] Hello World #2!\n\
[INFO     ] Hello World #3!\n\
[WARNING  ] Hello World #4!\n\
[ERROR    ] Hello World #5!\n\
[DEBUG    ] Hello World #6!\n\
[VERBOSE  ] Hello World #7!\n\
[INFO     ] Hello World #8!\n\
[WARNING  ] Hello World #9!\n\
[ERROR    ] Hello World #10!\n\
");
  
  [XLSharedFacility removeLogger:logger];
  [[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];
}

- (void)testDatabaseLogger {
  NSString* databasePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
  XLDatabaseLogger* logger = (XLDatabaseLogger*)[XLSharedFacility addLogger:[[XLDatabaseLogger alloc] initWithDatabasePath:databasePath appVersion:0]];
  
  for (int i = 0; i < 10; ++i) {
    [XLSharedFacility logMessageWithLevel:(i % 5) format:@"Hello World #%i!", i + 1];
  }
  
  usleep(kSleepDelay);
  
  __block int index = 0;
  [logger enumerateRecordsAfterAbsoluteTime:0.0 backward:NO maxRecords:0 usingBlock:^(int appVersion, XLLogRecord* record, BOOL* stop) {
    XCTAssertEqual(record.logLevel, index % 5);
    NSString* message = [NSString stringWithFormat:@"Hello World #%i!", index + 1];
    XCTAssertEqualObjects(record.message, message);
    ++index;
  }];
  
  [XLSharedFacility removeLogger:logger];
  [[NSFileManager defaultManager] removeItemAtPath:databasePath error:NULL];
}

- (void)testASLLogger {
  XLLogger* logger = [XLSharedFacility addLogger:[XLASLLogger sharedLogger]];
  
  XLOG_INFO(@"Bonjour le monde!");
  XLOG_WARNING(@"Hello World!");
  
  usleep(kSleepDelay);
  
  fprintf(stderr, "Querying ASL - please wait...\n");
  
  aslmsg query = asl_new(ASL_TYPE_QUERY);
  const char* level = "7";  // ASL_LEVEL_DEBUG
  asl_set_query(query, ASL_KEY_LEVEL, level, ASL_QUERY_OP_LESS_EQUAL | ASL_QUERY_OP_NUMERIC);
  char pid[16];
  snprintf(pid, sizeof(pid), "%i", getpid());
  asl_set_query(query, ASL_KEY_PID, pid, ASL_QUERY_OP_EQUAL | ASL_QUERY_OP_NUMERIC);
  char time[32];
  snprintf(time, sizeof(time), "%.0f", CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970 - 10.0);
  asl_set_query(query, ASL_KEY_PID, pid, ASL_QUERY_OP_GREATER_EQUAL | ASL_QUERY_OP_NUMERIC);
  aslresponse response = asl_search(NULL, query);
  aslmsg message = NULL;
  int index = 0;
  while ((message = aslresponse_next(response))) {
    XCTAssertEqual(strcmp(asl_get(message, ASL_KEY_SENDER), "xctest"), 0);
    switch (index) {
      
      case 0:
        XCTAssertEqual(strcmp(asl_get(message, ASL_KEY_LEVEL), "5"), 0);  // ASL_LEVEL_NOTICE
        XCTAssertEqual(strcmp(asl_get(message, ASL_KEY_MSG), "Bonjour le monde!"), 0);
        break;
        
      case 1:
        XCTAssertEqual(strcmp(asl_get(message, ASL_KEY_LEVEL), "4"), 0);  // ASL_LEVEL_WARNING
        XCTAssertEqual(strcmp(asl_get(message, ASL_KEY_MSG), "Hello World!"), 0);
        break;
      
      default:
        XCTAssertTrue(0);
        break;
      
    }
    ++index;
  }
  asl_free(query);
  
  [XLSharedFacility removeLogger:logger];
}

@end
