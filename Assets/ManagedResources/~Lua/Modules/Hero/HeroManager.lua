HeroManager = {}
local this = HeroManager
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local heroLevelConfig = ConfigManager.GetConfig(ConfigName.HeroLevelConfig)
local heroRankUpConfig = ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
local heroRankUpGroup = ConfigManager.GetConfig(ConfigName.HeroRankupGroup)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local passiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local passiveSkillLogicConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)
local equipsuite = ConfigManager.GetConfig(ConfigName.EquipSuiteConfig)
local jewelConfig = ConfigManager.GetConfig(ConfigName.JewelConfig)
local jewelRankupConfig = ConfigManager.GetConfig(ConfigName.JewelRankupConfig)
local jewelResonanceConfig = ConfigManager.GetConfig(ConfigName.JewelResonanceConfig)
local monsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local unlockSkill = ConfigManager.GetConfig(ConfigName.UnlockSkill)
local skillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local HeroRankConfig = ConfigManager.GetConfig(ConfigName.HeroRankConfig)
local HeroStarConfig = ConfigManager.GetConfig(ConfigName.HeroStarConfig)
local HeroStarBackConfig = ConfigManager.GetConfig(ConfigName.HeroStarBackConfig)
local HeroExchangeConfig = ConfigManager.GetConfig(ConfigName.HeroExchangeConfig)
local WarWaySkillUpgradeCost= ConfigManager.GetAllConfigsDataByKey(ConfigName.WarWaySkillConfig, "Level", 1)

local heroDatas = {}
this.heroSortedDatas = {}--排序后的英雄数据
this.heroDataLists = {}
this.heroLvEnd = {}
--3星=60,4=200,5=250      星级对应等级上限
--this.heroLvBreakNum = {}--3星=9000,4=60000,5=60000         星级对应突破系数
this.heroPropertyScore = {}

--每个属性评分
this.heroPosCount = 5
this.heroQuantityCount = 6
this.heroProCount = 6
--成员界面排序索引
this.heroListPanelSortID = 1
this.heroListPanelProID = 0
--穿脱装备界面临时数据
this.roleEquipPanelCurHeroData = nil
this.roleEquipPanelHeroListData = nil
this.allProVal = {}
--临时计算英雄战力加成
this.heroResolveLicence = {}
--this.singleHeroProVal = {}--单体加成
--this.lvProVal = {}--单体等级限制加成
--this.allHeroProVal = {}--团体加成
--this.specialProVal = {}--减乘


--英雄的两个能力是否可以领悟学习升级
local abilityCanShowRedPointState = {
    ["ability1"] = false,
    ["ability2"] = false
}

--两个戒指有没有更好的选择
local betterRingsState = {
    ["Rings1"] = false,
    ["Rings2"] = false
}

--装备
local WarWaySkillConfig = ConfigManager.GetConfig(ConfigName.WarWaySkillConfig)

function this.Initialize()
    for i = 1, WarPowerTypeAllNum do
        this.allProVal[i] = {
            singleHeroProVal = {},
            --单体加成
            lvProVal = {},
            --单体等级限制加成
            allHeroProVal = {},
            --团体加成
            specialProVal = {}
            --减乘
        }
    end

    this.GetSingleProScoreVal()
end
--初始化英雄数据
function this.InitHeroData(_msgHeroList)
    local hero_resolve_licence = string.split(ConfigManager.GetConfigData(ConfigName.SpecialConfig, 36).Value, "#")
    for i = 1, #hero_resolve_licence do
        this.heroResolveLicence[tonumber(hero_resolve_licence[i])] = tonumber(hero_resolve_licence[i])
    end
    for i = 1, #_msgHeroList do
        this.UpdateHeroDatas(_msgHeroList[i], true)
    end
    this.UpdateHeroLvEnd()
    --赋值每个星级的英雄等级上限
    -- this.UpdateHeroPower()
    --赋值英雄战力
end

--刷新本地数据
--_isExtern 是否是其他模块单增英雄 走同一套赋值 管理在各模块实现
function this.UpdateHeroDatas(_msgHeroData, _isFindHandBook, _isExtern)
    local isExtern = _isExtern or false
    local heroData = {}
    heroData.soulPrintList = {}
    --乘减属性集合
    heroData.MLSproList = {}
    heroData.heroBackData = _msgHeroData
    heroData.dynamicId = _msgHeroData.id
    local _id = _msgHeroData.heroId
    heroData.id = _id
    heroData.star = _msgHeroData.star
    heroData.lv = _msgHeroData.level
    heroData.breakId = _msgHeroData.breakId
    heroData.upStarId = _msgHeroData.starBreakId
    heroData.createTime = _msgHeroData.createTimelocal
    heroData.lockState = _msgHeroData.lockState
    heroData.createtype = _msgHeroData.createtype
    heroData.changeId = _msgHeroData.changeId--置换id
    heroData.formationList = {}--所在编队list
    -- 能力
    heroData.warWaySlot1Id = _msgHeroData.warWaySlot1 or 0
    heroData.warWaySlot2Id = _msgHeroData.warWaySlot2 or 0
    --本地 or 援助
    local _configData = heroConfig[_id]
    heroData.heroConfig = heroConfig[_id]
    heroData.maxStar = _configData.MaxRank

    local actionPowerRormula = gameSetting[1].ActionPowerRormula
    heroData.actionPower =
        heroData.heroConfig.ActionPower +
        math.floor(
            (actionPowerRormula[1] * math.pow(heroData.lv, 3) + actionPowerRormula[2] * math.pow(heroData.lv, 2) +
                actionPowerRormula[3] * heroData.lv +
                actionPowerRormula[4])
        )

    --英雄穿戴的装备
    heroData.equipIdList = _msgHeroData.equipIdList
    heroData.jewels = _msgHeroData.jewels
    heroData.talismanList = _msgHeroData.especialEquipLevel --法宝等级
    heroData.planList = {}            -- 戒指
    for i = 1, #_msgHeroData.combatPlans do
        heroData.planList[i] = {planId = _msgHeroData.combatPlans[i].planId, position = _msgHeroData.combatPlans[i].position}   --< 后端的第三个参数confPlanId不用
    end
    heroData.medal = _msgHeroData.medal                       -- 勋章
    heroData.suitActive = _msgHeroData.suit                   -- 勋章套装激活
    heroData.totemId = _msgHeroData.totemId                   -- 图腾
    
    if #_msgHeroData.soulPos >= 1 then
        local soulPrintList = {}
        for i, v in ipairs(_msgHeroData.soulPos) do
            local soulPrint = {equipId = v.equipId, position = v.position}
            SoulPrintManager.AddSoulPrintUpHeroDynamicId(v.equipId, heroData.dynamicId)
            table.insert(soulPrintList, soulPrint)
        end
        heroData.soulPrintList = soulPrintList
    end
    -- 部件
    heroData.partsData = {}
    this.SetHeroPartsData(heroData.partsData, _msgHeroData.AdjustUnLock, heroData)

    -- 特性 天赋
    HeroManager.SetHeroTalentData(heroData, _msgHeroData)

    heroData.skillIdList = {}
    --主动技
    this.UpdateSkillIdList(heroData)
    heroData.passiveSkillList = {}
    --被动技
    this.UpdatePassiveHeroSkill(heroData)
    heroData.hp = _configData.Hp
    heroData.attack = _configData.Attack
    heroData.pDef = _configData.PhysicalDefence
    heroData.mDef = _configData.MagicDefence
    heroData.speed = _configData.Speed
    heroData.live = GetResourcePath(_configData.Live)
    heroData.profession = _configData.Profession
    heroData.ProfessionResourceId = _configData.ProfessionResourceId
    if GetJobSpriteStrByJobNum(_configData.Profession) then
        heroData.professionIcon = GetJobSpriteStrByJobNum(_configData.Profession)
    else
        heroData.professionIcon = GetJobSpriteStrByJobNum(1)
    end
    heroData.name = _configData.ReadingName
    heroData.painting = GetResourcePath(_configData.Painting)
    heroData.icon = GetResourcePath(_configData.Icon)
    heroData.scale = _configData.Scale
    heroData.position = _configData.Position
    heroData.property = _configData.PropertyName
    heroData.sortId = #heroDatas + 1
    
    this.SetEquipUpHeroDid(heroData.equipIdList, heroData.dynamicId)
    -- this.SetEquipTreasureUpHeroDid(heroData.jewels, heroData.dynamicId)
    -- this.SetTalismanLv(heroData.dynamicId, heroData.talismanList)
    -- this.SetSoulPrintUpHeroDid(heroData.soulPrintList,heroData.dynamicId)
    this.SetPlanUpHeroDid(heroData.planList, heroData.dynamicId)
    this.SetMedalHeroDid(heroData.medal,heroData.dynamicId)
    this.SetTotemHeroDid(heroData.totemId,heroData.dynamicId)
    
    local isFindHandBook = true
    if _isFindHandBook ~= nil then
        isFindHandBook = _isFindHandBook
    end
    if isFindHandBook then --图鉴
        PlayerManager.SetHeroHandBookListData(heroData.id, heroData.star)
    end
    heroData.warPower = this.CalculateHeroAllProValList(1, heroData, false)[HeroProType.WarPower]   --< 此处算战力 有些会没算进去（被动。。）   不要用warPower   用新cal的
    --远征初始化血量
    --ExpeditionManager.InitHeroHpValue(heroData)

    --
    if not isExtern then
        table.insert(this.heroDataLists, heroData)
        heroDatas[heroData.dynamicId] = heroData
        Game.GlobalEvent:DispatchEvent(GameEvent.CustomEvent.OnUpdateHeroDatas)
    else
        return heroData
    end
end

function this.GetHeroEquipIdList(heroDid)
    return heroDatas[heroDid].equipIdList
end

function this.GetHeroEquipIdList1(heroDid, id)
    for i = 1, #heroDatas[heroDid].equipIdList do
        if equipConfig[tonumber(heroDatas[heroDid].equipIdList[i])].Position == equipConfig[tonumber(id)].Position then
            heroDatas[heroDid].equipIdList[i] = id
        end
    end
end

function this.SetHeroEquipIdList(heroDid, equipIdList)
    heroDatas[heroDid].equipIdList = equipIdList
end

function this.SetEquipUpHeroDid(_equipids, _heroDid)
    if _equipids then
        EquipManager.UpdateEquipData(_equipids, _heroDid)
    end
end
function this.SetEquipTreasureUpHeroDid(_equipTreasureDids, _heroDid)
    for i = 1, #_equipTreasureDids do
        EquipTreasureManager.SetEquipTreasureUpHeroDid(_equipTreasureDids[i], _heroDid)
    end
end

function this.SetPlanUpHeroDid(_planList, _heroDid)
    if _planList then
        for i = 1, #_planList do
            CombatPlanManager.UpPlanData(_heroDid, _planList[i].planId)
        end
    end
end

function this.SetMedalHeroDid(_MedalList, _heroDid)
    if #_MedalList > 0 then
        for i = 1, #_MedalList do
            MedalManager.UpMedalData(_MedalList[i].id,_heroDid)
            --heroDatas[_heroDid].medal=MedalManager.MedalDaraByHero(_heroDid)
        end
    end
end

function this. SetMedalHeroList(_heroDid,medalList)
    heroDatas[_heroDid].medal = medalList
end

function this.GetMedalHeroList(_heroDid)
    return heroDatas[_heroDid].medal
end

function this.SetHeroSuitAtive(heroDid,suitRes)
    -- local medalist = {}
    -- medalist = MedalManager.MedalDaraByHero(heroDid)
    -- local suitRes = {}
    -- suitRes = MedalManager.SuitHeroSuitActive(medalist)
    heroDatas[heroDid].suitActive = suitRes
end

function this.GetHeroSuitActive(heroDid)
    return heroDatas[heroDid].suitActive
end

function this.SetTotemHeroDid(totemid, _heroDid)
    if totemid ~= 0 then
        TotemManager.UpTotemData(totemid,_heroDid)
    else
    end
end

function this.SetHeroTotemInfo(heroDid,totemId)
    heroDatas[heroDid].totemId = totemId
end
function this.GetHeroTotemInfo(heroDid)
    return heroDatas[heroDid].totemId
end

--设置法宝等级
function this.SetTalismanLv(did, lv)
    heroDatas[did].talismanList = lv
end
function this.GetTalismanLv(did)
    if heroDatas[did] then
        return heroDatas[did].talismanList
    end
end

--设置已穿戴魂印数据
function this.SetSoulPrintUpHeroDid(soulPos, _heroDid)
    if soulPos then
        SoulPrintManager.SetSoulPrintUpHeroDid(soulPos, _heroDid)
    end
end
--获取所有英雄信息
function this.GetAllHeroDatas(_lvLimit)
    local lvLimit = 0
    local allUpZhenHeroList = FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_ENDLESS_MAP)
    if _lvLimit then
        lvLimit = _lvLimit
    end
    local heros = {}
    for i, v in pairs(heroDatas) do
        if v.heroConfig.Material ~= 1 then
            if v.lv >= lvLimit or allUpZhenHeroList[v.dynamicId] then
                table.insert(heros, v)
            end
        end
    end
    table.sort(
        heros,
        function(a, b)
            return a.sortId < b.sortId
        end
    )
    return heros
end
--获取所有英雄信息(包括万能卡)
function this.GetAllHeroDatasAndZero(_lvLimit)
    local lvLimit = 0
    local allUpZhenHeroList = FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_ENDLESS_MAP)
    if _lvLimit then
        lvLimit = _lvLimit
    end
    local heros = {}
    for i, v in pairs(heroDatas) do
        if v.lv >= lvLimit or allUpZhenHeroList[v.dynamicId] then
            table.insert(heros, v)
        end
    end
    table.sort(
        heros,
        function(a, b)
            return a.sortId < b.sortId
        end
    )
    return heros
end

--获取该静态id sortid最小的英雄信息
function this.GetHeroDataByHeroSIdAndMinSortId(_heroSId)
    local heroData = {}

    local formationList = FormationManager.GetAllFormationHeroId()
    for i, v in pairs(formationList) do
        if heroDatas[i] then
            local curData = heroDatas[i]
            if curData.id == _heroSId then
                if heroData and heroData.id then
                    if curData.sortId < heroData.sortId then
                        heroData = curData
                    end
                else
                    heroData = curData
                end
            end
        end
    end
    if heroData and heroData.id then
        return heroData
    end
    for i, v in pairs(heroDatas) do
        if v.id == _heroSId then
            if heroData and heroData.id then
                if v.sortId < heroData.sortId then
                    heroData = v
                end
            else
                heroData = v
            end
        end
    end
    return heroData
end
--获取所有英雄信息（分解 回溯用 ） --0全部 1-6属性  7-9 3、4、5星
function this.GetAllHeroDataMsinusUpWar(_sortTypeId,type)
    local heros = {}
    local heros2 = {}
    for i, v in pairs(heroDatas) do
        --队伍名称  以、 连接
        v.isFormation = ""
        table.insert(heros, v)
    end
    --标记编队上的英雄
    if heros and LengthOfTable(heros) > 0 then
        for i, v in pairs(heros) do
            local isFormations = {}
            for n, w in pairs(FormationManager.formationList) do
                for m = 1, #w.teamHeroInfos do
                    if w.teamHeroInfos[m] and v.dynamicId == w.teamHeroInfos[m].heroId then
                        --队伍名称  队伍id
                        local isFormationStr = ""
                        local curFormationId = 0
                        local temp = this.GetHeroFormationStr2(n)
                        if temp and temp ~= "" then
                            if heros[i].isFormation and heros[i].isFormation == "" then
                                isFormationStr, curFormationId = this.GetHeroFormationStr2(n)
                                table.insert(isFormations, curFormationId)
                            else
                                isFormationStr, curFormationId =this.GetHeroFormationStr2(n)
                                isFormationStr="、" ..isFormationStr
                                table.insert(isFormations, curFormationId)
                            end
                            heros[i].isFormation = heros[i].isFormation .. isFormationStr
                        end
                    end
                end
            end
            --所有的所在队伍id，
            heros[i].isFormations = isFormations
        end
    end
    --筛选
    if heros and LengthOfTable(heros) > 0 then
        for i, v in pairs(heros) do 
                --TODONow
                local isLock = false
                local teamIdList = HeroManager.GetAllFormationByHeroId(v.dynamicId)
                if teamIdList ~= nil and #teamIdList>0 then
                    for k,v in pairs(teamIdList)do
                        if v == FormationTypeDef.DEFENSE_TRAINING and DefenseTrainingManager.teamLock==1 then
                            isLock = true
                            break
                         end
                        --  --防守训练
                        -- if v == FormationTypeDef.FORMATION_DREAMLAND or --奥廖尔
                        -- v == FormationTypeDef.FORMATION_AoLiaoer then --奥廖尔
                        --     isLock = true
                        --     break
                        -- end
                    end
                
                end
            -- if isLock==true then

            -- elseif (v.lv > 1 and type == 1) or (v.lv > 0 and type == 2) then
            if (v.lv > 1 and type == 1) or (v.lv > 0 and type == 2) then
                if v.heroConfig.Material ~= 1 then
                    if _sortTypeId == 0 then
                        table.insert(heros2, v)
                    -- elseif _sortTypeId >= 7 then
                    --     if v.star == _sortTypeId - 4 then
                    --         table.insert(heros2, v)
                    --     end
                    else
                        if v.property == _sortTypeId then
                            table.insert(heros2, v)
                        end
                    end
                end
            end
        end
    end
    return heros2
end
--获取满足条件的所有英雄信息（改装厂回溯）  --0全部 1-6属性  type: 1普通回溯 2高级回溯
function this.GetAllHeroDataMsinusUpWar1(_sortTypeId,type)
    local heros = {}
    local heros2 = {}
    for i, v in pairs(heroDatas) do
        --队伍名称  以、 连接
        v.isFormation = ""
        table.insert(heros, v)
    end
    --标记编队上的英雄
    if heros and LengthOfTable(heros) > 0 then
        for i, v in pairs(heros) do
            local isFormations = {}
            for n, w in pairs(FormationManager.formationList) do
                for m = 1, #w.teamHeroInfos do
                    if w.teamHeroInfos[m] and v.dynamicId == w.teamHeroInfos[m].heroId then
                        --队伍名称  队伍id
                        local isFormationStr = ""
                        local curFormationId = 0
                        local temp = this.GetHeroFormationStr2(n)
                        if temp and temp ~= "" then
                            if heros[i].isFormation and heros[i].isFormation == "" then
                                isFormationStr, curFormationId = this.GetHeroFormationStr2(n)
                                table.insert(isFormations, curFormationId)
                            else
                                isFormationStr, curFormationId = this.GetHeroFormationStr2(n)
                                isFormationStr = "、" ..isFormationStr
                                table.insert(isFormations, curFormationId)
                            end
                            heros[i].isFormation = heros[i].isFormation .. isFormationStr
                        end
                    end
                end
            end
            --所有的所在队伍id，
            heros[i].isFormations = isFormations
        end
    end
    --筛选
    if heros and LengthOfTable(heros) > 0 then
        for i, v in pairs(heros) do 
            --TODONow
            local isLock = false
            local teamIdList = HeroManager.GetAllFormationByHeroId(v.dynamicId)
            -- if teamIdList ~= nil and #teamIdList > 0 then
            --     for k, v in pairs(teamIdList)do
            --         if v == FormationTypeDef.DEFENSE_TRAINING and DefenseTrainingManager.teamLock == 1 then
            --             isLock = true
            --             break
            --         end
            --          --防守训练
            --         if v == FormationTypeDef.FORMATION_DREAMLAND or --奥廖尔
            --         v == FormationTypeDef.FORMATION_AoLiaoer then --奥廖尔
            --             isLock = true
            --             break
            --         end
            --     end
            -- end
            if v.heroConfig.Material ~= 1 then
                if (v.star >= 7 and v.star <= 9 and type == 1) or (v.star >= 10 and type == 2)  then
                    if isLock == true then

                    elseif _sortTypeId == 0 then
                        table.insert(heros2, v)
                    -- elseif _sortTypeId >= 7 then
                    --     if v.star == _sortTypeId - 4 then
                    --         table.insert(heros2, v)
                    --     end
                    else
                        if v.property == _sortTypeId then
                            table.insert(heros2, v)
                        end
                    end    
                end
            end
        end
    end
    return heros2
end

--获取满足条件的所有英雄信息（改装厂改造） --0全部 1-6属性  type: 1普通回溯 2高级回溯
function this.GetAllHeroDataMsinusUpWar2(_sortTypeId,ExchangeConfigId)
    local heros = {}
    local heros2 = {}
    for i, v in pairs(heroDatas) do
        --队伍名称  以、 连接
        v.isFormation = ""
        table.insert(heros, v)
    end

    --标记编队上的英雄
    if heros and LengthOfTable(heros) > 0 then
        for i, v in pairs(heros) do
            local isFormations = {}
            for n, w in pairs(FormationManager.formationList) do
                for m = 1, #w.teamHeroInfos do
                    if w.teamHeroInfos[m] and v.dynamicId == w.teamHeroInfos[m].heroId then
                        --队伍名称  队伍id
                        local isFormationStr = ""
                        local curFormationId = 0
                        local temp = this.GetHeroFormationStr2(n)
                        if temp and temp ~= "" then
                            if heros[i].isFormation and heros[i].isFormation == "" then
                                isFormationStr, curFormationId = this.GetHeroFormationStr2(n)
                                table.insert(isFormations, curFormationId)
                            else
                                isFormationStr, curFormationId =this.GetHeroFormationStr2(n)
                                isFormationStr="、" ..isFormationStr
                                table.insert(isFormations, curFormationId)
                            end
                            heros[i].isFormation = heros[i].isFormation .. isFormationStr
                        end
                    end
                end
            end
            --所有的所在队伍id，
            heros[i].isFormations = isFormations
        end
    end
    --筛选
    if heros and LengthOfTable(heros) > 0 then
        for i, v in pairs(heros) do 
            -- if (v.star >= 7 and v.star<=9 and type == 1) or (v.star >= 10 and type == 2) then
            --     if _sortTypeId == 0 then
            --         table.insert(heros2, v)
            --     -- elseif _sortTypeId >= 7 then
            --     --     if v.star == _sortTypeId - 4 then
            --     --         table.insert(heros2, v)
            --     --     end
            --     else
            --         if v.property == _sortTypeId then
            --             table.insert(heros2, v)
            --         end
            --     end           
            -- end
            --条件一：最大星级大于等于10星的卡，Hero 表中 MaxRank >= 10
            --条件二：根据改装前卡牌阵营，符合 HeroExchangeConfig 表中 CanChangeCountry 字段所要求的阵营
            --条件三：星级等于  HeroExchangeConfig 表中 NeedStar 字段内容

            --TODONow
            local isLock = false
            local teamIdList = HeroManager.GetAllFormationByHeroId(v.dynamicId)
            if teamIdList ~= nil and #teamIdList > 0 then
                for k,v in pairs(teamIdList)do
                    if v == FormationTypeDef.DEFENSE_TRAINING or v == FormationTypeDef.FORMATION_DREAMLAND or v == FormationTypeDef.FORMATION_AoLiaoer then
                        isLock = true
                        break
                    end
                end
            end

            local canChangeCountry = {}
            canChangeCountry = HeroExchangeConfig[ExchangeConfigId].CanChangeCountry
            if v.heroConfig.Material ~= 1 then
                if v.heroConfig.MaxRank >= 10 and v.star == HeroExchangeConfig[ExchangeConfigId].NeedStar then
                    -- if isLock == true then
                    -- elseif _sortTypeId == 0 then
                    if _sortTypeId == 0 then
                        for i = 1, LengthOfTable(canChangeCountry) do
                            if canChangeCountry[i] == v.property then
                                table.insert(heros2, v)
                            end
                         end
                    else
                        if v.property == _sortTypeId then
                            table.insert(heros2, v)
                        end
                    end
                end
            end
        end
    end
    table.sort(heros2,function (a,b)
        return a.heroConfig.Id <b.heroConfig.Id
    end)
    return heros2
end

--筛选满足条件的所有英雄信息 --0全部 1-6属性  
function this.GetAllHeroDataByProperty(propertyId)
    local heros = {}
    local heros2 = {}
    for i, v in pairs(heroDatas) do
        table.insert(heros, v)
    end
    --筛选
    if heros and LengthOfTable(heros) > 0 then
        for i, v in pairs(heros) do
            if v.property == propertyId then
                table.insert(heros2, v)
            end   
        end
    end
    return heros2
end

--根据英雄id获得所在阵容
function this.GetFormationByHeroId(heroId)
    local teamId = nil
    for index, value in pairs(FormationManager.formationList) do
        for j = 1,#value.teamHeroInfos do
            if value.teamHeroInfos[j].heroId == heroId then
                teamId = index
                break
            end
        end
        if value.substitute == heroId then
            teamId = index
            break
        end
        if teamId ~= nil then
            break
        end
    end
    return teamId
end

function this.GetAllFormationByHeroId(heroId)
    local teamIdList = {}
    for index, value in pairs(FormationManager.formationList) do
        for j = 1, #value.teamHeroInfos do
            if value.teamHeroInfos[j].heroId == heroId then
                table.insert(teamIdList,index)
             break
            end
        end
        if value.substitute == heroId then
            table.insert(teamIdList,index)
        end
    end
    return teamIdList
end

