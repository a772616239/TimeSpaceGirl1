require("Base/BasePanel")
DefenseTrainingRewardPopup = Inherit(BasePanel)
local this = DefenseTrainingRewardPopup

--初始化组件（用于子类重写）
function DefenseTrainingRewardPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "bg/btnClose")

    this.Review = {}
    for i = 1, 3 do
        this.Review[i] = Util.GetGameObject(self.gameObject, "bg/Review" .. tostring(i) .. "/Grid")
    end
    this.repeatItemView = {}
end

--绑定事件（用于子类重写）
function DefenseTrainingRewardPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function DefenseTrainingRewardPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function DefenseTrainingRewardPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function DefenseTrainingRewardPopup:OnOpen()
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DefenseTrainingRewardPopup:OnShow()
    local idx = 1
    for i = 1, #this.Review do
        local rewardIds = DefenseTrainingManager.GetAllRewardNoRepeatIds(i)
        for j = 1, #rewardIds do
            if not this.repeatItemView[idx] then
                this.repeatItemView[idx] = SubUIManager.Open(SubUIConfig.ItemView, this.Review[i].transform)
            end
            this.repeatItemView[idx]:OnOpen(false, {rewardIds[j], 0}, 0.6, nil, nil, nil, nil, nil)
    
            idx = idx + 1
        end
        
    end
end

--界面关闭时调用（用于子类重写）
function DefenseTrainingRewardPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function DefenseTrainingRewardPopup:OnDestroy()
    this.repeatItemView = {}
end

return DefenseTrainingRewardPopup