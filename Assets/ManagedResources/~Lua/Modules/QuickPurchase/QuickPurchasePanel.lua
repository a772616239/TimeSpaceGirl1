--[[
 * @ClassName QuickPurchasePanel
 * @Description 快捷购买界面
 * @Date 2019/5/17 20:25
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]

local QuickCommonPurchasePart = require("Modules/QuickPurchase/QuickCommonPurchasePart")
local QuickSpecialPurchasePart = require("Modules/QuickPurchase/QuickSpecialPurchasePart")
local QuickCoinPurchasePart = require("Modules/QuickPurchase/QuickCoinPurchasePart")

---@class QuickPurchasePanel
local QuickPurchasePanel = quick_class("QuickPurchasePanel", BasePanel)

local ColorDef = {
    "#000000FF",
    "#FF0000FF",
    "#FF0000FF",
}

function QuickPurchasePanel:InitComponent()
    self.transform:Find("frame"):GetComponent("Button").onClick:AddListener(function()
        self:ClosePanel()
    end)
    -- self.title = Util.GetGameObject(self.transform, "frame/bg/upbar/title"):GetComponent("Text")
    self.help = Util.GetGameObject(self.transform, "Panel/bg/upbar/help")
    self.upbar = Util.GetGameObject(self.transform, "Panel/bg/upbar")
    self.commonPurchase = QuickCommonPurchasePart.new(self, self.transform:Find("Panel/bg/commonPart"))
    self.commonPurchase:OnHide()
    self.specialPurchase = QuickSpecialPurchasePart.new(self, self.transform:Find("Panel/bg/specialPart"))
    self.specialPurchase:OnHide()
    self.coinPurchase = QuickCoinPurchasePart.new(self,self.transform:Find("Panel/bg/coinPart"))
    self.coinPurchase:OnHide()

    Util.AddOnceClick(self.help, function()
        local pos = self.help.transform.localPosition
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.BuyCoin, pos.x, pos.y)
    end)
end

--context = {type}
function QuickPurchasePanel:OnOpen(context)
    -- self.title.text = GetLanguageStrById(11701)
    self.help:SetActive(false)

    self.upbar.transform.anchoredPosition = Vector3.New(0, -338, 0)
    if context.type == UpViewRechargeType.Energy or
            -- context.type == UpViewRechargeType.Gold or
            context.type == UpViewRechargeType.ChallengeTicket or
            context.type == UpViewRechargeType.EliteCarbonTicket or
            context.type == UpViewRechargeType.DemonCrystal or
            context.type == UpViewRechargeType.LightRing or
            context.type == UpViewRechargeType.ActPower or
            context.type == UpViewRechargeType.AdventureAlianInvasionTicket or
            context.type == UpViewRechargeType.ChangeNameCard or
            context.type == UpViewRechargeType.MonsterCampTicket or
            context.type == UpViewRechargeType.HourGlass or
            context.type == UpViewRechargeType.XingYao or
            context.type == UpViewRechargeType.ChatHorn
    then
        self.commonPurchase:OnShow(context)
    elseif context.type == UpViewRechargeType.SpiritTicket or
            context.type == UpViewRechargeType.GhostRing or
            context.type == UpViewRechargeType.ElementDrawCardTicket
    then
        self.specialPurchase:OnShow(context)
    elseif context.type == UpViewRechargeType.Gold then
        self.coinPurchase:OnShow(context)
        -- self.title.text = GetLanguageStrById(11702)
        self.upbar.transform.anchoredPosition = Vector3.New(0, -60, 0)
        self.help:SetActive(true)
    end
end

function QuickPurchasePanel:OnClose()
    self.commonPurchase:OnHide()
    self.specialPurchase:OnHide()
    self.coinPurchase:OnHide()
end

function QuickPurchasePanel:GetRemainBuyTimes(Id)
    local limitBuyTimes = ShopManager.GetShopItemLimitBuyCount(Id)
    if limitBuyTimes == -1 then
        return math.huge
    else
        local hadBuyTimes = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FUNCTION_SHOP, Id)
        return limitBuyTimes - hadBuyTimes
    end
end

function QuickPurchasePanel:GetConfigData(Id)
    local storeConfig = ConfigManager.GetConfigData(ConfigName.StoreConfig, Id)
    assert(storeConfig, string.format("ConfigName.StoreConfig not find Id:%s", Id))
    return storeConfig
end

-- function QuickPurchasePanel:GetCostTextColor(flag)
--     return flag and ColorDef[1] or ColorDef[2]
-- end

return QuickPurchasePanel