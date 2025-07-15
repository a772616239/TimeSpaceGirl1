local _isDebug = false
local specialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local function __DebugLog(str)
    if _isDebug then
    end
end

ChatManager = {}
local this = ChatManager

-- 定时刷新时间
local _DeltaTime = 2
-- 定时刷新数据的通道枚举
local _CHANNEL = {
    CHAT_CHANNEL.SYSTEM,     -- 系统
    CHAT_CHANNEL.GLOBAL,     -- 世界
    CHAT_CHANNEL.CrossRealm,     -- 跨服
}
this.SYS_MSG_TYPE = {
    [0] = {name = GetLanguageStrById(10384)},
    [1] = {name = GetLanguageStrById(10385)},
    [2] = {name = GetLanguageStrById(10386)},
    [10] = {name = GetLanguageStrById(10384)}   --充值
}

-- 聊天中要显示时间的时间间隔（毫秒）
this.ShowTimeDT = 300000

--初始化
function this.Initialize()
    -- 记录玩家上线的时间，小于这个时间的聊天消息（出好友外）不显示（毫秒）
    this.LoginTimeStamp = 0

    -- 数据
    this.ChatList = {}
    this.FriendChatList = {}

    -- msgId标志位，用于记录当前最新消息的消息号，刷新时按此消息号进行数据刷新
    this.MsgIdFlag = {}

    -- 我在世界发言中的时间冷却
    this.MyChatTimeStamp = 0

    -- 判断是否正在获取聊天信息(避免请求后台运行时请求积累)
    this.IsGetMsg = 0

    --跑马灯的速度(1秒移动的像素)
    this.horseRunSpeed = tonumber(specialConfig[31].Value)
end

-- 每两秒刷新一次数据
function this.TimeUpdate()
    if this.IsGetMsg > 0 then return end
    -- 不包括好友数据
    for _, channel in pairs(_CHANNEL) do
        local msgId = this.GetMsgIdFlag(channel)
        this.IsGetMsg = this.IsGetMsg + 1
        NetManager.RequestChatMsg(channel, msgId, function(data)
            this.IsGetMsg = this.IsGetMsg - 1
            this.ChatDataAdapter(channel, data)
        end)
    end
    -- 刷新主界面消息
    this.RefreshMainPanelShowMsg()
end

-- 开始刷新聊天数据
function this.StartChatDataUpdate()
    -- 开始定时刷新
    if not this._CountDownTimer then
        this._CountDownTimer = Timer.New(this.TimeUpdate, _DeltaTime, -1, true)
        this._CountDownTimer:Start()
    end

end
--关闭聊天数据刷新
function this.StopChatDataUpdate()
    -- 关闭定时刷新
    if this._CountDownTimer then
        this._CountDownTimer:Stop()
        this._CountDownTimer = nil
    end
end


-- 公会聊天数据由服务器推送
function this.ReceiveFamilyChat(msg)
    if msg.type ~= 2 then return end
    this.ChatDataAdapter(CHAT_CHANNEL.FAMILY, {chatInfo = {msg.chatInfo}})
end


-- 初始化数据
function this.InitData(func)
    -- 保存当前时间
    this.LoginTimeStamp = GetTimeStamp() * 1000
    -- 第一次获取数据
    local index = 0
    local maxIndex = 0
    local function serverCB(channel, data)
        -- 保存服务器数据
        this.ChatDataAdapter(channel, data)
        index = index + 1
        if index >= maxIndex then
            -- 刷新主界面消息
            this.RefreshMainPanelShowMsg()
            -- 执行回调
            if func then func() end
        end
    end
    -- 开始发送请求
    for _, channel in pairs(_CHANNEL) do
        maxIndex = maxIndex + 1
        NetManager.RequestChatMsg(channel, 0, function(data)
            serverCB(channel, data)
        end)
    end
end

