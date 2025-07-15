require("Base/BasePanel")
local AdventureAlianInvasionPanel = Inherit(BasePanel)
local this = AdventureAlianInvasionPanel
-- Tab管理器
local TabBox = require("Modules/Common/TabBox")
local _TabFontColor = { default = Color.New(168 / 255, 168 / 255, 167 / 255, 1),
                        select = Color.New(250 / 255, 227 / 255, 175 / 255, 1) }
local _TabData = {
    [1] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10038) },
    [2] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10039) },
    [3] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(10040) },
}
-- 物品数据
local adventureConfig = ConfigManager.GetConfig(ConfigName.AdventureConfig)
local monsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local monsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local injureGoList = {}
--初始化组件（用于子类重写）
function AdventureAlianInvasionPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.contentList = {}
    for i = 1, 3 do
        this.contentList[i] = Util.GetGameObject(self.gameObject, "content" .. i)
    end
    this.item = Util.GetGameObject(self.gameObject, "content3/item")
    this.rankItem = Util.GetGameObject(self.gameObject, "content2/item")
    this.rewardContentGrid = Util.GetGameObject(self.gameObject, "content3/scrollRect/grid")
    this.injureContentGrid = Util.GetGameObject(self.gameObject, "content2/scrollRect")
    this.myRank = Util.GetGameObject(self.gameObject, "content2/bottom/Image (2)/myRank")
    this.injuryTotal = Util.GetGameObject(self.gameObject, "content2/bottom/Image (2)/injuryTotal")
    this.roleImage=Util.GetGameObject(self.gameObject, "content1/roleImage")
    --for i = 1, 100 do
    --    injureGoList[i]=newObject(self.rankItem)
    --    injureGoList[i].transform:SetParent(this.injureContentGrid.transform)
    --    injureGoList[i].transform.localScale = Vector3.one
    --    injureGoList[i].transform.localPosition = Vector3.zero
    --    --injureGoList[i]:SetActive(true)
    --end
    for i = 1, #AdventureManager.minRank do
        local go = newObject(self.item)
        if (i == 1) then
            Util.GetGameObject(go, "rankImage"):GetComponent("RectTransform").sizeDelta = Vector2.New(152, 152)
            Util.GetGameObject(go, "rankImage"):GetComponent("RectTransform").localScale = Vector2.New(0.7, 0.7)
            Util.GetGameObject(go, "rankImage/rankNumberText"):GetComponent("Text").text = ""
            Util.GetGameObject(go, "rankImage"):GetComponent("Image").sprite = Util.LoadSprite("r_playerrumble_paiming_01")
        end
        if (i == 2) then
            Util.GetGameObject(go, "rankImage"):GetComponent("RectTransform").sizeDelta = Vector2.New(152, 152)
            Util.GetGameObject(go, "rankImage"):GetComponent("RectTransform").localScale = Vector2.New(0.7, 0.7)
            Util.GetGameObject(go, "rankImage/rankNumberText"):GetComponent("Text").text = ""
            Util.GetGameObject(go, "rankImage"):GetComponent("Image").sprite = Util.LoadSprite("r_playerrumble_paiming_02")
        end
        if (i == 3) then
            Util.GetGameObject(go, "rankImage"):GetComponent("RectTransform").sizeDelta = Vector2.New(152, 152)
            Util.GetGameObject(go, "rankImage"):GetComponent("RectTransform").localScale = Vector2.New(0.7, 0.7)
            Util.GetGameObject(go, "rankImage/rankNumberText"):GetComponent("Text").text = ""
            Util.GetGameObject(go, "rankImage"):GetComponent("Image").sprite = Util.LoadSprite("r_playerrumble_paiming_03")
        end
        if (i > 3 and i <= 10) then
            Util.GetGameObject(go, "rankImage"):GetComponent("Image").sprite = Util.LoadSprite("r_hero_zhuangbeidi")
            Util.GetGameObject(go, "rankImage"):GetComponent("RectTransform").sizeDelta = Vector2.New(152, 152)
            Util.GetGameObject(go, "rankImage"):GetComponent("RectTransform").localScale = Vector2.New(0.7, 0.7)
            Util.GetGameObject(go, "rankImage"):GetComponent("Image").sprite = Util.LoadSprite("r_hero_zhuangbeidi")
            Util.GetGameObject(go, "rankImage/rankNumberText"):GetComponent("RectTransform").sizeDelta = Vector2.New(140.93, 146.91)
            Util.GetGameObject(go, "rankImage/rankNumberText"):GetComponent("Text").fontSize = 70
            if AdventureManager.minRank[i] == AdventureManager.maxRank[i] then
                Util.GetGameObject(go, "rankImage/rankNumberText"):GetComponent("Text").text = AdventureManager.maxRank[i]
            end
        end
        if (i > 10) then
            Util.GetGameObject(go, "rankImage"):GetComponent("Image").sprite = Util.LoadSprite("r_hero_zhuangbeidi")
            Util.GetGameObject(go, "rankImage"):GetComponent("RectTransform").sizeDelta = Vector2.New(304.56, 156.09)
            Util.GetGameObject(go, "rankImage/rankNumberText"):GetComponent("RectTransform").sizeDelta = Vector2.New(304.56, 156.09)
            Util.GetGameObject(go, "rankImage"):GetComponent("RectTransform").localScale = Vector2.New(0.57, 0.57)
            --Util.GetGameObject(go, "rankImage"):GetComponent("RectTransform").localScale= Vector2.New(1, 1)
            Util.GetGameObject(go, "rankImage/rankNumberText"):GetComponent("Text").fontSize = 69
            if AdventureManager.minRank[i] == 1000 then
                Util.GetGameObject(go, "rankImage/rankNumberText"):GetComponent("Text").text = AdventureManager.minRank[i] .. "+"
            else
                Util.GetGameObject(go, "rankImage/rankNumberText"):GetComponent("Text").text = AdventureManager.minRank[i] .. "-" .. AdventureManager.maxRank[i]
            end
        end
        for j = 1, #AdventureManager.dailyReward[i] do
            local itemdata = {}
            table.insert(itemdata, AdventureManager.dailyReward[i][j][1])
            table.insert(itemdata, AdventureManager.dailyReward[i][j][2])
            local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetTransform(go, "content").transform)
            view:OnOpen(false, itemdata, 0.8)
        end
        go.transform:SetParent(this.rewardContentGrid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go:SetActive(true)
    end

    this.attackNum = Util.GetGameObject(self.gameObject, "content1/detail1/attackNumber")
    this.scrollRoot1 = Util.GetGameObject(self.gameObject, "content1/scrollRoot")
    this.enemyItem = Util.GetGameObject(this.scrollRoot1, "item")
    -- 创建循环列表
    this.ScrollView1 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot1.transform,
            this.enemyItem, nil, Vector2.New(916, 1094.8), 1, 1, Vector2.New(0, 4))
    this.ScrollView1.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    this.ScrollView1.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView1.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView1.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.ScrollView1.moveTween.MomentumAmount = 1
    this.ScrollView1.moveTween.Strength = 2

    this.ScrollView2 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.injureContentGrid.transform,
            this.rankItem, nil, Vector2.New(916, 898.27), 1, 1, Vector2.New(0, 0))
    this.ScrollView2.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    this.ScrollView2.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView2.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView2.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.ScrollView2.moveTween.MomentumAmount = 1
    this.ScrollView2.moveTween.Strength = 2

    -- 初始化Tab管理器
    this.tabbox = Util.GetGameObject(this.gameObject, "top")
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.TabCtrl:Init(this.tabbox, _TabData)

    --
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
end
-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Img"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
end
-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    -- 设置显示
    for i = 1, 3 do
        this.contentList[i]:SetActive(i == index)
    end
    -- 根据显示刷新
    if index == 1 then
        -- 刷新外敌列表显示
        AdventureManager.RequestAdventureEnemyList()
        this.RefreshChallengeTimes()
    elseif index == 2 then
        local injuerData={}
        AdventureManager.GetAdventurnInjureRankRequest()
    elseif index == 3 then
    end
