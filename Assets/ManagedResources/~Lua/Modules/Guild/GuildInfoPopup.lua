require("Base/BasePanel")
local GuildInfoPopup = Inherit(BasePanel)
local this = GuildInfoPopup
-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabFontColor = { default = Color.New(168 / 255, 168 / 255, 167 / 255, 1),
                        select = Color.New(250 / 255, 227 / 255, 175 / 255, 1) }
local _TabData = {
    [GUILD_GRANT.MASTER] = {
        [1] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10903) },
        [2] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10904) },
        [3] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10905), rpType = RedPointType.Guild_House_Apply },
    },
    [GUILD_GRANT.ADMIN] = {
        [1] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10903) },
        [2] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10904) },
        [3] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10905), rpType = RedPointType.Guild_House_Apply },
    },
    [GUILD_GRANT.MEMBER] = {
        [1] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10903) },
        [2] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10904) },
    },
}

-- 头像管理
local _PlayerHeadList = {}

--初始化组件（用于子类重写）
function GuildInfoPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.tabbox = Util.GetGameObject(self.transform, "top")
    this.title = Util.GetGameObject(self.transform, "Title"):GetComponent("Text")

    this.contentList = {}
    this.contentList[1] = Util.GetGameObject(self.transform, "content/info")
    this.contentList[2] = Util.GetGameObject(self.transform, "content/members")
    this.contentList[3] = Util.GetGameObject(self.transform, "content/verify")

    -- 基础信息展示
    this.guildName = Util.GetGameObject(this.contentList[1], "name/Text"):GetComponent("Text")
    this.guildLevel = Util.GetGameObject(this.contentList[1], "level/Text"):GetComponent("Text")
    this.guildMaster = Util.GetGameObject(this.contentList[1], "master/Text"):GetComponent("Text")
    this.expSlider = Util.GetGameObject(this.contentList[1], "level/Slider"):GetComponent("Slider")
    this.expText = Util.GetGameObject(this.contentList[1], "level/Slider/Text"):GetComponent("Text")
    this.guildMember = Util.GetGameObject(this.contentList[1], "member/Text"):GetComponent("Text")
    this.guildAnnounce = Util.GetGameObject(this.contentList[1], "declaration/Text"):GetComponent("Text")
    this.btnLog = Util.GetGameObject(this.contentList[1], "function/log")
    this.btnStore = Util.GetGameObject(this.contentList[1], "function/store")
    this.btnLogo = Util.GetGameObject(this.contentList[1], "function/logo")

    this.btnEditName = Util.GetGameObject(this.contentList[1], "name/bg")
    this.btnEditAnnounce = Util.GetGameObject(this.contentList[1], "declaration/bg")

    this.guildCharge = Util.GetGameObject(this.contentList[1], "option")
    this.btnDismiss = Util.GetGameObject(this.contentList[1], "option/box/dimiss")
    this.dismissStr = Util.GetGameObject(this.btnDismiss, "Text"):GetComponent("Text")
    this.dismissTime = Util.GetGameObject(this.btnDismiss, "time"):GetComponent("Text")
    this.btnSetting = Util.GetGameObject(this.contentList[1], "option/box/setting")
    this.btnInvite = Util.GetGameObject(this.contentList[1], "option/box/invite")

    -- 成员
    this.memScrollRoot = Util.GetGameObject(this.contentList[2], "scrollpos")
    this.memItem = Util.GetGameObject(this.contentList[2], "scrollpos/mem")
    this.onlineNumText = Util.GetGameObject(this.contentList[2], "title/status/num"):GetComponent("Text")
    this.btnQuit = Util.GetGameObject(this.contentList[2], "quit")

    -- 审核信息
    this.btnBg = Util.GetGameObject(this.contentList[3], "btnbg")
    this.verifyClearBtn = Util.GetGameObject(this.contentList[3], "btnbg/clear")
    this.verifyAgreeBtn = Util.GetGameObject(this.contentList[3], "btnbg/agree")
    this.verifyScrollRoot = Util.GetGameObject(this.contentList[3], "scrollpos")
    this.verifyItem = Util.GetGameObject(this.contentList[3], "scrollpos/verify")
    this.empty = Util.GetGameObject(this.contentList[3], "empty")
    this.agreeRedpot = Util.GetGameObject(this.contentList[3], "btnbg/agree/redpot")
    -- 公会日志
    this.logPanel = Util.GetGameObject(self.transform, "log")
    this.logScrollRoot = Util.GetGameObject(this.logPanel, "bg/scrollpos")
    this.logItem = Util.GetGameObject(this.logPanel, "bg/scrollpos/log")


end

