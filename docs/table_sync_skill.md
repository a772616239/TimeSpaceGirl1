# 导表服务端同步 skill（table_sync）

> 适用范围：`data_execl/base_data/*.xlsx` 改完之后，要让**测试服和线上服读到的配置**都和客户端 lua 对齐。
> 更新时间：2026-10-23
> 关联文档：`导表实跑与三处断点-20261020.md`（导出链路本身的三处断点）、
> `测试服导表部署与角标核查-20261021.md`（nil→null 那次事故）、
> `线上配置表语义diff-20261022.md`（37 张差异表的审计底稿）、`client_build_chain.md`
> 实现：`scripts/table_sync.py`（`--env` 按打包环境选目标）｜接入点：`scripts/resource_build.sh --sync-tables`、
> `TS-Android-Release` 的 `③-1 服务端表同步`（`SYNC_TABLES` / `SYNC_RESTART`）

---

## 0. 一句话

**导表只写本地影子目录，两套服务端那份从来没被推过** —— 客户端 lua 与服务端 txt 同源同一次导出，
但 `DataConfigSetting.serverOutputDir` 指向 `TimeSpaceServer/skzc/.../conf/server`（git 里的影子目录），
而服务端真正读的是另外两处。三条链之间没有任何自动衔接，
于是出现「客户端显示 0、服务端还能领」这类口径差，以及历史上反复的 `NoSuchMethodError`。

`table_sync.py` 补的就是这一段：**导表成功后，把「本次真正改动」的表增量推到两套服务端**。

### 两个目标，缺一不可

| 目标 | 位置 | 谁在用 |
|---|---|---|
| `local` 本机测试服 | `~/home/java/gameserver/{conf,assets/conf}/server` | Unity 编辑器、测试包（局域网 192.168.3.x:8081 + 游戏服 16081） |
| `gs` 线上服 | `gs:/home/java/gameserver/{conf,assets/conf}/server` | 现网 129.226.213.65 |

只推一边等于没改：测试服旧表 → 自测过的东西上线不成立；线上旧表 → 客户端显示与服务端校验继续对不上。
而且两套现在**本来就不是一个版本**（2026-10-22 实测有 3 张表判定不同，见第 6 节）。

---

## 1. 🔴 为什么不能整目录 rsync（先读这段，别再试）

2026-10-22 全量语义审计（406 张 txt）的结论，三种事故都是整目录覆盖直接造成的：

| 表 | 线上/测试服 | 仓库 | 整表覆盖的后果 |
|---|---|---|---|
| `Language.txt` | 5 列（含 `Korean`） | 4 列 | 韩语列整个消失，韩语全空 |
| `EncourageTaskConfig.txt` | 296 行 | 270 行 | **删掉线上 16001~16025 共 25 条任务** |
| `MultiLanguage.txt` | 有 id 10301 | 没有 | 同上，删线上行 |
| 30+ 张内容表 | 装机版本 | 2026 开发版 | 随机奖励 / 觉醒属性 / 新道具段**直接开给线上玩家** |

所以工具的设计前提是：**只推增量，且每张表先过结构体检，体检红灯一律不推。**

---

## 2. 怎么用

```bash
# ① 体检（默认，只读两个目标，不改任何东西）
python3 scripts/table_sync.py

# ② 推「本次导表改动」且通过体检的表（默认 local + gs 都推）
python3 scripts/table_sync.py --apply

# ③ 只推某一边
python3 scripts/table_sync.py --apply --targets local   # 只推本机测试服
python3 scripts/table_sync.py --apply --targets gs      # 只推线上服

# ③' 按「打包环境」推（Jenkins 用的就是这条：目标来自 scripts/build_envs.json 的 tableTargets）
python3 scripts/table_sync.py --env 现网-129.226.213.65 --apply --yes   # → gs
python3 scripts/table_sync.py --env 测试服                              # → local，只体检
python3 scripts/table_sync.py --env 正式服                              # → []，直接跳过 rc=0

# ④ 只推指定几张（表名可省 .txt）
python3 scripts/table_sync.py --apply --only StoreConfig,VipLevelConfig

# ⑤ 点名强推（体检红灯也推，慎用）
python3 scripts/table_sync.py --apply --only Language --force

# ⑥ 把历史漂移全推（含未发布内容，非交互必须 --yes）
python3 scripts/table_sync.py --apply --include-drift --yes

# ⑦ 推完重启（本机 launchctl 立即生效；线上会踢线，非交互需 --yes）
python3 scripts/table_sync.py --apply --restart

# ⑧ 数值列脏数据：先看会改什么（只报告），确认后落盘（见 5.2）
python3 scripts/table_sync.py --fix-numeric
python3 scripts/table_sync.py --fix-numeric --apply-fix
```

