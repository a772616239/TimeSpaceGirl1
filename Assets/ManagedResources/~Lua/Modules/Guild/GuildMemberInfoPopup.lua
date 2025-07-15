require("Base/BasePanel")
local GuildMemberInfoPopup = Inherit(BasePanel)
local this = GuildMemberInfoPopup

--> GuildMemberInfoPopup PlayerInfoPopup      共用PlayerInfoPopup prefab目前未发现问题 todo

local _GuildPosBtnType = {
    [GUILD_MEM_POPUP_TYPE.INFORMATION] = {
        [GUILD_GRANT.MASTER] = {
            [GUILD_GRANT.ADMIN] = {
                {name = GetLanguageStrById(10942), func = 1},
                {name = GetLanguageStrById(10943), func = 6},
                {name = GetLanguageStrById(10944), func = 3},
            },
            [GUILD_GRANT.MEMBER] = {
                {name = GetLanguageStrById(10942), func = 1},
                {name = GetLanguageStrById(10945), func = 2},
                {name = GetLanguageStrById(10944), func = 3},
            },
        },
        [GUILD_GRANT.ADMIN] = {
            [GUILD_GRANT.MEMBER] = {
                {name = GetLanguageStrById(10944), func = 3},
            }
        },
    },
    [GUILD_MEM_POPUP_TYPE.DEFEND] = {
        [GUILD_GRANT.MASTER] = {
            {name = GetLanguageStrById(10946), func = 4, param = GUILD_BUILD_TYPE.HOUSE },
            {name = GetLanguageStrById(10947), func = 4, param = GUILD_BUILD_TYPE.STORE },
            {name = GetLanguageStrById(10948), func = 4, param = GUILD_BUILD_TYPE.LOGO },
        },
        [GUILD_GRANT.ADMIN] = {
            {name = GetLanguageStrById(10946), func = 4, param = GUILD_BUILD_TYPE.HOUSE },
            {name = GetLanguageStrById(10947), func = 4, param = GUILD_BUILD_TYPE.STORE },
            {name = GetLanguageStrById(10948), func = 4, param = GUILD_BUILD_TYPE.LOGO },
        },
    },
    [GUILD_MEM_POPUP_TYPE.ATTACK_ENEMY_DEFEND] = {
        [GUILD_GRANT.MASTER] = {
            {name = GetLanguageStrById(10737), func = 5},
        },
        [GUILD_GRANT.ADMIN] = {
            {name = GetLanguageStrById(10737), func = 5},
        },
        [GUILD_GRANT.MEMBER] = {
            {name = GetLanguageStrById(10737), func = 5},
        },
    }
}
-- 头像
local _PlayerHead = nil
-- 星星
local _StarList = {}
local _StarMaxNum = 10

--初始化组件（用于子类重写）
function GuildMemberInfoPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnClose")

    this.memHead = Util.GetGameObject(self.transform, "tipImage/panel/info/head")
    this.memName = Util.GetGameObject(self.transform, "tipImage/panel/info/name"):GetComponent("Text")
    this.memProfessTip = Util.GetGameObject(self.transform, "tipImage/panel/info/professName"):GetComponent("Text")
    this.memProfess = Util.GetGameObject(self.transform, "tipImage/panel/info/profess"):GetComponent("Text")
    this.addFriendBtn = Util.GetGameObject(self.transform, "tipImage/panel/info/btnAdd")
    this.addFriendBtnText = Util.GetGameObject(this.addFriendBtn, "text"):GetComponent("Text")
    this.starBox = Util.GetGameObject(self.transform, "tipImage/panel/info/starBox")
    this.star = Util.GetGameObject(self.transform, "tipImage/panel/info/starBox/star")
    this.memPower = Util.GetGameObject(self.transform, "tipImage/panel/defendbox/power"):GetComponent("Text")
    this.formationTip = Util.GetGameObject(self.transform, "tipImage/panel/defendbox/tip"):GetComponent("Text")

    this.attackCount = Util.GetGameObject(self.transform, "tipImage/attackCount"):GetComponent("Text")

    -- this.DiffDemons = {}
    -- for i = 1, 3 do
    --     table.insert(this.DiffDemons, Util.GetGameObject(self.gameObject, "tipImage/panel/defendbox/diffdemons/icon_"..i))
    -- end
    this.Demons = {}
    for i = 1, 6 do
        table.insert(this.Demons, Util.GetGameObject(self.gameObject, "tipImage/panel/defendbox/Demons/heroPro (" .. i .. ")"))
    end

    this.boxLine = Util.GetGameObject(self.transform, "tipImage/panel/defendbox/line")
    this.btnBox = Util.GetGameObject(self.transform, "panel/box")
    this.btnList = {}
    this.btnList[1] = Util.GetGameObject(this.btnBox, "btn1")
    this.btnList[2] = Util.GetGameObject(this.btnBox, "btn2")
    this.btnList[3] = Util.GetGameObject(this.btnBox, "btn3")

