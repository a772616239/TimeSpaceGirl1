local floor = math.floor
local max = math.max
local min = math.min
--local RoleDataName = RoleDataName
--local BattleLogic = BattleLogic
--local BattleUtil = BattleUtil
--local BattleEventName = BattleEventName
--local BuffName = BuffName

--属性编号
-- local BattlePropList = {
--     RoleDataName.Attack,
--     RoleDataName.PhysicalDefence,
--     RoleDataName.MagicDefence,
--     RoleDataName.Speed,
--     RoleDataName.DamageBocusFactor,
--     RoleDataName.DamageReduceFactor,
--     RoleDataName.Hit,
--     RoleDataName.Dodge,
--     RoleDataName.Crit,
--     RoleDataName.CritDamageFactor,
--     RoleDataName.TreatFacter,
--     RoleDataName.MaxHp,
--     RoleDataName.Hp,
--     RoleDataName.CureFacter,
--     RoleDataName.Tenacity,
--     RoleDataName.InitRage,
-- }
PassiveManager = {}
PassiveManager.passiveCountList = {
    [0] = {},
    [1] = {}
}
function PassiveManager.Init()
    PassiveManager.passiveCountList = {
        [0] = {},
        [1] = {}
    }
end

local NormalMaxLayer = 100000

local function clearBuffPredicate(buff, type)
    local flag = false
    if type == 1 then --持续恢复
        flag = buff.type == BuffName.HOT
    elseif type == 2 then --护盾
        flag = buff.type == BuffName.Shield
    elseif type == 3 then --增益状态
        flag = buff.isBuff == true
    elseif type == 4 then --减益状态
        flag = buff.isDeBuff == true
    elseif type == 5 then --持续伤害
        flag = buff.type == BuffName.DOT
    elseif type == 6 then --负面状态（控制状态、减益状态和持续伤害状态）
        flag = buff.type == BuffName.Control or buff.isDeBuff or buff.type == BuffName.DOT
    end
    return flag
end


