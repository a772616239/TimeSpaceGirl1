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

local PosIsAirManAttack={}      --< 记录当前回合主角是否attack过
local PosIsAttackRecord = {}    --< 记录当前回合角色是否attack过
local CurPosition = -1          --< 当前位置
local MoveTimes = 0             --< 行动次数

local curFrame

local IsHaveTibu=false -- todo yh 是否已经上阵替补


BattleLogic.Type = 0 --1 故事副本 2 地图探索 3 竞技场 4 秘境boss 5 解锁秘境 6 公会战 7 血战 8 兽潮 9巅峰战
BattleLogic.IsEnd = false
BattleLogic.Result = -1
BattleLogic.Event = BattleEvent.New()
BattleLogic.BuffMgr = BuffManager.New()
BattleLogic.useTimes = 0    --< 每场战斗总共回合数
BattleLogic.RoundRandom = 0 --每回合随机值
BattleLogic.IsFetchedResult = false -- 询问战斗结果

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

-- 下一帧开始下一轮
local _TurnRoundFlag = 0

--> 暂停需要 隔帧执行技能 因技能中用到暂停
local _ProcessSkillFlag = 2


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

local function tablekIn(tbl, key)
    if tbl == nil then
        return false
    end
    for k, v in pairs(tbl) do
        if k == key then
            return true
        end
    end
    return false
end

local delayRoundTrip = {}

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
    BattleLogic.IsFetchedResult = false
    BattleLogic.Clear()

    curFrame = 0
    
    CurRound = 0
    MaxRound = maxRound or 20
    _TurnRoundFlag = 0
    _ProcessSkillFlag = 2

    _IsDebug = false

    BattleLogic.Event:ClearEvent()
    BattleLogic.BuffMgr:Init()
    BattleLogic.IsEnd = false
    BattleLogic.Result = -1
    BattleLogic.useTimes = 0    

    -- 数据初始化
    RoleManager.Init()
    SkillManager.Init()
    OutDataManager.Init(fightData)
    PassiveManager.Init()
    BattleLogManager.Init(fightData)
    FightUnitManager.Init()

    PosIsAttackRecord = {}
    PosIsAirManAttack = {}
    delayRoundTrip = {}
end

-- 检测先手阵营
function BattleLogic.CheckFirstCamp()
    -- 默认先手
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

-- to do check yh 检测加入节点测试数据 
function BattleLogic.StartOrder()
    BattleLogic.CurOrder = BattleLogic.CurOrder + 1
    if BattleLogic.CurOrder == 1 then
        local playerData = fightData.playerData
        local enemyData = fightData.enemyData[BattleLogic.CurOrder]

        for i = 1, #playerData do
            RoleManager.AddRole(playerData[i], playerData[i].position)
        end

        if #enemyData > 0 then
            for i = 1, #enemyData do
                RoleManager.AddRole(enemyData[i], enemyData[i].position)
            end
        end

        --> unit
        for _, unitData in pairs(fightData.fightUnitData) do
            if unitData and next(unitData) ~= nil then --< 防服务器值错误问题                
                FightUnitManager.AddUnit(unitData)
            end
        end

        --主角数据
        if fightData.leaderData ~= nil and #fightData.leaderData > 0 then
            if fightData.leaderData[1] ~= nil then
                fightData.leaderData[1].leader = true
                RoleManager.AddRole(fightData.leaderData[1], 99)
            end
            if fightData.leaderData[2] ~= nil then
                fightData.leaderData[2].leader = true
                RoleManager.AddRole(fightData.leaderData[2], 99)
            end
        end
    else
        RoleManager.ClearEnemy()
            -- to do check yh 模拟参数        
        local orderList = fightData.enemyData[BattleLogic.CurOrder]
        if orderList ~= nil then
            for i = 1, #orderList do
                RoleManager.AddRole(orderList[i], orderList[i].position)
            end
        end
    end

    if fightData.tibuData ~= nil and #fightData.tibuData > 0 then
        for _,tibuData in pairs(fightData.tibuData) do
        --获取当前在场英雄释放替补被动技能
            if tibuData ~= nil then
                RoleManager.InitTibuData(tibuData, -1, false)  -- 默认无位置信息 -1
                -- if tibuData.passivity~= nil then
                --    RoleManager.TriggerMyTeamOneAlivePassivity(tibuData.passivity)  -- 修改被动生效地点
                -- end
            end     
        end
    end

    -- RoleManager.printEveryOneDate(nil)
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

