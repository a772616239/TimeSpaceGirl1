DynamicActivityManager = {}
local this = DynamicActivityManager
this.ZhenQiBaoGeIndex = 0

local SpiritAnimalSummonConfig = ConfigManager.GetConfig(ConfigName.SpiritAnimalSummon)
local shopItemConfig = ConfigManager.GetConfig(ConfigName.StoreConfig)
local rechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
local actRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local GlobalActivity = ConfigManager.GetConfig(ConfigName.GlobalActivity)
this.curLevel = 0--社稷大典的等级
this.curActivityType = 0
this.OpenUIList = {}
this.selectIndex = {dataType = 0,goodsId = {}}

function this.SetSelectIndex(dataType,goodsId)
    this.selectIndex.dataType = dataType
    this.selectIndex.goodsId = goodsId
end

function this.Initialize()
end

function this.AddUIList(jumpId)
    table.insert(this.OpenUIList,jumpId) 
    for i,v in ipairs(this.OpenUIList) do
        
    end
end
function this.RemoveUIList()
    if #this.OpenUIList > 0 then
        table.remove(this.OpenUIList,#this.OpenUIList) 
    end
    for i,v in ipairs(this.OpenUIList) do
        
    end
end
function this.ChangeUIList(jumpId)
    this.OpenUIList[#this.OpenUIList] = jumpId
    for i,v in ipairs(this.OpenUIList) do
        
    end
end

function this.SheJiGetRankData(type,activityId,fun)
    -- local allRankData,myRankData
    -- RankingManager.InitData(type,function ()
    --     allRankData,myRankData =  RankingManager.GetRankingInfo()
    --     if fun then
    --         fun(allRankData,myRankData)
    --     end
    -- end,activityId)

    RankingManager.GetRankingInfo(type, function(allRankData, myRankData)
        if fun then
            fun(allRankData,myRankData)
        end
    end, activityId)
end

function this.SetCurLevel(level)--社稷大典的等级
    this.curLevel = level
end

function this.SheJiCheckRedPoint()
    local ActInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.Celebration)--活动数据
    local canGetRewardList={}
    if ActInfo then
        local curScore = ActInfo.mission[1].progress
        local actReward = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",ActInfo.activityId)
        local setting = ConfigManager.GetConfigDataByKey(ConfigName.GodSacrificeSetting,"ActivityId",ActInfo.activityId)
        --检测宝箱是否有可领取
        for i = 1, #ActInfo.mission do
            local curLevel = curScore/actReward[1].Values[2][1]
            if ActInfo.mission[i].state == 0 and curLevel >= i then
                table.insert(canGetRewardList,ActInfo.mission[i])
            end
        end
    
        local canGet = false
        --检测中央大锅是否可领取
        if GetTimeStamp() > ActInfo.value and GetTimeStamp() < (ActInfo.value + setting.LastTime * 60) then
            --领过--进入倒计时
            canGet = false
        elseif GetTimeStamp() > ActInfo.value and GetTimeStamp() > (ActInfo.value + setting.LastTime * 60) then
            --没到时间--进入倒计时
            canGet = false
        else
            --可领取
            canGet = true
        end
        if #canGetRewardList > 0  or canGet then
            return true
        else
            return false
        end
    end
end

function this.GetBaoKuData()

    local actData={}--全部数据
    local initCardDatas = {}--35个矿坑的初始数据
    local finalCardDatas = {}--35个矿坑抽取后的数据
    local allData = {}--总奖励数据
    local curBasicPool = 0
    local curFinalPool = 0

    local ActInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.YiJingBaoKu)--活动数据
    local BlessingConfigNew = ConfigManager.GetConfigDataByKey(ConfigName.BlessingConfigNew,"ActivityId",ActInfo.activityId)
    local RewardAllConfig = ConfigManager.GetConfig(ConfigName.BlessingRewardPoolNew)
    --领取过的35条数据
    for i = 1, 99 do
        if ActInfo.mission[i] then
            local v = ActInfo.mission[i]
            if v.missionId < 100 then
                local data = {}
                data.Id = v.missionId
                data.rewardId = v.progress
                data.reward = {}
                if v.progress ~= 0 then
                    data.reward = RewardAllConfig[v.progress].Reward
                    data.configId = RewardAllConfig[v.progress].Id
                end
                
                table.insert(finalCardDatas,data)
            end
        end
    end

    --大奖和当前层数数据
    for i = 1, 1100 do
        if ActInfo.mission[i] then
            local v = ActInfo.mission[i]
            if v.missionId == 100 then
                
                actData.curLevel = v.progress
                curBasicPool = BlessingConfigNew.BasicPoolId[v.progress]
                curFinalPool = BlessingConfigNew.FinalPoolId
            elseif v.missionId > 1000 then
                local data = {}
                data.rewardId = v.missionId-1000
                data.progress = v.progress
                
                data.configId = RewardAllConfig[data.rewardId].Id
                table.insert(allData,data)
            end
        end
    end
    --初始的坑的35条数据
    local RewardConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.BlessingRewardPoolNew,"PoolId",curBasicPool)
    local index = 1
    for i = 1, #RewardConfig do
        local j = 1
        while(j <= RewardConfig[i].InitializeNum) do
            local data = {}
            if index ~= 18 then
                data.rewardId = RewardConfig[i].Id
                data.reward = {}
                data.reward = RewardConfig[i].Reward
                j = j + 1
            else
                data.rewardId = 0
                data.reward = nil
            end
            table.insert(initCardDatas,data)
            index = index + 1
        end
    end

    actData.activityId = ActInfo.activityId
    actData.curBasicPool = curBasicPool
    actData.curFinalPool = curFinalPool
    actData.selectId = ActInfo.value
    actData.endTime = ActInfo.endTime
    

    actData.initCardDatas = initCardDatas
    actData.finalCardDatas = finalCardDatas
    actData.allData = allData

    return actData
