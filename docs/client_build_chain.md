# 客户端资源链路：Lua 字节码 / 配置表 / AssetBundle

> 更新时间：2026-10-12
> 一句话定位：**改客户端的东西改完不生效？先读这篇。**
> 90% 的「改了没反应」都是"只改了源文件、没同步真机实际读的那份产物"。

---

## 0. 🔴 最重要的一条

**真机跑的是预编译字节码，不是 `~Lua/*.lua` 源码。**

```
GameSettings.cs:112-117   !isEditor 时强制 luaBundleMode = true
        ↓
真机读 Assets/ManagedResources/LuaBytes/<路径下划线化>_64.bytes
Editor 才回落 ~Lua/*.lua
```

| | Editor | 真机 |
|---|---|---|
| 数据来源 | `~Lua/**/*.lua` | `Assets/ManagedResources/LuaBytes/**/*_64.bytes` |
| 改了源码不改 `.bytes` | ✅ 生效 | ❌ **不生效** |

⇒ **只改 `~Lua` 源码 = Editor 有效、真机无效。两个文件必须成对提交。**
仓库里有「只提交源码没重编字节码」的系统性问题，改动时务必自查。

---

## 1. Lua 字节码重编码

### 1.1 命名规则

源路径里的 `/` 变 `_`，加 `_64.bytes`：

```
~Lua/Logic/Network.lua
    → Assets/ManagedResources/LuaBytes/Logic_Network_64.bytes

~Lua/Common/LanguageManager.lua
    → Assets/ManagedResources/LuaBytes/Common_LanguageManager_64.bytes
```

### 1.2 命令

```bash
cd /Users/wangxufeng/Documents/TimeSpaceGirl1/LuaEncoder/luajit_mac/64

LUA_PATH="./?.lua;;" ./luajit -b \
  /abs/path/to/X.lua \
  /abs/path/to/X_64.bytes
```

🔴 **必须带 `LUA_PATH="./?.lua;;"` 且在本目录执行**（编码器依赖同目录的 lua 模块）。
🔴 **不要加 `-g`** —— `-g` 会把源码绝对路径写进字节码且**不剥离**。

### 1.3 验证（改了没把握就做这一步）

```bash
# 改动前后各用 -b -g 编码（带调试信息，便于反汇编比对）
cd LuaEncoder/luajit_mac/64
LUA_PATH="./?.lua;;" ./luajit -b -g /abs/X.lua /tmp/new_g.bytes
./luajit -bl /tmp/new_g.bytes > /tmp/new.list
# 归一化：把源码绝对路径统一化后再 diff
diff <(sed 's#/abs/path/to/#<SRC>#g' /tmp/old.list) \
     <(sed 's#/abs/path/to/#<SRC>#g' /tmp/new.list)
```

### 1.4 🔴 血泪教训：运行时 LuaJIT 必须与编码器严格同版本

真机跑的是 **LuaJIT 2.1.0-beta3** 编的字节码（编码器 `LuaEncoder/luajit_mac/64/luajit` 就是它）。

如果换了不同版本的 LuaJIT 重编 `libtolua.so`（运行时），**即使同为 2.1 线、`BCDUMP_VERSION`
都是 2、魔数 `1b 4c 4a 02` 不会被拒** —— **opcode 表在版本之间有增删** ⇒ 加载后执行错指令
⇒ **真机启动即卡死**（2026-10-12 真机实测）。

- `libtolua.so` 出自 **`topameng/tolua_runtime`**（LuaJIT **2.1.0-beta3**）。
  重编走 `scripts/libtolua16k/`，其 `verify.py` 的 **④ 号校验**会比对
  「`.so` 内版本串 == 编码器版本」，换错版本在校验阶段就被拦下。
- **别用 `alex4814/tolua_runtime`**（2.1.ROLLING ⇒ 卡死）。

---

## 2. 配置表链路（xlsx → lua → 服务端 TSV）

### 2.1 链路

```
data_execl/base_data/<X>.xlsx                      ← 🔴 唯一真源
   ↓  导表工具：Unity 菜单 Data Config/Window
   ↓           （Assets/Scripts/Editor/ExcelTool/DataConfig/DataConfigWindow.cs）
   ├→ 客户端 ~Lua/Config/Data/<X>.lua               （压缩编码）
   ├→ Assets/ManagedResources/LuaBytes/Config_Data_<X>_64.bytes   （真机实际读的）
   └→ 服务端 conf/server/<X>.txt                    （TSV）
```

⇒ **一处改动要同步三处**（源码 lua + 字节码 + 服务端 TSV），少一处就是"改了没生效"。

### 2.2 🔴 CRC32 门控

`DataConfigMD5Record.asset` 里存着每张源表 xlsx 的 **CRC32（十进制）**。

**改了 xlsx 必须同步这个值**，否则导表工具判定「未变更」→ 不重导出，
或反过来判「已变更」→ 重导出并**覆盖你手改过的 lua**。

- 结构：Unity YAML 的 `_keys:` / `_values:` 两个平行数组（各 300 项）。
- 🔴 **按 key 后缀匹配定位，不可按行号**（顺序会变）。
- 算值：

```bash
python -c "import zlib;print(zlib.crc32(open('data_execl/base_data/X.xlsx','rb').read())&0xffffffff)"
```

### 2.3 改表工具注意事项

