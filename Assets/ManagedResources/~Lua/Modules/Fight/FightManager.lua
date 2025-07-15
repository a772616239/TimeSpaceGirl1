FightManager = {};
local this = FightManager
--this.rewardGroupConfig = ConfigManager.GetConfig(ConfigName.RewardGroup)
this.levelSetting = ConfigManager.GetConfig(ConfigName.LevelSetting)
this.levelDifficultyConfig = ConfigManager.GetConfig(ConfigName.LevelDifficultyConfig)
local globalSystemConfig = ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)

this.fightList={}
this.oldLevel=0
local curSmallFightId=0
local newOpenSmallFightId=0
this.curIsInFightArea = 0--是否进关卡
this.isOpenLevelPat = false --是否弹关卡章节开启
function this.Initialize()
    --this.InitAllMapPgData()
end
--初始化所有关卡
function this.InitAllMapPgData(_msgFightList)
    this.fightList = {}
    local levelSettingKeys = GameDataBase.SheetBase.GetKeys(this.levelSetting)
    for i=1, #levelSettingKeys do
        local curFightData={}
        curFightData.fightId=this.levelSetting[levelSettingKeys[i]].Id
        curFightData.levelSettingConfig=this.levelSetting[levelSettingKeys[i]]
        curFightData.simpleLevel={}
        curFightData.nrmalLevel={}
        curFightData.difficultyLevel={}
        for i = 1, #curFightData.levelSettingConfig.SimpleLevel do
            local simpleLevelData={}
            simpleLevelData.fightId=curFightData.levelSettingConfig.SimpleLevel[i]
            simpleLevelData.state=SingleFightState.NoOpen--1 未开启 2 已开启 3 未通关  4 已通关
            simpleLevelData.num=1--打过多少次
            if this.levelDifficultyConfig[simpleLevelData.fightId] then
                simpleLevelData.fightData=this.levelDifficultyConfig[simpleLevelData.fightId]
            end
            table.insert( curFightData.simpleLevel,simpleLevelData)
        end
        for i = 1, #curFightData.levelSettingConfig.NormalLevel do
            local nrmalLevelData={}
            nrmalLevelData.fightId=curFightData.levelSettingConfig.NormalLevel[i]
            nrmalLevelData.state=SingleFightState.NoOpen--1 未开启 2 已开启 3 未通关  4 已通关
            nrmalLevelData.num=1--打过多少次
            if this.levelDifficultyConfig[nrmalLevelData.fightId] then
                nrmalLevelData.fightData=this.levelDifficultyConfig[nrmalLevelData.fightId]
            end
            table.insert( curFightData.nrmalLevel,nrmalLevelData)
        end
        for i = 1, #curFightData.levelSettingConfig.DifficultyLevel do
            local difficultyLevelData={}
            difficultyLevelData.fightId=curFightData.levelSettingConfig.DifficultyLevel[i]
            difficultyLevelData.state=SingleFightState.NoOpen--1 未开启 2 已开启 3 未通关  4 已通关
            difficultyLevelData.num=1--打过多少次
            if this.levelDifficultyConfig[difficultyLevelData.fightId] then
                difficultyLevelData.fightData=this.levelDifficultyConfig[difficultyLevelData.fightId]
            end
            table.insert( curFightData.difficultyLevel,difficultyLevelData)
        end
        this.fightList[curFightData.fightId]=curFightData
    end
    --table.sort(this.fightList, function(a,b) return a.fightId < b.fightId end)
    this.UpdateFightDatas(_msgFightList)
