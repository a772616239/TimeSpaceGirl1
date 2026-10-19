# 国家旗帜 + 国家排行榜 设计说明

> 更新时间：2026-10-18
> 一句话定位：**给游戏加"玩家国籍"这条视觉线索**——通用排行榜每一行、聊天点开的玩家信息面板、启动页国家排行，三处共用同一套旗帜美术。

---

## 1. 需求与落点

| 需求 | 落点 | 状态 |
|---|---|---|
| 启动页可见的国家排行榜 UI（沿用原有画风） | `Login/LoginPanel.prefab` 加 `btnCountryRank` 入口 → `Modules/CountryRank/CountryRankPanel` | ✅ |
| 排行榜中显示各玩家国家旗帜 | **通用排行榜** `Ranking/RankingSingleListPanel.prefab` 每行 `countryFlag` | ✅ |
| 聊天点击玩家 → 信息面板显示国旗 | `Popup/PlayerInfoPopup.prefab` 的 `info/countryFlag` | ✅ |
| 默认按设备地区判定，可手改 | `CountryRegionUtil.cs` 写 Prefs → `CountryRankManager` 读 | ✅ |

**关键决定**：旗帜不是只挂在新做的"国家排行"弹窗上，而是接在**通用排行榜**
（战力/竞技场/试炼/兽潮/关卡/公会…共 10+ 个榜单）的公共渲染路径上，
一处改动全榜生效。

---

## 2. 美术资源

全部程序化生成（`.workbuddy/tools/gen_country_rank_art.py`），无外部素材依赖。

- 图集目录：`Assets/ManagedResources/Atlas/CountryRankPanelAtlas/`
  - AB：`lz4/atlas/countryrankpanelatlas`
  - `spritePackingTag = CountryRankPanelAtlas`
- **旗帜 29 面**：`cn2-guoqi_<iso>.png`（ISO 3166-1 alpha-2 小写）
  - 造型：**圆角小旗 + 斜切金边 + 右上/左下切角**（对齐全项目 UI 的切角语言）
  - 尺寸 132×88，含 `xx`（其他地区，灰底问号）兜底
- 面板件：标题条 / 条目底板（普通+前三名+自己）/ 页签（选中+未选）/ 名次牌（1/2/3+普通）/
  关闭按钮 / 我的排名条 / 旗帜选中框 / 面板底板 / 选择弹窗底板 / 登录页入口图标

画风取样自现有 UI：深紫 `#1d162a~#261a3b`、金色 `#ffcc00`、青色 `#00d0e8`、
细亮边 `#797979`、斜向排线暗纹、多边形切角。

---

## 3. 代码结构

### 3.1 C#（一行改动 + 一个新文件）

```
Assets/LuaFramework/Scripts/Utility/CountryRegionUtil.cs   (新)
Assets/Scripts/GameInit/GameSettings.cs                    (改 2 行：启动时调一次)
```

`CountryRegionUtil.GetDeviceRegionCode()` 取值优先级：

1. `RegionInfo.CurrentRegion.TwoLetterISORegionName`（与 `CrashlyticsMgr` 上报 Firebase 的 country 同一套 API）
2. 失败 → 按 `Application.systemLanguage` 推断（中日韩英）
3. 再失败 → `un` → 最终由 Lua 侧归一到 `xx`

写入 `PlayerPrefs["device_country"]`，**只在缺失时写一次**（幂等）。

> 选 C# 而不是 Lua 做设备地区：toLua 没有 `System.Globalization` 绑定，
> 从 Lua 侧调用需要新增 wrap + 重新生成绑定，代价大于收益。

### 3.2 Lua（新增 6 个文件，改 5 个）

```
Modules/CountryRank/CountryConfig.lua         国家表（ISO码/旗帜名/中日英韩显示名/别名）
Modules/CountryRank/CountryRankManager.lua    玩家国家读写 + 榜单数据 + 我的排名
Modules/CountryRank/CountryRankPanel.lua      国家排行榜弹窗
Modules/CountryRank/CountryFlagSelectPopup.lua 旗帜选择弹窗（网格）
Modules/CountryRank/CountryFlagUtil.lua       旗帜解析与绘制（排行榜/玩家信息共用）
Modules/CountryRank/UIConfigExtension.lua     运行期补充 UIConfig
```

改动：`Game.lua`（启动注册）、`GameEvent.lua`（新增 `CountryRank.OnCountryChanged`）、
`Managers.lua`（注册 CountryRankManager）、`UIData.lua`（UIName 1010/1011）、
`LanguageManager.lua`（新增文案，走手动翻译通道）、`LoginPanel.lua`、`PlayerInfoPopup.lua`、
`RankingSingleListPanel.lua`。

### 3.3 为什么是「运行期注册 UIConfig」而不是改表

`UIConfig` 是 `data_execl/base_data/UIConfig.xlsx` 导出的 **LZ 压缩表**。
手工加两行要同时动：xlsx → 导出 lua → LuaBytes → `DataConfigMD5Record.asset` 的 CRC32
→ 服务端 TSV，共 5 处，且压缩索引极易错位。

因此改为运行期 `rawset` 注入：

```lua
-- Modules/CountryRank/UIConfigExtension.lua
rawset(uiConfig, 1010, { id=1010, type=2, name="CountryRankPanel", ... })
```

🔴 **必须用 `rawset`**：`UIConfig` 解码后带 `SheetBase` 元表，其 `__newindex` 是
`readonlyMT`（空函数），普通赋值会被**静默吞掉**，不报错也不生效。

