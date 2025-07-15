package com.bluewhale.androidutils;

import android.annotation.SuppressLint;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.telephony.TelephonyManager;
import android.util.DisplayMetrics;
import android.view.Display;
import android.view.WindowManager;

import com.ktgame.ktdeviceutil.KTGameDeviceUtil;

import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.Enumeration;

@SuppressLint({"NewApi"})
public class AndroidDeviceInfo {
    private static AndroidDeviceInfo _instance = null;

    private static Context mContext;

    public static AndroidDeviceInfo instance() {
        if (_instance == null)
            _instance = new AndroidDeviceInfo();
        return _instance;
    }

    public void Init(Context context) {
        mContext = context;
    }

    public static String GetDeviceBrand() {
        return Build.BRAND;
    }

    public static String GetDeviceModel() {
        return Build.MODEL;
    }

    public static String GetSystemVersion() {
        return Build.VERSION.RELEASE;
    }

    public static String GetScreenRatio(Context context) {
        WindowManager wm = (WindowManager)context.getSystemService(Context.WINDOW_SERVICE);
        Display display = wm.getDefaultDisplay();
        DisplayMetrics metrics = new DisplayMetrics();
        display.getMetrics(metrics);
        int width = metrics.widthPixels;
        int height = metrics.heightPixels;
        return String.format("%s*%s", new Object[] { Integer.valueOf(height), Integer.valueOf(width) });
    }

    public static String GetOperatorName(Context context) {
        TelephonyManager telephonyManager = (TelephonyManager)context.getSystemService(Context.TELEPHONY_SERVICE);
        return telephonyManager.getSimOperatorName();
    }

    public static String GetNetworkType(Context context) {
        ConnectivityManager connManager = (ConnectivityManager)context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (connManager == null)
            return "NoneNetWork ";
        NetworkInfo activeNetInfo = connManager.getActiveNetworkInfo();
        if (activeNetInfo == null || !activeNetInfo.isAvailable())
            return "NoneNetWork ";
        NetworkInfo wifiInfo = connManager.getNetworkInfo(1);
        if (wifiInfo != null) {
            NetworkInfo.State state = wifiInfo.getState();
            if (state != null && (
                    state == NetworkInfo.State.CONNECTED || state == NetworkInfo.State.CONNECTING))
                return "WIFI";
        }
        TelephonyManager telephonyManager = (TelephonyManager)context.getSystemService(Context.TELEPHONY_SERVICE);
        int networkType = 1;
        switch (networkType) {
            case 1:
            case 2:
            case 4:
            case 7:
            case 11:
                return "2G";
            case 3:
            case 5:
            case 6:
            case 8:
            case 9:
            case 10:
            case 12:
            case 14:
            case 15:
                return "3G";
            case 13:
                return "4G";
        }
        return "Unknown";
    }

    public static String GetLocalIpAddress(Context context) {
        NetworkInfo info = ((ConnectivityManager)context
                .getSystemService(Context.CONNECTIVITY_SERVICE)).getActiveNetworkInfo();
        if (info != null && info.isConnected())
            if (info.getType() == 0) {
                try {
                    for (Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces(); en.hasMoreElements(); ) {
                        NetworkInterface intf = en.nextElement();
                        for (Enumeration<InetAddress> enumIpAddr = intf.getInetAddresses(); enumIpAddr.hasMoreElements(); ) {
                            InetAddress inetAddress = enumIpAddr.nextElement();
                            if (!inetAddress.isLoopbackAddress() && inetAddress instanceof java.net.Inet4Address)
                                return inetAddress.getHostAddress();
                        }
                    }
                } catch (SocketException e) {
                    e.printStackTrace();
                }
            } else if (info.getType() == 1) {
                WifiManager wifiManager = (WifiManager)context.getSystemService(Context.WIFI_SERVICE);
                WifiInfo wifiInfo = wifiManager.getConnectionInfo();
                String ipAddress = intIP2StringIP(wifiInfo.getIpAddress());
                return ipAddress;
            }
        return "0.0.0.0";
    }

