require("Base/BasePanel")
StoryOptionPopup = Inherit(BasePanel)
local this = StoryOptionPopup
local curEventId = 0
local eventConfig = ConfigManager.GetConfig(ConfigName.ChapterEventPointConfig)
local optionConfig = ConfigManager.GetConfig(ConfigName.ChapterOptionConfig)
--初始化组件（用于子类重写）
function StoryOptionPopup:InitComponent()
    this.btn = {}
    this.btnInfo = {}
    -- 初始化4个按钮
    for i = 1, 4 do
        this.btn[i] = Util.GetGameObject(self.gameObject, string.format("btnRoot/btn%s", i))
        this.btnInfo[i] = Util.GetGameObject(this.btn[i], "Text"):GetComponent("Text")
    end

    -- 临时代码
    this.btnBack = Util.GetGameObject(self.gameObject, "BackMask")
    -- 选择按钮的父节点
    this.btnRoot = Util.GetGameObject(self.gameObject, "btnRoot")

end

--绑定事件（用于子类重写）
function StoryOptionPopup:BindEvent()

    Util.AddClick(this.btnBack, function ()
        --self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function StoryOptionPopup:AddListener()

end

--移除事件监听（用于子类重写）
function StoryOptionPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function StoryOptionPopup:OnOpen(eventId)
    curEventId = eventId
    -- 初始化动画
    this.InitAnimi()

end

function this.InitAnimi()
    PlayUIAnim(this.gameObject, function ()
        -- 初始化数据
        this.InitData()
        PlayUIAnim(this.btnRoot)
    end)
end

function this.InitData()
    -- 根据内容显示按钮
    local options = eventConfig[curEventId].Option
    if #options == 0 then 
        return
    end

    for i = 1, #options do
        this.btn[i]:SetActive(true)
        this.btnInfo[i].text = GetLanguageStrById(optionConfig[options[i]].Info)
        -- 点击跳转
        Util.AddClick(this.btn[i], function ()
            StoryManager.StoryJumpType(options[i], this.gameObject)
        end)
    end
end

--界面关闭时调用（用于子类重写）
function StoryOptionPopup:OnClose()
    for i = 1, 4 do
        this.btn[i]:SetActive(false)
    end

    PlayUIAnimBack(this.btnRoot)
end

--界面销毁时调用（用于子类重写）
function StoryOptionPopup:OnDestroy()

end

return StoryOptionPopup