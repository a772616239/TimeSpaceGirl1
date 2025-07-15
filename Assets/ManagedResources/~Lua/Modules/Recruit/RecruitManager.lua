
RecruitManager = {}
local this = RecruitManager
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local lotteryRewardConfig = ConfigManager.GetConfig(ConfigName.LotteryRewardConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local dailyRewardConfig = ConfigManager.GetConfig(ConfigName.DialRewardConfig)

--活动抽卡类型（动态的数据）
local drawtType = {
    FindFairySingle = 0,
    FindFairyTen = 0
}
this.freeUseTimeList = {} --免费抽卡容器
this.isDraw = false--是否抽卡

function this.Initialize()
    this.randCount = 0  --英雄抽卡已招募次数
    this.isCanOpenBox = false
    this.boxReward = {}
    this.recruitFreeUseTime = 0 --现在只剩下秘盒招募在用了
    this.isTenRecruit = 0 --首次十连

    this.isFirstEnterElementScroll = true
    this.isFirstEnterHeroScroll = true
    this.InitPreData()
end
--请求抽卡 1抽卡类型 2回调 3特权id
function this.RecruitRequest(recruitType, func, privilegeId)
    NetManager.RecruitRequest(recruitType, function(msg)
        CheckRedPointStatus(RedPointType.Recruit_Red)
        CheckRedPointStatus(RedPointType.Recruit_Normal)
        CheckRedPointStatus(RedPointType.RecruitTen_Red)
        CheckRedPointStatus(RedPointType.RecruitTen_Normal)
        CheckRedPointStatus(RedPointType.TimeLimited)
        CheckRedPointStatus(RedPointType.QianKunBox)
        if func then
            func(msg)
        end
    end)
end

--5点刷新数据
function this.RefreshFreeTime()
    this.freeUseTimeList[38] = PrivilegeManager.GetPrivilegeRemainValue(38)
    this.freeUseTimeList[14] = PrivilegeManager.GetPrivilegeRemainValue(14)
    this.freeUseTimeList[32] = PrivilegeManager.GetPrivilegeRemainValue(32)
    this.freeUseTimeList[99] = PrivilegeManager.GetPrivilegeRemainValue(99)
    
    if ActTimeCtrlManager.SingleFuncState(1) then
        CheckRedPointStatus(RedPointType.Recruit_Red)
        CheckRedPointStatus(RedPointType.Recruit_Normal)
        CheckRedPointStatus(RedPointType.RecruitTen_Red)
        CheckRedPointStatus(RedPointType.RecruitTen_Normal)
        CheckRedPointStatus(RedPointType.TimeLimited)
        CheckRedPointStatus(RedPointType.QianKunBox)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Recruit.OnRecruitRefreshData)
end

--刷新招募红点
function this.CheckRecuritRedPoint()
    if PrivilegeManager.GetPrivilegeRemainValue(14) >= 1 then--this.freeUseTimeList[14])
        return true
    else
        return false
    end
end
--刷新十连招募红点
function this.CheckRecuritTenRedPoint()
    if BagManager.GetItemCountById(19) >= 10 then--this.freeUseTimeList[14])
        return true
    else
        return false
    end
end

--刷新普通招募红点
function this.CheckRecuritNormalPoint()
    if PrivilegeManager.GetPrivilegeRemainValue(38) >= 1 then--this.freeUseTimeList[38]
        return true
    else
        return false
    end
end
--刷新普通十连招募红点
function this.CheckRecuritTenNormalPoint()
    if BagManager.GetItemCountById(91) >= 10 then--this.freeUseTimeList[38]
        return true
    else
        return false
    end
end

--刷新限时招募红点
-- function this.CheckRecuritNormalPoint()
--     if (this.freeUseTimeList[32] >= 1) then
--         return true
--     else
--         return false
--     end
-- end

