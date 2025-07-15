require("Base/BasePanel")
FormationCenterActivePanel = Inherit(BasePanel)
local this = FormationCenterActivePanel
local RechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)

--初始化组件（用于子类重写）
function FormationCenterActivePanel:InitComponent()
    this.rechargeBtn = Util.GetGameObject(self.gameObject,"frame/rechargeBtn")
    this.rechargeNum = Util.GetGameObject(this.rechargeBtn,"Text")
    this.closeBtn = Util.GetGameObject(self.gameObject,"closeBtn")

    this.title = Util.GetGameObject(self.gameObject,"frame/BG/title"):GetComponent("Text")
    this.text = Util.GetGameObject(self.gameObject,"frame/BG/info"):GetComponent("Text")
    this.scroll = Util.GetGameObject(self.gameObject,"frame/BG/scroll")
    this.itemPre = Util.GetGameObject(self.gameObject,"itempre")
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        this.itemPre, nil, Vector2.New(this.scroll.transform.rect.width, this.scroll.transform.rect.height), 2, 1, Vector2.New(45, 0))
end

--绑定事件（用于子类重写）
function FormationCenterActivePanel:BindEvent()
    Util.AddClick(this.rechargeBtn,function ()
        local state = OperatingManager.GetLeftBuyTime(GoodsTypeDef.DirectPurchaseGift, 20001)
        if GetChannerConfig().Rechargemode_Mail then
            if state == 0 then
                PopupTipPanel.ShowTipByLanguageId(50235)
                return
            end
        end
        if AppConst.isSDKLogin then
            PayManager.Pay({ Id = 20001 }, function()
            end)
        else
            NetManager.RequestBuyGiftGoods(20001,function()
            end)
        end
    end)
    Util.AddClick(this.closeBtn,function ()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function FormationCenterActivePanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.FormationCenter.OnFormationCenterLevelChange, this.OnTrigger)
end

--移除事件监听（用于子类重写）
function FormationCenterActivePanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.FormationCenter.OnFormationCenterLevelChange, this.OnTrigger)
end

function this.OnTrigger()    
    UIManager.OpenPanel(UIName.FormationCenterActiveOrUpgradeSuccessPanel,0)
    FormationCenterActivePanel:ClosePanel()
end

--界面打开时调用（用于子类重写）
function FormationCenterActivePanel:OnOpen()
    local rechargeConfig = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, 20001)
    this.rechargeNum:GetComponent("Text").text = MoneyUtil.GetMoney(rechargeConfig.Price)
    local investigateConfig = ConfigManager.GetConfigData(ConfigName.InvestigateConfig,10)
    this.title.text = GetLanguageStrById(50122)
    this.text.text = GetLanguageStrById(investigateConfig.DescAll)
    this.scrollView:SetData(rechargeConfig.BaseReward,function(index,go)
        this.ScrollData(go,rechargeConfig.BaseReward[index])
    end)
    -- this.scrollView:SetData(RechargeCommodityConfig[20001].BaseReward,function(index,go)
    --     this.ScrollData(go,RechargeCommodityConfig[20001].BaseReward[index])
    -- end)
end

function FormationCenterActivePanel:OnShow()
   
end
-- function this.ScrollData(go,date)
--     if (not itemsGrid1)  then
--         itemsGrid1 = {}
--     end
--     if not itemsGrid1[go] then
--         itemsGrid1[go] = SubUIManager.Open(SubUIConfig.ItemView,go.transform)
--     end
--     itemsGrid1[go]:OnOpen(false, date, 0.9, false)
-- end
function this.ScrollData(go,date)
    if not itemsGrid then
        itemsGrid = {}
    end
    if not itemsGrid[go] then
        itemsGrid[go] = SubUIManager.Open(SubUIConfig.ItemView,go.transform)
    end
    itemsGrid[go]:OnOpen(false, date, 0.65, false)
end

--界面关闭时调用（用于子类重写）
function FormationCenterActivePanel:OnClose()
   
end

--界面销毁时调用（用于子类重写）
function FormationCenterActivePanel:OnDestroy()

end

return FormationCenterActivePanel