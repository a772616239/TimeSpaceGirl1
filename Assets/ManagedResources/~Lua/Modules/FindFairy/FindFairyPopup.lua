require("Base/BasePanel")
FindFairyPopup = Inherit(BasePanel)
local this = FindFairyPopup
this.type = nil --当前面板弹窗类型
this.playerScrollHead = {}
--滚动条头像
--积分奖励按钮图片
local StateImageName = {
    "r_hero_button_001",
    "r_hero_button_003",
    "r_renwu_yiwancheng_001"
}
local CurType

---东海寻仙通用弹窗
--初始化组件（用于子类重写）
function FindFairyPopup:InitComponent()
    this.panel = Util.GetGameObject(self.gameObject, "Panel")
    this.backBtn = Util.GetGameObject(this.panel, "BackBtn")
    this.title = Util.GetGameObject(this.panel, "Title"):GetComponent("Text")
    this.info = Util.GetGameObject(this.panel, "Info"):GetComponent("Text")

    this.scrollRoot = Util.GetGameObject(this.panel, "ScrollRoot")
    this.noneImage = Util.GetGameObject(this.panel, "NoneImage")
    this.findFairyRoot = Util.GetGameObject(this.scrollRoot, "FindFairyRoot")
    this.scoreRewardRoot = Util.GetGameObject(this.scrollRoot, "ScoreRewardRoot")
    this.bigRankRoot = Util.GetGameObject(this.scrollRoot, "BigRankRoot")
    this.curScoreRankRoot = Util.GetGameObject(this.scrollRoot, "CurScoreRankRoot")
    this.curScoreRankScroll = Util.GetGameObject(this.scrollRoot, "CurScoreRankRoot/Scroll")

    this.bigRankList = {}
    --每次打开清理下重新加载
    FindFairyManager.rankRewardData = {}
    FindFairyManager.SetRankRewardData()
    for i = 1, #FindFairyManager.rankRewardData do
        this.bigRankList[i] = Util.GetGameObject(this.bigRankRoot, "Rect/BigRankPre" .. i)
    end

    --积分奖励item
    this.scoreItemList = {}
    --排名大奖item
    this.bigItemList = {}
    --寻仙榜滚动条预设
    this.findFairyPre = Util.GetGameObject(this.scrollRoot, "FindFairyPre")
    --积分奖励滚动条预设
    this.scoreRewardPre = Util.GetGameObject(this.scrollRoot, "ScoreRewardPre")
    --本期排名预设
    this.curScoreRankPre = Util.GetGameObject(this.scrollRoot, "CurScoreRankPre")

    --寻仙榜碎片item列表
    this.heroItemList = {}
end

--绑定事件（用于子类重写）
function FindFairyPopup:BindEvent()
    Util.AddClick(
        this.backBtn,
        function()
            local view = require("Modules/FindFairy/View/FindFairy_MainView")
            view.curRewardRootMask.enabled = true
            self:ClosePanel()
        end
    )
end

--添加事件监听（用于子类重写）
function FindFairyPopup:AddListener()
end

--移除事件监听（用于子类重写）
function FindFairyPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function FindFairyPopup:OnOpen(...)
    local args = {...}
    this.type = args[1]
    this.SetView(args[1])
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FindFairyPopup:OnShow()
end

--重设层级
function FindFairyPopup:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end

--界面关闭时调用（用于子类重写）
function FindFairyPopup:OnClose()
    this.playerScrollHead = {}
    this.noneImage:SetActive(false)
    this.CloseView(CurType)
end

--界面销毁时调用（用于子类重写）
function FindFairyPopup:OnDestroy()
    this.findFairyScrollView = nil
    this.scoreRewardScrollView = nil
    this.bigRankScrollView = nil
    this.curScoreRankScrollView = nil
end

