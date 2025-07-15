
-- 对象池物体的父类
local PoolItemBase = {}

-- 构造函数
function PoolItemBase:ctor(type, object)
    self.type = type
    self.gameObject = object
    self.transform = object.transform

    -- 回调子类
    if self.OnCreate then
        self:OnCreate()
    end
end

-- 设置节点父节点
function PoolItemBase:SetParent(parent)
    if self.transform then
        self.transform:SetParent(parent.transform)
        self.parent = parent.transform
    end
end

-- 设置节点位置
function PoolItemBase:SetPosition(v3)
    if not v3 then return end
    if self.transform then
        self.transform.localPosition = v3
    end
end

-- 设置节点缩放值
function PoolItemBase:SetScale(v3)
    if not v3 then return end
    if self.transform then
        self.transform.localScale = v3
    end
end

-- 使用节点
function PoolItemBase:Use(parent)
    -- 处于回收状态不可使用
    if self.recycleIndex then return end
    self:SetParent(parent)
    -- 回调子类
    if self.OnUse then
        self:OnUse()
    end
end

-- 回收节点
function PoolItemBase:Recycle()
    -- 如果数据没有回收，先从管理回收数据
    if not self.recycleIndex then
        CommonPool.RecycleNode(self)
        return
    end
    self:SetParent(poolManager.mPoolTrans)
    -- 回调子类
    if self.OnRecycle then
        self:OnRecycle()
    end
end

-- 销毁节点
function PoolItemBase:Destroy()
    -- 需要先从对象池中回收，才能销毁
    if not self.recycleIndex then
        CommonPool.RemoveNode(self)
        return
    end
    -- 回调子类
    if self.OnDestroy then
        self:OnDestroy()
    end
    -- 销毁节点
    GameObject.DestroyImmediate(self.gameObject)
end


return PoolItemBase