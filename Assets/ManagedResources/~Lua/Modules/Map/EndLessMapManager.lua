EndLessMapManager = {};
local this = EndLessMapManager
local endLessConfig = ConfigManager.GetConfig(ConfigName.EndlessMapConfig)
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
-- local endlessHeroProp = ConfigManager.GetConfig(ConfigName.EndlessHeroProp)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local passiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
-- local passiveSkillLogicConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local endlessMorale = ConfigManager.GetConfig(ConfigName.endlessMorale)
local endlessTreasure = ConfigManager.GetConfig(ConfigName.endlessTreasure)
this.limiteLevel = 0
this.EndlessDrop = {}
function this.Initialize()
    this.JiuYaunLuId = 1227
    this.hungery = false -- 没有行动力了
    this.leftEnergy = 0 -- 剩余行动力
    this.totalEnergy = 0 -- 总行动力
    this.targetMapId = 0 -- 传送去的地图Id
    this.justEnterMap = false -- 才刚进图伦家
    this.srcMapId = 0 -- 传送时上一张地图的ID
    this.curMapName = "" -- 当前地图名
    this.mapFightTimes = 0 -- 当前地图战斗次数
    this.energyCost = 0 -- 当前地图行动力消耗
    this.isReset = false -- 是处于复位状态
    this.openMapInfo = {} -- 地图的开放消息
    this.isTrigger = false -- 检测在是否在触发事件
    this.isUpdateOnClose = false -- 检测在MapPanel隐藏时是否更新过， 在面板关闭后初始化
    this.freshPointData = {}
    this.isAddPoint = false  -- 是否新增一个刷新点
    this.openMapId = 0 -- 开放的地图ID
    this.worldLevel = 0  -- 开放的世界等级
    this.isOpenedFullPanel = false -- 是否在退出地图前打开过全屏界面
    -- 打开过编队界面
    this.openedFormat = false
    this.isSkipFight = 1 -- 服务器记录的是否跳过战斗
    this.EndLessRoleDead = false  -- 无尽副本角色进入死亡状态，走一步重置
    this.maxMosterNum=0
    this.deadMosterNum=0
    this.cfgId=0

    this.shiQiValue = endlessMorale[1].Exp[1]
    this.scoreValueId = endlessTreasure[1].Integral[1][1]
    this.InitMissionData()
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold,this.RefreshItemData)
end

function this.RefreshItemData()
    local id,level = this.GetTreasureLevel()
    if not this.treasureData then
        return 
    end
    if id ~= this.treasureData.curDataId then
        this.treasureData.curDataId = id
        this.treasureData.curDataLevel = level
        this.SetTreasureState()
        CheckRedPointStatus(RedPointType.wujinTreasure)
        -- CheckRedPointStatus(RedPointType.EndlessPanel)
    end

    local count = BagManager.GetItemCountById(this.shiQiValue)
    if count > 0 and (not PlayerPrefs.HasKey("shiqiGuide"..PlayerManager.uid) or PlayerPrefs.GetInt("shiqiGuide"..PlayerManager.uid) == 0)  then
        PlayerPrefs.SetInt("shiqiGuide"..PlayerManager.uid,1)
        Game.GlobalEvent:DispatchEvent(GameEvent.EndLess.GuidePanel)
    end


    -- 请求完妖灵师数据后才打开编队刷新队伍
    if func then func() end
end

-- 在地图中更换编队后，更新上阵编队的最大血量值
function this.UpDateTeamMaxHp(info)
    -- 不是无尽副本，直接返回
    if CarbonManager.difficulty ~= CARBON_TYPE.ENDLESS then return end
    -- 替换地图编队的最大血量
    local mapTeam = {}
    for i = 1, #info do
        local roleId = info[i].heroId
        local allProp = HeroManager.CalculateWarAllProVal(roleId)
        allProp[2] = info[i].heroHp
        allProp[3] = info[i].heroMaxHp
        
        mapTeam[i] = {
            heroId = roleId,
            allProVal = allProp,
        }
    end
    MapManager.formationList = mapTeam

    CallBackOnPanelOpen(UIName.MapPanel, function ()
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.FormationHpChange)
    end)
end
function this.RrefreshFormationStart( ... )
    -- body
    this.formation = FormationManager.formationList[FormationTypeDef.FORMATION_ENDLESS_MAP].teamHeroInfos
