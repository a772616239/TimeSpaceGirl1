require("Base/BasePanel")
BagPanel = Inherit(BasePanel)
local this = BagPanel
local sortIndex = 0
local sortIndexBtnGo
local tabs1 = {}
local tabs1RedPoint = {}
local itemData = {}
this.isFristOpen = true
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local specialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local motherShipPlaneConfig = ConfigManager.GetConfig(ConfigName.MotherShipPlaneConfig)
local isFristOpenTime = Timer.New()
local orginLayer = 0--层级
local list = {}

--初始化组件（用于子类重写）
function BagPanel:InitComponent()
    this.BtnBack = Util.GetGameObject(self.transform, "rightUp/btnBack")
    for i = 0, 7 do
        tabs1[i] = Util.GetGameObject(self.transform, "box/Grid/Btn" .. i)
        tabs1RedPoint[i] = Util.GetGameObject(self.transform, "box/Grid/Btn" .. i .. "/redPoint")
    end
    this.selectBtn1 = Util.GetGameObject(self.gameObject, "selectBtn")
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)
    this.fenJieBtn = Util.GetGameObject(self.gameObject, "fenJieBtn")
    this.itemNumText = Util.GetGameObject(self.gameObject, "itemNumText")
    this.ItemView = Util.GetGameObject(self.gameObject, "ItemView")
    this.ItemViewEffect = Util.GetGameObject(self.gameObject, "ItemView/GameObject/effects")
    this.item = Util.GetGameObject(self.gameObject, "Item")
    this.grid = Util.GetGameObject(self.gameObject, "scroll/grid")
    this.Scrollbar = Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    this.isBagPanel = true
    this.EffectOrginLayer = 0
    this.mask = Util.GetGameObject(self.gameObject, "mask")

    this.btnBg = Util.GetGameObject(self.gameObject, "btnBg")
    this.allCompound = Util.GetGameObject(self.gameObject, "btnBg/allCompound")

    --无信息图片
    this.noneImage = Util.GetGameObject(self.gameObject,"NoneImage")

    this.Grid = Util.GetGameObject(self.transform, "box/Grid")
end


--绑定事件（用于子类重写）
function BagPanel:BindEvent()
    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    for i = 0, 7 do
        Util.AddClick(tabs1[i], function()
            if this.isFristOpen == false then
                if i == sortIndex then
                    sortIndex = 0
                    this:OnClickAllBtn()
                else
                    sortIndex = i
                    this.OnClickTabBtn(sortIndex, tabs1[sortIndex])
                end
            end
        end)
    end
    Util.AddClick(this.fenJieBtn, function()
        if sortIndex == ItemBaseType.Equip then
            UIManager.OpenPanel(UIName.EquipSellSelectPopup)--宝器
        elseif sortIndex == ItemBaseType.SoulPrint then
            UIManager.OpenPanel(UIName.HeroAndEquipResolvePanel, 4)--魂印
        end
    end)

    -- -- 点击你的猪头
    -- Util.AddClick(this.headPos, function ()
    --     UIManager.OpenPanel(UIName.SettingPanel)
    -- end)

    -- Util.AddClick(this.vipPrivilegeBtn, function()
    --     UIManager.OpenPanel(UIName.VipPanelV2)
    -- end)

    BindRedPointObject(RedPointType.Bag_HeroDebris, tabs1RedPoint[ItemBaseType.HeroChip])
    BindRedPointObject(RedPointType.Bag_BoxAndBlueprint, tabs1RedPoint[ItemBaseType.Special])
    --BindRedPointObject(RedPointType.Setting, this.headRedpot)
    --BindRedPointObject(RedPointType.VipPrivilege, this.vipRedPoint)

    Util.AddClick(this.allCompound, function ()
        if sortIndex == ItemBaseType.HeroChip then
            if not BagManager.GetBagRedPointIsCanCompoundDebris() then
                return
            end
            NetManager.BackpackLimitRequest( function(msg)
                if #HeroManager.GetAllHeroDatasAndZero() >= msg.backpackLimitCount then
                    PopupTipPanel.ShowTip(GetLanguageStrById(10671))
                    return
                end
                UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.FragmentAllCompound, function()
                    NetManager.HeroAllCompoundRequest(function (drop)
                        UIManager.OpenPanel(UIName.RewardItemPopup,drop,1)
                    end)
                end)
            end)
        end
    end)
end

--添加事件监听（用于子类重写）
function BagPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Bag.OnTempBagChanged, this.BagGoldChangeCallBackOnClickTabBtn)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.BagGoldChangeCallBackOnClickTabBtn)
    -- Game.GlobalEvent:AddEvent(GameEvent.Bag.OnRefreshSoulPanelData, this.OnRefreshSoulPanelBagData)
    --Game.GlobalEvent:AddEvent(GameEvent.Player.OnChangeName, this.FreshPlayerInfo)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.OnRefreshRing, this.BagGoldChangeCallBackOnClickTabBtn)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.OnRefreshRune, this.BagGoldChangeCallBackOnClickTabBtn)
end

