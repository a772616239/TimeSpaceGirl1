RankingManager = {}
local this = RankingManager

--需要显示的排行
local NeedRanking = {
    --[1] = {Id = 53, OpenLv = 0, Name = "外敌", PanelType = 0},
    [1] = {Id = 8, OpenLv = 0, Name = GetLanguageStrById(11725), PanelType = 0, Des = GetLanguageStrById(11725)},
    [2] = {Id = 30, OpenLv = 0, Name = GetLanguageStrById(11726), PanelType = 0, Des = GetLanguageStrById(11259)},
    [3] = {Id = 55, OpenLv = 0, Name = GetLanguageStrById(11727), PanelType = 0, Des = ""},
    [4] = {Id = 44, OpenLv = 0, Name = GetLanguageStrById(11728), PanelType = 0, Des = GetLanguageStrById(11728)},
    [5] = {Id = 26, OpenLv = 0, Name = GetLanguageStrById(11729), PanelType = 0, Des = ""},
}
--Tab按钮显示文字
local TabTextData = {
   -- [1] = {txt = ""},
    [1] = {txt = ""},
    [2] = {txt = ""},
    [3] = {txt = ""},
    [4] = {txt = ""},
    [5] = {txt = " " },
}
 
this.CurPage = 0
this.WarPowerData = {}--战力排行滚动数据
this.WarPowerMyRankData = {} --我的数据
this.ArenaData = {}--逐胜场
this.ArenaMyRankData = {}
this.TrialData = {}--试炼
this.TrialMyRankData = {}
this.MonsterData = {}--兽潮
this.MonsterMyRankData = {}
this.AdventureData = {}--外敌
this.AdventureMyRankData = {}
this.CustomsPassData = {}--关卡
this.CustomsPassMyRankData = {}
this.GuildData = {}--公会
this.GuildMyRankData = {}
this.GoldExperData = {}--点金
this.GoldExperMyRankData = {}
this.GoldExperGuildData = {}--社稷大典工会
this.GoldExperGuildMyRankData = {}
this.ClimbTowerData = {}--模拟战
this.ClimbTowerMyRankData = {}
this.AlameinWarData = {}--阿拉曼
this.AlameinWarMyRankData = {}
this.HeroForceRankData={} --英雄战力排行
this.HeroForceMyRankData={} 

--是否加载完成
this.LoadCompleted = {
    WarPower = 0,
    Arena = 0,
    Trial = 0,
    Monster = 0,
    FightAlien = 0,
    CustomsPass = 0,
    GuildForce = 0,
    GoldExperSort = 0,
    ClimbTower = 0,
    CELEBRATION_GUILD = 0,
    HeroForce = 0, -- 英雄战力排行 
    rankingReward=0, -- 全服排行奖励
}

this.mainLevelConfig = {}
this.isRequest = 0--防止连续请求

function this.Initialize()
    this.InitNeedRanking()
end

--初始化需要显示的排行
function this.InitNeedRanking()
    this.mainLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
    --开启等级赋值
    for i = 1, #NeedRanking do
        NeedRanking[i].OpenLv = ConfigManager.GetConfigData(ConfigName.GlobalSystemConfig, NeedRanking[i].Id).OpenRules[2]
    end
    --排序
    table.sort(NeedRanking,function(a,b)
        return a.OpenLv < b.OpenLv
    end)
    --面板类型赋值
    for i = 1, #NeedRanking do
        NeedRanking[i].PanelType = i
    end
end

--根据活动开启等级，获取排序后活动名
function this.GetSortName()
    local nameTable = {}
    for i = 1, #NeedRanking do
        nameTable[i] = NeedRanking[i].Name
    end
    return nameTable
end

--获取Tab文字内容
function this.GetTabTextData()
    local _tabTextName = RankingManager.GetSortName()
    for i = 1, #_tabTextName do
        TabTextData[i].txt = _tabTextName[i]
    end
    return TabTextData
end

