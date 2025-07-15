local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
ItemView = {}
function ItemView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b, { __index = ItemView })
    return b
end

--初始化组件（用于子类重写）
function ItemView:InitComponent()
    self.btn = Util.GetGameObject(self.gameObject, "item/frame")
    --框
    self.frame = Util.GetGameObject(self.gameObject, "item/frame"):GetComponent("Image")
    --
    self.icon = Util.GetGameObject(self.gameObject, "item/icon"):GetComponent("Image")
    --
    self.frameMask = Util.GetGameObject(self.gameObject, "item/frameMask")
    --属性
    self.pro = Util.GetGameObject(self.gameObject, "item/pro"):GetComponent("Image")
    self.proIcon = Util.GetGameObject(self.gameObject, "item/pro/icon"):GetComponent("Image")
    --星级
    self.starGrid = Util.GetGameObject(self.gameObject, "item/starGrid")
    --数量
    self.num = Util.GetGameObject(self.gameObject, "item/num"):GetComponent("Text")
    self.add = Util.GetGameObject(self.gameObject, "item/add")
    --名字
    self.name = Util.GetGameObject(self.gameObject, "name"):GetComponent("Text")
    --红点
    self.redPoint = Util.GetGameObject(self.gameObject, "redPoint")

    self.EffectOrginLayer = 0
    self.EffectOrginLayerQu = 0
    self.EffectOrginScale = 1
    self.EffectOrginScaleQu = 1

    self.effects = Util.GetGameObject(self.gameObject, "effects")
    -- 角标
    self.Corner = Util.GetGameObject(self.gameObject, "Corner")
    --基因等级
    self.geneLv = Util.GetGameObject(self.gameObject, "geneLv"):GetComponent("Image")
end

function ItemView:ToEffect(num)
end

--绑定事件（用于子类重写）
function ItemView:BindEvent()
end

--添加事件监听（用于子类重写）
function ItemView:AddListener()
end

--移除事件监听（用于子类重写）
function ItemView:RemoveListener()
end

--isGet 是否获得
--itemDatas 数据
--scale 缩放值
--isShowName 是否显示名字（默认不显示）
--isShowAddImage 是否显示道具不足加号（默认不显示）
--isPlayAnim 是否播放获得动画（默认不播）
--effectLayer 当前界面层级（显示粒子特效用）
--界面打开时调用（用于子类重写）
function ItemView:OnOpen(isGet, itemDatas, _scale, isShowName, isShowAddImage, isPlayAnim, effectLayer, cornerType)
    isShowName = isShowName or false
    isShowAddImage = isShowAddImage or false
    isPlayAnim = isPlayAnim or false
    effectLayer = effectLayer or 0

    self.EffectOrginLayerQu = effectLayer
    self.name.gameObject:SetActive(isShowName)
    self.add:SetActive(isShowAddImage)
    self.gameObject:GetComponent("PlayFlyAnim").enabled = isPlayAnim
    self.scale = _scale or 1
    --self.gameObject:GetComponent("RectTransform").localScale = Vector2.New(scale, scale)
    self.gameObject:GetComponent("RectTransform").sizeDelta = Vector2.New(193, 202)

    if isGet and itemDatas then
        _Quantity = itemDatas.configData.Quantity
        self:GetRewardShow(itemDatas, effectLayer)
    elseif isGet == false and itemDatas then
        _Quantity = ConfigManager.GetConfigData(ConfigName.ItemConfig, tonumber(itemDatas[1])).Quantity
        self:NoGetRewardShow(itemDatas, effectLayer, isShowAddImage)
    end

    -- self.Corner:SetActive(not not cornerType)
    -- self:SetCorner(cornerType)

    self.effect_saoguang = Util.GetGameObject(self.effects, "UI_effect_ItemView_saoguang(Clone)")
    if self.effect_saoguang then
        self.effect_saoguang:SetActive(false)
    end

    self.effect_hongse = self:SetEffect("UI_Effect_Kuang_HongSe", 5)
    self.effect_jinse = self:SetEffect("UI_Effect_Kuang_JinSe", 6)
    self.effect_kuang = self:SetEffect("UI_effect_WuCai_Kuang", 7)
end