end
function this.InitRefreshPoint(refreshInfo, func)
    
    this.freshPointData = {}
    for i = 1, #refreshInfo do
        local data = refreshInfo[i]
        if data.time > math.ceil(PlayerManager.serverTime) then
            this.freshPointData[data.cellId] = data.time
            
        end
    end

    if func then func() end
end

-- 登录初始化地图数据
function this.InitMapInfoData(mapId)
    this.openMapId = mapId > 1 and mapId or 4001-- 开放的地图ID
end
--  ==================================  妖灵师状态刷新 ========================================


-- -- 刷新地图中的队伍数据
-- function this.RefershMapTeam()
--     if CarbonManager.difficulty == CARBON_TYPE.ENDLESS and MapManager.Mapping then
--         MapManager.formationList = this.RefreshTeamInfo()
--     end
-- end

-- =============================================================================================
-- ====================  地图标记 ===============================================================
-- 无尽副本是否进入了可标记状态
-- function this.IsCanNoteState()
--     local canNote = false
--     if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
--         if this.isCanNote then
--             canNote = true
--         end
--     end
--     return canNote
-- end

-- -- 进入标记状态点击后保存点击选中的坐标值
-- function this.SetNotePos(u, v)
--     local selectedPos = Map_UV2Pos(u, v)
--     -- 没有标记过打开标记面板
--     local panelType = 1
--     panelType = this.IsPointNote(selectedPos) and 2 or 1
--     UIManager.OpenPanel(UIName.MapNotePopup, selectedPos, panelType)
-- end

-- -- 判断某一个点是否已经被标记
-- function this.IsPointNote(pos)
--     local isNote = false
--     if not this.PointNoteDataList[MapManager.curMapId][pos] or this.PointNoteDataList[MapManager.curMapId][pos].notePos == 0 then
--         isNote = false
--     else
--         isNote = true
--     end
--     return isNote
-- end

-- -- 删除一个已经标记的点, 需要删除的点必定存在，不然判断方法就完蛋了
-- function this.DeleteNotePoint(pos, func)
--     local noteData = this.PointNoteDataList[MapManager.curMapId][pos]
--     local deletePos = pos
--     local mapId = MapManager.curMapId
--     local deleteInfo = noteData.noteInfo
--     local deteType = 2

--     NetManager.RequestNotePoint(mapId, deletePos, deleteInfo, deteType, function ()
--         if func then func() end
--     end)
-- end

-- ===========================================================================================
-- ===================  消耗行动力 ===================================================
-- 进入当前地图消耗行动力数值
function this.EnergyCostEnterMap(mapId)
    -- 只有无尽副本执行
    if CarbonManager.difficulty ~= CARBON_TYPE.ENDLESS then return end
    local cost = 0
    local curCost = endLessConfig[this.srcMapId].TeleportCost
    local distCost = endLessConfig[mapId].TeleportCost
    cost = math.abs(distCost - curCost)
    return cost
end

-- 角色进入鸡儿状态
function this.roleIsHungery()
    local isHungery = false
    if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        if this.hungery then
            isHungery = true
        end
    end
    return isHungery
end

-- 判断鸡儿状态
function this.isHungery()
    local curEnergy = 100
    if curEnergy <= 0 then
        EndLessMapManager.hungery = true
    else
        EndLessMapManager.hungery = false
    end
end

-- 是否有足够的行动力给你去浪
function this.IsCanTransport(mapId)
    local canTransport = false
    canTransport = this.leftEnergy >= this.EnergyCostEnterMap(mapId)

    return canTransport
end

-- 向服务器索要剩余行动力
function this.GetLeftEnergy(func)
    if CarbonManager.difficulty ~= CARBON_TYPE.ENDLESS then return end
    -- NetManager.ReqeustRefreshEnergy(func)
end


-- 返回剩余行动力
function this.GetLeftMapEnergy()
    return BagManager.GetItemCountById(1)
end

-- =================================================================================
-- ============= 其他杂项处理方法 =====================================================
-- 获取统计数据
function this.OutMapStats(msg)
    if msg then
        this.mapFightTimes = msg.fightCount
        this.energyCost = msg.consumeExecution
    end
end

-- 通过传送门传送到想去的地图
function this.TranssportByMapId(mapId)
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out, mapId, 1)
end

--  获取开放的地图数据
function this.GetOpenMapInfo(openMapId)
    for i = 1, #openMapId do
        this.openMapInfo[openMapId[i]] = openMapId[i]
    end
end

