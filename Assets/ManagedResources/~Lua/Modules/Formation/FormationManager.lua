FormationManager = {}
local this = FormationManager
local ChallengeData = ConfigManager.GetConfig(ConfigName.ChallengeConfig)
local specialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local formationConfig = ConfigManager.GetConfig(ConfigName.FormationConfig)
local FormationBuffConfig = ConfigManager.GetConfig(ConfigName.FormationBuffConfig)

this.AllFormationFunIds = {
    [1] = JumpType.Level,
    [601] = JumpType.BeastIncomingTide,
    [101] = JumpType.Arena,
    [201] = JumpType.Arena,
    [401] = JumpType.EndlessFight,
    [501] = JumpType.Guild,
    [502] = JumpType.Guild
}
function this.Initialize()
    this.currentFormationIndex = 0
end

this.MirrorFormationList = {}

function this.MakeAEmptyTeam(teamId)
    local oTeam = {}
    oTeam.teamId = teamId
    if teamId < FormationTypeDef.FORMATION_ARENA_DEFEND then
        oTeam.teamName = GetLanguageStrById(10674)
    elseif teamId == FormationTypeDef.FORMATION_ARENA_DEFEND then
        oTeam.teamName = GetLanguageStrById(10676)
    elseif teamId == FormationTypeDef.FORMATION_ARENA_ATTACK then
        oTeam.teamName = GetLanguageStrById(10677)
    elseif teamId == FormationTypeDef.FORMATION_DREAMLAND then
        oTeam.teamName = GetLanguageStrById(10678)
    elseif teamId == FormationTypeDef.FORMATION_ENDLESS_MAP then
        oTeam.teamName = GetLanguageStrById(10679)
    elseif teamId == FormationTypeDef.FORMATION_GUILD_FIGHT_DEFEND then
        oTeam.teamName = GetLanguageStrById(10680)
    elseif teamId == FormationTypeDef.FORMATION_GUILD_FIGHT_ATTACK then
        oTeam.teamName = GetLanguageStrById(10681)
    elseif teamId == FormationTypeDef.MONSTER_CAMP_ATTACK then
        oTeam.teamName = GetLanguageStrById(10675)
    elseif teamId == FormationTypeDef.BLOODY_BATTLE_ATTACK then
        oTeam.teamName = GetLanguageStrById(10682)
    -- elseif teamId == FormationTypeDef.GUILD_BOSS then
    --     oTeam.teamName = " 公会Boss"-- 901
    elseif teamId == FormationTypeDef.EXPEDITION then
        oTeam.teamName = GetLanguageStrById(10683)
    elseif teamId == FormationTypeDef.GUILD_CAR_DELEAY then
        oTeam.teamName = GetLanguageStrById(50283)
    elseif teamId == FormationTypeDef.GUILD_CAR_DELEAY then
        oTeam.teamName = GetLanguageStrById(50283)
    elseif teamId == FormationTypeDef.ARENA_TOM_MATCH then
        oTeam.teamName = GetLanguageStrById(12280)
    elseif teamId == FormationTypeDef.CLIMB_TOWER then
        oTeam.teamName = GetLanguageStrById(12535)
    elseif teamId == FormationTypeDef.Arden_MIRROR then
        oTeam.teamName = GetLanguageStrById(22412)
    elseif teamId == FormationTypeDef.GUILD_TRANSCRIPT then
        oTeam.teamName = GetLanguageStrById(12387)
    elseif teamId == FormationTypeDef.DEFENSE_TRAINING then
        oTeam.teamName = GetLanguageStrById(22413)
    elseif teamId == FormationTypeDef.BLITZ_STRIKE then
        oTeam.teamName = GetLanguageStrById(22414)
    elseif teamId == FormationTypeDef.CONTEND_HEGEMONY then
        oTeam.teamName = GetLanguageStrById(22415)
    elseif teamId == FormationTypeDef.FORMATION_AoLiaoer then
        oTeam.teamName = GetLanguageStrById(50284)
    elseif teamId == FormationTypeDef.FORMATION_AoLiaoer then
        oTeam.teamName = GetLanguageStrById(50284)
    elseif teamId == FormationTypeDef.FORMATION_AoLiaoer then
        oTeam.teamName = GetLanguageStrById(50284)
    elseif teamId == FormationTypeDef.ALAMEIN_WAR then
        oTeam.teamName = GetLanguageStrById(50285)
    elseif teamId == FormationTypeDef.LADDERS_DEFEND then
        oTeam.teamName = GetLanguageStrById(50228)
    elseif teamId == FormationTypeDef.CHAOS_BATTLE then
        oTeam.teamName = GetLanguageStrById(50367)
    else
        LogRed(string.format("打印:没有%s对应的teamId", teamId))
        oTeam.teamName = ""
    end
    oTeam.teamHeroInfos = {}
    oTeam.teamPokemonInfos = {}
    oTeam.formationId = 1
    oTeam.supportId = 0
    oTeam.adjutantId = 0
    oTeam.substitute = ""
    return oTeam