function this.InitPreData()
    this.previewHeroData = {}
    this.previewFriendData = {}
    this.previewNormalData = {}
    this.previewElementData = {}
    this.previewLuckData = {} --- 幸运探宝
    this.previewGhostFindData = {}
    this.previewTimeLimitedData = {}--限时招募
    this.previewTimeLimitedUPData = {}
    this.previewLotterySoulData = {}--乾坤宝囊其他奖励
    this.previewLotterySoulUPData = {}--乾坤宝囊魂印up保底
    this.previewCardActivityData = {}
    if #this.previewHeroData >= 1 then
        return
    end

    -- 根据当前期获取卡池信息
    local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    local data = nil
    if curActivityId ~= nil then --活动招募
        data = ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"ActivityId",curActivityId,"LotteryType",3)
    end

    local activityId_1 = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)  --限时补给
    local activityId_2 = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.QianKunBox)  --点唱机

    local function GetPoolIds(activityId)
        local lotteryConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting, "ActivityId", activityId) --< 一般是俩 单抽十连俩组
        local normalGroupIds = {}
        local lotterySpecialTypeId = lotteryConfig[1].MergePool
        for i = 1, #lotteryConfig do
            local groupId = lotteryConfig[i].DiamondBoxContain[1][1]
            normalGroupIds[groupId] = groupId  -- 去重存
        end
        local lotterySpecialConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySpecialConfig, "Type", lotterySpecialTypeId)
        local upGroupIds = {}
        for i = 1, #lotterySpecialConfig do
            if lotterySpecialConfig[i].IsNeedShow == 1 then
                local groupId = lotterySpecialConfig[i].pool_id
                upGroupIds[groupId] = groupId  -- 去重存
            end
        end
        return normalGroupIds, upGroupIds
    end
    local activity1_normal, activity1_up = {}, {}
    local activity2_normal, activity2_up = {}, {}
    if activityId_1 then
        activity1_normal, activity1_up = GetPoolIds(activityId_1)
    end
    if activityId_2 then
        activity2_normal, activity2_up = GetPoolIds(activityId_2)
    end

    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Draw)
    local cardActivityId
    if activityId then
        cardActivityId = ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting, "ActivityId", activityId, "PerCount", 1).Id
    end

    -- ActivityGiftManager.mission[ActivityTypeDef.FindFairy]

    for i, v in ConfigPairs(lotteryRewardConfig) do
        if v.Pool == 1 then--钻石招募
            table.insert(this.previewHeroData, v)
        end

        if v.Pool == 2 then--友情
            table.insert(this.previewFriendData,v)
        end

        if v.Pool == 3 then --普抽
            table.insert(this.previewNormalData,v)
        end

        if v.Pool == 11 or v.Pool == 12 or v.Pool == 13 or v.Pool == 14 then-- or v.Pool == 15 光暗被移除
            table.insert(this.previewElementData, v)
        end

        if cardActivityId and v.Pool == cardActivityId then
            table.insert(this.previewCardActivityData, v)
        end

        local isSetIn1_n = false
        for k1, v1 in pairs(activity1_normal) do
            if v.Pool == v1 then
                isSetIn1_n = true
            end
        end
        if isSetIn1_n then--限时招募
            table.insert(this.previewTimeLimitedData, v)
        end

        local isSetIn1_up = false
        for k1, v1 in pairs(activity1_up) do
            if v.Pool == v1 then
                isSetIn1_up = true
            end
        end
        if isSetIn1_up then--限时招募up英雄
            table.insert(this.previewTimeLimitedUPData, v)
        end

        local isSetIn2_n = false
        for k1, v1 in pairs(activity2_normal) do
            if v.Pool == v1 then
                isSetIn2_n = true
            end
        end
        if isSetIn2_n then--乾坤宝囊其他奖励
            table.insert(this.previewLotterySoulData, v)
        end

        local isSetIn2_up = false
        for k1, v1 in pairs(activity2_up) do
            if v.Pool == v1 then
                isSetIn2_up = true
            end
        end
        if isSetIn2_up then--乾坤宝囊魂印up保底
            table.insert(this.previewLotterySoulUPData, v)
        end

        if data ~= nil then
            if v.Pool == data.DiamondBoxContain[1][1] then
                table.insert(this.previewGhostFindData, v)
            end
        end
    end

    for key, value in ConfigPairs(dailyRewardConfig) do
        table.insert( this.previewLuckData, value)
    end
    if #this.previewLuckData > 1 then 
        table.sort(this.previewLuckData, function(a, b)
            if itemConfig[a.Reward[1]].Quantity == itemConfig[b.Reward[1]].Quantity then 
                return a.Reward[1] > b.Reward[1]
            else
                return itemConfig[a.Reward[1]].Quantity > itemConfig[b.Reward[1]].Quantity
            end
        end)
    end

    table.sort(this.previewHeroData, function(a, b)
        if itemConfig[a.Reward[1]].HeroStar[2] == itemConfig[b.Reward[1]].HeroStar[2] then
            if a.Quality == b.Quality then
                return a.Id < b.Id
            else
                return a.Quality > b.Quality
            end
        else
            return itemConfig[a.Reward[1]].HeroStar[2]>itemConfig[b.Reward[1]].HeroStar[2]
        end
    end)

    --友情
    table.sort(this.previewFriendData, function(a, b)
        if itemConfig[a.Reward[1]].HeroStar[2] == itemConfig[b.Reward[1]].HeroStar[2] then
            if a.Quality == b.Quality then
                return a.Id < b.Id
            else
                return a.Quality > b.Quality
            end
        else
            return itemConfig[a.Reward[1]].HeroStar[2]>itemConfig[b.Reward[1]].HeroStar[2]
        end
    end)

    --普抽
    table.sort(this.previewNormalData, function(a, b)
        if itemConfig[a.Reward[1]].HeroStar[2] == itemConfig[b.Reward[1]].HeroStar[2] then
            if a.Quality == b.Quality then
                return a.Id < b.Id
            else
                return a.Quality > b.Quality
            end
        else
            return itemConfig[a.Reward[1]].HeroStar[2]>itemConfig[b.Reward[1]].HeroStar[2]
        end
    end)

    --元素
    table.sort(this.previewElementData, function(a, b)
        if (itemConfig[a.Reward[1]].Quantity == itemConfig[b.Reward[1]].Quantity) then
            if (a.Quality == b.Quality) then
                return a.Id > b.Id
            else
                return a.Quality > b.Quality
            end
        else
            return itemConfig[a.Reward[1]].Quantity > itemConfig[b.Reward[1]].Quantity
        end
    end)

    -- 东海找鬼
    table.sort(this.previewGhostFindData, function(a, b)
        if itemConfig[a.Reward[1]].Quantity == itemConfig[b.Reward[1]].Quantity then 
            return a.Weight > b.Weight
        else
            return itemConfig[a.Reward[1]].Quantity > itemConfig[b.Reward[1]].Quantity
        end
    end)

    -- 限时招募
    table.sort(this.previewTimeLimitedData, function(a, b)
        if itemConfig[a.Reward[1]].Quantity == itemConfig[b.Reward[1]].Quantity then 
            return a.Weight > b.Weight
        else
            return itemConfig[a.Reward[1]].Quantity > itemConfig[b.Reward[1]].Quantity
        end
    end)

    --乾坤宝囊其他奖励
    table.sort(this.previewLotterySoulData, function(a, b)
        if itemConfig[a.Reward[1]].Quantity == itemConfig[b.Reward[1]].Quantity then 
            return a.Weight > b.Weight
        else
            return itemConfig[a.Reward[1]].Quantity > itemConfig[b.Reward[1]].Quantity
        end
    end)

    --乾坤宝囊魂印Up保底
    table.sort(this.previewLotterySoulUPData, function(a, b)
        if itemConfig[a.Reward[1]].Quantity == itemConfig[b.Reward[1]].Quantity then 
            return a.Weight > b.Weight
        else
            return itemConfig[a.Reward[1]].Quantity > itemConfig[b.Reward[1]].Quantity
        end
    end)

    table.sort(this.previewCardActivityData, function(a, b)
        if itemConfig[a.Reward[1]].Quantity == itemConfig[b.Reward[1]].Quantity then 
            return a.Weight > b.Weight
        else
            return itemConfig[a.Reward[1]].Quantity > itemConfig[b.Reward[1]].Quantity
        end
    end)
