Game_17 = {}
local this = Game_17

local state = false

function this.Init(context, root, gameType, gameId, gameParams)
    this.root = root
    this.gameType = gameType
    this.gameId = gameId
    this.gameParams = gameParams
    this.context = context
    this.list={}--Id的List
    this.items = Util.GetGameObject(this.root,"items")
    this.btnStart = Util.GetGameObject(this.root,"Button")
    this.btnStart:GetComponent("Button").interactable = true
    this.itemsList = {}--12个框的List\
    this.ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
    this.ArtConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
    this.TrialGameConfig = ConfigManager.GetConfig(ConfigName.TrialGameConfig)
    this.liveRoot = Util.GetGameObject(root, "Liveroot")

    for i = 1, this.items.transform.childCount do
        this.itemsList[i] = this.items.transform:GetChild(i - 1)
    end
    for index, value in ipairs(this.gameParams) do
        table.insert(this.list,value)
    end
    this.tableTurnEffect(1)
end


local id
local num
function this.Show()
    this.root:SetActive(true)
    this.liveNode = poolManager:LoadLive("live2d_c_yj_00040", this.liveRoot.transform, Vector3.one, Vector3.New(-6,62, 0))
    local red = Util.GetGameObject(this.itemsList[1],"Red")
    red:SetActive(true)

    for index, item in pairs(this.itemsList) do
        local reward = Util.GetGameObject(item,"reward"):GetComponent("Image")
        local Name = this.ArtConfig[this.ItemConfig[this.TrialGameConfig[this.list[index]].RewardID].ResourceID].Name--（Index->奖励id->itemID->资源名字）
        reward.sprite = Util.LoadSprite(Name)
        local Num = Util.GetGameObject(item,"Num"):GetComponent("Text")
        Num.text =this.TrialGameConfig[this.list[index]].Max
    end

    Util.AddOnceClick(this.btnStart,function()
        this.btnStart:GetComponent("Button").interactable = false
        TrialMiniGameManager.GameOperate(0, function(msg)
            --转起来
            this.test(msg.drop.itemlist[1].itemId)
            id = msg.drop.itemlist[1].itemId
            num = msg.drop.itemlist[1].itemNum
            --4秒后显示掉落
            -- Timer.New(function()
            --     if TrialMiniGameManager.IsGameDone() then
            --         TrialMiniGameManager.EndGame()
            --     end
            --     local data = TrialMiniGameManager.IdToNameIconNum(msg.drop.itemlist[1].itemId,msg.drop.itemlist[1].itemNum)
            --     PopupTipPanel.ShowColorTip(data[1],data[2],data[3])
            -- end, 20,1,true):Start()
        end)
    end)
end
--加减速
function this.test(itemId)
    local t =1
    local thread=coroutine.start(function()
        --加速阶段
        if this.turnEffect2 then
            this.turnEffect2:Stop()
            this.turnEffect2 = nil
        end
        if not this.turnEffect2 then
            this.turnEffect2 = Timer.New(function()
                this.tableTurnEffect(1/t)
                t=t+5
            end,0.2,10,true)
            this.turnEffect2:Start()
        end
        coroutine.wait(2)
        --减速阶段
        if this.turnEffect2 then
            this.turnEffect2:Stop()
            this.turnEffect2 = nil
        end
        if not this.turnEffect2 then
            this.turnEffect2 = Timer.New(function()
                this.tableTurnEffect(1/t)
                t=t-3.3
            end,0.2,10,true)    
            this.turnEffect2:Start()
        end
        coroutine.wait(2)       
        this.tableTurnEffect(0.4,itemId)
    end)
end

--设置速度
local index = 1
function this.tableTurnEffect(speed,itemId)
    if this.turnEffect then 
        this.turnEffect:Stop()
        this.turnEffect = nil
    end
    if not this.turnEffect then
        this.turnEffect = Timer.New(function()
            local red = Util.GetGameObject(this.itemsList[index],"Red")
            red:SetActive(false)
            if index == 12 then--t归零
                index = 0
            end
            local redNext = Util.GetGameObject(this.itemsList[index+1],"Red")
            redNext:SetActive(true)
            index = index + 1
            --检测最后的奖励
            if itemId and id == this.TrialGameConfig[this.list[index]].RewardID and num == this.TrialGameConfig[this.list[index]].Max then
                this.turnEffect:Stop()
                --游戏结束显示掉落
                Timer.New(function()
                    if TrialMiniGameManager.IsGameDone() then
                        TrialMiniGameManager.EndGame()
                    end
                    local data = TrialMiniGameManager.IdToNameIconNum(id,num)
                    PopupTipPanel.ShowColorTip(data[1],data[2],data[3])
                end, 1,1,true):Start()

            end
        end,speed,-1,true)
        this.turnEffect:Start()
    end
end

function this.Close()
    this.root:SetActive(false)
    for index, value in ipairs(this.itemsList) do
        local red = Util.GetGameObject(this.itemsList[index],"Red")
        red:SetActive(false)
    end
    poolManager:UnLoadLive("live2d_c_yj_00040", this.liveNode)
    index = 1
    if this.turnEffect2 then
        this.turnEffect2:Stop()
        this.turnEffect2 = nil
    end
    if this.turnEffect then
        this.turnEffect:Stop()
        this.turnEffect = nil
    end
end

function this.Destroy()
end

return this