**导表时自动跑**（推荐入口，Jenkins / 本机通用）：

```bash
scripts/resource_build.sh --action export                     # 导表 + 自动同步（默认 apply）
scripts/resource_build.sh --action export --sync-tables plan  # 导表 + 只体检
scripts/resource_build.sh --action export --sync-tables off   # 导表但不碰服务端
scripts/resource_build.sh --action export --sync-strict       # 同步失败算构建失败
```

同步失败默认**不拖垮导表**（产物已在本地，服务端只是「还是旧的」），明细写
`build/table_sync/reports/sync_<时间戳>.md`。

退出码：`0` 正常｜`2` 参数/环境错｜`3` 传输或校验失败｜`4` 有被拦下的表（仅 `--strict`）｜`5` 缺 `--yes`

> 判定是按「表 × 目标」算的：同一张表可能线上能推、测试服不能推（或反过来）。
> 基线只在**所有选中目标都到位**之后才前移，所以某一边失败不会让下次漏推。

### 2.1 🔴 它到底跑在哪个目录（Jenkins 链路实情）

两条入口，**都在独立打包 clone 里跑**，都不在开发目录：

| 入口 | 触发 | 目标怎么定 |
|---|---|---|
| `TS-Resource-Build` 的导表环节 | `scripts/resource_build.sh --action export` → Unity 导表 → **同一脚本紧接着** `table_sync.py`（默认 `--sync-tables apply`） | 默认 `local,gs` 都推 |
| `TS-Android-Release` 的 `③-1 服务端表同步`（2026-10-23 新增） | 参数 `SYNC_TABLES=apply/check/off`（默认 apply）+ `SYNC_RESTART`（默认关） | `table_sync.py --env "$SERVER_ENV"`，映射见 `scripts/build_envs.json` 的 `tableTargets`：现网→`gs`、测试服→`local`、正式服→`[]`（跳过） |

> 🔴 为什么单独加 ③-1、而不是指望导表环节：**发线上包默认 `EXPORT_TABLES=false`**
> （`--action ab` 只重建 AB），导表环节根本不跑 ⇒ 同步也不跑。2026-10-22 之前的线上包
> 全是这么出去的：客户端 lua 是新的、服务端 txt 还是旧的。

| 项 | 值 |
|---|---|
| 打包目录 | `/Users/wangxufeng/Documents/TimeSpaceGirl1-build`（job 里的 `PROJ`） |
| 代码从哪来 | `.jenkins/ci_sync.sh`：`fetch` → `stash` → `reset --hard origin/release` |
| **服务端表从哪来** | **同一脚本第③步 `rsync -a --inplace "$DEV_PROJ/TimeSpaceServer/" "$CI/TimeSpaceServer/"`** |
| **基线从哪来** | **同一脚本第④步 `rsync -a --update` 开发目录的 `build/table_sync/state.json`**（2026-10-23 新增） |

由此得出四条必须知道的结论：

1. **`TimeSpaceServer/` 的真源是开发目录，不是 git。** `ci_sync.sh` 每跑一次就把开发目录的
   `TimeSpaceServer/` 整个 rsync 过去（因为它是独立仓，主仓拉不到）。所以「开发机手工推」
   和「Jenkins 推」用的是**同一份 txt**，不会各推一套。
