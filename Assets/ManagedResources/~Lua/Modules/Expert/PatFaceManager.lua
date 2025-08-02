PatFaceManager = {}
local this = PatFaceManager
this.isFirstLog = 0--0当天第一次登陆
this.isLogin = false

function this.Initialize()
    Game.GlobalEvent:AddEvent(GameEvent.PatFace.PatFaceSend, this.OnAddPatFaceData)
end

function this.SetisFirstLogVal(isDayFirst, setPatFaceFinishTabs)
    this.isFirstLog = isDayFirst
    if this.isFirstLog == 0 then--是否是今天的第一次登陆
        for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.LoginPosterConfig)) do
            if v.ShowType == 1 then--一天一清
                if RedPointManager.PlayerPrefsGetStr(v.Id.."PatFace") ~= "0" then
                    RedPointManager.PlayerPrefsDeleteStr(v.Id.."PatFace")
                end
            elseif v.ShowType == 4 then--公会战 巅峰战 结束清 默认一天一轮回
                if RedPointManager.PlayerPrefsGetStr(v.Id.."PatFace") ~= "0" then
                    RedPointManager.PlayerPrefsDeleteStr(v.Id.."PatFace")
                end
            end
        end
    else
        if setPatFaceFinishTabs and #setPatFaceFinishTabs > 0 then
            for i = 1, #setPatFaceFinishTabs do
                if  setPatFaceFinishTabs[i].Type == 8 then--升级限时礼包特殊处理
                    if RedPointManager.PlayerPrefsGetStr(setPatFaceFinishTabs[i].Id..PlayerManager.level.."PatFace") == "0" then
                        RedPointManager.PlayerPrefsSetStr(setPatFaceFinishTabs[i].Id..PlayerManager.level.."PatFace","1")
                    end
                elseif setPatFaceFinishTabs[i].Type == 9 then
                    if RedPointManager.PlayerPrefsGetStr(setPatFaceFinishTabs[i].Id..(MonsterCampManager.monsterWave-1).."MonsterWavePatFace") == "0" then
                        RedPointManager.PlayerPrefsSetStr(setPatFaceFinishTabs[i].Id..(MonsterCampManager.monsterWave-1).."MonsterWavePatFace","1")
                    end
                elseif setPatFaceFinishTabs[i].Type == 10 then
                    if RedPointManager.PlayerPrefsGetStr(setPatFaceFinishTabs[i].Id..PlayerManager.level.."MainLevelPatFace") == "0" then
                        RedPointManager.PlayerPrefsSetStr(setPatFaceFinishTabs[i].Id..PlayerManager.level.."MainLevelPatFace","1")
                    end
                elseif setPatFaceFinishTabs[i].Type == 11 then
                    if RedPointManager.PlayerPrefsGetStr(setPatFaceFinishTabs[i].Id..PlayerManager.level.."TimeLimitSkin") == "0" then
                        RedPointManager.PlayerPrefsSetStr(setPatFaceFinishTabs[i].Id..PlayerManager.level.."TimeLimitSkin","1")
                    end
                else
                    if setPatFaceFinishTabs[i].ShowType ~= 2 then--触发就拍不用赋值
                        if RedPointManager.PlayerPrefsGetStr(setPatFaceFinishTabs[i].Id.."PatFace") == "0" then
                            RedPointManager.PlayerPrefsSetStr(setPatFaceFinishTabs[i].Id.."PatFace","1")
                        end
                    end
                end
            end
        end
    end
end

local patFaceAllData = {}
function this.GetFrontPatFaceAllDataTabs()
    if this.isLogin then return end
    patFaceAllData = {}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.LoginPosterConfig)) do
        this.PatFaceSpecialMonitorOpenRules(v,patFaceAllData,1)
    end
    if patFaceAllData then
        table.sort(patFaceAllData, function(a,b) return a.Order < b.Order end)
    end
    return patFaceAllData
end

--检测所有拍脸
function this.GetPatFaceAllDataTabs()
    local curAllDatas = {}
    local backData = this.GetBackPatFaceDaqta()
    local FrontData = this.GetFrontPatFaceAllDataTabs()
    if backData and #backData > 0 then
        for i = 1, #backData do
            table.insert(curAllDatas,backData[i])
        end
    end
    if FrontData and #FrontData > 0 then
        for i = 1, #FrontData do
            table.insert(curAllDatas,FrontData[i])
        end
    end
    return curAllDatas
