using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;

namespace GameLogic
{
    public class AppConst
    {
        /// <summary>
        /// 托管资源根目录，用于替换Resources目录
        /// </summary>
        public const string GameResName = "ManagedResources";

        /// <summary>
        /// 托管资源根目录路径（以Asset为根节点）
        /// </summary>
        public static string GameResPath = "Assets/" + GameResName;

        /// <summary>
        /// 托管资源根目录真实路径
        /// </summary>
        public static string GameResRealPath = Application.dataPath + "/" + GameResName;
        /// <summary>
        /// 每个游戏的lua环境
        /// </summary>
        public static string GameLuaSearchPath = GameResName + "/{0}/Lua";

        /// <summary>
        /// 是否为AB包模式
        /// </summary>
        public static bool bundleMode;

        /// <summary>
        /// 是否开启热更新
        /// </summary>
        public static bool isUpdate;
		/// <summary>
		/// 是否开启新手引导
		/// </summary>
		public static bool isGuide;
        /// <summary>
        /// 是否勾选GM
        /// </summary>
        public static bool isOpenGM;
        /// <summary>
        /// 是否勾选sdk
        /// </summary>
        public static bool isSDK;
        public static bool isSDKLogin;

        /// <summary>
        /// 是否勾选TLog(lua表结构log)
        /// </summary>
        public static bool isOpenTLog;
        /// <summary>
        /// 是否勾选BLog(战斗数据log)
        /// </summary>
        public static bool isOpenBLog;
        /// <summary>
        /// 初始语言
        /// </summary>
        public static int originLan;
        /// <summary>
        /// 渠道类型
        /// </summary>
        public static string ChannelType;

        public static bool DebugMode = false;                       //调试模式-用于内部测试
        /// <summary>
        /// 如果想删掉框架自带的例子，那这个例子模式必须要
        /// 关闭，否则会出现一些错误。
        /// </summary>
        public static bool ExampleMode = false;                       //例子模式 

        /// <summary>
        /// 如果开启更新模式，前提必须启动框架自带服务器端。
        /// 否则就需要自己将StreamingAssets里面的所有内容\
        /// 复制到自己的Webserver上面，并修改下面的WebUrl。
        /// </summary>
        public static bool LuaByteMode = false;                //Lua字节码模式-默认关闭 
        public static bool luaBundleMode = false;                    //Lua代码AssetBundle模式
        public static bool IsLocalServer = true;                     //是否采用本地服务器
        public static bool ShowDebug = true;                        // 开关调试信息

        public static int TimerInterval = 1;
        public static int GameFrameRate = 30;                        //游戏帧频
        public static int Channel_ID = 0;

        public static int PIXELTOWORLD = 100;

        public static ulong EncyptBytesLength = 128;  // 资源加密空白字符长度，长度为0则不加密

#if UNITY_ANDROID
        public const string DOWNLOAD_URL_FORMAT = "{0}/Android/{1}/{2}{3}/";
#elif UNITY_IOS
        public const string DOWNLOAD_URL_FORMAT = "{0}/IOS/{1}/{2}{3}";
#else
        public const string DOWNLOAD_URL_FORMAT = "{0}/OTHER/{1}/{2}{3}";
#endif
        /// <summary>
        /// 持久化目录
        /// </summary>
#if UNITY_EDITOR
        public static string Platform = "EDITOR";
        public static string PersistentDataPath = Application.dataPath + "/../AssetBundles/";
#elif UNITY_ANDROID
        public static string Platform = "ANDROID";
        public static string PersistentDataPath = Application.persistentDataPath + "/Android/";
#elif UNITY_IOS
        public static string Platform = "IOS";
        public static string PersistentDataPath = Application.persistentDataPath + "/IOS/";
#elif UNITY_STANDALONE_WIN
        public static string Platform = "WINDOWS";
        public static string PersistentDataPath = Application.persistentDataPath + "/Windows/";
#else
        public static string Platform = "OTHER";
        public static string PersistentDataPath = Application.persistentDataPath + "/Other/";
#endif




        /// <summary>
        /// 流媒体目录
        /// </summary>
#if UNITY_ANDROID
        public static string StreamPath = Application.streamingAssetsPath + "/Android/";
#elif UNITY_IOS
        public static string StreamPath = Application.streamingAssetsPath + "/IOS/";
#elif UNITY_STANDALONE_WIN
        public static string StreamPath = Application.streamingAssetsPath + "/Windows/";
#else
        public static string StreamPath = Application.streamingAssetsPath + "/Other/";
#endif

        public static string AppName = "LuaFramework";                //应用程序名称
        public static string AppPrefix = AppName + "_";                  //应用程序前缀
        public static string ExtName = ".unity3d";                           //素材扩展名
        public static string ResourcePath = "Resources/";

#if UNITY_ANDROID
        public static string AssetDir = "StreamingAssets/Android/";    //素材目录
        public static string LuaTempDir = "Android/Lua/";                            //临时目录
        public static string AssetRoot = "StreamingAssets/Android";            //素材根目录
        public static string PlatformPath = "Android";
        //public static string Download_Package_Url = "http://121.43.180.34/resource/doudou.apk";
#elif UNITY_IOS
        public static string AssetDir = "StreamingAssets/IOS/"; 
        public static string LuaTempDir = "IOS/Lua/";
        public static string AssetRoot = "StreamingAssets/IOS";            //素材根目录
        public static string PlatformPath = "IOS";  
        //public static string Download_Package_Url = "http://121.43.180.34/resource/doudou.apk";
#else
        public static string AssetDir = "StreamingAssets/Editor/";    //素材目录
        public static string LuaTempDir = "Editor/Lua/";
        public static string AssetRoot = "StreamingAssets/Editor";
        public static string PlatformPath = "Editor";
        //public static string Download_Package_Url = "http://121.43.180.34/resource/doudou.apk";
#endif