--设置显示
function this.SetView(type)
    CurType = type
    this.info.gameObject:SetActive(this.type == FIND_FAIRY_POPUP_TYPE.FindFairyRecord)
    this.findFairyRoot:SetActive(this.type == FIND_FAIRY_POPUP_TYPE.FindFairyRecord)
    this.scoreRewardRoot:SetActive(this.type == FIND_FAIRY_POPUP_TYPE.ScoreReward)
    this.bigRankRoot:SetActive(this.type == FIND_FAIRY_POPUP_TYPE.BigRank)
    this.curScoreRankRoot:SetActive(this.type == FIND_FAIRY_POPUP_TYPE.CurScoreRank)

    if CurType == FIND_FAIRY_POPUP_TYPE.FindFairyRecord then
        this.title.text = GetLanguageStrById(10624)
        if not this.findFairyScrollView then
            this.findFairyScrollView =
                SubUIManager.Open(
                SubUIConfig.ScrollCycleView,
                this.findFairyRoot.transform,
                this.findFairyPre,
                nil,
                Vector2.New(this.findFairyRoot.transform.rect.width, this.findFairyRoot.transform.rect.height),
                1,
                1,
                Vector2.New(0, 20)
            )
            this.findFairyScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
            this.findFairyScrollView.moveTween.MomentumAmount = 1
            this.findFairyScrollView.moveTween.Strength = 2
        end
        NetManager.RequestRankInfo(
            RANK_TYPE.FINDFAIRY_RECORD,
            function(msg)
                --msg.myRankInfo.param2 --猎妖师ID
                this.noneImage:SetActive(#msg.ranks == 0)
                this.findFairyScrollView:SetData(
                    msg.ranks,
                    function(index, root)
                        this.FindFairyRecordShow(root, msg.ranks[index])
                    end
                )
                this.findFairyScrollView:SetIndex(1)
            end,
            ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
        )
    elseif CurType == FIND_FAIRY_POPUP_TYPE.ScoreReward then
        this.title.text = GetLanguageStrById(10625)
        this.noneImage:SetActive(false)
        local data = FindFairyManager.GetBtnDataState(ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy))
        if not this.scoreRewardScrollView then
            this.scoreRewardScrollView =
                SubUIManager.Open(
                SubUIConfig.ScrollCycleView,
                this.scoreRewardRoot.transform,
                this.scoreRewardPre,
                nil,
                Vector2.New(this.scrollRoot.transform.rect.width, this.scrollRoot.transform.rect.height),
                1,
                1,
                Vector2.New(0, 20)
            )
            this.scoreRewardScrollView.moveTween.MomentumAmount = 1
            this.scoreRewardScrollView.moveTween.Strength = 2
        end
        this.scoreRewardScrollView:SetData(
            data,
            function(index, root)
                this.ScoreRewardShow(root, data[index])
            end
        )
        this.scoreRewardScrollView:SetIndex(1)
    elseif CurType == FIND_FAIRY_POPUP_TYPE.BigRank then
        this.title.text = GetLanguageStrById(10626)
        this.noneImage:SetActive(false)
        Util.GetGameObject(this.bigRankRoot, "Rect"):GetComponent("RectTransform"):DOAnchorPosY(-546.5, 0)
        for i = 1, #FindFairyManager.rankRewardData do
            this.BigRankRewardShow(this.bigRankList[i], FindFairyManager.rankRewardData[i], i)
        end
    elseif CurType == FIND_FAIRY_POPUP_TYPE.CurScoreRank then
        this.title.text = GetLanguageStrById(10627)
        if not this.curScoreRankScrollView then
            this.curScoreRankScrollView =
                SubUIManager.Open(
                SubUIConfig.ScrollCycleView,
                this.curScoreRankScroll.transform,
                this.curScoreRankPre,
                nil,
                Vector2.New(this.curScoreRankScroll.transform.rect.width, this.curScoreRankScroll.transform.rect.height),
                1,
                1,
                Vector2.New(0, 10)
            )
            this.curScoreRankScrollView.moveTween.MomentumAmount = 1
            this.curScoreRankScrollView.moveTween.Strength = 2
        end
        NetManager.RequestRankInfo(
            10,
            function(msg)
                this.noneImage:SetActive(#msg.ranks == 0)
                this.CurMyScoreRankShow(msg.myRankInfo)
                this.curScoreRankScrollView:SetData(
                    msg.ranks,
                    function(index, root)
                        this.CurScoreRankShow(root, msg.ranks[index], msg.myRankInfo.rank)
                    end
                )
            end,
            ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
        )
    end
end

function this.CloseView(type)
    CurType = type
    if CurType == FIND_FAIRY_POPUP_TYPE.BigRank then
        if this.liveNode then
            poolManager:UnLoadLive(this.liveName, this.liveNode)
            this.liveName = nil
        end
    elseif CurType == FIND_FAIRY_POPUP_TYPE.ScoreReward then
        Game.GlobalEvent:DispatchEvent(GameEvent.FindFairy.RefreshRedPoint)
    end
end

--寻仙榜（记录条）
function this.FindFairyRecordShow(root, data)
    local click = Util.GetGameObject(root, "Click")
    local playerHead = Util.GetGameObject(root, "PlayerHead")
    local playerName = Util.GetGameObject(root, "PlayerName"):GetComponent("Text")
    local guild = Util.GetGameObject(root, "GuildBg")
    local guildIcon = Util.GetGameObject(root, "GuildBg/GuildIcon"):GetComponent("Image")
    local guildName = Util.GetGameObject(root, "GuildName"):GetComponent("Text")
    local heroHead = Util.GetGameObject(root, "HeroHead")
    --:GetComponent("Image")
    local info = Util.GetGameObject(root, "Info"):GetComponent("Text")

    Util.AddOnceClick(
        click,
        function()
            UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
        end
    )
    if not this.playerScrollHead[root] then
        this.playerScrollHead[root] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD, playerHead)
    end
    this.playerScrollHead[root]:Reset()
    this.playerScrollHead[root]:SetHead(data.head)
    this.playerScrollHead[root]:SetFrame(data.headFrame)
    this.playerScrollHead[root]:SetLevel(data.level)
    this.playerScrollHead[root]:SetScale(Vector3.one * 0.7)

    playerName.text = data.userName
    guild.gameObject:SetActive(data.guildName ~= "")
    if data.guildName == "" then
        guildName.text = GetLanguageStrById(10628)
        guildName.gameObject:GetComponent("RectTransform"):DOAnchorPosX(-63.75, 0)
    else
        guildName.text = GetLanguageStrById(10629) .. data.guildName
        guildName.gameObject:GetComponent("RectTransform"):DOAnchorPosX(0, 0)
        local logoName = GuildManager.GetLogoResName(data.icon)
        guildIcon.sprite = Util.LoadSprite(logoName)
    end
    FindFairyManager.ResetItemView(
        root,
        heroHead.transform,
        this.heroItemList,
        1,
        0.8,
        this.sortingOrder,
        true,
        data.rankInfo.param2,
        data.rankInfo.param3
    )
    info.text = FindFairyManager.TimeStampToDateStr(data.rankInfo.param1)
