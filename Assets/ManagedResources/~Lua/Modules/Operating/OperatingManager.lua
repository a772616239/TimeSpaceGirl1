--[[
 * @ClassName OperatingManager
 * @Description 运营活动管理
 * @Date 2019/6/6 10:29
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]

OperatingManager = {}
local this = OperatingManager

local giftGoodsInfoList = {}
--- 新的数据列表，按照ID存取
local newGoodsList = {}
local hadBuyGoodsList = {}
local rechargeConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
local luxuryConfig = ConfigManager.GetConfig(ConfigName.LuxuryFundConfig)
local MainLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local EncourageTaskConfig = ConfigManager.GetAllConfigsData(ConfigName.EncourageTaskConfig)
local EncouragePlanConfig = ConfigManager.GetConfig(ConfigName.EncouragePlanConfig)
local giftGoodsInfo
local isFistShow = true

--初始化
function this.Initialize()
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnLevelChange, function()
        CheckRedPointStatus(RedPointType.GrowthGift)
    end)

    Game.GlobalEvent:AddEvent(GameEvent.PatFace.PatFaceHaveGrowGift, this.NewHeroGift)
end


---------------------------局限性----------------------------
function this.SetBasicValues(giftGoodsList)
    giftGoodsInfo = giftGoodsList
    for _, v in pairs(GoodsTypeDef) do
        giftGoodsInfoList[v] = {}
    end
    for _, giftGoodsInfo in ipairs(giftGoodsList) do
        if rechargeConfig[giftGoodsInfo.goodsId] ~= nil then
            local rechargeConfig = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, giftGoodsInfo.goodsId)
            if giftGoodsInfoList[rechargeConfig.Type] then
                table.insert(giftGoodsInfoList[rechargeConfig.Type], giftGoodsInfo)
            end
        end
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.FindFairy.RefreshBuyOpenState)
end

--判断商品是否可购买（成长礼）
function this.IsGrowthGiftGoodsAvailable(goodsType)
    for _, v in ipairs(giftGoodsInfo)do
        local rechargeConfig = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, v.goodsId)
        if rechargeConfig.Type == goodsType and v.dynamicBuyTimes == 1 and v.buyTimes ~= v.dynamicBuyTimes then
            return v
        end
    end
    return nil
end

-- 判断商品数据是否在可用时间范围内
local function _IsGiftGoodsAvailable(gift)
    -- body
    if not gift then return false end
    if gift.startTime == 0 and gift.endTime == 0 then return true end
    local curTime = GetTimeStamp()
    local isAvailable = curTime > gift.startTime and curTime <= gift.endTime
    return isAvailable
end

function this.RemoveGiftInfoList(goodsType)
    giftGoodsInfoList[goodsType] = nil
end

--- 删除某一类型的某一条商品数据
function this.RemoveItemInfoByType(type, goodsId)
    if not giftGoodsInfoList[type] then 
        return
    end

    for k,v in pairs(giftGoodsInfoList[type]) do
        if v then
            if v.goodsId == goodsId then 
                table.remove(giftGoodsInfoList[type], k)
            end
        end
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.FindFairy.RefreshBuyOpenState)
end

function this.IsRechargeable(goodsType)
    return giftGoodsInfoList[goodsType]
end

--- 获取激活后的商品数据
function this.GetGiftGoodsInfo(goodsType, Id)
    -- if not giftGoodsInfoList[goodsType] then
    --     return nil
    -- end

    -- for _, giftGoodsInfo in pairs(giftGoodsInfoList[goodsType]) do
    --     if Id then
    --         if giftGoodsInfo.goodsId == Id then
    --             return giftGoodsInfo
    --         end
    --     else
    --         -- 判断是否可用
    --         if _IsGiftGoodsAvailable(giftGoodsInfo) then
    --             return giftGoodsInfo
    --         end
    --     end
    -- end
    -- return nil

    local data = this.GetGiftGoodsInfoList(goodsType)
    if next(data) == nil then
        return nil
    end

    for _, giftGoodsInfo in ipairs(data) do
        if Id then
            if giftGoodsInfo.goodsId == Id then
                return giftGoodsInfo
            end
        else
            -- 判断是否可用
            if _IsGiftGoodsAvailable(giftGoodsInfo) then
                return giftGoodsInfo
            end
        end
    end
    return nil
end

function this.GetGiftGoodsInfoList(type)
    -- return giftGoodsInfoList[type] and giftGoodsInfoList[type] or {}
    --> 加入LevelLinit 等级开启限制
    if giftGoodsInfoList[type] then
        local lv = PlayerManager.level
        local ret = {}
        for i = 1, #giftGoodsInfoList[type] do
            local goodsId = giftGoodsInfoList[type][i].goodsId
            local config = G_RechargeCommodityConfig[goodsId]
            if config and lv >= config.LevelLinit[1] and lv <= config.LevelLinit[2] then
                table.insert(ret, giftGoodsInfoList[type][i])
            end
        end
        return ret
    else
        return {}
    end
end

function this.RefreshGiftGoodsBuyTimes(goodsType, goodsId, buyTimes)
    if not giftGoodsInfoList[goodsType] then
        LogRed("打印：类型:"..goodsType.."商品ID："..goodsId.."服务器未传过来数据")
        return
    end
    for _, giftGoodsInfo in ipairs(giftGoodsInfoList[goodsType]) do
        if giftGoodsInfo.goodsId == goodsId then
            giftGoodsInfo.buyTimes = giftGoodsInfo.buyTimes --+ (buyTimes and buyTimes or 1)
        end
    end
end

function this.MyRefreshGiftGoodsBuyTimes(goodsType, goodsId, buyTimes)
    if not giftGoodsInfoList[goodsType] then
        return
    end
    for _, giftGoodsInfo in ipairs(giftGoodsInfoList[goodsType]) do
        if giftGoodsInfo.goodsId == goodsId then
            giftGoodsInfo.buyTimes = buyTimes
        end
    end
end

