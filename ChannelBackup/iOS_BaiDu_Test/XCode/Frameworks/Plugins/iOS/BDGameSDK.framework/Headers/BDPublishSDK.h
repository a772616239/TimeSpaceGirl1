//
//  BDPublishSDK.h
//  BDPublishSDK
//
//  Created by suzheng on 2020/12/14.
//

#import <Foundation/Foundation.h>
#import "BDPulishPayModel.h"
#import "BDSDKUser.h"
#import "BDSDKShare.h"
@import UIKit;

typedef NS_ENUM(NSUInteger, BDPublishPayStatus) {
    BDPublishPaySuccess   = 20000,
    BDPublishPayFail      = 20001,
    BDPublishPayCancel    = 20002,
    BDPublishPayOrderFail = 20003,
    BDPublishPayUnkown    = 20004
};

typedef NS_ENUM(NSUInteger, BDPublishBindStatus) {
    BDPublishBindSuccess    = 40000,
    BDPublishBindNotBind    = 40001
};

typedef NS_ENUM(NSUInteger, BDPublishSharePlatFormType) {
    BDPublishSharePlatFormFacebook,
    BDPublishSharePlatFormGoogle
};

typedef NS_ENUM(NSUInteger, BDBindOprationType) {
    BDBindOprationTypeBindAccount,
    BDBindOprationTypeChangePhoneNumber,
    BDBindOprationTypeDisabled,
};

extern NSString * _Nullable const BDLogEventParamKey_appsflyer; // af打点参数key
extern NSString * _Nullable const BDLogEventParamKey_firebase; // firebase打点参数key

@class BDPublishSDK;
NS_ASSUME_NONNULL_BEGIN

@protocol BDPublishSDKDelegate <NSObject>

@optional
/// 登录完成回调
/// @param publishSDK BDPublishSDK
/// @param user user
- (void)bd_didLogin:(BDPublishSDK *)publishSDK
               user:(nullable BDSDKUser *)user
              error:(nullable NSError *)error;

/// 支付完成回调
/// @param publishSDK BDPublishSDK
- (void)bd_didPay:(BDPublishSDK *)publishSDK payResult:(BDPulishPayModel *)payResult;

/// 绑定完成回调
/// @param publishSDK BDPublishSDK
- (void)bd_didBind:(BDPublishSDK *)publishSDK;

/// 分享完成回调
/// @param shareResult BDSDKShare
- (void)bd_didShare:(BDPublishSDK *)publishSDK
        shareResult:(nullable BDSDKShare *)shareResult
              error:(nullable NSError *)error;

@end

@protocol BDBusinessObserver <NSObject>

@required
/// 重新登录回调
/// @param publishSDK BDPublishSDK
- (void)bd_relogin:(BDPublishSDK *)publishSDK;

/// 处理支付掉单
- (void)bd_dealLostOrder:(BDPublishSDK *)publishSDK payResult:(BDPulishPayModel *)payResult;

@end


@interface BDPublishSDK : NSObject
+ (instancetype)sharedInstance;


#pragma mark - init
/// SDK注册方法
/// @param appkey appkey
/// @param appId appId
/// @param launchOptions launchOptions
/// @param application application
- (void)bd_registWithAppKey:(NSString *)appkey appId:(NSString *)appId Options:(NSDictionary *)launchOptions application:(UIApplication *)application;

/// 处理第三方跳转
/// @param application application
/// @param url openURL
/// @param options options
- (BOOL)bd_application:(UIApplication *)application
               openURL:(NSURL *)url
               options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options;


/// 处理第三方跳转 （iOS 9.0之前版本调用）
/// @param application application
/// @param url openURL
/// @param sourceApplication sourceApplication
/// @param annotation annotation
- (BOOL)bd_application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(nullable NSString *)sourceApplication
         annotation:(nullable id)annotation;


#pragma mark - 登录相关
/// 调起登录
- (void)bd_login;
/// 查询是否登录
- (BOOL)bd_isLogin;
/// 查询当前账号是否可以切换
- (BOOL)bd_canSwithAccount;
/// 切换帐号
- (void)bd_switchAccount;

/// 查询用户信息
- (BDSDKUser *)bd_queryLoginInfo;

#pragma mark - 支付相关

/// 调起支付
/// @param model 支付model
- (void)bd_payWithPayModel:(BDPulishPayModel *)model;

#pragma mark - 绑定手机号相关
/// 查询绑定业务
- (BDBindOprationType)bd_queryBindOperationType;

/// 调起绑定
- (void)bd_bindAccount;

/// 更改绑定账号
- (void)bd_changeBindAccount;

#pragma mark - report
// 打点
- (void)bd_logEvent:(NSString *)eventName withValues:(NSDictionary * _Nullable)values;

/// 角色信息上报
/// @param playerInfo playerInfo
/// @param isFirstCreate 1 是 0 不是
- (void)bd_reportPlayerInfo:(NSDictionary *)playerInfo isFirstCreate:(BOOL)isFirstCreate;

#pragma mark - AIHelp
// 调起客服系统
- (void)bd_showHelpConversation;

// 调起FAQ
- (void)bd_showFAQ;

// 调起运营模块
- (void)bd_showOperation;

#pragma mark - observer
/// 添加全局业务观察者
/// @param observer observer
- (void)addBussinessObserver:(id<BDBusinessObserver>)observer;

#pragma mark - other
/// 获取设备uuid
- (NSString *)bd_getDeviceId;


#pragma mark - 分享
/// 分享照片
- (void)bd_shareWithPhoto:(UIImage *)photo
            sharePlatform:(BDPublishSharePlatFormType)platform
                 delegate:(id <BDPublishSDKDelegate>)delegate;

/// 分享链接
- (void)bd_shareWithLink:(NSString *)linkURLString
           sharePlatform:(BDPublishSharePlatFormType)platform
                delegate:(id <BDPublishSDKDelegate>)delegate;

#pragma mark - property

@property (nonatomic, weak) id <BDPublishSDKDelegate> delegate;

/// 支付状态
@property (nonatomic, assign, readonly) BDPublishPayStatus payStatus;

/// 绑定状态
@property (nonatomic, assign, readonly) BDPublishBindStatus bindStatus;

/// 调试模式
@property (nonatomic, assign) BOOL debugMode;

@end

NS_ASSUME_NONNULL_END