end

--积分奖励显示 1各滚动条obj 2数据（数据结构:[1]={data[1],data[2],data[3]} //data1为领取状态，1为已领取，0为未领取或未达成；data2为当前积分；data3为当前任务id）
function this.ScoreRewardShow(root, data)
    local rewardRoot = Util.GetGameObject(root, "RewardRoot").transform
    local info = Util.GetGameObject(root, "Info"):GetComponent("Text")
    local stateBtn = Util.GetGameObject(root, "StateBtn")
    local stateImage = Util.GetGameObject(root, "StateBtn"):GetComponent("Image")
    local stateText = Util.GetGameObject(root, "StateBtn/Text"):GetComponent("Text")
    local config = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig, data.missionId)
    info.text = GetLanguageStrById(10630) .. config.Values[1][1] .. GetLanguageStrById(10631)
    FindFairyManager.ResetItemView(root, rewardRoot, this.scoreItemList, 4, 1, this.sortingOrder, false, config.Reward)

    stateBtn:GetComponent("Button").interactable = data.value >= config.Values[1][1] and data.state == 0

    if data.value >= config.Values[1][1] then
        if data.state == 0 then
            stateImage.sprite = Util.LoadSprite(StateImageName[1])
            stateText.text = GetLanguageStrById(10022)
        else
            stateImage.sprite = Util.LoadSprite(StateImageName[2])
            stateText.text = GetLanguageStrById(10350)
        end
        stateBtn:GetComponent("Animator").enabled = true
        stateBtn:GetComponent("RectTransform").localScale = Vector2.one
        stateImage.type = "Simple"
        stateText.color = Color.New(23 / 255, 35 / 255, 42 / 255, 1)
    else
        stateBtn:GetComponent("Animator").enabled = false
        stateBtn:GetComponent("RectTransform").localScale = Vector2.one * 0.8
        stateImage.sprite = Util.LoadSprite(StateImageName[3])
        stateImage.type = "Sliced"
        stateText.text = GetLanguageStrById(10348)
        stateText.color = Color.New(172 / 255, 172 / 255, 170 / 255, 1)
    end
    Util.AddOnceClick(
        stateBtn,
        function()
            NetManager.GetActivityRewardRequest(
                data.missionId,
                FindFairyManager.GetCurActivityId(),
                function(drop)
                    UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)
                    this.SetView(FIND_FAIRY_POPUP_TYPE.ScoreReward)
                end
            )
        end
    )
end

