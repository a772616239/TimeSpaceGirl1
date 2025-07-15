WishPanel = quick_class("CardActivityPanel")
local this = WishPanel
-- local GlobalActivity = ConfigManager.GetConfig(ConfigName.GlobalActivity)
-- local WishActivityRelationConfig = ConfigManager.GetConfig(ConfigName.WishActivityRelationConfig)
-- local WishTaskRewardConfig = ConfigManager.GetConfig(ConfigName.WishTaskRewardConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local RechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
local cardBg = {
    "cn2-X1_kapaihuodong_kapaizhanshi01",
    "cn2-X1_kapaihuodong_kapaizhanshi02",
    "cn2-X1_kapaihuodong_kapaizhanshi03",
    "cn2-X1_kapaihuodong_kapaizhanshi04",
    "cn2-X1_kapaihuodong_kapaizhanshi05",
}
local allData = {}
local wishHeroList = {}--心愿英雄

--初始化组件（用于子类重写）
function WishPanel:InitComponent(parent)
    this.gameObject = parent

    this.time = Util.GetGameObject(this.gameObject,"time/Text"):GetComponent("Text")
    this.pre = Util.GetGameObject(this.gameObject, "itemPre")
    this.scroll = Util.GetGameObject(this.gameObject, "scroll")

    this.cardBg = Util.GetGameObject(this.gameObject, "bg/cardBg"):GetComponent("Image")

    local v = this.scroll:GetComponent("RectTransform").rect
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
            this.pre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0, 5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function WishPanel:BindEvent()
end

--添加事件监听（用于子类重写）
function WishPanel:AddListener()
end

--移除事件监听（用于子类重写）
function WishPanel:RemoveListener()
end

function WishPanel:OnShow(sortingOrder,parent)
    this.Refresh()
    this.SetWish()
    this.SetTime()
end

--界面关闭时调用（用于子类重写）
function WishPanel:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function WishPanel:OnDestroy()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    wishHeroList = {}
end

function this.Refresh()
    CheckRedPointStatus(RedPointType.CardActivity_Haoli)
    allData = CardActivityManager.GetHaoliReward()
    allData[#allData + 1] = {}
    this.scrollView:SetData(allData, function (index, go)
        if index == #allData then
            go:SetActive(false)
            return
        end
        go:SetActive(true)
        this.SetItemData(go, allData[index])
    end)
end

function this.SetWish()
    local num = #CardActivityManager.wishRewardList
    this.cardBg.sprite = Util.LoadSprite(cardBg[num])
    local scale
    if num == 5 then
        scale = 0.65
    else
        scale = 0.8
    end
    for i = 1, #wishHeroList do
        wishHeroList[i]:SetActive(false)
    end
    for i = 1, num do
        local pos = Util.GetGameObject(this.gameObject, "bg/pos"..num.."/"..i)
        if not wishHeroList[i] then
            wishHeroList[i] = poolManager:LoadAsset("card", PoolManager.AssetType.GameObject)
        end
        wishHeroList[i].transform:SetParent(pos.transform)
        wishHeroList[i].transform:GetComponent("RectTransform").localPosition = Vector3.zero
        wishHeroList[i].transform:GetComponent("RectTransform").localScale = Vector2.one*scale
        local config = HeroConfig[CardActivityManager.wishRewardList[i][1]]
        Util.GetGameObject(wishHeroList[i].transform, "card/lv"):GetComponent("Text").text = 1
        Util.GetGameObject(wishHeroList[i].transform, "card/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(config.Painting))
        Util.GetGameObject(wishHeroList[i].transform, "card/pro/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(config.PropertyName))
        Util.GetGameObject(wishHeroList[i].transform, "card/bg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityBgImageByquality(config.Quality, config.Star))
        Util.GetGameObject(wishHeroList[i].transform, "card/frame"):GetComponent("Image").sprite = Util.LoadSprite(GetCardFrame(config.Star))
        SetHeroStars(Util.GetGameObject(wishHeroList[i].transform, "star"), config.Star)
        wishHeroList[i]:SetActive(true)
    end
end

local itemsGrid = {}
local timeDown --倒计时
function this.SetItemData(go, data)
    local title = Util.GetGameObject(go, "title"):GetComponent("Text")
    local price = Util.GetGameObject(go, "btn/Text"):GetComponent("Text")
    local limit = Util.GetGameObject(go, "limit"):GetComponent("Text")
    local mission = Util.GetGameObject(go, "mission"):GetComponent("Text")
    local btn = Util.GetGameObject(go, "btn")
    local grid = Util.GetGameObject(go, "Scroll View/Viewport/reward")
    local slider = Util.GetGameObject(go, "slider/Image"):GetComponent("Image")
    local free = Util.GetGameObject(go, "free")

    title.text = GetLanguageStrById(data.ContentsShow)
    slider.fillAmount = CardActivityManager.wishRewardTimes/data.Condition
    local wishRewardTimes = CardActivityManager.wishRewardTimes
    if wishRewardTimes > data.Condition then wishRewardTimes = data.Condition end
    mission.text = wishRewardTimes.."/"..data.Condition

    local config = RechargeCommodityConfig[data.RechargeId]
    local boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, data.RechargeId) or 0
    local num = config.Limit - boughtNum
    if num < 0 then
        num = 0
    end
    --限购
    limit.text = GetLanguageStrById(11454)..num.."/"..config.Limit..GetLanguageStrById(10054)
    if num > 0 then
        price.text = MoneyUtil.GetMoney(config.Price)
        btn:GetComponent("Button").enabled = true
        Util.SetGray(btn, false)
    else
        price.text = GetLanguageStrById(10526)--已购买
        btn:GetComponent("Button").enabled = false
        Util.SetGray(btn, true)
    end

    --付费
    if itemsGrid[go] then
        for i = 1, #itemsGrid[go] do
            itemsGrid[go][i].gameObject:SetActive(false)
        end
        for i = 1, #config.RewardShow do
            if itemsGrid[go][i+1] then
                itemsGrid[go][i+1]:OnOpen(false, {config.RewardShow[i][1], config.RewardShow[i][2]}, 0.6)
                itemsGrid[go][i+1].gameObject:SetActive(true)
            end
        end
    else
        itemsGrid[go] = {}
        for i = 1, #config.RewardShow do
            itemsGrid[go][i+1] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            itemsGrid[go][i+1].gameObject:SetActive(false)
            local obj = newObjToParent(grid, itemsGrid[go][i+1].transform)
            obj.gameObject:SetActive(false)
        end
        for i = 1, #config.RewardShow do
            itemsGrid[go][i+1]:OnOpen(false, {config.RewardShow[i][1], config.RewardShow[i][2]}, 0.6)
            itemsGrid[go][i+1].gameObject:SetActive(true)
        end
    end

    for i = 2, #itemsGrid[go] do
        if num > 0 then
            itemsGrid[go][i]:SetCorner(2, true)
            itemsGrid[go][i]:SetCorner(4, false)
        else
            itemsGrid[go][i]:SetCorner(2, false)
            itemsGrid[go][i]:SetCorner(4, true)
        end
    end

    --免费
    if not itemsGrid[go][1] then
        itemsGrid[go][1] = SubUIManager.Open(SubUIConfig.ItemView, free.transform)
    end
    itemsGrid[go][1]:OnOpen(false, {data.FreeReward[1], data.FreeReward[2]}, 0.6)
    itemsGrid[go][1].gameObject:SetActive(true)
    local freeState = CardActivityManager.GetHaoliState(data.Id)
    itemsGrid[go][1]:SetCorner(4, freeState == 2)
    itemsGrid[go][1]:SetRedPointState(freeState == 1)
    itemsGrid[go][1]:ClickEvent(function ()
        if timeDown < 1 then
            PopupTipPanel.ShowTip(GetLanguageStrById(10029))--活动已结束
            return
        end
        if freeState == 1 or wishRewardTimes >= data.Condition then
            local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Haoli)
            NetManager.CardSubjectHeroLuxuryGetFreeRequest(activityId, data.Id, function (msg)
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function ()
                    CardActivityManager.SetHaoliState(data.Id)
                    this.Refresh()
                end)
            end)
        else
            PopupTipPanel.ShowTip(GetLanguageStrById(50226))--条件未达成，无法领取奖励
        end
    end)
    Util.AddOnceClick(btn, function ()
        if timeDown < 1 then
            PopupTipPanel.ShowTip(GetLanguageStrById(10029))--活动已结束
            return
        end
        if num <= 0 then
            PopupTipPanel.ShowTip(GetLanguageStrById(10540))
        else
            if freeState == 0 then
                PopupTipPanel.ShowTip(GetLanguageStrById(50226))--条件未达成，无法领取奖励
                return
            end
            --直购商品
            if AppConst.isSDKLogin then
                PayManager.Pay({Id = data.RechargeId}, function ()
                    FirstRechargeManager.RefreshAccumRechargeValue(data.RechargeId)
                    this.Refresh()
                end)
            else
                NetManager.RequestBuyGiftGoods(data.RechargeId, function(msg)
                    FirstRechargeManager.RefreshAccumRechargeValue(data.RechargeId)
                    this.Refresh()
                end)
            end
        end
    end)
end

function this.SetTime()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    local endTime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.CardActivity_Haoli)
    timeDown = endTime - GetTimeStamp()
    this.time.text = GetLanguageStrById(12321)..TimeToDHMS(timeDown)
    this.timer = Timer.New(function()
        timeDown = timeDown - 1
        if timeDown < 1 then
            -- this:ClosePanel()
            this.time.text = ""
        end
        this.time.text = GetLanguageStrById(12321)..TimeToDHMS(timeDown)
    end, 1, -1, true)
    this.timer:Start()
end

return WishPanel