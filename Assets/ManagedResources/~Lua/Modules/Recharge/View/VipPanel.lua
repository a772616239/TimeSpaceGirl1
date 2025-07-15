--[[
 * @ClassName OperatingPanel
 * @Description 等级特权面板
 * @Date 2019/5/27 11:14
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]

---@class VipPanel
--local VipPanel = quick_class("VipPanel", BasePanel)
local VipPanel = quick_class("VipPanel")
local this = VipPanel
local orginLayer
local maxVipLevel = 15
local curChooseLevel = 0
this.levelBtnList = {}
this.btnRedPointList = {}
-- 当前选中的礼包内容
local giftData = {}
-- 避免多次点击按钮
local btnBg = {
    [1] = "N1_btn_tanke_weixuanzhong", -- 未激活， 已领取
    [2] = "N1_btn_tanke_xuanzhong", -- 领取
}

-- 按钮选中的颜色
local btnColor = {
    [1] = {nameColor = "#e0e0a0", descColor = "#e0e0a0", img = "cn2-x1_haoyou_biaoqian_xuanzhong"}, -- 未选中
    [2] = {nameColor = "#e0e0a0", descColor = "#e0e0a0", img = "cn2-x1_haoyou_biaoqian_xuanzhong"},  -- 选中
}

-- 上一个选择的按钮
local lastChoose = 0

local vipLevelConfig = ConfigManager.GetConfig(ConfigName.VipLevelConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

function VipPanel:ctor(mainPanel, gameObject)
    this.mainPanel = mainPanel
    this.gameObject = gameObject
    this:InitComponent(gameObject)
    this:BindEvent()
    this.ItemList = {}
end

function VipPanel:InitComponent(gameObject)
    this.gameObject = gameObject
    orginLayer = 0
    maxVipLevel = VipManager.GetMaxVipLevel()
    this.vipLevel = VipManager.GetVipLevel()

    --this.bg = Util.GetGameObject(this.transform, "bg")
    --if Screen.width / Screen.height < 1080 / 1920 then
    --    screenAdapte(this.bg)
    --end

    --this.BtnBack = Util.GetGameObject(this.transform, "btnBack")
    this.helpBtn = Util.GetGameObject(this.gameObject, "helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition
    this.effect = Util.GetGameObject(this.gameObject, "UI_Effect_VipPanel")

    --effectAdapte(this.effect)

    -- 充值信息
    this.chargeTip = Util.GetGameObject(this.gameObject, "VipInfoPart/textGrid")
    this.moneyNeed = Util.GetGameObject(this.gameObject, "VipInfoPart/textGrid/num"):GetComponent("Text")
    this.vipNextLevel = Util.GetGameObject(this.gameObject, "VipInfoPart/textGrid/end")
    
    --this.moneyIcon = Util.GetGameObject(this.gameObject, "VipInfoPart/textGrid/icon/Image"):GetComponent("Image")
    -- this.rewardInfo = Util.GetGameObject(this.gameObject, "VipInfoPart/reward/Text"):GetComponent("Image")
    this.vipCurLevel = Util.GetGameObject(this.gameObject, "VipInfoPart/vipIcon/num")

    -- 充值进度信息
    this.progressValue = Util.GetGameObject(this.gameObject, "VipInfoPart/Slider/fill"):GetComponent("Image")
    this.progressText = Util.GetGameObject(this.gameObject, "VipInfoPart/Slider/value"):GetComponent("Text")

    -- 购买月卡
    this.monthRewardList = {}
    this.monthRewardGrid = Util.GetGameObject(this.gameObject, "dailyGiftBg/dailyGift/grid")
    this.dailyReward = {}
    for i = 1, 2 do
        this.dailyReward[i] = SubUIManager.Open(SubUIConfig.ItemView, this.monthRewardGrid.transform)
        this.dailyReward[i].gameObject:SetActive(false)
    end
    this.btnGetReward = Util.GetGameObject(this.gameObject, "dailyGiftBg/dailyGift/btnGet")
    this.btnText = Util.GetGameObject(this.btnGetReward, "Text"):GetComponent("Text")
    -- 领取按钮红点
    this.redReward = Util.GetGameObject(this.btnGetReward, "redPoint")

    --midPart
    this.privilegeRoot = Util.GetGameObject(this.gameObject, "privilegeRootBg/privilegeRoot")
    this.moneyNeedTotal = Util.GetGameObject(this.privilegeRoot, "chargeTip/num"):GetComponent("Text")
    --this.moneyIconTotal = Util.GetGameObject(this.privilegeRoot, "chargeTip/icon/Image"):GetComponent("Image")
    --this.btnMidPart = Util.GetGameObject(this.gameObject, "frame/midPart")

    -- 增益描述
    this.privilegeTitle = Util.GetGameObject(this.privilegeRoot, "imgTitle/title"):GetComponent("Text")
    this.privilegeContent = Util.GetGameObject(this.privilegeRoot, "privilegeList/viewPort/content")
    this.privilegeItem = Util.GetGameObject(this.privilegeContent, "itemPro")
    this.privilegeItem.gameObject:SetActive(false)
    this.privilegeList = {}

    -- 当前等级的特权礼包
    this.giftGrid = Util.GetGameObject(this.gameObject, "gfitContentBg/gfitContent/Scroll/grid")
    this.gameObj = Util.GetGameObject(this.gameObject, "gfitContentBg/gfitContent/Scroll/frame")
    this.vipGfitList = {}
    -- 缓存6项
    for i = 1, 6 do
        local f = newObjToParent(this.gameObj,this.giftGrid.transform)
        this.vipGfitList[i] = SubUIManager.Open(SubUIConfig.ItemView, f.transform)
        this.vipGfitList[i].gameObject:SetActive(false)
        f.gameObject:SetActive(false)
    end

    this.gfitContent = Util.GetGameObject(this.gameObject, "gfitContentBg")
    this.giftText = Util.GetGameObject(this.gfitContent, "gfitContent/orginPrice/price"):GetComponent("Text")
    this.giftIcon = Util.GetGameObject(this.gfitContent, "gfitContent/orginPrice/icon"):GetComponent("Image")
    this.discountLine = Util.GetGameObject(this.gfitContent, "gfitContent/orginPrice/line")
    this.btnGiftBuy = Util.GetGameObject(this.gfitContent, "gfitContent/btnBuy")
    this.btnGiftBuyRedpot = Util.GetGameObject(this.gfitContent, "gfitContent/btnBuy/Redpot")
    this.buyIcon = Util.GetGameObject(this.gfitContent, "gfitContent/icon"):GetComponent("Image")
    this.buyText = Util.GetGameObject(this.gfitContent, "gfitContent/Text"):GetComponent("Text")

    -- 那一排的滑动按钮
    this.isExceedTen = false
    this.btnGrid = Util.GetGameObject(this.gameObject, "btnScrollBg/btnScroll/grid")
    this.btnPre = Util.GetGameObject(this.gameObject, "btnScrollBg/btnScroll/btnVipInfo")
    if this.vipLevel < 10 then
        maxVipLevel = 10
    else
        if this.vipLevel <= VipManager.GetMaxVipLevel() - 2 then
            maxVipLevel = this.vipLevel + 2
        else
            maxVipLevel = VipManager.GetMaxVipLevel()
        end
        this.isExceedTen = true
    end
    for i = 1, maxVipLevel + 1 do
        this.levelBtnList[i] = newObjToParent(this.btnPre, this.btnGrid)
        this.btnRedPointList[i] = Util.GetGameObject(this.levelBtnList[i], "redPoint")
    end
end

function VipPanel:BindEvent()
    ----帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.VIP, this.helpPosition.x,this.helpPosition.y)
    end)
    for i = 1, maxVipLevel + 1 do
        Util.AddClick(this.levelBtnList[i], function ()
            this:RefreshPanelStatus(i - 1)
            -- 刷新按钮红点状态
            if VipManager.GetBuyBtnRedState(i - 1) == 0 and this.vipLevel >= i - 1 then
                VipManager.SetBuyBtnRed(i - 1, 1)
                CheckRedPointStatus(RedPointType.VIP_SHOP_DETAIL)
                CheckRedPointStatus(RedPointType.VipPrivilege)
            end
            this:SetBtnRedState(i - 1)
        end)
    end
    Util.AddClick(this.btnGetReward, function ()
        this:BtnRewardClick()
    end)

    Util.AddClick(this.btnGiftBuy, function ()
        this:BuyVipGift()
        CheckRedPointStatus(RedPointType.GrowthPackage)
    end)

end

function VipPanel:OnShow(_sortingOrder, buyType)
    NetManager.RequestVipLevelUp(function()end)--提升等级

    this.chargedNum = VipManager.GetChargedNum()
    this.vipLevel = VipManager.GetVipLevel()

    if this.btnGrid.transform.childCount - 1 < this.vipLevel + 2 and this.vipLevel <= VipManager.GetMaxVipLevel() - 2 then
        this.isExceedTen = false
    end

    if this.vipLevel >= 10 and this.isExceedTen == false then
        if this.vipLevel <= VipManager.GetMaxVipLevel() - 2 then
            maxVipLevel = this.vipLevel + 2
        else
            maxVipLevel = VipManager.GetMaxVipLevel()
        end

        local num = #this.levelBtnList + 1
        for i = num, maxVipLevel + 1 do
            this.levelBtnList[i] = newObjToParent(this.btnPre, this.btnGrid)
            this.btnRedPointList[i] = Util.GetGameObject(this.levelBtnList[i], "redPoint")

            Util.AddOnceClick(this.levelBtnList[i], function ()
                this:RefreshPanelStatus(i - 1)
                -- 刷新按钮红点状态
                if VipManager.GetBuyBtnRedState(i - 1) == 0 and this.vipLevel >= i - 1 then
                    VipManager.SetBuyBtnRed(i - 1, 1)
                    CheckRedPointStatus(RedPointType.VIP_SHOP_DETAIL)
                    CheckRedPointStatus(RedPointType.VipPrivilege)
                end
                this:SetBtnRedState(i - 1)
            end)
        end
        this.isExceedTen = true
    end

    this.nextLevel = this.vipLevel + 1
    this.nextLevel = this.nextLevel > maxVipLevel and maxVipLevel or this.nextLevel

    -- 设置充值信息
    this:SetChargeInfo()
     --豪华礼包奖励信息
     this:MonthGift()
    -- 滑动的特权按钮
    this:SetBtnListState()
    this:InitAllRedBtn()
    -- 设置增益描述
    lastChoose = this.vipLevel
    this:RefreshPanelStatus(this.vipLevel)
end

-- 刷新系统界面
function VipPanel:RefreshPanelStatus(curLevel)
    for i = 1, #this.levelBtnList do
        this.levelBtnList[i]:GetComponent("Image").sprite = Util.LoadSprite(btnColor[1].img)
        -- Util.GetGameObject(this.levelBtnList[i], "info"):GetComponent("Text").text = GetLanguageStrById(vipLevelConfig[curChooseLevel].Name)
        Util.GetGameObject(this.levelBtnList[i], "level"):SetActive(true)
        Util.GetGameObject(this.levelBtnList[i], "selet"):SetActive(false)
        this.levelBtnList[i]:GetComponent("Image").enabled = false
    end

    curChooseLevel = curLevel
    lastChoose = curChooseLevel

    local bg = this.levelBtnList[curChooseLevel + 1]:GetComponent("Image")
    local desc = Util.GetGameObject(this.levelBtnList[curChooseLevel + 1], "info"):GetComponent("Text")
    bg.sprite = Util.LoadSprite(btnColor[2].img)

    if Util.GetGameObject(this.levelBtnList[curChooseLevel + 1], "selet"):GetComponent("Text").text ~=
        Util.GetGameObject(this.levelBtnList[curChooseLevel + 1], "level"):GetComponent("Text").text then
        Util.GetGameObject(this.levelBtnList[curChooseLevel + 1], "selet"):GetComponent("Text").text =
            Util.GetGameObject(this.levelBtnList[curChooseLevel + 1], "level"):GetComponent("Text").text
    end

    this.levelBtnList[curChooseLevel + 1]:GetComponent("Image").enabled = true
    Util.GetGameObject(this.levelBtnList[curChooseLevel + 1], "level"):SetActive(false)
    Util.GetGameObject(this.levelBtnList[curChooseLevel + 1], "selet"):SetActive(true)

    desc.text = string.format("<color=%s>%s</color>", btnColor[2].descColor,GetLanguageStrById(vipLevelConfig[curChooseLevel].Name))
    this.privilegeTitle.text = string.format(GetLanguageStrById(12010), curLevel)
    this.moneyNeedTotal.text = VipManager.CurLevelMoneyNeed(curLevel)

    local VipLvConfig = vipLevelConfig[curLevel]
    assert(VipLvConfig, string.format("ConfigName.VipLevelConfig not find VipLevel:%s", curLevel))
    this:SetVipPrivileges(curLevel)
    -- 刷新礼包内容
    this:RefreshVipGift(curLevel)
end

-- 初始化刷新所有按钮红点状态
function VipPanel:InitAllRedBtn()
    for i = 1, maxVipLevel + 1 do
        VipPanel:SetBtnRedState(i - 1)
    end
end

function VipPanel:SetBtnRedState(level)
    local isShow = VipManager.GetBtnListRed(level)
    this.btnRedPointList[level + 1]:SetActive(isShow)

    if level == 0 and VipManager.RefreshEveryDayGiftRedpoint() then
        this.btnRedPointList[level + 1]:SetActive(true)
    end
end

----------------------------- 特权信息显示 --------------------------------------
function VipPanel:SetChargeInfo()
    local need, nextLevelNeed = VipManager.GetNextLevelNeed()
    --显示钻石数量
    this.moneyNeed.text = need * 10----TODO汇率计算

    this.vipNextLevel:GetComponent("Text").text = this.nextLevel
    this.vipCurLevel:GetComponent("Text").text = this.vipLevel

    this.progressValue.fillAmount = this.chargedNum / nextLevelNeed
    this.progressText.text = this.chargedNum * 10 .. "/" .. nextLevelNeed * 10

    this:RefreshBtnState()
end

function VipPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Vip.OnVipDailyRewardStatusChanged, this.OnVipDailyRewardStatusChanged, this)
    Game.GlobalEvent:AddEvent(GameEvent.Vip.OnVipRankChanged, this.OnVipDailyRewardStatusChanged, this)
