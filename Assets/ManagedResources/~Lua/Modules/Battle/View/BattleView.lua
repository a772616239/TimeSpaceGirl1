require("Base/BasePanel")
require("Modules.Battle.Config.PokemonEffectConfig")
local FEAConfig = require("Modules/Battle/Config/FightEffectAudioConfig")
-- local RoleShowView = require("Modules/Battle/View/BattleRoleShowView")
local TurretRotationConfig = ConfigManager.GetConfig(ConfigName.TurretRotationConfig)
local BattleView = {}
local this = BattleView

--敌军站位分布
--敌军站位根节点Y坐标
local posY = 0
local posOffset = 0

local tbRole = {}
local tbRoleDispose = {}

local unitView = {}

local playerHP = 0
local playerMaxHP = 0
local enemyHP = 0
local enemyMaxHP = 0
local playerTmpHp
local enemyTmpHp

local delayRecycleList = {}

local LastDebugTime     -- 点击调试键的时间间隔需要大于0.1秒

IsLoadFightLocalPt = false -- 战斗位置信息记录

this.IsJumpGameEnd = false  --< 是否是跳过结束 用于是否要延时结算

local iHaveSupport --我方守护
local iHaveAdjutant --我方先驱
local iHaveAircraft --我方主角
local enemyHaveSupport  --敌方守护
local enemyHaveAdjutant --敌方先驱
local enemyHaveAircraft --敌方主角
local IsEndBattle=false
--live
FightCampLocalPosition = {
    [0] = {},
    [1] = {}
}
--model
FightCampTargetLocalPosition = {
    [0] = {},
    [1] = {}
}

FightCampLPToSkillRoot = {
    [0] = {},
    [1] = {}
}

local OuterUnitPt = {
    {},{},{},{}
}

local scene = {
    "r_zhandou_changjing016",
    "r_zhandou_changjing016",
    "r_zhandou_changjing016",
}

local mineNum = 0
local enemyNum = 0

local loadAsset = function(path)
    local go = poolManager:LoadAsset(path, PoolManager.AssetType.GameObject)
    local layer = tonumber(go.name) or 0
    local battleSorting = BattleManager.GetBattleSorting()
    Util.AddParticleSortLayer(go, battleSorting - layer)
    go.name = tostring(battleSorting)
    --- 播放音效
    local audioData = FEAConfig.GetAudioData(path)
    if audioData then
        SoundManager.PlaySound(audioData.name)
    end
    return go
end

--所有需要延迟回收的资源走该接口，当回调执行前界面已被销毁时，不会报错
local addDelayRecycleRes = function(path, go, recycleTime, delayFunc, delayTime)
    if not delayRecycleList[path] then
        delayRecycleList[path] = {}
    end
    table.insert(delayRecycleList[path], go)

    if delayTime and delayTime < recycleTime then
        Timer.New(delayFunc, delayTime):Start()
        Timer.New(function ()
            if not delayRecycleList[path] then return end
            go:SetActive(false)
            for i = 1, #delayRecycleList[path] do
                if delayRecycleList[path][i] == go then
                    poolManager:UnLoadAsset(path, go, PoolManager.AssetType.GameObject)
                    table.remove(delayRecycleList[path], i)
                    break
                end
            end
        end, recycleTime):Start()
    else
        Timer.New(function ()
            if not delayRecycleList[path] then return end
            go:SetActive(false)
            for i=1, #delayRecycleList[path] do
                if delayRecycleList[path][i] == go then
                    poolManager:UnLoadAsset(path, go, PoolManager.AssetType.GameObject)
                    table.remove(delayRecycleList[path], i)
                    break
                end
            end
            if delayFunc then
                delayFunc()
            end
        end, recycleTime):Start()
    end
end


function this:InitComponent(root, battleSceneLogic, battleScene)
    this.camera3DPos = Util.GetGameObject(battleScene, "CameraRoot/CameraPos").transform
    this.camera3D = Util.GetGameObject(battleScene, "CameraRoot/CameraPos/Camera"):GetComponent("Camera")
    this.cameraUI = UIManager.GetCamera()
    this.battleSceneLayer = LayerMask.NameToLayer("BattleScene")
    this.battleSceneSkillTransform = Util.GetGameObject(battleSceneLogic, "Skill").transform
    this.closeupPos = Util.GetGameObject(battleScene, "CameraRoot/CameraPos/CloseupPos").transform
    this.pvPos = Util.GetGameObject(battleScene, "PVPos").transform

    -- body
    this.root = root
    this.battleSceneLogic = battleSceneLogic
    this.battleScene = battleScene
    this.gameObject = root.gameObject
    this.transform = root.transform

    this.BuffItem = Util.GetGameObject(this.gameObject, "BuffIcon")
    this.RoleItem = Util.GetGameObject(this.gameObject, "Role")
    this.EnemyItem = Util.GetGameObject(this.gameObject, "Enemy")
    this.UnitPre = Util.GetGameObject(this.gameObject, "UnitPre")

    this.UpRoot = Util.GetGameObject(this.gameObject, "UpRoot")
    this.DownRoot = Util.GetGameObject(this.gameObject, "DownRoot")

    this.DiffMonster = Util.GetGameObject(this.DownRoot, "teamSkill")
    this.DiffMonsterFlag = false
    this.DiffMonsterSlider = Util.GetGameObject(this.DiffMonster, "slider"):GetComponent("Image")
    this.DiffMonsterIcon = Util.GetGameObject(this.DiffMonster, "icon"):GetComponent("Image")

    this.EnemyDiffMonster = Util.GetGameObject(this.UpRoot, "teamSkill")
    this.EnemyDiffMonsterFlag = false
    this.EnemyDiffMonsterSlider = Util.GetGameObject(this.EnemyDiffMonster, "slider"):GetComponent("Image")
    this.EnemyDiffMonsterIcon = Util.GetGameObject(this.EnemyDiffMonster, "icon"):GetComponent("Image")

    Util.GetGameObject(this.UpRoot, "EnemyHP"):SetActive(false)
    Util.GetGameObject(this.DownRoot, "PlayerHP"):SetActive(false)
    this.EnemyHP = Util.GetGameObject(this.UpRoot, "EnemyHP/hp"):GetComponent("Image")
    this.EnemyHPTxt = Util.GetGameObject(this.UpRoot, "EnemyHP/Text"):GetComponent("Text")
    this.PlayerHP = Util.GetGameObject(this.DownRoot, "PlayerHP/hp"):GetComponent("Image")
    this.PlayerHPTxt = Util.GetGameObject(this.DownRoot, "PlayerHP/Text"):GetComponent("Text")

    this.EnemyPanel = Util.GetGameObject(self.gameObject, "EnemyPanel")
    this.MinePanel = Util.GetGameObject(self.gameObject, "MinePanel")

    this.Right = Util.GetGameObject(self.battleSceneLogic, "Right")
    this.Left = Util.GetGameObject(self.battleSceneLogic, "Left")

    this.mineLeaderSkill = Util.GetGameObject(this.gameObject, "leftLeaderMan")
    this.enemyLeaderSkill = Util.GetGameObject(this.gameObject, "rightLeaderMan")
    this.mineLeaderSkill:SetActive(false)
    this.enemyLeaderSkill:SetActive(false)

    this.mine = Util.GetGameObject(self.gameObject, "DownRoot/option/OuterUnit/mine")
    this.OuterUnit_0_first = Util.GetGameObject(this.mine, "first")
    this.OuterUnit_0_second = Util.GetGameObject(this.mine, "second")

    this.OuterUnit_0_firstPos = this.OuterUnit_0_first.transform.localPosition
    this.OuterUnit_0_secondPos = this.OuterUnit_0_second.transform.localPosition

    this.enemy = Util.GetGameObject(self.gameObject, "DownRoot/option/OuterUnit/enemy")
    this.OuterUnit_1_first = Util.GetGameObject(this.enemy, "first")
    this.OuterUnit_1_second = Util.GetGameObject(this.enemy, "second")

    this.OuterUnit_1_firstPos = this.OuterUnit_1_first.transform.localPosition
    this.OuterUnit_1_secondPos = this.OuterUnit_1_second.transform.localPosition
    
    this.minepart = Util.GetGameObject(self.gameObject, "DownRoot/option/left")
    this.headpart_mine = Util.GetGameObject(this.minepart, "headpart")
    this.name_mine = Util.GetGameObject(this.minepart, "mineName")
    this.zhenBuff_mine = Util.GetGameObject(this.minepart, "zhenBuff")
    this.zhenxing_mine = Util.GetGameObject(this.minepart, "zhenxing")
    this.leftInvestigate = Util.GetGameObject(this.minepart,"InvestigateCenter")

    this.enemypart = Util.GetGameObject(self.gameObject, "DownRoot/option/right")
    this.headpart_enemy = Util.GetGameObject(this.enemypart, "headpart")
    this.name_enemy = Util.GetGameObject(this.enemypart, "enemyName")
    this.zhenBuff_enemy = Util.GetGameObject(this.enemypart, "zhenBuff")
    this.zhenxing_enemy = Util.GetGameObject(this.enemypart, "zhenxing")
    this.rightInvestigate = Util.GetGameObject(this.enemypart,"InvestigateCenter")
    
    this.FirstEffect = Util.GetGameObject(this.gameObject, "Start")
    this.ThirdEffect = Util.GetGameObject(this.gameObject, "Third")
    this.skillEffectRoot = Util.GetGameObject(this.gameObject, "skillEffectRoot")

    this.Cache = Util.GetGameObject(this.gameObject, "cache")

    this.enemySkillCast = Util.GetGameObject(this.transform, "EnemySkillCast")
    this.enemySkillCastRoot = Util.GetGameObject(this.transform, "EnemySkillCast/TongYong_Casting_Shang/DongHua/RENWU")
    this.mySkillCast = Util.GetGameObject(this.transform, "mySkillCast")
    this.mySkillCastRoot = Util.GetGameObject(this.transform, "mySkillCast/TongYong_Casting_Xia/DongHua/RENWU")

    this.CloseUpNode = Util.GetGameObject(this.transform, "CloseUpNode")

    this.TotalDmg = Util.GetGameObject(this.gameObject, "TotalDmg")

    this.HelpHeroShow = Util.GetGameObject(this.transform, "HelpHeroShow")
    Game.GlobalEvent:AddEvent(BattleEventName.BattleEndClearSceneRoles, this.ClearSceneRoles)
