
local LifelongLimitBuy = quick_class("LifelongLimitBuy")

function LifelongLimitBuy:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
    self.preList = {}
    self.ItemList = {}
end

-- 初始化组件
function LifelongLimitBuy:InitComponent(gameObject)
    self.content = Util.GetGameObject(gameObject, "content/rect/grid")
    self.pre = Util.GetGameObject(gameObject, "content/rect/grid/rewardPre")
end

function LifelongLimitBuy:BindEvent()

end

function LifelongLimitBuy:AddEvent()
end

function LifelongLimitBuy:RemoveEvent()
end

function LifelongLimitBuy:OnShow(parentSorting, arg, pageIndex) 
    self.gameObject:SetActive(true)

    self:RefreshList()
end

function LifelongLimitBuy:RefreshList()
    local config = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity, "Type", ActivityTypeDef.LifeMemeber)
    if not config then
        self.gameObject:SetActive(false)
        return
    end
    local canBuyRechargeId = config.CanBuyRechargeId
    for i = 1, #canBuyRechargeId do
        local config = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, canBuyRechargeId[i])

        local go = self.preList[i]
        if not go then
            go = newObject(self.pre)
            go.transform:SetParent(self.content.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            self.preList[i] = go
        end
        self:FillPreData(go, config)
    end
end

function LifelongLimitBuy:FillPreData(go, data)
    go:SetActive(true)
    local title = Util.GetGameObject(go, "title/Text"):GetComponent("Text")
    local itemGrid = Util.GetGameObject(go, "content")
    local progress = Util.GetGameObject(go, "progress"):GetComponent("Text")
    local btn = Util.GetGameObject(go, "btn")
    local price = Util.GetGameObject(go, "btn/Text"):GetComponent("Text")
    local originalPrice = Util.GetGameObject(go, "originalPrice"):GetComponent("Text")
    local redpoint = Util.GetGameObject(go, "btn/redPoint")
    local limit = Util.GetGameObject(go, "limit")
    local limitText = Util.GetGameObject(go, "limit/Text"):GetComponent("Text")

    title.text = GetLanguageStrById(data.Name)
    local boughtNum = OperatingManager.GetGoodsBuyTime(data.Type, data.Id) or 0
    progress.text = GetLanguageStrById(11451).."("..boughtNum.."/"..data.Limit..")"
    price.text = MoneyUtil.GetMoney(data.Price)
    originalPrice.gameObject:SetActive(data.IsDiscount ~= 0)
    originalPrice.text = GetLanguageStrById(10537)..MoneyUtil.GetCurrencyUnit()..data.Price/(data.IsDiscount*0.1)
    local isCanBuy = data.Limit - boughtNum > 0
    Util.SetGray(btn, not isCanBuy)
    redpoint:SetActive(data.Price == 0)

    if self.ItemList[go] then
        for i = 1, #data.RewardShow do
            self.ItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #data.RewardShow do
            if self.ItemList[go][i] then
                self.ItemList[go][i]:OnOpen(false, {data.RewardShow[i][1],data.RewardShow[i][2]}, 0.65)
                self.ItemList[go][i].gameObject:SetActive(true)
            end
        end
    else
        self.ItemList[go] = {}
        for i = 1, #data.RewardShow do
            self.ItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGrid.transform)
            self.ItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #data.RewardShow do
            self.ItemList[go][i]:OnOpen(false, {data.RewardShow[i][1],data.RewardShow[i][2]}, 0.65)
            self.ItemList[go][i].gameObject:SetActive(true)
        end
    end
    
    limit:SetActive(PlayerManager.level < data.LevelLinit[1])
    limitText.text = string.format(GetLanguageStrById(11472), data.LevelLinit[1])..GetLanguageStrById(10072)..GetLanguageStrById(12020)

    limit:SetActive(PlayerManager.level < data.LevelLinit[1])
    limitText.text = string.format(GetLanguageStrById(11472), data.LevelLinit[1])..GetLanguageStrById(10072)..GetLanguageStrById(12020)

    Util.AddOnceClick(btn, function()
        if PlayerManager.level < data.LevelLinit[1] then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10340),data.LevelLinit[1]))
        end
        if not isCanBuy then
            PopupTipPanel.ShowTipByLanguageId(10540)
        else
            --直购商品
            if AppConst.isSDKLogin then
                PayManager.Pay({ Id = data.Id }, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(data.Id)
                    self:RefreshList()
                end)
            else
                NetManager.RequestBuyGiftGoods(data.Id, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(data.Id)
                    self:RefreshList()
                end)
            end
        end
    end)
end

function LifelongLimitBuy:OnHide()
    self.gameObject:SetActive(false)
end

return LifelongLimitBuy