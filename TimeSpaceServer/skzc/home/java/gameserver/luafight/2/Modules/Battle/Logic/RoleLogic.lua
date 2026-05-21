RoleLogic = {}
RoleLogic.__index = RoleLogic
--local RoleLogic = RoleLogic
--local RoleDataName = RoleDataName
--local BattleLogic = BattleLogic
local Random = Random
local floor = math.floor
local max = math.max
local min = math.min

local skillPool = BattleObjectPool.New(function ()
    return Skill:New()
end)

function RoleLogic.New()
    local instance = {uid=0,roleData=0,data=RoleData.New(),camp=0,name=0,aiIndex=1,position=0,sp=0,spPass=0,
                      shield=BattleList.New(),
                      exCalDmgList=BattleList.New(),
                      proTranList=BattleList.New(),
                      buffFilter=BattleList.New(),
                      Event = BattleEvent:New(),passiveList={},isDead=false,IsDebug=false}
    setmetatable(instance, RoleLogic)
    return instance
end

function RoleLogic:Init(uid, data, position)
    self.uid = uid
    self.position = position
    self.roleData = data
    self.roleId=data.roleId
    self.data:Init(self, data.property)
    -- WYLog("HP")
    -- WYLog(self:GetRoleData(RoleDataName.Hp))
    self.isDead = self:GetRoleData(RoleDataName.Hp) <= 0
    self.isRealDead = self.isDead

    self.camp = data.camp --阵营 0：我方 1：敌方
    self.name = data.name
    self.element = data.element
    self.professionId = data.professionId
    self.star = data.star or 1
    -- LogError("英雄uid".. self.roleId .."  " .. self.star)
    self.shield:Clear() --护盾列表
    self.exCalDmgList:Clear() --额外计算伤害列表
    self.buffFilter:Clear() --buff屏蔽列表
    self.proTranList:Clear() --属性转换列表

    self.Event:ClearEvent()

    -- self.skill = data.skill
    -- self.superSkill = data.superSkill
    self.skillArray = data.skillArray

    --首次读条时间=速度/（20*（等级+10）
    self.sp = 0
    local time = self:GetRoleData(RoleDataName.Speed)/(20*(self:GetRoleData(RoleDataName.Level)+10))
    self.spPass = floor( BattleUtil.ErrorCorrection(time) * BattleLogic.GameFrameRate)


    -- 初始化怒气值（默认2）
    self.Rage = 2
    self.RageGrow = 2       -- 普通技能怒气成长
    self.SuperSkillRage = 4 -- 技能需要释放的怒气值，默认为4
    self.NoRageRate = 0     -- 不消耗怒气值的概率

    -- 
    self.passiveList = {}
    WYLog(data.passivity)
    --> 之前的一维改二维 每个passivity 包含多个
    if data.passivity and #data.passivity > 0 then
        for i = 1, #data.passivity do
            local v = data.passivity[i]
            local ids = v[1]
            for k = 1, #ids do
                local args = {}
                for j = 1, #v[k + 1] do
                    args[j] = v[k + 1][j]
                end
                local id = ids[k]
                if BattleUtil.Passivity[id] then
                    BattleUtil.Passivity[id](self, args)
                    -- 加入被动列表
                    table.insert(self.passiveList, {id, args})
                else
                    LogRed(Language[10232]..id..Language[10233])
                end
            end
            
        end
    end

    -- 初始怒气值放在被动之后计算，使被动对初始怒气的影响生效
    --> deprecated
    self.Rage = 0--self.Rage + self:GetRoleData(RoleDataName.InitRage)-- 当前怒气值

    -- 
    self.aiOrder = data.ai
    self.aiIndex = 1
    self.aiTempCount = 0

    self.IsDebug = false

    self.lockTarget = nil       --嘲讽
    self.ctrl_dizzy = false     --眩晕  不能释放所有技能
    self.ctrl_slient = false    --沉默  只能1技能
    self.ctrl_palsy = false     --麻痹  只能2技能
    self.ctrl_noheal = false    --禁疗
    self.ctrl_blind = false     --致盲
    self.ctrltimes = 0          --< 控制次数

    self.deadFilter = true    -- 控制死亡，置为false则角色暂时无法死亡

    self.reliveFilter = true    -- 控制复活的标志位，置为false角色将不再享受复活效果
    self.reliveHPF = 1

    self.IsCanAddSkill = true   -- 是否可以追加技能


    self.effect218times = 0     --< effect 218 触发次数
    self.skilling = false       --< 技能间