end

function this:BindEvent()
end

-- 正常接口
function this:OnOpen(data)
    BattleManager.BattleIsStart = true
    BattleManager.BattleIsEnd = false

    this.mine:SetActive(false)
    this.enemy:SetActive(false)

    this:Init()

    this:SetData(data.fightData, data.fightSeed, data.fightType, data.maxRound, data)

    Util.GetGameObject(this.TotalDmg, "FloatingTotalText"):SetActive(false)

    this.IsJumpGameEnd = false

    this.SetAgainstInfoUI()

    -- IsEndBattle=false

end

function this:OnOpenCustom()
    BattleManager.InitTimeScale()
    this.ClearSkillRootEffect()

    for _, unit in pairs(unitView) do
        unit:ResetAnim()
    end

    this.SetUnitPos()

    SoundManager.PlayMusic(SoundConfig.BGM_Battle_1, true, function()
        SoundManager.PlayMusic(SoundConfig.BGM_Battle_2, false)
    end)
end

function this:OnSortingOrderChange(battleSorting)
    -- 层级
    this.FirstEffect:GetComponent("Canvas").sortingOrder = battleSorting + 30
    this.skillEffectRoot:GetComponent("Canvas").sortingOrder = battleSorting + 40
    -- this.subPanel:GetComponent("Canvas").sortingOrder = battleSorting + 50
    
    local skillSorting = battleSorting + 200
    this.mySkillCast:GetComponent("Canvas").sortingOrder = skillSorting
    this.enemySkillCast:GetComponent("Canvas").sortingOrder = skillSorting

    this.CloseUpNode:GetComponent("Canvas").sortingOrder = battleSorting

    for _, v in pairs(tbRole) do
        v:OnSortingOrderChange(battleSorting)
    end
    for _, v in pairs(tbRoleDispose) do
        v:OnSortingOrderChange(battleSorting)
    end

    this.ResetRoleOrder()
end

-- 初始化界面
function this:Init()
    -- 初始化战斗对象池
    BattlePool.Init(this.Cache)
    BattlePool.Register(BATTLE_POOL_TYPE.ENEMY_ROLE_2, this.EnemyItem)
    BattlePool.Register(BATTLE_POOL_TYPE.BUFF_VIEW, this.BuffItem)
    BattlePool.Register(BATTLE_POOL_TYPE.UNIT_VIEW, this.UnitPre)

    -- 层级
    local battleSorting = BattleManager.GetBattleSorting()
    this.FirstEffect:GetComponent("Canvas").sortingOrder = battleSorting + 30
    this.skillEffectRoot:GetComponent("Canvas").sortingOrder = battleSorting + 40
    this.mySkillCast:GetComponent("Canvas").sortingOrder = battleSorting + 200
    this.enemySkillCast:GetComponent("Canvas").sortingOrder = battleSorting + 200
    this.CloseUpNode:GetComponent("Canvas").sortingOrder = battleSorting + 40

    -- 异妖显示
    this.DiffMonster:SetActive(false)
    this.DiffMonsterFlag = false
    this.EnemyDiffMonster:SetActive(false)
    this.EnemyDiffMonsterFlag = false

    -- 层级
    this.casterSortingOrder = 0 --释放技能时释放方层级
    this.targetSortingOrder = 0 --释放技能时接受方层级
    this.orderSequence = {1, 2, 3, 4, 5, 6, 7, 8, 9}
    for i = 1, #this.orderSequence do
        this.orderSequence[i] = this.orderSequence[i] * 3
        if this.casterSortingOrder < this.orderSequence[i] then
            this.casterSortingOrder = this.orderSequence[i];
        end
    end
    this.targetSortingOrder = this.casterSortingOrder + 5
    this.casterSortingOrder = this.casterSortingOrder + 10

    UIManager.camera.clearFlags = CameraClearFlags.Depth

    this.InitBattleEvent()

    if not IsLoadFightLocalPt then
        for i = 1, 9 do
            local liveMine = Util.GetGameObject(this.Left, "live_" .. tostring(i))
            local liveEnemy = Util.GetGameObject(this.Right, "live_" .. tostring(i))
            local liveMineTarget = Util.GetGameObject(this.Left, "live_" .. tostring(i) .. "_pos")
            local liveEnemyTarget = Util.GetGameObject(this.Right, "live_" .. tostring(i) .. "_pos")
            table.insert(FightCampLocalPosition[0], liveMine.transform.localPosition)
            table.insert(FightCampLocalPosition[1], liveEnemy.transform.localPosition)
            table.insert(FightCampTargetLocalPosition[0], liveMineTarget.transform.localPosition)
            table.insert(FightCampTargetLocalPosition[1], liveEnemyTarget.transform.localPosition)
            
            table.insert(FightCampLPToSkillRoot[0], liveMine.transform.localPosition)
            table.insert(FightCampLPToSkillRoot[1], liveEnemy.transform.localPosition)
        end


        local liveMine = Util.GetGameObject(this.Left, "live_" .. tostring(99))
        local liveEnemy = Util.GetGameObject(this.Right, "live_" .. tostring(99))
        local liveMineTarget = Util.GetGameObject(this.Left, "live_" .. tostring(99) .. "_pos")
        local liveEnemyTarget = Util.GetGameObject(this.Right, "live_" .. tostring(99) .. "_pos")
        table.insert(FightCampLocalPosition[0], liveMine.transform.localPosition)
        table.insert(FightCampLocalPosition[1], liveEnemy.transform.localPosition)
        table.insert(FightCampTargetLocalPosition[0], liveMineTarget.transform.localPosition)
        table.insert(FightCampTargetLocalPosition[1], liveEnemyTarget.transform.localPosition)

        table.insert(FightCampLPToSkillRoot[0], liveMine.transform.localPosition)
        table.insert(FightCampLPToSkillRoot[1], liveEnemy.transform.localPosition)

        IsLoadFightLocalPt = true
    else
        for i = 1, 9 do
            local liveMine = Util.GetGameObject(this.Left, "live_" .. tostring(i))
            local liveEnemy = Util.GetGameObject(this.Right, "live_" .. tostring(i))
            local liveMineTarget = Util.GetGameObject(this.Left, "live_" .. tostring(i) .. "_pos")
            local liveEnemyTarget = Util.GetGameObject(this.Right, "live_" .. tostring(i) .. "_pos")
            liveMine.transform.localPosition = FightCampLocalPosition[0][i]
            liveEnemy.transform.localPosition = FightCampLocalPosition[1][i]
            liveMineTarget.transform.localPosition = FightCampTargetLocalPosition[0][i]
            liveEnemyTarget.transform.localPosition = FightCampTargetLocalPosition[1][i]
        end

        local liveMine = Util.GetGameObject(this.Left, "live_" .. tostring(99))
        local liveEnemy = Util.GetGameObject(this.Right, "live_" .. tostring(99))
        local liveMineTarget = Util.GetGameObject(this.Left, "live_" .. tostring(99) .. "_pos")
        local liveEnemyTarget = Util.GetGameObject(this.Right, "live_" .. tostring(99) .. "_pos")
        liveMine.transform.localPosition = FightCampLocalPosition[0][10]
        liveEnemy.transform.localPosition = FightCampLocalPosition[1][10]
        liveMineTarget.transform.localPosition = FightCampTargetLocalPosition[0][10]
        liveEnemyTarget.transform.localPosition = FightCampTargetLocalPosition[1][10]
    end

    this.ResetRoleOrder()
end

-- 设置数据数据
function this:SetData(_fightData, _seed, _battleType, _maxRound)
    -- body
    this.fightData = _fightData
    this.seed = _seed
    this.battleType = _battleType or 0
    this.maxRound = _maxRound
    --
    if not this.seed then
        this.seed = math.random(0, 2147483647)
    end

    if IsOpenBattleDebug then
        LastDebugTime = Time.realtimeSinceStartup
    end

    -- 设置角色展示界面数据
    -- RoleShowView.SetData(_fightData)

    -- 加入战斗记录
    local record = {
        fightData = this.fightData,
        fightSeed = this.seed,
        fightType = this.battleType,
        maxRound = this.maxRound
    }
    this.recordId = BattleRecordManager.SetBattleRecord(record)
    BattleRecordManager.SetBattleBothNameStr(this.nameStr, this.recordId)
end

-- 设置攻击双方的名称
function this:SetNameStr(_nameStr)
    this.nameStr = _nameStr
end

-- 开始战斗
function this:StartBattle()
    this.InitBattleData()
    -- 初始化战斗数据
    FixedUpdateBeat:Add(this.OnUpdate, self)
    -- 预加载资源
    -- poolManager:PreLoadAsset("FloatingText",10, PoolManager.AssetType.GameObject, function()
    --     poolManager:PreLoadAsset("BuffFloatingText",10, PoolManager.AssetType.GameObject, function()
    --         this.BattleOrderChange(1)
    --     end)
    -- end)
    
    this.BattleOrderChange(1)
    this.UpdateCVSkillUI()
end

-- 暂停战斗
function this:PauseBattle()
    BattleManager.PauseBattle()
end
-- 继续战斗
function this:ResumeBattle()
    BattleManager.ResumeBattle()
end
-- 停止战斗
function this:StopBattle()
    BattleManager.StopBattle()
end

function this.EndBattleDelay(result)
    --隐藏血条
    this.EnemyPanel:SetActive(false)
    this.MinePanel:SetActive(false)

    local time = 2
    if this.IsJumpGameEnd then
        time = 0
    end
    Timer.New(function ()
        this.EndBattle(result)
    end, time):Start()
end

