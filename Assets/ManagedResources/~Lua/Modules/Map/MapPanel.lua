require("Base/BasePanel")
require("Modules/Map/Logic/TileMapController")
require("Modules/Map/Logic/TileMapView")
require("Modules/Map/View/MapPointView")


MapPanel = Inherit(BasePanel)
local this = MapPanel
local ChallengeMapConfig = ConfigManager.GetConfig(ConfigName.ChallengeMapConfig)
local DifficultyData = ConfigManager.GetConfig(ConfigName.ChallengeConfig)
local missionView = require("Modules/Map/View/MapMissionView")
local ctrlView = require("Modules/Map/View/MapControllView")
local playerView = require("Modules/Map/View/MapPlayerView")
local trialPanel = require("Modules/Map/TrialMapPanel")
local eliteMissionView = require("Modules/Map/View/CarbonMissionTypeView")
local endLessMapView = require("Modules/Map/View/EndLessMapView")
local pointHandleView = require("Modules/Map/View/PointHandleView")
local EventPointConfig = ConfigManager.GetConfig(ConfigName.EventPointConfig)
local MonsterGroupConfig = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local MonsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)

local _PropItemList = {}
local _PointerDownList = {}
local _PointerUpList = {}
this.mainList = {}

--============================== HUD 环绕入场 ==============================
-- 进图 / 换层时，贴边的 HUD 各自从「最近的那条边」滑进来，替掉原来「一次性齐刷刷冒出来」的死板开场。
-- 与 ui_item_slide_in_skill.md 那份列表配方同源（一侧滑入 + 逐格错开），三处差别：
--   ① 载体不是列表项，而是 9 个贴边容器 ⇒ 方向按各自锚点定（上/下/左/右），不是统一从右侧；
--   ② 只播一次入场、不做常驻循环 —— 地图里 HUD 一直动会干扰走格子；
--   ③ 这些容器里装着按钮，按钮自带 CommonButton 的 Animator（Normal 是单帧写 localScale=1），
--      Animator 在 Update 之后求值 ⇒ 给这种节点写 scale 每帧会被盖回去，所以「自带 Animator 的只写位置」。
local kHudDuration  = 0.26   -- 单组时长
local kHudStep      = 0.05   -- 相邻组的错开
local kHudFromScale = 0.94   -- 起始缩放（只给没有 Animator 的纯容器）
-- { 节点名, 方向, 位移量 }，表顺序 = 播放顺序（可见的才占一格延迟）
local kHudGroups = {
    { "leftUp",       "up",    64 },  -- 关卡名 / 进度（贴顶）
    { "endLessTitle", "up",    56 },  -- 无尽副本标题（只有无尽模式才激活）
    { "rightUp",      "right", 96 },  -- 返回 / 背包 / 队伍
    { "leftCenter",   "left",  88 },  -- 排行 / 奖励
    { "helpBtn",      "right", 88 },
    { "rightDown",    "right", 96 },  -- 技能 / 道具
    { "centerDown",   "down",  88 },  -- 时间 / buff / 返回
    { "btnJump",      "down",  56 },  -- 跳过战斗
    { "btnAutoJian",  "down",  56 },  -- 自动拾取
}
local hudAnimItems = {}   -- { rect=, tf=, x=, y=, sx=, sy=, sz=, tween=, scaleTween= }

-- tolua 的枚举表是运行期注册的，取不到就不设：否则整段被 pcall 吃掉、什么都不动
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then
        tween:SetEase(value)
    end
    return tween
end

-- UnityEngine.Object 在 lua 侧是 userdata：Destroy 之后既不是 nil 也不能直接取字段
local function HudAlive(obj)
    if obj == nil then
        return false
    end
    if type(obj) == "userdata" then
        return not IsNull(obj)
    end
    return true
end

-- 该节点自带的 Animator（按钮几乎都有 CommonButton）：有就不写 scale 通道
local function HudHasOwnAnimator(go)
    if not HudAlive(go) then
        return false
    end
    local ok, anim = pcall(function()
        return go:GetComponent("Animator")
    end)
    if not ok or anim == nil then
        return false
    end
    if type(anim) == "userdata" then
        return not IsNull(anim)
    end
    return true
end

-- 回收全部入场 tween，并把位置 / 缩放复位。
-- 🔴 位置和缩放都要复位：只复位位置 = 容器永久停在 0.94；只 Kill 不复位 = 停在中途。
function this.StopHudSlideIn()
    for i = #hudAnimItems, 1, -1 do
        local item = hudAnimItems[i]
        if HudAlive(item.tween) then
            item.tween:Kill(false)
        end
        if HudAlive(item.scaleTween) then
            item.scaleTween:Kill(false)
        end
        if HudAlive(item.rect) then
            item.rect.anchoredPosition = Vector2.New(item.x, item.y)
        end
        if HudAlive(item.tf) then
            item.tf.localScale = Vector3.New(item.sx, item.sy, item.sz)
        end
        hudAnimItems[i] = nil
    end
