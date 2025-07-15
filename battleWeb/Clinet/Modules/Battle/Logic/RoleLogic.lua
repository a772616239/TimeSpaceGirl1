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
    local instance = {uid = 0, roleData = 0, data = RoleData.New(), camp = 0, name = 0, aiIndex = 1, position = 0, sp = 0, spPass = 0,
                      shield = BattleList.New(),
                      exCalDmgList = BattleList.New(),
                      proTranList = BattleList.New(),
                      buffFilter = BattleList.New(),
                      Event = BattleEvent:New(), passiveList = {}, isDead = false, IsDebug = false}
    setmetatable(instance, RoleLogic)
    return instance
end

--匹配相同id
function RoleLogic:Equle(_role)
    if _role.roleId == self.roleId and _role.uid == self.uid then
        return true
    end
    return false
end

--回滚
function RoleLogic:RoleBack(_role)
    -- LogError("xRolbX ---------------"..self.uid)
-- 回滚的状态及其数据
    self.position = _role.position
    self.roleData= _role.roleData
    local _data =_role.data:Clone()    --< 检查状态
    self.data:RoleBack( self, _data)    
    self.Rage =_role.Rage
    self.RageGrow =_role.RageGrow       -- 普通技能怒气成长
    self.SuperSkillRage =_role.SuperSkillRage -- 技能需要释放的怒气值，默认为4
    self.NoRageRate =_role.NoRageRate     -- 不消耗怒气值的概率
    self.Rage =_role.Rage--self.Rage + self:GetRoleData(RoleDataName.InitRage)-- 当前怒气值
    self.aiOrder =_role.aiOrder 
    self.aiIndex =_role.aiIndex 
    self.aiTempCount =_role.aiTempCount 
    self.IsDebug =_role.IsDebug 
    self.lockTarget =_role.lockTarget        --嘲讽
    self.ctrl_dizzy =_role.ctrl_dizzy      --眩晕  不能释放所有技能
    self.ctrl_slient =_role.ctrl_slient     --沉默  只能1技能
    self.ctrl_palsy =_role.ctrl_palsy      --麻痹  只能2技能
    self.ctrl_noheal =_role.ctrl_noheal     --禁疗
    self.ctrl_blind =_role.ctrl_blind      --致盲
    self.ctrl_frozen =_role.ctrl_frozen     --< 冰冻
    self.ctrl_chaos =_role.ctrl_chaos      --< 混乱
    self.ctrl_chaos_beatBack =_role.ctrl_chaos_beatBack      --< 混乱中的反击
    self.ctrltimes =_role.ctrltimes           --< 控制次数
    self.stop_move =_role.stop_move       --< 停止行动
    self.deadFilter =_role.deadFilter     -- 控制死亡，置为false则角色暂时无法死亡
    self.reliveFilter =_role.reliveFilter     -- 控制复活的标志位，置为false角色将不再享受复活效果
    self.reliveHPF =_role.reliveHPF 
    self.IsCanAddSkill =_role.IsCanAddSkill    -- 是否可以追加技能
    self.effect218times =_role.effect218times      --< effect 218 触发次数
    self.skilling =_role.skilling        --< 技能间
    self.randHitPos =_role.randHitPos         --< 受击位置点
    self.miss_ctrl =_role.miss_ctrl       --< 无视控制
    self.warWayType =_role.warWayType         --< 战法类型
    self.isBeInfect = _role.isBeInfect
    self.movementRandom01=_role.movementRandom01  
end

