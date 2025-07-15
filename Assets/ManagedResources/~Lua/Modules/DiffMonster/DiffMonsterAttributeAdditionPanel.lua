--[[
 * @ClassName DiffMonsterAttributeAdditionPanel
 * @Description 异妖属性总加成
 * @Date 2019/5/14 17:22
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class DiffMonsterAttributeAdditionPanel
local DiffMonsterAttributeAdditionPanel = quick_class("DiffMonsterAttributeAdditionPanel",BasePanel)

function DiffMonsterAttributeAdditionPanel:InitComponent()
    self.confirmBtn = Util.GetGameObject(self.transform, "frame/bg/confirmBtn")
    self.attributeContent = Util.GetGameObject(self.transform, "frame/bg/attributesList/viewPort/content")
    self.attributeItem = Util.GetGameObject(self.attributeContent, "attributeItem")
    self.attributeItem.gameObject:SetActive(false)
    self.attributeList = {}

    --属性的key,Value存储
    self.propKeyValues = {}

end

function DiffMonsterAttributeAdditionPanel:BindEvent()
    Util.AddClick(self.confirmBtn, function()
        self:ClosePanel()
    end)
end
--pokemonInfoList
function DiffMonsterAttributeAdditionPanel:OnOpen()
    local wholePropertyList = DiffMonsterManager.DealWithPropertyList()
    for k, v in pairs(wholePropertyList) do
        table.insert(self.propKeyValues, { propId = k, propValue = v })
    end
    self:SetAttributes()
end

function DiffMonsterAttributeAdditionPanel:OnClose()
    table.walk(self.attributeList, function(attributeItem)
        destroy(attributeItem.gameObject)
    end)
    self.attributeList = {}

    self.propKeyValues = {}
end

function DiffMonsterAttributeAdditionPanel:GetNameAndValue(propInfo)
    local propertyConfig = ConfigManager.GetConfigData(ConfigName.PropertyConfig, propInfo.propId)
    return propertyConfig.Info, propInfo.propValue, propertyConfig.Style
end

function DiffMonsterAttributeAdditionPanel:SetAttributes()
    local itemCount = math.ceil(table.nums(self.propKeyValues) / 2)
    for idx = 1, itemCount do
        local propItem = newObjToParent(self.attributeItem, self.attributeContent)
        Util.GetGameObject(propItem, "shadow").gameObject:SetActive(idx % 2 == 1)
        self:SetPerItemValue(propItem, idx)
        table.insert(self.attributeList, propItem)
    end
end

function DiffMonsterAttributeAdditionPanel:SetPerItemValue(propItem, index)
    local propName, propValue, propType
    propName, propValue, propType = self:GetNameAndValue(self.propKeyValues[2 * index - 1])
    Util.GetGameObject(propItem, "attribute_1"):GetComponent("Text").text = propName
    Util.GetGameObject(propItem, "attribute_1/value"):GetComponent("Text").text = GetPropertyFormatStrOne(propType,propValue)
    if 2 * index > table.nums(self.propKeyValues) then
        Util.GetGameObject(propItem, "attribute_2"):GetComponent("Text").text = ""
        Util.GetGameObject(propItem, "attribute_2/value"):GetComponent("Text").text = ""
        return
    end
    propName, propValue,propType = self:GetNameAndValue(self.propKeyValues[2 * index])
    Util.GetGameObject(propItem, "attribute_2"):GetComponent("Text").text = propName
    Util.GetGameObject(propItem, "attribute_2/value"):GetComponent("Text").text = GetPropertyFormatStrOne(propType,propValue)
end

return DiffMonsterAttributeAdditionPanel