local this = {}

local FEAConfig = require("Modules/Battle/Config/FightEffectAudioConfig")
local Bezier = require("Base.Bezier")

local roleLiveGoLeft = {} --左方父节点
local roleLivePosLeft = {} --左方位置父节点
local liveNodesLeft = {} --左方人物
local liveNamesLeft = {} --左方名字
local turnArrayLeft = {} --左方战斗单位
local DoColor_Spine_TweenerLeft = {}--左方变换颜色的Tweener

local roleLiveGoRight = {} --右方父节点
local roleLivePosRight = {} --右方位置父节点
local liveNodesRight = {} --右方人物
local liveNamesRight = {} --右方名字
local turnArrayRight = {} --右方战斗单位
local DoColor_Spine_TweenerRight = {}--右方变换颜色的Tweener
local DeadMaterial_TweenerRight = {}--右方死亡材质
local afkSpeak = ConfigManager.GetConfig(ConfigName.AfkSpeak)

-- 挂机气泡「场景池」约定（AfkSpeak 表 Type 列）：
--   0        = 通用池（任何英雄、任何地图）
--   10001... = 英雄专属（Type == 英雄配置 Id）
--   9900 + n = 第 n 张挂机地图的场景吐槽（Map2 -> 9902）
--   40000 + 英雄id = 该英雄开大招时的专属台词
--   9998     = 通用大招台词（英雄没配专属台词，或 30% 混播）
-- 地图名来自 MainLevelConfig[curOpenFight].BG（Map1/Map2/Map5/Map7/Map8）。
local MAP_TALK_TYPE_BASE = 9900
local MAP_TALK_PERCENT = 40   -- 场景吐槽命中概率（%）

local ULT_TALK_TYPE_BASE = 40000
local ULT_TALK_TYPE_GENERIC = 9998
local ULT_HERO_PERCENT = 70   -- 大招台词里英雄专属的占比（%），其余走通用池
local ULT_OPEN_PERCENT = 55   -- 每场战斗「有人开局就放大招」的概率（%）
local ULT_HIT_CAP = 3         -- 挂机里的大招最多打 3 段（原生 12 段会把飘字刷满屏）

-- 最近说过的台词记忆条数：两个位置同帧说话、以及相邻几场之间靠它去重。
-- 要 ≥ 通用池规模（20 条），否则连打几场就会把最早说过的忘掉、开始整池循环重复；
-- 但也不能太大（英雄专属只有 2 条，记太久会把人家两句全堵死，只剩兜底重复）。取 24。
local TALK_RECENT_CAP = 24

---地图资源名 -> 场景池 Type；不是 MapN 形态就返回 nil（只是不说话，不报错）
local function MapTalkTypeFromName(mapName)
    if type(mapName) ~= "string" then
        return nil
    end
    local n = tonumber(string.match(mapName, "^Map(%d+)$"))
    if n == nil then
        return nil
    end
    return MAP_TALK_TYPE_BASE + n
end

---组一次气泡候选
---@param rows AfkSpeak 配置
---@param heroId number 说话位置上的英雄配置 Id
---@param mapType number|nil 当前场景池 Type
---@param roll number 1~100 的随机数（便于回归测试注入）
---@return table 候选语言 Id 列表
local function BuildTalkPool(rows, heroId, mapType, roll)
    local heroAndGeneric, mapTalk = {}, {}
    for i, v in ConfigPairs(rows) do
        if v.Type == heroId or v.Type == 0 then
            table.insert(heroAndGeneric, v.AfkDialogue)
        elseif mapType ~= nil and v.Type == mapType then
            table.insert(mapTalk, v.AfkDialogue)
        end
    end
    -- 场景池为空（新地图还没配台词）时自动退回通用池，不会出现「不说话」
    if #mapTalk > 0 and roll ~= nil and roll <= MAP_TALK_PERCENT then
        return mapTalk
    end
    return heroAndGeneric
end

