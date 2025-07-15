--[[
 * @Classname DailyRechargeManager
 * @Description 每日首充
 * @Date 2019/8/2 13:51
 * @Created by MagicianJoker
--]]
DailyRechargeManager = {}
local this = DailyRechargeManager

local rechargeState = false
local rechargeValue = 0
local rechargeState_2 = false
local rechargeValue_2 = 0

function this.Initialize()
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityProgressStateChange, this.DailyRechargeChanged)
    Game.GlobalEvent:AddEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, this.DailyRechargeReset)
end

function this.InitRechargeStatus()
    local dailyActInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.DailyRecharge)
    if dailyActInfo and dailyActInfo.mission[1] then
        rechargeState = dailyActInfo.mission[1].state
        rechargeValue = dailyActInfo.value
       
        -- if rechargeState == 0 then
        --     CheckRedPointStatus(RedPointType.DailyRecharge)
        -- end
    end

    local dailyActInfo_2 = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.DailyRecharge_2)
    if dailyActInfo_2 and dailyActInfo_2.mission[1] then
        rechargeState_2 = dailyActInfo_2.mission[1].state
        rechargeValue_2 = dailyActInfo_2.value
    end

    CheckRedPointStatus(RedPointType.DailyRecharge)
end

function this.GetRechargeValue(type)
    if type == ActivityTypeDef.DailyRecharge then
        return rechargeValue
    elseif type == ActivityTypeDef.DailyRecharge_2 then
        return rechargeValue_2
    end
end

--1已领取0未完成
function this.GetRechargeState(type)
    if type == ActivityTypeDef.DailyRecharge then
        return rechargeState == 1
    elseif type == ActivityTypeDef.DailyRecharge_2 then
        return rechargeState_2 == 1
    end
end

function this.SetRechargeState(type, value)
    if type == ActivityTypeDef.DailyRecharge then
        rechargeState = value
    elseif type == ActivityTypeDef.DailyRecharge_2 then
        rechargeState_2 = value
    end

end

function this.ReceivedEnabled(type)
    local dailyActInfo = ActivityGiftManager.GetActivityTypeInfo(type)
    if dailyActInfo and dailyActInfo.mission[1] then
        local actRewardConfig = ConfigManager.TryGetConfigData(ConfigName.ActivityRewardConfig, dailyActInfo.mission[1].missionId)

        if not actRewardConfig then --获取不到 false
            return false
        end
        return dailyActInfo.value/1000 >= actRewardConfig.Values[1][1]
    else
        return false
    end
end

function this.DailyRechargeReset()
    this.InitRechargeStatus()
    if not this.RefreshRedpoint() then
        Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnActivityOpenOrClose, {
            type = ActivityTypeDef.DailyRecharge,
            status = 1
        })
    end
end

function this.DailyRechargeChanged()
    this.InitRechargeStatus()
end

function this.GetDailyRechargeExist(type)
    local dailyActInfo = ActivityGiftManager.GetActivityTypeInfo(type)
    if this.GetRechargeState(type) or not dailyActInfo or not dailyActInfo.mission[1] then
        return false
    end

    return true
end

function this.DailyRechargeExist()
    return this.GetDailyRechargeExist(ActivityTypeDef.DailyRecharge) or this.GetDailyRechargeExist(ActivityTypeDef.DailyRecharge_2)
end

function this.RefreshRedpoint()
    return this.RefreshRedpoint_type(1) or this.RefreshRedpoint_type(2)
end

function this.RefreshRedpoint_type(index)
    local type
    if index == 1 then
        type = ActivityTypeDef.DailyRecharge
    else
        type = ActivityTypeDef.DailyRecharge_2
    end

    local dailyActInfo = ActivityGiftManager.GetActivityTypeInfo(type)
    if dailyActInfo and dailyActInfo.mission[1] then
        if dailyActInfo.mission[1].state == 0 then
            if DailyRechargeManager.GetRechargeValue(type) == 0 then
                return false
            else
                if DailyRechargeManager.ReceivedEnabled(type) then
                    return true
                else
                    return false
                end
            end
        end
    end
    return false
end

return this