end

--宝库奖励的剩余数据
function this.GetLeftRewardData()
    local actData = this.GetBaoKuData()
    local finalCardDatas = actData.finalCardDatas
    local RewardConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.BlessingRewardPoolNew,"PoolId",actData.curLevel)--初始所有奖励数据
    local data={}
    for i = 1, #RewardConfig do
        data[RewardConfig[i].Id] = {}
        data[RewardConfig[i].Id].id = RewardConfig[i].Id
        data[RewardConfig[i].Id].reward = RewardConfig[i].Reward
        data[RewardConfig[i].Id].progress = RewardConfig[i].InitializeNum
        data[RewardConfig[i].Id].limit = RewardConfig[i].InitializeNum
    end

    for i = 1, #finalCardDatas do
        if finalCardDatas[i].rewardId and finalCardDatas[i].rewardId ~= 0 and finalCardDatas[i].rewardId ~= actData.selectId then
            data[finalCardDatas[i].rewardId].progress = data[finalCardDatas[i].rewardId].progress - 1
        end
    end
    return data
end

function this.LingShouBuildData()
    local rewardData={}
    local showData={}
    local ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LingShouBaoGe)
    local activityId = ActData.activityId
    local LSrewardData = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",activityId)
    local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",activityId)
    local singleRecruit = array[1]
    local tenRecruit = array[2]
    local curScore = 0
    --第一条为选择抽取的灵兽信息
    for index, value in ipairs(ActData.mission) do
        local v = ActData.mission[index]
        if v.missionId == 0 then
            if v.progress == 0 then
                local mergePool = singleRecruit.MergePool
                local poolId = ConfigManager.GetConfigDataByKey(ConfigName.LotterySpecialConfig,"Type",mergePool).pool_id
                local tempData = ConfigManager.GetConfigDataByKey(ConfigName.LotteryRewardConfig,"Pool",poolId)
                showData.sasId = 0
                showData.monsterId = tempData.Reward[1]
                showData.iconId = LSrewardData[1].Reward[1][1]
            else
                local tempData = SpiritAnimalSummonConfig[v.progress]
                showData.sasId = tempData.Id
                showData.monsterId = tempData.FocusID
                showData.iconId = tempData.TargetItemList[2]
            end
        end
    end
    --剩下的是奖励信息
    for i = 1, #LSrewardData do
        local v = LSrewardData[i]
        for index, value in ipairs(ActData.mission) do
            if v.Id == value.missionId then
                local data = {}
                data.missionId = value.missionId
                data.reward = {}
                data.iconId = showData.iconId
                data.num = v.Reward[1][2]
                data.value = v.Values[1][1]
                curScore = ActData.mission[index].progress
                if curScore >= data.value then
                    if value.state == 0 then
                        data.state = 1--可领的
                    else
                        data.state = 2--领完的
                    end
                else
                    data.state = 0--不可领的
                end
                table.insert(rewardData,data)
            end
        end
    end
    return rewardData,showData,curScore