--排名大奖显示
function this.BigRankRewardShow(root, data, index)
    root.gameObject:SetActive(true)
    if index == 1 then
        --local curActivityId=ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)--静态立绘
        --local staticLiveId=FindFairyManager.GetHeroData(curActivityId).Painting
        --liveImage.sprite=Util.LoadSprite(ConfigManager.GetConfigData(ConfigName.ArtResourcesConfig,staticLiveId).Name)
        --立绘特殊处理
        local liveImage = Util.GetGameObject(root, "LiveMask/LiveRoot")
        local curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
        local heroData = FindFairyManager.GetHeroData(curActivityId)
        if this.liveNode then
            poolManager:UnLoadLive(this.liveName, this.liveNode)
            this.liveName = nil
        end
        local artData = ConfigManager.GetConfigData(ConfigName.ArtResourcesConfig, heroData.Live)
        this.liveName = artData.Name
        this.liveNode =
            poolManager:LoadLive(this.liveName, liveImage.transform, Vector3.one * heroData.Scale, Vector3.one)
    else
        -- elseif index > 1 and index <= 3 then
        --     local info = Util.GetGameObject(root, "Info"):GetComponent("Text")
        --     info.text = "第<color=#FCA032>" .. index .. "</color>名大奖"
        -- elseif index >= 4 then
        --     local info = Util.GetGameObject(root, "Info"):GetComponent("Text")
        --     if data.MaxRank == -1 then
        --         info.text = "第<color=#FCA032>200+</color>名大奖"
        --     else
        --         info.text =
        --             "第<color=#FCA032>" .. data.MinRank .. "</color>至<color=#FCA032>" .. data.MaxRank .. "</color>名大奖"
        --     end
        local info = Util.GetGameObject(root, "Info"):GetComponent("Text")
        if data.MinRank == data.MaxRank then
            info.text = GetLanguageStrById(10632) .. index .. GetLanguageStrById(10633)
        else
            if data.MaxRank == -1 then
                info.text = GetLanguageStrById(10634)
            else
                info.text =
                    GetLanguageStrById(10632) .. data.MinRank .. GetLanguageStrById(10635) .. data.MaxRank .. GetLanguageStrById(10633)
            end
        end
    end
    --奖励物品根节点
    local rewardRoot = Util.GetGameObject(root, "RewardRoot").transform
    FindFairyManager.ResetItemView(
        root,
        rewardRoot,
        this.bigItemList,
        4,
        0.9,
        this.sortingOrder,
        false,
        data.RankingReward
    )
end

--本期寻仙积分排名显示
function this.CurMyScoreRankShow(data)
    local myRankNum = tonumber(data.rank)
    local myScoreNum = tonumber(data.param1)
    local myRank = Util.GetGameObject(this.curScoreRankRoot, "MyRank/MyRank"):GetComponent("Text")
    local myScore = Util.GetGameObject(this.curScoreRankRoot, "MyRank/MyScore"):GetComponent("Text")
    if myRankNum == -1 then
        myRank.text = GetLanguageStrById(10321)
        myScore.text = GetLanguageStrById(10636)
    else
        myRank.text = GetLanguageStrById(10104) .. myRankNum
        myScore.text = GetLanguageStrById(10637) .. myScoreNum
    end
end
function this.CurScoreRankShow(root, data, myRank)
    local selfBg = Util.GetGameObject(root, "SelfBG"):GetComponent("Image")
    local rankImage = Util.GetGameObject(root, "RankImage"):GetComponent("Image")
    local rankText = Util.GetGameObject(root, "RankText"):GetComponent("Text")
    local head = Util.GetGameObject(root, "Head")
    local name = Util.GetGameObject(root, "Name"):GetComponent("Text")
    local gate = Util.GetGameObject(root, "Gate"):GetComponent("Text")
    local force = Util.GetGameObject(root, "Force"):GetComponent("Text")

    selfBg.enabled = myRank == data.rankInfo.rank
    rankImage.sprite = SetRankNumFrame(data.rankInfo.rank)
    rankText.text = data.rankInfo.rank > 3 and data.rankInfo.rank or ""
    if not this.playerScrollHead[root] then
        this.playerScrollHead[root] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD, head)
    end
    this.playerScrollHead[root]:Reset()
    this.playerScrollHead[root]:SetHead(data.head)
    this.playerScrollHead[root]:SetFrame(data.headFrame)
    this.playerScrollHead[root]:SetLevel(data.level)
    this.playerScrollHead[root]:SetScale(Vector3.one * 0.7)
    name.text = data.userName
    gate.text = data.rankInfo.param1
    force.text = data.force
end

return FindFairyPopup