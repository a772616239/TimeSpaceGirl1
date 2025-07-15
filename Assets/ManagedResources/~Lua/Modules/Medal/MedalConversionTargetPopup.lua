require("Base/BasePanel")
MedalConversionTargetPopup = Inherit(BasePanel)
local this = MedalConversionTargetPopup
local MedalConfig = ConfigManager.GetConfig(ConfigName.MedalConfig)
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local TabBox = require("Modules/Common/TabBox") 
local _TabData={ [1] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name =GetLanguageStrById(23144)},
                 [2] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name =GetLanguageStrById(23145)},
                 [3] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name =GetLanguageStrById(23146)},
                 [4] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_xuanzhong", name =GetLanguageStrById(23147)},
                } 
local curIndex = 1
local showPanel --MedalConversionPopup
local siteTypeList --满足交换条件的面板
local selectItem
local btnList = {}
local selfMedalConfigData

------------------------------勋章转化
--初始化组件（用于子类重写）
function MedalConversionTargetPopup:InitComponent()
	this.Mask = Util.GetGameObject(self.gameObject,"Mask")
    this.btnBack = Util.GetGameObject(self.gameObject,"btnBack")
    this.scroll = Util.GetGameObject(self.gameObject,"scroll")
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")  
    this.itemPre = Util.GetGameObject(self.gameObject,"ItemPre")

    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
    this.itemPre, nil, Vector2.New(this.scroll.transform.rect.width,  this.scroll.transform.rect.height), 1, 1, Vector2.New(60, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function MedalConversionTargetPopup:BindEvent()
    Util.AddClick(this.btnBack,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.Mask,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MedalConversionTargetPopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function MedalConversionTargetPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
--1.勋章转化选择panel 2.勋章Id  3.指定打开页签(默认第一个)
function MedalConversionTargetPopup:OnOpen(...)
    local args = {...}
    showPanel = args[1]
    this.itemData = args[2]
    curIndex = args[3] or 1
    --this.heroId=args[4]
    selfMedalConfigData = this.itemData.medalConfig
    siteTypeList = {}
    --所有满足条件的勋章
    local AllitemList = ConfigManager.GetAllConfigsDataByDoubleKey("MedalConfig", "Quality", selfMedalConfigData.Quality, "Star", selfMedalConfigData.Star)
    for k,v in ipairs(AllitemList) do
       local itemIdList = {}
       local siteType = v.SiteType
       if v.Id ~= selfMedalConfigData.Id then
            if siteTypeList[siteType] then
                table.insert(siteTypeList[siteType],v.Id)
                siteTypeList[siteType]=siteTypeList[siteType]
            else
                table.insert(itemIdList,v.Id)
                siteTypeList[siteType]=itemIdList
            end
        end
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MedalConversionTargetPopup:OnShow()
    --selectItem=itemId
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData, curIndex)
    
end
function MedalConversionTargetPopup:OnSortingOrderChange()
end


--界面关闭时调用（用于子类重写）
function MedalConversionTargetPopup:OnClose()
    if selectItem~=nil then
        showPanel:UpdateTargetData(selectItem)
    end
end

--界面销毁时调用（用于子类重写）
function MedalConversionTargetPopup:OnDestroy()

end
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    local select = Util.GetGameObject(tab, "select")
    select:GetComponent("Text").text = _TabData[index].name
    select:SetActive(status == "select")
    tabLab:SetActive(status == "default")
end

function this.SwitchView(index)
    btnList = {}
    local itemlist = siteTypeList[index]
    --selectItem=this.itemData.id
    this.ScrollView:SetData(itemlist, function(index, shopItem)
        this:SetData(shopItem,itemlist[index])
        -- if btnList[this.itemData.id] then
        --     Util.SetGray(btnList[this.itemData.id],true)
        -- end
    end)
    -- for k,v in pairs(btnList)
end

function this:SetData(go,data)
    local MedalConfigData = MedalConfig[data]--data.medalConfig

    go:SetActive(true)
    this.frame = Util.GetGameObject(go,"frame")
    this.icon = Util.GetGameObject(go,"frame/icon")
    this.name = Util.GetGameObject(go,"name")
    this.starGrid = Util.GetGameObject(go,"frame/starGrid")

    this.base = Util.GetGameObject(go,"base")
    this.baseIcon = Util.GetGameObject(this.base,"icon")
    this.baseName = Util.GetGameObject(this.base,"icon/name")
    this.baseValue = Util.GetGameObject(this.base,"icon/name/value")

    this.random = Util.GetGameObject(go,"random")--随机属性不显示
    -- this.randomIcon1=Util.GetGameObject(this.random,"icon1")
    -- this.randomeValue1=Util.GetGameObject(this.random,"icon1/value1")
    -- this.randomIcon2=Util.GetGameObject(this.random,"icon2")
    -- this.randomeValue2=Util.GetGameObject(this.random,"icon2/value2")

    local ConversionBtn = Util.GetGameObject(go,"ConversionBtn")

    SetHeroStars(this.starGrid,MedalConfigData.Star)
    this.frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(MedalConfigData.Quality))
    this.icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[data].ResourceID))
    this.name:GetComponent("Text").text = GetStringByEquipQua(MedalConfigData.Quality,string.format(GetLanguageStrById(23055), 
    MedalManager.GetQualityName(MedalConfigData.Quality), 
    MedalConfigData.Star,
    GetLanguageStrById(MedalConfigData.TypeName)))
    
    local PropertyConfigData = PropertyConfig[MedalConfigData.BasicAttr[1]]
    this.baseIcon:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfigData.Icon)
    this.baseName:GetComponent("Text").text = GetLanguageStrById(PropertyConfigData.Info)
    this.baseValue:GetComponent("Text").text = "+"..GetPropertyFormatStr(PropertyConfigData.Style,MedalConfigData.BasicAttr[2])

    btnList[data] = ConversionBtn

    if selectItem == data  then
        Util.SetGray(btnList[selectItem],true)
    else
        Util.SetGray(btnList[data],false)
    end
    
    Util.AddOnceClick(ConversionBtn, function()
        if btnList[selectItem] ~= nil then
            Util.SetGray(btnList[selectItem],false)
        end
        if data == this.itemData.id then
            PopupTipPanel.ShowTipByLanguageId(23062)
        else
            Util.SetGray(btnList[data],true)
            selectItem = data
            self:ClosePanel()
            -- MedalManager.ConversionMedal(this.itemData.idDyn,data,this.heroId,this.itemData.position,function()
            --     Util.SetGray(btnList[data],true)
            --     selectItem = data
            --     PopupTipPanel.ShowTip("转化成功")
            -- end)
        end
    end)
end


return MedalConversionTargetPopup