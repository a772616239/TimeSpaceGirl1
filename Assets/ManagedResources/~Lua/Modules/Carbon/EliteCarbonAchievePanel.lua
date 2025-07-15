require("Base/BasePanel")
local EliteCarbonAchievePanel = Inherit(BasePanel)
local this = EliteCarbonAchievePanel

local btnImg = {
    "r_chouka_button_001", -- 可领取
    "r_chouka_button_002", -- 不可领取
}

-- 需要显示的界面类型
local panelType = 1
--初始化组件（用于子类重写）
function EliteCarbonAchievePanel:InitComponent()
    this.itemList = {}
    this.achieveItem = Util.GetGameObject(self.gameObject, "bg/item")
    this.achieveScrollView = Util.GetGameObject(self.gameObject, "bg/scrollview")
    this.btnBack = Util.GetGameObject(self.gameObject, "bg/close")
    this.title = Util.GetGameObject(self.gameObject, "bg/title"):GetComponent("Text")

    this.itemPre = Util.GetGameObject(self.gameObject, "bg/item")
    this.scrollItem = Util.GetGameObject(self.gameObject, "bg/scrollview")
    local rootHight = this.scrollItem.transform.rect.height
    local width = this.scrollItem.transform.rect.width

    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollItem.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, -2))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1.5



end

--绑定事件（用于子类重写）
function EliteCarbonAchievePanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        CheckRedPointStatus(RedPointType.EpicExplore_GetReward)
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function EliteCarbonAchievePanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshShow)
end

--移除事件监听（用于子类重写）
function EliteCarbonAchievePanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshShow)
end

--界面打开时调用（用于子类重写）
function EliteCarbonAchievePanel:OnOpen(carbonId, isCanGet, type)

    this.carbonId = carbonId
    this.isCanGet = isCanGet

    -- 传入的界面类型，默认是功绩界面
    if type then
        panelType = type
    else
        panelType = 1
    end

    -- Set title show context
    local str = panelType == 1 and GetLanguageStrById(10346) or GetLanguageStrById(10347)
    this.title.text = str
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function EliteCarbonAchievePanel:OnShow()
    ---- 判断是否限制滚动列表是否存在
    --if not this.achieveSV then
    --    local LimitNodeController = require("Modules/Common/LimitScrollView/LimitNodeController")
    --    local controller = LimitNodeController.Find("achieve")
    --    if not controller then
    --        controller = LimitNodeController.New("achieve")
    --        controller:AddNode(this.achieveItem)
    --    end
    --
    --    local LimitScrollView = require("Modules/Common/LimitScrollView/LimitScrollView")
    --    this.achieveSV = LimitScrollView.New()
    --    local content = Util.GetGameObject(this.achieveScrollView, "Content")
    --    this.achieveSV:SetScrollView(this.achieveScrollView, content)
    --    this.achieveSV:SetNodeController(controller)
    --end
    -- 刷新显示
    this.RefreshShow()
end

-- 刷新显示
function this.RefreshShow()
    -- 数据
    local datalist = {}
    -- 获取需要显示的数据
    if panelType == 1 then
        this.GetAchieveData(datalist)
    else
       datalist = MapTrialManager.GetLevelReward()
    end

    local callBack = function(index, item)
        local data = datalist[index]
        this.AchieveAdapter(item, data)
    end

    this.ScrollView:SetData(datalist, callBack)

    ---- 设置数据
    --this.achieveSV:SetData(datalist, function(dataIndex, go)
    --    local data = datalist[dataIndex]
    --    this.AchieveAdapter(go, data)
    --end)
end

-- 获得所有的功绩数据
function this.GetAchieveData(datalist)
    local taskInfoList = ConfigManager.GetAllConfigsDataByKey(ConfigName.AccomplishmentConfig, "MapId", this.carbonId)
    for _, data in ipairs(taskInfoList) do
        local taskData = TaskManager.GetTypeTaskInfo(TaskTypeDef.EliteCarbonTask, data.id)
        if taskData then
            local info = {}
            info.id = data.id
            info.MapId = data.MapId
            info.Sort = data.Sort
            info.Logic = data.Logic
            info.Values = data.Values
            info.Info = data.Info
            info.Score = data.Score
            info.Reward = data.Reward
            info.ScheduleShow = data.ScheduleShow
            info.progress = taskData.progress
            info.state = taskData.state
            table.insert(datalist, info)
        end
    end

    -- 排序
    table.sort(datalist, function(a, b)
        -- 已完成领取的排在最后
        if a.state == VipTaskStatusDef.Received and b.state ~= VipTaskStatusDef.Received then
            return false
        end
        if a.state ~= VipTaskStatusDef.Received and b.state == VipTaskStatusDef.Received then
            return true
        end
        -- 可以领取的排在最前面
        if a.state ~= b.state then
            return a.state > b.state
        else
            return a.Sort < b.Sort
        end

    end)

end

