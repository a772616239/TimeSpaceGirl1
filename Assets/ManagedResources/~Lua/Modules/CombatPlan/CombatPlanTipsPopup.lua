require("Base/BasePanel")
CombatPlanTipsPopup = Inherit(BasePanel)
local this = CombatPlanTipsPopup
local WarWaySkillConfig = ConfigManager.GetConfig(ConfigName.WarWaySkillConfig)

local _MainProList = {}
local _SkillList = {}
local itemConfigData
local combatPlanData

--初始化组件（用于子类重写）
function CombatPlanTipsPopup:InitComponent()
    this.mask = Util.GetGameObject(self.transform, "mask")
	this.btnBack = Util.GetGameObject(self.transform, "btnBack")

    this.color = Util.GetGameObject(self.transform, "Bg/equipInfo/color"):GetComponent("Image")
    this.curEquipName = Util.GetGameObject(self.transform, "Bg/equipInfo/name"):GetComponent("Text")
    this.curEquipFrame = Util.GetGameObject(self.transform, "Bg/equipInfo/frame"):GetComponent("Image")
    this.curEquipIcon = Util.GetGameObject(self.transform, "Bg/equipInfo/icon"):GetComponent("Image")
    this.curEquipTypeText = Util.GetGameObject(self.transform, "Bg/equipInfo/equipTypeText"):GetComponent("Text")
    this.powerNum = Util.GetGameObject(self.transform, "Bg/equipInfo/powerNum"):GetComponent("Text")

    this.mainProGrid = Util.GetGameObject(self.transform, "Bg/mainPro/bg")
    this.mainProItem = Util.GetGameObject(self.transform, "Bg/mainPro/bg/curPro")
    this.mainProItem:SetActive(false)

    this.addProGrid = Util.GetGameObject(self.transform, "Bg/mainPro/addPro")
    this.addProGrid:SetActive(false)

    this.WarWayPreRoot = Util.GetGameObject(self.transform, "Bg/mainPro/skill/bg")
    this.WarWayPre = Util.GetGameObject(self.transform, "Bg/mainPro/skill/bg/WarWayPre")
    this.WarWayPre:SetActive(false)
    
    this.desc = Util.GetGameObject(self.transform, "Bg/desc/text"):GetComponent("Text")

    this.btnCompond = Util.GetGameObject(self.transform, "Bg/btns/btnCompond")
    this.btnReset = Util.GetGameObject(self.transform, "Bg/btns/btnReset")

    this.btnRed = Util.GetGameObject(self.transform, "Bg/btns/btn1")
    this.btnYel = Util.GetGameObject(self.transform, "Bg/btns/btn2")
    this.btnRedTxt = Util.GetGameObject(this.btnRed.transform, "Text"):GetComponent("Text")
    this.btnYelTxt = Util.GetGameObject(this.btnYel.transform, "Text"):GetComponent("Text")

    this.btns = Util.GetGameObject(self.transform, "Bg/btns")
end

--绑定事件（用于子类重写）
function CombatPlanTipsPopup:BindEvent()
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnCompond, function()
        self:ClosePanel()
        if combatPlanData.Quality < 5 then
            -- 戒指合成
            UIManager.OpenPanel(UIName.CompoundPanel, 2)
        elseif combatPlanData.Quality == 5 then
            --戒指精炼
            JumpManager.GoJump(99999)
        end
    end)

    Util.AddClick(this.btnReset, function()
        self:ClosePanel()
        if this.type == 1 then
            if  this.planDatas.bData.promotionLevel ~= 0  then
                PopupTipPanel.ShowTipByLanguageId(23029)
                return
            end
        elseif this.type == 2 then
            if  this.planData.promotionLevel ~= 0 then
                PopupTipPanel.ShowTipByLanguageId(23029)
                return
            end
        end
        CombatPlanManager.RequestEgData(function()
            UIManager.OpenPanel(UIName.EquipPlanResetPopup, this.planDid)
        end)
        
    end)
    Util.AddClick(this.btnRed, function()
        if this.type == 1 then
            -- 卸下
            CombatPlanManager.DownPlan(this.heroData.dynamicId, this.planDatas.bData.id, this.planDatas.sData.position, function()
                self:ClosePanel()
                this.openParent.UpdateEquipPosHeroData(3, 2, this.planDatas.bData.id, nil, this.planDatas.sData.position + 4)
            end)
        elseif this.type == 2 then
            -- 分解
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.DecomposePlan, this.planData)
            self:ClosePanel()
        end
    end)
    Util.AddClick(this.btnYel, function()
        if this.type == 1 then
            -- 替换
            UIManager.OpenPanel(UIName.CombatPlanSelectPopup, this.heroData, this.planDatas.sData.position + 4, this.openParent, this.planDatas.bData.id)
            self:ClosePanel()
        elseif this.type == 2 then
            -- 分配
            JumpManager.GoJump(22001)
            self:ClosePanel()
        end
    end)
