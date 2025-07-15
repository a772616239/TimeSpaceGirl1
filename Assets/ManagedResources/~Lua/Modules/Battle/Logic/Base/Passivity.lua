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

local function Slot2Idx(slot)
    if slot == 0 then
        return 1
    elseif slot == 1 then
        return 2
    elseif slot == 3 then
        return 3
    end
end

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
        or (buff.type ==BuffName.Brand and buff.flag == BrandType.curse)
    end
    if flag == nil then 
        flag = false
    end
    local sign="false"
    if flag then sign = "true" end
    BattleLogManager.Log(
        "clearBuffPredicate:"..buff.type.." caltype:"..type,
        "flag:", sign
    )
    if buff.type ==BuffName.Brand then
        BattleLogManager.Log(
            "clearBuffPredicate: Brand "..buff.type,
            "buff.flag :", buff.flag 
        )
    end
    return flag
end

-- 规范技能目标 1 对方 2 自己 3对方自己
local function EffectTargetFunc(_target,targetFunc,enemyFunc,args,defaltfunc)
    if _target==1 then
        if enemyFunc then  enemyFunc(args) end
    elseif _target==2 then
        if targetFunc then targetFunc(args) end
    elseif _target==3 then
        if enemyFunc then  enemyFunc(args) end
        if targetFunc then  targetFunc(args) end
    else
        if defaltfunc then  defaltfunc(args) end
    end
    return _target==1 or _target==2 or _target==3
end


