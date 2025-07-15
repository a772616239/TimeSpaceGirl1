//
//  SMPCQuickSDKGameRoleInfo.h
//  SMPCQuickSDK
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SMPCQuickSDKGameRoleInfo : NSObject

NS_ASSUME_NONNULL_BEGIN
@property (nonatomic,copy) NSString *serverId;         //服务器Id，必填
@property (nonatomic,copy) NSString *serverName;       //服务器名称，必填
@property (nonatomic,copy) NSString *gameRoleName;     //角色名，必填
@property (nonatomic,copy) NSString *gameRoleID;       //角色ID，必填
@property (nonatomic, copy) NSString * creatTime;      //角色创建时间(10位时间戳)，必填,没有传0
NS_ASSUME_NONNULL_END
@property (nonatomic,copy) NSString * _Nullable gameUserBalance;  //玩家虚拟货币余额，选填，默认值0
@property (nonatomic,copy) NSString * _Nullable vipLevel;         //玩家vip等级，选填，默认值0
@property (nonatomic,copy) NSString * _Nullable gameUserLevel;    //玩家等级，选填，默认值0
@property (nonatomic,copy) NSString * _Nullable partyName;        //公会名称，选填，默认空字符串
@property (nonatomic,copy) NSString * _Nullable partyId;        //公会id，选填，默认空字符串
@property (nonatomic, copy) NSString * _Nullable fightPower;     //战力，选填，默认值0
@property (nonatomic, copy) NSString * _Nullable professionId;     //角色职业id, 选填，默认值，空字符串
@property (nonatomic, copy) NSString * _Nullable profession;     //角色职业, 选填，默认值，空字符串
@property (nonatomic,copy) NSString * _Nullable roleGender;        //角色性别，选填，默认值男
@property (nonatomic,copy) NSString * _Nullable partyRoleId;        //公会角色id，选填，默认空字符串
@property (nonatomic,copy) NSString * _Nullable partyRoleName;        //公会角色名，选填，默认空字符串

@end