    public static String intIP2StringIP(int ip) {
        return String.valueOf(ip & 0xFF) + "." + (
                ip >> 8 & 0xFF) + "." + (
                ip >> 16 & 0xFF) + "." + (
                ip >> 24 & 0xFF);
    }

    public static void CopyToClipBoard(String str) {
        ClipboardManager cm = (ClipboardManager)mContext.getSystemService(Context.CLIPBOARD_SERVICE);
        ClipData mClipData = ClipData.newPlainText("PlayerInfo", str);
        cm.setPrimaryClip(mClipData);
    }

    public static String PasteFromClipBoard() {
        ClipboardManager cm = (ClipboardManager)mContext.getSystemService(Context.CLIPBOARD_SERVICE);
        String result = "";
        ClipData clipData = cm.getPrimaryClip();
        ClipData.Item item = clipData.getItemAt(0);
        CharSequence charSequence = item.coerceToText(mContext.getApplicationContext());
        result = charSequence.toString();
        return result;
    }

    public static String GetIMEICode() {
        return KTGameDeviceUtil.getIMEI(mContext);
    }

    public static String GetDeviceID() {
        return KTGameDeviceUtil.getDeviceID(mContext);
    }



    /**

     * 获取应用程序名称

     */

    public static synchronized String getAppName() {

        try {

            PackageManager packageManager = mContext.getPackageManager();

            PackageInfo packageInfo = packageManager.getPackageInfo(

                    mContext.getPackageName(), 0);

            int labelRes = packageInfo.applicationInfo.labelRes;

            return mContext.getResources().getString(labelRes);

        } catch (Exception e) {

            e.printStackTrace();

        }

        return null;

    }



    /**

     * [获取应用程序版本名称信息]

     * @return 当前应用的版本名称

     */

    public static synchronized String getVersionName() {
        try {

            PackageManager packageManager = mContext.getPackageManager();

            PackageInfo packageInfo = packageManager.getPackageInfo(

                    mContext.getPackageName(), 0);

            return packageInfo.versionName;

        } catch (Exception e) {

            e.printStackTrace();

        }

        return null;

    }





    /**

     * [获取应用程序版本名称信息]

     * @return 当前应用的版本名称

     */

    public static synchronized int getVersionCode() {

        try {

            PackageManager packageManager = mContext.getPackageManager();

            PackageInfo packageInfo = packageManager.getPackageInfo(

                    mContext.getPackageName(), 0);

            return packageInfo.versionCode;

        } catch (Exception e) {

            e.printStackTrace();

        }

        return 0;

    }





    /**

     * [获取应用程序版本名称信息]

     * @return 当前应用的版本名称

     */

    public static synchronized String getPackageName() {

        try {

            PackageManager packageManager = mContext.getPackageManager();

            PackageInfo packageInfo = packageManager.getPackageInfo(

                    mContext.getPackageName(), 0);

            return packageInfo.packageName;

        } catch (Exception e) {

            e.printStackTrace();

        }

        return null;

    }





    /**

     * 获取图标 bitmap

     */

    public static synchronized Bitmap getBitmap() {

        PackageManager packageManager = null;

        ApplicationInfo applicationInfo = null;

        try {

            packageManager = mContext.getApplicationContext()

                    .getPackageManager();

            applicationInfo = packageManager.getApplicationInfo(

                    mContext.getPackageName(), 0);

        } catch (PackageManager.NameNotFoundException e) {

            applicationInfo = null;

        }

        Drawable d = packageManager.getApplicationIcon(applicationInfo); //xxx根据自己的情况获取drawable

        BitmapDrawable bd = (BitmapDrawable) d;

        Bitmap bm = bd.getBitmap();

        return bm;

    }




}

