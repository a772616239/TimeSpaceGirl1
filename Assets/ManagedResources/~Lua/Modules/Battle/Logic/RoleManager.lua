RoleManager = {}
local this = RoleManager
--战舰人员
local _AirRole = {}
--我方死亡列表
local _RealDeadList = {}
-- 将死之人
local _DeadRoleList = {}
-- 重生之人
local _ReliveRoleList = {}
-- 所有角色
local PosList = {}
-- 删除节点
local removeObjList = BattleList.New()
-- 角色对象池
local rolePool = BattleObjectPool.New(function ()
    return RoleLogic.New()
end)

local bMyAllDead
local bEnemyAllDead

--替补数据
local tibuRoleList = {}
local tibuData = {}
local enemy_tibuData = {}
-- 替补状态 
-- 0 不存在 
-- 1 存在且在替补席 （未有单位死亡备战)
-- 3 存在且上阵中 (有战斗单位死亡准备上阵)
-- 4 （角色出场时）
-- 2 存在且已经上阵 （替补角色生成已在场上） 替补对象生成后
--    0 (不存在替补) --- 1 （存在初始化 备战ing）--- 3（场上有一个对象死亡等待上场）--- 4（开始上场直到上场动画回合结束）----2（回合结束到之后状态）
SubstiState = {
    none = 0,
    stage = 1,
    waiting = 3,
    onshow = 4,
    showed = 5
}

local Tibu_State
local enemyTibu_State

local RecordCaculate = {}
-- 初始化
function this.Init()
    bMyAllDead = false
    bEnemyAllDead = false
    Tibu_State = 0
    enemyTibu_State = 0

    _AirRole = {}
    RecordCaculate = {}
    this.Clear()
end

local isLog = false
--temp角色日志
function RoleManager.Log(str)
    if isLog then
        --LogError(str)
    end
end

--获取主角
function this.GetAirRole(camp)
    if _AirRole[camp] ~= nil then
        return _AirRole[camp]
    end
    return nil
end

--to do check yh  角色数据添加 camp==0 我方英雄 1 敌方英雄  战斗替补上阵回合增加角色上阵信息
function this.getCaRecord()
    return RecordCaculate
end

-- 角色数据添加
local curUid
function this.AddRole(roleData, position, isHelp)
    local isShowMan = false
    if roleData.leader then
         isShowMan = true
         roleData.roleId = 1
         roleData.name = "leader"
        --  roleData.element = 0
         roleData.professionId = 0
         roleData.star = 0
         roleData.isTibu = false
         roleData.passivity = nil
        --  roleData.ai = 0
        if roleData.skillArray == nil then
           roleData.skillArray = roleData.skill
        end
        if #roleData.skillArray <= 0 then return end
         roleData.size = 1
        --  LogError("add leader")
    end

    if not curUid then
        curUid = 0
    end
    curUid = curUid + 1
    local role = rolePool:Get()
    -- 判断当前角色作为替补角色出现
    if not roleData.isTibu then
        RoleManager.Log("no tibu")
        role:Init(curUid, roleData, position)
    else
        RoleManager.Log("is tibu")
        if roleData.camp == 0 then
            role = tibuRoleList[1]
        elseif roleData.camp == 1 then
            role = tibuRoleList[2]
        end
    end
    -- objList:Add(curUid, role)
    if roleData.camp == 0 then
        RoleManager.Log("slef on"..position)
        if not isShowMan then
            PosList[position] = role    -- 1-9 我方英雄
        end
        role.position = position
    else
        -- 检测固定上场位置 主角不上场
        if not role.leader then
            if position + 9 > 18 or position + 9 <= 9 then
                if position < 1  then
                position = position + 9
                elseif position > 9 then
                    position = position - 9
                end
            end
            role.position = position 
            RoleManager.Log("enemy on"..(position))
            PosList[position + 9] = role-- 10-18 敌方英雄
        end
    end

    -- 一个阵营限制仅一个人员
    if isShowMan then        
        _AirRole[role.camp] = role
        -- LogError("_AirRole camp:"..role.camp)
    end

    if not role:IsRealDead() then 
        if role:IsSubstitute() then
            BattleLogic.Event:DispatchEvent(BattleEventName.AddRole, role, isHelp,true,isShowMan)            
            local  RoundEndTibuSetState
            RoundEndTibuSetState = function (isHave,nullNum,ReCheckRound)
                if role.camp == 0 then Tibu_State = 2  end
                if role.camp == 1 then enemyTibu_State = 2 end
                BattleLogic.Event:RemoveEvent(BattleEventName.RoundBegin, RoundEndTibuSetState)
            end
            BattleLogic.Event:AddEvent(BattleEventName.RoundBegin, RoundEndTibuSetState)

            BattleLogic.ChangeRecordPos(role.position,false)
            local ResetTibuRound
            ResetTibuRound = function (isHave,nullNum,ReCheckRound)
                ReCheckRound(true,nullNum-1)
                BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundCheck, ResetTibuRound)
            end
            BattleLogic.Event:AddEvent(BattleEventName.BattleRoundCheck, ResetTibuRound)

            return
        end
        BattleLogic.Event:DispatchEvent(BattleEventName.AddRole, role, isHelp,false,isShowMan)
    end