end

-- 刷新编队信息
function this.RefreshFormationData(func)
    NetManager.TeamInfoRequest(func)
end

this.backpackLimit = 0

--刷新编队数据
function this.UpdateFormation(msg)
    this.formationList = {}
    --新加背包上限
    --this.backpackLimit = msg.backpackLimit

    this.curFormationIndex = this.SetCurFormationIndex()

    for i, team in ipairs(msg.TeamPosInfo) do
        local oTeam = this.MakeAEmptyTeam(team.teamId)

        for j = 1, #team.teamHeroInfos do
            local teamHeroInfo = team.teamHeroInfos[j]
            table.insert(oTeam.teamHeroInfos, teamHeroInfo)
        end

        -- for j = 1, #team.teamPokemonInfos do
        --     local teamPokemonInfo = team.teamPokemonInfos[j]
        --     table.insert(oTeam.teamPokemonInfos, teamPokemonInfo)
        -- end

        oTeam.formationId = team.formationId
        oTeam.supportId = team.supportId
        oTeam.adjutantId = team.adjutantId
        oTeam.substitute = team.substitute
        SupportManager.SetFormationSupportId(team.teamId, oTeam.supportId)
        AdjutantManager.SetFormationAdjutantId(team.teamId, oTeam.adjutantId)
        this.formationList[team.teamId] = oTeam
    end
    -- if #msg.TeamPosInfo == 0 then
    --     for i = 1, 3 do
    --         local curFormation = {}
    --         curFormation.teamId = i
    --         curFormation.teamName = GetLanguageStrById(10674)--GetLanguageStrById(10675) .. i
    --         curFormation.teamHeroInfos = {}
    --         -- curFormation.teamPokemonInfos = {}
    --         this.formationList[i] = curFormation
    --     end
    -- end


    -- 获取数据时检测一下公会战防守数据
    this.CheckGuildFightDefendFormation()
end

function this.SetCurFormationIndex()
    local curIndex = 1
    local curMapId = PlayerManager.curMapId
    local carbonType = 1
    if curMapId and curMapId > 0 then
        carbonType = ChallengeData[curMapId].Type
    end
    curIndex = carbonType == 4 and 401 or 1
    return curIndex
end