end

-- 进图 / 换层：可见的 HUD 容器按表顺序从各自那条边滑回原位（一次性，总跨度约 0.66s）。
-- 未激活的容器直接跳过（数量随副本类型变：无尽标题、战斗类按钮都是按类型 SetActive）。
function this.PlayHudSlideIn()
    this.StopHudSlideIn()
    local order = 0
    local ok, err = pcall(function()
        for i = 1, #kHudGroups do
            local cfg = kHudGroups[i]
            local go = Util.GetGameObject(this.gameObject, cfg[1])
            if HudAlive(go) and go.activeSelf then
                local rect = go:GetComponent("RectTransform")
                local tf = go.transform
                if HudAlive(rect) and HudAlive(tf) then
                    local pos, scale = rect.anchoredPosition, tf.localScale
                    local dx, dy = 0, 0
                    if cfg[2] == "left" then
                        dx = -cfg[3]
                    elseif cfg[2] == "right" then
                        dx = cfg[3]
                    elseif cfg[2] == "up" then
                        dy = cfg[3]
                    else
                        dy = -cfg[3]
                    end
                    local delay = order * kHudStep
                    local item = { rect = rect, tf = tf, x = pos.x, y = pos.y,
                                   sx = scale.x, sy = scale.y, sz = scale.z }
                    rect.anchoredPosition = Vector2.New(pos.x + dx, pos.y + dy)
                    local tween = rect:DOAnchorPos(Vector2.New(pos.x, pos.y), kHudDuration)
                    tween:SetDelay(delay)
                    SetEaseSafe(tween, "OutCubic")
                    tween:OnComplete(function()
                        if HudAlive(rect) then
                            rect.anchoredPosition = Vector2.New(pos.x, pos.y)
                        end
                    end)
                    item.tween = tween
                    if not HudHasOwnAnimator(go) then
                        tf.localScale = Vector3.New(scale.x * kHudFromScale,
                                                    scale.y * kHudFromScale, scale.z)
                        local scaleTween = tf:DOScale(Vector3.New(scale.x, scale.y, scale.z), kHudDuration)
                        scaleTween:SetDelay(delay)
                        SetEaseSafe(scaleTween, "OutCubic")
                        scaleTween:OnComplete(function()
                            if HudAlive(tf) then
                                tf.localScale = Vector3.New(scale.x, scale.y, scale.z)
                            end
                        end)
                        item.scaleTween = scaleTween
                    end
                    hudAnimItems[#hudAnimItems + 1] = item
                    order = order + 1
                end
            end
        end
    end)
    if not ok then
        LogError("MapPanel: HUD 入场失败 " .. tostring(err))
        this.StopHudSlideIn()
        return 0
    end
    return order
end

--初始化组件（用于子类重写）
function this:InitComponent()

    -- 通用图标
    -- this.Bg = Util.GetGameObject(self.gameObject,"Bg")
    this.main = Util.GetGameObject(self.gameObject,"Scroll/main")
    this.mainLeftTop = Util.GetGameObject(self.gameObject,"main/LeftTop")
    this.mainRightTop = Util.GetGameObject(self.gameObject,"main/RightTop")
    this.mainLeftBottom = Util.GetGameObject(self.gameObject,"main/LeftBottom")
    this.mainRightBottom = Util.GetGameObject(self.gameObject,"main/RightBottom")
    this.BtnBack = Util.GetGameObject(self.gameObject, "centerDown/bg/btnBack")
    this.btnAchive = Util.GetGameObject(self.gameObject, "rightDown/btnAchive")
    this.btnBag = Util.GetGameObject(self.gameObject, "rightUp/btnBag")
    this.btnTeam = Util.GetGameObject(self.gameObject, "rightUp/btnTeam")
    -- this.btnSetting = Util.GetGameObject(self.gameObject, "rightUp/btnSetting")
    -- this.btnSetting.SetActive(false)
    this.btnRank = Util.GetGameObject(self.gameObject, "leftCenter/btnRank")
    this.btnXingYao = Util.GetGameObject(self.gameObject,"rightDown/btnXingYao")
    this.xingYaoNum = Util.GetGameObject(this.btnXingYao,"num"):GetComponent("Text")
    this.btnReward = Util.GetGameObject(self.gameObject,"leftCenter/btnReward")

    -- this.btnXingYao = Util.GetGameObject(self.gameObject,"rightDown/btnXingYao")
    this.btnBomb = Util.GetGameObject(self.gameObject,"rightDown/btnBomb")
    this.btnBuff = Util.GetGameObject(self.gameObject,"rightDown/buff")
    -- this.slwxUI = Util.GetGameObject(self.gameObject,"")
    this.btnShop = Util.GetGameObject(self.gameObject,"rightDown/shop")
    this.btnReset = Util.GetGameObject(self.gameObject,"rightDown/btnReset")
    this.btnFormat = Util.GetGameObject(self.gameObject,"rightDown/btnFormat")
    this.btnNode = Util.GetGameObject(self.gameObject,"rightDown/btnNote")

    this.item = Util.GetGameObject(self.gameObject, "item")
    this.selectHero = Util.GetGameObject(self.gameObject, "centerDown/selectHero")
    this.selectHero:SetActive(false)


    -- buff显示
    this.propList = Util.GetGameObject(self.transform, "centerDown/bufflist")
    this.propBox = Util.GetGameObject(this.propList, "box")
    this.propItem = Util.GetGameObject(this.propBox, "buff")
    this.propInfo = Util.GetGameObject(this.propList, "info")
    this.propContent = Util.GetGameObject(this.propList, "info/Text"):GetComponent("Text")
    this.propInfo:SetActive(false)
    this.propList:SetActive(true)

    -- 面板遮罩, 没有接地图任务前不可点击
    this.Mask = Util.GetGameObject(self.gameObject, "Mask")

    -- 试炼副本相关组件
    -- this.leftUp = Util.GetGameObject(self.gameObject, "leftUp")
    -- this.oleLeftUp = Util.GetGameObject(self.gameObject, "LeftUp")
    this.centerDonwn = Util.GetGameObject(self.gameObject, "centerDown")

    this.endLessTitle = Util.GetGameObject(self.gameObject, "endLessTitle")
    --按钮
    this.btnJump = Util.GetGameObject(self.gameObject, "btnJump")  --跳过战斗
    this.btnJumpChoose = Util.GetGameObject(self.gameObject, "btnJump/choose")
    this.btnJumpChoose:SetActive(false)
    this.btnAutoJian = Util.GetGameObject(self.gameObject, "btnAutoJian")  --自动拾取
    this.btnAutoJianChoose = Util.GetGameObject(self.gameObject, "btnAutoJian/choose")
    this.btnAutoJianChoose:SetActive(false)
    -- this.endLessRate = Util.GetGameObject(self.gameObject, "endLessRate")
    -- for u=1,5,1 do
    --     for v=1,11,1 do
    --         local li=((i-1)*5)+j
    --         this.mainList[j][i]=Util.GetGameObject(this.main,"mainPoint"..li)
    --     end
    -- end
    for u = 1, MapManager.TrialMaxU do
        for v = 1, MapManager.TrialMaxV do
            local idx = (v - 1) * MapManager.TrialMaxU + u
            local node = Util.GetGameObject(this.main, "mainPoint" .. idx)
            if node ~= nil then
                if this.mainList[u] == nil then
                    this.mainList[u] = {}
                end
                this.mainList[u][v] = node
            end
        end
    end
    
    missionView.InitComponent(self.gameObject, this)
    playerView.InitComponent(self.gameObject, this)
    ctrlView.InitComponent(self.gameObject, this, playerView)
    trialPanel:InitComponent(self.gameObject, this)
    endLessMapView:InitComponent(self.gameObject, this)
end

function this:OnSortingOrderChange()
    trialPanel.OnSortingOrderChange()
    endLessMapView:OnSortingOrderChange()
end
--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.BtnBack, function ()
        if ctrlView.GetCallListCount() > 1 then
            PopupTipPanel.ShowTipByLanguageId(11232)
            return
        end
        this.SetEliteBackShow()
        this.SetEndlessShow()
    end)
    Util.AddClick(this.btnJump, function ()
        MapManager.isJump = not MapManager.isJump
           if MapManager.isJump then
               this.btnJumpChoose:SetActive(true)
           else
               this.btnJumpChoose:SetActive(false)
           end
   end)
   Util.AddClick(this.btnAutoJian, function ()
        MapManager.isAutoJian = not MapManager.isAutoJian
        if MapManager.isAutoJian then
            this.btnAutoJianChoose:SetActive(true)
        else
            this.btnAutoJianChoose:SetActive(false)
        end
    end)
    -- 功绩按钮
    Util.AddClick(this.btnAchive, function ()
        UIManager.OpenPanel(UIName.EliteCarbonAchievePanel, MapManager.GetCurCarbonId(), false, 1)
    end)
    --排行
    Util.AddClick(this.btnRank, function ()
        UIManager.OpenPanel(UIName.CarbonScoreSortPanel,1)
    end)

    --奖励
    Util.AddClick(this.btnReward,function()
        UIManager.OpenPanel(UIName.TrialRewardPopup)
    end)

    missionView.BindEvent()
    trialPanel:BindEvent()
    endLessMapView:BindEvent()
