package com.cyywl.cthy;

import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.os.Bundle;

import com.chitu350.game.sdk.ChituCode;
import com.chitu350.game.sdk.ChituPayParams;
import com.chitu350.game.sdk.ChituUserExtraData;
import com.chitu350.game.sdk.connect.ChituSDKCallBack;

import com.chitu350.game.sdk.verify.ChituToken;
import com.chitu350.mobile.ChituPlatform;
import com.game.base.IUnityPlayerActivity;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;

public class MyActivity extends IUnityPlayerActivity {

    String _orderID;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ChituPlatform.getInstance().chituSplashOnCreate(this);

        ChituPlatform.getInstance().chituInitSDK(this, savedInstanceState, new ChituSDKCallBack() {
            @Override
            public void onInitResult(int resultCode) {
                if (resultCode == ChituCode.CODE_INIT_SUCCESS) {
                    printLog("初始化成功");
                } else {
                    printLog("初始化失败");
                }
            }
            @Override
            public void onLoginResult(ChituToken authResult) {
                if (authResult.isSuc()) {
                    uid = authResult.getUserID();
                    String tokens = authResult.getToken(); //登录token
                    String timestamp = authResult.getTimestamp();
                    //结果(1成功0失败)#uid(SDK获取，没有就不管)#自定义(预留参数)#token(SDK获取)
                    callUnityFunc("LoginCallback", String.valueOf(1) + "#" + uid + "#" + timestamp + "#" + tokens);
                    printLog("登录成功");
                } else {
                    printLog("登录失败");
                }
            }
            @Override
            public void onLogoutResult(int resultCode) {
                callUnityFunc("LogoutCallback",SUCCESS);
                printLog("登出成功");
            }
            @Override
            public void onExit() {
                MyActivity.this.finish();
                printLog("退出成功");
            }
            @Override
            public void onPayResult(int resultCode) {
                if (resultCode == ChituCode.CODE_PAY_SUCCESS) {
                    callUnityFunc("PayCallback",SUCCESS + "#" + _orderID);
                    printLog("支付成功");
                } else if (resultCode == ChituCode.CODE_PAY_FAIL) {
                    callUnityFunc("PayCallback",FAILED + "#" + _orderID);
                    printLog("支付失败");
                } else if (resultCode == ChituCode.CODE_PAY_CANCEL) {
                }else if (resultCode == ChituCode.CODE_PAY_COMPLETE){
                    //什么也不用干
                }
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        ChituPlatform.getInstance().chituSplashOnResume(this);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        ChituPlatform.getInstance().chituSplashNewIntent(intent);
    }

    @Override
    public void onBackPressed() {
        ChituPlatform.getInstance().chituExit(this);
    }

    @Override
    protected void onStart() {
        super.onStart();
        ChituPlatform.getInstance().chituOnStart();
    }

    @Override
    protected void onPause() {
        super.onPause();
        ChituPlatform.getInstance().chituOnPause();
    }

    @Override
    protected void onStop() {
        super.onStop();
        ChituPlatform.getInstance().chituOnStop();
    }

    @Override
    protected void onRestart() {
        super.onRestart();
        ChituPlatform.getInstance().chituOnRestart();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        ChituPlatform.getInstance().chituOnDestroy();
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        ChituPlatform.getInstance().chituOnConfigurationChanged(newConfig);
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        ChituPlatform.getInstance().chituOnSaveInstanceState(outState);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        ChituPlatform.getInstance().chituOnActivityResult(requestCode, resultCode, data);
    }

    @Override
    protected void attachBaseContext(Context newBase) {
        super.attachBaseContext(newBase);
        ChituPlatform.getInstance().chituattachBaseContext(newBase);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode,permissions,grantResults);
        ChituPlatform.getInstance().chituOnRequestPermissionsResult(requestCode,
                permissions, grantResults);
    }

    // String orderID = null;
    Bitmap bitmap = null;
    String uid = null;
    private boolean isSwic = false;

    @Override
    public void Init(){
        callUnityFunc("InitCallback",SUCCESS);
        printLog("Init");
    }

    @Override
    public void Login() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                ChituPlatform.getInstance().chituLogin(MyActivity.this);

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
                ChituPlatform.getInstance().chituLogout(MyActivity.this);
                printLog("SwitchLogin");
            }
        });
    }

    @Override
    public void Logout() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                ChituPlatform.getInstance().chituLogout(MyActivity.this);
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
                ChituPlatform.getInstance().chituExit(MyActivity.this);
                printLog("ExitGame");
            }
        });
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

        ChituUserExtraData extraData = new ChituUserExtraData ();
        if (dataType == 2) {
            extraData.setDataType(ChituUserExtraData.TYPE_CREATE_ROLE);
        }
        else if (dataType == 3){
            extraData.setDataType(ChituUserExtraData.TYPE_ENTER_GAME);
        }
        else if (dataType == 4){
            extraData.setDataType(ChituUserExtraData.TYPE_LEVEL_UP);
        }
