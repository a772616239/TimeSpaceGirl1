require("Base/BasePanel")
BoxRewardShowPopup = Inherit(BasePanel)
local reward
local posX
local poxY
local titleStr
local itemGird = {}
--初始化组件（用于子类重写）
function BoxRewardShowPopup:InitComponent()
    self.RewardPanel = Util.GetGameObject(self.transform, "mask/RewardPanel")
    self.rewardMaskBtn = Util.GetGameObject(self.transform, "mask/rewardMaskBtn")
    self.RewardPanelGetInfo = Util.GetGameObject(self.transform, "mask/RewardPanel/getInfo"):GetComponent("Text")
    self.RewardPanelGrid = Util.GetGameObject(self.transform, "mask/RewardPanel/ViewRect/grid")
end

--绑定事件（用于子类重写）
function BoxRewardShowPopup:BindEvent()
    Util.AddClick(self.rewardMaskBtn, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function BoxRewardShowPopup:AddListener()
end

--移除事件监听（用于子类重写）
function BoxRewardShowPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BoxRewardShowPopup:OnOpen(_reward,_posX,_poxY,_titleStr)
    reward = _reward
    posX = _posX
    poxY = _poxY
    titleStr = _titleStr or ""
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BoxRewardShowPopup:OnShow()
    self.RewardPanelGetInfo.text = titleStr
    if reward and #reward > 0 then
        for i = 1, #reward do
            if itemGird[i] then
                itemGird[i]:OnOpen(false,reward[i], 1)
            else
                itemGird[i] = SubUIManager.Open(SubUIConfig.ItemView, self.RewardPanelGrid.transform)
                itemGird[i]:OnOpen(false, reward[i], 1)
            end
        end
    end
    if posX then
        if posX > 0 then
            posX = posX - 160
        else
            posX = posX + 160
        end
        self.RewardPanel.transform.anchoredPosition=Vector3.New(posX,poxY + 500)
    end
end

--界面关闭时调用（用于子类重写）
function BoxRewardShowPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function BoxRewardShowPopup:OnDestroy()
    itemGird = {}
end

return BoxRewardShowPopup