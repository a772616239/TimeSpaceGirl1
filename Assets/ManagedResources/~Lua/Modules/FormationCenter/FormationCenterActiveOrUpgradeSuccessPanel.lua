require("Base/BasePanel")
FormationCenterActiveOrUpgradeSuccessPanel = Inherit(BasePanel)
local this = FormationCenterActiveOrUpgradeSuccessPanel
local OpenType = {Unlock = 0, UpGrade = 1}
local openType
local investigateLevel = 1
local investigateConfig
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
--初始化组件（用于子类重写）
function FormationCenterActiveOrUpgradeSuccessPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject,"btnBack")
    this.UnLock = Util.GetGameObject(self.gameObject,"ScrollView/bg/Image/UnLock")
    this.Upgrade = Util.GetGameObject(self.gameObject,"ScrollView/bg/Image/Upgrade")
    this.icon = Util.GetGameObject(self.gameObject,"ScrollView/ItemContent/Item/icon")
    this.name = Util.GetGameObject(self.gameObject,"ScrollView/ItemContent/Item/name")
    this.Effect = Util.GetGameObject(self.gameObject,"ScrollView/ItemContent/Item/Effect")
    this.StarContent = Util.GetGameObject(self.gameObject,"ScrollView/ItemContent/Item/StarContent")
    this.proItem = Util.GetGameObject(self.gameObject,"ScrollView/ItemContent/proPrefab")
    this.proContent = Util.GetGameObject(self.gameObject,"ScrollView/ItemContent/Item/proContent")

    this.everyday = Util.GetGameObject(self.gameObject,"ScrollView/everyday")
    this.frame = Util.GetGameObject(self.gameObject,"ScrollView/everyday/frame"):GetComponent("Image")
    this.itemIcon = Util.GetGameObject(self.gameObject,"ScrollView/everyday/frame/icon"):GetComponent("Image")
    this.num = Util.GetGameObject(self.gameObject,"ScrollView/everyday/frame/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function FormationCenterActiveOrUpgradeSuccessPanel:BindEvent()   
    Util.AddClick(this.btnBack,function ()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function FormationCenterActiveOrUpgradeSuccessPanel:AddListener()
end

--移除事件监听（用于子类重写）
function FormationCenterActiveOrUpgradeSuccessPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function FormationCenterActiveOrUpgradeSuccessPanel:OnOpen(...)
    local args = {...}
    openType = args[1]
    if args[2] then
        investigateLevel = args[2]
    end
    investigateConfig = ConfigManager.GetConfigData(ConfigName.InvestigateConfig,investigateLevel)
end

function FormationCenterActiveOrUpgradeSuccessPanel:OnShow()
    this.name:SetActive(openType == OpenType.Unlock)
    this.icon:SetActive(openType == OpenType.Unlock)
    this.UnLock:SetActive(openType == OpenType.Unlock)
    this.Upgrade:SetActive(openType == OpenType.UpGrade)
    this.StarContent:SetActive(openType == OpenType.UpGrade)
    this.proContent:SetActive(openType == OpenType.UpGrade)
    if openType == OpenType.Unlock then
        this.icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(investigateConfig.ArtResourcesId))
        this.Effect:GetComponent("Text").text = GetLanguageStrById(investigateConfig.Desc)
    elseif openType == OpenType.UpGrade  then
       SetHeroStars(this.StarContent,investigateLevel)

        Util.ClearChild(this.proContent.transform)
        for i = 1, #investigateConfig.PropertyAdd do
            local go = newObjToParent(this.proItem, this.proContent)
            local name = Util.GetGameObject(go,"name"):GetComponent("Text")
            local value = Util.GetGameObject(go,"value"):GetComponent("Text")
            name.text = GetLanguageStrById(propertyConfig[investigateConfig.PropertyAdd[i][1]].Info)
            value.text = "+"..GetPropertyFormatStr(propertyConfig[investigateConfig.PropertyAdd[i][1]].Style,investigateConfig.PropertyAdd[i][2])
            go:GetComponent("Image").sprite = Util.LoadSprite(propertyConfig[investigateConfig.PropertyAdd[i][1]].Icon)
        end
    end

    local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig, investigateConfig.DailyReward[1][1])
    this.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig.Quantity))
    this.itemIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
    this.num.text = investigateConfig.DailyReward[1][2]
end

--界面关闭时调用（用于子类重写）
function FormationCenterActiveOrUpgradeSuccessPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function FormationCenterActiveOrUpgradeSuccessPanel:OnDestroy()
end

return FormationCenterActiveOrUpgradeSuccessPanel