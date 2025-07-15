package com.cyywl.cthy;

import android.util.Log;
import com.chitu350.game.sdk.ChituApplication;

public class SDKApplication extends ChituApplication {

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d("Unity SDK:", "初始化游戏");
    }
}
