SettingManager = {}
local this = SettingManager

-- 设置默认值
local _SettingData = {
    -- 整数

    -- 浮点数
    [SETTING_TYPE.BGM_RATIO] = 1,
    [SETTING_TYPE.SOUND_RATIO] = 0.5,

    -- 字符串

}

function this.Initialize()
    for _, t in pairs(SETTING_TYPE) do
        local v = PlayerPrefs.GetString("SettingType_"..t)
        if t > 0 and t < 100 then
            v = tonumber(v)
        elseif t > 100 and t < 200 then
            v = tonumber(v)
        elseif t > 200 and t < 300 then
            v = tostring(v)
        end
        if v then
            _SettingData[t] = v
        end
    end
end

function this.SetSettingData(t, v)
    if not t or not v then return end
    -- 存数据
    PlayerPrefs.SetString("SettingType_"..t, tostring(v))
    -- 保存数据
    _SettingData[t] = v
    -- 发送设置改变事件
    Game.GlobalEvent:DispatchEvent(GameEvent.Setting.OnSettingChanged, t, v)

    if t == SETTING_TYPE.BGM_RATIO or t == SETTING_TYPE.SOUND_RATIO then
        SoundManager.ChangeSettingVolume(t, v)
    end

end

function this.GetSettingData(settingType)
    return _SettingData[settingType]
end

return this