end

function this.PatFaceSpecialMonitorOpenRules(v,patFaceAllData,type,starUpGiftNum)
    --1等级 2关卡 3特劝等级 4功能开启时 5活动开启时 6公会战状态 7条件触发(事件)
    if v.OpenRules[1] == 1 then
        if PlayerManager.level >= v.OpenRules[2] and PlayerManager.level <= v.CloseRules[2] then
            this.PatFaceSpecialMonitor(v,patFaceAllData,type,starUpGiftNum)
        end
    elseif v.OpenRules[1] == 2 then
        local isPass1 = FightPointPassManager.IsFightPointPass(v.OpenRules[2])
        local isPass2 = FightPointPassManager.IsFightPointPass(v.CloseRules[2])
        if isPass1 and  isPass2 == false then
            this.PatFaceSpecialMonitor(v,patFaceAllData,type,starUpGiftNum)
        end
    elseif v.OpenRules[1] == 3 then
        local vipLv = VipManager.GetVipLevel()
        if vipLv >= v.OpenRules[2] and vipLv <= v.CloseRules[2] then
            this.PatFaceSpecialMonitor(v,patFaceAllData,type,starUpGiftNum)
        end
    elseif v.OpenRules[1] == 4 then
        local isOpen = ActTimeCtrlManager.SingleFuncState(v.OpenRules[2])
        if isOpen then
            this.PatFaceSpecialMonitor(v,patFaceAllData,type,starUpGiftNum)
        end
    elseif v.OpenRules[1] == 5 then
        --local activity = ConfigManager.GetConfigData(ConfigName.GlobalActivity,v.OpenRules[2])
        --if activity then
        --    local activityId = ActivityGiftManager.IsActivityTypeOpen(activity.Type)
        --    if activityId then
        --        this.PatFaceSpecialMonitor(v,patFaceAllData,type,starUpGiftNum)
        --    end
        --end
        local activityId = ActivityGiftManager.IsActivityTypeOpen(v.OpenRules[2])
        if activityId and activityId == 42 then
            this.PatFaceSpecialMonitor(v,patFaceAllData,type,starUpGiftNum)
        elseif activityId and activityId == v.Values then
            this.PatFaceSpecialMonitor(v,patFaceAllData,type,starUpGiftNum)
        end
    elseif v.OpenRules[1] == 6 then
        --公会
        this.PatFaceSpecialMonitor(v,patFaceAllData,type,starUpGiftNum)
    elseif v.OpenRules[1] == 7 then
        --巅峰战
        this.PatFaceSpecialMonitor(v,patFaceAllData,type,starUpGiftNum)
    end
end