--根据点击面板类型 获取当前排行信息
--type 需要的信息类型
--index 当前点击值
function this.GetCurRankingInfo(type,index)
    if type == "Id" then
        for i = 1, #NeedRanking do
            if NeedRanking[i].PanelType == index then
                return NeedRanking[i].Id
            end
        end
    elseif type == "OpenLv" then
        for i = 1, #NeedRanking do
            if NeedRanking[i].PanelType == index then
                return NeedRanking[i].OpenLv
            end
        end
    elseif type == "Des" then
        for i = 1, #NeedRanking do
            if NeedRanking[i].PanelType == index then
                return NeedRanking[i].Des
            end
        end
    end
end

--初始化排行数据（待优化）
function this.InitData(type, fun, id)
    -- if type == FUNCTION_OPEN_TYPE.ALLRANKING then--如果加载为指定的功能类型
    --    if this.LoadCompleted.WarPower == 0 then--当未加载该数据时
    --        --if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALLRANKING) then--判断该功能是否解锁
    --            NetManager.RequestRankInfo(RANK_TYPE.FORCE_RANK, function (msg)--请求数据
    --                this.ReceiveWarPowerData(msg)
    --                if fun then fun() end
    --            end, ActivityTypeDef.WarPowerSort)
    --        --else
    --        --    this.warPowerData = {}
    --        --    this.warPowerMsg = {}
    --        --    if fun then fun() end
    --        --end
    --    else--当存在该功能数据时 执行回调
    --        if fun then fun() end
    --    end
    -- end

    if this.LoadCompleted.rankingReward == 0 then--当未加载该数据时
        -- if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALLRANKING) then--判断该功能是否解锁
            NetManager.RankingInfoListRequest( function (msg)--请求数据
                this.ReceiveRankingTopInfo(msg)
                if fun then fun(msg) end
            end,0)
    else--当存在该功能数据时 执行回调
        if fun then fun(msg) end
    end


    --实时关卡排行   
    if type == RANK_TYPE.GOLD_EXPER then
        local activiteId = (id ~= nil and id > 0) and id or nil--点金时需要  当为公会副本是为章节id
        NetManager.RequestRankInfo(type, function (msg)--请求数据
            this.ReceiveRankingData(msg,fun)
        end,activiteId)
    end
    if type == FUNCTION_OPEN_TYPE.ALLRANKING then--如果加载为指定的功能类型
        if this.LoadCompleted.WarPower == 0 then--当未加载该数据时
            -- if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALLRANKING) then--判断该功能是否解锁
                NetManager.RequestRankInfo(RANK_TYPE.FORCE_CURR_RANK, function (msg)--请求数据
                    this.ReceiveWarPowerData(msg)
                    if fun then fun() end
                end,0)
            -- else
            --    this.warPowerData = {}
            --    this.warPowerMsg = {}
            --    if fun then fun() end
            -- end
        else--当存在该功能数据时 执行回调
            if fun then fun() end
        end
    end
    if type == FUNCTION_OPEN_TYPE.ARENA then---------------------------------------------------------------------------------
        if this.LoadCompleted.Arena == 0 then
            --if ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.ARENA) then --根据是否有资格开启 逐胜场排行在赛季结束时 tab不锁定 需要显示数据
                NetManager.RequestArenaRankData(1,function(page,msg)
                    this.ReceiveArenaData(page,msg)
                    --if fun then fun() end
                end)
            --else
            --    this.ArenaData = {}
            --    this.ArenaMyRankData = {}
            --    if fun then fun() end
            --end
        else
            if fun then fun() end
        end
    end

    if type == FUNCTION_OPEN_TYPE.TRIAL then
        if this.LoadCompleted.Trial == 0 then
            --if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.TRIAL) then
                NetManager.RequestRankInfo(RANK_TYPE.TRIAL_RANK, function(msg)
                    this.ReceiveTrialData(msg)
                    if fun then fun() end
                end)
            --else
            --    this.TrialData={}
            --    this.TrialMyRankData={}
            --    if fun then fun() end
            --end
        else
            if fun then fun() end
        end
    end
    if type == FUNCTION_OPEN_TYPE.MONSTER_COMING then
        if this.LoadCompleted.Monster == 0 then
            --if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.MONSTER_COMING) then
                NetManager.RequestRankInfo(RANK_TYPE.MONSTER_RANK, function(msg)
                    this.ReceiveMonsterData(msg)
                    if fun then fun() end
                end)
            --else
            --    this.MonsterData={}
            --    this.MonsterMyRankData={}
            --    if fun then fun() end
            --end
        else
            if fun then fun() end
        end
    end
    if type == FUNCTION_OPEN_TYPE.FIGHT_ALIEN then
        if this.LoadCompleted.FightAlien == 0 then
            -- if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.FIGHT_ALIEN) then
                NetManager.GetAdventureRankRequest(1,function(page,msg)
                    this.ReceiveAdventureData(page,msg)
                    if fun then fun() end
                end)
            -- else
            --    this.AdventureData = {}
            --    this.AdventureMyRankData = {}
            --    if fun then fun() end
            -- end
        else
            if fun then fun() end
        end
    end
    if type == FUNCTION_OPEN_TYPE.CUSTOMSPASS then
        if this.LoadCompleted.CustomsPass == 0 then
            -- if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.CUSTOMSPASS) then
                if this.isRequest == 1 then
                    return
                end
                this.isRequest = 1
                NetManager.RequestRankInfo(RANK_TYPE.FIGHT_LEVEL_RANK, function(msg)
                    this.ReceiveCustomsPassData(msg)
                    if fun then fun() end
                end)
            -- else
            --    this.CustomsPassData={}
            --    this.CustomsPassMyRankData={}
            --    if fun then fun() end
            -- end
        else
            if fun then fun() end
        end
    end
    if type == FUNCTION_OPEN_TYPE.GUILD then
        -- this.GuildData = {}--公会
        -- this.GuildMyRankData = {}
        if this.LoadCompleted.GuildForce == 0 then
            -- if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then
                if this.isRequest == 1 then
                    return
                end
                this.isRequest = 1
                NetManager.RequestRankInfo(RANK_TYPE.GUILD_FORCE_RANK, function(msg)
                    this.ReceiveGuildForeData(msg)
                    if fun then fun() end
                end)
            -- else
            --    this.GuildData = {}
            --    this.GuildMyRankData = {}
            --    if fun then fun() end
            -- end
        else
            if fun then fun() end
        end
    end
    if type == FUNCTION_OPEN_TYPE.EXPERT then
        if this.LoadCompleted.GoldExperSort == 0 then
            if this.isRequest == 1 then
                return
            end
            this.isRequest = 1
            local activityId
            if id and id > 0 then
                activityId = ActivityGiftManager.GetActivityTypeInfo(id).activityId
            else
                activityId = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.RecruitExper).activityId
            end
            local activityId
            if id and id > 0 then
                activityId = ActivityGiftManager.GetActivityTypeInfo(id).activityId
            else
                activityId = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.RecruitExper).activityId
            end

            NetManager.RequestRankInfo(RANK_TYPE.GOLD_EXPER, function(msg)
                this.ReceiveGoldExperSortData(msg)
                if fun then fun() end
            end, activityId)--ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.GoldExper))
        else
            if fun then fun() end
        end
    end

    if type == RANK_TYPE.CELEBRATION_GUILD then
        if this.LoadCompleted.CELEBRATION_GUILD == 0 then
            if this.isRequest == 1 then
                return
            end
            this.isRequest = 1
            NetManager.RequestRankInfo(RANK_TYPE.CELEBRATION_GUILD, function(msg)
                this.ReceiveGoldExperGuildSortData(msg)
                if fun then fun() end
            end,ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.Celebration).activityId)--ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.GoldExper))
        else
            if fun then fun() end
        end
    end

    if type == FUNCTION_OPEN_TYPE.CLIMB_TOWER then
        if this.LoadCompleted.ClimbTower == 0 then
            NetManager.RequestRankInfo(RANK_TYPE.CLIMB_TOWER, function(msg)
                this.ReceiveClimbTowerData(msg)
                if fun then fun() end
            end)
        else
            if fun then fun() end
        end
    end

    if type == FUNCTION_OPEN_TYPE.ALAMEIN_WAR then
        if this.LoadCompleted.AlameinWar == 0 then
            NetManager.RequestRankInfo(RANK_TYPE.ALAMEIN_WAR, function(msg)
                this.ReceiveAlameinWarData(msg)
                if fun then fun() end
            end)
        else
            if fun then fun() end
        end
    end
    -- to do yh
    if type == RANK_TYPE.HERO_FORCE_RANK then
        if this.LoadCompleted.HeroForce == 0 then
                NetManager.RequestRankInfo(RANK_TYPE.HERO_FORCE_RANK, function(msg)
                     --储存消息   
                     this.ReceiveHeroForceData(msg)       
                    if fun then fun() end
                end)
        else
            if fun then fun() end
        end
    end
