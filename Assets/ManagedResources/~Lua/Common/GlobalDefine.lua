--[[
 * @ClassName GlobalDefine
 * @Description 全局变量
 * @Date 2019/5/9 13:56
 * @Created by MagicianJoker
--]]

-- 启用功能引导
ENABLE_FUNC_GUIDE = 1 --0关闭1开启
RECHARGEABLE = true --false不可充值 true可充值
-- 引导类型
GuideType = {
    Force = 1,--强制
    Function = 2 --功能
}

BattleGuideType = {
    FakeBattle = 1,
    QuickFight = 1021,
}

SDKSubMitType = {
    TYPE_SELECT_SERVER = 1,
    TYPE_CREATE_ROLE = 2,
    TYPE_ENTER_GAME = 3,
    TYPE_LEVEL_UP = 4,
    TYPE_EXIT_GAME = 5,
    TYPE_ENTER_COPY = 6,
    TYPE_EXIT_COPY = 7,
    TYPE_VIP_LEVELUP = 8
}

SDK_RESULT = {
    FAILED = 0,
    SUCCESS = 1,
}

SDKCodeResult = {
    CODE_NO_NETWORK = 0,
    CODE_INIT_SUCCESS = 1,
    CODE_INIT_FAIL = 2,
    CODE_LOGIN_SUCCESS = 3,
    CODE_LOGIN_FAIL = 4,
    CODE_LOGIN_CANCEL = 5,
    CODE_AUTH_TOKEN_SUCCESS = 6,
    CODE_AUTH_TOKEN_FAIL = 7,
    CODE_SW_LOGIN_SUCCESS = 8,
    CODE_SW_LOGIN_FAIL = 9,
    CODE_LOGOUT_SUCCESS = 10,
    CODE_LOGOUT_FAIL = 11,
    CODE_PAY_SUCCESS = 12,
    CODE_PAY_FAIL = 13,
    CODE_PAY_CANCEL = 14,
    CODE_PAY_UNKNOWN = 15,
    CODE_PAYING = 16,
    CODE_REAL_NAME_REG_SUC = 17,
    CODE_SHARE_SUCCESS = 18,
    CODE_SHARE_FAIL = 19,
    CODE_SHARE_CANCEL = 20
}
--英雄资质定义
HeroNaturalDef = {
    [1] = "R",
    [2] = "SR",
    [3] = "SSR",
    [4] = "SSR+",
    [5] = "UR",
    [6] = "UR+"
}
--英雄元素定义
HeroElementDef = {
    [1] = GetLanguageStrById(23156),
    [2] = GetLanguageStrById(23157),
    [3] = GetLanguageStrById(23158),
    [4] = GetLanguageStrById(23159),
    [5] = GetLanguageStrById(23160)
}
--英雄职业定义
HeroOccupationDef = {
    [0] = GetLanguageStrById(12123),
    [1] = GetLanguageStrById(12038),
    [2] = GetLanguageStrById(12039),
    [3] = GetLanguageStrById(12040),
    [4] = GetLanguageStrById(12041),
    [5] = GetLanguageStrById(12042)
}
HeroProfessionIndexDef = {
    WuWei = 1,
    TianFa = 2,
    MiFa = 3,
    XuanCe = 4,
    ShengHua = 5
}

--品质框背景图片定义
QualityBgDef = {
    [1] = "cn2-X1_tongyong_daojukuang_01",
    [2] = "cn2-X1_tongyong_daojukuang_02",
    [3] = "cn2-X1_tongyong_daojukuang_03",
    [4] = "cn2-X1_tongyong_daojukuang_04",
    [5] = "cn2-X1_tongyong_daojukuang_05",
    [6] = "cn2-X1_tongyong_daojukuang_06",
    [7] = "cn2-X1_tongyong_daojukuang_07"
}
-- --Hero大卡前面遮罩
-- GetHeroCardQuantityImage = {
--     [1] = "N1_tankcard_tongyong_huise",
--     [2] = "N1_tankcard_tongyong_lvse",
--     [3] = "N1_tankcard_tongyong_lanse",
--     [4] = "N1_tankcard_tongyong_zise",
--     [5] = "N1_tankcard_tongyong_chengse",
--     [10] = "N1_tankcard_tongyong_hongse",
--     [11] = "N1_tankcard_tongyong_hongse",
-- }

--Card背景
X1GetHeroCardBgStarBgImage = {
    [1] = "cn2-X1_tongyong_yingxiongkuangdiban_01",
    [2] = "cn2-X1_tongyong_yingxiongkuangdiban_02",
    [3] = "cn2-X1_tongyong_yingxiongkuangdiban_03",
    [4] = "cn2-X1_tongyong_yingxiongkuangdiban_04",
    [5] = "cn2-X1_tongyong_yingxiongkuangdiban_05",
    [10] = "cn2-X1_tongyong_yingxiongkuangdiban_06",
}

--Card框
X1GetHeroCardFrameStarByImage = {
    [1] = "cn2-X1_tongyong_yingxiongkuang_01",
    [2] = "cn2-X1_tongyong_yingxiongkuang_02",
    [3] = "cn2-X1_tongyong_yingxiongkuang_03",
    [4] = "cn2-X1_tongyong_yingxiongkuang_04",
    [5] = "cn2-X1_tongyong_yingxiongkuang_05",
    [10] = "cn2-X1_tongyong_yingxiongkuang_06",
}

-- GetHeroCardStarImage = {
--     [1] = "r_tongyong_duiwudi",
--     [2] = "r_tongyong_duiwudihong",
--     [3] = "r_tongyong_duiwudizhuanshi",
-- }

-- GetHeroStarImage = {
--     [1] = "N1_img_tongyong_huangxing1",
--     [2] = "ui_1yue",
--     [3] = "t_zhandoukuang_zhuangshixx",
-- }

-- --Hero大卡背景
-- GetHeroCardStarBg = {
--     [1] = "t_chengyuankuang_huise",
--     [2] = "t_chengyuankuang_lvse",
--     [3] = "t_chengyuankuang_lan",
--     [4] = "t_chengyuankuang_zi",
--     [5] = "t_chengyuankuang_huang",
--     [6] = "t_chengyuankuang_hong",
--     [7] = "t_chengyuankuang_hong",
--     [8] = "t_chengyuankuang_hong",
--     [9] = "t_chengyuankuang_hong",
--     [10] = "t_chengyuankuang_hong",
--     [11] = "t_chengyuankuang_zhaunshi",
--     [12] = "t_chengyuankuang_zhaunshi",
--     [13] = "t_chengyuankuang_zhaunshi",
--     [14] = "t_chengyuankuang_zhaunshi",
--     [15] = "t_chengyuankuang_zhaunshi",
--     [16] = "t_chengyuankuang_zhaunshi",
--     [17] = "t_chengyuankuang_zhaunshi",
-- }

-- --Hero大卡背景
-- GetBattleHeroCardStarBg = {
--     [1] = "t_zhandoukuang_huise",
--     [2] = "t_zhandoukuang_lvse",
--     [3] = "t_zhandoukuang_lan",
--     [4] = "t_zhandoukuang_zi",
--     [5] = "t_zhandoukuang_huang",
--     [6] = "t_zhandoukuang_hong",
--     [7] = "t_zhandoukuang_hong",
--     [8] = "t_zhandoukuang_hong",
--     [9] = "t_zhandoukuang_hong",
--     [10] = "t_zhandoukuang_hong",
--     [11] = "t_zhandoukuang_zhuangshi",
--     [12] = "t_zhandoukuang_zhuangshi",
--     [13] = "t_zhandoukuang_zhuangshi",
--     [14] = "t_zhandoukuang_zhuangshi",
--     [15] = "t_zhandoukuang_zhuangshi",
--     [16] = "t_zhandoukuang_zhuangshi",
--     [17] = "t_zhandoukuang_zhuangshi",
-- }

-- --编队没有怒气值Hero大卡背景
-- GetFormationHeroCardStarBg = {
--     [1] = "t_biandui_huise",
--     [2] = "t_biandui_lvse",
--     [3] = "t_biandui_lan",
--     [4] = "t_biandui_zi",
--     [5] = "t_biandui_huang",
--     [6] = "t_biandui_hong",
--     [7] = "t_biandui_hong",
--     [8] = "t_biandui_hong",
--     [9] = "t_biandui_hong",
--     [10] = "t_biandui_hong",
--     [11] = "t_biandui_zhuangshi",
--     [12] = "t_biandui_zhuangshi",
--     [13] = "t_biandui_zhuangshi",
--     [14] = "t_biandui_zhuangshi",
--     [15] = "t_biandui_zhuangshi",
--     [16] = "t_biandui_zhuangshi",
--     [17] = "t_biandui_zhuangshi",
-- }

-- --Hero大卡前面遮罩
-- GetHeroCardStarFg = {
--     [1] = "t_zhandoukuang_huise002",
--     [2] = "t_zhandoukuang_lvse002",
--     [3] = "t_zhandoukuang_lan002",
--     [4] = "t_zhandoukuang_zi002",
--     [5] = "t_zhandoukuang_huang002",
--     [6] = "t_zhandoukuang_hong002",
--     [7] = "t_zhandoukuang_hong002",
--     [8] = "t_zhandoukuang_hong002",
--     [9] = "t_zhandoukuang_hong002",
--     [10] = "t_zhandoukuang_hong002",
--     [11] = "t_zhandoukuang_zhuangshi002",
--     [12] = "t_zhandoukuang_zhuangshi002",
--     [13] = "t_zhandoukuang_zhuangshi002",
--     [14] = "t_zhandoukuang_zhuangshi002",
--     [15] = "t_zhandoukuang_zhuangshi002",
--     [16] = "t_zhandoukuang_zhuangshi002",
--     [17] = "t_zhandoukuang_zhuangshi002",
-- }

-- --Hero大卡装饰
-- GetHeroCardStarZs = {
--     [1] = "",
--     [2] = "",
--     [3] = "",
--     [4] = "",
--     [5] = "",
--     [6] = "t_zhandoukuang_hong01",
--     [7] = "t_zhandoukuang_hong01",
--     [8] = "t_zhandoukuang_hong01",
--     [9] = "t_zhandoukuang_hong01",
--     [10] = "t_zhandoukuang_hong01",
--     [11] = "t_zhandoukuang_zhuanshi01",
--     [12] = "t_zhandoukuang_zhuanshi01",
--     [13] = "t_zhandoukuang_zhuanshi01",
--     [14] = "t_zhandoukuang_zhuanshi01",
--     [15] = "t_zhandoukuang_zhuanshi01",
--     [16] = "t_zhandoukuang_zhuanshi01",
--     [17] = "t_zhandoukuang_zhuanshi01",
-- }

--品质文字描述定义
QualityNameDef = {
    [1] = GetLanguageStrById(10198),
    [2] = GetLanguageStrById(10197),
    [3] = GetLanguageStrById(10196),
    [4] = GetLanguageStrById(10195),
    [5] = GetLanguageStrById(10194),
    [6] = GetLanguageStrById(10193),
    [7] = GetLanguageStrById(10192)
}

--装备类型描述定义
EquipQualityDescDef = {
    [2] = GetLanguageStrById(12110),
    [3] = GetLanguageStrById(12111),
    [4] = GetLanguageStrById(12112),
    [5] = GetLanguageStrById(12113)
}
--装备名字定义
EquipNameDef = {
    [1] = GetLanguageStrById(10427),
    [2] = GetLanguageStrById(12104),
    [3] = GetLanguageStrById(10429),
    [4] = GetLanguageStrById(12105),
    [5] = GetLanguageStrById(12106),
    [6] = GetLanguageStrById(12124)
}
-- --人物品质图标
-- HeroQualityIconDef = {
--     [1] = "r_hero_pinzhi_r",
--     [2] = "r_hero_pinzhi_sr",
--     [3] = "r_hero_pinzhi_ssr",
--     [4] = "r_hero_pinzhi_ssr+",
--     [5] = "r_hero_pinzhi_ur",
--     [6] = "r_hero_pinzhi_ur+"
-- }
-- --资质显示框
-- AptitudeQualityFrame={
--     [1] = "r_hero_zizhilanse",--蓝
--     [2] = "r_hero_zizhizise",--紫
--     [3] = "r_hero_chengse",--橙
--     [4] = "r_hero_hongse",--红
--     [5] = "r_hero_zizhijinse"--金
-- }
--英雄属性筛选
SortTypeConst = {
    Natural = 1, --品阶    ur+ -->  r       6  --> 1
    Lv = 2
}
--英雄属性筛选
ProIdConst = {
    All = 0, --全部
    Fire = 1, --火
    Wind = 2, --风
    Water = 3, --水
    Land = 4, --地
    Light = 5, --光
    Dark = 6, --暗
}

-- ************************************************************************************************************************
-- 战斗模块相关
--编队面板类型（前端用）
FORMATION_TYPE = {
    CARBON = 1,
    STORY = 2,
    MAIN = 3,
    ARENA_DEFEND = 4,
    ARENA_ATTACK = 5,
    ADVENTURE = 6,
    ADVENTURE_BOSS = 7,
    ELITE_MONSTER = 8,
    GUILD_DEFEND = 9,
    GUILD_ATTACK = 10,
    MONSTER_CAMP = 11,
    BLOODY_BATTLE = 12,
    PLAY = 13,                  -- 好友切磋
    ARENA_TOP_MATCH = 14,
    GUILD_BOSS = 15,
    EXPEDITION = 16,
    SAVE_FORMATION = 17,
    GUILD_CAR_DELEAY = 18,      -- 梦魇入侵
    GUILD_DEATHPOS = 19,        -- 公会战
    XUANYUAN_MIRROR = 20,       -- 腐化之战
    CLIMB_TOWER = 21,           -- 神之塔
    GUILD_TRANSCRIPT = 22,      -- 公会副本
    DefenseTraining = 23,       -- 防守训练
    CONTEND_HEGEMONY = 24,      -- 破碎王座
    BLITZ_STRIKE = 25,          -- 遗忘之城
    ALAMEIN_WAR = 26,           -- 迷雾之战
    LADDERSCHALLENGE = 27,      -- 跨服竞技场
    CHAOS_BATTLE = 28,         --混乱之治防守阵容
    CHAOS_BATTLE_ACK = 29,         --混乱之治进攻阵容
}

--编队定义 （与后端相关）
FormationTypeDef = {
    FORMATION_NORMAL = 1,
    FORMATION_ARENA_DEFEND = 101,   -- 竞技场防守阵容
    FORMATION_ARENA_ATTACK = 201,   -- 竞技场进攻阵容
    FORMATION_DREAMLAND = 301,      -- 异端之战
    FORMATION_ENDLESS_MAP = 401,    -- 无尽编队
    FORMATION_GUILD_FIGHT_DEFEND = 501, -- 公会战防守
    FORMATION_GUILD_FIGHT_ATTACK = 502, -- 公会战进攻
    MONSTER_CAMP_ATTACK = 601,  -- 锁妖塔
    BLOODY_BATTLE_ATTACK = 701, -- 血战出征
    GUILD_BOSS = 901,           -- 公会boss
    EXPEDITION = 1001,          -- 猎妖之路
    GUILD_CAR_DELEAY = 1101,    -- 梦魇入侵
    GUILD_DEATHPOS = 1201,      -- 公会战
    ARENA_TOM_MATCH = 1301,     -- 巅峰赛
    CLIMB_TOWER = 1401,         -- 爬塔
    Arden_MIRROR = 1402,        -- 阿登战役
    GUILD_TRANSCRIPT = 1501,    -- 公会副本
    DEFENSE_TRAINING = 1601,    -- 防守训练
    BLITZ_STRIKE = 1701,        -- 闪电出击
    CONTEND_HEGEMONY = 1801,    -- 争霸
    FORMATION_AoLiaoer = 1901,  -- 奥廖尔战役编队
    ALAMEIN_WAR = 1902,         -- 阿拉曼战役
    LADDERS_DEFEND = 1903,      -- 天梯赛防守
    CHAOS_BATTLE = 1904,      -- 混乱之治
    CHAOS_BATTLE_ACK = 1,  --混乱之治进攻
}

BATTLE_TYPE = {
    Test = 0,                   -- 测试战斗 --引导
    BACK = 1,                   -- 战斗回放 --地下竞技场
    MAP_FIGHT = 2,              -- 地图内战斗
    ELITE_MONSTER = 3,          -- 精英怪
    MONSTER_CAMP = 5,           -- 兽潮
    STORY_FIGHT = 6,            -- 关卡
    GUILD_BOSS = 7,             -- 公会BOSS
    EXECUTE_FIGHT = 8,          -- 猎妖之路
    DAILY_CHALLENGE = 9,        -- 日常副本 --异端之战
    GUILD_CAR_DELAY = 10,       -- 梦魇入侵
    DEATH_POS = 11,             -- 公会战
    Senro = 12,                 -- 森罗幻境
    Climb_Tower = 13,           -- 神之塔
    GuildTranscript = 14,       -- 公会副本
    DefenseTraining = 15,       -- 深渊试炼
    BLITZ_STRIKE = 16,          -- 遗忘之城
    CONTEND_HEGEMONY = 17,      -- 争霸
    REDCLIFF = 18,              -- 腐化之战
    ALAMEIN_WAR = 19,           -- 迷雾之战
    LADDERS = 20,               -- 跨服天梯赛
    Climb_Tower_Advance = 21,   -- 魔之塔
    Ladders_Challenge = 22,     -- 跨服竞技场
    PVEActivity = 23,           -- PVE主题活动
    CollectMaterials = 100,     -- 物资收集
}

