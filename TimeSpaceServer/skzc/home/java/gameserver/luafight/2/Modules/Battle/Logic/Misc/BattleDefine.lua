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
    AddRole = indexAdd(),
    RemoveRole = indexAdd(),
    MpChanged = indexAdd(),
    MpAdd = indexAdd(),
    MpSub = indexAdd(),
    BattleRoleDead = indexAdd(),
    BattleSkillUsable = indexAdd(),
    BattleRoundChange = indexAdd(),

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
    RoleBeHit = indexAdd(),
    RoleHit = indexAdd(), --造成伤害，dot情况排除
    RoleBeDodge = indexAdd(),
    RoleDodge = indexAdd(),
    RoleDead = indexAdd(),
    RoleKill = indexAdd(),
    RoleRevive = indexAdd(),
    RolePropertyChanged = indexAdd(),
    RoleCDChanged = indexAdd(),
    RoleTurnStart = indexAdd(),     -- 角色回合开始
    RoleTurnEnd = indexAdd(),       -- 角色回合结束
    RoleRageGrow = indexAdd(),      -- 角色怒气成长
    RoleRageCost = indexAdd(),      -- 角色怒气消耗
    RoleRageChange = indexAdd(),    -- 角色怒气变化
    RoleControl = indexAdd(),       -- 角色释放控制技能
    RoleBeControl = indexAdd(),     -- 角色被控制
    RoleRealDead = indexAdd(),      -- 角色真死了
    RoleRelive = indexAdd(),        -- 角色复活了
    FinalDamage = indexAdd(),
    FinalBeDamage = indexAdd(),

    HitMiss = indexAdd(),
    BeHitMiss = indexAdd(),

    CritDamageReduceFactor = indexAdd(),    -- 暴击伤害减免系数

    SkillCast = indexAdd(),         -- 技能攻击前
    SkillCastEnd = indexAdd(),      -- 技能攻击结束
    BeSkillCast = indexAdd(),       -- 被技能攻击前
    BeSkillCastEnd = indexAdd(),    -- 被技能攻击结束
    SkillRandomBuff = indexAdd(),   -- 技能控制时
    SkillEffectBefore = indexAdd(),   -- 技能效果触发前
    BeSkillEffectBefore = indexAdd(),   -- 技能效果触发前

    SkillFireOnce = indexAdd(),     --< 技能单次炮击
    AddUnit = indexAdd(),           --<
    RemoveUnit = indexAdd(),        --<

    PassiveTreating = indexAdd(),
    PassiveBeTreated = indexAdd(),
    PassiveBeDamaging = indexAdd(),
    PassiveDamaging = indexAdd(),
    PassiveCriting = indexAdd(),
    PassiveTreatingFactor = indexAdd(),
    PassiveBeTreatedFactor = indexAdd(),
    PassiveRandomControl = indexAdd(),
    PassiveBeRandomControl = indexAdd(),
    PassiveRandomDot = indexAdd(),
    PassiveBeRandomDot = indexAdd(),
    

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
    BuffCountChange = indexAdd(),
    BuffCover = indexAdd(),
    BuffRoundChange = indexAdd(),
    BuffDurationChange = indexAdd(),
    BuffAuraTrigger = indexAdd(),

    ShildValueChange = indexAdd(),
    ShildTrigger = indexAdd(),

    Curse_ShareDamage = indexAdd(),
    Be_Curse_ShareDamage = indexAdd(),


    SkillTargetCheck = indexAdd(),

    DebugStop = indexAdd(),

    FloatTotal = indexAdd(),

    IgnoreDefFactor = indexAdd(),
    BeIgnoreDefFactor = indexAdd(),
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
    Hit = indexAdd(), --施法率（%）
    Dodge = indexAdd(), --后期基础施法率（%）
    Crit = indexAdd(), --暴击率（%）
    CritDamageFactor = indexAdd(), --暴击伤害系数（%）
    Tenacity = indexAdd(), --抗暴率（%）
    TreatFacter = indexAdd(),--治疗加成系数（%）
    CureFacter = indexAdd(),--受到治疗加成系数（%）
    TeamDamageBocusFactor = indexAdd(),--队伍伤害加成系数（%）
    TeamDamageReduceFactor = indexAdd(),--队伍伤害减免系数（%）
    FireDamageReduceFactor = indexAdd(), --火系伤害减免系数（%）
    WindDamageReduceFactor = indexAdd(), --风系伤害减免系数（%）
    IceDamageReduceFactor = indexAdd(), --冰系伤害减免系数（%）
    LandDamageReduceFactor = indexAdd(), --地系伤害减免系数（%）
    LightDamageReduceFactor = indexAdd(), --光系伤害减免系数（%）
    DarkDamageReduceFactor = indexAdd(), --暗系伤害减免系数（%）

    PhysicalDamage = indexAdd(),            --< 物伤
    MagicDamage = indexAdd(),               --< 法伤
    PhysicalImmune = indexAdd(),            --< 物免
    MagicImmune = indexAdd(),               --< 法免
    SpeedAddition = indexAdd(),             --< 速度加成
    AttackAddition = indexAdd(),            --< 攻击加成
    ArmorAddition = indexAdd(),             --< 护甲加成
    ControlProbability = indexAdd(),        --< 控制几率
    ControlResist = indexAdd(),             --< 控制抵抗

    ElementDamageBocusFactor = indexAdd(), --属性伤害加成系数（%）
    --InitRage = indexAdd(), --初始怒气值

    

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
    ReBound = 1,            --< 反伤
}

--> FightUnit类型
FightUnitType = {
    UnitSupport = 1,             --< 支援
    UnitAircraftCarrier = 2,     --< 航母
    UnitAdjutant = 3,            --< 副官
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
    RoleDataName.CritDamageFactor,
    RoleDataName.TreatFacter,
    RoleDataName.MaxHp,
    RoleDataName.Hp,
    RoleDataName.CureFacter,
    RoleDataName.Tenacity,
    RoleDataName.InitRage,
    RoleDataName.PhysicalDamage,
    RoleDataName.MagicDamage,
    RoleDataName.PhysicalImmune,
    RoleDataName.MagicImmune,
    RoleDataName.SpeedAddition,
    RoleDataName.AttackAddition,
    RoleDataName.ArmorAddition,
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