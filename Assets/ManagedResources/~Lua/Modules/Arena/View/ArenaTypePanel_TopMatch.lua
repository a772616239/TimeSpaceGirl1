local this = {}
local sortingOrder = 0
local HeroStarBackConfig = ConfigManager.GetConfig(ConfigName.HeroStarBackConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local HeroLevelConfig = ConfigManager.GetConfig(ConfigName.HeroLevelConfig)
local HeroRankupConfig = ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
local selectData
local itemList = {}
local itemDefultList = {}

local btnLikeList = {}

function this:InitComponent(gameObject)
    this.TopMatch = Util.GetGameObject(gameObject, "ArenaTypePanel_TopMatch")
    --this.TopMatch_Name = Util.GetGameObject(this.TopMatch, "Name"):GetComponent("Text")
    this.TopMatch_Season = Util.GetGameObject(this.TopMatch, "bgDown/Season/Text"):GetComponent("Text")
    this.TopMatch_SeasonTime = Util.GetGameObject(this.TopMatch, "bgDown/Season/Time"):GetComponent("Text")
    this.TopMatch_Stage = Util.GetGameObject(this.TopMatch, "bgDown/Stage/Text"):GetComponent("Text")
    this.TopMatch_Rank = Util.GetGameObject(this.TopMatch, "bgDown/MyRank/Text"):GetComponent("Text")
    this.TopMatch_BestRank = Util.GetGameObject(this.TopMatch, "bgDown/BestRank/Text"):GetComponent("Text")
    this.TopMatch_btnEnter = Util.GetGameObject(this.TopMatch, "btnEnter")
    this.TopMatch_btnRank = Util.GetGameObject(this.TopMatch,"btnRank")
    this.btnRankRedpoint = Util.GetGameObject(this.TopMatch,"btnRank/redpoint")
   
    --获取帮助按钮
    this.HelpBtn = Util.GetGameObject(gameObject,"HelpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition

    --前三名数据显示
    this.first = Util.GetGameObject(this.TopMatch,"bg/flagRed/domain")
    this.firstFrame = Util.GetGameObject(this.first,"frame")
    this.firstIcon = Util.GetGameObject(this.first,"icon")
    this.firstName = Util.GetGameObject(this.first,"name/Text")
    this.firstBtn = Util.GetGameObject(this.first,"btnAdd")
    this.firstIBtnText = Util.GetGameObject(this.first,"btnAdd/Text")

    this.second = Util.GetGameObject(this.TopMatch,"bg/flagYellow/domain")
    this.secondFrame = Util.GetGameObject(this.second,"frame")
    this.secondIcon = Util.GetGameObject(this.second,"icon")
    this.secondName = Util.GetGameObject(this.second,"name/Text")
    this.secondBtn = Util.GetGameObject(this.second,"btnAdd")
    this.secondIBtnText = Util.GetGameObject(this.second,"btnAdd/Text")

    this.third = Util.GetGameObject(this.TopMatch,"bg/flagPurple/domain")
    this.thirdFrame = Util.GetGameObject(this.third,"frame")
    this.thirdIcon = Util.GetGameObject(this.third,"icon")
    this.thirdName = Util.GetGameObject(this.third,"name/Text")
    this.thirdtBtn = Util.GetGameObject(this.third,"btnAdd")
    this.thirdIBtnText = Util.GetGameObject(this.third,"btnAdd/Text")
 
    this.tableTopThree = {
        [1] = {heroFrame = this.firstFrame, heroIcon = this.firstIcon,playerName = this.firstName,addBtn = this.firstBtn},
        [2] = {heroFrame = this.secondFrame,heroIcon = this.secondIcon,playerName = this.secondName,addBtn = this.secondBtn},
        [3] = {heroFrame = this.thirdFrame,heroIcon = this.thirdIcon,playerName = this.thirdName,addBtn = this.thirdtBtn}, 
    }
end

function this:BindEvent()
    Util.AddClick(this.TopMatch_btnEnter, function()
        UIManager.OpenPanel(UIName.ArenaTopMatchPanel)
    end)
    Util.AddClick(this.TopMatch_btnRank, function()
        UIManager.OpenPanel(UIName.ATM_RankViewPanel)
    end)
    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.ArenaTypePanelTopMatch,this.helpPosition.x-30, this.helpPosition.y+1300)
    end)

    BindRedPointObject(RedPointType.ArenaTodayAlreadyLike, this.btnRankRedpoint)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshTopMatchShow)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshTopMatchShow)