--排行类型
RANK_TYPE = {
    TRIAL_RANK = 1,                 -- 试炼排行
    FORCE_RANK = 2,                 -- 战力排行
    FIGHT_LEVEL_RANK = 3,           -- 关卡排行
    MONSTER_RANK = 4,               -- 兽潮排行
    FINDFAIRY_RANK = 10,            -- 寻仙积分排行榜
    FINDFAIRY_RECORD = 11,          -- 寻仙榜（记录）
    GUILD_BOSS = 12,                -- 公会Boss进攻日志
    GUILD_REDPACKET = 13,           -- 公会红包排行榜
    GUILD_CAR_DELEAY_SINGLE = 14,   -- 公会车迟个人排行
    GUILD_CAR_DELEAY_GUILD = 19,    -- 公会车迟公会排行
    GUILD_DEATHPOS_PERSON = 15,     -- 十绝阵 各阵 个人排行
    GUILD_DEATHPOS_GUILD = 16,      -- 十绝阵 各阵 公会排行
    GUILD_DEATHPOS_ALLPERSON = 17,  -- 十绝阵 总个人排行
    GUILD_DEATHPOS_ALLGUILD = 18,   -- 十绝阵 总公会排行
    GUILD_FORCE_RANK = 20,          -- 公会
    GOLD_EXPER = 21,                -- 次元引擎个人
    FORCE_CURR_RANK = 22,           -- 实时战力排行
    ARENA_RANK = 23,                -- 竞技场积分排名（前端自己添加）
    XUANYUANMIRROR_RANK = 24,       -- 腐化之战
    GUILDTRANSCRIPT = 26,           -- 公会副本排行
    CLIMB_TOWER = 27,               -- 神之塔
    DEFENSE_TRAINING = 28,          -- 防守训练
    ALAMEIN_WAR = 33,               -- 迷雾之战
    CELEBRATION_GUILD = 32,         -- 次元引擎工会
    CLIMB_TOWER_ADVANCE = 34,       -- 魔之塔
    LADDERSCHALLENGE = 35 ,         -- 跨服竞技场排名
    HERO_FORCE_RANK = 36             -- 英雄战力排行
}
-- ************************************************************************************************************************

BATTLE_TYPE_BACK = {
    BACK_WITH_SB = 0    -- 切磋
}

--英雄属性类型
HeroProType = {
    Hp = 1,                             -- 生命值
    Attack = 2,                         -- 攻击力
    PhysicalDefence = 3,                -- 护甲
    MagicDefence = 4,                   -- 魔抗
    Speed = 5,                          -- 速度
    DamageBocusFactor = 51,             -- 伤害加成百分比
    DamageReduceFactor = 52,            -- 伤害减免百分比
    Hit = 53,                           -- 效果命中率
    Dodge = 54,                         -- 效果抵抗率
    CritFactor = 55,                    -- 暴击率
    CritDamageFactor = 56,              -- 暴伤
    CureFacter = 57,                    -- 受到治疗系数
    TreatFacter = 58,                   -- 治疗系数
    DifferDemonsReduceFactor = 59,      -- 异妖减伤率
    AntiCritDamageFactor = 60,          -- 抗暴率
    MaxHpPercentage = 61,               -- 生命值百分比
    AttackPercentage = 62,              -- 攻击力百分比
    PhysicalDefencePercentage = 63,     -- 护甲百分比
    MagicDefencePercentage = 64,        -- 护甲百分比
    SpeedPercentage = 65,               -- 速度百分比
    -- DifferDemonsBocusFactor = 66,       -- 异妖伤害加成系数
    -- CurHp = 67,
    -- CurHp = 68,
    PVPDamageBocusFactor  = 69, -- PVP增伤
    PVPDamageReduceFactor = 70, -- PVP减伤
    -- FireDamageBonusFactor = 101,        -- 火攻（%）
    -- WindDamageBonusFactor = 102,        -- 风攻（%）
    -- WaterDamageBonusFactor = 103,       -- 水攻（%）
    -- LandDamageBonusFactor = 104,        -- 地攻（%）
    -- LightDamageBonusFactor = 105,       -- 光攻（%）
    -- DarkDamageBonusFactor = 106,        -- 暗攻（%）
    -- FireDamageReduceFactor = 107,       -- 火抗（%）
    -- WindDamageReduceFactor = 108,       -- 风抗（%）
    -- WaterDamageReduceFactor = 109,      -- 水抗（%）
    -- LandDamageReduceFactor = 110,       -- 地抗（%）
    -- LightDamageReduceFactor = 111,      -- 光抗（%）
    -- DarkDamageReduceFaUpctor = 112,     -- 暗抗（%）
    InitRage = 200,                     -- 初始怒气值
    -- CriDamageReduceRate = 150,          -- 暴伤抵抗
    PhysicalAttackIncreaseRate = 151,   -- 物理伤害
    PhysicalDamageReduceRate = 152,     -- 物理减免
    MagicAttackIncreaseRate = 153,      -- 能量伤害
    MagicDamageReduceRate = 154,        -- 能量减免
    ControlRate = 155,                  -- 控制几率
    ControlResistRate = 156,            -- 控制抵抗
    PhysicalRateIncrease = 157,         -- 勇气
    MagicRateIncrease = 158,            -- 信念
    Accurate = 159,             -- 精准
    SkillDamage = 160,          -- 技能伤害
    DamageToMage = 161,         -- 对能量输出伤害
    DamageToFighter = 162,      -- 对物理输出伤害
    DamageToDefender = 163,     -- 对肉盾伤害
    DamageToHealer = 164,       -- 对辅助伤害
    HealCritical = 165,         -- 治疗暴击
    HealCriEffect = 166,        -- 治疗暴击效果
    DefenceFromFighter = 167,   -- 抗物理输出伤害
    DefenceFromMage = 168,      -- 抗能量输出伤害
    DefenceFromDefender = 169,  -- 抗肉盾伤害
    DefenceFromHealer = 170,    -- 抗辅助伤害
    Resilience = 171,           -- 坚韧
    WarPower = 1000,            -- 英雄战斗力（获取英雄属性时会用到）
}

-- 支援改造10属性
SupportRemouldSysMap = {
    HeroProType.Speed,
    HeroProType.Hit,
    HeroProType.Dodge,
    HeroProType.CritFactor,
    HeroProType.CritDamageFactor,
    HeroProType.AntiCritDamageFactor,
    HeroProType.MaxHpPercentage,
    HeroProType.AttackPercentage,
    HeroProType.ControlRate,
    HeroProType.ControlResistRate,
}

-- 转表类型
HeroLvUpBaseValue = {
    [HeroProType.Hp] = "Hp",
    [HeroProType.Attack] = "Attack",
    [HeroProType.PhysicalDefence] = "PhysicalDefence",
    [HeroProType.Speed] = "Speed",
}
HeroBreakStarUpBaseValue = {
    [HeroProType.Hp] = "Hp",
    [HeroProType.Attack] = "Atk",
    [HeroProType.PhysicalDefence] = "Def",
    [HeroProType.Speed] = "Speed",
}
HeroLvUpRate = {
    [HeroProType.Hp] = "Hp_rate",
    [HeroProType.Attack] = "Atk_rate",
    [HeroProType.PhysicalDefence] = "Def_rate",
    [HeroProType.Speed] = "Speed_rate",
}
HeroBreakStarUpRate = {
    [HeroProType.Hp] = "HpRate",
    [HeroProType.Attack] = "AtkRate",
    [HeroProType.PhysicalDefence] = "DefRate",
    [HeroProType.Speed] = "SpeedRate",
}

-- 异妖图片资源
DiffMonsterIconDef = {
    [1] = "yy-tujian-dlg",  -- 刀捞鬼
    [2] = "yy-tujian-zlg",  -- 蒸笼仔
    [3] = "yy-tujian-hg",   -- 横公
    [4] = "yy-tujian-jhj",  -- 拘魂姬,
    [5] = "yy-tujian-hs",   -- 火鼠
    [6] = "yy-tujian-lms",  -- 拦面叟
    [7] = "yy-tujian-sl",   -- 孙龙
    [8] = "yy-tujian-md",   -- 陌刀
    [9] = "yy-tujian-fl",   -- 风狸
    [10] = "yy-tujian-tl"   -- 天麟
}

--包含BtnView面板类型定义
PanelTypeView = {
    RolePanel = 1,           -- 主角选择按钮群
    MemberPanel = 2,         -- 成员面板
    DiffMonsterPanel = 3,    -- 异妖面板
    SecretTerritoryPanel = 4,-- 秘境界面
    BagPanel = 5,            -- 背包面板
    RecruitPanel = 6,        -- 招募面板
    PartyPanel = 7,          -- 公会面板
    ElementDrawCardPanel = 8,-- 元素抽卡
    MainCity = 9,            -- 主城
    JieLing = 10,            --（新关卡）
    Talent = 11,             -- 天赋
    Carbon = 12,             -- 副本
    GongHui = 13,            -- 公会
    TeQuan = 14,             -- 特权
    HandBook = 15,           -- 图鉴
    StageMap = 16,           -- 章节地图
    SupportPanel = 17,       -- 支援主界面
    AdjutantPanel = 18,      -- 副官
    AlameinWarPanel = 19,    -- 阿拉曼战役
    Logistics = 20,          -- 后勤
    AircraftCarrier = 21,    -- 航母
}
--包含BtnView面板类型定义
PanelTypeView2 = {
    DevelopPanel = 1, -- 养成面板
	TalentPanel = 2,  -- 戒灵天赋面板
    HandBookPanel = 3,-- 图鉴面板
    FriendPanel = 4,  -- 好友界面
    Achievement = 5,  -- 成就面板
    SettingPanel = 6, -- 设置面板
    StageMap = 7,     -- 章节地图
}

PanelType = {
    Main = { 14, 16 },                  -- 
    RoleInfo = { 14, 3, 4 },            -- 信息
    FightPointPass = { 14, 16 },        -- 挂机界面
    SoulCrystal = { 14, 16   },         -- 魂晶
    Recruit = { 91, 69 ,19, 16 },       -- 抽卡
    ElementDrawCard = { 14, 74, 20},    -- 元素神戒（元素招募）
    SecretBox = { 16, 22, 21 },         -- 妖魂魔戒（秘盒开启）
    Arena = { 16, 23 },                 -- 竞技场挑战券
    HeartFireStone = { 14, 16, 26 },    -- 心火明晶
    Carbon = { 14, 16, 27 },            -- 普通副本挑战券
    EliteCarbon = { 14, 16, 28 },       -- 精英副本挑战券
    AdventureTimes = { 14, 16, 44 },    -- 外敌挑战券
    TrialCoin = { 14, 16, 45 },         -- 试炼币
    LightRing = { 15, 46 },             -- 光辉灵界
    IronResource = { 14, 16, 1001 },    -- 铁矿石
    requiem = { 14, 16, 29 },           -- 宝魂
    FixforDan = { 14, 16, 1002 },       -- 修为丹
    StarSoul = { 14, 16, 66 },          -- 星魂
    DiffMonster = { 16, 6, 5 },         -- 异妖
    -- SoulContractShop = StoreTypeConfig[1].ResourcesBar,     -- 契魂商店
    -- GeneralShop = StoreTypeConfig[2].ResourcesBar,          -- 杂货商店
    -- RoamShop = StoreTypeConfig[3].ResourcesBar,             -- 云游商店
    ArenaShop = {14, 16, 24},--StoreTypeConfig[4].ResourcesBar,            -- 竞技场商店
    -- SecretBoxShop = StoreTypeConfig[6].ResourcesBar,        -- 秘盒商店
    -- TrialShop = StoreTypeConfig[8].ResourcesBar,            -- 试炼商店
    -- ActivityShop = StoreTypeConfig[11].ResourcesBar,        -- 活动商店
    -- GuildShop = StoreTypeConfig[12].ResourcesBar,           -- 公会商店
    -- EndLessShop = StoreTypeConfig[13].ResourcesBar,         -- 无尽商店
    -- SoulPrintShop = StoreTypeConfig[14].ResourcesBar,       -- 魂印商店
    -- FriendShop = StoreTypeConfig[17].ResourcesBar,          -- 友情商店
    -- ChoasShop = StoreTypeConfig[19].ResourcesBar,           -- 混沌商店
    -- TopMatchShop = StoreTypeConfig[21].ResourcesBar,        -- 巅峰赛商店
    MonsterCamp = { 14, 16},         -- 兽潮
    HeroReturn = { 14, 16},          -- 回溯{ 14, 16, 70},
    LuckyTreasure = { 60, 61},       -- 幸运探宝
    AdvancedTreasure = { 60, 61},    -- 高级探宝
    ExChange = { 14, 16, 67},        -- 显示兑换
    GoodFriend = {14, 69},           -- 好友
    SoulPritResolve = { 14, 16},     -- 魂印分解
    TopMatch = { 14, 16, 24},        -- 巅峰赛界面
    FindFairy = { 87, 16, 15},       -- 东海寻仙
    Talisman = {14},                 -- 新法宝
    Guild = {14, 65},                -- 公会
    TimelimitCall = {50007,16},      -- 限时召唤
    QianKunBox = {1002, 1003},       -- 神秘盲盒
    StageMap = {14, 3},              -- 章节地图
    SupportPanel = {14, 3},          -- 支援主界面
    AdjutantPanel = {14, 3},         -- 副官
    AlameinWarPanel = {14, 3},       -- 阿拉曼战役
    Logistics = {14, 3},             -- 后勤
    AircraftCarrier = {14, 3},       -- 航母
    HeroReplace = {14, 16, 92},      -- 神将置换
    recall = {14, 16, 18101, 18102}, -- 改装厂回溯
    CountryDraw = {14, 16, 20, 74},  -- 阵营抽卡
    YiJingBaoKu = {1004, 16},        -- 易经宝库
    ShenMiMangHe = {14, 16, 1003},   -- 神秘盲盒
    CiYuanYinQinG = {14, 16, 97},    -- 次元引擎
    QiMingXingKeJi = {16, 200010},   -- 启明星科技
    laddersChallenge = {14, 16, 103},-- 跨服竞技
    Chat = {14, 16, 6000126},        -- 聊天
    AdjutantRecruitPanel = {16, 6000115},   -- 先驱主题活动
    HeroMain = {16, 3},             -- 信息
    BoxPool = {16, 50004},          -- 扭蛋
    BoxPool_2 = {16, 50006},        -- 扭蛋_2
    CardActivity = {16, 50005},     -- 卡牌主题活动
}

--UpView打开类型
UpViewOpenType = {
    ShowLeft = 1,   --只打开左侧
    ShowRight = 2,  --只打开右侧
    ShowAll = 3,    --左右都打开
}

--UpView充值类型
UpViewRechargeType = {
    ActPower = 1,           -- 行动力
    Energy = 2,             -- 体力
    GrowthAmulet = 3,       -- 成长护符
    Yaoh = 4,               -- 梦魔妖壶
    Panacea = 5,            -- 灵丹
    JYD = 6,                -- 归元髓液
    Treasure = 7,           -- 寻宝积分
    HitOut = 8,             -- 出击积分
    Gold = 14,              -- 金币
    SoulCrystal = 15,       -- 魂晶
    DemonCrystal = 16,      -- 钻石
    SpiritTicket = 19,      -- 聚灵券
    MysteriousMoney = 20,   -- 玄冥宝钞
    GhostRing = 21,         -- 妖魂魔戒
    SpiritJade = 22,        -- 妖灵玉
    ChallengeTicket = 23,   -- 挑战券
    BadgeGlory = 24,        -- 荣耀徽章
    StarFireBuLingStone = 26,   -- 星火明晶
    OrdinaryCarbonTicket = 27,  -- 普通副本入场券
    EliteCarbonTicket = 28,     -- 精英副本入场券
    XingYao = 31,           -- 回春散
    AdventureAlianInvasionTicket = 44, -- 外敌挑战券
    LightRing = 46,         -- 光辉灵戒
    HourGlass = 47,         -- 时光沙漏
    MonsterCampTicket = 53, -- 兽潮入场券
    LuckyTreasure = 60,     -- 幸运探宝
    AdvancedTreasure = 61,  -- 高级探宝
    ChangeNameCard = 64,    -- 改名卡
    GuildToken = 65,        -- 军团贡献
    StarSoul = 66,          -- 星魂
    ChinaHas = 67,          -- 神州令
    FriendPoint = 69,       -- 友情点
    ChoasCoin = 74,         -- 混沌玉
    TopMatchCoin = 86,      -- 至尊之证
    FindFairy = 87,         -- 寻仙玉
    SummonStamps = 91,      -- 召唤券
    ExchangeOfLicenses = 92,-- 交换许可证
    Fight = 96,             -- 作战积分
    Cross = 97,             -- 跨服积分
    War = 98,               -- 战役积分
    LaddersChallenge = 103, -- 跨服积分
    Iron = 1001,            -- 铁矿石
    FixforDan = 1002,       -- 修为丹
    Medal = 10444,          -- 勋章积分
    WarWay = 6000110,       -- 战法
    Intelligence = 200010,  -- 情报
    Part = 50003,           -- 神秘零件
    Adjutantship = 6000114, -- 副官证
    GeneralRecycle = 18101, -- 普通回溯
    AdvancedRecycle = 18102,-- 高级回溯
    WishCross = 1004,       -- 愿望十字
    YunYouVle = 1008,
    ChatHorn = 6000126,     -- 跨服聊天喇叭
}

