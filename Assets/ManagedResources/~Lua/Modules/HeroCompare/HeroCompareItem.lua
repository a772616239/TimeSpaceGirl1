require("Base/BasePanel")
HeroCompareItem = Inherit(BasePanel)
local this = HeroCompareItem

function this:InitComponent()
    self.iconGo = Util.GetGameObject(self.gameObject, "icon")
    self.icon = self.iconGo:GetComponent("Image")
    self.nameText = Util.GetGameObject(self.gameObject, "nameText"):GetComponent("Text")
    self.lvText = Util.GetGameObject(self.gameObject, "lvText"):GetComponent("Text")
    self.starGrid = Util.GetGameObject(self.gameObject, "starGrid")
    self.powerText = Util.GetGameObject(self.gameObject, "powerText"):GetComponent("Text")
    self.proImage = Util.GetGameObject(self.gameObject, "proImage"):GetComponent("Image")
    self.frameImage = self.gameObject:GetComponent("Image")
    self.tagText = Util.GetGameObject(self.gameObject, "tag"):GetComponent("Text")
end

function this:BindEvent()
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnOpen(heroData, tag)
    if not heroData then
        self:ShowEmpty(tag)
        return
    end
    self:ShowHero(heroData, tag)
end

function this:ShowEmpty(tag)
    self.icon.sprite = nil
    self.nameText.text = tag == "A" and "选择英雄A" or "选择英雄B"
    self.lvText.text = ""
    self.powerText.text = ""
    self.tagText.text = tag or ""
    SetHeroStars(self.starGrid, 0)
end

function this:ShowHero(heroData, tag)
    local cfg = heroData.heroConfig
    self.frameImage.sprite = Util.LoadSprite(GetHeroCardQuantityImage[cfg.Quality])
    self.icon.sprite = Util.LoadSprite(heroData.painting)
    self.nameText.text = GetLanguageStrById(cfg.ReadingName)
    self.lvText.text = "Lv." .. heroData.lv
    self.powerText.text = tostring(math.floor(heroData.warPower or 0))
    self.proImage.sprite = Util.LoadSprite(GetProStrImageByProNum(cfg.PropertyName))
    SetHeroStars(self.starGrid, heroData.star)
    self.tagText.text = tag or ""
end

function this:OnShow()
end

function this:OnClose()
end

function this:OnDestroy()
end

return HeroCompareItem
