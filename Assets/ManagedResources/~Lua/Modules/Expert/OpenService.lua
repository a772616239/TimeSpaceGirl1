local OpenService = quick_class("OpenService")

function OpenService:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
    self.preList = {}
    self.ItemList = {}
end
--初始化组件（用于子类重写）
function OpenService:InitComponent(gameObject)
    self.content = Util.GetGameObject(gameObject, "content/rect/grid")
    self.pre = Util.GetGameObject(gameObject, "content/rect/grid/rewardPre")
    self.endTime = Util.GetGameObject(gameObject, "Image/endTime"):GetComponent("Text")
    self.endTimeBg = Util.GetGameObject(gameObject, "Image")
end

--绑定事件（用于子类重写）
function OpenService:BindEvent()
end

--添加事件监听（用于子类重写）
function OpenService:AddListener()
end

--移除事件监听（用于子类重写）
function OpenService:RemoveListener()
end

--界面打开时调用（用于子类重写）
function OpenService:OnOpen(...)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function OpenService:OnShow()
    self:RefreshList()
end

--界面关闭时调用（用于子类重写）
function OpenService:OnClose()
end

--界面销毁时调用（用于子类重写）
function OpenService:OnDestroy()
end

function OpenService:RefreshList()
    CheckRedPointStatus(RedPointType.OpenService)
    local gift = {}
    local globalActivityConfig = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity, "Type", 10020)
    for i = 1, #globalActivityConfig.CanBuyRechargeId do
        local config = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, globalActivityConfig.CanBuyRechargeId[i])
        table.insert(gift, config)
    end

    table.sort(gift, function(a, b)
        local aBoughtNum = OperatingManager.GetGoodsBuyTime(a.Type, a.Id) or 0
        local aCanBuy = a.Limit - aBoughtNum > 0
        local bBoughtNum = OperatingManager.GetGoodsBuyTime(b.Type, b.Id) or 0
        local bCanBuy = b.Limit - bBoughtNum > 0
        if not aCanBuy and not bCanBuy then
            return a.Id < b.Id
        elseif not aCanBuy or not bCanBuy then
            return (a.Limit - aBoughtNum) > (b.Limit - bBoughtNum)
        else--if aCanBuy and bCanBuy then
            return a.Id < b.Id
        end
    end)

    for i = 1,#gift do
        local go = self.preList[i]
        if not go then
            go = newObject(self.pre)
            go.transform:SetParent(self.content.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            self.preList[i] = go
        end
        self:FillPreData(go, gift[i])
    end

    local endTime = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.OpenService).endTime
    PatFaceManager.RemainTimeDown2(self.endTimeBg, self.endTime, endTime - GetTimeStamp(), GetLanguageStrById(12547))
end

function OpenService:FillPreData(go, data)
    go:SetActive(true)
    local title = Util.GetGameObject(go, "title/Text"):GetComponent("Text")
    local itemGrid = Util.GetGameObject(go, "content")
    local progress = Util.GetGameObject(go, "progress"):GetComponent("Text")
    local btn = Util.GetGameObject(go, "btn")
    local price = Util.GetGameObject(go, "btn/Text"):GetComponent("Text")
    local originalPrice = Util.GetGameObject(go, "originalPrice"):GetComponent("Text")
    local redpoint = Util.GetGameObject(go, "btn/redPoint")

    title.text = GetLanguageStrById(data.Name)
    local boughtNum = OperatingManager.GetGoodsBuyTime(data.Type, data.Id) or 0
    progress.text = GetLanguageStrById(11451).."("..boughtNum.."/"..data.Limit..")"
    price.text = MoneyUtil.GetMoney(data.Price)
    originalPrice.gameObject:SetActive(data.IsDiscount ~= 0)
    originalPrice.text = GetLanguageStrById(10537)..MoneyUtil.GetCurrencyUnit()..MoneyUtil.GetPrice(data.Price)/(data.IsDiscount*0.1)
    local isCanBuy = data.Limit - boughtNum > 0
    Util.SetGray(btn, not isCanBuy)
    redpoint:SetActive(data.Price == 0 and isCanBuy)

    if self.ItemList[go] then
        for i = 1, #self.ItemList[go] do
            if not self.ItemList[go][i] then
                self.ItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGrid.transform)
            end
            self.ItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #data.RewardShow do
            if self.ItemList[go][i] then
                self.ItemList[go][i]:OnOpen(false, {data.RewardShow[i][1],data.RewardShow[i][2]}, 0.6)
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
            self.ItemList[go][i]:OnOpen(false, {data.RewardShow[i][1],data.RewardShow[i][2]}, 0.6)
            self.ItemList[go][i].gameObject:SetActive(true)
        end
    end

    Util.AddOnceClick(btn, function()
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

return OpenService