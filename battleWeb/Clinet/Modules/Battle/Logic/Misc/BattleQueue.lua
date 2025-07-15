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

--浅克隆
function BattleQueue:Clone()
    local _quen = BattleQueue.New()
    for i = self.head + 1, self.rear do
        _quen:Enqueue(self.list[i])
    end
    return _quen
end

--删除index元素
function BattleQueue:Delete(index)
    if index > self.size then return nil end
    local obj = self.list[index]
    -- 队尾移动
    for i = index, self.rear do
        self.list[i]  = self.list[i+1] 
    end
    self.size = self.size - 1
    self.rear = self.rear - 1
    return obj
end

--删除对象元素
function BattleQueue:DeleteObj(obj)
    local searchfunc = function(_obj)
        return obj == _obj
    end
    local index = self:SearchIndex(searchfunc)
    if index < 0 then return nil end
    return self:Delete(index)
end

--删除对象元素
function BattleQueue:DeleteObjBy(obj,Icompare)
    local searchfunc = function(_obj)
        return Icompare(obj,_obj)
    end
    local index = self:SearchIndex(searchfunc)
    if index < 0 then return nil end
    return self:Delete(index)
end

function BattleQueue:DeleteFunc(func)
    local IsNul = false
    while not IsNul do
        local index = self:SearchIndex(func)
        if index < 0 then
            IsNul = true
        else
            self:Delete(index)
        end
    end
end

-- 查找Icompare元素 返回下标
function BattleQueue:SearchIndex(Icompare)
    if self.size < 0 then return -1 end
    for i = self.head + 1, self.rear do
        if Icompare and Icompare(self.list[i]) then
            return i
        end
    end
    return -1
end

-- 查找Icompare元素 返回对象
function BattleQueue:SearchObject(Icompare)
    if self.size < 0 then return nil end
    for i = self.head + 1, self.rear do
        if Icompare and Icompare(self.list[i]) then
            return self.list[i]
        end
    end
    return nil
end