SHOP_PAGE = {
    RECHARGE = 1,   -- 充值
    GENERAL = 2,    -- 杂货
    COIN = 3,       -- 代币
    PLAY = 4,       -- 玩法
    EXCHANGE = 5,   -- 兑换
    ROAM = 6,       -- 云游
    SOULBOX = 7,    -- 宝囊
}
SHOP_TYPE = {
    SOUL_CONTRACT_SHOP = 1, -- 契魂商店
    GENERAL_SHOP = 2,       -- 杂货商店
    ROAM_SHOP = 3,          -- 云游商店
    ARENA_SHOP = 4,         -- 竞技场商店
    SOUL_STONE_SHOP = 5,    -- 魂晶商店
    SECRET_BOX_SHOP = 6,    -- 秘盒商店
    FUNCTION_SHOP = 7,      -- 功能购买商店
    TRIAL_SHOP = 8,         -- 试炼副本商店
    SEVENDAY_CARNIVAL_SHOP = 10,    -- 七日狂欢商店
    ACTIVITY_SHOP = 11,     -- 活动商店
    GUILD_SHOP = 12,        -- 公会商店
    ENDLESS_SHOP = 13,      -- 无尽商店
    SOUL_PRINT_SHOP = 14,   -- 每日礼包
    EXPEDITION_SHOP = 15,   -- 
    FRIEND_SHOP = 17,       -- 特权商店
    NOVICE_GIFT_SHOP = 18,  --
    CHOAS_SHOP = 19,        -- 
    -- FREE_GIFT = 29,         -- 
    DAILY_GIFT = 30,        -- 每日礼包
    WEEK_GIFT = 31,         -- 每周礼包
    MONTH_GIFT = 32,        -- 月礼包
    FREE_GIFT = 33,         -- 商店每日免费礼包
    FINDTREASURE_GIFT = 34, -- 寻宝特权礼包
    VIP_GIFT = 20,          -- 成长礼包（原特权等级礼包）
    TOP_MATCH_SHOP = 21,    -- 
    FINDFAIRY_GIFT = 22,    -- 寻仙限时礼包
    BUYCOIN_SHOP = 57,      -- 点金商店
    QIANKUNBOX_SHOP = 58,   -- 宝囊限时商店

    -- 与StoreType 对应
    ITEM_SHOP               = 59,   -- 道具
    BLITZ_STRIKE            = 60,   -- 闪电出击
    FINDTREASURE_SHOP       = 61,   -- 寻宝
    COMBATPLAN_SHOP         = 62,   -- 作战
    WARWAY_SHOP             = 63,   -- 战法
    HIGHLADDER_SHOP         = 64,   -- 天梯

    CELEBRATION_SHOP        = 65,  -- 次元引擎商店
    INVESTIGATE_SHOP        = 100, -- 情报商店
    GROWTHFREE_GIFT = 500   -- 成长礼金每日免费礼包
}

-- StoreTypeConfig Pages
SHOP_INDEPENDENT_PAGE = {
    CLIMB_ADVANCE = 16, -- 精英模拟战
}

SHOP_INDEPENDENT_PAGE_NAME = {
    [16] = GetLanguageStrById(50260), -- 精英模拟战
}

PropertyTypeIconDef = {
    [1] = "cn2-x1_TB_shuxing_shengming",
    [2] = "cn2-x1_TB_shuxing_gongji",
    [3] = "cn2-x1_TB_shuxing_fangyu",
    [4] = "r_hero_kangxing",
    [5] = "cn2-x1_TB_shuxing_sudu",
}

RedPointType = {
    --服务器推送部分
    Mail_Server = 1,
    SecretTer_Boss = 2,
    Arena_Record = 3,   -- 竞技场防守记录
    Guild_Apply = 4,    -- 公会申请信息红点

    --本地存储部分
    Bag = 101,          -- 背包
    DiffMonster = 102,  -- 异妖
    -- SecretBox = 103,    -- 秘盒
    Guild = 104,        -- 公会
    ----戒灵相关-----
    --JieLing = 105,    -- 主界面戒灵按钮
    NewFight = 1005,    -- 新关卡
    Refining = 106,     -- 工坊
    Arena = 107,        -- 竞技场
    -- Adventure = 108,    -- 冒险
    ----活动相关----
    CourtesyDress = 109,-- 开服有礼
    Expert = 110,       -- 限时活动
    WarPowerSort = 111, -- 战力排行
    RankingSort = 112,  -- 排行榜
    ----副本相关------
    ExploreMain = 114,              -- 主界面副本探索
    ForgottenCity = 115,            -- 遗忘之城
    HeroExplore = 116,              -- 物资收集
    EpicExplore = 117,              -- 深渊试炼
    EpicExplore_LevleReward = 11701,-- 深渊试炼章节奖励
    EpicExplore_MoppingUp = 11702,  -- 深渊试炼免费挑战次数
    LegendExplore = 118,            -- 破碎王座
    -- EndLess = 119,                  -- 迷雾之战
    -- EndlessPanel = 1191,            -- 迷雾之战界面红点
    BattleOfFog = 119,              -- 迷雾之战
    Trial = 121,                    -- 森罗幻境
    TrialReward = 1211,             -- 森罗任务
    -- 充值
    Recharge = 120,
    RightUp2 = 122,--主界面右上角伸缩条

    ----礼包相关------
    Operating = 201,            -- 运营（主界面礼包）
    CumulativeSignIn = 202,     -- 累计签到
    GrowthGift = 203,           -- 成长礼金
    ContinuityRecharge = 204,   -- 连续充值
    VipPrivilege = 205,         -- 特权
    SevenDayCarnival = 206,     -- 七日狂欢
    DynamicActivity = 208,      -- 轮转活动 乾坤宝盒 限时召唤
    GiftPage = 2011,            -- 礼包
    DailyGift = 2012,           -- 每日礼包
    HERO_STAR_GIFT = 2013,      -- 星级礼包
    NobilityMonthCard = 2014,   -- 贵族月卡
    KingMonthCard = 20141,      -- 王者月卡
    GrowthPackage = 2015,       -- 成长礼包！(和礼金区分)
    QianKunBox = 2016,          -- 神秘盲盒
    DynamicAct = 2017,          -- 破阵诛仙
    DynamicActTask = 20171,     -- 主题活动
    DynamicActRecharge = 20172, -- 主题活动累充
    EveryWeekPreference = 2018, -- 每周特惠
    EveryMonthPreference = 2019,-- 每月特惠
    Celebration = 2020,         -- 次元引擎
    YiJingBaoKu = 2021,         -- 厄里斯魔镜
    LingShouBaoGe = 2022,       -- 灵兽宝阁
    XinJiangLaiXi = 2023,       -- 新将来袭
    XiangYaoDuoBao = 2024,      -- 降妖夺宝
    ShengXingYouLi = 2025,      -- 升星有礼
    EightTheLogin = 2026,       -- 八日登录
    MunitionsMerchant = 2027,   -- 旅行商人
    NiuQiChongTian = 20260,     -- 极限突破任务
    NiuQiChongTian_1 = 20261,   -- 任务页签1
    NiuQiChongTian_2 = 20262,   -- 任务页签2
    NiuQiChongTian_3 = 20263,   -- 任务页签3
    NiuQiChongTian_4 = 20264,   -- 进度奖励
    FuXingGaoZhao = 2027,       -- 福星高照
    FifteenDayGift = 2028,      -- 十五日登录
    FifteenDayGift_1 = 20281,   -- 十五日登录领取按钮
    ---聊天相关-----
    Chat = 207,
    Chat_Friend = 2070,

    ---主角相关-----
    Role = 220,     -- 主角红点
    Talent = 221,   -- 天赋戒灵
    --养成
    --英雄tab
    HeroTab=225,
    --图鉴
    Friend = 230,   -- 好友
    --成就

    --设置
    Setting = 231,

    FirstRecharge = 233,    -- 首充
    SupremeHero = 234,      -- 剑影仙踪
    LuckyTurn = 235,        -- 幸运探宝
    FindFairy = 236,        -- 东海寻仙
    ---主界面按钮
    DailyTaskMain = 251,
    DailyTask = 252,
    Shop = 253,
    Mail = 254,             -- 邮件
    SecretTer = 255,        -- 秘境
    TreasureOfSl = 256,     -- 成长手册
    ----招募相关------
    SecretBox = 257,        -- 秘盒
    Recruit = 258,          -- 招募
    DailyRecharge = 259,    -- 每日首充
    --- 外敌-------------
    Alien = 260,
    --超值基金
    SpecialFunds = 261,
    ---招财猫
    LuckyCat = 300, --招财猫红点(福星高照)
    ----- upview------------
    UpView_Gold = 301,

    --- 竞技场类型红点
    Arena_Type_Normal = 1070,
    --Arena_Type_TopMatch = 1071,
    --- 竞技场相关子红点
    Arena_Shop = 10701,
    --- 主界面商店大页签红点
    Shop_Page_Recharge = 2530,
    Shop_Page_General = 2531,
    Shop_Page_Coin = 2532,
    Shop_Page_Play = 2533,
    --Shop_Page_Exchange = 2534,
    Shop_Page_Roam = 2535,
    ---=== 商店小页签
    --Shop_Tab_Recharge = 25300,
    Shop_Tab_General = 25310,
    --Shop_Tab_Soul = 25320,
    Shop_Tab_Secret = 25321,
    Shop_Tab_Arena = 25330,
    Shop_Tab_Guild = 25331,
    Shop_Tab_Roam = 25350,
    ---========= 商店红点
    Shop_General_Check = 253100,
    -- Shop_General_Refresh = 253101,
    Shop_Secret_Check = 253200,
    Shop_Arena_Check = 253300,
    Shop_Guild_Check = 253310,
    Shop_Roam_Check = 253500,
    Shop_SoulBox_Check = 254000,

    --- 特权红点
    VIP_SHOP_DETAIL = 10086, -- 特权详情按钮

    --- 工坊相关子红点
    Refining_Weapon = 1060,
    Refining_Armor = 1061,

    --- 邮件子红点 ----
    Mail_Local = 2540,

    --- 秘境子红点 ----
    SecretTer_Uplevel = 2550,
    --SecretTer_GetAllReward = 2551,
    SecretTer_MaxBoxReward = 2552,
    SecretTer_NewHourseOpen = 2553,
    SecretTer_CallAlianInvasionTime = 2554,
    SecretTer_HaveFreeTime = 2555,
    SecretTer_IsCanFight = 2556,
    --- 剧情副本子红点 ----
    NormalExplore_OpenMap = 1150,
    NormalExplore_GetStarReward = 1151,
    --- 试炼副本子红点 ----
    -- EpicExplore_OpenCarbon = 1170,
    -- EpicExplore_GetReward = 1171,
    --- 精英副本子红点 ----
    -- HeroExplore_OpenMap = 1160,
    -- HeroExplore_Feats = 1161,
    --- 秘盒子红点 ----
    SecretBox_Red1 = 2570,
    Recruit_Red = 2571,         -- 神将召唤红点
    Recruit_Normal = 2572,      -- 普通招募红点
    RecruitTen_Red = 2573,      -- 神将召唤红点
    RecruitTen_Normal = 2574,   -- 普通招募红点
    --- 开服福利红点 ----
    CourtesyDress_Online = 1090,
    CourtesyDress_SevenDay = 1091,
    CourtesyDress_Chapter = 1092,
    SecretTer_FindTreasure = 1093,
    --- 好友红点 -----
    Friend_Reward = 2301,       -- 好友赠送体力红点
    Friend_Application = 2302,  -- 好友申请红点
    --- 设置界面红点 ----
    Setting_Head = 2311,
    --- 头像改变界面红点 ------
    HeadChange_Frame = 23111,
    HeadChange_Head = 23112,
    --- 限时达人红点 ----
    Expert_AdventureExper = 3110,   -- 秘境达人
    Expert_AreaExper = 3111,        -- 竞技达人
    Expert_UpStarExper = 3109,      -- 进阶达人
    Expert_EquipExper = 3112,       -- 装备达人
    Expert_GoldExper = 3113,        -- 点金达人
    Expert_FightExper = 3114,       -- 副本达人
    Expert_EnergyExper = 3115,      -- 体力达人
    Expert_Talisman = 3116,         -- 法宝达人
    Expert_SoulPrint = 3117,        -- 魂印达人
    Expert_AccumulativeRecharge = 3107,-- 累计充值
    Expert_FindTreasure = 3119,     -- 寻宝达人
    Expert_LuckyTurn = 3120,        -- 探宝达人
    Expert_Recruit = 3121,          -- 征募达人
    Expert_SecretBox = 3122,        -- 秘宝达人
    Expert_UpLv = 3123,             -- 充值限量礼包
    Expert_Heresy = 3127,           -- 异端克星
    -- Expert_LuckyTurn = 1118,        -- 秘宝达人
    Expert_WeekCard = 3150,         -- 周卡
    -- 战力排行 达标战力
    WarPowerSort_Sort = 3151,       -- 达标战力
    --- 招财猫子红点 ----
    LuckyCat_GetReward = 3000,      -- 招财猫抽取子红点
    --背包子红点
    Bag_HeroDebris = 1011,          -- 可合成碎片
    Bag_BoxAndBlueprint = 1012,     -- 蓝图或宝箱可使用

    --- 公会红点
    Guild_House = 1040,
    Guild_House_Apply = 10402,
    Guild_Shop = 1041,
    Guild_Boss = 1042,
    Guild_RedPacket = 1043,
    Guild_Fete = 1044,
    -- Guild_CarDeleay = 1045,
    Guild_Aid = 1046,
    Guild_AidMy = 1047,
    Guild_AidGuild = 1048,
    Guild_AidBox = 1049,
	Guild_Skill = 1050,
    Guild_DeathPos = 1051,
    Guild_Transcript = 1052,
    Guild_Active = 1053,-- todo
    Guild_Member = 1054,-- todo
    Guild_RedBag = 1055,-- todo
    --东海寻仙
    FindFairy_OneView = 2361,   -- 东海寻仙主界面
    FindFairy_ThreeView = 2362, -- 东海寻仙进阶赠礼
    FindFairy_FourView = 2363,  -- 东海寻仙寻仙盛典
    --成就面板
    Achievement_Main = 9000,    -- 成就
    -- Achievement_One = 9001,     -- 成就 玩家等级
    -- Achievement_Two = 9002,     -- 成就 通关
    -- Achievement_Three = 9003,   -- 成就 副本
    -- Achievement_Four = 9004,    -- 成就 兽潮
    -- Achievement_Five = 9005,    -- 成就 竞技

    --大闹天宫
    Expedition = 9100,          -- 副本界面
    Expedition_Treasure = 9101, -- 天宫秘宝按钮

    TimeLimited = 10001,        -- 限时召唤

    Magic_Mirror = 10002,       -- 妖灵宝镜
    People_Mirror = 10003,      -- 人杰宝镜
    Buddhist_Mirror = 10004,    -- 佛禅宝镜
    Taoist_Mirror = 10005 ,     -- 道玄宝镜

    QinglongSerectTreasure = 10007, --成长手册
    QinglongSerectTreasureTrail = 10008,

    --守护
    -- Support_Gift = 2200,  -- 领取奖励
    Support = 2201,       -- 守护
    
    -- Support_LevelUp = 2202, -- 守护等级升级
    -- Support_Skill = 2203,   -- 守护技能
    -- Support_Remould = 2204, -- 守护改造

    -- Support_LevelUpBtn = 2205, -- 守护等级升级按钮
    -- Support_SkillBtn = 2206,   -- 守护技能按钮
    -- Support_RemouldBtn = 2207, -- 守护改造按钮

    --税收免费领取
    Revenue_Free = 2300, --税收免费领取

    --先驱
    Adjutant = 2400,
    Adjutant_FreeButton = 2401, -- 免费按钮
    Adjutant_Gift = 2402,       -- 领取奖励提示
    Adjutant_Btn_Chat = 2403,   -- 沟通按钮
    Adjutant_Btn_Skill = 2404,  -- 技能按钮
    Adjutant_Btn_Handsel = 2405,-- 礼物按钮
    Adjutant_Btn_Teach = 2406,  -- 特训按钮

    Adjutant_Btn_ChatChildO = 2407,     -- 沟通子按钮
    Adjutant_Btn_ChatChildT = 2408,     -- 沟通子按钮
    Adjutant_Btn_SkillChild = 2409,     -- 技能子按钮
    Adjutant_Btn_HandselChild = 2410,   -- 礼物子按钮
    Adjutant_Btn_TeachChild = 2411,     -- 特训子按钮

    BattlePassMission = 2500, --女娲手札红点
    Logistics = 10006,                      -- 后勤

    -- AircraftCarrier = 101001,               -- 航母
    -- AircraftCarrier_Plane = 101002,
    -- AircraftCarrier_CV = 101003,
    -- AircraftCarrier_CV_Plane1 = 101004,
    -- AircraftCarrier_CV_Plane2 = 101005,
    -- AircraftCarrier_CV_Plane3 = 101006,
    -- AircraftCarrier_CV_Plane4 = 101007,
    -- AircraftCarrier_CV_LvUp = 101008,
    -- AircraftCarrier_Plane_Normal = 101009,
    -- AircraftCarrier_Plane_Privilege = 101010,
    -- AircraftCarrier_Plane_Factory = 101011,
    -- AircraftCarrier_Plane_Speed = 101012,

    -- 战令
    WarOrder_Abyss = 99883,                 -- 深渊
    WarOrder_DenseFog = 99884,              -- 迷雾
    WarOrder_Heresy = 99885,                -- 异端
    WarOrder_MagicTower = 99886,            -- 魔之塔
    WarOrder_Tower = 99887,                 -- 神之塔
    WarOrder = 99888,                       -- 战令
    -- 混乱之治
    Chaos_MainIcon = 99891,                 -- 混乱之治主城icon红点
    Chaos_Tab_Chanllege = 99892,            -- 混乱之治页签红点
    Chaos_Task = 99882,                     -- 混乱之治阵营指令红点
    -- 主角
    Lead = 99893,
    Lead_Assembly = 99898,                  -- 主角装配技能
    Lead_Normal = 99897,                    -- 主角普通研发
    Lead_Privilege = 99878,                 -- 主角特权研发
    Lead_UpLv = 99895,                      -- 主角升级
    Lead_SpeedLvUp = 99894,                 -- 主角研发速度升级
    OpenServiceShop = 99879,                -- 开服热卖
    IncentivePlan = 99881,                  -- 激励计划
    EightTheLogin_2 = 99880,                -- 每日赠礼
    GuildBattle = 99896,                    -- 公会战
    GuildBattle_FreeTime = 99889,           -- 公会战免费挑战
    GuildBattle_BoxReward = 99890,          -- 公会战宝箱
    PVEStarReward = 99899,                  -- PVE星数奖励
    Championships = 99900,                  -- 锦标赛
    Championships_Rank = 99901,             -- 锦标赛排行点赞
    -- 卡牌主题活动
    CardActivity = 99965,
    CardActivity_Haoli = 99961,
    CardActivity_Collect = 99962,
    CardActivity_Task = 99963,
    CardActivity_Draw = 99964,
    -- 先驱主题活动
    AdjutantActivity = 99966,
    AdjutantActivity_Challenge = 99967,     -- 先驱主题活动挑战
    RankReward = 99968,                     -- 排行榜奖励 
    WeekCard = 99969,                       -- 周卡
    WeekendWelfare = 99970,                 -- 周末福利红点
    -- 终身特权
    LifeMemeber = 99973,
    LifeMemeberEveryDay = 99971,            -- 终身特权每日奖励
    LifeMemeberFree = 99972,                -- 终身特权免费
    SuperLiftMemberEveryDay = 99902,        -- 超级终身特权每日奖励
    SuperLiftMemberFree = 99903,            -- 超级终身特权免费
    SuperLiftMember = 99904,                -- 超级终身特权
    BoxPoolFreeTime = 99974,                -- 扭蛋免费
    BoxPoolCanDraw = 99895,                 -- 扭蛋是否可以抽取
    BoxPool = 99894,                        -- 扭蛋
    VipPanel = 99975,                       -- vip
    BlackShop = 99976,                      -- 黑市
    OpenService = 99977,                    -- 开服双倍
    LineupRecommend = 99978,                -- 阵容推荐红点
    ThousandDraw = 99979,                   -- 千抽
    ArenaTodayAlreadyLike = 99980,          -- 竞技场点赞
    ClimbSeniorTowerReward = 99981,         -- 魔之塔奖励
    BattleOfHeresy = 99982,                 -- 异端之战
    WarOfCorruption = 99983,                -- 腐化之战
    NightmareInvasion = 99984,              -- 梦魇入侵
    ValuePack = 99985,                      -- 超值礼包
    LaddersChallenge = 99986,               -- 跨服竞技场
    General = 99987,                        -- 契约
    PatFace = 99988,                        -- 拍脸
    QuickTrain = 99989,                     -- 快速训练
    ResearchInstitute_EquipCompound = 99990,-- 研究所装备合成
    ResearchInstitute_RingCompound = 99991, -- 研究所戒指合成
    ResearchInstitute = 99992,              -- 研究所
    SpaceTimeBattlefield = 99993,           -- 时空战场
    ClimbTower = 99994,                     -- 神之塔
    ClimbTowerFreeTime = 99995,             -- 神之塔免费扫荡
    ClimbTowerReward = 99996,               -- 神之塔奖励
    Culturalrelics = 99997,                 -- 文明遗迹
    MainCity = 99998,                       -- 主城
    TempNull = 99999,                       -- 临时红点用 
}

