require("Base/BasePanel")
GoodFriendMainPanel = Inherit(BasePanel)
local this = GoodFriendMainPanel
local friendNumber = 0
local index = 1


local stateImg = {
    GetPictureFont("cn2-x1_haoyou_zaixian"),
    GetPictureFont("cn2-x1_haoyou_lixian"),
}

--初始化组件（用于子类重写）
function GoodFriendMainPanel:InitComponent()
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowRight })
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    --好友
    this.friendListBtn = Util.GetGameObject(self.gameObject, "switchBtn/friendListBtn")
    this.friendListImage = Util.GetGameObject(self.gameObject, "switchBtn/friendListBtn/Image"):GetComponent("Image")
    this.friendListText = Util.GetGameObject(self.gameObject, "switchBtn/friendListBtn/Text"):GetComponent("Text")

    --添加
    this.friendSearchBtn = Util.GetGameObject(self.gameObject, "switchBtn/friendSearchBtn")
    this.friendSearchImage = Util.GetGameObject(self.gameObject, "switchBtn/friendSearchBtn/Image"):GetComponent("Image")
    this.friendSearchText = Util.GetGameObject(self.gameObject, "switchBtn/friendSearchBtn/Text"):GetComponent("Text")

    --申请
    this.friendApplicationBtn = Util.GetGameObject(self.gameObject, "switchBtn/friendApplicationBtn")
    this.friendApplicationImage = Util.GetGameObject(self.gameObject, "switchBtn/friendApplicationBtn/Image"):GetComponent("Image")
    this.friendApplicationText = Util.GetGameObject(self.gameObject, "switchBtn/friendApplicationBtn/Text"):GetComponent("Text")

    --黑名单
    this.blackListBtn = Util.GetGameObject(self.gameObject, "switchBtn/blackListBtn")
    this.blackListImage = Util.GetGameObject(self.gameObject, "switchBtn/blackListBtn/Image"):GetComponent("Image")
    this.blackListText = Util.GetGameObject(self.gameObject, "switchBtn/blackListBtn/Text"):GetComponent("Text")

    this.blackListRemoveAllBtn = Util.GetGameObject(self.gameObject, "blackList/bottomImage/btn")
    this.blackFriendNum = Util.GetGameObject(self.gameObject, "blackList/blackFriendNumber/blackFriendTextNumber"):GetComponent("Text")

    this.friendList = Util.GetGameObject(self.gameObject, "friendList")
    this.friendSearch = Util.GetGameObject(self.gameObject, "friendSearch")
    this.friendApplication = Util.GetGameObject(self.gameObject, "friendApplication")
    this.blackList = Util.GetGameObject(self.gameObject, "blackList")

    this.item1 = Util.GetGameObject(self.gameObject, "friendList/item1")
    this.item3 = Util.GetGameObject(self.gameObject, "friendSearch/item3")
    this.item2 = Util.GetGameObject(self.gameObject, "friendApplication/item2")
    this.item4 = Util.GetGameObject(self.gameObject, "blackList/item4")

    this.friendListContentGrid = Util.GetGameObject(self.gameObject, "friendList/scrollRect")
    this.friendSearchContentGrid = Util.GetGameObject(self.gameObject, "friendSearch/scrollRect")
    this.friendApplicationContentGrid = Util.GetGameObject(self.gameObject, "friendApplication/scrollRect")
    this.blackListContentGrid = Util.GetGameObject(self.gameObject, "blackList/scrollRect")

    this.friendNumberText = Util.GetGameObject(self.gameObject, "friendList/friendNumber/friendTextNumber")
    this.presentBtn = Util.GetGameObject(self.gameObject, "friendList/bottomImage/presentBtn")
    this.receiveBtn = Util.GetGameObject(self.gameObject, "friendList/bottomImage/receiveBtn")

    this.agreeAllBtn = Util.GetGameObject(self.gameObject, "friendApplication/bottomImage/agreeAllBtn")
    this.refreshButton = Util.GetGameObject(self.gameObject, "refreshButton")
    this.searchButton = Util.GetGameObject(self.gameObject, "friendSearch/bottomImage/searchButton")
    this.searchUserNameText = Util.GetGameObject(self.gameObject, "friendSearch/bottomImage/InputField/roleNameSearchText"):GetComponent("Text")

    this.roleImage1 = Util.GetGameObject(self.gameObject, "friendList/roleImage")
    this.roleImage2 = Util.GetGameObject(self.gameObject, "friendApplication/roleImage")
    this.roleImage3 = Util.GetGameObject(self.gameObject, "friendSearch/roleImage")
    this.roleImage4 = Util.GetGameObject(self.gameObject, "blackList/roleImage")

    this.titleText = Util.GetGameObject(self.gameObject, "friendSearch/titleBgImage/titleText"):GetComponent("Text")
    this.haveGetRewardNumText = Util.GetGameObject(self.gameObject, "friendList/haveGetRewardNum/haveGetRewardNumText"):GetComponent("Text")
    this.friendshipValueText = Util.GetGameObject(self.gameObject, "friendList/friendship/friendshipValue"):GetComponent("Text")
    --GoodFriendManager.GetFriendInfoRequest(1)--1:好友, 2:推荐列表 3:申请列表
    --GoodFriendManager.GetFriendInfoRequest(3)--1:好友, 2:推荐列表 3:申请列表
    --GoodFriendManager.GetFriendInfoRequest(2)--1:好友, 2:推荐列表 3:申请列表
    local v21 = this.friendListContentGrid:GetComponent("RectTransform").rect
    this.ScrollView1 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.friendListContentGrid.transform,
            this.item1, nil, Vector2.New(-v21.x * 2, -v21.y * 2), 1, 1, Vector2.New(0, 10))
    this.ScrollView1.moveTween.MomentumAmount = 1
    this.ScrollView1.moveTween.Strength = 2

    local v22 = this.friendApplicationContentGrid:GetComponent("RectTransform").rect
    this.ScrollView2 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.friendApplicationContentGrid.transform,
            this.item2, nil, Vector2.New(-v22.x * 2, -v22.y * 2), 1, 1, Vector2.New(0, 10))
    this.ScrollView2.moveTween.MomentumAmount = 1
    this.ScrollView2.moveTween.Strength = 2

    local v23 = this.friendSearchContentGrid:GetComponent("RectTransform").rect
    this.ScrollView3 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.friendSearchContentGrid.transform,
            this.item3, nil, Vector2.New(-v23.x * 2, -v23.y * 2), 1, 1, Vector2.New(0, 8))
    this.ScrollView3.moveTween.MomentumAmount = 1
    this.ScrollView3.moveTween.Strength = 2

    local v24 = this.blackListContentGrid:GetComponent("RectTransform").rect
    this.ScrollView4 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.blackListContentGrid.transform,
            this.item4, nil, Vector2.New(-v24.x * 2, -v24.y * 2), 1, 1, Vector2.New(0, 10))
    this.ScrollView4.moveTween.MomentumAmount = 1
    this.ScrollView4.moveTween.Strength = 2

    this.friendApplicationRedPoint = Util.GetGameObject(self.gameObject, "friendApplicationRedPoint")
    this.friendListRedPoint = Util.GetGameObject(self.gameObject, "friendListRedPoint")

    this.mask = Util.GetGameObject(self.gameObject, "switchBtn/mask").transform
    this.maskText = Util.GetGameObject(self.gameObject, "switchBtn/mask/Text"):GetComponent("Text")
    this.maskTextCurPos = this.maskText.transform.localPosition
