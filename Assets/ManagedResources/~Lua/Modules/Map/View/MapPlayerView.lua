require("Modules/Map/Logic/TileMapView")
local this = {}
local ctrlView = require("Modules/Map/View/MapControllView")

local mapNpcOp = "UI_effect_DiTu_huoguang"
local mapNpc = "live2d_npc_map"
local mapNpc2 = "live2d_npc_map_nv"
local npc, scale
local testAnims = {
    "jingya",
    "lauch",
    "touch"
}
local SkeletonGraphic

-- 设置idel动画时角色是否还在行走
local isRoleWalk = false
local idleFunc = function()
    if this.bLeaderIsIdle and not isRoleWalk and SkeletonGraphic and SkeletonGraphic.AnimationState then
        SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
        SkeletonGraphic.transform.localEulerAngles = Vector3.zero
    end
end
local index = 1
local AnimTimer = Timer.New(function ()
    if SkeletonGraphic and not isRoleWalk and this.leader then
        PlayUIAnim(Util.GetGameObject(this.leader, "root/ui/arrow"))
        SkeletonGraphic.AnimationState:SetAnimation(0, testAnims[index], false)
        index = index + 1
        if index > 3 then
            index = 1
        end
    end
end, 5, -1, true)
local MapPanel
local curDir
local rolePos = 0

-- 血条的长度
local lightLen = {min = -97, max = 96}

function this.InitComponent(gameObject, mapPanel)
    MapPanel = mapPanel
    this.DragCtrl = Util.GetGameObject(gameObject, "Ctrl")
    this.floatblood = Util.GetGameObject(gameObject, "FloatBlood")

end

function this.AddListener()
    -- Game.GlobalEvent:AddEvent(GameEvent.Map.FormationHpChange, this.OnRefreshFormationHp)
    Game.GlobalEvent:AddEvent(GameEvent.Map.Transport, this.OnPosTransport)
    Game.GlobalEvent:AddEvent(GameEvent.FoodBuff.OnFoodBuffStart, this.OnFoodBuffStartRefresh)
    Game.GlobalEvent:AddEvent(GameEvent.FoodBuff.OnFoodBuffEnd, this.RefreshRoleBuff)
    Game.GlobalEvent:AddEvent(GameEvent.Formation.OnResetFormationHp, this.ResetRoleHp)
    Game.GlobalEvent:AddEvent(GameEvent.Formation.OnMapTeamHpReduce, this.ReduceRoleHp)
end

function this.RemoveListener()
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Map.FormationHpChange, this.OnRefreshFormationHp)
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.Transport, this.OnPosTransport)
    Game.GlobalEvent:RemoveEvent(GameEvent.FoodBuff.OnFoodBuffStart, this.OnFoodBuffStartRefresh)
    Game.GlobalEvent:RemoveEvent(GameEvent.FoodBuff.OnFoodBuffEnd, this.RefreshRoleBuff)
    Game.GlobalEvent:RemoveEvent(GameEvent.Formation.OnResetFormationHp, this.ResetRoleHp)
    Game.GlobalEvent:RemoveEvent(GameEvent.Formation.OnMapTeamHpReduce, this.ReduceRoleHp)
end