RedPointStatus = {
    Hide = 0, --隐藏状态
    Show = 1, --显示状态
}
ItemType = {
    --0无特殊分类，1角色，2角色碎片，3装备，4异妖配件，5随机道具，6符文, 7蓝图，8铁矿石，9天赋材料，10宝箱，11头像框，12改名卡，13魂印，14法宝，17皮肤，18坐骑，19宝器）
    NoType = 0,         --无特殊分类
    Hero = 1,           --角色
    HeroDebris = 2,     --角色碎片
    Equip = 3,          --装备
    Pokemon = 4,        --
    RandomItem = 5,     --
    Rune = 6,           --基因
    Blueprint = 7,      --
    IronOre = 8,        --
    TalentItem = 9,     --
    Box = 10,           --宝箱
    HeadFrame = 11,     --头像框
    ChangeName = 12,    --改名卡
    HunYin = 13,        --
    Talisman = 14,      --
    Head = 15,          --头像 框
    Title = 16,         --称号
    Skin = 17,          --
    Ride = 18,          --
    EquipTreasure = 19, --
    SelfBox = 20,       --自选宝箱
    CombatPlan = 21,    --戒指
    medal = 22,         --芯片
    Gene = 24,          --基因
}
YaoHunFrame = {
    --[6] = "r_tongyong_yaohunkuang002",
    --[7] = "r_tongyong_yaohunkuang001",
    [6] = "r_characterbg_gules",
    [7] = "t_tongyong_topkaung",
}
--特权任务状态
VipTaskStatusDef = {
    NotFinished = 0,
    CanReceive = 1,
    Received = 2,
}
TaskStatusDef = {
    NotFinished = 0,
    NotGet = 1,
    Finished = 2,
}
TaskStateRankDef = {
    [0] = 2,
    [1] = 1,
    [2] = 3
}
--特权观看状态
VipShowStatusDef = {
    Current = 1, --当前
    LevelUp = 2, --可升级
    Preview = 3, --预览
}
--特权奖励领取状态
GiftReceivedStatus = {
    NotReceive = 0,
    Received = 1,
}
--特权领取类型
GiftReceivedType = {
    LevelGift = 1,
    DailyGift = 2,
}

--品质文字颜色
QualityTextDef = {
    [1] = "#FFFFFFFF",--白色
    [2] = "#97FEC5FF",--绿色
    [3] = "#76ABECFF",--蓝色
    [4] = "#B677DAFF",--紫色
    [5] = "#F6934AFF",--橙色
}

-- 通用UI颜色色值
UIColor = {
    WHITE = Color.New(1, 1, 1, 1),
    WHITETOGRAY = Color.New(1, 1, 1, 0.6),
    GRAY = Color.New(0.5, 0.5, 0.5, 1),
    RED = Color.New(226 / 255, 91 / 255, 88 / 255, 1),
    GREEN = Color.New(87 / 255, 200 / 255, 138 / 255, 1),
    YELLOW = Color.New(232 / 255, 181 / 255, 70 / 255, 1),
    NOT_ENOUGH_RED = Color.New(198/255, 27/255, 33/255, 1),
    BTN_TEXT = Color.New(229/255, 229/255, 229/255, 1),
    Black = Color.New(0,0,0,1),
}
UIColorStr = {
    RED = "#e25b58",
    GREEN = "#57c88a",
    NOT_ENOUGH_RED = "#C51B20FF"
}
UIColorNew = {
    GREEN =         Color.New(159/255, 255/255, 136/255, 1),
    BLUE =          Color.New(136/255, 228/255, 255/255, 1),
    PINK =          Color.New(255/255, 136/255, 255/255, 1),
    ORANGE =        Color.New(255/255, 174/255, 53/255, 1),
    RED =           Color.New(255/255, 104/255, 104/255, 1),
    YELLOW =        Color.New(255/255, 209/255, 43/255, 1),
    BTN_GOTOORGET = Color.New(88/255, 57/255, 11/255, 1),
    GRAY =          Color.New(255/255, 255/255, 255/255, 128/255),
}
UITextFontStyle = {
    NORMAL = "Normal",
    BOLD = "Bold",
    ITALIC = "Italic",
    BOLDANDITALIC = "Bold And Italic"
}

UIBtnText = {
    get = GetLanguageStrById(10022),
    go = GetLanguageStrById(10023),
    geted = GetLanguageStrById(10350),
    buy = GetLanguageStrById(50272),
}
--活动Type定义
ActivityTypeDef = {
    OnlineGift = 1,                     -- 在线奖励
    SevenDayRegister = 2,               -- 七日登录
    ChapterAward = 3,                   -- 章节奖励
    FirstRecharge = 5,                  -- 超值首充
    GrowthReward = 6,                   -- 成长礼金
    Pray = 7,                           -- 
    TreasureOfSomeBody = 8,             -- 成长手册
    LuckyCat = 9,                       -- 
    SevenDayCarnival = 10,              -- 
    WarPowerSort = 11,                  -- 战力排行
    WarPowerReach = 12,                 -- 
    DailyRecharge = 13,                 -- 每日首充
    ContinuityRecharge = 14,            -- 连续充值
    LimitExchange = 15,                 -- 腐化侵袭-限时兑换
    AdventureExper = 16,                -- 训练精英
    AreaExper = 17,                     -- 
    UpStarExper = 18,                   -- 
    EquipExper = 19,                    -- 
    GoldExper = 20,                     -- 赞助精英
    FightExper = 21,                    -- 
    EnergyExper = 22,                   --
    MonthSign = 23,                     -- 签到
    AccumulativeRechargeExper = 24,     -- 每日累充
    ExpeditionExper = 26,               -- 
    DemonSlayer = 25,                   -- 
    PatFace = 29,                       -- 
    LuckyTurnTable_One = 30,            -- 幸运探宝
    LuckyTurnTable_Two = 31,            -- 高级探宝
    XiangYaoDuoBao = 36,                -- 降妖夺宝
    Talisman = 37,                      -- 
    SoulPrint = 38,                     -- 
    SupremeHero = 42,                   -- 
    FindFairy = 43,                     -- 限时招募
    QianKunBox = 44,                    -- 神秘盲盒
    FindTreasureExper = 46,             -- 探索精英
    LuckyTurnExper = 47,                -- 轮盘达人
    RecruitExper = 48,                  -- 精英小队
    SecretBoxExper = 49,                -- 
    FindFairyUpStar = 50,               -- 
    FindFairyCeremony = 51,             -- 
    UpLvAct = 52,                       -- 
    BuyCoin = 53,                       -- 
    TreasureOfHeaven = 54,              -- 
    OpenSeverWelfare = 55,              -- 开服福利
    EightDayGift = 56,                  -- 
    SignInfo = 57,                      -- 
    DynamicAct_recharge = 58,           -- 累计充值
    Celebration = 60,                   -- 次元引擎
    NiuZhuan = 61,                      -- 
    NiuQi = 62,                         -- 极限突破
    FuXingGaoZhao = 63,                 -- 
    FifteenDayGift = 64,                -- 
    YunYouShangRen = 65,                -- 
    TaSuiLingXiao = 66,                 -- 
    slhjExper = 70,                     -- 异端克星
    ShenYiTianJiang = 71,               -- 
    LingShouBaoGe = 100,                -- 
    LingShowTeHui = 101,                -- 
    DailyRecharge_2 = 130,              -- 新增每日充值
    XinJiangLaiXi = 200,                -- 
    SignInDays = 1000,                  -- 多日登录
    WeekendWelfare = 2000,              -- 周末福利
    LifeMemebr = 3000,                  -- 终身特权
    SuperLifeMemebr = 3001,             -- 超级终身特权
    WeekCard = 7000,                    -- 周卡
    TreasureStore = 6000,               -- 旅行商人
    YiJingBaoKu = 8000,                 -- 命运魔镜
    BoxPool = 9000,                     -- 扭蛋
    MonthCard = 10001,                  -- 月卡
    MeiRiLiBao = 10004,
    WeekGift = 10005,                   -- 周礼包
    MonthGift = 10006,                  -- 月礼包
    OpenService = 10020,                -- 开服双倍
    LifeMemeber = 10021,                -- 终身限购
    DynamicAct = 20000,                 -- 限时任务
    DynamicAct_TimeLimitShop = 20001,   -- 位面商人
    DynamicAct_Treasure = 20002,        -- 
    LimitUpHero = 20003,                -- 
    AdjutantCurrent = 21000,            -- 先驱活动
    AdjutantChallenge = 21001,          -- 先驱挑战
    AdjutantRecruit = 21002,            -- 先驱招募
    AdjutantGift = 21003,               -- 先驱礼包
    PVEActivity = 30000,                -- PVE活动
    PVEStarReward = 40000,              -- PVE星数奖励
    CardActivity_Draw = 50000,          -- 英雄驾到
    CardActivity_Task = 50001,          -- 神秘指令
    CardActivity_Gift = 50003,          -- 英雄礼包
    CardActivity_Haoli = 50004,         -- 英雄豪礼
    CardActivity_Collect = 50005,       -- 英雄收集
    PreparationBefore = 400110,         -- 
    Resupply = 400210,                  -- 
    Deployment = 400310,                -- 
    ArtilleryDrills = 400410,           -- 
    FestivalActivity = 800000,          -- 
    FestivalActivity_recharge = 800001, -- 
    OpenServiceShop = 6001,             -- 开服热卖
}

--活动结束需要处理面板关闭类型
ActivityTypePanel = {
    [ActivityTypeDef.TreasureOfSomeBody] = UIName.TreasureOfSomebodyPanelV2,
    [ActivityTypeDef.TreasureOfHeaven] = UIName.TreasureOfHeavenPanel,
    [ActivityTypeDef.FirstRecharge] = UIName.FirstRechargePanel,
    [ActivityTypeDef.SevenDayCarnival] = UIName.SevenDayCarnivalPanel,
}

--Task任务定义
TaskTypeDef = {
    VipTask = 1,                    -- vip任务
    DayTask = 2,                    -- 每日任务
    EliteCarbonTask = 3,            -- 精英副本成就任务
    TreasureOfSomeBody = 4,         -- 管你是谁的宝藏
    SevenDayCarnival = 5,           -- 七日狂欢
    MainTask = 6,                   -- 主线任务
    BloodyTask = 7,                 -- 血战任务
    FindTreasure = 8,               -- 迷宫寻宝任务
    Achievement = 9,                -- 所有成就任务
    DynamicActTask = 10,            -- 主题活动任务
    SupportTask = 11,               -- 支援
    ClimbTowerNormalTask = 12,      -- 爬塔普通任务
    ClimbTowerVipTask = 13,         -- 爬塔vip任务
    GuildActiveTask = 14,           -- 联盟活跃任务
    GuideTask = 15,                 -- 指引任务
    ClimbTowerNormalTaskAdvance = 16,  -- 爬塔普通任务 高级
    ClimbTowerVipTaskAdvance = 17,  -- 爬塔vip任务 高级
    wujinfuben = 12,                -- 牛气冲天任务
    NiuQiChongTian = 18,            -- 战车达人任务
    AdjutantChallengeTask = 19,     -- 副官挑战
    -- PreparationBefore = 20,         -- 战前准备
    BattlePass = 21,                -- 手札
    PreparationBefore = 22,         -- 战前准备
    CardActivity_Task = 23,         -- 卡牌主题活动 神秘指令
    CardActivity_Collect = 24,      -- 卡牌主题活动 英雄收集
    Train = 25,                     -- 快速训练阶段奖励
    Chaos = 26,                     -- 混乱之治
}

