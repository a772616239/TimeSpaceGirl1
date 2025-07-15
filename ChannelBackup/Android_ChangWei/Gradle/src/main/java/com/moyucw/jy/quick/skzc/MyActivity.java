package com.moyucw.jy.quick.skzc;

import android.Manifest;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;

import com.game.base.IUnityPlayerActivity;
import com.quicksdk.Extend;
import com.quicksdk.Payment;
import com.quicksdk.QuickSDK;
import com.quicksdk.Sdk;
import com.quicksdk.User;
import com.quicksdk.entity.GameRoleInfo;
import com.quicksdk.entity.OrderInfo;
import com.quicksdk.entity.UserInfo;
import com.quicksdk.notifier.ExitNotifier;
import com.quicksdk.notifier.InitNotifier;
import com.quicksdk.notifier.LoginNotifier;
import com.quicksdk.notifier.LogoutNotifier;
import com.quicksdk.notifier.PayNotifier;
import com.quicksdk.notifier.SwitchAccountNotifier;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;

public class MyActivity extends IUnityPlayerActivity {

    boolean isInit = false;

    String createTime;
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        QuickSDK.getInstance().setInitNotifier(new InitNotifier() {
            @Override
            public void onSuccess() {
                isInit = true;
                login();
                printLog("初始化成功");
            }
            @Override
            public void onFailed(String message, String trace) {
                printLog("初始化失败");
            } });
        QuickSDK.getInstance().setLoginNotifier(new LoginNotifier() {
            @Override
            public void onSuccess(UserInfo userInfo) {
                //登录成功，获取到用户信息userInfo
                //通过userInfo中的UID、token做服务器登录认证
                String tokens = userInfo.getToken();
                String uid = userInfo.getUID();
                int channelType = Extend.getInstance().getChannelType();
                callUnityFunc("LoginCallback", String.valueOf(1) + "#" + uid + "#" + channelType + "#" + tokens);
                printLog("登录成功");
            }
            @Override
            public void onCancel() {
                printLog("登录取消");
            }
            @Override
            public void onFailed(final String message, String trace) {
                printLog("登录失败");
            }
        });
        QuickSDK.getInstance().setLogoutNotifier(new LogoutNotifier() {
            @Override
            public void onSuccess() {
                callUnityFunc("LogoutCallback",SUCCESS);
                printLog("注销成功");
            }
            @Override
            public void onFailed(String message, String trace) {
                //注销失败，不做处理
                printLog("注销失败");
            }
        });
        QuickSDK.getInstance().setSwitchAccountNotifier(new SwitchAccountNotifier() {
            @Override
            public void onSuccess(UserInfo userInfo) {
                //切换账号成功的回调，返回新账号的userInfo
                callUnityFunc("SwitchAccountCallback",SUCCESS);
                printLog("切换账号成功");
            }
            @Override
            public void onCancel() {
                printLog("切换账号取消");
            }
            @Override
            public void onFailed(String message, String trace) {
                printLog("切换账号失败");
            }
        });
        QuickSDK.getInstance().setExitNotifier(new ExitNotifier() {
            @Override
            public void onSuccess() {
                //退出成功，游戏在此做自身的退出逻辑处理
                MyActivity.this.finish();
                printLog("退出成功");
            }
            @Override
            public void onFailed(String message, String trace) {
                //退出失败，不做处理
                printLog("退出失败");
            }
        });
        QuickSDK.getInstance().setPayNotifier(new PayNotifier() {
            @Override
            public void onSuccess(String sdkOrderID, String cpOrderID,
                                  String extrasParams) {
                //支付成功
                //sdkOrderID:quick订单号 cpOrderID：游戏订单号
                callUnityFunc("PayCallback",SUCCESS + "#" + cpOrderID);
                printLog("支付成功");
            }
            @Override
            public void onCancel(String cpOrderID) {
                //支付取消
                printLog("支付取消");
            }
            @Override
            public void onFailed(String cpOrderID, String message, String trace) {
                //支付失败
                callUnityFunc("PayCallback",FAILED + "#" + cpOrderID);
                printLog("支付失败");
            }
        });
        Sdk.getInstance().onCreate(this);
    }
    @Override
    protected void onStart() {
        super.onStart();
        Sdk.getInstance().onStart(this);
    }
    @Override
    protected void onRestart() {
        super.onRestart();
        Sdk.getInstance().onRestart(this);
    }
    @Override
    protected void onPause() {
        super.onPause();
        Sdk.getInstance().onPause(this);
    }
    @Override
    protected void onResume() {
        super.onResume();
        Sdk.getInstance().onResume(this);
    }
    @Override
    protected void onStop() {
        super.onStop();
        Sdk.getInstance().onStop(this);
    }
    @Override
    protected void onDestroy() {
        super.onDestroy();
        Sdk.getInstance().onDestroy(this);
    }
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        Sdk.getInstance().onNewIntent(intent);
    }
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        Sdk.getInstance().onActivityResult(this, requestCode, resultCode, data);
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
    }
    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
    }
    @Override
    protected void attachBaseContext(Context newBase) {
        super.attachBaseContext(newBase);
    }
    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode,permissions,grantResults);
		if(requestCode != 10001)
			return;
        //申请权限的回调（结果）这是一个类似生命周期的回调
        if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            //申请成功
