MyGuildManager = {}
local this = MyGuildManager
local guildSacrificeRewardConfig = ConfigManager.GetConfig(ConfigName.GuildSacrificeRewardConfig)
local guildHelpConfig = ConfigManager.GetConfig(ConfigName.GuildHelpConfig)
function this.Initialize()
    this.MyGuildInfo = nil
    this.MyMemInfo = nil
    this.MyGuildMemList = {}
    this.MyGuildApplyList = {}
    this.MyGuildLogList = {}
    this._MemWalkData = {}
    this.MyFeteInfo = {}
    
    --退出公会时间戳
    this.ExitTimeStamp = 0
end

-- 登录初始化数据
function MyGuildManager.InitBaseData(func)
    if PlayerManager.familyId == 0 then
        if func then func() end
        return
    end
    NetManager.RequestMyGuildInfo(func)
end

-- 初始化所有数据
function MyGuildManager.InitAllData(func)
    if PlayerManager.familyId == 0 then
        if func then func() end
        return
    end
    -- 有公会刷新一遍数据
    local step = 0
    local function _StepFunc()
        step = step + 1
        if step == 3 then
            if func then func() end
        end
    end
    NetManager.RequestMyGuildInfo(_StepFunc)
    this.RequestMyGuildMembers(_StepFunc)
    GuildFightManager.InitData(_StepFunc)
end

-- 设置我的公会信息
function MyGuildManager.SetMyGuildInfo(msg)
    -- 公会信息
    this.MyGuildInfo = msg.familyBaseInfo
    this.MyFeteInfo.score = this.MyGuildInfo.fete --登录时的奖励进度信息 后续数据刷新由MyGuildManager.MyFeteInfo.score操作
    if this.MyGuildInfo.id then
        PlayerManager.familyId = this.MyGuildInfo.id
    end
    -- 发送数据更新事件
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.DataUpdate)
end

-- 设置我的公会信息
function MyGuildManager.SetMyMemInfo(msg)
    -- 成员数据
    this.MyMemInfo = msg.familyUserInfo
    -- 发送数据更新事件
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.DataUpdate)
end

--设置我的祭祀信息
function MyGuildManager.SetMyFeteInfo(msg)
    this.MyFeteInfo.takeFeteReward = msg.familyUserInfo.takeFeteReward --祭祀领取进度
    this.MyFeteInfo.lastFeteGuildId = msg.familyUserInfo.lastFeteGuildId --上次祭祀公会id
    this.MyFeteInfo.lastFeteType = msg.familyUserInfo.lastFeteType --上次祭祀类型 //每日清除 5点推送
end
--设置祭祀 进度信息
function MyGuildManager.SetMyFeteInfo_ByScore(msg)
    this.MyFeteInfo.score = msg.score
end
--设置祭祀5点刷新 数据重置
function MyGuildManager.SetMyFeteInfo_FiveRefresh(msg)
    this.MyFeteInfo.takeFeteReward = msg.takeFeteReward
    this.MyFeteInfo.lastFeteType = msg.lastFeteType
end

--检测退出公会cd
function MyGuildManager.CheckGuildExitCdTime(_isShowTips)
    local isShowTips = _isShowTips or true
    local ExitTimeStamp =  this.ExitTimeStamp
    -- 判断是否在冷却 
    local _CurTimeStamp = GetTimeStamp()
    local stampTime =  tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,511).Value) * 3600
    if ExitTimeStamp and _CurTimeStamp - ExitTimeStamp < stampTime then
        if isShowTips then
            --local cd = math.floor(stampTime - (_CurTimeStamp - ExitTimeStamp))
            PopupTipPanel.ShowTip(this.GetGuildExitCdTips())
        end
        return false
    end
    return true
end

--获得退出公会的cd的提示
function MyGuildManager.GetGuildExitCdTips()
    return string.format(GetLanguageStrById(50264), ConfigManager.GetConfigData(ConfigName.SpecialConfig, 511).Value)
end


---============================ 行走相关======================================
-- 请求行走
function MyGuildManager.RequestWalk(pathlist, func)
    NetManager.GuildWalkRequest(pathlist, func)
end
-- 设置公会中玩家得行走数据
function MyGuildManager.SetWalkData(msg)
    this._MemWalkData = {}

    for i, data in ipairs(msg.familyWalkIndicaiton) do
        this._MemWalkData[data.uid] = data
    end

end
-- 更新行走数据
function MyGuildManager.UpdateWalkData(msg)
    if not this._MemWalkData then
        this._MemWalkData = {}
    end
    this._MemWalkData[msg.uid] = msg

    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.WalkUpdate, msg)
