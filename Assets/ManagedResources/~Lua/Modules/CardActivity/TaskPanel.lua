TaskPanel = quick_class("CardActivityPanel")
local this = TaskPanel
local GlobalActivity = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local ThemeActivityTaskConfig = ConfigManager.GetConfig(ConfigName.ThemeActivityTaskConfig)
local itemsGrid = {}
local singleTaskPre = {}
local endtime = 0
--初始化组件（用于子类重写）
function TaskPanel:InitComponent(parent)
    this.gameObject = parent

    this.time = Util.GetGameObject(this.gameObject, "time/Text"):GetComponent("Text")
    this.pre = Util.GetGameObject(this.gameObject, "itemPre")
    this.scroll = Util.GetGameObject(this.gameObject, "scroll")

    local v = this.scroll:GetComponent("RectTransform").rect
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
            this.pre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0, 5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function TaskPanel:BindEvent()
end

--添加事件监听（用于子类重写）
function TaskPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Task.Achievement,this.OnShow)
end

--移除事件监听（用于子类重写）
function TaskPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Task.Achievement, this.OnShow)
end
function TaskPanel:OnShow(sortingOrder, parent)
    this.Refresh()
    this.SetTime()
end

--界面关闭时调用（用于子类重写）
function TaskPanel:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function TaskPanel:OnDestroy()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    itemsGrid = {}
    singleTaskPre = {}
end

function this.Refresh()
    CheckRedPointStatus(RedPointType.CardActivity_Task)
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Task)
    local allData = CardActivityManager.GetTask(activityId, TaskTypeDef.CardActivity_Task)
    endtime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.CardActivity_Task)
    allData[#allData + 1] = {}
    this.scrollView:SetData(allData, function(index, go)
        if index == #allData then
            go:SetActive(false)
            return
        end
        go:SetActive(true)
        this.SetItemData(go, allData[index])

        if not singleTaskPre[go] then
            singleTaskPre[go] = {}
        end
        singleTaskPre[go].time = Util.GetGameObject(go,"btn/time"):GetComponent("Text")
        singleTaskPre[go].data = allData[index]
    end)
end

local type = {
    [0] = {text = GetLanguageStrById(10023)},
    [1] = {text = GetLanguageStrById(10022)},
    [2] = {text = GetLanguageStrById(10350)},
}
function this.SetItemData(go, data)
    local title = Util.GetGameObject(go, "title"):GetComponent("Text")
    local mission = Util.GetGameObject(go, "mission"):GetComponent("Text")
    local reward = Util.GetGameObject(go, "reward")
    local slider = Util.GetGameObject(go, "slider/Image"):GetComponent("Image")
    local btn = Util.GetGameObject(go, "btn")
    local redpoint = Util.GetGameObject(btn, "redPoint")
    local time = Util.GetGameObject(btn, "time")
    local btnTxt = Util.GetGameObject(btn, "Text"):GetComponent("Text")
    local finished = Util.GetGameObject(go, "finished")

    title.text = data.title
    slider.fillAmount = (data.progress > data.value and data.value or data.progress)/data.value
    mission.text = (data.progress > data.value and data.value or data.progress) .."/"..data.value
    if not itemsGrid[go] then
        itemsGrid[go] = {}
    end
    for i = 1, #itemsGrid[go] do
        itemsGrid[go][i].gameObject:SetActive(false)
    end
    for i = 1, #data.reward do
        if not itemsGrid[go][i] then
            itemsGrid[go][i] = SubUIManager.Open(SubUIConfig.ItemView,reward.transform)
        end
        itemsGrid[go][i]:OnOpen(false, data.reward[i], 0.55, false)
        itemsGrid[go][i].gameObject:SetActive(true)
    end

    time:SetActive(data.state == 0)
    redpoint:SetActive(data.state == 1)
    btnTxt.text = type[data.state].text
    finished:SetActive(data.state == 2)
    btn:SetActive(data.state ~= 2)

    if data.state == 1 then
        btn:GetComponent("Image").color = UIColorNew.YELLOW
    else
        btn:GetComponent("Image").color = UIColorNew.ORANGE
    end
    
    Util.AddOnceClick(btn, function ()
        if data.state == 1 then
            NetManager.TakeMissionRewardRequest(TaskTypeDef.CardActivity_Task, data.id, function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function ()
                    this.Refresh()
                end)
            end)
        elseif data.state == 0 then
            if data.jump then
                local id = data.jump
                if id == 27001 then
                    if ShopManager.SetMainRechargeJump() then
                        id = 36006
                    else
                        id = 36008
                    end
                end
                JumpManager.GoJump(id)
            end
        end
    end)
end

function this.SetTime()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    local dayTimeDown = CalculateSecondsNowTo_N_OClock(24)
    local weekTimeDown = endtime - GetTimeStamp()
    for k,v in pairs(singleTaskPre) do
        if v and v.data.type == 1 then
            if dayTimeDown > 3600 then
                v.time.text = GetLanguageStrById(10561) .. TimeToHMS(dayTimeDown)
            else
                v.time.text = GetLanguageStrById(10561) .. TimeToMS(dayTimeDown)
            end
        else
            if weekTimeDown > 3600 then
                v.time.text = GetLanguageStrById(10561) .. TimeToDH(weekTimeDown)
            else
                v.time.text = GetLanguageStrById(10561) .. TimeToMS(weekTimeDown)
            end
        end
    end
    this.time.text = GetLanguageStrById(12321) .. TimeToDHMS(weekTimeDown)
    this.timer = Timer.New(function()
        dayTimeDown = dayTimeDown - 1
        weekTimeDown = weekTimeDown - 1
        if dayTimeDown <= 0  then
            this.Refresh()
            return
        end
        if weekTimeDown <= 0 then
            return
        end
        for k,v in pairs(singleTaskPre) do
            if v and v.data.type == 1 then
                if dayTimeDown >= 3600 then
                    v.time.text = GetLanguageStrById(10561) .. TimeToHMS(dayTimeDown)
                else
                    v.time.text = GetLanguageStrById(10561) .. TimeToMS(dayTimeDown)
                end
            else
                if weekTimeDown >= 3600 then
                    v.time.text = GetLanguageStrById(10561) .. TimeToDH(weekTimeDown)
                else
                    v.time.text = GetLanguageStrById(10561) .. TimeToMS(weekTimeDown)
                end
            end
        end
        this.time.text = GetLanguageStrById(12321) .. TimeToDHMS(weekTimeDown)
    end, 1, -1, true)
    this.timer:Start()
end

return TaskPanel