end

--绑定事件（用于子类重写）
function GuildMemberInfoPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
    Util.AddClick(this.addFriendBtn, function()
        if this._ViewType ~= GUILD_MEM_POPUP_TYPE.INFORMATION then

            return
        end
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GOODFRIEND) then
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GOODFRIEND))
            return
        end
        if GoodFriendManager.IsInBlackList(this._MemId) then
            PopupTipPanel.ShowTipByLanguageId(10817)
            return
        end
        if this._MemId == PlayerManager.uid then
            PopupTipPanel.ShowTipByLanguageId(10950)
            return
        end
        if GoodFriendManager.IsMyFriend(this._MemId) then
            PopupTipPanel.ShowTipByLanguageId(10951)
            return
        end
        if this._PlayerData.isApplyed == 1 then
            PopupTipPanel.ShowTipByLanguageId(10822)
            return
        end
        GoodFriendManager.InviteFriendRequest(this._MemId, function()
            PopupTipPanel.ShowTipByLanguageId(10415)
            this._PlayerData.isApplyed = 1
            this.RefreshFunction()
        end)
    end)
end

--添加事件监听（用于子类重写）
function GuildMemberInfoPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.BeKickOut, this.CloseSelf)
end

--移除事件监听（用于子类重写）
function GuildMemberInfoPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.BeKickOut, this.CloseSelf)
end

-- 关闭界面
function this.CloseSelf()
    this:ClosePanel()
end


--界面打开时调用（用于子类重写）
function GuildMemberInfoPopup:OnOpen(type, memId, starNum)
    this._MemId = memId
    this._ViewType = type or GUILD_MEM_POPUP_TYPE.INFORMATION
    this._StarNum = starNum

    this.formationTip.text = type == GUILD_MEM_POPUP_TYPE.INFORMATION and GetLanguageStrById(10952) or GetLanguageStrById(10953)
    -- 注册按钮事件
    this.btnFunc = {
        [1] = this.SetMaster,
        [2] = this.SetAdmin,
        [3] = this.KickOut,
        [4] = this.ChangeMemBuildType,
        [5] = this.AttackEnemy,
        [6] = this.CancelAdmin,
    }
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildMemberInfoPopup:OnShow()
    if this._ViewType == GUILD_MEM_POPUP_TYPE.ATTACK_MY_DEFEND then
        this._MemData = GuildFightManager.GetAttackStagePlayerDefendData(GUILD_FIGHT_GUILD_TYPE.MY, this._MemId).userInfo
    elseif this._ViewType == GUILD_MEM_POPUP_TYPE.ATTACK_ENEMY_DEFEND then
        this._MemData = GuildFightManager.GetAttackStagePlayerDefendData(GUILD_FIGHT_GUILD_TYPE.ENEMY, this._MemId).userInfo
    else
        this._MemData = MyGuildManager.GetMemInfo(this._MemId)
    end
    -- 刷新基础信息
    this.RefreshPlayerInfo()
    -- 刷新进攻次数显示
    this.RefreshAttackCount()
    -- 刷新功能区显示
    this.RefreshFunction()
    -- 刷新编队显示
    this.RefreshFormationShow()
    -- 刷新按钮显示
    this.RefreshBtnShow()
