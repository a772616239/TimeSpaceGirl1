--[[
 * @ClassName VipManager
 * @Description 特权等级管理
 * @Date 2019/5/22 10:22
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]

VipManager = {}
local this = VipManager

local vipLevel = 0
local hadTakeLevelBox, hadTakeDailyBox
local vipLevelConfig = ConfigManager.GetConfig(ConfigName.VipLevelConfig)
local shopData = ConfigManager.GetConfig((ConfigName.StoreConfig))
local minLevel = 0
local maxLevel = 0
local m_chargedNum = 0
local m_rewardLeve = 0
local lastCharged = 0

function this.Initialize()
    --累充金额，由服务器返回
    -- 设置最高等级
    this.SetMaxVipLevel()
    this.totalCostMoney = 0
    -- 初始化Vip礼包数据
    this.InitVipShopData()
    -- 监听商店开启
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionOpen, function (openId)
        if openId == 20 then
            CheckRedPointStatus(RedPointType.VIP_SHOP_DETAIL)
        end
    end)
end
function this.GetVipLevel()
    return vipLevel
end
-- 登录时初始化Vip信息
function this.InitInfoOnLogin(msg)
    -- 避免服务器不同代码
    if msg.amount then
        lastCharged = msg.amount
        this.RefreshChargeMoney(msg.amount, true)
    end

    if msg.vipDaily then
        this.SetRewardVipLevel(msg.vipDaily)
    end

    -- 每天第一次登录时, 重置红点信息
    if PatFaceManager.isFirstLog == 0 then
        this.ReSetBtnListRedState()
    end
    PlayerPrefs.SetInt(PlayerManager.uid.."czlb", 0)--成长礼包红点每次登录显示
end

--vip等级的取设, 刷新Vip等级
function this.SetVipLevel(level)
    vipLevel = level
    AdventureManager.RefreshAttachVipData()
    MapTrialManager.RefreshAttachVipData()
    SecretBoxManager.RefreshFreeTime()
    RecruitManager.RefreshFreeTime()
    GoodFriendManager.OnRefreshEnegryData()
    CheckRedPointStatus(RedPointType.LuckyCat_GetReward)
    Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
    Game.GlobalEvent:DispatchEvent(GameEvent.Vip.OnVipRankChanged)
end

-- 刷新累充数量,更新VIP等级
function this.RefreshChargeMoney(chargedNum, isLogin)
    -- 先检测是否升级了
    local oldLevel = this.SetLevelByCost(lastCharged)

    m_chargedNum = chargedNum
    local vipLevel = this.SetLevelByCost(chargedNum)
    -- this.SetVipLevel(vipLevel)

    if oldLevel ~= this.GetVipLevel() and not isLogin then
        CheckRedPointStatus(RedPointType.VIP_SHOP_DETAIL)
        CheckRedPointStatus(RedPointType.VipPrivilege)
    end
    -- 同步充值金额
    lastCharged = chargedNum
    --刷新下签到红点
    CheckRedPointStatus(RedPointType.CumulativeSignIn)
end

-- 获得累充数量
function this.GetChargedNum()
    return m_chargedNum
end

-- 根据充值数量设置Vip等级
function this.SetLevelByCost(cost)
    local level = minLevel
    if cost <= vipLevelConfig[minLevel].MoneyLimit then
        level = minLevel
    elseif cost >= vipLevelConfig[maxLevel].MoneyLimit then
        level = maxLevel
    end

    for k, v in ConfigPairs(vipLevelConfig) do
        local money = v.MoneyLimit
        if v.VipLevel < maxLevel then
            if cost >= money and cost < vipLevelConfig[v.VipLevel + 1].MoneyLimit then
                level = v.VipLevel + 1
            end
        end
    end
    level = level > maxLevel and maxLevel or level
    return level
end

-- 距离升级到下一档位还需充值金额
function this.GetNextLevelNeed()
    local chargedNum = this.GetChargedNum()
    local nextLevelNeed = vipLevelConfig[this.GetVipLevel()].MoneyLimit
    local maxLevelNeed = this.CurLevelMoneyNeed(maxLevel)

    -- 最高等级不需要再充钱
    local needNum = 0
    if chargedNum < maxLevelNeed then
        needNum = nextLevelNeed - chargedNum
        needNum = needNum <= 0 and 0 or needNum
    else
        nextLevelNeed = maxLevelNeed
    end

    return needNum, nextLevelNeed
end


-- 达到当前档位需要的累充金额（X1显示为充值积分因此最终显示数值*10）
function this.CurLevelMoneyNeed(curLevel)
    local need = 0
    local lastLevel = curLevel - 1 <= 0 and 0 or curLevel - 1
    need = vipLevelConfig[lastLevel].MoneyLimit
    if curLevel == 0 then
        need = 0
    end
    return need * 10
end


function this.GetVipLevel()
    return vipLevel
end

--vip等级权益状态的取设
function this.SetTakeLevelBoxStatus(value)
    hadTakeLevelBox = value
