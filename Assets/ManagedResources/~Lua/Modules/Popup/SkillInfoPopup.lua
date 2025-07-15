require("Base/BasePanel")
require("Modules/RoleInfo/RoleInfoPanel")
SkillInfoPopup = Inherit(BasePanel)
local this = SkillInfoPopup
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local passiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
this.buffList = {}

local skillUseType = {
    HERO_SKILL = 1,
    CV_SKILL = 2,
}

--初始化组件（用于子类重写）
function this:InitComponent()
    this.content = Util.GetGameObject(self.transform, "Content"):GetComponent("RectTransform")
    this.backBtn = Util.GetGameObject(self.transform, "Button")
    -- this.skillTypeImage=Util.GetGameObject(self.transform,"Content/SkillTypeImage"):GetComponent("Image")
    this.icon = Util.GetGameObject(self.transform, "Content/IconBG/Icon"):GetComponent("Image")
    -- this.skillLv = Util.GetGameObject(self.transform, "Content/IconBG/Level/Text"):GetComponent("Text")
    this.skillName = Util.GetGameObject(self.transform, "Content/Title/Text"):GetComponent("Text")
    this.skillTypeTxt = Util.GetGameObject(self.transform,"Content/Title/type"):GetComponent("Text")
    -- this.desc = Util.GetGameObject(self.transform, "Content/Desc/Text"):GetComponent("Text")
    this.cureffect = Util.GetGameObject(self.transform, "Content/CurrentLvDesc/Text"):GetComponent("Text")
    this.CD = Util.GetGameObject(self.transform, "Content/CurrentLvDesc/CD")
    this.CDtext = Util.GetGameObject(self.transform, "Content/CurrentLvDesc/CD"):GetComponent("Text")
    this.LevUpCond = Util.GetGameObject(self.transform, "Content/CurrentLvDesc/LevUpCond")
    this.LevUpCondtext = Util.GetGameObject(self.transform, "Content/CurrentLvDesc/LevUpCond"):GetComponent("Text")
    this.buffPreParent = Util.GetGameObject(self.transform, "Content/CurrentLvDesc/Buff")
    this.buffPre = Util.GetGameObject(self.transform, "Content/CurrentLvDesc/Buff/BuffPre")
    this.buffDes = Util.GetGameObject(self.transform, "Content/CurrentLvDesc/BuffDes"):GetComponent("Text")
    -- this.skillNextObg = Util.GetGameObject(self.transform, "Content/NextLv")
    -- this.skillNextObg:SetActive(false)
    -- this.nextEffect = Util.GetGameObject(self.transform, "Content/NextLv/NextLvDesc/Text"):GetComponent("Text")

    this.rect = Util.GetGameObject(self.transform,"Content"):GetComponent("RectTransform")

    this.BuffDes = Util.GetGameObject(self.transform, "Content/CurrentLvDesc/BuffDes")
    this.BuffDesText = Util.GetGameObject(self.transform, "Content/CurrentLvDesc/BuffDes"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()

end

--移除事件监听（用于子类重写）
function this:RemoveListener()

end

function this:OnShow()
    for i = 1, #this.buffList do
        this.buffList[i]:SetActive(false)
    end
    if not this.skillData.skillConfig.Type == SkillType.Bei then
        for i = 2, #this.skillData.skillConfig.Desc do
            if this.buffList[i-1] == nil then
                this.buffList[i-1] = newObject(this.buffPre)
                this.buffList[i-1].transform:SetParent(this.buffPreParent.transform)
                this.buffList[i-1].transform.localScale = Vector3.one
                this.buffList[i-1].transform.localPosition = Vector3.zero
            end
            this.buffList[i-1]:GetComponent("Text").text = GetSkillConfigDesc(this.skillData.skillConfig)
            this.buffList[i-1]:SetActive(true)
        end

        this.buffPreParent:SetActive(#this.skillData.skillConfig.Desc > 0)
    else
        this.buffPreParent:SetActive(false)
    end
end

--界面打开时调用（用于子类重写）
--1:skillData 2:openType 3:nil 4:maxLv 5:skilltype 6:lv 7:useType 8:describe
function this:OnOpen(...)
    this.rect = Util.GetGameObject(GameObject.Find("SkillInfoPopup").transform,"Content"):GetComponent("RectTransform")
    this.curLvRect = Util.GetGameObject(self.transform,"Content"):GetComponent("RectTransform")
    local args = { ... }
    this.skillData = args[1]
    local openType = args[2]
    local maxLv = args[4]
    local skilltype = args[5]
    local lv = args[6]
    this.icon.sprite = Util.LoadSprite(GetResourcePath(this.skillData.skillConfig.Icon))
    if lv then
        this.skillName.text = GetLanguageStrById(this.skillData.skillConfig.Name) .. "  Lv." .. lv
    else
        this.skillName.text = GetLanguageStrById(this.skillData.skillConfig.Name)
    end

    this.useType = args[7] or 1  -- 技能应用类型
    this.skillId = args[8]

    local config
    if this.skillId then
        config = skillConfig[this.skillId]
    else
        config = this.skillData.skillConfig
    end

    --获取RoleInfoPanel的curUpStarData，以获取英雄最高等级
    if this.skillData.skillConfig.Type == SkillType.Pu then--普攻
    elseif this.skillData.skillConfig.Type == SkillType.Jue then--主动
        if lv and maxLv and lv < maxLv then
            local skillUpData
            if this.skillData.lock then
                skillUpData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.UnlockSkill, "SkillPos", skilltype, "UnlockLV", lv)
                this.LevUpCondtext.text = string.format(GetLanguageStrById(12565),skillUpData.Rank)
            else
                skillUpData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.UnlockSkill, "SkillPos", skilltype, "UnlockLV", lv+1)
                this.LevUpCondtext.text = string.format(GetLanguageStrById(12563),skillUpData.Star)
            end
            this.LevUpCond:SetActive(true)
        else
            this.LevUpCond:SetActive(false)
        end
        this.CD:SetActive(true)
        this.CDtext.text = string.format(GetLanguageStrById(12562), SkillLogicConfig[this.skillData.skillConfig.Id].release, SkillLogicConfig[this.skillData.skillConfig.Id].CD)
        this.skillTypeTxt.text = GetLanguageStrById(12500)
        if this.skillId then
            this.cureffect.text = GetSkillConfigDesc(config)
        else
            this.cureffect.text = GetSkillConfigDesc(config)
        end

        if this.useType == skillUseType.HERO_SKILL then
            this.CD:SetActive(true)
        elseif this.useType == skillUseType.CV_SKILL then
            this.CD:SetActive(false)
        end
    elseif this.skillData.skillConfig.Type == SkillType.Bei then--被动
        this.CD:SetActive(false)
        if lv and maxLv and lv < maxLv then
            local skillUpData
            if this.skillData.lock then
                skillUpData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.UnlockSkill, "SkillPos", skilltype, "UnlockLV", lv)
                this.LevUpCondtext.text = string.format(GetLanguageStrById(12565),skillUpData.Rank)
            else
                skillUpData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.UnlockSkill, "SkillPos", skilltype, "UnlockLV", lv+1)
                this.LevUpCondtext.text = string.format(GetLanguageStrById(12563),skillUpData.Star)
            end
            this.LevUpCond:SetActive(true)
        else
            this.LevUpCond:SetActive(false)
        end
        this.skillTypeTxt.text = GetLanguageStrById(12501)
        if this.skillId then
            this.cureffect.text = GetLanguageStrById(passiveSkillConfig[this.skillId].Desc)
        else
            this.cureffect.text = GetLanguageStrById(this.skillData.skillConfig.Desc)
        end
    end
    this.cureffect.transform:DOAnchorPosY(0,0,true)
    this.buffDes.gameObject:SetActive(false)

    if this.skillData.skillConfig.Type == SkillType.Pu or this.skillData.skillConfig.Type == SkillType.Jue then
        if this.skillData.skillConfig.BuffDesc ~= nil and this.skillData.skillConfig.BuffDesc ~= "" then
            local data = {}
            data.DescColor = config.BuffDescColor
            data.DescValue = config.BuffDescValue
            data.Desc = config.BuffDesc
            this.buffDes.text = GetSkillConfigDesc(data, false, 3)
            this.buffDes.gameObject:SetActive(true)
        end
    end

    for i = 1, #this.buffList do
        this.buffList[i]:SetActive(false)
    end
    if not this.skillData.skillConfig.Type == SkillType.Bei then
        for i = 2, #this.skillData.skillConfig.Desc do
            if this.buffList[i-1] == nil then
                this.buffList[i-1] = newObject(this.buffPre)
                this.buffList[i-1].transform:SetParent(this.buffPreParent.transform)
                this.buffList[i-1].transform.localScale = Vector3.one
                this.buffList[i-1].transform.localPosition = Vector3.zero
            end
            this.buffList[i-1]:SetActive(true)
            this.buffList[i-1]:GetComponent("Text").text = GetSkillConfigDesc(this.skillData.skillConfig)
        end
        this.buffPreParent:SetActive(config.Desc > 0)
    else
        this.buffPreParent:SetActive(false)
    end
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

function this.CheckPointer()
    local update
    update = function()
        if Input.GetMouseButtonDown(0) then
            local v2 = Input.mousePosition

            this.value0,this.value1 = RectTransformUtility.ScreenPointToLocalPointInRectangle(this.rect,v2,UIManager.camera,nil)

            if this.value1.x > this.curLvRect.sizeDelta.x and
                this.value1.x < 0
            then
                return
            end
            this.rect = nil
            this:ClosePanel()
            UpdateBeat:Remove(update, this)
        end
    end
    UpdateBeat:Add(update, this)
end

return SkillInfoPopup;