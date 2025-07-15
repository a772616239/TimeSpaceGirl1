require("Base/BasePanel")
BlitzStrikePanel = Inherit(BasePanel)
local this = BlitzStrikePanel

local buildingName = {"cn2-x1_yiwangzhicheng_TB_nandu_01", "cn2-x1_yiwangzhicheng_TB_nandu_02", "cn2-x1_yiwangzhicheng_TB_nandu_03"}

local isCanClick = false

local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
--初始化组件（用于子类重写）
function BlitzStrikePanel:InitComponent()
    this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)

    --获取帮助按钮
    this.HelpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition

    this.backBtn = Util.GetGameObject(self.gameObject, "Root/Bottom/backBtn")

    this.StageGo = {}
    for i = 1, BlitzStrikeManager.StageNum do
        this.StageGo[i] = Util.GetGameObject(self.gameObject, "Root/Center/StageRoot/Stage" .. tostring(i))
    end
    this.BoxGo = {}
    for i = 1, BlitzStrikeManager.BoxNum do
        this.BoxGo[i] = Util.GetGameObject(self.gameObject, "Root/Center/StageRoot/Box" .. tostring(i))
    end

    this.Model = {}
    for i = 1, 3 do
        this.Model[i] = Util.GetGameObject(self.gameObject, "Root/Top/TitleMode/Model" .. tostring(i))
        this.Model[i]:SetActive(false)
    end

    this.Btn_Shop = Util.GetGameObject(self.gameObject, "Root/Top/Btn_Shop")
    -- this.Btn_Friend = Util.GetGameObject(self.gameObject, "Root/Top/Btn_Friend")
    this.Btn_Relive = Util.GetGameObject(self.gameObject, "Root/Top/Btn_Relive")

    this.Scroll = Util.GetGameObject(self.gameObject, "Root/Top/TodayGetReward/Scroll")
    this.RewardPre = Util.GetGameObject(self.gameObject, "Root/Top/TodayGetReward/RewardPre")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.RewardPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 0))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function BlitzStrikePanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.Btn_Shop, function()
        UIManager.OpenPanel(UIName.MainShopPanel, SHOP_TYPE.BLITZ_STRIKE)
    end)

    -- Util.AddClick(this.Btn_Friend, function()
    --     UIManager.OpenPanel(UIName.BlitzStrikeSupportPopup)
    -- end)
    -- this.Btn_Friend:SetActive(false)

    Util.AddClick(this.Btn_Relive, function()
        if isCanClick then
            UIManager.OpenPanel(UIName.BlitzStrikeRelivePopup)
        end
    end)

    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.BlitzStrikeDifficultSelect,this.helpPosition.x,this.helpPosition.y+800) 
    end)
end

--添加事件监听（用于子类重写）
function BlitzStrikePanel:AddListener()
end

--移除事件监听（用于子类重写）
function BlitzStrikePanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function BlitzStrikePanel:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BlitzStrikePanel:OnShow()
    this.PlayerHeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.BlitzStrikePanel })

    if BlitzStrikeManager.difficultyLevel == 0 then
        UIManager.OpenPanel(UIName.BlitzStrikeDifficultSelectPopup)
        this.UpdateMainUnSelect()
        isCanClick = true
    else
        NetManager.GetBlitzAllTankInfo(function()
            isCanClick = true
            BlitzStrikeManager.RrefreshFormation()
        end)
        this.UpdateMain()
    end
end

local boxSprite = {
    "cn2-X1_yiwang_jiangli_lan",
    "cn2-X1_yiwang_jiangli_lan_open",
    "cn2-X1_yiwang_jiangli_jin",
    "cn2-X1_yiwang_jiangli_jin_open"
}

