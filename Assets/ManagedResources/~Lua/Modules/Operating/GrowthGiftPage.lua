local util = require "cjson.util"
local GrowthGiftPage = quick_class("GrowthGiftPage")
local curGiftsId--当前礼包Id
local actRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)--读取礼包任务信息
local rewardNameConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)--读取奖励名称信息
local GlobalActivity = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local MainLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)

local giftList = {
    [101] = 6,--表内没有礼包id（101、102、103、104、105）和ActivityId的对应关系，
    [102] = 7,
    [103] = 8,--自定义本表建立对应关系
    [104] = 9,
    [105] = 16,
}

function GrowthGiftPage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
    self.ItemList = {}
end

function GrowthGiftPage:InitComponent(gameObject)
    self.btnInvest = Util.GetGameObject(gameObject, "Bg/bg/btnInvest")
    self.btnInvest:GetComponent("Button").onClick:AddListener(
        function()
            self:OnBtnInvestClicked()
        end
    )
    self.btnInvestText = Util.GetGameObject(gameObject, "Bg/bg/btnInvest/Text"):GetComponent("Text")
    --滚动条和预设
    self.scrollItem = Util.GetGameObject(gameObject, "Bg/scrollItem")
    self.itemPre = Util.GetGameObject(gameObject, "Bg/ItemPre")
    --设置滚动条
    local rootHight = self.scrollItem.transform.rect.height
    local width = self.scrollItem.transform.rect.width
    self.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scrollItem.transform,
            self.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 0))
    self.scrollView.moveTween.MomentumAmount = 1
    self.scrollView.moveTween.Strength = 2

    self.freeBtn = Util.GetGameObject(gameObject, "Bg/bg/freeBtn")
    self.redPoint = Util.GetGameObject(gameObject, "Bg/bg/freeBtn/redPoint")
    self.received = Util.GetGameObject(gameObject, "Bg/bg/freeBtn/received")
end

function GrowthGiftPage:BindEvent()
end

function GrowthGiftPage:OnShow()
    --> GlobalActivity 转
    local globalActivityConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.GlobalActivity, "Type", 6)
    table.sort(globalActivityConfigs, function(a, b)
        return a.Id < b.Id
    end)
    local idx = 1
    for i = 101, 105 do
        giftList[i] = globalActivityConfigs[idx].Id
        idx = idx + 1
    end

    -- NetManager.InitFightPointLevelInfo()
    self.gameObject:SetActive(true)
    self:RefreshData()
    self:RefreshFreeData()
end

function GrowthGiftPage:RefreshData()
    self:SetBtnInvestState()
    self:RefreshGiftData()
end

function GrowthGiftPage:RefreshGiftData()
    local list = {}
    --判断是否已经有了List
    if self.taskList then
        table.walk(self.taskList,function(taskItem)
            taskItem.cloneObj:SetActive(false)
        end)
    end

    for _, configInfo in ConfigPairs(actRewardConfig) do
        if configInfo.ActivityId == giftList[curGiftsId] then
            table.insert(list, configInfo)
        end
    end

    --按照领取状态排序
    --取不到任务数据时按 0 处理：这里一旦抛错，整个列表刷新会中断，
    --表现就是「领完奖红点还在、按钮还是可点」
    table.sort(list, function(a, b)
        local info_a = ActivityGiftManager.GetActivityInfo(a.ActivityId, a.Id)
        local info_b = ActivityGiftManager.GetActivityInfo(b.ActivityId, b.Id)
        local state_a = info_a and info_a.state or 0
        local state_b = info_b and info_b.state or 0
        if state_a == 0 and state_b ~= 0 then
            return true
        end
        if state_a ~= 0 and state_b == 0 then
            return false
        end
        if state_a == state_b then
            return a.Id < b.Id
        end
        return state_a < state_b
    end)

    self.scrollView:SetData(list, function(index, item)
        self:RefreshShowData(item, list[index])
    end)
    -- 🔴 首开不要再用 DelayCreation 逐行显隐：它会把刚 SetData 出来的 item 全部
    -- SetActive(false)，OperatingPanel 随后调的逐格入场（ItemPopIn.PlayPage）就一个都收不到
    -- —— 这页的动画之前就是这么漏掉的（另一处是 page_9 的手工克隆列表）。
    -- 逐格放大缩小本身就是「一行一行冒出来」，交给它，别叠两套。
