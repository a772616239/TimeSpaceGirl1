require "Common/define"
require "Common/functions"
require "Logic/Network"
Protocal = {
    Connect		= '101';	--连接服务器
    Exception   = '102';	--异常掉线
    Disconnect  = '103';	--正常断线
    Message		= '104';	--接收消息
}

SocketType = {
    LOGIN = 1,
    MAP_FIGHT = 2,
}

SocketManager = {}
SocketManager.SocketList = {}
SocketManager.SocketDic = {}
function SocketManager.Start()
end

--卸载网络监听--
function SocketManager.Unload()
    for k,v in pairs(SocketManager.SocketList) do
        v:Unload()
    end
    SocketManager.SocketList = {}
    SocketManager.SocketDic = {}
end

function SocketManager.AddNetwork(type, ipAddress, port)
    if SocketManager.SocketList[type] then
        SocketManager.SocketList[type].socket:SetIpAddress(ipAddress, port)
        return
    end
    local socket = networkMgr:AddSocket(ipAddress, port)
    local network = Network.New(type, socket)
    network:Start()
    SocketManager.SocketList[type] = network
    SocketManager.SocketDic[socket] = network
end

function SocketManager.GetNetwork(type)
    return SocketManager.SocketList[type]
end

function SocketManager.Connect(type)
    if SocketManager.SocketList[type] then
        SocketManager.SocketList[type].socket:Connect()
    end
end

function SocketManager.TryConnect(type)
    if SocketManager.SocketList[type] then
        SocketManager.SocketList[type].socket:TryConnect()
    end
end

function SocketManager.Disconnect(type)
    if SocketManager.SocketList[type] then
        SocketManager.SocketList[type].socket:Close()
        SocketManager.SocketList[type]:Reset()
    end
end

--连接失败
function SocketManager.OnConnectFail(socket)
    if SocketManager.SocketDic[socket] then
        SocketManager.SocketDic[socket]:OnConnectFail()
    end
end

--重连3次失败
function SocketManager.OnReconnectFail(socket)
    if SocketManager.SocketDic[socket] then
        SocketManager.SocketDic[socket]:OnReconnectFail()
    end
end

--重新建立socket连接，回调lua方法
function SocketManager.OnReconnect(socket)
    if SocketManager.SocketDic[socket] then
        SocketManager.SocketDic[socket]:OnReconnect()
    end
end

--当连接建立时--
function SocketManager.OnConnect(socket)
    if SocketManager.SocketDic[socket] then
        SocketManager.SocketDic[socket]:OnConnect()
    end
end

--异常断线--
function SocketManager.OnException(socket)
    if SocketManager.SocketDic[socket] then
        SocketManager.SocketDic[socket]:OnException()
    end
end

--连接中断，或者被踢掉--
function SocketManager.OnDisconnect(socket)
    if SocketManager.SocketDic[socket] then
        SocketManager.SocketDic[socket]:OnDisconnect()
    end
end

function SocketManager.ReceiveErrorInfo(socket, msg)
    if SocketManager.SocketDic[socket] then
        SocketManager.SocketDic[socket]:ReceiveErrorInfo(msg)
    end
end

function SocketManager.ReceiveClientHeartBeat(socket, msg)
    if SocketManager.SocketDic[socket] then
        SocketManager.SocketDic[socket]:ReceiveClientHeartBeat(msg)
    end
end

