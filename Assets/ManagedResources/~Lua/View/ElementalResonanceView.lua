----- 元素共鸣 -----
ElementalResonanceView = {}
local this = ElementalResonanceView
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local monsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local elementalResonanceConfig = ConfigManager.GetConfig(ConfigName.ElementalResonanceConfig)
local elementPropertyList = {}
local ImageList = {
    "m5_img_buzhen_jiban_02",
    "m5_img_buzhen_jiban_06",
    "m5_img_buzhen_jiban_03",
    "m5_img_buzhen_jiban_04",
    "m5_img_buzhen_jiban_04",
    "m5_img_buzhen_jiban_04"
}

function ElementalResonanceView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b, {__index = ElementalResonanceView})
    return b
end

function this:InitComponent()
    self.elementalResonanceBtn = Util.GetGameObject(self.gameObject, "elementalResonanceBtn")
    this.orginLayer = 0
    this.effect = Util.GetGameObject(self.elementalResonanceBtn, "effect")
    self.elementalResonanceImage =
        Util.GetGameObject(self.gameObject, "elementalResonanceBtn/bgImage/Image"):GetComponent("Image")
end

function this:BindEvent()
    -- 功能开启列表
    Util.AddClick(
        self.elementalResonanceBtn,
        function()
            UIManager.OpenPanel(UIName.ElementPopup, self.dataTable, this.thisPanelOrder)
        end
    )
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnOpen(context)
    if context then
        this.SetOrderStatus(context)
    end
end

function this:OnClose()
    UIManager.ClosePanel(UIName.ElementPopup)
end

function this:OnDestroy()
end

--设定层级
function this.SetOrderStatus(context)
    if not context then
        return
    end

    local sortingOrder = context.sortOrder + 90
    
    this.thisPanelOrder = context.sortOrder
    --self.transform:GetComponent("Canvas").sortingOrder = sortingOrder
    Util.AddParticleSortLayer(this.effect, sortingOrder - this.orginLayer)
    this.orginLayer = sortingOrder
end

--得到元素共鸣类型
-- 1.火 2.风 3.水 4.大地
function this:GetElementalType(curFormation, type)
    elementPropertyList = {}
    local fireElementNum = 0
    local windyElementNum = 0
    local waterElementNum = 0
    local groundElementNum = 0
    self.dataTable = {}

    if (type == 1) then
        for i, v in pairs(curFormation) do
            self.heroPropertyType = HeroManager.GetSingleHeroData(v.heroId).heroConfig.PropertyName
            table.insert(elementPropertyList, self.heroPropertyType)
        end
        self.dataTable.title = GetLanguageStrById(12074)
    end
    if (type == 2) then
        for i, v in ipairs(curFormation) do
            if (v.monsterId ~= nil) then
                self.heroPropertyType = monsterConfig[v.monsterId].PropertyName
            else
                self.heroPropertyType = heroConfig[v.roleId].PropertyName
            end
            table.insert(elementPropertyList, self.heroPropertyType)
        end
        self.dataTable.title = GetLanguageStrById(12075)
    end

    for i, v in pairs(elementPropertyList) do --遍历该列表拿筛选出各元素
        if (v == 1) then
            fireElementNum = fireElementNum + 1
        elseif (v == 2) then
            windyElementNum = windyElementNum + 1
        elseif (v == 3) then
            waterElementNum = waterElementNum + 1
        elseif (v == 4) then
            groundElementNum = groundElementNum + 1
        end
    end

    local list = {}
    list[1] = fireElementNum
    list[2] = windyElementNum
    list[3] = waterElementNum
    list[4] = groundElementNum

    local indexChoose = 0
    for i = 1, #list do
        local v = list[i]
        if v == 4 then
            indexChoose = 4
        end
        if v == 5 then
            indexChoose = 5
        end
        if v == 6 then
            indexChoose = 6
        end
    end

    local count = 0
    for i = 1, #list do
        local v = list[i]
        if v == 3 then
            count = count + 1 --你有几组3
        end
    end
    if count == 1 then --当你有1组3时 返回2
        indexChoose = 2
    elseif count == 2 then
        indexChoose = 3 --当你有2组3时 返回3
    end

    local index = 0
    for i = 1, #list do
        local v = list[i]
        if v == 2 then
            index = index + 1
        end
    end
    if index == 3 then
        indexChoose = 1 --当你有3组2时 返回1
    end

    
    self.dataTable.activeIndex = indexChoose

    local isShow = false
    isShow = indexChoose > 0
    if (isShow == false) then
        self.elementalResonanceImage.sprite = Util.LoadSprite("m5_img_buzhen_jiban_01")
    else
        if indexChoose > 0 then
            self.elementalResonanceImage.sprite = Util.LoadSprite(ImageList[indexChoose])
        end
    end
    this.effect:SetActive(isShow)
end

function this:SetPosition(type)
    if (type == 1) then
        self.elementalResonanceBtn.transform.localPosition = Vector3.New(-455, 783 - 70, 0)
    elseif (type == 2) then
        --self.elementalResonanceBtn.transform.localPosition = Vector3.New(-484, 876, 1)
        self.elementalResonanceBtn.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(62, -67)
        self.elementalResonanceBtn.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0, 1)
        self.elementalResonanceBtn.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0, 1)
        self.elementalResonanceBtn.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    elseif (type == 3) then
        --self.elementalResonanceBtn.transform.localPosition = Vector3.New(500, 876, 1)
        self.elementalResonanceBtn.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(-62, -67)
        self.elementalResonanceBtn.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(1, 1)
        self.elementalResonanceBtn.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(1, 1)
        self.elementalResonanceBtn.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    elseif type == 4 then
        self.elementalResonanceBtn.transform.localPosition = Vector3.New(455, 783 - 70, 0)
    elseif type == 5 then
        self.elementalResonanceBtn.transform.localPosition = Vector3.New(0, 0, 0)
    end
end

function this:SetElementalPropertyTextColor()
end
return ElementalResonanceView