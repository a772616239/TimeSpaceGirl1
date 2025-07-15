local ArenaMainPanel_ArenaView = {}
local this = ArenaMainPanel_ArenaView
local rewardBoxBtn = {}
local arenaBattleReward = ConfigManager.GetConfig(ConfigName.ArenaBattleReward)
--local BattleView = require("Modules/Battle/View/BattleView")
local isJump = false--是否跳过
local isFistChallenge = true--是否挑战

--初始化组件（用于子类重写）
function ArenaMainPanel_ArenaView:InitComponent()
    this.Enemys = {}
    for i = 1, 3 do
        table.insert(this.Enemys, Util.GetGameObject(self.gameObject, "challengebox/enemy_"..i))
    end

    this.btnShop = Util.GetGameObject(self.gameObject, "btnShop")--商店
    this.btnRecord = Util.GetGameObject(self.gameObject, "btnRecord")--防守记录
    this.btnHelp = Util.GetGameObject(self.gameObject, "btnHelp")--帮助
    this.helpPosition = this.btnHelp:GetComponent("RectTransform").localPosition

    this.btnJump = Util.GetGameObject(self.gameObject, "btnJump")
    this.btnJumpChoose = Util.GetGameObject(self.gameObject, "btnJump/choose")
    this.btnJumpChoose:SetActive(false)
    this.btnRefresh = Util.GetGameObject(self.gameObject, "btnRefresh")--刷新
    this.btnFormation = Util.GetGameObject(self.gameObject, "btnFormation")--防守阵容

    this.myRank = Util.GetGameObject(self.gameObject,"MyRank")
    this.rank = Util.GetGameObject(this.myRank,"Rank"):GetComponent("Text")--排名
    this.Integral = Util.GetGameObject(this.myRank, "integral")--积分

    --宝箱部分
    local finalTargetShow = Util.GetGameObject(self.gameObject, "finalTargetShow")
    this.btnOpen = Util.GetGameObject(finalTargetShow, "btnOpen")
    this.progressImageShow = Util.GetGameObject(finalTargetShow, "progressbar/progress"):GetComponent("Image")
    this.progressTextShow = Util.GetGameObject(finalTargetShow, "value"):GetComponent("Text")

    this.finalTarget = Util.GetGameObject(self.gameObject, "finalTarget")
    this.btnClose = Util.GetGameObject(this.finalTarget, "btnClose")
    this.ArenaTime = Util.GetGameObject(this.finalTarget, "time")
    this.progressImage = Util.GetGameObject(this.finalTarget, "progressbar/progress"):GetComponent("Image")
    this.progressText = Util.GetGameObject(this.finalTarget, "value"):GetComponent("Text")
    rewardBoxBtn = {}
    for i = 1, 7 do
        rewardBoxBtn[i] = Util.GetGameObject(this.finalTarget, "rewardProgress/rewardBoxBtn (" .. i .. ")")
        rewardBoxBtn[i].transform.localPosition = Vector3.New(arenaBattleReward[i].Position[1], arenaBattleReward[i].Position[2] ,0)
    end
end