-- 结束战斗
function this.EndBattle(result)
    if BattleManager.BattleIsEnd then
        return
    end

    -- 清空数据
    BattleView.CatheStat()
    -- 判断结果
    local record = {
        fightData = this.fightData,
        fightSeed = this.seed,
        fightType = this.battleType,
        maxRound = this.maxRound
    }

    result = result 
    or BattleRecordManager.GetBattleRecordResult(this.recordId)  
    iHaveSupport = false
    iHaveAdjutant = false
    enemyHaveSupport = false
    enemyHaveAdjutant = false
    iHaveAircraft = false
    enemyHaveAircraft = false
    -- 战斗结束
    this.root.BattleEnd(result)

    BattleManager.BattleIsStart = false
    BattleManager.BattleIsEnd = true

    Game.GlobalEvent:DispatchEvent(GameEvent.Battle.OnBattleUIEnd)
    -- this:ClearRole()
    Log("BattleView.EndBattle:"..tostring(this.gameObject.activeInHierarchy))
    if this.gameObject.activeInHierarchy then
        IsEndBattle=true
    else
        Game.GlobalEvent:DispatchEvent(BattleEventName.BattleEndClearSceneRoles)
    end
end

function BattleView.Clear()
    --> 防止使用tbRole 报错 清理前 dispose
    this:ClearRole()
    BattleView.CatheStat()
end

function BattleView.CatheStat()

    tbRoleDispose = {} --战斗统计前将roleView收集到该容器中，tbRole清理掉
    for _, v in pairs(tbRole) do
        table.insert(tbRoleDispose, v)
    end
    tbRole = {}
end

-- 初始化战斗数据
function this.InitBattleData()
    Random.SetSeed(this.seed)
    --BattleLogic.IsOpenBattleRecord = true
    BattleLogic.Init(this.fightData, nil, this.maxRound)
    BattleLogic.Type = this.battleType
    this.InitBattleEvent()
end

function this.OnAddTiRole(state)
end

function this.OnEndTibu(state)
end

local function xRollBack()
    local _round = 0
    _round = BattleLogic.GetCurRound()
    if _round == nil then _round = -1 end
    BattleRecordManager.RollBackRound(_round,RecordType.RoleManager)
end

local function xMovewRollBack()
    local _move = 0
    _move = BattleLogic.GetMoveTimes()
    if _move == nil then _move = -1 end
    BattleRecordManager.RollBackRound(_move,RecordType.RoleManager)
end

-- 注册战斗事件
function this.InitBattleEvent()
    -- 战斗状态同步
    -- 注册战斗监听回滚 同步battlemanager 监听位置
    -- BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, xRollBack)
    BattleLogic.Event:AddEvent(BattleEventName.CheckFrame, xMovewRollBack)

    BattleLogic.Event:AddEvent(BattleEventName.AddRole, this.OnAddRole)
    BattleLogic.Event:AddEvent(BattleEventName.RemoveRole, this.OnRemoveRole)
    BattleLogic.Event:AddEvent(BattleEventName.BattleEnd, this.EndBattleDelay)
    BattleLogic.Event:AddEvent(BattleEventName.BattleOrderChange, this.BattleOrderChange)
    BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, this.BattleRoundChange)
    BattleLogic.Event:AddEvent(BattleEventName.BattleRoundChange, this.UpdateCVSkillUI)
    BattleLogic.Event:AddEvent(BattleEventName.BattleTibuRoundBegin, this.OnAddTiRole)
    BattleLogic.Event:AddEvent(BattleEventName.BattleTibuRoundEnd, this.OnEndTibu)

    BattleLogic.Event:AddEvent(BattleEventName.FloatTotal, this.FloatTotal)

    BattleLogic.Event:AddEvent(BattleEventName.AddUnit, this.OnAddUnit)
    BattleLogic.Event:AddEvent(BattleEventName.RemoveUnit, this.OnRemoveUnit)
    BattleLogic.Event:AddEvent(BattleEventName.BattleRoundBeginDialogue, this.RoundBeginDialogue)
    BattleLogic.Event:AddEvent(BattleEventName.RoleTurnStart, this.RoleTurnChange)


end
-- 清除战斗数据
function this.ClearBattleEvent()
    -- BattleLogic.Event:RemoveEvent(BattleEventName.CheckFrame, xMovewRollBack)

    BattleLogic.Event:RemoveEvent(BattleEventName.AddRole, this.OnAddRole)
    BattleLogic.Event:RemoveEvent(BattleEventName.RemoveRole, this.OnRemoveRole)
    BattleLogic.Event:RemoveEvent(BattleEventName.BattleEnd, this.EndBattleDelay)
    BattleLogic.Event:RemoveEvent(BattleEventName.BattleOrderChange, this.BattleOrderChange)
    BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundChange, this.BattleRoundChange)
    BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundChange, this.UpdateCVSkillUI)    
    BattleLogic.Event:RemoveEvent(BattleEventName.BattleTibuRoundBegin, this.OnAddTiRole)
    BattleLogic.Event:RemoveEvent(BattleEventName.BattleTibuRoundEnd, this.OnEndTibu)
    BattleLogic.Event:RemoveEvent(BattleEventName.FloatTotal, this.FloatTotal)
    -- BattleLogic.Event:RemoveEvent(BattleEventName.BattleEndClearSceneRoles, this.ClearSceneRoles)

    BattleLogic.Event:RemoveEvent(BattleEventName.AddUnit, this.OnAddUnit)
    BattleLogic.Event:RemoveEvent(BattleEventName.RemoveUnit, this.OnRemoveUnit)
    BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundBeginDialogue, this.RoundBeginDialogue)
    BattleLogic.Event:RemoveEvent(BattleEventName.RoleTurnStart, this.RoleTurnChange)

    
    -- 战斗状态同步
    -- 注销战斗监听回滚 同步battlemanager 监听位置
    -- BattleLogic.Event:RemoveEvent(BattleEventName.BattleRoundChange, xRollBack)
    BattleLogic.Event:RemoveEvent(BattleEventName.RoleTurnStart, xMovewRollBack)
end
function this.ClearSceneRoles()
    Log("ClearSceneRoles")

    this:ClearRole()
    this.BattleEndClear()
end
function this.RoundBeginDialogue(dialogueId)
    if BattleManager.IsInBackBattle() then
        if not UIManager.IsOpen(UIName.BattlePanel) then
            return
        end
    end

    BattleManager.PauseBattle()
    StoryManager.EventTrigger(dialogueId, function()
        BattleManager.ResumeBattle()
    end)
end

--敌军出现的表现
function this.EnemyAppear()
    SoundManager.PlaySound(SoundConfig.Sound_BattleStart_03)
    local go
    if BattleLogic.CurOrder == 1 then
        go = this.FirstEffect
    elseif BattleLogic.CurOrder == 2 then
        go = this.FirstEffect
    elseif BattleLogic.CurOrder == 3 then
        go = this.ThirdEffect
    end
    go:SetActive(false)
    --TODO:动态计算敌军站位
    for i = 1, 9 do
        local index = i
        local enemyLivePos = Util.GetTransform(this.Right, "live_"..i)
        local enemyPos = Util.GetTransform(this.EnemyPanel, tostring(i))

        local scale = 1--(1 - math.abs(i-pos[1]+posOffset) * 0.15) --敌人依次缩放出现
        -- enemyLivePos:DOScale(Vector3.one, 0.5):SetEase(Ease.OutExpo)
        enemyPos:DOScale(Vector3.one, 0.1):SetEase(Ease.OutExpo):OnComplete(function ()
            -- enemyLivePos:DOScale(Vector3.one, 0.2):SetEase(Ease.InExpo)
            -- enemyPos:DOScale(Vector3.one, 0.2):SetEase(Ease.InExpo):OnComplete(function ()

                if index == 4 then
                    -- 提前播放音效
                    -- if BattleLogic.CurOrder == 1 then
                    --     SoundManager.PlaySound(SoundConfig.Sound_BattleStart_04)
                    -- end

                elseif index == 9 then
                    --显示血条
                    for r, v in pairs(tbRole) do
                        if r.camp == 0 then
                            playerTmpHp = playerTmpHp + r:GetRoleData(RoleDataName.Hp)
                        else
                            enemyTmpHp = enemyTmpHp + r:GetRoleData(RoleDataName.Hp)
                        end
                        v:OrderStart()
                    end
                    Timer.New(function ()
                        go:SetActive(false)
                        playerHP = 0
                        this.PlayerHPTxt.text = GetLanguageStrById(10269)..math.floor(playerHP / playerMaxHP * 100).."%"

                        enemyHP = 0
                        this.EnemyHPTxt.text = GetLanguageStrById(10270)..math.floor(enemyHP / enemyMaxHP  * 100).."%"

                        Timer.New(function ()
                            if BattleLogic.CurOrder == 1 then
                                BattleManager.StartBattle()
                                this.OnOpenInvestigateBuff()
                            else
                                BattleManager.ResumeBattle()
                            end
                        end, 0.1):Start()

                        if BattleLogic.CurOrder == 1 then
                            Game.GlobalEvent:DispatchEvent(GameEvent.Guide.GuideBattleStart)
                        end
                    end, 0.8):Start()
                end
            --end)
        end):SetDelay(0.2):OnStart(function ()
            -- if enemyLivePos.childCount > 0 and RoleManager.GetRole(1, i) then
                ----出生特效,不需要了
                -- local go2 = loadAsset("fx_Effect_enemy_birth")
                -- go2.transform:SetParent(enemyLivePos)
                -- go2.transform.localScale = Vector3.one
                -- go2.transform.position = enemyLivePos.position
                -- go2:SetActive(true)

                -- addDelayRecycleRes("fx_Effect_enemy_birth", go2, 2)
            -- end
        end)
    end
end

-- 角色轮转回调(不出手的位置不会回调)
function this.RoleTurnChange(role)
    -- 回调UI层
    if this.root.RoleTurnChange then
        this.root.RoleTurnChange(role)
    end
end

local round
-- 回合变化
function this.BattleRoundChange(Round)
    -- 回调UI层
    this.root.OnRoundChanged(Round)
    this:SetUnitProgress(1, Round)
    this:SetUnitProgress(2, Round)
    round = Round
    -- 异妖CD
    if this.DiffMonsterFlag then
        local slider = BattleLogic.GetTeamSkillCastSlider(0)
        this.DiffMonsterSlider.fillAmount = slider
    end
    if this.EnemyDiffMonsterFlag then
        local slider = BattleLogic.GetTeamSkillCastSlider(1)
        this.EnemyDiffMonsterSlider.fillAmount = slider
    end
