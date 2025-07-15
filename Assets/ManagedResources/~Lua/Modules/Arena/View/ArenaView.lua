local ArenaView = {}
local this = ArenaView
local rewardBoxBtn = {}
local arenaBattleReward = ConfigManager.GetConfig(ConfigName.ArenaBattleReward)
--初始化组件（用于子类重写）
function ArenaView:InitComponent()
    this.ArenaName = Util.GetGameObject(self.gameObject, "name")
    this.ArenaTime = Util.GetGameObject(self.gameObject, "time")
    this.Integral = Util.GetGameObject(self.gameObject, "integral")
    this.WinNums = Util.GetGameObject(self.gameObject, "winNum")
    this.FailNums = Util.GetGameObject(self.gameObject, "loseNum")
    this.WinRate = Util.GetGameObject(self.gameObject, "winRate")
    this.AllNums = Util.GetGameObject(self.gameObject, "allNum")
   -- this.HelpBtn=Util.GetGameObject(self.gameObject,"btn")

    this.FormationBtn = Util.GetGameObject(self.gameObject, "formationBtn")
    --this.DiffDemons = {}
    --for i = 1, 3 do
    --    table.insert(this.DiffDemons, Util.GetGameObject(self.gameObject, "diffdemons/icon_"..i))
    --end
    this.Demons = {}
    for i = 1, 6 do
        table.insert(this.Demons, Util.GetGameObject(self.gameObject, "defendbox/Demons/heroPro (" .. i .. ")"))
    end

    this.Enemys = {}
    for i = 1, 3 do
        table.insert(this.Enemys, Util.GetGameObject(self.gameObject, "challengebox/enemy_"..i))
    end


    this.RecordBtn = Util.GetGameObject(self.gameObject, "record")
    this.RefreshBtn = Util.GetGameObject(self.gameObject, "refresh")
    this.sortBtn = Util.GetGameObject(self.gameObject, "sortBtn")
    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition

    this.myRank=Util.GetGameObject(self.gameObject,"MyRank")
    this.rank=Util.GetGameObject(this.myRank,"Rank"):GetComponent("Text")
    this.power=Util.GetGameObject(this.myRank,"Power"):GetComponent("Text")
    --this.formationPower=Util.GetGameObject(self.gameObject,"defendbox/FormationPower/Text"):GetComponent("Text")

    -- this.effect = Util.GetGameObject(self.gameObject, "bg/UI_effect_ArenaMainPanel_particle")
    --宝箱部分
    this.progressImage = Util.GetGameObject(self.gameObject, "finalTarget/progressbar/progress"):GetComponent("Image")
    -- this.progressText = Util.GetGameObject(self.gameObject, "finalTarget/curProgress/Text"):GetComponent("Text")
    this.progressTipText = Util.GetGameObject(self.gameObject, "finalTarget/Text (1)"):GetComponent("Text")
    rewardBoxBtn = {}
    for i = 1, 7 do
        rewardBoxBtn[i] = Util.GetGameObject(self.gameObject, "finalTarget/rewardProgress/rewardBoxBtn (" .. i .. ")")
        rewardBoxBtn[i].transform.localPosition = Vector3.New(arenaBattleReward[i].Position[1], arenaBattleReward[i].Position[2] ,0)
    end
end