--商品类型
GoodsTypeDef = {
    MonthCard = 1,          -- 月卡
    PermanentMonthCard = 2, -- 永久月卡
    DemonCrystal = 3,       -- 钻石类
    GrowthReward = 4,       -- 成长基金类
    DirectPurchaseGift = 5, -- 直购礼包
    LuxuryMonthCard = 6,    -- 豪华月卡
    WeekCard = 7,           -- 周卡
    MONTHCARD_128 = 8,      -- 豪华月卡128
    MONTHCARD_328 = 9,      -- 豪华月卡328
    GuildRedPacket = 10,    -- 公会红包
    FindBaby = 11,          -- 戒灵秘宝
    TreasureOfHeaven = 12,  -- 天宫秘宝
    UpgradePackage = 13,    -- 升级限时礼包
    LifeMember = 20,        -- 终身限购
    NewWeekCard = 21,       -- 周卡
    ClubGiftPack = 22,      -- 俱乐部礼包
}

--工坊功能类型
WorkShopFunType = {
    TheTechTree = 1,-- 天赋树
    EquipMade = 2,  -- 装备打造
    ArmorMade = 3,  -- 防具打造
    EquipRecast = 4,-- 装备重铸
}

--装备名字定义
WorkShopFunTypeGetStr = {
    [1] = GetLanguageStrById(12125),
    [2] = GetLanguageStrById(12126),
    [3] = GetLanguageStrById(12127),
    [4] = GetLanguageStrById(12128),
}

--每个小关卡状态--1 未开启 2 已开启 3 未通关  4 已通关
SingleFightState = {
    NoOpen = 1, -- 未开启
    Open = 2,   -- 已开启
    NoPass = 3, -- 未通关
    Pass = 4,   -- 已通关
}

--每个关卡困难状态
FightDifficultyState = {
    SimpleLevel = 1,    -- 简单
    NrmalLevel = 2,     -- 普通
    DifficultyLevel = 3,-- 困难
    HellLevel = 4,      -- 地狱
    NightmareLevel = 5, -- 噩梦
}

--每个关卡困难状态
FightDifficultyStateZiSp = {
    [1] = "r_guanka_jd", -- 简单
    [2] = "r_guanka_pt", -- 普通
    [3] = "r_guanka_kn", -- 困难
    [4] = "r_guanka_dy", -- 地狱
    [5] = "r_guanka_em", -- 噩梦
}

PowerChangeIconDef = {
    "r_hero_shengji", --战力提升
    "r_hero_xiajiang" --战力下降
}

ConditionType = {
    Level = 9, --玩家等级
    CarBon = 15 --通关副本
}
IndexValueDef = {
    [1] = 6,--首充6元
    [2] = 100, --首充100元
    [6] = 1,
    [100] = 2,
}

--功能开启
FunOpenIndexID = {
    DiffMonster = 3,    -- 异妖
    Party = 4,          -- 公会
    Arena = 8,          -- 竞技场
    NormalCopy = 17,    -- 剧情副本
    EliteCopy = 18,     -- 精英副本
    SecretBox = 21,     -- 秘宝轩
    TrialCopy = 30,     -- 试炼副本
    ElementRecruitment = 33,-- 元素令
    AnimalTides = 44,   -- 兽潮来袭
    EndlessCopy = 46,   -- 无尽副本
    Stargazing = 52,    -- 观星
    AlienInvasion = 53, -- 外敌入侵
    FindTreasure = 60,  -- 寻宝
    Talent = 101,       -- 天赋
}

-- 设置数据的枚举类型()
SETTING_TYPE = {
    -- 整数 0 < n < 100

    -- 浮点数 100 < n < 200
    BGM_RATIO = 101,
    SOUND_RATIO = 102,
    CV_RATIO = 103,
    -- 字符串 200 < n < 300
}

-- 特权类型
PRIVILEGE_TYPE = {
    EXPLORE_REWARD = 4,     -- 挂机探索特权
    ADVENTURE_BOSS = 9,     -- 外敌挑战次数
    DoubleTimesFight = 501, -- 2倍速战斗
    CarbonSweeps = 502,     -- 副本扫荡
    SkipFight = 512,        -- 跳过战斗
    -- UnlockPickUp = 504,     -- 一键领取
    -- EXTRA_STAR_REWARD = 506,-- 额外星级奖励特权
    -- ExitFight = 509,        -- 退出战斗
    -- MonsterCampJump = 510,  -- 兽潮跳过战斗
    ArenaJump  = 511,           -- 竞技场跳过战斗
    ClimbTowerJump = 513,       -- 神之塔跳过战斗
    DefenseTrainingJump = 514,  -- 深渊试炼战斗跳过
    BlitzStrikeJump = 515,      -- 遗忘之城战斗跳过
    MapJump = 516,              -- 异端之战战斗跳过
    Carbon = 517,               -- 腐化之战战斗跳过
    GoFindTreasure  = 30,       -- 高级迷宫寻宝每日任务刷新次数
    HaoFindTreasure  = 31,      -- 豪华迷宫寻宝每日任务刷新次数
    ADVENTURE_EXPLORE  = 35,    -- 挂机额外奖励
    GUILD_BOSS_ATTACK  = 37,    -- 公会boss挑战次数
    GUILD_BOSS_JUMP  = 1002,    -- 公会boss扫荡功能
    DAY_SIGN_IN = 1005,         -- 每日前端次数
    GUILD_CAR_DELEAY_CHALLENGE = 201,-- 车迟斗法挑战次数
    GUILD_CAR_DELEAY_LOOT = 202,     -- 车迟斗法抢夺次数
    GUILD_CAR_DELEAY_BuyCount = 203, -- 车迟斗法购买次数
    BuyGoldAdd = 21,                 -- 购买金币数量增加
    ThreeTimesFight = 2003,          -- 3倍速战斗
    GUILDTRANSCRIPT_BATTLENUM = 3011,     -- 公会副本挑战次数
    GUILDTRANSCRIPT_BUY_BATTLENUM = 3012, -- 公会副本挑战购买次数
    ClimbTowerUnlockNormalVip = 10001,  -- 爬塔解锁normal Reward Vip
    ClimbTowerUnlockAdvanceVip = 10002, -- 爬塔解锁advance Reward Vip
    BlitzRliveTimesLimit = 20001,       -- 闪电突袭购买复活次数上限
    AdjutantVigorLimit = 50001,         -- 副官精力上限
    BuyLADDERS = 30001,    -- 天梯赛购买次数
    BattleInBack = 93001,  -- 战斗切后台特权
    AutoNextFight = 94001, -- 自动下一关
}

-- 特权解锁类型
PRIVILEGE_UNLOCKTYPE = {
    -- 前面还有坦克设定的类型就不写这里了
    ClimbTower = 101,   -- 神之塔挑战层数
    BlitzStrike = 102,  -- 深渊试炼历史最高层数
    Map = 103,          -- 异端之战当前最高层数
    BattlePower = 104,  -- 当前战斗力
}

-- 功能开启类型
FUNCTION_OPEN_TYPE = {
    RECURITY = 1,           -- 角色招募
    DIFFER_DEMONS = 3,      -- 异妖
    GUILD = 4,              -- 公会
    ADVENTURE = 7,          -- 秘境
    ARENA = 8,              -- 竞技场
    MISSIONDAILY = 12,      -- 每日任务
    CHAT = 14,              -- 聊天
    NORMALCARBON = 17,      -- 普通副本
    SHOP = 20,              -- 商店
    SECRETBOX = 21,         -- 秘盒
    HERO_RESOLVE = 24,      -- 人事管理处
    GOODFRIEND = 25,        -- 好友
    CUSTOMSPASS = 26,       -- 关卡
    ROLE = 29,              -- 主角
    DAILY_TASK = 28,        -- 日常任务
    TRIAL = 30,             -- 异端之战
    PRAY = 34,              -- 云梦祈福
    SUNLONG = 35,           -- 孙龙宝藏
    SERVER_START_GIFT = 37, -- 开服有利
    RankList = 43,          -- 战力排行榜
    EXPERT = 42,            -- 限时活动
    MONSTER_COMING = 44,    -- 深渊试炼
    EMAIL = 45,             -- 邮件
    BLOODY_BATTLE = 47,     -- 血战
    RING_SOUL = 50,         -- 戒灵
    HAND_BOOK = 51,         -- 图鉴
    ASPECT_STAR = 52,       -- 观星
    FIGHT_ALIEN = 53,       -- 新关卡外敌入侵功能
    Online_Reward = 16,     -- 在线奖励
    Chapter_Reward = 19,    -- 章节奖励
    ELEMENT_RECURITY = 33,  -- 俱乐部
    TALENT_TREE = 101,      -- 天赋
    ENDLESS = 46,           -- 无尽副本
    ELITE = 18,             -- 精英副本
    ALLRANKING = 55,        -- 群雄榜（总排专属！）
    TOP_MATCH = 57,         -- 锦标赛
    FINDTREASURE = 60,      -- 迷宫寻宝
    LUCKYTURN = 61,         -- 幸运探宝（活动变功能）
    GUILD_BOSS = 62,        -- 公会boss
    GUILD_REDPACKET = 63,   -- 公会红包
    EXPEDITION = 64,        -- 远征
    Achiecement = 65,       -- 成就
    COMPOUND = 66,          -- 研究所
    DAILYCHALLENGE_COIN = 67,       -- 每日金币副本
    DAILYCHALLENGE_EXP = 68,        -- 每日经验副本
    DAILYCHALLENGE_HERODEBRIS = 69, -- 每日角色碎片副本
    DAILYCHALLENGE_TALISMAN = 70,   -- 每日法宝副本
    DAILYCHALLENGE_SOULPRINT = 71,  -- 每日魂印副本 
    GUILD_BATTLE = 72,      -- 公会战
    MINSKBATTLE = 73,       -- 梦魇入侵
    PEOPLE_MIRROR = 74,     -- 腐化之战
    ASSEMBLE = 75,          -- 实验室
    -- MAGIC_MIRROR = 76,      -- 妖灵宝镜Support
    -- TAOIST_MIRROR = 77,     -- 道玄宝镜
    ADJUTANT = 76,          -- 先驱
    GENERAL = 77,           -- 契约
    BlackShop = 78,         -- 黑市
    SUPPORT = 79,           -- 支援
    COMBAT_PLAN = 80,       -- 作战方案
    MEDAL = 81,             -- 勋章
    Hegemony = 82,          -- 破碎王座
    BLITZ_STRIKE = 83,      -- 遗忘之城
    laddersChallenge = 84,  -- 跨服竞技场
    CLIMB_TOWER = 85,       -- 神之塔
    HeroExchange = 86,      -- 医院
    ALAMEIN_WAR = 89,       -- 迷雾之战
    AIRCRAFT_CARRIER = 90,  -- 神眷者
    InvestigateCenter = 91, -- 启明星
    XiaoYaoYou = 92,        -- 战棋
    BattlePass = 107,       -- 手札
    QuickTrain = 110,       -- 快速训练任务
    ValuePack = 801,        -- 超值礼包
    ThousandDraw = 1500,    -- 千抽
    PVEActivity = 109,      -- PVE
    WorldLevel = 1501,      -- 世界等级
    Questionnaire = 201,    -- 调查问卷
    OpenServiceGift = 202,  -- 开服有礼
    ChaosZZ    =111,        -- 混乱之治
}

--跳转类型
JumpType = {
    Lottery = 1,                      -- 招募
    Team = 2,                         -- 编队
    -- DifferDemons = 3,                 -- 异妖
    Guild = 4,                        -- 公会
    -- WorkShop = 101,                   -- 天赋
    -- Foods = 6,                        -- 百味居
    -- Adventure = 7,                    -- 秘境
    Arena = 8,                        -- 竞技场
    -- HanYuan = 9,                      -- 汉元之境
    -- WangHun = 10,                     -- 亡魂之海
    MultipleChallenge = 11,           -- 物资收集
    DailyTasks = 12,                  -- 每日任务
    -- WorldBoss = 13,                   -- 世界boss
    Talking = 14,                     -- 聊天
    LoginReward = 15,                 -- 七日登陆
    OnlineReward = 16,                -- 在线奖励
    -- CommonChallenge = 17,             -- 剧情副本
    -- HeroChallenge = 18,               -- 精英副本
    ChapterReward = 19,               -- 章节奖励
    Store = 20,                       -- 商店
    -- DifferDemonsBox = 21,             -- 秘盒
    MemberCamp = 22,                  -- 成员
    StoreHouse = 23,                  -- 背包
    Resolve = 24,                     -- 人事处
    Friend = 25,                      -- 好友
    Level = 26,                       -- 闯关
    RechargeStore = 27,               -- 充值商店
    DatTask = 28,                     -- 日常任务
    -- Talent = 50,                      -- 天赋
    Trial = 30,                       -- 异端之战
    ElementDrawCard = 33,             -- 元素招募
    -- Pray = 34,                        -- 云梦祈福
    GrowthManual = 35,                -- 成长手册
    recharge = 36,                    -- 充值
    Welfare = 40,                     -- 福利
    DailyFirstCharge = 41,            -- 每日首充
    Expert = 42,                      -- 限时活动
    DefTraining = 44,                 -- 深渊试炼
    mial = 45,                        -- 邮件
    -- EndlessFight = 46,                -- 无尽副本
    GiveMePower = 48,                 -- 我要变强
    -- SoulPrintAstrology = 52,          -- 观星
    -- Alien = 53,                       -- 外敌
    TopMatch = 57,                    -- 锦标赛
    FindTreasure = 60,                -- 探索
    LuckyTurn = 61,                   -- 幸运轮盘
    GuildTranscript = 62,             -- 公会副本
    GuildRedPackage = 63,             -- 公会红包
    -- Expedition = 64,                  -- 远征
    Achievement = 65,                 -- 成就
    Compound = 66,                    -- 研究所
    DailyCarbon_Gold = 67,            -- 每日金币副本
    DailyCarbon_Exp = 68,             -- 每日经验副本
    DailyCarbon_Hero = 69,            -- 每日角色碎片副本
    DailyCarbon_Transure = 70,        -- 每日法宝副本
    DailyCarbon_SoulPrint = 71,       -- 每日魂印副本
    GuideBattle = 72,                 -- 公会战
    MinskBattle = 73,                 -- 梦魇入侵
    ArdenBattle = 74,                 -- 腐化之战
    BuyVigor = 10000,                 -- 体力购买
    BuyGold = 10001,                  -- 金币购买
    -- Privilege = 10003,                -- 特权
    HeroUpLv = 10004,                 -- 成员升级
    HeroUpStar = 10005,               -- 成员升星
    AllForMation = 10006,             -- 成员里的编队
    QuickPurchase = 10007,            -- 赞助
    -- FiveStarActivity = 10008,         -- 五星成长礼
    Setting = 10009,                  -- 设置界面
    -- FindFairy = 10010,                -- 东海寻仙
    -- GuildAid = 10011,                 -- 公会援助
    GuildSkill = 10012,               -- 公会技能
    GuildFete = 10013,                -- 公会捐献
    EndlessShop = 10014,              -- 无尽商店
    TimeLimiteCall = 10015,           -- 限时招募
    QianKunBox = 10016,               -- 乾坤宝盒
    Celebration = 10017,              -- 次元引擎
    YiJingBaoKu = 10018,              -- 厄里斯魔镜
    -- LingShouBaoGe = 10019,            -- 灵兽宝阁
    -- XiangYaoDuoBao = 10020,           -- 降妖夺宝
    -- HeadChange = 10021,               -- 锦标赛
    XianShiDuiHuan = 10022,           -- 主题活动限时兑换
    EndlessXingDongliBuy = 10023,     -- 无尽行动力购买
    chaozhijijin = 10078,             -- 超值基金
    ZhuTiHuoDong = 20000,             -- 主题活动任务
    QianKunShangDian = 20044,         -- 神秘盲盒商店
    SheJiDaDianShangDian = 20060,     -- 次元引擎商店
    -- XinJiangLaiXiShangDian = 20200,   -- 
    -- XingChenShangDian = 20059,        -- 星辰商店
    ChaoFanRuSheng = 20061,
    zhenqibaoge = 20002,
    xianshishangshi = 20001,
    firstRecharge = 30001,            -- 超值首充
    ZhiZunJiangShi = 30002,           -- 武圣降临
    SurpriseBox = 40001,              -- 惊喜礼盒
    CustomizeShop = 20019,            -- 兑换商店
    AdvancedClimbTower = 10085,       -- 魔之塔
    Adjutant = 76,                    -- 先驱
    Contract = 77,                    -- 契约
    BlackShop = 78,                   -- 黑市
    Support = 79,                     -- 守护
    Hegemony = 82,                    -- 破碎王座
    BlitzStrike = 83,                 -- 遗忘之城
    laddersChallenge = 84,            -- 跨服竞技
    ClimbTower = 85,                  -- 神之塔
    HeroExchange = 86,                -- 医院
    AlameinBattle = 89,               -- 迷雾之战
    AircraftCarrier = 90,             -- 航母
    InvestigateCenter = 91,           -- 启明星科技
    -- xiaoyaoJump = 92,                 -- 战棋推演
    AdjutantActivity = 93,            -- 先驱主题活动
    BattlePassPanel = 107,            -- 手札
    RingRefine = 50001,               -- 戒指精炼
    Laboratory = 50002,               -- 实验室
    LimitCollection = 50003,          -- 限定珍藏
    LaddersShop = 50004,              -- 跨服竞技场商店
    RouletteShop = 50005,             -- 幸运轮盘商店
    ChipShop = 50006,                 -- 芯片商店
    AdjutantShop = 50007,             -- 先驱商店
    WorldbossShop = 50008,            -- 梦魇入侵商店
    AreaThumbsUp = 50009,             -- 竞技场点赞
    CampWarShop = 50010,              -- 暗物质商店	
    ChaosZz = 111,                    -- 混乱之治
    ForgottenCity = 50011,            -- 遗忘之城商店
}

