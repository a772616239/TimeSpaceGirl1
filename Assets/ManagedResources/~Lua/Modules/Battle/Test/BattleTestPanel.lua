require("Base/BasePanel")
require("Base/Stack")
require("Modules.Battle.Config.PokemonEffectConfig")
require("Modules/Battle/Test/BattleSetView")
local MonsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local BattleView = require("Modules/Battle/View/BattleView")
BattleTestPanel = Inherit(BasePanel)

local this = BattleTestPanel
local battleTimeScaleKey = "battleTimeScaleKey"

local timeCount
local endFunc
local levelId
local isTestFight = false
local isBack = false --是否为战斗回放
local fightType -- 1关卡 2副本 3限时怪, 5兽潮, 6新关卡, 7公会boss
local orginLayer

-- 显示跳过战斗使用
local hadCounted = 0

local TestFightData = {
    playerData = { teamSkill = {}, teamPassive = {} },
    enemyData = {{teamSkill = {}, teamPassive = {} }},
}
local roleTestData = {}
local monsterTestData = {}
local allTestData = {}

local _IsStart = false
local _IsCanNext = false


--初始化组件（用于子类重写）
function this:InitComponent()
    BattleView:InitComponent(self)
    orginLayer = 0

    this.UpRoot = Util.GetGameObject(self.gameObject, "UpRoot")
    this.DownRoot = Util.GetGameObject(self.gameObject, "DownRoot")

    this.Option = Util.GetGameObject(this.UpRoot, "option")
    this.roundText = Util.GetGameObject(this.Option, "timeCount"):GetComponent("Text")
    this.orderText = Util.GetGameObject(this.Option, "order/text"):GetComponent("Text")
    this.BtnTimeScale = Util.GetGameObject(this.DownRoot, "option/BtnTimeScale")


    this.tOption = Util.GetGameObject(self.gameObject, "Test/option")
    this.BtnStrat = Util.GetGameObject(this.tOption, "BtnStrat")
    this.BtnPause = Util.GetGameObject(this.tOption, "BtnPause")
    this.BtnNext = Util.GetGameObject(this.tOption, "BtnNext")
    this.IsSingle = Util.GetGameObject(this.tOption, "isSingle"):GetComponent("Toggle")
    this.IsSkill = Util.GetGameObject(this.tOption, "isSkill"):GetComponent("Toggle")
    this.btnLoadMy = Util.GetGameObject(this.tOption, "loadMy")
    this.btnLoadMonster = Util.GetGameObject(this.tOption, "loadMonster")
    this.monsterGroupId = Util.GetGameObject(this.tOption, "loadMonster/InputField"):GetComponent("InputField")
    
    this.SkillOption = Util.GetGameObject(self.gameObject, "skillOption")


    

    -- 初始化设置界面
    RoleSetView:Init(Util.GetGameObject(self.gameObject, "roleSet"))
    MonsterSetView:Init(Util.GetGameObject(self.gameObject, "monsterSet"))
    AllSetView:Init(Util.GetGameObject(self.gameObject, "allSet"))
    SkillSetView:Init(Util.GetGameObject(self.gameObject, "skillSet"))


    this.MyRolePosList = {}
    this.EnemyRolePosList = {}
    for i = 1 , 6 do
        this.MyRolePosList[i] = Util.GetGameObject(self.gameObject, "Test/role/"..i.."/root")
        this.EnemyRolePosList[i] = Util.GetGameObject(self.gameObject, "Test/enemy/btn"..i)
    end

end

