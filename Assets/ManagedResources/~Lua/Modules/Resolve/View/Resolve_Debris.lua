----- 碎片回收 -----
local this = {}
local sortingOrder = 0
local tabSortType = 0
local tarHero
local selectHeroData = {}--选择的英雄list did = data
local selectHeroChoose = {}
local selectHeroChooseBg = {}
local maxSelectNum = 30--最大选择数量
--选择的碎片id
local selectChipId = 0
--碎片最大数量
local alreadyHaveNum = 0
--选择碎片的数量
local selectChipNum = 0
function this:InitComponent(gameObject)
    this.gameObject =  Util.GetGameObject(gameObject,"Content/Resolve_Debris")

    --上部内容
    this.helpBtn = Util.GetGameObject(this.gameObject,"HelpBtn")
    this.helpPos = this.helpBtn:GetComponent("RectTransform").localPosition
    --回溯按钮
    this.confirmBtn = Util.GetGameObject(this.gameObject,"ConfirmBtn")
    this.shopBtn = Util.GetGameObject(this.gameObject,"shopBtn")

    this.selectText = Util.GetGameObject(this.gameObject,"selectNumText"):GetComponent("Text")

    this.btns = Util.GetGameObject(this.gameObject,"btns")
    this.addBtn = Util.GetGameObject(this.btns,"addtBtn")
    this.reducetBtn = Util.GetGameObject(this.btns,"reducetBtn")
    this.slider = Util.GetGameObject(this.btns, "Slider"):GetComponent("Slider")
    this.showNumText = Util.GetGameObject(this.btns,"numText"):GetComponent("Text")
    this.bestBtn= Util.GetGameObject(this.btns,"bestBigBtn")

    this.cardPre = Util.GetGameObject(gameObject,"DebrisItem")
    this.scrollbar = Util.GetGameObject(this.gameObject,"Scrollbar"):GetComponent("Scrollbar")
    this.Empty = Util.GetGameObject(this.gameObject,"Empty")

    this.ItemListRoot = Util.GetGameObject(this.gameObject, "ItemListRoot")
    local v21 = this.ItemListRoot:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.ItemListRoot.transform,
            this.cardPre, this.scrollbar, Vector2.New(-v21.x*2, -v21.y*2), 1, 5, Vector2.New(5,5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    maxSelectNum = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,54).Value)
end

