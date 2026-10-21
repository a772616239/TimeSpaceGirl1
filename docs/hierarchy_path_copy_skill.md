# Hierarchy 复制节点路径 Skill（右键拿 `/` 路径）

> 更新时间：2026-10-21
> 一句话定位：**Hierarchy 里右键任意节点 → 「复制节点路径」→ 剪贴板拿到 `Canvas/Panel/Top/Btn` 这样的路径。**
>
> 代码：`Assets/Editor/HierarchyPathCopy.cs`（Editor-only，不参与打包，不影响运行时体积）
> 命名空间：`TSG.EditorTools.HierarchyPathCopy`

---

## 1. 怎么用

Hierarchy 里选中一个（或多个）GameObject，右键 → **复制节点路径** 子菜单：

| 菜单项 | 输出示例 | 用途 |
| --- | --- | --- |
| 完整路径（`Cmd/Ctrl + Alt + C`） | `Canvas/BattlePanel(Clone)/Top/BtnClose` | 通用，从场景根一路到自身 |
| 不含根节点 | `BattlePanel(Clone)/Top/BtnClose` | 拿到「场景根之下」的路径 |
| 带重名序号 | `Canvas/Panel/Top/Btn[1]/Icon` | 同级有同名节点时区分第几个（第一个不带 `[0]`） |
| 相对预制体根 | `Top/BtnClose` | **仅预制体实例可用**，可直接喂给 `transform.Find("Top/BtnClose")` |

- 多选：每个对象一行（`\n` 分隔），按选择顺序去重后输出。
- 无选中 / 该节点没有可用路径（如「相对预制体根」但选中对象不是预制体实例）时，菜单项置灰或打印 Warning。
- 每次复制都会在 Console 打一条 `[复制节点路径/xxx] ...`，多选时用 `  |  ` 连接，方便核对。

## 2. 实现要点（改之前先看）

- 路径拼法：从目标节点向上 `parent` 收集，`Reverse()` 后 `string.Join("/")`；根节点 = 场景根对象名（含 `(Clone)` 后缀，不做任何清洗）。
- 重名序号：`DuplicateIndex()` 数同级同名节点；**同级只有它一个时返回 0、不追加序号**，保证默认路径干净。
  场景根对象的重名判断走 `scene.GetRootGameObjects()`，其余走 `parent.GetChild(i)`。
- 相对预制体根：`PrefabUtility.GetOutermostPrefabInstanceRoot(go)` 取最外层实例根；嵌套预制体取的是最外层，
  路径不含该根的名字（因为 `transform.Find` 是相对根调用）。选中的正好是预制体根时返回它自己的名字。
- 校验函数注册路径**不带快捷键**（`MenuItem(MenuRoot + "完整路径", true)`）：Unity 会把 `%&c` 从菜单名里剥掉再匹配
  校验函数，两边写法不一致时菜单项会永远可点。

## 3. 坑位

- `GameObject/...` 的 MenuItem 在 Hierarchy 右键里是**扁平展开**的（不会出现一层叫 `GameObject` 的菜单），
  子菜单会以 `复制节点路径` 的名字出现；同一个 MenuItem **不会**出现在 Project 窗口右键（那走 `Assets/...` 路径）。
- 快捷键 `%&c` 是全局热键，注意别和项目里其它工具撞（撞了只影响谁先响应，不影响右键菜单本身）。
- 路径里的名字是 `GameObject.name`，**不是**变量名；重名的 `(Clone)` / `(1)` 后缀会原样带出来，
  想干净就用「带重名序号」或先改名字。
- 只对 GameObject 生效，不处理 Project 窗口里的 prefab 资源本身（那等价于 Unity 自带的 Copy Path）。
