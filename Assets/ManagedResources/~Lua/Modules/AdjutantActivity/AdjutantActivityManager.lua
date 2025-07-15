AdjutantActivityManager = {}
local this = AdjutantActivityManager

function this.Initialize()
    --当前层数
    this.currentlayer = 1
    --购买次数
    this.buyNum = 0
end

function this.GetLayer()
    return this.currentlayer
end

function this.SetLayer(layer)
    if layer == 0 then
        layer = 1
    end
    this.currentlayer = layer
end

function this.GetBuyNum()
    return this.buyNum
end

function  this.setBuyNum(num)
    this.buyNum = num
end

--判断先驱活动是否开启
function this.IsAdjutnatActivityOpen()
    local isOpen = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdjutantCurrent) or
        ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdjutantChallenge) or
        ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdjutantRecruit) or
        ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdjutantGift)
    return isOpen
end

function this.InitAdjutantData()
    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdjutantChallenge)
    if (not id) or id < 1 then
        return nil
    end
    this.allData = {}
    local allListData = ConfigManager.GetAllConfigsDataByKey(ConfigName.ThemeActivityTaskConfig, "ActivityId", id)
    local allMissionData = TaskManager.GetTypeTaskList(TaskTypeDef.AdjutantChallengeTask)
    for i = 1,#allListData do
        for j = 1,#allMissionData do
            if allListData[i].Id == allMissionData[j].missionId  then
                local data = {}
                data.id = allMissionData[j].missionId
                data.progress = allMissionData[j].progress 
                local strs = string.split(GetLanguageStrById(allListData[i].Show),"#")
                data.title = GetLanguageStrById(allListData[i].Show)--strs[1]
                data.content = strs[2]
                data.value = allListData[i].TaskValue[2][1]
                data.state = allMissionData[j].state
                data.type = allListData[i].Type
                data.reward = {allListData[i].Integral[1][1],allListData[i].Integral[1][2]} 
                data.jump = allListData[i].Jump[1]
                table.insert(this.allData,data)
            end
        end
    end
    return this.allData
end

--先驱主题活动挑战任务红点
function this.RefreshRedPoint()
    local data = this.InitAdjutantData()
    if data then
        for i = 1, #data do
            if data[i].state == 1 then
                return true
            end
        end
    end
    return false
end

return this