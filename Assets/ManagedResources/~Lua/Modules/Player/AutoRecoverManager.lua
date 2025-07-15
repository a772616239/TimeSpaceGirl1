AutoRecoverManager = {}
local this = AutoRecoverManager
local FreeTravel = ConfigManager.GetConfig(ConfigName.FreeTravel)
this.nextFlushTime=0

--- 注册物品及其获取恢复时间的方法
local _TimeCheckFunc = {
    [UpViewRechargeType.EliteCarbonTicket] = function()
        local ownNumber = BagManager.GetItemCountById(UpViewRechargeType.EliteCarbonTicket)
        if ownNumber < CarbonManager.gameSetting[1].HeroTimes then
            return CarbonManager.remainTime
        else -- 数量已满返回 -1
            return -1
        end
    end,
    -- [UpViewRechargeType.MonsterCampTicket] = function()
    --     if MonsterCampManager.IsNeedSupply() then
    --         local nextFreshTime = BagManager.bagDatas[UpViewRechargeType.MonsterCampTicket].nextFlushTime
    --         local remationTime = nextFreshTime - PlayerManager.serverTime
    --         return remationTime
    --     else -- 数量已满返回 -1
    --         return -1
    --     end
    -- end,
    [UpViewRechargeType.AdventureAlianInvasionTicket] = function()
        local curCount = BagManager.GetItemCountById(UpViewRechargeType.AdventureAlianInvasionTicket)
        local maxCount = PrivilegeManager.GetPrivilegeNumber(9)
        if curCount < maxCount then
            local nextFreshTime = BagManager.bagDatas[UpViewRechargeType.AdventureAlianInvasionTicket].nextFlushTime
            local remationTime = nextFreshTime - PlayerManager.serverTime
            return remationTime
        else -- 数量已满返回 -1
            return -1
        end
    end,
    [UpViewRechargeType.ActPower] = function()
        local curCount = EndLessMapManager.GetLeftMapEnergy()
        local maxCount = PrivilegeManager.GetPrivilegeNumber(20)
        if curCount < maxCount then
            local nextFreshTime = BagManager.bagDatas[UpViewRechargeType.ActPower].nextFlushTime
            local remationTime = nextFreshTime - PlayerManager.serverTime
            return remationTime
        else -- 数量已满返回 -1
            return -1
        end
    end,
    [UpViewRechargeType.Energy] = function()
        local curCount = BagManager.GetItemCountById(UpViewRechargeType.Energy)
        local maxCount = PlayerManager.userLevelData[PlayerManager.level].MaxEnergy
        if curCount < maxCount then
            local nextFreshTime = BagManager.bagDatas[UpViewRechargeType.Energy].nextFlushTime
            local remationTime = nextFreshTime - PlayerManager.serverTime   -- 下一次刷新的时间

            -- 计算从下一次刷新到恢复满得时间
            local gameSetting = ConfigManager.GetConfigData(ConfigName.GameSetting, 1)
            local recoverNum = gameSetting.EnergyRecoverSpeed[1]
            local recoverTime = gameSetting.EnergyRecoverSpeed[2]
            local fullTime = math.floor((maxCount - curCount) / recoverNum - 1) * recoverTime * 60

            return remationTime + fullTime
        else -- 数量已满返回 -1
            return -1
        end
    end,
    [UpViewRechargeType.YunYouVle] = function()   --逍遥游云游值倒计时
        local curCount = BagManager.GetItemCountById(UpViewRechargeType.YunYouVle)
        local maxCount = PrivilegeManager.GetPrivilegeNumber(40)
        local itemData = BagManager.GetItemById(UpViewRechargeType.YunYouVle)
        -- if not itemData then
        --     return
        -- end
        if curCount < maxCount then
            local nextFreshTime = this.nextFlushTime
            local remationTime = nextFreshTime - PlayerManager.serverTime   -- 下一次刷新的时间       
            if remationTime > 0 then
                
                return remationTime
            end
            -- 需要刷新数量
            return -2
        else -- 数量已满返回 -1
            return -1
        end
    end,
    
}


function this.Initialize()
    -- this.nextFlushTime=PlayerManager.serverTime + PlayerManager.serverTime
    Timer.New(function()
        local special = ConfigManager.GetConfigData(ConfigName.SpecialConfig,154)
        local data = string.split(special.Value,"#")
        local itemId = UpViewRechargeType.YunYouVle
        local deltaNum = data[3]
        local deltaTime = data[2]
        if this.IsAutoRecover(itemId) then
            local leftTime = this.GetRecoverTime(itemId)
            -- 已满不需要刷新
            -- 
            if leftTime == -2 then
                -- BagManager.bagDatas[itemId].num = BagManager.bagDatas[itemId].num + deltaNum
                -- this.nextFlushTime = this.nextFlushTime + deltaTime
                local xiaoyaoBo=false
                for index, config in ConfigPairs(FreeTravel) do
                    if ActivityGiftManager.GetActivityIdByZq(config.ActivityId)~=nil then
                        xiaoyaoBo=true
                    end
                end
                if xiaoyaoBo and this.nextFlushTime~=-1 then
                    NetManager.DiceInfoRequest(1,function ()
        
                    end)
                end

                -- Log("自动恢复物品数量刷新："..itemId.."|"..BagManager.bagDatas[itemId].num.."|"..this.nextFlushTime)
            end
        end
    end, 1, -1, true):Start()
end

-- 获取道具是否自动恢复
function AutoRecoverManager.IsAutoRecover(itemId)
    if not _TimeCheckFunc[itemId] then
        return false
    end
    return true
end

-- 获取道具恢复时间
function AutoRecoverManager.GetRecoverTime(itemId)
    if not _TimeCheckFunc[itemId] then
        assert(false, GetLanguageStrById(11499).. itemId)
    end
    return _TimeCheckFunc[itemId]()
end

return this