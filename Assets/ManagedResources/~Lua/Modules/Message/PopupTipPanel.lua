require("Base/BasePanel")
require("Base/Stack")
PopupTipPanel = Inherit(BasePanel)
local itemListPrefab = Stack.New()
local colorItemPrefab = Stack.New()
--初始化组件（用于子类重写）
function PopupTipPanel:InitComponent()
    PopupTipPanel.popup = Util.GetGameObject (self.transform, "item")
    PopupTipPanel.cache = Util.GetGameObject (self.transform, "itemCache")

    -- 带颜色的条
    PopupTipPanel.colorPopup = Util.GetGameObject (self.transform, "colorItem")
end

--添加事件监听（用于子类重写）
function PopupTipPanel:AddListener()

end

--移除事件监听（用于子类重写）
function PopupTipPanel:RemoveListener()

end

--关闭弹出信息
function PopupTipPanel.CloseTip()
    PopupTipPanel:ClosePanel()
end

--显示弹出信息
function PopupTipPanel.ShowTip(str)
    UIManager.OpenPanel(UIName.PopupTipPanel)
    PopupTipPanel:SetSortingOrder(6600)
    local go = itemListPrefab:Peek()
    if not go then
        go = newObject(PopupTipPanel.popup)
        go.transform:SetParent(PopupTipPanel.cache.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go:SetActive(true)
        itemListPrefab:Push(go)
    end
    go = itemListPrefab:Pop()
    go.transform:SetParent(PopupTipPanel.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition=Vector3.zero
    Util.GetGameObject (go, "Text"):GetComponent("Text").text = str
    PlayUIAnim(go, function ()
        go.transform:SetParent(PopupTipPanel.cache.transform)
        itemListPrefab:Push(go)
    end)
end

--显示弹出信息,参数为languageId
function PopupTipPanel.ShowTipByLanguageId(languageId)
    UIManager.OpenPanel(UIName.PopupTipPanel)
    local go = itemListPrefab:Peek()
    if not go then
        go = newObject(PopupTipPanel.popup)
        go.transform:SetParent(PopupTipPanel.cache.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go:SetActive(true)
        itemListPrefab:Push(go)
    end
    go = itemListPrefab:Pop()
    go.transform:SetParent(PopupTipPanel.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition=Vector3.zero
    Util.GetGameObject (go, "Text"):GetComponent("Text").text = GetLanguageStrById(languageId)
    PlayUIAnim(go, function ()
        go.transform:SetParent(PopupTipPanel.cache.transform)
        itemListPrefab:Push(go)
    end)
end

-- 有颜色的物品浮窗
function PopupTipPanel.ShowColorTip(name, icon, num)
    UIManager.OpenPanel(UIName.PopupTipPanel)
    local go = colorItemPrefab:Peek()
    if not go then
        go = newObject(PopupTipPanel.colorPopup)
        go.transform:SetParent(PopupTipPanel.cache.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go:SetActive(true)
        colorItemPrefab:Push(go)
    end
    go = colorItemPrefab:Pop()
    go.transform:SetParent(PopupTipPanel.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition=Vector3.zero

    -- 设置数据
    local itemName = Util.GetGameObject(go, "root/name")
    local itemIcon = Util.GetGameObject(go, "root/icon/Image")
    local itemNum = Util.GetGameObject(go, "root/num")

    itemName:GetComponent("Text").text = GetLanguageStrById(name)
    itemIcon:GetComponent("Image").sprite = icon
    itemNum:GetComponent("Text").text = num


    PlayUIAnim(go, function ()
        go.transform:SetParent(PopupTipPanel.cache.transform)
        colorItemPrefab:Push(go)
    end)
end

return PopupTipPanel