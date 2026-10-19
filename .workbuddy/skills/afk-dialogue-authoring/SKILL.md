---
name: afk-dialogue-authoring
description: 给 TimeSpaceGirl1 的挂机面板（FightPointPassMainPanel/Bg/talk）加/改气泡台词——通用池、英雄专属、地图场景吐槽、大招前摇喊话都走这一套。当用户说"挂机气泡加几句话""让英雄说点骚话/牢骚""按地图/按技能加台词""大招前弹一句"时使用。内含 AfkSpeak/Language 双表追加、官方导表器、LuaBytes 重编、两行排版实测、Type 池编号约定与全部踩坑。
---

# 挂机气泡台词：从写词到真机生效

> 唯一消费点：`Assets/ManagedResources/~Lua/Modules/Fight/View/FightPointMapOnHook.lua`
> 数据：`data_execl/base_data/AfkSpeak.xlsx`（池）+ `Language.xlsx`（中/英/日）
> 评审页样例：`_output/afk_ult_talk.html`、`afk_map_talk.html`、`afk_speak_lore_v3.html`

## 一句话流程

写词 → 追加两张 xlsx（XML 层，不用 openpyxl 存盘）→ Unity 官方导表器导出 lua →
（改逻辑时）改 `FightPointMapOnHook.lua` → Lua 回归测试 → TextGenerator 量两行 →
`lua-bytes-sync.sh --check` → 评审页 → 分条 commit + push。

## 1. 先选池：AfkSpeak.Type 约定

| Type | 含义 | 命中逻辑 |
|---|---|---|
| `0` | 通用池（任何英雄、任何地图） | 跑图时按权重随机 |
| `英雄id`（10001…） | 英雄专属 | 该英雄说话时进候选 |
| `9900 + n` | 第 n 张地图的场景吐槽（Map2 → 9902） | `UpdateMap` 记下 `curMapType`，40% 命中 |
| `40000 + 英雄id` | 该英雄大招前摇台词 | `ShowUltTalk`，70% 专属 / 30% 通用 |
| `9998` | 通用大招台词 | 没配专属 / 30% 混播 |

新增池类型时：**先确认不撞号**（现有 `0` / `10001…` / `9901..9908` / `9998` / `4xxxx`），
再在 `FightPointMapOnHook.lua` 顶部把常量写清楚，并在文件头注释补一行。

## 2. 写词口径（决定好不好笑）

- **不要解释规则**。"Clubs can select camps to recruit heroes." 这种是最早被毙掉的版本。
- 美式/欧式幽默优先：短、干、反高潮、自嘲、抱怨；一句一个笑点，不要解释笑点。
- **贴角色，不贴职业**：海盗就算账，诗人就拖稿，运动员就犯规，护士就数三下。
- 大招台词必须能**在 0.5~2.2 秒的前摇里喊完**：临战喊话，不是旁白。
- 技能梗优先玩**技能名 / 技能描述**（例：`环球远征` → "World tour. You're stop one."；
  `同位素轰炸` → "Relax. Half-life beats you."）。
- 中/英/日三语都要**重写**，不要机翻腔；日文不要照抄中文（测试里会查 `Chinese == Japanese`）。

## 3. 排版硬约束（不过这一关必被裁）

气泡 Text：**280×78、字号 28、Wrap + Truncate** ⇒ 最多两行。

- 中文 ≤ 16 字；英文 ≤ 34 字符；日文 ≤ 20 字（保守值，最终以实测为准）。
- 英文最容易翻车：`Don't thank me. Thank the formation.` 就 3 行了 ⇒ 改 `Thank the ranks.`。
- **不要按字符数猜，必须用 Unity TextGenerator 量**：

```python
# .workbuddy/tools/unity_bridge.py code '<C#>'
var t = prefab.transform.Find("Bg/talk/text1/Text").GetComponent<UnityEngine.UI.Text>();
var h = t.cachedTextGeneratorForLayout.GetPreferredHeight(s,
        t.GetGenerationSettings(new Vector2(t.rectTransform.rect.width, 0))) / t.pixelsPerUnit;
# h <= 74.5 才是两行
```

批量量法见 `.workbuddy/tools/gen_afk_ult_review.py`：先把所有词写成 TSV，再一次性读入测。

## 4. 追加配置（关键：别让 openpyxl 存盘）

`openpyxl.save()` 会把 56 个「空字符串」格子写成空单元格、整包重压 ⇒ diff 变成整表重写。

**用 XML 层追加**，模板：`.workbuddy/tools/append_afk_ult_talk.py`

```bash
python .workbuddy/tools/append_afk_ult_talk.py --dry-run   # 先看行号/Id/sharedStrings
python .workbuddy/tools/append_afk_ult_talk.py             # 写入（自动备份 .bak-xxx）
python .workbuddy/tools/append_afk_ult_talk.py --revert    # 回滚
```

要点：

- `Language.xlsx`：追加 `<c B=id C/D/E=sharedStrings>`，同步 `uniqueCount` 与 `<dimension>`。
- `AfkSpeak.xlsx`：追加 `B=Id, C=Type, D=LanguageId`，`D` 是**语言 id**不是文本。
- 语言 id 段要连续且未被占用。当前已用：
  `63010089~63010108`（世界观重写）、`63010109~63010148`（地图）、`63010149~63010256`（大招）。
  下一段从 `63010257` 起，动手前先查一遍有没有空洞/占用。
