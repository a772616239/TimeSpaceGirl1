----- 日常任务弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local fun
--item容器
local itemList = {}
local curAllData = {}
local achievementConfig = ConfigManager.GetConfig(ConfigName.AchievementConfig)
local itemGrid = {}
local allAvailableAchievement = {}

function this:InitComponent(gameObject)
    this.rewardPre = Util.GetGameObject(gameObject, "rewardPre")
    local v = Util.GetGameObject(gameObject, "rect"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "rect").transform,
            this.rewardPre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.NoviceItemList = {}--存储itemview 重复利用

    this.receiveAllBtn = Util.GetGameObject(gameObject, "receiveAllBtn")
end

function this:BindEvent()
    Util.AddClick(this.receiveAllBtn, function()
        NetManager.TakeMissionAllRewardRequest(TaskTypeDef.Achievement,function (msg)
            if msg.drop == nil then return end
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                for i = 1,#msg.missionIds do
                    TaskManager.SetTypeTaskState(TaskTypeDef.Achievement, msg.missionIds[i], 2)
                end
                this.OnShowPanelData()
            end)
        end)
    end)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Task.Achievement, this.OnShowPanelData)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Task.Achievement, this.OnShowPanelData)
end

function this:OnShow(_parent,...)
    parent = _parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local args = {...}
    fun = args[1]
    this.OnShowPanelData()
end

function this:OnSortingOrderChange(sortingOrder)
    for i, v in pairs(this.NoviceItemList) do
        for j = 1, #this.NoviceItemList[i] do
            if this.NoviceItemList[i][j] and this.NoviceItemList[i][j].gameObject then
                this.NoviceItemList[i][j]:SetEffectLayer(sortingOrder)
            end
        end
    end
end

function this.OnShowPanelData()
    local curAllData = TaskManager.GetCurShowAllAchievementData(TaskTypeDef.Achievement)
    local AllData = {}
    -- local allAchievement = {}
    allAvailableAchievement = {}
    for i, v in pairs(curAllData) do
        table.insert(AllData,v)
    end
    this.RewardTabsSort(AllData)
    this.ScrollView:SetData(AllData, function (index, go)
        this.SingleDataShow(go, AllData[index])
        -- allAchievement[index] = go
    end)

    Util.SetGray(this.receiveAllBtn,#allAvailableAchievement == 0)
    this.receiveAllBtn:GetComponent("Button").enabled = (#allAvailableAchievement ~= 0)

    -- DelayCreation(allAchievement)
end

function this.SingleDataShow(go,rewardData)
    -- go:SetActive(true)
    local sConFigData = achievementConfig[rewardData.missionId]
    local titleText = Util.GetGameObject(go, "titleImage/titleText"):GetComponent("Text")
    titleText.text = GetLanguageStrById(sConFigData.ContentsShow)
    local itemGroup = Util.GetGameObject(go, "content")

    --滚动条复用重设itemview
    if this.NoviceItemList[go] then
        for i = 1, 4 do
            this.NoviceItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #sConFigData.Reward do
            if this.NoviceItemList[go][i] then
                this.NoviceItemList[go][i]:OnOpen(false, {sConFigData.Reward[i][1],sConFigData.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                this.NoviceItemList[go][i].gameObject:SetActive(true)
            end
        end
    else
        this.NoviceItemList[go] = {}
        for i = 1, 4 do
            this.NoviceItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
            this.NoviceItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #sConFigData.Reward do
            this.NoviceItemList[go][i]:OnOpen(false, {sConFigData.Reward[i][1],sConFigData.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
            this.NoviceItemList[go][i].gameObject:SetActive(true)
        end
    end
    local receiveBtn = Util.GetGameObject(go.gameObject, "receiveBtn")
    local goBtn = Util.GetGameObject(go.gameObject, "goBtn")
    local Received = Util.GetGameObject(go.gameObject, "Received")
    local getRewardProgressSlider = Util.GetGameObject(go.gameObject, "getRewardProgress")
    local getRewardProgress = Util.GetGameObject(go.gameObject, "getRewardProgress/Txt")
    local state = rewardData.state
    local value = sConFigData.Values[2][1]
    receiveBtn:SetActive(state == 1)
    goBtn:SetActive(state == 0)
    Received:SetActive(state == 2)

    if state == 2 then
        getRewardProgressSlider:SetActive(false)
        -- TaskManager.SetTypeTaskState(TaskTypeDef.Achievement, rewardData.missionId, 2)
        -- go:SetActive(false)
    else
        local str = PrintWanNum4(math.abs(rewardData.progress)).."/"..PrintWanNum4(math.abs(value))
        local value = math.abs(rewardData.progress)/math.abs(value)
        if sConFigData.Type == 37 then
            if state == 0 then
                value = 0
                str = "0/"..1
            elseif state == 1 then
                value = 1
                str = "1/"..1
            end
        end
        getRewardProgressSlider:SetActive(true)
        getRewardProgressSlider:GetComponent("Slider").value = value
        getRewardProgress:GetComponent("Text").text = str
    end

    Util.AddOnceClick(goBtn, function()
        if sConFigData.Jump then
            JumpManager.GoJump(sConFigData.Jump[1])
        end
    end)
    Util.AddOnceClick(receiveBtn, function()
        NetManager.TakeMissionRewardRequest(TaskTypeDef.Achievement,rewardData.missionId,  function(msg)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                TaskManager.SetTypeTaskState(TaskTypeDef.Achievement, rewardData.missionId, 2)
                this.OnShowPanelData()
            end)
        end)
    end)

    if state == 1 then
        if this.IsAvailableAchievement(rewardData.missionId) then
            table.insert(allAvailableAchievement,rewardData.missionId)
        end
    end
end

--判断是否含有这个已完成的成就
function this.IsAvailableAchievement(missionId)
    for i = 1,#allAvailableAchievement do
        if allAvailableAchievement[i] == missionId then
            return false
        end
    end
    return true
end

local sortTable = {
    [1] = 2,
    [2] = 0,
    [0] = 1,
}
function this.RewardTabsSort(missions)
    table.sort(missions,function(a,b)
        if a.state == b.state then
            return a.missionId < b.missionId
        else
            return sortTable[a.state] > sortTable[b.state]
        end
    end)
end
function this:OnClose()

end
function this:OnDestroy()
end

return this