function ItemView:GetRewardShow(_itemData, effectLayer)
    -- self.isRewardItemPop = true
    self.starGrid:SetActive(false)
    self.redPoint:SetActive(false)
    self.add:SetActive(false)
    self.frameMask:SetActive(false)
    self.pro.gameObject:SetActive(false)
    self.num.gameObject:SetActive(true)
    self.geneLv.gameObject:SetActive(false)

    -- if _itemData.Image_proBg ~= nil then
    --     self.pro.gameObject:SetActive(true)
    --     self.pro.sprite = Util.LoadSprite(_itemData.Image_proBg)
    -- end
    self.frame.sprite = Util.LoadSprite(_itemData.frame)
    self.icon.sprite = Util.LoadSprite(_itemData.icon)
    self.num.text = PrintWanNum(_itemData.num)
    self.name.text = GetLanguageStrById(_itemData.name)

    self.EffectOrginScale = self.scale

    local itemType = {
        NoType = 0,
        NoType_1 = 1,
        Equip = 2,  --装备
        Hero = 3,   --英雄
        Weapon = 4, --法宝
        Jewel = 5,
        Reward = 6,
        Medal = 7,
        Gene = 8,
        Title = 9,  --称号
    }

    if _itemData.itemType == itemType.NoType or _itemData.itemType == itemType.NoType_1 then
        if _itemData.configData == nil then
            _itemData.configData = _itemData.itemConfig
            _itemData.backData = _itemData.itembackData
        end
        if _itemData.configData.ItemType == ItemType.HeroDebris then
            self.frameMask:SetActive(true)
            self.pro.gameObject:SetActive(true)
            self.frameMask:GetComponent("Image").sprite = Util.LoadSprite(GetHeroChipQuantityImageByquality(_itemData.configData.Quantity))
            self.pro.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(_itemData.configData.Quantity))
            self.proIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(_itemData.configData.PropertyName))
            
            Util.AddOnceClick(self.btn, function()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.backData.itemId,nil,self.isRewardItemPop)
            end)
        elseif _itemData.configData.ItemType == ItemType.Pokemon then
            Util.AddOnceClick(self.btn, function()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.backData.itemId,nil,self.isRewardItemPop)
            end)
        elseif _itemData.configData.ItemType == ItemType.TalentItem then
            Util.AddOnceClick(self.btn, function()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.backData.itemId,nil,self.isRewardItemPop)
            end)
        elseif _itemData.configData.ItemType == ItemType.Equip then
            self.num.gameObject:SetActive(_itemData.num > 1)
            self.starGrid:SetActive(true)

            self.num.text = _itemData.num
            self.name.text = GetLanguageStrById(_itemData.configData.Name)
            EquipManager.SetEquipStarShow(self.starGrid, _itemData.configData.Id)

            Util.AddOnceClick(self.btn, function()
                _itemData.id = _itemData.configData.Id
                UIManager.OpenPanel(UIName.RewardEquipSingleShowPopup, _itemData,nil,self.isRewardItemPop)
            end)
        elseif _itemData.configData.ItemType == ItemType.Blueprint then
            local lanTuData = WorkShopManager.GetLanTuIsOpenLock(_itemData.backData.itemId)
            if lanTuData then
                Util.AddOnceClick(self.btn, function()
                    UIManager.OpenPanel(UIName.WorkShopArmorOnePanel,3,3, lanTuData[2])
                end)
            end
        elseif _itemData.configData.ItemType == ItemType.HunYin then
            Util.AddOnceClick(self.btn, function()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.backData.itemId,nil,self.isRewardItemPop)
            end)
        elseif _itemData.configData.itemType == ItemType.CombatPlan then
            Util.AddOnceClick(self.btn, function()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.configData.Id,nil,self.isRewardItemPop)
            end)
        elseif _itemData.configData.itemType == ItemType.medal then
            self.starGrid:SetActive(true)

            local medalItem = ConfigManager.GetConfigData("MedalConfig", _itemData.configData.Id)
            local star = medalItem.Star
            SetHeroStars(self.starGrid, star)
            self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[_itemData.configData.Id].Quantity))
            self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[_itemData.configData.Id].ResourceID))

            Util.AddOnceClick(self.btn, function()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.configData.Id,nil,self.isRewardItemPop)
            end)
        else
            Util.AddOnceClick(self.btn, function()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.backData.itemId,nil,self.isRewardItemPop)
            end)
        end
    elseif _itemData.itemType == itemType.Equip then
        self.num.gameObject:SetActive(_itemData.num > 1)
        self.starGrid:SetActive(true)

        self.num.text = _itemData.num
        self.name.text = GetLanguageStrById(_itemData.configData.Name)
        EquipManager.SetEquipStarShow(self.starGrid, _itemData.configData.Id)
        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardEquipSingleShowPopup, _itemData.backData,nil,self.isRewardItemPop)
        end)
    elseif _itemData.itemType == itemType.Hero then
        self.pro.gameObject:SetActive(true)
        self.num.gameObject:SetActive(false)
        self.starGrid:SetActive(true)

        self.name:GetComponent("Text").text = GetLanguageStrById(_itemData.configData.ReadingName)
        self.pro.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(_itemData.configData.Quality, _itemData.configData.Star))
        self.proIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(_itemData.configData.PropertyName))
        SetHeroStars(self.starGrid, _itemData.backData.star)
        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RoleGetInfoPopup, true, _itemData.backData)
        end)
    elseif _itemData.itemType == itemType.Weapon then
        self.num.gameObject:SetActive(false)
        self.starGrid:SetActive(true)

        self.name:GetComponent("Text").text = GetLanguageStrById(_itemData.name)
        SetHeroStars(self.starGrid, _itemData.backData.rebuildLevel)
        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardTalismanSingleShowPopup,2,_itemData.backData.id,_itemData.backData.equipId,_itemData.backData.exp,_itemData.backData.rebuildLevel)
        end)
    elseif _itemData.itemType == itemType.Jewel then
        self.num.gameObject:SetActive(false)
        
        self.name:GetComponent("Text").text = GetLanguageStrById(_itemData.name)
        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardTalismanSingleShowPopup, 0, _itemData.backData.id,_itemData.backData.equipId, 0,0)
        end)
    elseif _itemData.itemType == itemType.Reward then
        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.configData.Id,nil,self.isRewardItemPop)
        end)
    elseif _itemData.itemType == itemType.Medal then
        if _itemData.configData.ItemType == ItemType.medal then
            self.starGrid:SetActive(true)
            self.pro.gameObject:SetActive(false)

            local medalItem = ConfigManager.GetConfigData("MedalConfig", _itemData.configData.Id)
            local star = medalItem.Star
            SetHeroStars(self.starGrid, star)
            self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[_itemData.configData.Id].Quantity))
            self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[_itemData.configData.Id].ResourceID))
        end
        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.configData.Id,nil,self.isRewardItemPop)
        end)
    elseif _itemData.itemType == itemType.Title then
        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.configData.Id, nil, self.isRewardItemPop)
        end)
    elseif _itemData.itemType == itemType.Gene then
        self.geneLv.gameObject:SetActive(true)
        self.geneLv.sprite = Util.LoadSprite(AircraftCarrierManager.GetSkillLvImgForId(_itemData.configData.Id).lvImg)
        Util.AddOnceClick(self.btn, function()
            -- UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, _itemData.configData.Id, nil, self.isRewardItemPop)
            UIManager.OpenPanel(UIName.LeadGeneTopLevelPanel, nil, _itemData.configData.Id, false)
        end)
    end
    self.gameObject:GetComponent("RectTransform").localScale = Vector2.New(self.scale, self.scale)
