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
#pragma clang diagnostic ignored "-Wsign-compare"

#define XLOG_TAG @"unit-tests"

#import <XCTest/XCTest.h>
#import <asl.h>

#import "XLFacilityMacros.h"
#import "XLStandardLogger.h"
#import "XLCallbackLogger.h"
#import "XLFileLogger.h"
#import "XLDatabaseLogger.h"
#import "XLASLLogger.h"
#import "XLTelnetServerLogger.h"
#import "XLHTTPServerLogger.h"
#import "XLTCPClientLogger.h"
#import "GCDTCPClient.h"

#define kLoggingDelay (100 * 1000)
#define kCommunicationSleepDelay (100 * 1000)

typedef void (^TCPServerConnectionBlock)(GCDTCPPeerConnection* connection);

@interface TestLogger : XLLogger
@end

@implementation TestLogger

- (BOOL)open {
  XLOG_ERROR(@"Recursive logging in %s", __FUNCTION__);
  return YES;
}

- (void)logRecord:(XLLogRecord*)record {
  XLOG_ERROR(@"Recursive logging in %s", __FUNCTION__);
}

- (void)close {
  XLOG_ERROR(@"Recursive logging in %s", __FUNCTION__);
}

@end

@interface TestServer : GCDTCPServer
@end

@implementation TestServer {
@private
  TCPServerConnectionBlock _block;
}

- (id)initWithPort:(NSUInteger)port connectionBlock:(TCPServerConnectionBlock)block {
  if ((self = [super initWithConnectionClass:[GCDTCPServerConnection class] port:port])) {
    _block = block;
  }
  return self;
}

- (void)willOpenConnection:(GCDTCPPeerConnection*)connection {
  [super willOpenConnection:connection];
  
  _block(connection);
}

@end

@interface XLFacility_Tests : XCTestCase
@end

@implementation XLFacility_Tests {
  NSMutableArray* _capturedRecords;
}

- (void)setUp {
  [super setUp];
  
  [XLSharedFacility setCapturesStandardOutput:NO];
  [XLSharedFacility setLogsInitializedExceptions:NO];
  [XLSharedFacility setMinLogLevel:kXLLogLevel_Verbose];
  
  [XLSharedFacility removeAllLoggers];
  [XLSharedFacility addLogger:[XLStandardLogger sharedErrorLogger]];
  
  _capturedRecords = [[NSMutableArray alloc] init];
  [XLSharedFacility addLogger:[XLCallbackLogger loggerWithCallback:^(XLCallbackLogger* logger, XLLogRecord* record) {
    [_capturedRecords addObject:record];
  }]];
}

- (void)testLoggingLevels {
  XLOG_VERBOSE(@"Hello Verbose World!");
  XLOG_INFO(@"Hello Info World!");
  XLOG_WARNING(@"Hello Warning World!");
  XLOG_ERROR(@"Hello Error World!");
  usleep(kLoggingDelay);
  
  XCTAssertEqual(_capturedRecords.count, 4);
  XLLogRecord* record = _capturedRecords[1];
  XCTAssertEqual(record.level, kXLLogLevel_Info);
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
  usleep(kLoggingDelay);
  
  XCTAssertEqual(_capturedRecords.count, 1);
  XLLogRecord* record = _capturedRecords[0];
  XCTAssertEqual(record.tag, XLFacilityTag_InitializedExceptions);
  XCTAssertEqual(record.level, kXLLogLevel_Exception);
  XCTAssertTrue([record.message hasPrefix:@"NSRangeException *** "]);
  XCTAssertNotNil(record.callstack);
  
  [XLSharedFacility setLogsInitializedExceptions:NO];
  
  @try {
    [[NSArray array] objectAtIndex:1];
  }
  @catch (NSException* exception) {
#pragma unused(exception)
  }
  usleep(kLoggingDelay);
  
  XCTAssertEqual(_capturedRecords.count, 1);
}

- (void)testCapturingStdOut {
  [XLSharedFacility setCapturesStandardOutput:YES];
  
  fprintf(stdout, "Hello stdout!\n");
  fprintf(stdout, "Bonjour stdout!\n");
  fflush(stdout);
  usleep(kLoggingDelay);
  
  XCTAssertEqual(_capturedRecords.count, 2);
  XLLogRecord* record1 = _capturedRecords[0];
  XCTAssertEqualObjects(record1.tag, XLFacilityTag_CapturedStdOut);
  XCTAssertEqual(record1.level, kXLLogLevel_Info);
  XCTAssertEqualObjects(record1.message, @"Hello stdout!");
  XLLogRecord* record2 = _capturedRecords[1];
  XCTAssertEqualObjects(record2.tag, XLFacilityTag_CapturedStdOut);
  XCTAssertEqual(record2.level, kXLLogLevel_Info);
  XCTAssertEqualObjects(record2.message, @"Bonjour stdout!");
  
  [XLSharedFacility setCapturesStandardOutput:NO];
  
  fprintf(stdout, "Hello again!\n");
  fflush(stdout);
  usleep(kLoggingDelay);
  
  XCTAssertEqual(_capturedRecords.count, 2);
}