function this.Init(pos,num)
    local u, v = Map_Pos2UV(pos)
    --(角色身上的数据, 主要是位置信息)
    this.leaderMapData = TileMapView.GetMapData():GetMapData(u, v)
    MapManager.curMapBornPos = Map_UV2Pos(this.leaderMapData.u, this.leaderMapData.v)

    if num ==1 then
        this.InitRolePre(u, v)
    end
    -- SkeletonGraphic = Util.GetGameObject(this.leader, "root/ui/roleRoot/npc"):GetComponent("SkeletonGraphic")
    -- SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idleFunc
    -- SkeletonGraphic.AnimationState:SetAnimation(0, "lauch", false)
    -- SkeletonGraphic.transform.localEulerAngles = Vector3.zero
    AnimTimer:Start()
    this.leader:SetActive(true)
    TileMapView.CameraTween(this.leaderMapData.u, this.leaderMapData.v, 0.4)
    PlayUIAnim(this.leader, function ()
        MapPanel.RefreshShow()
        --TileMapView.CameraTween(this.leaderMapData.u, this.leaderMapData.v, 0.5)
        TileMapView.UpdateWarFog(u, v, MapManager.fogSize)
        this.bLeaderIsIdle = true
        Game.GlobalEvent:DispatchEvent(GameEvent.Guide.MapInit)
        PlayUIAnim(Util.GetGameObject(this.leader, "root/ui/arrow"))
    end)
    Util.GetGameObject(this.leader, "root/ui/arrow/Image"):GetComponent("Image").sprite=GetPlayerHeadSprite(PlayerManager.head)
    this.RefreshOption()
    -- 刷新buff显示
    this.ResetBuffShow()
    this.RefreshRoleBuff()

    this.ShowPos(u, v)

    -- 刷新队伍血量
    -- this.OnRefreshFormationHp()
    isRoleWalk = false
end

function this.OnShow()
    -- 初始化未完成前，组件为空
    if not this.roleRedHp or not this.roleYellowHp then
        return
    end

    -- 刚进图时或者从战斗界面退出来时不刷新
    if not MapManager.FirstEnter and not EndLessMapManager.isOpenedFullPanel then
        -- this.OnRefreshFormationHp()
    end

    if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        -- 在地图里打开全屏界面需要重新激活小人状态
        if EndLessMapManager.isOpenedFullPanel then
            this.PlayerIdle()
            EndLessMapManager.isOpenedFullPanel = false
        end
    end
end

function this.InitRolePre(u, v)
    this.leader = poolManager:LoadAsset(mapNpcOp, PoolManager.AssetType.GameObject)
    this.leader:SetActive(false)
    Util.GetGameObject(this.leader, "root/ui"):GetComponent("Canvas").worldCamera = TileMapView.GetCamera()
    local v3 = TileMapView.GetLiveTilePos(u, v)
    this.leader.transform.localPosition = Vector3(v3.x, v3.y, v3.z - 10)
    this.leader.transform.localScale = Vector3.one * 1.5

    npc = NameManager.roleSex == ROLE_SEX.BOY and mapNpc or mapNpc2
    scale = NameManager.roleSex == ROLE_SEX.BOY and Vector3.one or Vector3.one * 0.5
    -- this.NpcGO = poolManager:LoadLive(npc, Util.GetTransform(this.leader, "root/ui/roleRoot"), scale, Vector3.zero)
    -- this.NpcGO.name = "npc"
end

function this.RefreshOption()
    --坐标显示
    this.PosText = Util.GetGameObject(this.leader, "root/ui/pos"):GetComponent("Text")
    Util.GetGameObject(this.leader, "root/ui/pos"):SetActive(true)

    --行动力显示
    this.energyProImg = Util.GetGameObject(this.leader, "root/ui/actionProgress/progress")
    this.energyMaxText = Util.GetGameObject(this.leader, "root/ui/actionProgress/maxEnergy")
    this.energyText = Util.GetGameObject(this.energyMaxText, "energy")

    this.NpcCloseOpBtn = Util.GetGameObject(this.leader, "root/ui/optionCancelBtn")
    this.NpcOption = Util.GetGameObject(this.leader, "root/ui/roleOption")

    -- 总血量显示
    this.roleYellowHp = Util.GetGameObject(this.leader, "root/ui/blood/hpYellow"):GetComponent("Image")
    this.roleRedHp = Util.GetGameObject(this.leader, "root/ui/blood/hpRed"):GetComponent("Image")
    this.hpLight = Util.GetGameObject(this.leader, "root/ui/blood/light")
    Util.GetGameObject(this.leader, "root/ui/blood"):SetActive(false)

    -- 状态特效的节点
    this.buffEffectRoot = Util.GetGameObject(this.leader, "root/ui/roleRoot/effectRoot")
    this.battleEffect = Util.GetGameObject(this.leader, "root/ui/quickBattleEffect")
    Util.GetGameObject(this.leader, "root/ui/Dialogue"):SetActive(false)

    this.buffEffectRoot:SetActive(true)
    Util.SetParticleScale(this.buffEffectRoot, 2) -- buff特效变为原来的两倍，并在释放时还原

    this.NpcOption:SetActive(false)
    this.NpcCloseOpBtn:SetActive(false)
    this.SetBattleState(false)

    -- 自带的对话框
    this.dialogueRoot = Util.GetGameObject(this.leader, "root/ui/Dialogue")
    this.context = Util.GetGameObject(this.leader, "root/ui/Dialogue/Text"):GetComponent("Text")
    this.dialogueRoot:SetActive(false)


    -- -- 如果角色还在死亡
    -- if MapManager.deadTime > 0 then
    --     MapPanel.OnMapDeadOut(MapManager.deadTime)
    -- else
    --     MapPanel.deadRoot:SetActive(false)
    -- end

    Util.AddOnceClick(this.NpcCloseOpBtn, function()
        this.NpcCloseOpBtn:SetActive(false)
        this.NpcOption:SetActive(false)
        this.DragCtrl:SetActive(true)
    end)