end

-- ================ 点击回城时一些稀里糊涂的操作 ======
-- 精英副本
function this.SetEliteBackShow()
    if CarbonManager.difficulty == 3 then
        eliteMissionView:OnBackBtnClick()
    end
end

-- 无尽副本
function this.SetEndlessShow()
    -- 无尽副本的回城设置
    if CarbonManager.difficulty == 4 then
        endLessMapView:OnClose()
        -- 先看看是否是能回去
        -- if  not EndLessMapManager.IsMapTeamAlive()then
        --     PopupTipPanel.ShowTipByLanguageId(11233)
        --     return
        -- end

        -- 先发更新事件点协议
        -- MapManager.MapUpdateEvent(-1000, function ()
        
        --     NetManager.RequestEndLessStats(function ()
        --         UIManager.OpenPanel(UIName.MapStatsPanel, true)
        --     end)
        -- end)
        MapManager.MapUpdateEvent(-1000, function ()
           
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out,0)
        end)
    else
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out,0)
    end
end
-- ===============================================
--添加事件监听（用于子类重写）
function this:AddListener()

    Game.GlobalEvent:AddEvent(GameEvent.Map.Out, this.OnMapOut)
    Game.GlobalEvent:AddEvent(GameEvent.Map.DeadOut, this.OnMapDeadOut)
    Game.GlobalEvent:AddEvent(GameEvent.Map.MapDataChange, this.OnMapDataChange)
    Game.GlobalEvent:AddEvent(GameEvent.Map.StopWalk, this.StopWalking)
    Game.GlobalEvent:AddEvent(GameEvent.FoodBuff.OnFoodBuffStateChanged, this.RefreshBuffShow)
    Game.GlobalEvent:AddEvent(GameEvent.Map.ClearCtrl, this.ClearCtrl)
    -- Game.GlobalEvent:AddEvent(GameEvent.Map.MaskState, this.MaskState)

    missionView.AddListener()
    playerView.AddListener()
    ctrlView.AddListener()

    trialPanel:AddListener()
    endLessMapView:AddListener()
    pointHandleView.AddListener()

