#import "SDK.h"
#import <BDGameSDK/BDPublishSDK.h>
extern UIViewController *UnityGetGLViewController();

//NSString转char*
#define MakeStringCopy( _x_ ) ( _x_ != NULL && [_x_ isKindOfClass:[NSString class]] ) ? strdup( [_x_ UTF8String] ) : NULL
//日志打印
#define DLOG(...) NSLog(__VA_ARGS__);

extern "C"{
    void m_SDK_Init(){
        [[SDK Instance] Init];
    }

    void m_SDK_Login(){
        [[SDK Instance] Login];
    }

    void m_SDK_Logout(){
        [[SDK Instance] Logout];
    }
    
    bool m_SDK_IsSupportExit(){
        return [[SDK Instance] IsSupportExit];
    }
    
    void m_SDK_Exit(){
        [[SDK Instance] ExitGame];
    }
    
    void m_SDK_SubmitExtraData(int dataType,int serverId,char* serverName, char* zoneID, char* zoneName, char* roleID, char* roleName, char* roleLevel, char* guildlD, char* Vip, int moneyNum, char* roleCreateTime, char* roleLevelUpTime){
        [[SDK Instance] SubmitExtraData:dataType
                               serverId:serverId
                             serverName:[NSString stringWithUTF8String:serverName]
                                 zoneID:[NSString stringWithUTF8String:zoneID]
                               zoneName:[NSString stringWithUTF8String:zoneName]
                                 roleID:[NSString stringWithUTF8String:roleID]
                               roleName:[NSString stringWithUTF8String:roleName]
                              roleLevel:[NSString stringWithUTF8String:roleLevel]
                                guildlD:[NSString stringWithUTF8String:guildlD]
                                    Vip:[NSString stringWithUTF8String:Vip]
                               moneyNum:moneyNum
                         roleCreateTime:[NSString stringWithUTF8String:roleCreateTime]
                        roleLevelUpTime:[NSString stringWithUTF8String:roleLevelUpTime]];
    }
    
    void m_SDK_Pay(char* rechargeId,int showType, int productId, char* productName, char* productDesc,char* price,char* currencyType,int ratio,int buyNum,int coinNum, char* zoneId, char* serverID, char* serverName, char* accounted, char* roleID, char* roleName,int roleLevel, char* Vip, char* guildlD, char* payNotifyUrl, char* extension, char* orderID){
        [[SDK Instance] Pay:[NSString stringWithUTF8String:rechargeId]
                   showType:showType
                  productId:productId
                productName:[NSString stringWithUTF8String:productName]
                productDesc:[NSString stringWithUTF8String:productDesc]
                      price:[NSString stringWithUTF8String:price]
               currencyType:[NSString stringWithUTF8String:currencyType]
                      ratio:ratio
                     buyNum:buyNum
                    coinNum:coinNum
                     zoneId:[NSString stringWithUTF8String:zoneId]
                   serverID:[NSString stringWithUTF8String:serverID]
                 serverName:[NSString stringWithUTF8String:serverName]
                  accounted:[NSString stringWithUTF8String:accounted]
                     roleID:[NSString stringWithUTF8String:roleID]
                   roleName:[NSString stringWithUTF8String:roleName]
                  roleLevel:roleLevel
                        Vip:[NSString stringWithUTF8String:Vip]
                    guildlD:[NSString stringWithUTF8String:guildlD]
               payNotifyUrl:[NSString stringWithUTF8String:payNotifyUrl]
                  extension:[NSString stringWithUTF8String:extension]
                    orderID:[NSString stringWithUTF8String:orderID]];
    }
    
    void m_SDK_Bind(){
        [[SDK Instance] Bind];
    }
    
    void m_SDK_Community(){
        [[SDK Instance] Community];
    }
	
	void m_SDK_HelpConversation(){
        [[SDK Instance] HelpConversation];
    }
	
	void m_SDK_FAQ(){
        [[SDK Instance] FAQ];
    }
	
	void m_SDK_Operation(){
        [[SDK Instance] Operation];
    }
    
    void m_SDK_CustomEvent(int type, char* param){
        [[SDK Instance] CustomEvent:type param:[NSString stringWithUTF8String:param]];
    }
}

