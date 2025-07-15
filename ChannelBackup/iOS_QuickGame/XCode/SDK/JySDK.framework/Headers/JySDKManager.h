//
//  JySDKManager.h
//  JySDKManager
//
//  Created by 96541254558447 on 2018/6/9.
//  Copyright © 2018年 xiaoxiao. All rights reserved.
//

#define Version @"2.5.2"


#import <Foundation/Foundation.h>
#import "GameRole.h"
#import "GoodParam.h"

///事件状态码
typedef enum {
    kErrorNone                 = 1000,          //事件成功
    kInitSuccess               = 2000,          //初始化成功
    kInitFail                  = 2001,          //初始化失败
    KOrderSuccess              = 3000,          //充值成功
    KOrderFail                 = 3001,          //充值失败
    KOrderCancel               = 3002,          //充值取消
    KOrderUnkown               = 3003,          //正在购买中或者非用户取消的购买失败
    KOrderRestoreSucc          = 3004,          //恢复购买成功
    KOrderRestoreFail          = 3005,          //恢复购买失败
} Status_CODE;
///登录方式
typedef enum {
    LOGIN_Account       = 1,                    //账号密码
    LOGIN_Phone         = 2,                    //手机号
    LOGIN_Guest         = 3,                    //游客登录
    LOGIN_Apple         = 4,                    //苹果
    LOGIN_WX            = 5,                    //微信
    LOGIN_QQ            = 6,                    //手Q
    LOGIN_OneKey        = 7,                    //阿里云一键登录
    LOGIN_GameCenter    = 8,                    //GameCenter
    LOGIN_UCloudLogin   = 9,                    //UCloud一键登录
    LOGIN_Tap           = 10,                   //TapTap登录
} LOGIN_TYPE;

typedef void (^KInitResultBlock)(Status_CODE retCode);
typedef void (^KLoginResultBlock)(NSDictionary *resultDic);
typedef void (^KPyResultBlock)(NSDictionary *resultDic);
typedef void (^kOtherResultBlock)(NSDictionary *resultDic);
typedef void (^kLogoutBlock)(void);
typedef void (^kResultBlock)(NSString * result);
typedef void (^kDeviceBindAccountBlock)(BOOL isDeviceBindAccount);
typedef void (^kPrivacyBlock)(BOOL isAgreed);

/**
 iscomplete 是否完成实名认证
 age 实名认证后返回实际年龄否则返回0
 source 1登录调起实名认证2用户主动调起3支付调起4用户中心进入5登录防沉迷进入
 */
typedef void (^realNameResult)(BOOL isComplete, NSInteger age, NSInteger source);
typedef void (^KLoginFailResult)(NSString * message);
@protocol KAcountDelegate <NSObject>
@required
/**
 *  退出当前账号
 *  LogoutType  退出账号方式 1.用户个人中心手动退出账号 2.修改密码成功退出当前账号 3.销毁账号成功
 */
- (void)userLogout:(NSDictionary *)resultDic;
@optional
/**
 *  新注册账号(注册账号时回调)
 */
- (void)userRegister:(NSString *)uid;
@optional
/**
 *  点击了客服按钮
 */
- (void)outService:(NSDictionary *)resultDic;

@end

@interface JySDKManager : NSObject

/**
 *  处理账户相关的代理
 */
@property (nonatomic, weak) id<KAcountDelegate> acountDelegate;

#pragma mark - 单例对象
/**
 *	@brief  单例对象
 *
 **/
+ (JySDKManager *)defaultManager;

#pragma - mark SDK初始化
/**
 *	@brief  SDK平台初始化方法（必接）
 *  @param  productCode   产品code
 *  @param  completion    初始化结果回调
 *
 **/
+ (void)initWithProductCode:(NSString *)productCode completion:(KInitResultBlock)completion;
#pragma - mark 登录
/**
 * @brief 调起登录界面（必接）
 * @param completion      登录结果回调
 */
+ (void)login:(KLoginResultBlock)completion;
+ (void)loginWithSuccBlock:(KLoginResultBlock)success failBlock:(KLoginFailResult)failure;
/** 静默登录，不显示登录界面
 * @param isShowFloatMenu 是否显示浮标
 * @param success 登录成功回调
 * @param failure 登录失败回调
 */
+ (void)loginAsGuestWithFloatMenuShow:(BOOL)isShowFloatMenu successBlock:(KLoginResultBlock)success failBlock:(KLoginFailResult)failure;
/**
 *    设置区服角色信息，上传角色信息（必接）
 */
+ (void)updateRoleInfo:(GameRole *)roleInfo;
/** 配置是否显示游客试玩  YES显示NO隐藏默认显示*/
+ (void)configGuestLoginShow:(BOOL)show;
#pragma - mark 退出账号
/**
 * 退出登录，退出SDK账号，隐藏悬浮球
 */
+ (void)logout:(kLogoutBlock)block;

#pragma - mark 购买商品
/**
 *	@brief  购买接口（必接）
 *
 *  @param  param           充值参数
 *  @param  completion      购买结果回调
 *
 **/
+ (void)getGoodWithParam:(GoodParam *)param completion:(KPyResultBlock)completion;

/**
 恢复已购买的非消耗品或者自动订阅商品
 */
+ (void)restoreNonConsumptionProducts:(KPyResultBlock)resultBlock;

/**
 *	调起个人中心页面
 **/
+ (void)showUserCenter;


/**
 *  获取用户id。如未登录，返回空。
 */
+ (NSString *)userId;

/**
 *  获取用户登录账号。如未登录，返回空。
 */
+ (NSString *)userAccount;

/**
 *  获取用户校验码，用于到服务器端验证用户真实性。
 */
+ (NSString *)userToken;

