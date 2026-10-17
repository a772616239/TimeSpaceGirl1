// ============================================================================
// 源码级修复：远征快速领奖（type=2）频次校验
//
// 事故：2026-10-18 玩家 Mozart(UID 10000013) 在 1 分钟内连发 35 次
//       ADVENTURE_REWARD_REQUEST{type:2, position:-1}，每次产出 777,600 钻石
//       + 20 余种物品，钻石最终达 1.25 亿（全服中位数 200）。
//
// 根因：原方法中 type==2 分支只调 getNewAdventureReward() 算奖励后直接下发，
//       既无每日次数上限，也无最小间隔冷却。
//
// 用法：把下方 ★修改区★ 的 3 行插入到 CombatLogic.takeNewAdventureReward()
//       的 `if (type == 2) {` 之后、`adventureFastReward = ...` 之前。
//
// 重要：本仓库不含 gameSrv 的完整源码工程（只有编译好的 jar），
//       因此这里提供的是「可直接粘贴的源码补丁 + 完整方法对照」，
//       待拿到厂商源码工程后按下方说明合入即可，之后不再依赖字节码注入。
// ============================================================================

/* ======================= 原始方法（反编译所得，供对照） =======================
 *
 * public void takeNewAdventureReward(ISession session, int type, int position) throws Exception {
 *     int uid = session.getUid();
 *     User user = UserManager.getUser(uid);
 *     long createTime = (int)user.getPlayerInfoManager().getCreateTime() / 1000;
 *     Map<Integer, CommonProto.Drop> adventureFastReward = null;
 *     if (type == 2) {
 *         // ★★★ 在这里插入频次校验 ★★★
 *         adventureFastReward = this.getNewAdventureReward(user, false, (int)(TimeUtils.now() / 1000L));
 *         if (System.currentTimeMillis() > createTime + 60000L && adventureFastReward.get(1).getItemlistCount() == 0) {
 *             throw new ErrorCodeException(ErrorCode.REWARD_COLLECTING);
 *         }
 *         user.getUserMissionManager().onGameEvent(user, GameEvent.ADVENTURE_TAKEREWARD, 1);
 *     } else {
 *         String err = "";
 *         if (position == 0 && !PlayerLogic.getInstance().checkAndUpdate(user, 4, 1)) {
 *             int[] result = SSpecialConfig.getOnceArrayValue("EXTRA_FAST_ADVENTUREREWARD_COST");
 *             if (result == null || result.length != 2) {
 *                 throw new ErrorCodeException(ErrorCode.CONFIG_ERROR);
 *             }
 *             int itemId  = result[0];
 *             int count   = result[1];
 *             HashMap<Integer, Integer> costItems = new HashMap<Integer, Integer>();
 *             costItems.put(itemId, count);
 *             if (!ItemUtil.itemCost(user, costItems, 1144, uid)) {
 *                 err = StoreLogic.checkBuyGoodsAndUpdate(user, 7, 10015, 1);
 *             }
 *         }
 *         if (!"".equals(err)) {
 *             throw new ErrorCodeException(ErrorCode.newDefineCode(err));
 *         }
 *         adventureFastReward = this.getNewAdventureFastReward(
 *                 user, ((CommonStaticConfig)STableManager.getFigureConfig(CommonStaticConfig.class))
 *                       .getGameSetting().getAdventureFastBattle());
 *         user.getUserMissionManager().onGameEvent(user, GameEvent.PlAY_STORY, 9999, 1);
 *         Poster.getPoster().dispatchEvent(new SecretEvent(user.getId()));
 *     }
 *     FightInfoProto.TakeAventureRewardResponse build =
 *         FightInfoProto.TakeAventureRewardResponse.newBuilder()
 *             .setDrop(adventureFastReward.get(1))
 *             .setRandomDrop(adventureFastReward.get(2))
 *             .build();
 *     MessageUtil.sendMessage(session, 1, 10023, (GeneratedMessage)build, true);
 * }
 * ========================================================================== */


/* ============================ ★修改区：插入这 3 行★ ============================
 *
 * 位置：CombatLogic.takeNewAdventureReward() 方法内，
 *       `if (type == 2) {` 之后、`adventureFastReward = this.getNewAdventureReward(...)` 之前。
 *
 *           if (type == 2) {
 *  >>>          if (!AdventureRewardGuard.tryAcquire(uid)) {          // ← 新增
 *  >>>              throw new ErrorCodeException(ErrorCode.REWARD_COLLECTING);  // ← 新增
 *  >>>          }                                                    // ← 新增
 *               adventureFastReward = this.getNewAdventureReward(...);
 *
 * 依赖：同包或 import com.ljsd.jieling.logic.fight.AdventureRewardGuard;
 * ========================================================================== */


