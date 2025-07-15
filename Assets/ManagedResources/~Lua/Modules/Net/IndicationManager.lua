IndicationManager = {}
local this = IndicationManager
--所有后端推送还未处理的协议，先临时做个数组遍历都监听上，以后单独处理一个，就删除一个
local testMessageType = {
    MessageTypeProto_pb.ADVENTURE_BOSS_REFRESH_INDICATION,
    MessageTypeProto_pb.ADJUTANT_FIGHTMISSION_REFRESH_INDICATION,
    MessageTypeProto_pb.BUY_GOODS_DROP_INDICATION,
    MessageTypeProto_pb.ERROR_CODE_INDICATION,
    MessageTypeProto_pb.ENDLESS_NEW_HERO_GET_INDICATION,
    MessageTypeProto_pb.HONGMENG_INFO_INDICATION,
    MessageTypeProto_pb.HONGMENG_STELE_NEW_HAND_INDICATION,
    MessageTypeProto_pb.JADE_DYNASTY_REFRESH_INDICATION,
    MessageTypeProto_pb.ROOM_MATCH_SUCCESS_INDICATION,
    MessageTypeProto_pb.ROOM_GAME_END_INDICATION,
    MessageTypeProto_pb.ROOM_SYNC_OTHER_MOVE_INDICTION,
    MessageTypeProto_pb.ROOM_TRIGGER_FIGHT_INDICATION,
    MessageTypeProto_pb.ROOM_MAP_POINT_INDICATION,
    MessageTypeProto_pb.ROOM_PLAY_HP_UPDATE_INDICATION,
    MessageTypeProto_pb.SUCCESS_RESPONSE,
    MessageTypeProto_pb.SCENE_GAME_OVER_READY_INDICATION,
    MessageTypeProto_pb.SHENGDAN_REFRESH_INDICATION,
    MessageTypeProto_pb.ZHANQIANZHUNBEI_REFRESH_INDICATION,
    MessageTypeProto_pb.BlitzBattleFightUpdate_INDICATION,
    MessageTypeProto_pb.WorldLevelIndication,--暂时吧，不确定
    MessageTypeProto_pb.ChatSendStatus,--暂时吧，不确定
    MessageTypeProto_pb.GetWorldChatMessageInfoResponse,--暂时吧，不确定
    MessageTypeProto_pb.DelGameInfoRequest,--暂时吧，不确定
    MessageTypeProto_pb.GetWorldChatMessageInfoRequest,--暂时吧，不确定
    MessageTypeProto_pb.GetRankRequest,--暂时吧，不确定
    MessageTypeProto_pb.AddDeathPathRankRequest,--暂时吧，不确定
    MessageTypeProto_pb.GetDeathPathFirstRequest,--暂时吧，不确定
    MessageTypeProto_pb.GetDeathPathRewardRequest,--暂时吧，不确定
    MessageTypeProto_pb.DeathPathWorldRewardRequest,--暂时吧，不确定
    MessageTypeProto_pb.ArenaClearInfoRequest,--暂时吧，不确定
    MessageTypeProto_pb.GetWorldArenaInfoIndication,--暂时吧，不确定
    MessageTypeProto_pb.UPDATE_BAG_MEDAL_INDICATION,
}



function this.Initialize()
    Game.GlobalEvent:AddEvent(Protocal.Connect, this.RegisterMessage)
    this.canPopUpBagMaxMessage = false
    this.getRewardFromMailMessage = false
end

