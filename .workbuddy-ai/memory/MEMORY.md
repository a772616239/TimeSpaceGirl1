# TimeSpaceGirl1 项目长期记忆

## 工作约定

- **改完就提交**（用户 2026-10-20 明确要求「记住提交啊」）：任何代码/配置/脚本改动完成后，
  立即 `git add` → 分组提交 → `git push origin release`，不要攒在工作区。
- 提交按主题分组，不要一把梭；信息用 conventional commits 中文描述（`fix(client):`、`feat(ci):`、
  `chore(build):`、`test(lua):`），正文写清根因/影响面。
- 提交前排除产物与临时文件：`apks/`、`build_log_*.txt`、`Assets/_Recovery/`、
  `.workbuddy*/tmp*/`、Unity 自动生成的 `untitledfolder`。
- 分支：主开发分支是 `release`（不是 main/master）。
- **总结的 skill 一律放 `docs/`**（用户 2026-10-20 明确要求）：写成扁平的
  `docs/<topic>_skill.md`（与 `unity_android_build_skill.md`、`cheat_detection_skill.md` 同风格：
  顶部写适用范围/更新时间/关联文档，正文含配方、判断规则、坑位、案例数据）。
  `.workbuddy-ai/skills/<name>/` 只留一个十几行的路由 `SKILL.md`（frontmatter + 指向 docs）
  和可执行脚本，**正文不要再堆在 skills 目录里**。

## 打包与服务器口径

- **线上服 = 柯测试服 = `129.226.213.65:8080`**（资源站 `:81`），即历史 Play 上架包用的现网。
  Jenkins 里选 `SERVER_ENV=现网-129.226.213.65`。
- `build_envs.json` 里标「正式服」的 `103.151.173.99:8080` 实测已死（HTTP 000），**不要用**。
- 出包前必须确认 Unity 编辑器未占用工程（`pgrep -x Unity`），否则 AB 重建 rc=3 直接失败；
  本机 AppleScript quit 被 TCC 拒，只能 `kill -TERM <pid>`。
- version.txt 共四处（`Assets/Resources/`、`Assets/StreamingAssets/Android/Resources/`、
  `Assets/Android/Resources/`、`AssetBundles/`），改环境要一起对齐；进包的是 StreamingAssets 那份。

## 关键坑位

- 真机换包后仍连旧服：`VersionManager.InitVersions()` 优先用持久化
  `persistentDataPath/Android/version.txt`，已加 `SyncServerConfigFromPackage()` 用包内值纠正。
- 纯后端表（第 3 行导出类型全 4）导表工具会空跑，需要 `append_reward_items_to_server.py` 手工补。
- Unity batchmode 下 `Debug.Log` 抓不到，只能自己写文件日志；`Logs/Editor.log` 也不可靠。
