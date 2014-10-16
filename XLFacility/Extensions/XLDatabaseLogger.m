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

#import <sqlite3.h>

#import "XLDatabaseLogger.h"
#import "XLFunctions.h"
#import "XLPrivate.h"

#define kTableName "records_v2"

@interface XLDatabaseLogger () {
@private
  sqlite3* _database;
  sqlite3_stmt* _statement;
}
@end

@implementation XLDatabaseLogger

- (id)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithDatabasePath:(NSString*)path appVersion:(int)appVersion {
  XLOG_DEBUG_CHECK(path);
  if ((self = [super init])) {
    _databasePath = [path copy];
    _appVersion = appVersion;
  }
  return self;
}

- (BOOL)open {
  int result = sqlite3_open([_databasePath fileSystemRepresentation], &_database);
  if (result == SQLITE_OK) {
    result = sqlite3_exec(_database, "CREATE TABLE IF NOT EXISTS " kTableName " (version INTEGER, time REAL, tag TEXT, level INTEGER, message TEXT, errno INTEGER, thread INTEGER, queue TEXT, callstack TEXT)",
                          NULL, NULL, NULL);
  }
  if (result == SQLITE_OK) {
    NSString* statement = [NSString stringWithFormat:@"INSERT INTO " kTableName " (version, time, tag, level, message, errno, thread, queue, callstack) VALUES (%i, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                           (int)_appVersion];
    result = sqlite3_prepare_v2(_database, [statement UTF8String], -1, &_statement, NULL);
  }
  if (result != SQLITE_OK) {
    XLOG_ERROR(@"Failed opening database at path \"%@\": %s", _databasePath, sqlite3_errmsg(_database));
    sqlite3_close(_database);  // Always call even if sqlite3_open() failed
    _database = NULL;
    return NO;
  }
  return YES;
}

- (void)logRecord:(XLLogRecord*)record {
  sqlite3_bind_double(_statement, 1, record.absoluteTime);
  const char* tag = XLConvertNSStringToUTF8CString(record.tag);
  if (tag) {
    sqlite3_bind_text(_statement, 2, tag, -1, SQLITE_STATIC);
  } else {
    sqlite3_bind_null(_statement, 2);
  }
  sqlite3_bind_int(_statement, 3, record.level);
  sqlite3_bind_text(_statement, 4, XLConvertNSStringToUTF8CString(record.message), -1, SQLITE_STATIC);
  sqlite3_bind_int(_statement, 5, record.capturedErrno);
  sqlite3_bind_int(_statement, 6, record.capturedThreadID);
  const char* label = XLConvertNSStringToUTF8CString(record.capturedQueueLabel);
  if (label) {
    sqlite3_bind_text(_statement, 7, label, -1, SQLITE_STATIC);
  } else {
    sqlite3_bind_null(_statement, 7);
  }
  const char* callstack = XLConvertNSStringToUTF8CString([record.callstack componentsJoinedByString:@"\n"]);
  if (callstack) {
    sqlite3_bind_text(_statement, 8, callstack, -1, SQLITE_STATIC);
  } else {
    sqlite3_bind_null(_statement, 8);
  }
  if (sqlite3_step(_statement) != SQLITE_DONE) {
    XLOG_ERROR(@"Failed writing to database at path \"%@\": %s", _databasePath, sqlite3_errmsg(_database));
  }
  sqlite3_reset(_statement);
  sqlite3_clear_bindings(_statement);
}

- (void)close {
  sqlite3_finalize(_statement);
  _statement = NULL;
  sqlite3_close(_database);
  _database = NULL;
}

- (BOOL)purgeRecordsBeforeAbsoluteTime:(CFAbsoluteTime)time {
  sqlite3* database = NULL;
  int result = sqlite3_open([_databasePath fileSystemRepresentation], &database);
  if (result == SQLITE_OK) {
    if (time > 0.0) {
      NSString* statement = [NSString stringWithFormat:@"DELETE FROM " kTableName " WHERE time < %f",
                                                       time];
      result = sqlite3_exec(database, [statement UTF8String], NULL, NULL, NULL);
    } else {
      result = sqlite3_exec(database, "DELETE FROM " kTableName, NULL, NULL, NULL);
    }
    if (result == SQLITE_OK) {
      result = sqlite3_exec(database, "VACUUM", NULL, NULL, NULL);
    }
  }
  if (result != SQLITE_OK) {
    XLOG_ERROR(@"Failed opening database at path \"%@\": %s", _databasePath, sqlite3_errmsg(database));
  }
  sqlite3_close(database);  // Always call even if sqlite3_open() failed
  return (result == SQLITE_OK ? YES : NO);
}

- (void)enumerateRecordsAfterAbsoluteTime:(CFAbsoluteTime)time
                                 backward:(BOOL)backward
                               maxRecords:(NSUInteger)limit
                               usingBlock:(void (^)(int appVersion, XLLogRecord* record, BOOL* stop))block {
  sqlite3* database = NULL;
  int result = sqlite3_open([_databasePath fileSystemRepresentation], &database);
  if (result == SQLITE_OK) {
    NSString* string = [NSString stringWithFormat:@"SELECT version, time, tag, level, message, errno, thread, queue, callstack FROM " kTableName " WHERE %@ ORDER BY time %@",
                                                  time > 0.0 ? [NSString stringWithFormat:@"time > %f", time] : @"1",
                                                  backward ? @"DESC" : @"ASC"];
    if (limit > 0) {
      string = [string stringByAppendingFormat:@" LIMIT %i", (int)limit];
    }
    sqlite3_stmt* statement = NULL;
    result = sqlite3_prepare_v2(database, [string UTF8String], -1, &statement, NULL);
    if (result == SQLITE_OK) {
      BOOL stop = NO;
      while (1) {
        result = sqlite3_step(statement);
        if (result != SQLITE_ROW) {
          break;
        }
        
        int version = sqlite3_column_int(statement, 0);
        double absoluteTime = sqlite3_column_double(statement, 1);
        const unsigned char* tagUTF8 = sqlite3_column_text(statement, 2);
        int level = sqlite3_column_int(statement, 3);
        const unsigned char* messageUTF8 = sqlite3_column_text(statement, 4);
        int capturedErrno = sqlite3_column_int(statement, 5);
        int capturedThreadID = sqlite3_column_int(statement, 6);
        const unsigned char* capturedQueueLabelUTF8 = sqlite3_column_text(statement, 7);
        const unsigned char* callstackUTF8 = sqlite3_column_text(statement, 8);
        
        NSString* tag = tagUTF8 ? [NSString stringWithUTF8String:(char*)tagUTF8] : nil;
        NSString* message = messageUTF8 ? [NSString stringWithUTF8String:(char*)messageUTF8] : nil;
        NSString* capturedQueueLabel = capturedQueueLabelUTF8 ? [NSString stringWithUTF8String:(char*)capturedQueueLabelUTF8] : nil;
        NSArray* callstack = [(callstackUTF8 ? [NSString stringWithUTF8String:(char*)callstackUTF8] : nil) componentsSeparatedByString:@"\n"];
        if (message) {
          XLLogRecord* record = [[XLLogRecord alloc] initWithAbsoluteTime:absoluteTime
                                                                tag:tag
                                                                    level:level
                                                                  message:message
                                                            capturedErrno:capturedErrno
                                                         capturedThreadID:capturedThreadID
                                                       capturedQueueLabel:capturedQueueLabel
                                                                callstack:callstack];
          block(version, record, &stop);
          if (stop) {
            result = SQLITE_DONE;
            break;
          }
        } else {
          XLOG_ERROR(@"Failed reading record from database at path \"%@\": %s", _databasePath, sqlite3_errmsg(database));
        }
      }
    }
    sqlite3_finalize(statement);
  }
  if (result != SQLITE_DONE) {
    XLOG_ERROR(@"Failed reading database at path \"%@\": %s", _databasePath, sqlite3_errmsg(database));
  }
  sqlite3_close(database);  // Always call even if sqlite3_open() failed
}

@end