end

--移除事件监听（用于子类重写）
function this:RemoveListener()

    Game.GlobalEvent:RemoveEvent(GameEvent.Map.Out, this.OnMapOut)
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.DeadOut, this.OnMapDeadOut)
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.MapDataChange, this.OnMapDataChange)
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.StopWalk, this.StopWalking)
    Game.GlobalEvent:RemoveEvent(GameEvent.FoodBuff.OnFoodBuffStateChanged, this.RefreshBuffShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.ClearCtrl, this.ClearCtrl)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Map.MaskState, this.MaskState)

    missionView.RemoveListener()
    playerView.RemoveListener()
    ctrlView.RemoveListener()

    trialPanel:RemoveListener()
    endLessMapView:RemoveListener()
    pointHandleView.RemoveListener()
end

function this:OnShow()
    UIManager.camera.clearFlags = CameraClearFlags.Depth
    local mapId = MapManager.curMapId
    
    --- 副本地图音效统一改成一个
    SoundManager.PlayMusic(SoundConfig.BGM_CarbonMap)
    -- 环境音
    local amb = ChallengeMapConfig[mapId].EnvironmentSound
    if amb and amb ~= "" then
        SoundManager.PlayAmbient(amb)
    end
    -- this.mapSlidleData()
    playerView.OnShow()
    endLessMapView:OnShow()
    pointHandleView.OnShow()
    trialPanel:OnShow()
    this.endLessTitle:SetActive(MapManager.curCarbonType == CarBonTypeId.ENDLESS)
    -- this.endLessRate:SetActive(MapManager.curCarbonType == CarBonTypeId.ENDLESS)
    Util.GetGameObject(self.gameObject,"leftCenter"):SetActive(false)

    this.btnXingYao:SetActive(MapManager.curCarbonType == CarBonTypeId.TRIAL)
    this.btnBomb:SetActive(MapManager.curCarbonType == CarBonTypeId.TRIAL)
    this.btnBuff:SetActive(MapManager.curCarbonType == CarBonTypeId.TRIAL)
    this.btnShop:SetActive(MapManager.curCarbonType == CarBonTypeId.TRIAL)
    this.btnReset:SetActive(false)
    this.btnFormat:SetActive(MapManager.curCarbonType == CarBonTypeId.ENDLESS)
    EndLessMapManager.GetLeftEnergy()
    this.btnNode:SetActive(false)
    if MapManager.curCarbonType == CarBonTypeId.ENDLESS then
        this.GetMonsterNumberData()
    end

    -- HUD 环绕入场：放在 OnShow 末尾，等各容器的 SetActive 都落定再播（未激活的直接跳过）
    if this.needHudAnim then
        this.needHudAnim = false
        this.PlayHudSlideIn()
    end
