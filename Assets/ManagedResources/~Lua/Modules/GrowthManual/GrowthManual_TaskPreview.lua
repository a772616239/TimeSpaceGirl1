----- 日常任务弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local curType = 1
local treasureState
local isPlayAnim = true
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local type = {
    [0] = { text = GetLanguageStrById(10023) },--前往
    [1] = { text = GetLanguageStrById(10022) },--领取
    [2] = { text = GetLanguageStrById(10350) },--已领取
}
this.ItemBoxList = {}

function this:InitComponent(gameObject)    
    this.gameObject = gameObject     
    this.dayTrailBtn = Util.GetGameObject(this.gameObject, "Toggle/Toggle_Day"):GetComponent("Toggle")
    this.weekTrailBtn = Util.GetGameObject(this.gameObject, "Toggle/Toggle_Week"):GetComponent("Toggle")
    this.finalTrailBtn = Util.GetGameObject(this.gameObject, "Toggle/Toggle_Month"):GetComponent("Toggle")
    this.btnList = {}
    table.insert(this.btnList,this.dayTrailBtn.gameObject)
    table.insert(this.btnList,this.weekTrailBtn.gameObject)
    table.insert(this.btnList,this.finalTrailBtn.gameObject)

    --  this.weekTrailBtnRed = Util.GetGameObject(this.weekTrailBtn , "redPoint")
    --  this.finalTrailBtnRed = Util.GetGameObject(this.finalTrailBtn, "redPoint")
    this.remainTime = Util.GetGameObject(this.gameObject, "time/Text"):GetComponent("Text")
    this.treasureList = Util.GetGameObject(this.gameObject, "Rect")
    local v2 = this.treasureList.transform.rect
    this.itemPre = Util.GetGameObject(this.gameObject, "LevelItem")
    
    --设置滚动条
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.treasureList.transform,
    this.itemPre,nil,Vector2.New(v2.width,v2.height),1,1,Vector2.New(0,5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
    curType = 0
end

function this:BindEvent()
    this.dayTrailBtn.onValueChanged:AddListener(function (state)
        if state then
            curType = 0
            this.refresh(true,true)
            this:Choose(this.dayTrailBtn.gameObject)
        end
    end)
    this.weekTrailBtn.onValueChanged:AddListener(function (state)
        if state then
            curType = 1
            this.refresh(true,true)
            this:Choose(this.weekTrailBtn.gameObject)
        end
    end)
    this.finalTrailBtn.onValueChanged:AddListener(function (state)
        if state then
            curType = 2
            this.refresh(true,true)
            this:Choose(this.finalTrailBtn.gameObject)
        end
    end)
end

function this:RefreshRedpoint()
    Util.GetGameObject(this.dayTrailBtn.gameObject,"redpoint"):SetActive(GrowthManualManager.RefreshTeskRedpoint(0))
    Util.GetGameObject(this.weekTrailBtn.gameObject,"redpoint"):SetActive(GrowthManualManager.RefreshTeskRedpoint(1))
    Util.GetGameObject(this.finalTrailBtn.gameObject,"redpoint"):SetActive(GrowthManualManager.RefreshTeskRedpoint(2))
end

function this:Choose(btn)
    for i = 1, 3 do
        Util.GetGameObject(this.btnList[i],"Background/Checkmark"):SetActive(false)
        Util.GetGameObject(this.btnList[i],"Background/Label"):SetActive(true)
    end
    Util.GetGameObject(btn,"Background/Checkmark"):SetActive(true)
    Util.GetGameObject(btn,"Background/Label"):SetActive(false)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.TreasureOfHeaven.RechargeQinglongSerectSuccess, this.refresh)
    Game.GlobalEvent:AddEvent(GameEvent.TreasureOfHeaven.TaskRefresh, this.RefreshTime)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose,this.CloseFunction)
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.refresh)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold,this.refresh)
    Game.GlobalEvent:AddEvent(GameEvent.GrowthManual.OnGrowthManualRedpointChange,this.RefreshRedpoint)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.TreasureOfHeaven.RechargeQinglongSerectSuccess, this.refresh)
    Game.GlobalEvent:RemoveEvent(GameEvent.TreasureOfHeaven.TaskRefresh, this.RefreshTime)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose,this.CloseFunction)
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.refresh)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold,this.refresh)
    Game.GlobalEvent:RemoveEvent(GameEvent.GrowthManual.OnGrowthManualRedpointChange,this.RefreshRedpoint)