function RoleLogic:Clone()
    local _copy = RoleLogic.New()
    _copy.uid = self.uid
    _copy.position = self.position
    _copy.roleData =  self.roleData
    _copy.roleId = self.roleId

    _copy.data = self.data:Clone(_copy)
    _copy.data:RoleBack(_copy,self.data)        
    _copy.isDead = _copy:GetRoleData(RoleDataName.Hp) <= 0
    _copy.isRealDead = _copy.isDead

    _copy.camp = self.camp --阵营 0：我方 1：敌方
    _copy.name = self.name
    _copy.element = self.element
    _copy.professionId = self.professionId
    _copy.star = self.star or 1

    _copy.shield = self.shield:Clone() --护盾列表
    _copy.exCalDmgList = self.exCalDmgList:Clone() --额外计算伤害列表
    _copy.buffFilter = self.buffFilter:Clone() --buff屏蔽列表
    _copy.proTranList = self.proTranList:Clone() --属性转换列表
    _copy.Event = self.Event --< 此处回滚需要屏蔽！！
    -- self.skill = data.skill
    -- self.superSkill = data.superSkill

    _copy.skillArray = self.skillArray    
    --首次读条时间=速度/（20*（等级+10）
    _copy.sp = self.sp
    -- local time = self:GetRoleData(RoleDataName.Speed)/(20*(self:GetRoleData(RoleDataName.Level)+10))
    _copy.spPass = self.spPass


    -- 初始化怒气值（
    _copy.Rage = self.Rage
    _copy.RageGrow = self.RageGrow       -- 普通技能怒气成长
    _copy.SuperSkillRage = self.SuperSkillRage -- 技能需要释放的怒气值，默认为4
    _copy.NoRageRate = self.NoRageRate     -- 不消耗怒气值的概率

    -- 被动技能
    _copy.passiveList = {}    
    _copy.passivity = self.passivity
    _copy.passivityIds = self.passivityIds or {}
    --> 之前的一维改二维 每个passivity 包含多个
    if _copy.passivity and #_copy.passivity > 0 then
        for i = 1, #_copy.passivity do
            -- --> 用于效果被动反显示技能名
            -- self.tempPassivityId = nil
            -- if data.passivityIds and data.passivityIds[i] then
            --     self.tempPassivityId = data.passivityIds[i]
            -- end            

            local v = _copy.passivity[i]
            local ids = v[1]
            for k = 1, #ids do
                local args = {}
                for j = 1, #v[k + 1] do
                    args[j] = v[k + 1][j]
                end
                local id = ids[k]
                if BattleUtil.Passivity[id] then
                    -- BattleUtil.Passivity[id](self, args) 被动加入了列表需要注意切换的时候只同步数据
                    -- 计入日志
                    -- local argtx=""
                    -- for i,ar in pairs(args) do 
                    --     argtx = argtx.." "..i..": "..ar
                    -- end
                    -- BattleLogManager.Log(
                    --     "insert Passivity idx:"..id.." "..argtx,
                    --     "tcamp", self.camp,
                    --     "tpos", self.position,
                    --     "id", self.roleId
                    -- )
                    -- 加入被动列表
                    table.insert(_copy.passiveList, {id, args})
                else
                end
            end
        end
    end

    -- 初始怒气值放在被动之后计算，使被动对初始怒气的影响生效
    --> deprecated
    _copy.Rage = self.Rage--self.Rage + self:GetRoleData(RoleDataName.InitRage)-- 当前怒气值
    -- 
    _copy.aiOrder = self.aiOrder
    _copy.aiIndex = self.aiIndex
    _copy.aiTempCount = self.aiTempCount
    _copy.IsDebug = self.IsDebug
    _copy.lockTarget = self.lockTarget        --嘲讽
    _copy.ctrl_dizzy = self.ctrl_dizzy      --眩晕  不能释放所有技能
    _copy.ctrl_slient = self.ctrl_slient     --沉默  只能1技能
    _copy.ctrl_palsy = self.ctrl_palsy      --麻痹  只能2技能
    _copy.ctrl_noheal = self.ctrl_noheal     --禁疗
    _copy.ctrl_blind = self.ctrl_blind      --致盲
    _copy.ctrl_frozen = self.ctrl_frozen     --< 冰冻
    _copy.ctrl_chaos = self.ctrl_chaos      --< 混乱
    _copy.ctrl_chaos_beatBack = self.ctrl_chaos_beatBack --< 混乱中的反击
    _copy.ctrltimes = self.ctrltimes           --< 控制次数
    _copy.stop_move = self.stop_move       --< 停止行动
    _copy.deadFilter = self.deadFilter     -- 控制死亡，置为false则角色暂时无法死亡
    _copy.reliveFilter = self.reliveFilter     -- 控制复活的标志位，置为false角色将不再享受复活效果
    _copy.reliveHPF = self.reliveHPF
    _copy.IsCanAddSkill = self.IsCanAddSkill    -- 是否可以追加技能
    _copy.effect218times = self.effect218times      --< effect 218 触发次数
    _copy.skilling = self.skilling        --< 技能间
    _copy.randHitPos = self.randHitPos         --< 受击位置点
    _copy.miss_ctrl = self.miss_ctrl       --< 无视控制
    _copy.warWayType = self.warWayType         --< 战法类型
    _copy.isBeInfect = self.isBeInfect
    _copy.movementRandom01 = self.movementRandom01
    _copy:InitRoleType()         --< 初始目标类型    
    return _copy
