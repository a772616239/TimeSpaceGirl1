#import <Foundation/Foundation.h>

//NSString转char*
#define MakeStringCopy( _x_ ) ( _x_ != NULL && [_x_ isKindOfClass:[NSString class]] ) ? strdup( [_x_ UTF8String] ) : NULL
//日志打印
#define DLOG(...) NSLog(__VA_ARGS__);


@interface NotchScreenUtil : NSObject

@end

@implementation NotchScreenUtil

//+ (BOOL)isIPhoneNotchScreen{
//    BOOL result = NO;
//    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone) {
//        return result;
//    }
//    if (@available(iOS 11.0, *)) {
//        UIWindow *mainWindow = [[[UIApplication sharedApplication] delegate] window];
//        if (mainWindow.safeAreaInsets.bottom > 0.0) {
//            result = YES;
//        }
//    }
//    return result;
//}

+(NSString *) GetNotchHeight {
    CGFloat notchHeight = 0;
    //只判断手机 pad没有刘海
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        if (@available(iOS 11.0, *)) {
            UIWindow *mainWindow = [[[UIApplication sharedApplication] delegate] window];
            //如果下边有安全区域就是刘海屏？
            if (mainWindow.safeAreaInsets.bottom > 0.0) {
                notchHeight = 88;//写死刘海高度
            }
        }
    }
	DLOG(@"结果：%@",[NSString stringWithFormat:@"%g",notchHeight]);
	return [NSString stringWithFormat:@"%g",notchHeight];
}
@end

// Helper method to create C string copy
 char* NotchScreenUtilMakeCString(NSString *str)
 {
     const char* string = [str UTF8String];
     if (string == NULL) {
         return NULL;
     }

     char* res = (char*)malloc(strlen(string) + 1);
     strcpy(res, string);
     return res;
 }

extern "C" {
    char * m_GetNotchHeight() {
        return NotchScreenUtilMakeCString([NotchScreenUtil GetNotchHeight]);
    }
}


