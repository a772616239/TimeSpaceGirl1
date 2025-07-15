----- 宝器分解 -----
local this = {}
local sortingOrder=0
local tabSortType = 0
local tarEquipTreasure
local selectEquipTreasureData={}--选择的宝器list did = data
local maxSelectNum = 30--最大选择数量
function this:InitComponent(gameObject)
    --上部内容
    this.helpBtn=Util.GetGameObject(gameObject,"Content/Resolve_EquipTreasure/HelpBtn")
    this.helpPos=this.helpBtn:GetComponent("RectTransform").localPosition
    --回溯按钮
    this.confirmBtn=Util.GetGameObject(gameObject,"Content/Resolve_EquipTreasure/ConfirmBtn")
    this.shopBtn=Util.GetGameObject(gameObject,"Content/Resolve_EquipTreasure/shopBtn")

    this.selectText = Util.GetGameObject(gameObject,"Content/Resolve_EquipTreasure/selectNumText"):GetComponent("Text")
    Util.GetGameObject(gameObject,"Content/Resolve_EquipTreasure/btns").gameObject:SetActive(false)
    this.selectBtn = Util.GetGameObject(gameObject,"Content/Resolve_EquipTreasure/btns/selectBtn")
    this.noSelectBtn = Util.GetGameObject(gameObject,"Content/Resolve_EquipTreasure/btns/noSelectBtn")
    this.cardPre = Util.GetGameObject(gameObject,"Content/Resolve_EquipTreasure/equipTreasurePre")
    this.scrollbar = Util.GetGameObject(gameObject,"Content/Resolve_EquipTreasure/Scrollbar"):GetComponent("Scrollbar")
    this.Empty = Util.GetGameObject(gameObject,"Content/Resolve_EquipTreasure/Empty")
    this.EmptyText = Util.GetGameObject(gameObject,"Content/Resolve_EquipTreasure/Empty/Bg/Text"):GetComponent("Text")
    this.EmptyText.text = GetLanguageStrById(12213)

    local v21 = Util.GetGameObject(gameObject, "Content/Resolve_EquipTreasure/ItemListRoot"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "Content/Resolve_EquipTreasure/ItemListRoot").transform,
            this.cardPre, this.scrollbar, Vector2.New(-v21.x*2, -v21.y*2), 1, 5, Vector2.New(45,15))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    maxSelectNum =tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,55).Value) 
end

function this:BindEvent()
    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.TreasureResolve,this.helpPos.x,this.helpPos.y)
    end)
    Util.AddClick(this.confirmBtn,function()
        if tonumber(LengthOfTable(selectEquipTreasureData))==0 then
            PopupTipPanel.ShowTipByLanguageId(12215)
        else
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.ResolveEquipTreasure,
            EquipTreasureManager.GetEquipTreasureResolveItems(selectEquipTreasureData),selectEquipTreasureData)
        end
    end)
    Util.AddClick(this.selectBtn, function()
        this.QuickSelectListData(1)
        if LengthOfTable(selectEquipTreasureData) > 0 then
            this.noSelectBtn.gameObject:SetActive(true)
        end
    end)
    Util.AddClick(this.noSelectBtn, function()
        this.QuickSelectListData(2)
        this.noSelectBtn.gameObject:SetActive(false)
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(...)
    sortingOrder =0
    this.SortTypeClick(sortingOrder)
end

--展示数据
function this.SortTypeClick(_sortType)
    tabSortType=_sortType
    selectEquipTreasureData={}
    if tabSortType == 0 then
        tarEquipTreasure=EquipTreasureManager.GetAllTreasures()
    else
        tarEquipTreasure=EquipTreasureManager.GetAllTreasures(tabSortType)
    end
    this.selectText.text = GetLanguageStrById(11775).."0/"..maxSelectNum
    this.noSelectBtn.gameObject:SetActive(false)
    tarEquipTreasure = this.SortDatas(tarEquipTreasure)
    this.Empty:SetActive(#tarEquipTreasure <= 0)
    this.ScrollView:SetData(tarEquipTreasure, function (index, go)
        this.SingleHeroDataShow(go, tarEquipTreasure[index])
    end)
end
function this.SortDatas(tarEquipTreasure)
    table.sort(
        tarEquipTreasure,
        function(a, b)
            if a.quantity == b.quantity then
                if a.lv == b.lv then
                    return a.refineLv < b.refineLv
                else
                    return a.lv < b.lv
                end
            else
                return a.quantity < b.quantity
            end
        end
    )
    return tarEquipTreasure
end
--英雄单个数据展示
function this.SingleHeroDataShow(go,_equipTreasureData)
    local _go = go
    Util.GetGameObject(_go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(_equipTreasureData.itemConfig.Quantity))
    Util.GetGameObject(_go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(_equipTreasureData.itemConfig.ResourceID))
    Util.GetGameObject(_go.transform, "equipTreaseureStoringLv"):GetComponent("Text").text = _equipTreasureData.lv > 0 and _equipTreasureData.lv or ""
    Util.GetGameObject(_go.transform, "equipTreaseureRefine"):GetComponent("Text").text = _equipTreasureData.refineLv > 0 and _equipTreasureData.refineLv or ""
    Util.GetGameObject(_go.transform, "Text"):GetComponent("Text").text = _equipTreasureData.itemConfig.Name
    Util.GetGameObject(_go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(_equipTreasureData.itemConfig.PropertyName))
    local choosed =Util.GetGameObject(_go.transform, "choosed")
    choosed:SetActive(selectEquipTreasureData[_equipTreasureData.idDyn] ~= nil)
    local cardclickBtn = Util.GetGameObject(_go.transform, "icon")
    this.selectText.text = GetLanguageStrById(11775)..LengthOfTable(selectEquipTreasureData).."/"..maxSelectNum

    Util.AddOnceClick(cardclickBtn, function()
        if selectEquipTreasureData[_equipTreasureData.idDyn] then
            choosed:SetActive(false)
            selectEquipTreasureData[_equipTreasureData.idDyn] = nil
            this.selectText.text = GetLanguageStrById(11775)..LengthOfTable(selectEquipTreasureData).."/"..maxSelectNum
            this.noSelectBtn.gameObject:SetActive(LengthOfTable(selectEquipTreasureData)>0)
            return
        end
        if LengthOfTable(selectEquipTreasureData) >= maxSelectNum then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12214),maxSelectNum))
            return
        end
        selectEquipTreasureData[_equipTreasureData.idDyn]=_equipTreasureData
        choosed:SetActive(true)
        this.selectText.text = GetLanguageStrById(11775)..LengthOfTable(selectEquipTreasureData).."/"..maxSelectNum
        this.noSelectBtn.gameObject:SetActive(LengthOfTable(selectEquipTreasureData)>0)
    end)
end
--快速选择英雄 或者 装备
function this.QuickSelectListData(type)
    if type == 1 then
        selectEquipTreasureData={}
        for k, v in pairs(tarEquipTreasure) do
            if LengthOfTable(selectEquipTreasureData)<maxSelectNum then
                selectEquipTreasureData[v.idDyn]=v
            else
                break
            end
        end
        this.ScrollView:SetData(tarEquipTreasure, function (index, go)
            this.SingleHeroDataShow(go, tarEquipTreasure[index])
        end)
    else
        selectEquipTreasureData={}
        this.ScrollView:SetData(tarEquipTreasure, function (index, go)
            this.SingleHeroDataShow(go, tarEquipTreasure[index])
        end)
    end
end
function this:OnClose()
end

function this:OnDestroy()
end

return this