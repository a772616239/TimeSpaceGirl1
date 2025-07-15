require("Base/Stack")
require("Modules/Map/Logic/TileMapController")
require("Modules/Map/Logic/TileMapView")

local this = {}
local MapPlayerView

local pointHandleView = require("Modules/Map/View/PointHandleView")
local iconShow = require("Modules/Map/View/IconShowView")

local callList = Stack.New()
local funcCanPass = function(data) return data.val <= 1 end
local pathList
-- 是否触发了事件
local isEventTrigger = false
local mapCtrl = "MapCtrl"
local MapPanel
local hasDisposed = false

function this.InitComponent(gameObject, mapPanel, playerView)
    MapPanel = mapPanel
    MapPlayerView = playerView
    this.DragCtrl = Util.GetGameObject(gameObject, "Ctrl")
end

function this.AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Event.PointTriggerEnd, this.OnEventTriggerEnd)
end

function this.RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Event.PointTriggerEnd, this.OnEventTriggerEnd)
end

function this.Init()
    UIManager.camera.clearFlags = CameraClearFlags.Depth
    hasDisposed = false
    
    this.Ctrl = poolManager:LoadAsset(mapCtrl, PoolManager.AssetType.GameObject)
    this.Ctrl.name = mapCtrl
    this.Ctrl.transform:SetParent(UIManager.uiRoot.transform.parent)
    this.Ctrl.transform.position = Vector3(0, 0, -100)
    pointHandleView.Ctrl = this.Ctrl


    TileMapView.OnInit = this.OnInit
    TileMapView.fogSize = MapManager.fogSize
    TileMapView.AwakeInit(this.Ctrl, MapManager.curMapId, MapManager.wakeCells)

    TileMapController.IsShieldDrag = function()
        --当栈中有逻辑，则拖动可以打断镜头跟随
        this.DragFlag = callList:Count() > 1
        return false
    end

    -- 清空
    this.OnRoleDead()

    TileMapController.OnClickTile = this.OnClickTile
    TileMapController.OnLongClickTile = this.OnLongClickTile
  
    TileMapController.Init(this.Ctrl, this.DragCtrl)

    callList:Clear()
end

function this.GetCallListCount()
    return callList:Count()
end

function this.OnInit()
end

---==============================================================================

function this.OnLongClickShowPath(u, v)
    if this.WalkLimit(false) > 0 then
        return
    end
    --寻路算法，返回的结果是从终点指向起点的坐标列表
    pathList = TileMapView.ShowPath(MapPlayerView.leaderMapData.u, MapPlayerView.leaderMapData.v, u, v, funcCanPass)
end

function this.OnLongClickTile()
    --寻路路径为空，则不能行走
    if this.WalkLimit(true) > 0 then
        return
    end

    if not pathList or #pathList <= 1 then
        -- 这里将弹出状态置为false，避免因为连续点击时，第二次点击到无法寻路的点导致寻路卡死的问题
        MapManager.isPoping = false
        return
    end

    --把最终回调最先入栈
    callList:Push(function ()
        -- 寻路完成弹出状态置为false
        MapManager.isPoping = false
        MapPanel.PathEnd()
    end)
    for i=1, #pathList-1 do --最后的点为起点，不处理
        local data = pathList[i]
        local v3 = TileMapView.GetLiveTilePos(data.u, data.v)

        callList:Push(function ()

            MapPlayerView.SetRoleDirAction(data.u, data.v)
            MapPlayerView.leaderMapData = data

            MapPlayerView.leader.transform:DOLocalMove(Vector3(v3.x, v3.y, v3.z - 10), MapManager.leaderMoveSpeed/5, false):OnUpdate(function() --TODO:测试速度
                --该标记监听拖动，当正在处理栈事件时，镜头默认居中跟随，此时拖动界面可以打断镜头跟随
                if this.DragFlag then
                    return
                end
                local v3 = MapPlayerView.leader.transform.localPosition
                v3.z = TileMapView.ViewCameraPos.z
                TileMapView.SetCameraPos(v3)
                TileMapView.UpdateBaseData()
            end):OnComplete(function ()
                TileMapView.ClearPathTile(data.u, data.v)
                MyPCall(function () this.OnMoveStep(data.u, data.v) end)
                this.CallListPop()
            end):SetEase(Ease.Linear)
        end)
    end

    --若相机未归位则先归位
    callList:Push(function ()
        local data = MapPlayerView.leaderMapData
        local v3 = TileMapView.GetLiveTilePos(data.u, data.v)
        v3.z = TileMapView.ViewCameraPos.z
        if TileMapView.ViewCameraPos ~= v3 then
            TileMapView.CameraTween(data.u, data.v, 0.5, function ()
                TileMapView.ClearPathTile(data.u, data.v)
                this.CallListPop()
            end)
            this.DragFlag = false
        else
            TileMapView.ClearPathTile(data.u, data.v)
            this.CallListPop()
        end
    end)


    -- 判断是否正在弹出事件，没有则开始
    if not MapManager.isPoping then
        MapManager.isPoping = true
        this.CallListPop()
    end
    --栈事件清空前，关闭移动
    MapPlayerView.PlayerMove()
