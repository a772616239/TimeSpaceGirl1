require("Base/BasePanel")
HegemonyTipPopup = Inherit(BasePanel)
local this = HegemonyTipPopup

function HegemonyTipPopup:InitComponent()

    this.okBtn=Util.GetGameObject(self.gameObject,"okBtn")
    this.cancelBtn= Util.GetGameObject(self.gameObject, "cancelBtn")

end

function HegemonyTipPopup:BindEvent()
    Util.AddClick(this.cancelBtn,function()
            self:ClosePanel()
    end)
    Util.AddClick(this.okBtn,function()
        self:ClosePanel()
        UIManager.OpenPanel(UIName.FormationPanelV2,this.arg[1],this.arg[2],this.arg[3],this.arg[4],this.arg[5])

end)
 
end

function HegemonyTipPopup:AddListener()
end

function HegemonyTipPopup:RemoveListener()

end

function HegemonyTipPopup:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end

function HegemonyTipPopup:OnOpen(...)
    
    this.arg={...}
end

function HegemonyTipPopup:OnShow()
  
end

function HegemonyTipPopup:OnClose()
 
end

function HegemonyTipPopup:OnDestroy()

end


return HegemonyTipPopup