end

--冒险伤害排行榜数据
function AdventureAlianInvasionPanel:InjureRankDataShow()

    this.ScrollView2:SetData(AdventureManager.adventureRankItemInfo, function(index, item)
        local itemData = AdventureManager.adventureRankItemInfo[index]
        this.InjureRankDataAdapter(item, itemData, index)
    end)

end

--冒险伤害排行榜循环滚动加载数据
function this.InjureRankDataAdapter(item, data, i)
    --item:SetActive(true)
    if (i == 1) then
        Util.GetGameObject(item, "rankImage/rankNumberText"):GetComponent("Text").text = ""
        Util.GetGameObject(item, "rankImage"):GetComponent("Image").sprite = Util.LoadSprite("r_playerrumble_paiming_01")
        Util.GetGameObject(item, "rankImage"):GetComponent("RectTransform").sizeDelta = Vector2.New(105, 105)
    end
    if (i == 2) then
        Util.GetGameObject(item, "rankImage/rankNumberText"):GetComponent("Text").text = ""
        Util.GetGameObject(item, "rankImage"):GetComponent("Image").sprite = Util.LoadSprite("r_playerrumble_paiming_02")
        Util.GetGameObject(item, "rankImage"):GetComponent("RectTransform").sizeDelta = Vector2.New(105, 105)
    end
    if (i == 3) then
        Util.GetGameObject(item, "rankImage/rankNumberText"):GetComponent("Text").text = ""
        Util.GetGameObject(item, "rankImage"):GetComponent("Image").sprite = Util.LoadSprite("r_playerrumble_paiming_03")
        Util.GetGameObject(item, "rankImage"):GetComponent("RectTransform").sizeDelta = Vector2.New(105, 105)
    end
    if (i > 3 and i < 10) then
        Util.GetGameObject(item, "rankImage"):GetComponent("Image").sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        Util.GetGameObject(item, "rankImage"):GetComponent("RectTransform").sizeDelta = Vector2.New(105, 105)
        Util.GetGameObject(item, "rankImage/rankNumberText"):GetComponent("Text").text = i
        Util.GetGameObject(item, "rankImage/rankNumberText"):GetComponent("Text").fontSize = 48
    end
    if (i >= 10) then
        Util.GetGameObject(item, "rankImage"):GetComponent("Image").sprite = Util.LoadSprite("r_hero_zhuangbeidi")
        Util.GetGameObject(item, "rankImage"):GetComponent("RectTransform").sizeDelta = Vector2.New(105, 105)
        Util.GetGameObject(item, "rankImage/rankNumberText"):GetComponent("Text").text = i
        Util.GetGameObject(item, "rankImage/rankNumberText"):GetComponent("Text").fontSize = 40
    end

    if (AdventureManager.adventureRankItemInfo ~= nil) then
        --local userHeadIcon=GetResourcePath(itemConfig[AdventureManager.adventureRankItemInfo[i].head].ResourceID)
        Util.GetGameObject(item, "userHeadQuality/userHeadIcon"):GetComponent("Image").sprite =GetPlayerHeadSprite(data.head)
        Util.GetGameObject(item, "userHeadQuality"):GetComponent("Image").sprite =GetPlayerHeadFrameSprite(data.headFrame)
        Util.GetGameObject(item, "userHeadQuality/Image/levelText"):GetComponent("Text").text = data.level
        Util.GetGameObject(item, "userHeadQuality/userNameText"):GetComponent("Text").text = data.name
        Util.GetGameObject(item, "injuryNumber"):GetComponent("Text").text = data.hurt
        if AdventureManager.myInfo.rank <= 0 then
            this.myRank:GetComponent("Text").text = GetLanguageStrById(10041)
            this.injuryTotal:GetComponent("Text").text="0"
        else
            this.myRank:GetComponent("Text").text = AdventureManager.myInfo.rank
            this.injuryTotal:GetComponent("Text").text = AdventureManager.myInfo.hurt
        end

    end
