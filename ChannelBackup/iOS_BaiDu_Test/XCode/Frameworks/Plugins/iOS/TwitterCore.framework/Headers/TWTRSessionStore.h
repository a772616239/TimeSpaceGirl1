/*
 * Copyright (C) 2017 Twitter, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

@class TWTRAuthConfig;
@class TWTRGuestSession;
@class TWTRSession;
@protocol TWTRAuthSession;
@protocol TWTRAPIServiceConfig;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - TWTRSessionRefreshingStore Protocol

/**
 *  Completion block called when a session refresh succeeds or fails.
 *
 *  @param refreshedSession The refreshed session
 *  @param error            Error that will be non nil if the refresh request failed
 */
typedef void (^TWTRSessionStoreRefreshCompletion)(id _Nullable refreshedSession, NSError *_Nullable error);

/**
 *  Protocol for session stores that can refresh expired sessions.
 */
@protocol TWTRSessionRefreshingStore <NSObject>

/**
 *  Refresh an expired session.
 *
 *  @param sessionClass The class of the session
 *  @param sessionID    ID of the session wherever applicable e.g. `userID` if it's a user session.
 *  @param completion   The completion block to call when the refresh request succeeds or fails.
 */
- (void)refreshSessionClass:(Class)sessionClass sessionID:(nullable NSString *)sessionID completion:(TWTRSessionStoreRefreshCompletion)completion;

/**
 *  Determines whether the given session has expired.
 *
 *  @param session  The session to check for expiration
 *  @param response API request response to check for expiration
 *
 *  @return Whether the session has expired.
 */
- (BOOL)isExpiredSession:(id)session response:(NSHTTPURLResponse *)response;

/**
 *  Determines whether the given session has expired based on a given error.
 *
 *  @param session  The session to check for expiration
 *  @param error API request error to check for expiration
 *
 *  @return Whether the session has expired.
 */
- (BOOL)isExpiredSession:(id)session error:(NSError *)error;

@end

#pragma mark - TWTRUserSessionStore Protocol

/**
 *  Completion block called when a user session saved to the session store or fails.
 *
 *  @param session The saved session
 *  @param error   Error that will be non nil if the save request fails.
 */
typedef void (^TWTRSessionStoreSaveCompletion)(id<TWTRAuthSession> _Nullable session, NSError *_Nullable error);

/**
 *  Completion block called when fetching all stored user sessions completes or fails.
 *
 *  @param sessions All stored user sessions or empty array if there are no user sessions found.
 */
typedef void (^TWTRSessionStoreBatchFetchCompletion)(NSArray *sessions);

/**
 *  Completion block to call when the session is deleted or fails.
 *
 *  @param session The deleted session or nil if none was found for the user.
 */
typedef void (^TWTRSessionStoreDeleteCompletion)(id<TWTRAuthSession> _Nullable session);

/**
 *  Protocol for session store that manages user sessions.
 */
@protocol TWTRUserSessionStore <NSObject>

/**
 *  Saves the existing session to the store after validations.
 *
 *  @param session    The user session to save
 *  @param completion Completion block to call when the save request succeeds or fails
 */
- (void)saveSession:(id<TWTRAuthSession>)session completion:(TWTRSessionStoreSaveCompletion)completion;

/**
 *  Fetches the user session for for the given auth tokens and saves it to the store after validations.
 *
 *  @param authToken       The existing authToken to use for authentication.
 *  @param authTokenSecret The existing authTokenSecret to use for authentication.
 *  @param completion      Completion block to call when the save request succeeds or fails
 */
- (void)saveSessionWithAuthToken:(NSString *)authToken authTokenSecret:(NSString *)authTokenSecret completion:(TWTRSessionStoreSaveCompletion)completion;

/**
 *  Checks to see if the user is logged in and has a saved session.
 *
 *  @param userID   The user ID to fetch session for.
 */
- (nullable id<TWTRAuthSession>)sessionForUserID:(NSString *)userID;