function this.GetHeroFormationStr(teamId)
    if this.heroResolveLicence[teamId] then
        if teamId < FormationTypeDef.FORMATION_ARENA_DEFEND then
            return GetLanguageStrById(11101)
        elseif teamId == FormationTypeDef.FORMATION_ARENA_DEFEND then
            return GetLanguageStrById(11102)
        elseif teamId == FormationTypeDef.FORMATION_ARENA_ATTACK then
            return GetLanguageStrById(11103)
        elseif teamId == FormationTypeDef.FORMATION_ENDLESS_MAP then
            return GetLanguageStrById(11104)
        elseif teamId == FormationTypeDef.FORMATION_GUILD_FIGHT_DEFEND then
            return GetLanguageStrById(11105)
        elseif teamId == FormationTypeDef.FORMATION_GUILD_FIGHT_ATTACK then
            -- elseif teamId == FormationTypeDef.MONSTER_CAMP_ATTACK then
            --     return "该猎妖师在锁妖阵容中已上阵"-- 601
            return GetLanguageStrById(11106)
        elseif teamId == FormationTypeDef.BLOODY_BATTLE_ATTACK then
            return GetLanguageStrById(11107)
        elseif teamId == FormationTypeDef.EXPEDITION then
            return GetLanguageStrById(11108)
        elseif teamId == FormationTypeDef.ARENA_TOM_MATCH then
            return GetLanguageStrById(12280)
        elseif teamId == FormationTypeDef.CLIMB_TOWER then
            return GetLanguageStrById(12535)
        end
    end
    return ""
end

function this.GetHeroFormationStr2(teamId)
    if this.heroResolveLicence[teamId] then
        if teamId == FormationTypeDef.FORMATION_NORMAL then
            return GetLanguageStrById(11109), FormationTypeDef.FORMATION_NORMAL
        elseif teamId == FormationTypeDef.FORMATION_ARENA_DEFEND then
            return GetLanguageStrById(11110), FormationTypeDef.FORMATION_ARENA_DEFEND
        elseif teamId == FormationTypeDef.FORMATION_ARENA_ATTACK then
            return GetLanguageStrById(11111), FormationTypeDef.FORMATION_ARENA_ATTACK
        elseif teamId == FormationTypeDef.FORMATION_DREAMLAND then
            return GetLanguageStrById(10678), FormationTypeDef.FORMATION_DREAMLAND
        elseif teamId == FormationTypeDef.FORMATION_ENDLESS_MAP then
            return GetLanguageStrById(10694), FormationTypeDef.FORMATION_ENDLESS_MAP
        elseif teamId == FormationTypeDef.FORMATION_GUILD_FIGHT_DEFEND then
            return GetLanguageStrById(10680), FormationTypeDef.FORMATION_GUILD_FIGHT_DEFEND
        elseif teamId == FormationTypeDef.FORMATION_GUILD_FIGHT_ATTACK then
            return GetLanguageStrById(10681), FormationTypeDef.FORMATION_GUILD_FIGHT_ATTACK
        elseif teamId == FormationTypeDef.BLOODY_BATTLE_ATTACK then
            return GetLanguageStrById(11112), FormationTypeDef.BLOODY_BATTLE_ATTACK
        elseif teamId == FormationTypeDef.EXPEDITION then
            return GetLanguageStrById(10699), FormationTypeDef.EXPEDITION
        elseif teamId == FormationTypeDef.ARENA_TOM_MATCH then
            return GetLanguageStrById(12280), FormationTypeDef.ARENA_TOM_MATCH
        elseif teamId == FormationTypeDef.CLIMB_TOWER then
            return GetLanguageStrById(12535), FormationTypeDef.CLIMB_TOWER
        elseif teamId == FormationTypeDef.Arden_MIRROR then
            return GetLanguageStrById(22412), FormationTypeDef.Arden_MIRROR
        elseif teamId == FormationTypeDef.GUILD_TRANSCRIPT then
            return GetLanguageStrById(12324), FormationTypeDef.GUILD_TRANSCRIPT
        elseif teamId == FormationTypeDef.DEFENSE_TRAINING then
            return GetLanguageStrById(22413), FormationTypeDef.DEFENSE_TRAINING
        elseif teamId == FormationTypeDef.BLITZ_STRIKE then
            return GetLanguageStrById(22414), FormationTypeDef.BLITZ_STRIKE
        elseif teamId == FormationTypeDef.CONTEND_HEGEMONY then
            return GetLanguageStrById(22415), FormationTypeDef.CONTEND_HEGEMONY
        elseif teamId == FormationTypeDef.FORMATION_AoLiaoer then
            return GetLanguageStrById(10678), FormationTypeDef.FORMATION_AoLiaoer
        end
    end
    return ""
end

--删除本地英雄信息
function this.DeleteHeroDatas(heroDIds,index)
    for i = 1, #heroDIds do
        if heroDatas[heroDIds[i]] then
            --清除英雄装备上挂载的英雄id
            local equips = heroDatas[heroDIds[i]].equipIdList
            if equips and LengthOfTable(equips) > 0 then
                for i = 1, LengthOfTable(equips) do
                    EquipManager.DeleteSingleEquip(equips[i], heroDIds[i])
                end
            end

            --清除英雄法宝上挂载的英雄did
            --local talismanList=heroDatas[heroDIds[i]].talismanList
            --if talismanList and LengthOfTable(talismanList)>0 then
            --    for i = 1, LengthOfTable(talismanList) do
            --        if TalismanManager.talismanTabs[talismanList[i]] then
            --            TalismanManager.talismanTabs[talismanList[i]].upHeroDid="0"
            --        end
            --    end
            --end
            --
            --清楚编队上的英雄
            FormationManager.AllFormationDeleCurHeroId(heroDIds[i])
            --清除英雄魂印上挂载的英雄did
            SoulPrintManager.hasEquipSoulPrintId[heroDIds[i]] = nil
            --删除远征英雄数据
            ExpeditionManager.DelHeroHpValue(heroDatas[heroDIds[i]])

            --> 清除combatplan
            local planList = heroDatas[heroDIds[i]].planList

            if planList and #planList > 0 then
                for j = 1, #planList do
                    CombatPlanManager.DownPlanData(heroDIds[i], planList[j].planId)
                end
            end

            --卸下勋章
            MedalManager.DownMedalDaraByHero(heroDIds[i])

            --删除英雄
            heroDatas[heroDIds[i]] = nil
        end
    end
end

--更新本地单个英雄基本信息
function this.UpdateSingleHeroDatas(heroDId, heroLv, heroStar, breakId, upStarId, isCallBackChangeWar)
    if heroDatas[heroDId] then
        heroDatas[heroDId].lv = heroLv
        heroDatas[heroDId].star = heroStar
        heroDatas[heroDId].breakId = breakId
        heroDatas[heroDId].upStarId = upStarId
        local actionPowerRormula = gameSetting[1].ActionPowerRormula
        heroDatas[heroDId].actionPower =
            heroDatas[heroDId].heroConfig.ActionPower +
            math.floor(
                (actionPowerRormula[1] * math.pow(heroLv, 3) + actionPowerRormula[2] * math.pow(heroLv, 2) +
                    actionPowerRormula[3] * heroLv +
                    actionPowerRormula[4])
            )
    end
    if isCallBackChangeWar then
        this.CompareWarPower(heroDId)
    end
end

--更新本地单个英雄上锁
function this.UpdateSingleHeroLockState(heroDId, lockState)
    if heroDatas[heroDId] then
        heroDatas[heroDId].lockState = lockState
    end
end

--对比战力并更新战力值
function this.CompareWarPower(heroDId)
    local oldPowerNum = heroDatas[heroDId].warPower
    local newPowerNum = this.CalculateHeroAllProValList(1, heroDId, false)[HeroProType.WarPower]
    heroDatas[heroDId].warPower = newPowerNum
    if oldPowerNum and newPowerNum then
        if oldPowerNum ~= newPowerNum then
            if not UIManager.IsOpen(UIName.RoleUpStarSuccessPanel) and
                not UIManager.IsOpen(UIName.RoleUpLvBreakSuccessPanel)
             then
                -- UIManager.OpenPanel(
                --     UIName.WarPowerChangeNotifyPanelV2,
                --     {oldValue = oldPowerNum, newValue = newWarnewPowerNumPowerValue}
                -- )
                RefreshPower(oldPowerNum, newPowerNum)
            end
        end
    end
    FormationManager.CheckHeroIdExist(heroDId)
end

--更新本地单个英雄技能信息
function this.UpdateSingleHeroSkillData(_heroDId)
    if heroDatas[_heroDId] then

        local heroData = heroDatas[_heroDId]
        heroData.skillIdList = {}
        --主动技
        if heroData.heroConfig.OpenSkillRules then
            for i = 1, #heroData.heroConfig.OpenSkillRules do
                if heroData.heroConfig.OpenSkillRules[i][1] == heroData.star then
                    local heroSkill = {}
                    heroSkill.skillId = heroData.heroConfig.OpenSkillRules[i][2]
                    heroSkill.skillConfig = skillConfig[heroSkill.skillId]
                    table.insert(heroData.skillIdList, heroSkill)
                end
            end
        end
        heroData.passiveSkillList = {}
        --被动技
        if heroData.heroConfig.OpenPassiveSkillRules then
            for i = 1, #heroData.heroConfig.OpenPassiveSkillRules do
                if heroData.heroConfig.OpenPassiveSkillRules[i][1] == heroData.star then
                    local heroSkill = {}
                    heroSkill.skillId = heroData.heroConfig.OpenPassiveSkillRules[i][2]
                    heroSkill.skillConfig = passiveSkillConfig[heroSkill.skillId]
                    table.insert(heroData.passiveSkillList, heroSkill)
                end
            end
        end
    end
end

--更新本地单个英雄法宝信息  --type--1 穿单件法宝  2 卸单件法宝
function this.UpdateHeroSingleTalismanData(heroDId, heroTalismanDatas, type)
    if heroDatas[heroDId] then
        if type == 1 then
            heroDatas[heroDId].talismanList = {}
            for i = 1, #heroTalismanDatas do
                table.insert(heroDatas[heroDId].talismanList, heroTalismanDatas[i])
            end
        elseif type == 2 then
            for i = 1, #heroDatas[heroDId].talismanList do
                for j = 1, #heroTalismanDatas do
                    if heroDatas[heroDId].talismanList[i] == heroTalismanDatas[j] then
                        heroDatas[heroDId].talismanList[i] = nil
                    end
                end
            end
        end
    end
    this.CompareWarPower(heroDId)
end

--更新本地单个英雄魂印信息
function this.UpdateHeroSingleSoulPrint(heroDId, hasEquipSoulPrintId)
    local soulEquipPrintList = {}
    for i, v in pairs(hasEquipSoulPrintId[heroDId]) do
        local soulPrint = {did = v.did, pos = v.pos}
        table.insert(soulEquipPrintList, soulPrint)
    end
    heroDatas[heroDId].soulPrintList = soulEquipPrintList
    this.CompareWarPower(heroDId)
end

--获取单个英雄数据 dynamicId
function this.GetSingleHeroDataByDynamicId(heroDyd)
    for did ,hero in pairs(heroDatas) do
        if hero.dynamicId == heroDyd then
            return hero,did
        end
    end
    return nil
end

--获取单个英雄数据
function this.GetSingleHeroData(heroDId)
    if heroDatas[heroDId] then
        return heroDatas[heroDId]
    else
        --> todo 后续需要改
        local DefenseTrainingData = DefenseTrainingManager.GetSingleHeroData(heroDId)
        if DefenseTrainingData ~= nil then
            return DefenseTrainingData
        end

        --镜像数据
        --local mirrorData = HeroTemporaryManager.GetSingleHeroData(heroDId)
        --if mirrorData then
        --    return mirrorData
        --end 

        -- local ExpeditionData = ExpeditionManager.GetSingleHeroData(heroDId)
        -- if ExpeditionData ~= nil then
        --     return ExpeditionData
        -- end
        return nil
    end
end

--获取当前升星信息
function this.GetHeroCurUpStarInfo(heroDId)
    local indexStar = 0
    local RankupConsumeMaterial = {}
    for i, v in pairs(heroDatas) do
        if v.dynamicId == heroDId then
            if v.heroConfig.RankupConsumeMaterial then
                for j = 1, #v.heroConfig.RankupConsumeMaterial do
                    if #v.heroConfig.RankupConsumeMaterial[j] > 1 then
                        if v.heroConfig.RankupConsumeMaterial[j][1] > v.star then
                            if indexStar == 0 then
                                indexStar = v.heroConfig.RankupConsumeMaterial[j][1]
                            end
                            if v.heroConfig.RankupConsumeMaterial[j][1] == indexStar then
                                local heroUpStarMaterialsData = {}
                                heroUpStarMaterialsData.upStarData = v.heroConfig.RankupConsumeMaterial[j]
                                heroUpStarMaterialsData.upStarMaterialsData =
                                    heroRankUpGroup[v.heroConfig.RankupConsumeMaterial[j][3]]
                                table.insert(RankupConsumeMaterial, heroUpStarMaterialsData)
                            end
                        end
                    else
                        return nil
                    end
                end
            end
        end
    end
    return RankupConsumeMaterial
end

--检测卡库中的英雄是否有满足当前升星条件
function this.GetUpStarHeroListData(heroRankUpGroupId, heroData)
    local needHeroListData = {}
    needHeroListData.state = 0
    --0 没有 1 有满足条件单位英雄
    needHeroListData.heroList = {}
    local heroRankUpGroup = heroRankUpGroup[heroRankUpGroupId]
    for i, v in pairs(heroDatas) do
        --TODONow
        local isLock = false
        local teamIdList = HeroManager.GetAllFormationByHeroId(v.dynamicId)
        if teamIdList ~= nil and #teamIdList > 0 then
            for k,n in pairs(teamIdList)do
                if n == FormationTypeDef.DEFENSE_TRAINING and DefenseTrainingManager.teamLock == 1 then
                    isLock = true
                    break
                end
                 --防守训练
                -- if n == FormationTypeDef.FORMATION_DREAMLAND or n == FormationTypeDef.FORMATION_AoLiaoer then
                --     isLock = true
                --     break
                -- end
            end
        end
        if v.dynamicId == heroData.dynamicId then --自己筛掉
        -- elseif isLock == true then --防守训练 奥廖尔筛掉
        else
            v.isFormation = ""
            if heroRankUpGroup.Issame == 1 then --需要同名卡
                if v.id == heroData.id then
                    if v.star == heroRankUpGroup.StarLimit then
                        if heroRankUpGroup.IsSameClan == 1 then
                            if v.property == heroData.property then
                                if heroRankUpGroup.IsId > 0 then
                                    if v.id == heroRankUpGroup.IsId then
                                        table.insert(needHeroListData.heroList, v)
                                    end
                                else
                                    table.insert(needHeroListData.heroList, v)
                                end
                            end
                        else
                            if heroRankUpGroup.IsId > 0 then
                                if v.id == heroRankUpGroup.IsId then
                                    table.insert(needHeroListData.heroList, v)
                                end
                            else
                                table.insert(needHeroListData.heroList, v)
                            end
                        end
                    end
                end
            else
                if v.star == heroRankUpGroup.StarLimit then
                    if heroRankUpGroup.IsSameClan == 1 then
                        if v.property == heroData.property then
                            if heroRankUpGroup.IsId > 0 then
                                if v.id == heroRankUpGroup.IsId then
                                    table.insert(needHeroListData.heroList, v)
                                end
                            else
                                table.insert(needHeroListData.heroList, v)
                            end
                        end
                    else
                        if heroRankUpGroup.IsId > 0 then
                            if v.id == heroRankUpGroup.IsId then
                                table.insert(needHeroListData.heroList, v)
                            end
                        else
                            table.insert(needHeroListData.heroList, v)
                        end
                    end
                end
            end
        end
    end
    --删除编队上的英雄
    if needHeroListData.heroList and LengthOfTable(needHeroListData.heroList) > 0 then
        for i, v in pairs(needHeroListData.heroList) do
            for n, w in pairs(FormationManager.formationList) do
                if this.heroResolveLicence[n] then
                    for m = 1, #w.teamHeroInfos do
                        if v.dynamicId == w.teamHeroInfos[m].heroId then

                            local isFormationStr = this.GetHeroFormationStr2(n)
                            v.isFormation = isFormationStr
                        end
                    end
                end
            end
        end
    end
    --删除冒险上的英雄
    --if needHeroListData.heroList and LengthOfTable(needHeroListData.heroList)>0 then
    --    for i, v in pairs(needHeroListData.heroList) do
    --        for n,w in pairs(AdventureManager.heroList) do
    --            for m = 1, #w do
    --                if v.dynamicId==w[m] then
    --                    needHeroListData.heroList[i] = nil
    --                end
    --            end
    --        end
    --    end
    --end
    local needHeroListData2 = {}
    needHeroListData2.state = 0
    --0 没有 1 有满足条件单位英雄
    needHeroListData2.heroList = {}
    for i, v in pairs(needHeroListData.heroList) do
        table.insert(needHeroListData2.heroList, v)
    end
    if #needHeroListData2.heroList > 0 then
        needHeroListData2.state = 1
    end
    table.sort(
        needHeroListData2,
        function(a, b)
            if a.id == b.id then
                if a.lv == b.lv then
                    return a.id > b.id
                else
                    return a.lv < b.lv
                end
            else
                return a.id > b.id
            end
        end
    )

    return needHeroListData2
end