end
-- 战斗波次变化
function this.BattleOrderChange(order)
    -- 回调UI层
    this.root.OnOrderChanged(order)

    -- this.ElementalResonanceView.elementalResonanceBtn:SetActive(true)
    -- this.ElementalResonanceView2.elementalResonanceBtn:SetActive(true)

    -- local curFormation = FormationManager.GetFormationByID(FormationManager.currentFormationIndex)
    -- this.ElementalResonanceView:GetElementalType(curFormation.teamHeroInfos,1)
    -- this.ElementalResonanceView:SetPosition(5)
    -- if this.fightData.enemyData[order] then
    --     this.ElementalResonanceView2:GetElementalType(this.fightData.enemyData[order], 2, order)
    --     this.ElementalResonanceView2:SetPosition(5)
    -- end

    if this.tween1 then
        this.tween1:Kill()
    end
    if this.tween2 then
        this.tween2:Kill()
    end

    enemyMaxHP = 0
    enemyHP = 0
    playerTmpHp = 0
    enemyTmpHp = 0

    this.PlayerHPTxt.text = ""
    this.EnemyHPTxt.text = ""
    this.EnemyHP.fillAmount = 0
    this.PlayerHP.fillAmount = 0

    BattleManager.PauseBattle()

    if order > 1 then
        -- PlayUIAnimBack(this.gameObject,function ()
        --     for _,v in pairs(tbRole) do
        --         v.hpSlider.fillAmount = 0
        --         v.hpPassSlider.fillAmount = 0
        --         v.hpCache = 0
        --         if v.spSlider then
        --             v.spSlider.fillAmount = 0
        --         end
        --     end

        --     PlayUIAnim(this.gameObject)--, this.EnemyAppear)
        --     this.EnemyAppear()
        -- end)
    else
        this.UpRoot:SetActive(false)
        this.DownRoot:SetActive(false)

        this.UpRoot:SetActive(true)
        this.DownRoot:SetActive(true)
        -- PlayUIAnim(this.gameObject, function()
        -- end)

        playerMaxHP = 0

        BattleLogic.StartOrder()
        this.EnemyAppear()

        for key, value in pairs(tbRole) do
            if value.role.roleData.roleId ~= 1 and value.role.roleData.roleId ~= 2 then -- 男女主没有此动作
                value:PlaySpineAnim(value.RoleLiveGOGraphic, 0, RoleAnimationName.Run, true)
            else
                value:PlaySpineAnim(value.RoleLiveGOGraphic, 0, RoleAnimationName.Stand, true)
            end
        end

        --隐藏血条,然后移动英雄
        this.EnemyPanel:SetActive(false)
        PlayUIAnim(this.Right, function()
            this.EnemyPanel:SetActive(true)
            for key, value in pairs(tbRole) do
                if key.camp == 1 then
                    value:PlaySpineAnim(value.RoleLiveGOGraphic, 0, RoleAnimationName.Stand, true)
                    value.RoleLiveGO:SetActive(true)
                end
            end
        end)

        this.MinePanel:SetActive(false)
        PlayUIAnim(this.Left, function()
            this.MinePanel:SetActive(true)
            for key, value in pairs(tbRole) do
                if key.camp == 0 then
                    value:PlaySpineAnim(value.RoleLiveGOGraphic, 0, RoleAnimationName.Stand, true)
                    value.RoleLiveGO:SetActive(true)
                end
            end
        end)

        -- PlayUIAnim(this.MinePanel, function()
        --     for _,v in pairs(tbRole) do
        --         v.smoke:SetActive(false)
        --     end
        -- end)

        -- for _,v in pairs(tbRole) do
        --     v.smoke:SetActive(true)
        --     Util.SetParticleSortLayer(v.RoleLiveGO, this.root.sortingOrder + 1)
        -- end
    -- end)
    end

    --刷新敌军站位
    local v3 = this.EnemyPanel:GetComponent("RectTransform").anchoredPosition
    this.EnemyPanel.transform.localScale = Vector3.one

    for i = 1, 9 do
        local enemyPos = Util.GetTransform(this.EnemyPanel, tostring(i))
        local enemyLivePos = Util.GetTransform(this.Right, "live_" .. i)
        enemyPos.localScale = Vector3.one
        enemyLivePos.localScale = Vector3.one
    end

    local enemyPos = Util.GetTransform(this.EnemyPanel, tostring(99))
    local enemyLivePos = Util.GetTransform(this.Right, "live_" .. 99)
    enemyPos.localScale = Vector3.one
    enemyLivePos.localScale = Vector3.one

    this.MinePanel.transform.localScale = Vector3.one
    this.ResetRoleOrder()
end

-- to do add yh show 增加替补上阵界面
function this.OnAddTibuRoleShow(data)
    -- 英雄出场表现
    BattleManager.PauseBattle()
    local _camp = -2
    if data.camp == 1 then _camp = 2 end
    tbRole[data].RoleLiveGO.transform.localPosition = Vector2.New(_camp, 0)
    tbRole[data]:PlaySpineAnim(tbRole[data].RoleLiveGOGraphic, 0, RoleAnimationName.Run, true)
    tbRole[data].RoleLiveGO.transform:DOLocalMove(Vector2.zero,0.6):OnComplete(function()   
    -- tbRole[data]:PlaySpineAnim(tbRole[data].RoleLiveGOGraphic, 0, RoleAnimationName.Stand, true)
    tbRole[data]:PlaySpineAnim(tbRole[data].RoleLiveGOGraphic, 0, RoleAnimationName.Stand, true)
    this.EnemyPanel:SetActive(false)
    this.MinePanel:SetActive(false)
    Timer.New(function ()
        this.EnemyPanel:SetActive(true)
        this.MinePanel:SetActive(true)
        -- 动画展现替补               
        -- BattleLogic.Event:DispatchEvent(BattleEventName.BattleRoundBeginDialogue, data.roleData.client_dialogue)
        BattleManager.ResumeBattle()
    end, 2):Start()     
    end)
end

function this.OnAddRole(data, isHelp,isTibu,isShowMan)    
    --战斗单位血条
    local go
    if data.camp == 0 then
        local parent = Util.GetTransform(this.MinePanel, tostring(data.position))
        go = BattlePool.GetItem(parent, BATTLE_POOL_TYPE.ENEMY_ROLE_2)
        playerHP = playerHP + data:GetRoleData(RoleDataName.Hp)
        playerMaxHP = playerMaxHP + data:GetRoleData(RoleDataName.MaxHp)
    else
        --LogError("tostring(data.position) "..tostring(data.position))
        local enemyPos = Util.GetTransform(this.EnemyPanel, tostring(data.position))
        go = BattlePool.GetItem(enemyPos, BATTLE_POOL_TYPE.ENEMY_ROLE_2)
        enemyHP = enemyHP + data:GetRoleData(RoleDataName.Hp)
        enemyMaxHP = enemyMaxHP + data:GetRoleData(RoleDataName.MaxHp)
    end
    go:SetActive(true)
    --主角icon更新
    if data.camp == 0 and isShowMan then
        iHaveAircraft = true
    elseif data.camp == 1 and isShowMan then
        enemyHaveAircraft = true
    end
    if isShowMan then 
        go:SetActive(false)
        -- LogError("setCarrierPos")
        this.SetAirCarrierPos()
    end

    --英雄所在位置
    local spineLivePos = Util.GetGameObject(data.camp == 0 and this.Left or this.Right, "live_" .. data.position)
    tbRole[data] = RoleView.New(go, data, data.position, this, spineLivePos)

    if isTibu then
        this.OnAddTibuRoleShow(data)
        return
    end

    if isHelp then
        BattleManager.PauseBattle()
        tbRole[data].RoleLiveGO.transform.localPosition = Vector2.New(-2, 0)
        tbRole[data]:PlaySpineAnim(tbRole[data].RoleLiveGOGraphic, 0, RoleAnimationName.Run, true)
        tbRole[data].RoleLiveGO.transform:DOLocalMove(Vector2.zero,0.6):OnComplete(function()        
            tbRole[data]:PlaySpineAnim(tbRole[data].RoleLiveGOGraphic, 0, RoleAnimationName.Stand, true)
            this.EnemyPanel:SetActive(false)
            this.MinePanel:SetActive(false)
            this.SetHelpHero()
            this.HelpHeroShow:SetActive(true)
            Timer.New(function ()
                this.HelpHeroShow:SetActive(false)
                if this.helpHeroLive then
                    UnLoadHerolive(this.helpHeroConfig, this.helpHeroLive)
                    Util.ClearChild(this.helpLivePos.transform)
                end
                this.EnemyPanel:SetActive(true)
                this.MinePanel:SetActive(true)
                BattleLogic.Event:DispatchEvent(BattleEventName.BattleRoundBeginDialogue, data.roleData.client_dialogue)
            end, 3.5):Start()
        end)
    end
end

function this.OnRemoveRole(data)
    local view = tbRole[data]
    if view then
        view:Dispose()
        tbRole[data] = nil
    end
end

--设置助战英雄信息
function this.SetHelpHero()
    local eventId = G_MainLevelConfig[FightPointPassManager.curOpenFight].BattleEvent[1]
    local event = G_BattleEventConfig[eventId].Event
    if event[1] == 4 then
        local heroId = G_MonsterConfig[event[2]].MonsterId
        this.helpHeroConfig = G_HeroConfig[heroId]
        Util.GetGameObject(this.HelpHeroShow, "name"):GetComponent("Text").text = GetLanguageStrById(this.helpHeroConfig.ReadingName)
        Util.GetGameObject(this.HelpHeroShow, "location"):GetComponent("Text").text = GetLanguageStrById(this.helpHeroConfig.HeroLocation)
        this.helpLivePos = Util.GetGameObject(this.HelpHeroShow, "live")
        if this.helpHeroLive then
            UnLoadHerolive(this.helpHeroConfig, this.helpHeroLive)
            Util.ClearChild(this.helpLivePos.transform)
        end
        this.helpHeroLive = LoadHerolive(this.helpHeroConfig, this.helpLivePos.transform)
    end