end

--绑定事件（用于子类重写）
function GoodFriendMainPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
        --UIManager.OpenPanel(UIName.MainPanel)
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)

    end)
    Util.AddClick(this.blackListRemoveAllBtn, function()
        GoodFriendManager.RequestDeleteFromBlackList(0, function()
            PopupTipPanel.ShowTipByLanguageId(10793)
        end)
    end)

    Util.AddClick(this.presentBtn, function()
        local isCanPresent = false
        for i, v in pairs(GoodFriendManager.friendAllData) do
            if v.isGive == 0 then
                isCanPresent = true
            end
        end
        if isCanPresent == true then
            GoodFriendManager.FriendGivePresentRequest(2, 0)
        else
            PopupTipPanel.ShowTipByLanguageId(10794)
        end
    end)
    Util.AddClick(this.receiveBtn, function()
        if GoodFriendManager.MaxEnergyGet >= 1 then
            local isCanGet = false
            for i, v in pairs(GoodFriendManager.friendAllData) do
                if v.haveReward == 1 then
                    isCanGet = true
                end
            end
            if isCanGet == true then
                GoodFriendManager.FriendTakeHeartRequest(2, 0)
            else
                PopupTipPanel.ShowTipByLanguageId(10795)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(10796)
        end
    end)
    Util.AddClick(this.agreeAllBtn, function()
        if table.nums(GoodFriendManager.friendAllData) < GoodFriendManager.goodFriendLimit then
            if table.nums(GoodFriendManager.friendApplicationData) > 0 then
                GoodFriendManager.FriendInviteOperationRequest(3, 0)
            else
                PopupTipPanel.ShowTipByLanguageId(10797)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(10798)
        end
    end)
    Util.AddClick(this.searchButton, function()
        local userName = this.searchUserNameText.text
        if userName == "" then
            PopupTipPanel.ShowTipByLanguageId(10799)
        else
            GoodFriendManager.FriendSearchRequest(userName)
        end
        this.isInRecommendPage = false
        this.titleText.text = GetLanguageStrById(10800)
    end)
    Util.AddClick(this.refreshButton, function()
        GoodFriendManager.RefreshRecommend(2)
        this.titleText.text = GetLanguageStrById(10801)
        this.isInRecommendPage = true
    end)
    Util.AddClick(this.friendListBtn, function()
        this.HideList(this.itemList1)
        this.BtnClickEvnet(1)
    end)
    Util.AddClick(this.friendApplicationBtn, function()
        -- this.HideList(this.itemList2)
        this.BtnClickEvnet(2)
    end)
    Util.AddClick(this.friendSearchBtn, function()
        this.HideList(this.itemList3)
        this.BtnClickEvnet(3)
    end)
    Util.AddClick(this.blackListBtn, function()
        this.HideList(this.itemList4)
        this.BtnClickEvnet(4)
    end)

    -- 绑定红点
    BindRedPointObject(RedPointType.Friend_Reward, this.friendListRedPoint)
    BindRedPointObject(RedPointType.Friend_Application, this.friendApplicationRedPoint)