end

-- 一部分不可寻路的条件
--- @return table 值大于0都是不可寻路的状态
function this.WalkLimit(showTip)
    local value = 0
    -- 触发了事件不可寻路
    if isEventTrigger then value = 1 end
    -- 人物死亡不可寻路
    if MapManager.deadTime > 0 then value = 2 end

    -- 精气值满时不可寻路
    if CarbonManager.difficulty == CARBON_TYPE.TRIAL then
        if not MapTrialManager.canMove or MapTrialManager.isChangeLevel then
            value = 3
        end
        if MapManager.isRemoving then 
            value = 4 
        end
    end

    -- -- 加入进入标记状态
    -- if EndLessMapManager.IsCanNoteState() then
    --     value = 5
    -- end
Log(showTip)
EndLessMapManager.isHungery()
    if EndLessMapManager.roleIsHungery() then
        if showTip then
            PopupTipPanel.ShowTipByLanguageId(11296)
            this.GodIsBack()
        end
        value = 6
    end

    --正在移动时，或点击区域外，点击移动无效
    if not MapPlayerView.bLeaderIsIdle then value = 7 end

    return value
end

--传说中的相机归位
function this.GodIsBack()
    local data = MapPlayerView.leaderMapData
    local v3 = TileMapView.GetLiveTilePos(data.u, data.v)
    v3.z = TileMapView.ViewCameraPos.z
    if TileMapView.ViewCameraPos ~= v3 then
        TileMapView.CameraTween(data.u, data.v, 0.5, function ()
            TileMapView.ClearPathTile(data.u, data.v)
            this.CallListPop()
        end)
        this.DragFlag = false
    end
end

function this.OnClickTile(u, v)
    -- 触发了事件不可寻路
    if isEventTrigger then return end
    -- 人物死亡不可寻路
    if MapManager.deadTime > 0 then return end

    -- 精气值满时不可寻路
    if CarbonManager.difficulty == CARBON_TYPE.TRIAL then
        if not MapTrialManager.canMove or MapTrialManager.isChangeLevel then
            return
        end
        if MapManager.isRemoving then
            return 
        end
    end

    --- 判断点击位置是否超出地图区域
    local data = TileMapView.GetTileData(u, v)
    if not data then
        -- if EndLessMapManager.IsCanNoteState() then
        --     PopupTipPanel.ShowTipByLanguageId(11285)
        -- end
        return
    end
    -- 无尽副本进入地图标记状态

    -- =====================================
    -- if EndLessMapManager.IsCanNoteState() then
    --     if not funcCanPass(data) then
    --         PopupTipPanel.ShowTipByLanguageId(11286)
    --         return
    --     end

    
    --     EndLessMapManager.SetNotePos(u, v)
    --     return
    -- end

    if EndLessMapManager.roleIsHungery() then
        PopupTipPanel.ShowTipByLanguageId(11296)
        -- 相机没有归位则归位，当次寻路不生效
        this.GodIsBack()
        return
    end

    -- 无尽副本进图死亡状态
    if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        local curFomation = EndLessMapManager.formation
        if not curFomation or #curFomation < 1 then
            PopupTipPanel.ShowTipByLanguageId(23052)
            MapManager.endlessEnter = false
            return
        end
        -- if EndLessMapManager.EndLessRoleDead then
        --     PopupTipPanel.ShowTipByLanguageId(11287)
        --     -- 重登时如果都是死的，上面的判断就可以，如果还有活着的，肯定在队伍中
        --     if EndLessMapManager.IsAllDead() then
        --         PopupTipPanel.ShowTipByLanguageId(11287)
        --         return
        --     end
        --     if not  MapManager.endlessEnter then
        --         if not EndLessMapManager.IsMapTeamAlive() then
        --             PopupTipPanel.ShowTipByLanguageId(11288)
        --             return
        --         end
        --     end
        --     MapManager.endlessEnter = false
        -- end
    end
    -- =====================================
    --- 当栈中有逻辑，则点击可以打断栈操作，并清空当前栈
    MapPanel.PathEnd()
    --- 显示路径开始寻路
    this.OnLongClickShowPath(u, v)
    this.OnLongClickTile()

