require("Base/BasePanel")
RoleReturnListPanel = Inherit(BasePanel)
local this = RoleReturnListPanel
local curSelectHeroData
local openThisPanel
local celectCardGo
--初始化组件（用于子类重写）
function RoleReturnListPanel:InitComponent()

    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.BtnSure = Util.GetGameObject(self.transform, "btnSure")
    this.cardPre = Util.GetGameObject(self.gameObject, "item")
    this.desText = Util.GetGameObject(self.gameObject, "desText"):GetComponent("Text")

    this.Scrollbar= Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,Util.GetGameObject(self.gameObject, "scroll").transform,
            this.cardPre, this.Scrollbar, Vector2.New(927.5, 1010), 1, 5, Vector2.New(19.32,15))
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(6.78, 27)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function RoleReturnListPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.BtnSure, function()
        self:ClosePanel()
        openThisPanel:OnShowCallBackData(curSelectHeroData,false)
    end)
end
--添加事件监听（用于子类重写）
function RoleReturnListPanel:AddListener()

end

--移除事件监听（用于子类重写）
function RoleReturnListPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RoleReturnListPanel:OnOpen(_curSelectHeroData,_openThisPanel)

    openThisPanel= _openThisPanel
    curSelectHeroData = _curSelectHeroData
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RoleReturnListPanel:OnShow()

    celectCardGo = nil
    local needStar = ConfigManager.GetConfigData(ConfigName.GameSetting,1).HeroReturn[2]
    local heroData = HeroManager.GetReturnHeroDatas(needStar)
    this.HeroSortData(heroData)
    this.ScrollView:SetData(heroData, function (index, go)
        this.OnShowSingleCardData(go, heroData[index])
    end)
    this.desText.text=string.format(GetLanguageStrById(11860) .. NumToSimplenessFont[needStar] .. GetLanguageStrById(11861))
end
function this.OnShowSingleCardData(go,heroData)

    local choosed = Util.GetGameObject(go.transform, "choosed")
    choosed:SetActive(false)
    if curSelectHeroData.dynamicId == heroData.dynamicId then
        celectCardGo = go
        choosed:SetActive(true)
    end
    Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality, heroData.star))
    Util.GetGameObject(go.transform, "lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
    Util.GetGameObject(go.transform, "posIcon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.professionIcon)
    Util.GetGameObject(go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    --Util.GetGameObject(go.transform, "heroStage"):GetComponent("Image").sprite = Util.LoadSprite(HeroStageSprite[heroData.heroConfig.HeroStage])
    Util.GetGameObject(go.transform, "heroStage"):SetActive(false)
    local formationMask = Util.GetGameObject(go.transform, "formationMask")
    formationMask:SetActive(heroData.isFormation ~= "" or heroData.lockState == 1)
    Util.GetGameObject(formationMask.transform, "formationImage"):SetActive(heroData.isFormation ~= "" )
    Util.GetGameObject(formationMask.transform, "lockImage"):SetActive( heroData.lockState == 1)
    local starGrid = Util.GetGameObject(go.transform, "star")
    SetHeroStars(starGrid, heroData.star)

    local cardBtn = Util.GetGameObject(go.transform, "icon")
    Util.AddOnceClick(cardBtn, function()
        if curSelectHeroData.dynamicId == heroData.dynamicId then
            return
        end
        curSelectHeroData = heroData
        choosed:SetActive(true)
        if celectCardGo then
            Util.GetGameObject(celectCardGo.transform, "choosed"):SetActive(false)
        end
        celectCardGo = go
    end)
    Util.AddOnceClick(formationMask, function()
        if heroData.isFormation ~= "" then
            PopupTipPanel.ShowTip( heroData.isFormation)
            return
        end
        if heroData.lockState == 1 then
            PopupTipPanel.ShowTipByLanguageId(11776)
            return
        end
    end)
end
function this.HeroSortData(heroData)
    table.sort(heroData, function(a, b)
        if a.isFormation == "" and b.isFormation == "" then
            if a.lockState == b.lockState then
                if a.id == b.id then
                    if a.lv == b.lv then
                        return a.id > b.id
                    else
                        return a.lv < b.lv
                    end
                else
                    return a.id > b.id
                end
            else
                return a.lockState < b.lockState
            end
        else
            return a.isFormation == ""  and not b.isFormation ~= ""
        end
    end)
end

--界面关闭时调用（用于子类重写）
function RoleReturnListPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function RoleReturnListPanel:OnDestroy()

end

return RoleReturnListPanel