--绑定事件（用于子类重写）
function ArenaView:BindEvent()
    -- 防守编队
    Util.AddClick(this.FormationBtn, function()
        
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
            PopupTipPanel.ShowTipByLanguageId(10082)
            return
        end
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ARENA_DEFEND)
    end)

    -- 挑战按钮
    for i, enemy in ipairs(this.Enemys) do
        local challengeBtn = Util.GetGameObject(enemy, "challenge")
        Util.AddClick(challengeBtn, function()
            if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
                PopupTipPanel.ShowTipByLanguageId(10082)
                return
            end
            -- 只在活动时间范围内可点
            if ArenaManager.GetLeftTime() > 0 then
                -- 添加次数限制
                local leftTimes = ArenaManager.GetArenaChallengeTimes()
                if leftTimes <= 0 then
                    local itemId, needNum = ArenaManager.GetArenaChallengeCost()
                    local haveNum = BagManager.GetItemCountById(itemId)
                    if haveNum < needNum then
                        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.ChallengeTicket })
                        PopupTipPanel.ShowTipByLanguageId(10085)
                        return
                    end
                end
                -- 敌方数据获取
                local EnemyList = ArenaManager.GetEnemyList()
                if EnemyList[i] then
                    -- UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ARENA_ATTACK, i)
                    --直接主线阵容进战斗
                    -- 请求开始挑战
                    local isSkip = 0--ArenaManager.IsSkipFight() and 1 or 0
                    ArenaManager.RequestArenaChallenge(i, isSkip)
                end
            else
                PopupTipPanel.ShowTipByLanguageId(10100)
            end
        end)
    end
    --排行
    Util.AddClick(this.sortBtn, function()
        UIManager.OpenPanel(UIName.RankingSingleListPanel,RankKingList[6])
    end)
    -- 刷新按钮
    Util.AddClick(this.RefreshBtn, function()
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
            PopupTipPanel.ShowTipByLanguageId(10082)
            return
        end
        ArenaManager.RequestNewArenaEnemy()
    end)
    -- 记录按钮
    Util.AddClick(this.RecordBtn, function()
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
            PopupTipPanel.ShowTipByLanguageId(10082)
            return
        end
        UIManager.OpenPanel(UIName.ArenaRecordPopup)
        ResetServerRedPointStatus(RedPointType.Arena_Record)
    end)
    -- 帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Arena,this.helpPosition.x,this.helpPosition.y)
    end)
end

--添加事件监听（用于子类重写）
function ArenaView:AddListener()
    --Game.GlobalEvent:AddEvent(GameEvent.Formation.OnFormationChange, this.RefreshDefendFormation)
    Game.GlobalEvent:AddEvent(GameEvent.Arena.OnBaseDataChange, this.RefreshBaseData)
    Game.GlobalEvent:AddEvent(GameEvent.Arena.OnBaseDataChange, this.RefreshEnemyData)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.RefreshEnemyData)

    Game.GlobalEvent:AddEvent(GameEvent.Arena.OnRankDataChange, this.RefreshRankInfo)
    -- 绑定红点
    BindRedPointObject(RedPointType.Arena_Record, Util.GetGameObject(self.gameObject, "record/redpot"))
end

--移除事件监听（用于子类重写）
function ArenaView:RemoveListener()
    --Game.GlobalEvent:RemoveEvent(GameEvent.Formation.OnFormationChange, this.RefreshDefendFormation)
    Game.GlobalEvent:RemoveEvent(GameEvent.Arena.OnBaseDataChange, this.RefreshBaseData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Arena.OnBaseDataChange, this.RefreshEnemyData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.RefreshEnemyData)

    Game.GlobalEvent:RemoveEvent(GameEvent.Arena.OnRankDataChange, this.RefreshRankInfo)
    -- 清除红点
    ClearRedPointObject(RedPointType.Arena_Record)
end

--界面打开时调用（用于子类重写）
function ArenaView:OnOpen(...)
    this.RefreshBaseData()

    this.RefreshEnemyData()

    --this.RefreshDefendFormation()

    this.StartCountTime()

    this.RefreshRankInfo()

    this.ShowRewardBoxProgressData()
    -- 延迟刷新一遍数据，避免来回切换页签，向服务器不停发数据
    if this.delayRefresh then return end
    --
    NetManager.RequestBaseArenaData()
    -- 刷新排名数据
    ArenaManager.RequestNextPageRank(true)
    this.delayRefresh = Timer.New(function()
        this.delayRefresh = nil
    end, 1)
    this.delayRefresh:Start()
end

-- 刷新排名信息
function this.RefreshRankInfo()
    local _, myRankInfo = ArenaManager.GetRankInfo()
    local myRank = myRankInfo.personInfo.rank
    if myRank<0 then
        myRank=GetLanguageStrById(10041)
    end
    this.rank.text=GetLanguageStrById(10101)..myRank.."</color>"
    this.power.text=GetLanguageStrById(10102)..myRankInfo.personInfo.totalForce.."</color>"
end

