
require("Base/Stack")
require("Modules/Map/Logic/TileMapController")
require("Modules/Map/Logic/TileMapView")
--require("Modules/Map/Config/MapConfig")
--require("Modules/Map/View/MapPointView")
local this = {}
local flagEventPool = {}
local mapCtrl = "MapCtrl"
-- 当前关卡地图编号
local m_curMapId = 5001
local mainLevelSettingConFig = ConfigManager.GetConfig(ConfigName.MainLevelSettingConfig)
-- 缩放值
local offsetScale = math.min(Screen.width/3241, Screen.height/1920)
local rootParent = nil
local SkeletonGraphic
local curMiddleFightId = 0
-- 设置角色行走方向
local WALK_DIR = {
    RIGHT = {animation = "move2", y = 0},
    LEFT = {animation = "move2", y = 180},
    UP = {animation = "move3", y = 0},
    DOWN = {animation = "move", y = 0},
}

local mapNpc = "live2d_npc_map"
local mapNpc2 = "live2d_npc_map_nv"
local npc, scale

function this:InitComponent(root)
    -- 地图点击拖动
    rootParent = root
    this.dragCtrl = Util.GetGameObject(root, "mapParent/Ctrl")
    this.selectMap = Util.GetGameObject(root, "mapParent/selectMap")

    -- npc = NameManager.roleSex == ROLE_SEX.BOY and mapNpc or mapNpc2
    -- scale = NameManager.roleSex == ROLE_SEX.BOY and Vector3.one or Vector3.one * 0.5
    this.liveNode = poolManager:LoadAsset("InBattle", PoolManager.AssetType.GameObject)
    this.liveNode.transform:SetParent(Util.GetTransform(root, "mapParent/selectMap/Image (1)/roleRoot"))
    this.liveNode.transform.localScale = Vector3.one
    this.liveNode.transform.localPosition = Vector3.zero

    this.liveNode:GetComponent("Animator"):Play("m5_count_UI_ZhanDouZhong")

    -- SkeletonGraphic = self.liveNode:GetComponent("SkeletonGraphic")
    -- if SkeletonGraphic then
    --     SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
    -- end
end
local IsPlayAni = false
local curSmallFightId = 0
local openPanel = nil
function this:Init(_curSmallFightId,_IsPlayAni,_openPanel)
    -- 初始化加载地图块数据
    IsPlayAni = _IsPlayAni
    curSmallFightId = _curSmallFightId
    openPanel = _openPanel
    if this.liveNode then
        this.liveNode:OnClose()
    end
    this.liveNode = PlayerLiveView:New(Util.GetGameObject(rootParent, "mapParent/selectMap/Image (1)/roleRoot"),1)
    this.liveNode:OnOpen(GetPlayerRoleSingleConFig().Scale5,Vector3.New(0,40,0),WALK_DIR.IDLE_FRONT)
    this.liveNode:SetTitleHide()
    this:LoadMapData()
    if IsPlayAni then
        isWalk = true
        local time3 = Timer.New(function ()
            this.SetRoleWalk(curMiddleFightId)
        end, 1.5)
        time3:Start()
    else
        isWalk = false
    end