end

function this.RefreshTime()
    NetManager.RefreshTimeSLRequest(function (msg)
        this.refresh(false,false)
    end)
end

this.CloseFunction = function()
    Timer.New(function()
        if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
            PopupTipPanel.ShowTipByLanguageId(10029)
            if parent then
                parent:ClosePanel()
            end
            return
        else
            this.RefreshTime()
        end
    end,1):Start()
end

function this:OnShow(_parent,...)
    parent = _parent
    sortingOrder = _parent.sortingOrder   
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
        parent:ClosePanel()
        return
    end
    this.refresh(true,true)
    this:RefreshRedpoint()
end


function this:OnSortingOrderChange()
 end

function this:OnClose()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end
function this:OnDestroy()
    if self.timer then  
        self.timer:Stop()
        self.timer = nil
    end
end

function this.refresh(isTop,isAni)
    GrowthManualManager.UpdateTreasureState2()
    this:ShowTime(curType)
    this:showTaskList(curType,isTop,isAni)
    CheckRedPointStatus(RedPointType.QinglongSerectTreasureTrail)
    CheckRedPointStatus(RedPointType.QinglongSerectTreasure)
    CheckRedPointStatus(RedPointType.TreasureOfSl)
    Game.GlobalEvent:DispatchEvent(GameEvent.GrowthManual.OnGrowthManualRedpointChange)
end

local state = {
    [1] = 0,
    [0] = 1,
    [2] = 2,
}
-- local itemList
--任务列表
function this:showTaskList(type,isTop,isAni)
    local rewardData = GrowthManualManager.GetQinglongTaskData(type)
    table.sort(rewardData,function(a,b) 
        if state[a.state] == state[b.state] then
            return a.id > b.id
        else
            return state[a.state] < state[b.state]
        end
    end)
    -- itemList = {}
    this.ScrollView:SetData(rewardData,function(index, rewardItem)
        this:SingleTask(rewardItem, rewardData[index])
        -- itemList[index] = rewardItem
    end,not isTop,not isAni)
    -- if isAni then
    --     DelayCreation(itemList)
    -- end
end

