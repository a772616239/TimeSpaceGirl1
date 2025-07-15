#import "UnityAppController.h"
#import <GamePot/GamePot.h>

#import <GamePotChannel/GamePotChannel.h>
// 使用Google登录时
#import <GamePotGoogleSignIn/GamePotGoogleSignIn.h>
// 使用Apple ID登录时
#import <GamePotApple/GamePotApple.h>

#if __has_include(<AppTrackingTransparency/AppTrackingTransparency.h>)
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#endif

#define SYSTEM_VERSION_GRATERTHAN_OR_EQUALTO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@interface SDKAppController : UnityAppController

@end

IMPL_APP_CONTROLLER_SUBCLASS(SDKAppController)
@implementation SDKAppController




- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = [super application:application didFinishLaunchingWithOptions:launchOptions];
    
    // GamePot SDK Initialize
    [[GamePot getInstance] setup];


    // 重置GamePotSDK频道。需按照所需频道使用addChannel（默认包括Guest方式）。
    // 重置Google登录
    GamePotChannelInterface* google     = [[GamePotGoogleSignIn alloc] init];
    [[GamePotChannel getInstance] addChannelWithType:GOOGLE interface:google];

    // 重置Apple ID登录
    GamePotChannelInterface* apple      = [[GamePotApple alloc] init];
    [[GamePotChannel getInstance] addChannelWithType:APPLE interface:apple];
    
    [[GamePotChannel getInstance] application:application didFinishLaunchingWithOptions:launchOptions];


    // Push Permission
    if(SYSTEM_VERSION_GRATERTHAN_OR_EQUALTO(@"10.0"))
    {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = [SDKAppController self];
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error){
            if(!error){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] registerForRemoteNotifications];
                });
            }
        }];
    }
    else
    {
        // Code for old versions
        UIUserNotificationType allNotificationTypes = (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [application registerUserNotificationSettings:settings];
        [application registerForRemoteNotifications];
    }

    // 为在iOS 14版本导入IDFA值，调用权限请求弹窗
    // 项目中未添加AppTrackingTransparency.framework时，无法调用。
    #if __has_include(<AppTrackingTransparency/AppTrackingTransparency.h>)
       if (@available(iOS 14, *)) {
           if(NSClassFromString(@"ATTrackingManager"))
           {
               // 没有注册侦听器时，不会弹出请求弹窗。
               [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {

                   switch (status)
                   {
                       case ATTrackingManagerAuthorizationStatusNotDetermined:
                           break;
                       case ATTrackingManagerAuthorizationStatusRestricted:
                           break;
                       case ATTrackingManagerAuthorizationStatusDenied:
                           break;
                       case ATTrackingManagerAuthorizationStatusAuthorized:
                           break;
                       default:
                           break;
                   }
               }];
           }
       }
    #endif

    return result;
}

// Push
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
   [[GamePot getInstance] handleRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
   [[GamePotChat getInstance] start];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
   [[GamePotChat getInstance] stop];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    // 进行登录处理时需要。
    BOOL nChannelResult = [[GamePotChannel getInstance] application:app openURL:url options:options];
    return nChannelResult;
}

@end
