require("Base/BasePanel")
MapAwardPanel = Inherit(BasePanel)
local this=MapAwardPanel
local nameText--名字
local nameInfoText--名字詳情
local awardText1--
local awardText2--
local itemUpGrid--父级
local heroGrid--父级
local sureBtn
local closeBtn
local itemListUp
local AwardItemData=ConfigManager.GetConfig(ConfigName.ItemConfig)
--初始化组件（用于子类重写）
function MapAwardPanel:InitComponent()

    this.nameText=Util.GetGameObject (self.transform, "title/nameText")
    this.nameInfoText=Util.GetGameObject (self.transform, "title/nameInfoText")
    this.awardText1=Util.GetGameObject (self.transform, "middle/awardText")
    this.itemUpGrid=Util.GetGameObject (self.transform,"middle/awardGrid")
    this.itemDownGrid=Util.GetGameObject (self.transform,"middle/bagGrid")
    this.heroGrid=Util.GetGameObject (self.transform,"heroRect/heroGrid")
    this.item = Util.GetGameObject(self.gameObject, "item")
    this.sureBtn=Util.GetGameObject (self.transform,"sureBtn")
    this.closeBtn=Util.GetGameObject (self.transform,"bg")
    --背包实例化

end

--绑定事件（用于子类重写）
function MapAwardPanel:BindEvent()

    Util.AddClick(this.sureBtn, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.closeBtn, function ()
        --self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MapAwardPanel:AddListener()

end

--移除事件监听（用于子类重写）
function MapAwardPanel:RemoveListener()

end
--界面打开时调用（用于子类重写）
function MapAwardPanel:OnOpen(...)

    local arg={...}
    --itemListUp={}
    --for i = 1, 5 do
    --    itemListUp[i]={}
    --    itemListUp[i].id=i
    --    local itemData=AwardItemData[i]
    --    itemListUp[i].frame=itemData.frame
    --    itemListUp[i].icon=itemData.icon
    --    itemListUp[i].num=i
    --    itemListUp[i].name=itemData.Name
    --end
    this.nameText:GetComponent("Text").text=GetLanguageStrById(11186)
    this.nameInfoText:GetComponent("Text").text=GetLanguageStrById(11187)
    --this.awardText1:GetComponent("Text").text="战利品--关闭后加入背包"

    --Util.ClearChild(this.itemUpGrid.transform)
    --for i, v in pairs(itemListUp) do
    --    local go = SubUIManager.Open(SubUIConfig.ItemView, self.itemUpGrid.transform,{frame=v.frame,icon=v.icon,num=v.num})
    --    Util.AddClick(Util.GetGameObject(go.transform,"frame"),function ()
    --        PopupTipPanel.ShowTip(v.name)
    --    end)
    --end

    Util.ClearChild(this.heroGrid.transform)
    for i=1, #MapManager.formationList do
        local heroData = HeroManager.GetSingleHeroData(MapManager.formationList[i].heroId)

        local go = newObject(this.item)

        go.transform:SetParent(this.heroGrid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go:SetActive(true)

        Util.GetGameObject(go,"frame"):GetComponent("Image").sprite=Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality,heroData.star))
        Util.GetGameObject(go,"icon"):GetComponent("Image").sprite=Util.LoadSprite(heroData.icon)
        Util.GetGameObject(go, "lv/Text"):GetComponent("Text").text = heroData.lv
        Util.GetGameObject(go,"icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
        Util.GetGameObject(go, "pro/icon"):GetComponent("Image").sprite = Util.LoadSprite(heroData.professionIcon)
        local starGrid = Util.GetGameObject(go, "star")
        --local starPre = Util.GetGameObject(go, "starPre")
        SetHeroStars(starGrid, heroData.star)

        Util.AddOnceClick(go, function ()
            UIManager.OpenPanel(UIName.MapRoleInfoPopup, heroData)
        end)
    end
    --英雄实例化
    --[[
    Util.ClearChild(this.heroGrid.transform)
    for i, v in pairs(panleData.herosData) do
        logError(panleData.herosData[1].name)
        local heroData=HeroConfig[v.id]
        SubUIManager.Open(SubUIConfig.RoleItemView, self.heroGrid.transform,{frame=heroData.quality,icon=heroData.icon,profession=heroData.profession,
                                                                             lv=v.lv,star=v.star,heroName=heroData.name,curHp=v.expCurVal,maxHp=v.expMaxVal})
    end]]--

end

--界面关闭时调用（用于子类重写）
function MapAwardPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function MapAwardPanel:OnDestroy()

end

return MapAwardPanel