end
function this.ThisTypeOpen()
end
function this.GetMonsterNumberData()
    NetManager.MapInfoListRequest(function (msg)
        local dataList = {}
        for index, value in ipairs(msg.info) do
            dataList[value.cfgId] = value
        end
        local data = dataList[EndLessMapManager.cfgId]
        EndLessMapManager.maxMosterNum = data.monsterNum
        EndLessMapManager.deadMosterNum = data.passNum
        -- this.mapSlidleData()
    end)
end
-- function this.mapSlidleData()
--     this.endLessRate:GetComponent("Slider").value=EndLessMapManager.deadMosterNum/EndLessMapManager.maxMosterNum
-- end
--界面打开时调用（用于子类重写）
function this:OnOpen(...)
    -- 只有「进图 / 换层」才播 HUD 入场（这两条路径都会走 OnOpen）；
    -- 从弹窗返回地图只走 OnShow，标记已被 OnShow 清掉 ⇒ 不会重播
    this.needHudAnim = true
    MapManager.FirstEnter = true
    EndLessMapManager.EndLessRoleDead = true
    -- 永久隐藏设置按钮
    ctrlView.Init()
    CarbonManager.isPassFight = true

    -- 在这设置所有副本的初始化设置
    -- 根据副本类型显示
    this.InitCompShow(CarbonManager.difficulty)

    -- 地图迷雾显示
    this.SetMapFog()

    pointHandleView.GeneratePoint()

    -- 进地图初始化位置
    local pos = MapManager.roleInitPos
    this.InitRolePosition(pos, MapManager.curMapId)
    EndLessMapManager.srcMapId = MapManager.curMapId

    missionView.Init()
    trialPanel:OnOpen()
    endLessMapView:OnOpen()
    -- 副本相关的初始化设置
    this.InitCarbonSet()

    -- 如果100%,弹出离开界面
    this.ExploreInitSet()
    this.InitrightUpBtn()

    ---- 刷新被主角狗眼糟蹋过的点
    EndLessMapManager.isOpenedFullPanel = false

    --- 刷新buff显示
    this.RefreshBuffShow()
    if MapManager.curCarbonType == CarBonTypeId.ENDLESS then
        this.GetMonsterNumberData()
    end
end

---==================== 地图初始化处理部分 ==================================

function this.SetMapFog()
    
    local mapId = MapManager.curMapId
    local fogVal = ChallengeMapConfig[mapId].isShowFog
    
    if fogVal and fogVal == 0 then
        TileMapView.isShowFog = false
    else
        TileMapView.isShowFog = true
    end
end

-- 有探索度地图的初始化
function this.ExploreInitSet()
    --首先他得有探索度
    local curMapId = MapManager.curMapId
    if DifficultyData[curMapId] and DifficultyData[curMapId].IsExplore == 1 then
        local isPass = CarbonManager.ExplorationDone()
        if isPass then
            UIManager.OpenPanel(UIName.MapStatsPanel)
        end
    end
end

function this.InitCarbonSet()
    -- 面板遮罩
    this.MaskState(1)
    local timer = Timer.New(function()
        this.MaskState(0)
    end, 2.5)
    timer:Start()
    --如果是在序章
    local isStartMap = MapManager.curMapId == 100
    this.BtnBack:SetActive(not isStartMap)

end

--设置遮罩开关 1 是开 其他都是关
function this.MaskState(state)
    this.Mask:SetActive(state == 1)
end

-- 根据副本的类型显示组件
function this.InitCompShow(type)
    -- this.leftUp:SetActive(type == 2)
    -- this.oleLeftUp:SetActive(type==2)
    this.centerDonwn:SetActive(true)
end

-- 角色位置初始化bb
function this.InitRolePosition(pos, curMapId)

    local u, v = Map_Pos2UV(pos)

    TileMapView.Init()
    TileMapController.LocateToUV(u, v)

    local scale = TileMapView.GetMapScale()
    MapManager.mapScale = scale
    TileMapController.SetScale(TileMapView.GetMapMinScale())
    TileMapView.UpdateFunc()

    if MapManager.isOpen then
        this.SetRoleShow(scale, pos,1)
    end
    MapManager.stepList = {}
end

-- 设置小人落地
function this.SetRoleShow(scale, pos,num)
   
    DoTween.To(DG.Tweening.Core.DOGetter_float(function () return TileMapView.GetMapMinScale() end),
            DG.Tweening.Core.DOSetter_float(TileMapController.SetScale),
            scale, 1):SetEase(Ease.Linear):OnComplete(function ()

        -- this.Mask:SetActive(false)

        playerView.Init(pos,num)

        -- 进图初始化完成
        MapManager.FirstEnter = false

        playerView.leader.transform:SetParent(ctrlView.Ctrl.transform)
        -- leader的父级设置为Ctrl后，Z轴的值发生了变化， 需要重新设置
        local v3 = playerView.leader.transform.localPosition
        playerView.leader.transform.localPosition = Vector3.New(v3.x, v3.y, -10)
    end)
