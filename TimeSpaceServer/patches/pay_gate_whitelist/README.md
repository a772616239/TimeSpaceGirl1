# 内购发放门禁补丁（debug 关闭后礼包买不了）

> 创建：2026-10-18
> 关联事故：关闭 `server.debug` 后全服内购失效（Sakuya uid 10000017 连点 5 次全被拒）
> 关联手册：`../../docs/gm_abuse_incident_playbook.md`

---

## 1. 问题

`server.debug` 关掉之后，**所有礼包都买不了**。原因不在支付，而在服务端发货这一步：

```
客户端 PayManager.Pay()
  → iapMgr:BuyItem1()            ← Google Play 真实扣款
  → ProcessPurchase 成功
  → NetManager.RequestBuyGiftGoods()        （NetManager.lua:3398）
  → TEST_BUY_GIGT_GOODS_REQEUST             ← 付费与免单共用这一条协议
  → TestBuyGiftGoodsHandler.process()
       if (!isDebug()) throw "In a formal setting"   ← 就是这一行
```

`TEST_BUY_GIGT_GOODS_REQEUST` 名义上是「测试购买」，实际上**是本项目唯一的发货通道**：
全 jar 搜 `androidpublisher` / `receipt` / `purchaseState` 零命中，
`tk` 登录服也没有任何 pay servlet —— 即**真实支付验单链路从来就没实现过**。

所以关掉 debug = 关掉内购，且玩家是**被 Google Play 真实扣款后**才被拒（收钱不发货）。

### 线上实证

```
$ ssh gs 'grep -a -B3 "In a formal setting" /data/srvlog/gameserver.log'
01:14:49.807  request=10000017  commond =TEST_BUY_GIGT_GOODS_REQEUST
01:14:49.825  [CODE: -1][操作失败][In a formal setting]
01:15:01.615  request=10000017  commond =TEST_BUY_GIGT_GOODS_REQEUST
01:15:01.616  [CODE: -1][操作失败][In a formal setting]
01:15:06.902 / 01:15:12.069 / 01:15:16.109  同样被拒（共 5 次）
01:49:13.013  request=10000001  同样被拒
```

uid 10000017 = **Sakuya**（lv84）。

---

## 2. 为什么不能只把门禁删掉

`TestBuyGiftGoodsHandler` 背后调的 `BuyGoodsLogic.testBuyGoods()` 是**GM 免单路径**：

```java
sendGoods(uid, goodsId, "gm-test", "111111", now, -999, true, channel)
//                                  ↑金额   ↑isGM=true
```

- `amount = -999` 是**免金额校验的哨兵值**（`sendGoods` 里 `if (amount != -999 && price*100 != amount)` 才报错）
- `isGM = true` 会**跳过 billno 去重**（不查 Mongo 里有没有这张订单）
- 商品配置里 **141 个 `Limit=0`**，`AbstractWelfareBag.buy()` 对 `limit==0` 直接放行 ⇒ 完全无限购

⇒ 裸开门禁 = 对全服开放**免费无限刷钻石**。这正是 Sieg 事件那类漏洞的翻版。

---

## 3. 补丁方案：三档开关 + 频控 + 全审计

新增 `com.ljsd.jieling.patch.PayGateGuard`，把 handler 里的 debug 硬门禁换成它。

| 模式 | 行为 | 用在什么时候 |
|---|---|---|
| `open`（**默认**） | 全体玩家放行，受频控约束 | 恢复内购（线上默认值） |
| `whitelist` | 只放行白名单 UID | 发现刷货苗头时收紧 |
| `off` | 全部拒绝 | 紧急止血（= 事故现状） |

`debug=true` 时**直接 return，行为与原版完全一致**，开发/测试服零影响。

### 频控（`open` / `whitelist` 都要过）

| 项 | 值 | 目的 |
|---|---|---|
| `MIN_INTERVAL_MS` | 1000ms | 挡住「连点 5 次」这类爆破 |
| `MAX_PER_DAY` | 50 次/人/日 | 挡脚本连刷 |
| `MAX_PER_GOODS_PER_DAY` | 20 次/人/商品/日 | 挡无限购商品（`Limit=0`）被刷 |

