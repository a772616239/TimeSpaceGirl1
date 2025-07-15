require("Base/BasePanel")
local AlienMainPanel = Inherit(BasePanel)
local this = AlienMainPanel
--初始化组件（用于子类重写）
function AlienMainPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.btnHelp = Util.GetGameObject(self.transform, "helpBtn")

    this.btnCallAlien = Util.GetGameObject(self.transform, "callMonsterBtn")
    this.callCount = Util.GetGameObject(self.transform, "callMonsterBtn/Text"):GetComponent("Text")
    this.callTime = Util.GetGameObject(self.transform, "callMonsterBtn/time"):GetComponent("Text")
    this.fullTip = Util.GetGameObject(self.transform, "callMonsterBtn/full"):GetComponent("Text")
    this.callAlienRedPoint = Util.GetGameObject(self.transform, "callMonsterBtn/redPoint")

    this.alienScrollRoot = Util.GetGameObject(self.transform, "scrollroot")
    this.alienItem = Util.GetGameObject(self.transform, "scrollroot/item")
    this.alienEmpty=Util.GetGameObject(self.gameObject, "scrollroot/roleImage")

    this.shareScrollRoot = Util.GetGameObject(self.transform, "chatroot")
    this.shareItem = Util.GetGameObject(self.transform, "chatroot/item")

    this.btnRank = Util.GetGameObject(self.transform, "right/rank")
    this.btnReward = Util.GetGameObject(self.transform, "right/reward")


    --
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })

end

--绑定事件（用于子类重写）
function AlienMainPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
    Util.AddClick(this.btnHelp, function()
        local pos = this.btnHelp.transform.localPosition
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.Adventure, pos.x, pos.y)
    end)
    --点击召唤外敌
    Util.AddClick(this.btnCallAlien, function()
        if (AdventureManager.callAlianInvasionTime >= 1) then
            AdventureManager.CallAlianInvasionRequest(function()
                -- 刷新外敌列表
                AdventureManager.RequestAdventureEnemyList()
                -- 刷新红点显示
                this:OnRefreshRedPoint()
                -- 刷新次数
                this.callCount.text = GetLanguageStrById(10077)..AdventureManager.callAlianInvasionTime .. "/" .. AdventureManager.callAlianInvasionTotalTime
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10057)
        end
    end)

    Util.AddClick(this.btnRank, function()
        UIManager.OpenPanel(UIName.AlienRankRewardPopup, "rank")
    end)
    Util.AddClick(this.btnReward, function()
        UIManager.OpenPanel(UIName.AlienRankRewardPopup, "reward")
    end)
end

--添加事件监听（用于子类重写）
function AlienMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.CallAlianInvasionTime, this.CallAlianInvasionTimeCountDown)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnEnemyListChanged, this.RefreshAlienList)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnChatListChanged, this.RefreshAlienShareList)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnRefreshRedShow, this.OnRefreshRedPoint)
end

--移除事件监听（用于子类重写）
function AlienMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.CallAlianInvasionTime, this.CallAlianInvasionTimeCountDown)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnEnemyListChanged, this.RefreshAlienList)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnChatListChanged, this.RefreshAlienShareList)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnRefreshRedShow, this.OnRefreshRedPoint)
end

--界面打开时调用（用于子类重写）
function AlienMainPanel:OnOpen(...)
    -- 开启计时器
    if not this._CountDownTimer then
        this._CountDownTimer = Timer.New(this.TimeUpdate, 1, -1, true)
        this._CountDownTimer:Start()
        this.TimeUpdate()
    end
    -- 设置
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.AdventureTimes })
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AlienMainPanel:OnShow()
    this.callCount.text = GetLanguageStrById(10077)..AdventureManager.callAlianInvasionTime .. "/" .. AdventureManager.callAlianInvasionTotalTime

    this:OnRefreshRedPoint()
    this.RefreshAlienShareList()
    -- 刷新外敌列表
    AdventureManager.RequestAdventureEnemyList()
end