--> formationId 阵型
function FormationManager.RefreshFormation(index, roleList, tibuRole, dataTrans, isDiffmonster, formationId,fun)--index编队 roleList编队数据 formationId阵型 
    local curFormation = this.formationList[index]
    if not curFormation or #this.formationList == 0 then
        return
    end

    curFormation.teamHeroInfos = {}

    local isHaveHero = true
    for i = 1, #roleList do
        local teamInfo = {}
        teamInfo.heroId = roleList[i].heroId--roleList[i]
        teamInfo.position = roleList[i].position--i
        table.insert(curFormation.teamHeroInfos, teamInfo)
        --只针对于奥廖尔阵营  阵营坦克大于一辆则重新考虑
        local hero = HeroManager.GetSingleHeroData(roleList[i].heroId)
        if hero == nil then
            isHaveHero = false
        else
            isHaveHero = true
        end
    end
    -- curFormation.teamPokemonInfos = {}
    -- for j = 1, #pokemonList do
        --     --#curFormation.teamPokemonInfos
        --     local teamPokemonInfo = {}
        --     teamPokemonInfo.pokemonId = pokemonList[j].pokemonId
        --     teamPokemonInfo.position = pokemonList[j].position
        --     table.insert(curFormation.teamPokemonInfos, teamPokemonInfo)
    -- end
    if tibuRole == nil then tibuRole = "" end
    curFormation.substitute = tibuRole
    curFormation.formationId = formationId
    curFormation.supportId = dataTrans.supportId
    curFormation.adjutantId = dataTrans.adjutantId
    NetManager.TeamInfoSaveRequest(curFormation, function()
        Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnFormationChange,isDiffmonster)
        if fun then
            fun()
        end
    end)

    if isHaveHero then
       this.UserPowerChanged(index)
    end
end

-- 获取所有正在编队的英雄id
function this.GetAllFormationHeroId()
    local list = {}
    local index = 1
    for i, team in pairs(this.formationList) do
        for j = 1, #team.teamHeroInfos do
            list[team.teamHeroInfos[j].heroId] = index
            index = index + 1
        end
    end
    return list
end
--获取单个编队所有上阵英雄
function this.GetWuJinFormationHeroIds(index)
   local forMationData = this.GetFormationByID(index).teamHeroInfos
    local index = 1
    local list = {}
    for j = 1, #forMationData do
        list[forMationData[j].heroId] = index
        index = index + 1
    end
    return list
end
-- 获取编队信息
function FormationManager.GetFormationByID(teamId)
    if not teamId then
        return
    end
    
    if not this.formationList then return nil end
    if not this.formationList[teamId] then
        this.formationList[teamId] = this.MakeAEmptyTeam(teamId)
    end
    --根据配置表 解锁功能时复制主线阵容 的配置
    for i, v in ipairs(string.split(specialConfig[47].Value, "#")) do
       
        local _v = tonumber(v)

        if teamId == _v and #this.formationList[teamId].teamHeroInfos <= 0 then
            for n = 1, #this.formationList[1].teamHeroInfos do
                table.insert(this.formationList[teamId].teamHeroInfos, this.formationList[1].teamHeroInfos[n])
            end
            -- 
            FormationManager.RefreshFormation(teamId, this.formationList[teamId].teamHeroInfos, this.formationList[teamId].substitute,
            {supportId = SupportManager.GetFormationSupportId(teamId),
            adjutantId = AdjutantManager.GetFormationAdjutantId(teamId)}, nil, this.formationList[teamId].formationId)

            return this.formationList[teamId]
        end
    end

    return this.formationList[teamId]
end

-- 获取编队镜像信息
function FormationManager.GetTeamPosMirrorInfo(teamId,func)
    if not teamId then
        return
    end
    NetManager.GetTeamPosMirrorInfoRequest(teamId,function(msg)
        this.curFormationIndex = teamId
        for i, team in ipairs(msg.TeamPosInfo) do
            local oTeam = this.MakeAEmptyTeam(team.teamId)
            for j = 1, #team.teamHeroInfos do
                local teamHeroInfo = team.teamHeroInfos[j]
                table.insert(oTeam.teamHeroInfos, teamHeroInfo)
            end
            oTeam.formationId = team.formationId
            oTeam.supportId = team.supportId
            oTeam.adjutantId = team.adjutantId
            SupportManager.SetFormationSupportId(team.teamId, oTeam.supportId)
            AdjutantManager.SetFormationAdjutantId(team.teamId, oTeam.adjutantId)
            this.MirrorFormationList[team.teamId] = oTeam
        end
        if func then
            func(this.MirrorFormationList[teamId])
        end
   end)
end