2. **打包 clone 落后时，job 推不出任何表。** 2026-10-23 实测：clone 停在 `a93b955d9`
   （落后 `origin/release` 27 个提交），里面**连 `scripts/table_sync.py` 都没有**，
   `resource_build.sh` 也还没有 `--sync-tables`。这种状态下跑 job 只会导表、不同步。
   ⇒ 改了同步逻辑后，必须先让 `ci_sync.sh` 跑过（job 第①-1 步会做），或手工在打包目录
   `git fetch && git reset --hard origin/release`。
3. **基线必须跟着镜像过去，否则 clone 永远是「首次运行」。** `build/table_sync/state.json`
   是 gitignore 的，clone 里没有；`table_sync` 首次运行只建基线、**一张都不推**
   ⇒ 「job 跑了但表没动」。所以 `ci_sync.sh` 第④步把开发目录的基线 rsync 过去
   （`--update`：只前移不回退，CI 自己推过的那次更可信）。基线只是账本，和 txt 一样以开发目录为真源。
4. **两个 clone 的基线互不相通，但共享同一份语义。** 开发机推过 23 张后，clone 拿到这份基线，
   看到的是「已经同步过」，不会重复推；之后开发机再改表、提交、打包，clone 才会看到差异。
   `SAME` 的表本来也不推，所以重复执行是幂等的。

> ⚠️ 一个反直觉的后果：CI 导表用的是**打包 clone 里的 xlsx（git 版本）**，
> 而 `TimeSpaceServer/` 是 rsync 来的开发目录版本。如果开发目录的 xlsx 有**未提交**改动，
> rsync 过去的新 txt 会被 CI 的旧 xlsx 重新导一遍覆盖掉，然后被当成「改动」推回服务端
> —— 等于把线上**回滚**成 git 版本。所以：**要发版的表改动，xlsx 和 txt 必须一起提交**。

> ⚠️ 一个反直觉的后果：CI 导表用的是**打包 clone 里的 xlsx（git 版本）**，
> 而 `TimeSpaceServer/` 是 rsync 来的开发目录版本。如果开发目录的 xlsx 有**未提交**改动，
> rsync 过去的新 txt 会被 CI 的旧 xlsx 重新导一遍覆盖掉，然后被当成「改动」推回服务端
> —— 等于把线上**回滚**成 git 版本。所以：**要发版的表改动，xlsx 和 txt 必须一起提交**。

---

## 3. 「本次改动」是怎么算出来的（基线机制）

基线文件 `build/table_sync/state.json`（v3：全局一份 `sig` + **每个目标各一份 `sig`** + `last_sync_at`），
每张表记一个**语义指纹**：

```
指纹 = md5( 表头 + 按主键排序后的每一行（单元格归一化） )
```

> v3 为什么要按目标分开记：v2 只有全局一份，`--targets local` 推完之后全局 `sig` 就前移了，
> 于是线上服（gs）永远认为这批表「没变过」→ 永久漏推。现在全局 `sig` 只在
> **所有已知目标都到位**时才前移；某个目标第一次接触时，以它**当前内容**建基线
> （所以历史漂移不会因为「第一次跑」被当成「本次改动」自动推上去，要推得显式 `--include-drift`）。

归一化吃掉的东西（**这些都不算改动**，否则一次导表 266 张表全变）：

- 行尾 TAB / 尾随空单元格（导出器 2026-10-20 才修掉，历史产物里全是）
- `nil` ↔ `null` ↔ 空串（空值字面量）
- `0.0` ↔ `0`、`1.00` ↔ `1`
- **行序**（`MonsterConfig` 线上/仓库行序不同，按行比会误判 45035 行全变）
- 零值填充行（`Id=0` 且全 0 的行，线上 `EquipTalismana` 多 75 行、`RandomName` 多 14 行都是这类）

候选表 = 指纹 ≠ 基线的表。**没有基线时**（第一次跑）用 `git status` 的工作区差异当基线；
`git` 也拿不到就只建基线、**一张都不推**。

> 所以第一次跑是安全的：它只记录现状。第二次起才「改几张推几张」。

---

## 4. 判定规则（体检）

