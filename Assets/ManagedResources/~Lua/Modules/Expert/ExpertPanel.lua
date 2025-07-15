require("Base/BasePanel")
ExpertPanel = Inherit(BasePanel)
local this = ExpertPanel
local BoxPoolConfig = ConfigManager.GetConfig(ConfigName.BoxPoolConfig)

local itemParamList = {--1.未选中 2.选中 3.ActiveType
    [1]  = {"",""},
    [2]  = {"",""},
    [3]  = {"",""},
    [4]  = {"",""},
    [5]  = {"",""},
    [6]  = {"",""},
    [7]  = {"cn2-X1_jingyinghuodong_yeqian_07", "cn2-X1_jingyinghuodong_yeqianxuanzhong_07", ActivityTypeDef.AccumulativeRechargeExper},--每日累充
    [8]  = {"cn2-X1_fuhqixi_yeqian_01", "cn2-X1_fuhqixi_yeqian_02", ActivityTypeDef.LimitExchange},--腐化侵袭
    [9]  = {"",""},
    [10] = {"cn2-X1_jingyinghuodong_yeqian_02", "cn2-X1_jingyinghuodong_yeqianxuanzhong_02", ActivityTypeDef.AdventureExper},--快速作战
    [11] = {"",""},
    [12] = {"",""},
    [13] = {"cn2-X1_jingyinghuodong_yeqian_01", "cn2-X1_jingyinghuodong_yeqianxuanzhong_01", ActivityTypeDef.GoldExper},--征收赋税
    [14] = {"",""},
    [15] = {"",""},
    [16] = {"",""},
    [17] = {"",""},
    [18] = {"",""},
    [19] = {"cn2-X1_jingyinghuodong_yeqian_03", "cn2-X1_jingyinghuodong_yeqianxuanzhong_03",ActivityTypeDef.FindTreasureExper},--巡逻达人
    [20] = {"cn2-X1_fuli_yeqian_xunb", "cn2-X1_tianjyuns_yeqian_04",ActivityTypeDef.LuckyTurnExper},--轮盘达人
    [21] = {"cn2-X1_jingyinghuodong_yeqian_06", "cn2-X1_jingyinghuodong_yeqianxuanzhong_06",ActivityTypeDef.RecruitExper},--征募达人
    [22] = {"",""},
    [23] = {"cn2-X1_jingyinghuodong_yeqian_10", "cn2-X1_jingyinghuodong_yeqianxuanzhong_10", ActivityTypeDef.UpLvAct},--升级礼包
    [24] = {"cn2-X1_jingyinghuodong_yeqian_08", "cn2-X1_jingyinghuodong_yeqianxuanzhong_08", ActivityTypeDef.ContinuityRecharge},--累充礼盒
    [25] = {"cn2-X1_jingyinghuodong_yeqian_09", "cn2-X1_jingyinghuodong_yeqianxuanzhong_09", 10007},--限定珍藏
    [26] = {"", ""},
    [27] = {"cn2-X1_jingyinghuodong_yeqian_05", "cn2-X1_jingyinghuodong_yeqianxuanzhong_05", 70},--异端克星
    [28] = {"", ""},
    [29] = {"", ""},
    [30] = {"", ""},
    [31] = {"cn2-X1_zhuthd_yeqian_kaifushuangbei_01", "cn2-X1_zhuthd_yeqian_kaifushuangbei_02", ActivityTypeDef.OpenService},--开服双倍
    [32] = {"cn2-X1_xingyunxing_02", "cn2-X1_xingyunxing_01", ActivityTypeDef.BoxPool},--开服馈赠
}

local allActivityNum = #itemParamList--最大活动数量
local tabBtns = {}
local tabSelectBtns = {}
local expertRedPointGrid = {}--红点

local ExChange = require("Modules/Expert/ExChange") --腐化侵袭
local Expert = require("Modules/Expert/Expert") --多个活动集合
local Expert_UpLv = require("Modules/Expert/Expert_UpLv") --升级礼包
local ContinuityRechargePage = require("Modules/Operating/ContinuityRechargePage") --累充豪礼
local GiftBuy = require("Modules/Expert/GiftBuy") --限定珍藏
local OpenService = require("Modules/Expert/OpenService") --开服双倍
local BoxPool = require("Modules/Expert/BoxPool")--扭蛋
local curIndex = 0
local isBindRedPoint = false

