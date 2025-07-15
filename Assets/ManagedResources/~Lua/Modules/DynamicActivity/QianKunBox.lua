local QianKunBox = quick_class("QianKunBox")
local this = QianKunBox
local ActivityDetail = require("Modules/DynamicActivity/ActivityDetail")--活动详情
local parent 
local iconsData = nil
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local artConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local privilegeConfig = ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local lotterySpecialConfig = ConfigManager.GetConfig(ConfigName.LotterySpecialConfig)
local orginLayer = 0

local activityId = 0 
local singleRecruit = nil
local tenRecruit = nil

local bType = {
    Btn1 = 1,
    Btn10 = 2
}
--type与lotterySetting表中的id对应
local btns = {
    [bType.Btn1] = {name = "btnOne",isInfo = GetLanguageStrById(10644),type = RecruitType.QianKunBoxSingle},
    [bType.Btn10] = {name = "btnTen",isInfo = GetLanguageStrById(12182),type = RecruitType.QianKunBoxTen}
}

function QianKunBox:ctor(mainPanel, gameObject)
    this.mainPanel = mainPanel.transform
    this.gameObject = gameObject
    this:InitComponent(gameObject)
    this:BindEvent()
end

function QianKunBox:InitComponent(gameObject)

    this.tabList = Util.GetGameObject(this.mainPanel,"bg/tabbox")
    this.btnBack = Util.GetGameObject(this.mainPanel,"bg/btnBack")
    -- this.bottomBar = Util.GetGameObject(this.mainPanel,"bg/bottomBar")
    --midDown
    this.midDown = Util.GetGameObject(gameObject,"midDown")
    this.midDowntips1 = Util.GetGameObject(this.midDown,"tips/tips1"):GetComponent("Text")
    this.leftUptips1 = Util.GetGameObject(this.midDown,"tips/tips1/times"):GetComponent("Text")
    this.leftUpTime = Util.GetGameObject(this.midDown,"tips/time/timeText"):GetComponent("Text")
    this.btnHelp = Util.GetGameObject(gameObject,"btnHelp")
    this.helpPosition = this.btnHelp:GetComponent("RectTransform").localPosition
    --rightUp
    this.rightUp = Util.GetGameObject(gameObject,"rightUp")
    this.btnReward = Util.GetGameObject(this.rightUp,"reward")
    this.btnStore = Util.GetGameObject(this.rightUp,"store")
    --center
    this.center = Util.GetGameObject(gameObject,"center")
    this.icons = Util.GetGameObject(this.center,"icons")
    --bottom
    this.bottom = Util.GetGameObject(gameObject,"bottom")
    -- this.btnOne = Util.GetGameObject(this.bottom,"btnOne")
    this.di1 = Util.GetGameObject(this.bottom,"countDown/di1")
    this.btnTime = Util.GetGameObject(this.bottom,"countDown/di1/time"):GetComponent("Text")
    -- this.btnTen1 = Util.GetGameObject(this.bottom,"btnTen1")
    -- this.btnTen2 = Util.GetGameObject(this.bottom,"btnTen2")
    -- this.btnTimes= Util.GetGameObject(this.bottom,"countDown/di2/time"):GetComponent("Text")
    --limit
    this.limit = Util.GetGameObject(gameObject,"limitdi/limit"):GetComponent("Text")
    --detail
    this.detail = Util.GetGameObject(gameObject,"detail")
    --shop
    this.shop = Util.GetGameObject(gameObject,"shop")
    this.shopBack = Util.GetGameObject(this.shop,"shopBack/btnBack")
    this.content = Util.GetGameObject(this.shop,"content")
    this.livename = nil
    this.live = Util.GetGameObject(this.shop,"live")
    -- this.effect = Util.GetGameObject(this.gameObject, "Effect_UI_changjing_qiankuanbaoguo")
end

