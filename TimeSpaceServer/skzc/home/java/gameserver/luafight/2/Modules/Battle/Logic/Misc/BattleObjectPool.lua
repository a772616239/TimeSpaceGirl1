BattleObjectPool = {}
function BattleObjectPool.New(onCreate)
    local o = {}
    setmetatable(o, BattleObjectPool)
    BattleObjectPool.__index = BattleObjectPool
    o.buffer = {}
    o.size = 0
    o.onCreate = onCreate
    return o
end

function BattleObjectPool:Get(...)
    local e = self.buffer[self.size]
    if not e then
        return self.onCreate(...)
    end
    self.size = self.size - 1
    return e
end

function BattleObjectPool:Put(item)
    self.size = self.size + 1
    self.buffer[self.size] = item
end   