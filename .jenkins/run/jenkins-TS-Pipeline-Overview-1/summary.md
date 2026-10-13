# TS-Pipeline-Overview #1

**结论：🔴 6 个环节失败**

| 分组 | 环节 | 结果 | 耗时 | 说明 |
|---|---|---|---|---|
| 客户端资源链 | Lua 源码↔字节码一致性 | 🔴 失败 | - | rc=127 · /usr/local/bin/bash: scripts/lua-bytes-sync.sh: No such file or directory |
| 客户端资源链 | AssetBundle 就绪体检 | 🔴 失败 | - | rc=127 · /usr/local/bin/bash: scripts/check_ab_ready.sh: No such file or directory |
| 打包环境 | 打包环境预检 | 🔴 失败 | - | rc=1 · 🔴 打包环境有阻塞项（见上方 ✗） |
| 仓库卫生 | 仓库卫生与 Lua 成对性 | ✅ 通过 | 1.0s | ✅ 仓库卫生检查通过 |
| 发布安全 | 送审闸门完好性 | 🔴 失败 | - | rc=2 · 找不到 scripts/aab_release.sh |
| Play | Play 轨道与 16KB 巡检 | 🔴 失败 | - | rc=2 ·    🔓 [play] 锁已释放 |
| 服务端 | 生产服只读巡检 | 🔴 失败 | - | rc=2 · /Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python: can't open file '/Users/wangxufeng/Documents/TimeSpaceGirl1/scripts/server_health_check.py': [Errno 2] No such |
| 服务端 | 本地 10002 区服状态 | ⚠️ 关注 | - | rc=2 · 找不到 10002 区服目录：/Users/wangxufeng/ts-shard10002 |

统计：通过 1 · 失败 6 · 关注 1 · 跳过 0
