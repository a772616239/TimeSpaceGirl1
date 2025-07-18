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
#import "TWTRTimelineDataSource.h"

@class TWTRAPIClient;
@class TWTRTimelineFilter;

NS_ASSUME_NONNULL_BEGIN

@interface TWTRCollectionTimelineDataSource : NSObject <TWTRTimelineDataSource>

/**
 *  The number of Tweets to request in each query to the Twitter Timeline API when fetching the next batch of Tweets.
 */
@property (nonatomic, readonly) NSInteger maxTweetsPerRequest;

/**
 *  ID of the collection.
 */
@property (nonatomic, copy, readonly) NSString *collectionID;

/*
 *  A filtering object that hides certain tweets.
 */
@property (nonatomic, copy, nullable) TWTRTimelineFilter *timelineFilter;

/**
 *  Convenience initializer.
 *
 *  @param collectionID (required) The ID of this collection. For example, the ID of this collection: https://twitter.com/TwitterMusic/timelines/393773266801659904 is @"393773266801659904"
 *
 *  @return An instance of TWTRCollectionTimelineDataSource or nil if any of the required parameters is missing.
 */
- (instancetype)initWithCollectionID:(NSString *)collectionID APIClient:(TWTRAPIClient *)client;

/**
 *  Designated initializer setting all supported values for Collection Timeline Data Source.
 *
 *  @param collectionID           (required) The Collection ID value. e.g. @"393773266801659904"
 *  @param client                 (required) The API client to use for all network requests.
 *  @param maxTweetsPerRequest    (optional) Number of Tweets to request per batch. A value of 0 uses the server default.
 *
 *  @return An instance of TWTRCollectionTimelineDataSource or nil if any of the required parameters are missing.
 */
- (instancetype)initWithCollectionID:(NSString *)collectionID APIClient:(TWTRAPIClient *)client maxTweetsPerRequest:(NSUInteger)maxTweetsPerRequest NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
