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

/**
 This header is private to the Twitter Core SDK and not exposed for public SDK consumption
 */

#import <Foundation/Foundation.h>

FOUNDATION_EXTERN NSString *const TWTRNetworkingErrorDomain;
FOUNDATION_EXTERN NSString *const TWTRNetworkingUserAgentHeaderKey;
FOUNDATION_EXTERN NSString *const TWTRNetworkingStatusCodeKey;

#pragma mark - HTTP Headers
FOUNDATION_EXTERN NSString *const TWTRContentTypeHeaderField;
FOUNDATION_EXTERN NSString *const TWTRContentLengthHeaderField;
FOUNDATION_EXTERN NSString *const TWTRContentTypeURLEncoded;
FOUNDATION_EXTERN NSString *const TWTRAcceptEncodingHeaderField;
FOUNDATION_EXTERN NSString *const TWTRAcceptEncodingGzip;

/**
 * Internal API error codes
 * These error codes belong to the `TWTRAPIErrorDomain` error domain.
 * @see https://cgit.twitter.biz/birdcage/tree/macaw/macaw-core/src/main/scala/com/twitter/macaw/monorail/ApiError.scala
 */
// TODO: Move these to the public header because they can all surface to the developer?
typedef NS_ENUM(NSUInteger, TWTRTwitterAPIErrorCode) {
    /**
     *  "%s parameter is invalid"
     */
    TWTRTwitterAPIErrorInvalidParameter = 44,

    /**
     * "The email address associated with this account is invalid."
     */
    TWTRTwitterAPIErrorInvalidEmailAddress = 56,

    /**
     *  "Client is not permitted to perform this action"
     */
    TWTRTwitterAPIErrorClientNotPrivileged = 87,

    /**
     *  "Rate limit exceeded"
     */
    TWTRTwitterAPIErrorRateLimitExceeded = 88,

    /**
     *  "Account update failed: %s."
     */
    TWTRTwitterAPIErrorAccountUpdateFailure = 120,

    /**
     *  "Bad Authentication data."
     */
    TWTRTwitterAPIErrorCodeBadAuthenticationData = 215,

    /**
     *  "The login verification request has expired"
     */
    TWTRTwitterAPIErrorExpiredLoginVerificationRequest = 235,

    /**
     *  "The challenge response is incorrect"
     */
    TWTRTwitterAPIErrorIncorrectChallengeResponse = 236,

    /**
     *  "That is not an active login verification request ID"
     */
    TWTRTwitterAPIErrorMissingLoginVerificationRequest = 237,

    /**
     *  "Your signup request looks similar to automated requests from a computer. To protect our users from spam and other malicious activity, we can't create an account for you right now. Please try again later."
     */
    TWTRTwitterAPIErrorTieredActionSignupSpammerPhoneVerify = 240,

    /**
     *  "User is over the limit for login verification. Please try again in an hour."
     */
    TWTRTwitterAPIErrorOverLimitLoginVerificationStart = 245,

    /**
     *  "User is over the limit for login verification attempts. Please try signing in again."
     */
    TWTRTwitterAPIErrorOverLimitLoginVerificationAttempt = 246,

    /**
     *  "The login request is not yet approved."
     */
    TWTRTwitterAPIErrorNotYetApprovedLoginVerification = 253,

    /**
     *  "There was a failure sending the login verification request"
     */
    TWTRTwitterAPIErrorFailureSendingLoginVerificationRequest = 266,

    /**
     *  "User is not an SDK user"
     */
    TWTRTwitterAPIErrorUserIsNotSdkUser = 269,

    /**
     *  "We are unable to verify this phone number."
     */
    TWTRTwitterAPIErrorDeviceRegistrationGeneralError = 284,

    /**
     *  "This phone number is already registered."
     */
    TWTRTwitterAPIErrorDeviceAlreadyRegistered = 285,

    /**
     *  "We cannot send a text message to this phone number because its operator is not supported."
     */
    TWTRTwitterAPIErrorDeviceOperatorUnsupported = 286,

    /**
     *  "Device registration contains incorrect/unformatted input.
     */
    TWTRTwitterAPIErrorDeviceRegistrationInvalidInput = 300,

    /**
     *  "Device registration attempted on pending device."
     */
    TWTRTwitterAPIErrorDeviceDeviceRegistrationPending = 301,

    /**
     *  "Internal operation failed during device registration."
     */
    TWTRTwitterAPIErrorDeviceRegistrationOperationFailed = 302,

    /**
     *  "Phone number normalization failed during device registration"
     */
    TWTRTwitterAPIErrorDeviceRegistrationPhoneNormalizationFailed = 303,

    /**
     *  "Phone number country not detected upon normalization during device registration"
     */
    TWTRTwitterAPIErrorDeviceRegistrationPhoneCountryDetectionFailed = 304,
};
