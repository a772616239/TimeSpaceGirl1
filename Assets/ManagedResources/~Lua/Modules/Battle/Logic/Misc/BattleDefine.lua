local index = 0
local function indexAdd()
    index = index + 1
    return index
end

BattleEventName = {
    BattleOrderChange = indexAdd(),
    BattleOrderEnd = indexAdd(),
    BeforeBattleEnd = indexAdd(),
    BattleEnd = indexAdd(),
    BattleEndClearSceneRoles = indexAdd(),
    AddRole = indexAdd(),
    RemoveRole = indexAdd(),
    BattleRoleDead = indexAdd(),
    BattleRoundChange = indexAdd(),
    BattleRoundCheck =indexAdd(),
    BattleRoundBeginDialogue = indexAdd(),

    RoleCheckForbear = indexAdd(),
    RoleBeCheckForbear = indexAdd(),
    RoleBeDamaged = indexAdd(),
    RoleDamage = indexAdd(),
    RoleBeDamagedBefore = indexAdd(),
    RoleDamageBefore = indexAdd(),
    RoleBeDamagedAfter = indexAdd(),
    RoleDamageAfter = indexAdd(),
    RoleBeTreated = indexAdd(),
    RoleTreat = indexAdd(),
    RoleBeHealed = indexAdd(),
    RoleBeCrit = indexAdd(),
    RoleCrit = indexAdd(),
    RoleBeSeal = indexAdd(), --封印
    RoleSeal = indexAdd(), 
    RoleBeHit = indexAdd(),
    RoleHit = indexAdd(), --造成伤害，dot情况排除
    RoleHitGeneralAttackCheck = indexAdd(),--攻击时额外普攻检测
    RoleHitDoubleHitCheck = indexAdd(),--攻击时连击检测
    RoleBeDodge = indexAdd(),
    RoleDodge = indexAdd(),
    RoleDead = indexAdd(),
    RoleKill = indexAdd(),--击杀
    RoleKillSkillPursueAttackCheck = indexAdd(),--击杀后追击技能检测
    RoleKillGeneralAttackPursueAttackCheck = indexAdd(),--击杀后追击普攻检测
    RolePropertyChanged = indexAdd(),
    RoleCDChanged = indexAdd(),
    RoleTurnStart = indexAdd(),     -- 角色回合开始
    RoleTurnEnd = indexAdd(),       -- 角色回合结束
    RoleRageGrow = indexAdd(),      -- 角色怒气成长
    RoleRageCost = indexAdd(),      -- 角色怒气消耗
    -- RoleRageChange = indexAdd(),    -- 角色怒气变化
    RoleRealDead = indexAdd(),      -- 角色真死了
    RoleRelive = indexAdd(),        -- 角色复活了
    FinalDamage = indexAdd(),
    FinalBeDamage = indexAdd(),

    HitMiss = indexAdd(),
    BeHitMiss = indexAdd(),

    CritMiss = indexAdd(),          --< 暴击miss
    BeCritMiss = indexAdd(),          --< 暴击miss
    CritDamageReduceFactor = indexAdd(),    -- 暴击伤害减免系数

    SkillSelectBefore = indexAdd(),  --< 技能目标选择前
    SkillCast = indexAdd(),         -- 技能攻击前
    SkillCastEnd = indexAdd(),      -- 技能攻击结束
    BeSkillCast = indexAdd(),       -- 被技能攻击前
    BeSkillCastEnd = indexAdd(),    -- 被技能攻击结束
    SkillRandomBuff = indexAdd(),   -- 技能控制时
    SkillEffectBefore = indexAdd(),   -- 技能效果触发前All
    BeSkillEffectBefore = indexAdd(),   -- 技能效果触发前
    SkillFirstEffectTrigger = indexAdd(),   --< 技能第一效果到位时触发 在效果前触发
    SkillLastEffectTrigger = indexAdd(),    --< 技能最后效果到位时触发 在效果后触发

    SkillFireOnce = indexAdd(),     --< 技能单次炮击
    SkillFireAll = indexAdd(),      --< 技能单次攻击所有 无炮击效果
    AddUnit = indexAdd(),           --< 加战斗单元
    RemoveUnit = indexAdd(),        --< 减战斗单元

    PassiveTreating = indexAdd(),
    PassiveBeTreated = indexAdd(),
    PassiveBeDamaging = indexAdd(),
    PassiveDamaging = indexAdd(),
    PassiveCriting = indexAdd(),
    PassiveTreatingFactor = indexAdd(),
    PassiveBeTreatedFactor = indexAdd(),
    PassiveRandomControl = indexAdd(),
    PassiveBeRandomControl = indexAdd(),
    PassiveRandomFinalControl = indexAdd(),     --< 修正最终控制率
    PassiveBeRandomFinalControl = indexAdd(),   --< 修正最终控制率
    PassiveRandomDot = indexAdd(),
    PassiveBeRandomDot = indexAdd(),

    TriggerDamaging = indexAdd(),
    TriggerBeDamaging = indexAdd(),
    TriggerBeDamageEnd = indexAdd(),
    
    PassiveRebackDamage = indexAdd(),
    PassiveBeRebackDamage = indexAdd(),

    PassiveSkillDamageHeal = indexAdd(),
    PassiveBeSkillDamageHeal = indexAdd(),

    PassiveSeckill = indexAdd(),
    PassiveBeSeckill = indexAdd(),
    Seckill = indexAdd(),
    BeSeckill = indexAdd(),

    PassiveDamageShare = indexAdd(),
    PassiveDamageBeShare = indexAdd(),

    PassiveShield = indexAdd(),
    PassiveBeShield = indexAdd(),


    AOE = indexAdd(),

    RoleViewBullet = indexAdd(), --弹道飞行击中表现

    RoleAddBuffMiss = indexAdd(),

    BuffCaster = indexAdd(),
    BuffStart = indexAdd(),
    BuffDodge = indexAdd(),
    BuffTrigger = indexAdd(),
    BuffEnd = indexAdd(),
    BuffCover = indexAdd(),
    BuffRoundChange = indexAdd(),
    BuffDurationChange = indexAdd(),
    BuffAuraTrigger = indexAdd(),
    BuffPropertyChangeIcebound = indexAdd(),

    ShildValueChange = indexAdd(),
    ShildTrigger = indexAdd(),
    ShildReduce = indexAdd(),
    ShildBeReduce = indexAdd(),

    Curse_ShareDamage = indexAdd(),
    Be_Curse_ShareDamage = indexAdd(),
    ImmuneTrigger =indexAdd(),

    SkillTargetCheck = indexAdd(),

    DebugStop = indexAdd(),

    FloatTotal = indexAdd(),

    IgnoreDefFactor = indexAdd(),
    BeIgnoreDefFactor = indexAdd(),

    SkillTextFloating = indexAdd(),

    RoundBegin = indexAdd(),-- 单轮回合开始
    Rounding = indexAdd(),-- 单轮回合中
    RoundEnd = indexAdd(),--  单轮回合结束

    FlagCritReset = indexAdd();

    RoleRealRelive = indexAdd();


    OnAddTibuRole = indexAdd(), -- 替补角色
    BattleTibuRoundBegin = indexAdd(), -- 替补回合开始
    BattleTibuRoundEnd = indexAdd(), -- 替补回合结束
    CheckFrame = indexAdd(),
}

