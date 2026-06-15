require("Base/BasePanel")
HeroComparePanel = Inherit(BasePanel)
local this = HeroComparePanel

local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local passiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)

local TAB_STATS = 1
local TAB_SKILLS = 2
local TAB_EQUIP = 3

local leftHeroData = nil
local rightHeroData = nil
local curTab = TAB_STATS
local heroListData = {}
local heroItemPool = {}
local selectSlot = 0

local statLabels = {
    { key = "hp",       label = "生命" },
    { key = "attack",   label = "攻击" },
    { key = "pDef",     label = "物防" },
    { key = "mDef",     label = "魔防" },
    { key = "speed",    label = "速度" },
    { key = "warPower", label = "战力" },
}

local radarDimensions = { "hp", "attack", "pDef", "mDef", "speed", "warPower" }

local COLOR_LEFT  = { r = 0.30, g = 0.68, b = 1.00, a = 0.45 }
local COLOR_RIGHT = { r = 1.00, g = 0.42, b = 0.34, a = 0.45 }

local COMPARE_ARROW_UP   = "▲"
local COMPARE_ARROW_DOWN = "▼"
local COMPARE_ARROW_EQ   = "—"

function this:InitComponent()
    self.btnBack = Util.GetGameObject(self.gameObject, "topBar/btnBack")
    self.titleText = Util.GetGameObject(self.gameObject, "topBar/title"):GetComponent("Text")
    self.titleText.text = GetLanguageStrById(11900) or "英雄对比"

    self.slotLeft  = Util.GetGameObject(self.gameObject, "content/heroSlots/slotLeft")
    self.slotRight = Util.GetGameObject(self.gameObject, "content/heroSlots/slotRight")
    self.vsText    = Util.GetGameObject(self.gameObject, "content/heroSlots/vsText"):GetComponent("Text")

    self.btnTabStats  = Util.GetGameObject(self.gameObject, "content/tabs/btnStats")
    self.btnTabSkills = Util.GetGameObject(self.gameObject, "content/tabs/btnSkills")
    self.btnTabEquip  = Util.GetGameObject(self.gameObject, "content/tabs/btnEquip")
    self.tabIndicator = Util.GetGameObject(self.gameObject, "content/tabs/indicator")

    self.btnSwap = Util.GetGameObject(self.gameObject, "content/heroSlots/btnSwap")
    self.btnClear = Util.GetGameObject(self.gameObject, "content/heroSlots/btnClear")

    self.statsContainer = Util.GetGameObject(self.gameObject, "content/detailPanel/statsPanel")
    self.skillsContainer = Util.GetGameObject(self.gameObject, "content/detailPanel/skillsPanel")
    self.equipContainer = Util.GetGameObject(self.gameObject, "content/detailPanel/equipPanel")

    self.statsPre = Util.GetGameObject(self.gameObject, "content/detailPanel/statsPanel/statPre")
    self.skillPre = Util.GetGameObject(self.gameObject, "content/detailPanel/skillsPanel/skillPre")
    self.equipPre = Util.GetGameObject(self.gameObject, "content/detailPanel/equipPanel/equipPre")

    self.radarRoot = Util.GetGameObject(self.gameObject, "content/radarChart")
    self.radarImage = self.radarRoot:GetComponent("Image")

    local listRect = Util.GetGameObject(self.gameObject, "content/heroList/rect")
    self.heroListPre = Util.GetGameObject(self.gameObject, "content/heroList/rect/heroPre")
    local v = listRect:GetComponent("RectTransform").rect
    self.heroScrollView = SubUIManager.Open(
        SubUIConfig.ScrollCycleView,
        listRect.transform,
        self.heroListPre, nil,
        Vector2.New(v.width, v.height),
        5, 1,
        Vector2.New(0, 10)
    )
    self.heroScrollView.moveTween.MomentumAmount = 1
    self.heroScrollView.moveTween.Strength = 1

    self.slotLeftView  = nil
    self.slotRightView = nil
end