end

-- 根据选择的副本类型设置显示的按钮
function this.InitrightUpBtn()
    this.btnAchive:SetActive(CarbonManager.difficulty == 3)
end

---===============================================================================
-- 修改地图的数据时相应的表现
function this.OnMapDataChange(refreshType)
    if refreshType then
        if refreshType == 1 then
            -- 增加地图移动速度
        elseif refreshType == 2 then
            -- 增加视野范围
            local u, v = Map_Pos2UV(MapManager.curPos)
            TileMapView.UpdateWarFog(u, v, MapManager.fogSize)

        elseif refreshType == 3 then
            -- 增加扎营次数

        elseif refreshType == 4 then
            --增加采矿暴击率

        elseif refreshType == 5 then
            -- 刷新行动力显示
        elseif refreshType == 6 then
            -- 驱散指定区域的迷雾
        else

        end
    end
end

--界面关闭时调用（用于子类重写）
function this:OnClose()

    -- 中途出图：Kill 掉入场 tween 并复位（漏掉的话容器会永久停在半截位置 / 0.94 缩放）
    this.StopHudSlideIn()
    playerView.PlayerMove()
    -- UIManager.camera.clearFlags = CameraClearFlags.Skybox

    trialPanel:OnClose()
    endLessMapView:OnClose()

    MapTrialManager.firstEnter = false
    -- 记录界面关闭但是没有注销
    EndLessMapManager.isOpenedFullPanel = true

    SoundManager.PauseAmbient()
end


-- 刷新buff显示
function this.RefreshBuffShow()
    -- 关闭所有显示
    for _, propItem in pairs(_PropItemList) do
        propItem:SetActive(false)
    end
    -- 重新显示
    local props = FoodBuffManager.GetBuffPropList()
    if not props then return end

    for index, prop in ipairs(props) do
        if GetProIndexByProId(prop.id) ~= 2 then
            local item = _PropItemList[index]
            if not item then
                item = newObjToParent(this.propItem, this.propBox)
                _PropItemList[index] = item
            end
            this.BuffItemAdapter(item, prop, index)
            item:SetActive(true)
        end
    end
end

-- buff显示匹配
function this.BuffItemAdapter(item, prop, index)
    local icon = Util.GetGameObject(item, "icon"):GetComponent("Image")
    local stepImg = Util.GetGameObject(item, "stepImg")
    local leftStep = Util.GetGameObject(item, "stepImg/step"):GetComponent("Text")
    local propInfo = ConfigManager.GetConfigData(ConfigName.PropertyConfig, prop.id)
    -- 图标
    if propInfo.BuffShow then
        local lastStr = ""
        if propInfo.IfBuffShow == 1 then
            lastStr = prop.value >= 0 and "_buff" or "_debuff" -- m5
        end
        icon.sprite = Util.LoadSprite(propInfo.BuffShow .. lastStr)
    else

    end
    -- 剩余步数
    stepImg:SetActive(prop.step >= 0)
    leftStep.text = prop.step

    -- 长按事件监听
    local trigger = Util.GetEventTriggerListener(item)
    --当之前注册过长按监听，则先移除
    if _PointerDownList[index] then
        trigger.onPointerDown = trigger.onPointerDown - _PointerDownList[index]
        trigger.onPointerUp = trigger.onPointerUp - _PointerUpList[index]
    end
    -- 事件监听
    _PointerDownList[index] = function(Pointgo, data)
        -- 显示内容
        local val = prop.value
        local express1 = val >= 0 and "+" or ""
        local express2 = ""
        if propInfo.Style == 2 then
            val = val / 100
            express2 = "%"
        end
        this.propContent.text = propInfo.Info .. express1..val..express2
        -- 显示位置
        local pos = item.transform.localPosition
        this.propInfo.transform.localPosition = Vector3(pos.x, pos.y + 120, 0)
        this.propInfo:SetActive(true)
    end
    _PointerUpList[index] = function(Pointgo, data)
        this.propInfo:SetActive(false)
    end
    trigger.onPointerDown = trigger.onPointerDown + _PointerDownList[index]
    trigger.onPointerUp = trigger.onPointerUp + _PointerUpList[index]
end



--界面销毁时调用（用于子类重写）
function this:OnDestroy()

    this.StopHudSlideIn()
    this.Dispose()

    trialPanel:OnDestroy()
    endLessMapView:OnDestroy()


    _PropItemList = {}
    _PointerDownList = {}
    _PointerUpList = {}
end