--移除事件监听（用于子类重写）
function BagPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.OnTempBagChanged, this.BagGoldChangeCallBackOnClickTabBtn)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.BagGoldChangeCallBackOnClickTabBtn)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Bag.OnRefreshSoulPanelData, this.OnRefreshSoulPanelBagData)
    --Game.GlobalEvent:RemoveEvent(GameEvent.Player.OnChangeName, this.FreshPlayerInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.OnRefreshRing, this.BagGoldChangeCallBackOnClickTabBtn)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.OnRefreshRune, this.BagGoldChangeCallBackOnClickTabBtn)
end

--界面打开时调用（用于子类重写）
function BagPanel:OnOpen(_sortIndex, isJumpX)
    sortIndex = 2--注释掉就是记录选择类型
    if _sortIndex then
        sortIndex = _sortIndex
    end

    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })
    this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.BagPanel })

    this.isJumpX = isJumpX or 0
end

--界面打开时调用（用于子类重写）
function BagPanel:OnShow()
    this.sortingOrder = self.sortingOrder
    this.isFristOpen = true
    this.mask:SetActive(true)
    if this.ScrollView then
        this.ScrollView:SetIndex(1)
    end
    if sortIndex > 0 then
        this.OnClickTabBtn(sortIndex, tabs1[sortIndex])
    else
        this:OnClickAllBtn()
    end
    SoundManager.PlayMusic(SoundConfig.BGM_Main)
    BagManager.isBagPanel = true
    this.HeadFrameView:OnShow()

    --this.FreshPlayerInfo()
    --this.SetPlayerHead()
end

local orginLayer
local orginLayer2 = 0
function BagPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.ItemViewEffect, self.sortingOrder - this.EffectOrginLayer)
    --Util.AddParticleSortLayer(this.vipPrivilegeBtn, self.sortingOrder - this.EffectOrginLayer)
    Util.AddParticleSortLayer(this.selectBtn1, self.sortingOrder - this.EffectOrginLayer)
    --特效层级重设
    for i = 1,#list do
        Util.AddParticleSortLayer(list[i], this.sortingOrder - orginLayer)
    end
    orginLayer = this.sortingOrder
    this.EffectOrginLayer = self.sortingOrder
    this.BtView:SetOrderStatus({ sortOrder = self.sortingOrder })
end

--界面关闭时调用（用于子类重写）
function BagPanel:OnClose()
    this.noneImage:SetActive(false)
    BagManager.isBagPanel = false
    if isFristOpenTime then
        isFristOpenTime:Stop()
        isFristOpenTime = nil
    end
end

function this.JumpOnClickTabBtn(_sortIndex)
    sortIndex = _sortIndex
    this.OnClickTabBtn(sortIndex, tabs1[sortIndex])
end

--界面销毁时调用（用于子类重写）
function BagPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.BtView)
    SubUIManager.Close(this.HeadFrameView)
    this.ScrollView = nil
    this.ScrollView1 = nil
    ClearRedPointObject(RedPointType.Bag_HeroDebris, tabs1RedPoint[ItemBaseType.HeroChip])
    ClearRedPointObject(RedPointType.Bag_BoxAndBlueprint, tabs1RedPoint[ItemBaseType.Special])
    --ClearRedPointObject(RedPointType.Setting, this.headRedpot)
    --ClearRedPointObject(RedPointType.VipPrivilege, this.vipRedPoint)
    list = {}
    orginLayer2 = 0
    orginLayer = 0
end

function this:SetSelectBtn(_btn)
    if _btn then
        this.selectBtn1:SetActive(true)
        this.selectBtn1.transform:SetParent(_btn.transform)
        Util.AddParticleSortLayer(this.selectBtn1,this.sortingOrder)
        this.selectBtn1.transform:SetSiblingIndex(1)
        this.selectBtn1.transform.localPosition = Vector3.zero
        Util.GetGameObject(this.selectBtn1.transform, "Text"):GetComponent("Text").text = Util.GetGameObject(_btn.transform, "Text"):GetComponent("Text").text
        Util.GetGameObject(this.selectBtn1.transform, "title"):GetComponent("Image").sprite = Util.GetGameObject(_btn.transform, "title"):GetComponent("Image").sprite
    else
        this.selectBtn1:SetActive(false)
    end
    this.fenJieBtn:SetActive(sortIndex == ItemBaseType.SoulPrint or sortIndex == ItemBaseType.Equip)--装备 
    this.itemNumText:SetActive(sortIndex == ItemBaseType.Equip or sortIndex == ItemBaseType.SoulPrint or sortIndex == ItemBaseType.EquipTreasure)--装备 法宝
end

