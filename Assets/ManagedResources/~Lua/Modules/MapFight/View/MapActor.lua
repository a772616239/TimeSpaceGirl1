MapActor = {}
MapActor.__index = MapActor

local mapNpcOp = "UI_MapPoint_actor"

local mapActorConfig = {
    [2] = "live2d_boss_01",
    [3] = "UI_effect_TanSuo_ShuiJing",
}
function MapActor.New(agentData, Ctrl)
    local instance = {}
    setmetatable(instance, MapActor)

    instance.agentData = agentData

    local u, v = Map_Pos2UV(agentData.curXY)

    instance.posData = TileMapView.GetMapData():GetMapData(u, v)
    instance.leader = poolManager:LoadAsset(mapNpcOp, PoolManager.AssetType.GameObject)
    instance.roleYellowHp = Util.GetGameObject(instance.leader, "hp/hpYellow"):GetComponent("Image")

    instance.livePath = mapActorConfig[agentData.type]
    local type = Util.GetGameObject(instance.leader, "type")
    if agentData.type == 2 then
        instance.live = poolManager:LoadLive(instance.livePath, Util.GetTransform(instance.leader, "root"),
                Vector3.one * 0.8, Vector3.zero)
        instance.SkeletonGraphic = instance.live:GetComponent("SkeletonGraphic")
        instance.SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
    elseif agentData.type == 3 then
        instance.live = poolManager:LoadAsset(instance.livePath, PoolManager.AssetType.GameObject)
        instance.live.transform:SetParent(Util.GetTransform(instance.leader, "root"))
        instance.live.transform.localScale = Vector3.one
        instance.live.transform.localPosition = Vector3.zero

        if agentData.maxHp > 5 then   -- TODO:临时大矿
            type:GetComponent("Text").text = GetLanguageStrById(11332)
        else
            type:GetComponent("Text").text = GetLanguageStrById(11333)
        end

    end

    type:SetActive(agentData.type == 3)

    instance.roleYellowHp.fillAmount = agentData.curHp / agentData.maxHp

    instance.leader.transform:SetParent(Util.GetTransform(Ctrl, "uiObj#"))

    instance.leader:GetComponent("RectTransform").anchoredPosition3D = TileMapView.GetLiveTilePos(u, v) * 100
    instance.leader.transform.localScale = Vector3.one

    instance:AddListener()
    instance:RefreshPos(u, v)

    instance.leader:SetActive(true)
    return instance
end

function MapActor:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.AgentRemove, self.OnAgentRemove, self)
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.HPChange, self.OnRefreshFormationHp, self)
end

--移除事件监听（用于子类重写）
function MapActor:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.AgentRemove, self.OnAgentRemove, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.HPChange, self.OnRefreshFormationHp, self)
end

function MapActor:OnAgentRemove(agent)
    if agent.playerUid ~= self.agentData.playerUid then return end

    self:Dispose()
end

function MapActor:OnRefreshFormationHp(id, hp)
    if id ~= self.agentData.playerUid then return end
   
    self.roleYellowHp.fillAmount = hp / self.agentData.maxHp
end


function MapActor:RefreshPos(u, v)
    self.posData = TileMapView.GetMapData():GetMapData(u, v)
    self.leader:GetComponent("RectTransform").anchoredPosition3D = TileMapView.GetLiveTilePos(u, v) * 100
    self.agentData.curXY = Map_UV2Pos(u, v)
end

-- 设置怪物行走方向
local WALK_DIR = {
    RIGHT = {animation = "move2", y = 0},
    LEFT = {animation = "move2", y = 180},
    UP = {animation = "move3", y = 0},
    DOWN = {animation = "move", y = 0},
}

function MapActor:SetRoleDirAction(u, v, isBack)
    --local dU = isBack and self.posData.u - u or u - self.posData.u
    --local dV = isBack and self.posData.v - v or v - self.posData.v
    --
    --if dU > 0 then
    --    self:SetWalkDir(WALK_DIR.RIGHT)
    --elseif dU < 0 then
    --    self:SetWalkDir(WALK_DIR.LEFT)
    --elseif dV < 0 then
    --    self:SetWalkDir(WALK_DIR.UP)
    --elseif dV > 0 then
    --    self:SetWalkDir(WALK_DIR.DOWN)
    --end
    --SoundManager.PlaySound(SoundConfig.Sound_FootStep..math.random(1,7))
end

function MapActor:SetWalkDir(dir)
    if not self.SkeletonGraphic then return end
    self.SkeletonGraphic.transform.localEulerAngles = Vector3.New(0, dir.y, 0)
    self.SkeletonGraphic.AnimationState:SetAnimation(0, dir.animation, true)
end


function MapActor:PlayerIdle()
    if not self.SkeletonGraphic then return end
    self.SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true)
end

function MapActor:Dispose()
    self:RemoveListener()
    if self.agentData.type == 2 then
        poolManager:UnLoadLive(self.livePath, self.live)
    elseif self.agentData.type == 3 then
        poolManager:UnLoadAsset(self.livePath, self.live, PoolManager.AssetType.GameObject)
    end
    poolManager:UnLoadAsset(mapNpcOp, self.leader, PoolManager.AssetType.GameObject)
end