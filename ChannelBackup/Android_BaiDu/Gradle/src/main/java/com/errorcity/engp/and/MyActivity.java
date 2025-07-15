package com.errorcity.engp.and;

import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.widget.Toast;

import com.appsflyer.AFInAppEventParameterName;
import com.baidu.game.publish.BDGameSDK;
import com.baidu.game.publish.base.BDGameSDKSetting;
import com.baidu.game.publish.base.IResponse;
import com.baidu.game.publish.base.OnGameExitListener;
import com.baidu.game.publish.base.ResultCode;
import com.baidu.game.publish.base.payment.model.PayOrderInfo;
import com.game.base.IUnityPlayerActivity;
import com.bun.miitmdid.core.MdidSdkHelper;
import com.bun.miitmdid.interfaces.IIdentifierListener;
import com.bun.miitmdid.interfaces.IdSupplier;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HashMap;
import java.util.Map;

public class MyActivity extends IUnityPlayerActivity {
    // String orderID = null;
    Bitmap bitmap = null;
    String uid = null;
    private boolean isSwic = false;

	@Override
    public void Init() {
        BDGameSDKSetting mBDGameSDKSetting = new BDGameSDKSetting();
        mBDGameSDKSetting.setAppID(24729330); // APPID设置
        mBDGameSDKSetting.setAppKey("0PrsSVgqf6Ip13xFxv5LuP2f"); // APPKEY设置
        mBDGameSDKSetting.setMode(BDGameSDKSetting.SDKMode.ONLINE); //
        mBDGameSDKSetting.setDomain(BDGameSDKSetting.Domain.DEBUG); // 测试阶段为DEBUG，待测试通过设置为正式模式RELEASE
        mBDGameSDKSetting.setOrientation(BDGameSDKSetting.Orientation.PORTRAIT);

        BDGameSDK.init(this, mBDGameSDKSetting, new IResponse<Void>() {
            @Override
            public void onResponse(int resultCode, String resultDesc,
                                   Void extraData) {
                switch (resultCode) {
                    case ResultCode.INIT_SUCCESS:
                        // 初始化成功
                        callUnityFunc("InitCallback",SUCCESS);
                        printLog("Init化成功");
                        break;
                    case ResultCode.INIT_FAIL:
                    default:
                        // 初始化失败
                        printLog("Init失败");
                        finish();
                }
            }
        });

        /**
         * 设置登录态失效监听
         * 触发条件：账号登出、账号在另一台设备登录
         */
        BDGameSDK.setSessionInvalidListener(new IResponse<Void>() {
            @Override
            public void onResponse(int resultCode, String resultDesc, Void extraData) {
                printLog("登录状态失效");
            }
        });

        BDGameSDK.setChangeAccountListener(this, new IResponse<Void>() {
            @Override
            public void onResponse(int resultCode, String resultDesc, Void extraData) {
                printLog("切换账号回调：" + resultCode + " " + resultDesc);
            }
        });


        MdidSdkHelper.InitSdk(getApplicationContext(), true, new IIdentifierListener() {
            @Override
            public void OnSupport(boolean b, IdSupplier idSupplier) {
                if (idSupplier != null && idSupplier.isSupported()) {
                    String Oaid = idSupplier.getOAID();
                    BDGameSDK.setOAID(Oaid); // setoaidCP
                }
            }
        });

        BDGameSDK.checkGooglePay(MyActivity.this, new IResponse<PayOrderInfo>() {
            @Override
            public void onResponse(int resultCode, String resultDesc, PayOrderInfo payOrderInfo) {
                if (ResultCode.PAY_CHECK_SUCCESS == resultCode && payOrderInfo != null) {
                    String resultStr = resultDesc;
                    // 获取该订单的商品Id Google后台配置的商品Sku
                    resultStr += "商品ID：" + payOrderInfo.getProductId();
                    // 获取该订单的cp订单号 创建订单时cp传的订单号
                    resultStr += "cp订单号：" + payOrderInfo.getCooperatorOrderSerial();
                    printLog("Google支付查询本地掉单成功：" + resultStr);
                } else {
                    printLog("Google支付查询本地掉单失败：" + resultDesc);
                }
            }
        });

        printLog("Init");
    }

