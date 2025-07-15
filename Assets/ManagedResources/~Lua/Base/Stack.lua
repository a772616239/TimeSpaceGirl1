Stack = {}
function Stack.New()
    local o = {}
    setmetatable(o, Stack)
    Stack.__index = Stack
    o.list = {}
    o.count = 0
    return o
end

function Stack:Push(element)
    self.count = self.count + 1
    self.list[self.count] = element
end

function Stack:Pop()
    if self.count == 0 then
        error('lua stack is isEmpty')
        return
    end
    local e = self.list[self.count]
    self.count = self.count - 1
    return e
end

function Stack:Count()
    return self.count
end

function Stack:Peek()
    return self.list[self.count]
end

function Stack:Contain(e)
    for i=1, self.count do
        if e == self.list[i] then
            return true
        end
    end
    return false
end

function Stack:Foreach(func)
    for i=1, self.count do
        if func then
            func(self.list[i])
        end
    end
end

function Stack:Clear()
    self.list = {}
    self.count = 0
end