--被动技能表
local passivityList
passivityList = {
    --对血量低于[a]的敌人伤害提高[b]。
    --a[float],b[float]
    [29] = function(role, args, delay)
        local f1 = args[1]
        local f2 = args[2]

        local OnPassiveDamaging = function(damagingFunc, defRole, damage)
            BattleLogic.WaitForTrigger(delay, function ()
                if BattleUtil.GetHPPencent(defRole) < f1 then
                    damagingFunc(-floor(f2 * damage))
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
    end,

    -- [a]增加[b], [c]改变
    -- a[属性]b[float]
    [90] = function(role, args, delay)
        local pro = args[1]
        local f1 = args[2]
        local ct = args[3]
        role.data:CountValue(BattlePropList[pro], f1, ct)
    end,
    
    -- 技能伤害增加[a]%，[b]改变
    -- a[float]b[改变类型]
    [91] = function(role, args, delay)
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
    [92] = function(role, args, delay)
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
    [93] = function(role, args, delay)
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
    [94] = function(role, args, delay)
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
    [95] = function(role, args, delay)
        local i1 = args[1]
        -- 行动结束后
        local onTurnEnd = function()
            role:AddRage(i1, CountTypeName.Add)
        end
        role.Event:AddEvent(BattleEventName.RoleTurnEnd, onTurnEnd)
    end,

    -- 普攻伤害增加[a]%[b]改变
    -- a[float]b[改变类型]
    [96] = function(role, args, delay)
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
    [97] = function(role, args, delay)
        local f1 = args[1]
        local f2 = args[2]
        local dt = args[3]
        -- 释放技能后
        local onSkillEnd = function(skill)
            BattleLogic.WaitForTrigger(delay, function ()
                if skill and skill.type == BattleSkillType.Special then
                    BattleUtil.RandomAction2(f1, function()
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
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)
    end,

    -- 释放技能[a]概率不消耗怒气
    -- a[float]
    [98] = function(role, args, delay)
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
    [99] = function(role, args, delay)
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

    -- 释放技能技能[a]概率[b]改变[c]%
    -- a[控制状态]b[改变类型]c[float]
    [101] = function(role, args, delay)
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
    [102] = function(role, args, delay)
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
    [103] = function(role, args, delay)
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
    [104] = function(role, args, delay)
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
    [105] = function(role, args, delay)
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
    [106] = function(role, args, delay)
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
    [107] = function(role, args, delay)
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
    [108] = function(role, args, delay)
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
    [109] = function(role, args, delay)
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
    [110] = function(role, args, delay)
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
    [111] = function(role, args, delay)
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
    [112] = function(role, args, delay)
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
    [113] = function(role, args, delay)
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
    [114] = function(role, args, delay)
        local i1 = args[1]
        -- 释放技能后
        local onRoleHit = function(target)
            
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
    [115] = function(role, args, delay)
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
    [116] = function(role, args, delay)
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
    [117] = function(role, args, delay)
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
    [118] = function(role, args, delay)
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
    [119] = function(role, args, delay)
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
    [120] = function(role, args, delay)
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
    [121] = function(role, args, delay)
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
    [122] = function(role, args, delay)
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
    [123] = function(role, args, delay)
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
    [124] = function(role, args, delay)
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
    [125] = function(role, args, delay)
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
    [126] = function(role, args, delay)
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
    [128] = function(role, args, delay)
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
    [130] = function(role, args, delay)
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
    [131] = function(role, args, delay)
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
    [132] = function(role, args, delay)
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
    [133] = function(role, args, delay)
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
    [134] = function(role, args, delay)
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
    [135] = function(role, args, delay)
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
    [136] = function(role, args, delay)
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
    [137] = function(role, args, delay)
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
    [138] = function(role, args, delay)
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

    -- 受到[a]状态敌人攻击时受到伤害[b]改变[c]%
    -- a[持续伤害状态]b[改变类型]c[float]
    [140] = function(role, args, delay)
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
    [141] = function(role, args, delay)
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
    [142] = function(role, args, delay)
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
    [143] = function(role, args, delay)
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
    [144] = function(role, args, delay)
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
    [145] = function(role, args, delay)
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
    [146] = function(role, args, delay)
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
    [147] = function(role, args, delay)
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
    [148] = function(role, args, delay)
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
    [149] = function(role, args, delay)
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
    [150] = function(role, args, delay)
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
    [151] = function(role, args, delay)
        local dot = args[1]
        local f1 = args[2]
        local f2 = args[3]
        -- 
        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                if skill and skill.type == BattleSkillType.Normal and not defRole:IsDead() then
                    if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.DOT, function (buff) return dot == 0 or buff.damageType == dot end) then
                        -- 检测被动技能对秒杀参数得影响
                        local bf, kf = BattleUtil.CheckSeckill(f1, f2, role, defRole)
                        --
                        local ft = defRole:GetRoleData(RoleDataName.Hp)/defRole:GetRoleData(RoleDataName.MaxHp)
                        if ft < bf then
                            BattleUtil.RandomAction2(kf, function()
                                -- 秒杀
                                BattleUtil.Seckill(skill, role, defRole)
                            end)
                        end
                    end
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    -- 释放技能有[a]%概率附加[b]效果持续[c]回合
    -- a[float]b[控制状态]c[int]
    [152] = function(role, args, delay)
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
    [153] = function(role, args, delay)
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
    [154] = function(role, args, delay)
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
    [155] = function(role, args, delay)
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
    [156] = function(role, args, delay)
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
    [157] = function(role, args, delay)
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
    [158] = function(role, args, delay)
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
    [159] = function(role, args, delay)
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
    [160] = function(role, args, delay)
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
    [161] = function(role, args, delay)
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
    [162] = function(role, args, delay)
        local f1 = args[1]
        local onCurse_ShareDamage = function(func)
            if func then func(f1, CountTypeName.Add) end
        end
        role.Event:AddEvent(BattleEventName.Curse_ShareDamage, onCurse_ShareDamage)
    end,

    -- 每当对方拥有链接符的目标死亡时，都会使己方输出型武将技能伤害提高[a]%（[b]元素输出武将提高[c]%)
    -- a[float]b[元素]c[float]
    [163] = function(role, args, delay)
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
    [164] = function(role, args, delay)
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
    [165] = function(role, args, delay)
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
    [166] = function(role, args, delay)
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

    -- 释放技能后给当前血量最少的2名队友附加无敌吸血盾持续[a]回合
    -- a[int]
    [168] = function(role, args, delay)
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
    [169] = function(role, args, delay)
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
    [170] = function(role, args, delay)
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
    [172] = function(role, args, delay)
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
    [173] = function(role, args, delay)
        local f1 = args[1]
        local ct = args[2]
        local onPassiveRebackDamage = function(func)
            if func then func(f1, ct) end
        end
        role.Event:AddEvent(BattleEventName.PassiveRebackDamage, onPassiveRebackDamage)
    end,

    -- 技能直接伤害治疗生命最少队友治疗量提升[a]%，[b]改变
    -- a[float]b[改变类型]
    [174] = function(role, args, delay)
        local f1 = args[1]
        local ct = args[2]
        
        local onPassiveSkillDamageHeal = function(func)
            if func then func(f1, ct) end
        end
        role.Event:AddEvent(BattleEventName.PassiveSkillDamageHeal, onPassiveSkillDamageHeal)
    end,

    -- 释放技能时，对己方生命最少武将治疗效果额外提升[a]，[b]改变
    -- a[float]b[改变类型]
    [175] = function(role, args, delay)
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
    [176] = function(role, args, delay)
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
    [177] = function(role, args, delay)
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
    [178] = function(role, args, delay)
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
    [179] = function(role, args, delay)
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
    [180] = function(role, args, delay)
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
    [181] = function(role, args, delay)
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
    [182] = function(role, args, delay)
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
    [183] = function(role, args, delay)
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
    [184] = function(role, args, delay)
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
    [185] = function(role, args, delay)
        local f1 = args[1]

        local onRoleHit = function(target)
            if target:IsDead() and BattleUtil.CheckIsNoDead(target) then
                local target = RoleManager.GetAliveAggro(role)
                BattleUtil.CalDamage(nil, role, target, 1, f1)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    -- 攻击纵排目标时额外降低目标[a]点怒气
    -- a[int]
    [186] = function(role, args, delay)
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
    [187] = function(role, args, delay)
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
    [188] = function(role, args, delay)
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
    [189] = function(role, args, delay)
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
    [190] = function(role, args, delay)
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
    [191] = function(role, args, delay)
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
    [192] = function(role, args, delay)
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
    [193] = function(role, args, delay)
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
    [194] = function(role, args, delay)
        local f1 = args[1]

        local OnRoleDamageBefore = function(defRole, factorFunc, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                local targets = skill:GetDirectTargets()
                if not targets or #targets == 0 then return end
                local cf = f1/#targets
                for _, target in ipairs(targets) do
                    BattleUtil.RandomAction2(cf, function()
                        BattleLogic.BuffMgr:ClearBuff(target, function(buff)
                            return buff.type == BuffName.Shield and buff.shieldType == ShieldTypeName.AllReduce
                        end)
                    end)
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, OnRoleDamageBefore)
    end,

    -- 首回合免疫[a]效果
    -- a[控制状态]
    [195] = function(role, args, delay)
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
    [196] = function(role, args, delay)
        local f1 = args[1]
        local onDamageBeShare = function(func)
            if func then func(f1, CountTypeName.Sub) end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamageBeShare, onDamageBeShare)
    end,
    
    -- 技能直接击杀敌方目标时有[a]%概率获得目标剩余所有怒气（输出武将佩戴）
    -- a[float]
    [197] = function(role, args, delay)
        local f1 = args[1]
        local onRoleHit = function(target, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                if skill and skill.type == BattleSkillType.Special and target:IsDead() and BattleUtil.CheckIsNoDead(target) then
                    BattleUtil.RandomAction2(f1, function()
                        role:AddRage(target.Rage, CountTypeName.Add)
                    end)
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    -- 受到的[a]效果伤害降低[b]%(与减伤盾原理相同）[c]改变
    -- a[持续伤害状态]b[float]c[改变类型]
    [198] = function(role, args, delay)
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
    [199] = function(role, args, delay)
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
    [200] = function(role, args, delay)
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
    [201] = function(role, args, delay)
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
    [202] = function(role, args, delay)
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
            BattleLogic.WaitForTrigger(delay, function ()
                if target:IsDead() then
                    if not BattleLogic.BuffMgr:HasBuff(role, BuffName.DOT, function (buff) return buff.damageType == dot or dot == 0 end) then
                        BattleUtil.RandomAction2(f2, function()
                            target:SetReliveFilter(false)
                        end)
                    end
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)



        -- 秒杀概率无法复活
        local function onSecKill(target)
                BattleUtil.RandomAction2(f3, function()
                    target:SetReliveFilter(false)
                end)
        end
        role.Event:AddEvent(BattleEventName.Seckill, onSecKill)

    end,

    -- 初始怒气增加[a]点敌方处于连接符状态的目标在回合结束时有[b]概率减少[c]点怒气
    -- a[int]b[int]
    [203] = function(role, args, delay)
        local i1 = args[1]
        local f1 = args[2]
        local i2 = args[3]
        -- 初始怒气增加
        role:AddRage(i1, CountTypeName.Add)

        -- 死亡数量
        local onRoleTurnEnd = function(target)
            BattleLogic.WaitForTrigger(delay, function ()
                if not target:IsDead() and BattleLogic.BuffMgr:HasBuff(target, BuffName.Curse, function(buff) return buff.curseType == CurseTypeName.ShareDamage end) then
                    BattleUtil.RandomAction2(f1, function()
                        target:AddRage(i2, CountTypeName.Sub)
                    end)
                end
            end)
        end
        BattleLogic.Event:AddEvent(BattleEventName.RoleTurnEnd, onRoleTurnEnd)

    end,

    -- 敌方处于连接符状态的目标在获得无敌盾时有[a]%概率获取失败
    -- a[float]
    [204] = function(role, args, delay)
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
    [205] = function(role, args, delay)
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
    [206] = function(role, args, delay)
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
    [207] = function(role, args, delay)
        
        local f1 = args[1]
        local f2 = args[2]
        local dt = args[3]
        -- 释放技能后
        local onSkillEnd = function(skill)
            BattleLogic.WaitForTrigger(delay, function ()
                if skill.type == BattleSkillType.Special then
                    BattleUtil.RandomAction2(f1, function()
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
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCastEnd, onSkillEnd)

    end,

    -- 如果自身是[a],则[d]改变[b]的[c]，[g改变[e]的[f]
    -- a[位置],b[float],c[属性],d[改变类型],e[float],f[属性],g[改变类型]
    [208] = function(role, args, delay)
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
    [209] = function(role, args, delay)
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
    [210] = function(role, args, delay)
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
    [211] = function(role, args, delay)
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
    [212] = function(role, args, delay)
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
    [213] = function(role, args, delay)
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
    [214] = function(role, args, delay)
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
    [215] = function(role, args, delay)
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
    [216] = function(role, args, delay)
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
    [217] = function(role, args, delay)
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
    [219] = function(role, args, delay)
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
    [220] = function(role, args, delay)
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
    [221] = function(role, args, delay)
        local rand = args[1]
        local f1 = args[2]
        local pro = args[3]

        role:AddBuff(Buff.Create(role, BuffName.Brand, 0, "YUAN"))  -- 鸳
        -- 
        local function _OnRoleHit(target)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(rand, function()
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
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, _OnRoleHit)

    end,


    -- 我方武将造成伤害时，[a]概率降低目标[b]%的[c]。若同时拥有效果221，则降低的属性加给伤害者。
    -- a[float],b[float],c[属性]
    [222] = function(role, args, delay)
        local rand = args[1]
        local f1 = args[2]
        local pro = args[3]

        role:AddBuff(Buff.Create(role, BuffName.Brand, 0, "YANG")) -- 鸯
        -- 
        local function _OnRoleHit(target)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(rand, function()
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
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, _OnRoleHit)


    end,




    -- 普攻时，[a]概率附加[b]效果，每回合造成攻击[c]%的伤害，持续[d]秒。
    -- a[float],b[持续伤害效果],c[float],d[int]
    [223] = function(role, args, delay)
        local rand = args[1]
        local dot = args[2]
        local f1 = args[3]
        local i1 = args[3]
        
        local function _OnRoleHit(target, damage, _, finalDmg, _, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                -- BattleUtil.RandomDot(rand, dot, role, target, i1, 1, )
                if skill and skill.type == BattleSkillType.Normal then
                    BattleUtil.RandomAction2(rand, function()
                        target:AddBuff(Buff.Create(role, BuffName.DOT, i1, 1, dot, 2, f1))
                    end)
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, _OnRoleHit)
    end,

    -- 我方武将造成伤害时，[a]概率附加攻击[b]%的真伤。
    -- a[float],b[float]
    [224] = function(role, args, delay)
        local rand = args[1]
        local f1 = args[2]

        local function _OnRoleHit(target)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(rand, function()
                    -- local dd = floor(BattleUtil.ErrorCorrection(role:GetRoleData(RoleDataName.Attack)*f1))
                    BattleUtil.CalDamage(nil, role, target, 1, f1, 1)
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, _OnRoleHit)
    end,

    -- 
    [225] = function(role, args, delay)
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
    [226] = function(role, args, delay)
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
    [227] = function(role, args, delay)
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
    [228] = function(role, args, delay)
        local f1 = args[1]

        local OnPassiveDamaging = function(damagingFunc, target, damage)
            damagingFunc(-floor(BattleUtil.FP_Mul(f1, damage, BattleUtil.GetHPPencent(target))))
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
    end,

    -- 自己血量越低，造成伤害越高，最多[a]%
    -- a[float]
    [229] = function(role, args, delay)
        local f1 = args[1]

        local OnPassiveDamaging = function(damagingFunc, target, damage)
            damagingFunc(-floor(BattleUtil.FP_Mul(f1, damage, 1 - BattleUtil.GetHPPencent(role))))
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
    end,





    -- 同阵营只生效一次
    -- 敌方武将[c]改变[a]的[b]
    -- a[float],b[属性],c[改变类型]
    [230] = function(role, args, delay)
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
    [231] = function(role, args, delay)
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
    [232] = function(role, args, delay)
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
    [233] = function(role, args, delay)
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
    [234] = function(role, args, delay)
        local ele = args[1]
        local f1 = args[2]
        local i1 = args[3]

        local function _OnRoundChange(curRound)
            BattleLogic.WaitForTrigger(delay, function ()
                if role.element == ele then
                    BattleUtil.RandomAction2(f1, function()
                        role:AddRage(i1, CountTypeName.Add)
                    end)
                end
            end)
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    -- 我方每有一个[a]武将，自身[d]改变[b]的[c]，可叠加（第一回合开始时生效）
    -- a[元素],b[float],c[属性],d[改变类型]
    [235] = function(role, args, delay)
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
    [237] = function(role, args, delay)
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
    [238] = function(role, args, delay)
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
    [239] = function(role, args, delay)
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
    [240] = function(role, args, delay)
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
    [241] = function(role, args, delay)
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
    [304] = function(role, args, delay)
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
                    local buff = Buff.Create(role, BuffName.PropertyChange, _d, BattlePropList[_a], _c, _b)
                    r:AddBuff(buff)
                    buff.clear =false
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    --> 战斗开始时, 己方所有人[a]属性[b]改变[c], 持续[d]回合
    [327] = function(role, args, delay)
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
    [300] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        

        local ishighOnPer = true
        local isFirstChange = true

        local function _OnRoundChange(curRound)      
            if not isFirstChange then 
                if ishighOnPer then
                    BattleUtil.RevertProp(role, _a, _c, _b)
                else
                    BattleUtil.RevertProp(role, _d, _f, _e)
                end
            end
            
            if role:GetRoleData(RoleDataName.Hp) > BattleUtil.ErrorCorrection(role:GetRoleData(RoleDataName.MaxHp) / 2) then
                BattleUtil.AddProp(role, _a, _c, _b)
                ishighOnPer = true
                
            else
                BattleUtil.AddProp(role, _d, _f, _e)
                ishighOnPer = false
            end

            isFirstChange = false
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    --> 攻击时, 有[a]概率使[b]目标的[c]属性[d]改变[e], 持续[f]回合
    [324] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local isCover = true
        local coverLayer = 1
       --RoleManager.LogArgs("324",args)
        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function()
                    if skill and not defRole:IsDead() then
                        local buff = Buff.Create(role, BuffName.PropertyChange, _f, _c, _e, _d)
                        local dfbuff = Buff.Create(defRole, BuffName.PropertyChange, _f, _c, _e, _d)
                        buff.cover = isCover -- 非叠加buff
                        dfbuff.cover = isCover -- 非叠加buff

                        buff.maxLayer = coverLayer-- 叠加层数
                        dfbuff.maxLayer = coverLayer -- 叠加层数
                        if _b == 1 then                       
                            defRole:AddBuff(dfbuff)
                            -- dfbuff:OnTrigger()
                        elseif _b == 2 then
                            role:AddBuff(buff)
                        elseif _b == 3 then                                           
                            defRole:AddBuff(dfbuff)
                            role:AddBuff(buff)
                            -- dfbuff:OnTrigger()
                        else
                            dfbuff.disperse = true
                            buff.disperse = true
                        end
                        -- buff:OnTrigger()
                    end
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 攻击时, 目标若有[a]控制状态, 则[b]目标[c]属性临时[d]改变[e]
    [305] = function(role, args, delay)
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
    [307] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
    
        -- RoleManager.LogArgs("307",args)

        local isAdd = false
        local _defRole = nil
        local _defRoles = {}
        local onRoleHit = function(defRole, damageType, f, skill)
            if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.PropertyChange, function(buff) return (buff.propertyChangeType == _a or _a == 0) end) then
                if _b == 1 then
                    BattleUtil.AddProp(defRole, _c, _e, _d) 
                    table.insert(_defRoles, defRole)
                elseif _b == 2 then
                    BattleUtil.AddProp(role, _c, _e, _d)
                    _defRole = defRole
                elseif _b == 3 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                    BattleUtil.AddProp(role, _c, _e, _d)
                    _defRole = defRole
                end               
                isAdd =true
                
            end


        end
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, onRoleHit)

        local RoleDamageAfter = function(SkillRole)
             if isAdd then
                --RoleManager.LogCa("revert 307")
                if _b == 1 then
                    if #_defRoles > 0 then
                        for i = 1, #_defRoles do
                            if not _defRoles[i]:IsRealDead() then
                                BattleUtil.RevertProp(_defRoles[i], _c, _e, _d) 
                            end
                        end
                        _defRoles = nil
                        _defRoles = {}
                        isAdd=false
                    end                
                elseif _b == 2 then
                    BattleUtil.RevertProp(role, _c, _e, _d)
                    isAdd=false
                elseif _b == 3 then
                    if _defRole ~=nil and not _defRole:IsRealDead() then
                        BattleUtil.RevertProp(_defRole, _c, _e, _d)
                        isAdd=false
                    end
                    BattleUtil.RevertProp(role, _c, _e, _d)
                    isAdd=false
                end
               
             end
        end
        role.Event:AddEvent(BattleEventName.RoleTurnEnd, RoleDamageAfter)
    end,

    
    --> new 攻击时, 技能目标被"冰封结界"冰冻概率变为[a]，每当目标被附加[b]控制状态或[c]属性状态时, 增加自己[d]和[e]属性[f]，持续[g]回合（可叠加10层），
    --> new 如果目标的[h]控制状态被解除, 会对全体敌方单位造成自己攻击力[i]的[j]伤害
    [308] = function(role, args, delay)
        -- local _a = args[1]   0.1
        -- local _b = args[2]   8
        -- local _c = args[3]   1
        -- local _d = args[4]   22
        -- local _e = args[5]   9
        -- local _f = args[6]   0.03
        -- local _g = args[7]   2
        -- local _h = args[8]   8 --
        -- local _i = args[9]   0.2
        -- local _j = args[10]  2
        -- local _k = args[11]
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        local _g = args[7]
        local _h = args[8]
        local _i = args[9]
        local _j = args[10]
        local _k = args[11]
        --> 提高敌方被冰冻概率10%（该效果不可驱散），
        --> 敌方武将每被冰冻或减速一次提高自身攻击和暴击10.2%，可叠加持续2回合（上限10层），
        --> 如果打碎敌方的冰冻效果会对全体敌方武将造成孙权攻击20%的伤害

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)           
            -- local onBuffEnd = function(buff)
            --     if buff.type == BuffName.Control and buff.ctrlType == _i then
            --         local list = RoleManager.Query(function(v) return role.camp ~= v.camp end)
            --         local damage = BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.Attack), _j)
            --         for k, v in ipairs(list) do
            --             BattleUtil.ApplyDamage(nil, role, v, damage)
            --         end
            --     end
            -- end
            -- defRole.Event:AddEvent(BattleEventName.BuffEnd, onBuffEnd)
            
            -- LogError("control attack："..defRole.roleId)
            if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.Control, function(buff) return buff.ctrlType == ControlType.Frozen end) then
                local bufflist = BattleLogic.BuffMgr:GetBuff(defRole, function(buff)
                    return buff.type == BuffName.Control and buff.ctrlType == ControlType.Frozen
                end)
                local frozenBuff = bufflist[1]
                --> 共3次击碎
                if frozenBuff.frozen_beHitTimes == 2 then
                    local list = RoleManager.Query(function(v) return role.camp ~= v.camp end)
                    local damage = BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.Attack), _i)
                    for k, v in ipairs(list) do
                        BattleUtil.ApplyDamage(nil, role, v,  damage)--damage
                    end
                end
            end

        end
        
        local function _OnRoundChange(curRound)
            if curRound == 1 then
                local list = RoleManager.Query(function(v) return role.camp ~= v.camp end)
                -- 我方击碎产生效果
                local mylist = RoleManager.Query(function(v) return role.camp == v.camp end)
                for k, role in ipairs(mylist) do
                    role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
                end

                for k, v in ipairs(list) do
                    local onBuffStart = function(_buff)                        
                        if (_buff.type == BuffName.Control and _buff.ctrlType == _b) or (_buff.type == BuffName.PropertyChange and _buff.propertyChangeType == _c) then
                            local buff = Buff.Create(role, BuffName.PropertyChange, _g, BattlePropList[_d], _f, CountTypeName.Add)
                            buff.cover = true
                            buff.maxLayer = 10
                            role:AddBuff(buff)
                            buff = Buff.Create(role, BuffName.PropertyChange, _g, BattlePropList[_e], _f, CountTypeName.Add)
                            buff.cover = true
                            buff.maxLayer = 10
                            role:AddBuff(buff)
                        end
                    end
                    --冰封结界修正概率 a
                    local onBuffProbabilityChange =function(_buffFrozen)
                        if _buffFrozen.propertyName == RoleDataName.AttackAddition and _buffFrozen.propertyChangeType == PropertyChangeType.Icebound then
                            _buffFrozen.probaFrozenFix = _a
                        end
                    end
                    v.Event:AddEvent(BattleEventName.BuffStart, onBuffProbabilityChange)  
                    v.Event:AddEvent(BattleEventName.BuffStart, onBuffStart)     
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
                
    end,

    --> 攻击时, 若目标存在[a]或[b]持续伤害状态, 则[c]目标的[d]属性临时[e]改变[f]
    [309] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4] --22
        local _e = args[5]
        local _f = args[6] --10
        --RoleManager.LogArgs("309",args)
        local isAdd = false
        local onRoleHit = function(defRole, factorFunc, damageType, skill)
            if BattleLogic.BuffMgr:HasBuff(defRole, BuffName.DOT, function(buff) return (buff.damageType == _a or buff.damageType == _b) end) then
                if _c == 1 then
                    BattleUtil.AddProp(defRole, _d, _f, _e) 
                    isAdd = true                   
                elseif _c == 2 then
                    BattleUtil.AddProp(role, _d, _f, _e)
                    isAdd = true
                elseif _c == 3 then
                    BattleUtil.AddProp(defRole, _d, _f, _e)
                    BattleUtil.AddProp(role, _d, _f, _e)
                    isAdd = true
                end                
            end
        end

        role.Event:AddEvent(BattleEventName.RoleDamageBefore, onRoleHit)


        local onRoleDamageAfter = function (defRole, damageFunc, fixDamage)
            if isAdd then
                if _c == 1 then
                    BattleUtil.RevertProp(defRole, _d, _f, _e) 
                    isAdd = false                   
                elseif _c == 2 then
                    BattleUtil.RevertProp(role, _d, _f, _e)
                    isAdd = false
                elseif _c == 3 then
                    BattleUtil.RevertProp(defRole, _d, _f, _e)
                    BattleUtil.RevertProp(role, _d, _f, _e)
                    isAdd = false
                end 
            end            
        end

        role.Event:AddEvent(BattleEventName.RoleDamageAfter, onRoleDamageAfter)
    end,

    --> 攻击时, 有[a]概率为目标附加1个【标识】,最多[b]层(自己的叠加上限)，每个【标识】使自己的[c]属性[d]改变[e],
    -- [f]个及以上【标识】使携带者的[g]属性[h]改变[i]
    [320] = function(role, args, delay)
        local _a = args[1]     -- 1
        local _b = args[2]     -- 10
        local _c = args[3]     -- 22
        local _d = args[4]     -- 1
        local _e = args[5]     -- 0.03
        local _f = args[6]     -- 3
        local _g = args[7]     -- 6
        local _h = args[8]     -- 3
        local _i = args[9]     -- 0.3
        --RoleManager.LogArgs("320",args)

        local function getEmenySignNum()
            local list = RoleManager.Query(function(v) return role.camp ~= v.camp and not role:IsRealDead() end)
            local totalSignNum = 0
            for k, v in ipairs(list) do
                local brandSignList = BattleLogic.BuffMgr:GetBuff(v, function(buff)
                    return buff.type == BuffName.Brand and buff.flag == BrandType.Sign
                end)
                if brandSignList and #brandSignList > 0 then
                    totalSignNum = totalSignNum + brandSignList[1].layer
                end
            end
            --LogError("totalSignNum:"..totalSignNum)
            return totalSignNum
        end

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()

                BattleUtil.RandomAction2(_a, function()
                    local brand = Buff.Create(defRole, BuffName.Brand, 0, BrandType.Sign)
                    -- brand.maxLayer = _b
                    brand.clear = false
                    brand.startFunc= function()
                        if getEmenySignNum() <= _b then
                            BattleUtil.AddProp(role, _c, _e, _d)
                        end                    
                        local brandSignList = BattleLogic.BuffMgr:GetBuff(defRole, function(buff)
                            return buff.type == BuffName.Brand and buff.flag == BrandType.Sign
                        end)
                        if brandSignList and #brandSignList > 0 then                        
                            if brandSignList[1].layer == _f  then
                                --LogError("layer add f:"..brandSignList[1].layer)
                                BattleUtil.AddProp(defRole, _g, _i, _h)                                    
                            end
                        end
                    end
                    brand.endFunc = function ()
                        local signs=getEmenySignNum() 
                        if brand.disperse or brand.caster.isRealDead then 
                            if signs <= _b then                        
                                for i=1, brand.layer do
                                    BattleUtil.RevertProp(role, _c, _e, _d)
                                end
                            else
                                --多余层数还原
                                local del_signs = brand.layer + _b - signs
                                if del_signs > 0 then
                                    for i=1, del_signs do
                                        BattleUtil.RevertProp(role, _c, _e, _d)
                                    end
                                end
                            end

                            local brandSignList = BattleLogic.BuffMgr:GetBuff(brand.caster, function(buff)
                                return buff.type == BuffName.Brand and buff.flag == BrandType.Sign
                            end)
        
                            if brandSignList and #brandSignList > 0 then                       
                                if brandSignList[1].layer < _f then
                                    --LogError("revert one f:"..brandSignList[1].layer)
                                    BattleUtil.RevertProp(brand.caster, _g, _i, _h)                            
                                end
                            end
                        end                                  
                    end
                    defRole:AddBuff(brand)
                    brand.duration = 0 --永久存在
                                
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
        
    end,

    --> 攻击时, 若目标的生命大于等于[a], 则[b]目标的[c]属性临时[d]改变[e]
    [321] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local onRoleDamageBefore = function(defRole, damage, bCrit, finalDmg, damageType, skill)
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

                local OnSkillCastEndOnce = nil
                OnSkillCastEndOnce = function(skill)
                    role.Event:RemoveEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
                    --还原属性
                    if _b == 1 then
                        BattleUtil.RevertProp(defRole, _c, _e, _d)
                    elseif _b == 2 then
                        BattleUtil.RevertProp(role, _c, _e, _d)
                    elseif _b == 3 then
                        BattleUtil.RevertProp(defRole, _c, _e, _d)
                        BattleUtil.RevertProp(role, _c, _e, _d)
                    end
                end
                role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
            end


        end
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, onRoleDamageBefore)
    end,

    --> 攻击时, 若目标的生命小于[a], 则[b]目标的[c]属性临时[d]改变[e]
    [345] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]  -- +100
        -- RoleManager.LogArgs("345",args)
        local onRoleHit = function( defRole, factorFunc, damageType, skill,baseFactor)
            local hpPercent = defRole:GetRoleData(RoleDataName.Hp) / defRole:GetRoleData(RoleDataName.MaxHp)
        --    LogError("per"..hpPercent)
            if hpPercent < _a then
                if _b == 1 then
                    BattleUtil.AddProp(defRole, _c, _e+0.0001, _d)
                    -- LogError("add ".._c)
                elseif _b == 2 then
                    BattleUtil.AddProp(role, _c, _e+0.0001, _d)
                    -- LogError("add ".._c)
                elseif _b == 3 then
                    BattleUtil.AddProp(defRole, _c, _e+0.0001, _d)
                    BattleUtil.AddProp(role, _c, _e+0.0001, _d)
                    -- LogError("add ".._c)
                end
                -- LogError("add"..hpPercent)
                local OnSkillCastEndOnce = nil
                OnSkillCastEndOnce = function(skill)
                    role.Event:RemoveEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
                    --还原属性
                    if _b == 1 then
                        BattleUtil.RevertProp(defRole, _c, _e, _d)
                    elseif _b == 2 then
                        BattleUtil.RevertProp(role, _c, _e, _d)
                    elseif _b == 3 then
                        BattleUtil.RevertProp(defRole, _c, _e, _d)
                        BattleUtil.RevertProp(role, _c, _e, _d)
                    end
                end
                role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, onRoleHit)
    end,

    --> 攻击时, 若目标的生命小于[a], 则[b]概率为[c]目标附加[d]属性状态, [e]改变[f], 持续[g]回合
    [322] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        local _g = args[7]
       -- RoleManager.LogArgs("322",args)
        local isCover = true
        local coverLayer = 1
        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                local hpPercent = BattleUtil.ErrorCorrection(defRole:GetRoleData(RoleDataName.Hp) / defRole:GetRoleData(RoleDataName.MaxHp))
                if hpPercent < _a then
                    BattleUtil.RandomAction2(_b, function()
                        if skill and not defRole:IsDead() then
                            local buff = Buff.Create(role, BuffName.PropertyChange, _g, PropertyChangeTypeMap[_d], _f, _e, _d)
                            local buff_2 = Buff.Create(role, BuffName.PropertyChange, _g, PropertyChangeTypeMap[_d], _f, _e, _d)
                            buff.maxLayer = coverLayer
                            buff_2.maxLayer = coverLayer
                            buff.cover = isCover
                            buff_2.cover = isCover
                            if _c == 1 then                            
                                defRole:AddBuff(buff_2)
                                buff_2:OnStart()
                            elseif _c == 2 then
                                role:AddBuff(buff)
                                buff:OnStart()
                            elseif _c == 3 then                            
                                defRole:AddBuff(buff_2)
                                role:AddBuff(buff)
                                buff_2:OnStart()
                                buff:OnStart()
                            else
                                buff.disperse = true
                                buff_2.disperse = true
                            end
                        end
                    end)
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --> 攻击时, 若目标的速度小于自己, 则[a]目标的[b]属性临时[c]改变[d]
    [326] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local onRoleDamageBefore = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if defRole:GetRoleData(RoleDataName.Speed) < role:GetRoleData(RoleDataName.Speed) then
                if _a == 1 then
                    BattleUtil.AddProp(defRole, _b, _d, _c)
                elseif _a == 2 then
                    BattleUtil.AddProp(role, _b, _d, _c)
                elseif _a == 3 then
                    BattleUtil.AddProp(defRole, _b, _d, _c)
                    BattleUtil.AddProp(role, _b, _d, _c)
                end

                local OnSkillCastEndOnce = nil
                OnSkillCastEndOnce = function(skill)
                    role.Event:RemoveEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
                    --还原属性
                    if _a == 1 then
                        BattleUtil.RevertProp(defRole, _b, _d, _c)
                    elseif _a == 2 then
                        BattleUtil.RevertProp(role, _b, _d, _c)
                    elseif _a == 3 then
                        BattleUtil.RevertProp(defRole, _b, _d, _c)
                        BattleUtil.RevertProp(role, _b, _d, _c)
                    end
                end
                role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, onRoleDamageBefore)
    end,

    --> 攻击时, 若目标是[a]阵营, 则[b]目标的[c]属性临时[d]改变[e]
    [342] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local triggered=false
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
                triggered=true
            end
        end

        local onRoleHitRevert = function(damagingFunc, defRole, damage, skill, dotType, bCrit, damageType)
            if defRole.roleData.element == _a  and triggered then
                if _b == 1 then
                    BattleUtil.RevertProp(defRole, _c, _e, _d)
                elseif _b == 2 then
                    BattleUtil.RevertProp(role, _c, _e, _d)
                elseif _b == 3 then
                    BattleUtil.RevertProp(defRole, _c, _e, _d)
                    BattleUtil.RevertProp(role, _c, _e, _d)
                end
                triggered=false
            end
        end


        role.Event:AddEvent(BattleEventName.FinalDamage, onRoleHitRevert)

        role.Event:AddEvent(BattleEventName.RoleDamageBefore, onRoleHit)
    end,

    --> 为自己添加魔种
    --> 攻击时, 有[a]概率清除任意己方单位的一个[b]清除状态, 并为其附加一层【魔种】, 最多[c]层, 每层魔种使携带者[d]属性[e]改变[f], 无法驱散一直存在 
    [349] = function(role, args, delay)
        local _a = args[1] -- 0.3
        local _b = args[2] -- 6
        local _c = args[3] -- 5
        local _d = args[4] -- 22
        local _e = args[5] -- 1
        local _f = args[6] -- 0.05
        
        --每次攻击可转化次数 目前固定为 1次
        local TurnOnce = 1
        -- RoleManager.LogArgs("349",args)
        local function getNum()
            local totalSignNum = 0
            local brandSignList = BattleLogic.BuffMgr:GetBuff(role, function(buff)
                return buff.type == BuffName.Brand and buff.flag == BrandType.MagicSeed
            end)
            if brandSignList and #brandSignList > 0 then
                totalSignNum = brandSignList[1].layer
            end
            return totalSignNum
        end

        local searchFunc = function(role)
            local list = BattleLogic.BuffMgr:GetBuff(role, function (buff)
                return buff.type == BuffName.Control or buff.isDeBuff or buff.type == BuffName.DOT              
            end)
            return list and #list > 0
        end

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if TurnOnce <=0 then
                return
            else
                TurnOnce = TurnOnce - 1
            end
            
            BattleLogic.WaitForTrigger(delay, function ()
                local clearBuff = nil
                local clearRole = nil
                local list = RoleManager.Query(searchFunc,false)
                list = BattleUtil.ShufferRoles(list,1)
                if not list or #list==0 then return end
                for k, v in ipairs(list) do
                    local bList = BattleLogic.BuffMgr:GetBuff(v, function (buff)                        
                        return clearBuffPredicate(buff, _b) and buff.clear  
                    end)
                    
                    
                    if #bList > 0 then
                        clearBuff = bList[1]
                        clearRole = v
                        break
                    end
                end
                if clearBuff then
                    BattleUtil.RandomAction2(_a, function()
                         
                        BattleLogic.BuffMgr:ClearBuff(clearRole, function (buff)
                            return clearBuff == buff and buff.clear
                        end)
                    
                        if getNum() < _c then
                            local brand = Buff.Create(role, BuffName.Brand, 0, BrandType.MagicSeed)
                            brand.maxLayer = _c
                            brand.clear = false
                            brand.endFunc = function ()                                 
                                BattleUtil.RevertProp(role, _d, _f * brand.layer, _e)
                            end
                            brand.cover = true
                            role:AddBuff(brand)
                            brand.startFunc =function()                                 
                                BattleUtil.AddProp(role, _d, _f * brand.layer, _e)
                            end
                        else
                            local brand2 = Buff.Create(role, BuffName.Brand, 1, BrandType.MagicSeed)
                            brand2.clear = true
                            brand2.cover = false
                            role:AddBuff(brand2)
                        end

                    end)
                end
            end)
            
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)

        local onRoleStart = function()
            TurnOnce = 1
        end
        role.Event:AddEvent(BattleEventName.RoleTurnStart, onRoleStart)
    end,

    --> 攻击后, 自己的[a]属性[b]改变[c]，可叠加，持续[d]回合
    [301] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local onSkillLastEffectTrigger = function(skill)
            
            local buff = Buff.Create(role, BuffName.PropertyChange, _d, BattlePropList[_a], _c, _b)
            buff.cover = false
            buff.maxLayer = 0
            role:AddBuff(buff)
        end
        role.Event:AddEvent(BattleEventName.SkillLastEffectTrigger, onSkillLastEffectTrigger)
    end,

    --> 释放[a]号技能时, 有[b]概率使技能目标的[c]属性[d]改变[e], 可叠加, 持续[f]回合
    [306] = function(role, args, delay)
        local _a = args[1]      -- 1         
        local _b = args[2]      -- 1
        local _c = args[3]      -- 9
        local _d = args[4]      -- 1
        local _e = args[5]      -- 0.2
        local _f = args[6]      -- 2
       
        local OnSkillCast = function(skill)
            BattleLogic.WaitForTrigger(delay, function ()
                if skill.ext_slot == _a then
                    BattleUtil.RandomAction2(_b, function ()
                        local targets = skill:GetDirectTargets()
                        if not targets or #targets == 0 then return end

                        for _, target in ipairs(targets) do
                            local buff = Buff.Create(role, BuffName.PropertyChange, _f, BattlePropList[_c], _e, _d)
                            --buff.cover = true                        
                            target:AddBuff(buff)
                            buff.maxLayer = NormalMaxLayer
                        end
                    end)
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)
    end,

    --> 释放[a]号技能时, 若目标是[b]阵营, 则[c]目标的[d]属性临时[e]改变[f]
    [310] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local isAdded = false
        local targets =nil
        local AddEnemyProp =function(skill)
            targets = skill:GetDirectTargets()
            if not targets or #targets == 0 then return end
            for _, target in ipairs(targets) do
                if target.roleData.element == _b then                  
                    BattleUtil.AddProp(target, _d, _f, _e)
                end
            end
        end
        local RevertEnemyProp=function()
            if not targets or #targets == 0 then return end
            for _, target in ipairs(targets) do
                if target.roleData.element == _b  and not target:IsRealDead() then                
                    BattleUtil.RevertProp(target, _d, _f, _e)
                end
            end
        end

        local OnSkillCast = function(skill)
            if skill.ext_slot == _a then
                if _c == 1 then
                    AddEnemyProp(skill)
                    isAdded=true
                elseif _c == 2 then
                    BattleUtil.AddProp(role, _d, _f, _e)
                    isAdded=true
                elseif _c == 3 then
                    AddEnemyProp(skill)
                    BattleUtil.AddProp(role, _d, _f, _e)
                    isAdded=true
                end 
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)

         -- 还原属性
         local OnSkillCastEnd = function(skill)
            if isAdded then
                if _c == 1 then
                    RevertEnemyProp()
                    isAdded=false
                elseif _c == 2 then
                    BattleUtil.RevertProp(role, _d, _f, _e)
                    isAdded=false
                elseif _c == 3 then
                    RevertEnemyProp()
                    BattleUtil.RevertProp(role, _d, _f, _e)
                    isAdded=false
                end
            end
        end

        role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEnd)
    end,

    --> 释放[a]号技能时, 若目标是[b]阵营, 则有[c]概率为目标附加[d]控制状态,持续[e]回合
    [311] = function(role, args, delay)
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
    [323] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local OnRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                if defRole:IsDead() then
                    BattleUtil.RandomAction2(_b, function()
                        defRole:SetReliveFilter(false)
                    end)
                end
            end)
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
   [333] = function(role, args, delay)
    local _a = args[1]
    local _b = args[2]
    local _c = args[3]
    local _d = args[4]
    local _e = args[5]
    
        local OnRoleDamageBefore = function(defRole, factorFunc, damageType, skill,baseFactor)
            BattleLogic.WaitForTrigger(delay, function ()
                -- local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
                -- local OnSkillFirstEffectTrigger = function(skill)        
                if skill.ext_slot == _a then
                    BattleUtil.RandomAction2(_b, function()
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
                                    -- 记录技能伤害
                                    local dif = baseFactor*_d
                                    BattleUtil.CalSimpleDamage(nil, role, otherRole[i],damageType,dif)
                                    -- BattleUtil.TriggerDamage(nil, role, otherRole[i], floor(damage * _d))
                                    -- BattleUtil.ApplyDamage(nil, role, otherRole[i], floor(role:GetRoleData(RoleDataName.Attack) * _d))
                                end
                            end
                        end
                        
                    end)
                end
            end)
        end
        -- role.Event:AddEvent(BattleEventName.SkillFirstEffectTrigger, OnSkillFirstEffectTrigger)
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, OnRoleDamageBefore)
        -- role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

