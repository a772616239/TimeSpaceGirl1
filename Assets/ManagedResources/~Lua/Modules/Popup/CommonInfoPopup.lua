require("Base/BasePanel")
CommonInfoPopup = Inherit(BasePanel)
local this = CommonInfoPopup

--初始化组件（用于子类重写）
function this:InitComponent()

    this.content = Util.GetGameObject(self.transform, "Content"):GetComponent("RectTransform")
    this.backBtn = Util.GetGameObject(self.transform, "Button")
    this.IconBG = Util.GetGameObject(self.transform, "Content/IconBG"):GetComponent("Image")
    this.icon = Util.GetGameObject(self.transform, "Content/IconBG/Icon"):GetComponent("Image")
    this.DesText = Util.GetGameObject(self.transform, "Content/Title/Text"):GetComponent("Text")
    this.DesType = Util.GetGameObject(self.transform,"Content/Title/type"):GetComponent("Text")
    this.Des = Util.GetGameObject(self.transform, "Content/CurrentLvDesc/Text"):GetComponent("Text")
    this.rect=Util.GetGameObject(self.transform,"Content"):GetComponent("RectTransform")

end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()

end

--移除事件监听（用于子类重写）
function this:RemoveListener()

end

function this:OnShow()

end

--界面打开时调用（用于子类重写）
function this:OnOpen(...)
    local args = { ... }
    this.type = args[1]
    this.originNode = args[2]
    this.rootId = args[3]

    this.content.anchoredPosition = Vector2.New(0, 0)
    local pt = UIManager.GetLocalPositionToTarget(this.content, this.originNode)
    this.content.transform.localPosition = Vector2.New(0, pt.y)
    self:SetUI()
end

function this:SetUI()
    local strTitle
    local strType
    local strDes
    local strIcon
    local strFrame
    if this.type == CommonInfoType.WarWay then
        local warWayData = G_WarWaySkillConfig[this.rootId]
        local passiveData = G_PassiveSkillConfig[warWayData.SkillId]

        strTitle = GetLanguageStrById(passiveData.Name)
        strType = GetLanguageStrById(11093) .. GetLanguageStrById(50319)
        strDes = GetSkillConfigDesc(passiveData, false, 1)
        strIcon = GetResourceStr(warWayData.Image)
        strFrame = GetQuantityImageByquality(warWayData.Quantity)
    else

    end

    if strIcon then
        this.icon.sprite = Util.LoadSprite(strIcon)
    end
    
    if strFrame then
        this.IconBG.sprite = Util.LoadSprite(strFrame)
    end
    
    this.DesText.text = strTitle
    this.DesType.text = strType
    this.Des.text = strDes
end

--界面关闭时调用（用于子类重写）
function this:OnClose()

end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()

end




return CommonInfoPopup;