function this.RegisterMessage(network)
    if network.type ~= SocketType.LOGIN then
        return
    end
    local socket = network.socket
    -- 监听服务器跨天状态N
    socket:RegistNetMessage(MessageTypeProto_pb.FIVE_PLAYER_REFLUSH_INDICATION, this.RefreshUpdateIndication)
    --监听红点推送
    socket:RegistNetMessage(MessageTypeProto_pb.SEND_RED_POINT_INDICATION, this.ReceiveRedPoint)

    socket:RegistNetMessage(MessageTypeProto_pb.UPDATE_BAG_INDICATION, this.BackUpDataBagItemIdNumber)

    socket:RegistNetMessage(MessageTypeProto_pb.SEND_CHAT_INFO_INDICATION, this.ReceiveFriendChat)

    socket:RegistNetMessage(MessageTypeProto_pb.MISSION_UPDATE_INDICATION, this.RefreshMissionList)
    -- 监听服务器推送
    socket:RegistNetMessage(MessageTypeProto_pb.ADVENTURE_BOSS_FIND_INDICATION, this.ReceiveChatMsg)
    -- 监听Boss被杀
    socket:RegistNetMessage(MessageTypeProto_pb.ADVENTURE_BOSS_KILL_INDICATION, this.GetBossInfo)

    socket:RegistNetMessage(MessageTypeProto_pb.ALL_GIFTGOODS_INDICATION, this.RefreshGiftGoods)
    -- 监听服务器好友删除，好友赠送体力推送 --type 1:申请好友 2: 添加好友
    socket:RegistNetMessage(MessageTypeProto_pb.SEND_FRIEND_INFO_INDICATION, this.ReceiveFriendApplication)
    -- 监听服务器好友申请，好友添加推送 --type 1:删除好友 2: 赠送体力
    socket:RegistNetMessage(MessageTypeProto_pb.SEND_FRIEND_STATE_INDICATION, this.ReceiveFriendDeleteState)
    -- 监听商店数据推送
    socket:RegistNetMessage(MessageTypeProto_pb.STORE_UPDATE_INDICATION, this.ReceiveShopData)

    --刷新活动
    socket:RegistNetMessage(MessageTypeProto_pb.ACTIVITY_UPDATE_INDICATION, this.RefreshActivityList)
    socket:RegistNetMessage(MessageTypeProto_pb.ACTIVITY_UPDATE_PROGRESS_INDICATION, this.ActivityUpdateProgressIndication)

    -- 公会推送
    socket:RegistNetMessage(MessageTypeProto_pb.FAMILY_JOIN_INDICATION, this.GuildJoinSuccess)
    socket:RegistNetMessage(MessageTypeProto_pb.FAMILY_KICK_INDICATION, this.GuildKickOut)
    socket:RegistNetMessage(MessageTypeProto_pb.FAMILY_POSITION_UPDATE_INDICAITON, this.GuildPositionUpdate)
    socket:RegistNetMessage(MessageTypeProto_pb.FAMILY_CHANGE_BASE_INDICATION, this.GuildDataUpdate)
    socket:RegistNetMessage(MessageTypeProto_pb.FAMILY_WALK_INDICATION, this.GuildWalkUpdate)
    socket:RegistNetMessage(MessageTypeProto_pb.FAMILY_QUICK_SET_DEFEND_INDICATION, this.GuildFightDefendUpdate)
    socket:RegistNetMessage(MessageTypeProto_pb.FAMILY_FIGHT_MATCHING_SUCCESS_INDICATION, this.GuildFightMatchingSuccess)
    socket:RegistNetMessage(MessageTypeProto_pb.FAMILY_DEFEATE_INDICATION, this.GuildFightBeKilled)
    socket:RegistNetMessage(MessageTypeProto_pb.FAMILY_REFUSE_JOIN_INDICATION, this.GuildBeRefused)
    socket:RegistNetMessage(MessageTypeProto_pb.FamilyFeteRewardProcessIndication, this.GuildFeteRewardProcess)
    -- socket:RegistNetMessage(MessageTypeProto_pb.DEATH_PATH_STATUS_CHANGE_INDICATION, this.GuildRefreshDeathPosStatus)
    socket:RegistNetMessage(MessageTypeProto_pb.DEATH_PATH_DO_REWARD_INDICATION, this.GuildDoRewardIndication)
    -- socket:RegistNetMessage(MessageTypeProto_pb.DEATH_PATH_FIRST_CHANGE_INDICATION, this.GuildFirstChangeIndication)
    --
    socket:RegistNetMessage(MessageTypeProto_pb.UPDATE_USER_EXP_INDICATION, this.UpdateUserExp)
    --秘盒跨季度刷新
    socket:RegistNetMessage(MessageTypeProto_pb.UPDATE_SECRET_BOX_SEASON_INDICATION, this.UpdateSecretSeasonData)
    -- 服务器要让我滚出图
    socket:RegistNetMessage(MessageTypeProto_pb.MAP_OUT_INDICATION, this.TimeToFuckOutMap)
    -- 刷新事件点时间
    socket:RegistNetMessage(MessageTypeProto_pb.ENDLESS_REFRESH_INDICAITON, this.FreshPointShowTime)
    -- 支付成功推送
    socket:RegistNetMessage(MessageTypeProto_pb.NOTIFY_PAY_SUCCESS_INDICATION, this.PaySuccess)
    -- 渠道强制改名推送
    socket:RegistNetMessage(MessageTypeProto_pb.PLAYER_BACKCINFO_INDICATION, this.PlayerBackCInfo)
    ---调查问卷推送
    socket:RegistNetMessage(MessageTypeProto_pb.QUESTION_INDICATION, this.RefreshQuestionnaire)
    -- 空刷小怪
    socket:RegistNetMessage(MessageTypeProto_pb.ENDLESS_MONSTER_REFRESH_INDICATION, this.MapNewAMonster)
    -- 血战奖励积分变化刷新
    socket:RegistNetMessage(MessageTypeProto_pb.BLOODY_SCORE_CHANGE_INDICATION, this.BloodyScoreChanged)
    -- 无尽副本编队数据变化
    socket:RegistNetMessage(MessageTypeProto_pb.ENDLESS_MAP_SET_TEAM_INDICATION, this.EndLessTeamChange)
    --道具直购
    socket:RegistNetMessage(MessageTypeProto_pb.DIRECT_BUY_GOODS_INDICATION, this.DirectBuyGoods)
    -- 无尽换期刷新地图信息
    socket:RegistNetMessage(MessageTypeProto_pb.ENDLESS_MAP_CHANGE_INDICATION, this.RefreshMapData)
    -- 任务重置刷新
    socket:RegistNetMessage(MessageTypeProto_pb.TREASURE_REFRESH_INDICATION, this.RestTreasureTaskData)
    -- 戒灵秘宝等级推送(成长手册等级推送)
    socket:RegistNetMessage(MessageTypeProto_pb.TREASURE_LEVELUP_INDICATION, this.RefreshTreasureLevel)
    -- 幸运转盘
    socket:RegistNetMessage(MessageTypeProto_pb.LUCKWHEEL_POOL_INDICATION, this.ReceiveLuckyTurnData)
    -- 战斗胜利更新关卡ID
    socket:RegistNetMessage(MessageTypeProto_pb.MAIN_LEVEL_FIGHT_UPDATE_INDICATION, this.FreshFightId)
    -- 累充金额推送
    socket:RegistNetMessage(MessageTypeProto_pb.REFRESH_RECHARGE_INDICATION, this.RefreshAccuMoneyNum)
    -- 巅峰战阶段切换
    socket:RegistNetMessage(MessageTypeProto_pb.CHAMPION_PROGRESS_UPDATE_INDICATION, this.TopMatchStageUpdate)
    -- 竞猜成功
    socket:RegistNetMessage(MessageTypeProto_pb.CHAMPION_GUESS_SUCCESS_INDICATION, this.TopMatchGuessSuccess)
    -- 特权解锁
    socket:RegistNetMessage(MessageTypeProto_pb.PRIVILLEGE_ADD_INDICATION, this.OnPrivilegeUpdate)
    -- 远征更新圣物信息
    socket:RegistNetMessage(MessageTypeProto_pb.EXPEDITION_HOLY_BAG_INDICATION, this.RefreshExpeditionHalidom)
    -- 远征更新节点和己方信息
    socket:RegistNetMessage(MessageTypeProto_pb.EXPEDITION_NOINFO_INDICATION, this.RefreshExpeditionNodeAndHeros)
    -- 月卡激活推送
    socket:RegistNetMessage(MessageTypeProto_pb.MONTHCARD_INDICATION, this.RefreshMonthCardData)
    -- 公会车迟阶段推送
    socket:RegistNetMessage(MessageTypeProto_pb.CAR_DELAY_PROGRESS_INDICATION, this.RefreshGuildCarDelayProgressData)
    -- 公会援助信息推送
    socket:RegistNetMessage(MessageTypeProto_pb.GuildHelpInfoIndication, this.RefreshGuildAidInfoData)
    -- 公会援助日志信息推送
    socket:RegistNetMessage(MessageTypeProto_pb.GuildHelpLogIndication, this.GuildHelpLogIndication)
    -- 猎妖之路推送
    socket:RegistNetMessage(MessageTypeProto_pb.ExpeditionResetIndication, this.ExpeditionResetIndication)
    -- 大闹天宫 天宫秘宝 积分 和 任务状态推送
    socket:RegistNetMessage(MessageTypeProto_pb.EXPEDITION_TREASURE_STATE_INDICATION, this.TreasureStateIndicaion)
    -- 爬塔关卡推送
    socket:RegistNetMessage(MessageTypeProto_pb.VIRTUAL_BATTLE_FIGHT_UPDATE_INDICATION, this.ClimbTowerFreshFightId)
    -- 爬塔关卡推送 高级
    socket:RegistNetMessage(MessageTypeProto_pb.VIRTUAL_ELITE_BATTLE_FIGHT_UPDATE_INDICATION, this.ClimbTowerFreshFightIdAdvance)
    -- 公户副本推送
    socket:RegistNetMessage(MessageTypeProto_pb.GUILD_CHALLENGE_INDICATION, this.GuildTranscriptIndication)
    -- 公户副本推送
    socket:RegistNetMessage(MessageTypeProto_pb.GUILD_CHALLENGE_BUY_BUFF_INDICATION, this.GuildChallengeBuyBuffIndication)
    -- 防守训练
    socket:RegistNetMessage(MessageTypeProto_pb.DefTrainingBattleFightUpdateIndication, this.DefenseTrainingFreshFightId)
    -- 礼包拍脸推送
    socket:RegistNetMessage(MessageTypeProto_pb.PUSH_WELFARE_RESPONSE, this.BackPatFaceData)
    -- 更新勋章信息
    --socket:RegistNetMessage(MessageTypeProto_pb.UPDATE_BAG_MEDAL_INDICATION, this.medalInfo)
    --勘探全服玩家获得奖励消息推送
    socket:RegistNetMessage(MessageTypeProto_pb.UPDATE_PROSPECT_INFO_ALL, this.UpdateProspectInfo)
    -->称号ID推送
    socket:RegistNetMessage(MessageTypeProto_pb.UPDATE_USER_DESIGNATION , this.UpdateUserDesignation)
    --阿登战役关卡开放推送
    socket:RegistNetMessage(MessageTypeProto_pb.SITUATION_INFO_INDICATION, this.SiTuaTionInfoIndication)
    --情报中心解锁监听
    socket:RegistNetMessage(MessageTypeProto_pb.INVESTIGATE_UNLOCK_RESPONSE, this.InvestigateUpLevel)
    --改变称号
    socket:RegistNetMessage(MessageTypeProto_pb.TITLE_UPDATE_PUSH, this.RefreshTitle)
    -- PVE章节数据推送
    socket:RegistNetMessage(MessageTypeProto_pb.ActivityChapterIndication, this.ActivityChapterIndication)
    --公会战状态改变
    socket:RegistNetMessage(MessageTypeProto_pb.DEATH_PATH_STATUS_CHANGE_INDICATION, this.GuildBattleStateChange)
    --公会战第一名修改推送
    socket:RegistNetMessage(MessageTypeProto_pb.DEATH_PATH_CUR_FIRST_CHANGE_INDICATION, this.DeathPathCurFirstChangeIndication)
    --战令推送某个任务已经完成
    socket:RegistNetMessage(MessageTypeProto_pb.PUSH_ENCOURAGE_PLAN_COMPETED, this.WarOrderIndication)
    --推送战令解锁
    socket:RegistNetMessage(MessageTypeProto_pb.PUSH_ENCOURAGE_PLAN_UNLOCK, this.PushEncouragePlanUnlock)
    --推送战令任务进度更新
    socket:RegistNetMessage(MessageTypeProto_pb.PUSH_ENCOURAGE_PLAN_TASK_PROGRESS_CHANGED, this.PushWarOrderPropress)
    --推送战令重置
    socket:RegistNetMessage(MessageTypeProto_pb.PUSH_ENCOURAGE_PALN_RESET, this.PushEncouragePlanReset)
    
    for i = 1,#testMessageType do
        socket:RegistNetMessage(testMessageType[i], function(buffer)
            -- LogError("服务器推送了协议")
        end)
    end