end

function this.HideList(list)
    if list then
        for index, value in ipairs(list) do
            if value.activeSelf then
                value:SetActive(false)
            end
        end
    end
end

--添加事件监听（用于子类重写）
function GoodFriendMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Friend.OnFriendList, this.FriendListDataShow)
    Game.GlobalEvent:AddEvent(GameEvent.Friend.OnFriendApplication, this.FriendApplicationDataShow)
    Game.GlobalEvent:AddEvent(GameEvent.Friend.OnFriendSearch, this.FriendSearchDataShow)
    Game.GlobalEvent:AddEvent(GameEvent.Friend.OnBlackFriend, this.BlackListDataShow)
end

--移除事件监听（用于子类重写）
function GoodFriendMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Friend.OnFriendList, this.FriendListDataShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Friend.OnFriendApplication, this.FriendApplicationDataShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Friend.OnFriendSearch, this.FriendSearchDataShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Friend.OnBlackFriend, this.BlackListDataShow)
end

--界面打开时调用（用于子类重写）
function GoodFriendMainPanel:OnOpen(...)
    index = 1
    local args = {...}
    this.isBlackPage = args[2]
    index = args[2] and args[2] or 1
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GoodFriendMainPanel:OnShow()
    --GoodFriendManager.OnRefreshDataNextDay()
    this.roleImage1:SetActive(false)
    this.roleImage2:SetActive(false)
    this.roleImage3:SetActive(false)
    this.roleImage4:SetActive(false)
    this:FriendListDataShow()
    this:FriendApplicationDataShow()
    this:FriendSearchDataShow()
    this:BlackListDataShow()
    this.isInRecommendPage = true
    this:OnRefreshData()
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.GoodFriend })
    if not this.isBlackPage then
        if this.friendListRedPoint.activeSelf or (not this.friendApplicationRedPoint.activeSelf and not this.friendListRedPoint.activeSelf) then
            this.friendListImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong")
            this.friendApplicationImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong_quekou")
            this.friendSearchImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong_quekou")
            this.blackListImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong_quekou")
            this.friendListText.text = GetLanguageStrById(10802)
            this.friendApplicationText.text = GetLanguageStrById(10803)
            this.friendSearchText.text = GetLanguageStrById(10804)
            this.blackListText.text = GetLanguageStrById(10805)
            this.friendList:SetActive(true)
            this.friendApplication:SetActive(false)
            this.friendSearch:SetActive(false)
            this.blackList:SetActive(false)
        else
            this.friendList:SetActive(false)
            this.friendApplication:SetActive(true)
            this.friendSearch:SetActive(false)
            this.blackList:SetActive(false)
            this.friendListImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong")
            this.friendApplicationImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong_quekou")
            this.friendSearchImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong_quekou")
            this.blackListImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong_quekou")
            this.friendListText.text = GetLanguageStrById(10806)
            this.friendApplicationText.text = GetLanguageStrById(10807)
            this.friendSearchText.text = GetLanguageStrById(10804)
            this.blackListText.text = GetLanguageStrById(10805)
        end
    else
        this.friendList:SetActive(false)
        this.friendApplication:SetActive(false)
        this.friendSearch:SetActive(false)
        this.blackList:SetActive(true)
        this.friendListImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong")
        this.friendApplicationImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong_quekou")
        this.friendSearchImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong_quekou")
        this.blackListImage.sprite = Util.LoadSprite("cn2-x1_haoyou_biaoqian_weixuanzhong_quekou")
        this.friendListText.text = GetLanguageStrById(10806)
        this.friendApplicationText.text = GetLanguageStrById(10803)
        this.friendSearchText.text = GetLanguageStrById(10804)
        this.blackListText.text = GetLanguageStrById(10808)

    end
    this.BtnClickEvnet(index)
