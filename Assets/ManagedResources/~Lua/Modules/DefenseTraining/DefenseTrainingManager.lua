DefenseTrainingManager = {}
local this = DefenseTrainingManager
-- local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

function this.Initialize()
    this.FriendSupportHeroDatas = {}
    this.ExternHeroDatas = {}
    this.SelectExternHeroDatas = {}
    this.heroInfo = {}
end

function DefenseTrainingManager.UpdateMainData(msg)
    this.curFightId = msg.fightId                           --< 当前要打fightid
    this.maxLastFinishedId = msg.fightIdMax                 --< 最大通关id
    this.todayPassCount = msg.todayPassCount
    this.firstAwardedProgress = msg.firstAwardedProgress    --< 领取进度 后端领取后赋值相应fightId
    this.curBuffId = msg.curBuffId
    this.fightBuffId = this.curBuffId
    this.randomBuff = {}
    for i = 1, #msg.randomBuff do
        table.insert(this.randomBuff, msg.randomBuff[i])
    end
    this.todayStartFightId = msg.todayStartFightId          --< 手动重置到的关卡 今天开始的关卡

    --> 已选择的好友支援的坦克Id            后端未选择nil
    this.useFriendTankId = not (msg.useFriendTankId == "") and msg.useFriendTankId or nil
    --> 已派遣分享的坦克数据 Hero结构       后端未分享nil
    this.shareTank = not (msg.shareTank == nil or msg.shareTank.id == nil or msg.shareTank.id == "") and msg.shareTank or nil
    
    
    this.SetShareTankData()
    this.teamLock = msg.teamLock
    CheckRedPointStatus(RedPointType.EpicExplore)
end

function DefenseTrainingManager.UpdateFightIdData(msg)
    this.curFightId = msg.fightId
end

--> 服务端Hero数据转换成本地数据
function DefenseTrainingManager.SetSDataToCData(sData)
    return HeroManager.UpdateHeroDatas(sData, false, true)
end

--> 更新剩余血量
function DefenseTrainingManager.UpdateRemainBlood(msg)
    this.heroInfo = {}

    --> 所以英雄（拥有+改模块）
    local allOwnHeroData = HeroManager.GetAllHeroDatas()
    local allModelHeroData = this.GetSelectExternHeroDatas()
    for i = 1, #allOwnHeroData do
        local singleHeroInfo = {}
        singleHeroInfo.heroId = allOwnHeroData[i].dynamicId
        singleHeroInfo.remainHp = 1
        this.heroInfo[allOwnHeroData[i].dynamicId] = singleHeroInfo
    end
    for i = 1, #allModelHeroData do
        local singleHeroInfo = {}
        singleHeroInfo.heroId = allModelHeroData[i].dynamicId
        singleHeroInfo.remainHp = 1
        this.heroInfo[allModelHeroData[i].dynamicId] = singleHeroInfo
    end

    --> 后端只传过来上阵英雄信息 覆盖
    for i = 1, #msg.tankInfo do
        local singleHeroInfo = {}
        singleHeroInfo.heroId = msg.tankInfo[i].tankId
        singleHeroInfo.remainHp = msg.tankInfo[i].remainHp
        this.heroInfo[singleHeroInfo.heroId] = singleHeroInfo
    end

    for key, value in pairs(this.heroInfo) do
        
    end
end

function DefenseTrainingManager.UpdateRankingData(callback)
    -- ranks {
    --     uid: 10000315
    --     level: 40
    --     head: 71000
    --     userName: 10000315
    --     rankInfo {
    --         rank: 11
    --         param1: 30
    --         param2: 3
    --         param3: 0
    --     }
    --     headFrame: 80000
    --     force: 433
    --     sex: 0
    -- }
    -- myRankInfo {
    --     rank: -1
    --     param1: 0
    --     param2: -1
    -- }
    NetManager.RequestRankInfo(RANK_TYPE.DEFENSE_TRAINING, function(msg)     
        this.ranks = msg.ranks
        this.myRankInfo = msg.myRankInfo

        if callback then
            callback()
        end
    end)
end

function this.SetShareTankData()
    if this.shareTank == nil then
        this.shareTankLocalData = nil
    else
        this.shareTankLocalData = this.SetSDataToCData(this.shareTank)      
    end
end

function this.SetFriendSupportHeroDatas(msg)
    this.FriendSupportHeroDatas = {}
    this.ExternHeroDatas = {}
    for i = 1, #msg.friendSupport do
        local tank = this.SetSDataToCData(msg.friendSupport[i].tank)
        table.insert(this.FriendSupportHeroDatas, {uid = msg.friendSupport[i].uid, name = msg.friendSupport[i].name, tank = tank})
        table.insert(this.ExternHeroDatas, tank)
    end
end

