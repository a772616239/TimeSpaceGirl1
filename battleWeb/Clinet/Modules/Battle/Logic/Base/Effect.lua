local floor = math.floor
local min = math.min
local max = math.max
--local RoleDataName = RoleDataName
--local BattleLogic = BattleLogic
--local BattleUtil = BattleUtil

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

local function Slot2Idx(slot)
    if slot == 0 then
        return 1
    elseif slot == 1 then
        return 2
    elseif slot == 3 then
        return 3
    end
end

-- 强制克制转化
local function ForceForbear(target,isForbear)
    local forceBear = isForbear 
    local changeBear = nil
    changeBear=function(atkRole,defRole,ChangeForbear)
        ChangeForbear(forceBear)
        target.Event:RemoveEvent(BattleEventName.RoleCheckForbear, changeBear) 
    end
    target.Event:AddEvent(BattleEventName.RoleCheckForbear, changeBear)
end 

local function clearBuffPredicate(buff, type)
    local flag = false
    if type == 1 then --持续恢复
        flag = buff.type == BuffName.HOT
    elseif type == 2 then --护盾
        flag = buff.type == BuffName.Shield
    elseif type == 3 then --增益状态
        flag = buff.isBuff 
    elseif type == 4 then --减益状态
        flag = buff.isDeBuff  
    elseif type == 5 then --持续伤害
        flag = buff.type == BuffName.DOT
    elseif type == 6 then --负面状态（控制状态、减益状态和持续伤害状态）
        flag = buff.type == BuffName.Control or buff.isDeBuff or buff.type == BuffName.DOT
         or (buff.type ==BuffName.Brand and buff.flag == BrandType.curse)
    end
    if flag==nil then
        flag=false
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

local function buffRandomAction(random, target, buff)

    -- 检测被动技能对技能的加成
    local rate = random
    local _ControlRatePassivitying = function(finalRate)
        rate = finalRate
    end
    buff.caster.Event:DispatchEvent(BattleEventName.SkillRandomBuff, target, buff, rate, _ControlRatePassivitying)

    -- 计算概率
    local b = Random.Range01() <= rate
    if b then
        target:AddBuff(buff)
        return true
    else
        target.Event:DispatchEvent(BattleEventName.BuffDodge, buff)
        BattleLogic.BuffMgr:PutBuff(buff)
    end
end

local function calBuffHit(caster, target, baseRandom)
    -- if caster.isTeam then --异妖不走效果命中公式
    --     return baseRandom
    -- end
    local hit = (1 + caster:GetRoleData(RoleDataName.Hit) / (1 + target:GetRoleData(RoleDataName.Dodge)))
    hit = baseRandom + caster:GetRoleData(RoleDataName.Hit)
    return baseRandom
end

--保留浮点数小数点后几位 
--floatValue 浮点值  decimalNum 保留小数几位
local function floatKeepDecimals(floatValue, keepNum)
    local result = floatValue - (floatValue % (0.1 ^ keepNum))
    return result
end