end
--后端关卡信息初始化
function this.UpdateFightDatas(_msgFightList)
    
    for i = 1, #_msgFightList do
        if this.fightList[_msgFightList[i].areaId] then
            for j = 1, #_msgFightList[i].LevelDifficulty do
                local level = _msgFightList[i].LevelDifficulty[j]
                if level.type==1 then
                    local curSimpleLevel = this.fightList[_msgFightList[i].areaId].simpleLevel
                    for k = 1, #curSimpleLevel do
                        if curSimpleLevel[k].fightId==level.fightId then
                            curSimpleLevel[k].num=level.num
                            --为后端做的判断
                            if PlayerManager.level >= curSimpleLevel[k].fightData.LevelLimit then
                                --this.SetCurInSmallFightId(math.floor(level.fightId))--%10
                                curSimpleLevel[k].state=level.state
                            end
                            if curSimpleLevel[k].state == SingleFightState.Open then

                                this.SetCurInSmallFightId(math.floor(curSimpleLevel[k].fightId))--%10
                            end
                           break
                        end
                    end
                elseif level.type==2 then
                    local curNrmalLevel = this.fightList[_msgFightList[i].areaId].nrmalLevel
                    for k = 1, #curNrmalLevel do
                        if curNrmalLevel[k].fightId==level.fightId then
                            curNrmalLevel[k].num=level.num
                            if PlayerManager.level >= curNrmalLevel[k].fightData.LevelLimit then
                                --this.SetCurInSmallFightId(math.floor(level.fightId))
                                curNrmalLevel[k].state=level.state
                            end
                            if curNrmalLevel[k].state == SingleFightState.Open then

                                this.SetCurInSmallFightId(math.floor(curNrmalLevel[k].fightId))--%10
                            end
                            break
                        end
                    end
                elseif level.type==3 then
                    local curDifficultyLevel = this.fightList[_msgFightList[i].areaId].difficultyLevel
                    for k = 1, #curDifficultyLevel do
                        if curDifficultyLevel[k].fightId==level.fightId then
                            curDifficultyLevel[k].num=level.num
                            if PlayerManager.level >= curDifficultyLevel[k].fightData.LevelLimit then
                                --this.SetCurInSmallFightId(math.floor(level.fightId))
                                curDifficultyLevel[k].state=level.state
                            end
                            if curDifficultyLevel[k].state == SingleFightState.Open then

                                this.SetCurInSmallFightId(math.floor(curDifficultyLevel[k].fightId))--%10
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end
--获取单个区域所有信息
function this.GetSingleFightData(_areaId)
    if this.fightList[_areaId] then
        return this.fightList[_areaId]
    end
    return nil
end
--获取单个关卡所有信息
function this.GetSingleFightDataByFightId(_fightId)
    local areaId=math.floor(_fightId/1000)
    local difficultyType=math.floor(_fightId%10)
    local areaData = this.fightList[areaId]
    if areaData then
        if difficultyType == FightDifficultyState.SimpleLevel then--简单
            for i = 1, #areaData.simpleLevel do
                if areaData.simpleLevel[i].fightId == _fightId then
                    return areaData.simpleLevel[i]
                end
            end
        elseif difficultyType == FightDifficultyState.NrmalLevel then--普通
            for i = 1, #areaData.nrmalLevel do
                if areaData.nrmalLevel[i].fightId == _fightId then
                    return areaData.nrmalLevel[i]
                end
            end
        elseif difficultyType == FightDifficultyState.DifficultyLevel then--困难
            for i = 1, #areaData.difficultyLevel do
                if areaData.difficultyLevel[i].fightId == _fightId then
                    return areaData.difficultyLevel[i]
                end
            end
        end
    end
    return nil
end
--获取某个关卡状态信息
function this.SetAndGetSingleFightState(_fightd,_setType,_state)--_setType   1 设置   2 获取
    local areaId=math.floor(_fightd/1000)
    local diffTypr=math.floor(_fightd%10)
    if this.fightList[areaId] then
        if diffTypr==FightDifficultyState.SimpleLevel then
            for i = 1, #this.fightList[areaId].simpleLevel do
                if this.fightList[areaId].simpleLevel[i].fightId==_fightd then
                    if _setType==1 and this.fightList[areaId].simpleLevel[i].state<SingleFightState.Pass then
                       this.fightList[areaId].simpleLevel[i].state=_state
                    else
                        return this.fightList[areaId].simpleLevel[i].state
                    end
                    break
                end
            end
        elseif diffTypr==FightDifficultyState.NrmalLevel then
            for i = 1, #this.fightList[areaId].nrmalLevel do
                if this.fightList[areaId].nrmalLevel[i].fightId==_fightd then
                    if _setType==1 and this.fightList[areaId].nrmalLevel[i].state<SingleFightState.Pass then
                        this.fightList[areaId].nrmalLevel[i].state=_state
                    else
                        return this.fightList[areaId].nrmalLevel[i].state
                    end
                    break
                end
            end
        elseif diffTypr==FightDifficultyState.DifficultyLevel then
            for i = 1, #this.fightList[areaId].difficultyLevel do
                if this.fightList[areaId].difficultyLevel[i].fightId==_fightd then
                    if _setType==1 and this.fightList[areaId].difficultyLevel[i].state<SingleFightState.Pass then
                        this.fightList[areaId].difficultyLevel[i].state=_state
                    else
                        return this.fightList[areaId].difficultyLevel[i].state
                    end
                    break
                end
            end
        end
    end
    if _setType==1 and _state==SingleFightState.Pass then--设置  并且 已通关

        this.SetAndGetSingleFightState2(_fightd)
        CheckRedPointStatus(RedPointType.NormalExplore_OpenMap)
        --Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnPassFight)
        Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.ActivityGift)
        RedPointManager.SetExploreRedPoint({fightId = _fightd})
        -- 检测红点
        CheckRedPointStatus(RedPointType.CourtesyDress_Chapter)
        CheckRedPointStatus(RedPointType.SecretTer)
    end