end
function this.GetTakeLevelBoxStatus()
    return hadTakeLevelBox
end
--vip每日礼包权益状态的取设
function this.SetTakeDailyBoxStatus(value)
    hadTakeDailyBox = value
end
function this.GetTakeDailyBoxStatus()
    return hadTakeDailyBox
end

function this.InitCommonData(context)
    this.SetVipLevel(context.vipLevel)
    this.SetTakeDailyBoxStatus(context.hadTakeDailyBox)
    this.SetTakeLevelBoxStatus(context.hadTakeLevelBox)
end

--五点刷新数据
function this.FiveAMRefreshLocalData(hadTakeDailyBox)

    VipManager.SetTakeDailyBoxStatus(hadTakeDailyBox)
    --通知Vip界面刷新数据
    MapTrialManager.RefreshAttachVipData()
    SecretBoxManager.RefreshFreeTime()
    RecruitManager.RefreshFreeTime()
    GoodFriendManager.OnRefreshDataNextDay()
    ShopManager.FiveAMRedpotStatusReset()

    -- 5点时刷新一下
    this.SetRewardVipLevel(hadTakeDailyBox)
    -- 重置按钮的红点状态
    this.ReSetBtnListRedState()
    Game.GlobalEvent:DispatchEvent(GameEvent.Vip.OnVipDailyRewardStatusChanged)
    CheckRedPointStatus(RedPointType.VIP_SHOP_DETAIL)
    CheckRedPointStatus(RedPointType.VipPrivilege)
end


-- 需要显示在主界面的文字
function this.GetMainPanelShowText()
    local missionInfo = TaskManager.GetTypeTaskList(TaskTypeDef.VipTask)
    table.sort(missionInfo, function(a, b)
        return a.state < b.state
    end)

    local isDone = true

    for i = 1, #missionInfo do
        if missionInfo[i].state == 0 then
            isDone = false
            break
        end
    end

    local str = ""
    if isDone then
        str=GetLanguageStrById(12007)
    else
        str= ConfigManager.GetConfigData(ConfigName.TaskConfig, missionInfo[1].missionId).Desc
    end
    
    --local info = ConfigManager.GetConfigData(ConfigName.TaskConfig, missionInfo[1].missionId)
    --
    --str = isDone and "当前特权等级的任务已经完成" or info.Desc
    return str
end

-- 某一特权对应的第一个礼包奖励
function this.GetFirstNameByLevel(level)
    level = level + 1
    local  str = ""
    for k, v in ConfigPairs(shopData) do
        if v.StoreId == SHOP_TYPE.VIP_GIFT and v.Sort == level then
            str = v.GoodsName
            break
        end
    end

    return str
end

function this.InitVipShopData()
    this.vipShopData = {}
    for k, v in ConfigPairs(shopData) do
        if v.StoreId == SHOP_TYPE.VIP_GIFT then
            this.vipShopData[v.Sort] = v
        end
    end
end

function this.SetMaxVipLevel()
    local max = 0
    for i, v in ConfigPairs(vipLevelConfig) do
        max = max > v.VipLevel and max or v.VipLevel
    end
    maxLevel = max
end

function this.GetMaxVipLevel()
    return maxLevel
end

-- 获取豪华月卡的激活状态
function this.GetMonthCardOpenState()
    local isActive = false
    --local endTime = OperatingManager.GetGoodsEndTime(GoodsTypeDef.LuxuryMonthCard)
    --if endTime and endTime - GetTimeStamp() > 0 then
    --    isActive = true
    --else
    --    isActive = false
    --end
    local curAllMonthCardData = OperatingManager.GetMonthCardData()
    isActive = curAllMonthCardData[MONTH_CARD_TYPE.LUXURYMONTHCARD] and curAllMonthCardData[MONTH_CARD_TYPE.LUXURYMONTHCARD].endingTime ~= 0
    return isActive
end

-- 获取每日奖励的领取状态。0时表示未领， 大于0表示已经领取过
function this.GetRewardState()
    return m_rewardLeve
end

-- 设置领取礼包时的Vip等级
function this.SetRewardVipLevel(level)
    m_rewardLeve = level
end

-- 获取今天领取礼包时的Vip等级
function this.GetRewardVipLevel()
    return m_rewardLeve
end

------------------------- 红点  --------------------------
function this.ReSetBtnListRedState()
    for i = 0, maxLevel do
        this.SetBuyBtnRed(i, 0)
    end
end

--- 记录按钮点击红点
function this.GetBuyBtnRedState(level)
    return PlayerPrefs.GetInt(PlayerManager.uid .. "VIP_GIFT" .. level)
end

function this.SetBuyBtnRed(level, value)
    PlayerPrefs.SetInt(PlayerManager.uid .. "VIP_GIFT" .. level, value)
end

