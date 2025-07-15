require("Base/BasePanel")
XuanYuanMirrorPanelList = Inherit(BasePanel)
local raceTowerConfig = ConfigManager.GetConfig(ConfigName.RaceTowerConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local this = XuanYuanMirrorPanelList
local hasFresh = false
local orginLayer = 0
local specialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local costNum = 0
local storeData = {}
local mirrors = {
    [1] = {--机械
        id = GetLanguageStrById(12715),
        bg = 10006,
        tip = GetLanguageStrById(12711),
        color = Color.New(104/255,209/255,252/255,255/255),
        title = GetLanguageStrById(23153)
    },
    [2] = {--体术
        id = GetLanguageStrById(12716),
        bg = 10020,
        tip = GetLanguageStrById(12712),
        color = Color.New(77/255,170/255,134/255,255/255),
        title = GetLanguageStrById(23150)
    },
    [3] = {--魔法
        id = GetLanguageStrById(12717),
        bg = 10037,
        tip = GetLanguageStrById(12710),
        color = Color.New(254/255,111/255,110/255,255/255),
        title = GetLanguageStrById(23151)
    },
    [4] = {--秩序
        id = GetLanguageStrById(12718),
        bg = 10057,
        tip = GetLanguageStrById(12714),
        color = Color.New(249/255,206/255,94/255,255/255),
        title = GetLanguageStrById(23152)
    },
    [5] = {--混沌
        id = GetLanguageStrById(12719),
        bg = 10082,
        tip = GetLanguageStrById(12713),
        color = Color.New(204/255,119/255,255/255,255/255),
        title = GetLanguageStrById(23154)
    }
}
local curType = 0
local dataList = {}
local list = {}
local colorText = {-- 0未解锁 1挑战 2扫荡
    sprite = {[0] = "", [1] = "", [2] = ""},
    color = {[0] = "", [1] = "", [2] = ""},
    text = {[0] = GetLanguageStrById(10339), [1] = GetLanguageStrById(10334), [2] = GetLanguageStrById(10336)}
}

--初始化组件（用于子类重写）
function this:InitComponent()
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)
    this.remainTimesTip = Util.GetGameObject(self.gameObject, "Panel/tip/remainTimesTip"):GetComponent("Text")
    this.vipTips = Util.GetGameObject(self.gameObject, "Panel/tip/vipTips"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(self.gameObject, "Panel/BackBtn")

    this.levelPre = Util.GetGameObject(self.gameObject, "Pre")
    local v21 = Util.GetGameObject(self.gameObject, "Panel/Scroll"):GetComponent("RectTransform").rect
    this.ScrollView =
        SubUIManager.Open(
        SubUIConfig.ScrollCycleView,
        Util.GetGameObject(self.gameObject, "Panel/Scroll").transform,
        this.levelPre,
        nil,
        Vector2.New(v21.width, v21.height),
        1,
        1,
        Vector2.New(0,5)
    )
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.prefab = Util.GetGameObject(self.gameObject, "ItemView")
    this.live = Util.GetGameObject(self.gameObject, "cut/Image")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    Util.AddClick(
        this.btnBack,
        function()
            this:ClosePanel()
        end
    )
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnXuanYuanFunctionChange, this.RefreshPanel)
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.NextDayRefresh, this.UpdateCount)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.FunctionCtrl.OnXuanYuanFunctionChange, this.RefreshPanel)
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.NextDayRefresh, this.UpdateCount)
end
function this.UpdateCount()
    this.remainTimesTip.text = XuanYuanMirrorManager.GetTimeTip()
end

this.RefreshPanel = function()
    local data = XuanYuanMirrorManager.GetMirroData(curType)
    if data.passId == 0 or XuanYuanMirrorManager.GetMirrorState(curType) ~= 1 then
        if data.passId == 0 then
            PopupTipPanel.ShowTip(mirrors[curType].id .. GetLanguageStrById(12734))
        elseif XuanYuanMirrorManager.GetMirrorState(curType) ~= 1 then
            PopupTipPanel.ShowTip(mirrors[curType].id .. GetLanguageStrById(12735))
        end
        this:OnClose()
        UIManager.OpenPanel(UIName.XuanYuanMirrorPanel)
    else
        this:OnShow()
    end
end

function this:OnOpen(_type)
    this.UpView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main})
    curType = _type
    XuanYuanMirrorManager.curType = curType
end

