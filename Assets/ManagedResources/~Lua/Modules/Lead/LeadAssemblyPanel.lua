require("Base/BasePanel")
LeadAssemblyPanel = Inherit(BasePanel)
local this = LeadAssemblyPanel
local SkillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local MotherShipPlaneConfig = ConfigManager.GetConfig(ConfigName.MotherShipPlaneConfig)--基因（主角技能）配置表
local lastBg = nil

--初始化组件（用于子类重写）
function LeadAssemblyPanel:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")
    this.mask = Util.GetGameObject(this.gameObject, "mask")

    this.skillGrid = {}
    for i = 1, 4 do
        this.skillGrid[i] = Util.GetGameObject(this.gameObject, "skillGrid").transform:GetChild(i-1).gameObject
    end

    this.skillInfo = Util.GetGameObject(this.gameObject, "skillInfo")
    this.btnEquip = Util.GetGameObject(this.gameObject, "skillInfo/btnUpLv")
    this.maxLv = Util.GetGameObject(this.gameObject, "skillInfo/maxLv")
    this.btnAssembly = Util.GetGameObject(this.gameObject, "btnAssembly")

    this.scroll = Util.GetGameObject(this.gameObject, "scroll")
    this.prefab = Util.GetGameObject(this.gameObject, "scroll/prefab")
    local v2 = this.scroll.transform.rect
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        this.prefab, nil, Vector2.New(v2.width, v2.height), 1, 4, Vector2.New(5, 5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function LeadAssemblyPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnEquip, function ()
        local curConfigId = AircraftCarrierManager.GetSingleSkillData(this.selectSkill).cfgId
        local nextConfig = AircraftCarrierManager.GetSkillNextIdForConfigId(curConfigId)
        if nextConfig then
            UIManager.OpenPanel(UIName.LeadGeneEvolutionPanel, this.selectSkill)
        else
            -- UIManager.OpenPanel(UIName.LeadGeneTopLevelPanel, selectSkill)
        end
    end)
    Util.AddClick(this.btnAssembly, function ()
        AircraftCarrierManager.EquipOrDowmSkill(this.selectSkill, function ()
        end)
    end)
end

--添加事件监听（用于子类重写）
function LeadAssemblyPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Lead.RefreshSkill, this.Refresh)
end

--移除事件监听（用于子类重写）
function LeadAssemblyPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Lead.RefreshSkill, this.Refresh)
end

--界面打开时调用（用于子类重写）
function LeadAssemblyPanel:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LeadAssemblyPanel:OnShow()
    this.Refresh()
end

--界面关闭时调用（用于子类重写）
function LeadAssemblyPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function LeadAssemblyPanel:OnDestroy()
    this.selectSkill = nil
    lastBg = nil
end

function this.Refresh()
    this.SetSkill()
    this.SetScroll(true)
end

function this.SetSkill()
    for i = 1, 4 do
        local mask = Util.GetGameObject(this.skillGrid[i], "mask")
        local icon = Util.GetGameObject(this.skillGrid[i], "mask/icon"):GetComponent("Image")
        local level = Util.GetGameObject(this.skillGrid[i], "level"):GetComponent("Image")
        local lock = Util.GetGameObject(this.skillGrid[i], "lock")
        local add = Util.GetGameObject(this.skillGrid[i], "add")

        local data
        for j = 1, #AircraftCarrierManager.LeadData.skill do
            if AircraftCarrierManager.LeadData.skill[j].sort == i then
                data = AircraftCarrierManager.LeadData.skill[j]
            end
        end
        if i > AircraftCarrierManager.GetOpenSlotMaxCnt() then
            lock:SetActive(true)
            mask:SetActive(false)
            add:SetActive(false)
            level.gameObject:SetActive(false)
        else
            lock:SetActive(false)
            add:SetActive(true)
            if data then
                mask:SetActive(true)
                level.gameObject:SetActive(true)
                local config = AircraftCarrierManager.GetSkillLvImgForId(data.cfgId)
                icon.sprite = SetIcon(data.cfgId)
                level.sprite = Util.LoadSprite(config.lvImg)
            else
                mask:SetActive(false)
                level.gameObject:SetActive(false)
            end
        end
        Util.AddOnceClick(this.skillGrid[i], function ()
            -- if add.gameObject.activeSelf then
            -- end
            if lock.gameObject.activeSelf then
                PopupTipPanel.ShowTipByLanguageId(91000254)
                return
            end
            if data then
                this.selectSkill = data.id
                this.SetScroll(false)
            end
        end)
    end
end

function this.SetScroll(isRefreshData)
    if isRefreshData then
        this.data = {}
        local equipGene = AircraftCarrierManager.EquipSkillDataToChooseList()
        for i = 1, #equipGene do
            table.insert(this.data, {
                cfgId = equipGene[i].cfgId,
                id = equipGene[i].id,
                num = 1,
            })
        end
        local bagGene = AircraftCarrierManager.GetBagAllDatas()
        table.sort(bagGene, function(a, b)
            local aConfig = MotherShipPlaneConfig[a.cfgId]
            local bConfig = MotherShipPlaneConfig[b.cfgId]
            if aConfig.Type > bConfig.Type then
                return true
            elseif aConfig.Type == bConfig.Type then
                if aConfig.Lvl > bConfig.Lvl then
                    return true
                elseif aConfig.Lvl == bConfig.Lvl then
                    return a.cfgId < b.cfgId
                end
            end
            return false
        end)
        for i = 1, #bagGene do
            table.insert(this.data, {
                cfgId = bagGene[i].cfgId,
                id = bagGene[i].id,
                num = bagGene[i].num,
            })
        end
    end
    this.scrollView:SetData(this.data, function(index, root)
        this.SetScrollItem(root, this.data[index])
    end)
