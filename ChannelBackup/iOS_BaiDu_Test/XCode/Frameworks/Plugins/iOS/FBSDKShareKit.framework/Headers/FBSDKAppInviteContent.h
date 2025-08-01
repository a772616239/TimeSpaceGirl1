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

#import "FBSDKCoreKitImport_Share.h"

#import "FBSDKSharingValidation.h"

NS_ASSUME_NONNULL_BEGIN

/**
 NS_ENUM(NSUInteger, FBSDKAppInviteDestination)
  Specifies the privacy of a group.
 */
typedef NS_ENUM(NSUInteger, FBSDKAppInviteDestination)
{
  /** Deliver to Facebook. */
  FBSDKAppInviteDestinationFacebook = 0,
  /** Deliver to Messenger. */
  FBSDKAppInviteDestinationMessenger,
} NS_SWIFT_NAME(AppInviteDestination);

/**
  A model for app invite.
 */
NS_SWIFT_NAME(AppInviteContent)
@interface FBSDKAppInviteContent : NSObject <FBSDKCopying, FBSDKSharingValidation, NSSecureCoding>

/**
  A URL to a preview image that will be displayed with the app invite


 This is optional.  If you don't include it a fallback image will be used.
*/
@property (nonatomic, copy, nullable) NSURL *appInvitePreviewImageURL;

/**
  An app link target that will be used as a target when the user accept the invite.


 This is a requirement.
 */
@property (nonatomic, copy) NSURL *appLinkURL;

/**
  Promotional code to be displayed while sending and receiving the invite.


 This is optional. This can be between 0 and 10 characters long and can contain
 alphanumeric characters only. To set a promo code, you need to set promo text.
 */
@property (nonatomic, copy, nullable) NSString *promotionCode;

/**
  Promotional text to be displayed while sending and receiving the invite.


 This is optional. This can be between 0 and 80 characters long and can contain
 alphanumeric and spaces only.
 */
@property (nonatomic, copy, nullable) NSString *promotionText;

/**
  Destination for the app invite.


 This is optional and for declaring destination of the invite.
 */
@property (nonatomic, assign) FBSDKAppInviteDestination destination;

/**
  Compares the receiver to another app invite content.
 @param content The other content
 @return YES if the receiver's values are equal to the other content's values; otherwise NO
 */
- (BOOL)isEqualToAppInviteContent:(FBSDKAppInviteContent *)content;

@end

NS_ASSUME_NONNULL_END

#endif