--- 获取商品的剩余购买次数
--- 0 不可买 1: 剩余1次,-1不限次数
function this.GetLeftBuyTime(type, goodsId)
    if not giftGoodsInfoList[type] then
        LogRed("打印：类型:"..type.."商品ID："..goodsId.."服务器未传过来数据")
        return
    end

    --- 此类商品的购买次数限制
    local limitTime = rechargeConfig[goodsId].Limit
    if limitTime == 0 then  --- 不限购
        return -1
    else
        local boughtTime = this.GetGoodsBuyTime(type, goodsId)
        return limitTime - boughtTime
    end
end


--- 获取商品已经购买次数
function this.GetGoodsBuyTime(type, goodsId)
    if not giftGoodsInfoList[type] then
        LogRed("打印：类型:"..type.."商品ID："..goodsId.."服务器未传过来数据")
        return
    end
    for k,v in pairs(giftGoodsInfoList[type]) do
        if v.goodsId == goodsId then
            return v.buyTimes
        end
    end
    LogRed("打印：类型:"..type.."商品ID："..goodsId.."服务器未传过来数据")
end

--------------------------------------------------------------
function this.SetHadBuyGoodsId(BuyGoodsList)
    for i = 1, #BuyGoodsList do
        table.insert(hadBuyGoodsList, BuyGoodsList[i])
    end
end

function this.GetHadBuyGoodsTypeId(type)
    local Id
    for _, goodsId in ipairs(hadBuyGoodsList) do
        if rechargeConfig[goodsId].Type == type then
            Id = goodsId
        end
    end
    return Id
end

--成长礼金红点
function this.GetGrowthRedPointState()
    local redPoint = false

    if not ActivityGiftManager.IsQualifiled(ActivityTypeDef.GrowthReward) then
        return redPoint
    end

    --每日免费礼包
    local freeData = ShopManager.GetShopDataByType(SHOP_TYPE.GROWTHFREE_GIFT)
    if freeData then
        local boughtNum = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.GROWTHFREE_GIFT, freeData.storeItem[1].id)
        local limitNum = ShopManager.GetShopItemLimitBuyCount(freeData.storeItem[1].id)
        local isCanBuy = limitNum - boughtNum >= 1
        if redPoint == false then
            redPoint = isCanBuy
        end
    end

    local giftGoodsInfo = OperatingManager.IsGrowthGiftGoodsAvailable(GoodsTypeDef.GrowthReward)
    if giftGoodsInfo then return redPoint end
    local openId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.GrowthReward)
    if openId then
        local actRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
        for _, configInfo in ConfigPairs(actRewardConfig) do
            if configInfo.ActivityId == openId then
                local activityInfo = ActivityGiftManager.GetActivityInfo(openId, configInfo.Id)
                if activityInfo and activityInfo.state == 0 then
                    if configInfo.Values[1][1] == ConditionType.Level then
                        if PlayerManager.level >= configInfo.Values[1][2] then
                            redPoint = true
                        end
                    elseif configInfo.Values[1][1] == ConditionType.CarBon then
                        local curLevel = tonumber(MainLevelConfig[FightPointPassManager.curOpenFight].Name - 1)
                        local target = tonumber(MainLevelConfig[configInfo.Values[1][2]].Name)
                        if curLevel >= target then
                            redPoint = true
                        end
                    end
                end
            end
        end
    end
    return redPoint
end


-- 商品时间数据
local _GoodsDurationData = {}
function this.SetGoodsDurationData(dataList)
    if not dataList then
        return
    end
    for _, data in ipairs(dataList) do
        -- 这里协议字段为goodsType其实数据为ID
        _GoodsDurationData[data.goodsType] = data.endTime
    end
end
-- 根据类型判断相应的物品是否开启并返回相应的ID
function this.GetActiveGoodsIDByType(goodsType)
    for goodsId, endTime in pairs(_GoodsDurationData) do
    if rechargeConfig[goodsId].Type == goodsType and endTime > GetTimeStamp() then
            return goodsId, endTime
        end
    end
end
function this.GetGoodsEndTime(goodsType)
    local goodsId, endTime = this.GetActiveGoodsIDByType(goodsType)
    return endTime
end
function this.RemoveEndTime(goodsId)
    _GoodsDurationData[goodsId] = nil
end
function this.SetGoodsEndTime(goodsId, endTime)
    _GoodsDurationData[goodsId] = endTime
end

-- 直购活动是否还在
function this.IsGoodsExit(type, id)
    local isOpen = false
    local data = this.GetGiftGoodsInfo(type, id)
    if data then
        -- 有数据，但是活动结束
        local time = data.endTime - PlayerManager.serverTime
        isOpen = time > 0
    else
        isOpen = false
    end

    return isOpen
end


-- 五星成长礼红点
function this.GetRedState()
    local isRed = false
    local redValue = PlayerPrefs.GetInt(PlayerManager.uid .. "BlaBlaBla")
    local openState = this.IsGoodsExit(GoodsTypeDef.DirectPurchaseGift, 21)
    if openState and redValue == 0 then
        isRed = true
    else
        isRed = false
    end

    return isRed
end


---------------------------------------累计签到--------------------------------
local _SignInData
function this.SetSignInData(signIn)
    _SignInData = signIn
    CheckRedPointStatus(RedPointType.CumulativeSignIn)
end

function this.GetSignInData()
    return _SignInData
end

--红点检测方法
function this.GetSignInRedPointStatus()
    if not _SignInData then
        return false
    end
    local receiveNum = PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.DAY_SIGN_IN)--本地标记可领取次数
    local rechargeNum = PrivilegeManager.GetPrivilegeNumber(PRIVILEGE_TYPE.DAY_SIGN_IN)--充值标记 1未充值 2已充值
    return _SignInData.state == 0 or receiveNum > 0--(_SignInData.state==1 and ((receiveNum==0 and rechargeNum==1) or (receiveNum==1 and rechargeNum==2)))
end

----------------------------------  什么什么什么新鸡成长礼包 ------------------------------------------
--- 新增一个礼包
function this.NewHeroGift()
    this.SetHeroRedState(1)
    CheckRedPointStatus(RedPointType.HERO_STAR_GIFT)
end


