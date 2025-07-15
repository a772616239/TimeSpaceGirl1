EquipManager = {}
local this = EquipManager
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local equipStarsConfig = ConfigManager.GetConfig(ConfigName.EquipStarsConfig)
local rewardGroupConfig=ConfigManager.GetConfig(ConfigName.RewardGroup)

--已装备的
this.equipDatas = {}

function this.Initialize()
end

--upHeroDid
function this.InitUpdateEquipData(id, upHeroDid, isFindHandBook)
    if not this.equipDatas then
        this.equipDatas = {}
    end
    id = tonumber(id)
    
    
    if this.equipDatas[id] then
        if not this.equipDatas[id].upHeroDidList then
            this.equipDatas[id].upHeroDidList = {}
        end
        if upHeroDid and upHeroDid ~= "0" then
            this.equipDatas[id].upHeroDidList[upHeroDid] = upHeroDid
        end
    else
        local equipdata = {}
        equipdata.equipConfig = equipConfig[id]
        equipdata.itemConfig = itemConfig[id]
        equipdata.id = id
        if itemConfig[equipdata.id] then
            equipdata.icon = GetResourcePath(itemConfig[equipdata.id].ResourceID)
        else

            return
        end
        equipdata.frame = GetQuantityImageByquality(equipdata.equipConfig.Quality)
        equipdata.quality = equipdata.equipConfig.Quality
        equipdata.position = equipdata.equipConfig.Position

        equipdata.mainAttribute = this.GetMainProList(equipdata.equipConfig)

        equipdata.backData = equipdata
        equipdata.star = equipStarsConfig[equipdata.equipConfig.Star].Stars
        this.equipDatas[id] = equipdata
        if not this.equipDatas[id].upHeroDidList then
            this.equipDatas[id].upHeroDidList = {}
        end

        if upHeroDid and upHeroDid ~= "0" and not this.equipDatas[id].upHeroDidList[upHeroDid] then
            this.equipDatas[id].upHeroDidList[upHeroDid] = upHeroDid
        end

        isFindHandBook = isFindHandBook or true
        if isFindHandBook then
            PlayerManager.SetEquipHandBookListData(equipdata.id)
        end
    end
end

function this.UpdateEquipData(idlist, heroDid)
    for i = 1, #idlist do
        this.InitUpdateEquipData(idlist[i], heroDid, false)
    end
end

-- --更新装备数据 新加
-- function this.UpdateEquipData(_equipData, isFindHandBook)

--     -- --新获得装备存红点
--     -- if equipConfig[_equipData.id] then
--     --     this.InitUpdateEquipData(_equipData.id,isFindHandBook)
--     --     if equipConfig[_equipData.id].Quality >= 4 then
--     --         table.insert(this.NewEquipList, _equipData.id)
--     --         -- 本地保存数据
--     --         local str = table.concat(this.NewEquipList, "|")
--     --         PlayerPrefs.SetString("EquipNew" .. PlayerManager.uid, str)
--     --     end
--     -- end
-- end

--获取单个装备数据
function this.GetSingleEquipData(_equipid)
    _equipid = tonumber(_equipid)
    if not this.equipDatas[_equipid] then
        this.InitUpdateEquipData(_equipid, nil, false)
    end
    return this.equipDatas[_equipid]
end