| 判定 | 含义 | 会不会推 |
|---|---|---|
| `SAME` | 归一化后逐格一致 | 不推（不需要） |
| `VALUE_DIFF` | 同主键、部分单元格值不同 | ✅ 推 |
| `ROW_ADD` | 本地新增主键 | ✅ 推 |
| `NEW` | 目标没有这张表 | ✅ 推 |
| `COL_GAIN` | 本地多列 | ⚠ 推（服务端按字段名反射注入，需确认 `S*Config` 有该字段） |
| `COL_LOSS` | 本地列数少于目标 | 🔴 拦（覆盖会丢列，`Language` 就死在这） |
| `ROW_LOSS` | 目标有主键、本地没有 | 🔴 拦（覆盖会删目标数据） |
| `HEADER_DIFF` | 表头字段名/顺序不一致 | 🔴 拦（覆盖会串列） |
| `REMOTE_ONLY` | 目标有、本地导出没有 | 🔴 永不删（可能纯后端表/已下线表） |
| `REVIEW` | 人工复核名单 | 🔴 拦（`Language` / `MultiLanguage` / `Encourage*` / `RewardItemConfig`） |
| `PARSE_FAIL` | 某行列数超过表头（串列风险） | 🔴 拦 |
| `NIL_CELLS` | **数值列里是 `nil`** | 🔴 拦（见 5.1） |
| `PARSE_BAD` | **int 列写了小数 / 超 int32 / 非数字** | 🔴 拦（见 5.2，2026-10-22 实测炸过） |

---

## 5. 🔴 坑位

### 5.1 `nil` 会让游戏服起不来（最容易踩）

服务端 `gamecommon/util/StringUtil.java:20-56` 的 `parseFiledInt/2/3`：

```java
if ("null".equals(value) || isEmpty(value) || " ".equals(value)) return new int[0];
... Integer.parseInt(param[i])      // "nil" 走到这里 → NumberFormatException
```

`DataHelper.GetValByDefault` 在 2026-10-21 之前写的是 `"nil"`，之后才改成 `"null"`。
**所以 2026-10-21 之前导出的影子目录里，数值列全是 `nil`**（实测 54 张表命中，
`StoreConfig` 一张就有 5009 个），这种文件推上去 = 服务端启动时整表加载中断。

两条出路：

1. **重跑一次导表**（`scripts/resource_build.sh --action export`），新产物写 `null`；
2. 不想开 Unity 的话加 `--fix-nil`：工具只把**数值列**里的 `nil` 就地改写成 `null`
   （逐单元格验证过：5009 个单元格，零其他改动，行尾风格不变），等价于重跑导表。
   ⚠️ 它会改 git 工作区里的 txt，记得和导表产物一起提交。

### 5.2 🔴 int 列里的脏数据会打断整张表的加载（2026-10-22 实测）

服务端 `STableManager.dealParams` 对 `int` 列直接 `Integer.parseInt`，**没有任何容错**，
而且 `catch (Exception e) { LOGGER.error(...); throw e; }` —— 抛了还会往外扔，
把整张表的加载打断。

2026-10-22 23:24 把 24 张表推到测试服后重启，实际炸了 3 张：

| 表 | 单元格 | 值 | 问题 |
|---|---|---|---|
| `SupremacyLevelConfig` | `Hit` id=658…（1896 处） | `740.000000000001` | Excel 浮点误差，列是 `int` |
| `ChallengeConfig` | `MapTime` id=100/4001/4002/4003 | `9999999999` | 超 int32（2147483647） |
| `RunesPoolConfig` | `Max` id=270055/280056/310055/320056 | `1.25` / `3.75` / `2.5` | 整数列写小数 |

日志里就三行 `NumberFormatException`，其余全绿 —— 很容易漏。已回滚这 3 张表，
并给工具加了 `PARSE_BAD` 拦截：按类型行判 `int`/`ref*`/`mut,int#…`/`long`/`float`/`double`，
逐单元格验（`mut` 按 `|#,;` 拆子值），越界或类型不符一律拦下。

**根因在 xlsx，但不在「有人写错了数」**：xlsx 里这些格子存的是**文本**，内容是 Excel 算出来的
浮点噪声（`'740.0000000000006'`、`'499.99999999999994'`），导表只是原样搬运。所以三件事都做了：

