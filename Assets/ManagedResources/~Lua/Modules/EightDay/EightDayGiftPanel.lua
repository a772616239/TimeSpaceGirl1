require("Base/BasePanel")
local EightDayGiftPanel = Inherit(BasePanel)
local this = EightDayGiftPanel

local EightDayRewardConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", ActivityTypeDef.EightDayGift)

-- 换皮后的卡片配色（圣诞夜深底主题）：深梅紫卡体 + 暖金高亮 + 米白文字
-- 旧版亮紫 #A37CE4 在深色新底板上很跳，且已领取态把白字压到 50% 透明（对比度 1.9:1）几乎看不清
local CardColor = {
    -- 未达成 / 未来天数
    body      = Color.New(60/255, 48/255, 96/255, 1),   -- #3C3060
    band      = Color.New(44/255, 34/255, 73/255, 1),   -- #2C2249 顶部天数带
    text      = Color.New(255/255, 233/255, 194/255, 1),-- #FFE9C2
    -- 今日可领
    bodyReady = Color.New(239/255, 193/255, 78/255, 1), -- #EFC14E
    bandReady = Color.New(217/255, 162/255, 47/255, 1), -- #D9A22F
    textReady = Color.New(74/255, 44/255, 6/255, 1),    -- #4A2C06
    -- 已领取
    bodyDone  = Color.New(42/255, 35/255, 68/255, 1),   -- #2A2344
    bandDone  = Color.New(34/255, 28/255, 56/255, 1),   -- #221C38
    textDone  = Color.New(167/255, 155/255, 200/255, 1),-- #A79BC8
    scrim     = Color.New(0, 0, 0, 0.18),               -- 已领取的压暗罩，原来 0.39 太黑
}
local ItemList = {}--奖励List
local ItemViewList = {}
local rewardData--后端数据
local curDay--当前可签到/可领取的那一天（签到制的推进结果）
local canSignToday--今天是否还能签到（每天最多一次）

--初始化组件（用于子类重写）
function this:InitComponent()
    this.btnClose = Util.GetGameObject(this.gameObject,"mask")
    this.BtnBack = Util.GetGameObject(this.gameObject,"BtnBack")	
    this.btnPreview = Util.GetGameObject(this.gameObject,"panel/bg/btnPreview")
    this.show = Util.GetGameObject(this.gameObject,"panel/show")--根节点
    this.itemPre = Util.GetGameObject(this.gameObject,"panel/show/itemPre")--预设
    this.effect = Util.GetGameObject(this.gameObject,"panel/effect")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.btnClose,function()
        this:ClosePanel()
    end)
    Util.AddClick(this.BtnBack,function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

function this:OnSortingOrderChange()
end

--界面打开时调用（用于子类重写）
function this:OnOpen(...)
end

-- 打开，重新打开时回调
function this:OnShow()
    this:Refresh()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    ItemList = {}
    ItemViewList = {}
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
end

function this:Refresh()
    -- 先停掉上一轮挂在那张卡上的倒计时：跨天刷新后那张卡不再是「待签卡」，
    -- 旧 timer 还在跑的话会继续往它的 day.text 里写时间
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
    rewardData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.EightDayGift)
    if not rewardData or not rewardData.mission then
        curDay = 1
        canSignToday = false
        return
    end
    -- 签到制：天数只由「玩家主动签到」累加，不再按建号自然日往前推。
    -- curDay = 第一个还没领的天，也就是「今天可以签到的那一天」；
    -- 今天已经签过 ⇒ canSignToday=false，这一天要等明天 0 点才解锁。
    -- 断签不重置进度：漏签几天回来还是接着上一次的天数继续 +1。
    local nextDay, _, canSign = EightDaySignProgress(rewardData)
    curDay = nextDay
    canSignToday = canSign
    this:SetAllReward()
end

function this:SetAllReward()
    for i = 1, #EightDayRewardConfig do
        local item = ItemList[i]
        if not item then
            item = newObject(this.itemPre)
            item.name = "itemPre_"..i
            item.transform:SetParent(this.show.transform)
            item.transform.localScale = Vector3.one
            item.transform.localPosition = Vector3.zero
            ItemList[i] = item
        end
        item.gameObject:SetActive(true)
        this:SetSingleReward(item, i)
    end
end

