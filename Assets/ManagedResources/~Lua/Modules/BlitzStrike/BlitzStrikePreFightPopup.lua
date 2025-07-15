require("Base/BasePanel")
BlitzStrikePreFightPopup = Inherit(BasePanel)
local this = BlitzStrikePreFightPopup

local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local BlitzConfig = ConfigManager.GetConfig(ConfigName.BlitzConfig)

--初始化组件（用于子类重写）
function BlitzStrikePreFightPopup:InitComponent()
    this.mask = Util.GetGameObject(self.gameObject, "mask")
    this.btnBack = Util.GetGameObject(self.gameObject, "Bg/btnBack")
    this.btnFight = Util.GetGameObject(self.gameObject, "Bg/btnFight/btn")

    this.headBox = Util.GetGameObject(self.gameObject, "Bg/headBox")

    this.Scroll = Util.GetGameObject(self.gameObject, "Bg/Formation/Scroll")
    this.tankPre = Util.GetGameObject(self.gameObject, "Bg/item2")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.tankPre, nil,
            Vector2.New(w, h), 2, 1, Vector2.New(0, 0))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
    this.scrollView.elastic = false

    this.itemList = {}

    this.RewardGrid = Util.GetGameObject(self.gameObject, "Bg/RewardTotal/Grid/RewardGrid")
    this.title = Util.GetGameObject(self.gameObject, "Bg/bg/title"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function BlitzStrikePreFightPopup:BindEvent()
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnFight, function()
        NetManager.GetBlitzAllTankInfo(function(msg)    --< 拉剩余血量数据
            --LogError("-get  blood BLITZ_STRIKE")    
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.BLITZ_STRIKE, this.curfightId)          
            end)         
    end)
end

--添加事件监听（用于子类重写）
function BlitzStrikePreFightPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function BlitzStrikePreFightPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function BlitzStrikePreFightPopup:OnOpen(...)
    this.args = {...}
    this.curfightId = this.args[1]
    this.stage = this.args[2]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BlitzStrikePreFightPopup:OnShow()
    this:SetTanks()
    this:SetHeadBox(BlitzStrikeManager.StageData)

    local BlitzConfig = BlitzConfig[this.curfightId]
    this:RewardCommon(1, this.RewardGrid, BlitzConfig.LevelsAwards)

    this.title.text = string.format(GetLanguageStrById(10484), this.stage)
end

function BlitzStrikePreFightPopup:SetHeadBox(data)
    local headpos = Util.GetGameObject(this.headBox, "headpos")
    local name = Util.GetGameObject(this.headBox, "name"):GetComponent("Text")
    local lv = Util.GetGameObject(this.headBox, "lvFrame/lv"):GetComponent("Text")
    local power = Util.GetGameObject(this.headBox, "power"):GetComponent("Text")

    name.text = data.name
    lv.text = data.level or 1   --< todo 人机时后端不传
    power.text = string.format(GetLanguageStrById(10335), data.team.totalForce)

    if not this.playerHead then
        this.playerHead = {}
    end
    if not this.playerHead[1] then
        this.playerHead[1] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    if data.head then
        this.playerHead[1]:SetHead(data.head)
    else
        this.playerHead[1]:SetHead(71000)   --< todo 人机时后端不传
    end
    if data.headFrame then
        this.playerHead[1]:SetFrame(data.headFrame)
    else
        this.playerHead[1]:SetFrame(80000)  --< todo 人机时后端不传
    end
end

function BlitzStrikePreFightPopup:SetTanks()
    local data = BlitzStrikeManager.StageData.team.team
    this.scrollView:SetData(data, function(index, root)
        self:SetSingleTank(root, data[index])
    end)
end

function BlitzStrikePreFightPopup:SetSingleTank(go, data)
    local go=go
    local Text_Name =  Util.GetGameObject(go, "Text_Name"):GetComponent("Text")
    local frame=Util.GetGameObject(go,"frame"):GetComponent("Image")
    local icon=Util.GetGameObject(go, "icon"):GetComponent("Image")
    local lv= Util.GetGameObject(go, "lv/Text")
    local pro= Util.GetGameObject(go, "proIcon"):GetComponent("Image")
    local starGrid = Util.GetGameObject(go, "star")
    local Slider = Util.GetGameObject(go, "Slider")
    local Text = Util.GetGameObject(go, "Slider/Text")
    Text:SetActive(false)
    local heroConfig = HeroConfig[data.heroTid]
    Text_Name.text = GetLanguageStrById(heroConfig.ReadingName)
    frame.sprite=Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig.Quality, data.star))
    icon.sprite=Util.LoadSprite(GetResourcePath(heroConfig.Icon))
    lv:GetComponent("Text").text = data.level
    pro.sprite= Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
    SetHeroStars(starGrid, data.star)
    Slider:GetComponent("Slider").value = data.remainHp
end

function BlitzStrikePreFightPopup:RewardCommon(listId, rewardGo, rewardConfig)
    if this.itemList[listId] == nil then
        this.itemList[listId] = {}
        for i = 1, 4 do     --< 目前最多支持四个item
            this.itemList[listId][i] = SubUIManager.Open(SubUIConfig.ItemView, rewardGo.transform)
        end
    end
    
    local itemData = rewardConfig
    for i = 1, 4 do
        local ItemView = this.itemList[listId][i]
        if i <= #itemData then
            ItemView.gameObject:SetActive(true)
            ItemView:OnOpen(false, {itemData[i][1], itemData[i][2]}, 0.9, nil, nil, nil, nil, nil)
        else
            ItemView.gameObject:SetActive(false)
        end
    end
end

--界面关闭时调用（用于子类重写）
function BlitzStrikePreFightPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function BlitzStrikePreFightPopup:OnDestroy()
    if this.playerHead then
        for _, v in pairs(this.playerHead) do
            v:Recycle()
        end
        this.playerHead = {}
    end

    this.itemList = {}
end

return BlitzStrikePreFightPopup