--- 获取那个的显示数据
function this.GetStarGiftData()
    local data = {}
    for k, v in ConfigPairs(rechargeConfig) do
        if v.ShowType == 8 then 
            local t = {}
            t.data = v   -- 数据结构
            t.Id = v.Id   -- 商品ID
            data[#data + 1] = t
        end 
    end
    return data
end

function this.IsHeroGiftActive()
    -- 关闭星级成长礼显示
    if not giftGoodsInfoList[GoodsTypeDef.DirectPurchaseGift] then
        return false
    end
    -- local activeNum = 0
    -- if not giftGoodsInfoList[GoodsTypeDef.DirectPurchaseGift] then
    --     return false 
    -- else
    --    for i = 1, #giftGoodsInfoList[GoodsTypeDef.DirectPurchaseGift] do
    --         local data =giftGoodsInfoList[GoodsTypeDef.DirectPurchaseGift][i]
    --         if data then 
    --             local id = data.goodsId
    --             if rechargeConfig[id].ShowType == 8 then --- 只有前端显示的商品类型
    --                 activeNum = activeNum + 1
    --             end
    --         end
    --    end
    -- end
    
    -- return activeNum > 0
end

--- 获取礼包的显示数据
function this.GetGiftShowData()
    local staticData = this.GetStarGiftData()
    local newData = {}
    for i = 1, #staticData do
        local goodsId = staticData[i].Id
        local data = {}
        data.rewardData = staticData[i].data.RewardShow
        data.price = staticData[i].data.Price
        data.id = goodsId
        data.name = staticData[i].data.Name
        local serData = this.GetGiftGoodsInfo(GoodsTypeDef.DirectPurchaseGift, goodsId)
        if serData and serData.endTime > 0 then   --- 商品激活可购买
            data.endTime = serData.endTime
            data.startTime = serData.startTime 
            data.leftBuyTime = serData.dynamicBuyTimes
            data.isActive = 1
        else  --- 未激活只是显示而已
            data.endTime = 0
            data.startTime = 0
            data.leftBuyTime = 0
            data.isActive = 0
        end
        newData[#newData + 1] = data
    end

    ---排序
    if #newData > 1 then 
        table.sort(newData, function(a, b)
            if a.isActive == b.isActive then 
                return a.id > b.id 
            else
                return a.isActive > b.isActive
            end
        end)
    end

    return newData 
end

--- 礼包红点
function this.IsHeroStarGiftActive()
    local clickedState = this.GetHeroRedState()
    local isActive = this.IsHeroGiftActive()
    local hasRed = clickedState == 1 and isActive
    return hasRed
end 

function this.SetHeroRedState(value)
    PlayerPrefs.SetInt(PlayerManager.uid .. "hero_star_gift", value)
end

function this.GetHeroRedState()
    return PlayerPrefs.GetInt(PlayerManager.uid .. "hero_star_gift")
end
----------------------------------------------------------------------------------------------

--- 获取镇魔计划面版的显示信息
--- 传进来的参数值是 33或者是34基金类型
function this.GetPanelShowReward(type, isAll, isOverlay)
    local data = {}
    for k, v in ConfigPairs(luxuryConfig) do
        if not isAll then 
            if v.Type == type and v.ShowReward == 1 then 
                data[#data + 1] = v
            end
        else
            if v.Type == type then 
                data[#data + 1] = v
            end
        end
    end
    if isOverlay then
        local endData = {}
        for i = 1, #data do
            if endData[data[i].reward[1][1]] then
                endData[data[i].reward[1][1]] = endData[data[i].reward[1][1]] + data[i].reward[1][2]
            else
                endData[data[i].reward[1][1]] = data[i].reward[1][2]
            end
        end
        local endData2 = {}
        for i, v in pairs(endData) do
            table.insert(endData2,{i,v})
        end
        return endData2
    else
        return data
    end
end

--修改为显示表里的ShowReward == 1的数据 不叠加
function this.GetPanelShowReward2(type)
    local data = {}
    for i, v in ConfigPairs(luxuryConfig) do
        if v.Type == type and v.ShowReward == 1 then 
            data[#data + 1] = v
        end
    end
    return data
end

--- 某一个基金活动是否开启
function this.IsBaseOpen(type, id)
    local isOpen = false
    local data = this.GetGiftGoodsInfo(type, id)
    if data then
        --- 常驻
        if tonumber(data.endTime) == 0 then
            isOpen = true
        else
            local time = data.endTime - PlayerManager.serverTime
            local isBuy = this.IsBaseBuy(type)

            isOpen = time > 0

            -- 如果购买了结束也没有用
            if isBuy then
                isOpen = true
            end
        end
    else
        isOpen = false
        -- 如果购买了结束也没有用
        if this.IsBaseBuy(type) then
            isOpen = true
        end
    end

    return isOpen
end 

--- 判断某一个基金是否购买
function this.IsBaseBuy(type)
    local leftTime = this.GetGoodsEndTime(type)
    local isBuy = false
    if not leftTime then
        isBuy = false
    else
        if leftTime <= 0 then 
            isBuy = false
        else
            isBuy = true
        end
    end
    return isBuy
end

---- 界面打开时设置一下服务器数据
function this.SetSerData(goodsType)
    local endTime = this.GetGoodsEndTime(goodsType)
    if not endTime then return end 

    local startTime = endTime - 24 * 30 * 60 * 60
    local passSecond = GetTimeStamp() - startTime

    this.SetSignRewarDay(goodsType, passSecond)
end

local getDay = {}
local oneDaySeconds = 24 * 60 * 60

-- 累计领取天数
function this.GetRewardDay(goodType)
    -- 未激活时没有天数
    if not this.IsBaseBuy(goodType)  then return 0 end 
    return getDay[goodType]
end

--- 设置累计天数
function this.SetSignRewarDay(goodType, second)
    if not getDay[goodType] then getDay[goodType] = {} end 
    -- 小于24小时按一天
    if second <= oneDaySeconds * 1 then 
        getDay[goodType] = 1
    elseif second >= oneDaySeconds * 30 then 
        getDay[goodType] = 30 
    else    
        local hour = math.ceil(math.ceil(second / 60) / 60)
        getDay[goodType] = math.ceil(hour / 24)

        getDay[goodType] =  getDay[goodType] >= 30 and 30 or getDay[goodType]
    end
end

-- 显示数据
function this.GetShowTime(endTime)
    local duration = 30 * 24 * 60 * 60
    local endStr = os.date(GetLanguageStrById(11484), endTime)
    local startStr = os.date(GetLanguageStrById(11484), endTime - duration + 1)
    return startStr, endStr
end

--月卡开始
--初始化月卡数据
local monthSaveAmt = 0--月卡累计总额
local smonthSaveAmt = 0--豪华月卡累计总额
local monthCardData = {}
function this.InitMonthCardData(data)
    monthCardData = {}
    
    for i = 1, #data do
        local singleMonthCard = {}
        singleMonthCard.id = data[i].id
        singleMonthCard.endingTime = data[i].endingTime
        singleMonthCard.state = data[i].state
        if i == MONTH_CARD_TYPE.MONTHCARD then
            monthSaveAmt = data[i].totleAmt
        elseif i == MONTH_CARD_TYPE.LUXURYMONTHCARD then
            smonthSaveAmt = data[i].totleAmt
        end
        table.insert(monthCardData,singleMonthCard)
    end
    CheckRedPointStatus(RedPointType.NobilityMonthCard)
    CheckRedPointStatus(RedPointType.KingMonthCard)
end
--推送更新月卡数据
function this.UpdateMonthCardData(msg)
    --当我数据没有  后端推过来的有数据 此时需要弹窗
    local showStr = ""
    for i = 1, #msg.monthinfos do
        if  monthCardData[i].endingTime <= 0 then
            showStr = GetLanguageStrById(11485)
        end
    end
    monthCardData = {}
    for i = 1, #msg.monthinfos do
        local singleMonthCard = {}
        singleMonthCard.id = msg.monthinfos[i].id
        singleMonthCard.endingTime = msg.monthinfos[i].endingTime
        singleMonthCard.state = msg.monthinfos[i].state--0 未领取 1 已领取
        if i == MONTH_CARD_TYPE.MONTHCARD then
            monthSaveAmt = msg.monthinfos[i].totleAmt
        elseif i == MONTH_CARD_TYPE.LUXURYMONTHCARD then
            smonthSaveAmt = msg.monthinfos[i].totleAmt
        end
        table.insert(monthCardData,singleMonthCard)
    end
    CheckRedPointStatus(RedPointType.NobilityMonthCard)
    CheckRedPointStatus(RedPointType.KingMonthCard)
    if showStr ~= "" then
        if ActTimeCtrlManager.SingleFuncState(JumpType.Welfare) then
            MsgPanel.ShowTwo(showStr, function()
                if UIManager.IsOpen(UIName.RewardItemPopup) then
                    UIManager.ClosePanel(UIName.RewardItemPopup)
                end
                JumpManager.GoJump(36004)
            end,
            function()
                UIManager.ClosePanel()
            end,GetLanguageStrById(10549),GetLanguageStrById(11486))
        end
    end
end
function this.RefreshMonthCardChargeMoney(msg)
    monthSaveAmt = msg.monthSaveAmt--月卡累计总额
    smonthSaveAmt = msg.smonthSaveAmt--豪华月卡累计总额
end
-- 月卡累计总额
function this.GetmonthSaveAmt()
    return monthSaveAmt
end
-- 豪华月卡累计总额
function this.GetsmonthSaveAmt()
    return smonthSaveAmt
end
--前端设置月卡领取状态数据
function this.SetMonthCardGetStateData(type,state)
    if monthCardData[type] then
        monthCardData[type].state = state--0 未领取 1 已领取
    end
    CheckRedPointStatus(RedPointType.NobilityMonthCard)
    CheckRedPointStatus(RedPointType.KingMonthCard)
end


--后端设置月卡领取状态数据   datas已领取的月卡id  五点刷新
function this.BackSetMonthCardGetStateData(datas)
    for i = 1, #monthCardData do
        if monthCardData[i] then--0 未领取 1 已领取
            if datas[i] then
                monthCardData[i].state = 1
            else
                monthCardData[i].state = 0
            end
        end
    end
    --事件
    CheckRedPointStatus(RedPointType.NobilityMonthCard)
    CheckRedPointStatus(RedPointType.KingMonthCard)
    Game.GlobalEvent:DispatchEvent(GameEvent.MonthCard.OnMonthCardUpdate)
end
--获取月卡数据
function this.GetMonthCardData()
    if monthCardData then
        return monthCardData
    else
        return nil
    end
end
function this.IsMonthCardActive()
    local curAllMonthCardData = this.GetMonthCardData()
    local curMonthCardOpenState = curAllMonthCardData[MONTH_CARD_TYPE.MONTHCARD] and curAllMonthCardData[MONTH_CARD_TYPE.MONTHCARD].endingTime ~= 0
    local curLuxuryMonthCardOpenState = curAllMonthCardData[MONTH_CARD_TYPE.LUXURYMONTHCARD] and curAllMonthCardData[MONTH_CARD_TYPE.LUXURYMONTHCARD].endingTime ~= 0
    local isMonthCardActive = curLuxuryMonthCardOpenState
    return isMonthCardActive
end
--月卡到期
local addTimeNum = 30 * 24 * 60 * 60
function this.RefreshMonthCardEnd()
    for i = 1, #monthCardData do
        if monthCardData[i] and monthCardData[i].endingTime > 0 then--0 未领取 1 已领取
            local dayLuxuryNum = this.EndTimejudgment(i) - GetTimeStamp()
            if dayLuxuryNum < 0 then
                monthCardData[i].endingTime = 0
                monthCardData[i].state = 0--0 未领取 1 已领取
                if i == MONTH_CARD_TYPE.MONTHCARD then
                    monthSaveAmt = 0--月卡累计总额
                else
                    smonthSaveAmt = 0--豪华月卡累计总额
                end
            end
        end
    end
    CheckRedPointStatus(RedPointType.NobilityMonthCard)
    CheckRedPointStatus(RedPointType.KingMonthCard)
end

--月卡结束时间判断
function this.EndTimejudgment(type)
    local curAllMonthCardData = this.GetMonthCardData()
    if curAllMonthCardData==nil or curAllMonthCardData[type].endingTime==0 then
        return -1
    end
    local allTotalTime=curAllMonthCardData[type].endingTime+(addTimeNum)
    local Totaltime = os.date("%H.%M.%S",allTotalTime)
    local TotalsplitTime=string.split(Totaltime,".")

    local hour=tonumber(TotalsplitTime[1])*60*60
    local Points=tonumber(TotalsplitTime[2])*60
    local second=tonumber(TotalsplitTime[3])
    local hsecond=hour+Points+second
    local MonthCardEndTime=allTotalTime-hsecond

    return MonthCardEndTime
end





--单种月卡红点检测
function this.RefreshMonthCardRedPoint(type)
    if monthCardData[type] then
        if monthCardData[type].endingTime ~= 0 and monthCardData[type].state == 0 then
            return true
        end
    end
    return false
end
function this.RefreshMONTHCARDMonthCardRedPoint()
    return this.RefreshMonthCardRedPoint(MONTH_CARD_TYPE.MONTHCARD)
end
function this.RefreshLUXURYMONTHCARDMonthCardRedPoint()
    return this.RefreshMonthCardRedPoint(MONTH_CARD_TYPE.LUXURYMONTHCARD)
end
--所有月卡红点检测
function this.AllRefreshMonthCardRedPoint()
    for i = 1, #monthCardData do
        if monthCardData[i].endingTime ~= 0 and monthCardData[i].state == 0 then
            return true
        end
    end
    return false
end
--所有月卡激活状态
function this.GetMonthCardIsOpen(type)
    if monthCardData[type] then
        if monthCardData[type].endingTime ~= 0 then
            return true
        end
    end
    return false
end

--礼包抢购是否开启
function this.IsGiftBuyActive()
    local config = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity, "Id", 10007)
    if PlayerManager.level < config.OpenRules[2] then
        return false
    end

    local activeNum = 0
    local GiftBuyData = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.RechargeCommodityConfig, "ShowType", 20, "Type", GoodsTypeDef.DirectPurchaseGift)
    if GiftBuyData then
        for i = 1, #GiftBuyData do
            local  curgoodData = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.DirectPurchaseGift, GiftBuyData[i].Id)
            if curgoodData then
                if curgoodData.endTime - GetTimeStamp() > 0 then
                    activeNum = activeNum + 1
                end
            end
        end
    end
    return activeNum > 0
end

--是否有免费的每周礼包
function this.EveryWeekPreferenceRedPoint()
    local shopDatas = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)
    local rechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
    local boughtNum = 0
    local limitNum = 0
    for i = 1, #shopDatas do
        if rechargeCommodityConfig[shopDatas[i].goodsId].ShowType == DirectBuyType.WEEK_GIFT then
            if rechargeCommodityConfig[shopDatas[i].goodsId].Price == 0  then
                boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, shopDatas[i].goodsId)
                limitNum = rechargeCommodityConfig[ shopDatas[i].goodsId].Limit
                if limitNum - boughtNum > 0 then
                    if ActivityGiftManager.IsQualifiled(ActivityTypeDef.WeekGift) then
                        return true
                    else
                        return false
                    end
                else
                    return false
                end
            end
        end
    end
    return false