end

-- 刷新基础信息显示
function this.RefreshPlayerInfo()
    this.memName.text = this._MemData.userName
    this.memProfessTip.text = GetLanguageStrById(10954)
    this.memProfess.text = GUILD_GRANT_STR[this._MemData.position]
    -- 头像
    if not _PlayerHead then
        _PlayerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.memHead.transform)
    end
    _PlayerHead:Reset()
    _PlayerHead:SetScale(Vector3.one * 0.85)
    _PlayerHead:SetHead(this._MemData.head)
    _PlayerHead:SetFrame(this._MemData.frame)
    _PlayerHead:SetLevel(this._MemData.userLevel)
end

-- 刷新进攻次数显示
function this.RefreshAttackCount()
    this.attackCount.gameObject:SetActive(false)
    if this._ViewType == GUILD_MEM_POPUP_TYPE.ATTACK_ENEMY_DEFEND then
        this.attackCount.gameObject:SetActive(true)
        local leftCount = GuildFightManager.GetLeftAttackCount()
        this.attackCount.text = string.format(GetLanguageStrById(10955), leftCount)
    end
end

-- 刷新功能区
function this.RefreshFunction()
    this.addFriendBtn:SetActive(false)
    this.starBox:SetActive(false)

    if this._ViewType == GUILD_MEM_POPUP_TYPE.INFORMATION then
        this.addFriendBtn:SetActive(true)
        if not this._PlayerData then return end
        local isSelf = this._MemId == PlayerManager.uid
        local isMyFriend = isSelf and true or GoodFriendManager.IsMyFriend(this._MemId)
        local isApplyed = this._PlayerData.isApplyed == 1
        Util.SetGray(this.addFriendBtn, isMyFriend or isApplyed)
        this.addFriendBtnText.text = isApplyed and GetLanguageStrById(10819) or GetLanguageStrById(10956)

    elseif this._ViewType == GUILD_MEM_POPUP_TYPE.DEFEND
            or this._ViewType == GUILD_MEM_POPUP_TYPE.ATTACK_ENEMY_DEFEND
            or this._ViewType == GUILD_MEM_POPUP_TYPE.ATTACK_MY_DEFEND then
        if not this._StarNum then return end
        this.starBox:SetActive(true)
        local maxNum = math.max(this._StarNum, #_StarList)
        for i = 1, maxNum do
            if not _StarList[i] then
                _StarList[i] = newObjToParent(this.star, this.starBox)
            end
            _StarList[i]:SetActive(i <= this._StarNum)
        end
    end
end

-- 刷新编队信息
function this.RefreshFormationShow()
    if this._ViewType == GUILD_MEM_POPUP_TYPE.INFORMATION then
        NetManager.RequestPlayerInfo(this._MemId, FormationTypeDef.FORMATION_NORMAL, function(msg)
            -- 重置战斗力
            local teamInfo = msg.teamInfo.team
            local force = teamInfo.totalForce
            MyGuildManager.ResetMemForce(this._MemId, force)
            this.FormationAdapter(teamInfo)
            -- 刷新功能显示
            this._PlayerData = msg.teamInfo
            this.RefreshFunction()
        end)
    elseif this._ViewType == GUILD_MEM_POPUP_TYPE.DEFEND then
        NetManager.RequestGuildFightDefendFormation(PlayerManager.familyId, this._MemId, function(msg)
            -- 重置战斗力
            GuildFightManager.ResetDefendStageDataForce(this._MemId, msg.teamInfo.totalForce)
            --
            this.FormationAdapter(msg.teamInfo)
        end)
    elseif this._ViewType == GUILD_MEM_POPUP_TYPE.ATTACK_MY_DEFEND then
        NetManager.RequestGuildFightDefendFormation(PlayerManager.familyId, this._MemId, function(msg)
            this.FormationAdapter(msg.teamInfo)
        end)
    elseif this._ViewType == GUILD_MEM_POPUP_TYPE.ATTACK_ENEMY_DEFEND then
        local enemyGuild = GuildFightManager.GetEnemyBaseData()
        if not enemyGuild then return end
        NetManager.RequestGuildFightDefendFormation(enemyGuild.id, this._MemId, function(msg)
            this.FormationAdapter(msg.teamInfo)
        end)
    end
end

-- 编队数据匹配
function this.FormationAdapter(teamInfo)
    
    -- 战斗力
    this.memPower.text = teamInfo.totalForce
    -- 妖灵师
    for i, demon in ipairs(this.Demons) do
        Util.GetGameObject(demon, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(1))
        Util.GetGameObject(demon, "hero"):SetActive(false)
    end
    for i, hero in ipairs(teamInfo.team) do
        local demonId = teamInfo.team[i].heroTid
        if demonId then
            local heroGo = Util.GetGameObject(this.Demons[i], "hero")
            heroGo:SetActive(true)
            SetHeroStars(Util.GetGameObject(heroGo, "starGrid"), hero.star)
            local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, demonId)
            Util.GetGameObject(heroGo, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
            Util.GetGameObject(heroGo, "lvbg/levelText"):GetComponent("Text").text = hero.level
            Util.GetGameObject(this.Demons[i], "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(heroConfig.Quality,hero.star))
            Util.GetGameObject(heroGo, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
            local frameBtn = Util.GetGameObject(this.Demons[i], "frame")
            local heroData = {}
            Util.AddOnceClick(frameBtn, function()
                NetManager.ViewHeroInfoRequest(this._MemId,hero.heroid,function(msg)
                    heroData= GoodFriendManager.GetHeroDatas(msg.hero,msg.force,msg.SpecialEffects,msg.guildSkill)
                    GoodFriendManager.InitEquipData(msg.equip,heroData)--HeroManager.GetSingleHeroData(heroData.dynamicId)
                    GoodFriendManager.InitModelData(msg, heroData)
                    UIManager.OpenPanel(UIName.RoleInfoPopup, heroData,true)
                end)
            end)
        end
    end

end

-- 刷新按钮显示
function this.RefreshBtnShow()
    -- 判断该界面类型是否有按钮显示
    
    local posToType = _GuildPosBtnType[this._ViewType]
    
    if not posToType then
        this.boxLine:SetActive(false)
        this.btnBox:SetActive(false)
        return
    end
    -- 判断我的职位是否有按钮显示
    local pos = MyGuildManager.GetMyPositionInGuild()
    local btnType = posToType[pos]
    if btnType and (not btnType[1] or not btnType[1].name) then    -- 判断类型
        btnType = btnType[this._MemData.position]
    end
    if not btnType then 
        this.boxLine:SetActive(false)
        this.btnBox:SetActive(false)
        return
    end

    if this._ViewType == GUILD_MEM_POPUP_TYPE.INFORMATION then  --< 信息界面永久去除委任等按钮 另起单独显示了 其他界面保留
        this.boxLine:SetActive(false)
        this.btnBox:SetActive(false)
        return
    end

    -- 有按钮显示
    this.boxLine:SetActive(true)
    this.btnBox:SetActive(true)
    for index, btn in ipairs(this.btnList) do
        btn:SetActive(btnType[index] ~= nil)
        if btnType[index] then
            Util.GetGameObject(btn, "Text"):GetComponent("Text").text = btnType[index].name
            Util.AddOnceClick(btn, function()
                local funcType = btnType[index].func
                if not this.btnFunc[funcType] then

                    return
                end
                this.btnFunc[funcType](btnType[index].param)
            end)
        end
    end
end

----===============================  按钮事件==================================
-- 转让会长
function this.SetMaster()
    -- 公会战期间无法执行此操作
    if GuildFightManager.IsInGuildFight() then
        PopupTipPanel.ShowTipByLanguageId(10908)
        return
    end
    -- 判断是否有权限
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos ~= GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10958)
        return
    end
    if this._MemId == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10959)
        return
    end
    if this._MemData.position == GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10960)
        return
    end

    MsgPanel.ShowTwo(GetLanguageStrById(10961), nil, function()
        -- 转让会长
        MyGuildManager.AppointmentPos(this._MemId, GUILD_GRANT.MASTER, function ()
            this:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10962)
        end)
    end)