--绑定事件（用于子类重写）
function this:BindEvent()

    Util.AddClick(this.BtnTimeScale, function ()
        if Time.timeScale > 2 then
            Time.timeScale = 0.5
        else
            Time.timeScale = math.floor(Time.timeScale + 1)
        end
        this.SwitchTimeScale()
    end)

    Util.AddClick(this.BtnStrat, function ()
        -- 开始战斗
        if _IsStart then
            --TODO: 
            BattleView:StopBattle()
            _IsStart = false
            this.SkillOption:SetActive(false)
            BattleView.Clear()
            BattleView:OnClose()

            BattleView.InitBattleEvent()
            this.RefreshAllRoleShow()

        else

            BattleView:ClearRole()
            this:SetData()
            BattleView:StartBattle()
            BattleLogic.SetIsDebug(this.IsSingle.isOn)
            BattleLogic.Event:AddEvent(BattleEventName.DebugStop, this.OnDebugStop)
            this.InitSkillOption()
            _IsStart = true
        end
    end)
    Util.AddClick(this.BtnPause, function ()
        if _IsStart then
            -- 战斗暂停
            if BattleManager.IsBattlePlaying() then
                BattleManager.PauseBattle()
            else
                BattleManager.ResumeBattle()
            end
        end
    end)

    Util.AddClick(this.BtnNext, function ()
        if _IsCanNext then
            _IsCanNext = false
            BattleLogic.TurnRound(true)
        end
    end)

    this.IsSingle.onValueChanged:AddListener(function(state)
        if not state then
            this.IsSkill.isOn = false
        end
    end)
    this.IsSkill.onValueChanged:AddListener(function(state)
        if state then
            this.IsSingle.isOn = true
        end
    end)


    Util.AddClick(this.btnLoadMy, function ()
        TestFightData.playerData = BattleManager.GetBattlePlayerData()
        if not TestFightData.playerData then
            PopupTipPanel.ShowTipByLanguageId(10246)
            return 
        end
        -- 加载角色
        this.RefreshAllRoleShow()
    end)

    Util.AddClick(this.btnLoadMonster, function ()
        local gId = tonumber(this.monsterGroupId.text)
        if not gId then
            PopupTipPanel.ShowTipByLanguageId(10247)
            return
        end
        TestFightData.enemyData = BattleManager.GetBattleEnemyData(gId)
        if not TestFightData.enemyData[1] then
            PopupTipPanel.ShowTipByLanguageId(10248)
            return 
        end
        -- 加载角色
        this.RefreshAllRoleShow()
    end)

    -- 
    for i = 1 , 6 do
        Util.AddClick(this.MyRolePosList[i], function()
            if _IsStart then
                PopupTipPanel.ShowTipByLanguageId(10249)
                return
            end
            RoleSetView:Show(0, i, roleTestData[i], this.ApplyRoleData)
        end)
        Util.AddClick(this.EnemyRolePosList[i], function()
            if _IsStart then
                PopupTipPanel.ShowTipByLanguageId(10249)
                return
            end
            RoleSetView:Show(1, i, roleTestData[i+6], this.ApplyRoleData)
        end)
    end
end

function this:LoseJump(id)
    if not MapManager.isInMap then
        if JumpManager.CheckJump(id) then
            this:ClosePanel()
            JumpManager.GoJumpWithoutTip(id)
        end
    else
        PopupTipPanel.ShowTipByLanguageId(10250)
    end
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

-- 
function this.OnDebugStop()
    _IsCanNext = true
end



function this:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.gameObject, this.sortingOrder - orginLayer)
    orginLayer = this.sortingOrder
    
    BattleView:OnSortingOrderChange(this.sortingOrder)
end

--界面打开时调用（用于子类重写）
function this:OnOpen()
    BattleView:Init()

    TestFightData = {
        playerData = { teamSkill = {}, teamPassive = {} },
        enemyData = {{teamSkill = {}, teamPassive = {} }},
    }
    this.InitPanelData()

    SoundManager.PlayMusic(SoundConfig.BGM_Battle_1, true, function()
        SoundManager.PlayMusic(SoundConfig.BGM_Battle_2, false)
    end)

    
    this.SkillOption:GetComponent("Canvas").sortingOrder = BattleManager.GetBattleSorting() + 200
end

-- 设置数据
function this:SetData()
    BattleView:SetData(TestFightData, nil, 1, 90)
end

-- 根据当前设置生成战斗数据
function this.RefreshFightData(type)
    if not type or type == 1 then
        TestFightData.playerData = { teamSkill = {}, teamPassive = {} }
        TestFightData.enemyData = {{teamSkill = {}, teamPassive = {} }}
        for i = 1, 12 do
            local role = roleTestData[i]
            if role then
                local data = {}
                data.camp = math.floor((i-1)/6)
                data.position = (i - 1) % 6 + 1
                data.monsterId = role.monsterId
                data.roleId = role.roleId
                local roleData
                if role.roleId > 10000 then
                    roleData = ConfigManager.GetConfigData(ConfigName.HeroConfig, data.roleId)
                else
                    roleData = ConfigManager.GetConfigData(ConfigName.MonsterConfig, data.monsterId)
                end
                data.element = roleData.PropertyName
                data.professionId = roleData.Profession
                data.quality = roleData.Quality
                data.star = 10
                data.type = 1
                local paskill = string.split(role.passivity, "#")
                data.passivity = BattleManager.GetPassivityData(paskill) or {}
                data.property = {}
                for pi = 1, 25 do
                    data.property[pi] = role.props[pi] or 0
                end
                data.skill = BattleManager.GetSkillData(role.skill) or {}
                data.superSkill = BattleManager.GetSkillData(role.superSkill) or {}
                -- 添加角色数据
                this.AddRoleData(data)
            end
        end 
    end

    if not type or type == 2 then

    end

    if not type or type == 3 then

    end
    --
    this.RefreshAllRoleShow()

