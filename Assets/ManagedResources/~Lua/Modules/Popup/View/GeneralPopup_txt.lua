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
    this.txt = Util.GetGameObject(this.root,"rect/content"):GetComponent("Text")
    this.ConfirmBtn = Util.GetGameObject(gameObject, "ConfirmBtn")
end

function this:BindEvent()    
    Util.AddClick(this.mask, this.sClosePanel)
    Util.AddClick(this.ConfirmBtn, this.sClosePanel)
end

--左边按钮点击事件
function this.sClosePanel()
    parent:ClosePanel()
end

--右边按钮点击事件
function this.OnRightBtnClick()
    parent:ClosePanel()
    if func then
        func()
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
end

function this:OnClose()
end

function this:OnDestroy()
end


return this