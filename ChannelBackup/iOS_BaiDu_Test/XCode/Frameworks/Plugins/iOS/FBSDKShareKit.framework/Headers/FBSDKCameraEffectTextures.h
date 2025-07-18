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

#import "FBSDKCoreKitImport_Share.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A container of textures for a camera effect.
 * A texture for a camera effect is an UIImages identified by a NSString key.
 */
NS_SWIFT_NAME(CameraEffectTextures)
@interface FBSDKCameraEffectTextures : NSObject <FBSDKCopying, NSSecureCoding>

/**
 Sets the image for a texture key.
 @param image The UIImage for the texture
 @param key The key for the texture
 */
- (void)setImage:(nullable UIImage *)image forKey:(NSString *)key
NS_SWIFT_NAME(set(_:forKey:));

/**
 Gets the image for a texture key.
 @param key The key for the texture
 @return The texture UIImage or nil
 */
- (nullable UIImage *)imageForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

#endif