index = 0
RoleDataName = {
    Level = indexAdd(), --等级
    Hp = indexAdd(), --生命
    MaxHp = indexAdd(), --最大生命
    Attack = indexAdd(), --攻击力
    PhysicalDefence = indexAdd(),--护甲
    MagicDefence = indexAdd(),--魔抗
    Speed = indexAdd(),--速度
    DamageBocusFactor = indexAdd(), --伤害加成系数（%）
    DamageReduceFactor = indexAdd(), --伤害减免系数（%）
    Hit = indexAdd(), --施法率（%）                                                 --< 10
    Dodge = indexAdd(), --后期基础施法率（%）
    Crit = indexAdd(), --暴击率（%）
    CritDamageFactor = indexAdd(), --暴击伤害系数（%）
    Tenacity = indexAdd(), --抗暴率（%）
    TreatFacter = indexAdd(),--治疗加成系数（%）
    CureFacter = indexAdd(),--受到治疗加成系数（%）

    PhysicalDamage = indexAdd(),            --< 物伤
    MagicDamage = indexAdd(),               --< 法伤
    PhysicalImmune = indexAdd(),            --< 物免
    MagicImmune = indexAdd(),               --< 法免                                --< 20
    SpeedAddition = indexAdd(),             --< 速度加成
    AttackAddition = indexAdd(),            --< 攻击加成                      
    ArmorAddition = indexAdd(),             --< 护甲加成
    ControlProbability = indexAdd(),        --< 控制几率
    ControlResist = indexAdd(),             --< 控制抵抗

    SkillDamage             = indexAdd(),               --< 技能伤害
    DamageToMage            = indexAdd(),               --< 对高爆型伤害
    DamageToFighter         = indexAdd(),               --< 对穿甲型伤害
    DamageToDefender        = indexAdd(),               --< 对防御型伤害
    DamageToHealer          = indexAdd(),               --< 对辅助型伤害            --< 30
    DefenceFromFighter      = indexAdd(),               --< 受穿甲型伤害降低
    DefenceFromMage         = indexAdd(),               --< 受高爆型伤害降低
    DefenceFromDefender     = indexAdd(),               --< 受防御型伤害降低
    DefenceFromHealer       = indexAdd(),               --< 受辅助型伤害降低
    CriDamageReduceRate     = indexAdd(),               --< 暴伤抵抗
    HealCritical            = indexAdd(),               --< 修理暴击
    HealCriEffect           = indexAdd(),               --< 修理暴击效果
    MaxHpPercentage         = indexAdd(),               --< 生命加成

    PVPDamageBocusFactor    = indexAdd(),               --<  pvp 增伤
    PVPDamageReduceFactor   = indexAdd(),               --<  pvp 减伤
    PhysicalRateIncrease    = indexAdd(),               --<  勇气
    MagicRateIncrease       = indexAdd(),               --<  信念
    Accurate                = indexAdd(),               --<  精准
    
}

