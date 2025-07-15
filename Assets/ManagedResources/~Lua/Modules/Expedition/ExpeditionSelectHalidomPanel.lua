require("Base/BasePanel")
ExpeditionSelectHalidomPanel = Inherit(BasePanel)
local fun
local curSelectHalidom
local _HalidomQualityConfig = {
    [3] = {bg = "m5_img_shenrudiying-zhanlipin-chuanshuodi", selectImg = "l_lieyaozhilu_chuanshuo1", typename = 12158, color = "#ff9898"},
    [2] = {bg = "m5_img_shenrudiying-zhanlipin-shishidi", selectImg = "l_lieyaozhilu_shishi1", typename = 12157, color = "#fff298"},
    [1] = {bg = "m5_img_shenrudiying-zhanlipin-xiyoudi", selectImg = "l_lieyaozhilu_xiyou1", typename = 12076, color = "#fe98ff"},

    
    [7] = {bg = "m5_img_shenrudiying-zhanlipin-chuanshuodi", selectImg = "l_lieyaozhilu_chuanshuo1", typename = 12158, color = "#ff9898"},
    [6] = {bg = "m5_img_shenrudiying-zhanlipin-shishidi", selectImg = "l_lieyaozhilu_shishi1", typename = 12157, color = "#fff298"},
    [5] = {bg = "m5_img_shenrudiying-zhanlipin-xiyoudi", selectImg = "l_lieyaozhilu_xiyou1", typename = 12076, color = "#fe98ff"},
}
local isOpenPanel = false
local curSelectNodeData = {}
--初始化组件（用于子类重写）
function ExpeditionSelectHalidomPanel:InitComponent()

    self.BtnBack = Util.GetGameObject(self.transform, "maskBtn")
    self.BackMask = Util.GetGameObject(self.transform, "BackMask") --m5
    self.BtnSure = Util.GetGameObject(self.transform, "btnSure")
    self.cardPre = Util.GetGameObject(self.gameObject, "cardPre")
    self.grid = Util.GetGameObject(self.gameObject, "RewardRect")
    self.noOneImage = Util.GetGameObject(self.gameObject, "noOneImage")
    -- self.selectImage = Util.GetGameObject(self.gameObject, "selectImage")

    self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.grid.transform,
            self.cardPre, nil, Vector2.New(283*3, 632 + 100), 2, 1, Vector2.New(19.32,0))
    self.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    self.ScrollView.moveTween.MomentumAmount = 1
    self.ScrollView.moveTween.Strength = 1
    self.ScrollView.elastic = false
end

--绑定事件（用于子类重写）
function ExpeditionSelectHalidomPanel:BindEvent()
    Util.AddClick(self.BtnBack, function()
        self:ClosePanel()
        Game.GlobalEvent:DispatchEvent(GameEvent.Expedition.RefreshMainPanel)
    end)
    Util.AddClick(self.BackMask, function()
        self:ClosePanel()
        Game.GlobalEvent:DispatchEvent(GameEvent.Expedition.RefreshMainPanel)
    end) --m5
    Util.AddClick(self.BtnSure, function()
            if curSelectHalidom then
                
                NetManager.TakeHolyEquipRequest(curSelectNodeData.sortId,curSelectHalidom, function(msg)
                   
                    --UIManager.OpenPanel(UIName.ExpeditionMainPanel)
                    Game.GlobalEvent:DispatchEvent(GameEvent.Expedition.RefreshPlayAniMainPanel)
                end)
                self:ClosePanel()
            else
                PopupTipPanel.ShowTipByLanguageId(10507)
            end
    end)
end

--添加事件监听（用于子类重写）
function ExpeditionSelectHalidomPanel:AddListener()

end

--移除事件监听（用于子类重写）
function ExpeditionSelectHalidomPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function ExpeditionSelectHalidomPanel:OnOpen(_isOpenPanel,_fun)

    isOpenPanel = _isOpenPanel
    fun = _fun
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ExpeditionSelectHalidomPanel:OnShow()
    curSelectHalidom = nil
    self:OnshowPanelData()
end

function ExpeditionSelectHalidomPanel:OnshowPanelData()
    local allHoly = {}
    -- self.selectImage:SetActive(false)
    curSelectNodeData = ExpeditionManager.curAttackNodeInfo
    allHoly = curSelectNodeData.holyEquipID
    self.noOneImage:SetActive(#allHoly <= 0)
    self.ScrollView:SetData(allHoly, function(index, go)
        self:OnShowSingleHolyData(go, allHoly[index])
    end)
end

function ExpeditionSelectHalidomPanel:OnShowSingleHolyData(go,singleHoly)
    local configData
    configData = ConfigManager.GetConfigData(ConfigName.ExpeditionHolyConfig,singleHoly)
    
    Util.GetGameObject(go, "bg"):GetComponent("Image").sprite = Util.LoadSprite(_HalidomQualityConfig[configData.type].bg)
    Util.GetGameObject(go, "quaImage"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(configData.type))
    Util.GetGameObject(go, "iconImage"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(configData.Icon))-- 报错，资源表里找不到：Util.LoadSprite(GetResourcePath(configData.Icon))
    Util.GetGameObject(go, "nameText"):GetComponent("Text").text = configData.Name
    Util.GetGameObject(go, "infoText"):GetComponent("Text").text = configData.Describe

    Util.GetGameObject(go, "type_name"):GetComponent("Text").text = "<color=".._HalidomQualityConfig[configData.type].color..">"..GetLanguageStrById(_HalidomQualityConfig[configData.type].typename).."</color>"
    
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
            Util.GetGameObject(go, "posImage/posImage"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(configData.SpecialIcon[2]))
        elseif configData.SpecialIcon[1] == 3 then--英雄
            heroImage:SetActive(true)
            Util.GetGameObject(heroImage, "Icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(HeroManager,configData.SpecialIcon[2]).Icon))
        end
    end
    local  click = Util.GetGameObject(go, "click")
    click:GetComponent("Button").enabled = true
    Util.AddOnceClick(click, function()
        -- self:SelectImageSetParent(Util.GetGameObject(go, "selectRoot"), configData)

        self:SelectItem(go)
        curSelectHalidom = singleHoly
    end)
end

--选择图片设置父级
function ExpeditionSelectHalidomPanel:SelectImageSetParent(_objPoint, configData)
    -- self.selectImage:SetActive(true)
    -- self.selectImage.transform:SetParent(_objPoint.transform)
    -- self.selectImage.transform.localScale = Vector3.one
    -- self.selectImage.transform.localPosition = Vector3.zero
    -- self.selectImage:GetComponent("Image").sprite = Util.LoadSprite(_HalidomQualityConfig[configData.type].selectImg)
end

function ExpeditionSelectHalidomPanel:SelectItem(go)
    local setData = function (i, item)
        item.transform:DOScale(Vector3.one, 0.1)
    end
    self.ScrollView:ForeachItemGO(setData)

    go.transform:DOScale(Vector3.one * 1.1, 0.1)
end


--界面关闭时调用（用于子类重写）
function ExpeditionSelectHalidomPanel:OnClose()

    if fun then
        fun()
        fun = nil
    end
end

--界面销毁时调用（用于子类重写）
function ExpeditionSelectHalidomPanel:OnDestroy()

end
return ExpeditionSelectHalidomPanel