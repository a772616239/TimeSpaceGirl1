require("Base/BasePanel")
LeadGeneAtlaslPanel = Inherit(BasePanel)
local this = LeadGeneAtlaslPanel

local tabImg = {
    "cn2-x1_haoyou_biaoqian_weixuanzhong",
    "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou",
    "cn2-x1_haoyou_biaoqian_xuanzhong"
}
local TabBox = require("Modules/Common/TabBox")
local TabData = {
    [1] = {default = tabImg[1], select = tabImg[3]},
    [2] = {default = tabImg[2], select = tabImg[3]},
    [3] = {default = tabImg[2], select = tabImg[3]},
    [4] = {default = tabImg[2], select = tabImg[3]},
    [5] = {default = tabImg[2], select = tabImg[3]},
}
local curIndex = 1

--初始化组件（用于子类重写）
function LeadGeneAtlaslPanel:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")
    this.mask = Util.GetGameObject(this.gameObject, "mask")
    this.tabBox = Util.GetGameObject(this.gameObject, "TabBox")
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetTabIsLockCheck(this.TabIsLockCheck)
    this.TabCtrl:SetChangeTabCallBack(this.OnTabChange)

    this.scroll = Util.GetGameObject(this.gameObject, "scroll")
    this.prefab = Util.GetGameObject(this.gameObject, "scroll/prefab")
    local v2 = this.scroll.transform.rect
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        this.prefab, nil, Vector2.New(v2.width, v2.height), 1, 4, Vector2.New(5, 5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.progress = Util.GetGameObject(this.gameObject, "progress"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function LeadGeneAtlaslPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function ()
        self:ClosePanel()
    end)

end

--添加事件监听（用于子类重写）
function LeadGeneAtlaslPanel:AddListener()
end

--移除事件监听（用于子类重写）
function LeadGeneAtlaslPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function LeadGeneAtlaslPanel:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LeadGeneAtlaslPanel:OnShow()
    this.TabCtrl:Init(this.tabBox, TabData, curIndex)
    this.SetScroll()
end

--界面关闭时调用（用于子类重写）
function LeadGeneAtlaslPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function LeadGeneAtlaslPanel:OnDestroy()
    curIndex = 1
end

function this.TabAdapter(tab, index, status)
    tab:GetComponent("Image").sprite = Util.LoadSprite(TabData[index][status])
    Util.GetGameObject(tab, "Text"):GetComponent("Text").text = index..GetLanguageStrById(10072)
end

function this.TabIsLockCheck(index)
    return false
end

function this.OnTabChange(index, lastIndex)
    curIndex = index
    this.SetScroll()
end

function this.SetScroll()
    local data = AircraftCarrierManager.GetAtlasForLv(curIndex)
    local havaNum = AircraftCarrierManager.GetGeneAtlasHaveNumberForLv(curIndex)
    this.scrollView:SetData(data, function(index, root)
        this.SetScrollItem(root, data[index])
    end)
    this.progress.text = string.format(GetLanguageStrById(22547), havaNum.."/"..#data)
end

function this.SetScrollItem(go, data)
    local frame = Util.GetGameObject(go, "frame"):GetComponent("Image")
    local icon = Util.GetGameObject(go, "icon"):GetComponent("Image")
    local lock = Util.GetGameObject(go, "lock")

    frame.sprite = Util.LoadSprite(GetQuantityImageByquality(data.Quality))
    icon.sprite = SetIcon(data.Id)
    lock:SetActive(not AircraftCarrierManager.GetGeneAtlasIsHave(data.Id))

    Util.AddOnceClick(go, function()
        -- UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, data.Id)
        UIManager.OpenPanel(UIName.LeadGeneTopLevelPanel, nil, data.Id, false)
    end)
end


return LeadGeneAtlaslPanel