--> type 1首通 2日常 3排行 0all
function DefenseTrainingManager.GetAllRewardNoRepeatIds(type)
    local type = type or 0
    local rewardIds = {}
    
    for k, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.DefTrainingConfig)) do
        if #v.Award > 0 and (type == 2 or type == 0) then
            for i = 1, #v.Award do
                rewardIds[v.Award[i][1]] = v.Award[i][1]
            end
        end

        if v.FirstAward and #v.FirstAward > 0 and (type == 1 or type == 0) then
            rewardIds[v.FirstAward[1]] = v.FirstAward[1]
        end
    end

    for k, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.DefTrainingRanking)) do
        if #v.RankingAward > 0 and (type == 3 or type == 0) then
            for i = 1, #v.RankingAward do
                rewardIds[v.RankingAward[i][1]] = v.RankingAward[i][1]
            end
        end
    end

    local ret = {}
    for key, value in pairs(rewardIds) do
        table.insert(ret, value)
    end

    return ret
end

function DefenseTrainingManager.ExecuteFightBefore(root)
    if this.curFightId % 5 == DefenseTrainingManager.todayStartFightId % 5 and DefenseTrainingManager.curBuffId == 0 then
        UIManager.OpenPanel(UIName.DefenseTrainingBuffPopup, this.curFightId)
        if root then
            root:ClosePanel()
        end
    else
        DefenseTrainingManager.ExecuteFight(this.curFightId, function()
            --更新编队信息
            NetManager.GetTankInfoOfTeam(FormationTypeDef.DEFENSE_TRAINING, function(msg)    --< 拉剩余血量数据
                -- LogError("-get  blood")
                end)
            if root then
                root:ClosePanel()
            end
            if RewardItemPopup then
                RewardItemPopup:ClosePanel()
            end
        end)
    end
end

--战斗
function DefenseTrainingManager.ExecuteFight(_fightId, callBack)
    --fightInfo
    BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.DefenseTraining, G_DefTrainingConfig[_fightId].MonsterGroupId)

    local fightBuffId
    if DefenseTrainingManager.fightBuffId ~= 0 then
        fightBuffId = DefenseTrainingManager.fightBuffId
    end
    NetManager.FightStartRequest(BATTLE_TYPE.DefenseTraining, _fightId, function(msg)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg, nil)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.DefenseTraining, callBack, _fightId)
        end)
    end, fightBuffId)
end

--获取有首通奖励的list
function DefenseTrainingManager.GetFirstRewardList()
    local ret = {}
    for k, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.DefTrainingConfig)) do
        if v.FirstAward and #v.FirstAward == 2 then --< 策划一维数组只有一个固定
            table.insert(ret, v)
        end
    end
    table.sort(ret, function(a, b)
        return a.Id < b.Id
    end)

    return ret
end

function DefenseTrainingManager.GetAllMineSupportHeroDatas()
    local alldata = HeroManager.GetAllHeroDatas()
    if this.shareTank == nil then

    else
        for i = 1, #alldata do
            if alldata[i].dynamicId == this.shareTank.id then
                table.remove(alldata, i)
                break
            end
        end
    end
    return alldata
end

--> 获取选择的extern 英雄数据
function DefenseTrainingManager.GetSelectExternHeroDatas()
    this.SelectExternHeroDatas = {}
    if this.useFriendTankId == nil then
    else
        for i = 1, #this.ExternHeroDatas do
            if this.ExternHeroDatas[i].dynamicId == this.useFriendTankId then
                table.insert(this.SelectExternHeroDatas, this.ExternHeroDatas[i])
            end
        end
    end
    return this.SelectExternHeroDatas
end

function DefenseTrainingManager.GetSingleHeroData(heroDid)
    local ret = nil
    for i = 1, #this.SelectExternHeroDatas do
        if this.SelectExternHeroDatas[i].dynamicId == heroDid then
            ret = this.SelectExternHeroDatas[i]
            break
        end
    end
    return ret
end

--> similar override
--获取所有英雄信息
function DefenseTrainingManager.GetAllHeroDatas(heros, _lvLimit)
    local lvLimit = 0
    if _lvLimit then lvLimit = _lvLimit end
    for i, v in pairs(this.GetSelectExternHeroDatas()) do
        if v.lv >= lvLimit then
            table.insert(heros,v)
        end
    end
    table.sort(heros, function(a,b) return a.sortId < b.sortId end)
    return heros
end

--> similar override
--通过属性筛选英雄
function DefenseTrainingManager.GetHeroDataByProperty(heros, _property, _lvLimit)
    local lvLimit = 0
    if _lvLimit then lvLimit = _lvLimit end
    local index = 1
    if heros and #heros > 0 then
        index = index + #heros
    end
    for i, v in pairs(this.GetSelectExternHeroDatas()) do
        if v.property == _property then
            if v.lv >= lvLimit then
                heros[index] = v
                index = index + 1
            end
        end
    end
    return heros
end

function DefenseTrainingManager.CheckIsAllDead()
    local formationData = FormationManager.GetFormationByID(FormationTypeDef.DEFENSE_TRAINING)

    for i = 1, #formationData.teamHeroInfos do
        local info = this.heroInfo[formationData.teamHeroInfos[i].heroId]
        if info and info.remainHp > 0 then
            return false
        end
    end

    local tibu =this.heroInfo[formationData.substitute]
    if tibu and tibu.remainHp > 0 then
        return false
    end

    return true
end

return this