#import "SDK.h"
#import <JySDK/JySDKManager.h>

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

    void m_SDK_CustomerService(){
    
    }

    void m_SDK_Relation(char* type){
    
    }

    void m_SDK_Cancellation(){
    
    }
	
    bool m_SDK_IsCDKey(){
        return  false;
    }

    void m_SDK_CDKey(char* cdkey, char* serverID, char* roleID){

    }

    void m_SDK_LoginPanel_Btn1(){

    }

    void m_SDK_LoginPanel_Btn2(){

    }

	void m_SDK_CustomEvent(int type, char* param){
        [[SDK Instance] CustomEvent:type param:[NSString stringWithUTF8String:param]];
	}
}

@implementation SDK

NSString* callUnityTargetGameObjectName = @"SDK.SDKManager";

static SDK * instance = nil;
 +(SDK*)Instance {
     if(instance == nil){
         instance =[[SDK alloc] init];
     }
     return instance;
 }

-(void)Init{
    
    [self callUnityFuncParam:@"InitCallback" param:@"1"];
    
    //设置代理，监听用户退出事件
//   [JySDKManager defaultManager].acountDelegate = self；
//    实现代理方法，监听用户退出和注册账号事件：
//    #pragma mark -- KAcountDelegate
//    - (void)userLogout:(NSDictionary *)resultDic
//    {
//    NSLog(@"用户从个人中心手动登出。\n%@",resultDic);
//    [self login:nil];
//    }
//    - (void)userRegister:(NSString *)uid
//    {
//    NSLog(@"注册账号：%@",uid);
//    };
    
    
    DLOG(@"Init");
}

-(void)Login{
    [JySDKManager login:^(NSDictionary *resultDic) {
        NSString *code = [resultDic objectForKey:@"code"];
        NSString *token = [JySDKManager userToken];
        switch (code.integerValue) {
            case kErrorNone:{
                
                NSString *userid = [resultDic objectForKey:@"userId"];
                NSLog(@"登录成功:\n用户ID:%@,验证码:%@",userid,token);
                
                if([JySDKManager isGuest]){
                    NSLog(@"是游客登录");
                }else{
                    NSLog(@"非游客登录");
                }
                
                //悬浮球
                [JySDKManager showFloatMenuBtnWithIsLeft:YES andWithCenterY:30];
                
                NSString* rel = [NSString stringWithFormat:@"%@#%@#%@#%@",@"1",userid,@"",token];
                [self callUnityFuncParam:@"LoginCallback" param:rel];
                
                if([JySDKManager isRealName]){

                }else{
                    NSLog(@"没有实名认证");
                }
            }
                break;
            default:
                break;
        }
    }];
    
    DLOG(@"Login");
}

-(void)SwitchLogin{
    DLOG(@"SwitchLogin");
}

-(void)Logout{
    [JySDKManager logout:^{
        
    }];
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
    
    // 更新角色信息
    GameRole *role = [GameRole new];
    role.roleId = roleID;  /// 必传
    role.role_name = roleName;
    role.serverId = [NSString stringWithFormat:@"%d",serverId];
    role.sv_name = serverName;
    role.role_level = roleLevel;
    role.vipLevel = Vip;
    [JySDKManager updateRoleInfo:role];
//    获取用户年龄
//    NSString * age = JySDKManager.getCurrentUserAge;
//    NSLog(@"当前用户UID=%@，年龄=%@", JySDKManager.userId, age);
    DLOG(@"SubmitExtraData");
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
    
    GoodParam *param = [GoodParam new];
    param.productId = rechargeId; ///商品id ,必填 // com.game.xianxiawu
    param.productName = productName;
    //param.productDesc = @"sixBaoshi";
    param.price = [price floatValue];   ///商品单价 必填
    param.orderNo = orderID;     ///游戏方订单号 string[64] 必填、必须唯一  /// 注意： 接入QuickAd时、游戏订单号 必传 且 必须唯一 ///
    param.url = payNotifyUrl;    ///回调通知地址 string[200] 可选  客户端配置优先;  可传nil
    param.extras = extension; ///透传参数  可选
    
    [JySDKManager getGoodWithParam:param completion:^(NSDictionary *resultDic) {
        NSLog(@"%@",resultDic);
        NSString *code = [resultDic objectForKey:@"code"];
        NSString *msg = [resultDic objectForKey:@"message"];
        NSString *productId; //商品id
        NSData *receipt;   //购买后的凭据
        NSString *tranactionId; //交易号
        switch (code.integerValue) {
            case KOrderSuccess:
            {
                NSLog(@"购买成功，订单号:%@",msg);
                //获取内购相关信息
                productId = [resultDic objectForKey:@"productIdentifier"]; //内购商品id
                receipt = [resultDic objectForKey:@"receipt"]; //内购交易凭据
                tranactionId = [resultDic objectForKey:@"transactionId"]; //内购交易id
            }
                break;
            case KOrderFail:
                //充值失败
                break;
            case KOrderCancel:
                NSLog(@"失败原因：%@",msg);
                break;
            case KOrderUnkown:
                break;
            default:
                break;
        }
    }];
    
    
    DLOG(@"Pay");
}

-(void)Bind{
	DLOG(@"Bind");
}

-(void)Community{
    [JySDKManager showUserCenter];
	DLOG(@"Community");
}

-(void)CustomerService{
    DLOG(@"CustomerService");
}

-(void)Relation:(NSString *) type{
    DLOG(@"Relation");
}

-(void)Cancellation{
    [JySDKManager deleteCurrentAccount];
    DLOG(@"Cancellation");
}

-(bool)IsCDKey{
    DLOG(@"IsCDKey");
    return false;
}

-(void)CDKey:(NSString *) cdkey
             serverID :(NSString *)serverID
     roleID :(NSString *)roleID{
    DLOG(@"CDKey");
}

-(void)LoginPanel_Btn1{
    DLOG(@"LoginPanel_Btn1");
}

-(void)LoginPanel_Btn2{
    DLOG(@"LoginPanel_Btn2");
}

-(void)CustomEvent:(int) type
			param :(NSString *) param{
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