--单个任务
function this:SingleTask(go, rewardSingleData)
    local activityRewardGo = go
    local sConFigData = rewardSingleData
    local name = Util.GetGameObject(activityRewardGo, "name"):GetComponent("Text")
    local strs = string.split(GetLanguageStrById(sConFigData.show)) 
    local value = sConFigData.taskValue[2][1]
    name.text = strs[1].."<size=28> ("..(math.abs(sConFigData.progress) > math.abs(value) and math.abs(value) or math.abs(sConFigData.progress)) .."/"..math.abs(value)..")</size>"
    local rewardContent = Util.GetGameObject(activityRewardGo, "ItemContent")
    if not this.ItemBoxList[activityRewardGo] then
        this.ItemBoxList[activityRewardGo] = SubUIManager.Open(SubUIConfig.ItemView,rewardContent.transform)
    end
    this.ItemBoxList[activityRewardGo].gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5,0.5)
    this.ItemBoxList[activityRewardGo].gameObject:GetComponent("RectTransform").localPosition = Vector3.zero
    this.ItemBoxList[activityRewardGo]:OnOpen(false, sConFigData.integral[1], 0.55,false,false,false,sortingOrder)

    local state = sConFigData.state
    local goBtn = Util.GetGameObject(activityRewardGo.gameObject, "goBtn")
    local red = Util.GetGameObject(goBtn.gameObject, "redPoint")
    local Received = Util.GetGameObject(activityRewardGo.gameObject,"Received")
    Received:SetActive(state == 2)
    red:SetActive(state == 1)
    local text = Util.GetGameObject(goBtn.gameObject, "Text") :GetComponent("Text")
    Util.SetGray(goBtn,state == 2)
    goBtn:GetComponent("Button").enabled = state ~= 2
    goBtn:SetActive(state ~= 2)
    text.text = GetLanguageStrById(type[state].text)
    Util.AddOnceClick(goBtn, function()
        if state == 1 then
            NetManager.TakeMissionRewardRequest(TaskTypeDef.TreasureOfSomeBody,sConFigData.id,  function(msg)
                PopupTipPanel.ShowTip(GetLanguageStrById(11332)..sConFigData.integral[1][2]..GetLanguageStrById(itemConfig[tonumber(sConFigData.integral[1][1])].Name))
                Timer.New(function()
                    this.refresh(false,false)
                end,1):Start()
            end)
        elseif state == 0 then
            if sConFigData.jump then
                JumpManager.GoJump(sConFigData.jump[1])
            end
        end
    end)
end

function this:ShowTime(curType)
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    local timeDown
    if curType == 0 then
        timeDown = CalculateSecondsNowTo_N_OClock(24)
    elseif curType == 1 then
        -- local info = ActivityGiftManager.GetActivityInfoByType(ActivityTypeDef.TreasureOfSomeBody)
        -- local startTime = info.startTime
        -- LogError(startTime)
        -- if GetTimeStamp() < startTime+604800 then
        --     timeDown = startTime+604800 - GetTimeStamp()
        --     LogError(TimeToDHMS(timeDown).."  |1   "..TimeStampToDateStr(startTime+604800))
        -- elseif GetTimeStamp() < startTime+604800*2 then
        --     timeDown = startTime+604800*2 - GetTimeStamp()
        --     LogError(TimeToDHMS(timeDown).."  |2   "..TimeStampToDateStr(startTime+604800*2))
        -- elseif GetTimeStamp() < startTime+604800*3 then
        --     timeDown = startTime+604800*3 - GetTimeStamp()
        --     LogError(TimeToDHMS(timeDown).."  |3   "..TimeStampToDateStr(startTime+604800*3))
        -- elseif GetTimeStamp() < startTime+604800*4 then
        --     timeDown = startTime+604800*4 - GetTimeStamp()
        --     LogError(TimeToDHMS(timeDown).."  |4   "..TimeStampToDateStr(startTime+604800*4))
        -- end
        timeDown = GrowthManualManager.GetTrailWeekTime()-GetTimeStamp()
    else
        timeDown = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.TreasureOfSomeBody)-GetTimeStamp()
    end
    this.remainTime.text = TimeToDHMS(timeDown)
    self.timer = Timer.New(function()
        if timeDown < 1 then
            this.remainTime.text = TimeToDHMS(0)
            self.timer:Stop()
            self.timer = nil
            this.RefreshTime()
            return
        end

        timeDown = timeDown - 1
        this.remainTime.text = TimeToDHMS(timeDown)
    end, 1, -1, true)
    self.timer:Start()
end

function this:NewItemView(config, gameObject, ...)
    local view = reimport(config.script)
    local sub = view:New(gameObject)
    sub.assetName = config.assetName
    if sub.Awake then
        sub:Awake()
    end
    if sub.InitComponent then
        sub:InitComponent()
    end
    if sub.BindEvent then
        sub:BindEvent()
    end
    if sub.AddListener then
        sub:AddListener()
    end
    if sub.Update then
        UpdateBeat:Add(sub.Update, sub)
    end
    if sub.OnOpen then
        sub:OnOpen(...)
    end
    return sub
end

return this