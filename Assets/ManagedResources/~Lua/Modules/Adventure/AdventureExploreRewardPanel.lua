require("Base/BasePanel")
AdventureExploreRewardPanel = Inherit(BasePanel)
local this=AdventureExploreRewardPanel
local baseDrop={}
local randomDrop={}
local randomList = {}
local itemListPrefab={}
local isOpenGeiSSRAvtivity = 0--五星成长礼拍脸
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
this.userLevelData = ConfigManager.GetConfig(ConfigName.PlayerLevelConfig)
this.selfsortingOrder = 0
--初始化组件（用于子类重写）
function AdventureExploreRewardPanel:InitComponent()
    this.backMask = Util.GetGameObject(self.gameObject, "maskImage")
    this.btnBack = Util.GetGameObject(self.gameObject, "closeBtn")
    this.rewardGrid = Util.GetGameObject(self.gameObject, "top/grid")
    this.randomDropGrid = Util.GetGameObject(self.gameObject, "Bg/scroll/grid")
    this.vipAddShow1 = Util.GetGameObject(self.gameObject, "Bg/top/vipAddShow1")
    this.vipAddShow2 = Util.GetGameObject(self.gameObject, "Bg/top/vipAddShow2")
    this.vipAddShowText1=Util.GetGameObject(self.gameObject, "Bg/top/vipAddShow1/vipAddShow1Text"):GetComponent("Text")
    this.vipAddShowText2=Util.GetGameObject(self.gameObject, "Bg/top/vipAddShow2/vipAddShow2Text"):GetComponent("Text")
    this.hangOnTime = Util.GetGameObject(self.gameObject, "Bg/hangOnTime"):GetComponent("Text")

    this.topItem = Util.GetGameObject(self.gameObject, "Bg/topItem")
    this.gradeValue = Util.GetGameObject(self.gameObject, "Bg/toptop/grade/gradeValue")
    this.expValue = Util.GetGameObject(self.gameObject, "Bg/toptop/exp"):GetComponent("Slider")
    this.expValueText = Util.GetGameObject(self.gameObject, "Bg/toptop/exp/jindu"):GetComponent("Text")

    this.UpLvSign = Util.GetGameObject(self.gameObject, "Bg/toptop/UpLvSign")

    this.headicon = Util.GetGameObject(self.gameObject, "Bg/toptop/headPart/headicon"):GetComponent("Image")
    this.headframe = Util.GetGameObject(self.gameObject, "Bg/toptop/headPart/headframe"):GetComponent("Image")
end

--绑定事件（用于子类重写）
function AdventureExploreRewardPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
		PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.backMask, function()
		PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end) --N1
end
--添加事件监听（用于子类重写） 
function AdventureExploreRewardPanel:AddListener()

end

