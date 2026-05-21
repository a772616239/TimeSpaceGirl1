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