end
-- 获取所有行走数据
function MyGuildManager.GetMemWalkData()
    return this._MemWalkData
end
-- 获取某个成员得行走数据
function MyGuildManager.GetMemWalkDataById(uid)
    return this._MemWalkData[uid]
end
---============================ 行走相关end======================================


-- 获取日志信息
function MyGuildManager.RequestMyGuildLog(func)
    NetManager.RequestMyGuildLog(function(msg)
        this.MyGuildLogList = msg.familyLogInfo
        if func then func() end
        -- 发送日志数据更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.LogDataUpdate)
    end)
end

-- 获取成员信息
function MyGuildManager.RequestMyGuildMembers(func)
    NetManager.RequestMyGuildMembers(function(msg)
        this.MyGuildMemList = msg.familyUserInfo
        table.sort(this.MyGuildMemList, function(a, b)
            if a.seconds == b.seconds then
                return a.position < b.position
            end
            return a.seconds < b.seconds
        end)
        if func then func() end
        -- 发送成员数据更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.MemberDataUpdate)
    end)
end

-- 获取申请信息
function MyGuildManager.RequestMyGuildApplyList(func)
    NetManager.RequestMyGuildApply(function(msg)
        this.MyGuildApplyList = msg.familyApply
        if func then func() end
        -- 发送申请数据更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.ApplyDataUpdate)
        -- 刷新服务器红点
        ResetServerRedPointStatus(RedPointType.Guild_Apply)
    end)
end

-- 申请修改图腾
function MyGuildManager.RequestChangeLogo(logoId, func)
    NetManager.RequestChangeLogo(logoId, function(msg)
        this.MyGuildInfo.icon = logoId
        if func then func() end
        -- 发送申请数据更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.DataUpdate)
    end)
end

-- 获取我的公会信息
function MyGuildManager.GetMyGuildInfo()
    return this.MyGuildInfo
end

-- 获取我的公会的成员数据
function MyGuildManager.GetMyGuildMemList()
    return this.MyGuildMemList
end

-- 获取我的公会的会长信息
function MyGuildManager.GetMyGuildMasterInfo()
    for _, v in ipairs(this.MyGuildMemList) do
        if v.position == GUILD_GRANT.MASTER then
            return v
        end
    end
end

-- 获取公会成员数据
function MyGuildManager.GetMemInfo(memId)
    if not memId then return end
    for _, v in ipairs(this.MyGuildMemList) do
        if v.roleUid == memId then
            return v
        end
    end
end
-- 重置公会成员战斗力
function MyGuildManager.ResetMemForce(memId, force)
    if not memId then return end
    for _, v in ipairs(this.MyGuildMemList) do
        if v.roleUid == memId then
            v.soulForce = force
            break
        end
    end
    -- 发送数据更新事件
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.DataUpdate)
end

-- 获取我再公会中的数据
function MyGuildManager.GetMyMemInfo()
    return this.MyMemInfo
end

-- 获取公会日志数据
function MyGuildManager.GetMyGuildLog()
    return this.MyGuildLogList
end

-- 获取公会申请数据
function MyGuildManager.GetMyGuildApplyList()
    return this.MyGuildApplyList
end

-- 获取我在公会中的职位
function MyGuildManager.GetMyPositionInGuild()
    if PlayerManager.familyId == 0 then return end
    if not this.MyMemInfo then return end
    return this.MyMemInfo.position
end

-- 获取公会管理数量
function MyGuildManager.GetAdminMemNum()
    local num = 0
    for _, v in ipairs(this.MyGuildMemList) do
        if v.position == GUILD_GRANT.ADMIN then
            num = num + 1
        end
    end
    return num
end


