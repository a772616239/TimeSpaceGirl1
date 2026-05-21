RoleManager = {}
local this = RoleManager

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

-- 初始化
function this.Init()

    bMyAllDead = false
    bEnemyAllDead = false

    this.Clear()
end


-- 角色数据添加
local curUid
function this.AddRole(roleData, position)
    -- WYLog("RoleManager.AddRole")
    -- WYLog(position)
    LogGreen("Rolemanager AddRole11")
    if not curUid then
        curUid = 0
    end
    curUid = curUid + 1
    local role = rolePool:Get()
    role:Init(curUid, roleData, position)
    -- objList:Add(curUid, role)
    if roleData.camp == 0 then
        PosList[position] = role    -- 1-9 我方英雄
    else
        PosList[position + 9] = role-- 10-18 敌方英雄
    end
    -- WYLog("RoleManager.AddRole end")
    if not role:IsRealDead() then
        -- WYLog("end1")
        LogGreen("Rolemanager AddRole22")
        BattleLogic.Event:DispatchEvent(BattleEventName.AddRole, role)
    end
end


--
function this.Update()
    
    bMyAllDead = true
    bEnemyAllDead = true
    for _, v in pairs(PosList) do
        if not v:IsRealDead() then
            v:Update()
            if v.camp == 0 then
                bMyAllDead = false
            else
                bEnemyAllDead = false
            end
        end
    end
    if bEnemyAllDead then
        BattleLogic.Event:DispatchEvent(BattleEventName.BattleOrderEnd, BattleLogic.CurOrder)
    end
end

-- 获取结果
function this.GetResult()
    if bMyAllDead then
        return 0
    end
    if bEnemyAllDead then
        return 1
    end
end

-- 加入将死的人
function this.AddDeadRole(role)
    _DeadRoleList[role.position + role.camp * 9] = role
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
-- function this.GetRoleByCamp(camp)
--     local list = {}
--     for i = 1, 6 do
--         list[i] = PosList[i + camp * 6]
--     end
--     return list
-- end

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

    -- c=0 前排 c=1 中排 
    for c = 0, 2 do
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
    -- c=0 前排 c=1 中排
    for c = 0, 2 do
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
return this   