--计算每个星级的英雄等级最终上限
function this.UpdateHeroLvEnd()
    --计算每个最终等级上限
    this.heroLvEnd = {}
    for i, v in ConfigPairs(heroConfig) do
        local heroEndStar = v.Star
        if v.RankupConsumeMaterial and type(v.RankupConsumeMaterial[1][1]) ~= "userdata" then
            local curRankupConsumeMaterial = v.RankupConsumeMaterial[#v.RankupConsumeMaterial]
            if curRankupConsumeMaterial then
                heroEndStar = curRankupConsumeMaterial[1]
            end
        end
        -- if heroEndStar == nil then
        --     heroEndStar = v.Star
        -- end
        for i, v2 in ConfigPairs(heroRankUpConfig) do
            if v2.Star == v.Star then
                if v2.OpenStar == heroEndStar then
                    this.heroLvEnd[v.Id] = v2.OpenLevel
                end
            end
        end
        if this.heroLvEnd[v.Id] == nil then
            this.heroLvEnd[v.Id] = 1
        end
    end
    --local threeStarLvEnd = 3
    --local fourStarLvEnd = 4
    --local fiveStarLvEnd = 5
    --this.heroLvBreakNum[threeStarLvEnd] = 0
    --this.heroLvBreakNum[fourStarLvEnd] = 0
    --this.heroLvBreakNum[fiveStarLvEnd] = 0
    --for i,v in ConfigPairs(heroRankUpConfig) do
    --    if v.Star == threeStarLvEnd then
    --        if v.Type == 1 and this.heroLvBreakNum[threeStarLvEnd] < v.RankupPara then
    --            this.heroLvBreakNum[threeStarLvEnd]=v.RankupPara
    --        end
    --    elseif v.Star == fourStarLvEnd then
    --        if v.Type == 1 and this.heroLvBreakNum[fourStarLvEnd] < v.RankupPara then
    --            this.heroLvBreakNum[fourStarLvEnd]=v.RankupPara
    --        end
    --    elseif v.Star == fiveStarLvEnd then
    --        if v.Type == 1 and this.heroLvBreakNum[fiveStarLvEnd] < v.RankupPara then
    --            this.heroLvBreakNum[fiveStarLvEnd] = v.RankupPara
    --        end
    --    end
    --end
end

--计算英雄当前星级的等级上限
function this.GetCurHeroStarLvEnd(getValType, curHeroData, _breakId, _upStarId)
    local breakId = 0
    local upStarId = 0
    if getValType == 1 then
        breakId = curHeroData.breakId
        upStarId = curHeroData.upStarId
    else
        breakId = _breakId
        upStarId = _upStarId
    end
    if--[[ breakId == 0 and ]] upStarId > 0 then --从没突破过 显示当前初始星级的等级上限
        -- for i, v in ConfigPairs(heroRankUpConfig) do
        --     if v.Star == curHeroData.heroConfig.Star then
        --         return v.LimitLevel
        --     end
      return heroRankUpConfig[upStarId].OpenLevel
    elseif breakId > 0 and heroRankUpConfig[breakId].JudgeClass ~= 1 and upStarId ==0 then --没突破完毕 显示当前突破的等级上限
        return heroRankUpConfig[breakId].OpenLevel
    elseif breakId > 0 and heroRankUpConfig[breakId].JudgeClass == 1 then --突破完毕 显示当前进阶的等级上限
        if upStarId > 0 then
            return heroRankUpConfig[upStarId].OpenLevel
        else
            return heroRankUpConfig[breakId].OpenLevel
        end
    end
end

--刷新英雄战力
function this.UpdateHeroPower()
    for _, v in pairs(heroDatas) do
        v.warPower = this.CalculateHeroAllProValList(1, v.dynamicId, false)[HeroProType.WarPower]
    end
end

--获取同一类型的技能
function this.GetTypeAllSkillData(_skillName)
    local allTypeSkillData = {}
    for i, v in ConfigPairs(skillConfig) do
        if v.Name == _skillName then
            table.insert(allTypeSkillData, v)
        end
    end
    return allTypeSkillData
end

--获得英雄属性计算战斗力属性评分
function this.GetSingleProScoreVal()
    this.heroPropertyScore = {}
    for i, v in ConfigPairs(propertyConfig) do
        this.heroPropertyScore[i] = v.Score --战力读表修改
    end
end

--计算所有装备加成的属性值
local function CalculateHeroUpEquipsProAddVal(_heroId)
    local addAllProVal = {}
    for i, v in ConfigPairs(propertyConfig) do
        addAllProVal[i] = 0
    end
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData then
        
        local equipSuit = {}
        --[id] = 件数
        for i = 1, #curHeroData.equipIdList do
            local curEquip = EquipManager.GetSingleHeroSingleEquipData(curHeroData.equipIdList[i], _heroId)
            if curEquip then
                for index, prop in ipairs(curEquip.mainAttribute) do
                    local id = prop.propertyId
                    local value = prop.propertyValue
                    if addAllProVal[id] then
                        addAllProVal[id] = addAllProVal[id] + value
                    else
                        addAllProVal[id] = value
                    end
                end
                --套装加成
                if equipSuit[curEquip.equipConfig.SuiteID] then
                    equipSuit[curEquip.equipConfig.SuiteID] = equipSuit[curEquip.equipConfig.SuiteID] + 1
                else
                    equipSuit[curEquip.equipConfig.SuiteID] = 1
                end
            end
        end

        if equipSuit and LengthOfTable(equipSuit) > 0 then
            for i, v in pairs(equipSuit) do
                local curSuitConfig = equipsuite[i]
                if v > 1 then
                    if curSuitConfig and curSuitConfig.SuiteValue then
                        for j = 1, #curSuitConfig.SuiteValue do
                            if v >= curSuitConfig.SuiteValue[j][1] then
                                local curProId = curSuitConfig.SuiteValue[j][2]
                                local curProVal = curSuitConfig.SuiteValue[j][3]
                                
                                if addAllProVal[curProId] then
                                    addAllProVal[curProId] = addAllProVal[curProId] + curProVal
                                else
                                    addAllProVal[curProId] = curProVal
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return addAllProVal
end

--计算所有法宝加成的属性值
local function CalculateHeroUpTalismanProAddVal(_heroId, _breakId, _upStarId,teamCurPropertyName)
    local addAllProVal = {}
    local singleHeroProVal, lvProVal, allHeroProVal, specialProVal
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData and curHeroData.heroConfig.EquipTalismana then
        local star = curHeroData.star
        if heroRankUpConfig[_upStarId] then
            star = heroRankUpConfig[_upStarId].OpenStar
        end
        if star >= curHeroData.heroConfig.EquipTalismana[1] then
            local curTalisman = ConfigManager.GetConfigData(ConfigName.HeroConfig, curHeroData.id).EquipTalismana
            if curTalisman and curTalisman[2] then
                local talismanConFig =
                    ConfigManager.GetConfigDataByDoubleKey(
                    ConfigName.EquipTalismana,
                    "TalismanaId",
                    curTalisman[2],
                    "Level",
                    curHeroData.talismanList
                )
                if talismanConFig then
                    --主属性
                    for j = 1, #talismanConFig.Property do
                        if addAllProVal[talismanConFig.Property[j][1]] then
                            addAllProVal[talismanConFig.Property[j][1]] = addAllProVal[talismanConFig.Property[j][1]] + talismanConFig.Property[j][2]
                        else
                            addAllProVal[talismanConFig.Property[j][1]] = talismanConFig.Property[j][2]
                        end
                    end
                    --副属性
                    if talismanConFig.SpecialProperty and #talismanConFig.SpecialProperty > 0 then
                        for k = 1, #talismanConFig.SpecialProperty do
                            if talismanConFig.SpecialProperty[k][1] == curHeroData.profession then
                                if addAllProVal[talismanConFig.SpecialProperty[k][2]] then
                                    addAllProVal[talismanConFig.SpecialProperty[k][2]] = addAllProVal[talismanConFig.SpecialProperty[k][2]] + talismanConFig.SpecialProperty[k][3]
                                else
                                    addAllProVal[talismanConFig.SpecialProperty[k][2]] = talismanConFig.SpecialProperty[k][3]
                                end
                            end
                        end
                    end
                    --当前法宝全部天赋数据(天赋可能为空)
                    local dowerAllData = ConfigManager.GetAllConfigsDataByKey(ConfigName.EquipTalismana, "TalismanaId", curTalisman[2])
                    local skillIds = {}
                    for i = 1, #dowerAllData do
                        if dowerAllData[i].OpenSkillRules and curHeroData.talismanList >= dowerAllData[i].Level then
                            for k = 1, #dowerAllData[i].OpenSkillRules do
                                table.insert(skillIds, dowerAllData[i].OpenSkillRules[k])
                            end
                        end
                    end
                    --被动技能计算
                    if skillIds and #skillIds > 0 then --talismanConFig.OpenSkillRules and #talismanConFig.OpenSkillRules > 0 then
                        --单体加成  --单体等级限制加成  --团体加成  --减乘
                        singleHeroProVal, lvProVal, allHeroProVal, specialProVal = this.CalculatePassiveSkillsValList(WarPowerType.Talisman, skillIds,teamCurPropertyName,curHeroData)
                    end
                end
            end
        end
    end
    if singleHeroProVal and LengthOfTable(singleHeroProVal) > 0 then
        for i, v in pairs(singleHeroProVal) do
            if addAllProVal[i] then
                addAllProVal[i] = addAllProVal[i] + v
            else
                addAllProVal[i] = v
            end
        end
    end
    return addAllProVal, lvProVal, allHeroProVal, specialProVal
end

--英雄身上魂印属性计算
local function CalculateSoulPrintAddVal(_heroId)
    -- local allSoulPrintAddWarPowerVal = 0
    -- local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    -- if curHeroData then
    --     if (table.nums(curHeroData.soulPrintList) >= 1) then
    --         for i = 1, #curHeroData.soulPrintList do
    --             local cursoulPrintConfig = equipConfig[curHeroData.soulPrintList[i].equipId]
    --             if cursoulPrintConfig then
    --                 allSoulPrintAddWarPowerVal = allSoulPrintAddWarPowerVal + cursoulPrintConfig.Score
    --             end
    --         end
    --     end
    -- end
    -- return allSoulPrintAddWarPowerVal

    local addAllProVal = {}
    local singleHeroProVal,lvProVal,allHeroProVal,specialProVal
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData then
       if table.nums(curHeroData.soulPrintList) >= 1 then
           for i = 1, #curHeroData.soulPrintList do
               local cursoulPrintConfig = equipConfig[curHeroData.soulPrintList[i].equipId]
               if cursoulPrintConfig then
                   --基础属性计算
                   local soulPrintPropertyList = cursoulPrintConfig.Property
                   if soulPrintPropertyList and #soulPrintPropertyList > 0 then
                       for i,v in pairs(soulPrintPropertyList) do
                           if(addAllProVal[v[1]]) then
                               addAllProVal[v[1]]=v[2]+addAllProVal[v[1]]
                           else
                               addAllProVal[v[1]]=v[2]
                           end
                       end
                   end
                   --被动技能计算
                   if cursoulPrintConfig.PassiveSkill then
                       --单体加成  --单体等级限制加成  --团体加成  --减乘
                      singleHeroProVal,lvProVal,allHeroProVal,specialProVal =  this.CalculatePassiveSkillsValList(WarPowerType.SoulPrint,cursoulPrintConfig.PassiveSkill)
                   end
               end
           end
       end
    end
    if singleHeroProVal and LengthOfTable(singleHeroProVal) > 0 then
       for i,v in pairs(singleHeroProVal) do
           if addAllProVal[i] then
               addAllProVal[i] = addAllProVal[i] + v
           else
               addAllProVal[i] = v
           end
       end
    end
    return addAllProVal,lvProVal,allHeroProVal,specialProVal
end

--英雄身上宝器属性计算
local function CalculateEquipTreaSureAddVal(_heroId)
    local addAllProVal = {}
    local minLv
    local mainRefineLv
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData then
        if #curHeroData.jewels > 0 then
            for i = 1, #curHeroData.jewels do
                local did = curHeroData.jewels[i]
                local curEuipTreaSureData =
                    EquipTreasureManager.GetSingleTreasureByIdDyn(did) or
                    ExpeditionManager.GetSingleTreasureByIdDyn(did)
                local curEuipTreaSureConfig = jewelConfig[curEuipTreaSureData.id]
                for _, configInfo in ConfigPairs(jewelRankupConfig) do
                    --强化的属性
                    if configInfo.PoolID == curEuipTreaSureConfig.LevelupPool and configInfo.Type == 1 and
                            configInfo.Level == curEuipTreaSureData.lv
                     then
                        for j = 1, #configInfo.Property do
                            if addAllProVal[configInfo.Property[j][1]] then
                                addAllProVal[configInfo.Property[j][1]] =
                                    addAllProVal[configInfo.Property[j][1]] + configInfo.Property[j][2]
                            else
                                addAllProVal[configInfo.Property[j][1]] = configInfo.Property[j][2]
                            end
                        end
                    end
                    --精炼的属性
                    if configInfo.PoolID == curEuipTreaSureConfig.RankupPool and configInfo.Type == 2 and
                        configInfo.Level == curEuipTreaSureData.refineLv
                    then
                        for j = 1, #configInfo.Property do
                            if addAllProVal[configInfo.Property[j][1]] then
                                addAllProVal[configInfo.Property[j][1]] =
                                    addAllProVal[configInfo.Property[j][1]] + configInfo.Property[j][2]
                            else
                                addAllProVal[configInfo.Property[j][1]] = configInfo.Property[j][2]
                            end
                        end
                    end
                end
                if #curHeroData.jewels > 1 then
                    --取 强化 精炼 最小值
                    if minLv then
                        if curEuipTreaSureData.lv < minLv then
                            minLv = curEuipTreaSureData.lv
                        end
                    else
                        minLv = curEuipTreaSureData.lv
                    end
                    if mainRefineLv then
                        if curEuipTreaSureData.refineLv < mainRefineLv then
                            mainRefineLv = curEuipTreaSureData.refineLv
                        end
                    else
                        mainRefineLv = curEuipTreaSureData.refineLv
                    end
                end
            end
            --math.min()
            --取 强化 精炼 共鸣属性
            if #curHeroData.jewels > 1 then
                local lvjewelResonanceConfig
                local refineLvjewelResonanceConfig
                for _, curjewelResonanceConfig in ConfigPairs(jewelResonanceConfig) do
                    if lvjewelResonanceConfig then
                        if
                            curjewelResonanceConfig.Type == 1 and curjewelResonanceConfig.Level <= minLv and
                                curjewelResonanceConfig.Id > lvjewelResonanceConfig.Id
                         then
                            lvjewelResonanceConfig = curjewelResonanceConfig
                        end
                    else
                        if curjewelResonanceConfig.Type == 1 and curjewelResonanceConfig.Level <= minLv then
                            lvjewelResonanceConfig = curjewelResonanceConfig
                        end
                    end
                    if refineLvjewelResonanceConfig then
                        if
                            curjewelResonanceConfig.Type == 2 and curjewelResonanceConfig.Level <= mainRefineLv and
                                curjewelResonanceConfig.Id > refineLvjewelResonanceConfig.Id
                         then
                            refineLvjewelResonanceConfig = curjewelResonanceConfig
                        end
                    else
                        if curjewelResonanceConfig.Type == 2 and curjewelResonanceConfig.Level <= mainRefineLv then
                            refineLvjewelResonanceConfig = curjewelResonanceConfig
                        end
                    end
                end
                --
                if lvjewelResonanceConfig then
                    for j = 1, #lvjewelResonanceConfig.Property do
                        if addAllProVal[lvjewelResonanceConfig.Property[j][1]] then
                            addAllProVal[lvjewelResonanceConfig.Property[j][1]] =
                                addAllProVal[lvjewelResonanceConfig.Property[j][1]] +
                                lvjewelResonanceConfig.Property[j][2]
                        else
                            addAllProVal[lvjewelResonanceConfig.Property[j][1]] = lvjewelResonanceConfig.Property[j][2]
                        end
                    end
                end
                if refineLvjewelResonanceConfig then
                    for j = 1, #refineLvjewelResonanceConfig.Property do
                        if addAllProVal[refineLvjewelResonanceConfig.Property[j][1]] then
                            addAllProVal[refineLvjewelResonanceConfig.Property[j][1]] =
                                addAllProVal[refineLvjewelResonanceConfig.Property[j][1]] +
                                refineLvjewelResonanceConfig.Property[j][2]
                        else
                            addAllProVal[refineLvjewelResonanceConfig.Property[j][1]] =
                                refineLvjewelResonanceConfig.Property[j][2]
                        end
                    end
                end
            end
        end
    end
    return addAllProVal
end

--计算能力属性
local function CalculateWarWayAddVal(_heroId)
    local addAllProVal = {}
    local singleHeroProVal,lvProVal,allHeroProVal,specialProVal
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData then
        local passiveSkills = {}
        if curHeroData.warWaySlot1Id > 0 then
            table.insert(passiveSkills, curHeroData.warWaySlot1Id)
        end
        if curHeroData.warWaySlot2Id > 0 then
            table.insert(passiveSkills, curHeroData.warWaySlot2Id)
        end
        --被动技能计算
        if #passiveSkills > 0 then
            --LogError("passiveSkills",passiveSkills[1])
            --单体加成  --单体等级限制加成  --团体加成  --减乘
            singleHeroProVal,lvProVal,allHeroProVal,specialProVal =  this.CalculatePassiveSkillsValList(WarPowerType.WarWayAndCombatPlan, passiveSkills)
        end
    end
    if singleHeroProVal and LengthOfTable(singleHeroProVal) > 0 then
       for i,v in pairs(singleHeroProVal) do
           if addAllProVal[i] then
               addAllProVal[i] = addAllProVal[i] + v
           else
               addAllProVal[i] = v
           end
       end
    end
    return addAllProVal,lvProVal,allHeroProVal,specialProVal
end

--计算戒指属性
local function CalculateCombatPlanAddVal(_heroId)
    local addAllProVal = {}
    local singleHeroProVal,lvProVal,allHeroProVal,specialProVal
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData then
        local passiveSkills = {}
        if curHeroData.planList and #curHeroData.planList > 0 then
            for i = 1, #curHeroData.planList do
                local planDid = curHeroData.planList[i].planId
                local planData = CombatPlanManager.GetPlanData(planDid)
                if planData then
                    -- 主
                    for j = 1, #planData.property do
                        local id = planData.property[j].id
                        local value = planData.property[j].value
                        if addAllProVal[id] then
                            addAllProVal[id] = addAllProVal[id] + value
                        else
                            addAllProVal[id] = value
                        end
                    end

                    -- 被动技能
                    for j = 1, #planData.skill do
                        table.insert(passiveSkills, planData.skill[j])
                    end
                end
            end
        end

        --被动技能计算
        if #passiveSkills > 0 then
            --单体加成  --单体等级限制加成  --团体加成  --减乘
            singleHeroProVal,lvProVal,allHeroProVal,specialProVal =  this.CalculatePassiveSkillsValList(WarPowerType.WarWayAndCombatPlan, passiveSkills)
        end
    end
    if singleHeroProVal and LengthOfTable(singleHeroProVal) > 0 then
        for i, v in pairs(singleHeroProVal) do
            if addAllProVal[i] then
                addAllProVal[i] = addAllProVal[i] + v
            else
                addAllProVal[i] = v
            end
        end
    end
    return addAllProVal,lvProVal,allHeroProVal,specialProVal
end

--计算能力和戒指属性
local function CalculateCombatPlanAndWarWayAddVal(_heroId)
    local addAllProVal = {}
    local singleHeroProVal,lvProVal,allHeroProVal,specialProVal
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData then
        local passiveSkills = {}
        if curHeroData.planList and #curHeroData.planList > 0 then
            for i = 1, #curHeroData.planList do
                local planDid = curHeroData.planList[i].planId
                local planData = CombatPlanManager.GetPlanData(planDid)
                if planData then
                    -- 主
                    for j = 1, #planData.property do
                        local id = planData.property[j].id
                        local value = planData.property[j].value
                        if addAllProVal[id] then
                            addAllProVal[id] = addAllProVal[id] + value
                        else
                            addAllProVal[id] = value
                        end
                    end

                    -- 被动技能
                    for j = 1, #planData.skill do
                        table.insert(passiveSkills, planData.skill[j])
                    end
                end
            end
        end

        if curHeroData.warWaySlot1Id > 0 then
            table.insert(passiveSkills, curHeroData.warWaySlot1Id)
        end
        if curHeroData.warWaySlot2Id > 0 then
            table.insert(passiveSkills, curHeroData.warWaySlot2Id)
        end
        --被动技能计算
        if #passiveSkills > 0 then
            local config = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
            local repeatList = {}
            for i = 1, #passiveSkills do
                local id = passiveSkills[i]
                local state = true
                for i = 1, #repeatList do
                    if config[id].Group == repeatList[i].group then
                        state = false
                        if config[id].Level > repeatList[i].lv then
                            repeatList[i].id = id
                            repeatList[i].group = config[id].Group
                            repeatList[i].lv = config[id].Level
                        end
                    end
                end
                if state then
                    table.insert(repeatList, {id = id, group = config[id].Group, lv = config[id].Level})
                end
            end

            passiveSkills = {}
            for i = 1, #repeatList do
                table.insert(passiveSkills, repeatList[i].id)
            end

            --单体加成  --单体等级限制加成  --团体加成  --减乘
            singleHeroProVal,lvProVal,allHeroProVal,specialProVal = this.CalculatePassiveSkillsValList(WarPowerType.WarWayAndCombatPlan, passiveSkills)
        end
    end

    if singleHeroProVal and LengthOfTable(singleHeroProVal) > 0 then
        for i,v in pairs(singleHeroProVal) do
            if addAllProVal[i] then
                addAllProVal[i] = addAllProVal[i] + v
            else
                addAllProVal[i] = v
            end
        end
    end
    return addAllProVal,lvProVal,allHeroProVal,specialProVal
end

--计算勋章属性
local function CalculateMedalAddVal(_heroId)
    local addAllProVal = {}
    local singleHeroProVal,lvProVal,allHeroProVal,specialProVal
   -- local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    local medalList = MedalManager.MedalDaraByHero(_heroId)
    if medalList and LengthOfTable(medalList) > 0 then
        for i = 1, 4 do
            local medalData = medalList[i]
            if medalList[i] then
                -- 基础属性
                local id = medalData.BasicProperty[1]
                local value = medalData.BasicProperty[2]
                if addAllProVal[id] then
                    addAllProVal[id] = addAllProVal[id] + value
                else
                    addAllProVal[id] = value
                end
                -- 随机属性
                if #medalData.RandomProperty > 0 then
                    for j = 1, #medalData.RandomProperty do
                        local id = medalData.RandomProperty[j].id
                        local value = medalData.RandomProperty[j].value
                        if addAllProVal[id] then
                            addAllProVal[id] = addAllProVal[id] + value
                        else
                            addAllProVal[id] = value
                        end
                    end
                end      
            end
        end
    end

    -- if curHeroData then
    --     if curHeroData.medal and #curHeroData.medal > 0 then
    --         for i = 1, #curHeroData.medal do
    --             local medalDid = curHeroData.medal[i].id
    --             local medalData = MedalManager.GetOneMedalData(medalDid)
    --             if medalData then
    --                 -- 基础属性
    --                 local id = medalData.BasicProperty[1]
    --                 local value = medalData.BasicProperty[2]
    --                 if addAllProVal[id] then
    --                     addAllProVal[id] = addAllProVal[id] + value
    --                 else
    --                     addAllProVal[id] = value
    --                 end
    --                 -- 随机属性
    --                 if #medalData.RandomProperty>0 then
    --                     for j = 1, #medalData.RandomProperty do
    --                         local id = medalData.RandomProperty[j].id
    --                         local value = medalData.RandomProperty[j].value
    --                         if addAllProVal[id] then
    --                             addAllProVal[id] = addAllProVal[id] + value
    --                         else
    --                             addAllProVal[id] = value
    --                         end
    --                     end
    --                 end
                   
    --             end
    --         end
    --     end
    -- end

    return addAllProVal
end

--计算勋章套装属性
local function CalculateMedalSuitAddVal(_heroId)
    local addAllProVal = {}
    local singleHeroProVal,lvProVal,allHeroProVal,specialProVal
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData then
        local passiveSkills = {}
        if curHeroData.suitActive and #curHeroData.suitActive > 0 then
            for i = 1, 2 do
                if curHeroData.suitActive[i] then
                    local suitId = curHeroData.suitActive[i].suitId
                    local suitNum = curHeroData.suitActive[i].num
                    local medalSuitData = MedalManager.GetMedalSuitInfoById(suitId)
                    for k,v in pairs(medalSuitData.SuitAttr) do
                        if v[1] == suitNum then
                            if v[2] == 8888 then
                                --激活技能
                                -- local PassiveSkillConfigData=ConfigManager.GetConfigDataByKey(ConfigName.PassiveSkillConfig, "Id", v[3])
                                -- icon:GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(PassiveSkillConfigData.icon))
                                -- value:GetComponent("Text").text=string.format("技能:%s",PassiveSkillConfigData.Name)
                                table.insert(passiveSkills,v[3])
                            else
                                if addAllProVal[v[2]] then
                                    addAllProVal[v[2]] = addAllProVal[v[2]] + v[3]
                                else
                                    addAllProVal[v[2]] = v[3]
                                end
                            end
                        end
                    end
                end
            end
        end

        --被动技能计算
        if #passiveSkills > 0 then
            --单体加成  --单体等级限制加成  --团体加成  --减乘
            singleHeroProVal,lvProVal,allHeroProVal,specialProVal =  this.CalculatePassiveSkillsValList(WarPowerType.medalSuit, passiveSkills)
        end
        if singleHeroProVal and LengthOfTable(singleHeroProVal) > 0 then
            for i,v in pairs(singleHeroProVal) do
                if addAllProVal[i] then
                    addAllProVal[i] = addAllProVal[i] + v
                else
                    addAllProVal[i] = v
                end
            end
         end
    end

    return addAllProVal,lvProVal,allHeroProVal,specialProVal
end

--计算图腾属性
local function CalculateTotemAddVal(_heroId)
    local addAllProVal = {}
    local singleHeroProVal,lvProVal,allHeroProVal,specialProVal
   -- local curHeroData =HeroManager.GetSingleHeroData(_heroId)
    local totemData = TotemManager.GetTotemDataByHeroId(_heroId)
    local passiveSkills = {}
    if totemData ~= nil then
        local totemItems = ConfigManager.GetAllConfigsDataByKey(ConfigName.ExpeditionTotemConfig,"ItemId",totemData.idDyn)
        for i = 1, #totemItems do
            local item = totemItems[i]
            if totemData.id >= item.Id then
                for j = 1, #item.Attr do
                    if addAllProVal[item.Attr[j][1]] then
                        addAllProVal[item.Attr[j][1]] = addAllProVal[item.Attr[j][1]] + item.Attr[j][2]
                    else
                        addAllProVal[item.Attr[j][1]] = item.Attr[j][2]
                    end
                end
            else
                break
            end
        end

        --被动技能计算
        local step = totemData.step
        local itemlist = ConfigManager.GetAllConfigsDataByKey("ExpeditionTotemTypeConfig","ItemId",totemData.idDyn)
        for i = 1, #itemlist do
           if i <= step then
               table.insert(passiveSkills,itemlist[i].SkillId)
           end 
        end
    end
    -- if totemData~=nil then
    --     if #totemData.Totemconfig.Attr>0 then
    --         for j = 1, #totemData.Totemconfig.Attr do
    --             local id = totemData.Totemconfig.Attr[j][1]
    --             local value = totemData.Totemconfig.Attr[j][2]
    --             if addAllProVal[id] then
    --                 addAllProVal[id] = addAllProVal[id] + value
    --             else
    --                 addAllProVal[id] = value
    --             end
    --         end
    --     end   
    --      --被动技能计算
    --     local step= totemData.step
    --     local itemlist=ConfigManager.GetAllConfigsDataByKey("ExpeditionTotemTypeConfig","ItemId",totemData.idDyn)
    --     for i = 1, #itemlist do
    --         if i<=step then
    --            table.insert(passiveSkills,itemlist[i].SkillId)
    --         end 
    --     end
    -- end

    if #passiveSkills > 0 then
        --单体加成  --单体等级限制加成  --团体加成  --减乘
        singleHeroProVal,lvProVal,allHeroProVal,specialProVal =  this.CalculatePassiveSkillsValList(WarPowerType.Totem, passiveSkills)
    end
    if singleHeroProVal and LengthOfTable(singleHeroProVal) > 0 then
        for i,v in pairs(singleHeroProVal) do
            if addAllProVal[i] then
                addAllProVal[i] = addAllProVal[i] + v
            else
                addAllProVal[i] = v
            end
        end
    end

    return addAllProVal,lvProVal,allHeroProVal,specialProVal
end

--计算特性属性
local function CalculateTalentAddVal(_heroId)
    local addAllProVal = {}
    local singleHeroProVal,lvProVal,allHeroProVal,specialProVal
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData then
        local passiveSkills = {}
        for i = 1, 5 do
            if curHeroData.talent and curHeroData.talent[i] then
                -- 被动技能
                table.insert(passiveSkills, curHeroData.talent[i].skillId)
            end
        end

        --被动技能计算
        if #passiveSkills > 0 then
            --单体加成  --单体等级限制加成  --团体加成  --减乘
            singleHeroProVal,lvProVal,allHeroProVal,specialProVal =  this.CalculatePassiveSkillsValList(WarPowerType.Talent, passiveSkills)
        end
    end
    if singleHeroProVal and LengthOfTable(singleHeroProVal) > 0 then
       for i,v in pairs(singleHeroProVal) do
           if addAllProVal[i] then
               addAllProVal[i] = addAllProVal[i] + v
           else
               addAllProVal[i] = v
           end
       end
    end
    return addAllProVal,lvProVal,allHeroProVal,specialProVal
end

--计算所有英雄被动技能的属性值
local function CalculateHeroPassiveSkillProAddVal(_type, _heroId, _breakId, _upStarId,teamCurPropertyName)
    local singleHeroProVal, lvProVal, allHeroProVal, specialProVal
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData then
        local star = curHeroData.star
        local allOpenPassiveSkillIds = {}
        if _type == 1 then
            allOpenPassiveSkillIds =
                this.GetAllPassiveSkillIds(curHeroData.heroConfig, curHeroData.breakId, curHeroData.upStarId,star,curHeroData)
        else
            allOpenPassiveSkillIds = this.GetAllPassiveSkillIds(curHeroData.heroConfig, _breakId, _upStarId,star,curHeroData)
        end
        --单体加成  --单体等级限制加成  --团体加成  --减乘
        singleHeroProVal, lvProVal, allHeroProVal, specialProVal =
            this.CalculatePassiveSkillsValList(WarPowerType.Hero, allOpenPassiveSkillIds,teamCurPropertyName,curHeroData)
        end
    return singleHeroProVal, lvProVal, allHeroProVal, specialProVal
end

--计算其他属性值   （角色基础属性+角色升级属性）* 星级系数+升星变量+进阶总属性
--proValue 初始属性  rebirth=0  化境增长 lvNum 对应属性等级  breakNum 突破系数

-- 原始属性 + 等级x属性提升x品级乘修x星级乘修 + 品级加修 + 星级加修 = 基础属性
-- 基础属性*被动乘修+被动加修=技能修正属性
-- (技能修正属性+联盟活跃+神兵基础)*联盟科技=面板属性
function this.CalculateProVal(proValue, lvNum, breakId, upStarId, proId, heroConFigData,star)
    local upRate = heroConFigData[HeroLvUpRate[proId]]
    local breakBase = 0
    local starBase = 0
    local breakRate = 10000
    local starRate = 10000
    if heroRankUpConfig[breakId] and HeroBreakStarUpBaseValue[proId] and HeroBreakStarUpRate[proId]  then
        local breakLv = heroRankUpConfig[breakId].Phase[2]
        -- if breakLv > 6 then
        --     breakLv = breakLv-7
        -- end
         local heroRankConfigData = ConfigManager.GetConfigDataByKey(ConfigName.HeroRankConfig, "Rank", breakLv)
         breakBase = heroRankConfigData[HeroBreakStarUpBaseValue[proId]]
         breakRate = heroRankConfigData[HeroBreakStarUpRate[proId]]
    end
   
    if heroRankUpConfig[upStarId] and HeroBreakStarUpBaseValue[proId] and HeroBreakStarUpRate[proId]  then
        local upStarLv = heroRankUpConfig[upStarId].Phase[2]
        starBase = HeroStarConfig[upStarLv][HeroBreakStarUpBaseValue[proId]]
        starRate = HeroStarConfig[upStarLv][HeroBreakStarUpRate[proId]]
    end

    --新加代码
    if star == 5 then
        starBase = HeroStarConfig[5][HeroBreakStarUpBaseValue[proId]]
    end

    return math.floor(proValue + lvNum * upRate / 10000 * breakRate / 10000 * starRate / 10000 + breakBase + starBase)
end

--计算其他属性值   角色面板属性*（1+升星增加值/10000)*等级系数+角色面板属性*突破系数/10000
--proValue 初始属性  rebirth=0  化境增长 lvNum 等级系数  breakNum 突破系数
--local function CalculateProVal2(proValue, lvNum, breakId,upStarId)
--    local breakRankupPara = 0
--    local upStarRankupPara = 0
--    if heroRankUpConfig[breakId] then
--        breakRankupPara = heroRankUpConfig[breakId].RankupPara
--    end
--    if heroRankUpConfig[upStarId] then
--        upStarRankupPara = heroRankUpConfig[upStarId].RankupPara
--    end
--    return math.floor(proValue * (1 + upStarRankupPara/10000) * lvNum+proValue*breakRankupPara/10000)
--end

--计算speed属性值  0#0#10#1  abcd公式 x=breakId  刚才公式算出的数据  + 速度升级参数 *  speed基础属性
--proValue速度基础属性   lv等级
local function CalculateSpeedProVal(proValue, breakId, speedNum)
    --local SpeedFormulaData = ConfigManager.GetConfig(ConfigName.GameSetting)
    --local curSpeedFormulaData = SpeedFormulaData[1].SpeedFormula
    --breakId = breakId % 100
    --local val = math.floor(((curSpeedFormulaData[1] * math.pow(breakId, 3) + curSpeedFormulaData[2] * math.pow(breakId, 2) + curSpeedFormulaData[3] * breakId + curSpeedFormulaData[4]) + proValue * speedNum))
    return 0
    --val
end