---============== 操作=================
-- 请求操作申请数据
function MyGuildManager.OperateApply(opType, applyId, func)
    -- 公会战期间无法执行此操作
    --if opType == GUILD_APPLY_OPTYPE.ONE_AGREE or opType == GUILD_APPLY_OPTYPE.ALL_AGREE then
    --    if GuildFightManager.IsInGuildFight() then
    --        PopupTipPanel.ShowTip("公会战期间无法执行此操作")
    --        return
    --    end
    --end

    if opType == GUILD_APPLY_OPTYPE.ALL_AGREE or opType == GUILD_APPLY_OPTYPE.ALL_REFUSE then
        if #this.MyGuildApplyList == 0 then
            PopupTipPanel.ShowTipByLanguageId(10982)
            return
        end
    end
    NetManager.RequestOperateMyGuildApply(opType, applyId, function()
        if opType == GUILD_APPLY_OPTYPE.ALL_AGREE or opType == GUILD_APPLY_OPTYPE.ALL_REFUSE then
            this.MyGuildApplyList = {}
        elseif opType == GUILD_APPLY_OPTYPE.ONE_AGREE or opType == GUILD_APPLY_OPTYPE.ONE_REFUSE then
            local removeIndex = nil
            for i, v in ipairs(this.MyGuildApplyList) do
                if v.roleUid == applyId then
                    removeIndex = i
                    break
                end
            end
            -- 删除相应位置的数据
            if removeIndex then
                table.remove(this.MyGuildApplyList, removeIndex)
            end
        end
        -- 发送申请数据更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.ApplyDataUpdate)
        -- 成功回调
        if func then func() end
    end)
end

-- 请求修改公会宣言
function MyGuildManager.RequestChangeGuildAnnounce(announce, func)
    local pos = this.GetMyPositionInGuild()
    if pos == GUILD_GRANT.MEMBER then
        PopupTipPanel.ShowTipByLanguageId(10983)
        return
    end
    if not announce or announce == "" then
        PopupTipPanel.ShowTipByLanguageId(10984)
        return
    end
    NetManager.RequestChangeGuildBase(1, announce, function(msg)
        if msg.result == 0 then
            PopupTipPanel.ShowTip(msg.err)
            return
        end
        this.MyGuildInfo.annouce = announce
        if func then func() end
        -- 发送数据更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.DataUpdate)
    end)
end

-- 请求修改公会名称
function MyGuildManager.RequestChangeGuildName(name, func)
    local pos = this.GetMyPositionInGuild()
    if pos == GUILD_GRANT.MEMBER then
        PopupTipPanel.ShowTipByLanguageId(10985)
        return
    end
    -- 判断物品数量
    local cost = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).RenameCost
    local haveNum = BagManager.GetItemCountById(cost[1][1])
    if haveNum < cost[1][2] then
        PopupTipPanel.ShowTipByLanguageId(10847)
        return
    end
    if not name or name == "" then
        PopupTipPanel.ShowTipByLanguageId(10986)
        return
    end
    local config = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1)
    -- local minLen, maxLen = config.NameSize[1], config.NameSize[2] --多语言策划需求 GuildSetting 对名称设置失效
    local minLen, maxLen =NameManager.GetGuildNameLimit()
    local len = StringWidth(name)
    if len < minLen or len > maxLen then
        PopupTipPanel.ShowTipByLanguageId(10852)
        return
    end

    NetManager.RequestChangeGuildBase(0, name, function(msg)
        if msg.result == 0 then
            PopupTipPanel.ShowTip(msg.err)
            return
        end
        this.MyGuildInfo.name = name
        if func then func() end
        -- 发送数据更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.DataUpdate)
    end)
end
-- 请求修改公会申请类型
function MyGuildManager.RequestChangeJoinType(joinType, limitLevel,  func)
    local pos = this.GetMyPositionInGuild()
    if pos == GUILD_GRANT.MEMBER then return end

    NetManager.RequestChangeJoinType(joinType, limitLevel, function()
        this.MyGuildInfo.joinType = joinType
        if func then func() end
        -- 发送数据更新事件
        --Game.GlobalEvent:DispatchEvent(GameEvent.Guild.DataUpdate)
    end)
end

-- 请求退出公会
function MyGuildManager.RequestQuitGuild(func)
    -- 公会战期间无法执行此操作
    if GuildFightManager.IsInGuildFight() then
        PopupTipPanel.ShowTipByLanguageId(10908)
        return
    end
    local pos = this.GetMyPositionInGuild()
    if pos == GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10987)
        return
    end
    NetManager.RequestQuitGuild(function(msg)
        PlayerManager.familyId = 0
        this.MyGuildInfo = nil
        this.MyMemInfo = nil
        this.MyFeteInfo = {}
        this.MyGuildMemList = {}
        this.MyGuildApplyList = {}
        this.MyGuildLogList = {}
        MyGuildManager.ExitTimeStamp = msg.leaveTime
        if func then func() end
        -- 退出公会成功事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.OnQuitGuild)
        --清援助数据
        MyGuildManager.SetGuildHelpInfo_FiveRefresh()
        -- 退出公会成功
        PopupTipPanel.ShowTipByLanguageId(10988)
        -- 刷新服务器红点
        ResetServerRedPointStatus(RedPointType.Guild_Apply)
        ResetServerRedPointStatus(RedPointType.Guild_Shop)
        ResetServerRedPointStatus(RedPointType.Shop_Guild_Check)
    end)
