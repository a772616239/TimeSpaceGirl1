require("Base/BasePanel")
FormationPositonPopup = Inherit(BasePanel)
local this = FormationPositonPopup

local FormationConfig = ConfigManager.GetConfig(ConfigName.FormationConfig)

local scrollObjList = {}
local formationIdx = 0
--初始化组件（用于子类重写）
function FormationPositonPopup:InitComponent()
    this.maskImage = Util.GetGameObject(this.gameObject, "maskImage")
	this.backBtn = Util.GetGameObject(this.gameObject, "backBtn")
    this.Button = Util.GetGameObject(this.gameObject, "Button")
    this.desc = Util.GetGameObject(this.gameObject, "Desc"):GetComponent("Text")

    for i = 1, 6 do
        scrollObjList[i] = Util.GetGameObject(this.gameObject, "Grid/Viewport/zhenxing" .. tostring(i))
    end
end

--绑定事件（用于子类重写）
function FormationPositonPopup:BindEvent()
    Util.AddClick(this.maskImage, function()
        this:ClosePanel()
    end)
    Util.AddClick(this.backBtn, function()
        this:ClosePanel()
    end)

    Util.AddClick(this.Button, function()
        if formationIdx ~= FormationManager.GetFormationId() then
            FormationManager.SetFormationId(formationIdx)            
            FormationPanelV2.SetChoosedFormationId(formationIdx)
            FormationPanelV2.ResetChooseWithFormationId()
            FormationManager.RefreshFormation(this.root.curFormationIndex, this.root.choosedList,this.root.tibu,
            {supportId = SupportManager.GetFormationSupportId(this.root.curFormationIndex),
            adjutantId = AdjutantManager.GetFormationAdjutantId(this.root.curFormationIndex)},
            nil,
            formationIdx)

            if this.fun then
                this.fun()
            end

        else
        end
        this:ClosePanel()
    end)

    for i = 1, 6 do
        Util.AddClick(scrollObjList[i], function()
            local formationData = FormationConfig[i]
            if formationData then
                if PlayerManager.level >= formationData.need_lev then
                    formationIdx = i
                    this.desc.text = GetLanguageStrById(formationData.Des)
                    self:UpdateUI()
                end
            else
                LogError("### FormationConfig error")
            end
        end)
    end
end

--添加事件监听（用于子类重写）
function FormationPositonPopup:AddListener()
end

--移除事件监听（用于子类重写）
function FormationPositonPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function FormationPositonPopup:OnOpen(...)
    local args = {...}
    self.root = args[1]
    this.fun = args[2]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FormationPositonPopup:OnShow()
    formationIdx = FormationManager.GetFormationId()
    this.desc.text = GetLanguageStrById(FormationConfig[formationIdx].Des)
    self:Init()
    self:UpdateUI()
end

function FormationPositonPopup:Init()
    for i = 1, 6 do
        local formationData = FormationConfig[i]
        if formationData then
            local root = scrollObjList[i]
            local cardImg = Util.GetGameObject(root, "card"):GetComponent("Image")
            cardImg.sprite = Util.LoadSprite(GetResourceStr(formationData.icon))
            local lock = Util.GetGameObject(root, "lock")
            lock:GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(formationData.icon))
            local lockFont = Util.GetGameObject(root, "lock/conText"):GetComponent("Text")
            lockFont.text = string.format(GetLanguageStrById(12502), formationData.need_lev)

            if PlayerManager.level >= formationData.need_lev then
                lock:SetActive(false)
            else
                lock:SetActive(true)
            end
            Util.GetGameObject(root, "name"):GetComponent("Text").text = GetLanguageStrById(formationData.name)
        else
            LogError("### FormationConfig error")
        end
    end
end

function FormationPositonPopup:UpdateUI()
    for i = 1, 6 do
        local formationData = FormationConfig[i]
        if formationData then
            local root = scrollObjList[i]
            Util.GetGameObject(root, "selected"):SetActive(i == formationIdx and true or false)
        else
            LogError("### FormationConfig error")
        end
    end
end

--界面关闭时调用（用于子类重写）
function FormationPositonPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function FormationPositonPopup:OnDestroy()

end

return FormationPositonPopup