end

--设置主角技能 --this.icon.sprite = Util.LoadSprite(GetResourcePath(this.skillData.skillConfig.Icon))
function this.SetLeaderSkill()

end

--设置主角位置  需要在守护确定之后更新位置
function this.SetAirCarrierPos()
    --我方主角技能栏
    if iHaveAircraft then
        this.mineLeaderSkill:SetActive(true)
        if (iHaveSupport or iHaveAdjutant) then
            this.mineLeaderSkill.transform.anchoredPosition3D = Vector3.New(0,-166,0) 
        else            
            this.mineLeaderSkill.transform.anchoredPosition3D = Vector3.New(0,-55,0)
        end
    end
    --敌方主角技能栏
    if enemyHaveAircraft then
        this.enemyLeaderSkill:SetActive(true)
        if enemyHaveSupport or enemyHaveAdjutant then
            this.enemyLeaderSkill.transform.anchoredPosition3D = Vector3.New(0,-166,0)
        else
            this.enemyLeaderSkill.transform.anchoredPosition3D = Vector3.New(0,-55,0)
        end
    end
end

-- 设置支援位置
function this.SetUnitPos()
    this.OuterUnit_0_first.transform.localPosition = this.OuterUnit_0_firstPos
    this.OuterUnit_0_second.transform.localPosition = this.OuterUnit_0_secondPos
    this.OuterUnit_1_first.transform.localPosition = this.OuterUnit_1_firstPos
    this.OuterUnit_1_second.transform.localPosition = this.OuterUnit_1_secondPos

    this.OuterUnit_0_first.transform.localScale = Vector3.one
    this.OuterUnit_0_second.transform.localScale = Vector3.one
    this.OuterUnit_1_first.transform.localScale = Vector3.one
    this.OuterUnit_1_second.transform.localScale = Vector3.one

    this.OuterUnit_0_first.transform.localRotation = Vector3.zero
    this.OuterUnit_0_second.transform.localRotation = Vector3.zero
    this.OuterUnit_1_first.transform.localRotation = Vector3.zero
    this.OuterUnit_1_second.transform.localRotation = Vector3.zero

    this.mine:SetActive(false)
    this.enemy:SetActive(false)
    if iHaveSupport and iHaveAdjutant then
        this.mine:SetActive(true)
        this.mine.transform.anchoredPosition3D = Vector3.New(0,-112,0)
    elseif iHaveSupport or iHaveAdjutant then
        this.mine:SetActive(true)
        this.mine.transform.anchoredPosition3D = Vector3.New(-205,-112,0)
    end
    if enemyHaveSupport and enemyHaveAdjutant then
        this.enemy:SetActive(true)
        this.enemy.transform.anchoredPosition3D = Vector3.New(0,-112,0)
    elseif enemyHaveSupport or enemyHaveAdjutant then
        this.enemy:SetActive(true)
        this.enemy.transform.anchoredPosition3D = Vector3.New(205,-112,0)
    end    
end

--设置支援释放技能进度
function this:SetUnitProgress(type, Round, isAdjutant)
    local supportGrid
    local adjutantGrid
    if type == 1 then
        supportGrid = this.mySupportGrid
        adjutantGrid = this.myAdjutantGrid
    elseif type == 2 then
        supportGrid = this.enemySupportGrid
        adjutantGrid = this.enemyAdjutantGrid
    end

    if supportGrid and not isAdjutant then
        local fire = Util.GetGameObject(supportGrid.parent.gameObject,"Fire")
        local num = Round % 3
        if num == 0 then num = 3 end
        if num == 3 then
            fire:SetActive(true)
            fire.transform:SetSiblingIndex(6)
        else
            fire:SetActive(false)
        end
        for i = 1, 3 do
            local effect = supportGrid:GetChild(i-1):GetChild(0).gameObject
            if i <= num then
                if not effect.activeSelf then
                    effect:SetActive(true)
                end
            else
                if effect.activeSelf then
                    effect:SetActive(false)
                end
            end
        end
    end
    if adjutantGrid then
        local fire = Util.GetGameObject(adjutantGrid.parent.gameObject,"Fire")
        if Round == 1 then
            fire:SetActive(true)
            fire.transform:SetSiblingIndex(6)
            for i = 1, 4 do
                local effect = adjutantGrid:GetChild(i-1):GetChild(0).gameObject
                if not effect.activeSelf then
                    effect:SetActive(true)
                end
            end
        else
            local num = (Round - 1) % 4
            if num == 0 then num = 4 end
            if num == 4 then
                fire:SetActive(true)
            else
                fire:SetActive(false)
            end
            for i = 1, 4 do
                local effect = adjutantGrid:GetChild(i-1):GetChild(0).gameObject
                if i <= num then
                    if not effect.activeSelf then
                        effect:SetActive(true)
                    end
                else
                    if effect.activeSelf then
                        effect:SetActive(false)
                    end
                end
            end
        end
    end
end
--设置支援释放技能
function this:SetUnitReleaseSkill(obj)
    local grid = Util.GetGameObject(obj.transform.parent, "grid").transform
    Util.GetGameObject(grid.parent.gameObject, "Fire"):SetActive(false)
    for i = 1, 4 do
        local effect = grid:GetChild(i-1):GetChild(0).gameObject
        if effect.activeSelf then
            effect:SetActive(false)
        end
    end

    local type
    local name = grid.parent.parent.gameObject.name
    if name == "mine" then
        type = 1
    elseif name == "enemy" then
        type = 2
    end
    --这里是由于先驱动画结束后加了回合而导致的显示不正确
    this:SetUnitProgress(type, round, true)
end

--添加支援
function this.OnAddUnit(unit)
    iHaveSupport = false
    iHaveAdjutant = false
    enemyHaveSupport = false
    enemyHaveAdjutant = false
    iHaveAircraft = false
    enemyHaveAircraft = false

    --> 不同类型区分
    if this.fightData.fightUnitData ~= nil then
        for index, value in ipairs(this.fightData.fightUnitData) do
            if value.type == FightUnitType.UnitSupport then
                if value.camp == 0 then
                    --己方有守护
                    iHaveSupport = true
                elseif value.camp == 1 then
                    --敌方有守护
                    enemyHaveSupport = true
                end
            elseif value.type == FightUnitType.UnitAdjutant then
                if value.camp == 0 then
                    iHaveAdjutant = true
                elseif value.camp == 1 then
                    enemyHaveAdjutant = true
                end
            end
        end
    end
    
    this.SetUnitPos()
    this.SetAirCarrierPos()

    local setGrid = function(item,value)
        for i = 1 ,item.childCount do
            if i <= value  then
                item:GetChild(i-1).gameObject:SetActive(true)
            else
                item:GetChild(i-1).gameObject:SetActive(false)
            end
        end
    end

    local go = nil
    if unit.type == FightUnitType.UnitSupport then
        go = BattlePool.GetItem(this["OuterUnit_" .. unit.camp .. "_first"], BATTLE_POOL_TYPE.UNIT_VIEW)
        go.transform:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_zhandou_shouhudi")
        go.transform:GetComponent("Image"):SetNativeSize()
        if unit.camp == 0 then
            this.mySupportGrid = Util.GetGameObject(this["OuterUnit_" .. unit.camp .."_first"],"grid").transform
            setGrid(this.mySupportGrid,3)
        elseif unit.camp == 1 then
            this.enemySupportGrid = Util.GetGameObject(this["OuterUnit_" .. unit.camp .."_first"],"grid").transform
            setGrid(this.enemySupportGrid,3)
        end
    elseif unit.type == FightUnitType.UnitAircraftCarrier then
        -- todo add unit
    elseif unit.type == FightUnitType.UnitAdjutant then
        if unit.camp == 0 then
            if iHaveSupport then
                go = BattlePool.GetItem(this["OuterUnit_" .. unit.camp .."_second"], BATTLE_POOL_TYPE.UNIT_VIEW)
                this.myAdjutantGrid = Util.GetGameObject(this["OuterUnit_" .. unit.camp .."_second"],"grid").transform
                setGrid(this.myAdjutantGrid,4)
                go.transform:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_zhandou_xianqudi")
                go.transform:GetComponent("Image"):SetNativeSize()
            elseif not iHaveSupport then
                go = BattlePool.GetItem(this["OuterUnit_" .. unit.camp .."_first"], BATTLE_POOL_TYPE.UNIT_VIEW)
                this.myAdjutantGrid = Util.GetGameObject(this["OuterUnit_" .. unit.camp .."_first"],"grid").transform
                setGrid(this.myAdjutantGrid,4)
            end
        elseif unit.camp == 1 then
            if enemyHaveSupport then
                go = BattlePool.GetItem(this["OuterUnit_" .. unit.camp .."_second"], BATTLE_POOL_TYPE.UNIT_VIEW)
                this.enemyAdjutantGrid = Util.GetGameObject(this["OuterUnit_" .. unit.camp .."_second"],"grid").transform
                setGrid(this.enemyAdjutantGrid,4)
                go.transform:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_zhandou_xianqudi")
                go.transform:GetComponent("Image"):SetNativeSize()
            elseif not enemyHaveSupport then
                go = BattlePool.GetItem(this["OuterUnit_" .. unit.camp .."_first"], BATTLE_POOL_TYPE.UNIT_VIEW)
                this.enemyAdjutantGrid = Util.GetGameObject(this["OuterUnit_" .. unit.camp .."_first"],"grid").transform
                setGrid(this.enemyAdjutantGrid,4)
            end
        end
    end

    local localScale = Vector3.one
    if unit.camp ~= 0 then
        localScale = Vector3.New(-1, 1, 1)
    end
    go.transform.localScale = Vector3.one
    Util.GetGameObject(go,"name").transform.localScale = localScale
    go:GetComponent("RectTransform").anchoredPosition = Vector2.zero
    go.transform.localEulerAngles = Vector3.New(0, 0, 0)
    go:SetActive(true)

    unitView[unit] = FightUnitView.New(go, unit, this)