-- 发送消息
function this.RequestSendChatMsg(channel, content, func)
    -- 好友消息不能通过此接口发送
    if CHAT_CHANNEL.FRIEND == channel then return end
    -- 限制发言等级
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.CHAT) then
        PopupTipPanel.ShowTipByLanguageId(10387)
        return
    end
    -- 消息正确性检测
    if string.len(content) <= 0 then
        PopupTipPanel.ShowTipByLanguageId(10388)
        return
    end
    -- 世界发言冷却时间
    if channel == CHAT_CHANNEL.GLOBAL then
        local curTimeStamp = GetTimeStamp()
        if curTimeStamp - this.MyChatTimeStamp < 10 then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10389), (10 - (curTimeStamp - this.MyChatTimeStamp))))
            return
        end
        this.MyChatTimeStamp = curTimeStamp
        -- 世界发言消息特殊处理
        content = string.format("%d|%s", GLOBAL_CHAT_TYPE.COMMON, content)
    elseif channel == CHAT_CHANNEL.FAMILY then
        -- 公会发言消息特殊处理
        content = string.format("%d|%s", GLOBAL_CHAT_TYPE.COMMON, content)
    end
    -- 检测屏蔽字（改为后端检测）
    -- 发送消息
    NetManager.RequestSendChatMsg(channel, content, 0,  function(msg)
        local msgId = this.GetMsgIdFlag(channel)    -- 获取当前最新消息的消息号
        --- messageId ~= 0 表示发送的消息包含屏蔽字段，该消息不会被广播，但是发送者在世界聊天中可以看到自己的消息
        --- 所以我们需要在前端保存这条消息，但是消息号设置为上一条的消息号，以保证在获取以后的数据时不会丢失数据。
        if msg.chatInfo.messageId ~= 0 then
            msg.chatInfo.messageId = -1
            local data = {
                chatInfo = {msg.chatInfo}
            }
            -- __DebugLog(GetLanguageStrById(10390))
            this.ChatDataAdapter(channel, data)
            if func then func() end
        else
            -- __DebugLog(GetLanguageStrById(10391))
            if channel == CHAT_CHANNEL.FAMILY then
                if func then func() end
            else
                NetManager.RequestChatMsg(channel, msgId, function(data)
                    if channel == 16 then
                        local count = PrivilegeManager.GetPrivilegeRemainValue(91001)
                        if count > 0 then
                            PrivilegeManager.RefreshPrivilegeUsedTimes(91001,1)
                        end
                    end
                    this.ChatDataAdapter(channel, data)
                    if func then func() end
                end)
            end
        end
    end)
end

-- 
function this.RequestGMCommand(command)
    -- 世界发言消息特殊处理
    local content = string.format("%d|%s", GLOBAL_CHAT_TYPE.COMMON, command)
    -- 请求发送
    NetManager.RequestSendChatMsg(CHAT_CHANNEL.GLOBAL, content, 0,  function(msg)
        PopupTipPanel.ShowTipByLanguageId(12198)
    end)
end

-- 设置相应通道的消息的最新消息号
function this.SetMsgIdFlag(channel, msgId)
    if not this.MsgIdFlag then
        this.MsgIdFlag = {}
    end
    this.MsgIdFlag[channel] = msgId
end
-- 获取最新消息号
function this.GetMsgIdFlag(channel)
    if not this.MsgIdFlag then
        this.MsgIdFlag = {}
    end
    return this.MsgIdFlag[channel] or 0
end