--- 外敌分享列表信息更新
function this.RefreshAlienShareList()
    -- 判断是否有新的消息显示
    if not AdventureManager.IsChatListNew then
        return
    end
    -- 判断是否需要创建scrollview
    if not this.shareScrollView then
        -- 创建循环列表
        local rootWidth = this.shareScrollRoot.transform.rect.width
        local rootHight = this.shareScrollRoot.transform.rect.height
        this.shareScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.shareScrollRoot.transform,
                this.shareItem, nil, Vector2.New(rootWidth, rootHight), 1, 1, Vector2.New(0, 0))
        this.shareScrollView.moveTween.MomentumAmount = 1
        this.shareScrollView.moveTween.Strength = 2
    end
    -- 获取数据
    local shareList = AdventureManager.GetChatList()
    this.shareScrollView:SetData(shareList, function(index, go)
        this.ChatNodeAdapter(go, shareList[index])
    end)
    -- 判断是否需要滚动到最下面
    local dataLen = #shareList
    if dataLen > 3 then
        this.shareScrollView:SetIndex(dataLen)
    end
end

-- 节点数据匹配
function this.ChatNodeAdapter(node, data)
    local name = Util.GetGameObject(node, "name")
    local content = Util.GetGameObject(node, "content")
    -- 判断是否被击杀
    local isKilled = AdventureManager.IsEnemyKilled(data.bossId)
    name:GetComponent("Text").text = isKilled and "<color=#B3B3B1>"..data.findName.."</color>" or data.findName
    --TODO:这里会区分聊天消息的类型做不同的显示，目前只有boss
    local monsterGroup = ConfigManager.GetConfigData(ConfigName.MonsterGroup, data.bossGroupId)
    local monsterId = monsterGroup.Contents[1][1]
    local monsterInfo = ConfigManager.GetConfigData(ConfigName.MonsterConfig, monsterId)
    local bossName = GetLanguageStrById(monsterInfo.ReadingName)
    content:GetComponent("Text").text = isKilled and "<color=#B3B3B1>"..bossName.."</color>" or bossName
    -- 点击事件监听
    Util.AddOnceClick(node, function()
        if isKilled then
            PopupTipPanel.ShowTipByLanguageId(10078)
        else
            UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.ADVENTURE_BOSS, data)
        end
    end)
end