--绑定事件（用于子类重写）
function ArenaMainPanel_ArenaView:BindEvent()
    Util.AddClick(this.btnFormation, function()
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
            PopupTipPanel.ShowTipByLanguageId(10082)
            return
        end
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ARENA_DEFEND)
    end)

    for i, enemy in ipairs(this.Enemys) do
        local challengeBtn = Util.GetGameObject(enemy, "challenge")
        Util.AddClick(challengeBtn, function()
            if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
                PopupTipPanel.ShowTip(GetLanguageStrById(10082))
                return
            end
            if ArenaManager.GetLeftTime() > 0 then
                local leftTimes = ArenaManager.GetArenaChallengeTimes()
                if leftTimes <= 0 then
                    local itemId, needNum = ArenaManager.GetArenaChallengeCost()
                    if BagManager.GetItemCountById(itemId) < needNum then
                        PopupTipPanel.ShowTip(GetLanguageStrById(10085))
                        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.ChallengeTicket })
                        return
                    end
                end
            else
                PopupTipPanel.ShowTip(GetLanguageStrById(10100))
            end

            if BattleManager.IsInBackBattle() then
                return
            end

            if not isFistChallenge then
                return
            end
            isFistChallenge = false

            BattleManager.GotoFight(function()
                local EnemyList = ArenaManager.GetEnemyList()
                if EnemyList[i] then
                    --直接主线阵容进战斗
                    local isSkip = isJump and 1 or 0
                    ArenaManager.RequestArenaChallenge(i, isSkip, function ()
                        Timer.New(function ()
                            isFistChallenge = true
                        end,0.8):Start()
                    end)
                end
            end)
        end)
    end

    Util.AddClick(this.btnRefresh, function()
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
            PopupTipPanel.ShowTipByLanguageId(10082)
            return
        end
        ArenaManager.RequestNewArenaEnemy()
    end)
    Util.AddClick(this.btnRecord, function()
        if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
            PopupTipPanel.ShowTipByLanguageId(10082)
            return
        end
        UIManager.OpenPanel(UIName.ArenaRecordPopup)
        ResetServerRedPointStatus(RedPointType.Arena_Record)
    end)
    Util.AddClick(this.btnHelp, function()
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.Arena, this.helpPosition.x, this.helpPosition.y)
    end)
    Util.AddClick(this.btnJump, function ()
         if ArenaManager.CheckSkipFight() then
            isJump = not isJump
            if isJump then
                this.btnJumpChoose:SetActive(true)
            else
                this.btnJumpChoose:SetActive(false)
            end
        else
            PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.ArenaJump))
        end
    end)

    Util.AddClick(this.btnOpen, function ()
        this.finalTarget:SetActive(true)
    end)

    Util.AddClick(this.btnClose, function ()
        this.finalTarget:SetActive(false)
    end)
    Util.AddClick(this.btnShop, function ()
        UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.ARENA_SHOP)
    end)
end

--添加事件监听（用于子类重写）
function ArenaMainPanel_ArenaView:AddListener()
    --Game.GlobalEvent:AddEvent(GameEvent.Formation.OnFormationChange, this.RefreshDefendFormation)
    Game.GlobalEvent:AddEvent(GameEvent.Arena.OnBaseDataChange, this.RefreshBaseData)
    Game.GlobalEvent:AddEvent(GameEvent.Arena.OnBaseDataChange, this.RefreshEnemyData)
    Game.GlobalEvent:AddEvent(GameEvent.Arena.OnBaseDataChange, this.ShowRewardBoxProgressData)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.RefreshEnemyData)
    Game.GlobalEvent:AddEvent(GameEvent.Arena.OnRankDataChange, this.RefreshRankInfo)
    -- 绑定红点
    BindRedPointObject(RedPointType.Arena_Record, Util.GetGameObject(self.gameObject, "record/redpot"))
end

--移除事件监听（用于子类重写）
function ArenaMainPanel_ArenaView:RemoveListener()
    --Game.GlobalEvent:RemoveEvent(GameEvent.Formation.OnFormationChange, this.RefreshDefendFormation)
    Game.GlobalEvent:RemoveEvent(GameEvent.Arena.OnBaseDataChange, this.RefreshBaseData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Arena.OnBaseDataChange, this.RefreshEnemyData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Arena.OnBaseDataChange, this.ShowRewardBoxProgressData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.RefreshEnemyData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Arena.OnRankDataChange, this.RefreshRankInfo)
    -- 清除红点
    ClearRedPointObject(RedPointType.Arena_Record)
end

--界面打开时调用（用于子类重写）
function ArenaMainPanel_ArenaView:OnOpen(...)
    this.finalTarget:SetActive(false)
    isFistChallenge = true
    this.RefreshBaseData()
    this.RefreshEnemyData()
    --this.RefreshDefendFormation()
    this.StartCountTime()
    this.RefreshRankInfo()
    this.ShowRewardBoxProgressData()
    -- 延迟刷新一遍数据，避免来回切换页签，向服务器不停发数据
    if this.delayRefresh then return end
    NetManager.RequestBaseArenaData()
    -- 刷新排名数据
    ArenaManager.RequestNextPageRank(true)
    RankingManager.RequestNextArenaPageData()
    this.delayRefresh = Timer.New(function()
        this.delayRefresh = nil
    end, 1)
    this.delayRefresh:Start()
end

-- 刷新排名信息
function this.RefreshRankInfo()
    local _, myRankInfo = ArenaManager.GetRankInfo()
    local myRank = myRankInfo.personInfo.rank
    if myRank < 0 then
        myRank = GetLanguageStrById(10041)
    end
    this.rank.text = myRank
    -- this.power.text = GetLanguageStrById(10102)..myRankInfo.personInfo.totalForce.."</color>"
end

--[[
-- 刷新防守编队显示（暂时不用）
function this.RefreshDefendFormation()
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
]]