end

------------- 抽象替补逻辑
function this.InitTibuData(roleData,position)
    local date
    if roleData.camp == 0 then
        date = tibuData
        if roleData == nil then
            tibuData.HasTibu = false
            tibuData.AddTibu = false
            Tibu_State = 0
        else
            if not curUid then
                curUid = 0
            end
            curUid = curUid + 1
            Tibu_State = 1
            local role = rolePool:Get()
            role:Init(curUid, roleData, position)
            tibuRoleList[1] = role
            tibuData.roleData = roleData
            tibuData.position = position
            tibuData.HasTibu = true
            tibuData.AddTibu = false
        end
    else
        date = enemy_tibuData
        if roleData == nil then
            enemy_tibuData.HasTibu = false
            enemy_tibuData.AddTibu = false
            enemyTibu_State = 0
        else
            if not curUid then
                curUid = 0
            end
            curUid = curUid + 1
            enemyTibu_State = 1
            local role = rolePool:Get()
            role:Init(curUid, roleData, position)
            tibuRoleList[2] = role
            enemy_tibuData.roleData = roleData
            enemy_tibuData.position = position
            enemy_tibuData.HasTibu = true
            enemy_tibuData.AddTibu = false
        end
    end
    return date
end

function this.getTibuStateByCamp(_camp)
    if _camp == 0 or _camp == nil then
       return Tibu_State
    elseif _camp == 1 then
        return enemyTibu_State
    end
end

function this.getTibuState()
    if Tibu_State ~= nil then
        RoleManager.Log("@@@@@@@@@@@@Tibu_State"..Tibu_State.."xxxxxxx enemyTibu_State"..enemyTibu_State)
        return Tibu_State,enemyTibu_State
    end
    RoleManager.Log("@@@@@@@@@@@@@@Tibu_State is nil")
end

function this.HasTibu(_camp)
    if _camp == 0 then
        if tibuData ~= nil then
            return tibuData.HasTibu
        else
            return false
        end
    elseif _camp == 1 then
        if enemy_tibuData ~= nil then
            return enemy_tibuData.HasTibu
        else
            return false
        end
    end
end

function this.SetTibuState(_camp,_state)
    if _camp == 0 then
        Tibu_State =_state
    elseif _camp == 1 then
        enemyTibu_State = _state
    end
end

function this.AddTibuToWaitingState(_camp)
    if _camp == 0 then
        Tibu_State = 3
    elseif _camp == 1 then
        enemyTibu_State = 3
    end
end

function this.IsRoleTibuAdding(_camp)
    if _camp == 0 then
        if Tibu_State == 3 then
            return true
        end
        return false
    elseif _camp == 1 then
        if enemyTibu_State == 3 then
            return true
        end
        return false
    end
end

function this.TibuClear()
    tibuData.HasTibu = false
    tibuData.AddTibu = false
    Tibu_State = 0
    enemy_tibuData.HasTibu = false
    enemy_tibuData.AddTibu = false
    enemyTibu_State = 0
end

--todo check yh 增加替补
function this.AddTibu(_camp)
    if _camp == 0 then
        if tibuData.HasTibu then
            Tibu_State = 4
            tibuData.AddTibu = true
            this.AddRole(tibuData.roleData, tibuData.position, false)
            bMyAllDead = false
            tibuData.HasTibu = false
            RoleManager.getTibuState()
            BattleLogic.Event:DispatchEvent(BattleEventName.OnAddTibuRole, tibuData.roleData)
        end
    elseif _camp == 1 then
        if enemy_tibuData.HasTibu then
            enemyTibu_State = 4
            enemy_tibuData.AddTibu = true
            this.AddRole(enemy_tibuData.roleData, enemy_tibuData.position - 9, false)
            bEnemyAllDead = false
            enemy_tibuData.HasTibu = false
            RoleManager.getTibuState()
            BattleLogic.Event:DispatchEvent(BattleEventName.OnAddTibuRole, enemy_tibuData.roleData)
        end
    end
end

function this.setTibuPos(pos,_camp)
    if _camp == 0 then
        tibuData.position = pos
    elseif _camp == 1 then
        enemy_tibuData.position = pos
    end
end

