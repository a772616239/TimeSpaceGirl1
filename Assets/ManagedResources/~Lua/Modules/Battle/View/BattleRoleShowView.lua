local RoleShowView = {}
local this = RoleShowView

-- local liveNodes={}--立绘容器
-- local liveNames={}--立绘名容器

-- 初始化节点
function this.Init(root)
    this.gameObject = root
    this.heroNodeList = {}
    for i = 1, 6 do
        this.heroNodeList[i] = Util.GetGameObject(root, string.format("RoleGrid/Bg%s/Hero", i))
    end

end

-- 设置数据
function this.SetData(_fightData)
    this.fightData = _fightData
    for _, node in ipairs(this.heroNodeList) do
        node:SetActive(false)
    end
    for _, data in ipairs(this.fightData.playerData) do
        local pos = data.position
        this.heroNodeList[pos]:SetActive(true)
        this.SetCardSingleData(this.heroNodeList[pos], data, pos)
    end
end

-- 显示
function this.Show(func)
    SoundManager.PlaySound(SoundConfig.Sound_BattleStart_01)
    this.gameObject:SetActive(true)
    local roleGrid = Util.GetGameObject(this.gameObject, "RoleGrid")

    PlayUIAnim(roleGrid)
    Timer.New(function()
        this.gameObject:SetActive(false)
        if func then func() end
    end, 1):Start()
    -- if this.timer then
    --     this.timer:Stop()
    --     this.timer = nil
    -- end
    -- this.timer = Timer.New(function()
    --     this.gameObject:SetActive(false)
    --     if func then func() end
    -- end, 2)
    -- this.timer:Start()
end


--设置单个上阵英雄信息 
function this.SetCardSingleData(o, data, pos)
    -- local live = Util.GetGameObject(o, "Mask/Live")
    local bg=Util.GetGameObject(o,"Bg1"):GetComponent("Image")
    local fg=Util.GetGameObject(o,"Bg2"):GetComponent("Image")
    local lv = Util.GetGameObject(o, "lv/Text"):GetComponent("Text")
    local pro = Util.GetGameObject(o, "Pro/Image"):GetComponent("Image")
    local starGrid = Util.GetGameObject(o, "StarGrid")
    local name = Util.GetGameObject(o, "Name/Text"):GetComponent("Text")
    -- local pos = Util.GetGameObject(o,"Pos"):GetComponent("Image")

    local heroConfig =  ConfigManager.GetConfigData(ConfigName.HeroConfig, data.roleId)
    local roleConfig =  ConfigManager.GetConfigData(ConfigName.RoleConfig, data.roleId)

    local live = Util.GetGameObject(o, "Mask/icon"):GetComponent("RawImage")
    local liveName = GetResourcePath(heroConfig.Live)
    local roleConfig = ConfigManager.GetConfigData(ConfigName.RoleConfig, heroConfig.Id)
    live.texture = CardRendererManager.GetSpineTexture(pos, liveName, Vector3.one * roleConfig.play_liveScale, Vector3.zero, true)
    local liveScale = Vector3.one-- * roleConfig.play_liveScale * 2
    local livePos = Vector2.New(roleConfig.offset[1], roleConfig.offset[2]) 
    live.transform.localScale = liveScale
    live.transform.anchoredPosition = livePos

    local zs = Util.GetGameObject(o, "zs")
    local zsName = GetHeroCardStarZs[data.star]
    if not zsName or zsName == "" then
        zs:SetActive(false)
    else
        zs:SetActive(true)
        zs:GetComponent("Image").sprite = Util.LoadSprite(zsName)
    end

    bg.sprite = Util.LoadSprite(GetBattleHeroCardStarBg[data.star])
    fg.sprite = Util.LoadSprite(GetHeroCardStarFg[data.star])

    -- local heroData = HeroManager.GetSingleHeroData(heroId)/

    lv.text = data.property[1] -- 等级
    pro.sprite = Util.LoadSprite(GetProStrImageByProNum(data.element))
    SetCardStars(starGrid, data.star or 5)
    name.text= GetLanguageStrById(heroConfig.ReadingName)
    -- pos.sprite=Util.LoadSprite("bd_bianhao"..data.position)

    --立绘(这里o只当区别索引用)
    -- if liveNodes[o] then
    --     poolManager:UnLoadLive(liveNames[o],liveNodes[o])
    --     liveNames[o]= nil
    --     liveNodes[o]= nil
    -- end
    -- local artData = ConfigManager.GetConfigData(ConfigName.ArtResourcesConfig, heroConfig.Live)
    -- liveNames[o] = artData.Name
    -- liveNodes[o] = poolManager:LoadLive(liveNames[o], live.transform, Vector3.one * roleConfig.play_liveScale, Vector3.New(roleConfig.offset[1], roleConfig.offset[2], 0))
    -- liveNodes[o]:GetComponent("SkeletonGraphic").raycastTarget=false
end

function this.Recycle()
    -- for o, node in pairs(liveNodes) do
    --     if liveNames[o] and node then
    --         poolManager:UnLoadLive(liveNames[o],liveNodes[o])
    --     end
    -- end
    -- liveNames = {}
    -- liveNodes = {}
end


return this