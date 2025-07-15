---
--- 对象池使用方法
---     1、注册对象枚举  POOL_ITEM_TYPE
---     2、创建对象预制体，创建对象类并继承PoolItemBase类，参照 PlayerHead
---     3、将创建好的类和预制体与枚举对象绑定，在_ItemInfo中
---     4、创建对象，并及时回收
---         使用对象池系统的 CreateNode 方法进行物体创建
---         在物体不再被使用时，使用 RecycleNode 方法进行物体回收
---
---     PoolItemBase 基类
---         1、要求所有使用此对象池的物体都继承此基类，继承此基类的对象，将提供以下通用方法：
---             SetPosition     设置位置
---             SetScale        设置大小
---             SetParent       设置父物体
---             Recycle         回收对象
---             Destroy         销毁对象
---
---         2、在继承此基类的子类中，提供四个生命周期函数，可以在必要时进行重写，按调用顺序依次为：
---             OnCreate    物体创建回调（在生命周期中 只会调用一次）
---             OnUse       物体被使用时回调（在生命周期中会在 使用时 多次调用）
---             OnRecycle   物体被回收时回调（在生命周期中会在 使用时 多次调用）
---             OnDestroy   物体被销毁时回调（在生命周期中 只会调用一次）
---
---
CommonPool = {}
local this = CommonPool

POOL_ITEM_TYPE = {
    PLAYER_HEAD = 1,
}

local _ItemInfo = {
    [POOL_ITEM_TYPE.PLAYER_HEAD] = {class = require("Modules/Common/Pool/Item/PlayerHead"), assert = "PlayerHead"}
}

local _ItemPool = {}


function this.Initialize()
    -- 创建母体对象
    for type, info in pairs(_ItemInfo) do
        info.momNode = GameObject.Instantiate(resMgr:LoadAsset(info.assert))
        info.momNode.transform:SetParent(poolManager.mPoolTrans)
    end
end

-- 创建一个对象
function this.CreateNode(itemType, parent)
    if not itemType or not parent then

        return
    end
    local itemInfo = _ItemInfo[itemType]
    if not itemInfo then

        return
    end
    -- 获取item
    local item = nil
    -- 判断对象池中是否存在
    if _ItemPool[itemType] and #_ItemPool[itemType] > 0 then
        local len = #_ItemPool[itemType]
        item = _ItemPool[itemType][len]
        _ItemPool[itemType][len] = nil
    else
        -- 不存在则创建新的
        item = itemInfo.class.new(itemType, newObject(itemInfo.momNode))
    end
    -- 切换物体为使用状态
    if item then
        item.recycleIndex = nil
        item:Use(parent)
        item.transform.localPosition = Vector3.zero
        item.transform.localScale = Vector3.one
    end
    return item
end

-- 回收一个对象
function this.RecycleNode(item)
    if not item then return end
    if not _ItemPool[item.type] then
        _ItemPool[item.type] = {}
    end
    table.insert(_ItemPool[item.type], item)
    -- 设置回收序号
    item.recycleIndex = #_ItemPool[item.type]
    item:Recycle()
end

-- 删除一个对象
function this.RemoveNode(item)
    if not item then return end
    if not item.recycleIndex then
        this.RecycleNode(item)
    end
    -- 移除数据
    table.remove(_ItemPool[item.type], item.recycleIndex)
    -- 销毁
    item:Destroy()

end


return  this