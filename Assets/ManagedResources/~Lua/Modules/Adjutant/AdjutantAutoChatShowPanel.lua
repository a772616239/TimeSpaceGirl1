require("Base/BasePanel")
AdjutantAutoChatShowPanel = Inherit(BasePanel)
local this = AdjutantAutoChatShowPanel

local adjutantConfig = ConfigManager.GetConfig(ConfigName.AdjutantConfig)

--初始化组件（用于子类重写）
function AdjutantAutoChatShowPanel:InitComponent()
    this.BgMask = Util.GetGameObject(self.gameObject, "BgMask")
    this.pro = Util.GetGameObject(this.gameObject, "CardPro")
    this.Scroll = Util.GetGameObject(this.gameObject, "frame/Scroll")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.pro, nil,
            Vector2.New(w, h), 2, 1, Vector2.New(30, 0), 1)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function AdjutantAutoChatShowPanel:BindEvent()
    Util.AddClick(this.BgMask, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function AdjutantAutoChatShowPanel:AddListener()
    
end

--移除事件监听（用于子类重写）
function AdjutantAutoChatShowPanel:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function AdjutantAutoChatShowPanel:OnOpen(...)
    local args = {...}
    this.oldLvArray = args[1]
    this.adjutantChat = args[2]

    
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AdjutantAutoChatShowPanel:OnShow()
    -- local proBase = {1,2,3,4,5,6,7,8,9,10}
    this.scrollView:SetData(this.adjutantChat, function(index, root)
        this.SetUI(root, this.adjutantChat[index], this.oldLvArray[index])
    end)
    this.scrollView:SetIndex(1)
end

function AdjutantAutoChatShowPanel.SetUI(root, data1, oldLv)
    local Name = Util.GetGameObject(root, "Name")
    local Level = Util.GetGameObject(root, "Level")
    local CurLv = Util.GetGameObject(root, "Level/CurLv")
    local UpLv = Util.GetGameObject(root, "Level/UpLv")
    local Image = Util.GetGameObject(root, "Level/Image")
    local ExpUp = Util.GetGameObject(root, "ExpUp")
    local Icon = Util.GetGameObject(root, "Icon")

    local adjutantid = data1.id
    local upExp = data1.addExp

    local adjutantData = AdjutantManager.GetOneAdjutantDataById(adjutantid)

    Name:GetComponent("Text").text = GetLanguageStrById(adjutantConfig[adjutantid].Name)
    Icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(adjutantConfig[adjutantid].Picture))
    
    
    if adjutantData.chatLevel > oldLv then
        Level:SetActive(true)

        CurLv:GetComponent("Text").text = string.format(GetLanguageStrById(22318), oldLv)
        UpLv:GetComponent("Text").text = string.format(GetLanguageStrById(22318), adjutantData.chatLevel)
    else
        Level:SetActive(false)
    end
    ExpUp:GetComponent("Text").text = string.format(GetLanguageStrById(22319), upExp)
end

--界面关闭时调用（用于子类重写）
function AdjutantAutoChatShowPanel:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function AdjutantAutoChatShowPanel:OnDestroy()

end

return AdjutantAutoChatShowPanel