end

function RoleLogic:Init(uid, data, position)
    self.uid = uid
    self.position = position
    self.roleData = data
    self.roleId = data.roleId
    self.data:Init(self, data.property)

    self.isFlagCrit = false

    self.isDead = self:GetRoleData(RoleDataName.Hp) <= 0
    self.isRealDead = self.isDead

    self.isFlagCrit = false

    self.camp = data.camp --阵营 0：我方 1：敌方
    self.name = data.name
    self.element = data.element
    self.professionId = data.professionId
    self.star = data.star or 1
    self.leader = false
    self.leaderUnlockSkillSize = 0
    if data.roleId == 1 or data.roleId == 2 then
        self.leader = true
        -- self.leaderUnlockSkillSize = data.leaderSkillUnlock
    end
    self.shield:Clear() --护盾列表
    self.exCalDmgList:Clear() --额外计算伤害列表
    self.buffFilter:Clear() --buff屏蔽列表
    self.proTranList:Clear() --属性转换列表

    self.Event:ClearEvent()

    -- self.skill = data.skill
    -- self.superSkill = data.superSkill
    self.skillArray = data.skillArray
    if self.position == 99 then
        --  LogError("skillArray len "..#data.skillArray) 
    end
    self.skillArrayBase = BattleUtil.cloneTable(data.skillArray)

    self.substitute = data.isTibu

    -- if self.substitute then
    --   LogError(self.uid .." true")
    -- else
    --     LogError(self.uid .."false")  
    -- end

    --首次读条时间=速度/（20*（等级+10）
    self.sp = 0
    local time = self:GetRoleData(RoleDataName.Speed)/(20*(self:GetRoleData(RoleDataName.Level)+10))
    self.spPass = floor( BattleUtil.ErrorCorrection(time) * BattleLogic.GameFrameRate)

    -- 初始化怒气值（默认2）
    self.Rage = 2
    self.RageGrow = 2       -- 普通技能怒气成长
    self.SuperSkillRage = 4 -- 技能需要释放的怒气值，默认为4
    self.NoRageRate = 0     -- 不消耗怒气值的概率
    self.isFlagCrit = false -- 暴击标记
    self.passiveList = {}

    self.passivity = data.passivity
    self.passivityIds = data.passivityIds or {}
    --> 之前的一维改二维 每个passivity 包含多个
    if data.passivity and #data.passivity > 0 then
        for i = 1, #data.passivity do
            -- --> 用于效果被动反显示技能名
            -- self.tempPassivityId = nil
            -- if data.passivityIds and data.passivityIds[i] then
            --     self.tempPassivityId = data.passivityIds[i]
            -- end            

            local v = data.passivity[i]
            local ids = v[1]
            for k = 1, #ids do
                local args = {}
                for j = 1, #v[k + 1] do
                    args[j] = v[k + 1][j]
                end
                local id = ids[k]
                -- if BattleUtil.Passivity[id] then
                --     BattleUtil.Passivity[id](self, args)

                if BattleUtil.Passivity[id] then
                    local delay = id/100
                    if delay < 0.1 then
                        delay = delay*4
                    elseif delay > 1 then
                        delay = delay/5 + 0.18
                    end
                    -- LogError("roleid:"..self.roleId.." p:"..id)
                    BattleUtil.Passivity[id](self, args, 0)-- id/100)
                    -- 计入日志
                    local argtx = ""
                    for i, ar in pairs(args) do 
                        argtx = argtx.." "..i..": "..ar
                    end
                    -- BattleLogManager.Log(
                    --     "insert Passivity idx:"..id.." "..argtx,
                    --     "tcamp", self.camp,
                    --     "tpos", self.position,
                    --     "id", self.roleId
                    -- )
                    -- 加入被动列表
                    table.insert(self.passiveList, {id, args})
                else
                --     -- 计入日志
                --     local argtx = ""
                --     for i ,ar in pairs(args) do 
                --         argtx = argtx.." "..i..": "..ar
                --     end

                --     BattleLogManager.Log(
                --         "insert Passivity idx:"..id.." "..argtx,
                --         "tcamp", self.camp,
                --         "tpos", self.position,
                --         "id", self.roleId,
                --     )
                --     table.insert(self.passiveList, {id, args})
                -- else

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
    self.ctrl_frozen = false    --< 冰冻
    self.ctrl_chaos = false     --< 混乱
    self.ctrl_chaos_beatBack = false    --< 混乱中的反击
    self.ctrltimes = 0          --< 控制次数
    self.isBeInfect = false     --<是否被传染
    self.isHoldBeatingBack = true     --<是否触发反击状态 true 为未触发
    self.stop_move = false      --< 停止行动

    self.deadFilter = true    -- 控制死亡，置为false则角色暂时无法死亡
    self.deadRoundCounter = 0 -- 不可复活 死亡回合数标记（控制何时可以复活）
    self.reliveFilter = true    -- 控制复活的标志位，置为false角色将不再享受复活效果
    self.reliveHPF = 1
    self.isOutGame = false -- 永久不可复活&&移除本场游戏
    self.IsCanAddSkill = true   -- 是否可以追加技能

    self.movementRandom01 = 0     --< 固定回合一次跟新随机数
    self.effect218times = 0     --< effect 218 触发次数
    self.effect280times = 0     --< effect 280 触发次数
    self.skilling = false       --< 技能间
    self.randHitPos = {}        --< 受击位置点

    self.miss_ctrl = false      --< 无视控制
    self.warWayType = {}        --< 战法类型
    self:InitRoleType()         --< 初始目标类型
    self:InitMovementSeed()     --< 初始化回合变化随机数

    self.effectTrigger400 = false --<是否触发追击
    self.effectTrigger352 = false --<是否触发暴击连击

    if self.leader then
        self.deadFilter = false
        local changeHp = function ()
            local maxHp = self:GetRoleData(RoleDataName.MaxHp)
            self:SetValue(RoleDataName.Hp, maxHp)
        end
        self.Event:AddEvent(BattleEventName.RoleTurnStart,changeHp)
    end
