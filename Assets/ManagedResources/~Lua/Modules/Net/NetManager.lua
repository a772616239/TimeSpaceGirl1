require "Message/CommonProto_pb"
require "Message/ChatProto_pb"
require "Message/FightInfoProto_pb"
require "Message/MessageTypeProto_pb"
require "Message/PlayerInfoProto_pb"
-- require "Message/GMCommandProto_pb"
require "Message/HeroInfoProto_pb"
require "Message/MapInfoProto_pb"
-- require "Message/MissionInfoProto_pb"
require "Message/ArenaInfoProto_pb"
require "Message/Family_pb"
require "Message/Expedition_pb"
require "Message/SupportProto_pb"
require "Message/AdjutantProto_pb"
require "Message/GeneralProto_pb"
require "Message/CombatPlanProto_pb"
require "Message/GuildProto_pb"
require "Message/DefTrainingProto_pb"
require "Message/FriendProto_pb"
require "Message/SupremacyProto_pb"
require "Message/BlitzProto_pb"
require "Message/MedalProto_pb"
require "Message/AlameinWarProto_pb"
require "Message/MotherShipProto_pb"
require "Message/ActivityProto_pb"
require "Message/gtwprotos/WorldProto_pb"
require "Message/CampWar_pb"
require "Message/EncouragePlan_pb"

NetManager = {}
local this = NetManager
local Network

function this.Initialize()
    Game.GlobalEvent:AddEvent(Protocal.Connect, this.RegisterMessage)
end

function this.RegisterMessage(network)
    if network.type == SocketType.LOGIN then
        Network = network
    end
end

function this.IsConnect()
    return Network and Network.isConnected
end

--请求登录
function this.LoginRequest(openId, func)
    local data = PlayerInfoProto_pb.LoginRequest()
    data.device_id_s = AppConst.isSDK and AndroidDeviceInfo.Instance:GetDeviceID() or ""
    data.idfa_sOr_imei_s = AppConst.isSDK and AndroidDeviceInfo.Instance:GetIMEICode() or ""
    data.brand_type_s = AppConst.isSDK and AndroidDeviceInfo.Instance:GetDeviceBrand() or ""
    data.brand_s = AppConst.isSDK and AndroidDeviceInfo.Instance:GetDeviceModel() or ""
    data.os_version_s = AppConst.isSDK and AndroidDeviceInfo.Instance:GetSystemVersion() or ""
    data.dpi_s = AppConst.isSDK and AndroidDeviceInfo.Instance:GetScreenRatio() or ""
    data.operator_s = AppConst.isSDK and AndroidDeviceInfo.Instance:GetOperatorName() or ""
    data.network_s = AppConst.isSDK and AndroidDeviceInfo.Instance:GetNetworkType() or ""
    data.ip_s = AppConst.isSDK and AndroidDeviceInfo.Instance:GetLocalIpAddress() or ""
    -- data.distinct_id = AppConst.isSDK and ThinkingAnalyticsManager.GetDistinctId() or ""
    data.distinct_id = ""
    data.openId = openId
    -- data.channel_s = AppConst.isSDKLogin and AppConst.SdkChannel .. "#" .. AppConst.SdkPackageName or ""  --pt_pid.."#"..pt_gid
    data.platform_s = AppConst.isSDK and "ADR" or "PC"

    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.LOGIN_REQUEST, MessageTypeProto_pb.LOGIN_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.LoginResponse()
        msg:ParseFromString(data)
        if msg.resultCode == 0 then
            --成功登录
            if func then
                func(msg)
            end
        end
        AppConst.Token = msg.newToken
        -- 打点
        -- ThinkingAnalyticsManager.SetDistinctId(AppConst.OpenId)
        -- ThinkingAnalyticsManager.SetSuperProperties({
        --     server_id = LoginManager.ServerId,
        --     account = AppConst.isSDK and tostring(AppConst.OpenId) or "",
        --     Bundle_id = AppConst.isSDK and AppConst.SdkPackageName or "",
        --     xx_id = AppConst.isSDK and AppConst.SdkChannel or "",
        --     -- test_list = "1,2,3#2",  -- 数组
        -- })
        -- TapDBManager.SetServer(LoginManager.ServerId)
    end)
end

--请求玩家数据
function this.PlayerInfoRequest(func)
    local data = PlayerInfoProto_pb.GetPlayerInfoRequest()
    data.num = 1
    data.str = "shujushuju"
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_PLAYERINFO_REQUEST, MessageTypeProto_pb.GET_PLAYERINFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetPlayerInfoResponse()
        msg:ParseFromString(data)
        Log("________uid        "..msg.player.uid)
        PlayerManager.uid = msg.player.uid
        gameMgr:SetUid(PlayerManager.uid)
        PlayerManager.nickName = msg.player.nickName
        NameManager.SetRoleName(msg.player.nickName)
        PlayerManager.level = msg.player.level
        PlayerManager.exp = msg.player.exp
        PlayerManager.familyId = msg.player.familyId
        PlayerManager.head = msg.player.head
        PlayerManager.frame = msg.player.headFrame == 0 and 80000 or msg.player.headFrame
        PlayerManager.gold = msg.player.gold
        PlayerManager.gem = msg.player.gem
        PlayerManager.chargeGem = msg.player.chargeGem
        PlayerManager.curMapId = msg.player.curMapId
        MapManager.isInMap = PlayerManager.curMapId ~= 0 and PlayerManager.curMapId > 100
        PlayerManager.maxForce = msg.player.maxForce
        -- RecruitManager.randCount = msg.randCount % 100 --钻石抽卡已招募次数 用不上了 协议没删
        RecruitManager.isTenRecruit = msg.firstTenth --首次十连
        PatFaceManager.SetisFirstLogVal(msg.isDayFirst)
        PlayerManager.userCreateTime = msg.userCreateTime
        SoulPrintManager.soulEquipPool = msg.SoulEquipPool
        -- PlayerManager.designation = msg.player.designation--称号
        PlayerManager.SetPlayerDesignation(msg.player.designation)
        PlayerManager.skin = msg.player.decrotion--皮肤
        PlayerManager.ride = msg.player.ride--坐骑
        PlayerManager.rideLevel = msg.player.rideLevel
        PlayerManager.sex = msg.player.sex
        PlayerManager.isShowVip = msg.showVip
        MyGuildManager.ExitTimeStamp = msg.leaveGuildTime
        if msg.player.sex then
            NameManager.SetRoleSex(msg.player.sex)
        else
            NameManager.SetRoleSex(ROLE_SEX.BOY)
        end
        AdventureManager.trainStageLevel = msg.trainTaskCurLevel
        -- 数据打点
        -- ThinkingAnalyticsManager.CalibrateTime(msg.player.serverTime)
        -- ThinkingAnalyticsManager.Login(PlayerManager.uid)
        -- ThinkingAnalyticsManager.SetSuperProperties({
        --     role_id = PlayerManager.uid,
        --     role_name = PlayerManager.nickName,
        --     vip_level = msg.player.vipLevel,
        --     -- test_date = math.floor(msg.player.serverTime) .. "#3",   -- 日期
        -- })
        -- TapDBManager.SetUser(PlayerManager.uid)
        -- TapDBManager.SetLevel(PlayerManager.level)

        -- 
        PlayerManager.missingRefreshCount = msg.missingRefreshCount--迷宫寻宝妖精刷新次数
        PlayerManager.SetMoveSpeedAndMapView()
        -- 设置服务器保存的红点数据
        RedpotManager.SetServerRedPointData(msg.redType)

        FirstRechargeManager.isFirstRecharge = msg.player.isFirstRecharge
        -- 老式Vip
        -- VipManager.InitCommonData(msg.vipBaseInfo)
        VipManager.SetVipLevel(msg.player.vipLevel)
        -- 
        PrivilegeManager.dailyGemRandomTimes = msg.dailyGemRandomTimes --限时招募次数
        PrivilegeManager.InitPrivilegeData(msg.privilege)
        OperatingManager.SetBasicValues(msg.giftGoodsInfo)
        OperatingManager.SetHadBuyGoodsId(msg.buyGoodsId)
        OperatingManager.SetGoodsDurationData(msg.goodsTypeDuration)
        PlayerManager.InitHandBookData(msg.heroHandBook, msg.equipHandBook)
        Log("PlayerManager.serverTime:"..PlayerManager.serverTime)
        PlayerManager.serverTime = msg.player.serverTime
        AdventureManager.serverTime = msg.player.serverTime
        ActivityGiftManager.serverTime = msg.player.serverTime

        FirstRechargeManager.SetAccumRechargeValue(msg.player.saveAmt)
        FirstRechargeManager.SetRechargeTime(msg.player.rechargeTime)

        BindPhoneNumberManager.InitBindInfo(msg.playerBindPhone)
        QuestionnaireManager.SetQuestionState(msg.QuestionState)

        PlayerManager.SetMaxEnergy()
        PlayerManager.InitServerTime()
        GuideManager.InitData(msg.newPlayerGuidePoint)
        --临时初始化地图探索的静态数据
        MapManager.InitAllMapPgData()
        -- WorkShopManager.UpdateWorkShopLvAndExp(msg.player.workLevel,msg.player.workExp)
        RoomManager.CurRoomType = msg.player.curRoomType
        RoomManager.RoomAddress = msg.player.roomAddreess

        -- 精英怪数据
        local suddBossId = msg.SuddenlyBossInfo.suddBossId
        local endTime = msg.SuddenlyBossInfo.endTime
        local findMapId = msg.SuddenlyBossInfo.findMapId
        EliteMonsterManager.SetEliteData(suddBossId, endTime, findMapId)

        -- 试炼副本层级奖励
        -- MapTrialManager.InitTrialRewardData(msg.towerReceivedReward)

        TreasureOfSomebodyManagerV2.SetCurrentLevel(msg.treasureLevel)
        TreasureOfSomebodyManagerV2.SetTreasureBuyStatus(msg.hadBuyTreasure)

        -- 当前波次
        MonsterCampManager.monsterWave = msg.monsterAttackTime
        OperatingManager.SetSignInData(msg.SignInInfo)


        --月卡初始化数据
        OperatingManager.InitMonthCardData(msg.monthinfos)

        --每日副本数据
        CarbonManager.dailyChallengeInfo=msg.dailyChallengeInfo

        --猎妖之路阶段
        ExpeditionManager.RefreshCurExpeditionLeve(msg.expeditionLeve)

        HeadManager.InitData()

        -- 充值金额
        VipManager.InitInfoOnLogin(msg)

        --> 支援系统属性数值参数
        SupportManager.UpdateProData(msg.supportDate)

        --成长手册
        GrowthManualManager.SetLevel(msg.treasureLevel)
        GrowthManualManager.SetTreasureBuyStatus(msg.hadBuyTreasure)

        MapManager.PlayedMapTypes = msg.playedMapTypes
        for _, type in ipairs(msg.playedMapTypes) do

        end
        LuckyTurnTableManager.SetTimes(msg.hadLuckTime,msg.hadAdvanceLuckyTime)
        FormationCenterManager.InitData(msg)
        if func then
            func(msg)
        end
    end)
end

--> ********************************************************************************************************************************************************
--> 支援
function NetManager.GetSupportInfos(func)
    local data = SupportProto_pb.GetSupportInfosRequest()

    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetSupportInfosRequest, MessageTypeProto_pb.GetSupportInfosResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = SupportProto_pb.GetSupportInfosResponse()
        msg:ParseFromString(data)
        SupportManager.InitData(msg)
        if func then
            func(msg)
        end
    end)
end
--> 升级
function NetManager.GetSupportLevelUp(type, func)
    local data = SupportProto_pb.GetSupportLevelUpRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetSupportLevelUpRequest, MessageTypeProto_pb.GetSupportLevelUpResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = SupportProto_pb.GetSupportLevelUpResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--> 激活下一飞机
function NetManager.GetSupportActive(func)
    local data = SupportProto_pb.GetSupportActiveRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetSupportActiveRequest, MessageTypeProto_pb.GetSupportActiveResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = SupportProto_pb.GetSupportActiveResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--> 获取支援开启列表 支援选择界面
function NetManager.GetSupportList(func)
    local data = SupportProto_pb.GetSupportListRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetSupportListRequest, MessageTypeProto_pb.GetSupportListResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = SupportProto_pb.GetSupportListResponse()
        msg:ParseFromString(data)
        -- 
        
        SupportManager.UpdateSelectData(msg)
        if func then
            func(msg)
        end
    end)
end
--> 技能Up
function NetManager.GetSupportSkillUp(supportId, func)
    local data = SupportProto_pb.GetSupportSkillUpRequest()
    data.supportId = supportId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetSupportSkillUpRequest, MessageTypeProto_pb.GetSupportSkillUpResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = SupportProto_pb.GetSupportSkillUpResponse()
        msg:ParseFromString(data)
        -- 
        
        if func then
            func(msg)
        end
    end)
end
--> 改造Up
function NetManager.GetSupportRefineUp(func)
    local data = SupportProto_pb.GetSupportRefineUpRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetSupportRefineUpRequest, MessageTypeProto_pb.GetSupportRefineUpResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = SupportProto_pb.GetSupportRefineUpResponse()
        msg:ParseFromString(data)
        -- 
        
        if func then
            func(msg)
        end
    end)
end
--> 改良Up
function NetManager.GetSupportSoulUp(count, func)
    local data = SupportProto_pb.GetSupportSoulUpRequest()
    data.count = count
    local msg = data:SerializeToString()
    
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetSupportSoulUpRequest, MessageTypeProto_pb.GetSupportSoulUpResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = SupportProto_pb.GetSupportSoulUpResponse()
        msg:ParseFromString(data)
        -- 
        
        if func then
            func(msg)
        end
    end)
end


--> 副官
--> 获取所有副官信息
function NetManager.GetAllAdjutantInfo(func)
    --> 是否解锁
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ADJUTANT) then
        if func then
            func()
        end
        return
    end
    
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetAllAdjutantInfoRequest, MessageTypeProto_pb.GetAllAdjutantInfoResponse, nil, function (buffer)
        local data = buffer:DataByte()
        local msg = AdjutantProto_pb.GetAllAdjutantInfoResponse()
        msg:ParseFromString(data)
        
        AdjutantManager.InitData(msg.adjutantDate)
        if func then
            func(msg)
        end
    end)
end
--> 解锁副官
function NetManager.GetAdjutantUnlock(adjutantIds, func)
    local data = AdjutantProto_pb.GetAdjutantUnlockRequest()
    for i = 1, #adjutantIds do
        data.adjutantId:append(adjutantIds[i])
    end
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetAdjutantUnlockRequest, MessageTypeProto_pb.GetAdjutantUnlockResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = AdjutantProto_pb.GetAdjutantUnlockResponse()
        msg:ParseFromString(data)
        -- 
        
        if func then
            func(msg)
        end
    end)
end

--> 沟通
function NetManager.GetAdjutantChat(adjutantId, type, type2, func)
    local data = AdjutantProto_pb.GetAdjutantChatRequest()
    data.adjutantId = adjutantId
    data.type = type    --< 1单次、2以升级为目标次数
    data.type2 = type2  --< 1消耗精力、2消耗物品
    -- 
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetAdjutantChatRequest, MessageTypeProto_pb.GetAdjutantChatResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = AdjutantProto_pb.GetAdjutantChatResponse()
        msg:ParseFromString(data)
        -- 
        
        if func then
            func(msg)
        end
    end)
end
--> 技能
function NetManager.GetAdjutantSkill(adjutantId, func)
    local data = AdjutantProto_pb.GetAdjutantSkillRequest()
    data.adjutantId = adjutantId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetAdjutantSkillRequest, MessageTypeProto_pb.GetAdjutantSkillResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = AdjutantProto_pb.GetAdjutantSkillResponse()
        msg:ParseFromString(data)
        -- 
        
        if func then
            func(msg)
        end
    end)
end
--> 礼物
function NetManager.GetAdjutantHandsel(adjutantId, count, func)
    local data = AdjutantProto_pb.GetAdjutantHandselRequest()
    data.adjutantId = adjutantId
    data.count = count
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetAdjutantHandselRequest, MessageTypeProto_pb.GetAdjutantHandselResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = AdjutantProto_pb.GetAdjutantHandselResponse()
        msg:ParseFromString(data)
        -- 
        
        if func then
            func(msg)
        end
    end)
end
--> 特训
function NetManager.GetAdjutantTeach(adjutantId, func)
    local data = AdjutantProto_pb.GetAdjutantTeachRequest()
    data.adjutantId = adjutantId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetAdjutantTeachRequest, MessageTypeProto_pb.GetAdjutantTeachResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = AdjutantProto_pb.GetAdjutantTeachResponse()
        msg:ParseFromString(data)
        -- 
        
        if func then
            func(msg)
        end
    end)
end

--> 战法
--> 领悟 升级
function NetManager.WarWayLearning(tankId, warWaySkillId, warWaySlot, func)
    local data = CombatPlanProto_pb.WarWayLearningRequest()
    data.tankId = tankId
    data.warWaySkillId = warWaySkillId
    data.warWaySlot = warWaySlot
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WarWayLearningRequest, MessageTypeProto_pb.WarWayLearningResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = CombatPlanProto_pb.WarWayLearningResponse()
        msg:ParseFromString(data)
        
        
        if func then
            func(msg)
        end
    end)
end
--> 遗忘
function NetManager.WarWayForget(tankId, warWaySkillId, warWaySlot, func)
    local data = CombatPlanProto_pb.WarWayForgetRequest()
    data.tankId = tankId
    data.warWaySkillId = warWaySkillId
    data.warWaySlot = warWaySlot
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WarWayForgetRequest, MessageTypeProto_pb.WarWayForgetResponse, msg, function (buffer)
        local data = buffer:DataByte()
        local msg = CombatPlanProto_pb.WarWayForgetResponse()
        msg:ParseFromString(data)
        
        
        if func then
            func(msg)
        end
    end)
end

--> 爬塔
--> 获取爬塔信息
function this.VirtualBattleGetInfo(func)
    --> 是否解锁
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.CLIMB_TOWER) then
        if func then
            func()
        end
        return
    end
    Network:SendMessageWithCallBack(MessageTypeProto_pb.VirtualBattleGetInfoRequest, MessageTypeProto_pb.VirtualBattleGetInfoResponse, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.VirtualBattleGetInfoResponse()
        msg:ParseFromString(data)
        
        ClimbTowerManager.UpdateData(msg, ClimbTowerManager.ClimbTowerType.Normal)
        if func then
            func(msg)
        end
    end)
end

--> 爬塔扫荡 type = 1;//1普通，2高级
function this.VirtualBattleSweep(_type, _fightId, func)
    local data = MapInfoProto_pb.VirtualBattleSweepRequest()
    data.type = _type
    data.fightId = _fightId
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.VirtualBattleSweepRequest, MessageTypeProto_pb.VirtualBattleSweepResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.VirtualBattleSweepResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 爬塔购买挑战次数 _type = 1;//1普通，2高级
function this.VirtualBattleBuyCount(_type, func)
    local data = MapInfoProto_pb.VirtualBattleBuyCountRequest()
    data.type = _type
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.VirtualBattleBuyCountRequest, MessageTypeProto_pb.VirtualBattleBuyCountResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.VirtualBattleBuyCountResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 爬塔战报数据
function this.VirtualBattleFightRePlay(fightId, uid, func)
    local data = FightInfoProto_pb.VirtualBattleFightRePlayRequest()
    data.fightId = fightId
    data.uid = uid
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.VirtualBattleFightRePlayRequest, MessageTypeProto_pb.VirtualBattleFightRePlayResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.VirtualBattleFightRePlayResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 爬塔高级
--> 获取爬塔信息 高级
function this.VirtualElitBattleGetInfo(func)
    --> 是否解锁
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.CLIMB_TOWER) then
        if func then
            func()
        end
        return
    end
    Network:SendMessageWithCallBack(MessageTypeProto_pb.VirtualElitBattleGetInfoRequest, MessageTypeProto_pb.VirtualElitBattleGetInfoResponse, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.VirtualEliteBattleGetInfoResponse()
        msg:ParseFromString(data)
        
        ClimbTowerManager.UpdateData(msg, ClimbTowerManager.ClimbTowerType.Advance)
        if func then
            func(msg)
        end
    end)
end
--> 爬塔战报数据 高级
function this.VirtualElitBattleFightRePlay(fightId, uid, func)
    local data = FightInfoProto_pb.VirtualBattleFightRePlayRequest()
    data.fightId = fightId
    data.uid = uid
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.VirtualElitBattleFightRePlayRequest, MessageTypeProto_pb.VirtualElitBattleFightRePlayResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.VirtualBattleFightRePlayResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 联盟
--> 联盟活跃奖励领取
function this.GuildActiveLevelUp(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GuildActiveLevelUpRequest, MessageTypeProto_pb.GuildActiveLevelUpResponse, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = GuildProto_pb.GuildActiveLevelUpResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 深渊试炼
--> 获取主界面信息
function NetManager.DefTrainingGetInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DefTrainingGetInfoRequest, MessageTypeProto_pb.DefTrainingGetInfoResponse, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = DefTrainingProto_pb.DefTrainingGetInfoResponse()
        msg:ParseFromString(data)
        
        DefenseTrainingManager.UpdateMainData(msg)
        if func then
            func(msg)
        end
    end)
end

--> 通用战斗请求
--> _fightId各模块关卡id
--> _battle_type BATTLE_TYPE
function this.FightStartRequest(_battle_type, _fightId, func, _buffid, _rank)
    local data = FightInfoProto_pb.FightStartRequest()
    data.type = _battle_type
    data.fightId = _fightId
    data.teamId = FormationManager.curFormationIndex
    if _buffid then
        data.buffid = _buffid
    end
    if _rank then
        data.rank = _rank   --< 不同模式意义不同 三强原始意义  精英模拟战是否打擂主（1机器人 2擂主）
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FIGHT_START_REQUEST, MessageTypeProto_pb.FIGHT_START_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.FightStartResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--> 首通领取
function this.DefTrainingGetFirstAward(_fightId, func)
    local data = DefTrainingProto_pb.DefTrainingGetFirstAwardRequest()
    data.fightId = _fightId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DefTrainingGetFirstAwardRequest, MessageTypeProto_pb.DefTrainingGetFirstAwardResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = DefTrainingProto_pb.DefTrainingGetFirstAwardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--> 获取好友支援我的所有坦克by模块
--> _moduleId  1.防守训练
function this.GetTankListFromFriendByModuleId(_moduleId, func)
    local data = FriendProto_pb.GetTankListFromFriendByModuleIdRequest()
    data.moduleId = _moduleId
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetTankListFromFriendByModuleIdRequest, MessageTypeProto_pb.GetTankListFromFriendByModuleIdResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FriendProto_pb.GetTankListFromFriendByModuleIdResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 分享坦克给好友
function this.DefTrainingShareTankToFriend(_heroId, func)
    local data = DefTrainingProto_pb.DefTrainingShareTankToFriendRequest()
    data.heroId = _heroId
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DefTrainingShareTankToFriendRequest, MessageTypeProto_pb.DefTrainingShareTankToFriendResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = DefTrainingProto_pb.DefTrainingShareTankToFriendResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 选择使用好友分享的坦克
function this.DefTrainingUseTankFromFriend(_friendId, _heroId, func)
    local data = DefTrainingProto_pb.DefTrainingUseTankFromFriendRequest()
    data.friendId = _friendId
    data.heroId = _heroId
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DefTrainingUseTankFromFriendRequest, MessageTypeProto_pb.DefTrainingUseTankFromFriendResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = DefTrainingProto_pb.DefTrainingUseTankFromFriendResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 取消使用好友分享的坦克
function this.DisUseTankFromFriendByModuleId(moduleId, tankId, func)
    local data = FriendProto_pb.DisUseTankFromFriendByModuleIdRequest()
    data.moduleId = moduleId
    data.tankId = tankId
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DisUseTankFromFriendByModuleIdRequest, MessageTypeProto_pb.DisUseTankFromFriendByModuleIdResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FriendProto_pb.DisUseTankFromFriendByModuleIdResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 获取编队剩余血量
function this.GetTankInfoOfTeam(_teamId, func)
    local data = FightInfoProto_pb.GetTankInfoOfTeamRequest()
    data.teamId = _teamId
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetTankInfoOfTeamRequest, MessageTypeProto_pb.GetTankInfoOfTeamResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.GetTankInfoOfTeamResponse()
        msg:ParseFromString(data)
        DefenseTrainingManager.UpdateRemainBlood(msg)
        
        if func then
            func(msg)
        end
    end)
end

--> 重置
function this.DefTrainingHandRest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DefTrainingHandRestRequest, MessageTypeProto_pb.DefTrainingHandRestResponse, nil, function(buffer)
        if func then
            func()
        end
    end)
end

--> 闪电出击
--> 获取选择信息
function NetManager.BlitzInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BlitzInfoRequest, MessageTypeProto_pb.BlitzInfoResponse, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = BlitzProto_pb.BlitzInfoResponse()
        msg:ParseFromString(data)
        BlitzStrikeManager.SetDiffInfo(msg)
        
        if func then
            func(msg)
        end
    end)
end

--> 获取主信息
function NetManager.BlitzTypeInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BlitzTypeInfoRequest, MessageTypeProto_pb.BlitzTypeInfoResponse, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = BlitzProto_pb.BlitzTypeInfoResponse()
        msg:ParseFromString(data)
        
        BlitzStrikeManager.SetMainInfo(msg)
        if func then
            func(msg)
        end
    end)
end

