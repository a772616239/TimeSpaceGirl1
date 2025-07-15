----- 通用 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local func
function this:InitComponent(gameObject)
    this.mask = Util.GetGameObject(gameObject, "Mask")
    this.title =  Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.root = Util.GetGameObject(gameObject,"Root")
    this.txt = Util.GetGameObject(this.root,"font/Text"):GetComponent("Text")
    this.cancel = Util.GetGameObject(gameObject, "CancelBtn")
    this.ConfirmBtn = Util.GetGameObject(gameObject, "ConfirmBtn")
    this.toggle = Util.GetGameObject(gameObject,"Root/Toggle"):GetComponent("Toggle")
end

function this:BindEvent()    
    Util.AddClick(this.cancel, this.sClosePanel)
    Util.AddClick(this.mask, this.sClosePanel)
    Util.AddClick(this.ConfirmBtn, this.OnRightBtnClick)
end

--左边按钮点击事件
function this.sClosePanel()
    parent:ClosePanel()
end

--右边按钮点击事件
function this.OnRightBtnClick()
    parent:ClosePanel()
    if func then
        func(this.toggle.isOn)
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
    this.txt.text = args[1]
    this.title.text = args[2]
    func = args[3]
end

function this:OnClose()
end

function this:OnDestroy()
end


return this