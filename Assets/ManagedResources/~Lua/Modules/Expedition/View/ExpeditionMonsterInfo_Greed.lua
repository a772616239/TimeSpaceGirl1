----- 远征贪婪节点弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local fun
--item容器
local itemList = {}
local monsterData = {}
local rewardData = {}
local curNodeConFig
local type = 1 --1 前往 2 放弃
function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    this.power = Util.GetGameObject(gameObject, "Power/Value"):GetComponent("Text")
    this.sureBtn=Util.GetGameObject(gameObject,"sureBtn")
    this.sureBtnText=Util.GetGameObject(gameObject,"sureBtn/Text"):GetComponent("Text")
    --滚动条根节点
    this.root = Util.GetGameObject(gameObject, "Root")
    this.backBtn=Util.GetGameObject(gameObject,"BackBtn")
    this.live2dRoot=Util.GetGameObject(gameObject,"live2dRoot")
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
        this.sureBtnText.text = GetLanguageStrById(10509)
    end
    this.titleText.text=GetLanguageStrById(10510)
    if monsterData == nil then LogError(GetLanguageStrById(10511)) return end
    
    this.power.text = monsterData.bossTeaminfo.totalForce
    local monsterCongig = {}
    if monsterData.bossTeaminfo.teamInfo and monsterData.bossTeaminfo.teamInfo > 0 then
        local monsterGroup = ConfigManager.TryGetConfigData(ConfigName.MonsterGroup,monsterData.bossTeaminfo.teamInfo)
        if monsterGroup and monsterGroup.Contents and  #monsterGroup.Contents > 0 then
            if monsterGroup.Contents[1] and  monsterGroup.Contents[1][1] then
                monsterCongig = ConfigManager.TryGetConfigData(ConfigName.MonsterConfig,monsterGroup.Contents[1][1])
            end
        end
        if not monsterCongig then return end
        --if not monsterCongig then LogError("无   monsterCongig") return end
        --monsterData.bossTeaminfo.hero[i].remainHp  monsterCongig.Level
        local demonId = monsterCongig.MonsterId
        local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, demonId)
        this.LiveName = GetResourcePath(heroConfig.Live)
        this.LiveGO = poolManager:LoadLive(this.LiveName, this.live2dRoot.transform,
                Vector3.one * heroConfig.Scale, Vector3.New(heroConfig.Position[1],heroConfig.Position[2],0))
        end
    FindFairyManager.ResetItemView(this.root,this.root.transform,itemList,5,1,sortingOrder,false,rewardData)
end
function this:OnClose()
    if fun then
        fun()
        fun = nil
    end
    poolManager:UnLoadLive(this.LiveName,this.LiveGO )
    this.LiveName= nil
end

function this:OnDestroy()
end

return this