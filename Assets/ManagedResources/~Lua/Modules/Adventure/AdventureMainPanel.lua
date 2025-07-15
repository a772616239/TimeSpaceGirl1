require("Base/BasePanel")
require("Modules/Adventure/View/AdventureView")
local AdventureMainPanel = Inherit(BasePanel)
local this = AdventureMainPanel
local goList = {}
local viewList = {}
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local RewardGroup = ConfigManager.GetConfig(ConfigName.RewardGroup)
local StoreConfig = ConfigManager.GetConfig(ConfigName.StoreConfig)
local cost = 0
local adventureConfig = ConfigManager.GetConfig(ConfigName.AdventureConfig)
local monsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
local monsterConfig = ConfigManager.GetConfig(ConfigName.MonsterConfig)
local orginLayer = 0
local isChooseOne = false
local costHourGlass = 0
local costDemonCrystal = 0
local costDemonCrystalNum = 0
local sayInfo = { GetLanguageStrById(10046), GetLanguageStrById(10047), GetLanguageStrById(10048), GetLanguageStrById(10049), GetLanguageStrById(10050) }
--初始化组件（用于子类重写）
function AdventureMainPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    this.alienInvasionBtn = Util.GetGameObject(self.gameObject, "right/alienInvasionBtn")
    this.alienInvasionRedPoint = Util.GetGameObject(self.gameObject, "right/alienInvasionBtn/redPoint")
    this.grid = Util.GetGameObject(self.gameObject, "ScrollRect/grid")
    this.item = Util.GetGameObject(self.gameObject, "item")
    this.bottom = Util.GetGameObject(self.gameObject, "bottom")
    this.attackTimesText = Util.GetGameObject(self.gameObject, "top/AttackTimesText")
    this.reward1Image = Util.GetGameObject(self.gameObject, "top/reward1Image"):GetComponent("Image")
    this.reward2Image = Util.GetGameObject(self.gameObject, "top/reward2Image"):GetComponent("Image")
    this.getRewardBtn = Util.GetGameObject(self.gameObject, "right/getRewardBtn")
    this.reward1NumberText = Util.GetGameObject(self.gameObject, "top/reward1bg/reward1NumberText"):GetComponent("Text")
    this.reward2NumberText = Util.GetGameObject(self.gameObject, "top/reward2bg/reward2NumberText"):GetComponent("Text")
    this.expeditionsBtn = Util.GetGameObject(self.gameObject, "right/expeditionsBtn")
    this.costItemImage = Util.GetGameObject(self.gameObject, "right/costItem"):GetComponent("Image")
    this.costItem= Util.GetGameObject(self.gameObject, "right/costItem")
    this.costNumerText = Util.GetGameObject(self.gameObject, "right/costItem/costNumerText"):GetComponent("Text")
    this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    this.adventureFastBattle = Util.GetGameObject(self.gameObject, "right/Text"):GetComponent("Text")
    this.sayInfoImageBg = Util.GetGameObject(self.gameObject, "ScrollRect/grid/head/sayInfoImageBg")
    this.sayInfoText = Util.GetGameObject(self.gameObject, "ScrollRect/grid/head/sayInfoImageBg/Text"):GetComponent("Text")
    this.monsterBtn = Util.GetGameObject(self.gameObject, "ScrollRect/grid/head/live2d/monsterBtn")
    this.GetAllRewardEffect = Util.GetGameObject(self.transform, "effect_yijianlingqu")
    this.hourGlassText = Util.GetGameObject(self.gameObject, "right/expeditionsBtn/hourGlassImage/hourGlassText"):GetComponent("Text")
    this.popUpView1 = Util.GetGameObject(self.gameObject, "PopUpViewTip")
    this.popUpViewBtn1 = Util.GetGameObject(self.gameObject, "PopUpViewTip/Image/fastBattleBtn")
    this.popUpViewItem1 = Util.GetGameObject(self.gameObject, "PopUpViewTip/Image/item1")
    this.popUpViewItemNumber1 = Util.GetGameObject(self.gameObject, "PopUpViewTip/Image/item1/numberText"):GetComponent("Text")
    this.popUpViewItem2 = Util.GetGameObject(self.gameObject, "PopUpViewTip/Image/item2")
    this.popUpViewItemNumber2 = Util.GetGameObject(self.gameObject, "PopUpViewTip/Image/item2/numberText"):GetComponent("Text")
    this.popUpViewBtnBack1 = Util.GetGameObject(self.gameObject, "PopUpViewTip/Image/btnBack")
    this.remainNumber = Util.GetGameObject(self.gameObject, "PopUpViewTip/Image/item1/numberText (1)"):GetComponent("Text")
    this.chooseImage1 = Util.GetGameObject(self.gameObject, "PopUpViewTip/Image/chooseImage1")
    this.chooseImage2 = Util.GetGameObject(self.gameObject, "PopUpViewTip/Image/chooseImage2")
    this.btn1 = Util.GetGameObject(self.gameObject, "PopUpViewTip/Image/btn1")
    this.btn2 = Util.GetGameObject(self.gameObject, "PopUpViewTip/Image/btn2")
    this.popUpView2 = Util.GetGameObject(self.gameObject, "PopUpViewTip2")
    this.popUpViewBtnBack2 = Util.GetGameObject(self.gameObject, "PopUpViewTip2/Image/btnBack")
    this.costItemIcon = Util.GetGameObject(self.gameObject, "PopUpViewTip2/Image/costItemIcon"):GetComponent("Image")
    this.costItemNumber = Util.GetGameObject(self.gameObject, "PopUpViewTip2/Image/costItemIcon/costNumber"):GetComponent("Text")
    this.Toggle = Util.GetGameObject(self.gameObject, "PopUpViewTip2/Image/Toggle"):GetComponent("Toggle")
    this.btnSureCost = Util.GetGameObject(self.gameObject, "PopUpViewTip2/Image/sureBtn")
    this.callMonsterBtn = Util.GetGameObject(self.gameObject, "right/callMonsterBtn")
    this.callMonsterText = Util.GetGameObject(self.gameObject, "right/callMonsterBtn/callMonsterImage/callMonsterText"):GetComponent("Text")
    this.remaindTimeText= Util.GetGameObject(self.gameObject, "right/callMonsterBtn/remaindTimeText"):GetComponent("Text")
    this.freeText=Util.GetGameObject(self.gameObject, "right/freeText"):GetComponent("Text")
    this.callMonsterRedPoint=Util.GetGameObject(self.gameObject, "right/callMonsterBtn/redPoint")
    this.expeditionRedPoint=Util.GetGameObject(self.gameObject, "right/expeditionsBtn/redPoint")

    --花费时光沙漏的次数
    this.adventureFastBattle.text = GetLanguageStrById(10051) .. AdventureManager.adventureFastBattle / 3600 .. GetLanguageStrById(10052)
    local count = AdventureManager.GetStoneFastBattleCount()
    local hasCostNumber = count + 1
    costDemonCrystal = StoreConfig[10015].Cost[2]
    costHourGlass = StoreConfig[10008].Cost[2][2]
    costDemonCrystalNum = table.nums(costDemonCrystal)
    if (hasCostNumber < costDemonCrystalNum) then
        cost = costDemonCrystal[hasCostNumber]
    else
        cost = costDemonCrystal[costDemonCrystalNum]
    end
    this.costNumerText.text = "×" .. cost .. GetLanguageStrById(10053) .. AdventureManager.fastBattlePrivilegeNumber .. GetLanguageStrById(10054)
    for i = #AdventureManager.Data, 1, -1 do
        local go1 = newObject(self.item)
        go1.name = "itemPro" .. i
        
        go1.transform:SetParent(this.grid.transform)
        go1.transform.localScale = Vector3.one
        go1.transform.localPosition = Vector3.zero
        go1:SetActive(true)
        goList[i] = go1
        local itemView = AdventureView:New(go1, i, AdventureManager.Data[i], this)
        viewList[i] = itemView
    end
    local go = newObject(self.bottom)
    go.transform:SetParent(this.grid.transform)
    go.transform.localScale = Vector3.one
    go.transform.localPosition = Vector3.zero
    go:SetActive(true)
    this.scrollRoot = Util.GetGameObject(self.gameObject, "chatroot")
    this.chatItem = Util.GetGameObject(self.gameObject, "chatroot/item")
    -- 创建循环列表
    local rootHight = this.scrollRoot.transform.rect.height
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform,
            this.chatItem, nil, Vector2.New(1080, rootHight), 1, 1, Vector2.New(0, 8))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
    -- 刷新聊天信息
    local chatList = AdventureManager.GetChatList()
    this.ScrollView:SetData(chatList, function(index, go)
        this.ChatNodeAdapter(go, chatList[index])
    end)
    --for k, v in ConfigPairs(AdventureManager.AdventureConfig) do
    --    if(this.Data[k].bossRemainTime~=-1) then
    --        this.TimeFormat(this.Data[k].bossRemainTime, k)
    --    end
    --end
    self:ShowTestLiveGO()

    local itemdata = {}
    table.insert(itemdata, StoreConfig[10015].Cost[1][1])
    table.insert(itemdata, 0)
    local view = SubUIManager.Open(SubUIConfig.ItemView, this.popUpViewItem1.transform)
    view:OnOpen(false, itemdata, 0.97)

    local itemdata = {}
    table.insert(itemdata, StoreConfig[10008].Cost[1][1])
    table.insert(itemdata, 0)
    local view = SubUIManager.Open(SubUIConfig.ItemView, this.popUpViewItem2.transform)
    view:OnOpen(false, itemdata, 0.97)

    this.costItemIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[StoreConfig[10015].Cost[1][1]].ResourceID))
    this.costItemNumber.text = "×" .. cost