--移除事件监听（用于子类重写）
function AdventureExploreRewardPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function AdventureExploreRewardPanel:OnOpen(...)
    this.selfsortingOrder = self.sortingOrder
    local args = {...}
    baseDrop = args[1]
    randomDrop = args[2]
    local itemDataList = {}
    local baseContentList1 = {}
    local callList1 = Stack.New()
    itemDataList = BagManager.GetTableByBackDropData(baseDrop)
    BagManager.GoIntoBackData(baseDrop)
    --固定掉落
    -- for i = 1, #itemDataList do
    --     local view
    --     if not baseContentList[i] then
    --         view = SubUIManager.Open(SubUIConfig.ItemView,this.rewardGrid.transform)
    --         baseContentList[i] = view
    --     end
    --     baseContentList[i]:OnOpen(true,itemDataList[i],1,true,false,false,this.selfsortingOrder)
    -- end
    if this.rewardGrid.transform.childCount > 0 then
        Util.ClearChild(this.rewardGrid.transform)
    end
    self:SetTopItemShow(baseDrop,itemDataList,this.rewardGrid.transform,callList1,baseContentList1)
  
    --随机掉落
    if randomDrop ~= nil then
        local callList2 = Stack.New()
        local itemRandomDataList = {}
        local baseContentList2 = {}
        itemRandomDataList = BagManager.GetTableByBackDropData(randomDrop)
        
        --> 方案显示叠加
        local planDatas = {}
        for i = #itemRandomDataList, 1, -1 do
            if itemRandomDataList[i].itemType == 6 then
                if planDatas[itemRandomDataList[i].sId] then
                    planDatas[itemRandomDataList[i].sId].num = planDatas[itemRandomDataList[i].sId].num + 1
                else
                    planDatas[itemRandomDataList[i].sId] = itemRandomDataList[i]
                end
                table.remove(itemRandomDataList, i)
            end
        end
        for k, v in pairs(planDatas) do
            table.insert(itemRandomDataList, v)
        end

        -- 按品质排序
        if #itemRandomDataList > 1 then
            table.sort(itemRandomDataList, function(a, b)
                return a.configData.Quantity > b.configData.Quantity
            end)
        end

        BagManager.GoIntoBackData(randomDrop)
        -- for i = 1, #itemRandomDataList do
        --     if not randomList[i] then 
        --         local view = SubUIManager.Open(SubUIConfig.ItemView,this.randomDropGrid.transform)
        --         randomList[i] = view
        --     end
        --     randomList[i]:OnOpen(true,itemDataList[i], 1.1, true)
        -- end
        self:SetItemShow(randomDrop, itemRandomDataList, this.randomDropGrid.transform, callList2,baseContentList2)
    end
    local hours = AdventureManager.adventureOffline  --gameSetting[1].AdventureOffline
    local time = AdventureManager.stateTime >= hours * 60 * 60 and hours * 60 * 60 or AdventureManager.stateTime
    this.hangOnTime.text = GetLanguageStrById(10044) .. TimeToHMS(time)

    this.gradeValue:GetComponent("Text").text = PlayerManager.level
    this.expValue.value = PlayerManager.exp / PlayerManager.userLevelData[PlayerManager.level].Exp
    this.expValueText.text = PlayerManager.exp .. "/" .. PlayerManager.userLevelData[PlayerManager.level].Exp

    if PlayerManager.level > FightPointPassManager.oldLevel then
        this.UpLvSign:SetActive(true)
    else
        this.UpLvSign:SetActive(false)
    end

    this.headicon.sprite = GetPlayerHeadSprite(PlayerManager.head)
    this.headframe.sprite = GetPlayerHeadFrameSprite(PlayerManager.frame)
end

