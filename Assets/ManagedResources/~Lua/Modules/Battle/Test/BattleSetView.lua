
RoleSetView = {}
local MonsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
-- 初始化角色设置界面
function RoleSetView:Init(root)
    self.gameObject = root
    self.monsterId = Util.GetGameObject(root, "configId/input"):GetComponent("InputField")
    self.btnLoad = Util.GetGameObject(root, "configId/load")

    self.roleId = Util.GetGameObject(root, "roleId/input"):GetComponent("InputField")
    self.passivity = Util.GetGameObject(root, "passivity/input"):GetComponent("InputField")
    self.skill = Util.GetGameObject(root, "skill/input"):GetComponent("InputField")
    self.superSkill = Util.GetGameObject(root, "superSkill/input"):GetComponent("InputField")

    self.props = Util.GetGameObject(root, "props")
    self.propList = {}
    for i = 1, self.props.transform.childCount do
        self.propList[i] = Util.GetGameObject(self.props.transform:GetChild(i-1), "input"):GetComponent("InputField")
    end

    self.btnComfirm = Util.GetGameObject(root, "Root/confirm")
    self.deletefirm = Util.GetGameObject(root, "Root/delete")
    self.btnCancel = Util.GetGameObject(root, "Root/cancel")
    self.content = Util.GetGameObject(root, "Root/cancel"):GetComponent("Text")

    -- 
    Util.AddOnceClick(self.btnComfirm, function()
        self:ApplyData()
    end)
    -- 
    Util.AddOnceClick(self.deletefirm, function()
        self:RemoveData()
    end)
    -- 
    Util.AddOnceClick(self.btnCancel, function()
        self:Close()
    end)
    --
    Util.AddOnceClick(self.btnLoad, function()
        self:LoadFromConfig()
    end)
end

-- 根据配置加载数据
function RoleSetView:LoadFromConfig()
    local monsterId = tonumber(self.monsterId.text)
    local config = MonsterConfig[monsterId]
    if not config then

        return
    end

    local passivity = config.PassiveSkillList and table.concat(config.PassiveSkillList, "#") or ""
    local skill = config.SkillList[1] or ""
    local superSkill = config.SkillList[2] or ""
    self.localData = {
        monsterId,
        config.MonsterId,   -- roleId
        passivity,
        skill,
        superSkill,

        config.Level,
        config.Hp,
        config.Hp,
        config.Attack,
        config.PhysicalDefence,
        config.MagicDefence,
        config.Speed,
        config.DamageBocusFactor,
        config.DamageReduceFactor,
        config.Hit,
        config.CritFactor,
        config.CritDamageFactor,
        config.AntiCritDamageFactor,
        config.TreatFacter,
        config.CureFacter,
    }

    
    -- 设置数据
    self.roleId.text = self:GetLocalData(2)
    self.passivity.text = self:GetLocalData(3)
    self.skill.text = self:GetLocalData(4)
    self.superSkill.text = self:GetLocalData(5)
    for propIndex, prop in ipairs(self.propList) do
        prop.text = self:GetLocalData(propIndex + 5)
    end
end

-- 从本地加载数据
function RoleSetView:loadFromLocal()
    local dataStr = PlayerPrefs.GetString("test_battle_role_"..self.camp..self.pos)
    
    self.localData = string.split(dataStr, "|")
end

-- 保存数据到本地
function RoleSetView:saveToLocal()
    local str = ""
    str = str .. (self.data.monsterId or "")
    str = str .. "|"..(self.data.roleId or "")
    str = str .. "|"..(self.data.passivity or "")
    str = str .. "|"..(self.data.skill or "")
    str = str .. "|"..(self.data.superSkill or "")
    
    for propIndex, prop in ipairs(self.data.props) do
        str = str .. "|"..(prop or "")
    end
    
    PlayerPrefs.SetString("test_battle_role_"..self.camp..self.pos, str)
end

function  RoleSetView:GetLocalData(index)
    local defaultData = {
        "",     -- monsterID
        10001,  -- roleID
        "",     -- 被动
        1011,   -- 普技
        1012,   -- 特殊

        100,    -- 等级
        100000, -- hp
        100000, -- maxhp
        100,    -- attack
        0,    -- 物抗
        0,    -- 魔抗
        0,    -- 速度（未使用）
        0,    -- 伤害加成系数
        0,    -- 伤害减免系数
        1,    -- 命中率（未使用）
        0,    -- 闪避率（未使用）
        0.2,  -- 暴击率
        1.5,  -- 爆伤系数
        0,    -- 抗暴率
        1,    -- 治疗系数
        1,    -- 治愈系数
    }
    if not self.localData[index] or self.localData[index] == "" then
        return (defaultData[index] or 0)
    end
    return self.localData[index]
