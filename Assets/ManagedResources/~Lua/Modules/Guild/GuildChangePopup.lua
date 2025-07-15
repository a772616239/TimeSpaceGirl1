require("Base/BasePanel")
local _LogoList = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).TotemItem
local GuildChangePopup = Inherit(BasePanel)
local this = GuildChangePopup

this._ViewTypeTitle = {
    [GUILD_CHANGE_TYPE.ANNOUNCE] = GetLanguageStrById(10841),
    [GUILD_CHANGE_TYPE.SETTING] = GetLanguageStrById(10842),
    [GUILD_CHANGE_TYPE.LOGO] = GetLanguageStrById(10843),
    [GUILD_CHANGE_TYPE.NAME] = GetLanguageStrById(10844),
}

-- 限制等级列表
local _LimitLevelList = {
    [1] = 0,
    [2] = 5,
    [3] = 10,
    [4] = 15,
    [5] = 20,
    [6] = 25,
    [7] = 30,
    [8] = 35,
    [9] = 40,
    [10] = 45,
    [11] = 50,
    [12] = 55,
    [13] = 60,
    [14] = 65,
    [15] = 70,
    [16] = 75,
    [17] = 80,
    [18] = 85,
    [19] = 90,
    [20] = 95,
    [21] = 100,
}


--初始化组件（用于子类重写）
function GuildChangePopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnClose")
    this.btnCreate = Util.GetGameObject(self.transform, "tipImage/btnCreate")
    this.costTip = Util.GetGameObject(this.btnCreate, "costTips"):GetComponent("Text")
    this.TL = Util.GetGameObject(this.btnCreate, "costTips/TL"):GetComponent("Text")
    this.TR = Util.GetGameObject(this.btnCreate, "costTips/TR"):GetComponent("Text")

    this.title = Util.GetGameObject(self.transform, "tipImage/title"):GetComponent("Text")

    -- 宣言
    this.announcePanel = Util.GetGameObject(self.transform, "tipImage/content/announce")
    this.inputAnnounce = Util.GetGameObject(this.announcePanel, "content"):GetComponent("InputField")
    -- 公会名称
    this.namePanel = Util.GetGameObject(self.transform, "tipImage/content/gname")
    this.inputName = Util.GetGameObject(this.namePanel, "content"):GetComponent("InputField")
    -- 入会设置
    this.settingPanel = Util.GetGameObject(self.transform, "tipImage/content/setting")
    this.isVerify = Util.GetGameObject(this.settingPanel, "verify/isVerify"):GetComponent("Toggle")
    this.levelBg = Util.GetGameObject(this.settingPanel, "level/bg")
    this.levelText = Util.GetGameObject(this.settingPanel, "level/Text"):GetComponent("Text")
    this.levelLeft = Util.GetGameObject(this.settingPanel, "level/leftbtn")
    this.levelRight = Util.GetGameObject(this.settingPanel, "level/rightbtn")
    this.scrollClose = Util.GetGameObject(this.settingPanel, "level/scroll/close")
    this.scrollRoot = Util.GetGameObject(this.settingPanel, "level/scroll")
    this.levelItem = Util.GetGameObject(this.settingPanel, "level/scroll/item")
    -- 图腾设置
    this.logoPanel = Util.GetGameObject(self.transform, "tipImage/content/logo")
    this.logo = Util.GetGameObject(this.logoPanel, "Image"):GetComponent("Image")
    this.logoLeft = Util.GetGameObject(this.logoPanel, "left")
    this.logoRight = Util.GetGameObject(this.logoPanel, "right")
    this.curChoose = Util.GetGameObject(this.logoPanel, "cur")

    this.ContentPanel = {}
    this.ContentPanel[GUILD_CHANGE_TYPE.ANNOUNCE] = this.announcePanel
    this.ContentPanel[GUILD_CHANGE_TYPE.SETTING] = this.settingPanel
    this.ContentPanel[GUILD_CHANGE_TYPE.LOGO] = this.logoPanel
    this.ContentPanel[GUILD_CHANGE_TYPE.NAME] = this.namePanel
end

