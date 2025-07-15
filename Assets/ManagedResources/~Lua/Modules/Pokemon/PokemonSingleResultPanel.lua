require("Base/BasePanel")
PokemonSingleResultPanel = Inherit(BasePanel)
local this=PokemonSingleResultPanel
local heroConfigData = ConfigManager.GetConfig(ConfigName.SpiritAnimal)
local lotterySetting=ConfigManager.GetConfig(ConfigName.LotterySetting)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local privilegeConfig=ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local passiveSkillConfig=ConfigManager.GetConfig(ConfigName.SpiritAnimalSkill)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

local isFirst = true--是否为第一次进入界面
local timeNum--第一个特效等待播放的时间
local timeNum2--第二个特效等待播放的时间
local timeNum3--第三个特效等待播放的时间
local type --抽卡类型
local index=0 --十连抽索引
local activityId--活动id

local orginLayer
local heroStaticData
local testLiveGO
local _heroTable = {} --符合4、5星的英雄容器
local isFree = false
local drop = {}

--初始化组件（用于子类重写）
function PokemonSingleResultPanel:InitComponent()
    orginLayer = 0
    this.bg = Util.GetGameObject(self.gameObject, "bg")
    screenAdapte(this.bg)
    this.rolePanel = Util.GetGameObject(self.transform, "rolePanel")
    this.live2dRoot = Util.GetGameObject(this.rolePanel, "live2dRoot")
    this.heroName = Util.GetGameObject(this.rolePanel, "rolePanel1/Panel/name"):GetComponent("Text")
    this.Title = Util.GetGameObject(this.rolePanel, "rolePanel1/Panel/Title"):GetComponent("Text")
    this.icon = Util.GetGameObject(this.rolePanel, "rolePanel1/Panel/info/frame/icon"):GetComponent("Image")
    this.content = Util.GetGameObject(this.rolePanel, "rolePanel1/Panel/info/content"):GetComponent("Text")

    this.goBtn=Util.GetGameObject(this.rolePanel,"rolePanel2/goBtn")
    this.UI_Effect_choukaSSR = Util.GetGameObject(self.transform, "bg/UI_Effect_chouka_SSR")
    this.UI_Effect_choukaSR = Util.GetGameObject(self.transform, "bg/UI_Effect_chouka_SR")
    this.UI_Effect_choukaR = Util.GetGameObject(self.transform, "bg/UI_Effect_chouka_R")
end

--绑定事件（用于子类重写）
function PokemonSingleResultPanel:BindEvent()
    --确定按钮
    Util.AddClick(self.goBtn,function()
        self:TenOpenPanel()
    end)
end

--添加事件监听（用于子类重写）
function PokemonSingleResultPanel:AddListener()

end

--移除事件监听（用于子类重写）
function PokemonSingleResultPanel:RemoveListener()

end

function PokemonSingleResultPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.bg, self.sortingOrder - orginLayer)
    this.rolePanel:GetComponent("Canvas").sortingOrder = self.sortingOrder + 5
    orginLayer = self.sortingOrder
end

--界面打开时调用（用于子类重写）
function PokemonSingleResultPanel:OnOpen(...)   
    SoundManager.PlaySound(SoundConfig.Sound_Recruit1)
    this.UI_Effect_choukaSSR:SetActive(false)
    this.UI_Effect_choukaSR:SetActive(false)
    this.UI_Effect_choukaR:SetActive(false)
    this.rolePanel:SetActive(false)

    local args = { ... }
    type = args[1]
    drop = args[2]
    activityId = args[3]
    _heroTable = drop.pokemon
end

function PokemonSingleResultPanel:OnShow()
    index = 1
    isFirst = true
    this:TenOpenPanel()
end
function PokemonSingleResultPanel:TenOpenPanel()     
    Timer.New(function ()
        if _heroTable and #_heroTable > 0 and _heroTable[index] then
            this:UpdataPanelData(_heroTable[index])
            isFirst = false
            index = index + 1
        else
            self:ClosePanel() 
        end
    end, 0.1):Start()       
end

