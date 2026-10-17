package com.ljsd.jieling.patch;

import com.ljsd.jieling.db.redis.RedisUtil;
import com.ljsd.jieling.exception.ErrorCode;
import com.ljsd.jieling.exception.ErrorCodeException;

/**
 * 远征快速领奖(type=2)频次护栏。
 *
 * 背景：2026-10-18 发现玩家 Mozart(UID 10000013) 在 1 分钟内连发 35 次
 * ADVENTURE_REWARD_REQUEST(type=2)，每次产出 20+ 物品与 77 万钻石，
 * 使其钻石达到 1.25 亿（全服中位数 200）。
 *
 * 根因：CombatLogic.takeNewAdventureReward() 的 type==2 分支只调用
 * getNewAdventureReward(user,true,now) 算出奖励后直接下发，
 * 既无每日次数上限，也无最小间隔冷却；对比 type==0 分支会走
 * PlayerLogic.checkAndUpdate(user,4,1) 做次数/消耗校验。
 *
 * 本类在 type==2 分支入口做两道检查（Redis 计数，按自然日滚动）：
 *   1) 最小间隔：同一次领奖至少间隔 MIN_INTERVAL_MS（默认 3000ms）
 *   2) 每日上限：每玩家每日最多 MAX_PER_DAY 次（默认 5 次）
 *
 * 失败一律抛 REWARD_COLLECTING（"奖励领取中"），客户端表现为不可重复领，
 * 不影响正常的单次/少数次领取。
 */
public final class AdventureRewardGuard {

    /** 每日最多允许的快速领奖次数 */
    public static final int MAX_PER_DAY = 5;

    /** 两次领奖之间的最小间隔（毫秒） */
    public static final long MIN_INTERVAL_MS = 3000L;

    private static final String KEY_PREFIX = "ADV_FAST_REWARD";

    private AdventureRewardGuard() {
    }

    /** 当天 yyyyMMdd（服务器本地时区） */
    private static String today() {
        java.util.Calendar c = java.util.Calendar.getInstance();
        int y = c.get(java.util.Calendar.YEAR);
        int m = c.get(java.util.Calendar.MONTH) + 1;
        int d = c.get(java.util.Calendar.DAY_OF_MONTH);
        return String.valueOf(y) + (m < 10 ? "0" + m : String.valueOf(m))
                + (d < 10 ? "0" + d : String.valueOf(d));
    }

    private static String dayKey(int uid) {
        return KEY_PREFIX + ":" + today() + ":" + uid;
    }

    private static String tsKey(int uid) {
        return KEY_PREFIX + "_TS:" + uid;
    }

    /**
     * 校验并记账。通过返回，超限抛 ErrorCodeException。
     *
     * @param uid    玩家 uid
     * @param server 服务器 id（用于 key 隔离）
     */
    public static void checkAndMark(int uid, int server) throws Exception {
        RedisUtil redis = RedisUtil.getInstence();

        String kDay = server + ":" + dayKey(uid);
        String kTs = server + ":" + tsKey(uid);

        // ---- 1) 最小间隔 ----
        Object lastObj = redis.get(kTs);
        if (lastObj != null) {
            long last;
            try {
                last = Long.parseLong(String.valueOf(lastObj));
            } catch (NumberFormatException e) {
                last = 0L;
            }
            long now = System.currentTimeMillis();
            if (last > 0 && now - last < MIN_INTERVAL_MS) {
                throw new ErrorCodeException(ErrorCode.REWARD_COLLECTING);
            }
        }

        // ---- 2) 每日上限 ----
        long cnt = redis.incr(kDay, 1L);
        // 首次计数时设置 25 小时过期，跨日自动清理
        if (cnt == 1L) {
            redis.expire(kDay, 25L * 60L * 60L);
        }
        if (cnt > MAX_PER_DAY) {
            throw new ErrorCodeException(ErrorCode.REWARD_COLLECTING);
        }

        // 记录本次时间戳
        redis.set(kTs, String.valueOf(System.currentTimeMillis()));
        redis.expire(kTs, 60L * 60L);
    }
}
