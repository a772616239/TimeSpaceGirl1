local LeiJiChongZhiPage = quick_class("LeiJiChongZhiPage")
local allData = {}
local itemsGrid = {}--item重复利用
local this = LeiJiChongZhiPage
local parent 
local endtime = 0
local rechargeNum 
local curtype = 0
function LeiJiChongZhiPage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

function LeiJiChongZhiPage:InitComponent(gameObject)
    this.time = Util.GetGameObject(gameObject, "time/timeText"):GetComponent("Text")
    -- this.text1 = Util.GetGameObject(gameObject, "bg1/Text"):GetComponent("Text")
    -- this.text2 = Util.GetGameObject(gameObject, "bg1/Text2"):GetComponent("Text")
    this.itemPre = Util.GetGameObject(gameObject, "ItemPre")
    this.scrollItem = Util.GetGameObject(gameObject, "grid")
    local rootHight = this.scrollItem.transform.rect.height
    local width = this.scrollItem.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollItem.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function LeiJiChongZhiPage:BindEvent()
end

--添加事件监听（用于子类重写）
function LeiJiChongZhiPage:AddListener()

end

--移除事件监听（用于子类重写）
function LeiJiChongZhiPage:RemoveListener()

end

local sortingOrder = 0
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LeiJiChongZhiPage:OnShow(_sortingOrder,_parent,_type)
    curtype = _type
    rechargeNum = VipManager.GetChargedNum()--已经充值的金额
    sortingOrder = _sortingOrder
    parent =  _parent
    this.Refresh()
end

function this.Refresh()
    this:OnShowData()
    this:SetTime()
end

function LeiJiChongZhiPage:SetTime()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    local timeDown = endtime
    this.time.text = GetLanguageStrById(10028)..TimeToDHMS(timeDown)
    self.timer = Timer.New(function()
        timeDown = timeDown - 1
        if timeDown < 1 then
            self.timer:Stop()
            self.timer = nil
            this.time.text = GetLanguageStrById(10028)..TimeToDHMS(0)
            return 
        end
        this.time.text = GetLanguageStrById(10028)..TimeToDHMS(timeDown)
    end, 1, -1, true)
    self.timer:Start()
end

function LeiJiChongZhiPage:OnShowData()   
    allData = OperatingManager.InitLeiJiChongZhiData(curtype)
    if allData then
        if curtype == ActivityTypeDef.AccumulativeRechargeExper then
            endtime = CalculateSecondsNowTo_N_OClock(24)
            -- this.text1.text = GetLanguageStrById(12408)
            -- this.text2.text = GetLanguageStrById(12409)
        else
            endtime = ActivityGiftManager.GetTaskEndTime(curtype) - GetTimeStamp()
            -- this.text1.text = GetLanguageStrById(12410)
            -- this.text2.text = GetLanguageStrById(12409)
        end
        
        this.SortData(allData)
        -- local itemList = {}
        allData[#allData+1] = {}
        this.ScrollView:SetData(allData, function (index, go)
            if index == #allData then
                go:SetActive(false)
                return
            end
            go:SetActive(true)
            this.SingleDataShow(go, allData[index])
            -- itemList[index] = go
        end)
        -- DelayCreation(itemList)
    else
        parent.OnPageTabChange(1)
        PopupTipPanel.ShowTipByLanguageId(12320)
        return
    end
    CheckRedPointStatus(RedPointType.DynamicActRecharge)
end
local typeIndex = {
    [0] = 2,
    [1] = 3,
    [2] = 1,
}
function LeiJiChongZhiPage:SortData()
    if allData == nil then
        return
    end
    table.sort(allData, function(a,b)
        if typeIndex[a.state] == typeIndex[b.state] then
            return a.id < b.id
        else
            return typeIndex[a.state] < typeIndex[b.state]
        end
    end)
end
local type = {
    [0] = {text = GetLanguageStrById(10023)},
    [1] = {text = GetLanguageStrById(10350)},
    [2] = {text = GetLanguageStrById(10022)},
}
--刷新每一条的显示数据
function this.SingleDataShow(pre,value)
    if pre == nil or value == nil then
        return
    end

    --绑定组件
    local go = pre
    go:SetActive(true)
    local sConFigData = value

    local num = Util.GetGameObject(go, "context/num"):GetComponent("Text")
    -- this:NumToNum(num, sConFigData.value)
    num.text = sConFigData.value
    local cur = sConFigData.progress > sConFigData.value and sConFigData.value or sConFigData.progress
    local target = sConFigData.value
    Util.GetGameObject(go, "context/progress"):GetComponent("Text").text = "("..cur .."/"..target..")"
    Util.GetGameObject(go, "context/Slider/Image"):GetComponent("Image").fillAmount = cur/target

    local reward = Util.GetGameObject(go.gameObject, "scrollView/grid")
    if not itemsGrid  then
        itemsGrid = {}
    end
    if not itemsGrid[pre] then
        itemsGrid[pre] = {}
    end
    for _, item in pairs(itemsGrid[pre]) do
        item.gameObject:SetActive(false)
    end
    for k,v in ipairs(sConFigData.reward) do
        if not itemsGrid[pre][k] then
            itemsGrid[pre][k] = SubUIManager.Open(SubUIConfig.ItemView,reward.transform)
        end
        itemsGrid[pre][k]:OnOpen(false, {v[1],v[2]}, 0.55, false)
        itemsGrid[pre][k].gameObject:SetActive(true)
    end

    local lingquButton = Util.GetGameObject(go.gameObject, "btnBuy")  
    local state = sConFigData.state
    local red = Util.GetGameObject(lingquButton.gameObject, "redPoint")
    red:SetActive(state == 2)

    Util.GetGameObject(lingquButton.gameObject, "price"):GetComponent("Text").text = type[state].text
    -- lingquButton:GetComponent("Image").sprite = Util.LoadSprite(type[state].sprite)
    lingquButton:GetComponent("Button").enabled = (state ~= 1)
    Util.SetGray(lingquButton.gameObject,state == 1)

    Util.AddOnceClick(lingquButton, function()
        if state == 2 then
            local curActivityId = ActivityGiftManager.GetActivityIdByType(curtype)
            NetManager.GetActivityRewardRequest(sConFigData.id, curActivityId,function(drop)    
                UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)
                this.Refresh()
            end)
        elseif state == 0 then
            if sConFigData.jump then
                JumpManager.GoJump(sConFigData.jump)
            end
        end    
    end)

end

-- function LeiJiChongZhiPage:NumToNum(num,_value)
--     local value = _value
--     local isFirst = true
--     for i = 1, 5 do
--         local m = Util.GetGameObject(num,"num"..i)
--         m:SetActive(false)
--         local t1 = math.floor(value/math.pow(10, (5-i)))
--         value = value%(math.pow(10, (5-i)))
--         if t1<1 and isFirst then
--             m:SetActive(false)
--         else
--             m:SetActive(true)
--             isFirst = false
--             m:GetComponent("Text").text = t1
--         end
--     end
-- end

--界面打开时调用（用于子类重写）
function LeiJiChongZhiPage:OnOpen()
end

function this.RechargeSuccessFunc(id)
end

function LeiJiChongZhiPage:OnClose()
end

--界面销毁时调用（用于子类重写）
function LeiJiChongZhiPage:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
    allData = {}
    itemsGrid = {}
end

function LeiJiChongZhiPage:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
end

--- 将一段时间转换为天时分秒
function LeiJiChongZhiPage:TimeToDHMS(second)
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

return LeiJiChongZhiPage