--初始化组件（用于子类重写）
function ExpertPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    local pre = Util.GetGameObject(this.gameObject, "tabs/viewPort/tabsContent/btn")
    for i = 1, allActivityNum do
        if not tabBtns[i] then
            tabBtns[i] = newObjToParent(pre, Util.GetGameObject(this.gameObject, "tabs/viewPort/tabsContent").transform)
        end
        Util.GetGameObject(tabBtns[i], "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(itemParamList[i][1]))
        Util.GetGameObject(tabBtns[i], "selected/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(itemParamList[i][2]))
        tabBtns[i].gameObject.name = "tab"..i
        tabBtns[i]:SetActive(true)
        expertRedPointGrid[i] = Util.GetGameObject(tabBtns[i], "redPoint")
        -- expertRedPointGrid[i]:SetActive(false)
        tabSelectBtns[i] = Util.GetGameObject(tabBtns[i], "selected")
    end

    for i = 1, allActivityNum do
        Util.AddOnceClick(tabBtns[i], function()
            curIndex = i
            this:ActivityRewardShow()
        end)
    end
    
    this.TabSort()

    --各种限时活动注册
    this.exChange = ExChange.new(self, Util.GetGameObject(self.transform, "downLayout/exChangeGrid"))
    this.expert = Expert.new(self, Util.GetGameObject(self.transform, "downLayout/expertRewardGrid"))
    this.upLvRewardGrid = Expert_UpLv.new(self, Util.GetGameObject(self.transform, "downLayout/UpLvRewardGrid"))
    this.continuityRechargePage = ContinuityRechargePage.new(self, Util.GetGameObject(self.transform, "downLayout/ContinuityRecharge"))
    this.giftBuy = GiftBuy.new(self, Util.GetGameObject(self.transform, "downLayout/GiftBuy"))
    this.openService = OpenService.new(self, Util.GetGameObject(self.transform, "downLayout/OpenService"))
    this.boxPool = BoxPool.new(self, Util.GetGameObject(self.transform, "downLayout/BoxPool"))

    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowRight })
end

--绑定事件（用于子类重写）
function ExpertPanel:BindEvent()
    this.upLvRewardGrid:BindEvent()
    Util.AddClick(this.btnBack, function()
        UIManager.OpenPanel(UIName.MainPanel)
    end)
    this:BindRedPoint()
end

--添加事件监听（用于子类重写）
function ExpertPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose, this.RefreshActivity)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityProgressStateChange, this.RefreshActivity)
    Game.GlobalEvent:AddEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, this.RefreshActivity)
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
end

--移除事件监听（用于子类重写）
function ExpertPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose, this.RefreshActivity)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityProgressStateChange, this.RefreshActivity)
    Game.GlobalEvent:RemoveEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, this.RefreshActivity)
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
end

--界面打开时调用（用于子类重写）
function ExpertPanel:OnOpen(index)
    if index ~= nil then
        curIndex = index
    end
    if UIManager.IsOpen(UIName.RoleInfoPanel) then
        UIManager.ClosePanel(UIName.RoleInfoPanel)
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ExpertPanel:OnShow()
    this.HeadFrameView:OnShow()
    this:CreateTab()
    this:CheckRedPoint()

    this:RefreshActivityShow()
    if curIndex <= 0 then
        this:GetPriorityIndex()
    end
    this:ActivityRewardShow()
end

function ExpertPanel:OnSortingOrderChange()
    this.upLvRewardGrid:OnSortingOrderChange(self.sortingOrder)
    this.continuityRechargePage:OnSortingOrderChange(self.sortingOrder)
    this.giftBuy:OnSortingOrderChange(self.sortingOrder)
    this.exChange:OnSortingOrderChange(self.sortingOrder)
end

--界面关闭时调用（用于子类重写）
function ExpertPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function ExpertPanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(self.UpView)
    this:ClearRedPoint()
    isBindRedPoint = false
end

