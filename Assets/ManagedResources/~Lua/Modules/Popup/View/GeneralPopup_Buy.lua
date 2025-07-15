----- 招募二次确认弹窗 -----
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
    this.icon = Util.GetGameObject(gameObject,"Root/font/Image"):GetComponent("Image")
    this.txt = Util.GetGameObject(gameObject,"Root/font/num"):GetComponent("Text")
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
    this.icon.sprite = Util.LoadSprite(GetResourcePath(args[1]))
    this.txt.text = args[2]
    func = args[3]
    if args[4] ~= nil then
        this.toggle.gameObject:SetActive(args[4])
    else
        this.toggle.gameObject:SetActive(true)
    end
end

function this:OnClose()
end

function this:OnDestroy()
end


return this