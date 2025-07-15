#import "UnityAppController.h"
#import <BDGameSDK/BDPublishSDK.h>
@interface SDKAppController : UnityAppController

@end

IMPL_APP_CONTROLLER_SUBCLASS(SDKAppController)
@implementation SDKAppController

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    //NSLog(@"[UnityOverrideAppDelegate application:%@ didFinishLaunchingWithOptions:%@]", application, launchOptions);
    BOOL result = [super application:application didFinishLaunchingWithOptions:launchOptions];
	[BDPublishSDK sharedInstance].debugMode = YES;
    [[BDPublishSDK sharedInstance] bd_registWithAppKey:@"q5TzYg9OSUVuZoYTD1GiV3jt" appId:@"25304533"
    Options:launchOptions application:application];
    return result;
}

- (BOOL)application:(UIApplication*)app openURL:(NSURL*)url options:(NSDictionary<NSString*, id>*)options
{
    return [[BDPublishSDK sharedInstance] bd_application:app openURL:url options:options];
}
@end