-- 刷新防守编队显示(暂时无效)
function this.RefreshDefendFormation()
    return
    local formation = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_ARENA_DEFEND)
    for i, demon in ipairs(this.Demons) do
        Util.GetGameObject(demon, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(1))
        Util.GetGameObject(demon, "hero"):SetActive(false)
    end
    for i, hero in ipairs(formation.teamHeroInfos) do
        local heroData = HeroManager.GetSingleHeroData(hero.heroId)
        local heroGo = Util.GetGameObject(this.Demons[hero.position], "hero")
        heroGo:SetActive(true)
        Util.GetGameObject(heroGo, "lvbg/levelText"):GetComponent("Text").text = heroData.lv
        SetHeroStars(Util.GetGameObject(heroGo, "starGrid"), heroData.star)
        local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroData.id)
        Util.GetGameObject(this.Demons[hero.position], "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(heroConfig.Quality, heroData.star))
        Util.GetGameObject(heroGo, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
        Util.GetGameObject(heroGo, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
    end


    --for i, demon in ipairs(this.Demons) do
    --    if formation.teamHeroInfos[i] then
    --        demon:SetActive(true)
    --        local demonId = formation.teamHeroInfos[i].heroId
    --        local demonData = HeroManager.GetSingleHeroData(demonId)
    --        demon:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(demonData.heroConfig.Quality))
    --        Util.GetGameObject(demon, "icon"):GetComponent("Image").sprite = Util.LoadSprite(demonData.icon)
    --    else
    --        demon:SetActive(false)
    --    end
    --end

    -- 异妖
    --for i, diffDemon in ipairs(this.DiffDemons) do
    --    if formation.teamPokemonInfos[i] then
    --        diffDemon:SetActive(true)
    --        local demonId = formation.teamPokemonInfos[i].pokemonId
    --        ---TODO:  异妖条状头像资源未配置，配置后增加根据ID获取资源名称
    --        local resId = ConfigManager.GetConfigData(ConfigName.DifferDemonsConfig, demonId).LiveIcon
    --        diffDemon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(resId))
    --    else
    --        diffDemon:SetActive(false)
    --    end
    --end
end

-- 刷新基础数据显示
function this.RefreshBaseData()
    this.ArenaName:GetComponent("Text").text = ArenaManager.GetArenaName()
    local baseData = ArenaManager.GetArenaBaseData()
    local allNums = baseData.successNums + baseData.failNums
    local rate = 0
    if allNums ~= 0 then
        rate = math.floor(baseData.successNums / allNums * 100)
    end
    this.Integral:GetComponent("Text").text = baseData.score
    this.AllNums:GetComponent("Text").text = allNums
    this.WinNums:GetComponent("Text").text = baseData.successNums
    this.FailNums:GetComponent("Text").text = baseData.failNums
    this.WinRate:GetComponent("Text").text = "("..rate.."%)"
end


-- 开始计时
function this.StartCountTime()
    if this.TimeCounter then return end
    local function _TimeUpdate()
        local leftTime = ArenaManager.GetLeftTime()
        this.ArenaTime:GetComponent("Text").text = TimeToHMS(leftTime)
    end
    _TimeUpdate()
    this.TimeCounter = Timer.New(_TimeUpdate, 1, -1, true)
    this.TimeCounter:Start()
end


-- 刷新敌人列表
function this.RefreshEnemyData()
    local leftTimes = ArenaManager.GetArenaChallengeTimes()
    local EnemyList = ArenaManager.GetEnemyList()
    for i, node in ipairs(this.Enemys) do
        if EnemyList[i] then
            node:SetActive(true)
            local lv_name = Util.GetGameObject(node, "name")
            local integral = Util.GetGameObject(node, "integral")
            local power = Util.GetGameObject(node, "power")
            local headroot = Util.GetGameObject(node, "headroot")
            local bg = Util.GetGameObject(node, "bg")
            local btnText = Util.GetGameObject(node, "challenge/Text"):GetComponent("Text")
            local btnItem = Util.GetGameObject(node, "challenge/item"):GetComponent("Image")
            local btnItemNum = Util.GetGameObject(node, "challenge/item/num"):GetComponent("Text")

            lv_name:GetComponent("Text").text = EnemyList[i].personInfo.name
            integral:GetComponent("Text").text = EnemyList[i].personInfo.score
            power:GetComponent("Text").text = EnemyList[i].personInfo.totalForce
            btnText.gameObject:SetActive(leftTimes > 0)
            btnText.text = GetLanguageStrById(10103)

            btnItem.gameObject:SetActive(leftTimes <= 0)
            if leftTimes <= 0 then
                local itemId, needNum = ArenaManager.GetArenaChallengeCost()
                local haveNum = BagManager.GetItemCountById(itemId)
                btnItem.sprite = SetIcon(itemId)
                btnItemNum.text = "×"..needNum
                btnItemNum.color = haveNum < needNum and UIColor.NOT_ENOUGH_RED or UIColor.BTN_TEXT
            end

            if not this.HeadList then
                this.HeadList = {}
            end
            if not this.HeadList[i] then
                this.HeadList[i] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headroot.transform)
            end
            this.HeadList[i]:Reset()
            this.HeadList[i]:SetHead(EnemyList[i].personInfo.head)
            this.HeadList[i]:SetFrame(EnemyList[i].personInfo.headFrame)
            this.HeadList[i]:SetLevel(EnemyList[i].personInfo.level)
            this.HeadList[i]:SetScale(Vector3.one*0.8)

            Util.AddOnceClick(bg, function()
                UIManager.OpenPanel(UIName.PlayerInfoPopup, EnemyList[i].personInfo.uid, PLAYER_INFO_VIEW_TYPE.ARENA)
            end)
        else
            node:SetActive(false)
        end
    end
