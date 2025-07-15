require("Base/BasePanel")
PassGiftPopup = Inherit(BasePanel)
local this=PassGiftPopup
--local isGo=true
local _heroId = 0
local _heroStar = 0
---通关豪礼面板
--初始化组件（用于子类重写）
function PassGiftPopup:InitComponent()
    this.pointId=Util.GetGameObject(self.gameObject,"Panel/Top/PointId"):GetComponent("Text")
    this.liveNameText=Util.GetGameObject(self.gameObject,"Panel/Top/LiveName"):GetComponent("Text")
    this.liveParent=Util.GetGameObject(self.transform,"Panel/LiveParent")
    --this.qualityImage=Util.GetGameObject(self.gameObject,"Quality"):GetComponent("Image")
    --this.doubleQuality=Util.GetGameObject(self.gameObject,"Quality/qualityDoubleText"):GetComponent("Text")
    Util.GetGameObject(self.gameObject,"Panel/Quality"):SetActive(false)
    this.previewBtn=Util.GetGameObject(self.transform,"Panel/PreviewBtn")
    --this.goBtn=Util.GetGameObject(self.gameObject,"Panel/GoBtn")
    this.backBtn=Util.GetGameObject(self.gameObject,"Panel/BackBtn")
    this.posImage=Util.GetGameObject(self.transform,"Panel/Pos/PosImage"):GetComponent("Image")
    this.posText=Util.GetGameObject(self.transform,"Panel/Pos/PosText"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function PassGiftPopup:BindEvent()
    Util.AddClick(this.previewBtn,function()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, _heroId, _heroStar)
    end)
    --Util.AddClick(this.goBtn,function()
    --    UIManager.OpenPanel(UIName.FightPointPassMainPanel)
    --    self:ClosePanel()
    --end)
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function PassGiftPopup:AddListener()

end

--移除事件监听（用于子类重写）
function PassGiftPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function PassGiftPopup:OnOpen(...)
    --local args={...}
    --isGo=args[1]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PassGiftPopup:OnShow()
    this.OnPanelShow()
end

--界面关闭时调用（用于子类重写）
function PassGiftPopup:OnClose()
    if this.liveNode then
        poolManager:UnLoadLive(this.liveName, this.liveNode)
        this.liveName=nil
    end
    --this.goBtn:SetActive(true)
    FightPointPassManager.isBeginFight = false
end

--界面销毁时调用（用于子类重写）
function PassGiftPopup:OnDestroy()

end

--显示
function this.OnPanelShow()
    --if not isGo then
    --    this.goBtn:SetActive(false)
    --end

    --获取目标立绘信息
    local liveId,tarPointId=ActivityGiftManager.GetNextHeroInfo()
    if liveId==0 or tarPointId==0 then
        return
    end

    this.pointId.text= GetLanguageStrById(10356)..ActivityGiftManager.mainLevelConfig[tarPointId].Name..GetLanguageStrById(11577)

    --赋值立绘名
    --local heroData=ConfigManager.GetConfigData(ConfigName.HeroConfig,liveId)
    local heroStar=ConfigManager.GetConfigData(ConfigName.ItemConfig,liveId).HeroStar[1]
    local heroData=ConfigManager.GetConfigData(ConfigName.HeroConfig,heroStar)
    _heroId=heroStar
    _heroStar= heroData.Star

    if heroData.Natural==13 or heroData.Natural==14 then
        this.liveNameText.text = GetLanguageStrById(11578)..GetLanguageStrById(heroData.ReadingName).."</color>"
    elseif heroData.Natural==11 or heroData.Natural==12 then
        this.liveNameText.text = GetLanguageStrById(11579)..GetLanguageStrById(heroData.ReadingName).."</color>"
    end
    this.posImage.sprite=Util.LoadSprite(GetHeroPosStr(heroData.Profession))
    this.posText.text=heroData.HeroLocation
    --赋值资质
    --this.qualityImage.sprite=GetQuantityImage(heroData.Natural)
    --this.doubleQuality.text=heroData.Natural

    --创建立绘
    if this.liveNode then
        poolManager:UnLoadLive(this.liveName, this.liveNode)
        this.liveName=nil
    end
    local artData=ConfigManager.GetConfigData(ConfigName.ArtResourcesConfig,heroData.Live)
    this.liveName = artData.Name
    this.liveNode = poolManager:LoadLive(this.liveName, this.liveParent.transform, Vector3(heroData.Scale,heroData.Scale,heroData.Scale) , Vector3.one)
end

return PassGiftPopup