-- 一排按钮的红点
function this.GetBtnListRed(level)
    local data = this.vipShopData[level + 1]
    local leftNum = ShopManager.GetShopItemRemainBuyTimes(SHOP_TYPE.VIP_GIFT, data.Id)

    local canBuy = false -- 剩余购买次数大于0
    if leftNum > 0 and this.GetVipLevel() >= level then
        canBuy = true
    else
        canBuy = false
    end

    local isFirst = this.GetBuyBtnRedState(level) == 0  -- 今天或者解锁后的第一次点击
    return isFirst and canBuy
end

-- 检查红点
function this.CheckRedPoint()
    -- local isShopOpen = ActTimeCtrlManager.SingleFuncState(20)
    -- -- 检查每日礼包奖励
    -- local hasReward = false
    -- local isActive = this.GetMonthCardOpenState()
    -- local getState = this.GetRewardState()

    -- if not isActive then
    --     hasReward = false
    -- else
    --     if getState < 1 then
    --         hasReward = true
    --     else
    --         hasReward = false
    --     end
    -- end

    -- --按钮红点
    -- local num = 0
    -- for i = 0, maxLevel do
    --     if this.GetBtnListRed(i) then
    --         num = num + 1
    --     end
    -- end

    -- local condition = hasReward or num > 0
    -- condition = condition and isShopOpen

    -- 
    -- return condition
    return false
end

--外面那个不检测商店
function this.CheckVipRedPoint()
       -- 检查每日礼包奖励
    local hasReward = false
    local isActive = this.GetMonthCardOpenState()
    local getState = this.GetRewardState()

    if not isActive then
        hasReward = false
    else
        if getState < 1 then
            hasReward = true
        else
            hasReward = false
        end
    end

    --按钮红点
    local num = 0
    for i = 0, maxLevel do
        if this.GetBtnListRed(i) then
            num = num + 1
        end
    end

    local condition = hasReward or num > 0

    return condition
end

-- 检测新vip红点
function this.CheckNewVipRP()
    if VipManager.GetVipLevel() >= VipManager.GetMaxVipLevel() then
        return false
    end
    local isFinish = true
    local list = TaskManager.GetTypeTaskList(TaskTypeDef.VipTask)
    if not list then return false end
    for _, t in ipairs(list) do
        if t.state == VipTaskStatusDef.CanReceive then
            return true
        elseif  t.state == VipTaskStatusDef.NotFinished then
            isFinish = false
        end
    end
    return isFinish
end

function this.CheckGrowthPackagePointStatus()--成长礼包
    local redointTime = PlayerPrefs.GetInt(PlayerManager.uid.."czlb", 0)
    local rechargeNum = VipManager.GetChargedNum()--已经充值的金额
    local shopItem = ShopManager.GetShopDataByType(SHOP_TYPE.VIP_GIFT)
    if shopItem then
        local shopData = shopItem.storeItem
        local shopItemConfig = ConfigManager.GetConfig(ConfigName.StoreConfig)
        for i = 1, #shopData do
            local boughtNum = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.VIP_GIFT, shopData[i].id)
            if rechargeNum >= shopItemConfig[shopData[i].id].BuyRule[2] and boughtNum == 0 then
                if redointTime == 0 then
                    return true
                end
            end
        end
    else
        LogRed("打印：未找到商店类型:" .. SHOP_TYPE.VIP_GIFT)
    end
    return false
end

 ---主界面显示使用
function this.SetVipLevelImg()
    --- vip 0 暂时没有资源
    local level = this.GetVipLevel()
    level = level or 0
    local img = Util.LoadSprite("T_vip_" .. level .. "_meisuzi")
    return img
end

-----------------------------------------------------
--- 获取vip属性加成
function this.GetAddPro()
    local proList = {}
    local level = this.GetVipLevel()
    local VipLvConfig = ConfigManager.GetConfigData(ConfigName.VipLevelConfig, level)
    for idx, dataInfo in ipairs(VipLvConfig.Property) do
        proList[dataInfo[1]] = dataInfo[2]
    end
    return proList
end

--vippanel的每日奖励
function this.RefreshEveryDayGiftRedpoint()
    --VIP0 0元购
    local shopData = VipManager.vipShopData[1]
    if shopData then
        local costId, finalCost, orignalCost = ShopManager.calculateBuyCost(SHOP_TYPE.VIP_GIFT, shopData.Id, 1)
        local leftNum = ShopManager.GetShopItemRemainBuyTimes(SHOP_TYPE.VIP_GIFT, shopData.Id)
        local canBuy = false
        if leftNum < 1 and leftNum ~= -1 then
            canBuy = false
        else
            canBuy = true
        end
        if canBuy and finalCost == 0 then
            return true
        end
    end

    local isActive = OperatingManager.GetMonthCardIsOpen(MONTH_CARD_TYPE.LUXURYMONTHCARD)
    local getState = VipManager.GetRewardState()
    if not isActive then
        return false
    else
        if getState < 1 then
            return true
        else
            return false
        end
    end
end

return this