end
function this:LoadMapData()
    curMiddleFightId = math.floor(curSmallFightId/1000)
    local difficultType = curSmallFightId%10
    UIManager.camera.clearFlags = CameraClearFlags.Depth
    -- 所有物体的根节点
    
    this.mapRoot = poolManager:LoadAsset(mapCtrl, PoolManager.AssetType.GameObject)
    this.mapRoot.name = mapCtrl
    this.mapRoot.transform:SetParent(UIManager.uiRoot.transform.parent)
    this.mapRoot.transform.position = Vector3.New(0, 0, -100)

    TileMapView.fogSize = 2
    TileMapView.AwakeInit(this.mapRoot, 5001)
    TileMapView.isShowFog = false


    TileMapController.IsShieldDrag = function()
        --当栈中有逻辑，则拖动可以打断镜头跟随
        return false
    end
    TileMapController.OnClickTile = this.OnClickTile
    TileMapController.Init(this.mapRoot, this.dragCtrl)

    TileMapView.Init()
    -- 设置相机初始化位置
    TileMapView.SetCameraPos(Vector3.New(14+(1.6*curMiddleFightId), 20.77, 0))-- -20.77
    -- 设置镜头的尺寸
    TileMapController.SetScale(TileMapView.GetMapScale() * offsetScale)

    if this.liveNode == nil then
        this.liveNode = poolManager:LoadAsset("InBattle", PoolManager.AssetType.GameObject)
        this.liveNode.transform:SetParent(Util.GetTransform(rootParent, "mapParent/selectMap/Image (1)/roleRoot"))
        this.liveNode.transform.localScale = Vector3.one
        this.liveNode.transform.localPosition = Vector3.zero

        this.liveNode:GetComponent("Animator"):Play("m5_count_UI_ZhanDouZhong")
    end
    this._BuildFlag = {}
    this._BuildFlagClick = {}
    this.selectMap:SetActive(false)
    for buildType, config in ConfigPairs(ConfigManager.GetConfig(ConfigName.MainLevelSettingConfig)) do
        if mainLevelSettingConFig[buildType] == nil then return end
        local go = poolManager:LoadAsset("FightMiddleFlag", PoolManager.AssetType.GameObject)
        go.transform:SetParent(Util.GetTransform(this.mapRoot, "uiObj#"))
        go.name = "FightMiddleFlag"..buildType
        go:GetComponent("RectTransform").anchoredPosition3D = Vector3.New(config.ChapterTitlePosition[1], config.ChapterTitlePosition[2]-254, 10)
        Util.GetTransform(go, "click"):GetComponent("RectTransform").anchoredPosition3D = Vector3.New(config.ChapterClickPosition[1], config.ChapterClickPosition[2], 0)
        go.transform.localScale = Vector3.one
        this._BuildFlag[buildType] = go
        this._BuildFlagClick[buildType] = Util.GetTransform(go, "click").gameObject
        Util.GetGameObject(go, "name"):GetComponent("Text").text = mainLevelSettingConFig[buildType].Name
        local passImage = Util.GetGameObject(go, "passImage")
       local ChapterSate = FightPointPassManager.GetDifficultAndChapter(difficultType,buildType)
        if ChapterSate == SingleFightState.Pass then
            if not FightPointPassManager.IsChapterClossState() and buildType == curMiddleFightId then--是否播放章节状态   特殊判断
                passImage:SetActive(true)
                --Util.SetGray(go, false)
                this.SelectRenPos(Util.GetTransform(this.mapRoot, "uiObj#"),config.ChapterRolePosition)
            else
                passImage:SetActive(true)
                --Util.SetGray(go, false)
            end
            
            Util.SetColor(Util.GetGameObject(go, "name"):GetComponent("Text"), Color.New(85/255, 29/255, 29/255, 1))
        else
            if  ChapterSate == SingleFightState.NoPass or  ChapterSate == SingleFightState.Open then

                if IsPlayAni then--是否播放章节开启动画
                    passImage:SetActive(false)
                    --Util.SetGray(go, false)
                    local oldMiddleId = buildType
                    if buildType > 1 then
                        oldMiddleId = oldMiddleId - 1
                    end
                    this.SelectRenPos(Util.GetTransform(this.mapRoot, "uiObj#"),ConfigManager.GetConfigData(ConfigName.MainLevelSettingConfig,(oldMiddleId)).ChapterRolePosition)
                else
                    if not FightPointPassManager.IsChapterClossState() and buildType == math.floor(FightPointPassManager.curOpenFight/1000) then--是否播放章节状态  特殊判断
                        passImage:SetActive(false)
                        --Util.SetGray(go, true)
                    else
                        passImage:SetActive(false)
                        --Util.SetGray(go, false)
                        this.SelectRenPos(Util.GetTransform(this.mapRoot, "uiObj#"),config.ChapterRolePosition)
                    end
                end
            elseif  ChapterSate == SingleFightState.NoOpen then
                passImage:SetActive(false)
                --Util.SetGray(go, true)
            end
            Util.SetColor(Util.GetGameObject(go, "name"):GetComponent("Text"), Color.New(1, 1, 1, 1))
        end
        flagEventPool = {}
    end
end

-- 临时代码
function this.SetRoleWalk(middleFightId)
    local oldMiddleId = middleFightId
    if middleFightId > 1 then
        oldMiddleId = oldMiddleId - 1
    end
    local oldMainLevelSettingConfig = ConfigManager.GetConfigData(ConfigName.MainLevelSettingConfig,(oldMiddleId))
    local curMainLevelSettingConfig = ConfigManager.GetConfigData(ConfigName.MainLevelSettingConfig,middleFightId)
    local tagerPos = Vector3.New(curMainLevelSettingConfig.ChapterRolePosition[1]+30, curMainLevelSettingConfig.ChapterRolePosition[2]-100,100)
    local pos = Vector3.New(oldMainLevelSettingConfig.ChapterRolePosition[1]+30, oldMainLevelSettingConfig.ChapterRolePosition[2]-100,100)
    local targetPos = tagerPos
    local speed = 2 -- 越大越慢

    this.liveNode.transform:DOLocalMove(targetPos, speed / 5, false):OnStart(function ()
        this.SetRoleDirAction(targetPos.x, targetPos.y, pos.x, pos.y)
    end):OnUpdate(function() --TODO:测试速度

    end):OnComplete(function ()

        FightPointPassManager.SetChapterOpenState(false)
        if openPanel then
            openPanel:OnRefreshMiddleClick()
            openPanel:OnRefreshBackClick()
        end
        --SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
        UIManager.OpenPanel(UIName.UnlockCheckpointPopup,FightPointPassManager.curOpenFight)
    end):SetEase(Ease.Linear)
