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
 *  The XLDatabaseLogger class saves logs records to a SQLite database which
 *  can be queried afterwards.
 *
 *  The "appVersion" argument can be used to keep track of which version of
 *  your app generated a given log record.
 *
 *  @warning XLUIKitOverlayLogger does not format records in any way and ignores
 *  the "format" property of XLLogger: it justs serializes records to the database.
 */
@interface XLDatabaseLogger : XLLogger

/**
 *  Returns the database path as specified when the logger was initialized.
 */
@property(nonatomic, readonly) NSString* databasePath;

/**
 *  Returns the app version as specified when the logger was initialized.
 */
@property(nonatomic, readonly) int appVersion;

/**
 *  Initializes a database logger at "~/Library/Caches/{APP_NAME}.db" and sets
 *  the app version to "CFBundleVersion" from the main bundle" Info.plist"
 *  (which is expected to be an integer).
 */
- (instancetype)init;

/**
 *  This method is the designated initializer for the class.
 *
 *  @warning The database file is not created or opened until the logger is
 *  opened.
 */
- (instancetype)initWithDatabasePath:(NSString*)path appVersion:(int)appVersion;

/**
 *  Deletes records from the database that are older than a specific time.
 *  Pass 0.0 to delete all records.
 *
 *  Returns NO if a database error occured.
 */
- (BOOL)purgeRecordsBeforeAbsoluteTime:(CFAbsoluteTime)time;

/**
 *  Enumerates records in the database that are newer than a specific time.
 *  Pass 0.0 for "time" to enumerate all records since the beginning of time
 *  and pass 0 for "limit" to fetch all matching records.
 *
 *  Returns NO if a database error occured.
 */
- (BOOL)enumerateRecordsAfterAbsoluteTime:(CFAbsoluteTime)time
                                 backward:(BOOL)backward
                               maxRecords:(NSUInteger)limit
                               usingBlock:(void (^)(int appVersion, XLLogRecord* record, BOOL* stop))block;

@end

@interface XLDatabaseLogger (Extensions)

/**
 *  Deletes all records from the database.
 *
 *  Returns NO if a database error occured.
 */
- (BOOL)purgeAllRecords;

/**
 *  Enumerates all records in the database.
 *
 *  Returns NO if a database error occured.
 */
- (BOOL)enumerateAllRecordsBackward:(BOOL)backward usingBlock:(void (^)(int appVersion, XLLogRecord* record, BOOL* stop))block;

@end
