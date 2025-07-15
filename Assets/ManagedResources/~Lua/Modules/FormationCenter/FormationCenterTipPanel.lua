require("Base/BasePanel")
FormationCenterTipPanel = Inherit(BasePanel)
local this = FormationCenterTipPanel
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local investigateLevel
local investigateConfig
--初始化组件（用于子类重写）
function FormationCenterTipPanel:InitComponent()
    this.backBtn = Util.GetGameObject(self.gameObject, "bg/backBtn")
    this.proItem = Util.GetGameObject(self.gameObject, "bg/proPrefab")
    this.StarItem = Util.GetGameObject(self.gameObject, "bg/StarItem")
    local v = Util.GetGameObject(self.gameObject, "bg/rect"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "bg/rect").transform,
            this.StarItem, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,15))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function FormationCenterTipPanel:BindEvent() 
    Util.AddClick(this.backBtn,function ()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function FormationCenterTipPanel:AddListener()
end

--移除事件监听（用于子类重写）
function FormationCenterTipPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function FormationCenterTipPanel:OnOpen()
    investigateLevel = FormationCenterManager.GetInvestigateLevel()    
end

function FormationCenterTipPanel:OnShow()
    local curAllData = ConfigManager.GetAllConfigsData(ConfigName.InvestigateConfig)
    local allData = {}
    for Index,value in pairs(curAllData) do
       table.insert(allData,value)
    end
    table.sort(allData,function (a,b)
        return a.Id < b.Id
    end)
    this.ScrollView:SetData(allData, function (index, go)
        self:SingleDataShow(go, allData[index])
    end)
    this.ScrollView:SetIndex(investigateLevel)
end

function FormationCenterTipPanel:SingleDataShow(go,data)
    local starItem = go
    starItem:SetActive(true)
    local icon = Util.GetGameObject(starItem,"icon"):GetComponent("Image")
    local name = Util.GetGameObject(starItem,"name/Text"):GetComponent("Text")
    local StarContent = Util.GetGameObject(starItem,"StarContent")
    local proCountent = Util.GetGameObject(starItem,"proCountent")
    local tip = Util.GetGameObject(starItem,"tip")
    local everydayItemIcon = Util.GetGameObject(starItem,"everyday/icon"):GetComponent("Image")
    local everydayItemNum = Util.GetGameObject(starItem,"everyday/Text"):GetComponent("Text")

    tip:SetActive(data.Id == investigateLevel)
    name.text = GetLanguageStrById(data.Name)
    SetHeroStars(StarContent,data.Id)
    icon.sprite = Util.LoadSprite(GetResourcePath(data.ArtResourcesId))

    local config = ConfigManager.GetConfigData(ConfigName.ItemConfig, data.DailyReward[1][1])
    everydayItemIcon.sprite = Util.LoadSprite(GetResourcePath(config.ResourceID))
    everydayItemNum.text = data.DailyReward[1][2]

    Util.ClearChild(proCountent.transform)
    for i = 1, #data.PropertyAdd do
        local go = newObjToParent(this.proItem, proCountent)
        local name = Util.GetGameObject(go,"name"):GetComponent("Text")
        local value = Util.GetGameObject(go,"value"):GetComponent("Text")
        name.text = GetLanguageStrById(propertyConfig[data.PropertyAdd[i][1]].Info)
        value.text = "+"..GetPropertyFormatStr(propertyConfig[data.PropertyAdd[i][1]].Style,data.PropertyAdd[i][2])
        go:GetComponent("Image").sprite = Util.LoadSprite(propertyConfig[data.PropertyAdd[i][1]].Icon)
    end
end

--界面关闭时调用（用于子类重写）
function FormationCenterTipPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function FormationCenterTipPanel:OnDestroy()
end

return FormationCenterTipPanel