end
function this.SetAndGetSingleFightState2(_fightd)
    this.isOpenLevelPat = false
    for k, v in pairs(this.fightList) do
        for i = 1, #v.simpleLevel do
            if v.simpleLevel[i].fightData.Precondition==_fightd then
                if v.simpleLevel[i].state==SingleFightState.NoOpen and PlayerManager.level>=v.simpleLevel[i].fightData.LevelLimit then

                    v.simpleLevel[i].state=SingleFightState.Open

                    Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnOpenFight,v.simpleLevel[i].fightId)
                    this.SetCurInSmallFightId(math.floor(v.simpleLevel[i].fightId))--%10
                    this.isOpenLevelPat = true
                end
            end
        end
        for i = 1, #v.nrmalLevel do
            if v.nrmalLevel[i].fightData.Precondition==_fightd  then
                if v.nrmalLevel[i].state==SingleFightState.NoOpen and PlayerManager.level>=v.nrmalLevel[i].fightData.LevelLimit then
                    v.nrmalLevel[i].state=SingleFightState.Open

                    Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnOpenFight,v.nrmalLevel[i].fightId)
                    this.SetCurInSmallFightId(math.floor(v.nrmalLevel[i].fightId))--%10
                    this.isOpenLevelPat = true
                end
            end
        end
        for i = 1, #v.difficultyLevel do
            if v.difficultyLevel[i].fightData.Precondition==_fightd  then
                if v.difficultyLevel[i].state==SingleFightState.NoOpen  and PlayerManager.level>=v.difficultyLevel[i].fightData.LevelLimit then
                    v.difficultyLevel[i].state=SingleFightState.Open

                    Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnOpenFight,v.difficultyLevel[i].fightId)
                    this.SetCurInSmallFightId(math.floor(v.difficultyLevel[i].fightId))--%10
                    this.isOpenLevelPat = true
                end
            end
        end
    end
end
function this.SetAndGetSingleFightState3(_level)

    this.isOpenLevelPat = false
    for k, v in pairs(this.fightList) do
        for i = 1, #v.simpleLevel do
            if v.simpleLevel[i].fightData.LevelLimit==_level then--this.SetAndGetSingleFightState(_fightd,_setType,_state)--_setType   1 设置   2 获取
                if v.simpleLevel[i].state==SingleFightState.NoOpen  then
                    if this.SetAndGetSingleFightState(v.simpleLevel[i].fightData.Precondition,2)>=SingleFightState.Pass then

                        v.simpleLevel[i].state=SingleFightState.Open

                        --if v.simpleLevel[i].fightData.Precondition~=1051 then--_fightd~=1051  为新手引导做的特殊判断
                            this.SetCurInSmallFightId(math.floor(v.simpleLevel[i].fightId))--%10
                        this.isOpenLevelPat = true
                        --end
                    end
                end
            end
        end
        for i = 1, #v.nrmalLevel do
            if v.nrmalLevel[i].fightData.LevelLimit==_level then
                if v.nrmalLevel[i].state==SingleFightState.NoOpen  then
                    if this.SetAndGetSingleFightState(v.nrmalLevel[i].fightData.Precondition,2)>=SingleFightState.Pass then
                        if v.nrmalLevel[i].state==SingleFightState.NoOpen then
                            v.nrmalLevel[i].state=SingleFightState.Open

                            this.SetCurInSmallFightId(math.floor(v.nrmalLevel[i].fightId))--%10
                            this.isOpenLevelPat = true
                        end

                    end
                end
            end
            for i = 1, #v.difficultyLevel do
                if v.difficultyLevel[i].fightData.LevelLimit==_level then
                    if v.difficultyLevel[i].state==SingleFightState.NoOpen then
                        if this.SetAndGetSingleFightState(v.difficultyLevel[i].fightData.Precondition,2)>=SingleFightState.Pass then
                            if v.difficultyLevel[i].state==SingleFightState.NoOpen then
                                v.difficultyLevel[i].state=SingleFightState.Open

                                this.SetCurInSmallFightId(math.floor(v.difficultyLevel[i].fightId))--%10
                                this.isOpenLevelPat = true
                            end

                        end
                    end
                end
            end
        end
    end
    end
