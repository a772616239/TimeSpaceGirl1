LuckyCatManager = {};
local this = LuckyCatManager
local luckyCatConfig = ConfigManager.GetConfig(ConfigName.LuckyCatConfig)
local CHANNEL = 0 --系统频道
local isFirstEnter = true
local isNewData = 0
local itemType = 0
local canGetTime = -1
local isFirstStart = true
--- 请求数据的下标
local lastMsgId = 0

function this.Initialize()
    --活动Id
    this.activityId = 0
    --招财类型
    this.luckyType = {}
    --招财次数
    this.luckyTime = {}
    --消耗数量
    this.consumeValue = {}
    --奖励上限
    this.valueUp = {}
    --奖励下限
    this.valueDown = {}
    --限制条件（充值金额）
    this.rmbValue = {}
    --抽奖次数
    this.getRewardNumber = 0
    --掉落物品个数
    this.dropNumbers = 0
    --活动期间累计充值
    this.hasRechargeNum = 0
    --世界消息集合
    this.worldMessageData = {}
    this.unitsText = 0
    this.tensText = 0
    this.hundredsText = 0
    this.thousandsText = 0
    this.tenThousandsText = 0
    --是否进入过招财猫
    this.isEnterLuckyCat = false
    --能够拉去跑马灯数据
    this.isCanGetWorldMessage=true
    --招财猫开放
    this.isOpenLuckyCat=false
    lastMsgId = 0
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.CheckRedPoint)
end
-------招财猫活动相关数据-----------
function this.InitLuckyCatData()
    this.luckyType={}
    this.luckyTime={}
    this.consumeValue={}
    this.valueUp={}
    this.valueDown={}
    this.rmbValue={}
    
    for i, v in ConfigPairs(luckyCatConfig) do
        if this.activityId == v.ActivityId then
            this.luckyType[i] = v.LuckyType
            this.luckyTime[i]=v.LuckyTime
            this.consumeValue[i]=v.ConsumeValue
            this.valueUp[i]=v.ShowMax
            this.valueDown[i]=v.ValueDown
            this.rmbValue[i]=v.RmbValue

            --table.insert(this.luckyType,v.LuckyType)
            --table.insert(this.luckyTime,v.LuckyTime)
            --table.insert(this.consumeValue,v.ConsumeValue)
            --table.insert(this.valueUp,v.ShowMax)
            --table.insert(this.valueDown,v.ValueDown)
            --table.insert(this.rmbValue,v.RmbValue)
            itemType = v.LuckyType
        end
    end
end
-- 每两秒刷新一次数据
function this.TimeUpdate()
    if this.isCanGetWorldMessage then
        NetManager.RequestChatMsg(CHANNEL, lastMsgId, function(data)
            this.GetWorldMessageIndication(data)
        end)
    end
end

-- 开始刷新招财猫数据
function this.StartLuckyCatDataUpdate()
    -- 开始定时刷新
    if not this._CountDownTimer then
        this._CountDownTimer = Timer.New(this.TimeUpdate, 2, -1, true)
        this._CountDownTimer:Start()
    end
end

--关闭招财猫数据刷新
function this.StopLuckyCatUpdate()
    -- 关闭定时刷新
    if this._CountDownTimer then
        this._CountDownTimer:Stop()
        this._CountDownTimer = nil
    end
end

--招财猫的领取进程数据
function this.GetRewardProgress(mission, activityId, rechargeValue)
    this.activityId = activityId
    local getNumbers = {}
    local index = 0
    for n, m in ipairs(mission) do
        getNumbers[n] = m.progress
    end
    for i, v in ipairs(getNumbers) do
        if (v == 1) then
            index = index + 1
        end
    end
    this.getRewardNumber = index
    this.hasRechargeNum = rechargeValue
    this.InitLuckyCatData()
end

--招财猫抽奖请求
function this.GetLuckyCatRequest()
    NetManager.GetActivityRewardRequest(-1, this.activityId, function(_drop)
        this.GetDropNumbers(_drop)
        this.drop = _drop
        this.getRewardNumber = this.getRewardNumber + 1
        CheckRedPointStatus(RedPointType.LuckyCat_GetReward)
        Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnLuckyCatRefresh, true)
    end)
end

--从drop解析掉落物品个数
function this.GetDropNumbers(drop)
    if drop.itemlist ~= nil then
        this.dropNumbers = drop.itemlist[1].itemNum
    end
    this.SplitDropNumbers(this.dropNumbers)
end

--将掉落物品的个数解析为各个位分开
function this.SplitDropNumbers(num)
    this.unitsText = math.floor(num % 10)
    this.tensText = math.floor(num % 100 / 10)
    this.hundredsText = math.floor(num % 1000 / 100)
    this.thousandsText = math.floor(num % 10000 / 1000)
    this.tenThousandsText = math.floor(num / 10000)
end