function QianKunBox:BindEvent()
    Util.AddClick(this.btnHelp,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.QianKunBox,this.helpPosition.x,this.helpPosition.y)
    end)
    Util.AddClick(this.btnReward,function()
        -- this.effect:SetActive(false)
        ActivityDetail.new(this.detail,2,this.effect, this.sortingOrder)
    end)
    Util.AddClick(this.btnStore,function()
        -- this.effect:SetActive(false)
        this.shop:SetActive(true)
        this.btnBack:SetActive(false)
        this.tabList:SetActive(false)
        -- this.bottomBar:SetActive(false)
        local ScrollCycleView = Util.GetGameObject(this.content,"ShopView/scrollbg/scrollroot").transform:GetChild(5)
        for i = 1, Util.GetGameObject(ScrollCycleView,"grid").transform.childCount do
            Util.GetGameObject(ScrollCycleView,"grid").transform:GetChild(i-1).gameObject:SetActive(false)
        end
        this:storeShow()--商店
        if this.UpView == nil then
            this.UpView = SubUIManager.Open(SubUIConfig.UpView, this.shop.transform, { showType = UpViewOpenType.ShowLeft})
            this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.ShenMiMangHe})
        end
        
    end)
    Util.AddClick(this.shopBack,function()
        -- this.effect:SetActive(true)
        this.shop:SetActive(false)
        -- this.UpView:SetActive(false)
        this.btnBack:SetActive(true)
        this.tabList:SetActive(true)
        -- this.bottomBar:SetActive(true)
        poolManager:UnLoadLive(this.livename, this.liveNode)
        this.livename = nil
        local ScrollCycleView = Util.GetGameObject(this.content,"ShopView/scrollbg/scrollroot").transform:GetChild(5)
        for i = 1, Util.GetGameObject(ScrollCycleView,"grid").transform.childCount do
            Util.GetGameObject(ScrollCycleView,"grid").transform:GetChild(i-1).gameObject:SetActive(false)
        end
    end)
end

function QianKunBox:OnShow(sortingOrder,_parent)
    parent = _parent
    Util.AddParticleSortLayer(this.effect, sortingOrder - orginLayer)  
    orginLayer = sortingOrder
    activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.QianKunBox)  
    local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",activityId)
    singleRecruit = array[1]
    tenRecruit = array[2]
    iconsData = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotteryRewardConfig,"Pool",singleRecruit.DiamondBoxContain[1][1])
    this.gameObject:SetActive(true)
    -- this:refreshMagicNum()
    this:refreshBtnShow()--刷新按钮显示
    -- this:contentShow()--五个魂印头像
    this:storeShow()--商店
    this:timeCountDown()--时间

    this.sortingOrder = sortingOrder

    this.shopcanvas = this.shop:GetComponent("Canvas")
    if this.shopcanvas and this.sortingOrder then
        this.shopcanvas.sortingOrder = this.sortingOrder + 1
    end
