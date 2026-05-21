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

function Skill:Init(role, effectData, type, targets, isAdd) --type 0 异妖 1 点技 2 滑技
    local isTeamSkill = type == 0
    self.type = type
    --skill = {技能ID, 命中时间, 持续时间, 伤害次数, {目标id1, 效果1, 效果2, ...},{目标id2, 效果3, 效果4, ...}, ...}
    --效果 = {效果类型id, 效果参数1, 效果参数2, ...}
    self.effectList:Clear()
    self.owner = role
    self.isTeamSkill = isTeamSkill
    self.teamSkillType = isTeamSkill and floor(effectData[1] / 100) or 0
    self.id = effectData[1]             -- 技能ID
    self.hitTime = effectData[2]        -- 效果命中需要的时间
    self.continueTime = effectData[3]   -- 命中后伤害持续时间
    self.attackCount = effectData[4]    -- 伤害持续时间内伤害次数
    -- self.ReturnTime = CombatControl[self.id].ReturnTime
    self.ReturnTime = effectData[5]     --< 技能总时长
    self.CastBullet = effectData[6]     --< 技能释放时间点 起点为动作开始
    self.repeatAttackTimes = effectData[7]      --< 技能伤害次数
    --> ext参数
    self.ext_slot = effectData[8].slot  --< 技能槽位        

    self.targets = targets or {}
    self.isAdd = isAdd
    -- self.isRage = isRage

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

local function DoEffect(caster, target, eff, duration, skill)
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
    caster.Event:DispatchEvent(BattleEventName.SkillEffectBefore, skill, e, _PassiveCheck)
    target.Event:DispatchEvent(BattleEventName.BeSkillEffectBefore, skill, e, _PassiveCheck)

    -- 
    LogGreen("### DoEffect 作用点")
    LogGreen(duration)
    LogGreen(e.type)
    if effect[e.type] then
        effect[e.type](caster, target, e.args, duration, skill)

        BattleLogManager.Log(
            "Take Effect",
            "tcamp", target.camp,
            "tpos", target.position,
            "type", e.type
        )
    end
end

function Skill:takeEffect(caster, target, effects, effectIndex, duration, skill)
    for k=1, #effects do
        -- 如果不是第一个效果对列的第一个效果则判断是否命中
        if k ~= 1 and effectIndex == 1 then
            if self:CheckTargetIsHit(target) then
                DoEffect(caster, target, effects[k], duration, skill)
            end
        else
            DoEffect(caster, target, effects[k], duration, skill)
        end
    end
end

-- 释放技能
-- func     技能释放完成回调
function Skill:Cast(func)
    self.castDoneFunc = func

    --
    BattleLogManager.Log(
        "Cast Skill",
        "camp", self.owner.camp,
        "pos", self.owner.position,
        "type", self.type,
        -- "isRage", tostring(self.isRage),
        "isAdd", tostring(self.isAdd)
    )

    

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
                    if not role:IsRealDead() then
                        isReTarget = false
                    end
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
                        BattleLogic.WaitForTrigger(self.ReturnTime / 1000 * (j - 1), function()
                            if arr[j] and not arr[j]:IsRealDead() then  
                                -- 检测是否命中
                                if i == 1 then
                                    self.targetIsHit[arr[j]] = BattleUtil.CheckIsHit(self.owner, arr[j]) 
                                end
                                LogGreen("### takeEffect")
                                self:takeEffect(self.owner, arr[j], effects, i, self.hitTime, self)
                            end
                            
                        end)
                        -- if arr[j] and not arr[j]:IsRealDead() then  
                        --     -- 检测是否命中
                        --     if i == 1 then
                        --         self.targetIsHit[arr[j]] = BattleUtil.CheckIsHit(self.owner, arr[j]) 
                        --     end
                        --     self:takeEffect(self.owner, arr[j], effects, i, self.hitTime, self)
                        --     -- if i == 1 then
                        --     --     self.targetIsHit[arr[j]] = BattleUtil.CheckIsHit(self.owner, arr[j]) 
                        --     --     takeEffect(self.owner, arr[j], effects, self.hitTime, self)
                        --     -- else
                        --     --     -- 未命中的目标不会产生后续技能效果
                        --     --     if self:CheckTargetIsHit(arr[j]) then
                        --     --         takeEffect(self.owner, arr[j], effects, self.hitTime, self)
                        --     --     end
                        --     -- end
                        -- end
                    end

                    self.totalDmg = {}
                    local function floatTotalDmg(idx)
                        if not self.totalDmg[idx] then
                            return
                        end
                        local totalnum = 0
                        for i = 1, #self.totalDmg do
                            totalnum = totalnum + self.totalDmg[i]
                        end
                        BattleLogic.Event:DispatchEvent(BattleEventName.FloatTotal, totalnum)
                    end
                    BattleLogic.WaitForTrigger(self.hitTime, function ()
                        if self.totalDmg then
                            if self.attackCount ~= 1 then

                                for i = 1, #self.continueTime do
                                    local time = 0
                                    for j = 1, i do
                                        time = time + self.continueTime[j] / 1000
                                    end
                                    BattleLogic.WaitForTrigger(time, function()
                                        floatTotalDmg(i + 1)
                                    end)
                                end
                                floatTotalDmg(1)
                            else
                                floatTotalDmg(1)
                            end
                        end
                        
                    end)

                end)
            end
        end

        if self.isTeamSkill then
            self.owner.curSkill = self
        end
        
        -- 释放技能开始
        -- self.owner.Event:DispatchEvent(BattleEventName.SkillCast, self)
        -- BattleLogic.Event:DispatchEvent(BattleEventName.SkillCast, self)

        self.owner.Event:DispatchEvent(BattleEventName.SkillCast, self)
        BattleLogic.Event:DispatchEvent(BattleEventName.SkillCast, self)
        
        
        local targetNum = #self.effectTargets[1]
        for i = 1, targetNum do
            BattleLogic.WaitForTrigger(self.ReturnTime / 1000 * (i - 1), function()
                self.owner.Event:DispatchEvent(BattleEventName.SkillFireOnce, self, i)
            end)
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


        BattleLogic.WaitForTrigger(self.ReturnTime / 1000 * targetNum, function()
            repeatTimes = repeatTimes - 1
            if repeatTimes == 0 then
                EndSkillProcess()
            else
                AttackOnce()
            end
        end)


        
    end


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
                    if not role:IsRealDead() then
                        isReTarget = false
                    end
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
                            end
                            LogGreen("### takeEffect")
                            self:takeEffect(self.owner, arr[j], effects, i, self.hitTime, self)
                        end
                    end



                end)
            end
        end

        self.owner.Event:DispatchEvent(BattleEventName.SkillCast, self)
        BattleLogic.Event:DispatchEvent(BattleEventName.SkillCast, self)
        
        
        -- local targetNum = #self.effectTargets[1]
        -- for i = 1, targetNum do
        --     BattleLogic.WaitForTrigger(self.ReturnTime / 1000 * (i - 1), function()
        --         self.owner.Event:DispatchEvent(BattleEventName.SkillFireOnce, self, i)
        --     end)
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


        BattleLogic.WaitForTrigger(self.ReturnTime / 1000, function()

            EndSkillProcess()

        end)


        
    end


    SkillPlay()
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