Game_18 = {}
local this = Game_18
local _itemsList = {}
local _ItemViewList={}
local _itemsPosList={}
local canGetTime = 3

local isActive = true
this.thread=nil --协程

function this.Init(context, root, gameType, gameId, gameParams)
    this.root = root
    this.gameType = gameType
    this.gameId = gameId
    this.gameParams = gameParams
    this.context = context
    this.liveRoot = Util.GetGameObject(root, "Liveroot")
    this.content = Util.GetGameObject(root, "Image/Content"):GetComponent("Text")
    this.itemsLayout = Util.GetGameObject(root, "Layout")
    this.itemPre = Util.GetGameObject(root, "Layout/itemPre")
    this.btn = Util.GetGameObject(root, "btnStart")
    this.empty = Util.GetGameObject(root, "empty")
    this.maks = Util.GetGameObject(root, "mask")
    this.gameConfig = ConfigManager.GetConfig(ConfigName.TrialGameConfig)
    this.itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
    this.atrConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

    for i = 1, this.itemsLayout.transform.childCount do
        _itemsList[i] = this.itemsLayout.transform:GetChild(i - 1)
    end
end

function this.Show()
    this.root:SetActive(true)
    this.empty:SetActive(true)
    this.maks:SetActive(true)
    this.liveNode = poolManager:LoadLive("live2d_c_yj_00040", this.liveRoot.transform, Vector3.one, Vector3.New(-22,57, 0))

    --数据乱序操作
    local aNumList ={}
    for index, value in ipairs(this.gameParams) do
        aNumList[index] = value
    end
    local unSorList =  this.shuffe(aNumList)--最终乱序数据
    this.SetCard(unSorList)

    Util.AddOnceClick(this.btn,function()--所有的 正->背
        local thread=coroutine.start(function()
            this.empty:SetActive(true)
            this.btn:SetActive(false)
            this.maks:SetActive(false)
            for index, value in ipairs(_itemsList) do
                local cFront = Util.GetGameObject(_itemsList[index], "front")
                cFront.transform:DORotate(Vector3.New(0, 90, 0), 0.3)
            end
            coroutine.wait(0.3)
            for index, value in ipairs(_itemsList) do
                local cBack = Util.GetGameObject(_itemsList[index], "back")
                cBack.transform:DORotate(Vector3.New(0, 0, 0), 0.3)
            end
            coroutine.wait(0.3)
            for index, value in ipairs(_itemsList) do
                _itemsList[index].transform:DOLocalMove(Vector3.New(0,0,0), 0.3)
            end
            coroutine.wait(0.3)
            for index, value in ipairs(_itemsList) do
                _itemsList[index].transform:DOLocalMove(Vector3.New(_itemsPosList[index].x,_itemsPosList[index].y,_itemsPosList[index].z), 0.3)
            end
            --重新发牌
            isActive = false
            this.SetCard(this.gameParams)
            this.empty:SetActive(false)
        end)
    end)

    for index, value in ipairs(_itemsList) do--单个的 背->正
        local cFront = Util.GetGameObject(_itemsList[index], "front")
        local cBack = Util.GetGameObject(_itemsList[index], "back")
        Util.AddOnceClick(cBack,function()
            local thread=coroutine.start(function()
                this.empty:SetActive(true)
                cBack.transform:DORotate(Vector3.New(0, 90, 0), 0.3)
                coroutine.wait(0.3)
                cFront.transform:DORotate(Vector3.New(0, 0, 0), 0.3)
                coroutine.wait(0.2)
                --请求奖励
                TrialMiniGameManager.GameOperate(index, function(msg)
                    if msg.resultId == -1 then
                        PopupTipPanel.ShowTipByLanguageId(12186)
                        TrialMiniGameManager.EndGame()
                    else
                        local data = TrialMiniGameManager.IdToNameIconNum(msg.drop.itemlist[1].itemId,msg.drop.itemlist[1].itemNum)
                        PopupTipPanel.ShowColorTip(data[1],data[2],data[3])
                        canGetTime = msg.gameStatus
                        if canGetTime == 0 then
                            TrialMiniGameManager.EndGame()
                        end
                    end
                end)
                this.empty:SetActive(false)
            end)
        end)

    end
end

function this.SetCard(table)
    for i = 1, 16 do--初始化奖励
        _itemsPosList[i] = _itemsList[i]:GetComponent("RectTransform").localPosition
        local icon = Util.GetGameObject(_itemsList[i], "front/reward"):GetComponent("Image")
        local cFront = Util.GetGameObject(_itemsList[i], "front")
        local cBack = Util.GetGameObject(_itemsList[i], "back")
        local num = Util.GetGameObject(_itemsList[i], "front/num"):GetComponent("Text")
        num.gameObject:SetActive(table[i] ~= -1)
        if isActive then
            this.btn:SetActive(true)
            cFront.transform:DORotate(Vector3.New(0, 0, 0), 0.3)
            cBack.transform:DORotate(Vector3.New(0, 90, 0), 0.3)
        end
        if table[i] ~= -1 then
            local name = this.atrConfig[this.itemConfig[this.gameConfig[table[i]].RewardID].ResourceID].Name
            icon.sprite = Util.LoadSprite(name)
            num.text = this.gameConfig[table[i]].Max
        else
            icon.sprite = Util.LoadSprite("r_jieling_hr_3006_SoulCrystal")
        end
        -- _itemsList[i]:SetActive(true)
    end
end

function this.shuffe(t)
    if type(t)~="table" then
        return
    end
    local tab={}
    local index=1
    while #t~=0 do
        local n=math.random(0,#t)
        if t[n]~=nil then
            tab[index]=t[n]
            table.remove(t,n)
            index=index+1
        end
    end
    return tab
end

function this.Close()
    this.root:SetActive(false)
    poolManager:UnLoadLive("live2d_c_yj_00040", this.liveNode)
    isActive = true
end

function this.Destroy()
    _ItemViewList={}
    _itemsList = {}
end

return this