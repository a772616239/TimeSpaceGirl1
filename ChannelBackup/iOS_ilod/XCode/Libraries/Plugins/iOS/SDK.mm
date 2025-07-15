#import "SDK.h"
#import <GamePot/GamePot.h>
#import <GamePotChannel/GamePotChannel.h>
#import "UnityAppController.h"

NSArray* order = @[@(GOOGLE), @(FACEBOOK), @(APPLE),@(NAVER), @(LINE), @(TWITTER), @(GUEST)];
GamePotChannelLoginOption* options = [[GamePotChannelLoginOption alloc] init:order];

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
        [[SDK Instance] CustomerService];
    }

    void m_SDK_Relation(char* type){
        [[SDK Instance] Relation:[NSString stringWithUTF8String:type]];
    }

    void m_SDK_Cancellation(){
        [[SDK Instance] Cancellation];
    }
	
    bool m_SDK_IsCDKey(){
        return [[SDK Instance] IsCDKey];
    }

    void m_SDK_CDKey(char* cdkey, char* serverID, char* roleID){
        [[SDK Instance] CDKey:[NSString stringWithUTF8String:cdkey] serverID:[NSString stringWithUTF8String:serverID] roleID:[NSString stringWithUTF8String:roleID]];
    }

    void m_SDK_LoginPanel_Btn1(){
        [[SDK Instance] LoginPanel_Btn1];
    }

    void m_SDK_LoginPanel_Btn2(){
        [[SDK Instance] LoginPanel_Btn2];
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

- (void)GamePotPurchaseSuccess:(GamePotPurchaseInfo *)_info
{
    // 付款成功
}

- (void)GamePotPurchaseFail:(NSError *)_error
{
    // 支付错误。请在游戏弹窗显示失败原因相关消息。
    // 消息语句请使用[error localizedDescription]。
}

- (void)GamePotPurchaseCancel
{
    // 启动付款过程中取消
    // 在游戏弹窗显示“已取消支付。”消息。
}

-(void)Init{
    DLOG(@"Init");
    [self callUnityFuncParam:@"InitCallback" param:@"1"];
    
    [[GamePot getInstance] setAutoAgree:YES];
    
    [[GamePot getInstance] setPurchaseDelegate:self];
    
    // 开启/关闭推送接收
    [[GamePot getInstance] setPushEnable:YES success:^{

    } fail:^(NSError *error) {

    }];

    // 开启/关闭夜间推送接收
    [[GamePot getInstance] setNightPushEnable:YES success:^{

    } fail:^(NSError *error) {

    }];

    // 同时设置推送/夜间推送
    // 如果是登录前需要获取推送/夜间推送权限的游戏，登录后必须调用以下代码。
    [[GamePot getInstance] setPushStatus:YES night:YES ad:YES success:^{
        
    } fail:^(NSError *error) {
        
    }];
}

-(void)Login{
    DLOG(@"Login");
        
    [[GamePot getInstance] checkAppStatus:^{
        //Login Success
    } setFailHandler:^(NSError *error) {
        //Failed
    } setUpdateHandler:^(GamePotAppStatus *status) {
        //NeedUpdate
        // 需强制更新。调用以下API，即可显示SDK自主弹窗。
        // 需要自定义时，在没有调用以下API的状态下进行自定义。
        [[GamePot getInstance] showAppStatusPopup:UnityGetGLViewController() setAppStatus:status
         setCloseHandler:^{
            // 调用showAppStatusPopup API时，在必须关闭应用的情况下调用。
            // 请处理终止进程。
            exit(0);
        } setNextHandler:^(NSObject* resultPayload) {
            // 将仪表盘的更新设置设为推荐时，会显示"下次进行"按钮。
            // 用户选择该按钮时会调用。
            // 请使用resultPayload信息，进行与登录成功时同样的处理。
            // GamePotUserInfo* userInfo = (GamePotUserInfo*)resultPayload;

        }];
    } setMaintenanceHandler:^(GamePotAppStatus *status) {
        //OnMaintenance
        [[GamePot getInstance] showAppStatusPopup:UnityGetGLViewController() setAppStatus:status
         setCloseHandler:^{
            // 调用showAppStatusPopup API时，在必须关闭应用的情况下调用。
            // 请处理终止进程。
            exit(0);
        }];
    }];
    
    
    // lastLoginType：获取最后一次登录值。
    GamePotChannelType type = [[GamePotChannel getInstance] lastLoginType];
    if(type != NONE)
    {
        // 以最后一次登录的类型登录的方式。
        // 处理自动登录时如下调用即可。
        [[GamePotChannel getInstance] Login:type viewController:UnityGetGLViewController() success:^(GamePotUserInfo* userInfo) {
            NSLog(@"登录成功");

            NSString *acceesToken = [userInfo toJsonString];
            NSString *uid = [[GamePot getInstance] getMemberId];
            NSLog(@"accessToken=%@", acceesToken);
            NSLog(@"uid=%@", uid);
            
            NSString* rel = [NSString stringWithFormat:@"%@#%@#%@#%@",@"1",uid,@"",userInfo.token];
            [self callUnityFuncParam:@"LoginCallback" param:rel];
        } cancel:^{
            NSLog(@"取消登录");
        } fail:^(NSError *error) {
            // 请在游戏弹窗显示失败原因相关消息。
            // 消息语句请使用[error localizedDescription]。
            NSLog(@"登录失败===%@",[error localizedDescription]);
        }];
    }
    else
    {
        NSArray* order = @[@(GOOGLE),@(APPLE),@(GUEST)];
        GamePotChannelLoginOption* options = [[GamePotChannelLoginOption alloc] init:order];
        
        // 没有最后登录信息。跳转到有登录按钮的登录界面
        [[GamePotChannel getInstance] showLoginWithUI:UnityGetGLViewController() option:options success:^(GamePotUserInfo *userInfo) {
            // 登录成功。请根据游戏逻辑进行处理。
            NSLog(@"登录成功");

            NSString *acceesToken = [userInfo toJsonString];
            NSString *uid = [[GamePot getInstance] getMemberId];
            NSLog(@"accessToken=%@", acceesToken);
            NSLog(@"uid=%@", uid);

            NSString* rel = [NSString stringWithFormat:@"%@#%@#%@#%@",@"1",uid,@"",userInfo.token];
            [self callUnityFuncParam:@"LoginCallback" param:rel];
        } update:^(GamePotAppStatus *appStatus) {
                // 需强制更新。调用以下API，即可显示SDK自主弹窗。
                // 需要自定义时，在没有调用以下API的状态下进行自定义。
                [[GamePot getInstance] showAppStatusPopup:UnityGetGLViewController() setAppStatus:appStatus
                 setCloseHandler:^{
                    // 调用showAppStatusPopup API时，在必须关闭应用的情况下调用。
                    // 请处理终止进程。
                    
                } setNextHandler:^(NSObject* resultPayload) {
                    // 将仪表盘的更新设置设为推荐时，会显示"下次进行"按钮。
                    // 用户选择该按钮时会调用。
                    // 请使用resultPayload信息，进行与登录成功时同样的处理。
                    GamePotUserInfo* userInfo = (GamePotUserInfo*)resultPayload;
                    NSString *acceesToken = [userInfo toJsonString];
                    NSString *uid = [[GamePot getInstance] getMemberId];
                    NSLog(@"accessToken=%@", acceesToken);
                    NSLog(@"uid=%@", uid);

                    NSString* rel = [NSString stringWithFormat:@"%@#%@#%@#%@",@"1",uid,@"",userInfo.token];
                    [self callUnityFuncParam:@"LoginCallback" param:rel];
                }];
            } maintenance:^(GamePotAppStatus *appStatus) {
                  // 正在维护中。调用以下API，即可显示SDK自主弹窗。
                // 需要自定义时，在没有调用以下API的状态下进行自定义。
                [[GamePot getInstance] showAppStatusPopup:UnityGetGLViewController() setAppStatus:appStatus
                 setCloseHandler:^{
                    // 调用showAppStatusPopup API时，在必须关闭应用的情况下调用。
                    // 请处理终止进程。
                    exit(0);
                }];
            } exit:^{
            // 点击X按钮时处理
                NSLog(@"关闭选择登录窗口");
        }];
    }
}

-(void)SwitchLogin{
    [[GamePotChannel getInstance] LogoutWithSuccess:^{
        // 退出成功后跳转到初始页面。
        [self callUnityFuncParam:@"LogoutCallback" param:@"1"];
    } fail:^(NSError *error) {
        // 退出登录失败。请在游戏弹窗显示失败原因相关消息。
        // 消息语句请使用[error localizedDescription]。
    }];
    DLOG(@"SwitchLogin");
}

-(void)Logout{
    [[GamePotChannel getInstance] LogoutWithSuccess:^{
        // 退出成功后跳转到初始页面。
        [self callUnityFuncParam:@"LogoutCallback" param:@"1"];
    } fail:^(NSError *error) {
        // 退出登录失败。请在游戏弹窗显示失败原因相关消息。
        // 消息语句请使用[error localizedDescription]。
    }];
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
    
    if(dataType == 3){
        [[GamePot getInstance] showNotice:UnityGetGLViewController() setSchemeHandler:^(NSString *scheme) {
            NSLog(@"scheme = %@", scheme);
        }];
    }
    
    NSDictionary *dict = @{@"name":roleName, @"level":roleLevel, @"serverid":[NSString stringWithFormat:@"%d",serverId], @"playerid":roleID, @"userdata":guildlD,};
    [[GamePot getInstance] setUserData:dict handler:^(BOOL _success, NSError *_error) {
        if(_success)
        {
            //setUserData成功
        }
        else
        {
             //setUserData失败
        }
    }];
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
    
    [[GamePot getInstance] purchase:rechargeId uniqueId:@"" serverId:serverID playerId:roleID etc:extension];
    
    DLOG(@"Pay");
}

-(void)Bind{
	DLOG(@"Bind");
}

-(void)Community{
	DLOG(@"Community");
}

-(void)CustomerService{
    [[GamePot getInstance] showHelpWebView:UnityGetGLViewController()];
    DLOG(@"CustomerService");
}

-(void)Relation:(NSString *) type {
    if([[GamePotChannel getInstance] lastLoginType] != GUEST){
        [self callUnityFuncParam:@"MessageCallback" param:@"현재 로그인 중입니다. 게스트 계정만 연동할 수 있습니다."];
        return;
    }
    
    GamePotChannelType gamePotChannelType = NONE;
    if ([type isEqualToString:@"google"]){
        gamePotChannelType = GOOGLE;
    }else if([type isEqualToString:@"apple"]){
        gamePotChannelType = APPLE;
    }
    [[GamePotChannel getInstance] CreateLinking:gamePotChannelType viewController:UnityGetGLViewController() success:^(GamePotUserInfo *userInfo) {
        // 关联成功。请在游戏弹窗显示关联结果相关消息。（例如：账户关联成功。）
        [self callUnityFuncParam:@"MessageCallback" param:@"연결 성공"];
    } cancel:^{
        // 用户取消
        [self callUnityFuncParam:@"MessageCallback" param:@"사용자 취소"];
    } fail:^(NSError *error) {
        // 关联失败。请在游戏弹窗显示失败原因相关消息。
        // 消息语句请使用[error localizedDescription]。
        [self callUnityFuncParam:@"MessageCallback" param:[error localizedDescription]];
    }];
    DLOG(@"Relation");
}

-(void)Cancellation{
    [[GamePotChannel getInstance] DeleteMemberWithSuccess:^{
        // 会员注销成功。将跳转至登录界面。
        [self callUnityFuncParam:@"LogoutCallback" param:@"1"];
    } fail:^(NSError *error) {
        // 会员注销失败。请在游戏弹窗显示失败原因相关消息。
        // 消息语句请使用[error localizedDescription]。
        DLOG(@"注销失败");
    }];
    DLOG(@"Cancellation");
}

-(bool)IsCDKey{
    DLOG(@"IsCDKey");
    return true;
}

-(void)CDKey:(NSString *) cdkey
             serverID :(NSString *)serverID
     roleID :(NSString *)roleID{
    
    
    [[GamePot getInstance] coupon:cdkey userData:[NSString stringWithFormat:@"%@#%@#%@",roleID,serverID,cdkey] handler:^(BOOL _success, NSError *_error) {
        if(_success)
        {
            // message中返回优惠券使用相关结果。请在游戏弹窗显示相应消息。
            [self callUnityFuncParam:@"MessageCallback" param:@"교환 성공"];
        }
        else
        {
            // _error中返回优惠券使用失败原因相关信息。
            // 请在游戏弹窗显示[_error localizedDescription]内容。
            [self callUnityFuncParam:@"MessageCallback" param:[_error localizedDescription]];
        }
    }];
    
    DLOG(@"CDKey");
}

-(void)LoginPanel_Btn1{
    [[GamePot getInstance] showTerms:UnityGetGLViewController()];
    DLOG(@"LoginPanel_Btn1");
}

-(void)LoginPanel_Btn2{
    [[GamePot getInstance] showPrivacy:UnityGetGLViewController()];
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
