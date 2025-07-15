//
//  BDSDKUser.h
//  BDUniSDK
//
//  Created by suzheng on 2021/2/24.
//  Copyright © 2021 yangfei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BDSDKUser : NSObject
/// AccessToken
@property (nonatomic, copy) NSString *AccessToken;
/// Uid
@property (nonatomic, copy) NSString *Uid;
/// 帐号id
@property (nonatomic, copy) NSString *AccountID;
/// 是否是游客  1.是 0.不是
@property (nonatomic, copy) NSString *IsGuest;
@end

NS_ASSUME_NONNULL_END