        //"http://192.168.0.15/address/get_address.php"
        //"http://192.168.1.11/address/get_address.php"
        //"http://192.168.1.7/address/get_address.php"
        //"http://116.62.144.108:8080/address/get_address.php"  
        //http://192.168.1.11/address/get_address.php

        public static string GameConfig_Url=null;

        public static bool IsMaintenance = false;
        public static string Download_apk_Url = string.Empty;
        public static string Download_ipa_Url = string.Empty;
        public static string JoinRoom_Url = string.Empty;
        public static string LoginRoot_Url = string.Empty;
        public static string Download_Resource_Root_Url = string.Empty;
        //public static int SocketPort = 0;                                                        //Socket服务器端口
        //public static string SocketAddress = string.Empty;                             //Socket服务器地址

        public static string Download_Resouces_Url = string.Empty;//"http://60.1.1.114/BuildABs/" + AppConst.PlatformPath + "/";

        public static string LaQi_JoinRoom_Url = string.Empty;  //拉起应用链接

        public const string LoadingMD5Flie = "files.txt";                  //加载界面更新MD5文件
        public const string GameVersionFile = "version.txt";            //游戏版本号文件

        public static int UserId;                                         //用户ID
        public static int Token;                                    //用户Token

        public static string SdkId;                                  //SDK UId
        public static string OpenId;                                  //开天SDK UId
        public static string TokenStr;                                  //开天SDK Token
        public static string MiTokenStr;                                  //开天SDK Token
        public static string SdkChannel;                                  //SDK 渠道
        public static string SdkPackageName;                                  //SDK包名


        public static int Url_JoinRoomID = 0;

        public static string LogToServerAddr = "http://119.3.154.143:9091/err";
        public static string ToServerAddr = "http://119.3.154.143:9091/log";

        public static string FrameworkRoot
        {
            get
            {
                return Application.dataPath + "/" + AppName;
            }
        }

//开天SDK参数
        public static string AppID;
        public const string AppKey = "c0fb59eb68559b6c9c1463e4d5d0c806";
        public const string PrivateKey = "MIICdwIBADANBgkqhkiG9w0BAQEFAASCAmEwggJdAgEAAoGBAPD9Qa8Db8CSJECkh+tEPmqniy1" +
            "B4FzH1L2rG6gtfZTA9UfEksIGZao3dUlCLACoPnhLqL5N/646P/qCR//H2q3JY/goyskAyWcrtqqwTaHwSFNY2mYfLPfV7tK+Ci6iyqK625Z" +
            "ZqaxwyTtPYDRFnzmCIDHdfe/GB8yakmtiEOZrAgMBAAECgYEAmA3DzvClJ2VOeHcXx4s0ssjqGPEy5neztMTs221wilZBrTnLu56bsQ3y8/lL" +
            "mFKPsAlU/FZsl/rq+V4QncP1Jm6mtMrPlYi/nhRKPQWQc76sMOpE8HsLdgmwDvbB+tgd0Px2gTAt9E5UJr1h++wmEh/lLSIju8bu1tV4/j70z" +
            "4kCQQD9Q2HxmwgN2YLEFGRniP6Sr1E/yVk8GGNbDNNL7bKu6iW4E3+zrHXqbtgCb0tO7heS29LwRGNyVkuKWbj38whvAkEA85frfGFCnYh" +
            "bS6SRxv9oDlYBsVIDVaZLdRf9qF/3rV7uQMyMTvZ0qUEqbXhCg6Pmodd/VxvOvSIMzW9iBqWnxQJAd3gIxNLwCrB3Sg2gi2KJTCKdfix6Bqouf" +
            "C3hoqifKHnVjy7Lh7Mr8ImXJhbf/Hy97A38RFDOZIommj3Wzkf7ywJBAMFXVnhddhM1NElAsNgCxmOCjktgrfbgS8n/pbxrl1lLHM3fzImsAgKJ" +
            "D5Tdu+ViRN81/QN1tczWZtTz0Bk4iIUCQDqAX2vfO1zrsFJq9fatsEx+scDHI+QVq7owt/757Qj1na9YPQumS6sHlkSpAN+L1GzGVfSQDtV+1yB" +
            "Spy9fI5Q=";

        //public static string ShareSDKAppID = string.Empty;
        //public static string ShareSDKSecret = string.Empty;

        //public static string WeChatAppID = string.Empty;
        //public static string WeChatSecret = string.Empty;
        //public static string WeChat_AccessToken = string.Empty;
        //public static string WeChat_OpenID = string.Empty;

        public static string LoginUrl = string.Empty;
        public static string LogoutUrl = string.Empty;
        public static string SDKLoginUrl = string.Empty;

        public static int SessionPlatform = -1;
        public static string Session = string.Empty;
        public static string Code = string.Empty;

        //public static string UmengAppKey_Andriod = string.Empty;
        //public static string UmengAppKey_Ios = string.Empty;
        //public static string UmengChannleId = string.Empty;

        //public static string Bugly_IosAppId = string.Empty;
        //public static string Bugly_AndroidAppId = string.Empty;

        //public static string ShareSDK_AppID = string.Empty;
        //public static string ShareSDK_AppSecret = string.Empty;

        public static float ConnectTimeout = 3.0f;
        public static float HttpTimeout = 3.0f;
        public static string AliyResourceErrorStr = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Error>\n  <Code>NoSuchKey</Code>\n  <Message>The specified key does not exist.</Message>";
    }
}