TaskGetBtnIconDef = {
    [0] = "N1_btn_tongyongxiaoxing_huangse",
    [1] = "N1_btn_tongyongxiaoxing_lvse",
}

---客户端主发信息
UpDateTypeState = {
    SevenDayCarnival = 1,
}

---=================公会相关============
-- 公会状态
GUILD_JOIN_TYPE = {
    NO_LIMIT = 1,   -- 无需审批
    LIMIT = 2,      -- 需要审批
    FORBID = 3,     -- 禁止加入
}
-- 公会审批状态
GUILD_APPLY_STATUS = {
    NO_APPLY = 0,   -- 未申请
    APPLY = 1,      -- 已申请
}
-- 公会职位
GUILD_GRANT = {
    MASTER = 1,     -- 会长大人
    ADMIN = 2,      -- 管理员小姐姐
    MEMBER = 3,     -- 吃瓜群众
}
-- 公会职位名称
GUILD_GRANT_STR = {
    [GUILD_GRANT.MASTER] = GetLanguageStrById(12129),     -- 会长大人
    [GUILD_GRANT.ADMIN] = GetLanguageStrById(12130),      -- 管理员小姐姐
    [GUILD_GRANT.MEMBER] = GetLanguageStrById(12131),     -- 吃瓜群众
}
-- 公会申请操作类型
GUILD_APPLY_OPTYPE = {
    ALL_AGREE = 1,
    ALL_REFUSE = 2,
    ONE_AGREE = 3,
    ONE_REFUSE = 4,
}
-- 公会建筑类型
GUILD_BUILD_TYPE = {
    HOUSE = 1,
    STORE = 2,
    LOGO = 3,
}
-- 公会地图建筑类型
GUILD_MAP_BUILD_TYPE = {
    HOUSE = 1,
    STORE = 2,
    LOGO = 3,
    DOOR = 4,
    LOGO_IMG = 5,
    BOSS = 6,
    FETE = 7,           -- 祭祀
    TENPOS = 8,         -- 十绝阵
    SKILL = 9,          -- 技能
    CARDELAY = 10,      -- 车迟
    AID = 11,           -- 援助
    ACTIVE = 12,        -- 联盟活跃
    MEMBER = 13,        -- 联盟成员
    REDBAG = 14,        -- 联盟红包
    TRANSCRIPT = 15,    -- 联盟副本
}
-- 公会成员信息界面类型
GUILD_MEM_POPUP_TYPE = {
    INFORMATION = 1,
    DEFEND = 2,                 -- 布防阶段
    ATTACK_MY_DEFEND = 3,       -- 进攻阶段我的公会
    ATTACK_ENEMY_DEFEND = 4,    -- 进攻阶段敌方公会
}
-- 公会信息修改界面类型
GUILD_CHANGE_TYPE = {
    ANNOUNCE = 1,
    SETTING = 2,
    LOGO = 3,
    NAME = 4,
}
-- 公会战双方类型
GUILD_FIGHT_GUILD_TYPE = {
    MY = 0,
    ENEMY = 1,
}
-- 公会战阶段类型
GUILD_FIGHT_STAGE = {
    DISSMISS = -99, -- 解散
    CLOSE = -2,     -- 公会战关闭
    EMPTEY = -1,    -- 轮空
    UN_START = 0,   -- 未开始
    DEFEND = 1,     -- 布防
    MATCHING = 2,   -- 匹配
    ATTACK = 3,     -- 进攻
    COUNTING = 4,   -- 结算
}
GUILD_FIGHT_STAGE_STR = {
    [GUILD_FIGHT_STAGE.EMPTEY] = GetLanguageStrById(12132),
    [GUILD_FIGHT_STAGE.UN_START] = GetLanguageStrById(10122),
    [GUILD_FIGHT_STAGE.DEFEND] = GetLanguageStrById(10883),
    [GUILD_FIGHT_STAGE.MATCHING] = GetLanguageStrById(10884),
    [GUILD_FIGHT_STAGE.ATTACK] = GetLanguageStrById(10885),
    [GUILD_FIGHT_STAGE.COUNTING] = GetLanguageStrById(10886),
}
-- 公会默认图腾id
GUILD_DEFAULT_LOGO = 1
-- 公会招募信息冷却时间
GUILD_INVITE_CD = 100

-- 公会提示类型
GUILD_TIP_TYPE = {
    JOIN = 0,
    POS = 1,
    KICKOUT = 2,
    REFUSE = 3,
}
---=================公会相关end============
-- 帮助类型
HELP_TYPE = {
    Plot = 1,       --剧情、普通副本
    Elite = 2,      --精英副本
    Trial = 3,      --试炼副本
    Arena = 4,      --竞技场
    Work = 5,       --工坊
    Adventure = 6,  --秘境
    RoleInfo = 7,   --妖灵师
    -- Talent = 8,     --戒灵
    VIP = 9,        --特权
    GeneralShop = 10,       -- 杂货商店
    SoulContractShop = 11,  -- 契魂商店
    SecretBoxShop = 12,     -- 秘盒商店
    ArenaShop = 13,         -- 竞技商店
    SecretBoxRecruit = 14,  -- 秘盒招募
    FuXingGaoZhao = 15,     -- 福星高照
    DiffMonster = 16,       -- 异妖
    EndLessMap = 17,        -- 无尽副本
    SoulPrintUpgrade = 18,  -- 魂印升级
    Talisman = 19,          -- 法宝
    SoulPrint = 20,         -- 魂印
    Astrology = 21,         -- 观星
    SoulPrintShop = 22,     -- 魂印商店
    HeroReturn = 23,        -- 回溯
    FriendShop = 24,        -- 好友商店
    LuckyTurn = 25,         -- 幸运探宝
    SpeedExploration = 26,  -- 极速探索
    Guilds = 27,            -- 公会战
    GuildShop = 28,         -- 工会商店
    ElementDraw = 29,       -- 定制补给
    ChoasShop = 30,         -- 混沌商店
    GuildDefend = 31,       -- 布防阶段
    GuildMatching = 32,     -- 匹配阶段
    GuildAttack = 33,       -- 进攻阶段
    GuildCounting = 34,     -- 结算阶段
    -- FindTreasure = 35,      -- 寻宝
    FindFairy = 36,         -- 东海寻仙
    TopMatch = 37,          -- 巅峰赛
    TopMatchShop = 38,      -- 巅峰赛商店
    GuildBoss = 39,         -- 公会boss
    Expedition = 40,        -- 远征
    Resolve_Recall = 41,    -- 回溯
    Resolve_Dismantle = 101,-- 献祭
    NewTalisman = 43,       -- 新法宝
    NewTalismanUp = 44,     -- 新法宝进阶
    DailyCarbon = 45,       -- 日常副本
    GuildFete = 46,         -- 公会祭祀
    GuildBattle = 47,       -- 公会战
    GuildTenPosInfo = 48,   -- 公会十绝阵详情
    GuildSkill = 49,        -- 公会技能详情
    BuyCoin = 50,           -- 点石成金
    GuildCarDelay = 51,     -- 车迟
    OpenHappy = 50,         -- 开服狂欢
    OpenSevenDay = 52,      -- 开服狂欢
    SoulPrintCommond = 53,  -- 魂印合成
    Sunro = 54,             -- 森罗环境
    EquipCompose = 55,      -- 装备合成
    TreasureCompose = 56,   -- 宝物合成
    TimeLimitedCall = 57,   -- 限时召唤
    TreasureOfHeaven = 58,  -- 天宫秘宝
    QianKunBox = 59,        -- 乾坤宝囊
    TreasureResolve = 60,   -- 宝物分解
    XuanYuanMirror = 61,    -- 轩辕宝镜
    GuildTranscripe = 62,   -- 公会副本
    QingLongSerectTreasure = 68,    -- 成长手册
    XiaoYaoHelp = 73,       --逍遥游帮助id
    YiJingBaoKu = 77,       --易经宝库
    DefenseTraining = 89,   -- 防守训练
    BlitzStrikeDifficultSelect = 90, -- 闪电出击
    Hegemony = 91,          -- 三强争霸
    Support = 92,           -- 支援
    HeroMain = 93,          -- 战车
    Adjutant = 94,          -- 副官
    ClimbTower = 95,        -- 模拟战
    ClimbTowerRewardPopup = 96, -- 模拟战挑战
    CarbonType = 97,        -- 奥登战役
    BattleOfMinsk = 98,     -- 明斯克战役
    Recruit = 99,           -- 补给
    ArenaTypePanelTopMatch = 100,   -- 联赛
    HeroExchange = 102,     -- 战车回溯
    HeroExchange1 = 103,    -- 战车改造
    HeroExchange2 = 104,    -- 高级回溯
    Assemble = 105,         -- 装配厂
    GeneralInfo = 106,      -- 名将
    GuildMember = 107,      -- 军团成员
    GuildBattleBoxReward = 108,      -- 公会战宝箱
    FindTreasure = 111,     -- 巡逻
    HeroReplacement = 112,  -- 战车交换
    ElAlamein = 113,        -- 阿拉曼战役
    roleSkillLayout = 114,  -- 战法
    CVFAQ = 117,            -- 航母飞机
    -- GuildBattle = 118,      -- 公会战
    Parts = 119,            -- 部件
    Talent = 120,           -- 特性（天赋）
    compoundMedal = 122,    -- 勋章合成属性
    CombatPlan = 123,       -- 作战方案合成
    Celebration = 124,      -- 社稷大典
    LaddersChallenge = 125, -- 跨服竞技场
    ArtilleryDrills = 126,  -- 炮击演练
    ChaosHelp = 130,        -- 混乱之治  
}

NumToComplexFont = {
    [1] = GetLanguageStrById(12133),
    [2] = GetLanguageStrById(12134),
    [3] = GetLanguageStrById(12135),
    [4] = GetLanguageStrById(12136),
    [5] = GetLanguageStrById(12137),
    [6] = GetLanguageStrById(12138),
    [7] = GetLanguageStrById(12139),
    [8] = GetLanguageStrById(12140),
    [9] = GetLanguageStrById(12141),
    [10] = GetLanguageStrById(12142),
    [11] = GetLanguageStrById(12143),
    [12] = GetLanguageStrById(12144),
    [13] = GetLanguageStrById(12145),
    [14] = GetLanguageStrById(12146),
    [15] = GetLanguageStrById(12147),
}
NumToSimplenessFont = {
    [1] = GetLanguageStrById(10005),
    [2] = GetLanguageStrById(10006),
    [3] = GetLanguageStrById(10007),
    [4] = GetLanguageStrById(10008),
    [5] = GetLanguageStrById(10009),
    [6] = GetLanguageStrById(10010),
    [7] = GetLanguageStrById(10011),
    [8] = GetLanguageStrById(10012),
    [9] = GetLanguageStrById(10013),
    [10] = GetLanguageStrById(10014),
    [11] = GetLanguageStrById(10015),
    [12] = GetLanguageStrById(10016),
    [13] = GetLanguageStrById(10017),
    [14] = GetLanguageStrById(10018),
    [15] = GetLanguageStrById(10019),
}
-- 世界聊天类型
GLOBAL_CHAT_TYPE = {
    COMMON = 0,
    GUILD_INVITE = 1,
    GUILD_REDPACKET = 2,
    GUILD_AID = 3,
}
-- 公共聊天记录最大保存数量
PUBLIC_CHAT_MAX_NUM = 50

ServerStateDef = {
    Maintenance = 1,
    Fluency = 2,
    Full = 3,
    Congestion = 4--拥挤，服务器不存在此状态
}

BindPhoneState = {
    NoneBind = 0,
    BindedButNotAward = 1,
    BindedAndAwarded = 2
}

-- 地图难度
MAP_MODE = {
    [1] = GetLanguageStrById(10351),
    [2] = GetLanguageStrById(10352),
    [3] = GetLanguageStrById(10353),
    [4] = GetLanguageStrById(12148),
}

--0:不可见 1:维护 2:流畅 3:拥挤 4:爆满
ServerStateIconDef = {
    [1] = "cn2-X1_denglu_fuwuqi_weixiu",
    [2] = "cn2-X1_denglu_fuwuqi_liuchang",
    [3] = "cn2-X1_denglu_fuwuqi_yongji",
    [4] = "cn2-X1_denglu_fuwuqi_baoman",
}

--编队需要拉取主线
FormationNeedNormalType = {

}

--法宝背景气泡
TalismanBubble = {
    [2] = "r_fabao_lvyuan",
    [3] = "r_fabao_lanyuan",
    [4] = "r_fabao_ziyuan",
    [5] = "r_fabao_huangyuan",
    [6] = "r_fabao_hongyuan",
}

-- 玩家信息界面类型
PLAYER_INFO_VIEW_TYPE = {
    NORMAL = 1,
    BLACK_REMOVE = 2,
    GO_TO_BLACK = 3,
    ARENA = 4,
    LADDERSARENA = 5,
    ChaosZZ=6,
}

--限时达人 周卡 限时活动 拍脸 异妖直购
ExperType = {
    SevenDay = 1,           -- 七日活动
    PatFace = 2,            -- 拍脸
    DiffMonster = 3,        -- 异妖直购
    WeekCard = 4,           -- 周卡
    LuckyCat = 5,           -- 招财猫
    -- LuckyTurn = 6,          -- 幸运转盘
    AddUp = 7,              -- 累计达人
    ExChange = 8,           -- 限时兑换
    UpStar = 9,             -- 进阶达人
    Adventure = 10,         -- 秘境达人
    Arena = 11,             -- 竞技场达人
    Equip = 12,             -- 装备达人
    Gold = 13,              -- 点金达人
    Map = 14,               -- 副本达人
    Manual = 15,            -- 体力达人
    Talisman = 16,          -- 法宝达人
    SoulPrint = 17,         -- 魂印达人
    StarGrowGift = 18,      -- 星级礼包
    FindTreasure = 19,      -- 寻宝达人
    LuckyTurn = 20,         -- 探宝达人
    Recruit = 21,           -- 征募达人
    SecretBox = 22,         -- 秘宝达人
    UpLv = 23,              -- 升级限量豪礼
    ContinueRecharge = 24,  -- 积天豪礼
    GiftBuy = 25,           -- 限定珍藏
    PreparationBefore = 28, -- 战前准备
    Resupply = 29,          -- 物资补给
    Deployment = 30,        -- 军备调配
    OpenService = 31,       -- 开服双倍
    BoxPool = 32,           -- 扭蛋
}

DynamicType = {--轮转活动类型
    TimeLimiteCall = 43,
    QianKunBox = 44,
    -- PoZhenZhuXian = 57,--待定
}

-- 枚举
CHAT_CHANNEL = {
    SYSTEM = 0,     -- 系统
    GLOBAL = 1,     -- 世界
    FAMILY = 2,     -- 公会
    FRIEND = 3,     -- 好友
    CrossRealm = 16,-- 跨服
}

-- 新关卡状态
FIGHT_POINT_STATE = {
    PASS = 1,           -- 已通关
    OPEN_NOT_PASS = 2,  -- 开启未通关，随时可以挑战
    OPEN_LOW_LEVEL = 3, -- 开启等级不够，需要等级
    LOCK = 4,           -- 未解锁
}

--英雄定位
ProfessionImage = {
    [1] = "cn2-X1_tongyong_yingxiongdingwei_01",
    [2] = "cn2-X1_tongyong_yingxiongdingwei_03",
    [3] = "cn2-X1_tongyong_yingxiongdingwei_02",
    [4] = "cn2-X1_tongyong_yingxiongdingwei_04",
}

NumExChange = {
    [7] = ActivityTypeDef.AccumulativeRechargeExper,
    [9] = ActivityTypeDef.UpStarExper,
    [10] = ActivityTypeDef.AdventureExper,
    [11] = ActivityTypeDef.AreaExper,
    [12] = ActivityTypeDef.EquipExper,
    [13] = ActivityTypeDef.GoldExper,
    [14] = ActivityTypeDef.FightExper,
    [15] = ActivityTypeDef.EnergyExper,
    [16] = ActivityTypeDef.Talisman,
    [17] = ActivityTypeDef.SoulPrint,
    [19] = ActivityTypeDef.FindTreasureExper,
    [20] = ActivityTypeDef.LuckyTurnExper,
    [21] = ActivityTypeDef.RecruitExper,
    [22] = ActivityTypeDef.SecretBoxExper,
    [26] = ActivityTypeDef.ExpeditionExper,
    [27] = ActivityTypeDef.slhjExper,
}

