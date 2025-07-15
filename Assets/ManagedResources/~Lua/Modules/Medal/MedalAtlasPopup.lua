require("Base/BasePanel")
MedalAtlasPopup = Inherit(BasePanel)
local this = MedalAtlasPopup
local MedalConfig = ConfigManager.GetConfig(ConfigName.MedalConfig)
local MedalSuitConfig = ConfigManager.GetConfig(ConfigName.MedalSuitConfig)
local MedalSuitType = ConfigManager.GetConfig(ConfigName.MedalSuitType)
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local TabBox = require("Modules/Common/TabBox") 
local _TabData={ [1] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong", select = "cn2-x1_haoyou_biaoqian_weixuanzhong", name = GetLanguageStrById(50312)},
                 [2] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", name = GetLanguageStrById(50313)},
                 [3] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", name = GetLanguageStrById(50314)},
                } 
local QualityTypeList --满足交换条件的面板

----------------------------------图谱
--初始化组件（用于子类重写）
function MedalAtlasPopup:InitComponent()
    this.Mask=Util.GetGameObject(self.gameObject,"Mask")
    this.btnBack = Util.GetGameObject(self.gameObject,"btnBack")
    this.scroll = Util.GetGameObject(self.gameObject,"scroll")
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")  
    this.itemPre = Util.GetGameObject(self.gameObject,"ItemPre")

    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
    this.itemPre, nil, Vector2.New(this.scroll.transform.rect.width,  this.scroll.transform.rect.height), 1, 2, Vector2.New(10, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2

    this.mask = Util.GetGameObject(self.gameObject,"TabBox/mask")
    this.isFirstOpen = true
    this.maskCurPos = this.mask.transform.position
end

--绑定事件（用于子类重写）
function MedalAtlasPopup:BindEvent()
    Util.AddClick(this.btnBack,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.Mask,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MedalAtlasPopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function MedalAtlasPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MedalAtlasPopup:OnOpen(...)
    local args = {...}
    QualityTypeList={}
    --所有满足条件的勋章
    local AllitemList = {}
    for k,v in ConfigPairs(MedalConfig) do
        table.insert(AllitemList, v)
    end  
    for k,v in ipairs(AllitemList) do
       local itemIdList = {}
       local QualityType = v.Quality
       if QualityTypeList[QualityType] then
           table.insert(QualityTypeList[QualityType],v.Id)
           QualityTypeList[QualityType] = QualityTypeList[QualityType]
       else
           table.insert(itemIdList,v.Id)
           QualityTypeList[QualityType] = itemIdList
       end
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MedalAtlasPopup:OnShow()
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData,1)
    
    this.mask.transform.position = this.maskCurPos
    Util.GetGameObject(this.mask,"Text"):GetComponent("Text").text =  _TabData[1].name
end
function MedalAtlasPopup:OnSortingOrderChange()
end


--界面关闭时调用（用于子类重写）
function MedalAtlasPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function MedalAtlasPopup:OnDestroy()

end
function this.TabAdapter(tab, index, status)
    Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    Util.GetGameObject(tab, "Text"):GetComponent("Text").text = _TabData[index].name

    if this.isFirstOpen then
        if index == 3 then
            this.isFirstOpen = false
        end
    else
        this.mask.transform.position = tab.transform.position
        Util.GetGameObject(this.mask,"Text"):GetComponent("Text").text = Util.GetGameObject(tab, "Text"):GetComponent("Text").text
    end
end

function this.SwitchView(index)
    local itemlist = QualityTypeList[index + 2]
    this.ScrollView:SetData(itemlist, function(index, Item)
        this:SetData(Item,itemlist[index])
    end)
end

function this:SetData(go,data)
    go:SetActive(true)
    local MedalConfigData = MedalConfig[data]

    this.frame = Util.GetGameObject(go,"frame")
    this.icon = Util.GetGameObject(go,"frame/icon")
    -- this.pro = Util.GetGameObject(go,"frame/pro")
    --this.starPre=Util.GetGameObject(go,"frame/starPre")
    this.star = Util.GetGameObject(go,"frame/star")
    this.name = Util.GetGameObject(go,"name")
    this.type = Util.GetGameObject(go,"type")
    -- this.suitIcon = Util.GetGameObject(go,"suitIcon")
    this.suitName = Util.GetGameObject(go,"suitName")

    this.frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(MedalConfigData.Quality))
    this.icon:GetComponent("Image").sprite = Util.LoadSprite(MedalConfigData.Icon)
    -- this.pro:GetComponent("Text").text = MedalManager.GetQualityName(MedalConfigData.Quality)
    SetHeroStars(this.star, MedalConfigData.Star)

    local Name = MedalSuitType[MedalSuitConfig[MedalConfigData.Suit].Type].Name
    this.name:GetComponent("Text").text = string.format("[%s]%s", MedalManager.GetQualityName(MedalConfigData.Quality),string.sub(GetLanguageStrById(MedalConfigData.TypeName), 1, 2*3))
    this.type:GetComponent("Text").text = string.format(GetLanguageStrById(23054),string.sub(GetLanguageStrById(Name),1, 2*3))
    -- this.suitIcon:GetComponent("Image").sprite = Util.LoadSprite(MedalSuitType[MedalSuitConfig[MedalConfigData.Suit].Type].Icon)
    this.suitName:GetComponent("Text").text = GetLanguageStrById(Name)

    Util.AddOnceClick(this.frame, function()
        UIManager.OpenPanel(UIName.MedalParticularsPopup,data,nil,false,nil,false,false)--data勋章ID 槽位ID  随机属性ID 已添加的勋章列表
    end)

end


return MedalAtlasPopup