end

local sortingOrder = 0
function this:OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
end

function this:OnShow(...)
    sortingOrder = 0
     -- 巅峰战
    ArenaTopMatchManager.RequestTopMatchBaseInfo(function()
        this.RefreshTopMatchShow()
        -- 计时器
        if this.TimeCounter then return end
        this.TimeCounter = Timer.New(this.TimeUpdate, 1, -1, true)
        this.TimeCounter:Start()
        this.TimeUpdate()
    end)
    do
        this.showRank()
    end
end

function this:OnClose()
    ClearRedPointObject(RedPointType.ArenaTodayAlreadyLike, this.btnRankRedpoint)
end

function this:OnDestroy()
    if this.TimeCounter then
        this.TimeCounter:Stop()
        this.TimeCounter = nil
    end

    btnLikeList = {}
end

-- 刷新巅峰战显示
function this.RefreshTopMatchShow()
    local tmData = ArenaTopMatchManager.GetBaseData()
    local titleName, stageName = ArenaTopMatchManager.GetCurTopMatchName()
    --this.TopMatch_Name.text = titleName
    this.TopMatch_Stage.text = stageName
    this.TopMatch_Rank.text = tmData.myrank <= 0 and GetLanguageStrById(10041) or ArenaTopMatchManager.GetRankNameByRank(tmData.myrank)
    this.TopMatch_BestRank.text = tmData.maxRank <= 0 and GetLanguageStrById(10094) or this.GetRankName(tmData.maxRank)

    local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.TOP_MATCH)
    local startDate = os.date("%m.%d", serData.startTime)
    local endDate = os.date("%m.%d", serData.endTime)
    this.TopMatch_Season.text = string.format("%s - %s", startDate, endDate)
end

-- 获取我得排名信息
function this.GetRankName(rank)
    if rank == 1 then
        return GetLanguageStrById(10095)
    elseif rank == 2 then
        return GetLanguageStrById(10096)
    else
        local maxTurn = ArenaTopMatchManager.GetEliminationMaxRound()
        for i = 1, maxTurn do
            if i == maxTurn then
                local config = ConfigManager.GetConfigData(ConfigName.ChampionshipSetting, 1)
                return config.ChampionshipPlayer..GetLanguageStrById(10097)
            end
            if rank > math.pow(2, i) and rank <= math.pow(2, i+1) then
                return (i+1)..GetLanguageStrById(10097)
            end
        end
    end
end
--
function this.TimeUpdate()
    local leftTime = ArenaManager.GetLeftTime()
    if leftTime <= 0 then
        this.RefreshArenaShow()
    end
    --this.Arena_SeasonTime.text = string.format(GetLanguageStrById(10098), TimeToHMS(leftTime))--!!!!!!!!!!!!!!!!!!!!!!!!!!!

    local isActive = ArenaTopMatchManager.IsTopMatchActive()
    local startTime, endTime = ArenaTopMatchManager.GetTopMatchTime()
    if isActive then
        local leftTime = endTime - GetTimeStamp()
        if leftTime <= 0 then
            this.RefreshTopMatchShow()
        end
        this.TopMatch_SeasonTime.text = string.format(GetLanguageStrById(10098), TimeToHMS(leftTime))
    else
        local leftTime = startTime - GetTimeStamp()
        if leftTime <= 0 then
            this.RefreshTopMatchShow()
            this.TopMatch_SeasonTime.text = ""
        else
            this.TopMatch_SeasonTime.text = string.format(GetLanguageStrById(10099), TimeToHMS(leftTime))
        end
    end
end

