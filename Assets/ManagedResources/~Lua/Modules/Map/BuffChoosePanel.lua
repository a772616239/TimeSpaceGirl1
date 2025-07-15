require("Base/BasePanel")
local BuffChoosePanel = Inherit(BasePanel)
local this = BuffChoosePanel

local _LevelItemList = {}
local _BuffItemList = {}
local _TargetStr = {
    [1] = GetLanguageStrById(10489),
    [2] = GetLanguageStrById(11166),
    [3] = GetLanguageStrById(10407),
}

--初始化组件（用于子类重写）
function BuffChoosePanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "level/rightUp/btnBack")

    this.levelPanel = Util.GetGameObject(self.gameObject, "level")
    this.levelGrid = Util.GetGameObject(self.gameObject, "level/scroll/grid")
    this.levelItem = Util.GetGameObject(self.gameObject, "level/scroll/btnPre")

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
function BuffChoosePanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)

    Util.AddClick(this.buffCancel, function()
        this.buffPanel:SetActive(false)
        this.levelPanel:SetActive(true)
    end)
end

--添加事件监听（用于子类重写）
function BuffChoosePanel:AddListener()
end

--移除事件监听（用于子类重写）
function BuffChoosePanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BuffChoosePanel:OnOpen(...)
    -- 货币界面
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.TrialCoin})
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BuffChoosePanel:OnShow()
    --
    this.buffPanel:SetActive(false)
    this.levelPanel:SetActive(true)
    this.buffCancelTip:SetActive(false)
    this.buffCancelText:GetComponent("Text").text = GetLanguageStrById(11167)
    this.RefreshLevelShow()
end

-- 刷新层级显示
function this.RefreshLevelShow()

    -- 遍历关闭显示
    for _, item in ipairs(_LevelItemList) do
        item:SetActive(false)
    end

    -- 判断是否有保存的补给点
    local buffList = MapTrialManager.GetBuffList()
    if not buffList or #buffList <= 0 then
        return
    end

    for index, buff in ipairs(buffList) do
        if not _LevelItemList[index] then
            _LevelItemList[index] = newObjToParent(this.levelItem, this.levelGrid)
        end
        this.LevelItemAdapter(_LevelItemList[index], buff)
        _LevelItemList[index]:SetActive(true)
    end
end


-- 层级按钮数据匹配
function this.LevelItemAdapter(node, buff)
    local content = Util.GetGameObject(node, "level"):GetComponent("Text")
    local icons = {}
    icons[1] = Util.GetGameObject(node, "icon_1"):GetComponent("Image")
    icons[2] = Util.GetGameObject(node, "icon_2"):GetComponent("Image")
    icons[3] = Util.GetGameObject(node, "icon_3"):GetComponent("Image")

    content.text = string.format(GetLanguageStrById(11168), buff.towerLevel)

    local optionList = ConfigManager.GetConfigData(ConfigName.EventPointConfig, buff.eventId).Option
    for index, icon in ipairs(icons) do
        local optionId = optionList[index]
        local optionData = ConfigManager.GetConfigData(ConfigName.OptionConfig, optionId)
        if not optionData.AddConditionID or optionData.AddConditionID == 0 then
         
            return 
        end
        local optionAddData = ConfigManager.GetConfigData(ConfigName.OptionAddCondition, optionData.AddConditionID)
        local buffData = ConfigManager.GetConfigData(ConfigName.FoodsConfig, tonumber(optionAddData.Info))
        icon.sprite = Util.LoadSprite(buffData.EffectShowIcon)
    end


    Util.AddOnceClick(node, function()
        this.ShowBuffPanel(buff.towerLevel, buff.eventId)
    end)
end

-- 显示buff选择
function this.ShowBuffPanel(level, eventId)
    this.levelPanel:SetActive(false)
    this.buffPanel:SetActive(true)
    -- 遍历关闭显示
    for _, item in ipairs(_BuffItemList) do
        item:SetActive(false)
    end

    -- 判断是否有保存的补给点
    local optionList = ConfigManager.GetConfigData(ConfigName.EventPointConfig, eventId).Option
    for index, optionId in ipairs(optionList) do
        -- 最后一个不显示
        if index ~= #optionList then
            if not _BuffItemList[index] then
                _BuffItemList[index] = newObjToParent(this.buffItem, this.buffGrid)
            end
            this.BuffItemAdapter(_BuffItemList[index], optionId, level, eventId)
            _BuffItemList[index]:SetActive(true)
        end
    end
end

--- buff节点数据匹配
function this.BuffItemAdapter(node, optionId, level, eventId)
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

    Util.AddOnceClick(node, function()
        local itemConfigData=ConfigManager.GetConfigData(ConfigName.ItemConfig, costId)
        local tipStr = string.format(GetLanguageStrById(11171), costNum, GetStringByEquipQua(itemConfigData.Quantity, itemConfigData.Name), optionData.Info)
        MsgPanel.ShowTwo(tipStr, nil, function()
            -- 判断消耗
            if not MapManager.ItemNumJudge(optionId) then
                PopupTipPanel.ShowTipByLanguageId(11172)
                return
            end
            -- 使用buff的接口
            NetManager.RequestUseBuff(level, optionId, function (msg)
                this.buffPanel:SetActive(false)
                this.levelPanel:SetActive(true)
                -- 删除相应的补给点
                MapTrialManager.RemoveBuff(level, eventId)
                this.RefreshLevelShow()
                -- 初始化buff数据
                OptionBehaviourManager.UpdateEventPoint(msg, optionId)
                -- 判断是否要自动关闭界面
                local buffList = MapTrialManager.GetBuffList()
                if not buffList or #buffList <= 0 then
                    this:ClosePanel()
                end
            end)
        end)
    end)
end



--界面关闭时调用（用于子类重写）
function BuffChoosePanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function BuffChoosePanel:OnDestroy()
    _LevelItemList = {}
    _BuffItemList = {}

    SubUIManager.Close(this.UpView)
end

return BuffChoosePanel