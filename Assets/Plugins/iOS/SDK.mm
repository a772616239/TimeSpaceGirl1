#import "SDK.h"

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
    DLOG(@"Init");
}

-(void)Login{
    DLOG(@"Login");
}

-(void)SwitchLogin{
    DLOG(@"SwitchLogin");
}

-(void)Logout{
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