end

function this.LingShouUpCheckRed()
    local freeTime = 0
    local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
    local ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LingShouBaoGe)
    if not ActData then
        return false
    end
    local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",ActData.activityId)
    local freeTimesId=lotterySetting[array[1].Id].FreeTimes
    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
    end

    local rewardData,showData,curScore = DynamicActivityManager.LingShouBuildData()
    for i = 1, #rewardData do
        if rewardData[i].state == 1 or freeTime >=1 then
            return true
        end
    end
    return false
end

--新将来袭获取数据
function this.XinJiangBuildData()
    local data={}
    local ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.XinJiangLaiXi)
    local newHeroData = ConfigManager.GetConfigData(ConfigName.NewHeroConfig,ActData.activityId)
    data.endTime = ActData.endTime
    data.fightTime = PrivilegeManager.GetPrivilegeRemainValue(2012)
    data.buyTime = PrivilegeManager.GetPrivilegeRemainValue(2013)
    data.money = BagManager.GetTotalItemNum(UpViewRechargeType.XinJiangCoin)
    local rewardGroupId = newHeroData.DropList[#newHeroData.DropList][2]
    data.reward = ConfigManager.GetConfigData(ConfigName.RewardGroup,rewardGroupId).ShowItem
    data.activityId = ActData.activityId
    return data
end

function this.XiangYaoBuildData()
    local rewardData={}
    local showData={}
    local ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.XiangYaoDuoBao)
    local activityId = ActData.activityId
    local LSrewardData = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",activityId)
    local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",activityId)
    local singleRecruit = array[1]
    local tenRecruit = array[2]
    local curScore = 0
    --第一条为选择抽取的英雄信息
    for index, value in ipairs(ActData.mission) do
        local v = ActData.mission[index]
        if v.missionId == 0 then
            if v.progress == 0 then
                local mergePool = singleRecruit.MergePool
                local poolId = ConfigManager.GetConfigDataByKey(ConfigName.LotterySpecialConfig,"Type",mergePool).pool_id
                local tempData = ConfigManager.GetConfigDataByKey(ConfigName.LotteryRewardConfig,"Pool",poolId)
                showData.sasId = 0
                showData.monsterId = tempData.Reward[1]
                showData.iconId = LSrewardData[1].Reward[1][1]
            else
                local tempData = SpiritAnimalSummonConfig[v.progress]
                showData.sasId = tempData.Id
                showData.monsterId = tempData.FocusID
                showData.iconId = tempData.TargetItemList[2]
            end
        end
    end
    --剩下的是奖励信息
    for i = 1, #LSrewardData do
        local v = LSrewardData[i]
        for index, value in ipairs(ActData.mission) do
            if v.Id == value.missionId then
                local data = {}
                data.missionId = value.missionId
                data.reward = v.Reward
                data.iconId = v.Reward[1][1]
                data.num = v.Reward[1][2]
                data.value = v.Values[1][1]
                curScore = ActData.mission[index].progress
                if curScore >= data.value then
                    if value.state == 0 then
                        data.state = 1--可领的
                    else
                        data.state = 2--领完的
                    end
                else
                    data.state = 0--不可领的
                end
                table.insert(rewardData,data)
            end
        end
    end
    return rewardData,showData,curScore
end

