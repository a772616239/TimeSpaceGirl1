local effect = require("Modules/Battle/Logic/Base/Effect")
local floor = math.floor
local max = math.max
local min = math.min
--local BattleConst = BattleConst
--local RoleDataName = RoleDataName
--local BattleEventName = BattleEventName

-- local CombatControl = ConfigManager.GetConfig(ConfigName.CombatControl)

local effectPool = BattleObjectPool.New(function ()
    return { type = 0, args = {}}  -- type, {args, ...}
end)
local effectGroupPool = BattleObjectPool.New(function ()
    return { chooseId = 0, effects = {}} -- chooseId, {effect1, effect2, ...}
end)

Skill = {}

function Skill:New()
    local o = {cd=0,effectList = BattleList.New(),owner=0,sp=0,spPass=0,isTeamSkill=false,teamSkillType=0 }
    setmetatable(o, self)
    self.__index = self
    return o
end

function Skill:Init(role, effectData, type, targets, isAdd, skillSubType) --type 0 异妖 1 点技 2 滑技
    local isTeamSkill = type == 0
    self.type = type
    --skill = {技能ID, 命中时间, 持续时间, 伤害次数, {目标id1, 效果1, 效果2, ...},{目标id2, 效果3, 效果4, ...}, ...}
    --效果 = {效果类型id, 效果参数1, 效果参数2, ...}
    self.effectList:Clear()
    self.owner = role
    self.isTeamSkill = isTeamSkill
    self.teamSkillType = isTeamSkill and floor(effectData[1] / 100) or 0
    self.id = tonumber(effectData[1])             -- 技能ID
    self.hitTime = effectData[2]        -- 效果命中需要的时间
    self.continueTime = effectData[3]   -- 命中后伤害持续时间
    self.attackCount = effectData[4]    -- 伤害持续时间内伤害次数
    -- self.ReturnTime = CombatControl[self.id].ReturnTime
    self.ReturnTime = effectData[5]     --< 技能总时长
    self.CastBullet = effectData[6]     --< 技能释放时间点 起点为动作开始
    self.repeatAttackTimes = effectData[7]      --< 技能伤害次数
    --> ext参数
    self.ext_slot = effectData[8].slot      --< 技能槽位
    self.isCannon = effectData[8].isCannon  --< 技能表现是否为开炮类型
    --> leader 主角专属
    self.sort = effectData[8].sort      --< 技能释放回合
    self.cd = effectData[8].cd
    self.release = effectData[8].release
    
    self.targets = targets or {}
    self.isAdd = isAdd
    -- self.isRage = isRage
    if skillSubType then
        self.skillSubType = skillSubType
    else
        self.skillSubType = SkillSubType.Normal
    end

    self.totalDmg = {}

    for i=9, #effectData do
        local v = effectData[i]
        local effectGroup = effectGroupPool:Get() -- chooseId, {effect1, effect2, ...}
        effectGroup.chooseId = v[1] -- chooseId
        for j=2, #v do -- effectList
            local effect = effectPool:Get() -- type, {args, ...}
            effect.type = v[j][1]
            for k=2, #v[j] do
                effect.args[k-1] = v[j][k]
            end
            effectGroup.effects[j-1] = effect
        end
        self.effectList:Add(effectGroup)
    end
    --> skillArray={{50201,0.3,{0},1,1200,0,1,{cd=0,isCannon=1,release=1,slot=0},{400000,{1,1,2}}}
end

function Skill:Dispose()
    while self.effectList.size > 0 do
        local effectGroup = self.effectList.buffer[self.effectList.size]
        for k=1, #effectGroup.effects do
            local effect = effectGroup.effects[k]
            for j=1, #effect.args do
                effect.args[j] = nil
            end
            effectPool:Put(effect)
            effectGroup.effects[k] = nil
        end
        effectGroupPool:Put(effectGroup)
        self.effectList:Remove(self.effectList.size)
    end
end

local function DoEffect(tarIdx, caster, target, eff, duration, skill)
    local e = {type = 0, args = {}}
    e.type = eff.type
    for i=1, #eff.args do
        e.args[i] = eff.args[i]
    end

    -- 检测被动技能对技能参数的影响
    local function _PassiveCheck(pe)
        if pe then
            e = pe
        end
    end
    caster.Event:DispatchEvent(BattleEventName.SkillEffectBefore, skill, e, _PassiveCheck, tarIdx)
    target.Event:DispatchEvent(BattleEventName.BeSkillEffectBefore, skill, e, _PassiveCheck, tarIdx)

    -- 
    
    
    
    if effect[e.type] then
        effect[e.type](tarIdx, caster, target, e.args, duration, skill)
        
        -- local arg=""
        -- for i,ar in pairs(e.args) do 
        --     arg = arg.." "..i..": "..ar
        -- end

        -- BattleLogManager.Log(
        --     "Take Effect idx:"..tarIdx.." "..arg.." du:"..duration,
        --     "tcamp", target.camp,
        --     "tpos", target.position,
        --     "type", e.type
        -- )
    end
end

function Skill:takeEffect(tarIdx, caster, target, effects, effectIndex, duration, skill)
    for k=1, #effects do
        -- 如果不是第一个效果对列的第一个效果则判断是否命中
        if k ~= 1 and effectIndex == 1 then
            if self:CheckTargetIsHit(target) or self:CheckEffectExecute(effects[k].type) then
                DoEffect(tarIdx, caster, target, effects[k], duration + (k-1)*BattleLogic.GameDeltaTime, skill)
            end
        else
            if self:CheckTargetIsHit(target) or self:CheckEffectExecute(effects[k].type) then
                DoEffect(tarIdx, caster, target, effects[k], duration, skill)
            end
        end
    end
end

--检测技能效果的执行(和策划规定 技能闪避后 只有伤害类型的效果才飘闪避,其他附加效果不执行)
function Skill:CheckEffectExecute(effectId)
    --219  269  250  285     1     10    244
    local isHitEffect = effectId == 219 
                        or effectId == 269 
                        or effectId == 250 
                        or effectId == 285
                        or effectId == 1 
                        or effectId == 10 
                        or effectId == 244 
    return isHitEffect
    
end

--和策划约定阵上只有一个英雄时释放技能的对象为己方所有人而攻击目标是除自己外的逻辑互斥
function Skill:CheckSkillChooseId(chooseId, targets, role)
    local chooseType = floor(chooseId / 100000) % 10
    local chooseLimit = floor(chooseId / 10000) % 10

    if chooseType == 1 and chooseLimit == 8 and #targets == 1 then
        if targets[1].roleId == role.roleId then
            return false
        end
    end

    return true
end

-- 释放技能
-- func     技能释放完成回调
function Skill:Cast(func)
    -- if self.isCannon ~= 0 then
    --     self:CastOneByOne(func)
    --     return
    -- end
    local chooseId = self.effectList.buffer[1].chooseId
    if chooseId then
        local sort = floor(chooseId / 10) % 10
        if sort == 3 then
            self:CastOneByOne(func)
            return
        end
    end

    self.castDoneFunc = func

    --
    -- BattleLogManager.Log(
    --     "Cast Skill",
    --     "camp", self.owner.camp,
    --     "pos", self.owner.position,
    --     "type", self.type,
    --     -- "isRage", tostring(self.isRage),
    --     "isAdd", tostring(self.isAdd)
    -- )

    
    

    local repeatTimes = self.repeatAttackTimes or 1  --< 多段
    repeatTimes = math.max(1, repeatTimes)  --< repeatTimes need > 1

    --> 单次攻击 可能多个目标
    local function AttackOnce()
        self.effectTargets = {}
        self.targetIsHit = {}
        
        
        -- 先计算出技能的目标
        for i=1, self.effectList.size do
            -- 是否重新选择目标
            local isReTarget = true
            if self.targets and self.targets[i] then
                self.effectTargets[i] = self.targets[i]
                -- 判断是否有有效目标
                for _, role in ipairs(self.effectTargets[i]) do
                    
                    
                    if role and role.IsRealDead then
                        if not role:IsRealDead() then
                            isReTarget = false
                        end
                    end
                end

                --> 传参形式目标固定 直接下一轮技能 主针对怒气 todo
                if isReTarget then
                    self:EndSkill()
                    return
                end
            end
            -- 重新选择目标a
            if isReTarget then
                local effectGroup = self.effectList.buffer[i]
                local chooseId = effectGroup.chooseId

                self.effectTargets[i] = {}
                self.effectTargets[i] = BattleUtil.ChooseTarget(self.owner, chooseId)
                -- 检测被动对攻击目标的影响
                
                if i == 1 then
                    local function _PassiveTarget(targets)
                        
                        
                        self.effectTargets[i] = targets
                    end
                    self.owner.Event:DispatchEvent(BattleEventName.SkillTargetCheck, _PassiveTarget, self)
                end
            end
        end
        
        -- 对目标造成相应的效果
        for i=1, self.effectList.size do
            local effectGroup = self.effectList.buffer[i]
            local chooseId = effectGroup.chooseId
            local arr = self.effectTargets[i]
            
            
            
            if arr and #arr > 0 and self:CheckSkillChooseId(chooseId, arr, self.owner) then
                
                
                
                -- for _, role in pairs(arr) do
                
                -- end
                
                -- 效果延迟1帧生效
                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                    local effects = effectGroup.effects
                    -- local weight = floor(chooseId % 10000 / 100) 
                    local count = #arr--min(chooseId % 10, #arr)
                    if count == 0 then
                        count = #arr
                    end
                    
                    
                    -- 全部同时生效
                    for j=1, count do
                        local funcHit = function()
                            --if arr[j] and not arr[j]:IsRealDead() then  
                            if arr[j] then  
                                -- 检测是否命中
                                if i == 1 then
                                    self.targetIsHit[arr[j]] = BattleUtil.CheckIsHit(self.owner, arr[j]) 

                                    if j == 1 then--< 技能第一效果到位时触发 在效果前触发
                                        BattleLogic.WaitForTrigger(self.hitTime, function ()
                                            self.owner.Event:DispatchEvent(BattleEventName.SkillFirstEffectTrigger, self)
                                        end)
                                    end

                                    if j == count then
                                        BattleLogic.WaitForTrigger(self.hitTime, function ()
                                            self.owner.Event:DispatchEvent(BattleEventName.SkillLastEffectTrigger, self)
                                        end)
                                    end
                                else
                                    self.targetIsHit[arr[j]] = BattleUtil.CheckIsHit(self.owner, arr[j]) 
                                end
                                
                                
                                if i ~= 1 then
                                    self:takeEffect(j, self.owner, arr[j], effects, i, 0, self, chooseId)
                                else
                                    self:takeEffect(j, self.owner, arr[j], effects, i, self.hitTime, self, chooseId)
                                end
                                
                            end
                        end

                        --> 第一作用效果 有延时     第二效果后全部技能开始时触发
                        if i == 1 then
                            --> 不开炮类型
                            if self.isCannon == 0 then
                                funcHit()
                            else
                                BattleLogic.WaitForTrigger(self.ReturnTime / 1000 * (j - 1), function()
                                    funcHit()    
                                end)
                            end
                        else
                            funcHit()
                        end
                        
                    end

                    -- self.totalDmg = {}
                    -- local function floatTotalDmg(idx)
                    --     if not self.totalDmg[idx] then
                    --         return
                    --     end
                    --     local totalnum = 0
                    --     for i = 1, #self.totalDmg do
                    --         totalnum = totalnum + self.totalDmg[i]
                    --     end
                    --     BattleLogic.Event:DispatchEvent(BattleEventName.FloatTotal, totalnum)
                    -- end
                    -- BattleLogic.WaitForTrigger(self.hitTime, function ()
                    --     if self.totalDmg then
                    --         if self.attackCount ~= 1 then

                    --             for i = 1, #self.continueTime do
                    --                 local time = 0
                    --                 for j = 1, i do
                    --                     time = time + self.continueTime[j] / 1000
                    --                 end
                    --                 BattleLogic.WaitForTrigger(time, function()
                    --                     floatTotalDmg(i + 1)
                    --                 end)
                    --             end
                    --             floatTotalDmg(1)
                    --         else
                    --             floatTotalDmg(1)
                    --         end
                    --     end
                        
                    -- end)

                end)
            end
        end

        -- if self.isTeamSkill then
        --     self.owner.curSkill = self
        -- end
        
        -- 释放技能开始
        -- self.owner.Event:DispatchEvent(BattleEventName.SkillCast, self)
        -- BattleLogic.Event:DispatchEvent(BattleEventName.SkillCast, self)

        self.owner.Event:DispatchEvent(BattleEventName.SkillCast, self)
        BattleLogic.Event:DispatchEvent(BattleEventName.SkillCast, self)
        
        local targetNum = #self.effectTargets[1]

        if not self.owner.ctrl_chaos or self.owner.ctrl_chaos_beatBack then   --< 混乱状态不表现（除了混乱状态中的反击）

            self.owner.ctrl_chaos_beatBack = false

            if self.isCannon == 0 then
                self.owner.Event:DispatchEvent(BattleEventName.SkillFireAll, self)
            else
                
                for i = 1, targetNum do
                    BattleLogic.WaitForTrigger(self.ReturnTime / 1000 * (i - 1), function()
                        self.owner.Event:DispatchEvent(BattleEventName.SkillFireOnce, self, i)
                    end)
                end
            end

        end
        
        
        
        -- 只对效果1的目标发送事件，效果1是技能的直接伤害目标
        -- for _, tr in ipairs(self.effectTargets[1]) do
        --     tr.Event:DispatchEvent(BattleEventName.BeSkillCast, self)
        -- end
        local EndSkillProcess = function()
            self.owner.Event:DispatchEvent(BattleEventName.SkillCastEnd, self)
            BattleLogic.Event:DispatchEvent(BattleEventName.SkillCastEnd, self)

            -- 只对效果1的目标发送事件，效果1是技能的直接伤害目标
            for _, tr in ipairs(self.effectTargets[1]) do
                tr.Event:DispatchEvent(BattleEventName.BeSkillCastEnd, self)
            end
            -- 技能结束
            self:EndSkill()
        end

        if self.isCannon == 0 then
            BattleLogic.WaitForTrigger(self.ReturnTime / 1000, function()
                EndSkillProcess()
            end)
        else
            BattleLogic.WaitForTrigger(self.ReturnTime / 1000 * targetNum, function()
                repeatTimes = repeatTimes - 1
                if repeatTimes == 0 then
                    EndSkillProcess()
                else
                    AttackOnce()
                end
            end)
        end
        


        
    end

    self.owner.Event:DispatchEvent(BattleEventName.SkillSelectBefore, self)
    AttackOnce()
