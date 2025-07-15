require("Base/BasePanel")
NotEnoughPopup = Inherit(BasePanel)
local this = NotEnoughPopup

-- 跳转商店购买窗口，物品id对应界面及参数
local _JumpConfig = {
    [16] = {panelName = UIName.MainRechargePanel, params = {1} },
}

--初始化组件（用于子类重写）
function NotEnoughPopup:InitComponent()
    this.title = Util.GetGameObject(self.transform, "title"):GetComponent("Text")
    this.content = Util.GetGameObject(self.transform, "content"):GetComponent("Text")
    this.btnLeft = Util.GetGameObject(self.transform, "op/btnLeft")
    this.btnRight = Util.GetGameObject(self.transform, "op/btnRight")
    this._toggle= Util.GetGameObject (self.transform, "Toggle")
end

--绑定事件（用于子类重写）
function NotEnoughPopup:BindEvent()
    Util.AddClick(this.btnLeft, function()
        this:ClosePanel()
    end)
    Util.AddClick(this.btnRight, function()
        this:ClosePanel()
        if _JumpConfig[this._ItemId] then
            UIManager.OpenPanel(_JumpConfig[this._ItemId].panelName, unpack(_JumpConfig[this._ItemId].params))
        else
            PopupTipPanel.ShowTipByLanguageId(11353)
        end
    end)
end

--添加事件监听（用于子类重写）
function NotEnoughPopup:AddListener()
end

--移除事件监听（用于子类重写）
function NotEnoughPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function NotEnoughPopup:OnOpen(itemId)
    this._ItemId = itemId
    local itemName = ConfigManager.GetConfigData(ConfigName.ItemConfig, itemId).Name
    this.content.text = string.format(GetLanguageStrById(11354), GetLanguageStrById(itemName))
    this.title.text = GetLanguageStrById(11355)
    this._toggle.gameObject:SetActive(false)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function NotEnoughPopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function NotEnoughPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function NotEnoughPopup:OnDestroy()
end

--
function NotEnoughPopup:Show(itemId, func)
    if not MapManager.isInMap and _JumpConfig[itemId] then
        if itemId == 15 and not ShopManager.IsActive(SHOP_TYPE.SOUL_STONE_SHOP)then
            PopupTipPanel.ShowTipByLanguageId(10847)
            return
        end
        if func then func() end
        UIManager.OpenPanel(UIName.NotEnoughPopup, itemId)
    else
        PopupTipPanel.ShowTipByLanguageId(10847)
    end
end

return NotEnoughPopup