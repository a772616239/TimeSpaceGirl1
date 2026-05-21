FightUnitLogic = {}
FightUnitLogic.__index = FightUnitLogic

local Random = Random
local floor = math.floor
local max = math.max
local min = math.min

local skillPool = BattleObjectPool.New(function ()
    return Skill:New()
end)

function FightUnitLogic.New()
    local instance = {type = 0, unitData = 0, data = RoleData.New(), camp = 0, name = 0,
                      Event = BattleEvent:New()}
    setmetatable(instance, FightUnitLogic)
    return instance
end

function FightUnitLogic:Init(data)
    self.type = data.type
    self.unitData = data
    if data.property == nil or next(data.property) == nil or #data.property == 0 then  --< 无属性的服务端没传战斗属性 用下值
        self.data:Init(self, {0,0,0,0,0,  0,0,0,0,10000,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0, 0,0,0,0,0,  0,0})
    else
        self.data:Init(self, data.property)
    end


    self.camp = data.camp --阵营 0：我方 1：敌方
    self.name = data.name

    self.position = 99999   --< 应对log nil问题

    self.Event:ClearEvent()

    self.skill = data.skill     --< 改为数组 航母多个技能

    -- self.round = data.round or -1


    self.lockTarget = nil       --嘲讽
    self.ctrl_dizzy = false     --眩晕  不能释放所有技能
    self.ctrl_slient = false    --沉默  只能1技能
    self.ctrl_palsy = false     --麻痹  只能2技能
    self.ctrl_noheal = false    --禁疗
    self.ctrl_blind = false     --致盲
    self.ctlr_seal = false      --封印
    self.ctrltimes = 0          --< 控制次数

    self.deadFilter = true    -- 控制死亡，置为false则角色暂时无法死亡


    self.effect218times = 0     --< effect 218 触发次数
    self.skilling = false       --< 技能间
end

function FightUnitLogic:Dispose()
    
end


-- 判断角色是否可以释放技能
function FightUnitLogic:IsAvailable()
    return true
end

-- 释放技能
function FightUnitLogic:SkillCast(skill, func)
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

    skill:CastUnit(_CastDone)
end


-- 加入一个技能
-- type         加入的技能类型 --< 修改为physical magic
-- targets      指定目标
-- isAdd        是否是追加技能
-- effectData   战斗技能数据
function FightUnitLogic:AddSkill(type, isAdd, targets, effectData)
    
    SkillManager.AddSkill(self, effectData, type, targets, isAdd)

    -- BattleLogManager.Log(
    --     "Add Skill",
    --     "camp", self.camp,
    --     "pos", self.position,
    --     "type", type,
    --     -- "isRage", tostring(isRage),
    --     "isAdd", tostring(isAdd),
    --     "targets", targets and #targets or "0"
    -- )
end


-- 正常触发技能
function FightUnitLogic:CastSkill(func) 
    -- 设置轮转方法
    SkillManager.SetTurnRoundFunc(func)
    local haveSkill = false
    local isHave, skilldata = self:CheckSkill()
    -- 释放大技能

    if isHave then
        --> 去掉skilltype判断  都应该是魔法
        self:AddSkill(SkillBaseType.Magic, true, nil, skilldata)
        haveSkill = true
    else

    end



    return haveSkill
end

--> 检测技能list中 可释放的技能
function FightUnitLogic:CheckSkill()
    local CurRound, MaxRound = BattleLogic.GetCurRound()
    
    
    for k, skill in ipairs(self.skill) do
        local cd = skill[8].cd
        local release = skill[8].release
        
        
        
        
        if CurRound == release then                                                     --< 起始回合
            return true, skill
        elseif CurRound > release and (CurRound - release) % (cd + 1) == 0 then         --< cd回合
            return true, skill
        end
    end

    return false, nil
end

function FightUnitLogic:GetRoleData(property)
    local tarPro = self.data:GetData(property)
    -- local item
    -- for i=1, self.proTranList.size do
    --     item = self.proTranList.buffer[i]
    --     if item.proName == property then
    --         local value
    --         if item.changeType == 1 then --加算
    --             value = item.tranFactor
    --         elseif item.changeType == 2 then --乘加算（百分比属性加算）
    --             value = BattleUtil.ErrorCorrection(self.data:GetData(item.tranProName) * item.tranFactor)
    --         elseif item.changeType == 3 then --减算
    --             value = -item.tranFactor
    --         elseif item.changeType == 4 then --乘减算（百分比属性减算）
    --             value = -BattleUtil.ErrorCorrection(self.data:GetData(item.tranProName) * item.tranFactor)
    --         end
    --         tarPro = tarPro + value
    --     end
    -- end
    return tarPro
end

--> 应对被动
function FightUnitLogic:AddBuff(...)
end

function FightUnitLogic:Update()

end