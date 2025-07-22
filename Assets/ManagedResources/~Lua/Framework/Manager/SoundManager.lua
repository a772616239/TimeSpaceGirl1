--region *.lua
--Date
--此文件由[BabeLua]插件自动生成
local _IsLog = false
local function __DebugLog(content)
    if _IsLog then
    end
end

SoundManager = { }

local eAudioType = {
    uiAudio = 1,
    bgAudio = 2,
    amAudio = 3,
    cvAudio = 4,
}

AUDIO_RUN_TYPE = {  -- 音效切换执行方式
    SEQ = 1,    -- 顺序
    CONC = 2    -- 并发
}
AUDIO_FADE_TYPE = {  -- 音效淡入淡出方式
    FADE_OUT_AND_IN = 1,    -- 淡入淡出
    FADE_OUT_NOT_IN = 2,    -- 淡出不淡入
    FADE_IN_NOT_OUT = 3,    -- 淡入不淡出
    DIRECT_CHANGE = 4       -- 直接变化
}

SoundManager.soundChannelCount = 20
SoundManager.soundVolume = 1
SoundManager.backgroundSoundVolume = 1
SoundManager.cachePlayTime = 0.16

local timer
local timeDown

-- 相同音效的播放间隔
local _AudioPlayCD = 0.05
local _AudioPlayList = {}

local _sfx_enabled = true
local _bgm_enabled = true
local _amb_enabled = true

local _backgroundSound = {}
local _backgroundRes

local _AmbientChannel = {}
local _AmbientRes

local _soundChannel = { }
local _cvChannel = {}
local AudioSource = UnityEngine.AudioSource
local AudioConfig = {}
local SoundDef = {
    "Music",    --背景音
    "Ambient",  --环境音效
    "common",   --普通UI音效
    "skill",    --技能音效 --[[
    "buff",     --技能音效         4,5,6,7统一使用skill音轨进行处理
    "monster",  --技能音效
    "yiyao",    --技能音效   ]]

    "footsteps", -- 脚步声
    "other",     -- 其他ui音效
    "special",   -- 特殊ui音效
    "Voice",     -- 配音音效
    "CV",        -- 战斗CV
}
local _node
function SoundManager.Clear()
    if _node ~= nil then
        SoundManager.ClearResource()
        GameObject.Destroy(_node)
        _node = nil
    end
end

function SoundManager.ClearResource()
    -- 资源回收
    for i = 1, SoundManager.soundChannelCount do
        local audioUnit = _soundChannel[i]
        if audioUnit then
            audioUnit.audio:Stop()
            if audioUnit.audio.clip then
                if audioUnit.audioType == eAudioType.uiAudio then
                    poolManager:UnLoadAsset(audioUnit.audio.clip.name,audioUnit.audio.clip, PoolManager.AssetType.MediaUI)
                    audioUnit.audio.clip = nil
                end
            end
        end
    end

    if _backgroundSound then
        for i = 1, #_backgroundSound do
            local audioBg = _backgroundSound[i]
            if audioBg then
                audioBg.audio:Stop()
                if audioBg.audio.clip then
                    poolManager:UnLoadAsset(audioBg.audio.clip.name,audioBg.audio.clip, PoolManager.AssetType.MediaUI)
                    audioBg.audio.clip = nil
                end
            end
        end
    end

    if _AmbientChannel then
        for i = 1, #_AmbientChannel do
            local audioBg = _AmbientChannel[i]
            if audioBg then
                audioBg.audio:Stop()
                if audioBg.audio.clip then
                    poolManager:UnLoadAsset(audioBg.audio.clip.name,audioBg.audio.clip, PoolManager.AssetType.MediaUI)
                    audioBg.audio.clip = nil
                end
            end
        end
    end

    if _cvChannel then
        for i = 1, #_cvChannel do
            local audioBg = _cvChannel[i]
            if audioBg then
                audioBg.audio:Stop()
                if audioBg.audio.clip then
                    poolManager:UnLoadAsset(audioBg.audio.clip.name,audioBg.audio.clip, PoolManager.AssetType.MediaUI)
                    audioBg.audio.clip = nil
                end
            end
        end
    end
end

