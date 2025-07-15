require "Message/SceneFight_pb"
require "Message/RoomProto_pb"
--require "Message/CommonProto_pb"
MapFightManager = {}

local this = MapFightManager
local Network

function this.Initialize()
    Game.GlobalEvent:AddEvent(Protocal.Connect, this.RegisterMessage)
end

function this.RegisterMessage(network)
    if network.type ~= SocketType.MAP_FIGHT then return end
    Network = network
    network.socket:RegistNetMessage(MessageTypeProto_pb.ROOM_START_GAME_INDICATION, this.OnRoomStartGame)
    network.socket:RegistNetMessage(MessageTypeProto_pb.SCENE_MSG_UPDATE_INDICATION, this.OnSceneInfoChange)
    network.socket:RegistNetMessage(MessageTypeProto_pb.SCENE_GAME_OVER_INDICATION, this.OnGameOver)

    Game.GlobalEvent:AddEvent(GameEvent.Room.GameStart, this.OnGameStart)
    this.RequestBloodyData()
end

this.selfAgent = nil
this.otherAgents = nil
this.walls = nil


-- 请求血战数据
function this.RequestBloodyData()

    Network:SendMessageWithCallBack(MessageTypeProto_pb.ROOM_LOGIN_REQEUST, MessageTypeProto_pb.ROOM_LOGIN_RESPONSE, nil, function(buffer)
        local data = buffer:DataByte()
        local msg = RoomProto_pb.RoomLoginResponse()
        msg:ParseFromString(data)

        this.OnGameDataPrepare(msg.roomMatchSuccessIndication)
    end)
end

--匹配成功，请求准备数据
function this.RoomStartGameReadyRequest(type)
    local data = RoomProto_pb.RoomStartGameReadyRequest()
    data.type = type
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.ROOM_START_GAME_READY_REQUEST, MessageTypeProto_pb.ROOM_START_GAME_READY_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = RoomProto_pb.RoomStartGameReadyResponse()
        msg:ParseFromString(data)
    end)
end

function this.OnRoomStartGame(buffer)
    local data = buffer:DataByte()
    local msg = RoomProto_pb.RoomStartGameIndication()
    msg:ParseFromString(data)


    Game.GlobalEvent:DispatchEvent(GameEvent.Room.GameStart, this.CurRoomType)
end

-- 初始化
function this.OnGameDataPrepare(msg)
   
    if msg.type ~= 1 then
        return
    end
    this.ParseSceneInfo(msg.sceneInfo)
    this.walls = msg.sceneInfo.barrierPoint
    UIManager.OpenPanel(UIName.MapFightPanel)

    --重登时有可能监听到角色正在行走
    if #this.selfAgent.path > 0 then
        table.reverse(this.selfAgent.path, 1, #this.selfAgent.path)
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.Move, this.selfAgent.playerUid, this.selfAgent.path)
    end
    for k, v in pairs(this.otherAgents) do
        if #v.path > 0 then
            table.reverse(v.path, 1, #v.path)
            Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.Move, k, v.path)
        end
    end

    this.buffList = {} --获取所有buff信息
    for i=1, #msg.sceneInfo.actorEffectBufferInfo do
        local buff = this.CreateBuff(msg.sceneInfo.actorEffectBufferInfo[i])
        this.buffList[buff.id] = buff
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.BuffAdd, buff)
    end

    this.mineralList = {} --获取所有散矿信息
    for i=1, #msg.sceneInfo.posMineral do
        local mineral = this.CreatePosMineral(msg.sceneInfo.posMineral[i])
        this.mineralList[mineral.pos] = mineral
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.MineralPointAdd, mineral)
    end

    -- 获取血战剩余时间
    if msg.sceneInfo.remainTime then FightUIManager.remainTime =  msg.sceneInfo.remainTime
    end


    this.RoomStartGameReadyRequest(RoomManager.CurRoomType)
end

