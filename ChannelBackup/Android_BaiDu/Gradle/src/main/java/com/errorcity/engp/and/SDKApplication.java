package com.errorcity.engp.and;

import android.util.Log;
import androidx.multidex.MultiDexApplication;
import com.baidu.game.publish.BDGameSDK;

public class SDKApplication  extends MultiDexApplication {
    @Override public void onCreate() {
        super.onCreate();
        BDGameSDK.initApplication(this);

        Log.d("Unity SDK:", "初始化游戏");
    }
}
