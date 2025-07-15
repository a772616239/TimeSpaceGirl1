--UI Define
UIName = {
    LoginPanel = 1, --登录 
    LoadingPanel = 2, --加载
    MsgPanel = 3, --通用消息弹窗
    PopupTipPanel = 4, --通用上浮消息提示
    RequestPanel = 5, --通用请求界面
    SwitchPanel = 6, --通用切换界面
    BattlePanel = 7, --战斗
    -- BattleEndPanel = 8, --战斗结算
    MapPanel = 9, --地图探索
    GuidePanel = 10, --新手引导
    -- ProgressPanel = 11, --事件交互之读条界面
    -- MapAwardPanel = 12, --地图探索获得
    MapSelectArea = 13, --选择地图区域
    -- MapFightPanel = 14, --血战界面
    MainPanel = 15, --主界面
    RoleInfoPanel = 16, --角色详细信息
    RoleListPanel = 17, --角色列表
    RoleUpStarListPanel = 18, --角色升级操作弹窗
    RoleEquipListPanel = 19, --角色穿装备操作
    RoleUpLvBreakSuccessPanel = 20, --角色突破成功界面
    RoleUpStarSuccessPanel = 21, --角色升星成功界面
    RoleProInfoPopup = 22, --角色属性详情界面
    -- RoleEquipPanel = 23, --角色装备选择界面
    RoleEquipChangePopup = 24, --角色装备更换界面
    RecruitPanel = 25, --抽卡
    SingleRecruitPanel = 26, --单抽
    TenRecruitPanel = 27, --钻石十连抽
    BagPanel = 28, --仓库背包
    GMPanel = 29, --GM
    -- FormationPanel = 30, --编队
    -- EquipInfoPopup = 31, --装备信息
    RoleInfoPopup = 32, --角色信息（面板+技能+装备）
    SkillInfoPopup = 33, --技能信息
    -- FormationExamplePopup = 34, --编队推荐阵容
    -- DiffmonsterEditPopup = 35, --异妖上阵操作
    -- ShopPanel = 36, --商城
    ShopInfoPopup = 37, --商品信息
    -- DiffMonsterPanel = 38, --异妖
    WorkShopMainPanel = 39,
    WorkShopMaterialsCompoundPanel = 40,
    WorkShopRuneListPanel = 41,
    WorkShopArmorOnePanel = 42,
    WorkShopArmorTwoPanel = 43,
    WorkShopCastSuccessPanel = 44,
    WorkShopMadeSuccessPanel = 45,
    WorkShopAwardPanel = 46,
    WorkShopEquipRebuildListPanel = 47,
    DemonActivatePanel = 48,
    -- DemonInfoPanel = 49, --异妖详情界面
    -- DemonPartsUpStarPanel = 50, --异妖配件升星界面
    -- DemonPartsUpStarSuccessPanel = 51, --异妖配件升星成功界面
    -- FoodGainPopup = 52, --食物增益信息
    MapShopPanel = 53, --行脚商人商城
    -- MapRoleInfoPopup = 54, --角色信息（面板+技能）
    -- MapBagPopup = 55, --地图背包
    -- MonsterInfoPopup = 56, --怪物信息
    CreateNamePopup = 57, --角色起名字弹窗
    RewardItemPopup = 58, --奖励获得弹窗
    RewardItemSingleShowPopup = 59, --奖励展示item详情
    RewardEquipSingleShowPopup = 60, --奖励展示装备详情
    MailMainPanel = 61, --邮件list
    MainSingleInfoPanel = 62, --单个邮件
    CurlingTipPanel = 63, --单个邮件
    -- CarbonMissionPopup = 64, --副本任务弹窗
    -- MapLeavePanel = 65, --离开地图界面
    -- MapStatsPanel = 66, --探索统计界面
    CarbonTypePanel = 67, --副本难度选择界面
    -- FightMopUpEndPanel = 68, --关卡扫荡结束奖励界面
    CarbonInfoPanel = 69, --副本详情
    CarbonScoreSortPanel = 70, --副本排行
    -- CarbonMopUpEndPanel = 71, --副本任务奖励
    -- SettingPopup = 72, --设置面板
    -- CarbonBuyCountPopup = 73, --购买弹窗
    StoryDialoguePanel = 74, --剧情使用对话框
    BagResolveAnCompoundPanel = 75, --剧情使用对话框
    RoleGetInfoPopup = 76, --获得英雄点击详情
    ChapterClearanceGiftPanel = 77, --章节奖励
    -- SevenDayGiftPanel = 78, --七日礼包
    -- OnlineGiftPanel = 79, --在线礼包
    FightEndLvUpPanel = 80, --关卡等级提升
    RewardPreviewPopupPanel = 81, --奖励预览详情弹框
    StoryBeginPanel = 82, --剧情开幕弹窗
    StoryEndPanel = 83, --剧情闭幕弹窗
    WorkShopEquipReforgePreviewPanel = 84, --装备重铸预览
    ArenaMainPanel = 85, --竞技场
    ArenaResultPopup = 86, --竞技场
    ArenaRecordPopup = 87, --竞技场
    -- SecretBoxPanel = 88, --秘盒
    -- StoryOptionPopup = 89, --剧情选择按钮
    SecretBoxBuyOnePanel = 90, --秘盒购买1次
    SecretBoxBuyTenPanel = 91, --秘盒购买10次
    MapOptionPanel = 92, --新地图选择界面
    -- DiffMonsterPreviewPanel = 93, --异妖预览
    -- DemonPartsActiveSuccessPanel = 94, --异妖配件激活
    -- RewardEquipSingleShowPopup2 = 95, --七日奖励未获得装备弹窗
    -- AdventureAlianInvasionPanel = 96, --冒险外敌入侵页面
    -- DemonUpGradePanel = 97, --异妖材料升级
    -- DiffMonsterAttributeAdditionPanel = 98, --异妖属性加成
    AdventureExploreRewardPanel = 99, --冒险宝箱时长奖励领取页面
    -- DiffMonsterUpGradSuccessPanel = 100, --异妖升阶成功界面
    -- HeroAndEquipResolvePanel = 101, --分解主界面
    WorkShopLevelUpNotifyPanel = 102, --工坊等级提升界面
    -- MapFormationInfoPopup = 103, --地图队伍信息界面
    MainShopPanel = 104, --商店主界面
    ShopBuyPopup = 105, --商店购买界面
    QuickPurchasePanel = 106, --快捷购买界面
    -- VipPanel = 107, --特权等级界面
    -- VipTipPopup = 108, --特权描述界面
    -- AdventureRewardDetailPopup = 109, --外敌奖励展示
    -- SecretBoxShowPokemonPanel = 110, --异妖抽卡抽到好部件展示界面
    -- AdventureGetRewardPopup = 111, --挂机战斗结果
    OperatingPanel = 112, --运营相关面板
    WarPowerChangeNotifyPanel = 113, --战力提升
    FirstRechargePanel = 114, --首冲
    MissionDailyPanel = 115, --每日任务
    GoodFriendMainPanel = 116, --好友系统
    ChatPanel = 117, --聊天
    FriendChatPanel = 118, --好友聊天
    WorkShopLvUpPanel = 119, --工坊升级界面
    WorkShowTechnologPanel = 120, --工坊天赋树界面
    EliteMonsterPanel = 121, --工坊升级界面
    -- DropGetSSRHeroShopPanel = 122, --掉落获得ssr英雄展示界面
    -- FightSelectAreaShowMopUpPanel = 123, --关卡扫荡次数选择界面
    -- EliteCarbonAchievePanel = 124, --精英副本成就界面
    TrialOpPanel = 125, --试炼副本操作界面
    WorkShopAttributeAdditionPanel = 126, --天赋树单个职业所有属性集合界面
    -- BuffChoosePanel = 127, --试炼副本UI触发的buff选择界面
    TrialBossTipPopup = 128, --试炼副本Boss提示
    MonsterShowPanel = 129, --怪物展示界面
    BuffOptionPanel = 130, --试炼副本地图触发的buff选择界面
    DamageResultPanel = 131, --战斗结果展示
    -- HandBookMainPanel = 132, --图鉴
    HandBookHeroAndEquipListPanel = 133, --图鉴英雄装备列表界面
    HandBookHeroInfoPanel = 134, --图鉴英雄详情界面
    HandBookEquipInfoPanel = 135, --图鉴装备详情界面
    ElementDrawCardPanel = 136, --元素抽卡页面
    -- PrayMainPanel = 137, --云梦祈祷主界面
    -- PraySelectRewardPanel = 138, --云梦祈祷奖励选择界面
    SettingPanel = 139, --设置界面
    HeadChangePopup = 140, --头像修改界面
    -- ShopExchangePopup = 141, --物品对换界面
    NotEnoughPopup = 142,                       --物品不足提示界面
    -- CommonConfirmPanel = 143,                --确认或取消选择界面
    -- PrayRewardItemPopup = 144,               --云梦祈祷奖励获得界面
    -- PlotCarbonPanel = 145,                   --普通副本界面
    -- TrialCarbonPanel = 146,                  --试炼副本界面
    EliteCarbonPanel = 147,                     --精英副本界面
    EndLessCarbonPanel = 148,                   --无尽副本界面
    -- SevenDayCarnivalPanel = 149,             --七日狂欢
    -- TrialResetPopup = 150,                   --试炼副本次数重置界面
    -- WarPowerSortPanel = 151,                 --战力排行
    MapNotePopup = 152,                         --战力排行
    DailyRechargePanel = 153,                   --每日首充
    -- LuckyCatPanel = 154,                     --招财猫
    GuildFindPopup = 155,                       --公会搜索，加入界面
    GuildCreatePopup = 156,                     --公会创建界面
    GuildInfoPopup = 157,                       --公会创建界面
    GuildMainCityPanel = 158,                   --公会主城界面
    GuildChangePopup = 159,                     --公会信息修改界面
    GuildMemberInfoPopup = 160,                 --公会成员信息界面
    GuildLogoPopup = 161,                       --公会图腾界面
    GuildFightDefendInfoPopup = 162,            --公会战防守信息界面
    GuildFightAttackInfoPopup = 163,            --公会战敌方公会信息界面
    GuildFightResultPopup = 164,                --公会战结算界面
    GuildFightAttackLogPopup = 165,             --公会战进攻日志界面
    GuildGetStarPopup = 166,                    --公会战获取星数提示界面
    GuildFightAttackTipPopup = 167,             --公会战攻击阶段提示界面
    GuildFightMatchingPopup = 168,              --公会战匹配中提示界面
    GuildFightMatchSuccessPopup = 169,          --公会战匹配成功提示界面
    GuildFightPopup = 170,                      --公会战界面
    ExpertPanel = 171,                          --限时达人
    CourtesyDressPanel = 172,                   --开服有礼
    ExpertRewardSortPanel = 173,                --限时达人排行
    -- SevenDayRewardPreviewPanel = 174,                       -- 七日狂欢奖励预览界面
    LoginPopup = 175,                                       -- 登录弹窗
    RegistPopup = 176,                                      -- 注册弹窗
    NoticePopup = 177,                                      -- 公告弹窗
    MonsterCampPanel = 178,                                 -- 妖兽来袭主界面
    -- NextMonsterInfoPopup = 179,                             -- 妖兽临袭界面弹窗
    PatFacePanel = 180,                                     -- 拍脸
    -- PlotRewardPreviewPupop = 181,                           -- 副本奖励预览
    HelpPopup = 182,                                        -- 帮助弹窗
    -- UnlockCheckpointPopup = 183,                            -- 解锁关卡弹窗
    LuckyTurnTablePanel = 184,                              -- 解锁幸运转盘弹窗
    HeroPreviewPanel = 185,                                 -- 奖池预览界面
    -- FormationSetPanel = 186,                                -- 编队设置界面
    GiveMePowerPanel = 187,                                 -- 我要变强界面
    --> RankingListPanel = 188,                                -- 排行榜面板
    -- FightMatchPanel = 189,                                  -- 血战匹配
    ServerListSelectPanel = 190,                            -- 服务器选择界面
    -- ConfirmBindPanel = 191,                                 -- 确定关联手机
    -- MatchingPopup = 192,                                    -- 匹配弹窗
    -- MinMapPopup = 193,                                      -- 小地图
    -- RolePosInfoPopup = 194,                                 -- 角色定位弹窗
    -- SoulPrintAstrologyPanel = 195,                          -- 魂印占星面板
    -- SoulPrintPanel = 196,                                   -- 魂印装备界面
    SoulPrintPopUp = 197,                                   -- 魂印弹窗
    -- SoulPrintHandBook = 198,                                -- 魂印图鉴
    -- SoulPrintPopUpV2 = 199,                                 -- 魂印详情与替换弹窗
    -- MapFightResultPopup = 200,                              -- 血战结果显示
    -- MapFightRewardPanel = 201,                              -- 血战奖励显示
    -- MapFightBuyExtraPopup = 202,                            -- 血战额外奖励令牌购买界面
    -- QuestionnairePanel = 203,                               -- 调查问卷
    -- TalismanInfoPanel = 204,                                -- 法宝进阶界面
    -- RoleTalismanChangePopup = 205,                          -- 法宝更换界面
    -- TalismanUpStarSuccessPanel = 206,                       -- 法宝进阶成功界面
    -- TalismanUpStarListPanel = 207,                          -- 法宝进阶选择界面
    -- RewardTalismanSingleShowPopup = 208,                    -- 法宝背包详情界面
    WarPowerChangeNotifyPanelV2 = 209,                      -- 战力提升V2版
    -- RewardSoulPrintSingleShowPopup = 210,                   -- 魂印属性预览界面
    -- HandBookTalismanInfoPanel = 211,                        -- 法宝图鉴详情界面
    -- DiffMonsterPreviewSecretBoxPanel = 212,                 -- 秘盒招募异妖预览
    PlayerInfoPopup = 213,                                  -- 玩家信息展示
    CDKeyExchangePanel = 214,                               -- CDKey兑换
    -- PatFaceDiffMonsterInfoPanel = 215,                      -- 异妖直购异妖详情界面
    -- TreasureOfSomebodyPanelV2 = 216,                        -- 异妖秘宝
    -- BuyTreasureLevelPanel = 217,                            -- 购买等级
    -- UnlockExtraRewardPanel = 218,                           -- 解锁额外奖励
    FightPointPassMainPanel = 219,                          -- 新关卡主界面
    -- FightSmallChoosePanel = 220,                            -- 新关卡小地图选择界面
    FightMiddleChoosePanel = 221,                           -- 新关卡中地图选择界面
    -- FightAreaRewardPopup = 222,                             -- 新关卡产出界面
    CostConfirmPopup = 223,                                 -- 通用花费确认界面
    -- RoleReturnPanel = 224,                                  -- 回溯
    BattleWinPopup = 225,                                   -- 战斗胜利弹窗
    BattleFailPopup = 226,                                  -- 战斗失败弹窗
    -- RoleReturnListPanel = 227,                              -- 回溯猎妖师选择界面
    FightPointPassRankPopup = 228,                          -- 关卡排行弹窗
    -- AlienMainPanel = 229,                                   -- 外敌主界面
    -- AlienRankRewardPopup = 230,                             -- 外敌排名奖励弹窗
    -- ElementRestraintPopup = 231,                            -- 元素克制弹窗
    FightAreaRewardFullPopup = 232,                         -- 挂机奖励预览界面
    FastExploreInfoPopup = 233,                             -- 极速探索奖励预览
    -- BattleStageTipPopup = 234,                              -- 战斗阶段提示界面
    -- PassGiftPopup = 235,                                    -- 通关豪礼面板
    ArenaTopMatchPanel = 236,                               -- 巅峰战面板
    RecordPopup = 237,                                      -- 癫疯战记录
    ArenaTypePanel = 238,                                   -- 竞技场类型选择界面
    SupremeHeroPopup = 239,                                 -- 剑影仙踪弹窗
    -- MatchTipPopup = 241,                                     -- 竞猜提示弹窗
    -- FindFairyPanel = 242,                                    -- 东海寻仙
    -- ElementPopup = 243,                                      -- 元素光环弹窗
    -- FindFairyPopup = 244,                                    -- 东海寻仙通用弹窗
    -- DropGetPlayerDecorateShopPanel = 245,                    -- 掉落获得玩家称号坐骑皮肤展示界面
    FindTreasureMainPanel = 246,                            -- 寻宝任务界面
    FindTreasureDispatchPanel = 247,                        -- 寻宝派遣界面
    FindTreasureVipPopup = 248,                             -- 寻宝vip界面
    ATMTeamRankPopup = 249,                                 -- 巅峰战小组排名
    ATMMyGuessHistoryPopup = 250,                           -- 巅峰战竞猜记录
    DoGuessPopup = 251,                                     -- 巅峰战竞猜界面
    -- GuessCoinDropPopup = 252,                               --  巅峰战竞猜成功恭喜获得
    MonthRewardPreviewPopup = 253,                          -- 鸡精奖励预览
    BattleBestPopup = 254,                                  -- 战斗最佳
    RedPacketPanel = 255,                                   -- 公会红包面板
    RedPacketPopup = 256,                                   -- 公会红包弹窗
    GuildBossPanel = 257,                                   -- 公会boss
    GuildBossTipPopup = 258,                                -- 公会boss奖励/扫荡
    GuildBossLogPopup = 259,                                -- 公会boss进攻日志
    GuildBossFightResultPopup = 260,                        -- 公会boss战斗结算
    -- ExpeditionMainPanel = 261,                           -- 远征主界面
    ExpeditionMonsterInfoPopup = 262,                       -- 远征对手详情界面
    -- ExpeditionHeroListInfoPopup = 263,                      -- 远征查看所有猎妖师血量界面
    -- ExpeditionHeroListResurgencePopup = 264,                -- 远征复活猎妖师界面
    -- ExpeditionSelectHalidomPanel = 265,                     -- 远征选择圣物界面
    -- MonsterSkillPopup = 266,                                -- 怪物技能展示
    RewardPreviewPopup = 267,                               -- 奖励预览
    -- DialoguePopup = 268,                                 -- 新增剧情对话弹窗
    -- ExpeditionHalidomPanel = 269,                        -- 远征圣物界面
    -- FightLevelSwitchPopup = 270,                         -- 关卡转场弹窗
    ResolvePanel = 271,                                     -- 献祭坛面板
    GeneralPopup = 272,                                     -- 通用弹窗
    -- AchievementPanel = 273,                              -- 成就
    CompoundPanel = 274,                                    -- 合成主界面
    -- RoleTalismanPanelV2 = 275,                              -- 改版法宝界面
    -- TalismanInfoPopup = 276,                                -- 法宝信息弹窗
    -- BattleTestPanel = 277,                                  -- 战斗测试界面
    -- RoleTalentPopup = 278,                                  -- 英雄天赋弹窗
    -- CompoundSelectListPopup = 279,                          -- 魂印合成选择界面
    FormationPanelV2 = 280,                                 -- 新编队
    SevenDayCarnivalPanelV2 = 281,                          -- 新开服狂欢
    DailyCarbonPanel = 282,
    RoleEquipTreasureChangePopup = 283,                     -- 宝物展示穿戴写下替换界面
    EquipTreasureStrongPopup = 284,                         -- 宝物强化精炼界面
    EquipTreasureResonancePanel = 285,                      -- 宝器共鸣
    BoxRewardShowPopup = 286,                               -- 宝箱弹奖励详情
    CarbonTypePanelV2 = 287,                                -- 新副本入口
    GuildSkillUpLvPopup = 288,                              -- 公会技能升级界面
    TreasureStorePopup = 289,                               -- 旅行商人
    GuildFetePopup = 290,                                   -- 公会祭祀弹窗
    DeathPosPanel = 291,                                    -- 公会十绝阵主面板
    DeathPosInfoPanel = 292,                                -- 公会十绝阵详情面板
    DeathPosRankPopup = 293,                                -- 公会十绝阵排行弹窗
    DeathPosRewardPopup = 294,                              -- 公会十绝阵奖励弹窗
    GuildCarDelayMainPanel = 295,                           -- 公会车迟斗法主界面
    GuildCarDelayFindBossPopup = 296,                       -- 公会车迟斗法查看Boss详情界面
    GuildCarDelayLootPopup = 297,                           -- 公会车迟斗法抢夺界面
    GuildCarDelayRewardSortPopup = 298,                     -- 公会车迟斗法奖励排行界面
    GuildCarDelayLootRecordPopup = 299,                     -- 公会车迟斗法抢夺记录界面
    EightDayGiftPanel = 300,                                -- 八日奖励界面
    MainRechargePanel = 301,                                -- 充值界面
    OnlineRewardPanel = 302,                                -- (新)在线奖励
    GuildAidMainPopup = 303,                                -- 公会援助
    HorseRaceLampView = 304,                                -- 跑马灯
    -- TreasureOfHeavenPanel = 305,                            -- 天宫秘宝
    -- HeavenUnlockExtraRewardPanel = 306,                     -- 天宫秘宝解锁额外奖励
    VipPanelV2 = 307,                                       -- 新的vip系统， 其实他妈是旧的
    FormationEditPopup = 308,                               -- 原编队上阵弹窗 这里暂时用于森罗幻境
    MissionDailyTipPanel = 309,                             -- 任务完成消息提示
    OpenSeverWelfarePanel = 310,                            -- 开服福利界面
    TrialRewardPopup = 311,                                 -- 试炼副本排行弹窗
    RankingListMainPanel = 312,                             -- 排行榜主界面
    RankingSingleListPanel = 313,                           -- 排行榜单个list界面
    RewardBoxPanel = 314,                                   -- 道具自选箱
    UpGradePackagePanel = 315,                              -- 升级限时礼包
    TrialMiniGamePanel = 316,                               -- 试炼小游戏界面
    ShowEnemyInfoPanel = 317,                               -- 森罗幻境遇敌信息界面
    EquipSellSelectPopup = 318,                             -- 装备分解选择界面
    QianKunBoxBuyOnePanel = 319,                            -- 乾坤宝囊购买1次
    QianKunBoxBuyTenPanel = 320,                            -- 乾坤宝囊购买10次
    XuanYuanMirrorPanel = 321,                              -- 轩辕宝镜界面
    XuanYuanMirrorPanelList = 322,                          -- 轩辕宝镜单个宝镜界面
    CarbonTypePanelV3 = 323,                                -- 轩辕宝镜单个宝镜界面
    TopMatchPlayBattleAinSelectPopup = 324,                 -- 巅峰战淘汰赛赛程记录回放
    ArenaTopMatchGuessTipViewPopup = 325,                   -- 巅峰赛竞猜结果弹窗
    DynamicActivityPanel = 326,                             -- 轮转活动通用窗口
    EquipSelectPopup = 327,                                 -- 装备选择弹窗
    HeroMainPanel = 328,                                    -- 英雄主界面
    StageMapPanel = 329,                                    -- 章节预览界面
    SupportPanel = 330,                                     -- 守护主界面
    FightRecordPopup = 331,                                 -- 通关记录界面
    FightAreaRewardPopupV2 = 332,                           -- 关卡掉落查询
    SupportSelectPanel = 333,                               -- 守护选择界面
    SupportImprovePanel = 334,                              -- 守护改良界面
    AdjutantPanel = 335,                                    -- 先驱主界面
    AdjutantFuncPopup = 336,                                -- 先驱功能弹窗
    AdjutantAutoChatShowPanel = 337,                        -- 先驱一键沟通展示界面
    AdjutantSelectPanel = 338,                              -- 先驱上阵选择界面
    FightAreaRewardReminderPopup = 339,                     -- 新挂机奖励预览界面
    RoleRankUpConfirmPopup = 340,                           -- 升品确认弹窗
    BlackShopPanel = 341,                                   -- 黑市界面
    GeneralInfoPanel = 342,                                 -- 契约窗口
    FormationPositonPopup = 343,                            -- 队伍阵型界面
    FormationBuffPopup = 344,                               -- 克制关系界面
    WarWayComprehendPopup = 345,                            -- 战法领悟界面
    WarWayLevelUpPopup = 346,                               -- 战法升级界面
    WarWayPreviewPopup = 347,                               -- 战法预览界面
    CombatPlanCompoundPanel = 348,                          -- 作战计划合成界面
    CombatPlanTipsPopup = 349,                              -- 作战计划tips界面
    EquipPlanResetPopup = 350,                              -- 作战计划重铸界面
    ClimbTowerPanel = 351,                                  -- 爬塔主界面
    ClimbTowerGoFightPopup = 352,                           -- 爬塔战前界面
    ClimbTowerBattleReportPopup = 353,                      -- 爬塔战报界面
    ClimbTowerRankPopup = 354,                              -- 爬塔排行榜界面
    ClimbTowerRewardPopup = 355,                            -- 爬塔任务奖励界面
    CompoundHeroPanel = 356,                                -- 定制补给界面
    ClimbTowerUnlockPopup = 357,                            -- 爬塔解锁特权界面
    AssemblePanel = 358,                                    -- 装配厂界面
    GuildActivePointPopup = 359,                            -- 工会活跃点界面
    GuildActivePointRewardPopup = 360,                      -- 工会活跃点奖励预览界面
    HeroExchangePanel = 361,                                -- 改造厂界面
    HeroListPopup = 362,                                    -- 改造坦克展示弹窗
    GuildLogPopup = 363,                                    -- 联盟日志
    GuildMemberPopup = 364,                                 -- 联盟成员
    GuildApplyPopup = 365,                                  -- 联盟申请
    GuildTranscriptMainPopup = 366,                         -- 联盟副本
    GuildTranscriptRewardSortPanel = 367,                   -- 联盟副本奖励排行
    DefenseTrainingPopup = 368,                             -- 防守训练主弹窗
    DefenseTrainingRankPopup = 369,                         -- 防守训练排行弹窗
    DefenseTrainingRewardPopup = 370,                       -- 防守训练奖励一览弹窗
    DefenseTrainingSupportPopup = 371,                      -- 防守训练支援弹窗
    BlitzStrikePanel = 372,                                 -- 闪电出击主界面
    BlitzStrikePreFightPopup = 373,                         -- 闪电出击准备战斗弹窗
    BlitzStrikeRelivePopup = 374,                           -- 闪电出击复活弹窗
    BlitzStrikeSupportPopup = 375,                          -- 闪电出击支援弹窗
    BlitzStrikeDifficultSelectPopup = 376,                  -- 闪电出击难度选择弹窗
    HegemonyPanel = 377,                                    -- 破碎王座界面
    HegemonyPopup = 378,                                    -- 三强争霸挑战弹窗
    HegemonyChallengePopup = 379,                           -- 三强争霸挑战记录弹窗
    ATM_RankViewPanel = 380,                                -- 联赛排行榜界面
    HegemonyTipPopup = 381,                                 -- 三强争霸提示弹窗
    XuanYuanMirrorRankPopup = 382,                          -- 阿登战役排行榜
    XuanYuanMirrorRewardSortPopup = 383,                    -- 阿登战役奖励弹窗
    GenerlProInfoPopup = 384,                               -- 名将升阶数据弹窗
    MinskShopPanel = 385,                                   -- 梦魇入侵商店
    BattleOfMinskHurtRewardSortPopup = 386,                 -- 梦魇入侵伤害奖励排行
    BattleOfMinskHurtSortPopup = 387,                       -- 梦魇入侵个人伤害排行
    BattleOfMinskMainPanel = 388,                           -- 梦魇入侵主面板
    BattleOfMinskRewardSortPopup = 389,                     -- 梦魇入侵排名奖励
    BattleOfMinskDocumentPopup = 390,                       -- 梦魇入侵军机文档
    BattleOfMinskBuyCountPopup = 391,                       -- 梦魇入侵购买次数界面
    CombatPlanSelectPopup = 392,                            -- 作战计划选择界面
    MedalChangelPopup = 393,                                -- 勋章更换弹窗
    MedalConversionPopup = 394,                             -- 勋章转化弹窗
    MedalConversionTargetPopup = 395,                       -- 勋章转化目标选择弹窗
    MedalParticularsPopup = 396,                            -- 勋章详情弹窗
    MedalSuitPopup = 397,                                   -- 勋章套装管理弹窗
    MedalTeachPopup = 398,                                  -- 勋章洗练面板
    CombatPlanCompoundSelectPopup = 399,                    -- 作战计划合成选择界面
    AlameinWarPanel = 400,                                  -- 阿拉曼战役主界面
    AlameinWarStagePanel = 401,                             -- 阿拉曼战役选关界面
    MedalCompoundChoosePopup = 402,                         -- 勋章合成选择界面
    MedalAtlasPopup = 403,                                  -- 勋章图谱界面
    LaddersMainPanel = 404,                                 -- 天梯赛主面板
    LaddersChallengeRecordPanel = 405,                      -- 天梯赛挑战记录界面
    LaddersKingPanel = 406,                                 -- 天梯赛巅峰王者界面
    LaddersPlayerInfoPopup = 407,                           -- 天梯赛挑战阵容界面
    -- LaddersRankSortPopup = 408,                             -- 天梯赛排行榜弹窗
    -- LaddersRewardSortPopup = 409,                           -- 天梯赛奖励预览弹窗
    LogisticsMainPanel = 410,                               -- 后勤主界面
    AircraftCarrierUnlockPanel = 411,                       -- 航母解锁界面
    AircraftCarrierDesignMainPanel = 412,                   -- 航母设计主界面
    AircraftCarrierDesignFactoryUpPopup = 413,              -- 航母设计工厂升级弹窗
    AircraftCarrierMeterialSelectPopup = 414,               -- 航母设计材料选择弹窗
    AircraftCarrierPrototypeSelectPopup = 415,              -- 航母设计原型选择弹窗
    AircraftCarrierPlaneDesignSucPopup = 416,               -- 航母战机设计成功弹窗
    AircraftCarrierPrivilegeActivatePopup = 417,            -- 航母特权激活弹窗
    AircraftCarrierSkillSequencePopup = 418,                -- 航母技能顺序选择弹窗
    AircraftCarrierPlaneUpLvPopup = 419,                    -- 航母飞机升级弹窗
    AircraftCarrierPlaneSelectPopup = 420,                  -- 航母飞机选择弹窗
    ReconnaissancePanel = 421,                              -- 勘察面板
    ReconnaissanceRecord = 422,                             -- 勘察记录
    AircraftCarrierPlaneAtlasPopup = 423,                   -- 航母飞机图谱弹窗
    GeneralRankRewardPanel = 424,                           -- 通用排行奖励界面
    GuideBattlePanel = 425,
    BackGroundInfoPanel = 426,                              -- 背景介绍界面
    AircraftCarrierPlaneTipsPopup = 427,                    -- 航母飞机tips弹窗
    GeneralBigPopup = 428,                                  -- 通用大弹窗界面
    DefenseTrainingBuffPopup = 429,                         -- 防守训练buff弹窗
    AlameinWarRewardPopup = 430,                            -- 阿拉曼战役领取界面弹窗
    CombatPlanPromotedSelectPopup = 431,                    -- 阿拉曼战役领取界面弹窗
    FormationCenterActiveOrUpgradeSuccessPanel = 432,       -- 情报中心解锁成功
    FormationCenterActivePanel = 433,                       -- 启明星科技解锁
    FormationCenterPanel = 434,                             -- 启明星科技
    FormationCenterTipPanel = 435,                          -- 启明星科技Tips
    PartsMainPopup = 436,                                   -- 铸神主界面弹窗
    PartsMeterialSelectPopup = 437,                         -- 铸神材料选择弹窗
    PartsSkillOverviewPopup = 438,                          -- 铸神技能总览弹窗
    FormationStartCombatPanel = 439,                        -- 启明星科技开战
    TalentSwitchPopup = 440,                                -- 特性切换弹窗（天赋）
    ClimbTowerElitePanel = 441,                             -- 爬塔精英主界面
    ClimbTowerEliteGoFightPopup = 442,                      -- 爬塔精英战前界面
    ClimbTowerEliteBattleReportPopup = 443,                 -- 爬塔精英战报界面
    ClimbTowerEliteRankPopup = 444,                         -- 爬塔精英排行榜界面
    ClimbTowerEliteRewardPopup = 445,                       -- 爬塔精英任务奖励界面
    ClimbTowerEliteUnlockPopup = 446,                       -- 爬塔精英解锁特权界面
    MedalAssembleChoosePopup = 447,                         -- 勋章套装选择装配栏位弹窗
    MedalSameTipPopup = 448,                                -- 勋章套装勋章佩戴相同提示弹窗
    ClimbTowerEliteFilterStarPopup = 449,                   -- 爬塔精英筛选星级弹窗
    GrowthManualPanel = 450,                                -- 成长手册 
    GrowthManualBuyPanel = 451,                             -- 成长手册购买
    GrowthManualLevelUpPanel = 452,                         -- 成长手册等级提升
    ToTemListPopup = 453,                                   -- 图鉴列表展示
    ToTemParticularsPopup = 454,                            -- 图鉴详情
    ToTemUpLvPopup = 455,                                   -- 图鉴升级升阶
    VideoPanel = 997,                                       -- 视频动画界面
    ChatSelectChannelPopup = 998,                           -- 聊天频道选择弹窗
    BuffPreviewPopup = 999,                                 -- Buff预览
    NiuQiChongTianPanel = 456,                              -- 战车达人
    JumpSelectPopup = 457,                                  -- 跳转选择界面
    ShopIndependentPanel = 458,                             -- 独立商城
    CustomSuppliesShopPanel = 459,                          -- 定制补给商城
    BattleStartPopup = 460,                                 -- 战斗开始动画
    PublicGetHeroPanel = 995,                               -- 获得英雄动画
    -- XiaoYaoYouPanel = 460,                                  -- 逍遥游入口界面
    XiaoYaoMapPanel = 461,                                  -- 逍遥游地图界面
    XiaoyaoHeroGetPopup = 462,                              -- 逍遥游购买神将
    -- XiaoYaoLuckyBossPopup = 463,                            -- 逍遥游boss来袭
    XiaoYaoLuckyTurnTablePopup = 464,                       -- 逍遥游幸运转盘
    XiaoYaoRewardPreviewPanel = 465,                        -- 逍遥游奖池预览界面
    AdjutantActivityPanel = 466,                            -- 副官活动
    LaddersTypePanel = 467,                                 -- 天梯赛入口
    SignInDays = 468,                                       -- 多日签到
    XiaoYaoEventPanel = 469,                                -- 添加完成界面
    FestivalActivityPanel = 470,                            -- 节日界面
    ArtilleryDrillsPanel = 471,                             -- 炮击演练
    LoadingPopup = 472,                                     -- LoadingPopup
    BattlePassPanel = 473,                                  -- 手札
    CommonInfoPopup = 474,                                  -- infoCommon
    EvaluateTankPopup = 475,                                -- 坦克评论界面
    HeroMonumentPanel = 476,                                -- 英雄丰碑
    ThousandDrawPanel = 993,                                -- 千抽
    ValuePackPanel = 994,                                   -- 超值礼包
    LineupRecommend = 992,                                  -- 阵容推荐
    PVEActivityPanel = 991,                                 -- PVE活动
    GuildBattlePanel = 990,                                 -- 公会战
    CommentPanel = 989,                                     -- 英雄评论
    RankAllSeverRewardPanel = 988,                          -- 全服排行奖励
    RankTopFivePanel = 987,                                 -- 排行奖励
    CardActivityPanel = 986,                                -- 卡牌主题活动
    OpenServiceGiftPanel = 985,                             -- 开服有礼
    GuildChallengeInfoPanel = 984,                          -- 公会战挑战信息
    PublicAwardPoolPreviewPanel = 983,                      -- 通用奖池预览
    PowerCenterPanel = 982,                                 -- 异能中心
    LeadPanel = 981,                                        -- 主角
    LeadAssemblyPanel = 980,                                -- 主角装配
    LeadUpLevelPanel = 979,                                 -- 主角升级
    LeadRAndDPanel = 978,                                   -- 主角研发
    -- LeadChooseAtlasPanel = 977,                             -- 主角选择图谱
    LeadGeneEvolutionPanel = 976,                           -- 主角基因进化
    LeadGeneTopLevelPanel = 975,                            -- 主角基因顶级
    LeadGeneAtlaslPanel = 974,                              -- 主角基因图谱
    LeadGotoActivationPanel = 973,                          -- 主角前往激活
    WarOrderPanel = 972,                                    -- 战令
    GuildBattleRankPanel = 971,                             -- 公会战排行
    PrivacyPanel = 1000,                                    -- 协议
    PermissionPanel = 1001,                                 -- 权限申请
    CustomerServicePanel = 1002,                            -- 客服
    ChaosSelectCampPanel = 1003,                            -- 混乱之治选择阵容
    ChaosMainPanel = 1004,                                  -- 混乱主界面
    ChaosFormationPanel = 1005,                             -- 混乱阵容
    ChaosChangeStarPanel = 1006,                            -- 混乱挑战
    ChaosTaskPanel = 1007,                                  -- 混乱之治任务
    UnLockWarOrderPanel = 1008,                             -- 战令购买
}

