require("Base/BasePanel")
WarWayComprehendPopup = Inherit(BasePanel)
local this = WarWayComprehendPopup

local WarWaySkillConfig = ConfigManager.GetConfig(ConfigName.WarWaySkillConfig)
local PassiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local ArtResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

--初始化组件（用于子类重写）
function WarWayComprehendPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "btnClose")
    this.SelectWarWay = Util.GetGameObject(self.gameObject, "bg/SelectWarWay")
    this.CostPart = Util.GetGameObject(self.gameObject, "bg/CostPart")
    this.ComprehendBtn = Util.GetGameObject(self.gameObject, "bg/ComprehendBtn")
    this.Scroll = Util.GetGameObject(self.gameObject, "bg/Scroll")
    this.WarWayPre = Util.GetGameObject(self.gameObject, "bg/WarWayPre")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.WarWayPre, nil,
            Vector2.New(w, h), 1, 4, Vector2.New(5, 5))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function WarWayComprehendPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.ComprehendBtn, function()
        if self.listA and #self.listA > 0 and self.listA[self.selectIdx] then
            local data = self.listA[self.selectIdx]
            -- materials enough
            local isEnough = true
            for i = 1, #data.data.UpgradeCost do
                local itemid = data.data.UpgradeCost[i][1]
                local itemnum = data.data.UpgradeCost[i][2]
                local ownNum = BagManager.GetItemCountById(itemid)
                if ownNum < itemnum then
                    isEnough = false
                    break
                end
            end
            if isEnough then
                local warWaySkillId = data.data.ID
                NetManager.WarWayLearning(this.heroData.dynamicId, warWaySkillId, this.slot, function(msg)
                    HeroManager.UpdateWarWayData(this.heroData.dynamicId, this.slot, warWaySkillId, true)
                    RoleInfoPanel:UpdatePanelData()
                    self:ClosePanel()
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(10455)
            end
        end
        RoleInfoPanel:AbilityUpdateUI()
    end)
end

--添加事件监听（用于子类重写）
function WarWayComprehendPopup:AddListener()
end

--移除事件监听（用于子类重写）
function WarWayComprehendPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function WarWayComprehendPopup:OnOpen(...)
    local args = {...}
    this.heroData = args[1]
    this.slot = args[2]

    self.selectIdx = 0
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function WarWayComprehendPopup:OnShow()
    local list = ConfigManager.GetAllConfigsDataByKey(ConfigName.WarWaySkillConfig, "Level", 1)

    self.listA = {}
    for i = 1, #list do
        local isS = false
        if i == 1 then --默认选第一个
            isS = true
        end
        table.insert(self.listA, {isSelect = isS, data = list[i]})
    end

    this:TableSort()
    self:RefreshScroll()
    if #self.listA > 0 then
        self.selectIdx = 1
        self:UpdateTopSelected(self.listA[1])
        self:UpdateConsumeItem(self.listA[1])
    end
    this.scrollView:SetIndex(1)
end

function WarWayComprehendPopup:RefreshScroll()
    this.scrollView:SetData(self.listA, function(index, root)
        self:FillItem(root, self.listA[index], index)
    end)
end

