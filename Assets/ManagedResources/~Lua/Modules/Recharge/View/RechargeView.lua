local RechargeView = quick_class("RechargeView")
local vipLevelConfig = ConfigManager.GetConfig(ConfigName.VipLevelConfig)
function RechargeView:ctor(rootView, gameObject)
    self.rootView = rootView
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
    self.ItemList = {}
    self.NoviceItemList = {}
end

function RechargeView:InitComponent(gameObject)
    self.shopViewRoot = Util.GetGameObject(gameObject, "root")
    -- 显示特权信息
    self.vipInfoPart = Util.GetGameObject(gameObject, "VipInfoPart")
    self.vipIconLevel = Util.GetGameObject(self.vipInfoPart, "vipIcon/num"):GetComponent("Text")

    -- 进度
    self.vipProgress = Util.GetGameObject(self.vipInfoPart, "Slider/fill"):GetComponent("Image")
    self.progressText = Util.GetGameObject(self.vipInfoPart, "Slider/value"):GetComponent("Text")
end

function RechargeView:BindEvent()
end

function RechargeView:OnShow()
    NetManager.RequestVipLevelUp(function()end)--提升等级
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, self.SetVipPartInfo, self)

    if not self.shopView then
        self.shopView = SubUIManager.Open(SubUIConfig.ShopView, self.shopViewRoot.transform, self.shopViewRoot)
        -- self.shopView:SetItemContentPosition(Vector3.New(0, 710, 0))
    end
    self.shopView:ShowShop(50000, self.rootView.sortingOrder)
    
    self:SetVipPartInfo()
end

function RechargeView:AddListener()
end

function RechargeView:RemoveListener()
end

-- 设置特权面板数据
function RechargeView:SetVipPartInfo()
    local need, nextLevelNeed = VipManager.GetNextLevelNeed()
    local nextLevel = VipManager.GetVipLevel() + 1
    nextLevel = nextLevel > VipManager.GetMaxVipLevel() and VipManager.GetMaxVipLevel() or nextLevel

    self.vipIconLevel.text = VipManager.GetVipLevel()
    self.vipProgress.fillAmount = VipManager.GetChargedNum() / nextLevelNeed
    self.progressText.text = VipManager.GetChargedNum()*10 .. "/" ..  nextLevelNeed*10
    Game.GlobalEvent:DispatchEvent(GameEvent.Vip.OnVipRankChanged)
end

function RechargeView:OnSortingOrderChange(cursortingOrder)
    if self.shopView then
        self.shopView:SetSortLayer(cursortingOrder)
    end
end

function RechargeView:OnHide()
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, self.SetVipPartInfo, self)
end

function RechargeView:OnDestroy()
    -- 销毁shopview
    if self.shopView then
        SubUIManager.Close(self.shopView)
        self.shopView = nil
    end
end

return RechargeView