end

function this.OnRemoveUnit(unit)
    local unit = unitView[unit]
    if unit then
        unit:Dispose()
        unitView[unit] = nil
    end
    this.mine:SetActive(false)
    this.enemy:SetActive(false)
end

function this.GetRoleView(role)
    return tbRole[role]
end

function this.UpdateCVSkillUI()
    -- this.cv_enemy = Util.GetGameObject(this.gameObject, "DownRoot/option/enemypart/cv")
    -- this.cv_mine = Util.GetGameObject(this.gameObject, "DownRoot/option/minepart/cv")
    -- local CurRound, MaxRound = BattleLogic.GetCurRound()
    -- local function setTurnUI(root, camp)
    --     if BattleManager.CV_equipDatas[camp] and #BattleManager.CV_equipDatas[camp] > 0 then
    --         root:SetActive(true)

    --         for i = 1, 4 do
    --             local icon = Util.GetGameObject(root, "frame/slot" .. tostring(i) .. "/icon")
    --             local lock = Util.GetGameObject(root, "frame/slot" .. tostring(i) .. "/lock")
    --             local Text = Util.GetGameObject(root, "frame/slot" .. tostring(i) .. "/Text")
    --             icon:SetActive(false)
    --             lock:SetActive(false)
    --             Text:SetActive(false)

    --             local shipConfig = G_MotherShipConfig[BattleManager.CV_equipDatas[camp + 2].CVLv]
    --             if i <= shipConfig.UnlockSite then
    --                 local planeId
    --                 local release
    --                 local cd
    --                 for j = 1, #BattleManager.CV_equipDatas[camp] do
    --                     if BattleManager.CV_equipDatas[camp][j].sort == i then
    --                         planeId = BattleManager.CV_equipDatas[camp][j].cfgId
    --                         release = BattleManager.CV_equipDatas[camp][j].release
    --                         cd = BattleManager.CV_equipDatas[camp][j].cd
    --                         break
    --                     end
    --                 end

    --                 if planeId then
    --                     icon:SetActive(true)
    --                     icon:GetComponent("Image").sprite = SetIcon(planeId)
    --                     local lastText = 0
    --                     if CurRound < release then
    --                         Util.SetGray(icon, false)           --< 未释放
    --                     elseif CurRound == release then
    --                         Util.SetGray(icon, true)            --< 初释放
    --                         Text:GetComponent("Text").text = cd - ((CurRound - release) % (cd + 1))
    --                         Text:SetActive(true)
    --                     elseif CurRound > release then
    --                         local R = (CurRound - release) % (cd + 1)
    --                         Util.SetGray(icon, true)
    --                         if cd - R == 0 then
    --                             Util.SetGray(icon, false)
    --                         else
    --                             Util.SetGray(icon, true)
    --                             Text:GetComponent("Text").text = cd - (CurRound - release) % (cd + 1)
    --                             Text:SetActive(true)
    --                         end
    --                     end
    --                 else
    --                     --> none
    --                 end
    --             else
    --                 --> lock
    --                 lock:SetActive(true)
    --             end
    --         end
    --     else
    --         root:SetActive(false)
    --     end
    -- end
    
    -- if BattleManager.CV_equipDatas then
    --     setTurnUI(this.cv_mine, 0)
    --     setTurnUI(this.cv_enemy, 1)
    -- end
end

function this.ResetRoleOrder()
    local order = this.root.sortingOrder--BattleManager.GetBattleSorting()
    -- 层级
    -- go.transform.localScale = Vector3.one
    for _roleLogic, _roleView in pairs(tbRole) do
        _roleView:ChangeEffectOrder()
        _roleView:SetBuffOrdering()
    end
    
    --> 结束统计时 
    for i, _roleView in pairs(tbRoleDispose) do
        _roleView:ChangeEffectOrder()
        _roleView:SetBuffOrdering()
    end
end

function this.ResetHighLight(isLight)
    if tbRole == nil or #tbRole<=0 then
        return
    end
    for _, role in pairs(tbRole) do
        if role ~= nil then
            role:SetHighLight(isLight, 1, 0.2)
        end
    end 
end

function this.ResetHighLightWithTargets(isLight, targets, yourself)
    for _, roleview in pairs(tbRole) do
        local isTarget = false
        if targets == nil then return end
        for key, role in pairs(targets) do
            if roleview == this.GetRoleView(role) then
                isTarget = true
            end
        end
        if roleview == yourself then
            isTarget = true
        end
        if not isTarget then
            roleview:SetHighLight(isLight, 1, 0.2)
        end
    end
end

function this.GetRoles()
    return tbRole
end

-- 设置角色高亮
function this.SetRoleHighLight(caster, targets, func, skill, cambat)
    this.ResetRoleOrder()
    -- 没有目标全部高亮
    if not caster and not targets then
        for _, role in pairs(tbRole) do
            role:SetHighLight(true, 1, 0.2)
        end
        -- 避免战斗结束时状态显示错误的问题
        if tbRoleDispose then
            for _, role in pairs(tbRoleDispose) do
                role:SetHighLight(true, 1, 0.2)
            end 
        end
        if func then func() end
        return 
    end
    -- 
    -- local i = 0
    -- local max = 0
    -- local function _Count()
    --     i = i + 1
    --     if i >= max then
    --         if func then func() end
    --     end
    -- end
    local function _gofight()
        if func then func() end
    end
    for _, role in pairs(tbRole) do
        -- max = max + 1
        -- role:SetHighLight(false, 0.95, 0.2, _Count)
        role:SetHighLight(false, 1, 0.1)
    end
    if caster then
        -- max = max - 1
        local chooseId = skill.effectList.buffer[1].chooseId
        local chooseType = math.floor(chooseId / 100000)
        --我方 自身 我方阵亡 我方含阵亡 不移动
        if cambat.Move == 1 and chooseType ~= 1 and chooseType ~= 3 and chooseType ~= 5 and chooseType ~= 6 then
            caster:SetHighLight(true, 1, 0.001)
            caster:DoFightMove(nil, caster:GetFightMovePos(skill), 3 * BattleLogic.GameDeltaTime , _gofight, true, true)
        elseif cambat.Move == 2 then --己方5号位
            caster:SetHighLight(true, 1, 0.001)
            local tarPos = FightCampTargetLocalPosition[caster.role.camp][5]
            caster:DoFightMove(nil, tarPos, 3 * BattleLogic.GameDeltaTime , _gofight, true, true)
        else
            caster:SetHighLight(true, 1, 0.1, _gofight)
        end
        -- caster:SetHighLight(true, 1.5, 0.2)
        caster:ChangeEffectOrder()
        caster:SetBuffOrdering()
        caster:HideBuff(true)
    end
    if targets then
        for _, data in ipairs(targets) do
            if caster ~= tbRole[data] then
                -- max = max - 1
                tbRole[data]:SetHighLight(true, 1, 0.2)

                tbRole[data]:ChangeEffectOrder()
                tbRole[data]:SetBuffOrdering()

            end
        end
    end
    -- if max == 0 then
    --     if func then func() end
    -- end
end

function this.PosToFrame(a_pos, b_pos, a_camp)
    local strtemp = a_camp == 0 and "Up" or "Down"
    local strtemp2 = a_camp == 0 and "_Pos_" or "_pos_"
    local keyStr = "Target_" .. strtemp .. strtemp2 .. b_pos

    local ret = TurretRotationConfig[a_pos][keyStr]

    return ret
end

--(新手引导专用)查找同一站位的人，敌方死亡，我方存活的
function this.GuideCheckEnemyDead(role)
    if not role:IsDead() and role.camp == 0 then
        for r, v in pairs(tbRole) do
            if r:IsDead() and r.camp == 1 and r.position == role.position then
                return true
            end
        end
    end
    return false
end

function this.OnUpdate()
    if BattleLogic.IsEnd then
        -- 所有角色血条
        for r, v in pairs(tbRoleDispose) do
            v:Update()
        end
    end

    for r, v in pairs(tbRole) do
        v:UpdateAnimation()
    end
    
    if BattleManager.IsBattlePlaying() and not BattleLogic.IsEnd then        
        BattleLogic.Update()
        -- 关键帧数据同步        
        -- BattleRecordManager.RollBack(BattleLogic.CurFrame(),RecordType.RoleManager)
        if BattleLogic.IsEnd then return end

        playerTmpHp = 0
        enemyTmpHp = 0
        -- 所有角色血条
        for r, v in pairs(tbRole) do
            v:Update()




            if r.camp == 0 then
                -- 测试代码
                --  if BattleLogic.GetCurRound()== 1 or BattleLogic.GetCurRound()== 2 then
                --     local maxHp=r:GetRoleData(RoleDataName.MaxHp)
                --     r:SetValue(RoleDataName.Hp,maxHp)
                --  end
                playerTmpHp = playerTmpHp + r:GetRoleData(RoleDataName.Hp)
            else
                -- 测试代码
                --  if BattleLogic.GetCurRound()== 1 or BattleLogic.GetCurRound()== 2 then
                --     local maxHp=r:GetRoleData(RoleDataName.MaxHp)
                --     r:SetValue(RoleDataName.Hp,maxHp)
                --  end
                enemyTmpHp = enemyTmpHp + r:GetRoleData(RoleDataName.Hp)
            end
        end
        -- 我方总血条
        if playerTmpHp ~= playerHP then
            local f1 = playerHP
            local f2 = playerTmpHp
            if this.tween1 then
                this.tween1:Kill()
            end
            this.tween1 = DoTween.To(DG.Tweening.Core.DOGetter_float( function () return f1 end),
                    DG.Tweening.Core.DOSetter_float(function (t)
                        this.PlayerHP.fillAmount = t / playerMaxHP
                    end), f2, 0.5):SetEase(Ease.Linear)
            playerHP = playerTmpHp
            this.PlayerHPTxt.text = GetLanguageStrById(10269)..math.floor(playerHP / playerMaxHP * 100).."%"
        end
        -- 敌方总血条
        if enemyTmpHp ~= enemyHP then
            local f1 = enemyHP
            local f2 = enemyTmpHp
            if this.tween2 then
                this.tween2:Kill()
            end
            this.tween2 = DoTween.To(DG.Tweening.Core.DOGetter_float( function () return f1 end),
                    DG.Tweening.Core.DOSetter_float(function (t)
                        this.EnemyHP.fillAmount = t / enemyMaxHP
                    end), f2, 0.5):SetEase(Ease.Linear)
            enemyHP = enemyTmpHp
            this.EnemyHPTxt.text = GetLanguageStrById(10270)..math.floor(enemyHP / enemyMaxHP  * 100).."%"
        end

        -- 驱动上层界面
        this.root.OnUpdate()
    -- elseif BattleManager.IsBattlePlaying() and BattleLogic.IsEnd and  UIManager.IsOpen(UIName.BattlePanel)  and  UIManager.IsTopShow(UIName.BattlePanel) 
    -- and not (UIManager.IsOpen(UIName.BattleWinPopup) or UIManager.IsOpen(UIName.BattleFailPopup)) then        
    --     BattleLogic.FeachResult()
    end

