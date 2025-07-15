//
//  CzParam.h
//  JySDKManager
//
//  Created by 96541254558447 on 2018/6/21.
//  Copyright © 2018年 xiaoxiao. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GoodParam : NSObject

@property (copy,nonatomic) NSString         *productId;         //productID
@property (copy,nonatomic) NSString         *productName;       //商品名称 必填
@property (copy,nonatomic) NSString         *productDesc;       //商品描述 可选
@property (assign,nonatomic) float          price;              //商品价格 必填  单位：元
@property (copy,nonatomic) NSString         *orderNo;           //游戏方订单号 string[64] 必填、必须唯一
@property (copy,nonatomic) NSString         *url;               //回调通知地址 string[200] 可选  客户端配置优先
@property (copy,nonatomic) NSString         *extras;            //附带参数 string[500] 可选，可作透传， 注意：扩展字段请勿传特殊符号，如果无法避免建议先进行base64编码后再传



@end
