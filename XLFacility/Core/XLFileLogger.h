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

#import "XLLogger.h"

/**
 *  The XLFileLogger class writes logs records to a file.
 *
 *  @warning XLFileLogger does not perform any buffering when writing to the
 *  file i.e. log records are written to disk immediately.
 */
@interface XLFileLogger : XLLogger

/**
 *  Returns the file path as specified when the logger was initialized or nil
 *  if it was initialized with a file descriptor.
 */
@property(nonatomic, readonly) NSString* filePath;

/**
 *  Returns the file descriptor as specified when the logger was initialized
 *  or 0 if it was initialized with a file path.
 */
@property(nonatomic, readonly) int fileDescriptor;

/**
 *  This method is a designated initializer for the class.
 *
 *  @warning The file is not created or opened until the logger is opened.
 */
- (instancetype)initWithFilePath:(NSString*)path append:(BOOL)append;

/**
 *  This method is a designated initializer for the class.
 */
- (instancetype)initWithFileDescriptor:(int)fd closeOnDealloc:(BOOL)close;

@end