--被动技能表
local passivityList = {
    --发动技能时，[a]的概率将[b]*[c]算作[d]计算
    --a[float],b[属性],c[float],d[属性]
    [1] = function(role, args)
        local f1 = args[1]
        local pro1 = args[2]
        local f2 = args[3]
        local pro2 = args[4]

        local OnSkillCast = function(skill)
            BattleUtil.RandomAction(f1, function ()
                local duration = 0
                for i=1, skill.effectList.size do
                    duration = max(duration, skill.effectList.buffer[i].duration)
                end
                role:AddPropertyTransfer(BattlePropList[pro1], f2, BattlePropList[pro2], 2, duration + BattleLogic.GameDeltaTime * 2)
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)
    end,

    --发动技能后，[a]的概率对敌方随机1名施加攻击*[c]的[d]伤害。
    --a[float],c[float],d[伤害类型]
    [2] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local dt = args[3]

        local OnSkillCastEnd = function(skill)
            BattleUtil.RandomAction(f1, function ()
                local arr = BattleUtil.ChooseTarget(role, 20001)
                if arr[1] then
                    BattleUtil.CalDamage(nil, role, arr[1], dt, f2)
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --发动技能后，[c]使仇恨目标受到治疗效果降低[a]，持续[b]
    --a[float],b[int],c[float]
    [3] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local f3 = args[3]

        local OnSkillCastEnd = function(skill)
            BattleUtil.RandomAction(f3, function ()
                local arr = BattleUtil.ChooseTarget(role, 40000)
                if arr[1] then
                    arr[1]:AddBuff(Buff.Create(role, BuffName.PropertyChange, f2, RoleDataName.CureFacter, f1, 3))
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --发动技能后，[d]改变自身[a]属性[b],持续[c]秒
    --a[属性],b[float],c[int],d[改变类型]
    [4] = function(role, args)
        local pro = args[1]
        local f1 = args[2]
        local f2 = args[3]
        local ct = args[4]

        local OnSkillCastEnd = function(skill)
            role:AddBuff(Buff.Create(role, BuffName.PropertyChange, f2, BattlePropList[pro], f1, ct))
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --发动技能后，[a]的概率回复攻击最高的1人的[b]*[c]血量，持续[d]秒。
    --a[float],b[属性],c[float],d[int]
    [5] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local f2 = args[3]
        local f3 = args[4]

        local OnSkillCastEnd = function(skill)
            BattleUtil.RandomAction(f1, function ()
                local arr = BattleUtil.ChooseTarget(role, 10321)
                if arr[1] then
                    local val = floor(BattleUtil.FP_Mul(f2, role:GetRoleData(BattlePropList[pro])))
                    arr[1]:AddBuff(Buff.Create(role, BuffName.HOT, f3, 1, val))
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --发动技能后，[a]的概率提升随机角色的[b]*[c]的[d]，持续[e]秒。
    --a[float],b[属性],c[float],d[属性],e[int]
    [6] = function(role, args)
        local f1 = args[1]
        local pro1 = args[2]
        local f2 = args[3]
        local pro2 = args[4]
        local f3 = args[5]

        local OnSkillCastEnd = function(skill)
            BattleUtil.RandomAction(f1, function ()
                local arr = BattleUtil.ChooseTarget(role, 10001)
                if arr[1] then
                    local val = floor(BattleUtil.FP_Mul(f2, role:GetRoleData(BattlePropList[pro1])))
                    arr[1]:AddBuff(Buff.Create(role, BuffName.PropertyChange, f3, BattlePropList[pro2], val, 1))
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --使用回复技能时，[a]的概率提高恢复效果[b]。
    --a[float],b[float]
    [7] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]

        local OnPassiveTreating = function(treatingFunc)
            BattleUtil.RandomAction(f1, function ()
                treatingFunc(f2, CountTypeName.AddPencent)
            end)
        end
        role.Event:AddEvent(BattleEventName.PassiveTreating, OnPassiveTreating)
    end,

    --受击后,[a]的概率，回复自身的[b]*[c]的血量
    --a[float],b[属性],c[float]
    [8] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local f2 = args[3]

        local OnBeHit = function(treatingFunc)
            BattleUtil.RandomAction(f1, function ()
                local val = floor(BattleUtil.FP_Mul(f2, role:GetRoleData(BattlePropList[pro])))
                BattleUtil.CalTreat(role, role, val)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)
    end,

    --受击后，[a]对攻击者造成的攻击*[c]的持续伤害，持续[d]秒。
    --a[float],c[float],d[int]
    [9] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local f3 = args[3]

        local triggerUid = {}
        local OnBeHit = function(atkRole)
            if atkRole.isTeam then
                return
            end
            if triggerUid[atkRole.uid] then --加入限定避免循环触发
                return
            end
            BattleUtil.RandomAction(f1, function ()
                atkRole:AddBuff(Buff.Create(role, BuffName.DOT, f3, 1, 0, 1, f2))
                triggerUid[atkRole.uid] = atkRole.uid
                BattleLogic.WaitForTrigger(f3+1, function ()
                    triggerUid[atkRole.uid] = nil
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)
    end,

    --受击时[e]，[a]的概率将[b]*[c]算作[d]计算
    --a[float],b[属性],c[float],d[属性],e[伤害类型]
    [10] = function(role, args)
        local f1 = args[1]
        local pro1 = args[2]
        local f2 = args[3]
        local pro2 = args[4]
        local dt = args[5]

        local OnRoleBeDamagedBefore = function(atkRole, func, damageType)
            if damageType == dt then
                BattleUtil.RandomAction(f1, function ()
                    role:AddPropertyTransfer(BattlePropList[pro1], f2, BattlePropList[pro2], 2, BattleLogic.GameDeltaTime)
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamagedBefore, OnRoleBeDamagedBefore)
    end,

    --受击时，有[a]的概率抵消[b]*[c]的攻击。
    --a[float],b[属性],c[float]
    [11] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local f2 = args[3]

        local OnPassiveDamaging = function(damagingFunc, atkRole, damage)
            BattleUtil.RandomAction(f1, function ()
                damagingFunc(floor(BattleUtil.FP_Mul(f2, role:GetRoleData(BattlePropList[pro]))))
            end)
        end
        role.Event:AddEvent(BattleEventName.PassiveBeDamaging, OnPassiveDamaging)
    end,

    --受击后，有[a]的概率对敌方全体造成攻击*[c]的[d]伤害
    --a[float],c[float],d[伤害类型]
    [12] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local dt = args[3]

        local lastTrigger = 0
        local OnBeHit = function(atkRole)
            if atkRole.isTeam then
                return
            end
            lastTrigger = lastTrigger + 1
            if lastTrigger > 1 then --加入限定避免循环触发
                return
            end
            BattleUtil.RandomAction(f1, function ()
                local arr = BattleUtil.ChooseTarget(role, 20000)
                for i=1, #arr do
                    BattleUtil.CalDamage(nil, role, arr[i], dt, f2)
                end
            end)
            lastTrigger = 0
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)
    end,

    --受击后，有[a]的概率对随机1人造成[b]*[c]的真实伤害。
    --a[float],b[属性],c[float]
    [13] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local f2 = args[3]

        local lastTrigger = 0
        local OnBeHit = function(atkRole)
            if atkRole.isTeam then
                return
            end
            lastTrigger = lastTrigger + 1
            if lastTrigger > 1 then --加入限定避免循环触发
                return
            end
            BattleUtil.RandomAction(f1, function ()
                local arr = BattleUtil.ChooseTarget(role, 20001)
                if arr[1] then
                    local val = floor(BattleUtil.FP_Mul(f2, role:GetRoleData(BattlePropList[pro])))
                    BattleUtil.ApplyDamage(nil, role, arr[1], val)
                end
            end)
            lastTrigger = 0
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)
    end,

    --受击后[f]，[a]的概率将[b]*[c]算作[d]计算，持续[e]秒。
    --a[float],b[属性],c[float],d[属性],e[int],f[伤害类型]
    [14] = function(role, args)
        local f1 = args[1]
        local pro1 = args[2]
        local f2 = args[3]
        local pro2 = args[4]
        local f3 = args[5]
        local dt = args[6]

        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
            if damageType == dt then
                BattleUtil.RandomAction(f1, function ()
                    role:AddPropertyTransfer(BattlePropList[pro1], f2, BattlePropList[pro2], 2, f3)
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)
    end,

    --免疫[a]属性伤害。
    --a[属性类型]
    [15] = function(role, args)
        local pt = args[1]
        local elementDamageReduceFactor
        if pt == 1 then
            elementDamageReduceFactor = RoleDataName.FireDamageReduceFactor
        elseif pt == 2 then
            elementDamageReduceFactor = RoleDataName.WindDamageReduceFactor
        elseif pt == 3 then
            elementDamageReduceFactor = RoleDataName.IceDamageReduceFactor
        elseif pt == 4 then
            elementDamageReduceFactor = RoleDataName.LandDamageReduceFactor
        elseif pt == 5 then
            elementDamageReduceFactor = RoleDataName.LightDamageReduceFactor
        elseif pt == 6 then
            elementDamageReduceFactor = RoleDataName.DarkDamageReduceFactor
        end
        role.data:AddValue(elementDamageReduceFactor, 10000)
    end,

    --发动技能后，[a]的概率将[b]*[c]算作[d]计算，持续[e]秒。
    --a[float],b[属性],c[float],d[属性],e[int]
    [16] = function(role, args)
        local f1 = args[1]
        local pro1 = args[2]
        local f2 = args[3]
        local pro2 = args[4]
        local f3 = args[5]

        local OnSkillCastEnd = function(skill)
            BattleUtil.RandomAction(f1, function ()
                role:AddPropertyTransfer(BattlePropList[pro1], f2, BattlePropList[pro2], 2, f3)
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --发动技能后，[d]改变仇恨目标[a]属性[b],持续[c]秒
    --a[属性],b[int],c[int],d[改变类型]
    [17] = function(role, args)
        local pro1 = args[1]
        local f1 = args[2]
        local f2 = args[3]
        local ct = args[4]

        local OnSkillCastEnd = function(skill)
            local arr = BattleUtil.ChooseTarget(role, 40000)
            if arr[1] then
                arr[1]:AddBuff(Buff.Create(role, BuffName.PropertyChange, f2, BattlePropList[pro1], f1, ct))
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --发动技能后，[d]改变己方全体[a]属性[b],持续[c]秒
    --a[属性],b[int],c[int],d[改变类型]
    [18] = function(role, args)
        local pro1 = args[1]
        local f1 = args[2]
        local f2 = args[3]
        local ct = args[4]

        local OnSkillCastEnd = function(skill)
            local arr = BattleUtil.ChooseTarget(role, 10000)
            for i=1, #arr do
                arr[i]:AddBuff(Buff.Create(role, BuffName.PropertyChange, f2, BattlePropList[pro1], f1, ct))
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --受到治疗效果提高[a]。
    --a[float]
    [19] = function(role, args)
        local f1 = args[1]
        role.data:AddValue(RoleDataName.CureFacter, f1)
    end,

    --[b]造成的持续伤害时间延长[a]。
    --a[int],b[改变类型]
    [20] = function(role, args)
        local f1 = args[1]
        local ct = args[2]

        local OnBuffCaster = function(buff)
            if buff.type == BuffName.DOT then
                if ct == 1 then --加算
                    buff.duration = buff.duration + f1
                elseif ct == 2 then --乘加算（百分比属性加算）
                    buff.duration = buff.duration * (1 + f1)
                elseif ct == 3 then --减算
                    buff.duration = buff.duration - f1
                elseif ct == 4 then --乘减算（百分比属性减算）
                    buff.duration = buff.duration * (1 - f1)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.BuffCaster, OnBuffCaster)
    end,

    --自身增益效果超过[a]时，技能伤害提升[b]。
    --a[int],b[float]
    [21] = function(role, args)
        local i1 = args[1]
        local f1 = args[2]

        local count = 0
        local targetBuff
        local active = count > i1
        local OnBuffStart = function(buff)
            if buff.isBuff then
                count = count + 1
                if count > i1 and not active then
                    active = true
                    targetBuff = Buff.Create(role, BuffName.PropertyChange, 0, RoleDataName.DamageBocusFactor, f1, 1)
                    targetBuff.isBuff = false --自身不算增益
                    role:AddBuff(targetBuff)
                end
            end
        end
        local OnBuffEnd = function(buff)
            if buff.isBuff then
                count = count - 1
                if count <= i1 and active then
                    active = false
                    if targetBuff then
                        targetBuff.disperse = true
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.BuffStart, OnBuffStart)
        role.Event:AddEvent(BattleEventName.BuffEnd, OnBuffEnd)
    end,

    --血量低于[a]时，[b]概率触发控制免疫，持续[c]秒。每场战斗只能触发1次。
    --a[float],b[float],c[int]
    [22] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local f3 = args[3]

        local triggerCount = 0
        local OnBeHit = function(atkRole)
            if BattleUtil.GetHPPencent(role) < f1 then
                if triggerCount < 1 then
                    BattleUtil.RandomAction(f2, function ()
                        role:AddBuff(Buff.Create(role, BuffName.Immune, f3, 1))
                        triggerCount = triggerCount + 1
                    end)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)
    end,

    --死亡时，立即回复己方全体[a]*[b]的血量。
    --a[属性],b[float]
    [23] = function(role, args)
        local pro = args[1]
        local f1 = args[2]

        local OnDead = function(atkRole)
            local arr = BattleUtil.ChooseTarget(role, 10000)
            for i=1, #arr do
                local val = floor(BattleUtil.FP_Mul(f1, role:GetRoleData(BattlePropList[pro])))
                BattleUtil.CalTreat(role, arr[i], val)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDead, OnDead)
    end,

    --控制效果命中后，[a]的概率施加[c]的[d]伤害
    --a[float],c[float],d[伤害类型]
    [24] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local dt = args[3]

        local OnBuffCaster = function(buff)
            if buff.type == BuffName.Control then
                BattleUtil.RandomAction(f1, function ()
                    BattleUtil.CalDamage(nil, role, buff.target, dt, f2)
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.BuffCaster, OnBuffCaster)
    end,

    --控制效果命中后，[a]对全体造成[c]的[d]伤害。
    --a[float],c[float],d[伤害类型]
    [25] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local dt = args[3]

        local OnBuffCaster = function(buff)
            if buff.type == BuffName.Control then
                BattleUtil.RandomAction(f1, function ()
                    local arr = BattleUtil.ChooseTarget(buff.target, 10000)
                    for i=1, #arr do
                        BattleUtil.CalDamage(nil, role, arr[i], dt, f2)
                    end
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.BuffCaster, OnBuffCaster)
    end,

    --造成的伤害暴击后，[a]施加攻击*[c]的[d]持续伤害，持续[e]秒。
    --a[float],c[float],d[伤害类型],e[int]
    [26] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local dt = args[3]
        local f3 = args[4]

        local triggerUid = {}
        local OnRoleCrit = function(defRole)
            if triggerUid[defRole.uid] then --加入限定避免循环触发
                return
            end
            BattleUtil.RandomAction(f1, function ()
                defRole:AddBuff(Buff.Create(role, BuffName.DOT, f3, 1, 0, dt, f2))
                triggerUid[defRole.uid] = defRole.uid
                BattleLogic.WaitForTrigger(f3+1, function ()
                    triggerUid[defRole.uid] = nil
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleCrit, OnRoleCrit)
    end,

    --造成的伤害暴击后，[a]的概率回复自身[b]*[c]的血量
    --a[float],b[属性],c[float]
    [27] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local f2 = args[3]

        local OnRoleCrit = function(defRole)
            BattleUtil.RandomAction(f1, function ()
                local val = floor(BattleUtil.FP_Mul(f2, role:GetRoleData(BattlePropList[pro])))
                BattleUtil.CalTreat(role, role, val)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleCrit, OnRoleCrit)
    end,

    --对血量高于[a]的敌人伤害提高[b]。
    --a[float],b[float]
    [28] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]

        local OnPassiveDamaging = function(damagingFunc, defRole, damage)
            if BattleUtil.GetHPPencent(defRole) > f1 then
                damagingFunc(-floor(f2 * damage))
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
    end,

    --对血量低于[a]的敌人伤害提高[b]。
    --a[float],b[float]
    [29] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]

        local OnPassiveDamaging = function(damagingFunc, defRole, damage)
            if BattleUtil.GetHPPencent(defRole) < f1 then
                damagingFunc(-floor(f2 * damage))
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
    end,

    --发动技能后，[d]改变敌方全体[a]属性[b],持续[c]秒
    --a[属性],b[float],c[int],d[改变类型]
    [30] = function(role, args)
        local pro = args[1]
        local f1 = args[2]
        local f2 = args[3]
        local ct = args[4]

        local OnSkillCastEnd = function(skill)
            local arr = BattleUtil.ChooseTarget(role, 20000)
            for i=1, #arr do
                arr[i]:AddBuff(Buff.Create(role, BuffName.PropertyChange, f2, BattlePropList[pro], f1, ct))
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --发动技能后，有[a]的概率眩晕敌方其中1人，持续[b]秒。
    --a[float],b[int]
    [31] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]

        local OnSkillCastEnd = function(skill)
            local arr = BattleUtil.ChooseTarget(role, 20001)
            if arr[1] then
                BattleUtil.RandomControl(f1, 1, role, arr[1], f2)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --持续伤害效果命中后，[d]改变自身[a]属性[b],持续[c]秒
    --a[属性],b[float],c[int],d[改变类型]
    [32] = function(role, args)
        local pro = args[1]
        local f1 = args[2]
        local f2 = args[3]
        local ct = args[4]

        local OnBuffCaster = function(buff)
            if buff.type == BuffName.DOT then
                role:AddBuff(Buff.Create(role, BuffName.PropertyChange, f2, BattlePropList[pro], f1, ct))
            end
        end
        role.Event:AddEvent(BattleEventName.BuffCaster, OnBuffCaster)
    end,

    --[d]改变自身[a]属性[b],持续[c]秒
    --a[属性],b[float],c[int],d[改变类型]
    [33] = function(role, args)
        local pro = args[1]
        local f1 = args[2]
        local f2 = args[3]
        local ct = args[4]

        role:AddBuff(Buff.Create(role, BuffName.PropertyChange, f2, BattlePropList[pro], f1, ct))
    end,

    --造成伤害时，额外增加[a]点伤害。
    --a[int]
    [34] = function(role, args)
        local f1 = args[1]

        local OnPassiveDamaging = function(damagingFunc)
            damagingFunc(-f1)
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
    end,

    --进入战斗[a]秒后，造成的伤害提升[b]，持续[c]秒
    --a[int],b[float],c[int]
    [35] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local f3 = args[3]

        BattleLogic.WaitForTrigger(f1, function ()
            role:AddBuff(Buff.Create(role, BuffName.PropertyChange, f3, RoleDataName.DamageBocusFactor, f2, 1))
        end)
    end,

    --进入战斗[a]秒后，[d]改变[b]属性[c]，持续[e]秒
    --a[int],b[属性],c[int],d[改变类型],e[int]
    [36] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local f2 = args[3]
        local ct = args[4]
        local f3 = args[5]

        BattleLogic.WaitForTrigger(f1, function ()
            role:AddBuff(Buff.Create(role, BuffName.PropertyChange, f3, BattlePropList[pro], f2, ct))
        end)
    end,

    --进入战斗[a]秒后，免疫控制效果，持续[b]秒
    --a[int],b[int]
    [37] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]

        BattleLogic.WaitForTrigger(f1, function ()
            role:AddBuff(Buff.Create(role, BuffName.Immune, f2, 1))
        end)
    end,

    --每[a]秒，[d]改变[b]的[c]，[g改变[e]的[f]，最高叠加[h]层 (举例:每5秒，扣除10%的生命，提高5%的速度, 最高叠加5层)
    --a[int],b[float],c[属性],d[改变类型],e[float],f[属性],g[改变类型],h[int]
    [38] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local pro1 = args[3]
        local ct1 = args[4]
        local f3 = args[5]
        local pro2 = args[6]
        local ct2 = args[7]
        local i1 = args[8]

        local auraBuff = Buff.Create(role, BuffName.Aura, 0, function (r)
            local changeBuff1 = Buff.Create(r, BuffName.PropertyChange, 0, BattlePropList[pro1], f2, ct1)
            changeBuff1.cover = true
            changeBuff1.maxLayer = i1

            local changeBuff2 = Buff.Create(r, BuffName.PropertyChange, 0, BattlePropList[pro2], f3, ct2)
            changeBuff2.cover = true
            changeBuff2.maxLayer = i1

            r:AddBuff(changeBuff1)
            r:AddBuff(changeBuff2)
        end)
        auraBuff.interval = f1
        role:AddBuff(auraBuff)
    end,

    --进入战斗后，每[a]秒回复[b]生命
    --a[int],b[int]
    [39] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]

        local auraBuff = Buff.Create(role, BuffName.Aura, 0, function (r)
            BattleUtil.CalTreat(r, r, f2)
        end)
        auraBuff.interval = f1
        role:AddBuff(auraBuff)
    end,

    --被指定[a]造成伤害时，回复[b]生命
    --a[职业],b[int]
    [40] = function(role, args)
        local i1 = args[1]
        local f1 = args[2]

        local OnBeHit = function(atkRole)
            if atkRole.isTeam then
                return
            end
            if atkRole.roleData.professionId == i1 then
                BattleUtil.CalTreat(role, role, f1)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)
    end,

    --造成伤害时，将伤害的[a]%转化为自身生命
    --a[float]
    [41] = function(role, args)
        local f1 = args[1]

        local OnDamage = function(defRole, damage, bCrit, finalDmg)
            BattleUtil.CalTreat(role, role, floor(f1 * finalDmg))
        end
        role.Event:AddEvent(BattleEventName.RoleDamage, OnDamage)
    end,

    --造成暴击伤害时，有[a]的概率造成[b]的暴击伤害。
    --a[float],b[float]
    [42] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]

        local OnPassiveCriting = function(crit)
            BattleUtil.RandomAction(f1, function ()
                crit(f2)
            end)
        end
        role.Event:AddEvent(BattleEventName.PassiveCriting, OnPassiveCriting)
    end,

    --发动技能后，[d]改变仇恨目标[a]属性[b]，持续整场战斗，属性最多可改变[c]
    --a[属性],b[float],c[float],d[改变类型]
    [43] = function(role, args)
        local pro = args[1]
        local f1 = args[2]
        local i1 = args[3]
        local ct = args[4]

        local OnSkillCastEnd = function(skill)
            local arr = BattleUtil.ChooseTarget(role, 40000)
            if arr[1] then
                local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[pro], f1, ct)
                buff.cover = true
                buff.maxLayer = i1
                arr[1]:AddBuff(buff)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --发动技能后，[a]的概率[e]改变自身[b]属性[c]，持续[d]秒。
    --a[float],b[属性],c[float],d[int],e[改变类型]
    [44] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local f2 = args[3]
        local f3 = args[4]
        local ct = args[5]

        local OnSkillCastEnd = function(skill)
            BattleUtil.RandomAction(f1, function ()
                role:AddBuff(Buff.Create(role, BuffName.PropertyChange, f3, BattlePropList[pro], f2, ct))
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --免疫[a]次[b]控制状态。
    --a[int],b[控制类型]
    [45] = function(role, args)
        local i1 = args[1]
        local ct = args[2]
        local triggerCount = 0
        role.buffFilter:Add(function(buff)
            local isTarget = buff.type == BuffName.Control and (ct == 0 or buff.ctrlType == ct)
            if isTarget then
                triggerCount = triggerCount + 1
                return i1 == 0 or (i1 > 0 and triggerCount <= i1)
            else
                return isTarget
            end
        end)
    end,

    --免疫[a]持续伤害状态。
    --a[持续伤害类型]
    [46] = function(role, args)
        local dt = args[1]
        role.buffFilter:Add(function(buff)
            return buff.type == BuffName.DOT and (dt == 0 or buff.damageType == dt)
        end)
    end,

    --战斗中，[c]改变[a]属性[b]。
    --a[属性],b[float],c[改变类型]
    [47] = function(role, args)
        local pro = args[1]
        local f1 = args[2]
        local ct = args[3]

        if ct == 1 then --加算
            role.data:AddValue(BattlePropList[pro], f1)
        elseif ct == 2 then --乘加算（百分比属性加算）
            role.data:AddPencentValue(BattlePropList[pro], f1)
        elseif ct == 3 then --减算
            role.data:SubValue(BattlePropList[pro], f1)
        elseif ct == 4 then --乘减算（百分比属性减算）
            role.data:SubPencentValue(BattlePropList[pro], f1)
        end
    end,

    --战斗中，[c]改变[a]属性[b]，[f]改变[d]属性[e]。
    --a[属性],b[float],c[改变类型],d[属性],e[float],f[改变类型]
    [48] = function(role, args)
        local pro = args[1]
        local f1 = args[2]
        local ct = args[3]
        local pro2 = args[4]
        local f2 = args[5]
        local ct2 = args[6]

        if ct == 1 then --加算
            role.data:AddValue(BattlePropList[pro], f1)
        elseif ct == 2 then --乘加算（百分比属性加算）
            role.data:AddPencentValue(BattlePropList[pro], f1)
        elseif ct == 3 then --减算
            role.data:SubValue(BattlePropList[pro], f1)
        elseif ct == 4 then --乘减算（百分比属性减算）
            role.data:SubPencentValue(BattlePropList[pro], f1)
        end

        if ct2 == 1 then --加算
            role.data:AddValue(BattlePropList[pro2], f2)
        elseif ct2 == 2 then --乘加算（百分比属性加算）
            role.data:AddPencentValue(BattlePropList[pro2], f2)
        elseif ct2 == 3 then --减算
            role.data:SubValue(BattlePropList[pro2], f2)
        elseif ct2 == 4 then --乘减算（百分比属性减算）
            role.data:SubPencentValue(BattlePropList[pro2], f2)
        end
    end,

    --发动技能后，[a]概率[e]改变敌方全体[b]属性[c],持续[d]秒
    --a[float],b[属性],c[float],d[int],e[改变类型]
    [49] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local f2 = args[3]
        local f3 = args[4]
        local ct = args[5]

        local OnSkillCastEnd = function(skill)
            BattleUtil.RandomAction(f1, function ()
                local arr = BattleUtil.ChooseTarget(role, 20000)
                for i=1, #arr do
                    arr[i]:AddBuff(Buff.Create(role, BuffName.PropertyChange, f3, BattlePropList[pro], f2, ct))
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --战斗中，每[a]秒增加[b]%的异妖能量
    --a[int],b[float]
    [50] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]

        local auraBuff = Buff.Create(role, BuffName.Aura, 0, function (r)
            --BattleLogic.AddMP(role.camp, f2 * 100)
        end)
        auraBuff.interval = f1
        BattleLogic.BuffMgr:AddBuff(role, auraBuff)
    end,

    --战斗中，初始拥有[a]%的异妖能量
    --a[float]
    [51] = function(role, args)
        local f1 = args[1]
        --BattleLogic.AddMP(role.camp, f1 * 100)
    end,

    --战斗中，队伍每损失[a]%的生命值，增加[b]%的异妖能量
    --a[float],b[float]
    [52] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]

        local maxHp = 0
        local curHp = 0
        if f1 == 0 then
            return
        end
        local curHpGears = 0
        local arr = BattleUtil.ChooseTarget(role, 10000)
        for i=1, #arr do
            curHp = curHp + arr[i]:GetRoleData(RoleDataName.Hp)
            maxHp = maxHp + arr[i]:GetRoleData(RoleDataName.MaxHp)
        end

        local auraBuff = Buff.Create(role, BuffName.Aura, 0, function (r)
            local hp = 0
            for i=1, #arr do
                hp = hp + arr[i]:GetRoleData(RoleDataName.Hp)
            end

            if hp < curHp then
                local gears = floor((maxHp - hp) / (f1 * maxHp))
                if gears > curHpGears then
                    --BattleLogic.AddMP(role.camp, f2 * (gears - curHpGears) * 100)
                    curHpGears = gears
                end
                curHp = hp
            end
        end)
        auraBuff.interval = 0
        BattleLogic.BuffMgr:AddBuff(role, auraBuff)
    end,
    --战斗中，治疗技能有概率额外造成[a]%的治疗，概率等于自身暴击率。
    --a[float]
    [53] = function(role, args)
        local f1 = args[1]

        local OnPassiveTreating = function(treatingFunc)
            BattleUtil.RandomAction(role:GetRoleData(RoleDataName.Crit), function ()
                treatingFunc(f1, CountTypeName.AddPencent)
            end)
        end
        role.Event:AddEvent(BattleEventName.PassiveTreating, OnPassiveTreating)
    end,
    --受击后，有[a]的概率对攻击者造成眩晕，持续[b]秒。
    --a[float],b[int]
    [54] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
            if atkRole.isTeam then
                return
            end
            BattleUtil.RandomControl(f1, 1, role, atkRole, f2)
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)
    end,
    --造成伤害时，有[a]的概率立即造成攻击[b]%的伤害。
    --a[float],b[float]
    [55] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]

        local lastTrigger = 0
        local OnDamage = function(defRole, damage, bCrit, finalDmg)
            lastTrigger = lastTrigger + 1
            if lastTrigger > 1 then --加入限定避免循环触发
                return
            end
            BattleUtil.RandomAction(f1, function ()
                local val = floor(BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.Attack), f2))
                BattleUtil.ApplyDamage(nil, role, defRole, val)
            end)
            lastTrigger = 0
        end
        role.Event:AddEvent(BattleEventName.RoleHit, OnDamage)
    end,
    --造成暴击时，额外造成目标最大生命值[a]%的伤害。（目标最大生命值伤害总上限为施法者2.5倍攻击）
    --a[float]
    [56] = function(role, args)
        local f1 = args[1]

        local lastTrigger = 0
        local OnRoleCrit = function(defRole)
            lastTrigger = lastTrigger + 1
            if lastTrigger > 1 then --加入限定避免循环触发
                return
            end
            local ar1 = BattleUtil.FP_Mul(defRole:GetRoleData(RoleDataName.MaxHp), f1)
            local ar2 = BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.Attack), 2.5)
            BattleUtil.ApplyDamage(nil, role, defRole, floor(min(ar1, ar2)))
            lastTrigger = 0
        end
        role.Event:AddEvent(BattleEventName.RoleCrit, OnRoleCrit)
    end,
    --发动技能时，若技能目标与自身发动的上一个技能目标相同，则增加[a]%的伤害，最多叠加[b]层。
    --a[float],b[int]
    [57] = function(role, args)
        local f1 = args[1]
        local i2 = args[2]

        local damageDic = {}
        local lastDamageDic = {}
        local OnSkillCastEnd = function(skill)
            for k in pairs(damageDic) do
                if lastDamageDic[k] then
                    damageDic[k] = damageDic[k] + 1
                end
            end
            lastDamageDic = damageDic
            damageDic = {}
        end
        local OnPassiveDamaging = function(damagingFunc, defRole, damage)
            if lastDamageDic[defRole] then
                local layer = i2 == 0 and lastDamageDic[defRole] or min(i2, lastDamageDic[defRole])
                damagingFunc(-floor(f1 * layer * damage))
                damageDic[defRole] = lastDamageDic[defRole]
            else
                damageDic[defRole] = 1
            end
        end

        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
        role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
    end,
    --发动技能后，每个敌方角色有[a]概率获得[b]，每秒造成[c]%的[d]伤害，持续[e]秒。
    --a[float],b[持续伤害类型],c[float],d[伤害类型],e[int]
    [58] = function(role, args)
        local f1 = args[1]
        local d1 = args[2]
        local f2 = args[3]
        local dt = args[4]
        local f3 = args[5]

        local OnSkillCastEnd = function(skill)
            local arr = BattleUtil.ChooseTarget(role, 20000)
            for i=1, #arr do
                BattleUtil.RandomAction(f1, function ()--
                    arr[i]:AddBuff(Buff.Create(role, BuffName.DOT, f3, 1, d1, dt, f2))
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,
    --每隔[a]秒，抵挡一个负面状态。（控制 dot 减益）
    --a[int]
    [59] = function(role, args)
        local f1 = args[1]

        local count = 0
        role.buffFilter:Add(function(buff)
            local b = buff.isDeBuff or buff.type == BuffName.DOT or buff.type == BuffName.Control
            if b then
                count = count + 1
            end
            return b and count <= 1
        end)

        local auraBuff = Buff.Create(role, BuffName.Aura, 0, function (r)
            count = 0
        end)
        auraBuff.interval = f1
        BattleLogic.BuffMgr:AddBuff(role, auraBuff)
    end,
    --我方生命最低的其他角色受到技能攻击后，自身[a]的概率对攻击者造成攻击[b]%的[c]伤害，并造成[d]，持续[e]秒。若自身处于沉默或眩晕状态，则不会触发。播放攻击特效，特效时间[f]秒。
    --a[float],b[float],c[伤害类型],d[控制状态],e[int],f[float]
    [60] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local dt = args[3]
        local ct = args[4]
        local f3 = args[5]
        local f4 = args[6]

        local triggerUid = {}
        BattleLogic.Event:AddEvent(BattleEventName.RoleBeDamaged, function (defRole, atkRole, damage, bCrit, finalDmg, damageType, dotType)
            if atkRole.isTeam or role:IsDead() or dotType then
                return
            end
            if triggerUid[atkRole.uid] then --加入限定避免循环触发
                return
            end
            if not BattleLogic.BuffMgr:HasBuff(role, BuffName.Control, function (buff) return buff.ctrlType == 1 or buff.ctrlType == 2 end) then
                local arr = BattleUtil.ChooseTarget(role, 10110)
                local target
                if arr[1] then
                    if arr[1] == role and arr[2] then
                        target = arr[2]
                    else
                        target = arr[1]
                    end
                end
                if defRole == target then
                    BattleUtil.RandomAction(f1, function ()--
                        role.Event:DispatchEvent(BattleEventName.RoleViewBullet, f4, atkRole)
                        BattleLogic.WaitForTrigger(f4, function ()
                            triggerUid[atkRole.uid] = atkRole.uid
                            BattleUtil.CalDamage(nil, role, atkRole, dt, f2)
                            BattleUtil.RandomControl(1, ct, role, atkRole, f3)
                            triggerUid[atkRole.uid] = nil
                        end)
                    end)
                end
            end
        end)
    end,
    --自身受到的非暴击伤害，可以转化[a]%的伤害为自身攻击，持续[b]秒。上限自身攻击的[c]%。
    --a[float],b[int],c[float]
    [61] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local f3 = args[3]

        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
            if not bCrit then
                local ar1 = BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.Attack), f3)
                local ar2 = BattleUtil.FP_Mul(damage, f1)
                role:AddBuff(Buff.Create(role, BuffName.PropertyChange, f2, RoleDataName.Attack, floor(min(ar1, ar2)), 1))
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)
    end,
    --发动技能后，有[a]的概率为自身及相邻加持[b][c]%的护盾，持续[d]秒。
    --a[float],b[属性],c[float],d[int]
    [62] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local f2 = args[3]
        local f3 = args[4]

        local OnSkillCastEnd = function(skill)
            BattleUtil.RandomAction(f1, function ()
                local list = RoleManager.GetNeighbor(role, 1)
                for i=1, #list do
                    local val = floor(BattleUtil.FP_Mul(role:GetRoleData(BattlePropList[pro]), f2))
                    list[i]:AddBuff(Buff.Create(role, BuffName.Shield, f3, ShieldTypeName.NormalReduce, val, 0))
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,
    --自身拥有护盾时，我方角色每次释放技能后，有[a]概率回复[b]%的[c]的治疗。
    --a[float],b[float],c[属性]
    [63] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local pro1 = args[3]
        BattleLogic.Event:AddEvent(BattleEventName.SkillCastEnd, function (skill)
            if skill.owner.isTeam then
                return
            end
            if skill.owner.camp == role.camp then
                if BattleLogic.BuffMgr:HasBuff(role, BuffName.Shield, function (buff) return true end) then
                    BattleUtil.RandomAction(f1, function ()
                        local val = floor(BattleUtil.FP_Mul(role:GetRoleData(BattlePropList[pro1]), f2))
                        BattleUtil.CalTreat(role, skill.owner, val)
                    end)
                end
            end
        end)
    end,
    --基于生命损失的百分比，受到的伤害降低[b]%。
    --a[float]
    [64] = function(role, args)
        local f1 = args[1]

        local OnPassiveDamaging = function(damagingFunc, atkRole, damage)
            damagingFunc(floor(BattleUtil.FP_Mul(f1, damage,1-BattleUtil.GetHPPencent(role))))
        end
        role.Event:AddEvent(BattleEventName.PassiveBeDamaging, OnPassiveDamaging)
    end,
    --我方角色死亡时，对击杀者造成[a]%的[b]伤害，令其眩晕，持续[c]秒。
    --a[float],b[伤害类型],c[int]
    [65] = function(role, args)
        local f1 = args[1]
        local dt = args[2]
        local f2 = args[3]

        BattleLogic.Event:AddEvent(BattleEventName.BattleRoleDead, function (defRole, atkRole)
            if role:IsDead() or atkRole.isTeam then
                return
            end
            if defRole.camp == role.camp then
                BattleUtil.CalDamage(nil, role, atkRole, dt, f1)
                BattleUtil.RandomControl(1, ControlType.Dizzy, role, atkRole, f2)
            end
        end)
    end,
    --免疫减益状态。
    --无
    [66] = function(role, args)
        role.buffFilter:Add(function(buff)
            return buff.isDeBuff
        end)
    end,
    --敌方累计发动[a]次技能，有[b]概率发动（发动特效），对敌方全体造成眩晕效果，持续[c]秒。然后清空累计次数。播放攻击特效，特效时间[d]秒。
    --a[int],b[float],c[float]
    [67] = function(role, args)
        local i1 = args[1]
        local f1 = args[2]
        local f2 = args[3]
        local f3 = args[4]

        local count = 0
        BattleLogic.Event:AddEvent(BattleEventName.SkillCast, function (skill)
            if skill.owner.isTeam or role:IsDead() then
                return
            end
            if skill.owner.camp ~= role.camp then
                count = count + 1
                if count == i1 then
                    BattleUtil.RandomAction(f1, function ()--
                        role.Event:DispatchEvent(BattleEventName.AOE, 1-role.camp)
                        BattleLogic.WaitForTrigger(f3, function ()
                            local arr = BattleUtil.ChooseTarget(role, 20000)
                            for i=1, #arr do
                                BattleUtil.RandomControl(1, ControlType.Dizzy, role, arr[i], f2)
                            end
                        end)
                    end)
                    count = 0
                end
            end
        end)
    end,
    --受到伤害后，[a]概率为自身施加[b]的[c]%的护盾。持续[d]秒。
    --a[float],b[属性],c[float],d[int]
    [68] = function(role, args)
        local f1 = args[1]
        local pro1 = args[2]
        local f2 = args[3]
        local f3 = args[4]

        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
            BattleUtil.RandomAction(f1, function ()
                local val = floor(BattleUtil.FP_Mul(role:GetRoleData(BattlePropList[pro1]), f2))
                role:AddBuff(Buff.Create(role, BuffName.Shield, f3, ShieldTypeName.NormalReduce, val, 0))
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)
    end,
    --造成暴击时，额外造成目标最大生命值[a]%的伤害。造成伤害时，有[a]的概率立即造成攻击[b]%的伤害，该伤害造成的暴击伤害不会触发额外最大生命值伤害。（效果55+效果56）（目标最大生命值伤害总上限为施法者5倍攻击）
    --a[float],b[float],c[float]
    [69] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local f3 = args[3]

        local lastTrigger = 0
        local OnDamage = function(defRole, damage, bCrit, finalDmg)
            lastTrigger = lastTrigger + 1
            if lastTrigger > 1 then --加入限定避免循环触发
                return
            end
            if bCrit then
                local ar1 = BattleUtil.FP_Mul(defRole:GetRoleData(RoleDataName.MaxHp), f1)
                local ar2 = BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.Attack), 5)
                BattleUtil.ApplyDamage(nil, role, defRole, floor(min(ar1, ar2)))
            else
                BattleUtil.RandomAction(f2, function ()
                    local val = floor(BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.Attack), f3))
                    BattleUtil.ApplyDamage(nil, role, defRole, val)
                end)
            end
            lastTrigger = 0
        end
        role.Event:AddEvent(BattleEventName.RoleDamage, OnDamage)
    end,
    --击杀每个敌人会永久增加[a]%的[b]，持续[c]秒。（0表示永久）（不可驱散）
    --a[float],b[属性],c[int]
    [70] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local f2 = args[3]

        local OnKill = function(defRole)
            local buff = Buff.Create(role, BuffName.PropertyChange, f2, BattlePropList[pro], f1, 2)
            buff.cover = true
            buff.clear = false
            role:AddBuff(buff)
        end
        role.Event:AddEvent(BattleEventName.RoleKill, OnKill)
    end,
    --受击后，[a]对攻击者造成自身[c]%的[d]伤害。
    --a[float],c[float],d[伤害类型]
    [71] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local dt = args[3]

        local lastTrigger = 0
        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
            if atkRole.isTeam then
                return
            end
            lastTrigger = lastTrigger + 1
            if lastTrigger > 1 then --加入限定避免循环触发
                return
            end
            BattleUtil.RandomAction(f1, function ()
                BattleUtil.CalDamage(nil, role, atkRole, dt, f2)
            end)
            lastTrigger = 0
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)
    end,
    --造成的伤害暴击时，有[a]概率在计算伤害时额外计算[b]的暴击伤害。
    --a[float],b[float]
    [72] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]

        local OnPassiveCriting = function(crit)
            BattleUtil.RandomAction(f1, function ()
                crit(role:GetRoleData(RoleDataName.CritDamageFactor)+f2)
            end)
        end
        role.Event:AddEvent(BattleEventName.PassiveCriting, OnPassiveCriting)
    end,
    --释放技能时，自己损失[a]%当前生命值，为此次技能增加等量伤害。
    --a[float]
    [73] = function(role, args)
        local f1 = args[1]

        local hp=0
        local OnPassiveDamaging = function(damagingFunc, defRole, damage)
            damagingFunc(-hp)
        end
        local OnSkillCast, OnSkillCastEnd
        OnSkillCast = function(skill)
            hp = floor(BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.Hp), f1))
            role.data:SubValue(RoleDataName.Hp, hp)

            role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
            role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
        end
        OnSkillCastEnd = function(skill)
            BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function () --延迟一帧移除事件，防止触发帧和结束帧为同一帧时，被动未移除
                role.Event:RemoveEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
                role.Event:RemoveEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)
    end,
    --死亡时，为所有我方角色增加[a]%的[b]属性，持续[c]秒。
    --a[float],b[属性],c[int]
    [74] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local f2 = args[3]

        local OnDead = function(atkRole)
            local arr = BattleUtil.ChooseTarget(role, 10000)
            for i=1, #arr do
                arr[i]:AddBuff(Buff.Create(role, BuffName.PropertyChange, f2, BattlePropList[pro], f1, 2))
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDead, OnDead)
    end,
    --boss每受到（[a]*印记层数）点伤害，为自身永久增加一层印记，每层印记为自身增加[b]点攻击，[c]点护甲和[d]点魔抗。【不可驱散】
    --a[int],b[int],c[int],d[int]
    [75] = function(role, args)
        local i1 = args[1]
        local i2 = args[2]
        local i3 = args[3]
        local i4 = args[4]

        if i1 <= 0 then return end --防止死循环
        local total = 0
        local layer = 0
        local OnBeDamaged = function(atkRole, damage, bCrit, finalDmg, damageType)
            total = total + damage
            local count = 0
            while total >= i1 * layer do
                total = total - i1 * layer
                layer = layer + 1
                count = count + 1
            end
            if count > 0 then
                local buff1 = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[1], i2 * count, 1)
                buff1.cover = true
                buff1.layer = count
                buff1.clear = false
                
                local buff2 = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[2], i3 * count, 1)
                buff2.cover = true
                buff2.layer = count
                buff2.clear = false
                
                local buff3 = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[3], i4 * count, 1) 
                buff3.cover = true 
                buff3.layer = count        
                buff3.clear = false
                
                role:AddBuff(buff1)
                role:AddBuff(buff2)
                role:AddBuff(buff3)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamaged, OnBeDamaged)
    end,
    --战斗中，若自己是[a],[d]改变[b]属性[c]。
    --a[职业],b[属性],c[float],d[改变类型]
    [76] = function(role, args)
        local i1 = args[1]
        local pro = args[2]
        local f1 = args[3]
        local ct = args[4]

        if role.roleData.professionId == i1 then
            if ct == 1 then --加算
                role.data:AddValue(BattlePropList[pro], f1)
            elseif ct == 2 then --乘加算（百分比属性加算）
                role.data:AddPencentValue(BattlePropList[pro], f1)
            elseif ct == 3 then --减算
                role.data:SubValue(BattlePropList[pro], f1)
            elseif ct == 4 then --乘减算（百分比属性减算）
                role.data:SubPencentValue(BattlePropList[pro], f1)
            end
        end
    end,
    --战斗开始时，为自身施加[a]*[b]的护盾，持续[c]秒（0为无限）。
    --a[属性],b[float],c[int]
    [77] = function(role, args)
        local pro1 = args[1]
        local f1 = args[2]
        local f2 = args[3]

        local val = floor(BattleUtil.FP_Mul(f1, role:GetRoleData(BattlePropList[pro1])))
        role:AddBuff(Buff.Create(role, BuffName.Shield, f2, ShieldTypeName.NormalReduce, val, 0))
    end,
    --战斗开始时，为自身回复[a]*[b]的血量。
    --a[属性],b[float]
    [78] = function(role, args)
        local pro = args[1]
        local f1 = args[2]

        local val = floor(BattleUtil.FP_Mul(f1, role:GetRoleData(BattlePropList[pro])))
        BattleUtil.CalTreat(role, role, val)
    end,
    --战斗结束时，为自身回复[a]*[b]的血量。
    --a[属性],b[float]
    [79] = function(role, args)
        local pro = args[1]
        local f1 = args[2]

        local OnEnd = function(order)
            if order == BattleLogic.TotalOrder then
                local val = floor(BattleUtil.FP_Mul(f1, role:GetRoleData(BattlePropList[pro])))
                BattleUtil.CalTreat(role, role, val)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleOrderEnd, OnEnd)
    end,
    --战斗中，若自己是[a],[d]改变[b]属性[c]。-- 2020/3/6 高鑫
    --a[元素],b[属性],c[float],d[改变类型]
    [80] = function(role, args)
        local i1 = args[1]
        local pro = args[2]
        local f1 = args[3]
        local ct = args[4]

        if role.roleData.element == i1 then
            if ct == 1 then --加算
                role.data:AddValue(BattlePropList[pro], f1)
            elseif ct == 2 then --乘加算（百分比属性加算）
                role.data:AddPencentValue(BattlePropList[pro], f1)
            elseif ct == 3 then --减算
                role.data:SubValue(BattlePropList[pro], f1)
            elseif ct == 4 then --乘减算（百分比属性减算）
                role.data:SubPencentValue(BattlePropList[pro], f1)
            end
        end
    end,


    -- [a]增加[b], [c]改变
    -- a[属性]b[float]
    [90] = function(role, args)
        local pro = args[1]
        local f1 = args[2]
        local ct = args[3]
        role.data:CountValue(BattlePropList[pro], f1, ct)
    end,
    
    -- 技能伤害增加[a]%，[b]改变
    -- a[float]b[改变类型]
    [91] = function(role, args)
        local f1 = args[1]
        local ct = args[2]
        local passivityDamaging = function(func, caster, damage)
            if func then 
                local dd = BattleUtil.CountValue(damage, f1, ct) - damage
                func(-floor(BattleUtil.ErrorCorrection(dd)))
            end
        end
        local OnSkillCast = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:AddEvent(BattleEventName.PassiveDamaging, passivityDamaging)
            end
        end
        local OnSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:RemoveEvent(BattleEventName.PassiveDamaging, passivityDamaging)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,
    
    -- (直接伤害（目前没有明确定义直接伤害）)直接伤害击杀目标自身增加[a]点怒气
    -- a[int]
    [92] = function(role, args)
        local i1 = args[1]

        local OnRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            -- local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[pro], i1, 1)
            -- buff.cover = true   -- 可以叠加
            -- buff.clear = false  -- 不可驱散
            -- role:AddBuff(buff)
            if skill and not skill.isAdd and defRole:IsDead() and BattleUtil.CheckIsNoDead(defRole) then
                role:AddRage(i1, CountTypeName.Add)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, OnRoleHit)
    end,

    -- 技能治疗量增加[a]
    -- a[float]
    [93] = function(role, args)
        local f1 = args[1]
        local passiveTreating = function(func, caster)
            if func then func(f1, CountTypeName.AddPencent) end
        end
        local OnSkillCast = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:AddEvent(BattleEventName.PassiveTreating, passiveTreating)
            end
        end
        local OnSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:RemoveEvent(BattleEventName.PassiveTreating, passiveTreating)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,
    

    -- 全体上阵武将增加[a][b] [c]改变
    -- a[float]b[属性]c[改变类型]
    [94] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local ct = args[3]
        local list = RoleManager.Query(function(v) return role.camp == v.camp end)
        for _, r in pairs(list) do
            r.data:CountValue(BattlePropList[pro], f1, ct)
        end
    end,

    -- 行动后增加[a]点怒气
    -- a[int]
    [95] = function(role, args)
        local i1 = args[1]
        -- 行动结束后
        local onTurnEnd = function()
            role:AddRage(i1, CountTypeName.Add)
        end
        role.Event:AddEvent(BattleEventName.RoleTurnEnd, onTurnEnd)
    end,

    -- 普攻伤害增加[a]%[b]改变
    -- a[float]b[改变类型]
    [96] = function(role, args)
        local f1 = args[1]
        local ct = args[2]
        local passivityDamaging = function(func, caster, damage)
            if func then 
                local dd = BattleUtil.CountValue(damage, f1, ct) - damage
                func(-floor(BattleUtil.ErrorCorrection(dd)))
            end
        end
        local OnSkillCast = function(skill)
            if skill.type == BattleSkillType.Normal then
                role.Event:AddEvent(BattleEventName.PassiveDamaging, passivityDamaging)
            end
        end
        local OnSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                role.Event:RemoveEvent(BattleEventName.PassiveDamaging, passivityDamaging)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
        
    end,

    -- 释放技能有[a]%对全体造成[c]%[d]伤害
    -- a[float]b[int]c[float]d[伤害类型]
    [97] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local dt = args[3]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill and skill.type == BattleSkillType.Special then
                BattleUtil.RandomAction(f1, function()
                    BattleLogic.WaitForTrigger(0.1, function()
                        local list = RoleManager.Query(function(v)
                            return v.camp == (role.camp + 1) % 2
                        end)
                        for _, r in ipairs(list) do
                            BattleUtil.CalDamage(nil, role, r, dt, f2)
                        end
                    end)
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,

    -- 释放技能[a]概率不消耗怒气
    -- a[float]
    [98] = function(role, args)
        local f1 = args[1]

        local onRageCost = function(noCostRate, costRage, func)
            local dRate = f1
            local dCost = 0
            if func then func(dRate, dCost) end
        end
        role.Event:AddEvent(BattleEventName.RoleRageCost, onRageCost)
    end,


    -- 技能直接伤害的[a]%治疗友方生命最少队友。
    -- a[float]
    [99] = function(role, args)
        local f1 = args[1]

        local allDamage = 0
        local OnHit = function(atkRole, damage, bCrit, finalDmg, damageType, skill)
            if skill and skill.type == BattleSkillType.Special then
                allDamage = allDamage + finalDmg
            end
        end
        local function onSkillCast(skill)
            if skill.type == BattleSkillType.Special then
                allDamage = 0
                role.Event:AddEvent(BattleEventName.RoleHit, OnHit)
            end
        end
        local function onSkillCastEnd(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:RemoveEvent(BattleEventName.RoleHit, OnHit)

                local arr = RoleManager.Query(function (r) return r.camp == role.camp end)
                BattleUtil.SortByHpFactor(arr, 1)
                -- 检测技能伤害治疗加成
                local f = BattleUtil.CheckSkillDamageHeal(f1, role, arr[1])
                -- 治疗血量最低队友实际伤害的f1%
                BattleUtil.ApplyTreat(role, arr[1], floor(BattleUtil.ErrorCorrection(allDamage*f)))
                -- 清空伤害记录
                allDamage = 0
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,


    -- 释放技能不消耗怒气几率[a]改变[b]%
    -- a[改变类型]b[float]
    [100] = function(role, args)
        local ct = args[1]
        local f1 = args[2]

        local onRageCost = function(noCostRate, costRage, func)
            local dRate = BattleUtil.CountValue(noCostRate, f1, ct) - noCostRate
            dRate = BattleUtil.ErrorCorrection(dRate)
            local dCost = 0
            if func then func(dRate, dCost) end
        end
        role.Event:AddEvent(BattleEventName.RoleRageCost, onRageCost)
    end,

    
    -- 释放技能技能[a]概率[b]改变[c]%
    -- a[控制状态]b[改变类型]c[float]
    [101] = function(role, args)
        local ctl = args[1]
        local ct = args[2]
        local f1 = args[3]

        local onSkillControl = function(func, ctrl)
            if ctrl == ctl then
                if func then func(f1, ct) end
            end
        end
        local onSkillCast = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:AddEvent(BattleEventName.PassiveRandomControl, onSkillControl)
            end
        end
        local onSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:RemoveEvent(BattleEventName.PassiveRandomControl, onSkillControl)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,


    -- 释放技能后追加[a]次普攻
    -- a[int]
    [102] = function(role, args)
        local i1 = args[1]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                for i = 1, i1 do 
                    role:AddSkill(BattleSkillType.Normal, false, true, nil)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,

    -- 直接伤害每次击杀目标增加[a]%的[b]可叠加持续至战斗结束[c]改变
    -- a[float]b[属性]c[改变类型]
    [103] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local ct = args[3]
        -- 释放技能后
        local onRoleHit = function(defRole)
            if defRole:IsDead() and BattleUtil.CheckIsNoDead(defRole) then
                local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[pro], f1, ct)
                -- buff.cover = true
                role:AddBuff(buff)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,



    -- 释放技能后给除自己外己方生命最少的武将附加无敌盾持续[b]回合（只剩自己则不加）
    --b[属性]
    [104] = function(role, args)
        local i1 = args[1]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                local list = RoleManager.Query(function(v) return v.camp == role.camp end)
                BattleUtil.SortByHpFactor(list, 1)
                local target = nil
                for i = 1, #list do 
                    if not list[i]:IsRealDead() and list[i] ~= role then
                        target = list[i]
                        break
                    end
                end
                if target then
                    target:AddBuff(Buff.Create(role, BuffName.Shield, i1, ShieldTypeName.AllReduce, 0, 0))
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,



    -- 释放技能后增加友方全体[a]点怒气
    -- a[int]
    [105] = function(role, args)
        local i1 = args[1]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                local list = RoleManager.Query(function(v) return v.camp == role.camp end)
                for i = 1, #list do 
                    local r = list[i]
                    r:AddRage(i1, CountTypeName.Add)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,


    -- 受到直接伤害[a]%治疗友方[b]最少[c]个单位
    -- a[float]b[属性]c[int]
    [106] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local i1 = args[3]

        local onBeHit = function(caster, damage)
            local list = RoleManager.Query(function(v) return v.camp == role.camp end)
            list = BattleUtil.SortByProp(list, BattlePropList[pro], 1)
            for i = 1, i1 do 
                local r = list[i]
                if r and not r:IsRealDead() then
                    local treatValue = floor(BattleUtil.ErrorCorrection(f1 * damage))
                    BattleUtil.ApplyTreat(role, r, treatValue)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, onBeHit)
    end,

    -- 释放技能后自身回[a]点怒气
    -- a[int]
    [107] = function(role, args)
        local i1 = args[1]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                role:AddRage(i1, CountTypeName.Add)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,

    -- 受到技能或普攻直接伤害的[a]%反弹给攻击者
    -- a[float]
    [108] = function(role, args)
        local f1 = args[1]
        local onBeHit = function(caster, damage, bCrit, finalDmg, damageType, skill)
            if skill then       --技能造成的直接伤害
                local rDamage = f1 * damage

                -- 计算被动技能额外加乘
                local cl = {}
                local function _CallBack(v, ct)
                    if v then
                        table.insert(cl, {v, ct})
                    end
                end
                role.Event:DispatchEvent(BattleEventName.PassiveRebackDamage, _CallBack)
                caster.Event:DispatchEvent(BattleEventName.PassiveBeRebackDamage, _CallBack)
                rDamage = floor(BattleUtil.ErrorCorrection(BattleUtil.CountChangeList(rDamage, cl)))

                if rDamage ~= 0 then
                    BattleUtil.ApplyDamage(nil, role, caster, rDamage)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, onBeHit)
    end,

    -- 受到普通攻击或直接伤害时回复自身[a]点怒气
    -- a[int]
    [109] = function(role, args)
        local i1 = args[1]
        local onBeSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                role:AddRage(i1, CountTypeName.Add)
            end
        end
        role.Event:AddEvent(BattleEventName.BeSkillCastEnd, onBeSkillCastEnd)
    end,

    -- 释放技能后降低目标[a]点怒气
    -- a[int]
    [110] = function(role, args)
        local i1 = args[1]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                local list = skill:GetDirectTargetsNoMiss()
                if list then
                    for i = 1, #list do 
                        list[i]:AddRage(i1, CountTypeName.Sub)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,

    -- 被击杀时[a]%概率[b]敌方武将[c]回合
    -- a[float]b[控制状态]c[int]
    [111] = function(role, args)
        local f1 = args[1]
        local ctl = args[2]
        local i1 = args[3]
        local onRoleBeDamaged = function(caster, damage, bCrit, finalDmg, damageType, dotType, skill)
            if role:IsDead() and skill then
                BattleUtil.RandomControl(f1, ctl, role, caster, i1)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamaged, onRoleBeDamaged)
    end,


    -- 战斗第[a]回合造成伤害必定暴击
    -- a[int]
    [112] = function(role, args)
        local i1 = args[1]
        local function onRoleDamageAfter(target)
            target.isFlagCrit = false
            role.Event:RemoveEvent(BattleEventName.RoleDamageAfter, onRoleDamageAfter)
        end
        local function onRoleDamageBefore(target)
            if BattleLogic.GetCurRound()  == i1 then
                target.isFlagCrit = true
                role.Event:AddEvent(BattleEventName.RoleDamageAfter, onRoleDamageAfter)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, onRoleDamageBefore)
    end,


    -- 追加的普攻[a]%概率暴击
    -- a[float]
    [113] = function(role, args)
        local f1 = args[1]
        local function onSkillCast(skill)
            if skill.type == BattleSkillType.Normal and skill.isAdd then
                role.data:AddValue(RoleDataName.Crit, f1)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)

        local function onSkillCastEnd(skill)
            if skill.type == BattleSkillType.Normal and skill.isAdd then
                role.data:SubValue(RoleDataName.Crit, f1)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,

    -- 直接伤害击杀目标后追加[a]次普攻
    -- a[int]
    [114] = function(role, args)
        local i1 = args[1]
        -- 释放技能后
        local onRoleHit = function(target)
            -- LogError("target  "..target.roleId ..  "    ".. target.star)
            if target:IsDead() and BattleUtil.CheckIsNoDead(target) then
                for i = 1, i1 do 
                    role:AddSkill(BattleSkillType.Normal, false, true, nil)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,


    -- 战斗第[a]回合增加[c]%的自身伤害持续[e]回合,[f]改变
    -- a[int]c[float]e[int]f[改变]
    [115] = function(role, args)
        local i1 = args[1]
        local f1 = args[2]
        local i2 = args[3] or 1
        local ct = args[4]

        --  如果是技能的伤害则判断加成
        local onPassiveDamaging = function(func, target, damage, skill)
            if skill then
                local dd = BattleUtil.CountValue(damage, f1, ct) - damage
                if func then func(-floor(BattleUtil.ErrorCorrection(dd))) end
            end
        end

        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, function(curRound)
            -- 第i1回合开始
            if curRound == i1 then
                role.Event:AddEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)
            end
            -- 第i1+i2回合结束
            if curRound == i1 + i2 then
                role.Event:RemoveEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)
            end
        end)
    end,



    -- 直接伤害击杀目标回复自身[a]%的[b]
    -- a[float]
    [116] = function(role, args)
        local f1 = args[1]
        -- 释放技能后
        local onRoleHit = function(target)
            if target:IsDead() and BattleUtil.CheckIsNoDead(target) then
                local treat = floor(BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.MaxHp), f1))
                BattleUtil.CalTreat(role, role, treat)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    -- 技能目标每[a]改变[b]个，技能伤害增加[c]%，[d]改变
    -- a[改变类型]b[int]c[float]d[改变类型]
    [117] = function(role, args)
        local ct = args[1]      -- 对方阵营中死亡数量(目前没有用到)
        local i1 = args[2]
        local f1 = args[3]
        local ct2 = args[4]


        -- 每次释放技能时提前计算额外加成的伤害
        local extra = 0
        local onSkillCast = function(skill)
            extra = 0
            if skill and skill.type == BattleSkillType.Special then
                -- local roleList =RoleManager.Query(function (r) return r.camp ~= role.camp end)
                -- local deadNum = 6 - #roleList
                -- local level = math.floor(deadNum/i1)
                -- extra = BattleUtil.ErrorCorrection(level * f1)

                -- 改变值 = 技能最大目标数 - 当前目标数
                local maxNum = skill:GetMaxTargetNum()
                local curNum = #skill:GetDirectTargets()
                local lessNum = max(maxNum - curNum, 0)
                local level = math.floor(lessNum/i1)
                extra = BattleUtil.ErrorCorrection(level * f1)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)

        --  如果是技能的伤害则判断加成
        local onPassiveDamaging = function(func, target, damage, skill)
            if skill and skill.type == BattleSkillType.Special then
                local dd = BattleUtil.CountValue(damage, extra, ct2) - damage
                if func then func(-floor(BattleUtil.ErrorCorrection(dd))) end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)
    end,



    -- 每次释放技能,技能伤害增加[a]%，无限叠加释放普攻时清除加成，[b]改变
    -- a[float]b[改变类型]
    [118] = function(role, args)
        local f1 = args[1]
        local ct = args[2]

        local af = 0

        local onSkillCast = function(skill)
            if skill.type == BattleSkillType.Normal and not skill.isAdd then
                af = 0
            elseif skill.type == BattleSkillType.Special then
                af = af + f1
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)

        --  如果是技能的伤害则判断加成
        local onPassiveDamaging = function(func, target, damage, skill)
            if skill and skill.type == BattleSkillType.Special then
                local dd = BattleUtil.CountValue(damage, af, ct) - damage
                if func then func(-floor(BattleUtil.ErrorCorrection(dd))) end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)
    end,
    -- 普攻后[a]改变自身[b]%的[c]持续[d]回合可叠加
    -- a[改变类型]b[float]c[属性]d[int]
    [119] = function(role, args)
        local ct = args[1]
        local f1 = args[2]
        local pro = args[3]
        local i1 = args[4]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                local buff = Buff.Create(role, BuffName.PropertyChange, i1, BattlePropList[pro], f1, ct)
                buff.cover = true
                role:AddBuff(buff)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,
    -- 受到直接伤害[a]%治疗友方全体
    -- a[float]
    [120] = function(role, args)
        local f1 = args[1]

        local onBeHit = function(caster, damage)
            local list = RoleManager.Query(function(v) return v.camp == role.camp end)
            for i = 1, #list do 
                local r = list[i]
                if r and not r:IsDead() then
                    local treatValue = floor(BattleUtil.ErrorCorrection(f1 * damage))
                    BattleUtil.ApplyTreat(role, r, treatValue)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, onBeHit)
    end,

    -- 普攻后回复[a]点怒气
    -- a[int]
    [121] = function(role, args)
        local i1 = args[1]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                role:AddRage(i1, CountTypeName.Add)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,


    -- 释放技能后给己方前排武将附加减伤盾持续时间[a]改变[b]回合
    -- a[改变类型]b[int]
    [122] = function(role, args)
        local ct = args[1]
        local i1 = args[2]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                local list = RoleManager.Query(function(v) return v.camp == role.camp and v.position <= 3 end)
                for _, role in ipairs(list) do
                    BattleLogic.BuffMgr:QueryBuff(role, function(buff)
                        if buff.type == BuffName.Shield and buff.shieldType == ShieldTypeName.RateReduce then
                            buff:ChangeBuffDuration(ct, i1)
                        end
                    end)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,


    -- 释放技能后给己方前排附加减伤盾效果[a]改变[b]%
    -- a[改变类型]b[float]
    [123] = function(role, args)
        local ct = args[1]
        local f1 = args[2]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                local list = RoleManager.Query(function(v) return v.camp == role.camp and v.position <= 3 end)
                for _, role in ipairs(list) do
                    BattleLogic.BuffMgr:QueryBuff(role, function(buff)
                        if buff.type == BuffName.Shield and buff.shieldType == ShieldTypeName.RateReduce then
                            buff:ChangeShieldValue(ct, f1)
                        end
                    end)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,

    -- 释放技能后回复己方后排[a]点怒气
    -- a[int]
    [124] = function(role, args)
        local i1 = args[1]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                local list = RoleManager.Query(function(v) return v.position > 3 end)
                for _, r in ipairs(list) do
                    r:AddRage(i1, CountTypeName.Add)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,

    -- 直接伤害击杀目标下回合攻击[a]%暴击(TODO:目前为增加[a]%)
    -- a[float]
    [125] = function(role, args)
        local f1 = args[1]
        -- 释放技能后
        local onRoleHit = function(target)
            if target:IsDead() and BattleUtil.CheckIsNoDead(target) then
                local buff = Buff.Create(role, BuffName.PropertyChange, 1, RoleDataName.Crit, f1, CountTypeName.Add)
                role:AddBuff(buff)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    -- 战斗中生命每减少[c]%，[d]就[e]改变[f]%
    -- c[float]d[属性]e[改变类型]f[float]
    [126] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        local dt = args[3]
        local f2 = args[4]

        local curLevel = 0
        -- 释放技能后
        local onRoleBeDamaged = function(caster, damage)
            local levelDamage = floor(role:GetRoleData(RoleDataName.MaxHp)*f1)
            local lostDamage = role:GetRoleData(RoleDataName.MaxHp) - role:GetRoleData(RoleDataName.Hp)
            local level = floor(lostDamage/levelDamage)
            if level > curLevel then
                local dl = level - curLevel
                for i = 1, dl do
                    local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[pro], f2, dt)
                    buff.cover = true
                    role:AddBuff(buff)
                end
                curLevel = level
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamaged, onRoleBeDamaged)
    end,


    -- 与48相同
    -- [127] = {},

    -- 普攻后降低目标[b]点怒气
    -- a[int]
    [128] = function(role, args)
        local i1 = args[1]
        -- 普攻后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                local list = skill:GetDirectTargetsNoMiss()
                if list then
                    for _, r in ipairs(list) do
                        r:AddRage(i1, CountTypeName.Sub)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,



    -- TODO
    -- 全体蜀国武将增加[a]%[b]
    -- a[float]b[属性]
    -- [129] = {},


    -- 死亡后持续战斗两回合期间受伤不致死，[a]回合后自动死亡。期间技能伤害降低[b]%无法触发追击效果且死后无法被复活。受到伤害[c]改变
    -- a[int]b[float]c[改变类型]
    [130] = function(role, args)
        local i1 = args[1]
        local f1 = args[2]
        local ct = args[3]

        -- 角色死亡时
        local onRoleDead = function()
            -- -- 暂时不能死
            -- role:SetDeadFilter(false)

            -- -- 伤害降低
            -- local function onPassiveDamaging(func, target, damage, skill)
            --     if skill and skill.type == BattleSkillType.Special then
            --         local dd = BattleUtil.CountValue(damage, f1, 4) - damage
            --         if func then func(-floor(BattleUtil.ErrorCorrection(dd))) end
            --     end
            -- end
            -- role.Event:AddEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)

            -- -- 自动死亡
            -- local counter = 0
            -- local function onRoleTurnEnd()
            --     counter = counter + 1
            --     if counter == i1 then
            --         -- 可以去死了
            --         role:SetDeadFilter(true)
            --         -- 但是不能复活了
            --         role:SetReliveFilter(false)
            --         -- 移除事件
            --         role.Event:RemoveEvent(BattleEventName.RoleTurnEnd, onRoleTurnEnd)
            --         role.Event:RemoveEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)
            --     end
            -- end
            -- role.Event:AddEvent(BattleEventName.RoleTurnEnd, onRoleTurnEnd)

            local buff = Buff.Create(role, BuffName.NoDead, i1, f1, ct, false)
            BattleLogic.BuffMgr:AddBuff(role, buff)
        end
        role.Event:AddEvent(BattleEventName.RoleDead, onRoleDead)
    end,


    -- 敌方每[a]改变[b]人自身伤害就[d]改变[e]%  (敌方每死亡i1个则自身属性改变)
    -- a[改变类型]b[int]d[改变类型]e[float]
    [131] = function(role, args)
        local ct1 = args[1]
        local i1 = args[2]
        local ct2 = args[3]
        local f1 = args[4]

        local deadNum = 0
        local extra = 0
        -- 释放技能后
        local OnDead = function(deadRole)
            if deadRole.camp == (role.camp + 1)%2 then
                deadNum = deadNum + 1
                if deadNum >= i1 then
                    deadNum = 0
                    extra = extra + f1
                    -- local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[pro], f1, ct2)
                    -- role:AddBuff(buff)
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoleDead, OnDead)

        local passivityDamaging = function(func, caster, damage, skill)
            if skill then
                if func then 
                    local dd = BattleUtil.CountValue(damage, extra, ct2) - damage
                    func(-floor(BattleUtil.ErrorCorrection(dd)))
                end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, passivityDamaging)
    end,

    -- 直接伤害每次击杀目标增加自身伤害[a]%，[b]改变，可叠加持续至战斗结束
    -- a[float]b[改变类型]
    [132] = function(role, args)
        local f1 = args[1]
        local ct = args[2]

        local killNum = 0
        local extra = 0

        -- 击杀数量累加
        local OnRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if skill and defRole:IsDead() and BattleUtil.CheckIsNoDead(defRole) then
                killNum = killNum + 1
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, OnRoleHit)


        -- 释放技能时计算额外伤害
        local OnSkillCast = function(skill)
            if skill then
                extra = f1 * killNum
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)


        -- 造成伤害时判断额外伤害
        local passivityDamaging = function(func, caster, damage, skill)
            if skill then
                if func then 
                    local dd = BattleUtil.CountValue(damage, extra, ct) - damage
                    func(-floor(BattleUtil.ErrorCorrection(dd)))
                end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, passivityDamaging)


    end,

    
    -- 攻击时若目标[a]则当次攻击自身[b]，[c]改变[d]%
    -- a[持续伤害状态]b[属性]c[改变类型]d[float}
    [133] = function(role, args)
        local dot = args[1]
        local pro = args[2]
        local ct = args[3]
        local f1 = args[4]


        local index, tran 
        local OnRoleDamageBefore = function(target)
            if BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff) return buff.damageType == dot end) then
                index, tran = role:AddPropertyTransfer(BattlePropList[pro], f1, BattlePropList[pro], ct)
            end
        end
        local OnRoleDamageAfter = function()
            if index and tran then
                role:RemovePropertyTransfer(index, tran)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, OnRoleDamageBefore)
        role.Event:AddEvent(BattleEventName.RoleDamageAfter, OnRoleDamageAfter)
    end,

 
    -- 释放技能技能[a]概率[b]改变[c]%
    -- a[持续伤害状态]b[改变类型]c[float]
    [134] = function(role, args)
        local dot = args[1]
        local ct = args[2]
        local f1 = args[3]
        
        local onSkillControl = function(func, dotType)
            if dotType == dot then
                if func then func(f1, ct) end
            end
        end
        local onSkillCast = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:AddEvent(BattleEventName.PassiveRandomDot, onSkillControl)
            end
        end
        -- 技能后后
        local onSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:RemoveEvent(BattleEventName.PassiveRandomDot, onSkillControl)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,

    -- 普攻有[a]%概率使目标[b]持续[c]回合（每回合造成攻击者20%攻击力的伤害）
    -- a[float]b[持续伤害状态]c[int]
    [135] = function(role, args)
        local f1 = args[1]
        local dot = args[2]
        local i1 = args[3]

        -- 普攻后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                local list = skill:GetDirectTargetsNoMiss()
                if list then
                    local attack = role:GetRoleData(RoleDataName.Attack)
                    local damage = floor(BattleUtil.ErrorCorrection(attack * 0.2))
                    for _, r in ipairs(list) do
                        BattleUtil.RandomDot(f1, dot, role, r, i1, 1, damage)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
        
    end,

    -- 受到普攻有[a]%概率使攻击者[b]持续[c]回合（每回合造成攻击者20%攻击力的伤害）
    -- a[float]b[持续伤害状态]c[int]
    [136] = function(role, args)
        local f1 = args[1]
        local dot = args[2]
        local i1 = args[3]

        -- 普攻后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                local caster = skill.owner
                local attack = role:GetRoleData(RoleDataName.Attack)
                local damage = floor(BattleUtil.ErrorCorrection(attack * 0.2))
                BattleUtil.RandomDot(f1, dot, role, caster, i1, 1, damage)
            end
        end
        role.Event:AddEvent(BattleEventName.BeSkillCastEnd, onSkillEnd)
    end,


    -- 释放技能后给目标附加治疗效果每回合回复[a]的[b]%点生命持续[c]回合
    -- a[属性]b[float]c[int]
    [137] = function(role, args)
        local pro = args[1]
        local f1 = args[2]
        local i1 = args[3]
        -- 技能后后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                local list = skill:GetDirectTargetsNoMiss()
                if list then
                    local tv = floor(BattleUtil.ErrorCorrection(role:GetRoleData(pro) * f1))
                    for _, r in ipairs(list) do
                        local auraBuff = Buff.Create(role, BuffName.HOT, i1, 1, tv)
                        auraBuff.interval = 1
                        r:AddBuff(auraBuff)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,

    -- 释放普攻后给目标附加治疗效果每回合回复[a]的[b]%点生命持续[c]回合
    -- a[属性]b[float]c[int]
    [138] = function(role, args)
        local pro = args[1]
        local f1 = args[2]
        local i1 = args[3]
        -- 技能后后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                local list = skill:GetDirectTargetsNoMiss()
                if list then
                    local tv = floor(BattleUtil.ErrorCorrection(role:GetRoleData(pro) * f1))
                    for _, r in ipairs(list) do
                        local auraBuff = Buff.Create(role, BuffName.HOT, i1, 1, tv)
                        auraBuff.interval = 1
                        r:AddBuff(auraBuff)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,

    -- TODO
    -- 释放技能后给目标附加治疗效果[a]改变[b]%
    -- a[改变类型]b[float]
    [139] = function(role, args)
        local dt = args[1]
        local f1 = args[2]
        local tFactor = function(factorFunc)
            factorFunc(f1, dt)
        end
        role.Event:AddEvent(BattleEventName.SkillCast, function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:AddEvent(BattleEventName.PassiveTreatingFactor, tFactor)
            end
        end)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:RemoveEvent(BattleEventName.PassiveTreatingFactor, tFactor)
            end
        end)
    end,

    -- 受到[a]状态敌人攻击时受到伤害[b]改变[c]%
    -- a[持续伤害状态]b[改变类型]c[float]
    [140] = function(role, args)
        local dot = args[1]
        local ct = args[2]
        local f1 = args[3]

        local onPassiveBeDamaging = function(func, caster, damage)
            if BattleLogic.BuffMgr:HasBuff(caster, BuffName.DOT, function(buff) return buff.damageType == dot end) then
                local dmgDeduction = damage - floor(BattleUtil.ErrorCorrection(BattleUtil.CountValue(damage, f1, ct)))
                if func then func(dmgDeduction) end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveBeDamaging, onPassiveBeDamaging)
    end,

    
    -- 战斗第[a]回合无敌
    -- a[int]
    [141] = function(role, args)
        local i1 = args[1]
        local buff 
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, function(curRound)
            -- 第i1回合开始
            if curRound == i1 then
                buff = Buff.Create(role, BuffName.Shield, 0, ShieldTypeName.AllReduce, 0, 0)
                buff.clear = false
                role:AddBuff(buff)
            end
            if curRound == i1 + 1 then
                if buff then
                    buff.disperse = true
                end
            end
        end)
    end,


    -- 释放技能时如目标处于[a]状态则伤害的[b]%转化为生命治疗自己
    -- a[持续伤害状态]b[float]
    [142] = function(role, args)
        local dot = args[1]
        local f1 = args[2]
        local onHit = function(target, damage, bCrit, finalDmg)
            if BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff) return buff.damageType == dot end) then
                BattleUtil.ApplyTreat(role, role, floor(BattleUtil.ErrorCorrection(finalDmg * f1)))
            end
        end
        local onSkillCast = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:AddEvent(BattleEventName.RoleHit, onHit)
            end
        end
        -- 技能后后
        local onSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:RemoveEvent(BattleEventName.RoleHit, onHit)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,


    -- 释放技能时如目标处于[a]状态则[b]的概率[c]改变[d]%
    -- a[持续伤害状态]b[控制状态]c[改变类型]d[float]
    [143] = function(role, args)
        local dot = args[1]
        local ctrl = args[2]
        local ct = args[3]
        local f1 = args[4]

        local onSkillControl = function(func, ctrl2, target)
            if ctrl2 == ctrl then
                if BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(b) return b.damageType == dot end) then
                    if func then func(f1, ct) end
                end
            end
        end
        local onSkillCast = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:AddEvent(BattleEventName.PassiveRandomControl, onSkillControl)
            end
        end
        -- 技能后后
        local onSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:RemoveEvent(BattleEventName.PassiveRandomControl, onSkillControl)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,

    -- 死亡时释放[a]次技能
    -- a[int]
    [144] = function(role, args)
        local i1 = args[1]

        local function onRoleDead()
            for i = 1, i1 do 
                -- 插入一个技能，该技能优先级较高
                role:InsertSkill(BattleSkillType.Special, false, true, nil)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDead, onRoleDead)
    end,


    -- 技能对[a]目标[b]额外提升[c]%（当次），[d]改变
    -- a[持续伤害状态]b[属性]c[float]d[改变类型]
    [145] = function(role, args)
        local dot = args[1]
        local pro = args[2]
        local f1 = args[3]
        local ct = args[4]

        local index, tran 
        local OnRoleDamageBefore = function(target, factorFunc, damageType, skill)
            if skill and skill.type == BattleSkillType.Special and
            BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff) return buff.damageType == dot end) then
                index, tran = role:AddPropertyTransfer(BattlePropList[pro], f1, BattlePropList[pro], ct)
            end
        end
        local OnRoleDamageAfter = function()
            if index and tran then
                role:RemovePropertyTransfer(index, tran)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, OnRoleDamageBefore)
        role.Event:AddEvent(BattleEventName.RoleDamageAfter, OnRoleDamageAfter)
    end,

    -- 普攻对[a]目标伤害额外增加[b]%（当次），[c]改变
    -- a[持续伤害状态]b[float]c[改变类型]
    [146] = function(role, args)
        local dot = args[1]
        local f1 = args[2]
        local ct = args[3]

        local onPassiveDamaging = function(damagingFunc, defRole, damage)
            if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.DOT, function(buff) return buff.damageType == dot end) then
                if damagingFunc then
                    local dd = BattleUtil.CountValue(damage, f1, ct) - damage
                    damagingFunc(-floor(BattleUtil.ErrorCorrection(dd)))
                end
            end
        end
        local onSkillCast = function(skill)
            if skill.type == BattleSkillType.Normal then
                role.Event:AddEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)
            end
        end
        local onSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                role.Event:RemoveEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,

    -- 受到攻击有[a]%概率使攻击者[b]（每回合造成被击者自身20%攻击力的伤害）持续[c]回合
    -- a[float]b[持续伤害状态]c[int]
    [147] = function(role, args)
        local f1 = args[1]
        local dot = args[2]
        local i1 = args[3]

        -- 技能后后
        local onRoleBeHit = function(caster)
            local attack = role:GetRoleData(RoleDataName.Attack)
            local damage = floor(BattleUtil.ErrorCorrection(attack * 0.2))
            BattleUtil.RandomDot(f1, dot, role, caster, i1, 1, damage)
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, onRoleBeHit)
    end,


    -- 直接伤害击杀[a]目标回复[b]%的最大生命
    -- a[持续伤害状态]b[float]
    [148] = function(role, args)
        local dot = args[1]
        local f1 = args[2]
        local function onHit(target)
            if target:IsDead() and BattleUtil.CheckIsNoDead(target) then
                local maxHp = role:GetRoleData(RoleDataName.MaxHp)
                local value = floor(BattleUtil.ErrorCorrection(maxHp* f1))
                BattleUtil.ApplyTreat(role, role, value)
            end
            role.Event:RemoveEvent(BattleEventName.RoleHit, onHit)
        end
        local onDamaging = function(func, target)
            if BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff) return buff.damageType == dot end) then
                role.Event:AddEvent(BattleEventName.RoleHit, onHit)
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, onDamaging)
    end,


    -- 技能攻击的目标如本回合直接攻击过自己则对其造成伤害增加[a]%(如目标[b]则伤害增加[c]%)[d]改变
    -- a[float]b[持续伤害状态]c[float]d[改变类型]
    [149] = function(role, args)
        local f1 = args[1]
        local dot = args[2]
        local f2 = args[3]
        local ct = args[4]

        local attor = {}
        local onRoleBeHit = function(caster)
            if not attor[caster.position] then
                attor[caster.position] = 1
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, onRoleBeHit)

        local onBattleRoundChange = function(func, caster)
            attor = {}
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onBattleRoundChange)

        -- 被动技能加伤害
        local onDamaging = function(func, target, damage, skill)
            if attor[target.position] and skill and skill.type == BattleSkillType.Special and func then
                local df = f1 
                if BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff) return buff.damageType == dot end) then
                    df = f2
                end
                local dd = BattleUtil.CountValue(damage, df, ct) - damage
                func(-floor(BattleUtil.ErrorCorrection(dd)))
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, onDamaging)

    end,

    -- 技能对[a]目标当次伤害提升[b]%，[c]改变
    -- a[持续伤害状态]b[flaot]c[改变类型]
    [150] = function(role, args)
        local dot = args[1]
        local f1 = args[2]
        local ct = args[3]

        local onPassiveDamaging = function(damagingFunc, defRole, damage)
            if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.DOT, function(buff) return buff.damageType == dot end) then
                if damagingFunc then
                    local dd = BattleUtil.CountValue(damage, f1, ct) - damage
                    damagingFunc(-floor(BattleUtil.ErrorCorrection(dd)))
                end
            end
        end
        local onSkillCast = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:AddEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)
            end
        end
        local onSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:RemoveEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,

    
    -- 释放普通攻击如目标[a]，且血量低于[b]%则有[c]%概率秒杀
    -- a[持续伤害状态]b[float]c[float]
    [151] = function(role, args)
        local dot = args[1]
        local f1 = args[2]
        local f2 = args[3]
        -- 
        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if skill and skill.type == BattleSkillType.Normal and not defRole:IsDead() then
                if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.DOT, function (buff) return dot == 0 or buff.damageType == dot end) then
                    -- 检测被动技能对秒杀参数得影响
                    local bf, kf = BattleUtil.CheckSeckill(f1, f2, role, defRole)
                    --
                    local ft = defRole:GetRoleData(RoleDataName.Hp)/defRole:GetRoleData(RoleDataName.MaxHp)
                    if ft < bf then
                        BattleUtil.RandomAction(kf, function()
                            -- 秒杀
                            BattleUtil.Seckill(skill, role, defRole)
                        end)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    -- 释放技能有[a]%概率附加[b]效果持续[c]回合
    -- a[float]b[控制状态]c[int]
    [152] = function(role, args)
        local f1 = args[1]
        local ctrl = args[2]
        local i1 = args[3]

        -- 技能后后
        local onSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                local targets = skill:GetDirectTargetsNoMiss()
                if targets then
                    for _, r in ipairs(targets) do
                        BattleUtil.RandomControl(f1, ctrl, role, r, i1)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,

    -- 直接伤害击杀目标回复自身[a]点怒气
    -- a[int]
    [153] = function(role, args)
        local i1 = args[1]

        local onHit = function(target, damage, bCrit, finalDmg)
            if target:IsDead() and BattleUtil.CheckIsNoDead(target) then
                role:AddRage(i1, CountTypeName.Add)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onHit)
    end,

    -- 复活友方第[a]位阵亡的英雄并回复其[b]%的生命每场战斗触发[c]次
    -- a[int]b[float]c[int]
    [154] = function(role, args)
        local i1 = args[1]
        local f1 = args[2]
        local i2 = args[3]-- 无意义（第几个死亡的人只能有一个）

        local counter = 0
        local onRoleRealDead = function(deadRole)
            if deadRole.camp == role.camp then
                counter = counter + 1
                if counter == i1 then
                    deadRole:SetRelive(f1)
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.RoleRealDead, onRoleRealDead)
    end,    

    -- 目标血量每降低[c]%（只看当前血量），对其治疗量就[e]改变[f]%
    -- c[float]e[改变类型]f[float]
    [155] = function(role, args)
        local f1 = args[1]        
        local ct = args[2]        
        local f2 = args[3]        
        local function onPassiveTreatingFactor(treatFactorFunc, targetRole)
            local lf = targetRole:GetRoleData(RoleDataName.Hp)/targetRole:GetRoleData(RoleDataName.MaxHp)
            local df = 1 - lf   -- 血量降低百分比 = 1 - 当前血量百分比
            local level = floor(df/f1)
            if treatFactorFunc then 
                treatFactorFunc(BattleUtil.ErrorCorrection(level*f2), ct)
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveTreatingFactor, onPassiveTreatingFactor)
    end,

    -- 受到普攻后降低攻击自己武将的[c]点怒气
    -- c[int]
    [156] = function(role, args)
        local i1 = args[1]
        local onBeSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                skill.owner:AddRage(i1, CountTypeName.Sub)
            end
        end
        role.Event:AddEvent(BattleEventName.BeSkillCastEnd, onBeSkillCastEnd)
    end,
    

    -- 减伤盾减伤比例[a]改变[b]%
    -- a[改变类型]b[float]
    [157] = function(role, args)
        local ct = args[1]
        local f1 = args[2]

        local OnBuffCaster = function(buff)
            if buff.type == BuffName.Shield and buff.shieldType == ShieldTypeName.RateReduce then
                buff:ChangeShieldValue(ct, f1)
            end
        end
        role.Event:AddEvent(BattleEventName.BuffCaster, OnBuffCaster)
    end,

    -- 释放技能后回复当前本方阵容最靠前武将[a]点怒气
    -- a[int]
    [158] = function(role, args)
        local i1 = args[1]
        local onSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                local list = RoleManager.Query(function(v) return v.camp == role.camp end)
                table.sort(list, function(a, b)
                    return a.position < b.position
                end)
                for i= 1, #list do
                    if list[i] and not list[i]:IsRealDead() then
                        list[i]:AddRage(i1, CountTypeName.Add)
                        break
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,



    -- [a]伤害[b]改变[c]%（技能效果111专属被动）
    -- a[持续伤害状态]b[改变类型]c[float]
    [159] = function(role, args)
        local dot = args[1]
        local ct = args[2]
        local f1 = args[3]

        local onSkillEffectBefore = function(skill, e, func)
            if skill.type == BattleSkillType.Special then
                if e.type == 111 then -- 当前只对技能效果103生效
                    if e.args[2] == dot then
                        local factor = BattleUtil.ErrorCorrection(BattleUtil.CountValue(e.args[3], f1, ct))
                        e.args[3] = factor
                        if func then func(e) end
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillEffectBefore, onSkillEffectBefore)
    end,


    -- 受到普攻是有[a]%概率给攻击者附加[b]，每回合对目标造成自身攻击的[c]%伤害，持续[d]回合
    -- a[float]b[持续伤害状态]c[float]d[int]
    [160] = function(role, args)
        local f1 = args[1]
        local dot = args[2]
        local f2 = args[3]
        local i1 = args[3]

        -- 技能后后
        local onBeSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                local attack = role:GetRoleData(RoleDataName.Attack)
                local damage = floor(BattleUtil.ErrorCorrection(attack * f2))
                BattleUtil.RandomDot(f1, dot, role, skill.owner, i1, 1, damage)
            end
        end
        role.Event:AddEvent(BattleEventName.BeSkillCastEnd, onBeSkillCastEnd)
    end,

    -- 攻击目标时目标身上每有1种异常状态（包括麻痹、眩晕、沉默、灼烧、中毒）都会使对其造成的直接伤害提高，异常状态数量乘以[a]%。
    -- a[float]
    [161] = function(role, args)
        local f1 = args[1]
        local function onPassiveDamaging(damagingFunc, target, damage)
            local list = BattleLogic.BuffMgr:GetBuff(target, function(buff)
                return buff.type == BuffName.DOT or buff.type == BuffName.Control
            end)
            if list and damagingFunc then
                local num = #list
                local dd = BattleUtil.CountValue(damage, f1 * num, CountTypeName.AddPencent) - damage
                damagingFunc(-floor(BattleUtil.ErrorCorrection(dd)))
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)
    end,

    -- 当敌方目标处于链接符状态(主动技能110效果）时受到链接符传导效果提高[a]%
    -- a[float]
    [162] = function(role, args)
        local f1 = args[1]
        local onCurse_ShareDamage = function(func)
            if func then func(f1, CountTypeName.Add) end
        end
        role.Event:AddEvent(BattleEventName.Curse_ShareDamage, onCurse_ShareDamage)
    end,


    -- 每当对方拥有链接符的目标死亡时，都会使己方输出型武将技能伤害提高[a]%（[b]元素输出武将提高[c]%)
    -- a[float]b[元素]c[float]
    [163] = function(role, args)
        local f1 = args[1]
        local ele = args[2]
        local f2 = args[3]

        -- 死亡数量
        local num = 0
        local onBattleRoleDead = function(defRole)
            -- 
            if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.Curse, function(buff) return buff.curseType == CurseTypeName.ShareDamage end) then
                num = num + 1
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoleDead, onBattleRoleDead)
        
        -- 
        local cNum = 0  -- 释放技能前记录此次技能提高伤害的目标数量，防止单次技能伤害不一致的问题
        local function onSkillCast()
            cNum = num
        end
        BattleLogic.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)

        -- 技能伤害提高
        local function onPassiveDamaging(damagingFunc, atkRole, defRole, damage, skill)
            if atkRole.professionId == 2 and atkRole.camp == role.camp and skill and skill.type == BattleSkillType.Special then
                -- 地元素特殊
                local f = atkRole.element == ele and f2 or f1
                local dd = BattleUtil.CountValue(damage, f * cNum, CountTypeName.AddPencent) - damage
                damagingFunc(-floor(BattleUtil.ErrorCorrection(dd)))
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)

    end,

    -- 爆伤减免增加[a]%，[b]改变
    -- a[float]b[改变类型]
    [164] = function(role, args)
        local f1 = args[1]
        local ct = args[2]

        local function onCritDamageReduceFactor(damagingFunc, atkRole, defRole)
            if defRole == role then
                if damagingFunc then
                    damagingFunc(f1, ct)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.CritDamageReduceFactor, onCritDamageReduceFactor)
    end,

    -- 战斗中生命每减少[a]%，自身伤害就[b]改变[c]%，减少为[d]改变
    -- a[float]b[改变类型]c[float]d[改变类型]
    [165] = function(role, args)
        local f1 = args[1]
        local ct = args[2]
        local f2 = args[3]
        local ct2 = args[4] -- 废物参数

        -- 释放技能后
        local onPassiveDamaging = function(damagingFunc, defRole, damage, skill)
            local levelDamage = floor(role:GetRoleData(RoleDataName.MaxHp)*f1)
            local lostDamage = role:GetRoleData(RoleDataName.MaxHp) - role:GetRoleData(RoleDataName.Hp)
            local level = floor(lostDamage/levelDamage)

            local dd = BattleUtil.CountValue(damage, f2*level, ct) - damage
            damagingFunc(-floor(BattleUtil.ErrorCorrection(dd)))

        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)
    end,

    -- 普通攻击时如目标处于[a]状态则伤害的[b]%转化为生命治疗自己
    -- a[持续伤害状态]b[float]
    [166] = function(role, args)
        local dot = args[1]
        local f1 = args[2]
        local onHit = function(target, damage, bCrit, finalDmg)
            if BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff) return buff.damageType == dot end) then
                BattleUtil.ApplyTreat(role, role, floor(BattleUtil.ErrorCorrection(finalDmg * f1)))
            end
        end
        local onSkillCast = function(skill)
            if skill.type == BattleSkillType.Normal then
                role.Event:AddEvent(BattleEventName.RoleHit, onHit)
            end
        end
        -- 技能后后
        local onSkillCastEnd = function(skill)
            if skill.type == BattleSkillType.Normal then
                role.Event:RemoveEvent(BattleEventName.RoleHit, onHit)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,

    -- 如果目标数量大于[a]个，增加自身[b]点怒气
    -- a[int]b[int]
    [167] = function(role, args)
        local i1 = args[1]
        local i2 = args[2]
        -- 释放技能后
        local onSkillEnd = function(skill)
            local targets = skill:GetDirectTargets()
            if targets and #targets > i1 then
                role:AddRage(i2, 1)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,

    -- 释放技能后给当前血量最少的2名队友附加无敌吸血盾持续[a]回合
    -- a[int]
    [168] = function(role, args)
        local i1 = args[1]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                local list = RoleManager.Query(function(v) return v.camp == role.camp end)
                BattleUtil.SortByProp(list, RoleDataName.Hp,  1)
                local index = 0 
                for i = 1, #list do 
                    if not list[i]:IsRealDead() and index < 2 then
                        index = index + 1
                        -- 吸血率%25 策划说写死
                        list[i]:AddBuff(Buff.Create(role, BuffName.Shield, i1, ShieldTypeName.AllReduce, 0.25, 0))
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,


    
    -- 行动后增加自身[a]%的[b]（可叠加持续至结束）
    -- a[float]b[属性]
    [169] = function(role, args)
        local f1 = args[1]
        local pro = args[2]
        -- 行动结束后
        local onTurnEnd = function()
            local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[pro], f1, CountTypeName.AddPencent)
            role:AddBuff(buff)
        end
        role.Event:AddEvent(BattleEventName.RoleTurnEnd, onTurnEnd)
    end,


    -- 击杀目标后对敌方血量百分比最低两名角色造成[a]%[b]伤害
    -- a[float]b[伤害类型]
    [170] = function(role, args)
        local f1 = args[1]
        local dt = args[2]
        -- 直接伤害后
        local onRoleHit = function(target, damage, bCrit, finalDmg, damageType, skill)
            if skill and not skill.isAdd and target:IsDead() and BattleUtil.CheckIsNoDead(target) then
                local list = RoleManager.Query(function(v) return v.camp ~= role.camp end)
                BattleUtil.SortByHpFactor(list, 1)
                local index = 0
                for i = 1, #list do 
                    if not list[i]:IsDead() and index < 2 then
                        index = index + 1
                        BattleUtil.CalDamage(nil, role, list[i], dt, f1)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    -- 攻击目标越少[a]对每个目标提升概率越高，提升概率为[b]%除以被击者的总数，提升为[c]改变
    -- a[控制状态]b[float]c[改变类型]
    [172] = function(role, args)
        local ctrl = args[1]
        local f1 = args[2]
        local ct = args[3]

        local af = 0
        local onSkillCast = function(skill)
            local targets = skill:GetDirectTargets()
            if targets and #targets > 0 then
                af = BattleUtil.ErrorCorrection(f1/#targets)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)

        local onPassiveRandomControl = function(func, ctrl2)
            if ctrl == 0 or ctrl == ctrl2 then
                if func then func(af, ct) end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveRandomControl, onPassiveRandomControl)
    end,

    -- 反弹伤害增加[a]%，[b]改变
    -- a[float]b[改变类型]
    [173] = function(role, args)
        local f1 = args[1]
        local ct = args[2]
        local onPassiveRebackDamage = function(func)
            if func then func(f1, ct) end
        end
        role.Event:AddEvent(BattleEventName.PassiveRebackDamage, onPassiveRebackDamage)
    end,

    -- 技能直接伤害治疗生命最少队友治疗量提升[a]%，[b]改变
    -- a[float]b[改变类型]
    [174] = function(role, args)
        local f1 = args[1]
        local ct = args[2]
        
        local onPassiveSkillDamageHeal = function(func)
            if func then func(f1, ct) end
        end
        role.Event:AddEvent(BattleEventName.PassiveSkillDamageHeal, onPassiveSkillDamageHeal)
    end,

    -- 释放技能时，对己方生命最少武将治疗效果额外提升[a]，[b]改变
    -- a[float]b[改变类型]
    [175] = function(role, args)
        local f1 = args[1]
        local ct = args[2]

        local onPassiveTreatingFactor = function(func, target)
            local arr = RoleManager.Query(function (r) return r.camp == role.camp end)
            BattleUtil.SortByHpFactor(arr, 1)
            if arr and arr[1] and arr[1] == target then
                if func then func(f1, ct) end
            end
        end

        local function onSkillCast(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:AddEvent(BattleEventName.PassiveTreatingFactor, onPassiveTreatingFactor)
            end
        end
        local function onSkillCastEnd(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:RemoveEvent(BattleEventName.PassiveTreatingFactor, onPassiveTreatingFactor)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,

    -- 减伤盾抵抗效果提升[a]%,抵抗效果[b]增加，提升效果由所有受益目标平分。
    -- a[float]b[改变类型]
    [176] = function(role, args)
        local f1 = args[1]
        local ct = args[2]

        local af = 0
        local onSkillCast = function(skill)
            local targets = skill.effectTargets[2]
            if targets and #targets > 0 then
                af = BattleUtil.ErrorCorrection(f1/#targets)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)

        local onPassiveShield = function(func, shieldType)
            if shieldType == ShieldTypeName.RateReduce then
                if func then func(af, ct) end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveShield, onPassiveShield)

    end,

    -- 技能治疗效果提升[a]%, 同时为每个技能目标附加减伤盾，减伤效果[b]%,持续[c]回合
    -- a[float]b[float]c[int]
    [177] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local i1 = args[3]

        local onPassiveTreatingFactor = function(func, target)
            if func then func(f1, 1) end
        end

        local function onSkillCast(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:AddEvent(BattleEventName.PassiveTreatingFactor, onPassiveTreatingFactor)
            end
        end
        local function onSkillCastEnd(skill)
            if skill.type == BattleSkillType.Special then
                role.Event:RemoveEvent(BattleEventName.PassiveTreatingFactor, onPassiveTreatingFactor)
                -- 对每个目标附加减伤盾
                local targets = skill:GetDirectTargets()
                for _, target in ipairs(targets) do
                    target:AddBuff(Buff.Create(role, BuffName.Shield, i1, ShieldTypeName.RateReduce, f2, 0))
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,


    -- 攻击目标越少[a]对每个目标提升概率越高，提升率等于[b]%除以被攻击者的总数，[c]改变
    -- a[持续伤害状态]b[float]c[改变类型]
    [178] = function(role, args)
        local dot = args[1]
        local f1 = args[2]
        local ct = args[3]

        local af = 0
        local onSkillCast = function(skill)
            local targets = skill:GetDirectTargets()
            if targets and #targets > 0 then
                af = BattleUtil.ErrorCorrection(f1/#targets)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)

        local onPassiveRandomDot = function(func, dot2)
            if dot == dot2 then
                if func then func(af, ct) end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveRandomDot, onPassiveRandomDot)
    end,

    -- 对别人造成的中毒伤害的[a]%用于治疗自己
    -- a[float]
    [179] = function(role, args)
        local f1 = args[1]
        local dot = DotType.Poison

        local onRoleDamage = function(defRole, damage, bCrit, finalDmg, damageType, dotType, skill)
            if dotType == dot then
                BattleUtil.ApplyTreat(role, role, floor(BattleUtil.ErrorCorrection(finalDmg * f1)))
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamage, onRoleDamage)
    end,


    -- 受到[a]效果概率降低[b]%，[c]改变
    -- a[控制状态]b[float]c[改变类型]
    [180] = function(role, args)
        local ctrl = args[1]
        local f1 = args[2]
        local ct = args[3]

        local onPassiveBeRandomControl = function(func, ctrl2, target)
            if ctrl == 0 or ctrl == ctrl2 then
                if func then func(f1, ct) end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveBeRandomControl, onPassiveBeRandomControl)
    end,


    -- 攻击单体目标时额外降低目标[a]点怒气
    -- a[int]
    [181] = function(role, args)
        local i1 = args[1]

        local function onSkillCastEnd(skill)
            -- 对每个目标附加减伤盾
            local targets = skill:GetDirectTargetsNoMiss()
            if targets and #targets == 1 then
                targets[1]:AddRage(i1, CountTypeName.Sub)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,


    -- 攻击目标越少[a]对每个目标的伤害越高，伤害提升量等于[b]%除以由于自身攻击受到该效果的敌人的总数，[c]改变
    -- a[持续伤害状态]b[float]c[改变类型]
    [182] = function(role, args)
        local dot = args[1]
        local f1 = args[2]
        local ct = args[3]

        local af = 0
        local onSkillCast = function(skill)
            local targets = skill:GetDirectTargets()
            if targets and #targets > 0 then
                af = BattleUtil.ErrorCorrection(f1/#targets)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)

        local onPassiveRandomDot = function(func, dot2, damage)
            if dot == dot2 then
                if func then func(nil, nil, af, ct) end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveRandomDot, onPassiveRandomDot)
    end,

    -- 有该技能角色，释放技能造成的[a]效果附加封治疗效果，该状态武将无法回复生命
    -- a[持续伤害状态]
    [183] = function(role, args)
        local dot = args[1]

        local onBuffCaster = function(buff)
            if buff.type == BuffName.DOT and buff.damageType == dot then
                BattleUtil.RandomControl(1, ControlType.NoHeal, role, buff.target, buff.duration)
            end
        end
        role.Event:AddEvent(BattleEventName.BuffCaster, onBuffCaster)
    end,

    -- [a]状态延长[b]回合
    -- a[持续伤害状态]b[int]
    [184] = function(role, args)
        local dot = args[1]
        local i1 = args[2]

        local onBuffCaster = function(buff)
            if buff.type == BuffName.DOT and buff.damageType == dot then
                buff:ChangeBuffDuration(CountTypeName.Add, i1)
            end
        end
        role.Event:AddEvent(BattleEventName.BuffCaster, onBuffCaster)
    end,


    -- 直接伤害击杀目标对仇恨目标造成[a]%物理伤害
    -- a[float]
    [185] = function(role, args)
        local f1 = args[1]

        local onRoleHit = function(target)
            if target:IsDead() and BattleUtil.CheckIsNoDead(target) then
                local target = RoleManager.GetAliveAggro(role)
                BattleUtil.CalDamage(nil, role, target, 1, f1)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    -- 直接伤害击杀目标对仇恨目标追加一次造成[a]%物理伤害的技能
    -- a[float]
    -- [185] = function(role, args)
    --     local f1 = args[1]

    --     local onRoleHit = function(target)
    --         if target:IsDead() then
    --             local skill = {
    --                 role.skill[1],  -- 技能id
    --                 {
    --                     400000, -- chooseId
    --                     role.skill[2][2],   -- 效果时间 
    --                     {1, f1, 1}  -- 效果id及参数
    --                 }
    --             }
    --             SkillManager.AddSkill(role, skill, BattleSkillType.Normal, nil, true, false)
    --         end
    --     end
    --     role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    -- end,


    -- 攻击纵排目标时额外降低目标[a]点怒气
    -- a[int]
    [186] = function(role, args)
        local i1 = args[1]

        local onSkillCastEnd = function(skill)
            local effectGroup = skill.effectList.buffer[1]
            local chooseId = effectGroup.chooseId
            local chooseLimit = floor(chooseId / 10000) % 10
            if chooseLimit == 3 then    -- 打纵列
                local targets = skill:GetDirectTargetsNoMiss()
                if targets then
                    for _, r in ipairs(targets) do
                        r:AddRage(i1, CountTypeName.Sub)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,

    -- 普攻[a]%概率暴击
    -- a[float]
    [187] = function(role, args)
        local f1 = args[1]
        local function onSkillCast(skill)
            if skill.type == BattleSkillType.Normal then
                role.data:AddValue(RoleDataName.Crit, f1)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)

        local function onSkillCastEnd(skill)
            if skill.type == BattleSkillType.Normal then
                role.data:SubValue(RoleDataName.Crit, f1)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillCastEnd)
    end,

    -- 受到伤害降低[a]%（与减伤盾同效果）并且将自身受到非致命伤害平分给自身及己方当前生命最高的两名武将（被平摊武将有无敌也会受到伤害）降低伤害[b]改变
    -- a[float]b[改变类型]
    [188] = function(role, args)
        local f1 = args[1]
        local ct = args[2]
        

        local onFinalBeDamage = function(damagingFunc, atkRole, damage, skill, dotType, bCrit, damageType)
            -- 伤害降低
            local finalDamage = BattleUtil.CountValue(damage, f1, ct)
            local curHp = role:GetRoleData(RoleDataName.Hp)
            -- 不是致死伤害
            if finalDamage < curHp then
                -- 找到除自身外的血量最高的两人
                local list = RoleManager.Query(function(v)
                    return v.camp == role.camp and v.position ~= role.position
                end)
                local ff = 1    -- 分摊比
                -- 检测被动对分摊比的影响
                local cl = {}
                local function _CallBack(v, ct)
                    if v then
                        table.insert(cl, {v, ct})
                    end
                end
                role.Event:DispatchEvent(BattleEventName.PassiveDamageShare, _CallBack)
                atkRole.Event:DispatchEvent(BattleEventName.PassiveDamageBeShare, _CallBack)
                ff = BattleUtil.CountChangeList(ff, cl)

                -- 计算分摊伤害
                local fenDamage = finalDamage * ff      -- 需要分摊的总伤害
                list = BattleUtil.SortByProp(list, RoleDataName.Hp, 0)
                local targets = {role, list[1], list[2]}
                local fd = floor(BattleUtil.ErrorCorrection(fenDamage/#targets)) -- 每个人需要分摊的伤害

                -- 自身伤害
                if damagingFunc then
                    local unFenDamage = floor(BattleUtil.ErrorCorrection(finalDamage * (1 - ff))) -- 不被分摊的伤害
                    damagingFunc(floor(BattleUtil.ErrorCorrection(damage - (unFenDamage + fd))))
                end
                -- 平分给别人
                if fd > 0 then
                    for i = 2, #targets do
                        BattleUtil.FinalDamage(skill, atkRole, targets[i], fd, nil, 0, dotType)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.FinalBeDamage, onFinalBeDamage)

    end,

    -- 有该技能角色，造成的[a]效果会使目标无法获得无敌盾和无敌吸血盾效果
    -- a[持续伤害状态]
    [189] = function(role, args)
        local dot = args[1]

        local onBuffCaster = function(buff)
            if buff.type == BuffName.DOT and buff.damageType == dot then
                buff.target:AddBuff(Buff.Create(role, BuffName.Immune, buff.duration, 3))
            end
        end
        role.Event:AddEvent(BattleEventName.BuffCaster, onBuffCaster)
    end,

    -- 所有攻击优先攻击敌方[a]最少的单位
    -- a[属性]
    [190] = function(role, args)
        local pro = args[1]

        local function onSkillTargetCheck(func)
            local list = RoleManager.Query(function(r)
                return r.camp == (role.camp + 1) % 2 
            end)    
            list = BattleUtil.SortByProp(list, BattlePropList[pro], 1)
            if list and #list > 0 then 
                if func then func({list[1]}) end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillTargetCheck, onSkillTargetCheck)
    end,

    -- 技能直接伤害[a]%转化为生命治疗自己
    -- a[float]
    [191] = function(role, args)
        local f1 = args[1]

        local onHit = function(target, damage, bCrit, finalDmg, dtype, skill)
            if skill and skill.type == BattleSkillType.Special then
                -- 检测技能伤害治疗加成
                local f = BattleUtil.CheckSkillDamageHeal(f1, role, target)
                -- 治疗自己
                BattleUtil.ApplyTreat(role, role, floor(BattleUtil.ErrorCorrection(finalDmg * f)))
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onHit)
    end,
    -- 武将怒气小于[a]点时不会释放技能，释放技能消耗当前所有怒气超过4怒气部分每额外消耗1点怒气技能伤害增加[b]%
    -- a[int]b[float]
    [192] = function(role, args)
        local i1 = args[1]
        local f1 = args[2]

        -- 提高技能释放怒气值
        role.SuperSkillRage = i1

        -- 
        local allRage = 0
        local function onRoleRageCost(rage, rate, func)
            allRage = role.Rage
            local deltaRage = allRage - role.SuperSkillRage
            if func then
                func(0, deltaRage)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleRageCost, onRoleRageCost)


        -- 释放技能后
        local onPassiveDamaging = function(damagingFunc, defRole, damage, skill, dotType)
            if skill and skill.type == BattleSkillType.Special then
                local deltaRage = allRage - 4
                if deltaRage > 0 then
                    local dd = BattleUtil.CountValue(damage, f1 * deltaRage, 2) - damage
                    damagingFunc(-floor(BattleUtil.ErrorCorrection(dd))) 
                end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, onPassiveDamaging)

    end,   

    -- 对己方生命最少的三个武将治疗效果额外提升治疗武将攻击的[a]%，提升为[b]改变
    -- a[float]b[改变类型]
    [193] = function(role, args)
        local f1 = args[1]
        local ct = args[2]

        local OnPassiveTreating = function(treatingFunc, target)
            local arr = RoleManager.Query(function (r) return r.camp == role.camp end)
            BattleUtil.SortByHpFactor(arr, 1)
            if not arr then return end
            for i = 1, 3 do
                if arr[i] and arr[i] == target then
                    local atk = role:GetRoleData(RoleDataName.Attack)
                    treatingFunc(atk * f1, ct)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveTreating, OnPassiveTreating)
    end,


    -- 攻击有概率清除敌方武将无敌盾和无敌吸血盾，攻击目标越少，清除概率越高，对每个受击者清除概率等于[a]%除以受击者的总数
    -- a[float]
    [194] = function(role, args)
        local f1 = args[1]

        local OnRoleDamageBefore = function(defRole, factorFunc, damageType, skill)
            local targets = skill:GetDirectTargets()
            if not targets or #targets == 0 then return end
            local cf = f1/#targets
            for _, target in ipairs(targets) do
                BattleUtil.RandomAction(cf, function()
                    BattleLogic.BuffMgr:ClearBuff(target, function(buff)
                        return buff.type == BuffName.Shield and buff.shieldType == ShieldTypeName.AllReduce
                    end)
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, OnRoleDamageBefore)
    end,

    -- 首回合免疫[a]效果
    -- a[控制状态]
    [195] = function(role, args)
        local ctrl = args[1]
        
        local immune = function(buff)
            return buff.type == BuffName.Control and (ctrl == 0 or buff.ctrlType == ctrl)
        end

        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, function(curRound)
            -- 第i1回合开始
            if curRound == 1 then
                role.buffFilter:Add(immune)
            end
            -- 第i1+i2回合结束
            if curRound == 2 then
                for i = 1, role.buffFilter.size do
                    if role.buffFilter.buffer[i] == immune then
                        role.buffFilter:Remove(i)
                        break
                    end
                end
            end
        end)
    end,

    -- 对敌方造成伤害如被分摊其分摊比降低[a]%
    -- a[float]
    [196] = function(role, args)
        local f1 = args[1]
        local onDamageBeShare = function(func)
            if func then func(f1, CountTypeName.Sub) end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamageBeShare, onDamageBeShare)
    end,
    
    -- 技能直接击杀敌方目标时有[a]%概率获得目标剩余所有怒气（输出武将佩戴）
    -- a[float]
    [197] = function(role, args)
        local f1 = args[1]
        local onRoleHit = function(target, damage, bCrit, finalDmg, damageType, skill)
            if skill and skill.type == BattleSkillType.Special and target:IsDead() and BattleUtil.CheckIsNoDead(target) then
                BattleUtil.RandomAction(f1, function()
                    role:AddRage(target.Rage, CountTypeName.Add)
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    -- 受到的[a]效果伤害降低[b]%(与减伤盾原理相同）[c]改变
    -- a[持续伤害状态]b[float]c[改变类型]
    [198] = function(role, args)
        local dot = args[1]
        local f1 = args[2]
        local ct = args[3]

        -- 释放技能后
        local onPassiveBeDamaging = function(damagingFunc, defRole, damage, skill, dotType)
            if dotType and (dotType == dot or dot == 0) then
                local dd = damage - BattleUtil.CountValue(damage, f1, ct)
                damagingFunc(floor(BattleUtil.ErrorCorrection(dd))) 
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveBeDamaging, onPassiveBeDamaging)

    end,


    --每回合最多受到自身生命上限[a]%的伤害（该伤害为来自武将的直接伤害）
    --a[float]
    [199] = function(role, args)
        local f1 = args[1]

        local curDamage = 0
        local function onRoundChange()
            curDamage = 0
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)
        

        local function onFinalBeDamage(damagingFunc, atkRole, damage, skill, dotType, bCrit, damageType)
            local maxDamage = role:GetRoleData(RoleDataName.MaxHp) * f1
            curDamage = curDamage + damage
            if curDamage > maxDamage then
                -- 计算免除的伤害值
                local md = curDamage - maxDamage
                if md > damage then
                    md = damage
                end
                if damagingFunc then damagingFunc(md) end
            end

        end
        role.Event:AddEvent(BattleEventName.FinalBeDamage, onFinalBeDamage)
    end,


    -- 同阵营武将受到直接伤害时该伤害[a]%转移给有此锦囊的武将转移伤害属于直接伤害（无法触发任何特性）
    -- a[float]
    [200] = function(role, args)
        local f1 = args[1]

        local onFinalDamage = function(damagingFunc, atkRole, defRole, damage, skill, dotType, bCrit, damageType)
            if skill and role.position ~= defRole.position and defRole.camp == role.camp and defRole.element == role.element then
                local shareDamage = floor(BattleUtil.ErrorCorrection(damage * f1)) 
                -- 被攻击武将自身伤害
                if damagingFunc then
                    damagingFunc(shareDamage)
                end
                -- 分担伤害
                BattleUtil.ApplyDamage(nil, atkRole, role, shareDamage)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.FinalDamage, onFinalDamage)

    end,

    -- 初始怒气增加[a]点并且目标血量低于[b]%时即有概率秒杀（对应秒杀技能）
    -- a[int]b[float]
    [201] = function(role, args)
        local i1 = args[1]
        local f1 = args[2]
        role:AddRage(i1, CountTypeName.Add)

        local function onPassiveSeckill(func)
            if func then func(f1, CountTypeName.Cover) end
        end
        role.Event:AddEvent(BattleEventName.PassiveSeckill, onPassiveSeckill)
    end,

    -- 秒杀概率增加[a]%直接伤害击杀的[b]目标有[c]%概率无法复活触发秒杀的目标[d]%无法复活，秒杀概率[e]改变
    -- a[float]b[持续伤害状态]c[float]d[float]e[改变类型]
    [202] = function(role, args)
        local f1 = args[1]
        local dot = args[2]
        local f2 = args[3]
        local f3 = args[4]
        local ct = args[5]

        -- 秒杀概率增加
        local function onPassiveSeckill(func)
            if func then func(nil, nil, f1, ct) end
        end
        role.Event:AddEvent(BattleEventName.PassiveSeckill, onPassiveSeckill)

        -- 直接伤害概率无法复活
        local function onRoleHit(target)
            if target:IsDead() then
                if not BattleLogic.BuffMgr:HasBuff(role, BuffName.DOT, function (buff) return buff.damageType == dot or dot == 0 end) then
                    BattleUtil.RandomAction(f2, function()
                        target:SetReliveFilter(false)
                    end)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)



        -- 秒杀概率无法复活
        local function onSecKill(target)
            BattleUtil.RandomAction(f3, function()
                target:SetReliveFilter(false)
            end)
        end
        role.Event:AddEvent(BattleEventName.Seckill, onSecKill)

    end,



    -- 初始怒气增加[a]点敌方处于连接符状态的目标在回合结束时有[b]概率减少[c]点怒气
    -- a[int]b[int]
    [203] = function(role, args)
        local i1 = args[1]
        local f1 = args[2]
        local i2 = args[3]
        -- 初始怒气增加
        role:AddRage(i1, CountTypeName.Add)

        -- 死亡数量
        local onRoleTurnEnd = function(target)
            if not target:IsDead() and BattleLogic.BuffMgr:HasBuff(target, BuffName.Curse, function(buff) return buff.curseType == CurseTypeName.ShareDamage end) then
                BattleUtil.RandomAction(f1, function()
                    target:AddRage(i2, CountTypeName.Sub)
                end)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.RoleTurnEnd, onRoleTurnEnd)

    end,


    -- 敌方处于连接符状态的目标在获得无敌盾时有[a]%概率获取失败
    -- a[float]
    [204] = function(role, args)
        local f1 = args[1]
        -- 死亡数量
        local onRoleAddBuffMiss = function(func, target, buff)
            -- 无敌盾
            if buff.type == BuffName.Shield and buff.shieldType == ShieldTypeName.AllReduce then
                -- 有连接符
                if BattleLogic.BuffMgr:HasBuff(target, BuffName.Curse, function(buff) return buff.curseType == CurseTypeName.ShareDamage end) then
                    -- 提高miss概率
                    if func then func(f1, CountTypeName.Add) end
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.RoleAddBuffMiss, onRoleAddBuffMiss)
    end,

    -- 伤害增加[a]%，[b]改变
    -- a[float]b[改变类型]
    [205] = function(role, args)
        local f1 = args[1]
        local ct = args[2]
        local passivityDamaging = function(func, caster, damage, skill)
            if skill and func then 
                local dd = BattleUtil.CountValue(damage, f1, ct) - damage
                func(-floor(BattleUtil.ErrorCorrection(dd)))
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, passivityDamaging)
    end,
    


    --技能治疗系数[a]改变[b]%(作用于主动技能效果103)
    --a[改变类型]b[float]
    [206] = function(role, args)
        local ct = args[1]
        local f1 = args[2]

        local onSkillEffectBefore = function(skill, e, func)
            if skill.type == BattleSkillType.Special then
                if e.type == 103 then -- 当前只对技能效果103生效
                    local factor = BattleUtil.ErrorCorrection(BattleUtil.CountValue(e.args[3], f1, ct))
                    e.args[3] = factor
                    if func then func(e) end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillEffectBefore, onSkillEffectBefore)
    end,


    -- 释放技能有[a]%几率对敌方后排造成[b]%[c]伤害
    -- a[float]b[float]c[伤害类型]
    [207] = function(role, args)
        
        local f1 = args[1]
        local f2 = args[2]
        local dt = args[3]
        -- 释放技能后
        local onSkillEnd = function(skill)
            if skill.type == BattleSkillType.Special then
                BattleUtil.RandomAction(f1, function()
                    BattleLogic.WaitForTrigger(0.1, function()
                        local list = RoleManager.Query(function(v)
                            return v.camp == (role.camp + 1) % 2 and v.position > 3
                        end)
                        for _, r in ipairs(list) do
                            BattleUtil.CalDamage(nil, role, r, dt, f2)
                        end
                    end)
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)

    end,


    -- 如果自身是[a],则[d]改变[b]的[c]，[g改变[e]的[f]
    -- a[位置],b[float],c[属性],d[改变类型],e[float],f[属性],g[改变类型]
    [208] = function(role, args)
        local i1 = args[1]
        local f1 = args[2]
        local pro1 = args[3]
        local ct1 = args[4]
        local f2 = args[5]
        local pro2 = args[6]
        local ct2 = args[7]

        if BattleUtil.GetRolePosType(role.position) == i1 then
            BattleUtil.AddProp(role, pro1, f1, ct1)
            BattleUtil.AddProp(role, pro2, f2, ct2)
        end

    end,


    -- 我方[a]武将全部阵亡后，如果自身是[a],则[d]改变[b]的[c]
    -- a[位置],b[位置],c[float],d[属性],e[改变类型]
    [209] = function(role, args)
        local i1 = args[1]
        local i2 = args[2]
        local f1 = args[3]
        local pro = args[4]
        local ct = args[5]


        local function _OnRoleRealDead(deadRole)
            if role.camp == deadRole.camp then
                local list = BattleUtil.GetRoleListByPosType(role.camp, i1)
                if not list or #list == 0 then
                    if BattleUtil.GetRolePosType(role.position) == i2 then
                        BattleUtil.AddProp(role, pro, f1, ct)
                        -- 移除事件监听
                        BattleLogic.Event:RemoveEvent(BattleEventName.RoleRealDead, _OnRoleRealDead)
                    end
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.RoleRealDead, _OnRoleRealDead)
    end,

    -- 如果自身是[a]和[b]武将则[e]改变[c]的[d]
    -- a[类型],b[类型],c[float],d[属性],e[改变类型]
    [210] = function(role, args)
        local pf1 = args[1]
        local pf2 = args[2]
        local f1 = args[3]
        local pro = args[4]
        local ct = args[5]

        if role.professionId == pf1 or role.professionId == pf2 then
            BattleUtil.AddProp(role, pro, f1, ct)
        end
    end,

    -- 第[a]回合开始时，如果自身血量最低，则恢复[b]*[c]的血量
    -- a[int],b[属性],c[float]
    [211] = function(role, args)
        if PassiveManager.passiveCountList[role.camp][211] and PassiveManager.passiveCountList[role.camp][211] > 0 then 
            return
        end
        PassiveManager.passiveCountList[role.camp][211] = 1


        local round = args[1]
        local pro = args[2]
        local f1 = args[3]

        local function onRoundChange(curRound)
            if curRound == round then
                local list = RoleManager.Query(function(r) return r.camp == role.camp end)    
                list = BattleUtil.SortByProp(list, RoleDataName.Hp, 1)
                local base = list[1]:GetRoleData(BattlePropList[pro])
                local value = floor(BattleUtil.ErrorCorrection(base* f1))
                BattleUtil.ApplyTreat(list[1], list[1], value)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)
    end,

    -- 战斗开始时， 自身血量高于[a]%， 则[d]改变[b]的[c]
    -- a[float],b[float],c[属性],d[改变类型]
    [212] = function(role, args)
        local f1 = args[1]
        local f2 = args[2]
        local pro = args[3]
        local ct = args[4]

        local hp = role:GetRoleData(RoleDataName.Hp)
        local maxHp = role:GetRoleData(RoleDataName.MaxHp)
        if hp/maxHp >= f1 then
            BattleUtil.AddProp(role, pro, f2, ct)
        end
    end,

    -- 战斗开始时，回复自身[a]点怒气 -- 
    -- a[int]
    [213] = function(role, args)
        local i1 = args[1]
        local function onRoundChange(curRound)
            if curRound == 1 then
                role:AddRage(i1, CountTypeName.Add)
                -- BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundChange, onRoundChange)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)
    end,

    -- 同阵营只会有一个生效
    -- 第[a]回合中，敌人受到的任何伤害会对其他敌人造成该伤害[b]%的伤害
    -- a[float],b[float]
    [214] = function(role, args)
        if PassiveManager.passiveCountList[role.camp][214] and PassiveManager.passiveCountList[role.camp][214] > 0 then 
            return
        end
        PassiveManager.passiveCountList[role.camp][214] = 1

        local i1 = args[1]
        local f1 = args[2]

        local function OnDamage(func, atkRole, defRole, damage, skill, dotType, bCrit, damageType)
            if defRole.camp ~= role.camp then
                if skill or dotType then
                    local list = RoleManager.Query(function(r) return r.camp == defRole.camp and r ~= defRole end)   
                    for _, r in ipairs(list) do
                        local dd = floor(BattleUtil.ErrorCorrection(damage* f1))
                        BattleUtil.ApplyDamage(nil, role, r, dd)
                    end
                end
            end
        end

        local function onRoundChange(curRound)
            if curRound == i1 then
                BattleLogic.Event:AddEvent(BattleEventName.FinalDamage, OnDamage)

            elseif curRound == i1 + 1 then
                BattleLogic.Event:RemoveEvent(BattleEventName.FinalDamage, OnDamage)
                -- BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundChange, onRoundChange)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)

    end,

    -- 战斗开始时，使随机一名敌人受到的伤害增加[a]%，持续[b]回合。持续期间目标敌人死亡时，转移给另一名随机敌人
    -- a[float],b[int]
    [215] = function(role, args)
        if PassiveManager.passiveCountList[role.camp][215] and PassiveManager.passiveCountList[role.camp][215] > 0 then 
            return
        end
        PassiveManager.passiveCountList[role.camp][215] = 1

        local f1 = args[1]
        local i1 = args[2]

        local target 
        local function RandomTarget()
            local list = RoleManager.Query(function(r)
                return r.camp ~= role.camp
            end)
            if #list < 1 then return end
            local index = Random.RangeInt(1, #list)
            target = list[index]
        end

        -- 伤害增加
        local function _OnPassiveDamaging(damagingFunc, atkRole, defRole, damage)
            if defRole == target then
                local dd = floor(BattleUtil.ErrorCorrection(damage* f1))
                if damagingFunc then damagingFunc(-dd) end
            end
        end

        -- 死亡重新随机
        local function _OnRoleRealDead(deadRole)
            if deadRole == target then
                RandomTarget()
            end
        end

        -- 
        local function onRoundChange(curRound)
            if curRound == 1 then
                RandomTarget()
                BattleLogic.Event:AddEvent(BattleEventName.PassiveDamaging, _OnPassiveDamaging)
                BattleLogic.Event:AddEvent(BattleEventName.RoleRealDead, _OnRoleRealDead)
            elseif curRound == i1 + 1 then
                target = nil
                BattleLogic.Event:RemoveEvent(BattleEventName.PassiveDamaging, _OnPassiveDamaging)
                BattleLogic.Event:RemoveEvent(BattleEventName.RoleRealDead, _OnRoleRealDead)
                -- BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundChange, onRoundChange)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)

    end,

    -- 第[a]回合开始时，对敌方全体造成目标最大生命值[b]%的伤害，并有[c]%概率造成[d]效果，持续[e]回合。
    -- a[int],b[float],c[float],d[控制类型],e[int]
    [216] = function(role, args)
        if PassiveManager.passiveCountList[role.camp][216] and PassiveManager.passiveCountList[role.camp][216] > 0 then 
            return
        end
        PassiveManager.passiveCountList[role.camp][216] = 1

        local i1 = args[1]
        local f1 = args[2]
        local f2 = args[3]
        local ctrl = args[4]
        local i2 = args[5]

        local function onRoundChange(curRound)
            if curRound == i1 then
                local list = RoleManager.Query(function(r) return r.camp ~= role.camp end)   
                for _, r in ipairs(list) do
                    -- 
                    local dd = floor(BattleUtil.ErrorCorrection(r:GetRoleData(RoleDataName.MaxHp)* f1))
                    local das = BattleUtil.PreCountShield(r, dd) -- 计算护盾吸收后的伤害值
                    local hp = r:GetRoleData(RoleDataName.Hp)
                    -- 有瑕疵，百分比减伤盾可能出现剩余血量不为1的问题
                    if das > hp then    -- 护盾后伤害值依然致死
                        dd = dd - das + hp - 1
                    end
                    BattleUtil.ApplyDamage(nil, role, r, dd)
                    --概率控制
                    BattleUtil.RandomControl(f2, ctrl, role, r, i2)
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)

    end,

    -- 战斗结束时，恢复自身[a]的损失血量
    -- a[float]
    [217] = function(role, args)
        local f1 = args[1]
        local function onBeforeBattleEnd()
            if not role:IsDead() then
                local maxHp = BattleUtil.ErrorCorrection(role:GetRoleData(RoleDataName.MaxHp))
                local hp =  BattleUtil.ErrorCorrection(role:GetRoleData(RoleDataName.Hp))
                local dd = floor((maxHp - hp) * f1)
                BattleUtil.ApplyTreat(role, role, dd)

            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BeforeBattleEnd, onBeforeBattleEnd)
    end,

    --[218] 用 79实现


    -- 敌方首次释放技能时，自身获得[a]*[b]的护盾，持续[c]回合
    -- a[属性],b[float],c[int]
    [219] = function(role, args)
        local pro = args[1]
        local f1 = args[2]
        local i1 = args[3]

        local counter = 0
        local function _OnSkillCast(skill)
            if counter == 0 and skill.owner.camp ~= role.camp and skill.type == BattleSkillType.Special then
                local dd = floor(BattleUtil.ErrorCorrection(role:GetRoleData(BattlePropList[pro])*f1))
                local buff = Buff.Create(skill.owner, BuffName.Shield, i1, ShieldTypeName.NormalReduce, dd, 0)
                role:AddBuff(buff)
                counter = counter + 1
                -- BattleLogic.Event:RemoveEvent(BattleEventName.SkillCast, _OnSkillCast)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.SkillCast, _OnSkillCast)
    end,




    -- 每当敌方英雄死亡时，自身[d]改变[b]的[c]，[g改变[e]的[f]
    -- b[float],c[属性],d[改变类型],e[float],f[属性],g[改变类型]
    [220] = function(role, args)
        local f1 = args[1]
        local pro1 = args[2]
        local ct1 = args[3]
        local f2 = args[4]
        local pro2 = args[5]
        local ct2 = args[6]

        local function _OnRoleRealDead(deadRole)
            if role.camp ~= deadRole.camp then
                BattleUtil.AddProp(role, pro1, f1, ct1)
                BattleUtil.AddProp(role, pro2, f2, ct2)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.RoleRealDead, _OnRoleRealDead)
    end,

    -- 我方武将造成伤害时，[a]概率降低目标[b]%的[c]。若同时拥有效果222，则降低的属性加给伤害者。
    -- a[float],b[float],c[属性]
    [221] = function(role, args)
        local rand = args[1]
        local f1 = args[2]
        local pro = args[3]

        role:AddBuff(Buff.Create(role, BuffName.Brand, 0, "YUAN"))  -- 鸳
        -- 
        local function _OnRoleHit(target)
            BattleUtil.RandomAction(rand, function()
                local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[pro], f1, CountTypeName.Sub)
                buff.cover = true
                buff.maxLayer = 1
                target:AddBuff(buff)
                -- BattleUtil.AddProp(target, pro, f1, CountTypeName.Sub)

                if BattleLogic.BuffMgr:HasBuff(role, BuffName.Brand, function(buff) return buff.flag == "YANG" end) then
                    local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[pro], f1, CountTypeName.Add)
                    buff.cover = true
                    buff.maxLayer = 1
                    role:AddBuff(buff)
                    -- BattleUtil.AddProp(role, pro, f1, CountTypeName.Add)
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, _OnRoleHit)

    end,


    -- 我方武将造成伤害时，[a]概率降低目标[b]%的[c]。若同时拥有效果221，则降低的属性加给伤害者。
    -- a[float],b[float],c[属性]
    [222] = function(role, args)
        local rand = args[1]
        local f1 = args[2]
        local pro = args[3]

        role:AddBuff(Buff.Create(role, BuffName.Brand, 0, "YANG")) -- 鸯
        -- 
        local function _OnRoleHit(target)
            BattleUtil.RandomAction(rand, function()
                local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[pro], f1, CountTypeName.Sub)
                buff.cover = true
                buff.maxLayer = 1
                target:AddBuff(buff)
                -- BattleUtil.AddProp(target, pro, f1, CountTypeName.Sub)

                if BattleLogic.BuffMgr:HasBuff(role, BuffName.Brand, function(buff) return buff.flag == "YUAN" end) then
                    local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[pro], f1, CountTypeName.Add)
                    buff.cover = true
                    buff.maxLayer = 1
                    role:AddBuff(buff)
                    -- BattleUtil.AddProp(role, pro, f1, CountTypeName.Add)
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, _OnRoleHit)


    end,




    -- 普攻时，[a]概率附加[b]效果，每回合造成攻击[c]%的伤害，持续[d]秒。
    -- a[float],b[持续伤害效果],c[float],d[int]
    [223] = function(role, args)
        local rand = args[1]
        local dot = args[2]
        local f1 = args[3]
        local i1 = args[3]
        
        local function _OnRoleHit(target, damage, _, finalDmg, _, skill)
            -- BattleUtil.RandomDot(rand, dot, role, target, i1, 1, )
            if skill and skill.type == BattleSkillType.Normal then
                BattleUtil.RandomAction(rand, function()
                    target:AddBuff(Buff.Create(role, BuffName.DOT, i1, 1, dot, 2, f1))
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, _OnRoleHit)
    end,

    -- 我方武将造成伤害时，[a]概率附加攻击[b]%的真伤。
    -- a[float],b[float]
    [224] = function(role, args)
        local rand = args[1]
        local f1 = args[2]

        local function _OnRoleHit(target)
            BattleUtil.RandomAction(rand, function()
                -- local dd = floor(BattleUtil.ErrorCorrection(role:GetRoleData(RoleDataName.Attack)*f1))
                BattleUtil.CalDamage(nil, role, target, 1, f1, 1)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, _OnRoleHit)
    end,

    -- 
    [225] = function(role, args)
        --王振兴添加
        local f1 = args[1]
        local pro1 = args[2]
        local ct1 = args[3]
        local maxNum = args[4]
        -- 紫+橙
        local num = OutDataManager.GetOutData(role.camp, OutDataName.MisteryLiquidUsedTimes)
        
        num = min(maxNum, num)
        BattleUtil.AddProp(role, pro1, f1 * num, ct1) 

    end,

    -- 斩杀生命低于[a]的敌人
    -- a[float]
    [226] = function(role, args)
        local f1 = args[1]
        -- 
        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if skill and not defRole:IsDead() then
                -- 检测被动技能对秒杀参数得影响
                local bf, kf = BattleUtil.CheckSeckill(f1, 0, role, defRole)
                --
                local ft = defRole:GetRoleData(RoleDataName.Hp)/defRole:GetRoleData(RoleDataName.MaxHp)
                if ft < bf then
                    -- 秒杀
                    BattleUtil.Seckill(skill, role, defRole)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    -- 杀敌回复自身[a]*[b]的血量
    -- a[属性],b[float]
    [227] = function(role, args)
        local pro = args[1] 
        local f1 = args[2]

        -- 杀敌回血
        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if skill and defRole:IsDead() then
                -- 回血
                local dd = floor(BattleUtil.ErrorCorrection(role:GetRoleData(BattlePropList[pro])*f1))
                BattleUtil.ApplyTreat(role, role, dd)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    -- 敌人生命越高，造成的伤害越高，最高[a]%
    -- a[float]
    [228] = function(role, args)
        local f1 = args[1]

        local OnPassiveDamaging = function(damagingFunc, target, damage)
            damagingFunc(-floor(BattleUtil.FP_Mul(f1, damage, BattleUtil.GetHPPencent(target))))
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
    end,

    -- 自己血量越低，造成伤害越高，最多[a]%
    -- a[float]
    [229] = function(role, args)
        local f1 = args[1]

        local OnPassiveDamaging = function(damagingFunc, target, damage)
            damagingFunc(-floor(BattleUtil.FP_Mul(f1, damage, 1 - BattleUtil.GetHPPencent(role))))
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
    end,





    -- 同阵营只生效一次
    -- 敌方武将[c]改变[a]的[b]
    -- a[float],b[属性],c[改变类型]
    [230] = function(role, args)
        if PassiveManager.passiveCountList[role.camp][230] and PassiveManager.passiveCountList[role.camp][230] > 0 then 
            return
        end
        PassiveManager.passiveCountList[role.camp][230] = 1

        local f1 = args[1]
        local pro = args[2] 
        local ct = args[3]

        local function _OnRoundChange(curRound)
            if curRound == 1 then
                local list = RoleManager.Query(function(r)
                    return r.camp ~= role.camp
                end)
                for _, r in ipairs(list) do
                    BattleUtil.AddProp(r, pro, f1, ct)
                end
                -- BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    -- 我方[a]武将每回合[d]改变[b]的[c]，可叠加
    -- a[元素],b[float],c[属性],d[改变类型]
    [231] = function(role, args)
        local ele = args[1]
        local f1 = args[2]
        local pro = args[3]
        local ct = args[4]


        local function _OnRoundChange(curRound)
            if role.element == ele then
                BattleUtil.AddProp(role, pro, f1, ct)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,



    -- 我方[a]武将每回合恢复[b]的损失血量
    -- a[元素],b[float]
    [232] = function(role, args)
        local ele = args[1]
        local f1 = args[2]

        local function _OnRoundChange(curRound)
            if role.element == ele then
                local maxHp = BattleUtil.ErrorCorrection(role:GetRoleData(RoleDataName.MaxHp))
                local hp =  BattleUtil.ErrorCorrection(role:GetRoleData(RoleDataName.Hp))
                local dd = floor((maxHp - hp) * f1)
                BattleUtil.ApplyTreat(role, role, dd)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    -- 我方[a]武将每回合获得[b]*[c]的护盾，持续[d]回合
    -- a[元素],b[属性],c[float],d[int]
    [233] = function(role, args)
        local ele = args[1]
        local pro = args[2]
        local f1 = args[3]
        local i1 = args[4]

        local function _OnRoundChange(curRound)
            if role.element == ele then
                local dd = floor(BattleUtil.ErrorCorrection(role:GetRoleData(BattlePropList[pro])*f1))
                local buff = Buff.Create(role, BuffName.Shield, i1, ShieldTypeName.NormalReduce, dd, 0)
                role:AddBuff(buff)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    -- 我方[a]武将每回合[b]概率回复[c]点怒气
    -- a[元素],b[float],c[int]
    [234] = function(role, args)
        local ele = args[1]
        local f1 = args[2]
        local i1 = args[3]

        local function _OnRoundChange(curRound)
            if role.element == ele then
                BattleUtil.RandomAction(f1, function()
                    role:AddRage(i1, CountTypeName.Add)
                end)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    -- 我方每有一个[a]武将，自身[d]改变[b]的[c]，可叠加（第一回合开始时生效）
    -- a[元素],b[float],c[属性],d[改变类型]
    [235] = function(role, args)
        local ele = args[1]
        local f1 = args[2]
        local pro = args[3]
        local ct = args[4]

        local function _OnRoundChange(curRound)
            if curRound == 1 then
                local list = RoleManager.Query(function(r)
                    return r.camp == role.camp and r.element == ele
                end)
                -- 
                local num = #list
                BattleUtil.AddProp(role, pro, f1*num, ct)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    -- 猎妖之路专属
    -- 根据同时拥有夜明珠的数量获得效果：2个：[c]改变[a]的[b]；3个：[f]改变[d]的[e]；4个：[i]改变[g]的[h]
    -- a[float],b[属性],c[改变类型],d[float],e[属性],f[改变类型],g[float],h[属性],i[改变类型]
    [237] = function(role, args)
        local f1 = args[1]
        local pro1 = args[2]
        local ct1 = args[3]
        local f2 = args[4]
        local pro2 = args[5]
        local ct2 = args[6]
        local f3 = args[7]
        local pro3 = args[8]
        local ct3 = args[9]


        local num = OutDataManager.GetOutData(role.camp, OutDataName.DarkGlowBallNum)
        if num >= 2 then
            BattleUtil.AddProp(role, pro1, f1, ct1)
        end
        if num >= 3 then
            BattleUtil.AddProp(role, pro2, f2, ct2)
        end
        if num >= 4 then
            BattleUtil.AddProp(role, pro3, f3, ct3)
        end
    end,
    -- 猎妖之路专属
    -- 在大闹天空的第[a]层中，我方武将[d]改变[b]的[c]，[g改变[e]的[f]
    -- a[位置],b[float],c[属性],d[改变类型],e[float],f[属性],g[改变类型]
    [238] = function(role, args)
        local flr = args[1]
        local f1 = args[2]
        local pro1 = args[3]
        local ct1 = args[4]
        local f2 = args[5]
        local pro2 = args[6]
        local ct2 = args[7]

        if OutDataManager.GetOutData(role.camp, OutDataName.DaNaoTianGongFloor) == flr then
            BattleUtil.AddProp(role, pro1, f1, ct1)
            BattleUtil.AddProp(role, pro2, f2, ct2)
        end
    end,
    -- 猎妖之路专属
    -- 每有一件紫色品质以上的战利品，我方武将[d]改变[b]的[c]，[g改变[e]的[f]，最多[h]层
    -- b[float],c[属性],d[改变类型],e[float],f[属性],g[改变类型],h[int]
    [239] = function(role, args)
        local f1 = args[1]
        local pro1 = args[2]
        local ct1 = args[3]
        local f2 = args[4]
        local pro2 = args[5]
        local ct2 = args[6]
        local maxNum = args[7]

        -- 紫+橙
        local num = OutDataManager.GetOutData(role.camp, OutDataName.PerpleGloryItemNum) + OutDataManager.GetOutData(role.camp, OutDataName.OrangeGloryItemNum)
        num = min(maxNum, num)
        BattleUtil.AddProp(role, pro1, f1 * num, ct1)
        BattleUtil.AddProp(role, pro2, f2 * num, ct2)
    end,
    -- 猎妖之路专属
    -- 每使用一次神秘药水，我方武将[c]改变[a]的[b]，最多[d]层
    -- a[float],b[属性],c[改变类型],d[int]
    [240] = function(role, args)
        local f1 = args[1]
        local pro1 = args[2]
        local ct1 = args[3]
        local maxNum = args[4]

        -- 紫+橙
        local num = OutDataManager.GetOutData(role.camp, OutDataName.MisteryLiquidUsedTimes)
        
        num = min(maxNum, num)
        BattleUtil.AddProp(role, pro1, f1 * num, ct1)
    end,

    -- 每当友方英雄死亡时，自身[d]改变[b]的[c]，[g]改变[e]的[f]
    -- b[float],c[属性],d[改变类型],e[float],f[属性],g[改变类型]
    [241] = function(role, args)
        local f1 = args[1]
        local pro1 = args[2]
        local ct1 = args[3]
        local f2 = args[4]
        local pro2 = args[5]
        local ct2 = args[6]

        local function _OnRoleRealDead(deadRole)
            if role.camp == deadRole.camp then
                BattleUtil.AddProp(role, pro1, f1, ct1)
                BattleUtil.AddProp(role, pro2, f2, ct2)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.RoleRealDead, _OnRoleRealDead)
    end,

    --> 战斗开始时, 敌方所有人[a]属性[b]改变[c], 持续[d]回合
    [304] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local function _OnRoundChange(curRound)
            if curRound == 1 then
                local list = RoleManager.Query(function(r)
                    return r.camp ~= role.camp
                end)
                for _, r in ipairs(list) do
                    r:AddBuff(Buff.Create(role, BuffName.PropertyChange, _d, BattlePropList[_a], _c, _b))
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    --> 战斗开始时, 己方所有人[a]属性[b]改变[c], 持续[d]回合
    [327] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local function _OnRoundChange(curRound)
            if curRound == 1 then
                local list = RoleManager.Query(function(r)
                    return r.camp == role.camp
                end)
                for _, r in ipairs(list) do
                    r:AddBuff(Buff.Create(role, BuffName.PropertyChange, _d, BattlePropList[_a], _c, _b))
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    --> 每回合开始时, 若自己血量大于50%, 则自己[a]属性[b]改变[c], 反之则[d]属性[e]改变[f]
    [300] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local function _OnRoundChange(curRound)
            if role:GetRoleData(RoleDataName.Hp) > BattleUtil.ErrorCorrection(role:GetRoleData(RoleDataName.MaxHp) / 2) then
                BattleUtil.AddProp(role, _a, _c, _b)
            else
                BattleUtil.AddProp(role, _d, _f, _e)
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    --> 攻击时, 有[a]概率使[b]目标的[c]属性[d]改变[e], 持续[f]回合
    [324] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleUtil.RandomAction(_a, function()
                if skill and defRole:IsDead() then
                    if _b == 1 then
                        defRole:AddBuff(Buff.Create(role, BuffName.PropertyChange, _f, BattlePropList[_c], _e, _d))
                    elseif _b == 2 then
                        role:AddBuff(Buff.Create(role, BuffName.PropertyChange, _f, BattlePropList[_c], _e, _d))
                    elseif _b == 3 then
                        defRole:AddBuff(Buff.Create(role, BuffName.PropertyChange, _f, BattlePropList[_c], _e, _d))
                        role:AddBuff(Buff.Create(role, BuffName.PropertyChange, _f, BattlePropList[_c], _e, _d))
                    end
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 攻击时, 目标若有[a]控制状态, 则[b]目标[c]属性临时[d]改变[e]
    [305] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.Control, function(buff) return (buff.ctrlType == _a or _a == 0) end) then
                if _b == 1 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                elseif _b == 2 then
                    BattleUtil.AddProp(role, _c, _e, _d)
                elseif _b == 3 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                    BattleUtil.AddProp(role, _c, _e, _d)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 攻击时, 目标若有[a]属性状态, 则[b]目标[c]属性临时[d]改变[e]
    [307] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.PropertyChange, function(buff) return (buff.propertyChangeType == _a or _a == 0) end) then
                if _b == 1 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                elseif _b == 2 then
                    BattleUtil.AddProp(role, _c, _e, _d)
                elseif _b == 3 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                    BattleUtil.AddProp(role, _c, _e, _d)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    
    --> 攻击时, 技能目标被"冰封结界"冰冻概率变为[a]，每当目标被附加[c]控制状态或[d]属性状态时, 增加自己[e]和[f]属性[g]，持续[h]回合（可叠加10层），如果目标的[i]控制状态被解除, 会对全体敌方单位造成自己攻击力[j]的[k]伤害
    [308] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

    end,

    --> 攻击时, 若目标存在[a]或[b]持续伤害状态, 则[c]目标的[d]属性临时[e]改变[f]
    [309] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.DOT, function(buff) return (buff.damageType == _a or buff.damageType == _b) end) then
                if _c == 1 then
                    BattleUtil.AddProp(defRole, _d, _f, _e)
                elseif _c == 2 then
                    BattleUtil.AddProp(role, _d, _f, _e)
                elseif _c == 3 then
                    BattleUtil.AddProp(defRole, _d, _f, _e)
                    BattleUtil.AddProp(role, _d, _f, _e)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 攻击时, 有[a]概率为目标附加1个【标识】,最多[b]层，每个【标识】使自己的[c]属性[d]改变[e], [f]个及以上【标识】使携带者的[g]属性[h]改变[i]
    [320] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        local _g = args[7]
        local _h = args[8]
        local _i = args[9]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)

            BattleUtil.RandomAction(_a, function()
                local buf = nil
                if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.Brand, function(buff)
                        local b = buff.flag == "biaoshi320"
                        if b then
                            buf = buff
                        end
                        return b
                    end) 
                then
                    if buf.layer < _b then
                        buf.layer = buf.layer + 1
                        if buf.pro1Arr[buf.layer] == nil then
                            BattleUtil.AddProp(defRole, _c, _e, _d)
                            buf.pro1Arr[buf.layer] = 1
                        end
                        
                        if buf.layer >= _f then
                            for i = 1, buf.layer do
                                if buf.pro2Arr[i] == nil then
                                    BattleUtil.AddProp(defRole, _g, _i, _h)
                                    buf.pro2Arr[i] = 1
                                end
                            end
                        end
                    end
                else
                    local brand = Buff.Create(defRole, BuffName.Brand, 0, "biaoshi320")
                    brand.maxLayer = _b
                    brand.clear = false
                    brand.pro1Arr = {}
                    brand.pro2Arr = {}
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                    brand.pro1Arr[brand.layer] = 1
                    brand.endFunc = function ()
                        buf = nil
                    end
                    defRole:AddBuff(brand)
                end
                
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
        
    end,

    --> 攻击时, 若目标的生命大于等于[a], 则[b]目标的[c]属性临时[d]改变[e]
    [321] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            local hpPercent = BattleUtil.ErrorCorrection(defRole:GetRoleData(RoleDataName.Hp) / defRole:GetRoleData(RoleDataName.MaxHp))
            if hpPercent >= _a then
                if _b == 1 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                elseif _b == 2 then
                    BattleUtil.AddProp(role, _c, _e, _d)
                elseif _b == 3 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                    BattleUtil.AddProp(role, _c, _e, _d)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 攻击时, 若目标的生命小于[a], 则[b]目标的[c]属性临时[d]改变[e]
    [345] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            local hpPercent = BattleUtil.ErrorCorrection(defRole:GetRoleData(RoleDataName.Hp) / defRole:GetRoleData(RoleDataName.MaxHp))
            if hpPercent < _a then
                if _b == 1 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                elseif _b == 2 then
                    BattleUtil.AddProp(role, _c, _e, _d)
                elseif _b == 3 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                    BattleUtil.AddProp(role, _c, _e, _d)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 攻击时, 若目标的生命小于[a], 则[b]概率为[c]目标附加[d]属性状态, [e]改变[f], 持续[g]回合
    [322] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        local _g = args[7]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            local hpPercent = BattleUtil.ErrorCorrection(defRole:GetRoleData(RoleDataName.Hp) / defRole:GetRoleData(RoleDataName.MaxHp))
            if hpPercent < _a then
                BattleUtil.RandomAction(_b, function()
                    if skill and defRole:IsDead() then
                        if _c == 1 then
                            defRole:AddBuff(Buff.Create(role, BuffName.PropertyChange, _g, PropertyChangeTypeMap[_d], _f, _e, _d))
                        elseif _c == 2 then
                            role:AddBuff(Buff.Create(role, BuffName.PropertyChange, _g, PropertyChangeTypeMap[_d], _f, _e, _d))
                        elseif _c == 3 then
                            defRole:AddBuff(Buff.Create(role, BuffName.PropertyChange, _g, PropertyChangeTypeMap[_d], _f, _e, _d))
                            role:AddBuff(Buff.Create(role, BuffName.PropertyChange, _g, PropertyChangeTypeMap[_d], _f, _e, _d))
                        end
                    end
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 攻击时, 若目标的速度小于自己, 则[a]目标的[b]属性临时[c]改变[d]
    [326] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if defRole:GetRoleData(RoleDataName.Speed) < role:GetRoleData(RoleDataName.Speed) then
                if _a == 1 then
                    BattleUtil.AddProp(defRole, _b, _d, _c)
                elseif _a == 2 then
                    BattleUtil.AddProp(role, _b, _d, _c)
                elseif _a == 3 then
                    BattleUtil.AddProp(defRole, _b, _d, _c)
                    BattleUtil.AddProp(role, _b, _d, _c)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 攻击时, 若目标是[a]阵营, 则[b]目标的[c]属性临时[d]改变[e]
    [342] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if defRole.roleData.element == _a then
                if _b == 1 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                elseif _b == 2 then
                    BattleUtil.AddProp(role, _c, _e, _d)
                elseif _b == 3 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                    BattleUtil.AddProp(role, _c, _e, _d)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 攻击时, 有[a]概率清除任意己方单位的一个[b]清除状态, 并为其附加一层【魔种】, 最多[c]层, 每层魔种使携带者[d]属性[e]改变[f], 无法驱散一直存在 
    [349] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleUtil.RandomAction(_a, function()
                BattleLogic.BuffMgr:ClearBuff(target, function (buff)
                    return clearBuffPredicate(buff, _b)
                end)

                local buf = nil
                if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.Brand, function(buff)
                        local b = buff.flag == "mozhong349"
                        if b then
                            buf = buff
                        end
                        return b
                    end) 
                then
                    if buf.layer < _c then
                        buf.layer = buf.layer + 1
                        if buf.pro1Arr[buf.layer] == nil then
                            BattleUtil.AddProp(defRole, _d, _f, _e)
                            buf.pro1Arr[buf.layer] = 1
                        end
                    end
                else
                    local brand = Buff.Create(defRole, BuffName.Brand, 0, "mozhong349")
                    brand.maxLayer = _c
                    brand.clear = false
                    brand.pro1Arr = {}
                    BattleUtil.AddProp(defRole, _d, _f, _e)
                    brand.pro1Arr[brand.layer] = 1
                    brand.endFunc = function ()
                        buf = nil
                    end
                    defRole:AddBuff(brand)
                end
                
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 攻击后, 自己的[a]属性[b]改变[c]，可叠加，持续[d]回合
    [301] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            local buff = Buff.Create(role, BuffName.PropertyChange, _d, BattlePropList[_a], _c, _b)
            buff.cover = true
            buff.maxLayer = NormalMaxLayer
            defRole:AddBuff(buff)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 释放[a]号技能时, 有[b]概率使技能目标的[c]属性[d]改变[e], 可叠加, 持续[f]回合
    [306] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local OnSkillCast = function(skill)
            if skill.ext_slot == _a then
                BattleUtil.RandomAction(_b, function ()
                    local targets = skill:GetDirectTargets()
                    if not targets or #targets == 0 then return end

                    for _, target in ipairs(targets) do
                        local buff = Buff.Create(role, BuffName.PropertyChange, _f, BattlePropList[_c], _e, _d)
                        buff.cover = true
                        buff.maxLayer = NormalMaxLayer
                        target:AddBuff(buff)
                    end
                end)
            end
            
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)
    end,

    --> 释放[a]号技能时, 若目标是[b]阵营, 则[c]目标的[d]属性临时[e]改变[f]
    [310] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local OnSkillCast = function(skill)
            if skill.ext_slot == _a then

                local targets = skill:GetDirectTargets()
                if not targets or #targets == 0 then return end

                for _, target in ipairs(targets) do
                    if target.roleData.element == _b then
                        BattleUtil.AddProp(target, _d, _f, _e)
                    end
                end

            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)
    end,

    --> 释放[a]号技能时, 若目标是[b]阵营, 则有[c]概率为目标附加[d]控制状态,持续[e]回合
    [311] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local OnSkillCast = function(skill)
            if skill.ext_slot == _a then

                local targets = skill:GetDirectTargets()
                if not targets or #targets == 0 then return end

                for _, target in ipairs(targets) do
                    if target.roleData.element == _b then
                        BattleUtil.RandomControl(_c, _d, role, target, _e)
                    end
                end

            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)
    end,

    --> 释放[a]号技能时, 若击杀目标, 则[b]几率使目标无法复活
    [323] = function(role, args)
        local _a = args[1]
        local _b = args[2]

        local OnRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if defRole:IsDead() then
                BattleUtil.RandomAction(_b, function()
                    defRole:SetReliveFilter(false)
                end)
            end
        end

        local OnSkillCast = function(skill)
            if skill.ext_slot == _a then
                role.Event:AddEvent(BattleEventName.RoleHit, OnRoleHit)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)

        local OnSkillCastEnd = function(skill)
            if skill.ext_slot == _a then
                role.Event:RemoveEvent(BattleEventName.RoleHit, OnRoleHit)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --> 释放[a]号技能时, 有[b]概率对处目标外的随机[c]个敌方单位造成攻击[d]的[e]伤害
    [333] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local OnSkillCast = function(skill)
            if skill.ext_slot == _a then
                BattleUtil.RandomAction(_b, function()
                    local targets = skill:GetDirectTargets()
                    if not targets or #targets == 0 then return end

                    local list = RoleManager.Query(function(v) return role.camp ~= v.camp end)
                    local otherRole = {}

                    for index, value in ipairs(list) do
                        local isHave = false
                        for _, target in ipairs(targets) do
                            if value == target then
                                isHave = true
                            end
                        end
                        if not isHave then
                            table.insert(otherRole, value)
                        end
                    end
                    if #otherRole > 0 then
                        Random.RandomList(otherRole)
                        local num = math.min(_c, #otherRole)
                        for i = 1, num do
                            if otherRole[i] then
                                BattleUtil.ApplyDamage(nil, role, otherRole[i], floor(otherRole[i]:GetRoleData(RoleDataName.Attack) * _d))
                            end
                        end
                    end
                    
                end)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)

    end,

    --> 释放[a]号技能时, 有[b]概率使[c]目标附加[d]控制状态, , 持续[e]回合
    [334] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local OnSkillCast = function(skill)
            if skill.ext_slot == _a then
                local target1 = function()
                    BattleUtil.RandomAction(_b, function()
                        local targets = skill:GetDirectTargets()
                        if not targets or #targets == 0 then return end

                        for _, target in ipairs(targets) do
                            if target.roleData.element == _b then
                                BattleUtil.RandomControl(1, _d, role, target, _e)
                            end
                        end
                    end)
                end
                local target2 = function()
                    BattleUtil.RandomAction(_b, function()
                        BattleUtil.RandomControl(1, _d, role, role, _e)
                    end)
                end
                if _c == 1 then
                    target1()
                elseif _c == 2 then
                    target2()
                elseif _c == 3 then
                    target1()
                    target2()
                end
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)

    end,

    --> 受到攻击时, [a]概率触发【反击】,对攻击者造成攻击[b]的[c]型伤害
    [302] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]



    end,

    --> 受到攻击时, [a]概率为攻击者附加[b]持续伤害状态, 每回合减少相当于施法者[c]属性[d]的生命, 持续[e]回合
    [315] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
            BattleUtil.RandomAction(_a, function ()
                local hitblood = floor(role:GetRoleData(BattlePropList[_c]) * _d)
                local dot = Buff.Create(role, BuffName.DOT, _e, 1, _b, hitblood, 1)
                dot.isRealDamage = true
                atkRole:AddBuff(dot)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)

    end,

    --> 受到攻击时, 如果目标是[a]职业, 则[b]属性临时[c]改变[d]
    [303] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
            if atkRole.roleData.professionId == _a then
                BattleUtil.AddProp(role, _b, _d, _c)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)

    end,

    --> 受到攻击时, 增加[a]点怒气, 最多[b]点怒气
    [318] = function(role, args)
        local _a = args[1]
        local _b = args[2]

        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)

            local buf = nil
            if BattleLogic.BuffMgr:HasBuff(role, BuffName.Brand, function(buff)
                    local b = buff.flag == "nuqi318"
                    if b then
                        buf = buff
                    end
                    return b
                end) 
            then
                if buf.layer < _b then
                    buf.layer = buf.layer + _a
                end
            else
                local brand = Buff.Create(role, BuffName.Brand, 0, "nuqi318")
                brand.layer = _a
                brand.maxLayer = _b

                brand.endFunc = function ()
                    buf = nil
                end
                role:AddBuff(brand)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)

    end,

    --> 受到攻击时, 伤害不会超过自己[a]属性的[b]
    [331] = function(role, args)
        local _a = args[1]
        local _b = args[2]

        local function onFinalBeDamage(damagingFunc, atkRole, damage, skill, dotType, bCrit, damageType)
            local maxDamage = floor(role:GetRoleData(BattlePropList[_a]) * _b)
            if damage > maxDamage then
                -- 计算免除的伤害值
                local md = damage - maxDamage
                if damagingFunc then damagingFunc(md) end
            end

        end
        role.Event:AddEvent(BattleEventName.FinalBeDamage, onFinalBeDamage)

    end,

    --> 受到攻击时, 有[a]概率给攻击者附加【诅咒】, 在[b]回合后给攻击者造成受击者[c]属性[d]的伤害, 诅咒可同时存在多个
    [346] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
            BattleUtil.RandomAction(_a, function()
                local auraBuff = Buff.Create(role, BuffName.Aura, _b, function (target)
                    BattleUtil.ApplyDamage(nil, role, atkRole, floor(role:GetRoleData(BattlePropList[_c]) * _d))
                end)
                auraBuff.interval = _b
                atkRole:AddBuff(auraBuff)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)

    end,

    --> 普通攻击时, 有[a]概率为[b]目标附加[c]属性状态, [d]改变[e], 持续[f]回合
    [330] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local OnRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if skill.ext_slot == 0 then
                if not defRole:IsDead() then
                    BattleUtil.RandomAction(_a, function()
                        defRole:AddBuff(Buff.Create(role, BuffName.PropertyChange, _f, PropertyChangeTypeMap[_c], _e, _d, _c))
                    end)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, OnRoleHit)

    end,

    --> 普通攻击时, 为己方生命最低的单位恢复相当于自身[a]属性[b]的生命
    [329] = function(role, args)
        local _a = args[1]
        local _b = args[2]

        local OnRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if skill.ext_slot == 0 then
                local list = RoleManager.Query(function(v) return role.camp == v.camp end)
                
                if list and #list > 0 then
                    local livemin = nil
                    local minhp = 100000000
                    for _, r in pairs(list) do
                        local hp = r:GetRoleData(RoleDataName.Hp)
                        if hp < minhp then
                            minhp = hp
                            livemin = r
                        end
                    end

                    local hp = floor(role:GetRoleData(BattlePropList[_a]) * _b)
                    if livemin then
                        BattleUtil.ApplyTreat(role, livemin, hp)
                    end
                end
            end
            
            
        end
        role.Event:AddEvent(BattleEventName.RoleHit, OnRoleHit)

    end,

    --> 普通攻击时, 有[a]概率给目标附加【诅咒】, 在[b]回合后给携带者造成施法者[c]属性[d]的伤害, 诅咒可同时存在多个
    [344] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local OnRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if skill.ext_slot == 0 then
                BattleUtil.RandomAction(_a, function()
                    local auraBuff = Buff.Create(role, BuffName.Aura, _b, function (target)
                        local hurthp = floor(role:GetRoleData(BattlePropList[_c]) * _d)
                        local onDamage = function(changefactor)
                            hurthp = hurthp - changefactor
                        end
                        role.Event:DispatchEvent(BattleEventName.BuffAuraTrigger, onDamage, skill)
                        BattleUtil.ApplyDamage(nil, role, defRole, hurthp)
                    end)
                    auraBuff.interval = _b
                    defRole:AddBuff(auraBuff)
                end)
            end
            
        end
        role.Event:AddEvent(BattleEventName.RoleHit, OnRoleHit)

    end,

    --> 自己死亡时, 为己方所有单位恢复相当于自身[a]属性[b]的生命, 只能触发[c]次
    [328] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        local OnDead = nil
        local cnt = 0
        OnDead = function(atkRole)
            local list = RoleManager.Query(function(v) return role.camp == v.camp end)
            for i=1, #list do
                local val = floor(BattleUtil.FP_Mul(_b, role:GetRoleData(BattlePropList[_a])))
                BattleUtil.CalTreat(role, list[i], val)
            end
            cnt = cnt + 1
            if cnt >= _c then
                role.Event:RemoveEvent(BattleEventName.RoleDead, OnDead)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDead, OnDead)

    end,

    --> 自己死亡时, 立即复活，并恢复[a]属性[b]的生命，[c]属性[d]改变[e]，持续[f]回合
    [314] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]


        local counter = 0
        local onRoleRealDead = function(deadRole)
            counter = counter + 1
            if counter == 1 then
                deadRole:SetRelive(BattleUtil.FP_Mul(role:GetRoleData(BattlePropList[_a]), _b))
                deadRole:AddBuff(Buff.Create(role, BuffName.PropertyChange, _f, BattlePropList[_c], _e, _d))
            end
        end
        role.Event:AddEvent(BattleEventName.RoleRealDead, onRoleRealDead)

    end,

    --> 己方单位暴击时, 为己方全体单位恢复伤害量[a]的生命
    [313] = function(role, args)
        local _a = args[1]

        local list = RoleManager.Query(function(v) return role.camp == v.camp end)

        local onRoleBeCrit = function(atkRole, damage, bCrit, finalDmg, damageType, skill)
            local list2 = RoleManager.Query(function(v) return role.camp == v.camp end)
            local val = floor(BattleUtil.FP_Mul(damage, _a))
            for i=1, #list2 do
                BattleUtil.CalTreat(role, list2[i], val)
            end 
        end
        for i=1, #list do
            list[i].Event:AddEvent(BattleEventName.RoleBeCrit, onRoleBeCrit)
        end
    end,

    --> 己方单位暴击时, 为己方全体单位附加吸收盾, 吸收量为伤害量的[a], 持续[b]回合
    [348] = function(role, args)
        local _a = args[1]
        local _b = args[2]

        local list = RoleManager.Query(function(v) return role.camp == v.camp end)

        local onRoleBeCrit = function(atkRole, damage, bCrit, finalDmg, damageType, skill)
            local list2 = RoleManager.Query(function(v) return role.camp == v.camp end)
            local val = floor(BattleUtil.FP_Mul(damage, _a))
            for i=1, #list2 do
                list2[i]:AddBuff(Buff.Create(role, BuffName.Shield, _b, ShieldTypeName.NormalReduce, val, 0))
            end 
        end
        for i=1, #list do
            list[i].Event:AddEvent(BattleEventName.RoleBeCrit, onRoleBeCrit)
        end
    end,

    --> 击杀目标时, 若目标是[a]阵营, 则自身恢复伤害量[b]的生命
    [316] = function(role, args)
        local _a = args[1]
        local _b = args[2]

        local OnKill = function(defRole, damage)
            if defRole.roleData.element == _a then
                BattleUtil.CalTreat(role, role, floor(BattleUtil.FP_Mul(damage, _b)))
            end
        end
        role.Event:AddEvent(BattleEventName.RoleKill, OnKill)
    end,

    --> 改变【普通攻击】, 使其优先选择处于[a]或[b]持续伤害状态的目标
    [312] = function(role, args)
        local _a = args[1]
        local _b = args[2]

        local function onSkillTargetCheck(func, skill)
            
            if skill.ext_slot == 0 then
                if skill.effectTargets and skill.effectTargets[1] then
                    local list = RoleManager.Query(function(r)
                        return r.camp ~= role.camp
                    end)

                    local num = #skill.effectTargets[1]
                    BattleUtil.Sort(list, function(a, b)
                        local aHave = BattleLogic.BuffMgr:HasBuff(a, BuffName.DOT, function (buff) return buff.damageType == _a or buff.damageType == _b end)
                        local bHave = BattleLogic.BuffMgr:HasBuff(b, BuffName.DOT, function (buff) return buff.damageType == _a or buff.damageType == _b end)
                        if aHave and bHave then
                            return false
                        elseif not aHave and bHave then
                            return false
                        elseif aHave and not bHave then
                            return true
                        end
                        return false
                    end)

                    local trans = {}
                    for i = 1, num do
                        if list[i] then
                            table.insert(trans, list[i])
                        end
                    end
                    
                    if trans and #trans > 0 then 
                        if func then func(trans) end
                    end
                end
                
            end
            
        end
        role.Event:AddEvent(BattleEventName.SkillTargetCheck, onSkillTargetCheck)
    end,

    --> 改变[a]号技能, 使其附加的【诅咒】的伤害增加[b]
    [343] = function(role, args)
        local _a = args[1]
        local _b = args[2]

        local damageFun = function(onDamage, skill)
            if onDamage and skill then
                if skill.ext_slot == _a then
                    onDamage(-_b)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.BuffAuraTrigger, damageFun)
    end,

    --> 光环, 使所有己方[a]阵营单位的[b]属性[c]改变[d]
    [338] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local arr = RoleManager.Query(function (r) return r.camp == role.camp end)
        for k, v in ipairs(arr) do
            if v.roleData.element == _a then
                BattleUtil.AddProp(v, _b, _d, _c)
            end
        end
    end,

    --> 光环, 提高己方所有单位的【反击】伤害, 增加相当于自己[a]属性的[b]
    [339] = function(role, args)
        local _a = args[1]
        local _b = args[2]

        
    end,

    --> 光环, 若敌方单位死亡时有[a]属性状态, 则恢复己方所有单位相当于自己[b]属性[c]的生命
    [341] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        local arr = RoleManager.Query(function (r) return r.camp ~= role.camp end)
        for k, v in ipairs(arr) do
            local OnDead = function(atkRole)
                if BattleLogic.BuffMgr:HasBuff(v, BuffName.PropertyChange, function (buff) return buff.propertyChangeType == _a end) then
                    local arr2 = RoleManager.Query(function (r2) return r2.camp == role.camp end)
                    for index, value in ipairs(arr2) do
                        local val = floor(BattleUtil.FP_Mul(_c, role:GetRoleData(BattlePropList[_b])))
                        BattleUtil.CalTreat(role, value, val)
                    end
                end
            end
            role.Event:AddEvent(BattleEventName.RoleDead, OnDead)
        end
    end,

    --> 光环, 有单位死亡, 自己获得1层【魔界之力】, 每层使自己[a]属性[b]改变[c], 无法驱散, 持续到本回合结束( 同1武将1回合内多次死亡只算1次; 自己死亡后不清除魔界之力)
    [347] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]


    end,

    --> 光环, 使所有敌方单位附加[a]或[b]持续伤害状态的概率提升[c], 且提升持续伤害效果, 相当于自己[d]属性的[e]
    [317] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]


    end,
    

    
}
return passivityList   