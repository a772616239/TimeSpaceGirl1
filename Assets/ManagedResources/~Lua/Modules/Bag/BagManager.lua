BagManager = {}
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)
local equipSign = ConfigManager.GetConfig(ConfigName.EquipSign)
local this = BagManager
this.bagDatas = {}
--地图临时背包数据
this.mapShotTimeItemData = {}
--天赋材料消耗组
this.tianFuMaterial = {}
this.needEndingTime = 0

function this.Initialize()
    this.isBagPanel = false
end

--初始化背包数据
function this.InitBagData(_msgItemList)
    for i = 1, #_msgItemList do
        this.UpdateBagData(_msgItemList[i], true)
    end
end

--更新背包数据
function this.UpdateBagData(_itemData, isNoSendNewItemEvent)
    isNoSendNewItemEvent = isNoSendNewItemEvent or false
    local itemdata = {}
    
    local _itemCfgData = itemConfig[_itemData.itemId]
    if _itemCfgData ~= nil then
        itemdata.itembackData = _itemData
        itemdata.itemConfig = _itemCfgData
        itemdata.id = _itemCfgData.Id
        itemdata.property = {}
        if _itemCfgData.ResourceID and _itemCfgData.ResourceID > 0 then
            itemdata.icon = GetResourcePath(_itemCfgData.ResourceID)
        else
            itemdata.icon = GetResourcePath(10002)
        end
        itemdata.quality = _itemCfgData.Quantity
        itemdata.frame = GetQuantityImageByquality(_itemCfgData.Quantity)
        itemdata.Image_proBg = GetQuantityProBgImageByquality(_itemCfgData.Quantity)
        itemdata.type = _itemCfgData.ItemBaseType
        itemdata.itemType = _itemCfgData.ItemType
        -- if _itemCfgData.ItemBaseType == ItemBaseType.Equip then
        
        -- end
        itemdata.isBag = _itemCfgData.BackpackOrNot
        itemdata.num = _itemData.itemNum
        itemdata.endingTime = _itemData.endingTime
        itemdata.nextFlushTime = _itemData.nextFlushTime
        if itemdata.id == 54 then
            this.needEndingTime = itemdata.endingTime
        end
        if this.bagDatas[itemdata.id] == nil then
            this.bagDatas[itemdata.id] = itemdata
            if not isNoSendNewItemEvent then
                Game.GlobalEvent:DispatchEvent(GameEvent.Bag.GetNewItem, itemdata.id)
            end
        else
            this.bagDatas[itemdata.id].num = itemdata.num
            this.bagDatas[itemdata.id].endingTime = itemdata.endingTime
            this.bagDatas[itemdata.id].nextFlushTime = itemdata.nextFlushTime
        end
    end

    -- 货币数据
    if itemdata.itemId == 14 or itemdata.itemId == 16 then
        -- ThinkingAnalyticsManager.SetSuperProperties({
        --     coins_amount = BagManager.GetItemCountById(14),
        --     diamond_amount = BagManager.GetItemCountById(16),
        -- })
    end
end

---英雄副本独用刷新
function this.UpDataBagItemIdNumber(_itemData)
    this.UpdateBagData(_itemData)
    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
end

--后端刷新
function this.BackDataRefreshEnerny(msgItemInfo)
    if msgItemInfo and #msgItemInfo > 0 then
        for i = 1, #msgItemInfo do
            --存储
            if this.bagDatas[msgItemInfo[i].templateId] then
                this.bagDatas[msgItemInfo[i].templateId].num = msgItemInfo[i].overlap
                this.bagDatas[msgItemInfo[i].templateId].nextFlushTime = msgItemInfo[i].nextRefreshTime
            end
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
    end  
end

--通过物品ID返回下次刷新时间（幸运探宝用）
function this.GetNextRefreshTime(_itemId)
    if this.bagDatas[_itemId] then
        return this.bagDatas[_itemId].nextFlushTime
    end
end

--通过物品id获取物品数量
function this.GetItemCountById(_itemId)
    local have = 0
    if this.bagDatas[_itemId] then
        have = this.bagDatas[_itemId].num
    end
    return have
end

--通过物品id获取物品数量
function this.GetItemById(_itemId)
    return this.bagDatas[_itemId]
end

-- 通过物品ID获得临时背包物品
function this.GetTempBagCountById(_itemId)
    if this.mapShotTimeItemData[_itemId] then
        return this.mapShotTimeItemData[_itemId].itemNum
    end
    return 0
end
--通过物品Id获得临时背包物品的恢复时间
function this.GetItemRecoveryTime(_itemId)
    if this.bagDatas[_itemId] then
        return (AdventureManager.callAlianInvasionCountDownTime - (PlayerManager.serverTime - this.needEndingTime))
    end
end

--临时背包
function this.DeleteTempBagCountById(_itemId, deleteNum)
    --if this.mapShotTimeItemData[_itemId] then
    --    if this.mapShotTimeItemData[_itemId].itemNum >= deleteNum then
    --        this.mapShotTimeItemData[_itemId].itemNum = this.mapShotTimeItemData[_itemId].itemNum - deleteNum
    --    else
    --        this.mapShotTimeItemData[_itemId] = nil
    --    end
    --end
    --Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnTempBagChanged)
end

--英雄升级专用通过物品id更新物品数量 0 时删除
function this.HeroLvUpUpdateItemsNum(_itemId, deleteNum)
    if this.bagDatas[_itemId] then
        this.bagDatas[_itemId].num = this.bagDatas[_itemId].num - deleteNum

        if this.bagDatas[_itemId].num < 0 then
            this.bagDatas[_itemId].num = 0

        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
    else

    end
end

--通过物品id更新物品数量 0 时删除
function this.UpdateItemsNum(_itemId, deleteNum)
    --if _itemId == 2 then
    --    PlayerManager.PromoteLevel(deleteNum)
    --end
    --改为后端刷新了  但是体力得从这减
    --if this.bagDatas[_itemId] then
    --    this.bagDatas[_itemId].num = this.bagDatas[_itemId].num - deleteNum
    --    if _itemId == 2 then
    --        PlayerManager.PromoteLevel(deleteNum)
    --    end
    
    --    if this.bagDatas[_itemId].num < 0 then
    --        this.bagDatas[_itemId].num = 0
    
    --    end
    --    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
    --else
    
    --end