end

function AdventureMainPanel:OnRefreshPopUpData()
    --探险次数不充足或妖晶不充足
    if (AdventureManager.fastBattlePrivilegeNumber == 0 or BagManager.GetItemCountById(StoreConfig[10015].Cost[1][1]) < cost or this.hourGlassNumber < costHourGlass) then
        this.popUpView1:SetActive(false)
    end
    local count = AdventureManager.GetStoneFastBattleCount()
    local hasCostNumber = count + 1
    if (hasCostNumber < costDemonCrystalNum) then
        cost = costDemonCrystal[hasCostNumber]
    else
        cost = costDemonCrystal[costDemonCrystalNum]
    end
    this.hourGlassNumber = BagManager.GetItemCountById(StoreConfig[10008].Cost[1][1])
    if (this.hourGlassNumber < costHourGlass or BagManager.GetItemCountById(StoreConfig[10015].Cost[1][1]) < cost) then
        this.popUpView1:SetActive(false)
    end
    this.popUpViewItemNumber1.text = PrintWanNum(BagManager.GetItemCountById(StoreConfig[10015].Cost[1][1])) .. "/" .. cost
    this.remainNumber.text = GetLanguageStrById(10055) .. AdventureManager.fastBattlePrivilegeNumber .. GetLanguageStrById(10056)
    this.popUpViewItemNumber2.text = PrintWanNum(BagManager.GetItemCountById(StoreConfig[10008].Cost[1][1])) .. "/" .. costHourGlass
