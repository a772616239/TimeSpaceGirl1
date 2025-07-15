require("Base/BasePanel")
CustomerServicePanel = Inherit(BasePanel)
local this = CustomerServicePanel

function this:InitComponent()
    this.title1 = Util.GetGameObject(this.gameObject, "grid/item1/title"):GetComponent("Text")
    this.Text1 = Util.GetGameObject(this.gameObject, "grid/item1/Text"):GetComponent("Text")
    -- this.btnCopy1 = Util.GetGameObject(this.gameObject, "grid/item1/btnCopy")

    this.title2 = Util.GetGameObject(this.gameObject, "grid/item2/title"):GetComponent("Text")
    this.Text2 = Util.GetGameObject(this.gameObject, "grid/item2/Text"):GetComponent("Text")
    -- this.btnCopy2 = Util.GetGameObject(this.gameObject, "grid/item2/btnCopy")

    this.title1.text = GetLanguageStrById(91001578)
    this.Text1.text = GetLanguageStrById(91001579)
    this.title2.text = GetLanguageStrById(91001580)
    this.Text2.text = GetLanguageStrById(91001581)
    this.btnAgree = Util.GetGameObject(this.gameObject, "btnAgree")
end

function this:BindEvent()
 	-- Util.AddClick(this.btnCopy1, function ()
    --     UnityEngine.GUIUtility.systemCopyBuffer = this.Text1
    -- end)
    -- Util.AddClick(this.btnCopy2, function ()
    --     UnityEngine.GUIUtility.systemCopyBuffer = this.Text2
    -- end)

    Util.AddClick(this.btnAgree, function ()
        self:ClosePanel()
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnOpen()
end

function this:OnShow()
end

function this:OnSortingOrderChange()
end

function this:OnClose()
end

function this:OnDestroy()
end

return CustomerServicePanel