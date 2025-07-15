Game_13 = {}
local this = Game_13
local _btnList = {}

function this.Init(context, root, gameType, gameId, gameParams)
    this.root = root
    this.gameType = gameType
    this.gameId = gameId
    this.gameParams = gameParams
    this.context = context
    this.config = ConfigManager.GetConfigData(ConfigName.TrialQuestionConfig, this.gameId)
    this.liveRoot = Util.GetGameObject(root, "Liveroot")
    this.content = Util.GetGameObject(root, "Image/Content"):GetComponent("Text")
    this.btnLayout = Util.GetGameObject(root, "layout")
    this.btn = Util.GetGameObject(root, "layout/c1")

end
--live2d_c_yj_00040
function this.Show()
    this.root:SetActive(true)
    this.content.text = GetLanguageStrById(this.config.Question)
    this.liveNode = poolManager:LoadLive("live2d_c_yj_00040", this.liveRoot.transform, Vector3.one, Vector3.New(0,57, 0)) 

    for _, item in pairs(_btnList) do 
        item:SetActive(false) 
    end
    local aList = string.split(GetLanguageStrById(this.config.Answer), "#")
    for index, answer in ipairs(aList) do
        if not _btnList[index] then
            _btnList[index] = newObjToParent(this.btn, this.btnLayout)
        end
        _btnList[index]:SetActive(true)
        Util.GetGameObject(_btnList[index], "Text"):GetComponent("Text").text = answer
        Util.AddOnceClick(_btnList[index], function()
            this.ChooseAnswer(index) 
        end)
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
    _btnList = {}
end

return this