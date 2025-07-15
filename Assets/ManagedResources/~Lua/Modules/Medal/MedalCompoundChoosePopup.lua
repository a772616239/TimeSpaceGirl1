require("Base/BasePanel")
MedalCompoundChoosePopup = Inherit(BasePanel)
local this = MedalCompoundChoosePopup
local MedalConfig = ConfigManager.GetConfig(ConfigName.MedalConfig)
local MedalSuitConfig = ConfigManager.GetConfig(ConfigName.MedalSuitConfig)
local MedalSuitType = ConfigManager.GetConfig(ConfigName.MedalSuitType)
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local TabBox = require("Modules/Common/TabBox") 
local _TabData = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_xuanzhong"}

local seleceList = {}--选中的勋章

-------------------------------合成材料
--初始化组件（用于子类重写）
function MedalCompoundChoosePopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject,"btnBack")
    this.scroll = Util.GetGameObject(self.gameObject,"scroll")
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")
    this.itemPre = Util.GetGameObject(self.gameObject,"itemPre")

    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
    this.itemPre, nil, Vector2.New(this.scroll.transform.rect.width,  this.scroll.transform.rect.height), 1, 4, Vector2.New(5, 5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2

    this.SureBtn = Util.GetGameObject(self.gameObject,"SureBtn")
    this.num = Util.GetGameObject(self.gameObject,"num")
end

--绑定事件（用于子类重写）
function MedalCompoundChoosePopup:BindEvent()
    Util.AddClick(this.btnBack,function()
        this.openPanel.UpdataPanel(seleceList)
        self:ClosePanel()
    end)
    Util.AddClick(this.SureBtn,function()
        this.openPanel.UpdataPanel(seleceList)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MedalCompoundChoosePopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function MedalCompoundChoosePopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MedalCompoundChoosePopup:OnOpen(...)
    local args = {...}
    this.openPanel = args[1]
    this.alreadySelect = args[2]
    this.tabType = {}
    table.insert(this.tabType, 0)
    for k,v in ConfigPairs(MedalSuitType) do
        table.insert(this.tabType, k)
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MedalCompoundChoosePopup:OnShow()
    seleceList = this.alreadySelect
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, this.tabType,1)
    this.num:GetComponent("Text").text = GetLanguageStrById(11957) .. string.format("  %s/3",LengthOfTable(seleceList))
end

function MedalCompoundChoosePopup:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function MedalCompoundChoosePopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function MedalCompoundChoosePopup:OnDestroy()
end

function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    local select =Util.GetGameObject(tab, "select")
    if index == 1 and status == "default" then
        Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong")
    else
        Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[status])
    end
    --tabLab:GetComponent("Text").text = _TabData[index].name
    if index-1 == 0 then
        tabLab:GetComponent("Text").text = GetLanguageStrById(10191)
        select:GetComponent("Text").text = GetLanguageStrById(10191)
    else
        local MedalSuit = MedalManager.GetMedalSuitInfoByType(index-1)
        tabLab:GetComponent("Text").text = GetLanguageStrById(MedalSuit.Name)
        select:GetComponent("Text").text = GetLanguageStrById(MedalSuit.Name)
    end
    select:SetActive(status == "select")
    tabLab:SetActive(status == "default")
end

function this.SwitchView(index)
    local itemlist = MedalManager.MedalDaraByType(index-1)
    --seleceList = {}
    this.MedalSortData(itemlist)
    this.ScrollView:SetData(itemlist, function(index, Item)
        this:SetData(Item,itemlist[index])
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

function this:SetData(go,data)
    local MedalConfigData = data.medalConfig
    go:SetActive(true)
    this.frame = Util.GetGameObject(go,"frame")
    this.icon = Util.GetGameObject(go,"icon")
    -- this.pro = Util.GetGameObject(go,"pro")
    -- this.starPre = Util.GetGameObject(go,"starPre")
    -- this.star = Util.GetGameObject(go,"star/num")
    -- this.name = Util.GetGameObject(go,"name")
    this.starGrid = Util.GetGameObject(go,"starGrid")
    local btn = Util.GetGameObject(go,"btn")
    local selsect = Util.GetGameObject(go,"bg")
    -- local btnSelect = Util.GetGameObject(go,"btn/Image")

    this.frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(MedalConfigData.Quality))
    this.icon:GetComponent("Image").sprite = Util.LoadSprite(data.icon)
    SetHeroStars(this.starGrid,MedalConfigData.Star)
    -- this.pro:GetComponent("Text").text = MedalManager.GetQualityName(MedalConfigData.Quality)
    -- this.name:GetComponent("Text").text = MedalConfigData.Id
    -- this.star:SetActive(false)
    --if MedalConfigData.Star > 1 then
        -- this.star:SetActive(true)
        -- this.star:GetComponent("Text").text = MedalConfigData.Star
    --end
    btn:SetActive(false)
    selsect:SetActive(false)

    Util.AddOnceClick(this.frame, function()
        UIManager.OpenPanel(UIName.MedalParticularsPopup,data,nil,false,nil,true,false)
    end)
    
    if seleceList[data.idDyn] then
        btn:SetActive(true)
        selsect:SetActive(true)
    else
        btn:SetActive(false)
        selsect:SetActive(false)
    end
    Util.AddOnceClick(go, function()
        if seleceList[data.idDyn] then
           seleceList[data.idDyn] = nil
           btn:SetActive(false)
           selsect:SetActive(false)
        else
            if LengthOfTable(seleceList) >= 3 then
                PopupTipPanel.ShowTip(GetLanguageStrById(23057))
                return
            end

            if LengthOfTable(seleceList) == 0 then
                this.firstid = nil
            end
            if LengthOfTable(seleceList) == 1 then
                for k,v in pairs(seleceList)do
                    this.firstid = v.id
                end
            end
            if this.firstid then
                if data.id == this.firstid then
                    seleceList[data.idDyn] = data
                    btn:SetActive(true)
                    selsect:SetActive(true)
                else
                    PopupTipPanel.ShowTip(GetLanguageStrById(23058))
                end
            else
                seleceList[data.idDyn] = data
                btn:SetActive(true)
                selsect:SetActive(true)
            end
        end
        this.num:GetComponent("Text").text = GetLanguageStrById(11957) .. string.format("  %s/3",LengthOfTable(seleceList))
    end)
end

return MedalCompoundChoosePopup