end

-- 添加一个被动技能
function RoleLogic:AddPassive(id, args, isRepeat)
    --判断是否可以叠加
    if not isRepeat then
        -- 不可以叠加, 如果重复则不再加入
        for _, pst in ipairs(self.passiveList) do
            if pst[1] == id then
                return 
            end
        end
    end
    -- 被动生效
    BattleUtil.Passivity[id](self, args)
    -- 加入被动列表
    table.insert(self.passiveList, {id, args})
end
-- 
function RoleLogic:CanCastSkill()
    return self.sp >= self.spPass and not self.IsDebug
end

-- 废弃的方法
function RoleLogic:GetSkillCD()
    return max(self.spPass - self.sp, 0)
end

-- 废弃的方法
function RoleLogic:AddSkillCD(value, type)
    self.Event:DispatchEvent(BattleEventName.RoleCDChanged)
    if value == 0 then --为0直接清CD
        self.sp = self.spPass
        return
    end

    local cdTotal = self.spPass
    local delta = 0
    if type == 1 then --加算
        delta = floor(value * BattleLogic.GameFrameRate)
    elseif type == 2 then --乘加算（百分比属性加算）
        delta = floor(value * cdTotal)
    elseif type == 3 then --减算
        delta = -floor(value * BattleLogic.GameFrameRate)
    elseif type == 4 then --乘减算（百分比属性减算）
        delta = -floor(value * cdTotal)
    end

    if delta > 0 then --加cd加cd最大值
        self.spPass = self.spPass + delta
    else --减cd减cd当前值
        delta = -delta
        self.sp = min(self.sp + delta, self.spPass)
    end
end

-- 改变怒气值
function RoleLogic:AddRage(value, type)
    local delta = 0
    if type == 1 then --加算
        delta = value
    elseif type == 2 then --乘加算（百分比属性加算）
        delta = floor(value * self.SuperSkillRage)
    elseif type == 3 then --减算
        delta = -value
    elseif type == 4 then --乘减算（百分比属性减算）
        delta = -floor(value * self.SuperSkillRage)
    end
    -- 
    self.Event:DispatchEvent(BattleEventName.RoleRageChange, delta)
    --怒气值不可为负值
    self.Rage = max(self.Rage + delta, 0)
end

function RoleLogic:GetRoleData(property)
    local tarPro = self.data:GetData(property)
    local item
    for i=1, self.proTranList.size do
        item = self.proTranList.buffer[i]
        if item.proName == property then
            local value
            if item.changeType == 1 then --加算
                value = item.tranFactor
            elseif item.changeType == 2 then --乘加算（百分比属性加算）
                value = BattleUtil.ErrorCorrection(self.data:GetData(item.tranProName) * item.tranFactor)
            elseif item.changeType == 3 then --减算
                value = -item.tranFactor
            elseif item.changeType == 4 then --乘减算（百分比属性减算）
                value = -BattleUtil.ErrorCorrection(self.data:GetData(item.tranProName) * item.tranFactor)
            end
            tarPro = tarPro + value
        end
    end
    return tarPro
end

--proA替换的属性，factor系数，proB被替换的属性, duration持续时间
--读取proB属性时，得到的值为proB + proA * factor
function RoleLogic:AddPropertyTransfer(proA, factor, proB, ct, duration)
    local proTran = {proName = proB, tranProName = proA, tranFactor = factor, changeType = ct}
    self.proTranList:Add(proTran)
    local index = self.proTranList.size
    if duration then
        BattleLogic.WaitForTrigger(duration, function ()
            self:RemovePropertyTransfer(index, proTran)
        end)
    end
    return index, proTran
