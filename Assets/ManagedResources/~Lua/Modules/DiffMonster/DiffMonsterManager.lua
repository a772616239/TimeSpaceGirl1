DiffMonsterManager = {}
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local pokemonComonpentsConfig = ConfigManager.GetConfig(ConfigName.DifferDemonsComonpentsConfig)
local pokemonStageConfig = ConfigManager.GetConfig(ConfigName.DifferDemonsStageConfig)

local this = DiffMonsterManager
-- 异妖立绘信息
this.demonlive2dInfo = {
    [1] = { Name = "live2d_s_jieling_dlg_3010",
            Scale = Vector3.New(0.6, 0.6, 1),
            Position = Vector2.New(0, -128), },
    [2] = { Name = "live2d_s_jieling_zlz_3001",
            Scale = Vector3.New(0.6, 0.6, 1),
            Position = Vector2.New(0, -128), },
    [3] = { Name = "live2d_s_jieling_hg_3002",
            Scale = Vector3.New(0.5, 0.5, 1),
            Position = Vector2.New(0, -128), },
    [4] = { Name = "live2d_s_jieling_jhj_3003",
            Scale = Vector3.New(0.7, 0.7, 1),
            Position = Vector2.New(0, -128), },
    [5] = { Name = "live2d_s_jieling_hs_3006",
            Scale = Vector3.New(0.5, 0.5, 1),
            Position = Vector2.New(0, -128), },
    [6] = { Name = "live2d_s_jieling_lms_3009",
            Scale = Vector3.New(0.6, 0.6, 1),
            Position = Vector2.New(0, -128), },
    [7] = { Name = "live2d_s_jieling_sl_3005",
            Scale = Vector3.New(0.8, 0.8, 1),
            Position = Vector2.New(0, -128), },
    [8] = { Name = "live2d_s_jieling_md_3007",
            Scale = Vector3.New(0.8, 0.8, 1),
            Position = Vector2.New(0, -128), },
    [9] = { Name = "live2d_s_jieling_fl_3008",
            Scale = Vector3.New(0.8, 0.8, 1),
            Position = Vector2.New(0, -128), },
    [10] = { Name = "live2d_s_jieling_tl_3004",
             Scale = Vector3.New(0.5, 0.5, 1),
             Position = Vector2.New(0, -128), },

}

this.pokemonList = {}
--存储配件ExtraAdd信息
this.extraAddList = {}

--异妖配件战力相关
this.componentPropertyList = {}
this.propertyTotalList = {}

function this.Initialize()

end

-- 数据结构
-- pokemonInfo.id
-- pokemonInfo.stage
-- pokemonInfo.pokemoncomonpent -- id
-- level
function this.Init(_pokemonList)
    for i = 1, #_pokemonList do
        this.SinglePokemonInfo(_pokemonList[i], i)
    end

    --初始化每个职业的加成 0 全职业
    for i = 0, 5 do
        this.extraAddList[i] = {}
    end
    this.InitComponentsExtraData()
    --初始化异妖配件战力相关属性
    this.InitComponentsPropertyData()

end