--升星有礼拿数据
function this.ShengXingYouLiGetData()
    local data={}
    local actData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FindFairyUpStar)
    data.activityId = actData.activityId
    data.endTime = actData.endTime
    data.mission = {}
    local rewardData = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",data.activityId)

    for i = 1, #actData.mission do
        local d={}
        d.missionId = actData.mission[i].missionId
        d.state = actData.mission[i].state
        d.progress = actData.mission[i].progress
        
        d.need = rewardData[i].Values[2][1]
        d.reward = rewardData[i].Reward
        d.word = GetLanguageStrById(rewardData[i].ContentsShow)
        d.jump = rewardData[i].Jump[1]
        table.insert(data.mission,d)
    end
    return data
end

--检测升星有礼的红点
function this.CheckShengXingYouLiRedPoint()
   local activeData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FindFairyUpStar)
    if activeData then
        for i = 1, #activeData.mission do
            local sConFigData = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig, activeData.mission[i].missionId)
            if sConFigData then
                local value = sConFigData.Values[2][1]
                if activeData.mission[i].state == 0 and activeData.mission[i].progress >= value then
                    return true
                end
            end
        end
    end
    return false
end

--新将来袭红点
function this.CheckXinJiangLaiXiRedPoint()
    local fightTime = PrivilegeManager.GetPrivilegeRemainValue(2012)
    local ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.XinJiangLaiXi)
    if not ActData then
        return false
    end
    if fightTime > 0 then
        return true
    else
        return false
    end
end

--降妖夺宝红点
function this.CheckXiangYaoDuoBaoRedPoint()
    local freeTime = 0
    local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
    local ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.XiangYaoDuoBao)
    if not ActData then
        return false
    end
    local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",ActData.activityId)
    local freeTimesId = lotterySetting[array[1].Id].FreeTimes
    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
    end

    local rewardData,showData,curScore = DynamicActivityManager.XiangYaoBuildData()
    for i = 1, #rewardData do
        if rewardData[i].state == 1 or freeTime >=1 then
            return true
        end
    end
    return false
end

function this.GetActivityTableDataByPageInde(pageIndex)
    local activityDic = {}
    local functionDic = {}
    local activityGroupsData = {}
    local activityDatas = {}
    local configs = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityGroups,"PageType",pageIndex)
    for i = 1 , #configs do
        if configs[i].ActiveType > 0 then
            if not activityDic[configs[i].ActiveType] then
                if configs[i].ShopData and configs[i].ShopData[1][1] == -9999 then
                    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.DynamicAct)
                    if id and id > 0 and ActivityGiftManager.IsQualifiled(ActivityTypeDef.DynamicAct) and GlobalActivity[id].ShowArt == configs[i].ActId then
                        activityDic[configs[i].ActiveType] = configs[i]
                        table.insert(activityGroupsData,configs[i])
                    end
                elseif configs[i].ShopData and configs[i].ShopData[1][1] == -6666 then
                    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FestivalActivity)
                    if id and id > 0 and ActivityGiftManager.IsQualifiled(ActivityTypeDef.FestivalActivity) and GlobalActivity[id].ShowArt == configs[i].ActId then
                        activityDic[configs[i].ActiveType] = configs[i]
                        table.insert(activityGroupsData,configs[i])
                    end
                else
                    activityDic[configs[i].ActiveType] = configs[i]
                    table.insert(activityGroupsData,configs[i])
                end
            end
        elseif configs[i].FunType > 0 then
            if not activityDic[configs[i].FunType] then
                functionDic[configs[i].FunType] = configs[i]
                table.insert(activityGroupsData,configs[i])
            end
        elseif configs[i].ShopData and configs[i].ShopData[1][1] == -9999 then
            local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.DynamicAct)
            if id and id > 0 and ActivityGiftManager.IsQualifiled(ActivityTypeDef.DynamicAct) and GlobalActivity[id].ShowArt == configs[i].ActId then
                table.insert(activityGroupsData,configs[i])
            end
        elseif configs[i].ActiveType == 0 and configs[i].FunType == 0 then
            table.insert(activityGroupsData,configs[i])
        end
    end
    table.sort(activityGroupsData,function(a,b)
        if a.Sort == b.Sort then
            return a.ActId > b.ActId
        else
            return a.Sort < b.Sort
        end
    end)
    return activityGroupsData
end

