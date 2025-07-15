package com.bluewhale.androidutils;

import android.content.Context;
import android.util.Log;
import android.util.TypedValue;

import java.lang.reflect.Method;

public class NotchScreenUtil {


    private static NotchScreenUtil _instance = null;
    public static NotchScreenUtil instance() {
        if (_instance == null)
            _instance = new NotchScreenUtil();
        return _instance;
    }

    private static Context mContext;
    public void Init(Context context) {
        mContext = context;
    }

    /**
     * 华为start
     */
    // 判断是否是华为刘海屏
    private static boolean hasNotchInScreenAtHuawei() {
        boolean ret = false;
        try {
            ClassLoader cl = mContext.getClassLoader();
            Class<?> HwNotchSizeUtil = cl.loadClass("com.huawei.android.util.HwNotchSizeUtil");
            Method get = HwNotchSizeUtil.getMethod("hasNotchInScreen");
            ret = (Boolean) get.invoke(HwNotchSizeUtil);
            Log.d("NotchScreenUtil", "this Huawei device has notch in screen？"+ret);
        } catch (ClassNotFoundException e) {
            Log.e("NotchScreenUtil", "hasNotchInScreen ClassNotFoundException", e);
        } catch (NoSuchMethodException e) {
            Log.e("NotchScreenUtil", "hasNotchInScreen NoSuchMethodException", e);
        } catch (Exception e) {
            Log.e("NotchScreenUtil", "hasNotchInScreen Exception", e);
        }
        return ret;
    }

    /**
     * 获取华为刘海的高
     * @return
     */
    private static int getNotchSizeAtHuawei() {
        return 0;
//        int[] ret = new int[] { 0, 0 };
//        try {
//            ClassLoader cl = mContext.getClassLoader();
//            Class<?> HwNotchSizeUtil = cl.loadClass("com.huawei.android.util.HwNotchSizeUtil");
//            Method get = HwNotchSizeUtil.getMethod("getNotchSize");
//            ret = (int[]) get.invoke(HwNotchSizeUtil);
//
//        } catch (ClassNotFoundException e) {
//            Log.e("NotchScreenUtil", "getNotchSize ClassNotFoundException");
//        } catch (NoSuchMethodException e) {
//            Log.e("NotchScreenUtil", "getNotchSize NoSuchMethodException");
//        } catch (Exception e) {
//            Log.e("NotchScreenUtil", "getNotchSize Exception");
//        }
//        return ret[1];
    }

    /**
     * 华为end
     */

    /**
     * Oppo start
     */
    private static boolean hasNotchInScreenAtOppo() {
        boolean hasNotch = mContext.getPackageManager().hasSystemFeature("com.oppo.feature.screen.heteromorphism");
        Log.d("NotchScreenUtil", "this OPPO device has notch in screen？"+hasNotch);
        return hasNotch;
    }

    private static int getNotchSizeAtOppo() {
        return 80;
    }

    /**
     * Oppo end
     */

    /**
     * vivo start
     */
    private static final int NOTCH_IN_SCREEN_VOIO = 0x00000020;// 是否有凹槽
    private static final int ROUNDED_IN_SCREEN_VOIO = 0x00000008;// 是否有圆角

    private static boolean hasNotchInScreenAtVivo() {
        boolean ret = false;
        try {
            ClassLoader cl = mContext.getClassLoader();
            Class<?> FtFeature = cl.loadClass("com.util.FtFeature");
            Method get = FtFeature.getMethod("isFeatureSupport", int.class);
            ret = (Boolean) get.invoke(FtFeature, NOTCH_IN_SCREEN_VOIO);
            Log.d("NotchScreenUtil", "this VIVO device has notch in screen？" + ret);
        } catch (ClassNotFoundException e) {
            Log.e("NotchScreenUtil", "hasNotchInScreen ClassNotFoundException", e);
        } catch (NoSuchMethodException e) {
            Log.e("NotchScreenUtil", "hasNotchInScreen NoSuchMethodException", e);
        } catch (Exception e) {
            Log.e("NotchScreenUtil", "hasNotchInScreen Exception", e);
        }
        return ret;
    }