end
-- 删除临时属性
function RoleLogic:RemovePropertyTransfer(index, tran)
    if index <= self.proTranList.size and tran == self.proTranList.buffer[index] then
        self.proTranList:Remove(index)
    end
end

-- 是否为指定id，指定星级的英雄 by:王振兴 2020/07/29
function RoleLogic:IsAssignHeroAndHeroStar(id,star)
if self.roleId==id and self.star==star then
    return true
end
return false
end


function RoleLogic:AddBuff(buff)
    if self:IsRealDead() then
        BattleLogic.BuffMgr:PutBuff(buff)
        return
    end
    -- buff的miss率
    local missF = 0
    -- 检测被动对miss概率的影响
    local cl = {}
    local function _CallBack(v, ct)
        if v then
            table.insert(cl, {v, ct})
        end
    end
    BattleLogic.Event:DispatchEvent(BattleEventName.RoleAddBuffMiss, _CallBack, self, buff)
    missF = BattleUtil.CountChangeList(missF, cl)

    -- 如果概率为0 或者没有miss
    if missF == 0 or not BattleUtil.RandomAction(missF, function() BattleLogic.BuffMgr:PutBuff(buff) end) then
        for i=1, self.buffFilter.size do
            if self.buffFilter.buffer[i](buff) then
                BattleLogic.BuffMgr:PutBuff(buff)
                return
            end
        end
        BattleLogic.BuffMgr:AddBuff(self, buff)
    end
end

function RoleLogic:Dispose()
    
end


-- 判断角色是否可以释放技能
function RoleLogic:IsAvailable()
    -- 眩晕            -- 死亡
    if self.ctrl_dizzy or self:IsRealDead() then
        return false
    end
    -- 沉默麻痹同时存在
    if self.ctrl_palsy and self.ctrl_slient then
        return false
    end
    -- 麻痹同时怒气不足
    --if self.ctrl_palsy and self.Rage < self.SuperSkillRage then
    if self.ctrl_palsy then
        return false
    end
    return true
end

-- 释放技能
function RoleLogic:SkillCast(skill, func)

    local _CastDone = function()
        if func then 
            func() 
        end
    end

    -- 角色不可用直接结束技能释放
    if not skill or not self:IsAvailable() then
        _CastDone()
        return
    end

    -- 没有麻痹，释放普通攻击
    -- if skill.type == BattleSkillType.Normal and not self.ctrl_palsy then

    --     -- local function _CheckRage()
    --     --     -- 后成长怒气
    --     --     if skill.isRage then
    --     --         -- 检测被动技能对怒气成长的影响
    --     --         local grow = self.RageGrow
    --     --         local _RageGrowPassivity = function(finalGrow)
    --     --             grow = finalGrow
    --     --         end
    --     --         self.Event:DispatchEvent(BattleEventName.RoleRageGrow, grow, _RageGrowPassivity)
    --     --         -- 
    --     --         self.Rage = self.Rage + grow
    --     --     end
    --     --     -- 释放完成
    --     --     _CastDone()
    --     -- end
    --     -- 释放普技
    --     skill:Cast(_CastDone)

    -- -- 没有沉默，释放大技能
    -- elseif skill.type == BattleSkillType.Special and not self.ctrl_slient then
    --     -- 先消耗怒气
    --     if skill.isRage then
    --         if self.Rage < self.SuperSkillRage then
    --             -- 怒气值不足不能释放技能
    --             _CastDone()
    --             return
    --         end
    --         -- 检测被动技能对怒气消耗的影响
    --         local costRage = self.SuperSkillRage
    --         local noRageRate = self.NoRageRate
    --         local _RageCostPassivity = function(rate, cost)
    --             noRageRate = noRageRate + rate
    --             costRage = costRage + cost
    --         end
    --         self.Event:DispatchEvent(BattleEventName.RoleRageCost, costRage, noRageRate, _RageCostPassivity)
    --         -- 计算消耗怒气的概率，并消耗怒气
    --         local costRate = 1 - noRageRate
    --         costRate = costRate > 1 and 1 or costRate
    --         costRate = costRate < 0 and 0 or costRate
    --         BattleUtil.RandomAction(costRate, function()
    --             self.Rage = self.Rage - costRage
    --         end)
    --     end

    --     -- 释放绝技
    --     skill:Cast(_CastDone)

    -- -- 没有符合条件的技能直接进入下一个技能检测    
    -- else
    --     _CastDone()
    -- end


    skill:Cast(_CastDone)