--点击全部按钮
function this:OnClickAllBtn()
    sortIndex = 0
    this:SetSelectBtn(tabs1[sortIndex])
    sortIndexBtnGo = tabs1[sortIndex]
    itemData = {}
    itemData = this.GetBagItemData()
    local curAllEquipTreasure = EquipTreasureManager.GetAllTreasures()
    for i = 1, #curAllEquipTreasure do
        table.insert(itemData, curAllEquipTreasure[i])
    end
    local soulPrintData = BagManager.GetAllSoulPrintData()
    for i,v in ipairs(soulPrintData) do
       table.insert(itemData, v)
    end

    this:SetItemData(itemData)
    this.noneImage:SetActive(#itemData == 0)

    this.fenJieBtn:GetComponent("Button").enabled = not(#itemData == 0)
    this.btnBg:SetActive(false)
end

function this.BagGoldChangeCallBackOnClickTabBtn()
    this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
end

function this.OnClickTabBtn(_index, _clickBtn)
    sortIndexBtnGo = _clickBtn
    itemData = {}
    local itemNumText = this.itemNumText:GetComponent("Text")
    this:SetSelectBtn(_clickBtn)
    PlaySoundWithoutClick("n1_tab2")
    if _index == ItemBaseType.Equip then
        local allEquipData = BagManager.GetBagItemDataByItemType(ItemBaseType.Equip)
        itemNumText.text = GetLanguageStrById(10188)..LengthOfTable(allEquipData).."/"..ConfigManager.GetConfigData(ConfigName.GameSetting,1).EquipNumlimit
        for i, v in pairs(allEquipData) do
            table.insert(itemData, v)
        end
        this:SetItemData(itemData)
    elseif _index == 0 then
        this:OnClickAllBtn()
    elseif _index == ItemBaseType.SoulPrint then
        itemData = BagManager.GetAllSoulPrintData()
        itemNumText.text = GetLanguageStrById(10189)..#itemData.."/"..specialConfig[9].Value
        this:SetItemData(itemData)
    elseif _index == ItemBaseType.EquipTreasure then
        itemData = EquipTreasureManager.GetAllTreasures()
        itemNumText.text = GetLanguageStrById(10190)..LengthOfTable(itemData).."/"..specialConfig[10].Value
        this:SetItemData(itemData)
    elseif _index == ItemBaseType.Project then
        itemData = CombatPlanManager.GetBagAllDatas()
        itemNumText.text = ""
        this:SetItemData(itemData)
    elseif _index == ItemBaseType.Medal then
        itemData = MedalManager.GetAllMedalData()
        itemNumText.text = ""
        this:SetItemData(itemData)
    elseif _index == ItemBaseType.Gene then
        itemData = AircraftCarrierManager.GetBagAllDatas()
        itemNumText.text = ""
        this:SetItemData(itemData)
    else
        itemData = BagManager.GetBagItemDataByItemType(_index)
        this:SetItemData(itemData)
    end
    this.noneImage:SetActive(#itemData == 0)
    this.fenJieBtn:GetComponent("Button").enabled = not(#itemData == 0)
    this.btnBg:SetActive(_index == ItemBaseType.HeroChip)
    Util.SetGray(this.allCompound, not BagManager.GetBagRedPointIsCanCompoundDebris())

    if this.isJumpX ~= 0 then
        this.Grid.transform.localPosition = Vector3.New(this.isJumpX, this.Grid.transform.localPosition.y, this.Grid.transform.localPosition.z)
    end
end

-- --当魂印升级消耗时刷新背包数据
-- function this.OnRefreshSoulPanelBagData()
--     itemData = SoulPrintManager.soulPrintData
--     this:SetItemData(itemData)
-- end

--设置背包列表数据
function this:SetItemData(_itemDatas)
    list = {}

    -- this.itemList = {}
    this.ItemsSortData(_itemDatas)
    if not this.ScrollView then
        local v2 = Util.GetGameObject(self.gameObject, "scroll"):GetComponent("RectTransform").rect
        this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.transform, "scroll").transform,
                this.ItemView, this.Scrollbar, Vector2.New(-v2.x * 2, -v2.y * 2), 1, 5, Vector2.New(5, 5))
        this.ScrollView.moveTween.MomentumAmount = 1
        this.ScrollView.moveTween.Strength = 2
    end

    this.ScrollView:SetData(_itemDatas, function(index, go)
        -- if this.isFristOpen then
        --     go.gameObject:SetActive(false)
        -- end

        this.SingleItemDataShow(go, _itemDatas[index])
        -- this.itemList[index] = go
        if _itemDatas[index].itemConfig.ItemType == ItemType.HunYin then
            table.insert(list,go)
        end
    end)
    --特效层级重设
    for i = 1,#list do
        Util.AddParticleSortLayer(list[i], this.sortingOrder - orginLayer2)
    end
    orginLayer2 = this.sortingOrder
    orginLayer = this.sortingOrder

    if this.isFristOpen then
        this.ScrollView:ForeachItemGO(function(index, go)
            Timer.New(function()
                go.gameObject:SetActive(true)
                PlayUIAnim(go.gameObject)
            end, 0.01 * (index - 1)):Start()
        end)
        if isFristOpenTime then
            isFristOpenTime:Stop()
            isFristOpenTime = nil
        end
        isFristOpenTime = Timer.New(function()
            this.isFristOpen = false
            this.mask:SetActive(false)
        end, 0.5):Start()
    end

    -- this.DelayCreation(this.itemList)
end

-- --延迟显示List里的item
-- function this.DelayCreation(list,maxIndex)
--     if this._timer ~= nil then
--         this._timer:Stop()
--         this._timer = nil
--     end

--     if this.ScrollView then
--         this.grid = Util.GetGameObject(this.ScrollView.gameObject,"grid").transform
--         for i = 1, this.grid.childCount do
--             if this.grid:GetChild(i-1).gameObject.activeSelf then
--                 this.grid:GetChild(i-1).gameObject:SetActive(false)
--             end
--         end
--     end

--     if list == nil then return end
--     if #list == 0 then return end

--     local time = 0.01
--     local _index = 1

--     if not maxIndex then
--         maxIndex = #list
--     end

--     for i = 1, #list do
--         if list[i].activeSelf then
--             list[i]:SetActive(false)
--         end
--     end

--     local fun = function ()
--         if _index == maxIndex + 1 then
--             if this._timer then
--                 this._timer:Stop()
--             end
--         end
--         list[_index]:SetActive(true)
--         Timer.New(function ()
--             _index = _index + 1
--         end,time):Start()
--     end

--     this._timer = Timer.New(fun,time,maxIndex + 1)
--     this._timer:Start()
-- end

-- --设置魂印循环滚动数据
-- function this:SetSoulPrintData(_go, _itemData)
--     local openBtn = Util.GetGameObject(_go.gameObject, "openBtn")
--     local quality = Util.GetGameObject(_go.gameObject, "itemShow/quality"):GetComponent("Image")
--     local icon = Util.GetGameObject(_go.gameObject, "itemShow/icon"):GetComponent("Image")
--     local name = Util.GetGameObject(_go.gameObject, "itemShow/Image/name"):GetComponent("Text")
--     local level = Util.GetGameObject(_go.gameObject, "itemShow/level"):GetComponent("Text")
--     local propertyText = Util.GetGameObject(_go.gameObject, "propertyText"):GetComponent("Text")
--     local propertyText2 = Util.GetGameObject(_go.gameObject, "propertyText (1)"):GetComponent("Text")
--     quality.sprite = Util.LoadSprite(GetQuantityImageByquality(_itemData.quality))
--     icon.sprite = Util.LoadSprite(_itemData.icon)
--     name.text = GetLanguageStrById(_itemData.name)
--     -- num.gameObject.SetActive(false)
--     level.text = "+" .. _itemData.level
--     propertyText.text = ""
--     propertyText2.text = ""
--     local property = SoulPrintManager.GetShowPropertyData(_itemData.property[1][1], _itemData.property[1][2])
--     propertyText.text = property.name .. property.num
--     if #_itemData.property >= 2 then
--         property = SoulPrintManager.GetShowPropertyData(_itemData.property[2][1], _itemData.property[2][2])
--         propertyText2.text = property.name .. property.num
--     end
--     Util.AddOnceClick(openBtn, function()
--         UIManager.OpenPanel(UIName.SoulPrintPopUp, ShowType.showTip3, _itemData.did, nil, nil, nil)
--     end)
-- end

function this.SingleItemDataShow(go, itemData)
    Util.GetGameObject(go.gameObject, "GameObject/item"):SetActive(true)
    Util.GetGameObject(go.gameObject, "GameObject/item/frame"):GetComponent("Image").sprite = Util.LoadSprite(itemData.frame)
    Util.GetGameObject(go.gameObject, "GameObject/item/icon"):GetComponent("Image").sprite = Util.LoadSprite(itemData.icon)
    Util.GetGameObject(go.gameObject, "GameObject/item/icon"):SetActive(true)
    Util.GetGameObject(go.gameObject, "GameObject/item/circleFrameBg"):SetActive(false)
    Util.GetGameObject(go.gameObject, "GameObject/name"):GetComponent("Text").text = GetLanguageStrById(itemData.itemConfig.Name)

    local upHeroInage = Util.GetGameObject(go.gameObject, "GameObject/item/upHeroInage")
    local UI_Effect_Kuang_JinSe = Util.GetGameObject(go.gameObject, "GameObject/effects/UI_Effect_Kuang_JinSe")
    local UI_Effect_Kuang_HongSe = Util.GetGameObject(go.gameObject, "GameObject/effects/UI_Effect_Kuang_HongSe")
    if UI_Effect_Kuang_JinSe then
        UI_Effect_Kuang_JinSe:SetActive(false)
    end
    if UI_Effect_Kuang_HongSe then
        UI_Effect_Kuang_HongSe:SetActive(false)
    end

    local frameMask = Util.GetGameObject(go.gameObject, "GameObject/item/suipian")
    local num = Util.GetGameObject(go.gameObject, "GameObject/item/num")
    local strongLv = Util.GetGameObject(go.gameObject, "GameObject/item/lv"):GetComponent("Text")
    local refine = Util.GetGameObject(go.gameObject, "GameObject/item/refine"):GetComponent("Text")
    local resetLv = Util.GetGameObject(go.gameObject, "GameObject/item/resetLv")
    local talismanStar = Util.GetGameObject(go.gameObject, "GameObject/item/talismanStar")
    local medalStar = Util.GetGameObject(go.gameObject, "GameObject/item/medalStar")
    local geneLv = Util.GetGameObject(go.gameObject, "GameObject/item/geneLv"):GetComponent("Image")
    frameMask:SetActive(false)
    upHeroInage:SetActive(false)
    num:SetActive(true)
    resetLv:SetActive(false)
    talismanStar:SetActive(false)
    medalStar:SetActive(false)
    strongLv.gameObject:SetActive(false)
    refine.gameObject:SetActive(false)
    geneLv.gameObject:SetActive(false)
    if itemData.itemConfig then
        Util.GetGameObject(go.gameObject, "GameObject/item/innateImage"):SetActive(false)
        Util.GetGameObject(go.gameObject, "GameObject/item/Image_fragmentBG"):SetActive(false)
        num:SetActive(true)
        num:GetComponent("Text").text = itemData.num
        if itemData.itemConfig.ItemType == ItemType.Equip then
            local equipConfig = ConfigManager.GetConfigData(ConfigName.EquipConfig,itemData.itemConfig.Id)
            if equipConfig then
                local equipStarsConfig = ConfigManager.GetConfigData(ConfigName.EquipStarsConfig,equipConfig.Star)
                if equipStarsConfig then
                    talismanStar:SetActive(true)
                    SetHeroStars(talismanStar, equipStarsConfig.Stars)
                    -- UI_Effect_Kuang_JinSe:SetActive(equipStarsConfig.Stars <= 5)
                    -- UI_Effect_Kuang_HongSe:SetActive(equipStarsConfig.Stars > 5)
                end
            end
        elseif itemData.itemConfig.ItemType == ItemType.Pokemon then
            Util.GetGameObject(go.gameObject, "GameObject/item/frame"):GetComponent("Image").sprite = Util.LoadSprite(YaoHunFrame[itemData.quality])
            num:SetActive(false)
        elseif itemData.itemConfig.ItemType == ItemType.HeroDebris then
            frameMask:SetActive(true)
            num:SetActive(false)
            Util.GetGameObject(go.gameObject, "GameObject/item/suipian/exp/Text"):GetComponent("Text").text = BagManager.GetItemCountById(itemData.itemConfig.Id) .. "/" .. itemData.itemConfig.UsePerCount
            local curExpVal = BagManager.GetItemCountById(itemData.itemConfig.Id) / itemData.itemConfig.UsePerCount
            this.expValue = curExpVal >= 1 and 1 or curExpVal
            Util.GetGameObject(go.gameObject, "GameObject/item/suipian/exp"):GetComponent("Slider").value = this.expValue
            talismanStar:SetActive(true)
            SetHeroStars(talismanStar, itemData.itemConfig.Quantity)
            local propertyName = itemConfig[itemData.itemConfig.Id].PropertyName
            if propertyName ~= 0 then
                Util.GetGameObject(go.gameObject, "GameObject/item/Image_fragmentBG"):SetActive(true)
                Util.GetGameObject(go.gameObject, "GameObject/item/Image_fragmentBG"):GetComponent("Image").sprite = Util.LoadSprite(itemData.Image_proBg)
                Util.GetGameObject(go.gameObject, "GameObject/item/Image_fragmentBG/fragmentIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(propertyName))
            end
            -- UI_Effect_Kuang_JinSe:SetActive(_itemData.itemConfig.Quantity <= 5)
            -- UI_Effect_Kuang_HongSe:SetActive(_itemData.itemConfig.Quantity > 5)
        elseif itemData.itemConfig.ItemType == ItemType.TalentItem then
            if itemData.itemConfig.RingLevel > 0 then
                Util.GetGameObject(go.gameObject, "GameObject/item/innateImage"):SetActive(true)
                Util.GetGameObject(go.gameObject, "GameObject/item/innateImage/Text"):GetComponent("Text").text = "+" .. itemData.itemConfig.RingLevel
            else
                Util.GetGameObject(go.gameObject, "GameObject/item/innateImage"):SetActive(false)
                Util.GetGameObject(go.gameObject, "GameObject/item/innateImage/Text"):GetComponent("Text").text = ""
            end
        elseif itemData.itemConfig.ItemType == ItemType.Talisman then
            talismanStar:SetActive(true)
            SetHeroStars(talismanStar, itemData.star)
            num:SetActive(false)
            -- UI_Effect_Kuang_JinSe:SetActive(_itemData.star <= 5)
            -- UI_Effect_Kuang_HongSe:SetActive(_itemData.star > 5)
        elseif itemData.itemConfig.ItemType == ItemType.EquipTreasure then
            num:SetActive(false)
            if itemData.lv > 0 then
                strongLv.gameObject:SetActive(true)
                strongLv.text = itemData.lv
            end
            if itemData.refineLv > 0 then
                refine.gameObject:SetActive(true)
                refine.text = "+" .. itemData.refineLv
            end
            Util.GetGameObject(go.gameObject, "GameObject/item/Image_fragmentBG"):SetActive(true)
            Util.GetGameObject(go.gameObject, "GameObject/item/Image_fragmentBG"):GetComponent("Image").sprite = Util.LoadSprite(itemData.Image_proBg)
            Util.GetGameObject(go.gameObject, "GameObject/item/Image_fragmentBG/fragmentIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(itemConfig[itemData.itemConfig.Id].PropertyName))
            -- UI_Effect_Kuang_JinSe:SetActive(_itemData.star <= 5)
            -- UI_Effect_Kuang_HongSe:SetActive(_itemData.star > 5)
        elseif itemData.itemConfig.ItemType == ItemType.HunYin then
            Util.GetGameObject(go.gameObject, "GameObject/item/resetLv"):SetActive(false)
            Util.GetGameObject(go.gameObject, "GameObject/item/icon"):SetActive(false)
            Util.GetGameObject(go.gameObject, "GameObject/item/circleFrameBg"):SetActive(true)
            Util.GetGameObject(go.gameObject, "GameObject/item/circleFrameBg"):GetComponent("Image").sprite = Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig[itemData.itemConfig.Id].Quantity].circleBg2)
            Util.GetGameObject(go.gameObject, "GameObject/item/circleFrameBg/Icon"):GetComponent("Image").sprite = Util.LoadSprite(itemData.icon)
            Util.GetGameObject(go.gameObject, "GameObject/item/circleFrameBg/circleFrame"):GetComponent("Image").sprite = Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig[itemData.itemConfig.Id].Quantity].circle)
            UI_Effect_Kuang_JinSe.gameObject:SetActive(true)
            num:SetActive(false)
        elseif itemData.itemConfig.ItemType == ItemType.CombatPlan then
            num:SetActive(false)
            -- UI_Effect_Kuang_JinSe:SetActive(_itemData.itemConfig.Quantity <= 5)
            -- UI_Effect_Kuang_HongSe:SetActive(_itemData.itemConfig.Quantity > 5)
        elseif itemData.itemConfig.ItemType == ItemType.medal then
            num:SetActive(false)
            medalStar:SetActive(true)
            local medalConfig = ConfigManager.GetConfigData(ConfigName.MedalConfig, itemData.itemConfig.Id)
            if medalConfig then
                Util.GetGameObject(go.gameObject, "GameObject/item/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.itemConfig.ResourceID))
                --if medalConfig.Star > 1 then
                    -- starNum:SetActive(true)
                    -- starNum:GetComponent("Text").text = medalConfig.Star
                    SetHeroStars(medalStar,medalConfig.Star)
                    -- UI_Effect_Kuang_JinSe:SetActive(medalConfig.Star <= 5)
                    -- UI_Effect_Kuang_HongSe:SetActive(medalConfig.Star > 5)
                --end
            end
        elseif itemData.itemConfig.ItemType == ItemType.Gene then
            geneLv.gameObject:SetActive(true)
            geneLv.sprite = Util.LoadSprite(AircraftCarrierManager.GetSkillLvImgForId(itemData.itemConfig.Id).lvImg)
            num:SetActive(true)
            num:GetComponent("Text").text = itemData.num
        end
    end
    local redPoint = Util.GetGameObject(go.gameObject, "GameObject/redPoint")
    Util.AddOnceClick(Util.GetGameObject(go.gameObject, "GameObject/item/frame"), function()
        if itemData.itemConfig then
            if itemData.itemConfig.ItemBaseType == ItemBaseType.Equip then
                UIManager.OpenPanel(UIName.RewardEquipSingleShowPopup, itemData, function()
                    this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                end,nil,true)
            elseif itemData.itemConfig.ItemType == ItemType.SelfBox then
                UIManager.OpenPanel(UIName.RewardBoxPanel, itemData, function()
                    this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                    UIManager.ClosePanel(UIName.RewardBoxPanel)
                end)
            elseif itemData.itemConfig.ItemBaseType == ItemBaseType.HeroChip then
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemData.id, function()
                    this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                    UIManager.ClosePanel(UIName.RewardItemSingleShowPopup)
                end)
            elseif itemData.itemConfig.ItemType == ItemType.Blueprint then
                local lanTuData = WorkShopManager.GetLanTuIsOpenLock(itemData.itemConfig.Id)
                if lanTuData and lanTuData[1] == true then
                    UIManager.OpenPanel(UIName.WorkShopArmorOnePanel, 2, 2, lanTuData[2], this, function()
                        this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                    end)
                elseif lanTuData and lanTuData[1] == false then
                    UIManager.OpenPanel(UIName.WorkShopArmorOnePanel, 2, 1, lanTuData[2], this, function()
                        this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                    end)
                end
            elseif itemData.itemConfig.ItemType == ItemType.HeroDebris then
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemData.id, function()
                    this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                    UIManager.ClosePanel(UIName.RewardItemSingleShowPopup)
                end)
                --[[
                --角色碎片
                if _itemData.num >= _itemData.itemConfig.UsePerCount then
                    UIManager.OpenPanel(UIName.BagResolveAnCompoundPanel, 3, _itemData, function()
                        this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                    end)
                else
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.id, function()
                        this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                        UIManager.ClosePanel(UIName.RewardItemSingleShowPopup)
                    end)
                end
                ]]
            elseif itemData.itemConfig.ItemBaseType == ItemBaseType.EquipTreasure then
                UIManager.OpenPanel(UIName.RewardTalismanSingleShowPopup, 0, itemData.idDyn, itemData.id, itemData.lv, itemData.refineLv, function()
                    this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                end)
            elseif itemData.itemConfig.ItemBaseType == ItemBaseType.SoulPrint then
                UIManager.OpenPanel(UIName.SoulPrintPopUp, ShowType.showTip3, nil, itemData.id)
            elseif itemData.itemConfig.ItemBaseType == ItemBaseType.Project then
                UIManager.OpenPanel(UIName.CombatPlanTipsPopup, 2, nil, nil, nil, nil, nil, itemData)
            elseif itemData.itemConfig.ItemBaseType == ItemBaseType.Medal then
                UIManager.OpenPanel(UIName.MedalParticularsPopup, itemData, itemData.position, false, nil, true, true)
            elseif itemData.itemConfig.ItemBaseType == ItemType.Rune then
                local nextConfig = AircraftCarrierManager.GetSkillNextIdForConfigId(itemData.itemConfig.Id)
                local type = 1
                if not nextConfig then
                    type = 2
                end
                UIManager.OpenPanel(UIName.LeadGeneTopLevelPanel, itemData.id, itemData.itemConfig.Id, true, type)
            else
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemData.id, function()
                    this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                    UIManager.ClosePanel(UIName.RewardItemSingleShowPopup)
                end)
            end
        end
    end)

    --显示红点
    redPoint:SetActive(false)
    if itemData.itemConfig.ItemType == ItemType.Equip then
        if itemData.itemConfig.Quantity >= 4 then
            redPoint:SetActive(EquipManager.IsNewEquipFrame(itemData.did))
        end
    elseif itemData.itemConfig.ItemType == ItemType.Blueprint then
        local lanTuData = WorkShopManager.GetLanTuIsOpenLock(itemData.itemConfig.Id)
        if lanTuData and lanTuData[1] == false then
            redPoint:SetActive(true)
        end
    elseif itemData.itemConfig.ItemType == ItemType.Box then
        redPoint:SetActive(true)
    elseif itemData.itemConfig.ItemType == ItemType.HeroDebris then
        if this.expValue >= 1 then
            redPoint:SetActive(true)
        end
    end