end

function AdventureMainPanel:ShowTestLiveGO()
    --TODO:动态加载立绘
    self.preList = poolManager:LoadLive("live2d_m_syjm_0026", Util.GetTransform(self.transform, "ScrollRect/grid/head/live2d"),
            Vector3.New(0.36, 0.36, 1), Vector3.New(8, -311, 0))
end

--绑定事件（用于子类重写）
function AdventureMainPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        UIManager.OpenPanel(UIName.MainPanel)
    end)
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Adventure,this.helpPosition.x,this.helpPosition.y)
    end)
    --点击塔顶怪物
    Util.AddClick(this.monsterBtn, function()
        this.sayInfoImageBg:SetActive(false)
        this.sayInfoImageBg:SetActive(true)
        local i = math.random(1, 5)
        this.sayInfoText.text = sayInfo[i]
    end)
    --外敌入侵列表
    Util.AddClick(this.alienInvasionBtn, function()
        UIManager.OpenPanel(UIName.AdventureAlianInvasionPanel)
        -- 重置外敌红点显示
        ResetServerRedPointStatus(RedPointType.SecretTer_Boss)
    end)

    --点击召唤首领按钮
    Util.AddClick(this.callMonsterBtn, function()
        if(AdventureManager.callAlianInvasionTime>=1) then
            AdventureManager.CallAlianInvasionRequest(function()
                this:OnRefreshRedPoint()
                this.callMonsterText.text = AdventureManager.callAlianInvasionTime.."/"..AdventureManager.callAlianInvasionTotalTime
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10057)
        end
    end)
    --领取奖励
    Util.AddClick(this.getRewardBtn, function()
        if (AdventureManager.IsUnlockPickUpAll() == true) then
            local isGetAllReward = true
            for i = #AdventureManager.Data, 1, -1 do
                if (AdventureManager.Data[i].stateTime >= AdventureManager.adventureRefresh) then
                    isGetAllReward = false
                end
            end
            if (isGetAllReward) then
                PopupTipPanel.ShowTipByLanguageId(10058)
            else
                this.GetAllRewardEffect:SetActive(false)
                this.GetAllRewardEffect:SetActive(true)
                local dataTime = {}
                --CheckRedPointStatus(RedPointType.SecretTer_GetAllReward)
                for i = #AdventureManager.Data, 1, -1 do
                    dataTime[i] = AdventureManager.Data[i].stateTime
                    if (AdventureManager.Data[i].stateTime >= AdventureManager.adventureRefresh) then
                        viewList[i].hasReward:SetActive(true)
                        AdventureManager.Data[i].stateTime = 0
                    end
                end
                Util.GetGameObject(this.btnBack.transform, "btnBack"):GetComponent("Button").enabled = false
                self.timerEffect = Timer.New(function()
                    for i = #AdventureManager.Data, 1, -1 do
                        if (dataTime[i] >= AdventureManager.adventureRefresh) then
                            viewList[i].hasReward:SetActive(false)
                        end
                        self.timerEffect:Stop()
                        Util.GetGameObject(this.btnBack.transform, "btnBack"):GetComponent("Button").enabled = true
                    end
                    AdventureManager.GetAventureRewardRequest(2, -1)
                end, 1.5, -1, true)
                self.timerEffect:Start()
            end
        else
            PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.UnlockPickUp))
        end
    end)
    --急速探险
    Util.AddClick(this.expeditionsBtn, function()
        local cost = 0
        local count = AdventureManager.GetStoneFastBattleCount()
        local hasCostNumber = count + 1
        if (hasCostNumber < costDemonCrystalNum) then
            cost = costDemonCrystal[hasCostNumber]
        else
            cost = costDemonCrystal[costDemonCrystalNum]
        end

        local isGetAllReward = false
        for i = #AdventureManager.Data, 1, -1 do
            if (AdventureManager.Data[i].isAttackBoosSuccess == 1) then
                isGetAllReward = true
            end
        end

        if (isGetAllReward == false) then
            PopupTipPanel.ShowTipByLanguageId(10059)
        else
            if (AdventureManager.GetSandFastBattleCount() ~= 0) then
                isChooseOne = false
                this:ClickFastBattle()
            else
                --妖晶充足
                if (BagManager.GetItemCountById(StoreConfig[10015].Cost[1][1]) >= cost) then
                    --妖晶充足，时光沙漏充足，极速探险次数充足
                    if (this.hourGlassNumber >= costHourGlass and AdventureManager.fastBattlePrivilegeNumber ~= 0) then
                        this.chooseImage1:SetActive(isChooseOne)
                        this.chooseImage2:SetActive(not isChooseOne)
                        this.popUpView1:SetActive(true)
                        this.popUpView1:GetComponent("PlayFlyAnim"):PlayAnim(true)
                        this:OnRefreshPopUpData()
                    end
                    --妖晶充足，时光沙漏充足，极速探险次数不足
                    if (this.hourGlassNumber >= costHourGlass and AdventureManager.fastBattlePrivilegeNumber == 0) then
                        isChooseOne = false
                        this:ClickFastBattle()
                    end
                    --妖晶充足，时光沙漏不足，急速探险次数充足
                    if (this.hourGlassNumber < costHourGlass and AdventureManager.fastBattlePrivilegeNumber ~= 0) then
                        local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "isShowPopUp")
                        local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                        if (isPopUp ~= currentTime) then
                            this.popUpView2:SetActive(true)
                            this.popUpView2:GetComponent("PlayFlyAnim"):PlayAnim(true)
                            isChooseOne = true
                            this:OnRefreshPopUpData()
                        else
                            isChooseOne = true
                            this:ClickFastBattle()
                        end
                    end
                    --妖晶充足，时光沙漏不足，急速探险次数不足
                    if (this.hourGlassNumber < costHourGlass and AdventureManager.fastBattlePrivilegeNumber == 0) then
                        PopupTipPanel.ShowTipByLanguageId(10060)
                    end
                else
                    --妖晶不足,时光沙漏充足，急速探险次数充足/不充足
                    if (this.hourGlassNumber >= costHourGlass) then
                        isChooseOne = false
                        this:ClickFastBattle()
                    end
                    --妖晶不充足，时光沙漏不足，急速探险次数充足
                    if (this.hourGlassNumber < costHourGlass and AdventureManager.fastBattlePrivilegeNumber ~= 0) then
                        UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.DemonCrystal })
                    end
                    --妖晶不足,时光沙漏不充足，急速探险次数不充足
                    if (this.hourGlassNumber < costHourGlass and AdventureManager.fastBattlePrivilegeNumber == 0) then
                        PopupTipPanel.ShowTipByLanguageId(10060)
                    end
                end
            end
        end
    end)

    Util.AddClick(this.popUpViewBtn1, function()
        local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "isShowPopUp")
        local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
        --选择妖晶且当日弹板
        if (isPopUp ~= currentTime and isChooseOne) then
            this.popUpView2:SetActive(true)
            --this.popUpView2:GetComponent("PlayFlyAnim"):PlayAnim(true)
        end
        if (isChooseOne == false or isPopUp == currentTime) then
            this:ClickFastBattle()
            this:OnRefreshPopUpData()
        end
    end)
    Util.AddClick(this.btnSureCost, function()
       
        --探险次数不充足或妖晶不充足
        local isShow = this.Toggle.isOn
        if (isShow == true) then
            local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
            RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "isShowPopUp", currentTime)
        end
        isChooseOne = true
        this:ClickFastBattle()
        this.popUpView2:SetActive(false)
    end)
    Util.AddClick(this.popUpViewBtnBack1, function()
        this.popUpView1:SetActive(false)


    end)
    Util.AddClick(this.popUpViewBtnBack2, function()
        this.popUpView2:SetActive(false)


    end)
    Util.AddClick(this.btn1, function()
        this.chooseImage1:SetActive(true)
        this.chooseImage2:SetActive(false)
        isChooseOne = true
    end)
    Util.AddClick(this.btn2, function()
        this.chooseImage1:SetActive(false)
        this.chooseImage2:SetActive(true)
        isChooseOne = false
    end)

    for i = #AdventureManager.Data, 1, -1 do
        viewList[i]:Init()
    end

    -- 绑定红点
    BindRedPointObject(RedPointType.SecretTer_Boss, this.alienInvasionRedPoint)  -- 外敌boss红点（服务器红点）
