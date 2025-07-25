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

    RequestPanel.Show(GetLanguageStrById(23011))
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
    RequestPanel.Show(GetLanguageStrById(23012))
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
                RequestPanel.Show(GetLanguageStrById(23011))
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

        if not isHideMask then
            RequestPanel.Show(self.resendTimes > 0 and GetLanguageStrById(23017) or GetLanguageStrById(23016))
        end
        self.socket:SendMessageWithCallBack(nMsgId, nReMsgId, buffer, function(b)
            self.sendFlag = false
            self.resendTimes = 0
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
        end)
    end)
end

function Network:ReceiveErrorInfo(buffer)
    local data = buffer:DataByte()
    local msg = CommonProto_pb.ErrorResponse()
    msg:ParseFromString(data)

    self.sendFlag = false
    self.resendTimes = 0
    if self.sendFuncQueue.size > 0 then
        self.sendFuncQueue:Dequeue()
    end
    --waitingTimes = 0
    RequestPanel.Hide()
    -- 登录过程中报错
    LoadingPanel.ErrorStep(msg)

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
            RequestPanel.Show(GetLanguageStrById(23018))
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
