local ChatMaxSaveNum = 100      -- 每个好友本地数据最大保存聊天数量

FriendChatManager = {}
local this = FriendChatManager

this.FriendChatList = {}

this.NewChatFriendList = {}

function this.Initialize()
    -- 好友删除回调
    Game.GlobalEvent:AddEvent(GameEvent.Friend.OnFriendDelete, function(uid)
        FriendChatManager.SetFriendNewChatState(uid, false)
        -- 删除该好友的所有消息
        this.FriendChatList[uid] = nil
        this.SaveAllFriendChatToLocal() -- 保存一次本地数据
    end)
end

-- 好友数据单独处理
function this.ReceiveFriendChat(msg)
    if msg.type ~= 1 then return end
    -- 好友消息更新
    local friendId = msg.chatInfo.senderId
    this.FriendDataAdapter(friendId, msg.chatInfo)
    -- 保存到本地
    this.SaveFriendChatToLocal(friendId, msg.chatInfo)
    -- 设置新消息
    this.SetFriendNewChatState(friendId, true)
    -- 更新事件
    Game.GlobalEvent:DispatchEvent(GameEvent.Chat.OnChatDataChanged, CHAT_CHANNEL.FRIEND, friendId)
end

-- 初始化好友聊天数据
function this.InitData(func)
    NetManager.RequestChatMsg(CHAT_CHANNEL.FRIEND, 0, function(data)
        -- 好友，先加载本地数据
        this.LoadFriendChatFromLocal()
        this.LoadNewChatListFromLocal()
        -- 先对数据排个序
        table.sort(data.chatInfo, function(a, b)
            return a.times < b.times
        end)
        -- 数据解析
        for _, chat in ipairs(data.chatInfo) do
            if this.FriendDataAdapter(chat.senderId, chat) then
                -- 设置有最新消息
                this.SetFriendNewChatState(chat.senderId, true)
            end
        end
        -- 加载完成，向本地保存一次数据
        this.SaveAllFriendChatToLocal()
        if func then func() end
    end)
end


-- 好友消息处理
function this.FriendDataAdapter(friendId, data)
    -- 剔除自己得数据
    if friendId == PlayerManager.uid then return end
    -- 判断是否是好友
    if not GoodFriendManager.IsMyFriend(friendId) then return end
    -- 聊天数据保存
    if not this.FriendChatList then
        this.FriendChatList = {}
    end
    if not this.FriendChatList[friendId] then
        this.FriendChatList[friendId] = {}
    end
    table.insert(this.FriendChatList[friendId], data)
    -- 超出100条删除最老的一条
    if #this.FriendChatList[friendId] > ChatMaxSaveNum then
        table.remove(this.FriendChatList[friendId], 1)
    end
    return true
end

-- 发送消息
function this.RequestSendChatMsg(friendId, content, func)
    -- 消息正确性检测
    if string.len(content) <= 0 then
        PopupTipPanel.ShowTipByLanguageId(10388)
        return
    end

    -- 检测屏蔽字
    -- 发送消息
    NetManager.RequestSendChatMsg(CHAT_CHANNEL.FRIEND, content, friendId, function(msg)
        -- 给好友发送数据，自己的消息要本地保存
        local data = {
            senderId = PlayerManager.uid,
            times = tostring(GetTimeStamp()*1000),
            msg = msg.chatInfo.messageId == 0 and content or msg.chatInfo.msg,
        }
        this.FriendDataAdapter(friendId, data)
        -- 保存到本地
        this.SaveFriendChatToLocal(friendId, data)
        -- 更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Chat.OnChatDataChanged, CHAT_CHANNEL.FRIEND, friendId)
        if func then func() end
    end)
end


-- 获取数据
function this.GetFriendChatList(friendId)
    return this.FriendChatList[friendId] or {}
end

-- 获取全部数据
function this.GetAllChatList()
    return this.FriendChatList
end

-- 判断有该好友的新消息
function this.IsFriendNewChat(friendId)
    local index = table.indexof(this.NewChatFriendList, friendId)
    if index then return true end
    return false
end

