require("Base/BasePanel")
WorkShopEquipRebuildListPanel = Inherit(BasePanel)
local this = WorkShopEquipRebuildListPanel
local curSelectEquip={}
local oldSelectEquip={}
local curEquipQuality
local openThisPanel
local type
--初始化组件（用于子类重写）
function WorkShopEquipRebuildListPanel:InitComponent()

    this.titleText = Util.GetGameObject(self.gameObject, "bg/Text"):GetComponent("Text")
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.BtnSure = Util.GetGameObject(self.transform, "btnSure")
    this.equipPre = Util.GetGameObject(self.gameObject, "equipPre")
    --this.grid = Util.GetGameObject(self.gameObject, "scroll/grid")

    this.ScrollBar=Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.gameObject.transform,
            this.equipPre, this.ScrollBar, Vector2.New(935.16, 1104.9), 1, 5, Vector2.New(19.32,15))
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(-12.1, -972.3)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 1)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 1)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.ScrollView.transform:SetParent(Util.GetGameObject(self.transform, "scroll").transform)
end

--绑定事件（用于子类重写）
function WorkShopEquipRebuildListPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.BtnSure, function()
            self:ClosePanel()
            openThisPanel.UpdateEquipPosHeroData(type,curSelectEquip.data)
    end)
end

--添加事件监听（用于子类重写）
function WorkShopEquipRebuildListPanel:AddListener()

end

--移除事件监听（用于子类重写）
function WorkShopEquipRebuildListPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WorkShopEquipRebuildListPanel:OnOpen(...)

    curSelectEquip={}
    oldSelectEquip={}
    local equipData={...}
    type = equipData[1]--1 选择重铸装备 2 选择祭品装备
    if type==1 then
        curSelectEquip.data=equipData[3]
        openThisPanel= equipData[2]
    elseif type==2 then
        curEquipQuality=equipData[2]
        curSelectEquip.data=equipData[4]
        openThisPanel= equipData[3]
    end
end
function WorkShopEquipRebuildListPanel:OnShow()
    local equipDatas={}
    if type==1 then
        this.titleText.text=GetLanguageStrById(12034)
        equipDatas=EquipManager.GetAllEquipDataIfClear()
    elseif type==2 then
        this.titleText.text=GetLanguageStrById(12035)
        equipDatas=EquipManager.WorkShopGetEquipDataByEquipQuality(curEquipQuality.equipConfig.Quality,curEquipQuality.did)
    end
    this:SetItemData(equipDatas)
end
--设置背包列表数据
function this:SetItemData(_itemDatas)
    this.ItemsSortData(_itemDatas)
    this.ScrollView:SetData(_itemDatas, function (index, go)
        this.SingleItemDataShow(go, _itemDatas[index])
    end)
end
function this.SingleItemDataShow(_go,curEquipData)
    Util.GetGameObject(_go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(curEquipData.frame)
    Util.GetGameObject(_go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(curEquipData.icon)
    Util.GetGameObject(_go.transform, "name"):GetComponent("Text").text = GetLanguageStrById(curEquipData.itemConfig.Name)
    if curEquipData.equipConfig.IfClear ==1 then
        Util.GetGameObject(_go.transform,"resetLv"):SetActive(true)
        Util.GetGameObject(_go.transform, "resetLv"):GetComponent("Text").text = "+"..curEquipData.resetLv
    else
        Util.GetGameObject(_go.transform,"resetLv"):SetActive(false)
    end
    local equipBtn = Util.GetGameObject(_go.transform, "icon")
    Util.AddOnceClick(equipBtn, function()
        this.OnClickEnterHeroEquip(_go,curEquipData,1)
    end)
    Util.AddLongPressClick(equipBtn, function()
        UIManager.OpenPanel(UIName.EquipInfoPopup,curEquipData)
    end, 0.5)
    local equipChoosedBtn = Util.GetGameObject(_go.transform, "choosed")
    Util.AddOnceClick(equipChoosedBtn, function()
        this.OnClickEnterHeroEquip(_go,curEquipData,2)
    end)
    if curEquipData.upHeroDid~="0" then
        Util.GetGameObject(_go.transform, "upHeroInage"):SetActive(true)
    else
        Util.GetGameObject(_go.transform, "upHeroInage"):SetActive(false)
    end
    curEquipData.isSelect=2
    if curSelectEquip.data~=nil then
        if curSelectEquip.data.did==curEquipData.did then
            curEquipData.isSelect=1
            curSelectEquip.isSelect=1
            oldSelectEquip.isSelect=1
            curSelectEquip.go=_go
            oldSelectEquip.go=_go
        end
    end
    this.OnShowSingleCardData(_go,curEquipData,curEquipData.isSelect)
end
function this.OnClickEnterHeroEquip(go,equipDatas,type)

    if type==1 then
        curSelectEquip.data=equipDatas
        curSelectEquip.isSelect=1
        curSelectEquip.go=go
        this.OnShowSingleCardData(curSelectEquip.go,curSelectEquip.data,curSelectEquip.isSelect)
        if oldSelectEquip.go~=nil then
            oldSelectEquip.isSelect=2
            this.OnShowSingleCardData(oldSelectEquip.go,oldSelectEquip.data,oldSelectEquip.isSelect)
        end
        oldSelectEquip.go=curSelectEquip.go
        oldSelectEquip.isSelect=curSelectEquip.isSelect
        oldSelectEquip.data=curSelectEquip.data
    elseif type==2 then
        if curSelectEquip.go~=nil then
            curSelectEquip.isSelect=2
            this.OnShowSingleCardData(curSelectEquip.go,curSelectEquip.data,curSelectEquip.isSelect)
            curSelectEquip={}
            oldSelectEquip={}
        end
    end
end

function this.OnShowSingleCardData(go,equipData,isSelect)--isSelect 1选择  2 没选择
    
    if isSelect==1 then
        Util.GetGameObject(go.transform, "choosed"):SetActive(true)
    elseif isSelect==2 then
        Util.GetGameObject(go.transform, "choosed"):SetActive(false)
    end
end
function this.ItemsSortData(_itemDatas)
    table.sort(_itemDatas, function(a, b)
        local aUpHero=a.upHeroDid~="0" and 2 or 1
        local bUpHero=b.upHeroDid~="0" and 2 or 1
        if aUpHero==bUpHero then
            if a.itemConfig.Quantity == b.itemConfig.Quantity then
                return a.id > b.id
            else
                return a.itemConfig.Quantity > b.itemConfig.Quantity
            end
        else
            return aUpHero>bUpHero
        end
    end)
end
--界面关闭时调用（用于子类重写）
function WorkShopEquipRebuildListPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function WorkShopEquipRebuildListPanel:OnDestroy()

    this.ScrollView = nil
end

return WorkShopEquipRebuildListPanel