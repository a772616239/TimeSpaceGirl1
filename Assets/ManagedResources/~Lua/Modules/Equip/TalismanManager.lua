TalismanManager = {};
local this = TalismanManager
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local heroConfig=ConfigManager.GetConfig(ConfigName.HeroConfig)
local equipTalismana = ConfigManager.GetConfig(ConfigName.EquipTalismana)
local equipTalismanaRankup = ConfigManager.GetConfig(ConfigName.EquipTalismanaRankup)
local propertyConfig=ConfigManager.GetConfig(ConfigName.PropertyConfig)

this.lv=0--默认法宝等级
this.talismanDatas={}

this.talismanTabs = {}
this.AllTalismanStartStar = {}
this.AllTalismanEndStar = {}

local GameSettingTalismanOpenType = 0
local GameSettingTalismanOpenVal = 0
function this.Initialize()

end
--初始化更新法宝数据
-- function this.InitUpdateTalismanData(msg)
--     if msg and #msg > 0 then
--         for i = 1, #msg do
--             this.InitUpdateSingleTalismanData(msg[i])
--         end
--     end
--     this.GetStartAndEndStar()
-- end

-- function this.InitUpdateSingleTalismanData(singleTalisman)

--     if singleTalisman.id then
--         local singleTalismanData = {}
--         singleTalismanData.backData= singleTalisman
--         singleTalismanData.upHeroDid = "0"
--         singleTalismanData.id = singleTalisman.equipId
--         singleTalismanData.did = singleTalisman.id
--         singleTalismanData.star = singleTalisman.rebuildLevel
--         singleTalismanData.itemConfig = itemConfig[singleTalisman.equipId]
--         singleTalismanData.frame = GetQuantityImageByquality(singleTalismanData.itemConfig.Quantity)
--         singleTalismanData.icon = GetResourcePath(singleTalismanData.itemConfig.ResourceID)
--         singleTalismanData.num = 1
--         singleTalismanData.power = this.CalculateWarForceBySid(singleTalismanData.id,singleTalismanData.star,0)
--         this.talismanTabs[singleTalisman.id] = singleTalismanData
--     end
-- end
--获取全部
function this.GetAllTalismanData(isAddUpHero,heroDid)
    local talismans = {}
    for i, v in pairs(this.talismanTabs) do
        if isAddUpHero then
            table.insert(talismans,v)
        else
            if v.upHeroDid == "0" and heroDid and v.upHeroDid == heroDid then
                table.insert(talismans,v)
            end
        end
    end
    table.sort(talismans, function(a,b) return a.backData.equipId < b.backData.equipId end)
    return talismans
end
--设置法宝穿戴的英雄
function this.SetTalismanUpHeroDid(talismanDid,heroDid)
    if this.talismanTabs[talismanDid] then
        this.talismanTabs[talismanDid].upHeroDid=heroDid
    end
end
--设置法宝穿戴的星级
function this.SetLv(lv,did)
    -- if not this.talismanDatas[did] then
        this.talismanDatas[did]=lv
    -- end
end
--获取单个法宝信息
function this.GetSingleTalismanData(talismanDid)
    if this.talismanTabs[talismanDid] then
        return this.talismanTabs[talismanDid]
    end
    return nil
end
--删除单个法宝信息
function this.DeleteSingleTalismanData(talismanDids)
    for i = 1, #talismanDids do
        if this.talismanTabs[talismanDids[i]] then
           
            this.talismanTabs[talismanDids[i]] = nil
        end
    end
end
--计算战斗力
function this.CalculateWarForceBySid(sId,star,heroPos)
    local curTalismanConFigData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana, "TalismanaId", sId, "Level", star)
    return this.CalculateWarForceBase(curTalismanConFigData,heroPos)
end

--计算战斗力
function  this.CalculateWarForce(talismanDid,heroPos)
    local curTalisman =  this.talismanTabs[talismanDid]
    if curTalisman then
        local curTalismanConFigData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana, "TalismanaId", curTalisman.id, "Level", curTalisman.star)
        return this.CalculateWarForceBase(curTalismanConFigData,heroPos)
    end
end
function this.CalculateWarForceBase(curTalismanConFigData,heroPos)
    if curTalismanConFigData then
        local addAllProVal = {}
        --主属性
        for i = 1, #curTalismanConFigData.Property do
            if addAllProVal[curTalismanConFigData.Property[i][1]] then
                addAllProVal[curTalismanConFigData.Property[i][1]] = addAllProVal[curTalismanConFigData.Property[i][1]] +
                        curTalismanConFigData.Property[i][2]
            else
                addAllProVal[curTalismanConFigData.Property[i][1]] = curTalismanConFigData.Property[i][2]
            end
        end
        --副属性
        if curTalismanConFigData.SpecialProperty and #curTalismanConFigData.SpecialProperty > 0 then
            for i = 1, #curTalismanConFigData.SpecialProperty do
                if curTalismanConFigData.SpecialProperty[i][1] == 1 then--是属性
                    if heroPos == 0 or heroPos == curTalismanConFigData.SpecialProperty[i][2] then
                        if addAllProVal[curTalismanConFigData.SpecialProperty[i][3]] then
                            addAllProVal[curTalismanConFigData.SpecialProperty[i][3]] = addAllProVal[curTalismanConFigData.SpecialProperty[i][3]] +
                                    curTalismanConFigData.SpecialProperty[i][4]
                        else
                            addAllProVal[curTalismanConFigData.SpecialProperty[i][3]] = curTalismanConFigData.SpecialProperty[i][4]
                        end
                    end
                end
            end
        end
        local heroPropertyScore={}
        for i, v in ConfigPairs(propertyConfig) do
            heroPropertyScore[i]=v.Score
        end
        local powerEndVal=0
        for i, v in pairs(addAllProVal) do
            if v > 0 then
                local curProConfigData = ConfigManager.GetConfigData(ConfigName.PropertyConfig,i)
                if curProConfigData then
                    if curProConfigData.Style == 1 then
                        powerEndVal=powerEndVal+v*heroPropertyScore[i]
                    else
                        powerEndVal=powerEndVal+v/100*heroPropertyScore[i]
                    end
                end
            end
        end
        return math.floor(powerEndVal)
    end