end


function RoleLogic:InitMovementSeed()
    local _round = -1
    local changeSeed = function ()
        local round =   BattleLogic.GetCurRound()
        if _round == round then
            return
        else
            _round=round
            if Random.Range01() <= 0.5 then
                self.movementRandom01 = 0 
            else
                self.movementRandom01 = 1
            end
        end
    end
    self.Event:AddEvent(BattleEventName.RoleTurnStart,changeSeed)
end

-- 被动接受替补buff  
function RoleLogic:AddPassiveByOther(passivity)
    if passivity and #passivity > 0 then
        for i = 1, #passivity do
            -- --> 用于效果被动反显示技能名
            -- self.tempPassivityId = nil
            -- if data.passivityIds and data.passivityIds[i] then
            --     self.tempPassivityId = data.passivityIds[i]
            -- end            
            local v = passivity[i]
            local ids = v[1]
            for k = 1, #ids do
                local args = {}
                for j = 1, #v[k + 1] do
                    args[j] = v[k + 1][j]
                end
                local id = ids[k]
                -- LogError("~~~~~~~~~~~~~~~ByOther oooooooo"..id) 
                if BattleUtil.Passivity[id] then

                    BattleUtil.Passivity[id](self, args, 0)-- id/100)
                    -- 加入被动列表   
                    -- LogError("~~~~~~~~~~~~~~~ByOther"..id)                   
                    table.insert(self.passiveList, {id, args})
                else

                end
            end
        end
    end
end