function this:SwitchView()
    local tankName = Util.GetGameObject(self.gameObject,"titleName"):GetComponent("Text")
    local bg = Util.GetGameObject(self.gameObject, "cut"):GetComponent("Image")
    local title = Util.GetGameObject(self.gameObject, "title"):GetComponent("Text")
    title.text = mirrors[curType].title

    if this.liveObg then
        UnLoadHerolive(heroConfig[mirrors[curType].bg],this.liveObj)
        Util.ClearChild(this.live.transform)
        this.liveObj = nil
    end
    this.liveObg = LoadHerolive(heroConfig[mirrors[curType].bg],this.live.transform)

    bg.color = mirrors[curType].color
    tankName.text = mirrors[curType].id
    Util.GetGameObject(self.gameObject, "titleText"):GetComponent("Text").text = mirrors[curType].tip

    local itemList = {}
    this.ScrollView:SetData(
        dataList,
        function(index, go)
            this:SetLevelData(go, dataList[index],index)
            table.insert(list, go)
            itemList[index] = go
        end
    )
    DelayCreation(itemList)
    local t = 1
    for k,v in ipairs(dataList) do
        if v.state == 1 then 
            t = k
            break
        end
    end
    this.ScrollView:SetIndex(t - 1 < 1 and 1 or (t - 1))
end

function this:NewItemView(config, gameObject, ...)
    local view = reimport(config.script)
    if gameObject then
        this:playUIAnimsOnStart(gameObject)
    end
    local sub = view:New(gameObject)
    sub.assetName = config.assetName
    if sub.Awake then
        sub:Awake()
    end
    if sub.InitComponent then
        sub:InitComponent()
    end
    if sub.BindEvent then
        sub:BindEvent()
    end
    if sub.AddListener then
        sub:AddListener()
    end
    if sub.Update then
        UpdateBeat:Add(sub.Update, sub)
    end
    if sub.OnOpen then
        sub:OnOpen(...)
    end
    return sub
end

function this:playUIAnimsOnStart(gameObject)
    local anims = gameObject:GetComponentsInChildren(typeof(PlayFlyAnim))
    if anims.Length > 0 then
        for i = 0, anims.Length - 1 do
            local anim = anims[i]
            if anim.isPlayOnOpen then
                anim:PlayAnim(false)
            end
        end
    end
end

