require("Base/BasePanel")
ClimbTowerUnlockPopup = Inherit(BasePanel)
local this = ClimbTowerUnlockPopup

local VirtualBattle = ConfigManager.GetConfig(ConfigName.VirtualBattle)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local RechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
local items = {}
local rechargeCommodityId = nil
--初始化组件（用于子类重写）
function ClimbTowerUnlockPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "bg/btnClose")
    this.UnlockBtn = Util.GetGameObject(self.gameObject, "bg/Btn/UnlockBtn")
    this.UnlockBtnFont = Util.GetGameObject(self.gameObject, "bg/Btn/UnlockBtn/Text (1)"):GetComponent("Text")

    this.RewardNowGrid = Util.GetGameObject(self.gameObject, "bg/RewardNow/Grid/RewardGrid")
    this.RewardTotalGrid = Util.GetGameObject(self.gameObject, "bg/RewardTotal/Grid/RewardGrid")

    this.repeatItemViews = {}
end

--绑定事件（用于子类重写）
function ClimbTowerUnlockPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.UnlockBtn, function()
        if AppConst.isSDKLogin then
            PayManager.Pay({ Id = rechargeCommodityId },function()
                FirstRechargeManager.RefreshAccumRechargeValue(rechargeCommodityId)
                if this.climbTowerType == ClimbTowerManager.ClimbTowerType.Normal then
                    if ClimbTowerRewardPopup then
                        ClimbTowerRewardPopup.ChangeTab(2, 1)
                    end
                elseif this.climbTowerType == ClimbTowerManager.ClimbTowerType.Advance then
                    if ClimbTowerEliteRewardPopup then
                        ClimbTowerEliteRewardPopup.ChangeTab(2, 1)
                    end
                end
                self:ClosePanel()
            end)
        else
            NetManager.RequestBuyGiftGoods(rechargeCommodityId, function()
                FirstRechargeManager.RefreshAccumRechargeValue(rechargeCommodityId)

                if this.climbTowerType == ClimbTowerManager.ClimbTowerType.Normal then
                    if ClimbTowerRewardPopup then
                        ClimbTowerRewardPopup.ChangeTab(2, 1)
                    end
                elseif this.climbTowerType == ClimbTowerManager.ClimbTowerType.Advance then
                    if ClimbTowerEliteRewardPopup then
                        ClimbTowerEliteRewardPopup.ChangeTab(2, 1)
                    end
                end
                self:ClosePanel()
            end)
        end
    end)

end

--添加事件监听（用于子类重写）
function ClimbTowerUnlockPopup:AddListener()
end

--移除事件监听（用于子类重写）
function ClimbTowerUnlockPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ClimbTowerUnlockPopup:OnOpen(...)
    local args = {...}
    this.climbTowerType = args[1]

    --> 策划意思写死
    if this.climbTowerType == ClimbTowerManager.ClimbTowerType.Normal then
        rechargeCommodityId = 10001
    elseif this.climbTowerType == ClimbTowerManager.ClimbTowerType.Advance then
        rechargeCommodityId = 10002
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ClimbTowerUnlockPopup:OnShow()
    self:Init()
end

function ClimbTowerUnlockPopup:Init()

    --> 立即获得
    local rewardNowData = RechargeCommodityConfig[rechargeCommodityId]
    if this.repeatItemViews[1] == nil then
        this.repeatItemViews[1] = {}
    end
    if #this.repeatItemViews[1] == 0 then
        for i = 1, 4 do --< 支持四个
            this.repeatItemViews[1][i] = SubUIManager.Open(SubUIConfig.ItemView, this.RewardNowGrid.transform)
        end
    end

    for i = 1, #this.repeatItemViews[1] do
        if i <= #rewardNowData.RewardShow then
            this.repeatItemViews[1][i]:OnOpen(false, {rewardNowData.RewardShow[i][1], rewardNowData.RewardShow[i][2]}, 0.6, nil, nil, nil, nil, nil)
            this.repeatItemViews[1][i].gameObject:SetActive(true)
        else
            this.repeatItemViews[1][i].gameObject:SetActive(false)
        end
    end

    --> 奖励总览
    local vipData = ClimbTowerManager.GetChallengeConfigVipData(this.climbTowerType)
    local items = {}
    for i = 1, #vipData do
        for j = 1, #vipData[i].PurchaseLevelReward do
            local itemid = vipData[i].PurchaseLevelReward[j][1]
            local itemnum = vipData[i].PurchaseLevelReward[j][2]
            if items[itemid] == nil then
                items[itemid] = {num = 0, sortid = j}   --< sortid 列 按顺序则有顺序 不按没顺序
            end
            items[itemid].num = items[itemid].num + itemnum
        end
    end
    local sortItems = {}
    for key, value in pairs(items) do
        table.insert(sortItems, {itemid = key, num = value.num, sortid = value.sortid, cornerType = nil})
    end
    table.sort(sortItems, function(a, b)
        return a.sortid < b.sortid
    end)
    
    

    if this.repeatItemViews[2] == nil then
        this.repeatItemViews[2] = {}
    end
    if #this.repeatItemViews[2] == 0 then
        for i = 1, 4 do --< 支持四个
            this.repeatItemViews[2][i] = SubUIManager.Open(SubUIConfig.ItemView, this.RewardTotalGrid.transform)
        end
    end

    for i = 1, #this.repeatItemViews[2] do
        if i <= #sortItems then
            this.repeatItemViews[2][i]:OnOpen(false, {sortItems[i].itemid, sortItems[i].num}, 0.6, nil, nil, nil, nil, sortItems[i].cornerType)
            this.repeatItemViews[2][i].gameObject:SetActive(true)
        else
            this.repeatItemViews[2][i].gameObject:SetActive(false)
        end
    end
 
    this.UnlockBtnFont.text = MoneyUtil.GetMoney(rewardNowData.Price)

end

--界面关闭时调用（用于子类重写）
function ClimbTowerUnlockPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function ClimbTowerUnlockPopup:OnDestroy()
    this.repeatItemViews = {}
end

return ClimbTowerUnlockPopup