-- 管理Option表格的行为
-- 包含行为类型与跳转类

OptionBehaviourManager = {}
local this = OptionBehaviourManager
local OptionConfig = ConfigManager.GetConfig(ConfigName.OptionConfig)
local BHController = require("Modules/Mission/BHController")

--当前触发事件的界面
this.CurTriggerPanel = nil
function this.Initialize()
end

-- 下一个事件ID
this.nextEventId = nil
function this.SetNextEventId(eventId)
    this.nextEventId = eventId
end

--处理行为类型
function this.UpdateEventPoint(msg, optionId, func)
    -- 下一个事件ID
    this.nextEventId = msg.eventId
    -- 行为类型
    local behaviorType = msg.EventBehaviorCommon.behaviorType
    -- 推任务专用消息
    
    
    
    local beArgs = {}
    for i=1, #msg.EventBehaviorCommon.eventBehaviorValues do
        local item = msg.EventBehaviorCommon.eventBehaviorValues[i]
        local args = {}
        for j=1, #item.behaviorValues do
            
            args[j] = item.behaviorValues[j]
        end
        beArgs[i] = args
    end

    local behaviorNodeList = {}
    -- 行为类型判断
    if behaviorType == 1 then
        behaviorNodeList = {
            {"Battle", {monsterID = beArgs[1][1]}, this.SetNextEventId},
            {"MapProgressChange", {type = 2, curEventID = 0, monsterID = beArgs[1][1]}}
        }
    elseif behaviorType == 2 then --消耗物品
        behaviorNodeList = {
            {"SpendGoods", {itemList = beArgs}},
            {"ShowProgress", {content = "", time = 2}},
        }
    elseif behaviorType == 3 then  -- 侦查
    elseif behaviorType == 4 then
    elseif behaviorType == 5 then

        behaviorNodeList = {
            {"MoveTo", {mapID = beArgs[1][1], u = beArgs[1][2], v = beArgs[1][3] }},

        }
    elseif behaviorType == 6 then -- 进度条
        behaviorNodeList = {
            {"ShowProgress", {content = GetLanguageStrById(11383), time = beArgs[1][1]}},
            {"ShowReward", {drop = msg.drop}},
        }
    elseif behaviorType == 7 then --讨债任务
        behaviorNodeList = {
            {"NewPoint", {pointList = beArgs, startIndex = 2, dynamicPoints = msg.addMapInfo}},
        }
    elseif behaviorType == 8 then -- 吃buff
        behaviorNodeList = {
            {"Buff", {buffID = beArgs[1][1]}},
        }
    elseif behaviorType == 9 then -- 完成任务往下推一步， 并销毁当前事件点
        behaviorNodeList = {
            {"ParseMission", {mission = msg.mission, isInit = false, drop = msg.missionDrop}},
            {"DeletePoint", {pos = MapManager.curTriggerPos}},
        }
    elseif behaviorType == 10 then -- 监听打怪数量
        behaviorNodeList = {
            {"ParseMission", {mission = msg.mission, isInit = false, drop = msg.missionDrop}},
            {"NewPoint", {pointList = beArgs, startIndex = 2, dynamicPoints = msg.addMapInfo}},
        }
    elseif behaviorType == 11 then  -- 完成任务往下推一步， 并开启新的事件
        behaviorNodeList = {
            {"ParseMission", {mission = msg.mission, isInit = false, drop = msg.missionDrop}},
            {"NewPoint", {pointList = beArgs, startIndex = 2, dynamicPoints = msg.addMapInfo}},
        }
    elseif behaviorType == 13 then  -- 完成任务往下推一步， 不摧毁地图点
        behaviorNodeList = {
            {"ParseMission", {mission = msg.mission, isInit = false, drop = msg.missionDrop}},
        }
    elseif behaviorType == 14 then -- 完成任务往下推一步并消耗物品，不摧毁地图点
        behaviorNodeList = {
            {"ParseMission", {mission = msg.mission, isInit = false, drop = msg.missionDrop}},
            {"SpendGoods", {itemList = {[1] = beArgs[2]}}},
        }
        --local itemId = beArgs[2][1]
        --local itemCostNum = beArgs[2][2]
        --PopupTipPanel.ShowTip(string.format("消耗%d个%s", itemCostNum, ItemConfig[itemId].Name))

    elseif behaviorType == 15 then -- 销毁当前地图点
        behaviorNodeList = {
            {"ShowReward", {drop = msg.drop}},
            {"DeletePoint", {pointID = beArgs[1]}},
        }
    elseif behaviorType == 16 then -- 消耗道具并销毁指定地图点
        behaviorNodeList = {
            {"SpendGoods", {itemList = {[1] = beArgs[1]}}},
            {"DeletePoint", {pointID = beArgs[2]}},
        }
    elseif behaviorType == 17 then  --完成任务往下推一步， 摧毁指定地图点，开启新的地图点，完成所有地图任务再推一步任务
        --销毁指定地图点
        behaviorNodeList = {
            {"DeletePoint", {pointID = beArgs[1]}},
            {"NewPoint", {pointList = beArgs, startIndex = 2, dynamicPoints = msg.addMapInfo}},
            {"ShowReward", {drop = msg.drop}}
        }
    elseif behaviorType == 18 then  -- 战斗并销毁指定地图点
        behaviorNodeList = {
            {"Battle", {monsterID = beArgs[1][2]}, this.SetNextEventId},
            {"ParseMission",
             function(deliver)
                 return {mission = deliver.mission, isInit = false, drop = deliver.missionDrop}
             end},
            {"MapProgressChange", {type = 2, curEventID = 0, monsterID = beArgs[1][2]}},
            {"DeletePoint", {pointID = {beArgs[1][3]}}},
        }
    elseif behaviorType == 19 then  -- 完成任务往下推一步， 行动到指定地图指定地图点，不摧毁地图点
        behaviorNodeList = {
            {"ParseMission", {mission = msg.mission, isInit = false, drop = msg.missionDrop}},
            {"MoveTo", {mapID = beArgs[1][2], u = beArgs[1][3], v = beArgs[1][4]}},
        }
    elseif behaviorType == 20 then -- 战斗并销毁指定地图点
        behaviorNodeList = {
            {"Battle", {monsterID = beArgs[1][1]}, this.SetNextEventId},
            {"MapProgressChange", {type = 2, curEventID = 0, monsterID = beArgs[1][1]}},
            {"DeletePoint", {pointID = {beArgs[1][2]}}},
        }

    elseif behaviorType == 22 then -- 完成任务往下推一步，行动到某张地图某坐标点，摧毁指定地图点
        behaviorNodeList = {
            {"ParseMission", {mission = msg.mission, isInit = false, drop = msg.missionDrop}},
            {"DeletePoint", {pointID = {beArgs[1][2]}}},
            {"MoveTo", {mapID = beArgs[1][3], u = beArgs[1][4], v = beArgs[1][5]}},
        }
    elseif behaviorType == 23 then  --第一次触发时，完成任务往下推一步。
    elseif behaviorType == 24 then  --服务器跳转地图点到指定状态，客户端不读取新事件

    elseif behaviorType == 25 then  --完成任务往下推一步，销毁当前地图点，服务器跳转地图点到指定状态，客户端不读取新事件  4#103018#103019   任务id#地图点id#新事件id
        behaviorNodeList = {
            {"ParseMission", {mission = msg.mission, isInit = false, drop = msg.missionDrop}},
            {"DeletePoint", {pos = MapManager.curPos}},
        }
    elseif behaviorType == 26 then -- 在主界面接受任务, 并开启新任务
    elseif behaviorType == 27 then -- 服务器推送下一个任务
    elseif behaviorType == 28 then -- 扣除行动力
        local num = beArgs[1][1]

        Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressChange, 6, 0, 0, num, false)

    elseif behaviorType == 29 then  -- 消耗道具并销毁当前位置
        behaviorNodeList = {
            {"SpendGoods", {itemList = beArgs}},
        }
        if #msg.drop.itemlist > 0 or #msg.drop.equipId > 0 or  #msg.drop.Hero > 0 then
            table.insert(behaviorNodeList,{"ShowProgress", {content = GetLanguageStrById(11386), time = 2}})
            table.insert(behaviorNodeList,{"DeletePoint", {pos = MapManager.curTriggerPos}})
            table.insert(behaviorNodeList,{"ShowReward", {drop = msg.drop}})
            table.insert(behaviorNodeList,{"MapProgressChange", {type = 5, curEventID = optionId}})
        end
    elseif behaviorType == 30 then -- 生成新的地图点
        behaviorNodeList = {
            {"NewPoint", {pointList = beArgs, startIndex = 1, dynamicPoints = msg.addMapInfo}},
            {"ShowReward", {drop = msg.drop}}
        }
    elseif behaviorType == 31 then -- 地图内传送
        behaviorNodeList = {
            {"MoveTo", {u = beArgs[1][1], v = beArgs[1][2]}}
        }
    elseif behaviorType == 32 then
        behaviorNodeList = {
            {"Battle", {monsterID = beArgs[1][1]}, this.SetNextEventId},
            {"ParseMission", function (result)
                return {mission = result.mission, isInit = false, drop = result.missionDrop}
            end},
            {"MapProgressChange", {type = 2, curEventID = 0, monsterID = beArgs[1][1]}},
            {"DeletePoint", {pointID = {beArgs[1][2]}}} ,
            {"NewPoint", {pointList = beArgs, startIndex = 2, dynamicPoints = msg.addMapInfo}},
        }
    elseif behaviorType == 33 then
        behaviorNodeList = {
            {"Battle", {monsterID = beArgs[1][1]}, this.SetNextEventId},
            {"MapProgressChange", {type = 2, curEventID = 0, monsterID = beArgs[1][1]}},
            {"DeletePoint", {pointID = {beArgs[1][2]}}},
            {"NewPoint", {pointList = beArgs, startIndex = 2, dynamicPoints = msg.addMapInfo}},
        }
    elseif behaviorType == 34 then
        behaviorNodeList = {
            {"Buff", {buffID = beArgs[1][1]}},
            {"DeletePoint", {pointID = {beArgs[1][2]}}},
        }
    elseif behaviorType == 35 then
        behaviorNodeList = {
            {"ParseMission", {mission = msg.mission, isInit = false, drop = msg.missionDrop}},
            {"DeletePoint", {pointID = beArgs[1]}},
            {"NewPoint", {pointList = beArgs, startIndex = 2, dynamicPoints = msg.addMapInfo}},
        }
    elseif behaviorType == 36 then
        behaviorNodeList = {
            {"ParseMission", {mission = msg.mission, isInit = false, drop = msg.missionDrop}},
            {"SpendGoods", {itemList = {[1] = beArgs[2]}}},
            {"DeletePoint", {pointID = {beArgs[1][1]}}},
        }

    elseif behaviorType == 37 then
        behaviorNodeList = {
            {"Buff", {buffID = beArgs[1][3]}},
            {"SpendGoods", {itemList = {[1] = beArgs[1]}}},
        }
    elseif behaviorType == 38 then
        behaviorNodeList = {
            {"Battle", {monsterID = beArgs[1][1]}, this.SetNextEventId},
            {"MapProgressChange", {type = 2, curEventID = 0, monsterID = beArgs[1][1]}}
        }
    elseif behaviorType == 39 then    -- 39 战斗胜利后推任务
        behaviorNodeList = {
            {"Battle", {monsterID = beArgs[1][1]}, this.SetNextEventId},
            {"ParseMission", function (result)
                return {mission = result.mission, isInit = false, drop = result.missionDrop}
            end},
            {"MapProgressChange", {type = 2, curEventID = 0, monsterID = beArgs[1][1]}},
            {"NewPoint", {pointList = beArgs, startIndex = 2, dynamicPoints = msg.addMapInfo}},
        }

    elseif behaviorType == 40 then
        behaviorNodeList = {
            {"ParseMission", {mission = msg.mission, isInit = false, drop = msg.missionDrop}},
            {"Buff", {buffID = beArgs[1][1]}},
            {"DeletePoint", {pointID = beArgs[2]}},
            {"NewPoint", {pointList = beArgs, startIndex = 3, dynamicPoints = msg.addMapInfo}},
        }
    elseif behaviorType == 41 then
        behaviorNodeList = {
            {"Battle", {monsterID = beArgs[1][1]}, this.SetNextEventId},
            {"MapProgressChange", {type = 2, curEventID = 0, monsterID = beArgs[1][1]}},
        }
    elseif behaviorType == 42 then
        MapTrialManager.GoNextLevel()
    elseif behaviorType == 43 then
        --MapTrialManager.GoNextLevel()
    elseif behaviorType == 44 then
        behaviorNodeList = {
            {"ShowReward", {drop = msg.drop}},
            {"DeletePoint", {pointID = beArgs[1]}},
        }

    elseif behaviorType == 45 then
        behaviorNodeList = {
            {"Battle", {monsterID = beArgs[1][2]}, this.SetNextEventId},
            {"MapProgressChange", {type = 2, curEventID = 0, monsterID = beArgs[1][1]}},
        }
    elseif behaviorType == 46 then
        behaviorNodeList = {
            {"DeletePoint", {pos = MapManager.curTriggerPos}},
        }
    elseif behaviorType == 47 then -- 跨地图传送
        EndLessMapManager.TranssportByMapId(beArgs[1][1])
    elseif behaviorType == 48 then
        behaviorNodeList = {
            {"Battle", {monsterID = beArgs[1][2]}, this.SetNextEventId},
            {"MapProgressChange", {type = 2, curEventID = 0, monsterID = beArgs[1][1]}},
        }

    elseif behaviorType == 49 then  -- 事件点开始倒计时

        behaviorNodeList = {
            {"ShowReward", {drop = msg.drop}},
        }
    elseif behaviorType==50 then  --惊喜层
        MapTrialManager.GoSurprisedLevel()
    elseif behaviorType==51 then  -- 吃buff， 删除当前点
        behaviorNodeList = {
            {"Buff", {buffID = beArgs[1][1]}},
            {"DeletePoint", {pos = MapManager.curTriggerPos}},
        }
    end

    -- 没有行为
    if #behaviorNodeList == 0 then
        if func then func(this.nextEventId) end
        return
    end
    -- 如果没有主动添加节点掉落则添加
    local isCheckDrop = false
    for i = 1, #behaviorNodeList do
        if behaviorNodeList[i][1] == "ShowReward" then
            isCheckDrop = true
            break
        end
    end
    if not isCheckDrop then
        table.insert(behaviorNodeList, {"ShowReward", {drop = msg.drop}})
    end
    -- 执行行为节点

    BHController.SeqExcuteNodeArray(behaviorNodeList, function()
        if func then func(this.nextEventId) end
    end)