end

function VipPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Vip.OnVipDailyRewardStatusChanged, this.OnVipDailyRewardStatusChanged, this)
    Game.GlobalEvent:RemoveEvent(GameEvent.Vip.OnVipRankChanged, this.OnVipDailyRewardStatusChanged, this)
end

-- 点击领取按钮
function VipPanel:BtnRewardClick()
    -- 豪华月卡的激活状态
    local isActive = OperatingManager.GetMonthCardIsOpen(MONTH_CARD_TYPE.LUXURYMONTHCARD)--VipManager.GetMonthCardOpenState()
    local getState = VipManager.GetRewardState()
    if not isActive then
        JumpManager.GoJump(36005)
    else
        if getState < 1 then
            -- 发送领取请求
            NetManager.GetVipDailyReward(function(respond)
                VipManager.SetRewardVipLevel(this.vipLevel)
                UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1, function ()
                    this:RefreshBtnState()
                    CheckRedPointStatus(RedPointType.VIP_SHOP_DETAIL)
                    CheckRedPointStatus(RedPointType.VipPrivilege)
                    CheckRedPointStatus(RedPointType.VipPanel)
                end)
            end)
        else
            -- 设置为不可领取
            PopupTipPanel.ShowTipByLanguageId(12011)
        end
    end
end

