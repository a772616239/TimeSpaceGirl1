require("Base/Stack")

BATTLE_POOL_TYPE = {
    MY_ROLE = 0,
    ENEMY_ROLE = 1,
    ENEMY_ROLE_2 = 2,
    BUFF_VIEW = 3,
    UNIT_VIEW = 4,
}

BattlePool = {}
local this = BattlePool

this.pool = {}
this.momItems = {}

function this.Init(poolRoot)
    this.root = poolRoot
end

function this.Register(type, item)
    if this.momItems[type] then

        return 
    end
    this.momItems[type] = item
end

-- 获取一个节点
function this.GetItem(parent, type)
    if not this.momItems[type] then

        return 
    end
    if not this.pool[type] then
        this.pool[type] = Stack.New()
    end
    -- 判断是否存在
    local item = this.pool[type]:Peek()
    if not item then
        item = newObject(this.momItems[type])
    else
        item = this.pool[type]:Pop()
    end
    --
    item.transform:SetParent(parent.transform)
    return item
end

-- 回收一个节点
function this.RecycleItem(item, type)
    if not this.momItems[type] then

        return 
    end
    if not this.pool[type] then
        this.pool[type] = Stack.New()
    end
    --
    item.transform:SetParent(this.root.transform)
    this.pool[type]:Push(item)
end

-- 清空对象池
function this.Clear()
    for _, st in pairs(this.pool) do
        st:Foreach(function(item)
            destroy(item)
        end)
    end
    this.pool = {}
end

-- 销毁对象池
function this.Destroy()
    this.Clear()
    this.momItems = {}
end


return BattlePool