end

function this.SiTuaTionInfoIndication(buffer)
    local data = buffer:DataByte()
    local msg = MapInfoProto_pb.GetAllSituationInfoResponse()
    msg:ParseFromString(data)
    XuanYuanMirrorManager.UpdateMirrorState(msg)
    Game.GlobalEvent:DispatchEvent(GameEvent.FunctionCtrl.OnXuanYuanFunctionChange)
end

function this.RefreshActivityList(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.ActivityUpateIndication()
    msg:ParseFromString(data)
    ActivityGiftManager.RefreshActivityData(msg)
end

--服务器0点刷新推送相关任务的状态数据
function this.RefreshUpdateIndication(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.FivePlayerUpdateIndication()
    msg:ParseFromString(data)
    ActivityGiftManager.FiveAMRefreshActivityProgress(msg)
    TaskManager.RefreshTypeTaskInfo(msg.userMissionInfo)
    VipManager.FiveAMRefreshLocalData(msg.hadTakeDailyBox)
    PrivilegeManager.FiveAMRefreshLocalData(msg.privilege)
    MapTrialManager.RefreshAttachVipData()
    OperatingManager.SetSignInData(msg.SignInInfo)
    CheckRedPointStatus(RedPointType.FirstRecharge)
    PatFaceManager.SetisFirstLogVal(0)
    ShopManager.isOpenNoviceGift = false
    ActivityGiftManager.isFirstForSupremeHero=false
    BindPhoneNumberManager.InitBindInfo(msg.playerBindPhone)
    LuckyTurnTableManager.ReceiveServerDataForFive(msg.posInfos,msg.posInfosAdvance)
    OperatingManager.BackSetMonthCardGetStateData(msg.MonthDailyTake)
    MyGuildManager.SetMyFeteInfo_FiveRefresh(msg)
    MyGuildManager.SetGuildHelpInfo_FiveRefresh(msg)
    -- CarbonManager.dailyChallengeInfo=msg.dailyChallengeInfo
    Timer.New(function()
        AdventureManager.RefreshAttachVipData()
        Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnRefreshNextDayData)
    end, 2, 1, true):Start()
    --先刷新完数据，再派发事件做界面刷新
    Game.GlobalEvent:DispatchEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh)
    --刷新极速探险免费次数
    Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnFastBattleChanged)
    --五点刷新拍脸
    Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnPatFaceRedRefresh)
    CheckRedPointStatus(RedPointType.SecretTer_HaveFreeTime)
    CheckRedPointStatus(RedPointType.DailyGift)
    CheckRedPointStatus(RedPointType.GrowthPackage)

    CheckRedPointStatus(RedPointType.Guild_Fete)
    CheckRedPointStatus(RedPointType.Guild_AidBox)
    CheckRedPointStatus(RedPointType.Guild_AidGuild)
    CheckRedPointStatus(RedPointType.Guild_AidMy)

    LuckyTurnTableManager.SetTimes(msg.hadLuckTime,msg.hadAdvanceLuckyTime)
    --三个抽奖勾选重置
    PlayerPrefs.SetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..RecruitType.Ten,0)
    PlayerPrefs.SetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..RecruitType.TimeLimitTen,0)
    PlayerPrefs.SetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..RecruitType.QianKunBoxTen,0)

    NetManager.GetAllFunState(function ()
        Game.GlobalEvent:DispatchEvent(GameEvent.FunctionCtrl.OnFunctionOpen)
    end)
