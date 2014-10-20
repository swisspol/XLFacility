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

#if !__has_feature(objc_arc)
#error XLFacility requires ARC
#endif

#import "XLFileLogger.h"
#import "XLFunctions.h"
#import "XLFacilityPrivate.h"

@interface XLFileLogger () {
@private
  int _fd;
  BOOL _close;
  BOOL _append;
}
@end

@implementation XLFileLogger

- (id)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithFilePath:(NSString*)path append:(BOOL)append {
  XLOG_DEBUG_CHECK(path);
  if ((self = [super init])) {
    _filePath = [path copy];
    _append = append;
  }
  return self;
}

- (instancetype)initWithFileDescriptor:(int)fd closeOnDealloc:(BOOL)close {
  XLOG_DEBUG_CHECK(fd >= 0);
  if ((self = [super init])) {
    _fileDescriptor = fd;
    _close = close;
  }
  return self;
}

- (void)dealloc {
  if (_close) {
    close(_fileDescriptor);
  }
}

- (BOOL)open {
  if (_filePath) {
    _fd = open([_filePath fileSystemRepresentation], O_CREAT | (_append ? 0 : O_TRUNC) | O_WRONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
    if (_fd < 0) {
      XLOG_ERROR(@"Failed opening log file at \"%@\": %s", _filePath, strerror(errno));
      return NO;
    }
  } else {
    _fd = _fileDescriptor;
  }
  return YES;
}

// We are using write() which is not buffered contrary to fwrite() so no flushing is needed
- (void)logRecord:(XLLogRecord*)record {
  if (_fd >= 0) {
    NSData* data = XLConvertNSStringToUTF8String([self formatRecord:record]);
    if (write(_fd, data.bytes, data.length) < 0) {
      if (_filePath) {
        XLOG_ERROR(@"Failed writing to log file at \"%@\": %s", _filePath, strerror(errno));
        close(_fd);
      } else {
        XLOG_ERROR(@"Failed writing to file descriptor: %s", strerror(errno));
      }
      _fd = -1;
    }
  }
}

- (void)close {
  if (_filePath) {
    close(_fd);
  }
  _fd = -1;
}

@end