--获取某个区域某个难度是否开启
function this.GetFightIsOpen(_area,_diffType)--_diffType  0 所有难度  1 简单  2 普通  3 困难
    local fightData=0
    if this.fightList[_area] then
        if _diffType==FightDifficultyState.SimpleLevel or _diffType==0 then
            for i = 1, #this.fightList[_area].simpleLevel do
                if this.fightList[_area].simpleLevel[i].state>SingleFightState.NoOpen then
                    return true
                elseif i==1 then
                    fightData=this.levelDifficultyConfig[this.fightList[_area].simpleLevel[i].fightId]
                end
            end
        elseif _diffType==FightDifficultyState.NrmalLevel or _diffType==0 then
            for i = 1, #this.fightList[_area].nrmalLevel do
                if this.fightList[_area].nrmalLevel[i].state>SingleFightState.NoOpen then
                    return true
                elseif i==1 then
                    fightData=this.levelDifficultyConfig[this.fightList[_area].nrmalLevel[i].fightId]
                end
            end
        elseif _diffType==FightDifficultyState.DifficultyLevel or _diffType==0 then
            for i = 1, #this.fightList[_area].difficultyLevel do
                if this.fightList[_area].difficultyLevel[i].state>SingleFightState.NoOpen then
                    return true
                elseif i==1 then
                    fightData=this.levelDifficultyConfig[this.fightList[_area].difficultyLevel[i].fightId]
                end
            end
        end
        return false,fightData
    else
        return false,fightData
    end
end
--获取某个区域某个难度是否开启
function this.GetSingleAreaIsPass(_area)
    local isPass=true
    if this.fightList[_area] then
        for i = 1, #this.fightList[_area].simpleLevel do
            if this.fightList[_area].simpleLevel[i].state<SingleFightState.Pass then
                isPass = false
                break
            end
        end
    end
    return isPass
end
this.curWarFightId = 0
--执行关卡战斗
function this.ExecuteFightBattle(monsterGroupId, fightId, callBack)

    this.curWarFightId = fightId
    NetManager.LevelStarFightDataRequest(monsterGroupId, fightId, function (msg)
        this.SetAndGetSingleFightState(fightId,1,SingleFightState.NoPass)
        --this.SetCurInSmallFightId(fightId)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.STORY_FIGHT, callBack)
        end)
    end)
end
--战斗后回调
function this.BattleEndCallBack(lastBattleResult)
   
    if lastBattleResult.result==0 then
    else
        local curFightOpenId = this.GetCurInSmallFightId()
        if curFightOpenId and curFightOpenId > 0 and this.levelDifficultyConfig[curFightOpenId] and this.levelDifficultyConfig[curFightOpenId].Cost then
            --BagManager.UpdateItemsNum(this.levelDifficultyConfig[curFightOpenId].Cost[1][1],this.levelDifficultyConfig[curFightOpenId].Cost[1][2])--进图扣一点  胜利再扣5点  失败不扣
            this.SetAndGetSingleFightState(this.curWarFightId,1,SingleFightState.Pass)
        end
    end
end
--设置当前进入的小关卡id
function this.SetCurInSmallFightId(_fightId)
    curSmallFightId=_fightId
