local YiJingBaoKu = quick_class("YiJingBaoKu")
local this = YiJingBaoKu
local _itemsList = {}
local _itemsPosList = {}
local itemViewList = {}

local ActData = {}
local sortingOrder = 0
local parent
local finalReward = nil
local trigger = true

local BlessingConfig = ConfigManager.GetConfig(ConfigName.BlessingRewardPoolNew)

function YiJingBaoKu:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    YiJingBaoKu:InitComponent(gameObject)
    YiJingBaoKu:BindEvent()
end

function YiJingBaoKu:InitComponent(gameObject)

    this.name = Util.GetGameObject(gameObject, "name/Text"):GetComponent("Text")
    this.itemFinal = Util.GetGameObject(gameObject, "reward/icon")
    this.addBtn = Util.GetGameObject(gameObject, "reward/add")
    this.itemTra = Util.GetGameObject(gameObject, "reward/daoju")
    this.refrashBtn = Util.GetGameObject(gameObject, "reward/refrash")
    this.tip = Util.GetGameObject(gameObject, "reward/tips/Text"):GetComponent("Text")

    this.time = Util.GetGameObject(gameObject, "time/timeText"):GetComponent("Text")

    this.helpBtn = Util.GetGameObject(gameObject, "helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition
    this.rewardPre = Util.GetGameObject(gameObject, "rewardPre")

    this.grid = Util.GetGameObject(gameObject, "content/grid")
    for i = 1, this.grid.transform.childCount do
        _itemsList[i] = this.grid.transform:GetChild(i - 1)
        _itemsPosList[i] = _itemsList[i]:GetComponent("RectTransform").localPosition
    end

    this.tip2 = Util.GetGameObject(gameObject, "Tip/tip"):GetComponent("Text")
    --effect
    this.effect = Util.GetGameObject(gameObject, "UI_effect_dig")
end

--绑定事件（用于子类重写）
function YiJingBaoKu:BindEvent()
    Util.AddClick(this.addBtn,function()
        UIManager.OpenPanel(UIName.GeneralBigPopup,GENERAL_POPUP_TYPE.YiJingBaoKu,ActData,function()
            YiJingBaoKu:SetFinalReward()
            YiJingBaoKu:FrontToBack()
            this.refrashBtn:SetActive(ActData.selectId ~= 0)
        end)
    end)
    
    Util.AddClick(this.refrashBtn,function()
        UIManager.OpenPanel(UIName.GeneralBigPopup,GENERAL_POPUP_TYPE.YiJingBaoKu,ActData,function()
            YiJingBaoKu:SetFinalReward()
        end)
    end)

    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.YiJingBaoKu,this.helpPosition.x,this.helpPosition.y)
    end)

    Util.AddClick(this.rewardPre,function()
        if ActData.selectId == 0 then
            PopupTipPanel.ShowTipByLanguageId(12416)
            return
        end
        UIManager.OpenPanel(UIName.GeneralBigPopup,GENERAL_POPUP_TYPE.YiJingBaoKuRewardPreview,ActData)
    end)
end

--添加事件监听（用于子类重写）
function YiJingBaoKu:AddListener()
end

--移除事件监听（用于子类重写）
function YiJingBaoKu:RemoveListener()
end
--界面打开时调用（用于子类重写）
function YiJingBaoKu:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function YiJingBaoKu:OnShow(_sortingOrder,_parent)
    Util.AddParticleSortLayer(this.effect, _sortingOrder - sortingOrder)
    -- local image = Util.GetGameObject(this.effect, "UI_Effect_YJBK_Zao/GameObject/Image (2)"):GetComponent("Canvas")
    -- image.sortingOrder = _sortingOrder + 1
    sortingOrder = _sortingOrder
    parent = _parent
    
    YiJingBaoKu:Refresh()

end

function YiJingBaoKu:OnSortingOrderChange(_sortingOrder)
    Util.AddParticleSortLayer(this.effect, _sortingOrder - sortingOrder)
    -- local image = Util.GetGameObject(this.effect, "UI_Effect_YJBK_Zao/GameObject/Image (2)"):GetComponent("Canvas")
    -- image.sortingOrder = _sortingOrder + 1
    sortingOrder = _sortingOrder
end

