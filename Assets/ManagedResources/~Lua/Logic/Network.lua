require "Message/CommonProto_pb"
require "Message/MessageTypeProto_pb"
require "Base/Queue"
Network = {}
Network.__index = Network

function Network.New(type, socket)
    local instance = { type = type, socket = socket }

    instance.isConnected = false

    instance.waitingTimes = 0 --空闲时间
    instance.maxWaitingTimes = 20 -- 最大心跳等待时间（秒）
    instance.bIsStartListenHeartBeat = false

    instance.resendTimes = 0 --记录消息重发次数
    instance.sendFlag = false --监听收到消息的标记，发送时标记为true，收到消息则标记为false
    instance.maxResendTimes = 3 --最大重发次数，超过该时间则取消发送
    instance.sendWaitTime = 0 --记录消息等待时间（秒）
    instance.maxSendWaitTime = 5 --消息重发等待时间（秒），超过该时间会重发消息
    instance.sendFunc = nil --请求缓存
    instance.sendFuncQueue = Queue.New() --请求缓存列表，当一帧发送多个请求时，缓存等待上一个请求收到回调时，执行下一个请求
    instance.pendingReMsgId = nil --当前在途请求期待的回包 msgId（AbortPending 用来清掉 C# 侧的回调注册）
    instance.parallelBatch = 0 -- >0 表示处于并行批次中：这批请求不进串行队列，直接并发发出（登录并行分组用）

    instance.re_resendTimes = 0 --记录断线重发次数
    instance.reconnectFlag = false --记录断线重连标记
    instance.re_maxResendTimes = 2 --最大断线重发次数，超过该时间则取消发送
    instance.re_sendWaitTime = 0 --记录断线等待时间（秒）
    instance.re_maxSendWaitTime = 5 --消息断线重发等待时间（秒），超过该时间会重连

    instance.disconnectWaitTime = 0 --记录断开后等待时间，重连后会重新计算
    instance.maxDisconnectWaitTime = 180 --断开后最大等待时间

    setmetatable(instance, Network)
    return instance
end

function Network:Start()
    UpdateBeat:Add(self.Update, self)
end

--卸载网络监听--
function Network:Unload()
    UpdateBeat:Remove(self.Update, self)
end

--当连接建立时--
function Network:OnConnect()
    self.isConnected = true
    self.bIsStartListenHeartBeat = true
    Game.GlobalEvent:DispatchEvent(Protocal.Connect, self)
end

--异常断线--
function Network:OnException()
    MsgPanel.ShowOne(GetLanguageStrById(23010), function()
        Framework.Dispose()
        App.Instance:ReStart()
    end)
    self.bIsStartListenHeartBeat = false
    Game.GlobalEvent:DispatchEvent(Protocal.Exception, self)
end

--连接中断，或者被踢掉--
function Network:OnDisconnect()
    self.reconnectFlag = true
    self.isConnected = false
    self.bIsStartListenHeartBeat = false
    Game.GlobalEvent:DispatchEvent(Protocal.Disconnect, self)

    RequestPanel.Show(GetLanguageStrById(23011)) -- "您已掉线，正在请求重连"
    self.socket:TryReconnect()

    self.disconnectWaitTime = 0
end

function Network:SendClientHeartBeat()
    self.socket:SendHeartBeat()
end

function Network:ReceiveClientHeartBeat(buffer)
    local time = buffer:ReadIntToByte()
    Game.GlobalEvent:DispatchEvent(GameEvent.Network.OnReceiveHeartBeat, self, time)
end

--重新建立socket连接，回调lua方法
function Network:OnReconnect()
    RequestPanel.Hide()
    -- RequestPanel.Show(GetLanguageStrById(23012))
    self.re_resendTimes = 0
    self.disconnectWaitTime = 0
    self.reconnectFlag = false
    self.socket:SendMessageWithCallBack(MessageTypeProto_pb.RECONNECT_REQUEST, MessageTypeProto_pb.RECONNECT_RESPONSE, nil, function(b)
        RequestPanel.Hide()
        self.isConnected = true
        self.bIsStartListenHeartBeat = true
        Game.GlobalEvent:DispatchEvent(Protocal.Connect, self)
    end)