    private static int getNotchSizeAtVivo(){
        return 0;
//        return dp2px(mContext, 32);
    }

    /**
     * vivo end
     */


    /**
     * dp转px
     * @param context
     * @param dpValue
     * @return
     */
    private static int dp2px(Context context, int dpValue) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dpValue,context.getResources().getDisplayMetrics());
    }


    /***
     * 判断小米手机
     * @return
     */
    private static boolean hasNotchInScreenAtXIAOMI() {
        boolean ret = false;
        try {
            ClassLoader cl = mContext.getClassLoader();
            Class<?> SystemProperties = cl.loadClass("android.os.SystemProperties");

            Class[] paramTypes = new Class[2];
            paramTypes[0] = String.class;
            paramTypes[1] = int.class;
            Method get = SystemProperties.getMethod("getInt", paramTypes);

            Object[] params = new Object[2];
            params[0] = "ro.miui.notch";
            params[1] = 0;
            ret = (Integer) get.invoke(SystemProperties, params) == 1;
            Log.d("NotchScreenUtil", "this XIAOMI device has notch in screen？" + ret);
        } catch (ClassNotFoundException e) {
            Log.e("NotchScreenUtil", "hasNotchInScreen ClassNotFoundException", e);
        } catch (NoSuchMethodException e) {
            Log.e("NotchScreenUtil", "hasNotchInScreen NoSuchMethodException", e);
        } catch (Exception e) {
            Log.e("NotchScreenUtil", "hasNotchInScreen Exception", e);
        }
        return ret;
    }

    /**
     * 获取小米手机
     * @return
     */
    private static int getNotchSizeAtXIAOMI(){
        int resourceId = mContext.getResources().getIdentifier("notch_height", "dimen", "android");
        if (resourceId > 0) {
            return mContext.getResources().getDimensionPixelSize(resourceId);
        }
        return -1;
    }






    /**
     * 获取手机厂商
     *
     * @return  手机厂商
     */
    private final static int DEVICE_BRAND_OPPO = 0x0001;
    private final static int DEVICE_BRAND_HUAWEI = 0x0002;
    private final static int DEVICE_BRAND_VIVO = 0x0003;
    private final static int DEVICE_BRAND_XIAOMI = 0x0004;

    private static int getDeviceBrand() {
        String brand = android.os.Build.BRAND.trim().toUpperCase();
        if (brand.contains("HUAWEI")) {
            Log.d("device brand", "HUAWEI");
            return DEVICE_BRAND_HUAWEI;
        }else if (brand.contains("OPPO")) {
            Log.d("device brand", "OPPO");
            return DEVICE_BRAND_OPPO;
        }else if (brand.contains("VIVO")) {
            Log.d("device brand", "VIVO");
            return DEVICE_BRAND_VIVO;
        }else if (brand.contains("MI")) {
            Log.d("device brand", "XIAOMI");
            return DEVICE_BRAND_XIAOMI;
        }
        return 0;
    }


    public static int getNotchHeight(){	
        int brand = getDeviceBrand();
        switch (brand){
            case DEVICE_BRAND_HUAWEI:
                if(hasNotchInScreenAtHuawei()) return getNotchSizeAtHuawei();
                break;

            case DEVICE_BRAND_OPPO:
                if(hasNotchInScreenAtOppo()) return getNotchSizeAtOppo();
                break;

            case DEVICE_BRAND_VIVO:
                if(hasNotchInScreenAtVivo()) return getNotchSizeAtVivo();
                break;

            case DEVICE_BRAND_XIAOMI:
                if(hasNotchInScreenAtXIAOMI()) return getNotchSizeAtXIAOMI();
                break;
        }
        return -1;
    }



}
