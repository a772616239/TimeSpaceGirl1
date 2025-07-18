--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Steven Hawking.
--- DateTime: 9/11/21 17:04
--- 公用数据显示部分
local this = {}

-- 页签下标作为参数
local panelPos = {
    [1] = Vector3.New(0, 0, 0), -- 我的
    [2] = Vector3.New(0, 0, 0), -- 竞猜
}
local resultRes = {
    [0] = {name = "cn2-X1_jinbiaosai_lose"},
    [1] = {name = "cn2-X1_jinbiaosai_win"},
}
local FormationConfig = ConfigManager.GetConfig(ConfigName.FormationConfig)

--------- 走 UI界面流程部分  ------------------------------
function this.InitComponent(root)
   
    this.rootPanel = Util.GetGameObject(root.gameObject, "content/ATM_CommonPart")
    this.rootPanel:SetActive(false)

    this.infoPanel = Util.GetGameObject(root.gameObject, "content/ATM_CommonPart/battlePopup")

    --我的信息
    this.myInfo = Util.GetGameObject(this.infoPanel, "Left/Grade")
    this.myPowerNum = Util.GetGameObject(this.myInfo, "power/value"):GetComponent("Text")
    this.myLevel = Util.GetGameObject(this.myInfo, "level/Text"):GetComponent("Text")
    this.myFrame = Util.GetGameObject(this.myInfo, "headBg"):GetComponent("Image")
    this.myIcon = Util.GetGameObject(this.myInfo, "headIcon"):GetComponent("Image")
    this.myName = Util.GetGameObject(this.myInfo, "name"):GetComponent("Text")

    --我的队伍
    this.myTeam = Util.GetGameObject(root.gameObject, "ATM_CommonPart/formatRoot/myFormat")
    this.myTeamSub = Util.GetGameObject(root.gameObject, "ATM_CommonPart/formatRoot/myFormat/substitude")
    this.myTeams = {}
    for i = 1, 9 do
        this.myTeams[i] = Util.GetGameObject(this.myTeam, "Demons/heroPro" .. i)
    end

    this.myZhenXing = Util.GetGameObject(this.myTeam,"formation/zhenxing"):GetComponent("Image")
    this.myZhenBuff = Util.GetGameObject(this.myTeam,"formation/zhenBuff")   

    --她的信息
    this.myInfo = Util.GetGameObject(this.infoPanel, "Right/Grade")
    this.herPowerNum = Util.GetGameObject(this.myInfo, "power/value"):GetComponent("Text")
    this.herLevel = Util.GetGameObject(this.myInfo, "level/Text"):GetComponent("Text")
    this.herFrame = Util.GetGameObject(this.myInfo, "headBg"):GetComponent("Image")
    this.herIcon = Util.GetGameObject(this.myInfo, "headIcon"):GetComponent("Image")
    this.herName = Util.GetGameObject(this.myInfo, "name"):GetComponent("Text")

    --她的队伍
    this.herTeam = Util.GetGameObject(root.gameObject, "ATM_CommonPart/formatRoot/otherFormat")
    this.herTeamSub = Util.GetGameObject(root.gameObject, "ATM_CommonPart/formatRoot/otherFormat/substitude")
    this.herTeams = {}
    for a = 1, 9 do
        this.herTeams[a] = Util.GetGameObject(this.herTeam, "Demons/heroPro" .. a)
    end

    this.otherZhenXing = Util.GetGameObject(this.herTeam,"formation/zhenxing"):GetComponent("Image")
    this.otherZhenBuff = Util.GetGameObject(this.herTeam,"formation/zhenBuff")

    this.LeftWinNum =  {}
    this.RightWinNum =  {}
    this.LeftWinNumGo = Util.GetGameObject(this.infoPanel, "Left/winNum")
    this.RightWinNumGo = Util.GetGameObject(this.infoPanel, "Right/winNum")
    for i = 1, 2 do
        this.LeftWinNum[i] = Util.GetGameObject(this.LeftWinNumGo, "winNum".. i)
        this.RightWinNum[i] = Util.GetGameObject(this.RightWinNumGo, "winNum" .. i)
    end

    this.playback = Util.GetGameObject(this.infoPanel, "Font")
    this.GuessView = Util.GetGameObject(root.gameObject, "content/ATM_GuessView")
    this.btnFormation = Util.GetGameObject(this.rootPanel, "btnOrggroup")
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshBtnFormation)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshBtnFormation)
end