end

--清空数据
function this.ClearData()
    this.CurPage = 0
    this.WarPowerData = {}--战力排行滚动数据
    this.WarPowerMyRankData = {} --我的数据
    this.ArenaData = {}--逐胜场
    this.ArenaMyRankData = {}
    this.TrialData = {}--试炼
    this.TrialMyRankData = {}
    this.MonsterData = {}--兽潮
    this.MonsterMyRankData = {}
    this.AdventureData = {}--外敌
    this.AdventureMyRankData = {}
    this.CustomsPassData = {}--关卡
    this.CustomsPassMyRankData = {}
    this.GuildData = {}--公会
    this.GuildMyRankData = {}
    this.GoldExperData = {}--点金
    this.GoldExperMyRankData = {}
    this.GoldExperGuildData = {}--社稷大典
    this.GoldExperGuildMyRankData = {}
    this.ClimbTowerData = {}--模拟战
    this.ClimbTowerMyRankData = {}
    this.AlameinWarData = {}--阿拉曼
    this.AlameinWarMyRankData = {}
    this.HeroForceRankData={} --英雄排行榜
    this.HeroForceMyRankData={}
    this.LoadCompleted.WarPower = 0
    this.LoadCompleted.Arena = 0
    this.LoadCompleted.Trial = 0
    this.LoadCompleted.Monster = 0
    this.LoadCompleted.FightAlien = 0
    this.LoadCompleted.CustomsPass = 0
    this.LoadCompleted.GuildForce = 0
    this.LoadCompleted.GoldExperSort = 0
    this.LoadCompleted.ClimbTower = 0
    this.LoadCompleted.AlameinWar = 0
    this.LoadCompleted.CELEBRATION_GUILD = 0
    this.LoadCompleted.HeroForce=0
