require("Base/BasePanel")
ExpeditionHalidomPanel = Inherit(BasePanel)
local _HalidomQualityConfig = {
    [3] = {bg = "m5_img_shenrudiying-zhanlipin-chuanshuodi", selectImg = "l_lieyaozhilu_chuanshuo1", typename = 12158, color = "#ff9898"},
    [2] = {bg = "m5_img_shenrudiying-zhanlipin-shishidi", selectImg = "l_lieyaozhilu_shishi1", typename = 12157, color = "#fff298"},
    [1] = {bg = "m5_img_shenrudiying-zhanlipin-xiyoudi", selectImg = "l_lieyaozhilu_xiyou1", typename = 12076, color = "#fe98ff"},

    
    [7] = {bg = "m5_img_shenrudiying-zhanlipin-chuanshuodi", selectImg = "l_lieyaozhilu_chuanshuo1", typename = 12158, color = "#ff9898"},
    [6] = {bg = "m5_img_shenrudiying-zhanlipin-shishidi", selectImg = "l_lieyaozhilu_shishi1", typename = 12157, color = "#fff298"},
    [5] = {bg = "m5_img_shenrudiying-zhanlipin-xiyoudi", selectImg = "l_lieyaozhilu_xiyou1", typename = 12076, color = "#fe98ff"},
}
--初始化组件（用于子类重写）
function ExpeditionHalidomPanel:InitComponent()

    self.BtnBack = Util.GetGameObject(self.transform, "maskBtn")
    self.BtnSure = Util.GetGameObject(self.transform, "btnSure")
    self.cardPre = Util.GetGameObject(self.gameObject, "cardPreV3")
    self.grid = Util.GetGameObject(self.gameObject, "RewardRect")
    self.noOneImage = Util.GetGameObject(self.gameObject, "noOneImage")

    self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.grid.transform,
            self.cardPre, nil, Vector2.New(283 * 3 + 30, 972.5), 1, 3, Vector2.New(19.32,0))
    self.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    self.ScrollView.moveTween.MomentumAmount = 1
    self.ScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function ExpeditionHalidomPanel:BindEvent()

    Util.AddClick(self.BtnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.BtnSure, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ExpeditionHalidomPanel:AddListener()

end

--移除事件监听（用于子类重写）
function ExpeditionHalidomPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function ExpeditionHalidomPanel:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ExpeditionHalidomPanel:OnShow()

    self:OnshowPanelData()
end

function ExpeditionHalidomPanel:OnshowPanelData()
    local allHoly = {}
    for i, v in pairs(ExpeditionManager.allHoly) do
        local configData = ConfigManager.GetConfigData(ConfigName.ExpeditionHolyConfig,v.equiptId)
        v.configData = configData
        table.insert(allHoly,v)
    end
    self:SortDatas(allHoly)
    self.noOneImage:SetActive(#allHoly <= 0)
    self.ScrollView:SetData(allHoly, function(index, go)
        self:OnShowSingleHolyData(go, allHoly[index])
    end)
end

function ExpeditionHalidomPanel:OnShowSingleHolyData(go,singleHoly)
    local configData = ConfigManager.GetConfigData(ConfigName.ExpeditionHolyConfig,singleHoly.equiptId)
    
    Util.GetGameObject(go, "bg"):GetComponent("Image").sprite = Util.LoadSprite(_HalidomQualityConfig[configData.type].bg)
    Util.GetGameObject(go, "quaImage"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(configData.type))
    Util.GetGameObject(go, "iconImage"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(configData.Icon))
    Util.GetGameObject(go, "nameText"):GetComponent("Text").text = configData.Name
    Util.GetGameObject(go, "infoText"):GetComponent("Text").text = configData.Describe
    local  click = Util.GetGameObject(go, "click")
    click:GetComponent("Button").enabled = false
    local posImage = Util.GetGameObject(go, "posImage")
    local proImage = Util.GetGameObject(go, "proImage")
    local heroImage = Util.GetGameObject(go, "Hero")
    posImage:SetActive(false)
    proImage:SetActive(false)
    heroImage:SetActive(false)
    if configData.SpecialIcon then
        if configData.SpecialIcon[1] == 1 then--属性
            proImage:SetActive(true)
            proImage:GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(configData.SpecialIcon[2]))
        elseif configData.SpecialIcon[1] == 2 then--职业
            posImage:SetActive(true)
            Util.GetGameObject(go, "posImage/posImage"):GetComponent("Image").sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(configData.SpecialIcon[2]))
        elseif configData.SpecialIcon[1] == 3 then--英雄
            heroImage:SetActive(true)
            Util.GetGameObject(heroImage, "Icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(HeroManager,configData.SpecialIcon[2]).Icon))
        end
    end
end
--界面关闭时调用（用于子类重写）
function ExpeditionHalidomPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function ExpeditionHalidomPanel:OnDestroy()

end
--排序
function ExpeditionHalidomPanel:SortDatas(allHoly)
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(allHoly, function(a, b)
        if a.configData.type == b.configData.type then
            return a.equiptId < b.equiptId
        else
            return a.configData.type > b.configData.type
        end
    end)
end
return ExpeditionHalidomPanel