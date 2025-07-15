package com.skfz.boomegg;

import android.util.Log;

import com.forevernine.FNApplication;

public class SDKApplication  extends FNApplication {
    @Override public void onCreate() {
        super.onCreate();
        Log.d("Unity SDK:", "初始化游戏");
    }
}
