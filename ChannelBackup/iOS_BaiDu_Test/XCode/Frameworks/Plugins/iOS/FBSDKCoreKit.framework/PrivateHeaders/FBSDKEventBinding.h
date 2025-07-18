// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "TargetConditionals.h"

#if !TARGET_OS_TV

#import <UIKit/UIKit.h>
#import "FBSDKAppEventsNumberParser.h"
#import "FBSDKCodelessParameterComponent.h"

@protocol FBSDKEventLogging;

NS_SWIFT_NAME(EventBinding)
@interface FBSDKEventBinding : NSObject

@property (class, nonatomic, readonly) id<FBSDKNumberParsing> numberParser;
@property (nonatomic, copy, readonly) NSString *eventName;
@property (nonatomic, copy, readonly) NSString *eventType;
@property (nonatomic, copy, readonly) NSString *appVersion;
@property (nonatomic, readonly) NSArray *path;
@property (nonatomic, copy, readonly) NSString *pathType;
@property (nonatomic, readonly) NSArray<FBSDKCodelessParameterComponent *> *parameters;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (BOOL)isViewMatchPath:(UIView *)view path:(NSArray *)path;
+ (BOOL)isPath:(NSArray *)path matchViewPath:(NSArray *)viewPath;
- (FBSDKEventBinding *)initWithJSON:(NSDictionary *)dict
                        eventLogger:(id<FBSDKEventLogging>)eventLogger;
- (void)trackEvent:(id)sender;
- (BOOL)isEqualToBinding:(FBSDKEventBinding *)binding;

@end

#endif