end

-- 点击角色
function this.OnClick()

end

-- ================== 与角色相关的其他表现 ==========================================================
-- 角色在图内传送
function this.OnPosTransport(nextPos)
    -- 角色停止行走，不然会继续触发事件
    ctrlView.OnRoleDead()


    local callBack = function()
        if nextPos ~= 0 then
            local u, v = Map_Pos2UV(nextPos)
            local v3 = TileMapView.GetLiveTilePos(u, v)

            this.leader.transform.localPosition = Vector3(v3.x, v3.y, v3.z - 10)
            this.leaderMapData = TileMapView.GetMapData():GetMapData(u, v)

            local v3 = this.leader.transform.localPosition
            v3.z = TileMapView.ViewCameraPos.z
            TileMapView.SetCameraPos(v3)
            TileMapView.UpdateBaseData()
            MapPanel.RefreshShow()

            ctrlView.SetCtrlState(false)
            -- 刷新迷雾
            TileMapView.UpdateWarFog(u, v, MapManager.fogSize)
        end
    end

    SwitchPanel.PlayTransEffect(callBack)
end

function this.ShowPos(u, v)
    rolePos = Map_UV2Pos(u, v)
    MapTrialManager.SetRolePos(u, v)
    EndLessMapView.OnRoleMove(u, v)
    this.PosText.text = string.format("(%d, %d)", u, v)
end


-- =============== 角色自身状态   ==================================================
-- 初始化角色血条
function this.InitRoleHp(relife)

    this.roleYellowHp.gameObject:SetActive(relife)
    this.roleRedHp.gameObject:SetActive(not relife)

    if relife then
        this.roleYellowHp.fillAmount = 1
        this.roleRedHp.fillAmount = 1
        this.hpLight:GetComponent("RectTransform").anchoredPosition =Vector2.New(lightLen.max, 0)
    else
        this.roleYellowHp.fillAmount = 0
        this.roleRedHp.fillAmount = 0
        this.hpLight:GetComponent("RectTransform").anchoredPosition =Vector2.New(lightLen.min, 0)
    end
end

function this.OnRefreshFormationHp()
    -- 刷新队伍血量百分比
    local curHp = 0
    local maxHp = 0
    
    for i=1, #MapManager.formationList do
        
        
        curHp = MapManager.formationList[i].allProVal[2] + curHp
        maxHp = maxHp + MapManager.formationList[i].allProVal[3]
    end
    local percent = 0

    if curHp > 0 and maxHp > 0 then
        percent = curHp / maxHp
    else
        percent = 0
    end

   
   

    percent = percent <= 0 and 0 or percent
    local isRedHp = percent <= 0.2

    this.roleRedHp.gameObject:SetActive(isRedHp)
    this.roleYellowHp.gameObject:SetActive(not isRedHp)


    if not isRedHp then
        this.roleYellowHp.fillAmount = percent
    else
        this.roleRedHp.fillAmount = percent / 0.2
    end
    local len = lightLen.max - lightLen.min
    len = len * percent
    this.hpLight:GetComponent("RectTransform").anchoredPosition =Vector2.New(lightLen.min + len, 0)
