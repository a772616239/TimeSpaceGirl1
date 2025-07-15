require("Base/BasePanel")
local PlayerInfoPopup = Inherit(BasePanel)
local this = PlayerInfoPopup
local adjutantConfig = ConfigManager.GetConfig(ConfigName.AdjutantConfig) 
local artifactConfig = ConfigManager.GetConfig(ConfigName.ArtifactConfig)

function GetViewConfig(playerInfoViewType)
    local table = nil

    if playerInfoViewType == PLAYER_INFO_VIEW_TYPE.NORMAL then
        local isSelf = this._PlayerId == PlayerManager.uid
        local isMyFriend = isSelf and true or GoodFriendManager.IsMyFriend(this._PlayerId)
        local isApplyed = this._PlayerData == nil and true or this._PlayerData.isApplyed == 1

        if isSelf or isMyFriend then
            table = {
                formationType = FormationTypeDef.FORMATION_NORMAL,
                tip = GetLanguageStrById(10952),
                btnType = {
                    {name = GetLanguageStrById(11580), func = 2},
                    {name = GetLanguageStrById(11581), func = 3},
                }
            }
        elseif isApplyed then
            table = {
                formationType = FormationTypeDef.FORMATION_NORMAL,
                tip = GetLanguageStrById(10952),
                btnType = {
                    {name = GetLanguageStrById(11580), func = 2},
                    {name = GetLanguageStrById(11581), func = 3},
                    {name = GetLanguageStrById(10819), func = 6, unenable = true},
                }
            }
        else
            table = {
                formationType = FormationTypeDef.FORMATION_NORMAL,
                tip = GetLanguageStrById(10952),
                btnType = {
                    {name = GetLanguageStrById(11580), func = 2},
                    {name = GetLanguageStrById(11581), func = 3},
                    {name = GetLanguageStrById(10820), func = 6},
                }
            }
        end

    elseif playerInfoViewType == PLAYER_INFO_VIEW_TYPE.BLACK_REMOVE then
        table = {
            formationType = FormationTypeDef.FORMATION_NORMAL,
            tip = GetLanguageStrById(10952),
            btnType = {
                {name = GetLanguageStrById(11582), func = 4},
            }
        }
    elseif playerInfoViewType == PLAYER_INFO_VIEW_TYPE.GO_TO_BLACK then
        table = {
            formationType = FormationTypeDef.FORMATION_NORMAL,
            tip = GetLanguageStrById(10952),
            btnType = {
                {name = GetLanguageStrById(11583), func = 5},
            }
        }
    elseif playerInfoViewType == PLAYER_INFO_VIEW_TYPE.ARENA then
        table = {
            formationType = FormationTypeDef.FORMATION_ARENA_DEFEND,
            tip = GetLanguageStrById(11584),
        }
    elseif playerInfoViewType == PLAYER_INFO_VIEW_TYPE.ChaosZZ then
        table = {
            formationType = FormationTypeDef.CHAOS_BATTLE,
            tip = "混乱之治防守阵容:",
        }
    elseif playerInfoViewType == PLAYER_INFO_VIEW_TYPE.LADDERSARENA then
        table = {
            formationType = FormationTypeDef.LADDERS_DEFEND,
            tip = GetLanguageStrById(50320),
            btnType = {
                {name = GetLanguageStrById(50321), func = 7, param = FORMATION_TYPE.LADDERSCHALLENGE},
                {name = GetLanguageStrById(50322), func = 8, param = this.args},
            }
        }
    end

    return table
end

