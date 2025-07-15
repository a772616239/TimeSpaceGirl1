MonsterCampManager = {};
local this = MonsterCampManager
local monsterCampConfig = ConfigManager.GetConfig(ConfigName.FloodConfig)
local monsterGroupConfig = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local monsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local monterViewConfig = ConfigManager.GetConfig(ConfigName.MonsterViewConfig)
local heroViewConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local resConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

function this.Initialize()
    this.monsterWave = 0 -- 当前妖兽波次
    this.m_Jump = false  -- 跳过战斗设置
end

-- 返回5个大虾的信息, 显示怪物的第一个,
function this.GetNextWaveMonsterInfo()
    local curWave = this.monsterWave
    local monsterInfo = {}
    --遇到表格的结尾处，则停止
    for i = curWave + 1, curWave + 5 do
        if not monsterCampConfig[i] then break end
        local data = {}
        data.rewardShow = monsterCampConfig[i].RewardShow
        local monsterGroupId = monsterCampConfig[i].Monster
        -- 默认显示第一只怪
        local id = monsterGroupConfig[monsterGroupId].Contents[1][1]
        local monsterId = monsterConfig[id].MonsterId
        local resId = 0
        if monsterId > 10000 then -- 这是人类
            resId = heroViewConfig[monsterId].Icon
        else -- 这是妖精
            resId = monterViewConfig[monsterId].MonsterIcon
        end

        local resPath = GetResourcePath(resId)
        local icon = Util.LoadSprite(resPath)
        data.icon = icon
        data.name = resConfig[resId].Desc
        monsterInfo[i] = data
    end

    return monsterInfo
end

-- 返回当前怪物阵容信息
function this.GetCurMonsterInfo()
    local curWave = this.monsterWave
    local monsterInfo = {}
    local mainMonsterInfo = {}
    local data = {}
    data.icon = {}
    data.level={}
    data.rewardShow = monsterCampConfig[curWave].RewardShow
    local monsterGroupId = monsterCampConfig[curWave].Monster

    local ids = monsterGroupConfig[monsterGroupId].Contents
    for i = 1, #ids do
        for j = 1, #ids[i] do
            -- 所有怪信息
            local monsterId = monsterConfig[ids[i][j]].MonsterId
            local resId = 0
            if monsterId > 10000 then -- 这是人类
                resId = heroViewConfig[monsterId].Icon
            else -- 这是妖精
                resId = monterViewConfig[monsterId].MonsterIcon
            end

            local resPath = GetResourcePath(resId)
            local icon = Util.LoadSprite(resPath)
            data.icon[#data.icon + 1] = icon
            data.level[j]= monsterConfig[ids[i][j]].Level
            -- 主怪信息
            if i == 1 and j == 1 then
                mainMonsterInfo.name = resConfig[resId].Desc
                mainMonsterInfo.live2dPath = resConfig[resId].Name
                mainMonsterInfo.monsterId = monsterId
            end
        end
    end

    monsterInfo = data
    return monsterInfo, mainMonsterInfo
end

-- 消耗道具上限值
function this.GetMaxCostItem()
    return PrivilegeManager.GetPrivilegeNumber(23)
end

-- 是否需要回复
function this.IsNeedSupply()
    return BagManager.GetItemCountById(53) < this.GetMaxCostItem()
end

--返回当前的怪物组Id
function this.GetCurWaveMonsterGroupId()
    return monsterCampConfig[this.monsterWave].Monster
end

-- 通过怪物ID返回头像
function this.GetIconByMonsterId(monsterId)
    local resId = 0
    local level = 0
    local icon
    local liveId = monsterConfig[monsterId].MonsterId
    if liveId > 10000 then -- 这是人类
        resId = heroViewConfig[liveId].Icon
    else -- 这是妖精
        resId = monterViewConfig[liveId].MonsterIcon
    end
    level = monsterConfig[monsterId].Level
    icon =Util.LoadSprite(GetResourcePath(resId))
   return icon, level
end

-- 获取表的上限值
function this.GetMaxNum()
    local max = 0
    for k, v in ConfigPairs(monsterCampConfig) do
        max = max > k and max or k
    end
    return max
end

-- 跳过战斗设置
function this.GetBattleJump()
    return false
    -- if not this.CheckBattleJump() then
    --     return false
    -- end
    -- return this.m_Jump
end

function this.SetBattleJump(state)
    this.m_Jump = state
end

function this.CheckBattleJump()
    local isOpen = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.MonsterCampJump)
    return isOpen
end


return this