local function tableKin(_tb,_k)
    for k,v in pairs(_tb) do
        if k == _k then return true end
    end
    return false
end

function RoleLogic:GetData(name)
    return self:GetRoleData(name)
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
    BattleUtil.Passivity[id](self, args, 0)-- id/100)

    -- 加入被动列表
    table.insert(self.passiveList, {id, args})
end

function RoleLogic:CanCastSkill()
    return self.sp >= self.spPass and not self.IsDebug
end

-- 废弃的方法
-- function RoleLogic:GetSkillCD()
--     return max(self.spPass - self.sp, 0)
-- end

-- -- 废弃的方法
-- function RoleLogic:AddSkillCD(value, type)
--     self.Event:DispatchEvent(BattleEventName.RoleCDChanged)
--     if value == 0 then --为0直接清CD
--         self.sp = self.spPass
--         return
--     end

--     local cdTotal = self.spPass
--     local delta = 0
--     if type == 1 then --加算
--         delta = floor(value * BattleLogic.GameFrameRate)
--     elseif type == 2 then --乘加算（百分比属性加算）
--         delta = floor(value * cdTotal)
--     elseif type == 3 then --减算
--         delta = -floor(value * BattleLogic.GameFrameRate)
--     elseif type == 4 then --乘减算（百分比属性减算）
--         delta = -floor(value * cdTotal)
--     end

--     if delta > 0 then --加cd加cd最大值
--         self.spPass = self.spPass + delta
--     else --减cd减cd当前值
--         delta = -delta
--         self.sp = min(self.sp + delta, self.spPass)
--     end
-- end

-- 改变怒气值
-- function RoleLogic:AddRage(value, type)
--     local delta = 0
--     if type == 1 then --加算
--         delta = value
--     elseif type == 2 then --乘加算（百分比属性加算）
--         delta = floor(value * self.SuperSkillRage)
--     elseif type == 3 then --减算
--         delta = -value
--     elseif type == 4 then --乘减算（百分比属性减算）
--         delta = -floor(value * self.SuperSkillRage)
--     end
--     -- 
--     self.Event:DispatchEvent(BattleEventName.RoleRageChange, delta)
--     --怒气值不可为负值
--     self.Rage = max(self.Rage + delta, 0)
-- end

-- 强行加血
function RoleLogic:SetValue(property,date)
    self.data:SetValue(property,date)
end

function RoleLogic:GetRoleData(property)
    local tarPro = self.data:GetData(property)
    --> 战斗加成在此处理
    if property == RoleDataName.Attack then
        tarPro = BattleUtil.FP_Mul(tarPro, (1 + self.data:GetData(RoleDataName.AttackAddition)))
    elseif property == RoleDataName.PhysicalDefence then
        tarPro = BattleUtil.FP_Mul(tarPro, (1 + self.data:GetData(RoleDataName.ArmorAddition)))
    elseif property == RoleDataName.Hp then
        tarPro = BattleUtil.FP_Mul(tarPro, (1 + self.data:GetData(RoleDataName.MaxHpPercentage)))
    elseif property == RoleDataName.MaxHp then
        tarPro = BattleUtil.FP_Mul(tarPro, (1 + self.data:GetData(RoleDataName.MaxHpPercentage)))
    elseif property == RoleDataName.Speed then
        tarPro = BattleUtil.FP_Mul(tarPro, (1 + self.data:GetData(RoleDataName.SpeedAddition)))
    end

    local item
    for i = 1, self.proTranList.size do
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
    if self.roleId == id and self.star == star then
        return true
    end
    return false
end

