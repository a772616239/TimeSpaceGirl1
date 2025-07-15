require("Base/BasePanel")
local GuildLogoPopup = Inherit(BasePanel)
local this = GuildLogoPopup
-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabFontColor = { default = Color.New(168 / 255, 168 / 255, 167 / 255, 1),
                        select = Color.New(250 / 255, 227 / 255, 175 / 255, 1) }
local _TabSprite = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001"}
local _TabData = {
    [1] = { name = GetLanguageStrById(10922) },
    --[2] = { name = "公会战" },
}



--初始化组件（用于子类重写）
function GuildLogoPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.tabbox = Util.GetGameObject(self.transform, "top")

    this.logoPanel = Util.GetGameObject(self.transform, "content/logo")
    this.btnChange = Util.GetGameObject(this.logoPanel, "btnChange")
    this.pingTxt = Util.GetGameObject(this.logoPanel, "grade/ping/Text"):GetComponent("Text")
    this.winTxt = Util.GetGameObject(this.logoPanel, "grade/win/Text"):GetComponent("Text")
    this.loseTxt = Util.GetGameObject(this.logoPanel, "grade/lose/Text"):GetComponent("Text")
    this.guildLogo = Util.GetGameObject(this.logoPanel, "Logo"):GetComponent("Image")

end

--绑定事件（用于子类重写）
function GuildLogoPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    Util.AddClick(this.btnChange, function()
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10923)
            return
        end
        UIManager.OpenPanel(UIName.GuildChangePopup, GUILD_CHANGE_TYPE.LOGO)
    end)

    -- 初始化Tab管理器
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)
end

--添加事件监听（用于子类重写）
function GuildLogoPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.DataUpdate, this.RefreshLogoPanelShow)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.BeKickOut, this.CloseSelf)
end

--移除事件监听（用于子类重写）
function GuildLogoPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.DataUpdate, this.RefreshLogoPanelShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.BeKickOut, this.CloseSelf)
end

-- 关闭界面
function this.CloseSelf()
    this:ClosePanel()
end

--界面打开时调用（用于子类重写）
function GuildLogoPopup:OnOpen(...)
    if this.TabCtrl then
        this.TabCtrl:ChangeTab(1)
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildLogoPopup:OnShow()
    -- 更换图腾
    local pos = MyGuildManager.GetMyPositionInGuild()
    this.btnChange:SetActive(pos ~= GUILD_GRANT.MEMBER)

end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Img"):GetComponent("Image").sprite = Util.LoadSprite(_TabSprite[status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
end
-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    -- 设置显示
    this._CurIndex = index

    this.logoPanel:SetActive(index == 1)
    if index == 1 then
        this.RefreshLogoPanelShow()
    end
end

-- 刷新图腾信息显示
function this.RefreshLogoPanelShow()
    local guildData = MyGuildManager.GetMyGuildInfo()
    local fightResult = guildData.fightResult
    this.pingTxt.text = fightResult.draw
    this.winTxt.text = fightResult.win
    this.loseTxt.text = fightResult.fail

    local logoName = GuildManager.GetLogoResName(guildData.icon)
    this.guildLogo.sprite = Util.LoadSprite(logoName)

end



--界面关闭时调用（用于子类重写）
function GuildLogoPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildLogoPopup:OnDestroy()
end

return GuildLogoPopup