end

--是否有免费的每月礼包
function this.EveryMonthPreferenceRedPoint()
    local shopDatas = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)
    local rechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
    local boughtNum = 0
    local limitNum = 0
    for i = 1, #shopDatas do
        if rechargeCommodityConfig[shopDatas[i].goodsId].ShowType == DirectBuyType.MONTH_GIFT then
            if rechargeCommodityConfig[shopDatas[i].goodsId].Price == 0  then
                boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, shopDatas[i].goodsId)
                limitNum = rechargeCommodityConfig[ shopDatas[i].goodsId].Limit
                if limitNum - boughtNum > 0 then
                    if ActivityGiftManager.IsQualifiled(ActivityTypeDef.WeekGift) then
                        return true
                    else
                        return false
                    end
                else
                    return false
                end
            end
        end
    end
    return false
end

function this.GetTimeLimitRedPointStatus()
    local activiytId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy) 
    if not activiytId or activiytId <= 0 then
        return false
    end

    local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
    local freeTimesId = lotterySetting[RecruitType.TimeLimitSingle].FreeTimes
    local freeTime = 0
    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        RecruitManager.freeUseTimeList[freeTimesId] = freeTime
        return freeTime and freeTime >= 1
    end
    return false
end 

function this.GetQiankunBoxRedPointStatus()
    local activiytId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.QianKunBox) 
    if not activiytId or activiytId <= 0 then
        return false
    end
    
    local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
    local freeTimesId =lotterySetting[RecruitType.QianKunBoxSingle].FreeTimes
    local freeTime = 0
    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        RecruitManager.freeUseTimeList[freeTimesId]=freeTime
        return freeTime and freeTime >= 1
    end
    return false