end

-- 消耗背包物品，先消耗临时背包，再消耗总背包
function this.SpendBagItem(itemId, deleteNum)
    -- 当前临时背包数据
    --if this.mapShotTimeItemData[itemId] then
    --    local tempBagNum = this.mapShotTimeItemData[itemId].itemNum
    --    if tempBagNum >= deleteNum then
    --        -- 临时背包数据充足
    --        tempBagNum = tempBagNum - deleteNum
    --        -- 道具刚好消耗完
    --        if tempBagNum == 0 then
    --            this.mapShotTimeItemData[itemId] = nil
    --        else
    --            this.mapShotTimeItemData[itemId].itemNum = tempBagNum
    --        end
    --    else
    --        -- 临时背包数量不充足
    --        local leftNeed = deleteNum - this.mapShotTimeItemData[itemId].itemNum
    --        this.mapShotTimeItemData[itemId] = nil
    --        this.UpdateItemsNum(itemId, leftNeed)
    --    end
    --else
    --    -- 临时背包无此道具
    --    this.UpdateItemsNum(itemId, deleteNum)
    --end
end

-- 获得临时背包和外部背包的总数量
function this.GetTotalItemNum(itemId)
    local totalnum = 0
    if this.GetTempBagCountById(itemId) and this.GetItemCountById(itemId) then
        totalnum = this.GetTempBagCountById(itemId) + this.GetItemCountById(itemId)
    else
        if not this.GetTempBagCountById(itemId) or this.GetTempBagCountById(itemId) == 0 then
            totalnum = this.GetItemCountById(itemId)
        end
    end
    return totalnum
end

--增加体力
function this.UpdateAddTiliNum(addNum)
    if this.bagDatas[2] then
        this.bagDatas[2].num = this.bagDatas[2].num + addNum
    else
        local itemData = {}
        itemData.itemId = 2
        itemData.itemNum = addNum
        this.UpdateBagData(itemData)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
end
--获取所有背包物品
function this.GetBagItemData()
    local _index = 1
    local _bagItemData = {}
    for i, v in pairs(this.bagDatas) do
        if v.isBag and v.num > 0 then
            _bagItemData[_index] = v
            _index = _index + 1
        end
    end
    return _bagItemData
end

--获取背包中所有的碎片
function this.GetBagDebrisItemData(propertyType)
    local _index = 1
    local _DebrisItemData = {}
    for i, v in pairs(this.bagDatas) do
        if v.itemConfig.ItemType == 2 and v.num > 0  then
            if propertyType == 0 then
                table.insert(_DebrisItemData, v)
            else
                if v.itemConfig.PropertyName == propertyType then
                    table.insert(_DebrisItemData, v)
                end
            end
        end
    end
    return _DebrisItemData
end

--通过背包物品品质获得物品list
function this.GetBagItemDataByItemQuality(_itemQuality)
    local _bagItemData = this.GetBagItemData()
    local items = {}
    local index = 1
    for i, v in pairs(_bagItemData) do
        if v.quality == _itemQuality and v.num > 0 then
            items[index] = v
            index = index + 1
        end
    end
    return items
end
--获得背包所有可携带入地图的物品list
function this.GetBagItemDataByItemMapIsShow()
    local items = {}
    local index = 1
    for i, v in pairs(this.bagDatas) do
        if v.itemConfig.IsShow then
            if v.itemConfig.IsShow == 1 then
                local itemdata = {}
                itemdata.itemType = 1 -- 物品道具
                itemdata.backData = v.itembackData
                itemdata.configData = v.itemConfig
                itemdata.name = v.itemConfig.Name
                itemdata.frame = GetQuantityImageByquality(v.itemConfig.Quantity)
                itemdata.Image_proBg = GetQuantityProBgImageByquality(v.itemConfig.Quantity)
                itemdata.icon = GetResourcePath(v.itemConfig.ResourceID)
                itemdata.num = v.num
                items[index] = itemdata
                index = index + 1
            end
        end
    end
    return items
end
--通过物品类型获得物品list
function this.GetBagItemDataByItemType(_itemType)
    local items = {}
    local index = 1
    for i, v in pairs(this.bagDatas) do
        if v.type == _itemType and v.num > 0 and v.itemConfig.BackpackOrNot then
            items[index] = v
            index = index + 1
        end
    end
    return items
end

--获取所有的魂印
function this.GetAllSoulPrintData(quality)
    local items = {}
    local index = 1
    for i, v in pairs(this.bagDatas) do
        if v.type == ItemBaseType.SoulPrint and v.num > 0 then
            if not quality or quality == 0 then
                for n = 1, v.num do
                    local itemdata = {}
                    itemdata.id = v.id
                    itemdata.itemType = v.itemType -- 物品道具
                    itemdata.itembackData = v.itembackData
                    itemdata.itemConfig = v.itemConfig
                    itemdata.quality = v.itemConfig.Quantity
                    itemdata.frame = GetQuantityImageByquality(v.itemConfig.Quantity)
                    itemdata.Image_proBg = GetQuantityProBgImageByquality(v.itemConfig.Quantity)
                    itemdata.icon = v.icon
                    itemdata.num = 1
                    itemdata.isSelect = false
                    items[index] = itemdata
                    index = index + 1
                end
            elseif quality > 0 and v.quality == quality then
                for n = 1, v.num do
                    local itemdata = {}
                    itemdata.id = v.id
                    itemdata.itemType = v.itemType -- 物品道具
                    itemdata.itembackData = v.itembackData
                    itemdata.itemConfig = v.itemConfig
                    itemdata.quality = v.itemConfig.Quantity
                    itemdata.frame = GetQuantityImageByquality(v.itemConfig.Quantity)
                    itemdata.Image_proBg = GetQuantityProBgImageByquality(v.itemConfig.Quantity)
                    itemdata.icon = v.icon
                    itemdata.num = 1
                    itemdata.isSelect = false
                    items[index] = itemdata
                    index = index + 1
                end
            end
        end
    end
    table.sort(
        items,
        function(a, b)
            -- if a.quality > b.quality then
            --     return true
            -- elseif a.quality == b.quality then
            --     return a.id > b.id
            -- else
            --     return false
            -- end
            if a.quality == b.quality then
                return a.id > b.id
            else
                return a.quality > b.quality
            end
        end
    )
    return items