end

-- 角色满血复活
function this.ResetRoleHp(intPos)
    MapManager.InitFormationHp()
    -- 检查一下队伍是否有人
    if FormationManager.CheckFormationValid(FormationTypeDef.FORMATION_ENDLESS_MAP) then
        this.InitRoleHp(true)
    end

    -- 同时设置一下重置的位置
    this.SetRolePos(intPos)
end
---=========================  角色buff显示相关================
--
function this.OnFoodBuffStartRefresh(buffId)
    local buffInfo = ConfigManager.GetConfigData(ConfigName.FoodsConfig, buffId)
    this.ShowBuffEffect(buffInfo.EffectShow)
end

-- 刷新角色身上的Buff特效状态
function this.RefreshRoleBuff()
    -- 判断是否有buff
    local buffList = FoodBuffManager.GetAllBuffList()
    local buffLen = #buffList
    -- 没有buff，关闭buff显示
    if buffLen == 0 then
        this.ShowBuffEffect(0)
        return
    end

    -- 找到当前需要显示的特效id
    local effectId = 0
    for i = buffLen, 1, -1 do
        local finalBuff = buffList[i]
        local buffInfo = ConfigManager.GetConfigData(ConfigName.FoodsConfig, finalBuff.ID)
        if buffInfo.EffectShow then
            local config = MapPlayerEffectConfig[buffInfo.EffectShow]
            if config.type ~= 1 then    -- 瞬时特效不显示
                effectId = buffInfo.EffectShow
                break
            end
        end
    end
    this.ShowBuffEffect(effectId)
end

-- 显示buff特效
function this.ShowBuffEffect(effectId)
    -- 特效id正确性检测
    if not effectId then return end

    -- 判断特效类型
    local config = MapPlayerEffectConfig[effectId]
    if config.type == 0 then        -- 播放空特效，顶替常驻特效
        if this.lastEffect then
            this.lastEffect:SetActive(false)
        end

    elseif config.type == 1 then    -- 播放瞬时特效
        local shortEffect = Util.GetGameObject(this.buffEffectRoot, config.name)
        shortEffect:SetActive(false)
        shortEffect:SetActive(true)

    elseif config.type == 2 then    -- 常驻特效
        if this.lastEffect then
            this.lastEffect:SetActive(false)
        end
        this.lastEffect = Util.GetGameObject(this.buffEffectRoot, config.name)
        this.lastEffect:SetActive(true)
    end
end

-- 重置隐藏buff特效
function this.ResetBuffShow()
    for _, effect in pairs(MapPlayerEffectConfig) do
        if effect and effect.name and effect.name ~= "" then
            local node = Util.GetGameObject(this.buffEffectRoot, effect.name)
            if node then
                node:SetActive(false)
            end
        end
    end
end

-- 设置战斗特效
function this.SetBattleState(state)
    this.battleEffect:SetActive(state)
end

-- 设置血量减少的表现
function this.ReduceRoleHp(reduceHp)
    if reduceHp > 0 then
        local u, v = Map_Pos2UV(rolePos)
        local v2 = RectTransformUtility.WorldToScreenPoint(TileMapView.GetCamera(), TileMapView.GetLiveTilePos(u, v))
        v2 = v2 / math.min(Screen.width/1080, Screen.height/1920)

        this.floatblood:GetComponent("RectTransform").anchoredPosition = v2 + Vector2.New(0, 50)

        this.floatblood:SetActive(true)
        Util.GetGameObject(this.floatblood, "Text"):GetComponent("Text").text = "-" .. reduceHp

        this.floatblood:GetComponent("RectTransform"):DOAnchorPos(v2 + Vector2.New(0, 500), 1.5, false):OnComplete(function ()

        end)

        PlayUIAnim(this.floatblood, function ()
            this.floatblood:SetActive(false)
            this.floatblood:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
        end)
    end
