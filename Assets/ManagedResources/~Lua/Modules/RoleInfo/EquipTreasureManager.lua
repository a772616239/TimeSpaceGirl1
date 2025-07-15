EquipTreasureManager = {}
local this = EquipTreasureManager
local allTreasures = {}
local jewelConfig = ConfigManager.GetConfig(ConfigName.JewelConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local jewerLevelUpConfig = ConfigManager.GetConfig(ConfigName.JewelRankupConfig)
function this.Initialize()
end
--初始化所有宝器数据
function this.InitAllEquipTreasure(_equipData)
    if _equipData == nil then
        return
    end
    for i = 1, #_equipData do
        this.InitSingleTreasureData(_equipData[i])
    end
end
--初始化单个宝物的数据
function this.InitSingleTreasureData(_singleData)
    if _singleData == nil then
        return
    end
    local single = {}
    local staticId = _singleData.equipId
    local currJewel = jewelConfig[staticId]
    single.id = staticId
    single.idDyn = _singleData.id
    single.lv = _singleData.exp
    single.refineLv = _singleData.rebuildLevel
    single.maxLv = currJewel.Max[1]
    single.maxRefineLv = currJewel.Max[2]
    single.upHeroDid = ""
    local quantity = currJewel.Level
    single.quantity = quantity
    single.race = currJewel.Race
    single.frame = GetQuantityImageByquality(quantity)
    single.name = itemConfig[staticId].Name
    single.itemConfig = itemConfig[staticId]
    single.levelPool = currJewel.LevelupPool
    single.proIcon = GetProStrImageByProNum(currJewel.Race)
    single.refinePool = currJewel.RankupPool
    single.equipType = currJewel.Location
    if currJewel.Location == 1 then
        single.type = GetLanguageStrById(10505)
    else
        single.type = GetLanguageStrById(10506)
    end
    single.icon = GetResourcePath(itemConfig[staticId].ResourceID)
    single.strongConfig = this.GetCurrTreasureLvConfig(1, currJewel.LevelupPool, _singleData.exp)
    single.refineConfig = this.GetCurrTreasureLvConfig(2, currJewel.RankupPool, _singleData.rebuildLevel)
    allTreasures[_singleData.id] = single
    
    
end
--获取玩家可以穿戴的宝物
function this.GetTreasureDataByPos(_pos, _idDyn, PropertyName)
    local equips = {}
    for i, v in pairs(allTreasures) do
        if v.equipType == _pos - 4 then
            if (v.upHeroDid == "" or v.upHeroDid == _idDyn) and v.race == PropertyName then
                table.insert(equips, v)
            end
        end
    end
    return equips
end

function this.OpenTreasure(star)
    local config = ConfigManager.GetConfigData(40)
    local configs = string.split(config.Value, "|")
    for i = 1, #configs do
        if string.split(configs[i], "#")[1] == 1 then --玩家等级
            return PlayerManager.level >= string.split(configs[i], "#")[2]
        end
        if string.split(configs[i], "#")[2] and string.split(configs[i], "#")[2] == 2 then --英雄星级
            return star >= string.split(configs[i], "#")[2]
        end
    end
end

--获取当前宝物升级数据
function this.GetCurrTreasureLvConfig(_type, _id, _lv)
    for _, configInfo in ConfigPairs(jewerLevelUpConfig) do
        if configInfo.Type == _type and configInfo.PoolID == _id and configInfo.Level == _lv then
            return configInfo
        end
    end
end

--获取当前等级的基础属性/精炼属性
function this.GetCurrLvAndNextLvPropertyValue(_type, _id, _lv)
    local lvConfig = nil
    local nexLvConfig = nil
    --获取当前等级属性加成
    for _, configInfo in ConfigPairs(jewerLevelUpConfig) do
        if configInfo.Type == _type and configInfo.PoolID == _id and configInfo.Level == _lv then
            lvConfig = configInfo
            break
        end
    end
    --获取下一等级属性加成
    local nextLv = _lv + 1
    for _, configInfo in ConfigPairs(jewerLevelUpConfig) do
        if configInfo.Type == _type and configInfo.PoolID == _id and configInfo.Level == nextLv then
            nexLvConfig = configInfo
            break
        end
    end
    local proList = {}
    if lvConfig then
        for i = 1, table.getn(lvConfig.Property) do
            local info = lvConfig.Property[i]
            if info then
                local index = info[1]
                local skillValue = {}
                skillValue.currValue = info[2]
                proList[index] = skillValue
            end
        end
    end
    --没有下一等级数据为已升到最高级
    if nexLvConfig then
        --最高级显示
        for i = 1, table.getn(nexLvConfig.Property) do
            local info = nexLvConfig.Property[i]
            if info then
                if proList[info[1]] then
                    proList[info[1]].nextValue = info[2]
                else
                    local skillValue = {}
                    skillValue.currValue = info[2]
                    proList[info[1]] = skillValue
                end
            end
        end
    else
        for i, v in pairs(proList) do
            proList[i].nextValue = proList[i].currValue
        end
    end
    return proList
end

--根据属性类型获取所有类型的表数据
function this.GetAllTabletTreasuresByRace(_index)
    if jewelConfig == nil then
        return
    end
    local list = {}
    local index = 0
    for _, configInfo in ConfigPairs(jewelConfig) do
        local jewel = configInfo
        if jewel then
            -- 获取同类型的所有表中的数据 （最低品质为2 不显示最低品质）
            if jewel.Race == _index and jewel.Level > 2 then
                index = index + 1
                local treasure = {}
                local Id = jewel.Id
                treasure.Id = Id
                local lv = jewel.Level
                treasure.frame = GetQuantityImageByquality(lv)
                --合成当前宝物需要的宝物id
                treasure.lowId = Id - 1
                treasure.lowFrame = GetQuantityImageByquality(lv - 1)
                treasure.icon = GetResourcePath(itemConfig[Id].ResourceID)
                treasure.quantity = lv
                treasure.name = itemConfig[Id].Name
                treasure.race = lv
                treasure.equipType = jewel.Location
                treasure.quaUpCount = jewel.RankupCount
                treasure.proIcon = GetProStrImageByProNum(jewel.Race)
                treasure.costCoin = jewel.RankupResources
                list[index] = treasure
            end
        end
    end
    if LengthOfTable(list) > 0 then
        table.sort(
            list,
            function(a, b)
                if a.race == b.race then
                    return a.Id < b.Id
                end
                return a.race < b.race
            end
        )
        return list
    end
end

--获取一键合成便利的所有宝物
function this.GetAllTabletTreasuresByRaceAndType(_index, _Location)
    if jewelConfig == nil then
        return
    end
    local list = {}
    local index = 0
    for _, configInfo in ConfigPairs(jewelConfig) do
        local jewel = configInfo
        if jewel then
            -- 获取同类型的所有表中的数据 （最低品质为2 不显示最低品质）
            if
                jewel.Race == _index and jewel.Level > 2 and
                    ((_Location and jewel.Location == _Location) or not _Location)
             then
                index = index + 1
                local treasure = {}
                local Id = jewel.Id
                treasure.Id = Id
                local lv = jewel.Level
                treasure.frame = GetQuantityImageByquality(lv)
                treasure.lowFrame = GetQuantityImageByquality(lv - 1)
                treasure.icon = GetResourcePath(itemConfig[Id].ResourceID)
                treasure.quantity = lv
                treasure.name = itemConfig[Id].Name
                treasure.race = lv
                treasure.equipType = jewel.Location
                treasure.quaUpCount = jewel.RankupCount
                treasure.proIcon = GetProStrImageByProNum(jewel.Race)
                treasure.costCoin = jewel.RankupResources
                list[index] = treasure
            end
        end
    end
    if LengthOfTable(list) > 0 then
        table.sort(
            list,
            function(a, b)
                return a.race < b.race
            end
        )
        return list
    end
end

--获取所有可以合成宝物的数据
function this.GeEquipTreasureDatas(_index)
    local equips = {}
    for i=1, 2 do 
        if not equips[i] then
            equips[i] = {}
        end
        for j=2, 6 do 
            equips[i][j] = 0
        end
    end
    
    for i, v in pairs(allTreasures) do
        if v.upHeroDid == "" and v.lv == 0 and v.refineLv == 0 and v.race == _index then
            if not equips[v.equipType] then
                equips[v.equipType] = {}
            end
            if not equips[v.equipType][v.quantity] then
                equips[v.equipType][v.quantity] = 1
            else
                equips[v.equipType][v.quantity] = equips[v.equipType][v.quantity] + 1
            end
        end
    end
    return equips
end

--获取所有可以合成宝物的数据
function this.GetBagCompoundEquipDatasByequipSData(equipSData)
    local equips = {}
    for i, v in pairs(allTreasures) do
        --获取没有穿戴，没有精炼/强化，低一个品质（表里低一个品质的id-1）
        if
            v.equipType == equipSData.equipType and v.upHeroDid == "" and v.quantity == equipSData.quantity - 1 and
                v.lv == 0 and
                v.refineLv == 0 and
                v.id == equipSData.Id - 1
         then
            table.insert(equips, v)
        end
    end
    return equips
end

--获取可以合成宝物的数量根据宝物id
function this.GetCanCompoundTreasureNumByTreasureId(_id, _type)
    local equips = {}
    for i, v in pairs(allTreasures) do
        --获取没有穿戴，没有精炼/强化，低一个品质（表里低一个品质的id-1）
        if v.equipType == _type and v.upHeroDid == "" and v.lv == 0 and v.refineLv == 0 and v.id == _id then
            table.insert(equips, v)
        end
    end
    return LengthOfTable(equips)
end

--获取当前等级加成的属性
function this.GetCurLvPropertyValue(_type, _id, _lv)
    local lvConfig = nil
    --获取当前等级属性加成
    for _, configInfo in ConfigPairs(jewerLevelUpConfig) do
        if configInfo.Type == _type and configInfo.PoolID == _id and configInfo.Level == _lv then
            lvConfig = configInfo
            break
        end
    end
    local proList = {}
    if lvConfig then
        for i = 1, table.getn(lvConfig.Property) do
            local info = lvConfig.Property[i]
            if info then
                local index = info[1]
                local skillValue = {}
                skillValue.currValue = info[2]
                if info[2] ~= 0 then
                    proList[index] = skillValue
                end
            end
        end
    end

    return proList
end

--获取满足升级条件的宝物
function this.GetEnoughRefineTreasure(_id, _idDyn)
    if allTreasures == nil then
        return
    end
    local num = 0
    local list = {}
    for i, v in pairs(allTreasures) do
        local isUpHero = false
        if v.upHeroDid == "" or v.upHeroDid == nil then
            isUpHero = false
        else
            isUpHero = true
        end

        if v.id == _id and v.idDyn ~= _idDyn and v.lv == 0 and v.refineLv == 0 and isUpHero == false then
            list[i] = v
            num = num + 1
        end
    end
    return list, num
end

function this.RemoveTreasureByIdDyn(_idDyn)
    if allTreasures == nil then
        return
    end
    if allTreasures[_idDyn] then
        allTreasures[_idDyn] = nil
    end
end

--获取所有宝物 不算英雄身上穿的 通过稀有度
function this.GetAllTreasuresByQuantity(Quantity)
    local curAllEquipTreasure = {}
    for key, value in pairs(allTreasures) do
        if (value.upHeroDid == "" or value.upHeroDid == "0") and value.itemConfig.Quantity == Quantity then
            table.insert(curAllEquipTreasure, value)
        elseif (value.upHeroDid == "" or value.upHeroDid == "0") and Quantity == 1 then --1  全部
            table.insert(curAllEquipTreasure, value)
        end
    end
    return curAllEquipTreasure
end
--获取所有宝物 不算英雄身上穿的 通过稀有度
function this.GetAllTreasuresByLocation(Location, PropertyName)
    local curAllEquipTreasure = {}
    for key, value in pairs(allTreasures) do
        if
            (value.upHeroDid == "" or value.upHeroDid == "0" ) and jewelConfig[value.id].Location == Location and
                jewelConfig[value.id].Race == PropertyName
         then
            table.insert(curAllEquipTreasure, value)
        end
    end
    return curAllEquipTreasure
end
--获取所有宝物 不算英雄身上穿的
function this.GetAllTreasures(PropertyName)
    if PropertyName then
    end
    local curAllEquipTreasure = {}
    for key, value in pairs(allTreasures) do
        if value.upHeroDid == "" or value.upHeroDid == "0" then
            if PropertyName then
                if jewelConfig[value.id].Race == PropertyName then
                    table.insert(curAllEquipTreasure, value)
                end
            else
                table.insert(curAllEquipTreasure, value)
            end
        end
    end
    if LengthOfTable(curAllEquipTreasure) > 0 then
        table.sort(
            curAllEquipTreasure,
            function(a, b)
                if a.quantity == b.quantity then
                    if a.lv == b.lv then
                        return a.refineLv > b.refineLv
                    else
                        return a.lv > b.lv
                    end
                else
                    return a.quantity > b.quantity
                end
            end
        )
        return curAllEquipTreasure
    end

    return curAllEquipTreasure
end
--改变宝物的等级或精炼等级
function this.ChangeTreasureLv(_idDyn, _type)
    if allTreasures == nil then
        return
    end
    if allTreasures[_idDyn] == nil then
        return
    end
    if allTreasures[_idDyn] then
        if _type == 1 then
            if allTreasures[_idDyn].lv == allTreasures[_idDyn].maxLv then
                return
            end
            local lv = allTreasures[_idDyn].lv + 1
            allTreasures[_idDyn].lv = lv
            allTreasures[_idDyn].strongConfig = this.GetCurrTreasureLvConfig(1, allTreasures[_idDyn].levelPool, lv)
        else
            if _type == 2 then
                if allTreasures[_idDyn].refineLv == allTreasures[_idDyn].maxRefineLv then
                    return
                end
                local refine = allTreasures[_idDyn].refineLv + 1
                allTreasures[_idDyn].refineLv = refine
                allTreasures[_idDyn].refineConfig =
                    this.GetCurrTreasureLvConfig(2, allTreasures[_idDyn].refinePool, refine)
            end
        end
    end
end
--设置宝物的穿戴卸下 (第二个参数传nil为卸下)
function this.SetTreasureUpOrDown(_idDyn, _hero)
    if allTreasures[_idDyn] then
        allTreasures[_idDyn].upHeroDid = _hero
    end
end

--根据id删除宝物
function this.DeleteTreasureByIdDyn(_idDyn)
    if allTreasures then
        allTreasures[_idDyn] = nil
    end
end
--设置装备穿戴的英雄
function this.SetEquipTreasureUpHeroDid(_equipTreasureDid, _heroDid)
    if allTreasures[_equipTreasureDid] then
        allTreasures[_equipTreasureDid].upHeroDid = _heroDid
    end
end
--设置装备穿戴的英雄
function this.GetSingleEquipTreasreData(_equipTreasureDid)
    if allTreasures[_equipTreasureDid] then
        return allTreasures[_equipTreasureDid]
    else
        return nil
    end
end

--根据动态id获取宝物
function this.GetSingleTreasureByIdDyn(_idDyn)
    if allTreasures == nil then
        return
    end
    return allTreasures[_idDyn]
end

--计算战斗力
function this.CalculateWarForceBySid(sId, lv, rlv)
    return this.CalculateWarForceBase(sId, lv, rlv)
end

--计算战斗力
function this.CalculateWarForce(Did)
    local curTreasure = allTreasures[Did]
    if curTreasure then
        return this.CalculateWarForceBase(curTreasure.id, curTreasure.lv, curTreasure.refineLv)
    end
end
function this.CalculateWarForceBase(sId, lv, rlv)
    local curEuipTreaSureConfig = ConfigManager.GetConfigData(ConfigName.JewelConfig, sId)
    if curEuipTreaSureConfig then
        local addAllProVal = {}
        --主属性
        for _, configInfo in ConfigPairs(jewerLevelUpConfig) do
            --强化的属性
            if
                configInfo.PoolID == curEuipTreaSureConfig.LevelupPool and configInfo.Type == 1 and
                    configInfo.Level == lv
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
            if
                configInfo.PoolID == curEuipTreaSureConfig.RankupPool and configInfo.Type == 2 and
                    configInfo.Level == rlv
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
        local heroPropertyScore = {}
        for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.PropertyConfig)) do
            heroPropertyScore[i] = v.Score
        end
        local powerEndVal = 0
        for i, v in pairs(addAllProVal) do
            if v > 0 then
                local curProConfigData = ConfigManager.GetConfigData(ConfigName.PropertyConfig, i)
                if curProConfigData then
                    if curProConfigData.Style == 1 then
                        powerEndVal = powerEndVal + v * heroPropertyScore[i]
                    else
                        powerEndVal = powerEndVal + v / 100 * heroPropertyScore[i]
                    end
                end
            end
        end
        return math.floor(powerEndVal)
    end
