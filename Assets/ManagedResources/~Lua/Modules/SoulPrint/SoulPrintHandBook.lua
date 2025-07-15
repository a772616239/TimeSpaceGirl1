---- 魂印图鉴 ----
require("Base/BasePanel")
SoulPrintHandBook = Inherit(BasePanel)
local this = SoulPrintHandBook
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local orginLayer=0--层级
local allSoulPrintData={}--所有魂印数据
local curIndex = 0--当前选择索引


local chooseNum = 0
local tabs = {}
local itemData = {}
local currentDataList = {}
local chooseIdList = {}
local list={}

function SoulPrintHandBook:InitComponent()
    this.backBtn = Util.GetGameObject(this.gameObject, "BackBtn")
    this.BackMask = Util.GetGameObject(this.gameObject, "BackMask") --m5
    for i = 1, 4 do
        tabs[i] = Util.GetGameObject(this.gameObject, "Tabs/Btn" .. i)
    end
    this.selectBtn = Util.GetGameObject(this.gameObject, "Tabs/selectBtn")
    this.selectBtnText = Util.GetGameObject(this.selectBtn.transform, "Text"):GetComponent("Text")
    this.scrollRoot=Util.GetGameObject(this.gameObject,"ScrollRoot")
    this.pre=Util.GetGameObject(this.scrollRoot,"Pre")
    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollRoot.transform,this.pre, nil,--
    Vector2.New(this.scrollRoot.transform.rect.width,this.scrollRoot.transform.rect.height),1,4,Vector2.New(50,15))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    allSoulPrintData= ConfigManager.GetAllConfigsDataByKey(ConfigName.EquipConfig,"Position",5)
end

function SoulPrintHandBook:BindEvent()
    --tab按钮点击
    for i = 1, 4 do
        Util.AddClick(tabs[i], function()
            if (curIndex == i) then
                this.selectBtn:SetActive(false)
            else
                this.selectBtn:SetActive(true)
            end
            curIndex = i
            this.selectBtn.transform.localPosition = tabs[i].transform.localPosition
            if (not this.selectBtn.activeSelf) then
                curIndex = 0--没有选定筛选按钮显示全部魂印
            end
            this.OnRefresh(curIndex)
            this.selectBtnText.text = Util.GetGameObject(tabs[i].transform, "Text"):GetComponent("Text").text
        end)
    end

    --关闭页面
    Util.AddClick(this.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.BackMask, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end) --m5
end

function SoulPrintHandBook:AddListener()
end
function SoulPrintHandBook:RemoveListener()
end

function SoulPrintHandBook:OnSortingOrderChange()
    --特效层级重设
    for i=1,#list do
        Util.AddParticleSortLayer(list[i], this.sortingOrder - orginLayer)
    end
    orginLayer = self.sortingOrder
end

function SoulPrintHandBook:OnOpen()

end

function SoulPrintHandBook:OnShow()
    curIndex=0
    this.OnRefresh(curIndex)
end

function SoulPrintHandBook:OnClose()
    this.selectBtn:SetActive(false)
end

function SoulPrintHandBook:OnDestroy()
    this.scrollView=nil
end

local orginLayer2=0
--打开页面时，页面数据刷新
function this.OnRefresh(index)
    local tempData={}
    if index==0 then
        tempData=allSoulPrintData
    else
        for i,v in ipairs(allSoulPrintData) do
            if v.Quality==(index+3) then
                table.insert( tempData, v)
            end
        end
    end
    --预设容器
    list={}
    this.scrollView:SetData(tempData,function(index,root)
        this.SetScrollPre(root,tempData[index])
        table.insert(list,root)
    end)
    this.scrollView:SetIndex(1)

    --特效层级重设
    for i=1,#list do
        Util.AddParticleSortLayer(list[i], this.sortingOrder - orginLayer2)
    end
    orginLayer2 = this.sortingOrder
    orginLayer = this.sortingOrder
end
--设置预设
function this.SetScrollPre(root,data)
    local frame=Util.GetGameObject(root,"Frame"):GetComponent("Image")
    local icon=Util.GetGameObject(root,"circleFrameBg/Icon"):GetComponent("Image")
    local name=Util.GetGameObject(root,"Name"):GetComponent("Text")
    Util.AddOnceClick(root,function()
        UIManager.OpenPanel(UIName.SoulPrintPopUp,3,nil,data.Id,nil)
    end)

    frame.sprite=Util.LoadSprite(GetQuantityImageByquality(data.Quality))
    icon.sprite=Util.LoadSprite(GetResourcePath(itemConfig[data.Id].ResourceID))
    Util.GetGameObject(root,"circleFrameBg"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig[data.Id].Quantity].circleBg2)
    Util.GetGameObject(root,"circleFrameBg/circleFrame"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig[data.Id].Quantity].circle)
    name.text=data.Name
end

return SoulPrintHandBook