/**
 *  Retrieve all logged in user sessions in ascending order of last saved date
 *
 *  @note This is a blocking call.
 */
- (NSArray *)existingUserSessions;

/**
 *  Returns YES if there are existing user sessions.
 *
 *  @note This is a blocking call.
 */
- (BOOL)hasLoggedInUsers;

/**
 *  Retrieves the last logged in user session.
 *
 *  @return The last logged in user session.
 */
- (nullable id<TWTRAuthSession>)session;

/**
 *  Deletes the local Twitter user session from this app. This will not remove the system Twitter account nor make a network request to invalidate the session.
 *
 *  @param userID ID of the user to log out
 */
- (void)logOutUserID:(NSString *)userID;

@end

#pragma mark - TWTRGuestSessionStore Protocol

/**
 *  Completion block called when retrieving a guest session succeeds or fails.
 *
 *  @param guestSession The retrieved guest session
 *  @param error        Error that will be non nil if the save request fails.
 */
typedef void (^TWTRSessionGuestLogInCompletion)(TWTRGuestSession *_Nullable guestSession, NSError *_Nullable error);

/**
 *  Protocol for session stores that can manage guest sessions.
 */
@protocol TWTRGuestSessionStore <NSObject>

/**
 *  Log in as a guest user and return the guest session. This can be used when the user is not a Twitter user.
 *
 *  @param completion Completion block to call when the authentication succeeds or fails.
 *
 *  @warning This method assumes your application, as indicated by the `consumerKey` and `consumerSecret` in the `authConfig`, has been whitelisted for guest authentication.
 */
- (void)fetchGuestSessionWithCompletion:(TWTRSessionGuestLogInCompletion)completion;

@end

#pragma mark - Composite TWTRSessionStore Protocol

/**
 *  Convenience composite protocol of a store that handles user, guest, and refreshable sessions.
 */
@protocol TWTRSessionStore <TWTRUserSessionStore, TWTRGuestSessionStore, TWTRSessionRefreshingStore>

/**
 *  Returns the store's auth config.
 */
@property (nonatomic, readonly) TWTRAuthConfig *authConfig;

@end

#pragma mark - Concrete Session Store Class

/**
 *  Concrete implementation of <TWTRSessionStore>. This session store supports fetching and storage of
 *  user and guest sessions. In addition, the session store also supports refreshing of such sessions when they expire.
 *
 *  @warning Instances of the session manager at the same path are not synchronized. The session store
 *  will simply choose the latest version in the case of conflicts.
 */
@interface TWTRSessionStore : NSObject <TWTRSessionStore>

- (instancetype)init NS_UNAVAILABLE;

/**
 * Provides a mechanism for reloading the session store. This method will force the session store
 * to find any sessions that may have been saved by another session store or application that is
 * using the same keychain access groups.
 *
 * Most applications will not need to call this method. You may need to call this method if you are
 * using multiple stores within your application and you need to synchronize when one writes to the
 * store. The more likely case for needing to call this method is if you are sharing credentials
 * between applications. In this situation you will want to call this method when the application
 * comes back to the foreground.
 *
 * This method does not need to be called when the store is created because this process happens
 * by default at time of instantiation.
 *
 * You should avoid calling this method if you do not have a specific reason to do so, like the reasons
 * mentioned above as this method does cause disk I/O and multiple calls can cause performance problems.
 */
- (void)reloadSessionStore;

/**
 *  Sets a local string which can be used to verify the auth token using
 *  isValidOauthToken:
 */
- (void)saveOauthToken:(NSString *)token;

/**
 *  If saveOauthToken is called then this will compare the set to the token passed by the token parameter.
 *  This is used to verify the token generated from the oauth/request_token request after a URL has been passed
 *  back from web authenticatoin.
 *
 *  Returns YES is the token string matches the internal OAuth token.
 */
- (BOOL)isValidOauthToken:(NSString *)token;
@end

NS_ASSUME_NONNULL_END
