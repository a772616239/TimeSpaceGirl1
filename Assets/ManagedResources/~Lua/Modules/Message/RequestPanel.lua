require("Base/BasePanel")

RequestPanel = Inherit(BasePanel)
local time = 1
local index = 1
local str = {
    ".",
    "..",
    "...",
}

local lastRealTime = 0
local isShow = false
function RequestPanel:Update()
    if Time.realtimeSinceStartup - lastRealTime > time then
        if not isShow then
            isShow = true
            RequestPanel.root:SetActive(true)
            RequestPanel.time:Start()
        end
    end
end

--初始化组件（用于子类重写）
function RequestPanel:InitComponent()

    self.root = Util.GetGameObject(self.transform, "mask")
    self.text = Util.GetGameObject(self.root, "Text"):GetComponent("Text")
    self.text2 = Util.GetGameObject(self.text.gameObject, "Text2"):GetComponent("Text")

    RequestPanel.time = Timer.New(function ()
        if not IsNull(self.text2) then --销毁时可能为空
            self.text2.text = str[index]
        end
        index = index + 1
        if index > 3 then
            index = 1
        end
    end, 0.3, -1)
end

function RequestPanel:OnDestroy()
    RequestPanel.time:Stop()
end

--打开界面时会开启遮罩
--打开界面1s之后才会显示内容
function RequestPanel.Show(msg)
    UIManager.OpenPanel(UIName.RequestPanel)
    RequestPanel.text.text = msg
    RequestPanel.root:SetActive(false)
    RequestPanel.time:Stop()

    lastRealTime = Time.realtimeSinceStartup
    isShow = false
end

function RequestPanel.Hide()
    RequestPanel:ClosePanel()
end

return RequestPanel