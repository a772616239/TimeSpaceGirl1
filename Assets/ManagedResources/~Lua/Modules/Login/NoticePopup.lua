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
    Game.GlobalEvent:DispatchEvent(GameEvent.NoticePanel.OnOpen,true)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function NoticePopup:OnShow()

end

--界面关闭时调用（用于子类重写）
function NoticePopup:OnClose()
    Game.GlobalEvent:DispatchEvent(GameEvent.NoticePanel.OnOpen,false)
end

--界面销毁时调用（用于子类重写）
function NoticePopup:OnDestroy()

end

local noticeContent = nil

function this.GetNotice()
    local timeStamp = Time.realtimeSinceStartup
    local timeSign = Util.MD5Encrypt(string.format("%s%s", timeStamp, LoginManager.sign))
    RequestPanel.Show(GetLanguageStrById(11128))
    local showCb= function  (str)
            noticeContent=str
            Log("获取公告内容: " .. tostring(str))
            RequestPanel.Hide()
            if str == nil or str == "" then
                return
            end
            
            local json = require 'cjson'
            local data = json.decode(str)
            
            if data.parms then
                -- 获取客户端当前语言标识（根据实际项目调整）
                local lang = GetCurLanguage().."" or "10001"
                Log("当前语言标识: " .. lang.."--获取公告内容"..GetCurLanguage())
                local content = data.parms.title
                
                -- 解析多语言公告
                local localizedContent = ""
                local found = false
                
                -- 尝试查找当前语言的公告
                for part in string.gmatch(content, "([^|]+)") do
                  
                    local langCode, text = string.match(part, "^(%w+):(.+)$")
                    if  langCode== nil then
                        langCode = "10001" -- 默认语言标识
                      Log("公告部分langCode: " .. langCode)
                    if langCode and text then
                        if langCode == lang then
                            localizedContent = text
                            found = true
                            break
                        end
                    end
                end
            end
                -- 如果未找到匹配语言，尝试中文或第一条公告
                if not found then
                    -- 尝试找中文
                    local zhText = string.match(content, "10001:([^|]+)")
                    if zhText then
                        localizedContent = zhText
                    else
                        -- 使用第一条公告
                        local firstPart = string.match(content, "([^|]+)")
                        if firstPart then
                            localizedContent = string.match(firstPart, ":%s*(.+)") or firstPart
                        else
                            localizedContent = content
                        end
                    end
                end
                
                this.ContentText.text = string.gsub(localizedContent, "\\n", "\n")
            else
                this.ContentText.text = GetLanguageStrById(11130)
            end
        end
    if noticeContent then
        showCb(noticeContent)
        return
    else
        networkMgr:SendGetHttp(LoginRoot_Url .. "tk/getNotice?timestamp="..timeStamp.."&sign=".. timeSign,
        showCb
        , nil, nil, nil)
    end

end

return NoticePopup