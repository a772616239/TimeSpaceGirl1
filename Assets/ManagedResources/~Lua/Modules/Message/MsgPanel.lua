require("Base/BasePanel")
MsgPanel = Inherit(BasePanel)

local str1 = GetLanguageStrById(10508)
local str2 = GetLanguageStrById(11350)
local str3 = GetLanguageStrById(11351)
--初始化组件（用于子类重写）
function MsgPanel:InitComponent()
    MsgPanel.btnLeft = Util.GetGameObject (self.transform, "panel/op/btnLeft")
    MsgPanel.btnLeftTxt = Util.GetGameObject (MsgPanel.btnLeft, "Text"):GetComponent("Text")

    MsgPanel.btnRight = Util.GetGameObject (self.transform, "panel/op/btnRight")
    MsgPanel.btnRightTxt = Util.GetGameObject (MsgPanel.btnRight, "Text"):GetComponent("Text")

    MsgPanel.title = Util.GetGameObject (self.transform, "panel/bg/title"):GetComponent("Text")
    MsgPanel.tipLabel = Util.GetGameObject (self.transform, "panel/content"):GetComponent("Text")
    MsgPanel.tips = Util.GetGameObject (self.transform, "panel/tips"):GetComponent("Text")
    MsgPanel.toggle = Util.GetGameObject (self.transform, "panel/Toggle"):GetComponent("Toggle")
    MsgPanel.toggleTxt = Util.GetGameObject (self.transform, "panel/Toggle/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function MsgPanel:BindEvent()
    Util.AddClick(MsgPanel.btnLeft, MsgPanel.OnLeftBtnClick)
    Util.AddClick(MsgPanel.btnRight, MsgPanel.OnRightBtnClick)
end

--界面关闭时调用（用于子类重写）
function MsgPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function MsgPanel:OnDestroy()
end

--左边按钮点击事件
function MsgPanel.OnLeftBtnClick()
    MsgPanel.Hide()
    if MsgPanel.leftAction then
        MsgPanel.leftAction()
    end
end

--右边按钮点击事件
function MsgPanel.OnRightBtnClick()
    MsgPanel.Hide()
    if MsgPanel.rightAction then
        MsgPanel.rightAction(MsgPanel.toggle.isOn)
    end
end

--展示一个按钮
function MsgPanel.ShowOne(msg, action, text, title)
    UIManager.OpenPanel(UIName.MsgPanel)
    MsgPanel.leftAction = action
    MsgPanel.btnLeftTxt.text = text and text or str1
    MsgPanel.tipLabel.text = msg
    MsgPanel.title.text = title and title or str3
    MsgPanel.btnLeft.gameObject:SetActive(true)
    MsgPanel.btnRight.gameObject:SetActive(false)
    MsgPanel.toggle.gameObject:SetActive(false)
end

--展示两个按钮
function MsgPanel.ShowTwo(msg, leftAction, rightAction, leftText, rightText, title, isShowToggle, toggleText, isShowTips, tipsText)
    UIManager.OpenPanel(UIName.MsgPanel)
    MsgPanel.leftAction = leftAction
    MsgPanel.rightAction = rightAction
    MsgPanel.btnLeftTxt.text = leftText and leftText or str2
    MsgPanel.btnRightTxt.text = rightText and rightText or str1
    MsgPanel.title.text = title and title or str3
    MsgPanel.tipLabel.text = msg
    MsgPanel.btnLeft.gameObject:SetActive(true)
    MsgPanel.btnRight.gameObject:SetActive(true)
    if isShowToggle then
        MsgPanel.toggle.gameObject:SetActive(true)
        if toggleText then
            MsgPanel.toggleTxt.text = toggleText
        else
            MsgPanel.toggleTxt.text = GetLanguageStrById(11352)
        end
    else
        MsgPanel.toggle.gameObject:SetActive(false)
    end

    if isShowTips then
        MsgPanel.tips.gameObject:SetActive(true)
        if tipsText then
            MsgPanel.tips.text = tipsText
        else
            MsgPanel.tips.text = GetLanguageStrById(11352)
        end
    else
        MsgPanel.tips.gameObject:SetActive(false)
    end
end

function MsgPanel.Hide()
    MsgPanel:ClosePanel()
end

return MsgPanel