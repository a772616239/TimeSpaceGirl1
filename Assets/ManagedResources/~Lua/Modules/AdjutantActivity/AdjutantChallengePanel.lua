local AdjutantChallengePanel = quick_class("AdjutantChallengePanel")
local allData = {}
local itemsGrid = {}--item重复利用
local singleTaskPre = {}
local this = AdjutantChallengePanel
local parent
local endtime = 0

function AdjutantChallengePanel:InitComponent(gameObject)

    itemsGrid = {}--item重复利用
    singleTaskPre = {}
    this.time = Util.GetGameObject(gameObject, "time/Text"):GetComponent("Text")
    this.itemPre = Util.GetGameObject(gameObject, "itemPre")
    this.scrollItem = Util.GetGameObject(gameObject, "scroll")
    local rootHight = this.scrollItem.transform.rect.height
    local width = this.scrollItem.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollItem.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
    this.gameObject = gameObject
end

--绑定事件（用于子类重写）
function AdjutantChallengePanel:BindEvent()
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.DynamicTask.OnMissionChange, this.Refresh)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.DynamicTask.OnMissionChange, this.Refresh)
end


--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AdjutantChallengePanel:OnShow(sortingOrder, _parent)
    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdjutantChallenge)

    -- local curindex = GlobalActConfig[id].ShowArt
    -- for k,v in pairs(bannerType) do
    --     Util.GetGameObject(this.gameObject, v.compent):SetActive(false)
    -- end
    -- Util.GetGameObject(this.gameObject, bannerType[curindex].compent):SetActive(true)
    -- Util.GetGameObject(this.gameObject, bannerType[curindex].compent):GetComponent("Image").sprite = Util.LoadSprite(bannerType[curindex].titilebg1)
    -- if bannerType[curindex].titilebg2 and bannerType[curindex].titilebg2 ~= "" then
    --     Util.GetGameObject(this.gameObject, bannerType[curindex].compent.."/Image"):GetComponent("Image").sprite = Util.LoadSprite(bannerType[curindex].titilebg2)
    -- end 
    parent = _parent
    this.Refresh()
end

function this.Refresh()
    CheckRedPointStatus(RedPointType.AdjutantActivity_Challenge)
    allData = AdjutantActivityManager.InitAdjutantData()
    this:OnShowData()
    this:SetTime()
end

function AdjutantChallengePanel:SetTime()
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
            if five_timeDown > 3600 then
                v.time.text = GetLanguageStrById(10561) .. TimeToHMS(five_timeDown)
            else
                v.time.text = GetLanguageStrById(10561) .. TimeToMS(five_timeDown)
            end
        else
            if week_timeDown > 3600 then
                v.time.text = GetLanguageStrById(10561) .. TimeToDH(week_timeDown)
            else
                v.time.text = GetLanguageStrById(10561) .. TimeToMS(week_timeDown)
            end
        end
    end
    this.time.text = GetLanguageStrById(12321) .. TimeToDHMS(week_timeDown)
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
        for k,v in pairs(singleTaskPre) do          
            -- v.com.gameObject:SetActive(true)
            if v and v.data.type == 1 then
                if five_timeDown >= 3600 then
                    v.time.text = GetLanguageStrById(10561) .. TimeToHMS(five_timeDown)
                else
                    v.time.text = GetLanguageStrById(10561) .. TimeToMS(five_timeDown)
                end
            else
                if week_timeDown >= 3600 then
                    v.time.text = GetLanguageStrById(10561) .. TimeToDH(week_timeDown)
                else
                    v.time.text = GetLanguageStrById(10561) .. TimeToMS(week_timeDown)
                end
            end
        end
        this.time.text = GetLanguageStrById(12321) .. TimeToDHMS(week_timeDown)
    end, 1, -1, true)
    self.timer:Start()
end

function AdjutantChallengePanel:OnShowData()
    if allData then
        endtime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.AdjutantChallenge)
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
            singleTaskPre[go].time = Util.GetGameObject(go,"Button/time"):GetComponent("Text")
            singleTaskPre[go].data = allData[index]
        end)
    else
        parent.OnPageTabChange(1)
        PopupTipPanel.ShowTip(GetLanguageStrById(12320))
    end
end

local typeIndex = {
    [0] = 1,
    [1] = 0,
    [2] = 2,
}
function AdjutantChallengePanel:SortData()
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
local type = {
    [0] = {text = GetLanguageStrById(10023)},
    [1] = {text = GetLanguageStrById(10022)},
    [2] = {text = GetLanguageStrById(10350)},
}
--刷新每一条的显示数据
function this.SingleDataShow(pre, data)
    if pre == nil or data == nil then
        return
    end
    --绑定组件
    local go = pre
    go:SetActive(true)
    local sConFigData = data

    Util.GetGameObject(go, "title"):GetComponent("Text").text = sConFigData.title
    Util.GetGameObject(go, "mission"):GetComponent("Text").text = (sConFigData.progress > sConFigData.value and sConFigData.value or sConFigData.progress) .."/"..sConFigData.value
    Util.GetGameObject(go, "slider/Image"):GetComponent("Image").fillAmount = (sConFigData.progress > sConFigData.value and sConFigData.value or sConFigData.progress)/sConFigData.value

    local reward = Util.GetGameObject(go, "reward")
    if not itemsGrid then
        itemsGrid = {}
    end
    if not itemsGrid[pre] then
        itemsGrid[pre] = SubUIManager.Open(SubUIConfig.ItemView,reward.transform)
    end
    itemsGrid[pre]:OnOpen(false, sConFigData.reward, 0.55, false)

    -- 0-未完成 1-完成未领取 2-已领取  --ThemeActivityTaskConfig
    local state = sConFigData.state

    local btn = Util.GetGameObject(go, "Button")
    Util.GetGameObject(btn, "time"):SetActive(state == 0)    

    Util.GetGameObject(btn, "redPoint"):SetActive(state == 1)
    Util.GetGameObject(btn, "Text"):GetComponent("Text").text = type[state].text
    Util.GetGameObject(btn, "Button").gameObject:SetActive(state ~= 2)
    Util.GetGameObject(go, "finished"):SetActive(state == 2)

    Util.AddOnceClick(btn, function()
        if state == 1 then
            NetManager.TakeMissionRewardRequest(TaskTypeDef.AdjutantChallengeTask,sConFigData.id, function(respond)    
                UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1,function ()
                    this.Refresh()
                    CheckRedPointStatus(RedPointType.DynamicActTask)
                end)
            end)
        elseif state == 0 then
            if sConFigData.jump then
                -- JumpManager.GoJump(sConFigData.jump)
                local id = sConFigData.jump
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

--界面打开时调用（用于子类重写）
function AdjutantChallengePanel:OnOpen()
end

function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    --OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.GiftBuy, id)
    this.Refresh()
end

function AdjutantChallengePanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function AdjutantChallengePanel:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end     
    singleTaskPre = {}
    itemsGrid = {}
end

function AdjutantChallengePanel:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
end
--- 将一段时间转换为天时分秒
function AdjutantChallengePanel:TimeToDHMS(second)
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

return AdjutantChallengePanel