end

--刷新每一条item
function GrowthGiftPage:RefreshShowData(item, data)
    -- 一律以「这一行配置自己的 ActivityId」为准。
    -- 成长礼金 5 个档位(101~105)各对应一个活动 Id(6/601/602/603/604)，IsActivityTypeOpen 只返回当前开启的那一个；
    -- 拿它去查别的档位的任务会取到 nil，服务器 takeReward 也会校验 config.ActivityId == 请求里的 activityId
    -- （不等直接 CFG_NULL），表现就是「点了没反应 / 领完红点不消失 / 还能再点一次」。
    local activityId = data.ActivityId or ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.GrowthReward)
    local singleRewardData = activityId and ActivityGiftManager.GetActivityInfo(activityId, data.Id) or nil
    local activityConfig = activityId and GlobalActivity[activityId] or nil
    local havaBought = activityConfig and OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.GrowthReward, activityConfig.CanBuyRechargeId) or nil
    local openStatus = activityId and ActivityGiftManager.GetActivityOpenStatus(activityId) or false
    
    local condition = Util.GetGameObject(item, "contents/lv"):GetComponent("Text")
    local image_icon1 = Util.GetGameObject(item,"Image_1/Image_icon1"):GetComponent("Image")
    local text_Num1 = Util.GetGameObject(item,"Image_1/text_num1"):GetComponent("Text")
    local image_icon2 = Util.GetGameObject(item,"Image_2/Image_icon2"):GetComponent("Image")
    local text_Num2 = Util.GetGameObject(item,"Image_2/text_num2"):GetComponent("Text")
    --按钮
    local btnGet = Util.GetGameObject(item, "btnGet")
    -- local btnGo = Util.GetGameObject(item, "btnGo")
    -- local btnFinish = Util.GetGameObject(item, "btnFinish")
    local redPoint = Util.GetGameObject(item,"btnGet/redPoint")

    -- 物品Item
    local isCanGetReward
    local shows = actRewardConfig[data.Id].Reward
    if actRewardConfig[data.Id].Values[1][1] == ConditionType.Level then
        condition.text = "Lv" .. actRewardConfig[data.Id].Values[1][2]
        isCanGetReward = PlayerManager.level >= actRewardConfig[data.Id].Values[1][2]
    elseif actRewardConfig[data.Id].Values[1][1] == ConditionType.CarBon then
        local curLevel = tonumber(MainLevelConfig[FightPointPassManager.curOpenFight].Name - 1)
        local target = tonumber(MainLevelConfig[actRewardConfig[data.Id].Values[1][2]].Name)
        isCanGetReward = curLevel >= target
        condition.text =
            string.format("<color=#fffff><size=30>%s</size></color>",GetLanguageStrById(10356)) ..
            MainLevelConfig[actRewardConfig[data.Id].Values[1][2]].Name ..
            string.format("<color=#fffff><size=30>%s</size></color>",GetLanguageStrById(10622))
    end
    local state = singleRewardData and singleRewardData.state or 0    --任务领取状态

    local goods = OperatingManager.GetHadBuyGoodsTypeId(GoodsTypeDef.GrowthReward)--已购买礼包ID
    image_icon1.sprite = Util.LoadSprite(GetResourcePath(rewardNameConfig[shows[1][1]].ResourceID))
    image_icon2.sprite = Util.LoadSprite(GetResourcePath(rewardNameConfig[shows[1][1]].ResourceID))
    text_Num1.text = "x" .. shows[1][2]-888
    text_Num2.text = "x" .. 888
    --设置按钮状态 0.未领取 1.已领取
    if isCanGetReward then
        if state == 0 then
            redPoint:SetActive(goods == curGiftsId)
            Util.SetGray(btnGet,false)
            Util.GetGameObject(btnGet,"get"):GetComponent("Text").text = GetLanguageStrById(10022)--领取
        elseif state == 1 then
            redPoint:SetActive(false)
            Util.SetGray(btnGet,true)
            Util.GetGameObject(btnGet,"get"):GetComponent("Text").text = GetLanguageStrById(10350)--已领取
        end
    else
        redPoint:SetActive(false)
        Util.SetGray(btnGet,true)
        Util.GetGameObject(btnGet,"get"):GetComponent("Text").text = GetLanguageStrById(10348)--未达成
    end

    -- 这条奖励已经领过（同一个按钮闭包只允许成功一次，防止列表还没重绘时又被点）
    local claimed = false
    Util.AddOnceClick(btnGet,function()
        -- 同一时刻只允许一笔领奖请求：列表刷新/翻页会重新绑按钮，
        -- 响应回来前连点两下会发两次请求（第二笔服务器报 HAD_TAKE_REWARD，玩家侧看起来就是"能重复领"）。
        -- 5 秒兜底：请求超时/断线时回调不会回来，不能让按钮永久点不动。
        local now = GetTimeStamp and GetTimeStamp() or 0
        if claimed then
            return
        end
        if self.claiming and now - (self.claimingAt or 0) < 5 then
            return
        end
        if not singleRewardData or not activityId then
            PopupTipPanel.ShowTipByLanguageId(11467)
            return
        end
        local packageInfo = OperatingManager.IsGrowthGiftGoodsAvailable(GoodsTypeDef.GrowthReward)--packageInfo:当前成长基金礼包ID（ID：101、102、103、104、105）
        if not openStatus or (havaBought and havaBought.buyTimes < 1) then
            PopupTipPanel.ShowTipByLanguageId(11467)
            return
        end
        if packageInfo and packageInfo.buyTimes == 0 then
            PopupTipPanel.ShowTipByLanguageId(11467)
            return
        end

        if isCanGetReward then
            self.claiming = true
            self.claimingAt = now
            NetManager.GetActivityRewardRequest(data.Id, activityId, function(drop)
                self.claiming = false
                claimed = true
                UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)
                -- 状态必须写到「这一行配置的 ActivityId」下，否则读回来还是 state=0，红点与领取按钮都复位不了
                ActivityGiftManager.SetActivityInfo(activityId, data.Id, 1)
                state = 1
                -- 先把这一条自己改成"已领取"，不等整表刷新：整表刷新一旦中途抛错，红点就会永久留在按钮上
                if redPoint then
                    redPoint:SetActive(false)
                end
                Util.SetGray(btnGet, true)
                Util.GetGameObject(btnGet, "get"):GetComponent("Text").text = GetLanguageStrById(10350)--已领取
                CheckRedPointStatus(RedPointType.GrowthGift)

                --检测奖励是否全部领完
                local allTaken = true
                local t = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", activityId)
                for i = 1, #t do
                    local info = ActivityGiftManager.GetActivityInfo(activityId, t[i].Id)
                    if not info or info.state ~= 1 then
                        allTaken = false
                        break
                    end
                end
                if allTaken then
                    if activityId == 604 then--604 是最后一个礼包的ActivityId
                        MsgPanel.ShowOne(GetLanguageStrById(11468))
                    else
                        MsgPanel.ShowOne(GetLanguageStrById(11469))
                    end
                    self:RefreshData()
                else
                    self:RefreshGiftData()
                end
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(11470)
        end
    end)