end
-- 委任管理员
function this.SetAdmin()
    -- 公会战期间无法执行此操作
    if GuildFightManager.IsInGuildFight() then
        PopupTipPanel.ShowTipByLanguageId(10908)
        return
    end
    -- 判断是否有权限
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos ~= GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10963)
        return
    end
    if this._MemId == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10959)
        return
    end
    if this._MemData.position == GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10964)
        return
    end
    if this._MemData.position == GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10965)
        return
    end

    local adminNum = MyGuildManager.GetAdminMemNum()
    local guildData = MyGuildManager.GetMyGuildInfo()
    local maxNum = ConfigManager.GetConfigData(ConfigName.GuildLevelConfig, guildData.levle).OfficalNum
    if adminNum >= maxNum then
        PopupTipPanel.ShowTipByLanguageId(10966)
        return
    end

    MsgPanel.ShowTwo(GetLanguageStrById(10967), nil, function()
        -- 委任管理员
        MyGuildManager.AppointmentPos(this._MemId, GUILD_GRANT.ADMIN, function ()
            this:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10968)
        end)
    end)
end
-- 取消管理员
function this.CancelAdmin()
    -- 公会战期间无法执行此操作
    if GuildFightManager.IsInGuildFight() then
        PopupTipPanel.ShowTipByLanguageId(10908)
        return
    end
    -- 判断是否有权限
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos ~= GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10969)
        return
    end
    if this._MemId == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10959)
        return
    end
    if this._MemData.position == GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10970)
        return
    end
    if this._MemData.position ~= GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10971)
        return
    end

    MsgPanel.ShowTwo(GetLanguageStrById(10972), nil, function()
        -- 委任管理员
        MyGuildManager.AppointmentPos(this._MemId, GUILD_GRANT.MEMBER, function ()
            this:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10973)
        end)
    end)
