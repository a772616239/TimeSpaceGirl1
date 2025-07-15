--region *.lua
--Date
--此文件由[BabeLua]插件自动生成


require "Framework/Manager/UIManager"
require "Framework/Manager/PoolManager"
require "Framework/Manager/SoundManager"
--require "Framework/Manager/CardRendererManager"
require "Framework/Manager/TankRendererManager"
require "Framework/Manager/ServerConfigManager"
require "Data/UIData"
require "Data/SoundData"
require "Data/ConfigData"

Framework = { }

Framework.isDebug = false
Framework.PlayClickSoundThisTime = false --允许这次点击播放声音，否则不播，并且下次继续播

local effectPos = Vector3.New(Screen.width / 2, Screen.height / 2, 0)
local update = function()
    if Input.GetKeyDown(UnityEngine.KeyCode.Escape) then
        if AppConst.isSDK and SDKMgr:IsSupportExit() then
            if LoginManager.IsLogin then
                SubmitExtraData({ type = SDKSubMitType.TYPE_EXIT_GAME })
                SDKMgr:ExitGame()
            else
                SDKMgr:ExitGame()
            end
        else
            MsgPanel.ShowTwo(GetLanguageStrById(23008), nil, function()
                Framework.Dispose()
                UnityEngine.Application.Quit()
            end)
        end
    end

    -- 临时退出游戏代码
    if not AppConst.isSDK and Input.GetKeyDown(UnityEngine.KeyCode.Tab) then
        MsgPanel.ShowTwo(GetLanguageStrById(23009), nil, function()
            Framework.Dispose()
            App.Instance:ReStart()
        end)
    end

    if Input.GetMouseButtonUp(0) then
        if Framework.PlayClickSoundThisTime then
            SoundManager.PlaySound(SoundConfig.Sound_UIClick)
            local clickEffect = poolManager:LoadAsset("N1_eff_UI_click", PoolManager.AssetType.GameObject) --n1
            clickEffect.transform:SetParent(UIManager.fixedNode)
            clickEffect.transform.localScale = Vector3.one
            clickEffect.transform.localPosition = Vector3.zero
            local v3 = Input.mousePosition - effectPos
            local sc = 1
            if Screen.width/Screen.height <= 1080/1920 then
                sc = 1080 / Screen.width
            else
                sc = 1920 / Screen.height
            end
            v3 = Vector3.New(v3.x * sc, v3.y * sc, v3.z)
            -- v3 = Vector3.New(v3.x / UIManager.width * 1080, v3.y / UIManager.height * 1920, v3.z)
            -- v3 = Vector3.New(v3.x / UIManager.width * UIManager.UIWidth, v3.y / UIManager.height * UIManager.UIHeight, v3.z)
            clickEffect:GetComponent("RectTransform").anchoredPosition = v3
            clickEffect:SetActive(true)

            local timer = Timer.New(function()
                poolManager:UnLoadAsset("N1_eff_UI_click", clickEffect, PoolManager.AssetType.GameObject) --n1
            end, 1, false, true)
            timer:Start()
        else
            Framework.PlayClickSoundThisTime = true
        end
    end

    --TODO:快速重新登录
    --if Input.GetKeyDown('1') then
    --    Framework.Dispose()
    --    App.Instance:ReStart()
    --end
end
--框架初始化
function Framework.Initialize()
    ConfigManager.Initialize()
    SoundManager.Initialize()
    poolManager = PoolManager:new()
    UIManager.Initialize()
    
    --CardRendererManager.Initialize()
    --TankRendererManager.Initialize()
    ServerConfigManager.Initialize()

    UpdateBeat:Add(update, Framework)
end

--销毁框架
function Framework.Dispose()
    UIManager.Dispose()
    SoundManager.Dispose()
    --CardRendererManager.Dispose()
    TankRendererManager.Dispose()
    poolManager:onDestroy()

    UpdateBeat:Remove(update, Framework)
end

--endregion