end
function this.GetAllTalismanByCondition(curTalismanData,upStarConFigData)
    local GetAllTalismanByConditionList = {}
    for i, v in pairs(this.talismanTabs) do
        if v.upHeroDid == "0" and v.did ~= curTalismanData.did  then
            if v.star == upStarConFigData.StarLimit then
                if upStarConFigData.Issame == 1 then--同名
                    if v.id == curTalismanData.id then
                        table.insert(GetAllTalismanByConditionList,v)
                    end
                elseif upStarConFigData.IsId ~= 0 then--指定id
                    if v.id == upStarConFigData.IsId then
                        table.insert(GetAllTalismanByConditionList,v)
                    end
                else
                    table.insert(GetAllTalismanByConditionList,v)
                end
            end
        end
    end
    return GetAllTalismanByConditionList
end

--获取最大星级
function this.GetStartAndEndStar()
    this.AllTalismanStartStar = {}
    this.AllTalismanEndStar = {}
    for i, v in ConfigPairs(equipTalismana) do
        if this.AllTalismanStartStar[v.TalismanaId] then
            if v.Level < this.AllTalismanStartStar[v.TalismanaId] then
                this.AllTalismanStartStar[v.TalismanaId] = v.Level
            end
            if v.Level > this.AllTalismanEndStar[v.TalismanaId] then
                this.AllTalismanEndStar[v.TalismanaId] = v.Level
            end
        else
            this.AllTalismanStartStar[v.TalismanaId] = v.Level
            this.AllTalismanEndStar[v.TalismanaId] = v.Level
        end
    end
    -- local gameSettingConFig = ConfigManager.GetConfigData(ConfigName.GameSetting,1)
    -- GameSettingTalismanOpenType = gameSettingConFig.EquipTalismanaUnlock[1]
    -- GameSettingTalismanOpenVal = gameSettingConFig.EquipTalismanaUnlock[2]
end

--地图临时背包数据
this.mapShotTimeItemData={}
--地图临时英雄数据存储
function this.InitMapShotTimeTalismanBagData(_mapHero)
    this.mapShotTimeItemData[#this.mapShotTimeItemData+1]=_mapHero
end

--检查HeroConfig里英雄是否配了法宝
function this.CheckTalismanIsInConfig(curHeroData)
    local isOpen = true
    if heroConfig[curHeroData.id].EquipTalismana~=nil then
        isOpen=true
    else
        isOpen=false
    end
    return isOpen
end

--获取当前英雄是否开启法宝
function this.GetCurHeroIsOpenTalisman(curHeroData)
    local isOpen = false
    local gameSettingConFig = ConfigManager.GetConfigData(ConfigName.GameSetting,1)
    GameSettingTalismanOpenType = gameSettingConFig.EquipTalismanaUnlock[1][1]
    if heroConfig[curHeroData.id].EquipTalismana~=nil then
        GameSettingTalismanOpenVal =  heroConfig[curHeroData.id].EquipTalismana[1]
    end

    if GameSettingTalismanOpenType == 1 then
        if PlayerManager.level >= GameSettingTalismanOpenVal and heroConfig[curHeroData.id].EquipTalismana~=nil then
            isOpen = true
        end
    elseif GameSettingTalismanOpenType == 2 and heroConfig[curHeroData.id].EquipTalismana~=nil then
        if curHeroData.star >= heroConfig[curHeroData.id].EquipTalismana[1] then--如果走的英雄星级 判断heroconfig里的法宝星级
            isOpen = true
        end
    end
    return isOpen
end
function this.GetCurHeroIsOpenTalismanStr()
    if GameSettingTalismanOpenType == 1 then
        return GameSettingTalismanOpenVal .. GetLanguageStrById(10062)
    elseif GameSettingTalismanOpenType == 2 then
        return NumToSimplenessFont[GameSettingTalismanOpenVal] .. GetLanguageStrById(10488)
    end
end

function this.GetCurHeroIsOpenTalismanTip()
    if GameSettingTalismanOpenType == 1 then
        return GameSettingTalismanOpenVal .. GetLanguageStrById(10062)
    elseif GameSettingTalismanOpenType == 2 then
        return GetLanguageStrById(10489)..NumToSimplenessFont[GameSettingTalismanOpenVal] .. GetLanguageStrById(10490)
    end
end
return this