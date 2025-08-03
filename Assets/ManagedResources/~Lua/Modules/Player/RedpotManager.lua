---
---  红点系统使用方法：
---     1、注册：
---         在   RedPointType  中注册相应的红点枚举
---     2、设置红点关系：
---         在   RedPotManager.InitRedPointAllRelate 设置红点的层级关系（树结构）
---            如： RPData:SetParent(rpType1, rpType2)
---             参数：     rpType1     子红点
---                        rpType2     父红点
---     3、注册红点的检测方法：
---         在   RedPotManager.RegisterRedCheckFunc  注册红点的检测方法，要求方法返回是否显示红点，显示返回 true
---            如：RPData:AddCheckFunc(rpType, func, funcType)
---             参数：     rpType       红点类型
---                        func         红点检测方法（返回  true 显示，false 不显示）
---                        funcType     红点对应的功能解锁类型（用于判断红点对应的功能是否已经解锁, 可为空，空则不判断）
---             *****注：只有没有子红点的红点才能注册红点检测方法，父红点的状态由所有的子红点决定*****
---
---     4、注册红点对象：
---         使用全局方法 BindRedPointObject 进行红点枚举与红点对象的绑定
---         使用全局方法 ClearRedPointObject  清楚红点枚举上绑定的所有物体（*******请在界面关闭时务必清理绑定的红点）
---
---     5、刷新红点状态
---         使用全局方法  CheckRedPointStatus  主动刷新红点的状态，在红点状态可能改变时调用此方法进行红点状态检测，
---      参数为无子红点的红点枚举，此方法会自动检测红点状态，并向父级递归设置父级的状态
---
---     *6、强制设置红点状态（此方法为预留方法，会使红点状态脱离管理，谨慎使用）
---         使用全局方法  ChangeRedPointStatus  强制设置红点状态，并向父级递归设置状态
---
---     7、服务器红点
---         1> 与服务器约定，并按第1、2步注册红点枚举、设置红点关系，服务器会在登录和需要时将红点推送到前端，并自动设置红点状态。
---         2> 在下面 ServerRedType 中声明服务器红点枚举。
---         3> 服务器红点无法注册检测方法（服务器和本地检测都需要的红点，请拆分为两个子红点），但可以注册功能解锁类型
---         4> 按第4步注册红点绑定的物体
---         5> 服务器红点无法刷新，在无需显示改红点时，请调用全局方法 ResetServerRedPointStatus 将服务器红点状态重置为隐藏状态。
---
---
require "Message/MessageTypeProto_pb"
require "Message/PlayerInfoProto_pb"

RedpotManager = {}
local this = RedpotManager

local RPData = require("Modules/Player/RedPointData")
local BindObjs = {}

-- 声明服务器红点类型
local ServerRedType = {
    RedPointType.Mail_Server,
    RedPointType.SecretTer_Boss,
    RedPointType.Arena_Record,
    RedPointType.Guild_Apply,
}

function this.Initialize()
    -- 清除绑定物体
    BindObjs = {}

    -- 初始化数据
    this.SetServerRedPointData()
    this.InitRedPointAllRelate()
    this.RegisterRedCheckFunc()

    -- 监听功能开启，结束事件
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionOpen, this.RefreshRedpotByFunctionOpenType)
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionClose, this.RefreshRedpotByFunctionOpenType)
end

-- 根据功能
function this.RefreshRedpotByFunctionOpenType(openType)
    -- 本地红点
    local checkList = RPData:GetCheckList()
    for rpType, checkData in pairs(checkList) do
        if checkData.openType == openType then
            this.CheckRedPointStatus(rpType)
        end
    end
end