1. **导出器归一化**（根治）：`DataHelper.GetServerValByType` + `DataToTxtExporter` 改用新方法，
   按 `fieldType` 判 `int`/`ref`/`mut,int#…`，写盘前做「Java `(int)` 截断 + int32 夹取」。
   `mut,float#…` / `float` / `double` / `long` / `string` 原样不动。
   口径不是拍脑袋：发包树 `TimeSpaceServer/Server_x1tag1.2.2/server_game` 里这三处现存值
   正好是 `740` / `2147483647` / `1`，说明历史链路就是这么归一的，现在只是把丢掉的这步补回来。
   单测用真实类型串跑过（`mcs` 编译 `DataHelper.cs` + `DataField.cs`，14 组输入全对）。
2. **工具兜底**：`--fix-numeric` 对**已经导出的** txt 做同样的归一化（`--apply-fix` 才落盘），
   2026-10-22 实测命中 3 张表 1904 个单元格，改完 `ChallengeConfig` / `RunesPoolConfig`
   直接变 `SAME`（证明测试服上那三个值本来就是同一套归一化的产物）。
3. **拦截**：`PARSE_BAD` 让这类表永远不会被推上去。

> 注意 `1.25 → 1` 是**有损**的（向零截断）。设计上要小数就得把服务端列类型改成 `float`/`long`，
> 而不是往 int 列里塞小数 —— 服务端 int 列本来也存不下。
> 另外导出器改的是 **txt（服务端）**；客户端 Lua 仍拿原始单元格，`499.99999999999994` 在 Lua 里
> 就是个数，不会报错，只是难看。

### 5.3 推完不重启等于没推（两边重启姿势不同）

`STableManager` 只在启动时 `initMap`。推完表不重启，服务端还是旧数值。

```bash
# 本机测试服：launchd 立即重启（秒级，不踢人）
launchctl kickstart -k gui/$(id -u)/com.ts.localserver.gameserver

# 线上服：会踢线，必须确认后再做
ssh gs "bash /home/java/gameserver/RESTART-GAMESERVER.sh"
```

`--restart` 两个目标都重启；线上那条在非交互环境需要 `--yes`，否则只提示不执行。

### 5.4 两个目录都要写

`conf/server`（运行时读）和 `assets/conf/server`（资源目录）**不是软链**，
2026-10-21 实测是两份独立文件（407 / 408 个）。只写一份 = 下次打包/热更又变回旧值。
工具默认两份都推、两份都校验。

### 5.5 ssh 每次握手 2~3 秒，别逐目录调

`md5sum` 清单用一次 ssh 拿两个目录（`Target.md5s`），逐目录调会把 20 秒的活干成 1 分钟。

### 5.6 远端快照缓存的键必须带 base

用 `--gs-base` 指向测试目录跑一次，如果缓存键只用目录名（`snap_conf_server`），
会把生产快照缓存覆盖成测试内容，下次比对直接 `EOFError: Compressed file ended...`。
已改成 `snap_<base 的 md5 前 8 位>_<dir>`。

### 5.7 `--include-drift` 是给审计用的，不是日常同步

它会把所有漂移表全纳入候选（含未发布内容）。日常同步永远用默认的基线增量。

### 5.8 两套服务端本来就不是一个版本，别假设「推一边就够」

2026-10-22 实测：同一批表，`local` 漂移 30 张、`gs` 漂移 31 张，**有 3 张判定不同**：

| 表 | 本机测试服 | 线上服 | 说明 |
|---|---|---|---|
| `ActivityRewardConfig` | `VALUE_DIFF` | `SAME` | 测试服落后 |
| `LuckyCatConfig` | `SAME` | `VALUE_DIFF` | 线上落后（32 行 `ValueUp`/`ValueDown`） |
| `RechargeCommodityConfig` | `SAME` | `VALUE_DIFF` | 线上落后（10-21 手工补过测试服，线上没补） |

---

## 6. 本次实测数据（2026-10-22 23:39，测试服已同步后）

本地影子目录 406 张 txt：

