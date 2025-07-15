RoleItemView = {}
local this=RoleItemView
function RoleItemView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b, { __index = RoleItemView })
    return b
end
--初始化组件（用于子类重写）
function RoleItemView:InitComponent()

    self.EffectOrginLayer = -10
    self.frame = Util.GetGameObject(self.gameObject, "frame")
    self.icon = Util.GetGameObject(self.gameObject, "icon"):GetComponent("Image")
    self.heroStageImage = Util.GetGameObject(self.gameObject, "heroStageImage"):GetComponent("Image")
    self.lv = Util.GetGameObject(self.gameObject, "lv/Text"):GetComponent("Text")
    -- self.pos = Util.GetGameObject(self.gameObject, "pos/icon"):GetComponent("Image")
    self.pro = Util.GetGameObject(self.gameObject, "pro/Image"):GetComponent("Image")
    self.starGrid = Util.GetGameObject(self.gameObject, "star")
    self.starPre = Util.GetGameObject(self.gameObject, "starPre")
    self.heroNameGo = Util.GetGameObject(self.gameObject, "name")
    self.heroNameText = Util.GetGameObject(self.gameObject, "name/Text"):GetComponent("Text")
    self.heroHpGo = Util.GetGameObject(self.gameObject, "hp")
    self.heroHp = Util.GetGameObject(self.gameObject, "hp/fill"):GetComponent("Image")
    self.roleEffect = Util.GetGameObject(self.gameObject, "effect")
end

--绑定事件（用于子类重写）
function RoleItemView:BindEvent()

end

--添加事件监听（用于子类重写）
function RoleItemView:AddListener()

end

--移除事件监听（用于子类重写）
function RoleItemView:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RoleItemView:OnOpen(_heroDId,_isShowHeroName,_isShowHeroHp,_hpVal,_effectLayer)

    if _heroDId ==nil then
        return
    end
    self.heroData=HeroManager.GetSingleHeroData(_heroDId)
    _isShowHeroName = _isShowHeroName or false
    _effectLayer = _effectLayer or 0
    self.isShowHeroHp = _isShowHeroHp or false
    self.hpVal=_hpVal

    self.heroNameGo:SetActive(_isShowHeroName)
    self.heroHpGo:SetActive(self.isShowHeroHp)
    if self.heroData then
        self:OnShowHeroData(_effectLayer)
    end
end
function RoleItemView:OnShowHeroData(effectLayer)
    self.frame:GetComponent("Image").sprite = Util.LoadSprite(GetHeroCardQuantityImage[self.heroData.heroConfig.Quality])
    self.icon.sprite = Util.LoadSprite(self.heroData.painting)
    self.lv.text=self.heroData.lv
    -- self.pos.sprite=Util.LoadSprite(self.heroData.professionIcon)
    self.pro.sprite=Util.LoadSprite(GetProStrImageByProNum(self.heroData.heroConfig.PropertyName))
    self.roleEffect:SetActive(self.heroData.star >= 5)--
    Util.AddParticleSortLayer(self.roleEffect, effectLayer - self.EffectOrginLayer)
    self.EffectOrginLayer = effectLayer

    SetHeroStars(self.starGrid,self.heroData.star)
    self.heroNameText.text=GetLanguageStrById(self.heroData.heroConfig.ReadingName)

    if self.hpVal and self.isShowHeroHp then
        self.hpVal = self.hpVal <= 0 and 0 or self.hpVal
       
        self.heroHp.fillAmount=self.hpVal
        Util.SetGray(self.gameObject, self.hpVal <= 0)
    end

    Util.AddOnceClick(self.frame, function()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup,true,self.heroData.heroBackData)
    end)
end
function RoleItemView:AddClick(clickFun)
    Util.AddOnceClick(self.frame, function()
        if clickFun then
            clickFun()
        else
            UIManager.OpenPanel(UIName.RoleGetInfoPopup,true,self.heroData.heroBackData)
        end
    end)
end
function RoleItemView:SetEffectLayer(effectLayer)
    Util.AddParticleSortLayer(self.roleEffect, effectLayer - self.EffectOrginLayer)
    self.EffectOrginLayer = effectLayer
end
--界面关闭时调用（用于子类重写）
function RoleItemView:OnClose()

end

--界面销毁时调用（用于子类重写）
function RoleItemView:OnDestroy()

end

return RoleItemView