BattleUtil = {}
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
--> 数量最多列
function BattleUtil.GetMaxCol(arr)
    local tempArr = {0, 0, 0}
    for _, role in ipairs(arr) do
        local idx = role.position % 3 + 1
        tempArr[idx] = tempArr[idx] + 1
    end
    local maxV = -1
    local maxIdx = 1
    for k, v in ipairs(tempArr) do
        if v > maxV then
            maxV = v
            maxIdx = k
        end
    end
    return maxIdx - 1
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

-- 
function BattleUtil.ChooseTarget(role, chooseId)
    WYLog("chooseId")
    WYLog(chooseId)
    local chooseType = floor(chooseId / 100000) % 10
    local chooseLimit = floor(chooseId / 10000) % 10
    local chooseWeight =  floor(chooseId / 100) % 100
    local sort = floor(chooseId / 10) % 10
    local num = chooseId % 10
    local arr
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
    else
        arr = RoleManager.Query()
    end

    --选择范围
    if chooseLimit == 0 then --选择全体不做任何操作

    elseif chooseLimit == 1 then-- 前排
        local tempArr = BattleUtil.ChooseFRow(arr)
        if #tempArr == 0 then   -- 没有选择后排
            tempArr = BattleUtil.ChooseBRow(arr)
        end
        arr = tempArr
    elseif chooseLimit == 2 then-- 后排
        local tempArr = BattleUtil.ChooseBRow(arr)
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
            if not r == role then
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

    if sort == 3 then       --< 3随机（可重复，单体最多被选3次）
        local randArr = {}
        local randtimes = num == 0 and #arr or num
        local randTimesArr = {}
        for i = 1, #arr do
            table.insert(randTimesArr, 0)
        end
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

    
    

    -- table.sort(finalArr, function(a, b)
    --     return a.position < b.position 
    -- end)

    return finalArr
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
            defRole.Event:DispatchEvent(BattleEventName.RoleBeHit, atkRole, damage, nil, finalDmg, nil, skill)
        end
    end
end