计数落 Redis，首次 `incr` 时设 25h 过期，跨日自动清理。

### 失败方向：fail-close

`RedisUtil` 的每个方法都直接用 `redisTemplate` 字段，未注入时抛 NPE 并 `printStackTrace`。
所以先用 `getRedisTemplate()` 探活；**Redis 不可用一律拒绝**——
宁可让玩家重试，也不能在失去频控的状态下把 GM 免单通道敞开放量。

### 审计

所有判定都打日志，`PAYGATE_` 前缀一键可查：

```
PAYGATE_PASS               uid= goodsId= channel= mode= day=/50 goods=/20
PAYGATE_DENY_MODE_OFF      uid= goodsId=
PAYGATE_DENY_NOT_WHITELIST uid= goodsId= channel=
PAYGATE_DENY_TOO_FAST      uid= goodsId= deltaMs=
PAYGATE_DENY_DAILY_LIMIT   uid= goodsId= cnt= max=
PAYGATE_DENY_GOODS_LIMIT   uid= goodsId= cnt= max=
PAYGATE_DENY_REDIS_NOT_READY / PAYGATE_DENY_REDIS_ERR
```

---

## 4. 运维：不重启即可改档（5 秒生效）

```bash
# 恢复内购（默认就是这个）
redis-cli -n 0 SET 10001:PAY_GATE_MODE open

# 发现有人刷货 → 收紧
redis-cli -n 0 SET  10001:PAY_GATE_MODE whitelist
redis-cli -n 0 SADD 10001:PAY_WHITELIST 10000017
redis-cli -n 0 SADD 10001:PAY_WHITELIST 10000001

# 紧急止血
redis-cli -n 0 SET 10001:PAY_GATE_MODE off

# 回滚到出厂行为（等价于没有本补丁，即全拒）
redis-cli -n 0 DEL 10001:PAY_GATE_MODE
```

优先级：**Redis 键（5s 缓存）→ JVM 参数 → 默认 `open`**。
JVM 参数形式：`-Dpay.gate.mode=open`、`-Dpay.whitelist=10000017,10000001`（需改启动脚本，一般不用）。

---

## 5. 构建

```bash
GS=/path/to/gameserver            # 含 gameSrv-1.0.0.jar 与 lib/
JAR=$GS/gameSrv-1.0.0.jar
LIB=$(ls $GS/lib/*.jar | tr '\n' ':')

# 1) 编译护栏类
javac -source 1.8 -target 1.8 -encoding UTF-8 \
      -cp "$JAR:$LIB" -d out PayGateGuard.java

# 2) 编译注入器
javac -encoding UTF-8 -cp "$GS/lib/javassist-3.18.2-GA.jar:$JAR:$LIB" \
      -d inject/out InjectPayGate.java

# 3) 注入（基于【线上 jar】，不要用仓库 jar，见 §7 注意事项 1）
java -cp "inject/out:$GS/lib/javassist-3.18.2-GA.jar:$JAR:$LIB:out" \
     InjectPayGate "$JAR" patched "$LIB:out"

# 4) 打进 jar
mkdir -p stage/com/ljsd/jieling/patch stage/com/ljsd/jieling/handler/store
cp out/com/ljsd/jieling/patch/PayGateGuard.class            stage/com/ljsd/jieling/patch/
cp patched/com/ljsd/jieling/handler/store/TestBuyGiftGoodsHandler.class \
   stage/com/ljsd/jieling/handler/store/
cd stage && jar uf "$JAR" \
   com/ljsd/jieling/patch/PayGateGuard.class \
   com/ljsd/jieling/handler/store/TestBuyGiftGoodsHandler.class
```

## 6. 部署

