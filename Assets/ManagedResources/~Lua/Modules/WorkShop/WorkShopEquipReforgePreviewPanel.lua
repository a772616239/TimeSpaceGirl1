--[[
 * @Classname WorkShopEquipReforgePreviewPanel
 * @Description 装备重铸预览
 * @Date 2019/5/8 17:35
 * @Created by MagicianJoker
--]]
require("Base/BasePanel")
---@class WorkShopEquipReforgePreviewPanel
WorkShopEquipReforgePreviewPanel = Inherit(BasePanel)

function WorkShopEquipReforgePreviewPanel:InitComponent()
    self.closeBtn = Util.GetGameObject(self.gameObject, "frame")
    --topPart
    self.equipInfo = Util.GetGameObject(self.gameObject, "frame/bg/equipInfo")

    self.equipName = Util.GetGameObject(self.equipInfo, "nameBg/name"):GetComponent("Text")

    self.iconBg = Util.GetGameObject(self.equipInfo, "iconBg"):GetComponent("Image")
    self.icon = Util.GetGameObject(self.equipInfo, "iconBg/icon"):GetComponent("Image")

    self.equipType = Util.GetGameObject(self.equipInfo, "proGrid/equipType"):GetComponent("Text")
    self.equipPos = Util.GetGameObject(self.equipInfo, "proGrid/equipPos"):GetComponent("Text")
    self.equipReforgeLv = Util.GetGameObject(self.equipInfo, "proGrid/equipLv"):GetComponent("Text")

    self.equipQuality = Util.GetGameObject(self.equipInfo, "quality"):GetComponent("Text")

    self.powerValue = Util.GetGameObject(self.equipInfo, "powerNum"):GetComponent("Text")
    self.powerUpOrDown = Util.GetGameObject(self.equipInfo, "powerUPOrDown"):GetComponent("Image")
    self.desc = Util.GetGameObject(self.equipInfo, "desc"):GetComponent("Text")

    --bottomPart
    self.propList = Util.GetGameObject(self.transform, "frame/bg/propList")

    self.listRoot = Util.GetGameObject(self.propList, "content")

    self.mainPro = Util.GetGameObject(self.listRoot, "mainPro")
    self.mainProName = Util.GetGameObject(self.mainPro, "curProName"):GetComponent("Text")
    self.mainProValue = Util.GetGameObject(self.mainPro, "curProValue"):GetComponent("Text")
    self.mainProLimit = Util.GetGameObject(self.mainPro, "propLimit"):GetComponent("Text")

    self.itemPro = Util.GetGameObject(self.listRoot, "itemPro")
    self.itemPro.gameObject:SetActive(false)

    self.itemList = {}

    self.castInfoObject = Util.GetGameObject(self.gameObject, "frame/bg/castInfoObject")
    self.curCastInfo = Util.GetGameObject(self.gameObject, "frame/bg/castInfoObject/castInfo"):GetComponent("Text")
end

function WorkShopEquipReforgePreviewPanel:BindEvent()
    --Util.AddClick(self.closeBtn, function()
    --    self:ClosePanel()
    --end)
end

function WorkShopEquipReforgePreviewPanel:OnOpen(context)
    self:ClearList()
    self:setEquipInfoStatus(context)
    self:setEquipPropStatus(context)
end

function WorkShopEquipReforgePreviewPanel:OnClose()
    self:ClearList()
end

function WorkShopEquipReforgePreviewPanel:ClearList()
    for _, v in ipairs(self.itemList) do
        destroy(v.gameObject)
    end
    self.itemList = {}
end

function WorkShopEquipReforgePreviewPanel:setEquipInfoStatus(context)
    self.equipName.text = GetStringByEquipQua(context.equipConfig.Quality, context.equipConfig.Name)
    self.iconBg.sprite = Util.LoadSprite(GetQuantityImageByquality(context.equipConfig.Quality))
    self.icon.sprite = Util.LoadSprite(GetResourcePath(context.itemConfig.ResourceID))

    self.equipType.text = string.format(GetLanguageStrById(11555), EquipNameDef[context.equipConfig.Position])
    self.equipPos.text = string.format(GetLanguageStrById(11094), GetJobStrByJobNum(context.equipConfig.ProfessionLimit))
    self.equipReforgeLv.text = GetLanguageStrById(12027) .. context.resetLv

    self.equipQuality.text = GetStringByEquipQua(context.equipConfig.Quality, EquipQualityDescDef[context.equipConfig.Quality])

    self.desc.text = context.itemConfig.ItemDescribe

    self.powerValue.text = EquipManager.CalculateWarForce(context.did)

    if context.skillId>0 then
        self.castInfoObject.gameObject:SetActive(true)
        local cfg=ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, context.skillId)
        self.curCastInfo.text=GetSkillConfigDesc(cfg)
    else
        self.curCastInfo.text=""
        self.castInfoObject.gameObject:SetActive(false)
    end
