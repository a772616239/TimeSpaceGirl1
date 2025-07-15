require("Base/BasePanel")
SoulPrintUpLevelSuccessPopUp = Inherit(BasePanel)
local this=SoulPrintUpLevelSuccessPopUp
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
--初始化组件（用于子类重写）
function SoulPrintUpLevelSuccessPopUp:InitComponent()
    this.quality = Util.GetGameObject(self.gameObject, "Bg/itemShow/quality"):GetComponent("Image")
    this.icon = Util.GetGameObject(self.gameObject, "Bg/itemShow/icon"):GetComponent("Image")
    this.level = Util.GetGameObject(self.gameObject, "Bg/itemShow/level"):GetComponent("Text")
    this.name = Util.GetGameObject(self.gameObject, "Bg/itemShow/name"):GetComponent("Text")
    this.lastLevelText = Util.GetGameObject(self.gameObject, "Bg/itemShow/lastLevelText"):GetComponent("Text")
    this.nextLevelText = Util.GetGameObject(self.gameObject, "Bg/itemShow/nextLevelText"):GetComponent("Text")
    this.propertyLeft1=Util.GetGameObject(self.gameObject, "Bg/propertyAddContent/propertyLeft1"):GetComponent("Text")
    this.propertyLeft2=Util.GetGameObject(self.gameObject, "Bg/propertyAddContent/propertyLeft2"):GetComponent("Text")
    this.propertyRight1=Util.GetGameObject(self.gameObject, "Bg/propertyAddContent/propertyRight1"):GetComponent("Text")
    this.propertyRight2=Util.GetGameObject(self.gameObject, "Bg/propertyAddContent/propertyRight2"):GetComponent("Text")
    this.image2=Util.GetGameObject(self.gameObject, "Bg/propertyAddContent/Image (2)")
    this.sureBtn=Util.GetGameObject(self.gameObject, "Bg/sureBtn")
end

--绑定事件（用于子类重写）
function SoulPrintUpLevelSuccessPopUp:BindEvent()
    Util.AddClick(this.sureBtn, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function SoulPrintUpLevelSuccessPopUp:AddListener()

end

--移除事件监听（用于子类重写）
function SoulPrintUpLevelSuccessPopUp:RemoveListener()

end

--界面打开时调用（用于子类重写）
function SoulPrintUpLevelSuccessPopUp:OnOpen(lastUpLevelItemData,upLevelItemData)
    this.quality.sprite = Util.LoadSprite(GetQuantityImageByquality(lastUpLevelItemData.quality))
    this.icon.sprite = Util.LoadSprite(lastUpLevelItemData.icon)
    this.level.text = "+" .. lastUpLevelItemData.level
    this.name.text = lastUpLevelItemData.name
    this.lastLevelText.text = lastUpLevelItemData.level
    this.nextLevelText.text = upLevelItemData.level
    if(lastUpLevelItemData.level==10) then
        this.nextLevelText.text=GetLanguageStrById(11961)
    end
    this.propertyLeft2.text=""
    this.propertyRight2.text=""
    this.image2:SetActive(false)
    local property=SoulPrintManager.GetShowPropertyData(lastUpLevelItemData.property[1][1],lastUpLevelItemData.property[1][2])
    this.propertyLeft1.text =property.name..property.num
    property=SoulPrintManager.GetShowPropertyData(lastUpLevelItemData.property[1][1],upLevelItemData.property[1][2])
    this.propertyRight1.text=property.num
    if (#upLevelItemData.property >= 2) then
        this.image2:SetActive(true)
        if(#upLevelItemData.property>=2) then
            property=SoulPrintManager.GetShowPropertyData(upLevelItemData.property[2][1],upLevelItemData.property[2][2])
            this.propertyLeft2.text=property.name..property.num
        else
            property=SoulPrintManager.GetShowPropertyData(upLevelItemData.property[2][1],upLevelItemData.property[2][2])
            this.propertyLeft2.text=property.name.."+0"
        end
        property=SoulPrintManager.GetShowPropertyData(upLevelItemData.property[2][1],upLevelItemData.property[2][2])
        this.propertyRight2.text=property.num
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SoulPrintUpLevelSuccessPopUp:OnShow()

end

--界面关闭时调用（用于子类重写）
function SoulPrintUpLevelSuccessPopUp:OnClose()

end

--界面销毁时调用（用于子类重写）
function SoulPrintUpLevelSuccessPopUp:OnDestroy()

end

return SoulPrintUpLevelSuccessPopUp