end

-- 请求任命官职
function MyGuildManager.AppointmentPos(tId, tPos, func)
    -- 公会战期间无法执行此操作
    if GuildFightManager.IsInGuildFight() then
        PopupTipPanel.ShowTipByLanguageId(10908)
        return
    end

    if tId == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10959)
        return
    end

    -- 判断我是否有权限
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos == GUILD_GRANT.MEMBER then
        PopupTipPanel.ShowTipByLanguageId(10989)
        return
    end
    --
    if tPos == GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10958)
        return
    end
    -- 如果委任官员判断官员数量是否已达上限
    if tPos == GUILD_GRANT.ADMIN then
        local adminNum = this.GetAdminMemNum()
        local guildData = this.GetMyGuildInfo()
        local maxNum = ConfigManager.GetConfigData(ConfigName.GuildLevelConfig, guildData.levle).OfficalNum
        if adminNum >= maxNum then
            PopupTipPanel.ShowTipByLanguageId(10966)
            return
        end
    end
    -- 判断目标成员职位是否符合条件
    local tData = this.GetMemInfo(tId)
    if tPos == tData.position then
        PopupTipPanel.ShowTip(GetLanguageStrById(10990)..GUILD_GRANT_STR[tPos])
        return
    end
    -- 管理之间无法操作
    if pos == GUILD_GRANT.ADMIN and tData.position == GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10991)
        return
    end

    NetManager.RequestMyGuildAppointment(tId, tPos, function()
        -- 成员数据变动
        this.RequestMyGuildMembers()
        if func then func() end
    end)
end

-- 请求踢人
function MyGuildManager.RequestKickOut(tId, func)
    -- 公会战期间无法执行此操作
    if GuildFightManager.IsInGuildFight() then
        PopupTipPanel.ShowTipByLanguageId(10908)
        return
    end

    if tId == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(10959)
        return
    end

    -- 判断我是否有权限
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos == GUILD_GRANT.MEMBER then
        PopupTipPanel.ShowTipByLanguageId(10917)
        return
    end
    -- 判断目标职位是否符合条件
    local tData = this.GetMemInfo(tId)
    -- 管理之间无法操作
    if tData.position == GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10992)
        return
    elseif pos == GUILD_GRANT.ADMIN and tData.position == GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10991)
        return
    end

    NetManager.RequestKickOutFormMyGuild(tId, function()
        -- 成员数据变动
        this.RequestMyGuildMembers()
        if func then func() end
    end)
end

-- 请求退出公会
function MyGuildManager.RequestDismissGuild(dType, func)
    -- 公会战期间无法执行解散公会的操作
    if dType == 1 then
        if GuildFightManager.IsInGuildFight() then
            PopupTipPanel.ShowTipByLanguageId(10908)
            return
        end
    end
    local pos = this.GetMyPositionInGuild()
    if pos ~= GUILD_GRANT.MASTER then
        PopupTipPanel.ShowTipByLanguageId(10917)
        return
    end
    NetManager.RequestDismissGuild(dType, function()
        if func then func() end
        -- 解散公会成功
        local destroyTime = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).DestroyTime
        local timeStr = ""
        if destroyTime < 60 then
            timeStr = destroyTime .. GetLanguageStrById(10364)
        elseif destroyTime >= 60 and destroyTime < 3600 then
            timeStr = math.floor(destroyTime/60)..GetLanguageStrById(10036)
        else
            timeStr = math.floor(destroyTime/3600)..GetLanguageStrById(10993)
        end
        PopupTipPanel.ShowTip(dType == 1 and string.format(GetLanguageStrById(10994), timeStr) or GetLanguageStrById(10995))
        -- 发送数据更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.DismissStatusChanged)
    end)
end

-- 判断商店栏位是否解锁
local _SortUnLockLevel = nil
function MyGuildManager.GetGuildShopSortIsUnLock(sort)
    if not _SortUnLockLevel then
        _SortUnLockLevel = {}
        local guildLevelConfig = ConfigManager.GetConfig(ConfigName.GuildLevelConfig)
        for level, data in ConfigPairs(guildLevelConfig) do
            for sort = 1, data.ShopSort do
                if not _SortUnLockLevel[sort] then
                    _SortUnLockLevel[sort] = level
                end
            end
        end
    end
    local unLockLevel = _SortUnLockLevel[sort]
    -- 没有解锁等级 999级解锁
    if not unLockLevel then return false, 999 end
    -- 判断是否解锁
    local isUnLock = this.GetMyGuildInfo().levle >= unLockLevel
    return isUnLock, unLockLevel
