BattleUtil = {}
-- local GameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
--local BattleUtil = BattleUtil
local floor = math.floor
local max = math.max
local min = math.min
--local Random = Random
--local RoleDataName = RoleDataName
--local BattleEventName = BattleEventName
BattleUtil.Passivity = require("Modules/Battle/Logic/Base/Passivity")

local function clamp(v, minValue, maxValue)
    if v < minValue then
        return minValue
    end
        if v > maxValue then
        return maxValue
    end
    return v
end

function BattleUtil.ErrorCorrection(f) --进行精度处理，避免前后端计算不一致
    return floor(f * 100000 + 0.5) / 100000
end

function BattleUtil.FP_Mul(...)
    local f = 1
    for i, v in ipairs{...} do
        f = floor(f * v * 100000 + 0.5) / 100000
    end
    return f
end

-- 选择前排
function BattleUtil.ChooseFRow(arr)
    local tempArr = {}
    for _, r in ipairs(arr) do
        if r.position <= 3 and not r:IsRealDead() then
            table.insert(tempArr, r)
        end
    end
    table.sort(tempArr, function(a, b)
        return a.position < b.position
    end)
    return tempArr
end
--> 选择中排
function BattleUtil.ChooseMRow(arr)
    local tempArr = {}
    for _, r in ipairs(arr) do
        if r.position > 3 and r.position <= 6 and not r:IsRealDead() then
            table.insert(tempArr, r)
        end
    end
    table.sort(tempArr, function(a, b)
        return a.position < b.position
    end)
    return tempArr
end
-- 选择后排
function BattleUtil.ChooseBRow(arr)
    local tempArr = {}
    for _, r in ipairs(arr) do
        if r.position > 6 and not r:IsRealDead() then
            table.insert(tempArr, r)
        end
    end
    table.sort(tempArr, function(a, b)
        return a.position < b.position
    end)
    return tempArr
end
--> 选择前两排
function BattleUtil.ChooseF2Row(arr)
    local tempArr = {}
    for _, r in ipairs(arr) do
        if r.position <= 6 and not r:IsRealDead() then
            table.insert(tempArr, r)
        end
    end
    table.sort(tempArr, function(a, b)
        return a.position < b.position
    end)
    return tempArr
end
--> 选择后两排
function BattleUtil.ChooseB2Row(arr)
    local tempArr = {}
    for _, r in ipairs(arr) do
        if r.position > 3 and not r:IsRealDead() then
            table.insert(tempArr, r)
        end
    end
    table.sort(tempArr, function(a, b)
        return a.position < b.position
    end)
    return tempArr
end
-- 选择一列(col == 0 表示第三列哦)
function BattleUtil.ChooseCol(arr, col)
    local tempArr = {}
    for _, role in ipairs(arr) do
        if role.position % 3 == col then
            table.insert(tempArr, role)
        end
    end
    table.sort(tempArr, function(a, b)
        return a.position < b.position
    end)
    return tempArr
end
--> 数量最多列 0第三
function BattleUtil.GetMaxCol(arr)
    local tempArr = {0, 0, 0}
    for _, role in ipairs(arr) do
        local idx = role.position % 3
        if idx == 0 then
            tempArr[3] = tempArr[3] + 1
        else
            tempArr[idx] = tempArr[idx] + 1
        end
        
    end
    local maxNum = -1
    local col = -1
    for i = 1, #tempArr do
        if tempArr[i] > maxNum then
            col = i
            maxNum = tempArr[i]
            if i == 3 then
                col = 0
            end
        end
    end
    return col
end
-- 根据属性排序
function BattleUtil.SortByProp(arr, prop, sort)
    BattleUtil.Sort(arr, function(a, b)
        local r1 = a:GetRoleData(prop)
        local r2 = b:GetRoleData(prop)
        if sort == 1 then return r1 > r2 else return r1 < r2 end
    end)
    return arr
end
-- 按血量排序
function BattleUtil.SortByHpFactor(arr, sort)
    BattleUtil.Sort(arr, function(a, b)
        local r1 = a:GetRoleData(RoleDataName.Hp) / a:GetRoleData(RoleDataName.MaxHp)
        local r2 = b:GetRoleData(RoleDataName.Hp) / b:GetRoleData(RoleDataName.MaxHp)
        if sort == 1 then return r1 > r2 else return r1 < r2 end
    end)
    return arr
end
--> 按职业排序
function BattleUtil.SortByProfessionId(arr, sort, _professionId)
    -- 角色职业
    -- 1、防御
    -- 2、高爆
    -- 3、穿甲
    -- 4，辅助
    BattleUtil.Sort(arr, function(a, b)
        local aa = a.professionId == _professionId and 1 or 0
        local bb = b.professionId == _professionId and 1 or 0
        
        if sort == 1 then return aa > bb else return aa < bb end
    end)

    return arr
end

function BattleUtil.ShuffleDead(arr)
    
    local hpZero = {}
    for i = 1, #arr do
        if arr[i]:GetRoleData(RoleDataName.Hp) <= 0 then
            table.insert(hpZero, arr[i])
        end
    end
    Random.RandomList(hpZero)
    local idx = 0
    for i = 1, #arr do
        if arr[i]:GetRoleData(RoleDataName.Hp) <= 0 then
            idx = idx + 1
            arr[i] = hpZero[idx]
        end
    end

    return arr
end

-- 获取技能最大目标数
function BattleUtil.GetMaxTargetNum(chooseId)
    local chooseType = floor(chooseId / 100000) % 10
    local chooseLimit = floor(chooseId / 10000) % 10
    local chooseWeight =  floor(chooseId / 100) % 100
    local sort = floor(chooseId / 10) % 10
    local num = chooseId % 10

    -- 
    if chooseType == 3 or chooseType == 4 then
        return 1
    else
        if num == 0 then
            if chooseLimit == 0 then
                if chooseWeight == 7 then 
                    return 4
                elseif chooseLimit == 8 then
                    return 1
                else
                    return 6
                end
            elseif chooseLimit == 1 or chooseLimit == 2 then
                return 3
            elseif chooseLimit == 3 then
                return 2
            end
        else
            return num
        end
    end
end

function BattleUtil.excludeSelfList(arr,role)
    local tempArr = {}
    for _, r in ipairs(arr) do
        if not r:Equle(role) and not r:IsRealDead() then
            table.insert(tempArr, r)
        end
    end
    table.sort(tempArr, function(a, b)
        return a.position < b.position
    end)
    return tempArr
end