function BattleLogic.TurnRoundNextFrame()
    _TurnRoundFlag = 0
end

function BattleLogic.UnRegisterDelayRroundTrigger(_func,_camp)   
    if #delayRoundTrip > 0 then
        for round,campfunc in pairs(delayRoundTrip) do
            if campfunc._camp == _camp then
                if _camp == 0 and _func == campfunc._mfunc then campfunc._mfunc = nil end
                if _camp == 1 and _func == campfunc._efunc then campfunc._efunc = nil end
            end
        end
    end
end

--根据回合数触发的定时器
function BattleLogic.RegisterDelayRroundTrigger(delayRound,func,camp)   
    local delay = CurRound+delayRound
    RoleManager.Log("...................... RegisterDelayRroundTrigger "..delay.." CurCamp "..camp)
    if delayRound ~= 0 and func ~= nil and delay <= MaxRound then
        local cafunc --缓存已注册方法
        if camp == 0 then  
            if tablekIn(delayRoundTrip,delay) then
                -- if delayRoundTrip[delay]._efunc ~= nil then
                    cafunc = delayRoundTrip[delay]._efunc
                    RoleManager.Log("已注册敌方方法")
                -- end
            end
           RoleManager.Log(".......my RegisterDelayRroundTrigger "..delay.." CurCamp "..camp)
            delayRoundTrip[delay] = {
                _mfunc = func,
                _efunc = cafunc,
                _camp = camp
            }
        elseif camp == 1 then
            if tablekIn(delayRoundTrip,delay) then
                -- if delayRoundTrip[delay]._mfunc ~= nil then
                     cafunc = delayRoundTrip[delay]._mfunc
                     RoleManager.Log("已注册我方法")
                -- end
            end

        --    RoleManager.Log(".......enemy RegisterDelayRroundTrigger "..delay.." CurCamp "..camp)
            delayRoundTrip[delay]={ 
                _mfunc=cafunc,
                _efunc=func,
                _camp=camp
            }
        end
    end
end

function BattleLogic.TriggerDelay(_curCamp)
   RoleManager.Log("~~~~~~~~~~~~~~~~~ trigger CurRound "..CurRound.." CurCamp ".._curCamp)
    if delayRoundTrip==nil then
        return
    end

    for round , campfunc in pairs(delayRoundTrip) do
        if CurRound == round then --需要检验当前回合的我方还是敌方 and _curCamp==campfunc._camp 
           RoleManager.Log("............................2.2 trigger CurRound "..CurRound.." CurCamp "..CurCamp)
            if campfunc._mfunc ~= nil then
                campfunc._mfunc(0)
                BattleLogic.TurnRoundNextFrame()
                delayRoundTrip[round]._mfunc = nil
               RoleManager.Log("............................3 .MY")
            elseif campfunc._efunc ~= nil then
                campfunc._efunc(1)
                BattleLogic.TurnRoundNextFrame()
                delayRoundTrip[round]._efunc=nil
               RoleManager.Log("............................3 .ENEMY")
            end
        end
    end  
end

-- 检测是否要轮转 todo check yh
function BattleLogic.CheckTurnRound()
    if _TurnRoundFlag == 2 then
        return
    end
    _TurnRoundFlag = _TurnRoundFlag + 1
    if _TurnRoundFlag == 2 then                    
        if BattleLogic.CheckSingleRoundStatus() == BattleLogic.SingleRoundStatus.RoundBegin then
            CurRound = CurRound + 1
            RoleManager.printEveryOneDate(nil)

            BattleLogic.RoundBegin(function()
                -- BattleLogic.TurnRound()
                    -- 检测是否存在替补                             
                BattleLogic.ProcessSkillNextFrame()
            end)
        elseif BattleLogic.CheckSingleRoundStatus() == BattleLogic.SingleRoundStatus.RoundEnd then
            BattleLogic.RoundEnd(function()
                BattleLogic.TurnRoundNextFrame()
            end)
        else
            -- BattleLogic.TurnRound()
            BattleLogic.ProcessSkillNextFrame()
        end
    end
end