end

-- -战力战力
-- 接收服务器战力数据
function this.ReceiveWarPowerData(msg)
    --if this.CurPage >= page then return end
    --this.CurPage=page
    --if page==1 then
    --    this.WarPowerData={}
    --end

    --自身数据
    this.WarPowerMyRankData.myRank = msg.myRankInfo.rank
    this.WarPowerMyRankData.myForce = msg.myRankInfo.param1
    --滚动数据
    local length = #this.WarPowerData
    for i, rank in ipairs(msg.ranks) do
        this.WarPowerData[length+i] = rank
    end
    this.LoadCompleted.WarPower = 1
    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnWarPowerChange)
end
--请求下一页数据
function this.RequestNextWarPowerPageData()
    -- if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALLRANKING) then
    --    PopupTipPanel.ShowTip("本赛季已结束")
    --    return
    -- end
    -- --判断是否符合刷新条件
    -- local rankNum = #this.WarPowerData
    -- -- 最多显示100
    -- local config = ConfigManager.GetConfigData(ConfigName.SpecialConfig, 7)
    -- local MaxNum = config and tonumber(config.Value) or 100
    -- if rankNum >= MaxNum then return end
    -- -- 上一页数据少于20条，则没有下一页数，不再刷新
    -- if rankNum % 20 > 0 then
    --    return
    -- end
    
    -- 请求下一页
    -- NetManager.RequestWarPowerSortData(this.CurPage + 1,ActivityTypeDef.WarPowerSort,function(page,msg)
    --    this.ReceiveWarPowerData(page,msg)
    -- end)
end
--获取排行榜信息
function this.GetWarPowerInfo()
    return this.WarPowerData, this.WarPowerMyRankData
end

---逐胜场
function this.ReceiveArenaData(page,msg)
    if this.CurPage >= page then return end
    this.CurPage = page
    if page == 1 then
        this.ArenaData={}
    end
    --自身数据
    this.ArenaMyRankData.myRank = msg.myRank
    this.ArenaMyRankData.myScore = msg.myscore
    --滚动数据
    local length = #this.ArenaData
    for i, rank in ipairs(msg.rankInfos) do
        this.ArenaData[length+i] = rank
    end
    this.LoadCompleted.Arena = 1
    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnArenaChange)