end

--获取抽卡奖励预览数据
function this.GetRewardPreviewData(type)
    if type == PRE_REWARD_POOL_TYPE.RECRUIT then
        return this.previewHeroData
    elseif type == PRE_REWARD_POOL_TYPE.ELEMENT_RECRUIT then
        return this.previewElementData
    elseif type == PRE_REWARD_POOL_TYPE.LUCK_FIND then
        return this.previewLuckData
    elseif type == PRE_REWARD_POOL_TYPE.GHOST_FIND then
        return this.previewGhostFindData
    elseif type == PRE_REWARD_POOL_TYPE.FRIEND then
        return this.previewFriendData
    elseif type == PRE_REWARD_POOL_TYPE.NORMAL then
        return this.previewNormalData
    elseif type == PRE_REWARD_POOL_TYPE.TIME_LIMITED then
        return this.previewTimeLimitedData
    elseif type == PRE_REWARD_POOL_TYPE.TIME_LIMITED_UP then
        return this.previewTimeLimitedUPData
    elseif type == PRE_REWARD_POOL_TYPE.LOTTERY_SOUL then--乾坤宝囊其他奖励
        return this.previewLotterySoulData
    elseif type == PRE_REWARD_POOL_TYPE.LOTTERY_SOUL_UP then--乾坤宝囊魂印Up保底
        return this.previewLotterySoulUPData
    elseif type == PRE_REWARD_POOL_TYPE.CARDACTIVITY then
        return this.previewCardActivityData
    end
