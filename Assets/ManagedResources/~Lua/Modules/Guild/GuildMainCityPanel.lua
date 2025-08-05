require("Base/BasePanel")

local _GuildBuildConfig = {
    [GUILD_MAP_BUILD_TYPE.HOUSE] = {
        isOpen = true,
        rpType = RedPointType.Guild_House,
        btnName = "btnHouse",
        btnFunc = function()
            UIManager.OpenPanel(UIName.GuildInfoPopup)
        end,
    },
    [GUILD_MAP_BUILD_TYPE.STORE] = {
        isOpen = true,
        rpType = RedPointType.Guild_Shop,
        btnName = "btnShop",
        btnFunc = function()
            local isActive = ShopManager.IsActive(SHOP_TYPE.GUILD_SHOP)
            if not isActive then
                PopupTipPanel.ShowTipByLanguageId(10924)
                return
            end
            UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.GUILD_SHOP)
        end,
    },
    [GUILD_MAP_BUILD_TYPE.FETE] = { --捐献
        isOpen = true,
        rpType = RedPointType.Guild_Fete,
        btnName = "btnFete",
        btnFunc = function ()
            UIManager.OpenPanel(UIName.GuildFetePopup)
        end,
    },
    [GUILD_MAP_BUILD_TYPE.TENPOS] = { --公会战
        isOpen = true,
        rpType = RedPointType.GuildBattle,
        btnName = "btnTenPos",
        btnFunc = function()
            GuildBattleManager.InitData(function ()
                UIManager.OpenPanel(UIName.GuildBattlePanel)
            end)
        end,
    },
    [GUILD_MAP_BUILD_TYPE.SKILL] = { --技能
        isOpen = true,
        rpType = RedPointType.Guild_Skill,
        btnName = "btnSkill",
        btnFunc = function()
            UIManager.OpenPanel(UIName.GuildSkillUpLvPopup)
        end,
    },
    [GUILD_MAP_BUILD_TYPE.ACTIVE] = { --联盟活跃
        isOpen = true,
        rpType = RedPointType.Guild_Active,
        btnName = "btnAction",
        btnFunc = function()
            NetManager.RequestMyGuildInfo(function()
                UIManager.OpenPanel(UIName.GuildActivePointPopup)
            end)
        end,
    },
    [GUILD_MAP_BUILD_TYPE.MEMBER] = { --联盟成员
        isOpen = true,
        rpType = RedPointType.Guild_Member,
        btnName = "btnMumber",
        btnFunc = function()
            MyGuildManager.RequestMyGuildMembers(function()
                MyGuildManager.RequestMyGuildApplyList()
                UIManager.OpenPanel(UIName.GuildMemberPopup)
            end)
        end,
    },
    [GUILD_MAP_BUILD_TYPE.REDBAG] = { --联盟红包
        isOpen = true,
        rpType = RedPointType.Guild_RedPacket,
        btnName = "btnRedBag",
        btnFunc = function()
            JumpManager.GoJump(77007)
        end,
    },
    [GUILD_MAP_BUILD_TYPE.TRANSCRIPT] = { --联盟副本
        isOpen = true,
        rpType = RedPointType.Guild_Transcript,
        btnName = "btntranscript",
        btnFunc = function()
            UIManager.OpenPanel(UIName.GuildTranscriptMainPopup)
        end,
    },
}
local GuildMainCityPanel = Inherit(BasePanel)
local this = GuildMainCityPanel

local _StageNameIcon = {
    [GUILD_FIGHT_STAGE.DEFEND] = {"r_gonghui_bufangjieduan"},
    [GUILD_FIGHT_STAGE.MATCHING] = {"r_gonghui_pipeijieduan"},
    [GUILD_FIGHT_STAGE.ATTACK] = {"r_gonghui_jingongjieduan"},
    [GUILD_FIGHT_STAGE.COUNTING] = {"r_gonghui_jiesuanjieduan", "r_gonghui_jiesuanwancheng"},
    [GUILD_FIGHT_STAGE.EMPTEY] = {"r_gonghui_bencilunkong"},
}

