#import "SDK.h"
#import <SMPCQuickSDK/SMPCQuickSDK.h>

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
    //登录
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(smpcQpLoginResult:) name:kSmpcQuickSDKNotiLogin object:nil];
    //注销
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(smpcQpLogoutResult:) name:kSmpcQuickSDKNotiLogout object:nil];
    //充值结果
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(smpcQpRechargeResult:) name:kSmpcQuickSDKNotiRecharge object:nil];
    
    DLOG(@"Init");
}

- (void)smpcQpLoginResult:(NSNotification *)notify {
    NSLog(@"登录成功通知%@",notify);
    int error = [[[notify userInfo] objectForKey:kSmpcQuickSDKKeyError] intValue];
    NSDictionary *userInfo = [notify userInfo];
    if (error == 0) {
        
        //悬浮球
        [[SMPCQuickSDK defaultInstance] showToolBar:SMPC_QUICK_SDK_TOOLBAR_TOP_LEFT];
        
        NSString *uid = [[SMPCQuickSDK defaultInstance] userId];
//        NSString *user_name = [[SMPCQuickSDK defaultInstance] userNick];
        QuickSDKUserTYPE type = [[SMPCQuickSDK defaultInstance] getChannelUserLoginType];
        //获取user_token，用于从服务器去验证用户信息
        NSString *token = userInfo[kSmpcQuickSDKKeyUserToken];
        NSString *channelType =  [NSString stringWithFormat:@"%d",[SMPCQuickSDK defaultInstance].channelType];
        NSString* rel = [NSString stringWithFormat:@"%@#%@#%@#%@",@"1",uid,channelType,token];
        [self callUnityFuncParam:@"LoginCallback" param:rel];
    }
}

- (void)smpcQpLogoutResult:(NSNotification *)notify {
    NSLog(@"%s",__func__);
    NSDictionary *userInfo = notify.userInfo;
    int errorCode = [userInfo[kSmpcQuickSDKKeyError] intValue];
    switch (errorCode) {
        case SMPC_QUICK_SDK_ERROR_NONE:
        {
            [self callUnityFuncParam:@"LogoutCallback" param:@"1"];
            NSLog(@"注销成功");
        }
            break;
        case SMPC_QUICK_SDK_ERROR_LOGOUT_FAIL:
        default:
        {
            //注销失败
            [self callUnityFuncParam:@"LogoutCallback" param:@"0"];
            NSLog(@"注销失败");
        }
            break;
    }
    if (errorCode == SMPC_QUICK_SDK_ERROR_NONE) {
        
    }
}

- (void)smpcQpRechargeResult:(NSNotification *)notify{
    NSLog(@"充值结果%@",notify);
    NSDictionary *userInfo = notify.userInfo;
    int error = [[userInfo objectForKey:kSmpcQuickSDKKeyError] intValue];
    switch (error) {
        case SMPC_QUICK_SDK_ERROR_NONE:
        {
            //充值成功
            //QuickSDK订单号,cp下单时传入的订单号，渠道sdk的订单号，cp下单时传入的扩展参数
            NSString *orderID = userInfo[kSmpcQuickSDKKeyOrderId];
            NSString *cpOrderID = userInfo[kSmpcQuickSDKKeyCpOrderId];
            NSLog(@"充值成功数据：%@,%@",orderID,cpOrderID);
        }
            break;
        case SMPC_QUICK_SDK_ERROR_RECHARGE_CANCELLED:
        case SMPC_QUICK_SDK_ERROR_RECHARGE_FAILED:
        {
            //充值失败
            NSString *orderID = userInfo[kSmpcQuickSDKKeyOrderId];
            NSString *cpOrderID = userInfo[kSmpcQuickSDKKeyCpOrderId];
            NSLog(@"充值失败数据%@,%@",orderID,cpOrderID);
        }
            break;
        default:
            break;
    }
}

-(void)Login{
    int error = [[SMPCQuickSDK defaultInstance] login];
    if (error != 0) {
        NSLog(@"不能登录：%d",error);
    }
    
    DLOG(@"Login");
}

-(void)SwitchLogin{
    DLOG(@"SwitchLogin");
}

-(void)Logout{
    [[SMPCQuickSDK defaultInstance] logout];
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
    SMPCQuickSDKGameRoleInfo *gameRoleInfo = [SMPCQuickSDKGameRoleInfo new];
    gameRoleInfo.serverName = serverName;
    gameRoleInfo.gameRoleName = roleName;
    gameRoleInfo.serverId = [NSString stringWithFormat:@"%d",serverId]; //需要是数字字符串
    gameRoleInfo.gameRoleID = roleID;
    gameRoleInfo.gameUserBalance = @"0";
    gameRoleInfo.vipLevel = Vip;
    gameRoleInfo.gameUserLevel = roleLevel;
    gameRoleInfo.partyName = @"";
    gameRoleInfo.creatTime = roleCreateTime;
    gameRoleInfo.fightPower = @"0";//战力值通常为数值
    [[SMPCQuickSDK defaultInstance] updateRoleInfoWith:gameRoleInfo isCreate:dataType==2];//如果这个角色是刚刚创建的，这里isCreate可以传YES
    
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
    
    SMPCQuickSDKGameRoleInfo *role = [[SMPCQuickSDKGameRoleInfo alloc] init];
    SMPCQuickSDKPayOrderInfo *order = [[SMPCQuickSDKPayOrderInfo alloc] init];
    role.serverName = serverName;
    role.gameRoleName = roleName;
    role.serverId = serverID; //需要是数字字符串
    role.gameRoleID = roleID;
    role.gameUserBalance = @"0";
    role.vipLevel = Vip;
    role.gameUserLevel = [NSString stringWithFormat:@"%d",roleLevel];
//    role.partyName = @"ios";
//    role.creatTime = @"1580105921";
    role.fightPower = @"0";//战力值通常为数值
    order.goodsID = rechargeId; //必填 iap时注意和苹果开发者后台一致，或者渠道映射的
    order.productName = productName;//必填
    order.cpOrderID = orderID; //必填 游戏订单号
    order.count = 1;  //必填 数量
    order.amount = [price floatValue]; //必填 总价
//    order.callbackUrl = @"";
    order.extrasParams = extension;
//    //个别渠道要求单价*数量==总价
//    if([SMPCQuickSDK defaultInstance].channelType == 9999){
//        //通过判断渠道号处理特定渠道的参数
//        order.goodsID = @"productlist.name";
//    }
    int error = [[SMPCQuickSDK defaultInstance] payOrderInfo:order
                                                    roleInfo:role];
    if (error!=0)
        NSLog(@"不能支付：%d", error);
    
    
    DLOG(@"Pay");
}

-(void)Bind{
	DLOG(@"Bind");
}

-(void)Community{
	DLOG(@"Community");
}

-(void)CustomerService{
    DLOG(@"CustomerService");
}

-(void)Relation:(NSString *) type{
    DLOG(@"Relation");
}

-(void)Cancellation{
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