end

--通过品质和星级获取装备列表
function this.GetEquipDataByEquipQualityAndStar(qualityList,starList)
    local equips = this.GetBagItemDataByItemType(ItemBaseType.Equip)   
    if (not qualityList or LengthOfTable(qualityList) < 1) and (not starList or LengthOfTable(starList) < 1) then
        return equips
    end
    local tempEquips = {}
    local index = 1
    if qualityList and LengthOfTable(qualityList) > 0 then
        for n,v in ipairs(equips) do
            if equipConfig[v.id] and qualityList[equipConfig[v.id].Quality] 
            and qualityList[equipConfig[v.id].Quality] == equipConfig[v.id].Quality then
                tempEquips[index] = v
                index = index + 1
            end
        end
    end
    local finalEquips = {}
    index = 1
    if starList and LengthOfTable(starList) > 0 then
        for n,v in ipairs(tempEquips) do           
            if equipConfig[v.id] then
                local equipstars = ConfigManager.GetConfigData(ConfigName.EquipStarsConfig,equipConfig[v.id].Star) 
                if equipstars and starList[equipstars.Stars] and starList[equipstars.Stars] == equipstars.Stars then
                    finalEquips[index] = v
                    index = index + 1
                end
            end
        end
    end
    return finalEquips
end

--通过职业和位置获得装备list
function this.GetEquipDataByEquipPosition(_profession,_position)
    local equips=this.GetEquipDataByEquipProfession(_profession)
    if (_position and _position == 0) or not _position then
        return equips
    else
        local equipsPosition = {}
        local index = 1
        for i, v in ipairs(equips) do
            if equipConfig[v.id].Position == _position then
                equipsPosition[index] = v
                index = index + 1
            end
        end       
        return equipsPosition
    end
    return nil
end

function this.GetEquipDataByEquipProfession(_profession)
    local equips = this.GetBagItemDataByItemType(ItemBaseType.Equip)   
    if (_profession and _profession == 0) or not _profession then
        return equips
    else
        local equipsPosition = {}
        local index = 1
        for i, v in ipairs(equips) do
            if equipConfig[v.id].ProfessionLimit == _profession or equipConfig[v.id].ProfessionLimit == 0 then
                equipsPosition[index] = v
                index = index + 1
            end
        end
        return equipsPosition
    end
    return nil    
end

--通过装备品质获得装备list
function this.GetEquipDataByEquipQuality(_quality)
    local equips = this.GetBagItemDataByItemType(ItemBaseType.Equip)
    local equipsPosition = {}
    if (_quality and _quality == 0) or not _quality then
        equipsPosition = equips
    else
        for i, v in pairs(equips) do
            if equipConfig[v.id].quality == _quality then
                table.insert(equipsPosition, v)
            end
        end
    end
    return equipsPosition
end

--工坊 通过装备品质获得该品质所有符文list
function this.GetBagItemDataByQuDownAll(_itemType, fuwenQuality)
    local _bagItemData = BagManager.GetBagItemData()
    local items = {}
    local index = 1
    for i, v in pairs(_bagItemData) do
        if v.itemType == _itemType then
            if v.quality == fuwenQuality then
                items[index] = v
                index = index + 1
            end
        end
    end
    return items
end

--地图临时背包数据存储
function this.InitMapShotTimeBagData(_mapItem)
    local singleitemdata = {}
    local _itemCfgData = itemConfig[_mapItem.itemId]
    if _itemCfgData ~= nil then
        singleitemdata.backData = _mapItem
        singleitemdata.itemId = _mapItem.itemId

        singleitemdata.itemNum = _mapItem.itemNum
        singleitemdata.isSave = _itemCfgData.IsSave
        if this.mapShotTimeItemData[singleitemdata.itemId] == nil then
            this.mapShotTimeItemData[singleitemdata.itemId] = singleitemdata
        else
            this.mapShotTimeItemData[singleitemdata.itemId].itemNum = singleitemdata.itemNum
         -- this.mapShotTimeItemData[singleitemdata.itemId].itemNum + singleitemdata.itemNum
        end
        if _mapItem.itemId == 43 then
            -- 是炸弹
            this.mapShotTimeItemData[singleitemdata.itemId].itemNum =
                this.mapShotTimeItemData[singleitemdata.itemId].itemNum >= 3 and 3 or
                this.mapShotTimeItemData[singleitemdata.itemId].itemNum
        end
    end

    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnTempBagChanged)
end
--通过物品id获取地图临时背包物品数量
function this.GetMapBagItemCountById(_itemId)
    
    if this.mapShotTimeItemData[_itemId] then
        return this.mapShotTimeItemData[_itemId].itemNum
    end
    return 0
end
--把地图临时背包物品数量加成到背包中
function this.InBagGetMapBag()
    --for i, v in pairs(this.mapShotTimeItemData) do
    --    if v.isSave then
    --        if v.isSave == 1 then
    --            this.UpdateBagData(v)
    --        end
    --    end
    --end
    for i, v in pairs(EquipManager.mapShotTimeItemData) do
        EquipManager.UpdateEquipData(v)
    end
    for i, v in pairs(HeroManager.mapShotTimeItemData) do
        HeroManager.UpdateHeroDatas(v)
    end
    for i, v in pairs(TalismanManager.mapShotTimeItemData) do
        TalismanManager.InitUpdateSingleTalismanData(v)
    end

    --SoulPrintManager.InitServerData(SoulPrintManager.mapShotTimeItemData)
    EquipTreasureManager.InitAllEquipTreasure(SoulPrintManager.mapShotTimeItemData)
    this.mapShotTimeItemData = {}
    EquipManager.mapShotTimeItemData = {}
    HeroManager.mapShotTimeItemData = {}
    TalismanManager.mapShotTimeItemData = {}
    SoulPrintManager.mapShotTimeItemData = {}
    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
