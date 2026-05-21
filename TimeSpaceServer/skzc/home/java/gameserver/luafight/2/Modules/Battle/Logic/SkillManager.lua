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
    WYLog("SkillManager 1111")
    local skill = skillPool:Get()
    skill:Init(caster, effectData, type, targets, isAdd)
    table.insert(this.SkillList, skill)
    WYLog("SkillManager 2222")
    return skill
end
-- 插入技能到技能列表首位
function this.InsertSkill(caster, effectData, type, targets, isAdd)
    local skill = skillPool:Get()
    skill:Init(caster, effectData, type, targets, isAdd)
    table.insert(this.SkillList, 1, skill)
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


-- 设置用于轮转的方法
function this.SetTurnRoundFunc(func)
    -- LogYellow("### 设置CastSkill回调")
    -- WYLog(func)
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
    -- LogYellow("SkillManager 轮转")
    -- WYLog(this.TurnRoundFunc)
    if this.TurnRoundFunc then
        BattleLogic.WaitForTrigger(0.3, function()
            -- LogBlue(Language[10239])
            this.TurnRoundFunc()            --< 轮转时 会赋值 屏蔽置空
            -- this.TurnRoundFunc = nil

            -- LogYellow("SkillManager 完成清理")
            -- WYLog(this.TurnRoundFunc)
        end)
    end
end

-- 
function this.Update()
    -- 
    if this.IsSkilling then
        return 
    end
    if not this.SkillList or #this.SkillList == 0 then
        return
    end
    
    local skill = this.SkillList[1]
    table.remove(this.SkillList, 1)
    this.IsSkilling = true
    -- 检测技能释放
    skill.owner:SkillCast(skill, function()
        skill:Dispose()
        skillPool:Put(skill)
        this.IsSkilling = false
        -- 检测一下轮转
        this.CheckTurnRound()
    end)
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