-- 判断无尽副本当前地图是否开放
function this.IsThisMapOpen(mapId)
    local isOpen = false
    if this.openMapInfo[mapId] and this.openMapInfo[mapId] > 0 then
       
        isOpen = true
    else
        isOpen = false
    end
    return isOpen
end



--------------------------------------------------------------------------------编队 神将-------------------------------------------------------------------------------
this.heroDataLists = {}
function this.InitAllEndlessHero(heroList,isClear)
    if not this.heroDataLists then
        this.heroDataLists = {}
    end
    for i = 1 ,#heroList do
        this.InitSingleEndlessHero(heroList[i])
    end
    local id ,lv = this.GetShiQiValue()
    this.moraleLv = lv
    this.moraleId = id
end

function this.InitFormation()
    this.RrefreshFormation()
end

function this.InitSingleEndlessHero(_msgHeroData)
    local heroData = {}
    heroData.heroBackData = _msgHeroData
    heroData.dynamicId = _msgHeroData.id
    heroData.id = _msgHeroData.heroId
    heroData.star = _msgHeroData.star
    heroData.lv = _msgHeroData.level
    heroData.breakId = _msgHeroData.breakId
    heroData.upStarId = _msgHeroData.starBreakId
    
    heroData.createTime = _msgHeroData.createTimelocal
    heroData.lockState = _msgHeroData.lockState
    heroData.createtype = _msgHeroData.createtype
    heroData.changeId = _msgHeroData.changeId--置换id
    heroData.heroConfig = heroConfig[_msgHeroData.heroId]
    heroData.maxStar = heroData.heroConfig.MaxRank
    heroData.equipIdList = _msgHeroData.equipIdList
    for i = 1 , #heroData.equipIdList do
        EquipManager.SetEquipUpHeroDid(heroData.equipIdList[i],heroData.dynamicId)       
    end

    heroData.jewels = _msgHeroData.jewels
    this.InitBaoDatas(_msgHeroData.jewels,_msgHeroData.fourTotal,_msgHeroData.treeLevel)
    for i = 1 , #heroData.jewels do
        this.SetEquipTreasureUpHeroDid(heroData.jewels[i],heroData.dynamicId)       
    end

    heroData.talismanList = _msgHeroData.especialEquipLevel --法宝等级
    heroData.soulPrintList = {}
    if (#_msgHeroData.soulPos >= 1) then
        local soulPrintList = {}
        for i, v in ipairs(_msgHeroData.soulPos) do
            local soulPrint = {equipId = v.equipId, position = v.position}
            --SoulPrintManager.AddSoulPrintUpHeroDynamicId(v.equipId,heroData.dynamicId)
            table.insert(soulPrintList, soulPrint)
        end
        heroData.soulPrintList = soulPrintList
    end
    --乘减属性集合
    heroData.MLSproList={}
    heroData.formationList = {}--所在编队list
    local actionPowerRormula = gameSetting[1].ActionPowerRormula
    heroData.actionPower =
        heroData.heroConfig.ActionPower +
        math.floor(
            (actionPowerRormula[1] * math.pow(heroData.lv, 3) + actionPowerRormula[2] * math.pow(heroData.lv, 2) +
                actionPowerRormula[3] * heroData.lv +
                actionPowerRormula[4])
        )
    heroData.skillIdList = this.UpdateSkillIdList(heroData)
    heroData.passiveSkillList = this.UpdatePassiveHeroSkill(heroData)

    heroData.hp = heroData.heroConfig.Hp
    heroData.attack = heroData.heroConfig.Attack
    heroData.pDef = heroData.heroConfig.PhysicalDefence
    heroData.mDef = heroData.heroConfig.MagicDefence
    heroData.speed = heroData.heroConfig.Speed
    heroData.skinId = _msgHeroData.skinId or 0
    if heroData.skinId == 0 then
        heroData.skinConfig = heroData.heroConfig
        heroData.live = GetResourcePath(heroData.heroConfig.Live)
        heroData.painting = GetResourcePath(heroData.heroConfig.Painting)
        heroData.icon = GetResourcePath(heroData.heroConfig.Icon)
        heroData.scale = heroData.heroConfig.Scale
        heroData.position = heroData.heroConfig.Position
    else
        heroData.skinConfig = ConfigManager.GetConfigDataByKey(ConfigName.HeroSkin,"Type",heroData.skinId)
        heroData.live = GetResourcePath(heroData.skinConfig.Live)
        heroData.painting = GetResourcePath(heroData.skinConfig.Painting)
        heroData.icon = GetResourcePath(heroData.skinConfig.Icon)
        heroData.scale = heroData.skinConfig.Scale
        heroData.position = heroData.skinConfig.Position
    end
    heroData.profession = heroData.heroConfig.Profession
    heroData.ProfessionResourceId = heroData.heroConfig.ProfessionResourceId
    if GetJobSpriteStrByJobNum(heroData.heroConfig.Profession) then
        heroData.professionIcon = GetJobSpriteStrByJobNum(heroData.heroConfig.Profession)
    else
        heroData.professionIcon = GetJobSpriteStrByJobNum(1)
    end
    heroData.name = GetLanguageStrById(heroData.heroConfig.ReadingName)
    heroData.property = heroData.heroConfig.PropertyName
    heroData.sortId = #this.heroDataLists + 1
    
    heroData.harmonyGongMing = _msgHeroData.createtype

    this.heroDataLists[heroData.dynamicId] = heroData
    heroData.warPower = HeroManager.CalculateHeroAllProValList(1, heroData.dynamicId, false)[HeroProType.WarPower]
end

--宝器
local jewelConfig = ConfigManager.GetConfig(ConfigName.JewelConfig)
function this.InitBaoDatas(_soulEquips,_fourTotal,_treeLevel)
    if not this.allTreasures then
        this.allTreasures = {}
    end
    if not _soulEquips then return end
    for i = 1, #_soulEquips do
        this.InitSingleTreasureData(_soulEquips[i],_fourTotal,_treeLevel)
    end
end
--初始化单个宝物的数据
function this.InitSingleTreasureData(_singleData,_fourTotal,_treeLevel)
    if not _singleData or not _singleData.equipId then
        return
    end
    local single={}
    local staticId=_singleData.equipId
    local currJewel=jewelConfig[staticId]
    single.id=staticId
    single.idDyn=_singleData.id
    single.lv=_singleData.exp
    single.refineLv=_singleData.rebuildLevel
    single.maxLv=currJewel.Max[1]
    single.maxRefineLv=currJewel.Max[2]
    single.upHeroDid=""
    single.maxTreeLv = currJewel.GodHoodMaxlv
    single.treeLv = _treeLevel 
    single.fourTotal = _fourTotal
    local quantity=currJewel.Level
    single.quantity=quantity
    single.frame=GetQuantityImageByquality(quantity)
    single.name=itemConfig[staticId].Name
    single.itemConfig=itemConfig[staticId]
    single.levelPool=currJewel.LevelupPool
    single.proIcon=GetProStrImageByProNum(currJewel.Race)
    single.refinePool=currJewel.RankupPool
    single.equipType=currJewel.Location
    if currJewel.Location==1 then
        single.type=GetLanguageStrById(10505)
    else
        single.type=GetLanguageStrById(10506)
    end
    single.icon=GetResourcePath(itemConfig[staticId].ResourceID)
    single.strongConfig=this.GetCurrTreasureLvConfig(1,currJewel.LevelupPool,_singleData.exp)
    single.refineConfig=this.GetCurrTreasureLvConfig(2,currJewel.RankupPool,_singleData.rebuildLevel)
    this.allTreasures[_singleData.id]=single
end
local jewerLevelUpConfig = ConfigManager.GetConfig(ConfigName.JewelRankupConfig)
--获取当前宝物升级数据
function this.GetCurrTreasureLvConfig(_type,_id,_lv)
    for _, configInfo in ConfigPairs(jewerLevelUpConfig) do
        if configInfo.Type==_type and configInfo.PoolID==_id and configInfo.Level==_lv then
            return configInfo
        end
    end
end
--根据动态id获取宝物
function this.GetSingleTreasureByIdDyn(_idDyn)
    if not this.allTreasures[_idDyn] == nil then
        return nil
    end
    return this.allTreasures[_idDyn]
end

--设置装备穿戴的英雄
function this.SetEquipTreasureUpHeroDid(_equipTreasureDid,_heroDid)
    if this.allTreasures[_equipTreasureDid] then
        this.allTreasures[_equipTreasureDid].upHeroDid=_heroDid
    end
end


--更新英雄主动技能
function this.UpdateSkillIdList(heroData)
    local skillIdList = {}
    --主动技
    if heroData.heroConfig.OpenSkillRules then
        for i = 1, #heroData.heroConfig.OpenSkillRules do
            if heroData.heroConfig.OpenSkillRules[i][1] == heroData.star then
                local heroSkill = {}
                heroSkill.skillId = heroData.heroConfig.OpenSkillRules[i][2]
                heroSkill.skillConfig = skillConfig[heroSkill.skillId]
                table.insert(skillIdList, heroSkill)
            end
        end
    end
    return skillIdList
end
--更新英雄被动技能
function this.UpdatePassiveHeroSkill(heroData)
    local passiveSkillList = {} --被动技
    local OpenPassiveSkillRules =  heroData.star == this.awakeNextStarIndex and heroData.heroConfig.Awaken or heroData.heroConfig.OpenPassiveSkillRules
    if OpenPassiveSkillRules then
        for i = 1, #OpenPassiveSkillRules do
            if OpenPassiveSkillRules[i][1] == 1 then --突破
                if heroData.breakId >= OpenPassiveSkillRules[i][2] then
                    local heroSkill = {}
                    heroSkill.skillId = OpenPassiveSkillRules[i][3]
                    heroSkill.skillConfig = passiveSkillConfig[heroSkill.skillId]
                    table.insert(passiveSkillList, heroSkill)
                end
            else --升星
                if heroData.upStarId >= OpenPassiveSkillRules[i][2] then
                    local heroSkill = {}
                    heroSkill.skillId = OpenPassiveSkillRules[i][3]
                    heroSkill.skillConfig = passiveSkillConfig[heroSkill.skillId]
                    table.insert(passiveSkillList, heroSkill)
                end
            end
        end
    end
    return passiveSkillList
end

function this.SetHeroFormationList(heroDid,teamId,isAddOrDel)

end

function this.GetSingleCanUseHeroData(heroDid)
    if not this.canUseHeroDatas or LengthOfTable(this.canUseHeroDatas) < 1 then
        this.GetCanUseHeroDatas()
    end
    if this.canUseHeroDatas[heroDid] then
        return this.canUseHeroDatas[heroDid]
    end
end

function this.GetSingleHeroData(heroDid)
    if this.heroDataLists[heroDid] then
        return this.heroDataLists[heroDid]
    end
end

function this.GetCanUseHeroDatas()
    if not this.canUseHeroDatas then
        this.canUseHeroDatas = {}
    end
    for k,v in pairs(this.heroDataLists) do
       if PlayerManager.GetHeroDataByStar(0,v.id) then
            if not this.canUseHeroDatas[v.dynamicId] then
                this.canUseHeroDatas[v.dynamicId] = v
            end
            local isNew = 0
            if not PlayerPrefs.HasKey("endlessCanUseHero"..PlayerManager.uid..v.dynamicId) then
                PlayerPrefs.SetInt("endlessCanUseHero"..PlayerManager.uid..v.dynamicId,1)
            end
            isNew = PlayerPrefs.GetInt("endlessCanUseHero"..PlayerManager.uid..v.dynamicId)
            this.canUseHeroDatas[v.dynamicId].isNew = isNew
       end
    end
end

function this.SetCanUseHeroNew()
    if not this.canUseHeroDatas or LengthOfTable(this.canUseHeroDatas) < 1 then
        this.GetCanUseHeroDatas()
    end
    for k,v in pairs(this.canUseHeroDatas) do
        PlayerPrefs.SetInt("endlessCanUseHero"..PlayerManager.uid..v.dynamicId,0)
        v.isNew = 0
    end
    -- CheckRedPointStatus(RedPointType.wujinBianDui)
    -- CheckRedPointStatus(RedPointType.EndlessPanel)
end

function this.GetHeroDataByProperty(_proId)
    this.GetCanUseHeroDatas()
    local heros = {}
    local index = 1
    if this.canUseHeroDatas then
        for i, v in pairs(this.canUseHeroDatas) do
            if v.property == _proId or _proId == 0 then
                    heros[index] = v
                    heros[index].exist = 1
                    index = index + 1                  
            end
        end
    end
    return heros
end

function this.GetHeroDataByProperty1(_proId,_heros)
    local index = 0
    for i, v in pairs(this.heroDataLists) do
        local isExist = false
        for j, k in pairs(this.canUseHeroDatas) do
            if (v.property == _proId or _proId == 0) and k.id == v.id then
                isExist = true
                break
            end
        end
        if not isExist and (v.property == _proId or _proId == 0) then
            index = #_heros + 1
            _heros[index] = v
            _heros[index].exist = 0
        end
    end
    return _heros
end

-- 所有妖灵师的血量数据
this.allHeroBlood = {}
function this.InitHeroHp(msg, func)
    this.allHeroBlood = {}

    if msg and #msg.heroInfo > 0 then
        for i = 1, #msg.heroInfo do
            local heroData = msg.heroInfo[i]

            local allEquipAddProVal= HeroManager.CalculateWarAllProVal(heroData.heroId)
            local maxHp = allEquipAddProVal[3]
            local hp = heroData.hp
            local data = {}
            data.percentHp = hp
            data.curHp = hp
            data.heroId = heroData.heroId
            this.allHeroBlood[heroData.heroId] = data
        end
    end
    -- 请求完妖灵师数据后才打开编队刷新队伍
    if func then func() end
end

-- -- 换人后刷新队伍血量
-- function this.RefreshTeamInfo()

--     local mapTeam = {}
--     local curTeam = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_ENDLESS_MAP)
--     for i = 1, #curTeam.teamHeroInfos do
--         local roleData = curTeam.teamHeroInfos[i]
--         local allProp = HeroManager.CalculateWarAllProVal(roleData.heroId)
--         allProp[2] = this.allHeroBlood[roleData.heroId].curHp
--         mapTeam[i] = {
--             heroId = roleData.heroId,
--             allProVal = allProp,
--         }
--     end

