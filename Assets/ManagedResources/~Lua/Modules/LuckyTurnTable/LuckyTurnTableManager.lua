LuckyTurnTableManager = {};
local this = LuckyTurnTableManager

this.luckyData = {}---服务器幸运探宝跑马灯 物品数据     indication、刷新同一数据
this.advancedData = {}---服务器高级探宝跑马灯 物品数据

this.luckyTempData = {}---幸运探宝 临时数据(包含Drop)
this.advancedTempData = {}---高级探宝 临时数据

this.dialRewardConfig = {}---表数据
local activityRewardConfig = {}
this.dialRewardSettingConfig = {}
this.gameSettingConfig = ConfigManager.GetConfigData(ConfigName.GameSetting,1)

---下次免费刷新时间倒计时
this.luckyFreeTime = 0
this.advancedFreeTime = 0

---幸运积分宝箱数据
this.boxReward_One = {}
this.boxReward_Two = {}

this.curTreasureType = nil---当前探宝类型

--- 上次请求数据的最后一位标识位
--- 幸运探宝
this.lastMsgId = 0
--- 高级探宝
this.upperLastMsgId = 0

--- 显示数据本地存放
this.luckMsgStrList = {}
this.upperLuckMsgList = {}

---探宝类型
local TreasureType = {
    Lucky = 30,
    Advanced = 31,
}

this.luckyTimes = 0
this.advanceTimes = 0
function this.SetTimes(_luckyTimes,_advanceTimes)
    if _luckyTimes then
        this.luckyTimes = _luckyTimes
    end
    if _advanceTimes then
        this.advanceTimes = _advanceTimes
    end
end

function this.Initialize()
    --世界跑马灯数据存储
    this.worldMessageData = {}
    this.luckMsgStrList = {}

    this.upperLuckMsgList = {}
    this.lastMsgId = 0
    this.upperLastMsgId = 0

    --幸运值积分
    this.integralGetNumber = 0
    this.luckyCountDownTimer = Timer.New(nil, 1, -1, true)
    this.advancedCountDownTimer = Timer.New(nil,1,-1,true)
    ---能够获取跑马灯数据
    this.isCanGetWorldMessage = true

    activityRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
    for i, v in ConfigPairs(activityRewardConfig) do
        if v.ActivityId == ActivityTypeDef.LuckyTurnTable_One then
            table.insert(this.boxReward_One,v)
        elseif v.ActivityId == ActivityTypeDef.LuckyTurnTable_Two then
            table.insert(this.boxReward_Two,v)
        end
    end
end

----------------------------------------------------
---初始化幸运转盘数据读取表数据
function this.InitTableData()
    this.dialRewardSettingConfig = ConfigManager.GetConfig(ConfigName.DialRewardSetting)
    this.dialRewardConfig = ConfigManager.GetConfig(ConfigName.DialRewardConfig)
    this.gameSettingConfig = ConfigManager.GetConfigData(ConfigName.GameSetting,1)
end

---接收服务器数据(每日5点刷新刷新)
function this.ReceiveServerDataForFive(data1,data2)
    this.luckyData = data1
    this.advancedData = data2
    --for i, v in ipairs(this.luckyData) do
    --end
    --for i, v in ipairs(this.advancedData) do
    --end
end

---请求活动数据
function this.GetLuckyTurnRequest(func)
    NetManager.GetLuckyTurnRequest(function(msg)
        this.luckyData = msg.posInfos
        this.advancedData = msg.posInfosAdvance
        --this.luckyFreeTime = 20 --假设返回时间戳
        --this.advancedFreeTime = 10800
        if func then
            func(msg)
        end
    end)
end

---接收服务器数据(监听服务器推送)
function this.ReceiveServerData(data1,data2)
    this.luckyData = data1
    --for i, v in ipairs(this.luckyData) do
    --end
    this.advancedData = data2
    --for i, v in ipairs(this.advancedData) do
    --end
    --this.luckyFreeTime = 10800
    --this.advancedFreeTime = 10800
end

---探宝 1探宝类型ID 2是否多次（false单次 true多次） 3回调
function this.GetLuckyTurnRankRequest(activityId,repeated,func)
    this.luckyTempData = {}
    this.advancedTempData = {}
    NetManager.GetLuckyTurnRankRequest(activityId,repeated,function(msg)
        if activityId == TreasureType.Lucky then
            this.luckyTempData = msg --存储临时数据 主要包括Drop

            --在登陆时 服务器会把所有物品数据推给我posInfos 包括已抽取次数  我可以把数据先保存下来 在每次请求数据时 通过回调的数据来动态改变现有数据的属性
            for i = 1, #this.luckyData do
                for j = 1, #msg.posInfos do
                    if this.luckyData[i].luckId == msg.posInfos[j].luckId then
                        this.luckyData[i].luckTimes = msg.posInfos[j].luckTimes
                    end
                end
            end
        elseif activityId == TreasureType.Advanced then
            this.advancedTempData = msg
            for i = 1, #this.advancedData do
                for j = 1, #msg.posInfos do
                    if this.advancedData[i].luckId == msg.posInfos[j].luckId then
                        this.advancedData[i].luckTimes = msg.posInfos[j].luckTimes
                    end
                end
            end
        end
        if func then
            func()
        end
    end)