end
function this.OnShowTipDropNumZero(drop)
    local addMaxNumItemNameList = ""
    if drop.itemlist ~= nil and #drop.itemlist > 0 then
        for i = 1, #drop.itemlist do
            if drop.itemlist[i].itemNum <= 0 then

                if addMaxNumItemNameList == "" then
                    addMaxNumItemNameList = itemConfig[drop.itemlist[i].itemId].Name
                else
                    addMaxNumItemNameList = addMaxNumItemNameList .. "、" .. itemConfig[drop.itemlist[i].itemId].Name
                end
            end
        end
    end
    if addMaxNumItemNameList and addMaxNumItemNameList ~= "" then
        MsgPanel.ShowOne(GetLanguageStrById(10184) .. GetLanguageStrById(addMaxNumItemNameList))
    end
end

--服务器掉落物品直接进背包
function this.GoIntoBackData(drop)
    if (#drop.itemlist > 0) then
    --BagManager.UpDataBagItemIdNumber(drop.itemlist)
    --Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
    end
    if (#drop.equipId > 0) then
        for i = 1, #drop.equipId do
            EquipManager.UpdateEquipData(drop.equipId[i])
        end
        --在关卡界面获得装备 刷新下btview成员红点
        Game.GlobalEvent:DispatchEvent(GameEvent.Equip.EquipChange)
    end
    if (#drop.Hero > 0) then
        for i = 1, #drop.Hero do
            HeroManager.UpdateHeroDatas(drop.Hero[i])
        end
    end
    -- if (#drop.especialEquipId > 0) then
    --     for i = 1, #drop.especialEquipId do
    --         TalismanManager.InitUpdateSingleTalismanData(drop.especialEquipId[i])
    --     end
    -- end
    
    if (#drop.soulEquip > 0) then
        --SoulPrintManager.InitServerData(drop.soulEquip)
        EquipTreasureManager.InitAllEquipTreasure(drop.soulEquip)
    end

    if drop.plan and #drop.plan > 0 then
        for i = 1, #drop.plan do
            CombatPlanManager.UpdateSinglePlanData(drop.plan[i])
        end
    end

    if drop.motherShipPlan and #drop.motherShipPlan > 0 then
        for i = 1, #drop.motherShipPlan do
            AircraftCarrierManager.UpdateSkillData(drop.motherShipPlan[i])
        end
    end
end
--兵棋骰子刷新
function this.GoDiceBackData(msg)
    local _msgItemList=msg.drop.itemlist
    AutoRecoverManager.nextFlushTime=msg.nextFlushTime

    -- -- this.bagDatas[1008].num = msg.Count 
    -- for i = 1, #_msgItemList do
    --     local _itemData=_msgItemList[i]
    --     local itemdata = {}
    --     --Log("_itemData.itemId   -=-=-=-=-=-=-=-=-=-=-=-=-=-=-        ".._itemData.itemId.."    ".._itemData.itemNum)
    --     local _itemCfgData = itemConfig[1008]
    --     if _itemCfgData ~= nil then
    --         itemdata.itembackData = _itemData
    --         itemdata.itemConfig = _itemCfgData
    --         itemdata.id = _itemCfgData.Id
    --         itemdata.property = {}
    --         if _itemCfgData.ResourceID and _itemCfgData.ResourceID > 0 then
    --             itemdata.icon = GetResourcePath(_itemCfgData.ResourceID)
    --         else
    --             itemdata.icon = GetResourcePath(10002)
    --         end
    --         itemdata.quality = _itemCfgData.Quantity
    --         itemdata.frame = GetQuantityImageByquality(_itemCfgData.Quantity)
    --         itemdata.type = _itemCfgData.ItemBaseType
    --         itemdata.itemType = _itemCfgData.ItemType
    --         itemdata.isBag = _itemCfgData.BackpackOrNot
    --         itemdata.num = msg.Count
    --         itemdata.endingTime = _itemData.endingTime
    --         itemdata.nextFlushTime = msg.nextFlushTime
    --         if (itemdata.id == 54) then
    --             this.needEndingTime = itemdata.endingTime
    --         end
    --         if this.bagDatas[itemdata.id] == nil then
    --             this.bagDatas[itemdata.id] = itemdata
    --         else
    --             this.bagDatas[itemdata.id].num = msg.Count 
    --             this.bagDatas[itemdata.id].endingTime = itemdata.endingTime
    --             this.bagDatas[itemdata.id].nextFlushTime = msg.nextFlushTime
    --         end
    --     end
    -- end
    -- if this.bagDatas[1008] then
    --     this.bagDatas[1008].num = msg.Count 
    -- end
end

function this.GMCallBackData(drop)
    if drop.itemlist and #drop.itemlist > 0 then
        for i = 1, #drop.itemlist do
            BagManager.UpdateBagData(drop.itemlist[i])
        end
    end
    if drop.equipId and #drop.equipId > 0 then
        for i = 1, #drop.equipId do
            EquipManager.UpdateEquipData(drop.equipId[i])
        end
    end
    if drop.Hero and #drop.Hero > 0 then
        for i = 1, #drop.Hero do
            HeroManager.UpdateHeroDatas(drop.Hero[i])
        end
    end
    -- if drop.especialEquipId and #drop.especialEquipId > 0 then
    --     for i = 1, #drop.especialEquipId do
    --         TalismanManager.InitUpdateSingleTalismanData(drop.especialEquipId[i])
    --     end
    -- end
    if #drop.soulEquip > 0 then
        --SoulPrintManager.InitServerData(drop.soulEquip)
        EquipTreasureManager.InitAllEquipTreasure(drop.soulEquip)
    end
    if drop.plan and #drop.plan > 0 then
        for i = 1, #drop.plan do
            CombatPlanManager.UpdateSinglePlanData(drop.plan[i])
        end
    end
    if drop.motherShipPlan and #drop.motherShipPlan > 0 then
        for i = 1, #drop.motherShipPlan do
            AircraftCarrierManager.UpdateSkillData(drop.motherShipPlan[i])
        end
    end
    if drop.medal and #drop.medal > 0 then
        for i = 1, #drop.medal do
            MedalManager.AddMedal(drop.medal[i])
        end
    end
end

--将后端drop转为前端table
function this.GetTableByBackDropData(drop)
    local itemDataList = {}
    if drop.itemlist ~= nil and #drop.itemlist > 0 then
        for i = 1, #drop.itemlist do
            local itemdata = {}
            itemdata.itemType = 1
             --item
            itemdata.sId = drop.itemlist[i].itemId
            itemdata.backData = drop.itemlist[i]
            
            itemdata.configData = itemConfig[drop.itemlist[i].itemId]
            itemdata.name = itemdata.configData.Name
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
            itemdata.Image_proBg = GetQuantityProBgImageByquality(itemdata.configData.Quantity)
            itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
            itemdata.num = drop.itemlist[i].itemNum
            table.insert(itemDataList, itemdata)
            --BagManager.UpdateBagData(itemdata.backData)
        end
    end
    if drop.equipId ~= nil and #drop.equipId > 0 then
        for i = 1, #drop.equipId do
            local itemdata = {}
            itemdata.itemType = 2
             --装备
            itemdata.sId = drop.equipId[i].equipId
            itemdata.backData = drop.equipId[i]
            itemdata.configData = itemConfig[drop.equipId[i].equipId]
            itemdata.name = itemdata.configData.Name
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
            itemdata.Image_proBg = GetQuantityProBgImageByquality(itemdata.configData.Quantity)
            itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
            itemdata.num = 1
            table.insert(itemDataList, itemdata)
            EquipManager.UpdateEquipData(itemdata.backData)
        end
    end
    if drop.Hero ~= nil and #drop.Hero > 0 then
        for i = 1, #drop.Hero do
            local itemdata = {}
            itemdata.itemType = 3
             --英雄
            itemdata.sId = drop.Hero[i].heroId
            itemdata.backData = drop.Hero[i]
            itemdata.configData = ConfigManager.GetConfigData(ConfigName.HeroConfig, drop.Hero[i].heroId)
            itemdata.name = itemdata.configData.ReadingName
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quality,itemdata.configData.Star)
            itemdata.Image_proBg = GetQuantityProBgImageByquality(itemdata.configData.Quantity,itemdata.configData.Star)
            itemdata.icon = GetResourcePath(itemdata.configData.Icon)
            itemdata.num = 1
            table.insert(itemDataList, itemdata)
            HeroManager.UpdateHeroDatas(itemdata.backData)
        end
    end
    -- if drop.especialEquipId ~= nil and #drop.especialEquipId > 0 then
    --     for i = 1, #drop.especialEquipId do
    --         local itemdata = {}
    --         itemdata.itemType = 4--法宝
    --         itemdata.sId = drop.especialEquipId[i].equipId
    --         itemdata.backData = drop.especialEquipId[i]
    --         itemdata.configData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana, "TalismanaId", drop.especialEquipId[i].equipId, "Level", drop.especialEquipId[i].rebuildLevel)
    --         itemdata.name = itemdata.configData.Name
    --         local itemConfig = itemConfig[drop.especialEquipId[i].equipId]
    --         itemdata.frame = GetQuantityImageByquality(itemConfig.Quantity)
            -- itemdata.Image_proBg = GetQuantityProBgImageByquality(itemConfig.Quantity)
    --         itemdata.icon = GetResourcePath(itemConfig.ResourceID)
    --         itemdata.num = 1
    --         table.insert(itemDataList, itemdata)
    --         TalismanManager.InitUpdateSingleTalismanData(itemdata.backData)
    --     end
    -- end
    if drop.soulEquip ~= nil and #drop.soulEquip > 0 then
        for i = 1, #drop.soulEquip do
            local itemdata = {}
            itemdata.itemType = 5
             --魂印
            itemdata.sId = drop.soulEquip[i].equipId
            itemdata.backData = drop.soulEquip[i]
            SoulPrintManager.UpSoulPrintLevel(drop.soulEquip[i].equipId, drop.soulEquip[i].exp)
            itemdata.level = SoulPrintManager.soulPrintLevel[drop.soulEquip[i].equipId]
            this.GetSoulPrintId(drop.soulEquip[i].equipId, itemdata.level)
            itemdata.configData = ConfigManager.GetConfigData(ConfigName.EquipSign, drop.soulEquip[i].id)
            itemdata.name = itemdata.configData.Name
            local itemConfig = itemConfig[drop.soulEquip[i].id]
            itemdata.frame = GetQuantityImageByquality(itemConfig.Quantity)
            itemdata.Image_proBg = GetQuantityProBgImageByquality(itemConfig.Quantity)
            itemdata.icon = GetResourcePath(itemConfig.ResourceID)
            itemdata.num = 1
            table.insert(itemDataList, itemdata)
            --SoulPrintManager.InitServerData(drop.soulEquip)
            EquipTreasureManager.InitAllEquipTreasure(drop.soulEquip)
            --TalismanManager.InitUpdateSingleTalismanData(itemdata.backData)
        end
    end
    if drop.plan and #drop.plan > 0 then
        for i = 1, #drop.plan do
            local itemdata = {}
            itemdata.itemType = 6   --< 作战方案
            itemdata.backData = drop.plan[i]
            itemdata.num = 1
            itemdata.sId = drop.plan[i].combatPlanId
            itemdata.configData = G_ItemConfig[itemdata.sId]
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
            itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
            table.insert(itemDataList, itemdata)
            CombatPlanManager.UpdateSinglePlanData(itemdata.backData)
        end
    end

    if drop.motherShipPlan and #drop.motherShipPlan > 0 then
        for i = 1, #drop.motherShipPlan do
            local itemdata = {}
            itemdata.itemType = 8   --< 航母飞机
            itemdata.backData = drop.motherShipPlan[i]
            itemdata.num = 1
            itemdata.sId = drop.motherShipPlan[i].cfgId
            itemdata.configData = G_ItemConfig[itemdata.sId]
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
            itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
            table.insert(itemDataList, itemdata)

            AircraftCarrierManager.UpdateSkillData(itemdata.backData)
        end
    end

    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
    return itemDataList
end

-- 将drop的数据解析存进临时背包, isSave 为true 为保存进临时背包
function this.GetItemListFromTempBag(drop, isSave)
    local itemDataList = {}
    if drop~=nil and drop.itemlist ~= nil and #drop.itemlist > 0 then
        for i = 1, #drop.itemlist do
            local itemdata = {}
            itemdata.itemType = 1
             --item
            itemdata.sId = drop.itemlist[i].itemId
            itemdata.backData = drop.itemlist[i]

            itemdata.configData = itemConfig[drop.itemlist[i].itemId]
            itemdata.name = itemdata.configData.Name
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
            itemdata.Image_proBg = GetQuantityProBgImageByquality(itemdata.configData.Quantity)
            itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
            itemdata.num = drop.itemlist[i].itemNum
            table.insert(itemDataList, itemdata)
        end
    end
    if drop.equipId ~= nil and #drop.equipId > 0 then
        for i = 1, #drop.equipId do
            local itemdata = {}
            local equipId = drop.equipId[i].equipId
            local equip = ConfigManager.TryGetConfigData(ConfigName.JewelConfig, equipId)
            if equip then
                itemdata.itemType = 5
             --宝物
            else
                itemdata.itemType = 2
             --装备
            end
            itemdata.sId = equipId
            itemdata.backData = drop.equipId[i]
            itemdata.configData = itemConfig[equipId]

            itemdata.name = itemdata.configData.Name
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
            itemdata.Image_proBg = GetQuantityProBgImageByquality(itemdata.configData.Quantity)
            itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
            itemdata.num = 1
            table.insert(itemDataList, itemdata)
            if isSave then
                --判断获取是否是宝物
                if equip then
                    EquipTreasureManager.InitSingleTreasureData(itemdata.backData)
                else
                    EquipManager.InitMapShotTimeEquipBagData(itemdata.backData)
                end
            end
        end
    end
    if drop.Hero ~= nil and #drop.Hero > 0 then
        for i = 1, #drop.Hero do
            local itemdata = {}
            itemdata.itemType = 3
             --英雄
            itemdata.sId = drop.Hero[i].heroId
            itemdata.backData = drop.Hero[i]
            itemdata.configData = ConfigManager.GetConfigData(ConfigName.HeroConfig, drop.Hero[i].heroId)
            itemdata.name = itemdata.configData.ReadingName
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quality,drop.Hero[i].star)
            itemdata.Image_proBg = GetQuantityProBgImageByquality(itemdata.configData.Quantity,drop.Hero[i].star)
            itemdata.icon = GetResourcePath(itemdata.configData.Icon)
            itemdata.num = 1
            table.insert(itemDataList, itemdata)
            if isSave then
                HeroManager.InitMapShotTimeHeroBagData(itemdata.backData)
            end
        end
    end

    if drop.soulEquip ~= nil and #drop.soulEquip > 0 then
        for i = 1, #drop.soulEquip do
            local itemdata = {}
            itemdata.itemType = 5
             --宝物
            itemdata.sId = drop.soulEquip[i].equipId
            itemdata.backData = drop.soulEquip[i]
            itemdata.data = drop.soulEquip
            itemdata.lv = drop.soulEquip[i].exp
            itemdata.refineLv = drop.soulEquip[i].rebuildLevel
            --SoulPrintManager.UpSoulPrintLevel(drop.soulEquip[i].equipId, drop.soulEquip[i].exp)
            --itemdata.level = SoulPrintManager.soulPrintLevel[drop.soulEquip[i].equipId]
            --local id = SoulPrintManager.GetSoulPrintId(drop.soulEquip[i].equipId, itemdata.level)
            itemdata.configData = ConfigManager.GetConfigData(ConfigName.ItemConfig, itemdata.sId)
             --ConfigManager.GetConfigData(ConfigName.EquipSign, id)
            itemdata.name = itemdata.configData.Name
            local itemConfig = itemConfig[drop.soulEquip[i].equipId]
            itemdata.itemConfig = itemConfig
            itemdata.frame = GetQuantityImageByquality(itemConfig.Quantity)
            itemdata.Image_proBg = GetQuantityProBgImageByquality(itemConfig.Quantity)
            itemdata.icon = GetResourcePath(itemConfig.ResourceID)
            itemdata.num = 1
            itemdata.id = drop.soulEquip[i].id
            table.insert(itemDataList, itemdata)
            if isSave then
                EquipTreasureManager.InitSingleTreasureData(itemdata.backData)
            end
        end
    end

    if drop.plan and #drop.plan > 0 then
        for i = 1, #drop.plan do
            local itemdata = {}
            itemdata.itemType = 6   --< 作战方案
            itemdata.backData = drop.plan[i]
            itemdata.num = 1
            itemdata.sId = drop.plan[i].combatPlanId
            itemdata.configData = G_ItemConfig[itemdata.sId]
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
            itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
            table.insert(itemDataList, itemdata)
            if isSave then
                
            end
        end
    end

    if drop.medal and #drop.medal > 0 then
        for i = 1, #drop.medal do
            local itemdata = {}
            itemdata.itemType = 7   --勋章
            itemdata.backData = drop.medal[i]
            itemdata.num = 1
            itemdata.sId = drop.medal[i].medalId
            itemdata.configData = G_ItemConfig[itemdata.sId]
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
            itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
            table.insert(itemDataList, itemdata)
        end
    end

    if drop.motherShipPlan and #drop.motherShipPlan > 0 then
        for i = 1, #drop.motherShipPlan do
            local itemdata = {}
            itemdata.itemType = 8   --< 航母飞机
            itemdata.backData = drop.motherShipPlan[i]
            itemdata.num = 1
            itemdata.sId = drop.motherShipPlan[i].cfgId
            itemdata.configData = G_ItemConfig[itemdata.sId]
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
            itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
            table.insert(itemDataList, itemdata)
        end
    end

    if drop.title and #drop.title > 0 then
        for i = 1, #drop.title do
            local itemdata = {}
            itemdata.itemType = 9
            -- itemdata.backData = drop.motherShipPlan[i]
            itemdata.num = 1
            itemdata.sId = drop.title[i]
            itemdata.configData = G_ItemConfig[drop.title[i]]
            itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
            itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
            itemdata.itemConfig = G_ItemConfig[drop.title[i]]
            table.insert(itemDataList, itemdata)
        end
    end

    return itemDataList
end

-- 返回所有临时背包的数据
function this.GetAllTempBagData()
    local mapItemList = {} --  临时背包所有显示用的道具
    local itemList = BagManager.mapShotTimeItemData
    local equipList = EquipManager.mapShotTimeItemData
    local heroList = HeroManager.mapShotTimeItemData
    local talismanList = TalismanManager.mapShotTimeItemData
    local soulPrintList = SoulPrintManager.mapShotTimeItemData
    for i, v in pairs(itemList) do
        local itemdata = {}
        itemdata.itemType = 1 -- 物品道具
        itemdata.sId = v.itemId
        itemdata.backData = v
        itemdata.configData = itemConfig[v.itemId]
        itemdata.name = itemdata.configData.Name
        itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
        itemdata.Image_proBg = GetQuantityProBgImageByquality(itemdata.configData.Quantity)
        itemdata.Quantity = itemdata.configData.Quantity
        itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
        itemdata.num = v.itemNum

        mapItemList[#mapItemList + 1] = itemdata
    end

    for i, v in pairs(equipList) do
        local itemdata = {}
        itemdata.itemType = 2
         --装备
        itemdata.sId = v.equipId
        itemdata.backData = v
        itemdata.configData = itemConfig[v.equipId]
        itemdata.name = itemdata.configData.Name
        itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quantity)
        itemdata.Image_proBg = GetQuantityProBgImageByquality(itemdata.configData.Quantity)
        itemdata.Quantity = itemdata.configData.Quantity
        itemdata.icon = GetResourcePath(itemdata.configData.ResourceID)
        itemdata.num = 1
        mapItemList[#mapItemList + 1] = itemdata
    end

    for i, v in pairs(heroList) do
        local itemdata = {}
        itemdata.itemType = 3
         --英雄
        itemdata.sId = v.heroId
        itemdata.backData = v
        itemdata.configData = ConfigManager.GetConfigData(ConfigName.HeroConfig, v.heroId)
        itemdata.name = itemdata.configData.Name
        itemdata.frame = GetQuantityImageByquality(itemdata.configData.Quality,itemdata.configData.Star)
        itemdata.Image_proBg = GetQuantityProBgImageByquality(itemdata.configData.Quality,itemdata.configData.Star)
        itemdata.Quantity = itemdata.configData.Star
        itemdata.icon = GetResourcePath(itemdata.configData.Icon)
        itemdata.num = 1
        mapItemList[#mapItemList + 1] = itemdata
    end
    for i, v in pairs(talismanList) do
        local itemdata = {}
        itemdata.itemType = 4
         --法宝
        itemdata.sId = v.equipId
        itemdata.backData = v
        itemdata.configData =
            ConfigManager.GetConfigDataByDoubleKey(
            ConfigName.EquipTalismana,
            "TalismanaId",
            v.equipId,
            "Level",
            v.rebuildLevel
        )
        itemdata.name = GetLanguageStrById(itemdata.configData.ReadingName)
        local itemConfig = itemConfig[v.equipId]
        itemdata.frame = GetQuantityImageByquality(itemConfig.Quantity)
        itemdata.Image_proBg = GetQuantityProBgImageByquality(itemConfig.Quantity)
        itemdata.Quantity = itemConfig.Quantity
        itemdata.icon = GetResourcePath(itemConfig.ResourceID)
        itemdata.num = 1
        mapItemList[#mapItemList + 1] = itemdata
    end
    for i, v in pairs(soulPrintList) do
        local itemdata = {}
        itemdata.itemType = 5
         --魂印
        itemdata.sId = v.equipId
        itemdata.backData = v
        SoulPrintManager.UpSoulPrintLevel(v.equipId, v.exp)
        itemdata.level = SoulPrintManager.soulPrintLevel[v.equipId]
        local id = SoulPrintManager.GetSoulPrintId(v.equipId, itemdata.level)
        itemdata.configData = ConfigManager.GetConfigData(ConfigName.EquipSign, id)
        itemdata.name = itemdata.configData.Name
        local itemConfig = itemConfig[v.equipId]
        itemdata.frame = GetQuantityImageByquality(itemConfig.Quantity)
        itemdata.Image_proBg = GetQuantityProBgImageByquality(itemConfig.Quantity)
        itemdata.Quantity = itemConfig.Quantity
        itemdata.icon = GetResourcePath(itemConfig.ResourceID)
        itemdata.num = 1
        mapItemList[#mapItemList + 1] = itemdata
        --SoulPrintManager.InitServerData(soulPrintList.soulEquip)
        --TalismanManager.InitUpdateSingleTalismanData(itemdata.backData)
    end

    -- 先类型后品质
    if #mapItemList > 1 then
        table.sort(
            mapItemList,
            function(a, b)
                if a.itemType == b.itemType then
                    return a.Quantity > b.Quantity
                else
                    return a.itemType < b.itemType
                end
            end
        )
    end

    return mapItemList
end
--设置背包物品红点
function this.SetItemNewRewPooint()
    for i, v in pairs(this.bagDatas) do
        if v.isNewRewPoint then
            v.isNewRewPoint = false
            RedPointManager.PlayerPrefsSetStrItemId(v.id, 1)
        end
    end
end
--是否有可合成碎片
function this.GetBagRedPointIsCanCompoundDebris()
    for i, v in pairs(this.bagDatas) do
        if v.itemType == ItemType.HeroDebris then
            local curExpVal = BagManager.GetItemCountById(v.id) / v.itemConfig.UsePerCount
            if curExpVal >= 1 then
                return true
            end
        end
    end
    return false
end
--是否有宝箱 和 可使用蓝图
function this.GetBagRedPointIsCanOpenBoxAndBlueprint()
    for i, v in pairs(this.bagDatas) do
        if v.itemType == ItemType.Box and v.num > 0 and v.itemConfig.BackpackOrNot then
            --宝箱
            return true
        end
        if v.itemType == ItemType.Blueprint then
            --蓝图
            local lanTuData = WorkShopManager.GetLanTuIsOpenLock(v.id)
            if lanTuData and v.num > 0 and lanTuData[1] == false then
                return true
            end
        end
    end
    return false
end

--获取该类型的所有背包数据
function this.GetBagAllDataByItemType(ItemType)
    local thisItemTypeAllDatas = {}
    for i, v in pairs(this.bagDatas) do
        if v.itemType == ItemType then
            table.insert(thisItemTypeAllDatas, v)
        end
    end
    return thisItemTypeAllDatas
end

function this.BagIndicationRefresh(msg)
    if msg.type == 0 then
        --普通背包
        for i, v in pairs(msg.item) do
            if v and v.itemId then
                --背包存储
                if BagManager.bagDatas[v.itemId] == nil then
                    BagManager.UpdateBagData(v)
                else
                    BagManager.bagDatas[v.itemId].num = v.itemNum
                    BagManager.bagDatas[v.itemId].endingTime = v.endingTime
                    BagManager.bagDatas[v.itemId].nextFlushTime = v.nextFlushTime
                end
                --公会贡献刷新公会技能红点
                if v.itemId == 65 then
                    if BagManager.bagDatas[v.itemId].num < v.itemNum then
                        GuildSkillManager.SetAllGuildSkillRedPlayers()
                    end
                    CheckRedPointStatus(RedPointType.Guild_Skill)
                end
            end
        end
    elseif msg.type == 1 then
        --临时背包
        for i, v in pairs(msg.item) do
            if v and v.itemId then
                if BagManager.mapShotTimeItemData[v.itemId] == nil then
                    BagManager.InitMapShotTimeBagData(v)
                else
                    BagManager.mapShotTimeItemData[v.itemId].itemNum = v.itemNum
                    BagManager.mapShotTimeItemData[v.itemId].endingTime = v.endingTime
                    BagManager.mapShotTimeItemData[v.itemId].nextFlushTime = v.nextFlushTime
                end
            end
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnTempBagChanged)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
    --检测背包红点
    CheckRedPointStatus(RedPointType.Bag_HeroDebris)
    CheckRedPointStatus(RedPointType.Bag_BoxAndBlueprint)

    -- AircraftCarrierManager.RedPointCheckStatus_CV()
    CheckRedPointStatus(RedPointType.Support)
    if UIManager.IsOpen(UIName.SupportPanel) then
        SupportPanel.CheckRedPoint()
    end
    CheckRedPointStatus(RedPointType.Adjutant)
end

--> 掉落tips
local DropList = BattleList.New()
local DropTimer
function F_DropTips(drop)
    local starItemDataList=BagManager.GetItemListFromTempBag(drop)
    --做装备叠加特殊组拼数据
    local equips = {}
    for i = 1, #starItemDataList do
        this.SaveItemData(starItemDataList[i])
        if starItemDataList[i].itemType == 2 or starItemDataList[i].itemType == 6 then--装备叠加
            if equips[starItemDataList[i].sId] then
                equips[starItemDataList[i].sId].num = equips[starItemDataList[i].sId].num + 1
            else
                equips[starItemDataList[i].sId] = starItemDataList[i]
                equips[starItemDataList[i].sId].num = 1
            end
        end
    end

    local itemDataList = {}
    for i, v in pairs(equips) do
        table.insert(itemDataList, v)
    end
    for i, v in pairs(starItemDataList) do
        if starItemDataList[i].itemType ~= 2 and starItemDataList[i].itemType ~= 6 then
            table.insert(itemDataList, v)
        end
    end

    for i = 1, #itemDataList do
        DropList:Add(itemDataList[i])
    end
    if not DropTimer then
        DropTimer = Timer.New(function()
            if DropList and DropList:Count() > 0 then
                local dropData = DropList.buffer[1]
                
                local itemConfig = G_ItemConfig[dropData.sId]
                PopupTipPanel.ShowTip(GetLanguageStrById(10076) .. " " .. GetLanguageStrById(itemConfig.Name) .. " " .. "x" .. dropData.num)
                DropList:Remove(1)
            end
        end, 0.5, -1, true)
        DropTimer:Start()
    end
end

function this.SaveItemData(itemdata)
    if itemdata.itemType == 1 then
       --后端更新
    elseif itemdata.itemType == 2 then
        EquipManager.UpdateEquipData(itemdata.backData)
    elseif itemdata.itemType == 3 then
        HeroManager.UpdateHeroDatas(itemdata.backData)
    elseif itemdata.itemType == 4 then
        TalismanManager.InitUpdateSingleTalismanData(itemdata.backData)
    elseif itemdata.itemType == 5 then
        EquipTreasureManager.InitSingleTreasureData(itemdata.backData)
    elseif itemdata.itemType == 6 then
        CombatPlanManager.UpdateSinglePlanData(itemdata.backData)
    elseif itemdata.itemType == 7 then
        MedalManager.AddMedal(itemdata.backData)
    elseif itemdata.itemType == 8 then
        AircraftCarrierManager.UpdateSkillData(itemdata.backData) 
    end
end

return this