require("Base/BasePanel")
PermissionPanel = Inherit(BasePanel)
local this = PermissionPanel
local isClose

function this:InitComponent()
    this.panel1 = Util.GetGameObject(this.gameObject, "panel1")
    this.panel2 = Util.GetGameObject(this.gameObject, "panel2")
    this.panel3 = Util.GetGameObject(this.gameObject, "panel3")
end

function this:BindEvent()
    Util.AddClick(Util.GetGameObject(this.panel1, "btnRefuse"), function ()
        PlayerPrefs.SetInt("IsAgreePrivacy", 0)
        this.panel1:SetActive(false)
        this.panel2:SetActive(true)
    end)
    Util.AddClick(Util.GetGameObject(this.panel1, "btnAgree"), function ()
        PlayerPrefs.SetInt("IsAgreePrivacy", 1)
        this.panel1:SetActive(false)
        this.panel3:SetActive(true)
    end)
    Util.AddClick(Util.GetGameObject(this.panel2, "btnRefuse"), function ()
        PlayerPrefs.SetInt("IsAgreePrivacy", 0)
        UnityEngine.Application.Quit()
    end)
    Util.AddClick(Util.GetGameObject(this.panel2, "btnAgree"), function ()
        -- PlayerPrefs.SetInt("IsAgreePrivacy", 1)
        if isClose then
            self:ClosePanel()
        end
        this.panel2:SetActive(false)
        this.panel1:SetActive(true)
    end)
    Util.AddClick(Util.GetGameObject(this.panel3, "btnAgree"), function ()
        this.panel3:SetActive(false)
        Game.GlobalEvent:DispatchEvent(GameEvent.LoginSuccess.OnAgreePrivacy)
        self:ClosePanel()
        if this.func then
            this.func()
        end
    end)
    Util.AddClick(Util.GetGameObject(this.panel1, "Content"), function ()
        UIManager.OpenPanel(UIName.PrivacyPanel, true)
    end)
end

function this:OnOpen(panel, func)
    this.panel1:SetActive(false)
    this.panel2:SetActive(false)
    this.panel3:SetActive(false)
    
    PlayerPrefs.SetInt("IsAgreePrivacy", 0)
    if panel then
        Util.GetGameObject(this.gameObject, "panel"..panel):SetActive(true)
        isClose = true
        return
    end
    if PlayerPrefs.GetInt("IsAgreePrivacy") == 0 then
        this.panel1:SetActive(true)
    end
    this.func = func
end

function this:OnClose()
end

function this:OnShow()
end

return this