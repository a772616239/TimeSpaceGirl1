require "Message/RoomProto_pb"
--管理所有房间匹配的处理
RoomManager = {}

--房间类型
local ROOM_TYPE = {
    NO_ROOM = 0, --未在房间里
    MAP_FIGHT = 1, --血战玩法
}

local this = RoomManager
this.CurRoomType = ROOM_TYPE.NO_ROOM
this.RoomAddress = nil --（空 代表未匹配 “1”代表匹配中，其他是房间服务器地址信息（ip+“：” + port）形式）
this.IsMatch = 0
local Network

function this.Initialize()
    this.RoomAddress = nil
    Game.GlobalEvent:AddEvent(Protocal.Connect, this.RegisterMessage)
end

function this.RegisterMessage(network)
    if network.type ~= SocketType.LOGIN then return end
    Network = network
    network.socket:RegistNetMessage(MessageTypeProto_pb.ROOM_ADDRESS_INDICATION, this.OnRoomAddressIndication)
    --Game.GlobalEvent:DispatchEvent(GameEvent.Room.MatchSuccess)
end

--请求房间匹配
function this.RoomMatchRequest(type, func)
    local data = RoomProto_pb.RoomMatchRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ROOM_MATCH_REQUEST, MessageTypeProto_pb.ROOM_MATCH_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = RoomProto_pb.RoomMatchResponse()
        msg:ParseFromString(data)
        if msg.result then
            this.IsMatch = 1
            if func then
                func()
            end
        end
    end)
end

--请求取消房间匹配，必须处于请求匹配状态才能请求
function this.RoomCancelMatchRequest(type, func)
    local data = RoomProto_pb.RoomCancelMatchRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ROOM_CANCEL_MATCH_REQUEST, MessageTypeProto_pb.ROOM_CANCEL_MATCH_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = RoomProto_pb.RoomCancelMatchResponse()
        msg:ParseFromString(data)
        if msg.result then
            this.IsMatch = 0
            if func then
                func()
            end
        end
    end)
end

--重登时，在房间里，通过该接口获取游戏数据
function this.RoomReGetGameRequest(ipAddress)
    local ss = string.split(ipAddress, ":")  -- ip:port
    SocketManager.AddNetwork(SocketType.MAP_FIGHT, ss[1], tonumber(ss[2]))
    SocketManager.TryConnect(SocketType.MAP_FIGHT)
end

function this.OnRoomAddressIndication(buffer)
    local data = buffer:DataByte()
    local msg = RoomProto_pb.RoomAddressIndication()
    msg:ParseFromString(data)

    local ss = string.split(msg.address, ":")  -- ip:port
    SocketManager.AddNetwork(SocketType.MAP_FIGHT, ss[1], tonumber(ss[2]))
    SocketManager.TryConnect(SocketType.MAP_FIGHT)
    this.CurRoomType = msg.type
end

-- 请求血战数据
function this.RequestBloodyRank(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ROOM_LOGIN_REQEUST, MessageTypeProto_pb.ROOM_LOGIN_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = RoomProto_pb.RoomLoginResponse()
        msg:ParseFromString(data)
        if func then
            func(msg)
        end
    end)
end

-- 请求排行榜信息
-- 请求血战排行
function this.RequestBloodyRank(func)
    Network:SendMessageWithCallBack(MessageTypeProto_pb.BLOOD_RANK_REQUEST, MessageTypeProto_pb.BLOOD_RANK_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = RoomProto_pb.BloodRankResponse()
        msg:ParseFromString(data)

        if func then
            func(msg)
        end
    end)
end



return this