function RoleLogic:AddBuff(buff)
    -- BattleLogManager.Log(
    --     self.roleId..": AddBuff",
    --     "camp", self.camp,
    --     "pos", self.position,
    --     "type", buff.type,
    --     -- "isRage", tostring(isRage),
    --     "id", buff.id
    -- )
    if self:IsRealDead() or self.leader then --主角不可加buff
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

    local ImmuneTrigger = function(_buff)
        buff = _buff
    end
    -- 如果概率为0 或者没有miss
    if missF == 0 or not BattleUtil.RandomAction(missF, function() BattleLogic.BuffMgr:PutBuff(buff) end) then
        local isMissCtrl = false
        for i=1, #BattleLogic.BuffMgr.buffQueue.list  do
            local _buff = BattleLogic.BuffMgr.buffQueue.list[i]
            if _buff.target == self and _buff.type == BuffName.Immune then
                local immuneType0 = _buff.immuneType == 0 and (buff.isDeBuff or buff.type == BuffName.Control or buff.type == BuffName.DOT)
                local immuneType1 = _buff.immuneType == 1 and buff.type == BuffName.Control
                local immuneType2 = _buff.immuneType == 2 and buff.type == BuffName.DOT
                -- local immuneType3 = buff.immuneType == 3 and buff.type == BuffName.Shield
                if immuneType0 or immuneType1 or immuneType2 then
                    isMissCtrl = true
                end
            end
        end

        if isMissCtrl then return end

        for i=1, self.buffFilter.size do
            if self.buffFilter.buffer[i](buff) then 
                self.Event:DispatchEvent(BattleEventName.ImmuneTrigger,buff,ImmuneTrigger)       
                BattleLogic.BuffMgr:PutBuff(buff)
                return
            end
        end

        BattleLogic.BuffMgr:AddBuff(self, buff)
    end
end

function RoleLogic:RemoveBuff(checkFunc)
    if checkFunc then
        BattleLogic.BuffMgr:RemoveBuff(self, checkFunc)
    end
end

function RoleLogic:Dispose()
    self.shield:Clear() --护盾列表
    self.exCalDmgList:Clear() --额外计算伤害列表
    self.buffFilter:Clear() --buff屏蔽列表
    self.proTranList:Clear() --属性转换列表
    self.Event:ClearEvent()
    self:RemoveBuff(function(buff) return true end)
end

-- 判断角色是否可以释放技能
function RoleLogic:IsAvailable()
    if self:IsRealDead() then
        return false
    end

    if self.effectTrigger352 then
        local function reset_stop()
            self.effectTrigger352 = false
            self.stop_move = true
            self.Event:RemoveEvent(BattleEventName.SkillCastEnd, reset_stop)
        end
        if BattleLogic.BuffMgr:HasBuff(self, BuffName.Brand, function (buff) return buff.flag == "stop_move" end) then
            self.Event:AddEvent(BattleEventName.SkillCastEnd, reset_stop)
        end
       -- LogError("effectTrigger352 !!!"..BattleLogic.GetCurRound())
    end

    if self.stop_move and not self.effectTrigger352 then--< 停止行动
       -- LogError("effectTrigger352 true")
        return false
    end
    -- --> ctrl
    -- if self.miss_ctrl then
    --     return true
    -- else
    --     --> 眩晕
    --     if self.ctrl_dizzy then
    --         return false
    --     end
    --     --> 冰冻
    --     if self.ctrl_frozen then
    --         return false
    --     end
    --     -- 沉默麻痹同时存在
    --     if self.ctrl_palsy and self.ctrl_slient then
    --         return false
    --     end
    -- end
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
    if not self.IsCanAddSkill and isAdd then return end
    -- local effectData = type == BattleSkillType.Normal and self.skill or self.superSkill

    SkillManager.AddSkill(self, effectData, type, targets, isAdd)
    -- 
    -- BattleLogManager.Log(
    --     self.roleId..":Add Skill",
    --     "camp", self.camp,
    --     "pos", self.position,
    --     "type", type,
    --     -- "isRage", tostring(isRage),
    --     "isAdd", tostring(isAdd),
    --     "targets", targets and #targets or "0"
    -- )
end

-- 插入一个技能
function RoleLogic:InsertSkill(type, isAdd, targets, effectData, skillSubType)
    if not self.IsCanAddSkill and isAdd then return end
    -- LogError("InsertSkill:"..type)
    -- local effectData = type == BattleSkillType.Normal and self.skill or self.superSkill
    -- 主角无法被选中
    if targets and #targets > 0 then
        for i,role in pairs(targets) do
            -- LogError("## I:"..i.." role:"..role[1].roleId)
             if role[1] and role[1].leader then
                table.remove(targets,i)
                -- LogError("removed!!!") 
             end
        end
    end        
    if targets==nil or #targets <= 0 then return end
    SkillManager.InsertSkill(self, effectData, type, targets, isAdd, skillSubType)
    -- BattleLogManager.Log(
    --     "Insert Skill",
    --     "camp", self.camp,
    --     "pos", self.position,
    --     "type", type,
    --     -- "isRage", tostring(isRage),
    --     "isAdd", tostring(isAdd),
    --     "targets", targets and #targets or "0"
    -- )