-- 初始化红点关系
function this.InitRedPointAllRelate()
    RPData:SetParent(RedPointType.ForgottenCity, RedPointType.ExploreMain)
    RPData:SetParent(RedPointType.HeroExplore, RedPointType.ExploreMain)
    RPData:SetParent(RedPointType.EpicExplore, RedPointType.ExploreMain)
    RPData:SetParent(RedPointType.LegendExplore, RedPointType.ExploreMain)


    RPData:SetParent(RedPointType.LuckyCat_GetReward, RedPointType.LuckyCat)
    -- 充值
    RPData:SetParent(RedPointType.VIP_SHOP_DETAIL, RedPointType.Shop_Page_Recharge)
    -- 主界面商店
    RPData:SetParent(RedPointType.Shop_Page_General, RedPointType.Shop)
    RPData:SetParent(RedPointType.Shop_Page_Coin, RedPointType.Shop)
    RPData:SetParent(RedPointType.Shop_Page_Play, RedPointType.Shop)
    RPData:SetParent(RedPointType.Shop_Page_Roam, RedPointType.Shop)
    -- 商店小页签
    RPData:SetParent(RedPointType.Shop_Tab_General, RedPointType.Shop_Page_General)
    RPData:SetParent(RedPointType.Shop_Tab_Secret, RedPointType.Shop_Page_Coin)
    RPData:SetParent(RedPointType.Shop_Tab_Arena, RedPointType.Shop_Page_Play)
    RPData:SetParent(RedPointType.Shop_Tab_Guild, RedPointType.Shop_Page_Play)
    RPData:SetParent(RedPointType.Shop_Tab_Roam, RedPointType.Shop_Page_Roam)
    -- 商店功能
    RPData:SetParent(RedPointType.Shop_General_Check, RedPointType.Shop_Tab_General)
    RPData:SetParent(RedPointType.Shop_Secret_Check, RedPointType.Shop_Tab_Secret)
    RPData:SetParent(RedPointType.Shop_Arena_Check, RedPointType.Shop_Tab_Arena)
    RPData:SetParent(RedPointType.Shop_Guild_Check, RedPointType.Shop_Tab_Guild)
    RPData:SetParent(RedPointType.Shop_Roam_Check, RedPointType.Shop_Tab_Roam)

    -- 竞技场
    RPData:SetParent(RedPointType.Arena_Type_Normal, RedPointType.Arena)
    RPData:SetParent(RedPointType.Arena_Record, RedPointType.Arena_Type_Normal)
    -- RPData:SetParent(RedPointType.Arena_Shop, RedPointType.Arena_Type_Normal)
    RPData:SetParent(RedPointType.ArenaTodayAlreadyLike, RedPointType.Arena)

    -- 工坊
    RPData:SetParent(RedPointType.Refining_Weapon, RedPointType.Refining)
    RPData:SetParent(RedPointType.Refining_Armor, RedPointType.Refining)

    -- 邮件
    RPData:SetParent(RedPointType.Mail_Local, RedPointType.Mail)
    RPData:SetParent(RedPointType.Mail_Server, RedPointType.Mail)

    -- 秘境
    RPData:SetParent(RedPointType.CourtesyDress_Online, RedPointType.SecretTer)
    RPData:SetParent(RedPointType.CourtesyDress_Chapter, RedPointType.SecretTer)
    RPData:SetParent(RedPointType.SecretTer_FindTreasure, RedPointType.SecretTer)
    RPData:SetParent(RedPointType.DailyTask, RedPointType.DailyTaskMain)
    RPData:SetParent(RedPointType.SecretTer_MaxBoxReward, RedPointType.SecretTer)
    RPData:SetParent(RedPointType.SecretTer_HaveFreeTime, RedPointType.SecretTer)
    RPData:SetParent(RedPointType.SecretTer_IsCanFight, RedPointType.SecretTer)

    -- 外敌
    RPData:SetParent(RedPointType.SecretTer_Boss, RedPointType.Alien)
    RPData:SetParent(RedPointType.SecretTer_CallAlianInvasionTime, RedPointType.Alien)

    -- 秘盒红点
    RPData:SetParent(RedPointType.SecretBox_Red1, RedPointType.SecretBox)

    -- 角色招募红点
    RPData:SetParent(RedPointType.Recruit_Red, RedPointType.Recruit)
    RPData:SetParent(RedPointType.RecruitTen_Red, RedPointType.Recruit)

    -- 普通召唤红点
    RPData:SetParent(RedPointType.Recruit_Normal, RedPointType.Recruit)
    RPData:SetParent(RedPointType.RecruitTen_Normal, RedPointType.Recruit)

    -- 福利
    RPData:SetParent(RedPointType.GrowthGift, RedPointType.Operating)
    RPData:SetParent(RedPointType.CumulativeSignIn, RedPointType.Operating)
    -- RPData:SetParent(RedPointType.GiftPage, RedPointType.Operating)
    RPData:SetParent(RedPointType.EveryWeekPreference, RedPointType.Operating)
    RPData:SetParent(RedPointType.EveryMonthPreference, RedPointType.Operating)
    RPData:SetParent(RedPointType.WeekendWelfare, RedPointType.Operating)
    RPData:SetParent(RedPointType.WeekCard, RedPointType.Operating)
    
    --激励计划
    RPData:SetParent(RedPointType.LifeMemeber, RedPointType.IncentivePlan)
    RPData:SetParent(RedPointType.SuperLiftMember, RedPointType.IncentivePlan)
    RPData:SetParent(RedPointType.SpecialFunds, RedPointType.IncentivePlan)
    RPData:SetParent(RedPointType.WarOrder, RedPointType.IncentivePlan)

    --终身会员
    RPData:SetParent(RedPointType.LifeMemeberFree, RedPointType.LifeMemeber)
    RPData:SetParent(RedPointType.LifeMemeberEveryDay, RedPointType.LifeMemeber)

    --超级终身会员
    RPData:SetParent(RedPointType.SuperLiftMemberFree, RedPointType.SuperLiftMember)
    RPData:SetParent(RedPointType.SuperLiftMemberEveryDay, RedPointType.SuperLiftMember)

    --战令
    RPData:SetParent(RedPointType.WarOrder_Abyss, RedPointType.WarOrder)
    RPData:SetParent(RedPointType.WarOrder_DenseFog, RedPointType.WarOrder)
    RPData:SetParent(RedPointType.WarOrder_Heresy, RedPointType.WarOrder)
    RPData:SetParent(RedPointType.WarOrder_MagicTower, RedPointType.WarOrder)
    RPData:SetParent(RedPointType.WarOrder_Tower, RedPointType.WarOrder)

    -- 主题活动
    RPData:SetParent(RedPointType.TimeLimited, RedPointType.DynamicActivity)
    RPData:SetParent(RedPointType.QianKunBox, RedPointType.DynamicActivity)
    RPData:SetParent(RedPointType.DynamicActTask, RedPointType.DynamicActivity)
    RPData:SetParent(RedPointType.DynamicActRecharge, RedPointType.DynamicActivity)

    -- 好友
    RPData:SetParent(RedPointType.Friend_Reward, RedPointType.Friend)
    RPData:SetParent(RedPointType.Friend_Application, RedPointType.Friend)

    -- 设置
    RPData:SetParent(RedPointType.Setting_Head, RedPointType.Setting)
    RPData:SetParent(RedPointType.HeadChange_Frame, RedPointType.Setting_Head)
    RPData:SetParent(RedPointType.HeadChange_Head, RedPointType.Setting_Head)

    -- 限时活动
    RPData:SetParent(RedPointType.Expert_AdventureExper, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_AreaExper, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_UpStarExper, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_EquipExper, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_GoldExper, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_FightExper, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_EnergyExper, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_AccumulativeRecharge, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_Talisman, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_SoulPrint, RedPointType.Expert)
    RPData:SetParent(RedPointType.LuckyCat, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_WeekCard, RedPointType.Expert)
    RPData:SetParent(RedPointType.HERO_STAR_GIFT, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_FindTreasure, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_LuckyTurn, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_Recruit, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_SecretBox, RedPointType.Expert)
    RPData:SetParent(RedPointType.Expert_UpLv, RedPointType.Expert)
    RPData:SetParent(RedPointType.ContinuityRecharge, RedPointType.Expert)
    RPData:SetParent(RedPointType.OpenService, RedPointType.Expert)
    RPData:SetParent(RedPointType.BoxPool, RedPointType.Expert)
    --扭蛋
    RPData:SetParent(RedPointType.BoxPoolFreeTime, RedPointType.BoxPool)
    RPData:SetParent(RedPointType.BoxPoolCanDraw, RedPointType.BoxPool)

    -- 战力排行
    RPData:SetParent(RedPointType.WarPowerSort_Sort, RedPointType.WarPowerSort)

    --背包
    RPData:SetParent(RedPointType.Bag_HeroDebris, RedPointType.Bag)
    RPData:SetParent(RedPointType.Bag_BoxAndBlueprint, RedPointType.Bag)
    
    --英雄tab
    RPData:SetParent(RedPointType.LineupRecommend, RedPointType.Role)
    RPData:SetParent(RedPointType.HeroTab, RedPointType.Role)

    -- 公会
    RPData:SetParent(RedPointType.Guild_House, RedPointType.Guild)
    RPData:SetParent(RedPointType.Guild_House_Apply, RedPointType.Guild_House)
    RPData:SetParent(RedPointType.Guild_Apply, RedPointType.Guild_House_Apply)
    RPData:SetParent(RedPointType.Guild_Shop, RedPointType.Guild)
    -- RPData:SetParent(RedPointType.Guild_Boss, RedPointType.Guild)
    RPData:SetParent(RedPointType.Guild_RedPacket, RedPointType.Guild)
    RPData:SetParent(RedPointType.Guild_Fete, RedPointType.Guild)
    -- RPData:SetParent(RedPointType.Guild_Aid, RedPointType.Guild)
    -- RPData:SetParent(RedPointType.Guild_AidMy, RedPointType.Guild_Aid)
    -- RPData:SetParent(RedPointType.Guild_AidGuild, RedPointType.Guild_Aid)
    -- RPData:SetParent(RedPointType.Guild_AidBox, RedPointType.Guild_Aid)
    RPData:SetParent(RedPointType.Guild_Transcript, RedPointType.Guild)
    RPData:SetParent(RedPointType.Guild_Skill, RedPointType.Guild)
    -- RPData:SetParent(RedPointType.Guild_DeathPos, RedPointType.Guild)
    RPData:SetParent(RedPointType.GuildBattle, RedPointType.Guild)
    --公会战
    RPData:SetParent(RedPointType.GuildBattle_BoxReward, RedPointType.GuildBattle)
    RPData:SetParent(RedPointType.GuildBattle_FreeTime, RedPointType.GuildBattle)

    RPData:SetParent(RedPointType.Chat_Friend, RedPointType.Chat)
    -- 东海寻仙
    RPData:SetParent(RedPointType.FindFairy_OneView, RedPointType.FindFairy)
    RPData:SetParent(RedPointType.FindFairy_ThreeView, RedPointType.FindFairy)
    RPData:SetParent(RedPointType.FindFairy_FourView, RedPointType.FindFairy)

    -- 成就
    RPData:SetParent(RedPointType.Achievement_Main, RedPointType.DailyTaskMain)

    -- 大闹天宫 天宫秘宝
    RPData:SetParent(RedPointType.Expedition_Treasure, RedPointType.Expedition)

    -- 支援
    -- RPData:SetParent(RedPointType.Support_Gift, RedPointType.Support)
    -- RPData:SetParent(RedPointType.Support_LevelUpBtn, RedPointType.Support_LevelUp)
    -- RPData:SetParent(RedPointType.Support_LevelUp, RedPointType.Support)
    -- RPData:SetParent(RedPointType.Support_SkillBtn, RedPointType.Support_Skill)
    -- RPData:SetParent(RedPointType.Support_Skill, RedPointType.Support)
    -- RPData:SetParent(RedPointType.Support_RemouldBtn, RedPointType.Support_Remould)
    -- RPData:SetParent(RedPointType.Support_Remould, RedPointType.Support)
    
    -- 免费赞助
    RPData:SetParent(RedPointType.Revenue_Free, RedPointType.UpView_Gold)

    -- 先驱
    RPData:SetParent(RedPointType.Adjutant_FreeButton, RedPointType.Adjutant)
    -- RPData:SetParent(RedPointType.Adjutant_Btn_ChatChildO, RedPointType.Adjutant_Btn_Chat)
    -- RPData:SetParent(RedPointType.Adjutant_Btn_ChatChildT, RedPointType.Adjutant_Btn_Chat)
    RPData:SetParent(RedPointType.Adjutant_Btn_Chat, RedPointType.Adjutant)
    -- RPData:SetParent(RedPointType.Adjutant_Btn_SkillChild, RedPointType.Adjutant_Btn_Skill)
    RPData:SetParent(RedPointType.Adjutant_Btn_Skill, RedPointType.Adjutant)
    -- RPData:SetParent(RedPointType.Adjutant_Btn_HandselChild, RedPointType.Adjutant_Btn_Handsel)
    RPData:SetParent(RedPointType.Adjutant_Btn_Handsel, RedPointType.Adjutant)
    -- RPData:SetParent(RedPointType.Adjutant_Btn_TeachChild, RedPointType.Adjutant_Btn_Teach)
    RPData:SetParent(RedPointType.Adjutant_Btn_Teach, RedPointType.Adjutant)
    -- RPData:SetParent(RedPointType.Adjutant_Gift, RedPointType.Adjutant)

    -- 若充值未开启就直接取消红点就ok了
    if RECHARGEABLE then--（是否开启充值）
        RPData:SetParent(RedPointType.KingMonthCard, RedPointType.Operating)
        RPData:SetParent(RedPointType.NobilityMonthCard, RedPointType.Operating)
        RPData:SetParent(RedPointType.Shop_Page_Recharge, RedPointType.Recharge)
        RPData:SetParent(RedPointType.DailyGift, RedPointType.Recharge)
        -- RPData:SetParent(RedPointType.GrowthPackage, RedPointType.Recharge)
        RPData:SetParent(RedPointType.VipPanel, RedPointType.Recharge)
    end

    -- 外援
    RPData:SetParent(RedPointType.Support, RedPointType.Logistics)
    RPData:SetParent(RedPointType.Adjutant, RedPointType.Logistics)
    -- RPData:SetParent(RedPointType.AircraftCarrier, RedPointType.Logistics)
    -- RPData:SetParent(RedPointType.AircraftCarrier_CV, RedPointType.AircraftCarrier)
    -- RPData:SetParent(RedPointType.AircraftCarrier_CV_LvUp, RedPointType.AircraftCarrier_CV)
    -- RPData:SetParent(RedPointType.AircraftCarrier_CV_Plane1, RedPointType.AircraftCarrier_CV)
    -- RPData:SetParent(RedPointType.AircraftCarrier_CV_Plane2, RedPointType.AircraftCarrier_CV)
    -- RPData:SetParent(RedPointType.AircraftCarrier_CV_Plane3, RedPointType.AircraftCarrier_CV)
    -- RPData:SetParent(RedPointType.AircraftCarrier_CV_Plane4, RedPointType.AircraftCarrier_CV)
    -- RPData:SetParent(RedPointType.AircraftCarrier_CV_Plane4, RedPointType.AircraftCarrier_CV)
    -- RPData:SetParent(RedPointType.AircraftCarrier_Plane, RedPointType.AircraftCarrier)
    -- RPData:SetParent(RedPointType.AircraftCarrier_Plane_Normal, RedPointType.AircraftCarrier_Plane)
    -- RPData:SetParent(RedPointType.AircraftCarrier_Plane_Privilege, RedPointType.AircraftCarrier_Plane)
    -- RPData:SetParent(RedPointType.AircraftCarrier_Plane_Factory, RedPointType.AircraftCarrier_Plane)
    -- RPData:SetParent(RedPointType.AircraftCarrier_Plane_Speed, RedPointType.AircraftCarrier_Plane)

    -- 时空战场
    RPData:SetParent(RedPointType.BattleOfFog, RedPointType.SpaceTimeBattlefield)
    RPData:SetParent(RedPointType.Culturalrelics, RedPointType.BattleOfFog)
    RPData:SetParent(RedPointType.NightmareInvasion, RedPointType.SpaceTimeBattlefield)
    RPData:SetParent(RedPointType.BattleOfHeresy, RedPointType.SpaceTimeBattlefield)
    RPData:SetParent(RedPointType.WarOfCorruption, RedPointType.SpaceTimeBattlefield)

    -- 神之塔
    RPData:SetParent(RedPointType.ClimbTowerReward, RedPointType.ClimbTower)
    RPData:SetParent(RedPointType.ClimbTowerFreeTime, RedPointType.ClimbTower)
    RPData:SetParent(RedPointType.ClimbSeniorTowerReward, RedPointType.ClimbTower)

    -- 研究所
    RPData:SetParent(RedPointType.ResearchInstitute_RingCompound,RedPointType.ResearchInstitute)
    RPData:SetParent(RedPointType.ResearchInstitute_EquipCompound,RedPointType.ResearchInstitute)

    -- 极限突破
    RPData:SetParent(RedPointType.NiuQiChongTian_1,RedPointType.NiuQiChongTian)
    RPData:SetParent(RedPointType.NiuQiChongTian_2,RedPointType.NiuQiChongTian)
    RPData:SetParent(RedPointType.NiuQiChongTian_3,RedPointType.NiuQiChongTian)
    RPData:SetParent(RedPointType.NiuQiChongTian_4,RedPointType.NiuQiChongTian)

    --排行榜
    RPData:SetParent( RedPointType.RankReward,RedPointType.RankingSort)

    --先驱主题活动
    RPData:SetParent(RedPointType.AdjutantActivity_Challenge, RedPointType.AdjutantActivity)

    --卡牌主题活动
    RPData:SetParent(RedPointType.CardActivity_Collect, RedPointType.CardActivity)
    RPData:SetParent(RedPointType.CardActivity_Draw, RedPointType.CardActivity)
    RPData:SetParent(RedPointType.CardActivity_Haoli, RedPointType.CardActivity)
    RPData:SetParent(RedPointType.CardActivity_Task, RedPointType.CardActivity)

    --锦标赛
    RPData:SetParent(RedPointType.Championships_Rank, RedPointType.Championships)

    --主角
    RPData:SetParent(RedPointType.Lead_Assembly, RedPointType.Lead)
    RPData:SetParent(RedPointType.Lead_Normal, RedPointType.Lead)
    RPData:SetParent(RedPointType.Lead_Privilege, RedPointType.Lead)
    RPData:SetParent(RedPointType.Lead_SpeedLvUp, RedPointType.Lead)
    RPData:SetParent(RedPointType.Lead_UpLv, RedPointType.Lead)

    --公会战
    RPData:SetParent(RedPointType.GuildBattle_BoxReward, RedPointType.GuildBattle)
    RPData:SetParent(RedPointType.GuildBattle_FreeTime, RedPointType.GuildBattle)

    --扭蛋
    RPData:SetParent(RedPointType.BoxPoolFreeTime, RedPointType.BoxPool)
    RPData:SetParent(RedPointType.BoxPoolCanDraw, RedPointType.BoxPool)

    --混乱之治
    RPData:SetParent(RedPointType.Chaos_Task, RedPointType.Chaos_MainIcon)
    RPData:SetParent(RedPointType.Chaos_Tab_Chanllege, RedPointType.Chaos_MainIcon)