end

function this.OnSkillCast(skill)
    local type = skill.teamSkillType
    local camp = skill.owner.camp
    local pokemonConfig = PokemonEffectConfig[type]

    if camp == 0 then
        Util.SetGray(this.DiffMonster, true)
    else
        Util.SetGray(this.EnemyDiffMonster, true)
    end
    if camp == 1 then
        local yiPath2 = pokemonConfig.aoe
        local go3 = loadAsset(yiPath2)
        go3.transform:SetParent(this.transform)
        go3.transform.localScale = Vector3.one
        go3.transform.localPosition = camp == 0 and Vector3.New(0,100,0) or Vector3.New(0,-674,0)
        go3:SetActive(true)

        addDelayRecycleRes(yiPath2, go3, 3)
        return
    end

    local go = loadAsset("casting_skill")
    go:GetComponent("Canvas").sortingOrder = this.root.sortingOrder + 100
    go.transform:SetParent(this.gameObject.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition = Vector3.zero
    go:SetActive(true)

    local path = pokemonConfig.live
    local scale = pokemonConfig.scale
    local tran = Util.GetTransform(go, "player")

    local liveGO = poolManager:LoadAsset(path, PoolManager.AssetType.GameObject)
    liveGO.transform:SetParent(tran)
    liveGO.transform.localScale = Vector3.one * scale
    liveGO.transform.localPosition = Vector3.New(0, 0, 0)
    liveGO:SetActive(true)
    liveGO:GetComponent("SkeletonGraphic"):DOFade(1, 0)
    liveGO:GetComponent("SkeletonGraphic"):DOColor(Color.New(1,1,1,1), 0)

    BattleManager.PauseBattle()

    addDelayRecycleRes("casting_skill", go, 1.6, function ()
        local yiPath1 = pokemonConfig.screen
        local go2 = loadAsset(yiPath1)
        go2.transform:SetParent(this.transform)
        go2.transform.localScale = Vector3.one
        go2.transform.localPosition = Vector3.zero
        go2:SetActive(true)

        addDelayRecycleRes(yiPath1, go2, pokemonConfig.screenCD + 3, function ()
            local yiPath2 = pokemonConfig.aoe
            local go3 = loadAsset(yiPath2)
            go3.transform:SetParent(this.transform)
            go3.transform.localScale = Vector3.one
            go3.transform.localPosition = camp == 0 and Vector3.New(0,100,0) or Vector3.New(0,-674,0)
            go3:SetActive(true)

            BattleManager.ResumeBattle()

            addDelayRecycleRes(yiPath2, go3, 3)
        end, pokemonConfig.screenCD)
    end)
    addDelayRecycleRes(path, liveGO, 1.6)
end

-- 清除角色
function this:ClearRole()
    --把摄像机还回自己的父节点
    this:SetCameraParent(this.camera3DPos)

    for _, view in pairs(tbRole) do
        view:Dispose()
    end
    tbRole = {}
end

--清除支援
function this:ClearUnit()
    Timer.New(function()
        for _, unit in pairs(unitView) do
            unit:Dispose()
        end
        unitView = {}
    end, 1):Start()

    this.mine:SetActive(false)
    this.enemy:SetActive(false)
    this.mySupportGrid  = nil
    this.myAdjutantGrid = nil
    this.enemySupportGrid = nil
    this.enemyAdjutantGrid = nil
    this.mineLeaderSkill:SetActive(false)
    this.enemyLeaderSkill:SetActive(false)
end

-- 参数:object 抖动物体  timeScale 震动时长 dx, dy震动偏移量
local isShaking = false
function this:SetShake(object, timeScale, dx, dy, callBack)
    if isShaking then return end
    isShaking = true
    if not object then
        object = this.gameObject
    end
    if not timeScale or timeScale == 0 then
        timeScale = 0.2
    end
    if not dx or not dy or dy == 0 and dx == 0 then
        dx = 100
        dy = 100
    end
    object:GetComponent("RectTransform"):DOShakeAnchorPos(timeScale, Vector2.New(dx, dy),
                        500, 90, true, true):OnComplete(function ()
        if callBack then callBack() end
        isShaking = false
    end)
end

function this.FloatTotal(num)
    if num == 0 then
        return
    end

    local FloatingTotalText = Util.GetGameObject(this.TotalDmg, "FloatingTotalText")
    if not FloatingTotalText.activeSelf then
        FloatingTotalText:SetActive(true)
    end

    local anim = Util.GetGameObject(FloatingTotalText, "Text")
    anim:SetActive(false)
    anim:SetActive(true)

    anim:GetComponent("Text").text = num
   -- anim:GetComponent("Canvas").sortingOrder = BattleManager.GetBattleSorting() + 100
   -- anim:GetComponent("Animator"):Play("FloatTotalText_anim_1")

    local e = function()
        FloatingTotalText:SetActive(false)
    end

    if not this.TotalDmgTimer then
        this.TotalDmgTimer = Timer.New(e, 1, false)
        this.TotalDmgTimer:Start()
    else
        this.TotalDmgTimer:Reset(e, 1.5, false)
        this.TotalDmgTimer:Start()
    end
end

function this:UpdateAllRoleHPPos()
    for rd, roleview in pairs(tbRole) do
        if not rd:IsDead() then
            roleview:Update_HPPos()
        end
    end
end

---设置英雄是否显示,已死亡英雄不显示
---@param roleData any 由哪个调用的英雄数据
---@param type any 旋转类型
---0不操作
---1操作不相关角色
---2操作自己
---999操作所有人
---@param active any 是否显示
---@param targets any 目标
function this.SetRoleActive(roleData, type, active, targets)
    if type == 1 then
        for rd, roleview in pairs(tbRole) do
            local isTarget = false
            for key, role in pairs(targets) do
                if roleview == this.GetRoleView(role) then
                    isTarget = true
                end
            end
            if rd == roleData then
                isTarget = true
            end
            if not isTarget and not rd:IsDead() then
                roleview.RoleLiveGO:SetActive(active)
                roleview.GameObject:SetActive(active)
            end
        end
    elseif type == 2 then
        if IsNull(tbRole[roleData].RoleLiveGO) then
            return
        end
        tbRole[roleData].RoleLiveGO:SetActive(active)
    elseif type == 999 then
        for rd, roleview in pairs(tbRole) do
            if not rd:IsDead() and not IsNull(roleview.RoleLiveGO) then
                roleview.RoleLiveGO:SetActive(active)
                roleview.GameObject:SetActive(active)
            end
        end
    end
end

---跟SetRoleActive方法一样 只是能做操作可以执行事件
---设置英雄是否显示,已死亡英雄不显示
---@param roleData any 由哪个调用的英雄数据
---@param type any 旋转类型
---0不操作
---1操作不相关角色
---2操作自己
---999操作所有人
---@param active any 是否显示
---@param targets any 目标
function this.SetRoleActiveAndDoSomething(roleData, type, active, targets, func)
    if type == 1 then
        for rd, roleview in pairs(tbRole) do
            local isTarget = false
            for key, role in pairs(targets) do
                if roleview == this.GetRoleView(role) then
                    isTarget = true
                end
            end
            if rd == roleData then
                isTarget = true
            end
            if not isTarget and not rd:IsDead() then
                if func then
                    func(roleview, active)
                end
            end
        end
    elseif type == 2 then
        if func then
            func(tbRole[roleData], active)
        end
    elseif type == 999 then
        for rd, roleview in pairs(tbRole) do
            if not rd:IsDead() then
                if func then
                    func(roleview, active)
                end
            end
        end
    end
end

--> 设置对阵信息
function this.SetAgainstInfoUI()
    local leftFormationIcon = Util.GetGameObject(this.zhenxing_mine, "icon"):GetComponent("Image")
    local rightFormationIcon = Util.GetGameObject(this.zhenxing_enemy, "icon"):GetComponent("Image")
    -- local leftIcon = Util.GetGameObject(this.headpart_mine, "headicon"):GetComponent("Image")
    -- local leftFrame = Util.GetGameObject(this.headpart_mine, "heaframe"):GetComponent("Image")
    -- local rightIcon = Util.GetGameObject(this.headpart_enemy, "headicon"):GetComponent("Image")
    -- local rightFrame = Util.GetGameObject(this.headpart_enemy, "heaframe"):GetComponent("Image")
    -- local myInvestigateIcon = Util.GetGameObject(this.mineInvestigate,"Image_Icon")
    -- local enemyInvestigateIcon = Util.GetGameObject(this.enemyInvestigate,"Image_Icon")
    -- local myInvestigateStar = Util.GetGameObject(this.mineInvestigate,"starContent")
    -- local enemyInvestigateStar = Util.GetGameObject(this.enemyInvestigate,"starContent")
    local leftInvestigate = Util.GetGameObject(this.leftInvestigate,"Text"):GetComponent("Text")
    local rightInvestigate = Util.GetGameObject(this.rightInvestigate,"Text"):GetComponent("Text")
    -- 元素buff
    if #BattleManager.elements > 0 then
        local Image0 = Util.GetGameObject(this.zhenBuff_mine, "Image")
        local Image1 = Util.GetGameObject(this.zhenBuff_enemy, "Image")
        SetFormationBuffIcon(Image0, BattleManager.elements[0])
        SetFormationBuffIcon(Image1, BattleManager.elements[1])
    end

    local function SetInfo(_struct, _name, _formation, _Investigate)
        -- if _struct.head then
        --     --> 用类型区分
        --     if type(_struct.head) == "number" then
        --         _head.sprite = GetPlayerHeadSprite(_struct.head)
        --     elseif type(_struct.head) == "string" then
        --         _head.sprite = Util.LoadSprite(_struct.head)
        --     end
        -- end
        -- _head:SetActive(not not _struct.head)

        -- if _struct.headFrame then
        --     if _struct.headFrame == 0 then
        --     else
        --         _headFrame.sprite = GetPlayerHeadFrameSprite(_struct.headFrame)
        --     end
        -- end
        -- _headFrame:SetActive(not not _struct.headFrame)

        if _struct.name then
            if _struct.formationId == 0 and _struct.head == 0 and _struct.headFrame == 0 then
                _name:GetComponent("Text").text = GetLanguageStrById(tonumber(_struct.name))
            else
                _name:GetComponent("Text").text = _struct.name
            end
        end
        _name:SetActive(not not _struct.name)

        if _struct.formationId then
            if _struct.formationId == 0 then
            else
                _formation.sprite = Util.LoadSprite(GetResourceStr(G_FormationConfig[_struct.formationId].icon))
            end
        end
        _formation.gameObject:SetActive(not not _struct.formationId)
        --情报中心
        -- if not ActTimeCtrlManager.SingleFuncState(JumpType.InvestigateCenter) then
        --     this.leftInvestigate:SetActive(false)
        --     this.rightInvestigate:SetActive(false)
        -- else
        --     this.leftInvestigate:SetActive(true)
        --     this.rightInvestigate:SetActive(true)
        --     -- local investigateConfig
        --     if _struct.investigateLevel then
        --         -- if _struct.investigateLevel == 0 then
        --         --     investigateConfig = ConfigManager.GetConfigData(ConfigName.InvestigateConfig, 1)
        --         --     Util.SetGray(_investigateIcon, true)
        --         -- else
        --         --     investigateConfig = ConfigManager.GetConfigData(ConfigName.InvestigateConfig, _struct.investigateLevel)   
        --         -- end
        --         -- _investigateIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(investigateConfig.ArtResourcesIconId))
        --         -- SetHeroStars(_investigateStar,investigateConfig.Id)
        --         _Investigate.text = "Lv" .. _struct.investigateLevel
        --     end
        -- end
        if _struct.investigateLevel then
            _Investigate.text = "Lv" .. _struct.investigateLevel
        else
            _Investigate.text = "Lv" .. 0
        end
    end
    
    SetInfo(BattleManager.structA, this.name_mine, leftFormationIcon, leftInvestigate)
    SetInfo(BattleManager.structB, this.name_enemy, rightFormationIcon, rightInvestigate)