-- 获取编队总战斗力
function this.GetFormationPower(formationId)
    if not formationId then
        return
    end
    --获取当前编队数据
    if formationId == FormationTypeDef.EXPEDITION then
        ExpeditionManager.ExpeditionRrefreshFormation()--刷新编队
    end
    local formationList = this.GetFormationByID(formationId)
    if formationList== nil then
        return 0
    end

    local power = 0
    for i = 1, 6 do
        if formationList.teamHeroInfos[i] then
            local heroData = HeroManager.GetSingleHeroData(formationList.teamHeroInfos[i].heroId)
            --1, curHeroData.dynamicId, false,nil,nil,true,allHeroTeamAddProVal)
            if #formationList.teamHeroInfos <= 0 then return 0 end
            local allHeroTeamAddProVal = HeroManager.GetAllHeroTeamAddProVal(formationList.teamHeroInfos,formationList.teamHeroInfos[i].heroId)
            local allEquipAddProVal = HeroManager.CalculateHeroAllProValList(1, heroData.dynamicId,false,nil,nil,true,allHeroTeamAddProVal)
            if allEquipAddProVal~=nil then
                power = power + allEquipAddProVal[HeroProType.WarPower]
            end
        end
    end
    -- substitute 为 dynamicId 需要转化
    if formationList.substitute ~= "" and formationList.substitute ~= nil then
        -- local heroDid = HeroManager.GetSingleHeroData(formationList.substitute).id
        -- local allHeroTeamAddProVal = HeroManager.GetAllHeroTeamAddProVal(formationList.teamHeroInfos,heroDid)
        local allEquipAddProVal = HeroManager.CalculateHeroAllProValList(1, formationList.substitute,false,nil,nil,true,allHeroTeamAddProVal)
        if allEquipAddProVal~=nil then
            power = power + allEquipAddProVal[HeroProType.WarPower]
        end
    end
    -- 主线编队战斗力
    -- ThinkingAnalyticsManager.SetSuperProperties({
    --     fighting_capacity = power,
    -- })
    return power
end

--某个妖灵师战力发生变化检查是否在任何一个编队
function this.CheckHeroIdExist(heroId)
    for _, formationData in pairs(this.formationList) do
        table.walk(formationData.teamHeroInfos, function(teamInfo)
            if heroId == teamInfo.heroId then
                this.UserPowerChanged()
            end
        end)
    end
end

function this.UserPowerChanged(teamId)
    local teamId = teamId or FormationTypeDef.FORMATION_NORMAL
    local maxPower = 0
    for _, teamInfo in pairs(this.formationList) do
        if teamId == teamInfo.teamId then
            if #teamInfo.teamHeroInfos > 0 then
                if this.GetFormationPower(teamInfo.teamId) > maxPower then
                    maxPower = this.GetFormationPower(teamInfo.teamId)
                end
            end
        end
    end
    if maxPower > PlayerManager.maxForce then
        NetManager.RequestUserForceChange(FormationTypeDef.FORMATION_NORMAL)
        PlayerManager.maxForce = maxPower
        Game.GlobalEvent:DispatchEvent(GameEvent.CustomEvent.OnPowerChange,PlayerManager.maxForce)
    end
end

function this.GetMaxPowerForTeamID(teamId)
    if this.formationList==nil  then
        return
    end
    local teamId = teamId or FormationTypeDef.FORMATION_NORMAL
    local maxPower = 0
    for _, teamInfo in pairs(this.formationList) do
        if teamId == teamInfo.teamId then
            if #teamInfo.teamHeroInfos > 0 then
                if this.GetFormationPower(teamInfo.teamId) > maxPower then
                    maxPower = this.GetFormationPower(teamInfo.teamId)
                end
            end
        end
    end
    return maxPower
end