--> 选择难度
function NetManager.BlitzChooseDifficulty(_typeId, func)
    local data = BlitzProto_pb.BlitzChooseDifficultyRequest()
    data.typeId = _typeId
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BlitzChooseDifficultyRequest, MessageTypeProto_pb.BlitzChooseDifficultyResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = BlitzProto_pb.BlitzChooseDifficultyResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 获取关卡信息
function NetManager.BlitzLevelInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BlitzLevelInfoRequest, MessageTypeProto_pb.BlitzLevelInfoResponse, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = BlitzProto_pb.BlitzLevelInfoResponse()
        msg:ParseFromString(data)
        
        BlitzStrikeManager.SetStageData(msg)
        if func then
            func(msg)
        end
    end)
end

--> 领取宝箱
function NetManager.BlitzGetBoxAward(_fightId, func)
    local data = BlitzProto_pb.BlitzGetBoxAwardRequest()
    data.fightId = _fightId    
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BlitzGetBoxAwardRequest, MessageTypeProto_pb.BlitzGetBoxAwardResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = BlitzProto_pb.BlitzGetBoxAwardResponse()
        msg:ParseFromString(data)        
        
        if func then
            func(msg)
        end
    end)
end

--> 获取本模块英雄剩余血量
function NetManager.GetBlitzAllTankInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetBlitzAllTankInfoRequest, MessageTypeProto_pb.GetBlitzAllTankInfoResponse, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = BlitzProto_pb.GetBlitzAllTankInfoResponse()
        msg:ParseFromString(data)
        
        BlitzStrikeManager.UpdateRemainBlood(msg)
        if func then
            func(msg)
        end
    end)
end

--> 复活英雄
function NetManager.BlitzReviveTank(heroDids, func)
    local data = BlitzProto_pb.BlitzReviveTankRequest()
    for k, v in pairs(heroDids) do
        data.heroId:append(k)
    end
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BlitzReviveTankRequest, MessageTypeProto_pb.BlitzReviveTankResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = BlitzProto_pb.BlitzReviveTankResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 作战方案
--> 请求全部方案
function NetManager.CombatPlanGetAllRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.COMBATPLAN_GETALL_REQUEST, MessageTypeProto_pb.COMBATPLAN_GETALL_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = CombatPlanProto_pb.CombatPlanGetAllReponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--> 装备方案
function NetManager.CombatPlanWearRequest(heroDid, planDid, pos, func)
    local data = CombatPlanProto_pb.CombatPlanWearRequest()
    data.heroId = heroDid
    data.planId = planDid
    data.position = pos
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.COMBATPLAN_WEAR_REQUEST, MessageTypeProto_pb.COMBATPLAN_WEAR_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

--> 卸下方案
function NetManager.CombatPlanUnloadRequest(heroDid, planDid, pos, func)
    local data = CombatPlanProto_pb.CombatPlanUnloadRequest()
    data.heroId = heroDid
    data.planId = planDid
    data.position = pos
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.COMBATPLAN_UNLOAD_REQUEST, MessageTypeProto_pb.COMBATPLAN_UNLOAD_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

--> 替换方案
function NetManager.CombatPlanReplaceRequest(heroDid, oldPlanDid, newPlanDid, pos, func)
    local data = CombatPlanProto_pb.CombatPlanReplaceRequest()
    data.heroId = heroDid
    data.oldPlanId = oldPlanDid
    data.newPlanId = newPlanDid
    data.position = pos
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.COMBATPLAN_REPLACE_REQUEST, MessageTypeProto_pb.COMBATPLAN_REPLACE_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

--> 分解方案
function NetManager.CombatPlanSellRequest(planDid, func)
    local data = CombatPlanProto_pb.CombatPlanSellRequest()
    data.planId = planDid
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.COMBATPLAN_SELL_REQUEST, MessageTypeProto_pb.COMBATPLAN_SELL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = CombatPlanProto_pb.CombatPlanSellResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 重铸方案
function NetManager.CombatPlanRebuildRequest(planDid, func)
    local data = CombatPlanProto_pb.CombatPlanRebuildRequest()
    data.planId = planDid
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.COMBATPLAN_REBUILD_REQUEST, MessageTypeProto_pb.COMBATPLAN_REBUILD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = CombatPlanProto_pb.CombatPlanRebuildResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--> 重铸确认
function NetManager.CombatPlanConfirmRequest(planDid, func)
    local data = CombatPlanProto_pb.CombatPlanConfirmRequest()
    data.planId = planDid
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.COMBATPLAN_COMFIRM_REQUEST, MessageTypeProto_pb.COMBATPLAN_COMFIRM_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

--作战方案晋级
function NetManager.CombatPlanUpgradeRequest(planDid, func)
    local data = CombatPlanProto_pb.CombatPlanUpgradeRequest()
    data.planId = planDid
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.COMBATPLAN_UPGRADE_REQUEST, MessageTypeProto_pb.COMBATPLAN_UPGRADE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = CombatPlanProto_pb.CombatPlanGetOneReponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end


--> 合成方案
function NetManager.CombatPlanMergeRequest(planDids, compoundQuality, func)
    local data = CombatPlanProto_pb.CombatPlanMergeRequest()
    for i = 1, #planDids do
        data.combatPlanId:append(planDids[i])
    end
    data.quality = compoundQuality
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CombatPlanMergeRequest, MessageTypeProto_pb.CombatPlanMergeResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = CombatPlanProto_pb.CombatPlanMergeResponse()
        msg:ParseFromString(data)

        if func then
            func(msg)
        end
    end)
end

--> 请求相关数据
function NetManager.CombatPlanReBuildNumRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.COMBATPLAN_EXP_REBUILDNUM_REQUEST, MessageTypeProto_pb.COMBATPLAN_EXP_REBUILDNUM_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = CombatPlanProto_pb.CombatPlanLuckyReBuildNumResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--> 阿拉曼战役
--> 请求main数据
function NetManager.AlameinBattleStageDataRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ALAMEIN_WAR_STAGE_DATA_REQUEST, MessageTypeProto_pb.ALAMEIN_WAR_STAGE_DATA_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = AlameinWarProto_pb.AlameinBattleStageDataResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--> 领取箱子
function NetManager.AlameinBattleBoxGetRequest(chapter, id, func)
    local data = AlameinWarProto_pb.AlameinBattleBoxGetRequest()
    data.chapter = chapter
    data.id = id
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ALAMEIN_WAR_BOX_GET_REQUEST, MessageTypeProto_pb.ALAMEIN_WAR_BOX_GET_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = AlameinWarProto_pb.AlameinBattleBoxGetResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 挑战次数购买
function NetManager.AlameinBattleChallengeTimesRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ALAMEIN_WAR_CHALLENGE_BUY_REQUEST, MessageTypeProto_pb.ALAMEIN_WAR_CHALLENGE_BUY_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = AlameinWarProto_pb.AlameinBattleChallengeTimesResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--> 扫荡
function NetManager.AlameinBattleSweepRequest(cfgId, func)
    local data = AlameinWarProto_pb.AlameinBattleSweepRequest()
    data.cfgId = cfgId
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ALAMEIN_WAR_SWEEP_REQUEST, MessageTypeProto_pb.ALAMEIN_WAR_SWEEP_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = AlameinWarProto_pb.AlameinBattleSweepResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

-------------------------------------主角-------------------------------------
-- 获取主角信息
function NetManager.MotherShipInfoRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIP_INFO_REQUEST, MessageTypeProto_pb.MOTHERSHIP_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MotherShipProto_pb.MotherShipInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 研发速度升级
function NetManager.MotherShipResearchUplevelRequest(tankIds, func)
    local data = MotherShipProto_pb.MotherShipResearchUplevelRequest()
    for i = 1, #tankIds do
        data.consumeMaterial.heroId:append(tankIds[i])
    end
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIPRESEARCH_UPLEVEL_REQUEST, MessageTypeProto_pb.MOTHERSHIPRESEARCH_UPLEVEL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MotherShipProto_pb.MotherShipInfoResponse()
        msg:ParseFromString(data)
        if msg.drop then
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
        end
        if func then
            func(msg)
        end
    end)
end

-- 开始研发 0：普通，1：特权
function NetManager.MotherShipResearchStartbuildRequest(bluePrintId, privilege, func)
    local data = MotherShipProto_pb.MotherShipResearchStartbuildRequest()
    data.bluePrintId = bluePrintId
    data.privilege = privilege
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIPRESEARCH_STARTBUILD_REQUEST, MessageTypeProto_pb.MOTHERSHIPRESEARCH_STARTBUILD_RESPONSE, msg, function(buffer)
        if func then
            func(msg)
        end
    end)
end

-- 研发加速 0：普通，1：特权
function NetManager.MotherShipResearchSpeedupRequest(researchPlusId, privilege, autoBuy, func)
    local data = MotherShipProto_pb.MotherShipResearchSpeedupRequest()
    data.researchPlusId = researchPlusId
    data.privilege = privilege
    data.autoBuy = autoBuy  --< 勾选 传 1
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIPRESEARCH_SPEEDUP_REQUEST, MessageTypeProto_pb.MOTHERSHIPRESEARCH_SPEEDUP_RESPONSE, msg, function(buffer)
        if func then
            func(msg)
        end
    end)
end

-- 结束研发 0：普通，1：特权
function NetManager.MotherShipResearchEndbuildRequest(privilege, func)
    local data = MotherShipProto_pb.MotherShipResearchEndbuildRequest()
    data.privilege = privilege
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIPRESEARCH_ENDBUILD_REQUEST, MessageTypeProto_pb.MOTHERSHIPRESEARCH_ENDBUILD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MotherShipProto_pb.MotherShipResearchEndbuildResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

-- 获取主角所有技能
function NetManager.MotherShipPlanGetAllRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIPPALN_GETALL_REQUEST, MessageTypeProto_pb.MOTHERSHIPPALN_GETALL_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MotherShipProto_pb.MotherShipPlanGetAllReponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 主角升级
function NetManager.MotherShipUplevelRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIP_UPLEVEL_REQUEST, MessageTypeProto_pb.MOTHERSHIP_UPLEVEL_RESPONSE, nil, function(buffer)
        if func then
            func()
        end
    end)
end

-- 装备技能
function NetManager.MotherShipWearRequest(motherShipPlanId, position, func)
    local data = MotherShipProto_pb.MotherShipWearRequest()
    data.motherShipPlanId = motherShipPlanId
    data.position = position
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIP_WEAR_REQUEST, MessageTypeProto_pb.MOTHERSHIP_WEAR_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

-- 技能替换
function NetManager.MotherShipReplaceRequest(posInfo, func)
    local data = MotherShipProto_pb.MotherShipReplaceRequest()
    for i = 1, #posInfo do
        local info = data.posInfo:add()
        info.motherShipPlanId = posInfo[i].id
        info.position = posInfo[i].pos
    end
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIP_REPLACE_REQUEST, MessageTypeProto_pb.MOTHERSHIP_REPLACE_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

-- 卸下技能
function NetManager.MotherShipUnloadRequest(motherShipPlanId, position, func)
    local data = MotherShipProto_pb.MotherShipUnloadRequest()
    data.motherShipPlanId = motherShipPlanId
    data.position = position
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIP_UNLOAD_REQUEST, MessageTypeProto_pb.MOTHERSHIP_UNLOAD_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

-- 技能升级
function NetManager.MotherShipPlanUpStarRequest(motherShipPlanId, func)
    local data = MotherShipProto_pb.MotherShipPlanUpStarRequest()
    data.motherShipPlanId = motherShipPlanId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIPPALN_UPSTAR_REQUEST, MessageTypeProto_pb.MOTHERSHIPPALN_UPSTAR_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

-- 技能分解
function NetManager.MotherShipPlanSellRequest(motherShipPlanId, num, func)
    local data = MotherShipProto_pb.MotherShipPlanSellRequest()
    data.motherShipCfgId = motherShipPlanId
    data.num = num
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIPPALN_SELL_REQUEST, MessageTypeProto_pb.MOTHERSHIPPALN_SELL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MotherShipProto_pb.MotherShipPlanSellResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--基因图鉴
function NetManager.MotherShipBookSetRequest(func)
    local data = MotherShipProto_pb.MotherShipBookSetRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MOTHERSHIPR_BOOK_SET_REQUEST, MessageTypeProto_pb.MOTHERSHIPR_BOOK_SET_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MotherShipProto_pb.MotherShipBookSetResponse()
        msg:ParseFromString(data)
        AircraftCarrierManager.SetGeneAtlas(msg)
        if func then
            func(msg)
        end
    end)
end
-------------------------------------End-------------------------------------

--> 部件
--> 解锁
function NetManager.AdjustUnLockRequest(heroServiceId, position, serviceIdsCost, func)
    local data = HeroInfoProto_pb.AdjustUnLockRequest()
    data.heroServiceId = heroServiceId
    data.position = position
    for i = 1, #serviceIdsCost do
        data.serviceIdsCost:append(serviceIdsCost[i])
    end
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADJUST_UNLOCK_REQUEST, MessageTypeProto_pb.ADJUST_UNLOCK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.AdjustUnLockListResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--> 解锁列表
function NetManager.AdjustUnLockListRequest(heroServiceId, func)
    local data = HeroInfoProto_pb.AdjustUnLockListRequest()
    data.heroServiceId = heroServiceId
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADJUST_UNLOCK_LIST_REQUEST, MessageTypeProto_pb.ADJUST_UNLOCK_LIST_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.AdjustUnLockListResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--> 调教
function NetManager.AdjustLevelUpRequest(heroServiceId, position, func)
    local data = HeroInfoProto_pb.AdjustLevelUpRequest()
    data.heroServiceId = heroServiceId
    data.position = position
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADJUST_LEVEL_UP_REQUEST, MessageTypeProto_pb.ADJUST_LEVEL_UP_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

--> 重置
function NetManager.AdjustResetRequest(heroServiceId, position, func)
    local data = HeroInfoProto_pb.AdjustResetRequest()
    data.heroServiceId = heroServiceId
    data.position = position
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADJUST_RESET_REQUEST, MessageTypeProto_pb.ADJUST_RESET_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.AdjustResetResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--> 特性 天赋
--> 激活
function NetManager.InnateSkillActivateRequest(heroServiceId, position, skillId, func)
    local data = HeroInfoProto_pb.InnateSkillActivateRequest()
    data.heroServiceId = heroServiceId
    data.position = position
    data.skillId = skillId
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.INNATE_SKILL_ACTIVATE_REQUEST, MessageTypeProto_pb.INNATE_SKILL_ACTIVATE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.InnateSkillActivateResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--> ********************************************************************************************************************************************************

--公会副本请求当前章节信息
function this.GetGuildChallengeInfoRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_GUILD_CHALLENGE_INFO_REQUEST, MessageTypeProto_pb.GET_GUILD_CHALLENGE_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetGuildChallengeInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--公会副本战斗
function this.GuildChallengeRequest(bossId,type,func)--0为挑战 1为扫荡
    local data = Family_pb.GuildChallengeRequest()
    data.bossId = bossId
    data.type = type
    local msg = data:SerializeToString()
    -- if not GuildTranscriptManager.GetCurBattleIsSkillBoss() or (GuildTranscriptManager.GetCurBattleIsSkillBoss() and curPassBossId[bossId]) then--因为此时的indcaton RESPONSE  回来的还早  所以加特殊判断操作  
        PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BATTLENUM, 1)--更新特权
    -- end
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GUILD_CHALLENGE_REQUEST, MessageTypeProto_pb.GUILD_CHALLENGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GuildChallengeResponse()
        msg:ParseFromString(data)
        local curPassBossId = GuildTranscriptManager.GetRefreshedBoss()
        if func then
            func(msg)
        end
    end)
end
--公会副本购买 buff
function this.GuildChallengeBuyBuffRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GUILD_CHALLENGE_BUY_BUFF_REQUEST, MessageTypeProto_pb.GUILD_CHALLENGE_BUY_BUFF_RESPONSE, nil, function(buffer)
        if func then
            func(msg)
        end
    end)
end
--公会副本发送号令
function this.GuildChallengeMessageResponse(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GUILD_CHALLENGE_SEND_MESSAGE_REQUEST, MessageTypeProto_pb.GUILD_CHALLENGE_SEND_MESSAGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GuildChallengeMessageResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

function this.LevelPlayerData (headId,func)
    local data=FightInfoProto_pb.GameLevelFightRePlayResponse
    data.fightId=headId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GameLevelFightRePlayRequest,MessageTypeProto_pb.GameLevelFightRePlayResponse,msg,function (buffer)
        local data=buffer:DataByte()
        local msg=FightInfoProto_pb.GameLevelFightRePlayRequest()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--请求卡库数据
function this.HeroInfoRequest(_index, func)
    local data = HeroInfoProto_pb.GetHeroListInfoRequest()
    data.index = _index
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_HEROINFO_REQUEST, MessageTypeProto_pb.GET_HEROINFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.GetHeroListInfoResponse()
        msg:ParseFromString(data)
        -- LogError(#msg.heroList)
        HeroManager.InitHeroData(msg.heroList)
        if msg.isSendFinish then
            if func then
                func(msg)
            end
        else
            _index = _index + #msg.heroList
            this.HeroInfoRequest(_index, func)
        end
    end)
end

--请求刷新卡库
function this.DrawHeroRequest(func)
    local data = HeroInfoProto_pb.DrawHeroRequest()
    data.type = 1222
    data.str = GetLanguageStrById(11426)
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DRAW_HERO_REQUEST, MessageTypeProto_pb.DRAW_HERO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.DrawHeroResponse()
        msg:ParseFromString(data)
        --HeroManager.data = msg.player
        if func then
            func(msg)
        end
    end)
end

--请求地图战斗，必须在地图中时请求
function this.MapFightInfoRequest(func)
    local data = FightInfoProto_pb.FightStartRequest()
    data.fightType = 1
    data.type = 2
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FIGHT_START_REQUEST, MessageTypeProto_pb.FIGHT_START_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.FightStartResponse()
        msg:ParseFromString(data)

        if func then
            func(msg)
        end
    end)
end

--请求地图战斗结果，必须在地图中时请求
function this.MapFightResultRequest(monsterGroupId, frames, fightId, fightType, _result, func)
    local data = FightInfoProto_pb.FightEndRequest()
    -- 这玩意一直是个常数
    data.monsterGroupId = 10000
    data.frames = frames
    -- if fightId and fightType == 6 then
    --     data.fightId = fightId
    -- end
    if fightId then
        data.fightId = fightId
    end
    data.type = fightType
    data.useTime = BattleLogic.GetMoveTimes()
    data.teamId = FormationManager.curFormationIndex
    
    -- 这个字段用于退出按钮
    if monsterGroupId == 1 then
        data.dropout = monsterGroupId
    end
    -- 服务器 无参数为-2  -1 异常 0 输 1 赢
    if _result == nil then _result = -2 end
    -- 校验战斗结果
    data.result =_result

    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FIGHT_END_REQUEST, MessageTypeProto_pb.FIGHT_END_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.FightEndResponse()
        msg:ParseFromString(data)

        if func then
            func(msg)
        end
    end)
end

--请求地图数据
function this.MapInfoRequest(mapModeId, func, mapType)
    local data = MapInfoProto_pb.MapEnterRequest()
    data.mapId = mapModeId
    if mapType then
        data.mapType = mapType
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_ENTER_REQUEST, MessageTypeProto_pb.MAP_ENTER_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapEnterResponse()
        msg:ParseFromString(data)
        local heros = msg.infos
        if MapManager.curCarbonType ~= CarBonTypeId.TRIAL then
            table.sort(heros,function (a,b)
                return a.position < b.position
            end)
        end
        MapManager.trialHeroInfo = heros 
        if msg.killCount then
            MapTrialManager.killCount = msg.killCount
        end
        if msg.essenceValue then
            MapTrialManager.powerValue = msg.essenceValue
        end
        -- local heros = msg.infos
        -- if heros then
        --     table.sort(heros,function (a,b)
        --         return a.position < b.position
        --     end)
        -- end
        -- MapManager.trialHeroInfo = heros 
        -- MapTrialManager.killCount=msg.killCount
        -- MapTrialManager.powerValue = msg.essenceValue
        MapManager.curMapId = msg.mapId
        if msg.curTower then
            MapTrialManager.curTowerLevel = msg.curTower
        end
        if msg.bombUsed then
            MapTrialManager.bombUsed = msg.bombUsed
        end
        MapManager.mapPointList = {}
        Timer.New(function()
            -- 刷新数据
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
        end, 1):Start()
        EndLessMapManager.PointNoteDataList = {}
        MapManager.InitData(msg)
        --SubmitExtraData({ type = SDKSubMitType.TYPE_ENTER_COPY })
        if msg.exploreDetail then
            MapManager.InitAllMapProgressData(msg.exploreDetail)--更新当前地图探索度
        end
        if func then
            func(msg)
        end
        -- 请求进图后
        MapManager.isInMap = true
        MapManager.Mapping = true
    end)
end
--> 获取远征列表地图攻略开启状态
function this.MapInfoListRequest( func)
    -- 
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ENDLESS_MAPINFO_REQUEST, MessageTypeProto_pb.ENDLESS_MAPINFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.EndlessMapInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
function this.MapClearRequest(mapid,mapType, func)
    -- Log(GetLanguageStrById(11427) .. mapModeId)
    local data = MapInfoProto_pb.MapBackOutRequest()
    data.mapId=mapid
    data.mapType=mapType
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_BACKOUT_REQUEST, MessageTypeProto_pb.MAP_BACKOUT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapBackOutResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--> 用于拉模块更新
function this.MapInfoRequestOnlyCell(mapModeId, func,type)
    local data = MapInfoProto_pb.MapEnterRequest()
    data.mapId = mapModeId
    if type then
        data.mapType=type
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_ENTER_REQUEST, MessageTypeProto_pb.MAP_ENTER_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapEnterResponse()
        msg:ParseFromString(data)

        this.mapPointList = {}
        for i=1, #msg.mapList do
            local cell = msg.mapList[i]
            this.mapPointList[cell.cellId] = cell.pointId  -- cell.cellId == Pos, Pos作为Key
        end

        if func then
            func()
        end
    end)
end

--请求地图离开
function this.MapOutRequest(outType, func, nextMapId)
    local data = MapInfoProto_pb.MapOutRequest()
    data.curXY = MapManager.curPos
    data.mapId = MapManager.curMapId
    data.outType = outType

    -- 无尽副本使用
    local distMapId = 0
    if not nextMapId or nextMapId == 0 then
        distMapId = 0
    else
        distMapId = nextMapId
    end
    data.targetMapId = distMapId
    for i = 1, #MapManager.stepList do
        --将当前探索步骤传给后端同步校验
        data.cells:append(MapManager.stepList[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_OUT_REQUEST, MessageTypeProto_pb.MAP_OUT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapOutResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
        MapManager.stepList = {} --收到回调后，清空当前探索步骤
        MapManager.pointAtkPower = {}
        PlayerManager.curMapId = 0
        MapManager.curMapId = 0
        MapManager.isInMap = false
        MapTrialManager.SetBossState(0)
    end)
end

-- 请求开始探索副本地图
function this.CarbonMissionStartRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_START_EXPLORE_REQUEST, MessageTypeProto_pb.MAP_START_EXPLORE_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapStartExploreResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end

    end)
end

--请求更新事件
function this.EventUpdateRequest(eventId, optionId, func)
    local data = MapInfoProto_pb.EventUpdateRequest()
    data.eventId = eventId
    data.optionId = optionId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EVENT_UPDATE_REQUEST, MessageTypeProto_pb.EVENT_UPDATE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.EventUpdateResponse()
        msg:ParseFromString(data)
        OptionBehaviourManager.UpdateEventPoint(msg, optionId, func)
    end)
end

--初始化获取所有地图探索度
--function this.GetMapAccomplishRequest(func)
--    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ALL_MAP_ACCOMPLISH_REQUEST, MessageTypeProto_pb.GET_ALL_MAP_ACCOMPLISH_RESPONSE, nil, function (buffer)
--        local data = buffer:DataByte()
--        local msg = MapInfoProto_pb.GetMapAccomplishResponse()
--        msg:ParseFromString(data)
--        MapManager.InitAllMapPgData()
--        for i = 1, #msg.mapAccomplishInfo do
--            MapManager.InitAllMapProgressData(msg.mapAccomplishInfo[i])
--        end
--        if func then
--            func(msg)
--        end
--    end)
--end
--领取地图探索度箱子奖励
--function this.GetTakeMapBoxRequest(_mapId,_boxWeight, func)
--    local data = MapInfoProto_pb.TakeMapBoxRequest()
--    data.mapId = _mapId
--    data.boxWeight = _boxWeight
--    local msg = data:SerializeToString()
--    Network:SendMessageWithCallBack(MessageTypeProto_pb.TAKE_MAP_MISSION_BOX_REQUEST, MessageTypeProto_pb.TAKE_MAP_MISSION_BOX_RESPONSE, msg, function(buffer)
--        local data = buffer:DataByte()
--        local msg = MapInfoProto_pb.TakeMapBoxResponse()
--        msg:ParseFromString(data)
--        if func then
--            func(msg.drop)
--        end
--    end)
--end
--请求奖励领取
function this.GetActivityRewardRequest(missionId, activityId, func)
    local data = PlayerInfoProto_pb.TakeActivityRewardRequest()
    data.missionId = missionId
    data.activityId = activityId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TAKE_ACTIVITY_REWARD_REQUEST, MessageTypeProto_pb.TAKE_ACTIVITY_REWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.TakeActivityRewardResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg.drop)
        end
    end)
end

--请求全部奖励领取
function this.GetActivityRewardAllRequest(activityId, func)
    local data = PlayerInfoProto_pb.TakeActivityRewardAllRequest()
    data.activityId = activityId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TAKE_ACTIVITY_REWARD_ALL_REQUEST, MessageTypeProto_pb.TAKE_ACTIVITY_REWARD_ALL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.TakeActivityRewardAllResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--请求领取任务奖励
