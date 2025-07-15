----- 远征怪节点弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local fun
--item容器
local itemList = {}
local heroListGo = {}
local monsterData = {}
local rewardData = {}
local type = 1 --1 前往 2 放弃
local liveNodes = {}
local liveNames = {}
local curNodeConFig
local roleConfig=ConfigManager.GetConfig(ConfigName.RoleConfig)
function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.power = Util.GetGameObject(gameObject, "Power/Value"):GetComponent("Text")
    this.sureBtn=Util.GetGameObject(gameObject,"sureBtn")
    this.sureBtnText=Util.GetGameObject(gameObject,"sureBtn/Text"):GetComponent("Text")
    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root")
    for i = 1, 6 do
        heroListGo[i] = Util.GetGameObject(gameObject, "RoleGrid/Bg"..i.."/Hero"..i)
    end
    this.backBtn=Util.GetGameObject(gameObject,"BackBtn")
end

function this:BindEvent()
    Util.AddClick(this.sureBtn, function()
        this:BtnClickEvent()
    end)
    Util.AddClick(this.backBtn, function()
        parent:ClosePanel()
    end)
end
function this:BtnClickEvent()
    if type == 1 then
        parent:ClosePanel()
    elseif type == 2 then
        parent:ClosePanel()
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.EXPEDITION, monsterData)
    end
end

function this:AddListener()
end

function this:RemoveListener()
end
function this:OnShow(_parent,...)
    parent=_parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local args = {...}
    monsterData = args[1]
    type = args[2]
    fun = args[3]

    --组数据
    rewardData = {}
    local curRewardData = {}
    --curNodeConFig = ConfigManager.TryGetConfigData(ConfigName.ExpeditionNodeConfig,monsterData.type)
    curNodeConFig = ConfigManager.TryGetConfigData(ConfigName.ExpeditionNodeConfig,monsterData.type)
    local  Reward = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.ExpeditionFloorConfig,"Floor",ExpeditionManager.expeditionLeve,"FloorLay",monsterData.lay - 1)
    if Reward and Reward.Reward and  #Reward.Reward > 0 then
        for i = 1, #Reward.Reward do
            local rewardGroupConfig = ConfigManager.TryGetConfigData(ConfigName.RewardGroup,Reward.Reward[i])
            if rewardGroupConfig and #rewardGroupConfig.ShowItem > 0 then
                for j = 1, #rewardGroupConfig.ShowItem do
                    local v = rewardGroupConfig.ShowItem[j]
                    if curRewardData[v[1]] then
                        curRewardData[v[1]] = {v[1],curRewardData[v[1]][2] + v[2]}
                    else
                        curRewardData[v[1]] = {v[1],v[2]}
                    end
                end
            end
        end
    end
    for i, v in pairs(curRewardData) do
        if curNodeConFig and curNodeConFig.Reward and curNodeConFig.Reward > 0 then
            v =  {v[1],math.floor(v[2] * curNodeConFig.Reward)}
        end
        table.insert(rewardData,v)
    end
    this:FormationAdapter()
end
-- 编队数据匹配
function this:FormationAdapter()
    if type == 1 then
        this.sureBtnText.text = GetLanguageStrById(10508)
    elseif type == 2 then
        this.sureBtnText.text = GetLanguageStrById(10512)
    end
    
    if curNodeConFig then
        
        if curNodeConFig.type == ExpeditionNodeType.Common then
            this.titleText.text=GetLanguageStrById(10513)
        elseif curNodeConFig.type == ExpeditionNodeType.Jy then
            this.titleText.text=GetLanguageStrById(10514)
        elseif curNodeConFig.type == ExpeditionNodeType.Boss then
            this.titleText.text=GetLanguageStrById(10515)
        end
    end
    if monsterData == nil then LogError(GetLanguageStrById(10511)) return end
    this.power.text = monsterData.bossTeaminfo.totalForce

    for i = 1, #heroListGo do
        if(monsterData.bossTeaminfo.hero[i]) then
            if monsterData.bossTeaminfo.hero[i].remainHp > 0 then
                this.SetCardSingleData(heroListGo[i],monsterData.bossTeaminfo.hero[i],i)
                heroListGo[i]:SetActive(true)
            else
                heroListGo[i]:SetActive(false)
            end
        else
            heroListGo[i]:SetActive(false)
        end
    end
    FindFairyManager.ResetItemView(this.root,this.root.transform,itemList,5,1,sortingOrder,false,rewardData)