function this:SetLevelData(go, data,index)
    local grade = Util.GetGameObject(go,"Text"):GetComponent("Text")
    grade.text = index
    local btnFight = Util.GetGameObject(go, "btnFight")
    Util.GetGameObject(btnFight, "Text"):GetComponent("Text").text = colorText.text[data.state]
    local costIcon = Util.GetGameObject(btnFight, "Icon"):GetComponent("Image")
    local costNumText = Util.GetGameObject(btnFight, "IconNum"):GetComponent("Text")
    local cost = Util.GetGameObject(btnFight, "Image")
    cost:SetActive(false)

    local tip = Util.GetGameObject(go, "Tip"):GetComponent("Text")  
    tip.gameObject:SetActive(true)

    local itemId = storeData.Cost[1][1] --消耗道具

    if data.state == 0 then
        Util.SetGray(btnFight, true)
        tip.gameObject:SetActive(false)
    else
        Util.SetGray(btnFight, false)
        if data.state == 1 then
            tip.text = data.condition
        else
            tip.text = GetLanguageStrById(10337)
        end
        if XuanYuanMirrorManager.freeTime < 1 then
            cost:SetActive(true)
            costIcon.sprite = SetIcon(itemId)
            if BagManager.GetItemCountById(itemId) < costNum then
                costNumText.text = costNum
            else
                costNumText.text = costNum
            end
        end 
    end

    Util.AddOnceClick(btnFight,function()
        if data.state == 0 or BattleManager.IsInBackBattle() then
            PopupTipPanel.ShowTipByLanguageId(10339)
        else
            --检测剩余次数
            if XuanYuanMirrorManager.buyTime <= 0 and XuanYuanMirrorManager.freeTime <= 0 then
                PopupTipPanel.ShowTipByLanguageId(10342)
                return
            end

            if BagManager.GetItemCountById(itemId) < costNum and XuanYuanMirrorManager.freeTime <= 0 then
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10343), GetLanguageStrById(itemConfig[itemId].Name)))
                return
            end
            if data.state == 2 then
                if XuanYuanMirrorManager.freeTime <= 0 then
                    ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,storeData.Id,1,function()
                        PrivilegeManager.RefreshPrivilegeUsedTimes(XuanYuanMirrorManager.buyTimeId, 1)       
                    end)
                end
                XuanYuanMirrorManager.ExecuteFightBattle(data.id,2,function()
                    PrivilegeManager.RefreshPrivilegeUsedTimes(XuanYuanMirrorManager.freeTimeId, 1)
                    CheckRedPointStatus(RedPointType.People_Mirror)
                    this:OnShow()
                end)
            elseif data.state == 1 then
                if XuanYuanMirrorManager.freeTime <= 0 then
                    UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.AlameinBuy,function()
                        ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,storeData.Id,1,function()
                            PrivilegeManager.RefreshPrivilegeUsedTimes(XuanYuanMirrorManager.buyTimeId, 1)                    
                        end)
                        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.XUANYUAN_MIRROR, curType, data)
                    end, 16, string.format(GetLanguageStrById(50271),costNum))
                else
                    UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.XUANYUAN_MIRROR, curType+1, data)
                end
            end
        end
    end)
    local rewardGrid = Util.GetGameObject(go, "Reward")
    local rewards = {}
    for i = 1, rewardGrid.transform.childCount do
        rewardGrid.transform:GetChild(i - 1).gameObject:SetActive(false)
        table.insert(rewards, rewardGrid.transform:GetChild(i - 1))
    end
    for n, m in ipairs(data.rewardList) do
        if m then
            --设置概率掉落奖励
            if m.israte == 0 then           --< 应该进不去 改为只有1 2 类型了  扫荡和首通
                --设置扫荡掉落奖励
                if not rewards[n] then
                    rewards[n] = newObjToParent(this.prefab, rewardGrid)
                end
                rewards[n].gameObject:SetActive(true)
                local o = this:NewItemView(SubUIConfig.ItemView, rewards[n])
                o:OnOpen(false, {m.id, m.num}, 0.7, false)
            elseif data.state == 2 and m.israte == 1 then
                --设置未开启和挑战掉落奖励
                if not rewards[n] then
                    rewards[n] = newObjToParent(this.prefab, rewardGrid)
                end
                rewards[n].gameObject:SetActive(true)
                local o = this:NewItemView(SubUIConfig.ItemView, rewards[n])
                o:OnOpen(false, {m.id, m.num}, 0.7, false)
            elseif (data.state == 1 or data.state == 0) and m.israte == 2 then
                if not rewards[n] then
                    rewards[n] = newObjToParent(this.prefab, rewardGrid)
                end
                rewards[n].gameObject:SetActive(true)
                local o = this:NewItemView(SubUIConfig.ItemView, rewards[n])
                o:OnOpen(false, {m.id, m.num}, 0.7, false, nil, nil, nil, ItemCornerType.FirstPass)
            end
        end
    end
end

--界面打开时调用（用于子类重写）
function this:OnShow(...)
    dataList = XuanYuanMirrorManager.GetMirrorLevelData(curType)
    this:RefreshTimes()
    local buyTimeId = XuanYuanMirrorManager.buyTimeId
    storeData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.StoreConfig, "StoreId", 7, "Limit", buyTimeId)
     --商店表数据
    local buyTimes = (PrivilegeManager.GetPrivilegeUsedTimes(buyTimeId) + 1) > PrivilegeManager.GetPrivilegeNumber(buyTimeId) 
    and PrivilegeManager.GetPrivilegeNumber(buyTimeId) or (PrivilegeManager.GetPrivilegeUsedTimes(buyTimeId) + 1)
    costNum = storeData.Cost[2][buyTimes]
    this:SwitchView()

    if XuanYuanMirrorPanel then
        XuanYuanMirrorPanel.UpdateCount()
    end
end

--界面打开时调用（用于子类重写）
function this:RefreshTimes()
    this.remainTimesTip.text = XuanYuanMirrorManager.GetTimeTip()
    if XuanYuanMirrorManager.GetBuyTimesTip() then
        this.vipTips.gameObject:SetActive(false)
    else
        this.vipTips.gameObject:SetActive(true)
        this.vipTips.text = GetLanguageStrById(11696)
        Util.AddOnceClick(
            Util.GetGameObject(this.vipTips.gameObject, "GameObject"),
            function()
                UIManager.OpenPanel(UIName.MainRechargePanel, 4)
            end
        )
    end
end

function this:OnSortingOrderChange()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    if this.liveObg then
        UnLoadHerolive(heroConfig[mirrors[curType].bg],this.liveObj)
        Util.ClearChild(this.live.transform)
        this.liveObj = nil
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    SubUIManager.Close(this.UpView)
    this.ScrollView = nil
end

return XuanYuanMirrorPanelList