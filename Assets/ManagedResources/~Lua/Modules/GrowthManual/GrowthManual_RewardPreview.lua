----- 日常任务弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0

local curScore = 0--当前分数
local treasureState = 0
local itemsList = {}

function this:InitComponent(gameObject)
     this.gameObject = gameObject
     this.treasureList = Util.GetGameObject(this.gameObject, "Rect")
     local v2 = this.treasureList.transform.rect
     this.itemPre = Util.GetGameObject(this.gameObject, "LevelItem")

     --设置滚动条
     this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.treasureList.transform,
        this.itemPre,nil,Vector2.New(v2.width,v2.height),1,1,Vector2.New(0,5))
     this.ScrollView.moveTween.MomentumAmount = 1
     this.ScrollView.moveTween.Strength = 2
end

function this:BindEvent()   

end
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.TreasureOfHeaven.BuyQinglongSerectLevelSuccess, this.refresh)
    Game.GlobalEvent:AddEvent(GameEvent.TreasureOfHeaven.RechargeQinglongSerectSuccess, this.refresh)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose,this.Closefunction)
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.refresh)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold,this.refresh)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.TreasureOfHeaven.BuyQinglongSerectLevelSuccess, this.refresh)
    Game.GlobalEvent:RemoveEvent(GameEvent.TreasureOfHeaven.RechargeQinglongSerectSuccess, this.refresh)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose,this.Closefunction)
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.refresh)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold,this.refresh)
end
this.Closefunction = function()    
    Timer.New(function()
        if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
            PopupTipPanel.ShowTipByLanguageId(10029)            
            parent:ClosePanel()            
            return
        else
            this.refresh(false,false)
        end
    end,1):Start()
end
function this:OnShow(_parent)    
    parent =_parent
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
        self:ClosePanel()
        return 
    end

    this.refresh(true,true)
end
function this:OnSortingOrderChange()

end

function this:OnClose()
    
end
function this:OnDestroy()    
    itemsList = {}

    if self.timer then
        self.timer :Stop()
        self.timer  = nil
    end
end

this.refresh = function(isTop,isAni) 
    treasureState = GrowthManualManager.GetTreasureState()--秘宝礼包状态 false:可购买  true:已购买
    GrowthManualManager.UpdateTreasureState2() 

    this:showTaskList(isTop,isAni)
    CheckRedPointStatus(RedPointType.TreasureOfSl)
end

--任务列表
function this:showTaskList(isTop,isAni)
    local rewardData = GrowthManualManager.GetAllRewardData()
    this.ScrollView:SetData(rewardData,function(index, rewardItem)
        this:SingleTask(rewardItem, rewardData[index])
    end,not isTop,not isAni)
    local index = 0
    if GrowthManualManager.GetLevel() == 1 then
        index = 1
    else
        for k,v in ipairs(rewardData) do
            if v.state == 1 and treasureState then
                index = k
                break
            elseif v.state == 0 and treasureState then
                index = k
                break
            elseif  v.state == 0 and (not treasureState) and (k < 35) then
                index = k
                break
            elseif v.state == 0 and (not treasureState) and (k >= 35) then
                index = 35
                break
            end
        end
        if index == 0 then
            for i = #rewardData , 1 , -1 do
                if (rewardData[i].state == -1) or (rewardData[i].state == 1 and not treasureState) then
                    index = i
                    break
                end
            end
        end
    end
    this.ScrollView:SetIndex(index)
end

