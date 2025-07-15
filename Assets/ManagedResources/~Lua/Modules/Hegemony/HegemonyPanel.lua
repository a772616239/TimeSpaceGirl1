require("Base/BasePanel")
HegemonyPanel = Inherit(BasePanel)
local this = HegemonyPanel
local SupremacyConfig = ConfigManager.GetConfig(ConfigName.SupremacyConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)

--上一子模块索引
local curIndex = 0
--Title资源名
local heroEndBtns = {}
local showList = {}

local posBaseInfo

function HegemonyPanel:InitComponent()
    showList = {}
    for i = 1, 6 do
        local gameObject=Util.GetGameObject(self.gameObject, "content/show"..i)
        table.insert(showList,gameObject)
    end

    this.condition = Util.GetGameObject(self.gameObject,"condition/Text"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

   --获取帮助按钮
    this.HelpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition
end

function HegemonyPanel:BindEvent()
    --返回按钮
    Util.AddClick(this.btnBack,function()
        self:ClosePanel()
    end)
    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Hegemony,this.helpPosition.x,this.helpPosition.y) 
    end)
end


function HegemonyPanel:OnOpen(...)
    HegemonyManager.isFirstOn = false
end

local rankList = {}
function HegemonyPanel:OnShow()
    NetManager.SupremacyInitRequest(function(msg)
        posBaseInfo = HegemonyManager.GetBaseInfo()

        local player = {}--所有位置占有者uId
        for i = 1, LengthOfTable(posBaseInfo) do
            table.insert(player,posBaseInfo[i].uid)
        end
        for i = 1, LengthOfTable(posBaseInfo) do
            HegemonyPanel:SetData(showList[i],posBaseInfo[i],player)
        end
    end)
end

function HegemonyPanel:AddListener()
end

function HegemonyPanel:RemoveListener()
end

function HegemonyPanel:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end

function HegemonyPanel:OnClose()
end

function HegemonyPanel:OnDestroy()
end


function HegemonyPanel:SetData(gameObject,PosData,players)
    local SupremacyConfigData = SupremacyConfig[PosData.id]
    local title = Util.GetGameObject(gameObject,"title"):GetComponent("Image")
    local icon = Util.GetGameObject(gameObject,"icon")
    -- local null = Util.GetGameObject(gameObject,"null")
    local HeroConfigData = HeroConfig[SupremacyConfigData.BossShow] 
    local name = Util.GetGameObject(gameObject,"nameBg/name"):GetComponent("Text")
    local challengeBtn = Util.GetGameObject(gameObject,"challengeBtn")
    local nameBg = Util.GetGameObject(gameObject,"nameBg")
    local noPlayer = Util.GetGameObject(gameObject,"noPlayer")
    Util.GetGameObject(noPlayer,"name"):GetComponent("Text").text = GetLanguageStrById(12406)

    title.sprite = Util.LoadSprite(SupremacyConfigData.Title)

    if PosData.uid ~= 0 then
        icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(HeroConfigData.Icon))
        --name.text = HeroConfigData.ReadingName
        name.text = PosData.personInfo.name
        nameBg:SetActive(true)
        noPlayer:SetActive(false)
    else
        icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(HeroConfigData.Icon))
        name.text = " "
        nameBg:SetActive(false)
        noPlayer:SetActive(true)
    end

    Util.AddClick(challengeBtn,function()
        --获取自己的竞技场排名和需要名次
        local myRank = HegemonyManager.GetMyRank()
        local needArenaRank = SupremacyConfigData.NeedArenaRank
        --判断是否符合挑战条件
        if myRank <= needArenaRank and myRank > 0 then
           UIManager.OpenPanel(UIName.HegemonyPopup, PosData, players)
        else
           PopupTipPanel.ShowTip(string.format(GetLanguageStrById(23043),needArenaRank))
        end
    end)
end

return HegemonyPanel