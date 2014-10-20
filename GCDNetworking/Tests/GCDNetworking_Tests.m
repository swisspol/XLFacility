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

#import "GCDNetworking.h"

typedef void (^TCPServerConnectionBlock)(GCDTCPPeerConnection* connection);

@interface TCPServer : GCDTCPServer
@end

@implementation TCPServer {
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

@interface GCDNetworking_Tests : XCTestCase
@end

@implementation GCDNetworking_Tests

- (void)testReading {
  __block GCDTCPPeerConnection* inConnection = nil;
  TCPServer* server = [[TCPServer alloc] initWithPort:4444 connectionBlock:^(GCDTCPPeerConnection* connection) {
    inConnection = connection;
  }];
  XCTAssertTrue([server start]);
  
  GCDTCPClient* client = [[GCDTCPClient alloc] initWithConnectionClass:[GCDTCPClientConnection class] host:@"localhost" port:4444];
  XCTAssertTrue([client start]);
  
  sleep(1);
  
  XCTAssertNotNil(inConnection);
  GCDTCPClientConnection* outConnection = client.connection;
  XCTAssertNotNil(outConnection);
  
  NSData* data1 = [inConnection readDataWithTimeout:3.0];
  XCTAssertNil(data1);
  
  XCTestExpectation* expectation = [self expectationWithDescription:nil];
  [outConnection writeDataAsynchronously:[@"Hello World!\n" dataUsingEncoding:NSUTF8StringEncoding] completion:^(BOOL success) {
    XCTAssertTrue(success);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:10.0 handler:NULL];
  NSData* data2 = [inConnection readDataWithTimeout:3.0];
  XCTAssertNotNil(data2);
  NSString* string = [[NSString alloc] initWithData:data2 encoding:NSUTF8StringEncoding];
  XCTAssertEqualObjects(string, @"Hello World!\n");
  
  [outConnection close];
  [inConnection close];
  
  [client stop];
  [server stop];
}

- (void)testWriting {
  __block GCDTCPPeerConnection* inConnection = nil;
  TCPServer* server = [[TCPServer alloc] initWithPort:4444 connectionBlock:^(GCDTCPPeerConnection* connection) {
    inConnection = connection;
  }];
  XCTAssertTrue([server start]);
  
  GCDTCPClient* client = [[GCDTCPClient alloc] initWithConnectionClass:[GCDTCPClientConnection class] host:@"localhost" port:4444];
  XCTAssertTrue([client start]);
  
  sleep(1);
  
  XCTAssertNotNil(inConnection);
  GCDTCPClientConnection* outConnection = client.connection;
  XCTAssertNotNil(outConnection);
  
  XCTestExpectation* expectation = [self expectationWithDescription:nil];
  [inConnection readDataAsynchronously:^(NSData* data) {
    XCTAssertNotNil(data);
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(string, @"Hello World!\n");
    
    [expectation fulfill];
  }];
  BOOL success = [outConnection writeData:[@"Hello World!\n" dataUsingEncoding:NSUTF8StringEncoding] withTimeout:3.0];
  XCTAssertTrue(success);
  [self waitForExpectationsWithTimeout:10.0 handler:NULL];
  
  [outConnection close];
  [inConnection close];
  
  [client stop];
  [server stop];
}

@end