-- 数据处理
function this.ChatDataAdapter(channel, data)
    -- 好友数据特殊处理
    if channel == CHAT_CHANNEL.FRIEND then return end
    -- 先对数据排个序
    table.sort(data.chatInfo, function(a, b)
        return a.times < b.times
    end)
    -- 初始化
    if not this.ChatList[channel] then
        this.ChatList[channel] = {}
    end
    -- 数据没有变化，则不刷新
    local len = #data.chatInfo
    if len == 0 then return end

    --- 公会数据无需判断消息号
    if channel == CHAT_CHANNEL.FAMILY then
        -- __DebugLog("++++++++++++++++++++++++++++++"..channel)
        for i = 1, len do
            table.insert(this.ChatList[channel], data.chatInfo[i])
            -- __DebugLog(GetLanguageStrById(10392)..data.chatInfo[i].msg)
            -- 公会红包消息加入跑马灯显示
            local anaMsg = string.split(data.chatInfo[i].msg, "#")
            local msgType = tonumber(anaMsg[1])
            if msgType == GLOBAL_CHAT_TYPE.GUILD_REDPACKET then
                local content = this.AnalysisGlobalChat(data.chatInfo[i].msg).content
                local race = {
                    messageId = 0,
                    msg = content,
                    speed = this.horseRunSpeed,
                    multiple = 1,
                    times = 1 --data.chatInfo[i].times
                }

                HorseRaceManager.AddRaceData(race)

                -- if GuildRedPacketManager.isCheck then return end
                GuildRedPacketManager.isCheck = true
                CheckRedPointStatus(RedPointType.Guild_RedPacket)
            end
        end
        -- __DebugLog("++++++++++++++++++++++++++++++"..channel)
        -- 更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Chat.OnChatDataChanged, channel)
        return
    end

    --- 非公会
    --- 判断messageId是否符合要求，新数据得第一条messageId必须比旧数据最后一条大，
    --- mssageId相等表示包含敏感字未发出的消息，此消息需要在前端展示，但是不会发送给其他人
    -- __DebugLog("++++++++++++++++++++++++++++++"..channel)
    for i = 1, len do
        local newChat = data.chatInfo[i]
        local newMsgId = tonumber(newChat.messageId)     -- 新消息的消息号
        local msgIdFlag = this.GetMsgIdFlag(channel)    -- 获取当前最新消息号
        if msgIdFlag < newMsgId or newMsgId == -1 then
            if newMsgId ~= -1 then-- 消息号为-1表示屏蔽消息，保存数据但不保存消息号，
                this.SetMsgIdFlag(channel, newMsgId)    -- 保存当前消息的消息号，避免下次刷新时还会请求
            end
            -- if tonumber(newChat.times) > this.LoginTimeStamp then           -- 登录时间之前的消息都不显示
                if channel ~= CHAT_CHANNEL.SYSTEM or this.IsShowInChatPanel(newChat.messageType) then
                    if not GoodFriendManager.IsInBlackList(newChat.senderId) then   -- 判断是否在黑名单中
                        table.insert(this.ChatList[channel], newChat)
                        if #this.ChatList[channel] >= PUBLIC_CHAT_MAX_NUM then      -- 判断如果超出最大数量，删除最早得数据
                            table.remove(this.ChatList[channel], 1)
                        end
                    end
                end
                local showData=nil
                local addData = true
                if newChat.itemId ~= nil then
                    for i, v in ConfigPairs(HeroConfig) do
                        if newChat.itemId == v.Id then
                            showData ={}
                            showData = v
                            break
                        end
                    end
                end
               
                if showData ~= nil then
                    if showData.Material ~= nil and  showData.Material == 1 then
                        addData = false
                    end
                end
                -- 跑马灯数据，保存到跑马灯管理器中
                if this.IsShowInHorseRace(newChat.messageType) then
                    if addData then  --是否是材料英雄
                        HorseRaceManager.AddRaceData(newChat)
                    end
                end
        end
        -- __DebugLog("--")
    end
    -- __DebugLog("++++++++++++++++++++++++++++++"..channel)
    -- 更新事件
    Game.GlobalEvent:DispatchEvent(GameEvent.Chat.OnChatDataChanged, channel)
end