```python
import openpyxl
wb = openpyxl.load_workbook(path)     # 🔴 不要传 data_only=True
ws = wb["Sheet1"]
ws.cell(row=r, column=c).value = v
wb.save(path)
```

- ⚠️ xlsx 有两种写法：**Excel 原版**（含 `sharedStrings`）与 **openpyxl 重存版**（`inlineStr`）。
  **别盲目 `git checkout` 历史 xlsx**（会换掉写法）；优先原地改。
  判据看**逐格内容**，不是哈希/文件体积。

### 2.4 读客户端压缩表

解码器：`~Lua/Framework/GameDataBase.lua` 的 `decodeList`
（`__indexs` / `__values` / `__refs` / `__refPoss` + LZ 式十进制重复 + 末位累计和）。

🔴 **比对前必须归一化行尾 TAB / CR**，否则全表逐行 diff 全是假差异。

---

## 3. AssetBundle 链路（三段式）

```
BuildABs/Android/                                     ← ① AB 构建产物
   ↑ FrameTool.BuildGameAssetBundles()               （GUI「整体打包资源」）
   ↓ FrameTool.CopyAssetBundleToStreamingAssets()    （GUI「复制资源到流媒体目录」）
Assets/StreamingAssets/Android/                       ← ② 包内资源的唯一来源
   ↑ FrameTool.BuildLuaAssetBundles()                （GUI「单打lua资源」，只重建 Lua）
```

🔴 **任一段没跑，Unity 打包不会报错**，只会静默把陈旧或缺资源打进包。

**最典型的坑是 Lua。** Lua bundle 的**真实名字**：

```
Assets/ManagedResources/LuaBytes.meta
    assetBundleName:    lzma/luabytes
    assetBundleVariant: unity3d
  ⇒ BuildABs/Android/lzma/luabytes.unity3d
  ⇒ CombinePack 里按 name.Replace("/","|") 变 lzma|luabytes.unity3d
```

⚠️ **它不带 `lua` 前缀、也不在 `lua/` 子目录**。
`Assets/StreamingAssets/lua/` 是**遗留空目录**，与 Lua 字节码无关，别拿它当判据。
判定是否就绪**只认文件名含 `luabytes` 的 bundle**。

缺了会怎样：真机启动即报 `StreamingAssets 路径资源丢失，请重新打包包内资源!`（`AssetBundleLoader`）。

体检：

```bash
scripts/check_ab_ready.sh      # 只读，逐项报 LuaBytes.meta / BuildConfigs / BuildABs / StreamingAssets / 最新 AAB
```

⚠️ 顺序：**先「整体打包资源」→ 再「复制资源到流媒体目录」**；
只有 Lua 变动时补「单打lua资源」。
「复制资源到流媒体目录」会**整目录删除** `StreamingAssets/Android`，所以必须在 AB 构建之后跑。

⚠️ `ResourcesCopy.cs` 的「Build/资源拷贝」是另一条手动选目录的路径，
依赖 `EditorUtility.OpenFolderPanel`，**batchmode 用不了**，别混淆。

---

## 4. 提交检查表（改客户端时逐条勾）

- [ ] `~Lua/**/*.lua` 源码改了
- [ ] **对应的 `LuaBytes/*_64.bytes` 重编并一起提交**（命名 = 路径下划线化 + `_64.bytes`）
- [ ] 如果改的是**配置表源 xlsx**：`DataConfigMD5Record.asset` 的 CRC32 已同步
- [ ] 三大产物齐全：客户端 lua + 字节码 + **服务端 `conf/server/<X>.txt`**
- [ ] 如果改了 bundle 相关（新资源/改名）：跑过 AB 构建 + 拷贝到 StreamingAssets
- [ ] 如果改了区服名：`LanguageManager.lua` 里 `AddManualTranslation` + 重编字节码（`d9059467d`）
- [ ] 🔴 **严禁 `git add -A`**，逐条 commit，中文 `type(scope): 摘要`

---

## 5. 故障速查

| 现象 | 根因 | 处理 |
|---|---|---|
| Editor 里改了生效，真机不生效 | 只改了 `~Lua` 源码，没重编 `.bytes` | 按 §1.2 重编并成对提交 |
| 改了表没用 | 三处没同步（lua / 字节码 / 服务端 TSV） | 按 §2.1 补齐 |
| 改了 xlsx，导出的 lua 又变回去了 | `DataConfigMD5Record.asset` 的 CRC32 没同步 | 半自动重导出覆盖了手改 |
| 真机启动即卡死、进不去登录界面 | 运行时 LuaJIT 版本 ≠ 字节码编码器版本（opcode 表不同） | 用 `topameng/tolua_runtime`（2.1.0-beta3）重编；跑 `libtolua16k/verify.py` ④ 号校验 |
| 真机报 `StreamingAssets 路径资源丢失，请重新打包包内资源!` | 包里没有 `lzma\|luabytes.unity3d` | `scripts/check_ab_ready.sh` 定位；重建 AB |
| 英文包里中文/区服名刷红字 | 该文案不在 `Language.xlsx` 里 | `LanguageManager.lua` 的 `AddManualTranslation` |
| 逐行 diff 全表都是差异 | 行尾 TAB / CR 没归一化 | 先归一化再比对 |
| `git checkout` 历史 xlsx 后导表报错 | 换成了另一种 xlsx 写法（sharedStrings ↔ inlineStr） | 优先原地改；别 checkout |