- 追加后用 openpyxl **只读** 校验：旧行必须逐字节一致（`old == new[:len(old)]`）。

## 5. 导出 lua（唯一正确姿势）

**不要手改 packed lua**（`__indexs` / `__exValues` 是压缩结构）。走 Unity 侧官方导表器：

```python
# unity_bridge.py code
UnityEditor.AssetDatabase.Refresh();
var sheet = GameEditor.Core.DataConfig.DataHelper.GetSheet("data_execl/base_data/AfkSpeak.xlsx");
new GameEditor.Core.DataConfig.DataToOptimizeLuaExporter(sheet,
    new GameEditor.Core.DataConfig.DataConfigSetting()).Export();
```

`Language.xlsx` 同样导一次。只写 `~Lua/Config/Data`，不碰服务端 `conf/`。
导出后用 `GameDataBase.SheetBase.Init` 在 luajit 里读回行数与末行，确认没截断。

## 6. 改运行时逻辑（只在需要新池/新触发时）

`FightPointMapOnHook.lua` 里的既有钩子：

- `BuildTalkPool(rows, heroId, mapType, roll)`：通用 + 英雄 + 地图（40%）。
- `BuildUltPool(rows, heroId, roll)`：大招专属 70% / 通用 30%。
- `PickUltSlot(rules, unlocked, displays, combats)`：槽位最高且 `SkillType==2`。
- `ResolveLoadout(heroConfig)`：`OpenSkillRules → SkillLogicConfig(Level=1) → SkillDisplay → CombatControl → SkillConfig`。
- `PrecomputeOpenUlt(roll)`：每场开场 55% 抽 1 个我方单位，写 `ultReady`。
- `ShowTalk(pos, langId, duration)`：**唯一冒泡入口**，负责同位置定时器互斥、收起动画、`SetActive(false)`。
- `ShowUltTalk(pos)`：大招前摇喊话。

🔴 改这些时必须守住：

1. **同位置定时器先 `Stop()` 再 `New`**，否则后一个气泡会被前一个的 Timer 提前关掉。
2. 面板关闭走 `Dispose`，`ClearTalkTimers()` 要跟着调；节点判活只认 `IsNull()`（tolua fake-null）。
3. `OnDamaged` 读 `skill.Type`，解析不出 `SkillConfig` 就**整招放弃**，不能返回半成品。
4. 挂机是演出：大招不卡 `UnlockSkill` 突破门槛（槽位 3 要 Rank≥3，卡了就全退化成槽位 1），
   段数压到 3 段（原生 12 段会刷满屏飘字）。
5. 每场至多 1 个大招：敌方 `deadTimes=1`，我方一轮清场，本来就只有一个回合。

## 7. 回归测试（不依赖 Unity）

```bash
cd LuaEncoder/luajit_mac/64
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_afk_ult_talk.lua
TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_afk_map_talk.lua
```

新池照 `test_afk_ult_talk.lua` 抄：

- 纯函数断言（池选取、概率边界、槽位、段数）
- 配置完整性（条数、语言 id 不重复、三语齐全、英雄 id 存在）
- `ShowTalk` 用最小 UI 桩验定时器互斥 / 收起 / 清场

再跑一次真实配置回放（脚本模板 `.workbuddy/tmp/verify_real_ult.lua`）：
把 50 位 `AfkUse==1` 的英雄逐个 `ResolveLoadout`，必须全部有结果。

## 8. 真机生效：LuaBytes 必须重编

```bash
scripts/lua-bytes-sync.sh <改过的 .lua 或配置 .lua>
scripts/lua-bytes-sync.sh --check     # 必须全绿
```

配置 lua 也要编：`Config_Data_AfkSpeak_64.bytes`、`Config_Data_Language_64.bytes`。
只改源码不编字节码 = Editor 有效、真机无效（历史事故）。

## 9. 评审页 + 提交

```bash
python .workbuddy/tools/gen_afk_ult_review.py
```

页面结构：流程四步 → 台词总表（英雄 / 大招 / 英 / 中 / 日）→ 通用池 → 回归检查。

提交（两个仓库都要管，但本功能只动客户端）：

- 配置：`文案(挂机气泡): …`
- 运行时：`功能(挂机气泡): …`
- 测试：`test(挂机气泡): …`
- 严禁 `git add -A`；Lua 源码 + LuaBytes 成对提交；push 后确认 `ahead = 0`。

## 10. 常见坑速查

| 现象 | 原因 | 处理 |
|---|---|---|
| 气泡空白不消失 | 先 `SetActive(true)` 再发现池为空 | 空池直接 return，让 `ShowTalk` 统一开关 |
| 新图不说话 | 场景池为空/地图名不是 `MapN` | `BuildTalkPool` 已回退通用池；`MapTalkTypeFromName` 返回 nil |
| 某英雄大招没台词 | 没配 `40000+id`，或 id 拼错 | 走 `9998` 通用池；测试会校验英雄 id |
| 台词被截断 | 超过两行（280×78） | TextGenerator 实测，英文压到 ≤34 字符 |
| 真机没变化 | 忘了重编 LuaBytes | `lua-bytes-sync.sh --check` |
| 老台词被整表重写 | 用了 openpyxl 存盘 | 回滚备份，改走 XML 追加脚本 |