	@Override
    public void Login() {
        BDGameSDK.login(this,new IResponse<Void>() {
            @Override
            public void onResponse(int resultCode, String resultDesc,
                                   Void extraData) {
                String resultStr = "";
                switch (resultCode) {
                    case ResultCode.LOGIN_SUCCESS: {
                        resultStr = "登录成功";
                        uid =  BDGameSDK.getLoginUid();
                        String tokens = BDGameSDK.getLoginAccessToken(); //登录token
                        isSwic = false;

                        String context = 24729330 + tokens + "W70xo8VyfRAyrfYRTVSPIUAk1FoZh6Xy";
                        try {
                            MessageDigest md = MessageDigest.getInstance("MD5");
                            md.update(context.getBytes());//update处理
                            byte [] encryContext = md.digest();//调用该方法完成计算

                            int i;
                            StringBuffer buf = new StringBuffer("");
                            for (int offset = 0; offset < encryContext.length; offset++) {//做相应的转化（十六进制）
                                i = encryContext[offset];
                                if (i < 0) i += 256;
                                if (i < 16) buf.append("0");
                                buf.append(Integer.toHexString(i));
                            }

                            callUnityFunc("LoginCallback", String.valueOf(1) + "#" + uid + "#" + buf.toString().toLowerCase() + "#" + tokens);
                        } catch (NoSuchAlgorithmException e) {
                            // TODO Auto-generated catch block
                            e.printStackTrace();
                        }
                    }
                    break;
                    case ResultCode.LOGIN_CANCEL: {
                        resultStr = "登录取消";
                    }
                    break;
                    case ResultCode.LOGIN_FAIL:
                    default: {
                        resultStr = "登录失败:" + resultDesc;
                    }
                }
                printLog("登录结果:" + resultStr);
            }
        });
        printLog("Login");
        callUnityFunc("DebugSdk", "开始登录");
    }
	
	@Override
    public void SwitchLogin() {
        BDGameSDK.changeAccount(this);
        printLog("SwitchLogin");
    }

	@Override
    public void Logout() {
        printLog("Logout");
        callUnityFunc("LogoutCallback",SUCCESS);
    }
	
	@Override
    public boolean IsSupportExit() {
        return true;
    }
	
