require("Base/BasePanel")
LogisticsMainPanel = Inherit(BasePanel)
local this = LogisticsMainPanel
local globalSystemConfig =ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)

local content = {
    --> 守护
    [1] = {
        isOpen = function ()
            return ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SUPPORT)
        end,
        id = FUNCTION_OPEN_TYPE.SUPPORT,
        sort = 1,
        clickFun = function()
            JumpManager.GoJump(7901)
        end,
        redPointId = RedPointType.Support
    },
    --> 契约
    [2] = {
        isOpen = function ()
            return ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GENERAL)
        end,
        id = FUNCTION_OPEN_TYPE.GENERAL,
        sort = 2,
        clickFun = function()
            -- JumpManager.GoJump()
            if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GENERAL) then
                NetManager.GetGeneralData(function ()
                    UIManager.OpenPanel(UIName.GeneralInfoPanel)
                end)
            else
                PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GENERAL))
            end
        end,
        redPointId = RedPointType.General
    },
    --> 先驱
    [3] = {
        isOpen = function ()
            return ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ADJUTANT)
        end,
        id = FUNCTION_OPEN_TYPE.ADJUTANT,
        sort = 3,
        clickFun = function()
            JumpManager.GoJump(7601)
        end,
        redPointId = RedPointType.Adjutant
    },
    --> 神眷者
    [4] = {
        isOpen  = function ()
            return ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER)
        end,
        id = FUNCTION_OPEN_TYPE.AIRCRAFT_CARRIER,
        sort = 4,
        clickFun = function()
            -- PopupTipPanel.ShowTipByLanguageId(10404)
            JumpManager.GoJump(80010)
        end,
        redPointId = RedPointType.Lead
    }
}

--初始化组件（用于子类重写）
function LogisticsMainPanel:InitComponent()
    this.HeadFrameView =SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)

    this.Back = Util.GetGameObject(self.gameObject, "Back")
    this.pages = {}
    for i = 1, #content do
        this.pages[i] = Util.GetGameObject(self.gameObject, "middle/page" .. i)
    end
end

--绑定事件（用于子类重写）
function LogisticsMainPanel:BindEvent()
    Util.AddClick(this.Back, function()
        self:ClosePanel()
    end)

    for i = 1, #content do
        local item= content[i]
        if item.isOpen() then
            local bg = Util.GetGameObject(this.pages[i], "bg")
            -- bg:GetComponent("Image").alphaHitTestMinimumThreshold  = 0.1
            Util.AddClick(bg, function()
                if item.clickFun then
                    item.clickFun()
                end
            end)

            BindRedPointObject(item.redPointId, Util.GetGameObject(this.pages[i], "redPoint"))
        end
    end
end

--添加事件监听（用于子类重写）
function LogisticsMainPanel:AddListener()
end

--移除事件监听（用于子类重写）
function LogisticsMainPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function LogisticsMainPanel:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LogisticsMainPanel:OnShow()
    CheckRedPointStatus(RedPointType.General)
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Logistics })
    this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.Logistics })

    for i = 1, #content do
        -- this.pages[i]:SetActive(content[i].isOpen)
        local bg = Util.GetGameObject(this.pages[i], "bg")
        local lock = Util.GetGameObject(this.pages[i], "bg/lock")
        local Text = Util.GetGameObject(this.pages[i], "bg/Text"):GetComponent("Text")
        Text.text = "LV."..globalSystemConfig[content[i].id].OpenRules[2]
        if content[i].isOpen() then
            bg:SetActive(true)
            lock:SetActive(false)
            Text.gameObject:SetActive(false)
        else
            bg:SetActive(true)
            lock:SetActive(true)
            Text.gameObject:SetActive(true)
        end
        this.pages[i].transform:SetSiblingIndex(content[i].sort - 1)
        -- if content[i].isOpen then
        --     if ActTimeCtrlManager.SingleFuncState(content[i].id) then
        --         Util.SetGray(this.pages[i], false)
        --     else
        --         Util.SetGray(this.pages[i], true)
        --     end
        -- else
        --     Util.GetGameObject(this.pages[i], "redPoint"):SetActive(false)
        -- end
    end
end

function LogisticsMainPanel.UpdateRedPoint()

end

--界面关闭时调用（用于子类重写）
function LogisticsMainPanel:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function LogisticsMainPanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.BtView)

    for i = 1, #content do
        if content[i].isOpen() then
            ClearRedPointObject(content[i].redPointId)
        end
    end
end

return LogisticsMainPanel