-- 获取相应编队的血量数据
function this.GetFormationHeroHp(formationIndex, dhId)
    if formationIndex == FormationTypeDef.FORMATION_ENDLESS_MAP then
        local data = EndLessMapManager.allHeroBlood[dhId]
        if not data then return end
        return data.percentHp
    elseif formationIndex == FormationTypeDef.FORMATION_GUILD_FIGHT_ATTACK then
        local dataList = GuildFightManager.GetMyHeroBloodData()
        local data = dataList[dhId]
        if not data then return end
        return data
    elseif formationIndex == FormationTypeDef.EXPEDITION then
        local data = ExpeditionManager.heroInfo[dhId]
        if not data then return end
        return data.remainHp
    elseif formationIndex == FormationTypeDef.DEFENSE_TRAINING then
        local data = DefenseTrainingManager.heroInfo[dhId]
        if not data then return end
        return data.remainHp
    elseif formationIndex == FormationTypeDef.BLITZ_STRIKE then
        local data = BlitzStrikeManager.heroInfo[dhId]
        if not data then return end
        return data.remainHp
    end

end

-- 检测编队正确性
function this.CheckFormationHp(formationIndex)
    local formation = this.GetFormationByID(formationIndex)
    local newFormation = {}
    local newIndex = 1
    for index = 1, #formation.teamHeroInfos do
        local teamInfo = formation.teamHeroInfos[index]
        local hp = this.GetFormationHeroHp(formationIndex, teamInfo.heroId)
        if hp > 0 then
            local singleData = {}
            singleData.heroId = teamInfo.heroId
            singleData.position = newIndex
            newIndex = newIndex + 1
            table.insert(newFormation, singleData)
        end
    end
    this.RefreshFormation(formationIndex, newFormation, formation.teamPokemonInfos)
end

-- 检测编队是否有上阵人数
function this.CheckFormationValid(teamId)
    local team = this.GetFormationByID(teamId)
    local isValid = #team.teamHeroInfos > 0
    return isValid
end

-- 检测公会战防守阶段玩家防守阵容正确性，防守阵容为空时将主线阵容复制到防守阵容
function FormationManager.CheckGuildFightDefendFormation()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD) then return end -- 公会未开启
    if PlayerManager.familyId == 0 then return end  -- 没有公会
    local isInFight = GuildFightManager.IsInGuildFight()
    local curStage = GuildFightManager.GetCurFightStage()
    if not isInFight or curStage == GUILD_FIGHT_STAGE.DEFEND then
        if not this.CheckFormationValid(FormationTypeDef.FORMATION_GUILD_FIGHT_DEFEND) then
            local formation = this.GetFormationByID(FormationTypeDef.FORMATION_NORMAL)
            local newFormation = {}
            for index = 1, #formation.teamHeroInfos do
                local teamInfo = formation.teamHeroInfos[index]
                local singleData = {}
                singleData.heroId = teamInfo.heroId
                singleData.position = index
                table.insert(newFormation, singleData)
            end
            this.RefreshFormation(FormationTypeDef.FORMATION_GUILD_FIGHT_DEFEND, newFormation, formation.teamPokemonInfos)
        end
    end
end

--设置元素共鸣激活索引
function this.GetElementIndex(curFormation)
    local elementPropertyList = {}
    local fireElementNum = 0
    local windyElementNum = 0
    local waterElementNum = 0
    local groundElementNum = 0

    for _, go in pairs(curFormation) do--将所有元素信息存入列表
        if go and go.heroId then
            local temp = HeroManager.GetSingleHeroData(go.heroId)
            if not temp then
            else
            local heroPropertyType = temp.heroConfig.PropertyName
            table.insert(elementPropertyList, heroPropertyType)
            end
        else
        end
    end
    for i, v in pairs(elementPropertyList) do--遍历该列表拿筛选出各元素
        if v == 1 then
            fireElementNum = fireElementNum + 1
        elseif v == 2 then
            windyElementNum = windyElementNum + 1
        elseif v == 3 then
            waterElementNum = waterElementNum + 1
        elseif v == 4 then
            groundElementNum = groundElementNum + 1
        end
    end

    local list = {}
    list[1] = fireElementNum
    list[2] = windyElementNum
    list[3] = waterElementNum
    list[4] = groundElementNum

    local indexChoose = 0
    for i = 1, #list do
        local v = list[i]
        if v == 4 then
            indexChoose = 4
        end
        if v == 5 then
            indexChoose = 5
        end
        if v == 6 then
            indexChoose = 6
        end
    end

    local count = 0
    for i = 1, #list do
        local v = list[i]
        if v == 3 then
            count = count + 1
        end
    end
    if count == 1 then
        indexChoose = 2
    elseif count == 2 then
        indexChoose = 3
    end

    local index = 0
    for i = 1, #list do
        local v = list[i]
        if v == 2 then
            index = index + 1
        end
    end
    if index == 3 then
        indexChoose = 1
    end

    return indexChoose