function this.ParseSceneInfo(sceneInfo)
   
   
   
    this.otherAgents = {}  --获取所有agent信息
    for i=1, #sceneInfo.SceneActor do
        local agent = this.CreateAgent(sceneInfo.SceneActor[i])
        if agent.playerUid == PlayerManager.uid then
            this.selfAgent = agent
        else
            this.otherAgents[agent.playerUid] = agent
        end
    end
end

function this.CreateBuff(buffInfo)
    local buff = {}
    buff.id = buffInfo.id
    buff.type = buffInfo.type
    buff.startTime = buffInfo.startTime
    buff.endTime = buffInfo.endTime
    buff.target = buffInfo.target
    buff.caster = buffInfo.caster
    buff.value = buffInfo.value

    return buff
end

function this.CreateAgent(agentInfo)
    local agent = {}
    agent.playerUid = agentInfo.id
    agent.type = agentInfo.type
    agent.curXY = agentInfo.curPos
    agent.state = agentInfo.state --1 未准备 2 已准备 3 游戏开始 4 不可移动 5 移动
    agent.userName = agentInfo.userName --1 未准备 2 已准备 3 游戏开始 4 不可移动 5 移动

    if agentInfo.Creature then
        agent.curHp = agentInfo.Creature.curHp
        agent.maxHp = agentInfo.Creature.maxHp
        agent.camp = agentInfo.Creature.camp
        agent.path = agentInfo.Creature.path
        agent.mineral = agentInfo.Creature.mineral
        agent.speed = agentInfo.Creature.speed / 1000
        agent.killNum = agentInfo.Creature.killNums
    end

    -- 过滤出所有玩家， 初始化
    --if agentInfo.type == 1 then
    --    local playerInfo = {}
    --    playerInfo.id = agentInfo.id
    --    playerInfo.name = agentInfo.userName
    --    playerInfo.nineralNum = agentInfo.Creature.mineral
    --    playerInfo.killNum = agentInfo.Creature.killNums
    --    FightUIManager.playerInfo[agentInfo.id] = playerInfo
    --    --table.insert(FightUIManager.playerInfo, agentInfo.id, playerInfo)
    --end
    FightUIManager.UpDateRankInfo(agentInfo)

    return agent
end

function this.CreatePosMineral(mineralInfo)
   
   

    local mineral = {}
    mineral.pos = mineralInfo.pos
    mineral.nums = mineralInfo.nums

    return mineral
end

function this.OnGameOver(buffer)
   
    local data = buffer:DataByte()
    local msg = SceneFight_pb.SceneEndIndication()
    msg:ParseFromString(data)
    FightUIManager.SetFightResultScoreData(msg.sceneSimpleRankInfo) -- 保存分数数据

    SocketManager.Disconnect(SocketType.MAP_FIGHT)
    RoomManager.IsMatch = 0
    Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.GameEnd)
end

function this.OnSceneInfoChange(buffer)
   
    local data = buffer:DataByte()
    local msg = SceneFight_pb.BroadMsgIndication()
    msg:ParseFromString(data)

    
    for i=1, #msg.removeBufferId do
        local buffId = msg.removeBufferId[i]

        if this.buffList[buffId] then
           
            local buff = this.buffList[buffId]
            this.buffList[buffId] = nil
            Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.BuffRemove, buff)
        end
    end

    for i=1, #msg.removePosMineralId do
        local mineralId = msg.removePosMineralId[i]

        if this.mineralList[mineralId] then
           
            local mineral = this.mineralList[mineralId]
            this.mineralList[mineralId] = nil
            Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.MineralPointRemove, mineral)
        end
    end

    
    for i=1, #msg.removeActorId do
        local actorId = msg.removeActorId[i]

        if this.otherAgents[actorId] then
           
            local agent = this.otherAgents[actorId]
            this.otherAgents[actorId] = nil
            Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.AgentRemove, agent)
        end
    end

    
    for i=1, #msg.SceneActor do
        this.CheckActorInfoChange(msg.SceneActor[i])
    end

    
    for i=1, #msg.ActorEffectBufferInfo do
        this.CheckBuffChange(msg.ActorEffectBufferInfo[i])
    end

    for i=1, #msg.PosMineral do
        this.CheckMineralChange(msg.PosMineral[i])
    end

    -- 场景广播消息
    for i = 1, #msg.sceneMsg do
       
       

        UIManager.OpenPanel(UIName.CurlingTipPanel, tostring(msg.sceneMsg[i].msg))
    end