end



-- ========================== 角色行走管理 ==========================================
-- 设置角色行走方向
local WALK_DIR = {
    RIGHT = {animation = "move2", y = 0},
    LEFT = {animation = "move2", y = 180},
    UP = {animation = "move3", y = 0},
    DOWN = {animation = "move", y = 0},
}

function this.SetRoleDirAction(u, v, isBack)
    local dU = isBack and this.leaderMapData.u - u or u - this.leaderMapData.u
    local dV = isBack and this.leaderMapData.v - v or v - this.leaderMapData.v

    if dU > 0 then
        this.SetWalkDir(WALK_DIR.RIGHT)
    elseif dU < 0 then
        this.SetWalkDir(WALK_DIR.LEFT)
    elseif dV < 0 then
        this.SetWalkDir(WALK_DIR.UP)
    elseif dV > 0 then
        this.SetWalkDir(WALK_DIR.DOWN)
    end
    SoundManager.PlaySound(SoundConfig.Sound_FootStep..math.random(1,7))
end

function this.SetWalkDir(dir)
    isRoleWalk = true
    if not curDir or curDir ~= dir then
        curDir = dir
        if SkeletonGraphic then
            SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, dir.y, 0)
            SkeletonGraphic.AnimationState:SetAnimation(0, dir.animation, true)
        end
    end

end

function this.SetRoleBattleAction()
    curDir = nil
    if SkeletonGraphic then
        SkeletonGraphic.AnimationState:SetAnimation(0, "jingya", false)
        SkeletonGraphic.transform.localEulerAngles = Vector3.zero
    end
end

-- 设置角色的位置
function this.SetRolePos(lastPos)

    if lastPos ~= 0 then
        local u, v = Map_Pos2UV(lastPos)
        local v3 = TileMapView.GetLiveTilePos(u, v)

        if CarbonManager.difficulty ~= 4 then
            this.SetRoleDirAction(u, v, true)
        end

        this.leader.transform.localPosition = Vector3(v3.x, v3.y, v3.z - 10)
        this.leaderMapData = TileMapView.GetMapData():GetMapData(u, v)
        if not this.leaderMapData then
            this.leaderMapData = TileMapView.GetMapData():GetMapData(u, v)
        end


        local v3 = this.leader.transform.localPosition
        v3.z = TileMapView.ViewCameraPos.z
        TileMapView.SetCameraPos(v3)
        TileMapView.UpdateBaseData()

        -- 传送显示事件点
        MapPanel.RefreshShow()


        --  无尽副本是复位时同步一下显示
        this.PosText.text = string.format("(%d, %d)", u, v)

    end
end

function this.PlayerIdle()
    this.bLeaderIsIdle = true
    AnimTimer:Start()
    if SkeletonGraphic and SkeletonGraphic.AnimationState then
        SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
        SkeletonGraphic.transform.localEulerAngles = Vector3.zero
    end
    curDir = nil
    isRoleWalk = false
end

function this.PlayerMove()
    this.bLeaderIsIdle = false
    AnimTimer:Stop()
end

-- =================================================================================
function this.Dispose()

    AnimTimer:Stop()

    -- if this.NpcGO then
    --     SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idleFunc
    --     poolManager:UnLoadLive(npc, this.NpcGO)
    -- end
    if this.leader then
        poolManager:UnLoadAsset(mapNpcOp, this.leader, PoolManager.AssetType.GameObject)
    end
    this.leader = nil
    -- this.NpcGO = nil
    -- SkeletonGraphic = nil

    -- buff
    if this.buffEffectRoot then
        Util.SetParticleScale(this.buffEffectRoot, 0.5) -- 重置buff特效回原大小
    end
    this.ResetBuffShow()
    this.lastEffect = nil
end

return this