end

-- 在option操作完毕之后更新事件点
function this.JumpEventPoint(eventId, optionId, panel, func)
    local jumpType = OptionConfig[optionId].JumpType
    local behaviorType=OptionConfig[optionId].BehaviorType


    this.CurTriggerPanel = panel

    if jumpType == 4 then --关闭界面，不读取，不刷新事件点

        -- 试炼副本的最后一层
        if MapTrialManager.IsFinalLevel() then
            Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
            return
        end
        NetManager.EventUpdateRequest(eventId, optionId, function ()
            panel:ClosePanel()
            this.CurTriggerPanel = nil
            Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressChange, 1, optionId)
            if behaviorType then
                if behaviorType==55 or behaviorType==53 then
                    Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, MapManager.curTriggerPos)
                end
            end
        end)
    elseif jumpType == 1 or jumpType == 2 or jumpType == 3 then --读取，刷新事件点
        NetManager.EventUpdateRequest(eventId, optionId, function (e)
            MissionManager.EventPointTrigger(e)

            Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressChange, 1, optionId)
            if behaviorType then
                if behaviorType==55 or behaviorType==53 then
                    Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, MapManager.curTriggerPos)
                end
            end
        end)
    elseif jumpType == 5 or jumpType == 7 or jumpType == 8 then --关闭界面，读取，刷新事件点
        panel:ClosePanel()
        this.CurTriggerPanel = nil
        NetManager.EventUpdateRequest(eventId, optionId, function (e)
            MissionManager.EventPointTrigger(e)
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressChange, 1, optionId)
            if behaviorType then
                if behaviorType==55 or behaviorType==53 then
                    Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, MapManager.curTriggerPos)
                end
            end
        end)
    elseif jumpType == 6 or jumpType == 9 or jumpType == 10 then --关闭界面，不读取，刷新事件点
        NetManager.EventUpdateRequest(eventId, optionId, function (e)
            panel:ClosePanel()
            this.CurTriggerPanel = nil
            Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressChange, 1, optionId)
            if behaviorType then
                if behaviorType==55 or behaviorType==53 then
                    Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, MapManager.curTriggerPos)
                end
            end
        end)
    end

    if func then func() end
end


return OptionBehaviourManager