end

--服务器推送红点信息
function this.ReceiveRedPoint(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.RedPointInfo()
    msg:ParseFromString(data)
    -- 显示红点
    RedpotManager.SetServerRedPointStatus(msg.type, RedPointStatus.Show)
end

--后端更新背包数据
function this.BackUpDataBagItemIdNumber(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.UpdateBagIndication()
    msg:ParseFromString(data)
    BagManager.BagIndicationRefresh(msg)
end

-- 好友数据单独处理
function this.ReceiveFriendChat(buffer)
    local data = buffer:DataByte()
    local msg = ChatProto_pb.SendChatInfoIndication()
    msg:ParseFromString(data)
    if msg.type == 1 then
        FriendChatManager.ReceiveFriendChat(msg)
    elseif msg.type == 2 then
        ChatManager.ReceiveFamilyChat(msg)
    end
end

--服务器推送相关任务的状态数据
function this.RefreshMissionList(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.MissionUpdateListIndication()
    msg:ParseFromString(data)
    TaskManager.RefreshTypeTaskInfo(msg.userMissionInfo)
    Game.GlobalEvent:DispatchEvent(GameEvent.TreasureOfHeaven.TaskRefresh)
end

-- 接收服务器数据
function this.ReceiveChatMsg(buffer)
    local data = buffer:DataByte()
    local msg = FightInfoProto_pb.AdventureBossFindIndication()
    msg:ParseFromString(data)
    --TODO: 服务器主动推送的数据与原数据不同，需特殊处理
    -- 只保留三十条数据
    table.insert(AdventureManager.adventureChatList, msg.adventureBossInfo)
    if #AdventureManager.adventureChatList > 30 then
        table.remove(AdventureManager.adventureChatList, 1)
    end
    -- 是否需要刷新显示标志位
    AdventureManager.IsChatListNew = true
    -- 聊天数据刷新
    Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnChatListChanged)

    -- 判断新增外敌是否在外敌列表中，不在则保存
    local data = AdventureManager.GetEnemyDataByBossId(msg.adventureBossInfo.bossId)
    if not data then
        table.insert(AdventureManager.adventrueEnemyList, msg.adventureBossInfo)
        AdventureManager.SortEnemyList()
        -- 数据刷新
        Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnEnemyListChanged)
    end
end

--拉去Boss外敌信息
function this.GetBossInfo(buffer)
    local data = buffer:DataByte()
    local msg = FightInfoProto_pb.AdventureBossKillIndication()
    msg:ParseFromString(data)
    AdventureManager.GetAdventureBossFlushRequest(msg)
    local removeIndex = nil
    for i, v in ipairs(AdventureManager.adventrueEnemyList) do
        if v.bossId == msg.bossId then
            removeIndex = i
        end
    end
    if removeIndex then
        table.remove(AdventureManager.adventrueEnemyList, removeIndex)
        AdventureManager.SortEnemyList()
        -- 是否需要刷新显示标志位
        AdventureManager.IsChatListNew = true
        -- 聊天数据刷新
        Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnChatListChanged)
        Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnEnemyListChanged)
    end
