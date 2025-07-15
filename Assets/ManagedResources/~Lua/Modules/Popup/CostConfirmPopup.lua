---
---CostConfirmPopup.Show(itemId, costNum, content, tip, func, costTipType)
---     参数：itemId         物品id  （not nil）
---           costNum       要消耗的数量（not nil）
---           content       显示内容（not nil）
---           tip           提示信息，nil则不显示
---           func           确认按钮回调事件
---           costTipType    界面类型，用于判断是否需要 不再显示 功能，默认不需要，
---               需要 不再显示 功能的，需在下面 COST_CONFIRM_TYPE 中注册相应的类型，并作为参数传入
---

require("Base/BasePanel")
CostConfirmPopup = Inherit(BasePanel)
local this=CostConfirmPopup

-- 界面类型
COST_CONFIRM_TYPE = {
    NO_POPUP_TOGGLE = 0,
    SOUL_PRINT = 1,
    BUYTREASURE_LEVEL = 2,
}
--初始化组件（用于子类重写）
function CostConfirmPopup:InitComponent()
    this.tipConfirmBtn=Util.GetGameObject(this.gameObject,"Panel/ConfirmBtn")
    this.tipBackBtn=Util.GetGameObject(this.gameObject,"Panel/BackBtn")

    this.toggleBox = Util.GetGameObject(this.gameObject, "Panel/box/toggle")
    this.tipToggle = Util.GetGameObject(this.toggleBox, "Toggle"):GetComponent("Toggle")
    this.costIcon = Util.GetGameObject(this.gameObject,"Panel/box/base/CostNum/CostItemIcon"):GetComponent("Image")
    this.costNumText = Util.GetGameObject(this.gameObject,"Panel/box/base/CostNum"):GetComponent("Text")
    this.contentText = Util.GetGameObject(this.gameObject,"Panel/box/base/content"):GetComponent("Text")
    this.tipText = Util.GetGameObject(this.gameObject,"Panel/box/tip"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function CostConfirmPopup:BindEvent()
    --提示框确定按钮
    Util.AddClick(this.tipConfirmBtn, function()
        -- 不是
        if this.costTipType ~= COST_CONFIRM_TYPE.NO_POPUP_TOGGLE then
            if this.tipToggle.isOn then
                local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "isShowPopUp" .. this.costTipType, currentTime)
            end
        end

        if this.func then this.func() end
        self:ClosePanel()
    end)
    --提示框关闭按钮
    Util.AddClick(this.tipBackBtn, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function CostConfirmPopup:AddListener()
end

--移除事件监听（用于子类重写）
function CostConfirmPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function CostConfirmPopup:OnOpen(itemId, costNum, content, tip, func, costTipType)
    this.itemId = itemId
    this.costNum = costNum
    this.content = content
    this.tip = tip
    this.func = func
    this.costTipType = costTipType or COST_CONFIRM_TYPE.NO_POPUP_TOGGLE
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function CostConfirmPopup:OnShow()

    --基础显示
    this.costIcon.sprite = SetIcon(this.itemId)
    this.costNumText.text=this.costNum
    this.contentText.text=" "..this.content

    -- 判断是否需要显示tip
    if this.tip then
        this.tipText.gameObject:SetActive(true)
        this.tipText.text=this.tip
    else
        this.tipText.gameObject:SetActive(false)
    end

    -- 今日不再弹出功能
    this.tipToggle.isOn = false -- 默认关闭
    this.toggleBox:SetActive(this.costTipType ~= COST_CONFIRM_TYPE.NO_POPUP_TOGGLE)
end

--
function CostConfirmPopup.Show(itemId, costNum, content, tip, func, costTipType)
    -- 界面默认类型为没有控制弹出功能的类型
    costTipType = costTipType or COST_CONFIRM_TYPE.NO_POPUP_TOGGLE
    if costTipType == COST_CONFIRM_TYPE.NO_POPUP_TOGGLE then
        UIManager.OpenPanel(UIName.CostConfirmPopup, itemId, costNum, content, tip, func, costTipType)
        return
    end

    --如果是同一天不必再弹出，否则弹出确认界面
    local lastPopupDay = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "isShowPopUp"..costTipType)
    local currentDay = os.date("%Y%m%d", PlayerManager.serverTime)
    if lastPopupDay == currentDay  then
        if func then func() end
    else
        UIManager.OpenPanel(UIName.CostConfirmPopup, itemId, costNum, content, tip, func, costTipType)
    end

end
--界面关闭时调用（用于子类重写）
function CostConfirmPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function CostConfirmPopup:OnDestroy()
end

return CostConfirmPopup