end

-- 获取所有正在编队的英雄id
function this.AllFormationDeleCurHeroId(heroDid)
    for i, team in pairs(this.formationList) do
        for j = 1, #team.teamHeroInfos do
            if team.teamHeroInfos[j] and team.teamHeroInfos[j].heroId ==  heroDid then
                team.teamHeroInfos[j] = nil
            end
        end
    end
end

-- 获取当前光环的加成数据 type 编队类型
function this.GetCurFormationElementAdd(teamHeroInfos)
    local data = {}
    -- local index= this.GetElementIndex(teamHeroInfos)
    -- if index==0 then return data end
    -- local config=ConfigManager.GetConfig(ConfigName.ElementalResonanceConfig)
    -- for i = 1, #config[index].Content do
    --     table.insert(data,config[index].Content[i][1],config[index].Content[i][2])
    -- end
    
    local elementIds = TeamInfosToElementIds(teamHeroInfos)
    local elementData = FormationManager.GetOpenElement(elementIds)
    for i = 1, #elementData do
        if elementData[i] then
            for j = 1, #elementData[i] do
                if elementData[i][j].isOpen then
                    for k = 1, #elementData[i][j].configData.BuffValue do
                        local pro = elementData[i][j].configData.BuffValue[k][1]
                        local value = elementData[i][j].configData.BuffValue[k][2]
                        if data[pro] then
                            data[pro] = data[pro] + value
                        else
                            data[pro] = value
                        end
                        -- table.insert(data, elementData[i][j].configData.BuffValue[k][1], elementData[i][j].configData.BuffValue[k][2])
                    end
                end
            end
        end
    end
    return data
end

-- 获取当前光环的加成数据 type 编队类型
function this.GetCurFormationElementAddByType(type,heroDid)
    local data = {}
    local curFormation = this.GetFormationByID(type)
    local isAdd = false
    if not curFormation then return {} end
    for i = 1, #curFormation.teamHeroInfos do
        if curFormation.teamHeroInfos[i].heroId == heroDid then
            isAdd = true
        end
    end
    if isAdd then
        local index = this.GetElementIndex(curFormation.teamHeroInfos)
        if index == 0 then return data end
        local config = ConfigManager.GetConfig(ConfigName.ElementalResonanceConfig)
        for i = 1, #config[index].Content do
            table.insert(data,config[index].Content[i][1],config[index].Content[i][2])
        end
    end
    return data
end


-- 设置元素共鸣激活索引 by属性id列表(heroconfig.PropertyName)
function this.GetElementIndexByPropertyNameList(propertyNameList)
    local elementPropertyList = {}
    local fireElementNum = 0
    local windyElementNum = 0
    local waterElementNum = 0
    local groundElementNum = 0

    for _, v in ipairs(propertyNameList) do
        table.insert(elementPropertyList, v)
    end

    for i, v in pairs(elementPropertyList) do--遍历该列表拿筛选出各元素
        if v == 1 then
            fireElementNum = fireElementNum + 1
        elseif v == 2 then
            windyElementNum = windyElementNum + 1
        elseif v == 3 then
            waterElementNum = waterElementNum + 1
        elseif v == 4 then
            groundElementNum = groundElementNum + 1
        end
    end

    local list = {}
    list[1] = fireElementNum
    list[2] = windyElementNum
    list[3] = waterElementNum
    list[4] = groundElementNum

    local indexChoose = 0
    for i = 1, #list do
        local v = list[i]
        if v == 4 then
            indexChoose = 4
        end
        if v == 5 then
            indexChoose = 5
        end
        if v == 6 then
            indexChoose = 6
        end
    end

    local count = 0
    for i = 1, #list do
        local v = list[i]
        if v == 3 then
            count = count + 1
        end
    end
    if count == 1 then
        indexChoose = 2
    elseif count == 2 then
        indexChoose = 3
    end

    local index = 0
    for i = 1, #list do
        local v = list[i]
        if v == 2 then
            index = index + 1
        end
    end
    if index == 3 then
        indexChoose = 1
    end

    return indexChoose