function BattleLogic.ProcessSkillNextFrame()
    _ProcessSkillFlag = 0
end

function BattleLogic.CheckProcessSkill()
    if _ProcessSkillFlag == 2 then
        return
    end
    _ProcessSkillFlag = _ProcessSkillFlag + 1
    if _ProcessSkillFlag == 2 then
        BattleLogic.TurnRound()
    end
end


--是否可以进入主角的轮次
function BattleLogic.IsAirManAttack(camp)
    local role = RoleManager.GetAirRole(camp) 
    if role ~= nil then
        if PosIsAirManAttack[camp] then
            -- LogError("camp true"..camp)            
            return true
        else
            -- LogError("camp false"..camp)
            if not role:LeaderCanCastSkilll() then
                return true
            else                
                return false
            end
        end
    else
        return true
    end
end

function BattleLogic.SetAirManAttack(camp,state)
    if RoleManager.GetAirRole(camp) ~= nil then
        PosIsAirManAttack[camp] = state
    else
        PosIsAirManAttack[camp] = true
    end
end

--> 检测单回合首末 返回两种状态  --to do check yh
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

    if not BattleLogic.IsAirManAttack(0) or not BattleLogic.IsAirManAttack(1) then         
        isHave = true
        -- if nullNum == 18  then nullNum = 17 end
    end

    local function ReCheckRound(_isHave,_nullNum)
         if _isHave then isHave=_isHave end
         if _nullNum then nullNum = _nullNum end
    end

    BattleLogic.Event:DispatchEvent(BattleEventName.BattleRoundCheck, isHave,nullNum,ReCheckRound)

    if nullNum == 18 then
        BattleLogic.Event:DispatchEvent(BattleEventName.RoundBegin, isHave,nullNum,ReCheckRound)
        return BattleLogic.SingleRoundStatus.RoundBegin
    else
        if isHave then
        else
            BattleLogic.Event:DispatchEvent(BattleEventName.RoundEnd, isHave,nullNum,ReCheckRound)
            return BattleLogic.SingleRoundStatus.RoundEnd
        end
    end
    BattleLogic.Event:DispatchEvent(BattleEventName.Rounding, isHave,nullNum,ReCheckRound)
    return BattleLogic.SingleRoundStatus.Rounding
end

function BattleLogic.RoundTibuBegin(func)
    if BattleLogic.CurOrder ~= 0 then
        BattleLogic.Event:DispatchEvent(BattleEventName.BattleTibuRoundBegin, RoleManager.getTibuState())

        
        BattleLogic.TriggerDelay((CurCamp+1)%2) -- 回合开始 当前储存是上回合结束数据未刷新
        BattleLogic.TriggerDelay((CurCamp)%2) -- 回合开始 当前储存是上回合结束数据未刷新


        if RoleManager.IsRoleTibuAdding(0) then
            RoleManager.setTibuPos(RoleManager.IsMyOneDeadPosCanNotRelive(0),0)
            RoleManager.AddTibuToWaitingState(0)
            BattleLogic.RegisterDelayRroundTrigger(1,RoleManager.AddTibu,0)
        else
            BattleLogic.CheckAndAddTibuToWaiting(0)

            BattleLogic.CheckAndAddTibuAtBeginRound(0)
        end

        ---------敌人  镜像逻辑 ---------
        if RoleManager.IsRoleTibuAdding(1) then
            RoleManager.setTibuPos(RoleManager.IsMyOneDeadPosCanNotRelive(1),1)
            RoleManager.AddTibuToWaitingState(1)          
            BattleLogic.RegisterDelayRroundTrigger(1,RoleManager.AddTibu,1)
        else
            BattleLogic.CheckAndAddTibuToWaiting(1)

            BattleLogic.CheckAndAddTibuAtBeginRound(1)
        end
        ---------敌人  镜像逻辑 ---------

        ---------满场状态重置---------
        BattleLogic.CheckAndAddTibuToOnStage(0)
        BattleLogic.CheckAndAddTibuToOnStage(1)
         ---------满场状态重置---------

         BattleLogic.TriggerDelay((CurCamp+1)%2) -- 回合开始 当前储存是上回合结束数据未刷新
         BattleLogic.TriggerDelay((CurCamp)%2) -- 回合开始 当前储存是上回合结束数据未刷新
         
        BattleLogic.Event:DispatchEvent(BattleEventName.BattleTibuRoundEnd, RoleManager.getTibuState())       
        if func then func() end
    end
