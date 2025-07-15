BattleEvent={}
BattleEvent.__index = BattleEvent

local listPool = BattleObjectPool.New(function ()
    return BattleList.New()
end)
local itemPool = BattleObjectPool.New(function ()
    return { func = 0, obj = 0, once = false }
end)
function BattleEvent.New()
    local instance = {}
    setmetatable(instance, BattleEvent)
    instance.m_listeners = {}
    return instance
end

function BattleEvent:AddEvent(sEventName, fListener, pObj, bOnce)
    if not self.m_listeners[sEventName] then
        self.m_listeners[sEventName] = listPool:Get()
    end
    local item = itemPool:Get()
    item.func = fListener
    item.obj = pObj
    item.once = bOnce
    self.m_listeners[sEventName]:Add(item)
end

function BattleEvent:RemoveEvent(sEventName, fListener, pObj)
    if not self.m_listeners[sEventName] then
        return
    end
    local v
    for i=1, self.m_listeners[sEventName].size do
        v = self.m_listeners[sEventName].buffer[i]
        if v.func == fListener and pObj == v.obj then
            itemPool:Put(v)
            self.m_listeners[sEventName]:Remove(i)
            break
        end
    end
end

function BattleEvent:DispatchEvent(sEventName, ...)
    if not self.m_listeners[sEventName] then
        return
    end
    local v
    for i=1, self.m_listeners[sEventName].size do
        v = self.m_listeners[sEventName].buffer[i]
        if not v.obj then
            v.func(...)
        else
            v.func(v.obj, ...)
        end
        if v.once then
            self:RemoveEvent(sEventName, v)
        end
    end
end
function BattleEvent:ClearEvent()
    for k, v in pairs(self.m_listeners) do
        for i=1, v.size do
            itemPool:Put(v.buffer[i])
        end
        v:Clear()
        listPool:Put(v)
        self.m_listeners[k]=nil
    end
end


-- 此处函数需要验证 pObj 为隐式 在战斗逻辑缺少对视图层个 clone 此方法暂未实现
function BattleEvent:Clone()
    local instance = BattleEvent.New()
    -- if  #self.m_listeners <= 0 then
    --     return
    -- end

    -- local v
    -- for sEventName,listPool in pairs(self.m_listeners) do
    --     for i=1, self.m_listeners[sEventName].size do
    --         v = self.m_listeners[sEventName].buffer[i]
    --         if v.func == fListener and pObj == v.obj then
    --             itemPool:Put(v)
    --             self.m_listeners[sEventName]:Remove(i)
    --             break
    --         end
    --     end
    -- end

    return instance
end