end

function AdventureMainPanel:RefreshBoxRedState()
    local isGetAllReward = true
    for i = #AdventureManager.Data, 1, -1 do
        if (AdventureManager.Data[i].stateTime >= AdventureManager.adventureRefresh) then
            isGetAllReward = false
        end
    end
end

function AdventureMainPanel:ClickFastBattle()
    if (isChooseOne == false) then
        if (this.hourGlassNumber >= costHourGlass or AdventureManager.GetSandFastBattleCount() ~= 0) then
            AdventureManager.GetAventureRewardRequest(1, 0, false, true)
        else
            PopupTipPanel.ShowTipByLanguageId(10060)
        end
    else
        local cost = 0
        local count = AdventureManager.GetStoneFastBattleCount()
        local hasCostNumber = count + 1
        if (hasCostNumber < costDemonCrystalNum) then
            cost = costDemonCrystal[hasCostNumber]
        else
            cost = costDemonCrystal[costDemonCrystalNum]
        end
        if (BagManager.GetItemCountById(StoreConfig[10015].Cost[1][1]) >= cost) then
            AdventureManager.GetAventureRewardRequest(1, 1, true, true)
        else
            PopupTipPanel.ShowTipByLanguageId(10060)
        end
    end
end

function AdventureMainPanel:RefreshExpeditionsData()
    this:OnRefreshRedPoint()
    this:OnRefreshPopUpData()
    this.hourGlassNumber = BagManager.GetItemCountById(StoreConfig[10008].Cost[1][1])
    if (this.hourGlassNumber < 100) then
        this.hourGlassText.text = this.hourGlassNumber
    else
        this.hourGlassText.text = "..."
    end
    local count = AdventureManager.GetStoneFastBattleCount()
    local hasCostNumber = count + 1
    if (hasCostNumber < costDemonCrystalNum) then
        cost = costDemonCrystal[hasCostNumber]
    else
        cost = costDemonCrystal[costDemonCrystalNum]
    end
    this.costNumerText.text = "×" .. cost .. GetLanguageStrById(10053) .. AdventureManager.fastBattlePrivilegeNumber .. GetLanguageStrById(10054)
    AdventureManager.isSuccess = false
    if (AdventureManager.GetSandFastBattleCount() ~= 0) then
        this.freeText.text=GetLanguageStrById(10061)
        this.costItem:SetActive(false)
    else
        this.freeText.text=""
        this.costItem:SetActive(true)
    end