--初始化组件（用于子类重写）
function GuildMainCityPanel:InitComponent()
    self.HeadFrameView =SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)

    this.btnList = {}
    this.ChangeNameBtn =  Util.GetGameObject(self.gameObject, "Panel/NameAndExp/ChangeNameBtn")
    this.GuildRank =  Util.GetGameObject(self.gameObject, "Panel/info/GuildRank")
    this.btnRedBag =  Util.GetGameObject(self.gameObject, "Panel/leftBtn/btnRedBag")
    this.btnShop =  Util.GetGameObject(self.gameObject, "Panel/leftBtn/btnShop")
    this.InviteBtn =  Util.GetGameObject(self.gameObject, "Panel/rightBtn/InviteBtn")
    this.GuildLogBtn =  Util.GetGameObject(self.gameObject, "Panel/rightBtn/GuildLogBtn")
    this.btnMumber =  Util.GetGameObject(self.gameObject, "Panel/rightBtn/btnMumber")
    this.RequirementBtn =  Util.GetGameObject(self.gameObject, "Panel/rightBtn/RequirementBtn")
    this.ChangeDeclarationBtn =  Util.GetGameObject(self.gameObject, "Panel/declaration/ChangeDeclarationBtn")
    this.btnFete =  Util.GetGameObject(self.gameObject, "Panel/downBtn/btnFete")
    this.btnAction =  Util.GetGameObject(self.gameObject, "Panel/downBtn/btnAction")
    this.btnTenPos =  Util.GetGameObject(self.gameObject, "Panel/downBtn/btnTenPos")
    this.btntranscript =  Util.GetGameObject(self.gameObject, "Panel/downBtn/btntranscript")
    this.btnSkill =  Util.GetGameObject(self.gameObject, "Panel/downBtn/btnSkill")
    table.insert(this.btnList,this.ChangeNameBtn)
    table.insert(this.btnList,this.GuildRank)
    table.insert(this.btnList,this.btnRedBag)
    table.insert(this.btnList,this.btnShop)
    table.insert(this.btnList,this.InviteBtn)
    table.insert(this.btnList,this.GuildLogBtn)
    table.insert(this.btnList,this.btnMumber)
    table.insert(this.btnList,this.RequirementBtn)
    table.insert(this.btnList,this.ChangeDeclarationBtn)
    table.insert(this.btnList,this.btnFete)
    table.insert(this.btnList,this.btnAction)
    table.insert(this.btnList,this.btnTenPos)
    table.insert(this.btnList,this.btntranscript)
    table.insert(this.btnList,this.btnSkill)

    for type, data in pairs(_GuildBuildConfig) do
        if data.btnName then
            local btn
            for index, value in ipairs(this.btnList) do
                if value.gameObject.name == data.btnName then
                    btn = value
                end
            end

            if btn then
                btn:SetActive(data.isOpen)
                if data.isOpen then
                    if data.btnFunc then
                        Util.AddOnceClick(btn, data.btnFunc)
                    end
                    if data.rpType then
                        BindRedPointObject(data.rpType, Util.GetGameObject(btn, "redpot"))
                    end
                end
            end
        end
    end

    --
    this.NameAndExp = Util.GetGameObject(self.gameObject, "Panel/NameAndExp")
    this.ChangeNameBtn = Util.GetGameObject(this.NameAndExp, "ChangeNameBtn")
    this.GuildName = Util.GetGameObject(this.NameAndExp, "name"):GetComponent("Text")
    this.GuildLv = Util.GetGameObject(this.NameAndExp, "level/lv"):GetComponent("Text")
    this.GuildExp = Util.GetGameObject(this.NameAndExp, "level/Exp"):GetComponent("Text")
    this.GuildSlider = Util.GetGameObject(this.NameAndExp, "Slider"):GetComponent("Slider")

    this.info = Util.GetGameObject(self.gameObject, "Panel/info")
    this.GuildRank = Util.GetGameObject(this.info, "GuildRank")--排名
    this.GuildMasterName = Util.GetGameObject(this.info, "master/Text"):GetComponent("Text")--会长
    this.GuildMember = Util.GetGameObject(this.info, "member/Text"):GetComponent("Text")--成员

    this.rightBtn = Util.GetGameObject(self.gameObject, "Panel/rightBtn")
    this.InviteBtn = Util.GetGameObject(this.rightBtn, "InviteBtn")--发消息
    this.GuildLogBtn = Util.GetGameObject(this.rightBtn, "GuildLogBtn")--日志
    this.RequirementBtn = Util.GetGameObject(this.rightBtn, "RequirementBtn")--入团设置

    --军团宣言
    this.GuildAnnounce = Util.GetGameObject(self.gameObject, "Panel/declaration/Text"):GetComponent("Text")
    this.ChangeDeclarationBtn = Util.GetGameObject(self.gameObject, "Panel/declaration/ChangeDeclarationBtn")
