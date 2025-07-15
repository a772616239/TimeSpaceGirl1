require("Base/BasePanel")
DefenseTrainingSupportPopup = Inherit(BasePanel)
local this = DefenseTrainingSupportPopup

local _tabIdx = 1
local TabBox = require("Modules/Common/TabBox") -- 引用

local _TabData = {
    [1] = { default = "cn2-X1_tongyong_anniu_bai", select = "cn2-X1_tongyong_anniu_bai", name = GetLanguageStrById(12560) },
    [2] = { default = "cn2-X1_tongyong_anniu_bai", select = "cn2-X1_tongyong_anniu_bai", name = GetLanguageStrById(12561) },
}

--初始化组件（用于子类重写）
function DefenseTrainingSupportPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "bg/btnClose")

    this.tabBox = Util.GetGameObject(self.gameObject, "bg/TabBox")


    this.ScrollPre = Util.GetGameObject(self.gameObject, "bg/ScrollPre")
    --> 支援我的
    this.Scroll_1 = Util.GetGameObject(self.gameObject, "bg/SupportMine/Scroll")
    local w = this.Scroll_1.transform.rect.width
    local h = this.Scroll_1.transform.rect.height
    this.scrollView_1 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll_1.transform, this.ScrollPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 0))
    this.scrollView_1.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView_1.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView_1.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView_1.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView_1.moveTween.MomentumAmount = 1
    this.scrollView_1.moveTween.Strength = 2

    --> 我的支援
    this.Scroll_2 = Util.GetGameObject(self.gameObject, "bg/MySupport/Scroll")
    this.Scrollbar = Util.GetGameObject(self.gameObject, "bg/MySupport/Scrollbar"):GetComponent("Scrollbar")
    w = this.Scroll_2.transform.rect.width
    h = this.Scroll_2.transform.rect.height
    this.scrollView_2 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll_2.transform, this.ScrollPre, this.Scrollbar,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 0))
    this.scrollView_2.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView_2.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView_2.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView_2.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView_2.moveTween.MomentumAmount = 1
    this.scrollView_2.moveTween.Strength = 2

    this.SupportMine = Util.GetGameObject(self.gameObject, "bg/SupportMine")
    this.MySupport = Util.GetGameObject(self.gameObject, "bg/MySupport")

    this.itemList = {}

    this.AlreadyGo = Util.GetGameObject(self.gameObject, "bg/MySupport/AlreadyGo")
    this.NoGo = Util.GetGameObject(self.gameObject, "bg/MySupport/NoGo")
end

--绑定事件（用于子类重写）
function DefenseTrainingSupportPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function DefenseTrainingSupportPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function DefenseTrainingSupportPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function DefenseTrainingSupportPopup:OnOpen()
    
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DefenseTrainingSupportPopup:OnShow()
    this.tabCtrl = TabBox.New()
    this.tabCtrl:SetTabAdapter(this.OnTabAdapter) 
    this.tabCtrl:SetTabIsLockCheck(this.OnTabIsLockCheck)
    this.tabCtrl:SetChangeTabCallBack(this.OnChangeTab)

    _tabIdx = 1
    this.tabCtrl:Init(this.tabBox, _TabData)
    DefenseTrainingSupportPopup.ChangeTab(_tabIdx)

    this:RefreshScroll_1(1)
    this:RefreshScroll_2(1)
    this:FillShareTankUI()
end

function DefenseTrainingSupportPopup.OnTabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    local image = Util.GetGameObject(tab,"Image"):GetComponent("Image")
    image.sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    if status == "default" then
        image.color = Color.New(161/255,161/255,161/255,1)
    else
        image.color = Color.New(255/255,216/255,6/255,1)
    end
end
function DefenseTrainingSupportPopup.OnTabIsLockCheck(index)
end
function DefenseTrainingSupportPopup.OnChangeTab(index, lastIndex)
    DefenseTrainingSupportPopup.ChangeTab(index, 1)
end

function DefenseTrainingSupportPopup.ChangeTab(index, scrollIndex)
    _tabIdx = index

    this.SupportMine:SetActive(false)
    this.MySupport:SetActive(false)
    if _tabIdx == 1 then
        this.SupportMine:SetActive(true)
    elseif _tabIdx == 2 then
        this.MySupport:SetActive(true)
    end
    -- this:RefreshScroll(scrollIndex)
end

function DefenseTrainingSupportPopup:RefreshScroll_1(scrollIndex)
    this.AllSupportMineDatas = DefenseTrainingManager.FriendSupportHeroDatas

    this.scrollView_1:SetData(this.AllSupportMineDatas, function(index, root)
        self:FillItem_1(root, this.AllSupportMineDatas[index])
    end)
    if scrollIndex then
        this.scrollView_1:SetIndex(scrollIndex)
    end
end

function DefenseTrainingSupportPopup:RefreshScroll_2(scrollIndex)
    this.AllMineHeroDatas = DefenseTrainingManager.GetAllMineSupportHeroDatas()
    HeroManager.SortHeroData(this.AllMineHeroDatas)

    this.scrollView_2:SetData(this.AllMineHeroDatas, function(index, root)
        self:FillItem_2(root, this.AllMineHeroDatas[index])
    end)

    if scrollIndex then
        this.scrollView_2:SetIndex(scrollIndex)
    end
end

