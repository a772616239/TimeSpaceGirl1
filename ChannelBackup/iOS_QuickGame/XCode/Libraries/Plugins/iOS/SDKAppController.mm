#import "UnityAppController.h"
#import <JySDK/JySDKManager.h>


// sdk产品code
#define SDK_PRODUCT_CODE @"35830695725172284797896935402546"

@interface SDKAppController : UnityAppController

@end

IMPL_APP_CONTROLLER_SUBCLASS(SDKAppController)
@implementation SDKAppController

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    //NSLog(@"[UnityOverrideAppDelegate application:%@ didFinishLaunchingWithOptions:%@]", application, launchOptions);
    BOOL result = [super application:application didFinishLaunchingWithOptions:launchOptions];
    
    //初始化sdk
    [JySDKManager initWithProductCode:SDK_PRODUCT_CODE completion:^(Status_CODE retCode) {
        if (retCode == kInitSuccess) {
            NSLog(@"初始化成功");
        } else {
            NSLog(@"初始化失败，错误码：%d",retCode);
        }
    }];
//    [JySDKManager setNeedAutoLogin:YES];
    [JySDKManager initQQLogin:@"1112252368" universalLink:@"universalLink"];
//    [JySDKManager initWxLogin:@"wx59f50ca79af3635b" appSecret:@"59b13fad3a8e985471b395e7d3f64796" universalLink:@"https://protocol.weiweihudong.cn/apple-app-site-association/"];
    
    
    //微信分享结果回调
    [JySDKManager wxShareResult:^(NSDictionary * _Nonnull resultDic) {
        NSString * msg = [resultDic objectForKey:@"msg"];
        if ([msg isEqualToString:@"succ"]) {
        NSLog(@"分享成功");
        }
        else if ([msg isEqualToString:@"cancel"]) {
        NSLog(@"用户取消分享");
        } else {
        NSLog(@"分享失败");
        }
    }];
    
    [JySDKManager completeRealName:^(BOOL isComplete, NSInteger age, NSInteger source) {
        NSLog(@"%@年龄%ld",isComplete ? @"完成实名认证":@"未完成实名认证", (long)age);
    }];
    
    [JySDKManager configGuestLoginShow:NO];
    
    
    return result;
}

// 微信QQ授权登录回调接口
- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler
{
    return [JySDKManager application:application continueUserActivity:userActivity restorationHandler:restorationHandler];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    return [JySDKManager application:app openURL:url options:options];
}
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [JySDKManager application:application openURL:url sourceApplication:sourceApplication annotation:annotation];
}

@end