end

--刷新界面数据
function GoodFriendMainPanel:OnRefreshData()
    if table.nums(GoodFriendManager.friendAllData) <= 0 then
        this.roleImage1:SetActive(true)
        -- this.roleTalk1.text = GetLanguageStrById(10809)
    else
        this.roleImage1:SetActive(false)
    end
    if table.nums(GoodFriendManager.friendApplicationData) <= 0 then
        this.roleImage2:SetActive(true)
        -- this.roleTalk2.text = GetLanguageStrById(10797)
    else
        this.roleImage2:SetActive(false)
    end
    if table.nums(GoodFriendManager.friendSearchData) > 0 then
        this.roleImage3:SetActive(false)
    else
        this.roleImage3:SetActive(true)
        -- this.roleTalk3.text = GetLanguageStrById(10810)
    end
    if this.isInRecommendPage then
        -- this.roleTalk3.text = GetLanguageStrById(10811)
    end

    if table.nums(GoodFriendManager.blackFriendList) <= 0 then
        this.roleImage4:SetActive(true)
    else
        this.roleImage4:SetActive(false)
    end
end


--界面关闭时调用（用于子类重写）
function GoodFriendMainPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function GoodFriendMainPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.HeadFrameView)
    ClearRedPointObject(RedPointType.Friend_Reward, this.friendListRedPoint)
    ClearRedPointObject(RedPointType.Friend_Application, this.friendApplicationRedPoint)
    this.ScrollView1 = nil
    this.ScrollView2 = nil
    this.ScrollView3 = nil
    this.ScrollView4 = nil
end

--好友列表循环滚动数据
function GoodFriendMainPanel:FriendListDataShow()
    CheckRedPointStatus(RedPointType.Friend_Reward)
    this:OnRefreshData()
    local list = {}
    local j = 1
    for i, v in pairs(GoodFriendManager.friendAllData) do
        list[j] = v
        if table.nums(GoodFriendManager.friendAllData) > 1 then
            if v.offLineTime == "0" then
                list[j].onLineState = 1
            else
                list[j].onLineState = 2
            end
        end
        j = j + 1
    end
    if #list > 1 then
        table.sort(list, function(a, b)
            if a.onLineState == b.onLineState then
                return tonumber(a.offLineTime) > tonumber(b.offLineTime)
            else
                return a.onLineState < b.onLineState
            end
        end)
    end
    -- this.itemList1 = {}
    this.ScrollView1:SetData(list, function(index, item)
        local itemData = list[index]
        this:FriendListRefreshData(item, itemData)
        -- this.itemList1[index] = item
    end)
    this.friendNumberText:GetComponent("Text").text = --[[GetLanguageStrById(10812) .. ]]#list .. "/" .. GoodFriendManager.goodFriendLimit
    this.haveGetRewardNumText.text = GetLanguageStrById(10813)..(GoodFriendManager.MaxEnergy-GoodFriendManager.MaxEnergyGet).."/"..GoodFriendManager.MaxEnergy
    this.friendshipValueText.text = BagManager.GetItemCountById(69)

    -- DelayCreation(this.itemList1)
end

--好友申请循环滚动数据
function GoodFriendMainPanel:FriendApplicationDataShow()
    -- 检测红点
    CheckRedPointStatus(RedPointType.Friend_Application)
    this:OnRefreshData()
    local list = {}
    local j = 1
    for i, v in pairs(GoodFriendManager.friendApplicationData) do
        list[j] = v
        if table.nums(GoodFriendManager.friendApplicationData) > 1 then
            if v.offLineTime == "0" then
                list[j].onLineState = 1
            else
                list[j].onLineState = 2
            end
        end
        j = j + 1
    end
    if #list >= 1 then
        this.friendApplicationRedPoint:SetActive(true)
        table.sort(list, function(a, b)
            if a.onLineState == b.onLineState then
                return tonumber(a.offLineTime) > tonumber(b.offLineTime)
            else
                return a.onLineState < b.onLineState
            end
        end)
    else
        this.friendApplicationRedPoint:SetActive(false)
    end
    -- this.itemList2 = {}
    this.ScrollView2:SetData(list, function(index, item)
        local itemData = list[index]
        this:FriendApplicationRefreshData(item, itemData)
        -- this.itemList2[index] = item
    end)

    -- DelayCreation(this.itemList2)
