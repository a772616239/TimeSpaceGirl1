require("Base/BasePanel")
LoginPopup = Inherit(BasePanel)
local this = LoginPopup
local _loginCall

--初始化组件（用于子类重写）
function LoginPopup:InitComponent()

    this.BtnBack = Util.GetGameObject(self.transform, "Mask")
    this.BtnLogin = Util.GetGameObject(self.transform, "Frame/btnLogin")
    this.BtnRegist = Util.GetGameObject(self.transform, "Frame/btnRegist")

    this.inputField = Util.GetGameObject(self.transform, "Frame/InputField"):GetComponent("InputField")
    this.pwInputField = Util.GetGameObject(self.transform, "Frame/PwInputField"):GetComponent("InputField")

    this.inputFieldText=""
    this.pwInputFieldText=""
end

--绑定事件（用于子类重写）
function LoginPopup:BindEvent()

    Util.AddClick(this.BtnBack, function()
       self:ClosePanel()
    end)
    Util.AddClick(this.BtnLogin, function()
        --[[
             if  this.CheckInput()==false then
            return
        end
        
        
        LoginManager.RequestUser(this.inputFieldText, this.pwInputFieldText, function (code)
            
            
            if code == 0 then
                self:ClosePanel()
                if _loginCall then
                    _loginCall(this.inputFieldText, this.pwInputFieldText)
                end
            end
        end)
        ]]
        if  this.CheckInputLogin()==false then
            return
        end
        
        
        
        LoginManager.RequestUser(this.inputFieldText, this.inputFieldText, function (code)
            
            
            if code == 0 then
                self:ClosePanel()
                if _loginCall then
                    _loginCall(this.inputFieldText, this.inputFieldText)
                end
            end
        end)
    end)
    Util.AddClick(this.BtnRegist, function()
        --self:ClosePanel()
        --UIManager.OpenPanel(UIName.RegistPopup, _loginCall)
        if this.CheckInputRegist()==false then
            return
        end
        local regist=this.inputFieldText
        LoginManager.RequestRegist(regist, regist, function (code)

        end)
    end)
    Util.AddInputField_OnEndEdit(this.inputField.gameObject, function(str)
        this.inputFieldText=str
    end)
    Util.AddInputField_OnEndEdit(this.pwInputField.gameObject, function(str)
        this.pwInputFieldText=str
    end)
end

--添加事件监听（用于子类重写）
function LoginPopup:AddListener()

end

--移除事件监听（用于子类重写）
function LoginPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function LoginPopup:OnOpen(user, pw, loginCall)

    this.inputField.text = user
    this.pwInputField.text = pw
    this.inputFieldText=user
    this.pwInputFieldText=pw
    _loginCall = loginCall
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LoginPopup:OnShow()

end

--界面关闭时调用（用于子类重写）
function LoginPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function LoginPopup:OnDestroy()

end

--检查账号密码输入
function this.CheckInput()
    if this.inputFieldText=="" or this.pwInputFieldText=="" then
        PopupTipPanel.ShowTipByLanguageId(11127)
        return false
    end
    return true
end

--检查账号密码输入(登录)
function this.CheckInputLogin()
    if this.inputFieldText=="" then
        PopupTipPanel.ShowTipByLanguageId(11127)
        return false
    end
    return true
end

--检查账号密码输入(注册)
function this.CheckInputRegist()
    if this.InputFieldText=="" then
        PopupTipPanel.ShowTipByLanguageId(11127)
        
        return false
    end
    return true
end

return LoginPopup