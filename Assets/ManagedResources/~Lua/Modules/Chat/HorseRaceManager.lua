HorseRaceManager = {}
local this = HorseRaceManager

local _GMRaceDeltaTime = 5

local _HorseRaceList = {}
local _RepeatRaceList = {}

function this.Initialize()
    Timer.New(this._TimerUpdate, 1, -1, true):Start()
end

function this._TimerUpdate()
    -- 战斗界面，不显示GM跑马灯
    if UIManager.IsOpen(UIName.BattlePanel) or UIManager.IsOpen(UIName.LoadingPanel) then
        return
    end
    -- 根据剩余次数
    local removeIndex = {}
    for index, race in ipairs(_RepeatRaceList) do
        local curTimeStamp = GetTimeStamp()
        if curTimeStamp - race.lastShowTime < 10 then
            if race.multiple > 0 then
                if curTimeStamp - race.lastTime >= _GMRaceDeltaTime then
                    race.lastTime = curTimeStamp
                    race.multiple = race.multiple - 1
                    table.insert(_HorseRaceList, race)
                    Game.GlobalEvent:DispatchEvent(GameEvent.HorseRace.ShowHorseRace)
                end
            end
            -- 播放完了，就删除
            if race.multiple <= 0 then
                table.insert(removeIndex, index)
            end
        else
            table.insert(removeIndex, index)
        end
    end
    -- 删除要删除的
    for i = #removeIndex, 1, -1 do
        table.remove(_RepeatRaceList, i)
    end
end

-- 将数据加入
function this.AddRaceData(data)
    local race = {
        id = data.messageId,
        content = data.msg,
        speed = data.speed,
        multiple = data.multiple,
        lastTime = 0,
        lastShowTime = data.times/1000,
        chatparms = data.chatparms
    }
    table.insert(_RepeatRaceList, race)
end

-- 获取第一条数据
function this.GetRaceData()
    if not _HorseRaceList or #_HorseRaceList == 0 then
        return
    end
    return table.remove(_HorseRaceList, 1)
end

return this