end

function WorkShopEquipReforgePreviewPanel:setEquipPropStatus(context)
    self:setEquipMainPro(context)
    if #context.secondAttribute <= 0 then
        return
    end
    for i = 1, #context.secondAttribute do
        local go = newObjToParent(self.itemPro, self.listRoot)
        self:setPerItemValue(go, context.secondAttribute[i], context.id)
        table.insert(self.itemList, go)
    end
end

function WorkShopEquipReforgePreviewPanel:setEquipMainPro(context)
    local mainPropInfo = context.mainAttribute
    local mainPropConfigInfo = mainPropInfo.PropertyConfig
    self.mainProName.text = mainPropConfigInfo.Info
    self.mainProValue.text = mainPropInfo.propertyValue
    local addProValue = WorkShopManager.WorkShopData.LvAddMainIdAndVales[context.equipConfig.PropertyMin[1]]
    local minValue, maxValue
    if addProValue then
        local basicPropertyMin = context.equipConfig.PropertyMin[2]
        minValue = basicPropertyMin + basicPropertyMin * addProValue / 100
        local basicPropertyMax = context.equipConfig.PropertyMax[2]
        maxValue = basicPropertyMax + basicPropertyMax * addProValue / 100
    else
        minValue = context.equipConfig.PropertyMin[2]
        maxValue = context.equipConfig.PropertyMax[2]
    end
    self.mainProLimit.text = string.format("[%s~%s]",math.floor(minValue), math.floor(maxValue))
end

function WorkShopEquipReforgePreviewPanel:setPerItemValue(item, propInfo, propId)
    local propNameText = Util.GetGameObject(item, "curProName"):GetComponent("Text")
    local propValueText = Util.GetGameObject(item, "curProValue"):GetComponent("Text")
    local propType = propInfo.PropertyConfig.Style
    propNameText.text = propInfo.PropertyConfig.Info
    propNameText.color = propType == 1 and Color.New(185 / 255, 174 / 255, 151 / 255, 1) or Color.New(99 / 255, 99 / 255, 99 / 255, 1)
    if propType == 1 then
        propValueText.text = "+" .. math.floor(propInfo.propertyValue )
    else
        propValueText.text = string.format("+%.2f%%", propInfo.propertyValue / 100)
    end
    --propValueText.text = "+" .. propInfo.propertyValue / 100 .. (propType == 1 and "" or "%")
    propValueText.color = propType == 1 and Color.New(185 / 255, 174 / 255, 151 / 255, 1) or Color.New(99 / 255, 99 / 255, 99 / 255, 1)
    if propType == 2 then
        Util.GetGameObject(item, "propLimit"):GetComponent("Text").text = ""
        return
    end
    --
    local equipConfigInfo = ConfigManager.GetConfigData(ConfigName.EquipConfig, propId)
    
    local tempId = 0
    for i = 1, #equipConfigInfo.Pool do
       local configData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.EquipPropertyPool, "PoolNum", equipConfigInfo.Pool[i], "PropertyId", propInfo.propertyId)
        if configData then
            tempId = configData.id--equipConfigInfo.Pool * 10000 + propInfo.propertyId
        end
    end
    if tempId > 0 then
        local equipPropertyPoolInfo = ConfigManager.GetConfigData(ConfigName.EquipPropertyPool, tempId)
        --assert(equipPropertyPoolInfo, string.format("equipPropertyPool not find id:%s", tempId))
        local addProValue = WorkShopManager.WorkShopData.LvAddMainIdAndVales[equipPropertyPoolInfo.PropertyId]
        local minValue, maxValue
        if addProValue then
            minValue = equipPropertyPoolInfo.Min * (1+addProValue / 100)
            maxValue = equipPropertyPoolInfo.Max * (1+addProValue / 100)
        else
            minValue = equipPropertyPoolInfo.Min
            maxValue = equipPropertyPoolInfo.Max
        end
        Util.GetGameObject(item, "propLimit"):GetComponent("Text").text = string.format("[%s~%s]", math.floor(minValue), math.floor(maxValue))
    end

end

return WorkShopEquipReforgePreviewPanel