end

--绑定事件（用于子类重写）
function GuildMainCityPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)

    -- 绑定红点
    BindRedPointObject(RedPointType.Guild_RedPacket, this.btnRedPacketRedPoint)

    -- 联盟名字修改
    Util.AddClick(this.ChangeNameBtn,function()
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10912)
            return
        end
        UIManager.OpenPanel(UIName.GuildChangePopup, GUILD_CHANGE_TYPE.NAME)
    end)
    -- 联盟宣言修改
    Util.AddClick(this.ChangeDeclarationBtn,function()
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10913)
            return
        end
        UIManager.OpenPanel(UIName.GuildChangePopup, GUILD_CHANGE_TYPE.ANNOUNCE)
    end)
    -- 联盟日志
    Util.AddClick(this.GuildLogBtn,function()
        UIManager.OpenPanel(UIName.GuildLogPopup)
    end)
    -- 发布信息
    Util.AddClick(this.InviteBtn,function()
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
    -- 入盟设置
    Util.AddClick(this.RequirementBtn,function()
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
            PopupTipPanel.ShowTipByLanguageId(10911)
            return
        end
        UIManager.OpenPanel(UIName.GuildChangePopup, GUILD_CHANGE_TYPE.SETTING)
    end)
    -- 联盟排名
    Util.AddClick(this.GuildRank,function()
        UIManager.OpenPanel(UIName.RankingSingleListPanel,RankKingList[9])
    end)
end

--添加事件监听（用于子类重写）
function GuildMainCityPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.OnQuitGuild, this.OnQuitGuild)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.BeKickOut, this.OnQuitGuild)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.DismissStatusChanged, this.RefreshStageShow)
    Game.GlobalEvent:AddEvent(GameEvent.GuildFight.FightBaseDataUpdate, this.RefreshStageShow)
    Game.GlobalEvent:AddEvent(GameEvent.GuildFight.EnemyBaseDataUpdate, this.RefreshGuildInfo)
    Game.GlobalEvent:AddEvent(GameEvent.GuildFight.ResultDataUpdate, this.RefreshGuildInfo)
    Game.GlobalEvent:AddEvent(GameEvent.GuildFight.AttackStageDefendDataUpdate, this.RefreshGetStar)
    Game.GlobalEvent:AddEvent(GameEvent.GuildRedPacket.OnCloseRedPointClick, this.CloseRedPointClick)
    -- Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshDeathPosStatus, this.RefreshDeathPos)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.DataUpdate, this.RefreshGuildInfo)
end

--移除事件监听（用于子类重写）
function GuildMainCityPanel:RemoveListener()
    -- ctrlView.RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.OnQuitGuild, this.OnQuitGuild)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.BeKickOut, this.OnQuitGuild)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.DismissStatusChanged, this.RefreshStageShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildFight.FightBaseDataUpdate, this.RefreshStageShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildFight.EnemyBaseDataUpdate, this.RefreshGuildInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildFight.ResultDataUpdate, this.RefreshGuildInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildFight.AttackStageDefendDataUpdate, this.RefreshGetStar)
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildRedPacket.OnCloseRedPointClick, this.CloseRedPointClick)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshDeathPosStatus, this.RefreshDeathPos)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.DataUpdate, this.RefreshGuildInfo)
end

