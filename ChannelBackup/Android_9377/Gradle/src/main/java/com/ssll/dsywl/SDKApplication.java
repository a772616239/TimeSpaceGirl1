package com.ssll.dsywl;

import android.util.Log;

import com.game.master.entity.MasterConfig;
import com.lib.master.sdk.MasterApplication;
import com.lib.master.sdk.MasterSDK2;

public class SDKApplication  extends MasterApplication {
    @Override public void onCreate() {
        super.onCreate();
        // 实现您的逻辑，初始化sdk
        MasterConfig config = new MasterConfig();
        config.setLandscape(false);//设置方向 横屏 true 竖屏false
//        config.setOpenAccredit(false);
        MasterSDK2.getInstance().initApplication(this,config);

        Log.d("Unity SDK:", "初始化游戏");
    }
}