end

function Network:Reset()
    self.isConnected = false
    self.re_resendTimes = 0
    self.disconnectWaitTime = 0
    self.reconnectFlag = false
end

function Network:OnConnectFail()
    RequestPanel.Hide()
    MsgPanel.ShowOne(GetLanguageStrById(23013))
end

--重连3次失败
function Network:OnReconnectFail()
    self.re_resendTimes = self.re_resendTimes + 1
    if self.re_resendTimes > self.re_maxResendTimes then
        RequestPanel.Hide()
        MsgPanel.ShowTwo(GetLanguageStrById(23014), function()
            if AppConst.isSDKLogin then
                SDKMgr:Logout()
            else
                Framework.Dispose()
                App.Instance:ReStart()
            end
        end, function()
            if self.disconnectWaitTime >= self.maxDisconnectWaitTime then
                MsgPanel.ShowOne(GetLanguageStrById(23010), function()
                    Framework.Dispose()
                    App.Instance:ReStart()
                end)
            else
                -- RequestPanel.Show(GetLanguageStrById(23011))
                self.re_sendWaitTime = 0
                self.re_resendTimes = 0
            end
        end, GetLanguageStrById(23015))
    end
end

-- 发送消息
function Network:SendMessage(nMsgId, sMsg)
    local buffer = ByteBuffer.New()
    if sMsg then
        buffer:WriteBuffer(sMsg)
    end
    MyPCall(function()
        self.socket:SendMessage(nMsgId, buffer)
    end)
end

function Network:SendMessageWithCallBack(nMsgId, nReMsgId, sMsg, func, isHideMask)
    -- 并行批次内的请求不进串行队列：串行槽位一次只能有一个在途请求，
    -- 登录链 40 多步全靠它排队，一步一个 RTT（欧洲 ~288ms）。纯展示数据的请求彼此
    -- 没有依赖，让它们同时飞出去，N 个 RTT 压成 1 个。
    if (self.parallelBatch or 0) > 0 then
        return self:SendParallelMessage(nMsgId, nReMsgId, sMsg, func)
    end
    if not isHideMask then
        -- RequestPanel.Show(GetLanguageStrById(23016))
    end
    self.sendFuncQueue:Enqueue(function()
        local buffer = ByteBuffer.New()
        if sMsg then
            buffer:WriteBuffer(sMsg)
        end
        self.sendFlag = true
        self.sendWaitTime = 0
        self.pendingReMsgId = nReMsgId

        -- if not isHideMask then
        --     RequestPanel.Show(self.resendTimes > 0 and GetLanguageStrById(23017) or GetLanguageStrById(23016))
        -- end
        self.socket:SendMessageWithCallBack(nMsgId, nReMsgId, buffer, function(b)
            self.sendFlag = false
            self.resendTimes = 0
            self.pendingReMsgId = nil
            if self.sendFuncQueue.size > 0 then
                self.sendFuncQueue:Dequeue()
            end
            --waitingTimes = 0
            if func then
                func(b)
            end
            if not isHideMask then
                --该参数为空时，会在请求时显示全屏遮罩，防止误点击
                RequestPanel.Hide()
            end
            -- 同一个包的回调里（加载链会在这里入队下一步）立刻把下一个请求发出去，
            -- 不用等下一帧 Update：登录链 40 多步，每步省一帧，欧洲长链路能省 1s 以上。
            self:Flush()
        end)
    end)
    self:Flush()
end

-- 进入/退出并行批次（登录加载链的并行分组用）。
-- 批次期间发出的所有请求都走 SendParallelMessage：不占 sendFlag、不进 sendFuncQueue，
-- 包括成员回调里再发的后续请求（例如跨服先 UNLOCK 再取数据）。
function Network:BeginParallelBatch()
    self.parallelBatch = (self.parallelBatch or 0) + 1
end

function Network:EndParallelBatch()
    self.parallelBatch = math.max(0, (self.parallelBatch or 0) - 1)
end

