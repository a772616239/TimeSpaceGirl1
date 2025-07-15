require("Base/BasePanel")
local TrialResetPopup = Inherit(BasePanel)
local this = TrialResetPopup

--初始化组件（用于子类重写）
function TrialResetPopup:InitComponent()
    this.cancelResetBtn = Util.GetGameObject(self.gameObject, "bg/cancelBtn")
    this.sureResetBtn = Util.GetGameObject(self.gameObject, "bg/sureBtn")
    this.floorNumberText = Util.GetGameObject(self.gameObject, "bg/floorNumberText"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function TrialResetPopup:BindEvent()--重置炼狱副本
    --取消进行重置
    Util.AddClick(this.cancelResetBtn, function()
        this:ClosePanel()
    end)
    --确定重置
    Util.AddClick(this.sureResetBtn, function()
        NetManager.RequestResetTrialMap(function(msg)
            MapTrialManager.curTowerLevel = msg.tower
            MapTrialManager.isCanReset = 0
            PrivilegeManager.RefreshPrivilegeUsedTimes(17, 1)
            MapTrialManager.resetCount = PrivilegeManager.GetPrivilegeRemainValue(17)
            -- 删除商店数据
            ShopManager.RequestAllShopData(function()
                -- 关闭当前界面
                this:ClosePanel()
                --执行成功回调
                if this.func then
                    this.func()
                end
                PopupTipPanel.ShowTipByLanguageId(10383)
            end)
        end)
    end)
end

--添加事件监听（用于子类重写）
function TrialResetPopup:AddListener()
end

--移除事件监听（用于子类重写）
function TrialResetPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function TrialResetPopup:OnOpen(func)
    this.floorNumberText.text = MapTrialManager.curTowerLevel
    this.func = func
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function TrialResetPopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function TrialResetPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function TrialResetPopup:OnDestroy()
end

return TrialResetPopup