--界面打开时调用（用于子类重写）
function GuildMainCityPanel:OnOpen(...)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildMainCityPanel:OnShow()
    self.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Guild })
    this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.GongHui })
    CheckRedPointStatus(RedPointType.Guild_RedPacket)
    CheckRedPointStatus(RedPointType.Guild_Fete)
    CheckRedPointStatus(RedPointType.Guild_AidBox)
    CheckRedPointStatus(RedPointType.Guild_AidGuild)
    CheckRedPointStatus(RedPointType.Guild_AidMy)
    CheckRedPointStatus(RedPointType.GuildBattle_BoxReward)
    CheckRedPointStatus(RedPointType.GuildBattle_FreeTime)
    CheckRedPointStatus(RedPointType.GuildBattle)
    if not PlayerManager.familyId or PlayerManager.familyId == 0 then
        this:ClosePanel()
        return
    end
    -- 刷新一遍公会数据，这里主要是为了刷新玩家位置信息，避免返回地图界面出现的问题
    NetManager.RequestMyGuildInfo()
    -- 刷新公会战阶段信息
    this.RefreshStageShow()
    -- 开始定时刷新聊天数据
    -- this.ChatTipView:StartCheck()
    -- 刷新十绝阵是否开启
    -- this.RefreshDeathPos()
    -- 开始吧
    this._TimeUpdate()
    if not this._TimeCounter then
        this._TimeCounter = Timer.New(this._TimeUpdate, 1, -1, true)
        this._TimeCounter:Start()
    end
    -- this.FreshPlayerInfo()
    -- this.SetPlayerHead()

    if not RECHARGEABLE then--（是否开启充值）
        -- this.btnRedPacket:SetActive(false)
    end

    local pos = MyGuildManager.GetMyPositionInGuild()
    local isHighPos = pos == GUILD_GRANT.MASTER or pos == GUILD_GRANT.ADMIN
    this.RequirementBtn:SetActive(isHighPos)
    this.InviteBtn:SetActive(isHighPos)
    this.ChangeDeclarationBtn:SetActive(isHighPos)
    this.ChangeNameBtn:SetActive(isHighPos)
    this.RefreshGuildInfo()
    MyGuildManager.RequestMyGuildApplyList()
    SoundManager.PlaySound(SoundConfig.Sound_n1_ui_sound_campwar_detect)

end

function this.RefreshStageShow()
    local curStage = GuildFightManager.GetCurFightStage()

    -- 按钮显示，及特殊阶段处理
    if curStage == GUILD_FIGHT_STAGE.UN_START then
    elseif curStage == GUILD_FIGHT_STAGE.DEFEND then
        -- this.btnCheckDefend:SetActive(true)
    elseif curStage == GUILD_FIGHT_STAGE.MATCHING then
    elseif curStage == GUILD_FIGHT_STAGE.ATTACK then
        -- this.btnAttack:SetActive(true)
        -- this.btnAttackLog:SetActive(true)
    elseif curStage == GUILD_FIGHT_STAGE.COUNTING then
        -- this.btnResult:SetActive(true)
        local result = GuildFightManager.GetGuildFightResultData()
        -- 显示结算完成
        if result and _StageNameIcon[curStage] then
            -- this.stageName.sprite = Util.LoadSprite(_StageNameIcon[curStage][2])
        end
    elseif curStage == GUILD_FIGHT_STAGE.EMPTEY then
    end

    -- 刷新展示信息
    this.RefreshGuildInfo()
end

-- 公会基础数据匹配
function this.GuildBaseInfoAdapter(node, data)
    local nameText = Util.GetGameObject(node, "name"):GetComponent("Text")
    local levelText = Util.GetGameObject(node, "level"):GetComponent("Text")
    local levelbg = Util.GetGameObject(node, "lvbg")
    local logoSpr = Util.GetGameObject(node, "icon"):GetComponent("Image")

    levelText.gameObject:SetActive(data ~= nil)
    levelbg.gameObject:SetActive(data ~= nil)
    if data then
        nameText.text = data.name
        levelText.text = data.level
        local logoName = GuildManager.GetLogoResName(data.pictureId)
        logoSpr.sprite = Util.LoadSprite(logoName)
    else
        nameText.text = "..."
        logoSpr.sprite = Util.LoadSprite("r_gonghui_pipeiwenhao")
    end