end

function BattleLogic.RoundTibuEnd(func)
    if BattleLogic.CurOrder ~= 0 then
        RoleManager.getTibuState()    
        
        local function OnlyRegister(camp)
            BattleLogic.RegisterDelayRroundTrigger(1,RoleManager.AddTibu,camp) 
        end

        if RoleManager.IsRoleTibuAdding(0) then
            RoleManager.setTibuPos(RoleManager.IsMyOneDeadPosCanNotRelive(0),0)
            RoleManager.AddTibuToWaitingState(0)
            BattleLogic.RegisterDelayRroundTrigger(1,RoleManager.AddTibu,0)
        else

            BattleLogic.CheckAndAddTibuToWaiting(0,OnlyRegister)

            BattleLogic.CheckAndAddTibuAtBeginRound(0,OnlyRegister)
        end

        ---------敌人  镜像逻辑 ---------
        if RoleManager.IsRoleTibuAdding(1) then
            RoleManager.setTibuPos(RoleManager.IsMyOneDeadPosCanNotRelive(1),1)
            RoleManager.AddTibuToWaitingState(1)          
            BattleLogic.RegisterDelayRroundTrigger(1,RoleManager.AddTibu,1)
        else
            BattleLogic.CheckAndAddTibuToWaiting(1,OnlyRegister)

            BattleLogic.CheckAndAddTibuAtBeginRound(1,OnlyRegister)
        end
        ---------敌人  镜像逻辑 ---------

        ---------满场状态重置---------
        BattleLogic.CheckAndAddTibuToOnStage(0,OnlyRegister)
        BattleLogic.CheckAndAddTibuToOnStage(1,OnlyRegister)
         ---------满场状态重置---------  

        BattleLogic.Event:DispatchEvent(BattleEventName.RoundTibuEnd, RoleManager.getTibuState())

        if func then func() end
    end
end

--> 单回合开始
function BattleLogic.RoundBegin(func) 

    BattleLogic.RoundRandom = Random.Range01()

    BattleLogic.RoundTibuBegin(function()
        -- BattleLogManager.Log(
        --     "Round Tibu Begin",
        --     "round", CurRound
        -- )
    end)
    
    -- 轮数变化
    BattleLogic.Event:DispatchEvent(BattleEventName.BattleRoundChange, CurRound)

    BattleLogic.useTimes = CurRound

    BattleLogic.BuffMgr:TurnUpdate(1) -- 计算恢复血量
    BattleLogic.BuffMgr:TurnUpdate(2) -- 计算持续伤害（除去流血）
    BattleLogic.BuffMgr:TurnUpdate(3) -- 计算持续伤害（流血）
    BattleLogic.BuffMgr:TurnUpdate(4) -- 计算其他buff
    BattleLogic.BuffMgr:PassUpdate()  -- 计算buff轮数

    --> unit 加入append Unit 单位
    if fightData.fightUnitDataAppend then
        for _, unitData in pairs(fightData.fightUnitDataAppend) do
            if unitData and next(unitData) ~= nil then --< 防服务器值错误问题
                if unitData.round and unitData.round == CurRound then
                    local isInBattleUnit = FightUnitManager.GetUnit(unitData.type, unitData.camp)
                    if isInBattleUnit == nil then   --< 判断是否已有unit
                        BattleLogic.Event:DispatchEvent(BattleEventName.BattleRoundBeginDialogue, unitData.client_dialogue)
                        FightUnitManager.AddUnit(unitData)
                        unitData.isAppend = true --< 是否是追加单位
                    else
                       RoleManager.Log("### repeated add append Unit error")
                    end
                end
            end
        end
    end


    FightUnitManager.ProcessRoundBeginNextFrame(func)


    --> 坦克append单位        
    if fightData.tankDataAppend then
        local tankAppendData = fightData.tankDataAppend
        if #tankAppendData > 0 then
            for i = 1, #tankAppendData do
                if tankAppendData[i].round and tankAppendData[i].round == CurRound and
                not RoleManager.CheckIsExistRole(tankAppendData[i].camp, tankAppendData[i].position) then    --< 后端数据没有筛上阵的  前端筛除位置上已有的 理论后端也应该筛选
                    RoleManager.AddRole(tankAppendData[i], tankAppendData[i].position, true)
                end
            end
        end
    end 

    --无战斗单位参战,运行对话
    if fightData.noUnitDataAppend then
        local noUnitData = fightData.noUnitDataAppend
        if #noUnitData > 0 then
            for i = 1, #noUnitData do
                if noUnitData[i].round and noUnitData[i].round == CurRound then
                    BattleLogic.Event:DispatchEvent(BattleEventName.BattleRoundBeginDialogue, noUnitData[i].client_dialogue)
                end
            end
        end
    end