-- 刷新基础数据显示
function this.RefreshBaseData()
    local baseData = ArenaManager.GetArenaBaseData()
    this.Integral:GetComponent("Text").text = baseData.score
end

local day
local otherhour
-- 开始计时
function this.StartCountTime()
    if this.TimeCounter then return end
    local function _TimeUpdate()
        local leftTime = ArenaManager.GetLeftTime()
        local time, hour, min, sec = TimeToHMS(leftTime)
        if hour > 24 then
            otherhour = hour%24
            hour = hour - otherhour
            day = hour/24
            this.ArenaTime:GetComponent("Text").text = string.format(GetLanguageStrById(12573), day,otherhour, min, sec)
        else
            this.ArenaTime:GetComponent("Text").text = string.format("%02d:%02d:%02d",hour, min, sec)
        end
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
            local lv_name = Util.GetGameObject(node, "name"):GetComponent("Text")
            local integral = Util.GetGameObject(node, "integral"):GetComponent("Text")--积分
            local level = Util.GetGameObject(node, "level"):GetComponent("Text")--等级
            local power = Util.GetGameObject(node, "power"):GetComponent("Text")--战力
            local headroot = Util.GetGameObject(node, "headroot")
            local bg = Util.GetGameObject(node, "bg")
            local btnText = Util.GetGameObject(node, "challenge/Text"):GetComponent("Text")
            local Image_Free = Util.GetGameObject(node, "Image_Free")
            local btnItem = Util.GetGameObject(node, "item"):GetComponent("Image")
            local btnItemNum = Util.GetGameObject(node, "item/num"):GetComponent("Text")

            lv_name.text = SetRobotName(EnemyList[i].personInfo.uid, EnemyList[i].personInfo.name)
            integral.text = EnemyList[i].personInfo.score
            level.text = EnemyList[i].personInfo.level
            local str

            local myPower = FormationManager.GetMaxPowerForTeamID()
            if myPower > EnemyList[i].personInfo.totalForce then
                str = string.format("<color=#9fff88>%s</color>", EnemyList[i].personInfo.totalForce)
            else
                str = string.format("<color=#ff6868>%s</color>", EnemyList[i].personInfo.totalForce)
            end
            power.text = str
            btnText.text = GetLanguageStrById(10103)

            Image_Free:SetActive(leftTimes > 0)
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
            this.HeadList[i]:SetScale(0.8)

            Util.AddOnceClick(bg, function()
                UIManager.OpenPanel(UIName.PlayerInfoPopup, EnemyList[i].personInfo.uid, PLAYER_INFO_VIEW_TYPE.ARENA)
            end)
        else
            node:SetActive(false)
        end
    end
end

