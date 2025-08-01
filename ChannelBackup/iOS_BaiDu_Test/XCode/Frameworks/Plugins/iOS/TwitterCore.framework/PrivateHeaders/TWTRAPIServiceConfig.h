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

@protocol TWTRAPIServiceConfig <NSObject>

@property (nonatomic, readonly, copy) NSString *apiHost;
@property (nonatomic, readonly, copy) NSString *apiScheme;

/**
 * A unique name to assign to this service. It is recommended
 * that reverse dns be used to make the name unique.
 */
@property (nonatomic, readonly, copy) NSString *serviceName;

@end

FOUNDATION_EXTERN NSURL *TWTRAPIURLWithPath(id<TWTRAPIServiceConfig> apiServiceConfig, NSString *path);

FOUNDATION_EXTERN NSURL *TWTRAPIURLWithParams(id<TWTRAPIServiceConfig> apiServiceConfig, NSString *path, NSDictionary *params);