end
-- 角色数据
function this.ApplyRoleData(camp, pos, data)
    if camp == 0 then
        roleTestData[pos] = data
    else
        roleTestData[pos+6] = data
    end

    this.RefreshFightData(1)    
end

-- 增加一个数据
function this.AddRoleData(data)
    local camp = data.camp
    local pos = data.position
    if camp == 0 then
        local rIndex
        for index, role in ipairs(TestFightData.playerData) do
            if role.position == pos then
                rIndex = index
                break
            end
        end
        if rIndex then
            TestFightData.playerData[rIndex] = data
        else
            table.insert(TestFightData.playerData, data)
        end

    else
        local rIndex
        for index, role in ipairs(TestFightData.enemyData[1]) do
            if role.position == pos then
                rIndex = index
                break
            end
        end
        if rIndex then
            TestFightData.enemyData[1][rIndex] = data
        else
            table.insert(TestFightData.enemyData[1], data)
        end
    
    end
end


-- 刷新显示
function this.RefreshAllRoleShow()
    BattleView:ClearRole()
    -- body
    if TestFightData.enemyData[1] then
        -- 加载角色
        for _, data in ipairs(TestFightData.enemyData[1]) do
            RoleManager.AddRole(data, data.position)
        end
    end

    if TestFightData.playerData then
        -- 加载角色
        for _, data in ipairs(TestFightData.playerData) do
            RoleManager.AddRole(data, data.position)
        end
    end
end

-- 异妖数据
function this.ApplyMonsterData(camp, data)
    
end
-- 全局被动
function this.ApplyAllData(camp, data)
    
end

-- 初始化
function this.InitPanelData()
    --显示倒计时
    local curRound, maxRound = BattleLogic.GetCurRound()
    this.roundText.text = string.format(GetLanguageStrById(10252), curRound, maxRound)
    hadCounted = 0
    
    this.Option:SetActive(true)

    this.SwitchTimeScale()
end


function this.SwitchTimeScale()
    local _scale = math.floor(Time.timeScale)
    local child = this.BtnTimeScale.transform.childCount - 3 -- 3倍速时-2
    local s = "x".. _scale
    for i=1, child do
        local g = this.BtnTimeScale.transform:GetChild(i-1).gameObject
        g:SetActive(g.name == s)
    end
end

function this.BattleEnd(result)
    BattleManager.PauseBattle()

end


-- 战斗波次变化回调
function this.OnOrderChanged(order)
    -- body
    --显示波次
    this.orderText.text = string.format("%d/%d", order, BattleLogic.TotalOrder)
end

-- 战斗回合变化回调
function this.OnRoundChanged(round)
    -- body
    --显示波次
    local curRound, maxRound = BattleLogic.GetCurRound()
    this.roundText.text = string.format(GetLanguageStrById(10252), curRound, maxRound)

end

-- 由BattleView驱动
function this.OnUpdate()
    
end

-- 初始化技能选项
function this.InitSkillOption()
    this.SkillOption:SetActive(this.IsSkill.isOn)
    if this.IsSkill.isOn then
        for i = 1, 12 do
            local camp = math.floor((i-1)/6)
            local pos = i - camp*6
            local btn1 = Util.GetGameObject(this.SkillOption, i.."/1")
            local btn2 = Util.GetGameObject(this.SkillOption, i.."/2")
            local btn3 = Util.GetGameObject(this.SkillOption, i.."/3")
            Util.AddOnceClick(btn1, function()
                if _IsCanNext then
                    local role = RoleManager.GetRole(camp, pos)
                    if not role then return end
                    _IsCanNext = false
                    role:ForceCastSkill(1, nil, function()
                        _IsCanNext = true
                    end)
                end
            end)
            Util.AddOnceClick(btn2, function()
                if _IsCanNext then
                    local role = RoleManager.GetRole(camp, pos)
                    if not role then return end
                    _IsCanNext = false
                    role:ForceCastSkill(2, nil, function()
                        _IsCanNext = true
                    end)
                end
            end)
            Util.AddOnceClick(btn3, function()
                SkillSetView:Show(camp, pos, BattleView)
            end)
        end
    end
end



--界面关闭时调用（用于子类重写）
function this:OnClose()
    BattleView:OnClose()
    Time.timeScale = 1
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    BattleView:OnDestroy()
end

return this