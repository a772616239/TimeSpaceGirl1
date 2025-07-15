require("Base/BasePanel")
local BuffOptionPanel = Inherit(BasePanel)
local this = BuffOptionPanel

local _BuffItemList = {}
local _TargetStr = {
    [1] = GetLanguageStrById(10489),
    [2] = GetLanguageStrById(11166),
    [3] = GetLanguageStrById(10407),
}
--初始化组件（用于子类重写）
function BuffOptionPanel:InitComponent()
    this.levelPanel = Util.GetGameObject(self.gameObject, "level")
    this.buffPanel = Util.GetGameObject(self.gameObject, "buff")
    this.buffGrid = Util.GetGameObject(self.gameObject, "buff/grid")
    this.buffItem = Util.GetGameObject(self.gameObject, "buff/btnBuffInfo")
    this.buffCancel = Util.GetGameObject(self.gameObject, "buff/Cancel")
    this.buffCancelText = Util.GetGameObject(self.gameObject, "buff/Cancel/Text")
    this.buffCancelTip = Util.GetGameObject(self.gameObject, "buff/Cancel/tip")

    -- 上部货币显示
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft})
end

--绑定事件（用于子类重写）
function BuffOptionPanel:BindEvent()
    -- 执行最后一个option，策划配置最后一个事件点为保存buff
    Util.AddClick(this.buffCancel, function()
        local optionList = ConfigManager.GetConfigData(ConfigName.EventPointConfig, this.eventId).Option
        OptionBehaviourManager.JumpEventPoint(this.eventId, optionList[#optionList], this)
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function BuffOptionPanel:AddListener()
end

--移除事件监听（用于子类重写）
function BuffOptionPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BuffOptionPanel:OnOpen(eventId)
    this.eventId = eventId

    this.levelPanel:SetActive(false)
    this.buffPanel:SetActive(true)
    this.buffCancelTip:SetActive(true)
    this.buffCancelText:GetComponent("Text").text = GetLanguageStrById(11173)
    -- 货币界面
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.TrialCoin})
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BuffOptionPanel:OnShow()
    this.ShowBuffPanel()
end

-- 显示buff选择
function this.ShowBuffPanel()
    this.levelPanel:SetActive(false)
    this.buffPanel:SetActive(true)
    -- 遍历关闭显示
    for _, item in ipairs(_BuffItemList) do
        item:SetActive(false)
    end

    -- 判断是否有保存的补给点
    local optionList = ConfigManager.GetConfigData(ConfigName.EventPointConfig, this.eventId).Option
    for index = 1, #optionList - 1 do
        local optionId = optionList[index]
        -- 最后一个不显示
        if index ~= #optionList then
            if not _BuffItemList[index] then
                _BuffItemList[index] = newObjToParent(this.buffItem, this.buffGrid)
            end
            this.BuffItemAdapter(_BuffItemList[index], optionId)
            _BuffItemList[index]:SetActive(true)
        end
    end

end

--- buff节点数据匹配
function this.BuffItemAdapter(node, optionId)
    local icon = Util.GetGameObject(node, "icon"):GetComponent("Image")
    local content = Util.GetGameObject(node, "context"):GetComponent("Text")
    local target = Util.GetGameObject(node, "target"):GetComponent("Text")
    local step = Util.GetGameObject(node, "step"):GetComponent("Text")
    local itemIcon = Util.GetGameObject(node, "itemIcon"):GetComponent("Image")
    local itemNum = Util.GetGameObject(node, "itemNum"):GetComponent("Text")

    local optionData = ConfigManager.GetConfigData(ConfigName.OptionConfig, optionId)
    if not optionData.AddConditionID or optionData.AddConditionID == 0 then
        return 
    end
    local optionAddData = ConfigManager.GetConfigData(ConfigName.OptionAddCondition, optionData.AddConditionID)
    local buffData = ConfigManager.GetConfigData(ConfigName.FoodsConfig, tonumber(optionAddData.Info))

    icon.sprite = Util.LoadSprite(buffData.EffectShowIcon)
    content.text = optionData.Info
    target.text = _TargetStr[buffData.Target]
    step.text = buffData.Contiue == 0 and GetLanguageStrById(11170) or buffData.Contiue

    local costId, costNum = optionAddData.Values[1][1], optionAddData.Values[1][2]
    itemIcon.sprite = SetIcon(costId)
    itemNum.text = costNum

    Util.AddOnceClick(node, function() local itemConfigData=ConfigManager.GetConfigData(ConfigName.ItemConfig, costId)
        local tipStr = string.format(GetLanguageStrById(11171), costNum, GetStringByEquipQua(itemConfigData.Quantity, itemConfigData.Name), optionData.Info)
        MsgPanel.ShowTwo(tipStr, nil, function()
            -- 判断消耗
            if not MapManager.ItemNumJudge(optionId) then
                PopupTipPanel.ShowTipByLanguageId(11172)
                return
            end
            OptionBehaviourManager.JumpEventPoint(this.eventId, optionId, this)
            this:ClosePanel()
        end)
    end)
end
--界面关闭时调用（用于子类重写）
function BuffOptionPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function BuffOptionPanel:OnDestroy()
    _BuffItemList = {}

    SubUIManager.Close(this.UpView)
end

return BuffOptionPanel