package com.ssll.dsywl;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

import com.lib.master.sdk.MasterSplashActivity;

public class SplashActivity extends MasterSplashActivity {
    @Override
    public void onSplashBefore(Context context, Bundle saveInstanceState) {
        // 闪屏动画播放前
    }

    @Override
    public void onSplashFinish() {
        // 闪屏动画播放完毕,跳转到游戏Activity
        startActivity(new Intent(this, MyActivity.class));
        finish();
    }
}
