local SheJiDaDian = quick_class("SheJiDaDian")
local this = SheJiDaDian
local orginLayer = 0
local parent
local ItemData = ConfigManager.GetConfig(ConfigName.ItemConfig)

local actReward = {}--奖励数据
local activityId--活动Id
local ActInfo = {}--活动数据
local curRankType = RANK_TYPE.GOLD_EXPER
local canGetRewardList = {} --可领取的宝箱

local isPressed = false--是否按下
local isShortPress = false--点击捐献
local trigger = false --道具不足的trigger
local t = 20 --用来区分长按和点击的临界值

local curItemIndex = nil
local numCount = 1 --用于计算按下的时长（长按的捐献个数 = 用于计算按下的时长 - t）
local curScore = 0
local myRank

local itemData = {--捐献道具id--三个按钮的数字显示--三个按钮的图片--三个trigger
    [1] = { id = 50000 , num = nil , leftNum = nil , icon = "cn2-X1_icon_item_lizi" , trigger = nil , value = 1},
    [2] = { id = 50001 , num = nil , leftNum = nil , icon = "cn2-X1_icon_item_nengyuan" , trigger = nil , value = 2},
    [3] = { id = 50002 , num = nil , leftNum = nil , icon = "cn2-X1_icon_item_yuanshi" , trigger = nil , value = 10}
}

local btnState = {
    [1] = { imageColor = Color.New(255/255,209/255,42/255,1), textColor = Color.New(0/255,0/255,0/255,1)},
    [2] = { imageColor = Color.New(255/255,209/255,42/255,0), textColor = Color.New(255/255,255/255,255/255,125/255)}
}

function this:ctor(mainPanel, gameObject)
    this.mainPanel = mainPanel.transform
    this.gameObject = gameObject
    this:InitComponent(gameObject)
    this:BindEvent()
end

function this:InitComponent(gameObject)

    --down
    -- this.tabList = Util.GetGameObject(this.mainPanel,"bg/tabbox")
    -- this.btnBack = Util.GetGameObject(this.mainPanel,"bg/btnBack")
    -- this.bottomBar = Util.GetGameObject(this.mainPanel,"bg/bottomBar")/

    --rank
    this.rank = Util.GetGameObject(this.gameObject,"Rank")
    this.firstName = Util.GetGameObject(this.rank,"name/first"):GetComponent("Text")
    this.secendName = Util.GetGameObject(this.rank,"name/secend"):GetComponent("Text")
    this.thirdName = Util.GetGameObject(this.rank,"name/third"):GetComponent("Text")
    -- this.myScoreText = Util.GetGameObject(this.rank,"myScore")
    -- this.guildScoreText = Util.GetGameObject(this.rank,"guildScore")
    -- this.score = Util.GetGameObject(this.rank,"text/score"):GetComponent("Text")
    this.btnDetail = Util.GetGameObject(this.rank,"btnDetail")
    this.btnTeamRank = Util.GetGameObject(this.rank,"teamRank")
    this.btnPersonRank = Util.GetGameObject(this.rank,"personRank")
    this.rankTime = Util.GetGameObject(this.rank,"limit"):GetComponent("Text")

    --btns
    this.btns = Util.GetGameObject(this.gameObject,"btns")
    this.btnHelp = Util.GetGameObject(this.btns,"btnHelp")
    this.helpPosition = this.btnHelp:GetComponent("RectTransform").localPosition
    this.btnRewardList = Util.GetGameObject(this.btns,"reward")
    this.btnStore = Util.GetGameObject(this.btns,"store")

    --center
    this.time = Util.GetGameObject(this.gameObject,"time/timeText"):GetComponent("Text")
    -- this.btnGet = Util.GetGameObject(this.gameObject,"btnGet")
    -- this.effect = Util.GetGameObject(this.gameObject,"center/DynamicActivityPanel_daiji")
    -- this.effect2 = Util.GetGameObject(this.gameObject,"center/DynamicActivityPanel_dakai")

    --shop
    this.shop = Util.GetGameObject(this.gameObject,"shop")
    this.shopBack = Util.GetGameObject(this.shop,"shopBack/btnBack")
    this.content = Util.GetGameObject(this.shop,"content")

    -- this.bottom = Util.GetGameObject(this.gameObject,"bottom")
    this.slider = Util.GetGameObject(this.gameObject,"slider"):GetComponent("Slider")
    this.level = Util.GetGameObject(this.slider.gameObject,"level"):GetComponent("Text")
    this.btnBox = Util.GetGameObject(this.slider.gameObject,"Background")
    this.scoreText = Util.GetGameObject(this.slider.gameObject,"score"):GetComponent("Text")
    -- this.boxEffect = Util.GetGameObject(this.slider,"reward/box/UI_Effect_BaoXiang_KeKaiQi")

    this.items = Util.GetGameObject(this.gameObject,"items")
    -- this.btnAdd = Util.GetGameObject(this.items,"item3/btnAdd")
    for i = 1, 3 do
        local item = Util.GetGameObject(this.items,"item"..i)
        itemData[i].num = Util.GetGameObject(item,"num"):GetComponent("Text")
        itemData[i].icon = Util.GetGameObject(item,"icon/Image")
        itemData[i].name = Util.GetGameObject(item,"name"):GetComponent("Text")
        itemData[i].trigger = Util.GetEventTriggerListener(itemData[i].icon)
        itemData[i].trigger.onPointerDown = itemData[i].trigger.onPointerDown + function(go, data) this.OnPointerDown(go, data, i) end
        itemData[i].trigger.onPointerUp = itemData[i].trigger.onPointerUp + this.OnPointerUp
    end

    this.effects = {}
    for i = 1, 3 do
        this.effects[i] = Util.GetGameObject(this.gameObject,"bg/x1_UI_ciyuanyinqin/UI/UI" .. i)
    end