---

## 4. 玩家国家的数据优先级

```
PlayerPrefs["player_country"]   （玩家在旗帜选择面板手动选的）
        ↓ 没有时
PlayerPrefs["device_country"]   （CountryRegionUtil 按设备地区写入）
        ↓ 没有时
"xx"（其他地区）
```

榜单行里每个玩家的旗帜（`CountryFlagUtil.ResolveCountry`）：

1. `data.country` —— 服务端下发时直接用（✅ 协议补上后自动生效，UI 不用改）
2. 是「自己」→ 用本地记录的玩家国家
3. 其他玩家且服务端未下发 → **按 uid 稳定映射**到已支持国家（占位）

> ⚠️ 第 3 条是明确的**占位策略**：现在 `proto/` 里没有任何玩家国家字段，
> 服务端 `RankingInfo` 只有 `uid/name/head/level/rank/headFrame/time`。
> 补协议后第 1 条自动接管，不需要再动 UI 代码。

---

## 5. 已知边界 / 后续

| 项 | 说明 |
|---|---|
| **协议缺国家字段** | 真正的"每个玩家真实国籍"需要 `PlayerInfo`/`RankingInfo` 加 `country` 字段 + 服务端落库。当前第 3 条兜底 |
| **国家排行数据** | `CountryRankManager.GetRankList` 目前是本地可复现的模拟数据，`TODO(接服务端)` 已标注替换点，返回同结构即可 |
| **公会榜** | 公会没有国籍概念，这两个榜单（`GUILD_FORCE_RANK` / `CELEBRATION_GUILD`）**隐藏**旗帜 |
| **AB 需重打** | 新增图集与 prefab 在 `ManagedResources` 下，真机走 AB ⇒ 出包前必须跑 `FrameTool.BuildGameAssetBundles`。Editor 直接用资源无需重打 |
| **Lua 字节码** | 已 `scripts/lua-bytes-sync.sh` 同步；新增 6 个模块的 `.bytes` 均已在 `LuaBytes/` |

---

## 6. 验证

```bash
# 纯逻辑单测（44 项，不依赖 Unity）
cd LuaEncoder/luajit_mac/64
TS_ROOT=/Users/wangxufeng/Documents/TimeSpaceGirl1 LUA_PATH="./?.lua;;" \
  ./luajit ../../../scripts/lua-tests/test_country_rank.lua

# prefab 结构自检（孤儿节点 = 写了 m_Father 但没进父 m_Children）
python3 .workbuddy/tools/fix_prefab_children.py \
  Assets/ManagedResources/Prefabs/UI/Ranking/RankingSingleListPanel.prefab --check

# 字节码与源码同步自检
scripts/lua-bytes-sync.sh --check
```

### 🔴 踩过的坑：prefab 追加节点只写 `m_Father` 不够

脚本化给 prefab 加节点时，**必须同时**把新节点的 `fileID` 追加到父节点的 `m_Children`，
否则 Unity 打开后节点不挂在树上（等于没加），而且不报错。
`.workbuddy/tools/fix_prefab_children.py` 就是为此写的自检+修复工具，改完 prefab 必跑。

---

## 8. 国家覆盖范围（2026-10-19 补齐到 ISO 全量）

原先图集只有 **73 面**手绘旗（主要市场 + 欧洲逐国 + `xx` 问号兜底），ISO 3166-1 其余国家
在 `CountryConfig.Normalize` 里统统一律落到 `xx` ⇒ 玩家没法表达自己来自哪国。
现已补齐到 **250 条**（ISO 3166-1 全量 249 + `xx` 占位）：

| 项 | 数值 | 说明 |
|---|---|---|
| `cn2-guoqi_*.png` | 250 | 前 73 面手绘不覆盖，新增 177 面走 `add_remaining_countries.py` |
| `CountryConfig.List` | 250 | 前 73 条顺序不变（主要市场优先），新增按 ISO 码字母序追加 |
| `ResourcePathConfig` guoqi 段 | 250 | `sync_guoqi_resinfo.py --check` 一致 |
| 选择面板行数 | 63 行 × 4 列 | 内容高 `63 * 176 = 11088`，ScrollRect 独占纵向滚动 |

新增旗帜的做法（`.workbuddy/tools/add_remaining_countries.py`）：
1. 原图取 **flagcdn** `w320`（公有领域，源自 Wikimedia），cover 裁切到 116×72（不拉伸）；
2. 套用 `gen_country_rank_art.compose_flag` 的既有画框（圆角小旗 + 斜切金边 + 顶部高光），
   与手绘旗同一视觉语言；
3. **只补缺失 code，已存在的 73 面绝不覆盖**；
4. 同时产出 `_output/country_config_new_block.lua` 供插入 `CountryConfig.List`。

⚠️ 已知取舍：
- `yt`（马约特）CDN 上是印着 "MAYOTTE" 字样的徽章图，132×88 下不可辨 ⇒ 脚本用
  `SOURCE_OVERRIDE` 借法国三色旗；
- `re`/`gp`/`mq`/`pm` 等法国海外省用的是 CDN 上的**非官方**地区旗（无官方旗），视觉上可区分；
- `af` 仍是 CDN 上的共和国三色旗（现政权白旗未收录），沿用国际通行版本。

多语言：新增条目 **zh/en 全填**，jp/kr 只补常用国；`CountryConfig.GetName` 的回落顺序
由 `当前语言 → zh` 改为 `当前语言 → en → zh`（日/韩玩家看拉丁字母比看简体中文可读）。
