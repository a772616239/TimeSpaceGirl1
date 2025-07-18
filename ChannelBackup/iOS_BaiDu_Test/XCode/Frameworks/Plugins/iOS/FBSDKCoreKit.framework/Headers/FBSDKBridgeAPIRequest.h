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

#import "FBSDKCopying.h"
#import "FBSDKBridgeAPIProtocol.h"
#import "FBSDKBridgeAPIProtocolType.h"

/**
 Internal Type exposed to facilitate transition to Swift.
 API Subject to change or removal without warning. Do not use.

 @warning UNSAFE - DO NOT USE
 */
@protocol FBSDKBridgeAPIRequestProtocol <NSObject, NSCopying>

@property (nonatomic, copy, readonly) NSString *scheme;
@property (nonatomic, copy, readonly) NSString *actionID;
@property (nonatomic, copy, readonly) NSString *methodName;
@property (nonatomic, assign, readonly) FBSDKBridgeAPIProtocolType protocolType;
@property (nonatomic, readonly, strong) id<FBSDKBridgeAPIProtocol> protocol;

- (NSURL *)requestURL:(NSError *__autoreleasing *)errorRef;

@end

/**
 Internal Type exposed to facilitate transition to Swift.
 API Subject to change or removal without warning. Do not use.

 @warning UNSAFE - DO NOT USE
 */
NS_SWIFT_NAME(BridgeAPIRequest)
@interface FBSDKBridgeAPIRequest : NSObject <FBSDKCopying, FBSDKBridgeAPIRequestProtocol>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (instancetype)bridgeAPIRequestWithProtocolType:(FBSDKBridgeAPIProtocolType)protocolType
                                          scheme:(NSString *)scheme
                                      methodName:(NSString *)methodName
                                   methodVersion:(NSString *)methodVersion
                                      parameters:(NSDictionary *)parameters
                                        userInfo:(NSDictionary *)userInfo;

@property (nonatomic, copy, readonly) NSString *actionID;
@property (nonatomic, copy, readonly) NSString *methodName;
@property (nonatomic, copy, readonly) NSString *methodVersion;
@property (nonatomic, copy, readonly) NSDictionary *parameters;
@property (nonatomic, assign, readonly) FBSDKBridgeAPIProtocolType protocolType;
@property (nonatomic, copy, readonly) NSString *scheme;
@property (nonatomic, copy, readonly) NSDictionary *userInfo;

- (NSURL *)requestURL:(NSError *__autoreleasing *)errorRef;

@end

#endif