function this.PatFaceSpecialMonitor(v, patFaceAllData, type, starUpGiftNum)
    if v.Type == 1 then--十连抽
        if RedPointManager.PlayerPrefsGetStr(v.Id.."PatFace") == "0" and RecruitManager.isTenRecruit == 0 then
            table.insert(patFaceAllData,v)
        end
    elseif v.Type == 2 then
        local conFigData = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, v.ShopId)
        if conFigData == nil then return end
        local shopItemData = OperatingManager.GetGiftGoodsInfo(conFigData.Type,v.ShopId)
        if RedPointManager.PlayerPrefsGetStr(v.Id.."PatFace") == "0" and shopItemData and shopItemData.buyTimes <= 0 then
            table.insert(patFaceAllData,v)
        end
    elseif v.Type == 3 then--公会
        local curGuildStage = GuildFightManager.GetCurFightStage()
        if PlayerManager.familyId ~= 0 then
            if v.OpenRules[2] == curGuildStage then---2 then
                if RedPointManager.PlayerPrefsGetStr(v.Id.."PatFace") == "0" then
                    table.insert(patFaceAllData,v)
                end
            end
        end
    elseif v.Type == 5 then
        if starUpGiftNum then
            if starUpGiftNum == v.Star then
                local pat = false
                local configData = ConfigManager.GetAllConfigsDataByKey(ConfigName.RechargeCommodityConfig,"ShowType",8)
                for i = 1, #configData do
                    local id = configData[i].Id
                    local giftInfo = OperatingManager.GetGiftGoodsInfo(5,id)
                    if giftInfo and giftInfo.dynamicBuyTimes == 1 then
                        pat = true
                    end
                end
                if pat and RedPointManager.PlayerPrefsGetStr(v.Id.."PatFace") == "0" then--商品未开启才会激活拍脸
                    table.insert(patFaceAllData,v)
                end
            end
        end
    elseif v.Type == 6 then--巅峰战
        local curState = ArenaTopMatchManager.GetBaseData().battleState
        local battleStage = ArenaTopMatchManager.GetBaseData().battleStage
        -- if (curState and curState >= v.OpenRules[2] and curState <= v.CloseRules[2]) and (battleStage and battleStage >= v.Values) then--v.Values 2 > 1
            if RedPointManager.PlayerPrefsGetStr(v.Id.."PatFace") == "0" then
                table.insert(patFaceAllData,v)
            end
        -- end
    elseif v.Type == 7 then
        if FindFairyManager.GetActivityTime() > 0 then
            if RedPointManager.PlayerPrefsGetStr(v.Id.."PatFace") == "0" then
                table.insert(patFaceAllData,v)
            end
        end
    elseif v.Type == 8 then
        local specialConfig = ConfigManager.GetConfigData(ConfigName.SpecialConfig,51).Value
        local t = string.split(specialConfig,"#")
        local q = false
        for i = 0, 19 do
            local level = tonumber(t[1])+i*tonumber(t[2])
            if PlayerManager.level == level then
                q = true
            end
        end
        if q then
            if RedPointManager.PlayerPrefsGetStr(v.Id..PlayerManager.level.."PatFace") == "0" then
                table.insert(patFaceAllData,v)
            end
        end
    elseif v.Type == 9 then
        local specialConfig = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.SpecialConfig,92).Value)
        local str = string.split(specialConfig,"|")
        local nums = string.split(str[1],"#")
        local canGet = false
        local value = MonsterCampManager.monsterWave-1
        if value == tonumber(nums[1]) or value == tonumber(nums[2]) or value == tonumber(nums[3]) then
            canGet = true
        else
            if value > tonumber(nums[3]) and (value - tonumber(nums[3])) % tonumber(str[2]) == 0 then
                canGet = true
            end
        end
        if canGet then
            if RedPointManager.PlayerPrefsGetStr(v.Id..(MonsterCampManager.monsterWave-1).."MonsterWavePatFace") == "0" then
                table.insert(patFaceAllData,v)
            end
        end
    elseif v.Type == 10 then
        local specialConfig = ConfigManager.GetConfigData(ConfigName.SpecialConfig,93).Value
        local num = tonumber(specialConfig)
        local canGet = false
        local value = fightLevelConfig[FightPointPassManager.lastPassFightId].SortId
        if value%num == 0 then
            canGet = true
        end
        if canGet then
            local key = (v.Id or "") .. (PlayerManager.level or "") .. "MainLevelPatFace"

            if RedPointManager.PlayerPrefsGetStr(key) == "0" then
                table.insert(patFaceAllData,v)
            end
        end
    elseif v.Type == 11 then
        local specialConfig = ConfigManager.GetConfigData(ConfigName.SpecialConfig,106).Value
        local num = tonumber(specialConfig)
        local canGet = false
        if PlayerManager.level == num then
            canGet =true
        end
        if canGet then
            if RedPointManager.PlayerPrefsGetStr(v.Id..PlayerManager.level.."TimeLimitSkin") == "0" then
                table.insert(patFaceAllData,v)
            end
        end
    elseif v.Type == 12 then
        local ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SurpriseBox)
        if ActData and PlayerPrefs.GetInt(PlayerManager.uid.."SurpriseBoxPatFaceDay"..ActData.value) == 0 then
            table.insert(patFaceAllData,v)
        end
    elseif v.Type == 15 then
        local ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.TeHuiShenZhuang)
        if ActData and PlayerPrefs.GetInt(PlayerManager.uid.."TeHuiShenZhuang"..ActData.activityId) == 0 then
            table.insert(patFaceAllData,v)
        end
    else
        if RedPointManager.PlayerPrefsGetStr(v.Id.."PatFace") == "0" then
            table.insert(patFaceAllData,v)
        end
    end
end

function this.ShowBuyLaterDrop(msg)
    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
end

--秒转换成文字对应时间
function this.GetTimeStrBySeconds(_seconds)
    return os.date("%Y.%m.%d", _seconds)