-- 是否满编   ！！pve 不适用
function this.IsNotFullTeam(_camp)
    local teamFull = 5 --满编队 5人  --引用外部函数注意！
    local idx = 0
    for _, ro in pairs(PosList) do
        if ro.camp == _camp  and ro ~= nil then
            idx = idx +1
        end
    end
    if idx < teamFull then
        return true
    end
    return false
end

--空场位置 返回第一个
function this.MyTeamEmptyPos(_camp)
    for i =1 , 9 do
        if PosList[i+_camp*9] == nil then return i end
    end

    for po, ro in pairs(PosList) do
        if ro.camp == _camp  and ro ==nil  and not this.IsReliveRole(ro)  then
            RoleManager.Log("po"..po)
            return po
        end
    end
end

-- 获取场上一个存活对象
function this.getMyTeamOneAlive()
    for _, ro in pairs(PosList) do
        if ro.camp == 0  and ro:IsDead()==false then
            return ro
        end
    end
    return nil
end

--我方场上一人触发被动技能
function this.TriggerMyTeamOneAlivePassivity(passivity)
    if tibuRoleList ~= nil then
      for _, ro in pairs(tibuRoleList) do
        local role = ro
        if role ~= nil then
            role:AddPassiveByOther(passivity)
            -- LogError("TriggerMyTeamOneAlivePassivity")
        end
      end
    end
end

--给所有存活人员加上被动buff
function this.AddPassiveToAliveRoles(role)
    for _, ro in pairs(PosList) do
        if ro.camp == 0  and ro:IsDead()==false then
            for idx = 1, #role.passivity do
                -- v:AddPassive(id)
                -- v:AddBuff()
                local v = role.passivity[idx]
                local ids = v[1]
                for k = 1, #ids do
                    local args = {}
                    for j = 1, #v[k + 1] do
                        args[j] = v[k + 1][j]
                    end
                    local id = ids[k]
                    if BattleUtil.Passivity[id] then
                        BattleUtil.Passivity[id](ro, args)
                        -- 加入被动列表
                        table.insert(ro.passiveList, {id, args})
                    else

                    end
                end
            end
        end
    end

    if not role:IsRealDead() then
        BattleLogic.Event:DispatchEvent(BattleEventName.AddRole, role, isHelp)
    end

    this.Clone()
end

--当前场上没有角色
function this.IsMyTeamEmpty(_camp)
    for _, v in pairs(PosList) do
        if v.camp == _camp  and v:IsDead() == false then
            return false
        end
    end
    return true
end

--to do check yh 我方全部阵亡
function this.IsMyAllDead()
   return bMyAllDead
end

--to do check yh 某方一人阵亡
function this.IsMyOneDead(_camp)
    for pos, role in pairs(_RealDeadList) do
        if  role.camp == _camp then            
            --and not BattleLogic.BuffMgr:HasBuff(role,BuffName.NoDead)
            return true
        end
    end
    return false
end

--to do check yh 我方一人阵亡位置
function this.IsMyOneDeadPosCanNotRelive(_camp)
    local upPos = -1
    for pos, role in pairs(_RealDeadList) do
        if  role.camp == _camp  then
            --被替补无法复活 role:GoDead() and not BattleLogic.BuffMgr:HasBuff(role,BuffName.NoDead)
            -- role:SetReliveFilter(false)
            upPos = pos
            break 
        end
    end
    if upPos == -1 then upPos = this.MyTeamEmptyPos(_camp) end
    return upPos
end

------------- 抽象替补逻辑 end

function this.Update()    
    bMyAllDead = true
    bEnemyAllDead = true
    for _, v in pairs(PosList) do
        if not v:IsRealDead() then
            v:Update()
            if v.camp == 0  then                
                bMyAllDead = false
            else
                bEnemyAllDead = false
            end
        end
    end
    -- to do check yh 更新战斗检测
    if tibuData ~= nil then
        if bMyAllDead and tibuData.HasTibu then
            bMyAllDead = false
        end
    end
    if enemy_tibuData ~= nil then
        if bEnemyAllDead and enemy_tibuData.HasTibu then
            bEnemyAllDead = false
        end
    end

    if bEnemyAllDead then
        BattleLogic.Event:DispatchEvent(BattleEventName.BattleOrderEnd, BattleLogic.CurOrder)
    end
end

-- 获取结果
function this.GetResult()    
    -- RecordResult={}
    -- for _, v in pairs(PosList) do
    --     if v~=nil then
    --         local isdead="false"
    --         if v.isRealDead then isdead = "true" end
    --         local _rolinfo =tostring(_) .." hp:".. tostring(v:GetRoleData(RoleDataName.Hp)) .." camp:"..tostring(v.camp) .." isdead:".. isdead 
    --         table.insert(RecordResult , _rolinfo)
    --     end
    -- end   

    -- if bMyAllDead then 
    --     local _set=" bMyAllDead is true"
    --     table.insert(RecordResult,_set)
    -- end

    -- if bEnemyAllDead then 
    --     local _set=" bEnemyAllDead is true"
    --     table.insert(RecordResult,_set)
    -- end
    if bMyAllDead then
        return 0
    end

    if bEnemyAllDead then
        return 1
    end