end

-- 单次寻路
function this.OnClickFindPath(u, v)
    --当栈中有逻辑，则点击可以打断栈操作，并清空当前栈
    if callList:Count() > 1 then
        -- 相机归位过程中，再次点击寻路，清空栈，相机归位完成栈是空的，无法重置状态
        MapManager.isPoping = false
        TileMapView.CameraTween(MapPlayerView.leaderMapData.u, MapPlayerView.leaderMapData.v, 0.5)
        this.DragFlag = false

        MapPanel.PathEnd()
        return
    end

    -- 相机没有归位则归位，当次寻路不生效
    local v3 = TileMapView.GetLiveTilePos(MapPlayerView.leaderMapData.u, MapPlayerView.leaderMapData.v)
    v3.z = TileMapView.ViewCameraPos.z
    if not TileMapView.IsOutBounds(v3) and TileMapView.ViewCameraPos ~= v3 then
        TileMapView.CameraTween(MapPlayerView.leaderMapData.u, MapPlayerView.leaderMapData.v, 0.5)
        this.DragFlag = false
        return
    end

    local data = this.GetOnceClickPathList(u, v)
    if data and funcCanPass(data) then
        pathList = {data, MapPlayerView.leaderMapData}
        this.OnLongClickTile()
    end
end

function this.GetOnceClickPathList(u, v)
    local tu, tv
    if math.abs(u - MapPlayerView.leaderMapData.u) >= math.abs(v - MapPlayerView.leaderMapData.v) then
        if u > MapPlayerView.leaderMapData.u then
            tu = MapPlayerView.leaderMapData.u + 1
        else
            tu = MapPlayerView.leaderMapData.u - 1
        end
        tv = MapPlayerView.leaderMapData.v
    else
        if v > MapPlayerView.leaderMapData.v then
            tv = MapPlayerView.leaderMapData.v + 1
        else
            tv = MapPlayerView.leaderMapData.v - 1
        end
        tu = MapPlayerView.leaderMapData.u
    end
    local data = TileMapView.GetTileData(tu, tv)

    return data
end

-- 角色进入进入标记状态时，只响应单击事件
function this.IsForbitLongClick(state)
    if state then
        TileMapController.OnLongClickShowPath = nil
    end
end


--- ---------------------------------------------------------------

function this.OnRoleDead()
    if isEventTrigger then
        isEventTrigger = false
    end
   
    if callList:Count() > 0 then
        -- 传送等强制设置角色位置，停止弹出状态，并清空当前栈
        MapManager.isPoping = false

        MapPanel.PathEnd()
    end
end

function this.BattleEnd()
    MapPlayerView.SetBattleState(false)
end

-- 复位时角色停止寻路
function this.StopWalk()
    if callList:Count() > 0 then
        -- 传送等强制设置角色位置，停止弹出状态
        MapManager.isPoping = false
        MapPanel.PathEnd()
    end
end