end
function this.RequestNextArenaPageData()
    if not ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.ARENA) then
        --PopupTipPanel.ShowTip("本赛季已结束")
        return
    end
    --判断是否符合刷新条件
    local rankNum = #this.ArenaData
    -- 最多显示100
    local config = ConfigManager.GetConfigData(ConfigName.SpecialConfig, 3)
    local MaxNum = config and tonumber(config.Value) or 100
    if rankNum >= MaxNum then return end
    -- 上一页数据少于20条，则没有下一页数，不再刷新
    if rankNum % 20 > 0 then
        return
    end
    -- 请求下一页
    NetManager.RequestArenaRankData(this.CurPage + 1,function(page,msg)
        this.ReceiveArenaData(page,msg)
    end)
end
function this.GetArenaInfo()
    return this.ArenaData, this.ArenaMyRankData
end

-- 阿拉曼战役
function this.ReceiveAlameinWarData(msg)
    --自身数据
    this.AlameinWarMyRankData.rank = msg.myRankInfo.rank
    this.AlameinWarMyRankData.param1 = msg.myRankInfo.param1
    this.AlameinWarMyRankData.param2 = msg.myRankInfo.param2
    --滚动数据
    local ranks = {}
    for i = 1, #msg.ranks do
        table.insert(ranks, msg.ranks[i])
    end
    table.sort(ranks, function(a, b)
        return a.rankInfo.rank < b.rankInfo.rank
    end)
    this.AlameinWarData = ranks
    this.LoadCompleted.AlameinWar = 1
    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnAlameinWarChange)
end
function this.GetAlameinWarInfo()
    return this.AlameinWarData, this.AlameinWarMyRankData
end

-- 英雄战力排行
function this.ReceiveHeroForceData(msg) 
    --滚动数据
    local ranks = {}
    -- LogError("my force:"..msg.myRankInfo.rank.." heroTemplateId "..msg.myRankInfo.heroTemplateId.."  param2 "..msg.myRankInfo.param2.."  param3"..msg.myRankInfo.param3)
    --自身数据
    this.HeroForceMyRankData.myrank = msg.myRankInfo.rank
    this.HeroForceMyRankData.myforce = msg.myRankInfo.param1
    this.HeroForceMyRankData.myHeroTemplateId = msg.myHeroTemplateId 
    this.HeroForceMyRankData.myheroLevel  = msg.myheroLevel 
    this.HeroForceMyRankData.myheroStar  = msg.myheroStar 
     for i = 1, #msg.ranks do
        table.insert(ranks, msg.ranks[i])
    end
    table.sort(ranks, function(a, b)
        return a.rankInfo.rank < b.rankInfo.rank
    end)
    this.HeroForceRankData = ranks

    this.LoadCompleted.HeroForce = 1
    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnHeroForceChange)
end
function this.GetHeroForceInfo()
    return this.HeroForceRankData, this.HeroForceMyRankData
end


-- 模拟战
function this.ReceiveClimbTowerData(msg)
    --自身数据
    this.ClimbTowerMyRankData.rank = msg.myRankInfo.rank
    this.ClimbTowerMyRankData.param1 = msg.myRankInfo.param1
    --滚动数据
    local ranks = {}
    for i = 1, #msg.ranks do
        table.insert(ranks, msg.ranks[i])
    end
    table.sort(ranks, function(a, b)
        return a.rankInfo.rank < b.rankInfo.rank
    end)
    this.ClimbTowerData = ranks
    this.LoadCompleted.ClimbTower = 1
    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnClimbTowerChange)
end
function this.GetClimbTowerInfo()
    return this.ClimbTowerData, this.ClimbTowerMyRankData
end

---试炼
function this.ReceiveTrialData(msg)
    --自身数据
    this.TrialMyRankData.rank = msg.myRankInfo.rank
    this.TrialMyRankData.highestTower = msg.myRankInfo.param1
    --滚动数据
    local length = #this.TrialData
    for i, rank in ipairs(msg.ranks) do
        this.TrialData[length+i]=rank
    end
    this.LoadCompleted.Trial = 1
    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnTrialChange)
