BlitzStrikeManager = {}
local this = BlitzStrikeManager
-- local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

BlitzStrikeManager.TotalModelNum = 3    --< 总模式数 固定
BlitzStrikeManager.StageNum = 15        --< 关总数
BlitzStrikeManager.BoxNum = 5           --< box总数
function this.Initialize()
    this.heroInfo = {}
end

--> 设置难度选择信息
function this.SetDiffInfo(msg)
    this.difficultyLevel = msg.difficultyLevel
    this.historyAllPassStatus = {}
    for i = 1, #msg.historyAllPassStatus do
        table.insert(this.historyAllPassStatus, msg.historyAllPassStatus[i])
    end
end

--> 设置主信息
function this.SetMainInfo(msg)
    this.fightId = msg.fightId
    this.boxAwardedProgress = {}
    if msg.boxAwardedProgress then
        for i = 1, #msg.boxAwardedProgress do
            this.boxAwardedProgress[msg.boxAwardedProgress[i]] = 1      --< value 1 随意值 主要idx
        end
    end
    
    -- if this.fightId == 0 and this.difficultyLevel > 1 then
    --     --> >1难度时 如果重置后 初始id为0 根据关数确定id
    --     this.curFightId = this.fightId + BlitzStrikeManager.StageNum * (this.difficultyLevel - 1) + 1
    -- else
        this.curFightId = this.fightId + 1
    -- end
    this.todayRewardedTotal = {}
    for i = 1, #msg.todayRewardedTotal do
        local id = msg.todayRewardedTotal[i].itemId
        local num = msg.todayRewardedTotal[i].itemNum
        if this.todayRewardedTotal[id] == nil then
            this.todayRewardedTotal[id] = 0
        end
        this.todayRewardedTotal[id] = this.todayRewardedTotal[id] + num
    end
    this.todayReviveCount = msg.todayReviveCount
end

function this.SetStageData(msg)
    --  teamOneInfo {
    --      team {
    --          team {
    --              heroid: 10000461010016159747790001
    --              heroTid: 10015
    --              star: 4
    --              level: 1
    --              position: 2
    --              remainHp: 1
    --          }
    --          team {
    --              heroid: 10000461010016159747790000
    --              heroTid: 10013
    --              star: 4
    --              level: 1
    --              position: 4
    --              remainHp: 1
    --          }
    --          totalForce: 467
    --      }
    --      uid
    --      level
    --      name
    --      head
    --      headFrame
    --      guildName
    this.StageData = msg.teamOneInfo
end

--> 战斗
function this.ExecuteFight(_fightId, callBack)
    NetManager.FightStartRequest(BATTLE_TYPE.BLITZ_STRIKE, _fightId, function(msg)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg, 1)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BLITZ_STRIKE, callBack, _fightId)
        end)
    end)
end

function this.GetConfigDataByDiff(diffLevel)
    local ret = {}
    for _, value in ConfigPairs(ConfigManager.GetConfig(ConfigName.BlitzConfig)) do
        if value.Type == diffLevel then
            table.insert(ret, value)
        end
    end
    table.sort(ret, function(a, b)
        return a.Id < b.Id
    end)
    return ret
end

--> 更新剩余血量
function this.UpdateRemainBlood(msg)
    this.heroInfo = {}

    --> 所以英雄（拥有+改模块）
    local allOwnHeroData = HeroManager.GetAllHeroDatas()
    -- local allModelHeroData = this.GetSelectExternHeroDatas()
    for i = 1, #allOwnHeroData do
        local singleHeroInfo = {}
        singleHeroInfo.heroId = allOwnHeroData[i].dynamicId
        singleHeroInfo.remainHp = 1
        this.heroInfo[allOwnHeroData[i].dynamicId] = singleHeroInfo
    end
    -- for i = 1, #allModelHeroData do
    --     local singleHeroInfo = {}
    --     singleHeroInfo.heroId = allModelHeroData[i].dynamicId
    --     singleHeroInfo.remainHp = 1
    --     this.heroInfo[allModelHeroData[i].dynamicId] = singleHeroInfo
    -- end

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

--> 刷新编队 删除死亡
function this.RrefreshFormation()
    local teamId = FormationTypeDef.BLITZ_STRIKE
    local newFormation = this.DeleteDeadRole()
    FormationManager.formationList[teamId] = newFormation
end

function this.DeleteDeadRole()
    local newFormation = {} -- 编队界面的编队数据
    local curTeam = FormationManager.GetFormationByID(FormationTypeDef.BLITZ_STRIKE)
    -- 编队界面的数据
    newFormation.teamHeroInfos = {}
    newFormation.teamId = FormationTypeDef.BLITZ_STRIKE
    newFormation.teamName = curTeam.teamName
    newFormation.formationId = curTeam.formationId
    newFormation.supportId = curTeam.supportId
    newFormation.adjutantId = curTeam.adjutantId
    newFormation.substitute = curTeam.substitute
    -- 成员数据
    for i = 1, #curTeam.teamHeroInfos do
        local roleData = curTeam.teamHeroInfos[i]
        if this.heroInfo[roleData.heroId] and this.heroInfo[roleData.heroId].remainHp and this.heroInfo[roleData.heroId].remainHp > 0 then
            -- 编队界面数据重组
            table.insert(newFormation.teamHeroInfos, roleData)
        end
    end
    return newFormation
end

function this.GetAllDeadTanks(_property, _lvLimit)
    local allTanks = nil
    if _property ~= ProIdConst.All then
        allTanks = HeroManager.GetHeroDataByProperty(_property, _lvLimit)
    else
        allTanks = HeroManager.GetAllHeroDatas(_lvLimit)
    end

    local deadTanks = {}
    for i = 1, #allTanks do
        if this.heroInfo[allTanks[i].dynamicId] and this.heroInfo[allTanks[i].dynamicId].remainHp and this.heroInfo[allTanks[i].dynamicId].remainHp == 0 then
            table.insert(deadTanks, allTanks[i])
        end
    end
    return deadTanks
end

function this.GetRewardTotal()
    local ret = {}
    for k, v in pairs(this.todayRewardedTotal) do
        table.insert(ret, {k, v})
    end
    return ret
end

return this