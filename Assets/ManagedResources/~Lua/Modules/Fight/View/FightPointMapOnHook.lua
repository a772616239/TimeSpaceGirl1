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
    for j = 1, #curFormation.teamHeroInfos do
        local teamInfo = curFormation.teamHeroInfos[j]
        table.insert(heroPosArray, teamInfo.position, HeroManager.GetSingleHeroData(teamInfo.heroId))
    end

    rightCount = 0
    liveNodesLeft = {}
    liveNodesRight = {}
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

function this:UpdateMap(map)
    mapMeshRenderers = {}
    if map ~= nil then
        for i = 0, map.transform.childCount - 1 do
            local meshRenderer = map.transform:GetChild(i):GetComponent("MeshRenderer")
            if meshRenderer then
                table.insert(mapMeshRenderers, meshRenderer)
            end
        end
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

--英雄说话
function this:HeroTalk()
    local r = math.random(0,talkNum)
    if r == 0 then
        return
    end
    local rand1,rand2 = this:RandTalkPos(r)

    local talk = function (_rand)
        this.talkList[_rand]:SetActive(true)

        local talk = {}
        for i, v in ConfigPairs(afkSpeak) do
            if v.Type == talkPosList[_rand].Id or v.Type == 0 then
                table.insert(talk,v.AfkDialogue)
            end
        end
    
        Util.GetGameObject(this.talkList[_rand],"Text"):GetComponent("Text").text = GetLanguageStrById(talk[math.random(1,#talk)])
        Timer.New(function ()
            local animation = this.talkList[_rand]:GetComponent("Animation")
            animation:Play("cn2-X1_UI_FightPointPassMainPanel_talk_fan")
            Timer.New(function ()
                this.talkList[_rand]:SetActive(false)
            end,animation.clip.length):Start()
        end,2.5):Start()
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

   --开始回合战斗
   this:turn()
end

---所有节点播放动画
function this:allLiveNodesPlayAnim(liveNodes, time, name, isLoop)
    for key, value in pairs(liveNodes) do
        if value then
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
        for i = 1, #mapMeshRenderers do
            local old = mapMeshRenderers[i].material:GetFloat("_time")
            mapMeshRenderers[i].material:SetFloat("_time", old + Time.deltaTime)
        end

        --右侧敌人位移进位置
        local speedOffset = 4.1 --为了跟背景图同步的一个值
        local rightPos = this.RightPanel.transform.localPosition
        rightPos.x = rightPos.x - Time.deltaTime * speedOffset

        if rightPos.x <= this.rightTargetX then --移到位置
            --重新赋值为目标值
            rightPos.x = this.rightTargetX
            this:stopFindEnemy()
        end

        this.RightPanel.transform.localPosition = rightPos
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

    if not livenode or livenode==nil then
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

    if livenode.name ~= "role_aijiyanhou" then
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
                    -->
                    -- for j, v in ipairs(this.hitEffectArray) do
                    --     if v == go then
                    --         table.remove(this.hitEffectArray, j)
                    --     end
                    -- end

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
        if v then
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

return this