end
function this.GetTrialInfo()
    return this.TrialData, this.TrialMyRankData
end

---兽潮
function this.ReceiveMonsterData(msg)
    --自身数据
    this.MonsterMyRankData.myRank = msg.myRankInfo.rank
    this.MonsterMyRankData.myScore = msg.myRankInfo.param1
    --滚动数据
    local length = #this.MonsterData
    for i, rank in ipairs(msg.ranks) do
        this.MonsterData[length+i] = rank
    end
    this.LoadCompleted.Monster = 1

    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnMonsterChange)
end
function this.GetMonsterInfo()
    return this.MonsterData, this.MonsterMyRankData
end

---外敌
function this.ReceiveAdventureData(page,msg)
    if this.CurPage >= page then return end
    this.CurPage = page
    if page == 1 then
        this.AdventureData = {}
    end
    --自身数据
    this.AdventureMyRankData.rank = msg.myInfo.rank
    this.AdventureMyRankData.hurt = msg.myInfo.hurt
    --滚动数据
    local length = #this.AdventureData
    for i, rank in ipairs(msg.adventureRankItemInfo) do
        this.AdventureData[length+i] = rank
    end
    this.LoadCompleted.FightAlien = 1

    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnAdventureChange)
end
function this.RequestNextAdventurePageData()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.FIGHT_ALIEN) then
        PopupTipPanel.ShowTipByLanguageId(10082)
        return
    end
    --判断是否符合刷新条件
    local rankNum = #this.AdventureData
    -- 最多显示100
    local config = ConfigManager.GetConfigData(ConfigName.SpecialConfig, 6)
    local MaxNum = config and tonumber(config.Value) or 100
    if rankNum >= MaxNum then return end
    -- 上一页数据少于20条，则没有下一页数，不再刷新
    if rankNum % 20 > 0 then
        return
    end
    -- 请求下一页
    NetManager.GetAdventureRankRequest(this.CurPage + 1,function(page,msg)
        this.ReceiveAdventureData(page,msg)
    end)
end
function this.GetAdventureInfo()
    return this.AdventureData,this.AdventureMyRankData
end

---关卡
function this.ReceiveCustomsPassData(msg)
    if this.LoadCompleted.CustomsPass == 1 then
        return
    end
    --自身数据

    this.CustomsPassMyRankData.myRank = msg.myRankInfo.rank
    this.CustomsPassMyRankData.fightId = msg.myRankInfo.param1
    --滚动数据
    local length=#this.CustomsPassData
    for i, rank in ipairs(msg.ranks) do
        this.CustomsPassData[length+i] = rank
    end
    this.LoadCompleted.CustomsPass = 1

    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnCustomsPassChange)
end
function this.GetCustomsPassInfo()
    return this.CustomsPassData,this.CustomsPassMyRankData
end
---公会
function this.ReceiveGuildForeData(msg)
    --this.GuildData = {}--公会
    --this.GuildMyRankData = {}
    if this.LoadCompleted.GuildForce == 1 then
        return
    end
    --自身数据

    this.GuildMyRankData.myRank = msg.myRankInfo.rank
    this.GuildMyRankData.myForce = msg.myRankInfo.param1
    --滚动数据
    local length = #this.GuildData
    for i, rank in ipairs(msg.ranks) do
        this.GuildData[length+i] = rank
    end
    this.LoadCompleted.GuildForce = 1

    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnGuildForceChange)
end
function this.GetGuildForeInfo()
    return this.GuildData,this.GuildMyRankData
end
---点金
function this.ReceiveGoldExperSortData(msg)
    if this.LoadCompleted.GoldExperSort == 1 then
        return
    end
    --自身数据
    this.GoldExperMyRankData.myRank = msg.myRankInfo.rank
    this.GoldExperMyRankData.myNum = msg.myRankInfo.param1

    --滚动数据
    local length = #this.GoldExperData
    for i, rank in ipairs(msg.ranks) do
        this.GoldExperData[length+i] = rank
    end
    this.LoadCompleted.GoldExperSort = 1

    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnGoldExperSortChange)
end
function this.GetGoldExperSortInfo()
    return this.GoldExperData,this.GoldExperMyRankData