end

function ItemView:SetEffectLayer(effectLayer)
    self.EffectOrginLayerQu = effectLayer
end

function ItemView:NoGetRewardShow(_reward, effectLayer, isShowAddImage)
    self.isRewardItemPop = false
    self.starGrid:SetActive(false)
    self.redPoint:SetActive(false)
    self.frameMask:SetActive(false)
    self.pro.gameObject:SetActive(false)
    self.num.gameObject:SetActive(true)
    self.geneLv.gameObject:SetActive(false)

    local itemSId = tonumber(_reward[1])
    local itemNum = tonumber(_reward[2]) or 0
    local isShowPrecious = _reward[3] or 0
    local itemDataConFig = ConfigManager.GetConfigData(ConfigName.ItemConfig, itemSId)

    self.name.text = GetLanguageStrById(itemDataConFig.Name)
    self.EffectOrginScale = self.scale

    if itemDataConFig.ItemType == ItemType.NoType then
        self.num.text = PrintWanNum(itemNum)
        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))
        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemSId, nil, self.isRewardItemPop)
        end)
    elseif itemDataConFig.ItemType == ItemType.Hero then
        self.starGrid:SetActive(true)
        self.num.gameObject:SetActive(itemNum > 1)
        self.pro.gameObject:SetActive(true)

        local heroConfigData = ConfigManager.GetConfigData(ConfigName.HeroConfig, itemConfig[itemSId].HeroStar[1])
        self.num.text = PrintWanNum(itemNum)
        local star = _reward[4] or itemConfig[itemSId].HeroStar[2]      --获取星级
        SetHeroStars(self.starGrid, star)
        self.frame.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(itemConfig[itemSId].Quantity))
        if itemSId == 20000 then   --高级回溯背景问题
            self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(nil,star))
        end
       
        self.icon.sprite = Util.LoadSprite(GetResourcePath(heroConfigData.Icon))
        self.name:GetComponent("Text").text = GetLanguageStrById(heroConfigData.ReadingName)
        self.pro.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(itemConfig[itemSId].Quantity))
        self.proIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfigData.PropertyName))

        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroConfigData.Id,star)
        end)
    elseif itemDataConFig.ItemType == ItemType.HeroDebris then
        self.frameMask:SetActive(true)
        self.starGrid:SetActive(true)
        --催化精粹做特殊处理不显示pro
        if itemConfig[itemSId].PropertyName == 0 then
            self.pro.gameObject:SetActive(false)
        else
            self.pro.gameObject:SetActive(true)
        end

        self.frameMask:GetComponent("Image").sprite = Util.LoadSprite(GetHeroChipQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))
        self.pro.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(itemConfig[itemSId].Quantity))
        self.proIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(itemConfig[itemSId].PropertyName))
        local star  = itemConfig[itemSId].Quantity
        SetHeroStars(self.starGrid, star)

        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemSId,nil,self.isRewardItemPop)
        end)
    elseif itemDataConFig.ItemType == ItemType.Equip then
        self.starGrid:SetActive(true)
        self.num.gameObject:SetActive(itemNum and itemNum > 0)

        self.num.text = PrintWanNum(itemNum and itemNum or 0)
        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))
        EquipManager.SetEquipStarShow(self.starGrid,itemSId)

        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.HandBookEquipInfoPanel, itemSId)
        end)
    elseif itemDataConFig.ItemType == ItemType.Pokemon then
        self.frame.sprite = Util.LoadSprite(YaoHunFrame[itemConfig[itemSId].Quantity])
        self.icon.sprite =  Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))

        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemSId,nil,self.isRewardItemPop)
        end)
    elseif itemDataConFig.ItemType == ItemType.Blueprint then
        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))

        local lanTuData = WorkShopManager.GetLanTuIsOpenLock(itemSId)
        if lanTuData then
            Util.AddOnceClick(self.btn, function()
                UIManager.OpenPanel(UIName.WorkShopArmorOnePanel,3,3, lanTuData[2])
            end)
        end
    elseif itemDataConFig.ItemType == ItemType.TalentItem then
        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))

        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemSId,nil,self.isRewardItemPop)
        end)
    elseif itemDataConFig.ItemType == ItemType.Talisman then
        self.num.gameObject:SetActive(false)
        self.starGrid:SetActive(true)

        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))
        SetHeroStars(self.starGrid, TalismanManager.AllTalismanStartStar[itemSId])

        Util.AddOnceClick(self.frameBtn, function()
            UIManager.OpenPanel(UIName.RewardTalismanSingleShowPopup,2,"",itemSId,0,0)
        end)
    elseif itemDataConFig.ItemType == ItemType.HunYin then
        self.num.gameObject:SetActive(true)

        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.SoulPrintPopUp,0,nil,itemSId,nil,nil)
        end)
    elseif itemDataConFig.ItemType == ItemType.EquipTreasure then
        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))

        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardTalismanSingleShowPopup,2,"",itemSId,0,0)
        end)
    elseif itemDataConFig.ItemType == ItemType.CombatPlan then
        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))

        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemSId,nil,self.isRewardItemPop)
        end)
    elseif itemDataConFig.ItemType == ItemType.medal then
        self.starGrid:SetActive(true)

        local medalItem = ConfigManager.GetConfigData("MedalConfig", itemSId)
        local star = medalItem.Star
        SetHeroStars(self.starGrid, star)
        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))
        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemSId,nil,self.isRewardItemPop)
        end)
    elseif itemDataConFig.ItemType == ItemType.SelfBox then
        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))
        Util.AddOnceClick(self.btn, function()
            local data = {["itemConfig"] = itemConfig[itemSId],["id"] = 10}
            UIManager.OpenPanel(UIName.RewardBoxPanel, data,function ()
                UIManager.ClosePanel(UIName.RewardBoxPanel)
            end)
        end)
    elseif itemDataConFig.ItemType == ItemType.Gene then
        self.geneLv.gameObject:SetActive(true)
        self.geneLv.sprite = Util.LoadSprite(AircraftCarrierManager.GetSkillLvImgForId(itemSId).lvImg)
        self.num.text = PrintWanNum(itemNum)
        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))
        Util.AddOnceClick(self.btn, function()
            -- UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemSId, nil, self.isRewardItemPop)
            UIManager.OpenPanel(UIName.LeadGeneTopLevelPanel, nil, itemSId, false)
        end)
    else
        self.num.text = PrintWanNum(itemNum)
        self.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[itemSId].Quantity))
        self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemSId].ResourceID))
        Util.AddOnceClick(self.btn, function()
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemSId, nil, self.isRewardItemPop)
        end)
    end
    if itemNum <= 0 then
        self.num.gameObject:SetActive(false)
    else
        if isShowAddImage then
            local bagAllNum = BagManager.GetItemCountById(itemSId)
            if bagAllNum >= itemNum then
                self.add:SetActive(false)
                self.num.text = string.format("%s/%s", PrintWanNum2(bagAllNum), PrintWanNum2(itemNum))
                self.num.color = Color.New(1, 1, 1, 1)
            else
                self.num.text = string.format("%s/%s", PrintWanNum2(bagAllNum), PrintWanNum2(itemNum))
                self.num.color = UIColor.NOT_ENOUGH_RED
            end
        else
            self.num.text = string.format("%s", PrintWanNum(itemNum))
            self.num.color = Color.New(1, 1, 1, 1)
        end
    end

    self.gameObject:GetComponent("RectTransform").localScale = Vector2.New(self.scale, self.scale)
