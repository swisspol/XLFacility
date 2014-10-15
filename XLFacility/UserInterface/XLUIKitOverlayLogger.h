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

#import <UIKit/UIKit.h>

#import "XLLogger.h"

/**
 *  The XLUIKitOverlayLogger class displays an overlay window on top of the
 *  entire app user interface whenever log records are received.
 */
@interface XLUIKitOverlayLogger : XLLogger

/**
 *  Sets the opacity of the window overlay in [0.0, 1.0] range.
 *
 *  The default value is 0.75.
 */
@property(nonatomic) float overlayOpacity;

/**
 *  Sets the duration in seconds during which the overlay remains visible after
 *  the last log record was received. Set to 0.0 to make the overlay always
 *  visible.
 *
 *  The default value is 5.0.
 */
@property(nonatomic) NSTimeInterval overlayDuration;

/**
 *  Sets the font used to display log records.
 *
 *  The default value is (Courier, 13.0).
 */
@property(nonatomic, retain) UIFont* textFont;

/**
 *  Returns the shared instance for XLUIKitOverlayLogger.
 */
+ (XLUIKitOverlayLogger*)sharedLogger;

@end