--通过充值金钱数返回能抽取次数
function this.GetCanRewardTimes(rechargeNum)
    local canRechargeTime = 0
    for i, v in ConfigPairs(luckyCatConfig) do
        if this.activityId == v.ActivityId then
            if rechargeNum >= v.RmbValue then
                canRechargeTime = v.LuckyTime
            end
        end
    end
    return canRechargeTime
end

--监听世界消息推送
function this.GetWorldMessageIndication(data)
    -- 先对数据排个序
    table.sort(data.chatInfo, function(a, b)
        return a.times < b.times
    end)

    -- 判断messageId是否符合要求，新数据得第一条messageId必须比旧数据最后一条大
    local listData = {}
    local msgIdList = {}
    for i = 1, #data.chatInfo do
        if data.chatInfo[i].messageType == 3 then
            if data.chatInfo[i].msg ~= "" then
                table.insert(listData, data.chatInfo[i].msg)
                msgIdList[#msgIdList+1] = data.chatInfo[i].messageId
            end
        end
    end

    -- local canInsert = true  原始代码，不知道干啥使的
    -- for j, v in pairs(this.worldMessageData) do
    --     if (listData[#listData] == v) then
    --         canInsert = false
    --     end
    -- end

    -- 数据没有变化，则不刷新
    local len = #listData
    if len == 0 then
        return
    end

    -- 按照ID再排序
    if len > 1 then 
        table.sort(msgIdList,function(a, b)  
        return a < b
        end)
    end

    -- 获取最新的ID
    local lastId = 0
    lastId = msgIdList[#msgIdList]
    lastMsgId = lastId

    local oldData = this.worldMessageData
    this.worldMessageData = {}
    local startIndex = #listData >= 3 and #listData - 2 or 1

    for i = startIndex, #listData do
        table.insert(oldData, listData[i])
    end

    local newIndex = #oldData >= 3 and #oldData - 2 or 1
    for i = newIndex, #oldData do
        table.insert( this.worldMessageData, oldData[i])
    end

    Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnLuckyCatWorldMessage)
end

--充值进行金额记录
function this.SetAccumRechargeValue(value)
    --this.hasRechargeNum = this.hasRechargeNum + value
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LuckyCat)
    if activityInfo and activityInfo.value then
        this.hasRechargeNum = activityInfo.value
    end
    CheckRedPointStatus(RedPointType.LuckyCat_GetReward)
end

--检测抽取红点
function this.CheckIsShowRedPoint()
    if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LuckyCat) == nil then
        return false
    end
    if this.getRewardNumber >= LengthOfTable(this.consumeValue) then--抽完
        return false
    end
    local canRewardTime = this.GetCanRewardTimes(this.hasRechargeNum)
    local getRewardNumber = this.getRewardNumber + 1
    local curLuckCatConfigData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.LuckyCatConfig,"ActivityId",this.activityId,"LuckyTime",getRewardNumber)
    if curLuckCatConfigData == nil then
        curLuckCatConfigData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.LuckyCatConfig,"ActivityId",this.activityId,"LuckyTime",this.getRewardNumber)
    end
    local costItemNum = this.consumeValue[curLuckCatConfigData.Id]
    --local costItemNum = ConfigManager.GetConfigDataByDoubleKey(ConfigName.LuckyCatConfig,"ActivityId",this.activityId,"LuckyTime",getRewardNumber).ConsumeValue --this.consumeValue[getRewardNumber]

    local haveItemNum = BagManager.GetItemCountById(itemType)
    if costItemNum then
        if haveItemNum >= costItemNum and this.getRewardNumber < canRewardTime then
            return true
        end
    else
        return false
    end
    local currentTime = 0
    --检测有新红点次数未查看显示红点
    for i, v in ConfigPairs(luckyCatConfig) do
        if this.activityId == v.ActivityId then
            if this.hasRechargeNum >= this.rmbValue[i] then
                currentTime = this.luckyTime[i]
            end
        end
    end
    if isFirstStart then
        local canRewardTime = this.GetCanRewardTimes(this.hasRechargeNum)
        local isRemaindTime = canRewardTime - this.getRewardNumber
        isFirstStart = false
        if isRemaindTime >= 1 then
            return true
        else
            return false
        end
    else
        if currentTime > canGetTime and this.isEnterLuckyCat == false then
            return true
        else
            canGetTime = currentTime
            this.isEnterLuckyCat = false
            return false
        end
    end
end

--检测妖晶数量变化进行红点检测
function this.CheckRedPoint()
    local canRewardTime = this.GetCanRewardTimes(VipManager.GetVipLevel())
    local getRewardNumber = this.getRewardNumber + 1
    local haveItemNum = BagManager.GetItemCountById(itemType)
    local costItemNum = this.consumeValue[getRewardNumber]
    if costItemNum then
        if haveItemNum >= costItemNum and this.getRewardNumber < canRewardTime then
            CheckRedPointStatus(RedPointType.LuckyCat_GetReward)
        end
    end
end

return this