end

-- 获取当前光环的加成数据 by属性id列表(heroconfig.PropertyName)
function this.GetCurFormationElementAddByPropertyNameList(propertyNameList)
    local data = {}
    local index = this.GetElementIndexByPropertyNameList(propertyNameList)
    if index == 0 then return data end
    local config = ConfigManager.GetConfig(ConfigName.ElementalResonanceConfig)
    for i = 1, #config[index].Content do
        table.insert(data,config[index].Content[i][1],config[index].Content[i][2])
    end
    return data
end

--> ******************************************************************************************************************************************
local m_formationId = 2 --<
--> 阵型  为改变阵型临时数据 真正上阵存储在formationList  只是上阵界面用 不用区分teamid int就可以
function FormationManager.SetFormationId(formationId)
    m_formationId = formationId
end
function FormationManager.GetFormationId()
    return m_formationId
end
function FormationManager.GetFormationPosList(teamId)
    local posArray = formationConfig[this.formationList[teamId].formationId].pos
    return posArray
end

--> 更新SupportSelect 数据
function FormationManager.UpdateSupportData()
    for k, v in pairs(this.formationList) do
        SupportManager.SetFormationSupportId(v.teamId, v.supportId)
    end
end

--> 更新AdjutantSelect 数据
function FormationManager.UpdateAdjutantData()
    for k, v in pairs(this.formationList) do
        AdjutantManager.SetFormationAdjutantId(v.teamId, v.adjutantId)
    end
end

--> 获取元素附加数据
function FormationManager.GetOpenElement(elementIds)
    local a5 = {0, 0, 0, 0, 0, 0}

    for _, v in ipairs(elementIds) do
        local countryId = v
        a5[countryId] = a5[countryId] + 1
    end

    local a6 = true
    for i = 1, 5 do
        if a5[i] ~= 1 then
            a6 = false
        end
    end

    local allElementData = {}
    for _, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.FormationBuffConfig)) do
        if allElementData[v.Type] == nil then
            allElementData[v.Type] = {}
        end
        local isOpen = false
        if v.Type ~= 6 and a5[v.Type] == v.Count then --< 刨除6类型
            isOpen = true
        end
        if a6 then --< 6类型特殊判断
            isOpen = false
            if v.Type == 6 then
                isOpen = true
            end
        end

        table.insert(allElementData[v.Type], {isOpen = isOpen, configData = v})
    end

    return allElementData
end