function PokemonSingleResultPanel:UpdataPanelData(_heroData)
    if heroStaticData and testLiveGO then
        poolManager:UnLoadLive(GetResourcePath(heroStaticData.Live), testLiveGO)
        heroStaticData, testLiveGO = nil, nil
    end
    --赋值展示界面数据
    
    -- local time2 = Timer.New(function ()
        heroStaticData = heroConfigData[_heroData.tempId]
        SoundManager.PlaySound(SoundConfig.Sound_Recruit3)
        --不同星级开启不同特效
        this.UI_Effect_choukaSSR:SetActive(heroStaticData.Quality == 5)
        this.UI_Effect_choukaSR:SetActive(heroStaticData.Quality == 4)
        this.UI_Effect_choukaR:SetActive(heroStaticData.Quality == 3 or heroStaticData.Quality == 2 or heroStaticData.Quality == 1)
        --TODO:动态加载立绘
        testLiveGO=this.LoadHerolive(GetResourcePath(heroStaticData.Live),self.live2dRoot.transform)
        -- testLiveGO = poolManager:LoadLive(GetResourcePath(heroStaticData.Live), self.live2dRoot.transform,
        --         Vector3.one * heroStaticData.Scale, Vector3.New(heroStaticData.Position[1],heroStaticData.Position[2],0))
        -- local SkeletonGraphic = testLiveGO:GetComponent("SkeletonGraphic")
        -- local idle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
        -- SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
        -- poolManager:SetLiveClearCall(GetResourcePath(heroStaticData.Live), testLiveGO, function ()
        --     SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idle
        -- end)
        this.heroName.text = heroStaticData.Name 
        this.Title.text = heroStaticData.Description 
        this.icon.sprite=Util.LoadSprite(artResourcesConfig[heroStaticData.Icon].Name)      
        this.content.text = passiveSkillConfig[heroStaticData.SkillArray[1][2]].Desc

        this.rolePanel:SetActive(true)
        this.goBtn:SetActive(true)
        PlayUIAnim(self.transform)
end

function this.LoadHerolive(_heroData, _objPoint)
    -- TODO:动态加载立绘
    
    local roleStaticImg = poolManager:LoadAsset(_heroData, PoolManager.AssetType.GameObject)
    roleStaticImg.transform:SetParent(_objPoint.transform)
    roleStaticImg.transform.localScale = Vector3.one --m5
    roleStaticImg.transform.localPosition = Vector3.zero
    roleStaticImg.name = "TestImg"
    -- local testLive = poolManager:LoadAsset(GetResourcePath(spiritAnimal[_heroData.id].Live), PoolManager.AssetType.GameObject)
    -- testLive:parent
    -- local SkeletonGraphic = testLive:GetComponent("SkeletonGraphic")
    -- local idle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
    -- SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
    -- poolManager:SetLiveClearCall(GetResourcePath(spiritAnimal[_heroData.id].Live), testLive, function ()
    --     SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idle
    -- end)
    return roleStaticImg
end
function PokemonSingleResultPanel:OnClose()
    index=0
    if heroStaticData then
        poolManager:UnLoadLive(GetResourcePath(heroStaticData.Live), testLiveGO)
    end
    heroStaticData, testLiveGO = nil, nil
    if activityId then--限时活动抽卡
        local singleRecruit
        local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",activityId)
        singleRecruit = array[1]
        if type == singleRecruit.Id then
            UIManager.OpenPanel(UIName.LingShouBaoGeOneResultPanel, drop,type,activityId)
        else
            UIManager.OpenPanel(UIName.LingShouBaoGeTenResultPanel, drop,type,activityId)
        end
        
    else--灵兽山抽卡
        if type == RecruitType.LingShowSingle then
            UIManager.OpenPanel(UIName.PokemonSummonOneResultPanel, drop,type)
        else
            UIManager.OpenPanel(UIName.PokemonSummonTenResultPanel, drop,type)
        end
    end

    _heroTable={}
    drop = {}
    NetManager.DiffMonsterRequest()
end

function PokemonSingleResultPanel:OnDestroy()

end

return PokemonSingleResultPanel