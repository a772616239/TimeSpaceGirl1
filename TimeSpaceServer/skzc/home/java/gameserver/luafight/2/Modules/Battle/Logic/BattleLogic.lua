BattleLogic = {}

local floor = math.floor
local min = math.min
-- local objList = BattleDictionary.New()
local removeObjList = BattleList.New()

local MaxRound = 20
local CurRound = 0
local CurCamp = 0
-- local CurSkillPos = {}
local PosList = {}

local PosIsAttackRecord = {}    --< 记录当前回合是否attack过
local CurPosition = -1          --< 当前位置
local MoveTimes = 0             --< 行动次数

local curFrame

BattleLogic.Type = 0 --1 故事副本 2 地图探索 3 竞技场 4 秘境boss 5 解锁秘境 6 公会战 7 血战 8 兽潮 9巅峰战
BattleLogic.IsEnd = false
BattleLogic.Result = -1
BattleLogic.Event = BattleEvent.New()
BattleLogic.BuffMgr = BuffManager.New()

local _IsDebug

local fightData
local record
local optionRecord

--是否开启战斗日志
BattleLogic.IsOpenBattleRecord = false
--逻辑帧频
BattleLogic.GameFrameRate = 30
BattleLogic.GameDeltaTime = 1 / BattleLogic.GameFrameRate
--总波次
BattleLogic.TotalOrder = 0
--当前波次
BattleLogic.CurOrder = 0

BattleLogic.SingleRoundStatus = {
    RoundBegin = 1,
    RoundEnd = 2,
    Rounding = 3
}


local actionPool = BattleObjectPool.New(function ()
    return { 0, 0 }
end)
local skillPool = BattleObjectPool.New(function ()
    return Skill:New()
end)
local tbActionList = BattleList.New()

local rolePool = BattleObjectPool.New(function ()
    return RoleLogic.New()
end)

function BattleLogic.Init(data, optionData, maxRound)
    if BattleLogic.IsOpenBattleRecord then
        record = {}
    end

    fightData = data
    if optionData then
        optionRecord = optionData
    else
        optionRecord = {}
    end

    BattleLogic.CurOrder = 0
    BattleLogic.TotalOrder = #data.enemyData

    BattleLogic.Clear()

    curFrame = 0

    CurRound = 0
    MaxRound = maxRound or 20

    _IsDebug = false

    BattleLogic.Event:ClearEvent()
    BattleLogic.BuffMgr:Init()
    BattleLogic.IsEnd = false
    BattleLogic.Result = -1

    RoleManager.Init()
    SkillManager.Init()
    OutDataManager.Init(fightData)
    PassiveManager.Init()
    BattleLogManager.Init(fightData)

    PosIsAttackRecord = {}
end

-- 检测先手阵营
function BattleLogic.CheckFirstCamp()
    -- 默认我方先手
    BattleLogic.FirstCamp = 0
    -- 数据不存在时，兼容老战斗数据
    if not fightData.playerData.firstCamp and not fightData.enemyData[BattleLogic.CurOrder].firstCamp then
        return 
    end
    -- 敌方先手
    if fightData.playerData.firstCamp == 0 and fightData.enemyData[BattleLogic.CurOrder].firstCamp == 1 then
        BattleLogic.FirstCamp = 1
    end
end