- (void)testFileLogger {
  NSString* filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
  XLFileLogger* logger = [[XLFileLogger alloc] initWithFilePath:filePath append:NO];
  logger.format = @"[%L] %m";
  [XLSharedFacility addLogger:logger];
  
  for (int i = 0; i < 10; ++i) {
    [XLSharedFacility logMessageWithTag:XLOG_TAG level:(1 + i % 4) format:@"Hello World #%i!", i + 1];
  }
  usleep(kLoggingDelay);
  
  NSString* contents = [[NSString alloc] initWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:NULL];
  XCTAssertEqualObjects(contents, @"\
[VERBOSE  ] Hello World #1!\n\
[INFO     ] Hello World #2!\n\
[WARNING  ] Hello World #3!\n\
[ERROR    ] Hello World #4!\n\
[VERBOSE  ] Hello World #5!\n\
[INFO     ] Hello World #6!\n\
[WARNING  ] Hello World #7!\n\
[ERROR    ] Hello World #8!\n\
[VERBOSE  ] Hello World #9!\n\
[INFO     ] Hello World #10!\n\
");
  
  [XLSharedFacility removeLogger:logger];
  [[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];
}

- (void)testDatabaseLogger {
  NSString* databasePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
  XLDatabaseLogger* logger = [[XLDatabaseLogger alloc] initWithDatabasePath:databasePath appVersion:0];
  
  [XLSharedFacility addLogger:logger];
  
  for (int i = 0; i < 10; ++i) {
    [XLSharedFacility logMessageWithTag:XLOG_TAG level:(i % 5) format:@"Hello World #%i!", i + 1];
  }
  usleep(kLoggingDelay);
  
  __block int index = 0;
  [logger enumerateRecordsAfterAbsoluteTime:0.0 backward:NO maxRecords:0 usingBlock:^(int appVersion, XLLogRecord* record, BOOL* stop) {
    XCTAssertEqualObjects(record, _capturedRecords[index]);
    ++index;
  }];
  
  [XLSharedFacility removeLogger:logger];
  [[NSFileManager defaultManager] removeItemAtPath:databasePath error:NULL];
}

- (void)testASLLogger {
  [XLSharedFacility addLogger:[XLASLLogger sharedLogger]];
  
  XLOG_INFO(@"Bonjour le monde!");
  XLOG_WARNING(@"Hello World!");
  usleep(kLoggingDelay);
  
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
  
  [XLSharedFacility removeLogger:[XLASLLogger sharedLogger]];
}

// This is mostly copy-pasted from unit tests in GCDTelnetServer
- (void)testTelnetLogger {
  XLTelnetServerLogger* logger = [[XLTelnetServerLogger alloc] initWithPort:3333 preserveHistory:YES];
  logger.format = @"[%L] %m";
  logger.shouldColorize = NO;
  [XLSharedFacility addLogger:logger];
  
  XLOG_INFO(@"Bonjour le monde!");
  XLOG_WARNING(@"Hello World!");
  usleep(kLoggingDelay);
  
  XCTestExpectation* expectation = [self expectationWithDescription:nil];
  [GCDTCPConnection connectAsynchronouslyToHost:@"localhost" port:3333 timeout:1.0 completion:^(GCDTCPConnection* connection) {
    XCTAssertNotNil(connection);
    [connection open];
    
    usleep(kCommunicationSleepDelay);
    
    NSData* data1 = [connection readDataWithTimeout:1.0];
    XCTAssertEqual(data1.length, 3);
    unsigned char buffer1[] = {255, 253, 3};
    XCTAssertTrue([connection writeData:[NSData dataWithBytes:buffer1 length:sizeof(buffer1)] withTimeout:1.0]);
    
    usleep(kCommunicationSleepDelay);
    
    NSData* data2 = [connection readDataWithTimeout:1.0];
    XCTAssertEqual(data2.length, 3);
    unsigned char buffer2[] = {255, 253, 1};
    XCTAssertTrue([connection writeData:[NSData dataWithBytes:buffer2 length:sizeof(buffer2)] withTimeout:1.0]);
    
    usleep(kCommunicationSleepDelay);
    
    NSData* data3 = [connection readDataWithTimeout:1.0];
    XCTAssertEqual(data3.length, 3);
    unsigned char buffer3[] = {255, 254, 24};
    XCTAssertTrue([connection writeData:[NSData dataWithBytes:buffer3 length:sizeof(buffer3)] withTimeout:1.0]);
    
    usleep(kCommunicationSleepDelay);
    
    NSData* data4 = [connection readDataWithTimeout:1.0];
    XCTAssertNotNil(data4);
    NSString* string4 = [[NSString alloc] initWithData:data4 encoding:NSASCIIStringEncoding];
    
    NSRange range = [string4 rangeOfString:@"[INFO     ] Bonjour le monde!\r\n[WARNING  ] Hello World!\r\n"];
    XCTAssertTrue(range.location != NSNotFound);
    
    XLOG_ERROR(@"Hello again!");
    usleep(kLoggingDelay);
    
    [connection readDataAsynchronously:^(NSData* data5) {
      XCTAssertNotNil(data5);
      NSString* string5 = [[NSString alloc] initWithData:data5 encoding:NSUTF8StringEncoding];
      XCTAssertEqualObjects(string5, @"[ERROR    ] Hello again!\r\n");
      
      [connection close];
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:10.0 handler:NULL];
  
  [XLSharedFacility removeLogger:logger];
}

- (void)testHTTPLogger {
  XLHTTPServerLogger* logger = [[XLHTTPServerLogger alloc] initWithPort:8888];
  [XLSharedFacility addLogger:logger];
  
  XLOG_INFO(@"Bonjour le monde!");
  XLOG_WARNING(@"Hello World!");
  usleep(kLoggingDelay);
  
  CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
  
  NSHTTPURLResponse* response1 = nil;
  NSURL* url1 = [NSURL URLWithString:@"http://localhost:8888/"];
  NSData* data1 = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url1] returningResponse:&response1 error:NULL];
  XCTAssertNotNil(data1);
  XCTAssertEqual(response1.statusCode, 200);
  NSString* string1 = [[NSString alloc] initWithData:data1 encoding:NSUTF8StringEncoding];
  NSRange range1 = [string1 rangeOfString:@"Bonjour le monde!"];
  XCTAssertNotEqual(range1.location, NSNotFound);
  NSRange range2 = [string1 rangeOfString:@"Hello World!"];
  XCTAssertNotEqual(range2.location, NSNotFound);
  
  XCTestExpectation* expectation = [self expectationWithDescription:nil];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
    NSHTTPURLResponse* response2 = nil;
    NSURL* url2 = [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:8888/log?after=%f", time]];
    NSData* data2 = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url2] returningResponse:&response2 error:NULL];
    XCTAssertNotNil(data2);
    XCTAssertEqual(response2.statusCode, 200);
    NSString* string2 = [[NSString alloc] initWithData:data2 encoding:NSUTF8StringEncoding];
    NSRange range3 = [string2 rangeOfString:@"Hello again!"];
    XCTAssertNotEqual(range3.location, NSNotFound);
    
    [expectation fulfill];
  });
  sleep(5);
  XLOG_ERROR(@"Hello again!");
  [self waitForExpectationsWithTimeout:10.0 handler:NULL];
  
  [XLSharedFacility removeLogger:logger];
}