-- 并发请求：直接发，不等串行槽位，回包只回调自己的 func。
-- 不重发：重发只会在服务端重复处理，超时由加载链的分组看门狗统一兜底。
function Network:SendParallelMessage(nMsgId, nReMsgId, sMsg, func)
    local buffer = ByteBuffer.New()
    if sMsg then
        buffer:WriteBuffer(sMsg)
    end
    if self.isConnected == false or not self.socket then
        -- 连接已断：直接算这个成员失败，别让整组等到看门狗超时
        LogRed(string.format("[Network] 并行请求 %s 时连接不可用，跳过", tostring(nMsgId)))
        if func then
            MyPCall(function() func(nil) end)
        end
        return
    end
    MyPCall(function()
        self.socket:SendMessageWithCallBack(nMsgId, nReMsgId, buffer, function(b)
            if func then
                MyPCall(function() func(b) end)
            end
        end)
    end)
end

-- 队列里还有待发请求且当前没有在途请求时，立刻发一个（等价于 Update 里的那段逻辑）
function Network:Flush()
    if self.sendFlag then return end
    if self.sendFuncQueue.size <= 0 then return end
    self.sendFunc = self.sendFuncQueue:Peek()
    MyPCall(self.sendFunc)
end

-- 放弃当前在途的请求：清掉"等待响应"状态、丢弃队首，并注销 C# 侧的回调注册。
-- 只给登录加载链的看门狗用：那条链只靠回调推进，某个响应永远不来时整个发送队列会堵死，
-- 之后所有请求都发不出去（现象＝加载条永久停在某个百分比、客户端静默无请求但心跳还在走）。
-- 注销回调是为了让迟到的响应被直接丢弃，不会再回调到已经推进过的步骤，造成连环跳步。
function Network:AbortPending()
    local reMsgId = self.pendingReMsgId
    self.pendingReMsgId = nil
    self.sendFlag = false
    self.resendTimes = 0
    self.sendWaitTime = 0
    if self.sendFuncQueue.size > 0 then
        self.sendFuncQueue:Dequeue()
    end
    if reMsgId and self.socket and self.socket.RemoveCallback then
        MyPCall(function() self.socket:RemoveCallback(reMsgId) end)
    end
end

function Network:ReceiveErrorInfo(buffer)
    local data = buffer:DataByte()
    local msg = CommonProto_pb.ErrorResponse()
    msg:ParseFromString(data)

    -- DEBUG: 打印服务端错误码
    print("[Network ERROR DEBUG] errCode = " .. tostring(msg.errCode) .. " errMsg = " .. tostring(msg.errMsg))
    if msg.errParams then
        for i = 1, #msg.errParams do
            print("[Network ERROR DEBUG]   errParams[" .. i .. "] = " .. tostring(msg.errParams[i]))
        end
    end

    self.sendFlag = false
    self.resendTimes = 0
    self.pendingReMsgId = nil
    if self.sendFuncQueue.size > 0 then
        self.sendFuncQueue:Dequeue()
    end
    --waitingTimes = 0
    RequestPanel.Hide()
    -- 登录过程中报错
    -- 并行批次里的报错只算"该成员失败"：C# 侧已经把它的回调摘掉了，再推进整条链会跳过还没回数据的步骤
    if (self.parallelBatch or 0) > 0 and LoadingPanel and LoadingPanel.GroupMemberFailed then
        MyPCall(function() LoadingPanel.GroupMemberFailed(msg) end)
    else
        LoadingPanel.ErrorStep(msg)
    end

    -- 过滤掉服务端"连接中"消息（语言ID 91000834），不弹任何Toast
    -- 服务端可能发送语言ID或已解析文本，使用string.find模糊匹配以防空格/编码差异
    local errMsg = tostring(msg.errMsg)
    if errMsg == "91000834"
        or string.find(errMsg, "连接中")
        or string.find(errMsg, "Connecting")
        or string.find(errMsg, "接続中")
        or string.find(errMsg, "연결중") then
        return
    end

    if msg.errCode == 20000 then
        if msg.errMsg == GetLanguageStrById(11590) then
            IndicationManager.canPopUpBagMaxMessage = true
        elseif msg.errMsg == GetLanguageStrById(11591) then
            IndicationManager.getRewardFromMailMessage = true
        else
            PopupTipPanel.ShowTip(GetLanguageStrById(msg.errMsg))
        end
        return
    elseif msg.errCode == -101 or msg.errCode == -102 then
        --被顶号或者被封号
        Framework.Dispose()
        App.Instance:ReStart()
        AppConst.Code = GetLanguageStrById(msg.errMsg) --TODO:重登会重置所有lua变量信息，用一个不用的C#变量记录，用于记录异常退出信息
        return
    end

    if msg.errCode == -1 then
        LogRed("服务器发来的错误消息："..msg.errMsg)
    end

    local errorCfg = ConfigManager.TryGetConfigData(ConfigName.ErrorCodeHint, msg.errCode)
    if errorCfg then
        if errorCfg.ShowType == 1 then --tips
            if errorCfg.Desc == nil or msg.errParams == nil then
                LogRed(string.format("打印：ErrorCodeHint表ID:%s 有问题", msg.errCode))
                return
            end
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(errorCfg.Desc), unpack(msg.errParams)))
        elseif errorCfg.ShowType == 2 then --弹窗
            local contexts = string.split(GetLanguageStrById(errorCfg.Desc), "#") --标题#内容
            if contexts[2] == nil or msg.errParams == nil then
                LogRed(string.format("打印：ErrorCodeHint表ID:%s 有问题", msg.errCode))
                return
            end
            MsgPanel.ShowOne(string.format(contexts[2], unpack(msg.errParams)), nil, nil, contexts[1])
        end
    end