end

function this.CheadListOnDeadPool()
    if _RealDeadList ~= nil then
        for pos, role in pairs(_RealDeadList) do
            return role
        end
    end
    return nil
end

-- 加入将死的人
function this.AddDeadRole(role)
    _DeadRoleList[role.position + role.camp * 9] = role
    _RealDeadList[role.position + role.camp * 9] = role
end
-- 检测是有人将死
function this.CheckDead()
    local isDeadFrame = false
    local removePos = {}
    for pos, role in pairs(_DeadRoleList) do
        if role:GoDead() then
            isDeadFrame = true
            table.insert(removePos, pos)
        end
    end
    for _, pos in ipairs(removePos) do
        _DeadRoleList[pos] = nil
    end
    return isDeadFrame
end

-- 加入复活之人
function this.AddReliveRole(role)
    _ReliveRoleList[role.position + role.camp * 9] = role
    _RealDeadList[role.position + role.camp * 9] = nil
end

-- 是否在复活列表
function this.IsReliveRole(role)
    if _ReliveRoleList == nil then
       return false
    end
    for ro in pairs(_ReliveRoleList) do
        if ro == role then
           return true
        end
    end
    return false
end

-- 检测是否有人复活
function this.CheckRelive()
    local isReliveFrame = false
    local removePos = {}
    for pos, role in pairs(_ReliveRoleList) do
        if role:Relive() then
            isReliveFrame = true
            table.insert(removePos, pos)
        end
    end
    for _, pos in ipairs(removePos) do
        _ReliveRoleList[pos] = nil
    end
    return isReliveFrame
end

-- 获取角色数据
function this.GetRole(camp, pos)
    return PosList[pos + camp*9]
end

function this.GetRoleByPos(pos)
    return PosList[pos]
end

-- 获取某阵营所有角色
function this.GetRoleByCamp(camp)
    local list = {}
    for i = 1, 6 do
        list[i] = PosList[i + camp * 6]
    end
    return list
end

--查找角色替补数据
function RoleManager.QueryTibu(func, inCludeDeadRole)
    local list = {}
    local index = 1
    if #tibuRoleList > 0 then
        if func then
            for camp, v in pairs(tibuRoleList) do
                if func(v) and (inCludeDeadRole or not v:IsRealDead()) then
                    list[index] = v
                    index = index + 1
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return a.position < b.position 
    end)
    return list
end


-- 查找角色
function RoleManager.Query(func, inCludeDeadRole)
    local list = {}
    local index = 1
    if func then
        for pos, v in pairs(PosList) do
            if func(v) and (inCludeDeadRole or not v:IsRealDead()) then
                list[index] = v
                index = index + 1
            end
        end
    end
    table.sort(list, function(a, b)
        return a.position < b.position 
    end)
    return list
end

--> 查找死亡角色
function RoleManager.QueryDead(func)
    local list = {}
    local index = 1
    if func then
        for pos, v in pairs(PosList) do
            if func(v) and v:IsRealDead() then
                list[index] = v
                index = index + 1
            end
        end
    end
    table.sort(list, function(a, b)
        return a.position < b.position 
    end)
    return list
end


--对位规则： 1敌方相同对位 2若死亡或不存在，选取相邻阵位最近且阵位索引最小的
function this.GetAggro(role)
    -- -- 计算开始位置
    -- local startPos = role.position
    -- startPos = startPos > 3 and startPos - 3 or startPos
    -- local target
    -- local enemyCamp = role.camp == 0 and 1 or 0

    -- -- c=0 前排 c=1 后排
    -- for c = 0, 1 do
    --     startPos = startPos + c*3 
    --     -- 向左
    --     for i = startPos, c*3+1, -1 do
    --         local pos = i + enemyCamp * 6
    --         if PosList[pos] and not PosList[pos]:IsRealDead() then
    --             target = PosList[pos]
    --             break
    --         end
    --     end
    --     if target then return target end
    --     -- 向右
    --     for i = startPos + 1, c*3+3 do
    --         local pos = i + enemyCamp * 6
    --         if PosList[pos] and not PosList[pos]:IsRealDead() then
    --             target = PosList[pos] 
    --             break
    --         end
    --     end
    --     if target then return target end
    -- end

    --> 
    -- 计算开始位置
    local startPos = role.position
    startPos = startPos > 6 and startPos - 6 or (startPos > 3 and startPos - 3 or startPos)
    local target
    local enemyCamp = role.camp == 0 and 1 or 0

    local tempStartPos = startPos  --< 重置用
    -- c=0 前排 c=1 中排 
    for c = 0, 2 do
        startPos = tempStartPos
        startPos = startPos + c*3 
        -- 向左
        for i = startPos, c*3+1, -1 do
            local pos = i + enemyCamp * 9
            if PosList[pos] and not PosList[pos]:IsRealDead() then
                target = PosList[pos]
                break
            end
        end
        if target then return target end
        -- 向右
        for i = startPos + 1, c*3+3 do
            local pos = i + enemyCamp * 9
            if PosList[pos] and not PosList[pos]:IsRealDead() then
                target = PosList[pos] 
                break
            end
        end
        if target then return target end
    end