end

this.timer = Timer.New()
--刷新倒计时显示
function this.RemainTimeDown(go, txt, timeDown, str)
    if timeDown > 0 then
        if go then
            go:SetActive(true)
        end
        if txt ~= nil and not IsNull(txt) then
            if str then
                txt.text = str .. TimeToDHMS(timeDown)
            else
                txt.text = GetLanguageStrById(10028) .. TimeToDHMS(timeDown)
            end
        end
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            if txt ~= nil and not IsNull(txt) then
                if str then
                    txt.text = str .. TimeToDHMS(timeDown)
                else
                    txt.text = GetLanguageStrById(10028) .. TimeToDHMS(timeDown)
                end
            end
            if timeDown < 0 then
                if go then
                    go:SetActive(false)
                end
                this.timer:Stop()
                this.timer = nil
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        if go then
            go:SetActive(false)
        end
    end
end
--刷新倒计时限时活动界面
function this.RemainTimeDown2(go, txt, timeDown, str)
    if timeDown > 0 then
        if go then
            go:SetActive(true)
        end
        if txt then
            if str then
                txt.text = str..TimeToDHMS(timeDown)
            else
                txt.text =  GetLanguageStrById(10028) .. TimeToDHMS(timeDown)
            end
        end
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            if txt ~=nil then
                if str and txt ~= nil then
                    txt.text = str..TimeToDHMS(timeDown)
                else
                    txt.text = GetLanguageStrById(10028) .. TimeToDHMS(timeDown)
                end
            end
            if timeDown < 0 then
                if go then
                    go:SetActive(false)
                end
                this.timer:Stop()
                this.timer = nil
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        if go then
            go:SetActive(false)
        end
    end
