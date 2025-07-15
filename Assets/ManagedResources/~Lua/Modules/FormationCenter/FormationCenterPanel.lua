require("Base/BasePanel")
FormationCenterPanel = Inherit(BasePanel)
local this = FormationCenterPanel
local investigateLevel
local investigateConfig
local nextInvestigateConfig
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)

--初始化组件（用于子类重写）
function FormationCenterPanel:InitComponent()
    this.closeBtn = Util.GetGameObject(self.gameObject,"bg/closeBtn")

    this.Star = Util.GetGameObject(self.gameObject,"bg/name/star")
    this.nameBg = Util.GetGameObject(self.gameObject,"bg/name")
    this.name = Util.GetGameObject(self.gameObject,"bg/name/Text")
    this.icon = Util.GetGameObject(self.gameObject,"bg/icon")

    -- this.proBg = Util.GetGameObject(self.gameObject,"bg/pro/proBg")
    this.arrow = Util.GetGameObject(self.gameObject,"bg/arrow")
    this.curContent = Util.GetGameObject(self.gameObject,"bg/cur/Viewport/Content")
    this.nextContent = Util.GetGameObject(self.gameObject,"bg/next/Viewport/Content")
    this.maxContent = Util.GetGameObject(self.gameObject,"bg/max/Viewport/Content")
    this.curStar = Util.GetGameObject(self.gameObject,"bg/pro/curStar")
    this.nextStar = Util.GetGameObject(self.gameObject,"bg/pro/nextStar")
    this.proPrefab = Util.GetGameObject(self.gameObject,"bg/pro/proPrefab")

    this.maxTip = Util.GetGameObject(self.gameObject,"bg/maxTip")

    this.Item = Util.GetGameObject(self.gameObject,"bg/Item")
    this.ItemIcon = Util.GetGameObject(self.gameObject,"bg/Item/icon")
    this.ItemNum = Util.GetGameObject(self.gameObject,"bg/Item/num")

    this.helpBtn = Util.GetGameObject(self.gameObject,"bg/helpBtn")
    this.upBtn = Util.GetGameObject(self.gameObject,"bg/upBtn")
    this.exchangeBtn = Util.GetGameObject(self.gameObject,"bg/exchangeBtn")

    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)


    this.everyday = Util.GetGameObject(self.gameObject,"bg/everyday")
end

--绑定事件（用于子类重写）
function FormationCenterPanel:BindEvent()      
    Util.AddClick(this.closeBtn,function ()
        self:ClosePanel()
    end)

    Util.AddClick(this.helpBtn,function ()
        UIManager.OpenPanel(UIName.FormationCenterTipPanel)
    end)

    Util.AddClick(this.upBtn,function ()
        local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
        NetManager.FormationCenterActiveRequest(
            function ()
                investigateLevel = investigateLevel + 1
                FormationCenterManager.SetInvestigateLevel(investigateLevel)
                UIManager.OpenPanel(UIName.FormationCenterActiveOrUpgradeSuccessPanel,1,investigateLevel)
                FormationManager.FlutterPower(oldPower)
            end)
    end)

    Util.AddClick(this.exchangeBtn,function ()
       UIManager.OpenPanel(UIName.MapShopPanel,FormationCenterManager.GetStoreId())
    end)
    --消耗材料预览
    Util.AddOnceClick(this.Image_CostBg,function()
        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,investigateConfig.Consume[1])
    end)
end

--添加事件监听（用于子类重写）
function FormationCenterPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.FormationCenter.OnFormationCenterLevelChange, this.OnShow)
end

--移除事件监听（用于子类重写）
function FormationCenterPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.FormationCenter.OnFormationCenterLevelChange, this.OnShow)
end


--界面打开时调用（用于子类重写）
function FormationCenterPanel:OnOpen()
end

function FormationCenterPanel:OnShow()
    this.PlayerHeadFrameView:OnShow(true)
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.QiMingXingKeJi })

    investigateLevel = FormationCenterManager.GetInvestigateLevel()
    investigateConfig = ConfigManager.GetConfigData(ConfigName.InvestigateConfig,investigateLevel)

    SetHeroStars(this.Star,investigateLevel)
    this.name:GetComponent("Text").text = GetLanguageStrById(investigateConfig.Name)
    this.icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(investigateConfig.ArtResourcesId))

    local config = ConfigManager.GetConfigData(ConfigName.ItemConfig, investigateConfig.DailyReward[1][1])

    Util.GetGameObject(this.everyday, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(config.Quantity))
    Util.GetGameObject(this.everyday, "frame/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(config.ResourceID))
    Util.GetGameObject(this.everyday, "frame/Text"):GetComponent("Text").text = investigateConfig.DailyReward[1][2]

    this.maxTip:SetActive((investigateConfig.NextLevel == 0))
    this.curContent:SetActive(investigateConfig.NextLevel ~= 0)
    this.nextContent:SetActive(investigateConfig.NextLevel ~= 0)
    this.maxContent:SetActive(investigateConfig.NextLevel == 0)
    this.upBtn:SetActive(investigateConfig.NextLevel ~= 0)
    this.curStar:SetActive(investigateConfig.NextLevel ~= 0)
    this.nextStar:SetActive(investigateConfig.NextLevel ~= 0)
    this.Item:SetActive(investigateConfig.NextLevel ~= 0)
    this.arrow:SetActive(investigateConfig.NextLevel ~= 0)
    -- this.exchangeBtn:SetActive(investigateConfig.NextLevel == 0)

   --下一级属性
   if investigateConfig.NextLevel ~= 0 then
        SetHeroStars(this.curStar,investigateLevel)
        SetHeroStars(this.nextStar,investigateLevel + 1)
        nextInvestigateConfig = ConfigManager.TryGetConfigData(ConfigName.InvestigateConfig,investigateLevel + 1)

        this.SetPro(investigateConfig,this.curContent)
        this.SetPro(nextInvestigateConfig,this.nextContent)

        local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig, investigateConfig.Consume[1])
        local resourceID = itemConfig.ResourceID
        this.Item:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig.Quantity))
        this.ItemIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(resourceID))
        local str = PrintWanNum(BagManager.GetTotalItemNum(itemConfig.Id))
        if BagManager.GetTotalItemNum(itemConfig.Id) < investigateConfig.Consume[2] then
            str = string.format("<color=#FF6868>%s</color>",PrintWanNum(BagManager.GetTotalItemNum(itemConfig.Id)))
        end
        this.ItemNum:GetComponent("Text").text = str .. "/".. investigateConfig.Consume[2]

        ItemImageTips(itemConfig.Id, this.Item)
    else
        this.SetPro(investigateConfig,this.maxContent)
    end
end

function this.SetPro(data,content)
    Util.ClearChild(content.transform)
    for i = 1, #data.PropertyAdd do
        local go = newObjToParent(this.proPrefab, content)
        local name = Util.GetGameObject(go,"name"):GetComponent("Text")
        local value = Util.GetGameObject(go,"value"):GetComponent("Text")
        name.text = GetLanguageStrById(propertyConfig[data.PropertyAdd[i][1]].Info)
        value.text = "+"..GetPropertyFormatStr(propertyConfig[data.PropertyAdd[i][1]].Style,data.PropertyAdd[i][2])
        go:GetComponent("Image").sprite = Util.LoadSprite(propertyConfig[data.PropertyAdd[i][1]].Icon)
    end
end

--界面关闭时调用（用于子类重写）
function FormationCenterPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function FormationCenterPanel:OnDestroy()
    SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.UpView)
end

return FormationCenterPanel