--     return mapTeam
-- end

-- 无尽副本中得到某一个妖灵师的血量值, 传入动态ID
function this.GetHeroLeftBlood(heroId)
    if CarbonManager.difficulty ~= CARBON_TYPE.ENDLESS then
        return
    end
    if this.allHeroBlood[heroId] then
        return this.allHeroBlood[heroId].curHp
    else
        local allProp = HeroManager.CalculateWarAllProVal(heroId)
        return allProp[3]
    end
end

-- 角色战斗失败，删除相应的地图队伍
function this.DeleteMapTeam()
    for i = 1, #this.formation do
        local heroId = this.formation[i].heroId
        this.allHeroBlood[heroId].curHp = 0
    end
end

-- 是否所有都死翘翘
function this.IsAllDead()
    for i, v in pairs(this.allHeroBlood) do
        if v.curHp > 0 then
            return false
        end
    end
    return true
end

-- 是否所有都满血
function this.IsAllFullHp()
    for i, v in pairs(this.allHeroBlood) do
        if v.percentHp < 1 then
            return false
        end
    end
    return true
end

-- 判断队伍是否还有活着的人
function this.IsMapTeamAlive()
    local curFormation = this.formation
    local tempList = {}
    for k,v in pairs(curFormation) do
        if EndLessMapManager.GetSingleCanUseHeroData(v.heroId) then
            
            if  EndLessMapManager.allHeroBlood[v.heroId].percentHp > 0 then
                table.insert(tempList,v)
            end
        end
    end
    if #tempList < 1 then
        return false
    else
        return true
    end
