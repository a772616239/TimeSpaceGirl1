require("Base/BasePanel")
GuildCarDelayFindBossPopup = Inherit(BasePanel)
local this = GuildCarDelayFindBossPopup
local curMonsterId = 0
local heroListGo = {}
local liveNodes = {}
local liveNames = {}
local roleConfig=ConfigManager.GetConfig(ConfigName.RoleConfig)
--初始化组件（用于子类重写）
function GuildCarDelayFindBossPopup:InitComponent()
    this.BackBtn = Util.GetGameObject(self.gameObject, "bg/btnBack")
    for i = 1, 6 do
        heroListGo[i] = Util.GetGameObject(this.gameObject,"RoleGrid/Bg"..i.."/Hero"..i)
    end

end

--绑定事件（用于子类重写）
function GuildCarDelayFindBossPopup:BindEvent()
    Util.AddClick(this.BackBtn, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function GuildCarDelayFindBossPopup:AddListener()
end

--移除事件监听（用于子类重写）
function GuildCarDelayFindBossPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GuildCarDelayFindBossPopup:OnOpen(...)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildCarDelayFindBossPopup:OnShow()
    curMonsterId = GuildCarDelayManager.bossIndexId
    local monsterGroupConfig = ConfigManager.GetConfigData(ConfigName.MonsterGroup,ConfigManager.GetConfigData(ConfigName.WorldBossConfig,curMonsterId).MonsterId)
    if monsterGroupConfig then
        for i = 1, #heroListGo do
            if monsterGroupConfig.Contents[1][i] and monsterGroupConfig.Contents[1][i] ~= 0 then
                this.SetCardSingleData(heroListGo[i],monsterGroupConfig.Contents[1][i],i)
                heroListGo[i]:SetActive(true)
            else
                heroListGo[i]:SetActive(false)
            end
        end
    end
end
--设置单个上阵英雄信息
function this.SetCardSingleData(go,monsterId,_pos)
    local monsterConfig = ConfigManager.GetConfigData(ConfigName.MonsterConfig,monsterId)
    local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig,monsterConfig.MonsterId)

    local bg=Util.GetGameObject(go,"Bg1"):GetComponent("Image")
    local lv=Util.GetGameObject(go,"lv/Text"):GetComponent("Text")
    go.transform.parent:GetComponent("Image").sprite = Util.LoadSprite(GetHeroCardStarBg[1])
    bg.sprite = Util.LoadSprite(GetHeroCardStarBg[heroConfig.Star])
    Util.GetGameObject(go,"hpProgress").gameObject:SetActive(false)
    Util.GetGameObject(go,"rageProgress").gameObject:SetActive(false)
    
    local fg=Util.GetGameObject(go,"Bg2"):GetComponent("Image")
    local pro=Util.GetGameObject(go,"Pro/Image"):GetComponent("Image")
    local starGrid=Util.GetGameObject(go,"StarGrid")
    local name=Util.GetGameObject(go,"Name/Text"):GetComponent("Text")
    local yuanImage=Util.GetGameObject(go,"yuanImage")
    local live = Util.GetGameObject(go, "Mask/icon"):GetComponent("RawImage")
    local liveName = GetResourcePath(heroConfig.Live)
    local roleConfig = ConfigManager.GetConfigData(ConfigName.RoleConfig, heroConfig.Id)
    local scale = roleConfig.play_liveScale
    local livePos = Vector3.New(roleConfig.offset[1], roleConfig.offset[2], 0) 
    live.texture = CardRendererManager.GetSpineTexture(_pos, liveName, Vector3.one * scale, livePos, true) 
    live.transform.localScale = Vector3.one
    live.transform.localPosition = Vector3.zero

    local zs = Util.GetGameObject(go, "zs")
    local zsName = GetHeroCardStarZs[heroConfig.Star]
    if zsName == "" then
        zs:SetActive(false)
    else
        zs:SetActive(true)
        zs:GetComponent("Image").sprite = Util.LoadSprite(zsName)
    end

    yuanImage:SetActive(false)
    lv.text=monsterConfig.Level
   
    fg.sprite = Util.LoadSprite(GetHeroCardStarFg[heroConfig.Star])

    pro.sprite=Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
    SetCardStars(starGrid,heroConfig.Star)
    if heroConfig.Star > 9 then
        Util.GetGameObject(go,"UI_Effect_jinkuang_KaPai").gameObject:SetActive(true)
    else
        Util.GetGameObject(go,"UI_Effect_jinkuang_KaPai").gameObject:SetActive(false)
    end
    name.text=GetLanguageStrById(heroConfig.ReadingName)
end
--界面关闭时调用（用于子类重写）
function GuildCarDelayFindBossPopup:OnClose()
    for i, v in pairs(liveNodes) do
        if v then
            poolManager:UnLoadLive(liveNames[i],v)
            liveNames[i]= nil
        end
    end
end

--界面销毁时调用（用于子类重写）
function GuildCarDelayFindBossPopup:OnDestroy()

end

return GuildCarDelayFindBossPopup