end

-- 刷新获取星数的显示
function this.RefreshGetStar()
    this.myStar.gameObject:SetActive(false)
    this.enemyStar.gameObject:SetActive(false)
    local curStage = GuildFightManager.GetCurFightStage()
    if curStage == GUILD_FIGHT_STAGE.ATTACK or curStage == GUILD_FIGHT_STAGE.COUNTING then
        this.myStar.gameObject:SetActive(true)
        this.enemyStar.gameObject:SetActive(true)
        local myGetStar, enemyGetStar = GuildFightManager.GetBothGetStarNum()
        this.myStar.text = myGetStar
        this.enemyStar.text = enemyGetStar
    end
end

-- 计时显示
local _BGMFlag = nil
function this._TimeUpdate()
    local curStage = GuildFightManager.GetCurFightStage()
    if curStage == GUILD_FIGHT_STAGE.DISSMISS or curStage == GUILD_FIGHT_STAGE.CLOSE then
        if not _BGMFlag or _BGMFlag == 1 then
            _BGMFlag = 0
            SoundManager.PlayMusic(SoundConfig.BGM_Guild)
        end
        return
    end

    local guildFightData = GuildFightManager.GetGuildFightData()
    local startTime = guildFightData.startTime
    local curTime = GetTimeStamp()

    if guildFightData.type == GUILD_FIGHT_STAGE.UN_START and curTime < startTime then
        local leftTime = startTime - curTime
        leftTime = leftTime < 0 and 0 or leftTime
        -- this.stageTime.text = string.format(GetLanguageStrById(10929), TimeToHMS(leftTime))

        if not _BGMFlag or _BGMFlag == 1 then
            _BGMFlag = 0
            SoundManager.PlayMusic(SoundConfig.BGM_Guild)
        end
    else
        local roundEndTime = guildFightData.roundEndTime
        local leftTime = roundEndTime - curTime
        leftTime = leftTime < 0 and 0 or leftTime
        -- this.stageTime.text = string.format(GetLanguageStrById(10930), TimeToHMS(leftTime))

        if not _BGMFlag or _BGMFlag == 0 then
            _BGMFlag = 1
            SoundManager.PlayMusic(SoundConfig.BGM_GuildFight)
        end
    end
end

-- 退出公会回调事件
function this.OnQuitGuild()
    this:ClosePanel()
end

--- 检测当前阶段是否需要显示阶段提示界面
function this.CheckStageTip()
    -- 获取当前公会战阶段
    local isInFight = GuildFightManager.IsInGuildFight()
    if not isInFight then return end
    local curStage = GuildFightManager.GetCurFightStage()
    local curTipStage = GuildFightManager.GetCurTipStage()
    -- 轮空状态特殊处理
    if curStage == GUILD_FIGHT_STAGE.EMPTEY and curTipStage ~= GUILD_FIGHT_STAGE.EMPTEY then
        GuildFightManager.SetCurTipStage(GUILD_FIGHT_STAGE.EMPTEY)
        if UIManager.IsOpen(UIName.GuildFightMatchingPopup) then
            UIManager.ClosePanel(UIName.GuildFightMatchingPopup)
        end
        -- 显示轮空提示
        UIManager.OpenPanel(UIName.GuildFightMatchSuccessPopup, 2)
        return
    elseif curStage == GUILD_FIGHT_STAGE.MATCHING then
        local enemyInfo = GuildFightManager.GetEnemyBaseData()
        if not enemyInfo then
            if not curTipStage or curTipStage < curStage - 0.5 then
                -- 这里匹配阶段但是未匹配成功的阶段用  匹配阶段减0.5代替  以符合提示显示的规则
                -- 阶段设计问题，应该将匹配阶段分开为两个阶段
                GuildFightManager.SetCurTipStage(curStage - 0.5)
                if UIManager.IsOpen(UIName.GuildFightDefendInfoPopup) then
                    UIManager.ClosePanel(UIName.GuildFightDefendInfoPopup)
                end
                UIManager.OpenPanel(UIName.GuildFightMatchingPopup)
            end
        else
            if not curTipStage or curTipStage < curStage then
                -- 匹配成功的阶段，显示匹配结果
                GuildFightManager.SetCurTipStage(curStage)
                if UIManager.IsOpen(UIName.GuildFightMatchingPopup) then
                    UIManager.ClosePanel(UIName.GuildFightMatchingPopup)
                end
                UIManager.OpenPanel(UIName.GuildFightMatchSuccessPopup, 1)
            end
        end
        return
    end

    if not curTipStage or curTipStage < curStage then
        GuildFightManager.SetCurTipStage(curStage)
        -- 根据不同的阶段显示不同的界面
        if curStage == GUILD_FIGHT_STAGE.DEFEND then
            if UIManager.IsOpen(UIName.GuildFightResultPopup) then
                UIManager.ClosePanel(UIName.GuildFightResultPopup)
            end
            UIManager.OpenPanel(UIName.GuildFightDefendInfoPopup, true)
        elseif curStage == GUILD_FIGHT_STAGE.ATTACK then
            if UIManager.IsOpen(UIName.GuildFightMatchSuccessPopup) then
                UIManager.ClosePanel(UIName.GuildFightMatchSuccessPopup)
            end
            UIManager.OpenPanel(UIName.GuildFightAttackTipPopup)
        elseif curStage == GUILD_FIGHT_STAGE.COUNTING then
            if UIManager.IsOpen(UIName.GuildFightAttackTipPopup) then
                UIManager.ClosePanel(UIName.GuildFightAttackTipPopup)
            end
            UIManager.OpenPanel(UIName.GuildFightResultPopup)
        end
    end