function this.TakeMissionRewardRequest(type, taskId, func)
    local data = PlayerInfoProto_pb.TakeMissionRewardRequest()
    data.type = type
    data.missionId = taskId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TAKE_MISSION_REWARD_REQUEST, MessageTypeProto_pb.TAKE_MISSION_REWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.TakeMissionRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--请求领取全部任务奖励
function this.TakeMissionAllRewardRequest(type, func)
    local data = PlayerInfoProto_pb.TakeMissionRewardAllRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TAKE_MISSION_REWARD_ALL_REQUEST, MessageTypeProto_pb.TAKE_MISSION_REWARD_ALL_RESPONSE , msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.TakeMissionRewardAllResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--手札任务一键领取
function this.TakeLetterMissionRewardAllRequest(func)
    local datas = PlayerInfoProto_pb.TakeLetterMissionRewardAllRequest()
    local msg = datas:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TAKE_LETTER_MISSION_REWARD_ALL_REQUEST, MessageTypeProto_pb.TAKE_LETTER_MISSION_REWARD_ALL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.TakeLetterMissionRewardAllResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--请求活动数据
function this.GetActivityAllRewardRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ALL_ACTIVITY_REQUEST, MessageTypeProto_pb.GET_ALL_ACTIVITY_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetAllActivityResponse()
        msg:ParseFromString(data)
        
        ActivityGiftManager.InitActivityData()
        ActivityGiftManager.InitActivityServerData(msg)
        SevenDayCarnivalManager.InitSevenDayScore()
        DailyRechargeManager.InitRechargeStatus()
        GrowthManualManager.UpdateTreasureState()
        ActivityGiftManager.InitBoxPoolInfo()
        if func then
            func(msg)
        end
    end)
end

--请求物品数据
function this.ItemInfoRequest(_index, func)
    local data = PlayerInfoProto_pb.GetItemInfoRequest()
    data.index = _index
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ITEMINFO_REQUEST, MessageTypeProto_pb.GET_ITEMINFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetItemInfoResponse()
        msg:ParseFromString(data)
        BagManager.InitBagData(msg.itemlist)
        if msg.isSendFinish then
            if func then
                func(msg)
            end
            -- 货币数据
            -- ThinkingAnalyticsManager.SetSuperProperties({
            --     coins_amount = BagManager.GetItemCountById(14),
            --     diamond_amount = BagManager.GetItemCountById(16),
            -- })
        else
            _index = _index + #msg.itemlist
            this.ItemInfoRequest(_index, func)
        end
    end)
end
--请求兵棋骰子刷新时间数据
function this.DiceInfoRequest(_index, func)
    local data = MapInfoProto_pb.JourneyNextFlushTimeRequest()
    data.typeId = _index
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.JOURNEY_NEXTFLUSHTIME_REQUEST, MessageTypeProto_pb.JOURNEY_NEXTFLUSHTIME_RESPONSE, msg, function(buffer)
        
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.JourneyNextFlushTimeResponse()
        msg:ParseFromString(data)
        BagManager.GoDiceBackData(msg)
        if func then
            func(msg)
        end
    end)
end

--请求所有装备数据
function this.AllEquipRequest(_index, func)
    if func then
        func()
    end
    -- local data = HeroInfoProto_pb.GetAllEquipRequest()
    -- data.index = _index
    -- data.type = 1
    -- local msg = data:SerializeToString()
    -- Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ALL_EQUIP_REQUEST, MessageTypeProto_pb.GET_ALL_EQUIP_RESPONSE, msg, function(buffer)
    --     local data = buffer:DataByte()
    --     local msg = HeroInfoProto_pb.GetAllEquipResponse()
    --     msg:ParseFromString(data)
    --     EquipManager.InitEquipData(msg.equip)
    --     if msg.isSendFinish then
    --         if func then
    --             func(msg)
    --         end
    --     else
    --         _index = _index + #msg.equip
    --         this.AllEquipRequest(_index, func)
    --     end
    -- end)
end



--请求所有宝物数据
function this.AllEquipTreasureRequest(_index, func)
    local data = HeroInfoProto_pb.GetAllEquipRequest()
    data.index = _index
    data.type = 4
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ALL_EQUIP_REQUEST, MessageTypeProto_pb.GET_ALL_EQUIP_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.GetAllEquipResponse()
        msg:ParseFromString(data)
        EquipTreasureManager.InitAllEquipTreasure(msg.equip)
        if msg.isSendFinish then
            if func then
                func(msg)
            end
        else
            _index = _index + #msg.equip
            this.AllEquipTreasureRequest(_index, func)
        end
    end)
end
--请求穿装备
function this.EquipWearRequest(_heroId, _equipIds,_type, func)
    local data = HeroInfoProto_pb.EquipWearRequest()
    data.heroId = _heroId
    data.type =_type
    for i = 1, #_equipIds do
        data.equipId:append(_equipIds[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EQUIP_WEAR_REQUEST, MessageTypeProto_pb.EQUIP_WEAR_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        -- local msg = HeroInfoProto_pb.GetAllEquipResponse()
        -- msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--请求脱装备
function this.EquipUnLoadOptRequest(_heroId, _equipIds, _type,func)
    local data = HeroInfoProto_pb.EquipUnLoadOptRequest()
    data.heroId = _heroId
    data.type = _type
    for i = 1, #_equipIds do
        data.equipIds:append(tostring(_equipIds[i]))
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EQUIP_UNLOAD_OPT_REQUEST, MessageTypeProto_pb.EQUIP_UNLOAD_OPT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        -- local msg = HeroInfoProto_pb.GetAllEquipResponse()
        -- msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--请求宝物强化/精炼
function this.EquipTreasureBuildRequest(_IdDyn, _type,_mats,func)
    local data = PlayerInfoProto_pb.JewelBuildRequest()
    data.id = _IdDyn
    data.type = _type
    if _mats then
        for i = 1, #_mats do
            data.item:append(_mats[i])
        end
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.JEWEL_BUILD_REQUEST, MessageTypeProto_pb.JEWEL_BUILD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.GetAllEquipResponse()
        msg:ParseFromString(data)
        -- EquipTreasureManager.ChangeTreasureLv(_IdDyn,_type)
        -- local equip = EquipTreasureManager.GetSingleTreasureByIdDyn(_idDyn)
        -- UIManager.OpenPanel(UIName.EquipTreasureStrongPopup,equip,_type)
        if func then
            func(msg)
        end
    end)
end


--请求装备上锁或者解锁
function this.EquipLockRequest(_equipIds, _type, func)
    local data = PlayerInfoProto_pb.LockEquip()
    data.type = _type--1：锁定操作 2：解锁操作
    for i = 1, #_equipIds do
        data.id:append(_equipIds[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EQUIP_LOCK_REQUEST, MessageTypeProto_pb.EQUIP_LOCK_RESPONSE, msg, function(buffer)
        --local data = buffer:DataByte()
        --local msg = HeroInfoProto_pb.GetAllEquipResponse()
        --msg:ParseFromString(data)
        EquipManager.SetEquipLockState(_equipIds, 2 - _type)--1：被锁定 0:未锁定
        if func then
            func()
        end
    end)
end
--请求抽卡
function this.RecruitRequest(type, func)
    local data = HeroInfoProto_pb.HeroRandRequest()
    data.type = type
    local msg = data:SerializeToString()

    Network:SendMessageWithCallBack(MessageTypeProto_pb.HERO_RAND_REQQUEST, MessageTypeProto_pb.HERO_RAND_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroRandResponse()
        msg:ParseFromString(data)

        for i = 1, #msg.drop.Hero do
            local singHeroData = msg.drop.Hero[i]
            HeroManager.UpdateHeroDatas(singHeroData,true)
        end
        if msg.dailyGemRandomTimes then
            PrivilegeManager.dailyGemRandomTimes = msg.dailyGemRandomTimes --限时招募次数
        end
        if func then
            func(msg)
        end
    end)
end

--请求地图单点
function this.MapUpdateEvent(triggerXY, func)
    local data = MapInfoProto_pb.MapUpdateRequest()
    data.curXY = MapManager.curPos
    data.triggerXY = triggerXY
    for i = 1, #MapManager.stepList do
        --将当前探索步骤传给后端同步校验
        data.cells:append(MapManager.stepList[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_UDPATE_REQUEST, MessageTypeProto_pb.MAP_UDPATE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapUpdateResponse()
        msg:ParseFromString(data)
        --
        MapManager.stepList = {} --收到回调后，清空当前探索步骤
        --  碰到事件点同步一次时间
        --
        local durationTime = MapManager.totalTime - msg.leftTime
        PlayerManager.startTime = PlayerManager.serverTime - durationTime

        if func then
            func(msg.eventId)
        end
    end)
end

--请求地图单点
function this.MapUpdateEvent2(triggerXY, func)
    local data = MapInfoProto_pb.MapUpdate2Request()
    data.curXY = triggerXY
    -- local data = MapInfoProto_pb.GetTrialBoxRewardRequest()
    -- data.type = 0
    -- data.curClickXY = triggerXY
    data.triggerXY = triggerXY
    MapManager.curTriggerPos=triggerXY
    -- for i = 1, #MapManager.stepList do
    --     --将当前探索步骤传给后端同步校验
    --     data.cells:append(MapManager.stepList[i])
    -- end
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_UDPATE_REQUEST, MessageTypeProto_pb.MAP_UDPATE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapUpdate2Response()
        msg:ParseFromString(data)
        
        --
        MapManager.stepList = {} --收到回调后，清空当前探索步骤
        --  碰到事件点同步一次时间
        --
        local durationTime = MapManager.totalTime - msg.leftTime
        PlayerManager.startTime = PlayerManager.serverTime - durationTime

        if func then
            func(msg.eventId)
        end
    end)
end

-- 请求快速战斗
function this.QuickFightRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_FAST_FIGHT_REQUEST, MessageTypeProto_pb.MAP_FAST_FIGHT_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.FastFightResponse()
        msg:ParseFromString(data)
        LogYellow("QuickFightRequest")
        MapTrialManager.cell=msg.cell
        if func then
            func(msg)
        end
    end)
end

--请求战斗回放
-- type : 1 竞技场  2 巅峰赛  3 公会boss  4 三强争霸
function this.FightRePlayRequest(type, fightId, func,rank,pos)
    local data = FightInfoProto_pb.FightRePlayRequest()
    data.type = type
    data.fightId = fightId
    if rank then
        data.rank = rank
    end
    if pos then
        data.pos = pos
    end
    
    --TODO检查传参是否正确 和服务器确定
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.VIEW_FIGHTREPLAY_REQUEST, MessageTypeProto_pb.VIEW_FIGHTREPLAY_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.FightRePlayResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--请求
function this.GMEvent(GMstr, func)
    local data = CommonProto_pb.GMCommand()
    data.command = GMstr
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GM_REQUEST, MessageTypeProto_pb.GM_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = CommonProto_pb.GmResponse()
        msg:ParseFromString(data)
        if msg.drop then
            if #msg.drop.itemlist > 0 or #msg.drop.equipId > 0 or #msg.drop.Hero > 0 or #msg.drop.plan > 0 or #msg.drop.motherShipPlan > 0 or #msg.drop.medal > 0 then
                BagManager.GMCallBackData(msg.drop)
            end
        end
        if func then
            func(msg)
        end
    end)
end

--请求英雄升级
function this.HeroLvUpEvent(heroId, upLv,oldLv, func)
    local data = HeroInfoProto_pb.UpHeroLevelRequest()
    --data.cells = cell
    
    data.heroId = heroId
    data.targetLevel = upLv
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.UP_HERO_LEVEL_REQUEST, MessageTypeProto_pb.UP_HERO_LEVEL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.UpHeroLevelResponse()
        msg:ParseFromString(data)
        if oldLv < 20 and msg.targetLevel >= 20 then
            --远征初始化血量
            ExpeditionManager.InitHeroHpValue(heroId)
        end
        if func then
            func(msg)
        end
    end)
end
--请求英雄升星
function this.HeroUpStarEvent(heroId, consumeMaterials, func)
    local data = HeroInfoProto_pb.UpHeroStarRequest()
    data.heroId = heroId
    data.type = 1
    for i = 1, #consumeMaterials do
        local c = data.consumeMaterials:add()
        c.position = i
        for j = 1, #consumeMaterials[i] do
            c.heroIds:append(consumeMaterials[i][j])
        end
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.UP_HERO_STAR_REQUEST, MessageTypeProto_pb.UP_HERO_STAR_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = CommonProto_pb.Drop()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--请求更新名将数据
function this.GetGeneralData(func,itemdata)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetAllGeneralInfoRequest, MessageTypeProto_pb.GetAllGeneralInfoResponse, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = GeneralProto_pb.GetAllGeneralInfoResponse()
        msg:ParseFromString(data)
        GeneralManager.SetAllGeneralDatas(msg)
        if func then
            func(msg,itemdata)
        end
    end)
end
--请求名将激活数据
function this.GetGeneralActiveData(id,tankID,func)
    local data = GeneralProto_pb.GetGeneralActiveRequest()
    data.generalId = id
    for i = 1, #tankID do
        data.tankId:append(tankID[i])
    end
    local msg=data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetGeneralActiveRequest, MessageTypeProto_pb.GetGeneralActiveResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = GeneralProto_pb.GetGeneralActiveResponse()
        msg:ParseFromString(data)
        for i = 1, #tankID do
            HeroManager.DeleteHeroDatas(tankID[i])
        end
        if func then
            this.GetGeneralData(func,msg)
        end
    end)
end
--请求名将升级数据
function this.GetGeneralLevelUpRequest(generalID,func)
    local data=GeneralProto_pb.GetGeneralLevelUpRequest()
    data.generalId=generalID
    local msg=data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetGeneralLevelUpRequest, MessageTypeProto_pb.GetGeneralLevelUpResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = GeneralProto_pb.GetGeneralLevelUpResponse()
        msg:ParseFromString(data)
        if func then
            this.GetGeneralData(func)
        end
    end)
end
--请求名将升阶数据
function this.GetGeneralRankUpRequest(generalID,func)
    local data = GeneralProto_pb.GetGeneralRankUpRequest()
    data.generalId = generalID
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetGeneralRankUpRequest, MessageTypeProto_pb.GetGeneralRankUpResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = GeneralProto_pb.GetGeneralRankUpResponse()
        msg:ParseFromString(data)
        if func then
            this.GetGeneralData(func)
        end
    end)
end
--请求更新新手引导记录
function this.SaveGuideDataRequest(type, id, func)
    local data = PlayerInfoProto_pb.SaveNewPlayerPointRequest()
    data.newPlayerGuidePoint.type = type
    data.newPlayerGuidePoint.id = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SAVE_NEW_PLAYER_GUIDE_POINT_REQUEST, MessageTypeProto_pb.SAVE_NEW_PLAYER_GUIDE_POINT_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
--请求图鉴开启
function this.GetHandBookHero(id, func)
    local data = PlayerInfoProto_pb.GetHandBookRewardRequest()
    data.handBookId = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetHandBookRewardRequest, MessageTypeProto_pb.GetHandBookRewardResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetHandBookRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--请求全部图鉴开启
function this.GetHandBookListHero(id, func)
    local data = PlayerInfoProto_pb.GetHandBookRewardOnekeyRequest()
    data.type=2
    data.citye = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetHandBookRewardOneKyeRequest, MessageTypeProto_pb.GetHandBookRewardOneKyeResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetHandBookRewardOnekeyResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--请求编队信息
function this.TeamInfoRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_TEAMPOS_INFO_REQUEST, MessageTypeProto_pb.GET_TEAMPOS_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.GetAllTeamPosResponse()
        msg:ParseFromString(data)
        
        FormationManager.UpdateFormation(msg)
        if func then
            func(msg)
        end
    end)
end
--请求背包上限信息
function this.BackpackLimitRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BACKPACK_LIMIT_COUNT_REQUEST, MessageTypeProto_pb.BACKPACK_LIMIT_COUNT_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.BackpackLimitCountResponse()
        msg:ParseFromString(data)
        
        --FormationManager.UpdateFormation(msg)
       --RoleListPanel:backLimit(msg)
        if func then
            func(msg)
        end

    end)

end

-- 请求称号信息
function this.chenghaoRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TITLE_LIST_QUERY_REQUEST, MessageTypeProto_pb.TITLE_LIST_QUERY_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.TitleListQueryResponse()
        msg:ParseFromString(data)
        PlayerManager.SetTitleList(msg.titleList)--设置称号列表
        if func then
            func(msg)
        end

    end)

end
--请求购买背包栏位
function this.BuyBackpackLimitRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BUY_BACKPACK_COUNT_REQUEST, MessageTypeProto_pb.BUY_BACKPACK_COUNT_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.BuyBackpackCountResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end

    end)

end

--保存编队信息
function this.TeamInfoSaveRequest(curFormation, func)

    local data = HeroInfoProto_pb.TeamposSaveRequest()
    data.TeamPosInfo.teamId = curFormation.teamId
    data.TeamPosInfo.formationId = curFormation.formationId
    --data.TeamPosInfo.teamName = curFormation.teamName
    for i = 1, #curFormation.teamHeroInfos do
        local teamInfo = data.TeamPosInfo.teamHeroInfos:add()
        teamInfo.heroId = curFormation.teamHeroInfos[i].heroId
        teamInfo.position = curFormation.teamHeroInfos[i].position
    end
    -- for i = 1, #curFormation.teamPokemonInfos do
    --     local teamPokemonInfo = data.TeamPosInfo.teamPokemonInfos:add()
    --     teamPokemonInfo.pokemonId = curFormation.teamPokemonInfos[i].pokemonId
    --     teamPokemonInfo.position = curFormation.teamPokemonInfos[i].position
    -- end
    data.TeamPosInfo.substitute = curFormation.substitute
    --> 支援id
    data.TeamPosInfo.supportId = curFormation.supportId
    --> 副官id
    data.TeamPosInfo.adjutantId = curFormation.adjutantId
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TEAM_POS_SAVE_REQUEST, MessageTypeProto_pb.TEAM_POS_SAVE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        if func then
            func(msg.pokemonInfo)
        end
    end)
end

--请求获取任务消息
function this.MissionInfoRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MISSION_GET_ALL_REQUEST, MessageTypeProto_pb.MISSION_GET_ALL_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MissionInfoProto_pb.MissionGetAllResponse()
        msg:ParseFromString(data)
        MissionManager.InitMissionInfo(msg)

        if func then
            func(msg)
        end
    end)
end

-- 请求开启任务信息
function this.MissionOpenRequest(missionId, func)
    local data = MissionInfoProto_pb.OpenMissionRequest()
    data.missionId = missionId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MISSION_OPEN_REQUEST, MessageTypeProto_pb.MISSION_OPEN_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()

        if func then
            func(msg)
        end
    end)
end

--请求获取异妖消息
function this.DiffMonsterRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ALL_POKEMON_REQUEST, MessageTypeProto_pb.GET_ALL_POKEMON_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.GetAllPokemonResponse()
        msg:ParseFromString(data)
        DiffMonsterManager.Init(msg.pokemonInfo)
        if func then
            func(msg)
        end
    end)
end

--请求异妖组件放置升级
function this.DemonCompUpRequest(diffMonId, compId, func)
    local data = HeroInfoProto_pb.PokenmonUpLevelRequest()
    data.pokemonId = diffMonId
    data.comonpentId = compId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.POKEMON_COMONPENT_LEVELUP_REQUEST, MessageTypeProto_pb.POKEMON_COMONPENT_LEVELUP_RESPONSE, msg, function(buffer)
        if func then
            func(msg)
        end
    end)
end

--请求异妖进阶
function this.DemonUpRequest(_id, func)
    local data = HeroInfoProto_pb.PokemonAdvancedRequest()
    data.pokemonId = _id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.POKEMON_ADVANCED_REQUEST, MessageTypeProto_pb.POKEMON_ADVANCED_RESPONSE, msg, function(buffer)
        if func then
            func(msg)
        end
    end)
end

--请求工坊信息
function this.GetWorkShopInfoRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_WORKSHOP_INFO_REQUEST, MessageTypeProto_pb.GET_WORKSHOP_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetWorkShopInfoResponse()
        msg:ParseFromString(data)
        WorkShopManager.InitWorkShopData(msg)
        if func then
            func(msg)
        end
    end)
end
--请求基础锻造
function this.GetWorkBaseRequest(_materialId, _nums, func)
    local data = PlayerInfoProto_pb.WorkShopFoundationRequest()
    data.materialId = _materialId
    data.nums = _nums
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORKSHOP_FOUNDATION_REQUEST, MessageTypeProto_pb.WORKSHOP_FOUNDATION_RESPONSE, msg, function(buffer)
        --local data = buffer:DataByte()
        --local msg = HeroInfoProto_pb.TakeMissionResponse()
        --msg:ParseFromString(data)
        if func then
            func()
        end
    end)
end
--请求装备锻造
function this.GetWorkShopEquipCreateRequest(_materialId, _runneIds, _nums, func)
    local data = PlayerInfoProto_pb.WorkShopEquipCreateRequest()
    data.equipTid = _materialId
    data.nums = _nums
    for i = 1, #_runneIds do
        data.runneIds:append(_runneIds[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORKSHOP_EQUIP_CREATE_REQUEST, MessageTypeProto_pb.WORKSHOP_EQUIP_CREATE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.WorkShopEquipCreateResponse()
        msg:ParseFromString(data)
        if msg.type == 1 then
            --工坊
            if #msg.drop.itemlist > 0 then
                --防具
                --for i = 1, #msg.drop.itemlist do
                --    BagManager.UpdateBagData(msg.drop.itemlist[i])
                --    if func then
                --        func(msg.drop.itemlist[i])
                --    end
                --end
            end
            if #msg.drop.equipId > 0 then
                --装备 --防具
                if #msg.drop.equipId <= 1 then
                    --工坊一个装备时 弹 装备工坊成功界面
                    for i = 1, #msg.drop.equipId do
                        EquipManager.UpdateEquipData(msg.drop.equipId[i])
                        if func then
                            func(msg.drop.equipId[i])
                        end
                    end
                else
                    --工坊多个装备时 弹 恭喜获得界面
                    if func then
                        func(msg.drop)
                    end
                end
            end
            if #msg.drop.Hero > 0 then

            end
        end
    end)
end
--请求装备重铸
function this.GetWorkShopEquipRebuildRequest(_equipId, _consumeEquipIds, func)
    local data = PlayerInfoProto_pb.WorkShopRebuildRequest()
    data.equipId = _equipId
    data.consumeEquipIds:append(_consumeEquipIds)
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORKSHOP_REBUILD_REQUEST, MessageTypeProto_pb.WORKSHOP_REBUILD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.WorkShopRebuildRespoonse()
        msg:ParseFromString(data)
        if func then
            func(msg.equip)
        end
    end)
end
--请求装备重铸二次确认
function this.GetWorkShopEquipRebuildSureRequest(_isSure, func)
    local data = PlayerInfoProto_pb.WorkShopRebuildConfirmRequest()
    data.state = _isSure
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORKSHOP_REBUILD_CONFIRM_REQUEST, MessageTypeProto_pb.WORKSHOP_REBUILD_CONFIRM_RESONSE, msg, function(buffer)
        if func then
            func(msg.equip)
        end
    end)
end
--请求工坊解锁蓝图
function this.GetWorkShopAvtiveLanTuRequest(_activiteId, _type, func)
    local data = PlayerInfoProto_pb.ActiviteWorkShopReqeust()
    data.type = _type
    data.activiteId = _activiteId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ACTIVITE_WORKSHOP_REQUEST, MessageTypeProto_pb.ACTIVITE_WORKSHOP_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
--请求工坊升级
function this.WorkShopLvUpRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORKSHOP_LEVELUP_REQUEST, MessageTypeProto_pb.WORKSHOP_LEVELUP_RESPONSE, nil, function(buffer)
        WorkShopManager.UpdataWorkShopLvAndExp()
        if func then
            func()
        end
    end)
end
--请求工坊天赋树升级
function this.WorkShopTreeLvUpRequest(treeId, upLv, func)
    local data = PlayerInfoProto_pb.WorkTechnologyLevelRequest()
    data.id = treeId
    data.targetLevel = upLv
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORKSHOP_TECHNOLOGY_LEVEL_REQUEST, MessageTypeProto_pb.WORKSHOP_TECHNOLOGY_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
--请求工坊天赋树重置
function this.WorkShopTreeResetRequest(professionId, func)
    local data = PlayerInfoProto_pb.WorkTechnologyResetRequest()
    data.professionId = professionId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORKSHOP_TECHNOLOGY_RESET_REQUEST, MessageTypeProto_pb.WORKSHOP_TECHNOLOGY_RESET_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.WorkTechnologyResetResponse()
        msg:ParseFromString(data)
        UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
        if func then
            func()
        end
    end)
end

----请求通关记录
function this.GetLevelInfoData(pokemonId,func)
    local data = FightInfoProto_pb.GameLevelFightRePlayRequest()
    data.fightId = pokemonId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GameLevelFightRePlayRequest, MessageTypeProto_pb.GameLevelFightRePlayResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.GameLevelFightRePlayResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