end

-- func     技能释放完成回调
function Skill:CastUnit(func)
    self.castDoneFunc = func

    local function SkillPlay()
        self.effectTargets = {}
        self.targetIsHit = {}
        -- 先计算出技能的目标
        for i=1, self.effectList.size do
            -- 是否重新选择目标
            local isReTarget = true
            if self.targets and self.targets[i] then
                self.effectTargets[i] = self.targets[i]
                -- 判断是否有有效目标
                for _, role in ipairs(self.effectTargets[i]) do
                    if role and role.IsRealDead then
                        if not role:IsRealDead() then
                            isReTarget = false
                        end
                    end
                end

                --> 传参形式目标固定 直接下一轮技能 主针对怒气 todo
                if isReTarget then
                    self:EndSkill()
                    return
                end
            end
            -- 重新选择目标a
            if isReTarget then
                local effectGroup = self.effectList.buffer[i]
                local chooseId = effectGroup.chooseId

                self.effectTargets[i] = {}
                self.effectTargets[i] = BattleUtil.ChooseTarget(self.owner, chooseId)
                -- 检测被动对攻击目标的影响
                if i == 1 then
                    local function _PassiveTarget(targets)
                        self.effectTargets[i] = targets
                    end
                    self.owner.Event:DispatchEvent(BattleEventName.SkillTargetCheck, _PassiveTarget, self)
                end
            end
        end
        

        -- 对目标造成相应的效果
        for i=1, self.effectList.size do
            local effectGroup = self.effectList.buffer[i]
            local chooseId = effectGroup.chooseId
            local arr = self.effectTargets[i]
            if arr and #arr > 0 then
                
                -- 效果延迟1帧生效
                BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                    local effects = effectGroup.effects
                    -- local weight = floor(chooseId % 10000 / 100)
                    local count = min(chooseId % 10, #arr)
                    if count == 0 then
                        count = #arr
                    end
                    -- 全部同时生效
                    for j=1, count do
                        if arr[j] and not arr[j]:IsRealDead() then  
                            -- 检测是否命中
                            if i == 1 then
                                self.targetIsHit[arr[j]] = BattleUtil.CheckIsHit(self.owner, arr[j]) 

                                if j == 1 then--< 技能第一效果到位时触发 在效果前触发
                                    BattleLogic.WaitForTrigger(self.hitTime, function ()
                                        self.owner.Event:DispatchEvent(BattleEventName.SkillFirstEffectTrigger, self)
                                    end)
                                end

                                if j == count then
                                    BattleLogic.WaitForTrigger(self.hitTime, function ()
                                        self.owner.Event:DispatchEvent(BattleEventName.SkillLastEffectTrigger, self)
                                    end)
                                end
                            end
                            if i ~= 1 then
                                self:takeEffect(j, self.owner, arr[j], effects, i, 0, self)
                            else
                                self:takeEffect(j, self.owner, arr[j], effects, i, self.hitTime, self)
                            end
                        end
                    end
                end)
            end
        end

        self.owner.Event:DispatchEvent(BattleEventName.SkillCast, self)
        BattleLogic.Event:DispatchEvent(BattleEventName.SkillCast, self)
        

        
        local EndSkillProcess = function()
            self.owner.Event:DispatchEvent(BattleEventName.SkillCastEnd, self)
            BattleLogic.Event:DispatchEvent(BattleEventName.SkillCastEnd, self)

            -- 只对效果1的目标发送事件，效果1是技能的直接伤害目标
            for _, tr in ipairs(self.effectTargets[1]) do
                tr.Event:DispatchEvent(BattleEventName.BeSkillCastEnd, self)
            end
            -- 技能结束
            self:EndSkill()
        end


        BattleLogic.WaitForTrigger(self.ReturnTime / 1000, function()

            EndSkillProcess()

        end)


        
    end


    SkillPlay()
