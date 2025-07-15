require("Base/Stack")
require("Modules/Map/Logic/TileMapController")
require("Modules/Map/Logic/TileMapView")
require("Modules/MapFight/View/MapAgent")
require("Modules/MapFight/View/MapActor")
require("Modules/MapFight/View/MapPointMineral")

local this = {}

local funcCanPass = function(data) return data.val <= 1 end
local mapCtrl = "MapCtrl"

local selfAgentView = {agent = nil, callList = Stack.New()}
local otherAgentViews = {}
local mineralViews = {}
local wallViews = {}

local targetPos
local clearSelfPathFlag = true

local function IsCanMove()
    return selfAgentView and selfAgentView.agent.agentData.state == 5
end

local function clear(agentView)
    local call = agentView.callList
    if agentView.tweener then
        agentView.tweener:Kill()
        agentView.tweener = nil
    end
    call:Clear()
end

local function move(pathList, agentView, isSelf)
    local call = agentView.callList
    local agent = agentView.agent

    clear(agentView)
    --把最终回调最先入栈
    call:Push(function ()
        
        if isSelf then
            clearSelfPathFlag = true
        end
        agent:PlayerIdle()
    end)

    for i=1, #pathList do
        local data = pathList[i]
        local v3 = TileMapView.GetLiveTilePos(data.u, data.v)

        call:Push(function ()
            agent:SetRoleDirAction(data.u, data.v)

            if agent.agentData.type == 1 then
                agentView.tweener = agent.leader.transform:DOLocalMove(Vector3.New(v3.x, v3.y, v3.z - 10), agent.agentData.speed, false):OnStart(function()
                    if isSelf then
                        clearSelfPathFlag = false
                    end
                end):OnUpdate(function()
                    if not isSelf then
                        return
                    end
                    local v3 = agent.leader.transform.localPosition
                    v3.z = TileMapView.ViewCameraPos.z
                    TileMapView.SetCameraPos(v3)
                    TileMapView.UpdateBaseData()
                end):OnComplete(function ()
                    if call:Count() < 1 then
                       
                        return
                    end
                    agent:RefreshPos(data.u, data.v)
                    if isSelf then
                        TileMapView.ClearPathTile(data.u, data.v)
                        clearSelfPathFlag = true
                    end
                    call:Pop()()
                end):SetEase(Ease.Linear)
            else
                agentView.tweener = agent.leader:GetComponent("RectTransform"):DOAnchorPos3D(v3 * 100, agent.agentData.speed, false):OnComplete(function ()
                    if call:Count() < 1 then
                       
                        return
                    end
                    agent:RefreshPos(data.u, data.v)
                    call:Pop()()
                end):SetEase(Ease.Linear)
            end
        end)
    end
    if isSelf then
        TileMapView.ClearPathTile(agent.posData.u, agent.posData.v)
    end
    call:Pop()()
end

local function update()
    if targetPos and clearSelfPathFlag and IsCanMove() then
        clearSelfPathFlag = false

        local posData = selfAgentView.agent.posData
        local pathList = TileMapView.ShowPath(posData.u, posData.v, targetPos.u, targetPos.v, funcCanPass)

        if pathList then
            MapFightManager.RoomSyncMyselfMoveRequest(pathList, function (result)
                if result == 1 then
                    table.reverse(pathList, 1, #pathList)
                    table.remove(pathList, #pathList)
                    move(pathList, selfAgentView, true)
                else
                    TileMapView.ClearPath()
                end
            end)
        else
            clearSelfPathFlag = true
        end
        targetPos = nil
    end
end

function this.InitComponent(gameObject)
    this.DragCtrl = Util.GetGameObject(gameObject, "Ctrl")
end

function this.AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.Move, this.OnMove)
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.AgentAdd, this.OnAgentAdd)
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.MineralPointAdd, this.OnMineralAdd)
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.PositionChange, this.OnPositionChange)
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.AgentRemove, this.OnAgentRemove)
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.MineralPointRemove, this.OnMineRemove)

    UpdateBeat:Add(update, this)
end

function this.RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.Move, this.OnMove)
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.AgentAdd, this.OnAgentAdd)
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.MineralPointAdd, this.OnMineralAdd)
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.PositionChange, this.OnPositionChange)
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.AgentRemove, this.OnAgentRemove)
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.MineralPointRemove, this.OnMineRemove)

    UpdateBeat:Remove(update, this)
end