----请求冒险数据
--function this.GetAdventureInfoRequest(func)
--    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ADVENTURE_INFO_REQUEST, MessageTypeProto_pb.GET_ADVENTURE_INFO_RESPONSE, nil, function(buffer)
--        local data = buffer:DataByte()
--        local msg = FightInfoProto_pb.GetAdventureStateInfoResponse()
--        msg:ParseFromString(data)
--        AdventureManager.InitAdventureData(msg)
--        if func then
--            func(msg)
--        end
--    end)
--end
--
----请求冒险驻扎
--function this.AdventureStationRequest(pos, heroList, func)
--    local data = FightInfoProto_pb.AventureStationRequest()
--    data.position = pos
--    for i = 1, #heroList do
--        
--        data.heroIdList:append(heroList[i])
--    end
--    --print(pos, duration, heroList)
--    local msg = data:SerializeToString()
--    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_STATION_REQUEST, MessageTypeProto_pb.ADVENTURE_STATION_RESPONSE, msg, function(buffer)
--        
--        AdventureManager.RefreshAdventureData(pos, heroList)
--        if func then
--            func()
--        end
--    end)
--end
--
----请求冒险奖励
--function this.TakeAventureRewardRequest(pos, func)
--    local data = FightInfoProto_pb.TakeAventureRewardRequest()
--    data.position = pos
--    local msg = data:SerializeToString()
--    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_REWARD_REQUEST, MessageTypeProto_pb.ADVENTURE_REWARD_RESPONSE, msg, function(buffer)
--        local data = buffer:DataByte()
--        local msg = FightInfoProto_pb.TakeAventureRewardResponse()
--        msg:ParseFromString(data)
--        
--        AdventureManager.TakeAventureReward(msg.Drop, pos)
--        AdventureManager.RefreshAdventureData(pos)
--        if func then
--            func()
--        end
--    end)
--end
--请求所有邮件信息
function this.GetAllMailData(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ALL_MAIL_INFO_REQUEST, MessageTypeProto_pb.GET_ALL_MAIL_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetAllMailInfoResponse()
        msg:ParseFromString(data)
        -- 
        MailManager.InitMailDataList(msg.mialList)
        if func then
            func(msg.mialList)
        end
    end)
end
--请求读取邮件信息
function this.ReadSingleMailData(_mailId, func)
    local data = PlayerInfoProto_pb.MailReadRequest()
    data.mailId = _mailId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAIL_READ_REQUEST, MessageTypeProto_pb.MAIL_READ_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
--请求领取邮件信息
function this.GetSingleMailRewardData(_mailIds, func)
    local data = PlayerInfoProto_pb.TakeMailRequest()
    for i = 1, #_mailIds do
        data.mailIds:append(_mailIds[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAIL_TAKE_MAIL_ITEM_REQUEST, MessageTypeProto_pb.MAIL_TAKE_MAIL_ITEM_RESPONESE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.TakeMailResponse()
        msg:ParseFromString(data)
        if func then
            func(msg.drop)
        end
    end)
end
--请求删除邮件
function this.DelMailData(_mailIds, func)
    local data = PlayerInfoProto_pb.MailDelRequest()
    for i = 1, #_mailIds do

        data.mailId:append(_mailIds[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAIL_DELETE_REQUEST, MessageTypeProto_pb.MAIL_DELETE_RESPONSE, msg, function(buffer)
        --local data = buffer:DataByte()
        --local msg = PlayerInfoProto_pb.TakeMailResponse()
        --msg:ParseFromString(data)
        if func then
            func()
        end
    end)
end

--请求所有关卡信息
function this.GetAllFightDataRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ALL_LEVE_DIFFICULTT_REQUEST, MessageTypeProto_pb.GET_ALL_LEVE_DIFFICULTT_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.getAllLevelDifficultyInfosResponse()
        msg:ParseFromString(data)
        --FightManager.InitAllMapPgData(msg.levelDifficultyInfos)
        
        
        MapTrialManager.RefreshTrialInfo(msg.towerCopyInfo)
        CarbonManager.InitCarbonState(msg.mapInfos)
        CarbonManager.InitNormalState(msg.playedGenMapId)
        CarbonManager.InitCountDownProcess()
        CarbonManager.difficultyId = msg.difficultMapOptions
        CarbonManager.hasGetRewardCostStar = msg.starNum
        if func then
            func(msg.levelDifficultyInfos)
        end
    end)
end

--请求单个关卡战斗
function this.LevelStarFightDataRequest(_monsterGroupId, _fightId, func)            
    local data = FightInfoProto_pb.FightStartRequest()
    data.type = 6   
    data.fightId = _fightId 
    data.teamId = FormationManager.curFormationIndex
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FIGHT_START_REQUEST, MessageTypeProto_pb.FIGHT_START_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.FightStartResponse()
        msg:ParseFromString(data)        
        if func then
            func(msg)                       
        end
        -- LogError("msg isok")
        return 
    end)
    --LogError("need fresh")
    NetManager.InitFightPointLevelInfo()    
end

--请求单个关卡扫荡
function this.GetMopUpFightDataRequest(_type, _fightId, _num, _targetItemId, _targetItemNum, func)
    local data = FightInfoProto_pb.SweepRightRequest()
    data.type = _type
    data.fightId = _fightId
    data.num = _num
    data.targetItemId = _targetItemId
    data.targetItemNum = _targetItemNum
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SWEEP_RIGHT_REQUEST, MessageTypeProto_pb.SWEEP_RIGHT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.SweepRightResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--请求副本排行榜
function this.MapGetRankInfoRequest(_mapId, func)
    local data = MapInfoProto_pb.MapGetRankInfoRequest()
    data.mapId = _mapId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_GET_RANK_INFO_REQUEST, MessageTypeProto_pb.MAP_GET_RANK_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapGetRankInfoResponse()
        msg:ParseFromString(data)

        if func then
            func(msg.mapRankInfo)
        end
    end)
end
--请求副本扫荡
function this.MapSweepRequest(_mapId, _sweepCount, func)
    local data = MapInfoProto_pb.MapSweepRequest()
    data.mapId = _mapId
    data.sweepCount = _sweepCount

    
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_SWEEP_REQUEST, MessageTypeProto_pb.MAP_SWEEP_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapSweepResponse()
        msg:ParseFromString(data)

        if func then
            func(msg)
        end
    end)
end
--请求道具 装备 分解
function this.UseAndPriceItemRequest(_type, _items, func)
    --_type  1:分解物品 2：分解装备3:分解妖灵师 4：分解法宝 5:分解魂印 6:自选宝箱
    local data = PlayerInfoProto_pb.UseAndPriceItemRequest()
    
    data.type = _type
    --data.itemId = _itemId
    if _type == 1 or _type == 0 then
        for i = 1, #_items do
            local itemData = data.items:add()
            itemData.itemId = _items[i].itemId
            itemData.itemNum = _items[i].itemNum
        end
    elseif _type == 2 then
        for i = 1, #_items do

            data.equipIds:append(tostring(_items[i]))
        end
    elseif _type == 3 then
        for i = 1, #_items do
            data.heroIds:append(_items[i])
        end
    elseif _type == 4 then
        for i = 1, #_items do
            data.equipIds:append(_items[i])
        end
    elseif _type == 5 then
        for i = 1, #_items do
            data.equipIds:append(_items[i])
        end
    elseif _type == 6 then
        data.itemId = _items[2]
        local itemData = data.items:add()
        itemData.itemId = _items[1]
        itemData.itemNum = _items[3]
    end

    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.USER_AND_PRICE_ITEM_REQUEST, MessageTypeProto_pb.USER_AND_PRICE_ITEM_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.UseAndPriceItemResponse()
        msg:ParseFromString(data)
        if func then
            func(msg.drop)
        end
    end)
end
--请求碎片合成
function this.HeroComposeRequest(_item, func)
    local data = HeroInfoProto_pb.HeroComposeRequest()
    data.item.itemId = _item.itemId
    data.item.itemNum = _item.itemNum
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HERO_COMPOSE_REQUEST, MessageTypeProto_pb.HERO_COMPOSE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroComposeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg.drop)
        end
    end)
end

--请求碎片一键合成
function this.HeroAllCompoundRequest(func)
    local data = HeroInfoProto_pb.HeroComposeRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HERO_COMPOSE_ALL_REQUEST, MessageTypeProto_pb.HERO_COMPOSE_ALL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroComposeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg.drop)
        end
    end)
end

--新手引导任意名字请求    0 全随机，1男，2女
function this.GetRandomNameRequest(sex, func)
    local data = CommonProto_pb.RandomRequest()
    data.sex = sex
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.RANDOMNAME_REQUEST, MessageTypeProto_pb.RANDOMNAME_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.RandomNameResponse()
        msg:ParseFromString(data)
        if func then
            func(msg.randomsurname, msg.randomname)
        end
    end)
end

--玩家名字更改请求
function this.ChangeUserNameRequest(type, name, teamPosId, sex, func)
    local data = PlayerInfoProto_pb.ReNameRequest()
    data.type = type
    data.name = name
    local _language= GetCurLanguage()
    -- LogError("lan".._language) 
    data.channelId = _language
    if teamPosId ~= nil then
        data.teamPosId = teamPosId
    end
    if sex then
        data.sex = sex
    else
        data.sex = ROLE_SEX.BOY
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.RENAME_REQUEST, MessageTypeProto_pb.RENAME_RESPONSE, msg, function()
        if func then
            func()
        end
    end)
end

-- 请求副本完成数据
function this.CarbonInfoRequest()
end

-- 请求获取竞技场基础数据
function this.RequestBaseArenaData(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ARENA_INFO_REQUEST, MessageTypeProto_pb.ARENA_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.GetArenaInfoResponse()
        msg:ParseFromString(data)
        ArenaManager.ReceiveBaseArenaData(msg)
        if func then
            func(msg)
        end
    end)
end

-- 请求获取竞技场排行数据
function this.RequestArenaRankData(page, func)
    local data = ArenaInfoProto_pb.GetArenaRankInfoRequest()
    data.page = page or 1
    local rqmsg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ARENA_RANK_REQUEST, MessageTypeProto_pb.ARENA_RANK_RESPONSE, rqmsg, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.GetArenaRankInfoResponse()
        msg:ParseFromString(data)
        ArenaManager.ReceiveArenaRankData(page, msg)
        RankingManager.ReceiveArenaData(page, msg)
        if func then
            func(page, msg)
        end
    end)
end

--请求秘盒当前周期和抽取次数请求
function this.GetSecretBoxInfoRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_SECRETBOX_REQUEST, MessageTypeProto_pb.GET_SECRETBOX_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetSecretBoxInfoResponse()
        msg:ParseFromString(data)
        SecretBoxManager.SeasonTime = msg.season
        SecretBoxManager.count = msg.count
        SecretBoxManager.GetDifferDemonsBoxData()
        if func then
            func(msg)
        end
    end)
end
--请求秘盒抽奖协议
function this.GetSecretBoxRewardRequest(type, func)
    local data = PlayerInfoProto_pb.SecretBoxRandomRequest()
    data.typeId = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SECRETBOX_RANDOM_REQUEST, MessageTypeProto_pb.SECRETBOX_RANDOM_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.SecretBoxRandomResponse()
        msg:ParseFromString(data)
        --Dump(msg.drop)

        if func then
            func(msg)
        end
    end)
end

-- 请求挑战
function this.RequestArenaChallenge(teamId, targetUid, isSkip, func)
    local data = ArenaInfoProto_pb.ArenaChallengeRequest()
    data.teamId = teamId
    data.challengeUid = targetUid
    data.skipFight = isSkip
    local rqmsg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ARENA_CHALLENGE_REQUEST, MessageTypeProto_pb.ARENA_CHALLENGE_RESPONSE, rqmsg, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.ArenaChallengeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 竞技场刷新对手数据
function this.RequestNewArenaEnemy(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ARENA_RANDOM_ENEMY_REQUEST, MessageTypeProto_pb.ARENA_RANDOM_ENEMY_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.ArenaRandomResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 竞技场获取防守记录
function this.RequestArenaRecord(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ARENA_DEFENSE_REQUEST, MessageTypeProto_pb.ARENA_DEFENSE_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.ArenaRecordInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 竞技场获取挑战记录
function this.RequestArenaRecordChallenge(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ARENA_CHALLENGE_RECORD_REQUEST, MessageTypeProto_pb.ARENA_CHALLENGE_RECORD_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.ArenaRecordInfoResponse()
        msg:ParseFromString(data)

        
        if func then
            func(msg)
        end
    end)
end

--冒险挂机状态请求
function this.GetAdventureStateInfoRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_INFO_REQUEST, MessageTypeProto_pb.ADVENTURE_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.GetAdventureStateInfoResponse()
        msg:ParseFromString(data)
        AdventureManager.adventureStateInfoList = msg.adventureStateInfoList
        AdventureManager.GetAdventureData()
        AdventureManager.OnFlushShowData()
        if func then
            func(msg)
        end
    end)
end
--冒险召唤外敌协议
function this.CallAlianInvasionRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_CALL_BOSS_REQUEST, MessageTypeProto_pb.ADVENTURE_CALL_BOSS_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.AdventureCallBossResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end



--外敌界面Boss挑战请求
function this.GetAdventurenBossChallengeRequest(func, bossId, teamId, fightTimes, skipFight)
    local data = FightInfoProto_pb.AdventurenBossChallengeRequest()
    data.bossId = tostring(bossId)
    data.teamId = teamId
    data.fightTimes = fightTimes
    data.skipFight = skipFight
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_BOSS_CHALLENGE_REQEUST, MessageTypeProto_pb.ADVENTURE_BOSS_CHALLENGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.AdventurenBossChallengeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--外敌界面Boss分享请求
function this.GetAdventureBossShareRequest(func, bossId)
    local data = FightInfoProto_pb.AdventurenBossChallengeRequest()
    data.bossId = bossId
    local rqmsg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_BOSS_SHARE_REQUEST, MessageTypeProto_pb.ADVENTURE_BOSS_SHARE_RESPONSE, rqmsg, function()
        if func then
            func()
        end
    end)
end

-- 外敌入侵敌人信息获取
function this.RequestAdventureEnemyList(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_BOSSHURT_REQEUST, MessageTypeProto_pb.ADVENTURE_BOSSHURT_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.AdventureBossInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)

end
--冒险伤害排行榜
function this.GetAdventurnInjureRankRequest(injueryData, _index, func)
    local data = FightInfoProto_pb.AdventurnRankRequest()
    --local dataNum=0
    data.page = _index
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_BOSS_RANK_REQUEST, MessageTypeProto_pb.ADVENTURE_BOSS_RANK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.AdventurnRankResponse()
        msg:ParseFromString(data)
        table.insert(injueryData, msg)
        if #msg.adventureRankItemInfo < 20 then
            if func then
                func(injueryData)
            end
        else
            --dataNum=dataNum+#msg.adventureRankItemInfo
            _index = _index + 1
            this.GetAdventurnInjureRankRequest(injueryData, _index, func)
        end
        --if func then
        --    func(msg)
        --end
    end)
end
--冒险伤害排行榜（总排行榜）
function this.GetAdventureRankRequest(page, func)
    local data = FightInfoProto_pb.AdventurnRankRequest()
    data.page = page
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_BOSS_RANK_REQUEST, MessageTypeProto_pb.ADVENTURE_BOSS_RANK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.AdventurnRankResponse()
        msg:ParseFromString(data)
        if func then
            func(page, msg)
        end
    end)
end
--冒险解锁Boss战斗请求
function this.AdventurnChallengeRequest(func, arenaId, teamId, skipFight)
    local data = FightInfoProto_pb.AdventurnChallengeRequest()
    data.arenaId = arenaId
    data.teamId = teamId
    data.skipFight = skipFight
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_CHALLENGE_REQUEST, MessageTypeProto_pb.ADVENTURE_CHALLENGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.AdventurnChallengeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--冒险区域升级请求
function this.GetAdventurnUpLevelRequest(func, arenaId)
    local data = FightInfoProto_pb.AdventureUpLevelRequest()
    data.arenaId = arenaId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_UPLEVEL_REQUEST, MessageTypeProto_pb.ADVENTURE_UPLEVEL_RESPONSE, msg, function()
        if func then
            func()
        end
    end)
end
--冒险区域领取奖励请求(position:0代表消耗时光沙漏，1代表消耗妖晶)
function this.GetAventureRewardRequest(func, type, position)
    local data = FightInfoProto_pb.TakeAventureRewardRequest()
    data.type = type
    if position then
        data.position = position
    else
        data.position = -1
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADVENTURE_REWARD_REQUEST, MessageTypeProto_pb.ADVENTURE_REWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.TakeAventureRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end




-- 获取主商店所有商店数据
function this.RequestMainShopData(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_STARE_INFOS_REQUEST, MessageTypeProto_pb.GET_STARE_INFOS_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetStoreInfosResponse()
        msg:ParseFromString(data)
        ShopManager.ReceiveShopData(msg)
        if func then
            func(msg)
        end
    end)
end


-- 请求购买物品
function this.RequestBuyShopItem(shopType, shopItemId, num, func)
    local data = PlayerInfoProto_pb.BuyStoreItemRequest()
    data.storeId = shopType
    data.itemId = shopItemId
    data.itemNum = num
    local rqmsg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BUY_STORE_ITEM_REQUEST, MessageTypeProto_pb.BUY_STORE_ITEM_RESPONSE, rqmsg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.BuyStoreItemResponse()
        msg:ParseFromString(data)
        NetManager.RequestVipLevelUp(function()end)--提升等级
        if func then
            func(msg)
        end
    end)
end

-- 请求刷新商店信息
function this.RequestRefreshShop(shopType, isAuto, func)
    local data = PlayerInfoProto_pb.StoreGoodsRefreshRequest()
    data.type = isAuto and 1 or 0
    data.storeId = shopType
    local rqmsg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.STORE_GOODS_REFRESH_REQUEST, MessageTypeProto_pb.STORE_GOODS_REFRESH_RESPONSE, rqmsg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.StoreGoodsRefreshResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求获取所有功能状态
function this.GetAllFunState(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_FUNCTIONOFTIME_REQUEST, MessageTypeProto_pb.GET_FUNCTIONOFTIME_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetFunctionOfTimeResponse()
        msg:ParseFromString(data)
        
        
        ActTimeCtrlManager.InitMsg(msg)
        if func then
            func(msg)
        end
    end)
end

-------------------Vip特权相关-----------------
--提升Vip等级
function this.RequestVipLevelUp(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.VIP_LEVELUP_REQEUST, MessageTypeProto_pb.VIP_LEVELUP_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.VipLevelUpResponse()
        msg:ParseFromString(data)
        VipManager.InitCommonData(msg.vipBaseInfo)
        TaskManager.SetTypeTaskList(TaskTypeDef.VipTask, msg.userMissionInfo)
        --AdventureManager.UpdateStateTime()
        SubmitExtraData({ type = SDKSubMitType.TYPE_VIP_LEVELUP })
        if func then
            func(msg)
        end
    end)
end

--领取Vip权益奖励(等级，每日)
function this.RequestReceiveVipRights(type,level, func)
    local data = PlayerInfoProto_pb.VipTakeBoxRequest()
    data.type = type
    data.level = level
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.VIP_TAKE_REWARD_REQUEST, MessageTypeProto_pb.VIP_TAKE_REWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.VipTakeBoxResponse()
        msg:ParseFromString(data)

        
        if func then
            func(msg)
        end
    end)
end

--用户战力提升变化
function this.RequestUserForceChange(teamId, func)
    local data = PlayerInfoProto_pb.UserForceChangeRequest()
    data.teamId = teamId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.USER_FORCE_CHANGE_REQUEST, MessageTypeProto_pb.USER_FORCE_CHANGE_RESPONSE, msg, function()
        if func then
            func()
        end
    end)
end

----------------------------------------------
--请求任务信息
function this.RequestMission(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_MISSION_REQUEST, MessageTypeProto_pb.GET_MISSION_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetMissionResponse()
        msg:ParseFromString(data)
        
        TaskManager.InitTypeTaskList(msg.userMissionInfo)
        if func then
            func(msg)
        end
    end)
end

--请求引导任务数据刷新
function this.RequestGuideTaskDataRefresh(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_MISSION_GUIDE_REQUEST, MessageTypeProto_pb.GET_MISSION_GUIDE_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetMissionResponse()
        msg:ParseFromString(data)
        
        TaskManager.RequestGuideTaskData(msg.userMissionInfo)
        if func then
            func(msg)
        end
    end)
end

--购买
function this.RequestBuyGiftGoods(Id, func)
    if not GetChannerConfig().Recharge_SDK_open then
        PopupTipPanel.ShowTipByLanguageId(10414)
        return
    end

    local payFunc = function ()
        local data = PlayerInfoProto_pb.TestBuyGiftGoodsRequest()
        data.goodsId = Id
        data.channel = GetChannerConfig(). ListID
        local msg = data:SerializeToString()
        Network:SendMessageWithCallBack(MessageTypeProto_pb.TEST_BUY_GIGT_GOODS_REQEUST, MessageTypeProto_pb.TEST_BUY_GIGT_GOODS_RESPONSE, msg, function(buffer)
            local data = buffer:DataByte()
            local msg = PlayerInfoProto_pb.BuyGoodsDropIndication()
            msg:ParseFromString(data)
            NetManager.RequestVipLevelUp(function()end)--提升等级
            if func then
                func(msg)
            end
        end)
    end

    if GetChannerConfig().IsRefund_tips then
        if ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, Id).IsRefund == 1 then
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Currency, GetLanguageStrById(50250), function (msg)
                payFunc()
            end)
        else
            payFunc()
        end
    else
        payFunc()
    end
end

function this.RequestBuyZeroGiftGoods(Id, func)
    local data = PlayerInfoProto_pb.BuyGiftGoodsOnlyZeroPriceRequest()
    data.goodsId = Id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BuyGiftGoodsOnlyZeroPriceRequest, MessageTypeProto_pb.BuyGiftGoodsOnlyZeroPriceResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.BuyGoodsDropIndication()
        msg:ParseFromString(data)
        if func then
            func(data)
        end
    end)
end

--获取好友信息请求
function this.RequestGetFriendInfo(type, func)
    local data = PlayerInfoProto_pb.GetFriendInfoRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_FRIEND_INFO_REQUEST, MessageTypeProto_pb.GET_FRIEND_INFO_REPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetFriendInfoResponse()
        msg:ParseFromString(data)
        GoodFriendManager.GetFriendInfoRequest(type, msg)
        if func then
            func(msg)
        end
    end)
end

-- 好友切磋
function this.RequestPlayWithSomeOne(uid, teamId, func)
    local data = ArenaInfoProto_pb.PlayWithSbRequest()
    data.challengeUid = uid
    data.myteamId = teamId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.PLAY_WITH_SB_REQUEST, MessageTypeProto_pb.PLAY_WITH_SB_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.PlayWithSbResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--申请好友请求
function this.RequestInviteFriend(inviteUids, func)
    local data = PlayerInfoProto_pb.InviteFriendRequest()
    data.inviteUids:append(inviteUids)
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FRIEND_INVITE_REQUEST, MessageTypeProto_pb.FRIEND_INVITE_RESPONSE, msg, function(buffer)
        --local data = buffer:DataByte()
        --local msg = PlayerInfoProto_pb.InviteFriendResponse()
        -- msg:ParseFromString(data)
        if func then
            func()
        end
    end)
end

--申请为好友操作
function this.RequestFriendInviteOperation(type, friendId, func)
    local data = PlayerInfoProto_pb.FriendInviteOperationRequest()
    data.type = type
    data.friendId = friendId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FRIEND_INVITE_OPERATION_REQUEST, MessageTypeProto_pb.FRIEND_INVITE_OPERATION_RESPONSE, msg, function(buffer)
        --local data = buffer:DataByte()
        --local msg = PlayerInfoProto_pb.FriendInviteOperationResponse()
        --msg:ParseFromString(data)
        if func then
            func()
        end
    end)
end

--赠送好友精力
function this.RequestFriendGivePresent(type, friendId, func)
    local data = PlayerInfoProto_pb.FriendGivePresentRequest()
    data.type = type
    data.friendId = friendId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FRIEND_GIVE_PRESENT_REQUEST, MessageTypeProto_pb.FRIEND_GIVE_PRESENT_RESPONSE, msg, function(buffer)
        --local data = buffer:DataByte()
        --local msg = PlayerInfoProto_pb.FriendGivePresentResponse()
        --msg:ParseFromString(data)
        if func then
            func()
        end
    end)
end
--删除好友
function this.RequestDelFriend(friendId, func)
    local data = PlayerInfoProto_pb.DelFriendRequest()
    data.friendId = friendId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEL_FRIEND_REQUEST, MessageTypeProto_pb.DEL_FRIEND_RESPONSE, msg, function(buffer)
        --local data = buffer:DataByte()
        --local msg = PlayerInfoProto_pb.DelFriendResponse()
        --msg:ParseFromString(data)
        if func then
            func()
        end
    end)
end
--领取一个人和所有人的精力值
function this.RequestFriendTakeHeart(type, friendId, func)
    local data = PlayerInfoProto_pb.FriendTakeHeartRequest()
    data.type = type
    data.friendId = friendId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FRIEND_TAKE_HEART_REQUEST, MessageTypeProto_pb.FRIEND_TAKE_HEART_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.FriendTakeHeartResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--根据名字查找好友
function this.RequestFriendSearch(name, func)
    local data = PlayerInfoProto_pb.FriendSearchRequest()
    data.name = name
    local msg = data:SerializeToString()
    GoodFriendManager.friendSearchInfo = {}
    Game.GlobalEvent:DispatchEvent(GameEvent.Friend.OnFriendSearch, this.friendSearchInfo)
    
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FRIEND_SEARCH_REQUEST, MessageTypeProto_pb.FRIEND_SEARCH_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.FriendSearchResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--刷新好友在线状态
function this.RequestRefreshFriendState(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.REFRESH_FRIEND_STATE_REQEUST, MessageTypeProto_pb.REFRESH_FRIEND_STATE_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.RefreshFriendStateResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 加入/移除黑名单
function this.RequestOptBlackList(type, uid, func)
    local data = PlayerInfoProto_pb.FriendBlackOptRequest()
    data.type = type
    data.blackUid = uid
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FRIEND_BLACK_OPT_REQUEST, MessageTypeProto_pb.FRIEND_BLACK_OPT_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end, true)
end

