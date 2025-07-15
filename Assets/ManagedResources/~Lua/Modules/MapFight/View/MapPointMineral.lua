MapPointMineral = {}
MapPointMineral.__index = MapPointMineral

local mapNpcOp = "UI_MapPoint_mineral"

function MapPointMineral.New(mineral, Ctrl)
    local instance = {}
    setmetatable(instance, MapPointMineral)

    instance.mineralData = mineral

    local u, v = Map_Pos2UV(mineral.pos)

    instance.posData = TileMapView.GetMapData():GetMapData(u, v)

    instance.leader = poolManager:LoadAsset(mapNpcOp, PoolManager.AssetType.GameObject)
    instance.leader.transform:SetParent(Util.GetTransform(Ctrl, "uiObj#"))
    instance.leader:GetComponent("RectTransform").anchoredPosition3D = TileMapView.GetLiveTilePos(u, v) * 100
    instance.leader.transform.localScale = Vector3.one

    instance.num = Util.GetGameObject(instance.leader, "Text"):GetComponent("Text")
    instance.num.text = tostring(mineral.nums)

    instance:AddListener()

    instance.leader:SetActive(true)
    return instance
end

function MapPointMineral:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.MineralPointRemove, self.OnRemove, self)
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.MineralPointChange, self.OnRefreshNums, self)
end

--移除事件监听（用于子类重写）
function MapPointMineral:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.MineralPointRemove, self.OnRemove, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.MineralPointChange, self.OnRefreshNums, self)
end

function MapPointMineral:OnRemove(agent)
    if agent.pos ~= self.mineralData.pos then return end

    self:Dispose()
end

function MapPointMineral:OnRefreshNums(agent)
    if agent.pos ~= self.mineralData.pos then return end
    self.num.text = tostring(agent.nums)
    self.mineralData.nums = agent.nums
end

function MapPointMineral:Dispose()
    self:RemoveListener()
    poolManager:UnLoadAsset(mapNpcOp, self.leader, PoolManager.AssetType.GameObject)
end