end

function this.RefreshGiftGoods(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.AllGiftGoodsIndication()
    msg:ParseFromString(data)
    OperatingManager.SetBasicValues(msg.GiftGoodsInfo)
end

-- 接收服务器好友申请,添加
function this.ReceiveFriendApplication(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.sendFriendInfoIndication()
    msg:ParseFromString(data)
    local friendApplicationData = msg.Friends
    if msg.type == 1 then
        GoodFriendManager.OnFriendDataRefresh(3, msg)
        --GoodFriendManager.friendApplicationData[friendApplicationData.id] = friendApplicationData
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendApplication, GoodFriendManager.friendApplicationData)
    end
    if msg.type == 2 then
        GoodFriendManager.OnFriendDataRefresh(1, msg)
        -- GoodFriendManager.friendAllData[friendApplicationData.id] = friendApplicationData
        GoodFriendManager.friendApplicationData[friendApplicationData.id] = nil
        RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "redPointApplication", 1)
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, GoodFriendManager.friendAllData)
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendApplication, GoodFriendManager.friendApplicationData)
    end
    CheckRedPointStatus(RedPointType.Friend_Application)
    CheckRedPointStatus(RedPointType.Friend_Reward)
end

-- 接收服务器好友删除，赠送体力推送
function this.ReceiveFriendDeleteState(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.SendFriendStateIndication()
    msg:ParseFromString(data)
    if msg.type == 1 then
        GoodFriendManager.friendAllData[msg.friendId] = nil
        --this.friendSearchData[msg.friendId].isHaveApplication=1
        Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendDelete, msg.friendId)
    end
    if msg.type == 2 then
        GoodFriendManager.friendAllData[msg.friendId].haveReward = 1
    end
    CheckRedPointStatus(RedPointType.Friend_Reward)
    Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendList, GoodFriendManager.friendAllData)
end