function this.OnMoveStep(u, v)

    this.RectangleTrigger(u , v)
    this.RefreshFog(u, v, true)
    MapPanel.RefreshShow()

    local pos = Map_UV2Pos(u, v)

    table.insert(MapManager.stepList, pos)
    MapPlayerView.ShowPos(u, v)
    -- 普通副本，出图时间到，停止行走
    if CarbonManager.difficulty == CARBON_TYPE.NORMAL then
        if MapManager.isTimeOut or MapManager.progressFull then
            this.OnRoleDead()
        end
    end

    MapManager.curPos = pos
    --边缘触发检测
    this.EdgeEventTrigger(u-1, v)
    this.EdgeEventTrigger(u+1, v)
    this.EdgeEventTrigger(u, v-1)
    this.EdgeEventTrigger(u, v+1)

    --覆盖触发检测
    this.EventTrigger(u, v)

    -- buff管理按照步数刷新buff信息
    FoodBuffManager.OnMoveStep()

end

-- 行走时刷新迷雾
function this.RefreshFog(u, v)
    -- 刷新地图米迷雾
    if TileMapView.isShowFog then
        TileMapView.UpdateWarFog(u, v, MapManager.fogSize)
    end
end


-- 设置不可刷新区域
function this.isFogArea(u, v)
    local canFlush = true
    -- 设置边界值
    local u0 = 0
    local v0 = 0
    local u1 = 0
    local v1 = 0
    if u >= u0 and u <= u1 and v >= v0 and v <= v1 then
        canFlush = false
    else
        canFlush = true
    end
    return canFlush
end

function this.SetCtrlState(state)
    if state then
        TileMapController.OnClickTile = nil
        TileMapController.OnLongClickTile = nil
        TileMapController.OnLongClickShowPath = nil
    else
        TileMapController.OnClickTile = this.OnClickTile
        TileMapController.OnLongClickTile = this.OnLongClickTile
    end
    TileMapController.SetEnable(not state)
end

function this.EdgeEventTrigger(u, v)
    local pos = Map_UV2Pos(u, v)
    local pointView = pointHandleView.EventPoint[pos]
    -- 周围不存在点，都没必要继续往下
    if not pointView then return end
    -- 如果当前已经到了地图的限制时间不再触发
    if MapManager.isTimeOut then
        return 
    end
    -- 探索度100%，不再触发事件
    if MapManager.progressFull then return end
    if CarbonManager.difficulty == CARBON_TYPE.TRIAL then
        if not MapTrialManager.canMove then
            return 
        end
        if MapManager.isRemoving then 
            return
        end
    end

    local triggerFunc = function()
        MapManager.MapUpdateEvent(pos, function ()
            if pointHandleView.IsAShinningPoint(MapManager.mapPointList[pos]) then
                pointHandleView.RemoveTipPoint(u, v)
            end
        end)
    end

    callList:Push(function ()
        local pointView = pointHandleView.EventPoint[pos]

        if not pointView or not pointView.cell or pointView.cell.TriggerRules ~= 1 then  --边缘触发
            this.CallListPop()
            return
        end
        -- 触发了事件
        if not isEventTrigger then
            -- Game.GlobalEvent:DispatchEvent(GameEvent.Map.StopWalk)
            isEventTrigger = true
            EndLessMapManager.isTrigger = true
            this.SetCtrlState(true)
        end
        if pointView and pointView.cell then
            pointView:ShowHidePoint()

        end
       
        
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.MaskState,1)
        
        --如果英雄阵亡 无法选择其进行战斗
        local num = #MapManager.trialHeroInfo
        for i, v in ipairs(MapManager.trialHeroInfo) do
            if v.heroHp<=0 then
                num = num -1
                if num == 0 then
                    PopupTipPanel.ShowTipByLanguageId(12263)
                    Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
                    return
                end
            end
        end

        local var=PlayerManager.uid.."GeneralPopup_TrialSettingBtn"..1--1是是否自动战斗
        if pointView.cell.Style == 1 then
            this.SetCtrlState(true)
            MapPlayerView.SetRoleBattleAction()
            MapPlayerView.SetBattleState(true)
            
            if PlayerPrefs.GetInt(var)==1 then--自动战斗是否开启
                Timer.New(function ()
                    this.SetCtrlState(false)
                    triggerFunc()
                end , 1):Start()
            else
                this.SetCtrlState(false)
                triggerFunc()
            end
        else
            MapPlayerView.SetBattleState(true)
            if PlayerPrefs.GetInt(var)==1 then--自动战斗是否开启
                Timer.New(function ()
                    triggerFunc()
                end , 1):Start()
            else
                triggerFunc()
            end
        end

    end)

    if pointView and pointView.cell and pointView.cell.TriggerRules == 1 then
        --引导阶段监听触发
        Game.GlobalEvent:DispatchEvent(GameEvent.Guide.MapPosTriggered, u, v, callList)
    end