end

---次元引擎工会
function this.ReceiveGoldExperGuildSortData(msg)
    if this.LoadCompleted.CELEBRATION_GUILD == 1 then
        return
    end
    --自身数据

    this.GoldExperGuildMyRankData.myRank = msg.myRankInfo.rank
    this.GoldExperGuildMyRankData.myNum = msg.myRankInfo.param1    
    --滚动数据
    local length = #this.GoldExperGuildData
    for i, rank in ipairs(msg.ranks) do
        this.GoldExperGuildData[length+i] = rank
    end
    this.LoadCompleted.CELEBRATION_GUILD = 1

    Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnGoldExperSortChange)
end
function this.GetGoldExperGuildSortInfo()
    return this.GoldExperGuildData,this.GoldExperGuildMyRankData
end

--膜拜信息
local RankProud = {}
local firstRankProud = {}--后端临时数据
function this.SetAllRankProud(types,prouds)
    for i = 1, #types do
        RankProud[types[i]] = prouds[i]
    end
end
function this.SetSingleRankProud(type,proud)
    RankProud[type] = proud
end
function this.GetRankProud()
   return RankProud
end
function this.SetAllFirstRankProud(types,_firstRankProud)
    for i = 1, #_firstRankProud do
        firstRankProud[types[i]] = _firstRankProud[i]
    end
end
function this.GetAllFirstRankProud()
    return firstRankProud
end

--数据拆分 d数据
function this.CutDate(d)
    local dt ,db = {}, {}
    for i, v in ipairs(d) do
        if i == 1 then
            table.insert(dt,v)
        else
            table.insert(db,v)
        end
    end
    return dt,db
end

--膜拜红点
function this.RefreshRedPoint()
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALLRANKING) then
        local proud = RankingManager.GetRankProud()
        local allFirstRankProud = RankingManager.GetAllFirstRankProud()
        if proud then
            for i, v in pairs(proud) do
                if v == 0 and allFirstRankProud[i].uid ~= 0 then--没有膜拜过
                    return true
                end
            end
        end
        return false
    else
        return false
    end
end

function this.GetRankingInfo(rankType, fun, id)
    NetManager.RequestRankInfo(rankType, function (msg)--请求数据
        this.ReceiveRankingData(msg, fun)
    end, id)
end

---战力战力
--接收服务器战力数据
function this.ReceiveRankingData(msg,fun)
    --自身数据
    this.curRankingData = {}
    this.curRankingMyRankData = msg.myRankInfo
    --滚动数据
    local length = #this.curRankingData
    for i, rank in ipairs(msg.ranks) do
        this.curRankingData[length+i] = rank
    end
    if fun then fun(this.curRankingData, this.curRankingMyRankData) end
    -- Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.AllRankingList)
end


-- 排行奖励 
this.RankingTopInfo={} --排行奖励信息
this.RankingRewardedList={} --领过奖励的id列表 

