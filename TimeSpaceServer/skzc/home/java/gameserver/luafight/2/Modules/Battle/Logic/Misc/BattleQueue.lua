BattleQueue = {}
function BattleQueue.New()
    local o = {}
    setmetatable(o, BattleQueue)
    BattleQueue.__index = BattleQueue
    o.head = -1
    o.rear = -1
    o.list = {}
    o.size = 0
    return o
end

function BattleQueue:Enqueue(e)
    if self.size == 0 then
        self.head = 0
        self.rear = 1
        self.size = 1
        self.list[self.rear] = e
    else
        self.rear = self.rear + 1
        self.list[self.rear] = e
        self.size = self.size + 1
    end
end

function BattleQueue:Dequeue()
    if self.size == 0 then
        error("lua queue is isEmpty")
        return nil
    end
    self.size = self.size - 1
    self.head = self.head + 1
    return self.list[self.head]
end

function BattleQueue:Clear()
    --self.list = {}
    self.size = 0
    self.head = -1
    self.rear = -1
end

function BattleQueue:Count()
    return self.size
end

function BattleQueue:Foreach(func)
    for i = self.head + 1, self.rear do
        if func then
            func(self.list[i])
        end
    end
end

function BattleQueue:Contain(e)
    for i = self.head + 1, self.rear do
        if e == self.list[i] then
            return true
        end
    end
    return false
end   