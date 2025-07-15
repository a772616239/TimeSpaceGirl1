require("Base/BasePanel")
GuildMemberPopup = Inherit(BasePanel)
local this = GuildMemberPopup

-- 头像管理
local _PlayerHeadList = {}

--初始化组件（用于子类重写）
function GuildMemberPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    this.memScrollRoot = Util.GetGameObject(self.gameObject, "content/members/scrollpos")
    this.memItem = Util.GetGameObject(self.gameObject, "content/members/scrollpos/mem")
    this.onlineNumText = Util.GetGameObject(self.gameObject, "content/members/title/status/num"):GetComponent("Text")

    --获取帮助按钮
    this.HelpBtn = Util.GetGameObject(self.gameObject,"content/members/title/HelpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition

    this.invite = Util.GetGameObject(self.gameObject, "content/ManageBtns/invite")
    this.ApplicationList = Util.GetGameObject(self.gameObject, "content/ManageBtns/ApplicationList")
    this.dimiss = Util.GetGameObject(self.gameObject, "content/ManageBtns/dimiss")
    this.dimissText = Util.GetGameObject(self.gameObject, "content/ManageBtns/dimiss/Text"):GetComponent("Text")
    this.dismissTime = Util.GetGameObject(self.gameObject, "content/ManageBtns/dimiss/dimissTime"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function GuildMemberPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.invite, function()
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10914)
            return
        end
        -- 请求发送给公会邀请
        ChatManager.RequestSendGuildInvite(function()
            PopupTipPanel.ShowTipByLanguageId(10915)
        end)
    end)
    Util.AddClick(this.ApplicationList, function()
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10917)
            return
        end      
        UIManager.OpenPanel(UIName.GuildApplyPopup,function()
            this.RefreshMembersShow()
        end)
    end)
    Util.AddClick(this.dimiss, function()
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos == GUILD_GRANT.MASTER then
            --> 解散
            local guildData = MyGuildManager.GetMyGuildInfo()
            if guildData.levelTime ~= 0 then
                MsgPanel.ShowTwo(GetLanguageStrById(10906),nil, function()
                    local pos = MyGuildManager.GetMyPositionInGuild()
                    if pos ~= GUILD_GRANT.MASTER then
                        PopupTipPanel.ShowTipByLanguageId(10907)
                        return
                    end
                    MyGuildManager.RequestDismissGuild(2)
                end)
            else
                -- 公会战期间无法执行此操作
                if GuildFightManager.IsInGuildFight() then
                    PopupTipPanel.ShowTipByLanguageId(10908)
                    return
                end
                MsgPanel.ShowTwo(GetLanguageStrById(10909),nil, function()
                    local pos = MyGuildManager.GetMyPositionInGuild()
                    if pos ~= GUILD_GRANT.MASTER then
                        PopupTipPanel.ShowTipByLanguageId(10910)
                        return
                    end
                    MyGuildManager.RequestDismissGuild(1)
                end)
            end
        else
            --> 退出
            -- 公会战期间无法执行此操作
            if GuildFightManager.IsInGuildFight() then
                PopupTipPanel.ShowTipByLanguageId(10908)
                return
            end
            MsgPanel.ShowTwo(GetLanguageStrById(10916),nil, function()
                MyGuildManager.RequestQuitGuild(function()
                    this:ClosePanel()
                end)
            end, GetLanguageStrById(10719), GetLanguageStrById(10720), GetLanguageStrById(11351), false, nil, true, 
            MyGuildManager.GetGuildExitCdTips())
        end
    end)
end

--添加事件监听（用于子类重写）
function GuildMemberPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.DataUpdate, this.RefreshUI)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.MemberDataUpdate, this.RefreshMembersShow)
end

--移除事件监听（用于子类重写）
function GuildMemberPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.DataUpdate, this.RefreshUI)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.MemberDataUpdate, this.RefreshMembersShow)
end

--界面打开时调用（用于子类重写）
function GuildMemberPopup:OnOpen()
    
end

function this.RefreshHelpBtn()
    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.GuildMember,this.helpPosition.x,this.helpPosition.y+800) 
    end)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildMemberPopup:OnShow()
    this.RefreshMembersShow()
    this.RefreshUI()

     this.RefreshHelpBtn()
end

-- 刷新公会解散时间显示
function this.RefreshDismissTime()
    local guildData = MyGuildManager.GetMyGuildInfo()
    if not guildData then return end
    local destroyTime = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).DestroyTime
    local leftTime = (guildData.levelTime + destroyTime) - GetTimeStamp()
    this.dismissTime.text = string.format(GetLanguageStrById(10920), TimeToHMS(leftTime))