- (void)testTCPClientLogger {
  __block GCDTCPPeerConnection* connection = nil;
  TestServer* server = [[TestServer alloc] initWithPort:4242 connectionBlock:^(GCDTCPPeerConnection* newConnection) {
    connection = newConnection;
  }];
  XCTAssertTrue([server start]);
  
  XLTCPClientLogger* logger = [[XLTCPClientLogger alloc] initWithHost:@"localhost" port:4242 preserveHistory:NO];
  logger.format = @"[%L] %m";
  logger.TCPClient.minReconnectInterval = 1.0;
  logger.TCPClient.maxReconnectInterval = 1.0;
  [XLSharedFacility addLogger:logger];
  
  sleep(1);
  XCTAssertNotNil(connection);
  
  XLOG_INFO(@"Bonjour le monde!");
  XLOG_WARNING(@"Hello World!");
  usleep(kLoggingDelay);
  
  XCTestExpectation* expectation1 = [self expectationWithDescription:nil];
  [connection readDataAsynchronously:^(NSData* data) {
    XCTAssertNotNil(data);
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(string, @"\
[INFO     ] Bonjour le monde!\n\
[WARNING  ] Hello World!\n\
");
    
    [connection close];
    connection = nil;
    
    [expectation1 fulfill];
  }];
  [self waitForExpectationsWithTimeout:10.0 handler:NULL];
  XCTAssertNil(connection);
  
  for (int i = 0; i < 10; ++i) {
    XLOG_VERBOSE(@"HEY THERE");
  }
  usleep(kLoggingDelay);
  
  XCTAssertNil(logger.TCPClient.connection);
  
  sleep(2);
  
  XCTAssertNotNil(connection);
  
  XLOG_ERROR(@"Hello again!");
  usleep(kLoggingDelay);
  
  XCTestExpectation* expectation2 = [self expectationWithDescription:nil];
  [connection readDataAsynchronously:^(NSData* data) {
    XCTAssertNotNil(data);
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(string, @"[ERROR    ] Hello again!\n");
    
    [connection close];
    connection = nil;
    
    [expectation2 fulfill];
  }];
  [self waitForExpectationsWithTimeout:10.0 handler:NULL];
  XCTAssertNil(connection);
  
  [XLSharedFacility removeLogger:logger];
  
  [server stop];
}

- (void)testRecursiveLogging {
  TestLogger* logger = [[TestLogger alloc] init];
  [XLSharedFacility addLogger:logger];
  
  XLOG_ERROR(@"Hello World!");
  
  [XLSharedFacility removeLogger:logger];
}

@end
