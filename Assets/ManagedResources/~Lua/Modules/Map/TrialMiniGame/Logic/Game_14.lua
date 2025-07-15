Game_14 = {}
local this = Game_14
local _itemsList = {}
local _iconList = {}
local artConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
function this.Init(context, root, gameType, gameId, gameParams)
    this.root = root
    this.gameType = gameType
    this.gameId = gameId
    this.gameParams = gameParams
    this.context = context
    this.config = ConfigManager.GetConfigData(ConfigName.TrialQuestionConfig, this.gameId)
    this.heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig) 
    this.content = Util.GetGameObject(root, "Image/Content"):GetComponent("Text")
    this.itemsLayout = Util.GetGameObject(root, "layout")
    this.itemPre = Util.GetGameObject(root, "layout/c1")
    this.liveRoot = Util.GetGameObject(root, "Liveroot")
end

function this.Show()
    this.root:SetActive(true)
    this.content.text = GetLanguageStrById(this.config.Question)
    this.liveNode = poolManager:LoadLive("live2d_c_yj_00040", this.liveRoot.transform, Vector3.one, Vector3.New(0,57, 0)) 

    for _, item in pairs(_itemsList) do 
        item:SetActive(false) 
    end
    local aIdList = string.split(GetLanguageStrById(this.config.Answer), "#")--id列表
    --设置按钮和图片
    for index, answerId in pairs(aIdList) do
        if not _itemsList[index] then

            _itemsList[index] = newObjToParent(this.itemPre, this.itemsLayout)
            local icon  = Util.GetGameObject(_itemsList[index], "icon"):GetComponent("Image")
            local btnSure = Util.GetGameObject(_itemsList[index], "btnAns")
            local data = ConfigManager.GetConfigDataByKey(ConfigName.HeroConfig,"Id",tonumber(answerId))

            -- if not _iconList[index] then
            --     _iconList[index] = SubUIManager.Open(SubUIConfig.ItemView,icon.transform)
            -- end
            -- _iconList[index]:OnOpen(false,{answerId,1},1.1,false)

            if not _iconList[index] then
                _iconList[index] = icon
            end
            _iconList[index].sprite = Util.LoadSprite(GetResourcePath(data.Icon))

            Util.AddOnceClick(btnSure, function()
                this.ChooseAnswer(index)
            end)
        end
        _itemsList[index]:SetActive(true)
        
        Util.GetGameObject(_itemsList[index], "btnAns/name"):GetComponent("Text").text = GetLanguageStrById(this.heroConfig[tonumber(answerId)].ReadingName)
        
    end
end

-- 选择答案
function this.ChooseAnswer(index)
    TrialMiniGameManager.GameOperate(index, function(msg)
        local thread=coroutine.start(function()
            if this.config.TrueAnswer[index] == 1 then
                PopupTipPanel.ShowTip(GetLanguageStrById(this.config.TrueFeedback))
            else
                PopupTipPanel.ShowTip(GetLanguageStrById(this.config.FalseFeedback))
            end
            -- UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
            --     if TrialMiniGameManager.IsGameDone() then
            --         TrialMiniGameManager.EndGame()
            --     end
            -- end)
            if TrialMiniGameManager.IsGameDone() then
                TrialMiniGameManager.EndGame()
            end
            coroutine.wait(0.5)
            local data = TrialMiniGameManager.IdToNameIconNum(msg.drop.itemlist[1].itemId,msg.drop.itemlist[1].itemNum)
            PopupTipPanel.ShowColorTip(data[1],data[2],data[3])
        end)
    end)
end

function this.Close()
    this.root:SetActive(false)
    poolManager:UnLoadLive("live2d_c_yj_00040", this.liveNode) 
end

function this.Destroy()
    _itemsList = {}
    _iconList = {}
    
end

return this