function this.PathEnd()
    ctrlView.ClearCallList()
    playerView.PlayerIdle()
end

--刷新动态点的显示
function this.RefreshShow()
    pointHandleView.leaderMapData = playerView.leaderMapData
    pointHandleView.RefreshShow()
end
 
function this.OnMapOut(outType)
    --出图不需要发协议了
   
    -- 无尽副本需要传目的地的地图ID
    -- local distMapId = 0
    -- if CarbonManager.difficulty == CARBON_TYPE.ENDLESS and nextMapId > 0 then
    --     distMapId = nextMapId
    -- end

    -- NetManager.MapOutRequest(outType, function (msg)
        if outType == 0 then
            this.BackHome()
            MapManager.Mapping = false
        elseif outType == 1 then  -- 正常出图
            this.BackToCarbonPanel()
            MapManager.Mapping = false
        else   --换层或者换地图
            this.ChangeMapByType()
        end

        Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
    -- end, distMapId)

end

function this.ClearCtrl()
    
    this.Dispose()
    poolManager:ClearPool()
end

-- ========================= 死出图的各种方法 ==========================
-- 序章回到主界面
function this.BackHome()
    -- EndLessMapManager.EndlessRedCheck()
    MapTrialManager.TrialRedCheck()
    local triggerCallBack
    triggerCallBack = function (panelType, panel)
        if panelType == UIName.MapPanel then
            this.Dispose()
            this:ClosePanel()
            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
        end
        -- BagManager.InBagGetMapBag()
    end
    Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    -- 清空一下副本任务
    MissionManager.carBonMission = {}
    if MapManager.curCarbonType == CarBonTypeId.TRIAL then
        UIManager.ClosePanel(UIName.MapPanel)
    elseif MapManager.curCarbonType == CarBonTypeId.ENDLESS then
        SwitchPanel.OpenPanel(UIName.MainPanel)
    end
    poolManager:ClearPool()
end

-- 正常出图时需要打开的界面类型
local panelNeedOpen = {
    [1] = UIName.PlotCarbonPanel,
    [2] = UIName.TrialCarbonPanel,
    [3] = UIName.EliteCarbonPanel,
    [4] = UIName.EndLessCarbonPanel,
}


-- 从副本正常出图
function this.BackToCarbonPanel()
    local triggerCallBack
    triggerCallBack = function (panelType, panel)
        if panelType == UIName.MapPanel then
            this.Dispose()
            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
        end
        BagManager.InBagGetMapBag()
    end
    Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    -- 清空一下副本任务
    this.ResetMapData()


    -- 从序章出来的回到主界面
    if MapManager.curMapId == 0 or MapManager.curMapId == 100 then
        SwitchPanel.OpenPanel(UIName.MainPanel)
    else
        if(MapTrialManager.curTowerLevel>MapTrialManager.highestLevel) then
            if not MapTrialManager.IsFinalLevel()then
                MapTrialManager.highestLevel=MapTrialManager.curTowerLevel-1
            else
                MapTrialManager.highestLevel = MapTrialManager.curTowerLevel
            end
        end
        SwitchPanel.OpenPanel(UIName.MainPanel)
    end

    -- 刷新红点
    if CarbonManager.difficulty == 2 then
        this.TrialCopyData()
    elseif CarbonManager.difficulty == 1 then
        CheckRedPointStatus(RedPointType.NormalExplore_GetStarReward)
    elseif CarbonManager.difficulty == 3 then
        this.TrialCopyData()
        CheckRedPointStatus(RedPointType.HeroExplore)
        CheckRedPointStatus(RedPointType.HeroExplore_Feats)
    elseif CarbonManager.difficulty == CARBON_TYPE.ENDLESS then


    end

    poolManager:ClearPool()
end

-- 正常出图需要消除的数据
function this.ResetMapData()
    EndLessMapManager.srcMapId = 0
    MissionManager.carBonMission = {}
    MapTrialManager.doneTime = 0
    MapManager.isTimeOut = false
    this.StopWalking()
end

-- 换层或者换地图
function this.ChangeMapByType(msg)
    local carbonType = CarbonManager.difficulty
    -- 在试炼副本中的是换层操作
    if carbonType == 2 then

        this.TrialChangeFloor(msg)
    elseif carbonType == 4 then

        -- 执行换图方法
        this.ChangeMap()
    end
end

