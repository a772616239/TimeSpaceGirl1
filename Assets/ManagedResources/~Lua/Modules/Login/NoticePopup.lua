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
    -- 🔴 必须在这里断开 ContentText 引用：DestroyUI() 之后紧接着
    -- GameObject.Destroy(panel.gameObject)，此时 lua 侧还握着一个「非 nil 但已销毁」的
    -- Text userdata，迟到的 HTTP 回调再写它就会抛
    -- "attempt to index text on a nil value"（见下方 Alive 注释）。
    this.ContentText = nil
end

local noticeContent = nil
local noticeRequestId = 0

-- C# 侧对象是否还活着。
-- 🔴 关键：GameObject 被 Destroy 后，lua 里持有的 userdata 依然「非 nil」，
-- 只有 tolua.isnull() 看得出来。所以 `if not obj then return end` 这种判空
-- 对"面板已销毁"完全无效——线上 Fatal Exception 的根因就在这里：
-- NoticePopup 的 noDestory=0 ⇒ ClosePanel 会走 DelayDestroyPanel（15s*openNum），
-- 面板被真正 Destroy 之后 getNotice 的 HTTP 回调才回来，赋值撞上已销毁的 Text，
-- tolua 生成代码 set_text 里 catch 到 NRE，统一抛
-- UnityEngine_UI_TextWrap: "attempt to index text on a nil value"。
local function Alive(obj)
    if obj == nil then
        return false
    end
    if type(obj) == "userdata" then
        return not IsNull(obj)   -- IsNull = obj == nil or tolua.isnull(obj)
    end
    return true
end

-- 写公告正文的唯一出口：判活 + pcall 双保险，异常只降级成「公告没刷新」，不打断 HTTP 回调。
local function SafeSetContent(content)
    local txt = this.ContentText
    if not Alive(txt) then
        this.ContentText = nil
        return false
    end
    local ok, err = pcall(function()
        txt.text = content
    end)
    if not ok then
        this.ContentText = nil
        Log("NoticePopup 写公告失败(组件已销毁): " .. tostring(err))
    end
    return ok
end

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
    noticeRequestId = noticeRequestId + 1
    local reqId = noticeRequestId
    -- RequestPanel.Show(GetLanguageStrById(11128))
    local showCb= function  (str)
            -- 过期回调丢弃：面板关了又开、或连发两次请求时，老响应不能覆盖新面板。
            if reqId ~= noticeRequestId then
                return
            end
            noticeContent=str
            RequestPanel.Hide()
            -- 面板可能在请求返回前被关掉并被销毁，此时不要写 UI
            if not Alive(this.ContentText) then
                this.ContentText = nil
                return
            end
            if str == nil or str == "" then
                SafeSetContent(GetLanguageStrById(11130))
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
                SafeSetContent(GetLanguageStrById(11130))
                return
            end

            SafeSetContent((string.gsub(localizedContent, "\\n", "\n")))
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