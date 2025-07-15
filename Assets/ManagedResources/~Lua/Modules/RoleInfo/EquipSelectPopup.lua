require("Base/BasePanel")

EquipSelectPopup = Inherit(BasePanel)
local this = EquipSelectPopup

local spcialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local jewerConfigs = ConfigManager.GetConfig(ConfigName.JewelConfig)

--当前英雄
local curHeroData
local teamHero

local openThisPanel
local lastRecordCur = nil

function this:InitComponent()
    this.equipPre = Util.GetGameObject(self.gameObject, "Panel/equipPre")
    this.BackBtn = Util.GetGameObject(self.gameObject, "Panel/BackBtn")
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.emptyObj = Util.GetGameObject(self.gameObject, "Panel/emptyObj")

    this.scorllRoot = Util.GetGameObject(self.gameObject, "Panel/scroll")
end

function this:BindEvent()
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)
end

function this:AddListener()

end

function this:RemoveListener()

end

--界面打开时调用（用于子类重写）
function this:OnOpen(...)
    local data = {...}
    --> 1curHeroData 2装备位置 3RoleInfoPanel
    if data[1] then
        curHeroData = data[1]
        HeroManager.roleEquipPanelCurHeroData = data[1]
    else
        curHeroData = HeroManager.roleEquipPanelCurHeroData
    end
    self.equippos = data[2]
    openThisPanel = data[3]

end

function this:OnShow()
    teamHero = FormationManager.GetAllFormationHeroId()

    --装备的数据
    self.curHeroEquipDatas = {}
    for i = 1, #curHeroData.equipIdList do
        local equipData = EquipManager.GetSingleHeroSingleEquipData(curHeroData.equipIdList[i], curHeroData.dynamicId)
        if equipData ~= nil then
            self.curHeroEquipDatas[equipData.equipConfig.Position] = equipData
        end
    end
    --宝器的数据
    self.curEquipTreasureDatas = {}
    
    for i = 1, #curHeroData.jewels do
        local treasureData = EquipTreasureManager.GetSingleEquipTreasreData(curHeroData.jewels[i])
        if treasureData ~= nil then
            local id = treasureData.id
            local pos = jewerConfigs[id].Location + 4
            self.curEquipTreasureDatas[pos] = treasureData
        end
    end

    --> 当前装备数据
    self.curPosData = nil
    for i = 1, 6 do
        if i < 5 then
            if self.curHeroEquipDatas[self.equippos] then
                self.curPosData = self.curHeroEquipDatas[self.equippos]
            else

            end
        else
            if self.curEquipTreasureDatas[self.equippos] then
                self.curPosData = self.curEquipTreasureDatas[self.equippos]
            end
        end
    end
    
    if self.curPosData then
        this.SingleItemDataShow(this.equipPre, self.curPosData, false)
        this.equipPre:SetActive(true)
        this:InitScrollCycle(true)
    else
        this.equipPre:SetActive(false)
        this:InitScrollCycle(false)
    end
    this:OnClickTabBtn(self.equippos)

end

function this:Init()
   
end

function this:InitScrollCycle(haveCur)
    if lastRecordCur == haveCur then
        return
    else
        lastRecordCur = haveCur
    end

    -- if haveCur then
        -- this.scorllRoot.transform.sizeDelta = Vector2.New(this.scorllRoot.transform.rect.width, this.scorllRoot.transform.rect.height)
    -- else
        -- this.scorllRoot.transform.sizeDelta = Vector2.New(this.scorllRoot.transform.rect.width, this.scorllRoot.transform.rect.height)
    -- end

    local scrollWidth = this.scorllRoot.transform.rect.width
    local scrollHight = this.scorllRoot.transform.rect.height
    
    Util.ClearChild(this.scorllRoot.transform)
    this.ScrollView =
        SubUIManager.Open(
        SubUIConfig.ScrollCycleView,
        this.scorllRoot.transform,
        this.equipPre,
        nil,
        Vector2.New(scrollWidth, scrollHight),
        1,
        1,
        Vector2.New(50, 15)
    )
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

--点击装备按钮
function this:OnClickTabBtn(_index)
    if _index < 5 then
        local allEquip = BagManager.GetEquipDataByEquipPosition(curHeroData.heroConfig.Profession, _index)
        this:SortEquipDatas(allEquip)
        -- local count = 0
        -- for i=1,#allEquip do
        --     count = count + allEquip[i].num
        -- end
        -- this.itemNumText.text = GetLanguageStrById(10188) .. count
        this:SetItemData(allEquip)
    else
        local allEquipTreasure
        allEquipTreasure =
            EquipTreasureManager.GetAllTreasuresByLocation(_index - 4, curHeroData.heroConfig.PropertyName)
        table.sort(
            allEquipTreasure,
            function(a, b)
                if a.refineLv == b.refineLv then
                    if a.lv == b.lv then
                        return a.id > b.id
                    else
                        return a.lv > b.lv
                    end
                else
                    return a.refineLv > b.refineLv
                end
            end
        )
        -- this.itemNumText.text = GetLanguageStrById(10188) .. LengthOfTable(allEquipTreasure)
        this:SetItemData(allEquipTreasure)      
    end
