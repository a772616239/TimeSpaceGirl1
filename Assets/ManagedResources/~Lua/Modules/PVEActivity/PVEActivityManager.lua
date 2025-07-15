PVEActivityManager = {}
local this = PVEActivityManager
local ActivityChapterConfig = ConfigManager.GetAllConfigsData(ConfigName.ActivityChapterConfig)
local ActivityLevelConfig = ConfigManager.GetConfig(ConfigName.ActivityLevelConfig)
local ActivityGroups = ConfigManager.GetAllConfigsData(ConfigName.ActivityGroups)
local activityRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)

--数据结构
--[[
    chapterInfoList = { 
        [1] = {
            id = 0, -- 章节ID
            state = 1, -- 开启1 通过2
            leveInofList = { -- 解锁关卡
                [1] = {
                    id = 1, -- 关卡ID
                    state = 1, -- 开启1 通过2
                    challengeCount = 1 -- 已挑战次数
                    starList = 1 -- 星数
                }
            },
        }
    }
]]

--通过章节ID查找ActivityLevelConfig表的ChapterID
function this.Initialize()
    this.chapterInfoList = {}--章节数据
    this.selectId = 0
    this.drop = {}
end

--获取开启的多个PVE活动
function this.ActivityList()
    local actList = {}
    local id = {
        30000,--不统计星数的PVE活动
        40000,--统计星数的PVE活动
    }
    for i = 1, #id do
        -- local idList = ConfigManager.GetAllConfigsDataByKey(ConfigName.GlobalActivity, "Type", id[i])
        -- for j = 1, #idList do
        --     for _, v in ipairs(ActivityGiftManager.mission) do
        --         if ActivityGiftManager.mission[idList[j].Id] then
        --             table.insert(actList, ActivityGiftManager.mission[idList[j].Id])
        --         end
        --     end
        -- end
        local datas = ActivityGiftManager.GetActivityTypeInfoList(id[i])
        for j = 1, #datas do
            table.insert(actList, datas[j])
        end
    end

    return actList
end

--活动Tab
function this.ActivityTabData()
    local activityTab = {}
    local allAct = this.ActivityList()
    for i = 1, #allAct do
        local config = ConfigManager.GetConfigDataByKey(ConfigName.ActivityGroups, "ActId", allAct[i].activityId)
        table.insert(activityTab, {
            default = GetPictureFont(config.Icon[1]),
            select = GetPictureFont(config.Icon[2]),
            activityId = allAct[i].activityId,
        })
    end
    return activityTab
end

--获取活动结束时间
function this.GetTime(activityId)
    local allAct = this.ActivityList()
    for i = 1, #allAct do
        if allAct[i].activityId == activityId then
            return allAct[i].endTime
        end
    end
    return 0
end

--获取数据
function this.InfoList(func)
    NetManager.ActivityChapterListRequest(function (msg)
        this.chapterInfoList = msg.chapterInfoList
        if func then
            func()
        end
    end)
end

--挑战关卡 1.挑战 2.扫荡
function this.ChallengeCheckpoint(id, type, func)
    if BattleManager.IsInBackBattle() then
        PopupTipPanel.ShowTip(GetLanguageStrById(50329))
        return
    end
    this.selectId = id
    if type == 1 then
        FormationManager.curFormationIndex = FormationTypeDef.FORMATION_NORMAL
        NetManager.FightStartRequest(BATTLE_TYPE.PVEActivity, id, function(msg)
            UIManager.OpenPanel(UIName.BattleStartPopup, function ()
                local fightData = BattleManager.GetBattleServerData(msg, nil)
                UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.PVEActivity, func)
            end)
        end)
    elseif type == 2 then
        NetManager.HeroTrialSweepRequest(id, function (msg)
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
            end)
            if func then
                func(msg)
            end
        end)
    end
end

--获取章节
function this.GetChapterData(activityId)
    local config = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityChapterConfig, "ActivityId", activityId)
    return config
end

--获取服务器返回的关卡列表
function this.GetUnlockedCheckpointList(id)
    for index, value in ipairs(this.chapterInfoList) do
        if value.id == id then
            return value.leveInofList
        end
    end
    return nil
