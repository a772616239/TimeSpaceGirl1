using System;
using System.IO;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using UnityEngine.UI;
using UnityEngine;
using ResUpdate;

namespace GameLogic
{
    /// <summary>
    /// 热更新面板
    /// </summary>
    public class UpdatePanel : MonoBehaviour
    {
        /// <summary>
        /// 提示文字
        /// </summary>
        [SerializeField]
        Text tipsText;
        /// <summary>
        /// 进度条
        /// </summary>
        [SerializeField]
        SliderCtrl slider;

        [SerializeField]
        UpdateMsgBox msgBox;

        //> 资源配置文件拉取失败自动重试次数
        int autoRetryTimes = 0;
        int WaitTime=0;
        void Awake()
        {
            Transform channelBgTrabsfrom = transform.Find("Canvas/LoadingScreen/" + AppConst.ChannelType);

            if (channelBgTrabsfrom != null)
            {
                channelBgTrabsfrom.gameObject.SetActive(true);
            }

            autoRetryTimes = 0;
            msgBox.gameObject.SetActive(false);
            //StartCoroutine(GetGameConfig());
            // BeginUpdatePlatform();
            StartCoroutine(AwakeUpdatePlatform());
        }

        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.Escape))
            {
                //> msgBox.Show("取消", "确定", "确定关闭程序？", (result) =>
                msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.CANEL), SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.CONFIRM), SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.CONFIRM_CLOSE), (result) =>
                {
                    if (result == 1)
                        Application.Quit();
                });
            }
        }

        //        void Start()
        //        {
        //#if UNITY_EDITOR
        //#elif UNITY_ANDROID
        //            Debug.LogError("UpdatePanel HideSplash Init SDKManager::::");
        //            using (AndroidJavaClass jc = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
        //            {
        //                using (AndroidJavaObject jo = jc.GetStatic<AndroidJavaObject>("currentActivity"))
        //                {
        //                    jo.Call("HideSplash");
        //                }
        //            }
        //#elif UNITY_IPHONE || UNITY_IOS

        //#endif
        //        }
        IEnumerator AwakeUpdatePlatform()
        {
            if(PlayerPrefs.GetInt("gameStart")==2)
            {
                BeginUpdatePlatform();
            }
            else
            {
                yield return new WaitForSeconds(1);
                if(WaitTime>10)
                {
                    msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.CONFIRM), SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.INIT_FAILED), (result) =>
                    {
                        Application.Quit();
                    });
                }
                else
                {
                    WaitTime=WaitTime+1;
                    StartCoroutine(AwakeUpdatePlatform());
                }
            }
        }
        IEnumerator GetGameConfig()
        {
            //> tipsText.text = "获取游戏配置";
            tipsText.text = SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.GET_GAME_SETTINGS);
            var jsonData = UpdateManager.Instance.PostServerInfo();
            WWW www = new WWW(AppConst.Download_apk_Url, Encoding.UTF8.GetBytes(jsonData));
            yield return www;
            if (string.IsNullOrEmpty(www.error))
            {
                OnGetGameConfig(www.text);
            }
            else 
            {
                Debug.LogError(www.url+"   "+www.error);
                //> msgBox.Show("重试", "获取游戏配置失败!", (result) =>
                msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.RETRY), SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.GET_GAME_SETTINGS_FAILED), (result) =>
                {
                    StartCoroutine(GetGameConfig());
                });
            }
            www.Dispose();
        }

        bool CheckAndConvert<T>(Hashtable tab,string parameterName,object targetValue)
        {
            if(tab.Contains(parameterName))
            {
                var parStr= tab[parameterName] as string;
                if(typeof(T) ==typeof(int))
                {
                    int intValue=0;
                    if (int.TryParse(parStr, out intValue))
                    {
                        targetValue= intValue;
                        return true;
                    }
                }
                else if(typeof(T) ==typeof(bool))
                {
                    if (parStr.ToLower() == "true" || parStr=="1")
                    {
                        targetValue = true;
                    }
                }
                else if (typeof(T) == typeof(string))
                {
                    if (parStr!=null)
                    {
                        targetValue = parStr;
                        return true;
                    }
                }
            }
             return false;
        }

        void OnGetGameConfig(string config)
        {
            if (string.IsNullOrEmpty(config))
            {
                return;
            }
            Util.LogError("gameConfig::"+config);
            var data = MiniJSON.jsonDecode(config) as Hashtable;
            if(data==null || data.Contains("error"))
            {
                //> msgBox.Show("重试", "获取游戏配置错误!", (result) =>
                msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.RETRY), SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.GET_GAME_SETTINGS_ERROR), (result) =>
                {
                    StartCoroutine(GetGameConfig());
                });
                return;
            }

            if (AppConst.isUpdate)
            {
                BeginUpdateGame();
            }
            else
            {
                OnUpdateFinish();
            }
        }


        /// <summary>
        /// 更新游戏
        /// </summary>
        void BeginUpdateGame()
        {
            GameUpdateManager.Instance.BeginUpdate(OnGameUpdateStateChanged);
        }

        /// <summary>
        /// 更新平台
        /// </summary>
        void BeginUpdatePlatform()
        {
            UpdateManager.Instance.UpdateResources(OnResourcesUpdateStateChanged);
        }

        /// <summary>
        /// 游戏状态改变
        /// </summary>
        /// <param name="isFinish"></param>
        /// <param name="state"></param>
        /// <param name="param"></param>
        void OnGameUpdateStateChanged(bool isFinish, GameUpdateState state, object param)
        {
            //Debug.LogFormat("OnGameUpdateStateChanged=======>IsFinish:{0},State:{1}", isFinish, state.ToString());
            switch (state)
            {
                case GameUpdateState.DownLoadGameConfigs:
                    //> tipsText.text = "获取版本信息";
                    tipsText.text = SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.GET_VERSION_INFO);
                    break;
                case GameUpdateState.DownLoadGameConfigsFailed:
                    //> msgBox.Show("重试", "获取游戏配置失败,请确认网络后重试!", (result) =>
                    msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.RETRY), SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.GET_GAME_SETTINGS_FAILED_CONFIRM_WIFI), (result) =>
                    {
                        BeginUpdateGame();
                    });
                    break;
                case GameUpdateState.NeedUpdateApp:
                    //  msgBox.Show();
                    GameUpdateManager.Instance.UpdateApp();
                    break;
                case GameUpdateState.DownLoadAPKProgress:
                    OnGameUpdateProgress(param as DownLoadProgress);
                    break;
                case GameUpdateState.DownLoadAPKFailed:
                    //> msgBox.Show("重试", "下载安装文件失败,请确认网络后重试!", (result) =>
                    msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.RETRY), SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.DOWNlOAD_FILE_FAILED_CONFIRM_WIFI), (result) =>
                    {
                        GameUpdateManager.Instance.UpdateAPK(true);
                    });
                    break;
                case GameUpdateState.Success:
                    BeginUpdatePlatform();
                    break;
            }
        }


        /// <summary>
        /// 资源更新状态改变
        /// </summary>
        /// <param name="isFinish"></param>
        /// <param name="state"></param>
        /// <param name="param"></param>
        void OnResourcesUpdateStateChanged(bool isFinish, ResourcesUpdateState state, object param)
        {
            //Debug.LogFormat("OnResourcesUpdateStateChanged=======>IsFinish:{0},State:{1}", isFinish, state.ToString());
            switch (state)
            {
                case ResourcesUpdateState.GetGameConfigs:
                    //> tipsText.text = "获取资源配置";
                    tipsText.text = SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.GET_RESOURCES_SETTINGS);
                    break;
                case ResourcesUpdateState.GetGameConfigsFailed:
                    //> msgBox.Show("重试", "获取资源版本失败,请确认网络后重试!", (result) =>
                    msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.RETRY), SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.GET_RESOURCES_VERSION_FAILED_CONFIRM_WIFI), (result) =>
                    {
                        BeginUpdatePlatform();
                    });
                    break;
                case ResourcesUpdateState.DownLoadVersionFiles:
                    //> tipsText.text = "校验资源文件";
                    tipsText.text = SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.CHECK_RESOURCES_FILE);
                    break;
                case ResourcesUpdateState.DownLoadVersionFilesFailed:
                    //> msgBox.Show("重试", "获取资源配置失败,请确认网络后重试!", (result) =>
                    if(autoRetryTimes < 3)
                    {
                        autoRetryTimes++;
                        BeginUpdatePlatform();
                        break;
                    }
                    msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.RETRY), SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.GET_RESOURCES_SETTINGS_FAILED_CONFIRM_WIFI), (result) =>
                    {
                        BeginUpdatePlatform();
                    });
                    break;
                case ResourcesUpdateState.DownLoadFromNoWifi:
                    float size = 1f * (long)(param as object[])[0] / 1024 / 1024;
                    Action startDownAction = (param as object[])[1] as Action;
                    //> string msg = string.Format("检测到资源更新{0:f2}MB,当前非wifi环境，点击确定开始更新!", size);
                    string msg = string.Format(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.NOT_WIFI_CONFIRM), size);
                    //> msgBox.Show("确定", msg, (result) =>
                    msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.CONFIRM), msg, (result) =>
                    {
                         startDownAction();
                         slider.SetValue(0f);
                        SDK.SdkCustomEvent.CustomEvent("开始热更");
                    });
                    break;
                case ResourcesUpdateState.DownLoadWithWifi:
                    float size2 = 1f * (long)(param as object[])[0] / 1024 / 1024;
                    Action startDownAction2 = (param as object[])[1] as Action;
                    //> string msg2 = string.Format("检测到资源更新{0:f2}MB, 点击确定开始更新!", size2);
                    string msg2 = string.Format(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.WIFI_CONFIRM), size2);
                    //> msgBox.Show("确定", msg2, (result) =>
                    msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.CONFIRM), msg2, (result) =>
                    {
                        startDownAction2();
                        slider.SetValue(0f);
                        // 打点 - 开始更新
                        SDK.SdkCustomEvent.CustomEvent("开始热更");
                    });
                    break;
                case ResourcesUpdateState.UpdateResourcesProgress:
                    OnResUpdateProgress(param as ResUpdateProgress);
                    break;
                case ResourcesUpdateState.UpdateResourcesFailed:
                    //> msgBox.Show("重试", "下载资源文件失败,请确认网络后重试!", (result) =>
                    // 打点 - 更新失败
                    SDK.SdkCustomEvent.CustomEvent("热更失败");
                    msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.RETRY), SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.DOWNlOAD_RESOURCES_FILE_FAILED_CONFIRM_WIFI), (result) =>
                    {
                        BeginUpdatePlatform();
                    });
                    break;
                case ResourcesUpdateState.Success:
                    VersionPar vp = (VersionPar)param;
                    //string version = (string)param;
                    VersionManager.Instance.SaveVersion(vp);
                    OnUpdateFinish();
                    // 打点 - 更新完成
                    SDK.SdkCustomEvent.CustomEvent("热更结束");
                    break;
                case ResourcesUpdateState.OldPackageNeedChange:
                    //> msgBox.Show("与最新版本差异过大，请下载最新安装包！");
                    msgBox.Show(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.DOWNLOAD_NEWEST_APP));
                    break;
            }
        }

        /// <summary>
        /// 游戏更新进度
        /// </summary>
        /// <param name="progress"></param>
        void OnGameUpdateProgress(DownLoadProgress progress)
        {
            slider.UpdateValue(progress.Progress);
            //> tipsText.text = string.Format("下载进度:{0}/{1}MB ，下载速度:{2}KB/s", progress.SizeMB.ToString("f2"), progress.TotalSizeMB.ToString("f2"),progress.LoadSpeed.ToString("f2"));
            tipsText.text = string.Format(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.DOWNLOAD_PROGRESS_RATE), progress.SizeMB.ToString("f2"), progress.TotalSizeMB.ToString("f2"), progress.LoadSpeed.ToString("f2"));
        }

        /// <summary>
        /// 资源更新进度
        /// </summary>
        /// <param name="progress"></param>
        void OnResUpdateProgress(ResUpdateProgress progress)
        {
            slider.UpdateValue(progress.Progress);
            //> tipsText.text = string.Format("下载进度:{0}/{1}MB({2}%)", progress.SizeMB, progress.TotalSizeMB, (progress.SizeMB/progress.TotalSizeMB)*100);
            tipsText.text = string.Format(SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.DOWNLOAD_PROGRESS), progress.SizeMB, progress.TotalSizeMB, (progress.SizeMB / progress.TotalSizeMB) * 100);
        }

        /// <summary>
        /// 更新结束
        /// </summary>
        void OnUpdateFinish() {
            //> tipsText.text = "更新完成";
            tipsText.text = SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.UPDATE_COMPLETE);
            slider.SetValue(1f);
            StartCoroutine(LoadGlobalRes());
        }

        IEnumerator LoadGlobalRes() {
            //> tipsText.text = "正在预加载资源,此过程不消耗流量。";
            tipsText.text = SLanguageMoreLanguageMgr.Instance.GetLanguageChValBykey(more_language.RELOAD_RESOURCES);
            slider.SetValue(0f);
            GlobalResLoader loader = new GlobalResLoader();
            loader.LoadGlobalRes(null);
            while (!loader.IsLoadFinish) {
                slider.UpdateValue(loader.Progress);
                yield return 1;
            }
            slider.SetValue(1f);
            yield return new WaitForSeconds(0.1f);
            yield return UpdateFinish();
        }

        IEnumerator UpdateFinish() {
            yield return new WaitForSeconds(0.2f);
            DestroyImmediate(this.gameObject);
            UpdateManager.Instance.UnLoadUpdateAsset();

            App.Instance.StartUp();
        }
    }
}