function BattleLogic.StartOrder()
    --
    BattleLogic.CurOrder = BattleLogic.CurOrder + 1
    if BattleLogic.CurOrder == 1 then
        local playerData = fightData.playerData
        local enemyData = fightData.enemyData[BattleLogic.CurOrder]
        LogYellow("### 数量")
        -- WYLog(#playerData)
        -- WYLog(#enemyData)
        WYLog(#playerData)
        for i=1, #playerData do
            -- WYLog("player" .. tostring(i))
            RoleManager.AddRole(playerData[i], playerData[i].position)
        end
        for i=1, #enemyData do
            RoleManager.AddRole(enemyData[i], enemyData[i].position)
        end


        --> unit
        for _, unitData in pairs(fightData.fightUnitData) do
            FightUnitManager.AddUnit(unitData)
        end
        
    else
        LogYellow("### StartOrder")
        RoleManager.ClearEnemy()
        local orderList = fightData.enemyData[BattleLogic.CurOrder]
        for i=1, #orderList do
            RoleManager.AddRole(orderList[i], orderList[i].position)
        end
        LogYellow("### StartOrder")
        LogYellow(#orderList)
    end
    -- 检测先后手
    BattleLogic.CheckFirstCamp()
    -- 开始战斗,延时一帧执行，避免战斗还没开始就释放了技能
    BattleLogic.TurnRoundNextFrame()

    MoveTimes = 0
end

-- 获取当前轮数
function BattleLogic.GetCurRound()
    -- body
    return CurRound, MaxRound
end

-- 获取当前轮次信息
function BattleLogic.GetCurTurn()
    -- body
    return CurCamp, CurPosition
end

-- 设置是否是debug
function BattleLogic.SetIsDebug(isDebug)
    _IsDebug = isDebug
end
function BattleLogic.GetIsDebug()
    return _IsDebug
end

-- 下一帧开始下一轮
local _TurnRoundFlag = 0
function BattleLogic.TurnRoundNextFrame()
    _TurnRoundFlag = 0
end

-- 检测是否要轮转
function BattleLogic.CheckTurnRound()
    if _TurnRoundFlag == 2 then
        return 
    end
    _TurnRoundFlag = _TurnRoundFlag + 1
    if _TurnRoundFlag == 2 then
        if BattleLogic.CheckSingleRoundStatus() == BattleLogic.SingleRoundStatus.RoundBegin then
            CurRound = CurRound + 1
            BattleLogic.RoundBegin(function()
                BattleLogic.TurnRound()
            end)
        elseif BattleLogic.CheckSingleRoundStatus() == BattleLogic.SingleRoundStatus.RoundEnd then
            BattleLogic.RoundEnd(function()
                BattleLogic.TurnRoundNextFrame()
            end)
        else
            BattleLogic.TurnRound()
        end
    end
end

--> 检测单回合首末 返回两种状态
function BattleLogic.CheckSingleRoundStatus()
    local isHave = false
    local nullNum = 0
    for pos = 1, 18 do
        while true 
        do
            if PosIsAttackRecord[pos] then
                break
            else
                nullNum = nullNum + 1
            end
            local role = RoleManager.GetRoleByPos(pos)
            if role and not role:IsRealDead() then
                isHave = true
            end

            break
        end
    end
    if nullNum == 18 then
        return BattleLogic.SingleRoundStatus.RoundBegin
    else
        if isHave then
        else
            return BattleLogic.SingleRoundStatus.RoundEnd
        end
    end
    return BattleLogic.SingleRoundStatus.Rounding
end

--> 单回合开始
function BattleLogic.RoundBegin(func)
    LogGreen(Language[10228]..CurRound)
    WYLog("### RoundBegin")
    BattleLogManager.Log(
        "Round Change",
        "round", CurRound
    )
    -- 轮数变化
    BattleLogic.Event:DispatchEvent(BattleEventName.BattleRoundChange, CurRound)

    BattleLogic.BuffMgr:TurnUpdate(1) -- 计算恢复血量
    BattleLogic.BuffMgr:TurnUpdate(2) -- 计算持续伤害（除去流血）
    BattleLogic.BuffMgr:TurnUpdate(3) -- 计算持续伤害（流血）
    BattleLogic.BuffMgr:TurnUpdate(4) -- 计算其他buff
    BattleLogic.BuffMgr:PassUpdate()  -- 计算buff轮数

    local processQueue = {{FightUnitType.UnitSupport, 0}, {FightUnitType.UnitSupport, 1}}

    local index = 1
    local next = nil
    local processFunc = nil
    next = function()
        if index == #processQueue then
            func()
        else
            index = index + 1
            processFunc()
        end
    end
    
    processFunc = function()
        local unit = FightUnitManager.GetUnit(processQueue[index][1], processQueue[index][2])
        if unit then
            local haveSkill = unit:CastSkill(function()
                next()
            end)
            if not haveSkill then
                next()
            end
        else
            next()
        end
    end
    processFunc()
    

    


    -- local unit = FightUnitManager.GetUnit(FightUnitType.UnitSupport, 0)
    -- if unit then
    --     local haveSkill = unit:CastSkill(function()
    --         func()
    --     end)
    --     if not haveSkill then
    --         func()
    --     end
    -- else
    --     func()
    -- end
    -- func()
    -- WYLog("RoundBegin延时触发继续")
    -- BattleLogic.WaitForTrigger(5, function() 
    --     func()
    -- end)
    
end
--> 单回合结束
function BattleLogic.RoundEnd(func)
    WYLog("### RoundEnd")
    PosIsAttackRecord = {}

    WYLog("RoundEnd延时触发继续")
    BattleLogic.WaitForTrigger(2, function()
        func()
    end)
    
end

-- 开始轮转
-- debugTurn  用于判断是否是debug轮转的参数
function BattleLogic.TurnRound(debugTurn)
    if BattleLogic.GetIsDebug() and not debugTurn then
        LogGreen(Language[10227])
        LogBlue("-------------")
        BattleLogic.Event:DispatchEvent(BattleEventName.DebugStop)
        return 
    end
    LogYellow("BattleLogic.TurnRound")
    --> 计算速度最大的执行技能
    local maxSpeed = -1
    local maxSpeedPos = -1
    local SkillRole = nil
    for pos = 1, 18 do
        while true 
        do
            if PosIsAttackRecord[pos] then
                break
            end
            local role = RoleManager.GetRoleByPos(pos)
            if role and not role:IsRealDead() then
                local speed = role:GetRoleData(RoleDataName.Speed)
                if speed > maxSpeed then
                    maxSpeed = speed
                    maxSpeedPos = pos
                    SkillRole = role
                end
            end

            break
        end
    end
    local isFindRole = false
    if maxSpeedPos ~= -1 then
        PosIsAttackRecord[maxSpeedPos] = true
        isFindRole = true
    end

    if not isFindRole then
        LogYellow("Not Find Role")
        BattleLogic.TurnRoundNextFrame()
    end

    --> 首回合 or 回合更新
    -- if CurRound == 0 or not isFindRole then
    --     CurRound = CurRound + 1
    --     LogGreen(Language[10228]..CurRound)
    --     BattleLogManager.Log(
    --         "Round Change",
    --         "round", CurRound
    --     )
    --     -- 轮数变化
    --     BattleLogic.Event:DispatchEvent(BattleEventName.BattleRoundChange, CurRound)

    --     BattleLogic.BuffMgr:TurnUpdate(1) -- 计算恢复血量
    --     BattleLogic.BuffMgr:TurnUpdate(2) -- 计算持续伤害（除去流血）
    --     BattleLogic.BuffMgr:TurnUpdate(3) -- 计算持续伤害（流血）
    --     BattleLogic.BuffMgr:TurnUpdate(4) -- 计算其他buff
    --     BattleLogic.BuffMgr:PassUpdate()  -- 计算buff轮数


    --     if not isFindRole then
    --         PosIsAttackRecord = {}
    --         BattleLogic.TurnRoundNextFrame()
    --         return
    --     end

    -- else
    --     -- 切换阵营
    --     --CurCamp = (CurCamp + 1) % 2
    -- end

    CurCamp = SkillRole.camp
    CurPosition = SkillRole.position
    BattleLogManager.Log(
        "Position Change",
        "camp", CurCamp,
        "position", CurPosition
    )

    -- LogGreen(Language[10229]..CurCamp)
    -- -- 
    -- BattleLogManager.Log(
    --     "Camp Change",
    --     "camp", CurCamp
    -- )


    

    -- -- 当前阵营下一释放技能的位置
    -- local cpos = CurSkillPos[CurCamp] + 1
    -- -- 找到下一个释放技能的人
    -- local SkillRole
    -- for p = cpos, 9 do
    --     -- 保存当前位置
    --     CurSkillPos[CurCamp] = p
    --     -- 自己阵营中的位置 + 自己阵营的ID * 9 = 自己在PosList中的位置
    --     local role = RoleManager.GetRole(CurCamp, p) --PosList[p + (CurCamp * 9)]
    --     if role and not role:IsRealDead() then
    --         SkillRole = role
    --         break
    --     end

    --     -- 如果当前位置不能释放技能也需要走buff轮转
    --     BattleLogic.BuffMgr:TurnUpdate(1) -- 计算恢复血量
    --     BattleLogic.BuffMgr:TurnUpdate(2) -- 计算持续伤害（除去流血）
    --     BattleLogic.BuffMgr:TurnUpdate(3) -- 计算持续伤害（流血）
    --     BattleLogic.BuffMgr:TurnUpdate(4) -- 计算其他buff
    --     BattleLogic.BuffMgr:PassUpdate()  -- 计算buff轮数
    -- end
    -- 如果找不到下一个人，直接交换阵营
    -- if not SkillRole then
    --     LogGreen(Language[10230])
    --     BattleLogManager.Log( "No Skill Position" )
    --     BattleLogic.TurnRoundNextFrame()
    --     return
    -- end

    -- LogGreen(Language[10231]..CurSkillPos[CurCamp])
    -- -- 
    -- BattleLogManager.Log(
    --     "Position Change",
    --     "position", CurSkillPos[CurCamp]
    -- )

    -- buff计算
    -- BattleLogic.BuffMgr:TurnUpdate(1) -- 计算恢复血量
    -- BattleLogic.BuffMgr:TurnUpdate(2) -- 计算持续伤害（除去流血）

    -- 如果角色无法释放技能
    if not SkillRole:IsAvailable()  -- 角色不能释放技能
        or (SkillRole:IsDead() and not BattleLogic.BuffMgr:HasBuff(SkillRole,BuffName.NoDead))  --将死但没有不死buff 
    then
        -- BattleLogic.BuffMgr:TurnUpdate(3) -- 计算持续伤害（流血）
        -- BattleLogic.BuffMgr:TurnUpdate(4) -- 计算其他buff
        -- BattleLogic.BuffMgr:PassUpdate()  -- 计算buff轮数
        BattleLogic.TurnRoundNextFrame()  -- 下一个
        return 
    end

    -- 行动
    SkillRole.Event:DispatchEvent(BattleEventName.RoleTurnStart, SkillRole)    -- 开始行动
    BattleLogic.Event:DispatchEvent(BattleEventName.RoleTurnStart, SkillRole)    -- 开始行动
    -- BattleLogic.BuffMgr:TurnUpdate(1) -- 计算恢复血量
    -- BattleLogic.BuffMgr:TurnUpdate(2) -- 计算持续伤害（除去流血）
    -- 释放技能后，递归交换阵营
    MoveTimes = MoveTimes + 1
    local haveSkill = SkillRole:CastSkill(function()
        -- BattleLogic.BuffMgr:TurnUpdate(3) -- 计算持续伤害（流血）
        -- BattleLogic.BuffMgr:TurnUpdate(4) -- 计算其他buff
        -- BattleLogic.BuffMgr:PassUpdate()  -- 计算buff轮数
        SkillRole.Event:DispatchEvent(BattleEventName.RoleTurnEnd, SkillRole)  -- 行动结束
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleTurnEnd, SkillRole)    -- 开始行动
        BattleLogic.TurnRoundNextFrame()
    end)

    --> 无技能时 跳过死循环问题
    if not haveSkill then
        BattleLogic.TurnRoundNextFrame()
    end
end


function BattleLogic.WaitForTrigger(delayTime, action)
    delayTime = BattleUtil.ErrorCorrection(delayTime)
    local delayFrame = floor(delayTime * BattleLogic.GameFrameRate + 0.5)
    if delayFrame == 0 then --0延迟的回调直接调用
        action()
        return
    end
    local item = actionPool:Get()
    item[1] = curFrame + delayFrame
    item[2] = action
    tbActionList:Add(item)
end


function BattleLogic.CurFrame()
    return curFrame
end

function BattleLogic.Update()
    curFrame = curFrame + 1
    -- WYLog(curFrame)
    local roleResult = RoleManager.GetResult()
    if roleResult == 0 then
        BattleLogic.BattleEnd(0)
        return
    end
    if CurRound > MaxRound then
        BattleLogic.BattleEnd(0)
        return
    end
    if roleResult == 1 then
        if BattleLogic.CurOrder == BattleLogic.TotalOrder then
            BattleLogic.BattleEnd(1)
        else
            BattleLogic.Event:DispatchEvent(BattleEventName.BattleOrderChange, BattleLogic.CurOrder + 1)
            LogYellow("Update StartOrder")
            BattleLogic.StartOrder()
        end
    end

    -- 检测帧事件（技能命中，伤害计算，buff生成）
    local index = 1
    while index <= tbActionList.size do
        local action = tbActionList.buffer[index]
        if action[1] <= curFrame then
            action[2]()
            actionPool:Put(action)
            tbActionList:Remove(index)
        else
            index = index + 1
        end
    end
    -- 检测buff
    BattleLogic.BuffMgr:Update()
    --- 
    -- 检测角色状态
    RoleManager.Update()

    -- 检测死亡
    if RoleManager.CheckDead() then -- 单独用一帧执行死亡
        return 
    end
    -- 检测复活
    if RoleManager.CheckRelive() then -- 单独用一帧执行复活
        return 
    end

    -- 检测技能释放
    -- 检测轮转
    BattleLogic.CheckTurnRound()
    -- 技能
    SkillManager.Update()

end

function BattleLogic.GetMoveTimes()
    return MoveTimes
end

-- 战斗结束
function BattleLogic.BattleEnd(result)
    -- 
    LogYellow("### 战斗 逻辑结束")
    WYLog(result)
    BattleLogic.Event:DispatchEvent(BattleEventName.BeforeBattleEnd, result)
    -- 
    BattleLogic.IsEnd = true
    BattleLogic.Result = result
    BattleLogic.Event:DispatchEvent(BattleEventName.BattleEnd, result)
    -- 战斗日志写入
    if not BattleLogic.GetIsDebug() then
        BattleLogManager.WriteFile()
    end
end
-- 
function BattleLogic.Clear()
    -- 清空角色
    RoleManager.Clear()
    -- 清空事件
    while tbActionList.size > 0 do
        actionPool:Put(tbActionList.buffer[tbActionList.size])
        tbActionList:Remove(tbActionList.size)
    end
end   