end

--添加事件监听（用于子类重写）
function AdventureMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnAreaStateChange, this.TimeFormat)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnRefreshData, this.OnRefreshData)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnRefeshBoxRewardShow, this.UpdataBoxStateShow)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnChatListChanged, this.ChatMsgUpdate)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnFastBattleChanged, this.RefreshExpeditionsData)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.MonsterSayInfo, this.MonsterSayInfo)
    Game.GlobalEvent:AddEvent(GameEvent.Guide.GuidePanelScrollViewPos, this.GuideResult)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.CallAlianInvasionTime, this.CallAlianInvasionTimeCountDown)

end

--移除事件监听（用于子类重写）
function AdventureMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnAreaStateChange, this.TimeFormat)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnRefreshData, this.OnRefreshData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnRefeshBoxRewardShow, this.UpdataBoxStateShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnChatListChanged, this.ChatMsgUpdate)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnFastBattleChanged, this.RefreshExpeditionsData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.MonsterSayInfo, this.MonsterSayInfo)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guide.GuidePanelScrollViewPos, this.GuideResult)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.CallAlianInvasionTime, this.CallAlianInvasionTimeCountDown)
end
--界面打开时调用（用于子类重写）
function AdventureMainPanel:OnOpen(...)
    -- 音效
    SoundManager.PlayMusic(SoundConfig.BGM_Adventure)
    -- 开启计时器，两秒钟刷新一次聊天信息
    --if not this._Timer then
    --    this._Timer = Timer.New(this.ChatMsgUpdate, 2, -1)
    --    this._Timer:Start()
    --end
