require("Base/BasePanel")
ClimbTowerEliteRewardPopup = Inherit(BasePanel)
local this = ClimbTowerEliteRewardPopup

-- local VirtualTargetReward = ConfigManager.GetConfig(ConfigName.VirtualTargetReward)

local _tabIdx = 1
local TabBox = require("Modules/Common/TabBox") -- 引用

local _TabData = {
    [1] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", name = GetLanguageStrById(12523) },
    [2] = { default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", name = GetLanguageStrById(12524) },
}

--初始化组件（用于子类重写）
function ClimbTowerEliteRewardPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "bg/btnClose")

    --获取帮助按钮
    this.HelpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition

    this.tabBox = Util.GetGameObject(self.gameObject, "bg/TabBox")
    this.Normal = Util.GetGameObject(self.gameObject, "bg/Normal")
    this.Vip = Util.GetGameObject(self.gameObject, "bg/Vip")
    this.VipBtn = Util.GetGameObject(self.gameObject, "bg/Vip/VipBtn")
    this.GoBtn = Util.GetGameObject(self.gameObject, "bg/Vip/GoBtn")
    this.Tier = Util.GetGameObject(self.gameObject, "bg/Vip/GameObject/Tier")

    this.ScrollPre = Util.GetGameObject(self.gameObject, "bg/ScrollPre")

    this.Scroll_Normal = Util.GetGameObject(self.gameObject, "bg/Normal/Scroll")
    local w_Normal = this.Scroll_Normal.transform.rect.width
    local h_Normal = this.Scroll_Normal.transform.rect.height
    this.scrollView_Normal = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll_Normal.transform, this.ScrollPre, nil,
            Vector2.New(w_Normal, h_Normal), 1, 1, Vector2.New(0, 10))
    this.scrollView_Normal.moveTween.MomentumAmount = 1
    this.scrollView_Normal.moveTween.Strength = 2

    this.Scroll_Vip = Util.GetGameObject(self.gameObject, "bg/Vip/Scroll")
    local w_Vip = this.Scroll_Vip.transform.rect.width
    local h_Vip = this.Scroll_Vip.transform.rect.height
    this.scrollView_Vip = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll_Vip.transform, this.ScrollPre, nil,
            Vector2.New(w_Vip, h_Vip), 1, 1, Vector2.New(0, 10))
    this.scrollView_Vip.moveTween.MomentumAmount = 1
    this.scrollView_Vip.moveTween.Strength = 2

    this.itemList = {}
end

--绑定事件（用于子类重写）
function ClimbTowerEliteRewardPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.VipBtn, function()
        local isOpen = nil
        if this.climbTowerType == ClimbTowerManager.ClimbTowerType.Normal then
            isOpen = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.ClimbTowerUnlockNormalVip)
        elseif this.climbTowerType == ClimbTowerManager.ClimbTowerType.Advance then
            isOpen = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.ClimbTowerUnlockAdvanceVip)
        end
        if not isOpen then
            UIManager.OpenPanel(UIName.ClimbTowerUnlockPopup, ClimbTowerManager.ClimbTowerType.Advance)
        end
    end)

    Util.AddClick(this.GoBtn, function()
        self:ClosePanel()
    end)
    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.ClimbTowerEliteRewardPopup,this.helpPosition.x,this.helpPosition.y+100) 
    end)
end

--添加事件监听（用于子类重写）
function ClimbTowerEliteRewardPopup:AddListener()
end

--移除事件监听（用于子类重写）
function ClimbTowerEliteRewardPopup:RemoveListener() 
end

--界面打开时调用（用于子类重写）
function ClimbTowerEliteRewardPopup:OnOpen()
    this.climbTowerType = ClimbTowerManager.ClimbTowerType.Advance
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ClimbTowerEliteRewardPopup:OnShow()
    this.tabCtrl = TabBox.New()
    this.tabCtrl:SetTabAdapter(this.OnTabAdapter) 
    this.tabCtrl:SetTabIsLockCheck(this.OnTabIsLockCheck)
    this.tabCtrl:SetChangeTabCallBack(this.OnChangeTab)

    this.configDataNormal = ClimbTowerManager.GetChallengeConfigNormalData(ClimbTowerManager.ClimbTowerType.Advance)
    this.configDataVip = ClimbTowerManager.GetChallengeConfigVipData(ClimbTowerManager.ClimbTowerType.Advance)
    this.curTier = ClimbTowerManager.fightId_Advance - 1--通过层数
    this.totalStar = ClimbTowerManager.GetStageAllStarsNum()
    _tabIdx = 1

    this.tabCtrl:Init(this.tabBox, _TabData)
    ClimbTowerEliteRewardPopup.ChangeTab(_tabIdx)

    this.Tier:GetComponent("Text").text = tostring(this.totalStar)
end

function ClimbTowerEliteRewardPopup.OnTabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    -- _tabIdx = index
    -- ClimbTowerEliteRewardPopup.ChangeTab(index)
end
function ClimbTowerEliteRewardPopup.OnTabIsLockCheck(index)
end
function ClimbTowerEliteRewardPopup.OnChangeTab(index, lastIndex)
    ClimbTowerEliteRewardPopup.ChangeTab(index, 1)
end

