---
name: redpoint-and-activityid-audit
description: 排查和预防「红点不消失 / 红点不亮 / 领完奖还能重复领」这类反复出现的问题。当出现红点相关 bug、活动多档位（成长礼金、时装、周月卡等）领奖异常、或需要新写/评审一段红点绑定代码时使用。关键词：红点、redPoint、redPointType、RedPointType、BindRedPointObject、ClearRedPointObject、CheckRedPointStatus、RefreshRedObjectStatus、领奖、重复领奖、activityId、ActivityId、IsActivityTypeOpen、GetActivityRewardRequest、page_3、OperatingPanel。
agent_created: true
---

# 红点 / 活动档位审计

这个项目的红点 bug 基本只有四种死法，全部来自三个管理器的**生命周期约定**被写错，
不是玄学。先跑脚本定位类别，再按类别改，别从 UI 层瞎猜。

## 一条命令定位

```bash
python3 .workbuddy-ai/skills/redpoint-and-activityid-audit/scripts/check_redpoint_binding.py
# 可选：--json 给机器读，--all 附明细，最后可跟一个 ~Lua 目录
# 退出码 1 = 有命中，可直接接 CI
```

输出分五类（A / A2 / B / C / D），每类在 `references/lifecycle.md` 里有判定依据。

## 判定表：这四种死法长什么样

| 类 | 症状 | 代码特征 | 修法 |
|---|---|---|---|
| **A** | 第一次打开红点正常，关掉再打开后**永远不亮/永远不灭** | `BindRedPointObject` 只在 `InitComponent`/`BindEvent`/`Awake`，`ClearRedPointObject` 在 `OnClose`/`OnHide` | 绑定挪到 `OnShow`，且**先 Clear 再 Bind** |
| **A2** | 页签切走再切回来，子页红点死了 | 宿主 `InitComponent` 只调一次子视图 `:InitComponent()`，但 `SwitchView`/`OnClose` 反复调 `:OnClose()` | 子视图自己把绑定挪到 `OnShow` |
| **B** | 领奖后状态没变、红点不消、还能再点；服务器日志 `CFG_NULL` | 列表按 `configInfo.ActivityId` 过滤，领奖却用 `IsActivityTypeOpen()` 的返回值当 activityId | 用**行自带的** `data.ActivityId`，`IsActivityTypeOpen` 只能当兜底 |
| **C** | 不报错，但 `BindObjs` 越来越长、刷新变慢 | 每次打开都 `Bind`，从不 `Clear` | 加 Clear，或先 Clear 再 Bind |
| **D** | 关掉 A 界面后，B 界面的同类型红点也不亮了 | `ClearRedPointObject(type)` **不传 obj** | 传具体 obj，只解绑自己的 |

## 为什么 A 类必现（背下来）

```
UIManager.OpenPanel
  ├─ 命中 openedList 缓存 → 只走 AddListener → OnOpen → OnShow
  └─ 未命中 → reimport + CreateUI: Awake → InitComponent → BindEvent

BasePanel.CloseUI   → RemoveListener → OnClose        ← 面板对象**还在缓存里**
BasePanel.DestroyUI → OnDestroy                        ← 只有这里才真销毁

RedpotManager.BindObject  → table.insert，**不幂等**
RedpotManager.ClearObject → 按 obj 从表里删；不传 obj = 整张表清空
```

所以「`BindEvent` 里绑 + `OnClose` 里清」= 第一次关闭清空后，下次打开既不重建也不补绑，
`BindObjs[type]` 变成空表 → 值再怎么变都刷不到 UI。**OperatingPanel page_3 就是这么坏的。**

## 日志怎么读（30 秒判断）

真机日志里 `[RedPoint] RefreshRedObjectStatus type=N state=X` 之后：

- 既**没有** `SetActive=` 也**没有** `No BindObjs` → `BindObjs[N]` 是空表 → **A 类**
- 有 `No BindObjs` → 从来没绑过（漏绑 / 绑在没走到的分支）
- 有 `SetActive=false` 但界面还亮 → 绑的是别的节点，或状态值被别处又改回 1
- 完全没有 `RefreshRedObjectStatus` → 检测函数没注册 / `RPData:CheckRedPoint` 认为值没变（`SetRedValue` 未生效）

## 修完必须做的三件事

1. **重编字节码**：真机跑 `LuaBytes/*_64.bytes`，只改 `~Lua/*.lua` 在真机上等于没改。
   ```bash
   scripts/lua-bytes-sync.sh <改过的 lua...>
   scripts/lua-bytes-sync.sh --check     # 确认全绿
   ```
2. **回归**：
   ```bash
   cd LuaEncoder/luajit_mac/64
   LUA_PATH="./?.lua;;" TS_ROOT=<repo> ./luajit ../..../scripts/lua-tests/test_xxx.lua
   ```
   `tests/lua-baseline.json` 里登记过的失败不算回归。
3. **复跑审计脚本**，确认这一类归零（D 类是已知存量，见 `references/known-issues.md`）。

## 写新代码时照这个抄

```lua
-- ✅ 面板里：绑在 OnShow，先 Clear 再 Bind（幂等）
function XxxPanel:OnShow()
    ClearRedPointObject(RedPointType.Xxx, self.redPointObj)
    BindRedPointObject(RedPointType.Xxx, self.redPointObj)
    CheckRedPointStatus(RedPointType.Xxx)
end

function XxxPanel:OnClose()
    ClearRedPointObject(RedPointType.Xxx, self.redPointObj)   -- 必须带 obj
end

-- ✅ 领奖：activityId 必须来自这一行配置，不能来自 IsActivityTypeOpen
local activityId = data.ActivityId or ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.Xxx)
local info = activityId and ActivityGiftManager.GetActivityInfo(activityId, data.Id) or nil
NetManager.GetActivityRewardRequest(data.Id, activityId, cb)
```

## 参考资料

- `references/lifecycle.md` — 三个管理器的完整生命周期、调用链、判定依据（改脚本前必读）
- `references/redpoint-api.md` — 红点 API 语义、`RPData` 父子关系、检测函数注册
- `references/case-operating-growth.md` — 案例：OperatingPanel page_3 领奖红点 + 重复领奖
- `references/case-arena-topmatch.md` — 案例：竞技场排行榜红点（A + A2 + D 三合一）
- `references/known-issues.md` — 当前审计结果与存量待评估清单
