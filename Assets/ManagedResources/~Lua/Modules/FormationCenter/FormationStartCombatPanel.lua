-- require("Base/BasePanel")
-- FormationStartCombatPanel = Inherit(BasePanel)
local FormationStartCombatPanel = {}
local this = FormationStartCombatPanel

function FormationStartCombatPanel:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b, { __index = FormationStartCombatPanel })
    return b
end




local myLevel
local enemyLevel
local func
--初始化组件（用于子类重写）
function FormationStartCombatPanel:InitComponent()
    this.backBtn=Util.GetGameObject(self.gameObject,"bg")
    this.Image_MyFormation=Util.GetGameObject(self.gameObject,"bg/my/Image_MyFormation")
    this.Image_EnemyFormation=Util.GetGameObject(self.gameObject,"bg/enemy/Image_EnemyFormation")
    this.MyStarContent=Util.GetGameObject(self.gameObject,"bg/my/MyStarContent")
    this.EnemyStarContent=Util.GetGameObject(self.gameObject,"bg/enemy/EnemyStarContent")
    this.MyNotActive=Util.GetGameObject(self.gameObject,"bg/my/Text_MyNotActive")
    this.EnemyNotActive=Util.GetGameObject(self.gameObject,"bg/enemy/Text_EnemyNotActive")

    this.Boss=Util.GetGameObject(self.gameObject,"bg/Boss")

    this.Animator = this.Button_Back:GetComponent("Animator")
    this.Button_Back:SetActive(false)
end

--绑定事件（用于子类重写）
function FormationStartCombatPanel:BindEvent()   

    Util.AddClick(this.backBtn,function()
        --self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function FormationStartCombatPanel:AddListener()

end

--移除事件监听（用于子类重写）
function FormationStartCombatPanel:RemoveListener()

end


--界面打开时调用（用于子类重写）
function FormationStartCombatPanel:OnOpen(...)
     local args={...}
     myLevel=args[1]
     enemyLevel=args[2]
     if args[3] then
         func=args[3]
     end
end

function FormationStartCombatPanel:OnShow()
--    local investigateConfig=ConfigManager.GetConfigData(ConfigName.InvestigateConfig,myLevel)
--    this.Image_MyFormation:GetComponent("Image").sprite=Util.LoadSprite(investigateConfig.ArtResourcesId)
--    SetHeroStars(this.MyStarContent.transform,myLevel)
--    investigateConfig=ConfigManager.GetConfigData(ConfigName.InvestigateConfig,enemyLevel)
--    this.Image_EnemyFormation:GetComponent("Image").sprite=Util.LoadSprite(investigateConfig.ArtResourcesId)
--    SetHeroStars(this.EnemyStarContent.transform,myLevel)
    this.Animator.enabled = true
    this.Button_Back:SetActive(true)

   if not ActTimeCtrlManager.SingleFuncState(JumpType.InvestigateCenter) then
    this.Image_MyFormation:SetActive(false)
    this.Image_EnemyFormation:SetActive(false)
    this.MyStarContent:SetActive(false)
    this.EnemyStarContent:SetActive(false)
    this.MyNotActive:SetActive(false)
    this.EnemyNotActive:SetActive(false)
   else
    this.Image_MyFormation:SetActive(true)
    this.Image_EnemyFormation:SetActive(true)
    this.MyStarContent:SetActive(true)
    this.EnemyStarContent:SetActive(true)
   
    this.EnemyNotActive:SetActive(false)
    local investigateConfig
    if myLevel == 0 then
        investigateConfig=ConfigManager.GetConfigData(ConfigName.InvestigateConfig,1)   
        Util.SetGray(this.Image_MyFormation, true) 
        this.MyNotActive:SetActive(true)                
    else
        this.MyNotActive:SetActive(false)      
        investigateConfig=ConfigManager.GetConfigData(ConfigName.InvestigateConfig,myLevel)                   
    end
    this.Image_MyFormation:GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(investigateConfig.ArtResourcesId))
    SetHeroStars(this.MyStarContent,investigateConfig.Id)

    if enemyLevel==nil or enemyLevel == 0 then
        investigateConfig=ConfigManager.GetConfigData(ConfigName.InvestigateConfig,1)   
        Util.SetGray(this.Image_EnemyFormation, true) 
        this.EnemyNotActive:SetActive(true)                
    else
        this.EnemyNotActive:SetActive(false)      
        investigateConfig=ConfigManager.GetConfigData(ConfigName.InvestigateConfig,enemyLevel)                   
    end
    this.Image_EnemyFormation:GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(investigateConfig.ArtResourcesId))
    SetHeroStars(this.EnemyStarContent,investigateConfig.Id)
    end

    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end    
    this.timer = Timer.New(function()
        -- self:ClosePanel()
        this.Animator.enabled = false
        this.Button_Back:SetActive(false)
        if func then
            func()
        end
        this.timer:Stop()
        this.timer = nil
    end, 2, -1, true)
    this.timer:Start()


    this.Boss:SetActive(false)
    if G_MainLevelConfig[FightPointPassManager.curOpenFight].BossDrop == 1 then
        this.Boss:SetActive(true)
    end
end

--界面关闭时调用（用于子类重写）
function FormationStartCombatPanel:OnClose()
   if func then
       func()
   end
end

--界面销毁时调用（用于子类重写）
function FormationStartCombatPanel:OnDestroy()

end

return FormationStartCombatPanel