end

--获取英雄星级数据的最大长度(动态) type 数据类型 star 星级
function this.GetHeroMaxLengthByStar_Dynamic(type,star)
    local d = {}
    for i, v in ipairs(this.GetRewardPreviewData(type)) do
        if itemConfig[v.Reward[1]].HeroStar[2] == star then
            table.insert(d,v)
        end
    end
    return #d
end

--获取抽卡消耗数据
--根据数据长度遍历;若前者不足 返回后者数据;若都不足 返回最后那组数据;若前者足 显示前者
function this.GetExpendData(type)
    local d
    local k = 0
    for i, v in ipairs(lotterySetting[type].CostItem) do
        if BagManager.GetItemCountById(v[1]) >= v[2] then
             d = v
            break
        else
            k = k + 1
        end
    end
    local l = #lotterySetting[type].CostItem
    if k == l then
        return lotterySetting[type].CostItem[l], lotterySetting[type].CostItem[1][1]
    end
    return d, lotterySetting[type].CostItem[1][1]
end

--对一组英雄数组进行随机排序
function this.RandomHerosSort(heros)
    local temps = {}
    for i = 1, #heros do 
        table.insert(temps,heros[i])
    end

    if #temps > 1 then
        local tempHeros = {}
        local tempIndex = 1
        while #temps ~= 0 do
            local tempRandomIndex = math.random(0,#temps)
            if temps[tempRandomIndex] ~= nil then
                tempHeros[tempIndex] = temps[tempRandomIndex]
                table.remove(temps,tempRandomIndex)
                tempIndex = tempIndex + 1
            end
        end
        temps = tempHeros
    end
    return temps
end

-----------------------------千抽相关-----------------------------
this.thousandDrawRound = 0--千抽轮数
this.limitLevel = 0--领取限制等级
this.thousandDrawCards = {}--千抽卡组
--初始化千抽
function this.InitThousandDraw(func)
    NetManager.ThousandDrawInfo(function (msg)
        this.thousandDrawRound = msg.round
        this.limitLevel = ConfigManager.GetConfigDataByKey(ConfigName.ThousandDrawConfig, "Round", this.thousandDrawRound).LvRequire
        this.ThousandDrawCards(3)
        this.thousandDrawCards = msg.thousandDrawCards
        CheckRedPointStatus(RedPointType.ThousandDraw)

        if func then
            func()
        end
    end)
end

this.thousandDrawRandomCards = {}--存储千抽随机后的数据
--1存 2取 3清空
function this.ThousandDrawCards(index, data, number)
    if index == 1 then
        local randCards = this.RandomHerosSort(data.cards)
        table.insert(this.thousandDrawRandomCards, {number = data.number, cards = randCards})
    elseif index == 2 then
        for i = 1, #this.thousandDrawRandomCards do
            if this.thousandDrawRandomCards[i].number == number then
                return this.thousandDrawRandomCards[i].cards
            end
        end
    elseif index == 3 then
        this.thousandDrawRandomCards = {}
    end
end

--抽卡后存入卡组
function this.SaveThousandDrawCards(cards)
    table.insert(this.thousandDrawCards, cards)
end

--千抽红点
function this.RefreshThousandDrawRedPoint()
    if ActTimeCtrlManager.SingleFuncState(1500) then
        if this.thousandDrawRound == 0 then
            this.InitThousandDraw(function ()
                return (#this.thousandDrawCards == 3 and PlayerManager.level >= this.limitLevel) or #this.thousandDrawCards < 3
            end)
        else
            return (#this.thousandDrawCards == 3 and PlayerManager.level >= this.limitLevel) or #this.thousandDrawCards < 3
        end
    else
        return false
    end
end

return this