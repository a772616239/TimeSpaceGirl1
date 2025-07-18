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

 #import "FBSDKEventProcessing.h"

 @protocol FBSDKDataPersisting;
 @protocol FBSDKFeatureChecking;
 @protocol FBSDKFileManaging;
 @protocol FBSDKGraphRequestProviding;
 @protocol FBSDKSettings;
 @protocol FBSDKFileDataExtracting;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ModelManager)
@interface FBSDKModelManager : NSObject<FBSDKEventProcessing>

@property (class, nonnull, readonly) FBSDKModelManager *shared;

- (void)enable;
- (nullable NSData *)getWeightsForKey:(NSString *)useCase;
- (nullable NSArray *)getThresholdsForKey:(NSString *)useCase;
- (BOOL)processIntegrity:(nullable NSString *)param;
- (NSString *)processSuggestedEvents:(NSString *)textFeature denseData:(nullable float *)denseData;
- (void)configureWithFeatureChecker:(id<FBSDKFeatureChecking>)featureChecker
                graphRequestFactory:(id<FBSDKGraphRequestProviding>)graphRequestFactory
                        fileManager:(id<FBSDKFileManaging>)fileManager
                              store:(id<FBSDKDataPersisting>)store
                           settings:(id<FBSDKSettings>)settings
                      dataExtractor:(Class<FBSDKFileDataExtracting>)dataExtractor;

@end

NS_ASSUME_NONNULL_END

#endif
