package com.ssll.dsywl;

import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.widget.Toast;

import com.game.base.IUnityPlayerActivity;
import com.game.master.callback.MasterCallBack;
import com.game.master.callback.MasterQuitCallBack;
import com.game.master.contacts.MasterGameAction;
import com.game.master.entity.MasterErrorInfo;
import com.game.master.entity.pay.MasterCpPayInfo;
import com.game.master.entity.user.MasterCpUserInfo;
import com.game.master.entity.user.MasterGotUserInfo;
import com.game.master.entity.user.MasterPlatformSubUserInfo;
import com.game.master.utils.ByteUtil;
import com.lib.master.sdk.MasterSDK2;

import java.security.MessageDigest;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

public class MyActivity extends IUnityPlayerActivity {

    MasterSDK2 masterSDK;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        printLog("onCreate");

        //必须保证游戏运行期间 该activity不被销毁，否则会引起crash
        masterSDK = MasterSDK2.getInstance();
        masterSDK.initGameActivity(this);//必须先于onCreate的调用
        masterSDK.onCreate(this);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        //必须在发起支付的activity重写onActivityResult,并调用以下方法
        MasterSDK2.getInstance().onActivityResult(this, requestCode, resultCode, data);
    }

    @Override
    protected void onResume() {
        MasterSDK2.getInstance().onResume(this);
        super.onResume();
    }

    @Override
    protected void onPause() {
        MasterSDK2.getInstance().onPause(this);
        super.onPause();
    }

    @Override
    protected void onStop() {
        MasterSDK2.getInstance().onStop(this);
        super.onStop();
    }

    @Override
    protected void onRestart() {
        MasterSDK2.getInstance().onRestart(this);
        super.onRestart();
    }

    @Override
    protected void onDestroy() {
        MasterSDK2.getInstance().onDestroy(this);
        super.onDestroy();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        MasterSDK2.getInstance().onNewIntent(this, intent);
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        //  需重写activity的onConfigurationChanged，并调用如下方法
        MasterSDK2.getInstance().onConfigurationChanged(this, newConfig);
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        // 需重写activity的onSaveInstanceState，并调用如下方法
        MasterSDK2.getInstance().onSaveInstanceState(this, outState);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        MasterSDK2.getInstance().onRequestPermissionsResult(this, requestCode, permissions, grantResults);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        MasterSDK2.getInstance().onWindowFocusChanged(hasFocus);
    }





    // String orderID = null;
    Bitmap bitmap = null;
    String uid = null;
    private boolean isSwic = false;

    @Override
    public void Init() {
        //masterSDK.getChannelName();//获取当前渠道
        callUnityFunc("InitCallback",SUCCESS);
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                masterSDK.setLogoutCallback(new MasterCallBack<String>() {
                    @Override
                    public void onSuccess(String s) {
                        //回到登录界面
                        callUnityFunc("LogoutCallback",SUCCESS);

                    }

                    @Override
                    public void onFailed(MasterErrorInfo masterErrorInfo) {

                    }
                });
            }
        });
        printLog("Init");
    }

    @Override
    public void Login() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                masterSDK.login(com.ssll.dsywl.MyActivity.this, new MasterCallBack<MasterGotUserInfo>() {
                    @Override
                    public void onSuccess(MasterGotUserInfo masterGotUserInfo) {
                        uid = masterGotUserInfo.getUserName();
                        String tokens = masterGotUserInfo.getToken(); //登录token
                        callUnityFunc("LoginCallback", String.valueOf(1) + "#" + "" + "#" + "" + "#" + tokens);
                        printLog("登录成功");
                    }

                    @Override
                    public void onFailed(MasterErrorInfo masterErrorInfo) {
                        printLog("登录失败");
                    }
                });

                printLog("Login");
            }
        });

        callUnityFunc("DebugSdk", "开始登录");
    }

    @Override
    public void SwitchLogin() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                masterSDK.logout( com.ssll.dsywl.MyActivity.this);
                printLog("SwitchLogin");
            }
        });
    }

    @Override
    public void Logout() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                masterSDK.logout(com.ssll.dsywl.MyActivity.this);
                printLog("Logout");
            }
        });
    }

    @Override
    public boolean IsSupportExit() {
        return true;
    }

    @Override
    public void ExitGame() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                // 退出游戏