end

--添加事件监听（用于子类重写）
function CombatPlanTipsPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function CombatPlanTipsPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function CombatPlanTipsPopup:OnOpen(...)
    local args = {...}
    this.type = args[1]         -- 1装备界面 2背包 3tips 4晋级 
    -- 1
    this.openParent = args[2]
    this.planDatas = args[3]
    this.heroData = args[4]
    this.pre1 = args[5]
    this.pre2 = args[6]
    -- 2
    this.planData = args[7]

    if this.type == 1 then
        this.planDid = this.planDatas.bData.id
    elseif this.type == 2 then
        this.planDid = this.planData.id
    elseif this.type == 3 then
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function CombatPlanTipsPopup:OnShow()
    this.btns:SetActive(true)
    if this.type == 1 then
        this.btnRedTxt.text = GetLanguageStrById(22403)
        this.btnYelTxt.text = GetLanguageStrById(22404)
        this.SetUI(this.planDatas.bData)
    elseif this.type == 2 then
        this.btnRedTxt.text = GetLanguageStrById(22401)
        this.btnYelTxt.text = GetLanguageStrById(22402)
        this.SetUI(this.planData)
    elseif this.type == 3 then
        this.SetUI(this.planData)
        this.btns:SetActive(false)
    elseif this.type == 4 then
        this.btns:SetActive(false)
        if this.planData.promotionLevel <= 1 then
            this.addProGrid:SetActive(true)
        else
            this.addProGrid:SetActive(false)
        end
        this.SetUIUpgrade(this.planData)
    end

    Util.SetGray(this.btnCompond,false)
    this.btnCompond:GetComponent("Button").enabled = true
    if combatPlanData.Quality == 5 then
        --精炼
        Util.GetGameObject(this.btnCompond,"Text"):GetComponent("Text").text = GetLanguageStrById(50150)
    elseif combatPlanData.Quality == 6 then
        --已精炼
        Util.SetGray(this.btnCompond,true)
        this.btnCompond:GetComponent("Button").enabled = false
        Util.GetGameObject(this.btnCompond,"Text"):GetComponent("Text").text = GetLanguageStrById(50151)
    else
        --合成
        Util.GetGameObject(this.btnCompond,"Text"):GetComponent("Text").text = GetLanguageStrById(50152)
    end
end