end

--好友搜索循环滚动数据
function GoodFriendMainPanel:FriendSearchDataShow()
    this:OnRefreshData()
    local list = {}
    local j = 1
    for i, v in pairs(GoodFriendManager.friendSearchData) do
        list[j] = v
        if table.nums(GoodFriendManager.friendSearchData) > 1 then
            if v.offLineTime == "0" then
                list[j].onLineState = 1
            else
                list[j].onLineState = 2
            end
        end
        j = j + 1
    end
    if #list > 1 then
        table.sort(list, function(a, b)
            if a.onLineState == b.onLineState then
                return tonumber(a.offLineTime) > tonumber(b.offLineTime)
            else
                return a.onLineState < b.onLineState
            end
        end)
    end

    -- this.itemList3 = {}
    this.ScrollView3:SetData(list, function(index, item)
        local itemData = list[index]
        this:FriendSearchRefreshData(item, itemData)
        -- this.itemList3[index] = item
    end)
    -- DelayCreation(this.itemList3)
end

--黑名单滚动数据
function GoodFriendMainPanel:BlackListDataShow()
    this:OnRefreshData()
    local list = {}
    local j = 1
    for i, v in pairs(GoodFriendManager.blackFriendList) do
        list[j] = v
        if table.nums(GoodFriendManager.blackFriendList) > 1 then
            if v.offLineTime == "0" then
                list[j].onLineState = 1
            else
                list[j].onLineState = 2
            end
        end
        j = j + 1
    end
    if #list > 1 then
        table.sort(list, function(a, b)
            if a.onLineState == b.onLineState then
                return tonumber(a.offLineTime) > tonumber(b.offLineTime)
            else
                return a.onLineState < b.onLineState
            end
        end)
    end
    -- this.itemList4 = {}
    this.ScrollView4:SetData(list, function(index, item)
        local itemData = list[index]
        this:BlackListRefreshData(item, itemData)
        -- this.itemList4[index] = item
    end)
    -- DelayCreation(this.itemList4)
    this.blackFriendNum.text = --[[GetLanguageStrById(10814) .. ]]#list .. "/" .. GoodFriendManager.blackFriendLimit
end