-- 接收商店数据
function this.ReceiveShopData(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.storeUpdateIndication()
    msg:ParseFromString(data)
    ShopManager.UpdateShopData(msg)
end

-- 加入公会成功推送
function this.GuildJoinSuccess(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.FamilyJoinIndicaion()
    msg:ParseFromString(data)
    local isSelf = msg.familyUserInfo.roleUid == PlayerManager.uid
    if isSelf then
        MyGuildManager.SetMyGuildInfo(msg)
        MyGuildManager.SetMyMemInfo(msg)
        MyGuildManager.SetMyFeteInfo(msg)
        -- 初始化一遍数据
        MyGuildManager.InitAllData(function()
            -- 发送数据更新事件
            Game.GlobalEvent:DispatchEvent(GameEvent.Guild.JoinGuildSuccess)
            -- 显示tip
            GuildManager.AddGuildTip(GUILD_TIP_TYPE.JOIN, msg.familyBaseInfo.name)
        end)
    else
        -- 不是自己暂不做处理
        --MyGuildManager.RequestMyGuildMembers()
    end
end

-- 被踢出公会推送
function this.GuildKickOut(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.KickOutIndication()
    msg:ParseFromString(data)
    MyGuildManager.BeKickOut(msg)
end
-- 被踢出公会推送
function this.GuildBeRefused(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.RefuseJoinFamily()
    msg:ParseFromString(data)
    GuildManager.AddGuildTip(GUILD_TIP_TYPE.REFUSE, msg.name)
end
-- 职位变更推送
function this.GuildPositionUpdate(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.FamilyPositionUpdateIndication()
    msg:ParseFromString(data)
    MyGuildManager.UpdateGuildPosition(msg)
end
-- 公会信息推送
function this.GuildDataUpdate(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.FamilyChangeIndication()
    msg:ParseFromString(data)
    MyGuildManager.SetMyGuildInfo(msg)
end
-- 公会成员行走
function this.GuildWalkUpdate(buffer)
    -- 不在公会主界面不接收，打开公会主界面时会刷新
    if not UIManager.IsOpen(UIName.GuildMainCityPanel) then
        return
    end
    local data = buffer:DataByte()
    local msg = Family_pb.FamilyWalkIndicaiton()
    msg:ParseFromString(data)
    MyGuildManager.UpdateWalkData(msg)
end
-- 公会战防守阵容改变推送
function this.GuildFightDefendUpdate(buffer)
    -- 不在公会主界面不接收，打开界面时会刷新
    if not UIManager.IsOpen(UIName.GuildMainCityPanel) then
        return
    end
    local data = buffer:DataByte()
    local msg = Family_pb.FamilyDefendInfo()
    msg:ParseFromString(data)
    GuildFightManager.UpdateDefendStageData(msg)
end
-- 公会战匹配成功
function this.GuildFightMatchingSuccess(buffer)
    -- 不在公会主界面不接收，打开界面时会刷新
    if not UIManager.IsOpen(UIName.GuildMainCityPanel) then
        return
    end
    local data = buffer:DataByte()
    local msg = Family_pb.EnemyFamily()
    msg:ParseFromString(data)
    GuildFightManager.SetEnemyBaseData(msg)
end

-- 公会战匹配成功
function this.GuildFightBeKilled(buffer)
    -- 不在公会主界面不接收，打开界面时会刷新
    local data = buffer:DataByte()
    local msg = Family_pb.DefeatResponse()
    msg:ParseFromString(data)
    GuildFightManager.KillSomeBody(msg)
end

-- 公会祭祀进度
function this.GuildFeteRewardProcess(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.FamilyFeteRewardProcessIndication()
    msg:ParseFromString(data)
    MyGuildManager.SetMyFeteInfo_ByScore(msg)
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.OnRefreshFeteProcess)
end

-- --公会战阶段刷新
-- function this.GuildRefreshDeathPosStatus(buffer)
--     local data = buffer:DataByte()
--     local msg = Family_pb.DeathPathStatusChangeIndication()
--     msg:ParseFromString(data)
--     DeathPosManager.status=msg.status
--     if msg.status == 1  then
--         DeathPosManager.battleTime = DeathPosManager.maxBattleTime
--     else
--         DeathPosManager.battleTime = 0
--     end
--     Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshDeathPosStatus)
-- end

--公会战 其他玩家领取奖励推送
function this.GuildDoRewardIndication(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.DoRewardIndication()
    msg:ParseFromString(data)
    -- DeathPosManager.SetDoRewardIndication(msg.info)
    -- Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshDeathPosReward)
    GuildBattleManager.SetRewardInfo(msg.info)
end

-- --公会战第一名修改推送
-- function this.GuildFirstChangeIndication(buffer)
--     local data = buffer:DataByte()
--     local msg = Family_pb.DeathPathFirstChangeIndication()
--     msg:ParseFromString(data)
--     DeathPosManager.SetGuildInfoIndication(msg.changeInfo)
--     Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshFirstChangeData)
-- end

function this.ActivityUpdateProgressIndication(buffer)
    local data = buffer:DataByte()
    local message = PlayerInfoProto_pb.ActivityUpateProgressIndication()
    message:ParseFromString(data)
    ActivityGiftManager.RefreshActivityProgressData(message)
end
function this.UpdateUserExp(buffer)
    local data = buffer:DataByte()
    local message = PlayerInfoProto_pb.UpdateUserExpIndicaiton()
    message:ParseFromString(data)

    PlayerManager.BcakUpdateUserExp(message)
end

function this.UpdateSecretSeasonData(buffer)
    local data = buffer:DataByte()
    local message = PlayerInfoProto_pb.UpdateSecretBoxSeasonIndication()
    message:ParseFromString(data)
    SecretBoxManager.RefreshSeasonTime(message)
end

-- 滚出图
function this.TimeToFuckOutMap(buffer)
    if UIManager.IsOpen(UIName.BattleFailPopup) then
        UIManager.ClosePanel(UIName.BattleFailPopup)
    end

    if UIManager.IsOpen(UIName.BattleWinPopup) then
        UIManager.ClosePanel(UIName.BattleWinPopup)
    end

    if UIManager.IsOpen(UIName.BattlePanel) then
        BattleLogic.IsEnd = true
        UIManager.ClosePanel(UIName.BattlePanel)
    end

    if UIManager.IsOpen(UIName.FormationPanel) then
        UIManager.ClosePanel(UIName.FormationPanel)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.OnForceGetOutMap)
end

-- 刷新地图事件点的显示时间
function this.FreshPointShowTime(buffer)
    local data = buffer:DataByte()
    local msg = MapInfoProto_pb.EndlessTimeIndication()
    msg:ParseFromString(data)
    EndLessMapManager.InitRefreshPoint(msg.infos)
    EndLessMapManager.isAddPoint = true
    MapManager.PanelCloseCallBack(UIName.MapOptionPanel, function()
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.OnAddCountTimePoint)
    end)
end

-- 强制改名
function this.PlayerBackCInfo(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.PlayerBackCInfoIndication()
    msg:ParseFromString(data)
    NameManager.SetRoleName(msg.nickName)
    PlayerManager.nickName = msg.nickName
    Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnChangeName)
end

--支付成功
function this.PaySuccess(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.NotifyPaySuccessfulIndicaiton()
    msg:ParseFromString(data)
    --if LoginManager.pt_pId == 2 then --TODO:九游渠道不允许客户端接受回调处理，通过监听服务器推送处理
    local tip = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, msg.goodsId).Tip)
    PopupTipPanel.ShowTip(tip)
    --FirstRechargeManager.RefreshAccumRechargeValue(msg.goodsId)
    -- 延时0.5秒刷新。避免sdk支付时商店次数未刷新，界面刷新的问题
    Timer.New(function()
        Game.GlobalEvent:DispatchEvent(GameEvent.MoneyPay.OnPayResultSuccess, msg.goodsId)
    end, 0.5):Start()
    --end
end

--调查问卷
function this.RefreshQuestionnaire(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.QuestionIndication()
    msg:ParseFromString(data)
    if msg.state == 1 then
        QuestionnaireManager.SetQuestionState(0)
        QuestionnaireManager.RefreshQuestionData()
    else
        QuestionnaireManager.ResetArgs()
        QuestionnaireManager.SetQuestionState(-1)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Questionnaire.OnQuestionnaireChange, msg.state)
end

-- 空地生成小怪
function this.MapNewAMonster(buffer)
    local data = buffer:DataByte()
    local msg = MapInfoProto_pb.RefreshMonsterResponse()
    msg:ParseFromString(data)
    for i = 1, #msg.cell do
        local pos = msg.cell[i].cellId
        local mapPointId = msg.cell[i].pointId
        MapManager.pointAtkPower[msg.cell[i].cellId] = msg.cell[i].monsterForce
        MapManager.PanelCloseCallBack(UIName.BattleEndPanel, function()
            CallBackOnPanelOpen(UIName.MapPanel, function ()
                Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointAdd, pos, mapPointId)
            end)
        end)
    end
