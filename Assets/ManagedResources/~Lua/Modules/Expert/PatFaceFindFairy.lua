local patFaceFindFairy = quick_class("patFaceFindFairy")
local this = patFaceFindFairy
local patFaceSingleData
local heroData
function patFaceFindFairy:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
--初始化组件（用于子类重写）
function patFaceFindFairy:InitComponent(gameObject)

    this.proImage = Util.GetGameObject(gameObject, "heroInfo/proImage"):GetComponent("Image")
    this.posImage = Util.GetGameObject(gameObject, "heroInfo/posImage/posImage"):GetComponent("Image")
    this.nameText = Util.GetGameObject(gameObject, "heroInfo/nameText"):GetComponent("Text")
    this.nameText2 = Util.GetGameObject(gameObject, "activityTextIcon/Text"):GetComponent("Text")
    this.qualityDoubleText = Util.GetGameObject(gameObject, "heroInfo/qualityDoubleText"):GetComponent("Text")
    this.time = Util.GetGameObject(gameObject, "activityTextIcon/time"):GetComponent("Text")
    this.live2d = Util.GetGameObject(gameObject, "live2d")
    this.btnBack = Util.GetGameObject(gameObject, "btnBack")
    this.click = Util.GetGameObject(gameObject, "heroInfo/click")
end

--绑定事件（用于子类重写）
function patFaceFindFairy:BindEvent()

    Util.AddClick(this.btnBack, function()
       UIManager.ClosePanel(UIName.PatFacePanel)
    end)
    Util.AddClick(this.click, function()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroData.Id, heroData.Star)
    end)
end

--添加事件监听（用于子类重写）
function patFaceFindFairy:AddListener()

end

--移除事件监听（用于子类重写）
function patFaceFindFairy:RemoveListener()

end

--界面打开时调用（用于子类重写）
function patFaceFindFairy:OnOpen(...)

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function patFaceFindFairy:OnShow(_patFaceSingleData)

    patFaceSingleData = _patFaceSingleData
    this:PatFaceShow()
end
function patFaceFindFairy:PatFaceShow()
    local curActivityId=ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    heroData=FindFairyManager.GetHeroData(curActivityId)
    --创建立绘
    if this.liveNode then
        poolManager:UnLoadLive(this.liveName, this.liveNode)
        this.liveName=nil
    end
    local artData=ConfigManager.GetConfigData(ConfigName.ArtResourcesConfig,heroData.Live)
    this.liveName = artData.Name
    this.liveNode = poolManager:LoadLive(this.liveName, this.live2d.transform, Vector3.one*heroData.Scale , Vector3.one)

    Util.AddOnceClick(this.live2d.gameObject,function()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup,false,heroData.Id,heroData.Star)
    end)

    this.posImage.sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(heroData.Profession))
    this.proImage.sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.PropertyName))
    this.nameText.text = GetLanguageStrById(heroData.ReadingName)
    this.nameText2.text = "【"..GetLanguageStrById(heroData.ReadingName).."】"
    this.qualityDoubleText.text = heroData.Natural
    local acitvityData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FindFairy)--ActivityGiftManager.GetActivityInfo(ActivityTypeDef.FindFairy, curActivityId)
    this.time.text = GetLanguageStrById(10546)..PatFaceManager.GetTimeStrBySeconds(acitvityData.startTime).."-"..PatFaceManager.GetTimeStrBySeconds(acitvityData.endTime - 60*60*24)
end
--界面关闭时调用（用于子类重写）
function patFaceFindFairy:OnClose()

    if this.liveNode then
        poolManager:UnLoadLive(this.liveName, this.liveNode)
        this.liveName=nil
    end
end

--界面销毁时调用（用于子类重写）
function patFaceFindFairy:OnDestroy()

end

return patFaceFindFairy