BuffName = {
    PropertyChange = "PropertyChange",
    HOT = "HOT",
    DOT = "DOT",
    Control = "Control",
    Aura = "Aura",
    Brand = "Brand",
    Shield = "Shield",
    Immune = "Immune",
    NoDead = "NoDead",
    Curse = "Curse",
    BEffect = "BEffect",
    Bond = "Bond",
}

BEffectType = {
    BaZhenTu = 1,
}

DotType = {
    All = 0,
    Burn = 1,
    Poison = 2,
    Blooding = 3,
}

ControlType = {
    Dizzy = 1,
    Slient = 2,
    LockTarget = 3,
    NoHeal = 4,
    Blind = 5,

    Palsy = 7,
    Frozen = 8,
    Chaos = 9,
}

BattleSkillType = {
    Monster = 0,
    Normal = 1, 
    Special = 2,
}

SkillBaseType = {
    Physical = 1,
    Magic = 2
}

SkillSlotPos = {
    Slot_0 = 0,
    Slot_1 = 1,
    Slot_2 = 2,
    Slot_3 = 3,
    Slot_4 = 4,
}

CountTypeName = {
    Add = 1,
    AddPencent = 2,
    Sub = 3,
    SubPencent = 4,
    Cover = 5,
}

ShieldTypeName = {
    NormalReduce = 1,   -- 固定值减伤A
    RateReduce = 2,     -- 百分比减伤
    AllReduce = 3,      -- 无敌护盾
}

--> 属性状态
PropertyChangeType = {
    ReduceSpeed = 1,        --< 减速
    PenetrationArmor = 2,   --< 破甲
    Admonish = 3,           --< 训诫
    Icebound = 4,           --< 冰封结界
}

--> 属性状态映射属性
PropertyChangeTypeMap = {
    RoleDataName.Speed,
    RoleDataName.ArmorAddition,
    RoleDataName.AttackAddition,
    RoleDataName.AttackAddition,
    RoleDataName.DamageReduceFactor,
    RoleDataName.PhysicalImmune,
}

