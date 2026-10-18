require "PreLoad"
require "Logic/GameEvent"

--管理器--
Game = {}
local this = Game

--初始化完成，发送链接服务器信息--
function Game.Initialize()
	this.CurPlatform = tostring(UnityEngine.Application.platform)
	U3d.Application.runInBackground = true
    Screen.fullScreen = true
    Screen.sleepTimeout = U3d.SleepTimeout.NeverSleep
    this.GlobalEvent = EventManager.New()
    this.InitManagers()
    -- 运行期补充 UI 配置（国家排行等；见 Modules/CountryRank/UIConfigExtension.lua）
    -- 必须在 InitManagers 之后、第一次 OpenPanel 之前调用
    require("Modules/CountryRank/UIConfigExtension").Register()
    UIManager.OpenPanelWithNoSound(UIName.LoginPanel)
end

--初始化管理器
function Game.InitManagers()
    Framework.Initialize()
    local managers = require("Common/Managers")
    local manager
    for i, v in ipairs(managers) do
        manager =  require("Modules/"..v)
        manager.Initialize()
    end
end

function Game.Logout()
    if AppConst.isSDKLogin then
        SDKMgr:Logout()
    else
        Game.Restart()
    end
end

function Game.Restart()
    Framework.Dispose()
    -- 退出时把socket断掉
    SocketManager.Disconnect(SocketType.LOGIN)
    -- 
    App.Instance:ReStart()
end

--应用程序暂停/恢复
function Game.OnApplicationPause(pauseStatus)
   
end

--应用程序获得焦点/失去焦点
function Game.OnApplicationFocus(hasFocus)
   
end

--应用程序退出
function Game.OnApplicationQuit()

end