	@Override
    public void ExitGame() {
        BDGameSDK.gameExit(this, new OnGameExitListener() {
            @Override
            public void onGameExit() {
                finish();
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
        try {
            BDGameSDK.updateGameCharacter(this,roleName,roleID,zoneName,zoneID,roleLevel,Vip,dataType == 2);
        } catch (Exception e) {
            e.printStackTrace();
        }
        printLog("SubmitExtraData");
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

        PayOrderInfo payOrderInfo = new PayOrderInfo();
        payOrderInfo.setProductId(rechargeId);
        payOrderInfo.setCooperatorOrderSerial(orderID);
        payOrderInfo.setExtInfo(extension);
        payOrderInfo.setCpUid(BDGameSDK.getLoginUid()); // 必传字段，需要验证uid是否合法

        CustomEvent(99,"调出支付请求接口成功");
        BDGameSDK.pay(MyActivity.this, payOrderInfo, null,
                new IResponse<PayOrderInfo>() {
                    @Override
                    public void onResponse(int resultCode, String resultDesc,
                                           PayOrderInfo extraData) {
                        String resultStr = "";
                        switch (resultCode) {
                            case ResultCode.PAY_SUCCESS: // 支付成功
                                resultStr = "支付成功" + resultDesc;
                                callUnityFunc("PayCallback",SUCCESS + "#" + orderID);

                                CustomEvent(99,showType + "-" + productId + "-" + price + "-" + currencyType);
                                break;
                            case ResultCode.PAY_CANCEL: // 订单支付取消
                                resultStr = "支付取消";

                                CustomEvent(99,"取消支付");
                                break;
                            case ResultCode.PAY_FAIL: // 订单支付失败
                                resultStr = "支付失败" + resultDesc;
                                callUnityFunc("PayCallback",FAILED + "#" + orderID);

                                CustomEvent(99,"支付失败");
                                break;
                            case ResultCode.PAY_SUBMIT_ORDER: // 订单已经提交，支付结果未知（比如：已经请求了，但是查询超时）
                                resultStr = "订单已经提交，支付结果未知";
                                break;
                            default:
                                resultStr = "订单已经提交，支付结果未知";
                                break;
                        }
                        printLog("支付结果：" + resultStr);
                    }
                });

        printLog("Pay");
    }

    // @Override
    // public void SendScreenshotData(byte[] bytes) {
    // this.bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
    // }

    @Override
    public  void Bind() {
        if (BDGameSDK.BindCode.CHANGE_BIND == BDGameSDK.getBindOperationType()) {
            BDGameSDK.changeBindAccount(this, new IResponse<Void>() {
                @Override
                public void onResponse(int resultCode, String resultDesc, Void extraData) {
                    if(resultCode == ResultCode.BIND_SUCCESS){
                        printLog("换绑成功！");
                    }else  if(resultCode == ResultCode.BIND_CANCEL){
                        printLog("换绑取消！");
                    }else  if(resultCode == ResultCode.BIND_FAIL){
                        printLog("换绑失败！" + resultDesc);
                    }
                }
            });
        }else if (BDGameSDK.BindCode.BIND == BDGameSDK.getBindOperationType()) {
            BDGameSDK.bindAccount(this, new IResponse<Void>() {
                @Override
                public void onResponse(int resultCode, String resultDesc, Void extraData) {
                    if(resultCode == ResultCode.BIND_SUCCESS){
                        printLog("绑定成功！");
                    }else  if(resultCode == ResultCode.BIND_CANCEL){
                        printLog("绑定取消！");
                    }else  if(resultCode == ResultCode.BIND_FAIL){
                        printLog("绑定失败！" + resultDesc);
                    }
                }
            });
        }else{
            //Toast.makeText(getApplicationContext(), "换绑与绑定功能都不可用", Toast.LENGTH_LONG).show();
            printLog("换绑与绑定功能都不可用");
        }

        printLog("Bind");
    }

    @Override
    public void Community(){
        startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.facebook.com/Error-City-SEA-100923279044170/?ref=page_internal")));
        printLog("Community");
    }

    @Override
    public void HelpConversation() {
        BDGameSDK.bdShowHelpConversation();
        printLog("HelpConversation");
    }

    @Override
    public void FAQ() {
        BDGameSDK.bdShowFAQ();
        printLog("FAQ");
    }

    @Override
    public void Operation() {
        BDGameSDK.bdShowOperation();
        printLog("Operation");
    }

    @Override
	public  void CustomEvent(int type,String param){
	    String eventName = null;
        Map<String, Object> eventValue = new HashMap<>();
		switch (type)
        {
            case 0://通用
            {
                switch (param)
                {
					case "游戏激活": eventName = "first_open"; break;
                    case "开始热更": eventName = "hot_update_click"; break;
                    case "热更结束": eventName = "hot_update_suc"; break;
                    case "热更失败": eventName = "hot_update_failed"; break;
                    case "登录页面弹出": eventName = "login_page"; break;//sdk这边加
                    case "登录成功": eventName = "login"; break;//sdk这边加
                    case "进入服务器": eventName = "ACTION_ENTER_SERVER"; break;
                    case "创建角色": eventName = "role_created"; break;
                    case "新手引导开始": eventName = "tutorial_begin"; break;
                    case "新手引导结束": eventName = "tutorial_complete"; break;
                }
            } 
            break;
            case 1://解锁功能
                switch (param)
                {
                    case "79": eventName = "unlock_guardian"; break;//守护
                    case "85": eventName = "unlock_tower"; break;//神之塔
                    case "8": eventName = "unlock_arena"; break;//地下竞技
                    case "66": eventName = "unlock_research"; break;//研究所
                    case "75": eventName = "unlock_laboratory"; break;//实验室
                    case "20": eventName = "unlock_market"; break;//超市
                    case "67": eventName = "unlock_Trial"; break;//试炼
                }
                break;
            case 2://好友数量
                switch (param)
                {
                    case "3": eventName = "task_friend3"; break;
                }
                break;
            case 3://英雄数量
                switch (param)
                {
                    case "3":
                    case "10":
                    case "30":
                        eventName = "task_hero" + param;
                    break;
                }
                break;
            case 4://玩家升级
                switch (param)
                {
                    case "5":
                    case "10":
                    case "15":
                    case "20":
                    case "50":
                    case "70":
                        eventName = "role_level" + param;
                        break;
                }
                break;
            case 5://vip升级
                switch (param)
                {
                    case "1":
                    case "2":
                    case "3":
                    case "4":
                    case "5":
                    case "6":
                    case "7":
                    case "8":
                    case "9":
                    case "10":
                    case "11":
                    case "12":
                    case "13":
                    case "14":
                    case "15":
                        eventName = "VIP_" + param;
                        break;
                }
                break;
            case 6://战斗力提升
                {
                    int maxPower = Integer.parseInt(param);
                    if (maxPower >= 1000000) {
                        eventName =  "power_100w";
                    } else if (maxPower >= 500000) {
                        eventName = "power_50w";
                    } else if (maxPower >= 100000) {
                        eventName = "power_10w";
                    }
                }
                break;
            case 7://加入公会
                {
                    eventName ="first_guild";
                }
                break;
            case 99://充值成功
                {
                    if(param.equals("取消支付")) {
                        eventName = "cancellation_payment";
                    } else if(param.equals("支付失败")) {
                        eventName = "payment_failed";
                    }else if(param.equals("调出支付请求接口成功")){
                        eventName = "payment_request";
                    }else if(param.equals("限时特惠购买页面弹出")){
                        eventName = "firstspecialbuyui_displayed";
                    }else {
                        BDGameSDK.logEvent(this, "finish_first_top-up", eventValue);

                        String[] strArr = param.split("-");
                        int showType = Integer.parseInt(strArr[0]);
                        int proId = Integer.parseInt(strArr[1]);
                        String price = strArr[2];
						String currencyType = strArr[3]; 
                        if (showType == 3) {
                            if (proId == 1) {
                                eventName = "iap_0.99buy";
                            } else if (proId == 2) {
                                eventName = "iap_4.99buy";
                            } else if (proId == 3) {
                                eventName = "iap_14.99buy";
                            } else if (proId == 4) {
                                eventName = "iap_29.99buy";
                            } else if (proId == 5) {
                                eventName = "iap_49.99buy";
                            } else if (proId == 6) {
                                eventName = "iap_99.99buy";
                            }
                        } else if (showType == 4){//成长基金
                            eventName = "iap_upgradefund";
                        } else if (showType == 14 || showType == 999) {//每日礼包
                            eventName = "iap_daily";
                        } else if (showType == 15) {
                            if (proId != 2000) {//周礼包
                                eventName = "iap_week";
                            }
                        }
						
//                        Map<String, Object> eventValues = new HashMap<>();
//                        eventValues.put(AFInAppEventParameterName.REVENUE, price);
//                        eventValues.put(AFInAppEventParameterName.CURRENCY, currencyType);
                        BDGameSDK.logMoneyEvent(this, "purchase_success", Double.parseDouble(price), currencyType, eventValue);
                    }
                }
                break;
            default:
                break;
        }

        if(eventName != null) {
            BDGameSDK.logEvent( this,eventName, eventValue);
        }
	}
}