end

function this.EventTrigger(u, v)
    local pos = Map_UV2Pos(u, v)
    -- 如果当前已经到了地图的限制时间不再触发
    if MapManager.isTimeOut then
        return 
    end
    if MapManager.progressFull then return end
    if CarbonManager.difficulty == CARBON_TYPE.TRIAL and MapTrialManager.isChangeLevel then

    end

    --触发事件时，将请求加入到逻辑栈中，监听事件点的变化，当事件点不再变化，或者被销毁时，说明事件交互结束
    callList:Push(function ()
        local pointView = pointHandleView.EventPoint[pos]

        if not pointView or not pointView.cell or pointView.cell.TriggerRules ~= 2 then  --覆盖触发
            this.CallListPop()
            return
        end
        -- 触发了事件
        if not isEventTrigger then
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.StopWalk)
            isEventTrigger = true
            EndLessMapManager.isTrigger = true
            this.SetCtrlState(true)

        end
        pointView:ShowHidePoint()

        MapManager.MapUpdateEvent(pos, function ()
            if pointHandleView.IsAShinningPoint(MapManager.mapPointList[pos]) then
                pointHandleView.RemoveTipPoint(u, v)
            end
        end)
    end)
end

function this.RectangleTrigger(u, v)
    this.AsideTrigger(u - 1, v - 1)
    this.AsideTrigger(u , v - 1)
    this.AsideTrigger(u + 1, v - 1)
    this.AsideTrigger(u - 1, v)
    this.AsideTrigger(u + 1, v )
    this.AsideTrigger(u - 1, v + 1)
    this.AsideTrigger(u , v + 1)
    this.AsideTrigger(u + 1, v + 1)
end

-- 玩家周围8个格子触发
function this.AsideTrigger(u, v)
    local pos = Map_UV2Pos(u, v)
    local eventPoint = pointHandleView.EventPoint[pos]
    if eventPoint and eventPoint.cell then
        -- 在八格子外的时候设置动画
        eventPoint:SetPointAnimation(eventPoint.iconId, 2)

        -- 先拿无尽副本开刀
        if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
            -- 12 ---> 商人
            -- 1  ---> 小怪
            if eventPoint.iconId == MapIconType.ICON_BUSY_WANDER_MAN then
                iconShow.SetIconShowByType(eventPoint, pos, MapPlayerView)
            end
        end
    end

end

function this.OnEventTriggerEnd()
    
    -- 事件结束
    if isEventTrigger then
        isEventTrigger = false
        EndLessMapManager.isTrigger = false
        -- if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        --     -- 激活小伙子
        --     -- MapPlayerView.PlayerIdle()
        -- end
    end

    -- 继续寻路
    MapPlayerView.SetBattleState(false)
    this.CallListPop()
    this.SetCtrlState(false)
end

-- 寻路状态初始化
function this.InitPath()
   
    isEventTrigger = false
    this.ClearCallList()
    this.DragCtrl:SetActive(true)
end

-- 获得事件触发状态
function this.GetTriggerState()
    return isEventTrigger
end


function this.CallListPop()
    --当事件交互结束，抛出下一个栈
    if callList:Count() > 0 then
        callList:Pop()()
    end
end

function this.ClearCallList()
    callList:Clear()
    if not hasDisposed then
        TileMapView.ClearPath()
    end
    pathList = nil

end

function this.Dispose()
    -- UIManager.camera.clearFlags = CameraClearFlags.Skybox
    hasDisposed = true
    TileMapView.Exit()
    TileMapController.Exit()
    if this.Ctrl then
        poolManager:UnLoadAsset(mapCtrl, this.Ctrl, PoolManager.AssetType.GameObject)
    end
    this.Ctrl = nil
end

return this