-- 试炼副本的换层操作
function this.TrialChangeFloor(msg)
    -- 设置不可点击
    ctrlView.SetCtrlState(true)
    this.ClearBag()
    this.StopWalking()

    NetManager.MapInfoRequest(MapManager.curCarbonType,function (msg)
        local triggerCallBack
        triggerCallBack = function (panelType, panel)
            if panelType == UIName.SwitchPanel then
                this.Dispose()
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)

        -- 试炼副本的完成时间
        -- if msg.useTime then
        
        --     MapTrialManager.doneTime = msg.useTime
        -- end
        SwitchPanel.OpenPanel(UIName.MapPanel)
        MapTrialManager.isChangeLevel = false
        
        
        -- if MapTrialManager.curTowerLevel<10000 then
        --     MapTrialManager.curTowerLevel = MapTrialManager.curTowerLevel + 1
        -- end
        --设置 进入下一层后领取全部奖励
        MissionManager.GetAllRewardTrigger()
    end)
end

-- 换图操作
function this.ChangeMap(nextMapId)
    this.ClearBag()
    this.StopWalking()

    local index = CarbonManager.difficulty == CARBON_TYPE.ENDLESS and 401 or FormationManager.curFormationIndex
    NetManager.MapInfoRequest(nextMapId,function ()
        local triggerCallBack
        triggerCallBack = function (panelType, panel)
            if panelType == UIName.SwitchPanel then
                this.Dispose()
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
        -- 如果是无尽副本，则需要消耗行动力
        if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
            -- 更新行动力

            endLessMapView:OnRoleTransport(function ()
            end)
        end
        SwitchPanel.OpenPanel(UIName.MapPanel)
        --设置 进入下一层后领取全部奖励
        MissionManager.GetAllRewardTrigger()
    end)
end


-- =================================================================
--  清除道具
function this.ClearBag()
    BagManager.mapShotTimeItemData = {}
    EquipManager.mapShotTimeItemData = {}
    HeroManager.mapShotTimeItemData = {}
end

--出图数据刷新
function this.TrialCopyData()
    local isPass = CarbonManager.IsMapPlayed(MapManager.curMapId)
    if isPass == true then
        for k, v in ConfigPairs(DifficultyData) do
            if v.Id == MapManager.curMapId and v.Type == 3 then
                if CarbonManager.difficultyMask[v.MapId] ~= -1 then
                    if v.DifficultType > CarbonManager.difficultyMask[v.MapId] then
                        CarbonManager.difficultyMask[v.MapId] = v.DifficultType
                    end
                else
                    CarbonManager.difficultyMask[v.MapId] = v.DifficultType
                end
            end
        end
    end
    if CarbonManager.difficulty == 2 then
        MapTrialManager.isCanReset = 1
    end
end

-- 角色死亡, 血量重置
function this.OnMapDeadOut(startTime, lastPos)
    if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        this.OnEndLessDead(lastPos)
    else
        this.OnDeadCount(startTime, lastPos)
    end
end

-- 无尽副本的死亡表现
function this.OnEndLessDead(lastPos)
    -- 进入死亡状态
    EndLessMapManager.EndLessRoleDead = true
    -- 清空血条值
    playerView.InitRoleHp(false)
    MapManager.deadTime = 0
    -- 清空相应的队伍英雄血量
    EndLessMapManager.DeleteMapTeam()
    -- 设置角色位置
    playerView.SetRolePos(lastPos)
    -- 隐藏战斗特效
    playerView.SetBattleState(false)
    -- 如果正在触发事件则停止
    ctrlView.OnRoleDead()
    ctrlView.SetCtrlState(false)
    -- 无尽副本中死亡扣行动力
    if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        endLessMapView:OnRoleDead()
    end

end

-- 死亡倒计时的表现
function this.OnDeadCount(startTime, lastPos)
    ctrlView.SetCtrlState(true)
    -- 死亡次前端无奈的加一次
    MapManager.deadCount = MapManager.deadCount + 1
    -- 清空血条值
    playerView.InitRoleHp(false)
    playerView.SetBattleState(false)
    -- 设置角色位置
    playerView.SetRolePos(lastPos)

    -- 如果正在触发事件则停止
    ctrlView.OnRoleDead()

    -- 角色死亡不出图, 立马设置遮罩，让你瞎几把点
    -- this.deadRoot:SetActive(true)
    local t=(PlayerPrefs.HasKey(PlayerManager.uid.."GeneralPopup_TrialSettingBtn"..1)
        and PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_TrialSettingBtn"..1)==1) and 1 or 0
    if  t==1 then
        UIManager.OpenPanel(UIName.BattleFailPopup,nil,false,nil,12)
    end
    ctrlView.SetCtrlState(false)

    -- 无尽副本中死亡扣行动力
    if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        endLessMapView:OnRoleDead()
    end
end

-- 清空寻路
function this.StopWalking()
    ctrlView.OnRoleDead()
    -- 换层时路径不一定完了，不弹完会卡死
end

function this.CallListPop()
    ctrlView.CallListPop()
end

function this.Dispose()
    if not ctrlView.Ctrl then
        return
    end

    ctrlView.Dispose()
    playerView.Dispose()
    pointHandleView.Dispose()

end

return MapPanel