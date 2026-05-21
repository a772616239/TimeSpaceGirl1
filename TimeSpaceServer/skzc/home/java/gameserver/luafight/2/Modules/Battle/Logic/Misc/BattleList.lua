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