end

-- 刷新红包红点
function this.CloseRedPointClick()
    GuildRedPacketManager.isCheck=false
    CheckRedPointStatus(RedPointType.Guild_RedPacket)
end

-- --刷新十绝阵是否开启
-- function this.RefreshDeathPos()
--     NetManager.GetDeathPathStatusResponse(function(msg)
        
--         DeathPosManager.status = msg.status
--         CheckRedPointStatus(RedPointType.Guild_DeathPos)--阶段切换时 检测红点
--     end)
-- end

function this.RefreshGuildInfo()
    local guildData = MyGuildManager.GetMyGuildInfo()
    local curGuildlv = guildData.levle
    local curGuildLevelInfo = ConfigManager.GetConfigData(ConfigName.GuildLevelConfig, curGuildlv)
    local masterInfo = MyGuildManager.GetMyGuildMasterInfo()

    this.GuildName.text = guildData.name
    this.GuildAnnounce.text = guildData.annouce
    this.GuildLv.text = curGuildlv
    this.GuildMasterName.text = GetLanguageStrById(masterInfo.userName)
    this.GuildMember.text = string.format("%s / %s", guildData.totalNum, curGuildLevelInfo.Num)
    this.GuildExp.text = string.format("%s/%s", guildData.exp, curGuildLevelInfo.Exp)
    this.GuildSlider.value = guildData.exp/curGuildLevelInfo.Exp
end

--界面关闭时调用（用于子类重写）
function GuildMainCityPanel:OnClose()
    _BGMFlag = nil
    -- 计时器关闭
    if this._TimeCounter then
        this._TimeCounter:Stop()
        this._TimeCounter = nil
    end
    -- -- 关闭定时刷新数据
    -- this.ChatTipView:StopCheck()
end

--界面销毁时调用（用于子类重写）
function GuildMainCityPanel:OnDestroy()
    -- SubUIManager.Close(this.ChatTipView)
    SubUIManager.Close(self.HeadFrameView)
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.BtView)
    -- 移除红点
    for type, data in pairs(_GuildBuildConfig) do
        if data.btnName then
            local btn = Util.GetGameObject(self.gameObject, "Bg/"..data.btnName)
            if btn and data.isOpen and data.rpType then
                ClearRedPointObject(data.rpType, Util.GetGameObject(btn, "redpot"))
            end
        end
    end

    -- 清除红点
    ClearRedPointObject(RedPointType.Guild_RedPacket, this.btnRedPacketRedPoint)
end

return GuildMainCityPanel