//        if (masterSDK.hadPlatformQuitUI()) {
                masterSDK.quit(com.ssll.dsywl.MyActivity.this, new MasterQuitCallBack() {
                    @Override
                    public void quit() {
                        // 回收sdk资源
                        masterSDK.destroySDK(mUnityPlayer.getContext());
                        finish();
                    }
                    @Override
                    public void cancel() {
                    }
                });
//        }
                printLog("ExitGame");
            }
        });
    }

    public static String md5(String str){
        String md5 = "";
        try{
            MessageDigest md = MessageDigest.getInstance("MD5");
            md.update(str.getBytes());//update处理
            byte [] encryContext = md.digest();//调用该方法完成计算
            int i;
            StringBuffer buf = new StringBuffer("");
            for (int offset = 0; offset < encryContext.length; offset++) {//做相应的转化（十六进制）
                i = encryContext[offset];
                if (i < 0) i += 256;
                if (i < 16) buf.append("0");
                buf.append(Integer.toHexString(i));
            }
            md5 = buf.toString();
        }catch (Exception e){
            e.printStackTrace();
        }

        return md5;
    }

    @Override
    public void SubmitExtraData(
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
            final String roleLevelUpTime) {

        SimpleDateFormat simpleDateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
        long ts = 0;//创建时间
        long cur_ts = 0;//当前时间
        try {
            Date date = simpleDateFormat.parse(roleCreateTime);
            ts = date.getTime();
            new Date().getTime();
        }catch (ParseException pe){
            printError(pe.getMessage());
        }

        MasterPlatformSubUserInfo.Builder info = new MasterPlatformSubUserInfo.Builder();
        info.setPower(0L)
                .setProfessionId("0")//登陆角色的职业ID，如无请填写：0
                .setProfession("0")//登陆角色的职业名称，如无请填写"无"
                .setGuildName("无")//当前角色所属帮派帮派名称，如无请填写：无
                .setGuildId("0")//当前角色所属帮派帮派Id，如无请填写:0
                .setGuildTitleId("0")//角色在帮派中的帮派称号Id,帮主则必填：1，其他可自定义，如无请填写：0
                .setGuildTitleName("0")//角色在帮派中的帮派称号,如无请填写："无"
                .setGender("无")//登陆角色的性别，不能为空，可选：“男、女、无”
                .setUserName(uid)//用户名，成功返回
                .setRoleName(roleName)//当前角色昵称
                .setRoleId(roleID)// 角色ID
                .setGameLevel(roleLevel)//当前角色等级
                .setZoneId(serverId+"")//服务器Id
                .setZoneName(serverName)//服务器名称
                .setBalance("0")
                .setRoleCTime(ts/1000)//角色创建时间(单 位:秒),长度 10, 获取服务器存储 的时间,不可用手机本地时间
                //玩家战斗力，如无请填写：0
                .setVipLevel(Vip)//当前用户的VIP等级，如无请填写：0
                .setCpTimestamp(cur_ts/1000)
                .setCpSign(md5(serverId+roleID+roleLevel+Vip+0+0+0+ts/1000+cur_ts/1000+"#"+"a7e554c4-9c5f-4511-a29b-5094ce6ff375"));
        info.setFriendsList(null);
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if(dataType == 1){

                }else if(dataType == 2){
                    masterSDK.submitUserInfo(com.ssll.dsywl.MyActivity.this, MasterGameAction.CREATE_ROLE,info.build());
                }else if(dataType == 3){
                    masterSDK.submitUserInfo(com.ssll.dsywl.MyActivity.this, MasterGameAction.ENTER_SERVER,info.build());
                    masterSDK.submitUserInfo(com.ssll.dsywl.MyActivity.this, MasterGameAction.LOGIN,info.build());
                }else if(dataType == 4){
                    masterSDK.submitUserInfo(com.ssll.dsywl.MyActivity.this, MasterGameAction.LEVEL_UP,info.build());
                }else if(dataType == 5){
                    masterSDK.submitUserInfo(com.ssll.dsywl.MyActivity.this, MasterGameAction.ROLE_LOGOUT,info.build());
                }
                printLog("SubmitExtraData");
            }
        });

    }

    @Override
    public void Pay(
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
            final String orderID) {


        MasterCpUserInfo userInfo = new MasterCpUserInfo.Builder()
                .setRoleName(roleName) // 角色名
                .setRoleId(roleID)//当前登陆的角色ID
                .setUserName(uid)// 用户名，登录成功返回
                .setGameLevel(roleLevel+"")// 角色等级
                .setVipLevel(vip)// vip等级
                .setZoneId(serverID)
                .setZoneName(serverName)
                .setBalance("0")
                .build();// 余额 rmb 单位：元

        MasterCpPayInfo payInfo = new MasterCpPayInfo();
        payInfo.setCpUserInfo(userInfo);
        payInfo.setDeveloperUrl("");// 支付回调接口
        payInfo.setAmount(price);//金额 rmb 单位：元
        payInfo.setRatio(10);// 交易比率，如1元＝10元宝，比率请填写10,默认为1:1  即1元＝1元宝
        payInfo.setProductName(productName);// 商品名
        payInfo.setProductId(rechargeId);// 商品id 001
        payInfo.setAppName("都市异闻录");// 游戏名
        payInfo.setZoneId(serverID);// （必选参数) 游戏服务器id
        payInfo.setZoneName(serverName); //服务器名称
        payInfo.setTerminalId("");// (可选参数) 设备标识符
        payInfo.setExtraData(extension);// (必填参数) CP 透传信息test
        payInfo.setProductNameNoCount(productName);//无商品数量的商品名
        payInfo.setCount(buyNum);//商品数量

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                masterSDK.doPayBySDK(com.ssll.dsywl.MyActivity.this, payInfo, new MasterCallBack<Bundle>() {
                    @Override
                    public void onSuccess(Bundle bundle) {
                        callUnityFunc("PayCallback",SUCCESS + "#" + orderID);
                        printLog("支付成功");
                    }
                    @Override
                    public void onFailed(MasterErrorInfo masterErrorInfo) {
                        callUnityFunc("PayCallback",FAILED + "#" + orderID);
                        printLog("支付失败");
                    }
                });
                printLog("Pay");
            }
        });

    }

    // @Override
    // public void SendScreenshotData(byte[] bytes) {
    // this.bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
    // }

    @Override
    public  void Bind() {
        printLog("Bind");
    }

    @Override
    public void Community(){
        printLog("Community");
    }

    @Override
    public void HelpConversation() {
        printLog("HelpConversation");
    }

    @Override
    public void FAQ() {
        printLog("FAQ");
    }

    @Override
    public void Operation() {
        printLog("Operation");
    }

    @Override
    public  void CustomEvent(int type,String param){
//	    String eventName = null;
//        Map<String, Object> eventValue = new HashMap<>();
//		switch (type)
//        {
//            case 0://通用
//            {
//                switch (param)
//                {
//					case "游戏激活": eventName = "first_open"; break;
//                    case "开始热更": eventName = "hot_update_click"; break;
//                    case "热更结束": eventName = "hot_update_suc"; break;
//                    case "热更失败": eventName = "hot_update_failed"; break;
//                    case "登录页面弹出": eventName = "login_page"; break;//sdk这边加
//                    case "登录成功": eventName = "login"; break;//sdk这边加
//                    case "进入服务器": eventName = "ACTION_ENTER_SERVER"; break;
//                    case "创建角色": eventName = "role_created"; break;
//                    case "新手引导开始": eventName = "tutorial_begin"; break;
//                    case "新手引导结束": eventName = "tutorial_complete"; break;
//                }
//            }
//            break;
//            case 1://解锁功能
//                switch (param)
//                {
//                    case "79": eventName = "unlock_guardian"; break;//守护
//                    case "85": eventName = "unlock_tower"; break;//神之塔
//                    case "8": eventName = "unlock_arena"; break;//地下竞技
//                    case "66": eventName = "unlock_research"; break;//研究所
//                    case "75": eventName = "unlock_laboratory"; break;//实验室
//                    case "20": eventName = "unlock_market"; break;//超市
//                    case "67": eventName = "unlock_Trial"; break;//试炼
//                }
//                break;
//            case 2://好友数量
//                switch (param)
//                {
//                    case "3": eventName = "task_friend3"; break;
//                }
//                break;
//            case 3://英雄数量
//                switch (param)
//                {
//                    case "3":
//                    case "10":
//                    case "30":
//                        eventName = "task_hero" + param;
//                    break;
//                }
//                break;
//            case 4://玩家升级
//                switch (param)
//                {
//                    case "5":
//                    case "10":
//                    case "15":
//                    case "20":
//                    case "50":
//                    case "70":
//                        eventName = "role_level" + param;
//                        break;
//                }
//                break;
//            case 5://vip升级
//                switch (param)
//                {
//                    case "1":
//                    case "2":
//                    case "3":
//                    case "4":
//                    case "5":
//                    case "6":
//                    case "7":
//                    case "8":
//                    case "9":
//                    case "10":
//                    case "11":
//                    case "12":
//                    case "13":
//                    case "14":
//                    case "15":
//                        eventName = "VIP_" + param;
//                        break;
//                }
//                break;
//            case 6://战斗力提升
//                {
//                    int maxPower = Integer.parseInt(param);
//                    if (maxPower >= 1000000) {
//                        eventName =  "power_100w";
//                    } else if (maxPower >= 500000) {
//                        eventName = "power_50w";
//                    } else if (maxPower >= 100000) {
//                        eventName = "power_10w";
//                    }
//                }
//                break;
//            case 7://加入公会
//                {
//                    eventName ="first_guild";
//                }
//                break;
//            case 99://充值成功
//                {
//                    if(param.equals("取消支付")) {
//                        eventName = "cancellation_payment";
//                    } else if(param.equals("支付失败")) {
//                        eventName = "payment_failed";
//                    }else if(param.equals("调出支付请求接口成功")){
//                        eventName = "payment_request";
//                    }else if(param.equals("限时特惠购买页面弹出")){
//                        eventName = "firstspecialbuyui_displayed";
//                    }else {
////                        BDGameSDK.logEvent(this, "finish_first_top-up", eventValue);
//
//                        String[] strArr = param.split("-");
//                        int showType = Integer.parseInt(strArr[0]);
//                        int proId = Integer.parseInt(strArr[1]);
//                        String price = strArr[2];
//						String currencyType = strArr[3];
//                        if (showType == 3) {
//                            if (proId == 1) {
//                                eventName = "iap_0.99buy";
//                            } else if (proId == 2) {
//                                eventName = "iap_4.99buy";
//                            } else if (proId == 3) {
//                                eventName = "iap_14.99buy";
//                            } else if (proId == 4) {
//                                eventName = "iap_29.99buy";
//                            } else if (proId == 5) {
//                                eventName = "iap_49.99buy";
//                            } else if (proId == 6) {
//                                eventName = "iap_99.99buy";
//                            }
//                        } else if (showType == 4){//成长基金
//                            eventName = "iap_upgradefund";
//                        } else if (showType == 14 || showType == 999) {//每日礼包
//                            eventName = "iap_daily";
//                        } else if (showType == 15) {
//                            if (proId != 2000) {//周礼包
//                                eventName = "iap_week";
//                            }
//                        }
//
////                        Map<String, Object> eventValues = new HashMap<>();
////                        eventValues.put(AFInAppEventParameterName.REVENUE, price);
////                        eventValues.put(AFInAppEventParameterName.CURRENCY, currencyType);
////                        BDGameSDK.logMoneyEvent(this, "purchase_success", Double.parseDouble(price), currencyType, eventValue);
//                    }
//                }
//                break;
//            default:
//                break;
//        }
//
//        if(eventName != null) {
////            BDGameSDK.logEvent( this,eventName, eventValue);
//        }
    }
}