end

function ItemView:OnBtnCkickEvent(itemSId)
    local itemDataConFig = ConfigManager.GetConfigData(ConfigName.ItemConfig, itemSId)
    if itemDataConFig.ItemType == ItemType.Hero then
        local heroConfigData = ConfigManager.GetConfigData(ConfigName.HeroConfig, itemConfig[itemDataConFig.Id].HeroStar[1])
        UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroConfigData.Id, itemConfig[itemDataConFig.Id].HeroStar[2])
    elseif itemDataConFig.ItemType == ItemType.Equip then
        UIManager.OpenPanel(UIName.HandBookEquipInfoPanel, itemDataConFig.Id)
    elseif itemDataConFig.ItemType == ItemType.Blueprint then
        local lanTuData = WorkShopManager.GetLanTuIsOpenLock(itemDataConFig.Id)
        if lanTuData then
            UIManager.OpenPanel(UIName.WorkShopArmorOnePanel,3,3, lanTuData[2])
        end
    else
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemDataConFig.Id,nil,self.isRewardItemPop)
    end
end

--显示扫光特效
function ItemView:OnShowUIeffectItemViewSaoguang()
    if not self.effect_saoguang then
        self.effect_saoguang = poolManager:LoadAsset("UI_effect_ItemView_saoguang",PoolManager.AssetType.GameObject)
        self.effect_saoguang.transform:SetParent(self.effects.transform)
        self.effect_saoguang.transform.localScale = Vector3.one
        self.effect_saoguang.transform.localPosition = Vector3.New(0, 0, 0)
        -- Util.AddParticleSortLayer(self.effect_saoguang, self.EffectOrginLayerQu + 1)
        Util.SetParticleSortLayer(self.effect_saoguang, self.EffectOrginLayerQu + 10)
    else
        self.effect_saoguang:SetActive(false)
        self.effect_saoguang:SetActive(true)
    end
