--协议类型--
ProtocalType = {
	BINARY = 0,
	PB_LUA = 1,
	PBC = 2,
	SPROTO = 3,
}
--当前使用的协议类型--
TestProtoType = ProtocalType.BINARY

Util = GameLogic.Util
AppConst = GameLogic.AppConst
LuaHelper = GameLogic.LuaHelper
ByteBuffer = GameLogic.ByteBuffer
resMgr = App.ResMgr
iapMgr = App.IAPMgr
ggSignMgr = App.GoogleSignMgr
ReviewMgr = App.ReviewMgr
--soundMgr = App.SoundMgr
networkMgr = App.NetWorkMgr
gameMgr = App.GameMgr
speakMgr = App.SpeakMgr
--shareSDKMgr = App.ShareSDKMgr
SDKMgr = App.SDKMgr
VersionManager=App.VersionMgr
--umengsdk=App.UmengSdkMgr
imageDownloadMgr = App.ImageDownloadMgr
--BuglySdkManager=App.BuglySdkMgr
--PhoneMgr = App.PhoneMgr
PoolMgr = App.ObjectPoolMgr
WWW = UnityEngine.WWW
GameObject = UnityEngine.GameObject
Camera = UnityEngine.Camera
Input = UnityEngine.Input
Screen = UnityEngine.Screen
RectTransformUtility = UnityEngine.RectTransformUtility
LayoutUtility = UnityEngine.UI.LayoutUtility

Tweening = DG.Tweening
Ease = DG.Tweening.Ease
DoTween = DG.Tweening.DOTween

Rect = UnityEngine.Rect
PlayerPrefs = UnityEngine.PlayerPrefs
Shader = UnityEngine.Shader

-- IsWeChatLogin =  true
-- IsAccountLogin =  false

-- IsIosPublish=false
--是否为微信自动登录
-- IsAutoWeChatLogin = true
--为0显示所有log，为1显示警告和错误，为2显示错误
LogModeLevel = 0
PassTimes1=1
--是否开启战斗调试
IsOpenBattleDebug = not AppConst.luaBundleMode

-- AppConst.ShareSDKAppID = "1f2577fdf25ab"
-- AppConst.ShareSDKSecret = "3a746f9f16fcf82b03fd33a7f2a33e53"

-- AppConst.WeChatAppID = "wxe62c94a32796c496"
-- AppConst.WeChatSecret = "e5278caf943b221493bb67b686bbb41f"

-- AppConst.UmengAppKey_Andriod = "595cabca677baa73be000abe"
-- AppConst.UmengAppKey_Ios = "595cac0fa325110ac80018ca"
-- AppConst.UmengChannleId = "App Store"

-- AppConst.Bugly_IosAppId = "c07e578650"
-- AppConst.Bugly_AndroidAppId = "9b909facba"

AppConst.LaQi_JoinRoom_Url = "com.doudou.dwc://data/openwith?"

Switch_MultiLanguage = true 						--< 多语言开关
