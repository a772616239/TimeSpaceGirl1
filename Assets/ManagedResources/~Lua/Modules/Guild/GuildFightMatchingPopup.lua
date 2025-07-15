require("Base/BasePanel")
local GuildFightMatchingPopup = Inherit(BasePanel)
local this = GuildFightMatchingPopup

--初始化组件（用于子类重写）
function GuildFightMatchingPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.time = Util.GetGameObject(self.transform, "content/time/Text"):GetComponent("Text")
    this.guildRoot = Util.GetGameObject(self.transform, "content/fight/Left/Grade/my")
end

--绑定事件（用于子类重写）
function GuildFightMatchingPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function GuildFightMatchingPopup:AddListener()
end

--移除事件监听（用于子类重写）
function GuildFightMatchingPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GuildFightMatchingPopup:OnOpen(...)
    -- 我方数据显示
    local myGuildData = GuildFightManager.GetMyBaseData()
    this.GuildBaseInfoAdapter(this.guildRoot, myGuildData)

    this._TimeUpdate()
    if not this.timer then
        this.timer = Timer.New(this._TimeUpdate, 1, -1, true)
        this.timer:Start()
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildFightMatchingPopup:OnShow()

end

-- 公会基础数据匹配
function this.GuildBaseInfoAdapter(node, data)
    local nameText = Util.GetGameObject(node, "name"):GetComponent("Text")
    local levelText = Util.GetGameObject(node, "level"):GetComponent("Text")
    local starText = Util.GetGameObject(node, "starNum"):GetComponent("Text")
    local logoSpr = Util.GetGameObject(node, "icon"):GetComponent("Image")

    nameText.text = data.name
    levelText.text = data.level
    local logoName = GuildManager.GetLogoResName(data.pictureId)
    logoSpr.sprite = Util.LoadSprite(logoName)
    logoSpr:SetNativeSize()

    -- 星星数量显示
    starText.text = data.totalStar

end

-- 计时显示
function this._TimeUpdate()
    local guildFightData = GuildFightManager.GetGuildFightData()
    local curTime = GetTimeStamp()
    local roundEndTime = guildFightData.roundEndTime
    local leftTime = roundEndTime - curTime
    leftTime = leftTime < 0 and 0 or leftTime
    this.time.text = TimeToHMS(leftTime)
end
--界面关闭时调用（用于子类重写）
function GuildFightMatchingPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildFightMatchingPopup:OnDestroy()
    -- 计时器销毁
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

return GuildFightMatchingPopup