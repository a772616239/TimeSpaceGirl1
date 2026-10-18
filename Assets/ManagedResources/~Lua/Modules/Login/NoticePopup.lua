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

-- 公告 title 的约定是「多语言用 | 拼接、每段形如 <语言id>:<正文>」，
-- 例如 "10001:中文公告|10101:English notice"。但后端/本地服也可能只下发纯文本，
-- 此时没有 langId: 前缀，必须整段兜底显示，不能拿 nil 去拼字符串。
local function PickLocalizedNotice(raw)
    if type(raw) ~= "string" or raw == "" then
        return ""
    end
    local lang = tostring(GetCurLanguage() or "10001")
    local firstPart = nil

    for part in string.gmatch(raw, "([^|]+)") do
        if not firstPart then
            firstPart = part
        end
        local langCode, text = string.match(part, "^([%w%-_]+):(.+)$")
        if langCode and text and langCode == lang then
            return text
        end
    end

    -- 未命中当前语言：先回退中文，再回退第一段，最后整段原文
    local zh = string.match(raw, "10001:([^|]+)")
    if zh then
        return zh
    end
    if firstPart then
        return (string.match(firstPart, ":%s*(.+)") or firstPart)
    end
    return raw
end

function this.GetNotice()
    local timeStamp = Time.realtimeSinceStartup
    local timeSign = Util.MD5Encrypt(string.format("%s%s", timeStamp, LoginManager.sign))
    -- RequestPanel.Show(GetLanguageStrById(11128))
    local showCb= function  (str)
            noticeContent=str
            RequestPanel.Hide()
            -- 面板可能在请求返回前被关掉，此时不要写 UI
            if not this.ContentText then
                return
            end
            if str == nil or str == "" then
                this.ContentText.text = GetLanguageStrById(11130)
                return
            end

            -- 公告解析整体兜底：任何异常都不该让整个 HTTP 回调崩掉（否则公告永远空白）
            local ok, localizedContent = pcall(function()
                local json = require 'cjson'
                local data = json.decode(str)
                if type(data) == "table" and type(data.parms) == "table" then
                    return PickLocalizedNotice(data.parms.title or data.parms.content)
                end
                return nil
            end)

            if not ok or localizedContent == nil or localizedContent == "" then
                if not ok then
                    Log("NoticePopup 解析公告失败: " .. tostring(localizedContent))
                end
                this.ContentText.text = GetLanguageStrById(11130)
                return
            end

            this.ContentText.text = (string.gsub(localizedContent, "\\n", "\n"))
        end
    if noticeContent and noticeContent ~= "" then
        showCb(noticeContent)
        return
    else
        networkMgr:SendGetHttp(LoginRoot_Url .. "tk/getNotice?timestamp="..timeStamp.."&sign=".. timeSign,
        showCb
        , nil, nil, nil)
    end

end

return NoticePopup