SubUIConfig = {
    UpView = { name = "UpView", assetName = "UpView", script = "View/UpView" },
    BtView = { name = "BtView", assetName = "BtView", script = "View/BtView" },
    ShopItemView = { name = "ShopItemView", assetName = "ShopItemView", script = "View/ShopItemView" },
    ItemView = { name = "ItemView", assetName = "ItemView", script = "View/ItemView" },
    RoleItemView = { name = "RoleItemView", assetName = "RoleItemView", script = "View/RoleItemView" },
    DragView = { name = "DragView", assetName = "DragView", script = "View/DragView" },
    ScrollCycleView = { name = "ScrollCycleView", assetName = "ScrollCycleView", script = "View/ScrollCycleView" },
    ScrollFitterView = { name = "ScrollFitterView", assetName = "ScrollCycleView", script = "View/ScrollFitterView" },
    NumberView = { name = "NumberView", assetName = "NumberView", script = "View/NumberView" },
    ShopView = { name = "ShopView", assetName = "ShopView", script = "View/ShopView" },
    JumpView = { name = "JumpView", assetName = "JumpView", script = "View/JumpView" }, --前往
    ElementalResonanceView = { name = "ElementalResonanceView", assetName = "ElementalResonanceView", script = "View/ElementalResonanceView" }, --前往
    PlayerHeadView = { name = "PlayerHeadView", assetName = "PlayerHead", script = "View/PlayerHeadView" }, -- 玩家头像
    HorseRaceLampView = { name = "HorseRaceLampView", assetName = "HorseRaceLamp", script = "Message/HorseRaceLampView" }, -- 跑马灯
    ChatTipView = { name = "ChatTipView", assetName = "ChatTipView", script = "View/ChatTipView" }, -- 聊天Tip
    PlayerLiveView = { name = "PlayerLiveView", assetName = "PlayerLiveView", script = "View/PlayerLiveView" }, -- 玩家动态例会（小人）
    PlayerHeadFrameView = { name = "PlayerHeadFrameView", assetName = "PlayerHeadFrameView", script = "View/PlayerHeadFrameView" }, --界面上方头像
    GuideTaskView = { name = "GuideTaskView",assetName = "GuideTaskView",script = "View/GuideTaskView" },--指引任务
    FormationStartCombatView = { name = "FormationStartCombatView",assetName = "FormationStartCombatPanel",script = "Modules/FormationCenter/FormationStartCombatPanel" }, --< battle sub 战前开始

    [1] = {name = "EveryDayGift",assetName = "EveryDayGift",script = "Modules/Recharge/View/EveryDayGift"},
    [2] = {name = "GiftPre",assetName = "GiftPre",script = "Modules/Recharge/View/GiftPre"},
    [3] = {name = "RechargeView",assetName = "RechargeView",script = "Modules/Recharge/View/RechargeView"},
    [4] = {name = "CumulativeSignInPage",assetName = "CumulativeSignInPage",script = "Modules/Operating/CumulativeSignInPage"},
    [5] = {name = "MonthCardPage",assetName = "MonthCardPage",script = "Modules/Operating/MonthCardPage"},
    [6] = {name = "GrowthGiftPage",assetName = "GrowthGiftPage",script = "Modules/Operating/GrowthGiftPage"},
    [7] = {name = "MissionPre",assetName = "MissionPre",script = "Modules/Operating/MissionPre"},
    [8] = {name = "UppperMonthCard",assetName = "UppperMonthCard",script = "Modules/Operating/UppperMonthCard"},
    [9] = {name = "ItemUpstarPre",assetName = "ItemUpstarPre",script = "Modules/NewActivity/ItemUpstarPre"},--装备升星单条预设
    [10] = {name = "CommonActPage",assetName = "CommonActPage",script = "Modules/NewActivity/CommonActPage"},--活动界面预设
    [11] = {name = "ExpertPage",assetName = "ExpertPage",script = "Modules/NewActivity/ExpertPage"},--达人界面预设
    [12] = {name = "ExpertPre",assetName = "ExpertPre",script = "Modules/NewActivity/ExpertPre"},--达人单条预设
    [13] = {name = "ConRechargePage",assetName = "ConRechargePage",script = "Modules/NewActivity/ConRechargePage"},--积天豪礼界面预设
    [14] = {name = "ExChangePage",assetName = "ExChangePage",script = "Modules/NewActivity/ExChangePage"},--限时兑换界面预设

    [15] = {name = "page2",assetName = "page2",script = "Modules/DynamicActivity/SheJiDaDian"}, --社稷大典
    --[16] = {name = "TimeLimitUpHero",assetName = "TimeLimitUpHero",script = "Modules/DynamicActivity/TimeLimitUpHero"}, --限时召唤
    [16] = {name = "page3",assetName = "page3",script = "Modules/DynamicActivity/TimeLimitedCall"}, --限时召唤
    [17] = {name = "page4",assetName = "page4",script = "Modules/DynamicActivity/QianKunBox"},--乾坤宝盒
    [18] = {name = "page9",assetName = "page9",script = "Modules/DynamicActivity/YiJingBaoKu"},--易经宝库
    [19] = {name = "page10",assetName = "page10",script = "Modules/DynamicActivity/ShengYiTianJiang"},--神衣天降
    [20] = {name = "page11",assetName = "page11",script = "Modules/DynamicActivity/LingShowTeHui"},--灵兽特惠
    [21] = {name = "page12",assetName = "page12",script = "Modules/DynamicActivity/LingShouBaoGe"},--灵兽宝阁
    [22] = {name = "page13",assetName = "page13",script = "Modules/DynamicActivity/XinJiangLaiXi"},--新将来袭
    [23] = {name = "page14",assetName = "page14",script = "Modules/DynamicActivity/XiangYaoDuoBao"},--降妖夺宝
    [24] = {name = "ShopView", assetName = "ShopView", script = "View/ShopViewNew" },
    [25] = {name = "FuXingGaoZhaoPanel", assetName = "FuXingGaoZhaoPanel", script = "Modules/FuXingGaoZhao/FuXingGaoZhaoPanel" },
    [26] = {name = "NiuQiChongTianPanel", assetName = "NiuQiChongTianPanel", script = "Modules/NiuQiChongTian/NiuQiChongTianPanel" },
    [27] = {name = "TimeLimitUpHero",assetName = "TimeLimitUpHero",script = "Modules/DynamicActivity/TimeLimitUpHero"}, --限时英雄up界面
    [28] = {name = "LingLongBaoJingPanel",assetName = "LingLongBaoJingPanel",script = "Modules/linglongbaojing/LingLongBaoJingPanel"}, --限时英雄up界面
    [30] = {name = "UpStarPre",assetName = "UpStarPre",script = "Modules/UpStar/UpStarPre"}, --限时英雄up界面
    [29] = {name = "page15",assetName = "page15",script = "Modules/DynamicActivity/ShengXingYouLi"},--升星有礼
    [31] = {name = "RecruitPanelNew",assetName = "RecruitPanelNew",script = "Modules/Recruit/RecruitPanelNew"},--
    [32] = {name = "ElementDrawCardPanelNew",assetName = "ElementDrawCardPanelNew",script = "Modules/Recruit/ElementDrawCardPanelNew"},--升星有礼
}