end

--> 单回合结束
function BattleLogic.RoundEnd(func)
    if BattleLogic.CurOrder ~= 0 then
        RoleManager.getTibuState()
        BattleLogic.RoundTibuEnd(function()
                -- BattleLogManager.Log(
                --     "Round Tibu end",
                --     "round", CurRound
                -- )
        end)
    end

    PosIsAttackRecord = {}

    PosIsAirManAttack = {}
     --roundend延时触发继续
    -- BattleLogic.WaitForTrigger(0.2, function()
    --     func()
    -- end)

    FightUnitManager.ProcessRoundEndNextFrame(func)
end

-- 开始轮转
-- debugTurn  用于判断是否是debug轮转的参数
function BattleLogic.TurnRound(debugTurn)
    if CurRound == 0 then
                
        --return
    end
    -- if BattleLogic.GetIsDebug() and not debugTurn then        
    --     BattleLogic.Event:DispatchEvent(BattleEventName.DebugStop)
    --     return 
    -- end

    --> 计算速度最大的执行技能 主角优先行动
    local maxSpeed = -1
    local maxSpeedPos = -1
    local SkillRole = nil
    local isFindRole = false

    -- if not SkillRole then  
    --     if BattleLogic.FirstCamp == 0  then
    --         if not BattleLogic.IsAirManAttack(0) then
    --             BattleLogic.SetAirManAttack(0,true)
    --             SkillRole = RoleManager.GetAirRole(0)                    
    --         elseif not BattleLogic.IsAirManAttack(1) then
    --             BattleLogic.SetAirManAttack(1,true)
    --             SkillRole = RoleManager.GetAirRole(1)          
    --         end
    --     else
    --         if not BattleLogic.IsAirManAttack(1) then
    --             BattleLogic.SetAirManAttack(1,true)
    --             SkillRole = RoleManager.GetAirRole(1)               
    --         elseif not BattleLogic.IsAirManAttack(0) then
    --             BattleLogic.SetAirManAttack(0,true)
    --             SkillRole = RoleManager.GetAirRole(0)               
    --         end
    --     end

    --     if  SkillRole then
    --         isFindRole = true
    --     end
    -- end
    local function CheckLeaderMan(firstCamp)
        local firstCheck = 0 
        local secondCheck = 1 
        if firstCamp ~= 0 then 
            firstCheck = 1
            secondCheck = 0
        end
        if not BattleLogic.IsAirManAttack(firstCheck) then
            BattleLogic.SetAirManAttack(firstCheck,true)
            SkillRole = RoleManager.GetAirRole(firstCheck)  
            if SkillRole:LeaderCanCastSkilll() then 
                return SkillRole 
            else
                SkillRole = nil   
                return SkillRole                              
            end
        end
        if not BattleLogic.IsAirManAttack(secondCheck) then
            BattleLogic.SetAirManAttack(secondCheck,true)
            SkillRole = RoleManager.GetAirRole(secondCheck)                                    
            if SkillRole:LeaderCanCastSkilll() then 
                return SkillRole 
            else
                SkillRole = nil   
                return SkillRole                                    
            end        
        end
    end

    if not BattleLogic.IsAirManAttack(0) or not BattleLogic.IsAirManAttack(1) then  
        if not SkillRole then  
            SkillRole = CheckLeaderMan(BattleLogic.FirstCamp) 
            if  SkillRole then
                isFindRole = true
            end
        end
    else 
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
    
        if maxSpeedPos ~= -1 then
            PosIsAttackRecord[maxSpeedPos] = true
            isFindRole = true
        end    
    end
    -- BattleLogManager.Log(
    --     "Position Change",
    --     "camp", CurCamp,
    --     "position", CurPosition
    -- )

    -- RoleManager.Log(
    --     "Position Change "..SkillRole.position..
    --     "camp".. CurCamp
    -- )
   
   
    
    -- 如果找不到下一个人
    if not SkillRole then    
        -- BattleLogManager.Log( "No Skill Position" )
        BattleLogic.TurnRoundNextFrame()
        return
    end


    local IsMyTeamEmpty = RoleManager.IsMyTeamEmpty(0)
    local IsEnemyTeamEmpty = RoleManager.IsMyTeamEmpty(1)
    local myhasSub = RoleManager.HasTibu(0) 
    local enemyHasTibu = RoleManager.HasTibu(1)
    local myTibuState = RoleManager.getTibuStateByCamp(0)
    local enemyTibuState = RoleManager.getTibuStateByCamp(1)
    --  空场 触发上场
    if  (IsMyTeamEmpty and myhasSub) or (IsEnemyTeamEmpty and enemyHasTibu) then
        if IsMyTeamEmpty and myhasSub  then
            BattleLogic.CheckAndAddTibu(0)
            BattleLogic.TriggerDelay(0)
        end

        if IsEnemyTeamEmpty and enemyHasTibu then
            BattleLogic.CheckAndAddTibu(1)
            BattleLogic.TriggerDelay(1)
        end

        BattleLogic.TurnRoundNextFrame()              
        return
    end

    -- 一方空场 另一方不行动 
    if (IsMyTeamEmpty and myTibuState == 3) or (IsEnemyTeamEmpty and  enemyTibuState == 3) then
        BattleLogic.TurnRoundNextFrame()
        return
    end

    if not isFindRole then        
        BattleLogic.TurnRoundNextFrame()
    end

    --> 首回合 or 回合更新
    -- if CurRound == 0 or not isFindRole then
    --     CurRound = CurRound + 1
    
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

    -- BattleLogManager.Log(
    --     "Position Change",
    --     "camp", CurCamp,
    --     "position", CurPosition
    -- )

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
    
    --     BattleLogManager.Log( "No Skill Position" )
    --     BattleLogic.TurnRoundNextFrame()
    --     return
    -- end
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

    if MoveTimes >= 1 then
      BattleLogic.Event:DispatchEvent(BattleEventName.CheckFrame,MoveTimes) --行动前核对
    end

    -- 行动
    SkillRole.Event:DispatchEvent(BattleEventName.RoleTurnStart, SkillRole)    -- 开始行动
    BattleLogic.Event:DispatchEvent(BattleEventName.RoleTurnStart, SkillRole)    -- 开始行动
    -- RoleManager.Log(SkillRole.roleId.."位置回调")
    -- BattleLogic.BuffMgr:TurnUpdate(1) -- 计算恢复血量
    -- BattleLogic.BuffMgr:TurnUpdate(2) -- 计算持续伤害（除去流血）
    -- 释放技能后，递归交换阵营
    MoveTimes = MoveTimes + 1
    local haveSkill = SkillRole:CastSkill(function()
        -- BattleLogic.BuffMgr:TurnUpdate(3) -- 计算持续伤害（流血）
        -- BattleLogic.BuffMgr:TurnUpdate(4) -- 计算其他buff
        -- BattleLogic.BuffMgr:PassUpdate()  -- 计算buff轮数
        SkillRole.Event:DispatchEvent(BattleEventName.RoleTurnEnd, SkillRole)      -- 行动结束
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleTurnEnd, SkillRole)    -- 开始行动    
        if SkillRole.leader then
            BattleUtil.ResetRoundToRoundingOnce()
        end
        BattleLogic.TurnRoundNextFrame()                   
    end)

    --> 无技能时 跳过死循环问题
    if not haveSkill then
        BattleLogic.TurnRoundNextFrame()
    end