function this.InitRankingRewardList(func)
    this.RankingTopInfo={}
    this.RankingRewardedList={}
    NetManager.RankingInfoListRequest(function (msg)--请求数据
        if msg~=nil then
            for i=1 , #msg.rankInfo do
                local list={}
                local tmp=msg.rankInfo[i]
                if this.RankingTopInfo[tmp.id]~=nil then 
                    table.insert(this.RankingTopInfo[tmp.id],tmp)  
                    table.sort(this.RankingTopInfo[tmp.id],function(a,b)
                        return a.time  < b.time 
                    end)
                else
                    this.RankingTopInfo[tmp.id]=list
                    table.insert(this.RankingTopInfo[tmp.id],tmp)   
                end
            end
            this.RankingRewardedList=msg.rewardRecords
            -- LogError("rewardRecords "..#this.RankingRewardedList.." s"..#msg.rewardRecords)
            if func then func() end 
        end
    end)
     
end
--请求数据
function this.ReceiveRankingTopInfo(msg,fun)
    this.RankingTopInfo={}
    if msg~=nil then
        for i=1 , #msg.rankInfo do
            local list={}
            local tmp=msg.rankInfo[i]
            if this.RankingTopInfo[tmp.id]~=nil then 

                table.insert(this.RankingTopInfo[tmp.id],tmp)   
                table.sort(this.RankingTopInfo[tmp.id],function(a,b)
                    return a.time  < b.time 
                end)
            else
                this.RankingTopInfo[tmp.id]=list
                table.insert(this.RankingTopInfo[tmp.id],tmp)   
            end
        end
        table.sort(this.RankingTopInfo,function(a,b)
            return a[1].id  < b[1].id 
        end)
        this.RankingRewardedList=msg.rewardRecords
        this.LoadCompleted.rankingReward = 1 -- 初始化完成
        --Game.GlobalEvent:DispatchEvent(GameEvent.RankingList.OnRankingRewardChange)       
    end
    if fun  then fun() end
end
--请求数据
function this.RequestRankingTopInfo(fun)
        NetManager.RankingInfoListRequest(function (msg)
        this.ReceiveRankingTopInfo(msg, fun)
    end)
end

-- 刷新数据
function this.RefreshInfo(fun)
    this.RequestRankingTopInfo(fun)
end

--获取数据
function this.GetRankingTopInfo()
    return this.RankingTopInfo,this.RankingRewardedList
end

--对应策划表id类型
-- 1：关卡排名
-- 2：战力排名
-- 3：神之塔排名
-- 4：英雄榜排名
function this.GetRankingTopInfoBytype(_rankType,myRankingRewardconfig)
    -- LogError("_rankType".._rankType)
    local typeId=0
    if _rankType==RANK_TYPE.FIGHT_LEVEL_RANK then
        typeId=1
    elseif _rankType==RANK_TYPE.FORCE_RANK or _rankType==RANK_TYPE.FORCE_CURR_RANK then 
        typeId=2
    elseif _rankType==RANK_TYPE.CLIMB_TOWER then
        typeId=3
    elseif _rankType==RANK_TYPE.HERO_FORCE_RANK then
        typeId=4
    end
    -- LogError("typid"..typeId)
    local listInfo={}
    for id,lis in pairs(this.RankingTopInfo) do
        if myRankingRewardconfig[id].Type==typeId then
            listInfo[id]=lis
        end
    end
    -- LogError("listInfo"..#listInfo)
    return listInfo,this.RankingRewardedList
end

--限制死宝箱排行类型 目前仅显示4种
function this.IsShowType(_rankType)
    if _rankType==RANK_TYPE.FIGHT_LEVEL_RANK or
    _rankType==RANK_TYPE.FORCE_RANK or 
    _rankType==RANK_TYPE.FORCE_CURR_RANK or
    _rankType==RANK_TYPE.CLIMB_TOWER or
    _rankType==RANK_TYPE.HERO_FORCE_RANK then
        return true
    end

    return false
end

local myRankingReward=ConfigManager.GetConfig(ConfigName.RankingRewardConfig)
--宝箱红点
function this.IsRankingTopRed(_rankType)
    local typeId=0
    if _rankType==RANK_TYPE.FIGHT_LEVEL_RANK then
        typeId=1
    elseif _rankType==RANK_TYPE.FORCE_RANK or _rankType==RANK_TYPE.FORCE_CURR_RANK then 
        typeId=2
    elseif _rankType==RANK_TYPE.CLIMB_TOWER then
        typeId=3
    elseif _rankType==RANK_TYPE.HERO_FORCE_RANK then
        typeId=4
    end

    for id,lis in pairs(this.RankingTopInfo) do
        if myRankingReward[id].Type==typeId and not this.IsInRewardedList(id) then
            -- LogError(" is reward" ..typeId .. " rewardlen" ..#this.RankingRewardedList)
            return true
        end
    end
    -- LogError(" not reward" ..typeId .. " rewardlen" ..#this.RankingRewardedList)
    return false
end

function this.IsInRewardedList(_id)
    if #this.RankingRewardedList>0 then
        for _,id in pairs(this.RankingRewardedList) do
            if id==_id then
                return true
            end
        end
    end
    return false
end

--排行红点 1-4 排行类型存在
function this.RefreshRankingRewardRedPoint()
    for i=1,4 do
        for id,lis in pairs(this.RankingTopInfo) do
            if not this.IsInRewardedList(id) then
                return true
            end
        end
    end
    return false
end

return this