function CombatPlanTipsPopup.SetUI(_planData)
    local planData = _planData
    itemConfigData = G_ItemConfig[planData.combatPlanId]
    combatPlanData = G_CombatPlanConfig[planData.combatPlanId]

    -- this.powerNum.text = CombatPlanManager.CalPlanPower(planData.id)
    this.powerNum.text = CombatPlanManager.CalPlanPowerByProperty(planData.property)

    local quality = 0
    if combatPlanData.Quality ~= 6 then
        quality = combatPlanData.Quality + 1
    else
        quality = combatPlanData.Quality
    end

    local lv
    if CombatPlanManager.GetPlanData(planData.id) then 
        lv = CombatPlanManager.GetPlanData(planData.id).promotionLevel
    else
        lv = planData.promotionLevel
    end

    if lv > 0 and lv < 3 then
        this.curEquipName.text = GetStringByEquipQua(quality, GetLanguageStrById(combatPlanData.Name)) .. "+" .. lv
    else
        this.curEquipName.text = GetStringByEquipQua(quality, GetLanguageStrById(combatPlanData.Name))
    end

    this.desc.text = GetLanguageStrById(itemConfigData.ItemDescribe)
    this.color.sprite = Util.LoadSprite(GetQuantityTipsColorByQuality(quality))
    this.curEquipFrame.sprite = Util.LoadSprite(GetQuantityImageByquality(quality))
    this.curEquipIcon.sprite = Util.LoadSprite(combatPlanData.Icon)
    this.curEquipTypeText.text = string.format(GetEquipPosStrByEquipPosNum(5))

    --主属性
    for _, item in ipairs(_MainProList) do
        item:SetActive(false)
    end

    local mainAttribute = CombatPlanManager.GetMainProListByProperty(planData.property)
    for index, prop in ipairs(mainAttribute) do
        local proConfigData = ConfigManager.GetConfigData(ConfigName.PropertyConfig, prop.propertyId)
        if proConfigData then
            if not _MainProList[index] then
                _MainProList[index] = newObjToParent(this.mainProItem, this.mainProGrid)
            end
            _MainProList[index]:SetActive(true)
            Util.GetGameObject(_MainProList[index], "curProName"):GetComponent("Text").text = GetLanguageStrById(proConfigData.Info)
            Util.GetGameObject(_MainProList[index], "curProIcon"):GetComponent("Image").sprite = Util.LoadSprite(proConfigData.val[12])

            local vText = Util.GetGameObject(_MainProList[index], "curProVale"):GetComponent("Text")
            if prop.propertyValue > 0 then
                vText.text = "+"..GetPropertyFormatStr(proConfigData.Style, prop.propertyValue)
            else 
                vText.text = GetPropertyFormatStr(proConfigData.Style, prop.propertyValue)
            end
        end
    end

    -- skill
    for _, item in ipairs(_SkillList) do
        item:SetActive(false)
    end

    for i = 1, #planData.skill do
        local skillId = planData.skill[i]
        if skillId then
            if not _SkillList[i] then
                _SkillList[i] = newObjToParent(this.WarWayPre, this.WarWayPreRoot)
            end
            _SkillList[i]:SetActive(true)
            local passivityConfig = G_PassiveSkillConfig[skillId]
            Util.GetGameObject(_SkillList[i], "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(passivityConfig.Icon))
            Util.GetGameObject(_SkillList[i], "Name"):GetComponent("Text").text = this.SetNameColor(GetLanguageStrById(passivityConfig.Name),WarWaySkillConfig[skillId].Level)
            Util.GetGameObject(_SkillList[i], "Des"):GetComponent("Text").text = GetSkillConfigDesc(passivityConfig, false, 1)
        end
    end

    if #planData.skill == 0 then
        Util.GetGameObject(this.transform, "Bg/mainPro/skill"):SetActive(false)
    else
        Util.GetGameObject(this.transform, "Bg/mainPro/skill"):SetActive(true)
    end
end

function CombatPlanTipsPopup.SetUIUpgrade(_planData)
    local planData = _planData
    local itemConfigData = G_ItemConfig[planData.combatPlanId]
    local combatPlanData = G_CombatPlanConfig[planData.combatPlanId]

    local qualityid = CombatPlanManager.SetQuality(combatPlanData.Quality)

    this.powerNum.text = CombatPlanManager.CalPlanPowerByProperty(planData.property)

    this.desc.text = GetLanguageStrById(itemConfigData.ItemDescribe)
    this.color.sprite = Util.LoadSprite(GetQuantityTipsColorByQuality(qualityid))
    this.curEquipName.text = GetStringByEquipQua(qualityid, GetLanguageStrById(combatPlanData.Name))
    this.curEquipFrame.sprite = Util.LoadSprite(GetQuantityImageByquality(qualityid))
    this.curEquipIcon.sprite = Util.LoadSprite(combatPlanData.Icon)
    this.curEquipTypeText.text = string.format(GetEquipPosStrByEquipPosNum(5))
    LogError(CombatPlanManager.GetPlanData(planData.id).promotionLevel)

    --主属性
    for _, item in ipairs(_MainProList) do
        item:SetActive(false)
    end

    local mainAttribute = CombatPlanManager.GetMainProListByProperty(planData.property)
    for index, prop in ipairs(mainAttribute) do
        local proConfigData = ConfigManager.GetConfigData(ConfigName.PropertyConfig, prop.propertyId)
        if proConfigData then
            if not _MainProList[index] then
                _MainProList[index] = newObjToParent(this.mainProItem, this.mainProGrid)
            end
  
            _MainProList[index]:SetActive(true)
            Util.GetGameObject(_MainProList[index], "curProName"):GetComponent("Text").text = GetLanguageStrById(proConfigData.Info)
            Util.GetGameObject(_MainProList[index], "curProIcon"):GetComponent("Image").sprite = Util.LoadSprite(proConfigData.val[12])

            local vText = Util.GetGameObject(_MainProList[index], "curProVale"):GetComponent("Text")
            if prop.propertyValue > 0 then
                if this.planData.promotionLevel < 1 then
                   --属性值加倍(1类型)
                   if proConfigData.Style == 1 then
                    vText.text = "<B><color=#FFD12B>+"..GetPropertyFormatStr(proConfigData.Style, prop.propertyValue+prop.propertyValue) .."</color></B>"
                   else
                     vText.text = "+"..GetPropertyFormatStr(proConfigData.Style, prop.propertyValue)
                   end
                else
                    vText.text = "+"..GetPropertyFormatStr(proConfigData.Style, prop.propertyValue)
                end
            else
                vText.text = GetPropertyFormatStr(proConfigData.Style, prop.propertyValue)
            end
        end
    end

    -- skill
    for _, item in ipairs(_SkillList) do
        item:SetActive(false)
    end
    for i = 1, #planData.skill do
        local skillId = planData.skill[i]
        if skillId then
            if this.planData.promotionLevel <= 2 then
                skillId = skillId + 1
            end
            if not _SkillList[i] then
                _SkillList[i] = newObjToParent(this.WarWayPre, this.WarWayPreRoot)
            end
            _SkillList[i]:SetActive(true)
            local passivityConfig = G_PassiveSkillConfig[skillId]
            Util.GetGameObject(_SkillList[i], "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(passivityConfig.Icon))
            Util.GetGameObject(_SkillList[i], "Name"):GetComponent("Text").text = this.SetNameColor(GetLanguageStrById(passivityConfig.Name),WarWaySkillConfig[skillId].Level)
            Util.GetGameObject(_SkillList[i], "Des"):GetComponent("Text").text = GetLanguageStrById(GetSkillConfigDesc(passivityConfig, false, 1))
        end
    end

    if #planData.skill == 0 then
        Util.GetGameObject(this.transform, "Bg/mainPro/skill"):SetActive(false)
    else
        Util.GetGameObject(this.transform, "Bg/mainPro/skill"):SetActive(true)
    end
end

function this.SetNameColor(_name,_level)
    if _level == 1 then
        return string.format("<color=#9fff88>%s</color>",_name)
    elseif _level == 2 then
        return string.format("<color=#88e4ff>%s</color>",_name)
    elseif _level == 3 then
        return string.format("<color=#f088ff>%s</color>",_name)
    elseif _level == 4 then
        return string.format("<color=#ffba88>%s</color>",_name)
    elseif _level == 5 then
        return string.format("<color=#ff6868>%s</color>",_name)
    else
        return _name
    end
end

--界面关闭时调用（用于子类重写）
function CombatPlanTipsPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function CombatPlanTipsPopup:OnDestroy()
    _MainProList = {}
    _SkillList = {}
end

return CombatPlanTipsPopup