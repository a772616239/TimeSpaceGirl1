----- 日常任务弹窗 -----
local this = {}
--传入父脚本模块
-- local parent
--传入特效层级
local sortingOrder = 0
-- local fun
local SingleDailyMissionState = {
    NoFinish = 0,   --未完成
    Finish = 1,     --完成未领取
    GetFinish = 2,  --已领取
}
local SortDailyMissionState = {
    [1] = 1,
    [0] = 2,
    [2] = 3
}
-- local allAvailableTaskId = {}
local dailyTasksConfig = {}         --静态数据
local curDailyMissionData = {}      --每日任务条目
local curDailyMissionBoxData = {}   --宝箱
local boxList = {}                  --宝箱按钮
-- local allMissionDailyPres = {}
-- local allMissionDailyItemPres = {}
local allMissionDailyBoxItemPres = {}
-- local myGo
local allAvailableTask = {}

function this:InitComponent(gameObject)
    -- myGo = gameObject
    this.rectMask = Util.GetGameObject(gameObject,"rect"):GetComponent("Image")
    this.rewardPre = Util.GetGameObject(gameObject, "rewardPre")
    local v = Util.GetGameObject(gameObject, "rect"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "rect").transform,
            this.rewardPre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.NoviceItemList = {}--存储itemview 重复利用

    this.reward = Util.GetGameObject(gameObject, "rewardBg/reward")
    this.Slider = Util.GetGameObject(this.reward, "progress/Fill Area/Slider"):GetComponent("Slider")

    this.rewardPanel = Util.GetGameObject(this.reward, "RewardPanel")
    this.RewardPanelGetInfo = Util.GetGameObject(this.rewardPanel, "getInfo")
    this.boxItemGrid = Util.GetGameObject(this.rewardPanel, "ViewRect/grid").transform

    for i = 1, 4 do
        boxList[i] = Util.GetGameObject(this.reward, "btnList/BoxBtn"..i)
        allMissionDailyBoxItemPres[i] = SubUIManager.Open(SubUIConfig.ItemView, this.boxItemGrid)
    end
    this.rewardMaskBtn = Util.GetGameObject(this.rewardPanel, "rewardMaskBtn")
    this.activityText = Util.GetGameObject(this.reward, "activity/Text"):GetComponent("Text")

    this.receiveAllBtn = Util.GetGameObject(gameObject, "receiveAllBtn")
end

function this:BindEvent()
    Util.AddClick(this.rewardMaskBtn, function()
        this.rewardMaskBtn:SetActive(false)
        this.rewardPanel:SetActive(false)
    end)

    Util.AddClick(this.receiveAllBtn, function()
        NetManager.TakeMissionAllRewardRequest(TaskTypeDef.DayTask,function (msg)
            if msg.drop == nil then return end
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                for i = 1,#msg.missionIds do
                    TaskManager.SetTypeTaskState(TaskTypeDef.DayTask, msg.missionIds[i], SingleDailyMissionState.GetFinish)
                    -- 检测红点状态
                    CheckRedPointStatus(RedPointType.DailyTask)
                    CheckRedPointStatus(RedPointType.SecretTer)
                end
                this.OnShowData()
            end)
        end)
    end)
end
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.OnShowData)
    Game.GlobalEvent:AddEvent(GameEvent.CloseUI.OnClose, this.ClosePanel)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged,this.OnShowData)
    Game.GlobalEvent:RemoveEvent(GameEvent.CloseUI.OnClose, this.ClosePanel)
end

function this:OnShow(_parent,...)
    -- parent = _parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local args = {...}
    -- fun = args[1]
    this.rectMask.enabled = true
    this.OnShowData()
end

function this:OnSortingOrderChange(sortingOrder)
    for i, v in pairs(this.NoviceItemList) do
        for j = 1, #this.NoviceItemList[i] do
            if this.NoviceItemList[i][j] and this.NoviceItemList[i][j].gameObject then
                this.NoviceItemList[i][j]:SetEffectLayer(sortingOrder)
            end
        end
    end
    --特效层级重设
    for i = 1,#boxList do
        Util.AddParticleSortLayer(boxList[i], sortingOrder)
    end
end