--计算其他属性值    初始属性*（1+化境增长）*等级系数 + 初始属性*突破系数
--proValue 初始属性  rebirth 化境增长 lvNum 等级系数  breakNum 突破系数
function this.CalculateProValMap(_heroDid, _proType)

    --proValue,rebirth,lvNum,breakId
    local curheroData = {}
    if heroDatas[_heroDid] then
        curheroData = heroDatas[_heroDid]
    end
    --local speedNum=heroLevelConfig[curheroData.lv].SpeedLevelPara
    local allEquipAddProVal = {}
    allEquipAddProVal = CalculateHeroUpEquipsProAddVal(curheroData.dynamicId)
    local allPokemonPeiJianAddPro =
        DiffMonsterManager.CalculateAllPokemonPeiJiAllProAddVal(curheroData.heroConfig.Profession)
    --添加所有异妖配件的属性
    for k, v in pairs(allPokemonPeiJianAddPro) do
        if allEquipAddProVal[k] then
            allEquipAddProVal[k] = allEquipAddProVal[k] + v
        end
    end
    local proValue = 0
    if _proType == HeroProType.Attack then
        proValue = curheroData.attack
    elseif _proType == HeroProType.Hp then
        proValue = curheroData.hp
    elseif _proType == HeroProType.PhysicalDefence then
        proValue = curheroData.pDef
    -- elseif _proType == HeroProType.MagicDefence then
        -- proValue = curheroData.mDef
    elseif _proType == HeroProType.Speed then
        proValue = curheroData.speed
    end
    if _proType == HeroProType.Speed then
        --return CalculateSpeedProVal(proValue,curheroData.breakId,speedNum)+allEquipAddProVal[_proType]
    else
        return this.CalculateProVal(proValue, curheroData.lv, curheroData.breakId, curheroData.upStarId, _proType, curheroData.heroConfig,curheroData.star) +
            allEquipAddProVal[_proType]
    end
end

--计算战斗力
local function CalculateWarForce(powerVal)
    -- LogError("------------------------------------------------------")
    local powerEndVal = 0
    for i, v in pairs(powerVal) do
        if v > 0 then
            powerEndVal = powerEndVal + v * HeroManager.heroPropertyScore[i]
            -- LogError(i.."   "..propertyConfig[i].Name..":"..v.."x"..HeroManager.heroPropertyScore[i].."="..v * HeroManager.heroPropertyScore[i])
        end
    end
    return math.floor(powerEndVal)
end
--计算战斗力
local function CalculateSingleModuleWarForce(powerVal)
    local powerEndVal = 0
    for i, v in pairs(powerVal) do
        if v > 0 then
            local curProConfig = propertyConfig[i]
            if curProConfig and curProConfig.TargetPropertyId > 0 then
                powerVal[curProConfig.TargetPropertyId] =
                    math.floor(
                    powerVal[curProConfig.TargetPropertyId] +
                        powerVal[curProConfig.TargetPropertyId] * powerVal[i] / 10000
                )
            end
            if curProConfig and curProConfig.Style == 2 then
                powerVal[i] = powerVal[i] / 10000
            end
        end
    end
    for i, v in pairs(powerVal) do
        if v > 0 then
            powerEndVal = powerEndVal + v * HeroManager.heroPropertyScore[i]
        end
    end
    return math.floor(powerEndVal)
end

---PassiveSkillLogicConfig 表里EffectiveRange 2 3 为战前生效直接加成属性   2 为个体 3 为团体
---PassiveSkillLogicConfig 表里Type 90 个体加成   94 全体加成  171 对多少级英雄加成    加成公式1加算 2乘算 3减算 4乘减算
---90 例子 5#0.05#2  第一位对应PropertyConfig表PropertyIdInBattle 第二位 加成具体数值是百分百或者绝对值看PropertyConfig表 第三位 公式
---94 例子 0.05#17#2  百分比  PropertyConfig表PropertyIdInBattle属性  公式
---171  例子 3#9 100后每增加一级加  PropertyConfig表PropertyIdInBattle属性3   9值
---129  例子 3#0.1#5#1  第一位英雄元素  第二位 加成具体数值是百分百或者绝对值看PropertyConfig表 第三位对应PropertyConfig表PropertyIdInBattle 第四位 公式
---前端计算逻辑  先把所有被动技团体加成 和 被动技个人加成都提出来  然后计算英雄身上所有绝对值 + 所有被动技团体绝对值 + 所有被动技个人加成绝对值
--- * （1 + 英雄身上万分比加成 + 普通团体被动技百分比 + 普通个人被动技百分比 +  个体等级百分比加成 ） * （1 - 4乘减算 百分比）
---
function this.CalculatePassiveSkillsValList(index, skillids,teamCurPropertyName,curHeroData)
    -- for k,v in pairs(this.allProVal)do
    --1,2,3,4
    -- end
    for k, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.PropertyConfig)) do
        this.allProVal[index].singleHeroProVal[k] = 0
        this.allProVal[index].lvProVal[k] = 0
        this.allProVal[index].allHeroProVal[k] = 0
        this.allProVal[index].specialProVal[k] = 0
    end
    for i = 1, #skillids do
        local skillid = skillids[i]
        --LogError("skillid"..tostring(skillid))
        --新修改
        if passiveSkillLogicConfig[skillid] then
            local curSkillData = passiveSkillLogicConfig[skillid]
            --LogError("curSkillData"..skillid)
            --> 改为数组
            for j = 1, #curSkillData.Type do                
                if curSkillData.EffectiveRange[j] == 2 then --战前个人
                    --LogError("curSkillData.Type "..curSkillData.Type[j])
                    if curSkillData.Type[j] == 90 then
                        this.GetProAndValByFormula(
                            this.allProVal[index].singleHeroProVal,
                            this.allProVal[index].specialProVal,
                            curSkillData.Value[j][1],
                            curSkillData.Value[j][2],
                            curSkillData.Value[j][3],
                            curHeroData
                        )
                    elseif curSkillData.Type[j] == 94 then
                        this.GetProAndValByFormula(
                            this.allProVal[index].singleHeroProVal,
                            this.allProVal[index].specialProVal,
                            curSkillData.Value[j][2],
                            curSkillData.Value[j][1],
                            curSkillData.Value[j][3]
                        )
                    -- elseif curSkillData.Type[j] == 171 then
                    --     this.GetProAndValByFormula(
                    --         this.allProVal[index].lvProVal,
                    --         this.allProVal[index].specialProVal,
                    --         curSkillData.Value[j][1],
                    --         curSkillData.Value[j][2]
                    --     )
                    end
                elseif curSkillData.EffectiveRange[j] == 3 then --战前团体
                    if curSkillData.Type[j] == 90 then
                        this.GetProAndValByFormula(
                            this.allProVal[index].allHeroProVal,
                            this.allProVal[index].specialProVal,
                            curSkillData.Value[j][1],
                            curSkillData.Value[j][2],
                            curSkillData.Value[j][3]
                        )
                    elseif curSkillData.Type[j] == 94 then
                        this.GetProAndValByFormula(
                            this.allProVal[index].allHeroProVal,
                            this.allProVal[index].specialProVal,
                            curSkillData.Value[j][2],
                            curSkillData.Value[j][1],
                            curSkillData.Value[j][3]
                        )
                    -- elseif curSkillData.Type[j]== 129 then
                    --     if teamCurPropertyName and teamCurPropertyName == curSkillData.Value[j][1] then
                    
                    --         this.GetProAndValByFormula(
                    --             this.allProVal[index].allHeroProVal,
                    --             this.allProVal[index].specialProVal,
                    --             curSkillData.Value[j][3],
                    --             curSkillData.Value[j][2],
                    --             curSkillData.Value[j][4],
                    --             curSkillData.Value[j][1]
                    --         )
                    --     elseif not teamCurPropertyName then
                    
                    --         this.GetProAndValByFormula(
                    --             this.allProVal[index].allHeroProVal,
                    --             this.allProVal[index].specialProVal,
                    --             curSkillData.Value[j][3],
                    --             curSkillData.Value[j][2],
                    --             curSkillData.Value[j][4],
                    --             curSkillData.Value[j][1]
                    --         )
                    --     end
                    --elseif curSkillData.Type[j] == 171 then
                    --目前没有
                    --this.GetProAndValByFormula(lvProVal,curSkillData,specialProVal)
                    end
                end
            end
        else

        end
    end
    return this.allProVal[index].singleHeroProVal, this.allProVal[index].lvProVal, this.allProVal[index].allHeroProVal, this.allProVal[
        index
    ].specialProVal
end
function this.GetProAndValByFormula(proTable, specialProVal, curProId, curProVal, curProlGs,heroPro)
    
    --LogError(" curProVal:"..curProVal.." curProId:"..curProId.." curProlGs:"..curProlGs)
    if curProlGs == 1 then --公式  （绝对值加a+b）
        local curProConfig = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyIdInBattle", curProId)
        if propertyConfig[curProConfig.PropertyId].Style == 1 then
            if proTable[curProConfig.PropertyId] then
                proTable[curProConfig.PropertyId] = proTable[curProConfig.PropertyId] + curProVal
            else
                proTable[curProConfig.PropertyId] = curProVal
            end
        else
            if proTable[curProConfig.PropertyId] then
                proTable[curProConfig.PropertyId] = proTable[curProConfig.PropertyId] + curProVal * 10000
            else
                proTable[curProConfig.PropertyId] = curProVal * 10000
            end
        end
        --LogError("value:"..proTable[curProConfig.PropertyId])
    elseif curProlGs == 2 then --公式  （百分比加a+oa*b）
        local curProConfig1 =
            ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyIdInBattle", curProId)
        local curProConfig2 =
            ConfigManager.TryGetConfigDataByKey(ConfigName.PropertyConfig, "TargetPropertyId", curProConfig1.PropertyId)
        if curProConfig2 then
            if proTable[curProConfig2.PropertyId] then
                proTable[curProConfig2.PropertyId] = proTable[curProConfig2.PropertyId] + curProVal * 10000
            else
                proTable[curProConfig2.PropertyId] = curProVal * 10000
            end
            --LogError("value1:"..proTable[curProConfig2.PropertyId])
        else
            if proTable[curProConfig1.PropertyId] then
                proTable[curProConfig1.PropertyId] = proTable[curProConfig1.PropertyId] + curProVal * 10000                
            else
                proTable[curProConfig1.PropertyId] = curProVal * 10000               
            end
            -- LogError("curProlGs 3:"..proTable[curProConfig1.PropertyId])
        end
    elseif curProlGs == 3 then --公式  （绝对值减a-b）
        local curProConfig = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyIdInBattle", curProId)
        if propertyConfig[curProConfig.PropertyId].Style == 1 then
            if proTable[curProConfig.PropertyId] then
                proTable[curProConfig.PropertyId] = proTable[curProConfig.PropertyId] - curProVal               
            else
                proTable[curProConfig.PropertyId] = curProVal
            end
        else
            if proTable[curProConfig.PropertyId] then
                proTable[curProConfig.PropertyId] = proTable[curProConfig.PropertyId] - curProVal * 10000
                -- LogError("delet 1:"..proTable[curProConfig.PropertyId])
            else
                proTable[curProConfig.PropertyId] = curProVal * 10000
                -- LogError("delet 2:"..proTable[curProConfig.PropertyId])
            end
        end
        -- LogError("curProlGs 3:"..proTable[curProConfig.PropertyId].." id:"..curProConfig.PropertyId)
    elseif curProlGs == 4 then --公式  （百分比减a*(1-b)）
        --目前没有
        local curProConfig1 =
            ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyIdInBattle", curProId)
        local curProConfig2 =
            ConfigManager.TryGetConfigDataByKey(ConfigName.PropertyConfig, "TargetPropertyId", curProConfig1.PropertyId)
        if curProConfig2 then
            if proTable[curProConfig2.PropertyId] then
                proTable[curProConfig2.PropertyId] = proTable[curProConfig2.PropertyId] - curProVal * 10000
            else
                proTable[curProConfig2.PropertyId] = curProVal * 10000
            end
        else
            if proTable[curProConfig1.PropertyId] then
                proTable[curProConfig1.PropertyId] = proTable[curProConfig1.PropertyId] - curProVal * 10000
            else
                proTable[curProConfig1.PropertyId] = curProVal * 10000
            end
        end
    else --171 无公式
        local curProConfig = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyIdInBattle", curProId)
        if propertyConfig[curProConfig.PropertyId].Style == 1 then
            if proTable[curProConfig.PropertyId] then
                proTable[curProConfig.PropertyId] = proTable[curProConfig.PropertyId] + curProVal
            else
                proTable[curProConfig.PropertyId] = curProVal
            end
        else
            if proTable[curProConfig.PropertyId] then
                proTable[curProConfig.PropertyId] = proTable[curProConfig.PropertyId] + curProVal * 10000
            else
                proTable[curProConfig.PropertyId] = curProVal * 10000
            end
        end
        --LogError("value:"..proTable[curProConfig.PropertyId])
    end
end
--团队加成
function this.GetAllHeroTeamAddProVal(teamHeroInfos,curteamHeroDid)
    local teamProVal = {}
    --英雄 法宝 魂印 被动技能
    --> 被动 能力 戒指
    for i = 1, 5 do
        if teamHeroInfos[i] then
            local heroSkillSingleHeroProVal, heroSkillLvProVal, heroSkillAllHeroProVal, heroSkillSpecialProVal =
                CalculateHeroPassiveSkillProAddVal(1, 
                teamHeroInfos[i].heroId,
                nil,
                nil,
                curteamHeroDid and
                HeroManager.GetSingleHeroData(curteamHeroDid).heroConfig.PropertyName or nil)
            -- local falismanSingleHeroProVal, falismanLvProVal, falismanAllHeroProVal, falismanSpecialProVal =
                -- CalculateHeroUpTalismanProAddVal(teamHeroInfos[i].heroId,nil,nil, curteamHeroDid and  HeroManager.GetSingleHeroData(curteamHeroDid).heroConfig.PropertyName or nil)
            -- local soulPrinSingleHeroProVal,soulPrinLvProVal,soulPrinAllHeroProVal,soulPrinSpecialProVal = CalculateSoulPrintAddVal(teamHeroInfos[i].heroId)
            -- local singleHeroProValWarWay, lvProValWarWay, allHeroProValWarWay, specialProValWarWay = CalculateWarWayAddVal(teamHeroInfos[i].heroId)
            -- local singleHeroProValCombatPlan, lvProValCombatPlan, allHeroProValCombatPlan, specialProValCombatPlan = CalculateCombatPlanAddVal(teamHeroInfos[i].heroId)

            local _, _, allHeroProValCombatPlanAndWarWay, _ = CalculateCombatPlanAndWarWayAddVal(teamHeroInfos[i].heroId)

            -- local medalSuitAddPro , lvProValMedalSuit, allHeroProValMedalSuit, specialProValMedalSuit = CalculateMedalSuitAddVal(teamHeroInfos[i].heroId)
            local singleHeroProValTalent, lvProValTalent, allHeroProValTalent, specialProValTalent = CalculateTalentAddVal(teamHeroInfos[i].heroId)
            this.DoubleTableCompound(teamProVal, heroSkillAllHeroProVal)
            -- this.DoubleTableCompound(teamProVal, allHeroProValWarWay)
            -- this.DoubleTableCompound(teamProVal, allHeroProValCombatPlan)
            this.DoubleTableCompound(teamProVal, allHeroProValCombatPlanAndWarWay)
            this.DoubleTableCompound(teamProVal, allHeroProValTalent)
            -- this.DoubleTableCompound(teamProVal, allHeroProValMedalSuit)
            -- this.DoubleTableCompound(teamProVal, falismanAllHeroProVal)
            -- this.DoubleTableCompound(teamProVal,soulPrinAllHeroProVal)
        end
    end
    --光环加成
    local aureoleProAdd = FormationManager.GetCurFormationElementAdd(teamHeroInfos)
    this.DoubleTableCompound(teamProVal, aureoleProAdd)
    return teamProVal
end

--计算英雄身上所有属性加成
--_type==1 计算当前英雄的所有属性  _type==2 根据_heroDid之后_breakId传过来的值进行计算  _isAllHeroProVal==true 团体加成综合  用字段_allHeroProVal
--_isAllHeroProVal 修改 团队属性外传
function this.CalculateHeroAllProValList(_type, _heroDid, isWar, _breakId, _upStarId, _isAllHeroProVal, _allHeroProVal)
    local curHeroData = nil
    -- 如果不是动态id 则为英雄数据
    if type(_heroDid) == "string" then
        curHeroData = this.GetSingleHeroData(_heroDid)
    else
        curHeroData = _heroDid
    end
    if curHeroData == nil then
        if type(_heroDid) == "string" then
            LogRed("有问题英雄：".._heroDid)
        end
        return
    end
    local curLvNum = curHeroData.lv -- heroLevelConfig[curHeroData.lv].CharacterLevelPara
    --local speedNum = heroLevelConfig[curHeroData.lv].SpeedLevelPara

    --英雄装备
    local allEquipScore = PlayerManager.GetSingHeroAllEquipSkillListScore(curHeroData)
    --单体所有属性加成
    local lvProVal = {}
    --100等级所有属性加成 升一级 加一次
    local allHeroProVal = _allHeroProVal or {}
    --团体所有属性加成
    local specialProVal = {}
    --计算所有装备加成的属性值
    local allAddProVal = CalculateHeroUpEquipsProAddVal(curHeroData.dynamicId)
    --公会技能加成
    local guildSkillAllProAdd = GuildSkillManager.HeroCalculateGuildSkillWarForce(curHeroData.heroConfig.Profession)
    --公会活跃
    local guildActiveAddPro = MyGuildManager.GetLivenessAllPro()
    --获取属性值加成
    local generalDate = GeneralManager.getAllData(curHeroData.heroConfig.PropertyName)
    --英雄被动技能属性加成
    local heroSkillSingleHeroProVal, heroSkillLvProVal, _, heroSkillSpecialProVal = {}, {}, {}, {}
    if _type == 1 then
        heroSkillSingleHeroProVal, heroSkillLvProVal, _, heroSkillSpecialProVal = CalculateHeroPassiveSkillProAddVal(_type, curHeroData.dynamicId)
    elseif _type == 2 then
        heroSkillSingleHeroProVal, heroSkillLvProVal, _, heroSkillSpecialProVal = CalculateHeroPassiveSkillProAddVal(_type, curHeroData.dynamicId, _breakId, _upStarId)
    end
    --玩家称号 皮肤 坐骑属性加成
    local playerDcorateAdd = PlayerManager.CalculatePlayerDcorateProAddVal()
    --守护
    local supportAddPro = SupportManager.GetAllPropertyAdd()
    local supportAddProbool  = SupportManager.GetDataById("isactive")
    --先驱
    local adjutantAddPro = AdjutantManager.GetAllPropertyAdd()
    --启明星
    local investigateAddPro = FormationCenterManager.GetAllPropertyAdd()
    --能力和戒指
    local warWayAndCombatPlanAddPro, lvProValCombatPlanAndWarWay, _, specialProValCombatPlanAndWarWay = CalculateCombatPlanAndWarWayAddVal(curHeroData.dynamicId)
    --芯片
    local medalAddPro = CalculateMedalAddVal(curHeroData.dynamicId)
    --芯片套装
    local medalSuitAddPro , lvProValMedalSuit, _, specialProValMedalSuit = CalculateMedalSuitAddVal(curHeroData.dynamicId)

    --法宝的属性加成  falismanProAdd
    -- local falismanSingleHeroProVal, falismanLvProVal, falismanAllHeroProVal, falismanSpecialProVal = {}, {}, {}, {}
    -- if _type == 1 then
    --     falismanSingleHeroProVal, falismanLvProVal, falismanAllHeroProVal, falismanSpecialProVal = CalculateHeroUpTalismanProAddVal(curHeroData.dynamicId)
    -- elseif _type == 2 then
    --     falismanSingleHeroProVal, falismanLvProVal, falismanAllHeroProVal, falismanSpecialProVal = CalculateHeroUpTalismanProAddVal(curHeroData.dynamicId, _breakId, _upStarId)
    -- end
    --魂印的属性加成
    -- local allSoulPrintAddWarPowerVal = CalculateSoulPrintAddVal(curHeroData.dynamicId)
    --宝器加成  宝器本身属性 + 宝器激活的强化共鸣 和 精炼共鸣
    -- local equipTreasureAddPro = CalculateEquipTreaSureAddVal(curHeroData.dynamicId)
    --编队光环加成
    -- local teamAddPro = FormationManager.GetCurFormationElementAddByType(FormationTypeDef.FORMATION_NORMAL, curHeroData.dynamicId)
    --Vip加成
    -- local vipAddPro = VipManager.GetAddPro()
    --异妖配件的加成
    -- local allPokemonPeiJianAddPro = DiffMonsterManager.CalculateAllPokemonPeiJiAllProAddVal(curHeroData.heroConfig.Profession)
    --科技树加成
    -- local treeAllProAdd = WorkShopManager.HeroCalculateTreeWarForce(curHeroData.heroConfig.Profession)
    --图腾
    -- local totemAddPro, lvProValTotem, allHeroProValTotem, specialProValTotem = CalculateTotemAddVal(curHeroData.dynamicId)
    --特性
    -- local singleHeroProValTalent, lvProValTalent, allHeroProValTalent, specialProValTalent = CalculateTalentAddVal(curHeroData.dynamicId)
    
    --单体所有属性合并
    this.DoubleTableCompound(allAddProVal, guildSkillAllProAdd)
    this.DoubleTableCompound(allAddProVal, generalDate)
    this.DoubleTableCompound(allAddProVal, playerDcorateAdd)
    this.DoubleTableCompound(allAddProVal, heroSkillSingleHeroProVal)
    this.DoubleTableCompound(allAddProVal, medalSuitAddPro)
    this.DoubleTableCompound(allAddProVal, medalAddPro)
    this.DoubleTableCompound(allAddProVal, adjutantAddPro)
    this.DoubleTableCompound(allAddProVal, warWayAndCombatPlanAddPro)
    this.DoubleTableCompound(allAddProVal, guildActiveAddPro)
    this.DoubleTableCompound(allAddProVal, investigateAddPro)
    this.DoubleTableCompound(lvProVal, heroSkillLvProVal)
    this.DoubleTableCompound(lvProVal, lvProValCombatPlanAndWarWay)

    this.DoubleTableCompound(lvProVal, lvProValMedalSuit)
    if supportAddProbool then
        this.DoubleTableCompound(allAddProVal, supportAddPro)
    end

    -- this.DoubleTableCompound(allAddProVal, singleHeroProValWarWay)
    -- this.DoubleTableCompound(lvProVal, lvProValWarWay)
    -- this.DoubleTableCompound(lvProVal, lvProValCombatPlan)
    -- this.DoubleTableCompound(allAddProVal, singleHeroProValCombatPlan)
    -- this.DoubleTableCompound(allAddProVal, allPokemonPeiJianAddPro)
    -- this.DoubleTableCompound(allAddProVal, falismanSingleHeroProVal)
    -- this.DoubleTableCompound(allAddProVal,soulPrinSingleHeroProVal)
    -- this.DoubleTableCompound(allAddProVal, equipTreasureAddPro)
    -- this.DoubleTableCompound(allAddProVal, vipAddPro)
    -- this.DoubleTableCompound(allAddProVal, totemAddPro)
    -- this.DoubleTableCompound(allAddProVal, singleHeroProValTalent)
    -- this.DoubleTableCompound(allAddProVal, allSoulPrintAddWarPowerVal)
    -- this.DoubleTableCompound(lvProVal, falismanLvProVal)
    -- this.DoubleTableCompound(lvProVal, soulPrinLvProVal)
    -- this.DoubleTableCompound(lvProVal, lvProValTotem)
    -- this.DoubleTableCompound(lvProVal, lvProValTalent)

    --团体所有属性合并
    --[[
    if not _isAllHeroProVal then
        -- this.DoubleTableCompound(allHeroProVal, falismanAllHeroProVal)
        -- this.DoubleTableCompound(allHeroProVal, soulPrinAllHeroProVal)
        this.DoubleTableCompound(allHeroProVal, heroSkillAllHeroProVal)
        this.DoubleTableCompound(allHeroProVal, teamAddPro)
        this.DoubleTableCompound(allHeroProVal, allHeroProValWarWay)
        this.DoubleTableCompound(allHeroProVal, allHeroProValCombatPlan)
        this.DoubleTableCompound(allHeroProVal, allHeroProValMedalSuit)
    end
    ]]

    --4公式特殊（减乘）所有属性加成
    -- this.DoubleTableCompound(specialProVal, falismanSpecialProVal)
    -- this.DoubleTableCompound(specialProVal,soulPrinSpecialProVal)
    this.DoubleTableCompound(specialProVal, heroSkillSpecialProVal)
    -- this.DoubleTableCompound(specialProVal, specialProValWarWay)
    this.DoubleTableCompound(specialProVal, specialProValCombatPlanAndWarWay)
    -- this.DoubleTableCompound(specialProVal, specialProValCombatPlan)
    this.DoubleTableCompound(specialProVal, specialProValMedalSuit)
    -- this.DoubleTableCompound(specialProVal, specialProValTotem)
    -- this.DoubleTableCompound(specialProVal, specialProValTalent)
    --100等级所有属性合并
    local forNum = curLvNum - 100
    if forNum > 0 then
        for k = 1, forNum do
            this.DoubleTableCompound(allAddProVal, lvProVal)
        end
    end
    --团体所有属性合并
    this.DoubleTableCompound(allAddProVal, allHeroProVal)
    -- 新加测试代码
    -- this.DoubleTableCompound(allAddProVal, specialProVal)
    
    if _type == 1 then
        -- allAddProVal[HeroProType.Speed] =
        --     CalculateSpeedProVal(
        --         curHeroData.speed,
        --         curHeroData.breakId,
        --         speedNum) + allAddProVal[HeroProType.Speed]
        -- allAddProVal[HeroProType.WarPower] =
        --     allEquipScore 
        --     + CalculateWarForce(allAddProVal[HeroProType.Hp],
        --     allAddProVal[HeroProType.PhysicalDefence],
        --     allAddProVal[HeroProType.MagicDefence],
        --     allAddProVal[HeroProType.Attack],
        --     allAddProVal[HeroProType.CritFactor],
        --     allAddProVal[HeroProType.Hit],
        --     allAddProVal[HeroProType.Dodge],
        --     allAddProVal[HeroProType.DamageBocusFactor],
        --     allAddProVal[HeroProType.DamageReduceFactor],
        --     allAddProVal[HeroProType.Speed])
        allAddProVal[HeroProType.Attack] =
            this.CalculateProVal(
            curHeroData.attack,
            curLvNum,
            curHeroData.breakId,
            curHeroData.upStarId,
            HeroProType.Attack,
            curHeroData.heroConfig,curHeroData.star) + allAddProVal[HeroProType.Attack]
        allAddProVal[HeroProType.Hp] =
            this.CalculateProVal(curHeroData.hp,
            curLvNum,
            curHeroData.breakId,
            curHeroData.upStarId,
            HeroProType.Hp,
            curHeroData.heroConfig,
            curHeroData.star) + allAddProVal[HeroProType.Hp]
        allAddProVal[HeroProType.PhysicalDefence] =
            this.CalculateProVal(
            curHeroData.pDef,
            curLvNum,
            curHeroData.breakId,
            curHeroData.upStarId,
            HeroProType.PhysicalDefence,
            curHeroData.heroConfig,curHeroData.star) + allAddProVal[HeroProType.PhysicalDefence]
        allAddProVal[HeroProType.Speed] =
            this.CalculateProVal(
            curHeroData.speed,
            curLvNum,
            curHeroData.breakId,
            curHeroData.upStarId,
            HeroProType.Speed,
            curHeroData.heroConfig,curHeroData.star) + allAddProVal[HeroProType.Speed]
        -- allAddProVal[HeroProType.MagicDefence] =
        --     this.CalculateProVal(
        --         curHeroData.mDef,
        --         curLvNum,
        --         curHeroData.breakId,
        --         curHeroData.upStarId,
        --         HeroProType.MagicDefence,
        --         curHeroData.heroConfig) + allAddProVal[HeroProType.MagicDefence]
    elseif _type == 2 then
        allAddProVal[HeroProType.Attack] =
            this.CalculateProVal(curHeroData.attack,
            curLvNum,
            _breakId,
            _upStarId,
            HeroProType.Attack,
            curHeroData.heroConfig,curHeroData.star) + allAddProVal[HeroProType.Attack]
        allAddProVal[HeroProType.Hp] =
            this.CalculateProVal(curHeroData.hp,
            curLvNum,
            _breakId,
            _upStarId,
            HeroProType.Hp,
            curHeroData.heroConfig,
            curHeroData.star) + allAddProVal[HeroProType.Hp]
        allAddProVal[HeroProType.PhysicalDefence] =
            this.CalculateProVal(curHeroData.pDef,
            curLvNum,
            _breakId,
            _upStarId,
            HeroProType.PhysicalDefence,
            curHeroData.heroConfig,curHeroData.star) + allAddProVal[HeroProType.PhysicalDefence]
        allAddProVal[HeroProType.Speed] =
            this.CalculateProVal(curHeroData.speed,
            curLvNum,
            _breakId,
            _upStarId,
            HeroProType.Speed,
            curHeroData.heroConfig,curHeroData.star) +allAddProVal[HeroProType.Speed]
        -- allAddProVal[HeroProType.MagicDefence] =
        --     this.CalculateProVal(
        --         curHeroData.mDef,
        --         curLvNum,
        --         _breakId,
        --         _upStarId,
        --         HeroProType.MagicDefence,
        --         curHeroData.heroConfig) + allAddProVal[HeroProType.MagicDefence]
        -- allAddProVal[HeroProType.Speed] =
        --     CalculateSpeedProVal(curHeroData.speed,
        --     _breakId,speedNum) + allAddProVal[HeroProType.Speed]
        -- allAddProVal[HeroProType.WarPower] = 
        --     allEquipScore 
        --     + CalculateWarForce(allAddProVal[HeroProType.Hp],
        --     allAddProVal[HeroProType.PhysicalDefence],
        --     allAddProVal[HeroProType.MagicDefence],
        --     allAddProVal[HeroProType.Attack],
        --     allAddProVal[HeroProType.CritFactor],
        --     allAddProVal[HeroProType.Hit],
        --     allAddProVal[HeroProType.Dodge],
        --     allAddProVal[HeroProType.DamageBocusFactor],
        --     allAddProVal[HeroProType.DamageReduceFactor],
        --     allAddProVal[HeroProType.Speed])
    end

    for k, v in pairs(allAddProVal) do
        local curProConfig = propertyConfig[k]
        --标注 二级属性
        if curHeroData.heroConfig.SecondaryFactor and isWar then
            for i = 1, #curHeroData.heroConfig.SecondaryFactor do
                if k == curHeroData.heroConfig.SecondaryFactor[i][1] then
                    allAddProVal[k] = allAddProVal[k] + curHeroData.heroConfig.SecondaryFactor[i][2]
                end
            end
        end
        -- 标注 TargetPropertyId加成
        --计算装备异妖 特殊百分比加成 （在英雄自身、装备、异妖 绝对值属性算完之后  最后计算百分比加成）
        --  and allAddProVal[k] > 0 减易属性 非战斗内
        if curProConfig  and curProConfig.TargetPropertyId > 0 then
            allAddProVal[curProConfig.TargetPropertyId] =
                math.floor(
                allAddProVal[curProConfig.TargetPropertyId] +
                    allAddProVal[curProConfig.TargetPropertyId] * allAddProVal[k] / 10000--修改比例
            )
        end
        --战斗里面        PropertyConfig里Style字段，2类型的统一需要除以100在战斗里面
        if curProConfig and allAddProVal[k] > 0 and isWar and curProConfig.Style == 2 then
            allAddProVal[k] = allAddProVal[k] / 10000
        elseif curProConfig and allAddProVal[k] > 0 and isWar == false and curProConfig.Style == 2 then
            allAddProVal[k] = allAddProVal[k] / 100
        end
        --战斗里面        PropertyConfig里面 IfFormula==1，策划投放的是属性绝对值，转化为战斗里面的是属性系数，转化公式为： 属性系数=属性绝对值*0.1/（等级+10）/100
        if curProConfig and allAddProVal[k] > 0 and isWar and curProConfig.IfFormula == 1 then
            allAddProVal[k] = math.floor(allAddProVal[k] * 0.1 / (curHeroData.lv + 10) / 10000)
        elseif curProConfig and allAddProVal[k] > 0 and isWar == false and curProConfig.IfFormula == 1 then
            -- allAddProVal[k] = math.floor(allAddProVal[k]*0.1/(curHeroData.lv+10)/100)
        end
    end
    
    --目前没有 王振兴加   最后计算个属性的乘减算
    -- if curHeroData.MLSproList and LengthOfTable(curHeroData.MLSproList)>0 then
    --     for k, v in pairs(curHeroData.MLSproList) do
    --         local mlsPro = curHeroData.MLSproList[k] 
    --         if allAddProVal[mlsPro.proId]  then
    --             -- local aaa = 1-mlsPro.value
    --             LogError("has MLSproList !!!!!!!!!!!!!!")
    --         local value = math.floor(allAddProVal[mlsPro.proId] * (1-mlsPro.value))
    --         allAddProVal[mlsPro.proId] = value
    --         end
    --     end
    -- end    
    -- curHeroData.MLSproList = {}
    
    --最后计算英雄战斗力
    if _type == 1 then
        allAddProVal[HeroProType.WarPower] = 
        allEquipScore + 
        CalculateWarForce(allAddProVal) + 
        ConfigManager.GetConfigData(ConfigName.SpecialConfig, 125).Value
        -- + allSoulPrintAddWarPowerVal
    elseif _type == 2 then
        allAddProVal[HeroProType.WarPower] = 
        allEquipScore + 
        CalculateWarForce(allAddProVal) + 
        ConfigManager.GetConfigData(ConfigName.SpecialConfig, 125).Value
        -- + allSoulPrintAddWarPowerVal
    end
    return allAddProVal