--刷新
function YiJingBaoKu:Refresh()
    ActData = DynamicActivityManager.GetBaoKuData()

    if ActData.selectId == 0 then--如果没有选择了最终奖励
        YiJingBaoKu:ResetCardToFront()--把卡片全部翻到正面
        YiJingBaoKu:InitSetAllCard()--显示所有奖励
        this.tip.text = GetLanguageStrById(12417)
    else--选择了最终奖励
        YiJingBaoKu:ResetCardToBack()--把卡片全部翻到背面
        YiJingBaoKu:SetFinalReward()--设置最终奖励
        YiJingBaoKu:SetCardData()--把抽取过的卡翻过来
        this.tip.text = GetLanguageStrById(12417)
    end
    YiJingBaoKu:TimeCountDown()--时间
    YiJingBaoKu:AddBackToFrontClick()--增加背面的带点击事件
    trigger = true
    this.addBtn:GetComponent("Button").enabled = ActData.selectId == 0
    this.name.text = GetLanguageStrById(10311)..NumToSimplenessFont[ActData.curLevel]..GetLanguageStrById(10319)
    this.tip2.text = GetLanguageStrById(12418)

    local t1 = true
    for i = 1, #ActData.finalCardDatas do
        if ActData.selectId == ActData.finalCardDatas[i].rewardId then
            t1 = false
        end
    end
    this.refrashBtn:SetActive((ActData.selectId ~= 0) and t1)

end

function YiJingBaoKu:SetCardData()
    for i = 1, #ActData.finalCardDatas do
        local v = ActData.finalCardDatas[i]
        if v.rewardId ~= 0 then
            local item = _itemsList[i]
            local cFront = Util.GetGameObject(item, "front")
            local cBack = Util.GetGameObject(item, "back")
            if not itemViewList[i] then
                itemViewList[i] = SubUIManager.Open(SubUIConfig.ItemView,cFront.transform)
            end
            itemViewList[i]:OnOpen(false, v.reward, 0.6, false, false, false, sortingOrder)
            itemViewList[i].transform.localPosition = Vector2.New(0,10)
            itemViewList[i].transform.rotation = Vector3.zero
            cFront:GetComponent("RectTransform").rotation = Quaternion.Euler(Vector3.New(0, 0, 0))
            cBack:GetComponent("RectTransform").rotation = Quaternion.Euler(Vector3.New(0, 90, 0))
            itemViewList[i].gameObject:SetActive(true)
        end
    end
end

function YiJingBaoKu:SetFinalReward()
    ActData = DynamicActivityManager.GetBaoKuData()
    if not finalReward then
        finalReward = SubUIManager.Open(SubUIConfig.ItemView,this.itemTra.transform)
    end
    finalReward:OnOpen(false, BlessingConfig[ActData.selectId].Reward, 0.65, false, false, false, sortingOrder)
    finalReward.transform.localPosition = Vector2.New(0,0)
    finalReward.gameObject:SetActive(true)
end

--初始化给所有坑赋值
function YiJingBaoKu:InitSetAllCard()
    for i = 1, #_itemsList do
        if ActData.initCardDatas[i].reward then
            YiJingBaoKu:SetSingleCardData(i,_itemsList[i],ActData.initCardDatas[i].reward)
        end
    end
end

----单个的卡增加点击
function YiJingBaoKu:AddBackToFrontClick()
    for index, value in ipairs(_itemsList) do
        local cFront = Util.GetGameObject(value, "front")
        local cBack = Util.GetGameObject(value, "back")
        local btn = Util.GetGameObject(value, "back/btn")
        Util.AddOnceClick(btn,function()
            --请求奖励
            if BagManager.GetTotalItemNum(1004) <= 0 then
                PopupTipPanel.ShowTipByLanguageId(11880)
                return
            end
            if not trigger then
                return
            end
            trigger = false
            
            NetManager.GetActivityRewardRequest(ActData.finalCardDatas[index].Id,ActData.activityId,function (drop)
                local tempData = YiJingBaoKu:RebuildDrop(drop)
                YiJingBaoKu:SetSingleCardData(index,value,tempData)
                local thread = coroutine.start(function()
                    this.effect.transform:SetParent(value.transform)
                    this.effect:GetComponent("RectTransform").localPosition = Vector3.zero
                    this.effect:SetActive(true)
                    -- coroutine.wait(0.3)
                    cFront.transform:DORotate(Vector3.New(0, 0, 0), 0)
                    -- coroutine.wait(0.8)
                    this.effect:SetActive(false)
                    UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1,function ()
                        trigger = true
                        if tempData[1] == BlessingConfig[ActData.selectId].Reward[1] then
                            finalReward.gameObject:SetActive(false)
                            if itemViewList[18] then
                                itemViewList[18].gameObject:SetActive(false)
                            end
                            YiJingBaoKu:Refresh()
                        end
                        YiJingBaoKu:Refresh()
                    end)
                end)
            end)
        end)
    end
end

