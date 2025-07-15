Game_15 = {}
local this = Game_15
local _itemsList = {}

function this.Init(context, root, gameType, gameId, gameParams)
    this.root = root
    this.gameType = gameType
    this.gameId = gameId
    this.gameParams = gameParams
    this.context = context
    this.config = ConfigManager.GetConfigData(ConfigName.TrialQuestionConfig, this.gameId)
    this.content = Util.GetGameObject(root, "kuang/question"):GetComponent("Text")
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
    local aNumList = {}
    aNumList = string.split(GetLanguageStrById(this.config.Answer), "#")--数字列表
    for index, num in pairs(aNumList) do
        if not _itemsList[index] then
            _itemsList[index] = newObjToParent(this.itemPre, this.itemsLayout)
        end
        _itemsList[index]:GetComponent("Button").interactable = false
        local Num = Util.GetGameObject(_itemsList[index], "Text"):GetComponent("Text")
        local kuang = Util.GetGameObject(_itemsList[index], "kuang")

        _itemsList[index]:SetActive(true)
        Num.text = tonumber(num)
        if num == "?" then
            _itemsList[index]:GetComponent("Button").interactable = true
            Util.AddOnceClick(_itemsList[index], function()
                this.ChooseAnswer(index)
            end)
            kuang:SetActive(false)
            Num.text = " ？"
        end
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
    _itemsList={}
end

return this