--好友
function GoodFriendMainPanel:FriendListRefreshData(item, itemData)
    local head = Util.GetGameObject(item, "friendHeadIcon")
    head:GetComponent("Image").sprite = GetPlayerHeadSprite(itemData.head)
    Util.GetGameObject(item, "friendHeadIcon/friendHeadFrame"):GetComponent("Image").sprite = GetPlayerHeadFrameSprite(itemData.frame)
    Util.GetGameObject(item, "name/nameText"):GetComponent("Text").text = itemData.name
    Util.GetGameObject(item, "lvbg/levelText"):GetComponent("Text").text = itemData.lv
    Util.GetGameObject(item, "zhanli/Text"):GetComponent("Text").text = itemData.soulVal

    local deleteFriendBtn = Util.GetGameObject(item, "deleteFriend")
    local givingEnergyBtn = Util.GetGameObject(item, "givingEnergy")
    local presentEnergyBtn = Util.GetGameObject(item, "presentEnergy")
    local haveEnergyBtn = Util.GetGameObject(item, "havePresent")
    local sendMessageBtn = Util.GetGameObject(item, "sendMessage")
    if itemData.offLineTime == "0" then
        -- Util.GetGameObject(item, "name/bg"):SetActive(true)
        Util.GetGameObject(item, "name/bg"):GetComponent("Image").sprite = Util.LoadSprite(stateImg[1])
        Util.GetGameObject(item, "name/lastOnlineText"):SetActive(false)
    else
        -- Util.GetGameObject(item, "name/bg"):SetActive(false)
        Util.GetGameObject(item, "name/bg"):GetComponent("Image").sprite = Util.LoadSprite(stateImg[2])
        Util.GetGameObject(item, "name/lastOnlineText"):SetActive(true)
        Util.GetGameObject(item, "name/lastOnlineText"):GetComponent("Text").text = this:ShowTime(itemData.offLineTime)
    end
    if GoodFriendManager.MaxEnergyGet >= 1 then
        if itemData.isGive == 0 then
            Util.GetGameObject(item, "givingEnergy"):SetActive(false)
            Util.GetGameObject(item, "presentEnergy"):SetActive(true)
            Util.GetGameObject(item, "havePresent"):SetActive(false)
        end
        if itemData.haveReward == 1 then
            Util.GetGameObject(item, "givingEnergy"):SetActive(true)
            Util.GetGameObject(item, "presentEnergy"):SetActive(false)
            Util.GetGameObject(item, "havePresent"):SetActive(false)
            Util.GetGameObject(item, "givingEnergy/givingEnergyRedPoint"):SetActive(true)
        end
    else
        if itemData.haveReward == 1 then
            Util.GetGameObject(item, "givingEnergy"):SetActive(true)
            Util.GetGameObject(item, "presentEnergy"):SetActive(false)
            Util.GetGameObject(item, "havePresent"):SetActive(false)
            Util.GetGameObject(item, "givingEnergy/givingEnergyRedPoint"):SetActive(false)
        end
        if itemData.isGive == 0 then
            Util.GetGameObject(item, "givingEnergy"):SetActive(false)
            Util.GetGameObject(item, "presentEnergy"):SetActive(true)
            Util.GetGameObject(item, "havePresent"):SetActive(false)
        end
    end
    if itemData.isGive == 1 and itemData.haveReward == 0 then
        Util.GetGameObject(item, "givingEnergy"):SetActive(false)
        Util.GetGameObject(item, "presentEnergy"):SetActive(false)
        Util.GetGameObject(item, "havePresent"):SetActive(true)
    end
    Util.AddOnceClick(deleteFriendBtn, function()
        local tip = string.format(GetLanguageStrById(10815), itemData.name)
        MsgPanel.ShowTwo(tip, nil, function()
            GoodFriendManager.DelFriendRequest(itemData.id)
        end)
    end)
    Util.AddOnceClick(givingEnergyBtn, function()
        if GoodFriendManager.MaxEnergyGet >= 1 then
            GoodFriendManager.FriendTakeHeartRequest(1, itemData.id)
        else
            PopupTipPanel.ShowTipByLanguageId(10796)
        end
    end)
    Util.AddOnceClick(presentEnergyBtn, function()
        GoodFriendManager.FriendGivePresentRequest(1, itemData.id)
    end)
    Util.AddOnceClick(haveEnergyBtn, function()
        PopupTipPanel.ShowTipByLanguageId(10816)
    end)
    Util.AddOnceClick(sendMessageBtn, function()
        UIManager.OpenPanel(UIName.FriendChatPanel, itemData.id)
    end)

    Util.AddOnceClick(head, function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, itemData.id)
    end)
end

-- 好友申请
function GoodFriendMainPanel:FriendApplicationRefreshData(item, itemData)
    local head = Util.GetGameObject(item, "friendHeadIcon")
    head:GetComponent("Image").sprite = GetPlayerHeadSprite(itemData.head)
    Util.GetGameObject(item, "friendHeadIcon/friendHeadFrame"):GetComponent("Image").sprite = GetPlayerHeadFrameSprite(itemData.frame)
    Util.GetGameObject(item, "name/nameText"):GetComponent("Text").text = itemData.name
    Util.GetGameObject(item, "lvbg/levelText"):GetComponent("Text").text = itemData.lv
    Util.GetGameObject(item, "zhanli/Text"):GetComponent("Text").text = itemData.soulVal
    local agreeBtn = Util.GetGameObject(item, "agree")
    local refuseBtn = Util.GetGameObject(item, "refuse")
    if itemData.offLineTime == "0" then
        -- Util.GetGameObject(item, "Image/bg"):SetActive(true)
        Util.GetGameObject(item, "name/bg"):GetComponent("Image").sprite = Util.LoadSprite(stateImg[1])
        Util.GetGameObject(item, "name/lastOnlineText"):SetActive(false)
    else
        -- Util.GetGameObject(item, "Image/bg"):SetActive(false)
        Util.GetGameObject(item, "name/bg"):GetComponent("Image").sprite = Util.LoadSprite(stateImg[2])
        Util.GetGameObject(item, "name/lastOnlineText"):SetActive(true)
        Util.GetGameObject(item, "name/lastOnlineText"):GetComponent("Text").text = this:ShowTime(itemData.offLineTime)
    end
    Util.AddOnceClick(agreeBtn, function()
        if GoodFriendManager.IsInBlackList(itemData.id) then
            PopupTipPanel.ShowTipByLanguageId(10817)
            return
        end
        if table.nums(GoodFriendManager.friendAllData) < GoodFriendManager.goodFriendLimit then
            GoodFriendManager.FriendInviteOperationRequest(1, itemData.id)
        else
            PopupTipPanel.ShowTipByLanguageId(10798)
        end
    end)
    Util.AddOnceClick(refuseBtn, function()
        GoodFriendManager.FriendInviteOperationRequest(2, itemData.id)
    end)
    Util.AddOnceClick(head, function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, itemData.id)
    end)