end

function this.RefreshUI()
    -->
    local pos = MyGuildManager.GetMyPositionInGuild()
    Util.SetGray(this.invite, pos == GUILD_GRANT.MEMBER)
    Util.SetGray(this.ApplicationList, pos == GUILD_GRANT.MEMBER)

    this.dimissText.text = pos == GUILD_GRANT.MASTER and GetLanguageStrById(12537) or GetLanguageStrById(12536)
    
    this.dismissTime.gameObject:SetActive(false)
    if pos == GUILD_GRANT.MASTER then
        this.dimissText.text = GetLanguageStrById(12537)
        local guildData = MyGuildManager.GetMyGuildInfo()
        if guildData.levelTime == 0 then
            if this._TimeCounter then
                this._TimeCounter:Stop()
                this._TimeCounter = nil
            end
        else
            this.dimissText.text = GetLanguageStrById(10919)
            this.dismissTime.gameObject:SetActive(true)
            this.RefreshDismissTime()
            -- 开始吧
            if not this._TimeCounter then
                this._TimeCounter = Timer.New(this.RefreshDismissTime, 1, -1, true)
                this._TimeCounter:Start()
            end
        end
    end
end

-- 刷新公会成员显示
function this.RefreshMembersShow()
    -- 创建滚动
    if not this.memScrollView then
        local height = this.memScrollRoot.transform.rect.height
        local width = this.memScrollRoot.transform.rect.width
        this.memScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.memScrollRoot.transform,
                this.memItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0))
        this.memScrollView.moveTween.Strength = 2
    end
    -- 设置数据
    local members = MyGuildManager.GetMyGuildMemList()
    local itemList = {}
    this.memScrollView:SetData(members, function(index, go)
        this.MemItemAdapter(go, members[index])
        itemList[index] = go
    end)
    DelayCreation(itemList)
    -- 在线人数计算
    local onlineNum = 0
    for _, v in ipairs(members) do
        if v.seconds == 0 then
            onlineNum = onlineNum + 1
        end
    end
    this.onlineNumText.text = onlineNum
end

-- 成员信息节点数据匹配
function this.MemItemAdapter(item, data)
    local headpos = Util.GetGameObject(item, "head")
    local nameText = Util.GetGameObject(item, "name")
    local powerText = Util.GetGameObject(item, "power")
    local professText = Util.GetGameObject(item, "pos")
    local onlineText = Util.GetGameObject(item, "online")
    local offlineText = Util.GetGameObject(item, "offline")
    local GiveAll = Util.GetGameObject(item, "GiveAll"):GetComponent("Text")
    local GiveToday = Util.GetGameObject(item, "GiveToday"):GetComponent("Text")
    local GiveLevel = Util.GetGameObject(item, "GiveLevel"):GetComponent("Text")
    local Option = Util.GetGameObject(item, "Option")

    nameText:GetComponent("Text").text = data.userName
    professText:GetComponent("Text").text = GUILD_GRANT_STR[data.position]
    powerText:GetComponent("Text").text = data.soulForce

    GiveAll.text = data.contribute
    GiveToday.text = data.contributeToday
    GiveLevel.text = data.guildActiveLevel

    -- 头像
    if not _PlayerHeadList[item] then
        _PlayerHeadList[item] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    _PlayerHeadList[item]:Reset()
    _PlayerHeadList[item]:SetScale(Vector3.one * 0.55)
    _PlayerHeadList[item]:SetHead(data.head)
    _PlayerHeadList[item]:SetFrame(data.frame)
    _PlayerHeadList[item]:SetLevel(data.userLevel)

    if data.seconds == 0 then
        onlineText:SetActive(true)
        offlineText:SetActive(false)
    else
        onlineText:SetActive(false)
        offlineText:SetActive(true)
        offlineText:GetComponent("Text").text = GetDeltaTimeStrByDeltaTime(data.seconds)
    end

    -- 添加点击事件
    Util.AddOnceClick(item, function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup,data.roleUid)
    end)

    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos == GUILD_GRANT.MASTER and data.position ~= GUILD_GRANT.MASTER then
        Option:SetActive(true)
        Util.AddOnceClick(Option, function()
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.GuildMemSet, data.userName, data.roleUid)
        end)
    else
        Option:SetActive(false)
    end
    
end

--界面关闭时调用（用于子类重写）
function GuildMemberPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function GuildMemberPopup:OnDestroy()
    -- 头像回收
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}

    -- 销毁计时器
    if this._TimeCounter then
        this._TimeCounter:Stop()
        this._TimeCounter = nil
    end

    this.memScrollView = nil
end

return GuildMemberPopup