/**
 *  用户是否是游客,请先判断用户是否有登录
 */
+ (BOOL)isGuest;
/**
 *  用户是否是新注册用户,请先判断用户是否有登录
 */
+ (BOOL)isNewUser;
/**
 *  用户是否是成年人,请先判断用户是否有登录
 */
+ (BOOL)isAdult;
/** 获取当前登录用户年龄 */
+ (NSString *)getCurrentUserAge;
/** 用户是否已实名认证 */
+ (BOOL)isRealName;
/**
 *  是否有用户登录
 */
+ (BOOL)isLogined;
/**
 *  获取用户登录方式
 */
+ (LOGIN_TYPE)userLoginType;
/**
 *  获取设备id
 */
+ (NSString *)getDeviceId;
/** 显示浮悬窗 isLeft:是否在左边 centery:中心点y值*/
+ (void)showFloatMenuBtnWithIsLeft:(BOOL)isleft andWithCenterY:(CGFloat)centery;
/** 隐藏悬浮窗*/
+ (void)hideFloatMenuBtn;

/** 显示防沉迷界面*/
+ (void)showAntiIndulgeTipViewControllerWithTips:(NSString *)tips;
/** 显示用户隐私弹窗， 用户同意返回YES，不同意返回NO*/
+ (void)showPrivacyViewController:(kPrivacyBlock)isAgreed;

/**销毁当前账号 */
+ (void)deleteCurrentAccount;

/** 微信QQ授权登录回调方法， 带第三方登录必接*/
+ (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler;
+ (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary *)options;
+ (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation;

/** 设置悬浮窗隐藏时透明度alpha为0-1，0透明1不透明*/
+ (void)configFloatAlpha:(CGFloat)alpha;
/** 设置设置手机号登录优先*/
+ (void)setPhoneLoginFirst;
/** 设置是否自动登录，默认自动登录YES*/
+ (void)setNeedAutoLogin:(BOOL)autoLogin;
/** 设置是否允许模拟器登录，默认允许YES*/
+ (void)setSimuLatorLogin:(BOOL)canLogin;
/** 进入实名认证 */
+ (void)enterRealName;
/** 实名认证回调须在实名认证之前设置 */
+ (void)completeRealName:(realNameResult)resultBlock;
/**
 *  @brief  检查设备是否绑定了账号
 *  @param  completion    设备是否绑定账号结果回调：YES:已绑定账号，NO:未绑定账号
 *
 **/
+ (void)getDeviceBindAccountResult:(kDeviceBindAccountBlock)completion;
/** 初始化微信参数*/
+ (void)initWxLogin:(NSString *)wxAppId appSecret:(NSString *)appSecret universalLink:(NSString *)universalLink;

/// 微信分享文本
/// @param text 要分享的文本
/// @param shareTo 分享到哪里，传字符串 0 聊天界面，1 朋友圈，2 收藏，3 指定联系人
/// @param completion 分享结果回调
+ (void)wxShareWithText:(NSString *)text
                 shareTo:(NSString *)shareTo
             shareResult:(kOtherResultBlock)completion;

/// 微信分享图片
/// @param image 要分享的图片对象 UIImage
/// @param shareTo 分享到哪里，传字符串 0 聊天界面，1 朋友圈，2 收藏，3 指定联系人
/// @param completion 分享结果回调
+ (void)wxShareWithImage:(UIImage *)image
                 shareTo:(NSString *)shareTo
             shareResult:(kOtherResultBlock)completion;

/// 微信分享视频
/// @param title 标题
/// @param videoUrl 视频链接
/// @param description 描述信息
/// @param thumbImage 缩略图链接
/// @param shareTo 分享到哪里，传字符串 0 聊天界面，1 朋友圈，2 收藏，3 指定联系人
/// @param completion 分享结果回调
+ (void)wxShareWithTitle:(NSString *)title
                videoUrl:(NSString *)videoUrl
             description:(NSString *)description
              thumbImage:(NSString *)thumbImage
                 shareTo:(NSString *)shareTo
             shareResult:(kOtherResultBlock)completion;
/// 微信分享网页
/// @param title 标题
/// @param webpageUrl 网页链接
/// @param description 描述信息
/// @param thumbImage 缩略图链接
/// @param shareTo 分享到哪里，传字符串 0 聊天界面，1 朋友圈，2 收藏，3 指定联系人
/// @param completion 分享结果回调
+ (void)wxShareWithTitle:(NSString *)title
              webpageUrl:(NSString *)webpageUrl
             description:(NSString *)description
              thumbImage:(NSString *)thumbImage
                 shareTo:(NSString *)shareTo
             shareResult:(kOtherResultBlock)completion;

/// 监听分享结果回调，用于游戏自己实现了微信分享，可通过该接口监听分享结果
/// @param resultBlock <#resultBlock description#>
+ (void)wxShareResult:(kOtherResultBlock)resultBlock;
// 不显示微信登录，只保留微信分享
+ (void)closeWxLogin;
/** 初始化qq参数*/
+ (void)initQQLogin:(NSString *)qqAppId universalLink:(NSString *)universalLink;
+ (NSString *)userThirdName;
+ (NSString *)userThirdImage;
/** 移除SDK内购监听若要自行实现内购请执行该代码否则千万不要执行*/
+ (void)removeListener;

/** 登录按钮显示排序 100 手机, 200 微信, 300 qq, 400 游客, 500 apple, 600 一键登录, 800 gamecenter,
 *  @param array 登录方式排序数组
    调用示例：[JySDKManager sortLoginBtn:@[@(200), @(300), @(100), @(400), @(500)]];
 */
+ (void)sortLoginBtn:(NSArray *_Nullable)array;


@end



