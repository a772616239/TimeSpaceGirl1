local DynamicTaskPage = quick_class("DynamicTaskPage")
local this = DynamicTaskPage
local allData = {}
local itemsGrid = {}--item重复利用
local singleTaskPre = {}
local parent
local endtime = 0
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local GlobalActConfig = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local AcitvityShowTheme = ConfigManager.GetConfig(ConfigName.AcitvityShowTheme)
local curindex

function DynamicTaskPage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

function DynamicTaskPage:InitComponent(gameObject)
    this.gameObject = gameObject
    this.time = Util.GetGameObject(gameObject, "time/Text"):GetComponent("Text")
    this.livePos = Util.GetGameObject(gameObject, "bg/live")
    this.font = Util.GetGameObject(gameObject, "bg/font"):GetComponent("Image")
    this.itemPre = Util.GetGameObject(gameObject, "ItemPre")
    this.scroll = Util.GetGameObject(gameObject, "scroll")
    local rootHight = this.scroll.transform.rect.height
    local width = this.scroll.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function DynamicTaskPage:BindEvent()
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.DynamicTask.OnMissionChange, this.Refresh)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.DynamicTask.OnMissionChange, this.Refresh)
end

local sortingOrder = 0
--界面打开时调用（用于子类重写）
function DynamicTaskPage:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DynamicTaskPage:OnShow(_sortingOrder, _parent)
    sortingOrder = _sortingOrder
    parent =  _parent

    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.DynamicAct)
    curindex = GlobalActConfig[id].ShowArt

    local spriteName = AcitvityShowTheme[curindex].Compent
    this.font.sprite = Util.LoadSprite(GetPictureFont(spriteName))

    if this.live then
        UnLoadHerolive(HeroConfig[AcitvityShowTheme[curindex].Live], this.live)
        Util.ClearChild(this.livePos.transform)
        this.live = nil
    end
    if AcitvityShowTheme[curindex].Live ~= 0 then
        this.live = LoadHerolive(HeroConfig[AcitvityShowTheme[curindex].Live], this.livePos.transform)
    end

    this.Refresh()
end

function DynamicTaskPage:OnClose()
end

--界面销毁时调用（用于子类重写）
function DynamicTaskPage:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end

    singleTaskPre = {}
    itemsGrid = {}

    if this.live then
        UnLoadHerolive(HeroConfig[AcitvityShowTheme[curindex].Live], this.live)
        Util.ClearChild(this.livePos.transform)
        this.live = nil
    end
    curindex = 0
end

function DynamicTaskPage:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end

function this.Refresh()
    allData = OperatingManager:InitDynamicActData()
    this:OnShowData()
    this:SetTime()
    CheckRedPointStatus(RedPointType.DynamicActTask)
end

function DynamicTaskPage:SetTime()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    local five_timeDown
    local week_timeDown
    five_timeDown = CalculateSecondsNowTo_N_OClock(24)
    week_timeDown = endtime - GetTimeStamp()
    -- for k,v in pairs(singleTaskPre) do   
    --     -- v.com.gameObject:SetActive(true)
    --     if v and v.data.type == 1 then
    --         if five_timeDown > 3600 then
    --             v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToH(five_timeDown))
    --         else
    --             v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToMS(five_timeDown))
    --         end
    --     else
    --         if week_timeDown > 3600 then
    --             v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToDH(week_timeDown))
    --         else
    --             v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToMS(week_timeDown))
    --         end
    --     end
    -- end
    this.time.text = GetLanguageStrById(12321)..TimeToDHMS(week_timeDown)
    self.timer = Timer.New(function()
        five_timeDown = five_timeDown - 1
        week_timeDown = week_timeDown - 1
        if five_timeDown <= 0  then
            this.Refresh()
            return
        end
        if week_timeDown <= 0 then
            return
        end
        -- for k,v in pairs(singleTaskPre) do          
        --     -- v.com.gameObject:SetActive(true)
        --     if v and v.data.type == 1 then
        --         if five_timeDown >= 3600 then
        --             v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToH(five_timeDown))
        --         else
        --             v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToMS(five_timeDown))
        --         end
        --     else
        --         if week_timeDown >= 3600 then
        --             v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToDH(week_timeDown))
        --         else
        --             v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToMS(week_timeDown))
        --         end
        --     end
        -- end
        this.time.text = GetLanguageStrById(12321)..TimeToDHMS(week_timeDown)
    end, 1, -1, true)
    self.timer:Start()