---从候选池里挑一条「最近没说过」的台词
---同一次 HeroTalk 的两个气泡共用一个 recent（第一条挑完立刻入表），
---所以两个人不会同帧说同一句；跨场战斗也共用，相邻几场不会翻来覆去那一句。
---@param pool table 候选语言 Id 列表
---@param recent table 已说过的 Id 列表（先进先出，长度上限 TALK_RECENT_CAP）
---@param avoid table|nil 本轮正在显示的 Id（同帧第二个人必须避开，池子再小也不能撞）
---@return number|string|nil 选中的语言 Id；池为空时返回 nil
local function PickFreshTalk(pool, recent, avoid)
    if pool == nil or #pool == 0 then
        return nil
    end
    recent = recent or {}

    local used = {}
    for i = 1, #recent do
        used[recent[i]] = true
    end

    local function usable(id)
        return not (avoid ~= nil and avoid[id])
    end

    local fresh = {}
    for i = 1, #pool do
        local id = pool[i]
        if not used[id] and usable(id) then
            table.insert(fresh, id)
        end
    end
    -- 池子被历史掏空（例如英雄只有 2 句且都刚说过）：放宽「最近说过」，但仍然避开本轮正在显示的
    if #fresh == 0 then
        for i = 1, #pool do
            local id = pool[i]
            if usable(id) then
                table.insert(fresh, id)
            end
        end
    end
    -- 池里只有 1 条又正好在显示：只能重复，总比不说话好
    if #fresh == 0 then
        fresh = pool
    end

    local id = fresh[math.random(1, #fresh)]
    table.insert(recent, id)
    while #recent > TALK_RECENT_CAP do
        table.remove(recent, 1)
    end
    return id
end

----------------------------------------------------------------------
-- 大招：预计算 + 前摇台词
----------------------------------------------------------------------
-- 挂机战斗默认只打普攻；这里给每个单位补一个「大招」，
-- 每场战斗开场前随机抽 1 个我方单位，它这一场的下一招就是大招（其余人仍是普攻）。
-- 🔴 为什么只抽 1 个：敌方 deadTimes=1，我方一轮就把对面清完，本来就只有一回合；
--    全员放大招会让 9 个人同时抢镜，且大招动画（ReturnTime 2.5~5.8s）会互相盖住。
-- 抽签结果写在 turnArrayX[i].ultReady 上，HeroAttack 出手前就已知「这一招是不是大招」。

---大招段数收敛：只改本次挂机用的副本，不动配置本身
local function MakeHookCombat(combat)
    local count = tonumber(combat.SkillNumber) or 1
    if count <= ULT_HIT_CAP then
        return combat
    end
    local durations = {}
    for i = 1, ULT_HIT_CAP - 1 do
        local d = combat.SkillDuration and combat.SkillDuration[i]
        durations[i] = tonumber(d) or 150
    end
    -- __index 回落到原配置：特效、动画、音效、位移全部按原技能播，只把段数压到 3
    return setmetatable({ SkillNumber = ULT_HIT_CAP, SkillDuration = durations }, { __index = combat })
end

---槽位规则里挑「大招」：槽位最高、且 CombatControl.SkillType == 2 的主动技能
---（unlocked 由调用方决定：挂机演出传全 true，正式战斗可以按养成卡）
---@param rules table OpenSkillRules {{slot, group}, ...}
---@param unlocked table { [group] = true }
---@param displayOfGroup table { [group] = SkillDisplay }
---@param combatOfDisplay table { [display] = CombatControl 行 }
local function PickUltSlot(rules, unlocked, displayOfGroup, combatOfDisplay)
    local bestSlot, bestGroup, bestCombat = nil, nil, nil
    if type(rules) ~= "table" then
        return nil
    end
    for i = 1, #rules do
        local rule = rules[i]
        local slot = tonumber(rule and rule[1])
        local group = tonumber(rule and rule[2])
        if slot and group and slot > 0 and unlocked[group] then
            local display = displayOfGroup[group]
            local combat = display and combatOfDisplay[display]
            if combat and tonumber(combat.SkillType) == 2 then
                if bestSlot == nil or slot > bestSlot then
                    bestSlot, bestGroup, bestCombat = slot, group, combat
                end
            end
        end
    end
    return bestSlot, bestGroup, bestCombat
end

---英雄配置 -> 大招（combat 用挂机副本、skill 给受击判定用）
---🔴 挂机是「演出」不是推图：大招取槽位最高的主动技能，不看养成解锁（UnlockSkill）。
---   槽位 3 要 Rank>=3 才解锁，而挂机一直用 heroConfig 的静态星级、突破恒为 0，
---   按解锁算的话所有人都会退化成槽位 1，台词里那些技能名的梗就全对不上了。
---   技能等级固定取 Level=1：等级只影响数值，SkillDisplay（特效）与技能 id 稳定。
local function ResolveLoadout(heroConfig)
    if heroConfig == nil or heroConfig.OpenSkillRules == nil then
        return nil
    end
    local rules = heroConfig.OpenSkillRules

    local unlocked, displays, combats, logics = {}, {}, {}, {}
    for i = 1, #rules do
        local rule = rules[i]
        local slot = tonumber(rule and rule[1])
        local group = tonumber(rule and rule[2])
        if slot and group and slot > 0 then
            local logic = ConfigManager.GetConfigDataByDoubleKey(
                ConfigName.SkillLogicConfig, "Group", group, "Level", 1)
            if logic then
                unlocked[group] = true
                displays[group] = logic.SkillDisplay
                logics[group] = logic
            end
        end
    end

    for _, display in pairs(displays) do
        local combat = ConfigManager.GetConfigData(ConfigName.CombatControl, display)
        if combat then
            combats[display] = combat
        end
    end

    local slot, group, combat = PickUltSlot(rules, unlocked, displays, combats)
    if combat == nil or group == nil then
        return nil
    end

    local logic = logics[group]
    local skillCfg = nil
    if logic then
        local all = ConfigManager.GetConfig(ConfigName.SkillConfig)
        skillCfg = all and all[logic.Id]
    end
    -- 拿不到 SkillConfig 就不放这个技能：OnDamaged 会读 skill.Type，缺了会直接报错
    if skillCfg == nil then
        return nil
    end

    return {
        combat = MakeHookCombat(combat),
        skill = skillCfg,
        slot = slot,
        group = group,
    }
end

local ultCache = {}

---按英雄 id 取大招（一次解析，整局复用；nil 表示这个英雄没有可用大招）
local function ResolveHeroUlt(heroId)
    if heroId == nil then
        return nil
    end
    local cached = ultCache[heroId]
    if cached ~= nil then
        return cached or nil
    end
    local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroId)
    -- fail-open：某一个英雄的配置拼不起来，只让他不放这招，绝不能把 Init/CreateEnemy 带崩
    local ok, ult = pcall(ResolveLoadout, heroConfig)
    if not ok then
        LogError("onhook ResolveLoadout failed heroId=" .. tostring(heroId) .. " err=" .. tostring(ult))
        ult = nil
    end
    ultCache[heroId] = ult or false
    return ult
end

---大招台词候选：英雄专属池 70%，通用池 30%；专属缺失时直接用通用池
local function BuildUltPool(rows, heroId, roll)
    local hero, generic = {}, {}
    local heroType = ULT_TALK_TYPE_BASE + (tonumber(heroId) or -1)
    for i, v in ConfigPairs(rows) do
        if v.Type == heroType then
            table.insert(hero, v.AfkDialogue)
        elseif v.Type == ULT_TALK_TYPE_GENERIC then
            table.insert(generic, v.AfkDialogue)
        end
    end
    if #hero > 0 and (roll == nil or roll <= ULT_HERO_PERCENT) then
        return hero
    end
    if #generic > 0 then
        return generic
    end
    return hero
end

---从候选中抽一个位置；roll 同时决定「这一场有没有大招」和落在谁身上（便于测试注入）
local function PickOpenUltPos(candidates, roll)
    if candidates == nil or #candidates == 0 then
        return 0
    end
    if roll ~= nil and roll > ULT_OPEN_PERCENT then
        return 0
    end
    local r = tonumber(roll) or 1
    local idx = (r * 7919 + #candidates * 104729) % #candidates + 1
    return candidates[idx]
end

local rolePosCount = 9 --左右每侧位置数量
---右方数量
local rightCount = 0
---右方存活数量
local rightLiveCount = 0

---当前攻击方未出手的数量
local attackPosLen = 0
---当前攻击方未出手位置
local attackPos = {}
---当前防守方未被攻击长度
local defendPosLen = 0
---当前存活防守方位置
local defendPos = {}

-- 我方挂机时的阵容和战斗阵容一致，敌方阵容的人数与我方阵容人数相同，敌方单位随机，从表中取。
-- 挂机模拟战斗时，敌我双方均使用普攻，伤害数字根据角色攻击力浮动随机。
-- 挂机模拟战斗时，我方和敌方轮流行动，我方先行动，我方单位在1-2秒内先后出手攻击，随机选择不同的敌方单位攻击（一个回合每个敌方单位有且只会被一个我方单位攻击），轮到敌方行动时敌方也是在1-2秒内先后出手攻击，随机选择不同的我方单位攻击。
-- 敌方单位由于被击败导致我方单位人数大于敌方单位人数时，我方进攻时只有与敌方人数相同的成员会出手，剩余成员待机。
-- 敌方单位1-3回合会被击败，击败表现可以具有随机性（死亡、逃跑、投降献宝、落地成盒等）。 
local isPlay = false --是否播放
local isFindEnemy = false --是否在寻找敌人
-- local turnArray = {}
local isLeftTurn = true --该回合内是否是左方在出手
-- local turnIdx = 1 --单回合内左方或右方攻击序号

local effectPath = "eff_UI_loot_line" --m5
local floatingEffect = "FloatingText"
local m_parent
---当前窗口的基准渲染序列sortingOrder
local m_orginLayer = 0
local defaultSortingOrder = 0
---当前攻击方已增加渲染序列,设计上来讲最多到10
local attackSortingOrder = 1
---特效渲染序列
local skillEffectSortingOrder = 20
---前景渲染序列增加数
local bg_1SortingOrder = 40
---UI渲染序列增加数
local UIContentSortingOrder = 50

local ArtFloatingType = {
    CritDamage = 1, -- 暴击伤害
    Damage = 2, --普通伤害
    Treat = 3,
    FireDamage = 4,
    PoisonDamage = 5
}
local ArtFloatingAnim = {
    [1] = "Crit_Attack_Float",
    [2] = "Normal_Attack_Float",
    [3] = "floatingTextAnim",
    [4] = "floatingTextAnim",
    [5] = "floatingTextAnim"
}
local ArtFloatingColor = {
    Red = 0,
    White = 1,
    Yellow = 2,
    Green = 3,
    Purple = 4,
    Poison = 5,
    Fire = 6
}

-- 宝箱特效的位置
local boxEffectPos = {
    [1] = Vector3.New(0, 130, 0),
    [2] = Vector3.New(0, 130, 0),
    [3] = Vector3.New(0, 130, 0),
}

--英雄动画脚本名字
local SpineComponentName = "SkeletonAnimation"
--BattleScene层级
local BattleSceneLayer = 0
local battleSceneSkillTransform
local camera3D
local cameraUI
local Map
local mapMeshRenderers = {}
local talkPosList = {}--说话位置
local talkNum--说话数量
local effectPos = 1

local loadAsset = function(path, battleSorting)
    battleSorting = battleSorting or 0
    local go = poolManager:LoadAsset(path, PoolManager.AssetType.GameObject)
    local layer = tonumber(go.name) or 0
    Util.AddParticleSortLayer(go, battleSorting - layer)
    -- go.name = go.name .. tostring(battleSorting)
    --- 播放音效
    local audioData = FEAConfig.GetAudioData(path)
    if audioData then
        --SoundManager.PlaySound(audioData.name)
    end
    return go
end

---加载战斗场景里使用的资源
local loadAssetForScene = function(path)
    local go = poolManager:LoadAsset(path, PoolManager.AssetType.GameObject)
    go:SetLayer(BattleSceneLayer)
    -- go.name = go.name .. tostring(battleSorting)
    --- 播放音效
    -- local audioData = FEAConfig.GetAudioData(path)
    -- if audioData then
        --SoundManager.PlaySound(audioData.name)
    -- end
    return go
end

function this:InitComponent(root, parent, battleSceneLogic, battleScene)
    camera3D = Util.GetGameObject(battleScene, "CameraRoot/CameraPos/Camera"):GetComponent("Camera")
    cameraUI = UIManager.GetCamera()
    BattleSceneLayer = LayerMask.NameToLayer("BattleScene")
    battleSceneSkillTransform = Util.GetGameObject(battleSceneLogic, "Skill").transform

    --挂机场景相机根节点归位到 0（战斗内被抬到 -1.57，场景实例复用时要显式还原）
    BattleManager.SetCameraRootY(battleScene, BattleManager.CAMERA_ROOT_Y_HOOK)

    m_parent = parent
    this.battleSceneLogic = battleSceneLogic
    this.battleScene = battleScene
    
    this.buffTipList = {}

    this.effectRoot = Util.GetGameObject(root, "effectRoot")
    this.hitEffect = Util.GetGameObject(this.effectRoot, "UI_Map_XunBaoEffect_hit")
    this.buffTip = Util.GetGameObject(root, "effectRoot/money")
    -- this.effect_dead = Util.GetGameObject(root, "FightPoint/RolePanel/live_4/effect_Dead")
    -- 箱子
    this.boxEffectParent = Util.GetGameObject(root, "boxRoot/UI_effect_GuaJi_Box_BaoDian")
    this.boxEffects = {}
    for i = 1, 5 do
        table.insert(this.boxEffects, Util.GetGameObject(root, "boxRoot/UI_effect_GuaJi_Box_BaoDian/partical_click" .. i))
    end
    this.getBoxReward = Util.GetGameObject(root, "getBoxReward")

    this.RolePanel = Util.GetGameObject(root, "FightPoint/RolePanel")

    this.skill = Util.GetGameObject(root, "FightPoint/skill")

    this.BgCanvas = Util.GetGameObject(root, "Bg"):GetComponent("Canvas")
    
    this.LeftPanel = Util.GetGameObject(this.battleSceneLogic, "Left")
    roleLiveGoLeft = {}
    roleLivePosLeft = {}
    for i = 1, rolePosCount do
        table.insert(roleLiveGoLeft, Util.GetGameObject(this.LeftPanel, "live_" .. tostring(i)))
        table.insert(roleLivePosLeft, Util.GetGameObject(this.LeftPanel, "live_" .. tostring(i) .. "_pos"))
    end

    this.RightPanel = Util.GetGameObject(this.battleSceneLogic, "Right")
    roleLiveGoRight = {}
    roleLivePosRight = {}
    for i = 1, rolePosCount do
        table.insert(roleLiveGoRight, Util.GetGameObject(this.RightPanel, "live_" .. tostring(i)))
        table.insert(roleLivePosRight, Util.GetGameObject(this.RightPanel, "live_" .. tostring(i) .. "_pos"))
    end
    
    --右侧敌人移动到位置
    this.rightTargetX = this.RightPanel.transform.localPosition.x

    -- 挂机特效
    effectPos = 1
    this.moneyEffects = {}
    for i = 1, 5, 1 do
        local effect = poolManager:LoadAsset(effectPath, PoolManager.AssetType.GameObject)
        effect.transform:SetParent(this.effectRoot.transform)
        effect.transform.localScale = Vector3.one
        effect.transform.localPosition = Vector3.New(0, 0, 0)
        effect:SetActive(false)

        table.insert(this.moneyEffects, effect)
    end

    local configHero = ConfigManager.GetConfig(ConfigName.HeroConfig)
    this.idArray = {} --随机右方英雄id数组
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.HeroConfig)) do
        if configInfo["AfkUse"] == 1 or configInfo["AfkUse"] == 2 then
            table.insert(this.idArray, configInfo["Id"])
        end
    end

    local talk = Util.GetGameObject(this.BgCanvas.gameObject, "talk")
    this.talkList = {}
    for i = 1, rolePosCount do
        local obj = Util.GetGameObject(talk, "text" .. tostring(i))
        table.insert(this.talkList,obj)
    end
    if GetCurLanguage() == 10101 then
       floatingEffect="FloatingText_en"
    end
