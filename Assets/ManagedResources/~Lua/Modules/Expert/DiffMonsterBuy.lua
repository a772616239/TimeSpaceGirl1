local DiffMonsterBuy = quick_class("DiffMonsterBuy")
local this = DiffMonsterBuy

local diffMonsterBuyData = {}--异妖直购数据
local peijianTabs = {}--异妖直购
local diffItemTabs = {}--天恩神赐异妖获得物品
local rechargeCommodityConfig
function DiffMonsterBuy:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
local thisGo = nil
--初始化组件（用于子类重写）
function DiffMonsterBuy:InitComponent(gameObject)

    thisGo = gameObject
    this.diffMonsteIcon = Util.GetGameObject(gameObject, "activityIcon"):GetComponent("Image")
    this.diffMonsteTextIcon = Util.GetGameObject(gameObject, "activityTextIcon"):GetComponent("Image")
    this.diffMonsteNameBtn = Util.GetGameObject(gameObject, "nameBtn")
    this.diffMonsterNameBtnText = Util.GetGameObject(gameObject, "nameBtn/Text"):GetComponent("Text")
    this.diffMonsterBuyBtn = Util.GetGameObject(gameObject, "goJumpBtn")
    this.diffMonsterBuyBtnText = Util.GetGameObject(gameObject, "goJumpBtn/Text"):GetComponent("Text")
    this.diffMonsterTitleText = Util.GetGameObject(gameObject, "titleTextAndTime/Text"):GetComponent("Text")
    this.diffMonsterTimeText = Util.GetGameObject(gameObject, "titleTextAndTime/time"):GetComponent("Text")
    for i = 1, 4 do
        peijianTabs[i] = Util.GetGameObject(gameObject, "peijians/peijianFrame (" .. i .. ")")
    end
    diffItemTabs = {}
    for i = 1, 5 do
        diffItemTabs[i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(gameObject, "rect/grid").transform)
    end
end

--绑定事件（用于子类重写）
function DiffMonsterBuy:BindEvent()

end

--添加事件监听（用于子类重写）
function DiffMonsterBuy:AddListener()

end

--移除事件监听（用于子类重写）
function DiffMonsterBuy:RemoveListener()

end

--界面打开时调用（用于子类重写）
function DiffMonsterBuy:OnOpen(...)

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DiffMonsterBuy:OnShow()

    this:DiffMonsterBuy()
end
function DiffMonsterBuy:DiffMonsterBuy()
    --拍脸 异妖直购
    diffMonsterBuyData = nil
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.LoginPosterConfig)) do
        if v.Type == 2 then--异妖直购特殊处理
            if v.OpenRules[1] == 1 then
                if PlayerManager.level >= v.OpenRules[2] and PlayerManager.level <= v.CloseRules[2] then
                    local conFigData = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, v.ShopId)
                    local shopItemData = OperatingManager.GetGiftGoodsInfo(conFigData.Type,v.ShopId)
                    if shopItemData and diffMonsterBuyData == nil  then
                        diffMonsterBuyData = v
                    end
                end
            end
        end
    end
    if diffMonsterBuyData == nil then return end
    this.diffMonsteIcon.sprite = Util.LoadSprite(GetResourcePath(diffMonsterBuyData.Background))
    this.diffMonsteTextIcon.sprite = Util.LoadSprite(GetResourcePath(diffMonsterBuyData.BackgroundString))

    local differDemonsConFig = ConfigManager.GetConfigData(ConfigName.DifferDemonsConfig,diffMonsterBuyData.Values)
    rechargeCommodityConfig = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig,diffMonsterBuyData.ShopId)
    if rechargeCommodityConfig == nil or differDemonsConFig == nil  then return end
    local shopItemData = OperatingManager.GetGiftGoodsInfo(rechargeCommodityConfig.Type,rechargeCommodityConfig.Id)
    this.diffMonsterNameBtnText.text = differDemonsConFig.Name
    this.diffMonsterTitleText.text = GetLanguageStrById(diffMonsterBuyData.Desc)
    this.diffMonsterTimeText.text = GetLanguageStrById(10525)..PatFaceManager.GetTimeStrBySeconds(shopItemData.startTime).."-"..PatFaceManager.GetTimeStrBySeconds(shopItemData.endTime)
    if shopItemData.buyTimes <= 0 then
       
        this.diffMonsterBuyBtnText.text =MoneyUtil.GetMoney(diffMonsterBuyData.Btn)
    else
        this.diffMonsterBuyBtnText.text = GetLanguageStrById(10526)
    end
    for i = 1, 4 do
        if #rechargeCommodityConfig.RewardShow >= i then
            peijianTabs[i]:SetActive(true)
            local itemSId = rechargeCommodityConfig.RewardShow[i][1]
            local itemConfigData = ConfigManager.GetConfigData(ConfigName.ItemConfig,itemSId)
            Util.GetGameObject(peijianTabs[i].transform, "peijianIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
            Util.AddOnceClick(peijianTabs[i], function()
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemSId,nil)
            end)
        else
            peijianTabs[i]:SetActive(false)
        end
    end
    for i = 1, math.max(#diffItemTabs, #rechargeCommodityConfig.BaseReward) do
        local go = diffItemTabs[i]
        if not go then
            go = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(thisGo, "rect/grid").transform)
            diffItemTabs[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #rechargeCommodityConfig.BaseReward do
        diffItemTabs[i].gameObject:SetActive(true)
        diffItemTabs[i]:OnOpen(false,rechargeCommodityConfig.BaseReward[i],1,false,false,false,self.sortingOrder)
    end
    Util.AddOnceClick(this.diffMonsterBuyBtn, function()
        if shopItemData.buyTimes <= 0 then
            if AppConst.isSDKLogin then
                PayManager.Pay({ Id = rechargeCommodityConfig.Id }, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(rechargeCommodityConfig.Id)
                    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, rechargeCommodityConfig.Id)
                    this:DiffMonsterBuy()
                end)
            else

                NetManager.RequestBuyGiftGoods(rechargeCommodityConfig.Id, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(rechargeCommodityConfig.Id)
                    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, rechargeCommodityConfig.Id)
                    this:DiffMonsterBuy()
                end)
            end
        end
    end)
    Util.AddOnceClick(this.diffMonsteNameBtn, function()
        UIManager.OpenPanel(UIName.PatFaceDiffMonsterInfoPanel,diffMonsterBuyData.Values)
    end)
end
--界面关闭时调用（用于子类重写）
function DiffMonsterBuy:OnClose()

end

--界面销毁时调用（用于子类重写）
function DiffMonsterBuy:OnDestroy()

end

return DiffMonsterBuy