function this:BindEvent()
    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Resolve_Dismantle,this.helpPos.x,this.helpPos.y)
    end)
    Util.AddClick(this.confirmBtn,function()
        this.getItem = {}
        if #tarHero <= 0 then
            PopupTipPanel.ShowTipByLanguageId(23119)
            return
        end
        if selectChipId == 0 then
            PopupTipPanel.ShowTipByLanguageId(23120)
            return
        end

        local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig,selectChipId)
        if itemConfig then
            local groupId = itemConfig.ResolveReward
            local groupConfig = ConfigManager.GetConfigData(ConfigName.RewardGroup,tonumber(groupId))
            if groupConfig then
                for i = 1, #groupConfig.ShowItem do
                    local rewardItem = {groupConfig.ShowItem[i][1], groupConfig.ShowItem[i][2] * selectChipNum}
                    table.insert(this.getItem, rewardItem)
                end
            end
        end
        UIManager.OpenPanel(UIName.GeneralPopup ,GENERAL_POPUP_TYPE.ResolveDebris, this.getItem, selectHeroData ,function()
            local data = {}
            for k,v in pairs(selectHeroData) do
                local dataItem = {}
                dataItem.itemId = v.id
                dataItem.itemNum = selectChipNum
                table.insert(data,dataItem)
            end
            NetManager.UseAndPriceItemRequest(1, data, function(msg)
            UIManager.OpenPanel(UIName.RewardItemPopup, msg, 1)
                --BagManager.HeroLvUpUpdateItemsNum(selectChipId, selectChipNum)
                selectChipNum = 0
                selectChipId = 0
                --展示碎片数量
                this.SortTypeClick(sortingOrder)
            end)
        end)
    end)

    Util.AddClick(this.shopBtn, function()
        local isActive, errorTip = ShopManager.IsActive(SHOP_TYPE.SOUL_CONTRACT_SHOP)
        if not isActive then
            PopupTipPanel.ShowTip(errorTip or GetLanguageStrById(10528))
            return
        end
        UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.SOUL_CONTRACT_SHOP)
    end)

    Util.AddSlider(this.slider.gameObject, function(go, value)
        if value < 1 then
            value = 1
        end
        Util.SetGray(this.addBtn, value > alreadyHaveNum -1)
        Util.SetGray(this.reducetBtn, value < 2)

        selectChipNum = value
        this.showNumText.text = value

    end)

      --减少按钮
    Util.AddClick(this.reducetBtn,function()
        if selectChipNum < 2 then return end
        if selectChipNum >= alreadyHaveNum -1 then
            --取消增加按钮置灰
            Util.SetGray(this.addBtn,false)
        end
        selectChipNum = selectChipNum - 1
        this.showNumText.text = selectChipNum
        this.slider.value = selectChipNum

        if selectChipNum < 2 then
            --减少按钮置灰
            Util.SetGray(this.reducetBtn,true)
        end
    end)

    --增加按钮
    Util.AddClick(this.addBtn,function()
        if selectChipNum >= alreadyHaveNum then
            --增加按钮置灰
            Util.SetGray(this.addBtn,true)
            return
         end
         selectChipNum = selectChipNum + 1
         this.showNumText.text = selectChipNum
         this.slider.value = selectChipNum
         if selectChipNum > 1 then
            --取消减少按钮置灰
            Util.SetGray(this.reducetBtn,false)
        end
    end)

    Util.AddClick(this.bestBtn,function()
        selectChipNum = alreadyHaveNum
         this.showNumText.text = selectChipNum
         Util.SetGray(this.reducetBtn,false)
         Util.SetGray(this.addBtn,true)
         this.slider.value = selectChipNum
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(...)
    sortingOrder = 0
    this.SortTypeClick(sortingOrder)
end

--展示数据
function this.SortTypeClick(_sortType)
    this.showNumText.text = selectChipNum
    tabSortType = _sortType
    selectHeroData = {}
    tarHero=BagManager.GetBagDebrisItemData(tabSortType)
    this.selectText.text = GetLanguageStrById(11775).."0/"..maxSelectNum
    this.SortHeroDatas(tarHero)
    this.Empty:SetActive(#tarHero <= 0)
    --禁用按钮
    this.btnList={}
    table.insert(this.btnList,this.addBtn)
    table.insert(this.btnList,this.reducetBtn)
    table.insert(this.btnList,this.bestBtn)
    this.slider.enabled = false
    for i = 1, #this.btnList do
        Util.SetGray(this.btnList[i],true)
        this.btnList[i]:GetComponent("Button").enabled = false
    end

    local itemList = {}
    this.ScrollView:SetData(tarHero, function (index, go)
        this.selfindex = tarHero[index].id
        this.SingleHeroDataShow(go, tarHero[index])
        itemList[index] = go
    end)
    if itemList then
        DelayCreation(itemList)
    end
end


--英雄单个数据展示
function this.SingleHeroDataShow(go,_debrisData)
    local debrisData = _debrisData
    local _go = go
    Util.GetGameObject(_go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(debrisData.itemConfig.Quantity,debrisData.star))
    -- Util.GetGameObject(_go.transform, "Text"):GetComponent("Text").text = debrisData.itemConfig.Name
    Util.GetGameObject(_go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(debrisData.itemConfig.ResourceID))

    if debrisData.itemConfig.PropertyName == 0 then
        Util.GetGameObject(_go.transform, "proIcon"):SetActive(false)
        Util.GetGameObject(_go.transform, "proIconBg"):SetActive(false)
    else
        Util.GetGameObject(_go.transform, "proIconBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(debrisData.itemConfig.Quantity,debrisData.star))
        Util.GetGameObject(_go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(debrisData.itemConfig.PropertyName))
    end
    local starGrid = Util.GetGameObject(_go.transform, "star")
    SetHeroStars(starGrid, debrisData.itemConfig.Quantity)
    local choosed = Util.GetGameObject(_go.transform, "choosed")
    local choosedBg = Util.GetGameObject(_go.transform, "choosedBg")
    --local formationMask =Util.GetGameObject(_go.transform, "formationMask")
    --formationMask:SetActive(heroData.isFormation ~= "" )
    --local lockMask =Util.GetGameObject(_go.transform, "lockMask")
    --lockMask:SetActive(heroData.lockState == 1)
    local cardclickBtn = Util.GetGameObject(_go.transform, "icon")
    this.selectText.text = GetLanguageStrById(11775)..LengthOfTable(selectHeroData).."/"..maxSelectNum
    local sliderNum = Util.GetGameObject(_go.transform, "Slider"):GetComponent("Slider")
    local piecesCount = Util.GetGameObject(_go.transform, "Slider/Text"):GetComponent("Text")
    piecesCount.text = tostring(debrisData.num).."/"..debrisData.itemConfig.UsePerCount
    sliderNum.value = debrisData.num/debrisData.itemConfig.UsePerCount
    choosed:SetActive(false)
    choosedBg:SetActive(false)
    
    Util.AddOnceClick(cardclickBtn, function()
        this.slider.enabled = true
        --接触禁用
        for i = 1, #this.btnList do
            Util.SetGray(this.btnList[i],false)
            this.btnList[i]:GetComponent("Button").enabled = true
        end

        if selectHeroData[this.selfindex] then
           
          selectHeroChoose[this.selfindex]:SetActive(false)
          selectHeroChooseBg[this.selfindex]:SetActive(false)
          selectHeroData[this.selfindex] = nil
          selectHeroChoose[this.selfindex] = nil
          selectHeroChooseBg[this.selfindex] = nil
          this.selectText.text = GetLanguageStrById(11775)..LengthOfTable(selectHeroData).."/"..maxSelectNum
        end
        if LengthOfTable(selectHeroData) >= maxSelectNum then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12211),maxSelectNum))
            return
        end
        if selectHeroData[debrisData.id] == nil then
            selectHeroData[debrisData.id] = debrisData
            selectHeroChoose[debrisData.id] = choosed
            selectHeroChooseBg[debrisData.id] = choosedBg
            this.selfindex = debrisData.id
            choosed:SetActive(true)
            choosedBg:SetActive(true)
        end
        selectChipId=debrisData.id
        --初始化按钮状态
        this.btns:SetActive(true)
        alreadyHaveNum = debrisData.num
        --初始化滑动条
        this.slider.enabled = debrisData.num > 1
        this.slider.maxValue = debrisData.num
        this.slider.minValue = 0
        this.slider.value = debrisData.num > 0 and 1 or 0
        selectChipNum = 1
        this.showNumText.text = selectChipNum
        if selectChipNum == 1 then
            Util.SetGray(this.reducetBtn,true)
            Util.SetGray(this.addBtn,false)
        elseif selectChipNum == alreadyHaveNum then
            Util.SetGray(this.addBtn,true)
            Util.SetGray(this.reducetBtn,false)
        end
    end)

    -- Util.AddOnceClick(formationMask, function()
    --     if heroData.isFormation ~= "" then
    --         -- 复位角色的状态
    --         MsgPanel.ShowTwo(GetLanguageStrById(11788)..heroData.isFormation..GetLanguageStrById(11789), nil, function()
    --                 if heroData.isFormations[1] then
    --                     if heroData.isFormations[1] == FormationTypeDef.FORMATION_NORMAL then
    --                         UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.SAVE_FORMATION)
    --                     elseif heroData.isFormations[1] == FormationTypeDef.FORMATION_ARENA_DEFEND then
    --                         JumpManager.GoJump(8001)
    --                     elseif heroData.isFormations[1] == FormationTypeDef.FORMATION_ENDLESS_MAP then
    --                         JumpManager.GoJump(57001) 
    --                     elseif heroData.isFormations[1] == FormationTypeDef.ARENA_TOM_MATCH then
    --                         JumpManager.GoJump(57001)
    --                     end
    --                 end
    --         end)
    --         return
    --     end
    -- end)
    -- Util.AddOnceClick(lockMask, function()
    --     if heroData.lockState == 1 then
    --         MsgPanel.ShowTwo(GetLanguageStrById(11790), nil, function()
    --             NetManager.HeroLockEvent(heroData.dynamicId,0,function ()
    --                 PopupTipPanel.ShowTipByLanguageId(11791)
    --                 HeroManager.UpdateSingleHeroLockState(heroData.dynamicId,0)
    --                 lockMask:SetActive(false)
    --             end)
    --         end)
    --         return
    --     end
    -- end)
