require("Base/BasePanel")
HandBookMainPanel = Inherit(BasePanel)

--初始化组件（用于子类重写）
function HandBookMainPanel:InitComponent()

    self.btnBack = Util.GetGameObject(self.transform, "btnBack/Image")
    self.HeroBtn = Util.GetGameObject(self.transform, "heroGo/heroBtn")
    self.equipBtn = Util.GetGameObject(self.transform, "equipGo/equipBtn")
    --self.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    --self.BtView2 = SubUIManager.Open(SubUIConfig.BtView2, self.gameObject.transform)
    self.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)
end

--绑定事件（用于子类重写）
function HandBookMainPanel:BindEvent()

    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
        UIManager.OpenPanel(UIName.MainPanel)
    end)
    Util.AddClick(self.HeroBtn, function()
       UIManager.OpenPanel(UIName.HandBookHeroAndEquipListPanel,1)
    end)
    Util.AddClick(self.equipBtn, function()
        UIManager.OpenPanel(UIName.HandBookHeroAndEquipListPanel,3)
    end)
end

--添加事件监听（用于子类重写）
function HandBookMainPanel:AddListener()

end

--移除事件监听（用于子类重写）
function HandBookMainPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function HandBookMainPanel:OnOpen(...)

    --self.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.RolePanel })
    --self.BtView2:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView2.HandBookPanel })
    self.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function HandBookMainPanel:OnShow()

end

--界面关闭时调用（用于子类重写）
function HandBookMainPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function HandBookMainPanel:OnDestroy()

    SubUIManager.Close(self.UpView)
    --SubUIManager.Close(self.BtView)
    --SubUIManager.Close(self.BtView2)
end

return HandBookMainPanel