end

-- 设置是否可以追加技能
function RoleLogic:SetIsCanAddSkill(isCan)
    self.IsCanAddSkill = isCan
end

--获取主角下次施放的技能
function RoleLogic:GetNextLeaderSkillSlot(skill)
    local index = -1
    local skillLen = #self.skillArray
    if skillLen == 1 then return self.skillArray[1][8].sort end
    for i = 1 ,skillLen do
        if self.skillArray[i][1]== skill.id then
            index = i
        end
    end
    if index == -1 then return skill.sort end
    --LogError("skillien:"..(index + 1)%skillLen.." slot:"..self.skillArray[(index + 1)%skillLen + 1][8].slot)
    return self.skillArray[(index + 1)%skillLen + 1][8].sort
end

function RoleLogic:LeaderCanCastSkilll()
    local isHave = self:CheckSkill(SkillBaseType.Magic)
    if not isHave then
        local isHave_p = self:CheckSkill(SkillBaseType.Physical)
            return isHave_p
    else
        return true
    end
end

-- 正常触发技能
function RoleLogic:CastSkill(func) 
    -- 设置轮转方法
    SkillManager.SetTurnRoundFunc(func)
    local haveSkill = false

    --> 是否被控制（眩晕或者冰冻）
    local isCtrl = self.ctrl_dizzy or self.ctrl_frozen

    -- 没有沉默
    -- if not self.ctrl_slient and self.Rage >= self.SuperSkillRage then
    local isHave, skilldata = self:CheckSkill(SkillBaseType.Magic)
    if isHave and skilldata then
        -- skilldata[-1] == 1是SkillLogicConfig表IgnoreControl字段 表示该技能无视控制出手
        if (not isCtrl and not self.ctrl_slient and not self.ctrl_chaos) or self.miss_ctrl or skilldata[-1] == 1 then    --< 混乱只释放普攻
            -- local isHave, skilldata = self:CheckSkill(SkillBaseType.Magic)
            -- 释放大技能
            self:AddSkill(SkillBaseType.Magic, true, nil, skilldata)
            haveSkill = true
            return haveSkill
        end
    end

    local isHave, skilldata = self:CheckSkill(SkillBaseType.Physical)
    -- 没有麻痹  释放普通技能
    if isHave and skilldata then
        if (not isCtrl and not self.ctrl_palsy) or self.miss_ctrl or skilldata[-1] == 1 then
            -- local isHave, skilldata = self:CheckSkill(SkillBaseType.Physical)
            self:AddSkill(SkillBaseType.Physical, true, nil, skilldata)
            haveSkill = true
            return haveSkill
        end
    end

    BattleLogManager.Log("### 无法填装技能"..self.roleId)
    -- LogError("### 无法填装技能")
    return haveSkill
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
        self:AddSkill(BattleSkillType.Normal, true, false, nil)
    elseif type == 2 and self.superSkill then 
        if self.Rage < self.SuperSkillRage then
            self.Rage = self.SuperSkillRage
        end
        self:AddSkill(BattleSkillType.Special, true, false, nil)
    end
end

--设置为替补属性
function RoleLogic:SetSubstitute(isTibu)
    self.substitute = isTibu
end

--判断是否为替补属性
function RoleLogic:IsSubstitute()
    return self.substitute
end

-- 判断是否可以去死了
function RoleLogic:IsCanDead()
    -- 暂时不能死
    if not self.deadFilter then
        return false
    end
    -- 还有我的技能没有释放,不能死啊
    --> 去掉死亡后释放问题
    -- if SkillManager.HaveMySkill(self) then
    --     return false
    -- end
    return true
end