end

function this.OnOpenInvestigateBuff()
    -- BattleManager.PauseBattle()
    -- this.subPanelView:OnOpen(BattleManager.structA.investigateLevel,BattleManager.structB.investigateLevel,function ()
    --     BattleManager.ResumeBattle()
    -- end)
    -- this.subPanelView:OnShow()
    -- UIManager.OpenPanel(UIName.FormationStartCombatPanel,BattleManager.structA.investigateLevel,BattleManager.structB.investigateLevel,function ()
    --     BattleManager.ResumeBattle()
    -- end)
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
-->
--[[
    FixedUpdateBeat:Remove(this.OnUpdate, self)
    for _, v in pairs(tbRoleDispose) do
        v:Dispose()
    end
    tbRoleDispose = {}

    for k, v in pairs(delayRecycleList) do
        for i=1, #v do
            poolManager:UnLoadAsset(k, v[i], PoolManager.AssetType.GameObject)
        end
        delayRecycleList[k] = nil
    end

    BattlePool.Clear()
    poolManager:ClearPool()

    this.mySkillCast:SetActive(false)
    this.enemySkillCast:SetActive(false)
    -- this.CloseUpNode:SetActive(false)
    
    -- 
    BattleManager.StopBattle()
    
    this.ClearBattleEvent()

    this:ClearUnit()
]]

    Time.timeScale = 1
    -- 设置音效播放的速度
    SoundManager.SetAudioSpeed(1)
    SoundManager.StopAllChannelSound()
    --SoundManager.StopMusic()
    if IsEndBattle then
        Game.GlobalEvent:DispatchEvent(BattleEventName.BattleEndClearSceneRoles)
        IsEndBattle=false
    end
end

function this.ClearSkillRootEffect()
    local skillNodeArray = {}
    for i = 1, this.skillEffectRoot.transform.childCount do
        local go = this.skillEffectRoot.transform:GetChild(i-1).gameObject
        skillNodeArray[go] = go
    end
    for key, value in pairs(skillNodeArray) do
        local iterRole = function(go)
            for _, role in pairs(tbRole) do
                for k, v in pairs(role.delayRecycleList) do
                    for j = 1, #v do
                        if go == v[j].node then
                            if v[j].type == PoolManager.AssetTypeGo.GameObjectFrame then
                                poolManager:UnLoadFrame(k, v[j].node)
                            else
                                poolManager:UnLoadAsset(k, v[j].node, PoolManager.AssetType.GameObject)
                            end
                            table.remove(v, j)
                            return
                        end
                    end
                end
            end
        end
        iterRole(value)
    end
end

--> 原有onclose code
function this.BattleEndClear()
    FixedUpdateBeat:Remove(this.OnUpdate, this)
    for _, v in pairs(tbRoleDispose) do
        v:Dispose()
    end
    tbRoleDispose = {}

    for k, v in pairs(delayRecycleList) do
        for i = 1, #v do
            poolManager:UnLoadAsset(k, v[i], PoolManager.AssetType.GameObject)
        end
        delayRecycleList[k] = nil
    end

    BattlePool.Clear()
    poolManager:ClearPool()

    this.mySkillCast:SetActive(false)
    this.enemySkillCast:SetActive(false)

    BattleManager.StopBattle()
    -- LogYellow("battleview clear ClearBattleEvent")
    this.ClearBattleEvent()

    this:ClearUnit()

    this.root:BattleEndClear()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    -- SubUIManager.Close(this.ElementalResonanceView)
    -- SubUIManager.Close(this.ElementalResonanceView2)
    BattlePool.Destroy()

    -- SubUIManager.Close(this.subPanelView)
end

-- 参数: timeScale 震动时长 dx, dy震动偏移量
local isShaking = false
function this:ShakeCamera(time, dx, dy, dz, callBack)
    if isShaking then
        return
    end
    isShaking = true

    if  IsNull(this.camera3D) then
        return
    end

    if not time or time == 0 then
        time = 0.2
    end
    if not dx or not dy or dy == 0 and dx == 0 then
        dx = 0.1
        dy = 0.1
        dz = 0.1
    end

    this.camera3D.transform.parent:DOShakePosition(time, Vector3.New(dx, dy, dz), 100, 90, false, true)
    :OnComplete(function ()
        if callBack then
            callBack()
        end
        isShaking = false
    end)

    this.EnemyPanel.transform:DOShakeAnchorPos(time, Vector2.New(5, 5), 100, 90, false, true)
    this.MinePanel.transform:DOShakeAnchorPos(time, Vector2.New(5, 5), 100, 90, false, true)
end

--战斗粘滞
local BattleSticky_timeScale = 0.5   --0.3 --战斗粘滞 时间缩放系数
local BattleSticky_time = 0.2 --战斗粘滞 持续时长
local BattleSticky_timer = nil

--带参 粘滞
function this:BattleSticky_Param(timeScale, time)
    if not UIManager.IsOpen(UIName.BattlePanel) and not UIManager.IsOpen(UIName.GuideBattlePanel) then
        --隐藏战斗 不产生效果
        return
    end

    --实际粘滞效果
    local battleTimeScale = PlayerPrefs.GetFloat(PlayerManager.uid.."battleTimeScaleKey")--, BATTLE_TIME_SCALE_ONE)
    if battleTimeScale <= 0 then
        battleTimeScale = BATTLE_TIME_SCALE_ONE
    end
    Time.timeScale = battleTimeScale * timeScale

    --停止上一个延时
    if BattleSticky_timer then
        BattleSticky_timer:Stop()
    end

    --创建新延时
    BattleSticky_timer =
        Timer.New(
        function()
            if not this.IsJumpGameEnd then
                --回归为正常速度
                local time = PlayerPrefs.GetFloat(PlayerManager.uid.."battleTimeScaleKey")
                --如果切出状态，倍速固定为1
                if BattleManager.isFightBack then
                    time = 1
                end
                if time <= 0 then
                    time = BATTLE_TIME_SCALE_ONE
                end
                Time.timeScale = time--PlayerPrefs.GetFloat(PlayerManager.uid.."battleTimeScaleKey")--, BATTLE_TIME_SCALE_ONE)
            end
            BattleSticky_timer = nil
        end,
        time,
        false,
        true
    )
    --开始延迟
    BattleSticky_timer:Start()
end

--无参 粘滞 使用默认
function this:BattleSticky()
    this:BattleSticky_Param(BattleSticky_timeScale, BattleSticky_time)
end

--↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑

--设置3D相机位置
function this:SetCameraParent(parent)
    if IsNull(this.camera3D ) then
        return
    end
    this.camera3D.transform:SetParent(parent)
    this.camera3D.transform.localPosition = Vector3.zero
    this.camera3D.transform.localEulerAngles = Vector3.zero
    this.camera3D.transform.localScale = Vector3.one
end

--还原所有英雄动作为待机(主要用于游戏内切出调用)
function this:ResetAllRoleAnimation()
    for _, v in pairs(tbRole) do
        v:ResetSpineComponent(v.RoleLiveGOGraphic)
    end
end

return BattleView