end

function BattleLogic.WaitForTrigger(delayTime, action)
    -- RoleManager.LogCa(
    --     "frame:"..BattleLogic.CurFrame(),
    --     "before-delayTime",delayTime
    -- )
    delayTime = BattleUtil.ErrorCorrection(delayTime)
    -- RoleManager.LogCa(
    --     "frame:"..BattleLogic.CurFrame(),
    --     "after-delayTime",delayTime
    -- )
    local delayFrame = floor(delayTime * BattleLogic.GameFrameRate + 0.5)
    -- RoleManager.LogCa(
    --     "delayFrame:"..BattleLogic.CurFrame(),
    --     "delayFrame:",delayTime
    -- )
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
    -- BattleLogManager.Log(
    --     "Round :"..CurRound,
    --     "curFrame", curFrame
    -- )
    -- 检测死亡
    if RoleManager.CheckDead() then -- 单独用一帧执行死亡
        return curFrame
    end
    -- 检测复活
    if RoleManager.CheckRelive() then -- 单独用一帧执行复活
        return curFrame
    end

    -- to do yh check 检测战斗结束逻辑
    local roleResult = RoleManager.GetResult()
    if roleResult == 0 then
        BattleLogic.BattleEnd(0)
        return curFrame
    end
    if CurRound > MaxRound then
        BattleLogic.BattleEnd(0)
        return curFrame
    end
    if roleResult == 1 then
        if BattleLogic.CurOrder == BattleLogic.TotalOrder then
            BattleLogic.BattleEnd(1)
        else
            BattleLogic.Event:DispatchEvent(BattleEventName.BattleOrderChange, BattleLogic.CurOrder + 1)
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
    -- -- 检测死亡
    -- if RoleManager.CheckDead() then -- 单独用一帧执行死亡
    --     return 
    -- end
    -- -- 检测复活
    -- if RoleManager.CheckRelive() then -- 单独用一帧执行复活
    --     return 
    -- end
    -- 检测技能释放
    -- 检测轮转   
    BattleLogic.CheckTurnRound()

    BattleLogic.CheckProcessSkill()         --< 检测技能轮转

    --> 空场时间 一方空场 另一方不进行战斗单元回合 以及技能回合
    -- if  BattleLogic.IsJumpSkillAndUnitFrame() then  
    --     BattleLogic.CheckAndAddTibu(0) 
    --     BattleLogic.CheckAndAddTibu(1) 
    --     -- end 待定处理防范
    --     CurRound = CurRound + 1
    --     return
    -- end

    FightUnitManager.UpdateRoundBegin()     --< 检测unit 施放roundbegin    
    FightUnitManager.UpdateRoundEnd()       --< 检测unit 施放roundend
    -- 技能
    SkillManager.Update()

    return curFrame