end

-- 释放技能
-- func     技能释放完成回调
function Skill:CastOneByOne(func)
    self.castDoneFunc = func

    --
    -- BattleLogManager.Log(
    --     "Cast Skill",
    --     "camp", self.owner.camp,
    --     "pos", self.owner.position,
    --     "type", self.type,
    --     "isAdd", tostring(self.isAdd)
    -- )

    self.effectTargets = {}
    self.targetIsHit = {}


    self.beEndTargets = {}
    self.hit3TimesCheck = {}    --< 3次攻击限定
    self.excludeAttackList = {}
    local effectGroup = self.effectList.buffer[1]
    local chooseId = effectGroup.chooseId
    local targets = BattleUtil.ChooseTarget(self.owner, chooseId)

    --> 2+...目标组效果
    for i = 2, self.effectList.size do
        local effectGroup = self.effectList.buffer[i]
        local chooseId = effectGroup.chooseId
        self.effectTargets[i] = BattleUtil.ChooseTarget(self.owner, chooseId)
        local arr = self.effectTargets[i]
        if arr and #arr > 0 then
            -- 效果延迟1帧生效
            BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                local effects = effectGroup.effects
                local count = min(chooseId % 10, #arr)
                if count == 0 then
                    count = #arr
                end
                -- 全部同时生效
                for j = 1, count do
                    if arr[j] then
                        --> 此处非第一组目标效果都在 hitTime 时触发所有（可改为0释放时即触发 未改因为可能策划有填hitTime时触发的2+...效果 如没有可改0）
                        self:takeEffect(j, self.owner, arr[j], effects, i, 0, self)
                    end
                end
            end)
        end
    end

    self.owner.Event:DispatchEvent(BattleEventName.SkillCast, self)
    BattleLogic.Event:DispatchEvent(BattleEventName.SkillCast, self)

    
    local targetNum = #targets
    if self.targets and self.targets[1] then
        targetNum = #self.targets[1]
    end
    
    for i = 1, targetNum do
        BattleLogic.WaitForTrigger(self.ReturnTime / 1000 * (i - 1), function()
            local sort = floor(chooseId / 10) % 10
            local target = BattleUtil.ChooseOneTarget(self.owner, chooseId, self.excludeAttackList)

            local function ReTarget(targets)
                for i = 1, #targets do
                    local isHave = false
                    for j = 1, #self.excludeAttackList do
                        if targets[i] == self.excludeAttackList[j] then
                            isHave = true
                            break
                        end
                    end
                    if not isHave and not targets[i]:IsRealDead() then  --< 无重复&未死亡 死亡按原有选择目标
                        target = targets[i]
                        break
                    end
                end
            end

            if self.targets and self.targets[1] then
                ReTarget(self.targets[1])
            end

            -- 检测被动对攻击目标的影响
            local function _PassiveTarget(targets)
                ReTarget(targets)
            end
            self.owner.Event:DispatchEvent(BattleEventName.SkillTargetCheck, _PassiveTarget, self)

            if sort ~= 3 then
                table.insert(self.excludeAttackList, target)
            else
                --> 单体攻击限定3次内
                if self.hit3TimesCheck[target] == nil then
                    self.hit3TimesCheck[target] = 0
                end
                self.hit3TimesCheck[target] = self.hit3TimesCheck[target] + 1
                if self.hit3TimesCheck[target] >= 3 then
                    table.insert(self.excludeAttackList, target)
                end
            end
            if target then
                self.beEndTargets[target] = target
            end
            
            
            --> 第一目标组效果
            self.effectTargets[1] = {target}
            -- 效果延迟1帧生效
            BattleLogic.WaitForTrigger(BattleLogic.GameDeltaTime, function()
                local effects = effectGroup.effects
                if self.effectTargets[1][1] then  
                    -- 检测是否命中
                    self.targetIsHit[self.effectTargets[1][1]] = BattleUtil.CheckIsHit(self.owner, self.effectTargets[1][1]) 
                    self:takeEffect(i, self.owner, target, effects, 1, self.hitTime, self)
                end
            end)
            
            if not self.owner.ctrl_chaos then   --< 混乱状态不表现
                self.owner.Event:DispatchEvent(BattleEventName.SkillFireOnce, self, 1)
            end
        end)
    end

    local EndSkillProcess = function()
        self.owner.Event:DispatchEvent(BattleEventName.SkillCastEnd, self)
        BattleLogic.Event:DispatchEvent(BattleEventName.SkillCastEnd, self)

        -- 只对效果1的目标发送事件，效果1是技能的直接伤害目标
        for _, tr in pairs(self.beEndTargets) do
            tr.Event:DispatchEvent(BattleEventName.BeSkillCastEnd, self)
        end
        -- 技能结束
        self:EndSkill()
    end


    BattleLogic.WaitForTrigger(self.ReturnTime / 1000 * targetNum, function()
        EndSkillProcess()
    end)

    
