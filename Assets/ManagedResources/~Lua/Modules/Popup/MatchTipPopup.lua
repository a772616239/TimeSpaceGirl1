require("Base/BasePanel")
MatchTipPopup = Inherit(BasePanel)
local this = MatchTipPopup
local showStr = GetLanguageStrById(11572)
local isCounting = false

--初始化组件（用于子类重写）
function MatchTipPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.context = Util.GetGameObject(self.gameObject, "bg/BgMask/context"):GetComponent("Text")

    this.rewardList = {}
    this.grid = Util.GetGameObject(self.gameObject, "bg/BgMask/rewardbg/Scroll/grid")
    this.btnCanel = Util.GetGameObject(self.gameObject, "bg/BgMask/btnCancel")
    this.btnSure = Util.GetGameObject(self.gameObject, "bg/BgMask/btnGo")

    this.btnText = Util.GetGameObject(this.btnCanel, "Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function MatchTipPopup:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnSure, function ()
        PopupTipPanel.ShowTipByLanguageId(11573)
    end)

    Util.AddClick(this.btnCanel, function ()
        if isCounting then return end
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MatchTipPopup:AddListener()

end

--移除事件监听（用于子类重写）
function MatchTipPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MatchTipPopup:OnOpen()
    -- 设置提示文字
    ShowText(this.context, showStr, 2)

    -- 设置奖励
    for  i = 1, 6 do
        if not this.rewardList[i] then
            this.rewardList[i] = SubUIManager.Open(SubUIConfig.ItemView, this.grid.transform)
        end
        this.rewardList[i]:OnOpen(false, {6022, 0}, 0.9)
    end

    this.timer = nil
    local index = 5
    this.btnText.text = GetLanguageStrById(10552) .. index .. ")"
    this.timer = Timer.New(function ()
        index = index - 1
        this.btnText.text = GetLanguageStrById(10552) .. index .. ")"
        isCounting = true
        if index == 0 then
            this.btnText.text = GetLanguageStrById(10719)
            isCounting = false
            this.timer:Stop()
            self:ClosePanel()
        end
    end, 1, 5, true)

    this.timer:Start()



end

--界面关闭时调用（用于子类重写）
function MatchTipPopup:OnClose()

    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function MatchTipPopup:OnDestroy()

end

return MatchTipPopup