end

--刷新英雄，去掉使用的自己的英雄和死了的英雄
function this.RrefreshFormation()
    local tempList = {}
    local curFormation = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_ENDLESS_MAP)
    for k,v in pairs(curFormation.teamHeroInfos) do
        if (not this.allHeroBlood[v.heroId] or this.allHeroBlood[v.heroId].curHp > 0) then
            table.insert(tempList,v)
        end
    end
    table.sort(tempList,function(a,b)
        return a.position < b.position
    end)
    FormationManager.formationList[FormationTypeDef.FORMATION_ENDLESS_MAP].teamHeroInfos = tempList
    this.formation = FormationManager.formationList[FormationTypeDef.FORMATION_ENDLESS_MAP].teamHeroInfos
end

function this.CheckFormationIsEmpty()
    if LengthOfTable(this.formation) < 1 then
        return true
    else
        return false
    end
end
---------------------------------------------------------任务-----------------------------------
function this.InitMissionData()
    this.mission = {}
    for k,v in ConfigPairs(ConfigManager.GetConfig(ConfigName.EndlessTask)) do          
        local data = {}
        data.Id = v.Id
        data.index = #this.mission + 1
        data.Desc = v.Desc
        data.info = ""
        data.progress = 0
        data.value = v.Values[2][1]
        data.jump = v.Jump
        data.BoxReward = {} 
        for i = 1,#v.Reward do
            table.insert(data.BoxReward ,v.Reward[i])
        end
        data.state = 0
        table.insert(this.mission,data)       
    end
