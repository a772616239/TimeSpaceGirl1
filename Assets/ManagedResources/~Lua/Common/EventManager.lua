EventManager = {}
EventManager.__index = EventManager

function EventManager.New()
    local o =  {}
    setmetatable(o, EventManager)
    o.m_listeners = {}
    return o
end

function EventManager:AddEvent(sEventName, fListener, pObj, bOnce)
    if not self.m_listeners[sEventName] then
        if not sEventName then
            LogError("EventManager:AddEvent的sEventName有问题")
        end
        self.m_listeners[sEventName] = {}
    end
    table.insert(self.m_listeners[sEventName],{ func = fListener, obj = pObj, once = bOnce } )
end

function EventManager:RemoveEvent(sEventName, fListener, pObj)
    if not self.m_listeners[sEventName] then
        return
    end
    local v
    for i=1, #self.m_listeners[sEventName] do
        v = self.m_listeners[sEventName][i]
        if v.func == fListener and pObj == v.obj then
            table.remove(self.m_listeners[sEventName], i)
            break
        end
    end
end

function EventManager:DispatchEvent(sEventName,...)
    if not self.m_listeners[sEventName] then
        return
    end
    local v
    local flag
    local msg
    local args = {...}
    local dispatcher = {}

    for i=1, #self.m_listeners[sEventName] do
        dispatcher[i] = self.m_listeners[sEventName][i]
    end

    for i=1, #dispatcher do --因为分发的事件可能修改self.m_listeners结构，所以把数据记录到一个缓存分发器，利用该分发器分发事件
        v = dispatcher[i]
        if not v.obj then
            local func = function() v.func(unpack(args, 1, table.maxn(args))) end
            flag, msg = xpcall(func, tolua.traceback)
        else
            local func = function() v.func(v.obj, unpack(args, 1, table.maxn(args))) end
            flag, msg = xpcall(func, tolua.traceback)
        end
        if not flag then
            --table.remove(self.m_listeners[sEventName],i)
           
        end

        if v.once then
            self:RemoveEvent(sEventName, v)
        end
    end
end

function EventManager:HasEvent(sEventName, func)
    if not self.m_listeners[sEventName] or not func then
        return false
    end
    local v
    for i=1, #self.m_listeners[sEventName] do
        v = self.m_listeners[sEventName][i]
        if v.func == func then
            return true
        end
    end
    return false
end

function EventManager:ClearEvent()
    self.m_listeners={}
end