end


-- 加入一个技能
-- type         加入的技能类型 --< 修改为physical magic
-- targets      指定目标
-- isAdd        是否是追加技能
-- effectData   战斗技能数据
function RoleLogic:AddSkill(type, isAdd, targets, effectData)
    WYLog("RoleLogic:AddSkill")
    if not self.IsCanAddSkill and isAdd then return end
    -- local effectData = type == BattleSkillType.Normal and self.skill or self.superSkill

    SkillManager.AddSkill(self, effectData, type, targets, isAdd)
    -- 
    BattleLogManager.Log(
        "Add Skill",
        "camp", self.camp,
        "pos", self.position,
        "type", type,
        -- "isRage", tostring(isRage),
        "isAdd", tostring(isAdd),
        "targets", targets and #targets or "0"
    )
end
-- 插入一个技能
function RoleLogic:InsertSkill(type, isAdd, targets, effectData)
    if not self.IsCanAddSkill and isAdd then return end
    -- local effectData = type == BattleSkillType.Normal and self.skill or self.superSkill
    SkillManager.InsertSkill(self, effectData, type, targets, isAdd)
    --
    BattleLogManager.Log(
        "Insert Skill",
        "camp", self.camp,
        "pos", self.position,
        "type", type,
        -- "isRage", tostring(isRage),
        "isAdd", tostring(isAdd),
        "targets", targets and #targets or "0"
    )
end
-- 设置是否可以追加技能
function RoleLogic:SetIsCanAddSkill(isCan)
    self.IsCanAddSkill = isCan
end


-- 正常触发技能
function RoleLogic:CastSkill(func) 
    -- 设置轮转方法
    SkillManager.SetTurnRoundFunc(func)
    local haveSkill = false
    -- 没有沉默
    -- if not self.ctrl_slient and self.Rage >= self.SuperSkillRage then
    if not self.ctrl_slient then

        local isHave, skilldata = self:CheckSkill(SkillBaseType.Magic)
        -- 释放大技能
        LogBlue(Language[10234])
        if isHave then
            self:AddSkill(SkillBaseType.Magic, true, nil, skilldata)
            haveSkill = true
        else
            local isHave_p, skilldata_p = self:CheckSkill(SkillBaseType.Physical)
            if isHave_p then
                self:AddSkill(SkillBaseType.Physical, true, nil, skilldata_p)
                haveSkill = true
            else
                LogError("RoleLogic CastSkill not have physical skill_1 !!!")
            end
        end
        
        return haveSkill
    end
    -- 没有麻痹  释放普通技能
    if not self.ctrl_palsy then
        LogBlue(Language[10235])
        local isHave, skilldata = self:CheckSkill(SkillBaseType.Physical)
        if isHave then
            self:AddSkill(SkillBaseType.Physical, true, nil, skilldata)
            haveSkill = true
        else
            LogError("CastSkill not have physical skill_2 !!!")
        end
        return haveSkill
    end
    
    LogError("### 无法填装技能")
    return haveSkill
    -- LogBlue(Language[10236])
end

