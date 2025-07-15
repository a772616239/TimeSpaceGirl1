RoleData = {}
RoleData.__index = RoleData
local max = math.max
local floor = math.floor
local function isFactor(name)
    return name > 7
end

function RoleData.New()
    local instance = {role=0, data={0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0},
                      orginData={0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0,0,0,  0,0,0}}
    setmetatable(instance, RoleData)
    return instance
end

function RoleData:Clone(_role)
    local _clone = RoleData.New()
    _clone.role = _role
    local max = max(#_clone.data, #self.data)
    for i=1, max do
        _clone.data[i] = self.data[i] 
        _clone.orginData[i] = self.orginData[i] 
    end
    return _clone
end

function RoleData:RoleBack(_role,_cpRoleDate)
    self.role = _role
    local max = max(#_cpRoleDate.data, #self.data)
    for i=1, max do
       self.data[i] = _cpRoleDate.data[i]
       self.orginData[i] =_cpRoleDate.orginData[i]
    end
end

function RoleData:Init(role, data)
    self.role = role
    local max = max(#data, #self.data)
    for i=1, max do
        self.data[i] = BattleUtil.ErrorCorrection(data[i] or 0)
        self.orginData[i] = BattleUtil.ErrorCorrection(data[i] or 0)
    end
end

local function tableKin(_tb,_k)
    for k,v in pairs(_tb) do
        if k==_k then return true end
    end
    return false
end

function RoleData:GetData(name)
    -- for prop in pairs(self.data) do
    --     BattleLogManager.Log(
    --         "hero:"..self.role.roleId..
    --         " camp：".. self.role.camp..
    --         " position："..self.role.position..
    --         " name：".. name, 
    --         " value："..self.data[name])
    -- end    
    if tableKin(self.data,name) then 
        return self.data[name]
    end
    return nil
end

local function tableKin(_tb,_k)
    for k,v in pairs(_tb) do
        if k==_k then return true end
    end
    return false
end

function RoleData:GetOrginData(name)
    return self.orginData[name]
end

function RoleData:SetValue(name, value)
    if self.data[name] then
        local delta = self.data[name]
        self.data[name] = value
        delta = value - delta
        if delta ~= 0 then
            self.role.Event:DispatchEvent(BattleEventName.RolePropertyChanged, name, value, delta)
            -- BattleLogManager.Log(
            --     self.role.roleId..":property change", 
            --     "camp", self.role.camp, 
            --     "position", self.role.position, 
            --     "propId", name, 
            --     "value", value)
        end
    end
end

function RoleData:AddValue(name, delta)
    if delta < 0 or not self.data[name] then --delta必须非负
        return 0
    end
    if self.data[name] then

        self:SetValue(name, self.data[name] + delta)
    end
    return delta
end

function RoleData:AddPencentValue(name, pencent)
    if self.data[name] then
        local delta
        if isFactor(name) then
            delta = BattleUtil.ErrorCorrection(self.orginData[name] * pencent)
        else
            delta = floor(self.orginData[name] * pencent)
        end
        return self:AddValue(name, delta)
    end 
    return 0
end

function RoleData:SubDeltaValue(name, delta)
    if not delta or delta < 0 or not self.data[name] then --delta必须非负
        return 0
    end
    if self.data[name] then
        -- RoleManager.LogCa(
        --     "SubDeltaValue curframe:"..BattleLogic.CurFrame(),
        --     "name:"..name,
        --     "data:"..(self.data[name] - delta)
        -- )
        self:SetValue(name, self.data[name] - delta)
    end
    return delta
end

function RoleData:SubValue(name, delta)
    if delta < 0 or not self.data[name] then --delta必须非负
        return 0
    end
    local orVal = self.data[name]
    if isFactor(name) then      
        if orVal then    
            self:SetValue(name, self.data[name] - delta)
            orVal = orVal - self.data[name]
        end
        return orVal
    else
        if orVal then    
            self:SetValue(name, max(self.data[name] - delta,0))
            orVal = orVal - self.data[name]
        end
        return orVal
    end
end

function RoleData:SubPencentValue(name, pencent)
    if self.data[name] then
        local delta
        if isFactor(name) then
            delta = BattleUtil.ErrorCorrection(self.orginData[name] * pencent)
        else
            delta = floor(self.orginData[name] * pencent)
        end
        return self:SubValue(name, delta)
    end
    return 0
end

function RoleData:CountValue(name, value, ct)
    if ct == 1 then
        self:AddValue(name, value)
    elseif ct == 2 then
        self:AddPencentValue(name, value)
    elseif ct == 3 then
        self:SubValue(name, value)
    elseif ct == 4 then
        self:SubPencentValue(name, value)
    end
end

--Debug
function RoleData:Foreach(func)
    for k,v in ipairs(self.data) do
        func(k, v)
    end
end