local isGotoBattle = false
local _PlayerHead = nil
--初始化组件（用于子类重写）
function PlayerInfoPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnClose")
    this.backMask = Util.GetGameObject(self.transform, "BackMask")

    this.memHead = Util.GetGameObject(self.transform, "tipImage/panel/info/head")
    this.memName = Util.GetGameObject(self.transform, "tipImage/panel/info/name"):GetComponent("Text")
    this.memProfessTip = Util.GetGameObject(self.transform, "tipImage/panel/info/professName"):GetComponent("Text")
    this.memProfess = Util.GetGameObject(self.transform, "tipImage/panel/info/profess"):GetComponent("Text")

    this.vip = Util.GetGameObject(self.transform, "tipImage/panel/info/vip"):GetComponent("Image")

    this.starBox = Util.GetGameObject(self.transform, "tipImage/panel/info/starBox")
    this.star = Util.GetGameObject(self.transform, "tipImage/panel/info/starBox/star")
    this.memPower = Util.GetGameObject(self.transform, "tipImage/panel/defendbox/power"):GetComponent("Text")
    this.formationTip = Util.GetGameObject(self.transform, "tipImage/panel/defendbox/tip"):GetComponent("Text")

    this.Demons = {}
    for i = 1, 6 do
        table.insert(this.Demons, Util.GetGameObject(self.gameObject, "tipImage/panel/defendbox/Demons/heroPro (" .. i .. ")"))
    end

    this.zhiyuanPic = Util.GetGameObject(self.transform, "Guard/icon")
    this.xianQuPic = Util.GetGameObject(self.transform, "Adjust/icon")

    this.btnBox = Util.GetGameObject(self.transform, "tipImage/panel/box")
    this.btnList = {}
    for i = 1, 3 do
        this.btnList[i] = Util.GetGameObject(this.btnBox, "btn"..i)
    end

    this.gene = {}
    for i = 1, 4 do
        this.gene[i] = Util.GetGameObject(self.transform, "tipImage/panel/defendbox/Lead").transform:GetChild(i-1).gameObject
    end
end