-- 
function BattleUtil.ChooseTarget(role, chooseId)
    
    
    local chooseType = floor(chooseId / 100000) % 10
    local chooseLimit = floor(chooseId / 10000) % 10
    local chooseWeight =  floor(chooseId / 100) % 100
    local sort = floor(chooseId / 10) % 10
    local num = chooseId % 10
    local arr

    if role.ctrl_chaos then --< 混乱自残
        return {role}
    end


    -- 选择类型
    if chooseType == 1 then
        arr = RoleManager.Query(function (r) return r.camp == role.camp end)
    elseif chooseType == 2 then
        if role.lockTarget and not role.lockTarget:IsRealDead() and num == 1 then --嘲讽时对单个敌军生效
            return {role.lockTarget}
        end
        arr = RoleManager.Query(function (r) return r.camp ~= role.camp end)
    elseif chooseType == 3 then
        if role.ctrl_blind then --致盲时自身变随机友军
            arr = RoleManager.Query(function (r) return r.camp == role.camp end)
            BattleUtil.RandomList(arr)
            return {arr[1]}
        end
        return {role}
    elseif chooseType == 4 then
        if role.lockTarget and not role.lockTarget:IsRealDead() then --嘲讽时对仇恨目标生效
            return {role.lockTarget}
        end
        if role.ctrl_blind then --致盲时仇恨目标变随机
            arr = RoleManager.Query(function (r) return r.camp ~= role.camp end)
            BattleUtil.RandomList(arr)
            return {arr[1]}
        end
        return {RoleManager.GetAggro(role)}
    elseif chooseType == 5 then     --< 我方阵亡
        arr = RoleManager.QueryDead(function (r) return r.camp == role.camp end)
    elseif chooseType == 6 then     --< 我方全体
        arr = RoleManager.Query(function (r) return r.camp == role.camp end, true)
    elseif chooseType == 7 then     --< 我方阵亡可复活英雄
        local reliveFunc = function (ro)
            return (ro.IsDead or ro.isRealDead) and  ro.reliveFilter
        end
        arr = RoleManager.Query(function (r) return r.camp == role.camp and reliveFunc(r) and r.isDead end,true)
  
        if arr==nil or #arr==0 then              
            arr =RoleManager.Query(function (r) return r.camp == role.camp end, false)
 
        end
    else
        arr = RoleManager.Query()
    end

    --选择范围
    if chooseLimit == 0 then --选择全体不做任何操作

    elseif chooseLimit == 1 then-- 前排
        local tempArr = BattleUtil.ChooseFRow(arr)
        if #tempArr == 0 then
            tempArr = BattleUtil.ChooseMRow(arr)
        end
        if #tempArr == 0 then   -- 没有选择后排
            tempArr = BattleUtil.ChooseBRow(arr)
        end
        arr = tempArr
    elseif chooseLimit == 2 then-- 后排
        local tempArr = BattleUtil.ChooseBRow(arr)
        if #tempArr == 0 then
            tempArr = BattleUtil.ChooseMRow(arr)
        end
        if #tempArr == 0 then   -- 没有选择前排
            tempArr = BattleUtil.ChooseFRow(arr)
        end
        arr = tempArr
    elseif chooseLimit == 3 then-- 对列
        local myCol = role.position % 3
        local tempArr = BattleUtil.ChooseCol(arr, myCol)
        if #tempArr == 0 then   -- 对列没有人，按顺序找到有人得列
            for i = 1, 3 do
                local col = i % 3 -- 0 表示第三列嗷
                tempArr = BattleUtil.ChooseCol(arr, col)
                if #tempArr ~= 0 then
                    break
                end
            end
        end
        arr = tempArr
    elseif chooseLimit == 4 then        --< 前二
        local tempArr = BattleUtil.ChooseF2Row(arr)
        if #tempArr == 0 then   -- 没有选择最后一排
            tempArr = BattleUtil.ChooseBRow(arr)
        end
        arr = tempArr
    elseif chooseLimit == 5 then        --< 后二
        local tempArr = BattleUtil.ChooseB2Row(arr)
        if #tempArr == 0 then   -- 没有选择第一排
            tempArr = BattleUtil.ChooseFRow(arr)
        end
        arr = tempArr
    elseif chooseLimit == 6 then        --< 全体,优先4职业
    elseif chooseLimit == 7 then        --< 人数最多列
        local tempArr = BattleUtil.ChooseCol(arr, BattleUtil.GetMaxCol(arr))
        arr = tempArr
    elseif chooseLimit == 8 then        --< 除自己外
        local tempArr = BattleUtil.excludeSelfList(arr,role)
        if #tempArr == 0 then   
            tempArr = arr
        end
        -- LogError("#tempArr"..#tempArr)
        arr = tempArr
    elseif chooseLimit == 9 then        --< 9全体,优先2职业
        arr = BattleUtil.SortByProfessionId(arr, sort, 2)
    end

    if chooseWeight == 9 then   --< 随机某属性 定死或走表
        chooseWeight = Random.RangeInt(1, 6)
    end
    -- 选择条件
    if chooseWeight == 0 or role.ctrl_blind then --致盲时排序无效
        BattleUtil.RandomList(arr)
    elseif chooseWeight == 1 then -- 生命值
        BattleUtil.SortByProp(arr, RoleDataName.Hp, sort)
        if chooseType == 6 then
            BattleUtil.ShuffleDead(arr)
        end
    elseif chooseWeight == 2 then -- 血量百分比
        BattleUtil.SortByHpFactor(arr, sort)
    elseif chooseWeight == 3 then   -- 攻击力
        arr =  BattleUtil.SortByProp(arr, RoleDataName.Attack, sort)
        -- RoleManager.LogRoles("attack",arr)
    elseif chooseWeight == 4 then   -- 防御
        BattleUtil.SortByProp(arr, RoleDataName.PhysicalDefence, sort)
    elseif chooseWeight == 5 then   -- 护甲
        BattleUtil.SortByProp(arr, RoleDataName.PhysicalDefence, sort)
    elseif chooseWeight == 6 then   -- 魔抗
        BattleUtil.SortByProp(arr, RoleDataName.MagicDefence, sort)
    elseif chooseWeight == 7 then   -- 对位及其相邻目标
        arr = RoleManager.GetNeighbor(role, chooseType)
    elseif chooseWeight == 8 then   -- 对位
        arr = RoleManager.GetArrAggroList(role, arr)
    elseif chooseWeight == 11 then                                  --< 防御
        arr = BattleUtil.SortByProfessionId(arr, sort, 1)
    elseif chooseWeight == 12 then                                  --< 高爆
        arr = BattleUtil.SortByProfessionId(arr, sort, 2)
    elseif chooseWeight == 13 then                                  --< 穿甲
        arr = BattleUtil.SortByProfessionId(arr, sort, 3)
    elseif chooseWeight == 14 then                                  --< 辅助
        arr = BattleUtil.SortByProfessionId(arr, sort, 4)
    elseif chooseWeight == 21 then                                  --< 负面状态（控制状态、减益状态和持续伤害状态）
        local searchFunc = function(role)
            local list = BattleLogic.BuffMgr:GetBuff(role, function (buff)
                return buff.type == BuffName.Control or buff.isDeBuff or buff.type == BuffName.DOT              
            end)
            return list and #list > 0
        end
        arr = RoleManager.Query(searchFunc, false)
    end

    if chooseLimit == 6 then            --< 全体,优先4职业
        local tempArr = {}
        for i = 1, #arr do
            if arr[i].roleData.professionId == 4 then
                table.insert(tempArr, arr[i])
            end
        end
        for i = 1, #arr do
            if arr[i].roleData.professionId ~= 4 then
                table.insert(tempArr, arr[i])
            end
        end
        arr = tempArr
    -- elseif chooseLimit == 8 then        --< 除自己
    --     local tempArr = {}
    --     for _, r in ipairs(arr) do
    --         if not (r == role) then
    --             table.insert(tempArr, r)
    --         end
    --     end
    --     table.sort(tempArr, function(a, b)
    --         return a.position < b.position
    --     end)
    --     arr = tempArr
    elseif chooseLimit == 9 then        --< 全体,优先2职业
        local tempArr = {}
        for i = 1, #arr do
            if arr[i].roleData.professionId == 2 then
                table.insert(tempArr, arr[i])
            end
        end
        for i = 1, #arr do
            if arr[i].roleData.professionId ~= 2 then
                table.insert(tempArr, arr[i])
            end
        end
        arr = tempArr
    end

    local finalArr = {}

    if sort == 3 then       --< 3随机（可重复，单体最多被选3次）
        local randArr = {}
        local randtimes = num == 0 and #arr or num
        local randTimesArr = {}
        for i = 1, #arr do
            table.insert(randTimesArr, 0)
        end
        
        
        local idx = 0
        while #randArr < randtimes
        do
            while true
            do
                local randIdx = Random.RangeInt(1, #arr)
                if randTimesArr[randIdx] >= 3 then
                    break
                end
                randTimesArr[randIdx] = randTimesArr[randIdx] + 1
                table.insert(randArr, arr[randIdx])

                break
            end
            idx = idx + 1
            if idx > 5 then
                break
            end
        end
        
        finalArr = randArr
    else
        --> 不随机按顺序
        if num == 0 then
            finalArr = arr
        else    
            for i = 1, num do
                if arr[i] then
                    table.insert(finalArr, arr[i])
                end
            end
        end
    end
   --LogError(string.format("chooseid: %s chooseType:== %s chooseLimit:== %s chooseWeight:== %s sort:== %s num:== %s,"
--,tostring(chooseId),tostring(chooseType),tostring(chooseLimit),tostring(chooseWeight),tostring(sort),tostring(num)))
    -- LogError("chooseType:"..chooseType)
    -- LogError("chooseLimit:"..chooseLimit)
    -- LogError("chooseWeight:"..chooseWeight)
    -- LogError("sort:"..sort)
    -- LogError("num:"..num)

    -- table.sort(finalArr, function(a, b)
    --     return a.position < b.position 
    -- end)

    return finalArr
end

--> 打乱角色队列
function BattleUtil.ShufferRoles(arr,singleTime)
    if not arr or #arr==0  then return nil end 
    local num = Random.RangeInt(1,5) --> 打乱次数
    local randArr = {}
    local randtimes = num == 0 and #arr or num
    local randTimesArr = {}
        for i = 1, #arr do
            table.insert(randTimesArr, 0)
        end
        
        local idx = 0
        while #randArr < randtimes
        do
            while true
            do
                local randIdx = Random.RangeInt(1, #arr)
                if randTimesArr[randIdx] >= singleTime then
                    break
                end
                randTimesArr[randIdx] = randTimesArr[randIdx] + 1
                table.insert(randArr, arr[randIdx])

                break
            end
            idx = idx + 1
            if idx > 5 then
                break
            end
        end
        
        return randArr
end

--> 选择单个对象
function BattleUtil.ChooseOneTarget(role, chooseId, excludeAttackList)
    
    
    local chooseType = floor(chooseId / 100000) % 10
    local chooseLimit = floor(chooseId / 10000) % 10
    local chooseWeight =  floor(chooseId / 100) % 100
    local sort = floor(chooseId / 10) % 10
    local num = chooseId % 10
    local arr

    
    if role.ctrl_chaos then --< 混乱自残
        
        return role
    end

    -- 选择类型
    if chooseType == 1 then
        arr = RoleManager.Query(function (r) return r.camp == role.camp end)
    elseif chooseType == 2 then
        if role.lockTarget and not role.lockTarget:IsRealDead() and num == 1 then --嘲讽时对单个敌军生效
            return role.lockTarget
        end
        arr = RoleManager.Query(function (r) return r.camp ~= role.camp end)
    elseif chooseType == 3 then
        if role.ctrl_blind then --致盲时自身变随机友军
            arr = RoleManager.Query(function (r) return r.camp == role.camp end)
            BattleUtil.RandomList(arr)
            return arr[1]
        end
        return role
    elseif chooseType == 4 then
        if role.lockTarget and not role.lockTarget:IsRealDead() then --嘲讽时对仇恨目标生效
            return role.lockTarget
        end
        if role.ctrl_blind then --致盲时仇恨目标变随机
            arr = RoleManager.Query(function (r) return r.camp ~= role.camp end)
            BattleUtil.RandomList(arr)
            return arr[1]
        end
        return RoleManager.GetAggro(role)
    elseif chooseType == 5 then     --< 我方阵亡
        arr = RoleManager.QueryDead(function (r) return r.camp == role.camp end)
    elseif chooseType == 6 then     --< 我方全体
        arr = RoleManager.Query(function (r) return r.camp == role.camp end, true)
    else
        arr = RoleManager.Query()
    end

    --选择范围
    if chooseLimit == 0 then --选择全体不做任何操作

    elseif chooseLimit == 1 then-- 前排
        local tempArr = BattleUtil.ChooseFRow(arr)
        if #tempArr == 0 then
            tempArr = BattleUtil.ChooseMRow(arr)
        end
        if #tempArr == 0 then   -- 没有选择后排
            tempArr = BattleUtil.ChooseBRow(arr)
        end
        arr = tempArr
    elseif chooseLimit == 2 then-- 后排
        local tempArr = BattleUtil.ChooseBRow(arr)
        if #tempArr == 0 then
            tempArr = BattleUtil.ChooseMRow(arr)
        end
        if #tempArr == 0 then   -- 没有选择前排
            tempArr = BattleUtil.ChooseFRow(arr)
        end
        arr = tempArr
    elseif chooseLimit == 3 then-- 对列
        local myCol = role.position % 3
        local tempArr = BattleUtil.ChooseCol(arr, myCol)
        if #tempArr == 0 then   -- 对列没有人，按顺序找到有人得列
            for i = 1, 3 do
                local col = i % 3 -- 0 表示第三列嗷
                tempArr = BattleUtil.ChooseCol(arr, col)
                if #tempArr ~= 0 then
                    break
                end
            end
        end
        arr = tempArr
    elseif chooseLimit == 4 then        --< 前二
        local tempArr = BattleUtil.ChooseF2Row(arr)
        if #tempArr == 0 then   -- 没有选择最后一排
            tempArr = BattleUtil.ChooseBRow(arr)
        end
        arr = tempArr
    elseif chooseLimit == 5 then        --< 后二
        local tempArr = BattleUtil.ChooseB2Row(arr)
        if #tempArr == 0 then   -- 没有选择第一排
            tempArr = BattleUtil.ChooseFRow(arr)
        end
        arr = tempArr
    elseif chooseLimit == 6 then        --< 全体,优先4职业
    elseif chooseLimit == 7 then        --< 人数最多列
        local tempArr = BattleUtil.ChooseCol(arr, BattleUtil.GetMaxCol(arr))
        arr = tempArr
    elseif chooseLimit == 8 then        --< 除自己外
    elseif chooseLimit == 9 then        --< 9全体,优先2职业
    end

    if chooseWeight == 9 then   --< 随机某属性 定死或走表
        chooseWeight = Random.RangeInt(1, 6)
    end
    -- 选择条件
    if chooseWeight == 0 or role.ctrl_blind then --致盲时排序无效
        BattleUtil.RandomList(arr)
    elseif chooseWeight == 1 then -- 生命值
        BattleUtil.SortByProp(arr, RoleDataName.Hp, sort)
        if chooseType == 6 then
            BattleUtil.ShuffleDead(arr)
        end
    elseif chooseWeight == 2 then -- 血量百分比
        BattleUtil.SortByHpFactor(arr, sort)
    elseif chooseWeight == 3 then   -- 攻击力
        BattleUtil.SortByProp(arr, RoleDataName.Attack, sort)
    elseif chooseWeight == 4 then   -- 防御
        BattleUtil.SortByProp(arr, RoleDataName.PhysicalDefence, sort)
    elseif chooseWeight == 5 then   -- 护甲
        BattleUtil.SortByProp(arr, RoleDataName.PhysicalDefence, sort)
    elseif chooseWeight == 6 then   -- 魔抗
        BattleUtil.SortByProp(arr, RoleDataName.MagicDefence, sort)
    elseif chooseWeight == 7 then   -- 对位及其相邻目标
        arr = RoleManager.GetNeighbor(role, chooseType)
    elseif chooseWeight == 8 then   -- 对位
        arr = RoleManager.GetArrAggroList(role, arr)
    end

    if chooseLimit == 6 then            --< 全体,优先4职业
        local tempArr = {}
        for i = 1, #arr do
            if arr[i].roleData.professionId == 4 then
                table.insert(tempArr, arr[i])
            end
        end
        for i = 1, #arr do
            if arr[i].roleData.professionId ~= 4 then
                table.insert(tempArr, arr[i])
            end
        end
        arr = tempArr
    elseif chooseLimit == 8 then        --< 除自己
        local tempArr = {}
        for _, r in ipairs(arr) do
            if not (r == role) then
                table.insert(tempArr, r)
            end
        end
        table.sort(tempArr, function(a, b)
            return a.position < b.position
        end)
        arr = tempArr
    elseif chooseLimit == 9 then        --< 全体,优先2职业
        local tempArr = {}
        for i = 1, #arr do
            if arr[i].roleData.professionId == 2 then
                table.insert(tempArr, arr[i])
            end
        end
        for i = 1, #arr do
            if arr[i].roleData.professionId ~= 2 then
                table.insert(tempArr, arr[i])
            end
        end
        arr = tempArr
    end

    local finalArr = {}


    --> 不随机按顺序
    if num == 0 then
        finalArr = arr
    else    
        for i = 1, num do
            if arr[i] then
                table.insert(finalArr, arr[i])
            end
        end
    end

    --> 刨除
    for i = #finalArr, 1, -1 do
        for j = 1, #excludeAttackList do
            if excludeAttackList[j].uid == finalArr[i].uid then
                table.remove(finalArr, i)
                break
            end
        end
    end

    if #finalArr <= 0 then
        return nil
    end

    if sort == 3 then   --< 随机类型
        local idx = Random.RangeInt(1, #finalArr)
        return finalArr[idx]
    else
        return finalArr[1]
    end
end


function BattleUtil.CreateBuffId(skill, index)
    local id = 0
    if skill.preAI then --主动技能生成buff
        id = skill.owner.uid * 10000 + index
    else --被动技能生成buff
        id = skill.owner.uid * 1000 + index
    end
    return id
end

-- 计算命中率
function BattleUtil.CalHit(atkRole, defRole)
    --命中率 = clamp(自身命中率-敌方闪避率,0,1)
    local hit = atkRole:GetRoleData(RoleDataName.Hit)
    local dodge = defRole:GetRoleData(RoleDataName.Dodge)

    local bHit = Random.Range01() <= clamp(hit - dodge, 0, 1)

    if bHit then
    else
        atkRole.Event:DispatchEvent(BattleEventName.RoleDodge)
        defRole.Event:DispatchEvent(BattleEventName.RoleBeDodge)
    end
    return bHit
end

-- 计算护盾
function BattleUtil.CalShield(atkRole, defRole, damage)
    for i=1, defRole.shield.size do
        local buff = defRole.shield.buffer[i]
        damage = buff:CountShield(damage, atkRole)
    end
    return damage
end
-- 提前计算护盾后伤害
function BattleUtil.PreCountShield(defRole, damage)
    for i=1, defRole.shield.size do
        local buff = defRole.shield.buffer[i]
        damage = buff:PreCountShield(damage)
    end
    return damage
end


-- 秒杀
function BattleUtil.Seckill(skill, atkRole, defRole)
    local damage = defRole:GetRoleData(RoleDataName.Hp)
    local finalDmg = defRole.data:SubValue(RoleDataName.Hp, damage)
    if finalDmg >= 0 then
        if defRole:GetRoleData(RoleDataName.Hp) <= 0 and not defRole:IsDead() then
            defRole:SetDead()
            defRole.Event:DispatchEvent(BattleEventName.RoleDead, atkRole)
            atkRole.Event:DispatchEvent(BattleEventName.RoleKill, defRole)
            --检测击杀后追击放技能
            atkRole.Event:DispatchEvent(BattleEventName.RoleKillSkillPursueAttackCheck, defRole)
            --检测击杀后追击普攻
            atkRole.Event:DispatchEvent(BattleEventName.RoleKillGeneralAttackPursueAttackCheck, defRole)
            BattleLogic.Event:DispatchEvent(BattleEventName.BattleRoleDead, defRole, atkRole)

            atkRole.Event:DispatchEvent(BattleEventName.Seckill, defRole)
            defRole.Event:DispatchEvent(BattleEventName.BeSeckill, atkRole)
            BattleLogic.Event:DispatchEvent(BattleEventName.Seckill, atkRole, defRole)
        end
        atkRole.Event:DispatchEvent(BattleEventName.RoleDamage, defRole, damage, false, finalDmg, 0, false, skill)
        defRole.Event:DispatchEvent(BattleEventName.RoleBeDamaged, atkRole, damage, false, finalDmg, 0, false, skill)
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleDamage, atkRole, defRole, damage, false, finalDmg, 0, false, skill)
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleBeDamaged, defRole, atkRole, damage, false, finalDmg, 0, false, skill)
        if skill then
            atkRole.Event:DispatchEvent(BattleEventName.RoleHit, defRole, damage, nil, finalDmg, nil, skill)
            --检测攻击时被动一次普攻
            atkRole.Event:DispatchEvent(BattleEventName.RoleHitGeneralAttackCheck, defRole, damage, nil, finalDmg, nil, skill)
            --检测连击事件
            atkRole.Event:DispatchEvent(BattleEventName.RoleHitDoubleHitCheck, defRole, damage, nil, finalDmg, nil, skill)
            defRole.Event:DispatchEvent(BattleEventName.RoleBeHit, atkRole, damage, nil, finalDmg, nil, skill)
        end
    end

end

-- 计算真实伤害
function BattleUtil.ApplyDamage(skill, atkRole, defRole, damage, bCrit, damageType, dotType, changeIsForbear)
    if defRole.position == 99999 or defRole.leader then
        return
    end
    bCrit = bCrit or false
    if atkRole.ctrl_seal then --封印 无法暴击
        bCrit = false       
    end
    --加入被动效果
    local damagingFunc = function(dmgDeduction)                 
        damage = floor(damage - dmgDeduction)
    end
    SYSLog(string.format("ApplyDamage  === damage: %s, damageType: %s,",tostring(damage),tostring(damageType)))
    atkRole.Event:DispatchEvent(BattleEventName.PassiveDamaging, damagingFunc, defRole, damage, skill, dotType, bCrit)
    defRole.Event:DispatchEvent(BattleEventName.PassiveBeDamaging, damagingFunc, atkRole, damage, skill, dotType, bCrit)
    BattleLogic.Event:DispatchEvent(BattleEventName.PassiveDamaging, damagingFunc, atkRole, defRole, damage, skill, dotType, bCrit)

    -- 计算护盾减伤    
    local beforeDamage = damage    
    damage = BattleUtil.CalShield(atkRole, defRole, damage)
    SYSLog(string.format("ApplyDamage CalShield  === damage: %s, damageType: %s,",tostring(damage),tostring(damageType)))
    local reduceSheild = beforeDamage - damage
    if reduceSheild > 0 then
        atkRole.Event:DispatchEvent(BattleEventName.ShildReduce, reduceSheild, defRole, damage, skill, dotType, bCrit)
        defRole.Event:DispatchEvent(BattleEventName.ShildBeReduce, reduceSheild, atkRole, damage, skill, dotType, bCrit)
        BattleLogic.Event:DispatchEvent(BattleEventName.ShildReduce, reduceSheild, atkRole, defRole, damage, skill, dotType, bCrit)
    end

    -- 造成的最终伤害
    local damagingFunc = function(dmgDeduction) 
        damage = floor(damage - dmgDeduction)
    end
    SYSLog(string.format("atkRole ApplyDamage final  === damage: %s, damageType: %s,",tostring(damage),tostring(damageType)))
    atkRole.Event:DispatchEvent(BattleEventName.FinalDamage, damagingFunc, defRole, damage, skill, dotType, bCrit, damageType)
    SYSLog(string.format(" defRole ApplyDamage final  === damage: %s, damageType: %s,",tostring(damage),tostring(damageType)))
    defRole.Event:DispatchEvent(BattleEventName.FinalBeDamage, damagingFunc, atkRole, damage, skill, dotType, bCrit, damageType)
    SYSLog(string.format(" BattleLogic ApplyDamage final  === damage: %s, damageType: %s,",tostring(damage),tostring(damageType)))
    BattleLogic.Event:DispatchEvent(BattleEventName.FinalDamage, damagingFunc, atkRole, defRole, damage, skill, dotType, bCrit, damageType)
    
    SYSLog(string.format("ApplyDamage CalShield final  === damage: %s, damageType: %s,",tostring(damage),tostring(damageType)))
    
    
    return BattleUtil.FinalDamage(skill, atkRole, defRole, damage, bCrit, damageType, dotType, changeIsForbear,reduceSheild)
end


--检测是否有是金翅大鹏有不灭效果
function BattleUtil.CheckIsNoDead(target)
    if target then
       return target:IsAssignHeroAndHeroStar(10086,10)==false and BattleLogic.BuffMgr:HasBuff(target,BuffName.NoDead)==false
    end
     return false
end



function BattleUtil.FinalDamage(skill, atkRole, defRole, damage, bCrit, damageType, dotType, changeIsForbear,reduceSheild)
    
    if damage < 0 then 
        damage = 0 
        SYSLog(string.format("FinalDamage final  === damage: %s, damageType: %s,",tostring(damage),tostring(damageType)))
    end
    local finalDmg = defRole.data:SubValue(RoleDataName.Hp, damage)    
    SYSLog(string.format("!!!!!!FinalDamage final  === damage: %s, damageType: %s,",tostring(damage),tostring(damageType)))
    if atkRole.ctrl_seal then --封印 无法暴击
        bCrit = false
        atkRole.Event:DispatchEvent(BattleEventName.RoleBeSeal, defRole, damage, bCrit, finalDmg, damageType, skill)
        defRole.Event:DispatchEvent(BattleEventName.RoleSeal, atkRole, damage, bCrit, finalDmg, damageType, skill)
    end

    if finalDmg >= 0 then
        if defRole:GetRoleData(RoleDataName.Hp) <= 0 and not defRole:IsDead() then
            defRole:SetDead()
            defRole.Event:DispatchEvent(BattleEventName.RoleDead, atkRole)
            atkRole.Event:DispatchEvent(BattleEventName.RoleKill, defRole, damage, bCrit, damageType, dotType, skill)
            --检测击杀后追击放技能
            atkRole.Event:DispatchEvent(BattleEventName.RoleKillSkillPursueAttackCheck, defRole, damage, bCrit, damageType, dotType, skill)
            --检测击杀后追击普攻
            atkRole.Event:DispatchEvent(BattleEventName.RoleKillGeneralAttackPursueAttackCheck, defRole, damage, bCrit, damageType, dotType, skill)
            BattleLogic.Event:DispatchEvent(BattleEventName.BattleRoleDead, defRole, atkRole)
        end

        --被伤害是要知道是不是受克制
        local isForbear, damageAdd, hitAdd = BattleUtil.CheckForbear(atkRole, defRole)
        isForbear = changeIsForbear == nil and isForbear or changeIsForbear
        atkRole.Event:DispatchEvent(BattleEventName.RoleDamage, defRole, damage, bCrit, finalDmg, damageType, dotType, skill,atkRole)
        defRole.Event:DispatchEvent(BattleEventName.RoleBeDamaged, atkRole, damage, bCrit, finalDmg, damageType, dotType, skill, isForbear,defRole,reduceSheild)
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleDamage, atkRole, defRole, damage, bCrit, finalDmg, damageType, dotType, skill)
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleBeDamaged, defRole, atkRole, damage, bCrit, finalDmg, damageType, dotType, skill,reduceSheild)
        
        if bCrit then
            atkRole.Event:DispatchEvent(BattleEventName.RoleCrit, defRole, damage, bCrit, finalDmg, damageType, skill)
            defRole.Event:DispatchEvent(BattleEventName.RoleBeCrit, atkRole, damage, bCrit, finalDmg, damageType, skill)
        end
        if skill then            
            atkRole.Event:DispatchEvent(BattleEventName.RoleHit, defRole, damage, bCrit, finalDmg, damageType, skill)
            --检测攻击时被动一次普攻
            atkRole.Event:DispatchEvent(BattleEventName.RoleHitGeneralAttackCheck, defRole, damage, bCrit, finalDmg, damageType, skill)
            --检测连击事件
            atkRole.Event:DispatchEvent(BattleEventName.RoleHitDoubleHitCheck, defRole, damage, bCrit, finalDmg, damageType, skill)
            defRole.Event:DispatchEvent(BattleEventName.RoleBeHit, atkRole, damage, bCrit, finalDmg, damageType, skill)
        end
    end

    --
    -- BattleLogManager.Log(
    --     "Final Damage",
    --     "acamp", atkRole.camp,
    --     "apos", atkRole.position,
    --     "tcamp", defRole.camp,
    --     "tpos", defRole.position,
    --     "damage", damage,
    --     "dotType", tostring(dotType)
    -- )

    
    return finalDmg, damage
