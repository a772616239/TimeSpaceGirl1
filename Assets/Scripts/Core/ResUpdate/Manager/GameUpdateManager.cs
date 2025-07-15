using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using GameCore;
using System.Text;

namespace ResUpdate
{

    /// <summary>
    /// 游戏更新状态
    /// </summary>
    public enum GameUpdateState
    {
        //下载游戏版本
        DownLoadGameConfigs,
        //下载游戏版本失败
        DownLoadGameConfigsFailed,
        //需要更新APP
        NeedUpdateApp,
        //下载APK
        DownLoadAPKProgress,
        //下载APK失败
        DownLoadAPKFailed,
        //游戏更新成功
        Success
    }

    /// <summary>
    /// 游戏更新管理器
    /// </summary>
    public class GameUpdateManager : UnitySingleton<GameUpdateManager>
    {
        class appJsonInfo
        {
            public string operate;
            public string time;
            public string sign;
        }

        /// <summary>
        /// 游戏更新回调
        /// </summary>
        Action<bool, GameUpdateState, object> gameUpdateAction;
        /// <summary>
        /// 开始热更新
        /// </summary>
        /// <param name="game"></param>
        public void BeginUpdate(Action<bool, GameUpdateState, object> gameUpdateAction)
        {
            if (BaseLogger.isDebug) BaseLogger.LogFormat("==========================ResUpdate.GameUpdateManager=====>BeginUpdate");
            this.gameUpdateAction = gameUpdateAction;
            StartCoroutine(GetAppConfigs());
        }

        /// <summary>
        /// 获取游戏版本信息
        /// </summary>
        /// <returns></returns>
        IEnumerator GetAppConfigs()
        {
            SetUpdateState(false, GameUpdateState.DownLoadGameConfigs);
            TimeSpan ts = DateTime.UtcNow - new DateTime(1970, 1, 1, 0, 0, 0, 0);
            var appkey = "dsfasdtcxv88!0stponxfa=";
            var time = Convert.ToInt64(ts.TotalSeconds).ToString();
            appJsonInfo data = new appJsonInfo();
            data.operate = "appInfo";
            data.time = time;
            data.sign = FileToCRC32.GetStrCRC32(time + "&" + appkey);
            var jsonData = JsonUtility.ToJson(data);
            Debug.LogError(jsonData);
            WWW www = new WWW(UpdateConfigs.GameVersionUrl, Encoding.UTF8.GetBytes(jsonData));
            yield return www;
            if (string.IsNullOrEmpty(www.error))
            { 
                Debug.LogFormat("ResUpdate.GameUpdateManager=={0}===>GetAppConfigs:{1}",www.url, www.text);
                try
                {
                    //AppConfigs.appConfigs = JsonUtility.FromJson<AppConfigs>(www.text);
                    //if( !string.IsNullOrEmpty(AppConfigs.appConfigs.error))
                    //{
                    //    Debug.LogError("--------------errorInfo::  " + AppConfigs.appConfigs.error);
                    //    SetUpdateState(true, GameUpdateState.DownLoadGameConfigsFailed);
                    //    www.Dispose();
                    //    yield break;
                    //}
                    //if (AppConfigs.appConfigs.CompareVersion(Application.version))
                    //{
                    //    UpdateApp();
                    //}
                    //else
                    //{
                    //    SetUpdateState(true, GameUpdateState.Success);
                    //}
                }
                catch(Exception e)
                {
                    Debug.LogFormat("appConfig "+e.Message);
                }
            }
            else
            {
                Debug.LogError(www.url+"--------------error::  "+www.error);
                SetUpdateState(true, GameUpdateState.DownLoadGameConfigsFailed);
            }
            www.Dispose();
        }