--> BrandFlag
BrandType = {
    ReBound                 = 1,            --< 反伤
    Attention               = 2,            --< 关注
    Protect                 = 3,            --< 保护
    Angry                   = 4,            --< 怒气
    Sign                    = 5,            --< 标识
    MagicSeed               = 6,            --< 魔种
    WithStand               = 7,            --< 无懈可击
    jueqing                 = 8,            --< 绝情
    TreatCutDebuff          = 9,            --< 治疗去debuff
    curse                   = 10,           --< 诅咒
    wild                    = 11,           --< 野心
    CantRelive              = 12,            --< 无法复活
    buquyizhi              = 13,            --< 不屈意志
}

--> FightUnit类型
FightUnitType = {
    UnitSupport = 1,             --< 守护 原坦克的支援
    UnitAircraftCarrier = 2,     --< 航母
    UnitAdjutant = 3,            --< 先驱 原坦克的副官

}

-- 战斗表属性id对应战斗中属性数据
BattlePropList = {
    RoleDataName.Attack,
    RoleDataName.PhysicalDefence,
    RoleDataName.MagicDefence,
    RoleDataName.Speed,
    RoleDataName.DamageBocusFactor,
    RoleDataName.DamageReduceFactor,
    RoleDataName.Hit,
    RoleDataName.Dodge,
    RoleDataName.Crit,
    RoleDataName.CritDamageFactor,              --< 10
    RoleDataName.TreatFacter,
    RoleDataName.MaxHp,
    RoleDataName.Hp,
    RoleDataName.CureFacter,
    RoleDataName.Tenacity,
    99999,  --< 怒气删除了 补位
    RoleDataName.PhysicalDamage,
    RoleDataName.MagicDamage,
    RoleDataName.PhysicalImmune,
    RoleDataName.MagicImmune,                   --< 20
    RoleDataName.SpeedAddition,
    RoleDataName.AttackAddition,
    RoleDataName.ArmorAddition,
    RoleDataName.ControlProbability,
    RoleDataName.ControlResist,
    RoleDataName.MaxHpPercentage,
    RoleDataName.HealCritical,
    RoleDataName.HealCriEffect,
}

CurseTypeName = {
    ShareDamage = 1,
}


OutDataName = {
    DarkGlowBallNum = 1,
    DaNaoTianGongFloor = 2,
    PerpleGloryItemNum = 3,
    OrangeGloryItemNum = 4,
    MisteryLiquidUsedTimes = 5
}

-- 从0 开始
BattleTankFrame = {
    IdleFrame = 6
}

--> 战法类型
WarWayType = {
    W_6001 = 6001,  --< 敏捷
    W_6002 = 6002,  --< 物连
    W_6003 = 6003,  --< 法连
    W_6004 = 6004,  --< 法力
    W_6005 = 6005,  --< 武力
    W_6009 = 6009,  --< 必杀
    W_6020 = 6020,  --< 躲闪
    W_6025 = 6025,  --< 回春
    W_6026 = 6026,  --< 还魂
    W_6027 = 6027,  --< 复活
    W_6031 = 6031,  --< 医术
}

SkillSubType = {
    Normal      = 1,   --< 正常技能
    BeatBack    = 2,   --< 反击
}

SkillEffectFirstPropty={ --<主动技能有限级别
    AtOnce = 9999999999,
    P2 = 1000,
    P1 = 100,
    P0 = 10,
    BeforeFirst = 3,
    First = 2,
    Normal = 1,
    Delay = 0.1,
    AfterDelay = 0.2,
    A0 = 0.01,
    A1 = 0.001,
    A2 = 0.0001,
    Latest = 0.00000000001
}

--1 燃烧 2 中毒 3 流血  4 点燃  5 洪荒烈火  6 业火 7 诅咒
BuffDamageType={
    All = 0,
    Burn = 1,
    Poison = 2,
    Blooding = 3,
    Fired = 4,
    Flood = 5,
    Hellfire = 6,
    Curse = 7
}




































