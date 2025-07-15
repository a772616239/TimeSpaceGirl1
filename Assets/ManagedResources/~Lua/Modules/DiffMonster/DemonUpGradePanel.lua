--[[
 * @ClassName DemonUpGradePanel
 * @Description 异妖进阶材料界面
 * @Date 2019/5/14 16:09
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class DemonUpGradePanel
local DemonUpGradePanel = quick_class("DemonUpGradePanel", BasePanel)

local ColorDef = {
    "#FFF2C8FF",
    "#635D4AFF",
}

function DemonUpGradePanel:InitComponent()
    self.closeBtn = Util.GetGameObject(self.gameObject, "bg/closeBtn")
    self.demonName = Util.GetGameObject(self.gameObject, "bg/demonName"):GetComponent("Text")
    --skillPart
    self.skillInfo = Util.GetGameObject(self.gameObject, "bg/skillInfo")
    self.skillIcon = Util.GetGameObject(self.skillInfo, "skillBg/skillIcon"):GetComponent("Image")
    self.skillName = Util.GetGameObject(self.skillInfo, "skillName"):GetComponent("Text")
    self.currentLv = Util.GetGameObject(self.skillInfo, "levelBg/currentLv"):GetComponent("Text")
    self.nextLv = Util.GetGameObject(self.skillInfo, "levelBg/nextLv"):GetComponent("Text")
    self.effectDesc = Util.GetGameObject(self.skillInfo, "effectDesc"):GetComponent("Text")
    --effectPart
    self.effectContent = Util.GetGameObject(self.gameObject, "bg/effectList")
    self.effectPre = Util.GetGameObject(self.effectContent, "content/effectPro")
    self.effectPre.gameObject:SetActive(false)

    local v2 = self.effectContent:GetComponent("RectTransform").rect
    self.effectList = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetTransform(self.transform, "bg"),
            self.effectPre, nil, Vector2.New(-v2.x * 2, -v2.y * 2), 1, 1, Vector2.New(0, 5))
    self.effectList.moveTween.MomentumAmount = 1
    self.effectList.moveTween.Strength = 2

    --upGradPart
    self.itemContent = Util.GetGameObject(self.gameObject, "bg/rect/grid")
    self.itemPre = Util.GetGameObject(self.itemContent, "itemPro")
    self.itemPre.gameObject:SetActive(false)
    self.itemList = {}
    self.costCount = Util.GetGameObject(self.gameObject, "bg/costIcon/costCount")
    self.DemonUpGradeBtn = Util.GetGameObject(self.gameObject, "bg/btnBreak")
    self.breakTips = Util.GetGameObject(self.gameObject, "bg/breakTips"):GetComponent("Text")

    self.upStarMaterial = nil

end

function DemonUpGradePanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)

    Util.AddClick(self.DemonUpGradeBtn, function()
        self:onDemonUpGradeBtnClicked()
    end)
end

function DemonUpGradePanel:OnOpen(pokemon)
    self.pokemon = pokemon
    self:SetSkillInfoPart(pokemon)
    self:SetExtraEffectPart(pokemon)
    self:SetMaterialCostPart(pokemon)
end

function DemonUpGradePanel:OnClose()
    self:ClearItemList()
end

--设置技能相关
function DemonUpGradePanel:SetSkillInfoPart(pokemon)
    local demonDataConfig = ConfigManager.GetConfigData(ConfigName.DifferDemonsConfig, pokemon.id)
    self.demonName.text = demonDataConfig.Name .. GetLanguageStrById(10452)
    local skillId = pokemon.pokemonUpLvConfigList[pokemon.stage].configData.SkillId
    local skillConfig = ConfigManager.GetConfigData(ConfigName.SkillConfig, skillId)
    if skillConfig then
        self.skillIcon.sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
        self.skillName.text =GetLanguageStrById(skillConfig.Name)
        self.currentLv.text = demonDataConfig.Name .. "+ " .. pokemon.stage
        self.nextLv.text = demonDataConfig.Name .. "+ " .. pokemon.stage + 1
        self.effectDesc.text = skillConfig.ShortDesc
    end
    self.breakTips.text = string.format(GetLanguageStrById(10453), pokemon.stage + 1)
end

--设置额外效果
function DemonUpGradePanel:SetExtraEffectPart(pokemon)
    local demonDataConfig = ConfigManager.GetConfigData(ConfigName.DifferDemonsConfig, pokemon.id)
    local stageConfigs = self:GetPokeMonStageConfigs(pokemon)
    self.effectList:SetData(stageConfigs, function(index, go)
        local stageInfo = stageConfigs[index]
        local lv = stageInfo.ID % 100
        local str
        if pokemon.stage >= lv then
            str = string.gsub(stageInfo.SkillChangeDesc,"{","<color=#34B936FF>")
            str = string.gsub(str,"}","</color>")
            str = str .. GetLanguageStrById(10449)
        else
            str = string.gsub(stageInfo.SkillChangeDesc,"{","<color=#1C4B15FF>")
            str = string.gsub(str,"}","</color>")
            str = str .. GetLanguageStrById(10450)
        end
        Util.GetGameObject(go, "desc"):GetComponent("Text").text = string.format("<color=%s>%s+%s</color>",
                pokemon.stage >= lv and ColorDef[1] or ColorDef[2], demonDataConfig.Name, lv)
        Util.GetGameObject(go, "desc2"):GetComponent("Text").text = string.format("<color=%s>%s</color>",
                pokemon.stage >= lv and ColorDef[1] or ColorDef[2], str)
    end)