local showRewardItemView
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

    local state1Reward
    local state2Reward
    local state3Reward
    local state1RewardPos
    local state2RewardPos
    local state3RewardPos

    local arenaBattleReward = ConfigManager.GetConfig(ConfigName.ArenaBattleReward)
    for i = 1, #rewardBoxBtn  do
        if arenaBattleReward[i] then
            local state = 1--1 未完成 2 未领取 3 已完成allNums >= arenaBattleReward[i].BattleTimes and false
            if allNums < arenaBattleReward[i].BattleTimes then
                state = 1
                if state1Reward == nil then --记录第一个未完成的
                    state1Reward = arenaBattleReward[i].Reward
                    state1RewardPos = i
                end
            elseif  allNums >= arenaBattleReward[i].BattleTimes and not allBoxGetState[i] then
                state = 2
                if state2Reward == nil then --记录第一个未领取的
                    state2Reward = arenaBattleReward[i].Reward
                    state2RewardPos = i
                end
            else
                state = 3
                --记录最后一个已领取
                state3Reward = arenaBattleReward[i].Reward
                state3RewardPos = i
            end

            local itemData = ConfigManager.GetConfigData(ConfigName.ItemConfig, arenaBattleReward[i].Reward[1][1])
            Util.GetGameObject(rewardBoxBtn[i], "Image"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemData.Quantity))
            Util.GetGameObject(rewardBoxBtn[i], "Image_Icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
            Util.GetGameObject(rewardBoxBtn[i], "redPoint"):SetActive(state == 2)
            Util.GetGameObject(rewardBoxBtn[i], "Text"):GetComponent("Text").text = arenaBattleReward[i].BattleTimes
            Util.GetGameObject(rewardBoxBtn[i], "num"):GetComponent("Text").text = arenaBattleReward[i].Reward[1][2]

            if state == 3 then --已领取
                Util.SetGray(rewardBoxBtn[i], true)
            else
                Util.SetGray(rewardBoxBtn[i], false)
            end

            Util.AddOnceClick(rewardBoxBtn[i], function()
                if state == 1 then
                    local itemData = ConfigManager.GetConfigData(ConfigName.ItemConfig, arenaBattleReward[i].Reward[1][1])
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemData.Id, function()
                        -- this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                        UIManager.ClosePanel(UIName.RewardItemSingleShowPopup)
                    end)

                   --UIManager.OpenPanel(UIName.BoxRewardShowPopup,arenaBattleReward[i].Reward,rewardBoxBtn[i].transform.localPosition.x,0,arenaBattleReward[i].BattleTimes .. GetLanguageStrById(12205))
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
    this.progressImageShow.fillAmount = allNums/maxNum
    this.progressTextShow.text = "<size=60>" .. allNums .. "</size><size=42>/" .. maxNum .. "</size>"
    this.progressImage.fillAmount = allNums/maxNum
    this.progressText.text = "<size=60>" .. allNums .. "</size><size=42>/" .. maxNum .. "</size>"
    -- this.progressText.text = allNums
    -- this.progressTipText.text = GetLanguageStrById(12575)

    local Text_Times = Util.GetGameObject(this.gameObject, "finalTargetShow/Image_Reward/Text_Times"):GetComponent("Text")
    local ItemPos = Util.GetGameObject(this.gameObject, "finalTargetShow/Image_Reward/ItemPos")
    local Button_GetReward = Util.GetGameObject(this.gameObject, "finalTargetShow/Image_Reward/btnGetReward")
    local effect = Util.GetGameObject(this.gameObject, "finalTargetShow/Image_Reward/effect_red")
    --显示挑战奖励
    local showReward
    local showRewardPos
    local showRewardState
    if state2Reward ~= nil then
        showReward = state2Reward
        showRewardPos = state2RewardPos
        showRewardState = 2
    elseif state1Reward ~= nil then
        showReward = state1Reward
        showRewardPos = state1RewardPos
        showRewardState = 1
    else
        showReward = state3Reward
        showRewardPos = state3RewardPos
        showRewardState = 3
    end

    effect:SetActive(showRewardState == 2)
    Text_Times.text = string.format(GetLanguageStrById(22608), arenaBattleReward[showRewardPos].BattleTimes)

    if showRewardItemView == nil or showRewardItemView.gameObject == nil  then
        showRewardItemView = SubUIManager.Open(SubUIConfig.ItemView, ItemPos.transform)
    end
    showRewardItemView:OnOpen(false, {showReward[1][1], 0}, 0.8, false, false, false, this.sortingOrder)

    Util.AddOnceClick(Button_GetReward, function ()
        if showRewardState == 1 then
            local itemData = ConfigManager.GetConfigData(ConfigName.ItemConfig, arenaBattleReward[showRewardPos].Reward[1][1])
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemData.Id, function()
                -- this.OnClickTabBtn(sortIndex, sortIndexBtnGo)
                UIManager.ClosePanel(UIName.RewardItemSingleShowPopup)
            end)
            --UIManager.OpenPanel(UIName.BoxRewardShowPopup, arenaBattleReward[showRewardPos].Reward, 0, 0, arenaBattleReward[showRewardPos].BattleTimes .. GetLanguageStrById(12205))
            return
        elseif showRewardState == 3 then
            PopupTipPanel.ShowTipByLanguageId(10350)
            return
        elseif showRewardState == 2 then
            NetManager.TakeArenaBattleRewardRequest(showRewardPos, function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function ()
                    this.ShowRewardBoxProgressData()
                end)
            end)
        end
    end)
end

-- 层级改变回调
local orginLayer = 0
function ArenaMainPanel_ArenaView:OnSortingOrderChange(sort)
    -- Util.AddParticleSortLayer(this.effect, sort - orginLayer)
    orginLayer = sort
end

--界面关闭时调用（用于子类重写）
function ArenaMainPanel_ArenaView:OnClose()
    if this.TimeCounter then
        this.TimeCounter:Stop()
        this.TimeCounter = nil
    end

    showRewardItemView = nil
end

function ArenaMainPanel_ArenaView:OnDestroy()
    for _, head in ipairs(this.HeadList) do
        head:Recycle()
    end
    this.HeadList= nil
end
return ArenaMainPanel_ArenaView