end

---=========== 服务器推送方法================
-- 被提出公会
function MyGuildManager.BeKickOut(msg)
    -- uid 为0表示公会解散
        
    if msg.uid == PlayerManager.uid or msg.uid == 0 then
        PlayerManager.familyId = 0
        this.MyGuildInfo = nil
        this.MyMemInfo = nil
        this.MyFeteInfo = {}
        this.MyGuildMemList = {}
        this.MyGuildApplyList = {}
        this.MyGuildLogList = {}
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.BeKickOut)
        -- 添加tip显示
        GuildManager.AddGuildTip(GUILD_TIP_TYPE.KICKOUT, msg.uid)
        -- 刷新服务器红点
        ResetServerRedPointStatus(RedPointType.Guild_Apply)
        ResetServerRedPointStatus(RedPointType.Guild_Shop)
        ResetServerRedPointStatus(RedPointType.Shop_Guild_Check)
    else
        local rIndex = nil
        for index, mem in ipairs(this.MyGuildMemList) do
            if mem.roleUid == msg.uid then
                rIndex = index
                break
            end
        end
        if rIndex then
            local rMem = table.remove(this.MyGuildMemList, rIndex)
            Game.GlobalEvent:DispatchEvent(GameEvent.Guild.KickOut, rMem.roleUid)
        end
        
        --清除援助信息
        -- MyGuildManager.DelSingleGuildHelpInfo(msg.uid)
    end
end

-- 我的职位更新
function MyGuildManager.UpdateGuildPosition(msg)
    local pos = msg.position
    local uid = msg.uid
    if uid == PlayerManager.uid then
        local oldPos = this.MyMemInfo.position
        this.MyMemInfo.position = pos
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.PositionUpdate)
        -- 加入tip显示
        GuildManager.AddGuildTip(GUILD_TIP_TYPE.POS, pos, oldPos)
        -- 降职重置红点儿
        if pos == GUILD_GRANT.MEMBER then
            -- 刷新服务器红点
            ResetServerRedPointStatus(RedPointType.Guild_Apply)
        end
    end

    -- 更新成员列表里的职位
    for _, v in ipairs(this.MyGuildMemList) do
        if v.roleUid == uid then
            v.position = pos
            break
        end
    end
    -- 发送数据更新事件
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.MemberDataUpdate)
end


--公会捐献红点检测
function MyGuildManager.CheckGuildFeteRedPoint()
    if PlayerManager.familyId == 0 then
        return
    end
    if this.MyFeteInfo.lastFeteType == 0 then --未捐献
        return true
    end

    local d = {}--进度条可领取
    for i = 1, 3 do
        if  this.MyGuildInfo == nil or this.MyGuildInfo.id == nil then
            return
        end
        if this.MyFeteInfo.score >= guildSacrificeRewardConfig[i].Score and this.MyGuildInfo.id == this.MyFeteInfo.lastFeteGuildId then --有未领取 并且是当前公会 与上次捐献公会相同
            table.insert(d,i)
        end
    end

    for n = 1, #d do
        for index, v in ipairs(this.MyFeteInfo.takeFeteReward) do --已领
            if d[n] == v then
                table.remove(d,n) --删除已领数据 剩余未领取数据
            end
        end
    end

    local isOn = false
    --若剩余数据 有未领取
    isOn = #d > 0
    return isOn
end



this.isPanelRequest = false
--公会援助
function MyGuildManager.SetMyAidInfo(msg)
    this.MyFeteInfo.guildHelpInfo = msg.familyUserInfo.guildHelpInfo
    this.MyFeteInfo.guildHelpTime = msg.familyUserInfo.guildHelpTime
    this.MyFeteInfo.isTakeGuildHelpReward = msg.familyUserInfo.isTakeGuildHelpReward
    this.MyFeteInfo.GuildAidTimeStamp = msg.familyUserInfo.lastHelpSendTime
end
function MyGuildManager.SetMyAidBoxStateInfo(boxState)
    this.MyFeteInfo.isTakeGuildHelpReward = boxState
    MyGuildManager.RefreshAidRedPot()
