# 自动化执行记忆 · Play 16KB 页大小合规巡检（com.Warera.timespace）

任务：跑 `scripts/play_16kb_watch.py` → 读 Play 轨道 / 对 apks 最新 AAB 取证 16KB 两层 / 与上次 diff / 发 QQ 邮件 / 写 `scripts/.play16kb_state.json`。
性质：**只读巡检**，不改仓库文件、不重打包、不重启服务。

## 执行记录

### 2026-10-12 10:11（首次运行，无基线）
- 脚本退出码 **0**，耗时 6s；邮件已发至 `772616239@qq.com`（凭据来源 `/Volumes/S/TD/.env`）。
- 取证对象：`apks/2026-10-12/CLIBuild/092806.aab`（421.3 MB，versionCode 66）。
- Play 轨道：`production completed v66` / beta·alpha 空 / `internal completed v61`。
  - ⚠️ 与 09:45 的项目记录（`production draft v66; completed v64`）相比，**v66 已从 draft 推进到 completed，v64 已不在 production 轨道上** ⇒ 已独立复核确认。含义：v66 已提交发布（API 侧面显示 completed；Play Console 里可能仍显示审核中）。需人工确认是否本人操作。
- 门槛1（硬性）：**12/12 全 p_align=16384，0 不合规** ✅
- 门槛2：Play 点名集合 3 个 → 其中 `libtolua.so` 已 r28 达标（历史遗留名字仍在集合内，报告显示「✅ 已达标」）；**真正待上游修复的只剩 2 个**：`libFirebaseCppAnalytics.so`、`libFirebaseCppCrashlytics.so`（均 r21e，Firebase 官方预编译）。
  - `libnative-googlesignin.so` 已随依赖移除彻底消失；`libFirebaseCppApp-12_8_0.so` 因 12.8.0→12.10.1 改名而脱离清单。
- state 基线已落盘：`elf="12 ELF checked, 0 non-compliant"`，`flagged=[libFirebaseCppAnalytics.so, libFirebaseCppCrashlytics.so]`。
- 未覆盖项：Play Console 的 16KB 告警**无公开 API**，必须人工去 Play Console → 发布 → App Bundle 浏览器 → 选版本 → 「支持的页大小」核对。
- 并发注意：脚本会建 Play edit，**绝不能与上传并发**（实测会导致上传 edit 被删、整包失败）。本次运行前已确认无 `play_upload` 进程。
