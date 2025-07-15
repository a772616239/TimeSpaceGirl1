--[[
 * @ClassName DemonPartsUpStarSuccessPanel
 * @Description 配件进阶成功界面
 * @Date 2019/9/5 20:11
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class DemonPartsUpStarSuccessPanel
local DemonPartsUpStarSuccessPanel = quick_class("DemonPartsUpStarSuccessPanel", BasePanel)

function DemonPartsUpStarSuccessPanel:InitComponent()
    self.btnBack = Util.GetGameObject(self.transform, "frame")

    self.topPart = Util.GetGameObject(self.transform, "frame/bg/topPart")

    self.compPart = Util.GetGameObject(self.topPart, "compPart")

    self.compCurrentIconBg = Util.GetGameObject(self.compPart, "compCurrent/iconBg"):GetComponent("Image")
    self.compCurrentIcon = Util.GetGameObject(self.compPart, "compCurrent/iconBg/icon"):GetComponent("Image")
    self.compCurrentLv = Util.GetGameObject(self.compPart, "compCurrent/iconBg/levelBg/value"):GetComponent("Text")
    self.compNextIconBg = Util.GetGameObject(self.compPart, "compNext/iconBg"):GetComponent("Image")
    self.compNextIcon = Util.GetGameObject(self.compPart, "compNext/iconBg/icon"):GetComponent("Image")
    self.compNextLv = Util.GetGameObject(self.compPart, "compNext/iconBg/levelBg/value"):GetComponent("Text")

    self.compCurrentLevel = Util.GetGameObject(self.compPart, "compMes/currentLevel"):GetComponent("Text")
    self.compNextLevel = Util.GetGameObject(self.compPart, "compMes/nextLevel"):GetComponent("Text")

    self.propContent = Util.GetGameObject(self.topPart, "propList")
    self.proPre = Util.GetGameObject(self.propContent, "propItem")
    self.proPre.gameObject:SetActive(false)
    self.propList = {}

    self.bottomPart = Util.GetGameObject(self.transform, "frame/bg/bottomPart")
    self.profExtraAdd = Util.GetGameObject(self.bottomPart, "extraProf"):GetComponent("Text")
    self.heroContent = Util.GetGameObject(self.bottomPart, "heroList/viewPort/content")
    self.heroItem = Util.GetGameObject(self.heroContent, "heroItem")
    self.heroItem:SetActive(false)
    self.heroList = {}

end

function DemonPartsUpStarSuccessPanel:BindEvent()
    Util.AddClick(self.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

function DemonPartsUpStarSuccessPanel:OnOpen(componentContext)
    -- 播放声音
    SoundManager.PlaySound(SoundConfig.Sound_Dispelling_02)
    self:SetTopPart(componentContext)
    self:SetBottomPart(componentContext)
end

function DemonPartsUpStarSuccessPanel:SetTopPart(componentContext)
    local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig, componentContext.id)
    self.compCurrentIconBg.sprite = SetFrame(componentContext.id)
    self.compCurrentIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
    self.compCurrentLv.text = componentContext.level - 1
    self.compNextIconBg.sprite = SetFrame(componentContext.id)
    self.compNextIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
    self.compNextLv.text = componentContext.level
    self.compCurrentLevel.text = GetLanguageStrById(itemConfig.Name) .. " " .. componentContext.level - 1
    self.compNextLevel.text = componentContext.level

    local upAllProVal = componentContext.upLvMateriaConfiglList[componentContext.level - 1].BaseAttribute
    local allProVal = componentContext.upLvMateriaConfiglList[componentContext.level].BaseAttribute
    for j = 1, #allProVal do
        local go = newObjToParent(self.proPre, self.propContent)
        local propertyConfig = ConfigManager.GetConfigData(ConfigName.PropertyConfig, allProVal[j][1])
        Util.GetGameObject(go, "backGround").gameObject:SetActive(j % 2 == 1)
        Util.GetGameObject(go, "proName"):GetComponent("Text").text = propertyConfig.Info
        Util.GetGameObject(go, "proName/curProValue"):GetComponent("Text").text = GetPropertyFormatStrOne(propertyConfig.Style, upAllProVal[j][2])
        if j <= #upAllProVal then
            Util.GetGameObject(go, "proName/nextProValue"):GetComponent("Text").text = GetPropertyFormatStrOne(propertyConfig.Style, allProVal[j][2])
        end
        table.insert(self.propList, go)
    end
    self.propContent:SetActive(true)
end

function DemonPartsUpStarSuccessPanel:SetBottomPart(componentContext)
    local DiffDemonComponentConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.DifferDemonsComonpentsConfig,
            "ComonpentsId", componentContext.id, "Stage", componentContext.level)
    self.profExtraAdd.text = ""
    if DiffDemonComponentConfig.ExtraAdd then
        local profession = DiffDemonComponentConfig.ExtraAdd[1][1]
        local propId = DiffDemonComponentConfig.ExtraAdd[1][2]
        local propValue = DiffDemonComponentConfig.ExtraAdd[1][3]
       
        local heroList = self:GetExtraAddHeroList(profession)
        if table.nums(heroList) > 0 then
            self.profExtraAdd.text = HeroOccupationDef[profession] .. GetLanguageStrById(10451)
            self.thread = coroutine.start(function()
                for _, heroInfo in ipairs(heroList) do
                    local item = newObjToParent(self.heroItem, self.heroContent)
                    PlayUIAnim(item)
                    item:GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroInfo.heroConfig.Quality))
                    Util.GetGameObject(item, "icon"):GetComponent("Image").sprite = Util.LoadSprite(heroInfo.icon)
                    table.insert(self.heroList, { item = item, heroInfo = heroInfo })
                    --coroutine.wait(0.25)
                    coroutine.wait(0.01)
                end
                coroutine.wait(0.35)
                --coroutine.wait(0.05)
                for _, heroItem in ipairs(self.heroList) do
                    Util.GetGameObject(heroItem.item, "propValue"):SetActive(true)
                    Util.GetGameObject(heroItem.item, "propValue"):GetComponent("Text").text = self:GetPropFormatStr(propId, heroItem.heroInfo, propValue)
                end
                coroutine.wait(0.15)
                --coroutine.wait(0.05)
                for _, heroItem in ipairs(self.heroList) do
                    Util.GetGameObject(heroItem.item, "upValue"):GetComponent("Text").text = "+" .. self:GetPropFormatStrV2(propId, propValue)
                    Util.GetGameObject(heroItem.item, "upValue"):SetActive(true)
                    PlayUIAnim(Util.GetGameObject(heroItem.item, "upValue"))
                end
                coroutine.wait(1)
                --coroutine.wait(0.2)
                for _, heroItem in ipairs(self.heroList) do
                    Util.GetGameObject(heroItem.item, "upValue"):SetActive(false)
                    Util.GetGameObject(heroItem.item, "propValue"):GetComponent("Text").text = self:GetPropFormatStr(propId, heroItem.heroInfo, propValue)--self:GetPropFormatStr(propId, heroItem.heroInfo)
                end
            end)
        end
    end