end

--设置特效
function ItemView:SetEffect(str, quantity)
    local effect = Util.GetGameObject(self.effects, str.."(Clone)")
    if effect then
        effect:SetActive(false)
        if _Quantity == quantity then
            effect:SetActive(true)
            Util.SetParticleSortLayer(effect, self.EffectOrginLayerQu + 10)
        end
    else
        if _Quantity == quantity then
            effect = poolManager:LoadAsset(str,PoolManager.AssetType.GameObject)
            effect.transform:SetParent(self.effects.transform)
            effect.transform.localScale = Vector3.one
            effect.transform.localPosition = Vector3.New(0, 0, 0)
            Util.SetParticleSortLayer(effect, self.EffectOrginLayerQu + 10)
        end
    end
    return effect
end

--重设属性
--OnOpen ItemView时 只对isGet=false时生效 否则会报错
--该方法根据对ItemView的不同需求自己拓展
--该方法可有可无 不调用时走默认的赋值 调用时根据自定义的设置赋值
--_reward为数据 便于物品类型与传入的type类型相匹配
--settings为表类型 传入的参数需要与自定义配置相对应
function ItemView:Reset(_reward,type,settings)
    local itemSId = tonumber(_reward[1])
    local itemDataConFig = ConfigManager.GetConfigData(ConfigName.ItemConfig, itemSId)
    if type == itemDataConFig.ItemType then
        local data = settings
        -- self.posImage.enabled = data[1]
        self.pro.enabled = data[2]
        --self.heroStage.enabled = data[3]
        self.num.enabled = data[4]
    end