function BlitzStrikePanel.UpdateMain()
    this.Model[BlitzStrikeManager.difficultyLevel]:SetActive(true)

    for i = 1, #this.StageGo do
        local Status1 = Util.GetGameObject(this.StageGo[i], "Status/Status1")
        local Status2 = Util.GetGameObject(this.StageGo[i], "Status/Status2")
        local Status3 = Util.GetGameObject(this.StageGo[i], "Status/Status3")
        local Click = Util.GetGameObject(this.StageGo[i], "Click")
        Status1:SetActive(false)
        Status2:SetActive(false)
        Status3:SetActive(false)

        local selectFightId = i + (BlitzStrikeManager.difficultyLevel - 1) * BlitzStrikeManager.StageNum
        if selectFightId < BlitzStrikeManager.curFightId then
            Status3:SetActive(true)
        elseif selectFightId == BlitzStrikeManager.curFightId then
            Status2:SetActive(true)
        else
            Status1:SetActive(true)
        end

        Util.AddOnceClick(Click, function()
            if isCanClick then
                if selectFightId == BlitzStrikeManager.curFightId then
                    NetManager.BlitzLevelInfo(function()
                        UIManager.OpenPanel(UIName.BlitzStrikePreFightPopup, BlitzStrikeManager.curFightId, i)
                    end)
                else
                end
            end
        end)
    end

    local StageConfigDatas = BlitzStrikeManager.GetConfigDataByDiff(BlitzStrikeManager.difficultyLevel)
    local BoxSignIdx = {}
    for i = 1, #StageConfigDatas do
        if StageConfigDatas[i].BoxAwards ~= 0 then
            table.insert(BoxSignIdx, StageConfigDatas[i])
        end
    end
    for i = 1, #this.BoxGo do
        local N = Util.GetGameObject(this.BoxGo[i], "Bg/box/N")
        local O = Util.GetGameObject(this.BoxGo[i], "Bg/box/O")
        local box = Util.GetGameObject(this.BoxGo[i], "Bg/box/box"):GetComponent("Image")
        N:SetActive(false)
        O:SetActive(false)

        if i == 5 then
            box.sprite = Util.LoadSprite(boxSprite[3])
        else
            box.sprite = Util.LoadSprite(boxSprite[1])
        end

        Util.AddOnceClick(N, function()
        end)
        if BlitzStrikeManager.curFightId > BoxSignIdx[i].Id then
            -- finished
            if BlitzStrikeManager.boxAwardedProgress[BoxSignIdx[i].Id] == nil then
                -- can get
                N:SetActive(true)
                Util.AddOnceClick(N, function()
                    NetManager.BlitzGetBoxAward(BoxSignIdx[i].Id, function(msg)
                        NetManager.BlitzTypeInfo(function()
                            if msg.drop then
                                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
                            end
                            this.UpdateMain()
                        end)
                    end)
                end)
            else
                O:SetActive(true)
                if i == 5 then
                    box.sprite = Util.LoadSprite(boxSprite[4])
                else
                    box.sprite = Util.LoadSprite(boxSprite[2])
                end
            end
        else
            N:SetActive(false)
        end
    end

    local data = BlitzStrikeManager.GetRewardTotal()
    this.scrollView:SetData(data, function(index, root)
        this:SetItem(root, data[index])
    end)
end

function BlitzStrikePanel.UpdateMainUnSelect()
    for i = 1, #this.StageGo do
        local Status1 = Util.GetGameObject(this.StageGo[i], "Status/Status1")
        local Status2 = Util.GetGameObject(this.StageGo[i], "Status/Status2")
        local Status3 = Util.GetGameObject(this.StageGo[i], "Status/Status3")
        Status1:SetActive(false)
        Status2:SetActive(false)
        Status3:SetActive(false)
        if i == 1 then
            Status2:SetActive(true)
        else
            Status1:SetActive(true)
        end
    end
end

function BlitzStrikePanel:SetItem(root, data)
    local itemData = ItemConfig[data[1]]
    Util.GetGameObject(root, "Image"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
    Util.GetGameObject(root, "Num"):GetComponent("Text").text = data[2]
end

--界面关闭时调用（用于子类重写）
function BlitzStrikePanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function BlitzStrikePanel:OnDestroy()
    SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.UpView)
end

return BlitzStrikePanel