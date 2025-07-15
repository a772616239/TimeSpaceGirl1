--[[
 * @ClassName DiffMonsterPreviewPanel
 * @Description 异妖预览查看
 * @Date 2019/5/11 14:50
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class DiffMonsterPreviewPanel
local DiffMonsterPreviewPanel = quick_class("DiffMonsterPreviewPanel", BasePanel)

local kInitLevel = 1
local partTypeDef = {
    UnLock = 1,
    Lock = 2,
    Add = 3
}

function DiffMonsterPreviewPanel:InitComponent()
    self.effectBg = Util.GetGameObject(self.transform, "effectBg")
    self.bg = Util.GetGameObject(self.transform, "uiBg")
    self.monsterLockIcon = Util.GetGameObject(self.bg, "lockIcon"):GetComponent("Image")
    self.diffName = Util.GetGameObject(self.bg, "nameBg/name"):GetComponent("Text")

    self.intelligenceBg=Util.GetGameObject(self.bg,"intelligenceBg"):GetComponent("Image")
    self.intelligenceValue = Util.GetGameObject(self.bg, "intelligenceBg/value"):GetComponent("Text")

    self.compContent = Util.GetGameObject(self.bg, "compList/compViewRect/content")
    self.compItemPro = Util.GetGameObject(self.compContent, "compPre")
    self.compItemPro.gameObject:SetActive(false)
    self.compList = {}

    self.skillInfo = Util.GetGameObject(self.bg, "skillInfo")
    self.skillIcon = Util.GetGameObject(self.skillInfo, "skillIcon"):GetComponent("Image")
    self.skillName = Util.GetGameObject(self.skillInfo, "skillNameBg/skillName"):GetComponent("Text")
    self.skillDesc = Util.GetGameObject(self.skillInfo, "skillDesc"):GetComponent("Text")

    self.backBtn = Util.GetGameObject(self.bg, "btnBack")

    self.pokemon = nil

    screenAdapte(self.effectBg)

end

function DiffMonsterPreviewPanel:BindEvent()
    Util.AddClick(self.backBtn, function()
        self:ClosePanel()
        UIManager.OpenPanel(UIName.DemonActivatePanel, { pokemon = self.pokemon })
    end)
end

function DiffMonsterPreviewPanel:OnOpen(_pokemon)
    self.pokemon = _pokemon
    self:SetMonster(_pokemon)
    self:SetCompList(_pokemon)
    self:SetSkill(_pokemon)
end

function DiffMonsterPreviewPanel:OnClose()
    table.walk(self.compList, function(compItem)
        destroy(compItem.gameObject)
    end)
    self.compList = {}
end

function DiffMonsterPreviewPanel:SetMonster(pokemon)
    local pokemonConfig = ConfigManager.GetConfigData(ConfigName.DifferDemonsConfig, pokemon.id)
    self.diffName.text = pokemonConfig.Name
    self.monsterLockIcon.sprite = Util.LoadSprite(DiffMonsterIconDef[pokemon.id])
    self.monsterLockIcon:SetNativeSize()
    self.intelligenceBg.sprite=GetQuantityImage(pokemonConfig.Aptitude)
    self.intelligenceValue.text = pokemonConfig.Aptitude
end

function DiffMonsterPreviewPanel:SetCompList(pokemon)
    for idx, pokeCompInfo in ipairs(pokemon.pokemoncomonpentList) do
        local comp = newObjToParent(self.compItemPro, self.compContent)
        comp:GetComponent("Image").sprite = SetFrame(pokeCompInfo.id)
        if pokeCompInfo.level > 0 then
            self:DealWithInlay(comp, pokeCompInfo)
        else
            if BagManager.GetItemCountById(pokeCompInfo.id) > 0 then
                self:DealWithCanBeInlay(comp, pokeCompInfo, idx)
            else
                self:DealWithUnlay(comp, pokeCompInfo)
            end
        end
        table.insert(self.compList, comp)
    end
end

--处理已镶嵌的
function DiffMonsterPreviewPanel:DealWithInlay(comp, pokeCompInfo)
    self:SetPartActive(comp, partTypeDef.UnLock)
    local unlockPart = Util.GetGameObject(comp, "unlockPart")
    local compImage = Util.GetGameObject(comp, "unlockPart/icon"):GetComponent("Image")
    compImage.sprite = SetIcon(pokeCompInfo.id)
    compImage:SetNativeSize()
    Util.GetGameObject(comp, "unlockPart/levelBg/value"):GetComponent("Text").text = "+" .. pokeCompInfo.level
    --Util.GetGameObject(comp, "unlockPart/upGradFlag").gameObject:SetActive(self:JudgeComponentCanBeUpData(pokeCompInfo))
    Util.GetGameObject(comp, "unlockPart/upGradFlag").gameObject:SetActive(false)
    Util.AddOnceClick(unlockPart, function()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, pokeCompInfo.id)
    end)
end

--处理未镶嵌的
function DiffMonsterPreviewPanel:DealWithUnlay(comp, pokeCompInfo)
    self:SetPartActive(comp, partTypeDef.Lock)
    local lockPart = Util.GetGameObject(comp, "lockPart")
    Util.GetGameObject(comp, "lockPart/icon"):GetComponent("Image").sprite = SetIcon(pokeCompInfo.id)
    Util.AddClick(lockPart, function()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, pokeCompInfo.id)
    end)
