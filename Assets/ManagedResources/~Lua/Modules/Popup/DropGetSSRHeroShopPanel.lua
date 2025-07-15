require("Base/BasePanel")
DropGetSSRHeroShopPanel = Inherit(BasePanel)
local heroConfigData = ConfigManager.GetConfig(ConfigName.HeroConfig)
local heroBackData = {}
local callBack
local orginLayer
--初始化组件（用于子类重写）
function DropGetSSRHeroShopPanel:InitComponent()

    orginLayer = 0
    self.live2dRoot = Util.GetGameObject(self.gameObject, "live2dRoot")
    self.bg = Util.GetGameObject(self.gameObject, "bg")
    self.bg2 = Util.GetGameObject(self.gameObject, "bg2")
    screenAdapte(self.bg2)
    self.heroName = Util.GetGameObject(self.transform, "rolePanel/rolePanel1/nameAndPossLayout/heroName"):GetComponent("Text")
    --self.profession = Util.GetGameObject(self.transform, "rolePanel/rolePanel1/nameAndPossLayout/posImage/posImage/posImage"):GetComponent("Image")
    Util.GetGameObject(self.transform, "rolePanel/rolePanel1/nameAndPossLayout/posImage"):SetActive(false)
    self.proImage = Util.GetGameObject(self.transform, "rolePanel/rolePanel1/nameAndPossLayout/proImage/proImage"):GetComponent("Image")
    self.starGrid = Util.GetGameObject(self.transform, "rolePanel/rolePanel1/sartAndLvLayout")
    self.sureBtn = Util.GetGameObject(self.transform, "sureBtn")
    --self.dragView = SubUIManager.Open(SubUIConfig.DragView, self.gameObject.transform)
    --self.dragView.transform:SetSiblingIndex(1)
    self.UI_Effect_chouka = Util.GetGameObject(self.transform, "bg/UI_Effect_chouka")
    --self.quality=Util.GetGameObject(self.transform,"rolePanel/rolePanel1/nameAndPossLayout/quality/quality"):GetComponent("Image")
    --self.qualityImage=Util.GetGameObject(self.transform,"quality"):GetComponent("Image")
    --self.quality=Util.GetGameObject(self.transform,"quality/qualityText")
    Util.GetGameObject(self.transform,"quality"):SetActive(false)
    self.doubleQuality=Util.GetGameObject(self.transform,"quality/qualityDoubleText")
    self.posImage=Util.GetGameObject(self.transform,"Pos/PosImage"):GetComponent("Image")
    self.posText=Util.GetGameObject(self.transform,"Pos/PosText"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function DropGetSSRHeroShopPanel:BindEvent()

    Util.AddClick(self.sureBtn, function()
        self:ClosePanel()
    end)
    --Util.AddClick(this.dragView.gameObject, function ()
    --    local testLive= Util.GetGameObject(this.live2dRoot, "testLive")
    --    if testLive then
    --        local SkeletonGraphic = testLive:GetComponent("SkeletonGraphic")
    --        SkeletonGraphic.AnimationState:SetAnimation(0, "touch", false)
    --    end
    --end)
end

--添加事件监听（用于子类重写）
function DropGetSSRHeroShopPanel:AddListener()

end

--移除事件监听（用于子类重写）
function DropGetSSRHeroShopPanel:RemoveListener()

end

local heroStaticData
local testLiveGO
--界面打开时调用（用于子类重写）
function DropGetSSRHeroShopPanel:OnOpen(_heroBackData,func)

    heroBackData = _heroBackData
    callBack = func
end

function DropGetSSRHeroShopPanel:OnSortingOrderChange()

    Util.AddParticleSortLayer(self.bg, self.sortingOrder - orginLayer)
    self.live2dRoot:GetComponent("Canvas").sortingOrder =  self.sortingOrder + 10
    Util.GetGameObject(self.transform,"Pos"):GetComponent("Canvas").sortingOrder =  self.sortingOrder + 20
    orginLayer = self.sortingOrder
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DropGetSSRHeroShopPanel:OnShow()
    self.UI_Effect_chouka:SetActive(true)
    SoundManager.PlaySound(SoundConfig.Sound_Recruit3)
    heroStaticData = heroConfigData[heroBackData.heroId]
    --TODO:动态加载立绘
    testLiveGO = poolManager:LoadLive(GetResourcePath(heroStaticData.Live), self.live2dRoot.transform,
            Vector3.one * heroStaticData.Scale, Vector3.New(heroStaticData.Position[1],heroStaticData.Position[2],0))
    local SkeletonGraphic = testLiveGO:GetComponent("SkeletonGraphic")
    local idle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
    SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
    poolManager:SetLiveClearCall(GetResourcePath(heroStaticData.Live), testLiveGO, function ()
        SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idle
    end)

    --self.dragView:SetDragGO(testLiveGO)
    self.posImage.sprite=Util.LoadSprite(GetHeroPosStr(heroStaticData.Profession))
    self.posText.text=heroStaticData.HeroLocation
    local starSize = Vector2.New(60,60)
    SetHeroStars(self.starGrid, heroBackData.star)
    --self.profession.sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(heroStaticData.Profession))
    self.proImage.sprite =Util.LoadSprite(GetProStrImageByProNum(heroStaticData.PropertyName))
    self.heroName.text =GetLanguageStrById(heroStaticData.ReadingName)
    --self.quality.sprite=Util.LoadSprite(GetQualityIconByQualityNumer(heroStaticData.Natural))
    --self.qualityImage.sprite=GetQuantityImage(heroStaticData.Natural)
    --self.quality:SetActive(heroStaticData.Natural < 10)
    --self.doubleQuality:SetActive(heroStaticData.Natural >= 10)
    --self.quality:GetComponent("Text").text = heroStaticData.Natural
    --self.doubleQuality:GetComponent("Text").text = heroStaticData.Natural
    PlayUIAnim(self.transform)
end

--界面关闭时调用（用于子类重写）
function DropGetSSRHeroShopPanel:OnClose()

    poolManager:UnLoadLive(GetResourcePath(heroStaticData.Live), testLiveGO)
    if callBack then
        callBack()
    end
end

--界面销毁时调用（用于子类重写）
function DropGetSSRHeroShopPanel:OnDestroy()

end

return DropGetSSRHeroShopPanel