end

--绑定事件（用于子类重写）
function AdventureAlianInvasionPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function AdventureAlianInvasionPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnInjureRank, this.InjureRankDataShow)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnEnemyListChanged, this.RefreshEnemyListShow)
end

--移除事件监听（用于子类重写）
function AdventureAlianInvasionPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnInjureRank, this.InjureRankDataShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnEnemyListChanged, this.RefreshEnemyListShow)
end

--界面打开时调用（用于子类重写）
function AdventureAlianInvasionPanel:OnOpen(...)
    -- 开启计时器
    if not this._CountDownTimer then
        this._CountDownTimer = Timer.New(this.TimeUpdate, 1, -1, true)
        this._CountDownTimer:Start()
    end

    -- 设置
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.AdventureTimes })
end
function AdventureAlianInvasionPanel:OnShow(...)
    this.roleImage:SetActive(false)
    -- tab节点管理
    if this.TabCtrl then
        this.TabCtrl:ChangeTab(1)
    end
end

-- 时间刷新
function this.TimeUpdate()
    if not this.countDownLabs then return end
    local datalist = AdventureManager.GetAdventureEnemyList()
    for _, v in pairs(this.countDownLabs) do
        if datalist[v.index] then
            local leftTime = datalist[v.index].remainTime
            local hour = 0
            local min = 0
            local sec = 0
            sec = math.floor(leftTime % 60)
            hour = math.floor(leftTime / 3600)
            min = 0
            if (hour >= 1) then
                min = math.floor((leftTime - hour * 3600) / 60)
            else
                min = math.floor(leftTime / 60)
            end
            Util.GetGameObject(v.node, "escapeTime"):GetComponent("Text").text = string.format("%02d:%02d:%02d", hour,min,sec)
        end
    end