--绑定事件（用于子类重写）
function GuildInfoPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    -- 公会日志
    Util.AddClick(this.btnLog, function()
        this.logPanel:SetActive(true)
        this.RefreshLogShow()
    end)
    Util.AddClick(this.logPanel, function()
        this.logPanel:SetActive(false)
    end)
    -- 跳转公会商店
    Util.AddClick(this.btnStore, function()
        UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.GUILD_SHOP)
    end)
    -- 公会图腾
    Util.AddClick(this.btnLogo, function()
        UIManager.OpenPanel(UIName.GuildLogoPopup)
    end)

    -- 基础操作
    Util.AddClick(this.btnDismiss, function()
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
    end)
    Util.AddClick(this.btnSetting, function()
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10911)
            return
        end
        UIManager.OpenPanel(UIName.GuildChangePopup, GUILD_CHANGE_TYPE.SETTING)
    end)
    Util.AddClick(this.btnEditName, function()
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10912)
            return
        end
        UIManager.OpenPanel(UIName.GuildChangePopup, GUILD_CHANGE_TYPE.NAME)
    end)
    Util.AddClick(this.btnEditAnnounce, function()
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10913)
            return
        end
        UIManager.OpenPanel(UIName.GuildChangePopup, GUILD_CHANGE_TYPE.ANNOUNCE)
    end)
    Util.AddClick(this.btnInvite, function()
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
    Util.AddClick(this.btnQuit, function()
        -- 公会战期间无法执行此操作
        if GuildFightManager.IsInGuildFight() then
            PopupTipPanel.ShowTipByLanguageId(10908)
            return
        end
        MsgPanel.ShowTwo(GetLanguageStrById(10916),nil, function()
            MyGuildManager.RequestQuitGuild(function()
                this:ClosePanel()
            end)
        end)
    end)

    -- 申请操作
    Util.AddClick(this.verifyClearBtn, function()
        -- 判断是否有权限
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10917)
            return
        end
        MyGuildManager.OperateApply(GUILD_APPLY_OPTYPE.ALL_REFUSE)

    end)
    Util.AddClick(this.verifyAgreeBtn, function()
        -- 判断是否有权限
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10917)
            return
        end
        MyGuildManager.OperateApply(GUILD_APPLY_OPTYPE.ALL_AGREE)
    end)


    -- 初始化Tab管理器
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
end

--添加事件监听（用于子类重写）
function GuildInfoPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.DataUpdate, this.RefreshBaseInfoShow)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.DataUpdate, this.RefreshMembersShow)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.ApplyDataUpdate, this.RefreshVerifyShow)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.MemberDataUpdate, this.RefreshMembersShow)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.BeKickOut, this.CloseSelf)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.PositionUpdate, this.RefreshShow)

end

--移除事件监听（用于子类重写）
function GuildInfoPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.DataUpdate, this.RefreshBaseInfoShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.DataUpdate, this.RefreshMembersShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.ApplyDataUpdate, this.RefreshVerifyShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.MemberDataUpdate, this.RefreshMembersShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.BeKickOut, this.CloseSelf)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.PositionUpdate, this.RefreshShow)

end

--界面打开时调用（用于子类重写）
function GuildInfoPopup:OnOpen(...)
    this.RefreshShow()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildInfoPopup:OnShow()
end

-- 我的职位变更回调
function this.RefreshShow()
    this.ClearRedpot()
    local pos = MyGuildManager.GetMyPositionInGuild()
    this.TabCtrl:Init(this.tabbox, _TabData[pos])
end

-- 关闭界面
function this.CloseSelf()
    this:ClosePanel()
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local pos = MyGuildManager.GetMyPositionInGuild()
    local tabLab = Util.GetGameObject(tab, "Text")
    local redpot = Util.GetGameObject(tab, "redpot")
    Util.GetGameObject(tab,"Img"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[pos][index][status])
    tabLab:GetComponent("Text").text = _TabData[pos][index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]

    -- 判断是否需要检测红点
    redpot:SetActive(false)
    if status ~= "lock" then
        this.ClearRedpot(index)
        this.BindRedpot(index, redpot)
    end
end
-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    -- 设置显示
    for i = 1, 3 do
        this.contentList[i]:SetActive(i == index)
    end

    this._CurIndex = index
    if index == 1 then
        this.RefreshBaseInfoShow()
        NetManager.RequestMyGuildInfo()
    elseif index == 2 then
        this.RefreshMembersShow()
        MyGuildManager.RequestMyGuildMembers()
    elseif index == 3 then
        this.RefreshVerifyShow()
        MyGuildManager.RequestMyGuildApplyList()
    end

    local pos = MyGuildManager.GetMyPositionInGuild()
    this.title.text = _TabData[pos][this._CurIndex].name