end

--空场状态检测
function BattleLogic.IsJumpSkillAndUnitFrame()
    local IsMyTeamEmpty = RoleManager.IsMyTeamEmpty(0)
    local IsEnemyTeamEmpty = RoleManager.IsMyTeamEmpty(1)
    local myhasSub = RoleManager.HasTibu(0) 
    local enemyHasTibu = RoleManager.HasTibu(1)
    local myTibuState = RoleManager.getTibuStateByCamp(0)
    local enemyTibuState = RoleManager.getTibuStateByCamp(1)
    -- if (IsMyTeamEmpty and myhasSub ) or ( IsEnemyTeamEmpty and enemyHasTibu) then
    --    RoleManager.Log("!!")
    -- end
    local result = ( IsMyTeamEmpty and myhasSub ) or ( IsEnemyTeamEmpty and enemyHasTibu ) 
    return result
end


--检测注册替补上阵
function BattleLogic.CheckAndAddTibuToWaiting(_camp,func)
    if RoleManager.IsMyOneDead(_camp) and 
    RoleManager.HasTibu(_camp) and 
    not RoleManager.IsRoleTibuAdding(_camp) then
        -- 增加替补回合游戏不会结束
        -- 轮转到我方回合
        RoleManager.setTibuPos(RoleManager.IsMyOneDeadPosCanNotRelive(_camp),_camp)
        RoleManager.AddTibuToWaitingState(_camp)  
        if func then 
            func(_camp) 
            return
        end 
        -- BattleLogic.RoundBegin(function()                            
            BattleLogic.RegisterDelayRroundTrigger(1,RoleManager.AddTibu,_camp) 
            BattleLogic.TriggerDelay(_camp)          
            BattleLogic.ProcessSkillNextFrame() 
        -- end)
    end
end

