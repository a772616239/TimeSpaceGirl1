package com.ljsd.jieling.patch;

import com.ljsd.GameApplication;
import com.ljsd.jieling.db.redis.RedisUtil;
import com.ljsd.jieling.exception.ErrorCodeException;

/**
 * 内购发放门禁：替代 TestBuyGiftGoodsHandler 里「debug 一关就全禁」的粗门禁。
 *
 * <h3>1. 事故背景</h3>
 * 2026-10-18 01:10 按 Sieg 事件处置要求关闭 {@code server.debug} 后，
 * 客户端礼包购买全部失效。因为付费与免单共用同一条协议：
 * <pre>
 *   PayManager.Pay → iapMgr:BuyItem1（Google Play 真实扣款）
 *                  → ProcessPurchase 成功后 → NetManager.RequestBuyGiftGoods
 *                  → TEST_BUY_GIGT_GOODS_REQEUST
 * </pre>
 * 而 {@code TestBuyGiftGoodsHandler.process()} 第一行是：
 * <pre>
 *   if (!GameApplication.serverProperties.isDebug())
 *       throw new ErrorCodeException("In a formal setting");
 * </pre>
 * 于是 debug=false 把整条内购链路打死 —— 玩家在 Google Play 被真实扣款，
 * 服务端却拒绝发货。
 *
 * 线上日志实证（uid 10000017 Sakuya）：
 * 01:14:49 / 01:15:01 / 01:15:06 / 01:15:12 / 01:15:16 连点 5 次，
 * 全部 "In a formal setting"；01:49 起 uid 10000001 同样被拒。
 *
 * <h3>2. 为什么不能只删掉这道门禁了事</h3>
 * 该 handler 背后的 {@code BuyGoodsLogic.testBuyGoods()} 本质是 <b>GM 免单路径</b>：
 * <pre>
 *   sendGoods(uid, goodsId, "gm-test", "111111", now, -999, true, channel)
 *                                                ↑金额    ↑isGM
 * </pre>
 * {@code isGM=true} 跳过账单去重（billno 查询）与「支付金额=商品金额」校验；
 * 且 141 个商品 limit=0 完全不限购（{@code AbstractWelfareBag.buy()} 里
 * limit==0 直接放行）。裸开门禁 = 对全服开放免费无限刷钻石。
 *
 * <h3>3. 本补丁策略：三档开关 + 频控 + 全审计</h3>
 * <ol>
 *   <li>debug=true（开发/测试服）：<b>保持原样全放行</b>，行为零改动。</li>
 *   <li>debug=false（正式服）按 {@code mode} 判定：
 *     <ul>
 *       <li>{@code open}      —— 全体玩家放行（<b>默认</b>，恢复内购），受频控约束</li>
 *       <li>{@code whitelist} —— 只放行白名单 UID（发现刷货时收紧）</li>
 *       <li>{@code off}       —— 全部拒绝（紧急止血，等价于事故现状）</li>
 *     </ul>
 *   </li>
 *   <li>放行还需过：最小间隔 {@link #MIN_INTERVAL_MS}、
 *       每日总量 {@link #MAX_PER_DAY}、单商品每日 {@link #MAX_PER_GOODS_PER_DAY}。</li>
 *   <li>放行/拒绝全打日志，用 {@code PAYGATE_} 前缀即可审计。</li>
 * </ol>
 *
 * <h3>4. 运维：不重启即可改档</h3>
 * <pre>
 *   redis-cli -n 0 SET  10001:PAY_GATE_MODE open        # 恢复内购（默认）
 *   redis-cli -n 0 SET  10001:PAY_GATE_MODE whitelist   # 收紧为白名单
 *   redis-cli -n 0 SET  10001:PAY_GATE_MODE off         # 紧急止血
 *   redis-cli -n 0 SADD 10001:PAY_WHITELIST 10000017    # 加白
 * </pre>
 * Redis 键优先，5 秒缓存；Redis 没配则回落到 JVM 参数
 * {@code -Dpay.gate.mode=open} / {@code -Dpay.whitelist=10000017,10000001}。
 *
 * <h3>5. 失败方向</h3>
 * Redis 不可用时频控无法执行，<b>一律拒绝</b>（fail-close）：宁可让玩家重试，
 * 也不能在失去频控的状态下把 GM 免单通道敞开放量。
 *
 * <h3>6. 这是热补丁，不是根治</h3>
 * 重新打包 jar 会丢；根治要接真实支付验单，见 README「根治路线」。
 */
