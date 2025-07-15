require("Base/BasePanel")
AlameinWarPanel = Inherit(BasePanel)
local this = AlameinWarPanel

--初始化组件（用于子类重写）
function AlameinWarPanel:InitComponent()
    this.HeadFrameView =SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    -- this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)

    this.backBtn = Util.GetGameObject(self.gameObject, "Root/Bottom/backBtn")
    this.Btn_Atlas = Util.GetGameObject(self.gameObject, "Root/Bottom/Btn_Atlas")
    this.Btn_Shop = Util.GetGameObject(self.gameObject, "Root/Bottom/Btn_Shop")
    this.Btn_Ruins = Util.GetGameObject(self.gameObject, "Root/Bottom/Btn_Ruins")
    this.Btn_Rank = Util.GetGameObject(self.gameObject, "Root/Bottom/Btn_Rank")
    this.Button = Util.GetGameObject(self.gameObject, "Root/Bottom/Times/Button")
    this.ChallengeTimes = Util.GetGameObject(self.gameObject, "Root/Bottom/Times/ChallengeTimes")
    this.LastBuyTimes = Util.GetGameObject(self.gameObject, "Root/Bottom/Times/LastBuyTimes")

    this.Scroll = Util.GetGameObject(self.gameObject, "Root/Scroll")
    this.ChapterPre = Util.GetGameObject(self.gameObject, "Root/ChapterPre")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.ChapterPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(12, 0))
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
    this.scrollView.transform:GetComponent("RectMask2D").enabled = false

end

--绑定事件（用于子类重写）
function AlameinWarPanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.Btn_Atlas, function()
        UIManager.OpenPanel(UIName.MedalAtlasPopup)
    end)
    Util.AddClick(this.Btn_Shop, function()
        ShopManager.GetMainShopPageList(1)
        local isActive, errorTip = ShopManager.IsPageActive(15)
        if not isActive then
            PopupTipPanel.ShowTip(errorTip)
            return
        end
        UIManager.OpenPanel(UIName.MainShopPanel,67)
    end)
    Util.AddClick(this.Btn_Ruins, function()
        UIManager.OpenPanel(UIName.ReconnaissancePanel)
    end)
    Util.AddClick(this.Btn_Rank, function()
        UIManager.OpenPanel(UIName.RankingSingleListPanel,RankKingList[8])
    end)
    Util.AddClick(this.Button, function()
        AlameinWarManager.BuyTimesBtn()
    end)

    BindRedPointObject(RedPointType.Culturalrelics, Util.GetGameObject(this.Btn_Ruins,"Redpot"))
end

--添加事件监听（用于子类重写）
function AlameinWarPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.AlameinWar.RefreshTimes, this.RefreshTimes, this)
end

--移除事件监听（用于子类重写）
function AlameinWarPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.AlameinWar.RefreshTimes, this.RefreshTimes, this)
end

--界面打开时调用（用于子类重写）
function AlameinWarPanel:OnOpen()
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AlameinWarPanel:OnShow()
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.AlameinWarPanel })
    -- this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.AlameinWarPanel })

    local adjutantArchiveData = AdjutantManager.GetAllAdjutantArchiveData()
    this.data = AlameinWarManager.chapters

    this.scrollView:SetData(this.data, function(index, root)
        this.SetChapterUI(root, this.data[index], index)
    end)
    this.scrollView:SetIndex(1)

    this:RefreshTimes()

    CheckRedPointStatus(RedPointType.Culturalrelics)
end

function AlameinWarPanel.SetChapterUI(root, data, index)
    root:SetActive(true)
    local FinishSign = Util.GetGameObject(root, "FinishSign")
    local Perfect = Util.GetGameObject(root, "FinishSign/Perfect")
    local Pass = Util.GetGameObject(root, "FinishSign/Pass")
    local Chapter = Util.GetGameObject(root, "Chapter"):GetComponent("Text")
    local starNum = Util.GetGameObject(root, "star/Text"):GetComponent("Text")

    Chapter.text = string.format("%03d",index)

    local box = Util.GetGameObject(root, "box")

    local totalStars = AlameinWarManager.GetChapterStars(index)
    starNum.text = totalStars .. "/30"

    if data[#data].cfgId < AlameinWarManager.curFightCfgId then
        local isPerfect = true
        for i = 1, #data do
            if #data[i].finishedStarIds < 3 then
                isPerfect = false
            end
        end
        FinishSign:SetActive(true)
        Perfect:SetActive(isPerfect)
        Pass:SetActive(not isPerfect)
    else
        FinishSign:SetActive(false)
    end
    
    Util.AddOnceClick(root, function()
        UIManager.OpenPanel(UIName.AlameinWarStagePanel, index)
    end)

    Util.AddOnceClick(box, function()
        UIManager.OpenPanel(UIName.AlameinWarRewardPopup, index)
    end)
end

function AlameinWarPanel:RefreshTimes()
    local upLimit = PrivilegeManager.GetPrivilegeNumber(40002)
    this.ChallengeTimes:GetComponent("Text").text = AlameinWarManager.challengeTimes .. "/" .. upLimit
    this.LastBuyTimes:GetComponent("Text").text = AlameinWarManager.residueBuyTimes
end

--界面关闭时调用（用于子类重写）
function AlameinWarPanel:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function AlameinWarPanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    -- SubUIManager.Close(this.BtView)

    ClearRedPointObject(RedPointType.Culturalrelics)
end

return AlameinWarPanel