end

function DemonPartsUpStarSuccessPanel:GetExtraAddHeroList(profession)
    local _heroDatas = self:GetSingleHeroList(profession)
    local teamHero = FormationManager.GetAllFormationHeroId()
    table.sort(_heroDatas, function(a, b)
        if (teamHero[a.dynamicId] and teamHero[b.dynamicId]) or
                (not teamHero[a.dynamicId] and not teamHero[b.dynamicId]) then
            if a.lv == b.lv then
                if a.heroConfig.Natural == b.heroConfig.Natural then
                    if a.star == b.star then
                        return a.heroConfig.Id < b.heroConfig.Id
                    else
                        return a.star > b.star
                    end
                else
                    return a.heroConfig.Natural > b.heroConfig.Natural
                end
            else
                return a.lv > b.lv
            end
        else
            return teamHero[a.dynamicId] and not teamHero[b.dynamicId]
        end
    end)
    return _heroDatas
end

function DemonPartsUpStarSuccessPanel:GetSingleHeroList(profession)
    local singleHeroList = {}
    local generalHeroList = HeroManager.GetHeroDataByProfession(profession)
    for _, heroInfo in pairs(generalHeroList) do
        local index = table.keyvalueindexof(singleHeroList, "id", heroInfo.id)
        if not index then
            table.insert(singleHeroList, heroInfo)
        else
            local insideHero = singleHeroList[index]
            if insideHero.lv < heroInfo.lv then
                singleHeroList[index] = heroInfo
            end
        end
    end
    return singleHeroList
end

function DemonPartsUpStarSuccessPanel:GetPropFormatStr(propId, heroInfo, extraValue)
    local propConfig = ConfigManager.GetConfigData(ConfigName.PropertyConfig, propId)
    if propConfig.TargetPropertyId ~= 0 then
        propId = propConfig.TargetPropertyId
    end
    local allAddProVal = HeroManager.CalculateHeroAllProValList(1, heroInfo.dynamicId, false)
    local result
    --if extraValue then
    --    if propConfig.Style == 1 then
    --        result = allAddProVal[propId] - extraValue
    --    else
    --        result = math.ceil(allAddProVal[propId] * (1 - extraValue / 10000))
    --    end
    --else
    --    if propConfig.TargetPropertyId ~= 0 then
    --        local propConfigV2 = ConfigManager.GetConfigData(ConfigName.PropertyConfig, propId)
    --        if propConfigV2.Style == 1 then
    --            result = allAddProVal[propId]
    --        else
    --            result = (allAddProVal[propId]) .. "%"
    --        end
    --    else
    --        if propConfig.Style == 1 then
    --            result = allAddProVal[propId]
    --        else
    --            result = (allAddProVal[propId]) .. "%"
    --        end
    --    end
    --end
    if propConfig.TargetPropertyId ~= 0 then
        local propConfigV2 = ConfigManager.GetConfigData(ConfigName.PropertyConfig, propId)
        if propConfigV2.Style == 1 then
            result = math.floor(allAddProVal[propId] - allAddProVal[propId] * (1 - extraValue / 10000))
        else
            result = (allAddProVal[propId] - allAddProVal[propId] * (1 - extraValue / 10000)) .. "%"
        end
    else
        if propConfig.Style == 1 then
            result = extraValue
        else
            result = (allAddProVal[propId] - allAddProVal[propId] * (1 - extraValue / 10000)) .. "%"
        end
    end
    return propConfig.Info .. "：" .. result
end

function DemonPartsUpStarSuccessPanel:GetPropFormatStrV2(propId, value)
    local propConfig = ConfigManager.GetConfigData(ConfigName.PropertyConfig, propId)
    return GetPropertyFormatStrOne(propConfig.Style, value)
end

function DemonPartsUpStarSuccessPanel:OnClose()
    table.walk(self.propList, function(propItem)
        destroy(propItem.gameObject)
    end)
    self.propList = {}

    table.walk(self.heroList, function(propItem)
        destroy(propItem.item.gameObject)
    end)
    self.heroList = {}

    if self.thread then
        coroutine.stop(self.thread)
        self.thread = nil
    end

end

return DemonPartsUpStarSuccessPanel