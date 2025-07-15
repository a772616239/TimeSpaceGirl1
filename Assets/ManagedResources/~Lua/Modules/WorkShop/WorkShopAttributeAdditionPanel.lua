require("Base/BasePanel")
WorkShopAttributeAdditionPanel = Inherit(BasePanel)
local heroPos = 0
--初始化组件（用于子类重写）
function WorkShopAttributeAdditionPanel:InitComponent()

    self.confirmBtn = Util.GetGameObject(self.transform, "frame/bg/confirmBtn")
    self.attributeContent = Util.GetGameObject(self.transform, "frame/bg/attributesList/viewPort/content")
    self.title = Util.GetGameObject(self.transform, "frame/bg/title"):GetComponent("Text")
    self.apartlineImage=Util.GetGameObject(self.transform,"frame/bg/apartline"):GetComponent("Image")--线图片
    self.noneImage=Util.GetGameObject(self.transform,"frame/bg/noneImage")--无信息图片
    self.attributeItem = Util.GetGameObject(self.attributeContent, "attributeItem")
    self.attributeItem.gameObject:SetActive(false)
    self.attributeList = {}
    --属性的key,Value存储
    self.propKeyValues = {}

end

--绑定事件（用于子类重写）
function WorkShopAttributeAdditionPanel:BindEvent()
    Util.AddClick(self.confirmBtn, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function WorkShopAttributeAdditionPanel:AddListener()

end

--移除事件监听（用于子类重写）
function WorkShopAttributeAdditionPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WorkShopAttributeAdditionPanel:OnOpen(_heroPos)

    heroPos = _heroPos

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function WorkShopAttributeAdditionPanel:OnShow()

    self.title.text = HeroOccupationDef[heroPos]..GetLanguageStrById(12032)
    --local UpGradAttribute = TalentManager.GetTalentUpGradPropList()
    --local propertyTotalList = TalentManager.GetRingFiresPropList()
    --local desireData = table.mergeV2(UpGradAttribute,propertyTotalList)
    local desireData = WorkShopManager.HeroCalculateTreeWarForce(heroPos)
    for k, v in pairs(desireData) do
        table.insert(self.propKeyValues, { propId = k, propValue = v })
    end
    self:SetAttributes()
end

--界面关闭时调用（用于子类重写）
function WorkShopAttributeAdditionPanel:OnClose()
    table.walk(self.attributeList, function(attributeItem)
        destroy(attributeItem.gameObject)
    end)
    self.attributeList = {}
    self.propKeyValues = {}
    self.noneImage.gameObject:SetActive(false)
end

function WorkShopAttributeAdditionPanel:GetNameAndValue(propInfo)
    local propertyConfig = ConfigManager.GetConfigData(ConfigName.PropertyConfig, propInfo.propId)
    --assert(propertyConfig, string.format("ConfigName.PropertyConfig not find Id:%s", propInfo.propId))
    return propertyConfig.Info, propInfo.propValue, propertyConfig.Style
end

function WorkShopAttributeAdditionPanel:SetAttributes()
    --无信息判断
    self.apartlineImage.enabled=#self.propKeyValues~=0
    self.noneImage.gameObject:SetActive(#self.propKeyValues==0)
    if #self.propKeyValues==0 then return end

    local itemCount = math.ceil(table.nums(self.propKeyValues) / 2)
    for idx = 1, itemCount do
        local propItem = newObjToParent(self.attributeItem, self.attributeContent)
        Util.GetGameObject(propItem, "shadow").gameObject:SetActive(idx % 2 == 1)
        self:SetPerItemValue(propItem, idx)
        table.insert(self.attributeList, propItem)
    end
end

function WorkShopAttributeAdditionPanel:SetPerItemValue(propItem, index)
    local propName, propValue, propType
    propName, propValue, propType = self:GetNameAndValue(self.propKeyValues[2 * index - 1])
    Util.GetGameObject(propItem, "attribute_1"):GetComponent("Text").text = propName
    Util.GetGameObject(propItem, "attribute_1/value"):GetComponent("Text").text = GetPropertyFormatStr(propType, propValue)
    if 2 * index > table.nums(self.propKeyValues) then
        Util.GetGameObject(propItem, "attribute_2"):GetComponent("Text").text = ""
        Util.GetGameObject(propItem, "attribute_2/value"):GetComponent("Text").text = ""
        return
    end
    propName, propValue, propType = self:GetNameAndValue(self.propKeyValues[2 * index])
    Util.GetGameObject(propItem, "attribute_2"):GetComponent("Text").text = propName
    Util.GetGameObject(propItem, "attribute_2/value"):GetComponent("Text").text = GetPropertyFormatStr(propType, propValue)
end

return WorkShopAttributeAdditionPanel