--效果表
local effectList = {
    --造成[a]%的[b]伤害
    --a[float],b[伤害类型]
    [1] = function(tarIdx, caster, target, args, interval, skill)
        local f1 = args[1]
        local dt = args[2]
        
        caster.Event:DispatchEvent(BattleEventName.RoleViewBullet, skill, target)
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.CalDamage(skill, caster, target, dt, f1)
            --caster.Event:DispatchEvent(BattleEventName.SkillTextFloating, skill)
        end)
    end,
    --[a]%概率[b]，持续[c]秒
    --a[float],b[控制状态],c[float]
    [3] = function(tarIdx, caster, target, args, interval, skill)
        local f1 =  args[1]
        local cb1 = args[2]
        local f2 = args[3]
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomControl(f1, cb1, caster, target, f2) 
        end)
    end,
    --[d]改变[a]属性[b]%,持续[c]秒
    --a[属性],b[float],c[int],d[改变类型]
    [4] = function(tarIdx, caster, target, args, interval, skill)
        local pro1 = args[1]
        local f1 = args[2]
        local f2 = args[3]
        local ct = args[4]
        BattleLogic.WaitForTrigger(interval, function ()
            local buff = Buff.Create(caster, BuffName.PropertyChange, f2, BattlePropList[pro1], f1, ct)
            if f2 == 0 then
                buff.cover = true
            end
            target:AddBuff(buff)
        end)
    end,
    --造成[a]%的[b]伤害，自身恢复造成伤害[c]%的生命
    --a[float],b[伤害类型],c[float]
    [10] = function(tarIdx, caster, target, args, interval, skill)
        local f1 = args[1]
        local dt = args[2]
        local f2 = args[3]
        caster.Event:DispatchEvent(BattleEventName.RoleViewBullet, skill, target)
        BattleLogic.WaitForTrigger(interval, function ()
            local finalDmg, bCrit, dmg = BattleUtil.CalDamage(skill, caster, target, dt, f1)
            if finalDmg ~= 0 then --< 是否命中
                BattleUtil.CalTreat(caster, caster, floor(dmg * f2))
            end
        end)
    end,
    --瞬间恢复[a]*[b]%生命
    --a[属性],b[float]
    [24] = function(tarIdx, caster, target, args, interval, skill)
        local pro1 = args[1]
        local f1 = args[2]
        BattleLogic.WaitForTrigger(interval / SkillEffectFirstPropty.First, function ()
            local val = floor(BattleUtil.FP_Mul(caster:GetRoleData(BattlePropList[pro1]), f1))
            BattleUtil.CalTreat(caster, target, val)
            --LogError(interval / SkillEffectFirstPropty.First.."SkillEffectFirstPropty.First is "..SkillEffectFirstPropty.First)
        end)
    end,
    
    --> 把目标增益换成负面buff
    --> [a]概率把目标一个增益变成[b]持续伤害状态, 每回合损失施法者[c]属性[d]的生命,持续[e]回合, 该效果可叠加
    [201] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                local list = BattleLogic.BuffMgr:GetBuff(target, function(buff)
                    return clearBuffPredicate(buff,3)
                end)
                --LogError("121："..#list)
                if list and #list > 0 then
                    BattleLogManager.Log(
                        "201 list",
                        "list:",#list
                    )
                    local delBuff = Random.RangeInt(1, #list)
                    --LogError("111")
                    BattleLogManager.Log(
                        "201 delBuff",
                        "delBuff:",delBuff
                    )

                    BattleLogic.BuffMgr:ClearBuff(target, function(buff)
                        if buff == list[delBuff] then
                            local damage =math.floor(caster:GetRoleData(BattlePropList[c])*d)
                            local dot = Buff.Create(caster, BuffName.DOT, e, 1, b,damage)
                            dot.damageFactor=1
                            --LogError(" 1:"..dot.damageType.." 2:"..dot.damagePro.." 3:"..dot.damageFactor)
                            dot.isRealDamage = true
                            target:AddBuff(dot)
                        end
                        return buff == list[delBuff]
                    end)


                end 
            end)
        end)
    end,

    --> 临时提升某属性
    --> 造成[a]%的[b]伤害，[c]%概率本次攻击[d]属性[e]改变[f]%
    --> a[float] b[伤害类型] c[float] d[属性] e[改变类型] f[float]
    [202] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(c, function()
                BattleUtil.AddProp(caster, BattlePropList[d], f, e)
                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()
                    if not caster:IsRealDead() then
                        BattleUtil.RevertProp(caster, BattlePropList[d], f, e)
                    end
                end)
            end)
            BattleUtil.CalDamage(skill, caster, target, b, a)
        end)
    end,

    --> 南蛮入侵
    --> 造成[a]%的[b]伤害，[c]%概率对血量百分比最低的目标伤害提升[d]%，[e]%概率对血量百分比最高的目标附加[f]控制状态[g]回合
    --> a[float] b[伤害类型] c[float] d[float] e[float] f[控制状态] g[int]
    [203] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        local g = args[7]
        BattleLogic.WaitForTrigger(interval, function ()
            local isTrigger = BattleUtil.RandomAction(c, function()
                local arr = BattleUtil.ChooseTarget(caster, 100210)
                if arr[1] and arr[1] == target then
                    local OnPassiveDamaging = function(damagingFunc, defRole, damage)
                        damagingFunc(-floor(BattleUtil.FP_Mul(d, damage)))
                    end
                    caster.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
                    BattleUtil.CalDamage(skill, caster, target, b, a)
                    caster.Event:RemoveEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
                end
            end)      
            if not isTrigger then
                BattleUtil.CalDamage(skill, caster, target, b, a)
            end
            local arr = BattleUtil.ChooseTarget(caster, 100220)
            if arr[1] and arr[1] == target then
                BattleUtil.RandomControl(e, f, caster, target, g)
            end 
        end)
    end,

    --> 加状态，按职业提高概率
    --> [a]%概率对目标附加[b]状态[c]回合；对[d]职业和[e]职业概率提高[f]%
    --> a[float] b[控制状态] c[int] d[职业] e[职业] f[float]
    [205] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        BattleLogic.WaitForTrigger(interval, function ()
            local rand = a
            if target.roleData.professionId == d or target.roleData.professionId == e then
                rand = a*(1+f)
            end
            BattleUtil.RandomControl(rand, b, caster, target, c)
        end)
    end,

    --> 加状态，减速提高概率
    --> [a]%概率对目标附加[b]状态[c]回合；若目标有“减速”状态，则概率提高[d]%
    --> a[float] b[控制状态] c[int] d[float]
    [206] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        BattleLogic.WaitForTrigger(interval, function ()
            local rand = a

            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.PropertyChange, function(buff)
                return buff.propertyChangeType == PropertyChangeType.ReduceSpeed
            end)
            if isHave then
                rand = a*(1+d)
            end
            BattleUtil.RandomControl(rand, b, caster, target, c)
        end)
    end,
    
    --> 加状态，诅咒提高概率
    --> [a]%概率对目标附加[b]状态[c]回合；若目标有“诅咒”状态，则概率乘算[d]%
    --> a[float] b[控制状态] c[int] d[float]
    [207] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        BattleLogic.WaitForTrigger(interval, function ()
            local rand = a
            if BattleLogic.BuffMgr:HasBuff(target, BuffName.Brand,function(buff)
                return buff.flag == BrandType.curse
            end) then
                -- LogError(" curse ")
                rand = a*d
            end
            BattleUtil.RandomControl(rand, b, caster, target, c)
        end)
    end,

    --> 驱散
    --> [a]%概率驱散[b]目标/自己[c]个[d]清除状态
    --> a[float] b[1目标/2自己/3目标和自己] c[int] d清除状态
    [208] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                -- RoleManager.LogArgs("208",args)
                local targetList = BattleLogic.BuffMgr:GetBuff(target, function(buff)
                    return clearBuffPredicate(buff, d) 
                end)
                local casterList = BattleLogic.BuffMgr:GetBuff(caster, function(buff)
                    return clearBuffPredicate(buff, d)
                end)
                
                -- LogError(target.roleId.."targetList:"..#targetList)
                -- LogError("casterList:"..#casterList)
                local clearT = function(t, list)
                    if list and #list > 0 then
                        local num = 0
                        if c == 0 then --< 0所有
                            num = #list
                        else
                            num = math.min(c, #list)
                        end
                        -- LogError("num:"..num) 
                        local count = 0
                        BattleLogic.BuffMgr:ClearBuff(t, function(buff) 
                            if c == 0 then
                                -- LogError("clear all")
                                return clearBuffPredicate(buff, d)                               
                            end

                            if clearBuffPredicate(buff, d) and count < num then
                                -- LogError("clear one")
                                count= count + 1
                                return true
                            else
                                return false
                            end                                                           
                        end)                       
                    end
                end
                if b == 1 then
                    clearT(target, targetList)
                elseif b == 2 then
                    if tarIdx == 1 then
                        clearT(caster, casterList)
                    end
                end
            end)
        end)
    end,

    --> 驱散并伤害
    --> [a]概率驱散目标[b]个增益状态，每驱散1个增益状态，额外造成等同目标属性[c][d]的伤害，最高不超过施法者[e]属性的[f]倍
    --> a[float] b[int] c[属性] d[float]
    [209] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1] --0.6
        local b = args[2] --0
        local c = args[3] --12
        local d = args[4] --0.05
        local e = args[5]
        local f = args[6]
        --RoleManager.LogArgs("209",args)
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                local targetList = BattleLogic.BuffMgr:GetBuff(target, function(buff)
                    return clearBuffPredicate(buff,3)
                end)
                local clearT = function(t, list)
                    if list and #list > 0 then
                        if b==0 then b = 10000 end
                        local num = math.min(b, #list)
                        
                        for i = 1, num do
                            BattleLogic.BuffMgr:ClearBuff(t, function(buff)
                                --LogError("209 i:"..i)
                                return clearBuffPredicate(buff,3)
                            end)
                            local damage = target:GetRoleData(BattlePropList[c])*d
                            local max = caster:GetRoleData(BattlePropList[e])*f
                            if damage >= max then
                                --LogError("209 bef:"..damage.."after "..max)
                                damage = max
                            end 
                            damage = math.floor(damage)
                            --LogError("damage:"..damage)
                            BattleUtil.ApplyDamage(skill, caster, target, damage)
                        end
                    end
                end
                clearT(target, targetList)
            end)
        end)
    end,

    --> 传染
    --> [a]%概率让目标的[b]状态传播到敌方一个未受该状态的单位
    --> a[float] b[持续伤害状态]
    [210] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        BattleLogic.WaitForTrigger(interval, function ()
            local bufflist = BattleLogic.BuffMgr:GetBuff(target, function(buff)
                return buff.type == BuffName.DOT and buff.damageType == b
            end)
            
           -- local checkBuffFunc = function(buff)
           --     LogError("buffid1: "..buff.target.roleId.." target:"..target.roleId)
           --     return buff.type == BuffName.DOT and  buff.damageType == b
           -- end
            
            if bufflist and #bufflist > 0 then
                BattleUtil.RandomAction(a, function()
                    local arr = RoleManager.Query(function (r) return r.camp ~= caster.camp end)
                    for k, v in ipairs(arr) do

                        if not BattleLogic.BuffMgr:HasBuff(v, BuffName.DOT, function(buff) return buff.damageType == b end) and not v.isBeInfect then

                            local buff = Buff.Create(caster, BuffName.DOT, bufflist[1].duration, 1, b, bufflist[1].damagePro, bufflist[1].damageFactor)
                            buff.isRealDamage = true
                            buff.isBeInfect = true
                            v:AddBuff(buff)
                            v.isBeInfect = true
                            break
                            
                        end
                        
                    end
                end)
                
            end
        end)
    end,

    --> 改变属性
    --> [a]%概率使[b]目标/自己的属性[c][d]改变[e]%[f]回合
    --> a[float] b[1目标/2自己/3目标和自己] c[属性] d[改变类型] e[float] f[int]
    [211] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
       -- RoleManagar.LogArgs("211",args)
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()  
                local changeProperty = function(_role)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, f, BattlePropList[c], e, d)
                    _role:AddBuff(buff)
                    end
                if b == 1 then
                    changeProperty(target)
                elseif b == 2 then
                    if tarIdx == 1 then
                        changeProperty(caster)
                    end
                end
            end)
        end)
    end,

    --> 改变双属性
    --> [a]%概率使[b]目标的属性[c][d]改变[e]%，属性[f][g]改变[h]%,储蓄[i]回合
    --> a[float] b[目标类型] c[属性] d[改变类型] e[float] f[属性] g[改变类型] h[float] i[int]
    [212] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        local g = args[7]
        local h = args[8]
        local i = args[9]
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                local changeProperty = function(_role, _a, _b, _c, _d)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, _a, BattlePropList[_b], _c, _d)
                    _role:AddBuff(buff)
                end

                --> 区分目标  caster target   ..   caster target    ..  caster target
                if b == 1 then
                    changeProperty(target, i, c, e, d)
                    changeProperty(target, i, f, h, g)
                elseif b == 2 then
                    if tarIdx == 1 then
                        changeProperty(caster, i, c, e, d)
                        changeProperty(caster, i, f, h, g)
                    end
                end
            end)
        end)
    end,

    --> 护盾，可变数值
    --> [a]%概率为目标附加护盾[b]回合，护盾值等同于自己属性[c][d]%
    --> a[float] b[int] c[属性] d[float]
    [213] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()  
                local val = floor(BattleUtil.FP_Mul(caster:GetRoleData(BattlePropList[c]), d))
                local shield = Buff.Create(caster, BuffName.Shield, b, ShieldTypeName.NormalReduce, val, 0)
                target:AddBuff(shield)
            end)
        end)
    end,

    --> 特殊状态：仁心
    --> [a]概率为目标附加烙印[l]"仁心"[b]回合，效果:[c]属性[d]改变[e],[f]属性[g]改变[h]. 若己方在仁心状态下死亡，则自己[i]属性[j]改变[k]，直至战斗结束
    --> a[float] b[int] c[属性] d[改变类型] e[float] f[属性] g[改变类型] h[float] i[属性] j[改变类型] k[float] l[int]
    [214] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        local g = args[7]
        local h = args[8]
        local i = args[9]
        local j = args[10]
        local k = args[11]
        local l = args[12]
        -- RoleManager.LogArgs("214",args)
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()  
                local changeProperty = function(_role, _a, _b, _c, _d)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, _a, BattlePropList[_b], _c, _d)
                    _role:AddBuff(buff)                    
                end


                changeProperty(target, b, c, e, d)
                changeProperty(target, b, f, h, g)


                local OnRoleRealDead = function(deadRole)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, 0, BattlePropList[i], k, j)
                    caster:AddBuff(buff)                        
                end
                
                local brand = Buff.Create(caster, BuffName.Brand, b, l, function ()                   
                end)
                
                target:AddBuff(brand)

                brand.startFunc=function()
                    target.Event:AddEvent(BattleEventName.RoleRealDead, OnRoleRealDead)
                end

                brand.endFunc=function()
                    BattleLogic.WaitForTrigger(interval, function ()
                        target.Event:RemoveEvent(BattleEventName.RoleRealDead, OnRoleRealDead)
                    end)
                end

            end)
        end)
    end,

    --> 光环
    --> 自己在场情况下己方所有[a]阵营武将的[b]属性[c]改变[d]
    --> a[阵营] b[属性] c[改变方式] d[float]
    [215] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        BattleLogic.WaitForTrigger(interval, function ()

            if tarIdx == 1 then
                local list = RoleManager.Query(function (r) return r.camp == caster.camp end)
                for _k, _v in ipairs(list) do
                    if not _v:IsRealDead() then
                        if _v.roleData.element == a then
                            local changeProperty = function(_role, _a, _b, _c, _d)
                                local buff = Buff.Create(caster, BuffName.PropertyChange, _a, BattlePropList[_b], _c, _d)
                                _role:AddBuff(buff)
            
                                local OnRoleRealDead = nil
                                OnRoleRealDead = function(deadRole)
                                    caster.Event:RemoveEvent(BattleEventName.RoleRealDead, OnRoleRealDead)
                                    BattleLogic.BuffMgr:ClearBuff(_role, function (_buff)
                                        return _buff == buff
                                    end)
                                end
                                caster.Event:AddEvent(BattleEventName.RoleRealDead, OnRoleRealDead)
            
            
                                local onBuffCover = nil
                                onBuffCover = function(buff)
                                    if buff.type == BuffName.Brand and buff.flag == "hit_halo" then
                                        caster.Event:RemoveEvent(BattleEventName.RoleRealDead, OnRoleRealDead)
                                        BattleLogic.BuffMgr:ClearBuff(_role, function (_buff)
                                            return _buff == buff
                                        end)
                                    end
                                end
                                _role.Event:AddEvent(BattleEventName.BuffCover, onBuffCover)
            
                                local brand = Buff.Create(caster, BuffName.Brand, 0, "hit_halo", function ()
                                    _role.Event:RemoveEvent(BattleEventName.BuffCover, onBuffCover)
                                end)
                                _role:AddBuff(brand)
            
                            end
                            changeProperty(_v, 0, b, c, d)
                        end
                    end
                end
            end
            
        end)
    end,

    --> 被此技能击杀的武将无法以任何方式复活
    [216] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]

        local skillkill 
        skillkill= function(defRole, damage, bCrit, damageType, dotType, _skill)
            if _skill == skill then
                -- LogError("216 SetOutBattle")
                defRole:SetOutBattle()
            end
        end
        caster.Event:AddEvent(BattleEventName.RoleKill,skillkill)

        local seckkill
        seckkill = function(defRole,_skill)
            -- LogError("seckkill 216 !!!")
            if _skill == skill then
                -- LogError("seckkill 216 SetOutBattle")
                defRole:SetOutBattle()
            end
        end
        caster.Event:AddEvent(BattleEventName.Seckill,seckkill)

        BattleLogic.WaitForTrigger(interval, function ()

            local skillkillReset
            skillkillReset = function()
                -- LogError("reset 216")
                caster.Event:RemoveEvent(BattleEventName.Seckill,seckkill)
                caster.Event:RemoveEvent(BattleEventName.RoleKill,skillkill)
                caster.Event:RemoveEvent(BattleEventName.RoleTurnEnd,skillkillReset)
            end
            
            caster.Event:AddEvent(BattleEventName.RoleTurnEnd,skillkillReset)

        end)
    end,

    --> 免疫控制
    --> 当自己血量低于[a]%或首次被控制时候时，自动解除并免疫控制，伤害提高[b]%，持续[c]回合（每场只能触发一次）
    --> a[float] b[float] c[int]
    [218] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        
        BattleLogic.WaitForTrigger(interval, function ()
            local list = BattleLogic.BuffMgr:GetBuff(caster, function(buff)
                return buff.type == BuffName.Control
            end)

            if caster.effect218times <= 0 and (BattleUtil.GetHPPencent(caster) < a or (list and #list > 0 and caster.ctrltimes == 1)) then
                caster.effect218times = caster.effect218times + 1
                if list and #list > 0 then
                    BattleLogic.BuffMgr:ClearBuff(caster, function (buff)
                        return buff.type == BuffName.Control
                    end)
                end

                caster:AddBuff(Buff.Create(caster, BuffName.Immune, 0, 1))

                local OnPassiveDamaging = function(damagingFunc, defRole, damage)
                    damagingFunc(-floor(b * damage))
                end
                caster.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
                local brand = Buff.Create(caster, BuffName.Brand, c, "damageup", function ()
                    caster.Event:RemoveEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
                end)
                caster:AddBuff(brand)
            end
        end)
    end,

    --> 二选一
    --> 二选一：造成[a]%的[b]伤害，[c]%概率附加[d]持续伤害状态[e]回合；或者造成[f]%的[g]伤害，恢复等同攻击[h]%的生命
    --> 二选一：造成[a]的[b]伤害，[c]概率附加[d]持续伤害状态[e]回合，每回合造成施法者[i]属性[j]%的伤害；或者造成[f]的[g]伤害，恢复等同攻击[h]的生命
    --> a[float] b[伤害类型] c[float] d[持续伤害状态] e[int] f[float] g[伤害类型] h[float]
    [219] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        local g = args[7]
        local h = args[8]
        local i = args[9]
        local j = args[10]
        
        BattleLogic.WaitForTrigger(interval, function ()            
                if caster.movementRandom01 <= 0.5 then
                    BattleUtil.CalDamage(skill, caster, target, b, a)

                    if skill and skill:CheckTargetIsHit(target) then
                        local damage = floor(caster:GetRoleData(BattlePropList[i]) * j)
                        BattleUtil.RandomDot(c, d, caster, target, e, 1, damage, function(buff)
                            buff.isRealDamage = true
                        end)
                    end
                    --[[
                        BattleUtil.RandomAction(c, function()
                        local damage = floor(caster:GetRoleData(BattlePropList[i]) * j)
                        local buff = Buff.Create(caster, BuffName.DOT, e, 1, d, damage)
                        buff.isRealDamage = true
                        target:AddBuff(buff)
                    end)
                    ]]
                else
                    BattleUtil.CalDamage(skill, caster, target, g, f)
                    if tarIdx == 1 then -- 仅生效一次
                        BattleUtil.CalTreat(caster, caster, floor(caster:GetRoleData(RoleDataName.Attack) * h))
                    end  
                end                     
        end)
    end,

    --> 守护目标分担伤害
    --> 分摊目标所受伤害的[a]%，持续[b]回合
    --> 获得烙印[c]，分摊目标所受伤害的[a]，持续[b]回合
    --> a[float] b[int]
    [220] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        
        if caster ~= target then
            BattleLogic.WaitForTrigger(interval, function ()
                local OnTriggerBeDamaging = function(damagingFunc, atkRole, damage,skill)
                    if not target:IsDead() then
                        damagingFunc(floor(damage * a))
                        -- LogError(caster.roleId.."分摊"..target.roleId..":"..floor(damage * a))
                        BattleUtil.ApplyDamage(skill, atkRole, caster, floor(damage * a), nil, nil, nil , false)
                    end
                end
    
                target.Event:AddEvent(BattleEventName.TriggerBeDamaging, OnTriggerBeDamaging)
                local brand = Buff.Create(caster, BuffName.Brand, b, c, function ()
                    target.Event:RemoveEvent(BattleEventName.TriggerBeDamaging, OnTriggerBeDamaging)
                end)
                target:AddBuff(brand)
            end)
        end
    end,

    --> 复活 回血
    --> 复活目标,并恢复相当于[a]属性[b]的生命,若无人死亡,则为己方血量最低的己方武将恢复相当于[c]属性[d]的生命
    --> a[float] b[目标类型] c[属性] d[float]
    [221] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        BattleLogic.WaitForTrigger(interval, function ()
            --> 针对不同目标特殊判断    死亡复活  不是死亡的回血
            if target:IsRealDead() then
                local maxHp = target:GetRoleData(RoleDataName.MaxHp)
                local pro = floor(caster:GetRoleData(BattlePropList[a]) * b)
                target:SetRelive(math.min(1 / maxHp, 1))
                --RoleRelive
                local reliveHp
                reliveHp = function ()
                    BattleUtil.CalTreat(caster, target,floor(caster:GetRoleData(BattlePropList[a]) * b))
                    target.Event:RemoveEvent(BattleEventName.RoleRelive, reliveHp)
                end
                target.Event:AddEvent(BattleEventName.RoleRelive, reliveHp)
            --》对象无法复活
            --elseif not target:IsCanRelive() then
               -- BattleUtil.CalTreat(caster, caster, floor(caster:GetRoleData(BattlePropList[c]) * d))
            else
                BattleUtil.CalTreat(caster, target, floor(caster:GetRoleData(BattlePropList[c]) * d))
            end

        end)
    end,

    --> 怒气换追加
    --> 每[a]层怒气增加[b]次攻击（最多[c]次，共[d]段），额外攻击会对目标以外随机[e]个武将造成相同系数的一次伤害，怒气在攻击后归零
    --> a[int] b[int] c[int] d[int] e[int]
    [222] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        
        BattleLogic.WaitForTrigger(interval, function ()
            local bufflist = BattleLogic.BuffMgr:GetBuff(caster, function(buff)
                return buff.type == BuffName.Brand and buff.flag == 4
            end)

            if bufflist and #bufflist > 0 then
                local attTimes = math.min(floor(bufflist[1].layer / a) * b, c)
                
                
                for i = 1, attTimes do
                    caster:InsertSkill(SkillBaseType.Physical, false, {[1] = {target}}, caster.skillArray[Slot2Idx(skill.ext_slot)])
                end
                if attTimes > 0 then
                    BattleLogic.BuffMgr:ClearBuff(caster, function(buff)
                        return buff.type == BuffName.Brand and buff.flag == 4
                    end)
                end
            end
            
        end)
    end,

    --> 按上场卡牌改属性
    --> 每个在场的[a]阵营武将使自己的属性[b][c]改变[d]
    --> a[阵营] b[属性] c[改变类型] d[float]
    [223] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        --RoleManager.LogArgs("223",args)
        BattleLogic.WaitForTrigger(interval, function ()
            if tarIdx == 1 then
                
                local list = RoleManager.Query(function (r) return r.camp == caster.camp end)
                local changeProperty = function(_role, _a, _b, _c, _d)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, _a, BattlePropList[_b], _d, _c)
                    _role:AddBuff(buff)
                end
                for k, _v in ipairs(list) do
                    if _v.roleData.element == a then
                        changeProperty(_v, 0, b, c, d)
                    end
                end
            end
            
        end)
    end,

    --> 按目标状态提升伤害
    --> 目标每携带[a]个负面状态，技能伤害提高[b]%
    --> a[int] b[float]
    [224] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]

        
        BattleLogic.WaitForTrigger(interval, function ()
            local bufflist = BattleLogic.BuffMgr:GetBuff(target, function(buff)
                return buff.type == BuffName.DOT or buff.type == BuffName.Control or buff.isDeBuff
            end)
            if bufflist and #bufflist > 0 then
                local num = floor(#bufflist / a)

                local OnPassiveDamaging = function(damagingFunc, defRole, damage)
                    local _a = damage
                    for _i = 1, num do
                        _a = _a + BattleUtil.FP_Mul(_a, b)
                    end
                    local finaladd = max(_a - damage, 0)

                    damagingFunc(-floor(finaladd))
                end
                target.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)

                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                    target.Event:RemoveEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
                end)
                

            end
        end)
    end,

    --> 击杀追加
    --> 若击杀目标，[a]概率触发追击，追击有[b]攻击，最多追击[c]次
    --> a[float] b[float] c[int]
    [225] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
     
        BattleLogic.WaitForTrigger(interval, function ()
            if not skill.isAdd then
                return
            end

            local triggerOnce = true
            --> 延时触发死亡判定
            BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                if target:IsDead() then
                    if triggerOnce then
                        BattleUtil.RandomAction(a, function()
                            for i = 1, c do
                                caster:InsertSkill(SkillBaseType.Physical, false, nil, caster.skillArray[Slot2Idx(skill.ext_slot)])
                            end


                            local isC = false
                            local OnSkillCastOnce = function(skill)
                                isC = true
                                BattleUtil.AddProp(caster, RoleDataName.Attack, 1-b, 4)
                            end
                            caster.Event:AddEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                            local OnRoleTurnEnd = nil
                            OnRoleTurnEnd = function(skill)
                                isC = false
                                caster.Event:RemoveEvent(BattleEventName.SkillCast, OnSkillCastOnce)
                                caster.Event:RemoveEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEnd)
                                BattleUtil.RevertProp(caster, RoleDataName.Attack, 1-b, 4)
                            end
                            caster.Event:AddEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEnd)
    
                        end)
                        triggerOnce = false
                    end
                end
            end)

            local OnRoleTurnEndB = nil
            OnRoleTurnEndB = function(SkillRole)
                triggerOnce = true
                caster.Event:RemoveEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEndB)
            end
            caster.Event:AddEvent(BattleEventName.RoleTurnEnd, OnRoleTurnEndB)
        end)
    end,

    --> 击杀回血
    --> 若击杀目标，则恢复等同自身[a]属性的[b]的生命
    --> a[属性] b[float]
    [226] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
     
        BattleLogic.WaitForTrigger(interval, function ()
            --> 延时触发死亡判定
            BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                if target:IsDead() then
                    BattleUtil.CalTreat(caster, caster, floor(caster:GetRoleData(BattlePropList[a]) * b))
                end
            end)
        end)
    end,

    --> 复活失败换成加血
    --> 若己方无死亡武将，则为生命最低的己方武将恢复等同属性[a][b]%的生命
    --> a[属性] b[float]
    [227] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
     
        BattleLogic.WaitForTrigger(interval, function ()
            local deadlist = RoleManager.QueryDead(function (r) return r.camp == caster.camp end)
            if deadlist and #deadlist <= 0 then
                local list = RoleManager.Query(function (r) return r.camp == caster.camp end)
                local minhp = nil
                local _r = nil
                for _k, _v in ipairs(list) do
                    if not minhp then
                        minhp = _v:GetRoleData(RoleDataName.Hp)
                    end
                    if _v:GetRoleData(RoleDataName.Hp) < minhp then
                        minhp = _v:GetRoleData(RoleDataName.Hp)
                        _r = _v
                    end
                    if _r then
                        BattleUtil.CalTreat(caster, _r, floor(_r:GetRoleData(BattlePropList[a]) * b))
                    end
                end
            end
        end)
    end,

    --> 比属性吸血
    --> 若目标属性[a]低于自己，则按[b]%伤害量吸血
    --> a[属性] b[float]
    [228] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
     
        BattleLogic.WaitForTrigger(interval, function ()
            if target:GetRoleData(BattlePropList[a]) < caster:GetRoleData(BattlePropList[a]) then
                local OnPassiveDamaging = function(damagingFunc, atkRole, damage)
                    if not target:IsDead() then
                        BattleUtil.CalTreat(caster, caster, floor(damage * b))
                    end
                end
    
                target.Event:AddEvent(BattleEventName.PassiveBeDamaging, OnPassiveDamaging)
                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                    target.Event:RemoveEvent(BattleEventName.PassiveBeDamaging, OnPassiveDamaging)
                end)
            end   
        end)
    end,

    --> 比属性临时改属性
    --> 若目标属性[a]低于自己，则[b]目标类型的[c]属性[d]改变[e]%
    --> a[属性] b[float] c[目标类型] d[属性] e[改变方式] f[float]
    [229] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        
        local _change = false

        -- BattleLogic.WaitForTrigger(interval, function ()
            -- LogError("229  1")
            if target:GetRoleData(BattlePropList[a]) < caster:GetRoleData(BattlePropList[a]) then
                local _revert = nil
                _revert = function()
                    if _change  then
                        if not caster:IsRealDead() then
                            BattleUtil.RevertProp(caster, c, e, d)
                            --LogError("229  2")
                            _change = false

                            caster.Event:RemoveEvent(BattleEventName.RoleDamageAfter, _revert)
                        end      
                    end             
                end    
                
                local changeProperty = function(_role, _a, _b, _c, _d)
                    -- LogError("229  3")
                    BattleUtil.AddProp(_role, _b, _c, _d)
                    _change = true
                    -- BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()
                    --     if not _role:IsRealDead() then
                    --         BattleUtil.RevertProp(_role, BattlePropList[_b], _c, _d)
                    --     end
                    -- end)
                end

                if b == 1 then
                    --LogError("229  4 1")
                    changeProperty(target, 0, c, e, d)
                elseif b == 2 then
                    if tarIdx == 1 then
                        --LogError("229  4 2")
                        changeProperty(caster, 0, c, e, d)
                    end
                end
                caster.Event:AddEvent(BattleEventName.RoleDamageAfter, _revert)  --造成伤害后就还原 下次重新触发
            end

        -- end)
    end,

    --> 有属性状态加控制状态
    --> 若目标有[a]属性状态，则[b]%概率给目标附加[c]控制状态[d]回合
    --> a[属性状态] b[float] c[控制状态] d[int]
    [230] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4] 

     
        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.PropertyChange, function(buff)
                return buff.propertyChangeType == a
            end)
            if isHave then
                BattleUtil.RandomControl(b, c, caster, target, d)
            end
        end)
    end,

    --> 无属性状态加控制状态
    --> 若目标没有[a]属性状态，则[b]%概率附加[c]控制状态[d]回合
    --> a[属性状态] b[float] c[控制状态] d[int]
    [231] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4] 

     
        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.PropertyChange, function(buff)
                return buff.propertyChangeType == a
            end)
            if not isHave then
                BattleUtil.RandomControl(b, c, caster, target, d)
            end
        end)
    end,

    --> 少血量临时改属性
    --> 若[a]目标类型的血量低于[b]%，则本次攻击[c]目标类型的[d]属性[e]改变[f]%
    --> a[目标类型] b[float] c[目标类型] d[属性] e[改变类型] f[float]
    [232] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]

        local isAdded=false
        BattleLogic.WaitForTrigger(interval, function ()
            --RoleManager.LogArgs("232",args)
            local hpPer = 0
            if a == 1 then   --< 此处目标类型应该只能为1 2
                hpPer = target:GetRoleData(RoleDataName.Hp) / target:GetRoleData(RoleDataName.MaxHp)
            elseif a == 2 then
                hpPer = caster:GetRoleData(RoleDataName.Hp) / caster:GetRoleData(RoleDataName.MaxHp)
            end
            if hpPer < b then
                local changeProperty = function(_role, _a, _b, _c, _d)                  
                    BattleUtil.AddProp(_role, _b, _c, _d)
                     
                    isAdded = true
                    -- 本次攻击结束还原
                    local _revert = function ()    
                        if isAdded then                                            
                            if not _role:IsRealDead() then                               
                                BattleUtil.RevertProp(_role, _b, _c, _d)
                                isAdded = false  
                                 
                            end
                        end
                    end
                    caster.Event:AddEvent(BattleEventName.RoleTurnEnd, _revert)
                end
                if c == 1 then
                    changeProperty(target, 0, d, f, e)
                elseif c == 2 then
                    if tarIdx == 1 then
                        changeProperty(caster, 0, d, f, e)
                    end
                end
            end
        end)
    end,

    --> 高血量目标忽视防御
    --> 若目标生命高于[a]%，则本次攻击忽视目标[b]%防御
    --> a[float] b[float]
    [233] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
     
        BattleLogic.WaitForTrigger(interval, function ()
            if target:GetRoleData(RoleDataName.Hp) / target:GetRoleData(RoleDataName.MaxHp) < a then
                local onIgnoreDefFactor = function(ignoreDefFactorFunc, atkRole, defRole)
                    if not target:IsDead() then
                        ignoreDefFactorFunc(b)
                    end
                end
    
                target.Event:AddEvent(BattleEventName.BeIgnoreDefFactor, onIgnoreDefFactor)
                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                    target.Event:RemoveEvent(BattleEventName.BeIgnoreDefFactor, onIgnoreDefFactor)
                end)
            end
        end)
    end,

    --> 按职业加控制状态
    --> 若目标是[a]职业，[b]%概率附加[c]控制状态[d]回合
    --> a[职业] b[float] c[控制状态] d[int]
    [234] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
     
        BattleLogic.WaitForTrigger(interval, function ()
            if target.roleData.professionId == a then
                BattleUtil.RandomControl(b, c, caster, target, d)
            end
        end)
    end,

    --> 按职业临时改属性
    --> 若目标是[a]职业，则本次攻击属性[b][c]改变[d]% , 每个目标单独计算
    --> a[职业] b[属性] c[改变类型] d[float]
    [235] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
     
        local PropRevetFunc = nil
        local PropAddFunc= nil

        PropRevetFunc = function(atkRole, damage, bCrit, finalDmg, damageType, dotType, skill, isForbear,defRole)
            --LogError("damage 3 "..atkRole.roleId)
            BattleUtil.RevertProp(caster, b, d, c)
            defRole.Event:RemoveEvent(BattleEventName.RoleBeDamaged, PropRevetFunc)
        end
        
        PropAddFunc = function(atkRole, factorFunc, damageType, skill,baseFactor,defRole) 
                --LogError("damage 2 "..defRole.roleId)
                BattleUtil.AddProp(caster, b, d, c)
                defRole.Event:AddEvent(BattleEventName.RoleBeDamaged, PropRevetFunc)          
        end       

        BattleLogic.WaitForTrigger(interval, function ()

            
            if target.roleData.professionId == a then
                --LogError("damage 1 "..target.roleId)
                target.Event:AddEvent(BattleEventName.RoleBeDamagedBefore, PropAddFunc)  
                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()
                    if not caster:IsRealDead() then
                        --LogError("damage 5 "..target.roleId)
                        target.Event:RemoveEvent(BattleEventName.RoleBeDamagedBefore, PropAddFunc)
                    end
                end)
            end
        end)
    end,

    --> 按职业改属性
    --> 若目标是[a]职业，则属性[b][c]改变[d]%[e]回合
    --> a[职业] b[属性] c[改变类型] d[float] e[int]
    [236] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
     
        BattleLogic.WaitForTrigger(interval, function ()
            if target.roleData.professionId == a then
                local buffPro = Buff.Create(caster, BuffName.PropertyChange, e, BattlePropList[b], d, c)
                target:AddBuff(buffPro)
            end
        end)
    end,

    --> 按职业和属性提高伤害
    --> 若目标是[a]职业，则额外造成目标属性[b][c]%的伤害（不超过施法者攻击的[d]倍）
    --> a[职业] b[属性] c[float] d[int]
    [237] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
     
        BattleLogic.WaitForTrigger(interval, function ()
            if target.roleData.professionId == a then
                local OnPassiveDamaging = function(damagingFunc, atkRole, damage)
                    if not target:IsDead() then
                        local dmg = min(floor(target:GetRoleData(BattlePropList[b]) * c), floor(caster:GetRoleData(RoleDataName.Attack) * d))
                        damagingFunc(-dmg)
                    end
                end
    
                target.Event:AddEvent(BattleEventName.PassiveBeDamaging, OnPassiveDamaging)
                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                    target.Event:RemoveEvent(BattleEventName.PassiveBeDamaging, OnPassiveDamaging)
                end)
            end
        end)
    end,

    --> 按职业直接提高伤害
    --> 若目标是[a]职业，则伤害提高[b]%
    --> a[职业] b[float]
    [238] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
     
        BattleLogic.WaitForTrigger(interval, function ()
            if target.roleData.professionId == a then
                local OnPassiveDamaging = function(damagingFunc, atkRole, damage)
                    if not target:IsDead() then
                        local upDmg = floor(BattleUtil.FP_Mul(damage, b))
                        damagingFunc(-upDmg)
                    end
                end
    
                target.Event:AddEvent(BattleEventName.PassiveBeDamaging, OnPassiveDamaging)
                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                    target.Event:RemoveEvent(BattleEventName.PassiveBeDamaging, OnPassiveDamaging)
                end)
            end
        end)
    end,

    --> 按控制状态临时改属性
    --> 若目标有[a]控制状态，则属性[b][c]改变[d]%
    --> a[控制状态] b[属性] c[改变类型] d[float]
    [239] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4] 
        
        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.Control, function(buff)
                return buff.ctrlType == a
            end)
            if isHave then         
                BattleUtil.AddProp(target, b, d, c)
                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()
                    if not target:IsRealDead() then                      
                        BattleUtil.RevertProp(target, b, d, c)
                    end
                end)
            end
        end)
    end,

    --> 按属性状态临时改属性
    --> 若目标有[a]属性状态，则属性[b][c]改变[d]%
    --> a[属性状态] b[属性] c[改变类型] d[float]
    [240] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4] 
     
        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.PropertyChange, function(buff)
                return buff.propertyChangeType == a
            end)
            if isHave then
                BattleUtil.AddProp(target, BattlePropList[b], d, c)
                -- LogError("240  1")

             -- 修改时间到本次行动结束前
            local function disRevert()
                if not target:IsRealDead() then
                     BattleUtil.RevertProp(target, BattlePropList[b], d, c)
                end
                caster.Event:RemoveEvent(BattleEventName.RoleDamage,disRevert)
            end
            caster.Event:AddEvent(BattleEventName.RoleDamage,disRevert)


            -- BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()
            --     if not target:IsRealDead() then
            --         -- LogError("240  2")
            --         BattleUtil.RevertProp(target, BattlePropList[b], d, c)
            --     end
            -- end)
            end
        end)
    end,

    --> 按控制状态暴击
    --> 若目标有[a]控制状态，则必定暴击
    --> a[控制状态]
    [241] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
     
        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.Control, function(buff)
                return buff.ctrlType == a
            end)
            if isHave then
                target.isFlagCrit = true
                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                    if not target:IsDead() then
                        target.isFlagCrit = false
                    end
                end)
            end
        end)
    end,

    --> 按dot加控制状态
    --> 若目标有[a]或[b]持续伤害状态，[c]%概率附加[d]控制状态[e]回合
    --> a[持续伤害状态] b[持续伤害状态] c[float] d[控制状态] e[int]
    [242] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4] 
        local e = args[5]
     
        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff)
                return buff.damageType == a or buff.damageType == b
            end)

            if isHave then
                BattleUtil.RandomControl(c, d, caster, target, e)
            end
        end)
    end,

    --> 伤害均摊
    --> 在场所有敌人平摊伤害（单体伤害不超过自身属性[a][b]倍）
    --> 造成[a]的[b]伤害, 所有在场敌人平摊伤害（单体伤害不超过自身属性[c][d]倍）
    --> a[属性] b[int]
    [244] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]

        BattleLogic.WaitForTrigger(interval, function ()
            local list = RoleManager.Query(function (r) return r.camp == target.camp and not r:IsDead() end)
            if not list then list = 0 end
            local damgbase = a
            local avgDmg = damgbase / max(#list, 1)

            local OnTriggerBeDamaging = function(damagingFunc, atkRole, damage)
                
                if not target:IsDead() and list and #list > 0 then                                        
                    -- local avgDmg2 = floor(damage / max(#list, 1))
                    -- avgDmg2 = min(floor(atkRole:GetRoleData(BattlePropList[c]) * d), avgDmg2)                    
                    -- damagingFunc(damage - avgDmg2) 
                    for i=1, #list do
                        if list[i].uid ~= target.uid then
                            --LogError("--伤害均摊  伤害1:"..avgDmg.."   当前回合:"..BattleLogic.GetCurRound())
                           local Damage,bCrit = BattleUtil.CalSimpleDamage(nil, caster, list[i], b, avgDmg,0,nil,true)                            
                            --LogError("i:"..Damage)
                            --LogError("--伤害均摊  伤害2:"..Damage.."   当前回合:"..BattleLogic.GetCurRound())
                            BattleUtil.ApplyDamage(skill, caster, list[i], Damage,bCrit)
                        end
                    end
                end
            end

            target.Event:AddEvent(BattleEventName.TriggerBeDamaging, OnTriggerBeDamaging)

            local finalDmg, bCrit, dmg = BattleUtil.CalDamage(skill, caster, target, b, avgDmg)
            --LogError("target:"..finalDmg.." dmg".. dmg)

            target.Event:RemoveEvent(BattleEventName.TriggerBeDamaging, OnTriggerBeDamaging)
        end)
    end,

    --> 无视控制
    --> 施放此技能时无视控制，驱散自身所有负面效果，免疫所有控制[a]回合
    --> a[int]
    [245] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]

        BattleLogic.WaitForTrigger(interval, function ()
            BattleLogic.BuffMgr:ClearBuff(caster, function (buff)
                return clearBuffPredicate(buff, 6)
            end)
            caster:AddBuff(Buff.Create(caster, BuffName.Immune, a, 1))
        end)
    end,

    --> 随机制衡
    --> 随机从攻击、防御、速度抽取一种制衡属性，从目标中选择一名制衡属性最高的敌方武将[a]改变类型其[b]%的相应属性[c]回合
    --> a[改变类型] b[float] c[属性]
    [246] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]

        BattleLogic.WaitForTrigger(interval, function ()
            local rand = Random.RangeInt(1, 3)
            local randPro = RoleDataName.Attack
            if rand == 1 then
                randPro = RoleDataName.Attack
            elseif rand == 2 then
                randPro = RoleDataName.PhysicalDefence
            elseif rand == 3 then
                randPro = RoleDataName.Speed
            end
            local skillTargetsRole = skill:GetDirectTargets()
            table.sort(skillTargetsRole, function(_a, _b)
                return _a:GetRoleData(randPro) > _b:GetRoleData(randPro)
            end)
            if skillTargetsRole[1] then
                local buffPro = Buff.Create(caster, BuffName.PropertyChange, c, randPro, b, a)
                skillTargetsRole[1]:AddBuff(buffPro)
            end
        end)
        
    end,

     --> 随机负面状态
    --> 随机从降疗[a]%、减命中[b]%、减攻[c]%、中毒4个负面状态中选择[d]个状态给目标，持续[e]回合,不超过【h】属性的【i】倍数,中毒每回合造成f属性g伤害
    --> a[float] b[float] c[float] d[int]
    [247] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]  --  0.3
        local b = args[2]  --  0.2
        local c = args[3]  --  0.3
        local d = args[4]  --  2
        local e = args[5]  --  2
        local f = args[6]  --  12
        local g = args[7]  --  0.05
        local h = args[8]  --  1
        local i = args[9]  --  2

        BattleLogic.WaitForTrigger(interval, function ()
            local randarr = {
                RoleDataName.CureFacter,
                RoleDataName.Hit,
                RoleDataName.Attack,
            }
            local fp = {
                a,
                b,
                c,
            }
            local rand = Random.RangeInt(1, 4)
            local rA = {1, 2, 3, 4}
            local randV = {}
            for _i = 1, min(d, 4) do
                local _idx = Random.RangeInt(1, #rA)
                table.insert(randV, rA[_idx])
                table.remove(rA, _idx)
            end

            local limit = floor(caster:GetRoleData(BattlePropList[h])*i)
            -- RoleManager.LogArgs("247",args)  
            for _i = 1, #randV do
                local randone = randV[_i]

                if randone == 4 then
                    local date =  floor(target:GetRoleData(BattlePropList[f])*g)
                    if date > limit then
                        date = limit
                    end
                    --LogError("1 "..date.." 2 "..limit)
                    local buffPro = Buff.Create(caster, BuffName.DOT, e, 1, DotType.Poison, 2)
                    target:AddBuff(buffPro)
                    buffPro.isRealDamage=true
                    buffPro.damagePro=date
                else
                    local date = fp[randone]
                    if randarr[randone] == RoleDataName.CureFacter then
                        limit= floor((1+caster:GetRoleData(BattlePropList[h]))*i)
                        -- LogError(" CureFacter limit:"..limit)
                    end
                    if date > limit then
                        date = limit
                    end
                    -- LogError("date:"..date)                    
                    local buffPro = Buff.Create(caster, BuffName.PropertyChange, e, randarr[randone], date, 3)
                    if randarr[randone] == RoleDataName.CureFacter then
                        -- buffPro.propertyName = RoleDataName.CureFacter
                        -- buffPro.changeType = 3 -- 改为减算 4的计算方式 1 - 0*0.1 数据未变化
                        -- LogError(target.roleId.."!!!date:"..date)  
                        -- BattleUtil.AddProp(target, 14, 10.0001, 3) 
                    end
                    target:AddBuff(buffPro)
                end
            end
        end)
    end,
    --> 偷属性
    --> 偷取属性[a]的[b]%,使目标该属性[c]改变, 自己该属性[d]改变, 持续[e]回合
    --> a[属性] b[float] c[改变类型] d[改变类型] e[int]
    [248] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4] 
        local e = args[5]

        BattleLogic.WaitForTrigger(interval, function ()
            local stealpro = target:GetRoleData(BattlePropList[a]) * b
            -- LogError(" 248 1".."   stealpro:"..stealpro)
            if BattlePropList[a]<= 7 then -- 仅对前七个属性做区分
                stealpro=floor(stealpro)
            end
            -- LogError(" 248 2".."   stealpro:"..stealpro)
            local buffPro = Buff.Create(caster, BuffName.PropertyChange, e, BattlePropList[a], stealpro, c)
            buffPro.isEveryRound = true
            target:AddBuff(buffPro)           

            buffPro = Buff.Create(caster, BuffName.PropertyChange, e, BattlePropList[a], stealpro, d)
            buffPro.isEveryRound = true
            caster:AddBuff(buffPro)
        end)
    end,


    --> 多血量临时改属性
    --> 若[a]目标类型的血量高于[b]%，则本次攻击[c]目标类型的[d]属性[e]改变[f]%
    --> a[目标类型] b[float] c[目标类型] d[属性] e[改变类型] f[float]
    [249] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
     
        BattleLogic.WaitForTrigger(interval, function ()
            local hpPer = 0
            if a == 1 then   --< 此处目标类型应该只能为1 2
                hpPer = target:GetRoleData(RoleDataName.Hp) / target:GetRoleData(RoleDataName.MaxHp)
            elseif a == 2 then
                hpPer = caster:GetRoleData(RoleDataName.Hp) / caster:GetRoleData(RoleDataName.MaxHp)
            end
            if hpPer > b then
                local changeProperty = function(_role, _a, _b, _c, _d)

                    BattleUtil.AddProp(_role, BattlePropList[_b], _c, _d)

                    -- 修改时间到本次行动结束前
                    local function disRevert()
                        if not _role:IsRealDead() then
                            BattleUtil.RevertProp(_role, BattlePropList[_b], _c, _d)
                        end
                        caster.Event:RemoveEvent(BattleEventName.RoleTurnEnd,disRevert)
                    end
                    caster.Event:AddEvent(BattleEventName.RoleTurnEnd,disRevert)
                    -- BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()
                    --     if not _role:IsRealDead() then
                    --         BattleUtil.RevertProp(_role, BattlePropList[_b], _c, _d)
                    --     end
                    -- end)
                end
                if c == 1 then
                    changeProperty(target, 0, d, f, e)
                elseif c == 2 then
                    if tarIdx == 1 then
                        changeProperty(caster, 0, d, f, e)
                    end
                end
            end
        end)
    end,

    --> 复杂伤害
    --> 造成（[a]+(1-目标剩余血量百分比)*[b]）/ [c] 的[d]伤害
    --> a[float] b[float] c[int] d[伤害类型]
    [250] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4] 

        BattleLogic.WaitForTrigger(interval, function ()
            local percentHp = target:GetRoleData(RoleDataName.Hp) / target:GetRoleData(RoleDataName.MaxHp)
            local damage = (a + floatKeepDecimals(((1 - percentHp) * b ), 2)) / c
            BattleUtil.CalDamage(skill, caster, target, d, damage)
        end)
    end,

    --> 斩杀
    --> 若伤害后目标生命值低于[a]，则斩杀目标（斩杀的伤害值无视护盾，防御，伤害分摊，伤害为该武将生命值的[b]，不超过攻击[c]倍）
    --> a[float] b[float] c[int]
    [251] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]

        BattleLogic.WaitForTrigger(interval, function ()
            local percentHp = target:GetRoleData(RoleDataName.Hp) / target:GetRoleData(RoleDataName.MaxHp)
            if percentHp < a then
                local damage = BattleUtil.FP_Mul(target:GetRoleData(RoleDataName.Hp), b)
                local atkMulti = BattleUtil.FP_Mul(caster:GetRoleData(RoleDataName.Attack), c)
                if damage < atkMulti then
                    BattleUtil.Seckill(skill, caster, target)
                else
                    local list = RoleManager.Query(function (r) return r.uid == target.uid end)
                    if list and #list > 0 then
                        BattleUtil.ApplyDamage(skill, caster, list[1], atkMulti)
                    end
                    -- BattleUtil.CalDamage(skill, caster, target, 1, c)
                end
            end
        end)
    end,

    --> 停止行动
    --> 之后停止行动[a]回合
    --> a[int]
    [252] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]

        BattleLogic.WaitForTrigger(interval, function ()
            local brand = Buff.Create(caster, BuffName.Brand, a + 1, "stop_move", function ()
                if caster and not caster:IsRealDead() then
                    caster.stop_move = false
                end
            end)
            caster.stop_move = true
            caster:AddBuff(brand)
        end)
    end,

    --> [a]属性[b]改变[c]，受到伤害所有在场己方均摊，持续[d]回合，效果均不可被驱散；消失后，携带者恢复施法者[e]属性[f]的生命
    --> a[属性] b[改变类型] c[float] d[int] e[属性] f[float] 
    [253] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4] 
        local e = args[5]
        local f = args[6]

        BattleLogic.WaitForTrigger(interval, function ()
            local buffEffect = Buff.Create(caster, BuffName.BEffect, d, BEffectType.BaZhenTu)
            buffEffect.clear = false
            target:AddBuff(buffEffect)

            local buffPro = Buff.Create(caster, BuffName.PropertyChange, d, BattlePropList[a], c, b)
            buffPro.clear = false
            target:AddBuff(buffPro)

            local caster_blood = floor(BattleUtil.FP_Mul(caster:GetRoleData(BattlePropList[e]), f))
            local list = RoleManager.Query(function (r) return r.camp == target.camp end)
            local OnTriggerBeDamageEnd = function(damagingFunc, atkRole, damage, skill)
                if not target:IsDead() and list and #list > 0 then
                    local listlive = RoleManager.Query(function (r) return r.camp == target.camp end,false)
                    if listlive == nil or #listlive <= 0 then return end
                    local avgDmg = floor(damage / max(#listlive, 1))
                    damagingFunc(damage - avgDmg)
                    -- LogError("总伤害："..damage)
                    for i = 1, #list do
                        if list[i].roleId ~= target.roleId then
                            local forceBear = false--atkRole.element==list[i].element 修改为默认不显示克制
                            local changeBear = nil
                            changeBear = function( atkRole,defRole, ChangeForbear)
                                ChangeForbear(forceBear)
                                target.Event:RemoveEvent(BattleEventName.RoleCheckForbear, changeBear) 
                            end
                            target.Event:AddEvent(BattleEventName.RoleCheckForbear, changeBear)
                            BattleUtil.ApplyDamage(skill, atkRole, list[i], avgDmg)
                            -- LogError(list[i].roleId..":"..avgDmg)
                        end
                    end
                end
            end
            target.Event:AddEvent(BattleEventName.TriggerBeDamageEnd, OnTriggerBeDamageEnd)


            local OnBuffEnd = function(buff)
                if buff == buffPro then
                    if caster_blood > 0 then    --< >0回血 1级不回血
                        BattleUtil.CalTreat(caster, target, caster_blood)
                    end
                end
            end
            target.Event:AddEvent(BattleEventName.BuffEnd, OnBuffEnd)

            local brand = Buff.Create(caster, BuffName.Brand, d, "Property_bazhentu_flag", function ()
                target.Event:RemoveEvent(BattleEventName.BuffEnd, OnBuffEnd)
                target.Event:RemoveEvent(BattleEventName.TriggerBeDamageEnd, OnTriggerBeDamageEnd)
            end)
            target:AddBuff(brand)
        end)
    end,

    --> 属性状态
    --> [a]%概率为[b]目标附加[c]属性状态, [d]改变[e]%，[f]回合
    --> a[float] b[目标] c[属性状态] d[改变类型] e[float] f[int]
    [254] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4] 
        local e = args[5]
        local f = args[6]
        -- local a = 1
        -- local b = 1
        -- local c = 5
        -- local d = 3 
        -- local e = 0.1
        -- local f = 10

        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                local changeProperty = function(_role, _a, _b, _c, _d, propertyStatus)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, _a, PropertyChangeTypeMap[_b], _c, _d, propertyStatus)
                    _role:AddBuff(buff)
                end
                -- local changeProperty2 = function(_role, _a, _b, _c, _d)
                --     local buff = Buff.Create(caster, BuffName.PropertyChange, _a, BattlePropList[_b], _c, _d)
                --     _role:AddBuff(buff)
                -- end
                if b == 1 then
                    changeProperty(target, f, c, e, d, c)
                    -- changeProperty2(target, f, g, e, d)
                elseif b == 2 then
                    if tarIdx == 1 then
                        changeProperty(caster, f, c, e, d, c)
                        -- changeProperty2(caster, f, g, e, d)
                    end
                end
            end)
        end)
    end,

    --> 挑衅
    --> [a]%概率附加挑衅,持续[b]回合
    --> a[float] b[int]
    [255] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]

        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomControl(a, ControlType.LockTarget, caster, target, b)
        end)
    end,

    --> 挑衅,条件提高概率
    --> [a]%概率附加挑衅, 如果目标有[b]属性状态, 概率提高[c]%,持续[d]回合
    --> a[float] b[属性状态] c[float] d[int]
    [256] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]

        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.PropertyChange, function(buff)
                return buff.propertyChangeType == b
            end)
            local _a = a
            if isHave then
                _a = _a + _a * c
            end
            BattleUtil.RandomControl(_a, ControlType.LockTarget, caster, target, d)
        end)
    end,

    --> 伤害,优先某职业
    --> 优先选择[a]职业, 造成[b]的[c]伤害
    --> a[职业] b[float] c[伤害类型]
    [257] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]

        BattleLogic.WaitForTrigger(interval, function ()
            
        end)
    end,

    --> 禁止复活
    --> [a]概率附加"禁止复活", 持续[b]回合
    --> a[float] b[int]
    [258] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        
       
        BattleLogic.WaitForTrigger(interval, function ()
            local function unRelive()
                target.deadRoundCounter = BattleLogic.GetCurRound() + b - 1
                target:SetReliveFilter(false)
                --LogError("start target:SetReliveFilter(false) round:"..target.deadRoundCounter)
                local resetFunc
                resetFunc = function()
                    if BattleLogic.GetCurRound() == target.deadRoundCounter then 
                        target:SetReliveFilter(true)
                        --LogError("end target:SetReliveFilter(true) round:"..target.deadRoundCounter )
                        target.deadRoundCounter = 0
                        BattleLogic.Event:RemoveEvent(BattleEventName.RoundBegin,resetFunc)
                    end
                end
                BattleLogic.Event:AddEvent(BattleEventName.RoundBegin,resetFunc)
            end   
     

            BattleUtil.RandomAction(a, function()            
                local brand = Buff.Create(caster, BuffName.Brand, b + 1, "no_relive")
                brand.startFunc = unRelive
                brand.coverFunc = unRelive
                -- brand.endFunc = resetRelive
                brand.clear = false --不可清除
                brand.cover = false
                target:AddBuff(brand)
            end)
        end)
    end,

    --> 属性状态+属性变化
    --> [a]%概率为[b]目标附加[c]属性状态[d]改变[e]%，且使属性[f][g]改变[h]%，[i]回合
    --> a[float] b[目标] c[属性状态] d[改变类型] e[float] f[属性] g[改变类型] h[float] i[int]
    [259] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        local g = args[7]
        local h = args[8]
        local i = args[9]
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                
                local changePropertyStatus = function(_role, _a, _b, _c, _d)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, _a, PropertyChangeTypeMap[_b], _c, _d, _b)
                    _role:AddBuff(buff)
                end
                local changeProperty = function(_role, _a, _b, _c, _d)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, _a, BattlePropList[_b], _c, _d)
                    _role:AddBuff(buff)
                end
                if b == 1 then
                    changePropertyStatus(target, i, c, e, d)
                    changeProperty(target, i, f, h, g)
                elseif b == 2 then
                    if tarIdx == 1 then
                        changePropertyStatus(caster, i, c, e, d)
                        changeProperty(caster, i, f, h, g)
                    end
                end
            end)
        end)
    end,

    --> 临时改属性
    --> [a]%概率使[b]目标的属性[c][d]改变[e]%
    --> a[float] b[目标类型] c[属性] d[改变类型] e[float]
    [260] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1] --1
        local b = args[2] --2
        local c = args[3] --10
        local d = args[4] --1
        local e = args[5]
         --LogError("260 1")
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                
                local changeProperty = function(_role, _a, _b, _c, _d)
                
                    -- local stealpro=_role:GetRoleData(BattlePropList[_b])                    
                    -- if stealpro > _c then --被偷的属性大于参数值否则最小到 0
                    --     stealpro = _c
                    -- end
                    -- -- LogError("260 seta"..stealpro)
                    BattleUtil.AddProp(_role, _b, _c , _d)

                   --[[
                        BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()
                        if not _role:IsRealDead() then
                            BattleUtil.RevertProp(_role, _b, _c, _d)
                        end
                    end)
                    ]]
                    local trigger = nil
                    trigger = function()

                        if not _role:IsRealDead() then
                            BattleUtil.RevertProp(_role, _b, _c, _d)
                        end
                        
                        _role.Event:RemoveEvent(BattleEventName.RoleDamageAfter, trigger)
                    end

                    _role.Event:AddEvent(BattleEventName.RoleDamageAfter, trigger)

                end
                if b == 1 then
                    changeProperty(target, nil, c, e, d)
                elseif b == 2 then
                    if tarIdx == 1 then
                        changeProperty(caster, nil, c, e, d)
                    end
                end
            end)
        end)
    end,

    --> 加dot
    --> [a]%概率给目标附加[b]持续伤害状态, 每回合损失施法者[c]属性[d]%的生命, 持续[e]回合
    --> a[float] b[持续伤害状态] c[属性] d[float] e[int]
    [261] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]  --0.4 6 12 0.07 2
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        

        local targetIsRealDead = false
        local deadFunc = function()
            targetIsRealDead = true
        end
        
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                local val = floor(BattleUtil.FP_Mul(caster:GetRoleData(BattlePropList[c]), d))
                local dot = Buff.Create(caster, BuffName.DOT, e, 1, b, val)
                dot.isRealDamage = true
                target:AddBuff(dot)
                
                --由于是复活之后再增加的buff 这里判断了再移除buff
                if targetIsRealDead and dot.target then
                    dot.target.Event:DispatchEvent(BattleEventName.BuffStart, dot)
                    BattleLogic.BuffMgr:RemoveBuffQueneBy(function(buff)
                        return buff.id  == dot.id
                    end)
                    dot.target.Event:DispatchEvent(BattleEventName.BuffEnd, dot)
                    targetIsRealDead = false
                end
            end)
        end)

        target.Event:AddEvent(BattleEventName.RoleRealDead, deadFunc)
    end,

    --> 按dot暴击
    --> 若目标有[a]或[b]持续伤害状态，则暴击
    --> a[持续伤害状态] b[持续伤害状态]
    [262] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        
        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff)
                return buff.damageType == a or buff.damageType == b
            end)

            if isHave then
                target.isFlagCrit = true
                local func = nil
                func = function()
                    if not target:IsDead() then
                        target.isFlagCrit = false
                        target.Event:RemoveEvent(BattleEventName.FlagCritReset, func)
                    end
                end
                
                target.Event:AddEvent(BattleEventName.FlagCritReset, func)
                --[[
                    BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                    if not target:IsDead() then
                        target.isFlagCrit = false
                    end
                end)
                ]]
               
            end
        end)
    end,

    --> 反伤效果
    --> 为目标附加反伤效果，反弹[a]%伤害, 持续[b]回合
    --> 为目标附加烙印[c]效果，反弹[a]伤害, 持续[b]回合 反伤用烙印实现 flag类型 为传入值
    --> a[float] b[int]
    [263] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        
        BattleLogic.WaitForTrigger(interval, function ()

            local OnTriggerBeDamaging = function(damagingFunc, atkRole, damage)
                if not target:IsDead() then
                    local reboundDmg = floor(BattleUtil.FP_Mul(damage, a))
                    BattleUtil.ApplyDamage(nil, caster, atkRole, reboundDmg)
                end
            end
            
            
            target.Event:AddEvent(BattleEventName.TriggerBeDamaging, OnTriggerBeDamaging)
            local brand = Buff.Create(caster, BuffName.Brand, b, c, function ()
                target.Event:RemoveEvent(BattleEventName.TriggerBeDamaging, OnTriggerBeDamaging)
            end)
            target:AddBuff(brand)
        end)
    end,

    --> 按dot加属性
    --> 若目标有[a]持续伤害状态,则[b]目标类型的[c]属性[d]改变类型[e]%
    --> a[持续伤害状态] b[目标类型] c[属性] d[改变类型] e[float]
    [264] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        
        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff)
                return buff.damageType == a
            end)

            if isHave then
                local changeProperty = function(_role, _a, _b, _c, _d) --6  0.2  3
                    -- local buff = Buff.Create(caster, BuffName.PropertyChange, 0, BattlePropList[_b], _c, _d)
                    -- _role:AddBuff(buff)
                    -- buff.isEveryRound=true
                    -- buff:OnTrigger()
                    BattleUtil.AddProp(_role, _b, _c, _d)
                    -- LogError("added")
                    local function disbuff() 
                        -- buff.disperse = true
                        BattleUtil.RevertProp(_role, _b, _c, _d)
                        caster.Event:RemoveEvent(BattleEventName.RoleTurnEnd,disbuff)
                    end
                    --修改到本回合结束 RoleTurnEnd
                    caster.Event:AddEvent(BattleEventName.RoleTurnEnd,disbuff)

                    -- BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                    --     buff.disperse = true
                    -- end)
                end
                if b == 1 then
                    changeProperty(target, nil, c, e, d)
                elseif b == 2 then
                    if tarIdx == 1 then
                        changeProperty(caster, nil, c, e, d)
                    end
                end
            end
        end)
    end,

    --> 按dot加控制状态
    --> 若目标有[a]或[b]持续伤害状态，则[c]%概率给[d]目标类型附加[e]控制状态, 持续[f]回合
    --> a[持续伤害状态] b[持续伤害状态] c[float] d[目标类型] e[控制状态] f[int]
    [265] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        
        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff)
                return buff.damageType == a or buff.damageType == b
            end)

            if isHave then
                if d == 1 then
                    BattleUtil.RandomControl(c, e, caster, target, f)
                elseif d == 2 then
                    if tarIdx == 1 then
                        BattleUtil.RandomControl(c, e, caster, caster, f)
                    end
                end
            end
        end)
    end,

    --> 改变属性,不叠加
    --> [a]概率使[b]目标类型的[c]属性[d]改变类型[e], 持续[f]回合,不可叠加
    --> a[float] b[1目标/2自己/3目标和自己] c[属性] d[改变类型] e[float] f[int]
    [266] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()  
                local changeProperty = function(_role)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, f, BattlePropList[c], e, d)
                    buff.cover = true
                    buff.maxLayer = 1
                    _role:AddBuff(buff)
                end
                if b == 1 then
                    changeProperty(target)
                elseif b == 2 then
                    if tarIdx == 1 then
                        changeProperty(caster)
                    end
                end
            end)
        end)
    end,

    --> 按负面效果临时改属性
    --> 目标身上每1个负面效果, 使[a]目标类型的[b]属性[c]改变[d]
    --> a[目标类型] b[属性] c[改变类型] d[float]
    [267] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        
        BattleLogic.WaitForTrigger(interval, function ()
            BattleLogic.BuffMgr:QueryBuff(target, function(buff)
                if buff.type == BuffName.Control or buff.isDeBuff or buff.type == BuffName.DOT then
                    local changeProperty = function(_role, _a, _b, _c, _d)
                        BattleUtil.AddProp(_role, _b, _c, _d)
                        BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()
                            if not _role:IsRealDead() then
                                BattleUtil.RevertProp(_role, _b, _c, _d)
                            end
                        end)
                    end
                    if a == 1 then
                        changeProperty(target, 0, b, d, c)
                    elseif a == 2 then
                        if tarIdx == 1 then
                            changeProperty(caster, 0, b, d, c)
                        end
                    end
                end
            end)
        end)
    end,

    --> 加诅咒
    --> [a]概率附加"诅咒", 在[b]回合后给携带者造成施法者[c]属性[d]的伤害, 诅咒可同时存在多个
    --> a[float] b[int] c[属性] d[float]
    [268] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1] --0.5
        local b = args[2] -- 2
        local c = args[3] -- 1
        local d = args[4] --0.3
        --RoleManager.LogArgs("268",args)
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                --LogError("268")
                local brand = Buff.Create(caster, BuffName.Brand, b, BrandType.curse)
                brand.TriggerFunc = function()
                    local damage = floor(caster:GetRoleData(BattlePropList[c])*d)
                    BattleLogManager.Log(
                        "268 ApplyDamage",
                        "damage:", damage
                    )
                    BattleUtil.ApplyDamage(nil, caster, target, damage, nil, nil, BuffDamageType.Curse, false)
                end
                brand:SetInterval(b)
                brand.cover = false
                target:AddBuff(brand)
            end)
        end)
    end,

    --> 根据伤害加吸收盾
    --> 造成[a]%的[b]伤害, 为己方血量百分比最少3人增加"吸收盾", 可吸收伤害量[c]%的伤害值,持续[d]回合
    --> a[float] b[伤害] c[float] d[int]
    [269] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]

        
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.CalDamage(skill, caster, target, b, a)

            local arr = RoleManager.Query(function (r) return r.camp == caster.camp end)
            
            
            table.sort(arr, function(a, b)
                local hpPerA =a:GetRoleData(RoleDataName.Hp) / a:GetRoleData(RoleDataName.MaxHp)
                local hpPerB =b:GetRoleData(RoleDataName.Hp) / b:GetRoleData(RoleDataName.MaxHp)
                return hpPerA < hpPerB
            end)
            for i = 1, 3 do
                if i <= #arr then
                    local shield = Buff.Create(caster, BuffName.Shield, d, ShieldTypeName.NormalReduce, c, 0)
                    arr[i]:AddBuff(shield)
                end
            end
            
        end)
    end,

    --> 按诅咒加控制状态
    --> 若目标有"诅咒", 则[a]概率附加[b]控制状态,持续[c]回合,; 同时使"诅咒"立即生效,造成伤害
    --> a[float] b[控制状态] c[int]
    [270] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]

        
        BattleLogic.WaitForTrigger(interval, function ()
            if BattleLogic.BuffMgr:HasBuff(target, BuffName.Brand, function (buff) return buff.flag == "brand_curse" end) then
                BattleUtil.RandomControl(a, b, caster, target, c)

                BattleLogic.BuffMgr:ClearBuff(target, function (buff)
                    return buff.type == BuffName.Brand and buff.flag == "brand_curse"
                end)
            end
        end)
    end,

    --> 加"绝情"
    --> [a]概率给目标附加"绝情",持续[b]回合; 绝情效果:<14受疗>属性减[c], <23防御加成>减[d]，且恢复攻击者本次伤害[e]的生命
    --> a[float] b[int] c[float] d[float] e[float]
    [271] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                local buff1 = Buff.Create(caster, BuffName.PropertyChange, 0, BattlePropList[14], c, 3)
                target:AddBuff(buff1)
                local buff2 = Buff.Create(caster, BuffName.PropertyChange, 0, BattlePropList[23], d, 3)
                target:AddBuff(buff2)
                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()

                end)
                local buff = Buff.Create(caster, BuffName.Brand, b, "brand_jueqing", function()
                    BattleLogic.BuffMgr:ClearBuff(target, function (_buff)
                        return _buff == buff1 or _buff == buff2
                    end)
                end)
                buff.isDeBuff = true
                target:AddBuff(buff)
            end)
        end)
    end,

    --> 神兵绝对伤害
    --> 造成[a]的绝对伤害(不走公式，直接削减目标血量或护盾值)
    --> a[int]
    [272] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.ApplyDamage(skill, caster, target, a)
        end)
    end,
    --> 神兵流血伤害
    --> [a]%概率给目标附加[b]持续伤害状态, 每回合损失固定[c]数量的生命, 持续[d]回合
    --> a[float] b[持续伤害状态] c[int] d[int]
    [273] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]

        
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                local dot = Buff.Create(caster, BuffName.DOT, d, 1, b, c)
                dot.isRealDamage = true
                target:AddBuff(dot)
            end)
        end)
    end,
    --> 神兵伤害吸收盾
    --> [a]改变携带者的[b]属性[c]%的伤害吸收盾，持续[d]回合
    --> a[改变类型] b[属性] c[float] d[int]
    [274] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]

        
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()  
                local val = floor(BattleUtil.FP_Mul(caster:GetRoleData(BattlePropList[b]), c))
                local shield = Buff.Create(caster, BuffName.Shield, d, ShieldTypeName.NormalReduce, val, 0)
                target:AddBuff(shield)
            end)
        end)
    end,
    --> 神兵昏迷无视抗控
    --> [a]%概率[b]控制状态，持续[c]回合（无视抗控）
    --> a[float] b[控制状态] c[int]
    [275] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]

        
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomControl(a, b, caster, target, c)
        end)
    end,
    --> 按dot改属性
    --> 若目标有[a]持续伤害状态,则[b]目标类型的[c]属性[d]改变类型[e]%,持续[f]回合
    --> a[持续伤害状态] b[目标类型] c[属性] d[改变类型] e[float] f[int]
    [276] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]

        
        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff)
                return buff.damageType == a
            end)

            if isHave then
                local changeProperty = function(_role, _a, _b, _c, _d)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, f, BattlePropList[_b], _c, _d)
                    _role:AddBuff(buff)
                end
                if b == 1 then
                    changeProperty(target, nil, c, e, d)
                elseif b == 2 then
                    if tarIdx == 1 then
                        changeProperty(caster, nil, c, e, d)
                    end
                end
            end
        end)
    end,
    --> 意志控制
    --> [a]概率使[b]目标恢复自身最大生命值的[c]，且属性[d][e]改变[f],持续[g]回合
    --> a[float] b[int] c[float] d[属性] e[改变类型] f[float] g[int]
    [277] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        local g = args[7]

        
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()  
                
                local process = function(role)
                    local val = floor(BattleUtil.FP_Mul(caster:GetRoleData(RoleDataName.MaxHp), c))
                    BattleUtil.CalTreat(caster, role, val)
                end
                local changeProperty = function(_role, _a, _b, _c, _d)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, g, BattlePropList[_b], _c, _d)
                    _role:AddBuff(buff)
                end

                
                
                if b == 1 then
                    process(target)
                    changeProperty(target, nil, d, f, e)
                elseif b == 2 then
                    if tarIdx == 1 then
                        process(caster)
                        changeProperty(caster, nil, d, f, e)
                    end
                end
            end)
        end)
    end,

    --> 加dot（261加目标类型）
    --> [a]概率给目标附加[b]持续伤害状态, 每回合损失[f]目标类型[c]属性[d]的生命, 持续[e]回合
    --> a[float] b[持续伤害状态] c[属性] d[float] e[int] f[目标类型]
    [278] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                local damage
                if f == 1 then
                    damage = floor(target:GetRoleData(BattlePropList[c]) * d)
                elseif f == 2 then
                    damage = floor(caster:GetRoleData(BattlePropList[c]) * d)
                end
                
                local buff = Buff.Create(caster, BuffName.DOT, e, 1, b, damage)
                buff.isRealDamage = true
                target:AddBuff(buff)
            end)
        end)
    end,

    --> 复杂恢复
    --> 为目标恢复等同于[a]目标类型[b]属性[c]%的生命值
    --> a[目标类型] b[属性] c[float]
    [279] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        
        BattleLogic.WaitForTrigger(interval, function ()
            local treat
            if a == 1 then
                treat = floor(target:GetRoleData(BattlePropList[b]) * c)
            elseif a == 2 then
                treat = floor(caster:GetRoleData(BattlePropList[b]) * c)
            end

            BattleUtil.CalTreat(caster, target, treat)
            
        end)
    end,

    --> 不屈意志状态
    --> 若目标剩余生命百分比低于[a]%, 则给目标不屈意志状态: 当目标在没有"禁止复活"状态时死亡会立即复活, 并获得[b]属性[c]%的生命值, 全场战斗只触发一次,
    --> a[float] b[属性] c[float]
    [280] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        
        BattleLogic.WaitForTrigger(interval, function ()
            if BattleLogic.BuffMgr:HasBuff(target, BuffName.Brand, function (buff)
                return buff.flag == BrandType.buquyizhi
            end) then
                
            else
                if target:GetRoleData(RoleDataName.Hp)/target:GetRoleData(RoleDataName.MaxHp) < a then
                    local buff = Buff.Create(caster, BuffName.Brand, 0, BrandType.buquyizhi)
                    buff.clear = false
                    target:AddBuff(buff)

                    local OnRoleRealDead = nil
                    OnRoleRealDead = function(deadRole)
                        target.Event:RemoveEvent(BattleEventName.RoleRealDead, OnRoleRealDead)
                        if target.effect280times == 0 then
                            local maxHp = target:GetRoleData(RoleDataName.MaxHp)
                            local blood = floor(target:GetRoleData(BattlePropList[b]) * c)
                            target:SetRelive(math.min(blood / maxHp, 1))
                            target.effect280times = target.effect280times - 1
                        end
                    end
                    target.Event:AddEvent(BattleEventName.RoleRealDead, OnRoleRealDead)
                end
            end
        end)
    end,

    --> 伤害+他人回血
    --> 给目标造成[a]倍的[b]类型伤害，且给己方血量最少单位恢复等同于伤害值[c]%的血量
    --> a[float] b[伤害类型] c[float]
    [281] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        
        BattleLogic.WaitForTrigger(interval, function ()
            local finalDmg, bCrit, dmg = BattleUtil.CalDamage(skill, caster, target, b, a)
            local list = RoleManager.Query(function (r) return r.camp == caster.camp end)
            local minhp = nil
            local _r = nil
            for _k, _v in ipairs(list) do
                if not minhp then
                    minhp = _v:GetRoleData(RoleDataName.Hp)/_v:GetRoleData(RoleDataName.MaxHp)
                    _r = _v
                end
                if _v:GetRoleData(RoleDataName.Hp)/_v:GetRoleData(RoleDataName.MaxHp) < minhp then
                    minhp = _v:GetRoleData(RoleDataName.Hp)/_v:GetRoleData(RoleDataName.MaxHp)
                    _r = _v
                end
                if _r then
                    BattleUtil.CalTreat(caster, _r, floor(dmg * c))
                end
            end
        end)
    end,

    --> 区间内随机伤害
    --> 对目标造成[a]-[b]区间内随机[c]类型伤害
    --> a[float] b[float] c[伤害类型]
    [282] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        
        BattleLogic.WaitForTrigger(interval, function ()
            local v = Random.Range(a, b)
            BattleUtil.CalDamage(skill, caster, target, c, v)
        end)
    end,

    --> 航母特殊效果
    --> 对目标造成[a]倍的[b]类型伤害,目标身上每携带1个负面状态则受到的伤害提升[c], 技能的伤害不超过自身攻击力5倍）；对负面状态超过5个的目标额外附加[d]控制状态[e]回合
    --> a[float] b[伤害类型] c[float] d[控制状态] e[int]
    [283] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        
        BattleLogic.WaitForTrigger(interval, function ()
            if not target:IsRealDead() then
                local targetList = BattleLogic.BuffMgr:GetBuff(target, function(buff)
                    return clearBuffPredicate(buff, 6)
                end)
                local deCnt = 0
                deCnt = #targetList
    
                local maxDmg = floor(BattleUtil.FP_Mul(caster:GetRoleData(RoleDataName.Attack), 5))
    
                local trigger = function(damagingFunc, atkRole, damage, skill, dotType, bCrit, damageType)
                    local dmg
                    if deCnt > 0 then
                        dmg = damage + floor(damage * c * deCnt)
                    else
                        dmg = damage
                    end
    
                    local trans = 0
                    dmg = floor(math.min(dmg, maxDmg))
                    if dmg >= damage then
                        trans = - (dmg - damage)
                    else
                        trans = damage - dmg
                    end
                    
                    damagingFunc(trans)
                end
                target.Event:AddEvent(BattleEventName.FinalBeDamage, trigger)
                local finalDmg, bCrit, dmg = BattleUtil.CalDamage(skill, caster, target, b, a)
                target.Event:RemoveEvent(BattleEventName.FinalBeDamage, trigger)

                if deCnt > 5 then
                    BattleUtil.RandomControl(1, d, caster, target, e)
                end
            end
        end)
    end,

    --> 航母特殊效果
    --> 二选一: 对目标造成[a]倍[b]类型伤害; 或者对敌方全体目标造成[c]倍的[d]类型伤害
    --> a[float] b[伤害类型] c[float] d[伤害类型]
    [284] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        
        BattleLogic.WaitForTrigger(interval, function ()
            if not target:IsRealDead() then
                if Random.Range01() <= 0.5 then
                    BattleUtil.CalDamage(skill, caster, target, b, a)
                else
                    if tarIdx == 1 then
                        local list = RoleManager.Query(function (r) return r.camp ~= caster.camp end)
                        skill:SetRoleListAsHit(list)
                        for _k, _v in ipairs(list) do
                            if not _v:IsRealDead() then
                                BattleUtil.CalDamage(skill, caster, _v, d, c)
                            end
                        end
                    end
                end
            end
        end)
    end,

    --> 怒气增加伤害 并且 对额外目标造成伤害
    --> 造成[a]的[b]伤害, 每[c]层怒气增加[d]百分比数值伤害(最多增加[e]次)，且当自身角色BUFF层数大于等于[c]层时，
    --> 额外对[f]个非当前自己目标的敌方单位基础技能造成*[d]的伤害，如当前BUFF层数大于等于[e]*[c]，则额外目标伤害再提高[d]百分比数值伤害,
    --  怒气在攻击后归零
    --> d[float]
    [285] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        
        BattleLogic.WaitForTrigger(interval, function ()
            local bufflist = BattleLogic.BuffMgr:GetBuff(caster, function(buff)
                return buff.type == BuffName.Brand and buff.flag == BrandType.Angry
            end)

            -- LogError("bufflist:"..#bufflist )
            if bufflist and #bufflist > 0 then
                local attTimes = math.min(floor(bufflist[1].layer / c), e)
                -- LogError("attTimes:"..attTimes )
                if attTimes > 0 then
                    local list = RoleManager.Query(function (r) return r.camp == target.camp end)
                    if list and #list > 0 then
                        -- LogError("list:"..#list )
                        for i=1, #list do
                            if list[i].uid == target.uid then
                                table.remove(list,i)
                                break
                            end
                        end

                        local addTarget = attTimes * d
                        local addExtraTarget = d 
                        if bufflist[1].layer >= e * c then addExtraTarget = d * 2 end

                        local OnTriggerBeDamaging = function(damagingFunc, atkRole, damage)
                            local t_list = {}
                            if not target:IsDead() and list and #list > 0 then
                                table.insert(t_list,list[1])
                                if #list > 1 then
                                    table.insert(t_list,list[2])
                                end

                                local dmg = floor(damage * addTarget)
                                local dmg1 = floor(damage * addExtraTarget)

                                damagingFunc(-dmg)

                                for i=1, #t_list do
                                    BattleUtil.ApplyDamage(skill, caster, t_list[i], dmg1)
                                end
                            end
                        end
            
                        target.Event:AddEvent(BattleEventName.TriggerBeDamaging, OnTriggerBeDamaging)
            
                        BattleUtil.CalDamage(skill, caster, target, b, a)
            
                        target.Event:RemoveEvent(BattleEventName.TriggerBeDamaging, OnTriggerBeDamaging)
                        
                        -- LogError("clearing")
                    end
                else
                    BattleUtil.CalDamage(skill, caster, target, b, a)  
                end
            else
                BattleUtil.CalDamage(skill, caster, target, b, a)  
            end  
            
            --怒气消失
            if bufflist and #bufflist > 0 then
                for v,bf in pairs(bufflist) do
                    bf.clear = true
                    bf.disperse = true
                end
            end
            -- bufflist[1].clear = true
            -- bufflist[1].disperse = true
        end)
    end,

    --> 停止行动
    --> 之后停止行动[a]回合
    -->[a]概率从下回合开始停止行动[b]回合(a[float],b[int])
    [286] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]

        BattleUtil.RandomAction(a, function()
            BattleLogic.WaitForTrigger(interval, function ()
                local brand = Buff.Create(caster, BuffName.Brand, b + 1, "stop_move", function ()
                    if caster and not caster:IsRealDead() then
                        caster.stop_move = false
                    end
                end)
                caster.stop_move = true
                caster:AddBuff(brand)
            end)
        end)
    end,
 
    --> 按属性状态临时改属性
    --> 若目标有[a]属性状态，则[b]目标c属性[d]改变[e] 
    --> a[属性状态] b[目标] c[属性] d[改变] e[改变值]
    [287] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4] 
        local e = args[5]
        --RoleManager.LogArgs("E 287",args)

        local isAdded =false

        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.PropertyChange, function(buff)
                return buff.propertyChangeType == a
            end)
            if isHave then
                if b == 1 then
                    BattleUtil.AddProp(target, c, e, d)                    
                    isAdded = true
                elseif b == 2 then
                    BattleUtil.AddProp(caster, c, e, d)
                    isAdded = true
                elseif b == 3 then
                    BattleUtil.AddProp(caster, c, e, d)
                    BattleUtil.AddProp(target, c, e, d)
                    isAdded = true
                end

             -- 修改时间到本次行动结束前
            local function disRevert()
                if not target:IsRealDead() and isAdded then
                    if b == 1 then
                        BattleUtil.RevertProp(target, c, e, d)                        
                        isAdded = false
                    elseif b == 2 then
                        BattleUtil.RevertProp(caster, c, e, d)
                        isAdded = false
                    elseif b == 3 then
                        BattleUtil.RevertProp(caster, c, e, d)
                        BattleUtil.RevertProp(target, c, e, d)
                        isAdded = false
                    end
                end
                caster.Event:RemoveEvent(BattleEventName.RoleTurnEnd,disRevert)
            end
             caster.Event:AddEvent(BattleEventName.RoleTurnEnd,disRevert)
            end
        end)
    end,

    --> 临时改属性  可为负数 
    --> [a]%概率使[b]目标的属性[c][d]改变[e]%
    --> a[float] b[目标类型] c[属性] d[改变类型] e[float]
    [288] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        -- LogError("288 1")
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                -- LogError("288 2")
                local changeProperty = function(_role, _a, _b, _c, _d)                
                     
                    BattleUtil.AddProp(_role, BattlePropList[_b], _c, _d)
                    BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()
                        if not _role:IsRealDead() then
                            BattleUtil.RevertProp(_role, BattlePropList[_b], _c, _d)
                        end
                    end)
                end
                if b == 1 then
                    changeProperty(target, nil, c, e, d)
                elseif b == 2 then
                    if tarIdx == 1 then
                        changeProperty(caster, nil, c, e, d)
                    end
                end
            end)
        end)
    end,

    --新增主动技能效果289：每个在场的[a]阵营英雄，使[b]目标的[c]属性临时[d]改变[e]
    [289] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]  --5  
        local b = args[2]  --1
        local c = args[3]  --23
        local d = args[4]  --3
        local e = args[5]  --0.03
       --RoleManager.LogArgs("289",args)
        BattleLogic.WaitForTrigger(interval, function ()
            if tarIdx == 1 then            
                local list = RoleManager.Query(function (r) 
                        return r.camp == caster.camp                  
                 end)
                local changeProperty = function(_role, _a, _b, _c, _d)
                    -- local buff = Buff.Create(caster, BuffName.PropertyChange, _a, BattlePropList[_b], _d, _c)
                    -- _role:AddBuff(buff)
                    -- buff:OnTrigger()
                   -- LogError("id:".._role.roleId)
                    BattleUtil.AddProp(_role, _b, _c, _d)
                    BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function ()
                        if not _role:IsRealDead() then
                            BattleUtil.RevertProp(_role, _b, _c, _d)
                        end
                    end)                        
                end
                for k, _v in ipairs(list) do
                    if _v.roleData.element == a then
                        if b == 1 then
                            changeProperty(target, 1, c, e, d)
                        elseif b == 2 then
                            if tarIdx == 1 then
                                changeProperty(caster, 1, c, e, d)
                            end
                        end
                       
                    end
                end
            end
            
        end)
    end,

    --> 南蛮入侵
    --> 造成[a]%的[b]伤害，[c]%概率对血量百分比最低的目标伤害提升[d]%，[e]%概率对血量百分比最高的目标附加[f]控制状态[g]回合
    --> a[float] b[伤害类型] c[float] d[float] e[float] f[控制状态] g[int]
    [290] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      
        local g = args[7]


        local arr1 = BattleUtil.ChooseTarget(target, 100210)
        local arr2 = BattleUtil.ChooseTarget(target, 100220)

        BattleLogic.WaitForTrigger(interval, function ()
            local isTrigger = BattleUtil.RandomAction(c, function()
               
                if arr1[1] and arr1[1] == target then
                    local OnPassiveDamaging = function(damagingFunc, defRole, damage)
                        damagingFunc(-floor(BattleUtil.FP_Mul(d, damage)))
                    end
                    caster.Event:AddEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
                    BattleUtil.CalDamage(skill, caster, target, b, a)
                    caster.Event:RemoveEvent(BattleEventName.PassiveDamaging, OnPassiveDamaging)
                else
                    BattleUtil.CalDamage(skill, caster, target, b, a)
                end
            end)      
            if not isTrigger then
                BattleUtil.CalDamage(skill, caster, target, b, a)
            end
            
            if arr2[1] and arr2[1] == target then
                BattleUtil.RandomControl(e, f, caster, target, g)
            end 

        end)
    end,

    --> 按dot加属性
    --> 若目标有[a] or [b] 持续伤害状态,则[c]目标类型的[d]属性[e]改变类型[f]%
    --> a b [持续伤害状态] c [目标类型] d[属性] e[改变类型] f[float]
    [291] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        BattleLogic.WaitForTrigger(interval, function ()
            local isHave = BattleLogic.BuffMgr:HasBuff(target, BuffName.DOT, function(buff)
                return buff.damageType == a or buff.damageType == b
            end)

            if isHave then
                local changeProperty = function(_role,  prop, value, ct) 

                    BattleUtil.AddProp(_role, prop, value, ct)

                    local function disbuff() 

                        BattleUtil.RevertProp(_role, prop, value, ct)
                        caster.Event:RemoveEvent(BattleEventName.RoleTurnEnd,disbuff)
                    end
                    --修改到本回合结束 RoleTurnEnd
                    caster.Event:AddEvent(BattleEventName.RoleTurnEnd,disbuff)

                end
                if c == 1 then
                    changeProperty(target, d, f, e)
                elseif c == 2 then
                    if tarIdx == 1 then
                        changeProperty(caster, d, f, e)
                    end
                end
            end
        end)
    end,

    --> 加属性
    --> [a]概率使[b]目标的[c]属性[d]型改变（ 自身[e]属性[f]倍值），持续[g]回合
    [292] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2] 
        local c = args[3]
        local d = args[4]
        local e = args[5]
        local f = args[6]
        local g = args[7]
        -- LogError(string.format("[%s]概率使[%s]目标的[%s]属性[%s]型改变（自身[%s]属性[%s]倍值），持续[%s]回合", a, b, c, d, e, f, g))
        BattleLogic.WaitForTrigger(interval, function () 
            -- LogError("effect!!")
            BattleUtil.RandomAction(a, function()         
                local changeProperty = function(_role, _prop, _changetype,_value,_round) 
                    -- LogError(_role.roleId..":属性".._prop .."---"..BattlePropList[_prop]..":值".._value..":改变类型".._changetype)
                    local buff = Buff.Create(caster, BuffName.PropertyChange, _round,BattlePropList[_prop], _value, _changetype)
                    _role:AddBuff(buff)
                end
                local val = floor(BattleUtil.FP_Mul(caster:GetRoleData(BattlePropList[e]), f))
                -- LogError(caster:GetRoleData(BattlePropList[e]).."    "..val)
                if b == 1 then
                    changeProperty(target, c, d, val, g)
                elseif b == 2 then
                    if tarIdx == 1 then
                        changeProperty(target, c, d, val, g)
                    end
                end
             end)            
        end)
    end,

    --> 瞬间为目标恢复等同自身[a]属性[b]%的生命值和目标[c]属性[d]%的生命值,若目标生命比例低于[e]%,则治疗效果提升[f]%
    [293] = function (tarIdx, caster, target, args, interval, skill)
        local a = args[1]--属性
        local b = args[2]--生命值
        local c = args[3]--属性
        local d = args[4]--生命值
        local e = args[5]--生命比例
        local f = args[6]--治疗效果
        
        BattleLogic.WaitForTrigger(interval/SkillEffectFirstPropty.First, function ()
            local treat = floor(caster:GetRoleData(BattlePropList[a]) * b) + floor(target:GetRoleData(BattlePropList[c]) * d)
            local hpPer = target:GetRoleData(RoleDataName.Hp) / target:GetRoleData(RoleDataName.MaxHp)
            if hpPer < e then
                treat = treat * (1 + f)
            end
            BattleUtil.CalTreat(caster, target, treat)
        end)
    end,

    --> 若目标剩余生命百分比低于[a]%, 则给目标不屈意志状态
    --> (当目标在没有"禁止复活"状态时死亡会立即复活, 并获得[b]属性[c]%的生命值, 全场战斗只触发一次)，持续d回合。
    --> 然后再为目标恢复等同自身[e]属性[f]%的生命值和目标[g]属性[h]%的生命值
    [294] = function (tarIdx, caster, target, args, interval, skill)
        local a = args[1]--目标生命百分比
        local b = args[2]--属性
        local c = args[3]--生命百分比
        local d = args[4]--回合
        local e = args[5]--属性
        local f = args[6]--生命百分比
        local g = args[7]--目标的属性
        local h = args[8]--生命百分比

        BattleLogic.WaitForTrigger(interval, function ()
            if BattleLogic.BuffMgr:HasBuff(target, BuffName.Brand, function (buff)
                    return buff.flag == BrandType.buquyizhi
                end) then
            else
                -- LogError(target.roleId..":"..target:GetRoleData(RoleDataName.Hp)/target:GetRoleData(RoleDataName.MaxHp).."<"..a)
                if target:GetRoleData(RoleDataName.Hp)/target:GetRoleData(RoleDataName.MaxHp) < a then
                    -- LogError("附加")
                    local buff = Buff.Create(caster, BuffName.Brand, d, BrandType.buquyizhi)
                    buff.clear = false
                    target:AddBuff(buff)

                    local OnRoleRealDead = nil
                    OnRoleRealDead = function(deadRole)
                        target.Event:RemoveEvent(BattleEventName.RoleRealDead, OnRoleRealDead)
                        if target.effect280times == 0 then 
                            local maxHp = target:GetRoleData(RoleDataName.MaxHp)
                            local blood = floor(target:GetRoleData(BattlePropList[b]) * c)
                            target:SetRelive(math.min(blood / maxHp, 1))
                            -- LogError("复活："..blood.."/"..maxHp)
                            target.effect280times = target.effect280times - 1
                        end
                    end
                    target.Event:AddEvent(BattleEventName.RoleRealDead, OnRoleRealDead)
                end
            end
            local treat = floor(caster:GetRoleData(BattlePropList[e]) * f) + floor(target:GetRoleData(BattlePropList[g]) * h)
            BattleUtil.CalTreat(caster, target, treat)
        end)
    end,

    --[a]概率随机从免伤降低[b]、抗暴降低[c]、暴击降低[d]3个负面状态中选择[e]个状态给目标，持续[f]回合
    --a[float],b[float],c[float],d[float],e[int],f[int]
    [295] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]--概率
        local b = args[2]--免伤降低
        local c = args[3]--抗暴降低
        local d = args[4]--暴击降低
        local e = args[5]--状态数量
        local f = args[6]--回合
        BattleLogic.WaitForTrigger(interval, function ()
            BattleUtil.RandomAction(a, function()
                local randState = {
                    RoleDataName.DamageReduceFactor,
                    RoleDataName.Tenacity,
                    RoleDataName.Crit,
                }
                local coefficient = {
                    b, c, d
                }
                local rs = {1, 2, 3}
                local randList = {}
                for i = 1, min(e, 3) do
                    local idx = Random.RangeInt(1, #rs)
                    table.insert(randList, rs[idx])
                    table.remove(rs, idx)
                end
                for i = 1, #randList do
                    local buff = Buff.Create(caster, BuffName.PropertyChange, f, randState[randList[i]], coefficient[randList[i]], 3)
                    target:AddBuff(buff)
                end
            end)
        end)
    end,

    --目标携带负面状态数量大于增益状态数量时，每多1个负面状态，额外造成目标[a]属性[b]倍的伤害，伤害最大不超过施法者[c]属性[d]倍
    --a[float],b[float],c[float],d[float]
    [296] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]--目标属性
        local b = args[2]--倍数
        local c = args[3]--施法者属性
        local d = args[4]--倍数
        BattleLogic.WaitForTrigger(interval, function ()
            local buff = BattleLogic.BuffMgr:GetBuff(target)
            local buffNum = 0
            local dbuffNum = 0
            for i = 1, #buff do
                if buff[i].isBuff then
                    buffNum = buffNum + 1
                elseif buff[i].isDeBuff then
                    dbuffNum = dbuffNum + 1
                end
            end
            if dbuffNum > buffNum then
                local hurt = floor(target:GetRoleData(BattlePropList[a]) * b * (dbuffNum - buffNum))
                local maxHurt = floor(caster:GetRoleData(BattlePropList[c]) * d)
                if hurt > maxHurt then
                    hurt = maxHurt
                end
                BattleUtil.ApplyDamage(skill, caster, target, hurt)
            end
        end)
    end,

    --给目标添加“连接”效果：携带“连接”效果的目标中，任意一个目标受到伤害，其它目标都会受到[a]%的伤害（该伤害不可被分摊和闪避）
    --a[float]
    [297] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]--伤害系数
        BattleLogic.WaitForTrigger(interval, function ()
            -- target:AddBuff(Buff.Create(caster, BuffName.Bond, 0, a))
            -- LogError("给目标添加“连接”效果")
        end)
    end,

    --对目标造成[a]的[b]类型伤害，和此目标“链接”、分摊伤害的目标受到等同[c]%的附加伤害（该伤害不可再次被分摊和闪避）
    --a[技能系数float],b[伤害类型],c[float]
    [298] = function(tarIdx, caster, target, args, interval, skill)
        local a = args[1]
        local b = args[2]
        local c = args[3]
        BattleLogic.WaitForTrigger(interval, function ()
            local list = RoleManager.Query(function(r)
                return r.camp == target.camp
            end)

            -- local finalDmg, bCrit, dmg = BattleUtil.CalDamage(skill, caster, target, b, a)
            -- for i = 1, #list do
            --     local buff = BattleLogic.BuffMgr:GetBuff(list[i])
            --     for j = 1, #buff do
            --         if buff[j] == BuffName.Bond then
            --             if not list[i]:IsDead() then
            --                 BattleUtil.ApplyDamage(skill, caster, list[i], floor(dmg * c))
            --             end
            --         end
            --     end
            -- end
            -- LogError("对目标造成[a]的[b]类型伤害")
        end)
    end
}

return effectList