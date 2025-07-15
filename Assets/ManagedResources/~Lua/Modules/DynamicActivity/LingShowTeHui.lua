local LingShowTeHui = quick_class("LingShowTeHui")
local allData = {}
local itemsGrid = {}--item重复利用
local this = LingShowTeHui
local parent = {}
local spiritAnimalConfig = ConfigManager.GetConfig(ConfigName.SpiritAnimal)
local rechargeConfigId = 0
local rechargeData = {}
local itemViewList = {}
function LingShowTeHui:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

function LingShowTeHui:InitComponent(gameObject)
    this.time = Util.GetGameObject(gameObject, "time/times"):GetComponent("Text")
    this.buyBtn = Util.GetGameObject(gameObject, "layout/buyBtn")
    this.scrollItem = Util.GetGameObject(gameObject, "scroller/grid")
    this.buytimes = Util.GetGameObject(gameObject, "layout/buytimes"):GetComponent("Text")  
    this.giftItemView = {}
    for i = 1, 4 do
        this.giftItemView[i] = Util.GetGameObject(gameObject, "layout/obj"..i)
    end
end

--绑定事件（用于子类重写）
function LingShowTeHui:BindEvent()
    Util.AddClick(this.buyBtn,function()
        if rechargeData.buyTimes >= rechargeData.dynamicBuyTimes then
            return
        end
        --直购商品
        PayManager.Pay(rechargeConfigId, function(id)
            this.RechargeSuccessFunc(id)
        end)
    end)
end
function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    this:OnShowData()
end
--添加事件监听（用于子类重写）
function LingShowTeHui:AddListener()
end

--移除事件监听（用于子类重写）
function LingShowTeHui:RemoveListener()
end

local sortingOrder = 0
--界面打开时调用（用于子类重写）
function LingShowTeHui:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LingShowTeHui:OnShow(_sortingOrder,_parent)
    parent = _parent
    sortingOrder = _sortingOrder
    this:OnShowData()
    LingShowTeHui:SetTime()
end
local FrameSprite = {
    [3] = "l_lishoutehui_ziyuan",
    [4] = "l_lishoutehui_ziyuan",
    [5] = "l_lishoutehui_huangyuan",
}
function LingShowTeHui:OnShowData()
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LingShowTeHui)
    local activityConfig = ConfigManager.GetConfigData(ConfigName.GlobalActivity,activityId)
    rechargeConfigId = activityConfig.CanBuyRechargeId[1]
    allData = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig,rechargeConfigId)
    if not itemsGrid then
        itemsGrid = {}
    end
    for k,v in ipairs(itemsGrid) do       
        v.gameObject:SetActive(false)
    end
    for k,v in ipairs(allData.RewardShow) do       
        if not itemsGrid[k] then
            itemsGrid[k] = SubUIManager.Open(SubUIConfig.ItemView,this.scrollItem.transform)
        end
        itemsGrid[k].gameObject:SetActive(true)
        itemsGrid[k]:OnOpen(false, {v[1],v[2]}, 1,false,false,false,sortingOrder)
    end

    for _,v in pairs(this.giftItemView) do
        v.gameObject:SetActive(false)
    end

    local strs = string.split(activityConfig.ExpertDec,'#')    
    for i = 1 ,#strs do
        local itemLocalConfig = spiritAnimalConfig[tonumber(strs[i])]
        if not itemLocalConfig then
            if this.giftItemView[i] then
                this.giftItemView[i].gameObject:SetActive(false)
            end
        else
            if this.giftItemView[i] then
                this.giftItemView[i].gameObject:SetActive(true)
                this.giftItemView[i]:GetComponent("Image").sprite = Util.LoadSprite(FrameSprite[itemLocalConfig.Quality])
                if not itemViewList then
                    itemViewList = {}
                end
                if not itemViewList[i] then
                    itemViewList[i] = SubUIManager.Open(SubUIConfig.ItemView,this.giftItemView[i].transform)
                end
                itemViewList[i].gameObject:SetActive(true)
                itemViewList[i].gameObject:GetComponent("RectTransform").anchoredPosition = Vector3.New(0,0,0)
                itemViewList[i]:OnOpen(false, {itemLocalConfig.Id,0}, 1,false,false,false,sortingOrder)
            end
        end
        
    end

    rechargeData = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.DirectPurchaseGift, rechargeConfigId)
    if rechargeData then
        this.buytimes.text = string.format(GetLanguageStrById(12341), (rechargeData.dynamicBuyTimes - rechargeData.buyTimes))
    else
        
    end
end

function LingShowTeHui:SetTime()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    local endTime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.LingShowTeHui)
    local timeDown = endTime - GetTimeStamp()
    this.time.text = GetLanguageStrById(12321)..TimeToDHMS(timeDown)
    self.timer = Timer.New(function()
        timeDown = timeDown - 1
        if timeDown < 1 then
            self.timer:Stop()
            self.timer = nil
            this.time.text = GetLanguageStrById(12321)..TimeToDHMS(0)
        end
        this.time.text = GetLanguageStrById(12321)..TimeToDHMS(timeDown)
    end, 1, -1, true)
    self.timer:Start()
end

function LingShowTeHui:OnClose()

end

--界面销毁时调用（用于子类重写）
function LingShowTeHui:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
    itemsGrid = {}
    itemViewList = {}
end

function LingShowTeHui:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
end

return LingShowTeHui