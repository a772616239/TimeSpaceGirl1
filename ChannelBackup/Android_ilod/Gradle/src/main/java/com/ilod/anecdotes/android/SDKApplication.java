package com.ilod.anecdotes.android;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.multidex.MultiDexApplication;

import com.adjust.sdk.Adjust;
import com.adjust.sdk.AdjustConfig;

public class SDKApplication  extends MultiDexApplication {
    @Override public void onCreate() {
        super.onCreate();
        //在进行测试时，请确保将 environment (环境) 设置为 AdjustConfig.ENVIRONMENT_SANDBOX 。
        // 请在向 App Store 提交应用程序前，将环境设置变为 AdjustConfig.ENVIRONMENT_PRODUCTION。
        String appToken = "a6rgl1dtql1c";
        String environment = AdjustConfig.ENVIRONMENT_SANDBOX;
        AdjustConfig config = new AdjustConfig(this, appToken, environment);
        config.setAppSecret(1, 1856811987, 900464503, 115361159, 1550347895);
        Adjust.onCreate(config);

        registerActivityLifecycleCallbacks(new AdjustLifecycleCallbacks());

        Log.d("Unity SDK:", "初始化游戏");
    }

    private static final class AdjustLifecycleCallbacks implements ActivityLifecycleCallbacks {
        @Override
        public void onActivityCreated(@NonNull Activity activity, @Nullable Bundle bundle) {

        }

        @Override
        public void onActivityStarted(@NonNull Activity activity) {

        }

        @Override
        public void onActivityResumed(Activity activity) {
            Adjust.onResume();
        }

        @Override
        public void onActivityPaused(Activity activity) {
            Adjust.onPause();
        }

        @Override
        public void onActivityStopped(@NonNull Activity activity) {

        }

        @Override
        public void onActivitySaveInstanceState(@NonNull Activity activity, @NonNull Bundle bundle) {

        }

        @Override
        public void onActivityDestroyed(Activity activity){

        }
    }
}