--设置选中按钮
function this:ShowActivityData()
    for i = 1, allActivityNum do
        tabSelectBtns[i]:SetActive(i == curIndex)
    end
end

function this.RefreshActivity()
    this:RefreshActivityShow()

    if tabBtns[curIndex].gameObject.activeSelf then
    else
        this:GetPriorityIndex()
    end
    this:ShowActivityData()
    this:ActivityRewardShow()
end

--刷新活动开关
function this:RefreshActivityShow()
    tabBtns[1]:SetActive(false)--(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayRegister))
    tabBtns[2]:SetActive(false)
    tabBtns[3]:SetActive(false)
    tabBtns[4]:SetActive(false)
    tabBtns[5]:SetActive(false)--(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LuckyCat))
    tabBtns[6]:SetActive(false)--(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LuckyTurnTable_One))
    tabBtns[7]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AccumulativeRechargeExper))
    tabBtns[8]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LimitExchange))
    tabBtns[9]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.UpStarExper))
    tabBtns[10]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AdventureExper))
    tabBtns[11]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.AreaExper))
    tabBtns[12]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.EquipExper))
    tabBtns[13]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.GoldExper))
    tabBtns[14]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FightExper))
    tabBtns[15]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.EnergyExper))
    tabBtns[16]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.Talisman))
    tabBtns[17]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SoulPrint))
    tabBtns[18]:SetActive(false)--(OperatingManager.IsHeroGiftActive())
    tabBtns[19]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindTreasureExper))
    tabBtns[20]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LuckyTurnExper))
    tabBtns[21]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.RecruitExper))
    tabBtns[22]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SecretBoxExper))
    tabBtns[23]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.UpLvAct))
    tabBtns[24]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.ContinuityRecharge))
    tabBtns[25]:SetActive(OperatingManager.IsGiftBuyActive())
    tabBtns[26]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.ExpeditionExper))
    tabBtns[27]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.slhjExper))
    tabBtns[28]:SetActive(false)--(ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.PreparationBefore))
    tabBtns[29]:SetActive(false)--(ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.Resupply))
    tabBtns[30]:SetActive(false)--(ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.Deployment))
    tabBtns[31]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.OpenService))
    tabBtns[32]:SetActive(not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.BoxPool))
end

--获取优先显示下标
function this:GetPriorityIndex()
    for i, btn in ipairs(tabBtns) do
        if btn.activeSelf then
            curIndex = i
            break
        end
    end
end

--显示页面
function this:ActivityRewardShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })

    this.expert.gameObject:SetActive(false)
    this.exChange.gameObject:SetActive(curIndex == ExperType.ExChange)
    this.upLvRewardGrid.gameObject:SetActive(curIndex == ExperType.UpLv)
    this.continuityRechargePage.gameObject:SetActive(curIndex == ExperType.ContinueRecharge)
    this.giftBuy.gameObject:SetActive(curIndex == ExperType.GiftBuy or curIndex == ExperType.Resupply)
    this.openService.gameObject:SetActive(curIndex == ExperType.OpenService)
    this.boxPool.gameObject:SetActive(curIndex == ExperType.BoxPool)

    if curIndex == ExperType.ExChange then
        this:ShowActivityData()
        this.exChange:OnShow(self.sortingOrder)
    elseif curIndex == ExperType.UpLv then
        this:ShowActivityData()
        this.upLvRewardGrid:OnShow()
    elseif curIndex == ExperType.ContinueRecharge then
        this:ShowActivityData()
        this.continuityRechargePage:OnShow(self.sortingOrder)
    elseif curIndex == ExperType.GiftBuy then
        this:ShowActivityData()
        this.giftBuy:OnShow(self.sortingOrder, 20)
    elseif curIndex == ExperType.OpenService then
        this:ShowActivityData()
        this.openService:OnShow(self.sortingOrder)
    elseif curIndex == ExperType.BoxPool then
        ActivityGiftManager.InitBoxPoolInfo(function ()
            if ActivityGiftManager.boxPoolId == 1 then
                this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.BoxPool})
            else
                this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.BoxPool_2})
            end
            this:ShowActivityData()
            this.boxPool:OnShow(self.sortingOrder)
        end)
    else
        this.expert.gameObject:SetActive(true)
        this:ShowActivityData()
        this.expert:OnShow(curIndex, self.sortingOrder)
    end

    this:CheckRedPoint()
