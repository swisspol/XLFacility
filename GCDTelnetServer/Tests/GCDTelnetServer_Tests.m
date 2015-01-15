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

#import <XCTest/XCTest.h>

#import "GCDTelnetServer.h"

#define kTestPort 3333
#define kCommunicationSleepDelay (100 * 1000)

@interface GCDTelnetServer_Tests : XCTestCase
@end

@implementation GCDTelnetServer_Tests

- (void)testCLIParsing {
  GCDTelnetConnection* connection = [[GCDTelnetConnection alloc] initWithSocket:0];
  NSArray* array1 = [connection parseLineAsCommandAndArguments:@"this is 'a test' string \"using quoting\""];
  NSArray* array2 = @[@"this", @"is", @"a test", @"string", @"using quoting"];
  XCTAssertEqualObjects(array1, array2);
}

- (void)testHandlers {
  GCDTelnetServer* server = [[GCDTelnetServer alloc] initWithPort:kTestPort startHandler:^NSString*(GCDTelnetConnection* connection) {
    return @"Hello World!\n";
  } lineHandler:^NSString *(GCDTelnetConnection* connection, NSString* line) {
    return [line stringByAppendingString:@"\n"];
  }];
  XCTAssertTrue([server start]);
  
  XCTestExpectation* expectation = [self expectationWithDescription:nil];
  [GCDTCPConnection connectAsynchronouslyToHost:@"localhost" port:kTestPort timeout:1.0 completion:^(GCDTCPConnection* connection) {
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
    XCTAssertEqualObjects(string4, @"Hello World!\r\n> ");
    
    XCTAssertTrue([connection writeString:@"B" withTimeout:1.0]);
    usleep(kCommunicationSleepDelay);
    XCTAssertTrue([connection writeString:@"o" withTimeout:1.0]);
    usleep(kCommunicationSleepDelay);
    XCTAssertTrue([connection writeString:@"n" withTimeout:1.0]);
    usleep(kCommunicationSleepDelay);
    XCTAssertTrue([connection writeString:@"j" withTimeout:1.0]);
    usleep(kCommunicationSleepDelay);
    XCTAssertTrue([connection writeString:@"o" withTimeout:1.0]);
    usleep(kCommunicationSleepDelay);
    XCTAssertTrue([connection writeString:@"u" withTimeout:1.0]);
    usleep(kCommunicationSleepDelay);
    XCTAssertTrue([connection writeString:@"r" withTimeout:1.0]);
    usleep(kCommunicationSleepDelay);
    XCTAssertTrue([connection writeString:@"\r\0" withTimeout:1.0]);
    usleep(kCommunicationSleepDelay);
    
    NSData* data5 = [connection readDataWithTimeout:1.0];
    XCTAssertNotNil(data5);
    NSString* string5 = [[NSString alloc] initWithData:data5 encoding:NSASCIIStringEncoding];
    XCTAssertEqualObjects(string5, @"Bonjour\r\nBonjour\r\n> ");
    
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:10.0 handler:NULL];
  
  [server stop];
}

@end