end
--获取宝物升级消耗
function this.GetTreasureUpLvCostMatrial(_id, _lv)
    local currJewel = jewelConfig[_id]
    if currJewel == nil then
        return
    end

    local lvConfig = nil
    --获取当前等级属性加成
    local lvList
    for _, configInfo in ConfigPairs(jewerLevelUpConfig) do
        if configInfo.Type == 2 and configInfo.PoolID == currJewel.RankupPool and configInfo.Level < _lv then
            lvList[configInfo.Level] = configInfo
            break
        end
    end
    if lvList == nil then
        return
    end
    local idList = {}
    for i, v in pairs(lvList) do
        local cost = v.JewelExpend
        if cost then
            for i = 1, cost do
                for i = 1, cost[i][2] do
                    if cost[i][1] == 1 then
                        table.insert(idList, currJewel.Id)
                    else
                        table.insert(idList, cost[i][1])
                    end
                end
            end
        end
    end
    return idList
end

--宝器分解返回item信息
local rewardGroup = ConfigManager.GetConfig(ConfigName.RewardGroup)
local ShowItemlist = {}
function this.GetEquipTreasureResolveItems(selectEquipTreasureData)
    local allRewardData = {}
    local specificValue = 1--tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,34).Value)/10000
    ShowItemlist = {}
    
    for i, v in pairs(selectEquipTreasureData) do
        local curEquipTreasureData = allTreasures[i]
        if not curEquipTreasureData then  return end
        --先把精炼的材料放进去 因为有宝器 放前边        
        if curEquipTreasureData.refineLv > 0 then
            for i=0,curEquipTreasureData.refineLv-1 do            
                local refineJewelRankupConfig =ConfigManager.TryGetConfigDataByThreeKey(ConfigName.JewelRankupConfig,"Type",2,"Level",i,"PoolID",curEquipTreasureData.refinePool)
                if refineJewelRankupConfig then
                    --精炼消耗的法宝
                    if refineJewelRankupConfig.JewelExpend then
                        for JewelExpendkey, JewelExpendvalue in ipairs(refineJewelRankupConfig.JewelExpend) do
                            if JewelExpendvalue[1] == 1 then
                                this.GetEquipTreasureResolveItems2(curEquipTreasureData.id, JewelExpendvalue[2])
                            elseif JewelExpendvalue[1] > 1 then
                                this.GetEquipTreasureResolveItems2(JewelExpendvalue[1], JewelExpendvalue[2])
                            end
                        end
                    end
                    --精炼消耗的材料
                    if refineJewelRankupConfig.UpExpend then
                        for UpExpendkey, UpExpendvalue in ipairs(refineJewelRankupConfig.UpExpend) do
                            this.GetEquipTreasureResolveItems2(UpExpendvalue[1], UpExpendvalue[2])
                        end
                    end
                end
            end
        end
        if curEquipTreasureData.lv > 0 then
            for i=0,curEquipTreasureData.lv - 1 do  
            local lvJewelRankupConfig = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.JewelRankupConfig,"Type",1,"Level",i,"PoolID",curEquipTreasureData.LevelupPool)
            if lvJewelRankupConfig then
                --强化消耗的材料
                if lvJewelRankupConfig.UpExpend then
                    for UpExpendkey, UpExpendvalue in ipairs(lvJewelRankupConfig.UpExpend) do
                        this.GetEquipTreasureResolveItems2(UpExpendvalue[1], UpExpendvalue[2])
                    end
                end
            end
        end
        end
        --加自身分解消耗的东西
        local rewardShowStr1 = {}
        local resolveRewardStr = curEquipTreasureData.itemConfig.ResolveReward
        if resolveRewardStr and rewardGroup[tonumber(resolveRewardStr)] then
            local curRewardGroupData = rewardGroup[tonumber(resolveRewardStr)]
            for key, curRewardGroupDatavalue in ipairs(curRewardGroupData.ShowItem) do
                this.GetEquipTreasureResolveItems2(curRewardGroupDatavalue[1], curRewardGroupDatavalue[2])
            end
        end
    end
    local dropList = {}
    for ShowItemlistkey, ShowItemlistvalue in pairs(ShowItemlist) do
        local curReward = {}
        curReward.id = ShowItemlistkey
        curReward.num = math.floor(ShowItemlistvalue * specificValue)
        curReward.itemConfig = itemConfig[ShowItemlistkey]
        table.insert(dropList, curReward)
    end
    return dropList
end
function this.GetEquipTreasureResolveItems2(itemId, itemNum)
    if ShowItemlist[itemId] then
        ShowItemlist[itemId] = ShowItemlist[itemId] + itemNum
    else
        ShowItemlist[itemId] = itemNum
    end
end

return EquipTreasureManager