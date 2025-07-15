--[[
 * @ClassName DiffMonsterUpGradSuccessPanel
 * @Description 异妖升阶成功界面
 * @Date 2019/5/16 10:30
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class DiffMonsterUpGradSuccessPanel
local DiffMonsterUpGradSuccessPanel = quick_class("DiffMonsterUpGradSuccessPanel", BasePanel)

function DiffMonsterUpGradSuccessPanel:InitComponent()
    self.effect = self.transform:Find("effect")

    self.live2dRoot = self.transform:Find("live2dRoot")
    self.diffName = self.transform:Find("nameBg/name"):GetComponent("Text")

    self.descName = self.transform:Find("descBg/container/name"):GetComponent("Text")
    self.descLv = self.transform:Find("descBg/container/lv"):GetComponent("Text")

    self.skillInfo = self.transform:Find("skillInfoBg")
    self.skillIcon = self.skillInfo:Find("skillIconBg/icon"):GetComponent("Image")
    self.skillLevel = self.skillInfo:Find("skillLevel"):GetComponent("Text")
    self.skillDesc = self.skillInfo:Find("skilldesc"):GetComponent("Text")

    self.btnConfirm = self.transform:Find("btnConfirm")

    screenAdapte(self.effect)

end

function DiffMonsterUpGradSuccessPanel:BindEvent()
    Util.AddClick(self.btnConfirm.gameObject, function()
        self:ClosePanel()
        UIManager.OpenPanel(UIName.DemonInfoPanel, { pokemon = DiffMonsterManager.GetSinglePokemonData(self.pokemon.id) })
    end)
end

function DiffMonsterUpGradSuccessPanel:OnOpen(pokemon)
    -- 播放声音
    SoundManager.PlaySound(SoundConfig.Sound_Recruit3)

    self.pokemon = pokemon
    self.effect.gameObject:SetActive(true)
    self:SetBasicStatus(pokemon)
    self:SetSkillStatus(pokemon)
end

function DiffMonsterUpGradSuccessPanel:OnClose()
    self.effect.gameObject:SetActive(false)
    if self.LiveName then
        poolManager:UnLoadLive(self.LiveName, self.LiveGO)
        self.LiveName = nil
    end
end

function DiffMonsterUpGradSuccessPanel:SetBasicStatus(pokemon)
    --立绘
    if self.LiveName then
        poolManager:UnLoadLive(self.LiveName, self.LiveGO)
        self.LiveName = nil
    end

    local demonId = pokemon.id
    self.LiveName = DiffMonsterManager.demonlive2dInfo[demonId].Name

    self.LiveGO = poolManager:LoadLive(self.LiveName, self.live2dRoot.transform, DiffMonsterManager.demonlive2dInfo[demonId].Scale, Vector3.zero)
    self.LiveGO:GetComponent("RectTransform").anchoredPosition = DiffMonsterManager.demonlive2dInfo[demonId].Position

    --基础信息
    local demonConfig = ConfigManager.GetConfigData(ConfigName.DifferDemonsConfig, demonId)
    self.diffName.text = demonConfig.Name
    self.descName.text = demonConfig.Name
    self.descLv.text = "+" .. pokemon.stage
end

function DiffMonsterUpGradSuccessPanel:SetSkillStatus(pokemon)
    local skillId = pokemon.pokemonUpLvConfigList[pokemon.stage].configData.SkillId
    local skillConfig = ConfigManager.GetConfigData(ConfigName.SkillConfig, skillId)
    if skillConfig then
        self.skillIcon.sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
        self.skillLevel.text = GetLanguageStrById(10470) .. pokemon.stage
        self.skillDesc.text = GetSkillConfigDesc(skillConfig)
    end
end

return DiffMonsterUpGradSuccessPanel