require("Base/BasePanel")
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
CarbonBuyCountPopup = Inherit(BasePanel)
local this = CarbonBuyCountPopup
local curBuyCount = 0
local costNeed = 0
local itemID = 0

--初始化组件（用于子类重写）
function CarbonBuyCountPopup:InitComponent()

    this.mask = Util.GetGameObject(self.gameObject, "BackMask")
    this.title = Util.GetGameObject(self.gameObject, "bg/title"):GetComponent("Text")
    this.leftBuyCount = Util.GetGameObject(self.gameObject, "bg/content"):GetComponent("Text")
    this.icon = Util.GetGameObject(self.gameObject, "bg/icon"):GetComponent("Image")
    this.btnConfirm = Util.GetGameObject(self.gameObject, "bg/Confirm")
    this.btnCancel = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.textCost = Util.GetGameObject(self.gameObject, "bg/cost"):GetComponent("Text")
    this.textFreshInfo = Util.GetGameObject(self.gameObject, "bg/info"):GetComponent("Text")
    this.textBuyNum = Util.GetGameObject(self.gameObject, "bg/Slider/numText"):GetComponent("Text")

    -- 滑条
    this.slider = Util.GetGameObject(self.gameObject, "bg/Slider")
    this.chooseNum = Util.GetGameObject( this.slider, "numText"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function CarbonBuyCountPopup:BindEvent()

    -- 关闭按钮事件监听
    Util.AddClick(this.btnCancel, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)

    Util.AddSlider(this.slider, function(go, value)
        this.OnSliderValueChange(value)
    end)

    -- 确认按钮事件
    Util.AddClick(this.btnConfirm, function()

        if curBuyCount == 0 then
            PopupTipPanel.ShowTipByLanguageId(11542)
            return
        end

        if CarbonManager.getLeftBuyCount() <= 0 then
            PopupTipPanel.ShowTipByLanguageId(11543)
            return
        end

        -- 当前剩余挑战次数
        local leftChallengeCount = CarbonManager.getLeftChallengeCount()
        -- 副本购买上限
        local maxLimitCount = CarbonManager.getMaxLimitCount()
        if leftChallengeCount >= maxLimitCount then
            PopupTipPanel.ShowTipByLanguageId(11544)
            return
        end

        -- 购买后的总量大于上限，只给购买到上限
        if curBuyCount + leftChallengeCount > maxLimitCount then
            local canBuy = maxLimitCount - leftChallengeCount
            PopupTipPanel.ShowTip(GetLanguageStrById(11545) .. canBuy .. GetLanguageStrById(10054))
            return
        end

        if costNeed > BagManager.GetItemCountById(itemID) then
            PopupTipPanel.ShowTipByLanguageId(11546)
            return
        end

        NetManager.BuyFightCountRequest(curBuyCount, function ()
            -- 关闭当前界面
            self:ClosePanel()
            -- 刷新物品数量
            --改为后端刷新了
            --BagManager.UpdateItemsNum(itemID, costNeed)
            -- 发送事件更新界面显示
            Game.GlobalEvent:DispatchEvent(GameEvent.Carbon.CarbonCountChange)
            PopupTipPanel.ShowTipByLanguageId(10545)
        end)
    end)
end

--添加事件监听（用于子类重写）
function CarbonBuyCountPopup:AddListener()

end

--移除事件监听（用于子类重写）
function CarbonBuyCountPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function CarbonBuyCountPopup:OnOpen(count)

    local sliderComp = this.slider:GetComponent("Slider")
    local maxValue = CarbonManager.getLeftBuyCount()
    sliderComp.maxValue = maxValue
    sliderComp.enabled = maxValue > 1
    sliderComp.minValue = maxValue > 1 and 1 or 0
    sliderComp.value = 1

    -- 刷新选择条数据
    this.RefreshData(count)

end

--根据Slider的数据刷新面板上的数据
function this.RefreshData(chooseNum)

    -- 剩余可购买次数
    local leftBuyCount = CarbonManager.getLeftBuyCount()
    local curLeftBuyCount = leftBuyCount - chooseNum
    if curLeftBuyCount < 0 then
        chooseNum = leftBuyCount
        curLeftBuyCount = 0
    end

    -- 设置当前
    this.slider:GetComponent("Slider").value = chooseNum

    -- 当前选择购买次数
    this.chooseNum.text = chooseNum

    -- 当前购买次数
    curBuyCount = chooseNum
    itemID, costNeed = CarbonManager.calBuyCountCost(chooseNum)

    --刷新显示
    this.icon.sprite = Util.LoadSprite(GetResourcePath(ItemConfig[itemID].ResourceID))
    this.title.text = GetLanguageStrById(11547)
    this.leftBuyCount.text = GetLanguageStrById(11548)..curLeftBuyCount.."）"
    this.textCost.text = chooseNum > 0 and costNeed or 0
    this.textFreshInfo.text = GetLanguageStrById(11549)
end

function this.OnSliderValueChange(value)
    this.RefreshData(value)
end

--界面关闭时调用（用于子类重写）
function CarbonBuyCountPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function CarbonBuyCountPopup:OnDestroy()

end

return CarbonBuyCountPopup