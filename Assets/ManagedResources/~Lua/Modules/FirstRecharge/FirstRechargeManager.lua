--[[
 * @ClassName FirstRechargeManager
 * @Description 首充管理
 * @Date 2019/7/4 19:11
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]

FirstRechargeManager = {}
local this = FirstRechargeManager
local activityRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
local AccumRechargeValue
--充值
local rechargeTime

function this.Initialize()

end

function this.GetFirstRechargeRedPointStatus()
    local redPoint = false
    if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FirstRecharge) then
        if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FirstRecharge) then
            redPoint = redPoint or this.GetSixMoneyTabRedPointStatus()
            redPoint = redPoint or this.GetHundredTabRedPointStatus()
        end
    end
    return redPoint
end

function this.GetSixMoneyTabRedPointStatus()
    local redPoint = false
    for _, rewardInfo in ConfigPairs(activityRewardConfig) do
        if rewardInfo.ActivityId == ActivityTypeDef.FirstRecharge and rewardInfo.Values[1][1] == IndexValueDef[1] then
            redPoint = redPoint or this.GetDayItemRedPoint(rewardInfo)
        end
    end
    return redPoint
end

function this.GetHundredTabRedPointStatus()
    local redPoint = false

    --奖励数据
    for _, rewardInfo in ConfigPairs(activityRewardConfig) do
        if rewardInfo.ActivityId == ActivityTypeDef.FirstRecharge and rewardInfo.Values[1][1] == IndexValueDef[2] then
            local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FirstRecharge)
            local AccumRecharge = 0
            for _, missInfo in pairs(activityInfo.mission) do
                if missInfo and missInfo.progress then
                    AccumRecharge = missInfo.progress
                end
            end

            if AccumRecharge == 0 then
                redPoint = false
            else
                if AccumRecharge/100 >= rewardInfo.Values[1][1]*10 then
                    if this.isFirstRecharge == 0 then
                        this.SetRechargeTime(math.floor(GetTimeStamp()))
                        this.isFirstRecharge = 1
                    end
                    local day = GetTimePass(this.GetRechargeTime())
                    if rewardInfo.Values[1][2] <= day then
                        if not ActivityGiftManager.GetActivityInfo(ActivityTypeDef.FirstRecharge, rewardInfo.Id) then
                            redPoint = false
                        end
                        local state = ActivityGiftManager.GetActivityInfo(ActivityTypeDef.FirstRecharge, rewardInfo.Id).state
                        return state == 0
                    else
                        redPoint = false
                    end
                else
                    redPoint = false
                end
            end
        end
    end

    return redPoint
end

function this.GetDayItemRedPoint(context)
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FirstRecharge)
    local AccumRecharge = 0
    for _, missInfo in pairs(activityInfo.mission) do
        if missInfo and missInfo.progress then
            AccumRecharge = missInfo.progress
        end
    end

    if AccumRecharge == 0 then
        return false
    else
        if AccumRecharge >= context.Values[1][1] then
            if this.isFirstRecharge == 0 then
                this.SetRechargeTime(math.floor(GetTimeStamp()))
                this.isFirstRecharge = 1
            end
            local day = GetTimePass(this.GetRechargeTime())
            if context.Values[1][2] <= day then
                if not ActivityGiftManager.GetActivityInfo(ActivityTypeDef.FirstRecharge, context.Id) then
                    return false
                end
                local state = ActivityGiftManager.GetActivityInfo(ActivityTypeDef.FirstRecharge, context.Id).state
                return state ~= 1
            else
                return false
            end
        else
            return false
        end
    end
    return false
end

function this.GetReceiveAll()
    local condition = true
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FirstRecharge)
    if activityInfo then
        for i = 1, #activityInfo.mission do
            local rechargeInfo = activityInfo.mission[i]
            condition = condition and rechargeInfo.state == 1
        end
    end
    return condition
end

function this.GetFirstRechargeExist()
    if this.GetReceiveAll() or ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FirstRecharge) == nil then
        return false
    end
    return true
end

-----------首充，累充相关----------------------
this.isFirstRecharge = 0
--刷新累计充值金额
function this.RefreshAccumRechargeValue(goodsId)
    if this.isFirstRecharge == 0 then
        this.SetRechargeTime(math.floor(GetTimeStamp()))
        this.isFirstRecharge = 1
    end

    if LuckyCatManager.isOpenLuckyCat then
        LuckyCatManager.SetAccumRechargeValue()
    end
end

function this.SetAccumRechargeValue(value, flag)
    if flag then
        AccumRechargeValue = AccumRechargeValue + value
        CheckRedPointStatus(RedPointType.FirstRecharge)
    else
        AccumRechargeValue = value
    end
end

function this.GetAccumRechargeValue()
    return AccumRechargeValue
end

function this.SetRechargeTime(value)
    rechargeTime = value
end

function this.GetRechargeTime()
    return rechargeTime
end
--设置红点存储本地
function this.PlayerPrefsSetStrItemId(val)
    PlayerPrefs.SetInt(PlayerManager.uid.."FirstRechatgePace", val)
end
--获得红点信息
function this.PlayerPrefsGetStrItemId()
    return PlayerPrefs.GetInt(PlayerManager.uid.."FirstRechatgePace", 0)--1 已经查看过不需要显示新红点  0 显示红点
end
function this.IsShowFirstChatge()
    if FirstRechargeManager.isFirstRecharge == 1 and FirstRechargeManager.PlayerPrefsGetStrItemId() == 0 and ActTimeCtrlManager.IsQualifiled(38) and FirstRechargeManager.GetFirstRechargeExist() then
        return true
    else
        return false
    end
end
return this