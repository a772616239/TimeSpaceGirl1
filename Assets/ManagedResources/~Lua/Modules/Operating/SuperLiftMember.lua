local SuperLiftMember = quick_class("SuperLiftMember")
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local item = nil
function SuperLiftMember:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

-- 初始化组件
function SuperLiftMember:InitComponent(gameObject)
    self.timePos = Util.GetGameObject(gameObject, "itemPos")
    self.btnBuy = Util.GetGameObject(gameObject, "btnBuy")
    self.btnFree = Util.GetGameObject(gameObject, "btnFree")
    self.rewardNum = Util.GetGameObject(gameObject, "txt_RewardNum"):GetComponent("Text")
    self.cumulativeGo = Util.GetGameObject(gameObject, "cumulative")
    self.cumulative = Util.GetGameObject(gameObject, "cumulative/Text"):GetComponent("Text")
    self.received = Util.GetGameObject(gameObject, "received")
    self.txt_des1 = Util.GetGameObject(gameObject, "txt_des1"):GetComponent("Text")
    self.txt_des2 = Util.GetGameObject(gameObject, "txt_des2"):GetComponent("Text")
end

function SuperLiftMember:BindEvent()
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

function SuperLiftMember:AddEvent()
end

function SuperLiftMember:RemoveEvent()
end

function SuperLiftMember:OnShow(parentSorting, arg, pageIndex)
    item = nil
    CheckRedPointStatus(RedPointType.SuperLiftMemberEveryDay)
    CheckRedPointStatus(RedPointType.SuperLiftMemberFree)

    self.txt_des1.text = GetLanguageStrById(50268)
    self.txt_des2.text = GetLanguageStrById(50269)

    self.gameObject:SetActive(true)
    local activityConfig = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity, "Type", ActivityTypeDef.SuperLifeMemebr)
    local rechargeId = activityConfig.CanBuyRechargeId[1]
    self.activityId = activityConfig.Id

    --立得
    self.rechargConfig = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, rechargeId)
    self.rewardNum.text = self.rechargConfig.RewardShow[1][2]

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

function SuperLiftMember:RefreshBtn()
    local boughtNum = OperatingManager.GetGoodsBuyTime(self.rechargConfig.Type, self.rechargConfig.Id) or 0
    self.isCanBuy = self.rechargConfig.Limit - boughtNum > 0
    --self.reward:SetActive(self.isCanBuy)
    self.btnBuy:GetComponent("Button").enabled = true
    if self.isCanBuy then
        Util.GetGameObject(self.btnBuy, "redpoint"):SetActive(false)
        self.received:SetActive(false)
        Util.SetGray(self.btnBuy, false)
        Util.GetGameObject(self.btnBuy, "Text"):GetComponent("Text").text = GetLanguageStrById(50202)..MoneyUtil.GetMoney(self.rechargConfig.Price)
    else
        local state = ActivityGiftManager.SuperLifeMemberRedPoint()
        Util.GetGameObject(self.btnBuy, "redpoint"):SetActive(state)
        self.txt_des2.gameObject:SetActive(state)
        Util.SetGray(self.btnBuy, not state)
        self.received:SetActive(not state)
        if state then
            Util.GetGameObject(self.btnBuy, "Text"):GetComponent("Text").text = GetLanguageStrById(91000003)
        else
            self.btnBuy:GetComponent("Button").enabled = false
            Util.GetGameObject(self.btnBuy, "Text"):GetComponent("Text").text = GetLanguageStrById(10350)
        end
    end
end

function SuperLiftMember:RefreshGift()
    if self.isCanBuy then
        self.cumulativeGo:SetActive(true)
        local time = GetDataToDataBetweenDays(ActTimeCtrlManager.serTime, PlayerManager.userCreateTime)
        self.cumulative.text = GetLanguageStrById(11476) ..":".. GetLanguageStrById(itemConfig[self.rewardConfig[1].Reward[1][1]].Name).."x".. time*self.rewardConfig[2].Reward[1][2]
    else
        self.cumulativeGo:SetActive(false)
    end
end

function SuperLiftMember:RefreshFreeGift()
    local state = ActivityGiftManager.SuperLifeMemberFreeRedPoint()
    Util.SetGray(self.btnFree, not state)
    Util.GetGameObject(self.btnFree, "received"):SetActive(not state)
    Util.GetGameObject(self.btnFree, "redpoint"):SetActive(state)
    self.btnFree:GetComponent("Button").enabled = state
end

function SuperLiftMember:OnHide()
    self.gameObject:SetActive(false)
end


function SuperLiftMember:ClosePanel()
    self.gameObject:SetActive(false)
end

return SuperLiftMember