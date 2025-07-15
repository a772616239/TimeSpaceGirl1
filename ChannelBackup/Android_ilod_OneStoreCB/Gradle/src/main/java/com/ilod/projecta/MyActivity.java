package com.ilod.projecta;

import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.widget.Toast;

import com.game.base.IUnityPlayerActivity;


import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import io.gamepot.channel.GamePotAppStatusChannelListener;
import io.gamepot.channel.GamePotAppStatusChannelLoginDialogListener;
import io.gamepot.channel.GamePotChannel;
import io.gamepot.channel.GamePotChannelListener;
import io.gamepot.channel.GamePotChannelLoginBuilder;
import io.gamepot.channel.GamePotChannelType;
import io.gamepot.channel.GamePotUserInfo;
import io.gamepot.channel.google.signin.GamePotGoogleSignin;
import io.gamepot.channel.naver.GamePotNaver;
import io.gamepot.common.GamePot;
import io.gamepot.common.GamePotAppCloseListener;
import io.gamepot.common.GamePotAppStatus;
import io.gamepot.common.GamePotChat;
import io.gamepot.common.GamePotCommonListener;
import io.gamepot.common.GamePotError;
import io.gamepot.common.GamePotListener;
import io.gamepot.common.GamePotNoticeDialog;
import io.gamepot.common.GamePotPurchaseInfo;
import io.gamepot.common.GamePotPurchaseListener;
import io.gamepot.common.GamePotSendLog;
import io.gamepot.common.GamePotSendLogCharacter;