//        extraData.setDataType(ChituUserExtraData.TYPE_CREATE_ROLE); // 调用时机，具体见文档3.6
        extraData.setServerID(serverId + ""); // 未获取到服务器时传0，传入的值必须保证能转换成整型
        extraData.setServerName(serverName); // 未获取到服务器名称时传空
        extraData.setRoleName(roleName); // 角色未获取或未创建时传空
        extraData.setRoleLevel(roleLevel); // 当前角色等级,未获取到角色等级时传空，如果有转生特殊等级, 按小数格式传递， 0.99(0转99级)
        extraData.setRoleID(roleID); // 当前角色id,未获取角色id时传空
        extraData.setMoneyNum(moneyNum + ""); // 玩家身上元宝数量，拿不到或者未获取时传0
        extraData.setRoleCreateTime(ts/1000); // 角色创建时间，未获取或未创建角色时传0
        extraData.setGuildId(guildlD);// 公会id，无公会或未获取时传空
        extraData.setGuildName("0");// 公会名称，无公会或未获取时传空
        extraData.setGuildLevel("0");// 公会等级，无公会或未获取时传0
        extraData.setGuildLeader("0");// 公会会长名称，无公会或未获取时传空
        extraData.setPower(0);// 角色战斗力, 不能为空，必须是数字，不能为null,若无,传0
        extraData.setProfessionid(0);//职业ID，不能为空，必须为数字，若无，传入 0
        extraData.setProfession("无");//职业名称，不能为空，不能为 null，若无，传入 “无”
        extraData.setGender("无");//角色性别，不能为空，不能为 null，可传入参数“ 男、女、无”
        extraData.setProfessionroleid(0);//职业称号ID，不能为空，不能为 null，若无，传入 0
        extraData.setProfessionrolename("无");//职业称号，不能为空，不能为 null，若无，传入“ 无”
        extraData.setVip(Integer.parseInt(Vip));//玩家VIP等级，不能为空，必须为数字,若无，传入 0
        extraData.setExt("");//扩展字段 例如几转等级，飞升等级

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                ChituPlatform.getInstance().chituSubmitExtendData (MyActivity.this,extraData);
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

        ChituPayParams params = new ChituPayParams ();
        params.setBuyNum(1);    //写默认1
        params.setCoinNum(100);  //写默认100
        params.setExtension(extension);    //透传参数
        params.setPrice(price);         //单位是元
        params.setProductId(productId + "");
        params.setProductName(productName);
        params.setProductDesc(productDesc);
        params.setRoleId(roleID + "");
        params.setRoleLevel(roleLevel);
        params.setRoleName(roleName);
        params.setServerId(serverID);
        params.setServerName(serverName);
        params.setVip(vip);

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                _orderID = orderID;
                ChituPlatform.getInstance().chituPay(MyActivity.this, params);
                printLog("Pay");
            }
        });
    }

    // @Override
    // public void SendScreenshotData(byte[] bytes) {
    // this.bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
    // }

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