end

function AdventureMainPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.GetAllRewardEffect, self.sortingOrder - orginLayer)
    this.popUpView2:GetComponent("Canvas").sortingOrder = self.sortingOrder + 22
    this.popUpView1:GetComponent("Canvas").sortingOrder = self.sortingOrder + 21
    orginLayer = self.sortingOrder
    for i = #AdventureManager.Data, 1, -1 do
        viewList[i]:OnSortingOrderChange()
    end
end

function AdventureMainPanel:OnShow()
    AdventureManager.isEnterAdventure=true
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.AdventureTimes })
    this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.SecretTerritoryPanel })
    this:OnRefreshData()
    this:RefreshExpeditionsData()
    this.sayInfoImageBg:SetActive(false)
    this.GetAllRewardEffect:SetActive(false)
    this.chooseImage1:SetActive(isChooseOne)
    this.chooseImage2:SetActive(not isChooseOne)
    --AdventureManager.OnFlushShowData()
    if (AdventureManager.GetSandFastBattleCount() ~= 0) then
        this.freeText.text=GetLanguageStrById(10061)
        this.costItem:SetActive(false)
    else
        this.freeText.text=""
        this.costItem:SetActive(true)
    end
    this.ChatMsgUpdate()
    this:OnRefreshRedPoint()
    --this.costItem:SetActive(true)
    CheckRedPointStatus(RedPointType.SecretTer_CallAlianInvasionTime)
    CheckRedPointStatus(RedPointType.SecretTer_Uplevel)
    CheckRedPointStatus(RedPointType.SecretTer_NewHourseOpen)
    CheckRedPointStatus(RedPointType.SecretTer_HaveFreeTime)
end

--刷新红点
 function AdventureMainPanel:OnRefreshRedPoint()
     if(AdventureManager.callAlianInvasionTime>=1) then
         this.callMonsterRedPoint:SetActive(true)
     else
         this.callMonsterRedPoint:SetActive(false)
     end
     this.hourGlassNumber = BagManager.GetItemCountById(StoreConfig[10008].Cost[1][1])
     if(AdventureManager.GetSandFastBattleCount() ~= 0 or this.hourGlassNumber>=1) then
         this.expeditionRedPoint:SetActive(true)
     else
         this.expeditionRedPoint:SetActive(false)
     end
 end



