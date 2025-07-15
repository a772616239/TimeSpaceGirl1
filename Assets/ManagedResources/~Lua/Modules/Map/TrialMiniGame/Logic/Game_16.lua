Game_16 = {}
local this = Game_16

function this.Init(context, root, gameType, gameId, gameParams)
    this.root = root
    this.gameId = gameId
    this.TrialGameConfig = ConfigManager.GetConfig(ConfigName.TrialGameConfig)
    this.Text = Util.GetGameObject(this.root, "middle/startDraw/canRechargeTimebg/Text"):GetComponent("Text")
    this.startDrawBtn = Util.GetGameObject(this.root, "middle/startDraw/startDrawBtn")
    this.startDrawBtn:GetComponent("Button").interactable = true
    this.anim = Util.GetGameObject(this.root, "middle/number/anim")
    this.anim.transform.localPosition = Vector2.New(18, -58)
    --this.NumView = SubUIManager.Open(SubUIConfig.NumberView, this.anim.transform, "r_fxgz_shuzi_", Vector2.New(80, 120), Vector2.New(50, 30), 0, 99999)

end

function this.Show()
    this.root:SetActive(true)
    Util.AddOnceClick(this.startDrawBtn,function()
        this.startDrawBtn:GetComponent("Button").interactable = false
        this.OnRefreshItemNumShow(this.gameId)
    end)
end

function this.OnRefreshItemNumShow(index)
    TrialMiniGameManager.GameOperate(index, function(msg)
        local dropNumbers = msg.drop.itemlist[1].itemNum
        --ToDo动画显示
        -- this.NumView:SetNum(0)
        -- this.NumView:DOItemNum(dropNumbers, function(index, num, item)
        --     -- itemList[index]=item
        --     item:Move(tostring(num), index * 0.5 + 2, true, 3)
        -- end)
        local timerEffect = Timer.New(function()
            -- UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
            --     if TrialMiniGameManager.IsGameDone() then
            --         TrialMiniGameManager.EndGame()
            --     end
            if TrialMiniGameManager.IsGameDone() then
                TrialMiniGameManager.EndGame()
                this.NumView.gameObject:SetActive(false)
            end
            local data = TrialMiniGameManager.IdToNameIconNum(msg.drop.itemlist[1].itemId,msg.drop.itemlist[1].itemNum)
            PopupTipPanel.ShowColorTip(data[1],data[2],data[3])
        end, 5, 1, true)
        timerEffect:Start()
    end)
end

function this.Close()
    this.root:SetActive(false)
end

function this.Destroy()
end
return this