-- 请求聊天数据
function this.RequestChatMsg(type, msgId, func)
    local data = ChatProto_pb.GetChatMessageInfoRequest()
    data.chatType = type
    data.messageId = msgId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_CHAT_MESSAGE_REQUEST, MessageTypeProto_pb.GET_CHAT_MESSAGE_REPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ChatProto_pb.GetChatMessageInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end, true)
end

-- 请求发送聊天数据
function this.RequestSendChatMsg(type, msg, friend, func)
    if string.utf8len(msg) > 140 then
        PopupTipPanel.ShowTipByLanguageId(11438)
       return
    end
    local data = ChatProto_pb.SendChatInfoReqest()
    data.chatType = type
    data.message = msg
    data.friendId = friend
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SEND_CHAT_INFO_REQUEST, MessageTypeProto_pb.SEND_CHAT_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ChatProto_pb.SendChatInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)

end

--------------------戒灵天赋---------------
--请求获取天赋消息
function this.TalentRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_RINGFIRE_INFO_REQUEST, MessageTypeProto_pb.GET_RINGFIRE_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.GetAllRingFireResponse()
        msg:ParseFromString(data)
        TalentManager.InitLocalTalentData(msg.ringFireInfo)
        if func then
            func(msg)
        end
    end)
end
--请求天赋鬼火激活
function this.TalentRingFireActiveRequest(talentId, compId, func)
    local data = HeroInfoProto_pb.RingFireLoadRequest()
    data.pokemonId = talentId
    data.comonpentId = compId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.RINGFIRE_LOAD_REQUEST, MessageTypeProto_pb.RINGFIRE_LOAD_RESPONSE, msg, function()
        if func then
            func()
        end
    end)
end
--请求戒灵天赋进阶
function this.TalentUpGradRequest(_id, func)
    local data = HeroInfoProto_pb.RingFirAdvanceRequest()
    data.pokemonId = _id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.RINGFIRE_ADVANCED_REQUEST, MessageTypeProto_pb.RINGFIRE_ADVANCED_RESPONSE, msg, function()
        if func then
            func()
        end
    end)
end
---------------------------------------

-- 请求在地图外挑战精英怪
function this.RequestFightEliteMonsterOutMap(func)
    local data = FightInfoProto_pb.FightStartRequest()
    data.type = 3
    data.teamId = FormationManager.curFormationIndex
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FIGHT_START_REQUEST, MessageTypeProto_pb.FIGHT_START_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.FightStartResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--副本普通星级奖励请求
function this.RequestFbStarReward(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FB_STAR_REWARD_REQUEST, MessageTypeProto_pb.FB_STAR_REWARD_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.FbStarRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg.FbStarReward)
        end
    end)
end

-- 重置爬塔副本
function this.RequestResetTrialMap(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_TOWER_RESET_REQUEST, MessageTypeProto_pb.MAP_TOWER_RESET_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapTowerResetResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end


-- 召唤副本首领
function this.RequestMapBoss(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_TOWER_CALL_CHIEF_REQUEST, MessageTypeProto_pb.MAP_TOWER_CALL_CHIEF_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapTowerCallChiefResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 使用炸弹
function this.RequestUseBomb(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_TOWER_USEBOMB_REQUEST, MessageTypeProto_pb.MAP_TOWER_USEBOMB_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapTowerUseBombResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求使用Buff
function this.RequestUseBuff(curLevel, optionId, func)
    local data = MapInfoProto_pb.UseTowerBuffRequest()
    data.towerLevel = curLevel
    data.optionId = optionId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_TOWER_USEBUFF_REQUEST, MessageTypeProto_pb.MAP_TOWER_USEBUFF_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.UseTowerBuffResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)

end
--请求刷新体力等 后端数据
function this.RefreshEnergyRequest(itemIdList, func)
    local data = PlayerInfoProto_pb.RefreshItemNumRequest()
    for i = 1, #itemIdList do
        data.itemId:append(itemIdList[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.REFRESH_ITEM_NUM_REQUEST, MessageTypeProto_pb.REFRESH_ITEM_NUM_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.RefreshItemNumResponse()
        msg:ParseFromString(data)
        BagManager.BackDataRefreshEnerny(msg.itemInfo)
        if func then
            func()
        end
    end)
end
--战争学院信息
function this.BattlePassRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetBattlePassInfoRequest, MessageTypeProto_pb.GetBattlePassInfoResponse , nil, function(buffer)
        local data = buffer:DataByte()
        local msg = CommonProto_pb.BattlePassInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--手札领取
function this.BattlePassGetRequest(_id,type, func)
    local datas = CommonProto_pb.GetBattlePassRewardRequest()
    datas.missionId =_id
    datas.getType = type
    local msg = datas:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetBattlePassRewardRequest, MessageTypeProto_pb.GetBattlePassRewardResponse , msg, function(buffer)
        local data = buffer:DataByte()
        local msg = CommonProto_pb.GetBattlePassRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--精英本难度状态存储请求
function this.DifficultMapRequest(mapId, index)
    local data = MapInfoProto_pb.DifficultMapRequest()
    data.mapInfo.Id = mapId
    data.mapInfo.mapdifficulty = index
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DIFFICULT_MAP_OPTION_RECORD_REQUEST, MessageTypeProto_pb.DIFFICULT_MAP_OPTION_RECORD_RESPONSE, msg, function()
    end)
end
--  请求获取试炼副本排行
function this.RequestTrialRank(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_TOWER_RANK_BY_PAGE_REQUEST, MessageTypeProto_pb.GET_TOWER_RANK_BY_PAGE_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.TowerRankResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 所有排行榜都走这个协议
function this.RequestRankInfo(rankType, func, id)
    local data = PlayerInfoProto_pb.RankRequest()
    data.type = rankType
    data.activiteId = id or 0
    local msg = data:SerializeToString()
    
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ONE_RANK_REQUEST, MessageTypeProto_pb.GET_ONE_RANK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.RankResponse()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)

end

-- 请求领取试炼层数奖励
--> levelnum trialkillconfig id
function this.RequestLevelReward(levelnum, func)
    local data = MapInfoProto_pb.TowerRewardRequest()
    data.tower = levelnum
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TAKE_TOWER_REWARD_REQUEST, MessageTypeProto_pb.TAKE_TOWER_REWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.TowerRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--请求英雄点赞界面
function this.RequestEvaluateTank(tankId, page, sortOrder,func)
    local data = HeroInfoProto_pb.HeroCommentListRequest()
    data.heroId = tankId
    data.page = page
    data.sortOrder = sortOrder
    -- data.selectType =selectType
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HERO_COMMENT_LIST_REQUEST, MessageTypeProto_pb.HERO_COMMENT_LIST_RESPONSE , msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroCommentListResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--请求英雄点赞界面自己的评论
function this.HeroMyCommentRequest(tankId,func)
    local data = HeroInfoProto_pb.HeroMyCommentRequest()
    data.heroId = tankId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HERO_MYCOMMENT_REQUEST, MessageTypeProto_pb.HERO_MYCOMMENT_RESPONSE , msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroMyCommentResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--点赞英雄评论
function this.RequestEvaluateTankId(uid,func)
    local data = HeroInfoProto_pb.HeroLikeCommentRequest()
    data.commId=uid
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HERO_LIKE_COMMENT_REQUEST, MessageTypeProto_pb.HERO_LIKE_COMMENT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroLikeCommentResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--发表英雄评论
function this.RequestEvaluateTankText(heroId,content,func)
    local data = HeroInfoProto_pb.HeroesCommentRequest()
    data.heroId=heroId
    data.content=content
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HEROES_COMMENT_REQUEST, MessageTypeProto_pb.HEROES_COMMENT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroesCommentResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--删除英雄评论
function this.RequestEvaluateTankDelText(heroId,commId ,func)
    local data = HeroInfoProto_pb.HeroDelCommentRequest()
    data.heroId=heroId
    data.commId=commId 
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HERO_DEL_COMMENT_REQUEST, MessageTypeProto_pb.HERO_DEL_COMMENT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroDelCommentResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--英雄点赞
function this.RequestEvaluateTankLike(heroId,func)
    local data = HeroInfoProto_pb.HeroLikeRequest()
    data.heroId = heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HERO_LIKE_REQUEST, MessageTypeProto_pb.HERO_LIKE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroLikeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 请求更换头像框     0头像框，1头像，2称号，3坐骑，4皮肤
function this.RequestChangeModifyDecoration(type, id, func)
    local data = PlayerInfoProto_pb.ModifyDecorationRequest()
    data.type = type
    data.decorationId = id
    local msg = data:SerializeToString()
   
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MODIFY_DECORATION_REQUEST, MessageTypeProto_pb.MODIFY_DECORATION_RESPONSE, msg, function(buffer)
        if data.type == 2 then
            if id == PlayerManager.designation then
                PlayerManager.SetPlayerDesignation(0)
            else
                PlayerManager.SetPlayerDesignation(id)
            end
        end

        if func then
            func()
        end
    end)
end
--玩家坐骑升级
function this.RequestRideLvUp(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.RIDE_LEVEL_UP_REQUEST, MessageTypeProto_pb.RIDE_LEVEL_UP_RESPONSE, nil, function(buffer)
        if func then
            func()
        end
    end)
end
-- 初始化云梦祈福数据
function this.InitPrayDataRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BLESS_INFO_REQUEST, MessageTypeProto_pb.BLESS_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.blessResponse()
        msg:ParseFromString(data)
        PrayManager.InitializeData(msg)
        if func then
            func(msg)
        end
    end)
end
-- 保存云梦祈福自选奖励
function this.SavePraySelectRewardRequest(_rewardIds, func)
    local data = PlayerInfoProto_pb.blessSaveRequest()
    for i = 1, #_rewardIds do
        data.rewardIds:append(_rewardIds[i])
        --
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BLESS_SAVE_REWARD_REQUEST, MessageTypeProto_pb.BLESS_SAVE_REWARD_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
-- 翻牌云梦祈福奖励
function this.GetSinglePrayRewardRequest(rewardId, func)
    local data = PlayerInfoProto_pb.blessChooseRequest()
    --
    data.locationId = rewardId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BLESS_CHOOSE_REQUEST, MessageTypeProto_pb.BLESS_CHOOSE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.blessChooseResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 重置云梦祈福奖励
function this.ResetAllPrayRewardRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BLESS_REFRESH_REQUEST, MessageTypeProto_pb.BLESS_REFRESH_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.blessRefresh()
        msg:ParseFromString(data)
        if func then
            func(msg.reward)
        end
    end)
end

--购买孙龙的宝藏
function this.BuyTreasureOfSomeBody(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BUY_TREASURE_REQUEST, MessageTypeProto_pb.BUY_TREASURE_RESPONSE, nil, function(buffer)
        Game.GlobalEvent:DispatchEvent(GameEvent.TreasureOfSomeBody.OpenTreasureAward)
        if func then
            func()
        end
    end)
end

-- 请求获取所有药灵师血量
function this.RequestAllHeroHp(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ENDLESS_MAP_HERO_INFO_REQUEST, MessageTypeProto_pb.ENDLESS_MAP_HERO_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.GetEndlessHeroResponse()
        msg:ParseFromString(data)
        EndLessMapManager.InitHeroHp(msg, function()
            if func then
                func()
            end
        end)
    end)
end

-- 请求复位
function this.RequestResetState(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ENDLESS_MAP_RESET_REQUEST, MessageTypeProto_pb.ENDLESS_MAP_RESET_RESPONSE, nil, function(buffer)
        if func then
            func()
        end
    end)
end

-- 请求标记地图点
function this.RequestNotePoint(mapId, pos, info, type, func)
    local data = MapInfoProto_pb.SignEndlessCellRequest()
    data.sign.mapId = mapId
    data.sign.cellId = pos
    data.sign.info = info
    data.sign.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ENDLESS_MAP_SIGN_REQUEST, MessageTypeProto_pb.ENDLESS_MAP_SIGN_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.SignEndlessCellResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)

end
-- 请求战力排名 排名数据
function this.RequestWarPowerSortData(_page, _activityId, func)
    local data = PlayerInfoProto_pb.GetForceRankInfoRequest()
    
    data.page = _page
    data.activiteId = _activityId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GETF_FORCE_RANK_INFO_REQUEST, MessageTypeProto_pb.GETF_FORCE_RANK_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetForceRankInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(_page, msg)
        end
    end)
end
-- 刷新行动力
function this.ReqeustRefreshEnergy(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ENDLESS_EXECUTION_REFRESH_REQUEST, MessageTypeProto_pb.ENDLESS_EXECUTION_REFRESH_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.ExecutionRefreshResponse()
        msg:ParseFromString(data)
        EndLessMapManager.leftEnergy = msg.exeValue

        if func then
            func()
        end
    end)
end