end

-- 好友搜索
function GoodFriendMainPanel:FriendSearchRefreshData(item, itemData)
    local head = Util.GetGameObject(item, "friendHeadIcon")
    head:GetComponent("Image").sprite = GetPlayerHeadSprite(itemData.head)
    Util.GetGameObject(item, "friendHeadIcon/friendHeadFrame"):GetComponent("Image").sprite = GetPlayerHeadFrameSprite(itemData.frame)

    Util.GetGameObject(item, "name/nameText"):GetComponent("Text").text = itemData.name
    Util.GetGameObject(item, "lvbg/levelText"):GetComponent("Text").text = itemData.lv
    Util.GetGameObject(item, "zhanli/Text"):GetComponent("Text").text = itemData.soulVal
    local applicationFriendBtn = Util.GetGameObject(item, "applicationFriend")
    local applicationFriendText = Util.GetGameObject(item, "applicationFriend/Text"):GetComponent("Text")
    if itemData.offLineTime == "0" then
        -- Util.GetGameObject(item, "name/bg"):SetActive(true)
        Util.GetGameObject(item, "name/bg"):GetComponent("Image").sprite = Util.LoadSprite(stateImg[1])
        Util.GetGameObject(item, "name/lastOnlineText"):SetActive(false)
    else
        -- Util.GetGameObject(item, "name/bg"):SetActive(false)
        Util.GetGameObject(item, "name/bg"):GetComponent("Image").sprite = Util.LoadSprite(stateImg[2])
        Util.GetGameObject(item, "name/lastOnlineText"):SetActive(true)
        Util.GetGameObject(item, "name/lastOnlineText"):GetComponent("Text").text = this:ShowTime(itemData.offLineTime)
    end
    local isFriend = GoodFriendManager.IsMyFriend(itemData.id)
    if isFriend then
        Util.SetGray(applicationFriendBtn, true)
        applicationFriendText.text = GetLanguageStrById(10818)
        -- applicationFriendBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-x1_haoyou_shenqinghaoyou"))
    elseif itemData.isApplyed == 1 then
        Util.SetGray(applicationFriendBtn, true)
        -- applicationFriendBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-x1_haoyou_yishenqing"))
        applicationFriendText.text = GetLanguageStrById(10819)
    else
        Util.SetGray(applicationFriendBtn, false)
        applicationFriendText.text = GetLanguageStrById(10820)
    end

    Util.AddOnceClick(applicationFriendBtn, function()
        if isFriend then
            PopupTipPanel.ShowTipByLanguageId(10821)
            return
        end
        if itemData.isApplyed == 1 then
            PopupTipPanel.ShowTipByLanguageId(10822)
            return
        end
        if table.nums(GoodFriendManager.friendAllData) >= GoodFriendManager.goodFriendLimit then
            PopupTipPanel.ShowTipByLanguageId(10798)
            return
        end
        if GoodFriendManager.IsInBlackList(itemData.id) then
            PopupTipPanel.ShowTipByLanguageId(10817)
            return
        end
        GoodFriendManager.InviteFriendRequest(itemData.id,function ()
            PopupTipPanel.ShowTipByLanguageId(10823)
        end)
    end)
    Util.AddOnceClick(head, function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, itemData.id)
    end)
end

-- 黑名单
function GoodFriendMainPanel:BlackListRefreshData(item, itemData)
    local head = Util.GetGameObject(item, "friendHeadIcon")
    head:GetComponent("Image").sprite = GetPlayerHeadSprite(itemData.head)
    Util.GetGameObject(item, "friendHeadIcon/friendHeadFrame"):GetComponent("Image").sprite = GetPlayerHeadFrameSprite(itemData.frame)
    Util.GetGameObject(item, "name/nameText"):GetComponent("Text").text = itemData.name
    Util.GetGameObject(item, "lvbg/levelText"):GetComponent("Text").text = itemData.lv
    Util.GetGameObject(item, "zhanli/Text"):GetComponent("Text").text = itemData.soulVal
    if itemData.offLineTime == "0" then
        Util.GetGameObject(item, "name/bg"):GetComponent("Image").sprite = Util.LoadSprite(stateImg[1])
        Util.GetGameObject(item, "name/lastOnlineText"):SetActive(false)
    else
        Util.GetGameObject(item, "name/bg"):GetComponent("Image").sprite = Util.LoadSprite(stateImg[2])
        Util.GetGameObject(item, "name/lastOnlineText"):SetActive(true)
        Util.GetGameObject(item, "name/lastOnlineText"):GetComponent("Text").text = this:ShowTime(itemData.offLineTime)
    end

    local removeBlackListBtn = Util.GetGameObject(item, "deleteFriend")
    Util.AddOnceClick(removeBlackListBtn, function()
        GoodFriendManager.RequestDeleteFromBlackList(itemData.id, function()
            PopupTipPanel.ShowTipByLanguageId(10793)
        end)
    end)
    Util.AddOnceClick(head, function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, itemData.id, PLAYER_INFO_VIEW_TYPE.BLACK_REMOVE)
    end)
