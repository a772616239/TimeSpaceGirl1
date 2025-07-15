require("Base/BasePanel")
ChaosTaskPanel = Inherit(BasePanel)
local this = ChaosTaskPanel
--初始化组件（用于子类重写）
function ChaosTaskPanel:InitComponent()
    this.rewardPre = Util.GetGameObject(this.gameObject, "Contents/Panel/rewardPre")
    local v = Util.GetGameObject(this.gameObject, "Contents/Panel/MyBattleScrollView"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(this.gameObject, "Contents/Panel/MyBattleScrollView").transform,
            this.rewardPre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.NoviceItemList = {}--存储itemview 重复利用

    this.receiveAllBtn = Util.GetGameObject(this.gameObject, "Bottom/receiveAllBtn")
    
    this.backBtn = Util.GetGameObject(this.gameObject, "Bottom/closeBtn")
end




--绑定事件（用于子类重写）
function ChaosTaskPanel:BindEvent()   
    Util.AddClick(this.receiveAllBtn, function()
        NetManager.TakeMissionAllRewardRequest(TaskTypeDef.Chaos,function (msg) --加一个混乱所有任务领取
            if msg.drop == nil then return end
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                for i = 1,#msg.missionIds do
                    TaskManager.SetTypeTaskState(TaskTypeDef.Chaos, msg.missionIds[i], 2)
                end
                this.OnShowPanelData()
            end)
        end)
    end)
    Util.AddClick(this.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
            this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ChaosTaskPanel:AddListener()
end

--移除事件监听（用于子类重写）
function ChaosTaskPanel:RemoveListener()
    
end


function ChaosTaskPanel:RefreshView()

end

-- --界面打开时调用（用于子类重写）
function ChaosTaskPanel:OnOpen()

end

local taskState = {
    [0] = 1,   --未完成
    [1] = 0,     --完成未领取
    [2] = 2,  --已领取
}

function ChaosTaskPanel:OnShowPanelData()
    local Data = TaskManager.GetChaosTaskData(TaskTypeDef.Chaos)
    -- local AllData = {}
    if Data then
        -- for i, v in pairs(Data) do
        --     if v.missionId == 2006 then
        --         v.state = taskState[0]
        --     end
        --     if v.missionId == 2008 then
        --         v.state = taskState[2]
        --     end
        --    -- table.insert(AllData,v)
        -- end
        -- for i = 1, #Data do
        --     -- body
        --     LogError(Data[i].state)
        -- end
        table.sort(Data,function(a, b)
            if a.state == b.state then
                return a.missionId < b.missionId
            else
                return taskState[a.state] < taskState[b.state]
            end
        end)
        this.ScrollView:SetData(Data, function (index, go)
            this:SingleDataShow(go, Data[index])
            -- allAchievement[index] = go
        end)
    else
        Log("_________________服务器返回任务nil")
    end
    
end

function ChaosTaskPanel:SingleDataShow(go,rewardData)
    -- go:SetActive(true)
    
    local configData = ChaosManager:GetRewardConfigConfigData()
    local sConFigData = configData[rewardData.missionId]
    local titleText = Util.GetGameObject(go, "titleImage/titleText"):GetComponent("Text")
    titleText.text = GetLanguageStrById(sConFigData.ContentsShow) 
    local itemGroup = Util.GetGameObject(go, "content")
    --滚动条复用重设itemview
    if this.NoviceItemList[go] then
        for i = 1, #this.NoviceItemList[go] do
            this.NoviceItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #sConFigData.Reward do
            if this.NoviceItemList[go][i] then
                this.NoviceItemList[go][i]:OnOpen(false, {sConFigData.Reward[i][1],sConFigData.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                this.NoviceItemList[go][i].gameObject:SetActive(true)
            else
                this.NoviceItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
                this.NoviceItemList[go][i]:OnOpen(false, {sConFigData.Reward[i][1],sConFigData.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                this.NoviceItemList[go][i].gameObject:SetActive(true)
            end
        end
    else
        this.NoviceItemList[go] = {}
        -- for i = 1, #this.NoviceItemList[go] do
        --     this.NoviceItemList[go][i].gameObject:SetActive(false)
        -- end
        for i = 1, #sConFigData.Reward do
            if not this.NoviceItemList[go][i] then
                this.NoviceItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
            end
            this.NoviceItemList[go][i]:OnOpen(false, {sConFigData.Reward[i][1],sConFigData.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
            this.NoviceItemList[go][i].gameObject:SetActive(true)
        end
    end
    local receiveBtn = Util.GetGameObject(go.gameObject, "receiveBtn")
    local receiveBtnredPoint = Util.GetGameObject(go.gameObject, "receiveBtn/redPoint")
    local goBtn = Util.GetGameObject(go.gameObject, "goBtn")
    local Received = Util.GetGameObject(go.gameObject, "Received")
    local getRewardProgressSlider = Util.GetGameObject(go.gameObject, "getRewardProgress")
    local getRewardProgress = Util.GetGameObject(go.gameObject, "getRewardProgress/Txt")
    local state = rewardData.state
    local value = sConFigData.Param3[2][1]
    receiveBtn:SetActive(state == 1)   --可领取
    receiveBtnredPoint:SetActive(state == 1)   --可领取
    goBtn:SetActive(state == 0)        --未完成
    Received:SetActive(state == 2)   --已领取

    if state == 2 then
        getRewardProgressSlider:SetActive(false)
        -- TaskManager.SetTypeTaskState(TaskTypeDef.Achievement, rewardData.missionId, 2)
        -- go:SetActive(false)
    else
        local str = PrintWanNum4(math.abs(rewardData.progress)).."/"..PrintWanNum4(math.abs(value))
        local value = math.abs(rewardData.progress)/math.abs(value)
        -- if sConFigData.Type == 37 then
        --     if state == 0 then
        --         value = 0
        --         str = "0/"..1
        --     elseif state == 1 then
        --         value = 1
        --         str = "1/"..1
        --     end
        -- end
        getRewardProgressSlider:SetActive(true)
        getRewardProgressSlider:GetComponent("Slider").value = value
        getRewardProgress:GetComponent("Text").text = str
    end

    Util.AddOnceClick(goBtn, function()
        --Log("____前往")
        -- if sConFigData.Jump then
        --     JumpManager.GoJump(sConFigData.Jump[1])
        -- end
    end)
    Util.AddOnceClick(receiveBtn, function()
        NetManager.TakeMissionRewardRequest(TaskTypeDef.Chaos,rewardData.missionId,  function(msg)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                TaskManager.SetTypeTaskState(TaskTypeDef.Chaos, rewardData.missionId, 2)
                this:OnShowPanelData()
            end)
        end)
    end)

    -- if state == 1 then
    --     if this.IsAvailableAchievement(rewardData.missionId) then
    --         table.insert(allAvailableAchievement,rewardData.missionId)
    --     end
    -- end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ChaosTaskPanel:OnShow()
    this:OnShowPanelData()
end

--界面关闭时调用（用于子类重写）
function ChaosTaskPanel:OnClose()
  
end

--界面销毁时调用（用于子类重写）
function ChaosTaskPanel:OnDestroy()
end

return ChaosTaskPanel