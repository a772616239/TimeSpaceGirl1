#import <UserNotifications/UserNotifications.h>

@interface GamePotNotificationServiceExtension : UNNotificationServiceExtension

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler;

@end