end

--格式化时间
function GoodFriendMainPanel:ShowTime(time)
    local onlineTime = math.floor(PlayerManager.serverTime - time / 1000)
    local timeText = ""
    if onlineTime < 60 then
        timeText = GetLanguageStrById(10824)
        return timeText
    elseif onlineTime >= 60 and onlineTime < 3600 then
        timeText = math.floor(onlineTime / 60) .. GetLanguageStrById(10825)
        return timeText
    elseif onlineTime >= 3600 and onlineTime < 3600 * 24 then
        timeText = math.floor(onlineTime / 3600) .. GetLanguageStrById(10826)
        return timeText
    elseif onlineTime >= 3600 * 24 and onlineTime <= 3600 * 24 * 30 then
        timeText = math.floor(onlineTime / (3600 * 24)) .. GetLanguageStrById(10827)
        return timeText
    elseif onlineTime > 3600 * 24 * 30 then
        timeText = GetLanguageStrById(10828)
        return timeText
    end
end

function this.BtnClickEvnet(index)
    if index == 1 then
        this.friendList:SetActive(true)
        this.friendApplication:SetActive(false)
        this.friendSearch:SetActive(false)
        this.blackList:SetActive(false)

        this.friendListBtn:SetActive(false)
        this.friendApplicationBtn:SetActive(true)
        this.friendSearchBtn:SetActive(true)
        this.blackListBtn:SetActive(true)

        this.mask.localPosition = this.friendListBtn.transform.localPosition
        this.maskText.text = this.friendListText.text
        this.maskText.transform.localPosition = this.maskTextCurPos
        GoodFriendManager.RefreshFriendStateRequest()
    elseif index == 2 then
        this.friendList:SetActive(false)
        this.friendApplication:SetActive(true)
        this.friendSearch:SetActive(false)
        this.blackList:SetActive(false)

        this.friendListBtn:SetActive(true)
        this.friendApplicationBtn:SetActive(false)
        this.friendSearchBtn:SetActive(true)
        this.blackListBtn:SetActive(true)

        this.mask.localPosition = this.friendApplicationBtn.transform.localPosition - Vector3.New(15,0,0)
        this.maskText.text = this.friendApplicationText.text
        this.maskText.transform.localPosition = this.maskTextCurPos
        -- GoodFriendManager.RefreshFriendStateRequest()
    elseif index == 3 then
        this.friendList:SetActive(false)
        this.friendApplication:SetActive(false)
        this.friendSearch:SetActive(true)
        this.blackList:SetActive(false)

        this.friendListBtn:SetActive(true)
        this.friendApplicationBtn:SetActive(true)
        this.friendSearchBtn:SetActive(false)
        this.blackListBtn:SetActive(true)

        this.mask.localPosition = this.friendSearchBtn.transform.localPosition - Vector3.New(15,0,0)
        this.maskText.text = this.friendSearchText.text
        this.maskText.transform.localPosition = this.maskTextCurPos
        GoodFriendManager.RefreshRecommend(2)
    elseif index == 4 then
        this.friendList:SetActive(false)
        this.friendApplication:SetActive(false)
        this.friendSearch:SetActive(false)
        this.blackList:SetActive(true)

        this.friendListBtn:SetActive(true)
        this.friendApplicationBtn:SetActive(true)
        this.friendSearchBtn:SetActive(true)
        this.blackListBtn:SetActive(false)

        this.mask.localPosition = this.blackListBtn.transform.localPosition - Vector3.New(15,0,0)
        this.maskText.text = this.blackListText.text
        this.maskText.transform.localPosition = this.maskTextCurPos + Vector3.New(10.6,0,0)
        GoodFriendManager.RefreshRecommend(4)
    end
end
return GoodFriendMainPanel