require("Base/BasePanel")
DropGetPlayerDecorateShopPanel = Inherit(BasePanel)
local callBack
local orginLayer
local backData
local testLiveGO
--初始化组件（用于子类重写）
function DropGetPlayerDecorateShopPanel:InitComponent()
    orginLayer = 0
    self.live2dRoot = Util.GetGameObject(self.gameObject, "live2dRoot")
    self.bg = Util.GetGameObject(self.gameObject, "bg")
    self.bg2 = Util.GetGameObject(self.gameObject, "bg2")
    screenAdapte(self.bg2)
    self.name = Util.GetGameObject(self.transform, "name/Text"):GetComponent("Text")
    self.infoText = Util.GetGameObject(self.transform, "infoText"):GetComponent("Text")
    self.sureBtn = Util.GetGameObject(self.transform, "sureBtn")
    self.UI_Effect_chouka = Util.GetGameObject(self.transform, "bg/UI_Effect_chouka")
end

--绑定事件（用于子类重写）
function DropGetPlayerDecorateShopPanel:BindEvent()

    Util.AddClick(self.sureBtn, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function DropGetPlayerDecorateShopPanel:AddListener()

end

--移除事件监听（用于子类重写）
function DropGetPlayerDecorateShopPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function DropGetPlayerDecorateShopPanel:OnOpen(_backData,func)

    backData = _backData
    callBack = func
end

function DropGetPlayerDecorateShopPanel:OnSortingOrderChange()

    Util.AddParticleSortLayer(self.bg, self.sortingOrder - orginLayer)
    self.live2dRoot:GetComponent("Canvas").sortingOrder =  self.sortingOrder + 10
    orginLayer = self.sortingOrder
end
local staticData
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DropGetPlayerDecorateShopPanel:OnShow()

    self.UI_Effect_chouka:SetActive(true)
    SoundManager.PlaySound(SoundConfig.Sound_Recruit3)
   staticData = ConfigManager.GetConfigData(ConfigName.PlayerAppearance,backData.itemId)
   local staticItemData = ConfigManager.GetConfigData(ConfigName.ItemConfig,backData.itemId)
    --TODO:动态加载立绘
    testLiveGO = poolManager:LoadLive(GetResourcePath(staticData.Live), self.live2dRoot.transform, Vector3.one, Vector3.zero)
    --local SkeletonGraphic = testLiveGO:GetComponent("SkeletonGraphic")
    --local idle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
    --SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
    --poolManager:SetLiveClearCall(GetResourcePath(heroStaticData.Live), testLiveGO, function ()
    --    SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idle
    --end)

    self.name.text =staticItemData.Name
    self.infoText.text =staticItemData.ItemDescribe
end

--界面关闭时调用（用于子类重写）
function DropGetPlayerDecorateShopPanel:OnClose()

    poolManager:UnLoadLive(GetResourcePath(staticData.Live), testLiveGO)
    if callBack then
        callBack()
    end
end

--界面销毁时调用（用于子类重写）
function DropGetPlayerDecorateShopPanel:OnDestroy()

end

return DropGetPlayerDecorateShopPanel