local isInPlayback = false
function this.BindEvent()
    -- 两个按钮相同的功能
    local function formatBtnClick()
        local isCanFormat = this.panelType == 1 and ArenaTopMatchManager.CanChangeTeam()
        if not isCanFormat then
            PopupTipPanel.ShowTipByLanguageId(10149)
        else
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ARENA_TOP_MATCH, function()
                -- 重新获取战斗数据
                ArenaTopMatchManager.RequestTopMatchBaseInfo()
            end)
        end
    end
    -- Util.AddClick(this.btnBlueFormat, formatBtnClick)
    -- Util.AddClick(this.btnRedFormat, formatBtnClick)

    Util.AddClick(this.playback, function ()
        local battleInfo = ArenaTopMatchManager.GetBattleInfo()
        if battleInfo.result == -1 then
            PopupTipPanel.ShowTipByLanguageId(50234)
            return
        end
        if isInPlayback then
            return
        else
            isInPlayback = true
        end
        if BattleManager.IsInBackBattle() then
            return
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.TopMatch.OnMyBattlePlayback)
    end)
    Util.AddClick(this.btnFormation, function ()
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ARENA_TOP_MATCH, function()
        end)
    end)
end
--------------------------------------------------------------------------------

function this.RefreshBtnFormation()
    local isActive = ArenaTopMatchManager.IsTopMatchActive()
    this.btnFormation:SetActive(isActive and not this.GuessView.activeSelf)
end

function this.HidePopup()
    this.infoPanel:SetActive(false)
end

--- @设置模块数据, 相当于OnShow方法
--- @ panelType -- 1 --> 我的 ; 2 -- > 竞猜
--- @ textType -- 需要显示的文字类型 -1  -->  战 ; 1 -- > 胜; 0  -->  败
--- @ showScore -- 是否显示积分
--- @ battleEndResultSortState -- 是否需要翻转战斗数据
function this.SetInfoData(panelType, blueData, redData, textType, showScore, battleEndResultSortState)
    this.panelType = panelType
    this.blueData = blueData
    this.redData = redData
    this.rootPanel.transform.localPosition = panelPos[panelType]
    this.rootPanel:SetActive(true)
    this.battleEndResultSortState = battleEndResultSortState

    this.RefreshData(showScore, textType)
    this.SetBlueInfo(blueData, textType)
    this.SetRedInfo(redData, textType)

    this.FreshTeam(blueData.team, blueData.teamFormation, true, blueData)
    this.FreshTeam(redData.team, redData.teamFormation, false, redData)
    -- if panelType == 1 then--当时我的界面 并且准备阶段时  显示我自己的编队数据
    --     local baseData = ArenaTopMatchManager.GetBaseData()
    --     if baseData.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_GUESS then
    --         this.FreshTeam2(FormationManager.GetFormationByID(FormationTypeDef.ARENA_TOM_MATCH),FormationManager.GetFormationByID(FormationTypeDef.ARENA_TOM_MATCH).formationId, true)
    --     else
    --         this.FreshTeam(blueData.team, blueData.teamFormation, true, blueData)
    --     end
    -- elseif panelType == 2 then
    --     this.FreshTeam(blueData.team, blueData.teamFormation, true, blueData)
    -- end
    -- local baseData = ArenaTopMatchManager.GetBaseData()
    -- if baseData.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_GUESS then
    --     local team = FormationManager.GetFormationByID(FormationTypeDef.ARENA_TOM_MATCH)
    --     local id = FormationManager.GetFormationByID(FormationTypeDef.ARENA_TOM_MATCH).formationId

    --     local allDate = {}
    --     if team and team.substitute ~= nil and team.substitute ~= 0 then
    --         local hero = HeroManager.GetSingleHeroDataByDynamicId(team.substitute)
    --         if hero ~= nil then
    --             allDate.lv = hero.lv
    --             allDate.star = hero.star
    --             allDate.id = hero.id
    --         end
    --     end

    --     this.FreshTeam(team, id, true, allDate)
    -- else
    --     this.FreshTeam(blueData.team, blueData.teamFormation, true, blueData)
    -- end

    this.RefreshTwoOutOfThreeData()

    this.playback:SetActive(not this.GuessView.activeSelf)
    this.RefreshBtnFormation()

    isInPlayback = false
end

-- 设置显隐
function this.SetActive(isActive)
    -- body
    this.rootPanel:SetActive(isActive)
end