-- 获取好友聊天列表
function this.GetFriendChatChannelList()
    local list = {}
    local friendChatList = FriendChatManager.GetAllChatList()
    for friendId, chatList in pairs(friendChatList) do
        if GoodFriendManager.IsMyFriend(friendId) then
            -- 获取最后一条数据
            local chat = chatList[#chatList]
            -- 我发的消息前面加一个我
            local content = chat.msg
            if chat.senderId == PlayerManager.uid then
                content = GetLanguageStrById(10397)..content
            end
            local data = {
                friendId = friendId,
                content = content,
                times = chat.times
            }
            table.insert(list, data)
        end
    end

    -- 先对数据排个序
    table.sort(list, function(a, b)
        return a.times > b.times
    end)

    return list
end


-- 获取数据
function this.GetChatList(channel)
    -- 好友
    if channel == CHAT_CHANNEL.FRIEND then
        return this.GetFriendChatChannelList()
    end
    return this.ChatList[channel] or {}
end

-- 刷新主界面显示的消息
this._MainPanelChat = nil
local _MainChatList = {
    CHAT_CHANNEL.GLOBAL,
    CHAT_CHANNEL.SYSTEM,
    CHAT_CHANNEL.FAMILY,
}
function this.RefreshMainPanelShowMsg()
    -- 获取当前应该显示的数据
    local channel = nil
    local msg = nil
    for _, cnl in pairs(_MainChatList) do
        local chatList = this.GetChatList(cnl)
        local chat = chatList[#chatList]
        if chat then
            if not msg or msg.times < chat.times then
                channel = cnl
                msg = chat
            end
        end
    end
    -- 没有要显示的数据
    if not msg then return end
    -- 保存数据
    this._MainPanelChat = {
        channel = channel,
        chat = msg
    }
    -- 发送事件刷新
    Game.GlobalEvent:DispatchEvent(GameEvent.Chat.OnMainChatChanged)
end

-- 获取主界面显示的消息
function this.GetMainPanelShowMsg()
    return this._MainPanelChat
end

-- 请求发送公会邀请
function this.RequestSendGuildInvite(func)
    if not PlayerManager.familyId then return end
    -- 判断是否在冷却
    local _CurTimeStamp = GetTimeStamp()
    if this._GuildInviteTimeStamp and _CurTimeStamp - this._GuildInviteTimeStamp < GUILD_INVITE_CD then
        local cd = math.floor(GUILD_INVITE_CD - (_CurTimeStamp - this._GuildInviteTimeStamp))
        PopupTipPanel.ShowTip(cd..GetLanguageStrById(10398))
        return
    end
    -- 构建字符串
    local channel = CHAT_CHANNEL.GLOBAL
    local guildData = MyGuildManager.GetMyGuildInfo()
    local content = string.format(
    "%d#%d#%d#%s#%d#%d|",
            GLOBAL_CHAT_TYPE.GUILD_INVITE,
            PlayerManager.familyId,
            guildData.levle,
            guildData.name,
            guildData.playerIntoLevel,
            guildData.joinType
    )

    -- 发送消息
    NetManager.RequestSendChatMsg(channel, content, 0,  function()
        local msgId = this.GetMsgIdFlag(channel)
        NetManager.RequestChatMsg(channel, msgId, function(data)
            this.ChatDataAdapter(channel, data)
            if func then func() end
        end)
        this._GuildInviteTimeStamp = GetTimeStamp()
    end)
end
-- 请求发送公会援助邀请
function this.RequestSendGuildAid(itemId1,itemId2,func)
    if not PlayerManager.familyId then return end
    -- 构建字符串
    local channel = CHAT_CHANNEL.FAMILY
    local guildData = MyGuildManager.GetMyGuildInfo()
    local content = ""
    if itemId2 then
        content = string.format(
                ConfigManager.GetConfigData(ConfigName.ErrorCodeHint,121).Desc,
                PlayerManager.nickName,
                GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,itemId1).Name),
                tostring(ConfigManager.GetConfigData(ConfigName.GuildHelpConfig,1).RecourseTime[2]),
                GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,itemId2).Name),
                tostring(ConfigManager.GetConfigData(ConfigName.GuildHelpConfig,1).RecourseTime[2])
        )
    else

        content = string.format(
                ConfigManager.GetConfigData(ConfigName.ErrorCodeHint,120).Desc,
                PlayerManager.nickName,
                GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,itemId1).Name),
                tostring(ConfigManager.GetConfigData(ConfigName.GuildHelpConfig,1).RecourseTime[2])
        )
    end
    content = string.format(
            "%d#%s",
            GLOBAL_CHAT_TYPE.GUILD_AID,
            content
    )
    -- 发送消息
    NetManager.RequestSendChatMsg(channel, content, 0,  function()
        local msgId = this.GetMsgIdFlag(channel)
        NetManager.RequestChatMsg(channel, msgId, function(data)
            if func then func() end
        end)
    end)
