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

function BattleObjectPool:Foreach(func)
    if self.size<=0 then  return  end
    for i=1,self.size do
        if func then
            func(self.buffer[i])
        end
    end
end


function BattleObjectPool:Find(obj,ICompare)
    if self.size<=0 then  return  end
    for i=1,self.size do
        if ICompare ~=nil then
            if ICompare(obj,self.buffer[i]) then
                return self.buffer[i]
            end
        end
    end
    --LogError("f role:"..obj.roleId)
    return nil
end

function BattleObjectPool:Count()
    return self.size
end

--浅克隆
function BattleObjectPool:Clone()
    local _battlePool =BattleObjectPool.New(self.onCreate)
    if self.size<=0 then  return _battlePool end
    for i , v in pairs(self.buffer) do 
        _battlePool:Put(self.buffer[i]) -- table
    end
    return _battlePool
end

--浅克隆
function BattleObjectPool:CloneType(str)
    local _battlePool =BattleObjectPool.New(self.onCreate)
    if self.size<=0 then  return _battlePool end
    if str == "RoleLogic" then
        for i , v in pairs(self.buffer) do 
            local _role = self.buffer[i]
            --LogError(type(_role))
            _battlePool:Put(_role:Clone()) -- table
        end
    else
        for i , v in pairs(self.buffer) do 
            --LogError(type(self.buffer[i]))
            _battlePool:Put(self.buffer[i]) -- table
        end
    end
    return _battlePool
end