end

---刷新跑马灯物品
function this.GetLuckyTurnRefreshRequest(activityId,isFree,func)
    NetManager.GetLuckyTurnRefreshRequest(activityId,isFree,function(msg)
        if activityId == TreasureType.Lucky then
            this.luckyData = msg.posInfos
        elseif activityId == TreasureType.Advanced then
            this.advancedData = msg.posInfos
        end
        if func then
            func(msg)
        end
    end)
end
-------------------------------------------------------------

---开始刷新转盘记录数据
function this.StartLuckyTurnRecordDataUpdate()
    -- 开始定时刷新
    if not this._CountDownTimer then
        this.lastMsgId = 0
        this.upperLastMsgId = 0
        this._CountDownTimer = Timer.New(this.TimeUpdate, 2, -1, true)
        this._CountDownTimer:Start()
    end
end
---每两秒刷新一次数据
function this.TimeUpdate()
    if this.isCanGetWorldMessage then
        local msgId = this.curTreasureType == TreasureType.Lucky and this.lastMsgId or this.upperLastMsgId
        NetManager.RequestChatMsg(0, msgId, function(data)
            this.GetWorldMessageIndication(data)
        end)
    end
end
---监听世界消息推送
function this.GetWorldMessageIndication(data)
    -- 先对数据排个序
    -- table.sort(data.chatInfo, function(a, b)
    --     return a.times < b.times
    -- end)
    -- 判断messageId是否符合要求，新数据得第一条messageId必须比旧数据最后一条大
    local listData = {}
    local luckMsgIdList = {}

    if this.curTreasureType == TreasureType.Lucky then
        for i = 1, #data.chatInfo do
            if data.chatInfo[i].messageType == 5 then
                if data.chatInfo[i].msg ~= "" then
                    table.insert(listData, GetMailConfigDesc(data.chatInfo[i].msg,data.chatInfo[i].chatparms))
                    luckMsgIdList[#luckMsgIdList + 1] = data.chatInfo[i].messageId
                end
            end
        end
    elseif this.curTreasureType == TreasureType.Advanced then
        for i = 1, #data.chatInfo do
            if data.chatInfo[i].messageType == 6 then
                if data.chatInfo[i].msg ~= "" then
                    table.insert(listData, GetMailConfigDesc(data.chatInfo[i].msg,data.chatInfo[i].chatparms))
                    luckMsgIdList[#luckMsgIdList + 1] = data.chatInfo[i].messageId
                end
            end
        end
    end

    -- 数据没有变化，则不刷新
    local len = #listData
    if len == 0 then
        return
    end

    --- ID大小排序
    if len > 1 then 
        table.sort(luckMsgIdList, function(a, b) 
            return a < b
        end)
    end

    local showData = {}
    local msgIdList = {}
    local startIndex = #listData >= 6 and #listData - 5 or 1
    
    for i = startIndex, #listData do
        showData[#showData + 1] = listData[i]   
        msgIdList[#msgIdList + 1] = luckMsgIdList[i]
    end

    this.SetLocalShowData(showData, this.curTreasureType)

    local lastIndex = #msgIdList
    local msgId = 0
    msgId = msgIdList[lastIndex]

    if lastIndex > 0 then -- 有数据更新，更新ID和本地缓存的数据
        --- 根据界面类型更新ID
        if this.curTreasureType == TreasureType.Lucky then
            this.lastMsgId = msgId
        elseif this.curTreasureType == TreasureType.Advanced then
            this.upperLastMsgId = msgId
        end
    end

    Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnLuckyTableWorldMessage, this.curTreasureType)
end

function this.SetLocalShowData(showData, type)
    for i = 1, #showData do
        if type == TreasureType.Lucky then 
            this.luckMsgStrList[#this.luckMsgStrList + 1] = showData[i]
        elseif type == TreasureType.Advanced then 
            this.upperLuckMsgList[#this.upperLuckMsgList + 1] = showData[i]
        end
    end

    --- 只保留最新的6条数据
    local oldData = type == TreasureType.Lucky and this.luckMsgStrList or this.upperLuckMsgList

    if type == TreasureType.Lucky then 
        this.luckMsgStrList = {}
        this.luckMsgStrList = this.ReplaceData(oldData)

    elseif type == TreasureType.Advanced then 
        this.upperLuckMsgList = {}
        this.upperLuckMsgList = this.ReplaceData(oldData)
    end

end

function this.ReplaceData(oldData)
    local list = {}
    local index = #oldData >= 6 and #oldData - 5 or 1
    for i = index, #oldData do
        list[#list + 1] = oldData[i]
    end

    return list
end

function this.GetShowDataByType(type)
    local oldData = type == TreasureType.Lucky and this.luckMsgStrList or this.upperLuckMsgList
    return oldData
end

---面板退出时清空数据
function this.ClearSaveData()
    this.luckMsgStrList = {}
    this.upperLuckMsgList = {}
    this.lastMsgId = 0
    this.upperLastMsgId = 0
end

---获取探宝券数量  1探宝类型
function this.GetTreasureTicketNum(treasureType)
    if treasureType == TreasureType.Lucky then
        return BagManager.GetItemCountById(60)--返回幸运探宝所需物品
    elseif treasureType == TreasureType.Advanced then
        return BagManager.GetItemCountById(61)--返回高级探宝所需物品
    end
end

---获取刷新按钮消耗材料数
function this.GetRefreshItemNum()
    return BagManager.GetItemCountById(16)
end

---获取探宝1/多次按钮信息  1探宝类型
function this.GetTreasureBtnInfo(treasureType)
    if treasureType == TreasureType.Lucky then
        local oneData = {1,this.dialRewardSettingConfig[1].CostItem[2][4]}--1探宝次数 2消耗道具数量
        local moreData = {this.dialRewardSettingConfig[1].ExtractingTime,this.dialRewardSettingConfig[1].MultipleCostItem[2][4]}
        local icon = SetIcon(60)
        return oneData,moreData,icon
    elseif treasureType == TreasureType.Advanced then
        local oneData = {1,this.dialRewardSettingConfig[2].CostItem[2][4]}
        local moreData = {this.dialRewardSettingConfig[2].ExtractingTime,this.dialRewardSettingConfig[2].MultipleCostItem[2][4]}
        local icon = SetIcon(61)
        return oneData,moreData,icon
    end
end

---设置幸运值相关
function this.SetLuckyValue()
    for i, v in pairs(ActivityGiftManager.mission) do
        --v.activityId活动Id 活动记录值v.value
        if v.activityId == ActivityTypeDef.LuckyTurnTable_One then
            this.value_1 = v.value
        elseif v.activityId == ActivityTypeDef.LuckyTurnTable_Two then
            this.value_2 = v.value
        end
    end
end

---获取幸运值相关
function this.GetLuckyValue()
    if this.curTreasureType == TreasureType.Lucky then
        return this.value_1
    elseif this.curTreasureType == TreasureType.Advanced then
        return this.value_2
    end
end

---获取奖励盒状态
function this.GetRewardState(activityId,missionId)
    for i, v in pairs(ActivityGiftManager.mission) do
        if v.activityId == activityId then
            for n, m in ipairs(v.mission) do
                if m.missionId == missionId then
                    return m.state
                end
            end
        end
    end
end

-- 获取免费探宝刷新时间
function this.GetItemRecoverTime(itemId)
    for _, data in ipairs(this.gameSettingConfig.ItemAdd) do
        if data[1] == itemId then
            return data[3]
        end
    end
end

-------红点相关--------------
function this.ReturnRedPointState()
    if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LuckyTurnTable_One) then
        return this.ReturnRewardBoxRedPoint()
    else
        return false
    end
end
---限时活动关联幸运探宝红点显示
function this.ReturnRewardBoxRedPoint()
    for i, v in pairs(ActivityGiftManager.mission) do
        if v.activityId == ActivityTypeDef.LuckyTurnTable_One then
            this.value_1 = v.value
        elseif v.activityId == ActivityTypeDef.LuckyTurnTable_Two then
            this.value_2 = v.value
        end
    end

    if this.CheckLuckyRedPoint() or this.CheckAdvancedRedPoint() then
        return true
    else
        return false
    end
end
---本地检查红点
function this.CheckLuckyRedPoint()
    local tab = {}
    for i = 1, 5 do--遍历所有达到领取奖励要求 且未领取奖励的宝箱状态 存入tab
        if this.value_1 >= this.boxReward_One[i].Values[1][1] then
            if this.GetRewardState(30,this.boxReward_One[i].Id) == 0 then
                table.insert(tab,0)
            end
        end
    end

    if #tab > 0 then --如果有未领取的奖励 显示红点
        return true
    else
        return false
    end
end
function this.CheckAdvancedRedPoint()
    local tab = {}
    for i = 1, 5 do
        if this.value_2 >= this.boxReward_Two[i].Values[1][1] then
            if this.GetRewardState(31, this.boxReward_Two[i].Id) == 0 then
                table.insert(tab, 0)
            end
        end
    end
    if #tab > 0 then
        return true
    else
        return false
    end
end

return this