--通过装备职业和位置获得装备list.包括英雄自己身上装备的
function this.GetEquipDataByEquipJobAndPos(_pos, _job, _heroDid)
    --没装备的
    local equips = BagManager.GetEquipDataByEquipPosition(_job, _pos)
    local equipDatas = {}
    local index = 1

    -- --自己装备
    -- local idlist= HeroManager.GetHeroEquipIdList(_heroDid)
    -- if not idlist then
    --     return equips
    -- end

    -- for __,equip in ipairs(equips) do
    --     local add = true
    --     --如果没装备的包含自己装备的
    --     for i, v in ipairs(idlist) do
    --         if tonumber(equip.id) == tonumber(v)  then
    --             add = false
    --             break
    --         end
    --     end
    --     --如果没装备的不包含自己装备的
    --     if add then
    --         for i, v in ipairs(idlist) do
    --             local equip = this.GetSingleHeroSingleEquipData(tonumber(v),_heroDid)
    --             if equip and (equip.equipConfig.Position == _pos or not _pos or _pos == 0) and (equip.equipConfig.ProfessionLimit == _job or not _job)  then
    --                 equips[#equips+1] = equip
    --             end
    --         end
    --     end
    -- end
    return equips
end

--设置装备穿戴的英雄
function this.SetEquipUpHeroDid(_equipid, _heroDid)
    _equipid = tonumber(_equipid)
    if not this.equipDatas[_equipid] then
        this.InitUpdateEquipData(_equipid, _heroDid, false)
    else
        if not this.equipDatas[_equipid].upHeroDidList then
            this.equipDatas[_equipid].upHeroDidList = {}
        end
        this.equipDatas[_equipid].upHeroDidList[_heroDid] = _heroDid
    end
end

--删除装备穿戴的英雄
function this.DeleteSingleEquip(_equipid, _heroDid)
    _equipid = tonumber(_equipid)
    if
        this.equipDatas[_equipid] and this.equipDatas[_equipid].upHeroDidList and
            this.equipDatas[_equipid].upHeroDidList[_heroDid]
     then
        this.equipDatas[_equipid].upHeroDidList[_heroDid] = nil
    end
end

--获取单个英雄装备数据
function this.GetSingleHeroSingleEquipData(_equipid, _heroDid)
    _equipid = tonumber(_equipid)
    if
        this.equipDatas[_equipid] and this.equipDatas[_equipid].upHeroDidList and
            this.equipDatas[_equipid].upHeroDidList[_heroDid]
     then
        return this.equipDatas[_equipid]
    else
        return nil
    end
end

-- --工坊 获得装备品品质获得装备list
-- function this.WorkShopGetEquipDataByEquipQuality(_equipQuality, _rebuildEquipDid)
--     local equips = {}
--     for i, v in pairs(EquipManager.equipDatas) do
--         if v.equipConfig.Quality == _equipQuality then
--             if v.did ~= _rebuildEquipDid then
--                 if v.upHeroDid == "0" then
--                     table.insert(equips, v)
--                 end
--             end
--         end
--     end
--     return equips
-- end

-- --工坊 获得可重铸所有装备
-- function this.GetAllEquipDataIfClear()
--     local equips = {}
--     for i, v in pairs(EquipManager.equipDatas) do
--         if v.equipConfig.IfClear == 1 then
--             table.insert(equips, v)
--         end
--     end
--     return equips
-- end

--地图临时背包数据
this.mapShotTimeItemData = {}
--地图临时装备数据存储
function this.InitMapShotTimeEquipBagData(_mapEquip)
    this.mapShotTimeItemData[#this.mapShotTimeItemData + 1] = _mapEquip
end

--计算战斗力
function this.CalculateWarForce(equipid, data)
    equipid = tonumber(equipid)
    local curEquip = equipConfig[equipid]
    if curEquip then --正常背包
        local num = this.CalculateEquipWarForce(curEquip)
        return num
    else
        curEquip = data
        if curEquip then
            local num = this.CalculateEquipWarForce(curEquip)
            return num
        end
    end
end

--根据装备数据计算战斗力
function this.CalculateEquipWarForce(curEquip)
    local addAllProVal = {}
    for i, v in ConfigPairs(propertyConfig) do
        addAllProVal[i] = 0
    end

    local mainAttribute = this.GetMainProList(curEquip)
    for index, prop in pairs(mainAttribute) do
        local id = prop.propertyId
        local value = prop.propertyValue
        if addAllProVal[id] then
            addAllProVal[id] = addAllProVal[id] + value
        else
            addAllProVal[id] = value
        end
    end
   --[[ local powerEndVal = 0
    for i, v in pairs(addAllProVal) do
        if v > 0 then
            local curProConfigData = ConfigManager.GetConfigData(ConfigName.PropertyConfig, i)
            if curProConfigData then
                if curProConfigData.Style == 1 then
                    powerEndVal = powerEndVal + v * HeroManager.heroPropertyScore[i]
                    --print(HeroManager.heroPropertyScore[i])
                else
                    powerEndVal = powerEndVal + v / 100 * HeroManager.heroPropertyScore[i]
                end
            end
        end
    end]]
    if curEquip and curEquip.Score > 0 then
        powerEndVal = --[[powerEndVal +]] curEquip.Score
    end
    return math.floor(powerEndVal)
end

-- 判断是否是新装备
function this.IsNewEquipFrame(equipDId)
    if not this.NewEquipList then
        return false
    end
    for _, newEquipId in ipairs(this.NewEquipList) do
        if newEquipId == equipDId then
            return true
        end
    end
    return false
end

-- 设置已经不是新装备了
function this.SetNotNewEquipAnyMore(equipDId)
    if not this.NewEquipList then
        return
    end
    local index = nil
    for i, newEquipId in ipairs(this.NewEquipList) do
        if newEquipId == equipDId then
            index = i
            break
        end
    end
    if not index then
        return
    end
    table.remove(this.NewEquipList, index)
    -- 保存数据
    local str = table.concat(this.NewEquipList, "|")
    PlayerPrefs.SetString("EquipNew" .. PlayerManager.uid, str)
end

--装备合成
--通过装备位置获得装备list {[绿1]= {},[绿2]= {},}
function this.GetEquipCompoundDataByEquipPosition1(_position)
    local starEquips = ConfigManager.GetAllConfigsDataByKey(ConfigName.EquipConfig, "Position", _position)
    
    table.sort(
        starEquips,
        function(a, b)
            return a.Star > b.Star
        end
    )

    local num = starEquips[1].Star
    
    local equips = {}
    for i = 1, num do
        equips[i] = 0
    end

    local equipDatas = BagManager.GetEquipDataByEquipPosition(nil, _position)
    
    for i, v in ipairs(equipDatas) do
        local equip = this.GetSingleEquipData(v.id)
        
        if equips[equip.equipConfig.Star] then
            equips[equip.equipConfig.Star] = equips[equip.equipConfig.Star] + v.num
        else
            equips[equip.equipConfig.Star] = v.num
        end
    end
    return equips
end
--得到背包里能合成equipSData的装备
function this.GetBagCompoundEquipDatasByequipSData(equipSData)
    
    local equips = {}
    local equipDatas = BagManager.GetBagItemDataByItemType(ItemBaseType.Equip)
    
    for i, v in ipairs(equipDatas) do
        local equipdata = this.GetSingleEquipData(v.id)
        if equipdata.equipConfig.Position == equipSData.Position and equipdata.equipConfig.Star == equipSData.Star - 1 then
            table.insert(equips, v)
        end
    end
    -- for i, v in ipairs(equips) do
    
    -- end
    return equips
end

--获取静态表中可合成装备静态信息
function this.GetAllSEquipsByPosition(_position)
    local starEquips = ConfigManager.GetAllConfigsDataByKey(ConfigName.EquipConfig, "Position", _position)

    local equips = {}
    for i = 1, #starEquips do
        if starEquips[i].Star and starEquips[i].Star > 0 and starEquips[i].Star ~= 1 then --最低等级的装备 合成不了
            table.insert(equips, starEquips[i])
        end
    end
    table.sort(
        equips,
        function(a, b)
            if a.Star == b.Star then
                return a.Id < b.Id
            else
                return a.Star < b.Star
            end
        end
    )
    
    -- for i = 1, #equips do
    
    -- end
    return equips
end

function this.SetEquipStarShow(starGrid, equipId)
    if equipConfig[equipId] then
        local curequipStarsConfig = equipStarsConfig[equipConfig[equipId].Star]
        if curequipStarsConfig then
            starGrid:SetActive(true)
            SetHeroStars(starGrid, curequipStarsConfig.Stars)
        end
    end
end

function this.GetMainProList(equipConfig)
    local propList = {}
    for index, prop in ipairs(equipConfig.Property) do
        propList[index] = {}
        propList[index].propertyId = prop[1]
        propList[index].propertyValue = prop[2]
        propList[index].PropertyConfig = propertyConfig[prop[1]]
    end
    return propList
end

function this.GetEquipRewardList(equiplist)
    local rewardlist = {}
    for k,v in ipairs(equiplist) do
        if v.itemConfig.ResolveReward and v.itemConfig.ResolveReward ~="" then 
            local rewardGroup =rewardGroupConfig[tonumber(v.itemConfig.ResolveReward)] 
            if rewardGroup and rewardGroup.ShowItem and #rewardGroup.ShowItem > 0 then               
                for i = 1,#rewardGroup.ShowItem do
                    local rewardId = rewardGroup.ShowItem[i][1]
                    local rewardNum = rewardGroup.ShowItem[i][2]
                    if rewardlist[rewardId] then
                        rewardlist[rewardId] = rewardlist[rewardId] + v.num * rewardNum
                    else
                        rewardlist[rewardId] = v.num * rewardNum
                    end
                end
            end
        end
    end
    return rewardlist
end

--页签红点
function this.RefreshEquipCompoundRedpoint(_pos)
    local bagPosEquips = EquipManager.GetEquipCompoundDataByEquipPosition1(_pos)
    local data = EquipManager.GetAllSEquipsByPosition(_pos)
    for i, v in ipairs(data) do
        local Config = equipStarsConfig[v.Star]
        if bagPosEquips[Config.Id - 1] and bagPosEquips[Config.Id - 1] >= equipStarsConfig[Config.Id - 1].RankupCount then
            local cost = equipStarsConfig[Config.Id - 1].RankupResources
            if BagManager.GetItemCountById(cost[1][1]) >= cost[1][2] then
                return true
            end
        end
    end
    return false
end

--刷新研究所装备红点
function this.RefreshAllEquipCompoundRedpoint()
    local state = false
    for i = 1, 4 do
        local red = this.RefreshEquipCompoundRedpoint(i)
        if red and not state then
            state = true
        end
    end
    return state
end

return this