end

function this.DoubleTableCompound(allProVal, addProVal)
    if addProVal and LengthOfTable(addProVal) > 0 then
        for k, v in pairs(addProVal) do
            -- if v > 0 then -- 负数属性也可加入 加入减益计算
                if allProVal[k] then
                    allProVal[k] = allProVal[k] + v
                else
                    allProVal[k] = v
                end
            -- end
        end
    end
end

--计算英雄身上单个模块战斗力
--1  装备  2 异妖 3 戒灵 4 天赋树 5 魂印 6 法宝 7 英雄自身
function this.CalculateSingleModuleProPower(_type, _heroDid)
    local curHeroData = heroDatas[_heroDid]
    local curLvNum = curHeroData.lv
    -- heroLevelConfig[curHeroData.lv].CharacterLevelPara
    -- local speedNum = heroLevelConfig[curHeroData.lv].SpeedLevelPara
    if _type == 1 then
        local allEquipScore = PlayerManager.GetSingHeroAllEquipSkillListScore(curHeroData)
        --获取单个英雄装备被动技能累计评分
        local allAddEquipProVal = CalculateHeroUpEquipsProAddVal(curHeroData.dynamicId)
        --添加该英雄装备的属性
        return allEquipScore + CalculateSingleModuleWarForce(allAddEquipProVal)
    elseif _type == 2 then
        --elseif _type ==  3 then
        --    local allTalentProVal=TalentManager.GetAllTypeTalentProVal()--添加所有戒灵的属性
        --    return CalculateSingleModuleWarForce( allTalentProVal)
        local allPokemonPeiJianAddPro =
            DiffMonsterManager.CalculateAllPokemonPeiJiAllProAddVal(curHeroData.heroConfig.Profession)
        --添加所有异妖配件的属性
        return CalculateSingleModuleWarForce(allPokemonPeiJianAddPro)
    elseif _type == 4 then
        local treeAllProAdd = WorkShopManager.HeroCalculateTreeWarForce(curHeroData.heroConfig.Profession)
        --计算所有科技树属性
        return CalculateSingleModuleWarForce(treeAllProAdd)
    elseif _type == 5 then
        return 0
    elseif _type == 6 then
        return 0
    elseif _type == 7 then
        local allAddProVal = {}
        allAddProVal[HeroProType.Attack] =
            this.CalculateProVal(
                curHeroData.attack,
                curLvNum,
                curHeroData.breakId,
                curHeroData.upStarId,
                HeroProType.Attack,
                curHeroData.heroConfig,curHeroData.star)
        allAddProVal[HeroProType.Hp] =
            this.CalculateProVal(
                curHeroData.hp,
                curLvNum,
                curHeroData.breakId,
                curHeroData.upStarId,
                HeroProType.Hp,
                curHeroData.heroConfig,
                curHeroData.star)
        allAddProVal[HeroProType.PhysicalDefence] =
            this.CalculateProVal(
                curHeroData.pDef,
                curLvNum,
                curHeroData.breakId,
                curHeroData.upStarId,
                HeroProType.PhysicalDefence,
                curHeroData.heroConfig,curHeroData.star)
        -- allAddProVal[HeroProType.MagicDefence] =
        --     this.CalculateProVal(
        --      curHeroData.mDef,
        --      curLvNum,
        --      curHeroData.breakId,
        --      curHeroData.upStarId,
        --      HeroProType.MagicDefence,
        --      curHeroData.heroConfig)
        -- allAddProVal[HeroProType.Speed] = 
        --     CalculateSpeedProVal(
        --         curHeroData.speed,
        --         curHeroData.breakId,
        --         speedNum)
        --if curHeroData.heroConfig.SecondaryFactor then
        --    for i = 1, #curHeroData.heroConfig.SecondaryFactor do
        --        if allAddProVal[curHeroData.heroConfig.SecondaryFactor[i][1]] then
        --            allAddProVal[curHeroData.heroConfig.SecondaryFactor[i][1]] = allAddProVal[curHeroData.heroConfig.SecondaryFactor[i][1]] + curHeroData.heroConfig.SecondaryFactor[i][2]
        --        else
        --            allAddProVal[curHeroData.heroConfig.SecondaryFactor[i][1]] = curHeroData.heroConfig.SecondaryFactor[i][2]
        --        end
        --    end
        --end
        return CalculateSingleModuleWarForce(allAddProVal)
    end
    return 0
end

--计算英雄战斗属性
--目前一次顺序  >等级>生命>最大生命>攻击力>护甲>魔抗>速度>伤害加成系数（%）>伤害减免系数（%）>命中率（%）>闪避率（%）>暴击率（%）>暴击伤害系数（%）>治疗加成系数（%）
--              >火系伤害加成系数（%）>火系伤害减免系数（%）>冰系伤害加成系数（%）>冰系伤害减免系数（%）>雷系伤害加成系数（%）>雷系伤害减免系数（%）>风系伤害加成系数（%）
--              >风系伤害减免系数（%）>地系伤害加成系数（%）>地系伤害减免系数（%）>暗系伤害加成系数（%）>暗系伤害减免系数（%）
function this.CalculateWarAllProVal(heroDid)
    local allEquipAddProVal = HeroManager.CalculateHeroAllProValList(1, heroDid, true)
    local allProVal = {}
    table.insert(allProVal, 1, HeroManager.GetSingleHeroData(heroDid).lv)
    --等级
    table.insert(allProVal, 2, allEquipAddProVal[HeroProType.Hp])
    --生命
    table.insert(allProVal, 3, allEquipAddProVal[HeroProType.Hp])
    --最大生命
    table.insert(allProVal, 4, allEquipAddProVal[HeroProType.Attack])
    --攻击力
    table.insert(allProVal, 5, allEquipAddProVal[HeroProType.PhysicalDefence])
    --护甲
    table.insert(allProVal, 6, allEquipAddProVal[HeroProType.MagicDefence])
    --魔抗
    table.insert(allProVal, 7, allEquipAddProVal[HeroProType.Speed])
    --速度
    table.insert(allProVal, 8, allEquipAddProVal[HeroProType.DamageBocusFactor])
    --伤害加成系数（%）
    table.insert(allProVal, 9, allEquipAddProVal[HeroProType.DamageReduceFactor])
    --伤害减免系数（%）
    table.insert(allProVal, 10, allEquipAddProVal[HeroProType.Hit])
    --命中率（%）
    table.insert(allProVal, 11, allEquipAddProVal[HeroProType.Dodge])
    --闪避率（%）
    table.insert(allProVal, 12, allEquipAddProVal[HeroProType.CritFactor])
    --暴击率（%）
    table.insert(allProVal, 13, allEquipAddProVal[HeroProType.CritDamageFactor])
    --暴击伤害系数（%）
    table.insert(allProVal, 14, allEquipAddProVal[HeroProType.AntiCritDamageFactor])
    --抗暴率（%）
    table.insert(allProVal, 15, allEquipAddProVal[HeroProType.TreatFacter])
    --治疗加成系数（%）
    table.insert(allProVal, 16, allEquipAddProVal[HeroProType.CureFacter])
    --受到治疗系数（%）
    table.insert(allProVal, 17, allEquipAddProVal[HeroProType.DifferDemonsBocusFactor])
    --异妖伤害加成系数（%）
    table.insert(allProVal, 18, allEquipAddProVal[HeroProType.DifferDemonsReduceFactor])
    --异妖减伤率（%）
    table.insert(allProVal, 19, allEquipAddProVal[HeroProType.FireDamageReduceFactor])
    --火系伤害减免系数（%）
    table.insert(allProVal, 20, allEquipAddProVal[HeroProType.WindDamageReduceFactor])
    --风系伤害减免系数（%）
    table.insert(allProVal, 21, allEquipAddProVal[HeroProType.WaterDamageReduceFactor])
    --冰系伤害减免系数（%）
    table.insert(allProVal, 22, allEquipAddProVal[HeroProType.LandDamageReduceFactor])
    --地系伤害减免系数（%）
    table.insert(allProVal, 23, allEquipAddProVal[HeroProType.LightDamageReduceFactor])
    --光系伤害减免系数（%）
    table.insert(allProVal, 24, allEquipAddProVal[HeroProType.DarkDamageReduceFactor])
    --暗系伤害减免系数（%）
    table.insert(allProVal, 25, 0)
    --属性伤害加成系数（%）
    return allProVal
end

--地图临时背包数据
this.mapShotTimeItemData = {}
--地图临时英雄数据存储
function this.InitMapShotTimeHeroBagData(_mapHero)
    this.mapShotTimeItemData[#this.mapShotTimeItemData + 1] = _mapHero
end
--通过职业筛选英雄
function this.GetHeroDataByProfession(_profession)
    local heros = {}
    local index = 1
    for i, v in pairs(heroDatas) do
        if v.profession == _profession or _profession == 0 then --0 全职业
            heros[index] = v
            index = index + 1
        end
    end
    return heros
end

--通过属性，等级筛选英雄
function this.GetHeroDataByProperty(_property, _lvLimit)
    local heros = {}
    local lvLimit = 0
    local allUpZhenHeroList = FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_ENDLESS_MAP)
    if _lvLimit then
        lvLimit = _lvLimit
    end
    local index = 1
    for i, v in pairs(heroDatas) do
        if v.property == _property and v.heroConfig.Material ~= 1 then
            if v.lv >= lvLimit or allUpZhenHeroList[v.dynamicId] then
                heros[index] = v
                index = index + 1
            end
        end
    end
    return heros
end

--通过品阶筛选英雄
function this.GetHeroDataByNatural(_natural)
    local heros = {}
    for _, heroInfo in pairs(heroDatas) do
        if heroInfo.heroConfig.Natural == _natural then
            table.insert(heros, heroInfo)
        end
    end
    return heros
end
--检测单个英雄是否有可穿的法宝
function this.GetHeroIsUpTalisman(heroDid)
    if heroDatas[heroDid] then
        local heroData = heroDatas[heroDid]
        local isOpenTalisman = TalismanManager.GetCurHeroIsOpenTalisman(heroData.star)
        if isOpenTalisman == false then --法宝是否开启
            return {}
        end
        local curTalismanData
        if heroData.talismanList and #heroData.talismanList > 0 then
            curTalismanData = TalismanManager.GetSingleTalismanData(heroData.talismanList[1])
        end
        local GetAllTalismanData = TalismanManager.GetAllTalismanData(false, "0")
        table.sort(
            GetAllTalismanData,
            function(a, b)
                return a.power > b.power
            end
        )
        if curTalismanData then
            if GetAllTalismanData and #GetAllTalismanData > 0 then
                for i = 1, #GetAllTalismanData do
                    if GetAllTalismanData[i].power > curTalismanData.power then
                        return {GetAllTalismanData[i]}
                    end
                end
            end
            return {}
        else
            if GetAllTalismanData and #GetAllTalismanData > 0 then
                return {GetAllTalismanData[1]}
            else
                return {}
            end
        end
    end
    return {}
end
--获取妖灵师技能最大等级
function this.GetHeroSkillMaxLevel(heroTId, skillPos)
    local curHeroData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroTId)
    local maxSkillLv
    -- if type == 1 then
    --     if #curHeroData.OpenSkillRules - 1 == 0 then
    --         maxSkillLv = curHeroData.OpenSkillRules[1][2] % 10
    --     else
    --         maxSkillLv = curHeroData.OpenSkillRules[#curHeroData.OpenSkillRules][2] % 10
    --     end
    -- elseif type == 2 then
    --     maxSkillLv = curHeroData.OpenSkillRules[#curHeroData.OpenSkillRules][2] % 10
    -- elseif type == 3 then
    --     maxSkillLv = curHeroData.OpenPassiveSkillRules[#curHeroData.OpenPassiveSkillRules][2] % 10
    -- end
    -- return maxSkillLv
    local unLockSkills = ConfigManager.GetAllConfigsDataByKey(ConfigName.UnlockSkill,"SkillPos",skillPos)
    table.sort(unLockSkills,function (a,b)
        return a.Star > b.Star
    end)
    local maxStar = curHeroData.MaxRank
    local maxRankUpConfig = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.HeroRankupConfig,"Star",curHeroData.Star,"JudgeClass",1,"Type",1)
    local maxRank
    if maxRankUpConfig then
        maxRank = maxRankUpConfig.Phase[2]
    end
    for index, value in ipairs(unLockSkills) do
        if maxStar >= value.Star then
            if maxRank >= value.Rank then
                maxSkillLv = value.UnlockLV
                break
            end
        end
    end
    return maxSkillLv
end

--获取所有英雄信息(回溯功能)
function this.GetReturnHeroDatas(_star)
    local heros = {}
    local heros2 = {}
    for i, v in pairs(heroDatas) do
        v.isFormation = ""
        table.insert(heros, v)
    end
    --标记编队上的英雄
    if heros and LengthOfTable(heros) > 0 then
        for i, v in pairs(heros) do
            for n, w in pairs(FormationManager.formationList) do
                for m = 1, #w.teamHeroInfos do
                    if v.dynamicId == w.teamHeroInfos[m].heroId then
                        local isFormationStr = this.GetHeroFormationStr(n)
                        heros[i].isFormation = isFormationStr
                    end
                end
            end
            if v.star >= _star then
                table.insert(heros2, v)
            end
        end
    end
    return heros2
end
function this.GetCurHeroSidAndCurStarAllSkillDatas(sid, star)
    local allSkillDatas = {}
    local skillIndex = 1
    local curHeroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, sid)
    if curHeroConfig.OpenSkillRules then
        for i = 1, #curHeroConfig.OpenSkillRules do
            if curHeroConfig.OpenSkillRules[i][1] == star then
                local heroSkill = {}
                heroSkill.skillId = curHeroConfig.OpenSkillRules[i][2]
                heroSkill.skillConfig = skillConfig[heroSkill.skillId]
                allSkillDatas[skillIndex] = heroSkill
                skillIndex = skillIndex + 1
            end
        end
    end
    if curHeroConfig.OpenPassiveSkillRules then
        for i = 1, #curHeroConfig.OpenPassiveSkillRules do
            if curHeroConfig.OpenPassiveSkillRules[i][1] == star then
                local heroSkill = {}
                heroSkill.skillId = curHeroConfig.OpenPassiveSkillRules[i][2]
                heroSkill.skillConfig = passiveSkillConfig[heroSkill.skillId]
                allSkillDatas[skillIndex] = heroSkill
                skillIndex = skillIndex + 1
            end
        end
    end
    return allSkillDatas
end
function this.GetCurHeroSidAndCurStarAllSkillDatas2(sid, star)
    local allSkillDatas = {}
    local skillIndex = 1
    local curHeroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, sid)
    isHeroUpStar = false
    local upStarRankUpConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroRankupConfig, "Star", curHeroConfig.Star, "LimitStar", star)
    if curHeroConfig.OpenSkillRules then
        for i = 1, #curHeroConfig.OpenSkillRules do
            if curHeroConfig.OpenSkillRules[i][1] <= star then
                local heroSkill = {}
                heroSkill.skillId = curHeroConfig.OpenSkillRules[i][2]
                local skilllogicconfig = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.SkillLogicConfig, "Group", heroSkill.skillId, "Level", this.GetSkillUnlockLv(curHeroConfig.OpenSkillRules[i][1], star, upStarRankUpConfig.Phase[2]))
                if skilllogicconfig ~= nil then
                    heroSkill.skillConfig = skillConfig[skilllogicconfig.Id]
                end
                allSkillDatas[skillIndex] = heroSkill
                skillIndex = skillIndex + 1
            end
        end
    end
    if curHeroConfig.OpenPassiveSkillRules then
        for i = 1, #curHeroConfig.OpenPassiveSkillRules do
            if curHeroConfig.OpenPassiveSkillRules[i][1] <= star then
                local heroSkill = {}
                heroSkill.skillId = curHeroConfig.OpenPassiveSkillRules[i][2]
                local skilllogicconfig = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.PassiveSkillLogicConfig, "Group", heroSkill.skillId, "Level", this.GetSkillUnlockLv(curHeroConfig.OpenPassiveSkillRules[i][1], star, upStarRankUpConfig.Phase[2]))
                if skilllogicconfig~=nil then
                    heroSkill.skillConfig = passiveSkillConfig[skilllogicconfig.Id]
                end
                allSkillDatas[skillIndex] = heroSkill
                skillIndex = skillIndex + 1
            end
        end
    end
    return allSkillDatas
end
function this.DetectionOpenFiveStarActivity(starUpGiftNum)
    Game.GlobalEvent:DispatchEvent(GameEvent.PatFace.PatFaceSend, FacePanelType.GrowGift, starUpGiftNum)
end

-- 判断英雄是否有魂印功能
function this.IsHeroHaveSoulPrintFunc(heroId)
    local unlock = ConfigManager.GetConfigData(ConfigName.GameSetting, 1).EquipSignUnlock
    if unlock[1] == 1 then
        -- 根据英雄判断等级
        return
    elseif unlock[1] == 2 then
        local MaxStar = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroId).MaxRank
        return MaxStar >= unlock[2]
    end
    return false
end
-- 判断英雄是否有法宝功能
function this.IsHeroHaveTalismanFunc(heroId)
    local unlock = ConfigManager.GetConfigData(ConfigName.GameSetting, 1).EquipTalismanaUnlock
    if unlock[1] == 1 then
        -- 根据英雄判断等级
        return
    elseif unlock[1] == 2 then
        local MaxStar = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroId).MaxRank
        return MaxStar >= unlock[2]
    end
    return false
end
function this.SetHeroFormationList(heroDid,teamId,isAddOrDel)
    if heroDatas[heroDid] then
        if isAddOrDel and this.heroResolveLicence[teamId] then
            heroDatas[heroDid].formationList[teamId] = teamId
        else
            heroDatas[heroDid].formationList[teamId] = nil
        end
    end
end
--获取探索所有英雄信息
function this.GetFingTreasureAllHeroDatas()
    local allUpZhenHeroList = FindTreasureManager.GetAllUpHeros()
    local heros = {}
    for i, v in pairs(heroDatas) do
        if not allUpZhenHeroList[v.dynamicId] and v.heroConfig.Material ~= 1 then
            table.insert(heros, v)
        end
    end
    return heros
