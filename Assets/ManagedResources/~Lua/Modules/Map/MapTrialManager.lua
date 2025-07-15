MapTrialManager = {};
local this = MapTrialManager
local trailSetting = ConfigManager.GetConfig(ConfigName.TrialSetting)
local trailConfig = ConfigManager.GetConfig(ConfigName.TrialConfig)
local trialKillConfig = ConfigManager.GetConfig(ConfigName.TrialKillConfig)
function this.Initialize()
    this.resetLevel = 0 -- 重置到的层数
    this.resetCount = 0 -- 已经重置的次数
    this.bossType = 0 -- 召唤的boss 类型
    this.bossId = 0 -- 召唤的boss怪物ID
    this.highestLevel = 0 -- 历史最高层
    this.doneTime = 0   -- 完成当前层数所用的时间
    this.curTowerLevel = 0 -- 当前所在层数
    this.fightCount = 0 -- 已战斗次数
    this.towerShopInfos ={} -- 爬塔副本商店信息
    this.powerValue = 0 -- 精气值
    this.canCallBoss = false -- 是否可以召唤地图首领
    this.isHaveBoss = false -- 是否Boss已经召唤出来
    this.trailBufferInfo = {} -- 试炼副本Buff数信息, 进图的时候赋值
    this.isCanReset = 0
    this.bossDeadTime = 0 -- 完成最后一层的时间
    this.leftLife = 0 -- 剩余复活次数
    this.rolePos = Vector2.zero
    this.canMove = true -- 服务器返回精气值100时不可寻路
    this.isChangeLevel = false -- 换层时不可寻路
    -- this.gotRewardLevel = {} -- 已经领取奖励的层数
    this.firstEnter = false -- 试炼副本重置后进图
    this.selectHeroDid = "" --已选择英雄的动态id
    this.cell = nil --传送门位置
    -- this.isFirstIn = false --是否第一次进入副本 退出副本时置为false
    this.trialRewardInfo = {} --试炼领奖信息
    this.killCount = 0 --已击杀小怪数量
    this.bombUsed = 0 --炸弹已使用次数
end

function this.RefreshTrialInfo(towerCopyInfo)
    --试炼副本数据初始化
    this.curTowerLevel = towerCopyInfo.tower
    this.highestLevel = towerCopyInfo.highestTower
    this.resetCount = PrivilegeManager.GetPrivilegeRemainValue(17)
    this.fightCount = towerCopyInfo.towerCopyInfo
    this.powerValue = towerCopyInfo.essenceValue
    this.isCanReset = towerCopyInfo.mapIntoReset
    this.doneTime = towerCopyInfo.towerUseTime
    -- this.trialRewardInfo = towerCopyInfo.trialRewardInfo
    this.InitTrialRewardData(towerCopyInfo.trialRewardInfo)
    this.killCount = towerCopyInfo.killCount
    this.bombUsed = towerCopyInfo.bombUsed

    -- 最后一层需要赋值
    this.bossDeadTime = towerCopyInfo.towerUseTime
    this.SetBossState(this.powerValue)
end

--  取得最初的服务器精气值
function this.UpdatePowerValue(value)
    this.powerValue = value
    Game.GlobalEvent:DispatchEvent(GameEvent.TrialMap.OnPowerValueChanged)
end

-- 设置标志位
function this.SetBossState(value)
    if value < 0 then
        this.isHaveBoss = true
    else
        this.isHaveBoss = false
    end
    this.canCallBoss = value >= 100
end

-- 进入下一层
function this.GoNextLevel()
    -- local curMapId = trailConfig[MapTrialManager.curTowerLevel + 1].MapId
    this.isChangeLevel = true
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out, 2)
    MapTrialManager.isHaveBoss = false
    this.bossType = 0
end

-- 是否是试炼副本的最后一层(没有最后一层了，判断是否是问号层)
function this.IsFinalLevel()
    local isFinalLevel = false
    if MapTrialManager.curTowerLevel > 10000 then
        MapTrialManager.curTowerLevel = MapTrialManager.curTowerLevel - 10000
    end
    if CarbonManager.difficulty == 2 then
        local curMapData = trailConfig[MapTrialManager.curTowerLevel + 1]
        if not curMapData or curMapData.MapId == 0 then
            isFinalLevel = true
        end
    end
    return isFinalLevel
end

function this.GoSurprisedLevel()
    -- local mapId = this.GetSurprisedLevelMapId()
    this.isChangeLevel = true
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out,2)
    MapTrialManager.isHaveBoss = false
    this.bossType = 0
end

-- 获取惊喜层地图id
function this.GetSurprisedLevelMapId()
    if MapTrialManager.curTowerLevel < 10000 then
        MapTrialManager.curTowerLevel = MapTrialManager.curTowerLevel + 10000
    end
    local mId = 0
    for mapId, _ in ConfigPairs(trailConfig) do
        if mapId >= MapTrialManager.curTowerLevel then
            mId = mapId
            break
        end
    end
    return trailConfig[mId].MapId
end