-- 强制释放技能，测试技能时使用
-- type  追加的技能类型 1=普技  2=特殊技
-- targets  追加技能的目标 nil则自动选择目标
-- func  追加技能释放完成回调
function RoleLogic:ForceCastSkill(type, targets, func)

    -- 清除技能控制
    self.ctrl_dizzy = false     --眩晕  不能释放技能
    self.ctrl_slient = false    --沉默  只能1技能
    self.ctrl_palsy = false     --麻痹  只能2技能

    -- 设置轮转方法
    SkillManager.SetTurnRoundFunc(func)
    -- 释放技能
    if type == 1 and self.skill then
        LogBlue(Language[10237])
        self:AddSkill(BattleSkillType.Normal, true, false, nil)
    elseif type == 2 and self.superSkill then 
        LogBlue(Language[10238])
        if self.Rage < self.SuperSkillRage then
            self.Rage = self.SuperSkillRage
        end
        self:AddSkill(BattleSkillType.Special, true, false, nil)
    end
end


-- 判断是否可以去死了
function RoleLogic:IsCanDead()
    -- 暂时不能死
    if not self.deadFilter then 
        return false
    end
    -- 还有我的技能没有释放,不能死啊
    if SkillManager.HaveMySkill(self) then
        return false
    end
    return true
end

-- 真的去死
function RoleLogic:GoDead()
    if self:IsCanDead() then 
        self.isRealDead = true
        self.Rage = 0
        BattleLogic.BuffMgr:ClearBuff(self)
        self.Event:DispatchEvent(BattleEventName.RoleRealDead, self)
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleRealDead, self)
        return true
    end
    return false
end

-- 设置是否可以死亡
function RoleLogic:SetDeadFilter(filter)
    self.deadFilter = filter
end
-- 要死了
function RoleLogic:SetDead()
    self.isDead = true
    RoleManager.AddDeadRole(self)
end
-- 判断是否死亡
function RoleLogic:IsDead()
    return self.isDead
end
function RoleLogic:IsRealDead()
    return self.isRealDead
end


-- 是否可以复活
function RoleLogic:IsCanRelive()
    if not self.reliveFilter then
        return false
    end
    if not self.isRealDead then
        return false
    end
    return true
end
-- 复活吧, 真的去世后才能复活
function RoleLogic:Relive()
    if self:IsCanRelive() then
        -- 没有指定血量则满血
        self.isDead = false
        self.isRealDead = false
        local maxHp = self.data:GetData(RoleDataName.MaxHp)
        self.data:SetValue(RoleDataName.Hp, floor(self.reliveHPF * maxHp))
        -- 发送复活事件
        self.Event:DispatchEvent(BattleEventName.RoleRelive, self)
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleRelive, self)
        return true
    end
    return false
end
-- 设置是否可以死亡
function RoleLogic:SetReliveFilter(filter)
    self.reliveFilter = filter
end
--,hpf 复活时拥有的血量的百分比
function RoleLogic:SetRelive(hpf)
    -- 判断是否可以复活
    if self:IsCanRelive() then
        self.reliveHPF = hpf or 1
        RoleManager.AddReliveRole(self)
    end
    return false
end

--> 检测技能list中 可释放的技能
function RoleLogic:CheckSkill(skilltype)
    local CurRound, MaxRound = BattleLogic.GetCurRound()
    -- WYLog("技能列表")
    -- WYLog(self.skillArray)
    for k, skill in ipairs(self.skillArray) do
        while true
        do
            if skilltype == SkillBaseType.Physical and skill[8].slot ~= SkillSlotPos.Slot_0 then        --< 物理技能 排除magic skill
                break
            end
            if skilltype == SkillBaseType.Magic and skill[8].slot == SkillSlotPos.Slot_0 then
                break
            end
            local skillid = skill[1]
            local cd = skill[8].cd
            local release = skill[8].release
            
            if CurRound == release then                                             --< 起始回合
                WYLog("ret skillid")
                WYLog(skillid)
                return true, skill
            elseif CurRound > release and (CurRound - release) % cd == 0 then       --< cd回合
                return true, skill
            end

            break
        end
    end

    return false, nil
end


function RoleLogic:Update()

end   