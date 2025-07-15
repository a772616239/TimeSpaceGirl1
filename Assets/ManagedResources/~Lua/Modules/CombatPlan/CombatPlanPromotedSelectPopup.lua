require("Base/BasePanel")
CombatPlanPromotedSelectPopup = Inherit(BasePanel)
local this = CombatPlanPromotedSelectPopup
local selectData
this.oldSelect=nil


--初始化组件（用于子类重写）
function CombatPlanPromotedSelectPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.btnSure = Util.GetGameObject(self.gameObject, "btnSure")


    this.Scroll = Util.GetGameObject(self.gameObject, "scroll")
    this.ScrollPre = Util.GetGameObject(self.gameObject, "item")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.ScrollPre, nil,
            Vector2.New(w, h), 1, 5, Vector2.New(10, 10))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function CombatPlanPromotedSelectPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnSure, function()
        
        
        this.upPanel.PromotedInfo(selectData)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function CombatPlanPromotedSelectPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function CombatPlanPromotedSelectPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function CombatPlanPromotedSelectPopup:OnOpen(...)
    local args = {...}
    this.upPanel=args[1]
    selectData=args[2]
  
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function CombatPlanPromotedSelectPopup:OnShow()
  
    this.data=CombatPlanManager.GetAllCanPromotionPlans()
    this.scrollView:SetData(this.data, function(index, root)
        CombatPlanPromotedSelectPopup.SetPlanItem(root, this.data[index])
    end)
end

function CombatPlanPromotedSelectPopup.SetPlanItem(root, data)
    local icon = Util.GetGameObject(root, "icon")
    local arrow = Util.GetGameObject(root, "select/Image")
    local selectBtn = Util.GetGameObject(root, "select")
    local frame = Util.GetGameObject(root, "frame")

    local qualityid= CombatPlanManager.SetQuality(data.quality)
    
    frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(qualityid))
    icon:GetComponent("Image").sprite = Util.LoadSprite(G_CombatPlanConfig[data.combatPlanId].Icon)
    if selectData~=nil and selectData.id==data.id then
        this.oldSelect=arrow
    end
    if selectData~=nil then
        
        
        
        arrow:SetActive(selectData.id==data.id)
    else
        arrow:SetActive(false)
    end

    Util.AddOnceClick(selectBtn, function()
        if this.oldSelect~=nil then
            this.oldSelect:SetActive(false)
            this.oldSelect=nil
        
        end
        selectData=data
        arrow:SetActive(true)
        this.oldSelect=arrow
    end)
    Util.AddOnceClick(icon, function()
       --TODO显示Tip
       UIManager.OpenPanel(UIName.CombatPlanTipsPopup, 3, nil, nil, nil, nil, nil, data)
    end)
end

--界面关闭时调用（用于子类重写）
function CombatPlanPromotedSelectPopup:OnClose()
    this.oldSelect=nil
end

--界面销毁时调用（用于子类重写）
function CombatPlanPromotedSelectPopup:OnDestroy()

end

return CombatPlanPromotedSelectPopup