function this:BindEvent()
    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)

    Util.AddClick(self.slotLeft, function()
        selectSlot = 1
        self:RefreshHeroList()
    end)

    Util.AddClick(self.slotRight, function()
        selectSlot = 2
        self:RefreshHeroList()
    end)

    Util.AddClick(self.btnSwap, function()
        leftHeroData, rightHeroData = rightHeroData, leftHeroData
        self:RefreshSlots()
        self:RefreshComparison()
    end)

    Util.AddClick(self.btnClear, function()
        leftHeroData = nil
        rightHeroData = nil
        self:RefreshSlots()
        self:RefreshComparison()
    end)

    Util.AddClick(self.btnTabStats, function()
        curTab = TAB_STATS
        self:SwitchTab()
    end)
    Util.AddClick(self.btnTabSkills, function()
        curTab = TAB_SKILLS
        self:SwitchTab()
    end)
    Util.AddClick(self.btnTabEquip, function()
        curTab = TAB_EQUIP
        self:SwitchTab()
    end)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.CustomEvent.OnUpdateHeroDatas, self.OnHeroDataChanged)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.CustomEvent.OnUpdateHeroDatas, self.OnHeroDataChanged)
end

function this:OnOpen()
end

function this:OnShow()
    curTab = TAB_STATS
    self:SwitchTab()
    self:RefreshHeroList()
    self:RefreshSlots()
    self:RefreshComparison()
end

function this:OnSortingOrderChange()
end

function this:OnClose()
end

function this:OnDestroy()
    leftHeroData = nil
    rightHeroData = nil
    selectSlot = 0
    SubUIManager.Close(self.heroScrollView)
    if self.slotLeftView then
        SubUIManager.Close(self.slotLeftView)
        self.slotLeftView = nil
    end
    if self.slotRightView then
        SubUIManager.Close(self.slotRightView)
        self.slotRightView = nil
    end
end

function this.OnHeroDataChanged()
    if UIManager.IsOpen(UIName.HeroComparePanel) then
        this:RefreshHeroList()
        this:RefreshSlots()
        this:RefreshComparison()
    end
end

-- ============================================================
-- Hero List
-- ============================================================

function this:RefreshHeroList()
    heroListData = {}
    local sortedList = HeroManager.heroSortedDatas
    if not sortedList or #sortedList == 0 then
        sortedList = HeroManager.heroDataLists
    end
    for i = 1, #sortedList do
        local hd = sortedList[i]
        if hd then
            table.insert(heroListData, hd)
        end
    end

    table.sort(heroListData, function(a, b)
        if a.star ~= b.star then
            return a.star > b.star
        end
        return (a.warPower or 0) > (b.warPower or 0)
    end)

    self.heroScrollView:SetData(heroListData, function(index, go)
        self:RenderHeroListItem(go, heroListData[index])
    end)
end

function this:RenderHeroListItem(go, heroData)
    go:SetActive(true)
    local icon = Util.GetGameObject(go, "icon"):GetComponent("Image")
    local nameText = Util.GetGameObject(go, "name/Text"):GetComponent("Text")
    local lvText = Util.GetGameObject(go, "lv/Text"):GetComponent("Text")
    local starGrid = Util.GetGameObject(go, "star")
    local proImage = Util.GetGameObject(go, "pro/Image"):GetComponent("Image")
    local frame = Util.GetGameObject(go, "frame"):GetComponent("Image")
    local selectMask = Util.GetGameObject(go, "selectMask")

    frame.sprite = Util.LoadSprite(GetHeroCardQuantityImage[heroData.heroConfig.Quality])
    icon.sprite = Util.LoadSprite(heroData.painting)
    nameText.text = GetLanguageStrById(heroData.heroConfig.ReadingName)
    lvText.text = "Lv." .. heroData.lv
    proImage.sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    SetHeroStars(starGrid, heroData.star)

    local isLeft  = (leftHeroData  and leftHeroData.dynamicId  == heroData.dynamicId)
    local isRight = (rightHeroData and rightHeroData.dynamicId == heroData.dynamicId)
    selectMask:SetActive(isLeft or isRight)
    if isLeft then
        Util.GetGameObject(go, "selectMask/tag"):GetComponent("Text").text = "A"
    elseif isRight then
        Util.GetGameObject(go, "selectMask/tag"):GetComponent("Text").text = "B"
    end

    Util.AddOnceClick(go, function()
        self:OnHeroSelected(heroData)
    end)