end

function SheJiDaDian:BindEvent()
    Util.AddClick(this.btnHelp,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Celebration,this.helpPosition.x + 430,this.helpPosition.y + 280)
    end)

    Util.AddClick(this.btnGet,function()
        ActInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.Celebration)--活动数据
        local setting = ConfigManager.GetConfigDataByKey(ConfigName.GodSacrificeSetting,"ActivityId",activityId)
        --活动结束时间
        local canGet = false
        local actTime = ActInfo.endTime - GetTimeStamp()
        this.rankTime.text = GetLanguageStrById(10028)..TimeToFelaxible(actTime)
        --宝箱领取重置时间
        local timeOne = Today_N_OClockTimeStamp(setting.TimePointList[1]) - GetTimeStamp()
        local leftTimeOne = timeOne > 0 and timeOne or timeOne + 86400--距离下一个十二点的时间
        local timeTwo = Today_N_OClockTimeStamp(setting.TimePointList[2]) - GetTimeStamp()
        local leftTimeTwo = timeTwo > 0 and timeTwo or timeTwo + 86400--距离下一个二十点的时间
        local giftTime = leftTimeOne < leftTimeTwo and leftTimeOne or leftTimeTwo--取小的
        local t1 = GetTimeStamp() - Today_N_OClockTimeStamp(setting.TimePointList[1])
        local t2 = GetTimeStamp() - Today_N_OClockTimeStamp(setting.TimePointList[2])
        if ActInfo.value == 0 then
            if (t1 > 0 and t1 < 1800) or (t2 > 0 and t2 < 1800) then
                canGet = true
            else
                canGet = false
            end
        else
            if (t1 > 0 and t1 < 1800) or (t2 > 0 and t2 < 1800) then
                if (GetTimeStamp() - ActInfo.value) < 1800 then
                    canGet = false
                else
                    canGet = true
                end
            else
                canGet = false
            end
        end
        if canGet == true then
            NetManager.GetSheJiRewardRequest(activityId,function (_drop)
                -- this.effect2:SetActive(true)
                -- local effectKaiQi = Util.GetGameObject(this.gameObject,"center/box"):GetComponent("Animator")
                -- effectKaiQi:SetBool("dakai",true)
                Timer.New(function ()
                    UIManager.OpenPanel(UIName.RewardItemPopup, _drop.drop,1,function()
                        this:Refresh()
                    end)
                end,0.5):Start()
            end)
        else
            
        end
    end)

    Util.AddClick(this.btnRewardList,function()
        UIManager.OpenPanel(UIName.GeneralRankRewardPanel,2,myRank,activityId)--需要活动id，和我的排名
    end)

    Util.AddClick(this.btnStore,function()       
        local data = ConfigManager.GetConfigData(ConfigName.GlobalActivity,activityId)
        local shopData = ConfigManager.GetConfigData(ConfigName.StoreTypeConfig,data.ShopId[1])
        UIManager.OpenPanel(UIName.MapShopPanel,shopData.StoreType)

        -- this.effect:SetActive(false)--特效还没加，加好后放开
        -- this.shop:SetActive(true)
        -- this.btnBack:SetActive(false)
        -- this.tabList:SetActive(false)
        -- this.bottomBar:SetActive(false)
        -- this:StoreShow()--商店

        if this.UpView == nil then
            this.UpView = SubUIManager.Open(SubUIConfig.UpView, this.shop.transform, { showType = UpViewOpenType.ShowLeft})
            this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.CiYuanYinQinG})
        end
    end)

    Util.AddClick(this.shopBack,function()
        -- this.effect:SetActive(true)--特效还没加，加好后放开
        this.shop:SetActive(false)
        -- this.btnBack:SetActive(true)
        -- this.tabList:SetActive(true)
        -- this.bottomBar:SetActive(true)
    end)

    Util.AddClick(this.btnDetail,function()
        if curRankType == RANK_TYPE.GOLD_EXPER then--个人排行
            UIManager.OpenPanel(UIName.RankingSingleListPanel,RankKingList[13])
        elseif curRankType == RANK_TYPE.CELEBRATION_GUILD then--工会排行
            UIManager.OpenPanel(UIName.RankingSingleListPanel,RankKingList[14])
        end
    end)

    Util.AddClick(this.btnTeamRank,function()
        curRankType = RANK_TYPE.CELEBRATION_GUILD
        this:LeftUpShow(curRankType)
        this.SetBtnState(1)
    end)

    Util.AddClick(this.btnPersonRank,function()
        curRankType = RANK_TYPE.GOLD_EXPER
        this:LeftUpShow(curRankType)
        this.SetBtnState()
    end)

    Util.AddOnceClick(this.btnAdd,function ()
        UIManager.OpenPanel(UIName.DynamicActivityPanel,DynamicActivityManager.ZhenQiBaoGeIndex)
    end)

    Util.AddOnceClick(this.btnBox,function ()
        DynamicActivityManager.SetCurLevel(math.floor(curScore/(actReward[1].Values[2][1])))
        UIManager.OpenPanel(UIName.TrialRewardPopup,1,ActivityTypeDef.Celebration,activityId)
    end)