end
this.allGuildHelpInfo = {}--援助 公会援助所有信息
--设置援助5点刷新 数据重置
function MyGuildManager.SetGuildHelpInfo_FiveRefresh()
    this.MyFeteInfo.guildHelpInfo = nil
    this.MyFeteInfo.guildHelpTime = 0
    this.allGuildHelpInfo = {}
    MyGuildManager.RefreshAidRedPot()
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildAid)
end
--初始化工会援助所有信息
function MyGuildManager.SetAllGuildHelpInfo(msg)
    for i = 1, #msg.guildHelpInfoIndication do
        if msg.guildHelpInfoIndication[i].uid and msg.guildHelpInfoIndication[i].uid > 0 then
            local singleHelpInfo = {}
            singleHelpInfo.uid = msg.guildHelpInfoIndication[i].uid
            singleHelpInfo.name = msg.guildHelpInfoIndication[i].name
            singleHelpInfo.guildHelpInfo = {}
            for j = 1, #msg.guildHelpInfoIndication[i].guildHelpInfo do
                if msg.guildHelpInfoIndication[i].guildHelpInfo[j].num ~= -1 then
                table.insert(singleHelpInfo.guildHelpInfo,{type = msg.guildHelpInfoIndication[i].guildHelpInfo[j].type,--碎片id
                                                                    num = msg.guildHelpInfoIndication[i].guildHelpInfo[j].num,--总获得数量
                                                                    hadtakenum = msg.guildHelpInfoIndication[i].guildHelpInfo[j].hadtakenum, })--已领取数量
                end
            end
             
            this.allGuildHelpInfo[msg.guildHelpInfoIndication[i].uid] = singleHelpInfo
        end
    end
    MyGuildManager.RefreshAidRedPot()
end
--当公会成员退出时清除求援信息
function MyGuildManager.DelSingleGuildHelpInfo(Deluid)
    
    for uid, value in pairs(this.allGuildHelpInfo) do
        if uid == Deluid then
            this.allGuildHelpInfo[uid] = nil
            Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildAid)
            MyGuildManager.RefreshAidRedPot()
        end
    end
end
--推送更新工会援助信息
function MyGuildManager.SetSingleGuildHelpInfo(msg)
     
     
    local isStarAdd = true
    for uid, value in pairs(this.allGuildHelpInfo) do
         
        if uid == msg.uid then
            isStarAdd = false
            this.allGuildHelpInfo[uid].uid = msg.uid
            this.allGuildHelpInfo[uid].name = msg.name
            this.allGuildHelpInfo[uid].guildHelpInfo = {}
             
            for j = 1, #msg.guildHelpInfo do

                if msg.guildHelpInfo[j].num ~= -1 then
                    table.insert(this.allGuildHelpInfo[uid].guildHelpInfo,{type = msg.guildHelpInfo[j].type,--碎片id
                                                               num = msg.guildHelpInfo[j].num,--总获得数量
                                                               hadtakenum = msg.guildHelpInfo[j].hadtakenum, })--已领取数量
                else
                    if this.allGuildHelpInfo[uid] then
                        this.allGuildHelpInfo[uid] = nil
                    end
                end
            end
        end
    end
    if isStarAdd then
        if msg.uid and msg.uid > 0 then
            local singleHelpInfo = {}
            singleHelpInfo.uid = msg.uid
            singleHelpInfo.name = msg.name
            singleHelpInfo.guildHelpInfo = {}
            
            for j = 1, #msg.guildHelpInfo do
                
                if msg.guildHelpInfo[j].num ~= -1 then
                    table.insert(singleHelpInfo.guildHelpInfo,{type = msg.guildHelpInfo[j].type,--碎片id
                                                               num = msg.guildHelpInfo[j].num,--总获得数量
                                                               hadtakenum = msg.guildHelpInfo[j].hadtakenum, })--已领取数量
                end
            end
             
            this.allGuildHelpInfo[msg.uid] = singleHelpInfo
        end
    end
    MyGuildManager.SetSingleGuildHelpInfoRefreshMyData(msg)
end
--自己发的援助更新自己信息
function MyGuildManager.SetSingleGuildHelpInfoRefreshMyData(msg)
    if msg then
        if msg.uid == PlayerManager.uid then
            
            this.MyFeteInfo.guildHelpInfo = msg.guildHelpInfo
        end
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildAid)
    MyGuildManager.RefreshAidRedPot()
