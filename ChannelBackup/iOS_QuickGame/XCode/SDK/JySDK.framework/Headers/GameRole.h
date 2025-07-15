//
//  GameRole.h
//  JySDKManager
//
//  Created by 96541254558447 on 2018/6/21.
//  Copyright © 2018年 xiaoxiao. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GameRole : NSObject

@property (copy,nonatomic) NSString *roleId;               //角色id  必填
@property (copy,nonatomic) NSString *role_name;            //角色名称  必填
@property (copy,nonatomic) NSString *serverId;              //区服id     必填
@property (copy,nonatomic) NSString *sv_name;              //区服名称     必填
@property (copy,nonatomic) NSString *role_level;           //角色等级    选填
@property (copy,nonatomic) NSString *vipLevel;             //vip等级    选填
@property (copy,nonatomic) NSString *role_power;             //角色战力值   选填
@property (copy,nonatomic) NSString *gameRoleBalance;      //角色余额    选填
@property (copy,nonatomic) NSString *partyName;            //工会名称    选填
- (void)setValues:(GameRole *)role;

@end