end

--注册消息模块
function Network:RegisterMessage(nMsgId, pMessageHandle)
    self.socket:RegistNetMessage(nMsgId, pMessageHandle)
end

function Network:UnRegisterMessage(nMsgId, pMessageHandle)
    self.socket:UnregistNetMessage(nMsgId, pMessageHandle)
end

function Network:Update()    
    if self.reconnectFlag and self.re_resendTimes <= self.re_maxResendTimes then
        self.re_sendWaitTime = self.re_sendWaitTime + Time.fixedDeltaTime
        if self.re_sendWaitTime > self.re_maxSendWaitTime then
            -- RequestPanel.Show(GetLanguageStrById(23018))
            self.socket:TryReconnect()
            self.re_sendWaitTime = 0
        end
    end

    if not self.isConnected then
        -- 计算断线后的等待时间
        self.disconnectWaitTime = self.disconnectWaitTime + Time.fixedDeltaTime

        return
    end

    local dt = Time.fixedDeltaTime
    if self.bIsStartListenHeartBeat then
        self.waitingTimes = self.waitingTimes + dt
        if self.waitingTimes > self.maxWaitingTimes then
            self:SendClientHeartBeat()
            self.waitingTimes = 0
        end
    end

    if self.sendFlag then
        self.sendWaitTime = self.sendWaitTime + dt
        if self.sendWaitTime > self.maxSendWaitTime then
            if self.resendTimes < self.maxResendTimes then
                --logError("重发次数 :: " .. self.resendTimes)
                -- 重发后必须把等待时间清零：原来不重置，超过 5s 之后每一帧都会重发一次
                -- （3 帧内打完 3 次重发额度），请求在服务端被重复处理，日志里也是刷屏的重复包。
                self.sendWaitTime = 0
                MyPCall(self.sendFunc)
            elseif self.resendTimes == self.maxResendTimes then
                RequestPanel.Hide()
                MsgPanel.ShowTwo(GetLanguageStrById(23019), function()
                    Framework.Dispose()
                    App.Instance:ReStart()
                end, function()
                    self.resendTimes = 0
                end, GetLanguageStrById(23015))
            end
            self.resendTimes = self.resendTimes + 1
        end
    else
        if self.sendFuncQueue.size > 0 then
            self.sendFunc = self.sendFuncQueue:Peek()
            MyPCall(self.sendFunc)
        end
    end
end
