BattleDictionary = {}
function BattleDictionary.New()
    local o = {}
    setmetatable(o, BattleDictionary)
    BattleDictionary.__index = BattleDictionary
    o.kL = BattleList.New()
    o.vL = BattleList.New()
    o.kList = o.kL.buffer
    o.vList = o.vL.buffer
    o.kvList = {}
    o.size = 0
    return o
end

function BattleDictionary:Add(k,v)
    if not self.kvList[k] then
        self.size = self.size + 1
        self.kvList[k] = v
        self.kL:Add(k)
        self.vL:Add(v)
    end
end

function BattleDictionary:Remove(k)
    if self.kvList[k] then
        for i=1, self.size do
            if self.vList[i] == self.kvList[k] then
                self.size = self.size - 1
                self.kL:Remove(i)
                self.vL:Remove(i)
                self.kvList[k] = nil
                break
            end
        end
    end
end

function BattleDictionary:Get(k)
    return self.kvList[k]
end

function BattleDictionary:Set(k,v)
    self:Remove(k)
    self:Add(k,v)
end

function BattleDictionary:Clear()
    self.kL:Clear()
    self.vL:Clear()
    self.kvList = {}
    self.size = 0
end

function BattleDictionary:Count()
    return self.size
end

function BattleDictionary:Foreach(func)
    for i = 1, self.size do
        if func then
            if func(self.kList[i], self.vList[i]) == "break" then
                break
            end
        end
    end
end


-- check
function BattleDictionary:Find(obj,ICompare)
    for i = 1, self.size do
        if ICompare ~=nil then
            if ICompare(obj, self.vList[i]) then
                return self.vList[i]
            end
        end
    end
end


function BattleDictionary:ContainsValue(_v)  
    for i = 1, self.size do
        if self.vList[i] == _v then return true end
    end   
    return false
end

function BattleDictionary:Contains(_k) 
    for i = 1, self.size do
        if self.kList[i] == _k then return true end
    end   
    return false
end

 -- 浅克隆
function BattleDictionary:Clone()
    local _dic = BattleDictionary.New()
    for i = 1, #self.kvList do
        _dic.kvList[i] = self.kvList[i] 
        _dic.kL:Add(i)
        _dic.vL:Add(self.kvList[i])
    end
    _dic.size = self.size
    return _dic
end