end

function this.OnSortingOrderChange()
    for i = 1, #heroListGo do
        Util.AddParticleSortLayer(heroListGo[i], self.sortingOrder - sortingOrder)
    end
    sortingOrder = self.sortingOrder
end

--设置单个上阵英雄信息
function this.SetCardSingleData(o,monsterId, _pos)
    o.transform.parent:GetComponent("Image").sprite=Util.LoadSprite("t_biandui.xuanzhongkuang")
    local heroConfig  = ConfigManager.GetConfigData(ConfigName.HeroConfig, monsterId.heroTid)
    local bg=Util.GetGameObject(o,"Bg1"):GetComponent("Image")
    local fg=Util.GetGameObject(o,"Bg2"):GetComponent("Image")
    -- local live=Util.GetGameObject(o,"Mask/Live")
    local lv=Util.GetGameObject(o,"lv/Text"):GetComponent("Text")
    local pro=Util.GetGameObject(o,"Pro/Image"):GetComponent("Image")
    local starGrid=Util.GetGameObject(o,"StarGrid")
    local name=Util.GetGameObject(o,"Name/Text"):GetComponent("Text")
    -- local pos=Util.GetGameObject(o,"Pos"):GetComponent("Image")
    local yuanImage=Util.GetGameObject(o,"yuanImage")
    local hp = Util.GetGameObject(o,"hpProgress/hp"):GetComponent("Image")
    local hpPass = Util.GetGameObject(o,"hpProgress/hpPass"):GetComponent("Image")
    local rage = Util.GetGameObject(o,"rageProgress/rage"):GetComponent("Image")

    local live = Util.GetGameObject(o, "Mask/icon"):GetComponent("RawImage")
    local liveName = GetResourcePath(heroConfig.Live)
    local roleConfig = ConfigManager.GetConfigData(ConfigName.RoleConfig, heroConfig.Id)
    local scale = roleConfig.play_liveScale
    local livePos = Vector3.New(roleConfig.offset[1], roleConfig.offset[2], 0)
    live.texture = CardRendererManager.GetSpineTexture(_pos, liveName, Vector3.one * scale, livePos, true)
    live.transform.localScale = Vector3.one
    live.transform.localPosition = Vector3.zero

    local zs = Util.GetGameObject(o, "zs")
    local zsName = GetHeroCardStarZs[heroConfig.Star]
    if zsName == "" then
        zs:SetActive(false)
    else
        zs:SetActive(true)
        zs:GetComponent("Image").sprite = Util.LoadSprite(zsName)
    end

    yuanImage:SetActive(false)
    lv.text=monsterId.level

    bg.sprite = Util.LoadSprite(GetFormationHeroCardStarBg[heroConfig.Star])
    fg.sprite = Util.LoadSprite(GetHeroCardStarFg[heroConfig.Star])

    pro.sprite=Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
    SetCardStars(starGrid,heroConfig.Star)
    if heroConfig.Star > 9 then
        Util.GetGameObject(o,"UI_Effect_jinkuang_KaPai").gameObject:SetActive(true)
    else
        Util.GetGameObject(o,"UI_Effect_jinkuang_KaPai").gameObject:SetActive(false)
    end
    name.text=GetLanguageStrById(heroConfig.ReadingName)


    local curHeroHpVal = monsterId.remainHp
    hp.fillAmount = curHeroHpVal
    hpPass.fillAmount = curHeroHpVal
    rage.fillAmount = 0.5
end
function this:OnClose()
    if fun then
        fun()
        fun = nil
    end
    for i, v in pairs(liveNodes) do
        if v then
            poolManager:UnLoadLive(liveNames[i],v)
            liveNames[i]= nil
        end
    end
end

function this:OnDestroy()
end

return this