end

-- 获取没有进入死亡状态的仇恨目标
function this.GetAliveAggro(role)
    -- 计算开始位置
    local startPos = role.position
    startPos = startPos > 3 and startPos - 3 or startPos
    local target
    local enemyCamp = role.camp == 0 and 1 or 0

    -- c=0 前排 c=1 后排
    for c = 0, 1 do
        startPos = startPos + c*3 
        -- 向左
        for i = startPos, c*3+1, -1 do
            local pos = i + enemyCamp * 6
            if PosList[pos] and not PosList[pos]:IsDead() then
                target = PosList[pos]
                break
            end
        end
        if target then return target end
        -- 向右
        for i = startPos + 1, c*3+3 do
            local pos = i + enemyCamp * 6
            if PosList[pos] and not PosList[pos]:IsDead() then
                target = PosList[pos] 
                break
            end
        end
        if target then return target end
    end
    --> 只有被动用 暂不动
end
--对位规则： 1敌方相同对位 2若死亡或不存在，选取相邻阵位最近且阵位索引最小的
function this.GetArrAggroList(role, arr)
    -- -- 重构数据
    -- local plist = {} 
    -- for _, role in ipairs(arr) do
    --     plist[role.position] = role
    -- end
    -- -- 计算开始位置
    -- local startPos = role.position
    -- startPos = startPos > 3 and startPos - 3 or startPos
    -- local targetList = {}
    -- -- c=0 前排 c=1 后排
    -- for c = 0, 1 do
    --     startPos = startPos + c*3 
    --     -- 向左
    --     for i = startPos, c*3+1, -1 do
    --         local pos = i
    --         if plist[pos] and not plist[pos]:IsRealDead() then
    --             table.insert(targetList, plist[pos])
    --         end
    --     end
    --     -- 向右
    --     for i = startPos + 1, c*3+3 do
    --         local pos = i
    --         if plist[pos] and not plist[pos]:IsRealDead() then
    --             table.insert(targetList, plist[pos])
    --         end
    --     end
    -- end
    -- table.sort(targetList, function(a, b)
    --     return a.position < b.position 
    -- end)
    -- return targetList

    --> 
    -- 重构数据
    local plist = {} 
    for _, role in ipairs(arr) do
        plist[role.position] = role
    end
    -- 计算开始位置
    local startPos = role.position
    startPos = startPos > 6 and startPos - 6 or (startPos > 3 and startPos - 3 or startPos)
    local targetList = {}

    local tempStartPos = startPos  --< 重置用
    -- c=0 前排 c=1 中排
    for c = 0, 2 do
        startPos = tempStartPos
        startPos = startPos + c*3 
        -- 向左
        for i = startPos, c*3+1, -1 do
            local pos = i
            if plist[pos] and not plist[pos]:IsRealDead() then
                table.insert(targetList, plist[pos])
            end
        end
        -- 向右
        for i = startPos + 1, c*3+3 do
            local pos = i
            if plist[pos] and not plist[pos]:IsRealDead() then
                table.insert(targetList, plist[pos])
            end
        end
    end
    table.sort(targetList, function(a, b)
        return a.position < b.position 
    end)
    return targetList
end
--获取对位相邻站位的人 chooseType 1 我方 2 敌方(对位的敌人受到嘲讽的影响，若对位的敌人死亡，则选取相邻最近的作为目标)
function this.GetNeighbor(role, chooseType)
    local posList = {}
    local target
    if chooseType == 1 then
        target = role
    else
        if role.lockTarget and not role.lockTarget:IsRealDead() then
            target = role.lockTarget
        else
            target = this.GetAggro(role)
        end
    end
    if target then
        local list = this.Query(function (r) return r.camp == target.camp end)
        for i=1, #list do
            if not list[i]:IsRealDead() then
                if list[i].position == target.position + 3    -- 后排的人
                or list[i].position == target.position - 3    -- 前排的人
                or (math.abs(target.position - list[i].position) <= 1 and math.floor((target.position-1)/3) == math.floor((list[i].position-1)/3)) then  -- 旁边的人和自己
                    table.insert(posList, list[i])
                end
            end
        end
    end
    table.sort(posList, function(a, b)
        return a.position < b.position 
    end)
    return posList