--绑定事件（用于子类重写）
function GuildChangePopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    -- 确认修改
    Util.AddClick(this.btnCreate, function()
        -- 刷新显示
        if this._ViewType == GUILD_CHANGE_TYPE.ANNOUNCE then
            this.SaveAnnounce()
        elseif this._ViewType == GUILD_CHANGE_TYPE.SETTING then
            this.SaveSetting()
        elseif this._ViewType == GUILD_CHANGE_TYPE.LOGO then
            this.SaveLogo()
        elseif this._ViewType == GUILD_CHANGE_TYPE.NAME then
            this.SaveName()
        end
    end)

    -- 点击等级选择
    Util.AddClick(this.levelBg, function()
        -- 刷新显示
        this.scrollRoot:SetActive(true)
    end)
    -- 点击等级选择
    Util.AddClick(this.scrollClose, function()
        -- 刷新显示
        this.scrollRoot:SetActive(false)
    end)
    -- 点击等级选择
    Util.AddClick(this.levelLeft, function()
        if this._CurLevelIndex <= 1 then return end
        this._CurLevelIndex = this._CurLevelIndex - 1
        this._CurLimitLevel = _LimitLevelList[this._CurLevelIndex]
        this.levelText.text = this._CurLimitLevel
    end)
    -- 点击等级选择
    Util.AddClick(this.levelRight, function()
        if this._CurLevelIndex >= #_LimitLevelList then return end
        this._CurLevelIndex = this._CurLevelIndex + 1
        this._CurLimitLevel = _LimitLevelList[this._CurLevelIndex]
        this.levelText.text = this._CurLimitLevel
    end)


    -- 向左切换图腾
    Util.AddClick(this.logoLeft, function()
        if not this.logoId then return end
        local nextLogo = this.logoId - 1
        if not _LogoList[nextLogo] then
            nextLogo = #_LogoList
        end
        this.RefreshLogoImage(nextLogo)
    end)
    -- 向右切换图腾
    Util.AddClick(this.logoRight, function()
        if not this.logoId then return end
        local nextLogo = this.logoId + 1
        if not _LogoList[nextLogo] then
            nextLogo = 1
        end
        this.RefreshLogoImage(nextLogo)
    end)


end

--添加事件监听（用于子类重写）
function GuildChangePopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.BeKickOut, this.CloseSelf)
end

--移除事件监听（用于子类重写）
function GuildChangePopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.BeKickOut, this.CloseSelf)
end

-- 关闭界面
function this.CloseSelf()
    this:ClosePanel()
end

--界面打开时调用（用于子类重写）
function GuildChangePopup:OnOpen(viewType)
    this._ViewType = viewType

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildChangePopup:OnShow()
    -- 标题
    this.title.text = this._ViewTypeTitle[this._ViewType]

    -- 判断显示
    for type, view in pairs(this.ContentPanel) do
        view:SetActive(this._ViewType == type)
    end
    -- 消耗显示关闭
    this.costTip.gameObject:SetActive(false)

    -- 刷新显示
    if this._ViewType == GUILD_CHANGE_TYPE.ANNOUNCE then
        this.RefreshAnnounceShow()
    elseif this._ViewType == GUILD_CHANGE_TYPE.SETTING then
        this.RefreshSettingShow()
    elseif this._ViewType == GUILD_CHANGE_TYPE.LOGO then
        this.RefreshLogoShow()
    elseif this._ViewType == GUILD_CHANGE_TYPE.NAME then
        this.RefreshNameShow()
    end
end

-- 刷新宣言显示
function this.RefreshAnnounceShow()
    local guildInfo = MyGuildManager.GetMyGuildInfo()
    this.inputAnnounce.text = guildInfo.annouce
end
function this.SaveAnnounce()
    local announce = this.inputAnnounce.text
    MyGuildManager.RequestChangeGuildAnnounce(announce, function()
        this:ClosePanel()
        -- 提示
        PopupTipPanel.ShowTipByLanguageId(10845)
    end)
end