function SoundManager.Initialize()
    SoundManager.Clear()
    _node = GameObject("Sound Listener")
    GameObject.DontDestroyOnLoad(_node)

    for k, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.AudioConfig)) do
        AudioConfig[v.Name] = {
            mixType = SoundDef[v.Type],
            isLoop = v.Loop == 1
        }
    end

    for i = 1, SoundManager.soundChannelCount do
        local chanel = _node:AddComponent(typeof(AudioSource))
        chanel.minDistance = 480
        chanel.enabled = true
        chanel.playOnAwake = false
        chanel.loop = false
        local audioUnit = {}
        audioUnit.audio = chanel
        audioUnit.audioType = eAudioType.uiAudio
        audioUnit.isLock = false
        table.insert(_soundChannel, audioUnit)
    end

    local _as = _node:AddComponent(typeof(AudioSource))
    _as.minDistance = 480
    _as.playOnAwake = false
    _as.loop = false
    local audioUnit = {}
    audioUnit.audio = _as
    audioUnit.audioType = eAudioType.bgAudio
    audioUnit.isLock = false
    table.insert(_backgroundSound, audioUnit)

    local _am = _node:AddComponent(typeof(AudioSource))
    _am.minDistance = 480
    _am.playOnAwake = false
    _am.loop = false
    local audioUnit = {}
    audioUnit.audio = _am
    audioUnit.audioType = eAudioType.amAudio
    audioUnit.isLock = false
    table.insert(_AmbientChannel, audioUnit)

    local _am = _node:AddComponent(typeof(AudioSource))
    _am.minDistance = 480
    _am.playOnAwake = false
    _am.loop = false
    local audioUnit = {}
    audioUnit.audio = _am
    audioUnit.audioType = eAudioType.cvAudio
    audioUnit.isLock = false
    table.insert(_cvChannel, audioUnit)

    if timer then
        timer:Stop()
        timer = nil
    end
    timeDown = 0
end


-- 外部改变音量大小
function SoundManager.ChangeSettingVolume(settingType, value)
    if settingType == SETTING_TYPE.BGM_RATIO then
        for _, unit in ipairs(_backgroundSound) do
            unit.audio.volume = SoundManager.backgroundSoundVolume * value
        end
    elseif settingType == SETTING_TYPE.SOUND_RATIO then
        for _, unit in ipairs(_soundChannel) do
            unit.audio.volume = SoundManager.backgroundSoundVolume * value
        end
        for _, unit in ipairs(_AmbientChannel) do
            unit.audio.volume = SoundManager.backgroundSoundVolume * value
        end
    elseif settingType == SETTING_TYPE.CV_RATIO then
        for _, unit in ipairs(_cvChannel) do
            unit.audio.volume = SoundManager.backgroundSoundVolume * value
        end
    end
end

-- 根据音效类型获取音效配置
local function GetAudioConfigByType(audioType)
    if audioType == eAudioType.uiAudio then
        return {volumeType = SETTING_TYPE.SOUND_RATIO, defaultVolume = 1}
    elseif audioType == eAudioType.bgAudio then
        return {volumeType = SETTING_TYPE.BGM_RATIO, defaultVolume = 1}
    elseif audioType == eAudioType.amAudio then
        return {volumeType = SETTING_TYPE.SOUND_RATIO, defaultVolume = 1}
    elseif audioType == eAudioType.cvAudio then
        return {volumeType = SETTING_TYPE.CV_RATIO, defaultVolume = 1}
    end
end

--[[
    clipName:音效资源名字
    channel：固定音轨 nil:用空闲音轨播放
]]
local function setAudioMixer(clipName, audioUnit)
    local config = AudioConfig[clipName]
    if not config then
        audioUnit.audio.loop = false
        return
    end
    if config.mixType and audioUnit.mixType ~= config.mixType then
        Util.SetAudioMixer(config.mixType, audioUnit.audio)
        audioUnit.mixType = config.mixType
    end
    audioUnit.audio.loop = config.isLoop
end