function YiJingBaoKu:RebuildDrop(drop)
    local tempTable = BagManager.GetTableByBackDropData(drop)
    local reward = {tempTable[1].sId,tempTable[1].num}
    return reward
end

--单个翻卡赋值
function YiJingBaoKu:SetSingleCardData(index,item,reward)
    local root = Util.GetGameObject(item,"front")
    if not itemViewList[index] then
        itemViewList[index] = SubUIManager.Open(SubUIConfig.ItemView,root.transform)
    end
    itemViewList[index]:OnOpen(false, reward, 0.55, false, false, false, sortingOrder)
    itemViewList[index].transform.localPosition = Vector2.New(0,0)
    itemViewList[index].gameObject:SetActive(true)
end

--所有奖励翻面
function YiJingBaoKu:FrontToBack()
    local thread = coroutine.start(function()
        for index, value in ipairs(_itemsList) do
            local cFront = Util.GetGameObject(value, "front")
            cFront.transform:DORotate(Vector3.New(0, 90, 0), 0.3)
            if itemViewList[index] then
                itemViewList[index].transform.rotation = Vector3.zero
            end
        end
        coroutine.wait(0.3)
        for index, value in ipairs(_itemsList) do
            local cBack = Util.GetGameObject(value, "back")
            cBack.transform:DORotate(Vector3.New(0, 0, 0), 0.3)
            if itemViewList[index] then
                itemViewList[index].transform.rotation = Vector3.zero
            end
        end
        coroutine.wait(0.3)
        for index, value in ipairs(_itemsList) do
            value.transform:DOLocalMove(Vector3.New(0,0,0), 0.3)
            if itemViewList[index] then
                itemViewList[index].transform.rotation = Vector3.zero
            end
        end
        coroutine.wait(0.3)
        for index, value in ipairs(_itemsList) do
            value.transform:DOLocalMove(Vector3.New(_itemsPosList[index].x,_itemsPosList[index].y,_itemsPosList[index].z), 0.3)
            if itemViewList[index] then
                itemViewList[index].transform.rotation = Vector3.zero
            end
        end
    end)
end
--把所有卡置为正面
function YiJingBaoKu:ResetCardToFront()
    for index, value in ipairs(_itemsList) do
        local cFront = Util.GetGameObject(value, "front")
        cFront:GetComponent("RectTransform").rotation = Quaternion.Euler(Vector3.New(0, 0, 0))
        if itemViewList[index] then
            itemViewList[index].transform.rotation = Vector3.zero
        end
    end
    for index, value in ipairs(_itemsList) do
        local cBack = Util.GetGameObject(value, "back")
        cBack:GetComponent("RectTransform").rotation = Quaternion.Euler(Vector3.New(0, 90, 0))
        if itemViewList[index] then
            itemViewList[index].transform.rotation = Vector3.zero
        end
    end
end
--把所有卡置为背面
function YiJingBaoKu:ResetCardToBack()
    for index, value in ipairs(_itemsList) do
        local cFront = Util.GetGameObject(value, "front")
        cFront:GetComponent("RectTransform").rotation = Quaternion.Euler(Vector3.New(0, 90, 0))
        if itemViewList[index] then
            itemViewList[index].transform.rotation = Vector3.zero
        end
    end
    for index, value in ipairs(_itemsList) do
        local cBack = Util.GetGameObject(value, "back")
        cBack:GetComponent("RectTransform").rotation = Quaternion.Euler(Vector3.New(0, 0, 0))
        if itemViewList[index] then
            itemViewList[index].transform.rotation = Vector3.zero
        end
    end
end

--时间
function YiJingBaoKu:TimeCountDown()
    local time = ActData.endTime - GetTimeStamp()
    this.time.text = GetLanguageStrById(10028)..TimeToFelaxible(time)
    if this.timer1 then
        this.timer1:Stop()
        this.timer1 = nil
    end
    this.timer1 = Timer.New(function()
        this.time.text = GetLanguageStrById(10028)..TimeToFelaxible(time)

        if time < 1 then
            this.timer1:Stop()
            this.timer1 = nil
            YiJingBaoKu:ClosePanel()
        end
        time = time -1
    end, 1, -1, true)
    this.timer1:Start()
end

function YiJingBaoKu:OnClose()

end

--界面销毁时调用（用于子类重写）
function YiJingBaoKu:OnDestroy()
    _itemsList = {}
    _itemsPosList={}
    itemViewList = {}
    finalReward = nil
end

function YiJingBaoKu:OnHide()
    if this.timer1 then
        this.timer1:Stop()
        this.timer1 = nil
    end
end


return YiJingBaoKu