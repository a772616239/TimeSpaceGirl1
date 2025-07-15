require("Base/BasePanel")
WorkShopRuneListPanel = Inherit(BasePanel)
local this = WorkShopRuneListPanel
local curSelectEquip={}
local oldSelectEquip={}
local openThisPanel
local fuwenQuality
--初始化组件（用于子类重写）
function WorkShopRuneListPanel:InitComponent()

    this.titleText = Util.GetGameObject(self.gameObject, "bg/Text"):GetComponent("Text")
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.BtnSure = Util.GetGameObject(self.transform, "btnSure")
    this.runePre = Util.GetGameObject(self.gameObject, "runePre")
    --this.grid = Util.GetGameObject(self.gameObject, "scroll/grid")

    this.ScrollBar=Util.GetGameObject(self.gameObject, "Scrollbar"):GetComponent("Scrollbar")
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.gameObject.transform,
            this.runePre, this.ScrollBar, Vector2.New(904.4, 995), 1, 5, Vector2.New(19.32,15))
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(-8.1, -924)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 1)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 1)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.ScrollView.transform:SetParent(Util.GetGameObject(self.transform, "scroll").transform)
end

--绑定事件（用于子类重写）
function WorkShopRuneListPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.BtnSure, function()
        self:ClosePanel()
        openThisPanel.UpdatePosFuwenData(curSelectEquip.data)
    end)
end

--添加事件监听（用于子类重写）
function WorkShopRuneListPanel:AddListener()

end

--移除事件监听（用于子类重写）
function WorkShopRuneListPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WorkShopRuneListPanel:OnOpen(...)

    curSelectEquip={}
    oldSelectEquip={}
    local fuwenData={...}
    fuwenQuality = fuwenData[1]
    openThisPanel= fuwenData[2]
    curSelectEquip.data= fuwenData[3]

end
function WorkShopRuneListPanel:OnShow()
    this:SetItemData()

    --local fuwenDatas=BagManager.GetBagItemDataByQuDownAll(6,fuwenQuality)
    --Util.ClearChild(this.grid.transform)
    --for i = 1, #fuwenDatas do
    --    local curFuwenData=fuwenDatas[i]
    --    local go = newObject(this.runePre)
    --    go.transform:SetParent(this.grid.transform)
    --    go.transform.localScale = Vector3.one
    --    go.transform.localPosition = Vector3.zero
    --    go:SetActive(true)
    --    Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(curFuwenData.frame)
    --    Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(curFuwenData.icon)
    --    Util.GetGameObject(go.transform, "num"):GetComponent("Text").text = curFuwenData.num
    --    Util.GetGameObject(go.transform, "name"):GetComponent("Text").text = curFuwenData.itemConfig.Name
    --    local fuwenBtn = Util.GetGameObject(go.transform, "icon")
    --    Util.AddOnceClick(fuwenBtn, function()
    --        this.OnClickEnterHeroEquip(go,curFuwenData,1)
    --    end)
    --    --Util.AddLongPressClick(equipBtn, function()
    --    --    UIManager.OpenPanel(UIName.EquipInfoPopup,curEquipData)
    --    --end, 0.5)
    --    --local fuwenChoosedBtn = Util.GetGameObject(go.transform, "choosed")
    --    --Util.AddOnceClick(fuwenChoosedBtn, function()
    --    --    this.OnClickEnterHeroEquip(go,curFuwenData,2)
    --    --end)
    --    curFuwenData.isSelect=2
    --    if curSelectEquip.data~=nil then
    --        if curSelectEquip.data.id==curFuwenData.id then
    --            curFuwenData.isSelect=1
    --            curSelectEquip.isSelect=1
    --            oldSelectEquip.isSelect=1
    --            curSelectEquip.go=go
    --            oldSelectEquip.go=go
    --        end
    --    end
    --    this.OnShowSingleCardData(go,curFuwenData,curFuwenData.isSelect)
    --end
end

--设置背包列表数据
function this:SetItemData()
    local fuwenDatas=BagManager.GetBagItemDataByQuDownAll(6,fuwenQuality)
    --this.ItemsSortData(_itemDatas)
    this.ScrollView:SetData(fuwenDatas, function (index, go)
        this.SingleItemDataShow(go, fuwenDatas[index])
    end)
end
function this.SingleItemDataShow(go,fuwenDatas)
        local curFuwenData=fuwenDatas
        Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(curFuwenData.frame)
        Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(curFuwenData.icon)
        Util.GetGameObject(go.transform, "num"):GetComponent("Text").text = curFuwenData.num
        Util.GetGameObject(go.transform, "name"):GetComponent("Text").text = curFuwenData.itemConfig.Name
        local fuwenBtn = Util.GetGameObject(go.transform, "icon")
        Util.AddOnceClick(fuwenBtn, function()
            this.OnClickEnterHeroEquip(go,curFuwenData,1)
        end)
        curFuwenData.isSelect=2
        if curSelectEquip.data~=nil then
            if curSelectEquip.data.id==curFuwenData.id then
                curFuwenData.isSelect=1
                curSelectEquip.isSelect=1
                oldSelectEquip.isSelect=1
                curSelectEquip.go=go
                oldSelectEquip.go=go
            end
        end
        this.OnShowSingleCardData(go,curFuwenData,curFuwenData.isSelect)
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

--界面关闭时调用（用于子类重写）
function WorkShopRuneListPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function WorkShopRuneListPanel:OnDestroy()

    this.ScrollView = nil
end

return WorkShopRuneListPanel