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

#import "FBSDKCameraEffectArguments.h"
#import "FBSDKCameraEffectTextures.h"
#import "FBSDKSharingContent.h"
#import "FBSDKSharingScheme.h"

NS_ASSUME_NONNULL_BEGIN

/**
 A model for content to share with a Facebook camera effect.
 */
NS_SWIFT_NAME(ShareCameraEffectContent)
@interface FBSDKShareCameraEffectContent : NSObject <FBSDKSharingContent, FBSDKSharingScheme>

/**
 ID of the camera effect to use.
 */
@property (nonatomic, copy) NSString *effectID;

/**
 Arguments for the effect.
 */
@property (nonatomic, copy) FBSDKCameraEffectArguments *effectArguments;

/**
 Textures for the effect.
 */
@property (nonatomic, copy) FBSDKCameraEffectTextures *effectTextures;

/**
 Compares the receiver to another camera effect content.
 @param content The other content
 @return YES if the receiver's values are equal to the other content's values; otherwise NO
 */
- (BOOL)isEqualToShareCameraEffectContent:(FBSDKShareCameraEffectContent *)content;

@end

NS_ASSUME_NONNULL_END

#endif