end

--处理可镶嵌的
function DiffMonsterPreviewPanel:DealWithCanBeInlay(comp, pokeCompInfo, idx)
    self:SetPartActive(comp, partTypeDef.Add)
    local addPart = Util.GetGameObject(comp, "addPart")
    Util.AddClick(addPart, function()
        NetManager.DemonCompUpRequest(self.pokemon.id, pokeCompInfo.id, function()
            addPart.gameObject:SetActive(false)
            --BagManager.UpdateItemsNum(pokeCompInfo.id, 1)
            DiffMonsterManager.UpdatePokemonPeiJianLv(self.pokemon.id, pokeCompInfo.id, 1)
            UIManager.OpenPanel(UIName.DemonPartsActiveSuccessPanel, { pokemon = self.pokemon, index = idx })
            local newPokeCompInfo = self.pokemon.pokemoncomonpentList[idx]
            self:DealWithInlay(comp, newPokeCompInfo)
        end)
    end)
end

--判断部件是否可以升级
function DiffMonsterPreviewPanel:JudgeComponentCanBeUpData(componentInfo)
    local maxLv = #componentInfo.upLvMateriaConfiglList
    local currentLv = componentInfo.level + 1
    if currentLv >= maxLv then
        return false
    else
        local materialEnough = true
        local costMaterials = componentInfo.upLvMateriaConfiglList[currentLv].Cost
        for idx = 1, #costMaterials do
            materialEnough = materialEnough and self:MaterialEnoughOrNot(costMaterials[idx][1], costMaterials[idx][2])
        end
        return materialEnough
    end
end

function DiffMonsterPreviewPanel:MaterialEnoughOrNot(propId, needNumber)
    local ownNumber = BagManager.GetItemCountById(propId)
    return ownNumber >= needNumber
end

function DiffMonsterPreviewPanel:SetSkill(pokemon)
    local skillId = pokemon.pokemonUpLvConfigList[kInitLevel].configData.SkillId
    local skillConfig = ConfigManager.TryGetConfigData(ConfigName.SkillConfig, skillId)
    if skillConfig then
        self.skillIcon.sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
        self.skillName.text = GetLanguageStrById(skillConfig.Name)
        self.skillDesc.text = GetSkillConfigDesc(skillConfig)
    end
end

function DiffMonsterPreviewPanel:SetPartActive(comp, index)
    Util.GetGameObject(comp, "unlockPart"):SetActive(index == partTypeDef.UnLock)
    Util.GetGameObject(comp, "lockPart"):SetActive(index == partTypeDef.Lock)
    Util.GetGameObject(comp, "addPart"):SetActive(index == partTypeDef.Add)
end

return DiffMonsterPreviewPanel