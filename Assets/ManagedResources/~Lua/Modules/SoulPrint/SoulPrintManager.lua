SoulPrintManager = {};
local this = SoulPrintManager
local equipSignSetting = ConfigManager.GetConfig(ConfigName.EquipSignSetting)
local equipSign = ConfigManager.GetConfig(ConfigName.EquipSign)
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
this.soulPrintLevel = {}
this.soulEquipPool=0
local remainExp = {}
local currentNeedExp = {}
local currentProprty = {}



local singleSoulPrintData=
{
    sid = 0,
    heroDid = ""
}
--抽卡类型
ShowType = {
    showTip1 = 1, --替换
    showTip2 = 2, --装备
    showTip3 = 3, --只显示升级
    showTip4 = 4, --卸下
}

function this.Initialize()
    this.soulPrintData = {}
    this.soulPrintDataAll = {} --正式背包以及临时背包数据，用于数据详情显示
    this.hasUnlockPos = {}
    this.hasEquipSoulPrintId = {}
    this.mapShotTimeItemData = {}
    this.canIsEquipSoulPrint={} --带红点的魂印，能够上阵的
    this.chooseExpShow=0
    this.chooseLevelShow=0
    this.chooseExpUpLevel=0
end
function this.CreateSoulPrintData()
    return {
        --升级后剩余经验
        remainExp = nil,
        --魂印id
        id = nil,
        --魂印等级
        level = nil,
        --魂印动态Id
        did = nil,
        --魂印属性
        property = {},
        --魂印品质
        quality = nil,
        --魂印类型
        type = nil,
        --魂印提供经验
        giveExp = nil,
        --魂印名称
        name = nil,
        --魂印图标
        icon = nil,
        --魂印升级所需经验
        upLevelExp = nil,
        --魂印拥有经验
        haveExp=nil,
    }
end


--初始化服务器传过来的数据
function this.InitServerData(msg)
    for i, v in ipairs(msg) do
        this.UpSoulPrintLevel(v.equipId, v.exp)
        local soulPrintItemData = this.CreateSoulPrintData()
        soulPrintItemData.remainExp = remainExp[v.equipId]
        soulPrintItemData.haveExp=v.exp
        soulPrintItemData.id = v.equipId
        soulPrintItemData.level = this.soulPrintLevel[v.equipId]
        soulPrintItemData.did = v.id
        soulPrintItemData.icon = GetResourcePath(itemConfig[v.equipId].ResourceID)
        --soulPrintItemData.power = GetResourcePath(itemConfig[v.equipId].ResourceID)
        for m, n in ConfigPairs(equipSign) do
            if (n.Id == this.GetSoulPrintId(v.equipId, soulPrintItemData.level)) then
                soulPrintItemData.property = n.Property
                soulPrintItemData.quality = n.Quality
                soulPrintItemData.type = n.Type
                soulPrintItemData.giveExp = n.Resolve
                soulPrintItemData.name = n.Name
                soulPrintItemData.upLevelExp = n.Experience
            end
        end
        this.soulPrintData[v.id] = soulPrintItemData
        this.soulPrintDataAll[v.id] = soulPrintItemData
    end
end

----根据魂印Id得到拼接后想要的Id
function this.GetSoulPrintId(id, level)
    local strId = 0
    if (level <= 9) then
        strId = id .. "0" .. level
    else
        strId = id .. level
    end
    return tonumber(strId)
end


--根据品质类型分类显示魂印数据
---参数_type，_type=1(显示所有品质魂印数据),_type=2(显示绿色品质魂印数据),_type=3(显示蓝色品质魂印数据),_type=4(显示紫色品质魂印数据),_type=5(显示橙色品质魂印数据)
function this.GetSoulPrintQualityDataByType(_type)
    _type = _type + 1
    local showData = {}
    for i, v in pairs(this.soulPrintData) do
        if (v.quality == _type) then
            table.insert(showData, v)
        end
    end
    if (_type == 1) then
        showData = this.soulPrintData
    end
    return showData
end

