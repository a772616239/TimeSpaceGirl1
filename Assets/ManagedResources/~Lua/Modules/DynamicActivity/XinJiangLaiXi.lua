local XinJiangLaiXi = quick_class("XinJiangLaiXi")
local this=XinJiangLaiXi
local allData={}
local itemsGrid = {}--item重复利用
local sortingOrder = 0
local parent = {}

this.LiveObj = nil
function XinJiangLaiXi:ctor(mainPanel, gameObject)
    this.mainPanel = mainPanel.transform
    this.gameObject = gameObject
    this:InitComponent()
    this:BindEvent()
end

function XinJiangLaiXi:InitComponent()
    this.time = Util.GetGameObject(this.gameObject, "time/times"):GetComponent("Text")
    -- this.money = Util.GetGameObject(this.gameObject, "money/times"):GetComponent("Text")
    this.fightBtn = Util.GetGameObject(this.gameObject, "layout/fightBtn")
    this.storeBtn = Util.GetGameObject(this.gameObject, "storeBtn")
    this.helpBtn = Util.GetGameObject(this.gameObject, "helpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    this.scrollItem = Util.GetGameObject(this.gameObject, "scroller/grid")
    this.liveRoot = Util.GetGameObject(this.gameObject, "bg/liveRoot")
    this.tip1 = Util.GetGameObject(this.gameObject, "layout/Text1"):GetComponent("Text")
    this.tip2 = Util.GetGameObject(this.gameObject, "layout/Text2"):GetComponent("Text")
    this.addBtn = Util.GetGameObject(this.gameObject, "layout/addBtn")

    --shop
    this.tabList = Util.GetGameObject(this.mainPanel,"bg/tabbox")
    this.btnBack = Util.GetGameObject(this.mainPanel,"bg/btnBack")
    this.bottomBar = Util.GetGameObject(this.mainPanel,"bg/bottomBar")

    this.shop = Util.GetGameObject(this.gameObject,"shop")
    this.shopBack = Util.GetGameObject(this.shop,"shopBack/btnBack")
    this.content = Util.GetGameObject(this.shop,"content")
end

--绑定事件（用于子类重写）
function XinJiangLaiXi:BindEvent()
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.XinJiangLaiXi,this.helpPosition.x,this.helpPosition.y)
    end)

    Util.AddClick(this.addBtn, function()
        --购买特权
        if allData.buyTime > 0 then
            local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP,10036, 1)
            local itemName = ConfigManager.GetConfigData(ConfigName.ItemConfig,costId).Name
            MsgPanel.ShowTwo(string.format( GetLanguageStrById(10516),finalNum,GetLanguageStrById(itemName)), nil, function()
                --买东西
                ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,10036,1,function()
                    PopupTipPanel.ShowTipByLanguageId(10517)
                    PrivilegeManager.RefreshPrivilegeUsedTimes(2013, 1)--更新特权
                    XinJiangLaiXi:Refresh()
                end)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10518)
        end
    end)

    Util.AddClick(this.fightBtn,function()
        --开始战斗
        if allData.fightTime > 0 then
            NetManager.NewGeneralAttackRequest(allData.activityId,2012,function(msg)
                PrivilegeManager.RefreshPrivilegeUsedTimes(2012, 1)--更新特权
                UIManager.OpenPanel(UIName.BattleStartPopup, function ()
                     local fightData = BattleManager.GetBattleServerData(msg,0)
                    UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.XINJIANG,function ()
                            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1,function ()
                                this:Refresh()
                            end)
                    end)
                end)
            end)
        else
            --购买特权
            if allData.buyTime > 0 then
                local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP,10036, 1)
                local itemName = ConfigManager.GetConfigData(ConfigName.ItemConfig,costId).Name
                MsgPanel.ShowTwo(string.format( GetLanguageStrById(10516),finalNum,GetLanguageStrById(itemName)), nil, function()
                    --买东西
                    ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,10036,1,function()
                        PopupTipPanel.ShowTipByLanguageId(10517)
                        PrivilegeManager.RefreshPrivilegeUsedTimes(2013, 1)--更新特权
                        XinJiangLaiXi:Refresh()
                    end)
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(10519)
            end
        end
    end)

    Util.AddClick(this.storeBtn,function()
        this.shop:SetActive(true)
        this.btnBack:SetActive(false)
        this.tabList:SetActive(false)
        this.bottomBar:SetActive(false)
        this:StoreShow()--商店
    end)

    Util.AddClick(this.shopBack,function()
        this.shop:SetActive(false)
        this.btnBack:SetActive(true)
        this.tabList:SetActive(true)
        this.bottomBar:SetActive(true)
        parent.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
        XinJiangLaiXi:Refresh()
    end)

