require("Modules.Battle.Logic.Misc.BattleDefine")
local FEAConfig = require("Modules/Battle/Config/FightEffectAudioConfig")
RoleView = {}
RoleView.__index = RoleView

local MonsterViewConfig = ConfigManager.GetConfig(ConfigName.MonsterViewConfig)
local MonsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local RoleConfig = ConfigManager.GetConfig(ConfigName.RoleConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local BuffEffectConfig = ConfigManager.GetConfig(ConfigName.BuffEffectConfig)
local TurretEffectRotationConfig = ConfigManager.GetConfig(ConfigName.TurretEffectRotationConfig)
local Bezier = require("Base.Bezier")
local healEffect = "n1_eff_heal"
local rageEffect = "s_jieling_hs_3006_skeff_casting_buff_nuqi"
local cdChangedEffect = "c_jz_0002_skeff_slidesk_buff"
local floatingEffect = "FloatingText"
local buffFloatingEffect = "BuffFloatingText"
local skillFloatingEffect = "SkillFloatingText"
local langSpace=""

--英雄动画脚本名字
local SpineComponentName = "SkeletonAnimation"
local leaderIcon = {3091,3092}

local loadAsset = function(path, battleSorting, notPlaySound)
    
    local go = poolManager:LoadAsset(path, PoolManager.AssetType.GameObject)
    if go == nil then
        LogError("### res not found:" .. path)
        -- go = poolManager:LoadAsset("TestImg", PoolManager.AssetType.GameObject)
    end
    local layer = tonumber(go.name) or 0
    battleSorting = battleSorting or BattleManager.GetBattleSorting()
    Util.AddParticleSortLayer(go, battleSorting - layer)
    go.name = tostring(battleSorting)
    --- 播放音效
    -- if not notPlaySound then
    --     local audioData = FEAConfig.GetAudioData(path)
    --     if audioData then
    --         SoundManager.PlaySound(audioData.name)
    --     end
    -- end
    return go
end

---加载战斗场景里使用的资源
function RoleView:loadAssetForScene(path, parent)
    if path == nil then
        LogError("path = nil!!!"..path)
    end

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

function RoleView:initHPOffset(position, size)
    local posRow = (position - 1) % 3

    if posRow == 2 then -- 摄像机最近的
        self.hpScale = 1
        self.hpOffset = Vector3.New(0, 80, 0)
    elseif posRow == 1 then
        self.hpScale = 0.9
        self.hpOffset = Vector3.New(-10, 80, 0)
    elseif posRow == 0 then
        self.hpScale = 0.8
        self.hpOffset = Vector3.New(-5, 80, 0)
    end

    --中间列高一点
    if position == 4 then
        self.hpOffset.y = self.hpOffset.y + 4
    elseif position == 5  then
        self.hpOffset.y = self.hpOffset.y + 8
    elseif position == 6 then
        self.hpOffset.y = self.hpOffset.y + 10
    end

    local coefficient = size > 2.3 and 0.9 or 1 --为了修正放大太多就偏移太高
    self.hpOffset.y = self.hpOffset.y * size * size * coefficient --血条跟着角色大小偏移,乘方没理由的,这样看起来合适
end

---创建一个英雄
---@param go table 血条
---@param role table 英雄数据
---@param position string 英雄所在位置
---@param root table 战场
---@return table
function RoleView.New(go, role, position, root, spineLivePos)
    local instance = {}
    setmetatable(instance, RoleView)
    if role.roleData.size == nil then role.roleData.size = 1 end
    instance:initHPOffset(role.position, role.roleData.size)

    instance.battleSceneLogic = root.battleSceneLogic
    instance.battleScene = root.battleScene

    instance.RootPanel = root
    instance.GameObject = go
    instance.role = role
    instance.camp = role.camp

    instance.turretCurFrame = BattleTankFrame.IdleFrame

    instance.BuffList = {}

    instance.buffRoot = Util.GetGameObject(go, "buff")
    instance.BuffIconList = {}
    instance.BuffEffectList = {}

    instance.delayRecycleList = {}

    role.Event:AddEvent(BattleEventName.SkillCast, instance.OnSkillCast, instance)
    role.Event:AddEvent(BattleEventName.SkillFireOnce, instance.SkillFireOnce, instance)    --< once炮击
    role.Event:AddEvent(BattleEventName.SkillFireAll, instance.SkillFireAll, instance)    --< 技能单次所有目标
    role.Event:AddEvent(BattleEventName.SkillCastEnd, instance.SkillCastEnd, instance)    --< once炮击
    BattleLogic.Event:AddEvent(BattleEventName.BattleEnd, instance.OnEnd, instance)
    BattleLogic.Event:AddEvent(BattleEventName.BattleOrderChange, instance.OnEnd, instance)

    role.Event:AddEvent(BattleEventName.BeHitMiss, instance.OnBeHitMiss, instance)
    role.Event:AddEvent(BattleEventName.RoleBeDamaged, instance.OnDamaged, instance)
    role.Event:AddEvent(BattleEventName.RoleBeTreated, instance.OnTreated, instance)
    role.Event:AddEvent(BattleEventName.RoleBeHealed, instance.OnHealed, instance)
    role.Event:AddEvent(BattleEventName.RoleDead, instance.OnDead, instance)
    role.Event:AddEvent(BattleEventName.RoleRealDead, instance.OnRealDead, instance)
    role.Event:AddEvent(BattleEventName.RoleCDChanged, instance.OnRoleCDChanged, instance)
    -- role.Event:AddEvent(BattleEventName.RoleViewBullet, instance.RoleViewBullet, instance)
    -- role.Event:AddEvent(BattleEventName.RoleRageChange, instance.RoleRageChange, instance)
    role.Event:AddEvent(BattleEventName.RoleRelive, instance.onRoleRelive, instance)
    role.Event:AddEvent(BattleEventName.AOE, instance.OnAOE, instance)
    role.Event:AddEvent(BattleEventName.BeSeckill, instance.onBeSecKill, instance)

    role.Event:AddEvent(BattleEventName.BuffStart, instance.OnBuffStart, instance)
    role.Event:AddEvent(BattleEventName.BuffCover, instance.OnBuffCover, instance)
    role.Event:AddEvent(BattleEventName.BuffTrigger, instance.OnBuffTrigger, instance)
    role.Event:AddEvent(BattleEventName.BuffEnd, instance.OnBuffEnd, instance)
    role.Event:AddEvent(BattleEventName.BuffDodge, instance.OnBuffDodge, instance)
    role.Event:AddEvent(BattleEventName.BuffRoundChange, instance.OnBuffRoundChange, instance)
    role.Event:AddEvent(BattleEventName.BuffDurationChange, instance.OnBuffRoundChange, instance)

    role.Event:AddEvent(BattleEventName.ShildTrigger, instance.OnShieldTrigger, instance)
    role.Event:AddEvent(BattleEventName.SkillTextFloating, instance.TextSkillFloating, instance)

    role.Event:AddEvent(BattleEventName.ImmuneTrigger, instance.OnImmuneTrigger, instance)
    role.Event:AddEvent(BattleEventName.ShildReduce, instance.OnShildReduce, instance)

    instance.hpGo = Util.GetGameObject(go, "hp"):GetComponent("MeshRenderer")
    instance.materialPropertyBlock = MaterialPropertyBlock.New()
    --等级
    local lv = role:GetRoleData(RoleDataName.Level)
    if lv < 10 then
        instance.materialPropertyBlock:SetFloat("_LV_length",1)
        instance.materialPropertyBlock:SetFloat("_LV",lv*100)
    elseif lv < 100 then
        instance.materialPropertyBlock:SetFloat("_LV_length",2)
        instance.materialPropertyBlock:SetFloat("_LV",lv*10)
    else
        instance.materialPropertyBlock:SetFloat("_LV_length",3)
        instance.materialPropertyBlock:SetFloat("_LV",lv)
    end

    --类型
    if not role.leader then
        instance.materialPropertyBlock:SetFloat("_Icon_set",role.roleData.element)
    end
    --血条
    instance.hpCache = instance.role:GetRoleData(RoleDataName.Hp) / instance.role:GetRoleData(RoleDataName.MaxHp)
    instance.materialPropertyBlock:SetFloat("_HP",instance.hpCache)
    --颜色
    instance.materialPropertyBlock:SetColor("_Color",Color.New(1, 1, 1, 1))
    instance.hpGo:SetPropertyBlock(instance.materialPropertyBlock)

    --instance.hpSlider = Util.GetGameObject(go, "hpProgress/hp"):GetComponent("Image")
    --instance.hpPassSlider = Util.GetGameObject(go, "hpProgress/hpPass"):GetComponent("Image")
    --instance.hpSlider.fillAmount = instance.hpCache
    --instance.hpPassSlider.fillAmount = instance.hpCache
    --instance.lvText = Util.GetGameObject(go, "lv/Text"):GetComponent("Text")
    instance.readingName = ""
    
    --我方主角 1 为女主 2 为男主 --目前为默认参数
    if role.roleData.roleId == 1 or role.roleData.roleId == 2 then 
        if NameManager.roleSex == ROLE_SEX.BOY then
            instance.livePath = "role_nanzhu"
        else
            instance.livePath = "role_nvzhu"
        end        
        instance.play_liveScale = RoleConfig[10001].play_liveScale --test
        instance.enemy_liveScale = RoleConfig[10001].enemy_liveScale --test
        instance.outOffset = RoleConfig[10001].enemy_offset --test
        instance.spAtkTime = 0 --RoleConfig[role.roleData.roleId].CastingSkills / 1000
        instance.atkSoundTime = 0.9--RoleConfig[role.roleData.roleId].CastingAudio / 1000
        instance.attackSound = "Audio_c_fx_00028_attack_01" --RoleConfig[role.roleData.roleId].sond

        instance.readingName = "tester"
    else        
        if role.roleData.roleId > 10000 then
            instance.livePath = GetResourcePath(HeroConfig[role.roleData.roleId].Live)
            instance.play_liveScale = RoleConfig[role.roleData.roleId].play_liveScale
            instance.enemy_liveScale = RoleConfig[role.roleData.roleId].enemy_liveScale
            instance.outOffset = RoleConfig[role.roleData.roleId].enemy_offset
            instance.spAtkTime = RoleConfig[role.roleData.roleId].CastingSkills / 1000
            instance.atkSoundTime = RoleConfig[role.roleData.roleId].CastingAudio / 1000
            instance.attackSound = RoleConfig[role.roleData.roleId].sond

            if role.roleData.monsterId then --非战斗数据，仅用于显示怪物名称
                instance.readingName = GetLanguageStrById(MonsterConfig[role.roleData.monsterId].ReadingName)
            else
                instance.readingName = GetLanguageStrById(HeroConfig[role.roleData.roleId].ReadingName)
            end
        else
            instance.livePath = GetResourcePath(MonsterViewConfig[role.roleData.roleId].Live)
            instance.enemy_liveScale = MonsterViewConfig[role.roleData.roleId].enemy_liveScale
            instance.spAtkTime = MonsterViewConfig[role.roleData.roleId].CastingSkills / 1000
            instance.atkSoundTime = MonsterViewConfig[role.roleData.roleId].CastingAudio / 1000
            instance.attackSound = MonsterViewConfig[role.roleData.roleId].sond

            if role.roleData.monsterId then --非战斗数据，仅用于显示怪物名称
                instance.readingName = GetLanguageStrById(MonsterConfig[role.roleData.monsterId].ReadingName)
            else
                instance.readingName = GetLanguageStrById(HeroConfig[role.roleData.roleId].ReadingName)
            end
        end
    end
    --Util.GetGameObject(go, "lv/Text"):GetComponent("Text").text = role:GetRoleData(RoleDataName.Level)
    --Util.GetGameObject(go, "Pro/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum2(role.roleData.element))

    --↓↓↓↓↓↓改为加载动画
    instance.RoleLiveGO = poolManager:LoadSpine(instance.livePath, spineLivePos.transform, Vector3.one, Vector3.zero)
    instance.RoleLiveGO:SetLayer(instance.RootPanel.battleSceneLayer)
    instance.RoleLiveGOGraphic = instance.RoleLiveGO:GetComponent(SpineComponentName)
    RoleView:ResetSpineComponent(instance.RoleLiveGOGraphic)
    instance.RoleLiveGO:SetActive(true)
    local size = role.roleData.size and role.roleData.size or 1
    instance.RoleLiveGO.transform.localScale = Vector3.New(size * (role.camp == 0 and 1 or -1) * instance.RoleLiveGO.transform.localScale.x, size * instance.RoleLiveGO.transform.localScale.y, instance.RoleLiveGO.transform.localScale.z)

    --↑↑↑↑↑

    instance.beHit = Util.GetGameObject(instance.RoleLiveGOTran, "size/beHit")
    -- Util.ClearChild(instance.Eff_ani.transform)

    instance.rageCache = nil



    if IsOpenBattleDebug then
        local URoleProperty = go:GetComponent(typeof(RoleProperty))
        if not URoleProperty then
            URoleProperty = go:AddComponent(typeof(RoleProperty))
        end
        instance.URoleProperty = URoleProperty
        instance.URoleProperty.uid = role.uid
        role.data:Foreach(
            function(name, value)
                --测试工具屏蔽                
                -- instance.URoleProperty:AddProperty(name, value)
            end
        )
    end

    instance.LastBuffFloatingTime = Time.realtimeSinceStartup
    instance.BuffFloatingCount = 0

    instance.LastBuffTextTime = Time.realtimeSinceStartup
    instance.BuffTextCount = 0

    instance.LastFloatingTime = Time.realtimeSinceStartup
    instance.FloatingCount = 0

    instance.LastSkillTextTime = Time.realtimeSinceStartup
    instance.SkillTextCount = 0

    -- if role.camp == 0 then
    --     local battleSorting = BattleManager.GetBattleSorting()
    --     instance:ChangeCardSorting(battleSorting + position)
    --     -- local c = go:GetComponent("Canvas")
    --     -- c.sortingOrder = battleSorting + position
    -- end


    --instance:HpComponentHide(true)

    instance.DoColor_Spine_Tweener = nil

    --更新血条缩放
    instance.GameObject.transform.localScale = Vector3.one * instance.hpScale

    --初始化角色的icon
    if instance.role.leader then 
        local unlockSlot = instance.role.leaderUnlockSkillSize
        instance.RootPanel.root:InitIcons_Skill(instance.role.skillArray,nil,instance.role.camp,unlockSlot)
        -- LogError("InitIcons_Skill")
    end
    if GetCurLanguage() == 10101 then
       floatingEffect="FloatingText_en"
       langSpace=" "
    end
    return instance
end

--所有需要延迟回收的资源走该接口，当回调执行前界面已被销毁时，不会报错
function RoleView:AddDelayRecycleRes(path, go, delayTime, delayFunc, delType, beforeFunc)
    if not self.delayRecycleList[path] then
        self.delayRecycleList[path] = {}
    end
    local delType = delType
    table.insert(self.delayRecycleList[path], {node = go, type = delType})
    if not self.kkkk then
        self.kkkk = {}
    end
    table.insert(self.kkkk, go)
    Timer.New(
        function()
            if not self.delayRecycleList[path] then
                return
            end
            if beforeFunc then
                beforeFunc()
            end
            for i = 1, #self.delayRecycleList[path] do
                if not IsNull(go) and self.delayRecycleList[path][i].node == go then
                    
                    if self.delayRecycleList[path][i].type == PoolManager.AssetTypeGo.GameObjectFrame then
                        poolManager:UnLoadSpine(path, go)
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

function RoleView:DelayFunc(time, func)
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
function RoleView:ClearDelayFunc(t)
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
function RoleView:LoopFunc(time, count, func)
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
function RoleView:ClearLoopFunc(t)
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

local TextFloatingColor = {
    Blue = 1,
    Red = 2,
    Purple = 3,
    Green = 4
}
function RoleView:TextBuffFloating(type, text)
    -- if true then
    --     return
    -- end
    if type == 0 then type = 1 end
    -- LogError(string.format("type: %s text: %s",tostring(type),text))
    local color
    if type == 1 then --蓝色 增益 效果抵抗
        color = Color.New(105, 227, 255, 255) / 255
    elseif type == 2 then --红色 减益
        color = Color.New(243, 82, 77, 255) / 255
    elseif type == 3 then --紫色 dot
        color = Color.New(222, 120, 255, 255) / 255
    elseif type == 4 then --绿色 hot
        color = Color.New(93, 231, 135, 255) / 255
    end

    local go = loadAsset(buffFloatingEffect)
    local baseOffset = Vector2.New(0, 0)
    -- if self.camp == 0 then
    go.transform:SetParent(self.RootPanel.skillEffectRoot.transform)
    --     baseY = 60
    -- else
    --     go.transform:SetParent(self.GameObject.transform)
    --     baseY = 200
    -- end
    go.transform.localScale = Vector3.one
    go.transform.position = self.GameObject.transform.position
    go:SetActive(true)

    if Time.realtimeSinceStartup - self.LastBuffTextTime < BattleLogic.GameDeltaTime * 2 then
        self.BuffTextCount = self.BuffTextCount + 1
    else
        self.BuffTextCount = 0
    end
    self.LastBuffTextTime = Time.realtimeSinceStartup
    local v2 = go:GetComponent("RectTransform").anchoredPosition
    go:GetComponent("RectTransform").anchoredPosition = v2 + Vector2.New(0 + baseOffset.x, baseOffset.y + self.BuffTextCount * 60)

    local battleSorting = BattleManager.GetBattleSorting()
    Util.GetGameObject(go, "anim"):GetComponent("Canvas").sortingOrder = battleSorting + 80
    Util.GetGameObject(go, "anim/text"):SetActive(true)
    Util.GetGameObject(go, "anim/text"):GetComponent("Text").text = text
    if color then
        Util.GetGameObject(go, "anim/text"):GetComponent("Text").color = color
    end
    
    Util.GetGameObject(go, "anim/grid"):SetActive(false)

    self:AddDelayRecycleRes(buffFloatingEffect, go, 1.3)
end

--
function RoleView:ImageBuffFloating(textImg, numImg)
    local go = loadAsset(buffFloatingEffect)
    go.transform:SetParent(self.RootPanel.skillEffectRoot.transform)
    go.transform.localScale = Vector3.one
    go.transform.position = self.GameObject.transform.position
    go:SetActive(true)

    if Time.realtimeSinceStartup - self.LastBuffTextTime < BattleLogic.GameDeltaTime then
        self.BuffTextCount = self.BuffTextCount + 1
    else
        self.BuffTextCount = 0
    end
    self.LastBuffTextTime = Time.realtimeSinceStartup
    local v2 = go:GetComponent("RectTransform").anchoredPosition
    local baseOffset = Vector2.New(0, 0)
    go:GetComponent("RectTransform").anchoredPosition = v2 + Vector2.New(0 + baseOffset.x, baseOffset.y + self.BuffTextCount * 60)

    local battleSorting = BattleManager.GetBattleSorting()
    Util.GetGameObject(go, "anim"):GetComponent("Canvas").sortingOrder = battleSorting + 200
    Util.GetGameObject(go, "anim/text"):SetActive(false)
    Util.GetGameObject(go, "anim/grid"):SetActive(true)

    local img1 = Util.GetGameObject(go, "anim/grid/Image1"):GetComponent("Image")
    local img2 = Util.GetGameObject(go, "anim/grid/Image2"):GetComponent("Image")

    if textImg then
        img1.gameObject:SetActive(true)
        img1.sprite = Util.LoadSprite(textImg)
        img1:SetNativeSize()
    else
        img1.gameObject:SetActive(false)
    end

    if numImg then
        img2.gameObject:SetActive(true)
        img2.sprite = Util.LoadSprite(numImg)
        img2:SetNativeSize()
    else
        img2.gameObject:SetActive(false)
    end

    self:AddDelayRecycleRes(buffFloatingEffect, go, 1.3)
end

--> 效果反推技能名显示用
function RoleView:TextSkillFloating(skill)
    if not skill then
        return
    end

    local color = Color.New(17, 255, 17, 255) / 255

    
    local skillConfig = G_SkillConfig[skill.id]
    local text = skillConfig.Name

    local go = loadAsset(skillFloatingEffect)

    --> go.transform:SetParent(self.RootPanel.transform)
    go.transform:SetParent(self.RootPanel.skillEffectRoot.transform)
    go.transform.localScale = Vector3.one
    go.transform.position = self.GameObject.transform.position
    go:SetActive(true)

    if Time.realtimeSinceStartup - self.LastSkillTextTime < BattleLogic.GameDeltaTime then
        self.SkillTextCount = self.SkillTextCount + 1
    else
        self.SkillTextCount = 0
    end
    self.LastSkillTextTime = Time.realtimeSinceStartup
    local v2 = go:GetComponent("RectTransform").anchoredPosition
    go:GetComponent("RectTransform").anchoredPosition = v2 + Vector2.New(0, self.SkillTextCount * 60)

    local battleSorting = BattleManager.GetBattleSorting()
    Util.GetGameObject(go, "anim"):GetComponent("Canvas").sortingOrder = battleSorting + 80
    Util.GetGameObject(go, "anim/text"):SetActive(true)
    Util.GetGameObject(go, "anim/text"):GetComponent("Text").text = GetLanguageStrById(text)
    Util.GetGameObject(go, "anim/text"):GetComponent("Text").color = color

    self:AddDelayRecycleRes(skillFloatingEffect, go, 1.3)
end

--
local ArtFloatingType = {
    CritDamage = 1, -- 暴击
    Damage = 2,
    Treat = 3,
    FireDamage = 4,
    PoisonDamage = 5,
    ShieldDef = 6
}
local ArtFloatingAnim = {
    [1] = "Crit_Attack_Float",
    [2] = "Normal_Attack_Float",
    [3] = "floatingTextAnim",
    [4] = "floatingTextAnim",
    [5] = "floatingTextAnim",
    [6] = "Crit_Attack_Float",
}
--角色受到的暴击伤害(无论什么类型)   - 红色字体 (字符顺序：40-49 ,0-9)(110, -)(111, +)(33, 暴击)(35, 灼烧)
--角色造成的点击技伤害              - 白色字体 (字符顺序：50-59 ,0-9)(112, -)(113, +)
--角色造成的滑动技伤害              - 黄色字体 (字符顺序：60-69 ,0-9)(114, -)(115, +)
--角色恢复量                       - 绿色字体 (字符顺序：70-79 ,0-9)(116, -)(117, +)
--角色造成的异妖技伤害              - 紫色字体 (字符顺序：80-89 ,0-9)(118, -)(119, +)(34, 中毒)
local ArtFloatingColor = {
    Red = 0,       --
    White = 1,     --
    Yellow = 2,    --
    Green = 3,    --
    Purple = 4,
    Poison = 5,
    Fire = 6,
    Shiled = 5
}
function RoleView:GetArtText(type, color, value, isForbear)
    local text = ""
    -- if type == ArtFloatingType.CritDamage then
    --     text = text .. string.char(33) -- 暴击文字
    --     text = text .. string.char((color * 2) + 110) -- 减号
    -- elseif type == ArtFloatingType.Damage then
    --     text = text .. string.char((color * 2) + 110) -- 减号
    -- elseif type == ArtFloatingType.Treat then
    --     text = text .. string.char((color * 2) + 111) -- 加号
    -- elseif type == ArtFloatingType.FireDamage then
    --     text = text .. string.char(35) -- 灼烧文字
    --     text = text .. string.char((color * 2) + 110) -- 减号
    -- elseif type == ArtFloatingType.PoisonDamage then
    --     text = text .. string.char(34) -- 中毒文字
    --     text = text .. string.char((color * 2) + 110) -- 减号
    -- end
    
    -- -- 数字
    -- local str = tostring(value)
    -- for i = 1, #str do
    --     text = text .. string.char((string.byte(str, i) - 48) + color * 10 + 40)
    -- end


    if type == ArtFloatingType.CritDamage then
        text = text .. string.char(98) -- 暴击文字
    elseif type == ArtFloatingType.ShieldDef then
        text = text .. string.char(120) -- 护盾
    elseif type == ArtFloatingType.Damage and isForbear then
        text = text .. string.char(107)
    end
    -- 数字
    local str = tostring(value)
    for i = 1, #str do
        text = text .. string.char(string.byte(str, i))
    end

    return text
end
function RoleView:ArtFloating(type, color, value, isForbear)
    local go = loadAsset(floatingEffect)
    -- if self.camp == 0 then
    go.transform:SetParent(self.RootPanel.skillEffectRoot.transform)
    -- else
    --     go.transform:SetParent(self.GameObject.transform)
    -- end
    if type == ArtFloatingType.ShieldDef then
        go.transform.localScale = Vector3.one * 0.65  
    else        
        go.transform.localScale = Vector3.one
    end
    go.transform.position = self.GameObject.transform.position
    go:SetActive(true)

    -- if Time.realtimeSinceStartup - self.LastFloatingTime < BattleLogic.GameDeltaTime then
    --     self.FloatingCount = self.FloatingCount + 1
    -- else
    --     self.FloatingCount = 0
    -- end
    -- self.LastFloatingTime = Time.realtimeSinceStartup
    local v2 = go:GetComponent("RectTransform").anchoredPosition
    local posRow = (self.role.position - 1) % 3

    if posRow == 2 then -- 摄像机最近的
        v2 = v2 + Vector2.New(0, 230)
    elseif posRow == 1 then
        v2 = v2 + Vector2.New(0, 200)
    elseif posRow == 0 then
        v2 = v2 + Vector2.New(0, 190)
    end
    local offset = Vector2.New(10, 40)
    -- local offsetW = Vector2.New(10, 0)
    go:GetComponent("RectTransform").anchoredPosition = v2

    if self.delayRecycleList[floatingEffect] then
        for k, v in ipairs(self.delayRecycleList[floatingEffect]) do
            local pt = v.node:GetComponent("RectTransform").anchoredPosition
            pt = pt + offset
            v.node:GetComponent("RectTransform").anchoredPosition = pt
        end
    end
    


    local text = self:GetArtText(type, color, value, isForbear)

    local colorArray = {[1] = "anim_Red", [2] = "anim_White", [3] = "anim_Yellow", [4] = "anim_Green",[5] = "anim_Blue",[6] = "anim_Blue"}
    for i = 1, #colorArray do
        local hideanim = Util.GetGameObject(go, colorArray[i])
        hideanim:SetActive(false)
    end
    if color + 1 > #colorArray then
        
        --return

        color = 1
    end
    local anim = Util.GetGameObject(go, colorArray[color + 1])
    anim:SetActive(true)


    anim:GetComponent("Text").text = text
    anim:GetComponent("Canvas").sortingOrder = BattleManager.GetBattleSorting() + 50
    anim:GetComponent("Animator"):Play(ArtFloatingAnim[type])
    self:AddDelayRecycleRes(floatingEffect, go, 2)
end

function RoleView:OnPointerClick(data)
    if self.role.IsDebug and self.role.skill then
        self.role.skill:Cast()
    end
    data:Use()
end

function RoleView:OnEndDrag(data)
    if self.role.IsDebug and self.role.superSkill then
        self.role.superSkill:Cast()
    end
    data:Use()
end

--
function RoleView:OnSortingOrderChange(battleSorting)
    -- if self.camp == 0 then
    --     self:ChangeCardSorting(battleSorting + self.role.position)
    --     -- self.GameObject:GetComponent("Canvas").sortingOrder = battleSorting + self.role.position
    -- end
    -- if self.delayRecycleList[floatingEffect] then
    --     for k, v in ipairs(self.delayRecycleList[floatingEffect]) do
    --         local colorArray = {[1] = "anim_Red", [2] = "anim_White", [3] = "anim_Yellow", [4] = "anim_Green"}
    --         for i = 1, #colorArray do
    --             local anim = Util.GetGameObject(v, colorArray[i])
    --             anim:GetComponent("Canvas").sortingOrder = battleSorting + 100
    --         end
    --     end
    -- end
    -- if self.delayRecycleList[buffFloatingEffect] then
    --     for k, v in ipairs(self.delayRecycleList[buffFloatingEffect]) do
    --         Util.GetGameObject(v, "anim"):GetComponent("Canvas").sortingOrder = battleSorting + 200
    --     end
    -- end
    -- if self.delayRecycleList[skillFloatingEffect] then
    --     for k, v in ipairs(self.delayRecycleList[skillFloatingEffect]) do
    --         Util.GetGameObject(v, "anim"):GetComponent("Canvas").sortingOrder = battleSorting + 200
    --     end
    -- end
    
end

function RoleView:ChangeEffectOrder()
    
    
end

function RoleView:GetSortingOrder()
    return self.GameObject.transform.parent:GetComponent("Canvas").sortingOrder
end

-- 改变卡牌层级
function RoleView:ChangeCardSorting(sortingOrder)
    if not self.oSortingOrder then
        self.oSortingOrder = BattleManager.GetBattleSorting()
    end
    self.GameObject:GetComponent("Canvas").sortingOrder = sortingOrder
    self.oSortingOrder = sortingOrder
end

function RoleView:Update_HPPos()
    if self.RootPanel== nil or self.RoleLiveGO == nil or self.GameObject == nil or IsNull(self.RootPanel.camera3D) then
        return
    end
    --更新血条位置
    self.GameObject.transform.localPosition = Util.WorldToLocalInRect(self.RootPanel.camera3D, self.RoleLiveGO.transform.parent.position, self.RootPanel.cameraUI, self.GameObject.transform.parent:GetComponent("RectTransform")) + self.hpOffset
end

function RoleView:Update()
    -- if not self.isPlay then
    --     return
    -- end
    if self.role:IsRealDead()  then
        return
    end

    --更新血条
    local hp = self.role:GetRoleData(RoleDataName.Hp) / self.role:GetRoleData(RoleDataName.MaxHp)
    if self.hpCache ~= hp then
        local f1 = self.hpCache
        local f2 = hp
        if f1 > f2 then
            if self.hpTween then
                self.hpTween:Kill()
            end
            --self.hpSlider.fillAmount = hp
            self.materialPropertyBlock:SetFloat("_HP",hp)
            self.hpGo:SetPropertyBlock(self.materialPropertyBlock)
            self.hpTween =
                DoTween.To(
                DG.Tweening.Core.DOGetter_float(
                    function()
                        return f1
                    end
                ),
                DG.Tweening.Core.DOSetter_float(
                    function(progress)
                        --self.hpPassSlider.fillAmount = progress
                        self.materialPropertyBlock:SetFloat("_HP",progress)
                        self.hpGo:SetPropertyBlock(self.materialPropertyBlock)
                    end
                ),
                f2,
                0.5
            ):SetEase(Ease.Linear)
        else
            if self.hpPassTween then
                self.hpPassTween:Kill()
            end
            --self.hpPassSlider.fillAmount = hp
            self.materialPropertyBlock:SetFloat("_HP",hp)
            self.hpGo:SetPropertyBlock(self.materialPropertyBlock)
            self.hpPassTween =
                DoTween.To(
                DG.Tweening.Core.DOGetter_float(
                    function()
                        return f1
                    end
                ),
                DG.Tweening.Core.DOSetter_float(
                    function(progress)
                        --self.hpSlider.fillAmount = progress
                        self.materialPropertyBlock:SetFloat("_HP",progress)
                        self.hpGo:SetPropertyBlock(self.materialPropertyBlock)
                    end
                ),
                f2,
                0.5
            ):SetEase(Ease.Linear)
        end
        self.hpCache = hp
    end

    --更新血条位置
    self:Update_HPPos()

--[[   临时屏蔽
    local rage = self.role.Rage / 4
    if self.rageCache ~= rage then
        -- 判断是否播放满怒动画
        if (not self.rageCache or self.rageCache < 1) and rage >= 1 then
            local go = loadAsset(rageEffect)
            go.transform:SetParent(self.GameObject.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:SetActive(true)
            self:AddDelayRecycleRes(rageEffect, go, 3)
        end

        self.rageCache = rage
        -- TODO: 战斗引导相关调整
        if rage == 1 and self.camp == 0 then
            Game.GlobalEvent:DispatchEvent(GameEvent.Guide.GuideBattleCDDone, self)
        end
    end
]]
    for k, v in pairs(self.BuffIconList) do
        v:Update()
    end

    if IsOpenBattleDebug then
        self.role.data:Foreach(
            function(name, value)
                -- self.URoleProperty:SetValue(name, value)
            end
        )
    end
end

function RoleView:UpdateAnimation()
    -- if self.role:IsRealDead() then
    --     return
    -- end

    -- local battlepanel = self.RoleLiveGO
    -- for i = 1, 10 do
    --     battlepanel = battlepanel.transform.parent
    --     if battlepanel.name == "BattlePanel" then
    --         break
    --     end
    -- end

    -- if not battlepanel.gameObject.activeSelf then
    --     self.RoleImageAnimation:Update()
    -- end
    
end

function RoleView:HpComponentHide(isHide)
    -- Util.GetGameObject(self.GameObject, "hpProgress"):SetActive(not isHide)
    -- Util.GetGameObject(self.GameObject, "Pro"):SetActive(not isHide)
    -- Util.GetGameObject(self.GameObject, "lv"):SetActive(not isHide)
    Util.GetGameObject(self.GameObject, "buff"):SetActive(not isHide)

    if isHide then
        self.materialPropertyBlock:SetColor("_Color",Color.New(1,1,1,0))
    else
        self.materialPropertyBlock:SetColor("_Color",Color.New(1,1,1,1))
    end
    self.hpGo:SetPropertyBlock(self.materialPropertyBlock)

    if not isHide then
        self:Update_HPPos()
    end
end

-- 战斗位移
function RoleView:DoFightMove(curpos, tarpos, dur, func, beforeIsHideObj, afterIsHideObj)
    if self.dsTweenFightMove then
        self.dsTweenFightMove:Kill()
    end

    BattleManager.PauseBattle()

    local oldpt = curpos == nil and self.RoleLiveGO.transform.parent.localPosition or curpos

    self.dsTweenFightMove =
        DoTween.To(
        DG.Tweening.Core.DOGetter_float(
            function()
                return 0
            end
        ),
        DG.Tweening.Core.DOSetter_float(
            function(progress)
                self.RoleLiveGO.transform.parent.transform.localPosition = Vector3.Slerp(oldpt+ Vector3.New(0,4,0), tarpos+Vector3.New(0,4,0), progress)-Vector3.New(0,4,0)
            end
        ),
        1,
        dur)
        :SetEase(Ease.Linear)
        :OnComplete(
            function()
                self:HpComponentHide(afterIsHideObj)
                if curpos == 10 or curpos==99 then self:HpComponentHide(true) end -- 主角血条不显示
                BattleManager.ResumeBattle()               
                if func then
                    func()
                end
            end)
        :OnStart(
            function()
                self:HpComponentHide(beforeIsHideObj)
            end)
end

-- 缩放
function RoleView:DoScale(scale, dur, func)
    if self.dsTween then
        self.dsTween:Kill()
    end
    self.dsTween =
        self.GameObject.transform.parent:DOScale(Vector3.one * scale, dur):OnComplete(
        function()
            if func then
                func()
            end
        end
    )

    -- if self.camp == 1 then
    if self.dsTween2 then
        self.dsTween2:Kill()
    end
    local liveScale = 1 -- self.role.position <= 3 and 0.6 or 0.5
    self.dsTween2 = self.RoleLiveGO.transform.parent:DOScale(Vector3.one * liveScale * scale, dur)
    -- end
end

-- 设置高亮
function RoleView:SetHighLight(isLight, eScale, dur, func)
    -- 设置变灰
    if self.isDead then
        --Util.SetGray(self.GameObject, true)

        --local color = Color.New(75, 75, 75, 255) / 255
        --Util.SetColor(self.GameObject, color)
        --Util.SetColor(self.RoleLiveGO, color)
        
        --self:DoScale(0.8, dur, func)
        return
    end

    self:DoScale(eScale, dur, func)
    -- 颜色变灰
    local sc = Util.GetColor_Spine(self.RoleLiveGOGraphic).r
    local ec = isLight and 1 or 0.5
    if self.hlTween3 then
        self.hlTween3:Kill()
    end
    self.hlTween3 =
        DoTween.To(
        DG.Tweening.Core.DOGetter_float(
            function()
                return sc
            end
        ),
        DG.Tweening.Core.DOSetter_float(
            function(progress)
                local color = Color.New(progress, progress, progress, 1)
                Util.SetColor(self.GameObject, color)
                self.lvText.color = color

                Util.SetColor_Spine(self.RoleLiveGOGraphic, color)
            end
        ),
        ec,
        dur
    ):SetEase(Ease.Linear)

end

function RoleView:SetBgColor(isLight, dur, bg)
    local sc = isLight and 0.3 or 1
    local ec = isLight and 1 or 0.3
    if self.bgColorTween then
        self.bgColorTween:Kill()
    end
    self.bgColorTween =
        DoTween.To(
        DG.Tweening.Core.DOGetter_float(
            function()
                return sc
            end
        ),
        DG.Tweening.Core.DOSetter_float(
            function(progress)
                local color = Color.New(progress, progress, progress, 1)
                Util.SetColor(bg, color)
            end
        ),
        ec,
        dur
    ):SetEase(Ease.Linear)
end

-- 播放动画
function RoleView:PlaySpineAnim(gog, time, name, isLoop)
    if isLoop then
        gog.AnimationState:ClearEvent_Complete()
        gog.AnimationState:SetAnimation(time, name, isLoop)
    else
        local _complete = nil
        _complete = function(state)
            gog.AnimationState.Complete = gog.AnimationState.Complete - _complete
            gog.AnimationState:SetAnimation(0, RoleAnimationName.Stand, true)
        end        
        RoleView:ResetSpineComponent(gog)
        gog.AnimationState:SetAnimation(time, name, isLoop)
        gog.AnimationState.Complete = gog.AnimationState.Complete + _complete
    end
    
end

--显示主角id
function RoleView:OnSkillCast(skill, func)
    --local testinfo =string.format("cd:%s  release:%s ",skill.cd,skill.release)
    -- self:TextBuffFloating(TextFloatingColor.Blue, 
    -- testinfo.." :"..GetLanguageStrById(G_SkillConfig[skill.id].Name).." 技能槽位:"..skill.ext_slot)
    if self.role.leader then 
        -- 需要技能槽位显示参数
        -- LogError("CastSkill")
        self.RootPanel.root:ShowRect_Skill(leaderIcon[1], G_SkillConfig[skill.id].Name, self.role.camp + 1, true)
        --切换技能图标 需要读取下个技能图标        
        local nextSkil = self.role:GetNextLeaderSkillSlot(skill)
        --LogError("nextSkil:"..nextSkil)
        self.RootPanel.root:FreshIcon_Skill(skill, skill.lv, self.role.camp, 2, nextSkil)
    end
end

function RoleView:SkillCastEnd(skill)
    self.role.skilling = false
    self:HideBuff(false)
    if self.role.leader then 
        self.RootPanel.root:UnGreyAndFrie_Skill(skill,self.role.camp,skill.sort,self.role)
    end
end

function RoleView:SkillFireOnce(skill, targetIdx)
    if not skill or not targetIdx then
        return
    end

    local combat = BattleManager.GetSkillCombat(SkillLogicConfig[skill.id].SkillDisplay)
    if not combat then
        return
    end

    local funFire = function()
        self.RootPanel.SetRoleHighLight(
            self,
            skill:GetDirectTargets(),
            function()
                self:PlaySpineAnim(self.RoleLiveGOGraphic, 0, combat.Animation, false)
                if combat.isRecoil == 1 then
                    self.RoleLiveGO.transform:DOAnchorPosY(-40, 0.1):SetEase(Ease.Linear):OnComplete(function()
                        self.RoleLiveGO.transform:DOAnchorPosY(0, 0.15):SetEase(Ease.Linear):OnComplete(function()
                        end)
                    end)
                end

                if combat.SkillSound then
                    local soundidx = math.random(1, #combat.SkillSound)
                   SoundManager.PlaySound(combat.SkillSound[soundidx])

                end
                if combat.SkillNameVoice then
                    SoundManager.PlaySound(combat.SkillNameVoice)
                end
                self:CheckFullSceenSkill(combat, skill, targetIdx)

                if combat.Move > 0 then
                    self:DelayFunc(
                        combat.ReturnTime / 1000 - 3 * BattleLogic.GameDeltaTime,
                        function()                             
                            local _backFinish = function()
                                self.RootPanel.SetRoleHighLight()

                                self:HideBuff(false)
                            end
                            local pos = self.role.position
                            if pos == 99 then pos = 10 end
                            self:DoFightMove(nil, FightCampLocalPosition[self.role.camp][pos], 3 * BattleLogic.GameDeltaTime, _backFinish, true, false)
                        end
                    )
                else
                end
            end,
            skill,
            combat
            )
    end

    if combat.Closeup and not self.role.skilling and skill.isAdd then
        self.role.skilling = true
        self:PlaySkillCloseUpBefore(combat, skill, funFire)
    else
        if combat.SkillType ~= 1 then
            -- self.RootPanel.root:ShowRect_Skill(HeroConfig[self.role.roleData.roleId].Icon,G_SkillConfig[skill.id].Name)
            if self.camp == 0 then
                self.RootPanel.root:ShowRect_Skill(HeroConfig[self.role.roleData.roleId].Icon, G_SkillConfig[skill.id].Name, 1)
            else
                self.RootPanel.root:ShowRect_Skill(HeroConfig[self.role.roleData.roleId].Icon, G_SkillConfig[skill.id].Name, 2)
            end
        end
        funFire()
    end
end

local SkillSumDamagedValue = 0 -- 技能伤害总值

function RoleView:SkillFireAll(skill)
    if not skill then
        return
    end
    local combat = BattleManager.GetSkillCombat(SkillLogicConfig[skill.id].SkillDisplay)
    if not combat then
        return
    end

    SkillSumDamagedValue = 0

    local funFire = function()
        self.RootPanel.SetRoleHighLight(
            self,
            skill:GetDirectTargets(),
            function()
                local funFire2 = function ()
                    --施法目标
                    local targets = skill:GetDirectTargets()
                    self.RootPanel.SetRoleActive(self.role, combat.HideActor, false, targets)
                    
                    if not BattleManager.isFightBack then
                        self:PlaySpineAnim(self.RoleLiveGOGraphic, 0, combat.Animation, false)
                        self:CheckSkillForoleEffect(combat, skill)
                    end

                    if combat.Move > 0 then
                        self:DelayFunc(
                            -- (combat.KeyFrame + t) / 1000 + 0.2 - 3 * BattleLogic.GameDeltaTime,
                            combat.ReturnTime / 1000 - 3 * BattleLogic.GameDeltaTime,
                            function()                             
                                local _backFinish = function()
                                    self.RootPanel.SetRoleActive(self.role, combat.BeforeHideActor, true, targets)
                                    self.RootPanel.SetRoleActive(self.role, combat.HideActor, true, targets)

                                    self.RootPanel.SetRoleHighLight()

                                    self:HideBuff(false)

                                    BattleLogic.Event:DispatchEvent(BattleEventName.FloatTotal, SkillSumDamagedValue)
                                end
                                local pos = self.role.position
                                if pos == 99 then pos =10 end
                                self:DoFightMove(nil, FightCampLocalPosition[self.role.camp][pos], 3 * BattleLogic.GameDeltaTime, _backFinish, true, false)
                            end
                        )
                    else
                        self:DelayFunc(
                            combat.ReturnTime / 1000- 3 * BattleLogic.GameDeltaTime,
                            function()
                                self.RootPanel.SetRoleActive(self.role, combat.BeforeHideActor, true, targets)
                                self.RootPanel.SetRoleActive(self.role, combat.HideActor, true, targets)

                                BattleLogic.Event:DispatchEvent(BattleEventName.FloatTotal, SkillSumDamagedValue)
                            end
                        )
                    end

                    self:DelayFunc(
                        combat.CastBullet / 1000,
                        function()
                            self:CheckFullSceenSkill(combat, skill, nil)
                        end
                    )

                    if combat.EffectType == 4 then
                        local a = 0
                    end

                    if combat.SkillSound then
                       local soundidx = math.random(1, #combat.SkillSound)
                        SoundManager.PlaySound(combat.SkillSound[soundidx])      
                    end
                    if combat.SkillNameVoice then
                        SoundManager.PlaySound(combat.SkillNameVoice)
                    end   

                end

                if combat.PV then
                    self:PlayPV(combat, skill, function ()
                        BattleLogic.Event:DispatchEvent(BattleEventName.FloatTotal, SkillSumDamagedValue)
                    end)

                    self:DelayFunc(
                        combat.CastBullet / 1000,
                        function()
                            self:CheckFullSceenSkill(combat, skill, nil)
                        end
                    )
                else
                    funFire2()
                end
            end,
            skill,
            combat
        )
    end

    --按规则隐藏英雄
    self:DelayFunc(0.1,
    function()
        self.RootPanel.SetRoleActive(self.role, combat.BeforeHideActor, false, skill:GetDirectTargets())
    end)

    if combat.Closeup and not self.role.skilling then
        self.role.skilling = true
        self:PlaySkillCloseUpBefore(combat, skill, funFire)
    else
        if combat.SkillType ~= 1 then
            -- self.RootPanel.root:ShowRect_Skill(HeroConfig[self.role.roleData.roleId].Icon,G_SkillConfig[skill.id].Name)
            local id = self.role.roleData.roleId
            local icon = 0
            -- 主角单独处理 HeroConfig[id].Icon 为 id @exm 10001的 头像id = 3001
            if self.role.leader then  
                icon = leaderIcon[id] -- 3092 为男需要读取对应表单
            else
                icon = HeroConfig[id].Icon
            end 
           
            if self.camp == 0 then
                self.RootPanel.root:ShowRect_Skill(icon, G_SkillConfig[skill.id].Name, 1)
            else
                self.RootPanel.root:ShowRect_Skill(icon, G_SkillConfig[skill.id].Name, 2)
            end
        end
        funFire()
    end
end

function RoleView:PlaySkillCloseUpBefore(combat, skill, funFire)
    BattleManager.PauseBattle()
    self:DelayFunc(0.5, function()
        -- self:SetBgColor(false, 0.2, self.RootPanel.BG)
        local roles = self.RootPanel.GetRoles()
        local roleUps = skill:GetDirectTargets()
        for r, role in pairs(roles) do
            local isFight = false
            for _, roleup in pairs(roleUps) do
                if r == roleup then
                    isFight = true
                end
            end

            if isFight then
                if not role.role:IsRealDead() then
                    role:SetHighLight(true, 1, 0.2)
                end
            else
                if not role.role:IsRealDead() then
                    role:SetHighLight(false, 1, 0.01)
                end
            end
        end

        self:SetHighLight(true, 1, 0.2)

        self:PlaySkillCloseUpNew(combat, funFire, skill)
        -- SoundManager.PlayBattleSound("n1_snd_closeup_bg") 改到表里了
    end)
end

--播放PV
function RoleView:PlayPV(combat, skill, func)
    BattleManager.PauseBattle()

    if self.playPV_LocalMove then
        self.playPV_LocalMove:Kill()
    end

    --隐藏血条
    self.RootPanel.EnemyPanel:SetActive(false)
    self.RootPanel.MinePanel:SetActive(false)

    --施法方移动到目标位置
    local tarPos = FightCampTargetLocalPosition[self.role.camp][5] --己方5号位
    local moveTime = 0.1

    self.playPV_LocalMove = self.RoleLiveGO.transform.parent:DOLocalMove(tarPos, moveTime, false)
    :SetEase(Ease.Linear)
    :OnComplete(function()
            BattleManager.ResumeBattle()
            --播放PV
            self:PlayPVPrefab(combat.PV, combat.PVDuration, self.role.camp == 0)
            --播放声音            
            if combat.SkillSound then
                local soundidx = math.random(1, #combat.SkillSound)
               SoundManager.PlaySound(combat.SkillSound[soundidx])
            end
            if combat.SkillNameVoice then
                SoundManager.PlaySound(combat.SkillNameVoice)
            end 
            --施法目标
            local targets = skill:GetDirectTargets()

            self.RootPanel.SetRoleActive(self.role, combat.HideActor, false, targets)

            self:DelayFunc(
                combat.PVDuration / 1000,
                function()
                    BattleManager.PauseBattle()

                    self.RootPanel.ResetHighLightWithTargets(true, targets, self)
                    self.RootPanel.SetRoleActive(self.role, combat.HideActor, true, targets)

                    --施法方归位
                    if self.playPV_LocalMove then
                        self.playPV_LocalMove:Kill()
                    end
                    local pos =self.role.position
                    if self.role.position == 99 or self.role.position==100 then 
                        pos = 10 
                        --LogError("pos 10 "..FightCampTargetLocalPosition[self.role.camp][pos].x)
                    end
                    tarPos = FightCampTargetLocalPosition[self.role.camp][pos] --自己原本位置

                    self.playPV_LocalMove = self.RoleLiveGO.transform.parent:DOLocalMove(tarPos, moveTime, false)
                        :SetEase(Ease.Linear)
                        :OnComplete(function ()
                                    --显示血条
                                    self.RootPanel.EnemyPanel:SetActive(true)
                                    self.RootPanel.MinePanel:SetActive(true)

                                    self.RootPanel.UpdateAllRoleHPPos()

                                    --所有人显示
                                    self.RootPanel.SetRoleActive(self.role, 999, true, targets)

                                    BattleManager.ResumeBattle()

                                    if func then
                                        func()
                                    end
                                    -- pv放完后 位置拉回
                                    self.RoleLiveGO.transform.parent.transform.localPosition = FightCampLocalPosition[self.role.camp][self.role.position]
                                end)
                end)
        end)
end

function RoleView:PlaySkillCloseUpNew(combat, func, skill)

    self:PlayCloseup(combat)

    if combat.CloseupSound then
        SoundManager.PlayBattleSound(combat.CloseupSound)
    end

    --隐藏血条
    self.RootPanel.EnemyPanel:SetActive(false)
    self.RootPanel.MinePanel:SetActive(false)

    self:DelayFunc(
        combat.CloseupDuration / 1000,
        function()
            --如果有PV,继续隐藏血条
            if not combat.PV then
                --显示血条
                self.RootPanel.EnemyPanel:SetActive(true)
                self.RootPanel.MinePanel:SetActive(true)
            end

            local targets = skill:GetDirectTargets()
            self.RootPanel.ResetHighLightWithTargets(true, targets, self)

            BattleManager.ResumeBattle()

            if func then
                func()
            end
        end
    )
end

local FightMovePosOffset = {
    --mine enemy x = -x
    Offset_All = Vector3.New(-3, 0, 0),
    Offset_Front = Vector3.New(-3, 0, 0),
    Offset_Behind = Vector3.New(-3, 0, 0),
    Offset_COL_1 = Vector3.New(-3, 0, 0),
    Offset_COL_2 = Vector3.New(-3, 0, 0),
    Offset_COL_3 = Vector3.New(-3, 0, 0),
    Offset_Single_1 = Vector3.New(-3, 0, 0),
    Offset_Single_2 = Vector3.New(-3, 0, 0),
    Offset_Single_3 = Vector3.New(-3, 0, 0),
    Offset_Single_4 = Vector3.New(-3, 0, 0),
    Offset_Single_5 = Vector3.New(-3, 0, 0),
    Offset_Single_6 = Vector3.New(-3, 0, 0),
    Offset_Single_7 = Vector3.New(-3, 0, 0),
    Offset_Single_8 = Vector3.New(-3, 0, 0),
    Offset_Single_9 = Vector3.New(-3, 0, 0),
    Offset_Single_10 = Vector3.New(-3, 0, 0),
}

function RoleView:GetFightMovePos(skill)
    local ret = nil

    local chooseId = skill.effectList.buffer[1].chooseId
    local chooseType = math.floor(chooseId / 100000)
    local chooseLimit = math.floor(chooseId / 10000) % 10
    local chooseNum = chooseId % 10
    local targets = skill:GetDirectTargets()

    local targetCamp = targets[1].camp
    local targetPos = targets[1].position
    local invert = targetCamp == 0 and 1 or -1


    if targetPos==99 then targetPos = 10 end
    --    LogError("targetPos "..targetPos)
    ---chooseType
    ---1:我方
    ---2:敌方
    ---3:自身
    ---4:仇恨目标
    ---5:我方阵亡
    ---6:我方含阵亡
    
    ---chooseLimit
    ---0:全体
    ---1:前排
    ---2:后排
    ---3:对列
    ---4:前2排
    ---5:后2排
    ---6:全体,优先4职业
    ---7:人数最多列
    ---8:除自己外
    ---9:全体,优先2职业

    if chooseType == 4 then --目标身前 单体     
        local offset = Vector3.New(FightMovePosOffset["Offset_Single_" .. targetPos].x,
         FightMovePosOffset["Offset_Single_" .. targetPos].y, 
         FightMovePosOffset["Offset_Single_" .. targetPos].z)
        offset.x = invert * offset.x
        ret = FightCampLocalPosition[targetCamp][targetPos] + offset
    elseif chooseType == 2 then
        if chooseLimit == 0 or chooseLimit == 6 or chooseLimit == 9 then
            if chooseNum == 0 or chooseNum == 5 then --对方阵前 全体
                local offset = Vector3.New(FightMovePosOffset.Offset_All.x, FightMovePosOffset.Offset_All.y, FightMovePosOffset.Offset_All.z)
                offset.x = invert * offset.x
                ret = FightCampLocalPosition[targetCamp][2] + offset
            elseif chooseNum == 1 then --目标身前 单体
                local offset = Vector3.New(FightMovePosOffset["Offset_Single_" .. targetPos].x, FightMovePosOffset["Offset_Single_" .. targetPos].y, FightMovePosOffset["Offset_Single_" .. targetPos].z)
                offset.x = invert * offset.x
                ret = FightCampLocalPosition[targetCamp][targetPos] + offset
            else
                --不移动
            end
        elseif chooseLimit == 1 or chooseLimit == 2 then --中间位置身前 1行
            local offsetF = Vector3.New(FightMovePosOffset.Offset_Front.x, FightMovePosOffset.Offset_Front.y, FightMovePosOffset.Offset_Front.z)
            offsetF.x = offsetF.x * invert
            local offsetB = Vector3.New(FightMovePosOffset.Offset_Behind.x, FightMovePosOffset.Offset_Behind.y, FightMovePosOffset.Offset_Behind.z)
            offsetB.x = offsetB.x * invert
            if targetPos <= 3 then
                ret = FightCampLocalPosition[targetCamp][2] + offsetF
            else
                ret = FightCampLocalPosition[targetCamp][5] + offsetB
            end
        elseif chooseLimit == 4 or chooseLimit == 5 then --前排中间位置身前 2行
            targetPos = 100 --拿到最小的位置
            for key, value in pairs(targets) do
                if targetPos > value.position then
                    targetPos = value.position
                end
            end

            local col = (targetPos - 1) % 3 + 1
            local offset = Vector3.New(FightMovePosOffset["Offset_COL_" .. col].x, FightMovePosOffset["Offset_COL_" .. col].y, FightMovePosOffset["Offset_COL_" .. col].z)
            offset.x = invert * offset.x
            ret = FightCampLocalPosition[targetCamp][col] + offset
        elseif chooseLimit == 3 or chooseLimit == 7 then --数字最小位置身前 1列
            local col = (targetPos - 1) % 3 + 1
            local offset = Vector3.New(FightMovePosOffset["Offset_COL_" .. col].x, FightMovePosOffset["Offset_COL_" .. col].y, FightMovePosOffset["Offset_COL_" .. col].z)
            offset.x = invert * offset.x
            ret = FightCampLocalPosition[targetCamp][col] + offset
        else
        --不移动
        end
    end

    if ret then
        ret = Vector3.New(ret.x, ret.y, ret.z - 0.01) --进攻方压住防守方
    end

    return ret
end

local FullEffectPosition = {
    --mine enemy x = -x
    Offset_All = Vector3.New(0, 0, 0),
    Offset_Front = Vector3.New(0, 0, 0),
    Offset_Behind = Vector3.New(0, 0, 0),
    Offset_COL_1 = Vector3.New(0, 0, 0),
    Offset_COL_2 = Vector3.New(0, 0, 0),
    Offset_COL_3 = Vector3.New(0, 0, 0),
    Offset_Single_1 = Vector3.New(0, 0, 0),
    Offset_Single_2 = Vector3.New(0, 0, 0),
    Offset_Single_3 = Vector3.New(0, 0, 0),
    Offset_Single_4 = Vector3.New(0, 0, 0),
    Offset_Single_5 = Vector3.New(0, 0, 0),
    Offset_Single_6 = Vector3.New(0, 0, 0),
}

function RoleView:GetEffectSPostion(skill)
    local chooseId = skill.effectList.buffer[1].chooseId
    local chooseLimit = math.floor(chooseId / 10000) % 10

    local targets = skill:GetDirectTargets()
    local targetPos = targets[1].position
    --LogError("tarpos"..targetPos)
    if chooseLimit == 3 then
        local col = (targetPos - 1) % 3 + 1
        return self.camp == 0 and FullEffectPosition["My_COL_" .. col] or FullEffectPosition["Enemy_COL_" .. col]
    else
        return self.camp == 0 and FullEffectPosition.My_All or FullEffectPosition.Enemy_All
    end
end

function RoleView:GetEffectPosition(skill)
    local ret = nil

    local chooseId = skill.effectList.buffer[1].chooseId
    local chooseType = math.floor(chooseId / 100000)
    local chooseLimit = math.floor(chooseId / 10000) % 10
    local chooseNum = chooseId % 10
    local targets = skill:GetDirectTargets()
    
    if #targets == 0 then--技能没找到目标
        return ret
    end

    local targetCamp = targets[1].camp
    local targetPos = targets[1].position

    local invert = targetCamp == 0 and 1 or -1
    
    if targetPos==99 then targetPos=10 end
    
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

    if chooseType == 4 then --目标身前 单体
        ret = FightCampLPToSkillRoot[targetCamp][targetPos]
    elseif chooseType == 2 then
        if chooseLimit == 0 or chooseLimit == 6 or chooseLimit == 9 then
            if chooseNum == 0 or chooseNum == 5 then --对方阵前 全体
                ret = FightCampLPToSkillRoot[targetCamp][5]
            elseif chooseNum == 1 then --目标身前 单体
                ret = FightCampLPToSkillRoot[targetCamp][targetPos]
            else
                ret = FightCampLPToSkillRoot[targetCamp][5]
            end
        elseif chooseLimit == 1 or chooseLimit == 2 then --中间位置身前 1行
            if targetPos <= 3 then
                ret = FightCampLPToSkillRoot[targetCamp][2]
            else
                ret = FightCampLPToSkillRoot[targetCamp][8]
            end
        elseif chooseLimit == 4 then
            ret = FightCampLPToSkillRoot[targetCamp][2]
        elseif chooseLimit == 5 then
            ret = FightCampLPToSkillRoot[targetCamp][5]            
        elseif chooseLimit == 3 or chooseLimit == 7 then --数字最小位置身前 1列
            local col = (targetPos - 1) % 3 + 1
            ret = FightCampLPToSkillRoot[targetCamp][col]
        else
        --不移动
        end
    else
        ret = FightCampLPToSkillRoot[targetCamp][5]
    end

    return ret
end

-- 检测特效旋转
function RoleView:CheckRotate(go, orientation)
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

-- 检测是否需要释放全屏技能
function RoleView:CheckFullSceenSkill(combat, skill, targetIdx)
    if not skill then
        return
    end
    -- 指定目标弹道特效
    if combat.EffectType == 1 then
        if combat.IsCannon == 0 then
            local targets = skill:GetDirectTargets()
            if targets==nil then return end
            for _, target in ipairs(targets) do
                self:RoleViewBullet(combat, target, skill)
            end
        else
            self:RoleViewBullet(combat, skill:GetDirectTargets()[targetIdx], skill)
        end
    elseif combat.EffectType == 2 then
        -- 全屏弹道特效
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
            if go then
                -- 检测特效旋转
                if self:CheckRotate(go, combat.Orientation) then
                    offset = -offset
                end
                go.transform.localScale = self.camp == 0 and Vector3.one or Vector3.New(-1, 1, 1)
                go.transform.localPosition = pos + offset

                self:PlayParticleSystem(path, go, nil, 4)
            end
        end
    elseif combat.EffectType == 3 then
        -- 指定目标特效
        local path = combat.Bullet
        if path then
            local spos = self:GetEffectSPostion(skill)
            local tpos = self:GetEffectPosition(skill)
            if not spos or not tpos then 
                return 
            end
            -- 时间
            local duration = combat.BulletTime/1000
            -- 特效的偏移量
            local offset = Vector3.zero
            if combat.Offset then
                local offset_x = self.camp == 0 and combat.Offset[1] or -combat.Offset[1]
                offset = Vector3.New(offset_x, combat.Offset[2], 0)
            end
            local go = self:loadAssetForScene(path, self.RootPanel.battleSceneSkillTransform)
            go.transform.localScale = Vector3.one
            if self.camp == 0 and combat.Orientation == 1 then
                go.transform.localRotation = Vector3.New(0, 0, 180)
                offset = -offset
            else
                go.transform.localRotation = Vector3.zero
            end

	        -- 检测特效旋转
            if self:CheckRotate(go, combat.Orientation) then
                offset = -offset
            end
            go.transform.localPosition = spos + offset
            go.transform.localScale = self.camp == 0 and Vector3.one or Vector3.New(-1, 1, 1)
            self:PlayParticleSystem(path, go, nil, duration)

            if self.fullBulletTween then self.fullBulletTween:Kill() end
            self.fullBulletTween = go.transform:DOLocalMove(tpos + offset, duration):SetEase(Ease.OutSine)
            -- :OnComplete(function()
            --     go:SetActive(false)
            -- end)
        end

    -- 指定目标特效
    elseif combat.EffectType == 4 then
        local path = combat.Bullet
        local targets = skill:GetDirectTargets()
        if targets == nil then return end
        for _, target in ipairs(targets) do
            local tv = self.RootPanel.GetRoleView(target)
            if tv then
                local offset = Vector3.zero
                if combat.Offset then
                    local offset_x = self.camp == 0 and combat.Offset[1] or -combat.Offset[1]
                    offset = Vector3.New(offset_x, combat.Offset[2], 0)
                end

                --local go2 = self:loadAssetForScene(path, tv.RoleLiveGO.transform)
                local go2 = self:loadAssetForScene(path, self.RootPanel.battleSceneSkillTransform)
                -- 检测特效旋转
                if self:CheckRotate(go2, combat.Orientation) then
                    offset = -offset
                end
                go2.transform.localScale = self.camp == 0 and Vector3.one or Vector3.New(-1, 1, 1)            
                go2.transform.position = tv.RoleLiveGO.transform.position
                go2.transform.localPosition = go2.transform.localPosition + offset
                self:PlayParticleSystem(path, go2, nil, 4)
            end

        end
    -- 全屏特效屏幕中心
    elseif combat.EffectType == 5 then
        local path = combat.Bullet
        local offset = Vector3.zero
        if combat.Offset then
            local offset_x = self.camp == 0 and combat.Offset[1] or -combat.Offset[1]
            offset = Vector3.New(offset_x, combat.Offset[2], 0)
        end
        local go2 = self:loadAssetForScene(path, self.RootPanel.battleSceneSkillTransform)
        -- 检测特效旋转
        if self:CheckRotate(go2, combat.Orientation) then
            offset = -offset
        end
        go2.transform.localScale = self.camp == 0 and Vector3.one or Vector3.New(-1, 1, 1)
        go2.transform.localPosition = offset
        self:PlayParticleSystem(path, go2, nil, 4)
    --> 连线类型效果
    elseif combat.EffectType == 6 then
        local path = combat.Bullet
        local offset = combat.Offset and Vector3.New(combat.Offset[1], combat.Offset[2], 0) or Vector3.zero

        local speed = 100
        local targets = skill:GetDirectTargets()
        for _, target in ipairs(targets) do
            local tv = self.RootPanel.GetRoleView(target)
            if tv and tv ~= self then

                local endV3 = tv.RoleLiveGO.transform.parent.position
                local time = 0.1--dis / 100
                local go = self:loadAssetForScene(path, self.RootPanel.battleSceneSkillTransform)
                go.transform.localScale = self.camp == 0 and Vector3.one or Vector3.New(-1, 1, 1)
                go.transform.position = self.RoleLiveGO.transform.position
                
                Util.ClearTrailRender(go)
                self:PlayParticleSystem(path, go, nil, time + combat.ReturnTime/1000)

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
                    time
                ):SetEase(Ease.InQuad)
            end
        end
    end

    -- 取消高亮
    self:DelayFunc(combat.KeyFrame/1000, function()
        self:CheckSkillHitEffect("skill", combat, skill)
        --self:checkShake(combat)
    end)
end

-- 检测前摇技能释放
function RoleView:CheckSkillForoleEffect(combat, skill)
    if not skill then
        return 
    end

    if not combat.BeforeBullet or combat.BeforeBullet == "" then
        return 
    end
    local go
    local path = combat.BeforeBullet
    local offset = Vector3.zero
    
    if combat.BeforeOffset then
        local offset_x = self.camp == 0 and combat.BeforeOffset[1] or -combat.BeforeOffset[1]
        offset = Vector3.New(offset_x, combat.BeforeOffset[2], 0)
    end

    -- 挂在人身上，以人物中心为原点
    if combat.BeforeEffectType == 1 then
        local sortingOrder = self:GetSortingOrder()
        go = self:loadAssetForScene(path, self.RoleLiveGO.transform.parent)
    -- 屏幕中心
    elseif combat.BeforeEffectType == 2 then
        go = self:loadAssetForScene(path, self.RootPanel.battleSceneSkillTransform)
    end
    -- 检测特效旋转
    if self:CheckRotate(go, combat.BeforeOrientation) then
        offset = -offset
    end

    go.transform.localScale = self.camp == 0 and Vector3.one or Vector3.New(-1, 1, 1)
    go.transform.localPosition = Vector3.zero + offset

    self:PlayParticleSystem(path, go, nil, 4)
end

-- 检测技能命中特效显示
function RoleView:CheckSkillHitEffect(checkType, combat, skill)
    if not combat then return end

    if checkType == "skill" then
        -- 释放技能时检测,如果是范围命中效果
        if combat.HitEffectType == 2 and combat.FriendHitEffect then
            local targets = skill:GetDirectTargets()
            if not targets or not targets[1] or targets[1]:IsDead() then return end
            local tv = self.RootPanel.GetRoleView(targets[1])
            if not tv then return end

            local tpos = self:GetEffectPosition(skill)
            if not tpos then 
                return 
            end

            -- 特效的偏移量
            local offset = Vector3.zero
            if combat.HitOffset then
                local offset_x = self.camp == 0 and combat.HitOffset[1] or -combat.HitOffset[1]
                offset = Vector3.New(offset_x, combat.HitOffset[2], 0)
            end

            local go = self:loadAssetForScene(combat.FriendHitEffect, self.RootPanel.battleSceneSkillTransform)
            -- 检测特效旋转
            if self:CheckRotate(go, combat.HitOrientation) then
                offset = -offset
            end
            go.transform.localScale = self.camp == 0 and Vector3.one or Vector3.New(-1, 1, 1)
            go.transform.localPosition = tpos + offset
            self:PlayParticleSystem(combat.FriendHitEffect, go, nil, 5)

            if combat.HitSound then
                local soundidx = math.random(1, #combat.HitSound)
                SoundManager.PlayBattleSound(combat.HitSound[soundidx])
            end
        elseif combat.HitEffectType == 1 then
            -- 被击中时检测，如果是目标命中
            if combat.FriendHitEffect then
                local targets = skill:GetDirectTargets()
                if targets then
                    for _, target in ipairs(targets) do
                        local tv = self.RootPanel.GetRoleView(target)
                        if tv ~= nil then
                            local go2 = self:loadAssetForScene(combat.FriendHitEffect, tv.RoleLiveGO.transform.parent)

                            --> offset 全部走 发射时转换的offset 因为有随机
                            local offset = Vector3.zero
                            if combat.HitOffset then
                                local offset_x = self.camp == 0 and combat.HitOffset[1] or -combat.HitOffset[1]
                                offset = Vector3.New(offset_x, combat.HitOffset[2], 0)
                            end

                            go2.transform.localScale = self.camp == 0 and Vector3.one or Vector3.New(-1, 1, 1)
                            go2.transform.localPosition = offset

                            go2.transform:SetParent(self.RootPanel.battleSceneSkillTransform, true)
                            go2.transform.localEulerAngles = Vector3.New(0, 0, 0)
                            self:PlayParticleSystem(combat.FriendHitEffect, go2, nil, 5)

                            --> image 即挂 imageAnimation的 节点播放完后会hide 缓存池中取出需重置
                            local image = Util.GetGameObject(go2, "root/Image")
                            if image then
                                image:SetActive(true)
                            end
                            
                            if combat.HitSound then
                                local soundidx = math.random(1, #combat.HitSound)
                                SoundManager.PlaySound(combat.HitSound[soundidx])
                            end
                        end
                    end
                end
            end
        end
    elseif checkType == "hit" then
        -- 被击中时检测，如果是目标命中
        if combat.HitEffectType == 1 and combat.Hit then
            local go2 = self:loadAssetForScene(combat.Hit, self.RoleLiveGO.transform.parent)

            --> offset 全部走 发射时转换的offset 因为有随机
            local offset = Vector3.zero
            if combat.HitOffset then
                local offset_x = self.camp == 0 and combat.HitOffset[1] or -combat.HitOffset[1]
                offset = Vector3.New(offset_x, combat.HitOffset[2], 0)
            end

            go2.transform.localScale = self.camp == 0 and Vector3.one or Vector3.New(-1, 1, 1)
            go2.transform.localPosition = offset

            go2.transform:SetParent(self.RootPanel.battleSceneSkillTransform)
            go2.transform.localEulerAngles = Vector3.New(0, 0, 0)
            self:PlayParticleSystem(combat.Hit, go2, nil, 5)

            --> image 即挂 imageAnimation的 节点播放完后会hide 缓存池中取出需重置
            local image = Util.GetGameObject(go2, "root/Image")
            if image then
                image:SetActive(true)
            end
            

            -- local ani = go2.transform:GetComponent("ImageAnimation")
            -- if ani then
            --     ani:Play()
            -- end
            
            if combat.HitSound then
                local soundidx = math.random(1, #combat.HitSound)
                SoundManager.PlayBattleSound(combat.HitSound[soundidx])
            end
            
        end

        if combat.HitSound then
            local soundidx = math.random(1, #combat.HitSound)
            SoundManager.PlaySound(combat.HitSound[soundidx])
        end
    end
end

-- 检测是否需要震动屏幕
function RoleView:checkShake(combat)
    if combat.ShockScreen == 1 then
        self.RootPanel:ShakeCamera(0.2, 0.2, 0.2, 0.2)
    elseif combat.ShockScreen == 2 then
        self.RootPanel:ShakeCamera(0.2, 0.4, 0.4, 0.4)
    end
end

--弹道轨迹
local plist = {
    [1] = {
        Vector2.New(0.2, 0.9),
    },
    [2] = {
        Vector2.New(1.12, 0.33),
        Vector2.New(-0.15, 0.67),
    },
    [3] = {
        Vector2.New(0.9, 0.2),
    },
}

-- 播放弹道特效
function RoleView:RoleViewBullet(combat, target, skill)
    if not self.RootPanel.GetRoleView(target) then
        return
    end
    if not combat then
        return
    end
    if not skill then
        return
    end
    
    local duration = combat.BulletTime / 1000
    local bulletEffect = combat.Bullet
    if not bulletEffect or bulletEffect == "" or duration == 0 then
        return
    end
    
    -- 目标点位置加偏移
    local targetRoleView = self.RootPanel.GetRoleView(target) --目标
    local tempHitOffset = combat.HitOffset and combat.HitOffset or Vector3.zero
    local target_x_offset = self.camp == 0 and -tempHitOffset[1] or tempHitOffset[1]
    local endV3 = targetRoleView.RoleLiveGO.transform.parent.position + Vector3.New(target_x_offset, tempHitOffset[2], 0)
    
    target.randHitPos = {}

    local count = skill.attackCount
    local function BulletFly()
        --> 弹道特效
        local go = self:loadAssetForScene(bulletEffect, self.RootPanel.battleSceneSkillTransform)
        go.transform.localScale = Vector3.one
        go.transform.localRotation = Vector3.zero

        --起始位置
        local temp = self.RoleLiveGO.transform.localPosition
        local tempOffset = combat.Offset or Vector3.zero
        local x_offset = self.camp == 0 and tempOffset[1] or -tempOffset[1]
        self.RoleLiveGO.transform.localPosition = self.RoleLiveGO.transform.localPosition + Vector3.New(x_offset, tempOffset[2], 0)
        go.transform.position = self.RoleLiveGO.transform.position
        self.RoleLiveGO.transform.localPosition = temp

        -- 旋转特效方向
        local worldReduceX = endV3.x - go.transform.position.x
        local worldReduceY = endV3.y - go.transform.position.y

        local angle = math.acos(math.abs(worldReduceX) / math.sqrt(worldReduceX * worldReduceX + worldReduceY * worldReduceY)) * 57.29578

        go.transform.localScale = self.camp == 0 and Vector3.one or Vector3.New(-1, 1, 1)
        local isUp = endV3.y > go.transform.position.y
        local rotateZ = 0
        local isFlip = self.camp == 0 and 1 or -1
        rotateZ = isUp and isFlip*angle or isFlip*-angle
        --go.transform.localRotation = Vector3.New(0, 0, rotateZ)
        if combat.IsBulletRotation == 1 then
            go.transform:DORotate(Vector3.New(0, 0, rotateZ), 0)
        end

        Util.ClearTrailRender(go)
        self:PlayParticleSystem(bulletEffect, go, nil, duration + 0.5)

        PlayUIAnims(go)

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
        ):SetEase(Ease.InQuad)
    end
    if count >= 1 and skill.attackCount - 1 == #skill.continueTime then
        for i = 1, #skill.continueTime do
            local time = 0
            for j = 1, i do
                time = time + skill.continueTime[j]
            end
            self:DelayFunc(
                time,
                function()
                    BulletFly()
                end
            )
        end
        BulletFly()
    else
        BulletFly()
    end
end

-- aoe
function RoleView:OnAOE(camp)
    local path
    if self.role.roleData.roleId > 10000 then
        if camp == self.camp then
            path = RoleConfig[self.role.roleData.roleId].aoe1
        else
            path = RoleConfig[self.role.roleData.roleId].aoe2
        end
    else
        if camp == self.camp then
            path = MonsterViewConfig[self.role.roleData.roleId].aoe1
        else
            path = MonsterViewConfig[self.role.roleData.roleId].aoe2
        end
    end
    local go = self:loadAssetForScene(path, self.RootPanel.battleSceneSkillTransform)
    go.transform.localScale = Vector3.one
    if camp == 0 then
        go.transform.localPosition = Vector3.New(0,-3,0)
    else
        go.transform.localPosition = Vector3.New(0,3,0)
    end
    go:SetActive(true)
    self:AddDelayRecycleRes(path, go, 3)
end

-- 治疗
function RoleView:OnTreated(castRole, realTreat, treat)
    self:ArtFloating(ArtFloatingType.Treat, ArtFloatingColor.Green, treat)

    local go = self:loadAssetForScene(healEffect, self.RoleLiveGO.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition = Vector3.zero--self.GameObject.transform.localPosition
    go:SetActive(true)
    self:AddDelayRecycleRes(healEffect, go, 3)
end


-- 免疫触发
function RoleView:OnImmuneTrigger(buff)
    if  buff.type == BuffName.Control then
        self:TextBuffFloating(TextFloatingColor.Blue, GetLanguageStrById(50278))
    end
end

--护盾减伤
function RoleView:OnShildReduce(reduceValue)
    -- self:ArtFloating(ArtFloatingType.ShieldDef, ArtFloatingColor.Shiled, reduceValue, false) 
end
-- 盾效果触发
function RoleView:OnShieldTrigger(shield)
    if shield.shieldType == ShieldTypeName.AllReduce then
        self:ImageBuffFloating("z_zhandou_wudizi")
    else
        -- self:TextBuffFloating(TextFloatingColor.Blue, GetLanguageStrById(10275))
        -- self:TextBuffFloating(TextFloatingColor.Blue, "减免"..shield.nowReduceValue)
        -- if shield.nowReduceValue~= 0 then
        --     self:ArtFloating(ArtFloatingType.ShieldDef, ArtFloatingColor.Shiled, shield.nowReduceValue, false) 
        -- end
    end
end

-- 哈哈，没打着
function RoleView:OnBeHitMiss(atkRole, skill)
    self:TextBuffFloating(TextFloatingColor.Blue, GetLanguageStrById(12218))

    local sortingOrder = nil
    local effName = "n1_eff_hit_miss"
    local go = self:loadAssetForScene(effName, self.RoleLiveGO.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition = Vector3.zero
    go:SetActive(true)
    self:AddDelayRecycleRes(effName, go, 3)

    -- local sound = {"n1_snd_miss_expl_1", "n1_snd_miss_expl_2", "n1_snd_miss_expl_3"}
    -- local soundidx = math.random(1, #sound)
    -- SoundManager.PlaySound(sound[soundidx])
end

local DotTypeTip = {
    [0] = GetLanguageStrById(10276),
    [1] = GetLanguageStrById(10277),
    [2] = GetLanguageStrById(10278),
    [3] = GetLanguageStrById(10279),
    [4] = GetLanguageStrById(12739),
    [5] = GetLanguageStrById(12740),
    [6] = GetLanguageStrById(12741),
    [7] = GetLanguageStrById(10283),    
}
--
function RoleView:OnDamaged(atkRole, dmg, bCrit, finalDmg, damageType, dotType, skill, isForbear,defRole,reduceSheild)

    --反击伤害不计算到总伤害里面
    if skill and skill.skillSubType ~= SkillSubType.BeatBack then
        --LogError(atkRole.roleId.." : " ..SkillSumDamagedValue.."+"..dmg.."="..SkillSumDamagedValue+dmg)
        SkillSumDamagedValue = SkillSumDamagedValue + dmg
    end

    if reduceSheild==nil then
        reduceSheild = 0
    end
    --仅显示护盾显示
    if reduceSheild > 0 then -- dmg <= 0 and 
        if skill and #skill.continueTime > 0 and skill.attackCount > 1 and #skill.continueTime == skill.attackCount - 1 then
            local count = skill.attackCount
            local d = math.floor(reduceSheild / count)
            if count ~= 1 then
                -- 后续伤害延迟打出
                for i = 1, #skill.continueTime do
                    local time = 0
                    for j = 1, i do
                        time = time + skill.continueTime[j]
                    end
                    local bIsLastDamage = i == #skill.continueTime and true or false
    
                    self:DelayFunc(time, function ()
                        if d > 0 then
                            self:OnceDamaged(atkRole, dmg, bCrit, finalDmg, damageType, dotType, skill, bIsLastDamage, isForbear,d)
                        elseif bIsLastDamage then
                            self:OnceDamaged(atkRole, dmg, bCrit, finalDmg, damageType, dotType, skill, bIsLastDamage, isForbear,reduceSheild)
                        end
                    end)
                end
                -- 显示打出第一次护盾
                if d > 0 then
                    local fd = reduceSheild - d * (count - 1)
                    self:OnceDamaged(atkRole, dmg, bCrit, finalDmg, damageType, dotType, skill, false, isForbear,fd)
                end
            else
                self:OnceDamaged(atkRole, dmg, bCrit, finalDmg, damageType, dotType, skill, true, isForbear,reduceSheild)
            end
        else 
            self:OnceDamaged(atkRole, dmg, bCrit, finalDmg, damageType, dotType, skill, true, isForbear,reduceSheild)       
        end
        -- 中断仅走护盾显示
        if dmg <= 0 then 
            return
        end
    end

    if skill and #skill.continueTime > 0 and skill.attackCount > 1 and #skill.continueTime == skill.attackCount - 1 then
        local count = skill.attackCount
        local d = math.floor(dmg / count)
        -- 如果平均伤害小于0 则
        if count ~= 1 then
            -- 后续伤害延迟打出
            for i = 1, #skill.continueTime do
                local time = 0
                for j = 1, i do
                    time = time + skill.continueTime[j]
                end
                local bIsLastDamage = i == #skill.continueTime and true or false

                self:DelayFunc(time, function ()
                    if d > 0 then
                        self:OnceDamaged(atkRole, d, bCrit, finalDmg, damageType, dotType, skill, bIsLastDamage, isForbear)
                    elseif bIsLastDamage then
                        self:OnceDamaged(atkRole, dmg, bCrit, finalDmg, damageType, dotType, skill, bIsLastDamage, isForbear)
                    end
                end)
            end
            -- 立刻打出第一次伤害
            if d > 0 then
                local fd = dmg - d * (count - 1)
                self:OnceDamaged(atkRole, fd, bCrit, finalDmg, damageType, dotType, skill, false, isForbear)
            end
        else
            self:OnceDamaged(atkRole, dmg, bCrit, finalDmg, damageType, dotType, skill, true, isForbear)
        end
    else
        self:OnceDamaged(atkRole, dmg, bCrit, finalDmg, damageType, dotType, skill, true, isForbear)
    end 
    
end
--
function RoleView:OnceDamaged(atkRole, dmg, bCrit, finalDmg, damageType, dotType, skill, isLastDamage, isForbear,reduceSheild)
    if self.isDead then
        return
    end

    if reduceSheild == nil then reduceSheild = 0 end
    --战斗粘滞
    self.RootPanel:BattleSticky()

    if reduceSheild > 0 then
        self:ArtFloating(ArtFloatingType.ShieldDef, ArtFloatingColor.Shiled, reduceSheild, false) 
    else
        if dotType then
            if dotType == DotType.Poison then
                -- self:ArtFloating(ArtFloatingType.PoisonDamage, ArtFloatingColor.Poison, dmg, isForbear)   
                self:TextBuffFloating(2, DotTypeTip[dotType]..dmg)  
            elseif dotType == DotType.Burn then
                self:ArtFloating(ArtFloatingType.FireDamage, ArtFloatingColor.Fire, dmg, isForbear)            
            else
                -- LogError("dot!!"..DotTypeTip[dotType]..dmg)
                self:TextBuffFloating(2, DotTypeTip[dotType]..dmg)
            end
        else    
            if bCrit then   -- 暴击红色并显示暴击
                self:ArtFloating(ArtFloatingType.CritDamage, ArtFloatingColor.Red, dmg, isForbear)
            else
                if atkRole.isTeam then  -- 异妖紫色
                    self:ArtFloating(ArtFloatingType.Damage, ArtFloatingColor.Purple, dmg, isForbear)
                else
                    if skill and skill.type == BattleSkillType.Special then -- 技能黄色
                        self:ArtFloating(ArtFloatingType.Damage, ArtFloatingColor.Yellow, dmg, isForbear)
                    else    -- 普攻白色
                        self:ArtFloating(ArtFloatingType.Damage, ArtFloatingColor.White, dmg, isForbear)
                    end
                end
            end
        end
    end    

    if skill then
        local combat = BattleManager.GetSkillCombat(SkillLogicConfig[skill.id].SkillDisplay)

        -- local strength = Vector3.New(0.8, 0, 0.4)
        -- if combat.isRecoil == 0 then
        --     strength = Vector3.New(0.4, 0, 0.4)
        -- end

        self.RoleLiveGO.transform:DOKill(true)

        local startValue = self.RoleLiveGO.transform.localPosition.x;
        local endValue = self.RoleLiveGO.transform.localPosition.x;

        if self.camp ~= 0 then
            endValue = endValue + 0.6
        else
            endValue = endValue - 0.6
        end

        self.RoleLiveGO.transform.localPosition = Vector3.New(endValue, self.RoleLiveGO.transform.localPosition.y, self.RoleLiveGO.transform.localPosition.z)
        self.RoleLiveGO.transform:DOLocalMoveX(startValue, 0.3):SetEase(Ease.OutQuad)

        if self.RoleLiveGO.name ~= "role_aijiyanhou" and not self.role.leader then
            self:PlaySpineAnim(self.RoleLiveGOGraphic, 0, RoleAnimationName.Injured, false)
        end

        -- self.RoleLiveGO.transform:DOShakePosition(0.3, strength, 50, 10, false, true):OnComplete(
        --     function()
        --         self.RoleLiveGO.transform.localPosition = Vector3.zero
        --     end
        -- )
        if self.DoColor_Spine_Tweener then
            self.DoColor_Spine_Tweener:Kill()
        end
        self.DoColor_Spine_Tweener = Util.DoColor_Spine(self.RoleLiveGOGraphic, Color.New(1, 0, 0, 1), 0.3):OnComplete(
            function()
                self.DoColor_Spine_Tweener = Util.DoColor_Spine(self.RoleLiveGOGraphic, Color.New(1, 1, 1, 1), 0.1)
            end
        )

        self:checkShake(combat)

        self:CheckSkillHitEffect("hit", combat, skill)

        -- 播放受击动画
        if isLastDamage and not self.isDead and not self.role.leader then
            if combat.isDiaup == 1 then
                 self:PlaySpineAnim(self.RoleLiveGOGraphic, 0, RoleAnimationName.Hurt, false)
            end
        end
    end

    --执行死亡动作
    if isLastDamage and not self.isDead then
        if self.isGoDead then
            self:RealDead()
        end
    end
end

function RoleView:OnHealed(castRole)
    if true then
        return
    end

    local go = self:loadAssetForScene(healEffect, self.RoleLiveGO.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition = Vector3.zero--self.GameObject.transform.localPosition
    go:SetActive(true)
    self:AddDelayRecycleRes(healEffect, go, 3)
end

function RoleView:OnRoleCDChanged()
    local go = loadAsset(cdChangedEffect)
    go.transform:SetParent(self.GameObject.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition = self.GameObject.transform.localPosition
    go:SetActive(true)
    self:AddDelayRecycleRes(cdChangedEffect, go, 3)
end


local BuffTypeToConfigType = {
    [BuffName.PropertyChange] = 1,
    [BuffName.Control] = 2,
    [BuffName.DOT] = 3,
    [BuffName.HOT] = 4,
    [BuffName.Shield] = 5,
    [BuffName.Immune] = 6,
    [BuffName.Curse] = 7,
    [BuffName.BEffect] = 8,
    [BuffName.Brand] = 9,
}
function RoleView:GetPropChangeBuffCType(pName)
    for cType, pn in ipairs(BattlePropList) do
        if pn == pName then
            return cType
        end
    end
end
function RoleView:GetBuffEffectConfig(buff)
    local bType = buff.type
    local cType = 1
    if bType == BuffName.PropertyChange then
        cType = self:GetPropChangeBuffCType(buff.propertyName)
    elseif bType == BuffName.HOT then
        cType = 1
    elseif bType == BuffName.DOT then
        cType = buff.damageType
    elseif bType == BuffName.Brand then
        cType = buff.flag
    elseif bType == BuffName.Control then
        cType = buff.ctrlType
    elseif bType == BuffName.Shield then
        cType = buff.shieldType
    elseif bType == BuffName.Immune then
        cType = buff.immuneType
    elseif bType == BuffName.Curse then
        cType = buff.curseType
    elseif bType == BuffName.BEffect then
        cType = buff.bEffectType
    end

    local type = BuffTypeToConfigType[bType]
    
    local config = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.BuffEffectConfig, "Type", type, "CType", cType)
    return config
end


-- 加载并播放动画
function RoleView:AddBuffEffect(buffName, isTrigger, offset)
    
    if not buffName or buffName == "" then
        return 
    end 
    if not self.BuffEffectList then
        self.BuffEffectList = {}
    end
    if not self.BuffEffectList[buffName] then
        self.BuffEffectList[buffName] = {}
        self.BuffEffectList[buffName].node = nil
        self.BuffEffectList[buffName].count = 0
    end
    --
    if not self.BuffEffectList[buffName].node then
        local node = self:loadAssetForScene(buffName, self.RoleLiveGO.transform)
        node.transform.localScale = Vector3.one
        node.transform.localPosition = offset and Vector3.New(offset[1], offset[2], 0) or Vector3.zero
        self.BuffEffectList[buffName].node = node
    end

    --简单播放 不走统一播放特效了
    self.BuffEffectList[buffName].node:SetActive(false)
    self.BuffEffectList[buffName].node:SetActive(true)
    -- 触发特效不计数
    if not isTrigger then
        self.BuffEffectList[buffName].count = self.BuffEffectList[buffName].count + 1
    end
end
-- 卸载动画
function RoleView:RemoveBuffEffect(buffName)
    if not buffName or buffName == "" then
        return 
    end 
    if not self.BuffEffectList then
        return
    end
    if not self.BuffEffectList[buffName] then
        return 
    end
    if not self.BuffEffectList[buffName].node then
        return 
    end
    -- 节点存在，数量不存在直接回收
    if not self.BuffEffectList[buffName].count then
        poolManager:UnLoadAsset(buffName, self.BuffEffectList[buffName].node, PoolManager.AssetType.GameObject)
        self.BuffEffectList[buffName] = nil
        return
    end
    -- 引用数量减1
    self.BuffEffectList[buffName].count = self.BuffEffectList[buffName].count - 1
    if self.BuffEffectList[buffName].count <= 0 then
        poolManager:UnLoadAsset(buffName, self.BuffEffectList[buffName].node, PoolManager.AssetType.GameObject)
        self.BuffEffectList[buffName] = nil
        return
    end
end
-- 卸载所有动画
function RoleView:RemoveAllBuffEffect()
    if not self.BuffEffectList then
        return
    end
    for name, v in pairs(self.BuffEffectList) do
        poolManager:UnLoadAsset(name, v.node, PoolManager.AssetType.GameObject)
    end
    self.BuffEffectList = {}
end

--> 设置buff特效ordering
function RoleView:SetBuffOrdering()
    --> 节点在人物上  所以只取节点的  不取Live的
    local order = self.GameObject.transform.parent:GetComponent("Canvas").sortingOrder

    for name, v in pairs(self.BuffEffectList) do
        Util.SetParticleSortLayer(v.node, order)
    end
end

--> 战斗播放动画期间 buff 隐藏
function RoleView:HideBuff(isHide)
    for name, v in pairs(self.BuffEffectList) do
        v.node:SetActive(not isHide)
    end
end

-- 
function RoleView:AddBuffIcon(buff, icon)
    if not buff or not icon or icon == "" then
        return 
    end 
    if not self.BuffIconList then
        self.BuffIconList = {}
    end
    if not self.BuffIconList[buff.id] then
        local buffGO = BattlePool.GetItem(self.buffRoot.transform, BATTLE_POOL_TYPE.BUFF_VIEW)
        buffGO.transform.localScale = Vector3.one
        buffGO.transform.localPosition = Vector3.zero
        buffGO:SetActive(true)
        self.BuffIconList[buff.id] = BuffView.New(buffGO, buff, icon)
    else
        self.BuffIconList[buff.id].count = self.BuffIconList[buff.id].count + 1
        self.BuffIconList[buff.id]:SetCount()
    end
    
end
function RoleView:RemoveBuffIcon(buff)
    if not buff then
        return 
    end 
    if not self.BuffIconList then
        return
    end
    if self.BuffIconList[buff.id] then
        self.BuffIconList[buff.id]:Dispose()
        self.BuffIconList[buff.id] = nil
    end
end
-- 卸载所有动画
function RoleView:RemoveAllBuffIcon()
    if not self.BuffIconList then
        return
    end
    for id, v in pairs(self.BuffIconList) do
        v:Dispose()
    end
    self.BuffIconList = {}
end


function RoleView:AddBuff(buff,eConfig)  
    if not buff then 
        return 
    end
    if not self.BuffList then
        self.BuffList = {}
    end

    table.insert(self.BuffList,{ Buff = buff,Config = eConfig })
end

function RoleView:RemoveBuff(buff)
    if not buff then
        return 
    end 
    if not self.BuffList then
        return
    end

    local rIndex
    for k, v in ipairs(self.BuffList) do
        if v.Buff == buff then
            rIndex = k
            break
        end
    end

    if rIndex then
        table.remove(self.BuffList, rIndex)
    end
end

function RoleView:RemoveAllBuff()
    if not self.BuffList then
        return
    end
    self.BuffList = {}
end



function RoleView:OnBuffStart(buff)
    
    -- 临时显示
    if buff.type == BuffName.NoDead then
        self:TextBuffFloating(2, GetLanguageStrById(10280))
        return 
    end

    local eConfig = self:GetBuffEffectConfig(buff)
    if not eConfig then return end

    -- LogError(string.format("buff.type:%s DescColorType:%s des:%s",buff.type,eConfig.DescColorType,GetLanguageStrById(eConfig.Describe)))
   
    if buff.type == BuffName.PropertyChange then
        if buff.changeType == 1 or buff.changeType == 2 then
            self:AddBuffEffect(eConfig.Hit)
            self:AddBuffEffect(eConfig.Continue, false, eConfig.ContinueOffset)
            self:TextBuffFloating(eConfig.DescColorType, GetLanguageStrById(eConfig.Describe)..langSpace..GetLanguageStrById(10281))
            self:AddBuffIcon(buff, eConfig.Icon)
            SoundManager.PlayBattleSound(SoundConfig.Sound_Buff)
        else
            self:AddBuffEffect(eConfig.DHit)
            self:AddBuffEffect(eConfig.DContinue)
            self:TextBuffFloating(eConfig.DDescColorType, GetLanguageStrById(eConfig.Describe)..langSpace..GetLanguageStrById(10282))
            self:AddBuffIcon(buff, eConfig.DIcon)
            SoundManager.PlayBattleSound(SoundConfig.Sound_DeBuff)
        end
    else
        self:AddBuffEffect(eConfig.Hit)
        self:AddBuffEffect(eConfig.Continue, false, eConfig.ContinueOffset)
        if eConfig.DescribeIcon and eConfig.DescribeIcon ~= "" then
            self:ImageBuffFloating(eConfig.DescribeIcon)
        else
            self:TextBuffFloating(eConfig.DescColorType, GetLanguageStrById(eConfig.Describe))
        end
        self:AddBuffIcon(buff, eConfig.Icon)
    end



    self:AddBuff(buff,eConfig)
end

-- 
function RoleView:OnBuffDodge(buff)
    if buff.type == BuffName.Control and buff.caster.camp ~= self.camp then
        self:ImageBuffFloating("z_zhandou_dikangzi")
    end
end

-- -- 怒气值改变
-- function RoleView:RoleRageChange(deltaRage)
--     if deltaRage ~= 0 then
--         if deltaRage > 0 then
--             self:ImageBuffFloating("z_zhandou_nuqijia", "z_zhandou_nuqijia_"..deltaRage)

            
--             -- local go = loadAsset(rageEffect)
--             -- go.transform:SetParent(self.GameObject.transform)
--             -- go.transform.localScale = Vector3.one
--             -- go.transform.localPosition = Vector3.zero
--             -- go:SetActive(true)
--             -- self:AddDelayRecycleRes(healEffect, go, 3)
--         else
--             self:TextBuffFloating(1, GetLanguageStrById(10283)..tostring(deltaRage))
--         end
--     end
-- end
-- 
function RoleView:OnBuffRoundChange(buff)
    if self.BuffIconList[buff.id] then
        self.BuffIconList[buff.id]:SetRound(buff)
    end
end

function RoleView:OnBuffCover(buff)
    if self.BuffIconList[buff.id] then
        self.BuffIconList[buff.id]:SetLayer(buff)
    end
end

function RoleView:OnBuffTrigger(buff)
    local eConfig = self:GetBuffEffectConfig(buff)
    if not eConfig then return end
    if buff.type == BuffName.PropertyChange then
        if buff.changeType == 1 or buff.changeType == 2 then
            self:AddBuffEffect(eConfig.Trigger, true)
        else
            self:AddBuffEffect(eConfig.DTrigger, true)
        end
    else
        self:AddBuffEffect(eConfig.Trigger, true)
    end
end

function RoleView:OnBuffEnd(buff)
    -- 临时显示
    if buff.type == BuffName.NoDead then
        return 
    end

    local eConfig = self:GetBuffEffectConfig(buff)
    if not eConfig then return end

    if buff.type == BuffName.PropertyChange then
        if buff.changeType == 1 or buff.changeType == 2 then
            self:RemoveBuffEffect(eConfig.Hit)
            self:RemoveBuffEffect(eConfig.Continue)
            self:RemoveBuffEffect(eConfig.Trigger)
            self:RemoveBuffIcon(buff, eConfig.Icon)
        else
            self:RemoveBuffEffect(eConfig.DHit)
            self:RemoveBuffEffect(eConfig.DContinue)
            self:RemoveBuffEffect(eConfig.DTrigger)
            self:RemoveBuffIcon(buff, eConfig.DIcon)
        end
    else
        self:RemoveBuffEffect(eConfig.Hit)
        self:RemoveBuffEffect(eConfig.Continue)
        self:RemoveBuffEffect(eConfig.Trigger)
        self:RemoveBuffIcon(buff, eConfig.Icon)
       -- LogError("buff"..buff.type.." ico"..eConfig.Icon)
    end

    self:RemoveBuff(buff)
end


function RoleView:OnDead()
    self.isGoDead = true--受击到最后一下时检测,并执行死亡

    if self.hpTween then
        self.hpTween:Kill()
    end
    if self.hpPassTween then
        self.hpPassTween:Kill()
    end
    -- self.hpSlider.fillAmount = 0
    -- self.hpPassSlider.fillAmount = 0
    self.materialPropertyBlock:SetFloat("_HP",0)
    self.hpGo:SetPropertyBlock(self.materialPropertyBlock)
end

-- 暴毙
function RoleView:onBeSecKill()
    self:TextBuffFloating(TextFloatingColor.Red, GetLanguageStrById(10284))
end

--通知死亡
function RoleView:OnRealDead()
    -- self.isGoDead = true--受击到最后一下时检测,并执行死亡
    --血条先隐藏 避免穿帮
    -- self.GameObject:SetActive(false)
end

--执行死亡
function RoleView:RealDead()
    self.isGoDead = false
    self.isPlayDead = true --播放死亡动画
    -- if self.camp == 0 then
    --     Util.SetGray(self.RoleIconGO, true)
    -- else
    self.RoleLiveGO:SetActive(true)
    local order = BattleLogic.CurOrder
    self.GameObject:SetActive(false)
    -- BattleManager.PauseBattle()
    -- self.RoleLiveGOGraphic:DOFade(1, 0):OnComplete(
    --     function()
    --         self.RoleLiveGOGraphic:DOFade(0, 1):OnComplete(
    --             function()
    --                 BattleManager.ResumeBattle()
    --                 self.RoleLiveGOGraphic.color = Color.New(1, 1, 1, 1)
    --                 if order ~= BattleLogic.CurOrder then
    --                     return
    --                 end
    --                 self.GameObject:SetActive(false)
    --                 self.RoleLiveGO:SetActive(false)
    --                 if self.shadow then
    --                     self.shadow:SetActive(false)
    --                 end
    --             end
    --         )
    --     end
    -- )

    local _complete = nil
    _complete = function(state)
        -- BattleManager.ResumeBattle()
        -- self.RoleLiveGOGraphic.color = Color.New(1, 1, 1, 1)
        if order == BattleLogic.CurOrder then
            self.RoleLiveGO:SetActive(false)
            -- if self.shadow then
                -- self.shadow:SetActive(false)
            -- end
        end

        self.isPlayDead = false --播放死亡动画完成

        --死亡动画执行完成,检查是否可复活
        if self.isRelive then
            self:RoleRelive()
        end
    end

    --替换材质
    local spineComponent = self.RoleLiveGOGraphic
    self.spineDeadMaterial = poolManager:LoadAsset("spineDead", PoolManager.AssetType.Other);
    local spineMaterial = spineComponent:GetComponent("MeshRenderer").sharedMaterial
    local customMaterialOverride = spineComponent.CustomMaterialOverride
    self.spineDeadMaterial = Material.New(self.spineDeadMaterial)
    if spineMaterial then
        self.spineDeadMaterial:SetTexture("_MainTex", spineMaterial:GetTexture("_MainTex"))
        customMaterialOverride:Add(spineMaterial, self.spineDeadMaterial);
    
        local startColor = Color.New(0.07843138, 0.145098, 1, 1)
        local endColor = Color.New(startColor.r, startColor.g, startColor.b, 1)
    
        if self.DoColor_Spine_Tweener then
            self.DoColor_Spine_Tweener:Kill()
        end
        self.DoColor_Spine_Tweener = Util.DoColor_Spine(spineComponent, startColor, endColor, 0):OnComplete(
            function()
                startColor.a = 1
                endColor.a = 0
                self.DoColor_Spine_Tweener = Util.DoColor_Spine(spineComponent, startColor, endColor, 0.8):OnComplete(
                    function()
                        Util.SetColor_Spine(spineComponent, Color.New(1, 1, 1, 1))
                        --清除替换材质
                        local customMaterialOverride = spineComponent.CustomMaterialOverride
                        customMaterialOverride:Clear()
    
                        _complete()
                    end
                )
            end
        )
    else--材质找不到直接播放死亡
        LogError(self.RoleLiveGO.name.."     材质球丢了")
        _complete()
    end    
    -- end

    local color = Color.New(75, 75, 75, 255)/255
    Util.SetColor(self.GameObject, color)
    -- Util.SetColor(self.RoleLiveGOGraphic, color)

    -- 回收所有buff相关效果
    self:RemoveAllBuffEffect()
    self:RemoveAllBuffIcon()
    self:RemoveAllBuff()

    -- self.RoleLiveGOGraphic.freeze = true

    self.isDead = true

    -- self.RootPanel:SetShake()
    self.RootPanel:ShakeCamera()

    local effName = "cn2-x1_eff_dead"
    local go = self:loadAssetForScene(effName, self.RootPanel.battleSceneSkillTransform)
    go.transform.localScale = Vector3.one
    go.transform.position = self.RoleLiveGO.transform.position
    go.transform:SetParent(self.RootPanel.skillEffectRoot.transform)
    go:SetActive(true)
    self:AddDelayRecycleRes(effName, go, 3)

    -- local sound = {"n1_snd_destory"}
    -- local soundidx = math.random(1, #sound)
    -- SoundManager.PlaySound(sound[soundidx])

    self.RootPanel:BattleSticky_Param(0.18, 0.5)  -----死亡缓速
end

function RoleView:onRoleRelive()
    self.isRelive = true --标记需要复活
    if self.isDead then 
        if self.isPlayDead then
            --等待死亡动画执行完,就可以复活了
        else
            self:RoleRelive()--直接执行复活
        end
    end
end

function RoleView:RoleRelive()
    self.isDead = false
    self.isRelive = false--已经执行复活了

    --播放复活特效  策划修改了特效的名字需要核对
    local effName = "cn2-x1_buff_fuhuo_elf"
    local effect_relive = self:loadAssetForScene(effName, self.RoleLiveGO.transform.parent)
    effect_relive.transform.localScale = Vector3.one
    effect_relive.transform.localPosition = Vector3.zero
    effect_relive:SetActive(true)
    self:AddDelayRecycleRes(effName, effect_relive, 4)

    --根据特效时机重新显示角色
    self:DelayFunc(0.2,function ()
        self.GameObject:SetActive(true)
        self.RoleLiveGO:SetActive(true)
        self:ResetSpineComponent(self.RoleLiveGOGraphic)
        
        --显示重新显示所有buff
        self:ReliveResetBuffIcon()
    end)

    --文字显示
    self:TextBuffFloating(4, GetLanguageStrById(10285))
end

function RoleView:ReliveResetBuffIcon()   
    local list = BattleLogic.BuffMgr:GetBuff(self.role)
    if #list> 0 then
        for key, buff in pairs(list) do
            if not buff.disperse then
                local eConfig = self:GetBuffEffectConfig(buff)
                self:AddBuffIcon(buff, eConfig.Icon)
            end
        end
    end   
end

function RoleView:OnEnd()
    self.isPlay = false
end

function RoleView:OrderStart()
    self.isPlay = true
end

function RoleView:Dispose()
    -- 清空所有延迟方法
    self:ClearDelayFunc()
    self:ClearLoopFunc()
    self.GameObject.transform.parent.localScale = Vector3.one

    --立即回收延迟列表上的资源
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
    -- 回收所有buff相关效果
    self:RemoveAllBuffEffect()
    self:RemoveAllBuffIcon()
    self:RemoveAllBuff()

    if self.DoColor_Spine_Tweener then
        self.DoColor_Spine_Tweener:Kill()
        self.DoColor_Spine_Tweener = nil
    end
    self.RoleLiveGOGraphic:DOKill()
    RoleView:ResetSpineComponent(self.RoleLiveGOGraphic)
    poolManager:UnLoadSpine(self.livePath, self.RoleLiveGO)

    BattlePool.RecycleItem(self.GameObject, BATTLE_POOL_TYPE.ENEMY_ROLE_2)

    if self.spineDeadMaterial ~= nil then
        GameObject.Destroy(self.spineDeadMaterial)
        self.spineDeadMaterial = nil
    end
end

--重置Spine脚本
function RoleView:ResetSpineComponent(spineComponent)
    Util.SetColor_Spine(spineComponent, Color.white)
    spineComponent.CustomMaterialOverride:Clear()
    spineComponent.AnimationState:ClearEvent_Complete()
    spineComponent.Skeleton:SetToSetupPose()
    spineComponent.AnimationState:ClearTracks()
    spineComponent.AnimationState:SetAnimation(0, RoleAnimationName.Stand, true)
end

---播放粒子特效
function RoleView:PlayParticleSystem(path, go, animationName, delayTime, delayFunc, delType, beforeFunc)
    --显示自动播放粒子特效
    go:SetActive(true)

    --播放特效里的动画
    local sg = Util.GetComponentInChildren(go, "spine-unity", "Spine.Unity.SkeletonAnimation", true)
    if sg ~= nil then
        if not animationName then
            animationName = sg.AnimationName
        end 
        sg.Skeleton:SetToSetupPose()
        sg.AnimationState:ClearEvent_Complete()
        sg.AnimationState:ClearTracks() -- 清除上一个动画的影响（修复概率攻击动画播放错误的问题）
        sg.AnimationState:SetAnimation(0, animationName, false)
    end

    --设置相机
    local effectCamera = go:GetComponent("EffectCamera")
    if effectCamera and effectCamera.effectCamera then
        if effectCamera.CameraAni then
            --获取相机动画时长
            local animator = effectCamera.CameraAni:GetComponent("Animator")
            local animationTime = Util.GetAnimatorTime(animator)
            
            effectCamera.CameraAni.localPosition = Vector3.New(go.transform.position.x * -go.transform.localScale.x, 0, -go.transform.position.z)
            self.RootPanel:SetCameraParent(effectCamera.effectCamera)
            
            self:DelayFunc(animationTime, function ()
                --相机复位
                if effectCamera and effectCamera.effectCamera then
                    if self.RootPanel.camera3D.transform.parent == effectCamera.effectCamera then --如果还是当时设置的父节点,就复位
                        self.RootPanel:SetCameraParent(self.RootPanel.camera3DPos)
                    end
                end
            end)
        else
            LogRed("特效的CameraAni = nil :" .. path)
        end
    end

    self:AddDelayRecycleRes(path, go, delayTime, delayFunc, delType, function()
        if beforeFunc then
            beforeFunc()
        end
    end)
end

--播放特写
function RoleView:PlayCloseup(combat)
    local go = self:loadAssetForScene(combat.Closeup, self.RootPanel.closeupPos)
    go.transform.localPosition = Vector3.zero
    go.transform.localEulerAngles = Vector3.zero
    -- local localScale = Vector3.one
    -- if self.role.camp ~= 0 then
    --     localScale.x = localScale.x * -1
    -- end
    -- go.transform.localScale = localScale

    --更换多语言资源
    local left = Util.GetGameObject(go.gameObject, "Left/fontPos/font"):GetComponent("MeshRenderer").materials[0]
    local right = Util.GetGameObject(go.gameObject, "Right/fontPos/font"):GetComponent("MeshRenderer").materials[0]
    local name = left:GetTexture("_TextureSample0").name
    local newName = GetPictureFont(string.sub(name, 1, #(name)-3))
    local material = poolManager:LoadAsset(newName, PoolManager.AssetType.Other)
    if material == nil then
        LogRed("无" .. newName)
    else
        left:SetTexture("_TextureSample0", material)
        right:SetTexture("_TextureSample0", material)
    end

    local closeupGo = nil

    if self.camp == 0 then
        Util.GetGameObject(go, "Left"):SetActive(true)
        Util.GetGameObject(go, "Right"):SetActive(false)
        closeupGo = Util.GetGameObject(go, "Left")
    else
        Util.GetGameObject(go, "Left"):SetActive(false)
        Util.GetGameObject(go, "Right"):SetActive(true)
        closeupGo = Util.GetGameObject(go, "Right")
    end

    --显示自动播放粒子特效
    go:SetActive(true)

    --播放特效里的动画
    local sg = Util.GetComponentInChildren(closeupGo, "spine-unity", "Spine.Unity.SkeletonAnimation", true)
    if sg ~= nil then
        local animationName = sg.AnimationName
        sg.Skeleton:SetToSetupPose()
        sg.AnimationState:ClearEvent_Complete()
        sg.AnimationState:ClearTracks() -- 清除上一个动画的影响（修复概率攻击动画播放错误的问题）
        sg.AnimationState:SetAnimation(0, animationName, false)
    end

    --设置相机
    local effectCamera = closeupGo:GetComponent("EffectCamera")
    if effectCamera and effectCamera.effectCamera then
        if effectCamera.CameraAni then
            effectCamera.CameraAni.localPosition = Vector3.New(closeupGo.transform.position.x * -closeupGo.transform.localScale.x, 0, -closeupGo.transform.position.z)
            self.RootPanel:SetCameraParent(effectCamera.effectCamera)
        else
            LogRed("特效的CameraAni = nil :" .. path)
        end
    end

    self:AddDelayRecycleRes(combat.Closeup, go, combat.CloseupDuration / 1000, nil, nil, function()
        --相机复位
        if effectCamera and effectCamera.effectCamera then
            self.RootPanel:SetCameraParent(self.RootPanel.camera3DPos)
        end
    end)
end

--播放PV的预制
function RoleView:PlayPVPrefab(pvPath, pvDuration, isLeft)
    local go = self:loadAssetForScene(pvPath, self.RootPanel.pvPos)

    local pvName
    if isLeft then
        pvName = "Left"
    else
        pvName = "Right"
    end
    local pvGo = Util.GetGameObject(go, pvName)

    --显示自动播放粒子特效
    pvGo:SetActive(true)

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