function this.SetBlueInfo(blueData, textType)
    this.myPowerNum.text = blueData.team.totalForce
    this.myLevel.text = blueData.level
    this.myFrame.sprite = GetPlayerHeadFrameSprite(blueData.headFrame)
    this.myIcon.sprite = GetPlayerHeadSprite(blueData.head)

    this.myName.text = SetRobotName(blueData.uid, blueData.name)
    local formationData = FormationConfig[blueData.teamFormation]
    if formationData then
        this.myZhenXing.sprite = Util.LoadSprite(GetResourceStr(formationData.icon))     
    else

    end
end

function this.SetRedInfo(redData, textType)
    this.herPowerNum.text = redData.team.totalForce
    this.herLevel.text = redData.level
    this.herFrame.sprite = GetPlayerHeadFrameSprite(redData.headFrame)
    this.herIcon.sprite = GetPlayerHeadSprite(redData.head)
    this.herName.text = SetRobotName(redData.uid, redData.name)
    local formationData = FormationConfig[redData.teamFormation]
    if formationData then
        this.otherZhenXing.sprite = Util.LoadSprite(GetResourceStr(formationData.icon))
    else

    end
end

function this.SetEffectPopupShow(state)
    this.rootPanel:SetActive(state)
end

-- 在此界面时刷新数据
--- 设置积分与文字图标
function this.RefreshData(showScore, textType)
    if showScore and textType >= 0  then
        local deltaIntegral = ArenaTopMatchManager.GetMatchDeltaIntegral()
    else

    end

    -- 设置编队按钮状态
    if this.panelType == 1 then       
        local isCanFormat = ArenaTopMatchManager.CanChangeTeam()
    elseif this.panelType == 2 then

    end
end

function this.RefreshTwoOutOfThreeData()
    this.LeftWinNumGo:SetActive(ArenaTopMatchManager.GetBaseData().battleStage == TOP_MATCH_STAGE.ELIMINATION)
    this.RightWinNumGo:SetActive(ArenaTopMatchManager.GetBaseData().battleStage == TOP_MATCH_STAGE.ELIMINATION)
    if ArenaTopMatchManager.GetBaseData().battleStage == TOP_MATCH_STAGE.ELIMINATION then
        local upWinNum,downWinNum = ArenaTopMatchManager.GetTwoOutOfThreeInfo(this.panelType)

        for i = 1, 2 do
            if this.battleEndResultSortState then
                Util.GetGameObject(this.LeftWinNum[i], "Image"):SetActive(upWinNum >= i)
                Util.GetGameObject(this.RightWinNum[i], "Image"):SetActive(downWinNum >= i)
            else
                Util.GetGameObject(this.RightWinNum[i], "Image"):SetActive(upWinNum >= i)
                Util.GetGameObject(this.LeftWinNum[i], "Image"):SetActive(downWinNum >= i)
            end
        end
    end