public final class PayGateGuard {

    /** 每玩家每日最多放行次数（挡脚本连点/连刷） */
    public static final int MAX_PER_DAY = 50;

    /** 同一玩家同一商品每日最多放行次数（挡无限购商品被刷） */
    public static final int MAX_PER_GOODS_PER_DAY = 20;

    /** 两次放行之间的最小间隔（毫秒） */
    public static final long MIN_INTERVAL_MS = 1000L;

    /** 模式缓存有效期（毫秒） */
    private static final long MODE_CACHE_MS = 5000L;

    private static final String KEY_PREFIX = "PAY_GATE";
    private static final String MODE_KEY = ":PAY_GATE_MODE";
    private static final String WL_KEY = ":PAY_WHITELIST";

    private static volatile String modeCache = null;
    private static volatile long modeCacheAt = 0L;

    private PayGateGuard() {
    }

    /**
     * 门禁主体。<b>抛 ErrorCodeException = 拒绝</b>；正常返回 = 放行。
     *
     * @param uid     请求玩家 uid
     * @param goodsId 商品 id（协议解析失败时为 -1，仅用于日志）
     * @param channel 客户端渠道
     */
    public static void check(int uid, int goodsId, String channel) throws Exception {
        // ① 开发/测试服：保持原样
        if (GameApplication.serverProperties != null && GameApplication.serverProperties.isDebug()) {
            return;
        }

        String mode = resolveMode();

        if ("off".equals(mode)) {
            slog("INFO", "PAYGATE_DENY_MODE_OFF uid=" + uid + " goodsId=" + goodsId);
            throw new ErrorCodeException("In a formal setting");
        }

        if ("whitelist".equals(mode) && !isWhitelisted(uid)) {
            slog("WARN", "PAYGATE_DENY_NOT_WHITELIST uid=" + uid
                    + " goodsId=" + goodsId + " channel=" + channel);
            throw new ErrorCodeException("In a formal setting");
        }

        // ② 频控（open 与 whitelist 都要过）
        //    RedisUtil 直接用 redisTemplate 字段，未初始化抛 NPE 并 printStackTrace，
        //    所以先探活；不可用则 fail-close。
        long dayCnt;
        long goodsCnt;
        try {
            RedisUtil redis = RedisUtil.getInstence();
            if (!redisReady(redis)) {
                slog("ERROR", "PAYGATE_DENY_REDIS_NOT_READY uid=" + uid + " goodsId=" + goodsId);
                throw new ErrorCodeException("In a formal setting");
            }
            int serverId = GameApplication.serverId;

            // 最小间隔
            String kTs = serverId + ":" + KEY_PREFIX + "_TS:" + uid;
            long last = 0L;
            Object lastObj = redis.get(kTs);
            if (lastObj != null) {
                try {
                    last = Long.parseLong(String.valueOf(lastObj));
                } catch (NumberFormatException ignored) {
                    last = 0L;
                }
            }
            long now = System.currentTimeMillis();
            if (last > 0L && now - last < MIN_INTERVAL_MS) {
                slog("WARN", "PAYGATE_DENY_TOO_FAST uid=" + uid + " goodsId=" + goodsId
                        + " deltaMs=" + (now - last));
                throw new ErrorCodeException("In a formal setting");
            }

            // 每日总量
            String kDay = serverId + ":" + KEY_PREFIX + ":" + today() + ":" + uid;
            dayCnt = redis.incr(kDay, 1L);
            if (dayCnt == 1L) {
                redis.expire(kDay, 25L * 60L * 60L);
            }
            if (dayCnt > MAX_PER_DAY) {
                slog("WARN", "PAYGATE_DENY_DAILY_LIMIT uid=" + uid + " goodsId=" + goodsId
                        + " cnt=" + dayCnt + " max=" + MAX_PER_DAY);
                throw new ErrorCodeException("In a formal setting");
            }

            // 单商品每日上限
            String kGoods = serverId + ":" + KEY_PREFIX + "_G:" + today() + ":" + uid + ":" + goodsId;
            goodsCnt = redis.incr(kGoods, 1L);
            if (goodsCnt == 1L) {
                redis.expire(kGoods, 25L * 60L * 60L);
            }
            if (goodsCnt > MAX_PER_GOODS_PER_DAY) {
                slog("WARN", "PAYGATE_DENY_GOODS_LIMIT uid=" + uid + " goodsId=" + goodsId
                        + " cnt=" + goodsCnt + " max=" + MAX_PER_GOODS_PER_DAY);
                throw new ErrorCodeException("In a formal setting");
            }

            redis.set(kTs, String.valueOf(now));
            redis.expire(kTs, 60L * 60L);
        } catch (ErrorCodeException e) {
            throw e;                                  // 业务拒绝原样上抛
        } catch (Throwable t) {
            slog("ERROR", "PAYGATE_DENY_REDIS_ERR uid=" + uid + " goodsId=" + goodsId
                    + " err=" + t);
            throw new ErrorCodeException("In a formal setting");
        }

        // ③ 审计
        slog("INFO", "PAYGATE_PASS uid=" + uid + " goodsId=" + goodsId
                + " channel=" + channel + " mode=" + mode
                + " day=" + dayCnt + "/" + MAX_PER_DAY
                + " goods=" + goodsCnt + "/" + MAX_PER_GOODS_PER_DAY);
    }

