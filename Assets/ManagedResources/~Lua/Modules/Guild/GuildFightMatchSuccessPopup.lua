require("Base/BasePanel")
local GuildFightMatchSuccessPopup = Inherit(BasePanel)
local this = GuildFightMatchSuccessPopup
local orginLayer
--初始化组件（用于子类重写）
function GuildFightMatchSuccessPopup:InitComponent()
    orginLayer = 0
    this.mask = Util.GetGameObject(self.transform, "mask")
    this.fightPanel = Util.GetGameObject(self.transform, "fight")
    this.myGuild = Util.GetGameObject(this.fightPanel, "Left/Grade/my")
    this.enemyGuild = Util.GetGameObject(this.fightPanel, "Right/Grade/my")
    this.effect = Util.GetGameObject(this.fightPanel, "Effect")
    this.emptyPanel = Util.GetGameObject(self.transform, "empty")

end

--绑定事件（用于子类重写）
function GuildFightMatchSuccessPopup:BindEvent()
    Util.AddClick(this.mask, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function GuildFightMatchSuccessPopup:AddListener()
end

--移除事件监听（用于子类重写）
function GuildFightMatchSuccessPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GuildFightMatchSuccessPopup:OnOpen(showType)
    this.showType = showType
    this.fightPanel:SetActive(this.showType == 1)
    this.emptyPanel:SetActive(this.showType == 2)
    if this.showType == 1 then
        this.RefreshGuildShow()
    end
end

-- 刷新公会显示
function this.RefreshGuildShow()
    -- 敌方数据显示
    local enemyInfo = GuildFightManager.GetEnemyBaseData()
    this.GuildBaseInfoAdapter(this.enemyGuild, enemyInfo)
    -- 我方数据显示
    local myGuildData = GuildFightManager.GetMyBaseData()
    this.GuildBaseInfoAdapter(this.myGuild, myGuildData)
end

-- 公会基础数据匹配
function this.GuildBaseInfoAdapter(node, data)
    local nameText = Util.GetGameObject(node, "name"):GetComponent("Text")
    local levelText = Util.GetGameObject(node, "level"):GetComponent("Text")
    local levelbg = Util.GetGameObject(node, "lvbg")
    local logoSpr = Util.GetGameObject(node, "icon"):GetComponent("Image")
    local starText = Util.GetGameObject(node, "starNum"):GetComponent("Text")

    levelText.gameObject:SetActive(data ~= nil)
    levelbg.gameObject:SetActive(data ~= nil)
    if data then
        nameText.text = data.name
        levelText.text = data.level
        local logoName = GuildManager.GetLogoResName(data.pictureId)
        logoSpr.sprite = Util.LoadSprite(logoName)
        -- 星星数量显示
        starText.text = data.totalStar
    else
        nameText.text = "..."
        logoSpr.sprite = Util.LoadSprite("r_gonghui_pipeiwenhao")
    end
    logoSpr:SetNativeSize()
end


--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildFightMatchSuccessPopup:OnShow()
end

--
function GuildFightMatchSuccessPopup:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.effect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end
--界面关闭时调用（用于子类重写）
function GuildFightMatchSuccessPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildFightMatchSuccessPopup:OnDestroy()
end

return GuildFightMatchSuccessPopup