--获取加成后的最高战力
function DefenseTrainingSupportPopup:GetHeroMaxPower()
    local max = 0
    local allHero = HeroManager.GetAllHeroDatas()
    for i, v in ipairs(allHero) do
        local allAddProPower = HeroManager.CalculateHeroAllProValList(1, v.dynamicId, false)
        local power = allAddProPower[HeroProType.WarPower]
        if power > max then
            max = power
        end
    end
    return max
end

function DefenseTrainingSupportPopup:FillItem_1(go, data)
    Util.GetGameObject(go, "btnCancelSelect"):SetActive(false)
    Util.GetGameObject(go, "Already"):SetActive(false)
    Util.GetGameObject(go, "btnSelect"):SetActive(true)

    Util.GetGameObject(go, "FriendName"):GetComponent("Text").text = string.format(GetLanguageStrById(12552), data.name)
    local btnSelect = Util.GetGameObject(go, "btnSelect/btn")

    if DefenseTrainingManager.useFriendTankId == data.tank.dynamicId then
        btnSelect:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_anniuxiao")
        Util.GetGameObject(btnSelect, "Text"):GetComponent("Text").text = GetLanguageStrById(12551)
    else
        btnSelect:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_anniuxiao")
        Util.GetGameObject(btnSelect, "Text"):GetComponent("Text").text = GetLanguageStrById(12550)
    end

    Util.AddOnceClick(btnSelect, function()
        if DefenseTrainingManager.teamLock == 1 then
            PopupTipPanel.ShowTipByLanguageId(22421)
            return
        end
        if DefenseTrainingManager.useFriendTankId == nil then
            if data.tank.warPower > math.floor(DefenseTrainingSupportPopup:GetHeroMaxPower() * 1.2) then
                PopupTipPanel.ShowTipByLanguageId(22419)
                return
            end
            NetManager.DefTrainingUseTankFromFriend(data.uid, data.tank.dynamicId, function(msg)
                NetManager.DefTrainingGetInfo(function()
                    NetManager.GetTankInfoOfTeam(FormationTypeDef.DEFENSE_TRAINING, function()    --< 拉剩余血量数据
                        this:RefreshScroll_1()
                    end)
                end)
            end)
        else
            if data.tank.dynamicId == DefenseTrainingManager.useFriendTankId then
                NetManager.DisUseTankFromFriendByModuleId(1, data.tank.dynamicId, function()
                    NetManager.TeamInfoRequest()
                    NetManager.DefTrainingGetInfo(function()
                        this:RefreshScroll_1()
                    end)
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(22420)
            end
        end
    end)

    this:SetPreCommonUI(go, data.tank, true)
end

function DefenseTrainingSupportPopup:FillItem_2(go, data)
    Util.GetGameObject(go, "btnCancelSelect"):SetActive(false)
    Util.GetGameObject(go, "Already"):SetActive(false)
    Util.GetGameObject(go, "FriendName"):SetActive(false)
    local btnSelect = Util.GetGameObject(go, "btnSelect/btn")

    Util.AddOnceClick(btnSelect, function()
        if DefenseTrainingManager.shareTank == nil then
            NetManager.DefTrainingShareTankToFriend(data.dynamicId, function(msg)
                NetManager.DefTrainingGetInfo(function()
                    PopupTipPanel.ShowTipByLanguageId(12548)
                    this:RefreshScroll_2()
                    this:FillShareTankUI()
                end)
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(12549)
        end
    end)

    this:SetPreCommonUI(go, data, false)
end

--> useWarPower 别人支援我的 本地无数据 用warPower 我派遣出去的 用warPower  自己的用计算来
function DefenseTrainingSupportPopup:SetPreCommonUI(go, data, useWarPower)
    local item = Util.GetGameObject(go, "item")
    if not this.itemList[1] then
        this.itemList[1] = {}
    end
    if not this.itemList[1][go] then
        this.itemList[1][go] = SubUIManager.Open(SubUIConfig.ItemView, item.transform)
    end   
    this.itemList[1][go]:OnOpen(false, {data.id, 0, nil, data.star}, 1, nil, nil, nil, nil, nil)

    if useWarPower then
        Util.GetGameObject(go, "Power"):GetComponent("Text").text = string.format(GetLanguageStrById(10335), data.warPower)
    else
        allAddProVal = HeroManager.CalculateHeroAllProValList(1, data.dynamicId, false)
        Util.GetGameObject(go, "Power"):GetComponent("Text").text = string.format(GetLanguageStrById(10335), --[[data.warPower]]allAddProVal[HeroProType.WarPower])
    end

    Util.GetGameObject(go, "NameModel/Name"):GetComponent("Text").text = GetLanguageStrById(data.name)
end

function DefenseTrainingSupportPopup:FillShareTankUI()
    this.AlreadyGo:SetActive(false)
    this.NoGo:SetActive(false)
    if DefenseTrainingManager.shareTankLocalData == nil then
        this.NoGo:SetActive(true)
    else
        this.AlreadyGo:SetActive(true)

        this:SetPreCommonUI(this.AlreadyGo, DefenseTrainingManager.shareTankLocalData, true)
    end
end

--界面关闭时调用（用于子类重写）
function DefenseTrainingSupportPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function DefenseTrainingSupportPopup:OnDestroy()

end

return DefenseTrainingSupportPopup