end
--公会援助
function MyGuildManager.SetMyAidInfoHadtakenum(chipId,hadtakenum)
    if this.MyFeteInfo.guildHelpInfo and #this.MyFeteInfo.guildHelpInfo > 0 then
        for i = 1, #this.MyFeteInfo.guildHelpInfo do
            if this.MyFeteInfo.guildHelpInfo[i].type == chipId then
                this.MyFeteInfo.guildHelpInfo[i].hadtakenum = this.MyFeteInfo.guildHelpInfo[i].hadtakenum + hadtakenum
            end
            end
    end
    MyGuildManager.RefreshAidRedPot()
end
--更新自己援助次数
function MyGuildManager.SetSingleGuildHelpguildHelpTimeData()
    if this.MyFeteInfo.guildHelpTime and this.MyFeteInfo.guildHelpTime > 0 then
        this.MyFeteInfo.guildHelpTime = this.MyFeteInfo.guildHelpTime + 1
    else
        this.MyFeteInfo.guildHelpTime = 1
    end
    MyGuildManager.RefreshAidRedPot()
end
--更新自己援助CD时间
function MyGuildManager.SetGuildHelpCDTimeData()
    this.MyFeteInfo.GuildAidTimeStamp = GetTimeStamp()
end
function MyGuildManager.GetAllGuildHelpInfo()
    local curAllGuildHelpInfo = {}
     
   for key, value in pairs(this.allGuildHelpInfo) do
         
           for j = 1, #value.guildHelpInfo do
                local aidMaxNum = 5
                for k = 1, #guildHelpConfig[1].RecourseReward do
                    if guildHelpConfig[1].RecourseReward[k][2] == value.guildHelpInfo[j].type then
                        aidMaxNum = guildHelpConfig[1].RecourseReward[k][3]
                    end
                end
                 
                if aidMaxNum ~= value.guildHelpInfo[j].num and value.uid ~= PlayerManager.uid then
                    table.insert(curAllGuildHelpInfo,{type = value.guildHelpInfo[j].type,--碎片id
                                                      num = value.guildHelpInfo[j].num,--总获得数量
                                                      hadtakenum = value.guildHelpInfo[j].hadtakenum,
                                                      uid = value.uid,
                                                      name = value.name,
                    })--已领取数量
                end
            end
    end
     
    return curAllGuildHelpInfo
end
this.allGuildHelpRecordInfo = {}--援助 公会援助记录所有信息
--初始化工会援助记录所有信息
function MyGuildManager.SetAllGuildHelpLogInfo(msg)
    this.allGuildHelpRecordInfo = msg.guildHelpLog
end
--推送更新工会援助记录所有信息
function MyGuildManager.SetSingleGuildHelpLogInfo(msg)
    table.insert(this.allGuildHelpRecordInfo,msg.guildHelpLog)
end
--获取我的公会援助红点
function MyGuildManager.GetMyGuildHelpRedPoint()
    if not PlayerManager.familyId or PlayerManager.familyId == 0 then return false end
    if this.MyFeteInfo.guildHelpInfo then
        return #this.MyFeteInfo.guildHelpInfo < ConfigManager.GetConfigData(ConfigName.GuildHelpConfig,1).RecourseTime[1]
    else
        return true
    end
end
--获取公会军团援助红点
function MyGuildManager.GetMyAidOtherGuildHelpRedPoint()
    if not PlayerManager.familyId or PlayerManager.familyId == 0 or LengthOfTable(this.allGuildHelpInfo) < 1 then return false end
    for key, value in pairs(this.allGuildHelpInfo) do
        
        
        
        if value.uid ~= PlayerManager.uid and this.MyFeteInfo.guildHelpTime < ConfigManager.GetConfigData(ConfigName.GuildHelpConfig,1).HelpTime[1] 
        and LengthOfTable(value.guildHelpInfo) > 0  then
            for j = 1, #value.guildHelpInfo do
                local aidMaxNum = 5
                for k = 1, #guildHelpConfig[1].RecourseReward do
                    if guildHelpConfig[1].RecourseReward[k][2] == value.guildHelpInfo[j].type then
                        aidMaxNum = guildHelpConfig[1].RecourseReward[k][3]
                    end
                end
                 
                if aidMaxNum > value.guildHelpInfo[j].num then
                    
                    return true
                end
            end
        end
    end
    return false