function WarWayComprehendPopup:FillItem(go, data, index)
    Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(data.data.Image))
    local passiveConfig = PassiveSkillConfig[data.data.SkillId]
    Util.GetGameObject(go, "Name"):GetComponent("Text").text = GetLanguageStrById(passiveConfig.Name)
    Util.GetGameObject(go, "Select"):SetActive(data.isSelect)

    Util.GetGameObject(go, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(data.data.Level))

    -- 标签
    local CanLearnSign = Util.GetGameObject(go, "CanLearnSign")
    local RecommandSign = Util.GetGameObject(go, "RecommandSign")
    local RareSign = Util.GetGameObject(go, "RareSign")
    local UniqueSign = Util.GetGameObject(go, "UniqueSign")
    CanLearnSign:SetActive(false)
    RecommandSign:SetActive(false)
    RareSign:SetActive(false)
    UniqueSign:SetActive(false)
    
    local isCanEquip = true
    if data.data.UpgradeCost then
        for i = 1, #data.data.UpgradeCost do
            local itemid = data.data.UpgradeCost[i][1]
            local itemnum = data.data.UpgradeCost[i][2]
            local itemData = ItemConfig[itemid]
            local ownNum = BagManager.GetItemCountById(itemid)
            if ownNum < itemnum then
                isCanEquip = false
            end
        end
    end
    if isCanEquip then  --可领悟
        CanLearnSign:SetActive(true)
    else
        if data.data.Recommend and #data.data.Recommend > 0 then
            local isRecommend = false
            for i = 1, #data.data.Recommend do
                if data.data.Recommend[i] == this.heroData.heroConfig.Profession then
                    isRecommend = true
                    break
                end
            end
            if isRecommend then --推荐
                RecommandSign:SetActive(true)
            end
        else
        end
    end
    --专属
    if data.data.Exclusive == 1 then
        UniqueSign:SetActive(true)
    end

    Util.AddOnceClick(Util.GetGameObject(go, "frame"), function()
        for i = 1, #self.listA do
            self.listA[i].isSelect = false
        end
        data.isSelect = true

        self:RefreshScroll()

        self.selectIdx = index
        self:UpdateTopSelected(data)
        self:UpdateConsumeItem(data)
    end)
end

function WarWayComprehendPopup:UpdateTopSelected(data)
    Util.GetGameObject(this.SelectWarWay, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(data.data.Image))
    local passiveConfig = PassiveSkillConfig[data.data.SkillId]
    Util.GetGameObject(this.SelectWarWay, "Name"):GetComponent("Text").text = GetLanguageStrById(passiveConfig.Name)
    Util.GetGameObject(this.SelectWarWay, "Desc"):GetComponent("Text").text = GetLanguageStrById(passiveConfig.Desc)
end

function WarWayComprehendPopup:UpdateConsumeItem(data)
    for i = 1, 3 do -- 暂时最多支持三种
        local cost = Util.GetGameObject(this.CostPart, "cost" .. tostring(i))
        if #data.data.UpgradeCost >= i then
            cost:SetActive(true)

            local itemid = data.data.UpgradeCost[i][1]
            local itemnum = data.data.UpgradeCost[i][2]

            local icon = Util.GetGameObject(cost, "icon")
            local Name = Util.GetGameObject(cost, "Name")
            local Num = Util.GetGameObject(cost, "Num")
            local frame = Util.GetGameObject(cost, "frame")

            local itemData = ItemConfig[itemid]

            frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemData.Quantity))
            icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
            Util.AddOnceClick(icon,function ()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,itemData.Id)
            end)
            Name:GetComponent("Text").text = GetLanguageStrById(itemData.Name)
            local ownNum = BagManager.GetItemCountById(itemid)
            Num:GetComponent("Text").text = GetNumUnenoughColor(ownNum, itemnum, ownNum, itemnum)

            Util.AddOnceClick(frame,function ()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemid)
            end)
        else
            cost:SetActive(false)
        end
    end
end

function this:TableSort()
    table.sort(self.listA, function(left,right)
        if this:isCanEquip(left) and not this:isCanEquip(right) then
            return true
        elseif not this:isCanEquip(left) and this:isCanEquip(right) then
            return false
        else
            if this:isRecommend(left) and not this:isRecommend(right) then
                return true
            else
                return false
            end
        end
    end)
end

--是否可领悟
function this:isCanEquip(data)
    local isCanEquip = true
    if data.data.UpgradeCost then
        for i = 1, #data.data.UpgradeCost do
            local itemid = data.data.UpgradeCost[i][1]
            local itemnum = data.data.UpgradeCost[i][2]
            local itemData = ItemConfig[itemid]
            local ownNum = BagManager.GetItemCountById(itemid)
            if ownNum < itemnum then
                isCanEquip = false
            end
        end
    end
    return isCanEquip
end

--是否是推荐
function this:isRecommend(data)
    local isRecommend = false
    if data.data.Recommend and #data.data.Recommend > 0 then
        for i = 1, #data.data.Recommend do
            if data.data.Recommend[i] == this.heroData.heroConfig.Profession then
                isRecommend = true
                break
            end
        end
    end
    return isRecommend
end

--界面关闭时调用（用于子类重写）
function WarWayComprehendPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function WarWayComprehendPopup:OnDestroy()
end

return WarWayComprehendPopup