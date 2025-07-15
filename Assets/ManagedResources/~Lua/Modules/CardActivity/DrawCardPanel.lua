DrawCardPanel = quick_class("CardActivityPanel")
local this = DrawCardPanel

local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local curIndex = 1  --英雄下标
local liveConfig    --当前立绘数据
local liveObj       --当前立绘
local wishLiveConfig--切换心愿里的立绘数据
local wishLiveObj   --切换心愿里的立绘
local wishHero = {} --心愿按钮
local heroItem = {} --心愿英雄
--初始化组件（用于子类重写）
function DrawCardPanel:InitComponent(parent)
    this.gameObject = parent

    this.time = Util.GetGameObject(this.gameObject, "time/Text"):GetComponent("Text")

    this.btnJackpotDetails = Util.GetGameObject(this.gameObject, "btnJackpotDetails")--奖池详情
    this.btnComment = Util.GetGameObject(this.gameObject, "btnComment")--评论
    this.btn1 = Util.GetGameObject(this.gameObject, "btn1")
    this.btn10 = Util.GetGameObject(this.gameObject, "btn10")
    this.btnDetails = Util.GetGameObject(this.gameObject, "btnDetails")--详情
    this.btnChange = Util.GetGameObject(this.gameObject, "btnChange")--切换心愿

    this.count = Util.GetGameObject(this.gameObject, "count"):GetComponent("Text")--次数

    this.changeWishPanel = Util.GetGameObject(this.gameObject, "ChangeWishPanel")--切换心愿窗口
    this.scroll = Util.GetGameObject(this.changeWishPanel, "scroll")
    this.pre = Util.GetGameObject(this.changeWishPanel, "scroll/pre")
    local rootHight = this.scroll.transform.rect.height
    local width = this.scroll.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
            this.pre, nil, Vector2.New(width, rootHight), 2, 1, Vector2.New(0, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2

    --切换心愿相关
    this.btnDetails2 = Util.GetGameObject(this.changeWishPanel, "btnDetails")--详情
    this.btnComment2 = Util.GetGameObject(this.changeWishPanel, "btnComment")--评论
    this.btnChange2 = Util.GetGameObject(this.changeWishPanel, "btnChange")--切换
    this.btnWishBack = Util.GetGameObject(this.changeWishPanel, "btnBack")
    this.btnLeft = Util.GetGameObject(this.changeWishPanel, "btnLeft")
    this.btnRight = Util.GetGameObject(this.changeWishPanel, "btnRight")
end

--绑定事件（用于子类重写）
function DrawCardPanel:BindEvent()
    Util.AddClick(this.btnChange, function ()
        this.ChangeWish(CardActivityManager.wishPool)
        this.changeWishPanel:SetActive(true)
    end)
    Util.AddClick(this.btnComment, function ()
        UIManager.OpenPanel(UIName.CommentPanel, liveConfig)
    end)
    Util.AddClick(this.btnJackpotDetails, function ()
        UIManager.OpenPanel(UIName.HeroPreviewPanel, 3, false)
    end)
    Util.AddClick(this.btnDetails, function ()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, liveConfig.Id, liveConfig.Star)
    end)
    Util.AddClick(this.btn1, function ()
        CardActivityManager.Recruit(1, function ()
            this.SetRecruitCost()
            this.RefreshTimes()
        end)
    end)
    Util.AddClick(this.btn10, function ()
        CardActivityManager.Recruit(2, function ()
            this.SetRecruitCost()
            this.RefreshTimes()
        end)
    end)

    --切换心愿相关
    Util.AddClick(this.btnDetails2, function ()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, wishLiveConfig.Id, wishLiveConfig.Star)
    end)
    Util.AddClick(this.btnComment2, function ()
        UIManager.OpenPanel(UIName.CommentPanel, wishLiveConfig)
    end)
    Util.AddClick(this.btnChange2, function ()
        if CardActivityManager.wishPool == curIndex then
            return
        end
        NetManager.CardSubjeckWishPoolChangeRequest(ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Draw), curIndex, function ()
            CardActivityManager.wishPool = curIndex
            this.SetWishInfo()
            Util.SetGray(this.btnChange2, true)
            PopupTipPanel.ShowTipByLanguageId(50236)
        end)
    end)
    Util.AddClick(this.btnWishBack, function ()
        this.changeWishPanel:SetActive(false)
    end)
    Util.AddClick(this.btnLeft, function ()
        curIndex = curIndex - 1
        if curIndex < 1 then
            curIndex = #wishHero
        end
        this.ChangeWish(curIndex)
    end)
    Util.AddClick(this.btnRight, function ()
        curIndex = curIndex + 1
        if curIndex > #wishHero then
            curIndex = 1
        end
        this.ChangeWish(curIndex)
    end)
