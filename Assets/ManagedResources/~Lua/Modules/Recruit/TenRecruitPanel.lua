require("Base/BasePanel")
TenRecruitPanel = Inherit(BasePanel)
local this = TenRecruitPanel
local cardList = {}
local cardNameList = {}
local cardEffectList = {}
local orginLayer
-- local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local privilegeConfig = ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local drawType --抽卡类型
local roleDatas = {}
local maxTimesId--特权id上限（今日召唤上限）
local isJump --是否跳过动画
local isAnimJump --千抽跳过动画

--初始化组件（用于子类重写）
function TenRecruitPanel:InitComponent()
    orginLayer = 0

    self.effect = Util.GetGameObject(self.gameObject, "choukaUI_jiesuan")
    this.UICanvas = Util.GetGameObject(self.gameObject,"UI"):GetComponent("Canvas")
    this.sureBtn = Util.GetGameObject(self.gameObject, "UI/bottom/sureBtn")
    this.againBtn = Util.GetGameObject(self.gameObject, "UI/bottom/againBtn")
    this.againIcon = Util.GetGameObject(self.gameObject,"UI/bottom/againBtn/Tip/juan"):GetComponent("Image")
    this.againNum = Util.GetGameObject(self.gameObject,"UI/bottom/againBtn/Tip/Text"):GetComponent("Text")
    this.grid = Util.GetGameObject(self.gameObject, "UI/grid")
    this.card = poolManager:LoadAsset("card", PoolManager.AssetType.GameObject) 
    this.card:SetActive(false)
    this.Mask = Util.GetGameObject(self.gameObject, "UI/Mask")
    for i = 1,this.grid.transform.childCount do
        local goParent = this.grid.transform:GetChild(i-1).gameObject
        local go = newObject(this.card)
        go.transform:SetParent(Util.GetGameObject(goParent,"CardPos").transform)
        go.transform.localScale = Vector3.one * 0.95
        go.transform.localPosition = Vector3.zero
        --go:SetActive(true)
        cardList[i] = go
        cardNameList[i] = Util.GetGameObject(goParent,"Name")
        cardEffectList[i] = Util.GetGameObject(goParent,"cardEffect")
    end
end

--绑定事件（用于子类重写）
function TenRecruitPanel:BindEvent()
    Util.AddClick(this.sureBtn, function()
        -- UIManager.OpenPanel(UIName.RecruitPanel)
        self:ClosePanel()
    end)
    Util.AddClick(this.againBtn, function()
        local d = RecruitManager.GetExpendData(drawType)
        if BagManager.GetItemCountById(d[1]) < d[2] then
            PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[d[1]].Name)..GetLanguageStrById(10492))
            return
        end
        if PrivilegeManager.GetPrivilegeUsedTimes(maxTimesId)+1 > privilegeConfig[maxTimesId].Condition[1][2] then
            PopupTipPanel.ShowTipByLanguageId(11760)
            return
        end
        RecruitManager.RecruitRequest(drawType, function(msg)
            PrivilegeManager.RefreshPrivilegeUsedTimes(maxTimesId,10)--记录抽卡次数
            local heros = RecruitManager.RandomHerosSort(msg.drop.Hero)--随机排序
            if isJump then
                UIManager.OpenPanel(UIName.TenRecruitPanel, heros, drawType, isJump)
            else
                UIManager.OpenPanel(UIName.SingleRecruitPanel, heros, drawType, 2)
            end
        end,maxTimesId)
    end)
end

--添加事件监听（用于子类重写）
function TenRecruitPanel:AddListener()
end

--移除事件监听（用于子类重写）
function TenRecruitPanel:RemoveListener()
end

function TenRecruitPanel:OnSortingOrderChange()
    -- Util.AddParticleSortLayer(self.effect, self.sortingOrder - orginLayer)
    -- for i = 1,  this.grid.transform.childCount do
    --     Util.AddParticleSortLayer(this.grid.transform:GetChild(i-1).gameObject, self.sortingOrder - orginLayer)
    -- end

    Util.AddParticleSortLayer(self.effect, self.sortingOrder - orginLayer)

    this.UICanvas.sortingOrder = self.sortingOrder + 5

    for i = 1, #cardEffectList do
        Util.AddParticleSortLayer(cardEffectList[i], self.sortingOrder + 5)
    end
    orginLayer = self.sortingOrder
end

