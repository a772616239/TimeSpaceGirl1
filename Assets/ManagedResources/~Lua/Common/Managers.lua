--- 管理器名字

local ManagerNames = {
    --> 全局Value
    "GlobleValueManager/GlobleValueManager",
    --数据中心管理
    "DataCenterService/DataCenterManager",
    -- "DataCenterService/ThinkingAnalyticsManager",
    -- "DataCenterService/TapDBManager",
    --"DataCenterService/BuglyManager",
     --打点管理
     "CustomEvent/CustomEventManager",
    -- 游戏设置管理
    "Setting/SettingManager",
    --通信管理，所有的通信接口
    "Net/NetManager",
    --推送管理，所有的推送接口
    "Net/IndicationManager",
    --登录数据管理
    "Login/LoginManager",
    --用户数据管理
    "Player/PlayerManager",
    "Player/HeadManager",
    "Player/PrivilegeManager",
    --编队数据管理
    "Formation/FormationManager",
    --战斗数据管理
    "Battle/BattleManager",
    "Battle/BattleRecordManager",
    --英雄数据管理
    "Hero/HeroManager",
    --镜像英雄数据
    "Hero/HeroTemporaryManager",
    --背包数据管理
    "Bag/BagManager",
    --关卡数据管理
    "Fight/FightManager",
    --拍脸数据管理
    "Expert/PatFaceManager",
    --地图数据管理
    "Map/MapManager",
    ----地图战斗数据管理
    "MapFight/MapFightManager",
    "MapFight/RoomManager",
    --新手引导
    "Guide/GuideManager",
    --任务系统数据管理，任务系统从属于通用事件系统
    "Mission/MissionManager",
    --装备数据管理
    "Equip/EquipManager",
    --法宝数据管理
    "Equip/TalismanManager",
    --异妖数据管理
    "DiffMonster/DiffMonsterManager",
    --工坊数据管理
    "WorkShop/WorkShopManager",
    -- 临时
    "Popup/NameManager",
    -- option行为管理
    "Mission/OptionBehaviourManager",
    -- 邮件数据管理
    "Mail/MailManager",
    -- 支线任务跳转管理
    "Mission/SecondaryMissionManager",
    -- 红点数据管理
    "Player/RedPointManager",
    --"RedPoint/RedPoint",
    -- buff效果管理
    "Map/FoodBuffManager",
    --副本数据管理
    "Carbon/CarbonManager",
    --活动数据管理
    "ActivityGift/ActivityGiftManager",
    --抽卡数据管理
    "Recruit/RecruitManager",
    -- 剧情管理
    "Story/StoryManager",
    -- 头像图标管理
    "Player/StateManager",
    -- 竞技场管理
    "Arena/ArenaManager",
    -- 商店管理
    "Shop/ShopManager",
    --秘盒管理
    "SecretBox/SecretBoxManager",
    -- 全局活动管理
    "GlobalActTimeCtrl/ActTimeCtrlManager",
    --特权等级管理
    "Vip/VipManager",
    --跳转管理
    "Player/JumpManager",
    --任务管理
    "Task/TaskManager",
    --运营管理
    "Operating/OperatingManager",
    --好友管理
    "GoodFriend/GoodFriendManager",
    --聊天管理
    "Chat/FriendChatManager",
    "Chat/ChatManager",
    --精英怪管理
    "EliteMonster/EliteMonsterManager",
    -- 地图试炼副本管理
    "Map/MapTrialManager",
    --支付管理
    "Pay/PayManager",
    --首充
    "FirstRecharge/FirstRechargeManager",
    -- 云梦祈祷
    "Pray/PrayManager",
    -- 无尽副本数据
    "Map/EndLessMapManager",
    --七日狂欢
    "SevenDayCarnival/SevenDayCarnivalManager",
    --每日首充
    "DailyRecharge/DailyRechargeManager",
    -- 公会数据
    "Guild/GuildManager",
    "Guild/MyGuildManager",
    "Guild/GuildFightManager",
    "Guild/Boss/GuildBossManager",
    "Guild/RedPacketView/GuildRedPacketManager",
    -- 妖兽来袭
    "MonsterCamp/MonsterCampManager",
    --招财猫
    "LuckyCat/LuckyCatManager",
    -- 自动恢复道具管理（只是获取恢复时间）
    "Player/AutoRecoverManager",
    -- 我要变强数据管理
    "Power/UKnowNothingToThePowerManager",
    -- 血战匹配数据管理
    "FormFightMatch/MatchDataManager",
    -- 血战UI数据管理类
    "MapFight/FightUIManager",
    -- 通用对象池
    "Common/Pool/CommonPool",
    -- 货币管理
    "Common/MoneyUtil",
    --幸运转盘
    "LuckyTurnTable/LuckyTurnTableManager",
    --手机绑定
    "BindPhone/BindPhoneNumberManager",
    --魂印管理
    "SoulPrint/SoulPrintManager",
    --调查问卷
    "Questionnaire/QuestionnaireManager",
    --排行榜管理器
    "Ranking/RankingManager",
    -- 新关卡管理
    "Fight/FightPointPassManager",
    -- 冒险数据管理
    "Adventure/AdventureManager",
    -- 戒灵秘宝（孙龙的宝藏V2）
    "TreasureOfSomebody/TreasureOfSomebodyManagerV2",
    -- 戒灵秘宝（孙龙的宝藏V2）
    "Chat/HorseRaceManager",
    -- 功能开启
    "GlobalActTimeCtrl/FunctionOpenMananger",
    -- 颠疯之战
    "ArenaTopMatch/ArenaTopMatchManager",
    -- 东海寻仙（抽卡活动）
    "FindFairy/FindFairyManager",
    -- 迷宫寻宝
    "FindTreasure/FindTreasureManager",
    -- 远征
    "Expedition/ExpeditionManager",
    --宝物管理器
    "RoleInfo/EquipTreasureManager",
    --公会技能管理器
    "Guild/Skill/GuildSkillManager",
    --公会车迟管理器
    "Guild/CarDelay/GuildCarDelayManager",
    --十绝阵管理器
    -- "Guild/DeathPos/DeathPosManager",
    --公会战
    "Guild/Battle/GuildBattleManager",
    --天宫秘宝管理器
    "TreasureOfHeaven/TreasureOfHeavenManager",
    "Carbon/XuanYuanMirrorManager",
    -->
    --> 支援
    "Support/SupportManager",
    --> 副官
    "Adjutant/AdjutantManager",
    --> 战法
    "WarWay/WarWayManager",
    "XiaoYao/XiaoYaoManager",
    --> 作战方案
    "CombatPlan/CombatPlanManager",
    --> 爬塔
    "ClimbTower/ClimbTowerManager",
    --主题活动管理器
    "DynamicActivity/DynamicActivityManager",
    --> 工会副本
    "Guild/Transcript/GuildTranscriptManager",
    --> 防守训练
    "DefenseTraining/DefenseTrainingManager",
    --> 闪电出击
    "BlitzStrike/BlitzStrikeManager",
    --> 阿拉曼战役
    "AlameinWar/AlameinWarManager",
    
    "General/GeneralManager",
    --成长手册
     "GrowthManual/GrowthManualManager",
    -->三强争霸
    "Hegemony/HegemonyManager",
    -->勋章
    "Medal/MedalManager",
    --> 航母
    "AircraftCarrier/AircraftCarrierManager",
    --情报中心
    "FormationCenter/FormationCenterManager",
    --战车达人
    "NiuQiChongTian/NiuQiChongTianManager",
    --图腾
    "Totem/TotemManager",
    --副官活动
    "AdjutantActivity/AdjutantActivityManager",
    --跨服竞技场
    "Ladders/LaddersArenaManager",
    --pve
    "PVEActivity/PVEActivityManager",
    --card
    "CardActivity/CardActivityManager",
    --混乱之治
    "ChaosZZ/ChaosManager",
    --!!!!红点管理(尽量放在最后)!!!!--
    "Player/RedpotManager",
    
}

return ManagerNames