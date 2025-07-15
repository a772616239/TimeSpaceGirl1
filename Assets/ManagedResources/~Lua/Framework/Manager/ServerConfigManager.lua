
ServerConfigManager = { }
local _ActiveCode = 26   -- 激活版本

ServerConfigManager.SettingConfig = {
    ServerVersion = "ServerVersion",    -- 用于切换正式服和提审服
    ThinkAnalysis_GetDeviceID = "ThinkAnalysis_GetDeviceID",    -- 数数获取DeviceID方法
    LayoutBuilderWrap = "LayoutBuilderWrap",                    -- 强制刷新layout组件大小的方法修改到lua中调用
    LanguagePackager = "LanguagePackager",                      -- 本地化处理
    UI_Layout_CanvasScaler = "UI_Layout_CanvasScaler",          -- 屏幕适配
    IS_PLAY_VOICE = "IS_PLAY_VOICE",                            -- 是否播放游戏内语音
    IS_SHOW_HEALTH_TIP = "IS_SHOW_HEALTH_TIP",                  -- 是否显示健康提示
    NOTICE_CHANNEL = "NOTICE_CHANNEL",                          -- 公告号
    PACKAGE_CC_CODE = "PACKAGE_CC_CODE",                        -- CC号
    SPRITE_LOADER = "SPRITE_LOADER",                            -- 资源加载器是否可以使用
    IS_TITLE_EFFECT_SCALE = "IS_TITLE_EFFECT_SCALE",            -- 判断
    IS_PLAY_LOGIN_VIDEO = "IS_PLAY_LOGIN_VIDEO",                -- 判断是否可以播放登录视频
    PACKAGE_CONFIG = "PACKAGE_CONFIG",                          -- 包配置
    IS_NO_TALKING = "IS_NO_TALKING",                            -- 禁言
}


function ServerConfigManager.Initialize()
    IS_PLAY_VOICE = ServerConfigManager.IsSettingActive(ServerConfigManager.SettingConfig.IS_PLAY_VOICE) -- 是否开启游戏内的语音
    IS_SHOW_HEALTH_TIP = ServerConfigManager.IsSettingActive(ServerConfigManager.SettingConfig.IS_SHOW_HEALTH_TIP) -- 是否开启游戏内的语音
end

-- 判断设置是否激活
function ServerConfigManager.IsSettingActive(settingType)
    local s_isActive = "Setting."..settingType..".isActive"
    local s_versionCode = "Setting."..settingType..".versionCode"
    local isActive = ServerConfigManager.GetConfigInfo(s_isActive)
    if isActive and isActive == "1" then -- 激活
        if not AppConst.isSDK then
            return true
        end
        local vc = AndroidDeviceInfo.Instance:GetVersionCode()
        if vc >= tonumber(ServerConfigManager.GetConfigInfo(s_versionCode)) then  --符合包版本
            return true
        end
    end
    return false
end
function ServerConfigManager.GetSettingValue(settingType)
    if ServerConfigManager.IsSettingActive(settingType) then
        local s_value = "Setting."..settingType..".value"
        local value = ServerConfigManager.GetConfigInfo(s_value)
        return value
    end
end

-- 获取version信息（老版本信息，新版中用于获取版本号，包版本号，）
function ServerConfigManager.GetVersionInfo(key)
    local v = ServerConfigManager.GetConfigInfo(key)
    if not v then
        v = VersionManager:GetVersionInfo(key)
    end
    return v 
end

-- 
function ServerConfigManager.GetConfigInfo(key)
    -- 包版本大于启用的版本使用新的配置
    if not AppConst.isSDK or AndroidDeviceInfo.Instance:GetVersionCode() >= _ActiveCode then
        if not ConfigMgr then
            ConfigMgr=App.ConfigMgr
        end
        local s = ConfigMgr:GetConfigInfo(key)
        return s
    end
end


function ServerConfigManager.GetSDKVersionCode()
    if AppConst.isSDK then
        return AndroidDeviceInfo.Instance:GetVersionCode()
    end
    return 9999
end