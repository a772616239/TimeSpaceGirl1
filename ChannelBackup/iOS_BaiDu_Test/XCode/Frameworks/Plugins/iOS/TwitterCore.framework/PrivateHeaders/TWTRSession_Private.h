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

#import <TwitterCore/TWTRSession.h>

@interface TWTRSession ()

/**
 * Returns YES if the dictionary represents a valid dictionary that can
 * safely be used to instantiate the TWTRSession object.
 */
+ (BOOL)isValidSessionDictionary:(NSDictionary *)dictionary;

/**
 *  Returns a new dictionary of the stored tokens and user context.
 */
- (NSDictionary *)dictionaryRepresentation;

@end
