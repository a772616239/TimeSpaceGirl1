BattleList = {}
function BattleList.New()
    local o = {}
    setmetatable(o, BattleList)
    BattleList.__index = BattleList
    o.buffer = {}
    o.size = 0
    return o
end

function BattleList:Add(v)
    self.size = self.size + 1
    self.buffer[self.size] = v
end

function BattleList:Remove(index)
    self.size = self.size - 1
    for i=index, self.size do
        self.buffer[i] = self.buffer[i+1]
    end
end

function BattleList:Clear()
    --self.buffer = {}
    self.size = 0
end

function BattleList:Count()
    return self.size
end

 -- 浅克隆
 function BattleList:Clone()
    local _list = BattleList.New()
    _list.size = self.size
    for i , v in pairs(self.buffer) do       
        _list[i]=v
    end
    return _list
end

function BattleList:Contains(_k)
    for k,v in pairs(self.buffer) do
        if k == _k then return true end
    end
    return false
end