--绑定事件（用于子类重写）
function PlayerInfoPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
    Util.AddClick(this.backMask, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function PlayerInfoPopup:AddListener()
end

--移除事件监听（用于子类重写）
function PlayerInfoPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function PlayerInfoPopup:OnOpen(playerId, viewType, serverId, playerInfoType, ...)
    this._PlayerId = playerId
    this._ViewType = viewType or PLAYER_INFO_VIEW_TYPE.NORMAL
    if serverId then
        this.serverId = serverId
    end
    this.playerInfoType = playerInfoType or PlayerInfoType.None
    this.args = {...}
    -- 界面类型修正
    if this._ViewType == PLAYER_INFO_VIEW_TYPE.NORMAL and GoodFriendManager.IsInBlackList(this._PlayerId) then
        this._ViewType = PLAYER_INFO_VIEW_TYPE.GO_TO_BLACK
    end
    this._Config = GetViewConfig(this._ViewType)
    -- 注册按钮事件
    this.btnFunc = {
        [1] = this.Report,
        [2] = this.AddToBlackList,
        [3] = this.BeatHim,
        [4] = this.RemoveFromBlackList,
        [5] = this.GoToBlack,
        [6] = this.AddFriend,
        [7] = this.DefensiveRotations,
        [8] = this.StartBattle
    }
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PlayerInfoPopup:OnShow()
    isGotoBattle = false
    for i, demon in ipairs(this.Demons) do
        Util.GetGameObject(demon, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(1))
        Util.GetGameObject(demon, "hero"):SetActive(false)
    end

    for index, btn in ipairs(this.btnList) do
        btn:SetActive(false)
    end

    --九境巅峰
    if this._ViewType == PLAYER_INFO_VIEW_TYPE.LADDERSARENA then
        NetManager.RequestPlayerInfo(this._PlayerId, this._Config.formationType, function(msg)
            -- 如果是好友更新好友数据
            GoodFriendManager.UpdateFriendData(this._PlayerId, msg.teamInfo.level, msg.teamInfo.name, msg.teamInfo.head, msg.teamInfo.headFrame)
            this._PlayerData = msg.teamInfo
            this._Config = GetViewConfig(this._ViewType)
            this.RefreshBtnShow()
            this.RefreshPlayerInfo(msg.teamInfo)
            local teamInfo = msg.teamInfo
            this.FormationAdapter(msg.teamInfo.team,teamInfo)
            --
            this.RefreshFunction()
            -- this.RefreshCV_Adjutant(msg.teamInfo)
    
            this.teamInfo = teamInfo

            --守护
            if teamInfo.supportId == 0 then
                this.zhiyuanPic:SetActive(false)
            else
                local artifactData = artifactConfig[teamInfo.supportId]
                this.zhiyuanPic:GetComponent("Image").sprite = Util.LoadSprite(artifactData.Head)
                this.zhiyuanPic:SetActive(true)
            end
            -- 先驱
            if teamInfo.adjutantId == 0 then
                this.xianQuPic:SetActive(false)
            else
                local adjutantDate = adjutantConfig[teamInfo.adjutantId]
                this.xianQuPic:GetComponent("Image").sprite = Util.LoadSprite(adjutantDate.Head)
                this.xianQuPic:SetActive(true)
            end

        end, nil, PlayerInfoType.CSArena)
        return
    end

    -- 请求数据
    NetManager.RequestPlayerInfo(this._PlayerId, this._Config.formationType, function(msg)
        -- 如果是好友更新好友数据
        GoodFriendManager.UpdateFriendData(this._PlayerId, msg.teamInfo.level, msg.teamInfo.name, msg.teamInfo.head, msg.teamInfo.headFrame)
        this._PlayerData = msg.teamInfo
        this._Config = GetViewConfig(this._ViewType)
        this.RefreshBtnShow()
        this.btnBox:SetActive(this._PlayerId > 100000)
        this.RefreshPlayerInfo(msg.teamInfo)
        local teamInfo = msg.teamInfo
        this.FormationAdapter(msg.teamInfo.team,teamInfo)

        --守护
        if teamInfo.supportId == 0 then
            this.zhiyuanPic:SetActive(false)
        else
            local artifactData = artifactConfig[teamInfo.supportId]
            this.zhiyuanPic:GetComponent("Image").sprite = Util.LoadSprite(artifactData.Head)
            this.zhiyuanPic:SetActive(true)
        end
        -- 先驱
        if teamInfo.adjutantId == 0 then
            this.xianQuPic:SetActive(false)
        else
            local adjutantDate = adjutantConfig[teamInfo.adjutantId]
            this.xianQuPic:GetComponent("Image").sprite = Util.LoadSprite(adjutantDate.Head)
            this.xianQuPic:SetActive(true)
        end

        --
        this.RefreshFunction()
        -- this.RefreshCV_Adjutant(msg.teamInfo)
        this.teamInfo = teamInfo
    end, nil, this.playerInfoType)
end

--界面关闭时调用（用于子类重写）
function PlayerInfoPopup:OnClose()
    this.battleBtnIsShow = nil
end

--界面销毁时调用（用于子类重写）
function PlayerInfoPopup:OnDestroy()
    -- 头像
    if _PlayerHead then
        _PlayerHead:Recycle()
        _PlayerHead = nil
    end
    this.SkillPlane = {}
end

-- 设置界面类型
function PlayerInfoPopup:SetViewType(viewType)
    this._ViewType = viewType or PLAYER_INFO_VIEW_TYPE.NORMAL
    this:OnShow()
end

-- 刷新基础信息显示
function this.RefreshPlayerInfo(data)
    this.memName.text = SetRobotName(data.uid, data.name)

    this.memProfessTip.text = GetLanguageStrById(10629)
    if data.guildName ~= "" then
        this.memProfess.text = data.guildName--GUILD_GRANT_STR[data.position]
    else
        this.memProfess.text = GetLanguageStrById(10094)
    end
    -- 头像
    if not _PlayerHead then
        _PlayerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.memHead.transform)
    end
    _PlayerHead:Reset()
    _PlayerHead:SetScale(Vector3.one * 1)
    _PlayerHead:SetHead(data.head)
    _PlayerHead:SetFrame(data.headFrame)
    _PlayerHead:SetLevel("LV." .. data.level)

    if data.vip > 0 then
        if data.showVip then
            this.vip.gameObject:SetActive(true)
            this.vip.sprite = Util.LoadSprite("T_vip_".. data.vip .. "_meisuzi")
        else
            this.vip.gameObject:SetActive(false)
        end
    else
        this.vip.gameObject:SetActive(false)
    end
end

-- 刷新功能区
function this.RefreshFunction()
    --  this.addFriendBtn:SetActive(false)
    this.starBox:SetActive(false)

    if this._ViewType == PLAYER_INFO_VIEW_TYPE.NORMAL then
        --  this.addFriendBtn:SetActive(true)
        local isSelf = this._PlayerId == PlayerManager.uid
        local isMyFriend = isSelf and true or GoodFriendManager.IsMyFriend(this._PlayerId)
        local isApplyed = this._PlayerData.isApplyed == 1
        --  Util.SetGray(this.addFriendBtn, isMyFriend or isApplyed)
        --  this.addFriendBtnText.text = isApplyed and GetLanguageStrById(10819) or GetLanguageStrById(10956)
    end