--界面打开时调用（用于子类重写）
function TenRecruitPanel:OnOpen(...)
    local data = { ... }
    roleDatas = data[1]
    if data[2] == nil then
        -- 千抽
        this.againBtn:SetActive(false)
        isAnimJump = data[4]
    else
        this.againBtn:SetActive(true)
        drawType = data[2]
        isJump = data[3]
        local d = RecruitManager.GetExpendData(drawType)
        this.againIcon.sprite = Util.LoadSprite(artResourcesConfig[itemConfig[d[1]].ResourceID].Name)
        this.againNum.text = "×"..d[2]
        maxTimesId = lotterySetting[drawType].MaxTimes --特权上限ID
    end

    for i = 1, #cardList do
        cardList[i]:SetActive(false)
        cardNameList[i]:SetActive(false)
        cardEffectList[i]:SetActive(false)
    end

    if isAnimJump then
        for i = 1, #roleDatas do
            this:ShowData(i)
        end
    else
        this.Mask:SetActive(true)
        AnimPlay(1)
    end
end

--界面关闭时调用（用于子类重写）
function TenRecruitPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function TenRecruitPanel:OnDestroy()
end

function AnimPlay(index)
    if index > #roleDatas then
        --完成
        this.Mask:SetActive(false)
    else
        this:ShowData(index)
        Timer.New(function()
            AnimPlay(index + 1)
        end,0.2):Start()
    end
end

function TenRecruitPanel:ShowData(index)
    local cardGo = cardList[index]
    local nameGo = cardNameList[index] 
    local effectGo = cardEffectList[index]
    local data = roleDatas[index]

    local heroConfig
    if type(data) == "number" then
        heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, data)
    elseif type(data) == "table" then
        heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, data.heroId)
    end

    --特效
    effectGo:SetActive(true)
    for i = 1, effectGo.transform.childCount do
        effectGo.transform:GetChild(i-1).gameObject:SetActive(i == heroConfig.Quality)
    end

    --音效
    if heroConfig.Quality < 4 then
        SoundManager.PlaySound(SoundConfig.Sound_Recruit_GetHero_1)    
    elseif heroConfig.Quality > 4 then
        SoundManager.PlaySound(SoundConfig.Sound_Recruit_GetHero_3)    
    else
        SoundManager.PlaySound(SoundConfig.Sound_Recruit_GetHero_2)    
    end

    --名字
    nameGo:SetActive(true)
    nameGo:GetComponent("Text").text = GetLanguageStrById(heroConfig.ReadingName)

    --卡牌
    cardGo:SetActive(true)
    SetHeroBg(Util.GetGameObject(cardGo.transform, "card/bg"), Util.GetGameObject(cardGo.transform, "card/frame"), heroConfig.Quality, heroConfig.Star)
    --local heroMaxConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroRankupConfig, "Star", heroConfig.Star, "OpenStar", data.star)
    Util.GetGameObject(cardGo.transform, "card/lv"):GetComponent("Text").text = 1 --heroMaxConfig.OpenLevel
    -- Util.GetGameObject(cardGo.transform, "card/name"):GetComponent("Text").text = GetLanguageStrById(heroConfig.ReadingName)
    Util.GetGameObject(cardGo.transform, "card/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Painting))
    Util.GetGameObject(cardGo.transform, "card/pro/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
    Util.GetGameObject(cardGo.transform, "card/bg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityBgImageByquality(heroConfig.Quality, heroConfig.Star))
    SetHeroStars(Util.GetGameObject(cardGo.transform, "star"), heroConfig.Star)
    Util.GetGameObject(cardGo.transform, "card/sign/core"):SetActive(heroConfig.HeroValue == 1)
    -- Util.AddOnceClick(Util.GetGameObject(go.transform, "card"), function()
    --     UIManager.OpenPanel(UIName.HandBookHeroInfoPanel,data,proId)
    -- end)
    -- if PlayerManager.heroHandBook and PlayerManager.heroHandBook[data.heroConfig.Id] then
    --     Util.SetGray(Util.GetGameObject(go.transform, "card/icon"), false)
    --     Util.SetGray(Util.GetGameObject(go.transform, "card/pro/Image"), false)
    --     Util.GetGameObject(go.transform, "card"):GetComponent("Image").material = nil
    -- else
    --     Util.SetGray(Util.GetGameObject(go.transform, "card/icon"), true)
    --     Util.SetGray(Util.GetGameObject(go.transform, "card/pro/Image"), true)
    --     Util.GetGameObject(go.transform, "card"):GetComponent("Image").material = Util.GetGameObject(go.transform, "card/icon"):GetComponent("Image").material
    -- end
end

return TenRecruitPanel