--检测重置替补状态到待上场
function BattleLogic.CheckAndAddTibuToOnStage(_camp)
    if RoleManager.HasTibu(_camp) and 
    not RoleManager.IsRoleTibuAdding(_camp) and 
    not RoleManager.IsNotFullTeam(_camp) then
        -- 重置状态
        RoleManager.SetTibuState(_camp,1)
        -- 注销上场
        BattleLogic.UnRegisterDelayRroundTrigger(RoleManager.AddTibu,_camp) 
    end
end

--队伍未满检测上阵
function BattleLogic.CheckAndAddTibuAtBeginRound(_camp,func)
    if RoleManager.HasTibu(_camp) and RoleManager.IsNotFullTeam(_camp) then
        RoleManager.setTibuPos(RoleManager.MyTeamEmptyPos(_camp),_camp)
        RoleManager.AddTibuToWaitingState(_camp)
        if func then 
            func(_camp) 
            return
        end 
        -- BattleLogic.RoundBegin(function()
            BattleLogic.RegisterDelayRroundTrigger(1,RoleManager.AddTibu,_camp)
            BattleLogic.TriggerDelay(_camp)                     
        -- end)
    end
end

function BattleLogic.CheckAndAddTibu(_camp,func)
    if RoleManager.IsMyOneDead(_camp) and RoleManager.HasTibu(_camp) then
        -- 增加替补回合游戏不会结束
        -- 轮转到我方回合
        RoleManager.setTibuPos(RoleManager.IsMyOneDeadPosCanNotRelive(_camp),_camp)
        RoleManager.AddTibuToWaitingState(_camp)  
        if func then 
            func(_camp) 
            return
        end 
            -- BattleLogic.RoundBegin(function()                            
                BattleLogic.RegisterDelayRroundTrigger(1,RoleManager.AddTibu,_camp) 
                BattleLogic.TriggerDelay(_camp)
            -- end)        
    end
end

-- 替补上阵中
function BattleLogic.IsAddingSubstitute(_camp)
    if not RoleManager.HasTibu(_camp) then
        return false
    end    
    if RoleManager.IsRoleTibuAdding(_camp) then
        return true
    end
    return false
end

function BattleLogic.GetMoveTimes()
    return MoveTimes
end

-- 查找是否在攻击列表里
function BattleLogic.IsinRecordPos(pos)
   if PosIsAttackRecord[pos] then
      return true
   end
   return false
end

--修改攻击位置为未攻击
function BattleLogic.ChangeRecordPos(pos,flag)
    PosIsAttackRecord[pos]= flag
end
-- 战斗结束
function BattleLogic.BattleEnd(result)
    BattleLogic.Event:DispatchEvent(BattleEventName.BeforeBattleEnd, result)

    BattleLogic.IsEnd =  true 
    BattleLogic.Result = result
    BattleLogic.Event:DispatchEvent(BattleEventName.BattleEnd, result)

    -- RoleManager.printEveryOneDate()
    -- BattleLogManager.Log(
    --     "BattleEnd",
    --     "result:", result
    -- )

    RoleManager.printEveryOneDate(nil)
    -- BattleLogManager.Log(
    --     "BattleEnd",
    --     "result:", result
    -- )

    -- 战斗日志写入
    if not BattleLogic.GetIsDebug() then
        BattleLogManager.WriteFile()
        -- 加入 计算数据
        -- local caculate = RoleManager.getCaRecord()
        -- BattleLogManager.WriteServerFightData(caculate, Random.GetSeed(), "Caculate")
    end
    -- BattleLogic.Clear()
end

--轮询战斗结果
function BattleLogic.FeachResult()
    if BattleLogic.IsFetchedResult then return end
    BattleLogic.IsFetchedResult = true
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
            BattleLogic.TotalOrder = #fightData.enemyData          
        else
            BattleLogic.Event:DispatchEvent(BattleEventName.BattleOrderChange, BattleLogic.CurOrder + 1)
            BattleLogic.IsEnd = false 
        end
    end
end

function BattleLogic.Clear()
    -- 清空角色
    RoleManager.Clear()
    -- 清空事件
    while tbActionList.size > 0 do
        actionPool:Put(tbActionList.buffer[tbActionList.size])
        tbActionList:Remove(tbActionList.size)        
    end
    delayRoundTrip={}
end


-- 服务器数据单独处理调用
function BattleLogic.InitLeaderChangeModeDate(fightData)
end