package com.ljsd.jieling.logic.fight;

import com.ljsd.jieling.db.redis.RedisUtil;

/**
 * 远征快速领奖(type=2)频次护栏 —— 源码版。
 *
 * <p>与字节码补丁版 {@code com.ljsd.jieling.patch.AdventureRewardGuard} 逻辑一致，
 * 区别是本类设计为**直接编入 gameSrv 源码工程**，重新打包后依然生效，
 * 不再依赖 Javassist 注入。</p>
 *
 * <p>策略（Redis 计数，按自然日滚动）：</p>
 * <ul>
 *   <li>最小间隔 {@link #MIN_INTERVAL_MS}：两次快速领奖至少间隔 3 秒</li>
 *   <li>每日上限 {@link #MAX_PER_DAY}：每玩家每日最多 5 次</li>
 * </ul>
 *
 * <p>超限一律返回 false，由调用方抛 {@code ErrorCode.REWARD_COLLECTING}，
 * 客户端表现为"领取中不可重复领"，与原有错误处理一致，无需新增错误码。</p>
 */
public final class AdventureRewardGuard {

    /** 每玩家每日最多可用的快速领奖次数 */
    public static final int MAX_PER_DAY = 5;

    /** 两次快速领奖之间的最小间隔（毫秒） */
    public static final long MIN_INTERVAL_MS = 3000L;

    /** Redis key 前缀 */
    private static final String KEY_DAY = "ADV_FAST_REWARD";
    private static final String KEY_TS = "ADV_FAST_REWARD_TS";

    private AdventureRewardGuard() {
    }

    /**
     * 尝试占用一次快速领奖额度。
     *
     * <p><b>注意：本方法有副作用</b>（Redis incr + set），
     * 只有确认要继续发奖时才应调用。</p>
     *
     * @param uid 玩家 uid
     * @return true = 允许领奖且已计数；false = 超限，调用方应拒绝
     */
    public static boolean tryAcquire(int uid) {
        try {
            RedisUtil redis = RedisUtil.getInstence();
            long now = System.currentTimeMillis();

            // ---- 1) 最小间隔：防止脚本连发 ----
            String tsKey = KEY_TS + ":" + uid;
            Object lastObj = redis.get(tsKey);
            if (lastObj != null) {
                long last;
                try {
                    last = Long.parseLong(String.valueOf(lastObj));
                } catch (NumberFormatException ignore) {
                    last = 0L;
                }
                if (last > 0 && now - last < MIN_INTERVAL_MS) {
                    return false;
                }
            }

            // ---- 2) 每日上限 ----
            String dayKey = KEY_DAY + ":" + today() + ":" + uid;
            long cnt = redis.incr(dayKey, 1L);
            if (cnt == 1L) {
                // 首次计数时挂 25 小时过期，跨日自动清理
                redis.expire(dayKey, 25L * 60L * 60L);
            }
            if (cnt > MAX_PER_DAY) {
                return false;
            }

            // ---- 3) 记账本次时间戳 ----
            redis.set(tsKey, String.valueOf(now));
            redis.expire(tsKey, 60L * 60L);
            return true;

        } catch (Throwable t) {
            // 护栏本身出问题时不阻断正常发奖，但记录日志便于排查
            org.slf4j.LoggerFactory.getLogger(AdventureRewardGuard.class)
                    .error("AdventureRewardGuard.tryAcquire failed, uid=" + uid, t);
            return true;
        }
    }

    /** 当天 yyyyMMdd（服务器本地时区） */
    private static String today() {
        java.util.Calendar c = java.util.Calendar.getInstance();
        int y = c.get(java.util.Calendar.YEAR);
        int m = c.get(java.util.Calendar.MONTH) + 1;
        int d = c.get(java.util.Calendar.DAY_OF_MONTH);
        StringBuilder sb = new StringBuilder(8);
        sb.append(y);
        if (m < 10) {
            sb.append('0');
        }
        sb.append(m);
        if (d < 10) {
            sb.append('0');
        }
        sb.append(d);
        return sb.toString();
    }
}
