#import "UnityAppController.h"
#import <SMPCQuickSDK/SMPCQuickSDK.h>
@interface SDKAppController : UnityAppController

@end

IMPL_APP_CONTROLLER_SUBCLASS(SDKAppController)
@implementation SDKAppController

- (void)smpcQpInitResult:(NSNotification *)notify {
    NSLog(@"init result:%@",notify);
    NSDictionary *userInfo = notify.userInfo;
    int errorCode = [userInfo[kSmpcQuickSDKKeyError] intValue];
    switch (errorCode) {
        case SMPC_QUICK_SDK_ERROR_NONE:
        {
            NSLog(@"初始化成功");
        }
            break;
        case SMPC_QUICK_SDK_ERROR_INIT_FAILED:
        default:
        {
            //初始化失败
            NSLog(@"渠道初始化失败");
        }
            break;
    }
}


- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    //NSLog(@"[UnityOverrideAppDelegate application:%@ didFinishLaunchingWithOptions:%@]", application, launchOptions);
    BOOL result = [super application:application didFinishLaunchingWithOptions:launchOptions];
    //监听初始化回调
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(smpcQpInitResult:)
                                                 name:kSmpcQuickSDKNotiInitDidFinished
                                               object:nil];
    
    //初始化
    SMPCQuickSDKInitConfigure *cfg = [[SMPCQuickSDKInitConfigure alloc] init];
    cfg.productKey = @"85149286";
    cfg.productCode = @"28786303682695343992261367010082";
    int error = [[SMPCQuickSDK defaultInstance] initWithConfig:cfg application:application didFinishLaunchingWithOptions:launchOptions];
    if (error != 0) {
        NSLog(@"不能启动初始化：%d",error);
    }
    return result;
}

//- (void)applicationWillResignActive:(UIApplication *)application {
//  [[SMPCQuickSDK defaultInstance] applicationWillResignActive:application];
//}
//- (void) applicationDidEnterBackground:(UIApplication *)application {
//  [[SMPCQuickSDK defaultInstance] applicationDidEnterBackground:application];
//}
//- (void) applicationWillEnterForeground:(UIApplication *)application {
//  [[SMPCQuickSDK defaultInstance] applicationWillEnterForeground:application];
//}
//- (void) applicationDidBecomeActive:(UIApplication *)application {
//  [[SMPCQuickSDK defaultInstance] applicationDidBecomeActive:application];
//}
//- (void) applicationWillTerminate:(UIApplication *)application {
//  [[SMPCQuickSDK defaultInstance] applicationWillTerminate:application];
//}
//- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
//  {
//  [[SMPCQuickSDK defaultInstance] application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
//}
//- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
//  {
//  [[SMPCQuickSDK defaultInstance] application:application didFailToRegisterForRemoteNotificationsWithError:error];
//}
//- (void)application:(UIApplication *)application didReceiveRemoteNotification:(nonnull NSDictionary *)userInfo{
//  [[SMPCQuickSDK defaultInstance] application:application didReceiveRemoteNotification:userInfo];
//}
//-(UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(nullable UIWindow *)window
//{
//  [[SMPCQuickSDK defaultInstance] application:application supportedInterfaceOrientationsForWindow:window];
//  return  UIInterfaceOrientationMaskAll;
//}
//- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url{
//  [[SMPCQuickSDK defaultInstance] openURL:url application:application];
//  return YES;
//}
//- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation{
//  [[SMPCQuickSDK defaultInstance] openURL:url sourceApplication:sourceApplication application:application annotation:annotation];
//  return YES;
//}
//- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString*, id> *)options{
//    [[SMPCQuickSDK defaultInstance] openURL:url application:app options:options];
//    return YES;
//}
@end
