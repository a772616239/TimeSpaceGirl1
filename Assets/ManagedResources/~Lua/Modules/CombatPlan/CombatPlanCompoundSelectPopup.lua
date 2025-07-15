require("Base/BasePanel")
CombatPlanCompoundSelectPopup = Inherit(BasePanel)
local this = CombatPlanCompoundSelectPopup

--初始化组件（用于子类重写）
function CombatPlanCompoundSelectPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.btnSure = Util.GetGameObject(self.gameObject, "btnSure")

    this.numText = Util.GetGameObject(self.gameObject, "numText"):GetComponent("Text")

    this.Scroll = Util.GetGameObject(self.gameObject, "scroll")
    this.ScrollPre = Util.GetGameObject(self.gameObject, "item")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.ScrollPre, nil,
            Vector2.New(w, h), 1, 4, Vector2.New(10, 10))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function CombatPlanCompoundSelectPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnSure, function()
        self:ClosePanel()


        this.compoundSelf.selectPlanDids = this.tempSelectPlanDids
        this.compoundSelf:UpdateAddUI()
    end)
end

--添加事件监听（用于子类重写）
function CombatPlanCompoundSelectPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function CombatPlanCompoundSelectPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function CombatPlanCompoundSelectPopup:OnOpen(...)
    local args = {...}
    this.compoundSelf = args[1]
    this.tempSelectPlanDids = {}
    for i = 1, #this.compoundSelf.selectPlanDids do
        table.insert(this.tempSelectPlanDids, this.compoundSelf.selectPlanDids[i])
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function CombatPlanCompoundSelectPopup:OnShow()
    this.data = CombatPlanManager.GetAllCanCompoundPlans()
    for i = 1, #this.data do
        this.data[i].isSelect = false
        for k, v in ipairs(this.tempSelectPlanDids) do
            if this.data[i].id == v then
                this.data[i].isSelect = true
            end
        end
    end

    this.scrollView:SetData(this.data, function(index, root)
        CombatPlanCompoundSelectPopup.SetPlanItem(root, this.data[index])
    end)
    this.scrollView:SetIndex(1)

    this.numText.text = #this.tempSelectPlanDids .. "/5"
end

function CombatPlanCompoundSelectPopup.SetPlanItem(root, data)
    local arrow = Util.GetGameObject(root, "select/Image")
    local select = Util.GetGameObject(root, "select")
    local icon = Util.GetGameObject(root, "icon")
    local frame = Util.GetGameObject(root, "frame")
    local selectImg = Util.GetGameObject(root, "selectImg")
    
    local qualityId = CombatPlanManager.SetQuality(data.quality)
    frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(qualityId))
    icon:GetComponent("Image").sprite = Util.LoadSprite(G_CombatPlanConfig[data.combatPlanId].Icon)
 
    arrow:SetActive(data.isSelect)
    selectImg:SetActive(data.isSelect)

    Util.AddOnceClick(select, function()
        if data.isSelect then
            for i = 1, #this.tempSelectPlanDids do
                if this.tempSelectPlanDids[i] == data.id then
                    table.remove(this.tempSelectPlanDids, i)
                    break
                end
            end
        else
            if #this.tempSelectPlanDids >= 5 then
                return
            end
            if #this.tempSelectPlanDids >= 1 then
                local planData = CombatPlanManager.GetPlanData(this.tempSelectPlanDids[1])
                if data.quality ~= planData.quality then
                    return
                end
            end

            table.insert(this.tempSelectPlanDids, data.id)
        end

        data.isSelect = not data.isSelect

        this.scrollView:SetData(this.data, function(index, root)
            CombatPlanCompoundSelectPopup.SetPlanItem(root, this.data[index])
        end)

        this.numText.text = #this.tempSelectPlanDids .. "/5"
    end)
    Util.AddOnceClick(icon, function ()
        UIManager.OpenPanel(UIName.CombatPlanTipsPopup, 3, nil, nil, nil, nil, nil, data)
    end)
end

--界面关闭时调用（用于子类重写）
function CombatPlanCompoundSelectPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function CombatPlanCompoundSelectPopup:OnDestroy()
end

return CombatPlanCompoundSelectPopup