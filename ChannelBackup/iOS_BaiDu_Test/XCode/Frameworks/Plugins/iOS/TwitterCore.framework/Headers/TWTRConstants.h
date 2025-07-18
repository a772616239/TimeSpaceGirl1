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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The NSError domain of errors surfaced by the Twitter SDK.
 */
FOUNDATION_EXTERN NSString *const TWTRErrorDomain;

/**
 *  Error codes surfaced by the Twitter SDK.
 */
typedef NS_ENUM(NSInteger, TWTRErrorCode) {

    /**
     *  Unknown error.
     */
    TWTRErrorCodeUnknown = -1,

    /**
     *  Authentication has not been set up yet. You must call -[TWTRTwitter logInWithCompletion:] or -[TWTRTwitter logInGuestWithCompletion:]
     */
    TWTRErrorCodeNoAuthentication = 0,

    /**
     *  Twitter has not been initialized yet. Call +[Fabric with:@[TwitterKit]] or -[TWTRTwitter startWithConsumerKey:consumerSecret:].
     */
    TWTRErrorCodeNotInitialized = 1,

    /**
     *  User has declined to grant permission to information such as their email address.
     */
    TWTRErrorCodeUserDeclinedPermission = 2,

    /**
     *  User has granted permission to their email address but no address is associated with their account.
     */
    TWTRErrorCodeUserHasNoEmailAddress = 3,

    /**
     *  A resource has been requested by ID, but that ID was not found.
     */
    TWTRErrorCodeInvalidResourceID = 4,

    /**
     *  A request has been issued for an invalid URL.
     */
    TWTRErrorCodeInvalidURL = 5,

    /**
     *  Type mismatch in parsing JSON from the Twitter API.
     */
    TWTRErrorCodeMismatchedJSONType = 6,

    /**
     *  Fail to save to keychain.
     */
    TWTRErrorCodeKeychainSerializationFailure = 7,

    /**
     *  Fail to save to disk.
     */
    TWTRErrorCodeDiskSerializationError = 8,

    /**
     *  Error authenticating with the webview.
     */
    TWTRErrorCodeWebViewError = 9,

    /**
     *  A required parameter is missing.
     */
    TWTRErrorCodeMissingParameter = 10
};

/**
 *  The NSError domain of errors surfaced by the Twitter SDK during the login operation.
 */
FOUNDATION_EXTERN NSString *const TWTRLogInErrorDomain;

/**
 *  Error codes surfaced by the Twitter SDK with the `TWTRLogInErrorDomain` error domain.
 */
typedef NS_ENUM(NSInteger, TWTRLogInErrorCode) {

    /**
     * Unknown error.
     */
    TWTRLogInErrorCodeUnknown = -1,

    /**
     * User denied login.
     */
    TWTRLogInErrorCodeDenied = 0,

    /**
     * User canceled login.
     */
    TWTRLogInErrorCodeCancelled = 1,

    /**
     * No Twitter account found.
     */
    TWTRLogInErrorCodeNoAccounts = 2,

    /**
     * Reverse auth with linked account failed.
     */
    TWTRLogInErrorCodeReverseAuthFailed = 3,

    /**
     *  Refreshing session tokens failed.
     */
    TWTRLogInErrorCodeCannotRefreshSession = 4,

    /**
     *  No such session or session is not tracked
     *  in the associated session store.
     */
    TWTRLogInErrorCodeSessionNotFound = 5,

    /**
     * The login request failed.
     */
    TWTRLogInErrorCodeFailed = 6,

    /**
     * The system account credentials are no longer valid and the
     * user will need to update their credentials in the Settings app.
     */
    TWTRLogInErrorCodeSystemAccountCredentialsInvalid = 7,

    /**
     *  There was no Twitter iOS app installed to attemp
     *  the Mobile SSO flow.
     */
    TWTRLoginErrorNoTwitterApp = 8,
};

NS_ASSUME_NONNULL_END