end

function this.SetBtnState(_btn)
    if _btn then
        this.btnTeamRank:GetComponent("Image").color = btnState[1].imageColor
        Util.GetGameObject(this.btnTeamRank,"Text"):GetComponent("Text").color = btnState[1].textColor
        this.btnPersonRank:GetComponent("Image").color = btnState[2].imageColor
        Util.GetGameObject(this.btnPersonRank,"Text"):GetComponent("Text").color = btnState[2].textColor
    else
        this.btnTeamRank:GetComponent("Image").color = btnState[2].imageColor
        Util.GetGameObject(this.btnTeamRank,"Text"):GetComponent("Text").color = btnState[2].textColor
        this.btnPersonRank:GetComponent("Image").color = btnState[1].imageColor
        Util.GetGameObject(this.btnPersonRank,"Text"):GetComponent("Text").color = btnState[1].textColor
    end
end

function this:OnShow(sortingOrder,_parent,actType)
    parent = _parent
    this.actType = actType
    -- Util.AddParticleSortLayer(this.effect, sortingOrder - orginLayer)
    -- Util.AddParticleSortLayer(this.effect2, sortingOrder - orginLayer)
    orginLayer = sortingOrder
    FixedUpdateBeat:Add(this.OnUpdate, this)--长按方法注册
    this:Refresh()
    --this:CheckGuild()
    self.sortingOrder = sortingOrder

    self.shopcanvas = self.shop:GetComponent("Canvas")
    if self.shopcanvas and self.sortingOrder then
        self.shopcanvas.sortingOrder = self.sortingOrder + 1
    end
