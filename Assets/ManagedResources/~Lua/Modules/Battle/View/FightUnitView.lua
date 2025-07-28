require("Modules.Battle.Logic.Misc.BattleDefine")
local FEAConfig = require("Modules/Battle/Config/FightEffectAudioConfig")
FightUnitView = {}
FightUnitView.__index = FightUnitView
local this = FightUnitView

local MonsterViewConfig = ConfigManager.GetConfig(ConfigName.MonsterViewConfig)
local MonsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local RoleConfig = ConfigManager.GetConfig(ConfigName.RoleConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local ArtifactConfig = ConfigManager.GetConfig(ConfigName.ArtifactConfig)
local AdjutantConfig = ConfigManager.GetConfig(ConfigName.AdjutantConfig)
local MainLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local BattleEventConfig = ConfigManager.GetConfig(ConfigName.BattleEventConfig)


local loadAsset = function(path, battleSorting, notPlaySound)
    local go = poolManager:LoadAsset(path, PoolManager.AssetType.GameObject)
    if not go then
        LogError("未找到资源:" .. path)
    end
    local layer = tonumber(go.name) or 0
    battleSorting = battleSorting or BattleManager.GetBattleSorting()
    Util.AddParticleSortLayer(go, battleSorting - layer)
    go.name = tostring(battleSorting)
    --- 播放音效
    if not notPlaySound then        
        local audioData = FEAConfig.GetAudioData(path)
        if audioData then
            SoundManager.PlayBattleSound(audioData.name)            
        end
    end
    return go
end

---加载战斗场景里使用的资源
function FightUnitView:loadAssetForScene(path, parent)
    local go = poolManager:LoadAsset(path, PoolManager.AssetType.GameObject)
    if go then
        go:SetLayer(self.RootPanel.battleSceneLayer)
        go.transform:SetParent(parent, false)
        -- go.name = go.name .. tostring(battleSorting)
        --- 播放音效
        -- local audioData = FEAConfig.GetAudioData(path)
        -- if audioData then
            --SoundManager.PlaySound(audioData.name)
        -- end
    end
    return go
end

function FightUnitView.New(go, unit, root)
    local instance = {}
    setmetatable(instance, FightUnitView)
    instance.RootPanel = root
    instance.GameObject = go
    instance.unit = unit
    instance.camp = unit.camp
    if this.battlePanel == nil then
        this.battlePanel = root
    end

    instance.delayRecycleList = {}

    unit.Event:AddEvent(BattleEventName.SkillCast, instance.OnSkillCast, instance)
    unit.Event:AddEvent(BattleEventName.SkillCastEnd, instance.OnSkillCastEnd, instance)

    if instance.unit.unitData.type == FightUnitType.UnitSupport then
        Util.GetGameObject(instance.GameObject,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(ArtifactConfig[tonumber(instance.unit.unitData.rootId)].BattleIcon))
        Util.GetGameObject(instance.GameObject,"name"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_zhandou_shouhu"))
    elseif instance.unit.unitData.type == FightUnitType.UnitAdjutant then
        Util.GetGameObject(instance.GameObject,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(AdjutantConfig[tonumber(instance.unit.unitData.rootId)].BattleIcon))
        Util.GetGameObject(instance.GameObject,"name"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_zhandou_xianqu"))
    elseif instance.unit.unitData.type == FightUnitType.UnitAircraftCarrier then
        local tempSkills = {}
        instance.skillids = {}
        
        for i = 1, #instance.unit.skill do
            table.insert(tempSkills, instance.unit.skill[i])
        end
        table.sort(tempSkills, function(a, b)
            return a[8].release < b[8].release
        end)
        for i = 1, #tempSkills do
            table.insert(instance.skillids, tempSkills[i][1])
        end

        local planeConfig = ConfigManager.GetConfigDataByKey(ConfigName.MotherShipPlaneConfig, "Skill", instance.skillids[1])
        instance.cvIdx = 1
        Util.GetGameObject(instance.GameObject, "Image"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(planeConfig.Res))
    end

    return instance
end

function FightUnitView:OnSkillCast(skill, func)
    if not skill then
        return
    end
    local combat = BattleManager.GetSkillCombat(SkillLogicConfig[skill.id].SkillDisplay)
    if not combat then
        return
    end
    BattleManager.PauseBattle()

    self:SceneCardAni(skill, combat)
end

-- function FightUnitView:PreDialogue(skill, combat)
--     if self.unit.unitData.isAppend and --< 是否追加
--        self.unit.unitData.client_dialogue and self.unit.unitData.client_dialogue ~= 0 then
        
--         StoryManager.EventTrigger(self.unit.unitData.client_dialogue, function()

--             self:PreCloseUp(skill, combat)
--         end)
--     else
--         self:PreCloseUp(skill, combat)
--     end
-- end

function FightUnitView:PreCloseUp(skill, combat)
    if combat.Closeup ~= nil and combat.Closeup ~= "" then
        self:CloseUpShow(skill, combat, function()
            self:SceneCardAniProcess(skill, combat)
        end)
    else
        self:SceneCardAniProcess(skill, combat)
    end
end

function FightUnitView:SceneCardAni(skill, combat)
    local aniName = "support"
    if self.unit.type == FightUnitType.UnitSupport then
        aniName = "support"
    elseif self.unit.type == FightUnitType.UnitAdjutant then
        aniName = "fuguan"
    elseif self.unit.type == FightUnitType.UnitAircraftCarrier then
        aniName = "cv"
    end
    self.GameObject.transform.parent.parent:GetComponent("Animator").enabled = true
    self.GameObject.transform.parent.parent:GetComponent("Animator"):Play(aniName)
    self:DelayFunc(0.7, function()
        self.GameObject.transform.parent.parent:GetComponent("Animator").speed = 0
        self:PreCloseUp(skill, combat)
    end)

end

function FightUnitView:SceneCardAniProcess(skill, combat)
    BattleManager.ResumeBattle()
    self.GameObject.transform.parent.parent:GetComponent("Animator").speed = 1
    self:CheckSkillForoleEffect(combat, skill)
    self:DelayFunc(
        combat.CastBullet / 1000,
        function()
            if self.unit.type == FightUnitType.UnitSupport then
                self:PlayEffect(skill, combat)
            elseif self.unit.type == FightUnitType.UnitAdjutant then
                self:PlayEffect(skill, combat)
            elseif self.unit.type == FightUnitType.UnitAircraftCarrier then
                self:PlayEffect(skill, combat)
            end
        end
    )

    if combat.PV then
        --播放守护
        if self.unit.type == FightUnitType.UnitSupport then
            self:PlayPV_UnitSupport(combat, skill,function ()
                this.battlePanel:SetUnitReleaseSkill(self.GameObject)
            end)
        elseif self.unit.type == FightUnitType.UnitAdjutant then
            self:PlayPV_UnitAdjutant(combat, skill,function ()
                this.battlePanel:SetUnitReleaseSkill(self.GameObject)
            end)
        end
    end
end

function FightUnitView:OnSkillCastEnd(skill)
    if self.unit.type == FightUnitType.UnitAircraftCarrier then
        self.cvIdx = self.cvIdx + 1
        if self.cvIdx > #self.skillids then
            self.cvIdx = 1
        else

        end
        local planeConfig = ConfigManager.GetConfigDataByKey(ConfigName.MotherShipPlaneConfig, "Skill", self.skillids[self.cvIdx])
        Util.GetGameObject(self.GameObject, "Image"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(planeConfig.Res))
    end
end

-- 检测前摇技能释放
function FightUnitView:CheckSkillForoleEffect(combat, skill)
    if not skill then
        return 
    end
    if not combat.BeforeBullet or combat.BeforeBullet == "" then
        return 
    end
    local go
    local path = combat.BeforeBullet
    local offset = combat.BeforeOffset and Vector3.New(combat.BeforeOffset[1], combat.BeforeOffset[2], 0) or Vector3.zero
    -- 挂在人身上，以人物中心为原点
    if combat.BeforeEffectType == 1 then
        go = loadAsset(path, self.RootPanel.skillEffectRoot:GetComponent("Canvas").sortingOrder)
        go.transform:SetParent(self.GameObject.transform)
    -- 屏幕中心
    elseif combat.BeforeEffectType == 2 then
        go = loadAsset(path, self.RootPanel.skillEffectRoot:GetComponent("Canvas").sortingOrder)
        go.transform:SetParent(self.RootPanel.skillEffectRoot.transform)
    end

    local mine = Util.GetGameObject(go, "mine")
    local enemy = Util.GetGameObject(go, "enemy")
    if mine and enemy then
        mine:SetActive(false)
        enemy:SetActive(false)
        if self.camp == 0 then
            mine:SetActive(true)
        else
            enemy:SetActive(true)
        end
    else
        LogError("### skill before mine or enemy not have")
    end

    go.transform.localScale = Vector3.one
    go.transform.localPosition = Vector3.zero
    
    go:SetActive(true)
    self:AddDelayRecycleRes(path, go, 4)
end

function FightUnitView:PlayEffect(skill, combat)
    -- 全屏特效
    if combat.EffectType == 2 then
        local path = combat.Bullet
        if path then
            local pos = self:GetEffectPosition(skill)
            if not pos then 
                return 
            end
            -- 特效的偏移量
            local offset = Vector3.zero
            if combat.Offset then
                local offset_x = self.camp == 0 and combat.Offset[1] or -combat.Offset[1]
                offset = Vector3.New(offset_x, combat.Offset[2], 0)
            end
            local go = self:loadAssetForScene(path, self.RootPanel.battleSceneSkillTransform)

            -- 检测特效旋转
            if self:CheckRotate(go, combat.Orientation) then
                offset = -offset
            end
            go.transform.localScale = self.camp == 0 and Vector3.one or Vector3.New(-1, 1, 1)
            go.transform.localPosition = pos + offset
            go:SetActive(true)
            self:AddDelayRecycleRes(path, go, 10)

                
            PlayUIAnims(go, function() end)

            local enemyGo = Util.GetGameObject(go, "enemy")
            if enemyGo then
                enemyGo:SetActive(self.camp == 1)
            end
            local mineGo = Util.GetGameObject(go, "mine")
            if mineGo then
                mineGo:SetActive(self.camp == 0)
            end
            
            if self.camp == 0 then

            else

            end
            
           
            if combat.SkillSound then
                local soundidx = math.random(1, #combat.SkillSound)
                -- LogError("combat.SkillSound:"..combat.SkillSound[soundidx])
                SoundManager.PlayBattleSound(combat.SkillSound[soundidx])
            end

            if combat.SkillNameVoice then
                -- LogError("combat.SkillNameVoice:"..combat.SkillNameVoice)
                SoundManager.PlaySound(combat.SkillNameVoice)
            end 
        end
    elseif combat.EffectType == 4 then
        local path = combat.Bullet
        if path then
            local targets = skill:GetDirectTargets()
            for _, target in ipairs(targets) do
                local tv = self.RootPanel.GetRoleView(target)
                if tv then
                    local offset = combat.Offset and Vector3.New(combat.Offset[1], combat.Offset[2], 0) or Vector3.zero
                    local go = loadAsset(path, self.RootPanel.skillEffectRoot:GetComponent("Canvas").sortingOrder)
                    go.transform:SetParent(tv.GameObject.transform.parent)
                    go.transform.localScale = Vector3.one
                    go.transform.localPosition = Vector3.zero + offset
                    -- go.transform.anchoredPosition = offset
                    go.transform:SetParent(self.RootPanel.skillEffectRoot.transform)
                    go:SetActive(true)
                    self:AddDelayRecycleRes(path, go, 5)

                    PlayUIAnims(go, function() end)

                    local enemyGo = Util.GetGameObject(go, "enemy")
                    if enemyGo then
                        enemyGo:SetActive(self.camp == 1)
                    end
                    local mineGo = Util.GetGameObject(go, "mine")
                    if mineGo then
                        mineGo:SetActive(self.camp == 0)
                    end
                end
            end
            -- LogError("combat.SkillSound:"..combat.SkillSound)
            if combat.SkillSound then
                local soundidx = math.random(1, #combat.SkillSound)
                SoundManager.PlayBattleSound(combat.SkillSound[soundidx])
            end
            if combat.SkillNameVoice then
                -- LogError("combat.SkillNameVoice:"..combat.SkillNameVoice)
                SoundManager.PlaySound(combat.SkillNameVoice)
            end 
        end
    else
        LogError("Unit EffectType unexist")
    end
    
end

function FightUnitView:LineEffect(skill, combat)

    if not skill then
        return
    end
    if not combat then
        return
    end

    local targets = skill:GetDirectTargets()

    for _, target in ipairs(targets) do
        while true
        do
            if not self.RootPanel.GetRoleView(target) then
                break
            end

            self:BulletFly(target, combat)

            break
        end
    end
end

function FightUnitView:BulletFly(target, combat)
    local duration = combat.BulletTime / 1000
    local bulletEffect = combat.Bullet
    
    if not bulletEffect or bulletEffect == "" or duration == 0 then
        
        return
    end

    local endV3 = self.RootPanel.GetRoleView(target).GameObject.transform.position

    local go = loadAsset(bulletEffect, self.RootPanel.skillEffectRoot:GetComponent("Canvas").sortingOrder)
    go.transform:SetParent(self.RootPanel.skillEffectRoot.transform)
    go.transform.localScale = Vector3.one
    go.transform.position = self.GameObject.transform.position

    Util.ClearTrailRender(go)
    go:SetActive(true)

    local startV3 = go.transform.position


    local startV2 = Vector2.New(0, 0)
    local endV2 = Vector2.New(1, 1)
    --飞行子弹轨迹
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
            self:AddDelayRecycleRes(bulletEffect, go, combat.ReturnTime / 1000)
        end
    )
end

function FightUnitView:CloseUpShow(skill, combat, func)
    local go = loadAsset(combat.Closeup, self.RootPanel.skillEffectRoot:GetComponent("Canvas").sortingOrder)
    go.transform:SetParent(self.RootPanel.CloseUpNode.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition = Vector3.zero
    go:SetActive(true)
    Util.SetParticleSortLayer(go, self.RootPanel.skillEffectRoot:GetComponent("Canvas").sortingOrder)

    local mine = Util.GetGameObject(go, "mine")
    local enemy = Util.GetGameObject(go, "enemy")
    local closeupGo
    if self.camp == 0 then
        mine:SetActive(true)
        enemy:SetActive(false)
        closeupGo = mine
    else
        mine:SetActive(false)
        enemy:SetActive(true)
        closeupGo = enemy
    end
    self:AddDelayRecycleRes(combat.Closeup, go, combat.CloseupDuration / 1000 + 2)
    self:DelayFunc(combat.CloseupDuration / 1000, function()
        if func then
            func()
        end
    end)

    if combat.CloseupSound then
        SoundManager.PlayBattleSound(combat.CloseupSound)
    end
    
end

function FightUnitView:GetEffectPosition(skill)
    local ret = nil

    local chooseId = skill.effectList.buffer[1].chooseId
    local chooseType = math.floor(chooseId / 100000)
    local chooseLimit = math.floor(chooseId / 10000) % 10
    local targets = skill:GetDirectTargets()

    local targetCamp = targets[1].camp
    local targetPos = targets[1].position

    local invert = targetCamp == 0 and 1 or -1
    
    
    -- 0全体
    -- 1前排
    -- 2后排
    -- 3对列
    -- 4前2排
    -- 5后2排
    -- 6全体,优先4职业
    -- 7人数最多一列
    -- 8除自己外
    -- 9全体,优先2职业
    if chooseLimit == 0 or chooseLimit == 6 or chooseLimit == 8 or chooseLimit == 9 then
        if chooseType == 4 then
            ret = FightCampLPToSkillRoot[targetCamp][targetPos]
        else
            ret = FightCampLPToSkillRoot[targetCamp][5]
        end
    elseif chooseLimit == 1 or chooseLimit == 2 then
        if targetPos <= 3 then
            ret = FightCampLPToSkillRoot[targetCamp][2]
        else
            ret = FightCampLPToSkillRoot[targetCamp][8]
        end
    elseif chooseLimit == 3 or chooseLimit == 7 then
        local col = (targetPos - 1) % 3 + 1
        ret = FightCampLPToSkillRoot[targetCamp][col]
    elseif chooseLimit == 4 then
        ret = FightCampLPToSkillRoot[targetCamp][2]
    elseif chooseLimit == 5 then
        ret = FightCampLPToSkillRoot[targetCamp][5]
    end
    
    return ret
end

--所有需要延迟回收的资源走该接口，当回调执行前界面已被销毁时，不会报错
function FightUnitView:AddDelayRecycleRes(path, go, delayTime, delayFunc, delType, beforeFunc)
    if not self.delayRecycleList[path] then
        self.delayRecycleList[path] = {}
    end
    local delType = delType
    table.insert(self.delayRecycleList[path], go)
    Timer.New(
        function()
            if not self.delayRecycleList[path] then
                return
            end
            if beforeFunc then
                beforeFunc()
            end
            for i = 1, #self.delayRecycleList[path] do
                if self.delayRecycleList[path][i] == go then
                    
                    
                    if delType == PoolManager.AssetTypeGo.GameObjectFrame then
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

function FightUnitView:DelayFunc(time, func)
    if not self._DelayFuncList then
        self._DelayFuncList = {}
    end
    local timer
    timer =
        Timer.New(
        function()
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

function FightUnitView:ClearDelayFunc(t)
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
--
function FightUnitView:LoopFunc(time, count, func)
    if count <= 0 then

        return
    end
    if not self._LoopFuncList then
        self._LoopFuncList = {}
    end
    local timer = nil
    local ctr = 0
    timer =
        Timer.New(
        function()
            if func then
                func()
            end
            ctr = ctr + 1
            if ctr >= count then
                self:ClearDelayFunc(timer)
            end
        end,
        time,
        count
    )
    timer:Start()
    table.insert(self._LoopFuncList, timer)
end

function FightUnitView:ClearLoopFunc(t)
    if not self._LoopFuncList then
        return
    end
    if t then
        local rIndex
        for index, timer in ipairs(self._LoopFuncList) do
            if timer == t then
                rIndex = index
                break
            end
        end
        if rIndex then
            self._LoopFuncList[rIndex]:Stop()
            table.remove(self._LoopFuncList, rIndex)
        end
    else
        for _, timer in ipairs(self._LoopFuncList) do
            timer:Stop()
        end
        self._LoopFuncList = {}
    end
end

function FightUnitView:OnSortingOrderChange(battleSorting)
    -- if self.camp == 0 then
    --     self:ChangeCardSorting(battleSorting + self.role.position)
    --     -- self.GameObject:GetComponent("Canvas").sortingOrder = battleSorting + self.role.position
    -- end
    -- Util.AddParticleSortLayer(self.effect_rage, sortingOrder - self.oSortingOrder)
end

function FightUnitView:Update()
end

function FightUnitView:ResetAnim()
    local pt
    local rotate
    if self.unit.type == FightUnitType.UnitSupport then
        pt = Vector3.New(-131, 0, 0)
        rotate = Vector3.New(0, 0, 5)
    elseif self.unit.type == FightUnitType.UnitAdjutant then
        pt = Vector3.New(-242.8, 0, 0)
        rotate = Vector3.New(0, 0, 5)
    elseif self.unit.type == FightUnitType.UnitAircraftCarrier then
        pt = Vector3.New(-346, 0, 0)
        rotate = Vector3.New(0, 0, 10)
    end

    self.GameObject.transform.parent.parent:GetComponent("Animator").enabled = false
    self.GameObject.transform.parent.transform.localScale = Vector3.New(0.73, 0.73, 0.73)
    self.GameObject.transform.parent.transform.localPosition = pt
    self.GameObject.transform.parent.transform.localEulerAngles = rotate
    self.GameObject.transform.parent.transform.anchorMin = Vector2.New(0.5, 0.5)
    self.GameObject.transform.parent.transform.anchorMax = Vector2.New(0.5, 0.5)
end

function FightUnitView:Dispose()
    -- 清空所有延迟方法
    self:ClearDelayFunc()
    self:ClearLoopFunc()
    -- self.GameObject.transform.parent.localScale = Vector3.one

    --立即回收延迟列表上的资源
    for k, v in pairs(self.delayRecycleList) do
        for i=1, #v do
            poolManager:UnLoadAsset(k, v[i], PoolManager.AssetType.GameObject)
        end
        self.delayRecycleList[k] = nil
    end


    -- poolManager:UnLoadFrame(self.livePath, self.RoleLiveGO)

    BattlePool.RecycleItem(self.GameObject, BATTLE_POOL_TYPE.UNIT_VIEW)
end

-- 检测特效旋转
function FightUnitView:CheckRotate(go, orientation)
    -- 判断是否旋转
    if go == nil or orientation == nil then
        -- body
        return false
    end
    local isR = orientation[1] and orientation[1][1] or 0
    local rt = orientation[2]
    rt = rt and Vector3.New(rt[1], rt[2], rt[3]) or Vector3.zero
    if (self.camp == 0 and isR == 1)
    or (self.camp == 1 and isR == 2) then
        go.transform.localRotation = rt
        return true
    end
    go.transform.localRotation = Vector3.zero
end

--播放守护PV 复制于RoleView并且去掉RoleLiveGo的移动动画,调整camp
function FightUnitView:PlayPV_UnitSupport(combat, skill, func)
    --施法目标
    local targets = skill:GetDirectTargets()

    local texiao = "cn2-x1_shouhu_xiaoshi"
    local texiaoTime = 0.4 --隐藏我方单位延迟
    local texiaoTime2 = 0.7 --播放PV延迟

    self.RootPanel.SetRoleActiveAndDoSomething(self.role, combat.HideActor, false, targets, function (roleview, active)
        self:DelayFunc(texiaoTime,function ()
            roleview.RoleLiveGO:SetActive(active)
            if roleview.GameObject and not IsNull(roleview.GameObject) then
                roleview.GameObject:SetActive(active)
            end
        end)

        if not active and roleview.camp == self.camp then
            local go = self:loadAssetForScene(texiao, self.RootPanel.battleSceneSkillTransform)
            go.transform.position = roleview.RoleLiveGO.transform.position
            go:SetActive(true)
            self:AddDelayRecycleRes(texiao, go, 4)
        end
    end)

    self:DelayFunc(texiaoTime2,function ()
        --播放PV
        self:PlayPVPrefab_UnitSupport(combat.PV, combat.PVDuration, self.camp == 0)
        --播放声音
        -- LogError("combat.SkillSound 3:"..combat.SkillSound)
        if combat.SkillNameVoice then
            -- LogError("combat.SkillNameVoice:"..combat.SkillNameVoice)
            SoundManager.PlaySound(combat.SkillNameVoice)
        end 
        if combat.SkillSound then
            local soundidx = math.random(1, #combat.SkillSound)
            SoundManager.PlaySound(combat.SkillSound[soundidx])
        end

        --隐藏血条
        self.RootPanel.EnemyPanel:SetActive(false)
        self.RootPanel.MinePanel:SetActive(false)

        self:DelayFunc(
            combat.PVDuration / 1000,
            function()
                self.RootPanel.ResetHighLightWithTargets(true, targets, self)
                self.RootPanel.SetRoleActive(self.role, combat.HideActor, true, targets)

                --显示血条
                self.RootPanel.EnemyPanel:SetActive(true)
                self.RootPanel.MinePanel:SetActive(true)

                self.RootPanel.UpdateAllRoleHPPos()

                --所有人显示
                self.RootPanel.SetRoleActive(self.role, 999, true, targets)

                if func then
                    func()
                end
        end)
    end)
end

--播放先驱PV 复制于RoleView并且去掉RoleLiveGo的移动动画,调整camp
function FightUnitView:PlayPV_UnitAdjutant(combat, skill, func)
    --施法目标
    local targets = skill:GetDirectTargets()

    local texiao = "cn2-x1_xianquPublic"
    local texiaoTime2 = 1 --播放PV延迟

    --播放特效
    local teamPos = self.camp == 0 and self.RootPanel.Left or self.RootPanel.Right
    local targetPos = teamPos.transform.localPosition + FightCampTargetLocalPosition[self.camp][5]
    local go = self:loadAssetForScene(texiao, self.RootPanel.battleSceneSkillTransform)
    go.transform.position = targetPos
    go:SetActive(true)
    self:AddDelayRecycleRes(texiao, go, 4)

    --播放声音   
    if combat.SkillSound then
        local soundidx = math.random(1, #combat.SkillSound)
        -- LogError("combat.SkillSound  4:"..combat.SkillSound[soundidx])
        SoundManager.PlaySound(combat.SkillSound[soundidx])
    end
    if combat.SkillNameVoice then
        -- LogError("combat.SkillNameVoice:"..combat.SkillNameVoice)
        SoundManager.PlaySound(combat.SkillNameVoice)
    end 

    self:DelayFunc(texiaoTime2,function ()
        --播放PV
        self:PlayPVPrefab_UnitAdjutant(combat.PV, combat.PVDuration)

        --隐藏血条
        self.RootPanel.EnemyPanel:SetActive(false)
        self.RootPanel.MinePanel:SetActive(false)

        self:DelayFunc(
            combat.PVDuration / 1000,
            function()
                self.RootPanel.ResetHighLightWithTargets(true, targets, self)
                self.RootPanel.SetRoleActive(self.role, combat.HideActor, true, targets)

                --显示血条
                self.RootPanel.EnemyPanel:SetActive(true)
                self.RootPanel.MinePanel:SetActive(true)

                self.RootPanel.UpdateAllRoleHPPos()

                --所有人显示
                self.RootPanel.SetRoleActive(self.role, 999, true, targets)

                if func then
                    func()
                end
        end)
    end)
end

--播放守护PV的预制
--在PV节点下
--区分左右
function FightUnitView:PlayPVPrefab_UnitSupport(pvPath, pvDuration, isLeft)
    local go = self:loadAssetForScene(pvPath, self.RootPanel.pvPos)

    local pvName
    if isLeft then
        pvName = "Left"
    else
        pvName = "Right"
    end
    
    if isLeft then
        local pvGo = Util.GetGameObject(go, "Left")
        local pvGo_Right = Util.GetGameObject(go, "Right")
        --显示自动播放粒子特效
        pvGo:SetActive(true)
        if pvGo_Right then
           pvGo_Right:SetActive(false)
        end
    else
        local pvGo = Util.GetGameObject(go, "Right")
        local pvGo_left = Util.GetGameObject(go, "Left")
        --显示自动播放粒子特效
        pvGo:SetActive(true)
        if pvGo_left then
           pvGo_left:SetActive(false)
        end
    end

    --显示自动播放粒子特效
    -- pvGo:SetActive(true)

    --播放特效里的动画
    local sg = Util.GetComponentInChildren(go, "spine-unity", "Spine.Unity.SkeletonAnimation", true)
    if sg ~= nil then
        local animationName = sg.AnimationName
        sg.Skeleton:SetToSetupPose()
        sg.AnimationState:ClearEvent_Complete()
        sg.AnimationState:ClearTracks() -- 清除上一个动画的影响（修复概率攻击动画播放错误的问题）
        sg.AnimationState:SetAnimation(0, animationName, false)
    end

    --设置相机
    local effectCamera = go:GetComponent("EffectCamera")
    local cameraParent = nil
    if effectCamera then
        if isLeft then
            if effectCamera.effectCamera_left then
                cameraParent = effectCamera.effectCamera_left
            else
                cameraParent = effectCamera.effectCamera
            end
        else
            if effectCamera.effectCamera_right then
                cameraParent = effectCamera.effectCamera_right
            else
                cameraParent = effectCamera.effectCamera
            end
        end
    end

    if cameraParent then
        self.RootPanel:SetCameraParent(cameraParent)
    end

    self:AddDelayRecycleRes(pvPath, go, pvDuration / 1000, nil, nil, function()
        if cameraParent then
            self.RootPanel:SetCameraParent(self.RootPanel.camera3DPos)
        end
    end)
end

--播放先驱PV的预制
--在Closeup节点下
--不区分左右
function FightUnitView:PlayPVPrefab_UnitAdjutant(pvPath, pvDuration)
    local go = self:loadAssetForScene(pvPath, self.RootPanel.closeupPos)

    --播放特效里的动画
    local sg = Util.GetComponentInChildren(go, "spine-unity", "Spine.Unity.SkeletonAnimation", true)
    if sg ~= nil then
        if sg.AnimationName then
            local animationName = sg.AnimationName
            sg.Skeleton:SetToSetupPose()
            sg.AnimationState:ClearEvent_Complete()
            sg.AnimationState:ClearTracks() -- 清除上一个动画的影响（修复概率攻击动画播放错误的问题）
            sg.AnimationState:SetAnimation(0, animationName, false)
        end
    end

    --设置相机
    local effectCamera = go:GetComponent("EffectCamera")
    local cameraParent = nil
    if effectCamera then
        cameraParent = effectCamera.effectCamera
    end

    if cameraParent then
        self.RootPanel:SetCameraParent(cameraParent)
    end

    self:AddDelayRecycleRes(pvPath, go, pvDuration / 1000, nil, nil, function()
        if cameraParent then
            self.RootPanel:SetCameraParent(self.RootPanel.camera3DPos)
        end
    end)
end