NumExChangeRankName = {
    [7] = GetLanguageStrById(10131),
    [9] = GetLanguageStrById(10131),
    [10] = GetLanguageStrById(10131),
    [11] = GetLanguageStrById(10131),
    [12] = GetLanguageStrById(10131),
    [13] = GetLanguageStrById(12168),
    [14] = GetLanguageStrById(10131),
    [15] = GetLanguageStrById(10131),
    [16] = GetLanguageStrById(10131),
    [17] = GetLanguageStrById(10131),
    [19] = GetLanguageStrById(10131),
    [20] = GetLanguageStrById(10131),
    [21] = GetLanguageStrById(50349),
    [22] = GetLanguageStrById(10131),

}
-- 关卡中地图章节
FIGHT_CHAPTER_TYPE = {
    FIRST = 1,
    SECOND = 2,
    THIRDLY = 3,
    FOURTH = 4,
    FIFTH = 5,
    SIXTH = 6,
    SEVENTH = 7,
    ENGHTH = 8,
    NINTH = 9,
    TENTH = 10,
    ELEVENTH = 11,
    TWELFTH = 12,
    THIRTEENTH = 13,
    FOURTEENTH = 14,
    FIFTEENTH = 15,
}
SkillType = {
    Pu = 1 , --普技
    Jue = 2 ,--绝技
    Bei = 3 ,--被动技
}
SkillTypeStr = {
    [1] = GetLanguageStrById(12149) ,--普技
    [2] = GetLanguageStrById(12150) ,--绝技
    [3] = GetLanguageStrById(12151) ,--被动技
}
-- 1:前期 2:中期 3:后期
HeroStageSprite = {
    [1] = "bd_qianqi",
    [2] = "bd_zhongqi",
    [3] = "bd_houqi",
    [4] = "bd_quanqi",
}

CommonInfoType = {
    WarWay = 1,
}

-- 功能开启图标类型
FUNC_OPNE_STATE = {
    CARBON_NORMAL = "CARBON_NORMAL",
    CARBON_ENDLESS = "CARBON_ENDLESS",
    CARBON_TRIAL = "CARBON_TRIAL",
    CARBON_ELITE = "CARBON_ELITE",
    MAIN_SHOP = "MAIN_SHOP",
    MAIN_RANK_LIST = "MAIN_RANK_LIST",
    MAIN_WATCH_STAR = "MAIN_WATCH_STAR",
    MAIN_HERO_RESOLVE = "MAIN_HERO_RESOLVE",
    MAIN_HAND_BOOK = "MAIN_HAND_BOOK",
    MAIN_AREAN = "MAIN_AREAN",
    MAIN_GUILD = "MAIN_GUILD",
    MAIN_MONSTER_COMING = "MONSTER_COMING",
    MAIN_RECURITY = "MAIN_RECURITY",
    MAIN_ELEMENT_RECURITY = "MAIN_ELEMENT_RECURITY",
    MAIN_SECRETBOX = "MAIN_SECRETBOX",
    MAIN_TALENT_TREE = "MAIN_TALENT_TREE",
    MAIN_DIFFER_DEMONS = "MAIN_DIFFER_DEMONS",
    MAIN_FIGHT_ALIEN = "MAIN_FIGHT_ALIEN",
    COMPOUND = "COMPOUND",
    MAIN_ADJUTANT = "MAIN_ADJUTANT", 
    MAIN_CLIMB_TOWER = "MAIN_CLIMB_TOWER",
    MAIN_HeroExchange = "MAIN_HeroExchange",
    MAIN_BlackShop = "MAIN_BlackShop",
    MAIN_ASSEMBLE = "MAIN_ASSEMBLE",
    MAIN_INVESTIGATECENTER = "MAIN_INVESTIGATECENTER",
    MAIN_LADDERSCHALLENGE = "MAIN_LADDERSCHALLENGE",
    MAIN_BATTLEPASS = "MAIN_BATTLEPASS",
}

-- 开放功能ID作为索引键值，索引对应的字符串
FUNC_OPEN_STR = {
    -- 副本系列
    [FUNCTION_OPEN_TYPE.NORMALCARBON] = FUNC_OPNE_STATE.CARBON_NORMAL,
    [FUNCTION_OPEN_TYPE.ENDLESS] = FUNC_OPNE_STATE.CARBON_ENDLESS,
    [FUNCTION_OPEN_TYPE.TRIAL] = FUNC_OPNE_STATE.CARBON_TRIAL,
    [FUNCTION_OPEN_TYPE.ELITE] = FUNC_OPNE_STATE.CARBON_ELITE,

    -- 主界面系列
    [FUNCTION_OPEN_TYPE.SHOP] = FUNC_OPNE_STATE.MAIN_SHOP,
    [FUNCTION_OPEN_TYPE.ALLRANKING] = FUNC_OPNE_STATE.MAIN_RANK_LIST,
    [FUNCTION_OPEN_TYPE.ASPECT_STAR] = FUNC_OPNE_STATE.MAIN_WATCH_STAR,
    [FUNCTION_OPEN_TYPE.HERO_RESOLVE] = FUNC_OPNE_STATE.MAIN_HERO_RESOLVE,
    [FUNCTION_OPEN_TYPE.HAND_BOOK] = FUNC_OPNE_STATE.MAIN_HAND_BOOK,
    [FUNCTION_OPEN_TYPE.ARENA] = FUNC_OPNE_STATE.MAIN_AREAN,
    [FUNCTION_OPEN_TYPE.GUILD] = FUNC_OPNE_STATE.MAIN_GUILD,
    [FUNCTION_OPEN_TYPE.MONSTER_COMING] = FUNC_OPNE_STATE.MAIN_MONSTER_COMING,
    [FUNCTION_OPEN_TYPE.RECURITY] = FUNC_OPNE_STATE.MAIN_RECURITY,
    [FUNCTION_OPEN_TYPE.ELEMENT_RECURITY] = FUNC_OPNE_STATE.MAIN_ELEMENT_RECURITY,
    [FUNCTION_OPEN_TYPE.SECRETBOX] = FUNC_OPNE_STATE.MAIN_SECRETBOX,
    [FUNCTION_OPEN_TYPE.TALENT_TREE] = FUNC_OPNE_STATE.MAIN_TALENT_TREE,
    [FUNCTION_OPEN_TYPE.DIFFER_DEMONS] = FUNC_OPNE_STATE.MAIN_DIFFER_DEMONS,
    [FUNCTION_OPEN_TYPE.FIGHT_ALIEN] = FUNC_OPNE_STATE.MAIN_FIGHT_ALIEN,
    [FUNCTION_OPEN_TYPE.COMPOUND] = FUNC_OPNE_STATE.COMPOUND,
    [FUNCTION_OPEN_TYPE.ADJUTANT] = FUNC_OPNE_STATE.MAIN_ADJUTANT,
    [FUNCTION_OPEN_TYPE.CLIMB_TOWER] = FUNC_OPNE_STATE.MAIN_CLIMB_TOWER,
    [FUNCTION_OPEN_TYPE.HeroExchange] = FUNC_OPNE_STATE.MAIN_HeroExchange,
    [FUNCTION_OPEN_TYPE.BlackShop] = FUNC_OPNE_STATE.MAIN_BlackShop,
    [FUNCTION_OPEN_TYPE.ASSEMBLE] = FUNC_OPNE_STATE.MAIN_ASSEMBLE,
    [FUNCTION_OPEN_TYPE.InvestigateCenter] = FUNC_OPNE_STATE.MAIN_INVESTIGATECENTER,
    [FUNCTION_OPEN_TYPE.laddersChallenge] = FUNC_OPNE_STATE.MAIN_INVESTIGATECENTER,
    [FUNCTION_OPEN_TYPE.BattlePass] = FUNC_OPNE_STATE.MAIN_BATTLEPASS,
}

-- 地图中图标对应的ID
MapIconType = {
    ICON_EAG_MONSTER = 1,
    ICON_ELITE_MONSTER = 2,
    ICON_SUPPLY = 3,
    ICON_TRIAL_BOX = 4,
    ICON_OPEN_EYE = 6,
    ICON_NPC = 7,
    ICON_GOLD_BOX = 8,
    ICON_TRANSPORT = 9,
    ICON_EMPIC = 10,
    ICON_NEW_BOX = 11,
    ICON_BUSY_WANDER_MAN = 12,
    ICON_BEAR_MONSTER = 13,
    ICON_ATTACK_BUFF = 14,
    ICON_DEFEND_BUFF = 15,
    ICON_SPECIAL_BUFF = 16,
    ICON_INDIA_MONSTER = 17,
}
-- 巅峰赛状态
TOP_MATCH_STAGE = {
    -- 活动已结束
    OVER = -2,
    -- 未开启
    CLOSE = -1,
    -- 选拔赛
    CHOOSE = 1,
    -- 淘汰赛
    ELIMINATION = 2,
}
-- 巅峰赛状态
TOP_MATCH_TIME_STATE = {
    -- 活动已结束
    OVER = -2,
    -- 开启未参与
    CLOSE = -1,
    -- 参与状态
    OPEN_IN_READY = 0,
    OPEN_IN_GUESS = 1,--剩竞猜
    OPEN_IN_BATTLE = 2,
    -- 秋后算账
    OPEN_IN_END = 3,  --剩结算
    BARRLE_FIRST = 4, --三局第一场
    BARRLE_SECOND = 5,--三局第二场
}
-- 巅峰赛状态名称
TOP_MATCH_STATE_NAME = {
    [TOP_MATCH_TIME_STATE.CLOSE] = GetLanguageStrById(10123),
    [TOP_MATCH_TIME_STATE.OVER] = GetLanguageStrById(10124),
    [TOP_MATCH_TIME_STATE.OPEN_IN_READY] = GetLanguageStrById(12152),
    [TOP_MATCH_TIME_STATE.OPEN_IN_GUESS] = GetLanguageStrById(12152),--12153
    [TOP_MATCH_TIME_STATE.OPEN_IN_BATTLE] = GetLanguageStrById(12154),
    [TOP_MATCH_TIME_STATE.OPEN_IN_END] = GetLanguageStrById(12154),--10886
}

-- 东海寻仙弹窗类型
FIND_FAIRY_POPUP_TYPE = {
    ScoreReward = 1,--积分奖励
    FindFairyRecord = 2,--寻仙榜（记录）
    BigRank = 3,--排名大奖
    CurScoreRank = 4,--寻仙积分排行榜(本期排行)
}

--通用弹窗类型
GENERAL_POPUP_TYPE = { 
    ResolveRecall = 1,              -- 回溯
    ResolveDismantle = 2,           -- 献祭
    EquipCompound = 3,              -- 装备合成
    GuildSkill = 4,                 -- 公会技能返还
    TreasureCompound = 5,           -- 宝物合成
    GuildAid = 6,                   -- 公会援助
    GuildAidFindBoxReward = 7,      -- 公会援助查看宝箱奖励
    RecruitBox = 8,                 -- 点将台抽卡 奖励弹窗
    Onhook = 9,                     -- 挂机属性提升
    TrialSetting = 10,              -- 试练设置
    TrialXingYao = 11,              -- 试练性药
    TrialGain = 12,                 -- 试练增益
    ExpeditionReply = 13,           -- 大闹天宫  回复 和 复活节点
    TrialToNextFloor = 14,          -- 试炼副本进入下一层
    ResolveEquipTreasure = 15,      -- 分解宝物
    EquipBatchSell = 16,            -- 装备批量出售
    EquipSingleSell = 17,           -- 装备单种出售 拉条
    TrialBomb = 18,                 -- 次元炸弹
    RecruitConfirm = 19,            -- 神将召唤、限时召唤、乾坤宝盒 二次确认界面
    ResolveDebris = 20,             -- 碎片回收
    WarWayForget = 21,              -- 战法遗忘
    ClimbTowerBuy = 22,             -- 模拟战购买挑战
    GuildMemSet = 23,               -- 联盟成员转让提示
    GeneralPopup_HeroStarBack = 24, -- 改装厂回溯英雄返还提示
    DecomposePlan = 25,             -- 作战方案分解预览提示
    MedalSell = 26,                 -- 勋章售出
    AlameinBuy = 27,                -- 阿拉曼购买次数
    SheJiCheckGuild = 29,           -- 社稷大典检查是否加入公会
    YiJingBaoKuConfirm = 31,        -- 易经宝库奖励确认
    LingShouBaoGe = 33,             -- 灵兽宝阁选择神兽
    PartsReset = 34,                -- 部件重置
    TotemReset = 35,                -- 雷达重置
    OnrKeyResolveDismantle = 36,    -- 坦克一键回收
    FragmentAllCompound = 37,       -- 碎片一键合成
    UpGradePackage = 38,            -- 拍脸
    Recruit = 39,                   -- 抽卡
    Buy = 40,                       -- 购买
    Currency = 41,                  -- 通用
    Txt = 42,                       -- 文本
    Choose = 43,                    -- 选择
    Binding = 44,                   -- 绑定
    Reconfirm = 45,                 -- 再次确认
    GeneDecompose = 46,             -- 基因分解
    --大号通用弹窗
    YiJingBaoKu = 30,--易经宝库
    YiJingBaoKuRewardPreview = 32,--易经宝库奖励预览
}

--抽卡类型
RecruitType = {
    WaterTen = 1,           -- 水属性十抽
    WaterSingle = 2,        -- 水属性单抽
    FireTen = 3,            -- 火属性十抽
    FireSingle = 4,         -- 火属性单抽
    WindyTen = 5,           -- 风属性十抽
    WindySingle = 6,        -- 风属性单抽
    GroundTen = 7,          -- 地属性十抽
    GroundSingle = 8,       -- 地属性单抽
    LightDarkTen = 9,       -- 光暗属性十抽
    LightDarkSingle = 10,   -- 光暗属性单抽
    Ten = 11,               -- 钻石招募十连(神将召唤)
    Single = 12,            -- 钻石招募单抽(神将召唤)
    TimeLimitSingle = 13,   -- 限时招募单抽
    TimeLimitTen = 14,      -- 限时招募十连
    QianKunBoxSingle = 15,  -- 乾坤宝囊单抽
    QianKunBoxTen = 16,     -- 乾坤宝囊十连
    FriendTen = 23,         -- 友情招募 多次
    FriendSingle = 24,      -- 友情招募 单次
    NormalTen = 25,         -- 普通招募 多次
    NormalSingle = 26,      -- 普通招募 单次
    RecruitBox = 27,        -- 仙缘招募
    ProveUpOne = 34,        -- 勘探次数单次
    ProveUpTen = 35,        -- 勘探次数多次
    --炮击演练
    YanxiOne = 6001,        -- 演习炮弹单次
    YanxiTen = 6002,        -- 演习炮弹多次
    ShizhanOne = 6003,      -- 实战炮弹单次
    ShizhanTen = 6004,      -- 实战炮弹多次

    -- FindFairySingle = 13,   -- 东海寻仙单抽
    -- FindFairyTen = 14,      -- 东海寻仙十连
}

ItemBaseType = {
    Equip = 1,          --部件(装备)
    Special = 2,        --道具(特殊)
    HeroChip = 3,       --材料(碎片)
    Project = 4,        --方案
    Medal = 5,          --勋章
    Gene = 7,           --基因
    DemonSoul = 93,     --妖魂
    EquipTreasure = 95, --宝器
    SoulPrint = 96,     --魂印
    Materials = 97,     --材料
}

--探宝类型
 TreasureType = {
    Lucky = 30,
    Advanced = 31,
}
--拍脸类型
FacePanelType = {
    Sbtj = 1,               -- 神兵天降
    Tesc = 2,               -- 天恩神赐
    GuildFight = 3,         -- 公会战
    SupremeHero = 4,        -- 萌新活动
    GrowGift = 5,           -- 五星成长礼
    Championship = 6,       -- 巅峰战
    FindFairy = 7,          -- 寻仙
    UpgradePac = 8,         -- 升级限时礼包
    OpenLevel = 9,          -- 通关限时礼包
    BattleFailGift = 10,    -- 战斗失败礼包
    ValueDiscountGift = 11, -- 超值折扣礼包
    NewGrowGift = 15,       -- 新五星成长礼
    GrowGift6 = 16,         -- 六星成长礼
    GrowGift7 = 17,         -- 七星成长礼
    GrowGift8 = 18,         -- 八星成长礼
    GrowGift9 = 19,         -- 九星成长礼
    GrowGift10 = 20,        -- 十星成长礼
    guard = 21,             -- 守护
}

--迷宫寻宝条件类型
FindTreasureNeedType = {
    Star = 1,   -- 星级
    Pro = 2,    -- 元素
    Level = 3,  -- 等级
}