//            printLog("申請成功");
            login();
        } else {
            //失败  这里逻辑以游戏为准 这里只是模拟申请失败 cp方可改为继续申请权限 或者退出游戏 或者其他逻辑
//            printLog("申請失敗");
            login();
        }
    }

    @Override
    public void Init() {
        callUnityFunc("InitCallback",SUCCESS);
    }

    @Override
    public void Login() {

        callUnityFunc("DebugSdk", "开始登录");

        try {

            if(ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.READ_PHONE_STATE)
                    || ActivityCompat.shouldShowRequestPermissionRationale(this,Manifest.permission.WRITE_EXTERNAL_STORAGE))
            {
//                printLog("沒有开启权限");
                login();
            }
            else {
                //check权限
                if ((ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED)
                        || (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED)) {
                    //没有 ，  申请权限  权限数组
//                    printLog("要求申请权限");
                    ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.READ_PHONE_STATE, Manifest.permission.WRITE_EXTERNAL_STORAGE}, 10001);
                } else {
                    // 有 则执行初始化
//                    printLog("已经有权限");
                    login();
                }
            }
        } catch (Exception e) {
            //异常  继续申请
            //ActivityCompat.requestPermissions(this, new String[] { Manifest.permission.READ_PHONE_STATE ,Manifest.permission.WRITE_EXTERNAL_STORAGE }, 1);
            Login();
        }

        printLog("开始登录");
    }

    private void login()
    {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if(!isInit){
//            printLog("初始化");
                    Sdk.getInstance().init(MyActivity.this, "28786303682695343992261367010082", "85149286");
                }else {
//            printLog("登录");
                    User.getInstance().login(MyActivity.this);
                }
            }
        });
    }


    @Override
    public void SwitchLogin() {
    }

    @Override
    public void Logout() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                User.getInstance().logout(MyActivity.this);
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
                //通过isShowExitDialog判断渠道sdk是否有退出框
                if(QuickSDK.getInstance().isShowExitDialog()){
                    Sdk.getInstance().exit(MyActivity.this);
                }else{
                    // 游戏调用自身的退出对话框，点击确定后，调用quick的exit接口
                    new AlertDialog.Builder(MyActivity.this).setTitle("退出").setMessage("是否退出游戏?").setPositiveButton("确定", new DialogInterface.OnClickListener() {
                        @Override
                        public void onClick(DialogInterface arg0, int arg1) {
                            Sdk.getInstance().exit(MyActivity.this);
                        }
                    }).setNegativeButton("取消", null).show();
                }
            }
        });
    }

    @Override
    public void SubmitExtraData(
            final int dataType,
            final int serverId,//服务器ID
            final String serverName,//服务器名
            final String zoneID,
            final String zoneName,
            final String roleID,//玩家ID
            final String roleName,//玩家姓名
            final String roleLevel,//玩家等级
            String guildlD,//公会ID
            String Vip,//VIP等级
            final int moneyNum,//钱币数量
            final String roleCreateTime,//创角时间
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

        createTime = ts/1000 + "";
        //注：GameRoleInfo的字段，以下所有参数必须传，没有的请模拟一个参数传入;
        GameRoleInfo roleInfo = new GameRoleInfo();
        roleInfo.setServerID(serverId + "");//数字字符串，不能含有中文字符
        roleInfo.setServerName(serverName);
        roleInfo.setGameRoleName(roleName);
        roleInfo.setGameRoleID(roleID);
        roleInfo.setGameBalance(moneyNum + "");//角色用户余额
        roleInfo.setVipLevel(Vip); //设置当前用户vip等级，必须为数字整型字符串,请勿传"vip1"等类似字符串
        roleInfo.setGameUserLevel(roleLevel);//设置游戏角色等级
        roleInfo.setPartyName("0");//设置帮派名称
        roleInfo.setRoleCreateTime(ts/1000 + ""); //UC，当乐与1881，TT渠道必传，值为10位数时间戳
        roleInfo.setPartyId(guildlD); //360渠道参数，设置帮派id，必须为整型字符串
        roleInfo.setGameRoleGender("无");//360渠道参数
        roleInfo.setGameRolePower("0"); //360,TT语音渠道参数，设置角色战力，必须为整型字符串
        roleInfo.setPartyRoleId("0"); //360渠道参数，设置角色在帮派中的id
        roleInfo.setPartyRoleName("0"); //360渠道参数，设置角色在帮派中的名称
        roleInfo.setProfessionId("0"); //360渠道参数，设置角色职业id，必须为整型字符串
        roleInfo.setProfession("0"); //360渠道参数，设置角色职业名称
        roleInfo.setFriendlist("无"); //360渠道参数，设置好友关系列表，格式请参考：https://www.quicksdk.com/doc-190.html?cid=15

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                //创建角色
                User.getInstance().setGameRoleInfo(MyActivity.this, roleInfo, dataType == 2);
                printLog("SubmitExtraData");
            }
        });
    }

    @Override
    public void Pay(
            final String rechargeId,//支付项ID
            final int showType,
            final int productId,//产品ID
            final String productName,//商品名称
            final String productDesc,//商品描述
            final String price,//价格
            final String currencyType,
            final int ratio,//比率
            final int buyNum,//购买数量
            final int coinNum,//金钱数量
            final String zoneId,
            final String serverID,//服务器ID
            final String serverName,//服务器名
            final String accounted,
            final String roleID,//玩家ID
            final String roleName,//玩家名
            final int roleLevel,//玩家等级
            final String vip,//vip
            final String guildlD,//公会ID
            final String payNotifyUrl,
            final String extension,//额外参数
            final String orderID) {

        GameRoleInfo roleInfo = new GameRoleInfo();
        roleInfo.setServerID(serverID);//数字字符串
        roleInfo.setServerName(serverName);
        roleInfo.setGameRoleName(roleName);
        roleInfo.setGameRoleID(roleID);
        roleInfo.setGameUserLevel(roleLevel + "");
        roleInfo.setVipLevel(vip);
        roleInfo.setGameBalance("0");
        roleInfo.setPartyName("");
        roleInfo.setRoleCreateTime(createTime); //UC，当乐与1881，TT渠道必传，值为10位数时间戳
        OrderInfo orderInfo = new OrderInfo();
        orderInfo.setCpOrderID(orderID + "");
        orderInfo.setGoodsName(productName);//商品名称，不带数量
        orderInfo.setCount(buyNum);//游戏币数量
        orderInfo.setAmount(Double.parseDouble(price));
        orderInfo.setGoodsID(rechargeId + "");
        orderInfo.setGoodsDesc(productDesc);
        orderInfo.setPrice(Double.parseDouble(price));
        orderInfo.setExtrasParams(extension);
        orderInfo.setCallbackUrl(payNotifyUrl);

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Payment.getInstance().pay(MyActivity.this, orderInfo, roleInfo);
                printLog("----------------------------支付");
            }
        });
    }
    @Override
    public  void CustomEvent(int type,String param) {
    }
}
