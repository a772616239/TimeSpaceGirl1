require("Base/BasePanel")
WorkShopAwardPanel = Inherit(BasePanel)
local this = WorkShopAwardPanel
--初始化组件（用于子类重写）
function WorkShopAwardPanel:InitComponent()

    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.awardName=Util.GetGameObject(self.transform, "name/Text"):GetComponent("Text")
    this.num=Util.GetGameObject(self.transform, "frame/num"):GetComponent("Text")
    --this.icon=Util.GetGameObject(self.transform, "frame/icon"):GetComponent("Image")
    --this.frame=Util.GetGameObject(self.transform, "frame"):GetComponent("Image")
    this.exp=Util.GetGameObject(self.transform, "expInfo"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function WorkShopAwardPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function WorkShopAwardPanel:AddListener()

end

--移除事件监听（用于子类重写）
function WorkShopAwardPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WorkShopAwardPanel:OnOpen(...)

    local data={...}
    local itemData=data[1]
    this.awardName.text=itemData.name
    --this.icon.text=Util.LoadSprite(itemData.icon)
    --this.frame.text=Util.LoadSprite(itemData.frame)
    this.exp.text=GetLanguageStrById(12033)..itemData.expNum
    this.num.text=itemData.num
end

--界面关闭时调用（用于子类重写）
function WorkShopAwardPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function WorkShopAwardPanel:OnDestroy()

end

return WorkShopAwardPanel