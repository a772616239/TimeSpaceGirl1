#import <Foundation/Foundation.h>

@interface GamePotUserInfo : NSObject
@property(nonatomic) NSString* memberid;
@property(nonatomic) NSString* userid;
@property(nonatomic) NSString* name;
@property(nonatomic) NSString* profileUrl;
@property(nonatomic) NSString* token;
@property(nonatomic) NSString* email;
@property(nonatomic) NSDictionary* kakaoRawData;
- (NSString*)toString;
- (NSDictionary*) toDictionary;
- (NSString* ) toJsonString;
@end