end

-- 注册红点检测方法
function this.RegisterRedCheckFunc()
    -- 服务器红点注册解锁类型
    RPData:AddCheckFunc(RedPointType.Mail_Server, nil, FUNCTION_OPEN_TYPE.EMAIL)
    RPData:AddCheckFunc(RedPointType.SecretTer_Boss, nil, FUNCTION_OPEN_TYPE.FIGHT_ALIEN)
    RPData:AddCheckFunc(RedPointType.Arena_Record, nil, FUNCTION_OPEN_TYPE.ARENA)
    RPData:AddCheckFunc(RedPointType.Guild_Apply, nil, FUNCTION_OPEN_TYPE.GUILD)

    -- 普通红点检测方法注册
    RPData:AddCheckFunc(RedPointType.CourtesyDress_SevenDay,ActivityGiftManager.CheckSevenDayRed)
    RPData:AddCheckFunc(RedPointType.CourtesyDress_Chapter, ActivityGiftManager.CheckChapterRed)
    RPData:AddCheckFunc(RedPointType.CourtesyDress_Online, ActivityGiftManager.CheckOnlineRed)
    RPData:AddCheckFunc(RedPointType.SecretTer_FindTreasure, FindTreasureManager.RefreshFindTreasureRedPoint)
    
    RPData:AddCheckFunc(RedPointType.DailyTask, RedPointManager.GetRedPointMissionDaily)
    RPData:AddCheckFunc(RedPointType.LuckyCat_GetReward,LuckyCatManager.CheckIsShowRedPoint)

    RPData:AddCheckFunc(RedPointType.DiffMonster, DiffMonsterManager.GetDiffMonsterRedPointStatus, FUNCTION_OPEN_TYPE.DIFFER_DEMONS)

    RPData:AddCheckFunc(RedPointType.TreasureOfSl, TreasureOfSomebodyManagerV2.GetTreasureRedPointState)

    RPData:AddCheckFunc(RedPointType.Mail_Local, MailManager.GetMailRedPointState)
    
    ---=== 商店相关红点
    RPData:AddCheckFunc(RedPointType.Arena_Shop, ShopManager.ShopRedCheck)
    RPData:AddCheckFunc(RedPointType.Shop_General_Check, ShopManager.ShopRedCheck)
    RPData:AddCheckFunc(RedPointType.Shop_Secret_Check, ShopManager.ShopRedCheck)
    RPData:AddCheckFunc(RedPointType.Shop_Arena_Check, ShopManager.ShopRedCheck)
    RPData:AddCheckFunc(RedPointType.Shop_Roam_Check, ShopManager.ShopRedCheck)
    RPData:AddCheckFunc(RedPointType.Shop_Guild_Check, ShopManager.ShopRedCheck)
    RPData:AddCheckFunc(RedPointType.Guild_Shop, ShopManager.ShopRedCheck)
    RPData:AddCheckFunc(RedPointType.Guild_Transcript, GuildTranscriptManager.GetRedPointState)
    RPData:AddCheckFunc(RedPointType.VIP_SHOP_DETAIL, VipManager.CheckRedPoint)
    RPData:AddCheckFunc(RedPointType.VipPrivilege, VipManager.CheckNewVipRP)
    RPData:AddCheckFunc(RedPointType.FirstRecharge, FirstRechargeManager.GetFirstRechargeRedPointStatus)
    RPData:AddCheckFunc(RedPointType.DailyGift, ShopManager.HaveFreeBaby)
    RPData:AddCheckFunc(RedPointType.GrowthPackage, VipManager.CheckGrowthPackagePointStatus)--成长礼包
    RPData:AddCheckFunc(RedPointType.VipPanel, VipManager.RefreshEveryDayGiftRedpoint)

    --工坊
    RPData:AddCheckFunc(RedPointType.Refining_Weapon, WorkShopManager.GetWorkShopRedPointState)
    RPData:AddCheckFunc(RedPointType.Refining_Armor, WorkShopManager.GetWorkShopRedPointState)
    --好友
    RPData:AddCheckFunc(RedPointType.Friend_Reward, GoodFriendManager.FriendRewardRedPointShow,FUNCTION_OPEN_TYPE.GOODFRIEND)
    RPData:AddCheckFunc(RedPointType.Friend_Application, GoodFriendManager.FriendApplicationRedPointShow,FUNCTION_OPEN_TYPE.GOODFRIEND)
    --秘境
    RPData:AddCheckFunc(RedPointType.SecretTer_MaxBoxReward, AdventureManager.BoxMaxReward,FUNCTION_OPEN_TYPE.ADVENTURE)
    RPData:AddCheckFunc(RedPointType.SecretTer_HaveFreeTime, AdventureManager.HaveFreeTime,FUNCTION_OPEN_TYPE.ADVENTURE)
    RPData:AddCheckFunc(RedPointType.SecretTer_IsCanFight, FightPointPassManager.IsShowFightRP)
    -- 外敌
    RPData:AddCheckFunc(RedPointType.SecretTer_CallAlianInvasionTime, AdventureManager.HaveCallAlianInvasionTime,FUNCTION_OPEN_TYPE.FIGHT_ALIEN)
    --秘盒红点
    RPData:AddCheckFunc(RedPointType.SecretBox_Red1, SecretBoxManager.CheckSecretRedPoint,FUNCTION_OPEN_TYPE.SECRETBOX)
    --角色招募红点
    RPData:AddCheckFunc(RedPointType.Recruit_Red, RecruitManager.CheckRecuritRedPoint,FUNCTION_OPEN_TYPE.RECURITY)
    --普通召唤红点
    RPData:AddCheckFunc(RedPointType.Recruit_Normal, RecruitManager.CheckRecuritNormalPoint,FUNCTION_OPEN_TYPE.RECURITY)
     --角色十连招募红点
     RPData:AddCheckFunc(RedPointType.RecruitTen_Red, RecruitManager.CheckRecuritTenRedPoint,FUNCTION_OPEN_TYPE.RECURITY)
     --普通十连召唤红点
     RPData:AddCheckFunc(RedPointType.RecruitTen_Normal, RecruitManager.CheckRecuritTenNormalPoint,FUNCTION_OPEN_TYPE.RECURITY)
    --七日狂欢红点
    RPData:AddCheckFunc(RedPointType.SevenDayCarnival, SevenDayCarnivalManager.GetSevenDayCarnivalRedPoint)
    --每日首充
    RPData:AddCheckFunc(RedPointType.DailyRecharge, DailyRechargeManager.RefreshRedpoint)
    ---------------福利
    RPData:AddCheckFunc(RedPointType.GrowthGift, OperatingManager.GetGrowthRedPointState)
    RPData:AddCheckFunc(RedPointType.CumulativeSignIn,OperatingManager.GetSignInRedPointStatus)--累计签到
    RPData:AddCheckFunc(RedPointType.NobilityMonthCard,OperatingManager.RefreshMONTHCARDMonthCardRedPoint)--月卡(贵族)
    RPData:AddCheckFunc(RedPointType.KingMonthCard,OperatingManager.RefreshLUXURYMONTHCARDMonthCardRedPoint)--月卡(王者)
    RPData:AddCheckFunc(RedPointType.EveryWeekPreference,OperatingManager.EveryWeekPreferenceRedPoint)--每周特惠
    RPData:AddCheckFunc(RedPointType.EveryMonthPreference,OperatingManager.EveryMonthPreferenceRedPoint)--每月特惠
    RPData:AddCheckFunc(RedPointType.WeekendWelfare, ActivityGiftManager.WeekendWelfareRedPoint)--周末福利
    RPData:AddCheckFunc(RedPointType.WeekCard, ActivityGiftManager.WeekCardRedPoint)--周卡

    -- 八日登录
    RPData:AddCheckFunc(RedPointType.EightTheLogin,ActivityGiftManager.CheckEightRedPoint)
    RPData:AddCheckFunc(RedPointType.EightTheLogin_2,ActivityGiftManager.CheckEightRedPoint_2)
    --神秘军火商
    RPData:AddCheckFunc(RedPointType.MunitionsMerchant,ActivityGiftManager.GetRedState)
    --连续充值
    RPData:AddCheckFunc(RedPointType.ContinuityRecharge,ActivityGiftManager.GetContinuityRechargeRedPoint)
    -- 头像红点
    RPData:AddCheckFunc(RedPointType.HeadChange_Frame, HeadManager.CheckHeadRedPot)
    RPData:AddCheckFunc(RedPointType.HeadChange_Head, HeadManager.CheckHeadRedPot)
    --限时活动
    RPData:AddCheckFunc(RedPointType.Expert_AdventureExper, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_AreaExper, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_UpStarExper, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_EquipExper,ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_GoldExper, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_FightExper, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_EnergyExper, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_AccumulativeRecharge, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_FindTreasure, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_LuckyTurn, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_Recruit, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_SecretBox, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_UpLv, ActivityGiftManager.ExperyUpLvActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_Talisman, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_SoulPrint, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.Expert_Heresy, ActivityGiftManager.ExpterActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.LuckyTurn, LuckyTurnTableManager.ReturnRedPointState)
    RPData:AddCheckFunc(RedPointType.Expert_WeekCard, ActivityGiftManager.WeedCardActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.HERO_STAR_GIFT, OperatingManager.IsHeroStarGiftActive)
    --战力排行
    RPData:AddCheckFunc(RedPointType.WarPowerSort_Sort, ActivityGiftManager.WarPowerSortActivityIsShowRedPoint)
    RPData:AddCheckFunc(RedPointType.RankingSort, RankingManager.RefreshRedPoint)
    RPData:AddCheckFunc(RedPointType.RankReward, RankingManager.RefreshRankingRewardRedPoint)
    --背包
    RPData:AddCheckFunc(RedPointType.Bag_HeroDebris, BagManager.GetBagRedPointIsCanCompoundDebris)
    RPData:AddCheckFunc(RedPointType.Bag_BoxAndBlueprint, BagManager.GetBagRedPointIsCanOpenBoxAndBlueprint)
    
    --英雄tab
    RPData:AddCheckFunc(RedPointType.HeroTab, HeroManager.GetAllHeroRedPoint)
    -- RPData:AddCheckFunc(RedPointType.Role, HeroManager.GetFormationHeroRedPoint)

    -- upView
    RPData:AddCheckFunc(RedPointType.UpView_Gold, ShopManager.CheckGoldIsFree)

    -- chatview
    RPData:AddCheckFunc(RedPointType.Chat_Friend, FriendChatManager.CheckRedPotShow)

    -- 剑影仙踪
    RPData:AddCheckFunc(RedPointType.SupremeHero, ActivityGiftManager.CheckSupremeHeroRedPoint)
    -- 东海寻仙
    RPData:AddCheckFunc(RedPointType.FindFairy_OneView, FindFairyManager.CheckRedPoint)
    RPData:AddCheckFunc(RedPointType.FindFairy_ThreeView, FindFairyManager.CheckFindFairyUpStarRedPoint)
    RPData:AddCheckFunc(RedPointType.FindFairy_FourView, FindFairyManager.CheckFindFairyCeremonyRedPoint)
    -- 公会boss
    RPData:AddCheckFunc(RedPointType.Guild_Boss, GuildBossManager.CheckGuildBossRedPoint, FUNCTION_OPEN_TYPE.GUILD_BOSS)

    --公会援助
    RPData:AddCheckFunc(RedPointType.Guild_AidMy, MyGuildManager.GetMyGuildHelpRedPoint)
    RPData:AddCheckFunc(RedPointType.Guild_AidGuild, MyGuildManager.GetMyAidOtherGuildHelpRedPoint)
    RPData:AddCheckFunc(RedPointType.Guild_AidBox, MyGuildManager.GetGuildHelpBoxRedPoint)
    --公会技能
    RPData:AddCheckFunc(RedPointType.Guild_Skill, GuildSkillManager.RefreshAllGuildSkillRedPoint)
    -- 公会红包
    RPData:AddCheckFunc(RedPointType.Guild_RedPacket,GuildRedPacketManager.CheckGuildRedPacketRedPoint)
    --公会祭祀
    RPData:AddCheckFunc(RedPointType.Guild_Fete,MyGuildManager.CheckGuildFeteRedPoint)
    --公会战
    -- RPData:AddCheckFunc(RedPointType.Guild_DeathPos,DeathPosManager.CheckDeathPosRedPoint)
    -- 成就
    RPData:AddCheckFunc(RedPointType.Achievement_Main,TaskManager.GetAchievementState)
    --天宫秘宝
    RPData:AddCheckFunc(RedPointType.Expedition_Treasure,TreasureOfHeavenManger.RedPoint)
    --限时招募
    RPData:AddCheckFunc(RedPointType.TimeLimited,OperatingManager.GetTimeLimitRedPointStatus)
    RPData:AddCheckFunc(RedPointType.QianKunBox,OperatingManager.GetQiankunBoxRedPointStatus)
    --累计充值
    RPData:AddCheckFunc(RedPointType.DynamicActRecharge,OperatingManager.CheckLeiJiChongZhiRedData)
    --支援
    -- RPData:AddCheckFunc(RedPointType.Support_Gift,SupportManager.CheckIsFinish)
    -- RPData:AddCheckFunc(RedPointType.Support_LevelUpBtn,SupportManager.CheckLevelUpIsEnough)
    -- RPData:AddCheckFunc(RedPointType.Support_SkillBtn,SupportManager.CheckSkillIsEnough)
    -- RPData:AddCheckFunc(RedPointType.Support_RemouldBtn,SupportManager.CheckRemouldIsEnough)

    --税收免费领取
    RPData:AddCheckFunc(RedPointType.Revenue_Free,ShopManager.GetFreeTimes)

    --先驱
    RPData:AddCheckFunc(RedPointType.Adjutant_FreeButton,AdjutantManager.IsVigorTotal)
    RPData:AddCheckFunc(RedPointType.Adjutant_Btn_Chat,AdjutantManager.IsChatEnough)
    RPData:AddCheckFunc(RedPointType.Adjutant_Btn_Skill,AdjutantManager.IsSkillEnough)
    RPData:AddCheckFunc(RedPointType.Adjutant_Btn_Handsel,AdjutantManager.IsHandselEnough)
    RPData:AddCheckFunc(RedPointType.Adjutant_Btn_Teach,AdjutantManager.IsTeachEnough)

    --支援
    RPData:AddCheckFunc(RedPointType.Support, SupportManager.CheckRedPoint, FUNCTION_OPEN_TYPE.SUPPORT)
    RPData:AddCheckFunc(RedPointType.Adjutant, AdjutantManager.CheckRedPoint, FUNCTION_OPEN_TYPE.ADJUTANT)

    -- RPData:AddCheckFunc(RedPointType.AircraftCarrier_CV_LvUp, AircraftCarrierManager.CheckRedPoint_CV_LvUp, FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER)
    -- RPData:AddCheckFunc(RedPointType.AircraftCarrier_CV_Plane1, AircraftCarrierManager.CheckRedPoint_CV_Plane1, FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER)
    -- RPData:AddCheckFunc(RedPointType.AircraftCarrier_CV_Plane2, AircraftCarrierManager.CheckRedPoint_CV_Plane2, FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER)
    -- RPData:AddCheckFunc(RedPointType.AircraftCarrier_CV_Plane3, AircraftCarrierManager.CheckRedPoint_CV_Plane3, FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER)
    -- RPData:AddCheckFunc(RedPointType.AircraftCarrier_CV_Plane4, AircraftCarrierManager.CheckRedPoint_CV_Plane4, FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER)
    -- RPData:AddCheckFunc(RedPointType.AircraftCarrier_Plane_Normal, AircraftCarrierManager.CheckRedPoint_Plane_Proto_Normal, FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER)
    -- RPData:AddCheckFunc(RedPointType.AircraftCarrier_Plane_Privilege, AircraftCarrierManager.CheckRedPoint_Plane_Proto_Privilege, FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER)
    -- RPData:AddCheckFunc(RedPointType.AircraftCarrier_Plane_Factory, AircraftCarrierManager.CheckRedPoint_Plane_Factory, FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER)
    -- RPData:AddCheckFunc(RedPointType.AircraftCarrier_Plane_Speed, AircraftCarrierManager.CheckRedPoint_Plane_Speed, FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER)-- 加速正常应该在设计选项中 会造成同一节点绑定多个逻辑 目前不支持 或其他方式做 暂时归为大类节点下

    RPData:AddCheckFunc(RedPointType.ForgottenCity, CarbonManager.CarbonRedCheck,FUNCTION_OPEN_TYPE.BLITZ_STRIKE)
    RPData:AddCheckFunc(RedPointType.HeroExplore, CarbonManager.CarbonRedCheck,FUNCTION_OPEN_TYPE.DAILYCHALLENGE_COIN)
    RPData:AddCheckFunc(RedPointType.EpicExplore, CarbonManager.CarbonRedCheck,FUNCTION_OPEN_TYPE.MONSTER_COMING)
    RPData:AddCheckFunc(RedPointType.LegendExplore, CarbonManager.CarbonRedCheck,FUNCTION_OPEN_TYPE.MINSKBATTLE)

    RPData:AddCheckFunc(RedPointType.QinglongSerectTreasure, GrowthManualManager.GetQinglongSerectTreasureRedPot)
    RPData:AddCheckFunc(RedPointType.QinglongSerectTreasureTrail, GrowthManualManager.GetSerectTreasureTrailRedPot)

    --极限突破
    RPData:AddCheckFunc(RedPointType.NiuQiChongTian_1,NiuQiChongTianManager.CheckNiuQiChongTianRedPoint)
    RPData:AddCheckFunc(RedPointType.NiuQiChongTian_2,NiuQiChongTianManager.CheckNiuQiChongTianRedPoint)
    RPData:AddCheckFunc(RedPointType.NiuQiChongTian_3,NiuQiChongTianManager.CheckNiuQiChongTianRedPoint)
    RPData:AddCheckFunc(RedPointType.NiuQiChongTian_4,NiuQiChongTianManager.CheckNiuQiChongTianRedPoint)

    RPData:AddCheckFunc(RedPointType.BattlePassMission, TaskManager.BattlePasssTask)

    --超值基金红点检测
    RPData:AddCheckFunc(RedPointType.SpecialFunds,OperatingManager.CheckSpecialFundsRedPoint)

    --引导任务红点检测
    RPData:AddCheckFunc(RedPointType.MainCity,TaskManager.CheckGuideTaskRedPoint)

    --神之塔奖励红点检测
    RPData:AddCheckFunc(RedPointType.ClimbTowerReward,ClimbTowerManager.RefreshTaskRewardRedpoint)
    RPData:AddCheckFunc(RedPointType.ClimbSeniorTowerReward,ClimbTowerManager.RefreshTaskAdvanceRewardRedpoint)

    --神之塔免费扫荡红点检测
    RPData:AddCheckFunc(RedPointType.ClimbTowerFreeTime,ClimbTowerManager.RefreshFreeRedpoint)

    --研究所
    RPData:AddCheckFunc(RedPointType.ResearchInstitute_EquipCompound,EquipManager.RefreshAllEquipCompoundRedpoint)
    RPData:AddCheckFunc(RedPointType.ResearchInstitute_RingCompound,CombatPlanManager.RefreshRingcompoundRedpoint)

    --快速训练
    RPData:AddCheckFunc(RedPointType.QuickTrain,FightPointPassManager.RefreshQuickTrain)

    --拍脸
    RPData:AddCheckFunc(RedPointType.PatFace,OperatingManager.RefreshPatFaceRedpoint)
    RPData:AddCheckFunc(RedPointType.Challenge,OperatingManager.RefreshChallengeRedpoint)
    --主题活动
    RPData:AddCheckFunc(RedPointType.DynamicActTask,OperatingManager.CheckDynamicActTaskRed)

    --契约
    RPData:AddCheckFunc(RedPointType.General,GeneralManager.RefreshRedPointState)

    --超值礼包
    RPData:AddCheckFunc(RedPointType.ValuePack, ShopManager.RefreshValuePackRedPoint)

    --竞技场点赞
    RPData:AddCheckFunc(RedPointType.ArenaTodayAlreadyLike, ArenaManager.RefreshAlreadyLikeRedpoint)

    --千抽红点
    RPData:AddCheckFunc(RedPointType.ThousandDraw, RecruitManager.RefreshThousandDrawRedPoint)

    --时空战场
    RPData:AddCheckFunc(RedPointType.NightmareInvasion, GuildCarDelayManager.RefreshAllRedPoint)--梦魇入侵
    RPData:AddCheckFunc(RedPointType.BattleOfHeresy, MapManager.RefreshRedPoint)--异端之战
    RPData:AddCheckFunc(RedPointType.Culturalrelics, PrivilegeManager.RefreshRelicsRedPoint)--文明遗迹红点检测
    RPData:AddCheckFunc(RedPointType.WarOfCorruption, XuanYuanMirrorManager.CarbonRedCheck)--腐化之战

    --阵容推荐红点
    RPData:AddCheckFunc(RedPointType.LineupRecommend, PlayerManager.LineupRecommendRedpoint)

    --开服双倍
    RPData:AddCheckFunc(RedPointType.OpenService, OperatingManager.RefreshOpenServiceRedpoint)

    --黑市
    RPData:AddCheckFunc(RedPointType.BlackShop, ShopManager.RefreshBlackShopRedPoint)

    --扭蛋
    RPData:AddCheckFunc(RedPointType.BoxPoolFreeTime, ActivityGiftManager.BoxPoolFreeTime)
    RPData:AddCheckFunc(RedPointType.BoxPoolCanDraw, ActivityGiftManager.BoxPoolCanDraw)

    --激励计划
    RPData:AddCheckFunc(RedPointType.LifeMemeberFree, ActivityGiftManager.LifeMemberFreeRedPoint)--终身特权
    RPData:AddCheckFunc(RedPointType.LifeMemeberEveryDay, ActivityGiftManager.LifeMemberRedPoint)
    RPData:AddCheckFunc(RedPointType.SuperLiftMemberFree, ActivityGiftManager.SuperLifeMemberFreeRedPoint)--超级终身特权
    RPData:AddCheckFunc(RedPointType.SuperLiftMemberEveryDay, ActivityGiftManager.SuperLifeMemberRedPoint)

    --先驱主题活动挑战任务
    RPData:AddCheckFunc(RedPointType.AdjutantActivity_Challenge, AdjutantActivityManager.RefreshRedPoint)

    --卡牌主题活动
    RPData:AddCheckFunc(RedPointType.CardActivity_Collect, CardActivityManager.CollectRedPoint)
    RPData:AddCheckFunc(RedPointType.CardActivity_Draw, CardActivityManager.RecruitRedPoint)
    RPData:AddCheckFunc(RedPointType.CardActivity_Haoli, CardActivityManager.HaoliRedPoint)
    RPData:AddCheckFunc(RedPointType.CardActivity_Task, CardActivityManager.TaskRedPoint)

    RPData:AddCheckFunc(RedPointType.Championships_Rank, ArenaTopMatchManager.RefreshRankRedpoint)
    -- RPData:AddCheckFunc(RedPointType.PVEStarReward, PVEActivityManager.SetPveStarRewardRedpoint)

    --主角
    RPData:AddCheckFunc(RedPointType.Lead_Assembly, AircraftCarrierManager.CheckRedPointForSkill)
    RPData:AddCheckFunc(RedPointType.Lead_Normal, AircraftCarrierManager.CheckRedPointForNormal)
    RPData:AddCheckFunc(RedPointType.Lead_Privilege, AircraftCarrierManager.CheckRedPointForPrivilege)
    RPData:AddCheckFunc(RedPointType.Lead_UpLv, AircraftCarrierManager.CheckRedPoint_CV_LvUp)
    RPData:AddCheckFunc(RedPointType.Lead_SpeedLvUp, AircraftCarrierManager.CheckRedPointForSpeed)

    --公会战
    RPData:AddCheckFunc(RedPointType.GuildBattle_FreeTime, GuildBattleManager.GuildBattleTimeRedPoint)
    RPData:AddCheckFunc(RedPointType.GuildBattle_BoxReward, GuildBattleManager.GuildBattleRewardRedPoint)
    --混乱之治
    RPData:AddCheckFunc(RedPointType.Chaos_Tab_Chanllege, ChaosManager.ChanllegeRedPoint)
    RPData:AddCheckFunc(RedPointType.Chaos_Task, ChaosManager.TaskRedPoint)
    --战令
    RPData:AddCheckFunc(RedPointType.WarOrder_Tower, OperatingManager.WarOrderRedPointForTower)
    RPData:AddCheckFunc(RedPointType.WarOrder_MagicTower, OperatingManager.WarOrderRedPointForMagicTower)
    RPData:AddCheckFunc(RedPointType.WarOrder_Heresy, OperatingManager.WarOrderRedPointForHeresy)
    RPData:AddCheckFunc(RedPointType.WarOrder_DenseFog, OperatingManager.WarOrderRedPointForDenseFog)
    RPData:AddCheckFunc(RedPointType.WarOrder_Abyss, OperatingManager.WarOrderRedPointForAbyss)

    --开服热卖
    RPData:AddCheckFunc(RedPointType.OpenServiceShop, ActivityGiftManager.OpenSeverShopRedpoint)