end

--绑定红点
function this:BindRedPoint()
    -- BindRedPointObject(RedPointType.CourtesyDress_SevenDay, expertRedPointGrid[1])
    BindRedPointObject(RedPointType.Expert_WeekCard, expertRedPointGrid[4])
    -- BindRedPointObject(RedPointType.LuckyCat, expertRedPointGrid[5])
    -- BindRedPointObject(RedPointType.Expert_LuckyTurn, expertRedPointGrid[6])
    BindRedPointObject(RedPointType.Expert_AccumulativeRecharge, expertRedPointGrid[7])
    BindRedPointObject(RedPointType.Expert_UpStarExper, expertRedPointGrid[9])
    BindRedPointObject(RedPointType.Expert_AdventureExper, expertRedPointGrid[10])
    BindRedPointObject(RedPointType.Expert_AreaExper, expertRedPointGrid[11])
    BindRedPointObject(RedPointType.Expert_EquipExper, expertRedPointGrid[12])
    BindRedPointObject(RedPointType.Expert_GoldExper, expertRedPointGrid[13])
    BindRedPointObject(RedPointType.Expert_FightExper, expertRedPointGrid[14])
    BindRedPointObject(RedPointType.Expert_EnergyExper, expertRedPointGrid[15])
    BindRedPointObject(RedPointType.Expert_Talisman, expertRedPointGrid[16])
    BindRedPointObject(RedPointType.Expert_SoulPrint, expertRedPointGrid[17])
    BindRedPointObject(RedPointType.HERO_STAR_GIFT, expertRedPointGrid[18])
    BindRedPointObject(RedPointType.Expert_FindTreasure, expertRedPointGrid[19])
    BindRedPointObject(RedPointType.Expert_LuckyTurn, expertRedPointGrid[20])
    BindRedPointObject(RedPointType.Expert_Recruit, expertRedPointGrid[21])
    BindRedPointObject(RedPointType.Expert_SecretBox, expertRedPointGrid[22])
    BindRedPointObject(RedPointType.Expert_UpLv, expertRedPointGrid[23])
    BindRedPointObject(RedPointType.ContinuityRecharge, expertRedPointGrid[24])
    -- BindRedPointObject(RedPointType.Expert_Expedition, expertRedPointGrid[26])
    BindRedPointObject(RedPointType.Expert_Heresy, expertRedPointGrid[27])
    BindRedPointObject(RedPointType.OpenService, expertRedPointGrid[31])
    BindRedPointObject(RedPointType.BoxPool, expertRedPointGrid[32])
end

--解绑红点
function this:ClearRedPoint()
    -- ClearRedPointObject(RedPointType.CourtesyDress_SevenDay)
    ClearRedPointObject(RedPointType.Expert_WeekCard)
    -- ClearRedPointObject(RedPointType.LuckyCat)
    -- ClearRedPointObject(RedPointType.Expert_LuckyTurn)
    ClearRedPointObject(RedPointType.Expert_AccumulativeRecharge)
    ClearRedPointObject(RedPointType.Expert_UpStarExper)
    ClearRedPointObject(RedPointType.Expert_AdventureExper)
    ClearRedPointObject(RedPointType.Expert_AreaExper)
    ClearRedPointObject(RedPointType.Expert_EquipExper)
    ClearRedPointObject(RedPointType.Expert_GoldExper)
    ClearRedPointObject(RedPointType.Expert_FightExper)
    ClearRedPointObject(RedPointType.Expert_EnergyExper)
    ClearRedPointObject(RedPointType.Expert_Talisman)
    ClearRedPointObject(RedPointType.Expert_FindTreasure)
    ClearRedPointObject(RedPointType.Expert_LuckyTurn)
    ClearRedPointObject(RedPointType.Expert_Recruit)
    ClearRedPointObject(RedPointType.Expert_SecretBox)
    ClearRedPointObject(RedPointType.Expert_UpLv)
    ClearRedPointObject(RedPointType.Expert_SoulPrint)
    ClearRedPointObject(RedPointType.Expert_Heresy)
    ClearRedPointObject(RedPointType.HERO_STAR_GIFT)
    ClearRedPointObject(RedPointType.ContinuityRecharge)
    ClearRedPointObject(RedPointType.OpenService)
    ClearRedPointObject(RedPointType.BoxPool)