-- 设置audioUnit
local function _SetAudioUnit(audioUnit, resName, auildType, volume)
    -- __DebugLog("_SetAudioUnit -------->"..resName)
      -- 检查是否包含 "x1" 且不包含 "cn-2"
    -- local lowerResName = resName
    -- if string.find(lowerResName, "x1") and  string.find(lowerResName, "cn2%-") then
    --     lowerResName = resName:gsub("^cn2%-", "")  -- 移除开头的 "cn2-"
    -- end
    -- 获取声音文件
    local clipNew = poolManager:LoadAsset(resName, PoolManager.AssetType.MediaBg)
    if not clipNew then return nil end
    -- 卸载旧音效
    if audioUnit.audio.clip then
        poolManager:UnLoadAsset(audioUnit.audio.clip.name,audioUnit.audio.clip, PoolManager.AssetType.MediaBg)
        -- __DebugLog("卸载旧音效 -------->"..audioUnit.audio.clip.name)
        audioUnit.audio.clip = nil
    end
    -- 获取类型配置
    if not volume then
        local audioTypeConfig = GetAudioConfigByType(auildType)
        local ratio = SettingManager.GetSettingData(audioTypeConfig.volumeType)
        volume = audioTypeConfig.defaultVolume * ratio
    end
    -- 是否循环
    local config = AudioConfig[resName]
    local isLoop = config and config.isLoop
    -- 播放新音效
    if isLoop then
        audioUnit.audio.clip = clipNew
        audioUnit.audio.volume = volume
        audioUnit.audioType = auildType
        audioUnit.audio.loop = isLoop
        audioUnit.audio:Play()
    else
        audioUnit.audio.pitch = Time.timeScale
            -- 将 resName 转为小写
        local lowerResName = string.lower(resName)
        
  
        --Log("resName"..resName)
        local data = ConfigManager.GetConfigDataByKey(ConfigName.AudioConfig, "Name", resName)
        if data then
            if data.Type == 12 then
                audioUnit.audio.pitch = 1
                if timeDown <= 0 then
                    timeDown = clipNew.length
                    SoundManager.CVTimeDown()
                else
                    return
                end
            end
        end
        audioUnit.audio:PlayOneShot(clipNew, volume)
    end
    setAudioMixer(resName, audioUnit)
end

local function _StopAudioUnit(audioUnit)
    -- 卸载旧音效
    if audioUnit.audio.clip then
        poolManager:UnLoadAsset(audioUnit.audio.clip.name,audioUnit.audio.clip, PoolManager.AssetType.MediaBg)
        -- __DebugLog("卸载旧音效 -------->"..audioUnit.audio.clip.name)
        audioUnit.audio.clip = nil
    end
    audioUnit.audio:Stop()
end

local _FadeTime = 1
local function _FadeOutUnit(audioUnit, _FadeDone)
    if not audioUnit then
        if _FadeDone then _FadeDone() end
    end
    -- 声音淡出
    DoTween.To(
            DG.Tweening.Core.DOGetter_float( function () return audioUnit.audio.volume end),
            DG.Tweening.Core.DOSetter_float(
                    function (progress)
                        audioUnit.audio.volume = progress
                    end),
            0, _FadeTime)
           :SetEase(Ease.Linear)
           :OnComplete(
            function ()
                -- 淡出完成回调
                _StopAudioUnit(audioUnit)
                if _FadeDone then _FadeDone() end
            end)
end
local function _FadeInUnit(audioUnit, auildType, _FadeDone)
    if not audioUnit then
        if _FadeDone then _FadeDone() end
    end
    -- 获取类型配置
    local audioTypeConfig = GetAudioConfigByType(auildType)
    -- 声音淡入
    DoTween.To(
            DG.Tweening.Core.DOGetter_float( function () return 0 end),
            DG.Tweening.Core.DOSetter_float(function (progress)
                local ratio = SettingManager.GetSettingData(audioTypeConfig.volumeType)
                audioUnit.audio.volume = progress * ratio
            end),
            audioTypeConfig.defaultVolume, _FadeTime)
           :SetEase(Ease.Linear)
           :OnComplete(function()
        -- 淡入完成回调
        if _FadeDone then _FadeDone() end
    end)
end