public class MyActivity extends IUnityPlayerActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // 重置GAMEPOT。context必须输入application context。
        // 在调用其他API前，最先调用setup API。
        GamePot.getInstance().setup(getApplicationContext());
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        // 为进行登录处理需要
        GamePotChannel.getInstance().onActivityResult(this, requestCode, resultCode, data);
        GamePot.getInstance().onActivityResult(requestCode, resultCode, data);
    }

    @Override
    protected void onStart() {
        super.onStart();
        GamePotChat.getInstance().start();
        GamePot.getInstance().onStart(this);
    }

    @Override
    protected void onStop() {
        super.onStop();
        GamePotChat.getInstance().stop();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        GamePotChannel.getInstance().onDestroy();
        GamePot.getInstance().onDestroy();
    }


    String _orderID = null;
    Bitmap bitmap = null;
    String uid = null;
    private boolean isSwic = false;

    @Override
    public void Init() {
//        //GamePot日志初始化。收集的日志可在NCP上的ELSA仪表板上查看。
//        GamePotLogger.init(getApplication());
//        GamePotLogger.d("app start");

        //GamePot通道初始化。必须按要使用的频道添加Channel，默认包括guest方式。
        GamePotChannel.getInstance().addChannel(this, GamePotChannelType.GOOGLE, new GamePotGoogleSignin());
        GamePotChannel.getInstance().addChannel(this, GamePotChannelType.NAVER, new GamePotNaver());

        GamePot.getInstance().setPurchaseListener(new GamePotPurchaseListener<GamePotPurchaseInfo>() {
            @Override
            public void onSuccess(GamePotPurchaseInfo info) {
                callUnityFunc("PayCallback",SUCCESS + "#" + _orderID);
//                sendMessage("结算成功", info.toJSONString());
//                sendMessage("结算金额", "" + Double.parseDouble(info.getPrice()));
                printLog("支付成功");
            }

            @Override
            public void onFailure(GamePotError error) {
                callUnityFunc("PayCallback",FAILED + "#" + _orderID);
//                sendMessage("支付失败", error.toJSONString());
                printLog("支付失败");
            }

            @Override
            public void onCancel() {
//                sendMessage("取消付款", "用户取消");
                printLog("用户取消");
            }
        });

        // 开启/关闭推送接收
        GamePot.getInstance().setPushEnable(true, new GamePotCommonListener() {
            @Override
            public void onSuccess() {
            }

            @Override
            public void onFailure(GamePotError error) {
            }
        });

        // 开启/关闭夜间推送接收
        GamePot.getInstance().setNightPushEnable(true, new GamePotCommonListener() {
            @Override
            public void onSuccess() {
            }

            @Override
            public void onFailure(GamePotError error) {
            }
        });

        // 推送/夜间推送同时设置
        // 如果是登录前需要确认是否允许推送/夜间推送的游戏，登录后必须调用以下代码。
        GamePot.getInstance().setPushEnable(true, true, true, new GamePotCommonListener() {
            @Override
            public void onSuccess() {
            }

            @Override
            public void onFailure(GamePotError error) {
            }
        });

        callUnityFunc("InitCallback",SUCCESS);
        printLog("Init");
    }

    //登录成功后处理
    private void loginBack(GamePotUserInfo info) {
        // userinfo.getMemberid()：会员固有ID
//        uid = GamePot.getInstance().getMemberId();
        callUnityFunc("LoginCallback", String.valueOf(1) + "#" + info.getMemberid() + "#" + "" + "#" + info.getToken());
        printLog("登录成功");
    }

    @Override
    public void Login() {

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                // 传输用户最后登录信息的API
                final GamePotChannelType lastLoginType = GamePotChannel.getInstance().getLastLoginType();

                if(lastLoginType != GamePotChannelType.NONE) {
                    // 以最后一次登录的类型登录的方式。
                    GamePotChannel.getInstance().login(MyActivity.this, lastLoginType, new GamePotChannelListener<GamePotUserInfo>() {
                        @Override
                        public void onCancel() {
                            printLog("登录取消");
                        }

                        @Override
                        public void onSuccess(GamePotUserInfo info) {
                            // 自动登录成功。请根据游戏逻辑进行处理。
                            loginBack(info);
                        }

                        @Override
                        public void onFailure(GamePotError error) {
                            // 自动登录失败。请使用error.getMessage()显示错误消息。
                            printLog("登录失败");
                        }
                    });
                }
                else
                {
                    // 第一次运行游戏或已退出登录的状态。请跳转到可以进行登录的登录界面。
                    ArrayList<GamePotChannelType> channelList = new ArrayList<>(Arrays.asList(GamePotChannelType.GOOGLE, GamePotChannelType.NAVER, GamePotChannelType.GUEST));
                    GamePotChannelLoginBuilder builder = new GamePotChannelLoginBuilder(channelList);
                    //builder.setShowLogo(true);
                    GamePotChannel.getInstance().showLoginWithUI(MyActivity.this, builder, new GamePotAppStatusChannelLoginDialogListener<GamePotUserInfo>() {
                        @Override
                        public void onExit() {
                            // 点击X按钮时处理
                            printLog("关闭选择登录窗口");
                        }

                        @Override
                        public void onNeedUpdate(GamePotAppStatus status) {
                            // TODO：需要强制更新时， 调用以下API，即可弹出SDK自主弹窗。
                            // TODO：需要自定义时，无需调用以下API，直接自定义即可。
                            GamePot.getInstance().showAppStatusPopup(MyActivity.this, status, new GamePotAppCloseListener() {
                                @Override
                                public void onClose() {
                                    // TODO：调用showAppStatusPopup API时，在必须关闭应用的情况下调用。
                                    // TODO：请处理结束进程。
                                    MyActivity.this.finish();
                                }

                                @Override
                                public void onNext(Object obj) {
                                    // TODO：在仪表盘更新设置中建议设置时，显示“下次进行”按钮。
                                    // 用户选择该按钮时调用。
                                    // TODO：使用obj信息，与成功登录时做相同的处理。
                                    // GamePotUserInfo userInfo = (GamePotUserInfo)obj;
                                    loginBack((GamePotUserInfo)obj);
                                }
                            });
                        }

                        @Override
                        public void onMainternance(GamePotAppStatus status) {

                            callUnityFunc("MessageCallback","게임 유지 보수 중");

                            // TODO：正在维护时， 调用以下API，即可弹出SDK自主弹窗。
                            // TODO：需要自定义时，无需调用以下API，直接自定义即可。
                            GamePot.getInstance().showAppStatusPopup(MyActivity.this, status, new GamePotAppCloseListener() {
                                @Override
                                public void onClose() {
                                    // TODO：调用showAppStatusPopup API时，在必须关闭应用的情况下调用。
                                    // TODO：请处理结束进程。
                                    MyActivity.this.finish();
                                }

                                @Override
                                public void onNext(Object o) {
                                    loginBack((GamePotUserInfo)o);
                                }
                            });
                        }

                        @Override
                        public void onCancel() {
                            // 用户取消登录时的情况。
                            printLog("登录取消");
                        }

                        @Override
                        public void onSuccess(GamePotUserInfo userinfo) {
                            // 登录成功。请根据游戏逻辑处理。
                            loginBack(userinfo);
                        }

                        @Override
                        public void onFailure(GamePotError error) {
                            // 登录失败，请通过error.getMessage()显示错误消息。
                            printLog("登录失败");
                        }
                    });
                }
            }
        });

        printLog("Login");
        callUnityFunc("DebugSdk", "开始登录");
    }

    @Override
    public void SwitchLogin() {
        //退出
        GamePotChannel.getInstance().logout(this, new GamePotCommonListener() {
            @Override
            public void onSuccess() {
                // 成功退出登录。请转到初始界面。
                callUnityFunc("LogoutCallback",SUCCESS);
            }

            @Override
            public void onFailure(GamePotError error) {
                // 退出失败。请使用error.getMessage()显示错误消息。
                printLog("退出失败");
            }
        });
        printLog("SwitchLogin");
    }

    @Override
    public void Logout() {
        //退出
        GamePotChannel.getInstance().logout(this, new GamePotCommonListener() {
            @Override
            public void onSuccess() {
                // 成功退出登录。请转到初始界面。
                callUnityFunc("LogoutCallback",SUCCESS);
            }

            @Override
            public void onFailure(GamePotError error) {
                // 退出失败。请使用error.getMessage()显示错误消息。
                printLog("退出失败");
            }
        });
        printLog("Logout");
    }

    @Override
    public boolean IsSupportExit() {
        return false;
    }

    @Override
    public void ExitGame() {
//        finish();
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

            if(dataType == 3){
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        GamePot.getInstance().showNotice(MyActivity.this, true, new GamePotNoticeDialog.onSchemeListener() {
                            @Override
                            public void onReceive(String scheme) {
                                // scheme处理
                            }
                        });
                    }
                });
            }

            GamePotSendLogCharacter obj = new GamePotSendLogCharacter();
            obj.put(GamePotSendLogCharacter.NAME, roleName);
            obj.put(GamePotSendLogCharacter.LEVEL, roleLevel);
            obj.put(GamePotSendLogCharacter.SERVER_ID, zoneID);
            obj.put(GamePotSendLogCharacter.PLAYER_ID, roleID);
            obj.put(GamePotSendLogCharacter.USERDATA, guildlD);
            // result：日志传送成功时为true，否则为false
            boolean result = GamePotSendLog.characterInfo(obj);
            if(result) {
                printLog("上报成功！");
            }else {
                printLog("上报失败！");
            }
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

        _orderID = orderID;
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                GamePot.getInstance().purchase(rechargeId,"",serverID,roleID,extension);
            }
        });

        printLog("Pay");
    }

    // @Override
    // public void SendScreenshotData(byte[] bytes) {
    // this.bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
    // }

    @Override
    public void CustomerService() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                GamePot.getInstance().showCSWebView(MyActivity.this);
            }
        });
        printLog("CustomerService");
    }

    @Override
    public void Relation(String type) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {

                if(GamePotChannel.getInstance().getLastLoginType() != GamePotChannelType.GUEST) {
                    callUnityFunc("MessageCallback","현재 비관광객 로그인！");//当前非游客登录！
                    return;
                }

                GamePotChannelType gamePotChannelType = GamePotChannelType.NONE;
                if (type.equals("google")){
                    gamePotChannelType = GamePotChannelType.GOOGLE;
                }else if(type.equals("naver")){
                    gamePotChannelType = GamePotChannelType.NAVER;
                }
                GamePotChannel.getInstance().createLinking(MyActivity.this, gamePotChannelType, new GamePotChannelListener<GamePotUserInfo>() {
                    @Override
                    public void onSuccess(GamePotUserInfo userInfo) {
                        // 关联成功。请显示关联结果的相关消息。（例如：“账户关联成功。”）
                        printLog("关联成功");
                        callUnityFunc("MessageCallback","연결 성공");
                    }
                    @Override
                    public void onCancel() {
                        // 用户取消账户关联流程
                        printLog("用户取消");
                        callUnityFunc("MessageCallback","사용자 취소");
                    }
                    @Override
                    public void onFailure(GamePotError error) {
                        // 关联失败。请使用error.getMessage()显示错误消息。
                        printLog("关联失败");
                        callUnityFunc("MessageCallback","연결 실패");
                    }
                });
            }
        });
        printLog("Relation");
    }

    @Override
    public void Cancellation() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                GamePotChannel.getInstance().deleteMember(MyActivity.this, new GamePotCommonListener() {
                    @Override
                    public void onSuccess() {
                        // 会员注销成功。请转到初始界面。
                        callUnityFunc("LogoutCallback",SUCCESS);
                    }

                    @Override
                    public void onFailure(GamePotError error) {
                        // 会员注销失败。请使用error.getMessage()显示错误消息。
                        printLog("注销失败");
                    }
                });
            }
        });
        printLog("Cancellation");
    }

    @Override
    public boolean IsCDKey() {
        return true;
    }

    @Override
    public void CDKey(String cdkey,String serverID,String roleID){
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                GamePot.getInstance().coupon(cdkey,roleID +"#"+serverID+"#"+cdkey, new GamePotListener<String>() {
                    @Override
                    public void onSuccess(String message) {
                        // TODO : message 将变量显示为游戏弹出
                        callUnityFunc("MessageCallback",message);
                        printLog("兑换成功");
                    }

                    @Override
                    public void onFailure(GamePotError error) {
                        // TODO : message 将变量显示为游戏弹出
                        callUnityFunc("MessageCallback",error.toJSONString());
                        printLog("兑换失败");
                    }
                });
            }
        });

        printLog("CDKey");
    }

    @Override
    public void LoginPanel_Btn1(){
        startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://kr.object.ncloudstorage.com/gamepot-xubrl8yv/page/index.html?id=13abc4ef-7632-481b-8bd6-95e35a8a675d")));
        printLog("LoginPanel_Btn1");
    }

    @Override
    public void LoginPanel_Btn2(){
        startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://kr.object.ncloudstorage.com/gamepot-xubrl8yv/page/index.html?id=d41796bf-2c2f-4270-81a1-278ef0fd6d4a")));
        printLog("LoginPanel_Btn2");
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
//                        BDGameSDK.logEvent(this, "finish_first_top-up", eventValue);
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
//                        BDGameSDK.logMoneyEvent(this, "purchase_success", Double.parseDouble(price), currencyType, eventValue);
//                    }
//                }
//                break;
//            default:
//                break;
//        }
//
//        if(eventName != null) {
//            BDGameSDK.logEvent( this,eventName, eventValue);
//        }
    }
}