end

function this.SetRewardData()
    local missions = {}
    local allMissionData = TaskManager.GetTypeTaskList(TaskTypeDef.wujinfuben)
    for k,v in ipairs(this.mission) do
        for j = 1,#allMissionData do 
            if v.Id == allMissionData[j].missionId then      
                v.progress = allMissionData[j].progress
                if allMissionData[j].state == 2 then
                    -- goText.text="已领取"
                    v.progress = v.value
                    v.state = 0
                elseif allMissionData[j].state == 1 then
                    -- goText.text="领取"
                    v.progress = v.value
                    v.state = allMissionData[j].state    
                elseif allMissionData[j].state == 0 then
                    -- goText.text="前往"
                    v.state = 2
                end
                v.info = v.Desc ..("(")..v.progress.."/"..v.value..(")")
                table.insert(missions,v)
                break
            end
        end
    end
    
    local typeIndex = {
        [0] = 2,
        [1]  = 0,
        [2] = 1,
    }
    table.sort(missions, function(a,b)
        if typeIndex[a.state] == typeIndex[b.state] then
            return a.Id < b.Id
        else
            return typeIndex[a.state] < typeIndex[b.state]
        end
    end)

    CheckRedPointStatus(RedPointType.wujinMission)
    -- CheckRedPointStatus(RedPointType.EndlessPanel)
    return missions