end

function this:OnHeroSelected(heroData)
    if selectSlot == 0 then
        if not leftHeroData then
            selectSlot = 1
        elseif not rightHeroData then
            selectSlot = 2
        else
            selectSlot = 1
        end
    end

    if selectSlot == 1 then
        if rightHeroData and rightHeroData.dynamicId == heroData.dynamicId then
            rightHeroData = nil
        end
        leftHeroData = heroData
    elseif selectSlot == 2 then
        if leftHeroData and leftHeroData.dynamicId == heroData.dynamicId then
            leftHeroData = nil
        end
        rightHeroData = heroData
    end

    self:RefreshSlots()
    self:RefreshHeroList()
    self:RefreshComparison()
end

-- ============================================================
-- Hero Slots
-- ============================================================

function this:RefreshSlots()
    self:SetSlotContent(self.slotLeft, leftHeroData, "A")
    self:SetSlotContent(self.slotRight, rightHeroData, "B")
end

function this:SetSlotContent(slotGo, heroData, tag)
    local emptyTip = Util.GetGameObject(slotGo, "emptyTip")
    local heroRoot = Util.GetGameObject(slotGo, "heroRoot")

    if not heroData then
        emptyTip:SetActive(true)
        heroRoot:SetActive(false)
        Util.GetGameObject(slotGo, "emptyTip/Text"):GetComponent("Text").text =
            tag == "A" and "选择英雄A" or "选择英雄B"
        return
    end

    emptyTip:SetActive(false)
    heroRoot:SetActive(true)

    local icon = Util.GetGameObject(heroRoot, "icon"):GetComponent("Image")
    local nameText = Util.GetGameObject(heroRoot, "name"):GetComponent("Text")
    local lvText = Util.GetGameObject(heroRoot, "lv"):GetComponent("Text")
    local starGrid = Util.GetGameObject(heroRoot, "star")
    local powerText = Util.GetGameObject(heroRoot, "warPower"):GetComponent("Text")
    local proImage = Util.GetGameObject(heroRoot, "pro"):GetComponent("Image")
    local tagText = Util.GetGameObject(slotGo, "tag"):GetComponent("Text")

    icon.sprite = Util.LoadSprite(heroData.painting)
    nameText.text = GetLanguageStrById(heroData.heroConfig.ReadingName)
    lvText.text = "Lv." .. heroData.lv
    powerText.text = tostring(math.floor(heroData.warPower or 0))
    proImage.sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    SetHeroStars(starGrid, heroData.star)
    tagText.text = tag
end

-- ============================================================
-- Tab Switching
-- ============================================================

function this:SwitchTab()
    self.statsContainer:SetActive(curTab == TAB_STATS)
    self.skillsContainer:SetActive(curTab == TAB_SKILLS)
    self.equipContainer:SetActive(curTab == TAB_EQUIP)

    local tabBtns = { self.btnTabStats, self.btnTabSkills, self.btnTabEquip }
    local positions = {
        [1] = self.btnTabStats:GetComponent("RectTransform").localPosition,
        [2] = self.btnTabSkills:GetComponent("RectTransform").localPosition,
        [3] = self.btnTabEquip:GetComponent("RectTransform").localPosition,
    }
    self.tabIndicator:GetComponent("RectTransform").localPosition = positions[curTab]

    self:RefreshComparison()
end

-- ============================================================
-- Comparison Rendering
-- ============================================================

function this:RefreshComparison()
    if curTab == TAB_STATS then
        self:RefreshStatsComparison()
    elseif curTab == TAB_SKILLS then
        self:RefreshSkillsComparison()
    elseif curTab == TAB_EQUIP then
        self:RefreshEquipComparison()
    end
    self:RefreshRadarChart()
end

-- ============================================================
-- Stats Comparison
-- ============================================================