    /** 当前档位：Redis 键（5s 缓存）→ JVM 参数 → 默认 open */
    static String resolveMode() {
        long now = System.currentTimeMillis();
        if (modeCache != null && now - modeCacheAt < MODE_CACHE_MS) {
            return modeCache;
        }
        String m = null;
        try {
            RedisUtil redis = RedisUtil.getInstence();
            if (redisReady(redis)) {
                Object v = redis.get(GameApplication.serverId + MODE_KEY);
                if (v != null) {
                    m = String.valueOf(v).trim().toLowerCase();
                }
            }
        } catch (Throwable ignored) {
            // 落回 JVM 参数
        }
        if (m == null || m.isEmpty()) {
            m = System.getProperty("pay.gate.mode");
        }
        if (m == null || m.isEmpty()) {
            m = "open";                               // 默认恢复内购
        }
        if (!"open".equals(m) && !"whitelist".equals(m) && !"off".equals(m)) {
            m = "open";                               // 未知值按 open，避免误锁死
        }
        modeCache = m;
        modeCacheAt = now;
        return m;
    }

    /** 是否在白名单内（JVM 参数 → Redis set） */
    public static boolean isWhitelisted(int uid) {
        String id = String.valueOf(uid);

        String prop = System.getProperty("pay.whitelist");
        if (containsId(prop, id)) {
            return true;
        }

        try {
            RedisUtil redis = RedisUtil.getInstence();
            if (!redisReady(redis)) {
                return false;
            }
            String key = GameApplication.serverId + WL_KEY;
            if (redis.sHasKey(key, id)) {
                return true;
            }
            Object viaHash = redis.hget(key, id);
            return viaHash != null;
        } catch (Throwable ignored) {
            return false;
        }
    }

    /** Redis 模板是否已注入；未就绪时频控/白名单一律 fail-close */
    private static boolean redisReady(RedisUtil redis) {
        try {
            return redis != null && redis.getRedisTemplate() != null;
        } catch (Throwable t) {
            return false;
        }
    }

    private static boolean containsId(String csv, String id) {
        if (csv == null || csv.isEmpty()) {
            return false;
        }
        for (String s : csv.split(",")) {
            if (id.equals(s.trim())) {
                return true;
            }
        }
        return false;
    }

    private static String today() {
        java.util.Calendar c = java.util.Calendar.getInstance();
        int y = c.get(java.util.Calendar.YEAR);
        int m = c.get(java.util.Calendar.MONTH) + 1;
        int d = c.get(java.util.Calendar.DAY_OF_MONTH);
        return String.valueOf(y) + (m < 10 ? "0" + m : String.valueOf(m))
                + (d < 10 ? "0" + d : String.valueOf(d));
    }

    /** 直接写 slf4j，避免依赖业务 logger 的初始化时机 */
    private static void slog(String level, String msg) {
        try {
            org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(PayGateGuard.class);
            if ("WARN".equals(level)) {
                log.warn(msg);
            } else if ("ERROR".equals(level)) {
                log.error(msg);
            } else {
                log.info(msg);
            }
        } catch (Throwable ignored) {
            System.out.println("[PAYGATE] " + level + " " + msg);
        }
    }
}
