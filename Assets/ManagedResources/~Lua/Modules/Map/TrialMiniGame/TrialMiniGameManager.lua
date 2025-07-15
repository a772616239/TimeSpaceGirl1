TrialMiniGameManager = {}
local this = TrialMiniGameManager
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local artConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

function this.Init()
    this.gameType = nil
    this.doneFunc = nil
    this.gameId = nil
    this.gameParams = nil
    this.gameDrop = nil
    this.isGameDone = nil
end

function this.StartGame(gameType, func)
    this.gameType = gameType
    this.doneFunc = func
    -- 初始化数据
    NetManager.MiniGameInitRequest(function(msg)
        -- this.gameId = msg.type
        this.gameId = msg.param[1]
        this.gameParams = msg.param
        UIManager.OpenPanel(UIName.TrialMiniGamePanel, this.gameType, this.gameId, this.gameParams)
    end)
end

-- 请求操作
function this.GameOperate(index, func)
    -- 初始化数据
    NetManager.MiniGameOperateRequest(index, function(msg)
        this.isGameDone = msg.gameStatus == 0
        this.resultId = msg.resultId
        if func then func(msg) end
    end)
end

-- 游戏结束
function this.EndGame()
    if UIManager.IsOpen(UIName.TrialMiniGamePanel) then
        UIManager.ClosePanel(UIName.TrialMiniGamePanel)
    end
end

--通过drop查找对应的NameIconNum
function this.IdToNameIconNum(_id,_num)
    local id,num = _id,_num 
    local name = GetLanguageStrById(itemConfig[id].Name)
    local icon = artConfig[itemConfig[id].ResourceID].Name
    local data = {
        [1] = name,
        [2] = Util.LoadSprite(icon),
        [3] = num
    }
    return data
end

-- 游戏界面关闭时调用
function this.GameClose()
    if this.IsGameDone() then
        if this.doneFunc then
            this.doneFunc()
        end
    end
    Timer.New(function()
        -- 刷新数据
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
    end, 1):Start()
end

-- 判断游戏是否完成
function this.IsGameDone()
    return this.isGameDone
end

return TrialMiniGameManager