end

function this:CheckRedPoint()
    CheckRedPointStatus(RedPointType.Expert_WeekCard)
    CheckRedPointStatus(RedPointType.Expert_AccumulativeRecharge)
    CheckRedPointStatus(RedPointType.Expert_UpStarExper)
    CheckRedPointStatus(RedPointType.Expert_AdventureExper)
    CheckRedPointStatus(RedPointType.Expert_AreaExper)
    CheckRedPointStatus(RedPointType.Expert_EquipExper)
    CheckRedPointStatus(RedPointType.Expert_GoldExper)
    CheckRedPointStatus(RedPointType.Expert_FightExper)
    CheckRedPointStatus(RedPointType.Expert_EnergyExper)
    CheckRedPointStatus(RedPointType.Expert_Talisman)
    CheckRedPointStatus(RedPointType.Expert_SoulPrint)
    CheckRedPointStatus(RedPointType.HERO_STAR_GIFT)
    CheckRedPointStatus(RedPointType.Expert_FindTreasure)
    CheckRedPointStatus(RedPointType.Expert_LuckyTurn)
    CheckRedPointStatus(RedPointType.Expert_Recruit)
    CheckRedPointStatus(RedPointType.Expert_SecretBox)
    CheckRedPointStatus(RedPointType.Expert_UpLv)
    CheckRedPointStatus(RedPointType.ContinuityRecharge)
    CheckRedPointStatus(RedPointType.Expert_Heresy)
    CheckRedPointStatus(RedPointType.OpenService)
    -- RedpotManager.RefreshRedObjectStatus(RedPointType.OpenService)
    CheckRedPointStatus(RedPointType.BoxPoolCanDraw)
    CheckRedPointStatus(RedPointType.BoxPoolFreeTime)
end

--tab排序
function this.TabSort()
    for i = 1, allActivityNum do
        if itemParamList[i][3] then
            local data = ConfigManager.TryGetConfigDataByKey(ConfigName.ActivityGroups, "ActiveType", itemParamList[i][3])
            if data and data.Sort then
                tabBtns[i].transform:SetSiblingIndex(data.Sort)
            else
                LogRed("找不到类型：" .. itemParamList[i][3])
            end
        end
    end
end

function this:CreateTab()
    for i = 1, allActivityNum do
        if itemParamList[i][3] then
            if itemParamList[i][3] == ActivityTypeDef.BoxPool then
                if not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.BoxPool) then
                    if ActivityGiftManager.boxPoolId == 0 then
                        ActivityGiftManager.InitBoxPoolInfo(function ()
                            local type = BoxPoolConfig[ActivityGiftManager.boxPoolId].PoolShowType
                            if type == 1 then
                                itemParamList[i][1] = "cn2-X1_kaufukuizeng_yeqian_02"
                                itemParamList[i][2] = "cn2-X1_kaifukuizeng_yeqianxuanzhong_01"
                            end
                        end)
                    else
                        local type = BoxPoolConfig[ActivityGiftManager.boxPoolId].PoolShowType
                        if type == 1 then
                            itemParamList[i][1] = "cn2-X1_kaufukuizeng_yeqian_02"
                            itemParamList[i][2] = "cn2-X1_kaifukuizeng_yeqianxuanzhong_01"
                        end
                    end
                    Util.GetGameObject(tabBtns[i], "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(itemParamList[i][1]))
                    Util.GetGameObject(tabBtns[i], "selected/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(itemParamList[i][2]))
                end
            end
        end
    end
end

--直购外网刷新界面
function this.RechargeSuccessFunc(id)
    local curRechargeCommConfig = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, id)
    if curRechargeCommConfig.ShowType == 20 then
        this.giftBuy:OnShow()--限购礼包
    end
end

return ExpertPanel