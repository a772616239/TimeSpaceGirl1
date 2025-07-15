require("Base/BasePanel")
WarWayPreviewPopup = Inherit(BasePanel)
local this = WarWayPreviewPopup

local PassiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)

local _tabIdx = 1
local TabBox = require("Modules/Common/TabBox") -- 引用

local _TabData = {
    [1] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong", select = "cn2-x1_haoyou_biaoqian_weixuanzhong", name = GetLanguageStrById(12508) },
    [2] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", name = GetLanguageStrById(12509) },
    [3] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", name = GetLanguageStrById(12510) },
    [4] = { default = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", select = "cn2-x1_haoyou_biaoqian_weixuanzhong_quekou", name = GetLanguageStrById(12511) },
}

--初始化组件（用于子类重写）
function WarWayPreviewPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "btnClose")

    this.tabBox = Util.GetGameObject(self.gameObject, "bg/TabBox")

    this.Scroll = Util.GetGameObject(self.gameObject, "bg/Scroll")
    this.WarWayPre = Util.GetGameObject(self.gameObject, "bg/WarWayPre")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.WarWayPre, nil,
            Vector2.New(w, h), 1, 4, Vector2.New(5, 5))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
    this.mask = Util.GetGameObject(self.gameObject,"bg/TabBox/mask")

    this.isFirstOpen = true
    this.maskCurPos = this.mask.transform.position
end

--绑定事件（用于子类重写）
function WarWayPreviewPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function WarWayPreviewPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function WarWayPreviewPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function WarWayPreviewPopup:OnOpen()
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function WarWayPreviewPopup:OnShow()
    this.tabCtrl=TabBox.New()
    this.tabCtrl:SetTabAdapter(this.OnTabAdapter) 
    this.tabCtrl:SetTabIsLockCheck(this.OnTabIsLockCheck)
    this.tabCtrl:SetChangeTabCallBack(this.OnChangeTab)
    this.tabCtrl:Init(this.tabBox, _TabData)


    _tabIdx = 1
    WarWayPreviewPopup.ChangeTab(_tabIdx)
    this.scrollView:SetIndex(1)
    this.mask.transform.position = this.maskCurPos
    Util.GetGameObject(this.mask,"Text"):GetComponent("Text").text =  _TabData[_tabIdx].name
end

function WarWayPreviewPopup.OnTabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name

    if this.isFirstOpen then
        if index == 4 then
            this.isFirstOpen = false
        end
    else
        this.mask.transform.position = tab.transform.position - Vector3.New(0,0,0)
        Util.GetGameObject(this.mask,"Text"):GetComponent("Text").text = tabLab:GetComponent("Text").text
    end
    

    _tabIdx = index
    WarWayPreviewPopup.ChangeTab(index)
end
function WarWayPreviewPopup.OnTabIsLockCheck(index)
end
function WarWayPreviewPopup.OnChangeTab(index, lastIndex)
end

function WarWayPreviewPopup.ChangeTab(index)
    this.data = WarWayManager.GetDataWithLv(index)
    this:RefreshScroll()
end

function WarWayPreviewPopup:RefreshScroll()
    this.scrollView:SetData(self.data, function(index, root)
        self:FillItem(root, self.data[index])
    end)
end

function WarWayPreviewPopup:FillItem(go, data)
    Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(data.Image))
    local passiveConfig = PassiveSkillConfig[data.SkillId]
    Util.GetGameObject(go, "Name"):GetComponent("Text").text = GetLanguageStrById(passiveConfig.Name)
    Util.GetGameObject(go, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(data.Quantity))
            Util.AddOnceClick(Util.GetGameObject(go, "frame"),function()
                local skillData = {}
                skillData.skillConfig =passiveConfig
                skillData.lock=true
                local PassiveSkillConfig = PassiveSkillConfig[data.SkillId]
                UIManager.OpenPanel(UIName.SkillInfoPopup,skillData,1,10,1,1,PassiveSkillConfig.Level)

            end)  	

    --> 标签
    local CanLearnSign = Util.GetGameObject(go, "CanLearnSign")
    local RecommandSign = Util.GetGameObject(go, "RecommandSign")
    local RareSign = Util.GetGameObject(go, "RareSign")
    local UniqueSign = Util.GetGameObject(go, "UniqueSign")
    CanLearnSign:SetActive(false)
    RecommandSign:SetActive(false)
    RareSign:SetActive(false)
    UniqueSign:SetActive(false)

    Util.AddOnceClick(Util.GetGameObject(go, "frame"), function()
        UIManager.OpenPanel(UIName.CommonInfoPopup, CommonInfoType.WarWay, Util.GetGameObject(go, "frame"), data.ID)
    end)

    --> 稀有
    if data.Rare == 1 then
        RareSign:SetActive(true)
    end

    --> 专属
    if data.Exclusive == 1 then
        UniqueSign:SetActive(true)
    end
end

--界面关闭时调用（用于子类重写）
function WarWayPreviewPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function WarWayPreviewPopup:OnDestroy()

end

return WarWayPreviewPopup