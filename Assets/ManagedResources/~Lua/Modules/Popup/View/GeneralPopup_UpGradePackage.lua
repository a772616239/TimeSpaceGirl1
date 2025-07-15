local this = {}
--传入父脚本模块
local parent
local func

function this:InitComponent(gameObject)
    this.titleText = Util.GetGameObject(gameObject,"title"):GetComponent("Text")
    this.cancelBtn = Util.GetGameObject(gameObject,"CancelBtn")
    this.confirmBtn = Util.GetGameObject(gameObject,"ConfirmBtn")
    this.time = Util.GetGameObject(gameObject,"CancelBtn/Text"):GetComponent("Text")
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()
        if func then
            func()
        end
        parent:ClosePanel()
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent, _title,_func)
    parent = _parent
    func = _func
    this.titleText.text = _title

    if this.timer then
        this.timer:Stop()
    end
    if this.timer2 then
        this.timer2:Stop()
    end
    this:StartCountdown()
end

function this:OnClose()
end

function this:OnDestroy()
    if this.timer then
        this.timer:Stop()
    end
    if this.timer2 then
        this.timer2:Stop()
    end
end

--开始选择BUFF倒计时
function this:StartCountdown()
    local time = 10
    this.timer = Timer.New(function ()
        parent:ClosePanel()
    end,time,1)

    this.time.text = GetLanguageStrById(10719) .. "(" .. time .. ")"
    this.timer2 = Timer.New(function()
        time = time - 1
        if time < 0 then time = 0 end
        this.time.text = GetLanguageStrById(10719) .. "(" .. time .. ")"
    end, 1, -1, true)

    this.timer:Start()
    this.timer2:Start()
end

return this