end

--获取章节对应关卡数据
function this.GetCheckpointList(chapterID)
    local checkpointList = this.GetUnlockedCheckpointList(chapterID)
    local configList = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityLevelConfig, "ChapterID", chapterID)
    local allData = {}
    for _, configData in ipairs(configList) do
        local state = 0 --0 未解锁 1 开启 2 通过
        local challengeCount = 0
        local starList = {}
        local cost = {}
        local livePos = {}
        if checkpointList then
            for i = 1, #checkpointList do
                if checkpointList[i].id == configData.Id then--若有服务器返回来的ID则表示已解锁
                    state = checkpointList[i].state
                    challengeCount = checkpointList[i].challengeCount
                    starList = checkpointList[i].starList
                    cost = configData.Cost
                    livePos = configData.positionShow
                end
            end
        end
        table.insert(allData, {
            config = configData,
            state = state,
            challengeCount = challengeCount,
            starList = starList,
            cost = cost,
            livePos = livePos,
        })
    end
    return allData
end

--检测章节状态
function this.CheckChapterIsUnlock(id)
    for i = 1, #this.chapterInfoList do
        if this.chapterInfoList[i].id == id then
            return this.chapterInfoList[i].state
        end
    end
    return 0
end

--检测关卡状态
function this.CheckCheckpointIsUnlock(id)
    for i = 1, #this.chapterInfoList do
        for j = 1, #this.chapterInfoList[i].leveInofList do
            if this.chapterInfoList[i].leveInofList[j].id == id then
                return this.chapterInfoList[i].leveInofList[j].state
            end
        end
    end
    return 0
end

--获取初始显示章节ID
function this.GetShowChapterId(activityId)
    local config = this.GetChapterData(activityId)
    for i = 1, #this.chapterInfoList do
        if this.chapterInfoList[i].id == config[1].Id then--默认显示第一章第一关
            return this.chapterInfoList[i].id
        end
    end
end

--章节数据推送
function this.ActivityChapterIndication(msg)
    local state = true
    for i = 1, #this.chapterInfoList do
        if this.chapterInfoList[i].id == msg.activityChapterInfo.id then
            this.chapterInfoList[i] = msg.activityChapterInfo
            state = false
        end
    end
    if state then
        table.insert(this.chapterInfoList, msg.activityChapterInfo)
    end
end

--获取当前章节解锁的最新章节无则返回第一个
function this.GetUnlockCheckpointFormChapter(chapterId)
    for i = 1, #this.chapterInfoList do
        if this.chapterInfoList[i].id == chapterId then
            for j = 1, #this.chapterInfoList[i].leveInofList do
                if this.chapterInfoList[i].leveInofList[j].state == 1 then
                    return this.chapterInfoList[i].leveInofList[j].id
                end
            end
            return this.chapterInfoList[i].leveInofList[#this.chapterInfoList[i].leveInofList].id
        end
    end
end

--刷新倒计时
function this.RemainTimeDown(go, txt, timeDown, str)
    if timeDown > 0 then
        if go then
            go:SetActive(true)
        end
        if txt then
            if str then
                txt.text = str..TimeToDHMS(timeDown)
            else
                txt.text = GetLanguageStrById(50330) .. TimeToDHMS(timeDown)
            end
        end
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            if txt then
                if str then
                    txt.text = str..TimeToDHMS(timeDown)
                else
                    txt.text = GetLanguageStrById(50330) .. TimeToDHMS(timeDown)
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

function this.StopTimeDown()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--PVE星数奖励红点
function this.SetPveStarRewardRedpoint(id)
    local activityList = ActivityGiftManager.GetActivityTypeInfoList(ActivityTypeDef.PVEStarReward)
    local data
    for index, value in ipairs(activityList) do
        if value.activityId == id then
            data = value.mission
        end
    end
    if data then
        for index, value in ipairs(data) do
            local config = activityRewardConfig[value.missionId]
            if value.state == 0 and value.progress >= config.Values[2][1] then
                return true
            end
        end
    end
    return false
end

return this