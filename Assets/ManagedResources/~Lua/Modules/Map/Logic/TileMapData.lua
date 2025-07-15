---定义地图逻辑数据
TileData = {}
TileData.__index = TileData

function TileData.New(u, v, val)
    local instance = {}
    instance.u = u
    instance.v = v
    instance.val = val
    instance.isOpen = false
    instance.nearVal = 0
    setmetatable(instance, TileData)
    return instance
end

TileMapData = {}
TileMapData.__index = TileMapData
local this = TileMapData

local _getTileCost = function (u, v)
    return 1
end

local _getDistance = function (u, v, eu, ev)
    return math.abs(u-eu) + math.abs(v-ev)
end

local _getCost = function (self, u, v)
    return self._openList[Map_UV2Pos(u, v)][4]
end

local _initCloseList = function (self)
    self._closeList = {}
    for i = 1, self.uLen do
        for j = 1, self.vLen do
            self._closeList[Map_UV2Pos(i, j)] = false
        end
    end
end

local _initOpenList = function (self, eu, ev)
    self._openList = {}
    for i = 1, self.uLen do
        for j = 1, self.vLen do
            local list = {}
            list[1] = 0 --定义地块是否存在 0不存在 1存在
            list[2] = _getTileCost(i, j) --定义地块消耗值
            list[3] = _getDistance(i, j, eu, ev) --定义总距离
            list[4] = list[2] + list[3] --定义路径总损耗
            list[5] = 0 --定义方向值 0无 1下 2上 3左 4右
            self._openList[Map_UV2Pos(i, j)] = list
        end
    end
    self._openListLen = 0
end

local _addOpenList = function (self, u, v)
    if self._openList[Map_UV2Pos(u, v)][1] == 0 then
        self._openList[Map_UV2Pos(u, v)][1] = 1
        self._openListLen = self._openListLen + 1
    end
end

local _removeOpenList = function (self, u, v)
    if self._openList[Map_UV2Pos(u, v)][1] == 1 then
        self._openList[Map_UV2Pos(u, v)][1] = 0
        self._openListLen = self._openListLen - 1
    end
end

local _setCost = function (self, u, v, eu, ev)
    local list = self._openList[Map_UV2Pos(u, v)]
    local newlist = self._openList[Map_UV2Pos(eu, ev)]
    list[2] = newlist[2] + _getTileCost(u, v)
    list[3] = _getDistance(u, v, eu, ev)
    list[4] = list[2] + list[3]
end

local _setFatherDir = function (self, u, v, dir)
    self._openList[Map_UV2Pos(u, v)][5] = dir
end

local _isCanPass = function (self, u, v)
    --超出边界
    if u < 1 or u > self.uLen or v < 1 or v > self.vLen then
        return false
    end
    --在关闭列表中
    if self._closeList[Map_UV2Pos(u, v)] then
        return false
    end
    --地图不通
    if not self._checkPassFunc(self:GetMapData(u, v)) then
        return false
    end
    return true
end

local _addNewOpenList = function (self, u, v, nU, nV, dir)
    if _isCanPass(self, nU, nV) then
        local list = self._openList[Map_UV2Pos(u, v)]
        local newlist = self._openList[Map_UV2Pos(nU, nV)]
        if list[1] == 1 then
            if list[2] + _getTileCost(u, v) < newlist[2] then
                _setFatherDir(self,nU, nV, dir)
                _setCost(self,nU, nV, u, v)
            end
        else
            _addOpenList(self, nU, nV)
            _setFatherDir(self, nU, nV, dir)
            _setCost(self, nU, nV, u, v)
        end
    end
end

local _aStar = function (self, tileStart, tileEnd)
    local x = tileStart.u
    local y = tileStart.v
    local cost
    local minDistance = _getDistance(tileEnd.u, tileEnd.v, tileStart.u, tileStart.v)
    local nearestData = tileStart --当目标点不可达时，选择最近的可达点
    local distance
    for t = 1, 5000 do --控制算法深度
        if x == tileEnd.u and y == tileEnd.v then
            return nearestData
        elseif self._openListLen == 0 then
            return nearestData
        end

        _removeOpenList(self,x, y)
        self._closeList[Map_UV2Pos(x, y)] = true

        --该点周围能够行走的点
        _addNewOpenList(self,x,y,x,y+1,2)
        _addNewOpenList(self,x,y,x,y-1,1)
        _addNewOpenList(self,x,y,x-1,y,4)
        _addNewOpenList(self,x,y,x+1,y,3)

        --找到估值最小的点，进行下一轮算法
        cost = 2 ^ 32
        --随机选择遍历方式，从而得到随机寻路路径
        for k, v in pairs(self._openList) do
            if v[1] == 1 then
                local i, j = Map_Pos2UV(k)
                if cost > _getCost(self, i, j) then
                    cost = _getCost(self, i, j)
                    x = i
                    y = j
                    distance = _getDistance(tileEnd.u, tileEnd.v, i, j)
                    if distance < minDistance then
                        nearestData = self:GetMapData(i, j)
                        minDistance = distance
                    end
                end
            end
        end
    end

    --算法超深
    return nearestData
end

function this.New(ulen, vlen)
    local instance = {}
    instance.uLen = ulen
    instance.vLen = vlen
    instance.mapData = {}
    for i = 1, ulen do
        for j = 1, vlen do
            instance.mapData[Map_UV2Pos(i, j)] = TileData.New(i, j,0)
        end
    end
    setmetatable(instance, TileMapData)
    return instance
end

function this:GetMapData(u, v)
    return self.mapData[Map_UV2Pos(u, v)]
end

function this:UpdateFogArea(u, v, rad)
    for i = math.max(u-rad, 1), math.min(u+rad, self.uLen) do
        for j = math.max(v-rad, 1), math.min(v+rad, self.vLen) do
            if math.abs(i-u) + math.abs(j-v) <= rad then
                self:GetMapData(i, j).isOpen = true
            end
        end
    end
end

--寻路算法 返回的结果是从终点指向起点(包括起点)的坐标列表
function this:FindPath(tileStart, tileEnd, checkPassFunc)
    if not tileStart or not tileEnd or tileStart == tileEnd then
        return nil
    end

    self._checkPassFunc = checkPassFunc

    _initCloseList(self)
    _initOpenList(self,tileStart.u, tileStart.v)
    _addOpenList(self,tileStart.u, tileStart.v)

    local targetData = _aStar(self,tileStart, tileEnd)
    local resList = {}
    local x = targetData.u
    local y = targetData.v
    while x ~= tileStart.u or y ~= tileStart.v do
        table.insert(resList, self:GetMapData(x, y))
        local dir = self._openList[Map_UV2Pos(x, y)][5]
        if dir == 1 then
            y = y + 1
        elseif dir == 2 then
            y = y - 1
        elseif dir == 3 then
            x = x - 1
        elseif dir == 4 then
            x = x + 1
        end
    end
    table.insert(resList, self:GetMapData(tileStart.u, tileStart.v))
    return resList
end