function this.Init()
    UIManager.camera.clearFlags = CameraClearFlags.Depth

    
    this.Ctrl = poolManager:LoadAsset(mapCtrl, PoolManager.AssetType.GameObject)
    this.Ctrl.name = mapCtrl
    this.Ctrl.transform:SetParent(UIManager.uiRoot.transform.parent)
    this.Ctrl.transform.position = Vector3.New(0, 0, -100)

    TileMapView.OnInit = this.OnInit
    TileMapView.fogSize = 2
    TileMapView.AwakeInit(this.Ctrl, 12)

    TileMapController.IsShieldDrag = function() return true end
    TileMapController.OnClickTile = this.OnClickTile
    TileMapController.Init(this.Ctrl, this.DragCtrl)

    TileMapView.Init()

    wallViews = {}
    for i=1, #MapFightManager.walls do --设置阻挡点
       
        TileMapView.GetTileData(Map_Pos2UV(MapFightManager.walls[i])).val = 2
        local go = poolManager:LoadAsset("mapButtonPoint", PoolManager.AssetType.GameObject)
        go.transform:SetParent(Util.GetTransform(this.Ctrl, "uiObj#"))
        go:GetComponent("Image").sprite = Util.LoadSprite("r_map_xiangzi")
        go:GetComponent("Image"):SetNativeSize()
        go.name = "mapButtonPoint"
        go:SetActive(true)
        local goPos = TileMapView.GetLiveTilePos(Map_Pos2UV(MapFightManager.walls[i])) * 100
        go:GetComponent("RectTransform").anchoredPosition3D = goPos + Vector3.New(0, 0, 0)
        go.transform.localScale = Vector3.one
        wallViews[MapFightManager.walls[i]] = go
    end

    selfAgentView.callList:Clear()
    if MapFightManager.selfAgent then
        selfAgentView.agent = MapAgent.New(true, MapFightManager.selfAgent, this.Ctrl)
        local u, v = Map_Pos2UV(MapFightManager.selfAgent.curXY)
        TileMapController.LocateToUV(u, v)
    end

    if MapFightManager.otherAgents then
        for k, v in pairs(MapFightManager.otherAgents) do
            if v.type == 1 then --玩家
                otherAgentViews[k] = {
                    agent = MapAgent.New(false, v, this.Ctrl),
                    callList = Stack.New(),
                }
            elseif v.type == 2 or v.type == 3 then --怪（可巡逻）
                otherAgentViews[k] = {
                    agent = MapActor.New(v, this.Ctrl),
                    callList = Stack.New(),
                }
            end
        end
    end
end

function this.OnInit()
end

function this.SelfMove()
end

function this.OnClickTile(u, v)
    local selfAgent = selfAgentView.agent
    -- 点击角色
    if u == selfAgent.posData.u and v == selfAgent.posData.v then
        selfAgent:OnClick()
        return
    end
    ---- 点击目标位置，不生效
    --if targetPos and u == targetPos.u and v == targetPos.v then
    --    return
    --end
    -- TODO:当状态不为可移动时，不能行走！
    if not IsCanMove() then

        return
    end
    --- 判断点击位置是否超出地图区域
    targetPos = TileMapView.GetTileData(u, v)
end

function this.OnMove(uid, pointList)
    if otherAgentViews[uid] then
        
        local pathList = {}
        for i=1, #pointList do
            table.insert(pathList, TileMapView.GetMapData():GetMapData(Map_Pos2UV(pointList[i])))
        end
        move(pathList, otherAgentViews[uid], false)
    end
end

function this.OnAgentAdd(agent)
   
    if agent.type == 2 or agent.type == 3 then --怪（可巡逻）
        -- 要是uid相同的话，会可能将怪和矿生成在一起，所以服务器推送的点必须是一个空点
        if not otherAgentViews[agent.playerUid] then
            otherAgentViews[agent.playerUid] = {
                agent = MapActor.New(agent, this.Ctrl),
                callList = Stack.New(),
            }
        end
    end
end

function this.OnMineralAdd(mineral)
   
    mineralViews[mineral.pos] = MapPointMineral.New(mineral, this.Ctrl)
end

-- 死掉一只怪或者是少了一个矿
function this.OnAgentRemove(agent)
    if otherAgentViews[agent.playerUid] then
        otherAgentViews[agent.playerUid] = nil
    end
end

-- 清除一个散矿
function this.OnMineRemove(mine)
    if mineralViews[mine.pos] then
        mineralViews[mine.pos] = nil
    end
end

--收到该推送立马打断寻路并更新位置
function this.OnPositionChange(uid, xy)
    if otherAgentViews[uid] then

        clear(otherAgentViews[uid])
        otherAgentViews[uid].agent:RefreshPos(Map_Pos2UV(xy))
        otherAgentViews[uid].agent:PlayerIdle()
    end
    local selfAgent = selfAgentView.agent
    if selfAgent.agentData.playerUid == uid then
        TileMapController.LocateToUV(Map_Pos2UV(xy))
        clearSelfPathFlag = true
        clear(selfAgentView)
        TileMapView.ClearPath()
        selfAgent:RefreshPos(Map_Pos2UV(xy))
        selfAgent:PlayerIdle()
    end
end

function this.Dispose()
    -- UIManager.camera.clearFlags = CameraClearFlags.Skybox

    TileMapView.Exit()
    TileMapController.Exit()
    poolManager:UnLoadAsset(mapCtrl, this.Ctrl, PoolManager.AssetType.GameObject)
    this.Ctrl = nil

    if selfAgentView.agent then
        clear(selfAgentView)
        selfAgentView.agent:Dispose()
    end
    for k, v in pairs(otherAgentViews) do
        clear(otherAgentViews[k])
        if otherAgentViews[k] then
            otherAgentViews[k].agent:Dispose()

            otherAgentViews[k] = nil
        end
    end
    for k, v in pairs(mineralViews) do
        if mineralViews[k] then
            mineralViews[k]:Dispose()
            mineralViews[k] = nil
        end
    end
    for k, v in pairs(wallViews) do
        poolManager:UnLoadAsset("mapButtonPoint", v, PoolManager.AssetType.GameObject)
        wallViews[k] = nil
    end
end

return this