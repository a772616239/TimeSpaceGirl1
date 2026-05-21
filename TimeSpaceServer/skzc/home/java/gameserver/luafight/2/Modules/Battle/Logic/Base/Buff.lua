Buff = {}
local floor = math.floor
local buffPoolList = {}

local getBuff = function(type)
    if not buffPoolList[type] then
        buffPoolList[type] = BattleObjectPool.New(function (type)
            return require("Modules/Battle/Logic/Buff/"..type):New()
        end)
    end
    return buffPoolList[type]:Get(type)
end

local putBuff = function(buff)
    if buffPoolList[buff.type] then
        buffPoolList[buff.type]:Put(buff)
    end
end

local buffListPool = BattleObjectPool.New(function ()
    return BattleList.New()
end)

function Buff:New()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Buff.Create(caster, type, duration, ...)
    local buff = getBuff(type)
    buff.type = type
    buff.id = BuffManager.GenerateBuffId()
    buff.caster = caster
    buff.disperse = false --该值为true时，buff在下一帧被清除
    buff.cover = false --该值为true时，同类型新buff会覆盖旧buff
    buff.clear = true --该值为false时,buff不可被驱散，除非无条件驱散

    buff.duration = duration or 0 --持续时间为0时buff永久存在
    buff.interval = -1 --间隔帧为0时每回合触发，小于0不触发 默认不触发OnTrigger
    -- buff.framePass = 0

    buff.roundPass = 0 
    buff.startRound = BattleLogic.GetCurRound()

    buff:SetData(...)
    return buff
end
-- 设置触发间隔
function Buff:SetInterval(interval)
    self.interval = interval
    return self
end
-- 改变buff的轮次
function Buff:ChangeBuffDuration(type, value)
    -- 永久存在改变无效
    if self.duration <= 0 then
        return
    end

    -- 计算
    local finalDuration = BattleUtil.ErrorCorrection(BattleUtil.CountValue(self.duration, value, type))
    self.duration = floor(finalDuration)
    if self.roundDuration then
        self.roundDuration = finalDuration
    end

    -- 发送事件
    self.caster.Event:DispatchEvent(BattleEventName.BuffDurationChange, self)
end



function Buff:CompareWith(buff)

    if self.type == buff.type then
        if self.OnCompare then
            return self:OnCompare(buff)
        else
            return true
        end
    else
        return false
    end
end

BuffManager = {}
BuffManager.__index = BuffManager

local curBuffId

function BuffManager.New()
    local instance = {owner=0, buffQueue = BattleQueue.New(), buffDic = BattleDictionary.New()}
    setmetatable(instance, BuffManager)
    return instance
end

-- 根据类型获取buff的刷新级别
-- local _TypeToLevel = {
--     [] = ,
-- }
function BuffManager.GetLevelByType(type)
    
end


function BuffManager:Init()
    while self.buffQueue.size > 0 do
        putBuff(self.buffQueue:Dequeue())
    end
    for i = 1, self.buffDic.size do
        local list = self.buffDic.vList[i]
        for j=1, list.size do
            putBuff(list.buffer[j])
        end
        list:Clear()
        buffListPool:Put(list)
    end
    self.buffDic:Clear()

    curBuffId = 0
end

function BuffManager.GenerateBuffId()
    if not curBuffId then
        curBuffId = 0
    end
    curBuffId = curBuffId + 1
    return curBuffId
end
function BuffManager:AddBuff(target, buff)
    buff.target = target
    self.buffQueue:Enqueue(buff)
    -- buff.frameDuration = floor(buff.duration * BattleLogic.GameFrameRate)
    --if buff.isBuff then --TODO:增益buff持续时间加成
    --    local buffBocus = buff.caster:GetRoleData(RoleDataName.BuffBocus)
    --    buff.frameDuration = floor(buff.duration * (1 + buffBocus + buff.exCtrlTime) * BattleLogic.GameFrameRate)
    --end
    --
    --if buff.isDeBuff then --TODO:减益buff持续时间减免
    --    local debuffReduce = self.owner:GetRoleData(RoleDataName.DebuffReduce)
    --    buff.frameDuration = floor(buff.duration * (1 - debuffReduce - buff.exCtrlTime) * BattleLogic.GameFrameRate)
    --end

    -- buff.frameInterval = floor(buff.interval * BattleLogic.GameFrameRate)
    
    buff.roundDuration = buff.duration
    buff.roundInterval = buff.interval
    buff.caster.Event:DispatchEvent(BattleEventName.BuffCaster, buff)
end

function BuffManager:QueryBuff(target, checkFunc)
    for i=1, self.buffDic.size do
        local list = self.buffDic.vList[i]
        for j=1, list.size do
            local buff = list.buffer[j]
            if buff.target == target then
                if checkFunc then
                    checkFunc(buff)
                end
            end
        end
    end
end


function BuffManager:GetBuff(target, checkFunc)
    local blist = {}
    for i=1, self.buffDic.size do
        local list = self.buffDic.vList[i]
        for j=1, list.size do
            local buff = list.buffer[j]
            if buff.target == target then
                if not checkFunc or checkFunc(buff)then
                    table.insert(blist, buff)
                end
            end
        end
    end
    return blist
end