@interface SDK ()<BDPublishSDKDelegate,UITableViewDelegate>//, UITableViewDataSource>

@end

@implementation SDK

NSString* callUnityTargetGameObjectName = @"SDK.SDKManager";
NSString* accountID;

static SDK * instance = nil;
 +(SDK*)Instance {
     if(instance == nil){
         instance =[[SDK alloc] init];
     }
     return instance;
 }

-(void)Init{
    DLOG(@"Init");
    [self callUnityFuncParam:@"InitCallback" param:@"1"];
}


- (void)bd_didLogin:(BDPublishSDK *)publishSDK user:(nullable BDSDKUser *)user error:(nullable NSError *)error {
    if (error) {
        switch (error.code) {
            case 70001:
            {
                NSLog(@"取消登录===%@", error.domain);
            }
                break;
            default:
                break;
        }
    } else {
        NSLog(@"登录成功");
        
        accountID = user.AccountID;
        
        NSString *acceesToken = user.AccessToken;
        NSString *uid = user.Uid;
        NSLog(@"accessToken=%@", acceesToken);
        NSLog(@"uid=%@", uid);
        
        NSString* rel = [NSString stringWithFormat:@"%@#%@#%@#%@",@"1",uid,@"",acceesToken];
        [self callUnityFuncParam:@"LoginCallback" param:rel];
    }
    
}

-(void)Login{
    [BDPublishSDK sharedInstance].delegate = self;
    [[BDPublishSDK sharedInstance] bd_login];
    DLOG(@"Login");
}
 
-(void)SwitchLogin{
    DLOG(@"SwitchLogin");
}

-(void)Logout{
    [self callUnityFuncParam:@"LogoutCallback" param:@"1"];
    DLOG(@"Logout");
}

-(bool)IsSupportExit{
    DLOG(@"IsSupportExit");
    return false;
}

-(void)ExitGame{
    DLOG(@"ExitGame");
}

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
            roleLevelUpTime :(NSString *) roleLevelUpTime{
        
    NSDictionary *dict = @{
                            @"account_id":accountID,
                            @"game_region":serverName,
                            @"game_region_id":[NSString stringWithFormat:@"%d",serverId],
                            @"game_role_name":roleName,
                            @"game_role_id":roleID,
                            @"game_role_level":roleLevel,
                            @"game_vip":Vip,
                          };
    [[BDPublishSDK sharedInstance] bd_reportPlayerInfo:dict isFirstCreate:dataType==2];
    DLOG(@"SubmitExtraData");
}

NSString* payParams = nil;

- (void)bd_didPay:(BDPublishSDK *)publishSDK payResult:(nonnull BDPulishPayModel *)payResult {
    switch (publishSDK.payStatus) {
        case BDPublishPaySuccess:
            NSLog(@"支付成功");
            [self callUnityFuncParam:@"PayCallback" param:@"1#"];
            
            if(payParams == nil){
                NSLog(@"参数有问题");
            }else{
                [self CustomEvent:99 param:@"调出支付请求接口成功"];
            }
            break;
        case BDPublishPayFail:
            NSLog(@"支付失败");
            [self callUnityFuncParam:@"PayCallback" param:@"0#"];
            
            [self CustomEvent:99 param:@"支付失败"];
            break;
        case BDPublishPayCancel:
            NSLog(@"支付取消");
            
            [self CustomEvent:99 param:@"取消支付"];
            break;
        case BDPublishPayOrderFail:
            NSLog(@"下单失败");
            break;
        case BDPublishPayUnkown:
            NSLog(@"支付未知");
            break;
        default:
            break;
    }
}
            
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
            orderID :(NSString *) orderID{
    
    payParams = [NSString stringWithFormat:@"%d-%d-%@-%@",showType,productId,price,currencyType];

    BDPulishPayModel *model = [[BDPulishPayModel alloc] init];
    model.productId = rechargeId; //商品id
    model.cooperatorOrderSerial = orderID; // 订单号
    NSDictionary *exInfo = @{
                             @"GameRegion":serverName,
                             @"GameRegionId":serverID,
                             @"GameRoleId":roleID,
                             @"GameRoleLevel":[NSString stringWithFormat:@"%d",roleLevel],
                            };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exInfo options:0 error:0];
    model.gameInfo = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]; // 角色信息
    
    [BDPublishSDK sharedInstance].delegate = self;
    
    [self CustomEvent:99 param:@"调出支付请求接口成功"];
    [[BDPublishSDK sharedInstance] bd_payWithPayModel:model];
    DLOG(@"Pay");
}

