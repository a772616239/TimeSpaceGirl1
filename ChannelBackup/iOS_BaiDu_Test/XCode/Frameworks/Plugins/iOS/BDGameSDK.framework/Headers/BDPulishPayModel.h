//
//  BDPulishPayModel.h
//  BDUniSDK
//
//  Created by suzheng on 2021/1/8.
//  Copyright © 2021 yangfei. All rights reserved.
//  支付model

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BDPulishPayModel : NSObject

/// apple商品id 
@property (nonatomic, copy) NSString *productId;

/// cp订单号
@property (nonatomic, copy) NSString *cooperatorOrderSerial;

/// 角色信息 格式事例：{\"GameRegion\":\"北方大区\",\"GameRegionId\":\"123_njjj\",\"GameRoleId\":\"123sxdw\",\"GameRoleName\":\"赵老哥\"}
@property (nonatomic, copy) NSString *gameInfo;

/// 回调的url
@property (nonatomic, copy) NSString *callbackURL;
@end

NS_ASSUME_NONNULL_END