-- 单个异妖数据
function this.SinglePokemonInfo(pokemonInfo, index)
    local pokemon = {}
    pokemon.id = pokemonInfo.id
    if pokemonInfo.id == 0 then
        return
    end
    pokemon.stage = pokemonInfo.stage--也是lv
    pokemon.pokemonConfig = ConfigManager.GetConfigData(ConfigName.DifferDemonsConfig, pokemon.id)--异妖静态信息pokemonStageConfig
    pokemon.pokemonUpLvConfigList = {}--异妖升级静态信息list

    for i, v in ConfigPairs(pokemonStageConfig) do
        if math.floor(v.ID / 100) == pokemon.id then
            local pokemonUpLvStaticData = {}
            pokemonUpLvStaticData.lv = v.ID % 100
            pokemonUpLvStaticData.configData = v
            pokemon.pokemonUpLvConfigList[pokemonUpLvStaticData.lv] = pokemonUpLvStaticData
        end
    end

    pokemon.pokemoncomonpentList = {}--配件list {id，lv,config}
    for i = 1, #pokemon.pokemonConfig.ComonpentList do
        --配件升级静态信息pokemonComonpentsConfig
        local pokemoncomonpent = {}
        pokemoncomonpent.id = pokemon.pokemonConfig.ComonpentList[i]
        pokemoncomonpent.level = 0
        pokemoncomonpent.upLvMateriaConfiglList = {}
        for _, configInfo in ConfigPairs(pokemonComonpentsConfig) do
            if configInfo.ComonpentsId == pokemoncomonpent.id then
                pokemoncomonpent.upLvMateriaConfiglList[configInfo.Stage] = configInfo
            end
        end
        table.insert(pokemon.pokemoncomonpentList, pokemoncomonpent)
    end
    for i = 1, #pokemonInfo.pokemoncomonpent do
        --配件升级动态数据
        for j = 1, #pokemon.pokemoncomonpentList do
            if pokemon.pokemoncomonpentList[j].id == pokemonInfo.pokemoncomonpent[i].id then
                pokemon.pokemoncomonpentList[j].level = pokemonInfo.pokemoncomonpent[i].level
            end
        end
    end
    --table.insert(this.pokemonList,pokemon)
    this.pokemonList[pokemon.id] = pokemon
end
--获取单个异妖数据
function this.GetSinglePokemonData(_pokemonId)
    if this.pokemonList[_pokemonId] then
        return this.pokemonList[_pokemonId]
    else
        return nil
    end
end
--获取单个异妖技能id
function this.GetSinglePokemonSkillIdData(_pokemonId)
    if this.pokemonList[_pokemonId] then
        local curPokemon = this.pokemonList[_pokemonId]
        if curPokemon.pokemonUpLvConfigList[curPokemon.stage] then
            return curPokemon.pokemonUpLvConfigList[curPokemon.stage].configData.SkillId
        else
            return 0
        end
    else
        return 0
    end
end
--获取单个异妖被动技能id
function this.GetSinglePokemonPassiveSkillIdData(_pokemonId)
    if this.pokemonList[_pokemonId] then
        local curPokemon = this.pokemonList[_pokemonId]
        if curPokemon.pokemonUpLvConfigList[curPokemon.stage] then
            return curPokemon.pokemonUpLvConfigList[curPokemon.stage].configData.PassiveSkillId
        end
    end
end
--更新异妖等级
function this.UpdatePokemonLv(_pokemonId, _Lv)
    if this.pokemonList[_pokemonId] then
        this.pokemonList[_pokemonId].stage = _Lv
    end
end
--更新异妖配件等级
function this.UpdatePokemonPeiJianLv(_pokemonId, _peijianId, _peijianLv)
    if this.pokemonList[_pokemonId] then
        for i = 1, #this.pokemonList[_pokemonId].pokemoncomonpentList do
            if this.pokemonList[_pokemonId].pokemoncomonpentList[i].id == _peijianId then
                this.pokemonList[_pokemonId].pokemoncomonpentList[i].level = _peijianLv
                FormationManager.UserPowerChanged()
                Game.GlobalEvent:DispatchEvent(GameEvent.DiffMonster.OnComponentChange, _pokemonId)
                this.SetExtraAddData(_peijianId, _peijianLv)
                this.AddOrRefreshBaseAttribute(this.GetActiveComponentInfo(_peijianId))
            end
        end
    end
end