-- 刷新宣言显示
function this.RefreshSettingShow()
    -- 加入状态
    local guildInfo = MyGuildManager.GetMyGuildInfo()
    this.isVerify.isOn = guildInfo.joinType == GUILD_JOIN_TYPE.LIMIT
    this.levelText.text = guildInfo.playerIntoLevel
    this._CurLimitLevel = guildInfo.playerIntoLevel
    this._CurLevelIndex = 1
    for index, level in ipairs(_LimitLevelList) do
        if level == this._CurLimitLevel then
            this._CurLevelIndex = index
            break
        end
    end
    -- 创建滚动
    if not this.limitLevelScroll then
        local height = this.scrollRoot.transform.rect.height
        local width = this.scrollRoot.transform.rect.width
        this.limitLevelScroll = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform,
                this.levelItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0))
        this.limitLevelScroll.moveTween.Strength = 2
        this.limitLevelScroll:SetData(_LimitLevelList, function(index, go)
            go:GetComponent("Text").text = _LimitLevelList[index]
            Util.AddOnceClick(go, function ()
                local limitLevel = _LimitLevelList[index]
                this._CurLimitLevel = limitLevel
                this._CurLevelIndex = index
                this.levelText.text = limitLevel
                this.scrollRoot:SetActive(false)
            end)
        end)
    end
end
function this.SaveSetting()
    local joinType = this.isVerify.isOn and GUILD_JOIN_TYPE.LIMIT or GUILD_JOIN_TYPE.NO_LIMIT
    local guildData = MyGuildManager.GetMyGuildInfo()
    if joinType == guildData.joinType and this._CurLimitLevel == guildData.playerIntoLevel then
        this:ClosePanel()
        PopupTipPanel.ShowTipByLanguageId(10845)
        return
    end
    MyGuildManager.RequestChangeJoinType(joinType, this._CurLimitLevel, function()
        this:ClosePanel()
        PopupTipPanel.ShowTipByLanguageId(10845)
    end)
end

-- 刷新宣言显示
function this.RefreshLogoShow()
    -- 刷新
    this.RefreshLogoImage()
    -- 创建消耗
    local cost = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).TotemCost
    local costName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig, cost[1]).Name)
    this.costTip.text = string.format(GetLanguageStrById(10846), cost[2], costName)
    this.costTip.gameObject:SetActive(true)
end

-- 刷新图腾显示
function this.RefreshLogoImage(logoId)
    local guildData = MyGuildManager.GetMyGuildInfo()
    if not logoId then
        logoId = guildData.icon == 0 and 1 or guildData.icon
    end
    this.logoId = logoId
    local logoName = GuildManager.GetLogoResName(logoId)
    this.logo.sprite = Util.LoadSprite(logoName)
    this.curChoose:SetActive(this.logoId == guildData.icon)
end

function this.SaveLogo()
    -- 判断物品数量
    local cost = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).TotemCost
    local haveNum = BagManager.GetItemCountById(cost[1])
    if haveNum < cost[2] then
        PopupTipPanel.ShowTipByLanguageId(10847)
        return
    end

    local guildData = MyGuildManager.GetMyGuildInfo()
    if this.logoId == guildData.icon then
        this:ClosePanel()
        return
    end

    CostConfirmPopup.Show(cost[1], cost[2], GetLanguageStrById(10848), nil, function()
        MyGuildManager.RequestChangeLogo(this.logoId, function()
            this:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10849)
        end)
    end)

end

-- 刷新公会名称显示
function GuildChangePopup.RefreshNameShow()
    local guildInfo = MyGuildManager.GetMyGuildInfo()
    this.inputName.text = guildInfo.name

    -- 创建消耗
    local cost = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).RenameCost
    local costName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig, cost[1][1]).Name)
    -- this.costTip.text = string.format(, )
    
    
    this.TL.text = GetLanguageStrById(10844) .. GetLanguageStrById(10216)
    this.TR.text = cost[1][2] .. costName
    this.costTip.gameObject:SetActive(true)
end
-- 保存公会名称
function GuildChangePopup.SaveName()
    local name = this.inputName.text
    MyGuildManager.RequestChangeGuildName(name, function()
        this:ClosePanel()
        -- 提示
        PopupTipPanel.ShowTipByLanguageId(10845)
    end)

end



--界面关闭时调用（用于子类重写）
function GuildChangePopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildChangePopup:OnDestroy()
    this.limitLevelScroll = nil
end

return GuildChangePopup