-- 设置补给点数据
function this.SetBuffList(buffs)
    this.trailBufferInfo = {}
    for _, buff in ipairs(buffs) do
        table.insert(this.trailBufferInfo, buff)
    end
    table.sort(this.trailBufferInfo, function (a, b)
        return a.towerLevel < b.towerLevel
    end)
    return this.trailBufferInfo
end

-- 获取buff列表
function this.GetBuffList()
    return this.trailBufferInfo
end

-- 删除某补给点
function this.RemoveBuff(level, eventId)
    local removeIndex
    for index, buff in ipairs(this.trailBufferInfo) do
        if buff.towerLevel == level and buff.eventId == eventId then
            removeIndex = index
        end
    end
    if removeIndex then
        table.remove(this.trailBufferInfo, removeIndex)
    end
end

function this.SetRolePos(u, v)
    local pos = Map_UV2Pos(u, v)
    --local v2 = RectTransformUtility.WorldToScreenPoint(TileMapView.GetCamera(), TileMapView.GetLiveTilePos(u, v))
    --v2 = v2 / math.min(Screen.width/1080, Screen.height/1920)
    --v2.x = Screen.width/1080 > 1 and v2.x - 180 or v2.x
    this.rolePos = SetObjPosByUV(pos)

end

------ 试练副本奖励相关 ------
-- 登录时试炼副本的奖励领取数据
function this.InitTrialRewardData(gotLevelData)
    this.trialRewardInfo = {}
    if gotLevelData and #gotLevelData > 0 then
        for i = 1, #gotLevelData do

            this.trialRewardInfo[gotLevelData[i]] = gotLevelData[i]
        end
    end
end

-- 获取试练奖励领取状态
-- 0 已经领取，1 可领取，2不能领取·
function this.GetTrialRewardState(id)
    if LengthOfTable(this.trialRewardInfo) > 0 then --若存在数据 说明已领取
        for i, v in pairs(this.trialRewardInfo) do
            if id == v then
                return 0
            end
        end
    end
    if this.killCount < trialKillConfig[id].Count then
        return 2
    elseif this.killCount >= trialKillConfig[id].Count then
        return 1
    end
end

--任务红点检测
function this.TrialRewardRedPointCheck()
    local d = {}
    for _, configInfo in ConfigPairs(trialKillConfig) do
        table.insert(d, configInfo)
    end
    for i = 1, #d do
        local state = MapTrialManager.GetTrialRewardState(d[i].Id)
        if state == 1 then
            return true
        end
    end
    return false
end

--设置试练奖励信息
function this.SetTrialRewardInfo(v)
    table.insert(this.trialRewardInfo,v)
end

--获取试练奖励信息
function this.GetTrialRewardInfo()
    return this.trialRewardInfo
end

--重置清空奖励信息
function this.ClearTrialRewardInfo()
    this.trialRewardInfo = {}
end

--设置试练已杀小怪数量
function this.SetKillCount(v)
    CheckRedPointStatus(RedPointType.TrialReward)
    CheckRedPointStatus(RedPointType.Trial)
    this.killCount = v
end

--获取已杀小怪数量
function this.GetKilCount()
    return this.killCount
end

-- 获得试炼副本的层数奖励数据
function this.GetLevelReward()
    local dataList = {}
    -- 遍历这个表看看
    for i, v in ConfigPairs(trailConfig) do
        local rewardData = v.FloorReward
        if rewardData and rewardData[1][1] > 0 then
            local info = {}
            info.rewardInfo = v
            info.state = this.GetTrialRewardState(v.Id)
            dataList[#dataList + 1] = info
        end
    end

    if #dataList > 1 then
        -- 数据大于1时重新排序
        table.sort(dataList, function(a, b)
            if a.state == 0 and b.state ~= 0 then
                return false
            end
            if a.state ~= 0 and b.state == 0 then
                return true
            end

            if a.state ~= b.state then
                return a.state < b.state
            else
                return a.rewardInfo.Id < b.rewardInfo.Id
            end
        end)
    end

    return dataList
end

--Vip等级提升时刷新数据,5点时刷新数据
function this.RefreshAttachVipData()
    this.resetCount = PrivilegeManager.GetPrivilegeRemainValue(trailSetting[1].DailyReset)
    Game.GlobalEvent:DispatchEvent(GameEvent.Carbon.RefreshCarbonData)
end

--设置英雄血量数据 data剩余血量;did 选中英雄的did
function this.SetHeroHp(data, did, func)
    for i, v in ipairs(MapManager.trialHeroInfo) do
        if v.heroId == did then
            v.heroHp = data[1]
        end
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.RefreshHeroHp,false,nil,true)--第二个false 已经进入副本了 不需要设置选择第一个Hero
    if func then func() end
end

function this.TrialRedCheck()
    local var = PlayerPrefs.GetInt(PlayerManager.uid.."Trial")
    if var == 0 and ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.TRIAL) then
        return true
    end
    return MapTrialManager.TrialRewardRedPointCheck()
end

-- 获取击杀表
function MapTrialManager.GetKillConfig()
    local a = {}
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.TrialKillConfig)) do
        table.insert(a, configInfo)
    end
    table.sort(a, function(a, b)
        return a.Count < b.Count
    end)

    return a
end

return this