end


--执行完整的命中，伤害，暴击计算，返回命中，暴击 simple不包含事件仅做计算用
function BattleUtil.CalSimpleDamage(skill, atkRole, defRole, damageType, baseFactor, ignoreDef, dotType,SimpleCaculate)
    
    if defRole.position == 99999 then
        return
    end
    -- 判断是否命中
    if skill and not skill:CheckTargetIsHit(defRole) then
        
        BattleLogic.Event:DispatchEvent(BattleEventName.HitMiss, atkRole, defRole, skill)
        atkRole.Event:DispatchEvent(BattleEventName.HitMiss, defRole, skill)
        defRole.Event:DispatchEvent(BattleEventName.BeHitMiss, atkRole, skill)
        return 0
    end
    -- 如果是队伍技能，计算真实伤害，则damageType为伤害值
    -- if atkRole.isTeam and not defRole:IsDead() then
    --     return BattleUtil.ApplyDamage(skill, atkRole, defRole, damageType), false
    -- end
    -- 计算技能额外伤害系数加成
    SYSLog(string.format("baseFactor 1  === baseFactor: %s",baseFactor))
    baseFactor = baseFactor or 1
    baseFactor = BattleUtil.ErrorCorrection(baseFactor)
    SYSLog(string.format("baseFactor 2  === baseFactor: %s",baseFactor))
    local baseDamage
    -- 防御（据伤害类型决定）
    --> damageType depracated    只有物防
    local defence = defRole:GetRoleData(RoleDataName.PhysicalDefence)
    -- if damageType == 1 then --1 物理 2 魔法
    --     defence = defRole:GetRoleData(RoleDataName.PhysicalDefence)
    -- else
    --     defence = defRole:GetRoleData(RoleDataName.MagicDefence)
    -- end
    -- 攻击力
    local attack = atkRole:GetRoleData(RoleDataName.Attack)
    -- 无视防御系数
    ignoreDef = 1 - (ignoreDef or 0)
    local onIgnoreDefFactor = function(outIgnoreDef)
        ignoreDef = 1 - math.max(0, outIgnoreDef)
    end
    -- 基础伤害 =  攻击力 - 防御力 
    -- baseDamage = max(attack - BattleUtil.FP_Mul(0.5, defence, ignoreDef), 0)
    -- baseDamage = max(attack - BattleUtil.FP_Mul(defence, ignoreDef), 0)

    baseDamage = attack * (1 - (BattleUtil.FP_Mul(defence, ignoreDef) / (defence + 598 + 2 * defRole:GetRoleData(RoleDataName.Level))))
    -- baseDamage = attack * (1 - (BattleUtil.FP_Mul(defence, ignoreDef) / (defence + GameSetting[1].DefenseLevvalue2 + GameSetting[1].DefenseLevvalue1 * defRole:GetRoleData(RoleDataName.Level))))

    -- 基础伤害增加系数         --< 伤害加成
    local addDamageFactor = atkRole:GetRoleData(RoleDataName.DamageBocusFactor) - defRole:GetRoleData(RoleDataName.DamageReduceFactor)

    -- 是否暴击： 暴击率 = 自身暴击率 - 对方抗暴率
    local bCrit = false
    local critRandom = Random.Range01()
    local critCondition = clamp(atkRole:GetRoleData(RoleDataName.Crit) - defRole:GetRoleData(RoleDataName.Tenacity), 0, 1)
    bCrit = critRandom <= critCondition
    bCrit = bCrit or defRole.isFlagCrit == true -- 必定暴击
    --< 封印状态大于必定暴击 锁死无法暴击
    if atkRole.ctrl_seal then bCrit=false end 
    defRole.Event:DispatchEvent(BattleEventName.FlagCritReset)

    --> 暴击抵抗 miss次数
    local onCritMiss = function(newbCrit)
        bCrit = newbCrit
    end
    -- 计算暴伤害系数
    local critDamageFactor = 0
    local critDamageReduceFactor = 0 -- 暴击伤害减免
    --计算暴击
    if bCrit then
        --加入被动效果 触发暴击被动
        local cl = {}
        local onCritDamageReduceFactor = function(v, ct) 
            if v then
                table.insert(cl, {v, ct})
            end
        end
        BattleLogic.Event:DispatchEvent(BattleEventName.CritDamageReduceFactor, onCritDamageReduceFactor, atkRole, defRole)
        critDamageReduceFactor = max(BattleUtil.CountChangeList(critDamageReduceFactor, cl), 0)

        -- 计算额外暴击伤害
        -- critDamageFactor = 1.3 + atkRole:GetRoleData(RoleDataName.CritDamageFactor) - critDamageReduceFactor
        critDamageFactor = max(atkRole:GetRoleData(RoleDataName.CritDamageFactor) - defRole:GetRoleData(RoleDataName.CriDamageReduceRate) - critDamageReduceFactor, 0)
        
    end
    
    local atkProFactor = 0
    local defProFactor = 0
    if defRole.professionId == 1 then       --< 防御
        atkProFactor = atkRole:GetRoleData(RoleDataName.DamageToDefender)
    elseif defRole.professionId == 2 then   --< 高爆
        atkProFactor = atkRole:GetRoleData(RoleDataName.DamageToMage)
    elseif defRole.professionId == 3 then   --< 穿甲
        atkProFactor = atkRole:GetRoleData(RoleDataName.DamageToFighter)
    elseif defRole.professionId == 4 then   --< 辅助
        atkProFactor = atkRole:GetRoleData(RoleDataName.DamageToHealer)
    end
    if atkRole.professionId == 1 then       --< 防御
        defProFactor = defRole:GetRoleData(RoleDataName.DefenceFromDefender)
    elseif atkRole.professionId == 2 then   --< 高爆
        defProFactor = defRole:GetRoleData(RoleDataName.DefenceFromMage)
    elseif atkRole.professionId == 3 then   --< 穿甲
        defProFactor = defRole:GetRoleData(RoleDataName.DefenceFromFighter)
    elseif atkRole.professionId == 4 then   --< 辅助
        defProFactor = defRole:GetRoleData(RoleDataName.DefenceFromHealer)
    end
    local professionFactor = atkProFactor - defProFactor

    --> 克制
    local isForbear, damageAdd, hitAdd = BattleUtil.CheckForbear(atkRole, defRole)
    local forbearFactor = 0
    if isForbear then
        forbearFactor = forbearFactor + damageAdd
    end

    -- 老公式
    --local fixDamage = floor(BattleUtil.FP_Mul(baseDamage, baseFactor, addDamageFactor, critDamageFactor))
    --> 修改公式
    --> 物
    -- (自己攻击 - 目标护甲)*(自己56暴击伤害 - 目标113暴击抵抗)*(自己114物伤加成/116法伤加成 - 目标115物伤减免/117法伤减免)
    -- *(1+ 自己职业伤害124\125\126\127 -目标职业减伤130\131\132\133)*(自己51伤害加成-目标52伤害减免）*(1+阵营克制系数)
    --> 法
    -- (自己攻击 - 目标护甲)*(自己56暴击伤害 - 目标113暴击抵抗)*(自己114物伤加成/116法伤加成 - 目标115物伤减免/117法伤减免)
    -- *(1+ 自己职业伤害124\125\126\127 -目标职业减伤130\131\132\133)*(1 + 自己123技能伤害)*(自己51伤害加成-目标52伤害减免）*(1+阵营克制系数)
    -- 老公式END

    local fixDamage = 0
    -- 公式伤害 = 基础伤害 * 基础伤害系数 * (1 + 增伤系数 + 爆伤系数 + 职业系数 + 物理损伤系数 + 克制系数)
    if damageType == 1 then
        local physicalDamageFactor = atkRole:GetRoleData(RoleDataName.PhysicalDamage) - defRole:GetRoleData(RoleDataName.PhysicalImmune)
        fixDamage = floor(BattleUtil.FP_Mul(baseDamage, baseFactor, (1 + addDamageFactor+critDamageFactor+professionFactor+physicalDamageFactor+forbearFactor)))
        SYSLog(string.format("damageType 1  === baseDamage: %s, baseFactor: %s, addDamageFactor: %s, critDamageFactor: %s, professionFactor: %s, physicalDamageFactor: %s, forbearFactor: %s",
        tostring(baseDamage), tostring(baseFactor), tostring(addDamageFactor), tostring(critDamageFactor), tostring(professionFactor), tostring(physicalDamageFactor), tostring(forbearFactor)))
    -- 公式伤害 = 基础伤害 * 基础伤害系数 * (1 +增伤系数 + 爆伤系数 + 职业系数 + 魔法损伤系数 + 技能 + 克制系数)
    elseif damageType == 2 then
        local magicDamageFactor = atkRole:GetRoleData(RoleDataName.MagicDamage) - defRole:GetRoleData(RoleDataName.MagicImmune)
        local skillFactor = atkRole:GetRoleData(RoleDataName.SkillDamage)
        fixDamage = floor(BattleUtil.FP_Mul(baseDamage, baseFactor, (1 + addDamageFactor+critDamageFactor+professionFactor+magicDamageFactor+skillFactor+forbearFactor)))
        SYSLog(string.format("damageType 2  === baseDamage: %s, baseFactor: %s, addDamageFactor: %s, critDamageFactor: %s, professionFactor: %s, magicDamageFactor: %s, skillFactor: %s, forbearFactor: %s",
        tostring(baseDamage), tostring(baseFactor), tostring(addDamageFactor), tostring(critDamageFactor), tostring(professionFactor), tostring(magicDamageFactor), tostring(skillFactor), tostring(forbearFactor)))
    end

    fixDamage = max(floor(attack * 0.1), fixDamage)

    if  SimpleCaculate  then --未计算护盾等返回的伤害指数 不触发伤害
        return fixDamage, bCrit
    end 

    local finalDmg = 0 --计算实际造成的扣血
    local dmg = 0 --< 造成伤害值
    if not defRole:IsRealDead()  then
        --finalDmg = BattleUtil.ApplyDamage(skill, atkRole, defRole, fixDamage, bCrit, damageType, dotType)
        finalDmg, dmg = BattleUtil.TriggerDamage(skill, atkRole, defRole, fixDamage, bCrit, damageType, dotType)
    end

    -- RoleManager.LogCa(
    --     "frame:"..BattleLogic.CurFrame(),
    --     "finalDmg:"..finalDmg,
    --     "bCrit:",bCrit,
    --     "dmg:",dmg
    -- )

    return finalDmg, bCrit, dmg
end




--执行完整的命中，伤害，暴击计算，返回命中，暴击
--skill造成伤害的技能 atkRole攻击者 defRole受击者 damageType伤害类型 baseFactor伤害系数 ignoreDef无视防御参数 dotType是持续伤害类型
function BattleUtil.CalDamage(skill, atkRole, defRole, damageType, baseFactor, ignoreDef, dotType)
    
    if defRole.position == 99999  or  defRole.position == 99 or defRole.leader then
        return
    end
    -- 判断是否命中
    if skill and not skill:CheckTargetIsHit(defRole) then
        
        BattleLogic.Event:DispatchEvent(BattleEventName.HitMiss, atkRole, defRole, skill)
        atkRole.Event:DispatchEvent(BattleEventName.HitMiss, defRole, skill)
        defRole.Event:DispatchEvent(BattleEventName.BeHitMiss, atkRole, skill)
        return 0
    end
    -- 如果是队伍技能，计算真实伤害，则damageType为伤害值
    -- if atkRole.isTeam and not defRole:IsDead() then
    --     return BattleUtil.ApplyDamage(skill, atkRole, defRole, damageType), false
    -- end
    -- 计算技能额外伤害系数加成
    SYSLog(string.format("baseFactor 1  === baseFactor: %s === attackrole: %s ",baseFactor,atkRole.roleId))
    baseFactor = baseFactor or 1
     -- 计算技能额外伤害系数加成
    SYSLog(string.format("baseFactor 2  === baseFactor: %s",baseFactor))
    local factorFunc = function(exFactor) baseFactor = baseFactor + exFactor end
    atkRole.Event:DispatchEvent(BattleEventName.RoleDamageBefore, defRole, factorFunc, damageType, skill,baseFactor,atkRole)
    defRole.Event:DispatchEvent(BattleEventName.RoleBeDamagedBefore, atkRole, factorFunc, damageType, skill,baseFactor,defRole)
    baseFactor = BattleUtil.ErrorCorrection(baseFactor)
    SYSLog(string.format("baseFactor 3  === baseFactor: %s",baseFactor))
    local baseDamage
    -- 防御（据伤害类型决定）
    --> damageType depracated    只有物防
    local defence = defRole:GetRoleData(RoleDataName.PhysicalDefence)
    -- if damageType == 1 then --1 物理 2 魔法
    --     defence = defRole:GetRoleData(RoleDataName.PhysicalDefence)
    -- else
    --     defence = defRole:GetRoleData(RoleDataName.MagicDefence)
    -- end
    -- 攻击力
    local attack = atkRole:GetRoleData(RoleDataName.Attack)
    -- 无视防御系数
    ignoreDef = 1 - (ignoreDef or 0)
    local onIgnoreDefFactor = function(outIgnoreDef)
        ignoreDef = 1 - math.max(0, outIgnoreDef)
    end
    atkRole.Event:DispatchEvent(BattleEventName.IgnoreDefFactor, onIgnoreDefFactor, atkRole, defRole)
    defRole.Event:DispatchEvent(BattleEventName.BeIgnoreDefFactor, onIgnoreDefFactor, atkRole, defRole)
    -- 基础伤害 =  攻击力 - 防御力 
    -- baseDamage = max(attack - BattleUtil.FP_Mul(0.5, defence, ignoreDef), 0)
    -- baseDamage = max(attack - BattleUtil.FP_Mul(defence, ignoreDef), 0)
    -- LogError(" defence:"..defence)
    baseDamage = attack * (1 - (BattleUtil.FP_Mul(defence, ignoreDef) / (defence + 598 + 2 * defRole:GetRoleData(RoleDataName.Level))))
    -- baseDamage = attack * (1 - (BattleUtil.FP_Mul(defence, ignoreDef) / (defence + GameSetting[1].DefenseLevvalue2 + GameSetting[1].DefenseLevvalue1 * defRole:GetRoleData(RoleDataName.Level))))
    -- LogError(" baseDamage:"..baseDamage)
    -- 基础伤害增加系数         --< 伤害加成
    local addDamageFactor = atkRole:GetRoleData(RoleDataName.DamageBocusFactor) - defRole:GetRoleData(RoleDataName.DamageReduceFactor)

    -- 是否暴击： 暴击率 = 自身暴击率 - 对方抗暴率
    local bCrit = false
    local critRandom = Random.Range01()
    local critCondition = clamp(atkRole:GetRoleData(RoleDataName.Crit) - defRole:GetRoleData(RoleDataName.Tenacity), 0, 1)
    bCrit = critRandom <= critCondition
    bCrit = bCrit or defRole.isFlagCrit == true -- 必定暴击
    if atkRole.ctrl_seal then --封印 无法暴击
        bCrit = false    
        atkRole.Event:DispatchEvent(BattleEventName.RoleBeSeal)   
    end
    defRole.Event:DispatchEvent(BattleEventName.FlagCritReset)

    --> 暴击抵抗 miss次数
    local onCritMiss = function(newbCrit)
        bCrit = newbCrit
    end
    atkRole.Event:DispatchEvent(BattleEventName.CritMiss, onCritMiss, atkRole, defRole, bCrit)
    defRole.Event:DispatchEvent(BattleEventName.BeCritMiss, onCritMiss, atkRole, defRole, bCrit)
    -- 计算暴伤害系数
    local critDamageFactor = 0
    local critDamageReduceFactor = 0 -- 暴击伤害减免
    --计算暴击
    if bCrit then
        --加入被动效果 触发暴击被动
        local cl = {}
        local onCritDamageReduceFactor = function(v, ct) 
            if v then
                table.insert(cl, {v, ct})
            end
        end
        atkRole.Event:DispatchEvent(BattleEventName.CritDamageReduceFactor, onCritDamageReduceFactor, atkRole, defRole)
        defRole.Event:DispatchEvent(BattleEventName.CritDamageReduceFactor, onCritDamageReduceFactor, atkRole, defRole)
        BattleLogic.Event:DispatchEvent(BattleEventName.CritDamageReduceFactor, onCritDamageReduceFactor, atkRole, defRole)
        critDamageReduceFactor = max(BattleUtil.CountChangeList(critDamageReduceFactor, cl), 0)

        -- 计算额外暴击伤害
        -- critDamageFactor = 1.3 + atkRole:GetRoleData(RoleDataName.CritDamageFactor) - critDamageReduceFactor
        critDamageFactor = max(atkRole:GetRoleData(RoleDataName.CritDamageFactor) - defRole:GetRoleData(RoleDataName.CriDamageReduceRate) - critDamageReduceFactor, 0)
        
        --加入被动效果 触发暴击被动
        local critFunc = function(critEx) critDamageFactor = critEx end
        atkRole.Event:DispatchEvent(BattleEventName.PassiveCriting, critFunc)
    end
    
    local atkProFactor = 0
    local defProFactor = 0
    if defRole.professionId == 1 then       --< 防御
        atkProFactor = atkRole:GetRoleData(RoleDataName.DamageToDefender)
    elseif defRole.professionId == 2 then   --< 高爆
        atkProFactor = atkRole:GetRoleData(RoleDataName.DamageToMage)
    elseif defRole.professionId == 3 then   --< 穿甲
        atkProFactor = atkRole:GetRoleData(RoleDataName.DamageToFighter)
    elseif defRole.professionId == 4 then   --< 辅助
        atkProFactor = atkRole:GetRoleData(RoleDataName.DamageToHealer)
    end
    if atkRole.professionId == 1 then       --< 防御
        defProFactor = defRole:GetRoleData(RoleDataName.DefenceFromDefender)
    elseif atkRole.professionId == 2 then   --< 高爆
        defProFactor = defRole:GetRoleData(RoleDataName.DefenceFromMage)
    elseif atkRole.professionId == 3 then   --< 穿甲
        defProFactor = defRole:GetRoleData(RoleDataName.DefenceFromFighter)
    elseif atkRole.professionId == 4 then   --< 辅助
        defProFactor = defRole:GetRoleData(RoleDataName.DefenceFromHealer)
    end
    local professionFactor = atkProFactor - defProFactor

    --> 克制
    local isForbear, damageAdd, hitAdd = BattleUtil.CheckForbear(atkRole, defRole)
    local forbearFactor = 0
    if isForbear then
        forbearFactor = forbearFactor + damageAdd
    end

    -- 老公式
    --local fixDamage = floor(BattleUtil.FP_Mul(baseDamage, baseFactor, addDamageFactor, critDamageFactor))
    --> 修改公式
    --> 物
    -- (自己攻击 - 目标护甲)*(自己56暴击伤害 - 目标113暴击抵抗)*(自己114物伤加成/116法伤加成 - 目标115物伤减免/117法伤减免)
    -- *(1+ 自己职业伤害124\125\126\127 -目标职业减伤130\131\132\133)*(自己51伤害加成-目标52伤害减免）*(1+阵营克制系数)
    --> 法
    -- (自己攻击 - 目标护甲)*(自己56暴击伤害 - 目标113暴击抵抗)*(自己114物伤加成/116法伤加成 - 目标115物伤减免/117法伤减免)
    -- *(1+ 自己职业伤害124\125\126\127 -目标职业减伤130\131\132\133)*(1 + 自己123技能伤害)*(自己51伤害加成-目标52伤害减免）*(1+阵营克制系数)
    -- 老公式END

    local fixDamage = 0
    -- 公式伤害 = 基础伤害 * 基础伤害系数 * (1 + 增伤系数 + 爆伤系数 + 职业系数 + 物理损伤系数 + 克制系数)
    if damageType == 1 then
        local physicalDamageFactor = atkRole:GetRoleData(RoleDataName.PhysicalDamage) - defRole:GetRoleData(RoleDataName.PhysicalImmune)
        fixDamage = floor(BattleUtil.FP_Mul(baseDamage, baseFactor, (1 + addDamageFactor+critDamageFactor+professionFactor+physicalDamageFactor+forbearFactor)))
        SYSLog(string.format("damageType 1  === baseDamage: %s, baseFactor: %s, addDamageFactor: %s, critDamageFactor: %s, professionFactor: %s, physicalDamageFactor: %s, forbearFactor: %s",
        tostring(baseDamage), tostring(baseFactor), tostring(addDamageFactor), tostring(critDamageFactor), tostring(professionFactor), tostring(physicalDamageFactor), tostring(forbearFactor)))
    -- 公式伤害 = 基础伤害 * 基础伤害系数 * (1 +增伤系数 + 爆伤系数 + 职业系数 + 魔法损伤系数 + 技能 + 克制系数)
    elseif damageType == 2 then
        local magicDamageFactor = atkRole:GetRoleData(RoleDataName.MagicDamage) - defRole:GetRoleData(RoleDataName.MagicImmune)
        local skillFactor = atkRole:GetRoleData(RoleDataName.SkillDamage)
        fixDamage = floor(BattleUtil.FP_Mul(baseDamage, baseFactor, (1 + addDamageFactor+critDamageFactor+professionFactor+magicDamageFactor+skillFactor+forbearFactor)))
        SYSLog(string.format("damageType 2  === baseDamage: %s, baseFactor: %s, addDamageFactor: %s, critDamageFactor: %s, professionFactor: %s, magicDamageFactor: %s, skillFactor: %s, forbearFactor: %s",
        tostring(baseDamage), tostring(baseFactor), tostring(addDamageFactor), tostring(critDamageFactor), tostring(professionFactor), tostring(magicDamageFactor), tostring(skillFactor), tostring(forbearFactor)))
    end

    -- 公式计算完成
    local damageFunc = function(damage) fixDamage = damage end
    atkRole.Event:DispatchEvent(BattleEventName.RoleDamageAfter, defRole, damageFunc, fixDamage)
    defRole.Event:DispatchEvent(BattleEventName.RoleBeDamagedAfter, atkRole, damageFunc, fixDamage)


    fixDamage = max(floor(attack * 0.1), fixDamage)


    local finalDmg = 0 --计算实际造成的扣血
    local dmg = 0 --< 造成伤害值
    if not defRole:IsRealDead() then
        --finalDmg = BattleUtil.ApplyDamage(skill, atkRole, defRole, fixDamage, bCrit, damageType, dotType)
        finalDmg, dmg = BattleUtil.TriggerDamage(skill, atkRole, defRole, fixDamage, bCrit, damageType, dotType)
    end

    -- RoleManager.LogCa(
    --     "frame:"..BattleLogic.CurFrame(),
    --     "finalDmg:"..finalDmg,
    --     "bCrit:",bCrit,
    --     "dmg:",dmg
    -- )

    return finalDmg, bCrit, dmg
end

function BattleUtil.TriggerDamage(skill, atkRole, defRole, damage, bCrit, damageType, dotType)
    if atkRole.ctrl_seal then --封印 无法暴击
        bCrit = false
    end
    --> 应对触发伤害 效果 被动
    local damagingFunc = function(dmgDeduction) 
        damage = damage - dmgDeduction 
    end
    SYSLog(string.format("TriggerDamage  === damage: %s, dmgDeduction: %s,",tostring(damage),tostring(damageType)))
    atkRole.Event:DispatchEvent(BattleEventName.TriggerDamaging, damagingFunc, defRole, damage, skill, dotType, bCrit)
    defRole.Event:DispatchEvent(BattleEventName.TriggerBeDamaging, damagingFunc, atkRole, damage, skill, dotType, bCrit)
    defRole.Event:DispatchEvent(BattleEventName.TriggerBeDamageEnd, damagingFunc, atkRole, damage, skill, dotType, bCrit)
    BattleLogic.Event:DispatchEvent(BattleEventName.TriggerDamaging, damagingFunc, atkRole, defRole, damage, skill, dotType, bCrit)
    return BattleUtil.ApplyDamage(skill, atkRole, defRole, damage, bCrit, damageType, dotType)
end

function BattleUtil.CalTreat(castRole, targetRole, value, baseFactor)
    if targetRole.ctrl_noheal or targetRole:IsDead() then --禁疗和死亡无法加血
        return
    end
    targetRole.Event:DispatchEvent(BattleEventName.RoleBeHealed, castRole)
    BattleUtil.ApplyTreat(castRole, targetRole, value, baseFactor)
end

function BattleUtil.ApplyTreat(castRole, targetRole, value, baseFactor)
    if targetRole.ctrl_noheal or targetRole:IsDead() then --禁疗和死亡无法加血
        return
    end
    baseFactor = baseFactor or 1
    local maxHp = targetRole:GetRoleData(RoleDataName.MaxHp)
    local hp = targetRole:GetRoleData(RoleDataName.Hp)

    -- 计算被动对治疗系数的影响
    local treatFactorFunc = function(df, dt)
        baseFactor = BattleUtil.CountValue(baseFactor, df, dt)
    end
    castRole.Event:DispatchEvent(BattleEventName.PassiveTreatingFactor, treatFactorFunc, targetRole)
    targetRole.Event:DispatchEvent(BattleEventName.PassiveBeTreatedFactor, treatFactorFunc, castRole)

    local factor = castRole:GetRoleData(RoleDataName.TreatFacter)
    local factor2 = targetRole:GetRoleData(RoleDataName.CureFacter)

    -- 是否修理暴击
    local bTreatCrit = false
    local critRandom = Random.Range01()
    local critCondition = clamp(castRole:GetRoleData(RoleDataName.HealCritical), 0, 1)
    bTreatCrit = critRandom <= critCondition
    
    local treatCritFactor = 1
    if bTreatCrit then
        treatCritFactor = 1 + castRole:GetRoleData(RoleDataName.HealCriEffect)
    end

    -- local baseTreat = BattleUtil.FP_Mul(value, baseFactor, factor, factor2)
    --> 改
    --> 自己攻击(即治疗value) * (1+自己58治疗加成 + 目标57受疗加成)*自己129治疗暴击效果
    local baseTreat = BattleUtil.FP_Mul(value, baseFactor, (1 + factor + factor2), treatCritFactor)

    --加入被动效果
    local cl = {}
    local function treatingFunc(v, ct)
        if v then
            table.insert(cl, {v, ct})
        end
    end
    -- local treatingFunc = function(exFactor) baseTreat = floor(baseTreat * (exFactor + 1) + 0.5) end
    castRole.Event:DispatchEvent(BattleEventName.PassiveTreating, treatingFunc, targetRole)
    targetRole.Event:DispatchEvent(BattleEventName.PassiveBeTreated, treatingFunc, castRole)
    baseTreat = BattleUtil.CountChangeList(baseTreat, cl)


    -- 取整
    local baseTreat = floor(baseTreat + 0.5)
    -- LogError("baseTreat:"..baseTreat)
    local treat = min(baseTreat, maxHp - hp)
    if treat > 0 then
        targetRole.data:AddValue(RoleDataName.Hp, treat)
    end
        castRole.Event:DispatchEvent(BattleEventName.RoleTreat, targetRole, treat, baseTreat)
        targetRole.Event:DispatchEvent(BattleEventName.RoleBeTreated, castRole, treat, baseTreat)
    -- else
    --     targetRole.data:AddValue(RoleDataName.Hp, 0)
    --     castRole.Event:DispatchEvent(BattleEventName.RoleTreat, targetRole, 0, 0)
    --     targetRole.Event:DispatchEvent(BattleEventName.RoleBeTreated, castRole, 0, 0)
    
    
    


    --
    -- BattleLogManager.Log(
    --     "Final Damage",
    --     "acamp", castRole.camp,
    --     "apos", castRole.position,
    --     "tcamp", targetRole.camp,
    --     "tpos", targetRole.position,
    --     "value", value
    -- )
end



-- 检测命中
function BattleUtil.CheckIsHit(atkRole, defRole)
    -- 是否命中： 命中 = 自身命中率 - 对方闪避率
    local isHit = false
    local hitRandom = Random.Range01()
            
    --> 克制
    local isForbear, damageAdd, hitAdd = BattleUtil.CheckForbear(atkRole, defRole)
    local addHit = 0
    if isForbear then
        addHit = addHit + hitAdd
    end
    local hitCondition = clamp(atkRole:GetRoleData(RoleDataName.Hit) + addHit - defRole:GetRoleData(RoleDataName.Dodge), 0, 1)
    isHit = hitRandom <= hitCondition
    --如果攻击方和防守方是同一阵营  直接命中
    isHit = atkRole.camp == defRole.camp and true or isHit
    return isHit
end

--> 克制
function BattleUtil.CheckForbear(atkRole, defRole)
    local damageAdd = 0.25
    local hitAdd = 0.2
    -- 1 Y系
    -- 2 S系
    -- 3 F系
    -- 4 M系
    -- 5 D系
    local arrForbear = {[1] = 3, [2] = 1, [3] = 2, [4] = 5, [5] = 4}
    local tempChecker = nil
    local ChangeForbear=function(forceBear)
        tempChecker = forceBear
    end
    atkRole.Event:DispatchEvent(BattleEventName.RoleCheckForbear, atkRole,defRole,ChangeForbear)
    defRole.Event:DispatchEvent(BattleEventName.RoleBeCheckForbear, atkRole,defRole,ChangeForbear)
    if tempChecker ~= nil then
        return tempChecker,damageAdd, hitAdd
    end
    if atkRole and defRole then
        return arrForbear[atkRole.element] == defRole.element, damageAdd, hitAdd
    else
        return false, damageAdd, hitAdd
    end
end


function BattleUtil.RandomAction(rand, action)
    if Random.Range01() <= rand and action then
        action()
        return true
    end
    return false
end

function BattleUtil.RandomAction2(rand, action)
    if BattleLogic.RoundRandom <= rand and action then
        action()
        return true
    end
    return false
end

-- 
function BattleUtil.RandomControl(rand, ctrl, caster, target, round)
 
    local cl = {}
    local function _CallBack(v, ct)
        if v then
            table.insert(cl, {v, ct})
        end
    end
    caster.Event:DispatchEvent(BattleEventName.PassiveRandomControl, _CallBack, ctrl, target)
    target.Event:DispatchEvent(BattleEventName.PassiveBeRandomControl, _CallBack, ctrl, target)
    --> 技能控制几率 + 自己118控制几率 - 目标119控制抵抗
    rand = BattleUtil.CountChangeList(rand, cl) + caster:GetRoleData(RoleDataName.ControlProbability) - target:GetRoleData(RoleDataName.ControlResist)
    
    --修改最终控制几率
    local function fixControl(deRand)
        rand = deRand
    end    
    caster.Event:DispatchEvent(BattleEventName.PassiveRandomFinalControl, fixControl, rand, ctrl, target)
    target.Event:DispatchEvent(BattleEventName.PassiveBeRandomFinalControl, fixControl,rand, ctrl, target)

    return BattleUtil.RandomAction(rand, function()
        local buff = Buff.Create(caster, BuffName.Control, round, ctrl)
 
        target:AddBuff(buff)
    end)
end

-- 
function BattleUtil.RandomDot(rand, dot, caster, target, round, interval, damage, func)
    
    local cl = {}
    local dcl = {}
    local function _CallBack(v, ct, dv, dct)
        if v then
            table.insert(cl, {v, ct})
        end
        if dv then
            table.insert(dcl, {dv, dct})
        end
    end


    caster.Event:DispatchEvent(BattleEventName.PassiveRandomDot, _CallBack, dot)
    target.Event:DispatchEvent(BattleEventName.PassiveBeRandomDot, _CallBack, dot)
    rand = BattleUtil.CountChangeList(rand, cl)
    damage = BattleUtil.CountChangeList(damage, dcl)

    return BattleUtil.RandomAction(rand, function()
        local buff = Buff.Create(caster, BuffName.DOT, round, interval, dot, damage)
        if func then func(buff) end
        target:AddBuff(buff)
    end)
end


function BattleUtil.RandomList(arr)
    if #arr <= 1 then return end
    local index
    for i=#arr, 1, -1 do
        index = Random.RangeInt(1, i)
        arr[i], arr[index] = arr[index], arr[i]
    end
end

function BattleUtil.Sort(arr, comp)
    if #arr <= 1 then return arr end
    for i=1, #arr do
        for j = #arr, i+1, -1 do
            if comp(arr[j-1], arr[j]) then
                arr[j-1], arr[j] = arr[j], arr[j-1]
            end
        end
    end
    return arr
end

function BattleUtil.GetPropertyName(type)
    if type == 1 then
        return RoleDataName.Strength
    elseif type == 2 then
        return RoleDataName.Energy
    elseif type == 3 then
        return RoleDataName.Vitality
    elseif type == 4 then
        return RoleDataName.Dexterity
    elseif type == 5 then
        return RoleDataName.Speed
    elseif type == 6 then
        return RoleDataName.PhysicalAttack
    elseif type == 7 then
        return RoleDataName.MagicAttack
    elseif type == 8 then
        return RoleDataName.PhysicalDefence
    elseif type == 9 then
        return RoleDataName.MagicDefence
    end
end

function BattleUtil.GetHPPencent(role)
    return role:GetRoleData(RoleDataName.Hp) / role:GetRoleData(RoleDataName.MaxHp)
end

-- 计算数值
function BattleUtil.CountValue(v1, v2, ct)
    local v = v1
    if ct == 1 then --加算
        v = v + v2
    elseif ct == 2 then --乘加算（百分比属性加算）
        v = v * (1 + v2)
    elseif ct == 3 then --减算
        v = v - v2
    elseif ct == 4 then --乘减算（百分比属性减算）
        v = v * (1 - v2)
    elseif ct == 5 then -- 覆盖
        v = v2
    end
    -- 做一个正确性检测
    -- v = BattleUtil.ErrorCorrection(v)
    return v
end

-- 计算数值改变
function BattleUtil.CountChangeList(v, changeList)
    local aplist = {}
    local splist = {}
    local cplist = {}
    local fv = v
    -- 先算绝对值
    for _, change in ipairs(changeList) do
        local cv = change[1]
        local ct = change[2]
        if ct then
            if ct == 1 or ct == 3 then
                fv = BattleUtil.CountValue(fv, cv, ct)
            elseif ct == 2 then
                table.insert(aplist, change)
            elseif ct == 4 then
                table.insert(splist, change)
            elseif ct == 5 then
                table.insert(cplist, change)
            end
        end
    end
    -- 加乘(对基数进行加乘)
    for _, change in ipairs(aplist) do
        local cv = change[1]
        local ct = change[2]
        fv = fv + (BattleUtil.CountValue(v, cv, ct) - v)
    end
    -- 减乘(对最终数值进行减乘算)
    for _, change in ipairs(splist) do
        local cv = change[1]
        local ct = change[2]
        fv = BattleUtil.CountValue(fv, cv, ct)
    end
    -- 覆盖
    for _, change in ipairs(cplist) do
        local cv = change[1]
        local ct = change[2]
        fv = BattleUtil.CountValue(fv, cv, ct)
    end
    return fv
end

-- 检测技能伤害治疗加乘
function BattleUtil.CheckSkillDamageHeal(f, caster, target)
    
    local cl = {}
    local function _CallBack(v, ct)
        if v then
            table.insert(cl, {v, ct})
        end
    end
    caster.Event:DispatchEvent(BattleEventName.PassiveSkillDamageHeal, _CallBack)
    target.Event:DispatchEvent(BattleEventName.PassiveBeSkillDamageHeal, _CallBack)
    f = BattleUtil.CountChangeList(f, cl)

    return f
end

-- 检测技能伤害治疗加乘
function BattleUtil.CheckSeckill(bf, kf, caster, target)
    
    local bcl = {}
    local kcl = {}
    local function _CallBack(bv, bct, kv, kct)
        if bv and bct then
            table.insert(bcl, {bv, bct})
        end
        if kv and kct then
            table.insert(kcl, {kv, kct})
        end
    end
    caster.Event:DispatchEvent(BattleEventName.PassiveSeckill, _CallBack)
    target.Event:DispatchEvent(BattleEventName.PassiveBeSeckill, _CallBack)
    bf = BattleUtil.CountChangeList(bf, bcl)
    kf = BattleUtil.CountChangeList(kf, kcl)

    return bf, kf
end


-- 获取位置类型
-- 1 前排
-- 2 后排
function BattleUtil.GetRolePosType(pos)
    if pos <= 3 then
        return 1
    elseif pos > 3 then
        return 2
    end
end

-- 根据位置类型获取数据
function BattleUtil.GetRoleListByPosType(camp, posType)
    if posType == 1 then
        return RoleManager.Query(function (r) return r.camp == camp and r.position <= 3 end)
    elseif posType == 2 then
        return RoleManager.Query(function (r) return r.camp == camp and r.position > 3 end)
    end
end


-- 通用增加属性的方法
function BattleUtil.AddProp(role, prop, value, ct)
    if ct == 1 then --加算
        role.data:AddValue(BattlePropList[prop], value)
    elseif ct == 2 then --乘加算（百分比属性加算）
        role.data:AddPencentValue(BattlePropList[prop], value)
    elseif ct == 3 then --减算
        role.data:SubValue(BattlePropList[prop], value)
    elseif ct == 4 then --乘减算（百分比属性减算）
        role.data:SubPencentValue(BattlePropList[prop], value)
    end
end

--> 还原属性
function BattleUtil.RevertProp(role, prop, value, ct)
    if ct == 3 or ct == 4 then
        role.data:AddValue(BattlePropList[prop], value)
    elseif ct == 2 then
        role.data:SubPencentValue(BattlePropList[prop], value)
    else
        role.data:SubDeltaValue(BattlePropList[prop], value)
    end
end

-- 规范基础伤害效果修改方法
function  BattleUtil.ChangeBaseSkillDamage(role,percent,damagetype,ct)
    -- 由于仅修改原始参数每次修改会叠加 所以增加镜像数据镜像为原始数据不会修改
        local tempBaseDamgePercent = 1
        local tempBaseDamgeType = 1
        for i=9, #role.skillArrayBase[1] do
            local v = role.skillArrayBase[1][i]
            for j=2, #v do 
                for k=2, #v[j] do
                    if k == 2 then 
                        tempBaseDamgePercent = v[j][k]
                    elseif k == 3 then
                        tempBaseDamgeType = v[j][k] 
                    end
                end
            end
        end

        for i=9, #role.skillArray[1] do
            local v = role.skillArray[1][i]
            for j=2, #v do 
                for k=2, #v[j] do
                    if k == 2 then 
                        if ct == 1 then --加算
                            v[j][k] = tempBaseDamgePercent + percent
                        elseif ct == 2 then --乘加算（百分比属性加算）
                            v[j][k] = tempBaseDamgePercent + floor(tempBaseDamgePercent * percent)
                        elseif ct == 3 then --减算
                            v[j][k] = tempBaseDamgePercent - percent
                        elseif ct == 4 then --乘减算（百分比属性减算）
                            v[j][k] = tempBaseDamgePercent - floor(tempBaseDamgePercent * percent)
                        end
                        v[j][k] = tempBaseDamgePercent  * percent; --会叠加
                    elseif k == 3 then
                        v[j][k] = damagetype;
                        end
                end
            end
        end
end

-- 规范基础伤害效果修改方法
function  BattleUtil.ChangeSkillArrayDamage(skillArray,percent,damagetype,ct)
    -- 由于仅修改原始参数每次修改会叠加 所以增加镜像数据镜像为原始数据不会修改
        local tempBaseDamgePercent = 1
        local tempBaseDamgeType = 1
        local skillArrayBase = BattleUtil.cloneTable(skillArray)
        for i=9, #skillArrayBase[1] do
            local v =skillArrayBase[1][i]
            for j=2, #v do 
                for k=2, #v[j] do
                    if k == 2 then 
                        tempBaseDamgePercent = v[j][k]
                    elseif k == 3 then
                        tempBaseDamgeType = v[j][k] 
                    end
                end
            end
        end

        for i=9, #skillArray[1] do
            local v = skillArray[1][i]
            for j=2, #v do 
                for k=2, #v[j] do
                    if k == 2 then 
                        if ct == 1 then --加算
                            v[j][k] = tempBaseDamgePercent + percent
                        elseif ct == 2 then --乘加算（百分比属性加算）
                            v[j][k] = tempBaseDamgePercent + floor(tempBaseDamgePercent * percent)
                        elseif ct == 3 then --减算
                            v[j][k] = tempBaseDamgePercent - percent
                        elseif ct == 4 then --乘减算（百分比属性减算）
                            v[j][k] = tempBaseDamgePercent - floor(tempBaseDamgePercent * percent)
                        end
                        v[j][k] = tempBaseDamgePercent  * percent; --会叠加
                    elseif k == 3 then
                        v[j][k] = damagetype;
                        end
                end
            end
        end
        return skillArray
end


-- 规范基础伤害效果还原方法 基础伤害固定只有2个参数 参照effect 1
function  BattleUtil.RevertBaseSkillDamage(role)
    -- 由于仅修改原始参数每次修改会叠加 所以增加镜像数据镜像为原始数据不会修改
        local tempBaseDamgePercent = 1
        local tempBaseDamgeType = 1
        for i=9, #role.skillArrayBase[1] do
            local v = role.skillArrayBase[1][i]
            for j=2, #v do 
                for k=2, #v[j] do
                    if k == 2 then 
                        tempBaseDamgePercent = v[j][k]
                    elseif k == 3 then
                        tempBaseDamgeType = v[j][k] 
                    end
                end
            end
        end

        for i=9, #role.skillArray[1] do
            local v = role.skillArray[1][i]
            for j=2, #v do 
                for k=2, #v[j] do
                    if k == 2 then 
                       v[j][k] = tempBaseDamgePercent                     
                    elseif k == 3 then
                        v[j][k] = tempBaseDamgeType;
                    end
                end
            end
        end
end

--> 条件下增加属性
function BattleUtil.AddPropOnFunc(role, prop, value, ct,func)
    if func and func(role) then
        BattleUtil.AddProp(role, prop, value, ct)
    end
end

--> 条件下还原属性
function BattleUtil.RevertPropOnFunc(role, prop, value, ct,func)
    if func and func(role) then
        BattleUtil.RevertProp(role, prop, value, ct)
    end
end

-- 触发某一方法后注销此方法 -- 方法统一参数 @role @args 
function BattleUtil.TirggerOnceAtEvent(role,func,_tirggerBattleEventName,args)
    local SubFunc 
    SubFunc = function()
        if func then func(role,args) end
        role.Event:RemoveEvent(_tirggerBattleEventName, SubFunc)
    end
    role.Event:AddEvent(_tirggerBattleEventName, SubFunc)
end

--克隆表单
function BattleUtil.cloneTable(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local newObject = {}
        lookup_table[object] = newObject
        for key, value in pairs(object) do
            newObject[_copy(key)] = _copy(value)
        end
        return setmetatable(newObject, getmetatable(object))
    end
    return _copy(object)
end

-- 逻辑回合触发某一方法后注销此方法 -- 方法统一参数 @role @args 
function BattleUtil.LogicTrigerOnceAtEvent(role,func,_tirggerBattleEventName,args)
    local SubFunc 
    SubFunc = function()
        if func then func(role,args) end
        BattleLogic.Event:RemoveEvent(_tirggerBattleEventName, SubFunc)
    end
    BattleLogic.Event:AddEvent(_tirggerBattleEventName, SubFunc)
end

function BattleUtil.GetRoleSpeedList()
    local arr = RoleManager.Query(function(role) return true end,false)
    table.sort(arr, function(a, b)
        return a:GetRoleData(RoleDataName.Speed) > b:GetRoleData(RoleDataName.Speed) 
    end)
    local temp = {}
    -- for i=1,#arr do
    --     if not BattleLogic.IsinRecordPos( arr[i].position) then
    --         table.insert(temp,arr[i]) 
    --     end
    -- end
    for i=1,#arr do
        -- if BattleLogic.IsinRecordPos( arr[i].position) then
            table.insert(temp,arr[i]) 
        -- end
    end
    return temp
end

-- 重置回合状态 用于增加行动数
function BattleUtil.ResetRoundToRoundingOnce()    
    local ResetTibuRound
    ResetTibuRound =function (isHave,nullNum,ReCheckRound)
        ReCheckRound(true,nullNum-1)
        BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundCheck, ResetTibuRound)
    end
    BattleLogic.Event:AddEvent(BattleEventName.BattleRoundCheck, ResetTibuRound)
end