--迷宫寻宝条件类型
FindTreasureVipTypeSprite = {
    [1] = "cn2-X1_xunluo_xunluotequan",-- 普通寻宝
    [2] = "cn2-X1_xunluo_xunluotequan",-- 高级寻宝
    [3] = "x_xb_haohua",           -- 豪华寻宝
}
FindTreasureVipTextTypeSprite = {
    [1] = "m5_img_tansuo-putongxunbao",-- 普通寻宝
    [2] = "m5_img_tansuo-gaojixunbao", -- 高级寻宝
    [3] = "m5_img_tansuo-huahaoxunbao",-- 豪华寻宝
}
FindTreasureVipImageTypeSprite = {
    [1] = "N1_btn_xunluo_xunluo04",     -- 普通寻宝
    [2] = "m5_img_tansuo-putong",       -- 高级寻宝
    [3] = "m5_img_tansuo-huahaoxunbao", -- 豪华寻宝
}
--[[
FindTreasureVipTypeSprite = {
    [1] = "x_xb_putong",--普通寻宝
    [2] = "x_xb_gaoji",--高级寻宝
    [3] = "x_xb_haohua",--豪华寻宝
}
FindTreasureVipTextTypeSprite = {
    [1] = "m5_img_tansuo-putongxunbao",--普通寻宝
    [2] = "m5_img_tansuo-gaojixunbao",--高级寻宝
    [3] = "m5_img_tansuo-huahaoxunbao",--豪华寻宝
}
FindTreasureVipImageTypeSprite = {
    [1] = "m5_img_tansuo-putong",--普通寻宝
    [2] = "m5_img_tansuo-putong",--高级寻宝
    [3] = "m5_img_tansuo-huahaoxunbao",--豪华寻宝
}
]]
--迷宫寻宝条件类型
FindTreasureMissionTitleTypeSprite = {
    [1] = "cn2-x1_DB_nandubiaoqian_01",
    [2] = "cn2-x1_DB_nandubiaoqian_02",
    [3] = "cn2-x1_DB_nandubiaoqian_03",
    [4] = "cn2-x1_DB_nandubiaoqian_04",
    [5] = "cn2-x1_DB_nandubiaoqian_04",
    [6] = "cn2-x1_DB_nandubiaoqian_04",
}
--[[
FindTreasureMissionTitleTypeSprite = {
    [1] = "m5_img_tansuo-di5",
    [2] = "m5_img_tansuo-di5",
    [3] = "m5_img_tansuo-di4",
    [4] = "m5_img_tansuo-di3",
    [5] = "m5_img_tansuo-di2",
    [6] = "m5_img_tansuo-di1",
}
]]
FindTreasureMissionTitleTypeStr = {
    [1] = GetLanguageStrById(10352),
    [2] = GetLanguageStrById(12155),
    [3] = GetLanguageStrById(12156),
    [4] = GetLanguageStrById(12157),
    [5] = GetLanguageStrById(12158),
    [6] = GetLanguageStrById(12159),
}

-- 特权奖励
VIP_LEVEL_REWARD = {
    -- [1] = "N1_imgtxt_chongzhi_jiangli01_zh",
    -- [2] = "N1_imgtxt_chongzhi_jiangli02_zh",
    -- [3] = "N1_imgtxt_chongzhi_jiangli03_zh",
    -- [4] = "N1_imgtxt_chongzhi_jiangli04_zh",
    -- [5] = "N1_imgtxt_chongzhi_jiangli05_zh",
    -- [6] = "N1_imgtxt_chongzhi_jiangli06_zh",
    -- [7] = "N1_imgtxt_chongzhi_jiangli06_zh",
    -- [8] = "N1_imgtxt_chongzhi_jiangli07_zh",
    -- [9] = "N1_imgtxt_chongzhi_jiangli07_zh",
    -- [10] = "N1_imgtxt_chongzhi_jiangli08_zh",
    -- [11] = "N1_imgtxt_chongzhi_jiangli09_zh",
    -- [12] = "N1_imgtxt_chongzhi_jiangli09_zh",
    -- [13] = "N1_imgtxt_chongzhi_jiangli10_zh",
    -- [14] = "N1_imgtxt_chongzhi_jiangli11_zh",
    -- [15] = "N1_imgtxt_chongzhi_jiangli12_zh",
    -- [16] = "N1_imgtxt_chongzhi_jiangli13_zh",
    -- [17] = "N1_imgtxt_chongzhi_jiangli14_zh",
    -- [18] = "N1_imgtxt_chongzhi_jiangli15_zh",
}

-- 性别定义
ROLE_SEX = {
    BOY = 0,
    SLUT = 1,
}

SALARY_TYPE = {
    BASE_128 = 33,
    BASE_328 = 34,
}

ExpeditionNodeState = {
    No = 0,
    NoPass = 1,
    NoGetEquip = 2,
    Finish = 3,
    Over = 4,
}
--远征节点类型
ExpeditionNodeType = {
    Star = 0,       -- 初始节点
    Jy = 1,         -- 精英节点
    Boss = 2,       -- 首领节点
    Resurgence = 3, -- 复活节点
    Reply = 4,      -- 回复节点
    Common = 5,     -- 普通节点
    Halidom = 6,    -- 圣物节点
    Recruit = 7,    -- 招募节点
    Shop = 8,       -- 商店节点
    Trail = 9,      -- 试炼节点
    Greed = 10,     -- 贪婪节点
    Reward = 11,    -- 最后奖励节点
}

--- 奖池预览类型
PRE_REWARD_POOL_TYPE = {
    RECRUIT = 1,            -- 钻石
    FRIEND = 2,             -- 友情
    NORMAL = 3,             -- 普通
    ELEMENT_RECRUIT = 4,    -- 元素
    LUCK_FIND = 5,          -- 幸运探宝
    UPPER_LUCK_FIND = 6,    -- 高级探宝
    GHOST_FIND = 7,         -- 东海寻鬼
    TIME_LIMITED = 8,       -- 限时招募
    TIME_LIMITED_UP = 9,    -- 限时招募UP
    LOTTERY_SOUL = 10,      -- 魂印抽取
    LOTTERY_SOUL_UP = 11,   -- 魂印抽取UP
    CARDACTIVITY = 52,      -- 卡牌主题活动
}
DirectBuyType = {
    XSHL = 11,--限时豪礼
    TGCF = 12,--天官赐福
    MRXY = 13,--每日仙缘
    DAILY_GIFT = 14,        -- 每日礼包
    WEEK_GIFT = 15,         -- 每周礼包
    MONTH_GIFT = 16,        -- 月礼包
    FINDTREASURE_GIFT = 17, -- 极速探索特权
}
--新月卡类型定义
MONTH_CARD_TYPE = {
    MONTHCARD = 1,
    LUXURYMONTHCARD = 2,
}
--战力类型
WarPowerTypeAllNum = 7--战力类型总数量  下边结构加一种类型 此数值 + 1
WarPowerType = {
    Hero = 1,       -- 英雄自身 被动技（天赋）
    Talisman = 2,   -- 英雄自身法宝 被动技
    SoulPrint = 3,  -- 英雄穿戴魂印 被动技
    WarWayAndCombatPlan = 4, -- 战法和作战方案
    medalSuit =5,   -- 勋章套装被动技能
    Talent = 6,     -- 特性 天赋
    Totem = 7       -- 图腾
}
EquipTreasureTypeStr = {
    [1] = GetLanguageStrById(10505),
    [2] = GetLanguageStrById(10506),
}
--[[
 SkillIconType = {
    "m5_img_skilltype_pu",
    "m5_img_skilltype_nu",
    "m5_img_skilltype_bei"
 }
]]
GuildSkillType = {
    [1] = GetLanguageStrById(12162),
    [2] = GetLanguageStrById(12161),
    [3] = GetLanguageStrById(12160),
    [4] = GetLanguageStrById(12163),
}

--公会十绝阵 阶段类型 -1开服几天内未开 0未开启 1挑战 2领奖
DeathPosStatus = {
    Death = -1,
    Close = 0,
    Fight = 1,
    Reward = 2,
    Belated = 0,--十绝阵开启才加入工会
}
--公会车迟 阶段类型 1挑战 2间歇 3抢夺
GuildCarDelayProType = {
    Challenge = 1,
    Interval = 2,
    Loot = 3
}
--猎妖弹窗类型
EXPEDITON_POPUP_TYPE = {
    Recruit = 1,-- 招募
    Shop = 2,   -- 商店
    Monster = 3,-- 普通 精英 boss
    Trail = 4,  -- 试炼
    Greed = 5,  -- 贪婪
}

RankKingList = {
    [3] = {
        bgImage = "cn2-X1_paihangbang_ditu05",
        name = GetLanguageStrById(50205),
        Id = 36,   --check
        rankType = RANK_TYPE.HERO_FORCE_RANK,
        activiteId = 0,
        isRankingMainPanelShow = true,
        nameImage = ""},
    [1] = {
        bgImage = "cn2-X1_paihangbang_ditu01",
        name = GetLanguageStrById(12164),
        Id = 26,
        rankType = RANK_TYPE.FIGHT_LEVEL_RANK,
        activiteId = 0,
        isRankingMainPanelShow = true,
        nameImage = ""},
    [2] = {
        bgImage = "cn2-X1_paihangbang_ditu02",
        name = GetLanguageStrById(12165),
        Id = 55,
        rankType = RANK_TYPE.FORCE_CURR_RANK,
        activiteId = 0,
        isRankingMainPanelShow = true,
        nameImage = ""},
    [9] = {
        bgImage = "cn2-X1_paihangbang_ditu03",
        name = GetLanguageStrById(12166),
        Id = 4,
        rankType = RANK_TYPE.GUILD_FORCE_RANK,
        activiteId = 0,
        isRankingMainPanelShow = true,
        nameImage = ""},
    [4] = {
        bgImage = "cn2-X1_paihangbang_ditu04",
        name = GetLanguageStrById(12665),
        Id = 85,
        rankType = RANK_TYPE.CLIMB_TOWER,
        activiteId = 0,
        isRankingMainPanelShow = true,
        nameImage = ""},
    -- [4] = {  bgImage = "cn2-X1_paihangbang_ditu04",
    --     name = GetLanguageStrById(12167),
    --     Id = 44,
    --     rankType = RANK_TYPE.MONSTER_RANK,
    --     activiteId = 0,
    --     isRankingMainPanelShow = false,
    --     nameImage = ""},
    [5] = {
        bgImage = "cn2-x1_paihangbang_banner_05",
        name = GetLanguageStrById(12168),
        Id = 42,
        rankType = RANK_TYPE.GOLD_EXPER,
        activiteId = ActivityTypeDef.GoldExper,
        isRankingMainPanelShow = false,
        nameImage = ""},
    [6] = {
        bgImage = "",
        name = GetLanguageStrById(12240),
        Id = 8,
        rankType = RANK_TYPE.ARENA_RANK,
        activiteId = 0,
        isRankingMainPanelShow = false,
        nameImage = ""},
    [7] = {
        bgImage = "",
        name = GetLanguageStrById(50273),
        Id = 62,
        rankType = RANK_TYPE.GUILDTRANSCRIPT,
        activiteId = 0,
        isRankingMainPanelShow = false},
    [8] = {
        bgImage = "",
        name = GetLanguageStrById(22533),
        Id = 89,
        rankType = RANK_TYPE.ALAMEIN_WAR,
        activiteId = 0,
        isRankingMainPanelShow = false,
        nameImage = ""},
    [13] = {
        bgImage = "",
        name = GetLanguageStrById(11033),
        Id = 42,
        rankType = RANK_TYPE.GOLD_EXPER,
        activiteId = ActivityTypeDef.Celebration,
        isRankingMainPanelShow = false},
    [14] = {
        bgImage = "",
        name = GetLanguageStrById(11032),
        Id = RANK_TYPE.CELEBRATION_GUILD,
        rankType = RANK_TYPE.CELEBRATION_GUILD,
        activiteId = ActivityTypeDef.Celebration,
        isRankingMainPanelShow = false},
    [15] = {
        bgImage = "",
        name = GetLanguageStrById(50274),
        Id = 42,
        rankType = RANK_TYPE.GOLD_EXPER,
        activiteId = ActivityTypeDef.RecruitExper,
        isRankingMainPanelShow = false,
        nameImage = ""},
}

SoulPrintSpriteByQuantity = {
    [0] = { circle = "m5_img_jiban_juesekuang_zi", circleBg1 = "m5_img_jiban_juesekuang_kong",circleBg2 = "m5_img_jiban_juesekuang_kong"},--未装备时的显示图片
    [4] = { circle = "m5_img_jiban_juesekuang_zi", circleBg1 = "m5_img_jiban_juesekuang_zi",circleBg2 = "m5_img_jiban_juesekuang_kong"},
    [5] = { circle = "m5_img_jiban_juesekuang_huang", circleBg1 = "m5_img_jiban_juesekuang_huang",circleBg2 = "m5_img_jiban_juesekuang_kong"},
    [6] = { circle = "m5_img_jiban_juesekuang_hong", circleBg1 = "m5_img_jiban_juesekuang_hong",circleBg2 = "m5_img_jiban_juesekuang_kong"},
    [7] = { circle = "m5_img_jiban_juesekuang_hong", circleBg1 = "m5_img_jiban_juesekuang_hong",circleBg2 = "m5_img_jiban_juesekuang_kong"},
}
HeroPanelBgByPropertyName = {
    [1] = "r_hero_bg_ren",--人
    [2] = "r_hero_bg_fo",--佛
    [3] = "r_hero_bg_yao",--妖
    [4] = "r_hero_bg_dao",--道
}

-- 阵营Tab
CampTabSelectPic = {[0] = {GetPictureFont("cn2-X1_tongyong_zhenying_01"), "cn2-x1_AN_shuxing_xuanzhong"},
                    [1] = {"cn2-X1_tongyong_zhenying_04", "cn2-x1_AN_shuxing_xuanzhong"},
                    [2] = {"cn2-X1_tongyong_zhenying_02", "cn2-x1_AN_shuxing_xuanzhong"},
                    [3] = {"cn2-X1_tongyong_zhenying_03", "cn2-x1_AN_shuxing_xuanzhong"},
                    [4] = {"cn2-X1_tongyong_zhenying_06", "cn2-x1_AN_shuxing_xuanzhong"},
                    [5] = {"cn2-X1_tongyong_zhenying_05", "cn2-x1_AN_shuxing_xuanzhong"},}

X1CampTabSelectPic = {[0] = GetPictureFont("cn2-X1_tongyong_zhenying_01"),
                    [1] = "cn2-X1_tongyong_zhenying_04",
                    [2] = "cn2-X1_tongyong_zhenying_02",
                    [3] = "cn2-X1_tongyong_zhenying_03",
                    [4] = "cn2-X1_tongyong_zhenying_06",
                    [5] = "cn2-X1_tongyong_zhenying_05",}


--副本玩法类型
CarBonTypeId = {
    TRIAL = 1,  --异端之战
    ENDLESS = 2,
}

ItemCornerType = {
    FirstPass = 1, -- 首通
    Lock = 2,      -- 锁
}

---角色动画名字
RoleAnimationName = {
    Stand = "Stand",    --待机
    Run = "Run",        --跑
    Hurt = "Hurt",      --倒地
    Attack = "Attack",  --攻击
    Skill_01 = "Skill_01",  --技能1
    Skill_02 = "Skill_02",  --技能2
    Injured = "Injured", --受击
}

MoneyType = {
    RMB = 1,    -- 人民币
    USD = 2     -- 美元
}
-- 首充显示
IndexValueDefType = {
    [MoneyType.RMB] = {
        [1] = 6,    --首充6元
        [2] = 100,  --首充100元
        [6] = 1,    --首充6元
        [100] = 2,  --首充100元
    },
    [MoneyType.USD] = {
        [1] = 1,    --首充1美元
        [2] = 15,   --首充15美元
        [1] = 1,    --首充1美元
        [15] = 2,   --首充15美元
    },
}

--公会职位文字
JobString = {
    [0] = "",
    [1] = GetLanguageStrById(12129),    --会长
    [2] = GetLanguageStrById(12130),    --官员
    [3] = GetLanguageStrById(12131),    --成员
}
--[[
--卡牌详情星级底板
HeroStarBackground = {
    [1] = "N1_bg_tanke_lvsebeijng",
    [2] = "N1_bg_tanke_lvsebeijng",
    [3] = "N1_bg_tanke_lansebeijng",
    [4] = "N1_bg_tanke_zisebeijng",
    [5] = "N1_bg_tanke_chengsebeijng",
    [6] = "N1_bg_tanke_hongsebeijng",
    [7] = "N1_bg_tanke_hongsebeijng",
    [8] = "N1_bg_tanke_hongsebeijng",
    [9] = "N1_bg_tanke_hongsejiabeijng",
    [10] = "N1_bg_tanke_hongsejiabeijng",
    [11] = "N1_bg_tanke_hongsejiabeijng",
    [12] = "N1_bg_tanke_hongsejiabeijng",
    [13] = "N1_bg_tanke_hongsejiabeijng"
}
]]

Thumbsup = {
    [1] = GetPictureFont("cn2-X1_jingjichang_dianzan"),
    [2] = GetPictureFont("cn2-X1_jingjichang_yizan"),
}

--战令类型--对应OperatingPanel的Tab页
WarOrderType = {
    [15] = 1503,   --爬塔
    [16] = 1502,   --魔之塔
    [17] = 1504,   --异端
    [18] = 1505,   --迷雾
    [19] = 1506,   --深渊
}

PlayerInfoType = {
    None = 0,           --默认
    CSArena = 1,        --跨服竞技场
    CSGuildBattle = 2,  --跨服公会战
}