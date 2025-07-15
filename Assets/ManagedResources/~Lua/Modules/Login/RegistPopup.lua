require("Base/BasePanel")
RegistPopup = Inherit(BasePanel)
local this = RegistPopup

local _loginCall

--初始化组件（用于子类重写）
function RegistPopup:InitComponent()

    this.InputField=Util.GetGameObject(self.transform,"Frame/InputField"):GetComponent("InputField")
    this.PwInputField=Util.GetGameObject(self.transform,"Frame/PwInputField"):GetComponent("InputField")
    this.PwSureInputField=Util.GetGameObject(self.transform,"Frame/PwSureInputField"):GetComponent("InputField")

    this.InputFieldText=""
    this.PwInputFieldText=""
    this.PwSureInputFieldText=""

    this.BtnBack = Util.GetGameObject(self.transform, "Frame/btnBack")
    this.BtnRegist = Util.GetGameObject(self.transform, "Frame/btnRegist")
end

--绑定事件（用于子类重写）
function RegistPopup:BindEvent()

    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
        UIManager.OpenPanel(UIName.LoginPopup,this.InputFieldText, this.PwInputFieldText,_loginCall)
    end)
    Util.AddClick(this.BtnRegist, function()
        --self:ClosePanel()
        if this.CheckInput()==false then
            return
        end
        LoginManager.RequestRegist(this.InputFieldText, this.PwInputFieldText, function (code)
            if code == 0 then
                self:ClosePanel()
                UIManager.OpenPanel(UIName.LoginPopup,this.InputFieldText, this.PwInputFieldText, _loginCall)
            end
        end)
    end)
    Util.AddInputField_OnEndEdit(this.InputField.gameObject, function(str)
        this.InputFieldText=str
    end)
    Util.AddInputField_OnEndEdit(this.PwInputField.gameObject, function(str)
        this.PwInputFieldText=str
    end)
    Util.AddInputField_OnEndEdit(this.PwSureInputField.gameObject, function(str)
        this.PwSureInputFieldText=str
    end)
end

--添加事件监听（用于子类重写）
function RegistPopup:AddListener()

end

--移除事件监听（用于子类重写）
function RegistPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RegistPopup:OnOpen(loginCall)

    _loginCall = loginCall
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RegistPopup:OnShow()
   -- local str0=InputField:GetComponent("InputField").TextComponent.text
    

end

--界面关闭时调用（用于子类重写）
function RegistPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function RegistPopup:OnDestroy()

end

--检查账号密码输入
function this.CheckInput()
    if this.InputFieldText=="" or this.PwInputFieldText=="" or this.PwSureInputFieldText=="" then
        PopupTipPanel.ShowTipByLanguageId(11127)
        
        return false
    end
    if this.PwInputFieldText~=this.PwSureInputFieldText then
        PopupTipPanel.ShowTipByLanguageId(11131)
        
        return false
    end
    return true
end
return RegistPopup