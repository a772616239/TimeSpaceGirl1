local LifeMember = quick_class("LifeMember")
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local item = nil
function LifeMember:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

-- 初始化组件
function LifeMember:InitComponent(gameObject)
    self.timePos = Util.GetGameObject(gameObject, "itemPos")
    self.btnBuy = Util.GetGameObject(gameObject, "btnBuy")
    self.btnFree = Util.GetGameObject(gameObject, "btnFree")
    self.reward = Util.GetGameObject(gameObject, "reward")
    self.cumulativeGo = Util.GetGameObject(gameObject, "cumulative")
    self.cumulative = Util.GetGameObject(gameObject, "cumulative/Text"):GetComponent("Text")
    self.received = Util.GetGameObject(gameObject, "received")
end

function LifeMember:BindEvent()
    Util.AddClick(self.btnBuy, function ()
        if self.isCanBuy then
            if AppConst.isSDKLogin then
                PayManager.Pay({ Id = self.rechargConfig.Id }, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(self.rechargConfig.Id)
                    self:OnShow()
                end)
            else
                NetManager.RequestBuyGiftGoods(self.rechargConfig.Id, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(self.rechargConfig.Id)
                    self:OnShow()
                end)
            end
        else
            NetManager.GetActivityRewardRequest(self.rewardConfig[1].Id, self.activityId, function(drop)
                UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function()
                    self:OnShow()
                end)
            end)
        end
    end)
    Util.AddClick(self.btnFree, function ()
        NetManager.GetActivityRewardRequest(self.rewardConfig[2].Id, self.activityId, function(drop)
            UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1, function()
                self:OnShow()
            end)
        end)
    end)
end

function LifeMember:AddEvent()
end

function LifeMember:RemoveEvent()
end

function LifeMember:OnShow(parentSorting, arg, pageIndex)
    item = nil
    CheckRedPointStatus(RedPointType.LifeMemeberEveryDay)
    CheckRedPointStatus(RedPointType.LifeMemeberFree)
    self.gameObject:SetActive(true)
    local activityConfig = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity, "Type", ActivityTypeDef.LifeMemebr)
    local rechargeId = activityConfig.CanBuyRechargeId[1]
    self.activityId = activityConfig.Id

    --立得
    self.rechargConfig = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, rechargeId)
    Util.GetGameObject(self.reward, "Image"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[self.rechargConfig.RewardShow[1][1]].ResourceID))
    Util.GetGameObject(self.reward, "Text"):GetComponent("Text").text = self.rechargConfig.RewardShow[1][2]

    --每日获得
    self.rewardConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", self.activityId)
    for i = 1, #self.rewardConfig do
        if self.rewardConfig[i].Values[2][1] == 1 then
            Util.ClearChild(self.timePos.transform)
            if not item then
                item = SubUIManager.Open(SubUIConfig.ItemView, self.timePos.transform)
            end
            item:OnOpen(false, {self.rewardConfig[i].Reward[1][1], self.rewardConfig[i].Reward[1][2]}, 0.8)
            item.gameObject:SetActive(true)
        end
    end

    self:RefreshBtn()
    self:RefreshGift()
    self:RefreshFreeGift()
end

function LifeMember:RefreshBtn()
    local boughtNum = OperatingManager.GetGoodsBuyTime(self.rechargConfig.Type, self.rechargConfig.Id) or 0
    self.isCanBuy = self.rechargConfig.Limit - boughtNum > 0
    self.reward:SetActive(self.isCanBuy)
    self.btnBuy:GetComponent("Button").enabled = true
    if self.isCanBuy then
        Util.GetGameObject(self.btnBuy, "redpoint"):SetActive(false)
        self.received:SetActive(false)
        Util.SetGray(self.btnBuy, false)
        Util.GetGameObject(self.btnBuy, "Text"):GetComponent("Text").text = GetLanguageStrById(50202)..MoneyUtil.GetMoney(self.rechargConfig.Price)
    else
        local state = ActivityGiftManager.LifeMemberRedPoint()
        Util.GetGameObject(self.btnBuy, "redpoint"):SetActive(state)
        Util.SetGray(self.btnBuy, not state)
        self.received:SetActive(not state)
        if state then
            Util.GetGameObject(self.btnBuy, "Text"):GetComponent("Text").text = GetLanguageStrById(50318)
        else
            self.btnBuy:GetComponent("Button").enabled = false
            Util.GetGameObject(self.btnBuy, "Text"):GetComponent("Text").text = GetLanguageStrById(10350)
        end
    end
end

function LifeMember:RefreshGift()
    if self.isCanBuy then
        self.cumulativeGo:SetActive(true)
        local time = GetDataToDataBetweenDays(ActTimeCtrlManager.serTime, PlayerManager.userCreateTime)
        self.cumulative.text = GetLanguageStrById(11476) ..":".. GetLanguageStrById(itemConfig[self.rewardConfig[1].Reward[1][1]].Name).."x".. time*self.rewardConfig[2].Reward[1][2]
    else
        self.cumulativeGo:SetActive(false)
    end
end

function LifeMember:RefreshFreeGift()
    local state = ActivityGiftManager.LifeMemberFreeRedPoint()
    Util.SetGray(self.btnFree, not state)
    Util.GetGameObject(self.btnFree, "received"):SetActive(not state)
    Util.GetGameObject(self.btnFree, "redpoint"):SetActive(state)
    self.btnFree:GetComponent("Button").enabled = state
end

function LifeMember:OnHide()
    self.gameObject:SetActive(false)
end

function LifeMember:ClosePanel()
    self.gameObject:SetActive(false)
end

return LifeMember