end
--获取公会援助宝箱红点
function MyGuildManager.GetGuildHelpBoxRedPoint()
    if not PlayerManager.familyId or PlayerManager.familyId == 0 then return false end
    local chipMaxNum = ConfigManager.GetConfigData(ConfigName.GuildHelpConfig,1).RecourseTime[2]
    local curFinishAidChipNum = 0
    if this.MyFeteInfo.guildHelpInfo and #this.MyFeteInfo.guildHelpInfo > 0 then
        for i = 1, #this.MyFeteInfo.guildHelpInfo do
            local curguildHelpInfo = this.MyFeteInfo.guildHelpInfo[i]
            if curguildHelpInfo.hadtakenum == chipMaxNum then
                curFinishAidChipNum = curFinishAidChipNum + 1
            end
        end
    end
    if not MyGuildManager.MyFeteInfo.isTakeGuildHelpReward and curFinishAidChipNum >= ConfigManager.GetConfigData(ConfigName.GuildHelpConfig,1).RecourseTime[1] then
        return true
    end
    return false
end
function MyGuildManager.RefreshAidRedPot()
    if not PlayerManager.familyId or PlayerManager.familyId == 0 then return end
    CheckRedPointStatus(RedPointType.Guild_AidBox)
    CheckRedPointStatus(RedPointType.Guild_AidGuild)
    CheckRedPointStatus(RedPointType.Guild_AidMy)
end
function MyGuildManager.ShowGuildAidCdTime(_isShowTips)
    local isShowTips = _isShowTips or true
    -- 判断是否在冷却
    local _CurTimeStamp = GetTimeStamp()
    local stampTime = ConfigManager.GetConfigData(ConfigName.GuildHelpConfig,1).RecourseCD
    if this.MyFeteInfo.GuildAidTimeStamp and _CurTimeStamp - this.MyFeteInfo.GuildAidTimeStamp < stampTime then
        if isShowTips then
            local cd = math.floor(stampTime - (_CurTimeStamp - this.MyFeteInfo.GuildAidTimeStamp))
            PopupTipPanel.ShowTip(GetLanguageStrById(10997)..GetLeftTimeStrByDeltaTime(cd)..GetLanguageStrById(10998))
        end
        return false
    end
    return true
end

--> 联盟活跃 获取活跃属性
function MyGuildManager.GetLivenessAllPro(v)
    local livenessLv = nil
    if v == nil then
        livenessLv = MyGuildManager.GetLivenessData()
    else
        livenessLv = v
    end

    
    local guildActiveConfig = {}
    for _, value in ConfigPairs(ConfigManager.GetConfig(ConfigName.GuildActiveConfig)) do
        table.insert(guildActiveConfig, value)
    end
    table.sort(guildActiveConfig, function(a, b)
        return a.Lv < b.Lv
    end)

    local allPro = {}
    for i = 1, #guildActiveConfig do
        if livenessLv  >= guildActiveConfig[i].Lv then
            if next(guildActiveConfig[i].Prop) then
                for k, v in ipairs(guildActiveConfig[i].Prop) do
                    if #v == 2 then
                        if allPro[v[1]] == nil then
                            allPro[v[1]] = 0
                        end
                      
                        if livenessLv  == guildActiveConfig[i].Lv  then
                            allPro[v[1]] = allPro[v[1]] + v[2]
                        end


                    end
                end
            end
        else
            break
        end
    end

    return allPro
end

--> 获取联盟活跃数据 前端根据背包数量自己算数据 (联盟成员需要活跃度 新增的 取后端活跃度 自己的暂时走用道具自己算的 以确保一致)
function MyGuildManager.GetLivenessData()
    local guildActiveConfig = {}
    for _, value in ConfigPairs(ConfigManager.GetConfig(ConfigName.GuildActiveConfig)) do
        table.insert(guildActiveConfig, value)
    end
    table.sort(guildActiveConfig, function(a, b)
        return a.Lv < b.Lv
    end)

    local itemCnt = BagManager.GetItemCountById(guildActiveConfig[1].UpLv_Exp[1])   --< 取升级经验所需itemid 如果列itemid不同会出问题
    local reduceCnt = itemCnt
    local liveness = 0
    local isMax = false
    local curMaxExp = 0
    local lastRecordExp = 0
    for i = 1, #guildActiveConfig do
        if guildActiveConfig[i].UpLv_Exp[2] then
            if reduceCnt >= guildActiveConfig[i].UpLv_Exp[2] then
                --reduceCnt = reduceCnt - guildActiveConfig[i].UpLv_Exp[2]
                liveness = liveness + 1
                lastRecordExp = guildActiveConfig[i].UpLv_Exp[2]
            else
                reduceCnt = reduceCnt - lastRecordExp
                curMaxExp = guildActiveConfig[i].UpLv_Exp[2] - lastRecordExp
                break
            end
        else
            isMax = true
            break
        end
    end
    
    
    

    return liveness, reduceCnt, isMax, curMaxExp
end

return this