end

function RoleSetView:Show(camp, pos, data, func)
    data = data or {props = {}}
    self.gameObject:SetActive(true)
    self.camp = camp
    self.pos = pos
    self.data = data
    self.func = func
    self:loadFromLocal()    -- 加载本地资源

    -- 设置数据
    self.monsterId.text = data.monsterId or self:GetLocalData(1)
    self.roleId.text = data.roleId or self:GetLocalData(2)
    self.passivity.text = data.passivity or self:GetLocalData(3)
    self.skill.text = data.skill or self:GetLocalData(4)
    self.superSkill.text = data.superSkill or self:GetLocalData(5)
    for propIndex, prop in ipairs(self.propList) do
        prop.text = data.props[propIndex] or self:GetLocalData(propIndex + 5)
    end
end

-- 应用数据
function RoleSetView:ApplyData()
    self.data.monsterId = tonumber(self.monsterId.text)
    self.data.roleId = tonumber(self.roleId.text)
    self.data.passivity = self.passivity.text 
    self.data.skill = tonumber(self.skill.text)
    self.data.superSkill = tonumber(self.superSkill.text)
    for propIndex, prop in ipairs(self.propList) do
        local value = prop.text == "" and 0 or tonumber(prop.text) 
        self.data.props[propIndex] = tonumber(value)
    end
    -- 保存数据到本地
    self:saveToLocal()
    -- 应用数据
    if self.func then
        self.func(self.camp, self.pos, self.data)
        PopupTipPanel.ShowTipByLanguageId(10241)
    end
end

-- 应用数据
function RoleSetView:RemoveData()
    -- 应用数据
    if self.func then
        self.func(self.camp, self.pos, nil)
        PopupTipPanel.ShowTipByLanguageId(10242)
    end
end
-- 关闭界面
function RoleSetView:Close()
    self.gameObject:SetActive(false)

end

-- 异妖设置界面
MonsterSetView = {}

-- 初始化角色设置界面
function MonsterSetView:Init(root)
    self.gameObject = root
    self.monster1 = Util.GetGameObject(root, "monster1/input"):GetComponent("InputField")
    self.monster2 = Util.GetGameObject(root, "monster2/input"):GetComponent("InputField")
    self.monster3 = Util.GetGameObject(root, "monster3/input"):GetComponent("InputField")
    
    self.btnComfirm = Util.GetGameObject(root, "Root/confirm")
    self.btnCancel = Util.GetGameObject(root, "Root/cancel")
    self.content = Util.GetGameObject(root, "Root/cancel"):GetComponent("Text")

    -- 
    Util.AddOnceClick(self.btnComfirm, function()
        self:ApplyData()
    end)
    -- 
    Util.AddOnceClick(self.btnCancel, function()
        self:Close()
    end)

end

function MonsterSetView:Show(camp, data, func)
    self.gameObject:SetActive(true)
    self.camp = camp
    self.data = data or {}
    self.func = func
    self.monster1.text = data.monster1
    self.monster2.text = data.monster2
    self.monster3.text = data.monster3
end

-- 应用数据
function MonsterSetView:ApplyData()
    self.data.monster1 = self.monster1.text
    self.data.monster2 = self.monster2.text 
    self.data.monster3 = self.monster3.text 

    -- 应用数据
    if self.func then
        if self.func(self.camp, self.data) then
            PopupTipPanel.ShowTipByLanguageId(10241)
            return 
        end
    end
    PopupTipPanel.ShowTipByLanguageId(10243)
end

-- 关闭界面
function MonsterSetView:Close()
    self.gameObject:SetActive(false)
end



-- 全局设置界面
AllSetView = {}

-- 初始化角色设置界面
function AllSetView:Init(root)
    self.gameObject = root
    self.passivity = Util.GetGameObject(root, "passivity/input"):GetComponent("InputField")
    
    self.btnComfirm = Util.GetGameObject(root, "Root/confirm")
    self.btnCancel = Util.GetGameObject(root, "Root/cancel")
    self.content = Util.GetGameObject(root, "Root/cancel"):GetComponent("Text")

    -- 
    Util.AddOnceClick(self.btnComfirm, function()
        self:ApplyData()
    end)
    -- 
    Util.AddOnceClick(self.btnCancel, function()
        self:Close()
    end)

end