end

function this:AddListener()

end

function this:RemoveListener()

end

function this:ResetPos()
    for i = 1, #roleLiveGoLeft do
        if roleLiveGoLeft[i] and roleLivePosLeft[i] then
            roleLiveGoLeft[i].transform.localPosition = roleLivePosLeft[i].transform.localPosition
        end
    end

    for i = 1, #roleLiveGoRight do
        if roleLiveGoRight[i] and roleLivePosRight[i] then
            roleLiveGoRight[i].transform.localPosition = roleLivePosRight[i].transform.localPosition
        end
    end
end

function this:Init()
    -- 获得阵形数据
    local curFormation = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_NORMAL)
    --上阵列表赋值
    local heroPosArray = {}
    if curFormation ~= nil and curFormation.teamHeroInfos ~= nil then
        for j = 1, #curFormation.teamHeroInfos do
            local teamInfo = curFormation.teamHeroInfos[j]
            table.insert(heroPosArray, teamInfo.position, HeroManager.GetSingleHeroData(teamInfo.heroId))
         end
    end


    rightCount = 0
    liveNodesLeft = {}
    liveNodesRight = {}
    this:ClearTalkTimers()
    -- 台词记忆跨场保留（同一面板里连打几十场，靠它避免相邻两场说同一句）；
    -- 面板销毁时在 Dispose 里清空。
    this.talkRecent = this.talkRecent or {}
    talkPosList = {}
    talkNum = 0
    turnArrayLeft = {}
    for i = 1, rolePosCount do
        if heroPosArray[i] then
            rightCount = rightCount + 1
            local heroDataTemp = heroPosArray[i]

            this.SetRoleSingleWithData(roleLiveGoLeft[i], heroDataTemp.heroConfig, i, 0)
            if heroDataTemp.skillIdList == nil then
                LogError("### heroConfig openskillrules star not found ques")
            end
            table.insert(turnArrayLeft, {livego = roleLiveGoLeft[i], skillId = heroDataTemp.heroConfig.OpenSkillRules[1][2], heroid = heroDataTemp.heroConfig.Id})
            this:SetAttackData(i, 0)
        else
            table.insert(turnArrayLeft, {livego = nil, skillId = nil, heroid = nil})
        end
    end

    if not self.isInit then
        self.isInit = true

        self.LastFloatingTime = Time.realtimeSinceStartup
        self.FloatingCount = 0

        self.delayRecycleList = {}
    end
    this:ResetPos()
    FightPointPassManager.isBeginFight = false

    this:CreateEnemy()

    if not FightPointPassManager.IsChapterClossState() then
        this.integer, this.decimal = math.modf(FightPointPassManager.lastPassFightId/1000)--确定区域id
    else
        this.integer, this.decimal = math.modf(FightPointPassManager.curOpenFight/1000)
    end

    local data = ConfigManager.GetConfigData(ConfigName.MainLevelSettingConfig, this.integer)--获取这一区域所有数据

    --隐藏UI战斗
    this.RolePanel:SetActive(false)

    this:startFindEnemy()

    isPlay = true

    talkNum = this:GetTalkNum()
end

function this:UpdateMap(map, mapName)
    mapMeshRenderers = {}
    this.mapRoot = map
    -- 换图/换章节时跟着换吐槽池：拿不到名字就置 nil，退回通用池
    this.curMapType = MapTalkTypeFromName(mapName)
    if map == nil or IsNull(map) then
        return
    end
    for i = 0, map.transform.childCount - 1 do
        local meshRenderer = map.transform:GetChild(i):GetComponent("MeshRenderer")
        if meshRenderer then
            -- 材质在 UpdateMap 时取一次并缓存：
            -- ① Renderer.material 每次访问都会 new 一份材质实例，原来放在每帧 Update 里访问
            --    （每帧还访问两次）⇒ 每帧每块地图泄漏材质实例，长时间挂机必然涨内存；
            -- ② 地图一旦被销毁，Renderer.material 返回 nil（tolua 只报一条 destroyed 错误），
            --    后面接 :GetFloat 就是线上 event:172 的 "attempt to index material on a nil value"。
            table.insert(mapMeshRenderers, { renderer = meshRenderer, material = meshRenderer.material })
        end
    end
end

--- 背景地图 UV 流动（Update 每帧调用；单独抽出来便于回归测试）
function this:UpdateMapUV()
    for i = #mapMeshRenderers, 1, -1 do
        local item = mapMeshRenderers[i]
        if item == nil or item.material == nil or IsNull(item.material) or IsNull(item.renderer) then
            -- 地图已经被换掉/销毁（FightPointPassMainPanel 换章节 Destroy 了旧 mapGameObject，
            -- 或面板销毁把整棵战场带走）：整批渲染器一起作废，清空后等下一次 UpdateMap 重建，
            -- 绝不能每帧拿已销毁的 Material 去 GetFloat —— 那会每帧刷一条报错并且永远自愈不了。
            mapMeshRenderers = {}
            return
        end
        local material = item.material
        material:SetFloat("_time", material:GetFloat("_time") + Time.deltaTime)
    end
end

---开始寻找敌人
function this:startFindEnemy()
    --右侧人物移到屏幕外面
    local rightPos = this.RightPanel.transform.localPosition
    rightPos.x = 13 --从屏幕右边进入屏幕
    this.RightPanel.transform.localPosition = rightPos

    --左右开始播放人物跑动画
    this:allLiveNodesPlayAnim(liveNodesLeft, 0, RoleAnimationName.Run, true)
--    this:allLiveNodesPlayAnim(liveNodesRight, 0, RoleAnimationName.Run, true)

    if talkNum > 0 then
        this:HeroTalk()
    end

    isFindEnemy = true
end

---停掉所有气泡的收起定时器（换阵容 / 关面板时必须调，否则旧 Timer 会去关新气泡）
function this:ClearTalkTimers()
    if this.talkTimers == nil then
        return
    end
    for pos, timer in pairs(this.talkTimers) do
        if timer ~= nil then
            timer:Stop()
        end
        this.talkTimers[pos] = nil
    end
end

---在指定位置冒一个气泡
---@param pos number 1~9，对应 Bg/talk/textN
---@param langId number|string Language 表 id
---@param duration number 停留秒数（之后播收起动画再 SetActive(false)）
function this:ShowTalk(pos, langId, duration)
    local node = this.talkList and this.talkList[pos]
    if node == nil or IsNull(node) or langId == nil then
        return false
    end

    -- 同一位置的收起定时器必须先停：不然后一个气泡会被前一个的定时器提前关掉
    this.talkTimers = this.talkTimers or {}
    if this.talkTimers[pos] ~= nil then
        this.talkTimers[pos]:Stop()
        this.talkTimers[pos] = nil
    end

    local textNode = Util.GetGameObject(node, "Text")
    if textNode == nil or IsNull(textNode) then
        return false
    end
    node:SetActive(true)
    textNode:GetComponent("Text").text = GetLanguageStrById(langId)

    local timer = Timer.New(function()
        this.talkTimers[pos] = nil
        -- tolua fake-null：面板关掉后 GameObject 被 Destroy，lua 侧仍不是 nil
        if node == nil or IsNull(node) then
            return
        end
        local animation = node:GetComponent("Animation")
        local hold = 0.3
        if animation ~= nil then
            animation:Play("cn2-X1_UI_FightPointPassMainPanel_talk_fan")
            if animation.clip ~= nil then
                hold = animation.clip.length
            end
        end
        local hideTimer = Timer.New(function()
            this.talkTimers[pos] = nil
            if node ~= nil and not IsNull(node) then
                node:SetActive(false)
            end
        end, hold)
        this.talkTimers[pos] = hideTimer
        hideTimer:Start()
    end, duration or 2.5)
    this.talkTimers[pos] = timer
    timer:Start()
    return true
end

---大招前摇台词：英雄专属池优先，取不到就走通用池；两边都没有就不说话
function this:ShowUltTalk(pos)
    local heroConfig = talkPosList[pos]
    if heroConfig == nil then
        return false
    end
    local pool = BuildUltPool(afkSpeak, heroConfig.Id, math.random(1, 100))
    if #pool == 0 then
        return false
    end
    -- 2.2s：大招 KeyFrame 0.55~2.2s，气泡从起手一直留到伤害结算之后一点
    return this:ShowTalk(pos, PickFreshTalk(pool, this.talkRecent), 2.2)
end

---每场战斗开场前抽签：至多 1 个我方单位这一场的第一招是大招
---@param roll number|nil 1~100（测试注入；nil 时按 ULT_OPEN_PERCENT 必定命中）
---@return number 被选中的位置，0 表示这场没人放大招
function this:PrecomputeOpenUlt(roll)
    local candidates = {}
    for i = 1, #turnArrayLeft do
        local entry = turnArrayLeft[i]
        if entry ~= nil then
            entry.ultReady = false
            if entry.livego ~= nil and entry.ult ~= nil then
                table.insert(candidates, i)
            end
        end
    end

    local pos = PickOpenUltPos(candidates, roll)
    if pos > 0 and turnArrayLeft[pos] ~= nil then
        turnArrayLeft[pos].ultReady = true
    end
    return pos
end

--英雄说话
function this:HeroTalk()
    local r = math.random(0,talkNum)
    if r == 0 then
        return
    end
    local rand1,rand2 = this:RandTalkPos(r)

    -- 本轮正在显示的两句：第一个人挑完立刻登记，第二个人挑的时候必须避开
    local shownNow = {}
    local talk = function (_rand)
        -- 候选池：英雄专属 + 通用池，或者当前场景池（40% 概率，见 BuildTalkPool）
        local pool = BuildTalkPool(afkSpeak, talkPosList[_rand].Id, this.curMapType, math.random(1, 100))
        if #pool == 0 then
            -- 没词可说：不要先把气泡 SetActive(true)，否则会留一个空白气泡
            return
        end

        local langId = PickFreshTalk(pool, this.talkRecent, shownNow)
        if langId == nil then
            return
        end
        shownNow[langId] = true
        this:ShowTalk(_rand, langId, 2.5)
    end
    if rand1 and rand1 ~= 0 then
        talk(rand1)
    end
    if rand2 and rand2 ~= 0 then
        talk(rand2)
    end