```bash
# 1) 备份（本仓约定目录）
ssh gs 'mkdir -p /root/incident_20261018 && \
        cp -a /home/java/gameserver/gameSrv-1.0.0.jar \
              /root/incident_20261018/gameSrv-1.0.0.jar.bak.$(date +%Y%m%d_%H%M%S)'

# 2) 上传已打好的 jar
scp gameSrv-1.0.0.jar gs:/home/java/gameserver/gameSrv-1.0.0.jar

# 3) 完整性 + 补丁落位校验
ssh gs 'unzip -t /home/java/gameserver/gameSrv-1.0.0.jar | tail -1;
        unzip -p /home/java/gameserver/gameSrv-1.0.0.jar \
          com/ljsd/jieling/handler/store/TestBuyGiftGoodsHandler.class > /tmp/h.class;
        javap -c /tmp/h.class | grep -c PayGateGuard.check'   # 应为 1

# 4) 重启（会踢线，需用户确认；在线 0 人时最安全）
ssh gs 'cd /home/java/gameserver && sh RESTART-GAMESERVER.sh'
```

## 7. 验证

```bash
# ① 服务起来了、debug 仍是 false
ssh gs 'grep -a "ServerProperties ->" /data/srvlog/gameserver.log | tail -1'

# ② 补丁生效：让玩家点一次购买，日志应出现
ssh gs 'grep -a "PAYGATE_" /data/srvlog/gameserver.log | tail -5'
#   期望：PAYGATE_PASS uid=10000017 goodsId=xxx channel=xxx mode=open day=1/50 goods=1/20

# ③ 确认货真的到了（BuyGoodsLogic 的发放日志）
ssh gs 'grep -a "send to uid=10000017" /data/srvlog/gameserver.log | tail -3'

# ④ GM 通道仍是关的（不能被这次改动误开）
ssh gs 'grep -a "GM_REQUEST" /data/srvlog/gameserver.log | tail -3'
```

## 8. 🔴 注意事项

1. **必须在【线上 jar】上打补丁，不能用仓库 jar。**
   仓库 `TimeSpaceServer/.../gameSrv-1.0.0.jar` **不含** `AdventureRewardGuard`
   （它是线上单独注入的）。拿仓库 jar 替换上去会把 Mozart 的远征刷奖漏洞一起放回来。
   已核对：线上 jar = 仓库 jar + `AdventureRewardGuard`。

2. **这是热补丁，重新打包 jar 会丢。** 长期要写进 `gameSrv` 源码或改成真实支付验单。

3. **`server.debug` 不要开回来。** 它与 GM 通道共用；本补丁正是为了把「内购」和
   「GM 调试」这两件事解耦，不必再靠开 debug 换内购。

4. **`off` 模式等于玩家付了钱拿不到货**，只用于止血，用完尽快回 `open`。

---

## 9. 根治路线（未做，需排期）

当前架构下服务端**无法验证玩家是否真的付了钱**，因为客户端压根没上传凭证：

| 现状 | 位置 |
|---|---|
| `IAPManager.ProcessPurchase` 已拿到 `product.receipt` / `transactionID` | `Assets/Scripts/IAP/IAPManager.cs:150` |
| 但只 `Debug.Log` 打印，**没有上传** | 同上 |
| `TestBuyGiftGoodsRequest` 只有 `goodsId` + `channel`，**无收据字段** | `proto/protos/PlayerInfoProto.proto:343` |
| 服务端无任何收据校验类 | 全 jar 搜 `androidpublisher`/`receipt` = 0 |

**要根治，三步：**

1. **proto 加字段**：`TestBuyGiftGoodsRequest` 增加 `optional string receipt = 3;`
   （Google Play 的 `product.receipt`，内含 `purchaseToken`）。
2. **客户端上传**：`PayManager.Pay` 把 `ret1.product.receipt` 一并带上。
3. **服务端验单**：用 Play Developer API
   `androidpublisher.purchases.products.get(packageName, productId, token)`
   校验 `purchaseState==0`（已购买）且未被消费过，通过后才 `sendGoods`，
   并把 `purchaseToken` 当 `billno` 落库去重（这样就不必走 `testBuyGoods` 的免单路径）。

凭据方面本仓已有基础：`scripts/play_upload.py` + `.secrets/service-account.json`
（`play-publisher@platinum-loop-468100-k5.iam.gserviceaccount.com`），
但**需要额外授予「查看财务数据」权限**才能查订单，见 `docs/google_play_upload_setup.md`。

在 1~3 完成前，`open` + 频控 + 审计是能同时满足「内购可用」和「不裸奔」的唯一选择。