end


function this.Clear()
    --todo check yh add
    this.TibuClear()

    for _, obj in pairs(PosList) do
        obj:Dispose()
        removeObjList:Add(obj)
    end
    PosList = {}

    while removeObjList.size > 0 do
        rolePool:Put(removeObjList.buffer[removeObjList.size])
        removeObjList:Remove(removeObjList.size)
    end

    _DeadRoleList = {}
    _ReliveRoleList = {}
    _RealDeadList= {}
    tibuRoleList={}
end

-- 多波
function this.ClearEnemy()
    local removePos = {}
    for pos, obj in pairs(PosList) do
        if obj.camp == 1 then
            removePos[pos] = 1
            BattleLogic.Event:DispatchEvent(BattleEventName.RemoveRole, obj)
            obj:Dispose()
            removeObjList:Add(obj)
        end
    end
    for pos, _ in pairs(removePos) do
        PosList[pos] = nil
    end
end

--> 获取当前最高速度阵营
function RoleManager.GetFastCamp()
    local maxSpeed = -1
    local maxSpeedCamp = 0
    for pos = 1, 18 do
        while true 
        do
            local role = RoleManager.GetRoleByPos(pos)
            if role and not role:IsRealDead() then
                if maxSpeed < role:GetRoleData(RoleDataName.Speed) then
                    maxSpeed = role:GetRoleData(RoleDataName.Speed)
                    maxSpeedCamp = role.camp
                end
            end

            break
        end
    end

    return maxSpeedCamp
end

--> deprecated 改为服务器算好位置
--> 检测是否有人物数据 根据 位置信息和当前阵型   (formationPos 需要是对应camp的阵型)
function RoleManager.CheckIsHaveRole(camp, position, formationPos)
    local pos = nil
    local isInFormation = false
    for i = 1, 5 do
        if formationPos[i] then
            if position == formationPos[i] then
                isInFormation = true
            end
        else
            --Logerror("### RoleManager.CheckIsHaveRole error!!!")
        end
    end
    if isInFormation then
        if camp == 0 then
            pos = position
        elseif camp == 1 then
            pos = position + 9
        end
        if PosList[pos] then
            return true
        else
            return false
        end
    else
        return false
    end

    return false
end

function RoleManager.CheckIsExistRole(camp, position)
    local pos = nil
    if camp == 0 then
        pos = position
    elseif camp == 1 then
        pos = position + 9
    end
    if PosList[pos] then
        return true
    else
        return false
    end
end

function this.getOneRoleProperty(role,pro)
    local _line = ""
    if role ~= nil then
        local date = role:GetData(pro)
        if date ~= nil then
            _line = tostring(date)
        end
    end
    return _line
end


function this.printLogicInfo()
    local line = ""
    local tb = {}
    line = line.."   frame".. BattleLogic.CurFrame() 
    line = line.."   curRround"..BattleLogic.GetCurRound()
    line = line.."   curMove"..BattleLogic.GetMoveTimes()
    return line
end

local _cacheTeam
function this.printEveryOneDate(_posList)
    _cacheTeam = {}
    if _posList == nil then _posList = PosList end
    for pos,_role in pairs(PosList) do
        local info = this.printOneProper(_role,"self ")
         local prop = {
         _info = info,
         _pos = pos
         }
         if prop.info == nil then   
            prop.info = "null"
        end
        table.insert(_cacheTeam,prop)
    end
    return _cacheTeam
end

function this.GetTeamInfos()
    return this.printEveryOneDate(PosList)
end

