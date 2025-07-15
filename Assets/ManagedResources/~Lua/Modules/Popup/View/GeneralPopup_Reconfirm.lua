----- 二次确认弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local func

function this:InitComponent(gameObject)
    this.cancel = Util.GetGameObject(gameObject, "CancelBtn")
    this.confirm = Util.GetGameObject(gameObject, "ConfirmBtn")
    
    this.toggle = Util.GetGameObject(gameObject,"Root/Toggle"):GetComponent("Toggle")
    this.title = Util.GetGameObject(gameObject,"Root/Text"):GetComponent("Text")
    this.Text = Util.GetGameObject(gameObject,"Root/Toggle/Text"):GetComponent("Text")
end

function this:BindEvent()
    Util.AddClick(this.cancel, this.OnLeftBtnClick)
    Util.AddClick(this.confirm, this.OnRightBtnClick)
end

--左边按钮点击事件
function this.OnLeftBtnClick()
    parent:ClosePanel()
end

--右边按钮点击事件
function this.OnRightBtnClick()
    parent:ClosePanel()
    if this.toggle.isOn then
        if func then
            func()
        end
    end
end
function this.Hide()
    parent:ClosePanel()
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent, ...)
    parent = _parent
    local args = {...}
    this.toggle.isOn = false
    this.title.text = args[1]
    this.Text.text = args[2]
    func = args[3]
end

function this:OnClose()
end

function this:OnDestroy()
end


return this