--计算单个异妖加成的属性值
function this.CalculatePokemonProValue(pokemonId)
    local propValueList = {}
    local diffDemonsConfig = ConfigManager.GetConfigData(ConfigName.DifferDemonsConfig, pokemonId)
    for _, componentId in ipairs(diffDemonsConfig.ComonpentList) do
        local diffComponentsConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.DifferDemonsComonpentsConfig, "ComonpentsId", componentId)
        local targetConfig = diffComponentsConfigs[#diffComponentsConfigs]
        for _, attributeInfo in ipairs(targetConfig.BaseAttribute) do
            if propValueList[attributeInfo[1]] then
                propValueList[attributeInfo[1]] = propValueList[attributeInfo[1]] + attributeInfo[2]
            else
                propValueList[attributeInfo[1]] = attributeInfo[2]
            end
        end
    end
    for propId, propValue in pairs(propValueList) do
        local propConfig = ConfigManager.GetConfigData(ConfigName.PropertyConfig, propId)
        if propConfig.TargetPropertyId ~= 0 and propValueList[propConfig.TargetPropertyId] then
            propValueList[propConfig.TargetPropertyId] = math.floor((1 + propValue / 10000) * propValueList[propConfig.TargetPropertyId])
            table.remove(propValueList,propId)
        end
    end
    return propValueList
end

-----------初始化所有激活异妖配件的加成数据-----------
--获取所有已激活异妖配件
function this.GetAllActiveDiffComponents()
    local activeComponents = {}
    for _, pokemon in pairs(this.pokemonList) do
        table.walk(pokemon.pokemoncomonpentList, function(componentInfo)
            if componentInfo.level > 0 then
                table.insert(activeComponents, componentInfo)
            end
        end)
    end
    return activeComponents
end

function this.GetActiveComponentInfo(componentId)
    for _, pokemon in pairs(this.pokemonList) do
        for _, componentInfo in pairs(pokemon.pokemoncomonpentList) do
            if componentInfo.id == componentId then
                return componentInfo
            end
        end
    end
end

--获取配件Id等级level内的所有ExtraAdd数据
function this.GetComponentIdLevelExtraConfigData(componentInfo)
    local configData = {}
    for _, configInfo in ConfigPairs(pokemonComonpentsConfig) do
        if configInfo.ComonpentsId == componentInfo.id and
                configInfo.Stage <= componentInfo.level and
                configInfo.ExtraAdd then
            table.insert(configData, configInfo.ExtraAdd)
        end
    end
    return configData
end
function this.InitComponentsExtraData()
    local allActiveComponents = this.GetAllActiveDiffComponents()
    table.walk(allActiveComponents, function(componentInfo)
        local ExtraAddData = this.GetComponentIdLevelExtraConfigData(componentInfo)
        table.walk(ExtraAddData, function(ExtraInfo)
            for i = 1, #ExtraInfo do
                this.AddOrRefreshExtraAdd(ExtraInfo[i][1], ExtraInfo[i][2], ExtraInfo[i][3], componentInfo.id)
            end
        end)
    end)
end
------------------------------------------------

--设定加成数值
function this.SetExtraAddData(componentId, level)
    local extraAddConfigData = this.GetComponentIdConfigData(componentId, level)
    if not extraAddConfigData then
        return
    end
    for i = 1, #extraAddConfigData do
        this.AddOrRefreshExtraAdd(extraAddConfigData[i][1], extraAddConfigData[i][2], extraAddConfigData[i][3], componentId)
    end
end

--当前Id,level数据
function this.GetComponentIdConfigData(componentId, level)
    for _, configInfo in ConfigPairs(pokemonComonpentsConfig) do
        if configInfo.ComonpentsId == componentId and
                configInfo.Stage == level and
                configInfo.ExtraAdd then
            return configInfo.ExtraAdd
        end
    end
    return false
end
--刷新赋值或者添加新值
function this.AddOrRefreshExtraAdd(pos, propId, value, componentId)
    local isContain = table.keyvalueindexof(this.extraAddList[pos], "Id", propId)
    if isContain then
        this.extraAddList[pos][isContain].value = this.extraAddList[pos][isContain].value + value
    else
        table.insert(this.extraAddList[pos], { Id = propId, value = value, componentId = componentId })
    end
end
--获取某个职业当前的异妖配件所有加成属性
function this.GetExtraAddEffect(pos)
    return this.extraAddList[pos]
end

------------初始化所有激活异妖配件的属性数据-----------
--初始化各属性
function this.InitComponentsPropertyData()
    local allActiveComponents = this.GetAllActiveDiffComponents()
    for _, componentInfo in ipairs(allActiveComponents) do
        this.AddOrRefreshBaseAttribute(componentInfo)
    end
end

--获取配件Id等级level内的所有BaseAttribute数据
function this.GetComponentIdLevelBaseAttributeConfigData(componentInfo)
    local configData = {}
    for _, configInfo in ConfigPairs(pokemonComonpentsConfig) do
        if configInfo.ComonpentsId == componentInfo.id and
                configInfo.Stage <= componentInfo.level then
            table.insert(configData, configInfo.BaseAttribute)
        end
    end
    return configData
end

--刷新赋值或者添加新值
function this.AddOrRefreshBaseAttribute(componentInfo)
    local AttributeData = {}
    local BaseAttributeData = this.GetComponentIdLevelBaseAttributeConfigData(componentInfo)
    table.walk(BaseAttributeData, function(BaseAttributeInfo)
        for i = 1, #BaseAttributeInfo do
            table.insert(AttributeData, BaseAttributeInfo[i])
        end
    end)
    local componentId = componentInfo.id
    if not this.componentPropertyList[componentId] then
        this.componentPropertyList[componentId] = {}
        this.SetPerPropertyValue(AttributeData, componentId, true)
    else
        this.SetPerPropertyValue(AttributeData, componentId, false)
    end
end

--具体每个属性的赋值和更新(flag是否是全新的)
function this.SetPerPropertyValue(attributeData, componentId, flag)
    for i = 1, #attributeData do
        
        local attributeInfo = attributeData[i]
        local posIndex = table.keyvalueindexof(this.componentPropertyList[componentId], "Id", attributeInfo[1])
        if posIndex then
            local tempForwardValue = this.componentPropertyList[componentId][posIndex].value
            local currentValue = this.propertyTotalList[attributeInfo[1]]
            this.propertyTotalList[attributeInfo[1]] = currentValue - tempForwardValue + attributeInfo[2]
            this.componentPropertyList[componentId][posIndex].value = attributeInfo[2]
            --if not flag then
            --    local tempForwardValue = this.componentPropertyList[componentId][posIndex].value
            --    local currentValue = this.propertyTotalList[attributeInfo[1]]
            --    this.propertyTotalList[attributeInfo[1]] = currentValue - tempForwardValue + attributeInfo[2]
            --    this.componentPropertyList[componentId][posIndex].value = attributeInfo[2]
            --else
            --    this.componentPropertyList[componentId][posIndex].value = attributeInfo[2]
            --    this.propertyTotalList[attributeInfo[1]] = this.propertyTotalList[attributeInfo[1]] + attributeInfo[2]
            --end
        else
            table.insert(this.componentPropertyList[componentId], { Id = attributeInfo[1], value = attributeInfo[2] })
            if this.propertyTotalList[attributeInfo[1]] then
                this.propertyTotalList[attributeInfo[1]] = this.propertyTotalList[attributeInfo[1]] + attributeInfo[2]
            else
                this.propertyTotalList[attributeInfo[1]] = attributeInfo[2]
            end
        end
        
    end
    --for k, v in pairs(this.propertyTotalList) do
    
    --end
end

function this.DealWithPropertyList()
    local desirePropertyList = {}
    for k, v in pairs(this.propertyTotalList) do
        local configInfo = propertyConfig[k]
        if configInfo.TargetPropertyId ~= 0 then
            
            local gainProperty = this.propertyTotalList[configInfo.TargetPropertyId]
            gainProperty = gainProperty * (1 + v / 10000)
            desirePropertyList[configInfo.TargetPropertyId] = gainProperty
        else
            
            desirePropertyList[k] = v
        end
    end
    return desirePropertyList
end

function this.GetDiffMonstersPowerValue()
    local totalPower = 0
    local wholePropertyList = this.DealWithPropertyList()
    for k, v in pairs(wholePropertyList) do
        local configInfo = propertyConfig[k]
        if configInfo.Style == 1 then
            totalPower = totalPower + v * configInfo.Score
        else
            totalPower = totalPower + v / 100 * configInfo.Score
        end
    end
    return math.floor(totalPower) * 5
end

------------------------------------------------



function this.CalculatePokemonPeiJiAllProAddVal(_pokemonId)
    local allProVal = {}
    for i, v in ConfigPairs(propertyConfig) do
        allProVal[i] = 0
    end
    if this.pokemonList[_pokemonId] then
        for i = 1, #this.pokemonList[_pokemonId].pokemoncomonpentList do
            local item = this.pokemonList[_pokemonId].pokemoncomonpentList[i]
            if item.upLvMateriaConfiglList[item.level] then
                local BaseAttribute = item.upLvMateriaConfiglList[item.level].BaseAttribute
                for j = 1, #BaseAttribute do
                    allProVal[BaseAttribute[j][1]] = allProVal[BaseAttribute[j][1]] + BaseAttribute[j][2]
                end
            end
        end
    end
    return allProVal
end
--计算所有异妖配件的加成属性
function this.CalculateAllPokemonPeiJiAllProAddVal(heroPos)
    local allProVal = {}
    for i, v in ConfigPairs(propertyConfig) do
        allProVal[i] = 0
    end
    for j = 1, #this.pokemonList do
        for i = 1, #this.pokemonList[j].pokemoncomonpentList do
            if this.pokemonList[j].pokemoncomonpentList[i].upLvMateriaConfiglList[this.pokemonList[j].pokemoncomonpentList[i].level] then
                local BaseAttribute = this.pokemonList[j].pokemoncomonpentList[i].upLvMateriaConfiglList[this.pokemonList[j].pokemoncomonpentList[i].level].BaseAttribute
                for j = 1, #BaseAttribute do
                    allProVal[BaseAttribute[j][1]] = allProVal[BaseAttribute[j][1]] + BaseAttribute[j][2]
                end
            end
        end
    end
    --异妖配件对职业额外加成
    local allComonpentExtraAdd = this.GetExtraAddEffect(heroPos)
    if allComonpentExtraAdd and #allComonpentExtraAdd > 0 then
        for i = 1, #allComonpentExtraAdd do
            allProVal[allComonpentExtraAdd[i].Id] = allProVal[allComonpentExtraAdd[i].Id] + allComonpentExtraAdd[i].value
        end
    end
    --异妖配件全职业的加成
    local allComonpentExtraAdd2 = this.GetExtraAddEffect(0)
    if allComonpentExtraAdd2 and #allComonpentExtraAdd2 > 0 then
        for i = 1, #allComonpentExtraAdd2 do
            allProVal[allComonpentExtraAdd2[i].Id] = allProVal[allComonpentExtraAdd2[i].Id] + allComonpentExtraAdd2[i].value
        end
    end
    return allProVal
end


-------------红点数据处理--------------------
--异妖主界面是否存在红点
function this.GetDiffMonsterRedPointStatus()
    local meetCondition = false
    meetCondition = meetCondition or this.CanActiveComponent() or this.CanUpGradComponent() or
            this.CanActiveDiffMonster() or this.CanUpGradDiffMonster()
    return meetCondition
end

function this.GetSingleDiffMonsterRedPointStatus(pokemon)
    local meetCondition = false
    meetCondition = meetCondition or this.SingleActiveComponent(pokemon) or this.SingleUpGradComponent(pokemon) or
            this.SingleActiveDiffMonster(pokemon) or this.SingleUpGradDiffMonster(pokemon)
    return meetCondition
end

--单个异妖是否存在可以激活的妖魂
function this.SingleActiveComponent(pokemon)
    local meetCondition = false
    for _, pokemonComponent in pairs(pokemon.pokemoncomonpentList) do
        if pokemonComponent.level <= 0 and BagManager.GetItemCountById(pokemonComponent.id) > 0 then
            meetCondition = true
            break
        end
    end
    return meetCondition
end
--所有异妖是否存在可以激活的妖魂
function this.CanActiveComponent()
    local meetCondition = false
    for _, pokemon in pairs(this.pokemonList) do
        meetCondition = meetCondition or this.SingleActiveComponent(pokemon)
        if meetCondition then
            break
        end
    end
    return meetCondition
end

--单个异妖是否存在可以进阶妖魂
function this.SingleUpGradComponent(pokemon)
    local meet = false
    table.walk(pokemon.pokemoncomonpentList, function(componentInfo)
        local maxLv = #componentInfo.upLvMateriaConfiglList
        local currentLv = componentInfo.level + 1
        if currentLv >= maxLv then
            meet = false
        else
            local materialEnough = true
            if currentLv > 0 then
                local costMaterials = componentInfo.upLvMateriaConfiglList[currentLv].Cost
                for idx = 1, #costMaterials do
                    materialEnough = materialEnough and BagManager.GetItemCountById(costMaterials[idx][1]) >= costMaterials[idx][2]
                end
            else
                materialEnough = false
            end
            meet = meet or materialEnough
        end
    end)
    return meet
end
--所有异妖是否存在可进阶妖魂
function this.CanUpGradComponent()
    local meetCondition = false
    for _, pokemon in pairs(this.pokemonList) do
        meetCondition = meetCondition or this.SingleUpGradComponent(pokemon)
        if meetCondition then
            break
        end
    end
    return meetCondition
end
--通过配件id获取异妖信息
function this.GetPokemonDataByComonpentId(_comonpentId)
    for j = 1, #this.pokemonList do
        for i = 1, #this.pokemonList[j].pokemoncomonpentList do
            local comonpentData = this.pokemonList[j].pokemoncomonpentList[i]
            if comonpentData.id == _comonpentId then
                return this.pokemonList[j]
            end
        end
    end
end
--单个异妖是否可以激活
function this.SingleActiveDiffMonster(pokemon)
    if pokemon.stage > 0 then
        return false
    end
    local activeComponent = 0
    for _, pokemonComponent in pairs(pokemon.pokemoncomonpentList) do
        if pokemonComponent.level > 0 then
            activeComponent = activeComponent + 1
        end
    end
    return activeComponent >= #pokemon.pokemoncomonpentList
end
--所有异妖是否存在可激活异妖
function this.CanActiveDiffMonster()
    local meetCondition = false
    for _, pokemon in pairs(this.pokemonList) do
        meetCondition = meetCondition or this.SingleActiveDiffMonster(pokemon)
        if meetCondition then
            break
        end
    end
    return meetCondition
end

--单个异妖是否可以进阶
function this.SingleUpGradDiffMonster(pokemon)
    local meet = true
    if pokemon.stage >= #pokemon.pokemonUpLvConfigList then
        meet = false
    else
        meet = this.JudgeComponentsMeet(pokemon) and this.JudgeMaterialCostMeet(pokemon)
    end
    return meet
end
--配件等级进阶判定
function this.JudgeComponentsMeet(pokemon)
    local meet = true
    table.walk(pokemon.pokemoncomonpentList, function(componentInfo)
        meet = meet and componentInfo.level > pokemon.stage
    end)
    return meet
end
--材料消耗是否都满足
function this.JudgeMaterialCostMeet(pokmon)
    local meet = true
    local costMaterials = pokmon.pokemonUpLvConfigList[pokmon.stage + 1].configData.Cost
    for i = 1, #costMaterials do
        meet = meet and BagManager.GetItemCountById(costMaterials[i][1]) >= costMaterials[i][2]
    end
    return meet
end

--所有异妖是否存在可进阶异妖
function this.CanUpGradDiffMonster()
    local meetCondition = false
    for _, pokemon in pairs(this.pokemonList) do
        meetCondition = meetCondition or this.SingleUpGradDiffMonster(pokemon)
        if meetCondition then
            break
        end
    end
    return meetCondition
end

--获取异妖技能最大等级（ 秘技）
function this.GetDifferSkillMaxLevel(type)
    local curHeroData = ConfigManager.GetConfig(ConfigName.DifferDemonsStageConfig)

    local maxLv = 0
    for id, _ in ConfigPairs(curHeroData) do
        if math.floor(id / 100) == type then
            maxLv = maxLv + 1
        end
    end
    return maxLv
end

function this.GetDiffMonsterByComponentId(componentId)
    local diffMonsterId
    local diffDemonsConfig = ConfigManager.GetConfig(ConfigName.DifferDemonsConfig)
    for idx, diffMonsterInfo in ConfigPairs(diffDemonsConfig) do
        local index = table.indexof(diffMonsterInfo.ComonpentList, componentId)
        if index then
            diffMonsterId = idx
            break
        end
    end
    return diffMonsterId
end

---------------------------------------------------------------------------


return DiffMonsterManager