end 

this.TimeLimitedTimes = 0
this.allData = {}
function this.InitDynamicActData()
    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.DynamicAct)
    if not id or id < 1 then
        return nil
    end
    this.allData = {}
    local allListData = ConfigManager.GetAllConfigsDataByKey(ConfigName.ThemeActivityTaskConfig, "ActivityId", id)
    local allMissionData = TaskManager.GetTypeTaskList(TaskTypeDef.DynamicActTask)
    for i = 1,#allListData do 
        for j = 1,#allMissionData do 
            if allListData[i].Id == allMissionData[j].missionId  then
                local data = {}
                data.id = allMissionData[j].missionId
                data.progress = allMissionData[j].progress 
                local strs = string.split(GetLanguageStrById(allListData[i].Show),"#")
                data.title = strs[1]
                data.content = strs[2]
                data.value = allListData[i].TaskValue[2][1]
                data.state = allMissionData[j].state
                data.type = allListData[i].Type
                data.reward = {}
                for _, v in ipairs(allListData[i].Integral) do
                    data.reward[_] = {v[1], v[2]}
                end
                if allMissionData[j].state == 2 then
                    data.progress = allListData[i].TaskValue[2][1]
                end
                data.jump = allListData[i].Jump[1]
                table.insert(this.allData,data)
            end
        end
    end
    return this.allData
