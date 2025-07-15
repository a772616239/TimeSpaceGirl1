-- 管理器的对象池
local _ControllerPool = {}

-- 管理器类
local NodeController = {}

--- 获取管理器中的某类型的管理器
function NodeController.Find(type)
    --- 如果有则返回
    if _ControllerPool[type] then
        _ControllerPool[type]:RecycleAllNode()
        return _ControllerPool[type]
    end
end

--- 创建一个新的管理器
function NodeController.New(type)
    --- 判断是否有, 有了销毁
    if _ControllerPool[type] then
        _ControllerPool[type]:Destroy()
        _ControllerPool[type] = nil
    end
    --- 创建新的管理器
    local o = {}
    NodeController.__index = NodeController
    setmetatable(o, NodeController)
    -- 默认限制个数100
    o._LimitNum = 100
    o._NodeList = {}
    o._UnUsedPool = {}
    o._UsedPool = {}
    _ControllerPool[type] = o
    return o
end

-- 设置限制创建的个数
function NodeController:SetLimitNum(num)
    self._LimitNum = num
end

-- 设置节点，返回节点id
function NodeController:AddNode(node, adapter)
    -- copy这个节点并保存到对象池
    local copyNode = newObjToParent(node, poolManager.mPoolTrans)
    local data = {
        node = copyNode,
        adapter = adapter
    }
    table.insert(self._NodeList, data)
    return #self._NodeList
end

-- 创建节点
function NodeController:CreateNode(parent, data)
    -- 找到符合条件的节点
    for id, ndata in ipairs(self._NodeList) do
        if ndata.adapter then
            if ndata.adapter(data) then
                return self:GetNode(parent, id)
            end
        else
            return self:GetNode(parent, id)
        end
        assert(GetLanguageStrById(10418))
    end
end

-- 获取节点
function NodeController:GetNode(parent, id)
    -- 判断是否有了
    if self._UnUsedPool[id] and #self._UnUsedPool[id] > 0 then
        local node = table.remove(self._UnUsedPool[id], 1)
        if not self._UsedPool[id] then
            self._UsedPool[id] = {}
        end
        table.insert(self._UsedPool[id], node)
        node.transform:SetParent(parent.transform)
        node.transform.localScale = Vector3(1, 1, 1)
        node.transform.localPosition = Vector3(0, 0, 0)
        node.gameObject:SetActive(true)
        return node
    end

    -- 判断是否超出限制
    if self._UsedPool[id] and #self._UsedPool[id] >= self._LimitNum then
        -- 获取第一个
        local node = table.remove(self._UsedPool[id], 1)
        if not self._UsedPool[id] then
            self._UsedPool[id] = {}
        end
        table.insert(self._UsedPool[id], node)
        node.transform:SetParent(poolManager.mPoolTrans)
        node.transform:SetParent(parent.transform)
        node.transform.localScale = Vector3(1, 1, 1)
        node.transform.localPosition = Vector3(0, 0, 0)
        node.gameObject:SetActive(true)
        return node
    end

    -- 创建新的
    local node = newObject(self._NodeList[id].node)
    if not self._UsedPool[id] then
        self._UsedPool[id] = {}
    end
    table.insert(self._UsedPool[id], node)
    node.transform:SetParent(parent.transform)
    node.transform.localScale = Vector3(1, 1, 1)
    node.transform.localPosition = Vector3(0, 0, 0)
    node.gameObject:SetActive(true)
    return node
end

-- 回收所有节点
function NodeController:RecycleAllNode()
    for id, list in pairs(self._UsedPool) do
        for _, node in ipairs(list) do
            node.transform:SetParent(poolManager.mPoolTrans)
            node.gameObject:SetActive(false)

            if not self._UnUsedPool[id] then
                self._UnUsedPool[id] = {}
            end
            table.insert(self._UnUsedPool[id], node)
        end
    end
    self._UsedPool = {}
end

-- 销毁管理器
function NodeController:Destroy()
    -- 删除使用中的
    for _, list in pairs(self._UsedPool) do
        for _, node in ipairs(list) do
            GameObject.DestroyImmediate(node)
        end
    end
    self._UsedPool = {}
    -- 删除未使用的
    for _, list in pairs(self._UnUsedPool) do
        for _, node in ipairs(list) do
            GameObject.DestroyImmediate(node)
        end
    end
    self._UnUsedPool = {}
    -- 删除母体
    for _, nodeData in pairs(self._NodeList) do
        GameObject.DestroyImmediate(nodeData.node)
    end
    self._NodeList = {}
end

return NodeController