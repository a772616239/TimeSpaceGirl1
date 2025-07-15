--[[
 * @ClassName ContinuityRechargePage
 * @Description 连续充值
 * @Date 2019/8/2 16:45
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
local ContinuityRechargeItem = require("Modules/Operating/ContinuityRechargeItem")
--积天豪礼
---@class ContinuityRechargePage
local ContinuityRechargePage = quick_class("ContinuityRechargePage")

local sortingOrder = 0
local isFirstOn = true--是否首次打开页面

function ContinuityRechargePage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    sortingOrder = 0
    -- self.conditionDesc = Util.GetGameObject(self.gameObject, "condition"):GetComponent("Text")

    self.continuityTaskContent = Util.GetGameObject(self.gameObject, "taskList/viewPort/content")
    self.continuityTaskItem = Util.GetGameObject(self.continuityTaskContent, "itemPro")
    --self.effect = Util.GetGameObject(self.gameObject, "UI_effect_OperatingPanel_normal")
    self.continuityTaskItem:SetActive(false)
    self.continuityTaskList = {}
end

function ContinuityRechargePage:OnShow(_sortingOrder)
    isFirstOn = true
    --Util.AddParticleSortLayer( self.effect, _sortingOrder - sortingOrder)
    sortingOrder = _sortingOrder
    Game.GlobalEvent:AddEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, self.RefreshPanel, self)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.ContinueRechargeRefresh, self.RefreshPanel, self)
    self.gameObject:SetActive(true)
    self:RefreshPanel()
end

--层级重设 防特效穿透
function ContinuityRechargePage:OnSortingOrderChange(cursortingOrder)
    -- Util.AddParticleSortLayer( self.effect, cursortingOrder - sortingOrder)
    -- sortingOrder = cursortingOrder
    -- for i, v in pairs(self.continuityTaskList) do
    --     v:OnSortingOrderChange(cursortingOrder)
    -- end
end

function ContinuityRechargePage:OnHide()
    Game.GlobalEvent:RemoveEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, self.RefreshPanel, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.ContinueRechargeRefresh, self.RefreshPanel, self)
    self.gameObject:SetActive(false)
end

function ContinuityRechargePage:RefreshPanel()
    local actRewardConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.GlobalActivity,
            "Id", ActivityTypeDef.ContinuityRecharge)
    local actRewardConfigsOhter = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,
            "ActivityId", ActivityTypeDef.ContinuityRecharge)
    -- self.conditionDesc.text = GetLanguageStrById(actRewardConfigs[1].ExpertDec)

    if table.nums(self.continuityTaskList) > 0 then
        table.walk(self.continuityTaskList, function(taskItem)
            taskItem:SetValue()
        end)

        -- if isFirstOn then
        --     isFirstOn = false
        --     DelayCreation(self.itemList)
        -- end
        return
    end

    self.itemList = {}
    for i, actRewardInfo in ipairs(actRewardConfigsOhter) do
        local cloneObj = newObjToParent(self.continuityTaskItem, self.continuityTaskContent)
        self.continuityTaskList[i] = ContinuityRechargeItem.create(cloneObj)

        -- self.continuityTaskList[i] = ContinuityRechargeItem.create(self.continuityTaskItem, self.continuityTaskContent)
        self.continuityTaskList[i]:Init(actRewardInfo,sortingOrder)
        self.continuityTaskList[i]:SetValue()

        self.itemList[i] = cloneObj
    end
    table.walk(self.continuityTaskList, function(continuityTaskItem)
        continuityTaskItem:TrySetLastSibling()
    end)

    -- if isFirstOn then
    --     isFirstOn = false
    --     DelayCreation(self.itemList)
    -- end
end

return ContinuityRechargePage