end
function this.CheckDynamicActTaskRed()
    this.InitDynamicActData()
    if not this.allData then
        return false
    end
    for i = 1,#this.allData do 
        if this.allData[i].state == 1 then
            return true
        end
    end
    return false
end
function this.InitLeiJiChongZhiData(_type)
    local id = 0
    local type = _type
    if type then
        id = ActivityGiftManager.IsActivityTypeOpen(type)
        if (not id) or id == 0 then
            return nil
        end
    else
        id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AccumulativeRechargeExper)
        if (not id) or id == 0 then
            id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.DynamicAct_recharge)
            if (not id) or id == 0 then
                return nil
            else
                type = ActivityTypeDef.DynamicAct_recharge
            end
        else
            type = ActivityTypeDef.AccumulativeRechargeExper
            local tempConfig = ConfigManager.GetConfigData(ConfigName.GlobalActivity,id)
            if tempConfig and tempConfig.ShowArt == 1 then
                return nil
            end       
        end
    end
    
    this.LeiJiChongZhiData = {}
    local allListData = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", id)
    local allMissionData = ActivityGiftManager.GetActivityTypeInfo(type)
    for i = 1,#allListData do 
        for j = 1,#allMissionData.mission do 
            if allListData[i].Id == allMissionData.mission[j].missionId then
                local data = {}
                data.id = allMissionData.mission[j].missionId
                data.progress = allMissionData.value/100
                data.value = allListData[i].Values[1][1]
                data.state = allMissionData.mission[j].state == 1 and allMissionData.mission[j].state or (data.progress>= data.value and 2 or 0)  -- 0 前往   1已领奖     2领奖             
                data.reward = allListData[i].Reward
                if allListData[i].Jump then
                    data.jump = allListData[i].Jump[1]
                end               
                table.insert(this.LeiJiChongZhiData,data)
            end
        end
    end
    return this.LeiJiChongZhiData
end
function this.CheckLeiJiChongZhiRedData()
    local mission = this.InitLeiJiChongZhiData(ActivityTypeDef.DynamicAct_recharge)
    if not mission or #mission < 1 then
        return false
    end
    for j = 1,#mission do 
        if mission[j].state == 2 then
           return true
        end
    end
    return false
end
function this.CheckWeekGiftPageRedPoint()
    local boughtNum = 0
    local limitNum = 0
    local shopData = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)
    for i = 1, #shopData do
        if rechargeConfig[shopData[i].goodsId].ShowType == DirectBuyType.WEEK_GIFT then
            boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, shopData[i].goodsId)
            limitNum = rechargeConfig[shopData[i].goodsId].Limit
            local isCanBuy = limitNum - boughtNum > 0
            if isCanBuy and rechargeConfig[shopData[i].goodsId].Price <= 0 then
                return true
            end 
        end
    end
    return false
end
function this.CheckMonthGiftPageRedPoint()
    local boughtNum = 0
    local limitNum = 0
    local shopData = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)
    for i = 1, #shopData do
        if rechargeConfig[shopData[i].goodsId].ShowType == DirectBuyType.MONTH_GIFT then
            boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, shopData[i].goodsId)
            limitNum = rechargeConfig[shopData[i].goodsId].Limit
            local isCanBuy = limitNum - boughtNum > 0
            if isCanBuy and rechargeConfig[shopData[i].goodsId].Price <= 0 then
                return true
            end     
        end
    end
    return false
end
--超值基金红点检测
local firstOpen = true
function this.CheckSpecialFundsRedPoint()
    local isAllBuy = OperatingManager.IsBaseBuy(GoodsTypeDef.MONTHCARD_128) and OperatingManager.IsBaseBuy(GoodsTypeDef.MONTHCARD_328)
    if isAllBuy then
       return false
    else
        if firstOpen then
            return true
        end
    end
    return false
end

function this.SetSpecialFundsFistOpen()
     firstOpen = false
end

--为限时神装写的(只有一个)
function this.GetTimeLimitSkinInfoList()
    local giftList = {}
    local infoList = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)--拿取所有类型5礼包信息(包含需要的礼包)
    local infoList2 = ConfigManager.GetConfigDataByKey(ConfigName.RechargeCommodityConfig,"ShowType",29)
    for index, value in pairs(infoList) do
        if infoList2.Id == value.goodsId and value.dynamicBuyTimes > 0 then
            return value
        end
    end
    return nil
end
--为限时折扣写的（含有多个）
function this.GetInfoList()
    local giftList = {}
    local infoList = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)--拿取所有类型5礼包信息(包含需要的礼包)
    local infoList2 = ConfigManager.GetAllConfigsDataByKey(ConfigName.RechargeCommodityConfig,"ShowType",21)
    for index, value in pairs(infoList) do
        for i = 1, #infoList2 do
            if infoList2[i].Id == value.goodsId and value.dynamicBuyTimes > 0 then
                table.insert(giftList,value)
            end
        end
    end
    local infoList3 = ConfigManager.GetAllConfigsDataByKey(ConfigName.RechargeCommodityConfig,"ShowType",8)
    for index, value in pairs(infoList) do
        for i = 1, #infoList3 do
            if infoList3[i].Id == value.goodsId and value.dynamicBuyTimes > 0 then
                table.insert(giftList,value)
            end
        end
    end
    local infoList4 = ConfigManager.GetAllConfigsDataByKey(ConfigName.RechargeCommodityConfig,"ShowType",25)
    for index, value in pairs(infoList) do
        for i = 1, #infoList4 do
            if infoList4[i].Id == value.goodsId and value.dynamicBuyTimes > 0 then
                table.insert(giftList,value)
            end
        end
    end
    local infoList5 = ConfigManager.GetAllConfigsDataByKey(ConfigName.RechargeCommodityConfig,"ShowType",26)
    for index, value in pairs(infoList) do
        for i = 1, #infoList5 do
            if infoList5[i].Id == value.goodsId and value.dynamicBuyTimes > 0 then
                table.insert(giftList,value)
            end
        end
    end
    return giftList
end