end
local isFree
function QianKunBox:refreshBtnShow()
    local freeTimesId = lotterySetting[singleRecruit.Id].FreeTimes
    local maxtimesId = lotterySetting[singleRecruit.Id].MaxTimes  --lotterySetting表中的MaxTimes对应privilegeConfig表中的id       
    local curTimes = PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)

    local freeTime = 0

    this.limit.text = GetLanguageStrById(12225)..curTimes.."/"..privilegeConfig[maxtimesId].Condition[1][2]

    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        RecruitManager.freeUseTimeList[freeTimesId] = freeTime
    end

    --按钮赋值
    for n, m in ipairs(btns) do
        local btn = Util.GetGameObject(this.bottom,m.name)
        local redPoint = Util.GetGameObject(btn.gameObject,"redPoint")
        local info = Util.GetGameObject(btn.gameObject,"layout/info"):GetComponent("Text")
        local icon = Util.GetGameObject(btn.gameObject,"layout/icon"):GetComponent("Image")
        local num = Util.GetGameObject(btn.gameObject,"layout/num"):GetComponent("Text")

        local type
        --存在免费次数和免费次数>=1
        isFree = freeTime and freeTime >= 1
        Util.GetGameObject(btn.gameObject,"Text"):SetActive(true)
        if n == bType.Btn1 then
            type = singleRecruit.Id
            if isFree then
                info.text = GetLanguageStrById(11759)
                this.di1:SetActive(false)
                Util.GetGameObject(btn.gameObject,"free"):SetActive(true)
                Util.GetGameObject(btn.gameObject,"Text"):SetActive(false)
                icon.gameObject:SetActive(not isFree)
                num.gameObject:SetActive(not isFree)
                redPoint.gameObject:SetActive(isFree)
            else
                this.di1:SetActive(true)
                Util.GetGameObject(btn.gameObject,"free"):SetActive(false)
            end
        else
            type = tenRecruit.Id
        end
        local item,v1 = RecruitManager.GetExpendData(type)

        icon.sprite = Util.LoadSprite(artResourcesConfig[itemConfig[item[1]].ResourceID].Name)
        info.text = m.isInfo
        num.text = tostring(item[2])

        Util.AddOnceClick(btn,function()
            local state = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..tenRecruit.Id)
            if n == bType.Btn1 then
                if not isFree then
                    if BagManager.GetItemCountById(item[1]) < item[2] then
                        PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[item[1]].Name)..GetLanguageStrById(10492))
                        return
                    end
                end
                if PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)+1>privilegeConfig[maxtimesId].Condition[1][2] then
                    PopupTipPanel.ShowTip(GetLanguageStrById(11760))
                    return
                end
                local recruitOne = function()
                    RecruitManager.RecruitRequest(singleRecruit.Id, function(msg)
                        if isFree then
                            PrivilegeManager.RefreshPrivilegeUsedTimes(freeTimesId,1)--记录免费抽卡次数
                        end
                        PrivilegeManager.RefreshPrivilegeUsedTimes(maxtimesId,1)--记录抽卡次数
                        UIManager.OpenPanel(UIName.QianKunBoxBuyOnePanel, msg.drop,singleRecruit.Id,{nil, type})
                        CheckRedPointStatus(RedPointType.QianKunBox)
                    end,freeTimesId)
                end
                if state == 0 and item[1] == 16 and not isFree then
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,singleRecruit.Id,recruitOne)
                else
                    recruitOne()
                end
            elseif n==bType.Btn10 then

                
                local lotterySettingConfig=G_LotterySetting[type]
                local count=BagManager.GetItemCountById(lotterySettingConfig.CostItem[1][1])
                local lotterten10,lotteryPerCount=RecruitManager.GetExpendData(type)
                local singleCost=lotterten10[2]/lotterySettingConfig.PerCount
                if count>lotterySettingConfig.PerCount then
                    count=lotterySettingConfig.PerCount
                end
                local deficiencyCount = lotterySettingConfig.PerCount - count
                if BagManager.GetItemCountById(item[1]) < deficiencyCount*singleCost then
                    PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[item[1]].Name)..GetLanguageStrById(10492))
                    return
                end


                if PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)+10>privilegeConfig[maxtimesId].Condition[1][2] then
                    PopupTipPanel.ShowTip(GetLanguageStrById(11760))
                    return
                end
                local recruitTen = function()
                    RecruitManager.RecruitRequest(tenRecruit.Id, function(msg)
                        PrivilegeManager.RefreshPrivilegeUsedTimes(maxtimesId,10)--记录抽卡次数
                        UIManager.OpenPanel(UIName.QianKunBoxBuyTenPanel, msg.drop,tenRecruit.Id,{nil, type})
                        CheckRedPointStatus(RedPointType.QianKunBox)
                    end,freeTimesId)
                end
                if item[1] ==16 and not isFree and BagManager.GetItemCountById(v1) > 0 and state == 0 then
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,tenRecruit.Id,recruitTen)
                elseif state == 0 and item[1] == 16 and not isFree and BagManager.GetItemCountById(v1) <= 0 then
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,tenRecruit.Id,recruitTen)
                else
                    recruitTen()
                end
            end
        end)
    end
end

function QianKunBox:RefreshOneBtnNum()
    local freeTimesId = lotterySetting[singleRecruit.Id].FreeTimes
    local maxtimesId = lotterySetting[singleRecruit.Id].MaxTimes
    local curTimes = PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)
    local freeTime = 0
    this.limit.text = GetLanguageStrById(12225)..curTimes.."/"..privilegeConfig[maxtimesId].Condition[1][2]

    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        RecruitManager.freeUseTimeList[freeTimesId] = freeTime
    end

    local freeTimesId = lotterySetting[singleRecruit.Id].FreeTimes
    local freeTime = 0
    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        RecruitManager.freeUseTimeList[freeTimesId] = freeTime
    end
    isFree = freeTime and freeTime >= 1
    local btn = Util.GetGameObject(this.bottom,"btnOne")
    local icon = Util.GetGameObject(btn.gameObject,"layout/icon"):GetComponent("Image")
    local num = Util.GetGameObject(btn.gameObject,"layout/num"):GetComponent("Text")
    this.di1:SetActive(not isFree)
    Util.GetGameObject(btn,"free"):SetActive(isFree)
    Util.GetGameObject(btn,"Text"):SetActive(not isFree)
    Util.GetGameObject(btn,"redPoint"):SetActive(isFree)
    num.gameObject:SetActive(not isFree)
    icon.gameObject:SetActive(not isFree)
    local d = RecruitManager.GetExpendData(singleRecruit.Id)
    icon.sprite = Util.LoadSprite(artResourcesConfig[itemConfig[d[1]].ResourceID].Name)
    num.text = tostring(d[2])
