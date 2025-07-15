require("Base/BasePanel")
MedalChangelPopup = Inherit(BasePanel)
local this = MedalChangelPopup
local MedalConfig = ConfigManager.GetConfig(ConfigName.MedalConfig)
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
--初始化组件（用于子类重写）
function MedalChangelPopup:InitComponent()
    this.itemPre = Util.GetGameObject(self.gameObject,"ItemPre")
    this.btnBack = Util.GetGameObject(self.gameObject,"btnBack")
	this.Mask = Util.GetGameObject(self.gameObject,"Mask")

    this.scroll = Util.GetGameObject(self.gameObject,"scroll")
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
    this.itemPre, nil, Vector2.New(this.scroll.transform.rect.width,  this.scroll.transform.rect.height), 1, 1, Vector2.New(0, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
    this.ScrollView.elastic = false
end

--绑定事件（用于子类重写）
function MedalChangelPopup:BindEvent()
    Util.AddClick(this.btnBack,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.Mask,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MedalChangelPopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function MedalChangelPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
--1.槽位Id
function MedalChangelPopup:OnOpen(...)
    local args = {...}
    this.site = args[1]
    this.heroId = args[2]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MedalChangelPopup:OnShow()

    --this.itemlist = {300001,300002,300003,302101,314204,380101,380201}--TODO获取背包里对应槽位的勋章信息

    local medalSiteList = MedalManager.MedalDaraBySite(this.site,this.heroId)

    if #medalSiteList > 1 then
        this.MedalSortData(medalSiteList)
    end

    this.ScrollView:SetData(medalSiteList, function(index, shopItem)
        this:SetData(shopItem, medalSiteList[index])
    end)
end

function this.MedalSortData(medalData)
    table.sort(medalData,function (a,b)
        if a.itemConfig.Quantity > b.itemConfig.Quantity then
            if a.itemConfig.Id > b.itemConfig.Id then
                return a.id > b.id
            else
                return a.id < b.id
            end
        end
    end)
end

function MedalChangelPopup:OnSortingOrderChange()

end

--界面关闭时调用（用于子类重写）
function MedalChangelPopup:OnClose()
    this.medalSiteList = nil
end

--界面销毁时调用（用于子类重写）
function MedalChangelPopup:OnDestroy()

end

function this:SetData(go,data)
    go:SetActive(true)
    local MedalConfigData = data.medalConfig
    this.frame = Util.GetGameObject(go,"frame")
    this.icon = Util.GetGameObject(go,"frame/icon")
    this.name = Util.GetGameObject(go,"name")
    this.star = Util.GetGameObject(go,"star")

    this.base = Util.GetGameObject(go,"base")
    this.baseIcon = Util.GetGameObject(this.base,"icon")
    this.baseName = Util.GetGameObject(this.base,"icon/name")
    this.baseValue = Util.GetGameObject(this.base,"icon/name/value")

    this.random = Util.GetGameObject(go,"random")
    this.randomIcon1 = Util.GetGameObject(this.random,"icon1")
    -- this.randomeValue1 = Util.GetGameObject(this.random,"icon1/value")
    this.randomIcon2 = Util.GetGameObject(this.random,"icon2")
    -- this.randomeValue2=Util.GetGameObject(this.random,"icon2/value")

    this.random:SetActive(false)
    this.randomIcon1:SetActive(false)
    this.randomIcon2:SetActive(false)

    this.ChangeBtn = Util.GetGameObject(go,"ChangeBtn")

    SetHeroStars(this.star,MedalConfigData.Star)
    this.frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(MedalConfigData.Quality))
    this.icon:GetComponent("Image").sprite = Util.LoadSprite(data.icon)
    this.name:GetComponent("Text").text = string.format(GetLanguageStrById(23055), MedalManager.GetQualityName(MedalConfigData.Quality), MedalConfigData.Star,GetLanguageStrById(MedalConfigData.TypeName))
    
    local PropertyConfigData = PropertyConfig[MedalConfigData.BasicAttr[1]]
    this.baseIcon:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfigData.Icon)
    this.baseName:GetComponent("Text").text = GetLanguageStrById(PropertyConfigData.Info)
    this.baseValue:GetComponent("Text").text = "+"..GetPropertyFormatStr(PropertyConfigData.Style,MedalConfigData.BasicAttr[2])

    local RandomProperty = data.RandomProperty
    if RandomProperty ~= nil and #RandomProperty>0 then
        this.random:SetActive(true)
        for i = 1, #RandomProperty do
            Util.GetGameObject(this.random,"icon"..i):SetActive(true)
            local id = RandomProperty[i].id
            local value = RandomProperty[i].value
            
            Util.GetGameObject(this.random,"icon" .. i .. "/icon"):GetComponent("Image").sprite = Util.LoadSprite(PropertyConfig[id].Icon)
            Util.GetGameObject(this.random,"icon" .. i .. "/value"):GetComponent("Text").text = string.format("%s  +%s",GetLanguageStrById(PropertyConfig[id].Info),GetPropertyFormatStr(PropertyConfig[id].Style,value))
        end
    end

    Util.AddOnceClick(this.frame, function()
       
    end)
    Util.AddOnceClick(this.ChangeBtn, function()
        MedalManager.WearMedal(this.heroId,data.idDyn,this.site,function() 
            self:ClosePanel()
        end)
    end)

end

return MedalChangelPopup