-- 设置该好友有新消息
function this.SetFriendNewChatState(friendId, isNew)
    if isNew then
        local isMyFriend = GoodFriendManager.IsMyFriend(friendId)
        -- 是新消息，则判断是否已经在新消息表中了
        local index = table.indexof(this.NewChatFriendList, friendId)
        if not index and isMyFriend then
            table.insert(this.NewChatFriendList, friendId)
        elseif index and not isMyFriend then
            table.remove(this.NewChatFriendList, index)
        else
            return
        end
    else
        -- 移除新消息，从新消息表中移除并保存本地
        local index = table.indexof(this.NewChatFriendList, friendId)
        if not index then return end
        table.remove(this.NewChatFriendList, index)
    end
    this.SaveNewChatListToLocal()
    -- 检测红点显示
    CheckRedPointStatus(RedPointType.Chat_Friend)
end


---- 好友消息本地数据保存--------------

-- 消息内容中的  #  和 | 需特殊处理，避免在解读数据数出现错误
--   #  用  <1>  标识
--   |  用  <2>  标识
this.ChatLocalData = ""     -- 本地聊天数据字符串

-- 保存一条聊天数据到本地
function this.SaveFriendChatToLocal(friendId, chat)
    -- 剔除自己得数据
    if friendId == PlayerManager.uid then return end
    -- 判断是否是好友
    if not GoodFriendManager.IsMyFriend(friendId) then return end
    -- 对聊天内容进行处理
    local msg = chat.msg
    msg = string.gsub(msg,"#", "<1>")
    msg = string.gsub(msg,"|", "<2>")
    -- 构建数据
    local chatStr = string.format("%d#%d#%s#%s", friendId, chat.senderId, chat.times, msg)
    if this.ChatLocalData ~= "" then
        this.ChatLocalData = this.ChatLocalData .."|"
    end
    this.ChatLocalData = this.ChatLocalData .. chatStr
    -- 保存数据
    Util.WriteFileToDataPath("FriendChat/"..PlayerManager.uid, this.ChatLocalData)
    
    
    
end

-- 保存所有好友消息到本地
function this.SaveAllFriendChatToLocal()
    this.ChatLocalData = ""
    for friendId, chatList in pairs(this.FriendChatList) do
        for i = 1, #chatList do
            local chat = chatList[i]
            local msg = chat.msg
            msg = string.gsub(msg,"#", "<1>")
            msg = string.gsub(msg,"|", "<2>")
            -- 构建数据
            local chatStr = string.format("%d#%d#%s#%s", friendId, chat.senderId, chat.times, msg)
            if this.ChatLocalData ~= "" then
                this.ChatLocalData = this.ChatLocalData .."|"
            end
            this.ChatLocalData = this.ChatLocalData .. chatStr
        end
    end
    -- 保存数据
    Util.WriteFileToDataPath("FriendChat/"..PlayerManager.uid, this.ChatLocalData)
    
    
    
end


-- 从本地加载好友数据, 加载完成后，读取数据，删除多余的数据
function this.LoadFriendChatFromLocal()
    -- 获取本地数据
    this.ChatLocalData = Util.ReadFileFromDataPath("FriendChat/"..PlayerManager.uid) or ""
    
    
    
    if this.ChatLocalData == "" then return end
    -- 解析数据
    local chatList = string.split(this.ChatLocalData, "|")
    for i = 1, #chatList do
        local chat = string.split(chatList[i], "#")
        local friendId = tonumber(chat[1])
        local data = {
            senderId = tonumber(chat[2]),
            times = chat[3],
            msg = chat[4],
        }
        data.msg = string.gsub(data.msg,"<1>", "#")
        data.msg = string.gsub(data.msg,"<2>", "|")
        -- 聊天数据保存
        this.FriendDataAdapter(friendId, data)
    end
end


----- 好友新消息数据本地保存
function this.SaveNewChatListToLocal()
    local str = table.concat(this.NewChatFriendList, "|")
    PlayerPrefs.SetString("NewChatList" .. PlayerManager.uid, str)
end

function this.LoadNewChatListFromLocal()
    local str = PlayerPrefs.GetString("NewChatList" .. PlayerManager.uid)
    local list = string.split(str, "|")
    this.NewChatFriendList = {}
    -- 字符串转数字
    for i = 1, #list do
        if list[i] and list[i] ~= "" then
            local friendId = tonumber(list[i])
            if GoodFriendManager.IsMyFriend(friendId) then
                table.insert(this.NewChatFriendList, friendId)
            end
        end
    end
end

-- 红点相关
function this.CheckRedPotShow()
    local len = #this.NewChatFriendList
    if len == 0 then
        return false
    end
    if len == 1 and this.NewChatFriendList[1] == "" then
        return false
    end
    return true
end
return this