end

--英雄排序
function this.SortHeroDatas(_heroDatas)
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_heroDatas, function(a, b)
        if a ==nil or b == nil then
            return
        end
        if a.isFormation == "" and b.isFormation == "" then
            if a.lockState == b.lockState then
                if a.heroConfig.Natural ==b.heroConfig.Natural then
                    if a.star == b.star then
                        if a.lv == b.lv then
                            return a.heroConfig.Id > b.heroConfig.Id
                        else
                            return a.lv < b.lv
                        end
                    else
                        return a.star < b.star
                    end
                else
                    return a.heroConfig.Natural < b.heroConfig.Natural
                end
            else
                return a.lockState < b.lockState
            end
        else
            return a.isFormation == ""  and not b.dynamicId ~= ""
        end
    end)
end
--快速选择英雄 或者 装备
function this.QuickSelectListData(type)
    if type == 1 then
        selectHeroData={}
        for k, v in pairs(tarHero) do
            if LengthOfTable(selectHeroData)<maxSelectNum and v.isFormation == "" and v.lockState == 0 then
                selectHeroData[v.dynamicId]=v
            else
                break
            end
        end
        this.ScrollView:SetData(tarHero, function (index, go)
            this.SingleHeroDataShow(go, tarHero[index])
        end)
    else
        selectHeroData={}
        this.ScrollView:SetData(tarHero, function (index, go)
            this.SingleHeroDataShow(go, tarHero[index])
        end)
    end
end
function this:OnClose()
    selectChipNum=0
end

function this:OnDestroy()
end

return this