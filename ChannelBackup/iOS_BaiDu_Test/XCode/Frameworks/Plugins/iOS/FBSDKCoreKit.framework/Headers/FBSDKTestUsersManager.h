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

#import <Foundation/Foundation.h>

#import "FBSDKConstants.h"

NS_ASSUME_NONNULL_BEGIN

@class FBSDKAccessToken;

/**
 Callback block for returning an array of FBSDKAccessToken instances (and possibly `NSNull` instances); or an error.
 */
typedef void (^FBSDKAccessTokensBlock)(NSArray<FBSDKAccessToken *> *tokens, NSError *_Nullable error)
NS_SWIFT_NAME(AccessTokensBlock)
DEPRECATED_MSG_ATTRIBUTE("AccessTokensBlock is deprecated and will be removed in the next major release");


/**
  Provides methods for managing test accounts for testing Facebook integration.


 Facebook allows developers to create test accounts for testing their applications'
 Facebook integration (see https://developers.facebook.com/docs/test_users/). This class
 simplifies use of these accounts for writing tests. It is not designed for use in
 production application code.

 This class will make Graph API calls on behalf of your app to manage test accounts and requires
 an app id and app secret. You will typically use this class to write unit or integration tests.
 Make sure you NEVER include your app secret in your production app.
 */
DEPRECATED_MSG_ATTRIBUTE("FBSDKTestUsersManager is deprecated and will be removed in the next major release")
NS_SWIFT_NAME(TestUsersManager)
@interface FBSDKTestUsersManager : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
  construct or return the shared instance
 @param appID the Facebook app id
 @param appSecret the Facebook app secret
 */
+ (instancetype)sharedInstanceForAppID:(NSString *)appID appSecret:(NSString *)appSecret
NS_SWIFT_NAME(shared(forAppID:appSecret:));

/**
  retrieve FBSDKAccessToken instances for test accounts with the specific permissions.
 @param arraysOfPermissions an array of permissions sets, such as @[ [NSSet setWithObject:@"email"], [NSSet setWithObject:@"user_birthday"]]
 if you needed two test accounts with email and birthday permissions, respectively. You can pass in empty nested sets
 if you need two arbitrary test accounts.
 @param createIfNotFound if YES, new test accounts are created if no test accounts existed that fit the permissions
 requirement
 @param handler the callback to invoke which will return an array of `FBAccessTokenData` instances or an `NSError`.
 If param `createIfNotFound` is NO, the array may contain `[NSNull null]` instances.


 If you are requesting test accounts with differing number of permissions, try to order
 `arrayOfPermissionsArrays` so that the most number of permissions come first to minimize creation of new
 test accounts.
 */
- (void)requestTestAccountTokensWithArraysOfPermissions:(NSArray<NSSet<NSString *> *> *)arraysOfPermissions
                                       createIfNotFound:(BOOL)createIfNotFound
                                      completionHandler:(nullable FBSDKAccessTokensBlock)handler
NS_SWIFT_NAME(requestTestAccountTokens(withPermissions:createIfNotFound:completionHandler:));

/**
  add a test account with the specified permissions
 @param permissions the set of permissions, e.g., [NSSet setWithObjects:@"email", @"user_friends"]
 @param handler the callback handler
 */
- (void)addTestAccountWithPermissions:(NSSet<NSString *> *)permissions
                    completionHandler:(nullable FBSDKAccessTokensBlock)handler;

/**
  remove a test account for the given user id
 @param userId the user id
 @param handler the callback handler
 */
- (void)removeTestAccount:(NSString *)userId
        completionHandler:(nullable FBSDKErrorBlock)handler;

/**
  Make two test users friends with each other.
 @param first the token of the first user
 @param second the token of the second user
 @param callback the callback handler
 */
- (void)makeFriendsWithFirst:(FBSDKAccessToken *)first
                      second:(FBSDKAccessToken *)second
                    callback:(nullable FBSDKErrorBlock)callback
NS_SWIFT_NAME(makeFriends(first:second:callback:));

@end

NS_ASSUME_NONNULL_END