end

--检查是否有公会
function this:CheckGuild()
    if PlayerManager.familyId == 0 then
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.SheJiCheckGuild)
    end
end

--刷新整个页面
function this:Refresh()
    trigger = false
    -- this.effect:SetActive(true)
    -- this.effect2:SetActive(false)

    ActInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.Celebration)--活动数据
    activityId = ActInfo.activityId
    actReward = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",activityId)
    this:RefreshItemsData()
    this:TimeCountDown()--时间
    this:LeftUpShow()
    this:RefreshBottom()--刷新下部数字
    this:RefreshRewardBox()--刷新奖励宝箱数据
end

--刷新物品剩余数量和当前积分
function this:RefreshItemsData()
    for i = 1, 3 do
        itemData[i].leftNum = BagManager.GetItemCountById(itemData[i].id)
    end
    curScore = ActInfo.mission[1].progress
end

function this:RefreshRewardBox()
    canGetRewardList = {}
    -- this.boxEffect:SetActive(false)
    this.btnBox:GetComponent("Image").enabled = true

    for i = 1, #ActInfo.mission do
        local curLevel = curScore/actReward[1].Values[2][1]
        if ActInfo.mission[i].state == 0 and curLevel >= i then
            table.insert(canGetRewardList,ActInfo.mission[i])
        end
    end
    if #canGetRewardList > 0 then
        -- this.boxEffect:SetActive(true)
        this.btnBox:GetComponent("Image").enabled = true
    end
end

--点击或长按处理升级处理
function this.OnPointerDown(Pointgo,data,i)--按下
    -- if PlayerManager.level < 50 then
    --     PopupTipPanel.ShowTipByLanguageId(12411)
    --     return
    -- end
    if PlayerManager.familyId == 0 then
        PopupTipPanel.ShowTipByLanguageId(23041)
        return
    end
    curItemIndex = i
    if BagManager.GetItemCountById(itemData[curItemIndex].id) <= 0 then
        return
    end
    numCount = 1
    isPressed = true
    this:OpenEffect()
end
function this.OnPointerUp(Pointgo,data)--抬起
    if PlayerManager.level < 50 or PlayerManager.familyId == 0 then
        return
    end
    if BagManager.GetItemCountById(itemData[curItemIndex].id) <= 0 then
        return
    end
    if isShortPress then
        numCount = 1
        -- this:RefreshBottom(numCount)
        this:RequestDonate(numCount)
    else
        if itemData[curItemIndex].leftNum > 0 then
            this:RequestDonate(numCount-t)
        end
    end
    isPressed = false
    isShortPress = false

    if this.effectTime then
        this.effectTime:Stop()
        this.effectTime = nil
    end
end
function this.OnUpdate()
    if isPressed then
        numCount = numCount + 1
        if numCount > t then
            isShortPress = false
            this:RefreshBottom(numCount-t)
        else
            if not isShortPress then
                isShortPress = true
            end
        end
    end
end