-(void)Bind{
    [[BDPublishSDK sharedInstance] bd_bindAccount];
    DLOG(@"Bind");
}
    
-(void)Community{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.facebook.com/Error-City-SEA-100923279044170/?ref=page_internal"]];
    DLOG(@"Community");
}

-(void)HelpConversation{
    [[BDPublishSDK sharedInstance] bd_showHelpConversation];
    DLOG(@"HelpConversation");
}

-(void)FAQ{
    [[BDPublishSDK sharedInstance] bd_showFAQ];
    DLOG(@"FAQ");
}

-(void)Operation{
    [[BDPublishSDK sharedInstance] bd_showOperation];
    DLOG(@"Operation");
}
-(void)CustomEvent:(int) type
            param :(NSString *) param{
    
    NSString* eventName = @"";
    NSDictionary* eventVelue = @{};
    switch (type)
    {
        case 0://通用
        {
            if([param isEqualToString:@"游戏激活"]){
                eventName = @"first_open";
            }
            else if([param isEqualToString:@"开始热更"]){
                eventName = @"hot_update_click";
            }
            else if([param isEqualToString:@"热更结束"]){
                eventName = @"hot_update_suc";
            }
            else if([param isEqualToString:@"热更失败"]){
                eventName = @"hot_update_failed";
            }
            else if([param isEqualToString:@"登录页面弹出"]){
                eventName = @"login_page";//sdk这边加
            }
            else if([param isEqualToString:@"登录成功"]){
                eventName = @"login";//sdk这边加
            }
            else if([param isEqualToString:@"进入服务器"]){
                eventName = @"ACTION_ENTER_SERVER";
            }
            else if([param isEqualToString:@"创建角色"]){
                eventName = @"role_created";
            }
            else if([param isEqualToString:@"新手引导开始"]){
                eventName = @"tutorial_begin";
            }
            else if([param isEqualToString:@"新手引导结束"]){
                eventName = @"tutorial_complete";
            }
        }
        break;
        case 1://解锁功能
        {
            if([param isEqualToString: @"79"]){
                eventName = @"unlock_guardian";//守护
            }
            else if([param isEqualToString: @"85"]){
                eventName = @"unlock_tower";//神之塔
            }
            else if([param isEqualToString: @"8"]){
                eventName = @"unlock_arena";//地下竞技
            }
            else if([param isEqualToString: @"66"]){
                eventName = @"unlock_research";//研究所
            }
            else if([param isEqualToString: @"75"]){
                eventName = @"unlock_laboratory";//实验室
            }
            else if([param isEqualToString: @"20"]){
                eventName = @"unlock_market";//超市
            }
            else if([param isEqualToString: @"67"]){
                eventName = @"unlock_Trial";//试炼
            }
        }
        break;
        case 2://好友数量
            if([param isEqualToString: @"3"]){
                eventName = @"task_friend3";
            }
        break;
        case 3://英雄数量
            if([param isEqualToString: @"3"] or [param isEqualToString: @"10"] or [param isEqualToString: @"30"]){
                eventName = [NSString stringWithFormat:@"%@%@", @"task_hero",param];
            }
        break;
        case 4://玩家升级
            if([param isEqualToString: @"5"]
               or [param isEqualToString: @"10"]
               or [param isEqualToString: @"15"]
               or [param isEqualToString: @"20"]
               or [param isEqualToString: @"50"]
               or [param isEqualToString: @"70"]){
                eventName = [NSString stringWithFormat:@"%@%@", @"role_level",param];
            }
        break;
        case 5://vip升级
            if([param isEqualToString: @"1"]
               or [param isEqualToString: @"2"]
               or [param isEqualToString: @"3"]
               or [param isEqualToString: @"4"]
               or [param isEqualToString: @"5"]
               or [param isEqualToString: @"6"]
               or [param isEqualToString: @"7"]
               or [param isEqualToString: @"8"]
               or [param isEqualToString: @"9"]
               or [param isEqualToString: @"10"]
               or [param isEqualToString: @"11"]
               or [param isEqualToString: @"12"]
               or [param isEqualToString: @"13"]
               or [param isEqualToString: @"14"]
               or [param isEqualToString: @"15"]){
                eventName = [NSString stringWithFormat:@"%@%@", @"VIP_",param];
            }
            break;
        case 6://战斗力提升
            {
                int maxPower = [param intValue];
                if (maxPower >= 1000000) {
                    eventName =  @"power_100w";
                } else if (maxPower >= 500000) {
                    eventName = @"power_50w";
                } else if (maxPower >= 100000) {
                    eventName = @"power_10w";
                }
            }
            break;
        case 7://加入公会
            {
                eventName = @"first_guild";
            }
            break;
        case 99://充值成功
            {
                if([param isEqualToString: @"取消支付"]){
                    eventName = @"cancellation_payment";
                } else if([param isEqualToString:@"支付失败"]) {
                    eventName = @"payment_failed";
                }else if([param isEqualToString:@"调出支付请求接口成功"]){
                    eventName = @"payment_request";
                }else if([param isEqualToString:@"限时特惠购买页面弹出"]){
                    eventName = @"firstspecialbuyui_displayed";
                }else {
                    [[BDPublishSDK sharedInstance] bd_logEvent:@"finish_first_top-up" withValues:eventVelue];

                    NSArray* strArr = [param componentsSeparatedByString:NSLocalizedString(@"-", nil)];
                    int showType = [strArr[0] intValue];
                    int proId = [strArr[1] intValue];
                    NSString* price = strArr[2];
                    NSString* currencyType = strArr[3];
                    if (showType == 3) {
                        if (proId == 1) {
                            eventName = @"iap_0.99buy";
                        } else if (proId == 2) {
                            eventName = @"iap_4.99buy";
                        } else if (proId == 3) {
                            eventName = @"iap_14.99buy";
                        } else if (proId == 4) {
                            eventName = @"iap_29.99buy";
                        } else if (proId == 5) {
                            eventName = @"iap_49.99buy";
                        } else if (proId == 6) {
                            eventName = @"iap_99.99buy";
                        }
                    } else if (showType == 4){//成长基金
                        eventName = @"iap_upgradefund";
                    } else if (showType == 14 || showType == 999) {//每日礼包
                        eventName = @"iap_daily";
                    } else if (showType == 15) {
                        if (proId != 2000) {//周礼包
                            eventName = @"iap_week";
                        }
                    }
                    

                    [[BDPublishSDK sharedInstance] bd_logEvent:@"purchase_success" withValues:@{
                        @"af_revenue":price,
                        @"af_currency":currencyType,
                       }];
                }
            }
            break;
        default:
            break;
    }

    if([eventName isEqualToString:@""]) {
        
    }
    else{
        [[BDPublishSDK sharedInstance] bd_logEvent:eventName withValues:eventVelue];
    }
    DLOG(@"CustomEvent");
}


//调用Unity方法
-(void)callUnityFunc:(NSString*)funcName{
    UnitySendMessage(MakeStringCopy(callUnityTargetGameObjectName), MakeStringCopy(funcName), "");
}

//调用Unity方法
-(void)callUnityFuncParam:(NSString*)funcName param:(NSString*)param{
    UnitySendMessage(MakeStringCopy(callUnityTargetGameObjectName), MakeStringCopy(funcName), MakeStringCopy(param));
}

@end

