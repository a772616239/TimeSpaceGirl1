
local canDrag = true
local i = 1
local this = {}
local orginLayer
local AllActSetConfig = ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local itemId = 20 --元素神符
local integralId = 74--积分
local isManyTimes = false

local cardState = {
    [1] = {
        bg = {
            [1] = "cn2-X1_julebu_tishudiban",
            [2] = "cn2-X1_julebu_yinengdiban",
            [3] = "cn2-X1_julebu_jixiediban",
            [4] = "cn2-X1_julebu_guangminghundundiban"
        },
        color = Color.New(255,255,255,153),
        outline = false,
        pos = Vector3.zero,
        sizeDelta = Vector2.New(269,261)
    },
    [2] = {
        bg = "cn2-X1_julebu_xuanzhong" , 
        color = Color.New(255,255,255,255),
        outline = true,
        pos = Vector3.New(-2,10),
        sizeDelta = Vector2.New(268,280)
    }
}
local btnList = {}

--初始化组件（用于子类重写）
function this:InitComponent(gameObject)
    orginLayer = 0
    this.gameObject = gameObject
    this.Mask = Util.GetGameObject(gameObject,"ElementDrawCardPanel/Mask");
    this.choukaUI_julebu = Util.GetGameObject(gameObject,"ElementDrawCardPanel/choukaUI_julebu"):GetComponent("Animator")
    this.UICanvas = Util.GetGameObject(gameObject,"ElementDrawCardPanel/choukaUI_julebu/Image (3)/Image (6)"):GetComponent("Canvas")

    for i = 1, 4 do
        local btn = Util.GetGameObject(gameObject, "ElementDrawCardPanel/enterCardPanel/btn"..i)
        table.insert(btnList, btn)
    end

    this.previewBtn = Util.GetGameObject(gameObject, "ElementDrawCardPanel/previewBtn")--奖池概率
    this.shopBtn = Util.GetGameObject(gameObject, "ElementDrawCardPanel/shopBtn")--商店
    this.helpBtn = Util.GetGameObject(gameObject, "ElementDrawCardPanel/helpBtn")--帮助

    this.camp = 1

    this.btnRecruit = Util.GetGameObject(gameObject, "ElementDrawCardPanel/btnRecruit")--招募
    this.btnManyTimes = Util.GetGameObject(gameObject,"ElementDrawCardPanel/btnManyTimes")--多次招募
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(this.btnRecruit,function ()
        local type
        if isManyTimes then
            if this.camp == 1 then type = RecruitType.FireTen 
            elseif this.camp == 2 then type = RecruitType.WindyTen
            elseif this.camp == 3 then type = RecruitType.WaterTen
            elseif this.camp == 4 then type = RecruitType.GroundTen
            end
        else
            if this.camp == 1 then type = RecruitType.FireSingle
            elseif this.camp == 2 then type = RecruitType.WindySingle
            elseif this.camp == 3 then type = RecruitType.WaterSingle
            elseif this.camp == 4 then type = RecruitType.GroundSingle
            end
        end

        if BagManager.GetItemCountById(itemId) < lotterySetting[type].CostItem[1][2] then
            PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[itemId].Name)..GetLanguageStrById(10492))
            return
        end

        this.PlayAnim(function()
            RecruitManager.RecruitRequest(type, function(msg)
                if isManyTimes then
                    UIManager.OpenPanel(UIName.SecretBoxBuyTenPanel, msg.drop, type)
                else
                    UIManager.OpenPanel(UIName.SecretBoxBuyOnePanel, msg.drop, type)
                end
                Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
            end)
        end)
    end)

    Util.AddOnceClick(this.previewBtn,function()
        UIManager.OpenPanel(UIName.HeroPreviewPanel, 2, false)
    end)

    for i = 1, #btnList do
        Util.AddClick(btnList[i], function ()
            PlayerPrefs.SetInt(PlayerManager.uid.."ElementDrawPos", i)
            this.camp = i
            this.CardClicked()
        end)
    end

    Util.AddClick(this.btnManyTimes, function ()
        isManyTimes = not isManyTimes
        this:SetBtn()
    end)

    Util.AddClick(this.shopBtn, function()
        JumpManager.GoJump(20008)
    end)
    Util.AddClick(this.helpBtn, function()
        local pos = this.helpBtn.transform.localPosition
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.ElementDraw, pos.x, pos.y)
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.SecretBox.OnOpenOneReward, this.OpenOneRewardPanel)
    Game.GlobalEvent:AddEvent(GameEvent.SecretBox.OnOpenTenReward, this.OpenTenRewardPanel)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.SecretBox.OnOpenOneReward,this.OpenOneRewardPanel)
    Game.GlobalEvent:RemoveEvent(GameEvent.SecretBox.OnOpenTenReward,this.OpenTenRewardPanel)