end

-- --五个魂印头像
-- function QianKunBox:contentShow()
--     for i = 1, 5 do
--         local icon = Util.GetGameObject(this.icons,"icon"..i.."/icon"):GetComponent("Image")
--         local kuang = Util.GetGameObject(this.icons,"icon"..i.."/kuang"):GetComponent("Image")
--         local name = artConfig[itemConfig[iconsData[i].Reward[1]].ResourceID].Name
--         icon.sprite = Util.LoadSprite(name)
--         if itemConfig[iconsData[i].Reward[1]].Quantity == 5 then--金色
--             kuang.sprite = Util.LoadSprite("N1_img_zhuangzhilinyun_diepianhuang")--m5--N1
--         end
--         --点击能查看魂印信息
--         Util.AddOnceClick(Util.GetGameObject(this.icons,"icon"..i.."/kuang"),function ()
--             -- UIManager.OpenPanel(UIName.SoulPrintPopUp,nil,nil,iconsData[i].Reward[1],nil,nil)
--             UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, iconsData[i].Reward[1], function()
--                 UIManager.ClosePanel(UIName.RewardItemSingleShowPopup)
--             end)
--         end)
--     end
-- end

--商店
function QianKunBox:storeShow()
    if not this.shopView then
        this.shopView = SubUIManager.Open(SubUIConfig.ShopView, this.content.transform, this.content)
    end
    this.shopView:BindEvent()
    ShopManager.RequestAllShopData(function ()
        this.shopView:ShowShop(SHOP_TYPE.QIANKUNBOX_SHOP,orginLayer)
    end)
end

--时间
function QianKunBox:timeCountDown()
    local timeDown = CalculateSecondsNowTo_N_OClock(24)--领取按钮的倒计时
    this.btnTime.text = TimeToHMS(timeDown)
    -- this.shopData = ShopManager.GetShopDataByType(SHOP_TYPE.QIANKUNBOX_SHOP)--获取活动信息
    this.shopData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.QianKunBox)
    this.leftUpTime.text = GetLanguageStrById(12230)..this:TimeToDHMS(this.shopData.endTime - PlayerManager.serverTime)--活动结束的倒计时
    this.timer = Timer.New(function()
        this.leftUpTime.text = GetLanguageStrById(12230)..this:TimeToDHMS(this.shopData.endTime - PlayerManager.serverTime)
        this.btnTime.text = TimeToHMS(timeDown)
        if timeDown < 1 then
            this.timer:Stop()
            this.timer = nil
            return
        end
        timeDown = timeDown -1
    end, 1, -1, true)
    this.timer:Start()
end

--- 将一段时间转换为天时分秒
function QianKunBox:TimeToDHMS(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = math.floor(second % 60)
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    if day <= 0 and hour <= 0 then
        return string.format(GetLanguageStrById(12231),minute, sec)
    else
        return string.format(GetLanguageStrById(12232),day, hour)
    end
end

-- function QianKunBox:refreshMagicNum()
--     local actData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.QianKunBox)  
--     -- local d = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySpecialConfig,"Type",singleRecruit.MergePool)
--     -- this.leftUptips1.text = d[1].Count-math.floor(actData.value/1000)
--     -- this.btnTimes.text = tostring(d[2].Count-actData.value%1000)..GetLanguageStrById(12264)
--     -- this.midDowntips1.text = GetLanguageStrById(12239)
-- end

function QianKunBox:OnSortingOrderChange(_sortingOrder)
    orginLayer = _sortingOrder
end

function QianKunBox:OnHide()
    this.gameObject:SetActive(false)
    this.detail.gameObject:SetActive(false)
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    if this.shopView then
        this.shopView = SubUIManager.Close(this.shopView)
        Util.ClearChild(this.content.transform)
        this.shopView = nil
    end
end

--添加事件监听（用于子类重写）
function QianKunBox:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Activity.QianKunBoxRefreshBtn, self.RefreshOneBtnNum)
end

--移除事件监听（用于子类重写）
function QianKunBox:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.QianKunBoxRefreshBtn, self.RefreshOneBtnNum)
end
return QianKunBox