--刷新拍脸红点
function this.RefreshPatFaceRedpoint()
    if isFistShow then
        isFistShow = false
        return not isFistShow
    end
    return isFistShow
end

--刷新开服双倍红点
function this.RefreshOpenServiceRedpoint()
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.OpenService) then
        return false
    end
    local canBuyRechargeId = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity, "Type", 10020).CanBuyRechargeId
    for i = 1, #canBuyRechargeId do
        local config = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, canBuyRechargeId[i])
        local boughtNum = OperatingManager.GetGoodsBuyTime(config.Type, config.Id) or 0
        if config.Price == 0 then
            local isCanBuy = config.Limit - boughtNum > 0
            return isCanBuy
        end
    end
    return false
end

--获取战令是否开启
function this.GetWarOrderIsOpen()
    local state = false
    for key, value in pairs(WarOrderType) do
        if not not ActivityGiftManager.IsActivityTypeOpen(value) then
            state = true
        end
    end
    return state
end

--战令列表
function this.GetAllWarOrderData(func)
--[[
    encouragePlanClassifies = {
        [1] = {
            globalSystemId = GlobalSystemConfig表ID,
            encouragePlanInfos = {
                [1] = {
                    encouragePlanId = EncouragePlanConfig表ID,
                    encouragePlanTaskInfos = {
                        [1] = {
                            taskConfigId = 任务ID,
                            freeObtained = 免费奖励领取状态 bool,
                            privilegeObtained = 特权奖励领取状态 bool,
                            isCompeted = 任务完成状态 bool,
                        }
                    unlockPrivilege = 是否解锁战令特权 bool
                    progress = 进度
                    cycleEndingTime = 结束时间
                    }
                }
            }
        }
    }
--]]
    this.AllWarOrderData = {}
    NetManager.GetAllEncouragePlanInfoRequest(function (msg)
        this.AllWarOrderData = msg.encouragePlanClassifies
        if func then
            func()
        end
    end)
end

--根据传进来的GlobalSystemId获取战令
function this.GetWarOrderForGlobalSystemId(globalSystemId)
    if this.AllWarOrderData then
        for i = 1, #this.AllWarOrderData do
            if this.AllWarOrderData[i].globalSystemId == globalSystemId then
                for j = 1, #this.AllWarOrderData[i].encouragePlanInfos do
                    if #this.AllWarOrderData[i].encouragePlanInfos[j].encouragePlanTaskInfos > 0 then
                        return this.AllWarOrderData[i]
                    end
                end
            end
        end
    end
    return nil
end

--根据传进来的GlobalSystemId和EncouragePlanConfigId获取具体战令
function this.GetWarOrderForGlobalSystemIdAndId(globalSystemId, id)
    local warOrder = this.GetWarOrderForGlobalSystemId(globalSystemId)
    if warOrder then
        for i = 1, #warOrder.encouragePlanInfos do
            if warOrder.encouragePlanInfos[i].encouragePlanId == id then
                return warOrder.encouragePlanInfos[i]
            end
        end
    end
    return nil
end

--获取战令任务状态
function this.GetWarOrderTaskState(globalSystemId, Id, taskId)
    local warOrder = this.GetWarOrderForGlobalSystemIdAndId(globalSystemId, Id)
    if warOrder then
        for i = 1, #warOrder.encouragePlanTaskInfos do
            if warOrder.encouragePlanTaskInfos[i].taskConfigId == taskId then
                return warOrder.encouragePlanTaskInfos[i]
            end
        end
    end
    return nil
end

--解锁特权前端手动改变状态
function this.ManualChangeWarOrderState(EncouragePlanID)
    for i = 1, #this.AllWarOrderData do
        for j = 1, #this.AllWarOrderData[i].encouragePlanInfos do
            if this.AllWarOrderData[i].encouragePlanInfos[j].encouragePlanId == EncouragePlanID then
                this.AllWarOrderData[i].encouragePlanInfos[j].unlockPrivilege = true
                Game.GlobalEvent:DispatchEvent(GameEvent.WarOrder.UnLock)
            end
        end
    end
end

--领取完前端手动改变状态
function this.ManualChangeTaskState(taskCfgId)
    local EncouragePlan
    for key, value in ipairs(EncourageTaskConfig) do
        if value.Id == taskCfgId then
            EncouragePlan = value.EncouragePlan
        end
    end
    local GlobalSystemId = EncouragePlanConfig[EncouragePlan].GlobalSystemId
    local infos = this.GetWarOrderTaskState(GlobalSystemId, EncouragePlan, taskCfgId)
    local all = this.GetWarOrderForGlobalSystemIdAndId(GlobalSystemId, EncouragePlan)
    if infos.isCompeted then
        if all.unlockPrivilege then
            infos.freeObtained = true
            infos.privilegeObtained = true
        else
            infos.freeObtained = true
        end
    end
end

--领取战令奖励 --任务ID 0：领取免费 1：领取特权 2：领取全部
function this.GetWarOrderReward(taskCfgId, obtainPos, func)
    NetManager.ObtainEncouragePlanRewardRequest(taskCfgId, obtainPos, function (msg)
        UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
            this.ManualChangeTaskState(taskCfgId)
            CheckRedPointStatus(RedPointType.WarOrder_Tower)
            CheckRedPointStatus(RedPointType.WarOrder_MagicTower)
            CheckRedPointStatus(RedPointType.WarOrder_Heresy)
            CheckRedPointStatus(RedPointType.WarOrder_DenseFog)
            CheckRedPointStatus(RedPointType.WarOrder_Abyss)
            if func then
                func()
            end
        end)
    end)
end