end

-- 空地生成小怪
function this.BloodyScoreChanged(buffer)
    local data = buffer:DataByte()
    local msg = RoomProto_pb.BloodyScoreChangeIndication()
    msg:ParseFromString(data)
    MatchDataManager.SetRewardScore(msg.myscore)
end

-- 无尽副本换编队刷新最大血量值
function this.EndLessTeamChange(buffer)
    local data = buffer:DataByte()
    local msg = MapInfoProto_pb.EndlessSetTeamIndication()
    msg:ParseFromString(data)
    EndLessMapManager.UpDateTeamMaxHp(msg.info)
end
function this.DirectBuyGoods(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.DirectBuyIndication()
    msg:ParseFromString(data)
    PatFaceManager.ShowBuyLaterDrop(msg)
end

function this.RefreshMapData(buffer)
    local data = buffer:DataByte()
    local msg = MapInfoProto_pb.EndlessMapChange()
    msg:ParseFromString(data)
    EndLessMapManager.openMapId = msg.mapId
    EndLessMapManager.worldLevel = msg.worldLevel
end

function this.RestTreasureTaskData(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.TreasureRefreshIndication()
    msg:ParseFromString(data)
    TaskManager.ResetTreasureTaskInfo(msg.tasks)
end
function this.RefreshTreasureLevel(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.TreasureLevelUpIndication()
    msg:ParseFromString(data)
    TreasureOfSomebodyManagerV2.SetCurrentLevel(msg.level)
    CheckRedPointStatus(RedPointType.TreasureOfSl)
    GrowthManualManager.SetTreasureBuyStatus(msg.hadBuy)
    if msg.level ~= GrowthManualManager.GetLevel() then
        UIManager.OpenPanel(UIName.GrowthManualLevelUpPanel,msg.level)
    end
    GrowthManualManager.SetLevel(msg.level)    
    GrowthManualManager.UpdateTreasureState2()
end

--幸运转盘
function this.ReceiveLuckyTurnData(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.LuckWheelIndication()
    msg:ParseFromString(data)
    LuckyTurnTableManager.ReceiveServerData(msg.posInfos,msg.posInfosAdvance)
end

-- 更新关卡ID
function this.FreshFightId(buffer)
    local data = buffer:DataByte()
    local msg = FightInfoProto_pb.MainLevelFightUpdateIndication()
    msg:ParseFromString(data)
    FightPointPassManager.RefreshFightId(msg)
end

-- 后端推送累充金额
function this.RefreshAccuMoneyNum(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.RefreshRechargeIndication()
    msg:ParseFromString(data)
    VipManager.RefreshChargeMoney(msg.amount, false)
    OperatingManager.RefreshMonthCardChargeMoney(msg)
end

-- 巅峰战阶段更新
function this.TopMatchStageUpdate(buffer)
    local data = buffer:DataByte()
    local msg = ArenaInfoProto_pb.ChampionProgressUpdateIndication()
    msg:ParseFromString(data)
    ArenaTopMatchManager.UpdateTopMatchStage(msg)
end

-- 巅峰战竞猜成功
function this.TopMatchGuessSuccess(buffer)
    local data = buffer:DataByte()
    local msg = ArenaInfoProto_pb.ChampionGuessSuccessIndication()
    msg:ParseFromString(data)
    -- ArenaTopMatchManager.OnGuessSuccess(msg)
end

-- 特权解锁
function this.OnPrivilegeUpdate(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.PrivilegeIndication()
    msg:ParseFromString(data)
    PrivilegeManager.OnPrivilegeUpdate(msg.infos)
end

function this.RefreshExpeditionHalidom(buffer)
    local data = buffer:DataByte()
    local msg = Expedition_pb.ExpeditionEquipIndication()
    msg:ParseFromString(data)
    ExpeditionManager.UpdateHalidomValue(msg)
end
function this.RefreshExpeditionNodeAndHeros(buffer)
    local data = buffer:DataByte()
    local msg = Expedition_pb.ExpeditionNodeInfoIndication()
    msg:ParseFromString(data)
    ExpeditionManager.UpdateHeroHpValue(msg.heroInfo)
    ExpeditionManager.UpdateNodeValue(msg.nodeInfo)
end
function this.RefreshMonthCardData(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.MonthCardIndication()
    msg:ParseFromString(data)
    OperatingManager.UpdateMonthCardData(msg)
end
function this.RefreshGuildCarDelayProgressData(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.CarDelayProgressIndication()
    msg:ParseFromString(data)
    GuildCarDelayManager.SetProgressData(msg)
end
function this.RefreshGuildAidInfoData(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.GuildHelpInfoIndication()
    msg:ParseFromString(data)
    MyGuildManager.SetSingleGuildHelpInfo(msg)
end
function this.GuildHelpLogIndication(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.GuildHelpLogIndication()
    msg:ParseFromString(data)
    MyGuildManager.SetSingleGuildHelpLogInfo(msg)
end
function this.ExpeditionResetIndication(buffer)
    local data = buffer:DataByte()
    local msg = Expedition_pb.GetExpeditionResponse()--ExpeditionResetIndication()
    msg:ParseFromString(data)
    PlayerPrefs.SetInt(PlayerManager.uid.."Expedition", 0)
    ExpeditionManager.SetExpeditionState(3)
    ExpeditionManager.expeditionLeve = 1
    ExpeditionManager.InitExpeditionData(msg)
    ExpeditionManager.RefreshPanelShowByState()
end
function this.TreasureStateIndicaion(buffer)
    local data = buffer:DataByte()
    local msg = Expedition_pb.TreasureStateIndicaion()--ExpeditionResetIndication()
    msg:ParseFromString(data)
    TreasureOfHeavenManger.SetScore(msg.score)
    TreasureOfHeavenManger.SetLimitTime(msg.resetTime)
    for i = 1, #msg.treasureRewardState do
        TreasureOfHeavenManger. SetSingleRewardState(msg.treasureRewardState[i].id,msg.treasureRewardState[i].state)
    end
end

-- 爬塔更新数据
function this.ClimbTowerFreshFightId(buffer)
    local data = buffer:DataByte()
    local msg = FightInfoProto_pb.VirtualBattleFightUpdateIndication()
    msg:ParseFromString(data)
    ClimbTowerManager.UpdateFightIdData(msg, ClimbTowerManager.ClimbTowerType.Normal)
end
-- 爬塔更新数据 高级
function this.ClimbTowerFreshFightIdAdvance(buffer)
    local data = buffer:DataByte()
    local msg = FightInfoProto_pb.VirtualBattleFightUpdateIndication()
    msg:ParseFromString(data)
    ClimbTowerManager.UpdateFightIdData(msg, ClimbTowerManager.ClimbTowerType.Advance)
end

function this.GuildTranscriptIndication(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.GuildChallengeIndication()
    msg:ParseFromString(data)
    GuildTranscriptManager.RefreshGuildTranscriptInfo(msg)
end

function this.GuildChallengeBuyBuffIndication(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.GuildChallengeBuyBuffIndication()
    msg:ParseFromString(data)
    GuildTranscriptManager.RefreshGuildTranscriptBuffInfo(msg)
end

-- 防守训练更新数据
function this.DefenseTrainingFreshFightId(buffer)
    local data = buffer:DataByte()
    local msg = FightInfoProto_pb.DefTrainingBattleFightUpdateIndication()
    msg:ParseFromString(data)
    DefenseTrainingManager.UpdateFightIdData(msg)
end
--后端拍脸推送
function this.BackPatFaceData(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.PushWelfareResponse()
    msg:ParseFromString(data)
    local name = ConfigManager.TryGetConfigData(ConfigName.RechargeCommodityConfig,msg.id[#msg.id]).Name
    local title = string.format(GetLanguageStrById(50168),GetLanguageStrById(name))
    LogRed("打印：触发拍脸")
    UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.UpGradePackage, title, function()
        if not PatFaceManager.GetcurCanPatFace() then
            PopupTipPanel.ShowTipByLanguageId(50270)
        end
        PatFaceManager.SetPatFaceDaqta(msg)
    end)
end
--已有勋章更新
--function this.medalInfo(buffer)
    -- local data = buffer:DataByte()
    -- local msg = MedalProto_pb.MedalGetAllReponse()
    -- msg:ParseFromString(data)
    -- MedalManager.InitAllMedalData(msg)
--end

--勘探记录推送
function this.UpdateProspectInfo(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.UpdateProspectInfoAll()
    msg:ParseFromString(data)
    if ReconnaissancePanel ~= nil then
        ReconnaissancePanel.updataUpTipText(msg)
    end
end

--称号ID推送
function this.UpdateUserDesignation(buffer)
--     local data = buffer:DataByte()
--     local msg = PlayerInfoProto_pb.UpdateUserDesignation()
--     msg:ParseFromString(data)
--     PlayerManager.designation = msg.designation
end

function this.InvestigateUpLevel(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.InvestigateUpLevelResponse()
    msg:ParseFromString(data)
    FormationCenterManager.PushData(msg)
end
function this.InvestJourneyNextFlushTime(buffer)
    local data = buffer:DataByte()
    local msg = MapInfoProto_pb.JourneyNextFlushTimeResponse()
    msg:ParseFromString(data)
    BagManager.GoDiceBackData(msg)
end

function this.RefreshTitle(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.TitleUpdatePush()
    msg:ParseFromString(data)
    PlayerManager.RefreshTitle(msg)
    FormationManager.UserPowerChanged()
end

function this.ActivityChapterIndication(buffer)
    local data = buffer:DataByte()
    local msg = ActivityProto_pb.ActivityChapterIndication()
    msg:ParseFromString(data)
    PVEActivityManager.ActivityChapterIndication(msg)
end

function this.DeathPathCurFirstChangeIndication(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.DeathPathCurFirstChangeIndication()
    msg:ParseFromString(data)
    GuildBattleManager.SetFirstRank(msg.changeInfo)
end

function this.GuildBattleStateChange(buffer)
    local data = buffer:DataByte()
    local msg = Family_pb.DeathPathStatusChangeIndication()
    msg:ParseFromString(data)
    GuildBattleManager.ChangeGuildState()
end

function this.WarOrderIndication(buffer)
    local data = buffer:DataByte()
    local msg = EncouragePlan_pb.PushEncouragePlanTaskCompeted()
    msg:ParseFromString(data)
    OperatingManager.ChangeTaskState(msg)
end

function this.PushEncouragePlanUnlock(buffer)
    local data = buffer:DataByte()
    local msg = EncouragePlan_pb.PushEncouragePlanUnlock()
    msg:ParseFromString(data)
    OperatingManager.ChangeWarOrderState(msg)
end

function this.PushWarOrderPropress(buffer)
    local data = buffer:DataByte()
    local msg = EncouragePlan_pb.PushEncouragePlanTaskProgressChanged()
    msg:ParseFromString(data)
    OperatingManager.PushWarOrderPropress(msg)
end

function this.PushEncouragePlanReset(buffer)
    local data = buffer:DataByte()
    local msg = EncouragePlan_pb.PushEncouragePlanReset()
    msg:ParseFromString(data)
    OperatingManager.PushWarOrderResetting(msg)
end

return this