end

--添加事件监听（用于子类重写）
function DrawCardPanel:AddListener()
end

--移除事件监听（用于子类重写）
function DrawCardPanel:RemoveListener()
end

function DrawCardPanel:OnShow(sortingOrder, parent)
    if sortingOrder then
        this.changeWishPanel:GetComponent("Canvas").sortingOrder = sortingOrder + 10
    end

    CardActivityManager.InitWish(function ()
        this.SetWishInfo()
        this.SetScroll()
        this.RefreshTimes()
        this.SetRecruitCost()
    end)

    --倒计时
    local endtime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.CardActivity_Task)
    CardActivityManager.TimeDown(this.time, endtime - GetTimeStamp())
end

--界面关闭时调用（用于子类重写）
function DrawCardPanel:OnClose()
    CardActivityManager.StopTimeDown()
end

--界面销毁时调用（用于子类重写）
function DrawCardPanel:OnDestroy()
    if liveObj then
        UnLoadHerolive(liveConfig, liveObj)
        Util.ClearChild(this.root.transform)
        liveObj = nil
    end
    if wishLiveObj then
        UnLoadHerolive(wishLiveConfig, wishLiveObj)
        Util.ClearChild(this.wishRoot.transform)
        wishLiveObj = nil
    end
    wishHero = {}
    heroItem = {}
end

--设置心愿信息
function this.SetWishInfo()
    local data = HeroConfig[CardActivityManager.GetCurHeroConfig()]
    curIndex = CardActivityManager.wishPool
    this.root = Util.GetGameObject(this.gameObject, "root")
    local camp = Util.GetGameObject(this.gameObject, "info/camp"):GetComponent("Image")--阵营
    local name = Util.GetGameObject(this.gameObject, "info/name"):GetComponent("Text")
    local star = Util.GetGameObject(this.gameObject, "info/star")
    local location = Util.GetGameObject(this.gameObject, "info/location"):GetComponent("Image")--定位
    local locationTxt = Util.GetGameObject(this.gameObject, "info/location/Text"):GetComponent("Text")

    if liveObj then
        UnLoadHerolive(liveConfig, liveObj)
        Util.ClearChild(this.root.transform)
        liveObj = nil
    end
    liveConfig = data
    liveObj = LoadHerolive(liveConfig, this.root.transform)

    SetHeroStars(star, data.Star)
    name.text = GetLanguageStrById(data.ReadingName)
    camp.sprite = Util.LoadSprite(GetProStrImageByProNum(data.PropertyName))
    location.sprite = Util.LoadSprite(ProfessionImage[data.Profession])
    locationTxt.text = GetLanguageStrById(data.HeroLocationDesc1)
end

--设置招募消耗
function this.SetRecruitCost()
    local cost1 = Util.GetGameObject(this.btn1, "cost"):GetComponent("Image")
    local cost1Txt = Util.GetGameObject(this.btn1, "cost/Text"):GetComponent("Text")
    local cost10 = Util.GetGameObject(this.btn10, "cost"):GetComponent("Image")
    local cost10Txt = Util.GetGameObject(this.btn10, "cost/Text"):GetComponent("Text")

    local config1 = ConfigManager.GetConfigData(ConfigName.LotterySetting, CardActivityManager.lotteryId[1])
    cost1.sprite = Util.LoadSprite(GetResourcePath(ItemConfig[config1.CostItem[1][1]].ResourceID))
    cost1Txt.text = config1.CostItem[1][2]

    local config10 = ConfigManager.GetConfigData(ConfigName.LotterySetting, CardActivityManager.lotteryId[2])
    cost10.sprite = Util.LoadSprite(GetResourcePath(ItemConfig[config10.CostItem[1][1]].ResourceID))
    cost10Txt.text = config10.CostItem[1][2]

    local redpoint = Util.GetGameObject(this.btn1, "redpoint")
    local redpoint2 = Util.GetGameObject(this.btn10, "redpoint")
    local myCount = BagManager.GetItemCountById(ItemConfig[config1.CostItem[1][1]].Id)
    redpoint:SetActive(myCount >= config1.CostItem[1][2])
    local myCount2 = BagManager.GetItemCountById(ItemConfig[config10.CostItem[1][1]].Id)
    redpoint2:SetActive(myCount2 >= config10.CostItem[1][2])
    CheckRedPointStatus(RedPointType.CardActivity_Draw)