end

--获取对应异妖的SkillConfig
function DemonUpGradePanel:GetPokeMonStageConfigs(pokemon)
    local targetConfigs = {}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.DifferDemonsStageConfig)) do
        if math.floor(v.ID / 100) == pokemon.id and v.SkillChangeDesc ~= nil then
            table.insert(targetConfigs, v)
        end
    end
    return targetConfigs
end


--设置进阶消耗相关
function DemonUpGradePanel:SetMaterialCostPart(pokeMon)
    self.materialEnough = true
    self.upStarMaterial = pokeMon.pokemonUpLvConfigList[pokeMon.stage + 1].configData.Cost
    self.costCount.transform.parent.gameObject:SetActive(false)
    for i = 1, #self.upStarMaterial do
        if self.upStarMaterial[i][1] == 14 then
            self.materialEnough = self.materialEnough and BagManager.GetItemCountById(self.upStarMaterial[i][1]) >= self.upStarMaterial[i][2]
            self.costCount.transform.parent.gameObject:SetActive(false)
            if BagManager.GetItemCountById(self.upStarMaterial[i][1]) < self.upStarMaterial[i][2] then
                self.costCount:GetComponent("Text").text = string.format("<color=#FF0000FF>%s</color>", self.upStarMaterial[i][2])
            else
                self.costCount:GetComponent("Text").text = string.format("<color=#FFFFFFFF>%s</color>", self.upStarMaterial[i][2])
            end
        else
            if self.upStarMaterial[i][2] > 0 then
                self.materialEnough = self.materialEnough and BagManager.GetItemCountById(self.upStarMaterial[i][1]) >= self.upStarMaterial[i][2]
                local comp = newObjToParent(self.itemPre, self.itemContent)
                local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig, self.upStarMaterial[i][1])
                Util.GetGameObject(comp, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig.Quantity))
                Util.GetGameObject(comp, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
                Util.AddClick(Util.GetGameObject(comp, "icon"), function()
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, self.upStarMaterial[i][1])
                end)
                if BagManager.GetItemCountById(self.upStarMaterial[i][1]) < self.upStarMaterial[i][2] then
                    Util.GetGameObject(comp, "num"):GetComponent("Text").text = string.format("<color=#FF0000FF>%s/%s</color>", BagManager.GetItemCountById(self.upStarMaterial[i][1]), self.upStarMaterial[i][2])
                else
                    Util.GetGameObject(comp, "num"):GetComponent("Text").text = string.format("<color=#FFFFFFFF>%s/%s</color>", BagManager.GetItemCountById(self.upStarMaterial[i][1]), self.upStarMaterial[i][2])
                end
                table.insert(self.itemList, comp)
            end
        end
    end
end

function DemonUpGradePanel:ClearItemList()
    table.walk(self.itemList, function(Item)
        destroy(Item.gameObject)
    end)
    self.itemList = {}
end

function DemonUpGradePanel:onDemonUpGradeBtnClicked()
    local componentsLevelMeet = self:JudgeComponentsMeet()
    if componentsLevelMeet then
        if self.materialEnough then
            NetManager.DemonUpRequest(self.pokemon.id, function()
                self:UpDataManagerRecord()
                self:ClosePanel()
                PopupTipPanel.ShowTipByLanguageId(10454)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10455)
        end
    else
        local needCompLevel = self.pokemon.stage + 1
        PopupTipPanel.ShowTip(GetLanguageStrById(10456) .. needCompLevel .. GetLanguageStrById(10457))
    end
end

--判断配件条件是否满足
function DemonUpGradePanel:JudgeComponentsMeet()
    local meet = true
    table.walk(self.pokemon.pokemoncomonpentList, function(componentInfo)
        meet = meet and componentInfo.level > self.pokemon.stage
    end)
    return meet
end

--更新相关Manager数据内容
function DemonUpGradePanel:UpDataManagerRecord()
    if not self.upStarMaterial then
        return
    end
    --for i = 1, #self.upStarMaterial do
    --    if self.upStarMaterial[i][2] > 0 then
    --        BagManager.UpdateItemsNum(self.upStarMaterial[i][1], self.upStarMaterial[i][2])
    --    end
    --end
    DiffMonsterManager.UpdatePokemonLv(self.pokemon.id, self.pokemon.stage + 1)
    local pokeMon = DiffMonsterManager.GetSinglePokemonData(self.pokemon.id)
    UIManager.OpenPanel(UIName.DiffMonsterUpGradSuccessPanel, pokeMon)
end

return DemonUpGradePanel