end


-- 获取技能的直接目标，和策划规定第一个效果的目标为直接效果目标,(包含miss的目标)
function Skill:GetDirectTargets()
    return self.effectTargets[1]
end
-- 获取直接目标，不包含miss的目标，可能为空
function Skill:GetDirectTargetsNoMiss()
    local list = {}
    for _, role in ipairs(self.effectTargets[1]) do
        if self:CheckTargetIsHit(role) then
            table.insert(list, role)
        end
    end
    return list
end
-- 获取技能目标最大人数
function Skill:GetMaxTargetNum()
    local mainEffect = self.effectList.buffer[1]
    if not mainEffect then
        return 0
    end
    return BattleUtil.GetMaxTargetNum(mainEffect.chooseId)
end

-- 判断是否命中
function Skill:CheckTargetIsHit(role)
    return self.targetIsHit[role]
end

--强制设置技能命中
function Skill:SetRoleListAsHit(rolelist)
    if #rolelist > 0 then
        for index, role in ipairs(rolelist) do
            self.targetIsHit[role] = true
        end
    end
end

-- 结束技能
function Skill:EndSkill()
    -- 技能后摇
    -- 技能结束后摇后结束技能释放
    BattleLogic.WaitForTrigger(0.3, function()
        -- 结束回调
        if self.castDoneFunc then self.castDoneFunc() end
        
    end)
    -- 
    self.effectTargets = {}
end