end

function this:OnSortingOrderChange(_sortingOrder)
    this.sortingOrder = _sortingOrder
    Util.AddParticleSortLayer(this.gameObject, this.sortingOrder)
    this.UICanvas.sortingOrder = this.sortingOrder + 5
end

--界面打开时调用（用于子类重写）
function this:OnOpen(...)
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow(...)
    this.camp = PlayerPrefs.GetInt(PlayerManager.uid.."ElementDrawPos")
    if this.camp == 0 then this.camp = 1 end
    this.CardClicked()
    this:SetBtn()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    btnList = {}
end

function this:OpenOneRewardPanel(drop)
    UIManager.OpenPanel(UIName.SecretBoxBuyOnePanel,drop)
end

function this:OpenTenRewardPanel(drop)
    UIManager.OpenPanel(UIName.SecretBoxBuyTenPanel,drop)
end

function this.PlayAnim(backAction)
    this.Mask:SetActive(true)
    this.choukaUI_julebu:SetBool("play",true)
    Timer.New(function()
        if backAction then
            backAction()
        end
    end,1.5):Start()
    Timer.New(function()
        this.choukaUI_julebu:SetBool("play",false)
        this.Mask:SetActive(false)
    end,2):Start()

end

function this:SetBtn()
    if isManyTimes then
        Util.GetGameObject(this.btnManyTimes, "Image"):SetActive(true)
        Util.GetGameObject(this.btnRecruit, "drawNum"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_anniuziyuandi_shici")
    else
        Util.GetGameObject(this.btnManyTimes, "Image"):SetActive(false)
        Util.GetGameObject(this.btnRecruit, "drawNum"):GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_anniuziyuandi")
    end
end

function this.CardClicked()
    for i = 1, #btnList do
        local bg = Util.GetGameObject(btnList[i], "bg")
        local text = Util.GetGameObject(btnList[i], "Text")
        bg:GetComponent("Image").sprite = Util.LoadSprite(cardState[1].bg[i])
        bg:GetComponent("RectTransform").sizeDelta = cardState[1].sizeDelta
        bg:GetComponent("RectTransform").localPosition = cardState[1].pos
        text:GetComponent("Text").color = cardState[1].color
        text:GetComponent("Outline").enabled = cardState[1].outline
    end
    Util.GetGameObject(btnList[this.camp], "bg"):GetComponent("Image").sprite = Util.LoadSprite(cardState[2].bg)
    Util.GetGameObject(btnList[this.camp], "bg"):GetComponent("RectTransform").sizeDelta = cardState[2].sizeDelta
    Util.GetGameObject(btnList[this.camp], "bg"):GetComponent("RectTransform").localPosition = cardState[2].pos
    Util.GetGameObject(btnList[this.camp], "Text"):GetComponent("Text").color = cardState[2].color
    Util.GetGameObject(btnList[this.camp], "Text"):GetComponent("Outline").enabled = cardState[2].outline
end

return this