        /// <summary>
        /// 设置更新状态
        /// </summary>
        /// <param name="isFinish"></param>
        /// <param name="result"></param>
        /// <param name="param"></param>
        void SetUpdateState(bool isFinish, GameUpdateState result, object param = null)
        {
            ThreadManager.Instance.QueueOnMainThread(() => {
                if (gameUpdateAction != null)
                {
                    gameUpdateAction(isFinish, result, param);
                }
                if (isFinish)
                {
                    gameUpdateAction = null;
                }
            });
        }

        /// <summary>
        /// 安装APP
        /// </summary>
        public void UpdateApp()
        {
            if (Application.platform == RuntimePlatform.Android)
            {
                UpdateAPK(false);
            }
            else if (Application.platform == RuntimePlatform.IPhonePlayer)
            {
                UpdateIPA();
            }
            else {
                SetUpdateState(true,GameUpdateState.Success);
            }
        }

        /// <summary>
        /// 安装APK
        /// </summary>
        public void UpdateAPK(bool allowDownLoadFromNoWifi)
        {
            if (IsNetWorkReachable(allowDownLoadFromNoWifi))
            {
                //ResourceDownloadManager.Instance.StartDownload("test.apk", AppConfigs.appConfigs.androidURL, "apks/", DownLoadApkProgresCallBack, DownLoadApkFinishCallBack);
            }
            else 
            { 
            }
        }

        /// <summary>
        /// 网络是否可用
        /// </summary>
        /// <param name="allowDownLoadFromNoWifi"></param>
        /// <returns></returns>
        bool IsNetWorkReachable(bool allowDownLoadFromNoWifi)
        {
            if (!allowDownLoadFromNoWifi && Application.internetReachability == NetworkReachability.ReachableViaCarrierDataNetwork) return false;
            return true;
        }


        /// <summary>
        /// 下载APK进度回调
        /// </summary>
        /// <param name="name"></param>
        /// <param name="downLoadProgress"></param>
        void DownLoadApkProgresCallBack(string name,DownLoadProgress downLoadProgress) 
        {
            SetUpdateState(false, GameUpdateState.DownLoadAPKProgress, downLoadProgress);
        }

        /// <summary>
        /// 下载完成APK回调
        /// </summary>
        /// <param name="result"></param>
        /// <param name="name"></param>
        void DownLoadApkFinishCallBack(string name, bool result)
        {
            if (result)
            {
                //TODO 安装APK
                //try
                //{
                //    var Intent = new AndroidJavaClass("android.content.Intent");
                //    var ACTION_VIEW = Intent.GetStatic<string>("ACTION_VIEW");
                //    var FLAG_ACTIVITY_NEW_TASK = Intent.GetStatic<int>("FLAG_ACTIVITY_NEW_TASK");
                //    var intent = new AndroidJavaObject("android.content.Intent", ACTION_VIEW);

                //    var file = new AndroidJavaObject("java.io.File", path);
                //    var Uri = new AndroidJavaClass("android.net.Uri");
                //    var uri = Uri.CallStatic<AndroidJavaObject>("fromFile", file);

                //    intent.Call<AndroidJavaObject>("setDataAndType", uri, "application/vnd.android.package-archive");
                //    intent.Call<AndroidJavaObject>("addFlags", FLAG_ACTIVITY_NEW_TASK);
                //    intent.Call<AndroidJavaObject>("setClassName", "com.android.packageinstaller", "com.android.packageinstaller.PackageInstallerActivity");

                //    var UnityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                //    var currentActivity = UnityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                //    currentActivity.Call("startActivity", intent);
                //}
                //catch (System.Exception e)
                //{
                //    Debug.LogError("Error:" + e.Message + " -- " + e.StackTrace);
                //}           
            }
            else
            {
                SetUpdateState(true, GameUpdateState.DownLoadAPKFailed);
            }
        }

        /// <summary>
        /// 安装IPA
        /// </summary>
        void UpdateIPA()
        {
            //Application.OpenURL(AppConfigs.appConfigs.iosURL);
            Application.Quit();
        }
    }
}
