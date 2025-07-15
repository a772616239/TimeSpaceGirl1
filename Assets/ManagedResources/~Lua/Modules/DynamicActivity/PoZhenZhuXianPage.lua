local PoZhenZhuXianPage = quick_class("PoZhenZhuXianPage")
local allData={}
local itemsGrid = {}--item重复利用
local singleTaskPre = {}
local this=PoZhenZhuXianPage
local parent 
local endtime = 0
function PoZhenZhuXianPage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

function PoZhenZhuXianPage:InitComponent(gameObject)
    itemsGrid = {}--item重复利用
    singleTaskPre = {}
    this.time = Util.GetGameObject(gameObject, "content/tiao/time"):GetComponent("Text")
    this.itemPre = Util.GetGameObject(gameObject, "content/itempre")
    this.scrollItem = Util.GetGameObject(gameObject, "content/grid")
    local rootHight = this.scrollItem.transform.rect.height
    local width = this.scrollItem.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollItem.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 30))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function PoZhenZhuXianPage:BindEvent()
end

--添加事件监听（用于子类重写）
function PoZhenZhuXianPage:AddListener()
end

--移除事件监听（用于子类重写）
function PoZhenZhuXianPage:RemoveListener()
end
local sortingOrder = 0
--界面打开时调用（用于子类重写）
function PoZhenZhuXianPage:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PoZhenZhuXianPage:OnShow(_sortingOrder,_parent)
    sortingOrder = _sortingOrder
    parent =  _parent
    this.Refresh()
end

function this.Refresh()
    allData = OperatingManager:InitPoZhenZhuXianData()
    this:OnShowData()
    this:SetTime()
end

function PoZhenZhuXianPage:SetTime()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    local five_timeDown
    local week_timeDown
    five_timeDown = CalculateSecondsNowTo_N_OClock(24)
    week_timeDown = endtime - GetTimeStamp()
    for k,v in pairs(singleTaskPre) do   
        -- v.com.gameObject:SetActive(true)
        if v and v.data.type == 1 then
            v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561), TimeToH(five_timeDown))
        else
            v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561), TimeToDH(week_timeDown))
        end     
    end   
    this.time.text = GetLanguageStrById(12321)..TimeToDHMS(week_timeDown)
    self.timer = Timer.New(function()
        five_timeDown = five_timeDown - 1
        week_timeDown = week_timeDown - 1
        if five_timeDown <= 0  then
            this.Refresh()
            return
        end
        if week_timeDown <= 0 then
            parent:ClosePanel()
            return
        end
        for k,v in pairs(singleTaskPre) do          
            -- v.com.gameObject:SetActive(true)
            if v and v.data.type == 1 then
                v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToH(five_timeDown))
            else
                v.com:GetComponent("Text").text = string.format(GetLanguageStrById(10561),TimeToDH(week_timeDown))
            end  
        end   
        this.time.text = GetLanguageStrById(12321)..TimeToDHMS(week_timeDown)
    end, 1, -1, true)
    self.timer:Start()
end

function PoZhenZhuXianPage:OnShowData()
    if allData then
        endtime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.pozhenzhuxian_task)
        this.SortData(allData)
        this.ScrollView:SetData(allData, function (index, go)
            this.SingleDataShow(go, allData[index])
            if not singleTaskPre[go] then
                singleTaskPre[go] = {}
            end
            singleTaskPre[go].com = Util.GetGameObject(go,"btn/Text")
            singleTaskPre[go].data = allData[index]
        end)   
    else
        parent.OnPageTabChange(1)
        PopupTipPanel.ShowTipByLanguageId(12320)
        return
    end
    
end
local typeIndex = {
    [0] = 1,
    [1]  = 0,
    [2] = 2,
}
function PoZhenZhuXianPage:SortData()
    if allData==nil then
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
local type={
    [0]={sprite = "m5_btn_001",text = GetLanguageStrById(10023)},--m5
    [1]={sprite = "m5_btn_002",text = GetLanguageStrById(10022)},--m5   
    [2]={sprite = "m5_btn_001",text = GetLanguageStrById(10350)},--m5  
    
}
--刷新每一条的显示数据
function this.SingleDataShow(pre,value)
    if pre==nil or value==nil then
        return
    end
    --绑定组件
    local activityRewardGo = pre
    activityRewardGo:SetActive(true)
    local sConFigData = value

    local titleText = Util.GetGameObject(activityRewardGo, "title"):GetComponent("Text")
    titleText.text = sConFigData.title .."("..(sConFigData.progress > sConFigData.value and sConFigData.value or sConFigData.progress) .."/"..sConFigData.value..")"
    local missionText = Util.GetGameObject(activityRewardGo, "mission"):GetComponent("Text")
    missionText.text = sConFigData.content
    local timeText = Util.GetGameObject(activityRewardGo, "btn/Text")

    local reward = Util.GetGameObject(activityRewardGo.gameObject, "reward")
    if (not itemsGrid)  then
        itemsGrid = {}
    end
    if not itemsGrid[pre] then
        itemsGrid[pre] = SubUIManager.Open(SubUIConfig.ItemView,reward.transform)
    end
    itemsGrid[pre]:OnOpen(false, sConFigData.reward, 0.9, false)

    local lingquButton = Util.GetGameObject(activityRewardGo.gameObject, "btn")  
    --0-未完成，1-完成未领取  2-已领取
    local state = sConFigData.state
    timeText:SetActive(state == 0)
    
    local red = Util.GetGameObject(lingquButton.gameObject, "redPoint")
    red:SetActive(state == 1)

    Util.GetGameObject(lingquButton.gameObject, "Button/Text"):GetComponent("Text").text = type[state].text
    Util.GetGameObject(lingquButton.gameObject, "Button"):GetComponent("Image").sprite = Util.LoadSprite(type[state].sprite)
    Util.GetGameObject(lingquButton.gameObject, "Button").gameObject:SetActive(state ~= 2)
    Util.GetGameObject(lingquButton.gameObject, "image").gameObject:SetActive(state == 2)

    Util.AddOnceClick(Util.GetGameObject(lingquButton.gameObject, "Button"), function()
        if state == 1 then
            NetManager.TakeMissionRewardRequest(TaskTypeDef.PoZhenZhuXianTask,sConFigData.id, function(respond)    
                UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1,function ()
                    this.Refresh()
                    CheckRedPointStatus(RedPointType.PoZhenZhuXianTask)
                end)
            end)
        elseif state == 0 then
            if sConFigData.jump then
                JumpManager.GoJump(sConFigData.jump)
            end
        end        
    end)
end

--界面打开时调用（用于子类重写）
function PoZhenZhuXianPage:OnOpen()

end

function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    --OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.GiftBuy, id)
    this.Refresh()
end

function PoZhenZhuXianPage:OnClose()

end

--界面销毁时调用（用于子类重写）
function PoZhenZhuXianPage:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
    singleTaskPre = {}
    itemsGrid = {}
end

function PoZhenZhuXianPage:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
end
--- 将一段时间转换为天时分秒
function PoZhenZhuXianPage:TimeToDHMS(second)
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

return PoZhenZhuXianPage