end

-- 编队数据匹配
function this.FormationAdapter(teamInfo, allteaminfo)
    this.formationTip.text = GetViewConfig(this._ViewType).tip
    -- 战斗力
    this.memPower.text = teamInfo.totalForce

    for i, demon in ipairs(this.Demons) do
        Util.GetGameObject(demon, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(1))
        Util.GetGameObject(demon, "hero"):SetActive(false)
        Util.GetGameObject(demon, "proIconBg"):SetActive(false)
        Util.GetGameObject(demon, "proIcon"):SetActive(false)
		Util.GetGameObject(demon, "Lvbg"):SetActive(false)
        Util.GetGameObject(demon, "levelText"):SetActive(false)
        Util.GetGameObject(demon, "starGrid"):SetActive(false)
    end

    if allteaminfo.substitute ~= "" and allteaminfo.substitute ~= nil then
        local hero = {
            heroid = allteaminfo.substitute ,
            heroTid = allteaminfo.substituteTid ,
            star = allteaminfo.substituteStar,
            level = allteaminfo.substituteLevel
        }
        local tibuPos = 6 -- 对应预制体位置
        local heroGo = Util.GetGameObject(this.Demons[tibuPos], "hero")
        heroGo:SetActive(true)
        Util.GetGameObject(this.Demons[tibuPos], "proIconBg"):SetActive(true)
        Util.GetGameObject(this.Demons[tibuPos], "proIcon"):SetActive(true)
        Util.GetGameObject(this.Demons[tibuPos], "Lvbg"):SetActive(true)
        Util.GetGameObject(this.Demons[tibuPos], "levelText"):SetActive(true)
        Util.GetGameObject(this.Demons[tibuPos], "starGrid"):SetActive(true)
        SetHeroStars(Util.GetGameObject(this.Demons[tibuPos], "starGrid"), hero.star)
        local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, hero.heroTid)
        Util.GetGameObject(this.Demons[tibuPos], "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
        Util.GetGameObject(heroGo, "frameBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityBgImageByquality(heroConfig.Quality))
        Util.GetGameObject(this.Demons[tibuPos], "levelText"):GetComponent("Text").text = hero.level
        Util.GetGameObject(this.Demons[tibuPos], "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(heroConfig.Quality, hero.star))
        Util.GetGameObject(heroGo, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
        Util.GetGameObject(this.Demons[tibuPos], "proIconBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroConfig.Quality, hero.star))
       
        local frameBtn = Util.GetGameObject(this.Demons[tibuPos], "frame")
        local heroData = {}
        Util.AddOnceClick(frameBtn, function()
            if this._ViewType == PLAYER_INFO_VIEW_TYPE.LADDERSARENA   or this._ViewType == PLAYER_INFO_VIEW_TYPE.ChaosZZ  then
                NetManager.WorldViewHeroInfoRequest(this._PlayerId, hero.heroid, function(msg)
                    heroData = GoodFriendManager.GetHeroDatas(msg.hero,msg.force,msg.SpecialEffects,msg.guildSkill)
                    GoodFriendManager.InitEquipData(msg.equip,heroData)--HeroManager.GetSingleHeroData(heroData.dynamicId)
                    GoodFriendManager.InitModelData(msg, heroData)
                    UIManager.OpenPanel(UIName.RoleInfoPopup, heroData,true)
                end)
            else
                NetManager.ViewHeroInfoRequest(this._PlayerId, hero.heroid, function(msg)
                    heroData = GoodFriendManager.GetHeroDatas(msg.hero,msg.force,msg.SpecialEffects,msg.guildSkill)
                    GoodFriendManager.InitEquipData(msg.equip,heroData)--HeroManager.GetSingleHeroData(heroData.dynamicId)
                    GoodFriendManager.InitModelData(msg, heroData)
                    UIManager.OpenPanel(UIName.RoleInfoPopup, heroData,true)
                end)
            end
        end)
    end

    for i, hero in ipairs(teamInfo.team) do
        local demonId = teamInfo.team[i].heroTid
        if demonId then
            local heroGo = Util.GetGameObject(this.Demons[i], "hero")
            heroGo:SetActive(true)
            Util.GetGameObject(this.Demons[i], "proIconBg"):SetActive(true)
            Util.GetGameObject(this.Demons[i], "proIcon"):SetActive(true)
			Util.GetGameObject(this.Demons[i], "Lvbg"):SetActive(true)
            Util.GetGameObject(this.Demons[i], "levelText"):SetActive(true)
            Util.GetGameObject(this.Demons[i], "starGrid"):SetActive(true)
            SetHeroStars(Util.GetGameObject(this.Demons[i], "starGrid"), hero.star)
            local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, demonId)
            Util.GetGameObject(this.Demons[i], "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
            Util.GetGameObject(heroGo, "frameBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityBgImageByquality(heroConfig.Quality))
            Util.GetGameObject(this.Demons[i], "levelText"):GetComponent("Text").text = hero.level
            Util.GetGameObject(this.Demons[i], "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(heroConfig.Quality, hero.star))
            Util.GetGameObject(heroGo, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
            Util.GetGameObject(this.Demons[i], "proIconBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroConfig.Quality, hero.star))
            
            local frameBtn = Util.GetGameObject(this.Demons[i], "frame")
            local heroData = {}
            Util.AddOnceClick(frameBtn, function()
                if this._ViewType == PLAYER_INFO_VIEW_TYPE.LADDERSARENA or this._ViewType == PLAYER_INFO_VIEW_TYPE.ChaosZZ then
                    NetManager.WorldViewHeroInfoRequest(this._PlayerId, hero.heroid, function(msg)
                        heroData = GoodFriendManager.GetHeroDatas(msg.hero,msg.force,msg.SpecialEffects,msg.guildSkill)
                        GoodFriendManager.InitEquipData(msg.equip,heroData)--HeroManager.GetSingleHeroData(heroData.dynamicId)
                        GoodFriendManager.InitModelData(msg, heroData)
                        UIManager.OpenPanel(UIName.RoleInfoPopup, heroData,true)
                    end)
                else
                     NetManager.ViewHeroInfoRequest(this._PlayerId,hero.heroid,function(msg)
                        heroData = GoodFriendManager.GetHeroDatas(msg.hero,msg.force,msg.SpecialEffects,msg.guildSkill)
                        GoodFriendManager.InitEquipData(msg.equip,heroData)--HeroManager.GetSingleHeroData(heroData.dynamicId)
                        GoodFriendManager.InitModelData(msg, heroData)
                        UIManager.OpenPanel(UIName.RoleInfoPopup, heroData,true)
                    end)
                end
            end)
        end
    end

    Util.GetGameObject(this.gameObject, "tipImage/panel/defendbox/Lead"):SetActive(allteaminfo.motherShipInfo and #allteaminfo.motherShipInfo.plan > 0)
    for i = 1, 4 do
        local lock = Util.GetGameObject(this.gene[i], "lock")
        local mask = Util.GetGameObject(this.gene[i], "mask")
        local icon = Util.GetGameObject(this.gene[i], "mask/icon"):GetComponent("Image")
        local level = Util.GetGameObject(this.gene[i], "level"):GetComponent("Image")

        local data
        if allteaminfo.motherShipInfo then
            for j = 1, #allteaminfo.motherShipInfo.plan do
                if allteaminfo.motherShipInfo.plan[j].sort == i then
                    data = allteaminfo.motherShipInfo.plan[j]
                end
            end
        end
        if allteaminfo.motherShipInfo and i > allteaminfo.motherShipInfo.unlockSkillSize then
            lock:SetActive(true)
            mask:SetActive(false)
            level.gameObject:SetActive(false)
        else
            lock:SetActive(false)
            if data then
                mask:SetActive(true)
                level.gameObject:SetActive(true)
                local config = AircraftCarrierManager.GetSkillLvImgForId(data.cfgId)
                icon.sprite = SetIcon(data.cfgId)
                level.sprite = Util.LoadSprite(config.lvImg)
            else
                mask:SetActive(false)
                level.gameObject:SetActive(false)
            end
        end
    end
end

-- 刷新按钮显示
function this.RefreshBtnShow()
    -- 自己
    if this._PlayerId == PlayerManager.uid then
        this.btnBox:SetActive(false)
        return
    end
    -- 判断该界面类型是否有按钮显示
    if not this._Config or not this._Config.btnType then
        this.btnBox:SetActive(false)
        return
    end
    -- 有按钮显示
    local btnType = this._Config.btnType
    if this._ViewType == PLAYER_INFO_VIEW_TYPE.LADDERSARENA then
        this.btnBox:SetActive(true)
    else
        this.btnBox:SetActive(this._PlayerId > 10000)
    end

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
            Util.SetGray(btn, btnType[index].unenable == nil and false or btnType[index].unenable)
        end
    end

    -- if this.serverId ~= nil then
    --     if PlayerManager.serverInfo.server_id == this.serverId then
    --         this.btnBox:SetActive(true)
    --     else
    --         this.btnBox:SetActive(false)
    --     end
    -- end
    -- if this.playerInfoType == PlayerInfoType.CSArena then
    --     this.btnBox:SetActive(true)
    -- end
end

----===============================  按钮事件==================================
function this.AddFriend()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GOODFRIEND) then
        PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GOODFRIEND))
        return
    end
    if GoodFriendManager.IsInBlackList(this._PlayerId) then
        PopupTipPanel.ShowTipByLanguageId(10817)
        return
    end
    if this._PlayerId == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10950)
        return
    end
    if GoodFriendManager.IsMyFriend(this._PlayerId) then
        PopupTipPanel.ShowTipByLanguageId(10951)
        return
    end
    if this._PlayerData.isApplyed == 1 then
        PopupTipPanel.ShowTipByLanguageId(10822)
        return
    end
    GoodFriendManager.InviteFriendRequest(this._PlayerId, function()
        PopupTipPanel.ShowTipByLanguageId(11585)
        this._PlayerData.isApplyed = 1
        this.RefreshFunction()
        this._Config = GetViewConfig(this._ViewType)
        this.RefreshBtnShow()
    end)
end

-- 举报
function this.Report()
end
-- 拉黑
function this.AddToBlackList()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GOODFRIEND) then
        PopupTipPanel.ShowTipByLanguageId(10835)
        return
    end
    if table.nums(GoodFriendManager.blackFriendList) >= GoodFriendManager.blackFriendLimit then
        PopupTipPanel.ShowTipByLanguageId(11587)
        return
    end
    GoodFriendManager.RequestAddToBlackList(this._PlayerId, function()
        PopupTipPanel.ShowTipByLanguageId(11588)
        this:SetViewType(PLAYER_INFO_VIEW_TYPE.GO_TO_BLACK)
    end)
end
-- 移除黑名单
function this.RemoveFromBlackList()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GOODFRIEND) then
        PopupTipPanel.ShowTipByLanguageId(10835)
        return
    end
    GoodFriendManager.RequestDeleteFromBlackList(this._PlayerId, function()
        PopupTipPanel.ShowTipByLanguageId(11589)
        this:ClosePanel()
    end)
end
-- 移除黑名单
function this.GoToBlack()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GOODFRIEND) then
        PopupTipPanel.ShowTipByLanguageId(10835)
        return
    end
    this:ClosePanel()
    UIManager.OpenPanel(UIName.GoodFriendMainPanel, true, 4)
end
-- 打他
function this.BeatHim()
    if isGotoBattle then
        return
    end
    isGotoBattle = true
    -- if this._ViewType == FormationTypeDef.FORMATION_NORMAL then
        local structA = nil
        local structB = {
            head = this.teamInfo.head,
            headFrame = this.teamInfo.headFrame,
            name = this.teamInfo.name,
            formationId = this.teamInfo.teamFormation or 1,
            investigateLevel = this.teamInfo.investigateLevel
        }
        BattleManager.SetAgainstInfoData(BATTLE_TYPE.BACK, structA, structB)
    
        -- 请求开始挑战
        PlayerManager.RequestPlayWithSomeOne(this._PlayerId, FormationTypeDef.FORMATION_NORMAL, nil, function()
            this:ClosePanel()
        end)
    -- else

    -- end
    -- this:ClosePanel()
    -- UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.PLAY, this._PlayerId, nil, this.teamInfo)
end

-- 自己防守阵容
function this.DefensiveRotations(formationId)
    UIManager.OpenPanel(UIName.FormationPanelV2, formationId)
end

-- 开始挑战
function this.StartBattle(args)
    local enemyId = args[1]
    local func = args[2]

    func()
end

return PlayerInfoPopup