---========================公会基础接口=============================
-- 请求创建公会
function this.RequestCreateGuild(name, announce, func)
    local data = Family_pb.FamilyCreateReqeust()
    data.name = name
    data.announce = announce
    local _language= GetCurLanguage()
    -- LogError("lan".._language)
    data.channelId = _language 
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_CREATE_REQUEST, MessageTypeProto_pb.FAMILY_CREATE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyCreateResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求推荐公会列表
function this.RequestRecommandGuild(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_RECOMEND_REQUEST, MessageTypeProto_pb.FAMILY_RECOMEND_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyRecommandResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求搜索公会
function this.RequestSearchGuild(name, func)
    local data = Family_pb.FamilySearchReqeust()
    data.name = name
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_SEARCH_REQEUST, MessageTypeProto_pb.FAMILY_SEARCH_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilySeachResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求加入公会
function this.RequestJoinGuild(familyId, func)
    local data = Family_pb.FamilyJoinRequest()
    data.familyId = familyId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_JOIN_REQUEST, MessageTypeProto_pb.FAMILY_JOIN_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyJoinResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 申请加入公会
function this.RequestApplyGuild(familyIdList, func)
    local data = Family_pb.FamilyApplyRequest()
    for i = 1, #familyIdList do
        data.familyId:append(familyIdList[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_APPLY_REQEUST, MessageTypeProto_pb.FAMILY_APPLY_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

-- 请求获取我的公会信息
function this.RequestMyGuildInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_GET_INFO_REQUEST, MessageTypeProto_pb.FAMILY_GET_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetFamilyInfoResponse()
        msg:ParseFromString(data)
        -- 设置我的公会信息
        MyGuildManager.SetMyGuildInfo(msg)
        MyGuildManager.SetMyMemInfo(msg)
        MyGuildManager.SetMyFeteInfo(msg)
        MyGuildManager.SetWalkData(msg)
        GuildBossManager.SetBossData(msg)
        --GuildCarDelayManager.SetProgressData(msg.carDelayProgressIndication)
        GuildCarDelayManager.SetCarPlayTimeData(msg.carPlayTime)
        MyGuildManager.SetMyAidInfo(msg)
        if func then
            func()
        end

        -- 工会数据
        -- ThinkingAnalyticsManager.SetSuperProperties({
        --     guild_id = msg.familyBaseInfo.id,
        --     guild_name = msg.familyBaseInfo.name,
        --     guild_level = msg.familyBaseInfo.levle,
        -- })

    end)
end

-- 请求获取公会成员信息
function this.RequestMyGuildMembers(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_GET_MEMBER_REQUEST, MessageTypeProto_pb.FAMILY_GET_MEMBER_RESPOSNE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetFamilyMemberInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求获取公会日志
function this.RequestMyGuildLog(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_GET_LOG_REQUEST, MessageTypeProto_pb.FAMILY_GET_LOG_RESPOSNE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetFamilyLogResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 请求获取申请信息
function this.RequestMyGuildApply(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_GET_APPLY_REQUEST, MessageTypeProto_pb.FAMILY_GET_APPLY_RESPOSNE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetFamilyApplyResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 请求操作申请
function this.RequestOperateMyGuildApply(opType, applyId, func)
    local data = Family_pb.FamilyOperationApplyRequest()
    data.type = opType
    data.applyId = applyId or 0
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_OPERATION_APPLY_LIST_REQUEST, MessageTypeProto_pb.FAMILY_OPERATION_APPLY_LIST_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
-- 请求踢人
function this.RequestKickOutFormMyGuild(uid, func)
    local data = Family_pb.FamilyKickOutRequest()
    data.targetUid = uid
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_KICK_OUT_REQUEST, MessageTypeProto_pb.FAMILY_KICK_OUT_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
-- 请求委任职位
function this.RequestMyGuildAppointment(uid, pos, func)
    local data = Family_pb.FamilyAppointmentReqeust()
    data.targetUid = uid
    data.position = pos
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_APPOINTMENT_REQEUST, MessageTypeProto_pb.FAMILY_APPOINTMENT_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
-- 请求修改公会宣言
function this.RequestChangeGuildBase(type, content, func)
    local data = Family_pb.FamilyChangeRequest()
    data.type = type
    data.content = content
    local _language= GetCurLanguage()
    -- LogError("lan".._language)
    data.channelId = _language 
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_CHANGE_NOTICE_REQUEST, MessageTypeProto_pb.FAMILY_CHANGE_NOTICE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyChangeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 请求修改公会申请类型
function this.RequestChangeJoinType(joinType, limitLevel, func)
    local data = Family_pb.FamilyChangeJoinTypeRequest()
    data.type = joinType
    data.intoLevel = limitLevel
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_CHANGE_JOIN_TYPE_REQUEST, MessageTypeProto_pb.FAMILY_CHANGE_JOIN_TYPE_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
-- 请求退出公会
function this.RequestQuitGuild(func)
    local data = Family_pb.FamilyLeaveRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_LEVEL_REQUEST, MessageTypeProto_pb.FAMILY_LEVEL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyLeaveResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 解散公会
function this.RequestDismissGuild(dType, func)
    local data = Family_pb.FamilyDissolutionRequest()
    data.type = dType
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_DISSOLUTION_REQUEST, MessageTypeProto_pb.FAMILY_DISSOLUTION_RESPONSE, msg, function(buffer)
        
        if func then
            func()
        end
    end)
end

--请求公会行走
function this.GuildWalkRequest(pathList, func)
    
    local data = Family_pb.FamilyWalkRequest()
    for i = 1, #pathList do
        local point = pathList[i]
        data.path:append(GuildMap_UV2Pos(point.u, point.v))
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_WALK_REQUEST, MessageTypeProto_pb.FAMILY_WALK_RESPONSE, msg, function(buffer)

        
        if func then
            func()
        end
    end)
end

--请求修改公会图腾
function this.RequestChangeLogo(logoId, func)
    local data = Family_pb.ChangeIconRequest()
    data.iconId = logoId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_CHANGE_ICON_REQUEST, MessageTypeProto_pb.FAMILY_CHANGE_ICON_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

---========================公会基础接口end=============================

---========================公会战接口=============================

-- 请求公会建筑布防信息
function this.RequestGuildFightBaseData(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_FIGHT_ROUND_INFO_REQUEST, MessageTypeProto_pb.FAMILY_FIGHT_ROUND_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyFightRoundResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 请求公会建筑布防信息
function this.RequestDefendStageData(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_VIEW_DEFEND_REQUEST, MessageTypeProto_pb.FAMILY_VIEW_DEFEND_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyDefendViewResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 请求布防公会建筑(buildType 为空或0 表示随机建筑)
function this.RequestGuildFightDefend(uid, buildType, func)
    local data = Family_pb.FamilyQuickDefendRequest()
    data.buildId = buildType or 0
    data.uid = uid
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_QUICK_SET_DEFEND_REQEUST, MessageTypeProto_pb.FAMILY_QUICK_SET_DEFEND_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
-- 请求进攻阶段双方信息
function this.RequestAttackStageDefendData(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_FIGHT_INFO_REQUEST, MessageTypeProto_pb.FAMILY_FIGHT_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyFightInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求玩家布防编队信息
function this.RequestGuildFightDefendFormation(gid, uid, func)
    local data = Family_pb.FamilyDefendDetailViewRequest()
    data.gid = gid
    data.playerId = uid
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_VIEW_DEFEND_DETAIL_REQUEST, MessageTypeProto_pb.FAMILY_VIEW_DEFEND_DETAIL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyDefendDetailViewResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求进攻
function this.RequestGuildFightAttackEnemy(gid, uid, func)
    local data = Family_pb.FamilyFightAttackRequest()
    data.gid = gid
    data.attackUid = uid
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_FIGHT_ATTACK_REQUEST, MessageTypeProto_pb.FAMILY_FIGHT_ATTACK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyFightAttackResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求公会战结果
function this.RequestGuildFightResultData(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_FIGHT_TOTAL_RESULT_REQUEST, MessageTypeProto_pb.FAMILY_FIGHT_TOTAL_RESULT_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GuildFightResultResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求公会战排名
function this.RequestGuildFightAttackLogData(type, func)
    local data = Family_pb.PersonalFightResultRequest()
    data.type = type or 0
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_PERSONAL_FIGHT_RESULT_REQUEST, MessageTypeProto_pb.FAMILY_PERSONAL_FIGHT_RESULT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.PersonalFightResultResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求公会战排名
function this.RequestMyHeroBloodData(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAMILY_ATTACK_BLOOD_REQUEST, MessageTypeProto_pb.FAMILY_ATTACK_BLOOD_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetAttackHeroBloodResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end


---========================公会战接口end=============================
---========================公会boss=============================
-- 请求战斗
function this.RequestAttackGuildBoss(func)
    local data = FightInfoProto_pb.FightStartRequest()
    data.type = 7
    data.teamId = FormationTypeDef.FORMATION_NORMAL
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FIGHT_START_REQUEST, MessageTypeProto_pb.FIGHT_START_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.FightStartResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--请求公会boss扫荡
function this.RequestSweepGuildBoss(func)
    local data = FightInfoProto_pb.SweepRightRequest()
    data.type = 2   -- 公会boss扫荡
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SWEEP_RIGHT_REQUEST, MessageTypeProto_pb.SWEEP_RIGHT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.SweepRightResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
---========================公会boss end=============================



--累计签到
function this.RequestSignIn(dayIndex, func)
    local data = PlayerInfoProto_pb.SignInRequest()
    data.dayIndex = dayIndex
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SIGN_IN_REQUEST, MessageTypeProto_pb.SIGN_IN_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.SignInResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 获取玩家信息 typeId = 0默认，1跨服竞技场，2跨服公会战
function this.RequestPlayerInfo(uid, teamId, func, serverId, typeId)
    local data = PlayerInfoProto_pb.GetPlayerOneTeamInfoRequest()
    data.playerId = uid
    data.teamId = teamId
    data.serverId = tonumber(PlayerManager.serverInfo.server_id)
    data.typeId = typeId or 0
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_PLAYER_ONE_TEAM_INFO_REQUEST, MessageTypeProto_pb.GET_PLAYER_ONE_TEAM_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetPlayerOneTeamInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 无尽副本出图统计数据
function this.RequestEndLessStats(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ENDLESS_OUT_CONSUME_REQUEST, MessageTypeProto_pb.ENDLESS_OUT_CONSUME_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.EndlessOutConsumeResponse()
        msg:ParseFromString(data)
        EndLessMapManager.OutMapStats(msg)
        if func then
            func(msg)
        end
    end)
end

--七日狂欢领取宝箱奖励
function this.GetSevenDayCarnivalBoxReward(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TAKE_SEVEN_HAPPY_REWARD_REQUEST, MessageTypeProto_pb.TAKE_SEVEN_HAPPY_REWARD_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.TakeSenvenScoreRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 请求达人排名
function this.RequestGetExpertInfoData(_activityId, func)
    local data = PlayerInfoProto_pb.GetExpertInfoRequest()
    data.activiteId = _activityId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GETF_EXPERT_RANK_INFO_REQUEST, MessageTypeProto_pb.GETF_EXPERT_RANK_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetExpertInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

function this.RequestUpDateState(_type, func)
    local data = PlayerInfoProto_pb.UpdateStateRequest()
    data.type = _type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.UPDATE_STATE_REQUEST, MessageTypeProto_pb.UPDATE_STATE_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end


-- 请求兽潮排行
function this.RequestMonsterRankInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_MONSTER_RANK_INFO_REQUEST, MessageTypeProto_pb.GET_MONSTER_RANK_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetMonsterRankInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求禽兽战斗
function this.RequestMonsterCampFight(curWave, func)
    local data = FightInfoProto_pb.FightStartRequest()
    data.type = 5
    data.fightId = curWave
    data.teamId = FormationTypeDef.MONSTER_CAMP_ATTACK
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FIGHT_START_REQUEST, MessageTypeProto_pb.FIGHT_START_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.FightStartResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求小地图数据
function this.RequestMiniMapInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ENDLESS_MIN_MAP_INFO_REQUEST, MessageTypeProto_pb.ENDLESS_MIN_MAP_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.EndlessMinMapResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

---========我要变强评分数据============
function this.CheckGiveMePowerTask(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TO_BE_STRONGER_REQUEST, MessageTypeProto_pb.TO_BE_STRONGER_RESPONSE, nil, function()
        if func then
            func()
        end
    end)
end

---绑定手机相关
--获取绑定手机号奖励
function this.RequestGetPhoneBindReward(func)
    local data = PlayerInfoProto_pb.GetPhoneRewardRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_PHONE_REWARD_REQUEST, MessageTypeProto_pb.GET_PHONE_REWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetPhoneRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--绑定手机号
function this.RequestUpDataBindPhoneInfo(phoneNumber, func)
    local data = PlayerInfoProto_pb.UpdatePhoneinfoRequest()
    data.phoneNum = phoneNumber
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.UPDATE_PHONE_INFO_REQUEST, MessageTypeProto_pb.UPDATE_PHONE_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.UpdatePhoneinfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--请求所有法宝数据
-- function this.AllTalismanRequest(_index, func)
--     local data = HeroInfoProto_pb.GetAllEquipRequest()
--     data.index = _index
--     data.type = 2
--     local msg = data:SerializeToString()
--     Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ALL_EQUIP_REQUEST, MessageTypeProto_pb.GET_ALL_EQUIP_RESPONSE, msg, function(buffer)
--         local data = buffer:DataByte()
--         local msg = HeroInfoProto_pb.GetAllEquipResponse()
--         msg:ParseFromString(data)
--         TalismanManager.InitUpdateTalismanData(msg.equip)
--         if msg.isSendFinish then
--             if func then
--                 func(msg)
--             end
--         else
--             _index = _index + #msg.equip
--             this.AllTalismanRequest(_index, func)
--         end
--     end)
-- end

--请求所有魂印数据
function this.GetSoulPrintDataRequest(_index, func)
    if func then
        func()
    end
    -- local data = HeroInfoProto_pb.GetAllEquipRequest()
    -- data.index = _index
    -- data.type = 3
    -- local msg = data:SerializeToString()
    -- Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ALL_EQUIP_REQUEST, MessageTypeProto_pb.GET_ALL_EQUIP_RESPONSE, msg, function(buffer)
    --     local data = buffer:DataByte()
    --     local msg = HeroInfoProto_pb.GetAllEquipResponse()
    --     msg:ParseFromString(data)
    --     SoulPrintManager.InitServerData(msg.equip)
    --     if msg.isSendFinish then
    --         if func then
    --             func(msg)
    --         end
    --     else
    --         _index = _index + #msg.equip
    --         this.GetSoulPrintDataRequest(_index, func)
    --     end
    -- end)
end
--穿魂印请求(包括替换，装备，一键装备等)
-- function this.SoulEquipWearRequest(_heroId, soulPrintIdList, type, func)
--     local data = HeroInfoProto_pb.SoulEquipWearRequest()
--     data.heroId = _heroId
--     if (type == 1) then
--         data.type = type
--     else
--         data.type = 0
--     end
--     for i, v in pairs(soulPrintIdList) do
--         local c = data.soulEquipIds:add()
--         c.equipId = i
--         c.position = v
--     end
--     local msg = data:SerializeToString()
--     Network:SendMessageWithCallBack(MessageTypeProto_pb.SOUL_EQUIP_WEAR_REQUEST, MessageTypeProto_pb.SOUL_EQUIP_WEAR_RESPONSE, msg, function()
--         if func then
--             func(msg)
--         end
--     end)
-- end
--脱魂印请求
-- function this.SoulEquipUnLoadWearRequest(_heroId, soulPrintIdList, func)
--     local data = HeroInfoProto_pb.SoulEquipUnLoadWearRequest()
--     data.heroId = _heroId
--     for i, v in pairs(soulPrintIdList) do
--         local c = data.soulEquipIds:add()
--         c.equipId = i
--         c.position = v
--     end
--     local msg = data:SerializeToString()
--     Network:SendMessageWithCallBack(MessageTypeProto_pb.SOUL_EQUIP_UNLOAD_OPT_REQUEST, MessageTypeProto_pb.SOUL_EQUIP_UNLOAD_OPT_RESPONSE, msg, function()
--         if func then
--             func(msg)
--         end
--     end)
-- end
--魂印快速升级请求
function this.UpQuickSoulEquipRequest(soulPrintId, soulEquipIds, func)
    local data = HeroInfoProto_pb.UpQuickSoulEquipRequest()
    data.equipId = tostring(soulPrintId)
    for i, v in pairs(soulEquipIds) do
        data.soulEquipIds:append(i)
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.UP_SOUL_EQUIP_QUICK_REQUEST, MessageTypeProto_pb.UP_SOUL_EQUIP_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.UpSoulEquipResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end




--请求穿法宝
function this.TalismanWearRequest(_heroId, _talismanIds, func)
    local data = HeroInfoProto_pb.EquipWearRequest()
    data.heroId = _heroId
    data.type = 2
    for i = 1, #_talismanIds do
        data.equipId:append(_talismanIds[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EQUIP_WEAR_REQUEST, MessageTypeProto_pb.EQUIP_WEAR_RESPONSE, msg, function(buffer)
        if func then
            func(msg)
        end
    end)
end
--请求脱法宝
function this.TalismanUnLoadOptRequest(_heroId, _talismanIds, func)
    local data = HeroInfoProto_pb.EquipUnLoadOptRequest()
    data.heroId = _heroId
    data.type = 2
    for i = 1, #_talismanIds do
        data.equipIds:append(_talismanIds[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EQUIP_UNLOAD_OPT_REQUEST, MessageTypeProto_pb.EQUIP_UNLOAD_OPT_RESPONSE, msg, function(buffer)
        if func then
            func(msg)
        end
    end)
end
--请求法宝升星
function this.TalismanUpStarRequest(_talismanDid, func)
    local data = HeroInfoProto_pb.UpHeroStarRequest()
    data.heroId = _talismanDid
    data.type = 2
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.UP_HERO_STAR_REQUEST, MessageTypeProto_pb.UP_HERO_STAR_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = CommonProto_pb.Drop()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

---调查问卷相关
--获取调查问卷
function this.RequestGetQuestionnaireArgs(func)
    local data = PlayerInfoProto_pb.GetQuestionRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_QUESTION_REQUEST, MessageTypeProto_pb.GET_QUESTION_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetQuestionResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--提交问卷
function this.RequestUpDataQuestion(answers, func)
    local data = PlayerInfoProto_pb.upDataQuestionRequest()
    for i = 1, #answers do
        data.options:append(answers[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.UPDATE_QUESTION_REQUEST, MessageTypeProto_pb.UPDATE_QUESTION_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.upDataQuestionResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 保存跳过战斗
function this.RequestSaveSkipFight(type, func)
    local data = MapInfoProto_pb.EndlessSetSkipRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ENDLESS_SET_SKIPFIGHT_REQUEST, MessageTypeProto_pb.ENDLESS_SET_SKIPFIGHT_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end


--- ====== 血战奖励相关================
-- 获取奖励数据
function this.RequestBloodyScoreRewardData(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BLOOD_GETSCORE_INFO_REQUEST, MessageTypeProto_pb.BLOOD_GETSCORE_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = RoomProto_pb.GetBloodyScoreInfoResponse()
        msg:ParseFromString(data)
        -- 保存数据
        MatchDataManager.SetScoreRewardData(msg)
        if func then
            func()
        end
    end)
end

-- 领取奖励数据
function this.RequestGetScoreRewardData(id, func)
    local data = RoomProto_pb.BloodyTakeScoreRewardRequet()
    data.id = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BLOOD_TAKE_SCORE_REWARD_REQEUST, MessageTypeProto_pb.BLOOD_TAKE_SCORE_REWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = RoomProto_pb.BloodyTakeScoreRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 购买令牌
function this.RequestBuyExtraReward(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BLOOD_BUY_SCORE_REQUEST, MessageTypeProto_pb.BLOOD_BUY_SCORE_RESPONSE, nil, function(buffer)
        --local data = buffer:DataByte()
        --local msg = RoomProto_pb.GetBloodyScoreInfoResponse()
        --msg:ParseFromString(data)
        ---- 保存数据
        --MatchDataManager.SetScoreRewardData(msg)
        if func then
            func()
        end
    end)
end

---占星相关
--请求占星抽奖协议
function this.GetSoulRandRequest(time, func)
    local data = HeroInfoProto_pb.SoulRandRequest()
    data.time = time
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SOUL_RAND_EQUIP_REQUEST, MessageTypeProto_pb.SOUL_RAND_EQUIP_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.SoulRandResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--请求强行召唤协议
function this.GetSoulForceRandRequest(func)
    local data = HeroInfoProto_pb.SoulForceRandRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SOUL_FORCE_RAND_EQUIP_REQUEST, MessageTypeProto_pb.SOUL_FORCE_RAND_EQUIP_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.SoulForceRandResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--CDKey兑换
function this.GetExchangeCdkRequest(key, func)
    local data = PlayerInfoProto_pb.ExchangeCdkRequest()
    data.key = key
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EXCHANGE_CDK_REQUEST, MessageTypeProto_pb.EXCHANGE_CDK_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

--登录获取新关卡的信息
function this.InitFightPointLevelInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAIN_LEVEL_GET_INFO_REQUEST, MessageTypeProto_pb.MAIN_LEVEL_GET_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetMainLevelInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
        FightPointPassManager.InitAllFightPointState(msg)
        AdventureManager.GetAdventureData()
    end)
end
--请求英雄回溯
function this.HeroRetureEvent(heroId, func)
    local data = HeroInfoProto_pb.HeroReturnRequest()
    
    data.heroId = heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HERO_RETURN_REQUEST, MessageTypeProto_pb.HERO_RETURN_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroReturnResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 请求关卡排行
function this.RequestFightRank(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAIN_LEVEL_GET_RANK_REQUEST, MessageTypeProto_pb.MAIN_LEVEL_GET_RANK_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.MainLevelRankInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求兽潮战斗结果
function this.GetMonsterFightResult(fightId, teamId, func)
    local data = FightInfoProto_pb.QuickStartMonsterFightRequest()
    data.fightId = fightId
    data.teamId = teamId

    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.QUICK_START_MONSTERFIGHTER_REQUEST, MessageTypeProto_pb.QUICK_START_MONSTERFIGHTER_REPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.QuickStartMonsterFightResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--孙龙的宝藏购买等级
function this.RequestBuyTreasureLevel(level, func)
    local data = PlayerInfoProto_pb.QuickBuyTreasureLevelRequest()
    data.level = level
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BUY_TREASURE_LEVEL_REQUEST, MessageTypeProto_pb.BUY_TREASURE_LEVEL_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

---幸运探宝
function this.GetLuckyTurnRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_LUCKWHEEL_REQUEST, MessageTypeProto_pb.GET_LUCKWHEEL_RESPONSE, nil,function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.LuckWheelIndication()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--请求幸运转盘刷新 1活动id 2是否免费
function this.GetLuckyTurnRefreshRequest(activityId,isFree, func)
    local data = PlayerInfoProto_pb.RefreshLuckWheelRequest()
    data.activityId = activityId
    data.isFree=isFree
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.REFRESH_LUCKWHEEL_REQUEST, MessageTypeProto_pb.REFRESH_LUCKWHEEL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.RefreshLuckWheelResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--请求抽取幸运转盘 1活动id 2是否是多次抽取
function this.GetLuckyTurnRankRequest(activityId,repeated,func)
    local data = PlayerInfoProto_pb.GetLuckWheelRandRewardRequest()
    data.activityId = activityId
    data.repeated=repeated
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_LUCKWHEEL_RANDREWARD_REQUEST, MessageTypeProto_pb.GET_LUCKWHEEL_RANDREWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetLuckWheelRandRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--请求物品刷新
function this.GetRefreshCountDownRequest(itemIdList,func)
    local data = PlayerInfoProto_pb.RefreshItemNumRequest()
    for i = 1, #itemIdList do
        data.itemId:append(itemIdList[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.REFRESH_ITEM_NUM_REQUEST, MessageTypeProto_pb.REFRESH_ITEM_NUM_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.RefreshItemNumResponse()
        msg:ParseFromString(data)
        BagManager.BackDataRefreshEnerny(msg.itemInfo)
        if func then
            func(msg)
        end
    end)
end

--请求英雄上锁
function this.HeroLockEvent(heroId,lockState, func)
    local data = HeroInfoProto_pb.HeroLockChangeRequest()
    
    data.heroId = heroId
    data.lockState = lockState
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HERO_LOCK_CHANGE_REQUEST, MessageTypeProto_pb.HERO_LOCK_CHANGE_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

--好友上阵英雄预览信息
function this.ViewHeroInfoRequest(targetUid,heroId,func)
    local data = PlayerInfoProto_pb.ViewHeroInfoRequest()
    data.targetUid = targetUid
    data.heroId = heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.VIEW_HERO_INFO_REQUEST, MessageTypeProto_pb.VIEW_HERO_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.ViewHeroInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--跨服好友上阵英雄预览信息
function this.WorldViewHeroInfoRequest(targetUid, heroId, func)
    local data = gtwprotos.WorldProto_pb.ViewHeroInfoRequest()
    data.targetUid = targetUid
    data.heroId = heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ViewHeroInfoRequest, MessageTypeProto_pb.ViewHeroInfoResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = gtwprotos.WorldProto_pb.ViewHeroInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

---东海寻仙限时抽卡相关---
function this.GetFindFairyRequest(activityId,func)
    local data = PlayerInfoProto_pb.NextActivityRequest()
    data.activityId = activityId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.NEXT_ACTIVITY_REQUEST, MessageTypeProto_pb.NEXT_ACTIVITY_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.NextActivityResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
----------------------

-- 领取Vip每日奖励
function this.GetVipDailyReward(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.VIP_TAKE_DAILY_REQUEST, MessageTypeProto_pb.VIP_TAKE_DAILY_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.VipTakeDilyResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)

end
--迷宫寻宝派遣
function this.FindTreasureMissingRoomSendHeroRequest(_missionId,_heroIds,func)
    local data = PlayerInfoProto_pb.MissingRoomSendHeroRequest()
    data.missionId = _missionId
    for i = 1, #_heroIds do
        data.heroIds:append(_heroIds[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MISSING_ROOM_HERO_SEND_REQUEST, MessageTypeProto_pb.MISSING_ROOM_HERO_SEND_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
--迷宫寻宝单个任务加速
function this.FindTreasureMissingRoomAccelerateRequest(_missionId,func)
    local data = PlayerInfoProto_pb.MissingRoomAccelerateRequest()
    data.missionId = _missionId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MISSING_ROOM_MISSION_ACCELERATE_REQUEST, MessageTypeProto_pb.MISSING_ROOM_MISSION_ACCELERATE_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
--迷宫寻宝刷新
function this.FindTreasureRefreshRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MISSING_ROOM_MISSION_REFRESH_REQUEST, MessageTypeProto_pb.MISSING_ROOM_MISSION_REFRESH_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.MissingRoomRefreshResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
----===================巅峰赛相关+++++++++++++++++++++++
--- 获取基础数据
function NetManager.GetTopMatchBaseInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CHAMPION_GET_REQUEST, MessageTypeProto_pb.CHAMPION_GET_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.ChampionGetInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--- 获取历史记录
function NetManager.GetTopMatchHistoryBattle(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CHAMPION_GET_MYHISTORY_REQEUST, MessageTypeProto_pb.CHAMPION_GET_MYHISTORY_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.ChanpionGetAllMyBattleHistoryResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--- 获取选拔赛小组排名
function NetManager.GetTopMatchMyTeamRank(func)
    local data = ArenaInfoProto_pb.ChampionGetWorldRankRequest()
    data.page = 1
    data.type = 1
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CHAMPION_GET_RANK_REQUEST, MessageTypeProto_pb.CHAMPION_GET_RANK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.ChampionGetWorldRankResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--- 获取竞猜数据，  type == 0  全量拉取数据， == 1 只获取赔率信息（用于界面定时刷新赔率）
function NetManager.GetBetMatchInfo(type, func)
    local data = ArenaInfoProto_pb.ChampionGetBetRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CHAMPION_BET_INFO_REQUEST, MessageTypeProto_pb.CHAMPION_BET_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.ChampionGetBetResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--- 竞猜下注
function NetManager.RequestBet(uid, coins, func)
    local data = ArenaInfoProto_pb.ChampionBetReqeust()
    data.winUid = uid
    data.coins = coins
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CHAMPION_BET_GUESS_REQUEST, MessageTypeProto_pb.CHAMPION_BET_GUESS_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

-- 获取历史竞猜信息
function NetManager.GetBetHistoryInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CHAMPION_GET_MYALL_BET_REQUEST, MessageTypeProto_pb.CHAMPION_GET_MYALL_BET_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.ChampionGetAllMyBetInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 获取淘汰赛数据（type == 1 32强, == 2 4强赛） 
function NetManager.GetTopMatchEliminationInfo(type, func)
    local data = ArenaInfoProto_pb.ChampionViewFinalRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CHAMPION_VIEW_FINAL_REQUEST, MessageTypeProto_pb.CHAMPION_VIEW_FINAL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.ChampionViewFinalResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 获取淘汰赛排行数据（page == 1 页签）
function NetManager.GetTopMatchRankInfo(page, func)
    local data = ArenaInfoProto_pb.ChampionGetWorldRankRequest()
    data.page = page
    data.type = 0
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CHAMPION_GET_RANK_REQUEST, MessageTypeProto_pb.CHAMPION_GET_RANK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.ChampionGetWorldRankResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 公会红包 获得所有红包信息
function NetManager.GetAllRedPacketResponse(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.J_GET_ALL_REDPACKAGE_INFO_REQUEST, MessageTypeProto_pb.J_GET_ALL_REDPACKAGE_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetAllRedPackageResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--公会红包 抢红包
function NetManager.GetRobRedPackageRequest(id,func)
    local data = Family_pb.RobRedPackageRequest()
    data.id = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.J_ROB_REDPACKAGE_INFO_REQUEST, MessageTypeProto_pb.J_ROB_REDPACKAGE_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.RobRedPackageResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--公会红包 查看红包详情
function NetManager.GetRedPackageDetailRequest(id,func)
    local data = Family_pb.RedPackageDetailRequest()
    data.id = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.J_GET_REDPACKAGE_DETAIL_REQUEST, MessageTypeProto_pb.J_GET_REDPACKAGE_DETAIL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.RedPackageDetailResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--公会红包 点赞
function NetManager.GetRedPackageLikeRequest(uid,func)
    local data = Family_pb.RedPackageLikeRequest()
    data.uid = uid
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.J_REDPACKAGE_SEND_LIKE_REQUEST, MessageTypeProto_pb.J_REDPACKAGE_SEND_LIKE_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
--公会红包 获取点赞信息
function NetManager.GetAllSendLikeResponse(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.J_GET_ALL_SEND_LIKE_REQUEST, MessageTypeProto_pb.J_GET_ALL_SEND_LIKE_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetAllSendLikeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--远征开始

--远征获取节点信息
function NetManager.GetExpeditionRequest(leve,func)
    local data = Expedition_pb.GetExpeditionRequest()
    data.leve = leve or ExpeditionManager.expeditionLeve
    
    --if data.leve == -1 then
    --    if func then
    --        func()
    --    end
    --    return
    --end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EXPEDITION_GET_EXPEDITION_REQUEST, MessageTypeProto_pb.EXPEDITION_GET_EXPEDITION_RESONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.GetExpeditionResponse()
        msg:ParseFromString(data)
        ExpeditionManager.SetExpeditionState(1)
        ExpeditionManager.InitExpeditionData(msg)
        if func then
            func(msg)
        end
    end)
end

--获取层级奖励
function NetManager.TakeExpeditionBoxRewardRequest(_lay,func)
    local data = Expedition_pb.TakeExpeditionBoxRewardRequest()
    data.laycfg = _lay
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EXPEDITION_TAKE_BOXREWARD_REQUEST, MessageTypeProto_pb.EXPEDITION_TAKE_BOXREWARD_RESONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.TakeExpeditionBoxRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--复活英雄
function NetManager.ReliveExpeditionHeroRequest(_heroId,_nodeId,func)
    local data = Expedition_pb.ReliveExpeditionHeroRequest()
    if _heroId then
        data.heroId = _heroId
    end
    data.nodeId = _nodeId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EXPEDITION_RELIVE_HERO_REQUEST, MessageTypeProto_pb.EXPEDITION_RELIVE_HERO_RESONSE, msg, function(buffer)
    local data = buffer:DataByte()
    local msg = Expedition_pb.ReliveExpeditionHeroResponse()
    msg:ParseFromString(data)
    if func then
    func(msg)
    end
    end)
    end

--恢复节点
function NetManager.ReCoverExpeditionHeroRequest(_nodeId,func)
    local data = Expedition_pb.ReCoverExpeditionHeroRequest()
    data.nodeId = _nodeId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EXPEDITION_RECOVER_HERO_REQUEST, MessageTypeProto_pb.EXPEDITION_RECOVER_HERO_RESONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.ReCoverExpeditionHeroResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end


--领取圣物
function NetManager.TakeHolyEquipRequest(_nodeId,_type,func)
    local data = Expedition_pb.TakeHolyEquipRequest()
    data.nodeId = _nodeId
    data.type = _type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EXPEDITION_TAKE_HOLY_EQUIP_REQUEST, MessageTypeProto_pb.EXPEDITION_TAKE_HOLY_EQUIP_RESONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.TakeHolyEquipResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--开始节点战斗操作
function NetManager.StartExpeditionBattleRequest(_nodeId,_teamId,_expInfo,func)
    local data = Expedition_pb.StartExpeditionBattleRequest()
    
    data.nodeId = _nodeId
    data.teamId = _teamId
    --data.expInfo = _expInfo
    for i = 1, #_expInfo do
        data.expInfo:append(_expInfo[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EXPEDITION_START_BATTLE_REQUEST, MessageTypeProto_pb.EXPEDITION_START_BATTLE_RESONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.StartExpeditionBattleResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--战斗结束操作
function NetManager.EndExpeditionBattleRequest(_nodeId,_frames,func)
    local data = Expedition_pb.EndExpeditionBattleRequest()
    data.nodeId = _nodeId
    data.frames = _frames
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EXPEDITION_END_BATTLE_REQUEST, MessageTypeProto_pb.EXPEDITION_END_BATTLE_RESONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.EndExpeditionBattleResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--战斗结束失败操作  清空血量  保存当前状态请求
function NetManager.EndConfirmExpeditionBattleRequest(_nodeId,func)
    local data = Expedition_pb.EndConfirmExpeditionBattleRequest()
    data.nodeId = _nodeId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EndConfirmExpeditionBattleRequest, MessageTypeProto_pb.EndConfirmExpeditionBattleResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.EndConfirmExpeditionBattleResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--远征商店节点
function NetManager.StoreNodeRequest(_nodeId,func)
    local data = Expedition_pb.EndConfirmExpeditionBattleRequest()
    data.nodeId = _nodeId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.StoreNodeRequest, MessageTypeProto_pb.StoreNodeResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.StoreNodeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--远征招募节点信息
function NetManager.HeroNodeGetInfoRequest(_nodeId,func)
    local data = Expedition_pb.HeroNodeGetInfoRequest()
    data.nodeId = _nodeId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HeroNodeGetInfoRequest, MessageTypeProto_pb.HeroNodeGetInfoResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.HeroNodeGetInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--远征招募
function NetManager.HeroNodeRequest(_nodeId,_heroId,func)
    local data = Expedition_pb.HeroNodeRequest()
    data.nodeId = _nodeId
    data.heroId = _heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HeroNodeRequest, MessageTypeProto_pb.HeroNodeResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.HeroNodeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--远征结束

--孙龙的宝藏时间倒计时请求
function NetManager.RefreshTimeSLRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TREASURE_REFRESH_TIME_REQUEST, MessageTypeProto_pb.TREASURE_REFRESH_TIME_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.TreasureRefreshTimeResponse()
        msg:ParseFromString(data)
        GrowthManualManager.UpdateTrailWeekTime(msg)
        if func then
            func(msg)
        end
    end)
end


--月卡领取奖励
function NetManager.MonthCardTakeDailyRequest(type,func)
    local data = PlayerInfoProto_pb.TakeMothDilyRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MONTHCARD_TAKE_DAILY_REQUEST, MessageTypeProto_pb.MONTHCARD_TAKE_DAILY_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.TakeMothDilyResponse()
        msg:ParseFromString(data)
        if func then
            func(msg.drop)
        end
    end)
end

--合成
--装备合成
function NetManager.ComplexEquipRequest(type,star,num,func)--type装备类型   star 装备星级 0一键合成   num合成数量
    local data = HeroInfoProto_pb.ComplexEquipRequest()
    data.type = type
    data.star = star
    data.num = num
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EQUIP_COMPLEX_REQUEST, MessageTypeProto_pb.EQUIP_COMPLEX_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.ComplexEquipResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--宝物合成
function NetManager.ComplexTreasureRequest(equipType,type,star,num,func)--type :   star 装备星级 0一键合成   num合成数量
    local data = HeroInfoProto_pb.ComplexJewelEquipRequest()
    data.type = equipType
    data.rance = type
    data.targetleve=star
    data.num = num
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ComplexJewelEquipRequest, MessageTypeProto_pb.ComplexJewelEquipResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.ComplexJewelEquipResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--新魂印--
--穿戴
function NetManager.SoulEquipWearRequest(wearInfo, unloadInfo, func)
    local data = HeroInfoProto_pb.SoulEquipWearRequest()
    if wearInfo then
        data.wearInfo.heroId=wearInfo.heroId
        local c = data.wearInfo.soulEquipIds:add()
        c.equipId = wearInfo.equipId
        c.position = wearInfo.position
    end
    if unloadInfo then
        data.unloadInfo.heroId=unloadInfo.heroId
        local c = data.unloadInfo.soulEquipIds:add()
        c.equipId = unloadInfo.equipId
        c.position =unloadInfo.position
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SOUL_EQUIP_WEAR_REQUEST, MessageTypeProto_pb.SOUL_EQUIP_WEAR_RESPONSE, msg, function()
        if func then
            func(msg)
        end
    end)
end

--卸下
function NetManager.SoulEquipUnLoadWearRequest(_heroId, _equipId,_pos, func)
    local data = HeroInfoProto_pb.SoulEquipUnLoadWearRequest()
    data.heroId=_heroId
    local c = data.soulEquipIds:add()
    c.equipId = _equipId
    c.position =_pos
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SOUL_EQUIP_UNLOAD_OPT_REQUEST, MessageTypeProto_pb.SOUL_EQUIP_UNLOAD_OPT_RESPONSE, msg, function()
        if func then
            func(msg)
        end
    end)
end
--魂印合成
function NetManager.ComplexSoulPrintRequest(targetId,soulIds,func)--type装备类型   star 装备星级 0一键合成   num合成数量
    local data = HeroInfoProto_pb.MergeSoulRequest()
    data.targetId = targetId
    for i = 1, #soulIds do
        data.soulId:append(soulIds[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SOUL_MERGE_REQUEST, MessageTypeProto_pb.SOUL_MERGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.MergeSoulResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--- 每日副本相关 ---
--请求挑战 id为DailyChallengeConfig表ID type 1为挑战 2为扫荡
function NetManager.DailyChallengeRequest(id,type,func)
    local data = PlayerInfoProto_pb.DailyChallengeRequest()
    data.id = id
    data.type=type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DAILY_CHALLENGE_REQUEST, MessageTypeProto_pb.DAILY_CHALLENGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.DailyChallengeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
------------------------------------------------
--主动请求活动刷新
function NetManager.RefreshAcitvityData(ids,func)
    local data = PlayerInfoProto_pb.GetSomeActivityInfoRequest()
    for i = 1, #ids do
        data.id:append(ids[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_SOME_ACTIVITY_INFO_REQUEST, MessageTypeProto_pb.GET_SOME_ACTIVITY_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.GetSomeActitityInfoRespone()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--获取所有公会技能
function NetManager.GetAllGuildSkillData(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ALL_GUILD_SKILL_REQUEST, MessageTypeProto_pb.GET_ALL_GUILD_SKILL_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetAllGuildSkillResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
        GuildSkillManager.InitData(msg)
    end)
end
--公会技能升级
function NetManager.SinGleGuildSkillUpLv(profession,func)
    local data = Family_pb.GuildSkillLevelUpRequest()
    data.type = profession
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GUILD_SKILL_LEVEL_UP_REQUEST, MessageTypeProto_pb.GUILD_SKILL_LEVEL_UP_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
--公会技能重置
function NetManager.ResetGuildSkillRequest(type,func)
    local data = Family_pb.ResetGuildSkillRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GUILD_SKILL_RESET_REQUEST, MessageTypeProto_pb.GUILD_SKILL_RESET_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.ResetGuildSkillResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--===== 公会祭祀相关 =====--
-- 请求领取公会祭祀
function NetManager.FamilyGetFeteRewardRequest(id,func)
    local data = Family_pb.FamilyGetFeteRewardRequest()
    data.id = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FamilyGetFeteRewardRequest, MessageTypeProto_pb.FamilyGetFeteRewardResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyGetFeteRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 公会祭祀
function NetManager.FamilyFeteRequest(type,func)
    local data = Family_pb.FamilyFeteRequest()
    data.type=type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FamilyFeteRequest, MessageTypeProto_pb.FamilyFeteResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.FamilyFeteResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
------------------------------
--===== 公会战相关 =====--
--获取公会战状态信息
function NetManager.GetDeathPathStatusResponse(func)
    local data = Family_pb.GetDeathPathStatusRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEATH_PATH_GET_STATUS_REQUEST, MessageTypeProto_pb.DEATH_PATH_GET_STATUS_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetDeathPathStatusResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--公会战列表信息
function NetManager.GetDeathPathInfoResponse(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEATH_PATH_INFO_REQUEST, MessageTypeProto_pb.DEATH_PATH_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetDeathPathInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--购买公会战挑战次数
function NetManager.DeathPathBuyCountRequest(func)
    local data = Family_pb.DeathPathBuyCountRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEATH_PATH_BUYCOUNT_REQUEST, MessageTypeProto_pb.DEATH_PATH_BUYCOUNT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.DeathPathBuyCountResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--公会战请求挑战 pathId 当前阵Id
function NetManager.ChallengeDeathPathRequest(pathId, func)
    -- LogError("公会战请求挑战")
    local data = Family_pb.ChallengeDeathPathRequest()
    data.pathId = pathId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEATH_PATH_CHALLENGE_REQUEST, MessageTypeProto_pb.DEATH_PATH_CHALLENGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.ChallengeDeathPathResponse()
        msg:ParseFromString(data)
        -- LogError("回消息")
        if func then
            func(msg)
        end
    end)
end

--公会战 请求所有奖励信息
function NetManager.GetAllDeathPathRewardInfoResponse(func)
    local data = Family_pb.GetAllDeathPathRewardInfoRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEATH_PATH_GET_ALL_REWARD_INFO_REQUEST, MessageTypeProto_pb.DEATH_PATH_GET_ALL_REWARD_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetAllDeathPathRewardInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--公会战 请求领取奖励
function NetManager.DoRewardDeathPathRequest(position,func)
    local data = Family_pb.DoRewardDeathPathRequest()
    data.position = position
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEATH_PATH_DO_REWARD_REQUEST, MessageTypeProto_pb.DEATH_PATH_DO_REWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.DoRewardDeathPathResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--公会战玩家总伤害排行 请求
function NetManager.DeathPathTotalPersonRankRequest(func)
    local data = Family_pb.DeathPathTotalPersonRankRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEATH_PATH_TOTAL_PERSON_RANK_REQUEST, MessageTypeProto_pb.DEATH_PATH_TOTAL_PERSON_RANK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.DeathPathTotalPersonRankResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--会战当前阵玩家伤害排行 请求
function NetManager.DeathPathPersonRankRequest(pathId, type, func)
    local data = Family_pb.DeathPathPersonRankRequest()
    data.pathId = pathId
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEATH_PATH_PERSON_RANK_REQUEST, MessageTypeProto_pb.DEATH_PATH_PERSON_RANK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.DeathPathPersonRankResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--公会战自己公会排行第几名 请求
function NetManager.DeathPathSelfGuildRankRequest(func)
    local data = Family_pb.DeathPathSelfGuildRankRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEATH_PATH_SELF_GUILD_RANK_REQUEST, MessageTypeProto_pb.DEATH_PATH_SELF_GUILD_RANK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.DeathPathSelfGuildRankResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--公会占领排行
function NetManager.DeathPathCurGuildCountRankRequest(func)
    local data = Family_pb.DeathPathCurGuildCountRankRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEATH_PATH_CUR_GUILD_COUNT_RANK_REQUEST, MessageTypeProto_pb.DEATH_PATH_CUR_GUILD_COUNT_RANK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.DeathPathCurGuildCountRankResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--公会战开启时间
function NetManager.DeathPathStartTimeRequest(func)
    local data = Family_pb.DeathPathStartTimeRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DEATH_PATH_START_TIME_REQUEST, MessageTypeProto_pb.DEATH_PATH_START_TIME_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.DeathPathStartTimeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--跨服公会战是否解锁
function NetManager.WorldDeathPathUnLockRequest(func)
    local data = Family_pb.WorldDeathPathUnLockRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORLD_DEATHPATH_UNLOCK_REQUEST, MessageTypeProto_pb.WORLD_DEATHPATH_UNLOCK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.WorldDeathPathUnLockResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--============================================

--梦魇入侵请求挑战
function NetManager.FastFightChallengeRequest(type, challeageId, sweep, func)
    local data = FightInfoProto_pb.FastFightChallengeRequest()
    data.type = type
    data.challeageId = challeageId
    data.sweep = sweep
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FAST_FIGHT_CHALLENGE_REQUEST, MessageTypeProto_pb.FAST_FIGHT_CHALLENGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.FastFightChallengeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--车迟请求抢夺信息
function NetManager.GetCarChallenegListResponse(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_CAR_CHALLENEG_LIST_REQUEST, MessageTypeProto_pb.GET_CAR_CHALLENEG_LIST_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GetCarChallenegListResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--车迟请求抢夺记录信息
function NetManager.CarGrapRecordResponse(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_CAR_GRAP_RECORD_REQUEST, MessageTypeProto_pb.GET_CAR_GRAP_RECORD_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.CarGrapRecordResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--公会援助
function NetManager.GuildHelpGetAllRequest(func)
    if not PlayerManager.familyId or PlayerManager.familyId == 0 then
        if func then func() end
        return
    end
    local data = Family_pb.GuildHelpGetAllRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GuildHelpGetAllRequest, MessageTypeProto_pb.GuildHelpGetAllResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GuildHelpGetAllResponse()
        msg:ParseFromString(data)
        MyGuildManager.SetAllGuildHelpInfo(msg)
        if func then
            func(msg)
        end
    end)
end
--公会援助记录
function NetManager.GuildGetHelpLogRequest(func)
    local data = Family_pb.GuildGetHelpLogRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GuildGetHelpLogRequest, MessageTypeProto_pb.GuildGetHelpLogResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GuildGetHelpLogResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--公会援助
function NetManager.GuildSendHelpRequest(type,sendMessage,func)
    local data = Family_pb.GuildSendHelpRequest()
    for i = 1, #type do
        data.type:append(type[i])
    end
    data.sendMessage = sendMessage
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GuildSendHelpRequest, MessageTypeProto_pb.GuildSendHelpResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GuildSendHelpResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--公会援助领奖
function NetManager.GuildTakeHelpRewardRequest(type,func)
    local data = Family_pb.GuildTakeHelpRewardRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GuildTakeHelpRewardRequest, MessageTypeProto_pb.GuildTakeHelpRewardRequese, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GuildTakeHelpRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--公会援助领宝箱奖
function NetManager.GuildTakeHelpBoxRequest(func)
    local data = Family_pb.GuildTakeHelpBoxRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GuildTakeHelpBoxRequest, MessageTypeProto_pb.GuildTakeHelpBoxResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GuildTakeHelpRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--公会援助援助 信息
function NetManager.GuildSendHelpMessageRequest(func)
    local data = Family_pb.GuildSendHelpMessageRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GuildSendHelpMessageRequest, MessageTypeProto_pb.GuildSendHelpMessageResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GuildSendHelpMessageResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--援助他人 自己援助次数修改 GuildHelpInfoIndication会推
function NetManager.GuildHelpHelpOtherRequest(uid,type,func)
    local data = Family_pb.GuildHelpHelpOtherRequest()
    data.uid = uid
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GuildHelpHelpOtherRequest, MessageTypeProto_pb.GuildHelpHelpOtherResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.GuildHelpHelpOtherResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end


--天宫秘宝活动数据
function NetManager.TreasureOfHeavenScoreRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EXPEDITION_TREASURE_INFO_REQUEST, MessageTypeProto_pb.EXPEDITION_TREASURE_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.ExpeditionTreasureInfoResponse()
        msg:ParseFromString(data)
        
        -- TreasureOfHeavenManger.GetTreasureState()
        TreasureOfHeavenManger.SetScore(msg.score)
        TreasureOfHeavenManger.SetLimitTime(msg.resetTime)
        TreasureOfHeavenManger.SetState(msg.treasureRewardState)
        if func then
            func(msg)
        end
    end)
end

--天宫秘宝任务领取
function NetManager.GetTreasureOfHeavenRewardRequest(uid,func)
    local data = Expedition_pb.ExpeditionTakeTreasureRequest()
    data.id = uid
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.EXPEDITION_TAKE_TREASURE_REWARD_REQUEST, MessageTypeProto_pb.EXPEDITION_TAKE_TREASURE_REWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = Expedition_pb.ExpeditionTakeTreasureResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--森罗幻境请求保存上阵
function NetManager.TrialHeroInfoSaveRequest(heroIds,func)
    local data = MapInfoProto_pb.TrialHeroInfoSaveRequest()
    for i = 1, #heroIds do
       data.heroIds:append(heroIds[i])
    end

    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TRIAL_HERO_INFO_SAVE_REQUEST, MessageTypeProto_pb.TRIAL_HERO_INFO_SAVE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        if func then
            func(msg)
        end
    end)
end


--试练副本领取宝箱奖励 type 0为单个领取 1为全部领取
function NetManager.GetTrialBoxRewardRequest(type,func)
    local data = MapInfoProto_pb.GetTrialBoxRewardRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TRIAL_GET_BOX_REQUEST, MessageTypeProto_pb.TRIAL_GET_BOX_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.GetTrialBoxRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--试练副本请求使用加血药 heroId 英雄ID
function NetManager.UseAddHpItemRequest(heroId,func)
    local data = MapInfoProto_pb.UseAddHpItemRequest()
    data.heroId = heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TRIAL_USE_ADD_HP_ITEM_REQUEST, MessageTypeProto_pb.TRIAL_USE_ADD_HP_ITEM_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.UseAddHpItemResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--排行榜初始化第一名 请求
function NetManager.RankFirstRequest(_types,activiteId,func)
    local data = PlayerInfoProto_pb.RankFirstRequest()
    for i = 1, #_types do
        data.types:append(_types[i])
    end
    for i = 1, #activiteId do
        data.activiteId:append(activiteId[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.RANK_GET_FIRST_REQUEST, MessageTypeProto_pb.RANK_GET_FIRST_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.RankFirstResponse()
        msg:ParseFromString(data)
        RankingManager.SetAllRankProud(_types,msg.proud)
        RankingManager.SetAllFirstRankProud(_types,msg.ranks)
        if func then
            func(msg)
        end
    end)
end
--排行膜拜请求
function NetManager.RankProudRequest(rankType,func)
    local data = PlayerInfoProto_pb.RankProudRequest()
    data.rankType = rankType
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.RANK_PROUD_REQUEST, MessageTypeProto_pb.RANK_PROUD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.RankProudResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 小游戏相关接口
-- 初始化数据
function NetManager.MiniGameInitRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_GAME_GET_REQUEST, MessageTypeProto_pb.MAP_GAME_GET_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapGameResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 小游戏操作
function NetManager.MiniGameOperateRequest(index, func)
    local data = MapInfoProto_pb.MapGameUpdateRequest()
    data.index = index
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MAP_GAME_UPDATE_REQUEST, MessageTypeProto_pb.MAP_GAME_UPDATE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.MapGameUpdateResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求领取竞技场宝箱数据
function this.TakeArenaBattleRewardRequest(missionId, func)
    local data = ArenaInfoProto_pb.TakeArenaBattleRewardRequest()
    data.missionId = missionId or 1
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TakeArenaBattleRewardRequest, MessageTypeProto_pb.TakeArenaBattleRewardResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.TakeArenaBattleRewardResponse()
        msg:ParseFromString(data)
        ArenaManager.SetHadTakeBoxData(missionId)
        if func then
            func(msg)
        end
    end)
end

--神将置换 的三个请求
function this.SaveHeroChangeRequest(_heroId,func)
    local data = HeroInfoProto_pb.SaveHeroChangeRequest()
    data.heroId = _heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SaveHeroChangeRequest, MessageTypeProto_pb.SaveHeroChangeResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.SaveHeroChangeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

function this.CancelHeroChangeRequest(_heroId,func)
    local data = HeroInfoProto_pb.CancelHeroChangeRequest()
    data.heroId = _heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CancelHeroChangeRequest, MessageTypeProto_pb.CancelHeroChangeResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.CancelHeroChangeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

function this.DoHeroChangeRequest(_heroId,func)
    local data = HeroInfoProto_pb.DoHeroChangeRequest()
    data.heroId = _heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.DoHeroChangeRequest, MessageTypeProto_pb.DoHeroChangeResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.DoHeroChangeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end


--改装厂回溯
function this.HeroStarBackRequest(_type,_tankId,func)
    local data = HeroInfoProto_pb.HeroStarBackRequest()
    data.type = _type
    data.tankId = _tankId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HeroStarBackRequest, MessageTypeProto_pb.HeroStarBackResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroStarBackResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--改装厂改装
function this.HeroExchangeRequest(_beforeTankId,_afterTankIds,func)
    local data = HeroInfoProto_pb.HeroExchangeRequest()
    data.beforeTankId = _beforeTankId
    for i = 1, #_afterTankIds do
        data.afterTankIds:append(_afterTankIds[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HeroExchangeRequest, MessageTypeProto_pb.HeroExchangeResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroExchangeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--竞技场点赞
function this.RedPackageLikeRequest(_uid,func)
    local data = ArenaInfoProto_pb.RedPackageLikeRequest()
    data.uid = _uid
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ARENA_REDPACKAGE_SEND_LIKE_REQUEST, MessageTypeProto_pb.ARENA_REDPACKAGE_SEND_LIKE_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end
--获取排行榜每天已点赞数
function this.ArenaGetAllSendLikeResponse(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ARENA_GET_ALL_SEND_LIKE_REQUEST, MessageTypeProto_pb.ARENA_GET_ALL_SEND_LIKE_RESPONSE , nil, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.GetAllSendLikeResponse()
        msg:ParseFromString(data)

        if func then
            func(msg)
        end
    end)
end

--联赛点赞
function this.ArenaTopMatchLikeRequest(_uid,func)
    local data = ArenaInfoProto_pb.RedPackageLikeRequest()
    data.uid = _uid
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CHAMPION_REDPACKAGE_SEND_LIKE_REQUEST, MessageTypeProto_pb.CHAMPION_REDPACKAGE_SEND_LIKE_RESPONSE , msg, function(buffer)
        if func then
            func()
        end
    end)
end
--获取联赛排行榜每天已点赞数
function this.ArenaTopMatchGetAllSendLikeResponse(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CHAMPION_GET_ALL_SEND_LIKE_REQUEST, MessageTypeProto_pb.CHAMPION_GET_ALL_SEND_LIKE_RESPONSE , nil, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.GetAllSendLikeResponse()
        msg:ParseFromString(data)

        if func then
            func(msg)
        end
    end)
end

--三强争霸请求界面基本数据
function this.SupremacyInitRequest(func)
    local data=SupremacyProto_pb.SupremacyInitRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SUPREMACY_INIT_GET_REQUEST, MessageTypeProto_pb.SUPREMACY_INIT_GET_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = SupremacyProto_pb.SupremacyInitResponse()
        msg:ParseFromString(data)
        HegemonyManager.InitHeroData(msg)
        if func then
            func(msg)
        end
    end)
end

--> 三强争霸战斗请求
function this.ContendHegemonyFightDataRequest(_fightId,_rank,_pos,_level, func)
    local data = FightInfoProto_pb.FightStartRequest()
    data.type = BATTLE_TYPE.CONTEND_HEGEMONY
    data.fightId = _fightId
    data.teamId = FormationManager.curFormationIndex
    data.rank = _rank
    data.pos = _pos
    data.level = _level
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.FIGHT_START_REQUEST, MessageTypeProto_pb.FIGHT_START_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = FightInfoProto_pb.FightStartResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 三强争霸挑战记录请求
function this.GetSupremacyBattleRecordRequest(_rank,_pos,func)
    local data = SupremacyProto_pb.GetSupremacyBattleRecordRequest()
    data.rank = _rank
    data.pos = _pos
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SUPREMACY_BATTLE_RECORD_REQUEST, MessageTypeProto_pb.SUPREMACY_BATTLE_RECORD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = SupremacyProto_pb.GetSupremacyBattleRecordResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求轩辕宝镜数据
function this.GetSituationInfoRequest(func)  
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SITUATION_INFO_GET_REQUEST, MessageTypeProto_pb.SITUATION_INFO_GET_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.GetAllSituationInfoResponse()
        msg:ParseFromString(data)
        XuanYuanMirrorManager.UpdateMirrorState(msg)
        if func then
            func(msg)
        end
    end)
end

--开始节点战斗操作
function NetManager.StartSituationChallengeRequest(id,type,func)
    local data = MapInfoProto_pb.SituationChallengeRequest()
    data.id = id
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SITUATION_CHALLENGE_REQUEST, MessageTypeProto_pb.SITUATION_CHALLENGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.SituationChallengeResponse()
        msg:ParseFromString(data)

        if func then
            func(msg)
        end
    end)
end

-- 梦魇入侵基本信息
function this.CarChallengeProgressIndication(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_CAR_CHALLENGE_INFO_REQUEST , MessageTypeProto_pb.GET_CAR_CHALLENGE_INFO_RESPONSE , nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.CarChallengeProgressIndication()
        msg:ParseFromString(data)
        GuildCarDelayManager.SetProgressData(msg)
        if func then
            func()
        end
    end)
end

-- 梦魇入侵请求购买
function this.MINSK_BATTLE_BUYCOUNT_REQUEST(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MINSK_BATTLE_BUYCOUNT_REQUEST  , MessageTypeProto_pb.MINSK_BATTLE_BUYCOUNT_RESPONSE , nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.CarChallengeProgressIndication()
        msg:ParseFromString(data)
        GuildCarDelayManager.RefreshCout(msg)
        if func then
            func()
        end
    end)
end

-- 梦魇入侵已次数购买信息
function this.GET_CAR_CHALLENGE_MY_INFO_REQUEST(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_CAR_CHALLENGE_MY_INFO_REQUEST , MessageTypeProto_pb.GET_CAR_CHALLENGE_MY_INFO_RESPONSE , nil, function(buffer)
        local data = buffer:DataByte()
        local msg = Family_pb.CarChallengeMyInfo()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--获取已有全部芯片
function NetManager.MedalGetAllRequest(func)
    local data = MedalProto_pb.MedalGetAllRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_GETALL_REQUEST, MessageTypeProto_pb.MEDAL_GETALL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MedalProto_pb.MedalGetAllReponse()
        msg:ParseFromString(data)
        MedalManager.InitAllMedalData(msg)
        if func then
            func(msg)
        end
    end)
end

--穿戴芯片
function NetManager.MedalWearRequest(_heroId,_medalId,_siteType,func)
    local data = MedalProto_pb.MedalWearRequest()
    data.heroId = _heroId
    data.medalId = _medalId
    data.siteType = _siteType
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_WEAR_REQUEST, MessageTypeProto_pb.MEDAL_WEAR_RESPONSE, msg, function(buffer)
        if func then
            func(msg)
        end
    end)
end

--卸下勋章
function NetManager.MedalUnloadRequest(_heroId,_siteType,_medalId,func)
    local data = MedalProto_pb.MedalUnloadRequest()
    data.heroId = _heroId
    data.siteType = _siteType
    data.medalId = _medalId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_UNLOAD_REQUEST, MessageTypeProto_pb.MEDAL_UNLOAD_RESPONSE, msg, function(buffer)
        if func then
            func(msg)
        end
    end)
end

--转化勋章
function NetManager.MedalConversionRequest(_medalId,_confMedalId,_heroid,_site,func)
    local data = MedalProto_pb.MedalChangeRequest()
    data.medalId = _medalId
    data.confMedalId = _confMedalId
    if _heroid and _site then
        data.heroId = _heroid
        data.position = _site
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_CHANGE_REQUEST, MessageTypeProto_pb.MEDAL_CHANGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MedalProto_pb.MedalGetOneReponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--洗练勋章
function NetManager.MedalRefineRequest(_medalId,lockPropertyId,func)
    local data = MedalProto_pb.MedalRefineRequest()
    data.medalId = _medalId
    for i = 1, #lockPropertyId do
        data.property:append(lockPropertyId[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_REFINE_REQUEST, MessageTypeProto_pb.MEDAL_REFINE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MedalProto_pb.MedalRefineResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--洗练临时数据
function NetManager.MedalRefineTempPropertyRequest(_medalId,func)
    local data = MedalProto_pb.MedalRefineTempPropertyRequest()
    data.medalId = _medalId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_REFINE_TEMPPROPERTY_REQUEST, MessageTypeProto_pb.MEDAL_REFINE_TEMPPROPERTY_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MedalProto_pb.MedalRefineTempPropertyResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 保存洗练勋章
function NetManager.MedalRefineConfirmRequest(_medalId,func)
    local data = MedalProto_pb.MedalRefineConfirmRequest()
    data.medalId=_medalId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_REFINE_CONFIRM_REQUEST, MessageTypeProto_pb.MEDAL_REFINE_CONFIRM_RESPONSE, msg, function(buffer)
        if func then
            func()
        end
    end)
end

-- 合成勋章
function NetManager.MedalMergeRequest(_medalId,lockPropertyId,func)
    local data = MedalProto_pb.MedalMergeRequest()
    for i = 1, #_medalId do
        data.medalId:append(_medalId[i])
    end
    
    -- for i = 1, #lockPropertyId do
    --     data.property:append(lockPropertyId[i])
    -- end

    for i = 1, #lockPropertyId do
        local c = data.property:add()
        c.id = lockPropertyId[i].id
        c.value = lockPropertyId[i].value
        -- c.position = i
        -- for j = 1, #consumeMaterials[i] do
        --     c.heroIds:append(consumeMaterials[i][j])
        -- end
    end
    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_MERGE_REQUEST, MessageTypeProto_pb.MEDAL_MERGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MedalProto_pb.MedalGetOneReponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
-- 出售勋章
function NetManager.MedalSellRequest(_medalId,func)
    local data = MedalProto_pb.MedalSellRequest()
    data.medalId = _medalId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_SELL_REQUEST, MessageTypeProto_pb.MEDAL_SELL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MedalProto_pb.MedalSellResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--社稷大典贡献点击
function this.SheJiDonateItemRequest(id,num,func)
    local data = ActivityProto_pb.CommitShejiActivityItemRequest()
    data.itemId = id
    data.itemNum = num
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CommitShejiActivityItemRequest, MessageTypeProto_pb.CommitShejiActivityItemResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ActivityProto_pb.CommitShejiActivityItemResponse()
        if func then
            func(msg)
        end
    end)
end
--社稷大典领取大宝箱奖励
function this.GetSheJiRewardRequest(id,func)
    local data = ActivityProto_pb.GetShejiAwardRequest()
    data.activityId = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetShejiAwardRequest, MessageTypeProto_pb.GetShejiAwardResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ActivityProto_pb.GetShejiAwardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--勘察
function NetManager.WorldProspectRequest(_type,_countType,func)--type:1=遗址地图消耗,2=钻石消耗  countType勘察数量 0=免费， 34=单次，35=10连
    local data = PlayerInfoProto_pb.WorldProspectRequest()
    data.type = _type
    data.countType = _countType
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORKSHOP_PROSPECT_REQUEST, MessageTypeProto_pb.WORKSHOP_PROSPECT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.WorldProspectResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--获取逍遥游地图列表数据
function this.JourneyGetInfoResponse(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.JOURNEY_GET_INFO_REQUEST, MessageTypeProto_pb.JOURNEY_GET_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.JourneyGetInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--勘察界面信息
function NetManager.WorldProspectInfoRequest(func)
    local data = PlayerInfoProto_pb.WorldProspectInfoRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORKSHOP_PROSPECT_INFO_REQUEST, MessageTypeProto_pb.WORKSHOP_PROSPECT_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.WorldProspectInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--获取逍遥游地图数据
function this.JourneyGetOneInfoResponse(mapId,func)
    local request = MapInfoProto_pb.JourneyGetOneInfoRequest()
    request.mapId  = mapId
    local msg = request:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.JOURNEY_GET_ONE_INFO_REQUEST, MessageTypeProto_pb.JOURNEY_GET_ONE_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.JourneyGetOneInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--摇骰子请求
function this.JourneyDoResponse(mapId,func)
    local request = MapInfoProto_pb.JourneyDoRequest()
    request.mapId  = mapId
    local msg = request:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.JOURNEY_DO_REQUEST, MessageTypeProto_pb.JOURNEY_DO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.JourneyDoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
function this.StartXiaoyaoBossFightRequest(index,func)
    local data = MapInfoProto_pb.JourneyFightRequest()
    data.monsterIndex = index
    data.mapId = XiaoYaoManager.curMapId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.JOURNEY_FIGHT_REQUEST, MessageTypeProto_pb.JOURNEY_FIGHT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.JourneyFightResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
function this.XiaoyaoyouTurnTableRequest(func)
    local data = MapInfoProto_pb.JourneyRandomRequest()
    data.mapId = XiaoYaoManager.curMapId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.JOURNEY_RANDOM_REQUEST, MessageTypeProto_pb.JOURNEY_RANDOM_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.JourneyRandomResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
function this.XiaoyaoyouGetHeroRequest(id,func)
    local data = MapInfoProto_pb.JourneyBuyRequest()
    data.goodsIndex = id
    data.mapId = XiaoYaoManager.curMapId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.JOURNEY_BUY_REQUEST, MessageTypeProto_pb.JOURNEY_BUY_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.JourneyBuyResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--易经宝库选择最终奖励
function this.SelectFinalRewardRequest(id,activityId,func)
    local data = ActivityProto_pb.SeletSubRewardPoolRequest()
    data.selectId = id
    data.activityId = activityId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SeletSubRewardPoolRequest, MessageTypeProto_pb.SeletSubRewardPoolResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ActivityProto_pb.SeletSubRewardPoolResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--勘察奖励领取
function NetManager.WorldProspectTotalRewardRequest(_count,func)
    local data = PlayerInfoProto_pb.WorldProspectTotalRewardRequest()
    data.count=_count
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORKSHOP_PROSPECT_TOTAL_REWARD_REQUEST, MessageTypeProto_pb.WORKSHOP_PROSPECT_TOTAL_REWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.WorldProspectTotalRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
function this.AllEndLessHeroDataResponse(_index,func)
    local data = HeroInfoProto_pb.GetEndlessHeroListInfoRequest()
    data.index = _index
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ENDLESS_HERO_LIST_INFO_REQUEST, MessageTypeProto_pb.GET_ENDLESS_HERO_LIST_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.GetEndlessHeroListInfoResponse()
        msg:ParseFromString(data)
        EndLessMapManager.InitAllEndlessHero(msg.heroList,true)
        if msg.isSendFinish then
            EndLessMapManager.InitMapInfoData(msg.endlessMapId)
            EndLessMapManager.InitFormation()
            if func then
                func(msg)
            end
        else
            _index = _index + #msg.heroList           
            this.AllEndLessHeroDataResponse(_index,func)
        end
    end)
end

--勘察记录
function NetManager.WORKSHOP_PROSPECT_RECORD_REQUEST(func)
    local data = PlayerInfoProto_pb.WorldProspectRecordRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORKSHOP_PROSPECT_RECORD_REQUEST, MessageTypeProto_pb.WORKSHOP_PROSPECT_RECORD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.WorldProspectRecordResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--情报中心升级
function NetManager.FormationCenterActiveRequest(func)
    local data = PlayerInfoProto_pb.InvestigateUpLevelRequest()    
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.INVESTIGATE_LEVEL_REQUEST , MessageTypeProto_pb.INVESTIGATE_LEVEL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.InvestigateUpLevelResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end   

-- 获取勋章套装存储信息
function NetManager.GetSavePosRequest(func)
    local data = MedalProto_pb.GetSavePosRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_GET_SAVEPOS_REQUEST, MessageTypeProto_pb.MEDAL_GET_SAVEPOS_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MedalProto_pb.GetSavePosReponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 购买套装方案位置
function NetManager.BuySavePosRequest(_medalSuitPlanId,func)
    local data = MedalProto_pb.BuySavePosRequest()
    data.pos=_medalSuitPlanId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_BUY_SAVEPOS_REQUEST, MessageTypeProto_pb.MEDAL_BUY_SAVEPOS_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MedalProto_pb.GetSavePosReponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 勋章套装方案穿戴
function NetManager.UseSavePosRequest(_heroId,_medalSuitPlanId,func)
    local data = MedalProto_pb.UseSavePosRequest()
    data.heroId = _heroId
    data.pos = _medalSuitPlanId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_USE_SAVEPOS_REQUEST, MessageTypeProto_pb.MEDAL_USE_SAVEPOS_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        if func then
            func()
        end
    end)
end

-- 勋章套装存储
function NetManager.WearSavePosRequest(_medalSuitPlanId,_medalList,func)
    local data = MedalProto_pb.WearSavePosRequest()
    data.pos=_medalSuitPlanId
    for i = 1, #_medalList do
        data.medalIds:append(_medalList[i])
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_WEAR_SAVEPOS_REQUEST, MessageTypeProto_pb.MEDAL_WEAR_SAVEPOS_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        if func then
            func()
        end
    end)
end

-- 勋章套装方案改名字
function NetManager.SetNameRequest(_medalSuitPlanId,_medalSuitPlanName,func)
    local data = MedalProto_pb.SetNameRequest()
    data.pos = _medalSuitPlanId
    data.name = _medalSuitPlanName
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_SETNAME_REQUEST, MessageTypeProto_pb.MEDAL_SETNAME_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        if func then
            func()
        end
    end)
end

-- 勋章一键卸下
function NetManager.MedalUnload2Request(_heroId,func)
    local data = MedalProto_pb.MedalUnload2Request()
    data.heroId = _heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.MEDAL_UNLOAD2_REQUEST, MessageTypeProto_pb.MEDAL_UNLOAD2_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        if func then
            func()
        end
    end)
end

-- 材料副本一键扫荡 --新增区分扫荡类型
function NetManager.CopyOneKeySweepRequest(_type,_useBuy ,func)
    local data = PlayerInfoProto_pb.CopyOneKeySweepRequest()
    data.type = _type
    data.useBuy=_useBuy 
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.COPY_ONEKEY_REQUEST , MessageTypeProto_pb.COPY_ONEKEY_RESPONSE , msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.CopyOneKeySweepResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--获取已有全部图腾
function NetManager.TotemListRequest(func)
    local data = HeroInfoProto_pb.TotemListRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TOTEM_LIST_REQUEST, MessageTypeProto_pb.TOTEM_LIST_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.TotemListResponse()
        msg:ParseFromString(data)
        TotemManager.InitAllTotemData(msg.totem)
        if func then
            func(msg)
        end
    end)
end
--穿戴图腾
function NetManager.TotemWearRequest(_totemId,_heroId,func)
    local data = HeroInfoProto_pb.TotemWearRequest()
    data.totemId=_totemId
    data.heroServiceId=_heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TOTEM_WEAR_REQUEST, MessageTypeProto_pb.TOTEM_WEAR_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        if func then
            func()
        end
    end)
end

--卸下图腾
function NetManager.TotemUnloadRequest(_heroId,func)
    local data = HeroInfoProto_pb.TotemUnloadRequest()
    data.heroServiceId=_heroId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TOTEM_UNLOAD_REQUEST, MessageTypeProto_pb.TOTEM_UNLOAD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        if func then
            func()
        end
    end)
end
--图腾升级&进阶
function NetManager.TotemLevelRequest(_totemId,func)
    local data = HeroInfoProto_pb.TotemLevelRequest()
    data.totemId=_totemId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TOTEM_LEVEL_REQUEST, MessageTypeProto_pb.TOTEM_LEVEL_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        if func then
            func()
        end
    end)
end

--图腾重置
function NetManager.TotemResetRequest(_totemId,func)
    local data = HeroInfoProto_pb.TotemResetRequest()
    data.totemId=_totemId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.TOTEM_RESET_REQUEST, MessageTypeProto_pb.TOTEM_RESET_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.TotemResetResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end


--特殊阵营镜像数据
function NetManager.GetTeamPosMirrorInfoRequest(_temaId,func)
    local data = HeroInfoProto_pb.GetTeamPosMirrorInfoRequest()
    data.teamId = _temaId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_TEAMPOS_MIRROR_INFO_REQUEST, MessageTypeProto_pb.GET_TEAMPOS_MIRROR_INFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.GetAllTeamPosResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end


--镜像英雄数据请求
function this.HeroMirrorInfoRequest(_teamId, func)
    local data = PlayerInfoProto_pb.ViewMirrorHeroInfoRequest()
    data.teamId = _teamId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_HERO_MIRRORINFO_REQUEST, MessageTypeProto_pb.GET_HERO_MIRRORINFO_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.ViewMirrorHeroInfoResponse()
        msg:ParseFromString(data)
        HeroTemporaryManager.InitHeroData(msg.info)
        if func then
            func()
        end
     
    end)
end

--获取副官招募信息
function NetManager.GetAdjutantActivityInfo(func)    
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADJUTANT_LAYERACTIVITY_INFO_REQUEST, MessageTypeProto_pb.ADJUTANT_LAYERACTIVITY_INFO_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = AdjutantProto_pb.AdjutantLayerActivityResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--副官招募
function NetManager.AdjutantActivityRecruit(layer,type,func)
    local data = AdjutantProto_pb.AdjutantLayerActivityRequest()
    data.layer = layer
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ADJUTANT_LAYERACTIVITY_REQUEST, MessageTypeProto_pb.ADJUTANT_LAYERACTIVITY_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = AdjutantProto_pb.AdjutantLayerActivityResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--跨服消息
function NetManager.GetWorldArenaInfoRequest(isPro, isfreash, func)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.laddersChallenge) then
        if func then
            func()
        end
        return
    end
    --在登录时防止弹活动未开启
    NetManager.WorldArenaUnLockRequest(function (msg)
        if msg.unLock then
            local data = gtwprotos.WorldProto_pb.GetWorldArenaInfoRequest()
            data.isPro = isPro
            data.isfreash = isfreash 
            local msg = data:SerializeToString()
            Network:SendMessageWithCallBack(MessageTypeProto_pb.GetWorldArenaInfoRequest, MessageTypeProto_pb.GetWorldArenaInfoResponse, msg, function(buffer)
                local data = buffer:DataByte()
                local msg = gtwprotos.WorldProto_pb.GetWorldArenaInfoResponse()
                msg:ParseFromString(data)
                LaddersArenaManager.ReceiveBaseArenaData(msg)
                if func then
                    func(msg)
                end
            end)
        else
            if func then
                func()
            end
        end
    end)
end

--跨服天梯挑战
function NetManager.GetWorldArenaChallengeRequest(teamId,challengeUid,challengeRank,myCurrentRank,isSkip,func)--挑战阵营 挑战敌人Uid 挑战敌人排名 自身排名
    local data = gtwprotos.WorldProto_pb.GetWorldArenaChallengeRequest()
    data.teamId = teamId
    data.challengeUid = challengeUid
    data.challengeRank = challengeRank
    data.myCurrentRank = myCurrentRank
    data.skipFight = isSkip

    -- data.skipFight = skipFight
    -- data.arenaEnemys = arenaEnemys
    -- data.fightTeamInfo = fightTeamInfo
    -- data.arenaEnemys = arenaEnemys     
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetWorldArenaChallengeRequest, MessageTypeProto_pb.GetWorldArenaChallengeResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = gtwprotos.WorldProto_pb.GetWorldArenaChallengeResponse()
        msg:ParseFromString(data)
      
        if func then
            func(msg)
        end
    end)
end

--跨服天梯挑战与被挑战记录
function NetManager.GetWorldArenaRecordInfoRequest(_type,func)
    local data = gtwprotos.WorldProto_pb.GetWorldArenaRecordInfoRequest()
    data.type = _type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetWorldArenaRecordInfoRequest, MessageTypeProto_pb.GetWorldArenaRecordInfoResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = gtwprotos.WorldProto_pb.GetWorldArenaRecordInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--跨服竞技场巅峰王者前三名请求
function NetManager.GetWorldArenaRankInfoRequest(isPro, func)
    local data = gtwprotos.WorldProto_pb.GetWorldArenaRankInfoRequest()
    data.isPro = isPro
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetWorldArenaRankInfoRequest, MessageTypeProto_pb.GetWorldArenaRankInfoResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = gtwprotos.WorldProto_pb.GetWorldArenaRankInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--跨服竞技场巅峰王者点赞
function NetManager.GetWorldArenaProudRequest(challengeUid, challengeRank, func)
    local data = gtwprotos.WorldProto_pb.GetWorldArenaProudRequest()
    data.challengeUid = challengeUid
    data.challengeRank = challengeRank
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GetWorldArenaProudRequest, MessageTypeProto_pb.GetWorldArenaProudResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = gtwprotos.WorldProto_pb.GetWorldArenaProudResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--炮击演练开炮
function NetManager.WordExchangeBombardActivityRequest(lotteryId,func)
    local data = PlayerInfoProto_pb.WordExchangeBombardActivityRequest()
    data.id = lotteryId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORDEXCHANGE_BOMBARD_ACTIVITY_REQUEST , MessageTypeProto_pb.WORDEXCHANGE_BOMBARD_ACTIVITY_RESPONSE , msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.WordExchangeBombardActivityResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 千抽请求信息
function NetManager.ThousandDrawInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ThousandDrawInfoRequest, MessageTypeProto_pb.ThousandDrawInfoResponse , nil, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.ThousandDrawInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 千抽抽卡/领卡
function NetManager.ThousandDrawRequest(isDraw, number, func)
    local data = PlayerInfoProto_pb.ThousandDrawRequest()
    data.isDraw = isDraw
    data.number = number
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ThousandDrawRequest, MessageTypeProto_pb.ThousandDrawResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.ThousandDrawCard()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 阵容推荐领奖情况
function NetManager.HeroCollectRewardInfo(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HeroCollectRewardInfoRequest, MessageTypeProto_pb.HeroCollectRewardInfoResponse, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroCollectRewardInfoResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 阵容推荐领奖
function NetManager.HeroCollectRewardRequest(id, index, func)
    local data = HeroInfoProto_pb.HeroCollectRewardRequest()
    data.id = id
    data.index = index
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HeroCollectRewardRequest, MessageTypeProto_pb.HeroCollectRewardResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = HeroInfoProto_pb.HeroCollectRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--扭蛋信息
function NetManager.BoxPoolListRequest(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BoxPoolListRequest, MessageTypeProto_pb.BoxPoolListResponse, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = ActivityProto_pb.BoxPoolInfoListResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--扭蛋/重置
function NetManager.BoxPoolOperateRequest(id, isReset, func)
    local data = ActivityProto_pb.BoxPoolOperateRequest()
    data.id = id
    data.reset = isReset
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BoxPoolOperateRequest, MessageTypeProto_pb.BoxPoolOperateResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ActivityProto_pb.BoxPoolOperateResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--设置是否显示vip
function NetManager.SetVipShowRequest(isShpwVip, func)
    local data = PlayerInfoProto_pb.SetVipShowRequest()
    data.showVip = isShpwVip
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SetVipShowRequest,MessageTypeProto_pb.SetVipShowResponse, msg, function(buffer)
        if func then
            func()
        end
    end)
end

--获取排行奖励信息
function NetManager.RankingInfoListRequest(func)
    local data = PlayerInfoProto_pb.RankingInfoListRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.RankingInfoListRequest ,MessageTypeProto_pb.RankingInfoListResponse , msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.RankingInfoListResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--获取奖励内容
function NetManager.RankingTakeRewardRequest(id, func)
    local data = PlayerInfoProto_pb.RankingTakeRewardRequest()
    data.id = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.RankingTakeRewardRequest,MessageTypeProto_pb.RankingTakeRewardResponse , msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.RankingTakeRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--英雄试炼 章节数据
function NetManager.ActivityChapterListRequest(func)
    local data = ActivityProto_pb.ActivityChapterListRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ActivityChapterListRequest, MessageTypeProto_pb.ActivityChapterListResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ActivityProto_pb.ActivityChapterListResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--英雄试炼扫荡
function NetManager.HeroTrialSweepRequest(id, func)
    local data = MapInfoProto_pb.HeroTrialSweepRequest()
    data.fightId = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.HeroTrialSweepRequest, MessageTypeProto_pb.HeroTrialSweepResponse, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = MapInfoProto_pb.HeroTrialSweepResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--卡牌主题：英雄驾到 招募
function NetManager.CardSubjectHeroGetActivityRequest(id, func)
    local data = PlayerInfoProto_pb.CardSubjectHeroGetActivityRequest()
    data.id = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CARD_SUBJECT_HERO_GET_ACTIVITY_REQUEST, MessageTypeProto_pb.CARD_SUBJECT_HERO_GET_ACTIVITY_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.CardSubjectHeroGetActivityResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--卡牌主题：英雄驾到 换心愿池
function NetManager.CardSubjeckWishPoolChangeRequest(activityId, id, func)
    local data = PlayerInfoProto_pb.CardSubjeckWishPoolChangeRequest()
    data.activityId = activityId
    data.id = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CARD_SUBJECT_WISH_POOL_CHANGE_REQUEST, MessageTypeProto_pb.CARD_SUBJECT_WISH_POOL_CHANGE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.CardSubjeckWishPoolChangeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--卡牌主题：英雄豪礼 免费领取
function NetManager.CardSubjectHeroLuxuryGetFreeRequest(activityId, id, func)
    local data = PlayerInfoProto_pb.CardSubjectHeroLuxuryGetFreeRequest()
    data.activityId = activityId
    data.id = id
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CARD_SUBJECT_HERO_LUXURY_GET_FREE_REQUEST, MessageTypeProto_pb.CARD_SUBJECT_HERO_LUXURY_GET_FREE_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.CardSubjectHeroGetFreeResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--卡牌主题：英雄豪礼 请求
function NetManager.CardSubjectHeroLuxuryGetRequest(activityId, func)
    local data = PlayerInfoProto_pb.CardSubjectHeroLuxuryGetRequest()
    data.activityId = activityId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CARD_SUBJECT_HERO_LUXURY_GET_REQUEST, MessageTypeProto_pb.CARD_SUBJECT_HERO_LUXURY_GET_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.CardSubjectHeroLuxuryGetResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--卡牌主题：初始化信息 请求
function NetManager.CardSubjectInitRequest(activityId, func)
    local data = PlayerInfoProto_pb.CardSubjectInitRequest()
    data.activityId = activityId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CARD_SUBJECT_INIT_REQUEST, MessageTypeProto_pb.CARD_SUBJECT_INIT_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.CardSubjectInitResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--worldLevel 世界等级 unLock跨服天梯是否解锁 true解锁，false未解锁
function NetManager.WorldArenaUnLockRequest(func)
    local data = ArenaInfoProto_pb.WorldArenaUnLockRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.WORLD_ARENA_UNLOCK_REQUEST, MessageTypeProto_pb.WORLD_ARENA_UNLOCK_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = ArenaInfoProto_pb.WorldArenaUnLockResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end



--混乱之治打开选择阵营 请求
function NetManager.CampSimpleInfoGetReq(func)
    -- local data = CampWar_pb.CampSimpleInfoGetReq()
    -- local msg = data:SerializeToString()
  --  Log("___________________select")
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CS_CampSimpleInfoGet, MessageTypeProto_pb.SC_CampSimpleInfoGet, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = CampWar_pb.CampSimpleInfoGetAck()
        msg:ParseFromString(data)
        ChaosManager.addCamp = msg.camp
        ChaosManager.lastMatchTime = msg.lastMatchTime
        --Log("______________________ select Return      ")
        if func then
            func(msg)
        end
    end)
end
--混乱之治设置阵营 请求
function NetManager.CampSetReq(campId,func)
    local data = CampWar_pb.CampSetReq()
    data.Camp = campId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CS_CampSet, MessageTypeProto_pb.SC_CampSet, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = CampWar_pb.CampSetAck()
        msg:ParseFromString(data)
        
        if func then
            func(msg)
        end
    end)