end

function GrowthGiftPage:OnHide()
    self.gameObject:SetActive(false)
end

function GrowthGiftPage:OnDestroy()
end

--更改特效层级
function GrowthGiftPage:OnSortingOrderChange(cursortingOrder)
    for i, v in pairs(self.ItemList) do
        for j = 1, #self.ItemList[i] do
            self.ItemList[i][j]:SetEffectLayer(cursortingOrder)
        end
    end
end

--设置投资按钮初始状态
function GrowthGiftPage:SetBtnInvestState()
    local packageInfo = OperatingManager.IsGrowthGiftGoodsAvailable(GoodsTypeDef.GrowthReward)--packageInfo:当前成长基金礼包ID（ID：101、102、103、104、105）
    if packageInfo and packageInfo.buyTimes == 0 then
        self.btnInvest:GetComponent("Button").enabled = true
        self.btnInvestText.text =MoneyUtil.GetMoney(G_RechargeCommodityConfig[packageInfo.goodsId].Price)
        Util.SetGray(self.btnInvest, false)
        curGiftsId = packageInfo.goodsId
    else
        self.btnInvest:GetComponent("Button").enabled = false
        self.btnInvestText.text = GetLanguageStrById(10526)
        Util.SetGray(self.btnInvest, true)
        curGiftsId = OperatingManager.GetHadBuyGoodsTypeId(GoodsTypeDef.GrowthReward)
    end