end

-- 驱逐公会
function this.KickOut()
    -- 公会战期间无法执行此操作
    if GuildFightManager.IsInGuildFight() then
        PopupTipPanel.ShowTipByLanguageId(10908)
        return
    end
    -- 判断是否有权限
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10974)
        return
    end
    if this._MemId == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10959)
        return
    end
    if this._MemData.position == GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10975)
        return
    end
    if pos == GUILD_GRANT.ADMIN and this._MemData.position == GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10976)
        return
    end


    MsgPanel.ShowTwo(GetLanguageStrById(10977), nil, function()
        MyGuildManager.RequestKickOut(this._MemId, function()
            this:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(10978)
        end)
    end)

end


-- 改变成员防守建筑
function this.ChangeMemBuildType(buildType)
    -- 判断是否有权限
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10917)
        return
    end
    GuildFightManager.RequestChangeMemDefend(this._MemId, buildType, function ()
        this:ClosePanel()
    end)
end


-- 改变成员防守建筑
function this.AttackEnemy()

    local leftCount = GuildFightManager.GetLeftAttackCount()
    if not leftCount or leftCount <= 0 then
        PopupTipPanel.ShowTipByLanguageId(10734)
        return
    end

    -- 获取我的英雄的数据
    GuildFightManager.RequestMyHeroBloodData(function()
        this:ClosePanel()
        FormationManager.CheckFormationHp(FormationTypeDef.FORMATION_GUILD_FIGHT_ATTACK)
        UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.GUILD_ATTACK, this._MemId)
    end)

end


--界面关闭时调用（用于子类重写）
function GuildMemberInfoPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildMemberInfoPopup:OnDestroy()
    -- 头像
    if _PlayerHead then
        _PlayerHead:Recycle()
        _PlayerHead = nil
    end
    -- 星星
    _StarList = {}

end

return GuildMemberInfoPopup