function this.printOneProper(_role,_sign)
    if _role.leader then return end
    local _line = _role.roleId.."  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.Hp).." ".."--生命  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.MaxHp).." ".."--最大生命  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.Attack).." ".."--攻击力  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.PhysicalDefence).." ".."--护甲  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.MagicDefence).." ".."--魔抗  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.Speed).." ".."--速度  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.DamageBocusFactor).."-> ".."--伤害加成系数（%）  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.DamageReduceFactor).." ".."--伤害减免系数（%）  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.Hit).." ".."--施法率（%  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.Dodge).." ".."--后期基础施法率（%）  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.Crit).." ".."--暴击率（%）  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.CritDamageFactor).." ".."--暴击伤害系数（%）  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.Tenacity).." ".."--抗暴率（%）  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.TreatFacter).." ".."--治疗加成系数（%）  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.CureFacter).." ".."--受到治疗加成系数（%）  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.PhysicalDamage).." ".."--< 物伤  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.MagicDamage).." ".."--< 法伤  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.PhysicalImmune).."-> ".."--< 物免  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.MagicImmune).." ->".."--< 法免  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.SpeedAddition).." ".."--< 速度加成  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.AttackAddition).." ".."--< 攻击加成  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.ArmorAddition).." ".."--< 护甲加成  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.ControlProbability).." ".."--< 控制几率  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.ControlResist).." ".."--< 控制抵抗  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.SkillDamage).." ".."--< 技能伤害  \n"
    -- _line = _line..this.getOneRoleProperty(_role,RoleDataName.DamageToMage).." ".."--< 对高爆型伤害  \n"
    -- _line = _line..this.getOneRoleProperty(_role,RoleDataName.DamageToFighter).." ".."--< 对穿甲型伤害  \n"
    -- _line = _line..this.getOneRoleProperty(_role,RoleDataName.DamageToDefender).." ".."--< 对防御型伤害  \n"
    -- _line = _line..this.getOneRoleProperty(_role,RoleDataName.DamageToHealer).." ".."--< 对辅助型伤害             \n"
    -- _line = _line..this.getOneRoleProperty(_role,RoleDataName.DefenceFromFighter).." ".."--< 受穿甲型伤害降低  \n"
    -- _line = _line..this.getOneRoleProperty(_role,RoleDataName.DefenceFromMage).." ".."--< 受高爆型伤害降低  \n"
    -- _line = _line..this.getOneRoleProperty(_role,RoleDataName.DefenceFromDefender).." ".."--< 受防御型伤害降低  \n"
    -- _line = _line..this.getOneRoleProperty(_role,RoleDataName.DefenceFromHealer).." ".."--< 受辅助型伤害降低  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.CriDamageReduceRate).." ".."--< 暴伤抵抗  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.HealCritical).." ".."--< 修理暴击  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.HealCriEffect).." ".."--< 修理暴击效果  \n"
    _line = _line..this.getOneRoleProperty(_role,RoleDataName.MaxHpPercentage).." ".."--< 生命加成  \n"
    if _role.isRealDead then
        _line = _line.."》》》isdead"
    else
        _line = _line.."》》》not dead"
    end
    BattleLogManager.Log(
        _sign.." round:"..BattleLogic.GetCurRound().."frame:"..BattleLogic.CurFrame(),
        "tcamp:".. _role.camp,
        "tpos：".. _role.position,
        "prop：".. _line," end"
    )
    return _line
end


------------------- 回滚状态同步

--记录当前回滚帧
this.nowRecored={}

function this.printMirror()
    -- --获取克隆的人员输出属性
    -- BattleLogManager.Log(
    --     "~~~~cloneMirror round:"..BattleLogic.GetCurRound().."frame:"..BattleLogic.CurFrame().."   start"
    -- )
    -- if ##this.nowRecored > 0 and #this.nowRecored._fPosList > 0 then
    --  local _posList = this.nowRecored._fPosList
    --     this.printEveryOneDate(_posList)
       
    -- end
    -- BattleLogManager.Log(
    --     "~~~~~cloneMirror round:"..BattleLogic.GetCurRound().."frame:"..BattleLogic.CurFrame().."   end"
    -- )
end

--记录角色计算数据
function this.LogCa(...)
    -- local args = {...}
    -- local log = args[1] .. ":\n"
    -- log = log .. string.format("%s = %s, ", "frame", BattleLogic.CurFrame())
    -- for i = 2, #args, 2 do
    --     local key = args[i]
    --     local value = args[i + 1]
    --     log = log .. string.format("%s = %s, ", key, value)
    -- end
    -- table.insert(RecordCaculate, log)
end

function this.LogArgs(id,args)
    if #args > 0 then
        for i,arg in pairs(args) do
            --LogError("id:"..id.." ".."arg["..i.."]:"..arg)
        end
    end
end

-------------------工具方法--------------

local function compare(_myrole,_other)
    --Logerror("compare  ".._myrole.roleId.."  ") 
    return _myrole:Equle(_other)
end

local function getRoleInPool(_role,_pool)
    --Logerror("getRole".._role.roleId) 
    local ro =_pool:Find(_role,compare)
    return ro
end

local function tableCloneUID(intb,cptb,_newpool)
    for pos, rol in pairs(cptb) do
        intb[pos]=getRoleInPool(rol,_newpool)
        -- --Logerror("R..................y")
    end
    return intb
end

-------------------工具方法--------------

function this.XCpy()
    local _cpPool = BattleObjectPool.New(function ()
        return RoleLogic.New()
    end)

    local function _cpRoles(_role)   
        --Logerror("ori".._role.roleId)     
        local _r = _role:Clone()
        _cpPool:Put(_r)
        --Logerror("new".._r.roleId)     
    end 
    rolePool:Foreach(_cpRoles)     
     
    --Logerror("_cpPool........."..tostring(_cpPool:Count()))    