end
--点击进行投资购买礼包
function GrowthGiftPage:OnBtnInvestClicked()
    local status = OperatingManager.IsRechargeable(GoodsTypeDef.GrowthReward)
    if not status then
        self.btnInvest:GetComponent("Button").enabled = false
        Util.SetGray(self.btnInvest, true)
        return
    end
    self.btnInvest:GetComponent("Button").enabled = true
    Util.SetGray(self.btnInvest, false)
    self:RequestBuy()
end
function GrowthGiftPage:RequestBuy()
    local giftGoodsInfo = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.GrowthReward, curGiftsId)
    if AppConst.isSDKLogin then
        PayManager.Pay({Id = giftGoodsInfo.goodsId},function(respond)
            -- PopupTipPanel.ShowTip("奖励已发送到邮件,请前往领取")
            -- FirstRechargeManager.RefreshAccumRechargeValue( giftGoodsInfo.goodsId)
            -- lastGiftId = curGiftsId
            self:RefreshStatus()
        end)
    else
        NetManager.RequestBuyGiftGoods(giftGoodsInfo.goodsId,function(respond)
            -- PopupTipPanel.ShowTip("奖励已发送到邮件,请前往领取")
            -- FirstRechargeManager.RefreshAccumRechargeValue( giftGoodsInfo.goodsId)
            -- lastGiftId = curGiftsId
            self:RefreshStatus()
        end)
    end
end

function GrowthGiftPage:RefreshStatus()
    local giftGoodsInfo = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.GrowthReward, curGiftsId)
    -- 设置活动开启状态
    ActivityGiftManager.SetActivityOpenStatus(ActivityTypeDef.GrowthReward)
    -- 添加已经购买的物品
    OperatingManager.SetHadBuyGoodsId({curGiftsId})
    -- 增加充值金额
    FirstRechargeManager.RefreshAccumRechargeValue(curGiftsId)
    -- 检测红点状态
    CheckRedPointStatus(RedPointType.GrowthGift)
    -- 从可购买物品列表中删除
    OperatingManager.RemoveItemInfoByType(GoodsTypeDef.GrowthReward, curGiftsId)
    -- 刷新当前界面显示
    self:RefreshData()
end

--刷新每日免费礼包
function GrowthGiftPage:RefreshFreeData()
    local freeData = ShopManager.GetShopDataByType(SHOP_TYPE.GROWTHFREE_GIFT).storeItem
    local boughtNum = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.GROWTHFREE_GIFT, freeData[1].id)
    local limitNum = ShopManager.GetShopItemLimitBuyCount(freeData[1].id)
    local isCanBuy = limitNum - boughtNum >= 1
    local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.GROWTHFREE_GIFT, freeData[1].id, 1)

    self.redPoint:SetActive(isCanBuy)
    self.received:SetActive(not isCanBuy)
    if isCanBuy then
        self.freeBtn:GetComponent("Image").color = Color.New(255/255,255/255,255/255,255/255)
    else
        self.freeBtn:GetComponent("Image").color = Color.New(255/255,255/255,255/255,127/255)
    end

    Util.AddOnceClick(self.freeBtn,function()
        if isCanBuy then
            local haveNum = BagManager.GetItemCountById(costId)
            if haveNum < finalNum then
                NotEnoughPopup:Show(costId)
            else
                ShopManager.RequestBuyShopItem(SHOP_TYPE.GROWTHFREE_GIFT, freeData[1].id, 1, function()
                    self:RefreshFreeData()
                    CheckRedPointStatus(RedPointType.GrowthGift)
                end)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(23106)
        end
    end)
end

return GrowthGiftPage