function this:RefreshStatsComparison()
    for i, child in ipairs(self:GetChildren(self.statsContainer)) do
        if child.name ~= "statPre" then
            child:SetActive(false)
        end
    end

    local itemIndex = 0
    for i, stat in ipairs(statLabels) do
        local leftVal  = leftHeroData  and (leftHeroData[stat.key] or 0) or nil
        local rightVal = rightHeroData and (rightHeroData[stat.key] or 0) or nil

        if leftVal ~= nil or rightVal ~= nil then
            itemIndex = itemIndex + 1
            local item = self:GetOrCreateStatItem(itemIndex)
            item:SetActive(true)

            local labelText = Util.GetGameObject(item, "label"):GetComponent("Text")
            local leftText  = Util.GetGameObject(item, "leftVal"):GetComponent("Text")
            local rightText = Util.GetGameObject(item, "rightVal"):GetComponent("Text")
            local diffText  = Util.GetGameObject(item, "diff"):GetComponent("Text")
            local diffArrow = Util.GetGameObject(item, "diffArrow"):GetComponent("Text")

            labelText.text = stat.label

            leftText.text  = leftVal  and tostring(math.floor(leftVal))  or "—"
            rightText.text = rightVal and tostring(math.floor(rightVal)) or "—"

            if leftVal and rightVal then
                local diff = rightVal - leftVal
                if diff > 0 then
                    diffText.text = "+" .. tostring(math.floor(diff))
                    diffArrow.text = COMPARE_ARROW_UP
                    diffText.color = Color.New(0.2, 0.85, 0.2, 1)
                    diffArrow.color = Color.New(0.2, 0.85, 0.2, 1)
                elseif diff < 0 then
                    diffText.text = tostring(math.floor(diff))
                    diffArrow.text = COMPARE_ARROW_DOWN
                    diffText.color = Color.New(1.0, 0.3, 0.3, 1)
                    diffArrow.color = Color.New(1.0, 0.3, 0.3, 1)
                else
                    diffText.text = "0"
                    diffArrow.text = COMPARE_ARROW_EQ
                    diffText.color = Color.New(0.7, 0.7, 0.7, 1)
                    diffArrow.color = Color.New(0.7, 0.7, 0.7, 1)
                end
            else
                diffText.text = "—"
                diffArrow.text = ""
                diffText.color = Color.New(0.7, 0.7, 0.7, 1)
                diffArrow.color = Color.New(0.7, 0.7, 0.7, 1)
            end

            if leftVal and rightVal then
                local better = leftVal >= rightVal
                leftText.color  = (better)       and Color.New(1, 0.85, 0.2, 1) or Color.New(0.9, 0.9, 0.9, 1)
                rightText.color = (not better)   and Color.New(1, 0.85, 0.2, 1) or Color.New(0.9, 0.9, 0.9, 1)
            else
                leftText.color  = Color.New(0.9, 0.9, 0.9, 1)
                rightText.color = Color.New(0.9, 0.9, 0.9, 1)
            end
        end
    end
end

local statItemCache = {}
function this:GetOrCreateStatItem(index)
    if statItemCache[index] then
        return statItemCache[index]
    end
    local item = newObject(self.statsPre)
    item.name = "statItem_" .. index
    item.transform:SetParent(self.statsContainer.transform)
    item.transform.localScale = Vector3.one
    item.transform.localPosition = Vector3.zero
    statItemCache[index] = item
    return item
end

-- ============================================================
-- Skills Comparison
-- ============================================================