function this.RefreshAlienList()
    -- 判断是否需要创建scrollview
    if not this.alienScrollView then
        -- 创建循环列表
        local rootWidth = this.alienScrollRoot.transform.rect.width
        local rootHight = this.alienScrollRoot.transform.rect.height
        this.alienScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.alienScrollRoot.transform,
                this.alienItem, nil, Vector2.New(rootWidth, rootHight), 1, 1, Vector2.New(0, 10))
        this.alienScrollView.moveTween.MomentumAmount = 1
        this.alienScrollView.moveTween.Strength = 2
    end

    -- 敌人列表
    local enemyList = AdventureManager.GetAdventureEnemyList()
    this.alienEmpty:SetActive(#enemyList < 1)
    this.countDownLabs = {}
    this.alienScrollView:SetData(enemyList, function(index, item)
        local itemData = enemyList[index]
        -- 保存节点对应的数据index
        this.countDownLabs[item.name] = { node = item, index = index }
        this.EnemyItemAdapter(item, itemData)
    end)
end

-- 外敌节点数据匹配
function this.EnemyItemAdapter(item, data)
    local bossQuality = Util.GetGameObject(item, "invadeBossQuality"):GetComponent("Image")
    local bossIcon = Util.GetGameObject(item, "invadeBossQuality/invadeBossIcon"):GetComponent("Image")
    local bossLvl = Util.GetGameObject(item, "invadeBossQuality/lvbg/levelText"):GetComponent("Text")
    local bossName = Util.GetGameObject(item, "invadeBossQuality/namebg/bossNameText"):GetComponent("Text")

    local mapName = Util.GetGameObject(item, "mapName"):GetComponent("Text")
    local finderName = Util.GetGameObject(item, "finderName"):GetComponent("Text")
    local totalInjuryName = Util.GetGameObject(item, "totalInjuryName"):GetComponent("Text")
    local escapeTime = Util.GetGameObject(item, "escapeTime"):GetComponent("Text")

    local slider = Util.GetGameObject(item, "Slider"):GetComponent("Slider")
    local sliderText = Util.GetGameObject(item, "Slider/Text"):GetComponent("Text")

    local attackBtn = Util.GetGameObject(item, "attackBtn")
    local detailBtn = Util.GetGameObject(item, "detailBtn")
    local shareBtn = Util.GetGameObject(item, "shareBtn")

    local monsterId = ConfigManager.GetConfigData(ConfigName.MonsterGroup, data.bossGroupId).Contents[1][1]
    local monsterInfo = ConfigManager.GetConfigData(ConfigName.MonsterConfig, monsterId)
    local heroInfo = ConfigManager.GetConfigData(ConfigName.HeroConfig, monsterInfo.MonsterId)
    -- bossQuality.sprite = Util.LoadSprite(GetQuantityImageByquality(monsterInfo.Quality))
    if heroInfo then
        bossIcon.sprite = Util.LoadSprite(GetResourcePath(heroInfo.Icon))
    end
    bossLvl.text = monsterInfo.Level
    bossName.text = GetLanguageStrById(monsterInfo.ReadingName)

    --mapName.text = ConfigManager.GetConfigData(ConfigName.AdventureConfig, data.arenaId).AreaName
    finderName.text = data.findName
    totalInjuryName.text = data.myHurt
    escapeTime.text = TimeToHMS(GetTimeStamp() - data.levelTime)
    slider.value = data.bossRemainlHp / data.totalHp
    local remainlHP = data.bossRemainlHp > 1000000 and math.floor(data.bossRemainlHp/10000)..GetLanguageStrById(10042) or tostring(data.bossRemainlHp)
    local totalHP = data.totalHp > 1000000 and math.floor(data.totalHp/10000)..GetLanguageStrById(10042) or tostring(data.totalHp)
    sliderText.text = string.format("%s/%s", remainlHP, totalHP)

    Util.AddOnceClick(attackBtn, function()
        UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.ADVENTURE_BOSS, data)
    end)
    Util.AddOnceClick(detailBtn, function()
        UIManager.OpenPanel(UIName.AdventureRewardDetailPopup, data.arenaId, data.arenaLevel, data.bossGroupId)
    end)
    -- 分享按钮
    shareBtn:SetActive(data.findUid == PlayerManager.uid)
    Util.AddOnceClick(shareBtn, function()
        -- 请求分享
        if data.findUid ~= PlayerManager.uid then return end
        AdventureManager.GetAdventureBossShareRequest(data.bossId)
    end)
end
-- 时间刷新
function this.TimeUpdate()
    if not this.countDownLabs then return end
    local datalist = AdventureManager.GetAdventureEnemyList()
    local curTimeStamp = GetTimeStamp()
    for _, v in pairs(this.countDownLabs) do
        if datalist[v.index] then
            local leftTime = datalist[v.index].levelTime - curTimeStamp
            Util.GetGameObject(v.node, "escapeTime"):GetComponent("Text").text = TimeToHMS(leftTime)
        end
    end
end

--外敌次数恢复时间倒计时
function this.CallAlianInvasionTimeCountDown(remainTime)
    this.callTime.gameObject:SetActive(remainTime ~= 0)
    this.fullTip.gameObject:SetActive(remainTime == 0)
    if remainTime ~= 0 then
        this.callTime.text = TimeToHMS(remainTime)
    end
    if remainTime == AdventureManager.callAlianInvasionCountDownTime then
        this:OnRefreshRedPoint()
        CheckRedPointStatus(RedPointType.SecretTer_CallAlianInvasionTime)
    end
    this.callCount.text = GetLanguageStrById(10077)..AdventureManager.callAlianInvasionTime .. "/" .. AdventureManager.callAlianInvasionTotalTime
end


--刷新红点
function this:OnRefreshRedPoint()
    this.callAlienRedPoint:SetActive(AdventureManager.callAlianInvasionTime >= 1)
end


--界面关闭时调用（用于子类重写）
function AlienMainPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function AlienMainPanel:OnDestroy()
    -- 开启计时器
    if this._CountDownTimer then
        this._CountDownTimer:Stop()
        this._CountDownTimer = nil
    end
    this.countDownLabs = nil

    this.alienScrollView = nil
    this.shareScrollView = nil

    SubUIManager.Close(this.UpView)
end

return AlienMainPanel