end

function this.SetScrollItem(go, data)
    local lvUp = Util.GetGameObject(go, "lvUp")
    local frame = Util.GetGameObject(go, "frame"):GetComponent("Image")
    local icon = Util.GetGameObject(go, "icon"):GetComponent("Image")
    local name = Util.GetGameObject(go, "name"):GetComponent("Text")
    local level = Util.GetGameObject(go, "level"):GetComponent("Image")
    local num = Util.GetGameObject(go, "num")
    local numTxt = Util.GetGameObject(go, "num/Text"):GetComponent("Text")
    local assembly = Util.GetGameObject(go, "assembly")
    local bg = Util.GetGameObject(go, "chooseBg")

    local config = AircraftCarrierManager.GetSkillLvImgForId(data.cfgId)
    frame.sprite = Util.LoadSprite(GetQuantityImageByquality(config.config.Quality))
    icon.sprite = SetIcon(data.cfgId)
    name.text = GetLanguageStrById(config.config.Name)
    level.sprite = Util.LoadSprite(config.lvImg)
    num:SetActive(data.num > 1)
    numTxt.text = "x"..data.num
    assembly:SetActive(AircraftCarrierManager.GetSkillIsEquipForId(data.id))

    -- local nextConfig = AircraftCarrierManager.GetSkillNextIdForConfigId(data.cfgId)
    -- if nextConfig then
    --     if BagManager.GetItemCountById(config.config.CostItem[1]) >= config.config.CostItem[2] and
    --         AircraftCarrierManager.GetSkillSimilarCount(config.config.CostPlane[1], data.id) >= config.config.CostPlane[2]
    --         then
    --         lvUp:SetActive(true)
    --     else
    --         lvUp:SetActive(false)
    --     end
    -- else
    --     lvUp:SetActive(false)
    -- end
    lvUp:SetActive(AircraftCarrierManager.GetSkillIsCanLevelUp(data.cfgId, data.id))

    local func = function()
        this.selectSkill = data.id
        if lastBg then
            lastBg:SetActive(false)
        end
        bg:SetActive(true)
        lastBg = bg
        this.SetSkillInfo(data)
    end
    if this.selectSkill then
        if data.id == this.selectSkill then
            func()
        end
    else
        func()
    end
    Util.AddOnceClick(go, function ()
        func()
    end)
end

--设置技能详细信息
function this.SetSkillInfo(data)
    local frame = Util.GetGameObject(this.skillInfo, "frame"):GetComponent("Image")
    local icon = Util.GetGameObject(this.skillInfo, "icon"):GetComponent("Image")
    local name = Util.GetGameObject(this.skillInfo, "name"):GetComponent("Text")
    local skillName = Util.GetGameObject(this.skillInfo, "skillName"):GetComponent("Text")
    local type = Util.GetGameObject(this.skillInfo, "type"):GetComponent("Text")
    local desc = Util.GetGameObject(this.skillInfo, "desc"):GetComponent("Text")
    local lv = Util.GetGameObject(this.skillInfo, "lv"):GetComponent("Image")

    local config = AircraftCarrierManager.GetSkillLvImgForId(data.cfgId)
    frame.sprite = Util.LoadSprite(GetQuantityImageByquality(config.config.Quality))
    icon.sprite = SetIcon(data.cfgId)
    name.text = GetLanguageStrById(config.config.Name)
    local skillData = SkillConfig[config.config.Skill]
    skillName.text = GetLanguageStrById(skillData.Name)
    type.text = skillData.Type
    lv.sprite = Util.LoadSprite(config.lvImg)
    if skillData.Type == SkillType.Jue then
        type.text = GetLanguageStrById(12500)
    elseif skillData.Type == SkillType.Bei then
        type.text = GetLanguageStrById(12501)
    end
    desc.text = GetSkillConfigDesc(skillData)

    if AircraftCarrierManager.GetSkillIsEquipForId(data.id) then
        Util.GetGameObject(this.btnAssembly, "Text"):GetComponent("Text").text = GetLanguageStrById(22403)
        Util.GetGameObject(this.btnAssembly, "Text"):GetComponent("Text").color = Color.New(56/255,29/255,88/255,255/255)
        this.btnAssembly:GetComponent("Image").color = Color.New(172/255,101/255,255/255,255/255)
    else
        Util.GetGameObject(this.btnAssembly, "Text"):GetComponent("Text").text = GetLanguageStrById(22320)
        Util.GetGameObject(this.btnAssembly, "Text"):GetComponent("Text").color = Color.New(86/255,58/255,7/255,255/255)
        this.btnAssembly:GetComponent("Image").color = Color.New(255/255,214/255,41/255,255/255)
    end

    local nextConfig = AircraftCarrierManager.GetSkillNextIdForConfigId(data.cfgId)
    this.btnEquip:SetActive(not not nextConfig)
    this.maxLv:SetActive(not nextConfig)
end

return LeadAssemblyPanel