end

function this.SetRoleDirAction(targetU, targetV, u0, v0)
    local dU =  targetU - u0
    local dV =  targetV - v0

    if dU > 0 then
        this.SetWalkDir(WALK_DIR.RIGHT)
    elseif dU < 0 then
        this.SetWalkDir(WALK_DIR.LEFT)
    elseif dV < 0 then
        this.SetWalkDir(WALK_DIR.UP)
    elseif dV > 0 then
        this.SetWalkDir(WALK_DIR.DOWN)
    end

end

function this.SetWalkDir(dir)
    --SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, dir.y, 0)
    --SkeletonGraphic.AnimationState:SetAnimation(0, dir.animation, true)
end

-- 单击
function this.OnClickTile(u, v,fuv)
    if this.CheckFlagClick(fuv) then return end
   
    --this.SetRoleWalk(curMiddleFightId)

end
-- 检测是否点到旗子上
function this.CheckFlagClick(fuv)
    local mousePos = TileMapView.GetLiveTilePos(fuv.x, -fuv.y) * 100
    for type, node in pairs(this._BuildFlag) do
        local nPos = node.transform.anchoredPosition3D
        local nRect = node.transform.rect
        local nPivot = node.transform.pivot
        local left = nPos.x + nRect.width * (0 - nPivot.x)
        local right = nPos.x + nRect.width * (1 - nPivot.x)
        local bottom = nPos.y + nRect.height * (0 - nPivot.y)
        local top = nPos.y + nRect.height * (1 - nPivot.y)
        if mousePos.x >= left and mousePos.x <= right
                and mousePos.y >= bottom and mousePos.y <= top then
           
            if flagEventPool[type] then
                flagEventPool[type]()
                return true
            end
        end
    end
   
    for type, node in pairs(this._BuildFlagClick) do
        local nPos = node.transform.anchoredPosition3D + this._BuildFlag[type].transform.anchoredPosition3D
        local nRect = node.transform.rect
        local nPivot = node.transform.pivot
        local left = nPos.x + nRect.width * (0 - nPivot.x)
        local right = nPos.x + nRect.width * (1 - nPivot.x)
        local bottom = nPos.y + nRect.height * (0 - nPivot.y)
        local top = nPos.y + nRect.height * (1 - nPivot.y)
        if mousePos.x >= left and mousePos.x <= right
                and mousePos.y >= bottom and mousePos.y <= top then
           
            if flagEventPool[type] then
                flagEventPool[type]()
                return true
            end
        end
    end
    return false
end
-- 增加一个标记点
function this.AddPointFunc(type, clickTipFunc)
    --mapPointEventPool[type * 10] = clickTipFunc
    flagEventPool[type] = clickTipFunc
end
function this.SelectRenPos(_parent,ChapterRolePosition)
    if this.liveNode then
        this.liveNode:SetActive(true)
        this.liveNode.transform:SetParent(_parent.transform)
        this.liveNode.transform.localScale = Vector3.one
        this.liveNode:GetComponent("RectTransform").anchoredPosition3D = Vector3.New(ChapterRolePosition[1]+30, ChapterRolePosition[2]-100, 10)
    end
end
function this:Dispose()
    if this.liveNode then
        this.liveNode.transform:SetParent(Util.GetGameObject(rootParent, "mapParent/selectMap/Image (1)/roleRoot").transform)
        poolManager:UnLoadAsset("InBattle", this.liveNode, PoolManager.AssetType.GameObject)
        this.liveNode = nil
    end
    -- UIManager.camera.clearFlags = CameraClearFlags.Skybox
    TileMapView.Exit()
    TileMapController.Exit()
    poolManager:UnLoadAsset(mapCtrl, this.mapRoot, PoolManager.AssetType.GameObject)
    this.mapRoot = nil
    for _, flag in pairs(this._BuildFlag) do
        Util.AddOnceClick(flag, function()end)
        poolManager:UnLoadAsset("FightMiddleFlag", flag, PoolManager.AssetType.GameObject)
    end
    this._BuildFlag = {}
    this._BuildFlagClick = {}
    openPanel = nil
end

return this