-- 真的去死
function RoleLogic:GoDead()
    if self:IsCanDead() then
        self.isRealDead = true
        -- self.Rage = 0
        BattleLogic.BuffMgr:ClearBuff(self)
        BattleLogic.BuffMgr:RemoveBuffQueneBy(function(buff)
            return buff.target == self
        end)
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
    if self.isOutGame then
        return false
    end
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
        --[[
            BattleLogic.WaitForTrigger(0.1, function()
            BattleLogic.BuffMgr:ClearBuff(self)
            end)
        ]]
        local maxHp = self.data:GetData(RoleDataName.MaxHp)
        -- RoleManager.LogCa(
        --     "curframe:"..BattleLogic.CurFrame(),
        --     "Relive:"..maxHp,
        --     "RoleDataName.Hp:"..floor(self.reliveHPF * maxHp)
        -- )
         --LogError("self.reliveHPF"..self.reliveHPF)
         --LogError("hp"..floor(self.reliveHPF * maxHp))   
        self.data:SetValue(RoleDataName.Hp, floor(self.reliveHPF * maxHp))
        -- 发送复活事件
        self.Event:DispatchEvent(BattleEventName.RoleRelive, self)
        BattleLogic.Event:DispatchEvent(BattleEventName.RoleRelive, self)
        return true
    end
    return false
end

-- 永久死亡&移除本局游戏
function RoleLogic:SetOutBattle()
    self.isOutGame = true 
    self:SetReliveFilter(false)
end

-- 设置是否可以复活
function RoleLogic:SetReliveFilter(filter)
    if self.isOutGame and filter then --移除游戏后无法复活
        return
    end
    -- LogError(self.roleId.." SetReliveFilter "..tostring(filter))
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
    if CurRound == 0 then
        return false, nil
    end
    if self.leader then
        for k, skill in ipairs(self.skillArray) do
            while true
            do                                                 
                -- if skilltype == SkillBaseType.Physical and skill[8].slot ~= SkillSlotPos.Slot_0 then        --< 物理技能 排除magic skill
                --     break
                -- end
                -- if skilltype == SkillBaseType.Magic and skill[8].slot == SkillSlotPos.Slot_0 then
                --     break
                -- end
               -- LogError("camp:"..self.camp.."id: "..skill[1].." leaderskill CurRound"..CurRound.." skill.round:"..skill[8].sort)
                -- 0 1 2 3    1x0 2x1 3x2 4x3 5x0
                if tonumber(skill[8].sort) - 1 == (CurRound - 1) % 4  then
                --    LogError("id: "..skill[1].." leaderskill CurRound"..CurRound.." skill.round:"..skill[8].sort)
                   return true, skill
                end

                break
            end
        end
        return false, nil
    end

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
            --> cd为间隔数
            if CurRound == release then                                             --< 起始回合
                return true, skill
            elseif CurRound > release and (CurRound - release) % (cd + 1) == 0 then       --< cd回合
                return true, skill
            end
            break
        end
    end
    return false, nil
end

function RoleLogic:Update()
end

--> 初始人物为什么类型目标
function RoleLogic:InitRoleType()  
    -- if self.skillArray then
    --     for i = 1, #self.skillArray do
    --         if self.skillArray[i][9] then
    --             for j = 2, #self.skillArray[i][9] do
    --                 if self.skillArray[i][9][j] then
    --                     local effectType = self.skillArray[i][9][j][1]
    --                     if effectType == 245 then
    --                         self.miss_ctrl = true
    --                     end
    --                 end
    --             end
    --         end
    --     end
    -- end
    -- if self.passivity and self.passivity[1] and self.passivity[1][1] then
    --     for i = 1, #self.passivity[1][1] do
    --         local pEffectType = self.passivity[1][1][i]
    --         if pEffectType == 314 or pEffectType == 367 then
    --             self.isReliveOrSoulRole = true
    --         end
    --     end
    -- end


    --> 战法   --目前所以被动组都在其中
    self.warWayType = {}
    for k, v in ipairs(self.passivityIds) do
        local passivityIdStr = tostring(v)
        local passivityGroup = tonumber(string.sub(passivityIdStr, 1, -2))
        self.warWayType[passivityGroup] = 0
    end
end