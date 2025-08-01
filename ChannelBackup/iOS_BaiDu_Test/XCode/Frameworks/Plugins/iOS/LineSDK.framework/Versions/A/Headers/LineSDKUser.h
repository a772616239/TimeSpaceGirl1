//
//  Copyright (c) 2016-present, LINE Corporation. All rights reserved.
//
//  You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
//  copy and distribute this software in source code or binary form for use
//  in connection with the web services and APIs provided by LINE Corporation.
//
//  As with any software that integrates with the LINE Corporation platform, your use of this software
//  is subject to the LINE Developers Agreement [http://terms2.line.me/LINE_Developers_Agreement].
//  This copyright notice shall be included in all copies or substantial portions of the software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
//  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <Foundation/Foundation.h>
#import "LineSDKAttributes.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Represents a user.
 */
NS_SWIFT_NAME(User)
@interface LineSDKUser : NSObject

/**
 The user's user ID.
 */
@property (nonatomic, copy, readonly) NSString *userID;

/**
 The user’s display name.
 */
@property (nonatomic, copy, readonly) NSString *displayName;

/**
 The user’s profile media URL.
 */
@property (nonatomic, copy, readonly, nullable) NSURL *pictureURL;

/**
 :nodoc:
 Use `initWithUserID:displayName:pictureURL:` instead.
 */
- (instancetype)init LSDK_UNAVAILABLE("Use `initWithUserID:displayName:pictureURL:` instead");

/**
 Instantiates a user.

 @param userID The user's user ID.
 @param displayName The user's display name.
 @param pictureURL The user's profile media URL.
 */
- (instancetype)initWithUserID:(NSString *)userID
                   displayName:(NSString *)displayName
                    pictureURL:(nullable NSURL *)pictureURL NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