--> 释放[a]号技能时, 有[b]概率使[c]目标附加[d]控制状态, , 持续[e]回合
    [334] = function(role, args, delay)
        local _a = args[1]  --1
        local _b = args[2]  --0.5
        local _c = args[3]  --1
        local _d = args[4]  --10
        local _e = args[5]  --2

        local OnSkillCast = function(skill)
            BattleLogic.WaitForTrigger(delay, function ()
                if skill.ext_slot == _a then
                    local target1 = function()
                        BattleUtil.RandomAction2(_b, function()
                            local targets = skill:GetDirectTargets()
                            if not targets or #targets == 0 then return end
                            for _, target in ipairs(targets) do

                                BattleUtil.RandomControl(1, _d, role, target, _e)
                            end
                        end)
                    end
                    local target2 = function()

                        BattleUtil.RandomControl(_b, _d, role, role, _e)
                    end
                    if _c == 1 then
                        target1()
                    elseif _c == 2 then
                        target2()
                    end
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)

    end,

    --> 受到攻击时, [a]概率触发【反击】,对攻击者造成攻击[b]的[c]型伤害
    [302] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3] 

        role.isHoldBeatingBack = true
        local OnBeHit = nil
        --> RoleBeHit受击正常是会触发一次（按之前的逻辑） 加个skillcast reset 确保一下
        OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType, skill, transType)
            --自己或者自己阵营的人攻击自己不造成反击
            if atkRole.camp == role.camp then 
                return 
            end
            -- BattleLogic.WaitForTrigger(delay, function ()
                if not skill.isAdd then  --混乱状态不造成反击
                    return
                end
 

                if role.isHoldBeatingBack then
                    BattleUtil.RandomAction2(_a, function ()
                        --是否是混乱状态的反击(特殊处理)
                        role.ctrl_chaos_beatBack = true

                        --修改伤害百分比(临时处理写死，可优化)
                        -- 由于仅修改原始参数每次修改会叠加 所以增加镜像数据镜像 原始数据不会修改
                        -- BattleUtil.ChangeBaseSkillDamage(role,_b,_c,1)
                        local cloneArrary = BattleUtil.cloneTable(role.skillArray)
                        BattleUtil.ChangeSkillArrayDamage(cloneArrary,_b,_c,1)
                        role:InsertSkill(SkillBaseType.Physical, false, {[1] = {atkRole}}, cloneArrary[1], SkillSubType.BeatBack)
                        --BattleUtil.CalDamage(nil, role, atkRole, _c, _b)
                        -- BattleUtil.TirggerOnceAtEvent(role,
                        --     function(_role,args)
                        --         BattleUtil.RevertBaseSkillDamage(_role)                        
                        --     end,
                        --     BattleEventName.RoleDamageAfter,nil)
                        end
                    )
                        role.isHoldBeatingBack = false
                end
            -- end)
        end

        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)

        

        local OnSkillCast = function(skill)
            role.isHoldBeatingBack = true
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)
    end,

    --> 受到攻击时, [a]概率为攻击者附加[b]持续伤害状态, 每回合减少相当于施法者[c]属性[d]的生命, 持续[e]回合
    [315] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
            BattleLogic.WaitForTrigger(delay, function ()
            local hitblood = floor(role:GetRoleData(BattlePropList[_c]) * _d)
            BattleUtil.RandomDot(_a, _b, role, atkRole, _e, 1, hitblood, function(buff)
                buff.isRealDamage = true
            end)

            --[[
                    BattleUtil.RandomAction2(_a, function ()
                    local hitblood = floor(role:GetRoleData(BattlePropList[_c]) * _d)
                    local dot = Buff.Create(role, BuffName.DOT, _e, 1, _b, hitblood)
                    dot.isRealDamage = true
                    atkRole:AddBuff(dot)
                end)
            ]]
               
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)

    end,

    --> 受到攻击时, 如果目标是[a]职业, 则[b]属性临时[c]改变[d]
    [303] = function(role, args, delay)
        local _a = args[1]  --3 
        local _b = args[2]  --6
        local _c = args[3]  --1
        local _d = args[4]  --0.15
        
        local OnBeHit = function( atkRole, factorFunc, damageType, skill,baseFactor,defRole)
            if atkRole.professionId == _a then
                BattleUtil.AddProp(role, _b, _d, _c)         
                BattleUtil.TirggerOnceAtEvent(role,function(_role,args)
                    BattleUtil.RevertProp(_role, _b, _d, _c)
                end
            ,BattleEventName.RoleBeDamagedAfter,nil)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamagedBefore, OnBeHit)

    end,

    --> 受到攻击时, 增加[a]点怒气, 最多[b]点怒气
    [318] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
                local brand = Buff.Create(role, BuffName.Brand, 0, BrandType.Angry)
                brand.layer = _a
                brand.maxLayer = _b

                brand.endFunc = function ()
                    
                end
                role:AddBuff(brand)
            end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)

    end,

    --> 受到攻击时, 伤害不会超过自己[a]属性的[b]
    [331] = function(role, args, delay)
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
    [346] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function()
                    local brand = Buff.Create(role, BuffName.Brand, _b, BrandType.curse)
                    brand.TriggerFunc = function()
                        local damage = floor(role:GetRoleData(BattlePropList[_c]) * _d)                    
                        BattleUtil.ApplyDamage(nil, role, atkRole, damage, nil, nil, BuffDamageType.Curse, false)
                    end
                    brand:SetInterval(_b )
                    brand.cover = false
                    atkRole:AddBuff(brand)
                    -- local auraBuff = Buff.Create(role, BuffName.Aura, _b, function (target)
                    --     BattleUtil.ApplyDamage(nil, role, atkRole, floor(role:GetRoleData(BattlePropList[_c]) * _d))
                    -- end)
                    -- auraBuff.interval = _b
                    -- atkRole:AddBuff(auraBuff)
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)

    end,

    --> 普通攻击时, 有[a]概率为[b]目标附加[c]属性状态, [d]改变[e], 持续[f]回合
    [330] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local OnRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                if skill.ext_slot == 0 then
                    if not defRole:IsDead() then
                        BattleUtil.RandomAction2(_a, function()
                            defRole:AddBuff(Buff.Create(role, BuffName.PropertyChange, _f, PropertyChangeTypeMap[_c], _e, _d, _c))
                        end)
                    end
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, OnRoleHit)

    end,

    --> 普通攻击时, 为己方生命最低的单位恢复相当于自身[a]属性[b]的生命
    [329] = function(role, args, delay)
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
    [344] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local OnRoleHit = function(atkRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                if skill.ext_slot == 0 then
                    BattleUtil.RandomAction2(_a, function()
                        local brand = Buff.Create(role, BuffName.Brand, _b, BrandType.curse)
                        brand.TriggerFunc=function()
                            local damage = floor(role:GetRoleData(BattlePropList[_c]) * _d)
                            --诅咒类型的buff伤害没有克制
                            BattleUtil.ApplyDamage(nil, role, atkRole, damage, nil, nil, BuffDamageType.Curse, false)
                        end
                        brand:SetInterval(_b)
                        brand.cover = false                       
                        atkRole:AddBuff(brand)
                    end)
                end
            end)
            
        end
        role.Event:AddEvent(BattleEventName.RoleHit, OnRoleHit)

    end,

    --> 自己死亡时, 为己方所有单位恢复相当于自身[a]属性[b]的生命, 只能触发[c]次
    [328] = function(role, args, delay)
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
    [314] = function(role, args, delay)
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
                deadRole:SetRelive(BattleUtil.FP_Mul(role:GetRoleData(BattlePropList[_a]), _b) / role:GetRoleData(RoleDataName.MaxHp))
            end
        end

        local counter2 = 0
        local OnRoleRelive = function(deadRole)
            counter2 = counter2 + 1
            if counter2 == 1 then
                deadRole:AddBuff(Buff.Create(role, BuffName.Immune, 1, 0))
                deadRole:AddBuff(Buff.Create(role, BuffName.PropertyChange, _f, BattlePropList[_c], _e, _d))
            end
        end

        role.Event:AddEvent(BattleEventName.RoleRelive, OnRoleRelive)
        role.Event:AddEvent(BattleEventName.RoleRealDead, onRoleRealDead)

    end,

    --> 己方单位暴击时, 为己方全体单位恢复伤害量[a]的生命
    [313] = function(role, args, delay)
        local _a = args[1]

        local isAdd = false

        local onRoundChange = function(curRound)
            if curRound == 1 and not isAdd then
                local list = RoleManager.Query(function(v) return role.camp == v.camp and role.roleId ~= v.roleId end)
                local tubuList = RoleManager.QueryTibu(function(v) return role.camp == v.camp and role.roleId ~= v.roleId end)

                local onRoleCrit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
                    if role:IsDead() then
                        return
                    end
                    
                    local list2 = RoleManager.Query(function(v) return role.camp == v.camp end)
                    local val = floor(BattleUtil.FP_Mul(damage, _a))
                    for i=1, #list2 do
                        BattleUtil.CalTreat(role, list2[i], val)
                    end 

                end
                for i=1, #list do
                    list[i].Event:AddEvent(BattleEventName.RoleCrit, onRoleCrit)
                end

                for i=1, #tubuList do
                    tubuList[i].Event:AddEvent(BattleEventName.RoleCrit, onRoleCrit)
                end

                role.Event:AddEvent(BattleEventName.RoleCrit, onRoleCrit)
                isAdd = true
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)
    
    end,

    --> 己方单位暴击时, 为己方全体单位附加吸收盾, 吸收量为伤害量的[a], 持续[b]回合
    [348] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local onRoundChange = function(curRound)
            if curRound == 1 then
                local list = RoleManager.Query(function(v) return role.camp == v.camp end)
                local tubuList = RoleManager.QueryTibu(function(v) return role.camp == v.camp end)

                local onRoleCrit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
                    if role:IsDead() then
                        return
                    end
                
                    local list2 = RoleManager.Query(function(v) return role.camp == v.camp end)
                    local val = floor(BattleUtil.FP_Mul(damage, _a))
                    for i=1, #list2 do
                        local buff = Buff.Create(role, BuffName.Shield, _b, ShieldTypeName.NormalReduce, val, 0)
                        buff.cover = true
                        buff.isValueCover = true
                        list2[i]:AddBuff(buff)
                    end 
                end
                for i=1, #list do
                    list[i].Event:AddEvent(BattleEventName.RoleCrit, onRoleCrit)
                end

                for i=1, #tubuList do
                    tubuList[i].Event:AddEvent(BattleEventName.RoleCrit, onRoleCrit)
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)
        
    end,

    --> 击杀目标时, 若目标是[a]阵营, 则自身恢复伤害量[b]的生命
    [316] = function(role, args, delay)
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
    [312] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local function onSkillTargetCheck(func, skill)
            if role.ctrl_chaos or role.lockTarget~=nil then return end    --混乱,嘲讽状态不强制改变目标
            if skill.ext_slot == 0 then
                local list = RoleManager.Query(function(r)
                    return r.camp ~= role.camp
                end)
                --local chooseId = skill.effectList.buffer[1].chooseId
                local num = skill:GetMaxTargetNum()
                -- local num = #skill.effectTargets[1]

                BattleUtil.Sort(list, function(a, b)
                    local aHave = BattleLogic.BuffMgr:HasBuff(a, BuffName.DOT, function (buff) return buff.damageType == _a or buff.damageType == _b end)
                    local bHave = BattleLogic.BuffMgr:HasBuff(b, BuffName.DOT, function (buff) return buff.damageType == _a or buff.damageType == _b end)
                    if aHave and bHave then
                        return false
                    elseif not aHave and bHave then
                        return true
                    elseif aHave and not bHave then
                        return false
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
        role.Event:AddEvent(BattleEventName.SkillTargetCheck, onSkillTargetCheck)
    end,

    --> 改变【普通攻击】, 使其伤害[a]类型改变[b]
    [325] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        --RoleManager.LogArgs("325",args)
        local function onFinalDamage(damagingFunc, defRole, damage, skill, dotType, bCrit, damageType)
            if skill and skill.ext_slot == 0 and skill.skillSubType~=2 then
                local changeValue = function(ct, a, b)
                    if ct == 1 then
                        return a + b
                    elseif ct == 2 then
                        return a + floor(BattleUtil.FP_Mul(a, b))
                    elseif ct == 3 then
                        return a - b
                    elseif ct == 4 then
                        return a - floor(BattleUtil.FP_Mul(a, b))
                    end
                end
     
                
                --LogError("325 triggerd before"..damage)
                local d = floor(changeValue(_a, damage, _b) + 0.5)
                local cDamage = d - damage
                --LogError("325 triggerd after"..cDamage.." D:"..d)
                damagingFunc(-cDamage)
            end
        end
        role.Event:AddEvent(BattleEventName.FinalDamage, onFinalDamage)
    end,

    --> 改变[a]号技能, 使其附加的【诅咒】的伤害增加[b]
    [343] = function(role, args, delay)
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
    [338] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local onRoundChange = function(curRound)
            if curRound == 1 then
                local arr = RoleManager.Query(function (r) return r.camp == role.camp end)
                for k, v in ipairs(arr) do
                    if v.roleData.element == _a then
                        BattleUtil.AddProp(v, _b, _d, _c)
                    end
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)
        
    end,

    --> 光环, 提高己方所有单位的【反击】伤害, 增加相当于自己[a]属性的[b]
    [339] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local onRoundChange = function(curRound)
            if curRound == 1 then
                local arr = RoleManager.Query(function (r) return r.camp == role.camp end)
                for k, v in ipairs(arr) do
                    local OnPassiveDamaging = function( damagingFunc, atkRole, damage, skill, dotType, bCrit)                        
                        --if skill and skill.skillSubType~=nil then LogError("339 SkillSubType "..skill.skillSubType.." type:"..type(skill.skillSubType)) end
                        if skill and skill.skillSubType~=nil and skill.skillSubType == 2 then --SkillSubType 对比问题
                            local val = floor(BattleUtil.FP_Mul(_b, role:GetRoleData(BattlePropList[_a])))
                            damagingFunc(-val)
                        end
                    end
                    v.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)

        
    end,

    --> 光环, 若敌方单位死亡时有[a]属性状态, 则恢复己方所有单位相当于自己[b]属性[c]的生命
    [341] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        local onRoundChange = function(curRound)
            if curRound == 1 then
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
                    v.Event:AddEvent(BattleEventName.RoleDead, OnDead)
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)

        
    end,

    --> 光环, 有单位死亡, 自己获得1层【魔界之力】, 每层使自己[a]属性[b]改变[c], 无法驱散, 持续到本场战斗结束( 同1武将1回合内多次死亡只算1次; 自己死亡后不清除魔界之力)
    [347] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        local DeadNums = 0        
        local SignList = {}

        local DeadAddProp = function ()
            -- LogError("加BUFF")   
            BattleUtil.AddProp(role, _a, _c, _b)
            local brand = Buff.Create(role, BuffName.Brand, 0, BrandType.wild)--BrandType.Angry
            brand.clear = false                        
            role:AddBuff(brand)
            brand.cover = true
              --不可驱散永久增加
            --   LogError( "add one is dead!! "..#SignList)
        end

        local IsInsertDeadList = function (deadRole)
             if #SignList == 0 then
                table.insert(SignList,deadRole.roleId)
                DeadAddProp()
             else
                for k,v in pairs(SignList) do
                    if v == deadRole.roleId then
                        return false
                    end
                end
                table.insert(SignList,deadRole.roleId)
                DeadAddProp()
             end
        end

        local onRoundChange = function(curRound)
            if curRound == 1 then
                local OnDead = function(defRole, atkRole)
                    -- LogError(tostring(role:IsDead()))
                    if not role:IsDead() then
                        IsInsertDeadList(defRole)
                    end
                end                    
                BattleLogic.Event:AddEvent(BattleEventName.BattleRoleDead, OnDead)
            else
                SignList = {} --回合变更后清除列表
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)
    end,

    --> 光环, 使所有敌方单位附加[a]或[b]持续伤害状态的概率提升[c], 且提升持续伤害效果, 相当于自己[d]属性的[e]
    [317] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local onRoundChange = function(curRound)
            if curRound == 1 then
                local arr = RoleManager.Query(function (r) return r.camp == role.camp end)
                for k, v in ipairs(arr) do
                    local onPassiveRandomDot = function(func, dot)
                        if dot == _a or dot == _b then
                            local val = floor(BattleUtil.FP_Mul(_e, role:GetRoleData(BattlePropList[_d])))
                            if func then func(_c, 2, val, 1) end    --< 概率加乘 2类型
                        end
                    end
                    v.Event:AddEvent(BattleEventName.PassiveRandomDot, onPassiveRandomDot)
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)


        
    end,

    --> 为己方最先出手的单位时，[a]属性临时[b]改变[c]；[d]属性临时[e]改变[f]; 反之有[g]概率额外增加1个攻击目标，造成原技能[h]的伤害
    [319] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        local _g = args[7]
        local _h = args[8]

        local OnSkillSelectBefore = function(skill)
            --RoleManager.LogArgs("319",args)
            -- BattleLogic.WaitForTrigger(delay, function ()
                -- if skill.ext_slot == 1 or skill.ext_slot == 3 then
                    local maxSpeed = 0
                    local arr = RoleManager.Query(function (r) return r.camp == role.camp end)
                    local maxTarget = nil
                    for k, v in ipairs(arr) do
                        if v and v:GetRoleData(RoleDataName.Speed) > maxSpeed then
                            maxSpeed = v:GetRoleData(RoleDataName.Speed)
                            maxTarget = v
                        end
                    end
                    if maxTarget == role then
                        local OnRoleDamageBefore = nil
                        OnRoleDamageBefore = function(defRole, factorFunc, damageType, skill,baseFactor,atkRole)
                            BattleUtil.AddProp(role, _a, _c, _b)
                            BattleUtil.AddProp(role, _d, _f, _e)
                            
                            role.Event:RemoveEvent(BattleEventName.RoleDamageBefore, OnRoleDamageBefore)
                        end
                        role.Event:AddEvent(BattleEventName.RoleDamageBefore, OnRoleDamageBefore)
                
                        local OnRoleDamageAfter = nil
                        OnRoleDamageAfter = function(defRole, func, damageType)
                            BattleUtil.RevertProp(role, _a, _c, _b)
                            BattleUtil.RevertProp(role, _d, _f, _e)
                           
                            role.Event:RemoveEvent(BattleEventName.RoleDamageAfter, OnRoleDamageAfter)
                        end
                        role.Event:AddEvent(BattleEventName.RoleDamageAfter, OnRoleDamageAfter)
                    else
                        BattleUtil.RandomAction2(_g, function()
                            local OnSkillTargetCheck = nil
                            OnSkillTargetCheck = function(func, skill)
                                
                                local list = RoleManager.Query(function(r)
                                    if r.camp == role.camp then
                                        return false
                                    end
                                    for i = 1, #skill.effectTargets[1] do
                                        if r == skill.effectTargets[1][i] then
                                            return false
                                        end
                                    end
                                    return true
                                end)
                                
                                
                                if func then
                                    if #list > 0 then
                                        local retlist = {}
                                        for i = 1, #skill.effectTargets[1] do
                                            table.insert(retlist, skill.effectTargets[1][i])
                                        end
                                        table.insert(retlist, list[1])
                                        
                                        --> h伤害
                                        local function onFinalBeDamage(damagingFunc, atkRole, damage, skill, dotType, bCrit, damageType)
                                            list[1].Event:RemoveEvent(BattleEventName.FinalBeDamage, onFinalBeDamage)
                                            
                                            
                                            if damagingFunc then damagingFunc(damage - BattleUtil.FP_Mul(damage, _h)) end
                                        end
                                        list[1].Event:AddEvent(BattleEventName.FinalBeDamage, onFinalBeDamage)

                                        func(retlist)
                                    else
                                        func(skill.effectTargets[1])
                                    end
                                end
                                
                                role.Event:RemoveEvent(BattleEventName.SkillTargetCheck, OnSkillTargetCheck)
                            end
                            
                            role.Event:AddEvent(BattleEventName.SkillTargetCheck, OnSkillTargetCheck)
                            
                        end)
                    end
                -- end
            -- end)
            
        end
        role.Event:AddEvent(BattleEventName.SkillSelectBefore, OnSkillSelectBefore)

    end,

    --> 造成[a][伤害类型]时，[b]概率再次释放技能，造成原技能[c]的伤害,[d]属性临时[e]改变[f]
    [350] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local triggerOnce = true
        local OnHit = nil
        --> OnHit打击正常是会触发一次（按之前的逻辑） 加个skillcast reset 确保一下
        OnHit = function(defRole, damage, bCrit, finalDmg, damageType, skill, transType)

            BattleLogic.WaitForTrigger(delay, function ()
                if defRole==nil then
                return
                end
                
                if damageType ~= _a then
                    return
                end
                if not skill.isAdd or not skill then
                    return
                end
                if triggerOnce then
                    BattleUtil.RandomAction2(_b, function ()
                        role:InsertSkill(_a, false, nil, role.skillArray[Slot2Idx(skill.ext_slot)])
                        --开始连击
                        local isC = false
                        local OnSkillCastOnce = nil
                        OnSkillCastOnce = function(skill)
                            role.Event:RemoveEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                            --连击技能开始
                            isC = true

                            local OnFinalDamage = nil
                            OnFinalDamage = function(damagingFunc, defRole, damage, skill, dotType, bCrit, damageType)
                                if isC then
                                    --连击的伤害都要减半
                                    local fDamage = floor(BattleUtil.FP_Mul(damage, _c))
                                    local rDamage = damage - fDamage
                                    damagingFunc(rDamage)
                                end
                            end
                            role.Event:AddEvent(BattleEventName.FinalDamage, OnFinalDamage)

                            local OnSkillCastEndOnce = nil
                            OnSkillCastEndOnce = function(skill)
                                --连击技能完成 
                                isC = false
                                role.Event:RemoveEvent(BattleEventName.FinalDamage, OnFinalDamage)
                                role.Event:RemoveEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
                                --还原属性
                                BattleUtil.RevertProp(role, _d, _f, _e)
                            end
                            role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)

                            --修改属性
                            BattleUtil.AddProp(role, _d, _f, _e)
                        end
                        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                    end)
                    triggerOnce = false
                end
            end)
        end

        role.Event:AddEvent(BattleEventName.RoleHit, OnHit)

        local OnRoleTurnEnd = function(SkillRole)
            triggerOnce = true
        end
        role.Event:AddEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEnd)
        
    end,

    --> 使用[a][伤害类型]击杀目标时[b]概率触发[c]次普攻，普攻伤害为原伤害的[d]
    [351] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local triggerOnce = true
        local OnRoleKillGeneralAttackPursueAttackCheck = nil
        local isStoped = false
        OnRoleKillGeneralAttackPursueAttackCheck = function(defRole, damage, bCrit, damageType, dotType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                if damageType ~= _a then
                    return
                end
                if not skill then
                    return
                end
                if skill and not skill.isAdd then
                    return
                end
                if triggerOnce then
                    BattleUtil.RandomAction2(_b, function ()
                        for i = 1, _c do
                            role:InsertSkill(SkillBaseType.Physical, false, nil, role.skillArray[1])
                        end

                        local isC = false
                        local OnSkillCastOnce = function(skill)
                            isC = true
                            if isStoped then 
                                role.stop_move = true
                                isStoped = false
                            end
                        end
                        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                        local OnRoleTurnEnd = nil
                        OnRoleTurnEnd = function(SkillRole)
                            isC = false
                            role.Event:RemoveEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                            role.Event:RemoveEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEnd)
                        end
                        role.Event:AddEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEnd)


                        local OnFinalDamage = function(damagingFunc, defRole, damage, skill, dotType, bCrit, damageType)
                            if isC then
                                if damage == nil then 
                                    damage = 0
                                end
                                local fDamage = floor(BattleUtil.FP_Mul(damage, _d))
                                local rDamage = damage - fDamage
                                if type(damagingFunc) == "table" then return end
                                damagingFunc(rDamage)
                            end
                        end
                        role.Event:AddEvent(BattleEventName.FinalDamage, OnFinalDamage)

                    end)
                    triggerOnce = false
                end
            end)
        end

        role.Event:AddEvent(BattleEventName.RoleKillGeneralAttackPursueAttackCheck, OnRoleKillGeneralAttackPursueAttackCheck)
        
        local OnRoleTurnEnd = function(SkillRole)
            triggerOnce = true
        end
        role.Event:AddEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEnd)

                -- 检测当前是否禁步状态 连击后复原
        local function resetStop()
            if role.stop_move  and not triggerOnce then
                role.stop_move = false    
                isStoped = true
            end
        end

        role.Event:AddEvent(BattleEventName.SkillCastEnd, resetStop)
        
    end,

    --> 若为反击类技能使用[a][伤害类型]造成暴击时[b]概率触发[c]次普攻，若非反击类技能使用[d][伤害类型]造成暴击时[e]概率触发[f]次普攻
    [352] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local triggerOnce = true
        local OnRoleCrit = nil
        local isStoped = false
        OnRoleCrit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                if not skill then
                    return
                end

                if skill.skillSubType == SkillSubType.BeatBack then
                    if damageType ~= _a then
                        return
                    end

                    if triggerOnce then
                        BattleUtil.RandomAction2(_b, function ()
                            for i = 1, _c do
                                role:InsertSkill(SkillBaseType.Physical, false, nil, role.skillArray[1])
                            end
                        end)
                        triggerOnce = false
                        role.effectTrigger352 = true
                    end
                else
                    if damageType ~= _d then
                        return
                    end

                    if triggerOnce then
                        BattleUtil.RandomAction2(_e, function ()
                            for i = 1, _f do
                                role:InsertSkill(SkillBaseType.Physical, false, nil, role.skillArray[1])
                            end
                        end)
                        triggerOnce = false
                        role.effectTrigger352 = true
                    end
                end
            end)
            
        end

        role.Event:AddEvent(BattleEventName.RoleCrit, OnRoleCrit)


        local OnRoleTurnEnd = function(SkillRole)
            triggerOnce = true
            role.effectTrigger352 = false
        end
        role.Event:AddEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEnd)

        -- -- 检测当前是否禁步状态 连击后复原
        -- local function resetStop()
        --     if role.stop_move  and not triggerOnce then
        --         role.stop_move = false            
        --         isStoped = true
        --     end
        -- end

        -- role.Event:AddEvent(BattleEventName.SkillCastEnd, resetStop)
        
    end,

    --> 生命每下降[a], 则[b]属性[c]改变[d]
    [353] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local reduceHp = 0
        local OnRoleBeDamaged = function(atkRole, damage, bCrit, finalDmg, damageType, dotType, skill)
            reduceHp = reduceHp + finalDmg
            local maxHp = role:GetRoleData(RoleDataName.MaxHp)
            local rH = BattleUtil.FP_Mul(maxHp, _a)
            if reduceHp >= rH then
                local multi = floor(reduceHp / rH)
                reduceHp = reduceHp - BattleUtil.FP_Mul(rH, multi)
                for i = 1, multi do
                    BattleUtil.AddProp(role, _b, _d, _c)
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamaged, OnRoleBeDamaged)
        
    end,

    --> 复活后[a]属性[b]改变[c],持续[d]回合
    [354] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local OnRoleRelive = nil
        OnRoleRelive = function(reliveRole)
            reliveRole:AddBuff(Buff.Create(role, BuffName.PropertyChange, _d, BattlePropList[_a], _c, _b))
            role.Event:RemoveEvent(BattleEventName.RoleRealRelive, OnRoleRelive)
        end
        role.Event:AddEvent(BattleEventName.RoleRealRelive, OnRoleRelive)
        
    end,

    --> 对敌方造成伤害时（dot伤害除外），有[a]概率使其[b]属性[c]改变[d],持续[e]回合
    [355] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local OnDamage = function(defRole, damage, bCrit, finalDmg, damageType, dotType, skill,atkRole)
            BattleLogic.WaitForTrigger(delay, function ()
                if dotType~=nil then return end --排除dot伤害
                BattleUtil.RandomAction(_a, function ()
                    defRole:AddBuff(Buff.Create(role, BuffName.PropertyChange, _e, BattlePropList[_b], _d, _c))
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleDamage, OnDamage)
    end,

    --> 攻击时有[a]概率使目标[b]回合无法复活，对携带复活或还魂技能的目标[c]属性[d]改变[e]
    [356] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function()
                    defRole:SetReliveFilter(false)

                    local roundTimes = _b
                    local onRoundChange = nil
                    onRoundChange = function(curRound)
                        roundTimes = roundTimes - 1
                        if roundTimes <= 0 then
                            BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundChange, onRoundChange)
                            defRole:SetReliveFilter(true)
                        end
                    end
                    BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)

                    if defRole.warWayType[WarWayType.W_6026] or defRole.warWayType[WarWayType.W_6027] then
                        BattleUtil.AddProp(defRole, _c, _e, _d)
                    end
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
        
    end,

    --> 攻击时[a]概率驱散目标身上所有的[b][清除状态]
    [357] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function()
                    BattleLogic.BuffMgr:ClearBuff(defRole, function (buff)
                        return clearBuffPredicate(buff, _b)
                    end)
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
        
    end,

    --> 攻击时, 技能伤害大于目标[a]属性的[b]时，[c]概率对目标添加[d][控制状态]，持续[e]回合
    [358] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            local val = floor(BattleUtil.FP_Mul(_b, defRole:GetRoleData(BattlePropList[_a])))
            
            
            
            if damage > val then
                BattleUtil.RandomControl(_c, _d, role, defRole, _e)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
        
    end,

    --> 攻击时有[a]概率对目标添加[b][控制状态],持续[c]回合
    [359] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleUtil.RandomControl(_a, _b, role, defRole, _c)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
        
    end,

    --> 攻击时有[a]概率[b]改变目标[c]属性[d]，持续[e]回合
    [360] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function()
                    
                    local propertyChange = function(_target, round, pro, v, ct)
                        _target:AddBuff(Buff.Create(role, BuffName.PropertyChange, round, BattlePropList[pro], v, ct))
                    end

                    propertyChange(defRole, _e, _c, _d, _b)
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
        
    end,

    --> 死亡时有[a]概率[b]改变全体友方[c]属性[d]，持续[e]回合
    [361] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local onRoleDead = function(atkRole)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function()
                    
                    local propertyChange = function(_target, round, pro, v, ct)
                        _target:AddBuff(Buff.Create(role, BuffName.PropertyChange, round, BattlePropList[pro], v, ct))
                    end

                    local arr2 = RoleManager.Query(function (r2) return r2.camp == role.camp end)
                    for k, v in ipairs(arr2) do
                        if v then
                            propertyChange(v, _e, _c, _d, _b)
                        end
                    end
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleDead, onRoleDead)
        
    end,

    --> 被携带武力或法力技能的武将攻击时，自身[a]属性临时[b]改变[c]
    [362] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        local OnRoleBeDamagedBefore = function(atkRole, func, damageType)
            if atkRole.warWayType[WarWayType.W_6004] or atkRole.warWayType[WarWayType.W_6005] then
                BattleUtil.AddProp(role, _a, _c, _b)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamagedBefore, OnRoleBeDamagedBefore)

        local OnRoleBeDamagedAfter = function(atkRole, func, damageType)
            if atkRole.warWayType[WarWayType.W_6004] or atkRole.warWayType[WarWayType.W_6005] then
                BattleUtil.RevertProp(role, _a, _c, _b)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamagedAfter, OnRoleBeDamagedAfter)
        
    end,

    --> 攻击携带医术或回春技能的目标时，自身[a]属性临时[b]改变[c]
    [363] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        
        local OnRoleDamageBefore = function(defRole, func, damageType)
            if defRole.warWayType[WarWayType.W_6025] or defRole.warWayType[WarWayType.W_6031] then
                BattleUtil.AddProp(role, _a, _c, _b)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, OnRoleDamageBefore)

        local OnRoleDamageAfter = function(defRole, func, damageType)
            if defRole.warWayType[WarWayType.W_6025] or defRole.warWayType[WarWayType.W_6031] then
                BattleUtil.RevertProp(role, _a, _c, _b)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamageAfter, OnRoleDamageAfter)

    end,

    --> 攻击携带躲闪或敏捷技能的目标时，自身[a]属性临时[b]改变[c]
    [364] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        local OnRoleDamageBefore = function(defRole, func, damageType)
            if defRole.warWayType[WarWayType.W_6001] or defRole.warWayType[WarWayType.W_6020] then
                BattleUtil.AddProp(role, _a, _c, _b)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamageBefore, OnRoleDamageBefore)

        local OnRoleDamageAfter = function(defRole, func, damageType)
            if defRole.warWayType[WarWayType.W_6001] or defRole.warWayType[WarWayType.W_6020] then
                BattleUtil.RevertProp(role, _a, _c, _b)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamageAfter, OnRoleDamageAfter)
        
    end,

    --> 回合开始时，[a]概率清除自身所有[b][清除状态]
    [365] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]


        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, function(curRound)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function()
                    BattleLogic.BuffMgr:ClearBuff(role, function (buff)
                        return clearBuffPredicate(buff, _b)
                    end)
                end)
            end)
        end)
    end,

    --> 回合开始时，恢复自身[a]属性的[b]值
    [366] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, function(curRound)
            local val = floor(BattleUtil.FP_Mul(_b, role:GetRoleData(BattlePropList[_a])))
            BattleUtil.CalTreat(role, role, val)
        end)

    end,

    --> 死亡时，有[a]概率复活，复活时恢复自身[b]属性的[c]值，每场最多触发[d]次
    [367] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local counter = 0
        local onRoleRealDead = function(deadRole)
            -- BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function()
                    counter = counter + 1
                    if counter <= _d then
                        deadRole:SetRelive(BattleUtil.FP_Mul(role:GetRoleData(BattlePropList[_b]), _c) / role:GetRoleData(RoleDataName.MaxHp))
                    end
                end)
            -- end)
        end


        local counter2 = 0
        local OnRoleRelive = function(deadRole)
            counter2 = counter2 + 1
            if counter2 == 1 then
                deadRole:AddBuff(Buff.Create(deadRole, BuffName.Immune, 1, 0))
            end
        end

        role.Event:AddEvent(BattleEventName.RoleRelive, OnRoleRelive)


        role.Event:AddEvent(BattleEventName.RoleRealDead, onRoleRealDead)
        
    end,

    --> 使目标[a]属性[b]改变[c]
    [368] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        BattleUtil.AddProp(role, _a, _c, _b)
        
    end,

    --> 战斗开始时，自身[a]属性[b]改变[c]，持续[d]回合 -- 不能被驱散
    [369] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        --RoleManager.LogArgs("369",args)        
        local isAdd = false
        local function _OnRoundChange(curRound)
            if not isAdd then
                local buff=Buff.Create(role, BuffName.PropertyChange, _d, BattlePropList[_a], _c, _b)
                buff.clear = false -- 不能被驱散
                role:AddBuff(buff)
                isAdd=true
            end
        end

        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
        -- BattleUtil.AddProp(role, _a, _c, _b)
        -- BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, function(curRound)
        --     if curRound >= _d then
        --         BattleUtil.RevertProp(role, _a, _c, _b)
        --     end
        -- end)
        
    end,

    --> 造成[a][伤害类型]时，恢复自己血量，恢复量为伤害量的[b]
    [370] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local onRoleDamage = function(defRole, damage, bCrit, finalDmg, damageType, dotType, skill)
            if role and damageType == _a then
                BattleUtil.CalTreat(role, role, floor(BattleUtil.FP_Mul(_b, damage)))
            end
        end
        role.Event:AddEvent(BattleEventName.RoleDamage, onRoleDamage)
    end,

    --> 当敌方单位携带必杀、物连、法连技能造成伤害时，自身受到的[a]属性[b]改变[c]
    [371] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        local OnRoleBeDamagedBefore = function(caster, func, damageType)
            if role then
                if caster.warWayType then 
                   if caster.warWayType[WarWayType.W_6002] or caster.warWayType[WarWayType.W_6003] or caster.warWayType[WarWayType.W_6009] then
                        BattleUtil.AddProp(role, _a, _c, _b)
                   end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamagedBefore, OnRoleBeDamagedBefore)
        
        local OnRoleBeDamagedAfter = function(caster, func, damageType)
            if role then
               if caster.warWayType then
                   if caster.warWayType[WarWayType.W_6002] or caster.warWayType[WarWayType.W_6003] or caster.warWayType[WarWayType.W_6009] then
                    BattleUtil.RevertProp(role, _a, _c, _b)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamagedAfter, OnRoleBeDamagedAfter)

    end,

    --> 战斗开始时，给己方全体增加伤害吸收盾，吸收量为自身[a]属性的[b],持续[c]回合
    [372] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        local onRoundChange = function(curRound)
            if curRound == 1 then
                local list = RoleManager.Query(function(v) return v.camp == role.camp end)
                for i = 1, #list do 
                    if not list[i]:IsRealDead() then
                        local val = floor(BattleUtil.FP_Mul(_b, role:GetRoleData(BattlePropList[_a])))
                        list[i]:AddBuff(Buff.Create(role, BuffName.Shield, _c, ShieldTypeName.NormalReduce, val, 0))
                    end
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)

        
        
    end,

    --> 战斗中使用[治疗]或[复活]技能时，有[a]概率清除随机一名队友[b][清除状态]
    [373] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local clearFun = function()
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function()
                    local list = RoleManager.Query(function(v) return role.camp == v.camp end)
                    for k, v in ipairs(list) do     --< 任意为第一个拥有者第一个相关buff
                        if v ~= role then
                            local bList = BattleLogic.BuffMgr:GetBuff(v, function (buff)
                                return clearBuffPredicate(buff, _b)
                            end)
                            if #bList > 0 then
                                BattleLogic.BuffMgr:ClearBuff(v, function (buff)
                                    return clearBuffPredicate(buff, _b)
                                end)
                                break
                            end
                        end
                    end
                end)
            end)
        end
        
        local onRoleTreat = function(targetRole, treat, baseTreat)
            clearFun()
        end
        role.Event:AddEvent(BattleEventName.RoleTreat, onRoleTreat)

        local OnRoleRelive = function(reliveRole)
            clearFun()
        end
        role.Event:AddEvent(BattleEventName.RoleRelive, OnRoleRelive)
        
    end,

    --> 受到伤害时，有[a]概率对伤害输出者造成受到伤害的[b]
    [374] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local round = -1

        local onRoleBeDamaged = function(caster, damage, bCrit, finalDmg, damageType, dotType, skill)
            BattleLogic.WaitForTrigger(delay, function ()               
                if role and  caster.uid ~= role.uid and not dotType and round ~= BattleLogic.GetMoveTimes() then
                    BattleUtil.RandomAction2(_a, function()
                        local val = floor(BattleUtil.FP_Mul(_b, damage))                        
                        round = BattleLogic.GetMoveTimes()
                        BattleUtil.ApplyDamage(nil, role, caster, val, nil, nil, nil, false) -- atkRole, defRole
                       
                    end)
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamaged, onRoleBeDamaged)
        
    end,

    --> 使用[a][伤害类型]时，恢复自身血量，恢复量为伤害量的[b]，恢复量不大于自身生命的[c]
    [375] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        
        local OnRoleDamage = function(defRole, damage, bCrit, finalDmg, damageType, dotType, skill)
            if damageType ~= _a then
                return
            end
            local dmg = floor(BattleUtil.FP_Mul(_b, damage))
            local treatVal = dmg
            local limitVal = floor(BattleUtil.FP_Mul(_c, role:GetRoleData(RoleDataName.Hp)))
            if treatVal > limitVal then
                treatVal = limitVal
            end

            BattleUtil.CalTreat(role, role, treatVal)
        end
        role.Event:AddEvent(BattleEventName.RoleDamage, OnRoleDamage)
    end,

    --> 自身受到攻击时，对攻击者造成自身生命值上限[a]的伤害，无视防御 不超过施法者攻击的[b] 伤害
    [376] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local lastMove = 0
        local val = floor(BattleUtil.FP_Mul(_a, role:GetRoleData(RoleDataName.MaxHp)))
        
        local onRoleBeDamaged = function (caster, damage, bCrit, finalDmg, damageType, dotType, skill)
            local limit =floor(role:GetRoleData(RoleDataName.Attack)*_b)
            if val > limit then 
                val = limit
            end
            local curmove=BattleLogic.GetMoveTimes()
            if not role:IsDead() and lastMove~=curmove and role.camp~=caster.camp and not dotType then
                lastMove=curmove
                BattleUtil.ApplyDamage(nil, role, caster, val, nil, nil, nil, false)
            end
        end
        role.Event:AddEvent(BattleEventName.RoleBeDamaged, onRoleBeDamaged)
        
    end,

    --> 进入战斗后，每回合提高[a]伤害，最多叠加[b]层
    [377] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local totalDamage = 0   --< 改为层数 a为伤害的百分比
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, function(curRound)
            if curRound <= _b then
                totalDamage = totalDamage + 1
            end
        end)

        local OnPassiveDamaging = function(damagingFunc, defRole, damage)
            local damageReduce = floor(BattleUtil.FP_Mul(damage, _a, totalDamage))
            damagingFunc(-damageReduce)
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
        
    end,

    --> 攻击造成暴击时有[a]概率额外造成目标生命上限[b]的无视防御伤害（该伤害不超过攻击的[c]倍）
    [378] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        local OnRoleDamage = function(defRole, damage, bCrit, finalDmg)
            BattleLogic.WaitForTrigger(delay, function ()
                if bCrit then
                    BattleUtil.RandomAction2(_a, function()
                        local val = floor(BattleUtil.FP_Mul(_b, defRole:GetRoleData(RoleDataName.MaxHp)))
                        local limit = floor(BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.Attack), _c))
                        val = math.min(val, limit)
                        BattleUtil.ApplyDamage(nil, role, defRole, val)
                    end)
                end
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleDamage, OnRoleDamage)
        
    end,

    --> 治疗时目标获得等同治疗量[a]的【伤害吸收盾】该效果不可驱散，持续[b]回合
    [379] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        
        local OnRoleBeTreated = function(targetRole, treat, baseTreat)
            local val = floor(BattleUtil.FP_Mul(_a, baseTreat))
            local shieldBuff = Buff.Create(role, BuffName.Shield, _b, ShieldTypeName.NormalReduce, val, 0)
            shieldBuff.clear = false
            shieldBuff.cover = true
            shieldBuff.isValueCover = true
            targetRole:AddBuff(shieldBuff)
        end
        role.Event:AddEvent(BattleEventName.RoleTreat, OnRoleBeTreated)
    end,

    --> 己方全员[a]属性[b]改变[c]
    [380] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]

        local onRoundChange = function(curRound)
            if curRound == 1 then
                local list = RoleManager.Query(function(v) return role.camp == v.camp end)
                for k, v in ipairs(list) do
                    BattleUtil.AddProp(v, _a, _c, _b)
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)

        
        
    end,

    --> 每回合开始时，取己方最大生命值单位的[a]生命值，添加此生命值给己方全体单位
    [381] = function(role, args, delay)
        local _a = args[1]

        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, function(curRound)
            local list = RoleManager.Query(function(v) return role.camp == v.camp end)
            local maxHp = 0
            local addHp = 0
            for k, v in ipairs(list) do
                local hp = v:GetRoleData(RoleDataName.Hp)
                if hp > maxHp then
                    maxHp = hp
                    addHp = floor(BattleUtil.FP_Mul(_a, maxHp))
                end
            end
            for k, v in ipairs(list) do
                BattleUtil.CalTreat(role, v, addHp)
            end
        end)
        
    end,

    --> 战斗开始时，给自身增加无懈可击状态（抵挡[a]次控制效果），持续[b]回合
    [382] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local brand
        local triggerCount = 0
        local func = function(buff)
            local isTarget = buff.type == BuffName.Control
            if isTarget then
                triggerCount = triggerCount + 1
                if triggerCount >= _a then --< 抵挡次数到了 清除
                    BattleLogic.BuffMgr:ClearBuff(role, function(buff)
                        return buff == brand
                    end)
                end
                return _a == 0 or (_a > 0 and triggerCount <= _a)
            else
                return false
            end
        end
        role.buffFilter:Add(func)

        brand = Buff.Create(role, BuffName.Brand, _b, BrandType.WithStand)
        brand.maxLayer = _b
        brand.clear = false

        brand.endFunc = function ()
            for i = 1, role.buffFilter.size do
                if role.buffFilter.buffer[i] == func then
                    role.buffFilter:Remove(i)
                    break
                end
            end
        end
        role:AddBuff(brand)
        
    end,

    --> 暴击时，[a]概率使目标无法复活，持续[b]回合
    [383] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local OnRoleCrit = function(defRole)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function ()
                    defRole:SetReliveFilter(false)

                    local brand = Buff.Create(role, BuffName.Brand, _b, BrandType.CantRelive)
                    brand.clear = false
                    brand.startFunc = function()
                        defRole:SetReliveFilter(false)
                    end
                    brand.endFunc = function ()
                        defRole:SetReliveFilter(true)
                    end
                    role:AddBuff(brand)
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleCrit, OnRoleCrit)
        
    end,

    --> 主动治疗时，[a]概率清除治疗目标[b]个负面效果
    [384] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]


        local showCurFrame = false
        local OnRoleTreat = function(targetRole, treat, baseTreat)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function ()
                    local targetList = BattleLogic.BuffMgr:GetBuff(targetRole, function(buff)
                        return clearBuffPredicate(buff, 6)
                    end)
                    
                    local clearT = function(t, list)
                        if list and #list > 0 then
                            local num = 0
                            if _b == 0 then --< 0所有
                                num = #list
                            else
                                num = math.min(_b, #list)
                            end

                            for i = 1, num do
                                BattleLogic.BuffMgr:ClearBuff(t, function(buff)
                                    return buff == list[i]
                                end)
                            end
                        end
                    end

                    clearT(targetRole, targetList)

                    
                    
                    --> 显示用
                    if not BattleLogic.BuffMgr:HasBuff(role, BuffName.Brand, function (buff) return buff.flag == BrandType.TreatCutDebuff end) and not showCurFrame then --< 避免治疗多个触发多次
                        local brand = Buff.Create(role, BuffName.Brand, 0, BrandType.TreatCutDebuff)
                        role:AddBuff(brand)
                        showCurFrame = true

                        BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()
                            showCurFrame = false
                            BattleLogic.BuffMgr:ClearBuff(role, function(buff)
                                return buff == brand
                            end)
                        end)
                    end
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleTreat, OnRoleTreat)
        
    end,

    --> 385~392 回合开始改为技能开始 有目标问题 回合开始确定不了
    --> 每回合开始时，[a]目标[b]属性[c]改变[d]，最多叠加[e]层（不可被驱散）
    [385] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local function onSkillCast(skill)
            if _a == 1 then
                local targets = skill:GetDirectTargets()
                for _, target in ipairs(targets) do
                    local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[_b], _d, _c)
                    buff.cover = true
                    buff.maxLayer = _e
                    buff.clear = false
                    target:AddBuff(buff)
                end
            elseif _a == 2 then
                local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[_b], _d, _c)
                buff.cover = true
                buff.maxLayer = _e
                buff.clear = false
                role:AddBuff(buff)
            end
            
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
    end,

    --> 385~392 回合开始改为技能开始 有目标问题 回合开始确定不了
    --> 每回合开始时，恢复生命上限[a]
    [386] = function(role, args, delay)
        local _a = args[1]

        local function onRoundChange(curRound)
            local value = floor(BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.MaxHp), _a))
            BattleUtil.ApplyTreat(role, role, value)
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)
    end,

    --> 385~392 回合开始改为技能开始 有目标问题 回合开始确定不了
    --> 每回合开始时，[a]目标[b]属性[c]改变[d]，最多叠加[e]层（不可被驱散），并额外使[f]目标，[g]属性[h]改变[i],伤害不超过自身攻击力的[j]
    [387] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        local _g = args[7]
        local _h = args[8]
        local _i = args[9]
        local _j = args[10]

        passivityList[385](role, {_a, _b, _c, _d, _e})

        local function onSkillCast(skill)
            if _f == 1 then
                local targets = skill:GetDirectTargets()
                for _, target in ipairs(targets) do
                    local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[_g], _i, _h)
                    target:AddBuff(buff)
                end
            elseif _f == 2 then
                local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[_g], _i, _h)
                role:AddBuff(buff)
            end
            
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)

        local OnPassiveDamaging = function(damagingFunc, defRole, damage)
            local maxDmg = floor(BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.Attack), _j))
            if maxDmg < damage then
                damagingFunc(damage - maxDmg)
            end
        end
        role.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
    end,

    --> 385~392 回合开始改为技能开始 有目标问题 回合开始确定不了
    --> 每回合开始时，[a]目标[b]属性[c]改变[d]，最多叠加[e]层（不可被驱散），并额外使[f]目标，负面效果随机清除[g]个
    [388] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        local _g = args[7]

        passivityList[385](role, {_a, _b, _c, _d, _e})

        local function clearRoleBuff(par_role)
            local targetList = BattleLogic.BuffMgr:GetBuff(par_role, function(buff)
                return clearBuffPredicate(buff, 6)
            end)
            
            local clearT = function(t, list)
                if list and #list > 0 then
                    local num = 0
                    if _g == 0 then --< 0所有
                        num = #list
                    else
                        num = math.min(_g, #list)
                    end

                    for i = 1, num do
                        BattleLogic.BuffMgr:ClearBuff(t, function(buff)
                            return buff == list[i]
                        end)
                    end
                end
            end

            clearT(par_role, targetList)
        end
        local function onSkillCast(skill)
            if _a == 1 then
                local targets = skill:GetDirectTargets()
                for _, target in ipairs(targets) do
                    clearRoleBuff(target)
                end
            elseif _a == 2 then
                clearRoleBuff(role)
            end
            
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
    end,

    --> 385~392 回合开始改为技能开始 有目标问题 回合开始确定不了
    --> 每回合开始时，[a]目标[b]属性[c]改变[d]，最多叠加[e]层（不可被驱散），并使全场友方[f]属性[g]改变[h]
    [389] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        local _g = args[7]
        local _h = args[8]
        local _i = args[9]

        passivityList[385](role, {_a, _b, _c, _d, _e})

        local function onSkillCast(skill)
            local list = RoleManager.Query(function(v) return role.camp == v.camp end)
            for k, v in ipairs(list) do
                local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[_f], _h, _g)
                v:AddBuff(buff)
            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
    end,

    --> 385~392 回合开始改为技能开始 有目标问题 回合开始确定不了
    --> 每回合开始时，[a]目标[b]属性[c]改变[d]，最多叠加[e]层（不可被驱散），并使自己每回合可抵抗[f]次暴击
    [390] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        passivityList[385](role, {_a, _b, _c, _d, _e})

        local times = _f
        local function onRoundChange(curRound)
            times = _f
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)

        local function onCritMiss(CritMissFunc, atkRole, defRole, bCrit)
            if bCrit then
                if times > 0 then
                    times = times - 1
                    if CritMissFunc then
                        CritMissFunc(false)
                    end
                end
            end
        end
        role.Event:AddEvent(BattleEventName.BeCritMiss, onCritMiss)
    end,

    --> 385~392 回合开始改为技能开始 有目标问题 回合开始确定不了
    --> 每回合开始时，恢复生命上限[a],恢复溢出血量会形成伤害吸收盾保护自己，持续[b]回合。
    [391] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local function onRoundChange(curRound)
            local value = floor(BattleUtil.FP_Mul(role:GetRoleData(RoleDataName.MaxHp), _a))
            local canAddBlood = (role:GetRoleData(RoleDataName.MaxHp) - role:GetRoleData(RoleDataName.Hp))
            local outBlood = 0
            if value > canAddBlood then
                outBlood = floor(value - canAddBlood)
            end
            BattleUtil.ApplyTreat(role, role, value)
            if outBlood > 0 then
                role:AddBuff(Buff.Create(role, BuffName.Shield, _b, ShieldTypeName.NormalReduce, outBlood, 0))
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, onRoundChange)
    end,

    --> 385~392 回合开始改为技能开始 有目标问题 回合开始确定不了
    --> 每回合开始时，[a]目标[b]属性[c]改变[d]，最多叠加[e]层（不可被驱散），并额外使[f]目标，[g]属性[h]改变[i]
    [392] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        local _g = args[7]
        local _h = args[8]
        local _i = args[9]

        passivityList[385](role, {_a, _b, _c, _d, _e})

        local function onSkillCast(skill)
            if _f == 1 then
                local targets = skill:GetDirectTargets()
                for _, target in ipairs(targets) do
                    local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[_g], _i, _h)
                    target:AddBuff(buff)
                end
            elseif _f == 2 then
                local buff = Buff.Create(role, BuffName.PropertyChange, 0, BattlePropList[_g], _i, _h)
                role:AddBuff(buff)
            end
            
        end
        role.Event:AddEvent(BattleEventName.SkillCast, onSkillCast)
    end,



    --> 替补未上场，给我方职业[c]的单位[a]属性[b]改变（ 自身[e]属性[f]倍值），从第1回合开始，持续生效[d]回合，失效[g]回合，一直循环到替补上场就清除该buff
    [393] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        local _g = args[7]

        --当前是替补并且未上场
        if role:IsSubstitute() then
            if RoleManager.getTibuStateByCamp(role.camp) == 1 or RoleManager.getTibuStateByCamp(role.camp) == 3 then
                local list = RoleManager.Query(function (r) return r.camp == role.camp and r.professionId == _c end)
                for i = 1, #list do
                    local buff=Buff.Create(list[i], BuffName.PropertyChange, 0, BattlePropList[_a], role:GetRoleData(BattlePropList[_e])*_f, _b)                 
                    buff.isEveryRound = true
                    buff.cdRound = _g     
                    buff.effectRound = _d
                    buff.isEffect = true
                    list[i]:AddBuff(buff)
                end
                
                
                BattleLogic.Event:AddEvent(BattleEventName.OnAddTibuRole, function(roleData)
                    if roleData.roleId == role.roleId then
                        for i = 1, #list do
                            list[i]:RemoveBuff(function(b)
                                return b.type == BuffName.PropertyChange and b.propertyName == BattlePropList[_a]
                            end)
                        end
                    end
                end)
                
                
            end
        end

        
    end,

    --> 替补未上场，回合结束我方有目标死亡时，复活一名友军，并给目标恢复释放者[a]百分比[b]的生命值。
    [394] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local counter = 0

        local function clamp(v, minValue, maxValue)
            if v < minValue then
                return minValue
            end
                if v > maxValue then
                return maxValue
            end
            return v
        end
    
        --回合结束时
        BattleLogic.Event:AddEvent(BattleEventName.RoundEnd, function(isHave,nullNum,ReCheckRound)
            --当前是替补并且未上场
            if role:IsSubstitute() then
                if RoleManager.getTibuStateByCamp(role.camp) == 1 or RoleManager.getTibuStateByCamp(role.camp) == 3 then
                    if counter == 0 then
                        local list = RoleManager.Query(function (r) return r.camp == role.camp and r:IsRealDead() and r:IsCanRelive() end,true)
                        if #list > 0 then
                          
                            local random = Random.Range(1,#list) + 0.49  
                            local pos = clamp(floor(random),1,#list)
                            local maxHp = list[pos]:GetRoleData(RoleDataName.MaxHp)
                            local pro = floor(role:GetRoleData(BattlePropList[_a]) * _b)
                            
                            --快速复活
                            if list[pos]:IsCanRelive() then
                                list[pos].reliveHPF = math.min(pro / maxHp, 1)
                                RoleManager.AddReliveRole(list[pos])
                                counter = 1
                            end

                        end
                    end
                end
            end
        end)
    end,

    --> 替补上场时，[a]属性[b]改变[c]，持续[d]回合
    [395] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]

        local counter = 0
        --回合结束时
        BattleLogic.Event:AddEvent(BattleEventName.BattleTibuRoundEnd, function(curRound)
            --当前是替补并且上场时
            if role:IsSubstitute() then
                if counter == 0 then
                    if RoleManager.getTibuStateByCamp(role.camp) == 4 then
                        counter = 1
                        local list = RoleManager.Query(function (r) return r.camp == role.camp end)   
                        for _, r in ipairs(list) do
                            r:AddBuff(Buff.Create(role, BuffName.PropertyChange, _d, BattlePropList[_a], _c, _b))
                        end
                    end
                end
            end
        end)
    end,

    --> 受到攻击时，增加[a]点怒气，最多[b]点怒气，每1层怒气使自身[c]属性[d]类型改变[e]
    -->（a[int],b[int],c[属性],d[改变类型],e[float]）
    [396] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        -- 记录怒气层数
        local counter = 0

        local OnBeHit = function(atkRole, damage, bCrit, finalDmg, damageType)
            
            if counter + _a > _b then
                return
            end
            
            local brand = Buff.Create(role, BuffName.Brand, 0, BrandType.Angry)
            brand.layer = _a
            brand.maxLayer = _b
            brand.clear = false
            brand.startFunc = function()
                counter = counter + _a
                BattleUtil.AddProp(role, _c, _e*_a, _d)
                -- 增加属性
                 --LogError("count add:"..counter)
            end
            brand.endFunc = function ()
                -- 还原属性    
                if brand.disperse or brand.caster.isRealDamage then           
                    BattleUtil.RevertProp(role, _c, _e*counter, _d)
                    counter = 0
                    --LogError("count del:"..counter)
                end
            end
            role:AddBuff(brand)

        end
        role.Event:AddEvent(BattleEventName.RoleBeHit, OnBeHit)

    end,

      --> 释放[a]号技能时, 若目标是[b]职业, 则[c]目标的[d]属性临时[e]改变[f]
      [397] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]

        local isAdded=false
        local targets = nil
        local tempSkill = nil 

        local AddEnemyProp =function(skill)
            targets = skill:GetDirectTargets()
            if not targets or #targets == 0 then return end
            for _, target in ipairs(targets) do
                if target.professionId == _b then                 
                    BattleUtil.AddProp(target, _d, _f, _e)
                end
            end
        end

        local RevertEnemyProp=function()
            if not targets or #targets == 0 then return end
            for _, target in ipairs(targets) do
                if target.professionId == _b  and not target:IsRealDead() then                
                    BattleUtil.RevertProp(target, _d, _f, _e)
                end
            end
        end

        local CheckAdd = function(defRole) 
            local isAdd = defRole.professionId == _b
            return isAdd
        end

        local OnSkillCast = function(defRole, damageType, f, skill)
            tempSkill = skill
            if skill.ext_slot == _a then
                if _c == 1 then
                    AddEnemyProp(skill)
                    isAdded=true
                elseif _c == 2 then
                    if CheckAdd(defRole) then
                        BattleUtil.AddProp(role, _d, _f, _e)
                    end
                    isAdded=true
                elseif _c == 3 then
                    AddEnemyProp(skill)
                    if CheckAdd(defRole) then
                        BattleUtil.AddProp(role, _d, _f, _e)
                    end
                    isAdded=true
                end 
            end
        end

        role.Event:AddEvent(BattleEventName.RoleDamageBefore, OnSkillCast)

        -- 还原属性
        local OnSkillCastEnd = function(defRole, damageFunc, fixDamage)
            if isAdded then
                if _c == 1 then
                    RevertEnemyProp()
                    isAdded=false
                elseif _c == 2 then
                    if CheckAdd(defRole) then
                        BattleUtil.RevertProp(role, _d, _f, _e)
                    end
                    isAdded=false
                elseif _c == 3 then
                    RevertEnemyProp()
                    if CheckAdd(defRole) then
                        BattleUtil.RevertProp(role, _d, _f, _e)
                    end
                    isAdded=false
                end
            end
        end

        role.Event:AddEvent(BattleEventName.RoleDamageAfter, OnSkillCastEnd)
    end,

    --> 释放[a]号技能时, 若目标是[b]职业, 则有[c]概率为目标附加[d]控制状态,持续[e]回合
    [398] = function(role, args, delay)
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
                    if target.professionId == _b then
                        BattleUtil.RandomControl(_c, _d, role, target, _e)
                    end
                end

            end
        end
        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCast)
    end,
    --> 造成[a]伤害类型时，[b]概率再次释放技能，造成原技能[c]的伤害，若该技能是控制技能，则使技能最终的控制几率[d]类型改变[e](a[伤害类型],b[float],c[float],d[改变类型],e[float])
    [399] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local index = 0
        -- RoleManager.LogArgs("399",args)
        local triggerOnce = true
        local OnRoleHitDoubleHitCheck = nil
        local isConTrol=false
        local isStoped = false
        --> OnHit打击正常是会触发一次（按之前的逻辑） 加个skillcast reset 确保一下
        OnRoleHitDoubleHitCheck = function(defRole, damage, bCrit, finalDmg, damageType, skill, transType)
            BattleLogic.WaitForTrigger(delay, function ()
                if damageType ~= _a then
                    return
                end
                if not skill.isAdd or not skill then
                    return
                end

                if role.effectTrigger400 then 
                    return
                end

                if triggerOnce then
                    BattleUtil.RandomAction(_b, function ()
                        role:InsertSkill(_a, false, nil, role.skillArray[Slot2Idx(skill.ext_slot)])
                        --开始连击
                        local isInContorl = false
                        local isC = false
                        local OnSkillCastOnce = nil
                        local onSkillPassivetyPropChange = nil
                        OnSkillCastOnce = function(skill)
                            role.Event:RemoveEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                            --连击技能开始
                            isC = true

                            local OnFinalDamage = nil
                            OnFinalDamage = function(damagingFunc, defRole, damage, skill, dotType, bCrit, damageType)
                                if isC then    
                                    if damage == nil then 
                                        damage = 0
                                    end                            
                                    --连击的伤害都要减半
                                    local fDamage = floor(BattleUtil.FP_Mul(damage, _c))
                                    local rDamage = damage - fDamage
                                    -- LogError("399 rDamage:"..rDamage)
                                    if type(damagingFunc) == "table" then return end
                                    damagingFunc(rDamage)
                                    
                                    onSkillPassivetyPropChange = function(fixControl, rand, ctrl, target)
                                        --修改本次最终控制几率
                                        if isC then
                                            isConTrol = true                                    
                                            rand = BattleUtil.CountValue(rand, _e, _d)                                    
                                            fixControl(rand)
                                            index = index - 1                                        
                                            role.Event:RemoveEvent(BattleEventName.PassiveRandomFinalControl, onSkillPassivetyPropChange)
                                        end
                                    end
                                    --若该技能是控制技能，则使技能最终的控制几率[d]类型改变[e](a[伤害类型],b[float],c[float],d[改变类型],e[float]) PassiveRandomControl
                                    
                                    if not isInContorl or isConTrol then
                                        index = index + 1                                    
                                        role.Event:AddEvent(BattleEventName.PassiveRandomFinalControl, onSkillPassivetyPropChange)
                                        isInContorl = true
                                    end

                                end
                            end
                            role.Event:AddEvent(BattleEventName.FinalDamage, OnFinalDamage)


                            local OnSkillCastEndOnce = nil
                            OnSkillCastEndOnce = function(skill)
                                --连击技能完成 
                                isC = false
                                 if isStoped then 
                                        role.stop_move = true
                                        isStoped = false
                                  end

                                isInContorl=false
                                index = index - 1
                                role.Event:RemoveEvent(BattleEventName.PassiveRandomFinalControl, onSkillPassivetyPropChange)
                                role.Event:RemoveEvent(BattleEventName.FinalDamage, OnFinalDamage)
                                role.Event:RemoveEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
                                if isConTrol then 
                                    isConTrol=false                        
                                end                                                
                            end
                            role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
                
                        end
                        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                    end)
                    triggerOnce = false
                end
            end)
        end

        role.Event:AddEvent(BattleEventName.RoleHitDoubleHitCheck, OnRoleHitDoubleHitCheck)

        local OnRoleTurnEnd = function(SkillRole)
            triggerOnce = true
        end
        role.Event:AddEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEnd)
        

      -- 检测当前是否禁步状态 连击后复原
        local function resetStop()
            if role.stop_move  and not triggerOnce then
                role.stop_move = false            
                isStoped = true
            end
        end

        role.Event:AddEvent(BattleEventName.SkillCastEnd, resetStop)
    end,


    --被动检测主动技能释放连击  
    -->当使用[a]号技能时，若击杀目标，则[b]概率触发追击，以[c]%的攻击再次释放该技能，-- 最多追击触发一次 -- 优先级高于连击！！（触发时399不触发）
    [400] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        --local _d = 10   
        --RoleManager.LogArgs("400",args)
        local triggerOnce = true
        local OnRoleKillSkillPursueAttackCheck = nil
        local isStoped = false
        --> OnHit打击正常是会触发一次（按之前的逻辑） 加个skillcast reset 确保一下
        OnRoleKillSkillPursueAttackCheck = function(defRole, damage, bCrit, damageType, dotType, skill) 
            BattleLogic.WaitForTrigger(delay, function ()
                if skill == nil or defRole==nil then
                    return
                end
                --技能释放者不是被动拥有者不触发
                if skill.owner ~= nil and role.uid ~= skill.owner.uid then
                    return
                end
                if skill.ext_slot ~= _a then
                    return
                end
                if not skill.isAdd or not skill then
                    return
                end   
                if triggerOnce then
                    BattleUtil.RandomAction2(_b, function ()               

                    role:InsertSkill(_a, false, nil, role.skillArray[Slot2Idx(skill.ext_slot)])  
                     --触发效果追击标记
                     role.effectTrigger400 = true    
                    --LogError("InsertSkill ")
                        --开始连击
                        local isC = false
                        local OnSkillCastOnce = nil
                        OnSkillCastOnce = function(skill)
                            --LogError("OnSkillCastOnce  OnFinalDamage")
                            role.Event:RemoveEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                            --连击技能开始
                            isC = true                           
                            local OnFinalDamage = nil
                            OnFinalDamage = function(damagingFunc, defRole, damage, skill, dotType, bCrit, damageType)
                                --LogError("xxdamage "..damage)
                                if isC then 
                                    if damage == nil then 
                                        damage = 0
                                    end
                                    --连击的伤害都要减半
                                    local fDamage = floor(BattleUtil.FP_Mul(damage, _c))
                                    local rDamage = damage - fDamage
                                    -- LogError("400 rDamage "..rDamage)
                                    if type(damagingFunc) == "table" then return end
                                    damagingFunc(rDamage)
                                end
                            end
                            role.Event:AddEvent(BattleEventName.FinalDamage, OnFinalDamage)

                            local OnSkillCastEndOnce = nil
                            OnSkillCastEndOnce = function(skill)
                                role.effectTrigger400 = false
                                --连击技能完成 
                                isC = false
                                if not isC then
                                    if isStoped then 
                                        role.stop_move = true
                                        isStoped = false
                                    end
                                    --LogError("OnSkillCastEndOnce ")
                                    role.Event:RemoveEvent(BattleEventName.FinalDamage, OnFinalDamage)
                                    role.Event:RemoveEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
                                end       
                            end
                            role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
                        end

                        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                    end)
                triggerOnce = false
                end
            end)
        end


        role.Event:AddEvent(BattleEventName.RoleKillSkillPursueAttackCheck, OnRoleKillSkillPursueAttackCheck)

        local OnRoleTurnEnd = function(SkillRole)
            triggerOnce = true
        end
        role.Event:AddEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEnd)


        -- 检测当前是否禁步状态 连击后复原
        local function resetStop()
            if role.stop_move  and not triggerOnce then
                role.stop_move = false      
                isStoped = true
            end
        end

        role.Event:AddEvent(BattleEventName.SkillCastEnd, resetStop)
    end,

     --> 造成[a][伤害类型]时，[b]概率再次释放技能，造成原技能[c]的伤害,[d]属性临时[e]改变[f]
     [332] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
    

        local triggerOnce = true
        local OnRoleHitGeneralAttackCheck = nil
        --> OnHit打击正常是会触发一次（按之前的逻辑） 加个skillcast reset 确保一下
        OnRoleHitGeneralAttackCheck = function(defRole, damage, bCrit, finalDmg, damageType, skill, transType)
            BattleLogic.WaitForTrigger(delay, function ()
                if defRole==nil then
                return
                end
                
                if not skill.isAdd or not skill then
                    return
                end
                if triggerOnce then
                    BattleUtil.RandomAction2(_a, function ()
                        --role:InsertSkill(_a, false, nil, role.skillArray[Slot2Idx(skill.ext_slot)])
                        role:InsertSkill(SkillBaseType.Physical, false, nil, role.skillArray[Slot2Idx(0)])
                        --开始连击
                        local isC = false
                        local OnSkillCastOnce = nil
                        OnSkillCastOnce = function(skill)
                            role.Event:RemoveEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                            --连击技能开始
                            isC = true

                            local OnFinalDamage = nil
                            OnFinalDamage = function(damagingFunc, defRole, damage, skill, dotType, bCrit, damageType)
                                if isC then
                                    --连击的伤害都要减半
                                    local fDamage = floor(BattleUtil.FP_Mul(damage, _b))
                                    local rDamage = damage - fDamage
                                    damagingFunc(rDamage)
                                    damageType=_c
                                end
                            end
                            role.Event:AddEvent(BattleEventName.FinalDamage, OnFinalDamage)

                            local OnSkillCastEndOnce = nil
                            OnSkillCastEndOnce = function(skill)
                                --连击技能完成 
                                isC = false
                                role.Event:RemoveEvent(BattleEventName.FinalDamage, OnFinalDamage)
                                role.Event:RemoveEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)
                            
                            end
                            role.Event:AddEvent(BattleEventName.SkillCastEnd, OnSkillCastEndOnce)

                        
                        end
                        role.Event:AddEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                    end)
                    triggerOnce = false
                end
            end)
        end

        role.Event:AddEvent(BattleEventName.RoleHitGeneralAttackCheck, OnRoleHitGeneralAttackCheck)

        local OnRoleTurnEnd = function(SkillRole)
            triggerOnce = true
        end
        role.Event:AddEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEnd)
        
    end,

     --> 免疫控制
    --> 当自己血量低于[a]或首次被控制时，自动解除并免疫控制，同时使自己的[b]属性[c]改变[d]，持续[e]回合（每场只能触发一次）
    --> a[float] b[float] c[int]
    [403] = function(role, args)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

    --    RoleManager.LogArgs("403",args)
        local  onRoleContoleOrHit
        onRoleContoleOrHit= function()
            local list = BattleLogic.BuffMgr:GetBuff(role, function(buff)
                return buff.type == BuffName.Control
            end)
            -- LogError("triggerd list"..#list.." per "..BattleUtil.GetHPPencent(role).." 218："..role.effect218times.." ctrl:"..role.ctrltimes)
            if role.effect218times <= 0 and (BattleUtil.GetHPPencent(role) < _a or (list and #list > 0 and role.ctrltimes == 1)) then
                role.effect218times = role.effect218times + 1
               
                --LogError("triggerd")
                local ime=Buff.Create(role, BuffName.Immune, _e, 1)
                role:AddBuff(ime)
                ime.IsOnlyImmune = true
                ime:OnStart()
                ime.clear=false
                if list and #list > 0  then
                    for i=0,#list do                                                
                        BattleLogic.BuffMgr:ClearBuff(role, function (buff)  
                            if  buff == list[i] then
                                buff.clear = true
                                buff.disperse=true                           
                            end         
                            return false --代理类存在问题
                        end)
                    end
                end               
                            
                local buff = Buff.Create(role, BuffName.PropertyChange, _e, BattlePropList[_b], _d, _c)
                role:AddBuff(buff)
                buff:OnTrigger()
              
            end
        end

        role.Event:AddEvent(BattleEventName.PassiveBeRandomFinalControl, onRoleContoleOrHit) 
        role.Event:AddEvent(BattleEventName.RoleBeDamaged, onRoleContoleOrHit) 
        role.Event:AddEvent(BattleEventName.RoleDead, onRoleContoleOrHit)  
        role.Event:AddEvent(BattleEventName.BuffStart, onRoleContoleOrHit) 

        BattleLogic.Event:DispatchEvent(BattleEventName.BuffCaster, onRoleContoleOrHit)
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleTurnEnd, onRoleContoleOrHit)
    end,
    
    --> 攻击时, 若目标是[a]职业, 则[b]目标的[c]属性临时[d]改变[e]
    [405] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]

        local triggered=false
        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            if defRole.professionId == _a then
                if _b == 1 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                elseif _b == 2 then
                    BattleUtil.AddProp(role, _c, _e, _d)
                elseif _b == 3 then
                    BattleUtil.AddProp(defRole, _c, _e, _d)
                    BattleUtil.AddProp(role, _c, _e, _d)
                end
                triggered=true
            end
        end

        local onRoleHitRevert = function(damagingFunc, defRole, damage, skill, dotType, bCrit, damageType)
            if defRole.professionId == _a  and triggered then
                if _b == 1 then
                    BattleUtil.RevertProp(defRole, _c, _e, _d)
                elseif _b == 2 then
                    BattleUtil.RevertProp(role, _c, _e, _d)
                elseif _b == 3 then
                    BattleUtil.RevertProp(defRole, _c, _e, _d)
                    BattleUtil.RevertProp(role, _c, _e, _d)
                end
                triggered=false
            end
        end


        role.Event:AddEvent(BattleEventName.FinalDamage, onRoleHitRevert)

        role.Event:AddEvent(BattleEventName.RoleDamageBefore, onRoleHit)
    end,

    --> 战斗开始时, 敌方所有人[a]属性[b]改变[c], 持续[d]回合，可驱散
    [406] = function(role, args, delay)
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
                    local buff = Buff.Create(role, BuffName.PropertyChange, _d, BattlePropList[_a], _c, _b)
                    r:AddBuff(buff)
                    buff.clear = true
                end
            end
        end
        BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, _OnRoundChange)
    end,

    --> 击杀目标时, 若目标是[a]职业, 则自身恢复伤害量[b]的生命/镜像逻辑316
    [407] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]

        local OnKill = function(defRole, damage)
            if defRole.professionId == _a then
                BattleUtil.CalTreat(role, role, floor(BattleUtil.FP_Mul(damage, _b)))
            end
        end
        role.Event:AddEvent(BattleEventName.RoleKill, OnKill)
    end,

    --攻击时[a]概率驱散目标身上[b]个[c][清除状态]（a[float],b[int],c[int]）
    [408] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local onRoleHit = function(defRole, damage, bCrit, finalDmg, damageType, skill)
            BattleLogic.WaitForTrigger(delay, function ()
                BattleUtil.RandomAction2(_a, function()

                    local targetList = BattleLogic.BuffMgr:GetBuff(role, function(buff)
                        return clearBuffPredicate(buff, _c)
                    end)
                    
                    local clearT = function(t, list)
                        if list and #list > 0 then
                            local num = 0
                            if _b == 0 then --< 0所有
                                num = #list
                            else
                                num = math.min(_b, #list)
                            end

                            for i = 1, num do
                                BattleLogic.BuffMgr:ClearBuff(t, function(buff)
                                    return buff == list[i]
                                end)
                            end
                        end
                    end

                    clearT(role, targetList)
                end)
            end)
        end
        role.Event:AddEvent(BattleEventName.RoleHit, onRoleHit)
    end,

    --使用[a]号技能时，因"连接"、分摊伤害导致技能伤害目标增加，目标每额外增加1个，则自身的[b]属性临时[c]改变[d]
    --a[int],b[属性类型],c[改变类型],d[float]
    [409] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        OnRoleKill = function(defRole, damage, bCrit, damageType, dotType, skill) 
            if skill == nil or defRole == nil then
                return
            end
            if skill.ext_slot ~= _a then
                return
            end
            
        end
    end,

    --> copy
    [99999999] = function(role, args, delay)
        local _a = args[1]
        local _b = args[2]
        local _c = args[3]
        local _d = args[4]
        local _e = args[5]
        local _f = args[6]
        local _g = args[7]
        local _h = args[8]
        local _i = args[9]


    end,
    
}
return passivityList