function this:OpenEffect()
    if this.effectTime then
        this.effectTime:Stop()
        this.effectTime = nil
    end

    this.effectTime = Timer.New(function()
        if not isPressed then
            this.effectTime:Stop()
            this.effectTime = nil
            return
        end
        this.effects[curItemIndex]:GetComponent("ParticleSystem"):Play()
    end, 0.2, -1)
    this.effectTime:Start()
end

--发送捐献请求
function this:RequestDonate(numCount)
    if numCount <= 0 then
        PopupTipPanel.ShowTipByLanguageId(11197)
        return
    end
    if trigger and numCount == 1 then
        trigger = false
        this:Refresh()
    else
        NetManager.SheJiDonateItemRequest(itemData[curItemIndex].id,numCount,function()
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12413), itemData[curItemIndex].value * numCount))
            trigger = false
            this.effects[curItemIndex]:GetComponent("ParticleSystem"):Play()
            this:Refresh()
            CheckRedPointStatus(RedPointType.Celebration)
        end)
    end
end

--刷新左上排行版
function this:LeftUpShow(_curRankType)
    if _curRankType then
        curRankType = _curRankType
    else
        if not curRankType then
            curRankType = RANK_TYPE.GOLD_EXPER
        end
    end
    DynamicActivityManager.SheJiGetRankData(curRankType,ActInfo.activityId,function(allRankData,myRankData)
        if curRankType == RANK_TYPE.GOLD_EXPER then
            this.firstName.text = allRankData[1] and allRankData[1].userName or GetLanguageStrById(11073)
            this.secendName.text = allRankData[2] and allRankData[2].userName or GetLanguageStrById(11073)
            this.thirdName.text = allRankData[3] and allRankData[3].userName or GetLanguageStrById(11073)
        else
            this.firstName.text = allRankData[1] and allRankData[1].guildName or GetLanguageStrById(11073)
            this.secendName.text = allRankData[2] and allRankData[2].guildName or GetLanguageStrById(11073)
            this.thirdName.text = allRankData[3] and allRankData[3].guildName or GetLanguageStrById(11073)
        end
        local t = myRankData.param1 > 0 and myRankData.param1 or 0
        -- this.score.text = curRankType == RANK_TYPE.GOLD_EXPER and t or ActInfo.mission[1].progress
        myRank = myRankData.rank
    end)
end

--刷新进度条和剩余数量
function this:RefreshBottom(num)
    local score = 0
    if num == nil then--初始、刷新进度条显示
        num = 0
        for i = 1, 3 do
            itemData[i].num.text = itemData[i].leftNum
            itemData[i].name.text = GetLanguageStrById(ItemData[itemData[i].id].Name)
            itemData[i].icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemData[itemData[i].id].ResourceID))
        end
        this.scoreText.text = (curScore%(actReward[1].Values[2][1])).."/"..actReward[1].Values[2][1]
    else--实时更新进度条
        --要判断是否还有道具进行捐献
        if itemData[curItemIndex].leftNum - num < 0 then
            this:RequestDonate(num - 1)
            trigger = true
            isPressed = false
            return
        end
        itemData[curItemIndex].num.text = itemData[curItemIndex].leftNum - num
        score = itemData[curItemIndex].value * num
        this.scoreText.text = ((curScore + score)%(actReward[1].Values[2][1])).."/"..actReward[1].Values[2][1]
    end
    this.slider.value = (((curScore + score))%(actReward[1].Values[2][1]))/actReward[1].Values[2][1]
    this.level.text = math.floor((curScore + score)/(actReward[1].Values[2][1])) .. GetLanguageStrById(10072)
end