end
--回溯 和 献祭 返回item信息
local rewardGroup = ConfigManager.GetConfig(ConfigName.RewardGroup)
function this.GetHeroReturnItems(selectHeroData, type,spe)
    local cost
    local allRewardData = {}
    if type == GENERAL_POPUP_TYPE.ResolveRecall then
        local specificValue = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig, 34).Value) / 10000
        local ShowItemlist = {}
        --HeroReturn 的 ReturnHero + RankupReturn * specificValue + HeroLevelConfig 的 Consume * specificValue
        --先把回溯英雄放进去
        for i, v in pairs(selectHeroData) do
            local curHeroData = heroDatas[i]
            if not curHeroData then
                return
            end
            local pId
            if curHeroData.breakId == 0 then
                pId = 0
            else
                pId = heroRankUpConfig[curHeroData.breakId].Phase[2]
            end
            local heroReturnConfig =
                ConfigManager.TryGetConfigDataByDoubleKey(
                ConfigName.HeroReturn,
                "HeroId",
                curHeroData.id,
                "Star",
                pId
            )
            local rewardShowStr1 = {}
            if not heroReturnConfig then
            else
                ShowItemlist[heroReturnConfig.HeroId] = {heroReturnConfig.HeroId,1,curHeroData.star} 
                rewardShowStr1 = heroReturnConfig.RankupReturn
                cost = heroReturnConfig.ReturnConsume
                 if rewardShowStr1 then
                    for k,v in ipairs(rewardShowStr1) do 
                        if v[1] and v[2] then
                            if not ShowItemlist[v[1]] then
                                ShowItemlist[v[1]] = {v[1], v[2] * specificValue}
                            else
                                ShowItemlist[v[1]] = {v[1],ShowItemlist[v[1]][2] + v[2] * specificValue}
                            end
                        end
                    end
                end
            end
            rewardShowStr1 = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, v.lv).SumConsume
            if rewardShowStr1 then
                for k, v in ipairs(rewardShowStr1) do 
                    if not ShowItemlist[v[1]] then
                        ShowItemlist[v[1]] = {v[1], v[2] * specificValue}
                    else
                        ShowItemlist[v[1]] = {v[1],ShowItemlist[v[1]][2] + v[2] * specificValue}
                    end
                end
            end
            --this.GetHeroReturnItems2(ShowItemlist,allRewardData)
        end
        local dropList = {}
        for n,m in pairs(ShowItemlist) do
            local curReward = {}
            curReward.id = m[1]
            curReward.num = math.floor(m[2])
            curReward.itemConfig = itemConfig[curReward.id]
            curReward.star = m[3] or nil
            table.insert(dropList, curReward)
        end

        --重置坦克添加作战方案预览
        -- for k,v in pairs(selectHeroData)do
        --     if v.planList and #v.planList>0 then
        --         for n,m in ipairs(v.planList)do
        --             local sData = m
        --             local curReward = {}
        --              local data=CombatPlanManager.GetPlanData(sData.planId)
        --             curReward.id = data.combatPlanId
        --             curReward.num = 1
        --             curReward.itemConfig = itemConfig[curReward.id]
        --             curReward.star = nil
        --             table.insert(dropList, curReward)    
        --         end
        --     end
        -- end
       
        return dropList, cost

    elseif type == GENERAL_POPUP_TYPE.ResolveDismantle then --献祭
        local specificValue = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig, 35).Value) / 10000
        for i, v in pairs(selectHeroData) do
            --当英雄一次都未突破和进阶时
            --val=itemConfig.ResolveReward+heroLevelConfig.SumConsume  else  val=HeroRankupConfig.SumConsume+heroLevelConfig.SumConsume
            --1裸角色卡（没有突破过的角色卡）熔炼后返还的材料=当前等级返还升级材料+item表返还材料
            --2有过突破的卡 =当前等级返还升级材料+突破表返还材料+升星返还材料
            local curHeroData = heroDatas[i]
            if not curHeroData then
                return
            end

            local ShowItemlist = {}

            local pId
            if curHeroData.breakId == 0 then
                pId = 0
            else
                pId = heroRankUpConfig[curHeroData.breakId].Phase[2]
            end
            if pId == 0 and curHeroData.upStarId == 0 then
                local rewardGroupId = tonumber(itemConfig[curHeroData.id].ResolveReward)
                if rewardGroupId and rewardGroup[rewardGroupId] then
                    local showItem = rewardGroup[rewardGroupId].ShowItem
                    if showItem and LengthOfTable(showItem) > 0 then
                        for i = 1, #showItem do
                            table.insert(ShowItemlist, {showItem[i][1], showItem[i][2]})
                        end
                    end
                end
            else
                if pId > 0 then
                    local heroRankUpConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroSacrifice,"Type",2,"Key",pId)
                    if heroRankUpConfig then
                        local sumConsume = heroRankUpConfig.Value
                        for i = 1, #sumConsume do
                            table.insert(ShowItemlist, {sumConsume[i][1], sumConsume[i][2] * specificValue})
                        end
                    else
                        
                    end
                end
                if curHeroData.star > 1 then
                    local heroRankUpConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroSacrifice,"Type",1,"Key",curHeroData.star)
                    if heroRankUpConfig then
                        local sumConsume = heroRankUpConfig.Value
                        for i = 1, #sumConsume do
                            table.insert(ShowItemlist, {sumConsume[i][1], sumConsume[i][2] * specificValue})
                        end
                    end
                else
                    
                end
            end
            local temp = {}
            if curHeroData.talismanList > 1 then
                local temp1 = tonumber(ConfigManager.GetConfigData(ConfigName.HeroConfig, curHeroData.id).EquipTalismana[2])
                for i = 1, curHeroData.talismanList - 1 do
                    temp = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana,"TalismanaId",temp1,"Level",i).RankupBasicMaterial
                    for i = 1,#temp do
                        table.insert(ShowItemlist, {temp[i][1], temp[i][2] * specificValue})
                    end
                end

            end
            if curHeroData.lv > 1 then
                local rewardShowStr2 = {}
                rewardShowStr2 = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv).SumConsume
                if rewardShowStr2 then
                    for i = 1, #rewardShowStr2 do
                        if rewardShowStr2[i] and rewardShowStr2[i][1] then
                            table.insert(ShowItemlist, {rewardShowStr2[i][1], rewardShowStr2[i][2] * specificValue})
                        end
                    end
                end
            end

            --能力
            if curHeroData.warWaySlot1Id ~= nil and curHeroData.warWaySlot1Id ~= 0 then
                local warWayData
                warWayData = ConfigManager.GetConfigData(ConfigName.WarWaySkillConfig, curHeroData.warWaySlot1Id)
                if warWayData then
                    local dataList = ConfigManager.GetAllConfigsDataByKey(ConfigName.WarWaySkillConfig,"WarWayGroup",warWayData.WarWayGroup)
                    for i = 1, #dataList do
                        if dataList[i].Level <= warWayData.Level then
                            for j = 1, #dataList[i].UpgradeCost do
                             table.insert(ShowItemlist, {dataList[i].UpgradeCost[j][1], dataList[i].UpgradeCost[j][2]})
                            end

                        end
                    end
                end
            end
            if curHeroData.warWaySlot2Id ~= nil and curHeroData.warWaySlot2Id ~= 0 then
                local warWayData
                warWayData = ConfigManager.GetConfigData(ConfigName.WarWaySkillConfig, curHeroData.warWaySlot2Id)
                if warWayData then
                    local dataList = ConfigManager.GetAllConfigsDataByKey(ConfigName.WarWaySkillConfig,"WarWayGroup",warWayData.WarWayGroup)
                    for i = 1, #dataList do
                        if dataList[i].Level <= warWayData.Level then
                            for j = 1, #dataList[i].UpgradeCost do
                             table.insert(ShowItemlist, {dataList[i].UpgradeCost[j][1], dataList[i].UpgradeCost[j][2]})
                            end

                        end
                    end
                end
            end

            this.GetHeroReturnItems2(ShowItemlist, allRewardData)
        end

        local dropList = {}
        for k, v in pairs(allRewardData) do
            v.num = math.floor(v.num)
            table.insert(dropList, v)
        end
        table.sort(
            dropList,
            function(a, b)
                return itemConfig[a.id].Quantity > itemConfig[b.id].Quantity
            end
        )
        return dropList
    elseif type == GENERAL_POPUP_TYPE.ResolveDebris then --碎片回收       
        local specificValue = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig, 35).Value) / 10000
        for i, v in pairs(selectHeroData) do
            --当英雄一次都未突破和进阶时
            --val=itemConfig.ResolveReward+heroLevelConfig.SumConsume  else  val=HeroRankupConfig.SumConsume+heroLevelConfig.SumConsume
            --1裸角色卡（没有突破过的角色卡）熔炼后返还的材料=当前等级返还升级材料+item表返还材料
            --2有过突破的卡 =当前等级返还升级材料+突破表返还材料+升星返还材料
            local curHeroData = heroDatas[i]
            if not curHeroData then
                return
            end

            local ShowItemlist = {}
            local pId
            if curHeroData.breakId == 0 then
                pId = 0
            else
                pId = heroRankUpConfig[curHeroData.breakId].Phase[2]
            end

            if pId == 0 and curHeroData.upStarId == 0 then
                local rewardGroupId = tonumber(itemConfig[curHeroData.id].ResolveReward)
                if rewardGroupId and rewardGroup[rewardGroupId] then
                    local showItem = rewardGroup[rewardGroupId].ShowItem
                    if showItem and LengthOfTable(showItem) > 0 then
                        for i = 1, #showItem do
                            table.insert(ShowItemlist, {showItem[i][1], showItem[i][2]})
                        end
                    end
                end
            else
                if pId > 0 then
                    local heroRankUpConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroSacrifice,"Type",2,"Key",pId)
                    if heroRankUpConfig then
                        local sumConsume = heroRankUpConfig.Value
                        for i = 1, #sumConsume do
                            table.insert(ShowItemlist, {sumConsume[i][1], sumConsume[i][2] * specificValue})
                        end
                    else
                        
                    end
                end
                if curHeroData.star > 1 then
                    local heroRankUpConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroSacrifice,"Type",1,"Key",curHeroData.star)
                    if heroRankUpConfig then
                        local sumConsume = heroRankUpConfig.Value
                        for i = 1, #sumConsume do
                            table.insert(ShowItemlist, {sumConsume[i][1], sumConsume[i][2] * specificValue})
                        end
                    end
                else
                    
                end
            end
            local temp = {}
            if curHeroData.talismanList > 1 then
                local temp1 = tonumber(ConfigManager.GetConfigData(ConfigName.HeroConfig, curHeroData.id).EquipTalismana[2])
                for i = 1, curHeroData.talismanList - 1 do
                    temp = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana,"TalismanaId",temp1,"Level",i).RankupBasicMaterial
                    for i = 1,#temp do
                        table.insert(ShowItemlist, {temp[i][1], temp[i][2] * specificValue})
                    end
                end
            end
            if curHeroData.lv > 1 then
                local rewardShowStr2 = {}
                rewardShowStr2 = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv).SumConsume
                if rewardShowStr2 then
                    for i = 1, #rewardShowStr2 do
                        if rewardShowStr2[i] and rewardShowStr2[i][1] then
                            table.insert(ShowItemlist, {rewardShowStr2[i][1], rewardShowStr2[i][2] * specificValue})
                        end
                    end
                end
            end
            this.GetHeroReturnItems2(ShowItemlist, allRewardData)
        end

        local dropList = {}
        for k, v in pairs(allRewardData) do
            v.num = math.floor(v.num)
            table.insert(dropList, v)
        end
        table.sort(
            dropList,
            function(a, b)
                return itemConfig[a.id].Quantity > itemConfig[b.id].Quantity
            end
        )
        return dropList
    elseif type == GENERAL_POPUP_TYPE.GeneralPopup_HeroStarBack then--改装厂回溯(普通高级)
        if spe == 1 then
            local specificValue = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig, 34).Value) / 10000
            local ShowItemlist = {}
            --HeroReturn 的 ReturnHero + RankupReturn * specificValue + HeroLevelConfig 的 Consume * specificValue
            --先把回溯英雄放进去
            for i, v in pairs(selectHeroData) do
                local curHeroData = heroDatas[i]
                if not curHeroData then
                    return
                end
                local pId
                if curHeroData.breakId == 0 then
                    pId = 0
                else
                    pId = heroRankUpConfig[curHeroData.breakId].Phase[2]
                end
                local heroReturnConfig =
                    ConfigManager.TryGetConfigDataByDoubleKey(
                    ConfigName.HeroReturn,
                    "HeroId",
                    curHeroData.id,
                    "Star",
                    pId
                )
                local rewardShowStr1 = {}
                if not heroReturnConfig then
                else
                    rewardShowStr1 = heroReturnConfig.RankupReturn
                     if rewardShowStr1 then
                        for k,v in ipairs(rewardShowStr1) do 
                            if v[1] and v[2] then
                                if not ShowItemlist[v[1]] then
                                    ShowItemlist[v[1]] = {v[1], v[2] * specificValue}
                                else
                                    ShowItemlist[v[1]] = {v[1],ShowItemlist[v[1]][2] + v[2] * specificValue}
                                end
                            end
                        end
                    end
                end
                rewardShowStr1 = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, v.lv).SumConsume
                if rewardShowStr1[1][2] then
                    for k,v in ipairs(rewardShowStr1) do 
                        if not ShowItemlist[v[1]] then
                            ShowItemlist[v[1]] = {v[1], v[2] * specificValue}
                        else
                            ShowItemlist[v[1]] = {v[1],ShowItemlist[v[1]][2] + v[2] * specificValue}
                        end
                    end
                end
    
                  if curHeroData.warWaySlot1Id ~= nil and curHeroData.warWaySlot1Id ~= 0 then
                    local warWayData
                    warWayData = ConfigManager.GetConfigData(ConfigName.WarWaySkillConfig, curHeroData.warWaySlot1Id)
                    if warWayData then
                        local dataList = ConfigManager.GetAllConfigsDataByKey(ConfigName.WarWaySkillConfig,"WarWayGroup",warWayData.WarWayGroup)
                        for i = 1, #dataList do
                            if dataList[i].Level <= warWayData.Level then
                                for j = 1, #dataList[i].UpgradeCost do
                                 table.insert(ShowItemlist, {dataList[i].UpgradeCost[j][1], dataList[i].UpgradeCost[j][2]})
                                end
                            end
                        end
                    end
                end
            end
            local dropList = {}
            for n,m in pairs(ShowItemlist) do
                local curReward = {}
                curReward.id = m[1]
                curReward.num = math.floor(m[2])
                curReward.itemConfig = itemConfig[curReward.id]
                curReward.star = m[3] or nil
                table.insert(dropList, curReward)
            end
    
            return dropList
        else
            local specificValue = tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig, 34).Value) / 10000
            local ShowItemlist = {}
            --HeroReturn 的 ReturnHero + RankupReturn * specificValue + HeroLevelConfig 的 Consume * specificValue
            --先把回溯英雄放进去
            for i, v in pairs(selectHeroData) do
                local curHeroData = heroDatas[i]
                if not curHeroData then
                    return
                end
                -- local pId
                -- if curHeroData.breakId == 0 then
                --     pId=0
                -- else
                --     pId= heroRankUpConfig[curHeroData.breakId].Phase[2]
                -- end
                -- local heroReturnConfig =
                --     ConfigManager.TryGetConfigDataByDoubleKey(
                --     ConfigName.HeroReturn,
                --     "HeroId",
                --     curHeroData.id,
                --     "Star",
                --     pId
                -- )
                -- local rewardShowStr1 = {}
                -- if not heroReturnConfig then
                
                -- else
                --     rewardShowStr1 = heroReturnConfig.RankupReturn
                --      if rewardShowStr1 then
                --         for k,v in ipairs(rewardShowStr1) do 
                --             if v[1] and v[2] then
                --                 if not ShowItemlist[v[1]] then
                --                     ShowItemlist[v[1]] = {v[1], v[2] * specificValue}
                --                 else
                --                     ShowItemlist[v[1]] = {v[1],ShowItemlist[v[1]][2] + v[2] * specificValue}
                --                 end
                --             end
                --         end
                --     end
                -- end
                -- rewardShowStr1 = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, v.lv).SumConsume
                -- if rewardShowStr1 then
                --     for k,v in ipairs(rewardShowStr1) do 
                --         if not ShowItemlist[v[1]] then
                --             ShowItemlist[v[1]] = {v[1], v[2] * specificValue}
                --         else
                --             ShowItemlist[v[1]] = {v[1],ShowItemlist[v[1]][2] + v[2] * specificValue}
                --         end
                --     end
                -- end
    
                if curHeroData.warWaySlot2Id ~= nil and curHeroData.warWaySlot2Id ~= 0 then
                    local warWayData
                    warWayData = ConfigManager.GetConfigData(ConfigName.WarWaySkillConfig, curHeroData.warWaySlot2Id)
                    if warWayData then
                        local dataList=ConfigManager.GetAllConfigsDataByKey(ConfigName.WarWaySkillConfig,"WarWayGroup",warWayData.WarWayGroup)
    
                        for i = 1, #dataList do
                            if dataList[i].Level <= warWayData.Level then
                                for j = 1, #dataList[i].UpgradeCost do
                                 table.insert(ShowItemlist, {dataList[i].UpgradeCost[j][1], dataList[i].UpgradeCost[j][2]})
                                end
                            end
                        end
                    end
                end
            end
            local dropList = {}
            for n,m in pairs(ShowItemlist) do
                local curReward = {}
                curReward.id = m[1]
                curReward.num = math.floor(m[2])
                curReward.itemConfig = itemConfig[curReward.id]
                curReward.star = m[3] or nil
                table.insert(dropList, curReward)
            end
    
            return dropList
        end
    end
end

function this.GetHeroReturnItems2(ShowItemlist, allRewardData)
    for i = 1, #ShowItemlist do
        local curReward = {}
        curReward.id = ShowItemlist[i][1]
        curReward.num = ShowItemlist[i][2]
        curReward.itemConfig = itemConfig[curReward.id]
        if allRewardData[curReward.id] == nil then
            allRewardData[curReward.id] = curReward
        else
            allRewardData[curReward.id].num = allRewardData[curReward.id].num + curReward.num
        end
    end
end

--更新英雄主动技能
function this.UpdateSkillIdList(heroData)
    heroData.skillIdList = {}
    this.SetSkillListByRules(heroData, false, heroData.skillIdList)
end
--更新英雄被动技能
function this.UpdatePassiveHeroSkill(heroData)
    heroData.passiveSkillList = {} --被动技
    this.SetSkillListByRules(heroData, true, heroData.passiveSkillList)
end
--> 获取技能数据 by Rules(HeroConfig)
function this.SetSkillListByRules(heroData, isPassivity, RetList)
    local Rules = nil
    if isPassivity then
        Rules = heroData.heroConfig.OpenPassiveSkillRules
    else
        Rules = heroData.heroConfig.OpenSkillRules
    end
     
    if Rules then
        for i = 1, #Rules do
            while true do
                --改解锁机制
                local pId
                if heroData.breakId == 0 then
                    pId = 0
                else
                    pId = heroRankUpConfig[heroData.breakId].Phase[2]
                end
                local unlockLv = this.GetSkillUnlockLv(Rules[i][1], heroData.star, pId)
                if unlockLv == -1 then
                    break
                end
                local skilllogicconfig = ConfigManager.GetAllConfigsDataByDoubleKey(isPassivity and ConfigName.PassiveSkillLogicConfig or ConfigName.SkillLogicConfig, "Group", Rules[i][2], "Level", unlockLv)

                local heroSkill = {}
                heroSkill.skillId = skilllogicconfig.Id
                heroSkill.skillConfig = isPassivity and passiveSkillConfig[skilllogicconfig.Id] or skillConfig[skilllogicconfig.Id]
                table.insert(RetList, heroSkill)

                break
            end
        end
    end
end

--获取技能等级 skillpos技能槽位 _break阶级
function this.GetSkillUnlockLv(skillpos, _star, _break)
    local unlocklv = -1
    local maxlv = -1
    for index, value in ConfigPairs(unlockSkill) do
        if value["SkillPos"] == skillpos and value["Star"] <= _star and value["Rank"] <= _break then
            maxlv = math.max(maxlv, value["UnlockLV"])
        end
    end
    -- LogYellow(maxlv)
    if maxlv ~= -1 then
        unlocklv = maxlv
    end
    return unlocklv
end

--获取skillids 根据hero 表rules
function this.GetSkillIdsByHeroRules(_rules, _star, _break)
    local RetList = {}
    if _rules then
        for i = 1, #_rules do
            --> 改解锁机制
            local pId
            if _break == 0 then
                pId=0
            else
                pId= heroRankUpConfig[_break].Phase[2]
            end
            local unlockLv = this.GetSkillUnlockLv(_rules[i][1], _star, pId)
            if unlockLv ~= -1 then
                local skilllogicconfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.SkillLogicConfig, "Group", _rules[i][2], "Level", unlockLv)
                local heroSkill = {}
                heroSkill.skillId = skilllogicconfig.Id
                heroSkill.skillConfig = skillConfig[skilllogicconfig.Id]
                heroSkill.lock = false
                table.insert(RetList, heroSkill)
            end
        end
    end
    return RetList
end
function this.GetSkillIdsByHeroRulesRole(_rules, _star, _break, _heroData)
    local heroData = _heroData
    local RetList = {}
    if _rules then
        for i = 1, #_rules do
            --> 改解锁机制
            local pId
            if _break == 0 then
                pId = 0
            else
                pId = heroRankUpConfig[_break].Phase[2]
            end
            local unlockLv = this.GetSkillUnlockLv(_rules[i][1], _star, pId)
            if unlockLv ~= -1 then
                local skilllogicconfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.SkillLogicConfig, "Group", _rules[i][2], "Level", unlockLv)
                local heroSkill = {}

                local skillId = skilllogicconfig.Id
                --> 部件add 只有全部解锁会有此功能 下面undo
                if heroData then
                    local skillIdStr = tostring(skillId)
                    local slot = tonumber(string.sub(skillIdStr, -2, -2))
                    
                    local partsData = heroData.partsData
                    local partsAddLv = 0
                    if partsData[slot] then
                        if partsData[slot].isUnLock > 0 then
                            partsAddLv = partsData[slot].actualLv
                        end
                    end
                    skillId = skillId + partsAddLv
                end

                heroSkill.skillId = skillId
                heroSkill.skillConfig = skillConfig[skillId]
                heroSkill.lock = false
                table.insert(RetList, heroSkill)
            else
                local skilllogicconfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.SkillLogicConfig, "Group", _rules[i][2], "Level", 1)
                local heroSkill = {}
                heroSkill.skillId = skilllogicconfig.Id
                heroSkill.skillConfig = skillConfig[skilllogicconfig.Id]
                heroSkill.lock=true
                table.insert(RetList, heroSkill)
            end
        end
    end
    return RetList
end

--获取英雄的铸神等级
function this.GetSkillPartsAddLevel(_rules, _star, _break, _heroData)
    local heroData = _heroData
    local addLv = 0
    if _rules then
        for i = 1, #_rules do
            --> 改解锁机制
            local pId
            if _break == 0 then
                pId = 0
            else
                pId = heroRankUpConfig[_break].Phase[2]
            end
            local unlockLv = this.GetSkillUnlockLv(_rules[i][1], _star, pId)
            if unlockLv ~= -1 then
                local skilllogicconfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.SkillLogicConfig, "Group", _rules[i][2], "Level", unlockLv)
                local skillId = skilllogicconfig.Id
                --> 部件add 只有全部解锁会有此功能 下面undo
                if heroData then
                    local skillIdStr = tostring(skillId)
                    local slot = tonumber(string.sub(skillIdStr, -2, -2))                    
                    local partsData = heroData.partsData
                    local partsAddLv = 0
                    if partsData[slot] then
                        if partsData[slot].isUnLock > 0 then
                            partsAddLv = partsData[slot].actualLv
                        end
                    end
                    addLv = partsAddLv
                end
            end
        end
    end
    return addLv
end

--获取被动skillids 根据hero 表rules
function this.GetPassiveSkillIdsByHeroRules(_rules, _star, _break)
    local RetList = {}
    if _rules then
        for i = 1, #_rules do
            --> 改解锁机制
            local pId
            if _break == 0 then
                pId=0
            else
                pId= heroRankUpConfig[_break].Phase[2]
            end
            local unlockLv = this.GetSkillUnlockLv(_rules[i][1], _star, pId)
            if unlockLv ~= -1 then
                local skilllogicconfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.PassiveSkillLogicConfig, "Group", _rules[i][2], "Level", unlockLv)

                local heroSkill = {}
                heroSkill.skillId = skilllogicconfig.Id
                heroSkill.skillConfig = passiveSkillConfig[skilllogicconfig.Id]
                table.insert(RetList, heroSkill)
            end
        end
    end
    return RetList
end
function this.GetPassiveSkillIdsByHeroRuleslock(_rules, _star, _break, _heroData)
    local heroData = _heroData
    local RetList = {}
    if _rules then
        for i = 1, #_rules do
            --> 改解锁机制
            local pId
            if _break == 0 then
                pId = 0
            else
                pId = heroRankUpConfig[_break].Phase[2]
            end
            local unlockLv = this.GetSkillUnlockLv(_rules[i][1], _star, pId)
            if unlockLv ~= -1 then
                local skilllogicconfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.PassiveSkillLogicConfig, "Group", _rules[i][2], "Level", unlockLv)
                local heroSkill = {}
                local skillId = skilllogicconfig.Id
                -- 部件add 只有全部解锁会有此功能 下面undo
                if heroData then
                    local skillIdStr = tostring(skillId)
                    local slot = tonumber(string.sub(skillIdStr, -2, -2))
                    
                    local partsData = heroData.partsData
                    local partsAddLv = 0
                    if partsData[slot] then
                        if partsData[slot].isUnLock > 0 then
                            partsAddLv = partsData[slot].actualLv
                        end
                    end
                    skillId = skillId + partsAddLv
                end

                heroSkill.skillId = skillId
                heroSkill.skillConfig = passiveSkillConfig[skillId]
                heroSkill.lock=false
                table.insert(RetList, heroSkill)
            else
                local skilllogicconfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.PassiveSkillLogicConfig, "Group", _rules[i][2], "Level", 1)

                local heroSkill = {}
                heroSkill.skillId = skilllogicconfig.Id
                heroSkill.skillConfig = passiveSkillConfig[skilllogicconfig.Id]
                heroSkill.lock = true
                table.insert(RetList, heroSkill)
            end
        end
    end
    return RetList