function this:SetSingleReward(item, i)
    local body = item:GetComponent("Image")--卡片底
    local band = Util.GetGameObject(item,"Image"):GetComponent("Image")--卡片顶部天数带
    local kuang = Util.GetGameObject(item, "kuang"):GetComponent("Image")
    local day = Util.GetGameObject(item, "kuang/reward/days/Text"):GetComponent("Text")
    local dayImg = Util.GetGameObject(item, "kuang/reward/days"):GetComponent("Image")
    local icon = Util.GetGameObject(item, "kuang/reward/icon")
    local get = Util.GetGameObject(item, "getBtn")
    local redPoint = Util.GetGameObject(item, "redPoint")
    local mask = Util.GetGameObject(item, "kuang/reward/mask")
    local transparency = Util.GetGameObject(item, "kuang/reward/transparency")
    local transImg = transparency:GetComponent("Image")
    local isCanGet = rewardData.mission[i].state--0：未领 1：已领
    local isTodayCard = (i == curDay)--今天要签到的那一张
    local canClaim = isTodayCard and canSignToday and isCanGet == 0--此刻能不能点（= 今天还能签到）

    if isTodayCard and not canSignToday then
        -- 今天已经签过了：这一张要等明天 0 点才解锁，倒计时挂在这里
        this:SetRemainTime(day, i)
        dayImg.enabled = false
    else
        dayImg.enabled = true
        day.text = --[[GetLanguageStrById(10311)..NumToSimplenessFont[i]..]]GetLanguageStrById(10021)
        dayImg.sprite = Util.LoadSprite("cn2-X1_baridenglu_tian_0" .. i)
    end

    --奖励的Icon
    if not ItemViewList[i] then
        local view = SubUIManager.Open(SubUIConfig.ItemView,icon.transform)
        ItemViewList[i] = view
    end
    ItemViewList[i]:OnOpen(false,EightDayRewardConfig[i].Reward[1],1,false)

    --2\3\8可领取的金框
    if i == 2 or i == 3 or i == 8 then
        kuang.enabled = true--isCanGet == 0 and curDay >= i
    end

    get:SetActive(canClaim)
    mask:SetActive(isCanGet == 1)

    --先铺默认态（未达成 / 未来天数），再按状态覆盖
    body.color = CardColor.body
    band.color = CardColor.band
    dayImg.color = CardColor.text
    day.color = CardColor.text
    ItemViewList[i].num.color = CardColor.text
    transImg.color = CardColor.scrim
    transparency:SetActive(false)

    if isCanGet == 1 then--已领取（含旧数据里已经领过的天）：压暗降饱和，但文字仍保持可读
        body.color = CardColor.bodyDone
        band.color = CardColor.bandDone
        dayImg.color = CardColor.textDone
        day.color = CardColor.textDone
        ItemViewList[i].num.color = CardColor.textDone
        transparency:SetActive(true)
    elseif canClaim then--今天可签到：暖金卡 + 深棕字，跟新底板的红金圣诞调子走
        body.color = CardColor.bodyReady
        band.color = CardColor.bandReady
        dayImg.color = CardColor.textReady
        day.color = CardColor.textReady
        ItemViewList[i].num.color = CardColor.textReady
    end

    redPoint:SetActive(canClaim)

    Util.AddOnceClick(get,function()
        if not canClaim then
            return
        end
        NetManager.GetActivityRewardRequest(rewardData.mission[i].missionId, rewardData.activityId, function(drop)
            -- 领到奖励才算签到成功：先落本地签到日期，再同步本地 state。
            -- 请求失败走不到这个回调 ⇒ 不会出现「签到成功却没奖励」。
            EightDaySignMarkSigned()
            rewardData.mission[i].state = 1
            --获得英雄表现
            if drop.Hero ~= nil and #drop.Hero > 0 then
                local itemDataList = {}
                local itemDataStarList = {}
                for i = 1, #drop.Hero do
                    local heroData = ConfigManager.TryGetConfigDataByKey(ConfigName.HeroConfig, "Id", drop.Hero[i].heroId)
                    table.insert(itemDataList, heroData)
                    table.insert(itemDataStarList, drop.Hero[i].star)
                end
                UIManager.OpenPanel(UIName.PublicGetHeroPanel, itemDataList, itemDataStarList,function ()
                    UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                        ActivityGiftManager.sevenDayGetRewardState[i] = 1
                        this:Refresh()
                        Game.GlobalEvent:DispatchEvent(GameEvent.EightDay.GetRewardSuccess)
                        CheckRedPointStatus(RedPointType.EightTheLogin)
                        CheckRedPointStatus(RedPointType.CourtesyDress_SevenDay)
                    end)
                end)
            else
                UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                    ActivityGiftManager.sevenDayGetRewardState[i] = 1
                    this:Refresh()
                    Game.GlobalEvent:DispatchEvent(GameEvent.EightDay.GetRewardSuccess)
                    CheckRedPointStatus(RedPointType.EightTheLogin)
                    CheckRedPointStatus(RedPointType.CourtesyDress_SevenDay)
                end)
            end
        end)
    end)
end

function this:SetRemainTime(day, i)
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
    if not self.localTimer then
        self.localTimer = Timer.New(function ()
            local t = CalculateSecondsNowTo_N_OClock(24)
            if t-1 < 0 then
                Timer.New(function()
                    this:Refresh()
                end, 1, 1, true):Start()
            end
            day.text = TimeToHMS(t)
        end, 1, -1, true)
        self.localTimer:Start()
    end
end

return EightDayGiftPanel