end

-- 刷新挑战次数
function this.RefreshChallengeTimes()
    -- 挑战次数
    this.attackNum:GetComponent("Text").text = AdventureManager.GetLeftChallengeTimes()
end
-- 刷新外敌列表显示
function this.RefreshEnemyListShow()

    -- 刷新挑战次数
    this.RefreshChallengeTimes()
    -- 敌人列表
    local enemyList = AdventureManager.GetAdventureEnemyList()
    if(#enemyList<1) then
        this.roleImage:SetActive(true)
    else
        this.roleImage:SetActive(false)
    end
    -- 重置列表
    this.countDownLabs = {}
    this.ScrollView1:SetData(enemyList, function(index, item)
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
    local hour = 0
    local min = 0
    local sec = 0
    sec = math.floor(data.remainTime % 60)
    hour = math.floor(data.remainTime / 3600)
    min = 0
    if (hour >= 1) then
        min = math.floor((data.remainTime - hour * 3600) / 60)
    else
        min = math.floor(data.remainTime / 60)
    end
    escapeTime.text = string.format("%02d:%02d:%02d", hour,min,sec)
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

--界面关闭时调用（用于子类重写）
function AdventureAlianInvasionPanel:OnClose()
end
--界面销毁时调用（用于子类重写）
function AdventureAlianInvasionPanel:OnDestroy()
    -- 开启计时器
    if this._CountDownTimer then
        this._CountDownTimer:Stop()
        this._CountDownTimer = nil
    end
    SubUIManager.Close(this.UpView)
    this.ScrollView1 = nil
    this.ScrollView2 = nil

    this.countDownLabs = nil
end

return AdventureAlianInvasionPanel