end

-- 向红点绑定物体
function this.BindObject(rpType, rpObj)
    if not rpType then
        LogError("rpType == nil!!!")
        return
    end

    BindObjs[rpType] = BindObjs[rpType] or {}
    table.insert(BindObjs[rpType], rpObj)
    -- 根据状态设置红点现隐

    if rpObj ~= nil then
        rpObj:SetActive(this.GetRedPointStatus(rpType) == RedPointStatus.Show)
    end
end

-- 解绑物体
function this.ClearObject(rpType, rpObj)
    if rpObj then
        local indexToKill = nil
        for index, obj in pairs(BindObjs[rpType]) do
            if rpObj == obj then
                indexToKill = index
                break
            end
        end
        if indexToKill then
            table.remove(BindObjs[rpType], indexToKill)
        else
        end
    else
        if BindObjs then
            BindObjs[rpType] = {}
        end
    end
end

-- 设置服务器红点数据
function this.SetServerRedPointData(list)
    local serverList = {}
    for _, rpType in ipairs(ServerRedType) do
        serverList[rpType] = 0
    end
    -- list中保存要显示的红点
    if list then
        for _, rpType in ipairs(list) do

            serverList[rpType] = 1
        end
    end
    RPData:SetServerRedData(serverList)
end

-- 获取红点状态
function this.GetRedPointStatus(rpType)
    local value = RPData:GetRedValue(rpType)
    if not value then
        return RedPointStatus.Hide
    end
    if value == 0 then
        return RedPointStatus.Hide
    end
    return RedPointStatus.Show