end

function this.CopyTableRole(_tb)
    local _copyTb=BattleDictionary.New()
    if _tb~=nil and #_tb>0 then
        for pos=1,#_tb do
            local _rol=_tb[pos]:Clone()
            _copyTb:Add(pos,_rol)            
        end
    end 
    return _copyTb
end


--克隆关键数据
function this.Clone()

    local _roleCp = BattleObjectPool.New(function ()
        return RoleLogic.New()
    end)

    local function _cpRoles(_role)   
        --Logerror("ori".._role.roleId)     
        local _r = _role:Clone()
        _roleCp:Put(_r)
        --Logerror("new".._r.roleId)     
    end 
     rolePool:Foreach(_cpRoles)     
     

    -- local _roleCp = rolePool:CloneType("RoleLogic")   做镜像数据
    -- 将死之人
    local function CopyTableRole(_tb,_copyTb)
        if _tb ~= nil and #_tb > 0 then
            for pos, role in pairs(_tb) do
                local _rol = role:Clone()
                --Logerror("_rol........."..role.roleId)   
                _copyTb:Add(pos,_rol)
            end
        end 
    end
    -- local _roleCp = rolePool:CloneType("RoleLogic")   做镜像数据
    -- 将死之人
    local _CpDeadRoleList = BattleDictionary.New()
    -- 重生之人
    local _CpReliveRoleList = BattleDictionary.New()
    -- 所有角色
    local _CpPosList = BattleDictionary.New()

    CopyTableRole(_DeadRoleList,_CpDeadRoleList)
    CopyTableRole(_ReliveRoleList,_CpReliveRoleList)
    CopyTableRole(PosList,_CpPosList)

    local frame = {
        _frolepool = _roleCp,
        _fDeadRoleList = _CpDeadRoleList,
        _fReliveRoleList = _CpReliveRoleList,
        _fPosList = _CpPosList
    }

    return frame
end

-- 更新当前角色池中的所有角色数据


local function ContainsRoleInTable(tab,role)
    if #tab <=0 then return false end
    for pos,ro in pairs(tab) do
        if role:Equle(ro) then 
            return true
        end
    end
    return true
end


local function FindRoleInTable(tab,role)
    --Logerror("F..............1")
    if #tab <=0 then return nil end
    for pos,ro in pairs(tab) do
        if role:Equle(ro) then 
            return ro 
        end
    end
    return nil
end


local function FindRolePosInTable(tab,role)
    if #tab <=0 then return nil end
    for pos,ro in pairs(tab) do
        if role:Equle(ro) then 
            return pos 
        end
    end
    return nil
end

--回滚战斗数据
function this.RollBack(_frame)
    -- 重置对象池所有玩家数据
    local frame = _frame
    local _rolPol = frame._frolepool
    local _FDead= frame._fDeadRoleList
    local _FRelive= frame._fReliveRoleList
    local _FPos= frame._fPosList

    --Logerror("R..............5")
    ---- 原始角色池找到对象
    ---- 回滚到帧记录的对象数据
    -- local function XrollBack(_role)
    --     local mirro = _rolPol:Find(_role,compare)
    --     if mirro ~= nil then 
    --         _role:RoleBack(mirro) 
    --         --Logerror("R..............6")
    --     end
    -- end
    -- rolePool:Foreach(XrollBack)
    --Logerror("R..............7")

    -- 角色数据回滚 
    local function XrolFucDate(orTb,MirTb)
        if #orTb<=0 then return end   
        --Logerror("f..............1") 
        for pos,role in pairs(orTb) do
            if MirTb:Contains(pos) then
                local _mir =MirTb:Get(pos)
                -- LogError("f..............2") 
                this.printOneProper(_mir,"miro   ")
                role:RoleBack(_mir)      

            end                        
        end
        --Logerror("R..............x")
    end

    -- 角色站位回滚 --todo
    local function XrolFucPos(orTb,MirTb)
        if #orTb<=0 then return end    
        for pos,role in pairs(orTb) do
            if ContainsRoleInTable(role,MirTb) then -- 在镜像数据中 回滚数据
                local _ps = FindRolePosInTable(role,MirTb)
                if _ps ~= pos then
                    --Logerror(role.roleId.."pos is error")
                end
            end
        end
    end


    -- XrolFucDate(_DeadRoleList,_FDead)
    --Logerror("R..............8")
    -- XrolFucDate(_ReliveRoleList,_FRelive)
    --Logerror("R..............9")
    XrolFucDate(PosList,_FPos)        
    --Logerror("R..............10")
    this.nowRecored = frame

    return frame
end

return this