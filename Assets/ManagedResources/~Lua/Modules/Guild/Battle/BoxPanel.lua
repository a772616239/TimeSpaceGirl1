BoxPanel = quick_class("GuildBattlePanel")
local this = BoxPanel

local itemList = {}
function this:InitComponent(go)
    this.gameObject = go
    this.time = Util.GetGameObject(this.gameObject, "content/Text"):GetComponent("Text")
    this.scroll = Util.GetGameObject(this.gameObject, "scroll")
    this.pre = Util.GetGameObject(this.gameObject, "scroll/pre")
    this.btnPreview = Util.GetGameObject(this.gameObject, "content/btnPreview")
    this.btnHelp = Util.GetGameObject(this.gameObject, "content/btnHelp")

    local w = this.scroll.transform.rect.width
    local h = this.scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform, this.pre, nil,
            Vector2.New(w, h), 1, 4, Vector2.New(5, 5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

function this:BindEvent()
    Util.AddClick(this.btnHelp, function ()
        UIManager.OpenPanel(
            UIName.HelpPopup,
            HELP_TYPE.GuildBattleBoxReward,
            this.btnHelp:GetComponent("RectTransform").localPosition.x,
            this.btnHelp:GetComponent("RectTransform").localPosition.y)
    end)
    Util.AddClick(this.btnPreview, function ()
        UIManager.OpenPanel(UIName.PublicAwardPoolPreviewPanel)
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshGuildBattleReward, this.SetReward)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshGuildBattleReward, this.SetReward)
end

-- 打开时调用
function this:OnOpen()
end

--界面打开时调用（用于子类重写）
function this:OnShow()
    this.SetReward()
    this.RemainTimeDown()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

function this.SetReward()
    CheckRedPointStatus(RedPointType.GuildBattle_BoxReward)
    local rewards = GuildBattleManager.rewardInfo
    this.scrollView:SetData(rewards, function(i, go)
        this.SetScrollPre(go, rewards[i])
    end)
end

function this.SetScrollPre(go, data)
    go:SetActive(true)
    local nameObj = Util.GetGameObject(go, "name")
    local name = Util.GetGameObject(go, "name/Text"):GetComponent("Text")
    local pos = Util.GetGameObject(go, "pos")
    local btn = Util.GetGameObject(go, "btnBox")

    nameObj:SetActive(data.username ~= "")
    btn:SetActive(data.username == "")
    name.text = data.username
    if data.username ~= "" then
        if not itemList[go] then
            itemList[go] = SubUIManager.Open(SubUIConfig.ItemView, pos.transform)
        end
        itemList[go]:OnOpen(false, {data.items[1].itemId, data.items[1].itemNum}, 0.8)
        itemList[go].gameObject:SetActive(true)
    else
        if itemList[go] then
            itemList[go].gameObject:SetActive(false)
        end
    end

    Util.AddOnceClick(btn, function ()
        if GuildBattleManager.allowChallange == 0 and GuildBattleManager.guildBattleState == 0 then
            PopupTipPanel.ShowTip(GetLanguageStrById(50254))--没有权限领取，请积极参与下次城市争夺
            return
        end
        GuildBattleManager.ReceiveRewardRequest(data.position, function ()
            this.SetReward()
        end)
    end)
end

--刷新时间
function this.RemainTimeDown()
    local timeDown = GuildBattleManager.startTime - GetTimeStamp()

    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    
    if timeDown > 0 then
        this.time.text = GetLanguageStrById(50267)..TimeToDHMS(timeDown)
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        
        this.timer = Timer.New(function()
            if timeDown <= 0 then
                this.time.text = ""
                this.timer:Stop()
                this.timer = nil
            end

            timeDown = timeDown - 1
            this.time.text = GetLanguageStrById(50267)..TimeToDHMS(timeDown)

        end, 1, -1, true)
        this.timer:Start()
    else
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end

        this.time.text = ""
    end
end

return this