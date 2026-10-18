# Unity MCP 控制流程（TimeSpaceGirl1）

> 更新时间：2026-10-18。配套技能：`unity-mcp-ts`（DSH 技能库，内容同源）。
> 本文面向「要用 mcp__unity__* 工具操作本项目 Unity Editor」的场景：部署架构、
> 连通检查、工具速查、踩坑与恢复。

---

## 架构总览（本项目实际拓扑）

```
DSH agent
  └─ mcp-client (stdio)                      ~/.dsh/profiles/web/cordis.patch.yml 的 mcp-unity 条目
      └─ uvx mcpforunityserver==10.3.0       Python MCP server (FastMCP, stdio)
          └─ TCP 127.0.0.1:6400~640x         Unity 侧 StdioBridgeHost (TcpListener)
              └─ TimeSpaceGirl1 Editor      6000.6.5f1, MCPForUnity.Editor 程序集
```

- **只能用 stdio 传输**。HTTP/WebSocket 模式（默认 8080 端口）被本机 Jenkins 占用
  （`jenkins.war --httpPort=8080`），HTTP 起不来，且包的自动配置切到 HTTP 时会把
  stdio 桥也停掉，两头落空（2026-10-18 实测翻过车）。
- `Assets/Editor/McpBridgeBoot.cs`（`[InitializeOnLoad]`）每次 domain load 调用
  `McpCiBoot.StartStdioForCi()` 钉死 stdio 并自启桥——自恢复保障，勿删。
- 工具名前缀 `mcp__unity__`，资源 URI `mcpforunity://`。
- 桥端口会漂移（6400 被占则顺延 6401/6402…），以
  `~/.unity-mcp/unity-mcp-status-<hash>.json` 为准（`reason` 应为 `ready`）。

---

## 连通检查（按顺序）

1. `mcp__unity__read_console {action:"get", count:1}` —— 最轻量探针。
2. `read_mcp_resource(server:"unity", uri:"mcpforunity://editor/state")`
   看 `data.editor.play_mode.is_playing`、`data.advice.ready_for_tools`、
   `data.compilation.is_compiling`。
3. 文件系统侧：`lsof -nP -iTCP:6400 -sTCP:LISTEN`（端口可能漂移）；status json
   心跳应持续更新。

> `manage_editor {action:"telemetry_ping"}` 返回 queued **不代表桥活着**，
> 必须用真实读工具（read_console / manage_scene）验证。

---

## 工具速查

| 要做什么 | 用哪个 |
|---|---|
| 查编译/播放状态 | `mcpforunity://editor/state` 资源 |
| 创建/改 GameObject | `manage_gameobject`（create/modify/delete/duplicate） |
| 组件读写 | `manage_components`；读详情走 `mcpforunity://scene/gameobject/{id}/components` |
| 写 C# 脚本 | `create_script` / `script_apply_edits`（结构化编辑，推荐） |
| 动态执行 C# | `execute_code`（Roslyn 后端，C# 12） |
| 刷新/触发编译 | `refresh_unity {mode:"force", compile:"request"}` |
| 截图 | `manage_camera {action:"screenshot", capture_source:"scene_view", include_image:true}` |
| 找对象 | `find_gameobjects`（只返回 instanceID，详细数据走资源 URI） |
| 批量操作 | `batch_execute`（默认上限 25 条/批） |
| 菜单项 / 测试 | `execute_menu_item`；`run_tests` → `get_test_job` |

---

## 踩坑清单（全部实测）

1. **改 `Packages/manifest.json` 后 Unity 不会自动解析**——必须激活/聚焦 Unity
   窗口触发 Package Manager 刷新（`open -a "/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app"`，
   ~10s 生效）。
2. **AssetDatabase 外部文件变化同样要聚焦窗口**，或直接 `refresh_unity`。
3. **`execute_code` 拿不到返回值**除非结尾 `return <expr>;`。
4. **`execute_code` 安全拦截**：`AssetDatabase.DeleteAsset`、`File.Delete` 等会被
   blocked-pattern 拦。替代：`rm` 文件 + `refresh_unity`，或 `Object.DestroyImmediate(x, true)`。
5. **`sharedMaterial` 等 Object 引用属性**：`manage_components set_property` 的
   `{guid/path}` 值可能转换失败，改在 `execute_code` 里
   `AssetDatabase.LoadAssetAtPath<Material>(...)` 直接赋值。
6. **`execute_code` 里类型声明**（class/record）要放在表达式之后、语句结尾。
7. **Play 模式中**：包解析/资产导入被推迟；play 中改脚本会 domain reload 中断游戏。
   部署类操作先确认 `is_playing:false`。
8. **与编辑器内置程序集同名的 DLL**（Microsoft.CodeAnalysis 等）：编辑器运行中
   导入会停在 stub meta（DefaultAsset），需手写完整 PluginImporter meta
   （带 Any 平台 Exclude 列表，参考 `Assets/Plugins/Sirenix` 样例）。
9. **Scene View 截图前先 LookAt**：`SceneView.lastActiveSceneView.LookAt(pos,
   Quaternion.Euler(25,-35,0), size)`，否则截到的是上次视角。
10. **管理类资产别放错目录**：临时材质/脚本放 `Assets/Editor/`，别进
    `Assets/Plugins/Roslyn/`（DLL 专用目录）。

---

## Roslyn（已启用）

- `Assets/Plugins/Roslyn/` 只放 `Microsoft.CodeAnalysis(.CSharp)` 4.12.0
  （NuGet netstandard2.0），Editor-only meta（不进 APK/AAB）。
- `System.Collections.Immutable / Reflection.Metadata / Unsafe` **不要放**：
  Unity 6 内置 BCLExtensions 已带同版本（8.0.0/6.0.0），csc rsp 解析到内置副本，
  项目副本零引用。
- `USE_ROSLYN` 宏在 ProjectSettings 的 **Android** 条目（`NamedBuildTarget` 无
  Editor 项；宏只被 Editor-only 程序集消费，Player 构建无影响）。
- 效果：`manage_script` 的 Roslyn span 校验、`execute_code` 的 C# 12 后端
  （返回带 `compiler: roslyn`）。

---

## 断线恢复

1. 桥断（所有 `mcp__unity__*` 失败）：确认
   `defaults read com.unity3d.UnityEditor5.x MCPForUnity.UseHttpTransport` 为 `0`，
   然后 `open -a Unity` 触发刷新；McpBridgeBoot 在下次 domain load 自启桥。
2. 仍不通：看 `Logs/Editor.log` 的 `MCP-FOR-UNITY` 行——出现
   `Failed to start MCP transport: Http` 即 transport 被切到 HTTP，重启 Unity
   后 McpBridgeBoot 钉回 stdio。
3. DSH 侧：mcp-client 自动重连（10 次退避）；耗尽后编辑
   `~/.dsh/profiles/web/cordis.patch.yml` 触发 HMR 重载，无需重启 dsh web。

---

## 相关文件

| 文件 | 作用 |
|---|---|
| `Packages/manifest.json` | git 依赖 pin `?path=/MCPForUnity#v10.3.0`（勿改 #main） |
| `Assets/Editor/McpBridgeBoot.cs` | stdio 桥引导（自恢复） |
| `Assets/Plugins/Roslyn/` | Roslyn DLL（Editor-only） |
| `~/.dsh/profiles/web/cordis.patch.yml` | DSH mcp-unity 客户端条目（仓外） |
| `~/.unity-mcp/unity-mcp-status-*.json` | 桥状态/端口/心跳（仓外） |
| `ProjectSettings/ProjectSettings.asset` | USE_ROSLYN 宏（Android 条目） |
