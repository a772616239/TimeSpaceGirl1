require("Base/BasePanel")
XiaoYaoRewardPreviewPanel = Inherit(BasePanel)
local this = XiaoYaoRewardPreviewPanel

--初始化组件（用于子类重写）
function this:InitComponent()
    -- this.spLoader = SpriteLoader.New()
    this.BtnBack = Util.GetGameObject(self.transform, "bg/btnBack")
    this.grid= Util.GetGameObject(self.transform, "bg/Scroll/Grid")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.BtnBack, function ()        
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()

end

--移除事件监听（用于子类重写）
function this:RemoveListener()

end

--界面打开时调用（用于子类重写）
function this:OnOpen(...)
   
    
end

function this:OnShow()
    local rewardList=ConfigManager.GetConfigDataByKey(ConfigName.FreeTravel,"MapID",XiaoYaoManager.curMapId).Exhibition
    for i = 1, #rewardList do
        Log(rewardList[i])
        local _rewardObj= SubUIManager.Open(SubUIConfig.ItemView, this.grid.transform)
        _rewardObj:OnOpen(false, {rewardList[i]}, 1,true)
    end
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    while(this.grid.transform.childCount>0)
    do
        destroy(this.grid.transform:GetChild(0).gameObject)
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy() 
    -- this.spLoader:Destroy()

end

return XiaoYaoRewardPreviewPanel