-- 成就节点数据匹配
function this.AchieveAdapter(node, data)
    -- 设置组件
    local desc = Util.GetGameObject(node, "content/desc"):GetComponent("Text")
    local progress = Util.GetGameObject(node, "content/progressBar"):GetComponent("Slider")
    local progressTip = Util.GetGameObject(node, "content/value"):GetComponent("Text")
    local btn = Util.GetGameObject(node, "content/dealBtn")
    local itemPos = Util.GetGameObject(node, "content/itemPos")
    local doneImg = Util.GetGameObject(node, "content/finished")
    -- 试炼副本奖励提示
    local trialTip = Util.GetGameObject(node, "content/trialRewardTip")

    -- 奖励
    if not this.itemList[tostring(node)] then
        local item = SubUIManager.Open(SubUIConfig.ItemView, itemPos.transform)
        this.itemList[tostring(node)]= item
    end


    local showInfo

    -- 根据打开的界面类型设置显示的组件
    this.SetCompShowByType(panelType, desc, progress, progressTip, trialTip)


    if panelType == 1 then -- 精英功绩数据
        local rewardInfo = ConfigManager.GetConfigData(ConfigName.RewardGroup, data.Reward[1])
        showInfo = rewardInfo.ShowItem[1]
        this.SetRewardData(data, desc,progress, progressTip, btn, doneImg)
    else -- 试炼副本数据
        showInfo = data.rewardInfo.FloorReward[1]
        this.SetTrialRewardData(data, btn, trialTip, doneImg)
    end

    -- 设置显示的奖励内容
    this.itemList[tostring(node)]:OnOpen(false, showInfo, 0.8)
end

-- 设置组件的显示与否
function this.SetCompShowByType(panelType, desc, progress, progressTip, trialTip)
    trialTip:SetActive(panelType ~= 1)
    desc.gameObject:SetActive(panelType == 1)
    progress.gameObject:SetActive(panelType == 1)
    progressTip.gameObject:SetActive(panelType == 1)
end

-- 设置具体的显示数据
function this.SetRewardData(data, desc, progress, progressTip, btn, doneImg)
    -- 设置显示数据
    local taskId = data.id
    -- 描述
    desc.text = data.Info
    -- 进度
    local curProgress = data.progress
    local totalProgress = data.ScheduleShow
    progress.value = curProgress/totalProgress
    progressTip.text = string.format("%d/%d", curProgress, totalProgress)

    -- 按钮
    local isDone = data.state == VipTaskStatusDef.Received

    btn:SetActive(this.isCanGet and not isDone)
    doneImg:SetActive(isDone)
    if this.isCanGet and not isDone then
        local isCanReceive = data.state == VipTaskStatusDef.CanReceive
        btn:GetComponent("Button").interactable = isCanReceive
        Util.GetGameObject(btn, "redPoint"):SetActive(isCanReceive)
        Util.SetGray(btn, false)
        local s = isCanReceive and GetLanguageStrById(10022) or GetLanguageStrById(10348)
        Util.GetGameObject(btn, "Text"):GetComponent("Text").text = s
        local index = isCanReceive and 1 or 2
        btn:GetComponent("Image").sprite = Util.LoadSprite(btnImg[index])
        
        Util.AddOnceClick(btn, function()
            if isCanReceive then
                NetManager.TakeMissionRewardRequest(TaskTypeDef.EliteCarbonTask, taskId, function(respond)
                    UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1)
                    TaskManager.SetTypeTaskState(TaskTypeDef.EliteCarbonTask, taskId, VipTaskStatusDef.Received)
                    this.RefreshShow()
                    CheckRedPointStatus(RedPointType.HeroExplore)
                end)
            end
        end)
    end
end


-- 试炼副本层级奖励数据
function this.SetTrialRewardData(data, btn, trialTip, doneImg)
    -- 提示文字
    trialTip:GetComponent("Text").text = GetLanguageStrById(10349) .. data.rewardInfo.Id .. GetLanguageStrById(10319)
    -- 领取状态
    doneImg:SetActive(false)
    btn:GetComponent("Button").interactable = false
    local curTrialLevel = data.rewardInfo.Id

    -- 当前领取状态
    local recieveState = data.state
    this.RefreshBtnState(recieveState, btn, doneImg)
    -- if 可以领取
    Util.AddOnceClick(btn, function ()
        NetManager.RequestLevelReward(curTrialLevel, function (msg)
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
            -- 刷新状态
            MapTrialManager.gotRewardLevel[curTrialLevel] = curTrialLevel
            this.RefreshShow()
        end)
    end)
end

-- 刷新领取按钮状态
function this.RefreshBtnState(recieveState, btn, doneImg)
    doneImg:SetActive(false)
    btn:SetActive(true)
    if recieveState == 2 then -- 不可领
        btn:GetComponent("Button").interactable = false
        btn:GetComponent("Image").sprite = Util.LoadSprite(btnImg[2])
        Util.GetGameObject(btn, "Text"):GetComponent("Text").text = GetLanguageStrById(10348)
        Util.GetGameObject(btn, "redPoint"):SetActive(false)
    elseif recieveState == 1 then -- 可领
        btn:GetComponent("Button").interactable = true
        btn:GetComponent("Image").sprite = Util.LoadSprite(btnImg[1])
        Util.GetGameObject(btn, "Text"):GetComponent("Text").text = GetLanguageStrById(10022)


        Util.GetGameObject(btn, "redPoint"):SetActive(true)
    elseif recieveState == 0 then -- 已领
        Util.GetGameObject(btn, "redPoint"):SetActive(false)
        Util.GetGameObject(btn, "Text"):GetComponent("Text").text = GetLanguageStrById(10350)
        btn:GetComponent("Image").sprite = Util.LoadSprite(btnImg[1])
    end
    Util.SetGray(btn, recieveState == 0)
end

--界面关闭时调用（用于子类重写）
function EliteCarbonAchievePanel:OnClose()
    --if this.achieveSV then
    --    this.achieveSV:RecycleNode()
    --    this.achieveSV = nil
    --end

    panelType = 1
end

--界面销毁时调用（用于子类重写）
function EliteCarbonAchievePanel:OnDestroy()
    this.itemList = {}

end

return EliteCarbonAchievePanel