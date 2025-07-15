package com.blzx.boomegg;

import android.content.Intent;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import com.forevernine.FNLifecycleBroadcast;
import com.forevernine.FNSdk;
import com.forevernine.notifier.FNLoginNotifier;
import com.forevernine.notifier.FNLoginUserinfo;
import com.forevernine.notifier.FnPaymentNotifier;
import com.forevernine.pay.FNOrderInfo;
import com.forevernine.pay.FNOrderResult;
import com.forevernine.user.FNRoleinfo;
import com.forevernine.util.FNUtils;
import com.forevernine.util.ToastUtil;
import com.game.base.IUnityPlayerActivity;

import java.security.MessageDigest;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
public class MyActivity extends IUnityPlayerActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        FNLifecycleBroadcast.getInstance().onLifecycleActivityResult(requestCode, resultCode, data);
    }

    @Override
    protected void onResume() {
        super.onResume();
    }

    @Override
    protected void onPause() {
        super.onPause();
    }

    @Override
    protected void onStop() {
        super.onStop();
    }

    @Override
    protected void onRestart() {
        super.onRestart();
        FNLifecycleBroadcast.getInstance().onLifecycleActivityRestart();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        FNLifecycleBroadcast.getInstance().onLifecycleLaunchActivityDestroy();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        Log.d("MainActivity", "onLifecycleActivityRestart");
        FNLifecycleBroadcast.getInstance().onLifecycleActivityNewIntent(intent);
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
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        FNLifecycleBroadcast.getInstance().onRequestPermissionsResult(requestCode,permissions, grantResults);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
    }

    @Override
    public void Init() {
        callUnityFunc("InitCallback",SUCCESS);
//        runOnUiThread(new Runnable() {
//            @Override
//            public void run() {
//
//            }
//        });
        printLog("Init");
    }

    @Override
    public void Login() {
        callUnityFunc("DebugSdk", "开始登录");
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                FNSdk.Login(new FNLoginNotifier() {
                    @Override
                    public void onSuccess(FNLoginUserinfo user) {
                        ToastUtil.toast("登录成功");
                        Log.d("MainActivity",   "onLogin FNLoginNotifier:" + user.toString());
                        String uid = user.Uid;
                        String token = user.Token;
                        //appid这样获取传递给服务器端，不能写死
                        String appid = FNUtils.getApplicationMetaData("FN_APP_ID");
                        //结果(1成功0失败)#uid(SDK获取，没有就不管)#自定义(预留参数)#token(SDK获取)
                        callUnityFunc("LoginCallback", String.valueOf(1) + "#" + uid + "#" + appid + "#" + token);
                        printLog("登录成功");
                    }

                    @Override
                    public void onCancel() {
                        ToastUtil.toast("取消登录");
                        printLog("取消登录");
                    }

                    @Override
                    public void onFailed(String var1, String var2) {
                        ToastUtil.toast("登录失败");
                        printLog("登录失败");
                    }
                });
                printLog("Login");
            }
        });

        printLog("开始登录");
    }

    @Override
    public void SwitchLogin() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                printLog("SwitchLogin");
            }
        });
    }

    @Override
    public void Logout() {
        callUnityFunc("LogoutCallback",SUCCESS);
        printLog("Logout");
    }

    @Override
    public boolean IsSupportExit() {
        return false;
    }

    @Override
    public void ExitGame() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                printLog("ExitGame");
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

        if(dataType == 2)
        {
            FNSdk.onCreateRole(new FNRoleinfo(serverId, roleID, Integer.parseInt(roleLevel), roleName, false, "", "",0));
        }
        else if(dataType == 3)
        {
            FNSdk.onLogin(new FNRoleinfo(serverId, Integer.parseInt(roleID), Integer.parseInt(roleLevel), roleName, false));
        }
        else if(dataType == 4)
        {
            FNSdk.onLevelUp(Integer.parseInt(roleLevel));
        }
        //1.流水数据上报 2.上报新手引导完成 3.活动数据上报 未做

        printLog("SubmitExtraData");
    }

    @Override
    public void Pay(
            final String rechargeId,//支付项ID
            final int showType,
            final int productId,//产品ID
            final String productName,//商品名称
            final String productDesc,//商品描述
            final String price,//价格
            final String currencyType,//货币类型
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

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                FNSdk.Pay(new FNOrderInfo(productId+"", Integer.parseInt(price)*100, extension, productName, productDesc, "", ""), new FnPaymentNotifier() {
                    @Override
                    public void onSuccess(FNOrderResult order) {
                        ToastUtil.toast("支付成功");
                        callUnityFunc("PayCallback",SUCCESS + "#" + orderID);
                        printLog("支付成功");
                    }

                    @Override
                    public void onCancel() {
                        ToastUtil.toast("支付取消");
                        printLog("支付取消");
                    }

                    @Override
                    public void onFailed(FNOrderResult order, String msg) {
                        ToastUtil.toast("支付失败");
                        callUnityFunc("PayCallback",FAILED + "#" + orderID);
                        printLog("支付失败");
                    }
                });
                printLog("Pay");
            }
        });
    }

    @Override
    public  void Bind() {
        printLog("Bind");
    }

    @Override
    public void Community(){
        printLog("Community");
    }

    @Override
    public  void CustomEvent(int type,String param){
    }
}