end

-- 绑定数据
local _RedBindData = {}
function this.BindRedpot(index, redpot)
    local pos = MyGuildManager.GetMyPositionInGuild()
    local rpType = _TabData[pos][index].rpType
    if not rpType then return end
    BindRedPointObject(rpType, redpot)
    _RedBindData[rpType] = redpot
    this.agreeRedpot:SetActive(redpot.activeSelf)
end
function this.ClearRedpot(index)
    -- 清除红点绑定
    if index then    -- 清除某个
        local pos = MyGuildManager.GetMyPositionInGuild()
        local rpType = _TabData[pos][index].rpType
        if not rpType then return end
        ClearRedPointObject(rpType, _RedBindData[rpType])
        _RedBindData[rpType] = nil
    else    -- 全部清除
        for rpt, redpot in pairs(_RedBindData) do
            ClearRedPointObject(rpt, redpot)
        end
        _RedBindData = {}
    end
end



-- 刷新公会基础信息显示
function this.RefreshBaseInfoShow()
    if this._CurIndex ~= 1 then return end
    local guildData = MyGuildManager.GetMyGuildInfo()
    local curGuildlv = guildData.levle
    local curGuildLevelInfo = ConfigManager.GetConfigData(ConfigName.GuildLevelConfig, curGuildlv)
    local masterInfo = MyGuildManager.GetMyGuildMasterInfo()

    this.guildName.text = guildData.name
    this.guildAnnounce.text = guildData.annouce
    this.guildLevel.text = curGuildlv
    this.guildMaster.text = masterInfo.userName
    this.guildMember.text = string.format("（%s/%s）", guildData.totalNum, curGuildLevelInfo.Num)
    this.expText.text = string.format("%s/%s", guildData.exp, curGuildLevelInfo.Exp)
    this.expSlider.value = guildData.exp/curGuildLevelInfo.Exp

    local pos = MyGuildManager.GetMyPositionInGuild()
    this.guildCharge:SetActive(pos ~= GUILD_GRANT.MEMBER)
    this.btnDismiss:SetActive(pos == GUILD_GRANT.MASTER)

    this.dismissStr.text = GetLanguageStrById(10918)
    this.dismissTime.gameObject:SetActive(false)
    if pos == GUILD_GRANT.MASTER then
        if guildData.levelTime == 0 then
            if this._TimeCounter then
                this._TimeCounter:Stop()
                this._TimeCounter = nil
            end
        else
            this.dismissStr.text = GetLanguageStrById(10919)
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

-- 刷新公会解散时间显示
function this.RefreshDismissTime()
    local guildData = MyGuildManager.GetMyGuildInfo()
    if not guildData then return end
    local destroyTime = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).DestroyTime
    local leftTime = (guildData.levelTime + destroyTime) - GetTimeStamp()
    this.dismissTime.text = string.format(GetLanguageStrById(10920), TimeToHMS(leftTime))
end

-- 刷新公会成员显示
function this.RefreshMembersShow()
    if this._CurIndex ~= 2 then return end
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
    this.memScrollView:SetData(members, function(index, go)
        this.MemItemAdapter(go, members[index])
    end)
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
    local bg = Util.GetGameObject(item, "bg")
    local headpos = Util.GetGameObject(item, "head")
    local nameText = Util.GetGameObject(item, "name")
    local powerText = Util.GetGameObject(item, "power")
    local professText = Util.GetGameObject(item, "pos")
    local onlineText = Util.GetGameObject(item, "online")
    local offlineText = Util.GetGameObject(item, "offline")
    local GiveTodayTxt = Util.GetGameObject(item, "GiveToday")
    local GiveAllTxt = Util.GetGameObject(item, "GiveAll")

    nameText:GetComponent("Text").text = data.userName
    professText:GetComponent("Text").text = GUILD_GRANT_STR[data.position]
    powerText:GetComponent("Text").text = data.soulForce

    GiveTodayTxt:GetComponent("Text").text = data.contributeToday
    GiveAllTxt:GetComponent("Text").text = data.contribute

    -- 头像
    if not _PlayerHeadList[item] then
        _PlayerHeadList[item] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    _PlayerHeadList[item]:Reset()
    -- _PlayerHeadList[item]:SetScale(Vector3.one * 0.65)

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
    Util.AddOnceClick(bg, function()
        UIManager.OpenPanel(UIName.GuildMemberInfoPopup, GUILD_MEM_POPUP_TYPE.INFORMATION, data.roleUid)
    end)
end

