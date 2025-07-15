require("Base/BasePanel")
MapBagPopup = Inherit(BasePanel)
local this = MapBagPopup
local itemList={}
--初始化组件（用于子类重写）
function MapBagPopup:InitComponent()

    self.btnBack = Util.GetGameObject(self.gameObject, "panel/btnBack")
    self.tansuoBtn = Util.GetGameObject(self.gameObject, "panel/Tabs/tansuoBtn")
    self.xiedaiBtn = Util.GetGameObject(self.gameObject, "panel/Tabs/xiedaiBtn")
    self.vipBtn = Util.GetGameObject(self.gameObject, "panel/Tabs/vipBtn")
    self.selectBtn = Util.GetGameObject(self.gameObject, "panel/Tabs/selectBtn")
    self.item = Util.GetGameObject(self.gameObject, "Item")
    self.grid = Util.GetGameObject(self.gameObject, "panel/scroll/grid")
    this.noneImage=Util.GetGameObject(self.gameObject,"panel/NoneImage")--无信息图片
    this.exploreBag = {}
end

--绑定事件（用于子类重写）
function MapBagPopup:BindEvent()

    Util.AddClick(self.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MapBagPopup:AddListener()


    Util.AddClick(this.tansuoBtn, function(go)
        this.selectBtn.transform.localPosition = go.transform.localPosition
        Util.GetGameObject(this.selectBtn, "Text"):GetComponent("Text").text = Util.GetGameObject(go, "Text"):GetComponent("Text").text
        this.ShowItemInfo(1)
    end)

    Util.AddClick(this.xiedaiBtn, function(go)
        this.selectBtn.transform.localPosition = go.transform.localPosition
        Util.GetGameObject(this.selectBtn, "Text"):GetComponent("Text").text = Util.GetGameObject(go, "Text"):GetComponent("Text").text

        this.ShowItemInfo(2)
    end)
    Util.AddClick(this.vipBtn, function(go)
        this.selectBtn.transform.localPosition = go.transform.localPosition
        Util.GetGameObject(this.selectBtn, "Text"):GetComponent("Text").text = Util.GetGameObject(go, "Text"):GetComponent("Text").text

    end)
end

--移除事件监听（用于子类重写）
function MapBagPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MapBagPopup:OnOpen(...)

    this.selectBtn.transform.localPosition = this.tansuoBtn.transform.localPosition
    Util.GetGameObject(this.selectBtn, "Text"):GetComponent("Text").text = Util.GetGameObject(this.tansuoBtn, "Text"):GetComponent("Text").text
    this.ShowItemInfo(1)
end

--点击装备按钮
function this:OnClickTabBtn(_index)
    if _index == 1 then --探索
    elseif _index == 2 then --携带
    else --vip
    end
end


local curType
function this.ShowItemInfo(_index)
    itemList={}
    curType = _index


    for j = 1, #this.exploreBag do
        this.exploreBag[j].gameObject:SetActive(false)
    end


    if curType == 1 then
        itemList = BagManager.GetAllTempBagData()
    elseif curType==2 then
        itemList = BagManager.GetBagItemDataByItemMapIsShow()
    end
    this.noneImage:SetActive(#itemList==0)

    for i = 1, #itemList do
        local item = itemList[i]
        if not this.exploreBag[i] then
            this.exploreBag[i] = SubUIManager.Open(SubUIConfig.ItemView, this.grid.transform)
            this.exploreBag[i].gameObject:SetActive(false)
        end

        if item.num > 0 then
            if curType == 2 then
                this.exploreBag[i]:OnOpen(true, item, 1, true, true)
                this.exploreBag[i].gameObject:SetActive(true)
            elseif curType == 1 then
                this.exploreBag[i]:OnOpen(false, {item.sId,item.num}, 1, true, false)
                this.exploreBag[i].gameObject:SetActive(true)
            end

        end
    end
end

--界面关闭时调用（用于子类重写）
function MapBagPopup:OnClose()

    this.noneImage:SetActive(false)
end

--界面销毁时调用（用于子类重写）
function MapBagPopup:OnDestroy()

end

return MapBagPopup