end

function this.GetRewardData()
    this.SetRewardData()
    local data = nil
    for i = 1 ,#this.mission do
       
    end
    for i = 1 ,#this.mission do
        if this.mission[i].state == 1 then
            data = this.mission[i]
            break
        end
    end
    if not data then
        for i = 1 ,#this.mission do
            if this.mission[i].state == 2 then
                data = this.mission[i]
                break
            end
        end
    end
    if not data then
        data = this.mission[#this.mission]
    end
    return data
end
--------------------------------------------------------------------------士气-----------------------------------------------
function this.GetShiQiValue()
    local id = 0
    local moraleLv1 = 0
    local itemCount = BagManager.GetItemCountById(this.shiQiValue)
    for k,v in ConfigPairs(endlessMorale) do
        if not v.Exp or #v.Exp < 2 then
            moraleLv1 = v.Level
            id = v.Id
            break
        elseif itemCount < v.Exp[2]  then
            moraleLv1 = v.Level
            id = v.Id
            break
        end
    end
    return id,moraleLv1
end
------------------------------------------------------------------------------------秘宝-----------------------------------------------------
this.treasureLevel = 0
function this.GetTreasureData()
    this.treasureDataReward = {}
    for k,v in ConfigPairs(ConfigManager.GetConfig(ConfigName.endlessTreasure)) do          
        local data = {}
        data.Id = v.Id
        data.index = #this.mission + 1
        data.Level = v.Level
        data.Integral = v.Integral[1][2] or 51000
        data.Reward = {} 
        if v.Reward then
            for i = 1,#v.Reward do
                table.insert(data.Reward,{id = v.Reward[i][1],num = v.Reward[i][2],type = 1})
            end
        end
        if v.TreasureReward then
            for i = 1,#v.TreasureReward do
                table.insert(data.Reward,{id = v.TreasureReward[i][1],num = v.TreasureReward[i][2],type = 2})
            end
        end
        data.state = 0
        table.insert(this.treasureDataReward,data)       
    end
end

function this.GetTreasureLevel()
    local id = 0
    local moraleLv1 = 0
    local itemCount = BagManager.GetItemCountById(this.scoreValueId)
    for k,v in ConfigPairs(endlessTreasure) do
        if not v.Integral or #v.Integral < 1 or #v.Integral[1] < 2 then
            moraleLv1 = v.Level
            id = v.Id
            break
        elseif itemCount < v.Integral[1][2]  then
            moraleLv1 = v.Level
            id = v.Id
            break
        end 
    end
    return id,moraleLv1
end

function this.SetTreasureGiftState(index)
    this.treasureData.treasureState = index
end

function this.InitTreasureData(msg)
    this.treasureData = {}
    this.treasureData.tip = GetLanguageStrById(23044)
    this.treasureData.resetTime = msg.resetTime
    --购买状态
    
    this.SetTreasureGiftState(msg.isBuy)
    
    this.treasureData.curScore = BagManager.GetItemCountById(EndLessMapManager.scoreValueId) or 0
    this.GetTreasureData()
    this.treasureData.rewardData = this.treasureDataReward
    this.treasureData.curDataId,this.treasureData.curDataLevel = this.GetTreasureLevel()
    for i = 1 ,#msg.treasureRewardState do
       
        this.SetTreasureState(msg.treasureRewardState[i].id,msg.treasureRewardState[i].state)
    end
    return this.treasureData
end

function this.SetTreasureState(id,state)
    --4 未达成 3 可再次领取 2 可领取 1 已领取 -1 完美领取（充钱领取过的）
    local itemCount = BagManager.GetItemCountById(this.scoreValueId)
    local s = function(data)
        if data.state == -1 then
            return
        end
        if this.treasureData.curDataId >= data.Id then
            if data.state == 1 then
                if this.treasureData.treasureState == 1 then      --已购买
                    data.state = 3 
                end
            else
                local isAdd = false
                for i = 1,#data.Reward do
                    if data.Reward[1].type == 1 then
                        data.state = 2
                        isAdd = true
                        break
                    end
                end
                if not isAdd and this.treasureData.treasureState == 1 then
                    data.state = 2
                elseif not isAdd and this.treasureData.treasureState == 0 then
                    data.state = 4
                end
            end
        else
            data.state = 4
        end
    end
    if id then
        for i = 1,#this.treasureDataReward do
            if this.treasureDataReward[i].Id == id then
                this.treasureDataReward[i].state = state
                s(this.treasureDataReward[i])
                break
            end
        end
    end
    for i = 1,#this.treasureDataReward do
        s(this.treasureDataReward[i])
    end
end

function this.GetAllRewardData()
    local rewardData = {}
    local rewardData1 = {}
    local caluteLv = function(count)
        local id,moraleLv1 
        for k,v in ConfigPairs(endlessTreasure) do
            if not v.Integral or #v.Integral < 1 or #v.Integral[1] < 2 then
                moraleLv1 = v.Level
                id = v.Id
                break
            elseif count < v.Integral[1][2]  then
                moraleLv1 = v.Level
                id = v.Id
                break
            end 
        end
        return id,moraleLv1
    end
  
    local itemCount = BagManager.GetItemCountById(this.scoreValueId)
    local config = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig,107)
    local willItemCount = itemCount + 0
    for i = 1,#config.BaseReward do
        if config.BaseReward[i][1] == this.scoreValueId then
            willItemCount = willItemCount + config.BaseReward[i][2]
        end
    end
    local id,lv = caluteLv(willItemCount) or 0,0
    for k,v in ipairs(this.treasureDataReward) do
         --4 未达成 3 可再次领取 2 可领取 1 已领取 -1 完美领取（充钱领取过的）
        if v.Reward then
            for n,m in ipairs(v.Reward) do
                if m.type == 2 then
                    table.insert(rewardData1,m)
                    if id >= v.Id then
                        table.insert(rewardData,m)
                    end                 
                else
                    if (v.state == 4 and id >= v.Id) or v.state == 2 then
                        if id >= v.Id then
                            table.insert(rewardData,m)
                        end
                    end
                end
            end
        end
    end
    return rewardData,rewardData1