end

--获取说话人的数量
function this:GetTalkNum()
    local talk = {}
    for i = 1, 9 do
        if talkPosList[i] ~= nil then
            table.insert(talk,i)
        end
    end

    local first = false
    local second = false
    local third = false
    for i, v in ipairs(talk) do
        if v == 1 or v == 4 or v == 7 then
            first = true
        elseif v == 2 or v == 5 or v == 8 then
            third = true
        elseif v == 3 or v == 6 or v == 9 then
            third = true
        end
    end
    if first and second and third then
        return 2
    elseif (first and second) or (first and third) or (second and third) then
        return 2
    end
    return 0
end

--递归出说话位置
function this:RandRecursion(_max,_rand,_list)
    local rand = math.random(1,_max)
    if _rand then
        if rand == _rand then
            return this:RandRecursion(_max,_rand)
        end
    elseif _list then
        if talkPosList[_list[1]] == nil and talkPosList[_list[2]] == nil and talkPosList[_list[3]] == nil then
            return 0
        end
        if talkPosList[_list[rand]] == nil then
            return this:RandRecursion(3,nil,_list)
        end

        return _list[rand]
    else
        if talkPosList[rand] == nil then
            return this:RandRecursion(9)
        end
    end

    return rand
end

--随机说话位置
function this:RandTalkPos(_taleNum)
    local randP = {
        [1] = {1,4,7},
        [2] = {2,5,8},
        [3] = {3,6,9}
    }
    if _taleNum == 1 then
        return this:RandRecursion(9)
    elseif _taleNum == 2 then
        local r1 = math.random(1,3)
        local r2 = this:RandRecursion(3,r1)

        local rand1 = this:RandRecursion(3,nil,randP[r1])
        local rand2 = this:RandRecursion(3,nil,randP[r2])
        return rand1,rand2
    end
    return 0
end

function this:stopFindEnemy()
    isFindEnemy = false

   --左右开始播放人物站立动画
   this:allLiveNodesPlayAnim(liveNodesLeft, 0, RoleAnimationName.Stand, true)
   this:allLiveNodesPlayAnim(liveNodesRight, 0, RoleAnimationName.Stand, true)

   -- 开场抽签：这一场谁的第一招是大招（必须在 turn 之前算好，HeroAttack 只读结果）
   this:PrecomputeOpenUlt(math.random(1, 100))

   --开始回合战斗
   this:turn()
end

---所有节点播放动画
function this:allLiveNodesPlayAnim(liveNodes, time, name, isLoop)
    for key, value in pairs(liveNodes) do
        if not IsNull(value) then
            self:PlaySpineAnim(value:GetComponent(SpineComponentName), time, name, isLoop)
        end
    end
end

--创建右方
function this:CreateEnemy()
    --清空右方
    for i = 1, #roleLiveGoRight, 1 do
        ClearChild(roleLiveGoRight[i])
    end

    for i = 1, #turnArrayRight do
        turnArrayRight[i] = nil
    end

    rightLiveCount = rightCount

    --假数据 敌人随机不重复位置
    local randomPos = {}
    for i = 1, rightLiveCount do
        while (not randomPos[i]) do
            local pos = math.random(1, rolePosCount) --随机一个位置
            if not table.indexof(randomPos, pos) then --不在记录里,加进去
                table.insert(randomPos, pos)
            end
        end
    end

    for i = 1, rolePosCount do
        local heroid = this.idArray[math.random(1, #this.idArray)]

        if table.indexof(randomPos,i) then--该位置表示可生成单位
            local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroid)
            this.SetRoleSingleWithData(roleLiveGoRight[i], heroConfig, i, 1)
            table.insert(turnArrayRight, {livego = roleLiveGoRight[i], skillId = heroConfig.OpenSkillRules[1][2], heroid = heroid, deadTimes = this:randDeadTimes()})
            this:SetAttackData(i, 1)
            roleLiveGoRight[i]:SetActive(true)
        else
            table.insert(turnArrayRight, {livego = nil, skillId = nil, heroid = nil})
        end
    end

    isLeftTurn = true --左方先出手
    attackSortingOrder = 1
    self.enemyDead = false
    attackPos, attackPosLen, defendPos, defendPosLen = this:randomTargetPos(turnArrayLeft, turnArrayRight)
end

function this:RandEnemy()
    -- self:DelayFunc(4, function()
        this:CreateEnemy()

        this:startFindEnemy() --开始寻找敌人阶段
    -- end)
end

---创建一个角色 camp:阵营(0=左方 1=右方)
function this.SetRoleSingleWithData(go, _heroconfigData, _pos, camp)
    local liveName = GetResourcePath(_heroconfigData.Live)
    local _scale = 1 --_heroconfigData.Scale
    local curPos = Vector3.zero --_heroconfigData.Position

    if liveName == "N1_btn_tongyong_guanbi" then
       
    end

    local liveNode = poolManager:LoadSpine(liveName, go.transform, Vector3.one * _scale, Vector3.New(curPos[1], curPos[2], 0))
    if not liveNode then
        LogError("liveNode = nil _heroconfigData.Id:" .. _heroconfigData.Id)
    end
    liveNode:SetLayer(BattleSceneLayer)
    local spineComponent = liveNode:GetComponent(SpineComponentName)
    this:ResetSpineComponent(spineComponent)
    liveNode.transform.localScale = Vector3.New((camp == 0 and 1 or -1) * liveNode.transform.localScale.x, liveNode.transform.localScale.y, liveNode.transform.localScale.z)

    local liveNames = nil
    local liveNodes = nil

    if camp == 0 then
        talkPosList[_pos] = _heroconfigData
        liveNames = liveNamesLeft
        liveNodes = liveNodesLeft
    else
        liveNames = liveNamesRight
        liveNodes = liveNodesRight
    end

    liveNames[_pos] = liveName
    liveNodes[_pos] = liveNode
end

---设置攻击数据
---@param i any 位置
---@param camp any 阵营(0=左方 1=右方)
function this:SetAttackData(i, camp)
    local turnArray = nil

    if camp == 0 then
        turnArray = turnArrayLeft
    else
        turnArray = turnArrayRight
    end

    if turnArray and turnArray[i] and turnArray[i].livego then
        local combat = ConfigManager.TryGetConfigData(ConfigName.CombatControl, turnArray[i].skillId)
        if not combat then
            combat = ConfigManager.GetConfigData(ConfigName.CombatControl, 1011)
            LogError("onhook SetAttackData")
        end
        local roleconfig = ConfigManager.GetConfigData(ConfigName.RoleConfig, turnArray[i].heroid)
        turnArray[i].combat = combat
        turnArray[i].roleconfig = roleconfig

        local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, turnArray[i].heroid)
        local skills = HeroManager.GetSkillIdsByHeroRules(heroConfig.OpenSkillRules, heroConfig.Star, 0)
        if skills and skills[1] then
            turnArray[i].skill = skills[1].skillConfig
        end

        -- 大招（槽位最高的 SkillType==2 技能）；每场开场前由 PrecomputeOpenUlt 抽签决定谁先放
        turnArray[i].ult = ResolveHeroUlt(turnArray[i].heroid)
        turnArray[i].ultReady = false
    end
end