end

--刷新次数
function this.RefreshTimes()
    -- 抽取%s次之后必得心愿奖励
    this.count.text = string.format(GetLanguageStrById(50223), CardActivityManager.wishTimes)
end

--设置所有可选择的心愿英雄
function this.SetScroll()
    local allWish = CardActivityManager.wishRewardList
    this.ScrollView:SetData(allWish, function (index, go)
        local config = HeroConfig[allWish[index][1]]
        local pos = Util.GetGameObject(go, "pos")
        local name = Util.GetGameObject(go, "name"):GetComponent("Text")
        name.text = GetLanguageStrById(config.ReadingName)
        if not heroItem[index] then
            heroItem[index] = SubUIManager.Open(SubUIConfig.ItemView, pos.transform)
        end
        heroItem[index]:OnOpen(false, {config.Id, 1}, 0.9)
        heroItem[index]:ClickEnable(false)
        Util.AddOnceClick(go, function ()
            curIndex = index
            this.ChangeWish(curIndex)
        end)

        local state = true
        for index, value in ipairs(wishHero) do
            if go == value then
                state = false
            end
        end
        if state then table.insert(wishHero, go) end
    end)
end

local btnSprite = {
    "cn2-X1_kapaihuodong_yingxiongweixuan",
    "cn2-X1_kapaihuodong_yingxiongxuanzhong"
}
--切换心愿
function this.ChangeWish(index)
    for i, v in ipairs(wishHero) do
        v:GetComponent("Image").sprite = Util.LoadSprite(btnSprite[1])
        if i == index then
            v:GetComponent("Image").sprite = Util.LoadSprite(btnSprite[2])
        end
    end
    local data = HeroConfig[CardActivityManager.wishRewardList[index][1]]
    Util.SetGray(this.btnChange2, index == CardActivityManager.wishPool)
    this.SetChangeWishPanel(data)
end

--设置切换心愿
function this.SetChangeWishPanel(data)
    this.wishRoot = Util.GetGameObject(this.changeWishPanel, "root")
    local camp = Util.GetGameObject(this.changeWishPanel, "info/camp"):GetComponent("Image")--阵营
    local name = Util.GetGameObject(this.changeWishPanel, "info/name"):GetComponent("Text")
    local star = Util.GetGameObject(this.changeWishPanel, "info/star")
    local location = Util.GetGameObject(this.changeWishPanel, "info/location"):GetComponent("Image")--定位
    local locationTxt = Util.GetGameObject(this.changeWishPanel, "info/location/Text"):GetComponent("Text")
    local cost = Util.GetGameObject(this.changeWishPanel, "btnChange/cost"):GetComponent("Image")--消耗
    local costTxt = Util.GetGameObject(this.changeWishPanel, "btnChange/cost/Text"):GetComponent("Text")

    if wishLiveObj then
        UnLoadHerolive(wishLiveConfig, wishLiveObj)
        Util.ClearChild(this.wishRoot.transform)
        wishLiveObj = nil
    end
    wishLiveConfig = data
    wishLiveObj = LoadHerolive(wishLiveConfig, this.wishRoot.transform)

    SetHeroStars(star, data.Star)
    name.text = GetLanguageStrById(data.ReadingName)
    camp.sprite = Util.LoadSprite(GetProStrImageByProNum(data.PropertyName))
    location.sprite = Util.LoadSprite(ProfessionImage[data.Profession])
    locationTxt.text = GetLanguageStrById(data.HeroLocationDesc1)
    cost.sprite = Util.LoadSprite(GetResourcePath(ItemConfig[CardActivityManager.changeWishCost[1]].ResourceID))
    costTxt.text = CardActivityManager.changeWishCost[2]
end

return DrawCardPanel