end
--------------------------------------------------------------红点-----------------------------------------------
function this.CheckoutRedPointTreasure()
    if not this.treasureDataReward then
        return false
    end
    for i = 1,#this.treasureDataReward do
        if this.treasureDataReward[i].state == 2 or this.treasureDataReward[i].state == 3 then
            return true
        end
    end
    return false
end
function this.CheckoutRedPointMission()
    for i = 1,#this.mission do
        if this.mission[i].state == 1 then
            return true
        end
    end
    return false
end
function this.ChecRedPointEndLess()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ENDLESS) then
        return false
    end
    if not PlayerPrefs.HasKey("WuJin1"..PlayerManager.uid) then
        PlayerPrefs.SetInt("WuJin1"..PlayerManager.uid ,0)
    end
    local note = PlayerPrefs.GetInt("WuJin1"..PlayerManager.uid)
    local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.ENDLESS)
    if serData.endTime ~= note then
        return true
    end
    local isShow = this.CheckoutRedPointTreasure()
    if not isShow then
        isShow = this.CheckoutRedPointMission()
    end
    if not isShow then
        isShow = this.CheckCanUseHeroNew()
    end
    return isShow
end

function this.CheckCanUseHeroNew()
    this.GetCanUseHeroDatas()
    for k,v in pairs(this.canUseHeroDatas) do
        if v.isNew and v.isNew == 1 then
            return true
        end
    end
    return false
end
-------------------------------------------------------------------------------------------------------------
return this