-- 切换音效
local function _ChangeAudio(outUnit, inUnit, resName, audioType, fadeType, runType, _FadeOutDone, _FadeInDone)
    fadeType = fadeType or AUDIO_FADE_TYPE.DIRECT_CHANGE
    runType = runType or AUDIO_RUN_TYPE.SEQ

    if fadeType == AUDIO_FADE_TYPE.FADE_OUT_AND_IN then
        if runType == AUDIO_RUN_TYPE.SEQ then
            _FadeOutUnit(outUnit, function()
                -- 淡出完成回调
                _SetAudioUnit(inUnit, resName, audioType, 0)
                if _FadeOutDone then _FadeOutDone() end
                _FadeInUnit(inUnit, audioType, _FadeInDone)
            end)
        elseif runType == AUDIO_RUN_TYPE.CONC then
            _FadeOutUnit(outUnit, _FadeOutDone)
            _SetAudioUnit(inUnit, resName, audioType, 0)
            _FadeInUnit(inUnit, audioType, _FadeInDone)
        end

    elseif fadeType == AUDIO_FADE_TYPE.FADE_OUT_NOT_IN then
        if runType == AUDIO_RUN_TYPE.SEQ then
            _FadeOutUnit(outUnit, function()
                -- 淡出完成回调
                _SetAudioUnit(inUnit, resName, audioType)
                if _FadeOutDone then _FadeOutDone() end
                if _FadeInDone then _FadeInDone() end
            end)
        elseif runType == AUDIO_RUN_TYPE.CONC then
            _FadeOutUnit(outUnit, _FadeOutDone)
            _SetAudioUnit(inUnit, resName, audioType)
            if _FadeInDone then _FadeInDone() end
        end
    elseif fadeType == AUDIO_FADE_TYPE.FADE_IN_NOT_OUT then
        -- 顺序，同步相同
        _StopAudioUnit(outUnit)
        _SetAudioUnit(inUnit, resName, audioType, 0)
        if _FadeOutDone then _FadeOutDone() end
        _FadeInUnit(inUnit, _FadeInDone)
    elseif fadeType == AUDIO_FADE_TYPE.DIRECT_CHANGE then
        _StopAudioUnit(outUnit)
        _SetAudioUnit(inUnit, resName, audioType)
        if _FadeOutDone then _FadeOutDone() end
        if _FadeInDone then _FadeInDone() end
    end
end

---- ==============================播放音效===================================
function SoundManager.PlaySound(clipName, fadeType, runType, channel, outChannel)
    -- __DebugLog("*****")
    -- 判断是否符合音效时间限制
    if _AudioPlayList[clipName] then
        local startTime = _AudioPlayList[clipName].startTime
        local nowTime = Time.realtimeSinceStartup
        if nowTime - startTime < _AudioPlayCD then
            -- __DebugLog("与同名音效播放时间间隔小于cd时间被舍弃，音效："..clipName)
            return
        end
    end

    local function _AddStartTime()
        -- 记录音效播放时间点
        _AudioPlayList[clipName] = {
            startTime = Time.realtimeSinceStartup
        }
    end

    --找一个空闲的音源播放
    if not channel then
        for i = 1, SoundManager.soundChannelCount do
            local audioUnit = _soundChannel[i]
            if not audioUnit.audio.isPlaying then
                channel = i
                break
            end
        end
    end
    if not channel then
        return
    end
    if not outChannel then
        outChannel = channel
    end
    -- __DebugLog("播放音效-------->"..clipName.."channel ->"..channel.."outChannel ->"..outChannel)
    local inUnit = _soundChannel[channel]
    local outUnit = _soundChannel[outChannel]
    _ChangeAudio(outUnit, inUnit, clipName, eAudioType.uiAudio, fadeType, runType, _AddStartTime)

    return inUnit
end

-- 通过通道关闭音效
function SoundManager.StopSoundByChannel(channel)
    local audioUnit = _soundChannel[channel]
    _StopAudioUnit(audioUnit)
end

-- 关闭音效
function SoundManager.StopSound(audioUnit)
    _StopAudioUnit(audioUnit)
end

function SoundManager.StopAllChannelSound()
    for i = 1, SoundManager.soundChannelCount do
        local audioUnit = _soundChannel[i]
        if audioUnit and audioUnit.audio.isPlaying then
            SoundManager.StopSoundByChannel(i)
        end
    end
end

function SoundManager.PlayBattleSound(clipName)
    if not UIManager.IsOpen(UIName.BattlePanel) and not UIManager.IsOpen(UIName.GuideBattlePanel) and BattleManager.IsInBackBattle() then
        return
    end
    SoundManager.PlaySound(clipName)
end