-- 判段跳转index活动是否开启
function this.IsActivityOpenByJumpIndex(pageIndex, jumpIndex)
    local tb = this.GetActivityTableDataByPageInde(pageIndex)
    for i = 1, #tb do
        if tb[i].Sort == jumpIndex then
            if tb[i].IfBack then
                if tb[i].ActiveType > 0 then
                    local id = ActivityGiftManager.IsActivityTypeOpen(tb[i].ActiveType)
                    return id and id > 0 and ActivityGiftManager.IsQualifiled(tb[i].ActiveType)
                elseif tb[i].FunType > 0 then
                    return ActTimeCtrlManager.SingleFuncState(tb[i].FunType)
                end
            end
            return true
        end
    end
    return true
end


-- 玩家是否有资格开启
function this.IsQualifiled(id)
    -- 相同类型活动解锁类型相同，所以只判断第一个
    local data = ConfigManager.GetConfigData(ConfigName.ActivityGroups,id)
    if not data then return true end
    -- 当前玩家等级
    local qualifiled = false
    local playerLv = PlayerManager.level
    local openRule = data.OpenRules
    if not openRule or #openRule < 1 then
        return true
    end
    if openRule[1] == 1 then  -- 关卡开启
        qualifiled = FightPointPassManager.IsFightPointPass(openRule[2])
    elseif openRule[1] == 2 then                      -- 等级开启
        qualifiled = playerLv >= openRule[2]
    elseif openRule[1] == 3 then    -- 工坊等级开启
        qualifiled = WorkShopManager.WorkShopData.lv >= openRule[2]
    end
    return qualifiled
end

function this.GetGiftDataByType(ShopData) 
    local rechargeNum = VipManager.GetChargedNum()--已经充值的金额
    local lv = PlayerManager.level
    local shopData = {}
    for i = 1,#ShopData do
        if ShopData[i][1] == DataType.Direct and RECHARGEABLE then
            local topspeedData = this.ResetShopData(OperatingManager.GetGiftGoodsInfoList(ShopData[i][2]), ShopData[i][3], ShopData[i][1])
            for i = 1, #topspeedData do
                if lv >= topspeedData[i].data.shopItemData.LevelLinit[1] and lv <= topspeedData[i].data.shopItemData.LevelLinit[2] then
                    table.insert(shopData,topspeedData[i])
                end
            end
        elseif ShopData[i][1] == DataType.Shop then
            local topspeedData = this.ResetShopData(ShopManager.GetShopDataByType(ShopData[i][2]).storeItem, ShopData[i][2], ShopData[i][1])
            for i = 1, #topspeedData do
                if (not topspeedData[i].data.shopItemData.ShowRule) or (rechargeNum >= topspeedData[i].data.shopItemData.ShowRule[2]) then
                    table.insert(shopData,topspeedData[i])
                end
            end
        end
    end
    table.sort(shopData,function(a,b)
        if a.sortId == b.sortId then
            if a.DataType == b.DataType and a.DataType == DataType.Direct then
                return rechargeCommodityConfig[a.data.shopData.goodsId].Sequence < rechargeCommodityConfig[b.data.shopData.goodsId].Sequence
            elseif a.DataType == b.DataType and a.DataType == DataType.Shop then
                return a.data.shopData.id < b.data.shopData.id
            else
                return a.DataType > b.DataType
            end
        else
            return a.sortId > b.sortId
        end
    end)
    return shopData
end