end

--通过物品类型获取物品数据
function this:GetItemsByItemTpye(_itemType)
    local items = {}
    local index = 1
    for i, v in pairs(BagManager.bagDatas) do
        if v.type == _itemType then
            items[index] = v
            index = index + 1
        end
    end
    return items
end

function this.DelePokemonItemData(_itemDatas)
    local curItemDatas = {}
    --背包特殊处理 sortType=1  sortIndex=5 时显示妖魂  其他页签不显示
    for k, v in pairs(_itemDatas) do
        if sortIndex == ItemBaseType.DemonSoul then
        else
            if v.itemConfig.ItemType == ItemType.Pokemon then
                _itemDatas[k] = nil
            end
        end
    end
    for k, v in pairs(_itemDatas) do
        table.insert(curItemDatas, v)
    end
    return curItemDatas
end

--排序
function this.ItemsSortData(_itemDatas)
    table.sort(_itemDatas, function(a, b)
        if sortIndex == 0 then
            --0全部 1装备 2材料 3消耗 4特殊 5碎片
            if a.itemConfig.ItemBaseType == b.itemConfig.ItemBaseType then
                if a.itemConfig.ItemType == a.itemConfig.ItemType then
                    if a.itemConfig.ItemType == ItemType.Talisman and b.itemConfig.ItemType == ItemType.Talisman then
                        if a.itemConfig.Quantity == b.itemConfig.Quantity then
                            if a.star == b.star then
                                return a.id < b.id
                            else
                                return a.star > b.star
                            end
                        else
                            return a.itemConfig.Quantity > b.itemConfig.Quantity
                        end
                    end
                    if a.itemConfig.ItemType == ItemType.HunYin and b.itemConfig.ItemType == ItemType.HunYin then
                        if a.itemConfig.Quantity == b.itemConfig.Quantity then
                            if a.quality == b.quality then
                                return a.id > b.id
                            else
                                return a.quality > b.quality
                            end
                        else
                            return a.itemConfig.Quantity > b.itemConfig.Quantity
                        end
                    end
                    if a.itemConfig.ItemType == ItemType.EquipTreasure and b.itemConfig.ItemType == ItemType.EquipTreasure then
                        if a.itemConfig.Quantity == b.itemConfig.Quantity then
                            if a.refineLv == b.refineLv then
                                if a.lv == b.lv then
                                    return a.id > b.id
                                else
                                    return a.lv > b.lv
                                end
                            else
                                return a.refineLv > b.refineLv
                            end
                        else
                            return a.itemConfig.Quantity > b.itemConfig.Quantity
                        end
                    end
                    if a.itemConfig.ItemType == ItemType.HeroDebris and b.itemConfig.ItemType == ItemType.HeroDebris then
                        local aNum = BagManager.GetItemCountById(a.itemConfig.Id) >= a.itemConfig.UsePerCount and 2 or 1
                        local bNum = BagManager.GetItemCountById(b.itemConfig.Id) >= b.itemConfig.UsePerCount and 2 or 1
                        if aNum == bNum then
                            if a.itemConfig.Quantity == b.itemConfig.Quantity then
                                if a.itemConfig.PropertyName == b.itemConfig.PropertyName then
                                    return a.id < b.id
                                else
                                    return a.itemConfig.PropertyName < b.itemConfig.PropertyName
                                end
                            else
                                return a.itemConfig.Quantity > b.itemConfig.Quantity
                            end
                        else
                            return aNum > bNum
                        end
                    end
                else
                    return a.itemConfig.ItemType < b.itemConfig.ItemType
                end
            else
                return a.itemConfig.ItemBaseType < b.itemConfig.ItemBaseType
            end
        elseif sortIndex == ItemBaseType.Equip or sortIndex == ItemBaseType.Materials or sortIndex == ItemBaseType.Special then
            if a.itemConfig.Quantity == b.itemConfig.Quantity then
                if a.itemConfig.ItemType == b.itemConfig.ItemType then
                    return a.id > b.id
                else
                    return a.itemConfig.ItemType < b.itemConfig.ItemType
                end
            else
                return a.itemConfig.Quantity > b.itemConfig.Quantity
            end
        elseif sortIndex == ItemBaseType.HeroChip then
            local aNum = BagManager.GetItemCountById(a.itemConfig.Id) >= a.itemConfig.UsePerCount and 2 or 1
            local bNum = BagManager.GetItemCountById(b.itemConfig.Id) >= b.itemConfig.UsePerCount and 2 or 1
            if aNum == bNum then
                if a.itemConfig.Quantity == b.itemConfig.Quantity then
                    if a.itemConfig.PropertyName == b.itemConfig.PropertyName then
                        return a.id < b.id
                    else
                        return a.itemConfig.PropertyName < b.itemConfig.PropertyName
                    end
                else
                    return a.itemConfig.Quantity > b.itemConfig.Quantity
                end
            else
                return aNum > bNum
            end
        elseif sortIndex == ItemBaseType.Project then
            return a.quality > b.quality
        elseif sortIndex == ItemBaseType.Medal then
            if a.medalConfig.Quality == b.medalConfig.Quality then
                return  a.medalConfig.Star > b.medalConfig.Star
            else
                return a.medalConfig.Quality > b.medalConfig.Quality
            end

        elseif sortIndex == ItemBaseType.DemonSoul then
            local aNum = BagManager.GetItemCountById(a.itemConfig.Id) >= a.itemConfig.UsePerCount and 2 or 1
            local bNum = BagManager.GetItemCountById(b.itemConfig.Id) >= b.itemConfig.UsePerCount and 2 or 1
            if aNum == bNum then
                if a.itemConfig.Quantity == b.itemConfig.Quantity then
                    if a.itemConfig.ItemType == b.itemConfig.ItemType then
                        return a.id > b.id
                    else
                        return a.itemConfig.ItemType < b.itemConfig.ItemType
                    end
                else
                    return a.itemConfig.Quantity > b.itemConfig.Quantity
                end
            else
                return aNum > bNum
            end
        elseif sortIndex == ItemBaseType.SoulPrint then
            if a.quality == b.quality then
                return a.id > b.id
            else
                return a.quality > b.quality
            end
        elseif sortIndex == ItemBaseType.EquipTreasure then
            if a.itemConfig.Quantity == b.itemConfig.Quantity then
                if a.refineLv == b.refineLv then
                    if a.lv == b.lv then
                        return a.id > b.id
                    else
                        return a.lv > b.lv
                    end
                else
                    return a.refineLv > b.refineLv
                end
            else
                return a.itemConfig.Quantity > b.itemConfig.Quantity
            end
        elseif sortIndex == ItemBaseType.Gene then
            local aConfig = motherShipPlaneConfig[a.itemConfig.Id]
            local bConfig = motherShipPlaneConfig[b.itemConfig.Id]
            if aConfig.Type > bConfig.Type then
                return true
            elseif aConfig.Type == bConfig.Type then
                if aConfig.Lvl > bConfig.Lvl then
                    return true
                elseif aConfig.Lvl == bConfig.Lvl then
                    return a.itemConfig.Id < b.itemConfig.Id
                end
            end
            return false
        end
    end)
end

--获取所有背包物品
function this.GetBagItemData()
    local _index = 1
    local _bagItemData = {}
    for i, v in pairs(BagManager.bagDatas) do
        if v.isBag and v.num > 0 and v.itemConfig.ItemType ~= ItemType.Pokemon and v.itemConfig.ItemType ~= ItemType.HunYin then
            --进背包  数量大于零的  不是异妖部件
            _bagItemData[_index] = v
            _index = _index + 1
        end
    end
    return _bagItemData
end

--跳转显示新手提示圈
function this.ShowGuideGo()
    local item1Btn = Util.GetGameObject(this.transform, "scroll/ScrollCycleView/grid/item1")
    if item1Btn then
        JumpManager.ShowGuide(UIName.BagPanel, item1Btn)
    end
end

return BagPanel