function AllSetView:Show(camp, data, func)
    self.gameObject:SetActive(true)
    self.camp = camp
    self.data = data or {}
    self.func = func
    self.passivity.text = data.passivity
end

-- 应用数据
function AllSetView:ApplyData()
    self.data.passivity = self.passivity.text
    -- 应用数据
    if self.func then
        if self.func(self.camp, self.data) then
            PopupTipPanel.ShowTipByLanguageId(10241)
            return 
        end
    end
    PopupTipPanel.ShowTipByLanguageId(10243)
end

-- 关闭界面
function AllSetView:Close()
    self.gameObject:SetActive(false)
end



-- 全局设置界面
SkillSetView = {}

local MonsterViewConfig = ConfigManager.GetConfig(ConfigName.MonsterViewConfig)
local MonsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local RoleConfig = ConfigManager.GetConfig(ConfigName.RoleConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)

-- 初始化角色设置界面
function SkillSetView:Init(root)
    self.gameObject = root
    self.rt = Util.GetGameObject(root, "role/time1/input"):GetComponent("InputField")
    self.rt2 = Util.GetGameObject(root, "role/time2/input"):GetComponent("InputField")
    self.nt1 = Util.GetGameObject(root, "normal/time1/input"):GetComponent("InputField")
    self.nt2 = Util.GetGameObject(root, "normal/time2/input"):GetComponent("InputField")
    self.st1 = Util.GetGameObject(root, "special/time1/input"):GetComponent("InputField")
    self.st2 = Util.GetGameObject(root, "special/time2/input"):GetComponent("InputField")
    
    
    self.btnComfirm = Util.GetGameObject(root, "Root/confirm")
    self.btnCancel = Util.GetGameObject(root, "Root/cancel")

    -- 
    Util.AddOnceClick(self.btnComfirm, function()
        self:ApplyData()
    end)
    -- 
    Util.AddOnceClick(self.btnCancel, function()
        self:Close()
    end)

end

function SkillSetView:Show(camp, pos, BattleView)
    self.gameObject:SetActive(true)
    self.camp = camp
    self.pos = pos
    self.role = RoleManager.GetRole(camp, pos)
    self.roleView = BattleView.GetRoleView(self.role)

    local nSkillId = self.role.roleData.skill[1]
    local sSkillId = self.role.roleData.superSkill[1]

    self.rt.text = self.roleView.spAtkTime*1000
    self.rt2.text = self.roleView.atkSoundTime*1000
    
    local nCombat = BattleManager.GetSkillCombat(SkillLogicConfig[nSkillId].SkillDisplay)
    self.nt1.text = nCombat.BulletTime
    self.nt2.text = nCombat.KeyFrame

    local sCombat = BattleManager.GetSkillCombat(SkillLogicConfig[sSkillId].SkillDisplay)
    self.st1.text = sCombat.BulletTime
    self.st2.text = sCombat.KeyFrame

    
end

-- 应用数据
function SkillSetView:ApplyData()
    local nSkillId = self.role.roleData.skill[1]
    local sSkillId = self.role.roleData.superSkill[1]

    self.roleView.spAtkTime = (tonumber(self.rt.text)or 0)/1000 
    self.roleView.atkSoundTime = (tonumber(self.rt2.text)or 0)/1000 

    local ncId = SkillLogicConfig[nSkillId].SkillDisplay
    local nCombat = BattleManager.GetSkillCombat(ncId)
    local nBulletTime = tonumber(self.nt1.text) or 0
    local nKeyFrame =  tonumber(self.nt2.text) or 0
    nCombat.BulletTime = nBulletTime
    nCombat.KeyFrame = nKeyFrame
    BattleManager.SetSkillCombat(ncId, nCombat)
    for i=2, #self.role.skill do
        self.role.skill[2] = nKeyFrame/1000
    end
    
    local scId = SkillLogicConfig[sSkillId].SkillDisplay
    local sCombat = BattleManager.GetSkillCombat(scId)
    local sBulletTime = tonumber(self.st1.text) or 0
    local sKeyFrame =  tonumber(self.st2.text) or 0
    sCombat.BulletTime = sBulletTime
    sCombat.KeyFrame = sKeyFrame
    BattleManager.SetSkillCombat(scId, sCombat)
    for i=2, #self.role.superSkill do
        self.role.superSkill[2] = sKeyFrame/1000
    end

    PopupTipPanel.ShowTipByLanguageId(10241)
end

-- 关闭界面
function SkillSetView:Close()
    self.gameObject:SetActive(false)
end