function this.OnShowData()
    dailyTasksConfig = ConfigManager.GetConfig(ConfigName.DailyTasksConfig)
    curDailyMissionData = {}
    curDailyMissionBoxData = {}
    allAvailableTask = {}
    for i, v in pairs(TaskManager.GetTypeTaskList(TaskTypeDef.DayTask)) do
        if v.missionId < 10000 then
            if dailyTasksConfig[v.missionId].OpenLevel  and ActTimeCtrlManager.SingleFuncState(dailyTasksConfig[v.missionId].OpenLevel) then
                table.insert(curDailyMissionData,v)
            end
        else
            if dailyTasksConfig[v.missionId].OpenLevel and ActTimeCtrlManager.SingleFuncState(dailyTasksConfig[v.missionId].OpenLevel) then
                table.insert(curDailyMissionBoxData,v)
            end
        end
    end
    table.sort(curDailyMissionData, function(a,b)
        if a.state == b.state then
            return a.missionId < b.missionId
        else
            return SortDailyMissionState[a.state] < SortDailyMissionState[b.state]
        end
    end)

    -- local allTask = {}
    this.ScrollView:SetData(curDailyMissionData, function (index, go)
        this.SingleMissionDatasDataShow(go,curDailyMissionData[index])
        -- allTask[index] = go
    end)
    this.SetDailyMissionBox(curDailyMissionBoxData)
    -- DelayCreation(allTask)

    --一键领取按钮状态
    Util.SetGray(this.receiveAllBtn,#allAvailableTask == 0)
    this.receiveAllBtn:GetComponent("Button").enabled = (#allAvailableTask ~= 0)
end

function this.SingleMissionDatasDataShow(_go,_missionData)
    local missionData = _missionData
    local missionConfigData = dailyTasksConfig[missionData.missionId]
    local titleText = Util.GetGameObject(_go, "titleImage/titleText"):GetComponent("Text")
    titleText.text = string.format(GetLanguageStrById(missionConfigData.Desc),missionConfigData.Values[2][1])

    local itemGroup = Util.GetGameObject(_go, "content")
    --滚动条复用重设itemview
    if this.NoviceItemList[_go] then
        for i = 1, 4 do
            this.NoviceItemList[_go][i].gameObject:SetActive(false)
        end
        for i = 1, #missionConfigData.Reward do
            if this.NoviceItemList[_go][i] then
                this.NoviceItemList[_go][i]:OnOpen(false, {missionConfigData.Reward[i][1],missionConfigData.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                this.NoviceItemList[_go][i].gameObject:SetActive(true)
            end
        end
    else
        this.NoviceItemList[_go] = {}
        for i = 1, 4 do
            this.NoviceItemList[_go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
            this.NoviceItemList[_go][i].gameObject:SetActive(false)
        end
        for i = 1, #missionConfigData.Reward do
            this.NoviceItemList[_go][i]:OnOpen(false, {missionConfigData.Reward[i][1],missionConfigData.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
            this.NoviceItemList[_go][i].gameObject:SetActive(true)
        end
    end

    local receiveBtn = Util.GetGameObject(_go.gameObject, "receiveBtn") --领取
    local goBtn = Util.GetGameObject(_go.gameObject, "goBtn")           --前往
    local Received = Util.GetGameObject(_go.gameObject, "Received")     --已领取
    local getRewardProgressSlider = Util.GetGameObject(_go.gameObject, "getRewardProgress")
    local getRewardProgress = Util.GetGameObject(_go.gameObject, "getRewardProgress/Txt")
    local state = missionData.state--0:未完成 1：完成未领取 2：已达成（已领取）

    receiveBtn:SetActive(state == SingleDailyMissionState.Finish)
    goBtn:SetActive(state == SingleDailyMissionState.NoFinish)
    Received:SetActive(state == SingleDailyMissionState.GetFinish)

    if state == SingleDailyMissionState.GetFinish then
        getRewardProgressSlider:SetActive(false)
    else
        getRewardProgressSlider:SetActive(true)
        getRewardProgressSlider:GetComponent("Slider").value = missionData.progress/missionConfigData.Values[2][1]
        if missionConfigData.Values[2][1] >= 10000 then
            local num = missionConfigData.Values[2][1]/10000
            getRewardProgress:GetComponent("Text").text = missionData.progress.. "/" .. num .. GetLanguageStrById(10042)
        else
            getRewardProgress:GetComponent("Text").text = missionData.progress.. "/" .. missionConfigData.Values[2][1]
        end
    end

    Util.AddOnceClick(goBtn, function()
        if missionConfigData.Jump then
            JumpManager.GoJump(missionConfigData.Jump)
            this.rectMask.enabled = UIManager.IsTopShow(UIName.MissionDailyPanel)
        end
    end)
    Util.AddOnceClick(receiveBtn, function()
        NetManager.TakeMissionRewardRequest(TaskTypeDef.DayTask,missionData.missionId,function (msg)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                TaskManager.SetTypeTaskState(TaskTypeDef.DayTask, missionData.missionId, SingleDailyMissionState.GetFinish)
                this.OnShowData()
                -- 检测红点状态
                CheckRedPointStatus(RedPointType.DailyTask)
                CheckRedPointStatus(RedPointType.SecretTer)
            end)
        end)
    end)

    if state == SingleDailyMissionState.Finish then
        if this.IsAvailableTask(missionData.missionId) then
            table.insert(allAvailableTask,missionData.missionId)
        end
    end
end

--判断是否含有这个已完成的任务
function this.IsAvailableTask(missionId)
    for i = 1,#allAvailableTask do
        if allAvailableTask[i] == missionId then
            return false
        end
    end
    return true
end

--每日任务宝箱赋值
function this.SetDailyMissionBox(_missionDatas)
    for i = 1, math.max(#_missionDatas, #boxList) do
        local go = boxList[i]
        if not go then
            go = newObject(boxList[4])
            go.transform:SetParent(this.btnList.transform)
            go.name = "BoxBtn"..i
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            boxList[i] = go
        end
        go.gameObject:SetActive(false)
    end

    local curGetRewardNum = 0
    for i, v in pairs(curDailyMissionBoxData) do
        if v.progress > curGetRewardNum then
            curGetRewardNum = v.progress
        end
    end
    this.Slider.value = curGetRewardNum/dailyTasksConfig[_missionDatas[#_missionDatas].missionId].Values[2][1]
    this.activityText.text = curGetRewardNum
    for i, v in pairs(_missionDatas) do
        boxList[i]:SetActive(true)
        local missionConfigData = dailyTasksConfig[v.missionId]
        Util.GetGameObject(boxList[i], "num"):GetComponent("Text").text = missionConfigData.Values[2][1]
        Util.GetGameObject(boxList[i], "biaoxiang"):GetComponent("Image").enabled = (not (v.state == SingleDailyMissionState.Finish or  v.state == SingleDailyMissionState.GetFinish))
        Util.GetGameObject(boxList[i], "UI_Effect_BaoXiang_KaiQi"):SetActive(v.state == SingleDailyMissionState.GetFinish)
        Util.GetGameObject(boxList[i], "UI_Effect_BaoXiang_KaiQi/MeiKaiQi"):SetActive(false)
        Util.GetGameObject(boxList[i], "redPoint"):SetActive(v.state == SingleDailyMissionState.Finish)
        Util.GetGameObject(boxList[i], "UI_Effect_BaoXiang_KeKaiQi"):SetActive(v.state == SingleDailyMissionState.Finish)
        Util.GetGameObject(boxList[i], "getFinish"):SetActive(v.state == SingleDailyMissionState.GetFinish)

        if v.state == SingleDailyMissionState.Finish then
            if this.IsAvailableTask(v.missionId) then
                table.insert(allAvailableTask,v.missionId)
            end
        end

        Util.AddOnceClick(boxList[i], function()
            this.MissionBoxClick(boxList[i],v)
        end)
    end
end
function this.MissionBoxClick(btn,_singleData)
    if  _singleData.state == SingleDailyMissionState.NoFinish or _singleData.state == SingleDailyMissionState.GetFinish then
        local curConfig = dailyTasksConfig[_singleData.missionId]
        this.RewardPanelGetInfo:GetComponent("Text").text = GetLanguageStrById(11362)..curConfig.Values[2][1]..GetLanguageStrById(11363)

        local reward = dailyTasksConfig[_singleData.missionId]
        if reward then
            for i = 1, math.max(#allMissionDailyBoxItemPres, #reward.Reward) do
                local go = allMissionDailyBoxItemPres[i]
                if not go then
                    go = SubUIManager.Open(SubUIConfig.ItemView, this.boxItemGrid)
                    go.gameObject.name = "frame"..i
                    allMissionDailyBoxItemPres[i] = go
                end
                go.gameObject:SetActive(false)
            end
            for i = 1, #reward.Reward do
                allMissionDailyBoxItemPres[i].gameObject:SetActive(true)
                allMissionDailyBoxItemPres[i]:OnOpen(false,reward.Reward[i],0.55)
            end
        end

        this.rewardMaskBtn:SetActive(true)
        this.rewardPanel:SetActive(true)
    elseif _singleData.state == SingleDailyMissionState.Finish then
        Util.GetGameObject(btn, "UI_Effect_BaoXiang_KeKaiQi"):SetActive(false)
        Util.GetGameObject(btn, "UI_Effect_BaoXiang_KaiQi"):SetActive(true)
        Util.GetGameObject(btn, "UI_Effect_BaoXiang_KaiQi/MeiKaiQi"):SetActive(true)
        btn:GetComponent("Button").enabled = false
        this.timer = Timer.New(function()
            NetManager.TakeMissionRewardRequest(TaskTypeDef.DayTask,_singleData.missionId,function (msg)
                TaskManager.SetTypeTaskState(TaskTypeDef.DayTask, _singleData.missionId, SingleDailyMissionState.GetFinish)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1)
                this.OnShowData()
            end)
            this.timer:Stop()
            this.timer = nil
            btn:GetComponent("Button").enabled = true
        end, 1, 1, true)
        this.timer:Start()
    end
end

function this.GetCurIsOpen(LevelRegion)
    if LevelRegion[1] == 1 then--等级
        return PlayerManager.level >= LevelRegion[2]
    elseif LevelRegion[1] == 2 then--关卡
        return FightPointPassManager.GetFightIsOpenById(LevelRegion[2])
    end
end

--跳转显示新手提示圈
function this.ShowGuideGo()
end

--用于跳转回调
function this.ClosePanel()
    this.rectMask.enabled = true
end

function this:OnClose()
    FightPointPassManager.isBeginFight = false
    this.rectMask.enabled = true
end

function this:OnDestroy()
    -- allMissionDailyPres = {}
    -- allMissionDailyItemPres = {}
    boxList = {}
    allMissionDailyBoxItemPres = {}
end

return this