end
--根据后端数据显示编队
function this.FreshTeam(formation, teamFormation, isBlue, allDate)
    local choosedList = {}
    local teamRoot = isBlue and this.myTeams or this.herTeams
    for i, demon in ipairs(teamRoot) do
        Util.GetGameObject(demon, "frame"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
        Util.GetGameObject(demon, "hero"):SetActive(false)
    end
    local formationConfig = ConfigManager.GetConfigData(ConfigName.FormationConfig,teamFormation)
    for key, value in ipairs(formationConfig.pos) do
        Util.GetGameObject(teamRoot[value], "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(1))
    end
    --> 重置
    for i = 1, 9 do
        Util.GetGameObject(teamRoot[i], "frame"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
    end
    for i, hero in ipairs(formation.team) do
        teamRoot[hero.position]:SetActive(true)
        local heroData = formation.team[i]
        Util.GetGameObject(teamRoot[hero.position], "lvbg/levelText"):GetComponent("Text").text = heroData.level
        local demonId = heroData.heroTid
        local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, demonId)
        this.SetHeroData(teamRoot[heroData.position],heroConfig,heroData)
        table.insert(choosedList, {heroId = demonId, position = heroData.position})
    end
    local _show = {}
    if isBlue then
        _show = this.myTeamSub
    else
        _show = this.herTeamSub
    end

    local tibuId = {
        id = allDate.substituteTid,
        level = allDate.substituteLevel,
        star = allDate.substituteStar 
    }
    if tibuId.id ~= 0 and tibuId.id ~= nil then
        Util.GetGameObject(_show, "hero"):SetActive(true)
        local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, tibuId.id)
        Util.GetGameObject(_show, "lvbg/levelText"):GetComponent("Text").text =  tibuId.level-- 没有参数
        this.SetHeroData(_show,heroConfig,tibuId) -- 只有一个字段
    else
        Util.GetGameObject(_show, "hero"):SetActive(false)
    end

    local type = 1
    if not isBlue then
        type = 2
    end
    this.UpdateElementIcon(type, choosedList)
end

--[[
--根据前端数据显示编队  来自formationmanager的数据
function this.FreshTeam2(formation,formationId, isBlue)
    local teamRoot = isBlue and this.myTeams or this.herTeams
    local choosedList = {}
    --> 重置
    for i = 1, 9 do
        Util.GetGameObject(teamRoot[i], "frame"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
    end
    for i, demon in ipairs(teamRoot) do
        if formation.teamPokemonInfos[i] then
            Util.GetGameObject(demon, "frame"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
        else
            Util.GetGameObject(demon, "hero"):SetActive(false)
        end
    end
    local formationConfig = ConfigManager.GetConfigData(ConfigName.FormationConfig,formationId)
    for key, value in ipairs(formationConfig.pos) do
        Util.GetGameObject(teamRoot[value], "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(1))
    end
    for i, hero in ipairs(formation.teamHeroInfos) do
        local heroGo = Util.GetGameObject(teamRoot[formation.teamHeroInfos[i].position], "hero")
        heroGo:SetActive(true)
        local heroData = HeroManager.GetSingleHeroData(formation.teamHeroInfos[i].heroId)
        local heroConfig = heroData.heroConfig
        Util.GetGameObject(heroGo, "lvbg/levelText"):GetComponent("Text").text = heroData.lv
        this.SetHeroData(teamRoot[formation.teamHeroInfos[i].position],heroConfig,heroData)
        table.insert(choosedList, {heroId = heroConfig.Id,position = hero.position})
    end
    local _show = {}
    if isBlue then
        _show = this.myTeamSub
    else
        _show = this.herTeamSub
    end
    local _lv = 1
    local _star = 1
    local _id = 0
    if formation.substitute ~= nil and formation.substitute ~= 0 then
        local hero = HeroManager.GetSingleHeroDataByDynamicId(formation.substitute)
        if hero ~= nil then
            _lv = hero.lv
            _star = hero.star
            _id = hero.id
        end
    end
    local tibuId = {
        id = _id ,
        level = _lv,
        star = _star
    }
    if tibuId.id ~= 0 and tibuId.id ~= nil then
         Util.GetGameObject(_show, "hero"):SetActive(true)
        local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, tibuId.id)
        Util.GetGameObject(_show, "lvbg/levelText"):GetComponent("Text").text =  tibuId.level-- 没有参数
        this.SetHeroData(_show,heroConfig,tibuId) -- 只有一个字段
    else
        Util.GetGameObject(_show, "hero"):SetActive(false)
    end

    this.UpdateElementIcon(2,choosedList)
end
]]

function this.SetHeroData(item, Config, data)
    local heroGo = Util.GetGameObject(item, "hero")
    heroGo:SetActive(true)
    ClearChild(Util.GetGameObject(heroGo, "starGrid"))
    SetHeroStars(Util.GetGameObject(heroGo, "starGrid"), data.star)
    Util.GetGameObject(item, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(Config.Quality,data.star))
    -- Util.GetGameObject(heroGo, "lvbg/levelText"):GetComponent("Text").text = data.level
    Util.GetGameObject(heroGo, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(Config.Icon))
    Util.GetGameObject(heroGo, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(Config.PropertyName))
    Util.GetGameObject(heroGo, "proIconBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(Config.Quality,data.star))
    Util.GetGameObject(heroGo, "lvbg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(Config.Quality,data.star))
end

-- 控制显示编队信息
--- @showType 0 = both hide; 1 = show me and hide bitch; 2 = show bitch and hide me
function this.SetFormationShow(showType, showFormat)
    this.rootPanel:SetActive(true)
    this.herTeam:SetActive(showType == 2)
    this.herTeam:SetActive(showType == 1)
    this.infoPanel:SetActive(showFormat)
end

function this.UpdateElementIcon(type,choosedList)
    local elementIds = {}
    for _, v in ipairs(choosedList) do
        local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig,v.heroId)
        local countryId = heroConfig.PropertyName
        table.insert(elementIds, countryId)
    end
    if type == 1 then
        SetFormationBuffIcon(this.myZhenBuff, elementIds)
    else
        SetFormationBuffIcon(this.otherZhenBuff, elementIds)
    end
end

return this