-- 设置领取按钮显示状态
function VipPanel:RefreshBtnState()
    local isActive = OperatingManager.GetMonthCardIsOpen(MONTH_CARD_TYPE.LUXURYMONTHCARD)--VipManager.GetMonthCardOpenState()

    local getState = VipManager.GetRewardState()
    local str = ""
    if not isActive then
        str = GetLanguageStrById(10543)

    else
        if getState < 1 then
            str = GetLanguageStrById(12012)
            Util.SetGray(this.btnGetReward, false)
        else
            str = GetLanguageStrById(10350)
            Util.SetGray(this.btnGetReward, true)
        end
    end

    -- 设置红点
    this.redReward:SetActive(isActive and getState < 1)
    this.btnText.text = str
end

-- 5点刷新数据
function VipPanel:OnVipDailyRewardStatusChanged()
    this:RefreshBtnState()
    this:MonthGift()
    this:InitAllRedBtn()
end

----------------------------- 豪华月卡每日礼包显示 --------------------------------
function VipPanel:MonthGift()
    local level = 0
    local getState = VipManager.GetRewardState()
    local isLevelUp = this:IsLevelUped()

    if isLevelUp and getState > 0 then  -- 升级过又领取了奖励
        level = VipManager.GetRewardVipLevel()
    else
        level = VipManager.GetVipLevel()
    end

    local rewardData = vipLevelConfig[level].VipBoxDailyReward
    if not rewardData then
        return
    end
    for i = 1, 2 do
        this.dailyReward[i].gameObject:SetActive(i <= #rewardData)
        if rewardData[i] then
            this.dailyReward[i]:OnOpen(false, {rewardData[i][1],rewardData[i][2]}, 0.75)
            Util.GetGameObject(this.dailyReward[i].transform,"item/num"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,153/255)
        end
    end
end

function VipPanel:SetBtnListState()
    for i = 1, maxVipLevel + 1 do
        local btn = this.levelBtnList[i]
        -- btn:GetComponent("Image").enabled = false
        Util.GetGameObject(btn, "level"):GetComponent("Text").text = GetLanguageStrById(12009) .. i - 1
        --Util.GetGameObject(btn, "info"):GetComponent("Text").text = VipManager.GetFirstNameByLevel(i - 1)
        Util.GetGameObject(btn, "info"):GetComponent("Text").text = GetLanguageStrById(vipLevelConfig[i - 1].Name)

        this.levelBtnList[i].gameObject.name = GetLanguageStrById(12009) .. i - 1
    end
end

-------------------------------  特权增益  --------------------------------------
--特权增益描述
function VipPanel:SetVipPrivileges(curVipLevel)
    if this.priThread then
        coroutine.stop(this.priThread)
        this.priThread = nil
    end
    table.walk(this.privilegeList, function(privilegeItem)
        privilegeItem:SetActive(false)
    end)

    local curVipData = PrivilegeManager.GetTipsByVipLv(curVipLevel)
    local tempNumber = 0
    this.priThread = coroutine.start(function()
        for _, privilegeInfo in ipairs(curVipData) do
            if privilegeInfo.value == "" or privilegeInfo.value > 0 then
                tempNumber = tempNumber + 1
                local item = this:GetPrivilegeItem(tempNumber)
                item:SetActive(false)
                -- local str = "<size=45><color=#7bb15bFF> </color></size>"
                -- str = string.format("<size=45><color=#7bb15bFF>%s</color></size>", privilegeInfo.value)
                if privilegeInfo.IfFloat == 2 then --特权关卡挂机加成百分比
                    Util.GetGameObject(item, "title"):GetComponent("Text").text = string.format(GetLanguageStrById(privilegeInfo.content),(privilegeInfo.value).."%")
                else
                    Util.GetGameObject(item, "title"):GetComponent("Text").text = string.format(GetLanguageStrById(privilegeInfo.content),privilegeInfo.value)
                end
                -- if privilegeInfo.id == 1 then --特权关卡挂机加成百分比
                --     Util.GetGameObject(item, "title"):GetComponent("Text").text = string.format(privilegeInfo.content,(privilegeInfo.value).."%")
                -- else
                --     Util.GetGameObject(item, "title"):GetComponent("Text").text = string.format(privilegeInfo.content,privilegeInfo.value)
                -- end

                PlayUIAnim(Util.GetGameObject(item, "content"))
                coroutine.wait(0.03)
                if privilegeInfo.value == 0 then
                    item:SetActive(false)
                else
                    item:SetActive(true)
                end
            end
        end
    end)
end

function VipPanel:GetPrivilegeItem(index)
    if this.privilegeList[index] then
        return this.privilegeList[index]
    else
        local newItem = newObjToParent(this.privilegeItem, this.privilegeContent)
        table.insert(this.privilegeList, newItem)
        return newItem
    end
end

local curGoodData
-----------------------------------------------------------------------
--------------------------特权礼包购买 ----------------------------------
function VipPanel:RefreshVipGift(curLevel)
    local shopData = VipManager.vipShopData[curLevel + 1]
    if not shopData then
        return
    end

    curGoodData = shopData.Goods

    for i = 1, 6 do
        this.vipGfitList[i].gameObject:SetActive(i <= #curGoodData)
        this.vipGfitList[i].transform.parent.gameObject:SetActive(i <= #curGoodData)

        if curGoodData[i] then
            this.vipGfitList[i]:OnOpen(false, {curGoodData[i][1],curGoodData[i][2]}, 0.8)
            Util.GetGameObject(this.vipGfitList[i].transform,"item/num"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,153/255)
        end
    end

    giftData = {}
    -- 设置购买按钮状态
    local itemId = shopData.Id
    local costId, finalCost, orignalCost = ShopManager.calculateBuyCost(SHOP_TYPE.VIP_GIFT, itemId, 1)
    this.giftText.text = orignalCost
    this.giftIcon.sprite = SetIcon(costId)
    this.buyIcon.sprite = SetIcon(costId)
    giftData.shopType = SHOP_TYPE.VIP_GIFT
    giftData.shopItemId = itemId
    giftData.num = 1
    giftData.costId = costId
    giftData.costNum = finalCost

    VipPanel:FreshBuyBtnState(giftData.costNum)
end

--购买礼包处理
function VipPanel:BuyVipGift()
    if curChooseLevel > this.vipLevel then
        PopupTipPanel.ShowTip(GetLanguageStrById(12019) .. curChooseLevel .. GetLanguageStrById(12020))
        return
    end

    -- 商品的剩余购买次数
    local leftNum = ShopManager.GetShopItemRemainBuyTimes(giftData.shopType, giftData.shopItemId)
    if leftNum < 1 and leftNum ~= -1 then
        PopupTipPanel.ShowTipByLanguageId(12021)
        return
    end

    local haveNum = BagManager.GetItemCountById(giftData.costId)
    if haveNum < giftData.costNum then
        --UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.DemonCrystal })
        PopupTipPanel.ShowTipByLanguageId(10854)
        return
    end

    --判断是否含有英雄
    local shopItemNum
    for i, v in ipairs(curGoodData) do
        if itemConfig[v[1]].ItemType == 1 then
            shopItemNum = v[2]
        end
    end

    if shopItemNum then
        --判断英雄是否满
        NetManager.BackpackLimitRequest(function(msg)
            local heroNum = #HeroManager.GetAllHeroDatasAndZero()
            local limit = msg.backpackLimitCount
            if heroNum + shopItemNum <= limit then
                ShopManager.RequestBuyShopItem(giftData.shopType, giftData.shopItemId, 1, function ()
                    VipPanel:FreshBuyBtnState(giftData.costNum)
                    CheckRedPointStatus(RedPointType.GrowthPackage)
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(10671)
            end
        end)
    else
        ShopManager.RequestBuyShopItem(giftData.shopType, giftData.shopItemId, 1, function ()
            VipPanel:FreshBuyBtnState(giftData.costNum)
            CheckRedPointStatus(RedPointType.GrowthPackage)
        end)
    end
end

-- 刷新购买按钮显示状态
function VipPanel:FreshBuyBtnState(costNum)
    -- 检测剩余购买次数
    local leftNum = ShopManager.GetShopItemRemainBuyTimes(giftData.shopType, giftData.shopItemId)
    local canBuy = false
    if leftNum < 1 and leftNum ~= -1 then
        this.buyText.text = GetLanguageStrById(12022)
        canBuy = false
        Util.SetGray(this.btnGiftBuy, true)
    else
        this.buyText.text = costNum
        canBuy = true
        Util.SetGray(this.btnGiftBuy, false)
    end
    -- this.btnGiftBuyRedpot:SetActive(canBuy and this.vipLevel >= curChooseLevel and BagManager.GetItemCountById(giftData.costId) >= giftData.costNum)
    this.btnGiftBuyRedpot:SetActive(canBuy and this.vipLevel >= curChooseLevel and costNum == 0)
end

-- 判断出去面板后，是否升过级
function VipPanel:IsLevelUped()
    local isUp = false
    -- 今日领取奖励时的等级
    local rewardLevel = VipManager.GetRewardVipLevel()
    if rewardLevel > 0 and rewardLevel ~= this.vipLevel then
        isUp = true
    else
        isUp = false
    end

    return isUp
end

--------------------------------------------------------------------

--跳转显示新手提示圈
function VipPanel:ShowGuideGo()
    JumpManager.ShowGuide(UIName.VipPanel, this.taskItemList[1].dealBtn)
end

function VipPanel:OnHide()
    if this.priThread then
        coroutine.stop(this.priThread)
        this.priThread = nil
    end

    if this.taskThread then
        coroutine.stop(this.taskThread)
        this.taskThread = nil
    end

    -- 目前的选择
    if LengthOfTable(this.levelBtnList) > 0 then
        local bg = this.levelBtnList[curChooseLevel + 1]:GetComponent("Image")
        -- local name = Util.GetGameObject(this.levelBtnList[curChooseLevel + 1], "level"):GetComponent("Text")
        local desc = Util.GetGameObject(this.levelBtnList[curChooseLevel + 1], "info"):GetComponent("Text")
        bg.sprite = Util.LoadSprite(btnColor[1].img)
        -- local namaText = GetLanguageStrById(12009) .. curChooseLevel + 1
        -- local descTex = VipManager.GetFirstNameByLevel(curChooseLevel)
        -- name.text = string.format("<color=%s>%s</color>", btnColor[1].nameColor, namaText)

        --desc.text = string.format("<color=%s>%s</color>", btnColor[1].descColor, descTex)
        if vipLevelConfig[curChooseLevel].Name ~= "null" then
            desc.text = GetLanguageStrById(vipLevelConfig[curChooseLevel].Name)
        else
            desc.text = vipLevelConfig[curChooseLevel].Name
        end
    end
end

function VipPanel:OnDestroy()
    --SubUIManager.Close(this.UpView)
end

return VipPanel