local iconPic = {
    ["cn2-x1_TB_formationbuff_1_4"] = {1},
    ["cn2-x1_TB_formationbuff_1_3"] = {2},
    ["cn2-x1_TB_formationbuff_1_2"] = {3},
    ["cn2-x1_TB_formationbuff_1_5"] = {4},
    ["cn2-x1_TB_formationbuff_1_1"] = {5},
    ["cn2-x1_TB_formationbuff_2_8"] = {1, 2},
    ["cn2-x1_TB_formationbuff_2_11"] = {1, 3},   --x1_TB_formationbuff_2_6 蓝红
    ["cn2-x1_TB_formationbuff_2_10"] = {4, 1},
    ["cn2-x1_TB_formationbuff_2_3"] = {5, 1},
    ["cn2-x1_TB_formationbuff_2_5"] = {2, 3},
    ["cn2-x1_TB_formationbuff_2_9"] = {4, 2},
    ["cn2-x1_TB_formationbuff_2_2"] = {5, 2},
    ["cn2-x1_TB_formationbuff_2_7"] = {4, 3},
    ["cn2-x1_TB_formationbuff_2_1"] = {5, 3},
    ["cn2-x1_TB_formationbuff_2_4"] = {4, 5},
    ["cn2-x1_TB_formationbuff_3_9"] = {4, 1, 2},
    ["cn2-x1_TB_formationbuff_3_5"] = {5, 1, 2},
    ["cn2-x1_TB_formationbuff_3_4"] = {4, 2, 3},
    ["cn2-x1_TB_formationbuff_3_3"] = {5, 2, 3},
    ["cn2-x1_TB_formationbuff_3_8"] = {4, 1, 3},
    ["cn2-x1_TB_formationbuff_3_1"] = {5, 1, 3},
    ["cn2-x1_TB_formationbuff_3_7"] = {4, 5, 1},
    ["cn2-x1_TB_formationbuff_3_6"] = {4, 5, 2},
    ["cn2-x1_TB_formationbuff_3_2"] = {4, 5 ,3},
}

--> 获取布阵element icon num
function FormationManager.GetElementPicNum(elementIds)
    local allElementData = FormationManager.GetOpenElement(elementIds)

    local temp = {}
    for i = 1, #allElementData do
        for j = 1, #allElementData[i] do
            if allElementData[i][j].isOpen then
                if temp[allElementData[i][j].configData.Type] == nil then
                    temp[allElementData[i][j].configData.Type] = 0
                end

                -- temp[allElementData[i][j].configData.Type] = temp[allElementData[i][j].configData.Type] + 1
                temp[allElementData[i][j].configData.Type] = math.max(temp[allElementData[i][j].configData.Type], allElementData[i][j].configData.Count)
            end
        end
    end
    
    local iconStr = nil
    local numArray = {}
    local isGray = false
    if LengthOfTable(temp) == 0 then
        iconStr = "cn2-x1_TB_formationbuff_all"
        isGray = true
    else
        if LengthOfTable(temp) == 1 and temp[6] == 5 then
            numArray = {}
            iconStr = "cn2-x1_TB_formationbuff_all"
            table.insert(numArray, 1)
        else
            iconStr = ""
            for k, v in pairs(iconPic) do
                local isFit = true
                if #v == LengthOfTable(temp) then
                    for l, w in pairs(temp) do
                        local isH = false
                        for h = 1, #v do
                            if v[h] == l then
                                isH = true
                                break
                            end
                        end
                        if not isH then
                            isFit = false
                        end
                    end
                else
                    isFit = false
                end
    
                if isFit then
                    iconStr = k
                    numArray = {}
                    for a = 1, #v do
                        table.insert(numArray, temp[v[a]])
                    end
                    break
                end
            end
            if iconStr == "" then
                LogError("### not found x1_TB_formationbuff !!!")
            end
        end
    end

    return iconStr, numArray, isGray
end

--> chooselist or teaminfos   to  elementids
function TeamInfosToElementIds(teaminfos,special)
    local elementIds = {}

    if special and DefenseTrainingManager.teamLock==1  then
        for _, v in ipairs(teaminfos) do
            local heroData = HeroTemporaryManager.GetSingleHeroData(v.heroId)
            local countryId = heroData.heroConfig.PropertyName
            table.insert(elementIds, countryId)
        end
    else
        for _, v in ipairs(teaminfos) do
            local heroData = HeroManager.GetSingleHeroData(v.heroId)
            if heroData then
                local countryId = heroData.heroConfig.PropertyName
                table.insert(elementIds, countryId)
            end
        end
    end
    return elementIds
end

function FormationManager.FlutterPower(oldPower)
    local newPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
    if oldPower ~= newPower then
        UIManager.OpenPanel(UIName.WarPowerChangeNotifyPanelV2,{oldValue = oldPower,newValue = newPower, pos = Vector3.New(50, 18),duration = 0.7,isShowBg = true,isShowOldNum = true,pivot = Vector2.New(0.5,0.5)})
    end
end
return this