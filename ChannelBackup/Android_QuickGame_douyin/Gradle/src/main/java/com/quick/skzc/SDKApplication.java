package com.quick.skzc;

import android.util.Log;

import com.quicksdk.QuickSdkApplication;

public class SDKApplication extends QuickSdkApplication {
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d("Unity SDK:", "初始化游戏");
    }
}