--单个任务
function this:SingleTask(rewardItem, rewardSingleData)
    local scoreLevel = Util.GetGameObject(rewardItem, "Text_Level"):GetComponent("Text")
    local box1 = Util.GetGameObject(rewardItem, "ItemContent")
    local box2 = Util.GetGameObject(rewardItem, "ItemJingyingContent")

    local normalGeted = Util.GetGameObject(rewardItem,"NormalReceived")
    local eliteGeted = Util.GetGameObject(rewardItem,"EliteGeteds")
    local unlockTip = Util.GetGameObject(rewardItem,"Locks")
    unlockTip.gameObject:SetActive(not treasureState)
    if not itemsList[rewardItem] then
        itemsList[rewardItem] = {}
    end 
    for i = 1, #itemsList[rewardItem] do
        itemsList[rewardItem][i].gameObject:SetActive(false)
    end

    scoreLevel.text = rewardSingleData.level
    normalGeted.gameObject:SetActive(false)
    eliteGeted.gameObject:SetActive(false)

    local SetMask = function (item,i,type)
        if type == 1 then
            if rewardSingleData.state == 1 or rewardSingleData.state == -1 then
                normalGeted.gameObject:SetActive(true)
            end
        else
            if rewardSingleData.state == -1 then
                eliteGeted.gameObject:SetActive(true)
            end
        end
        if i < 3 then
            Util.GetGameObject(eliteGeted,"EliteGeted2"):SetActive(false)
            Util.GetGameObject(unlockTip,"Lock2"):SetActive(false)
        else
            Util.GetGameObject(eliteGeted,"EliteGeted2"):SetActive(true)
            Util.GetGameObject(unlockTip,"Lock2"):SetActive(true)
        end
    end

    for i = 1, #rewardSingleData.Reward do
        if not itemsList[rewardItem][i] then
            itemsList[rewardItem][i] = SubUIManager.Open(SubUIConfig.ItemView,box1.transform)
            itemsList[rewardItem][i].gameObject:SetActive(false)
        end
        if rewardSingleData.Reward[i] then
            if rewardSingleData.Reward[i].type == 1 then
                itemsList[rewardItem][i].gameObject.transform:SetParent(box1.transform)
            else
                itemsList[rewardItem][i].gameObject.transform:SetParent(box2.transform)
            end
            itemsList[rewardItem][i].gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5,0.5)
            itemsList[rewardItem][i].gameObject:GetComponent("RectTransform").localPosition = Vector3.zero
            itemsList[rewardItem][i].gameObject:SetActive(true)
            itemsList[rewardItem][i]:OnOpen(false, rewardSingleData.Reward[i].item, 0.65,false,false,false,sortingOrder)

            SetMask(rewardItem,i,rewardSingleData.Reward[i].type)
        else
            itemsList[rewardItem][i].gameObject:SetActive(false)
        end
    end

    --初始化按钮状态
    this:InitButtonState(rewardItem, rewardSingleData)
end

local type = {
    [-2] = { text = GetLanguageStrById(10348)},--未达成
    [-1] = { text = GetLanguageStrById(10350)},--已领取
    [0] = { text = GetLanguageStrById(10022)}, --领取
    [1] = { text = GetLanguageStrById(12356)}--再次领取
}
--初始化按钮状态
function this:InitButtonState(rewardItem, rewardSingleData)
    rewardItem:SetActive(true)

    local go = rewardItem
    local get = Util.GetGameObject(go, "Button_Get")
    local text = Util.GetGameObject(get, "Text"):GetComponent("Text")
    local redPoint = Util.GetGameObject(go, "Button_Get/redPoint")
    local done = Util.GetGameObject(rewardItem,"Done")
    --当前任务领取情况
    local state = rewardSingleData.state
    done:SetActive(state == -1)
    get:SetActive(state ~= -1)
    redPoint:SetActive(state == 0 or (state == 1 and treasureState))
    -- get.sprite = Util.LoadSprite(type[state].sprite)
    -- get.enabled = true
    text.text = type[state].text
    -- if state == -1 then
        -- btnDeal:GetComponent("Button").enabled = false     
        -- get.enabled = false 
    -- else
        -- btnDeal:GetComponent("Button").enabled = true
        Util.AddOnceClick(get,function()
            this:OnBtnDealClicked(go,rewardSingleData)
            Game.GlobalEvent:DispatchEvent(GameEvent.GrowthManual.OnGrowthManualRedpointChange)
        end)
    -- end
end

--按钮事件
function this:OnBtnDealClicked(rewardItem,rewardSingleData)
    if rewardSingleData.state ~= -2 then--分数达到要求
        if (rewardSingleData.state == 0) or--任务未领取
        (rewardSingleData.state == 1 and treasureState) then--任务未领取+礼包已购买
            -- if PlayerManager.level < rewardSingleData.LevelCondLimit then
            --     PopupTipPanel.ShowTip(GetLanguageStrById(10657) .. GetLanguageStrById(10782) .. rewardSingleData.LevelCondLimit)
            --     return
            -- end
            local id = ActivityGiftManager.GetActivityIdByType(ActivityTypeDef.TreasureOfSomeBody)
            
            NetManager.GetActivityRewardRequest(rewardSingleData.level,id,function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg,1)
                --需要刷新界面
                if not treasureState then--判断是否已经购买了礼包
                    GrowthManualManager.SetSingleRewardState(rewardSingleData.level,1)
                else
                    GrowthManualManager.SetSingleRewardState(rewardSingleData.level,-1)
                end
                this.refresh(false,false)--刷新界面
            end)
        elseif rewardSingleData.state == 1 and (not treasureState) then----任务已领取+礼包未购买（弹出购买界面）
            UIManager.OpenPanel(UIName.GrowthManualBuyPanel)
        end
    else--分数未达到要求
        PopupTipPanel.ShowTip(GetLanguageStrById(11989))   
    end
end
return this