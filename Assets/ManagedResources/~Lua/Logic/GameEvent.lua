GameEvent = {
    Network = {
        OnReconnectSuccess = 'Network_OnReconnectSuccess',
        OnSendHeartBeat = "Network_OnSendHeartBeat",
        OnReceiveHeartBeat = "Network_OnReceiveHeartBeat",
    },
    UI = {
        OnOpen = 'UIEvent_OnOpen',
        OnClose = "UIEvent_OnClose",
        OnDestory = "UIEvent_OnDestory",
        OnFocus = "UIEvent_OnFocus",
        OnLoseFocus = "UIEvent_OnLoseFocus",
        
        OnBtnClicked = "UIEvent_OnBtnClicked",-- 按钮点击后通知其他界面
    },
    Guide = {
        NextTrigger = "Guide.NextTrigger",
        MapInit = "Guide.MapInit",
        EventTriggered = "Guide.EventTriggered",
        MapPosTriggered = "Guide.MapPosTriggered",
        GuideBattleStart = "Guide.GuideBattleStart",
        GuideBattleCDDone = "Guide.GuideBattleCDDone",
        GuideBattleTeamCDDone = "Guide.GuideBattleTeamCDDone",
        GuideBattleStageChange = "Guide.GuideBattleStageChange",
        GuidePanelScrollViewPos = "Guide.GuidePanelScrollViewPos",
    },
    Player = {
        OnGoldChange = "Player.GoldChange",-- 金币数量改变
        OnLevelChange = "Player.LevelChange",
        OnNameChange = "Player.NameChange",-- 得到任意名字
        OnChangeName = "Player.OnChangeName",-- 名字改变
        OnPlayerLvChange = "Player.OnPlayerLvChange",-- 玩家等级改变
        OnHeadFrameChange = "Player.OnHeadFrameChange",-- 玩家头像框改变
        OnHeadChange = "Player.OnHeadChange",
        OnPowerChange = "Player.OnPowerChange",-- 玩家战力改变
        OnPlayNameChange = "Player.OnPlayNameChange",-- 玩家名字改变
        OnPlayTitleChange = "Player.OnPlayTitleChange",-- 玩家称号改变
        OnPlayRingChange = "Player.OnPlayRingChange",-- 戒指重铸
    },
    Treasure = {
      TreasureLvUp = "Treasure.TreasureLvUp",--宝物强化/精炼提升
    },
    Formation = {
        OnFormationChange = "Formation.OnFormationChange",--队伍数据改变
        OnResetFormationHp = "Formation.OnResetFormationHp",-- 重置队伍血量
        OnMapTeamHpReduce = "Formation.OnMapTeamHCVpReduce",-- 掉血消息
        OnSupportChange = "Formation.OnSupportChange",--> 更新支援
        OnAdjutantChange = "Formation.OnAdjutantChange",--> 更新副官
        OnCVChange = "Formation.OnCVChange",--> 更新航母
    },
    Mission = {
        OnMissionAdd = "Mission.OnMissionAdd",--新增任务
        OnMissionChange = "Mission.OnMissionChange",--更新任务状态MapManager.mapPointList[pos]
        OnGetReward = "Mission.OnGetReward",-- 完成任务领奖
        OnMissionEnd = "Mission.End",-- 任务结束在地图上的表现
        OnTimeChange = "Mission.OnTimeChange",-- 任务计时
        OnPassFight = "Mission.OnPassFight",-- 首次通关一个关卡
        OnOpenFight = "Mission.OnOpenFight",-- 首次解锁一个关卡
        OnOpenEnableFight = "Mission.OnOpenEnableFight",-- 解锁一个可以打的关卡
        GetOpenServerRewardRefreshFightPoint = "Mission.GetOpenServerRewardRefreshFightPoint",-- 领取开服福利奖励 刷新挂机主界面
        NiuQiChongTianTask = "Mission.NiuQiChongTianTask",--战车达人任务
    },
    Map = {
        PointAdd = "Map.PointAdd",
        PointRemove = "Map.PointRemove",
        PointUiClear="Map.PointUiClear",
        Out = "Map.Out",
        DeadOut = "Map.DeadOut",
        FormationHpChange = "Map.FormationHpChange",
        ProgressChange = "Map.ProgressChange",
        ProgressChangeUpdateShow = "Map.ProgressChangeUpdateShow",
        MapDataChange = "Map.DataChange",-- 地图上的数据变动事件
        DisperseFog = "Map.DisperseFog",
        Transport = "Map.Transport",-- 图内传送
        ProgressDataChange = "Map.ProgressDataChange",-- 更新探索度信息
        OnRefreshStarReward = "Map.OnRefreshStarReward",--更新副本星级奖励
        OnAddNotePoint = "Map.OnAddNotePoint",-- 增加一个标记点
        OnRemoveNotePoint = "Map.OnRemoveNotePoint",-- 刪除一个标记点
        OnForceGetOutMap = "Map.OnForceGetOutMap",-- 服务器器强制出图
        OnAddCountTimePoint = "Map.OnAddCountTimePoint",-- 增加一个显示刷新点
        ShowEnemyInfo = "Map.ShowEnemyInfo",-- 显示敌人信息弹窗
        RefreshHeroHp = "Map.RefreshHeroHp",-- 刷新英雄血量
        StopWalk = "Map.StopWalk",
        ClearCtrl = "ClearCtrl",--> 清除ctrl组件
	MaskState = "Map.MaskState",
        EnergyFull = "Map.EnergyFull"
    },
    Event = {
        PointTrigger = "Event.PointTrigger",
        PointTriggerEnd = "Event.PointTriggerEnd",
    },
    Room = {
        GameStart = "Room.GameStart",
        GameEnd = "Room.GameEnd",
    },
    MapFight = {
        Move = "MapFight.Move",
        PositionChange = "MapFight.PositionChange",
        HPChange = "MapFight.HPChange",
        MineralChange = "MapFight.MineralChange",
        AgentAdd = "MapFight.AgentAdd",
        AgentRemove = "MapFight.AgentRemove",
        BuffAdd = "MapFight.BuffAdd",
        BuffChange = "MapFight.BuffChange",
        BuffRemove = "MapFight.BuffRemove",
        MineralPointAdd = "MapFight.MineralPointAdd",
        MineralPointChange = "MapFight.MineralPointChange",
        MineralPointRemove = "MapFight.MineralPointRemove",
        GameEnd = "MapFight.GameEnd",
        BackMain = "MapFight.BackMain",
        RankInfoChange = "MapFight.RankInfoChange",
        ScoreRewardUpdate = "MapFight.ScoreRewardUpdate",
    },
    WorkShow = {
        WorkShopLvChange = "WorkShow.WorkShopLvChange",

    },
    DiffMonster = {
        OnComponentChange = "DiffMonster.OnComponentChange"
    },
    Bag = {
        BagGold = "Bag.BagGold",
        OnTempBagChanged = "Bag.OnTempBagChanged",-- 监听临时背包
        EnErnyBagChanged = "Bag.EnErnyBagChanged",
        OnBagItemNumChange = "Bag.OnBagItemNumChange",-- 有按时间刷新的道具刷新
        GetNewItem = "Bag.GetNewItem",--得一个新item
        OnRefreshSoulPanelData = "Bag.OnRefreshSoulPanelData",
        OnBagShowWarPowerChange = "Bag.OnBagShowWarPowerChange",
        OnRefreshRing = "Bag.OnRefreshRing",-- 戒指重铸后刷新
        OnRefreshRune = "Bag.OnRefreshRune",
    },
    Adventure = {
        OnAreaStateChange = "Adventure.OnAreaStateChange",
        RefreshGetAward = "Adventure.RefreshGetAward",
        OnInjureRank = "Adventure.OnInjureRank",
        OnRefeshBoxRewardShow = "Adventure.OnRefeshBoxRewardShow",
        OnEnemyListChanged = "Adventure.OnEnemyListChanged",
        OnRefreshData = "Adventure.OnRefreshData",
        OnChatListChanged = "Adventure.OnChatListChanged",
        OnFastBattleChanged = "Adventure.OnFastBattleChanged",
        MonsterSayInfo = "Adventure.MonsterSayInfo",
        CallAlianInvasionTime = "Adventure.CallAlianInvasionTime",
        OnRefreshRedShow = "Adventure.OnRefreshRedShow",
        OnRefreshNextDayData = "Adventure.OnRefreshNextDayData",
        UpdateMultiUI = "Adventure.UpdateMultiUI",
    },
    RedPoint = {
        NumChange = "RedPoint.NumChange",
        StateChange = "RedPoint.StateChange",
        PointRemove = "RedPoint.PointRemove",
        Mail = "RedPoint.Mail",
        ActivityGift = "RedPoint.ActivityGift",
        PveStar = "RedPoint.PveStar",
        TrainTask = "RedPoint.ActivityGift",
    },
    Activity = {
        OnChapterState = "Activity.OnChapterState",
        OnSevenDayState = "Activity.OnSevenDayState",
        OnlineState = "Activity.OnlineState",
        GetRewardRefresh = "Activity.GetRewardRefresh",
        OnCloseSevenDayGift = "Activity.OnCloseSevenDayGift",
        OnCloseOnlineGift = "Activity.OnCloseOnlineGift",
        OnCloseChapterGift = "Activity.OnCloseChapterGift",
        OnActivityOpenOrClose = "Activity.OnActivityOpenOrClose",--活动开闭
        OnFuncStateChange = "Activity.OnFuncStateChange",-- 活动状态改变
        OnLuckyCatRefresh = "Activity.OnLuckyCatRefresh",--招财猫刷新数据
        OnLuckyCatWorldMessage = "Activity.OnLuckyCatWorldMessage",--招财猫跑马灯数据刷新
        OnLuckyCatRedRefresh = "Activity.OnLuckyCatRedRefresh",--招财猫红点刷新
        OnActivityProgressStateChange = "Activity.OnActivityProgressStateChange",-- 活动进度状态改变
        OnPatFaceRedRefresh = "Activity.OnPatFaceRedRefresh",--五点刷新拍脸
        OnLuckyTableWorldMessage = "Activity.OnLuckyTableWorldMessage",--幸运转盘跑马灯数据刷新
        ContinueRechargeRefresh = "Activity.ContinueRechargeRefresh",-- 积天豪礼刷新
        QianKunBoxRefreshBtn = "Activity.QianKunBoxRefreshBtn",
    },
    Carbon = {
        CarbonCountChange = "Carbon.CarbonCountChange",
        RefreshCarbonData="Carbon.RefreshCarbonData",
    },
    Arena = {
        OnBaseDataChange = "Arena.OnBaseDataChange",
        OnRankDataChange = "Arena.OnRankDataChange",
        OnRecordDataChange = "Arena.OnRecordDataChange",
    },
    SecretBox = {
        OnOpenOneReward = "SecretBox.OnOpenOneReward",
        OnOpenTenReward = "SecretBox.OnOpenTenReward",
        OnRefreshSecretBoxData = "SecretBox.OnRefreshSecretBoxData",
    },
    Shop = {
        OnShopInfoChange = "Shop.OnShopInfoChange",
        OnExchangeChange = "Shop.OnExchangeChange",
    },
    Vip = {
        OnVipTaskStatusChanged = "Vip.OnVipTaskStatusChanged",
        OnVipDailyRewardStatusChanged = "Vip.OnVipDailyRewardStatusChanged",
        OnVipRankChanged = "Vip.OnVipRankChanged"
    },
    Friend = {
        OnFriendList = "GoodFriend.OnFriendList",
        OnFriendApplication = "GoodFriend.OnFriendApplication",
        OnFriendSearch = "GoodFriend.OnFriendSearch",
        OnBlackFriend = "GoodFriend.OnBlackFriend",
        OnFriendDelete = "GoodFriend.OnFriendDelete",
    },
    Chat = {
        OnChatDataChanged = "Chat.OnChatDataChanged",
        OnMainChatChanged = "Chat.OnMainChatChanged",
    },
    MissionDaily = {
        OnMissionDailyChanged = "MissionDaily.OnMissionDailyChanged",
        OnMissionListRestChanged = "MissionDaily.OnMissionListRestChanged",
    },
    EliteAchieve = {
        OnAchieveDone = "EliteAchieve.OnAchieveDone",
    },
    TrialMap = {
        OnPowerValueChanged = "TrialMap.OnPowerValueChanged",
        BtViewOut = "BtViewOut",
        UpdateBox = "UpdateBox",
    },
    MoneyPay = {
        OnPayResultSuccess = "MoneyPay.OnPayResultSuccess"
    },
    FoodBuff = {
        OnFoodBuffStateChanged = "FoodBuff.OnFoodBuffStateChanged",
        OnFoodBuffStart = "FoodBuff.OnFoodBuffStart",
        OnFoodBuffEnd = "FoodBuff.OnFoodBuffEnd",
    },
    Setting = {
        OnSettingChanged = "Setting.OnSettingChanged",
    },
    TreasureOfSomeBody = {
        OnOneKeyReceived = "TreasureOfSomeBody.OnOneKeyReceived",
        OneKeyBtnStatus = "TreasureOfSomeBody.OneKeyBtnStatus",
        OpenTreasureAward = "TreasureOfSomeBody.OpenTreasureAward"
    },
    FunctionCtrl = {
        OnFunctionOpen = "FunctionCtrl.OnFunctionOpen",
        OnFunctionClose = "FunctionCtrl.OnFunctionClose",
        OnXuanYuanFunctionChange = "FunctionCtrl.OnXuanYuanFunctionChange",
        NextDayRefresh ="FunctionCtrl.NextDayRefresh",
	},
    Guild = {
        JoinGuildSuccess = "Guild.JoinGuildSuccess",
        DataUpdate = "Guild.DataUpdate",
        LogDataUpdate = "Guild.LogDataUpdate",
        MemberDataUpdate = "Guild.MemberDataUpdate",
        ApplyDataUpdate = "Guild.ApplyDataUpdate",
        BeKickOut = "Guild.BeKickOut",
        KickOut = "Guild.KickOut",
        PositionUpdate = "Guild.PositionUpdate",
        OnQuitGuild = "Guild.OnQuitGuild",
        WalkUpdate = "Guild.WalkUpdate",
        DismissStatusChanged = "Guild.DismissStatusChanged",
        CarDelayProgressChanged = "Guild.CarDelayProgressChanged",--车迟阶段变化更新
        CarDelayChallengeCdStar = "Guild.CarDelayChallengeCdStar",--车迟挑战cd开始计数
        CarDelayLootCdStar = "Guild.CarDelayLootCdStar",--车迟抢夺cd开始计数
        OnRefreshFeteProcess = "Guild.OnRefreshFeteProcess",--公会祭祀进度
        RefreshDeathPosStatus = "Guild.RefreshDeathPosStatus",--十绝阵阶段切换
        RefreshDeathPosReward = "Guild.RefreshDeathPosReward",--其他玩家领取奖励推送
        RefreshFirstChangeData = "Guild.RefreshFirstChangeData", --刷新十绝阵第一公会信息
        RefreshGuildAid = "Guild.RefreshGuildAid", --刷新公会援助
        RefreshGuildTranscript = "Guild.RefreshGuildTranscript", --刷新公会副本界面
        RefreshGuildTranscriptBuff = "Guild.RefreshGuildTranscriptBuff", --刷新公会副本界面buff
        RefreshGuildTranscripQuickBtn = "Guild.RefreshGuildTranscripQuickBtn", --刷新公会副本界面扫荡
        RefreshGuildBattleReward = "Guild.RefreshGuildBattleReward",--刷新公会战宝箱信息
        RefreshGuildCityRank = "Guild.RefreshGuildCityRank",--刷新城市排名第一
        RefreshGuildBattleState = "Guild.RefreshGuildBattleState",--刷新公会战状态
    },
    WorldBoss = {
        RefreshChallengeInfo = "WorldBoss.RefreshChallengeInfo", -- --刷新世界BOSS挑战信息
    },
    GuildFight = {
        DefendDataUpdate = "GuildFight.DefendDataUpdate",
        AttackStageDefendDataUpdate = "GuildFight.AttackStageDefendDataUpdate",
        FightBaseDataUpdate = "GuildFight.FightBaseDataUpdate",
        EnemyBaseDataUpdate = "GuildFight.EnemyBaseDataUpdate",
        ResultDataUpdate = "GuildFight.ResultDataUpdate",
        OnStageChanged = "GuildFight.OnStageChanged",
    },
    GuildBoss = {
        OnMaxDamageChanged = "GuildBoss.OnMaxDamageChanged",
        OnLastDamageChanged = "GuildBoss.OnLastDamageChanged",
        OnBaseDataChanged = "GuildBoss.OnBaseDataChanged",
    },
    GuildRedPacket = {
        OnRefreshGetRedPacket = "GuildRedPacket.OnRefreshGetRedPacket",
        OnCloseRedPointClick = "GuildRedPacket.OnCloseRedPointClick",
    },
    FiveAMRefresh = {
        ServerNotifyRefresh = "FiveAMRefresh.ServerNotifyRefresh",
    },
    Recruit = {
        OnRecruitRefreshData = "Recruit.OnRecruitRefreshData",
    },
    LoginSuccess = {
        OnLoginSuccess = "LoginSuccess.OnLoginSuccess",
        OnLogout = "LoginSuccess.OnLogout",
        OnAgreePrivacy = "LoginSuccess.OnAgreePrivacy",
    },
    HeroGrade = {
        OnHeroGradeChange = "HeroGrade.OnHeroGradeChange",
    },
    BindPhone = {
        OnBindStatusChange = "BindPhone/OnBindStatusChange"
    },
    Questionnaire = {
        OnQuestionnaireChange = "Questionnaire.OnQuestionnaireChange"
    },
    SoulPrint = {
        OnRefreshBag = "SoulPrint.OnRefreshBag"

    },
    RankingList = {
        OnWarPowerChange = "RankingList.OnWarPowerChange",
        OnArenaChange = "RankingList.OnArenaChange",
        OnTrialChange = "RankingList.OnTrialChange",
        OnMonsterChange = "RankingList.OnMonsterChange",
        OnAdventureChange = "RankingList.OnAdventureChange",
        OnCustomsPassChange = "RankingList.OnCustomsPassChange",
        OnGuildForceChange = "RankingList.OnGuildForceChange",
        OnGoldExperSortChange = "RankingList.OnGoldExperSortChange",
        OnClimbTowerChange = "RankingList.OnClimbTowerChange",
        OnAlameinWarChange = "RankingList.OnAlameinWarChange",
        OnHeroForceChange = "RankingList.OnHeroForceChange",
        OnRankingRewardChange="RankingList.OnRankingRewardChange",
    },
    HorseRace = {
        ShowHorseRace = "HorseRace.ShowHorseRace",
    },
    Equip = {
        EquipChange = "Equip.EquipChange",
    },
    PatFace = {
        PatFaceSend = "PatFace.PatFaceSend",
        PatFaceSendFinish = "PatFace.PatFaceSendFinish",
        PatFaceHaveGrowGift = "PatFace.PatFaceHaveGrowGift",
        PatFaceClear = "PatFace.PatFaceClear",
    },
    ATM_RankView = {
        OnRankChange = "ATM_RankView.OnRankChange",
        OnOpenBattle = "ATM_RankView.OnOpenBattle",
    },
    FindTreasure = {
        RefreshFindTreasure = "FindTreasure.RefreshFindTreasure",
        RefreshFindTreasureRedPot = "FindTreasure.RefreshFindTreasureRedPot",
    },
    TopMatch = {
        OnTopMatchDataUpdate = "TopMatch.OnTopMatchDataUpdate",
        OnGuessDataUpdate = "TopMatch.OnGuessDataUpdate",
        OnGuessRateUpdate = "TopMatch.OnGuessRateUpdate",
        OnGuessDataUpdateShowTip = "TopMatch.OnGuessDataUpdateShowTip",
        OnMyBattlePlayback = "TopMatch.OnMyBattlePlayback",
    },
    FindFairy = {
        RefreshRedPoint = "FindFairy.RefreshRedPoint",
        RefreshBuyOpenState = "FindFairy.RefreshBuyOpenState",
    },
    Privilege = {
        OnPrivilegeUpdate = "Privilege.OnPrivilegeUpdate",
    },
    Battle = {
        OnTimeScaleChanged = "Battle.OnTimeScaleChanged",
        OnBattleUIEnd = "Battle.OnBattleUIEnd"
    },
    MonthCard = {
        OnMonthCardUpdate = "MonthCard.OnMonthCardUpdate",
    },
    BugCoin = { --点金
        OnBuyCoinUpdate = "BugCoin.OnBuyCoinUpdate"
    },
    EightDay = {
        GetRewardSuccess = "EightDay.GetRewardSuccess"
    },
    OnlineGift = {
        GetOnlineRewardSuccess = "OnlineGift.GetOnlineRewardSuccess"
    },
    Expedition = {
        RefreshPlayAniMainPanel = "Expedition.RefreshPlayAniMainPanel",
        RefreshMainPanel = "Expedition.RefreshMainPanel"
    },
    GrowGift = {
        GetAllGift = "GrowGift.GetAllGift"
    },
    TreasureOfHeaven = {
        RechargeSuccess = "TreasureOfHeaven.RechargeSuccess",
        BuyQinglongSerectLevelSuccess = "TreasureOfHeaven.BuyQinglongSerectLevelSuccess",
        RechargeQinglongSerectSuccess = "TreasureOfHeaven.RechargeQinglongSerectSuccess",
        TaskRefresh = "TreasureOfHeaven.TaskRefresh",
    },
    CloseUI = {
        OnClose = "CloseUI.OnClose"
    },
    CombatPlan = {
        CompoundPlanExpPush = "CombatPlan.CompoundPlanExpPush",
        RebuildPlan = "CombatPlan.RebuildPlan"
    },
    AlameinWar = {
        RefreshTimes = "AlameinWar.RefreshTimes"
    },
    AircraftCarrier = {
        DesignSubPlaneRefresh = "AircraftCarrier.DesignSubPlaneRefresh",
        DesignSubPlaneSetDownType = "DesignSubPlaneSetDownType",
        DesignSubPlaneRefreshPlaneDesign = "AircraftCarrier.DesignSubPlaneRefreshPlaneDesign",
        CVSubRefreshMain = "AircraftCarrier.CVSubRefreshMain"
    },
    Parts = {
        FreshEquip = "Parts.FreshEquip",
    },
    DynamicTask = {
        OnMissionChange = "DynamicTask.MissionChange",
        OnGetReward = "DynamicTask.OnGetReward",
    },
    XiaoYao = {
        StartXiaoYao = "XiaoYao.StartXiaoYao",--执行逍遥游跑图
        RefreshEventShow = "XiaoYao.RefreshEventShow",--刷新逍遥游地图界面事件按钮显示隐藏
        PlayEventEffect = "XiaoYao.PlayEventEffect",--播放事件特效
    },
    Role = {
        UpdateSkin = "Role.UpdateSkin",-- 刷新皮肤
        UpdateRoleInfoPanel = "Role.UpdateRoleInfoPanel",-- 刷新详情界面
        UpdateTalismanInfoPanel = "Role.UpdateTalismanInfoPanel",-- 刷新法宝界面
    },
    HongMeng = {
        RereshNumText = "HongMeng.RereshNumText",--鸿蒙阵消息号
        OpenBoxTips = "HongMeng.OpenBoxTips",
        ChooseData = "HongMeng.ChooseData",
        UnLoadData = "HongMeng.UnLoadData",
        OnlyRefeshText = "HongMeng.OnlyRefeshText",
        UpHongMengEnvoy = "HongMeng.UpHongMengEnvoy",--鸿蒙塔消息号
        UnLoadHongMengEnvoy = "HongMeng.UnLoadHongMengEnvoy",
        UpdateGongMingLv = "HongMeng.UpdateGongMingLv",
        HongMengGuide = "HongMeng.HongMengGuide",--鸿蒙碑新手引导
    },
    GuideTask = {
        OnGuideTaskChange = "GuideTask.OnGuideTaskChange",--指引任务更换
    },
    EndLess = {
        MissonChange = "EndLess.MissonChange",
        RechargeQinglongSerectSuccess = "EndLess.RechargeQinglongSerectSuccess",
        RefreshHeroData = "EndLess.RefreshHeroData",
        GuidePanel = "EndLess.GuidePanel",
        QinglongSerectRefresh = "EndLess.QinglongSerectRefresh",
    },
    --情报中心
    FormationCenter ={
        OnFormationCenterLevelChange = "FormationCenter,OnFormationCenterLevelChange"--情报中心等级变化
    },
    SDK = {
        InitSuccess = "SDK.InitSuccess",
    },
    CustomEvent = {
        OnUpdateHeroDatas = "CustomEvent.OnUpdateHeroDatas",
        OnPowerChange = "CustomEvent.OnPowerChange",
    },
    Title = {
        RefreshTitleShowEvevt = "Title.RefreshTitleShowEvevt",
    },
    --先驱
    Adjutant = {
        OnAdjutantChange = "Adjutant.OnAdjutantChange"
    },
    --成长手册
    GrowthManual = {
        OnGrowthManualRedpointChange = "GrowthManual.OnGrowthManualRedpointChange"
    },
    --引导
    MianGuide = {
        RefreshGuide = "MianGuide.RefreshGuide"
    },
    DefenseTrainingPopup = {
        RefreshBtnClick = "DefenseTrainingPopup.RefreshBtnClick"
    },
    --图鉴
    HandBook = {
        RefreshRedPoint = "HandBook.RefreshRedPoint"
    },
    --异端之战
    YiDuan = {
        AutoGetBaoXiang = "YiDuan.AutoGetBaoXiang"
    },
    --任务
    Task = {
        Achievement = "Task.Achievement"
    },
    --主城
    Main = {
        ActivityRefresh = "Main.ActivityRefresh"
    },
    Ladders = {
        RefreshItem = "Ladders.RefreshItem"
    };
    --主角
    Lead = {
        RefreshProgress = "Lead.RefreshProgress",--刷新研发进度
        RefreshNormalProgress = "Lead.RefreshNormalProgress",--刷新普通研发进度
        RefreshPrivilegeProgress = "Lead.RefreshPrivilegeProgress",--刷新普通研发进度
        ResearchOver = "Lead.ResearchOver",--研发结束
        ResearchLvUp = "Lead.ResearchLvUp",--研发速度升级
        RefreshSkill = "Lead.RefreshSkill",--刷新技能
        RefreshInfo = "Lead.RefreshInfo",--刷新基础属性
    };
    WarOrder = {
        UnLock = "WarOrder,UnLock",
    },
    PVE = {
        Jump = "PVE.Jump"
    },
}