end

function DynamicTaskPage:OnShowData()
    if allData then
        endtime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.DynamicAct)
        this.SortData(allData)
        allData[#allData+1] = {}
        this.ScrollView:SetData(allData, function (index, go)
            if index == #allData then
                go:SetActive(false)
                return
            end
            go:SetActive(true)
            this.SingleDataShow(go, allData[index])
            if not singleTaskPre[go] then
                singleTaskPre[go] = {}
            end
            singleTaskPre[go].data = allData[index]
        end)
    else
        parent.OnPageTabChange(1)
        PopupTipPanel.ShowTipByLanguageId(12320)
    end
end

local typeIndex = {
    [0] = 1,
    [1] = 0,
    [2] = 2,
}
function DynamicTaskPage:SortData()
    if allData == nil then
        return
    end
    table.sort(allData, function(a,b)
        if typeIndex[a.state] == typeIndex[b.state] then
            if a.type == b.type then
                return a.id < b.id
            else
                return a.type < b.type
            end
        else
            return typeIndex[a.state] < typeIndex[b.state]
        end
    end)
end

--刷新每一条的显示数据
function this.SingleDataShow(go, data)--0-未完成  1-完成未领取 2-已领取
    local title = Util.GetGameObject(go, "context/title"):GetComponent("Text")
    local slider = Util.GetGameObject(go, "context/Slider/Image"):GetComponent("Image")
    local reward = Util.GetGameObject(go.gameObject, "scrollView/grid")
    local btn = Util.GetGameObject(go.gameObject, "btn")
    local red = Util.GetGameObject(btn.gameObject, "redPoint")

    title.text = data.title .. "#" .. data.content
    slider.fillAmount = data.progress > data.value and data.value or data.progress/data.value

    if itemsGrid[go] then
        for i = 1, #itemsGrid[go] do
            itemsGrid[go][i].gameObject:SetActive(false)
        end
        for i = 1, #data.reward do
            if itemsGrid[go][i] then
                itemsGrid[go][i]:OnOpen(false, {data.reward[i][1], data.reward[i][2]}, 0.65)
                itemsGrid[go][i].gameObject:SetActive(true)
            end
        end
    else
        itemsGrid[go] = {}
        for i = 1, #data.reward do
            itemsGrid[go][i] = SubUIManager.Open(SubUIConfig.ItemView, reward.transform)
            itemsGrid[go][i].gameObject:SetActive(false)
            local obj = newObjToParent(reward, itemsGrid[go][i].transform)
            obj.gameObject:SetActive(false)
        end
        for i = 1, #data.reward do
            itemsGrid[go][i]:OnOpen(false, {data.reward[i][1], data.reward[i][2]}, 0.65)
            itemsGrid[go][i].gameObject:SetActive(true)
        end
    end

    if data.state == 0 then
        btn:GetComponent("Image").color = UIColorNew.ORANGE
        Util.GetGameObject(btn, "Text"):GetComponent("Text").text = UIBtnText.go
    else
        btn:GetComponent("Image").color = UIColorNew.YELLOW
        Util.GetGameObject(btn, "Text"):GetComponent("Text").text = UIBtnText.get
    end

    red:SetActive(data.state == 1)
    Util.SetGray(btn, data.state == 2)
    btn:GetComponent("Button").enabled = data.state ~= 2

    Util.AddOnceClick(btn, function()
        if data.state == 1 then
            NetManager.TakeMissionRewardRequest(TaskTypeDef.DynamicActTask, data.id, function(respond)    
                UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1,function ()
                    this.Refresh()
                    CheckRedPointStatus(RedPointType.DynamicActTask)
                end)
            end)
        elseif data.state == 0 then
            if data.jump then
                JumpManager.GoJump(data.jump)
            end
        end
    end)
end

function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    -- OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.GiftBuy, id)
    this.Refresh()
end

--- 将一段时间转换为天时分秒
function DynamicTaskPage:TimeToDHMS(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    if day <= 0 and hour <= 0 then
        return string.format(GetLanguageStrById(12231),minute, sec)
    else
        return string.format(GetLanguageStrById(12232),day, hour)
    end
end

return DynamicTaskPage