--刷新主页数据
function AdventureMainPanel:OnRefreshData()
    this.callMonsterText.text = AdventureManager.callAlianInvasionTime.."/"..AdventureManager.callAlianInvasionTotalTime
    this.grid:GetComponent("RectTransform").localPosition = Vector2.New(0, 4631.2)
    this.attackTimesText:GetComponent("Text").text = AdventureManager.canAttackBossTimes
    this.hourGlassNumber = BagManager.GetItemCountById(StoreConfig[10008].Cost[1][1])
    if (this.hourGlassNumber < 100) then
        this.hourGlassText.text = this.hourGlassNumber
    else
        this.hourGlassText.text = "..."
    end
    --if(AdventureManager.buyTimsPerDay<=4) then
    --end
    this.costItemImage.sprite = Util.LoadSprite(GetResourcePath(itemConfig[StoreConfig[10015].Cost[1][1]].ResourceID))
    this.reward1Image.sprite = Util.LoadSprite(GetResourcePath(itemConfig[AdventureManager.upShow[1][2]].ResourceID))
    this.reward2Image.sprite = Util.LoadSprite(GetResourcePath(itemConfig[AdventureManager.upShow[1][1]].ResourceID))
    this.reward1NumberAll = 0
    this.reward2NumberAll = 0
    for i = #AdventureManager.Data, 1, -1 do
        local data = AdventureManager.Data[i]
        viewList[i]:OnRefreshData()
        if (PlayerManager.level >= data.OpenLevel[1] and data.isAttackBoosSuccess == 1) then
            this.reward1NumberAll = RewardGroup[data.baseRewardGroup[1][data.areaLevel]].ShowItem[2][2] + this.reward1NumberAll
            this.reward2NumberAll = RewardGroup[data.baseRewardGroup[1][data.areaLevel]].ShowItem[1][2] + this.reward2NumberAll
        end
    end
    this.reward1NumberAll = this.reward1NumberAll + math.floor(AdventureManager.vipAddBaseGift * this.reward1NumberAll)
    this.reward2NumberAll = this.reward2NumberAll + math.floor(AdventureManager.vipAddBaseGift * this.reward2NumberAll)
    for i = #AdventureManager.Data, 1, -1 do
        local j = #AdventureManager.Data + 1 - i
        if (PlayerManager.level < AdventureManager.Data[j].OpenLevel[1]) then
            Util.GetGameObject(goList[j], "lock/unLockLevelText"):GetComponent("Text").text = AdventureManager.Data[j].OpenLevel[1] .. GetLanguageStrById(10062)
            break
        end
    end
    if (AdventureManager.vipAddBaseGift * 100 ~= 0) then
        this.reward1NumberText.text = "  ×" .. this.reward1NumberAll .. string.format("<color=#F5C66BFF>(+%s</color>", AdventureManager.vipAddBaseGift * 100) .. "<color=#F5C66BFF>%)</color>" .. GetLanguageStrById(10063)
        this.reward2NumberText.text = "  ×" .. this.reward2NumberAll .. string.format("<color=#F5C66BFF>(+%s</color>", AdventureManager.vipAddBaseGift * 100) .. "<color=#F5C66BFF>%)</color>" .. GetLanguageStrById(10063)
    else
        this.reward1NumberText.text = "  ×" .. this.reward1NumberAll .. GetLanguageStrById(10063)
        this.reward2NumberText.text = "  ×" .. this.reward2NumberAll .. GetLanguageStrById(10063)
    end
end

-- 时间格式化
function this.TimeFormat(time, k)
    local hour = 0
    local min = 0
    local sec = 0
    sec = math.floor(time % 60)
    hour = math.floor(time / 3600)
    min = 0
    if (hour >= 1) then
        min = math.floor((time - hour * 3600) / 60)
    else
        min = math.floor(time / 60)
    end
    if (time <= 0) then
        AdventureManager.Data[k].bossRemainTime = -1
        this:OnRefreshData()
    end
    Util.GetGameObject(goList[k], "haveAttackunLock/bossAppear/bossAppearCountDown"):GetComponent("Text").text = string.format("%02d:%02d:%02d",hour, min, sec)
end

--更新宝箱状态
function AdventureMainPanel.UpdataBoxStateShow(i)
    --CheckRedPointStatus(RedPointType.SecretTer_GetAllReward)
    --this.RefreshBoxRedState()
    if (AdventureManager.Data[i].stateTime >= AdventureManager.adventureBoxShow[1] and AdventureManager.Data[i].stateTime < AdventureManager.adventureBoxShow[2]) then
        viewList[i]:SetRewordBoxStatus(1, i)
    elseif (AdventureManager.Data[i].stateTime >= AdventureManager.adventureBoxShow[2]) then
        viewList[i]:SetRewordBoxStatus(2, i)
    elseif (AdventureManager.Data[i].stateTime < AdventureManager.adventureBoxShow[1] and AdventureManager.Data[i].stateTime >= AdventureManager.adventureRefresh) then
        viewList[i]:SetRewordBoxStatus(3, i)
    elseif (AdventureManager.Data[i].stateTime < AdventureManager.adventureRefresh) then
        viewList[i]:SetRewordBoxStatus(4, i)
    end
    if (AdventureManager.Data[i].stateTime >= AdventureManager.adventureOffline * 3600) then
        viewList[i]:SetRewordBoxStatus(5, i)
    end
    viewList[i]:UpdataBossShowState(i)
end

