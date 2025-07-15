require("Base/BasePanel")
MedalSameTipPopup = Inherit(BasePanel)
local this = MedalSameTipPopup

--初始化组件（用于子类重写）
function MedalSameTipPopup:InitComponent()
    this.itemList = Util.GetGameObject(self.gameObject,"itemList")
    this.allItem = {}
    for i = 1, 4 do
        local data = Util.GetGameObject(this.itemList,"item"..i)
        table.insert(this.allItem,data)
    end

    this.backBtn = Util.GetGameObject(self.gameObject,"backBtn")
    this.cancelBtn = Util.GetGameObject(self.gameObject,"cancelBtn")
    this.sureBtn = Util.GetGameObject(self.gameObject,"sureBtn")
end

--绑定事件（用于子类重写）
function MedalSameTipPopup:BindEvent()
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.cancelBtn,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.sureBtn,function()
        if this.fun ~= nil then
            this.fun()
        end
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MedalSameTipPopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function MedalSameTipPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MedalSameTipPopup:OnOpen(...)
    local args = {...}
    this.heroList = args[1]
    this.medalList = args[2]
    this.fun = args[3]  
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MedalSameTipPopup:OnShow()
    for k,v in pairs(this.allItem) do
        v:SetActive(#this.heroList >= k)

        if #this.heroList >= k then
            local medal = Util.GetGameObject(v,"medal")
            local medalData = MedalManager.GetOneMedalData(this.medalList[k])
            Util.GetGameObject(medal, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(medalData.medalConfig.Quality))
            Util.GetGameObject(medal, "icon"):GetComponent("Image").sprite = Util.LoadSprite(medalData.icon)
            SetHeroStars(Util.GetGameObject(medal,"icon/grid"),medalData.medalConfig.Star)

            local hero = Util.GetGameObject(v,"hero")
            local heroData = HeroManager.GetSingleHeroData(this.heroList[k])
            Util.GetGameObject(hero, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality,heroData.star))
            Util.GetGameObject(hero, "lv"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroData.heroConfig.Quality,heroData.star))
            Util.GetGameObject(hero, "lv/Text"):GetComponent("Text").text = heroData.lv
            -- Util.GetGameObject(hero, "Text"):GetComponent("Text").text = heroData.heroConfig.ReadingName
            Util.GetGameObject(hero, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
            Util.GetGameObject(hero, "proIconBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroData.heroConfig.Quality,heroData.star))
            Util.GetGameObject(hero, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
            local starGrid = Util.GetGameObject(hero, "star")
            SetHeroStars(starGrid, heroData.star)
        end
    end
end
function MedalSameTipPopup:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function MedalSameTipPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function MedalSameTipPopup:OnDestroy()

end


return MedalSameTipPopup