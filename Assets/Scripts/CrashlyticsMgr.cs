    using System;
    using System.Collections;
    using System.Collections.Generic;
    using System.IO;
    using UnityEngine;

    // Import Firebase and Crashlytics
    using Firebase;
    using Firebase.Analytics;
    using Firebase.Crashlytics;
    // using UnityEngine.AddressableAssets;
    namespace ETModel{

    public class CrashlyticsMgr : MonoBehaviour
    {
        public static CrashlyticsMgr Inst;
        public static bool IsRelease = false;
        public static Action<string> AfterLog { get; set; }
        bool IsInitFireBase = false;
        // Use this for initialization
        public void Awake()
        {
            Inst = this;
            string path = $"{Application.persistentDataPath}/debug.txt";
    #if RELEASE
                IsRelease=true;
    #endif
            if (File.Exists(path))
            {
                IsRelease = false;
            }

            if (IsRelease)
            {
                Application.SetStackTraceLogType(UnityEngine.LogType.Log, StackTraceLogType.None);
                // 关闭 Unity 内置的日志输出
                Debug.unityLogger.logEnabled = false;
            }
            Debug.Log("Init CrashlyticsMgr CrashlyticsMgr:");
            // Initialize Firebase
            Firebase.FirebaseApp.CheckAndFixDependenciesAsync().ContinueWith(task =>
            {
                var dependencyStatus = task.Result;
                Debug.Log("Init CrashlyticsMgr: succ");
                AfterLog = (str) =>
                {
    #if !UNITY_EDITOR
                         Crashlytics.Log(str);
    #endif
                    // Debug.Log("Init CrashlyticsMgr: log:"+str);
                };
                if (dependencyStatus == Firebase.DependencyStatus.Available)
                {
                    FirebaseAnalytics.SetAnalyticsCollectionEnabled(true);
                    Debug.Log("Init CrashlyticsMgr:Available");
                    // Create and hold a reference to your FirebaseApp,
                    // where app is a Firebase.FirebaseApp property of your application class.
                    // Crashlytics will use the DefaultInstance, as well;
                    // this ensures that Crashlytics is initialized.
                    Firebase.FirebaseApp app = Firebase.FirebaseApp.DefaultInstance;

                    // When this property is set to true, Crashlytics will report all
                    // uncaught exceptions as fatal events. This is the recommended behavior.
                    Crashlytics.ReportUncaughtExceptionsAsFatal = true;
                    // FirebaseAnalytics.LogEvent();
                    // Set a flag here for indicating that your project is ready to use Firebase.
                    IsInitFireBase = true;
                }
                else
                {
                    UnityEngine.Debug.LogError(System.String.Format(
                        "Could not resolve all Firebase dependencies: {0}", dependencyStatus));
                    // Firebase Unity SDK is not safe to use here.
                }
                // Firebase.Messaging.FirebaseMessaging.TokenReceived += OnTokenReceived;
                // Firebase.Messaging.FirebaseMessaging.MessageReceived += OnMessageReceived;
            });
        }

        // public void OnTokenReceived(object sender, Firebase.Messaging.TokenReceivedEventArgs token)
        // {
        //     Log.Info("Received Registration Token: " + token.Token);
        // }
        //
        // public void OnMessageReceived(object sender, Firebase.Messaging.MessageReceivedEventArgs e)
        // {
        //     Log.Info("Received a new message from: " + e.Message.From);
        // }

        #region Core Gameplay Events

        public void TapEvent(int type, string eventName)
        {
                if (IsInitFireBase)
                {
                    var cbName = type + "_" + eventName;
                    // if (!_isFirebaseInitialized) return;
                    XDebug.Log.l("TapEvent" + cbName);

                    FirebaseAnalytics.LogEvent(cbName);
                }

        }

        public void LevelStart(int levelNumber, string difficulty)
        {
            // if (!_isFirebaseInitialized) return;

            FirebaseAnalytics.LogEvent(
                "level_start",
                new Parameter("level_number", levelNumber),
                new Parameter("difficulty", difficulty)
            );
        }

        public void LevelLoadComplete(int levelNumber, float loadTime)
        {
            FirebaseAnalytics.LogEvent(
                "level_load_complete",
                new Parameter("level_number", levelNumber),
                new Parameter("load_time", loadTime)
            );
        }

        public void LevelPause(int levelNumber, float pauseDuration)
        {
            FirebaseAnalytics.LogEvent(
                "level_pause",
                new Parameter("level_number", levelNumber),
                new Parameter("pause_duration", pauseDuration)
            );
        }

        public void LevelResume(int levelNumber)
        {
            FirebaseAnalytics.LogEvent(
                "level_resume",
                new Parameter("level_number", levelNumber)
            );
        }

        public void LevelComplete(int levelNumber, float timeSpent, int retryCount = 1)
        {
            FirebaseAnalytics.LogEvent(
                "level_complete",
                new Parameter("level_number", levelNumber),
                new Parameter("time_spent", timeSpent),
                new Parameter("retry_count", retryCount)
            );
        }

        public void LevelFail(int levelNumber, string failReason)
        {
            FirebaseAnalytics.LogEvent(
                "level_fail",
                new Parameter("level_number", levelNumber),
                new Parameter("fail_reason", failReason)
            );
        }

        #endregion

        #region Economy & Monetization

        public void ResourceEarn(string currencyType, int amount, string source)
        {
            FirebaseAnalytics.LogEvent(
                "resource_earn",
                new Parameter("currency_type", currencyType),
                new Parameter("amount", amount),
                new Parameter("source", source)
            );
        }

        public void ResourceSpend(string currencyType, int amount, string purpose)
        {
            FirebaseAnalytics.LogEvent(
                "resource_spend",
                new Parameter("currency_type", currencyType),
                new Parameter("amount", amount),
                new Parameter("purpose", purpose)
            );
        }
        public void ShowView(string viewName)
        {
            FirebaseAnalytics.LogEvent(
                "show_view",
                new Parameter("view_name", viewName)
            );
        }
        /// <summary>
        /// 0开始
        /// 1成功
        /// 2失败
        ///3.成功发奖
        /// </summary>
        /// <param name="state"></param>
        public void ClickPurchase(int state)
        {
            FirebaseAnalytics.LogEvent(
                "click_purchase",
                new Parameter("state", state)
            );
        }
        /// <summary>
        /// 0开始
        /// 1成功
        /// 2失败
        ///3.成功发奖
        /// </summary>
        /// <param name="state"></param>
        public void ShowInterstitialAd(int state)
        {
            FirebaseAnalytics.LogEvent(
                "click_InterstitialAd",
                new Parameter("state", state)
            );
        }
        public void ClickAds(int state)
        {
            FirebaseAnalytics.LogEvent(
                "click_ads",
                new Parameter("state", state)
            );
        }
        public void ShopView(string pageType)
        {
            FirebaseAnalytics.LogEvent(
                "shop_view",
                new Parameter("page_type", pageType)
            );
        }
        public void AdView(string pageType)
        {
            FirebaseAnalytics.LogEvent(
                "shop_view",
                new Parameter("page_type", pageType)
            );
        }
        public void ItemPurchase(string itemId, string price)
        {
            FirebaseAnalytics.LogEvent(
                "item_purchase",
                new Parameter("item_id", itemId),
                new Parameter("price", price)
            );
        }

        public void IAPTransaction(string productId, string price, string paymentMethod)
        {
            FirebaseAnalytics.LogEvent(
                "iap_transaction",
                new Parameter("product_id", productId),
                new Parameter("price", price),
                new Parameter("payment_method", paymentMethod)
            );
        }

        #endregion

        #region Social & UGC

        public void LevelShare(int levelNumber, string platform)
        {
            FirebaseAnalytics.LogEvent(
                "level_share",
                new Parameter("level_number", levelNumber),
                new Parameter("platform", platform)
            );
        }

        public void FriendInviteSent(string inviteChannel)
        {
            FirebaseAnalytics.LogEvent(
                "friend_invite_sent",
                new Parameter("invite_channel", inviteChannel)
            );
        }

        public void CustomLevelPublish(string levelId, string theme)
        {
            FirebaseAnalytics.LogEvent(
                "custom_level_publish",
                new Parameter("level_id", levelId),
                new Parameter("theme", theme)
            );
        }

        public void CustomLevelDownload(string levelId, string creatorId)
        {
            FirebaseAnalytics.LogEvent(
                "custom_level_download",
                new Parameter("level_id", levelId),
                new Parameter("creator_id", creatorId)
            );
        }

        #endregion

        #region System & Errors

        public void SettingsChanged(string settingType, string newValue)
        {
            FirebaseAnalytics.LogEvent(
                "settings_changed",
                new Parameter("setting_type", settingType),
                new Parameter("new_value", newValue)
            );
        }

        public void AchievementUnlocked(string achievementId, float progress)
        {
            FirebaseAnalytics.LogEvent(
                "achievement_unlocked",
                new Parameter("achievement_id", achievementId),
                new Parameter("progress", progress)
            );
        }

        public void ErrorOccurred(string errorCode, string context)
        {
            FirebaseAnalytics.LogEvent(
                "error_occurred",
                new Parameter("error_code", errorCode),
                new Parameter("context", context)
            );
        }

        #endregion

        #region Advanced Analytics

        public void TutorialSkip(int stepNumber)
        {
            FirebaseAnalytics.LogEvent(
                "tutorial_skip",
                new Parameter("step_number", stepNumber)
            );
        }

        public void TutorialCmpt(int stepNumber = 0)
        {
            FirebaseAnalytics.LogEvent(
                "tutorial_cmpt",
                new Parameter("step_number", stepNumber)
            );
        }
        public void JumpOver(int stepNumber = 0)
        {
            FirebaseAnalytics.LogEvent(
                "jump_over",
                new Parameter("step_number", stepNumber)
            );
        }
        public void AdImpression(string adType, string placement)
        {
            FirebaseAnalytics.LogEvent(
                "ad_impression",
                new Parameter("ad_type", adType),
                new Parameter("placement", placement)
            );
        }

        public void ABTestExposure(string experimentId, string variantId)
        {
            FirebaseAnalytics.LogEvent(
                "ab_test_exposure",
                new Parameter("experiment_id", experimentId),
                new Parameter("variant_id", variantId)
            );
        }

        #endregion
    }
    }