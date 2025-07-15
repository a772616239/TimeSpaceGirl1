FindFairyManager = {};
local this = FindFairyManager
--本地表数据
this.rankRewardData = {}--排名大奖数据

this.loginScore = 0--登陆时的免费次数
this.myScore = 0--我的积分
this.tempScore = 0--临时积分

local index = {39, 40, 41}--寻仙限时豪礼表索引（rechargeCommodityConfig没字段，暂时写死）

this.NoticeState = 0--预告状态 0活动状态 1预告状态

--是否处于出海状态
this.isGoToSea = false

--是否是活动结束返回this.isOver = false
this.isOver = false


function this.Initialize()

end

-- 设置排名大奖数据
function this.SetRankRewardData()
    local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ActivityRankingReward)) do
        if(v.ActivityId == curActivityId) then
            table.insert(this.rankRewardData,v)
        end
    end
end

--设置一些数据
function this.SetActivityData()
    local activitData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FindFairy)
    if activitData then
        this.myScore = activitData.value
        this.tempScore = activitData.value % 150
        this.loginScore =PrivilegeManager.GetPrivilegeRemainValue(32)
    end
    
end

--设置免费抽取次数
function this.SetFreeExtract(num)
    this.myScore = this.myScore + num * 10
    this.tempScore = this.tempScore + num * 10

    if num == 1 then--单抽
        if PrivilegeManager.GetPrivilegeRemainValue(32) > 0 then
            PrivilegeManager.RefreshPrivilegeUsedTimes(32,num)
        end
    else--十连
        if PrivilegeManager.GetPrivilegeRemainValue(32) >= 10 then
            PrivilegeManager.RefreshPrivilegeUsedTimes(32, num)
        end
    end
    local addScore = math.floor(this.tempScore / 150)
    if addScore > 0 then
        this.tempScore = this.tempScore - addScore * 150
        if PrivilegeManager.GetPrivilegeRemainValue(32)>=0 then
            PrivilegeManager.RefreshPrivilegeUsedTimes(32, -addScore)
        end
    end
    --local activitData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FindFairy)
    --if activitData then
    
    --end
end

--获取当前期活动Id
function this.GetCurActivityId()
    local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    return curActivityId
end

--获取英雄信息
function this.GetHeroData(activityId)
    local scoreRewardData={}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)) do
        if(v.ActivityId == tonumber(activityId)) then
            table.insert(scoreRewardData,v)
        end
    end
    local heroLiveId = scoreRewardData[1].Drawing
    local heroData = ConfigManager.GetConfigData(ConfigName.HeroConfig,heroLiveId)
    return heroData
end

