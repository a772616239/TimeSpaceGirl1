require("Base/BasePanel")
UnLockWarOrderPanel = Inherit(BasePanel)
local this = UnLockWarOrderPanel
local EncourageTaskConfig = ConfigManager.GetConfig(ConfigName.EncourageTaskConfig)
local EncouragePlanConfig = ConfigManager.GetConfig(ConfigName.EncouragePlanConfig)
local RechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)

function this:InitComponent()
    this.mask = Util.GetGameObject(this.gameObject, "mask")
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")
    this.grid1 = Util.GetGameObject(this.gameObject, "Panel/grid1")
    this.grid2 = Util.GetGameObject(this.gameObject, "Panel/grid2")
    this.btnUnLock = Util.GetGameObject(this.gameObject, "btnUnLock")
    this.Price = Util.GetGameObject(this.gameObject, "btnUnLock/Text"):GetComponent("Text")
end

function this:BindEvent()
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnUnLock, function()
        if AppConst.isSDKLogin then
            PayManager.Pay({ Id = this.RechargeID }, function()
                FirstRechargeManager.RefreshAccumRechargeValue(this.RechargeID)
                OperatingManager.ManualChangeWarOrderState(this.EncouragePlanId)
                self:ClosePanel()
            end)
        else
            NetManager.RequestBuyGiftGoods(this.RechargeID, function()
                FirstRechargeManager.RefreshAccumRechargeValue(this.RechargeID)
                OperatingManager.ManualChangeWarOrderState(this.EncouragePlanId)
                self:ClosePanel()
            end)
        end
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

local itemList1 = {}
local itemList2 = {}
function this:OnOpen(Id)
    this.RechargeID = EncouragePlanConfig[Id].RechargeID
    local Price = RechargeCommodityConfig[this.RechargeID].Price
    this.Price.text = MoneyUtil.GetMoney(Price)

    local BaseReward = RechargeCommodityConfig[this.RechargeID].BaseReward
    local FreeReward = {}
    local PrivilegeReward = {}
    local allData = ConfigManager.GetAllConfigsDataByKey(ConfigName.EncourageTaskConfig, "EncouragePlan", Id)
    this.EncouragePlanId = Id
    for i = 1, #allData do
        -- for j = 1, #allData[i].FreeReward do
        --     local state = true
        --     local id = allData[i].FreeReward[j][1]
        --     local value = allData[i].FreeReward[j][2]
        --     for k = 1, #FreeReward do
        --         if FreeReward[k][1] == id then
        --             FreeReward[k][2] = FreeReward[k][2] + value
        --             state = false
        --             break
        --         end
        --     end
        --     if state then
        --         table.insert(FreeReward, {id, value})
        --     end
        -- end
        for j = 1, #allData[i].PrivilegeReward do
            local state = true
            local id = allData[i].PrivilegeReward[j][1]
            local value = allData[i].PrivilegeReward[j][2]
            for k = 1, #PrivilegeReward do
                if PrivilegeReward[k][1] == id then
                    PrivilegeReward[k][2] = PrivilegeReward[k][2] + value
                    state = false
                    break
                end
            end
            if state then
                table.insert(PrivilegeReward, {id, value})
            end
        end
    end
    for i = 1, #BaseReward do
        local id = BaseReward[i][1]
        local value = BaseReward[i][2]
        table.insert(FreeReward, {id, value})
    end

    if not itemList1 then
        itemList1 = {}
    end
    for i = 1, #itemList1 do
        itemList1[i].gameObject:SetActive(false)
    end
    for i = 1, #FreeReward do
        itemList1[i] = SubUIManager.Open(SubUIConfig.ItemView, this.grid1.transform)
        itemList1[i]:OnOpen(false, FreeReward[i], 1)
        itemList1[i].gameObject:SetActive(true)
    end

    if not itemList2 then
        itemList2 = {}
    end
    for i = 1, #itemList2 do
        itemList2[i].gameObject:SetActive(false)
    end
    for i = 1, #PrivilegeReward do
        itemList2[i] = SubUIManager.Open(SubUIConfig.ItemView, this.grid2.transform)
        itemList2[i]:OnOpen(false, PrivilegeReward[i], 0.8)
        itemList2[i].gameObject:SetActive(true)
    end
end

function this:OnShow()
end

function this:OnSortingOrderChange()
end

function this:OnClose()
end

function this:OnDestroy()
    itemList1 = {}
    itemList2 = {}
end

return UnLockWarOrderPanel