--推送战令改变任务状态
function this.ChangeTaskState(msg)
    -- LogError("推送战令改变任务状态")
    local task = this.GetWarOrderForGlobalSystemIdAndId(msg.globalSystemId, msg.planId)
    for i = 1, #task.encouragePlanTaskInfos do
        if task.encouragePlanTaskInfos[i].taskConfigId == msg.taskInfo.taskConfigId then
            task.encouragePlanTaskInfos[i].freeObtained = msg.taskInfo.freeObtained
            task.encouragePlanTaskInfos[i].privilegeObtained = msg.taskInfo.privilegeObtained
            task.encouragePlanTaskInfos[i].isCompeted = msg.taskInfo.isCompeted
            task.encouragePlanTaskInfos[i].cycleEndingTime = msg.taskInfo.cycleEndingTime
        end
    end
    CheckRedPointStatus(RedPointType.WarOrder_Tower)
    CheckRedPointStatus(RedPointType.WarOrder_MagicTower)
    CheckRedPointStatus(RedPointType.WarOrder_Heresy)
    CheckRedPointStatus(RedPointType.WarOrder_DenseFog)
    CheckRedPointStatus(RedPointType.WarOrder_Abyss)
    Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnActivityOpenOrClose)
end

--推送战令解锁
function this.ChangeWarOrderState(msg)
    -- LogError("推送战令解锁")
    local data = this.GetWarOrderForGlobalSystemId(msg.globalSystemId)
    if not data then
        table.insert(this.AllWarOrderData, {
            globalSystemId = msg.globalSystemId,
            encouragePlanInfos = {
                [1] = {
                    encouragePlanId = msg.planId,
                    encouragePlanTaskInfos = msg.encouragePlanTaskInfos,
                    unlockPrivilege = msg.unlockPrivilege,
                    progress = msg.progress,
                    cycleEndingTime = msg.cycleEndingTime
                }
            }
        })
    else
        table.insert(data.encouragePlanInfos, {
            encouragePlanId = msg.planId,
            encouragePlanTaskInfos = msg.encouragePlanTaskInfos,
            unlockPrivilege = msg.unlockPrivilege,
            progress = msg.progress,
            cycleEndingTime = msg.cycleEndingTime
        })
    end
    CheckRedPointStatus(RedPointType.WarOrder_Tower)
    CheckRedPointStatus(RedPointType.WarOrder_MagicTower)
    CheckRedPointStatus(RedPointType.WarOrder_Heresy)
    CheckRedPointStatus(RedPointType.WarOrder_DenseFog)
    CheckRedPointStatus(RedPointType.WarOrder_Abyss)
    -- LogError(#data.encouragePlanInfos)
    Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnActivityOpenOrClose)
end

--推送战令进度
function this.PushWarOrderPropress(msg)
    -- LogError("推送战令进度")
    local data = this.GetWarOrderForGlobalSystemId(msg.globalSystemId)
    if data then
        for i = 1, #data.encouragePlanInfos do
            data.encouragePlanInfos[i].progress = msg.progress
        end
    end
    CheckRedPointStatus(RedPointType.WarOrder_Tower)
    CheckRedPointStatus(RedPointType.WarOrder_MagicTower)
    CheckRedPointStatus(RedPointType.WarOrder_Heresy)
    CheckRedPointStatus(RedPointType.WarOrder_DenseFog)
    CheckRedPointStatus(RedPointType.WarOrder_Abyss)
end

--推送战令重置
function this.PushWarOrderResetting(msg)
    -- LogError("推送战令重置")
    local data = this.GetWarOrderForGlobalSystemIdAndId(msg.globalSystemId, msg.planId)
    if data then
        for i = 1, #msg.encouragePlanTaskInfos do
            data.encouragePlanTaskInfos[i].taskConfigId = msg.encouragePlanTaskInfos[i].taskConfigId
            data.encouragePlanTaskInfos[i].freeObtained = msg.encouragePlanTaskInfos[i].freeObtained
            data.encouragePlanTaskInfos[i].privilegeObtained = msg.encouragePlanTaskInfos[i].privilegeObtained
            data.encouragePlanTaskInfos[i].isCompeted = msg.encouragePlanTaskInfos[i].isCompeted
        end
        data.progress = msg.progress
        data.unlockPrivilege = msg.unlockPrivilege
        data.cycleEndingTime = msg.cycleEndingTime
    end

    if msg.drop then
        UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
        end)
    end
    CardActivityManager.StopTimeDown()
    CheckRedPointStatus(RedPointType.WarOrder_Tower)
    CheckRedPointStatus(RedPointType.WarOrder_MagicTower)
    CheckRedPointStatus(RedPointType.WarOrder_Heresy)
    CheckRedPointStatus(RedPointType.WarOrder_DenseFog)
    CheckRedPointStatus(RedPointType.WarOrder_Abyss)
    Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnActivityOpenOrClose)
end

--战令红点
function this.WarOrderRedPoint(type)
    local allWarOrder = this.GetWarOrderForGlobalSystemId(WarOrderType[type])
    if allWarOrder then
        for i = 1, #allWarOrder.encouragePlanInfos do
            local data = allWarOrder.encouragePlanInfos[i]
            for j = 1, #data.encouragePlanTaskInfos do
                if data.encouragePlanTaskInfos[j].isCompeted then
                    if not data.encouragePlanTaskInfos[j].freeObtained then
                        return true
                    elseif not data.encouragePlanTaskInfos[j].privilegeObtained and data.unlockPrivilege then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function this.WarOrderRedPointForTower()
    return this.WarOrderRedPoint(15)
end
function this.WarOrderRedPointForMagicTower()
    return this.WarOrderRedPoint(16)
end
function this.WarOrderRedPointForHeresy()
    return this.WarOrderRedPoint(17)
end
function this.WarOrderRedPointForDenseFog()
    return this.WarOrderRedPoint(18)
end
function this.WarOrderRedPointForAbyss()
    return this.WarOrderRedPoint(19)
end

function this.WarOrderRedPointForId(type, id)
    local allWarOrder = this.GetWarOrderForGlobalSystemId(WarOrderType[type])
    if allWarOrder then
        for i = 1, #allWarOrder.encouragePlanInfos do
            local data = allWarOrder.encouragePlanInfos[i]
            if allWarOrder.encouragePlanInfos[i].encouragePlanId == id then
                for j = 1, #data.encouragePlanTaskInfos do
                    if data.encouragePlanTaskInfos[j].isCompeted then
                        if not data.encouragePlanTaskInfos[j].freeObtained then
                            return true
                        elseif not data.encouragePlanTaskInfos[j].privilegeObtained and data.unlockPrivilege then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

return this