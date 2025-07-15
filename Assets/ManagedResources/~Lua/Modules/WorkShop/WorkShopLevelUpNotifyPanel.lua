--[[
 * @Classname WorkShopLevelUpNotifyPanel
 * @Description 工坊升级提示界面
 * @Date 2019/5/17 11:04
 * @Created by MagicianJoker
--]]

require("Base/BasePanel")

---@class WorkShopLevelUpNotifyPanel
WorkShopLevelUpNotifyPanel = Inherit(BasePanel)

function WorkShopLevelUpNotifyPanel:InitComponent()
    self.closeBtn = self.transform:Find("frame").gameObject

    self.levelValue = self.transform:Find("frame/bg/Content/bg/levelValue"):GetComponent("Text")

    self.itemPro = self.transform:Find("frame/bg/Content/openList/openList/viewPort/content/itemPro")
    self.itemPro.gameObject:SetActive(false)
    self.openLock = self.transform:Find("frame/bg/Content/openLock")
    self.openLock.gameObject:SetActive(false)
    self.openList = self.transform:Find("frame/bg/Content/openList")
    self.openList.gameObject:SetActive(false)
    self.itemList = {}
end

function WorkShopLevelUpNotifyPanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)
end

--context:{level}
function WorkShopLevelUpNotifyPanel:OnOpen(context)
    self:SetBasic(context)
    self:SetItemList(context)
end

function WorkShopLevelUpNotifyPanel:SetBasic(context)
    self.levelValue.text = context.level
end

function WorkShopLevelUpNotifyPanel:SetItemList(context)
    local configData = self:GetMeetConfigs(context.level)
    table.walk(configData, function(configInfo)
        local go = newObjToParent(self.itemPro.gameObject, self.itemPro.parent.gameObject)
        self:SetItem(go, configInfo)
        table.insert(self.itemList, go)
    end)
    self.openLock.gameObject:SetActive(#configData > 0)
    self.openList.gameObject:SetActive(#configData > 0)
end

function WorkShopLevelUpNotifyPanel:GetMeetConfigs(level)
    local data = {}
    --local workShopEquipConfigs = ConfigManager.GetConfig(ConfigName.WorkShopEquipmentConfig)
    --local configKeys = GameDataBase.SheetBase.GetKeys(workShopEquipConfigs)
    --for i = 1, #configKeys do
    --    local configInfo = workShopEquipConfigs[configKeys[i]]
    --    if configInfo.OpenRules[1] == 1 and configInfo.OpenRules[2] == level then
    --        table.insert(data, configInfo)
    --    end
    --end
    --table.sort(data, function(a, b)
    --    return a.Id < b.Id
    --end)
    local curWorkShopSetting = ConfigManager.GetConfigData(ConfigName.WorkShopSetting,level)
    if curWorkShopSetting and curWorkShopSetting.UnravelItem then
        data = curWorkShopSetting.UnravelItem
    end
    return data
end

function WorkShopLevelUpNotifyPanel:SetItem(go, Id)
    local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig, Id)
    Util.GetGameObject(go, "frame"):GetComponent("Image").sprite =
        Util.LoadSprite(GetQuantityImageByquality(itemConfig.Quantity))
    Util.GetGameObject(go, "icon"):GetComponent("Image").sprite =
        Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
    Util.AddClick(Util.GetGameObject(go, "icon"), function()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, Id)
    end)
    Util.GetGameObject(go, "name"):GetComponent("Text").text = GetLanguageStrById(itemConfig.Name)
end

function WorkShopLevelUpNotifyPanel:OnClose()
    table.walk(self.itemList, function(item)
        destroy(item.gameObject)
    end)
    self.itemList = {}
end

return WorkShopLevelUpNotifyPanel