-- 商店数据重组
function this.ResetShopData(shopData, buyType, DataTypeIndex)
    local newData = {}
    local boughtNum = 0
    local limitNum = 0
    for i = 1, #shopData do
        newData[#newData + 1] = this.CreatSingleData(shopData[i],DataTypeIndex,buyType)
    end
    return newData
end

function this.CreatSingleData(shopData,DataTypeIndex,buyType)
    local _data = {}
    local data = {}
    local curSortId = 0--临时一个数值 只用做排序用
    if DataTypeIndex == DataType.Shop then
        data.shopData = shopData
        data.shopItemData = shopItemConfig[shopData.id]
        data.shows = data.shopItemData.Goods       
        data.tipImageText = GetLanguageStrById(11356)
        data.tagName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,data.shows[1][1]).Name)
        data.boughtNum = ShopManager.GetShopItemHadBuyTimes(buyType, shopData.id)
        data.limitNum = ShopManager.GetShopItemLimitBuyCount(shopData.id)
        if data.limitNum == -1 then
            curSortId = 3
        elseif data.limitNum - data.boughtNum  > 0 then
            curSortId = 2
        end
        data.costId,data.finalNum,data.oriCostNum = ShopManager.calculateBuyCost(buyType, shopData.id, 1)
        data.price = data.finalNum
    elseif DataTypeIndex == DataType.Direct and rechargeCommodityConfig[shopData.goodsId].ShowType == buyType  then
        data.shopData = shopData
        data.shopItemData = rechargeCommodityConfig[shopData.goodsId]
        data.shows = data.shopItemData.RewardShow
        data.tagName = GetLanguageStrById(data.shopItemData.Name)
        data.boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift,shopData.goodsId)
        data.limitNum = rechargeCommodityConfig[shopData.goodsId].Limit
        if data.limitNum == -1 then
            curSortId = 2
        elseif data.limitNum - data.boughtNum  > 0 then
            curSortId = 1
        end
        data.costId = nil
        data.finalNum = MoneyUtil.GetMoney(data.shopItemData.Price)
        data.oriCostNum = nil
        if data.shopItemData.DailyUpdate == 7 then
            data.tipImageText = GetLanguageStrById(11699) 
        elseif data.shopItemData.DailyUpdate == 15 then
            data.tipImageText = GetLanguageStrById(11700)
        elseif data.shopItemData.DailyUpdate == 30 then
            data.tipImageText = GetLanguageStrById(11357)
        else
            data.tipImageText = nil
        end
        data.price = MoneyUtil.GetMoney(data.finalNum)
        data.endTime = shopData.endTime
    else
        return nil
    end
    data.buyInfo = GetLanguageStrById(10580)..data.limitNum - data.boughtNum..GetLanguageStrById(10048)
    _data.data = data
    _data.DataType = DataTypeIndex
    _data.sortId = curSortId
    _data.buyType = buyType
    return _data
end

local stateSort = {
    [1] = 1,
    [2] = 4,
    [0] = 3,
    [-1] = 2,
}

function this.GetMissionDataByActId(activityId)
    local actiInfo = ActivityGiftManager.GetActivityInfoByType(activityId)
    local havaBought = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.GrowthReward, GlobalActivity[activityId].CanBuyRechargeId[1])--当前礼包ID(101\102\103\104\105)
    local data = {}
    for k,v in ipairs(actiInfo.mission) do
        table.insert(data,this.CreatSingleMissionData(v,havaBought))
    end
    table.sort(data, function(a, b)
         if stateSort[a.state] == stateSort[b.state] then
            return a.missionId < b.missionId
         else
            return stateSort[a.state] > stateSort[b.state]
         end
     end)
     return data
end

function this.CreatSingleMissionData(missionData,havaBought)
    local data = {}
    data.missionId = missionData.missionId
    data.shows = actRewardConfig[missionData.missionId].Reward
    data.itemName = GetLanguageStrById(itemConfig[data.shows[1][1]].Name) 
    data.content = GetLanguageStrById(11367)..actRewardConfig[data.missionId].Values[1][2]..GetLanguageStrById(11368)
    data.isCanGetReward = PlayerManager.level >= actRewardConfig[data.missionId].Values[1][2]
    --0 未领取(等级已达到，未购买基金)  1 已领取  -1 未达到等级  2可领取
    if missionData.state == 0 then
        if PlayerManager.level < actRewardConfig[data.missionId].Values[1][2] then
            data.state = -1
        elseif havaBought.buyTimes > 0 then
            data.state = 2
        else
            data.state = 0
        end
    else
        data.state = missionData.state
    end
    
    return data
end

function this.RecrutDetailData(actType)
    if actType == ActivityTypeDef.LingShouBaoGe then
        return DynamicActivityManager.LingShouBuildData()
    elseif actType == ActivityTypeDef.XiangYaoDuoBao then
        return DynamicActivityManager.XiangYaoBuildData()
    else
        return nil,nil,nil
    end
end

return this