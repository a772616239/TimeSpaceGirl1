local ExChange = quick_class("ExChange")
local this = ExChange

local exChangeInfoGrid = {}--限时兑换内容
local heroConfig
local itemList = {}  --itemView优化
local cursortingOrder

function ExChange:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
--初始化组件（用于子类重写）
function ExChange:InitComponent(gameObject)
    this.timeTextExChangeGo = Util.GetGameObject(gameObject, "time/timeText")
    this.timeTextExChange = Util.GetGameObject(gameObject, "timeText"):GetComponent("Text")
    -- this.exChangeRewardIcon = Util.GetGameObject(gameObject, "downbg1/info/itemViewParent/icon"):GetComponent("Image")
    this.exChangeRewardParent = Util.GetGameObject(gameObject, "itemRewardParent")

    this.exChangeBuyNum = Util.GetGameObject(gameObject, "buyInfo/buyNum"):GetComponent("Text")
    this.exChangeBuyIcon = Util.GetGameObject(gameObject, "buyInfo/icon"):GetComponent("Image")
    this.exChangeBuyBtn = Util.GetGameObject(gameObject, "buyInfo/addBtn")

    for i = 1, 4 do
        exChangeInfoGrid[i] = Util.GetGameObject(gameObject, "downbg/info/infoTextGrid/infoText ("..i..")")
    end
    this.exChangeGoBtn = Util.GetGameObject(gameObject, "goBtn")
end

--绑定事件（用于子类重写）
function ExChange:BindEvent()
    Util.AddClick(this.click, function()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroConfig.Id, heroConfig.Star)
    end)
end

--添加事件监听（用于子类重写）
function ExChange:AddListener()
end

--移除事件监听（用于子类重写）
function ExChange:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ExChange:OnOpen(...)
end

local sortingOrder = 0
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ExChange:OnShow(_sortingOrder)
    sortingOrder = _sortingOrder
    this:ExChangeShow()
end

function ExChange:OnSortingOrderChange(_cursortingOrder)
    cursortingOrder = _cursortingOrder
    for i, v in pairs(itemList) do
        v:SetEffectLayer(cursortingOrder)
    end
end

--限时兑换活动
function ExChange:ExChangeShow()
    local LimitExchange = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LimitExchange)
    if LimitExchange then
        CardActivityManager.TimeDown(this.timeTextExChange, LimitExchange.endTime - GetTimeStamp())
    end

    -- LogError("活动ID："..LimitExchange.activityId)
    local exChangeConFig = ConfigManager.GetConfigDataByKey(ConfigName.ExchangeActivityConfig, "ActivityId", LimitExchange.activityId)
    heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig,exChangeConFig.AwardHeroId)

    for i = 1, #exChangeConFig.ShowItem do
        local rewardInfo = {exChangeConFig.ShowItem[i],0}
        if itemList[i] then
            itemList[i]:OnOpen(false,rewardInfo,0.85)
        else
            itemList[i] = SubUIManager.Open(SubUIConfig.ItemView,  this.exChangeRewardParent.transform)
            itemList[i]:OnOpen(false,rewardInfo,0.85)
        end
    end
    local itemConFig = ConfigManager.GetConfigData(ConfigName.ItemConfig,exChangeConFig.ActivityItem)
    -- this.exChangeRewardIcon.sprite = Util.LoadSprite(GetResourcePath(itemConFig.ResourceID))
    this.exChangeBuyNum.text = PrintWanNum(BagManager.GetItemCountById(exChangeConFig.ActivityItem))
    this.exChangeBuyIcon.sprite = Util.LoadSprite(GetResourcePath(itemConFig.ResourceID))
    local descTabs = string.split( exChangeConFig.Desc,"#")
    for i = 1, #exChangeInfoGrid do
        if #descTabs >= i then
            exChangeInfoGrid[i]:SetActive(true)
            exChangeInfoGrid[i]:GetComponent("Text").text = "·"..GetLanguageStrById(descTabs[i])
        else
            exChangeInfoGrid[i]:SetActive(false)
        end
    end
    Util.AddOnceClick(this.exChangeBuyBtn, function()
        JumpManager.GoJump(exChangeConFig.ItemJump)
    end)
    Util.AddOnceClick(this.exChangeGoBtn, function()
        local exChangeConFig = ConfigManager.GetConfigData(ConfigName.ExchangeActivityConfig,1)
        -- if not ShopManager.IsActive(exChangeConFig.ShopId) then
        --     PopupTipPanel.ShowTipByLanguageId(10528)
        --     return
        -- end
        -- local exChangeConFig = ConfigManager.GetConfigDataByKey(ConfigName.ExchangeActivityConfig, "ActivityId", LimitExchange.activityId)
        if ShopManager.GetShopDataByType(exChangeConFig.ShopId) == nil then
            PopupTipPanel.ShowTipByLanguageId(10528)
            return
        end
        UIManager.OpenPanel(UIName.MapShopPanel, exChangeConFig.ShopId)
    end)
end
--界面关闭时调用（用于子类重写）
function ExChange:OnClose()
    CardActivityManager.StopTimeDown()
end

--界面销毁时调用（用于子类重写）
function ExChange:OnDestroy()
    itemList = {}
end

return ExChange