end

--混乱之治打开MainUI 请求   --有阵营
function NetManager.CampWarInfoGetReq(func)
        Network:SendMessageWithCallBack(MessageTypeProto_pb.CS_CampWarInfoGet, MessageTypeProto_pb.SC_CampWarInfoGet, nil, function(buffer)
            -- Log("_______________ main   return ")
             local data = buffer:DataByte()
             local msg = CampWar_pb.CampWarInfoGetAck()
             msg:ParseFromString(data)
             ChaosManager:SetChallegeData(msg)
            -- Log("________________________________msg.teamOneInfos main   "..#msg.teamOneInfos)
             ChaosManager:SetChaosTeams(msg.teamOneInfos)
             if func then
                 func(msg)
             end
         end)  
end
--混乱购买挑战次数 请求
function NetManager.CampWarChallengeNumsBuyReq(func)
    --Log("_______________ buy  OnClick  ")
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CS_CampWarChallengeNumsBuy, MessageTypeProto_pb.SC_CampWarChallengeNumsBuy, nil, function(buffer)
        --Log("_______________ buy   return ")
        local data = buffer:DataByte()
        local msg = CampWar_pb.CampWarChallengeNumsBuyAck()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end
--混乱匹配 请求
function NetManager.CampWarMatchReq(type,func)
   -- Log("_________________________   pipei OnClick  .."..type)
    local data = CampWar_pb.CampWarMatchReq()
    data.matchType = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CS_CampWarMatch, MessageTypeProto_pb.SC_CampWarMatch, msg, function(buffer)
       -- Log("_________________________   pipei   return")
        local data = buffer:DataByte()
        local msg = CampWar_pb.CampWarMatchAck()
        msg:ParseFromString(data)
       -- Log("________________________________msg.teamOneInfos pipei  "..#msg.teamOneInfos)
        ChaosManager:SetChaosTeams(msg.teamOneInfos)
       
        ChaosManager.lastMatchTime = msg.lastMatchTime
       -- Log("______________________ select Return   msg.lastMatchTime   "..msg.lastMatchTime)
        if func then
            func(msg)
        end
    end)
end

--混乱战报 请求
function NetManager.CampWarBattleRecordGetReq(battleRecordType,func)
   -- Log("______________________zhanbao OnClick")
   
        local data = CampWar_pb.CampWarBattleRecordGetReq()
        data.battleRecordType = battleRecordType
        local msg = data:SerializeToString()
        Network:SendMessageWithCallBack(MessageTypeProto_pb.CS_CampWarBattleRecordGetReq, MessageTypeProto_pb.SC_CampWarBattleRecordGetAck, msg, function(buffer)
        -- Log("______________________zhanbao return ")
            local data = buffer:DataByte()
            local msg = CampWar_pb.CampWarBattleRecordGetAck()
            msg:ParseFromString(data)
            if func then
                func(msg)
            end
        end)
end
--混乱挑战 请求
function NetManager.CampWarChallengeReq(uid,star,func)
    
    local data = CampWar_pb.CampWarChallengeReq()
    data.targetUserId = uid
    data.star = star
    local msg = data:SerializeToString()
   -- Log("__________challenge OnClick ")
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CS_CampWarChallengeReq, MessageTypeProto_pb.SC_CampWarChallengeAck, msg, function(buffer)
       -- Log("__________challenge return ")
        local data = buffer:DataByte()
        local msg = CampWar_pb.CampWarChallengeAck()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--混乱排行榜 请求
function NetManager.CampWarRankingListInfoGetReq(typeId,func)
   -- Log("__________rank  OnClick  ")
    local data = CampWar_pb.CampWarRankingListInfoGetReq()
    data.rankType = typeId
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.CS_CampWarRankingListInfoGetReq, MessageTypeProto_pb.SC_CampWarRankingListInfoGetAck, msg, function(buffer)
       -- Log("__________rank  return ")
        local data = buffer:DataByte()
        local msg = CampWar_pb.CampWarRankingListInfoGetAck()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--请求战令列表
function NetManager.GetAllEncouragePlanInfoRequest(func)
    local data = EncouragePlan_pb.GetAllEncouragePlanInfoRequest()
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.GET_ALL_ENCOURAGE_PLAN_REQUEST, MessageTypeProto_pb.GET_ALL_ENCOURAGE_PLAN_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = EncouragePlan_pb.GetAllEncouragePlanResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

--领取战令奖励
function NetManager.ObtainEncouragePlanRewardRequest(taskCfgId, obtainPos, func)
    local data = EncouragePlan_pb.ObtainEncouragePlanRewardRequest()
    data.taskCfgId = taskCfgId
    data.obtainPos = obtainPos
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.OBTAIN_ENCOURAGE_PLAN_REWARD_REQUEST, MessageTypeProto_pb.OBTAIN_ENCOURAGE_PLAN_REWARD_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = EncouragePlan_pb.ObtainEncouragePlanRewardResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

return this