end

-----------新魂印开始
--增加魂印装备的英雄did
function this.AddSoulPrintUpHeroDynamicId(heroDid, soulPrintSid, soulPrintPos)
    if heroDatas[heroDid] then
        local singleSoulPrint = {equipId = soulPrintSid, position = soulPrintPos}
        table.insert(heroDatas[heroDid].soulPrintList, singleSoulPrint)
        SoulPrintManager.AddSoulPrintUpHeroDynamicId(soulPrintSid, heroDid)
    end
end
--删除魂印装备的英雄did
function this.DelSoulPrintUpHeroDynamicId(heroDid, soulPrintSid)
    if heroDatas[heroDid] then
        for i = 1, #heroDatas[heroDid].soulPrintList do
            if heroDatas[heroDid].soulPrintList[i] and heroDatas[heroDid].soulPrintList[i].equipId == soulPrintSid then
                table.remove(heroDatas[heroDid].soulPrintList, i)
                SoulPrintManager.DelSoulPrintUpHeroDynamicId(soulPrintSid, heroDid)
            end
        end
    end
end
------------新魂印结束

--天赋技能（被动技能）
function this.GetAllPassiveSkillIds(heroConfig, breakId, upStarId,star,curHeroData)
    --> 暂屏,新修改
    if  false then
        return {}, 0, 0, {}
    end
    --获取星级
    local PassiveskillId = {}
    local islock = {}
    --获取被动技能组id
    local allPassiveSkillIds = {}
    if star then
    local GetopenPassiveSkillRules = this.GetPassiveSkillIdsByHeroRuleslock(heroConfig.OpenPassiveSkillRules,star,breakId,curHeroData)
      for i = 1, #GetopenPassiveSkillRules do
           if GetopenPassiveSkillRules[i] and not GetopenPassiveSkillRules[i].lock then
                PassiveskillId[i] = GetopenPassiveSkillRules[i].skillConfig.Id
                table.insert(allPassiveSkillIds,PassiveskillId[i])
            end
        end
    end
    
    local allPassiveSkillIdcompound = {}
    local allOpenPassiveSkillIdcompound = {}
    local allUpStarOpenData = {}
    --只用于界面升星开放技能提示显示用
    local compoundNum = 0
    local compoundOPenNum = 0
        if heroConfig.OpenPassiveSkillRules then
        for i = 1, #heroConfig.OpenPassiveSkillRules do
            if heroConfig.OpenPassiveSkillRules[i][1] == 1 then --突破
                 --for j=1,#PassiveskillId do
                if --[[breakId >= heroConfig.OpenPassiveSkillRules[i][2]] false then
                    -- local openPassiveSkillRules = allPassiveSkillIds,heroConfig.OpenPassiveSkillRules
                    table.insert(allPassiveSkillIds, --[[heroConfig.OpenPassiveSkillRules[i][3]]PassiveskillId[j])
                    if allOpenPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] then allOpenPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] =
                            allOpenPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] + 1
                    else
                        allOpenPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] = 1
                    end
                end
            else --升星
                allUpStarOpenData[heroRankUpConfig[heroConfig.OpenPassiveSkillRules[i][1]]] = heroConfig.OpenPassiveSkillRules[i]
                         --for j=1,#PassiveskillId do
                if --[[upStarId >= heroConfig.OpenPassiveSkillRules[i][1]] false then
                    table.insert(allPassiveSkillIds, --[[heroConfig.OpenPassiveSkillRules[i][3]]PassiveskillId[1])
                    if allOpenPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] then
                        allOpenPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] = allOpenPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] + 1
                    else
                        allOpenPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] = 1
                    end
                end
            end
            if allPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] then
                allPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] = allPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] + 1
            else
                allPassiveSkillIdcompound[heroConfig.OpenPassiveSkillRules[i][2]] = 1
            end
        end
    end
    for i, v in pairs(allPassiveSkillIdcompound) do
        if v > 1 then
            compoundNum = compoundNum + 1
        end
    end
    for i, v in pairs(allOpenPassiveSkillIdcompound) do
        if v > 1 then
            compoundOPenNum = compoundOPenNum + 1
        end
    end
    return allPassiveSkillIds, compoundOPenNum, compoundNum, allUpStarOpenData
end

-- 目前只有gm之前的战斗模拟会用到
--战中英雄被动技获取
function this.GetHeroAllPassiveSkillIds(curHeroData)
    local allPassiveSkillIds = {}
    if not curHeroData then
        return allPassiveSkillIds
    end
    --英雄天赋被动技
    if curHeroData.heroConfig.OpenPassiveSkillRules then
        local openPassiveSkillRules = curHeroData.heroConfig.OpenPassiveSkillRules
        for i = 1, #openPassiveSkillRules do
            local skillType = openPassiveSkillRules[i][1]
            local skillRanUpId = openPassiveSkillRules[i][2]
            local skillId = openPassiveSkillRules[i][3]
            if skillType == 1 then --突破
                if curHeroData.breakId >= skillRanUpId and passiveSkillLogicConfig[skillId].EffectiveRange == 1 then
                    table.insert(allPassiveSkillIds, skillId)
                end
            else --升星
                if curHeroData.upStarId >= skillRanUpId and passiveSkillLogicConfig[skillId].EffectiveRange == 1 then
                    table.insert(allPassiveSkillIds, skillId)
                end
            end
        end
    end
    --法宝被动技
    if curHeroData.heroConfig.EquipTalismana and curHeroData.star >= curHeroData.heroConfig.EquipTalismana[1] then
        local curTalisman = ConfigManager.GetConfigData(ConfigName.HeroConfig, curHeroData.id).EquipTalismana
        if curTalisman and curTalisman[2] then
            local talismanConFig =
                ConfigManager.GetConfigDataByDoubleKey(
                ConfigName.EquipTalismana,
                "TalismanaId",
                curTalisman[2],
                "Level",
                curHeroData.talismanList
            )
            if talismanConFig then
                --当前法宝全部天赋数据(天赋可能为空)
                local dowerAllData =
                    ConfigManager.GetAllConfigsDataByKey(ConfigName.EquipTalismana, "TalismanaId", curTalisman[2])
                for i = 1, #dowerAllData do
                    if dowerAllData[i].OpenSkillRules and curHeroData.talismanList >= dowerAllData[i].Level then
                        for k = 1, #dowerAllData[i].OpenSkillRules do
                            if passiveSkillLogicConfig[dowerAllData[i].OpenSkillRules[k]].EffectiveRange == 1 then
                                table.insert(allPassiveSkillIds, dowerAllData[i].OpenSkillRules[k])
                            end
                        end
                    end
                end
            end
        end
    end
    --魂印被动技
    if (table.nums(curHeroData.soulPrintList) >= 1) then
        for i = 1, #curHeroData.soulPrintList do
            local cursoulPrintConfig = equipConfig[curHeroData.soulPrintList[i].equipId]
            if cursoulPrintConfig and cursoulPrintConfig.PassiveSkill then
                for _, pId in ipairs(cursoulPrintConfig.PassiveSkill) do
                    if passiveSkillLogicConfig[pId] and passiveSkillLogicConfig[pId].EffectiveRange == 1 then
                        table.insert(allPassiveSkillIds, pId)
                    end
                end
            end
        end
    end
    for i = 1, #allPassiveSkillIds do
        LogRed("allPassiveSkillIds        " .. allPassiveSkillIds[i])
    end
    return allPassiveSkillIds
end
--获取当前类型英雄是否存在
function this.GetCurHeroIsHaveBySid(heroSId)
    for i, v in pairs(heroDatas) do
        if v.id == heroSId then
            return true
        end
    end
    return false
end

-- 角色定位相关
-- 判断该角色是否开启定位 sid 英雄静态ID
function this.IsHeroPosOpen(did)
    return this.GetSingleHeroData(did).heroConfig.RecommendTeamId[1] ~= 0
end

--单个红点判断
local isHeroUpTuPo = false
local isHeroUpStar = false
local upTuPoRankUpConfig = {}
local upStarRankUpConfig = {}
local heroRankupConfig = ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
--编队所有英雄判断
function this.GetFormationHeroRedPoint()
    local teamHero = FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_NORMAL)
    local allHero= HeroManager.GetAllHeroDatas(0)
    for i, v in pairs(teamHero) do
        local curHeroData = HeroManager.GetSingleHeroData(i)
        local abilityRedPointState=this.GetCurHeroAbilityIsShowRedPoint(curHeroData)
        if
        -- dynamicId
        this.GetCurHeroUpLvOrUpStarSData(curHeroData) or 
        this.LvUpBtnRedPoint(curHeroData) or
            this.IsShowUpStarRedPoint(curHeroData) or
            #this.GetHeroIsUpEquip(curHeroData.dynamicId) > 0 or
            this.GetIsShowSoulPrintRedPoint(curHeroData) or
            this.GetIsShowTalismanRedPoint(curHeroData) 
            or abilityRedPointState["ability1"] or abilityRedPointState["ability2"]
        then
            return true
        end
    end
    return false
end

--所有英雄红点判断
function this.GetAllHeroRedPoint()
    local allHero= HeroManager.GetAllHeroDatas(0)
    local myHasBetterRings,myBetterRingsState=this.GetRingsIsShowRedPoin(curHeroData)
    for i, v in pairs(allHero) do
        local curHeroData = HeroManager.GetSingleHeroData(v.dynamicId)
        local abilityRedPointState=this.GetCurHeroAbilityIsShowRedPoint(curHeroData)
        --获得戒指是否有要显示红点的状态
        if
        this.GetCurHeroUpLvOrUpStarSData(curHeroData) or 
        this.LvUpBtnRedPoint(curHeroData) or
            this.IsShowUpStarRedPoint(curHeroData) or
            #this.GetHeroIsUpEquip(curHeroData.dynamicId) > 0 or
            this.GetIsShowSoulPrintRedPoint(curHeroData) or
            this.GetIsShowTalismanRedPoint(curHeroData) or abilityRedPointState["ability1"] or abilityRedPointState["ability2"] or
            (myBetterRingsState["Rings1"] or myBetterRingsState["Rings2"])
            then
                return true
        end
    end
    return false
end


----玩家能力只要有一个可以学习和升级就返回true
function this.GetCurHeroAbilityIsShowRedPointState()
    return abilityCanShowRedPointState["ability1"] or abilityCanShowRedPointState["ability2"]
end

--玩家能力可学习可升级给两个技能的true和false
function this.GetCurHeroAbilityIsShowRedPoint(curHeroData)
    local limit = {
    ["limitStarLv1"] = 6,
    ["limitStarLv2"] = 11
    }   
    
    for i = 1, 2 do
        --技能如果可以升级需要红点
        --获得当前技能的当前等级，id分别是1和2
        local warWaySlotId = curHeroData[string.format("warWaySlot%dId",i)]
        local warWayConfig = WarWaySkillConfig[warWaySlotId]
        --Log("---------------------------------------")
        if warWayConfig ~= nil then
            if warWayConfig.Level >= 4 then
                -- Log("技能超出上限了")
                --this.SetActive(this.btnAbilityRedPoint,false)
                abilityCanShowRedPointState["ability".. tostring(i)]=false
            else
                -- Log("技能" .. i .. "的当前等级是:" .. warWayConfig.Level)
                
                local nextId = tonumber(tostring(warWayConfig.WarWayGroup) .. tostring(warWayConfig.Level + 1))
                local warWayConfigNext = WarWaySkillConfig[nextId]
                
                --第1个能力升级所需要的的道具id和道具数量
                local itemid1 = warWayConfigNext.UpgradeCost[1][1]
                local itemnum1 = warWayConfigNext.UpgradeCost[1][2]
                
                --第2个能力升级所需要的的道具id和道具数量
                local itemid2 = warWayConfigNext.UpgradeCost[2][1]
                local itemnum2 = warWayConfigNext.UpgradeCost[2][2]
                
                --第1个能力升级所需要的第1个道具数量
                local ownNum1 = BagManager.GetItemCountById(itemid1)
                --第2个能力升级所需要的第1个道具数量
                local ownNum2 = BagManager.GetItemCountById(itemid2)
                --Log("能力"..i.."道具1背包物品数量：".. ownNum1)
                --Log("能力"..i.."道具2升级所需物品数量:".. itemnum1)
                
                --Log("能力"..i.."道具1背包物品数量：".. ownNum2)
                --Log("能力"..i.."道具2升级所需物品数量:".. itemnum2)
                
                --判断英雄星级是否达到条件
                local TankStar1= curHeroData.star
                local TankStar2= warWayConfigNext.TankStarLimit


                if ownNum1 > itemnum1 and ownNum2 > itemnum2 and TankStar1>= TankStar2 then
                    --Log("能力"..i.."可以升级，可以展示红点")
                    abilityCanShowRedPointState["ability".. tostring(i)]=true
                else
                    --Log("能力"..i.."条件不满足不可以升级！")
                    abilityCanShowRedPointState["ability".. tostring(i)]=false
                end
            end
        else
            --Log("技能" .. i .. "暂时没学习")
            abilityCanShowRedPointState["ability".. tostring(i)]=false
        end
        --Log("---------------------------------------")
        if curHeroData.star >= limit["limitStarLv" .. tostring(i)] then -- isOpen
            local isOn = false
            local warWaySlotId = curHeroData[string.format("warWaySlot%dId", i)]
            
            if warWaySlotId and warWaySlotId ~= 0 then
                isOn = true
            end
            if not isOn then
                --解锁了能力但是没有学习能力，加号和红点都显示
                abilityCanShowRedPointState["ability".. tostring(i)]=true
            end
        end
        --Log("ability1:" .. tostring(abilityCanShowRedPointState["ability1"]))
        --Log("ability2:" .. tostring(abilityCanShowRedPointState["ability2"]))
    end

    --先判断是否有能力技能
    if this.IsCompetencySkills() == false then
        abilityCanShowRedPointState["ability1"] = false
        abilityCanShowRedPointState["ability2"] = false

    end 

    return abilityCanShowRedPointState
end

--玩家戒指解锁，有更好的戒指，解锁了但是没装备戒指
function this.GetRingsIsShowRedPoin(curHeroData)

    if curHeroData==nil then
        return false,betterRingsState
    end

    --因为是全局变量，使用之前先重置
    betterRingsState["Rings1"]=false
    betterRingsState["Rings2"]=false

        --红点显示的条件
    --  1.解锁了但是没有装备
    --  2.有更好的戒指
    --首先看玩家有没有解锁戒指，然后判断当前装备的戒指有没有更好的替代品
    --如果没解锁红点显示，有更好的替代品也显示红点

    --查看两个戒指的解锁状态
    local rings1IsUnlock=false
    local rings2IsUnlock=false

    for i=1,2 do
        local s_type = 0
        local s_value = 0
        local specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "CombatPlanUnlock")
        local valueArray = string.split(specialConfig.Value, "|")
        local a = string.split(valueArray[i], "#")
        s_type = a[2]
        s_value = a[3]
        if tonumber(s_type) == 1 then
            rings1IsUnlock= curHeroData.lv >= tonumber(s_value)
        elseif tonumber(s_type) == 2 then
            rings2IsUnlock=curHeroData.star >= tonumber(s_value)
        end
    end

    if not rings1IsUnlock and not rings2IsUnlock then
        --Log("戒指没解锁")
        return false,betterRingsState
    end

    --初始化获得背包所有的戒指,索引从5开始，因为装备是1234，方便区别
    curRingsData = {}
    for i = 1, #curHeroData.planList do
        local sData = curHeroData.planList[i]
        local bData = CombatPlanManager.GetPlanData(sData.planId)
        curRingsData[sData.position+4] = {sData = sData, bData = bData}
    end

    --获取所有的没装备的戒指
    local allRingsData = CombatPlanManager.GetPlanByType(2)
    --用来存储所有没装备戒指的评分
    local ringsPowerNum = {}
    --有没有最好的戒指
    local hasBetterRings = false
    --最好戒指的评分
    local bestRings = 0
    --把所有没装备戒指的评分到table中
    for i = 1, #allRingsData do
        local oneRingsData = CombatPlanManager.CalPlanPowerByProperty(allRingsData[i].property)
        ringsPowerNum[i] = oneRingsData
    end
    --取出所有未装备戒指中的最大评分,如果只一件装备那就不用排了
    if #ringsPowerNum > 1 then
        bestRings= math.max(unpack(ringsPowerNum))
    end

    for i = 1, #allRingsData do
        local oneRingsData = bestRings
            --如果两个戒指有一个解锁了就显示红点
            if curRingsData[5] == nil or curRingsData[6] == nil then
                hasBetterRings = true
            else
                --如果当前装备戒指的评分不大于未装备的最高评分的戒指那么久显示红点
                if
                    oneRingsData > CombatPlanManager.CalPlanPowerByProperty(curRingsData[5].bData.property) or
                        oneRingsData > CombatPlanManager.CalPlanPowerByProperty(curRingsData[6].bData.property)
                then
                    hasBetterRings = true
                end
            end

            if rings1IsUnlock then
                    --比较一号戒指是不是有更好的替代品
                if curRingsData[5] == nil then
                    betterRingsState["Rings1"] = true
                    --Log("一号戒指解锁了但是没装备")
                else
                    --注释戒指一号评分判断
                    -- if oneRingsData > CombatPlanManager.CalPlanPowerByProperty(curRingsData[5].bData.property) then
                    --    -- betterRingsState["Rings1"] = true
                    --     --Log("一号戒指有更好的"..oneRingsData)
                    -- else
                    --     betterRingsState["Rings1"] = false
                    --     --Log("一号戒指就是最好的".. CombatPlanManager.CalPlanPowerByProperty(curRingsData[5].bData.property))
                    -- end
                end 
            end
     
            if rings2IsUnlock then
                --比较二号戒指是不是有更好的替代品
                if curRingsData[6] == nil then
                    betterRingsState["Rings2"] = true
                    --Log("二号戒指解锁了但是没装备")
                else
                     --注释戒指二号评分判断
                    -- if oneRingsData > CombatPlanManager.CalPlanPowerByProperty(curRingsData[6].bData.property) then
                    --     betterRingsState["Rings2"] = true
                    --     --Log("二号戒指有更好的"..oneRingsData)
                    -- else
                    --     betterRingsState["Rings2"] = false
                    --     --Log("二号戒指就是最好的".. CombatPlanManager.CalPlanPowerByProperty(curRingsData[6].bData.property))
                    -- end
                end
            end
        --背包全部装备的评价
        --Log('全部未装备戒指的评价：' .. CombatPlanManager.CalPlanPowerByProperty(allRingsData[i].property))
    end

    --Log("Rings1==>".. tostring(betterRingsState["Rings1"]))
    --Log("Rings2==>".. tostring(betterRingsState["Rings2"]))
    --Log("=================================")

    --获取当前穿戴戒指的评分
    -- if curRingsData[5] ~= nil then
    --    --Log("1号戒指当前的评分是：".. CombatPlanManager.CalPlanPowerByProperty(curRingsData[5].bData.property))
    -- end
    -- if curRingsData[6] ~= nil then
    --    --Log("2号戒指当前的评分是：".. CombatPlanManager.CalPlanPowerByProperty(curRingsData[6].bData.property))
    -- end

    --这里处理一定要！！！注意！！！，三个前提，1.戒指都解锁了，2.背包有至少一个戒指，3.没有装备戒指
    if rings1IsUnlock and rings2IsUnlock and (curRingsData[5]==nil or curRingsData[6]==nil) and #allRingsData>1 then
        --Log("戒指都解锁了，背包有戒指，但是没装备任何戒指")
        return true,betterRingsState
    elseif hasBetterRings then
        --Log("有更好的戒指")
        return true,betterRingsState
    elseif rings1IsUnlock and rings2IsUnlock then
        --Log("戒指都解锁了，背包没有戒指")
        return true,betterRingsState
    end
end
--单个英雄所有红点判断
function this.GetCurHeroIsShowRedPoint(curHeroData)
    if curHeroData.heroConfig.Material == 1 then
        return false
    end
    -- return false
    hasBetterRings1, betterRingsState1 = this.GetRingsIsShowRedPoin(curHeroData)
    if betterRingsState1 ~= nil then
        return this.GetCurHeroUpLvOrUpStarSData(curHeroData) or
            this.LvUpBtnRedPoint(curHeroData) or
            this.IsShowUpStarRedPoint(curHeroData) or
            #this.GetHeroIsUpEquip(curHeroData.dynamicId) > 0 or
            this.GetIsShowSoulPrintRedPoint(curHeroData) or
            this.GetIsShowTalismanRedPoint(curHeroData) or 
            this.GetCurHeroAbilityIsShowRedPoint(curHeroData)["ability1"] or  this.GetCurHeroAbilityIsShowRedPoint(curHeroData)["ability2"] or
            (betterRingsState1["Rings1"] or betterRingsState1["Rings2"])
    end
    return this.GetCurHeroUpLvOrUpStarSData(curHeroData) or 
        this.LvUpBtnRedPoint(curHeroData) or
        this.IsShowUpStarRedPoint(curHeroData) or
        #this.GetHeroIsUpEquip(curHeroData.dynamicId) > 0 or
        this.GetIsShowSoulPrintRedPoint(curHeroData) or
        this.GetIsShowTalismanRedPoint(curHeroData) or 
        this.GetCurHeroAbilityIsShowRedPoint(curHeroData)["ability1"] or  this.GetCurHeroAbilityIsShowRedPoint(curHeroData)["ability2"]
end

--单个英雄所有红点判断,去掉装备红点判断
function this.GetIsHeroAlternativeRedPoint(curHeroData)
    if curHeroData.heroConfig.Material == 1 then
        return false
    end
    -- return false
    hasBetterRings1, betterRingsState1 = this.GetRingsIsShowRedPoin(curHeroData)
    if betterRingsState1 ~= nil then
        return this.GetCurHeroUpLvOrUpStarSData(curHeroData) or
            this.LvUpBtnRedPoint(curHeroData) or
            this.IsShowUpStarRedPoint(curHeroData) or
            this.GetIsShowSoulPrintRedPoint(curHeroData) or
            this.GetIsShowTalismanRedPoint(curHeroData) or 
            this.GetCurHeroAbilityIsShowRedPoint(curHeroData)["ability1"] or  this.GetCurHeroAbilityIsShowRedPoint(curHeroData)["ability2"] or
            (betterRingsState1["Rings1"] or betterRingsState1["Rings2"])
    end
    return this.GetCurHeroUpLvOrUpStarSData(curHeroData) or 
        this.LvUpBtnRedPoint(curHeroData) or
        this.IsShowUpStarRedPoint(curHeroData) or
        this.GetIsShowSoulPrintRedPoint(curHeroData) or
        this.GetIsShowTalismanRedPoint(curHeroData) or 
        this.GetCurHeroAbilityIsShowRedPoint(curHeroData)["ability1"] or  this.GetCurHeroAbilityIsShowRedPoint(curHeroData)["ability2"]
end


--获取当前英雄的下一突破 和 升星 静态数据
function this.GetCurHeroUpLvOrUpStarSData(curHeroData)
    isHeroUpTuPo = false
    isHeroUpStar = false
    upTuPoRankUpConfig = {}
    upStarRankUpConfig = {}

    if curHeroData == nil then  -- 线上红点问题  +空判断
        return
    end
    for i, v in ConfigPairs(heroRankUpConfig) do
        if v.Star == curHeroData.heroConfig.Star then --初始星级相等
            if v.Show == 1 then -- 1 突破
                if v.Id ~= curHeroData.breakId and curHeroData.lv == v.LimitLevel then --and curHeroData.star == v.LimitStar
                    isHeroUpTuPo = true
                    upTuPoRankUpConfig = v
                end
            end
            if v.Show == 2 then --  2 升星
                if v.Id ~= curHeroData.upStarId and curHeroData.star == v.LimitStar and curHeroData.star < curHeroData.heroConfig.MaxRank then
                    upStarRankUpConfig = v
                    isHeroUpStar = true
                end
            end
        end
    end
end
--单个英雄升级红点
function this.LvUpBtnRedPoint(curHeroData)
    HeroManager.GetCurHeroUpLvOrUpStarSData(curHeroData)

    --是否为最大等级
    if curHeroData.lv >= HeroManager.heroLvEnd[curHeroData.heroConfig.Id] then
        return false
    end
    local curTuPoRankUpConfig = heroRankupConfig[curHeroData.breakId]
    local curStarRankUpConfig = heroRankupConfig[curHeroData.upStarId]
    local isUpLvMaterials = true
    local costItemList = {}
    if isHeroUpTuPo and upTuPoRankUpConfig and curHeroData.lv == upTuPoRankUpConfig.LimitLevel then
        costItemList = upTuPoRankUpConfig.ConsumeMaterial
    else
        costItemList = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv).Consume
    end
    for i = 1, #costItemList do
        if BagManager.GetItemCountById(costItemList[i][1]) < costItemList[i][2] then
            isUpLvMaterials = false
        end
    end
    --如果此时需要进阶 每次都要跳转
    if isHeroUpStar and upStarRankUpConfig and curTuPoRankUpConfig and curTuPoRankUpConfig.JudgeClass == 1 and
            curHeroData.lv >= curTuPoRankUpConfig.OpenLevel then --当前突破全部完成
        if curStarRankUpConfig then --进阶过处理
            if curHeroData.lv == curStarRankUpConfig.OpenLevel then
                return false
            else
                if isUpLvMaterials then
                    return true
                else
                    return false
                end
            end
        else --从未进阶过处理
            return false
        end
    else
        if isUpLvMaterials then
            return true
        else
            return false
        end
    end
    return false
