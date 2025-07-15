SkillManager = {}
local this = SkillManager

local skillPool = BattleObjectPool.New(function ()
    return Skill:New()
end)

-- 
this.SkillList = {}
this.IsSkilling = false
-- 初始化
function this.Init()
    this.Clear()
end

-- 向技能列表中追加技能
function this.AddSkill(caster, effectData, type, targets, isAdd)
    
    local skill = skillPool:Get()
    skill:Init(caster, effectData, type, targets, isAdd)
    table.insert(this.SkillList, skill)
    
    return skill
end
-- 插入技能到技能列表首位
function this.InsertSkill(caster, effectData, type, targets, isAdd, skillSubType)
    if #this.SkillList <= 1 then
        local skill = skillPool:Get()
        skill:Init(caster, effectData, type, targets, isAdd, skillSubType)
        table.insert(this.SkillList, 1, skill)

    else
        this.InsertSkillAfter(caster, effectData, type, targets, isAdd, skillSubType)
    end
    return skill
end
-- 插入技能到后一位
function this.InsertSkillAfter(caster, effectData, type, targets, isAdd, skillSubType)
    local skill = skillPool:Get()
    skill:Init(caster, effectData, type, targets, isAdd, skillSubType)
    local index = #this.SkillList
    table.insert(this.SkillList, index + 1, skill)
    return skill
end

-- 获取是否拥有我的技能未释放
function this.HaveMySkill(role)
    for _, skill in ipairs(this.SkillList) do
        if skill.owner == role then
            return true 
        end
    end
    return false
end

--是否有追加技能 
function this.HaveAddSkill(role)
    local skill = this.SkillList[1]
    if skill.owner.Equle(role) then
        return true
    end
    return false
end

-- 设置用于轮转的方法
function this.SetTurnRoundFunc(func)
    
    
    this.TurnRoundFunc = func
end
function this.CheckTurnRound()
    if this.IsSkilling then
        return 
    end
    if this.SkillList and #this.SkillList > 0 then
        return
    end
    -- 没有技能释放的时候才轮转
    
    
    if this.TurnRoundFunc then
        BattleLogic.WaitForTrigger(0.3, function()
            
            this.TurnRoundFunc()            --< 轮转时 会赋值 屏蔽置空
            -- this.TurnRoundFunc = nil

            
            
        end)
    end
end

-- 
function this.Update()
     -- 如果正在引导战斗
     if BattleManager and BattleManager.IsGuidePause() then
        return 
    end
    -- 
    if this.IsSkilling then
        return 
    end
    if not this.SkillList or #this.SkillList == 0 then
        return
    end
    
    local skill = this.SkillList[1]
    this.TurnNextSkill(this.SkillList)
    this.IsSkilling = true
    -- 检测技能释放
    skill.owner:SkillCast(skill, function()
        -- LogError("SkillCast"..skill.owner.roleId)
        skill:Dispose()
        skillPool:Put(skill)
        this.IsSkilling = false
        -- 检测一下轮转
        this.CheckTurnRound()
    end)
end

function this.TurnNextSkill(_skillTable)
    if #_skillTable > 1 then
        for i=1,#_skillTable - 1 do
            _skillTable[i]=_skillTable[i+1]
        end
        local last = #_skillTable
        table.remove(_skillTable,last)
    else
        table.remove(_skillTable, 1)
    end
end

-- 清除
function this.Clear()
    for _, skill in ipairs(this.SkillList) do
        skill:Dispose()
        skillPool:Put(skill)

    end
    this.SkillList = {}
    this.IsSkilling = false
end


return SkillManager