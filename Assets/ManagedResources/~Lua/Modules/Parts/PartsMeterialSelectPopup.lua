require("Base/BasePanel")
PartsMeterialSelectPopup = Inherit(BasePanel)
local this = PartsMeterialSelectPopup
local generalData = ConfigManager.GetConfig(ConfigName.GeneralConfig)

local curHeroData
--初始化组件（用于子类重写）
function PartsMeterialSelectPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.btnSure = Util.GetGameObject(self.gameObject, "btnSure")
    this.numText = Util.GetGameObject(self.gameObject, "numText"):GetComponent("Text")

    this.Scroll = Util.GetGameObject(self.gameObject, "scroll")
    this.item = Util.GetGameObject(self.gameObject, "item")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.item, nil,
            Vector2.New(w, h), 1,4, Vector2.New(5, 5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.noHero = Util.GetGameObject(self.gameObject, "noHero")
end

--绑定事件（用于子类重写）
function PartsMeterialSelectPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnSure, function()
        this.openThisPanel.UpdateSelect()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function PartsMeterialSelectPopup:AddListener()
end

--移除事件监听（用于子类重写）
function PartsMeterialSelectPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function PartsMeterialSelectPopup:OnOpen(...)
    local args = {...}
    this.openThisPanel = args[1]
    this.star = args[2]
    this.needNum = args[3]
    curHeroData = args[4]
    this.IsSameClan = args[5]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PartsMeterialSelectPopup:OnShow()
    -- local allHeros = HeroManager.GetAllHeroDatas()
    -- local accordHeros = {}
    -- for i, v in ipairs(allHeros) do
    --     local isIn = true
    --     for n,w in pairs(FormationManager.formationList) do
    --         for m = 1, #w.teamHeroInfos do
    --             if v.dynamicId == w.teamHeroInfos[m].heroId then
    --                 isIn = false
    --             end
    --         end
    --     end
    --     if v.star ~= this.star and this.star ~= 0 then --< 0全部进入
    --         isIn = false
    --     end
    --     if v.lockState == 1 then
    --         isIn = false
    --     end

    --     if this.IsSameClan == 1 and v.heroConfig.PropertyName ~= curHeroData.heroConfig.PropertyName then
    --         isIn = false
    --     end
    --     if isIn then
    --         table.insert(accordHeros, v)
    --     end
    -- end
    local general = generalData[curHeroData.heroConfig.PropertyName]
    local heroData = {property = general.LockHero[3]}
    local upStarHeroListData = HeroManager.GetUpStarHeroListData(23,heroData)
    local accordHeros= upStarHeroListData.heroList

    this.HeroSortData(accordHeros)

    this.scrollView:SetData(accordHeros, function(index, root)
        this.OnShowSingleCardData(root, accordHeros[index])
    end)

    this.numText.text = string.format(GetLanguageStrById(11872), this.needNum,this.star)..GetLanguageStrById(11871)
    -- this.numText.text = string.format("%s/%s",LengthOfTable(this.openThisPanel.curSelectHeroIds),this.needNum)
    this.noHero:SetActive(#accordHeros < 1)
end

function PartsMeterialSelectPopup.OnShowSingleCardData(go,heroData)--isSelect 1选择  2 没选择
    local curSelectHeroList = this.openThisPanel.curSelectHeroIds
    local curNeedRoleNum = this.needNum
    local choosed = Util.GetGameObject(go.transform, "select/Image")
    local select = Util.GetGameObject(go.transform, "selectImg")
    choosed:SetActive(false)
    select:SetActive(false)
    if curSelectHeroList[heroData.dynamicId] then
        curSelectHeroList[heroData.dynamicId] = heroData
        choosed:SetActive(true)
        select:SetActive(true)
    end
    Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(go.transform, "lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
    Util.GetGameObject(go.transform, "pro/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    local starGrid = Util.GetGameObject(go.transform, "star")
    SetHeroStars(starGrid,  heroData.star)
    local cardBtn = Util.GetGameObject(go.transform, "icon")
    Util.AddOnceClick(cardBtn, function()
        if curSelectHeroList[heroData.dynamicId] then
            choosed:SetActive(false)
            select:SetActive(false)
            curSelectHeroList[heroData.dynamicId] = nil
            -- this.numText.text = string.format("%s/%s",LengthOfTable(curSelectHeroList),curNeedRoleNum)
            return
        end
        if LengthOfTable(curSelectHeroList)>=curNeedRoleNum then
            PopupTipPanel.ShowTipByLanguageId(10660)
            return
        end

        curSelectHeroList[heroData.dynamicId]=heroData
        choosed:SetActive(true)
        select:SetActive(true)
        -- this.numText.text = string.format("%s/%s",LengthOfTable(curSelectHeroList),curNeedRoleNum)
    end)
end

function this.HeroSortData(heroData)
    table.sort(heroData, function(a, b)
        if a.heroConfig.Star == b.heroConfig.Star then
            if a.lv == b.lv then
                return a.id > b.id
            else
                return a.lv < b.lv
            end
        else
            return a.heroConfig.Star < b.heroConfig.Star
        end
    end)
end

--界面关闭时调用（用于子类重写）
function PartsMeterialSelectPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function PartsMeterialSelectPopup:OnDestroy()
end

return PartsMeterialSelectPopup