end

--显示上边积分奖励
function this.ShowRewardBoxProgressData()
    local baseData = ArenaManager.GetArenaBaseData()
    local allNums = baseData.successNums + baseData.failNums
    local allBoxGetState = ArenaManager.GetHadTakeBoxData()
    local maxNum = 0

    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.ArenaBattleReward)) do
       if configInfo.BattleTimes > maxNum then
        maxNum = configInfo.BattleTimes
       end
    end
    local arenaBattleReward = ConfigManager.GetConfig(ConfigName.ArenaBattleReward)
    for i = 1, #rewardBoxBtn  do
        if arenaBattleReward[i] then
            local state = 1--1 未完成 2 未领取 3 已完成allNums >= arenaBattleReward[i].BattleTimes and false
            if allNums < arenaBattleReward[i].BattleTimes then
                state = 1
            elseif  allNums >= arenaBattleReward[i].BattleTimes and not allBoxGetState[i] then
                state = 2
            else
                state = 3
            end
            Util.GetGameObject(rewardBoxBtn[i], "redPoint"):SetActive(state == 2)
            Util.GetGameObject(rewardBoxBtn[i], "Text"):GetComponent("Text").text = arenaBattleReward[i].BattleTimes..GetLanguageStrById(10054)
            Util.GetGameObject(rewardBoxBtn[i], "getFinish"):SetActive(state == 3)
            Util.AddOnceClick(rewardBoxBtn[i], function()
                if state == 1 then
                    UIManager.OpenPanel(UIName.BoxRewardShowPopup,arenaBattleReward[i].Reward,rewardBoxBtn[i].transform.localPosition.x,-937,arenaBattleReward[i].BattleTimes .. GetLanguageStrById(12205))
                    return
                elseif state == 3 then
                    PopupTipPanel.ShowTipByLanguageId(10350)
                    return
                elseif state == 2 then
                    NetManager.TakeArenaBattleRewardRequest(i, function(msg)
                        UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function ()
                            this.ShowRewardBoxProgressData()
                        end)
                    end)
                end
            end)
        end
    end
    this.progressImage.fillAmount = allNums/maxNum
    -- this.progressText.text = allNums
    this.progressTipText.text = GetLanguageStrById(12204)
end
-- 层级改变回调
local orginLayer = 0
function ArenaView:OnSortingOrderChange(sort)
    -- Util.AddParticleSortLayer(this.effect, sort - orginLayer)
    orginLayer = sort
end

--界面关闭时调用（用于子类重写）
function ArenaView:OnClose()
    if this.TimeCounter then
        this.TimeCounter:Stop()
        this.TimeCounter = nil
    end
end

function ArenaView:OnDestroy()
    for _, head in ipairs(this.HeadList) do
        head:Recycle()
    end
    this.HeadList= nil
end
return ArenaView