function this:RefreshSkillsComparison()
    for i, child in ipairs(self:GetChildren(self.skillsContainer)) do
        if child.name ~= "skillPre" then
            child:SetActive(false)
        end
    end

    local leftSkills  = leftHeroData  and leftHeroData.skillIdList  or {}
    local rightSkills = rightHeroData and rightHeroData.skillIdList or {}

    local maxSkills = math.max(#leftSkills, #rightSkills)
    local itemIndex = 0

    for i = 1, maxSkills do
        itemIndex = itemIndex + 1
        local item = self:GetOrCreateSkillItem(itemIndex)
        item:SetActive(true)

        local leftIcon  = Util.GetGameObject(item, "leftSkill/icon"):GetComponent("Image")
        local leftName  = Util.GetGameObject(item, "leftSkill/name"):GetComponent("Text")
        local rightIcon = Util.GetGameObject(item, "rightSkill/icon"):GetComponent("Image")
        local rightName = Util.GetGameObject(item, "rightSkill/name"):GetComponent("Text")
        local slotLabel = Util.GetGameObject(item, "slotLabel"):GetComponent("Text")

        slotLabel.text = GetLanguageStrById(11900 + i) or ("技能" .. i)

        if leftSkills[i] and skillConfig[leftSkills[i]] then
            local sk = skillConfig[leftSkills[i]]
            leftIcon.sprite = Util.LoadSprite(GetResourcePath(sk.Icon or ""))
            leftName.text = GetLanguageStrById(sk.Name or 0)
            Util.GetGameObject(item, "leftSkill"):SetActive(true)
        else
            Util.GetGameObject(item, "leftSkill"):SetActive(leftHeroData ~= nil)
            if leftHeroData then
                leftIcon.sprite = nil
                leftName.text = "—"
            end
        end

        if rightSkills[i] and skillConfig[rightSkills[i]] then
            local sk = skillConfig[rightSkills[i]]
            rightIcon.sprite = Util.LoadSprite(GetResourcePath(sk.Icon or ""))
            rightName.text = GetLanguageStrById(sk.Name or 0)
            Util.GetGameObject(item, "rightSkill"):SetActive(true)
        else
            Util.GetGameObject(item, "rightSkill"):SetActive(rightHeroData ~= nil)
            if rightHeroData then
                rightIcon.sprite = nil
                rightName.text = "—"
            end
        end
    end

    local leftPassive  = leftHeroData  and leftHeroData.passiveSkillList  or {}
    local rightPassive = rightHeroData and rightHeroData.passiveSkillList or {}

    local maxPassive = math.max(#leftPassive, #rightPassive)
    for i = 1, maxPassive do
        itemIndex = itemIndex + 1
        local item = self:GetOrCreateSkillItem(itemIndex)
        item:SetActive(true)

        local leftIcon  = Util.GetGameObject(item, "leftSkill/icon"):GetComponent("Image")
        local leftName  = Util.GetGameObject(item, "leftSkill/name"):GetComponent("Text")
        local rightIcon = Util.GetGameObject(item, "rightSkill/icon"):GetComponent("Image")
        local rightName = Util.GetGameObject(item, "rightSkill/name"):GetComponent("Text")
        local slotLabel = Util.GetGameObject(item, "slotLabel"):GetComponent("Text")

        slotLabel.text = "被动" .. i

        if leftPassive[i] and passiveSkillConfig[leftPassive[i]] then
            local sk = passiveSkillConfig[leftPassive[i]]
            leftIcon.sprite = Util.LoadSprite(GetResourcePath(sk.Icon or ""))
            leftName.text = GetLanguageStrById(sk.Name or 0)
            Util.GetGameObject(item, "leftSkill"):SetActive(true)
        else
            Util.GetGameObject(item, "leftSkill"):SetActive(leftHeroData ~= nil)
            if leftHeroData then
                leftIcon.sprite = nil
                leftName.text = "—"
            end
        end

        if rightPassive[i] and passiveSkillConfig[rightPassive[i]] then
            local sk = passiveSkillConfig[rightPassive[i]]
            rightIcon.sprite = Util.LoadSprite(GetResourcePath(sk.Icon or ""))
            rightName.text = GetLanguageStrById(sk.Name or 0)
            Util.GetGameObject(item, "rightSkill"):SetActive(true)
        else
            Util.GetGameObject(item, "rightSkill"):SetActive(rightHeroData ~= nil)
            if rightHeroData then
                rightIcon.sprite = nil
                rightName.text = "—"
            end
        end
    end
end

local skillItemCache = {}
function this:GetOrCreateSkillItem(index)
    if skillItemCache[index] then
        return skillItemCache[index]
    end
    local item = newObject(self.skillPre)
    item.name = "skillItem_" .. index
    item.transform:SetParent(self.skillsContainer.transform)
    item.transform.localScale = Vector3.one
    item.transform.localPosition = Vector3.zero
    skillItemCache[index] = item
    return item
end

-- ============================================================
-- Equipment Comparison
-- ============================================================

function this:RefreshEquipComparison()
    for i, child in ipairs(self:GetChildren(self.equipContainer)) do
        if child.name ~= "equipPre" then
            child:SetActive(false)
        end
    end

    local leftEquips  = leftHeroData  and leftHeroData.equipIdList  or {}
    local rightEquips = rightHeroData and rightHeroData.equipIdList or {}

    local maxEquips = math.max(#leftEquips, #rightEquips, 6)
    local itemIndex = 0

    for i = 1, maxEquips do
        itemIndex = itemIndex + 1
        local item = self:GetOrCreateEquipItem(itemIndex)
        item:SetActive(true)

        local leftRoot  = Util.GetGameObject(item, "leftEquip")
        local rightRoot = Util.GetGameObject(item, "rightEquip")
        local slotLabel = Util.GetGameObject(item, "slotLabel"):GetComponent("Text")

        slotLabel.text = GetLanguageStrById(11910 + i) or ("装备" .. i)

        self:SetEquipSlotContent(leftRoot, leftEquips[i], leftHeroData)
        self:SetEquipSlotContent(rightRoot, rightEquips[i], rightHeroData)
    end
end

function this:SetEquipSlotContent(root, equipId, heroData)
    if not heroData then
        root:SetActive(false)
        return
    end
    root:SetActive(true)
    local icon = Util.GetGameObject(root, "icon"):GetComponent("Image")
    local nameText = Util.GetGameObject(root, "name"):GetComponent("Text")
    local emptyText = Util.GetGameObject(root, "empty"):GetComponent("Text")

    if equipId and equipConfig[tonumber(equipId)] then
        local ec = equipConfig[tonumber(equipId)]
        icon.sprite = Util.LoadSprite(GetResourcePath(ec.Icon or ""))
        nameText.text = GetLanguageStrById(ec.Name or 0)
        icon.gameObject:SetActive(true)
        nameText.gameObject:SetActive(true)
        emptyText.gameObject:SetActive(false)
    else
        icon.gameObject:SetActive(false)
        nameText.gameObject:SetActive(false)
        emptyText.gameObject:SetActive(true)
        emptyText.text = "空"
    end
end

local equipItemCache = {}
function this:GetOrCreateEquipItem(index)
    if equipItemCache[index] then
        return equipItemCache[index]
    end
    local item = newObject(self.equipPre)
    item.name = "equipItem_" .. index
    item.transform:SetParent(self.equipContainer.transform)
    item.transform.localScale = Vector3.one
    item.transform.localPosition = Vector3.zero
    equipItemCache[index] = item
    return item
end

-- ============================================================
-- Radar Chart (UI Mesh Drawing)
-- ============================================================

function this:RefreshRadarChart()
    if not leftHeroData and not rightHeroData then
        self.radarImage.enabled = false
        return
    end
    self.radarImage.enabled = true

    local leftValues  = self:CalcRadarValues(leftHeroData)
    local rightValues = self:CalcRadarValues(rightHeroData)

    self:DrawRadarMesh(leftValues, rightValues)
end

function this:CalcRadarValues(heroData)
    if not heroData then return nil end

    local maxVals = self:GetRadarMaxValues()
    local values = {}
    for i, key in ipairs(radarDimensions) do
        local raw = heroData[key] or 0
        local max = maxVals[key] or 1
        values[i] = math.clamp(raw / max, 0, 1)
    end
    return values
end

function this:GetRadarMaxValues()
    local maxVals = {}
    for _, key in ipairs(radarDimensions) do
        maxVals[key] = 0
    end
    local allHeroes = HeroManager.heroDataLists
    if allHeroes then
        for _, hd in ipairs(allHeroes) do
            for _, key in ipairs(radarDimensions) do
                local v = hd[key] or 0
                if v > maxVals[key] then
                    maxVals[key] = v
                end
            end
        end
    end
    for _, key in ipairs(radarDimensions) do
        if maxVals[key] <= 0 then
            maxVals[key] = 1
        end
    end
    return maxVals
end

function this:DrawRadarMesh(leftValues, rightValues)
    local mesh = self:GetOrCreateRadarMesh()
    mesh:Clear()

    local dimCount = #radarDimensions
    local center = Vector3.zero
    local radius = 120

    local vertices = {}
    local triangles = {}
    local colors = {}
    local uvs = {}

    local function getAxisPoint(index, scale)
        local angle = (math.pi * 2 / dimCount) * index - math.pi / 2
        return Vector3(math.cos(angle) * radius * scale, math.sin(angle) * radius * scale, 0)
    end

    local gridColor = Color.New(0.4, 0.4, 0.5, 0.3)

    local vIdx = 0
    local gridLevels = { 0.25, 0.5, 0.75, 1.0 }
    for _, level in ipairs(gridLevels) do
        local baseIdx = vIdx
        for i = 0, dimCount - 1 do
            vIdx = vIdx + 1
            table.insert(vertices, getAxisPoint(i, level))
            table.insert(colors, gridColor)
            table.insert(uvs, Vector2.zero)
        end
        for i = 0, dimCount - 1 do
            local next = (i + 1) % dimCount
            table.insert(triangles, baseIdx + i)
            table.insert(triangles, baseIdx + next)
        end
    end

    local function drawFilledArea(values, color)
        if not values then return end
        local baseIdx = vIdx
        vIdx = vIdx + 1
        table.insert(vertices, center)
        table.insert(colors, Color.New(color.r, color.g, color.b, color.a * 0.2))
        table.insert(uvs, Vector2.zero)

        for i = 0, dimCount - 1 do
            vIdx = vIdx + 1
            local pt = getAxisPoint(i, values[i + 1] or 0)
            table.insert(vertices, pt)
            table.insert(colors, color)
            table.insert(uvs, Vector2.zero)
        end

        for i = 1, dimCount do
            local next = (i % dimCount) + 1
            table.insert(triangles, baseIdx)
            table.insert(triangles, baseIdx + i)
            table.insert(triangles, baseIdx + next)
        end
    end

    drawFilledArea(leftValues, Color.New(COLOR_LEFT.r, COLOR_LEFT.g, COLOR_LEFT.b, COLOR_LEFT.a))
    drawFilledArea(rightValues, Color.New(COLOR_RIGHT.r, COLOR_RIGHT.g, COLOR_RIGHT.b, COLOR_RIGHT.a))

    mesh.vertices = vertices
    mesh.triangles = triangles
    mesh.colors = colors
    mesh.uv = uvs
    mesh:RecalculateBounds()
end

local radarMeshFilter = nil
function this:GetOrCreateRadarMesh()
    if radarMeshFilter then
        return radarMeshFilter.mesh
    end

    local meshGo = GameObject.New("RadarMesh")
    meshGo.transform:SetParent(self.radarRoot.transform, false)
    meshGo.transform.localPosition = Vector3.zero
    meshGo.transform.localScale = Vector3.one
    meshGo.transform.localRotation = Quaternion.identity

    local meshFilter = meshGo:AddComponent(typeof(MeshFilter))
    local meshRenderer = meshGo:AddComponent(typeof(MeshRenderer))

    local mesh = Mesh.New()
    meshFilter.mesh = mesh

    meshRenderer.material = Material(Shader.Find("UI/Default"))
    meshRenderer.sortingOrder = self.sortingOrder or 0

    radarMeshFilter = meshFilter
    return mesh
end

-- ============================================================
-- Utility
-- ============================================================

function this:GetChildren(parentGo)
    local result = {}
    local tran = parentGo.transform
    for i = 0, tran.childCount - 1 do
        table.insert(result, tran:GetChild(i).gameObject)
    end
    return result
end

return HeroComparePanel