-- 刷新申请信息
function this.RefreshVerifyShow()
    if this._CurIndex ~= 3 then return end
    --
    local pos = MyGuildManager.GetMyPositionInGuild()
    local isAdmin = pos == GUILD_GRANT.MASTER or pos == GUILD_GRANT.ADMIN
    this.btnBg:SetActive(isAdmin)
    -- 创建滚动
    if not this.verifyScrollView then
        local width = this.verifyScrollRoot.transform.rect.width
        local height = isAdmin and this.verifyScrollRoot.transform.rect.height or this.verifyScrollRoot.transform.rect.height + this.btnBg.transform.rect.height
        this.verifyScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.verifyScrollRoot.transform,
                this.verifyItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0))
        this.verifyScrollView.transform.anchoredPosition = Vector2.New(0, 0)
        this.verifyScrollView.transform.anchorMin = Vector2.New(0.5, 1)
        this.verifyScrollView.transform.anchorMax = Vector2.New(0.5, 1)
        this.verifyScrollView.transform.pivot = Vector2.New(0.5, 1)
        this.verifyScrollView.moveTween.Strength = 2
    end
    -- 获取数据
    local verifies = MyGuildManager.GetMyGuildApplyList()
    this.verifyScrollView:SetData(verifies, function(index, go)
        this.VerifyItemAdapter(go, verifies[index])
    end)
    -- 判断空数据显示
    this.empty:SetActive(#verifies == 0)
end
-- 成员信息节点数据匹配
function this.VerifyItemAdapter(item, data)
    local headpos = Util.GetGameObject(item, "head")
    local nameText = Util.GetGameObject(item, "name")
    local powerText = Util.GetGameObject(item, "power")
    local btnRefuse = Util.GetGameObject(item, "btnRefuse")
    local btnAgree = Util.GetGameObject(item, "btnAgree")
    nameText:GetComponent("Text").text = data.name
    powerText:GetComponent("Text").text = data.foreces
    -- 头像
    if not _PlayerHeadList[item] then
        _PlayerHeadList[item] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    _PlayerHeadList[item]:Reset()
    _PlayerHeadList[item]:SetScale(Vector3.one * 0.8)
    _PlayerHeadList[item]:SetHead(data.head)
    _PlayerHeadList[item]:SetFrame(data.frame)
    _PlayerHeadList[item]:SetLevel(data.level)

    local pos = MyGuildManager.GetMyPositionInGuild()
    local isAdmin = pos == GUILD_GRANT.MASTER or pos == GUILD_GRANT.ADMIN
    btnRefuse:SetActive(isAdmin)
    btnAgree:SetActive(isAdmin)
    Util.AddOnceClick(btnRefuse, function()
        -- 判断是否有权限
        if not isAdmin then
            PopupTipPanel.ShowTipByLanguageId(10917)
            return
        end
        MyGuildManager.OperateApply(GUILD_APPLY_OPTYPE.ONE_REFUSE, data.roleUid)
    end)
    Util.AddOnceClick(btnAgree, function()
        -- 判断是否有权限
        if not isAdmin then
            PopupTipPanel.ShowTipByLanguageId(10917)
            return
        end
        MyGuildManager.OperateApply(GUILD_APPLY_OPTYPE.ONE_AGREE, data.roleUid)
    end)
end


-- 刷新公会日志
function this.RefreshLogShow()
    MyGuildManager.RequestMyGuildLog(function()
        if not this.logScrollView then
            local height = this.logScrollRoot.transform.rect.height
            local width = this.logScrollRoot.transform.rect.width
            this.logScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.logScrollRoot.transform,
                    this.logItem, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0))
            this.logScrollView.moveTween.Strength = 2
        end
        -- 设置数据
        local logs = MyGuildManager.GetMyGuildLog()
        this.logScrollView:SetData(logs, function(index, go)
            this.LogItemAdapter(go, logs[index])
        end)
        local len = #logs
        if len >= 10 then
            this.logScrollView:SetIndex(len)
        end
    end)
end
-- 成员信息节点数据匹配
function this.LogItemAdapter(item, data)
    local nameText = Util.GetGameObject(item, "name")
    local statusText = Util.GetGameObject(item, "state")
    nameText:GetComponent("Text").text = data.info
    statusText:GetComponent("Text").text = GetDeltaTimeStr(data.time)
end

--界面关闭时调用（用于子类重写）
function GuildInfoPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildInfoPopup:OnDestroy()
    this.memScrollView = nil
    this.verifyScrollView = nil
    this.logScrollView = nil

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

    -- 清除红点
    this.ClearRedpot()
end

return GuildInfoPopup