end
--获取当前进入的小关卡id
function this.GetCurInSmallFightId()
    if curSmallFightId > 0 then
        return curSmallFightId
    else
        local curSmallFightId =0
        for k, v in pairs(this.fightList) do
            for i = 1, #v.simpleLevel do
                if v.simpleLevel[i].state==SingleFightState.Open or  v.simpleLevel[i].state==SingleFightState.NoPass or v.simpleLevel[i].state==SingleFightState.Pass then
                    if  v.simpleLevel[i].fightId%10 >= curSmallFightId%10 then
                        if v.simpleLevel[i].fightId > curSmallFightId then
                            curSmallFightId = v.simpleLevel[i].fightId
                        end
                    end
                end
            end
            for i = 1, #v.nrmalLevel do
                if v.nrmalLevel[i].state==SingleFightState.Open or  v.nrmalLevel[i].state==SingleFightState.NoPass or v.nrmalLevel[i].state==SingleFightState.Pass then
                    if v.nrmalLevel[i].fightId%10 >= curSmallFightId%10 then
                        if v.nrmalLevel[i].fightId > curSmallFightId then
                            curSmallFightId = v.nrmalLevel[i].fightId
                        end
                    end
                end
            end
            for i = 1, #v.difficultyLevel do
                if v.difficultyLevel[i].state==SingleFightState.Open or  v.difficultyLevel[i].state==SingleFightState.NoPass or v.difficultyLevel[i].state==SingleFightState.Pass then
                    if v.difficultyLevel[i].fightId%10 >= curSmallFightId%10 then
                        if v.difficultyLevel[i].fightId > curSmallFightId then
                            curSmallFightId = v.difficultyLevel[i].fightId
                        end
                    end
                end
            end
        end
        return curSmallFightId
    end
end
function this.SetNewOpenFightId(_newOpenSmallFightId)
    newOpenSmallFightId = _newOpenSmallFightId
end
--当前通关关卡 和 当前达到玩家等级 解锁的功能list
function this.GetPlayerAndLevelPassOpenFun(playerLv)
    local openFunDataList = {}
    for i, v in ConfigPairs(globalSystemConfig) do
        if v.OpenRules then
            local type = v.OpenRules[1]
            if type == 1 then--1关卡开启
                if v.OpenRules[2] == FightPointPassManager.lastPassFightId and  v.IsOpen == 1 and  v.IsShow == 1 then
                    table.insert(openFunDataList,v)
                end
            elseif type == 2 then--2玩家等级开启
                if v.OpenRules[2] == playerLv and  v.IsOpen == 1 and  v.IsShow == 1  then
                    table.insert(openFunDataList,v)
                end
            end
        end
    end
    return openFunDataList
end
--预先显示玩家等级 解锁的功能list
function this.GetNextPlayerAndLevelPassOpenFun(playerLv)
    local openFunDataList = {}
    local needLv = 0
    local nextFightId = 0
    local nextFightSortId = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,FightPointPassManager.curOpenFight).SortId - 1
    --if FightPointPassManager.curOpenFight == nil or FightPointPassManager.curOpenFight and FightPointPassManager.curOpenFight <= 0 then
    --    nextFightSortId = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,FightPointPassManager.lastPassFightId).SortId
    --else
    --    nextFightSortId = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,FightPointPassManager.curOpenFight).SortId
    --end
    for i, v in ConfigPairs(globalSystemConfig) do
        if v.OpenRules then
            local type = v.OpenRules[1]
            if type == 1 then--1关卡开启
                local OpenRulesSortId = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,v.OpenRules[2]).SortId
                if OpenRulesSortId > nextFightSortId
                        and  v.IsOpen == 1 and  v.IsShow == 1  then
                    if nextFightId == 0 then
                        nextFightId = v.OpenRules[2]
                    else
                        if ConfigManager.GetConfigData(ConfigName.MainLevelConfig,nextFightId).SortId >
                                OpenRulesSortId  then
                            nextFightId = v.OpenRules[2]
                        end
                    end
                end
            elseif type == 2 then--2玩家等级开启
                if v.OpenRules[2] > playerLv and  v.IsOpen == 1 and  v.IsShow == 1  then
                    if needLv == 0 then
                        needLv = v.OpenRules[2]
                    else
                        if needLv > v.OpenRules[2]  then
                            needLv = v.OpenRules[2]
                        end
                    end
                end
            end
        end
    end
    for i, v in ConfigPairs(globalSystemConfig) do
        if v.OpenRules then
            local type = v.OpenRules[1]
            if type == 1 then--1关卡开启
                if v.OpenRules[2] == nextFightId and  v.IsOpen == 1 and  v.IsShow == 1 then
                    table.insert(openFunDataList,v)
                end
            elseif type == 2 then--2玩家等级开启
                if v.OpenRules[2] == needLv and  v.IsOpen == 1 and  v.IsShow == 1 then
                    table.insert(openFunDataList,v)
                end
            end
            end
    end
    return needLv,openFunDataList
end
return this