-- 聊天信息更新
function this.ChatMsgUpdate()
    -- 判断是否有新的消息显示
    if not AdventureManager.IsChatListNew then
        return
    end

    local chatList = AdventureManager.GetChatList()
    this.ScrollView:SetData(chatList, function(index, go)
        this.ChatNodeAdapter(go, chatList[index])
    end)
    -- 判断是否需要滚动到最下面
    local dataLen = #chatList
    if dataLen >= 7 then
        this.ScrollView:SetIndex(dataLen)
    end
end

-- 节点数据匹配
function this.ChatNodeAdapter(node, data)
    local name = Util.GetGameObject(node, "name")
    local content = Util.GetGameObject(node, "content")
    name:GetComponent("Text").text = data.findUserName
    --TODO:这里会区分聊天消息的类型做不同的显示，目前只有boss
    local areaName = adventureConfig[data.arenaId].AreaName
    local monsterId = monsterGroup[data.bossGroupId].Contents[1][1]
    local monsterInfo = monsterConfig[monsterId]
    local bossName = GetLanguageStrById(monsterInfo.ReadingName)
    local isCanClick=true
    for i,v in ipairs(AdventureManager.hasKilledId) do
        if(data.bossId==v) then
            content:GetComponent("Text").text =string.format(GetLanguageStrById(10064), areaName, bossName)
            isCanClick=false
        end
    end
    if(isCanClick) then
        content:GetComponent("Text").text = string.format(GetLanguageStrById(10065), areaName, bossName)
        -- 点击事件监听
        Util.AddOnceClick(content, function()
            local isCanClick=true
            for i,v in ipairs(AdventureManager.hasKilledId) do
                if(data.bossId==v) then
                    content:GetComponent("Text").text =string.format(GetLanguageStrById(10064), areaName, bossName)
                    isCanClick=false
                end
            end
            if(isCanClick) then
                UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.ADVENTURE_BOSS, data)
            end
        end)
    end
end

--界面关闭时调用（用于子类重写）
function AdventureMainPanel:OnClose()
    -- 开启计时器
    --if this._Timer then
    --    this._Timer:Stop()
    --    this._Timer = nil
    --end
end

--界面销毁时调用（用于子类重写）
function AdventureMainPanel:OnDestroy()
    poolManager:UnLoadLive(self.preList.name, self.preList)
    SubUIManager.Close(this.BtView)
    SubUIManager.Close(this.UpView)

    this.ScrollView = nil
    -- 清除红点绑定的物体
    ClearRedPointObject(RedPointType.SecretTer_Boss)
end
--怪物进行说话
function this.MonsterSayInfo(arenaId)
   
    this.grid:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 1082.807)
    local bosssName = GetLanguageStrById(monsterConfig[monsterGroup[AdventureManager.Data[arenaId].systemBoss].Contents[1][1]].ReadingName)
    this.sayInfoImageBg:SetActive(true)
    this.sayInfoText.text = GetLanguageStrById(10066) .. string.format("<color=#F5C66CFF>%s</color>", bosssName) .. GetLanguageStrById(10067) .. string.format(GetLanguageStrById(10068), AdventureManager.Data[arenaId].areaName .. AdventureManager.Data[arenaId].areaLevel)
end

function this.GuideResult()

    this.grid.transform:DOLocalMoveY(4631.2, 0.6, false):OnComplete(function()
        AdventureManager.Data[1].stateTime = AdventureManager.adventureRefresh
    end)
end
--跳转显示新手提示圈
function this.ShowGuideGo()
    JumpManager.ShowGuide(UIName.AdventureMainPanel, this.expeditionsBtn)
end
--外敌次数恢复时间倒计时
function this.CallAlianInvasionTimeCountDown(remainTime)
    local hour = 0
    local min = 0
    local sec = 0
    sec = math.floor(remainTime % 60)
    hour = math.floor(remainTime / 3600)
    min = 0
    if (hour >= 1) then
        min = math.floor((remainTime - hour * 3600) / 60)
    else
        min = math.floor(remainTime / 60)
    end
    this.remaindTimeText.text = string.format("%02d:%02d:%02d", hour, min, sec)
    if (remainTime == 0) then
        this.remaindTimeText.text = "00:00:00"
    end
    if(remainTime==AdventureManager.callAlianInvasionCountDownTime) then
        this:OnRefreshRedPoint()
        CheckRedPointStatus(RedPointType.SecretTer_CallAlianInvasionTime)
    end
    this.callMonsterText.text = AdventureManager.callAlianInvasionTime.."/"..AdventureManager.callAlianInvasionTotalTime
end

return AdventureMainPanel