end
--添加事件监听（用于子类重写）
function XinJiangLaiXi:AddListener()
end

--移除事件监听（用于子类重写）
function XinJiangLaiXi:RemoveListener()
end

--界面打开时调用（用于子类重写）
function XinJiangLaiXi:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function XinJiangLaiXi:OnShow(_sortingOrder,_parent)
    local actId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.XinJiangLaiXi)
    if not actId or actId <= 0 then return end
    parent = _parent
    sortingOrder = _sortingOrder
    XinJiangLaiXi:Refresh()
end

function XinJiangLaiXi:Refresh()
    CheckRedPointStatus(RedPointType.XinJiangLaiXi)
    allData = DynamicActivityManager.XinJiangBuildData()
    XinJiangLaiXi:OnShowData()
    XinJiangLaiXi:SetTime()
end

function XinJiangLaiXi:OnShowData()
    this.shop:SetActive(false)
    if not itemsGrid then
        itemsGrid = {}
    end
    for k,v in ipairs(itemsGrid) do
        v.gameObject:SetActive(false)
    end

    for i = 1,#allData.reward do
        if not itemsGrid[i] then
            itemsGrid[i] = SubUIManager.Open(SubUIConfig.ItemView,this.scrollItem.transform)
        end
        itemsGrid[i].gameObject:SetActive(true)
        itemsGrid[i]:OnOpen(false, allData.reward[i], 1,false,false,false,sortingOrder)
    end

    if this.LiveObj then
        poolManager:UnLoadLive(this.LiveObj.name,this.LiveObj)
        this.LiveObj = nil
    end
    local configData = ConfigManager.GetConfigData(ConfigName.NewHeroConfig,allData.activityId)
    local HeroId = configData.HeroId
    local imgName = GetResourcePath(ConfigManager.GetConfigData(ConfigName.HeroConfig,HeroId).Live)
    this.LiveObj = poolManager:LoadLive(imgName,this.liveRoot.transform, Vector3.one*configData.Size[1], Vector2.New(configData.Size[2],configData.Size[3]))

    this.tip1.text = GetLanguageStrById(10520).."<color=#6BC74D>"..allData.fightTime.."</color>"
    this.tip2.text = GetLanguageStrById(10521).."<color=#6BC74D>"..allData.buyTime.."</color>"
    this.money.text = allData.money
end

function XinJiangLaiXi:SetTime()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    local timeDown = allData.endTime - GetTimeStamp()
    this.time.text = GetLanguageStrById(10470)..TimeToFelaxible(timeDown)
    self.timer = Timer.New(function()
        timeDown = timeDown - 1
        if timeDown < 1 then
            self.timer:Stop()
            self.timer = nil
            parent:ClosePanel()
            return
        end
        this.time.text = GetLanguageStrById(10470)..TimeToFelaxible(timeDown)
    end, 1, -1, true)
    self.timer:Start()
end

--界面打开时调用（用于子类重写）
function XinJiangLaiXi:OnOpen()

end

--商店
function XinJiangLaiXi:StoreShow()
    if not this.shopView then
        this.shopView = SubUIManager.Open(SubUIConfig.ShopView, this.content.transform)
    end
    this.shopView:ShowShop(SHOP_TYPE.XINJIANG_SHOP,sortingOrder)
    parent.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.XinJiangLaiXi })
end

function XinJiangLaiXi:OnClose()

end

--界面销毁时调用（用于子类重写）
function XinJiangLaiXi:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    if this.LiveObj then
        poolManager:UnLoadLive(this.LiveObj.name,this.LiveObj)
        this.LiveObj = nil
    end
    sortingOrder = 0
    itemsGrid = {}
end

function XinJiangLaiXi:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    if this.shopView then
        this.shopView = SubUIManager.Close(this.shopView)
        this.shopView = nil
    end
    sortingOrder = 0
end

return XinJiangLaiXi