function BuffManager:HasBuff(target, type, checkFunc)
    if self.buffDic.kvList[type] then
        local buffList = self.buffDic.kvList[type]
        for i=1, buffList.size do
            local v = buffList.buffer[i]
            if v.target == target then
                if (not checkFunc or (checkFunc and checkFunc(v))) then
                    return true
                end
            end
        end
    end
    return false
end

--func为nil时无条件清除，否则判定clear值，执行func
function BuffManager:ClearBuff(target, func)
    for i = 1, self.buffDic.size do
        local list = self.buffDic.vList[i]
        if list.size > 0 then
            local idx = 1
            while idx <= list.size do
                local buff = list.buffer[idx]
                if buff.target == target and (not func or (func and buff.clear and func(buff))) then
                    buff:OnEnd()
                    buff.target.Event:DispatchEvent(BattleEventName.BuffEnd, buff)
                    putBuff(buff)
                    list:Remove(idx)
                else
                    idx = idx + 1
                end
            end
        end
    end
end

function BuffManager:PutBuff(buff)
    putBuff(buff)
end

function BuffManager:GetBuffCount(type)
    if self.buffDic[type] then
        return self.buffDic[type].size
    end
    return 0
end

-- 每帧刷新
function BuffManager:Update()
    -- 检测上一帧生成的buff，加入管理
    while self.buffQueue.size > 0 do
        local buff = self.buffQueue:Dequeue()
        local buffList
        if not self.buffDic.kvList[buff.type] then
            buffList = buffListPool:Get()
            self.buffDic:Add(buff.type, buffList)
        else
            buffList = self.buffDic.kvList[buff.type]
        end

        -- 是覆盖类型的buff且有老buff
        if buff.cover and buffList.size > 0 then
            local isCovered = false
            for i=1, buffList.size do
                local oldBuff = buffList.buffer[i]
                if oldBuff.cover and oldBuff.target == buff.target and oldBuff.clear == buff.clear and oldBuff:OnCover(buff) then --判定该效果能否被覆盖
                    -- 结束并回收老buff
                    oldBuff:OnEnd()
                    oldBuff.target.Event:DispatchEvent(BattleEventName.BuffEnd, oldBuff)
                    putBuff(oldBuff)
                    -- 覆盖老buff
                    buffList.buffer[i] = buff
                    buff:OnStart()
                    buff.target.Event:DispatchEvent(BattleEventName.BuffStart, buff)
                    buff.target.Event:DispatchEvent(BattleEventName.BuffCover, buff)
                    isCovered = true
                    break
                end
            end
            -- 没有覆盖，新buff
            if not isCovered then
                buffList:Add(buff)
                buff:OnStart()
                buff.target.Event:DispatchEvent(BattleEventName.BuffStart, buff)
            end
        else
            -- 新buff
            buffList:Add(buff)
            buff:OnStart()
            buff.target.Event:DispatchEvent(BattleEventName.BuffStart, buff)
        end
    end

    -- 清除过期buff
    for i=1, self.buffDic.size do
        local buffList = self.buffDic.vList[i]
        if buffList.size > 0 then
            local index = 1
            while index <= buffList.size do
                local buff = buffList.buffer[index]
                if buff.disperse then
                    buff:OnEnd()
                    buff.target.Event:DispatchEvent(BattleEventName.BuffEnd, buff)
                    putBuff(buff)
                    buffList:Remove(index)
                else
                    index = index + 1
                end
            end
        end
    end
end

-- 计算buff 剩余步数(根据当前回合人刷新其造成的所有buff回合数)
function BuffManager:PassUpdate()
    local curCamp, curPos = BattleLogic.GetCurTurn()
    for i=1, self.buffDic.size do
        local buffList = self.buffDic.vList[i]
        if buffList.size > 0 then
            for index = 1, buffList.size do
                local buff = buffList.buffer[index]
                if not buff.disperse    -- 没过期
                -- and buff.caster.camp == curCamp     -- 释放者是当前轮到的人
                -- and buff.caster.position == curPos 
                and buff.roundDuration > 0          -- 不是无限存在的buff
                then
                    -- 当前轮释放的buff不结算
                    if buff.startRound ~= BattleLogic.GetCurRound() then
                        buff.roundPass = buff.roundPass + 1
                        if buff.roundPass >= buff.roundDuration then
                            buff.disperse = true
                        end
                        buff.target.Event:DispatchEvent(BattleEventName.BuffRoundChange, buff)
                    end
                end
            end
        end
    end
end


-- 每一个人的轮次都刷新
function BuffManager:TurnUpdate(sort)
    local curCamp, curPos = BattleLogic.GetCurTurn()
    for i=1, self.buffDic.size do
        local buffList = self.buffDic.vList[i]
        if buffList.size > 0 then
            for index = 1, buffList.size do
                local buff = buffList.buffer[index]
                if not buff.disperse    -- 没有过期
                and buff.sort == sort      -- 当前buff刷新等级
                -- and buff.target.camp == curCamp     -- 当前阵营
                -- and buff.target.position == curPos     -- 当前位置
                then
                    --触发buff
                    if buff.roundInterval >= 0 then
                        if buff.roundInterval == 0 or buff.roundPass % buff.roundInterval == 0 then
                            if not buff:OnTrigger() then
                                buff.disperse = true
                            end
                            buff.target.Event:DispatchEvent(BattleEventName.BuffTrigger, buff)
                        end
                    end
                end
            end
        end
    end
end   