end

function ItemView:ResetNameColor(v4)
    self.name.color = GetLanguageStrById(v4)
end

--设置名字大小位置
function ItemView:ResetNameSize(v2,v3)
    self.name.gameObject:GetComponent("RectTransform").anchoredPosition3D = v2
    self.name.gameObject:GetComponent("RectTransform").localScale = v3
end

--设置数量显隐
function ItemView:ShowNum(isShow)
    self.num.gameObject:SetActive(isShow)
end

--设置星级显隐
function ItemView:ShowStar(isShow)
    self.starGrid.gameObject:SetActive(isShow)
end

--设置按钮点击响应
function ItemView:ClickEnable(isEnable)
    self.btn:GetComponent("Button").enabled = isEnable
end

--设置数量
function ItemView:SetNum(str)
    self.num.text = str
end

--1：首通 2：锁 3：概率获得 4：已领取  5：特效  6：等级  7:基因等级
function ItemView:SetCorner(type, isShow, arg)
    if type == 1 then
        if isShow then
            Util.GetGameObject(self.Corner, "CornerModel/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_fuhuazhizhan_shoutong"))
        end
        Util.GetGameObject(self.Corner, "CornerModel"):SetActive(isShow)
    elseif type == 2 then
        Util.GetGameObject(self.Corner, "Lock"):SetActive(isShow)
    elseif type == 3 then
        if isShow then
            Util.GetGameObject(self.Corner, "ProbabilityGet"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_gonghui_gailvhuode"))
        end
        Util.GetGameObject(self.Corner, "ProbabilityGet"):SetActive(isShow)
    elseif type == 4 then
        Util.GetGameObject(self.Corner, "Received"):SetActive(isShow)
    elseif type == 5 then
        Util.GetGameObject(self.Corner, "Effect"):SetActive(isShow)
    elseif type == 6 then
        Util.GetGameObject(self.Corner, "Lv"):SetActive(isShow)
        Util.GetGameObject(self.Corner, "Lv"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(nil, arg.star))
        Util.GetGameObject(self.Corner, "Lv/Text"):GetComponent("Text").text = arg.lv
        self.frame.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(nil, arg.star))
        SetHeroStars(self.starGrid, arg.star)
    elseif type == 7 then
        Util.GetGameObject(self.Corner, "geneLv"):SetActive(isShow)
        Util.GetGameObject(self.Corner, "geneLv"):GetComponent("Image").sprite = Util.LoadSprite(AircraftCarrierManager.GetSkillLvImgForId(arg.id).lvImg)
    end
end

--重写点击
function ItemView:ClickEvent(func)
    Util.AddOnceClick(self.btn, function()
        if func then
            func()
        end
    end)
end

--设置红点显隐
function ItemView:SetRedPointState(isShow)
    self.redPoint.gameObject:SetActive(isShow)
end

function ItemView:OnClose()
    -- 修复对象池回收层级没有重置，导致特效穿透的问题
    self:SetEffectLayer(-self.EffectOrginLayerQu)
end

function ItemView:OnDestroy()
end

return ItemView