function this.showRank()
    ArenaTopMatchManager.RequestRankData(1,function ()            
        local rankData ,myRankData = ArenaTopMatchManager.GetRankData()
        for i = 1, 3 do
            if rankData[i] then
                btnLikeList[rankData[i].uid] = this.tableTopThree[i].addBtn
                this.tableTopThree[i].playerName:GetComponent("Text").text = GetLanguageStrById(rankData[i].name)
                this.tableTopThree[i].heroFrame:GetComponent("Image").sprite = GetPlayerHeadFrameSprite(rankData[i].headFrame)
                this.tableTopThree[i].heroIcon:GetComponent("Image").sprite = GetPlayerHeadSprite(rankData[i].head)

                Util.GetGameObject(this.tableTopThree[i].addBtn,"Text"):GetComponent("Text").text = rankData[i].likeNums
                if rankData[i].uid < 10000000 then
                    this.tableTopThree[i].addBtn.gameObject:SetActive(false)
                else
                    this.tableTopThree[i].addBtn.gameObject:SetActive(true)
                end
                Util.AddOnceClick(this.tableTopThree[i].heroIcon, function ()
                    UIManager.OpenPanel(UIName.PlayerInfoPopup, rankData[i].uid)
                end)
                Util.AddOnceClick(this.tableTopThree[i].addBtn,function()
                    this.btnText = Util.GetGameObject(this.tableTopThree[i].addBtn,"Text"):GetComponent("Text")
                    if ArenaTopMatchManager.CheckTodayIsAlreadyLike(rankData[i].uid) then
                        PopupTipPanel.ShowTipByLanguageId(50357)
                        return
                    end
                    NetManager.ArenaTopMatchLikeRequest(rankData[i].uid,function()
                        -- this.LikeBtnState()
                        rankData[i].likeNums = rankData[i].likeNums + 1
                        this.btnText:GetComponent("Text").text = rankData[i].likeNums
                        PopupTipPanel.ShowTipByLanguageId(12579)
                        this.tableTopThree[i].addBtn:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[2])
                    end)
                end)
            else
                this.tableTopThree[i].heroIcon.gameObject:SetActive(false)
                this.tableTopThree[i].playerName:GetComponent("Text").text = GetLanguageStrById(12406)
                this.tableTopThree[i].addBtn.gameObject:SetActive(false)
            end
        end
        this.LikeBtnState()
    end)
end

function this.GetHeroInfo(playerUid,index)
    NetManager.RequestPlayerInfo(playerUid, FormationTypeDef.FORMATION_ARENA_DEFEND, function(msg)         
        local teamInfo = msg.teamInfo.team
        this.FormationAdapter(playerUid,teamInfo,index)
    end)
end

function this.FormationAdapter(playerId,teamInfo,index)    
    local demonId
    local heroForce = 0
    local num = 0
    local numIndex = 0
    for i, hero in ipairs(teamInfo.team) do
        if hero.heroid then
            num = num + 1
        end
    end
    for i, hero in ipairs(teamInfo.team) do
        if hero.heroid then
            NetManager.ViewHeroInfoRequest(playerId,hero.heroid,function(msg)                
                if msg.force >= heroForce then
                    heroForce = msg.force
                    demonId = hero.heroTid
                end
                numIndex = numIndex + 1
                if num == numIndex then
                    if demonId then
                        local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, demonId)                       
                        this.tableTopThree[index].heroIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
                        this.tableTopThree[index].heroIcon.gameObject:SetActive(true)
                    end
                end
            end)
        end
    end
end

function this.LikeBtnState()
    ArenaTopMatchManager.RequestTodayAlreadyLikeUids_TopMatch(function(msg)
        local alreadyLike = msg.uid
        for k, v in pairs(btnLikeList) do
            local isAlreadyLike = false
            for i = 1, #alreadyLike do
                if alreadyLike[i] == k then
                    isAlreadyLike = true
                end
            end
            Util.SetGray(v, isAlreadyLike)

            if isAlreadyLike then
                v:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[2])
            else
                v:GetComponent("Image").sprite = Util.LoadSprite(Thumbsup[1])
            end
        end
    end)

end
return this