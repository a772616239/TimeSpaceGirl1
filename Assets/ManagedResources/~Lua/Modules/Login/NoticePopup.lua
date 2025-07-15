require("Base/BasePanel")
NoticePopup = Inherit(BasePanel)
local this = NoticePopup
local LoginRoot_Url = VersionManager:GetVersionInfo("serverUrl")
--初始化组件（用于子类重写）
function NoticePopup:InitComponent()
    -- this.BtnBack = Util.GetGameObject(self.transform, "bg/bg/btnBack")
    this.BackMask = Util.GetGameObject(self.transform,"BackMask")
	this.BackBtn = Util.GetGameObject(self.transform,"BackBtn")
    -- this.TitleText=Util.GetGameObject(self.transform,"bg/bg/Image/title"):GetComponent("Text")
    this.ContentText = Util.GetGameObject(self.transform,"bg/rect/content"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function NoticePopup:BindEvent()
    -- Util.AddClick(this.BtnBack, function()
    --     self:ClosePanel()
    -- end)
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function NoticePopup:AddListener()

end

--移除事件监听（用于子类重写）
function NoticePopup:RemoveListener()


end

--界面打开时调用（用于子类重写）
function NoticePopup:OnOpen(...)
    this.GetNotice()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function NoticePopup:OnShow()

end

--界面关闭时调用（用于子类重写）
function NoticePopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function NoticePopup:OnDestroy()

end

function this.GetNotice()
    local timeStamp = Time.realtimeSinceStartup
    local timeSign = Util.MD5Encrypt(string.format("%s%s", timeStamp, LoginManager.sign))
    RequestPanel.Show(GetLanguageStrById(11128))
    networkMgr:SendGetHttp(LoginRoot_Url .. "tk/getNotice?timestamp="..timeStamp.."&sign=".. timeSign,
        function (str)
            RequestPanel.Hide()
            if str == nil then
                return
            end
            local json = require 'cjson'
            local data = json.decode(str)
            if data.parms then
                -- this.TitleText.text = data.parms.title
                this.ContentText.text = string.gsub(data.parms.content, "\\n", "\n")
            else
                -- this.TitleText.text = GetLanguageStrById(11129)
                this.ContentText.text = GetLanguageStrById(11130)
            end
        end, nil, nil, nil)
end

return NoticePopup