-- 计算真实伤害
function BattleUtil.ApplyDamage(skill, atkRole, defRole, damage, bCrit, damageType, dotType)
    LogGreen("BattleUtil.ApplyDamage")
    bCrit = bCrit or false
    damageType = damageType or 0

    -- if atkRole.isTeam then
    --     --max（技能基础伤害*（1+已方异妖伤害加成-目标异妖伤害减免），30%×技能基础伤害）
    --     local arr = RoleManager.Query(function (r) return r.camp == atkRole.camp end)
    --     local n = 0
    --     for i=1, #arr do
    --         n = n + arr[i]:GetRoleData(RoleDataName.TeamDamageBocusFactor)
    --     end
    --     damage = floor(max(damage * (1 + n / #arr - defRole:GetRoleData(RoleDataName.TeamDamageReduceFactor)), 0.3 * damage))
    -- end

    --加入被动效果
    local damagingFunc = function(dmgDeduction) 
        damage = damage - dmgDeduction 
    end
    atkRole.Event:DispatchEvent(BattleEventName.PassiveDamaging, damagingFunc, defRole, damage, skill, dotType, bCrit)
    defRole.Event:DispatchEvent(BattleEventName.PassiveBeDamaging, damagingFunc, atkRole, damage, skill, dotType, bCrit)
    BattleLogic.Event:DispatchEvent(BattleEventName.PassiveDamaging, damagingFunc, atkRole, defRole, damage, skill, dotType, bCrit)

    -- 计算护盾减伤
    damage = BattleUtil.CalShield(atkRole, defRole, damage)

    -- 造成的最终伤害
    local damagingFunc = function(dmgDeduction) 
        damage = damage - dmgDeduction 
    end
    atkRole.Event:DispatchEvent(BattleEventName.FinalDamage, damagingFunc, defRole, damage, skill, dotType, bCrit, damageType)
    defRole.Event:DispatchEvent(BattleEventName.FinalBeDamage, damagingFunc, atkRole, damage, skill, dotType, bCrit, damageType)
    BattleLogic.Event:DispatchEvent(BattleEventName.FinalDamage, damagingFunc, atkRole, defRole, damage, skill, dotType, bCrit, damageType)

    -- 
    return BattleUtil.FinalDamage(skill, atkRole, defRole, damage, bCrit, damageType, dotType)
end


--检测是否有是金翅大鹏有不灭效果
function BattleUtil.CheckIsNoDead(target)
    if target then
       return target:IsAssignHeroAndHeroStar(10086,10)==false and BattleLogic.BuffMgr:HasBuff(target,BuffName.NoDead)==false
    end
     return false
end



function BattleUtil.FinalDamage(skill, atkRole, defRole, damage, bCrit, damageType, dotType)
    LogGreen("BattleUtil.FinalDamage")
    if damage < 0 then damage = 0 end
    local finalDmg = defRole.data:SubValue(RoleDataName.Hp, damage)
    if finalDmg >= 0 then
        if defRole:GetRoleData(RoleDataName.Hp) <= 0 and not defRole:IsDead() then
            defRole:SetDead()
            defRole.Event:DispatchEvent(BattleEventName.RoleDead, atkRole)
            atkRole.Event:DispatchEvent(BattleEventName.RoleKill, defRole, damage)
            BattleLogic.Event:DispatchEvent(BattleEventName.BattleRoleDead, defRole, atkRole)
        end

        atkRole.Event:DispatchEvent(BattleEventName.RoleDamage, defRole, damage, bCrit, finalDmg, damageType, dotType, skill)
        defRole.Event:DispatchEvent(BattleEventName.RoleBeDamaged, atkRole, damage, bCrit, finalDmg, damageType, dotType, skill)
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleDamage, atkRole, defRole, damage, bCrit, finalDmg, damageType, dotType, skill)
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleBeDamaged, defRole, atkRole, damage, bCrit, finalDmg, damageType, dotType, skill)
        if bCrit then
            atkRole.Event:DispatchEvent(BattleEventName.RoleCrit, defRole, damage, bCrit, finalDmg, damageType, skill)
            defRole.Event:DispatchEvent(BattleEventName.RoleBeCrit, atkRole, damage, bCrit, finalDmg, damageType, skill)
        end
        if skill then
            atkRole.Event:DispatchEvent(BattleEventName.RoleHit, defRole, damage, bCrit, finalDmg, damageType, skill)
            defRole.Event:DispatchEvent(BattleEventName.RoleBeHit, atkRole, damage, bCrit, finalDmg, damageType, skill)
        end
    end

    --
    BattleLogManager.Log(
        "Final Damage",
        "acamp", atkRole.camp,
        "apos", atkRole.position,
        "tcamp", defRole.camp,
        "tpos", defRole.position,
        "damage", damage,
        "dotType", tostring(dotType)
    )
    
    return finalDmg
end

--执行完整的命中，伤害，暴击计算，返回命中，暴击
--skill造成伤害的技能 atkRole攻击者 defRole受击者 damageType伤害类型 baseFactor伤害系数 ignoreDef无视防御参数 dotType是持续伤害类型
function BattleUtil.CalDamage(skill, atkRole, defRole, damageType, baseFactor, ignoreDef, dotType)
    LogGreen("BattleUtil.CalDamage")
    -- 判断是否命中
    if skill and not skill:CheckTargetIsHit(defRole) then
        LogGreen("HitMiss")
        BattleLogic.Event:DispatchEvent(BattleEventName.HitMiss, atkRole, defRole, skill)
        atkRole.Event:DispatchEvent(BattleEventName.HitMiss, defRole, skill)
        defRole.Event:DispatchEvent(BattleEventName.BeHitMiss, atkRole, skill)
        return 0
    end
    -- 如果是队伍技能，计算真实伤害，则damageType为伤害值
    if atkRole.isTeam and not defRole:IsDead() then
        return BattleUtil.ApplyDamage(skill, atkRole, defRole, damageType), false
    end
    -- 计算技能额外伤害系数加成
    baseFactor = baseFactor or 1
    local factorFunc = function(exFactor) baseFactor = baseFactor + exFactor end
    atkRole.Event:DispatchEvent(BattleEventName.RoleDamageBefore, defRole, factorFunc, damageType, skill)
    defRole.Event:DispatchEvent(BattleEventName.RoleBeDamagedBefore, atkRole, factorFunc, damageType, skill)
    baseFactor = BattleUtil.ErrorCorrection(baseFactor)

    local baseDamage
    -- 防御（据伤害类型决定）
    local defence = 0
    if damageType == 1 then --1 物理 2 魔法
        defence = defRole:GetRoleData(RoleDataName.PhysicalDefence)
    else
        defence = defRole:GetRoleData(RoleDataName.MagicDefence)
    end
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
    baseDamage = max(attack - BattleUtil.FP_Mul(0.5, defence, ignoreDef), 0)

    -- 基础伤害增加系数
    local addDamageFactor = 1 + atkRole:GetRoleData(RoleDataName.DamageBocusFactor) - defRole:GetRoleData(RoleDataName.DamageReduceFactor)

    -- 是否暴击： 暴击率 = 自身暴击率 - 对方抗暴率
    local bCrit = false
    local critRandom = Random.Range01()
    local critCondition = clamp(atkRole:GetRoleData(RoleDataName.Crit) - defRole:GetRoleData(RoleDataName.Tenacity), 0, 1)
    bCrit = critRandom <= critCondition
    bCrit = bCrit or defRole.isFlagCrit == true -- 必定暴击

    -- 计算暴伤害系数
    local critDamageFactor = 1
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
        critDamageFactor = 1.3 + atkRole:GetRoleData(RoleDataName.CritDamageFactor) - critDamageReduceFactor
        
        --加入被动效果 触发暴击被动
        local critFunc = function(critEx) critDamageFactor = critEx end
        atkRole.Event:DispatchEvent(BattleEventName.PassiveCriting, critFunc)
    end

    -- 公式伤害 = 基础伤害 * 基础伤害系数 * 增伤系数 * 爆伤系数
    local fixDamage = floor(BattleUtil.FP_Mul(baseDamage, baseFactor, addDamageFactor, critDamageFactor))

    -- 公式计算完成
    local damageFunc = function(damage) fixDamage = damage end
    atkRole.Event:DispatchEvent(BattleEventName.RoleDamageAfter, defRole, damageFunc, fixDamage)
    defRole.Event:DispatchEvent(BattleEventName.RoleBeDamagedAfter, atkRole, damageFunc, fixDamage)


    fixDamage = max(floor(attack * 0.1), fixDamage)


    local finalDmg = 0 --计算实际造成的扣血
    if not defRole:IsRealDead() then
        finalDmg = BattleUtil.ApplyDamage(skill, atkRole, defRole, fixDamage, bCrit, damageType, dotType)
    end
    return finalDmg, bCrit
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

    local factor = castRole.isTeam and 1 or castRole:GetRoleData(RoleDataName.TreatFacter) --释放者为team则不计算治疗加成属性
    local factor2 = targetRole:GetRoleData(RoleDataName.CureFacter)
    local baseTreat = BattleUtil.FP_Mul(value, baseFactor, factor, factor2)

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

    local treat = min(baseTreat, maxHp - hp)
    if treat > 0 then
        targetRole.data:AddValue(RoleDataName.Hp, treat)
    end
    castRole.Event:DispatchEvent(BattleEventName.RoleTreat, targetRole, treat, baseTreat)
    targetRole.Event:DispatchEvent(BattleEventName.RoleBeTreated, castRole, treat, baseTreat)

    --
    BattleLogManager.Log(
        "Final Damage",
        "acamp", castRole.camp,
        "apos", castRole.position,
        "tcamp", targetRole.camp,
        "tpos", targetRole.position,
        "value", value
    )
end



-- 检测命中
function BattleUtil.CheckIsHit(atkRole, defRole)
    -- 是否命中： 命中 = 自身命中率 - 对方闪避率
    local isHit = false
    local hitRandom = Random.Range01()
    LogGreen("命中率")
    LogGreen(atkRole:GetRoleData(RoleDataName.Hit))
    LogGreen(atkRole:GetRoleData(RoleDataName.Dodge))
    local hitCondition = clamp(atkRole:GetRoleData(RoleDataName.Hit) - defRole:GetRoleData(RoleDataName.Dodge), 0, 1)
    isHit = hitRandom <= hitCondition
    return isHit
end




function BattleUtil.RandomAction(rand, action)
    if Random.Range01() <= rand and action then
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
    rand = BattleUtil.CountChangeList(rand, cl)

    return BattleUtil.RandomAction(rand, function()
        local buff = Buff.Create(caster, BuffName.Control, round, ctrl)
        target:AddBuff(buff)
    end)
end

-- 
function BattleUtil.RandomDot(rand, dot, caster, target, round, interval, damage)
    
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
        buff.isRealDamage = true
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