--商店
function this:StoreShow()
    local activityId = ActivityGiftManager.IsActivityTypeOpen(this.actType)

    local shopType = ConfigManager.GetConfigDataByDoubleKey(ConfigName.ActivityStoreConfig,"ActivityId",activityId,"EnumerateType",1)

    if shopType == nil then
        return
    end
    if not this.shopView then
        this.shopView = SubUIManager.Open(SubUIConfig.ShopView, this.content.transform,this.content)
    end
    local shopTypeId = ConfigManager.GetConfigData(ConfigName.StoreTypeConfig,shopType.StoreTypeId)
    this.shopView:ShowShop(shopTypeId.StoreType,orginLayer)
end

--时间
function this:TimeCountDown()
    local setting = ConfigManager.GetConfigDataByKey(ConfigName.GodSacrificeSetting,"ActivityId",activityId)
    --活动结束时间
    local canGet = false
    local actTime = ActInfo.endTime - GetTimeStamp()
    this.rankTime.text = GetLanguageStrById(10028)..TimeToFelaxible(actTime)
    CardActivityManager.TimeDown(this.time, actTime)
    --宝箱领取重置时间
    local timeOne = Today_N_OClockTimeStamp(setting.TimePointList[1]) - GetTimeStamp()
    local leftTimeOne = timeOne > 0 and timeOne or timeOne + 86400--距离下一个十二点的时间
    local timeTwo = Today_N_OClockTimeStamp(setting.TimePointList[2]) - GetTimeStamp()
    local leftTimeTwo = timeTwo > 0 and timeTwo or timeTwo + 86400--距离下一个二十点的时间
    local giftTime = leftTimeOne < leftTimeTwo and leftTimeOne or leftTimeTwo--取小的

    -- local t1 = GetTimeStamp() - Today_N_OClockTimeStamp(setting.TimePointList[1])
    -- local t2 = GetTimeStamp() - Today_N_OClockTimeStamp(setting.TimePointList[2])

    -- if ActInfo.value == 0 then
    --     if (t1 > 0 and t1 < 1800) or (t2 > 0 and t2 < 1800) then
    --         canGet = true
    --     else
    --         canGet = false
    --     end
    -- else
    --     if (t1 > 0 and t1 < 1800) or (t2 > 0 and t2 < 1800) then
    --         if (GetTimeStamp() - ActInfo.value) < 1800 then
    --             canGet = false
    --         else
    --             canGet = true
    --         end
    --     else
    --         canGet = false
    --     end
    -- end

    -- this.time.text = canGet == false and GetLanguageStrById(12321)..TimeToFelaxible(giftTime) or GetLanguageStrById(12183)

    -- -- this.centerTime.text = canGet == false and GetLanguageStrById(23006)..TimeToFelaxible(giftTime)  or GetLanguageStrById(12183)

    if this.timer1 then
        this.timer1:Stop()
        this.timer1 = nil
    end
    this.timer1 = Timer.New(function()
        this.rankTime.text = GetLanguageStrById(10028)..TimeToFelaxible(actTime)
        -- this.time.text = canGet == false and GetLanguageStrById(12321)..TimeToFelaxible(giftTime) or GetLanguageStrById(12183) 

        if actTime < 1 then
            this.timer1:Stop()
            this.timer1 = nil
            parent:ClosePanel()
            return
        end
        if giftTime < 0 then
            this:Refresh()
        end
        actTime = actTime -1
        giftTime = giftTime - 1
    end, 1, -1, true)
    this.timer1:Start()
end

function this:OnSortingOrderChange(_sortingOrder)
    orginLayer = _sortingOrder
end

function this:OnHide()
    FixedUpdateBeat:Remove(this.OnUpdate, this)
    if this.timer1 then
        this.timer1:Stop()
        this.timer1 = nil
    end
    if this.effectTime then
        this.effectTime:Stop()
        this.effectTime = nil
    end
    if this.shopView then
        this.shopView = SubUIManager.Close(this.shopView)
        this.shopView = nil
    end
    CardActivityManager.StopTimeDown()
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.DynamicTask.OnGetReward, this.Refresh)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.DynamicTask.OnGetReward, this.Refresh)
end

return this