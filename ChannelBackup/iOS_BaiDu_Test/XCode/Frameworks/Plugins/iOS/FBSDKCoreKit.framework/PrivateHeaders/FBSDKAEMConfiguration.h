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

 #import <Foundation/Foundation.h>

 #import "FBSDKAEMRule.h"
 #import "FBSDKAEMAdvertiserRuleMatching.h"
 #import "FBSDKAEMAdvertiserRuleProviding.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AEMConfiguration)
@interface FBSDKAEMConfiguration : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, readonly, assign) NSInteger cutoffTime;

/** The UNIX timestamp of config's valid date and works as a unqiue identifier of the config */
@property (nonatomic, readonly, assign) NSInteger validFrom;

@property (nonatomic, readonly, copy) NSString *defaultCurrency;

@property (nonatomic, readonly, copy) NSString *configMode;

@property (nullable, nonatomic, readonly, copy) NSString *businessID;

@property (nullable, nonatomic, readonly, copy) id<FBSDKAEMAdvertiserRuleMatching> matchingRule;

@property (nonatomic, readonly) NSArray<FBSDKAEMRule *> *conversionValueRules;

@property (nonatomic, readonly) NSSet<NSString *> *eventSet;

@property (nonatomic, readonly) NSSet<NSString *> *currencySet;

+ (void)configureWithRuleProvider:(id<FBSDKAEMAdvertiserRuleProviding>)ruleProvider;

- (nullable instancetype)initWithJSON:(nullable NSDictionary<NSString *, id> *)dict;

- (BOOL)isSameValidFrom:(NSInteger)validFrom
             businessID:(nullable NSString *)businessID;

- (BOOL)isSameBusinessID:(nullable NSString *)businessID;

@end

NS_ASSUME_NONNULL_END

#endif