end
--单个英雄升星红点
function this.IsShowUpStarRedPoint(curHeroData)
    HeroManager.GetCurHeroUpLvOrUpStarSData(curHeroData)
    if curHeroData.lv >= HeroManager.heroLvEnd[curHeroData.heroConfig.Id] then
        return false
    --培养已满
    end
    if upStarRankUpConfig and upStarRankUpConfig.LimitLevel then
        if curHeroData.lv < upStarRankUpConfig.LimitLevel then
            return false
        --等级不够
        end
    else
        --不能升星
        return false
    end
    if upStarRankUpConfig then
        local ConsumeMaterial = upStarRankUpConfig.ConsumeMaterial
        for i = 1, #ConsumeMaterial do
            --> todo
            if ConsumeMaterial[i][2] and ConsumeMaterial[i][2] > 0 then
                if BagManager.GetItemCountById(ConsumeMaterial[i][1]) < ConsumeMaterial[i][2] then
                    return false
                --材料不足
                end
            end
        end
    end
    local upStarConsumeMaterial = {}
    local upStarMaterialIsAll = {}
    local curUpStarData = HeroManager.GetHeroCurUpStarInfo(curHeroData.dynamicId)
    if curUpStarData and #curUpStarData > 0 then
        for i = 1, #curUpStarData do
            local curSelectUpStarData = curUpStarData[i]
            local upStarHeroListData =
                HeroManager.GetUpStarHeroListData(curSelectUpStarData.upStarMaterialsData.Id, curHeroData)
            local curSelectHeroList = {}
            --if curSelectUpStarData.upStarMaterialsData.Issame ==1 or curSelectUpStarData.upStarMaterialsData.IsId > 0 then
            upStarMaterialIsAll[curSelectUpStarData.upStarData[2]] = 2
            if #upStarHeroListData.heroList >= curSelectUpStarData.upStarData[4] then
                for j = 1, #upStarHeroListData.heroList do
                    if
                        upStarHeroListData.heroList[j].lockState == 0 and
                            upStarHeroListData.heroList[j].isFormation == "" and
                            #curSelectHeroList < curSelectUpStarData.upStarData[4] and
                            not upStarConsumeMaterial[upStarHeroListData.heroList[j].dynamicId]
                     then
                        table.insert(curSelectHeroList, upStarHeroListData.heroList[j])
                    end
                end
                if LengthOfTable(curSelectHeroList) >= curSelectUpStarData.upStarData[4] then
                    upStarMaterialIsAll[curSelectUpStarData.upStarData[2]] = 1
                end
                for _i, v in pairs(curSelectHeroList) do
                    upStarConsumeMaterial[v.dynamicId] = v.dynamicId
                end
            end
            --end
        end
    end
    -- 消耗位置材料状态
    for i = 1, #upStarMaterialIsAll do
        if upStarMaterialIsAll[i] == 2 then
            return false
        end
    end
    return true
end
--单个英雄装备红点  --检测单个英雄是否有可穿的装备
function this.GetHeroIsUpEquip(heroDid)
    if heroDatas[heroDid] then
        local heroData = heroDatas[heroDid]
        local lackEquips = {}
        --六个装备位
        for i = 1, 6 do
            local equipIdAndWarPower = {}
            equipIdAndWarPower.pos = i
            equipIdAndWarPower.id = 0
            equipIdAndWarPower.warPower = 0
            lackEquips[i] = equipIdAndWarPower
        end

        -- 有装备的位置赋值装备id及战力
        if heroData.equipIdList and #heroData.equipIdList > 1 then
            for i = 1, #heroData.equipIdList do
                if not heroData.equipIdList[i] then
                else
                    local curEquipConFigData =
                        EquipManager.GetSingleHeroSingleEquipData(heroData.equipIdList[i], heroDid)
                    if not curEquipConFigData then
                        
                    else
                        lackEquips[curEquipConFigData.equipConfig.Position].id = heroData.equipIdList[i]
                        lackEquips[curEquipConFigData.equipConfig.Position].warPower =
                            EquipManager.CalculateWarForce(heroData.equipIdList[i])
                    end
                end
            end
        end

        --有同系  且未在英雄身上的装备
        local equips = BagManager.GetEquipDataByEquipPosition(heroData.heroConfig.Profession)

        for _, v in ipairs(equips) do
            if EquipManager.GetSingleHeroSingleEquipData(v.id, heroDid) then
                --英雄已经装备了这个装备
            else
                local equipConfigData = equipConfig[v.id]
                local pos = equipConfigData.Position
                --比较战力 高战力的装备add
                if lackEquips[pos].pos == equipConfigData.Position then
                    if lackEquips[pos].id == 0 then
                        lackEquips[pos].id = v.id
                        lackEquips[pos].warPower = EquipManager.CalculateWarForce(v.id)
                    else
                        local nextEquipWarPower = EquipManager.CalculateWarForce(v.id)
                        if nextEquipWarPower > lackEquips[pos].warPower then
                            lackEquips[pos].id = v.id
                            lackEquips[pos].warPower = EquipManager.CalculateWarForce(v.id)
                        end
                    end
                end
            end
        end

        --去掉与自己本身自带的重合装备
        local allUpEquipDidTabs = {}
        for i = 1, #lackEquips do
            if lackEquips[i].id ~= 0 then
                local isAdd = true
                for j = 1, #heroData.equipIdList do
                    if tonumber(heroData.equipIdList[j]) == tonumber(lackEquips[i].id) then
                        isAdd = false
                    end
                end
                if isAdd then
                    table.insert(allUpEquipDidTabs, lackEquips[i].id)
                end
            end
        end
        if #allUpEquipDidTabs > 0 then
            return allUpEquipDidTabs
        end
        return {}
    end
    return {}
end
--单个英雄魂印红点
--获取魂印环形布局数据  didMaxLen最大槽位数量 didLen可装备槽位数量 didLv最大动态等级 maxLv配置最大等级
function this.GetSoulPrintLoopUIMaxData()
    local d = string.split(ConfigManager.GetConfigData(ConfigName.SpecialConfig, 37).Value, "#")
    local _d = {}
    for n = 1, #d do
        local v = d[n]
        if PlayerManager.level >= tonumber(v) then
            table.insert(_d, v)
        end
    end
    --当前动态最大等级
    local didLv = 0
    --最大槽位数量
    local didMaxLen = 0
    --可装备槽位数量（与是否装备英雄无关）
    local didLen = 0
    if #_d < #d then --未达到最大等级 +1显示锁定
        didMaxLen = #_d + 1
    else
        didMaxLen = #_d
    end
    didLv = tonumber(d[didMaxLen])
    didLen = #_d
    local maxLv = tonumber(d[#d])

    return didMaxLen, didLen, didLv, maxLv
end
function this.GetIsShowSoulPrintRedPoint(curHeroData)
    local soulPrintIsOpen = SoulPrintManager.GetSoulPrintIsOpen(curHeroData)
    if not soulPrintIsOpen then
        return false
    end
    local didMaxLen, didLen, didLv, maxLv = this.GetSoulPrintLoopUIMaxData()
    if curHeroData.soulPrintList and #curHeroData.soulPrintList >= didLen then
        return false --空位置 已装满
    end
    local allUpSoulPrint = {}
    if curHeroData.soulPrintList then
        for i = 1, #curHeroData.soulPrintList do
            allUpSoulPrint[curHeroData.soulPrintList[i].equipId] = curHeroData.soulPrintList[i]
        end
    end
    local allBagSoulPrintData = BagManager.GetBagItemDataByItemType(ItemBaseType.SoulPrint)
    for i = 1, #allBagSoulPrintData do
        if not allUpSoulPrint[allBagSoulPrintData[i].id] and equipConfig[allBagSoulPrintData[i].id].Range[1] == 0 then
            return true
        --有空位可以穿戴
        end
        local isHaveCurHeroid = false
        for j = 1, #equipConfig[allBagSoulPrintData[i].id].Range do
            local heroId = equipConfig[allBagSoulPrintData[i].id].Range[j]
            if curHeroData.id == heroId then
                isHaveCurHeroid = true
            end
        end
        if not allUpSoulPrint[allBagSoulPrintData[i].id] and isHaveCurHeroid then
            return true
        --有空位可以穿戴
        end
    end
    return false
end
--单个英雄法宝红点
function this.GetIsShowTalismanRedPoint(curHeroData)
    local isOpen = TalismanManager.GetCurHeroIsOpenTalisman(curHeroData)
    if not isOpen then
        return false
    --功能未开启
    end
    local equipTalismana = ConfigManager.GetConfigData(ConfigName.HeroConfig, curHeroData.id).EquipTalismana
    --当前法宝数据 data[1]星级 data[2]法宝ID
    if not equipTalismana then
        return false
    end
    --获取最大等级
    TalismanManager.GetStartAndEndStar()
    local maxLv = TalismanManager.AllTalismanEndStar[equipTalismana[2]]
    --获取当前法宝等级
    local curLv = HeroManager.GetTalismanLv(curHeroData.dynamicId)
    --获取当前等级与下一等级表数据
    local nextLv = 0
    if (curLv + 1) <= maxLv then
        nextLv = curLv + 1
    end
    local isMaxStar = curLv >= maxLv
    if isMaxStar then
        return false --已满级
    end
    local curTalismanConFig =
        ConfigManager.GetConfigDataByDoubleKey(
        ConfigName.EquipTalismana,
        "Level",
        curLv,
        "TalismanaId",
        equipTalismana[2]
    )
    --local nextTalismanConFig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana, "TalismanaId",  equipTalismana[2], "Level", nextLv)
    --需要判断材料够不够
    for i = 1, #curTalismanConFig.RankupBasicMaterial do
        local needNum = curTalismanConFig.RankupBasicMaterial[i][2]
        --需要物品数量
        local haveNum = BagManager.GetItemCountById(curTalismanConFig.RankupBasicMaterial[i][1])
        --已有物品数量
        if haveNum < needNum then
            return false
        --材料不足
        end
    end
    return true
end

function this.ResetHero(dynamicloadId)
    if heroDatas[dynamicloadId] then
        heroDatas[dynamicloadId].lv = 1
        heroDatas[dynamicloadId].breakId = 0
    end
end

--神将合成
function this.ByCompoundHeroGetAllHeros()
    local upSortHeroList = {}
    local downSoryHeroList = {}
    for i, v in pairs(heroDatas) do
        if v.star == 4 or v.star == 5  or v.star == 3 then--四星  五星 才能加  3星 是狗粮
            if LengthOfTable(v.formationList)  ~= 0 then
                local text = ""
                for index, value in pairs(v.formationList) do
                    text = HeroManager.GetHeroFormationStr(value)
                end
                v.isFormation = text
            end
            table.insert(upSortHeroList,v)
            table.insert(downSoryHeroList,v)    
        end
    end
    table.sort(downSoryHeroList, function(a,b)
        if a.star == b.star then
            if a.lv == b.lv then
                return a.heroConfig.Id < b.heroConfig.Id
            else
                return a.lv > b.lv
            end
        else
            return a.star > b.star
        end
    end)
    table.sort(upSortHeroList, function(a,b)
        if a.star == b.star then
            if a.lv == b.lv then
                return a.heroConfig.Id > b.heroConfig.Id
            else
                return a.lv < b.lv
            end
        else
            return a.star < b.star
        end
    end)
    return upSortHeroList,downSoryHeroList
end
--神将置换
function this.ByReplaceHeroGetAllHeros()
    local sortHeroList = {}
    for i, v in pairs(heroDatas) do
        if v.star == 4 or v.star == 5 then--四星  五星
            v.isFormation = "" 
            --筛选
            local teamIdList = HeroManager.GetAllFormationByHeroId(v.dynamicId)
            local isOK = true
            if teamIdList ~= nil and #teamIdList > 0 then
                for k, v in pairs(teamIdList)do
                    if v == FormationTypeDef.DEFENSE_TRAINING and DefenseTrainingManager.teamLock == 1 then
                        isOK = false
                        --table.removebyvalue(sortHeroList, n)
                        break
                    end
                     --防守训练
                    -- if v == FormationTypeDef.FORMATION_DREAMLAND or v == FormationTypeDef.FORMATION_AoLiaoer then
                    --     isOK = true
                    --     --table.removebyvalue(sortHeroList, n)
                    --     break
                    -- end
                end
            end
            -- if isOK == true then
                table.insert(sortHeroList,v)
            -- end
        end
    end
     --标记编队上的英雄
     if sortHeroList and LengthOfTable(sortHeroList) > 0 then
        for i, v in pairs(sortHeroList) do
            local isFormations = {}
            for n, w in pairs(FormationManager.formationList) do
                for m = 1, #w.teamHeroInfos do
                    if w.teamHeroInfos[m] and v.dynamicId == w.teamHeroInfos[m].heroId then
                        --队伍名称  队伍id
                        local isFormationStr = ""
                        local curFormationId = 0
                        local temp = this.GetHeroFormationStr2(n)
                        if temp and temp ~= "" then
                            if sortHeroList[i].isFormation and sortHeroList[i].isFormation == "" then
                                isFormationStr, curFormationId = this.GetHeroFormationStr2(n)
                                table.insert(isFormations, curFormationId)
                            else
                                isFormationStr, curFormationId = this.GetHeroFormationStr2(n)
                                isFormationStr = "、" ..isFormationStr
                                table.insert(isFormations, curFormationId)
                            end
                            sortHeroList[i].isFormation = sortHeroList[i].isFormation .. isFormationStr
                        end
                    end
                end
            end
            --所有的所在队伍id，
            sortHeroList[i].isFormations = isFormations
        end
    end
    --筛选
    -- if sortHeroList and LengthOfTable(sortHeroList) > 0 then
    --     for i, n in pairs(sortHeroList) do
    --         local isLock = false
    --         local teamIdList = HeroManager.GetAllFormationByHeroId(n.dynamicId)
    --         if teamIdList ~= nil and #teamIdList > 0 then
    --             for k,v in pairs(teamIdList)do
    --                 if v == FormationTypeDef.DEFENSE_TRAINING and DefenseTrainingManager.teamLock == 1 then
    --                     isLock = true
    --                     table.removebyvalue(sortHeroList, n)
    --                     break
    --                 end
    --                  --防守训练
    --                 if v == FormationTypeDef.FORMATION_DREAMLAND or v == FormationTypeDef.FORMATION_AoLiaoer then
    --                     isLock = true
    --                     table.removebyvalue(sortHeroList, n)
    --                     break
    --                 end
    --             end
    --         end
    --     end
    -- end
    table.sort(sortHeroList, function(a,b)
        if a.star == b.star then
            if a.lv == b.lv then
                return a.heroConfig.Id > b.heroConfig.Id
            else
                return a.lv < b.lv
            end
        else
            return a.star > b.star
        end
    end)
    return sortHeroList
end
--修改神将changeId （1是增加/修改 0是恢复默认值0）
function this.ResetHeroChangeId(dynamicloadId,changeId)
    if heroDatas[dynamicloadId] then
        if changeId then
            heroDatas[dynamicloadId].changeId = changeId
        else
            heroDatas[dynamicloadId].changeId = 0
        end
    end
end

--计算敌人被动技能的属性值 主要是为团体
local function CalculateMonsterPassiveSkillProAddVal(heroData, _breakId, _upStarId, teamCurPropertyName)
    local singleHeroProVal, lvProVal, allHeroProVal, specialProVal
    if heroData then
        local allOpenPassiveSkillIds = {}
        allOpenPassiveSkillIds = this.GetAllPassiveSkillIds(heroData, _breakId, _upStarId)
        --单体加成  --单体等级限制加成  --团体加成  --减乘
        singleHeroProVal, lvProVal, allHeroProVal, specialProVal =
            this.CalculatePassiveSkillsValList(WarPowerType.Hero, allOpenPassiveSkillIds, heroData.PropertyName)
    end
    return singleHeroProVal, lvProVal, allHeroProVal, specialProVal
end

--计算敌人战力 (_breakId, _upStarId 加成的暂时留着 如果敌人基础属性没加这个 还需要算进去)
function this.CalculateMonsterAllProValList(enemyIdList, _breakId, _upStarId)
    local _breakId = _breakId or 0
    local _upStarId = _upStarId or 0
    if enemyIdList == nil or next(enemyIdList) == nil then
        LogError("monster power nil")
        return 0
    end
    local totalPower = 0

    -- 光环团体add
    local elementPropertyNameList = {}
    for k, v in ipairs(enemyIdList) do
        local monsterData = monsterConfig[v]
        if monsterData == nil then
            LogError(string.format("monsterid not find   %d", v))
            return 0
        end
        local heroData = heroConfig[monsterData.MonsterId]
        table.insert(elementPropertyNameList, heroData.PropertyName)
    end

    for k, v in ipairs(enemyIdList) do
        local monsterData = monsterConfig[v]
        local heroData = heroConfig[monsterData.MonsterId]
        local curLvNum = monsterData.Level

        local allAddProVal = {}
        for i, v in ConfigPairs(propertyConfig) do
            allAddProVal[i] = 0
        end
        --单体所有属性加成
        local lvProVal = {}
        --100等级所有属性加成 升一级 加一次
        local allHeroProVal = {}
        --团体所有属性加成
        local specialProVal = {}
        --减乘

        --英雄被动技能属性加成
        local heroSkillSingleHeroProVal, heroSkillLvProVal, heroSkillAllHeroProVal, heroSkillSpecialProVal = {}, {}, {}, {}
        heroSkillSingleHeroProVal, heroSkillLvProVal, heroSkillAllHeroProVal, heroSkillSpecialProVal =
            CalculateMonsterPassiveSkillProAddVal(heroData, _breakId, _upStarId)

        --编队光环加成
        local teamAddPro = FormationManager.GetCurFormationElementAddByPropertyNameList(elementPropertyNameList)
        --单体所有属性合并
        this.DoubleTableCompound(allAddProVal, heroSkillSingleHeroProVal)
        --100等级所有属性合并
        this.DoubleTableCompound(lvProVal, heroSkillLvProVal)
        --团体所有属性合并
        this.DoubleTableCompound(allHeroProVal, heroSkillAllHeroProVal)
        this.DoubleTableCompound(allHeroProVal, teamAddPro)
        --4公式特殊（减乘）所有属性加成
        this.DoubleTableCompound(specialProVal, heroSkillSpecialProVal)


        --100等级所有属性合并
        local forNum = curLvNum - 100
        if forNum > 0 then
            for k = 1, forNum do
                this.DoubleTableCompound(allAddProVal, lvProVal)
            end
        end
        --团体所有属性合并
        this.DoubleTableCompound(allAddProVal, allHeroProVal)

        allAddProVal[HeroProType.Attack] =
            this.CalculateProVal(heroData.Attack, curLvNum, _breakId, _upStarId, HeroProType.Attack,heroData,curHeroData.star) +
            allAddProVal[HeroProType.Attack]
        allAddProVal[HeroProType.Hp] =
            this.CalculateProVal(heroData.Hp, curLvNum, _breakId, _upStarId, HeroProType.Hp,heroData,curHeroData.star) +
            allAddProVal[HeroProType.Hp]
        allAddProVal[HeroProType.PhysicalDefence] =
            this.CalculateProVal(heroData.PhysicalDefence, curLvNum, _breakId, _upStarId, HeroProType.PhysicalDefence,heroData,curHeroData.star) +
            allAddProVal[HeroProType.PhysicalDefence]
        -- allAddProVal[HeroProType.MagicDefence] =
            -- this.CalculateProVal(heroData.MagicDefence, curLvNum, _breakId, _upStarId, HeroProType.MagicDefence,heroData) +
            -- allAddProVal[HeroProType.MagicDefence]

        --最后计算战斗力
        allAddProVal[HeroProType.WarPower] = CalculateWarForce(allAddProVal)

        totalPower = totalPower + allAddProVal[HeroProType.WarPower]
    end

    return totalPower
end

--更新战法数据 穿 卸
function HeroManager.UpdateWarWayData(tankDId, slot, warWayId, isOn)
    local heroData = this.GetSingleHeroData(tankDId)
    if heroData then
        if isOn then
            heroData[string.format("warWaySlot%dId", slot)] = warWayId
        else
            heroData[string.format("warWaySlot%dId", slot)] = 0
        end
    else
        LogError("### UpdateWarWayData data nil")
    end
end

HeroDownDataType = {
    EQUIP           = 1,
    WARWAY          = 2,
}
--清除client本地英雄身上 类型数据(all)
function HeroManager.UpdateHeroDownData(type, dynamicId,spe)
    if heroDatas[dynamicId] then
        if HeroDownDataType.EQUIP == type then
            local equips = heroDatas[dynamicId].equipIdList
            if equips and #equips > 0 then
                for i = 1, #equips do
                    EquipManager.DeleteSingleEquip(equips[i], dynamicId)
                end
            end
            heroDatas[dynamicId].equipIdList = {}
        elseif HeroDownDataType.WARWAY == type then
            if spe==1 then
                heroDatas[dynamicId].warWaySlot1Id = 0
                return
            elseif spe==2 then
                heroDatas[dynamicId].warWaySlot2Id = 0
                return
            end
            heroDatas[dynamicId].warWaySlot1Id = 0
            heroDatas[dynamicId].warWaySlot2Id = 0
        end
    else
        LogError("### UpdateHeroDownData dynamicId Not Exist!!!")
    end
end

--通用英雄排序
function HeroManager.SortHeroData(_heroDatas, sortType)
    local sortType = sortType or SortTypeConst.Lv
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_heroDatas, function(a, b)
        if sortType == SortTypeConst.Lv then
            if a.lv == b.lv then
                if a.heroConfig.Quality == b.heroConfig.Quality then--Natural
                    if a.star == b.star then
                        if a.warPower == b.warPower then
                            if a.heroConfig.Natural == b.heroConfig.Natural then--Natural
                                return a.heroConfig.Id < b.heroConfig.Id
                            else
                                return a.heroConfig.Natural > b.heroConfig.Natural
                            end
                        else
                            return a.warPower > b.warPower
                        end
                    else
                        return a.star > b.star
                    end
                else
                    return a.heroConfig.Quality > b.heroConfig.Quality
                end
            else
                return a.lv > b.lv
            end
        elseif sortType == SortTypeConst.Natural then
            if a.heroConfig.Quality == b.heroConfig.Quality then--Natural
                if a.star == b.star then
                    if a.lv == b.lv then
                        if a.warPower == b.warPower then
                            if a.heroConfig.Natural == b.heroConfig.Natural then--Natural
                                return a.heroConfig.Id < b.heroConfig.Id
                            else
                                return a.heroConfig.Natural > b.heroConfig.Natural
                            end
                        else
                            return a.warPower > b.warPower
                        end
                    else
                        return a.lv > b.lv
                    end
                else
                    return a.star > b.star
                end
            else
                return a.heroConfig.Quality > b.heroConfig.Quality
            end
        end
    end)
end

--获取本地英雄最高战力
function HeroManager.GetHerosMaxPower()
    local max = 0
    for k, v in pairs(heroDatas) do
        if v and v.warPower then
            max = math.max(max, v.warPower)
        end
    end
    return max
end

--设置天赋数据
function HeroManager.SetHeroTalentData(heroData, msg)
    heroData.talent = {}
    for k, v in ipairs(msg.positionSkills) do
        local a = {}
        a.skillId = v.skillId
        a.position = v.position
        heroData.talent[a.position] = a
    end
end

--设置部件数据
function HeroManager.SetHeroPartsData(partsData, unlockData, heroData)
    if unlockData and #unlockData > 0 then
        for i = 1, #unlockData do
            --> isUnLock -1未解锁，0已解锁，>0已升级       actualLv 实际应用等级
            partsData[unlockData[i].position] = {position = unlockData[i].position, isUnLock = unlockData[i].isUnLock, actualLv = 0}
        end

        this.UpdateHeroPartsData(heroData)
    end
end
--更新部件数据 主装备变动更新
function HeroManager.UpdateHeroPartsData(heroData)
    local partsData = heroData.partsData
    for i = 1, #partsData do
        partsData[i].actualLv = 0
    end
    for i = 1, #heroData.equipIdList do
        local equipId = heroData.equipIdList[i]
        local equipConfig = G_EquipConfig[tonumber(equipId)]
        if partsData[equipConfig.Position] then
            if partsData[equipConfig.Position].isUnLock > 0 then
                if equipConfig.IfAdjust == 1 then
                    partsData[equipConfig.Position].actualLv = math.min(partsData[equipConfig.Position].isUnLock, equipConfig.Adjustlimit)
                end
            end
        end
    end
end
--获取技能ids 按顺序  (注：目前只有主动有槽位 被动无槽位 如果按技能id区分倒数第二位 或直接顺序走) 去掉普攻
function HeroManager.GetHeroSkillSortList(heroData)
    local skillAList = HeroManager.GetSkillIdsByHeroRulesRole(heroData.heroConfig.OpenSkillRules, heroData.star, heroData.breakId, heroData)
    local skillBList = HeroManager.GetPassiveSkillIdsByHeroRuleslock(heroData.heroConfig.OpenPassiveSkillRules, heroData.star, heroData.breakId, heroData)
    for key, value in pairs(skillBList) do
        table.insert(skillAList, value)
    end
    table.sort(skillAList, function(a, b) 
        return a.skillConfig.Id < b.skillConfig.Id
    end)
    table.remove(skillAList, 1)
    return skillAList
end
--部件解锁设值 解锁 重置
function HeroManager.PartsSetUnlockValue(heroData, position)
    if heroData.partsData and heroData.partsData[position] then
        heroData.partsData[position].isUnLock = 0
        this.UpdateHeroPartsData(heroData)
    end
end
--部件升级设值
function HeroManager.PartsSetLvUpValue(heroData, position)
    if heroData.partsData and heroData.partsData[position] then
        heroData.partsData[position].isUnLock = heroData.partsData[position].isUnLock + 1
        this.UpdateHeroPartsData(heroData)
    end
end
--部件获取表数据 by level
function HeroManager.GetPartsConfigData(level)
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.AdjustConfig)) do
        if configInfo["Id"] ~= 1 and configInfo["Level"] == level then
            return configInfo
        end
    end
    LogError("GetPartsConfigData error!")
    return nil
end

--判断是否有能力技能
function this.IsCompetencySkills()
    local list =WarWaySkillUpgradeCost

    if list then
        for _, v in pairs(list) do   
            local itemid = v.UpgradeCost[1][1]
            local itemnum = v.UpgradeCost[1][2]
            local ownNum = BagManager.GetItemCountById(itemid)
            if ownNum >= itemnum then
                return true
            end
        end
    end
    return false
end


return this