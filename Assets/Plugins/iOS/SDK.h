//#import <StoreKit/StoreKit.h>
#import <Foundation/Foundation.h>

@interface SDK : NSObject

+(SDK*)Instance;

-(void)Init;

-(void)Login;

-(void)SwitchLogin;

-(void)Logout;

-(bool)IsSupportExit;

-(void)ExitGame;
            
-(void)SubmitExtraData:(int) dataType
            serverId :(int) serverId
            serverName :(NSString *) serverName
            zoneID :(NSString *) zoneID
            zoneName :(NSString *) zoneName
            roleID :(NSString *) roleID
            roleName :(NSString *) roleName
            roleLevel :(NSString *) roleLevel
            guildlD :(NSString *) guildlD
            Vip :(NSString *) Vip
            moneyNum :(int) moneyNum
            roleCreateTime :(NSString *) roleCreateTime
            roleLevelUpTime :(NSString *) roleLevelUpTime;
            
-(void)Pay:(NSString *) rechargeId
            showType :(int)showType
            productId :(int) productId
            productName :(NSString *) productName
            productDesc :(NSString *) productDesc
            price :(NSString *) price
			currencyType :(NSString *) currencyType
            ratio :(int) ratio
            buyNum :(int) buyNum
            coinNum :(int) coinNum
            zoneId :(NSString *) zoneId
            serverID :(NSString *) serverID
            serverName :(NSString *) serverName
            accounted :(NSString *) accounted
            roleID :(NSString *) roleID
            roleName :(NSString *) roleName
            roleLevel :(int) roleLevel
            Vip :(NSString *) Vip
            guildlD :(NSString *) guildlD
            payNotifyUrl :(NSString *) payNotifyUrl
            extension :(NSString *) extension
            orderID :(NSString *) orderID;
			
-(void)Bind;

-(void)Community;

-(void)CustomerService;

-(void)Relation:(NSString *) type;

-(void)Cancellation;

-(bool)IsCDKey;

-(void)CDKey:(NSString *) cdkey
             serverID :(NSString *)serverID
             roleID :(NSString *)roleID;

-(void)LoginPanel_Btn1;

-(void)LoginPanel_Btn2;
			
-(void)CustomEvent:(int) type
			param :(NSString *) param;
			
@end