---发起攻击
function this:HeroAttack()
    local dataAttack = nil --攻击方数据
    local liveNodesAttack = nil
    local roleLiveGoAttack = nil
    local roleLivePosAttack = nil
    
    local liveNodesDefend = nil
    local roleLiveGoDefend = nil
    local roleLivePosDefend = nil

    attackSortingOrder = attackSortingOrder + 1

    local turnIdx = this:randAttackPos()--随机一个存在角色的攻击位置

    if isLeftTurn then
        dataAttack = turnArrayLeft[turnIdx]
        liveNodesAttack = liveNodesLeft
        roleLiveGoAttack = roleLiveGoLeft
        roleLivePosAttack = roleLivePosLeft
        
        liveNodesDefend = liveNodesRight
        roleLiveGoDefend = roleLiveGoRight
        roleLivePosDefend = roleLivePosRight
    else
        dataAttack = turnArrayRight[turnIdx]
        liveNodesAttack = liveNodesRight
        roleLiveGoAttack = roleLiveGoRight
        roleLivePosAttack = roleLivePosRight
        
        liveNodesDefend = liveNodesLeft
        roleLiveGoDefend = roleLiveGoLeft
        roleLivePosDefend = roleLivePosLeft
    end
    
    if dataAttack and dataAttack.livego then
        -- dataAttack.livego:GetComponent("Canvas").sortingOrder = m_orginLayer + attackSortingOrder

        -- 「下一招是大招」在开场抽签时就算好了（turnEntry.ultReady）。
        -- 这里只换本次出手的 combat/skill，不污染 turnArray：用一层代理表，
        -- 延迟回调里读到的仍然是这一招自己的特效与段数。
        local turnEntry = dataAttack
        if turnEntry.ultReady == true and turnEntry.ult ~= nil then
            dataAttack = setmetatable(
                { combat = turnEntry.ult.combat, skill = turnEntry.ult.skill },
                { __index = turnEntry })
            turnEntry.ultReady = false
            -- 前摇窗口：CombatControl.KeyFrame 1.8~2.2s 后才结算伤害，气泡正好压在这段
            this:ShowUltTalk(turnIdx)
        end

        local targetIndex = this:randDefendPos()

        if dataAttack.combat.Move == 0 then
            --bullet
            self:PlaySpineAnim(liveNodesAttack[turnIdx]:GetComponent(SpineComponentName), 0, dataAttack.combat.Animation, false)

            --skillbefore
            if not isLeftTurn then --右方释放
                this:CheckSkillForoleEffect(isLeftTurn, dataAttack.combat, turnIdx, targetIndex, 2)
            else
                this:CheckSkillForoleEffect(isLeftTurn, dataAttack.combat, turnIdx, targetIndex, 1)
            end

            self:DelayFunc(dataAttack.combat.CastBullet / 1000, function()
                --attack effect
                -- if turnIdx == 4 then
                --     this:ShootBullet(data.combat, roleLivePos[4].transform, roleLivePos[targetIndex].transform, 2)
                -- else
                --     this:ShootBullet(data.combat, roleLivePos[turnIdx].transform, roleLivePos[4].transform, 1)
                -- end

                -- local t = 0
                -- for index, value in ipairs(data.combat.SkillDuration) do
                --     t = t + value
                -- end

                if not isLeftTurn then
                    this:CheckFullSceenSkill(isLeftTurn, dataAttack.combat, turnIdx, targetIndex, 2)
                else
                    this:CheckFullSceenSkill(isLeftTurn, dataAttack.combat, turnIdx, targetIndex, 1)
                end
            end)

            
            self:DelayFunc(dataAttack.combat.KeyFrame / 1000, function()
                --hit effect
                -- local idx = turnIdx == 4 and targetIndex or 4
                this:OnDamaged(roleLiveGoDefend[targetIndex], liveNodesDefend[targetIndex], this:randDmg(), this:randbCrit(), dataAttack.combat, dataAttack.skill, isLeftTurn, turnIdx, targetIndex)
            end)
            self:DelayFunc(dataAttack.combat.ReturnTime / 1000, function()
                --hit effect finish
                -- this:turn()
                -- this:ResetRoleOrder()
                -- dataAttack.livego:GetComponent("Canvas").sortingOrder = defaultSortingOrder
            end)
            if dataAttack.combat.SkillSound and #dataAttack.combat.SkillSound > 0 then
                self:DelayFunc(dataAttack.combat.SkillSoundDelay, function()
                    SoundManager.PlaySound(dataAttack.combat.SkillSound[1])
                end)
            end
        else
            --jump attack
            local _goBackFinish = function()
                if not isPlay then
                    return
                end
                -- this:turn()
                -- this:ResetRoleOrder()
                -- dataAttack.livego:GetComponent("Canvas").sortingOrder = defaultSortingOrder
            end
            local _MoveFinish = function()
                if not isPlay then
                    return
                end

                self:PlaySpineAnim(liveNodesAttack[turnIdx]:GetComponent(SpineComponentName), 0, dataAttack.combat.Animation, false)
                --skillbefore
                if not isLeftTurn then --右方释放
                    this:CheckSkillForoleEffect(isLeftTurn, dataAttack.combat, turnIdx, targetIndex, 2)
                else
                    this:CheckSkillForoleEffect(isLeftTurn, dataAttack.combat, turnIdx, targetIndex, 1)
                end
                self:DelayFunc(dataAttack.combat.CastBullet / 1000, function()
                    --attack effect
                    -- local t = 0
                    -- for index, value in ipairs(data.combat.SkillDuration) do
                    --     t = t + value
                    -- end
                    if not isLeftTurn then
                        this:CheckFullSceenSkill(isLeftTurn, dataAttack.combat, turnIdx, targetIndex, 2)
                    else
                        this:CheckFullSceenSkill(isLeftTurn, dataAttack.combat, turnIdx, targetIndex, 1)
                    end
                end)

                self:DelayFunc(dataAttack.combat.KeyFrame / 1000, function()
                    --hit effect
                    -- local idx = turnIdx == 4 and targetIndex or 4
                    this:OnDamaged(roleLiveGoDefend[targetIndex], liveNodesDefend[targetIndex], this:randDmg(), this:randbCrit(), dataAttack.combat, dataAttack.skill, isLeftTurn, turnIdx, targetIndex)
                end)
                self:DelayFunc(dataAttack.combat.ReturnTime / 1000 - 3 * BattleLogic.GameDeltaTime, function()
                    --hit effect finish
                    --go back
                    this:DoMoveFight(dataAttack.livego, roleLivePosAttack[turnIdx].transform.localPosition, 3 * BattleLogic.GameDeltaTime, _goBackFinish)
                end)

                if dataAttack.combat.SkillSound then
                    self:DelayFunc(dataAttack.combat.SkillSoundDelay, function()
                        local soundidx = math.random(1, #dataAttack.combat.SkillSound)
                        SoundManager.PlaySound(dataAttack.combat.SkillSound[soundidx])
                    end)
                end
                
            end

            --移动到目标点
            if not isLeftTurn then
                this:DoMoveFight(dataAttack.livego, roleLivePosDefend[targetIndex].transform.localPosition + Vector3.New(-3, 0, -0.1), 3 * BattleLogic.GameDeltaTime, _MoveFinish)
            else
                this:DoMoveFight(dataAttack.livego, roleLivePosDefend[targetIndex].transform.localPosition + Vector3.New(3, 0, -0.1), 3 * BattleLogic.GameDeltaTime, _MoveFinish)
            end
            
        end

        this:turn()

        -- roleLiveGo[turnIdx]:GetComponent("Canvas").sortingOrder = m_parent.sortingOrder + turnIdx + 5
        -- roleLiveGo[targetIndex]:GetComponent("Canvas").sortingOrder = m_parent.sortingOrder + targetIndex + 5
    else
        this:turn(true)
        return
    end
end

---
---@param isLeft any 是否是左方
---@param combat table
---@param _aObj any 施法方
---@param _bObj any 受击方
---@param type any
function this:CheckSkillForoleEffect(isLeft, combat, _aObj, _bObj, type)
    local a = nil
    local b = nil

    if isLeft then
        a = turnArrayLeft[_aObj]
        b = turnArrayRight[_bObj]
    else
        a = turnArrayRight[_aObj]
        b = turnArrayLeft[_bObj]
    end

    if not a or not b then
        return
    end
    if not combat then
        return 
    end
    if not combat.BeforeBullet or combat.BeforeBullet == "" then
        return 
    end
    local go
    local path = combat.BeforeBullet

    local offset = Vector3.zero
    if combat.BeforeOffset then
        local offset_x = type == 1 and combat.BeforeOffset[1] or -combat.BeforeOffset[1]
        offset = Vector3.New(offset_x, combat.BeforeOffset[2], 0)
    end

    -- 挂在人身上，以人物中心为原点
    if combat.BeforeEffectType == 1 then
        go = loadAssetForScene(path)
        go.transform:SetParent(a.livego.transform)
    -- 屏幕中心
    elseif combat.BeforeEffectType == 2 then
        go = loadAssetForScene(path)
        go.transform:SetParent(battleSceneSkillTransform)
    end
    
    -- -- 检测特效旋转
    -- if self:CheckRotate(go, combat.BeforeOrientation) then
    --     offset = -offset
    -- end

    go.transform.localScale = type == 1 and Vector3.one or Vector3.New(-1, 1, 1)
    go.transform.localPosition = Vector3.zero + offset
    go:SetActive(true)
    self:AddDelayRecycleRes(path, go, 4)
end

--- 检测是否需要释放全屏技能 isLeft:是否是左方 _aObj:施法方 _bObj:受击方
function this:CheckFullSceenSkill(isLeft, combat, _aObj, _bObj, type, livego)
    if not combat then
        return
    end
    
    local a = nil
    local b = nil
    local roleLivePosAttack = nil
    local roleLivePosDefend = nil

    if isLeft then
        a = turnArrayLeft[_aObj]
        b = turnArrayRight[_bObj]
        roleLivePosAttack = roleLivePosLeft[_aObj]
        roleLivePosDefend = roleLivePosRight[_bObj]
    else
        a = turnArrayRight[_aObj]
        b = turnArrayLeft[_bObj]
        roleLivePosAttack = roleLivePosRight[_aObj]
        roleLivePosDefend = roleLivePosLeft[_bObj]
    end

    if not a or not b then
        return
    end

    -- 指定目标弹道特效
    if combat.EffectType == 1 then
        this:ShootBullet(combat, roleLivePosAttack.transform, roleLivePosDefend.transform, type, livego)
    -- 全屏特效
    elseif combat.EffectType == 2 then
        -- 全屏弹道特效
        local path = combat.Bullet
        if path then

            local pos = b.livego.transform.localPosition
            -- 特效的偏移量
            local offset = Vector3.zero
            if combat.Offset then
                local offset_x = type == 1 and combat.Offset[1] or -combat.Offset[1]
                offset = Vector3.New(offset_x, combat.Offset[2], 0)
            end

            -- 
            local go = loadAssetForScene(path)
            go.transform:SetParent(battleSceneSkillTransform)
            go.transform.localScale = type == 1 and Vector3.one or Vector3.New(-1, 1, 1)
            go.transform.localPosition = pos + offset
            go:SetActive(true)
            self:AddDelayRecycleRes(path, go, 4)
        end
    end 
    
end

function this:randDeadTimes()
    return math.random(1, 1)
end

function this:randDmg()
    return math.random(100, 2000)
end

function this:randbCrit()
    return math.random() < 0.4
end

function this:randAttackPos()
    local pos = table.remove(attackPos, math.random(1, attackPosLen))
    attackPosLen = attackPosLen - 1
    return pos
end

--随机查找目标
function this:randDefendPos()
    local pos = table.remove(defendPos, math.random(1, defendPosLen))
    defendPosLen = defendPosLen - 1
    return pos
end

---
---转换下一个战斗单位
---
function this:turn(isNoDelay, delayTime)
    if (not self.enemyDead) and (not isFindEnemy) then
        if delayTime == nil then
            delayTime = 0.1 --默认每次行动间隔
        end
        local delay = isNoDelay and 0 or delayTime
        self:DelayFunc(delay, function()
			if self.enemyDead or isFindEnemy then --如果防守方全部死亡
                        return
             end
            if attackPosLen <= 0 or defendPosLen <= 0 then --一方完毕 或 对手都受到过一次攻击,换另一方 
                self:DelayFunc(1.5, function() --延迟执行交换攻守方
                    if self.enemyDead or isFindEnemy then --如果防守方全部死亡
                        return
                    end

                    attackSortingOrder = 1
                    isLeftTurn = not isLeftTurn
    
                    local turnArrayAttack = nil --攻击方
                    local turnArrayDefend = nil --防守方
                    if isLeftTurn then
                        turnArrayAttack = turnArrayLeft
                        turnArrayDefend = turnArrayRight
                    else
                        turnArrayAttack = turnArrayRight
                        turnArrayDefend = turnArrayLeft
                    end
    
                    attackPos, attackPosLen, defendPos, defendPosLen = this:randomTargetPos(turnArrayAttack, turnArrayDefend)
    
                    -- 下一轮
                    this:turn(true)
                end)
            else
                if not this:checkDead() then
                    this:HeroAttack()
                end
            end
        end)
    else
        -- this:ClearDelayFunc()
    end
end

function this:randomTargetPos(turnArrayAttack, turnArrayDefend)
   local attackPos = {}
   local attackPosLen = 0
   for i = 1, #turnArrayAttack do
    local role = turnArrayAttack[i]
        if role and role.livego then
            table.insert(attackPos, i)
            attackPosLen = attackPosLen + 1
        end
    end

    --当前对手还活着的单位位置
    local defendPos = {}
    local defendPosLen = 0
    for i = 1, #turnArrayDefend do
        local role = turnArrayDefend[i]
        if role and role.livego then
            table.insert(defendPos, i)
            defendPosLen = defendPosLen + 1
        end
    end

    return attackPos, attackPosLen, defendPos, defendPosLen
end

function this:checkDead()
    return false
end

function this:Update()
    if not isPlay then
        return
    end

    if isFindEnemy then
        this:UpdateMapUV()

        --右侧敌人位移进位置
        local rightPanel = this.RightPanel
        if rightPanel == nil or IsNull(rightPanel) then
            -- 战场节点已被销毁（面板销毁只保证走 OnDestroy，Dispose 不一定会跑到），
            -- 这里直接收掉播放状态，别每帧去索引已销毁的 transform。
            isFindEnemy = false
            isPlay = false
            return
        end
        local speedOffset = 4.1 --为了跟背景图同步的一个值
        local rightPos = rightPanel.transform.localPosition
        rightPos.x = rightPos.x - Time.deltaTime * speedOffset

        if rightPos.x <= this.rightTargetX then --移到位置
            --重新赋值为目标值
            rightPos.x = this.rightTargetX
            this:stopFindEnemy()
        end

        rightPanel.transform.localPosition = rightPos
    end
end

---移动景色图片
function this:MoveBgImage(bgImage, speed, deltaTime, offset, normalWidth)
    --因为宽度不同,计算相应速度速度
    offset = offset / (bgImage.rectTransform.sizeDelta.x / normalWidth)

    local uvRect = bgImage.uvRect;
    uvRect.x = uvRect.x + speed * deltaTime * offset
    if uvRect.x > 2 then
        uvRect.x = uvRect.x - 2
    end
    bgImage.uvRect = uvRect
end

function this:DoMoveFight(go, tarpos, dur, func)
    local oldpt = go.transform.localPosition
    DoTween.To(
    DG.Tweening.Core.DOGetter_float(
        function()
            return 0
        end
    ),
    DG.Tweening.Core.DOSetter_float(
        function(progress)
            go.transform.localPosition = Vector3.Lerp(oldpt, tarpos, progress)
        end
    ),
    1,
    dur
    ):SetEase(Ease.Linear):OnComplete(
        function()
            if func then
                func()
            end
        end
    )
end

function this:DelayFunc(time, func)
    if not self._DelayFuncList then
        self._DelayFuncList = {}
    end
    local timer
    timer =
        Timer.New(
        function()
            if not isPlay then
                LogError("已经停止播放了,但是还是调用时间到了")
                return
            end
            
            if func then
                func()
            end
            self:ClearDelayFunc(timer)
        end,
        time
    )
    timer:Start()
    table.insert(self._DelayFuncList, timer)
end

function this:ClearDelayFunc(t)
    if not self._DelayFuncList then
        return
    end
    if t then
        local rIndex
        for index, timer in ipairs(self._DelayFuncList) do
            if timer == t then
                rIndex = index
                break
            end
        end
        if rIndex then
            self._DelayFuncList[rIndex]:Stop()
            table.remove(self._DelayFuncList, rIndex)
        end
    else
        for _, timer in ipairs(self._DelayFuncList) do
            timer:Stop()
        end
        self._DelayFuncList = {}
    end
end

function this:PlaySpineAnim(spineComponent, time, name, isLoop)
    if isLoop then
        spineComponent.AnimationState:ClearEvent_Complete()
        spineComponent.AnimationState:SetAnimation(time, name, isLoop)
    else
        local _complete = nil
        _complete = function(state)
            spineComponent.AnimationState.Complete = spineComponent.AnimationState.Complete - _complete
            spineComponent.AnimationState:SetAnimation(0, RoleAnimationName.Stand, true)
        end
        this:ResetSpineComponent(spineComponent)
        spineComponent.AnimationState:SetAnimation(time, name, isLoop)
        spineComponent.AnimationState.Complete = spineComponent.AnimationState.Complete + _complete
    end
end

---释放子弹
---@param combat table 技能
---@param _aObj table 攻击方
---@param _bObj table 防守方
---@param type any 1 攻击方是我方 2 攻击方是敌方
function this:ShootBullet(combat, _aObj, _bObj, type)
    if not combat then
        return
    end
    local duration = combat.BulletTime / 1000
    local bulletEffect = combat.Bullet
    if not bulletEffect or bulletEffect == "" or duration == 0 then
        return
    end

    -- 目标点位置
    local endV3 = _bObj.position
    local tempHitOffset = combat.HitOffset or Vector3.zero
    local target_x_offset = type == 1 and -tempHitOffset[1] or tempHitOffset[1]
    endV3 = endV3 + Vector3.New(target_x_offset, tempHitOffset[2], 0)

    local count = combat.SkillNumber
    local function BulletFly()
        local go = loadAssetForScene(bulletEffect)
        go.transform:SetParent(battleSceneSkillTransform)
        go.transform.localScale = type == 1 and Vector3.one or Vector3.New(-1, 1, 1)

        --开始位置
        local startV3 = _aObj.position
        local tempOffset = combat.Offset or Vector3.zero
        local x_offset = type == 1 and tempOffset[1] or - tempOffset[1]
        startV3 = startV3 + Vector3.New(x_offset, tempOffset[2], 0)
        go.transform.position = startV3

        -- 旋转特效方向
        local worldReduceX = endV3.x - go.transform.position.x
        local worldReduceY = endV3.y - go.transform.position.y

        local angle = math.acos(math.abs(worldReduceX) / math.sqrt(worldReduceX * worldReduceX + worldReduceY * worldReduceY)) * 57.29578

        go.transform.localScale = type == 1 and Vector3.one or Vector3.New(-1, 1, 1)
        local isUp = endV3.y > go.transform.position.y
        local rotateZ = 0
        local isFlip = type == 1 and 1 or -1
        rotateZ = isUp and isFlip*angle or isFlip*-angle

        if combat.IsBulletRotation then
            go.transform:DORotate(Vector3.New(0, 0, rotateZ), 0)
        end

        Util.ClearTrailRender(go)
        go:SetActive(true)

        DoTween.To(
            DG.Tweening.Core.DOGetter_UnityEngine_Vector3(
                function()
                    return go.transform.position
                end
            ),
            DG.Tweening.Core.DOSetter_UnityEngine_Vector3(
                function(progress)
                    go.transform.position = progress
                end
            ),
            endV3,
            duration
        ):SetEase(Ease.InQuad):OnComplete(
            function()
                poolManager:UnLoadAsset(bulletEffect, go, PoolManager.AssetType.GameObject)
            end
        )
    end
    if count >= 1 and combat.SkillNumber - 1 == #combat.SkillDuration then
        for i = 1, #combat.SkillDuration do
            local time = 0
            for j = 1, i do
                time = time + combat.SkillDuration[j] / 1000
            end
            self:DelayFunc(
                time,
                function()
                    BulletFly()
                end
            )
            BulletFly()
        end
    else
        BulletFly()
    end
end

function this:OnSortingOrderChange(orginLayer)
    if this.moneyEffects then
        if m_orginLayer ~= 0 then
            m_orginLayer = m_orginLayer + UIContentSortingOrder + 1
            Util.AddParticleSortLayer(this.hitEffect, -m_orginLayer)
            Util.AddParticleSortLayer(this.boxEffectParent, -m_orginLayer)
            Util.AddParticleSortLayer(this.getBoxReward, -m_orginLayer)
            Util.AddParticleSortLayer(this.effectRoot, -m_orginLayer)
        end

        Util.AddParticleSortLayer(this.hitEffect, m_parent.sortingOrder + UIContentSortingOrder + 1)
        Util.AddParticleSortLayer(this.boxEffectParent, m_parent.sortingOrder + UIContentSortingOrder + 1)
        Util.AddParticleSortLayer(this.getBoxReward, m_parent.sortingOrder + UIContentSortingOrder + 1)
        Util.AddParticleSortLayer(this.effectRoot, m_parent.sortingOrder + UIContentSortingOrder + 1)
    end

    m_orginLayer = m_parent.sortingOrder

    this.skill:GetComponent("Canvas").sortingOrder = m_parent.sortingOrder + skillEffectSortingOrder

    this.BgCanvas.sortingOrder = m_orginLayer + UIContentSortingOrder
end

function this:ArtFloating(type, color, value, livego, targetIndex)

    local go = loadAsset(floatingEffect, self.skill:GetComponent("Canvas").sortingOrder)
    go.transform:SetParent(self.skill.transform)
    go.transform.localScale = Vector3.one
    go:GetComponent("RectTransform").localPosition = Util.WorldToLocalInRect(camera3D, livego.transform.position, cameraUI, self.skill:GetComponent("RectTransform"))
    go:SetActive(true)

    local v2 = go:GetComponent("RectTransform").anchoredPosition

    local posRow = (targetIndex - 1) % 3

    if posRow == 2 then -- 摄像机最近的
        v2 = v2 + Vector2.New(0, 265)
    elseif posRow == 1 then
        v2 = v2 + Vector2.New(0, 245)
    elseif posRow == 0 then
        v2 = v2 + Vector2.New(0, 225)
    end

    go:GetComponent("RectTransform").anchoredPosition = v2
    
    -- local offset = Vector2.New(10, 50)
    -- if self.delayRecycleList[floatingEffect] then
    --     for k, v in ipairs(self.delayRecycleList[floatingEffect]) do
    --         local pt = v:GetComponent("RectTransform").anchoredPosition
    --         -- pt = pt + offset
    --         v:GetComponent("RectTransform").anchoredPosition = pt
    --     end
    -- end

    local text = self:GetArtText(type, color, value)

    local colorArray = {[1] = "anim_Red", [2] = "anim_White", [3] = "anim_Yellow", [4] = "anim_Green"}
    for i = 1, #colorArray do
        local hideanim = Util.GetGameObject(go, colorArray[i])
        hideanim:SetActive(false)
    end
    if color + 1 > #colorArray then
        LogError("roleview color error!")
        return
    end
    local anim = Util.GetGameObject(go, colorArray[color + 1])
    anim:SetActive(true)

    -- local anim = Util.GetGameObject(go, "anim")
    anim:GetComponent("Text").text = text
    anim:GetComponent("Canvas").sortingOrder = m_parent.sortingOrder + 15
    anim:GetComponent("Animator"):Play(ArtFloatingAnim[type])
    self:AddDelayRecycleRes(floatingEffect, go, 2)
end

function this:GetArtText(type, color, value)
    local text = ""
    if type == ArtFloatingType.CritDamage then
        text = text .. string.char(98) -- 暴击文字
    end
    -- 数字
    local str = tostring(value)
    for i = 1, #str do
        text = text .. string.char(string.byte(str, i))
    end

    return text
end

---
---伤害战斗单位
---
---@param livego table 受伤的角色
---@param livenode integer
---@param dmg any
---@param bCrit any
---@param combat any
---@param skill any
---@param isLeft any 发出攻击的是否左方
---@param targetIndex any 受击方的角色位置
function this:OnDamaged(livego, livenode, dmg, bCrit, combat, skill, isLeft, turnIdx, targetIndex)
    if combat == nil then
        LogError("onhook OnDamaged combat nil")
        return
    end
    if combat and #combat.SkillDuration > 0 and combat.SkillNumber > 1 and #combat.SkillDuration == combat.SkillNumber - 1 then
        local count = combat.SkillNumber
        local d = math.floor(dmg / count)
        -- 如果平均伤害小于0 则
        if d == 0 then
            d = dmg
            count = 1
        end
        if count ~= 1 then
            -- 后续伤害延迟打出
            for i = 1, #combat.SkillDuration do
                local time = 0
                for j = 1, i do
                    time = time + combat.SkillDuration[j] / 1000
                end
                local bIsLastDamage = i == #combat.SkillDuration and true or false
                self:DelayFunc(
                    time,
                    function()
                        self:OnceDamaged(livego, livenode, dmg, bCrit, combat, skill, isLeft, turnIdx, targetIndex, bIsLastDamage)
                    end
                )
            end
            -- 立刻打出第一次伤害
            local fd = dmg - d * (count - 1)
            self:OnceDamaged(livego, livenode, dmg, bCrit, combat, skill, isLeft, turnIdx, targetIndex, false)
        else
            self:OnceDamaged(livego, livenode, dmg, bCrit, combat, skill, isLeft, turnIdx, targetIndex, true)
        end
    else
        self:OnceDamaged(livego, livenode, dmg, bCrit, combat, skill, isLeft, turnIdx, targetIndex, true)
    end


    local time = 0
    for j = 1, #combat.SkillDuration do
        time = time + combat.SkillDuration[j] / 1000
    end
    local _effectFinish = function()
        if isLeft then --发出攻击的是左方,判断右方血量
            if not turnArrayRight or not turnArrayRight[targetIndex] then
                return
            end
            turnArrayRight[targetIndex].deadTimes = turnArrayRight[targetIndex].deadTimes - 1

            if turnArrayRight[targetIndex].deadTimes <= 0 then
                --防守方角色死亡
                this:RoleOnDead(targetIndex)

                local boxState = FightPointPassManager.GetBoxState()
                boxState = boxState == 0 and 1 or boxState
                -- 播放特效
                this.SetEffect(targetIndex, boxState)
                
                if rightLiveCount <= 0 then --所有防守方都死亡,该场战斗结束
                    this:BattleEnd()
                end
            end
        end
    end
    self:DelayFunc(time + 0.2, _effectFinish)
end

function this:OnceDamaged(livego, livenode, dmg, bCrit, combat, skill, isLeft, turnIdx, targetIndex, isLastDamage)
    if self.isDead then
        return
    end

    if not livenode or livenode==nil or IsNull(livenode) then
        return
    end

    if not livego or livego==nil or IsNull(livego) then
        return
    end

    local roleLivePos = nil
    local roleLiveGo = nil
    local DoColor_Spine_Tweener = nil

    if not isLeft then
        roleLivePos = roleLivePosLeft
        roleLiveGo = roleLiveGoLeft
        DoColor_Spine_Tweener = DoColor_Spine_TweenerLeft
    else
        roleLivePos = roleLivePosRight
        roleLiveGo = roleLiveGoRight
        DoColor_Spine_Tweener = DoColor_Spine_TweenerRight
    end

    if bCrit then -- 暴击红色并显示暴击
        self:ArtFloating(ArtFloatingType.CritDamage, ArtFloatingColor.Red, dmg, roleLivePos[targetIndex], targetIndex)
    else
        self:ArtFloating(ArtFloatingType.Damage, ArtFloatingColor.White, dmg, roleLivePos[targetIndex], targetIndex)
    end

    livego.transform:DOKill(true)

    local startValue = livego.transform.localPosition.x;
    local endValue = livego.transform.localPosition.x;

    if isLeft then
        endValue = endValue + 0.6
    else
        endValue = endValue - 0.6
    end

    livego.transform.localPosition = Vector3.New(endValue, livego.transform.localPosition.y, livego.transform.localPosition.z)
    livego.transform:DOLocalMoveX(startValue, 0.3):SetEase(Ease.OutQuad)

    if livenode ~=nil and livenode.name ~= "role_aijiyanhou" then
        self:PlaySpineAnim(livenode:GetComponent(SpineComponentName), 0, RoleAnimationName.Injured, false)
    end

    if DoColor_Spine_Tweener[targetIndex] then
        DoColor_Spine_Tweener[targetIndex]:Kill()
    end

    DoColor_Spine_Tweener[targetIndex] = Util.DoColor_Spine(livenode:GetComponent(SpineComponentName), Color.New(1, 0, 0, 1), 0.3):OnComplete(
        function()
            if not isPlay then
                return
            end
            DoColor_Spine_Tweener[targetIndex] = Util.DoColor_Spine(livenode:GetComponent(SpineComponentName), Color.New(1, 1, 1, 1), 0.1)
        end
    )

    -- 播放受击动画
    if isLastDamage and skill.Type == 2 then
        self:PlaySpineAnim(livenode:GetComponent(SpineComponentName), 0, RoleAnimationName.Hurt, false)
    end

    -- 播放受击特效
    self:CheckSkillHitEffect(livego, combat, turnIdx)

end

-- 检测技能命中特效显示
function this:CheckSkillHitEffect(livego, combat, turnIdx)
    if not combat then
        return
    end
    -- 被击中时检测，如果是目标命中
    if combat.HitEffectType == 1 and combat.Hit then
        local offset_x = turnIdx == 4 and -combat.HitOffset[1] or combat.HitOffset[1]
        local offset = combat.HitOffset and Vector3.New(offset_x, combat.HitOffset[2], 0) or Vector3.zero
        
        local go2 = loadAssetForScene(combat.Hit)
        go2.transform:SetParent(livego.transform)
        go2.transform.localScale = turnIdx == 4 and Vector3.New(-1, 1, 1) or Vector3.one
        go2.transform.localPosition = offset
        go2:SetActive(true)
        self:AddDelayRecycleRes(combat.Hit, go2, 1)

        if combat.HitSound then
            local soundidx = math.random(1, #combat.HitSound)
            SoundManager.PlaySound(combat.HitSound[soundidx])
        end

        Util.SetParticleSortLayer(go2, m_parent.sortingOrder + 15)
    end
end

--所有需要延迟回收的资源走该接口，当回调执行前界面已被销毁时，不会报错
function this:AddDelayRecycleRes(path, go, delayTime, delayFunc)
    if not isPlay then
        LogError("挂机已经停止播放了,但是还在走调用延迟回收资源方法,资源名:" .. path)
        return
    end

    if not self.delayRecycleList[path] then
        self.delayRecycleList[path] = {}
    end
    table.insert(self.delayRecycleList[path], {node = go, type = delType})
    Timer.New(
        function()
            if not self.delayRecycleList[path] then
                return
            end
            if not isPlay then
                LogError("挂机已经停止播放了,但是还在走调用延迟回收资源方法的时间到方法,资源名:" .. path)
                return
            end
            for i = 1, #self.delayRecycleList[path] do
                if self.delayRecycleList[path][i].node == go then
                    -- tolua fake-null：特效挂在战斗角色节点下，角色被回收时特效随之销毁，
                    -- 但 Lua 侧 userdata 仍非 nil；必须先判活，已销毁只清登记项、不再触碰节点
                    -- （否则 Util.SetGray/UnLoad 对已销毁 GameObject 报错，见 FightPointMapOnHook:1901）
                    if IsNull(go) then
                        table.remove(self.delayRecycleList[path], i)
                        break
                    end
                    if self.delayRecycleList[path][i].type == PoolManager.AssetTypeGo.GameObjectFrame then
                        poolManager:UnLoadFrame(path, go)
                    else
                        Util.SetGray(go, false)
                        poolManager:UnLoadAsset(path, go, PoolManager.AssetType.GameObject)
                    end
                    table.remove(self.delayRecycleList[path], i)
                    break
                end
            end
            if delayFunc then
                delayFunc()
            end
        end,
        delayTime
    ):Start()
end

function this:BattleEnd()
    self.enemyDead = true
    
    local _nextTurn = function()
        this:RandEnemy()
    end
    self:DelayFunc(1.5, _nextTurn) --时间过短会导致动画不完结
end

function this:RoleOnDead(pos)
    --只会防守方死亡
    local roleLiveGo = roleLiveGoRight
    local liveNodes = liveNodesRight
    local liveNames = liveNamesRight
    local turnArray = turnArrayRight
    local DoColor_Spine_Tweener = DoColor_Spine_TweenerRight
    local DeadMaterial_Tweener = DeadMaterial_TweenerRight

    if not roleLiveGo[pos] then
        return
    end

    if not liveNodes[pos] then
        return
    end

    roleLiveGo[pos]:SetActive(true)
    liveNodes[pos]:SetActive(true)
    -- this.effect_dead:SetActive(true)

    --从数据先移除
    if turnArray[pos] ~= nil and turnArray[pos].livego ~= nil then
        turnArray[pos].livego = nil
    end

    rightLiveCount = rightLiveCount - 1

    --替换材质
    local spineComponent = liveNodes[pos]:GetComponent(SpineComponentName)
    local spineDeadMaterial = poolManager:LoadAsset("spineDead", PoolManager.AssetType.Other);
    local spineMaterial = spineComponent:GetComponent("MeshRenderer").sharedMaterial
    local customMaterialOverride = spineComponent.CustomMaterialOverride
    spineDeadMaterial = Material.New(spineDeadMaterial)
    table.insert(DeadMaterial_Tweener, spineDeadMaterial)
    spineDeadMaterial:SetTexture("_MainTex", spineMaterial:GetTexture("_MainTex"))
    customMaterialOverride:Add(spineMaterial, spineDeadMaterial);

    local startColor = Color.New(0.07843138, 0.145098, 1, 1)
    local endColor = Color.New(startColor.r, startColor.g, startColor.b, 1)

    if DoColor_Spine_Tweener[pos] then
        DoColor_Spine_Tweener[pos]:Kill()
    end
    
    DoColor_Spine_Tweener[pos] = Util.DoColor_Spine(spineComponent, startColor, endColor, 0):OnComplete(
        function()
            startColor.a = 1
            endColor.a = 0
            DoColor_Spine_Tweener[pos] = Util.DoColor_Spine(spineComponent, startColor, endColor, 0.8):OnComplete(
                function()

                    Util.SetColor_Spine(spineComponent, Color.New(1, 1, 1, 1))

                    --清除替换材质
                    local customMaterialOverride = spineComponent.CustomMaterialOverride
                    customMaterialOverride:Clear()

                    local removeIndex = -1
                    for index, value in ipairs(DeadMaterial_Tweener) do
                        if value == spineDeadMaterial then
                            removeIndex = index
                            GameObject.Destroy(value)
                            break
                        end
                    end
                    if removeIndex ~= -1 then
                        table.remove(DeadMaterial_Tweener, removeIndex)
                    end

                    roleLiveGo[pos]:SetActive(false)
                    liveNodes[pos]:SetActive(false)
                    spineComponent.AnimationState:SetAnimation(0, RoleAnimationName.Stand, true)
                    this:DelayFunc(0.5,function()
                        poolManager:UnLoadSpine(liveNames[pos], liveNodes[pos])
                    end)

                    liveNames[pos] = nil
                    liveNodes[pos] = nil
                end
            )
        end
    )
end

function this:StopAction()
    FightPointPassManager.isBeginFight = true
end

function this.SetEffect(pos, boxState)
    if not this.moneyEffects then
        return
    end

    local moneyEffect = this.moneyEffects[effectPos]
    effectPos = effectPos + 1 --循环使用
    if effectPos > 5 then
        effectPos = 1
    end
    local effectPosTemp = effectPos
    local roleLiveGo = roleLiveGoRight
    if not roleLiveGo[pos] then
        return
    end
    local tartPos = this.boxEffectParent.transform.position

    local localPosition = Util.WorldToLocalInRect(camera3D, roleLiveGo[pos].transform.position, cameraUI, moneyEffect.transform.parent)
    localPosition = Vector3.New(localPosition.x, localPosition.y + 80, localPosition.z)
    moneyEffect.transform.localPosition = localPosition

    Util.ClearTrailRender(moneyEffect)
    this.SetBoxEffect(false, Vector3.zero, effectPosTemp)
    if not FightPointPassManager.isBeginFight then
        moneyEffect:SetActive(true)
    end
    moneyEffect.transform:DOMove(tartPos, 0.6, false):OnComplete(function ()
        -- 这些该死的延迟动画
        -- if isPanelClose then return end
        if moneyEffect then
            moneyEffect:SetActive(false)
        end
        if not FightPointPassManager.isBeginFight then
            this.SetBoxEffect(true, boxState, effectPosTemp)
        end
    end)
    SoundManager.PlaySound(SoundConfig.Sound_FightArea_Gold)
end

-- 设置宝箱特效
function this.SetBoxEffect(isShow, state, pos)
    this.boxEffectParent:SetActive(isShow)
    
    if not isShow then
        if this.boxEffects[pos] then
            this.boxEffects[pos]:SetActive(false)
        end
    else
        this.boxEffects[pos]:SetActive(true)
        
    end
 
end

function this:Dispose()
    Log("Dispose")
    isFindEnemy = false
    isPlay = false
    -- 气泡的收起定时器不属于 DelayFunc 列表，必须单独停：否则面板关了还会去碰已销毁的节点
    this:ClearTalkTimers()
    -- 台词记忆随面板一起作废，下次开面板从空白开始
    this.talkRecent = {}
    -- 地图渲染器缓存跟着这一轮播放一起作废；下次 OnShow 会重新 UpdateMap 重建
    mapMeshRenderers = {}
    this.mapRoot = nil
    this:ClearDelayFunc()
    --立即回收延迟列表上的资源
    if self.delayRecycleList then
        for k, v in pairs(self.delayRecycleList) do
            for i = 1, #v do
                if v[i].type == PoolManager.AssetTypeGo.GameObjectFrame then
                    poolManager:UnLoadFrame(k, v[i].node)
                else
                    poolManager:UnLoadAsset(k, v[i].node, PoolManager.AssetType.GameObject)
                end
                
            end
            self.delayRecycleList[k] = nil
        end
    end

    for key, value in pairs(DoColor_Spine_TweenerLeft) do
        DoColor_Spine_TweenerLeft[key]:Kill()
        DoColor_Spine_TweenerLeft[key] = nil
    end
    for key, value in pairs(DoColor_Spine_TweenerRight) do
        DoColor_Spine_TweenerRight[key]:Kill()
        DoColor_Spine_TweenerRight[key] = nil
    end

    for index, value in ipairs(DeadMaterial_TweenerRight) do
        GameObject.Destroy(value)
    end
    DeadMaterial_TweenerRight = {}

    for i, v in pairs(liveNodesLeft) do
        if v then
            local spineComponent = v:GetComponent(SpineComponentName)
            spineComponent.transform:DOKill()
            this:ResetSpineComponent(spineComponent)
            poolManager:UnLoadSpine(liveNamesLeft[i], v)
            liveNamesLeft[i]= nil
        end
    end
    liveNamesLeft = {}
    liveNodesLeft = {}

    for i, v in pairs(liveNodesRight) do
        if not IsNull(v)  then
            local spineComponent = v:GetComponent(SpineComponentName)
            spineComponent.transform:DOKill()
            this:ResetSpineComponent(spineComponent)
            poolManager:UnLoadSpine(liveNamesRight[i], v)
            liveNamesRight[i]= nil
        end
    end
    liveNamesRight = {}
    liveNodesRight = {}
    this.boxEffectParent:SetActive(false)

    -- turnArray = {}
end

function this:OnDestroy()
    if this.moneyEffects then
        for index, value in ipairs(this.moneyEffects) do
            poolManager:UnLoadAsset(effectPath, value, PoolManager.AssetType.GameObject)
        end
        this.moneyEffects = {}
    end
end

--重置Spine脚本
function this:ResetSpineComponent(spineComponent)
    Util.SetColor_Spine(spineComponent, Color.white)
    spineComponent.CustomMaterialOverride:Clear()
    spineComponent.AnimationState:ClearEvent_Complete()
    spineComponent.Skeleton:SetToSetupPose()
    spineComponent.AnimationState:ClearTracks()
    spineComponent.AnimationState:SetAnimation(0, RoleAnimationName.Stand, true)
end

--暴露给 scripts/lua-tests（纯函数，不碰 UI）
this.BuildTalkPool = BuildTalkPool
this.PickFreshTalk = PickFreshTalk
this.TALK_RECENT_CAP = TALK_RECENT_CAP
this.MapTalkTypeFromName = MapTalkTypeFromName
this.MAP_TALK_PERCENT = MAP_TALK_PERCENT
this.BuildUltPool = BuildUltPool
this.PickUltSlot = PickUltSlot
this.PickOpenUltPos = PickOpenUltPos
this.MakeHookCombat = MakeHookCombat
this.ResolveLoadout = ResolveLoadout
this.ULT_TALK_TYPE_BASE = ULT_TALK_TYPE_BASE
this.ULT_TALK_TYPE_GENERIC = ULT_TALK_TYPE_GENERIC
this.ULT_HERO_PERCENT = ULT_HERO_PERCENT
this.ULT_OPEN_PERCENT = ULT_OPEN_PERCENT
this.ULT_HIT_CAP = ULT_HIT_CAP

return this