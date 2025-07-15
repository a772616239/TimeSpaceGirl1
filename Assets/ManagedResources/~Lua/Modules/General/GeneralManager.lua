GeneralManager = {}
local this = GeneralManager
local generalStepConfig = ConfigManager.GetConfig(ConfigName.GeneralConfig)
local generalLevelStepConfig = ConfigManager.GetConfig(ConfigName.GeneralLevelConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
this.generalDate = {}
this.setDataMode = false

function this.Initialize()
end

function this.SetAllGeneralDatas(data)
    for key, value in pairs(data.generalDate) do
        this.generalDate[key] = value
    end
    this.setDataMode = true
end

--契约是否获取数据状态
function this.GetGeneralMode()
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GENERAL) then
        if this.setDataMode ~= true then
            NetManager.GetGeneralData()
        end
    end
    return this.setDataMode
end

--获取所有契约信息
function this.GetAllGeneralDatas(_lvLimit)
    for key, value in pairs(this.generalDate) do
        if value.id == _lvLimit then
            return value
        end
    end
    return nil
end

--获取契约升级信息
function this.UpgradeExpend(generalID,lv)
   local levelUpList = ConfigManager.GetAllConfigsDataByKey(ConfigName.GeneralLevelConfig,"GeneralId",generalID)
   for key, value in pairs(levelUpList) do
       if value.Lev == lv then
           return value
       end
   end
   return nil
end

--获取契约满级信息
function this.MaxLevel(generalID)
    local levelUpList = ConfigManager.GetAllConfigsDataByKey(ConfigName.GeneralLevelConfig,"GeneralId",generalID)
    local maxLevel = 0
    for key, value in pairs(levelUpList) do
        if value.Lev > maxLevel then
            maxLevel = value.Lev
        end
    end
    return maxLevel
 end

--获取契约属性数据
function this.GeneralAtt(generalID,lv,attackIdx)
    local generalData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.GeneralLevelConfig,"GeneralId",generalID,"Lev",lv)
    local attData = generalData.FirstAtt
    local attDatalist = 0
    attDatalist = attData[attackIdx][2]
    if this.GetAllGeneralDatas(generalID).moduleProperty ~= nil then
        for key, value in pairs(this.GetAllGeneralDatas(generalID).moduleProperty.property) do
            if value.id == attackIdx then
                attDatalist = attDatalist+value.value
            end
        end
    end
    return attDatalist
end

--获取契约当前等级属性数据
function this.GeneralAttLevel(generalID,lv,attackIdx)
    local generalData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.GeneralLevelConfig,"GeneralId",generalID,"Lev",lv)
    local generalDatas = GeneralManager.GetAllGeneralDatas(generalID)
    local indexNum = generalDatas.exp/generalData.AddExp
    local attData = generalData.FirstAtt
    if indexNum > 0 then
        local addNum = generalData.AddAtt[attackIdx][2] * indexNum
        return attData[attackIdx][2] + addNum
    else
        return attData[attackIdx][2]
    end
end
--获取契约当前等级属性数据上限
function this.GeneralLevel(generalID, lv, attackIdx)
    local generalData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.GeneralLevelConfig,"GeneralId",generalID,"Lev",lv)
    local attData = generalData.FirstAtt
    return attData[attackIdx][2]
end

--获取契约属性数据
function this.GeneralOtherAtt(generalID,attackIdx)
    local generalData = this.GetAllGeneralDatas(generalID)
    local attData = generalData.FirstAtt
    local attDatalist = 0
    if this.GetAllGeneralDatas(generalID).moduleProperty ~= nil then
        for key, value in pairs(this.GetAllGeneralDatas(generalID).moduleProperty.property) do
            if value.id == attackIdx then
                if propertyConfig[attackIdx].Style == 2 then
                    attDatalist = value.value/10000*100
                else
                    attDatalist = value.value
                end
            end
        end
    end
    return attDatalist
end

--获取契约下一星级属性数据
function this.GeneralOtherRankAtt(generalID,attackIdx,rank)
    local generalData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.GeneralStepConfig,"GeneralId",generalID,"StepLev",rank+1)
    if generalData == nil then
        return 0
    end
    local generalStepAtt = generalData.StepAtt
    local attDatalist = 0
    if generalStepAtt[1] == attackIdx then
        if propertyConfig[attackIdx].Style == 2 then
            attDatalist = generalStepAtt[2]/10000*100
        else
            attDatalist = generalStepAtt[2]
        end
    end
    return attDatalist
end

--获取契约解锁状态
function this.GetAllLock(index)
    local getAllHero = HeroManager.GetAllHeroDatas(nil)
    local general = generalStepConfig[index]
    local generalNum = 0
    for key, value in pairs(getAllHero) do
        if value.star >= general.LockHero[1] then
            if value.property == general.LockHero[3] then
                generalNum = generalNum + 1
            end
        end
    end
    if generalNum >= general.LockHero[2] then
        return true
    end
    return false