end
function this.TimeStampToDateString2(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format(GetLanguageStrById(50351),day, hour, minute, sec)
end
function this.TimeStampToDateString(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format(GetLanguageStrById(10585),day, hour, minute, sec)
end

function this.GetGuildFightTime()
    local guildFightData = GuildFightManager.GetGuildFightData()
    if guildFightData then
        local startTime = guildFightData.startTime
        local curTime = GetTimeStamp()
        return (curTime - startTime) <= 3 * 60
    else
        return false
    end
end
--事件触发拍脸 (如五星成长礼)
function this.OnAddPatFaceData(faceConFigType, starUpGiftNum)
    if faceConFigType == FacePanelType.GrowGift or faceConFigType == FacePanelType.UpgradePac  or faceConFigType == FacePanelType.MonsterWave  or faceConFigType == FacePanelType.MainLevel or faceConFigType == FacePanelType.TimeLimitSkin then
        return
    end
    if this.isLogin then return end--上来就弹新关卡界面 所以不弹

    if MapManager.Mapping or UIManager.IsOpen(UIName.BattlePanel) then return end--在关卡里 副本里不弹
    patFaceAllData = {}
    local allTypeFaceConFig = ConfigManager.GetAllConfigsDataByKey(ConfigName.LoginPosterConfig,"Type",faceConFigType)
    for i = 1, #allTypeFaceConFig do
        this.PatFaceSpecialMonitorOpenRules(allTypeFaceConFig[i], patFaceAllData, 2,  starUpGiftNum)
    end
    if patFaceAllData and not GuideManager.IsFunctionGuideExist() then
        this.OpenPatFacePanel(patFaceAllData)
    end
end

this.patFaceCallList = Stack.New()
function this.OpenPatFacePanel(_patFaceAllData)
    if _patFaceAllData and #_patFaceAllData > 0 then
        this.patFaceCallList:Clear()
        this.patFaceCallList:Push(function()
            this.DeleBackPatFaceDaqta()
            Game.GlobalEvent:DispatchEvent(GameEvent.PatFace.PatFaceSendFinish)
            -- AdventureManager.GetIsMaxTime()
        end)
        for i = #_patFaceAllData, 1, -1 do
            this.patFaceCallList:Push(function()
                PatFaceManager.SetisFirstLogVal(1, { _patFaceAllData[i] })
                UIManager.OpenPanel(UIName.PatFacePanel, _patFaceAllData[i], function()
                    if this.time2 then
                        this.time2:Stop()
                        this.time2 = nil
                    end
                    this.time2 = Timer.New(function()
                        if this.patFaceCallList.count > 0 then
                            this.patFaceCallList:Pop()()
                        end
                        this.time2 = nil
                    end, 0.5)
                    this.time2:Start()
                end)
            end)
        end
        this.patFaceCallList:Pop()()
    else
        Game.GlobalEvent:DispatchEvent(GameEvent.PatFace.PatFaceSendFinish)
    end
end

--后端礼包拍脸逻辑
this.backPatFaceAllData = {}
function this.SetPatFaceDaqta(PatFaceDatas)
    if PatFaceDatas and PatFaceDatas.id and #PatFaceDatas.id > 0 then
        for i = 1, #PatFaceDatas.id do
            local curRechargeCommodityConfig = ConfigManager.TryGetConfigData(ConfigName.RechargeCommodityConfig,PatFaceDatas.id[i])
            if curRechargeCommodityConfig and curRechargeCommodityConfig.PosterUiId then
                local config = ConfigManager.GetConfigData(ConfigName.LoginPosterConfig,curRechargeCommodityConfig.PosterUiId)
                local isShow = true
                if config.Type == FacePanelType.Surprise then
                    if not PlayerPrefs.HasKey(PlayerManager.uid.."Surprise") then
                        PlayerPrefs.SetString(PlayerManager.uid.."Surprise","0#0")
                    end
                    local str = PlayerPrefs.GetString(PlayerManager.uid.."Surprise")
                    str = string.split(str,"#")
                    local curTimeStemp = math.floor(GetTimeStamp() / (24 * 3600))
                    local times = tonumber(str[2])
                    if tonumber(str[1]) ~= curTimeStemp then
                        times = 0
                        PlayerPrefs.SetString(PlayerManager.uid.."Surprise",curTimeStemp.."#"..times)
                    end
                    if times >= 2 then
                        isShow = false
                    else
                        for k,v in ipairs(this.backPatFaceAllData) do
                            if config.Type == v.Type then
                                isShow = false
                                break
                            end
                        end
                        if isShow then
                            times = times + 1
                            PlayerPrefs.SetString(PlayerManager.uid.."Surprise",curTimeStemp.."#"..times)
                        end
                    end
                end
                if isShow then
                    table.insert(this.backPatFaceAllData,config)
                end
            end
        end
    end

    if this.backPatFaceAllData and this.GetcurCanPatFace() then
        this.OpenPatFacePanel(this.backPatFaceAllData)
    else
        if not UIManager.IsOpen(UIName.PatFacePanel) then
            this.PatFaceback(1)
        end
    end
end

function this.OpenPatFaceLS()
    this.OpenPatFacePanel(this.backPatFaceAllData)
end

function this.GetBackPatFaceDaqta()
    return this.backPatFaceAllData
end

function this.DeleBackPatFaceDaqta()
    this.backPatFaceAllData = {}
end

function this.GetcurCanPatFace()
    if this.isLogin then return false end--登录界面不拍
    if MapManager.Mapping or UIManager.IsOpen(UIName.BattlePanel) or UIManager.IsOpen(UIName.SurpriseBoxPanel) or UIManager.IsOpen(UIName.RoleInfoPanel) or UIManager.IsOpen(UIName.HandBookHeroInfoPanel) or UIManager.IsOpen(UIName.ActivityMainPanel) then return false end--在关卡里 副本里不拍
    if GuideManager.IsFunctionGuideExist() or GuideManager.IsInMainGuide() then return false end--引导不拍
    if UIManager.IsOpen(UIName.SingleRecruitPanel) or UIManager.IsOpen(UIName.TenRecruitPanel) --[[or UIManager.IsOpen(UIName.RecruitPanel)]] or UIManager.IsOpen(UIName.DynamicActivityPanel) or RecruitManager.isDraw then return false end--抽卡界面不拍
    if UIManager.IsOpen(UIName.PatFacePanel) then return false end--正在拍脸
    return true
end

function this.RefreshPatface()
     if this.GetcurCanPatFace() then
        this.OpenPatFacePanel(this.GetPatFaceAllDataTabs())
     end
end

function this.PatFaceback(val)
    PlayerPrefs.SetInt("PatFace"..PlayerManager.uid ,val)
end

--获得红点信息
function this.GetPatFaceback()
    return PlayerPrefs.GetInt("PatFace"..PlayerManager.uid)
end
return this