测试服分两批推：23:24 推 21 张（24 张过体检，其中 3 张 `PARSE_BAD` 回滚，见 5.2）；
23:36 用 `--fix-numeric --apply-fix` 把 3 张的 1904 个脏单元格归一化后，23:39 补推
`SupremacyLevelConfig`（另外两张归一化后直接 `SAME`，无需推）。
每次推完重启都验证过：`initMap` 279 张全加载、**零 ERROR**。
剩下 6 张仍拦着：

| 表 | 判定 | 原因 |
|---|---|---|
| `EncourageTaskConfig` / `EncouragePlanConfig` / `MultiLanguage` | `ROW_LOSS` | 覆盖会删目标行 |
| `Language` | `COL_LOSS` | 导出缺 `Korean` 列 |
| `ChannelRechargeIdConfig` | `HEADER_DIFF` | 表头少一列 |
| `RewardItemConfig` | `REVIEW` | 未发布道具 |

> `SupremacyLevelConfig` 这次是 `VALUE_DIFF` 推的：15 行 × 6 列共 90 个单元格
> `499→500`（xlsx 里是 `'499.99999999999994'`，现导出器四舍五入成 500；
> 发包树里是旧链路截断的 499）。属于数值修正，不是结构变更。

同步**前**的双目标全量体检（406 张）：

| 结果 | 本机测试服 local | 线上服 gs |
|---|---|---|
| 语义漂移 | **30** | **31** |
| 其中 `VALUE_DIFF` | 16 | 17 |
| 其中 `NIL_CELLS`（同时有值差异） | 6 | 6 |
| 其中 `ROW_LOSS` | 3（`EncourageTaskConfig` 25 行、`EncouragePlanConfig` 1 行、`MultiLanguage` 1 行） | 同左 |
| 其中 `COL_LOSS` | 1（`Language` 缺 `Korean`） | 同左 |
| 其中 `HEADER_DIFF` | 1（`ChannelRechargeIdConfig` 少 `Android_99_Child2`） | 同左 |
| 其中 `ROW_ADD` | 1（`ChannelConfig` 16/17） | 同左 |
| 其中 `COL_GAIN` | 1（`SkillLogicConfig` 多 `IgnoreControl`） | 同左 |
| 其中 `REVIEW` | 1（`RewardItemConfig` 103 个 990000+ 道具） | 同左 |

> `VALUE_DIFF` 里最大的几张：`MainLevelConfig` 2540 行、`SupremacyLevelConfig` 933 行、
> `RewardGroup` 320 行、`MonsterConfig` 6 行。
> 数值列含 `nil` 的表共 **54** 张（`StoreConfig` 一张 5009 个），推之前必须 `--fix-nil` 或重跑导表。

| 数值列含 `nil` 的表 | **54**（必须先 `--fix-nil` 或重跑导表） |

对照审计底稿（37 张）：`EquipTalismana`（3604 行）、`WorkShopSetting`、`ArtifactSkillConfig`、
`JewelRankupConfig`、`EquipStarsConfig` 这次判成 `SAME` —— 复核过，
差异**只是 `nil` vs `null`/空串**（审计那版把空值归一化漏到了列尾），不是内容差异。
`PrivilegeTypeConfig` 也是 `SAME`（10-22 21:51 已定点修过 3 个单元格）。

---

## 7. 待决策（工具不替人做）

- 漂移表里哪几张属于「客户端已经发布、服务端必须跟上」？
  按审计建议分三批：批 2 是纯结构补齐（`SkillLogicConfig` / `RechargeCommodityConfig` /
  `ChannelRechargeIdConfig` + `Language` 补 Korean 列），批 3 是内容型数值表（跟版本走）。
- `RechargeCommodityConfig` 本地多 `SystemMessageShow` 列，42 行 `=1` 意味着那些礼包
  **不再发系统消息**，属行为变更，需产品确认后再推。
- `Language.txt` 的 `Korean` 列要不要先在导出器里补上（`DataHelper` 的类型行），
  否则这张表在两个目标上永远 `COL_LOSS`、永远推不了。
- 测试服和线上服的差异（`ActivityRewardConfig` / `LuckyCatConfig` / `RechargeCommodityConfig`）
  是先对齐测试服到线上，还是反过来？这决定 `--targets` 选哪一边。