end

function this.CheckActorInfoChange(actorInfo)
   
    local agent
    if this.selfAgent.playerUid == actorInfo.id then
        agent = this.selfAgent
    else
        if this.otherAgents[actorInfo.id] then
            agent = this.otherAgents[actorInfo.id]
        else
            agent = this.CreateAgent(actorInfo)
            this.otherAgents[actorInfo.id] = agent
            Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.AgentAdd, agent)
            return
        end
    end

    agent.speed = actorInfo.Creature.speed / 1000

    if agent.curHp ~= actorInfo.Creature.curHp then
        agent.curHp = actorInfo.Creature.curHp
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.HPChange, actorInfo.id, actorInfo.Creature.curHp)
    end
    if agent.mineral ~= actorInfo.Creature.mineral then
        agent.mineral = actorInfo.Creature.mineral
        FightUIManager.UpDateRankInfo(actorInfo)
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.MineralChange, actorInfo.id, actorInfo.Creature.mineral)
    end
    agent.maxHp = actorInfo.Creature.maxHp
    agent.state = actorInfo.state

    if agent.killNums ~= actorInfo.Creature.killNums then
        agent.killNums = actorInfo.Creature.killNums
        FightUIManager.UpDateRankInfo(actorInfo)
    end


    if agent.curXY ~= actorInfo.curPos then
        
        
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.PositionChange, actorInfo.id, actorInfo.curPos)
    end

    if #actorInfo.Creature.path > 0 then
        if actorInfo.state == 5 then --怪触发战斗时，该状态不为5 但有巡逻路径，此时不能走
            
            --for i=1, #actorInfo.Creature.path do
                
            --end
            table.reverse(actorInfo.Creature.path, 1, #actorInfo.Creature.path)
            Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.Move, actorInfo.id, actorInfo.Creature.path)
        end
    else --后端推过来的路径为空时，需要打断本地的寻路路径
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.PositionChange, actorInfo.id, actorInfo.curPos)
    end

end

function this.CheckBuffChange(buffInfo)
   
    local buff
    if not this.buffList[buffInfo.id] then
        buff = this.CreateBuff(buffInfo)
        this.buffList[buff.id] = buff
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.BuffAdd, buff)
    else
        buff = this.buffList[buffInfo.id]
        local newBuff = this.CreateBuff(buffInfo)
        this.buffList[buff.id] = newBuff
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.BuffChange, buff, newBuff)
    end
end

function this.CheckMineralChange(mineralInfo)
   
    local mineral
    if not this.mineralList[mineralInfo.pos] then
        mineral = this.CreatePosMineral(mineralInfo)
        this.mineralList[mineralInfo.pos] = mineral
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.MineralPointAdd, mineral)
    else
        mineral = this.mineralList[mineralInfo.pos]
        local newMineral = this.CreatePosMineral(mineralInfo)
        this.mineralList[mineralInfo.pos] = newMineral
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.MineralPointChange, mineral, newMineral)
    end
end

function this.OnGameStart(type)
    if type ~= 1 then
        return
    end
end

--请求移动
function this.RoomSyncMyselfMoveRequest(pathList, func)
    local data = SceneFight_pb.SceneCommandRequest()
    data.type = 1

    table.reverse(pathList, 1, #pathList)

    for i = 1, #pathList do
        local point = pathList[i]
       
        data.parm:append(Map_UV2Pos(point.u, point.v))
    end
    local msg = data:SerializeToString()
    Network:SendMessageWithCallBack(MessageTypeProto_pb.SCENE_COMMAND_REQUEST, MessageTypeProto_pb.SCENE_COMMAND_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = SceneFight_pb.SceneCommandResponse()
        msg:ParseFromString(data)

        --指令类型 1：表示行走
        --行为结果 1 ： 成功 0：失败
        if msg.type == 1 and func then
            func(msg.result)
        end
    end)
end

return this