end

-- 设置红点状态
function this.SetRedPointStatus(rpType, status)
    local value = status == RedPointStatus.Show and 1 or 0
    local result = RPData:SetRedValue(rpType, value)
    -- 判断是否设置成功
    if result then
        this.RefreshRedObjectStatus(rpType)
    end
end

-- 设置服务器红点状态
function this.SetServerRedPointStatus(rpType, status)
    local value = status == RedPointStatus.Show and 1 or 0
    local result = RPData:SetServerRed(rpType, value)
    -- 判断是否设置成功
    if result then
        this.CheckRedPointStatus(rpType)
    end
end

-- 检测红点状态
function this.CheckRedPointStatus(rpType)
    -- -- 判断是否需要刷新红点显示
    if RPData:CheckRedPoint(rpType) then
        this.RefreshRedObjectStatus(rpType)
    end

    return false
end

-- 检测所有红点状态
function this.CheckAllRedPointStatus()
    -- 服务器红点
    local serverList = RPData:GetServerRedData()
    for rpType, _ in pairs(serverList) do
        this.CheckRedPointStatus(rpType)
    end
    -- 本地红点
    local checkList = RPData:GetCheckList()
    for rpType, _ in pairs(checkList) do
        this.CheckRedPointStatus(rpType)
    end
end

-- 刷新对应物体的显示
function this.RefreshRedObjectStatus(rpType)
    -- 检测红点状态
    local state = this.GetRedPointStatus(rpType)
    if BindObjs[rpType] then
        table.walk(BindObjs[rpType], function(bindObj)
            if bindObj and IsNull(bindObj) then
            end
            if bindObj and not IsNull(bindObj) and bindObj.gameObject then
                bindObj.gameObject:SetActive(state == RedPointStatus.Show)
            else
            end
        end)
    end

    -- 向父级递归
    local parent = RPData:GetRedParent(rpType)
    if parent then
        this.RefreshRedObjectStatus(parent)
    end
end

function this.ClearNullReference()
    for _, objs in pairs(BindObjs) do
        local indexToKill = {}
        for k, obj in pairs(objs) do
            if IsNull(obj) then
                table.insert(indexToKill, k)
            end
        end
        for _, index in ipairs(indexToKill) do
            objs[index] = nil
        end
    end
end

return this