end

--获取契约升阶
function this.RankInfo(index,rank)
    local rankInfo = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.GeneralStepConfig,"GeneralId",index,"StepLev",rank+1)
    if rankInfo == nil then
        return nil
    end
    local rankUpItem = rankInfo.UpgradeExpend
    return rankUpItem
end

function this.getAllData(index)
    local generalLsData = this.GetAllGeneralDatas(index)
    if generalLsData == nil then
        -- LogRed("没获取到契约数据")
        return {}
    end
    local generalDateList = {}
    local generalData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.GeneralLevelConfig,"GeneralId",index,"Lev",generalLsData.level)
    local generalDateOther = this.GetAllGeneralDatas(index)
    local attData = generalData.FirstAtt
    local indexNum = generalLsData.exp/generalData.AddExp
    for i = 1, #attData, 1 do
        if indexNum > 0 then
            local addNum = generalData.AddAtt[i][2] * indexNum
            generalDateList[attData[i][1]] = attData[i][2] + addNum
        else
            generalDateList[attData[i][1]] = attData[i][2]
        end
    end
    generalDateList[5] = this.GeneralOtherAtt(index,5)
    generalDateList[61] = this.GeneralOtherAtt(index,61)*100
    generalDateList[62] = this.GeneralOtherAtt(index,62)*100
    return  generalDateList
end

-- -- 刷新契约红点
-- function this.RefreshRedPointState()
--     local state = false
--     for i = 1, 6 do
--         local data = this.GetAllGeneralDatas(i)
--         if data then
--             local state_1 = false
--             if data.level < GeneralManager.MaxLevel(i) then
--                 local generalUpdata = this.UpgradeExpend(i,data.level).UpgradeExpend
--                 if BagManager.GetItemCountById(generalUpdata[1][1]) > generalUpdata[1][2] and BagManager.GetItemCountById(generalUpdata[2][1]) > generalUpdata[2][2] then
--                     state_1 = true
--                 end
--             end
--             local state_2 = false
--             local generalUpRank = GeneralManager.RankInfo(i,data.rankUpLevel)
--             if data.rankUpLevel < 50 then
--                 if BagManager.GetItemCountById(generalUpRank[2][1]) > generalUpRank[2][2] and BagManager.GetItemCountById(generalUpRank[1][1]) > generalUpRank[1][2] then
--                     state_2 = true
--                 end
--             else
--                 state_2 = false
--             end

--             if not state then
--                 state = state_1 or state_2
--             end
--         end
--     end
--     return state
-- end

-- 是否可解锁
function this.IsCanUnlock(id)
    local general = this.GetAllGeneralDatas(id)
    if general ~= nil then return false end

    -- 可用于解锁的英雄列表
    local upStarHeroListData = HeroManager.GetUpStarHeroListData(23, {property = G_GeneralConfig[id].LockHero[3]}).heroList
    local isCanUnLockNum = 0 -- 可用于解锁的英雄数量
    for index, data in ipairs(upStarHeroListData) do
        local teamIdList = HeroManager.GetAllFormationByHeroId(data.dynamicId)
        if #teamIdList > 0 or data.lockState == 1 then
        else
            isCanUnLockNum = isCanUnLockNum + 1
        end
    end
    return isCanUnLockNum > 0
end

-- 是否可升级
function this.IsCanUpLevel(id)
    local general = this.GetAllGeneralDatas(id)
    if general == nil then return false end

    -- local upRank = this.RankInfo(id, general.rankUpLevel)
    local upData = this.UpgradeExpend(id, general.level).UpgradeExpend
    if general.level >= this.MaxLevel(id) then
        return false
    -- elseif upRank == nil then
    --     return false
    else
        if BagManager.GetItemCountById(upData[1][1]) < upData[1][2] or BagManager.GetItemCountById(upData[2][1]) < upData[2][2] then
            return false
        end
    end
    return true
end

-- 是否可进阶
function this.IsCanAdvanced(id)
    local general = this.GetAllGeneralDatas(id)
    if general == nil then return false end
    
    local upRank = this.RankInfo(id, general.rankUpLevel)
    if general.rankUpLevel + 1 > 50 then
        return false
    end
    local advancedLv = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.GeneralStepConfig,"GeneralId", id,"StepLev",general.rankUpLevel + 1)
    if advancedLv.GeneralLev <= general.level then
        if general.rankUpLevel == 50 then
            return false
        else
            if BagManager.GetItemCountById(upRank[2][1]) < upRank[2][2] or BagManager.GetItemCountById(upRank[1][1]) < upRank[1][2] then
                return false
            end
        end
    else
        return false
    end
    return true
end

--刷新契约红点
function this.RefreshRedPointState()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GENERAL) then
        return false
    end
    for i = 1, 5 do
        if this.IsCanUnlock(i) or this.IsCanUpLevel(i) or this.IsCanAdvanced(i) then
            return true
        end
    end
    return false
end

return this