function ClimbTowerEliteRewardPopup.ChangeTab(index, scrollIndex)
    _tabIdx = index

    if this.climbTowerType == ClimbTowerManager.ClimbTowerType.Normal then
        this.isOpen = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.ClimbTowerUnlockNormalVip)
    elseif this.climbTowerType == ClimbTowerManager.ClimbTowerType.Advance then
        this.isOpen = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.ClimbTowerUnlockAdvanceVip)
    end

    this.data = {}
    this.Normal:SetActive(false)
    this.Vip:SetActive(false)
    if index == 1 then
        local RewardTaskData = ClimbTowerManager.GetTaskData(ClimbTowerManager.RewardType.Normal, ClimbTowerManager.ClimbTowerType.Advance)
        for i = 1, #this.configDataNormal do
            local status = 0
            local tData = RewardTaskData[this.configDataNormal[i].Star]
            if tData then
                status = tData.state
            end
            
            table.insert(this.data, {status = status, data = this.configDataNormal[i], type = index})
        end

        this.Normal:SetActive(true)
    elseif index == 2 then
        local RewardTaskData = ClimbTowerManager.GetTaskData(ClimbTowerManager.RewardType.Vip, ClimbTowerManager.ClimbTowerType.Advance)
        for i = 1, #this.configDataVip do
            local status = 0
            local tData = RewardTaskData[this.configDataVip[i].Star]
            if tData then
                status = tData.state
            end

            local isLock = not this.isOpen
            if isLock then
                status = 3
            end

            table.insert(this.data, {status = status, data = this.configDataVip[i], type = index, cornerType = isLock and ItemCornerType.Lock or nil})
        end

        this.Vip:SetActive(true)
    end

    table.sort(this.data, function(a, b)
        if a.status == b.status then
            return a.data.Star < b.data.Star
        else
            local sort = {1, 0, 2, 3}
            return sort[a.status + 1] < sort[b.status + 1]
        end
    end)
 
    this:RefreshScroll(scrollIndex)
end

function ClimbTowerEliteRewardPopup:RefreshScroll(scrollIndex)
    -- this.scrollView:SetData(self.data, function(index, root)
    --     self:FillItem(root, self.data[index])
    -- end)

    -- if scrollIndex then
    --     this.scrollView:SetIndex(scrollIndex)
    -- end

    if _tabIdx == 1 then
        local itemList = {}
        this.scrollView_Normal:SetData(self.data, function(index, root)
            self:FillItem(root, self.data[index])
            itemList[index] = root
        end)
        DelayCreation(itemList)
    
        if scrollIndex then
            this.scrollView_Normal:SetIndex(scrollIndex)
        end
    elseif _tabIdx == 2 then
        local itemList = {}
        this.scrollView_Vip:SetData(self.data, function(index, root)
            self:FillItem(root, self.data[index])
            itemList[index] = root
        end)
        DelayCreation(itemList)
    
        if scrollIndex then
            this.scrollView_Vip:SetIndex(scrollIndex)
        end
    end

    CheckRedPointStatus(RedPointType.ClimbSeniorTowerReward)
end

function ClimbTowerEliteRewardPopup:FillItem(go, data)
    local RewardGrid = Util.GetGameObject(go, "Grid/RewardGrid")

    if this.itemList[go] == nil then
        this.itemList[go] = {}
        for i = 1, 4 do     --目前最多支持四个item
            this.itemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, RewardGrid.transform)
        end
    end
    local itemData = data.type == 1 and data.data.StarReward or data.data.PurchaseLevelReward
    for i = 1, 4 do
        local ItemView = this.itemList[go][i]
        if i <= #itemData then
            ItemView.gameObject:SetActive(true)
            
            ItemView:OnOpen(false, {itemData[i][1], itemData[i][2]}, 0.6, nil, nil, nil, nil, data.cornerType)
        else
            ItemView.gameObject:SetActive(false)
        end
    end

    local finishTier = data.data.Star
    Util.GetGameObject(go, "title"):GetComponent("Text").text = string.format(GetLanguageStrById(50233), finishTier, this.totalStar > finishTier and finishTier or this.totalStar, finishTier)

    local statusGo = {}
    for i = 1, 4 do
        local status = Util.GetGameObject(go, "Status" .. tostring(i - 1))
        status:SetActive(data.status == i - 1)
        statusGo[i-1] = status
    end
    if data.status == 0 then
        Util.AddOnceClick(Util.GetGameObject(statusGo[data.status], "Btn"), function()
            --前往
            self:ClosePanel()
        end)
    elseif data.status == 1 then
        Util.AddOnceClick(Util.GetGameObject(statusGo[data.status], "Btn"), function()
            --领取
            local type = nil
            if _tabIdx == 1 then
                type = TaskTypeDef.ClimbTowerNormalTaskAdvance
            elseif _tabIdx == 2 then
                type = TaskTypeDef.ClimbTowerVipTaskAdvance
            end
            NetManager.TakeMissionRewardRequest(type, data.data.Star, function(msg)
                if msg.drop then
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
                end

                TaskManager.SetTypeTaskState(type, data.data.Star, 2)  --客户端即时刷新数据 后端推送有延迟

                ClimbTowerEliteRewardPopup.ChangeTab(_tabIdx)
            end)
        end)
    elseif data.status == 2 then
        --已领取
    elseif data.status == 3 then
        --未解锁
    end
end

--界面关闭时调用（用于子类重写）
function ClimbTowerEliteRewardPopup:OnClose()  
end

--界面销毁时调用（用于子类重写）
function ClimbTowerEliteRewardPopup:OnDestroy()
    this.itemList = {}
end

return ClimbTowerEliteRewardPopup