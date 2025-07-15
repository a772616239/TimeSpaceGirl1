package com.game.base;

import android.util.Log;
import com.unity3d.player.UnityPlayer;
import com.unity3d.player.UnityPlayerActivity;

public abstract class IUnityPlayerActivity extends UnityPlayerActivity {

    // 初始化接口
    public abstract void Init();
    // 登录接口
    public abstract void Login();
    public abstract void SwitchLogin();
    public abstract void Logout();
	//是否支持退出功能
    public abstract boolean IsSupportExit();
	// 手机返回键点击事件
    public abstract void ExitGame();
    // 数据提交接口
    public abstract void SubmitExtraData(
            final int dataType,
            final int serverId,
            final String serverName,
            final String zoneID,
            final String zoneName,
            final String roleID,
            final String roleName,
            final String roleLevel,
            String guildlD,
            String Vip,
            final int moneyNum,
            final String roleCreateTime,
            final String roleLevelUpTime);
    //支付接口
    public abstract void Pay(
            final String rechargeId,
            final int showType,
            final int productId,
            final String productName,
            final String productDesc,
            final String price,
			final String currencyType,
            final int ratio,
            final int buyNum,
            final int coinNum,
            final String zoneId,
            final String serverID,
            final String serverName,
            final String accounted,
            final String roleID,
            final String roleName,
            final int roleLevel,
            final String vip,
            final String guildlD,
            final String payNotifyUrl,
            final String extension,
            final String orderID);
    // // 截屏功能
    // public abstract void SendScreenshotData(byte[] bytes);
    //绑定
    public void Bind(){

    }
    //社区
	public void Community(){
		
	}
	//客服
	public void CustomerService(){

    }
    //账户关联
    public void Relation(String type){

    }
    //账户注销
    public void Cancellation(){

    }
    //是否有兑换码功能
    public boolean IsCDKey(){
        return false;
    }
    //兑换码
    public void CDKey(String cdkey,String serverID,String roleID){

    }
    //登录界面预留按钮1功能
    public void LoginPanel_Btn1(){

    }
    //登录界面预留按钮2功能
    public void LoginPanel_Btn2(){

    }
	// 打点
    public void CustomEvent(int type,String param){

    }
	
    protected final String SUCCESS = "1";
    protected final String FAILED = "0";
	//回调Unity方法
    protected void callUnityFunc(String funcName) {
        callUnityFunc(funcName, null);
    }
    //回调Unity方法
    protected void callUnityFunc(String funcName, String param) {
        if (param == null) {//调用Unity方法参数不能为null不然调用失败
            param = "";
        }
        UnityPlayer.UnitySendMessage("SDK.SDKManager",funcName,param);
    }
    //打印日志
    protected void printLog(String log) {
        Log.d("Unity SDK:", log);
    }
    //打印错误
    protected void printError(String error) {
        Log.e("Unity SDK:", error);
    }
}