-- 根据物品列表数据显示物品
function  AdventureExploreRewardPanel:SetItemShow(drop,dataList,transform,callList,baseContentList)
    BagManager.OnShowTipDropNumZero(drop)
    if drop == nil then return end
    for i = 1, #dataList do
        dataList[i].itemConfig = itemConfig[dataList[i].sId]
    end
    self:ItemDataListSort(dataList)
    for i = 1, math.max(#dataList, #baseContentList) do
        local go = baseContentList[i]
        if not go then
            go = SubUIManager.Open(SubUIConfig.ItemView, transform)
            go.gameObject.name = "frame"..i
            baseContentList[i] = go
        end
        go.gameObject:SetActive(false)
    end

    callList:Clear()
    callList:Push(function ()
        if isOpenGeiSSRAvtivityTime then
            isOpenGeiSSRAvtivityTime:Stop()
            isOpenGeiSSRAvtivityTime = nil
        end
        isOpenGeiSSRAvtivityTime = Timer.New(function ()
            isPlayerAniEnd = true
            if isOpenGeiSSRAvtivity > 0 then
                HeroManager.DetectionOpenFiveStarActivity(isOpenGeiSSRAvtivity)
            end
        end, 0.5):Start()
        --在关卡界面获得装备 刷新下btview成员红点
        -- Game.GlobalEvent:DispatchEvent(GameEvent.Equip.EquipChange)
    end)
    for i = #dataList, 1, -1 do
        isPlayerAniEnd = false
        local view = baseContentList[i]
        local curItemData = dataList[i]
        view:OnOpen(true,curItemData,0.8,false,true,false,self.sortingOrder)
        --view.gameObject:SetActive(false)
        callList:Push(function ()
            local func = function()
                view.gameObject:SetActive(true)
                local btn = Util.GetGameObject(view.gameObject, "item/frame"):GetComponent("Button")
                btn.enabled = false
                PlayUIAnim(view.gameObject, function()
                    btn.enabled = true
                end)
                --改为后端更新
                --this.SetItemData2(itemDataList[i])
                Timer.New(function ()
                    isPopGetSSR = false
                    callList:Pop()()
                end, 0.05):Start()
            end
            if curItemData.configData and curItemData.itemType == 3 and curItemData.configData.Quality == 5 then
                isPopGetSSR = true
                isOpenGeiSSRAvtivity = curItemData.configData.Star
                -- UIManager.OpenPanel(UIName.DropGetSSRHeroShopPanel,curItemData.backData, func)
            elseif curItemData.configData and curItemData.itemType == 1 and
                    (curItemData.configData.ItemType == ItemType.Title or curItemData.configData.ItemType == ItemType.Ride or
                            curItemData.configData.ItemType == ItemType.Skin) then--皮肤 坐骑
                isPopGetSSR = true
                UIManager.OpenPanel(UIName.DropGetPlayerDecorateShopPanel,curItemData.backData, func)
            else
                func()
            end
        end)
    end
    callList:Pop()()
end

--> top set
function  AdventureExploreRewardPanel:SetTopItemShow(drop,dataList,transform,callList,baseContentList)
    BagManager.OnShowTipDropNumZero(drop)
    if drop == nil then return end
    for i = 1, #dataList do
        dataList[i].itemConfig = itemConfig[dataList[i].sId]
    end
    self:ItemDataListSort(dataList)
    for i = 1, math.max(#dataList, #baseContentList) do
        local go = baseContentList[i]
        if not go then
            go = newObject(self.topItem)
            go.transform:SetParent(transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go.gameObject.name = "frame"..i
            baseContentList[i] = go
        end
        go.gameObject:SetActive(false)
    end

    callList:Clear()
    callList:Push(function ()
        if isOpenGeiSSRAvtivityTime then
            isOpenGeiSSRAvtivityTime:Stop()
            isOpenGeiSSRAvtivityTime = nil
        end
        isOpenGeiSSRAvtivityTime = Timer.New(function ()
            isPlayerAniEnd = true
            if isOpenGeiSSRAvtivity > 0 then
                HeroManager.DetectionOpenFiveStarActivity(isOpenGeiSSRAvtivity)
            end
        end, 0.5):Start()
        --在关卡界面获得装备 刷新下btview成员红点
        -- Game.GlobalEvent:DispatchEvent(GameEvent.Equip.EquipChange)
    end)
    
    for i = #dataList, 1, -1 do
        isPlayerAniEnd = false
        local view = baseContentList[i]
        local curItemData = dataList[i]

        Util.GetGameObject(view, "item"):GetComponent("Image").sprite = Util.LoadSprite(curItemData.icon)
        Util.GetGameObject(view, "name"):GetComponent("Text").text = GetLanguageStrById(curItemData.configData.Name)
        Util.GetGameObject(view, "num"):GetComponent("Text").text = curItemData.num
        --view.gameObject:SetActive(false)
        callList:Push(function ()
            local func = function()
                view.gameObject:SetActive(true)
                -- local btn = Util.GetGameObject(view.gameObject, "item/frame"):GetComponent("Button")
                -- btn.enabled = false
                PlayUIAnim(view.gameObject, function()
                    -- btn.enabled = true
                end)
                --改为后端更新
                --this.SetItemData2(itemDataList[i])
                Timer.New(function ()
                    isPopGetSSR = false
                    callList:Pop()()
                end, 0.05):Start()
            end
            if curItemData.configData and curItemData.itemType == 3 and curItemData.configData.Quality == 5 then
                isPopGetSSR = true
                isOpenGeiSSRAvtivity = curItemData.configData.Star
                -- UIManager.OpenPanel(UIName.DropGetSSRHeroShopPanel,curItemData.backData, func)
            elseif curItemData.configData and curItemData.itemType==1 and
                    (curItemData.configData.ItemType == ItemType.Title or curItemData.configData.ItemType == ItemType.Ride or
                            curItemData.configData.ItemType == ItemType.Skin) then--皮肤 坐骑
                isPopGetSSR = true
                UIManager.OpenPanel(UIName.DropGetPlayerDecorateShopPanel,curItemData.backData, func)
            else
                func()
            end
        end)
    end
    callList:Pop()()
end

--掉落物品排序
function AdventureExploreRewardPanel:ItemDataListSort(itemDataList)
    table.sort(itemDataList, function(a, b)
        if a.itemConfig.Quantity == b.itemConfig.Quantity then
            if a.itemConfig.ItemType == b.itemConfig.ItemType then
               return a.itemConfig.Id < b.itemConfig.Id
            else
                return a.itemConfig.ItemType < b.itemConfig.ItemType
            end
        else
           return a.itemConfig.Quantity > b.itemConfig.Quantity
        end
    end)
end

--界面关闭时调用（用于子类重写）
function AdventureExploreRewardPanel:OnClose()
    FightPointPassManager.isBeginFight = false
    if FightPointPassManager.oldLevel<PlayerManager.level then
            UIManager.OpenPanel(UIName.FightEndLvUpPanel,FightPointPassManager.oldLevel,PlayerManager.level)
    end
end

--界面销毁时调用（用于子类重写）
function AdventureExploreRewardPanel:OnDestroy()

    randomList = {}
end

return AdventureExploreRewardPanel