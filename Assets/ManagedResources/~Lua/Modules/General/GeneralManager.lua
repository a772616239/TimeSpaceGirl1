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
    --口径对齐 LockHero[2]：以前只判「有没有」，凑够 1 张就真，与真正能解锁的数量要求脱节
    local needNum = G_GeneralConfig[id] and G_GeneralConfig[id].LockHero and G_GeneralConfig[id].LockHero[2] or 1
    return isCanUnLockNum >= needNum
end

-- 消耗是否足够（红点与点击校验共用这一套口径，避免两处各算一遍）
-- cost 形如 {{itemId,num},...}，按实际条目数遍历，不再写死 2 项
function this.IsCostEnough(cost)
    if cost == nil or cost[1] == nil then
        return false
    end
    for i = 1, #cost do
        local item = cost[i]
        if item == nil or item[1] == nil or item[2] == nil then
            return false
        end
        if BagManager.GetItemCountById(item[1]) < item[2] then
            return false
        end
    end
    return true
end

-- 是否可升级
function this.IsCanUpLevel(id)
    local general = this.GetAllGeneralDatas(id)
    if general == nil then return false end
    -- 先判满级，再取消耗，避免末级/缺行时对 nil 取下标
    if general.level >= this.MaxLevel(id) then
        return false
    end
    local upCfg = this.UpgradeExpend(id, general.level)
    if upCfg == nil then
        return false
    end
    return this.IsCostEnough(upCfg.UpgradeExpend)
end

-- 是否可进阶
function this.IsCanAdvanced(id)
    local general = this.GetAllGeneralDatas(id)
    if general == nil then return false end

    local nextRank = general.rankUpLevel + 1
    local advancedLv = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.GeneralStepConfig,"GeneralId", id,"StepLev",nextRank)
    if advancedLv == nil then
        return false
    end
    -- 等级不达标（与服务端 rankUp 的 GeneralLev 校验一致）
    if advancedLv.GeneralLev > general.level then
        return false
    end
    return this.IsCostEnough(advancedLv.UpgradeExpend)
end

--红点判定统一包一层：单个契约/单条配置判定出错，不能把整轮刷新打断。
--一旦在循环里抛出，后面的页签与按钮都轮不到 SetActive，页签会停在 prefab 里默认亮着的红点上
--（m_IsActive=1），表现就是「没材料也一直显示红点」。出错时打日志并当作不可操作。
function this.SafeCheck(checkFunc, id)
    local ok, ret = pcall(checkFunc, id)
    if not ok then
        LogRed("[General] 红点判定异常 id=" .. tostring(id) .. " : " .. tostring(ret))
        return false
    end
    return ret == true
end

--页签红点口径：该契约现在能不能升级/能不能进阶（材料是否足够），与点击校验共用同一套函数
function this.CanUpgradeOrRank(id)
    return this.SafeCheck(this.IsCanUpLevel, id) or this.SafeCheck(this.IsCanAdvanced, id)
end

--可解锁（带保护）
function this.CanUnlockSafe(id)
    return this.SafeCheck(this.IsCanUnlock, id)
end

--解锁按钮红点口径 = 点击校验（GetAllLock）能通过 且 真有一张可献祭的卡
--只判 GetAllLock 会把「卡都在编队里」也算成可解锁，红点亮着却点不动
function this.CanUnlockNow(id)
    local ok, ret = pcall(this.GetAllLock, id)
    if not ok then
        LogRed("[General] GetAllLock 异常 id=" .. tostring(id) .. " : " .. tostring(ret))
        return false
    end
    return ret == true and this.CanUnlockSafe(id)
end

--刷新契约红点
function this.RefreshRedPointState()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GENERAL) then
        return false
    end
    for i = 1, 5 do
        if this.CanUnlockSafe(i) or this.CanUpgradeOrRank(i) then
            return true
        end
    end
    return false
end

-- 统一刷新契约红点：入口红点（LogisticsMainPanel）+ 已打开的契约面板
-- 背包/金钱变动、升级升阶成功都要走这里，否则红点会停在旧状态（点亮但点进去材料不足）
function this.RefreshRedPoint()
    CheckRedPointStatus(RedPointType.General)
    if UIManager.IsOpen(UIName.GeneralInfoPanel) and GeneralInfoPanel and GeneralInfoPanel.RefreshRedPoint then
        GeneralInfoPanel.RefreshRedPoint()
    end
end

return this