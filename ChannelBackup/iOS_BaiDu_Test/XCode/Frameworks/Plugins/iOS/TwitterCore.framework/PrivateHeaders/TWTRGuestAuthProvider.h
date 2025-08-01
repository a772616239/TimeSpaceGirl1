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

@class TWTRAuthConfig;
@protocol TWTRAPIServiceConfig;
#import "TWTRAuthenticationProvider.h"

/**
 Manages activation of new guest tokens.

 @see TWTRAuthenticator
 */
@interface TWTRGuestAuthProvider : TWTRAuthenticationProvider

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithAuthConfig:(TWTRAuthConfig *)authConfig apiServiceConfig:(id<TWTRAPIServiceConfig>)apiServiceConfig accessToken:(NSString *)accessToken __attribute__((nonnull(1, 2)))NS_DESIGNATED_INITIALIZER;

@end