--获取按钮数据并重新排序数据(操作数据包含value) 寻仙积分奖励、寻仙盛典用
function this.GetBtnDataState(curActivityId)
    local state={}
    for i, v in pairs(ActivityGiftManager.mission) do
        for i = 1, #v.mission do
            if v.activityId == curActivityId then
                table.insert(state,{missionId = v.mission[i].missionId,state = v.mission[i].state,value = v.value}) --插入领取状态 当前积分 对应表Id
            end
        end
    end
    local lingqu = {}--领取(请忽略LowB的命名方式)
    local weidacheng = {}--未达成
    local yilingqu = {}--已领取
    local newData = {}
    for i, v in ipairs(state) do
        local data = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig,v.missionId)
        if v.value >= data.Values[1][1] and v.state == 0 then
            lingqu[#lingqu+1] = v
        end
        if v.value < data.Values[1][1] then
            weidacheng[#weidacheng+1] = v
        end
        if v.value >= data.Values[1][1] and v.state == 1 then
            yilingqu[#yilingqu+1] = v
        end
    end
    table.sort(lingqu, function (a, b) return a.missionId < b.missionId end)
    table.sort(weidacheng, function (a, b) return a.missionId < b.missionId end)
    table.sort(yilingqu, function (a, b) return a.missionId < b.missionId end)
    for i = 1, #lingqu do
        newData[#newData + 1] = lingqu[i]
    end
    for i = 1, #weidacheng do
        newData[#newData + 1] = weidacheng[i]
    end
    for i = 1, #yilingqu do
        newData[#newData + 1] = yilingqu[i]
    end
    return newData,#lingqu--返回重新排序后的数据，返回可领取的数量
end

--获取寻仙限时豪礼数据 并数据重组 寻仙限时豪礼用
function this.GetGiftBtnState()
    local config = {}
    local data = {}
   local allConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.RechargeCommodityConfig, "ShowType", DirectBuyType.XSHL)
    for k,v in pairs(allConfigs) do
        table.insert(config,ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig,v.Id))
        local _data = OperatingManager.GetGiftGoodsInfo(config[k].Type,config[k].Id)
        if _data then
            table.insert(data,{server = _data,native = config[k]})--data由服务器数据与本地表数据组成
        end
    end
    local notPurchas = {} local purchased = {} local newData = {}
    for k,v in pairs(data) do
        if v.server.buyTimes < v.native.Limit then
            table.insert(notPurchas,v)
        else
            table.insert(purchased,v)
        end
    end
    table.sort(notPurchas,function(a,b) return a.native.Id<b.native.Id end)
    table.sort(purchased,function(a,b) return a.native.Id<b.native.Id end)
    for i = 1, #notPurchas do
        newData[#newData+1]=notPurchas[i]
    end
    for i = 1, #purchased do
        newData[#newData+1]=purchased[i]
    end
    return newData
end

--获取活动倒计时间戳(活动开始到开始预告时间)
function this.GetActivityTime()
    local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    local time = 0
    for i, v in pairs(ActivityGiftManager.mission) do
        for i = 1, #v.mission do
            if v.activityId == curActivityId then
                time = v.endTime-tonumber(86400)-GetTimeStamp()
            end
        end
    end
    return time
end


--- itemview重设复用 1根节点 2生成到父节点 3item容器 4容器上限 5缩放 6层级 7根据数据类型生成 8不定参数据...
function this.ResetItemView(root,rewardRoot,itemList,max,scale,sortingOrder,type,...)
    local args = {...}
    local data1 = args[1]
    local data2 = args[2]

    if itemList[root] then -- 存在
        for i = 1, max do
            itemList[root][i].gameObject:SetActive(false)
        end
        if type then
            itemList[root][1]:OnOpen(false, {data1,data2},scale,false,false,false,sortingOrder)
            itemList[root][1].gameObject:SetActive(true)
        else
            for i = 1, #data1 do
                if itemList[root][i] then
                    itemList[root][i]:OnOpen(false, {data1[i][1],data1[i][2],data1[i][3],data1[i][4]},scale,false,false,false,sortingOrder)
                    itemList[root][i]:Reset({data1[i][1],data1[i][2]},ItemType.Hero,{false,true,true,true})
                    itemList[root][i].gameObject:SetActive(true)
                end
            end
        end
    else -- 不存在 新建
        itemList[root] = {}
        for i = 1, max do
            itemList[root][i] = SubUIManager.Open(SubUIConfig.ItemView, rewardRoot)
            itemList[root][i].gameObject:SetActive(false)
        end
        if type then
            itemList[root][1]:OnOpen(false, {data1,data2},scale,false,false,false,sortingOrder)
            itemList[root][1].gameObject:SetActive(true)
        else
            for i = 1, #data1 do
                itemList[root][i]:OnOpen(false, {data1[i][1],data1[i][2],data1[i][3],data1[i][4]},scale,false,false,false,sortingOrder)
                itemList[root][i]:Reset({data1[i][1],data1[i][2]},ItemType.Hero,{false,true,true,true})
                itemList[root][i].gameObject:SetActive(true)
            end
        end
    end
end

--时间格式转换（只显示月日时分）
function this.TimeStampToDateStr(timestamp)
    local date = os.date("*t", timestamp)
    --local cdate = os.date("*t", GetTimeStamp())
    --if date.year == cdate.year and date.month == cdate.month and date.day == cdate.day then
    --    return string.format("%02d:%02d", date.hour, date.min)
    --end
    return string.format(GetLanguageStrById(10623),date.month, date.day,date.hour, date.min)
    --return string.format("%d年%d月%d日 %02d:%02d", date.year, date.month, date.day, date.hour, date.min)
end

--红点检测
function this.CheckRedPoint()
    local open
    open = this.CheckOnceSea() or this.CheckRewardBtn()
    if this.GetActivityTime() <= 0 then
        open = false
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.FindFairy.RefreshRedPoint)
    return open
end
--检测出海一次的红点
function this.CheckOnceSea()
    local open
    open = this.myScore/10%15 == 0 or PrivilegeManager.GetPrivilegeRemainValue(32) > 0
    return open
end
--检测奖励按钮红点
function this.CheckRewardBtn()
    local open
    local data,num =this.GetBtnDataState(ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy))
    open = num>0
    return open
end
--检测进阶礼的红点
function this.CheckFindFairyUpStarRedPoint()
    --ActivityTypeDef.FindFairyUpStar
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
--检测寻仙盛典的红点
function this.CheckFindFairyCeremonyRedPoint()
    --ActivityTypeDef.FindFairyUpStar
    local activeData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FindFairyCeremony)
    if activeData then
        for i = 1, #activeData.mission do
            local sConFigData = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig, activeData.mission[i].missionId)
            if sConFigData then
                local value = sConFigData.Values[1][1]
                if activeData.mission[i].state == 0 and activeData.value >= value then
                    return true
                end
            end
        end
    end
    return false
end

--获取寻仙天官赐福 and 每日仙缘礼
function this.GetGiftActiveBtnState(DirectBuyTypeVal)
    local RechargeCommodityConfigIds = {}
    local allConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.RechargeCommodityConfig, "ShowType", DirectBuyTypeVal)
    for k,v in pairs(allConfigs) do
        local _data=OperatingManager.GetGiftGoodsInfo(v.Type,v.Id)
        if _data then
            table.insert(RechargeCommodityConfigIds,v.Id)
        end
    end
    return RechargeCommodityConfigIds
end

return this