end

function this:SetItemData(_itemDatas)
    
    if LengthOfTable(_itemDatas) == 0 then
        this.emptyObj.gameObject:SetActive(true)
    else
        this.emptyObj.gameObject:SetActive(false)
    end

    this.ScrollView:SetData(
        _itemDatas,
        function(index, go)
            this.SingleItemDataShow(go, _itemDatas[index], true)
        end
    )
end

function this.SingleItemDataShow(_go, _itemData, isWear)
    if not itemConfig[_itemData.id] then
        return
    end
    local frame = Util.GetGameObject(_go.transform, "frame"):GetComponent("Image")
    local icon = Util.GetGameObject(_go.transform, "icon"):GetComponent("Image")
    local name = Util.GetGameObject(_go.transform, "name"):GetComponent("Text")
    local power=Util.GetGameObject(_go.transform, "score"):GetComponent("Text")
    local star = Util.GetGameObject(_go.transform, "star")
    local pro = Util.GetGameObject(_go.transform, "pro")
    local proBG = Util.GetGameObject(_go.transform, "pro/proBG")
    local proIcon = Util.GetGameObject(_go.transform, "pro/proIcon")
    local jewerConfig = ConfigManager.TryGetConfigData(ConfigName.JewelConfig, _itemData.id)
    local pos = 0
    if jewerConfig then
        Util.GetGameObject(_go.transform, "num").gameObject:SetActive(false)
        if jewerConfig.Location == 1 then
            pos = 5
        else
            if jewerConfig.Location == 2 then
                pos = 6
            end
        end
    else
        Util.GetGameObject(_go.transform, "num").gameObject:SetActive(false)
        Util.GetGameObject(_go.transform, "num"):GetComponent("Text").text = _itemData.num
    end
    power.text=GetLanguageStrById(22327)..EquipManager.CalculateWarForce(_itemData.id)
    local lvObj = Util.GetGameObject(_go.transform, "lv"):GetComponent("Text")
    local refineObj = Util.GetGameObject(_go.transform, "refine"):GetComponent("Text")
    if itemConfig[_itemData.id].ItemType == ItemType.EquipTreasure then
        icon.sprite = Util.LoadSprite(_itemData.icon)
        frame.sprite = Util.LoadSprite(_itemData.frame)
        proBG.sprite = Util.LoadSprite(_itemData.Image_proBg)
        pro:SetActive(true)
        proIcon:GetComponent("Image").sprite =
            Util.LoadSprite(GetProStrImageByProNum(_itemData.itemConfig.PropertyName))
        name.text = GetLanguageStrById(itemConfig[_itemData.id].Name)
        star:SetActive(false)
        Util.GetGameObject(_go.transform, "redPoint"):SetActive(false)
        lvObj.text = _itemData.lv
        if _itemData.lv > 0 then
            lvObj.gameObject:SetActive(true)
        else
            lvObj.gameObject:SetActive(false)
        end
        refineObj.text = "+" .. _itemData.refineLv
        if _itemData.refineLv > 0 then
            refineObj.gameObject:SetActive(true)
        else
            refineObj.gameObject:SetActive(false)
        end
        -- 0.查看属性  1.穿戴 2.卸下  3.交换
        --宝物界面
        Util.AddOnceClick(
            Util.GetGameObject(_go.transform, "icon"),
            function()
                -- if curEquipTreasureDatas[pos] then
                --     UIManager.OpenPanel(
                --         UIName.RoleEquipTreasureChangePopup,
                --         this,
                --         3,
                --         curHeroData,
                --         curEquipTreasureDatas[pos],
                --         _itemData,
                --         pos
                --     )
                -- else
                --     UIManager.OpenPanel(UIName.RoleEquipTreasureChangePopup, this, 1, curHeroData, _itemData, nil, pos)
                -- end
            end
        )
    else
        frame.sprite = Util.LoadSprite(_itemData.frame)
        icon.sprite = Util.LoadSprite(_itemData.icon)
        lvObj.gameObject:SetActive(false)
        refineObj.gameObject:SetActive(false)
        pro:SetActive(false)
        name.text =GetLanguageStrById(_itemData.itemConfig.Name)
        star:SetActive(true)
        EquipManager.SetEquipStarShow(star, _itemData.itemConfig.Id)
        local redPoint = Util.GetGameObject(_go.transform, "redPoint")
        -- if curHeroCanUpEquipTabs and #curHeroCanUpEquipTabs > 0 then
        --     local isShow = false
        --     for i = 1, #curHeroCanUpEquipTabs do
        --         if curHeroCanUpEquipTabs[i] == _itemData.id then
        --             isShow = true
        --         end
        --     end
        --     if isShow then
        --         redPoint:SetActive(true)
        --     else
        --         redPoint:SetActive(false)
        --     end
        -- else
        --     redPoint:SetActive(false)
        -- end
        Util.GetGameObject(_go.transform, "num"):GetComponent("Text").text = _itemData.num
        Util.AddOnceClick(
            Util.GetGameObject(_go.transform, "icon"),
            function()
                -- if curHeroEquipDatas[equipConfig[_itemData.id].Position] then
                --     local nextEquipData = EquipManager.GetSingleEquipData(_itemData.id)
                --     UIManager.OpenPanel(
                --         UIName.RoleEquipChangePopup,
                --         this,
                --         3,
                --         curHeroData,
                --         curHeroEquipDatas[equipConfig[_itemData.id].Position],
                --         nextEquipData,
                --         equipConfig[_itemData.id].Position
                --     )
                -- else
                    UIManager.OpenPanel(
                        UIName.RoleEquipChangePopup,
                        this,
                        2,
                        curHeroData,
                        _itemData,
                        equipConfig[_itemData.id].Position
                    )
                -- end
            end
        )

        --> 穿戴
        if isWear then
            Util.GetGameObject(_go.transform, "btn_sure"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_genghuan_zhuangbei"))
        else
            Util.GetGameObject(_go.transform, "btn_sure"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_xinpian_xinpianyizhuangbei"))
        end
        Util.AddOnceClick(
            Util.GetGameObject(_go.transform, "btn_sure"),
            function()
                local equipIdList={}
                local equipDataList={}
                local position = equipConfig[_itemData.id].Position
                table.insert(equipIdList, tostring(_itemData.id))
                table.insert(equipDataList, _itemData)

                if isWear then
                    --> 服务端 1装备 2宝物
                    NetManager.EquipWearRequest(curHeroData.dynamicId, equipIdList, 1, function ()
                        
                        --> 客户端 1 穿单件装备  2 卸单件装备 3 替换单件装备 4 一键穿装备  5一键脱装备
                        if this.curPosData then     --< 替换
                            openThisPanel.UpdateEquipPosHeroData(1, 3, equipDataList, this.curPosData, position)
                        else                        --< 穿戴
                            openThisPanel.UpdateEquipPosHeroData(1, 1, equipDataList, 0, position)
                        end 

                        this:ClosePanel()
                    end)
                else
                    if this.curPosData then
                        equipIdList={}
                        equipDataList={}
                        table.insert(equipIdList,tostring(this.curPosData.id))
                        table.insert(equipDataList,this.curPosData)
                        --> par3 1装备 2宝物
                        NetManager.EquipUnLoadOptRequest(curHeroData.dynamicId, equipIdList, 1, function ()
                            this:ClosePanel()
                            --> 客户端 1 穿单件装备  2 卸单件装备 3 替换单件装备 4 一键穿装备  5一键脱装备
                            openThisPanel.UpdateEquipPosHeroData(1, 2, equipDataList)
                        end)
                    else
                        LogRed("卸下装备error")
                    end
                end
            end
        )
    end
end

function this:SortEquipDatas(_equipDatas)
    if teamHero[curHeroData.dynamicId] then
        -- isUpZhen = true
        -- this.allEquipUpRedPoint:SetActive(#HeroManager.GetHeroIsUpEquip(curHeroData.dynamicId) > 0)
        -- curHeroCanUpEquipTabs = HeroManager.GetHeroIsUpEquip(curHeroData.dynamicId)
    else
        -- isUpZhen = false
        -- this.allEquipUpRedPoint:SetActive(false)
        -- curHeroCanUpEquipTabs = {}
    end
    -- this:AddRedPointVale(_equipDatas)
    table.sort(
        _equipDatas,
        function(a, b)
            if a.isRedPointShow == b.isRedPointShow then
                if a.itemConfig.Quantity == b.itemConfig.Quantity then
                    if equipConfig[a.id].Position == equipConfig[b.id].Position then
                        return a.id > b.id
                    else
                        return equipConfig[a.id].Position < equipConfig[b.id].Position
                    end
                else
                    return a.itemConfig.Quantity > b.itemConfig.Quantity
                end
            else
                return a.isRedPointShow > b.isRedPointShow
            end
        end
    )
end

function this:OnSortingOrderChange(orginLayer)

end

function this:OnClose()
    this.curPosData = nil
end

function this:Dispose()

end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    lastRecordCur = nil
end

return this