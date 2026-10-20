# 红点 API 语义

## 全局包装（`Common/functions.lua`）

| 函数 | 行 | 语义 |
|---|---|---|
| `BindRedPointObject(rpType, rpObj)` | L1567 | 把 `rpObj` 挂到 `rpType` 上，**立即**按当前值 `SetActive` |
| `ClearRedPointObject(rpType, rpObj)` | L1572 | 传 obj = 只解绑这一个；**不传 obj = 清空该类型所有绑定** |
| `CheckRedPointStatus(rpType)` | L1587 | 重算该类型并刷新所有绑定物体（值没变则跳过） |
| `ChangeRedPointStatus(rpType, state)` | L1577 | 强制改值（注释写着「不建议使用」） |
| `ResetServerRedPointStatus(rpType)` | L1582 | 服务器红点置隐藏 |

## RedpotManager（`Modules/Player/RedpotManager.lua`）

```lua
-- L670 绑定
function this.BindObject(rpType, rpObj)
    BindObjs[rpType] = BindObjs[rpType] or {}
    table.insert(BindObjs[rpType], rpObj)          -- ★ 不幂等，重复绑就重复插
    if rpObj ~= nil then
        rpObj:SetActive(this.GetRedPointStatus(rpType) == RedPointStatus.Show)
    end
end

-- L686 解绑
function this.ClearObject(rpType, rpObj)
    if rpObj then
        -- 在 BindObjs[rpType] 里找到同一个 obj 并 table.remove
    else
        BindObjs[rpType] = {}                      -- ★ 不传 obj 就是清空全部
    end
end
```

**结论：任何「可能被执行多次」的绑定点，都必须先 `ClearRedPointObject(type, obj)` 再
`BindRedPointObject(type, obj)`**，否则：

- `BindObjs[type]` 里堆 N 份同一个物体；
- 每次刷新对它 `SetActive` N 遍（性能 + 视觉闪）；
- 而且无法靠 `ClearRedPointObject(type, obj)` 一次清干净（只删第一份）。

`RefreshRedObjectStatus`（L784）还负责向上递归父节点，所以父节点的显示依赖子节点的
`SetRedValue` 生效——这也是为什么「子节点空表」时父节点也跟着不更新。

## RedPointData（`Modules/Player/RedPointData.lua`）

| 函数 | 行 | 说明 |
|---|---|---|
| `SetParent(child, parent)` | L~55 | 一个子节点只能有一个父节点（L61 重复设置直接 return） |
| `SetRedValue(node, value)` | L84 | **有子节点的节点不能直接设值**（L85-88 return false），只有叶子能设 |
| `AddCheckFunc(node, func, openType)` | L100 | 注册检测函数；已有子节点或已注册过都直接 return（不覆盖） |
| `CheckRedPoint(node)` | L126 | 值没变返回 false（L155-158），此时**不会**刷新 UI |

两个坑：

1. `SetRedValue` 对「有子节点的节点」返回 false ⇒ 想让父节点亮，只能让子节点亮，
   别直接 `ChangeRedPointStatus` 父节点。
2. `CheckRedPoint` 值没变就跳过刷新 ⇒ 如果你在**绑定之前**已经把值算好了，
   绑上之后 `CheckRedPointStatus` 会认为「值没变」而不刷新。
   但 `BindObject` 在绑的瞬间会自己 `SetActive` 一次，所以不会漏——除非绑的时机在
   值变化之后又发生了别的事情把显示改回去了。

## 检测函数常见写法（`OperatingManager.GetGrowthRedPointState` 为反面教材）

```lua
RPData:AddCheckFunc(RedPointType.GrowthGift, OperatingManager.GetGrowthRedPointState)
```

检测函数必须满足：

- **纯查询**，不能有副作用（不能在里面 `SetRedValue` / 发协议 / 改状态）；
- 覆盖页面**所有**能领的档位。`GetGrowthRedPointState` 只遍历
  `ActivityId == IsActivityTypeOpen(GrowthReward)`（`Modules/Operating/OperatingManager.lua` L250-271），
  也就是只覆盖「最后开启的那一档」。页面本身能翻到 101~105 五档并从中领奖
  （`GrowthGiftPage:RefreshShowData` 用的是行自带的 `data.ActivityId`），
  所以更早的档位有奖可领时红点不会亮。这是**已知缺口**，改动前先确认运营是否
  真的会同时开多档（见 `known-issues.md`）。