--根据玩家等级，猎妖师星级判断魂印槽位是否解锁
function this.UnLockSoulPrintPos(chooseHeroData)
    local roleLv = PlayerManager.level
    local heroStar = chooseHeroData.star
    this.hasUnlockPos = {}
    for i, v in ConfigPairs(equipSignSetting) do
        if (v.OpenRules[1] == 1 and roleLv >= v.OpenRules[2]) then
            table.insert(this.hasUnlockPos, v.SlotPosition)
        end
        if (v.OpenRules[1] == 2 and heroStar >= v.OpenRules[2]) then
            table.insert(this.hasUnlockPos, v.SlotPosition)
        end
    end
end



--根据魂印类型,英雄Id判断是否是替换魂印还是装备魂印，返回其位置
function this.GetSoulPrintPos(_type, _heroId)
    --是否有同类型魂印
    local haveType = false
    --有同类型的
    if (table.nums(this.hasEquipSoulPrintId[_heroId]) >= 1) then
        for i, v in pairs(this.hasUnlockPos) do
            for m, n in pairs(this.hasEquipSoulPrintId[_heroId]) do
                if (_type == this.soulPrintData[n.did].type) then
                    haveType = true
                    return { position = n.pos, showType = ShowType.showTip1 }  --显示替换，和替换的位置
                end
            end
        end
    end
    --无同类型的
    if (not haveType) then
        --无空槽，没有同类型的，则不显示替换
        if (#this.hasUnlockPos == table.nums(this.hasEquipSoulPrintId[_heroId])) then
            for i, v in pairs(this.hasUnlockPos) do
                return { position = 0, showType = ShowType.showTip3 }  --只显示升级
            end
        end
        local canInsertPos = {}
        for i, v in ipairs(this.hasUnlockPos) do
            table.insert(canInsertPos, v)
        end
        --有空槽，没有同类型的，则不显示替换
        for i, v in pairs(canInsertPos) do
            for m, n in pairs(this.hasEquipSoulPrintId[_heroId]) do
                if (v == n.pos) then
                    canInsertPos[i]=nil
                end
            end
        end
        local isCanInsertPos={}
        for i, v in pairs(canInsertPos) do
            table.insert(isCanInsertPos,v)
        end
        if (#this.hasUnlockPos > table.nums(this.hasEquipSoulPrintId[_heroId])) then
            return { position = isCanInsertPos[1], showType = ShowType.showTip2 }  --显示装备，和装备的位置
        end
    end
    --return { position = 1, showType = ShowType.showTip2 } --显示装备，和装备的位置
end

--根据英雄Id返回可以上阵的高战力的soulPrintIdList
function this.GetCanEquipSoulPrintIdList(_heroId)
    local heroData=HeroManager.GetSingleHeroData(_heroId)
    if(heroData) then
        SoulPrintManager.UnLockSoulPrintPos(heroData)
        if(table.nums(this.hasUnlockPos)<1) then
            return {}
        end
    else
        return {}
    end
    local canIsEquipSoulPrint = {}
    local isSortData = {}
    local isCanInsert = true
    isSortData = this.GetSoulPrintAndSortData(this.soulPrintData, _heroId)
    table.sort(isSortData, function(a, b)
        return this.CalculateSoulPrintAddVal(a.did) > this.CalculateSoulPrintAddVal(b.did)
    end)
    for i, v in ipairs(isSortData) do
        if (canIsEquipSoulPrint) then
            isCanInsert = true
            for n, m in pairs(canIsEquipSoulPrint) do
                if this.soulPrintData[m].type == v.type then
                    isCanInsert = false
                end
            end
        end
        if (isCanInsert and table.nums(canIsEquipSoulPrint) < #this.hasUnlockPos) then
            canIsEquipSoulPrint[v.did] =v.did
        end
    end

    for i, v in pairs(this.hasEquipSoulPrintId[_heroId]) do
        for m, n in pairs(canIsEquipSoulPrint) do
            if (this.CalculateSoulPrintAddVal(v.did) ==this.CalculateSoulPrintAddVal(m)) then
                canIsEquipSoulPrint[m] = nil
            end
        end
    end
    this.canIsEquipSoulPrint=canIsEquipSoulPrint
    return canIsEquipSoulPrint
end


--根据魂印id获得单个魂印数据
function this.GetSoulPrintSingleData(_id)
    local itemData = BagManager.GetBagItemDataByItemType(6)
    for i, v in pairs(itemData) do
        if (v.id == _id) then
            return v
        end
    end
end
--根据魂印动态id获得魂印属性数据
function this.GetSoulPrintPropertyData(_id)
    --for i, v in pairs(this.soulPrintDataAll) do
    --    if (v.did == _id) then
    --        return v.property
    --    end
    --end
    return equipConfig[_id].Property
end

--根据魂印静态id获得魂印属性数据
function this.GetStaticSoulPrintPropertyData(_id)
    for m, n in ConfigPairs(equipSign) do
        if (n.Id == this.GetSoulPrintId(_id, 1)) then
            return n.Property
        end
    end
end


--通过魂印Id计算该魂印加成的战力
function this.CalculateSoulPrintAddVal(_soulPrintId)
    local powerEndVal = 0
    if equipConfig[_soulPrintId] then
        powerEndVal = equipConfig[_soulPrintId].Score
    end
    --local addAllProVal = {}
    --local soulPrintPropertyList = {}
    --soulPrintPropertyList = this.GetSoulPrintPropertyData(_soulPrintId)
    --if soulPrintPropertyList and #soulPrintPropertyList > 0 then
    --    for i, v in pairs(soulPrintPropertyList) do
    --        if (addAllProVal[v[1]]) then
    --            addAllProVal[v[1]] = v[2] + addAllProVal[v[1]]
    --        else
    --            addAllProVal[v[1]] = v[2]
    --        end
    --    end
    --end
    --local powerEndVal = 0
    --for i, v in pairs(addAllProVal) do
    --    if v > 0 then
    --        local curProConfigData = ConfigManager.GetConfigData(ConfigName.PropertyConfig, i)
    --        if curProConfigData then
    --            if curProConfigData.Style == 1 then
    --                powerEndVal = powerEndVal + v * HeroManager.heroPropertyScore[i]
    --            else
    --                powerEndVal = powerEndVal + (v / 10000) * HeroManager.heroPropertyScore[i] * 100
    --            end
    --        end
    --    end
    --end
    return math.floor(powerEndVal)
end
--计算静态魂印战力显示
function this.CalculateStaticSoulPrintAddVal(_id)
    local addAllProVal = {}
    local soulPrintPropertyList = {}
    soulPrintPropertyList = this.GetStaticSoulPrintPropertyData(_id)
    for i, v in pairs(soulPrintPropertyList) do
        if (addAllProVal[v[1]]) then
            addAllProVal[v[1]] = v[2] + addAllProVal[v[1]]
        else
            addAllProVal[v[1]] = v[2]
        end
    end
    local powerEndVal = 0
    for i, v in pairs(addAllProVal) do
        if v > 0 then
            local curProConfigData = ConfigManager.GetConfigData(ConfigName.PropertyConfig, i)
            if curProConfigData then
                if curProConfigData.Style == 1 then
                    powerEndVal = powerEndVal + v * HeroManager.heroPropertyScore[i]
                else
                    powerEndVal = powerEndVal + (v / 10000) * HeroManager.heroPropertyScore[i] * 100
                end
            end
        end
    end
    return math.floor(powerEndVal)
end




--穿戴魂印(包括替换和一件装备)
---参数soulPrintIdList(key为魂印id，value为魂印装备位置)
function this.SoulEquipWearRequest(_heroId, soulPrintIdList, OneKey, func)
    NetManager.SoulEquipWearRequest(_heroId, soulPrintIdList, OneKey, function(msg)
        local soulPrintList = {}
        if (OneKey == 1) then
            this.hasEquipSoulPrintId[_heroId] = {}
        end
        for i, v in pairs(soulPrintIdList) do
            local soulPrint = { did = i, pos = v }
            table.insert(soulPrintList, soulPrint)
            if (table.nums(this.hasEquipSoulPrintId[_heroId])) then
                for m, n in pairs(this.hasEquipSoulPrintId[_heroId]) do
                    if (this.soulPrintData[n.did].type ~= this.soulPrintData[i].type) then
                        table.insert(soulPrintList, n)
                    end
                end
            end
        end
        this.hasEquipSoulPrintId[_heroId] = soulPrintList
        HeroManager.UpdateHeroSingleSoulPrint(_heroId, this.hasEquipSoulPrintId)
        HeroManager.CompareWarPower(_heroId)
        if func then
            func()
        end
    end)
end
--卸下魂印
---参数soulPrintIdList(key为魂印id，value为魂印装备位置)
function this.SoulEquipUnLoadWearRequest(_heroId, soulPrintIdList, func)
    NetManager.SoulEquipUnLoadWearRequest(_heroId, soulPrintIdList, function(msg)
        if (table.nums(soulPrintIdList) <= 1) then
            for i, v in pairs(this.hasEquipSoulPrintId[_heroId]) do
                for m, n in pairs(soulPrintIdList) do
                    if (v.did == m) then
                        this.hasEquipSoulPrintId[_heroId][i] = nil
                    end
                end
            end
        else
            this.hasEquipSoulPrintId[_heroId] = {}
        end
        HeroManager.UpdateHeroSingleSoulPrint(_heroId, this.hasEquipSoulPrintId)
        HeroManager.CompareWarPower(_heroId)
        if func then
            func()
        end
    end)
end
--魂印快速升级请求
---参数soulPrintId(要升级魂印的did),soulEquipIds(消耗的魂印did集合)
function this.UpQuickSoulEquipRequest(soulPrintDid, soulEquipIds, _heroId, func)
    NetManager.UpQuickSoulEquipRequest(soulPrintDid, soulEquipIds, function(msg)
        for i, v in pairs(soulEquipIds) do
            if (soulPrintDid == i) then

            end
        end
        this.soulPrintData[soulPrintDid].haveExp=msg.exp
        this.UpSoulPrintLevel(this.soulPrintData[soulPrintDid].id, msg.exp)
        this.soulPrintData[soulPrintDid].remainExp = remainExp[this.soulPrintData[soulPrintDid].id]
        if (msg.leve > this.soulPrintData[soulPrintDid].level) then
            this.soulPrintData[soulPrintDid].level = msg.leve
            this.soulPrintData[soulPrintDid].upLevelExp = currentNeedExp[this.soulPrintData[soulPrintDid].id]
            this.soulPrintData[soulPrintDid].property = currentProprty[this.soulPrintData[soulPrintDid].id]
            if (this.IsHaveEquip(soulPrintDid)) then
                --魂印升级时只有穿在身上的才会刷新战力
                HeroManager.UpdateHeroSingleSoulPrint(_heroId, this.hasEquipSoulPrintId)
                HeroManager.CompareWarPower(_heroId)
            end
        end
        for i, v in pairs(msg.soulEquipIds) do
            this.soulPrintData[v] = nil
        end
        if func then
            func()
        end
    end)
end

--将传入的魂印Id集合转换为经验(idlist:key为id,value为等级)
function this.ExChangeSoulPrintToExp(idList)
    local getExpAll = 0
    for i, v in ConfigPairs(equipSign) do
        for m, n in pairs(idList) do
            if (n == v.Id) then
                getExpAll = getExpAll + v.Resolve
            end
        end
    end
    return getExpAll
end
--通过传入魂印经验提升魂印等级,及剩余经验
function this.UpSoulPrintLevel(_id, _exp)
    local currentExp = 0
    local index = 0
    local isEnter = false
    this.chooseExpShow=0
    this.chooseLevelShow=0
    this.chooseExpUpLevel=0
    for i, v in ConfigPairs(equipSign) do
        index = index + 1
        if (_id == math.floor(v.Id / 100)) then
            currentExp = v.Experience + currentExp
            if (equipSign[i + 1]) then
                if (_exp >= currentExp and _exp < currentExp + equipSign[i + 1].Experience) then
                    this.soulPrintLevel[_id] = v.Level + 1
                    remainExp[_id] = (_exp - currentExp)
                    currentNeedExp[_id] = equipSign[i + 1].Experience
                    currentProprty[_id] = equipSign[i + 1].Property
                    isEnter = true
                end
            end
        end
    end
    if (not isEnter) then
        this.soulPrintLevel[_id] = 1
        remainExp[_id] = _exp
        currentNeedExp[_id] = equipSign[this.GetSoulPrintId(_id, 1)].Experience
        currentProprty[_id] = equipSign[this.GetSoulPrintId(_id, 1)].Property
        this.chooseExpUpLevel=currentNeedExp[_id]
    end
    if (_exp >= currentExp) then
        for i, v in ConfigPairs(equipSign) do
            if (_id == math.floor(v.Id / 100)) then
                this.soulPrintLevel[_id] = v.Level
                remainExp[_id] = v.Experience
                currentNeedExp[_id] = v.Experience
                currentProprty[_id] = v.Property
            end
        end
    end
    this.chooseExpUpLevel=currentNeedExp[_id]
    this.chooseExpShow=remainExp[_id]
    this.chooseLevelShow=this.soulPrintLevel[_id]
end
--通过传入英雄Id，得到加成属性
function this.GetPropertyTotalShow(_heroId)
    local addAllProVal = {}
    local curHeroData = HeroManager.GetSingleHeroData(_heroId)
    if curHeroData then
        for i, v in pairs(curHeroData.soulPrintIdList) do
            local soulPrintPropertyList = {}
            soulPrintPropertyList = SoulPrintManager.GetSoulPrintPropertyData(v)
            for i, v in pairs(soulPrintPropertyList) do
                if (addAllProVal[v[i][1]]) then
                    addAllProVal[v[i][1]] = v[i][2] + addAllProVal[v[i][1]]
                else
                    addAllProVal[v[i][1]] = v[i][2]
                end
            end
        end
    end
    return addAllProVal
end
--判断是否为带红点的魂印
function this.IsRedEquipSoulPrint(did)
    local isShowRed=false
    for i,v in pairs(this.canIsEquipSoulPrint) do
        if(did==v) then
            isShowRed=true
        end
    end
    return isShowRed
end
--将魂印数据转化为能够循环滚动的数据并按照品质排序(删除已被装备数据)
function this.GetSoulPrintLevelAndSort(soulPrintData)
    local soulDataFinal = {}
    for i, v in pairs(soulPrintData) do
        if (not this.IsHaveEquip(v.did)) then
            table.insert(soulDataFinal, v)
        end
    end
    table.sort(soulDataFinal,
            function(a, b)
                if (a.quality == b.quality) then
                    -- if (a.level < b.level) then
                    --     return a.level < b.level
                    -- elseif (a.level == b.level) then
                    --     return a.id < b.id
                    -- end
                else
                    return a.quality < b.quality
                end
            end)
    return soulDataFinal
end


--将魂印数据转化为能够循环滚动的数据并按照品质排序(删除已被装备数据)
function this.GetSoulPrintAndSort(soulPrintData)
    local soulDataFinal = {}
    for i, v in pairs(soulPrintData) do
        if (not this.IsHaveEquip(v.did) and not this.IsRedEquipSoulPrint(v.did)) then
            table.insert(soulDataFinal, v)
        end
    end
    table.sort(soulDataFinal,
            function(a, b)
                if (a.quality == b.quality) then
                    if (a.level > b.level) then
                        return a.level > b.level
                    elseif (a.level == b.level) then
                        return a.id > b.id
                    end
                else
                    return a.quality > b.quality
                end
            end)
    local index=0
    for i,v in pairs(this.canIsEquipSoulPrint) do
        index=index+1
        table.insert(soulDataFinal,index,this.soulPrintData[v])
    end
    return soulDataFinal
end
--将魂印数据转化为能够循环滚动的数据并按照品质排序(删除其他英雄装备数据)
function this.GetSoulPrintAndSortData(soulPrintData, heroId)
    local soulDataFinal = {}
    for i, v in pairs(soulPrintData) do
        if (not this.IsHaveEquip(v.did)) then
            table.insert(soulDataFinal, v)
        end
        for m, n in pairs(this.hasEquipSoulPrintId[heroId]) do
            if (n.did == v.did) then
                table.insert(soulDataFinal, v)
            end
        end
    end

    table.sort(soulDataFinal,
            function(a, b)
                if (a.quality == b.quality) then
                    if (a.level > b.level) then
                        return a.level > b.level
                    elseif (a.level == b.level) then
                        return a.id > b.id
                    end
                else
                    return a.quality > b.quality
                end
            end)
    return soulDataFinal
end




--设置已穿戴魂印数据
function this.SetSoulPrintUpHeroDid(soulPos, heroDid)
    this.hasEquipSoulPrintId[heroDid] = soulPos
end
--根据魂印did判断其是否已装备
function this.IsHaveEquip(soulPrintDid)
    if (table.nums(this.hasEquipSoulPrintId) >= 1) then
        for i, v in pairs(this.hasEquipSoulPrintId) do
            for m, n in pairs(v) do
                if (soulPrintDid == n.did) then
                    return true
                end
            end
        end
    end
    return false
end
--通过传入升级需要的经验得到消耗魂印的Id集合
function this.GetCostSoulPrintIdList(needExp, soulPrintData)
    table.sort(soulPrintData,
            function(a, b)
                if (a.quality == b.quality) then
                    if (a.level < b.level) then
                        return a.level < b.level
                    elseif (a.level == b.level) then
                        return a.id < b.id
                    end
                else
                    return a.quality < b.quality
                end
            end)
    local giveExp = 0
    local costIdList = {}
    local isEnter = false
    for i, v in ipairs(soulPrintData) do
        giveExp = giveExp + v.giveExp
        costIdList[v.did]= v.id
        if (giveExp >= needExp) then
            isEnter = true
            return costIdList
        end
    end
    if (not isEnter) then
        return costIdList
    end
end

--通过传入分解的魂印Id移除魂印
function this.RemoveSoulPrint(idlist)
    for i, m in pairs(idlist) do
        for i, v in pairs(this.soulPrintData) do
            if (v.did == m) then
                this.soulPrintData[v.did] = nil
            end
        end
    end
end
--通过传入魂印id，获得其需要替换的已装备的魂印id
function this.GetEquipSoulPrintId(did, heroId)
    for i, v in pairs(SoulPrintManager.hasEquipSoulPrintId[heroId]) do
        if (this.soulPrintData[did].type == this.soulPrintData[v.did].type) then
            return v.did
        end
    end
end
--地图临时魂印数据存储
function this.InitMapShotTimeSoulPrintBagData(_soulPrintData)
    this.mapShotTimeItemData[#this.mapShotTimeItemData + 1] = _soulPrintData
end
--通过传入的属性获得显示的属性数据
function this.GetShowPropertyData(propertyIndex, propertyNum)
    if (propertyConfig[propertyIndex].Style == 1) then
        local propertyName = propertyConfig[propertyIndex].Info
        local propertyNum = "+" .. propertyNum
        return { name = propertyName, num = propertyNum }
    else
        local propertyName = propertyConfig[propertyIndex].Info
        local propertyNum = "+" .. (propertyNum / 10000) * 100 .. "%"
        return { name = propertyName, num = propertyNum }
    end
end
--获得用于背包显示数据组装
function this.GetBagShowData(data)
    local showData = this.GetSoulPrintAndSort(data)
    local itemDataList = {}
    for i, v in ipairs(showData) do
        local itemdata = {}
        itemdata.itemType = 13--魂印
        itemdata.backData = v
        itemdata.level = v.level
        itemdata.id=v.id
        local id = this.GetSoulPrintId(v.id, itemdata.level)
        itemdata.configData = ConfigManager.GetConfigData(ConfigName.EquipSign, id)
        itemdata.name = itemdata.configData.Name
        itemdata.itemConfig = itemConfig[v.id]
        itemdata.frame = GetHeroQuantityImageByquality(v.quality)
        itemdata.Image_bg = GetQuantityBgImageByquality(v.quality)
        itemdata.Image_proBg = GetQuantityProBgImageByquality(v.quality)
        itemdata.quality = v.quality
        itemdata.icon = v.icon
        itemdata.num = 1
        itemdata.property = v.property
        itemdata.did = v.did
        table.insert(itemDataList, itemdata)
    end
    return itemDataList
end
--通过魂印类型获得魂印id最高等级
function this.GetSoulPrintMaxLevel(soulPrintId)
    local maxLevel = 0
    for i, v in ConfigPairs(equipSign) do
        local id = tonumber(string.sub(v.Id, 1, -3))
        if (id == soulPrintId) then
            maxLevel = v.Level
        end
    end
    return maxLevel
end

--将临时背包的掉落数据以及正式背包的掉落数据存起来以便显示属性
function this.StoreData(msg)
    for i, v in ipairs(msg) do
        this.UpSoulPrintLevel(v.equipId, v.exp)
        local soulPrintItemData = this.CreateSoulPrintData()
        soulPrintItemData.remainExp = remainExp[v.equipId]
        soulPrintItemData.id = v.equipId
        soulPrintItemData.level = this.soulPrintLevel[v.equipId]
        soulPrintItemData.did = v.id
        soulPrintItemData.icon = GetResourcePath(itemConfig[v.equipId].ResourceID)
        for m, n in ConfigPairs(equipSign) do
            if (n.Id == this.GetSoulPrintId(v.equipId, soulPrintItemData.level)) then
                soulPrintItemData.property = n.Property
                soulPrintItemData.quality = n.Quality
                soulPrintItemData.type = n.Type
                soulPrintItemData.giveExp = n.Resolve
                soulPrintItemData.name = n.Name
                soulPrintItemData.upLevelExp = n.Experience
            end
        end
        this.soulPrintDataAll[v.id] = soulPrintItemData
    end
end
--通过传入魂印Id组装数据，用于显示静态背包数据
function this.GetStaticBagShowData(_id, level)
    local itemdata = {}
    itemdata.itemType = 5--魂印
    itemdata.level = level
    local id = this.GetSoulPrintId(_id, itemdata.level)
    itemdata.configData = ConfigManager.GetConfigData(ConfigName.EquipSign, id)
    itemdata.name = itemdata.configData.Name
    itemdata.quality = itemdata.configData.Quality
    itemdata.icon = GetResourcePath(itemConfig[_id].ResourceID)
    itemdata.property = itemdata.configData.Property
    itemdata.itemConfig = itemConfig[_id]
    return itemdata
end


-----------新魂印开始
local allSoulPrintUpHeros = {}-- soulPrintSid = {heroDid,heroDid,heroDid}
--增加魂印装备的英雄did
function this.AddSoulPrintUpHeroDynamicId(soulPrintSid, heroDid)
    if allSoulPrintUpHeros[soulPrintSid] then
        table.insert(allSoulPrintUpHeros[soulPrintSid],heroDid)
    else
        allSoulPrintUpHeros[soulPrintSid] = {}
        table.insert(allSoulPrintUpHeros[soulPrintSid],heroDid)
    end
end
function this.GetCurSoulPrintIsCanUp(soulPrintSid)
    if allSoulPrintUpHeros[soulPrintSid] and allSoulPrintUpHeros[soulPrintSid][1] and allSoulPrintUpHeros[soulPrintSid][1]~=""  then
        if equipConfig[soulPrintSid].limit == 1 then
            return false
        else
            return true
        end
    else
        return true
    end
end
--删除魂印装备的英雄did
function this.DelSoulPrintUpHeroDynamicId(soulPrintSid, heroDid)
    if allSoulPrintUpHeros[soulPrintSid] then
        for i = 1, #allSoulPrintUpHeros[soulPrintSid] do
            if allSoulPrintUpHeros[soulPrintSid][i] == heroDid then
                table.remove(allSoulPrintUpHeros[soulPrintSid],i)
            end
        end
    end
end
--获取所有魂印 isUpHero 布尔值 是否显示装备中的魂印   heroSId 此类英雄可穿的魂印  heroDid不算自身带的
function this.GetAllSoulPrint(isUpHero,heroSId,_heroDid)
    local heroDid = _heroDid or ""
    local allData= {}
    local bagAllData = BagManager.GetBagAllDataByItemType(ItemType.HunYin)--背包所有
    if bagAllData and #bagAllData > 0 then
        for i = 1, #bagAllData do
            for j = 1, bagAllData[i].num do
                if heroSId then
                    local Range = equipConfig[bagAllData[i].id].Range
                    if Range and #Range > 0 and Range[1] > 0 then--此魂印能装备那些英雄
                        for k = 1, #Range do
                            if Range[k] == heroSId then
                                local singleSoulPrint = {id = bagAllData[i].id,upHero = ""}
                                table.insert(allData,singleSoulPrint)
                            end
                        end
                    else--此魂印能装备所有英雄
                        local singleSoulPrint = {id = bagAllData[i].id,upHero = ""}
                        table.insert(allData,singleSoulPrint)
                    end
                else--没有可穿英雄限制
                    local singleSoulPrint = {id = bagAllData[i].id,upHero = ""}
                    table.insert(allData,singleSoulPrint)
                end
            end
        end
    end
    if isUpHero then--显示装备中的魂印  显示其他英雄身上装的魂印
        for soulPrintSid, heroDids in pairs(allSoulPrintUpHeros) do
            for i = 1, #heroDids do
                if heroSId then
                    local Range = equipConfig[soulPrintSid].Range
                    if Range and #Range > 0 and Range[1] > 0 then
                        for k = 1, #Range do
                            if Range[k] == heroSId and heroDid ~= heroDids[i] then  --这个魂印能装在这个英雄身上并且没有装在这个英雄身上
                                local singleSoulPrint = {id = soulPrintSid,upHero = heroDids[i]}
                                table.insert(allData,singleSoulPrint)
                            end
                        end
                    else
                        if  heroDid ~= heroDids[i] then --这个魂印能装在所有英雄身上并且没有装在这个英雄身上
                            local singleSoulPrint = {id = soulPrintSid,upHero = heroDids[i]}
                            table.insert(allData,singleSoulPrint)
                        end
                    end
                else  --这个魂印没有装在这个英雄身上
                    if  heroDid ~= heroDids[i] then
                        local singleSoulPrint = {id = soulPrintSid,upHero = heroDids[i]}
                        table.insert(allData,singleSoulPrint)
                    end
                end
            end
        end
    end
    table.sort(allData, function(a,b)   
        return equipConfig[a.id].Quality > equipConfig[b.id].Quality            
    end)
    return allData
end
function this.SetIsShowUpHeroSoulPrintPlayerPrefs(val)
    PlayerPrefs.SetString(PlayerManager.uid..PlayerManager.serverInfo.server_id.."soulprint", val)
end
--获得本地存储字符串
function this.GetIsShowUpHeroSoulPrintPlayerPrefs()
    return PlayerPrefs.GetString(PlayerManager.uid..PlayerManager.serverInfo.server_id.."soulprint", 0)
end

--获取魂印是否开启
function this.GetSoulPrintIsOpen(curHeroData)
    local EquipSignUnlock = ConfigManager.GetConfigData(ConfigName.GameSetting,1).EquipSignUnlock
    return (PlayerManager.level>=EquipSignUnlock[1][2]) and (curHeroData.star>=EquipSignUnlock[2][2])
end
-----------新魂印结束

return this