--- =================================背景音======================================
local _MusicTimer = nil
function SoundManager.PlayMusic(resName, isFade, callback)
    --   Log("PlayMusic resName1:"..resName)
    -- if startswith2(resName,"cn2-")   then
    --     resName = string.sub(resName, 5)  -- 移除开头的 "cn2-"
    --     Log("PlayMusic resName2:"..resName)
    -- end

    -- Log("PlayMusic resName3:"..resName)
    if resName == nil then return end
    if resName == _backgroundRes then return end

    if not _backgroundSound then return end
    local audioUnit = _backgroundSound[1]
    if not audioUnit then return end

    _backgroundRes = resName

    local function _SetTimer()
        -- 关闭音乐计时器
        if _MusicTimer then
            _MusicTimer:Stop()
            _MusicTimer = nil
        end
        if callback then
            -- 获取声音文件
            local config = AudioConfig[resName]
            local isLoop = config and config.isLoop
            _MusicTimer = Timer.New(callback, audioUnit.audio.clip.length, isLoop and -1 or 1, true)
            _MusicTimer:Start()
        end
    end
    local fadeType = AUDIO_FADE_TYPE.DIRECT_CHANGE
    if isFade == nil or isFade then
        fadeType = AUDIO_FADE_TYPE.FADE_OUT_AND_IN
    end
    _ChangeAudio(audioUnit, audioUnit, resName, eAudioType.bgAudio, fadeType, AUDIO_RUN_TYPE.SEQ, _SetTimer)
end
--暂停当前背景音乐
function SoundManager.StopMusic()
    local audioUnit = _backgroundSound[1]
    if audioUnit then
        audioUnit.audio:Stop()
    end
    -- 关闭音乐计时器
    if _MusicTimer then
        _MusicTimer:Stop()
        _MusicTimer = nil
    end
    _backgroundRes = nil
end

---=============================环境音效============================================
function SoundManager.PlayAmbient(resName)
    if not resName then return end
    -- 播放相同音效
    if resName == _AmbientRes then return end
    -- 通道检测
    if not _AmbientChannel or not _AmbientChannel[1] then return end

    local audioUnit = _AmbientChannel[1]
    if not audioUnit then return end

    _AmbientRes = resName

    _ChangeAudio(audioUnit, audioUnit, resName, eAudioType.amAudio, AUDIO_FADE_TYPE.FADE_OUT_AND_IN, AUDIO_RUN_TYPE.SEQ)
end
--暂停当前背景音乐
function SoundManager.PauseAmbient()
    local audioUnit = _AmbientChannel[1]
    if audioUnit then
        -- 声音淡出
        DoTween.To(
                DG.Tweening.Core.DOGetter_float( function () return audioUnit.audio.volume end),
                DG.Tweening.Core.DOSetter_float(
                        function (progress)
                            audioUnit.audio.volume = progress
                        end),
                0, 1)
               :SetEase(Ease.Linear)
               :OnComplete(function ()
            audioUnit.audio:Pause()
        end)
    end
    _AmbientRes = nil
end


--- ========================== 音效控制===========================
function SoundManager.GetSoundEnabled()
    return _sfx_enabled
end

function SoundManager.SetSoundEnabled(b)
    if _sfx_enabled == b then return end
    _sfx_enabled = b
end

function SoundManager.GetBgmEnabled()
    return _bgm_enabled
end

function SoundManager.SetBgmEnabled(b)
    if _bgm_enabled == b then return end
    _bgm_enabled = b
end

-- 设置音效播放速度
function SoundManager.SetAudioSpeed(speed)
    speed = speed or 1
    -- for _, unit in ipairs(_backgroundSound) do
    --     unit.audio.pitch = speed
    -- end

    for _, unit in ipairs(_soundChannel) do
        if not unit.mixType or unit.mixType ~= SoundDef[12] then
            unit.audio.pitch = speed
        end
    end
    for _, unit in ipairs(_AmbientChannel) do
        unit.audio.pitch = speed
    end
end

function SoundManager.Dispose()
    SoundManager.Clear()
end

function SoundManager.CVTimeDown()
    if timer then
        timer:Stop()
        timer = nil
    end
    timer = Timer.New(function()
        if timeDown < 0 then
            timer:Stop()
            timer = nil
        end
        timeDown = timeDown - 1
    end, 1, -1, true)
    timer:Start()
end

function SoundManager.SetBattleVolume(volume)
    SoundManager.ChangeSettingVolume(SETTING_TYPE.SOUND_RATIO, volume)
    SoundManager.ChangeSettingVolume(SETTING_TYPE.CV_RATIO, volume)
end

--endregion