end
-- 请求发送公会副本
function this.RequestSendGuildTranscript(func)
    if not PlayerManager.familyId then return end
    -- 构建字符串
    local channel = CHAT_CHANNEL.FAMILY
    local guildData = MyGuildManager.GetMyGuildInfo()
    local content = string.format(GetLanguageStrById(12311),PlayerManager.nickName)
    this.RequestSendChatMsg(channel, content, function()
    end)
end

-- 请求发送公会红包信息
function this.RequestSendRedPacket(curIndex,func)
    local redpack = ConfigManager.GetConfigData(ConfigName.GuildRedPackConfig,curIndex)
    if not PlayerManager.familyId then return end

    -- 构建字符串
    local channel = CHAT_CHANNEL.FAMILY

    local content = string.format(
        "%d#%s#%s",--"%d#%d#%d#%s#%d#%d|",
            GLOBAL_CHAT_TYPE.GUILD_REDPACKET,
            PlayerManager.nickName,
            redpack.Name
    )

    -- 发送消息
    NetManager.RequestSendChatMsg(channel, content, 0,  function()
        local msgId = this.GetMsgIdFlag(channel)
        NetManager.RequestChatMsg(channel, msgId, function(data)
            if func then func() end
        end)
    end)
end

-- 解析世界聊天数据
function this.AnalysisGlobalChat(msg)
    local chat = {}
    local msgList = string.split(msg, "|")
    local headStr = table.remove(msgList, 1)
    local headList = string.split(headStr, "#")
    chat.type = tonumber(headList[1])

    if chat.type == GLOBAL_CHAT_TYPE.COMMON then
        chat.content = table.concat(msgList, "|")
    elseif chat.type == GLOBAL_CHAT_TYPE.GUILD_INVITE then
        chat.gId = tonumber(headList[2])
        chat.gLv = tonumber(headList[3])
        chat.gName = headList[4]
        chat.gLimitLv = tonumber(headList[5])
        chat.joinType = tonumber(headList[6])
        chat.content = string.format(
                GetLanguageStrById(10399),
                chat.gLv,
                chat.gName,
                chat.gLimitLv)
    elseif chat.type == GLOBAL_CHAT_TYPE.GUILD_REDPACKET then
        chat.nickName = headList[2]
        chat.redpackName = headList[3]
        chat.content = string.format(GetLanguageStrById(10400),chat.nickName,chat.redpackName)
    elseif chat.type == GLOBAL_CHAT_TYPE.GUILD_AID then
        chat.content = headList[2]
    end
    return chat
end

-- 判断是否需要在聊天中显示
function this.IsShowInChatPanel(msgType)
    local config = ConfigManager.TryGetConfigDataByKey(ConfigName.SystemMessageConfig, "Type", msgType)
    if not config then return false end
    return config.SystemShow == 1
end
-- 判断是否需要在跑马灯中显示
function this.IsShowInHorseRace(msgType)
    local config = ConfigManager.TryGetConfigDataByKey(ConfigName.SystemMessageConfig, "Type", msgType)
    if not config then return false end
    return config.lanternShow == 1
end

return this