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
    this.timeGo = Util.GetGameObject(gameObject, "timeText")
    this.timeTxt = Util.GetGameObject(gameObject, "timeText"):GetComponent("Text")
    this.exChangeRewardIcon = Util.GetGameObject(gameObject, "downbg1/info/itemViewParent/icon"):GetComponent("Image")
    this.exChangeRewardParent = Util.GetGameObject(gameObject, "downbg2/itemRewardParent")

    this.exChangeBuyNum = Util.GetGameObject(gameObject, "downbg2/buyInfo/buyNum"):GetComponent("Text")
    this.exChangeBuyIcon = Util.GetGameObject(gameObject, "downbg2/buyInfo/icon"):GetComponent("Image")
    this.exChangeBuyBtn = Util.GetGameObject(gameObject, "downbg2/buyInfo/addBtn")

    for i = 1, 4 do
        exChangeInfoGrid[i] = Util.GetGameObject(gameObject, "downbg1/info/infoTextGrid/infoText ("..i..")")
    end
    this.exChangeGoBtn = Util.GetGameObject(gameObject, "downbg2/goBtn")
    this.click = Util.GetGameObject(gameObject, "leftUpGO/click")

    this.live2dRoot = Util.GetGameObject(gameObject, "bg/live")
    this.profession = Util.GetGameObject(gameObject, "leftUpGO/posImage/posImage"):GetComponent("Image")
    this.proImage = Util.GetGameObject(gameObject, "leftUpGO/proImage"):GetComponent("Image")
    this.heroName = Util.GetGameObject(gameObject, "leftUpGO/heroName"):GetComponent("Text")
    this.quality = Util.GetGameObject(gameObject, "leftUpGO/Natural"):GetComponent("Text")
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
    itemList = {}
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
-- this.liveNode = nil
-- this.liveName = nil
function ExChange:ExChangeShow()
    local LimitExchange = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LimitExchange)
    if LimitExchange then
        local str = GetLanguageStrById(11496)
        
        PatFaceManager.RemainTimeDown2(this.timeGo, this.timeTxt, LimitExchange.endTime - GetTimeStamp(),str)
    else
        this.timeGo:SetActive(false)
    end

    local exChangeConFig = ConfigManager.GetConfigDataByKey(ConfigName.ExchangeActivityConfig, "ActivityId", LimitExchange.activityId)
    heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig,exChangeConFig.AwardHeroId)

    -- if this.liveNode then
    --     poolManager:UnLoadLive(this.liveName, this.liveNode)
    --     this.liveNode = nil
    -- end
    -- this.liveName = GetResourcePath(heroConfig.Live)
    -- this.liveNode = poolManager:LoadLive(this.liveName, this.live2dRoot.transform, 
    --     Vector3.one * exChangeConFig.HeroShowScale, Vector3.New(exChangeConFig.HeroShowLocation[1], exChangeConFig.HeroShowLocation[2],0))
    if this.liveNode then
        UnLoadHerolive(this.config, this.liveNode)
        Util.ClearChild(this.live2dRoot.transform)
    end
    this.config = heroConfig
    this.liveNode = LoadHerolive(this.config, this.live2dRoot.transform)

    this.profession.sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(heroConfig.Profession))
    this.proImage.sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
    this.heroName.text = GetLanguageStrById(heroConfig.ReadingName)
    this.quality.text = heroConfig.Natural

    --Util.ClearChild(this.exChangeRewardParent.transform)
    for i = 1, #exChangeConFig.ShowItem do
        local rewardInfo = {exChangeConFig.ShowItem[i],0}
        if itemList[i] then
            itemList[i]:OnOpen(false,rewardInfo,1.1,false,false,false,sortingOrder)
        else
            itemList[i] = SubUIManager.Open(SubUIConfig.ItemView,  this.exChangeRewardParent.transform)
            itemList[i]:OnOpen(false,rewardInfo,1.1,false,false,false,sortingOrder)
        end
    end
    local itemConFig = ConfigManager.GetConfigData(ConfigName.ItemConfig,exChangeConFig.ActivityItem)
    this.exChangeRewardIcon.sprite = Util.LoadSprite(GetResourcePath(itemConFig.ResourceID))

    this.exChangeBuyNum.text = PrintWanNum(BagManager.GetItemCountById(exChangeConFig.ActivityItem))
    this.exChangeBuyIcon.sprite = Util.LoadSprite(GetResourcePath(itemConFig.ResourceID))
    local descTabs = string.split( exChangeConFig.Desc,"#")
    for i = 1, #exChangeInfoGrid do
        if #descTabs >= i then
            exChangeInfoGrid[i]:SetActive(true)
            exChangeInfoGrid[i]:GetComponent("Text").text = "·"..descTabs[i]
        else
            exChangeInfoGrid[i]:SetActive(false)
        end
    end
    Util.AddOnceClick(this.exChangeBuyBtn, function()
        JumpManager.GoJump(exChangeConFig.ItemJump)
    end)
    Util.AddOnceClick(this.exChangeGoBtn, function()
        local exChangeConFig = ConfigManager.GetConfigData(ConfigName.ExchangeActivityConfig,1)
        if not ShopManager.IsActive(exChangeConFig.ShopId) then
            PopupTipPanel.ShowTipByLanguageId(10528)
            return
        end
        UIManager.OpenPanel(UIName.MainShopPanel,exChangeConFig.ShopId)
    end)
end
--界面关闭时调用（用于子类重写）
function ExChange:OnClose()
    -- if this.liveNode then
    --     poolManager:UnLoadLive(this.liveName, this.liveNode)
    --     this.liveNode = nil
    --     this.liveName = nil
    -- end
    if this.liveNode then
        UnLoadHerolive(this.config, this.liveNode)
        Util.ClearChild(this.live2dRoot.transform)
    end
end

function ExChange:OnHide()
    -- if this.liveNode then
    --     poolManager:UnLoadLive(this.liveName, this.liveNode)
    --     this.liveNode = nil
    --     this.liveName = nil
    -- end
    if this.liveNode then
        UnLoadHerolive(this.config, this.liveNode)
        Util.ClearChild(this.live2dRoot.transform)
    end
end
--界面销毁时调用（用于子类重写）
function ExChange:OnDestroy()
    itemList = {}
end

return ExChange