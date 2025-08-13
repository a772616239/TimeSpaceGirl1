require("Base/BasePanel")
RewardItemPopup = Inherit(BasePanel)
local this = RewardItemPopup
local userLevelData = ConfigManager.GetConfig(ConfigName.PlayerLevelConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local itemListPrefab
local func
local bagType = 0   --1 正常背包  2 临时背包 3 梦魇入侵显示
--需要显示的小组件类型
-- 1 -- 界面显示升级
-- 2 -- 显示地图自由探索按钮
local compShowType = 0
local sortingOrder = 0
local callList = Stack.New()
local isPopGetSSR = false
local isOpenGeiSSRAvtivity = 0--五星成长礼拍脸
local isOpenGeiSSRAvtivityTime
local isPlayerAniEnd = true
local itemDataList
local showHero = 1  --是否展示英雄
local leftPlayerHeadList
local rightPlayerHeadList
local fightType
local autoFightTotalTime = 4
local autoFightCurTime = autoFightTotalTime
local isFirst = true
local getExp--获取的经验

--初始化组件（用于子类重写）
function RewardItemPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    --
    this.ScrollView = Util.GetGameObject(self.gameObject, "Content/ScrollView")
    this.ScrollView:SetActive(false)
    this.dropGrid = Util.GetGameObject(self.gameObject, "Content/ScrollView/Viewport/Content")
    itemListPrefab = {}
    for i = 1, 10 do --初始缓存10个
        local view = SubUIManager.Open(SubUIConfig.ItemView, this.dropGrid.transform)
        view.gameObject.name = "frame"..i
        itemListPrefab[i] = view
    end

    --关卡等级经验
    this.lvAndExp = Util.GetGameObject(self.gameObject, "Content/PlayerInfo/lvAndExp")
    this.lvAndExp:SetActive(false)
    this.lv = Util.GetGameObject(this.lvAndExp, "lv"):GetComponent("Text")
    this.exp = Util.GetGameObject(this.lvAndExp, "exp"):GetComponent("Slider")
    this.expText = Util.GetGameObject(this.lvAndExp, "exp/Text"):GetComponent("Text")
    this.lvUpImage = Util.GetGameObject(this.lvAndExp, "lvUpImage")
    this.headicon = Util.GetGameObject(this.lvAndExp, "headPart/headicon"):GetComponent("Image")
    this.headframe = Util.GetGameObject(this.lvAndExp, "headPart/headframe"):GetComponent("Image")
    -- 地图探索按钮
    this.btnMapExplore = Util.GetGameObject(self.gameObject, "Content/PlayerInfo/mapExplore")
    -- 伤害统计按钮
    this.btnResult = Util.GetGameObject(self.gameObject, "btnResult")

    --自动
    this.automatic = Util.GetGameObject(self.gameObject, "Automatic")
    this.nextStage = Util.GetGameObject(this.automatic, "nextStage")
    this.nextStageTime = Util.GetGameObject(this.automatic, "Time"):GetComponent("Text")
    this.toggle = Util.GetGameObject(this.automatic, "Toggle"):GetComponent("Toggle")

    --标题
    this.titleBg = Util.GetGameObject(self.gameObject, "title")
    this.title = Util.GetGameObject(self.gameObject, "title/title")

    --梦魇入侵显示
    this.guildCarDelay = Util.GetGameObject(self.gameObject, "Content/PlayerInfo/guildCarDelay")
    this.guildCarDelaysoreNum = Util.GetGameObject(this.guildCarDelay, "soreNum"):GetComponent("Text")
    this.guildCarDelayhurtNum = Util.GetGameObject(this.guildCarDelay, "hurtNum"):GetComponent("Text")

    --公会十绝阵显示
    this.guildDeathPos = Util.GetGameObject(self.gameObject,"Content/PlayerInfo/guildDeathPos")
    this.guildDeathPos_CurScore = Util.GetGameObject(this.guildDeathPos,"curScore/num"):GetComponent("Text")
    this.guildDeathPos_State = Util.GetGameObject(this.guildDeathPos,"curScore/state"):GetComponent("Image")
    this.guildDeathPos_MaxScore = Util.GetGameObject(this.guildDeathPos,"maxScore/num"):GetComponent("Text")
    --大闹天宫
    this.expedition = Util.GetGameObject(self.gameObject,"Content/PlayerInfo/expedition")

    --三强争霸显示
    this.hegemony = Util.GetGameObject(self.gameObject,"Content/PlayerInfo/hegemony")
    this.hegemonyTitle = Util.GetGameObject(this.hegemony,"title"):GetComponent("Image")
    this.prop1_name = Util.GetGameObject(this.hegemony,"prop/prop1_name"):GetComponent("Text")
    this.prop2_name = Util.GetGameObject(this.hegemony,"prop/prop2_name"):GetComponent("Text")
    this.prop1_Value = Util.GetGameObject(this.hegemony,"prop/prop1_Value"):GetComponent("Text")
    this.prop2_Value = Util.GetGameObject(this.hegemony,"prop/prop2_Value"):GetComponent("Text")

    --跨服竞技场
    this.laddersChallenge = Util.GetGameObject(self.gameObject,"Content/PlayerInfo/laddersChallenge")
    this.laddersLeftIcon = Util.GetGameObject(this.laddersChallenge,"leftIcon")
    this.laddersRightIcon = Util.GetGameObject(this.laddersChallenge,"rightIcon")

end

--绑定事件（用于子类重写）
function RewardItemPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        if isPlayerAniEnd then
            PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
            if (MapManager.curCarbonType == CarBonTypeId.TRIAL and #MapManager.allOnClickEvent > 0 and MapManager.isAutoJian) or
            (MapManager.curCarbonType == CarBonTypeId.TRIAL and #MapManager.buffOnClickEvent > 0 and MapManager.isAutoJian) then
                Game.GlobalEvent:DispatchEvent(GameEvent.YiDuan.AutoGetBaoXiang)
            end
            self:ClosePanel()
        elseif #itemDataList < 1 then
            self:ClosePanel()
        end
    end)
    Util.AddClick(this.btnMapExplore, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnResult, function ()
        UIManager.OpenPanel(UIName.DamageResultPanel, 1)
        if this.TimeCounter~=nil then
            this.TimeCounter:Stop()
        end
        this.nextStageTime.gameObject:SetActive(false)
    end)

    Util.AddClick(this.nextStage, function ()
        if PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.AutoNextFight) then
            -- 关闭自动战斗计时器
            RewardItemPopup.EndTimeDown()
            if this.ExcuteNext then
                return
            end
            if isFirst then
                isFirst = false
                this.NextStageClick()
            end
        else
            PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.AutoNextFight))
        end
    end)
end

--添加事件监听（用于子类重写）
function RewardItemPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.DefenseTrainingPopup.RefreshBtnClick, this.RefreshBtnClick)
end

--移除事件监听（用于子类重写）
function RewardItemPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.DefenseTrainingPopup.RefreshBtnClick, this.RefreshBtnClick)
end

function this.RefreshBtnClick()
    isFirst = true
    this.ExcuteNext = false
end

--界面打开时调用（用于子类重写）
--@1 drop 后端掉落原始数据
--@2 bagType 1.正常背包 2.地图临时背包
--@3 func 回调
--@4 需要显示的小组件类型 1.界面显示升级 2.显示地图自由探索按钮
--@5 伤害统计
--@6 设置背景遮罩的显隐
--@7 是否展示英雄
--@8 控制标题和背景板显示
--@9 对应三强争霸位置id(特殊)
--@10 战斗类型
function RewardItemPopup:OnOpen(...)
    isFirst = true
    if fightType == BATTLE_TYPE.DefenseTraining then
        if #itemDataList <= 0 then
            isPlayerAniEnd = true
        else
            isPlayerAniEnd = false
        end
    else
        isPlayerAniEnd = true
    end
    isOpenGeiSSRAvtivity = 0
    sortingOrder = self.sortingOrder

    local args = {...}
    local drop = args[1]
    bagType = args[2]
    func = args[3]

    if args[4] then
        compShowType = args[4]
    end
    local isRecord = args[5]
    -- 设置背景遮罩的显隐
    local isHideBg = args[6]
    if args[7] then
        showHero = false
    else
        showHero = true
    end

    --控制标题和背景板显示
    if args[8] ~= nil then
        this.title:SetActive(args[8])
    else
        this.title:SetActive(true)
    end
    this.hegemony:SetActive(compShowType == 7)
    if compShowType == 7 then
        this.title:SetActive(true)
        this:SetHegemonyData(args[9])
    end

    -- 战斗类型 仅用于直接下一关战斗
    if args[10] ~= nil then
        fightType = args[10]
    else
        fightType = nil
    end

    this.ExcuteNext = false
    local isAutoBegin = false
    if fightType and ((AppConst.isGuide and not GuideManager.IsInMainGuide()) or (not AppConst.isGuide)) then
        this.automatic:SetActive(true)
        if PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.AutoNextFight) then
            Util.SetGray(this.nextStage, false)
            Util.SetGray(this.toggle.gameObject, false)
            this.toggle.enabled = true
            this.nextStageTime.gameObject:SetActive(false)

            if fightType == BATTLE_TYPE.Climb_Tower then
                if ClimbTowerManager.curFightId >= 1300 then--写死
                    this.automatic:SetActive(false)
                end
            elseif fightType == BATTLE_TYPE.Climb_Tower_Advance then
                if ClimbTowerManager.curFightId_Advance >= 500 then
                    this.automatic:SetActive(false)
                end
            elseif fightType == BATTLE_TYPE.DefenseTraining then
            elseif fightType == BATTLE_TYPE.STORY_FIGHT then
            end

            this.nextStageTime.text = GetLanguageStrById(50323)
            local isAutoNext = PlayerPrefs.GetInt("Fight_Auto_Next", 1)
            this.toggle.isOn = isAutoNext == 1 and true or false
            if this.toggle.isOn and this.automatic.activeSelf and isAutoNext == 1 then
                RewardItemPopup.BeginTimeDown()
                isAutoBegin = true
            end

            this.toggle.onValueChanged:AddListener(function(state)
                if state then
                    PlayerPrefs.SetInt("Fight_Auto_Next", 1)
                    RewardItemPopup.BeginTimeDown()
                else
                    PlayerPrefs.SetInt("Fight_Auto_Next", 0)
                    RewardItemPopup.EndTimeDown()
                end
            end)
        else
            Util.SetGray(this.nextStage, true)
            Util.SetGray(this.toggle.gameObject, true)
            this.toggle.enabled = false
            this.nextStageTime.text = GetLanguageStrById(50323)
            this.nextStageTime.gameObject:SetActive(true)
            this.nextStageTime.text = PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.AutoNextFight)
        end
    else
        this.automatic:SetActive(false)
    end
    if fightType == BATTLE_TYPE.GUILD_CAR_DELAY or fightType == BATTLE_TYPE.DEATH_POS then
        Util.GetGameObject(this.title, "Text"):GetComponent("Text").text = GetLanguageStrById(50239)
        this.automatic:SetActive(false)
    else
        Util.GetGameObject(this.title, "Text"):GetComponent("Text").text = GetLanguageStrById(50240)
    end
    local haveRecord = BattleRecordManager.isHaveRecord()
    this.btnResult:SetActive(haveRecord and isRecord)

    if not drop then
        this:NightmareInvasionShow()
        this.guildCarDelay:SetActive(compShowType == 3)
        for i = 1, #itemListPrefab do
            itemListPrefab[i].gameObject:SetActive(false)
        end
        return
    end
    this.expedition:SetActive(compShowType == 5)
    this.guildDeathPos:SetActive(compShowType == 4)

    if compShowType == 4 then
        this:GuildDeathPosShow()
    elseif compShowType == 8 then
        this:SetLaddersData()
    end

    this:SetDrop(drop)
    
    --没有数据直接关闭界面
    if #itemDataList <= 0 and fightType ~= BATTLE_TYPE.DefenseTraining then
        self:ClosePanel()
        return
    end

    --获得奖励数量超过10个做界面适应拖动
    if #itemDataList > 10 then
        this.dropGrid:GetComponent("ContentSizeFitter").verticalFit = 2--UnityEngine.UI.ContentSizeFitter.FitMode.PreferredSize
    else
        this.dropGrid:GetComponent("ContentSizeFitter").verticalFit = 0--UnityEngine.UI.ContentSizeFitter.FitMode.Unconstrained
        local x = this.dropGrid:GetComponent("RectTransform").sizeDelta.x
        this.dropGrid:GetComponent("RectTransform").sizeDelta = Vector2.New(x, 420)
    end

    this.SetComPShowState(compShowType)

    -- 预制体高于生成参数的时候只开 预生成的 10个
    for i = 1,math.min(#itemDataList,10) do
        itemListPrefab[i].gameObject:SetActive(true)
    end

    if #itemDataList < 1 then
        if fightType == BATTLE_TYPE.DefenseTraining then
            this.title:SetActive(false)
            this.ScrollView:SetActive(false)
            this.titleBg:SetActive(false)
            this.btnBack:GetComponent("Image").color = Color.New(0,0,0,1/255)
        end

        this:SelectCanPopUpBagMaxMessage()
    else
        this.titleBg:SetActive(true)
        this.btnBack:GetComponent("Image").color = Color.New(0,0,0,180/255)

        this:SetItemShow(drop)
    end
    SoundManager.PlaySound(SoundConfig.Sound_Reward)
    this:ShowLvAndExp()
    this:SelectCanPopUpBagMaxMessage()

    if compShowType == 1 then
        compShowType = 0
        if FightPointPassManager.oldLevel < PlayerManager.level then
            local isHave = ActTimeCtrlManager.CheckIsHaveFuncGuideByLv(PlayerManager.level)
            -- 有功能引导剧情 结束自动下一关
            if isAutoBegin then
                RewardItemPopup.EndTimeDown()
            end
            UIManager.OpenPanel(UIName.FightEndLvUpPanel,FightPointPassManager.oldLevel,PlayerManager.level,function ()
                if isHave then
                    self:ClosePanel()
                    func()
                else
                    if isAutoBegin then
                        RewardItemPopup.BeginTimeDown()
                    end
                end
            end)

            if  this.toggle.isOn and isHave==false and PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.AutoNextFight) then
                RewardItemPopup.BeginTimeDown()
            end
        end
    end
end

--界面关闭时调用（用于子类重写）
function RewardItemPopup:OnClose()
    RewardItemPopup.EndTimeDown()
    this.ScrollView:SetActive(false)
    this.lvAndExp:SetActive(false)
    local fightConFigData = ConfigManager.GetConfigData(ConfigName.MainLevelConfig, FightPointPassManager.curOpenFight)
    -- if compShowType == 1 then
    --     compShowType = 0
    --     if FightPointPassManager.oldLevel<PlayerManager.level then
    --         if fightConFigData and fightConFigData.PicShow == 1 and FightPointPassManager.isOpenNewChapter  then
    --             UIManager.OpenPanel(UIName.FightEndLvUpPanel,FightPointPassManager.oldLevel,PlayerManager.level,function ()
    --                 func()
    --             end)
    --         else
    --             UIManager.OpenPanel(UIName.FightEndLvUpPanel,FightPointPassManager.oldLevel,PlayerManager.level,func)
    --         end
    --         return
    --     end
    -- end

    for i = 1, #itemListPrefab do
        itemListPrefab[i].gameObject:SetActive(false)
    end

    compShowType = 0
    if func and not isPopGetSSR then
        if fightConFigData and fightConFigData.PicShow == 1 and FightPointPassManager.isOpenNewChapter  then
            func()
        else
            func()
        end
    end

    -- 展示完以后结束章节解锁状态
    FightPointPassManager.isOpenNewChapter = false
    if isOpenGeiSSRAvtivityTime then
        isOpenGeiSSRAvtivityTime:Stop()
        isOpenGeiSSRAvtivityTime = nil
    end
    --检测是否需要弹每日任务飘窗
    TaskManager.RefreshShowDailyMissionTipPanel()

    --防止弹两个奖励面板导致界面无法关闭
    if UIManager.IsOpen(UIName.BattleBestPopup) then
        UIManager.ClosePanel(UIName.BattleBestPopup)
    end
    if UIManager.IsOpen(UIName.BattleWinPopup) then
        UIManager.ClosePanel(UIName.BattleWinPopup)
    end
    if UIManager.IsOpen(UIName.BattleFailPopup) then
        UIManager.ClosePanel(UIName.BattleFailPopup)
    end

    this.ExcuteNext = false
end

--界面销毁时调用（用于子类重写）
function RewardItemPopup:OnDestroy()
    leftPlayerHeadList = nil
    rightPlayerHeadList = nil

    itemListPrefab = {}
end

--一些元素的显隐
function RewardItemPopup.SetComPShowState(type)
    this.btnBack:GetComponent("Button").enabled = type ~= 2
    this.ScrollView:SetActive(type ~= 7)
    this.lvAndExp:SetActive(type == 1)
    this.btnMapExplore:SetActive(type == 2)
    this.guildCarDelay:SetActive(type == 3)
    this.guildDeathPos:SetActive(type == 4)
    this.title:SetActive(type == 6 or type == 0 or type == 4)
    this.laddersChallenge:SetActive(type == 8)
end

--获得道具的处理
function RewardItemPopup:SetDrop(drop)
    local starItemDataList = BagManager.GetItemListFromTempBag(drop)
    --做装备叠加特殊组拼数据
    local equips = {}
    for i = 1, #starItemDataList do
        this.SetItemData(starItemDataList[i])
        if starItemDataList[i].itemType == 2 or starItemDataList[i].itemType == 6 then--装备叠加
            if equips[starItemDataList[i].sId] then
                equips[starItemDataList[i].sId].num = equips[starItemDataList[i].sId].num + 1
            else
                equips[starItemDataList[i].sId] = starItemDataList[i]
                equips[starItemDataList[i].sId].num = 1
            end
        end
    end
    itemDataList = {}
    for i, v in pairs(equips) do
        table.insert(itemDataList, v)
    end
    for i, v in pairs(starItemDataList) do
        if starItemDataList[i].itemType ~= 2 and starItemDataList[i].itemType ~= 6 then
            table.insert(itemDataList, v)
        end
    end
end

--梦魇入侵伤害展示
function RewardItemPopup:NightmareInvasionShow()
    if GuildCarDelayManager.score and GuildCarDelayManager.hurt then
        -- this.guildCarDelaysoreNum.text = GuildCarDelayManager.score
        this.guildCarDelayhurtNum.text = GetLanguageStrById(10730) ..":" ..GuildCarDelayManager.hurt
    end
end

--公会战 挑战奖励掉落弹窗表现
function RewardItemPopup:GuildDeathPosShow()
    if GuildBattleManager.damage and GuildBattleManager.historyMax then
        this.guildDeathPos_CurScore.text = GuildBattleManager.damage
        this.guildDeathPos_MaxScore.text = GuildBattleManager.historyMax

        local state = GuildBattleManager.damage > GuildBattleManager.historyMax or GuildBattleManager.damage < GuildBattleManager.historyMax
        this.guildDeathPos_State.gameObject:SetActive(state)
        if GuildBattleManager.damage > GuildBattleManager.historyMax then
            this.guildDeathPos_State.sprite = Util.LoadSprite("cn2-X1_tongyong_shangjiantou")
        elseif GuildBattleManager.damage < GuildBattleManager.historyMax then
            this.guildDeathPos_State.sprite = Util.LoadSprite("cn2-X1_tongyong_xiajiantou")
        end
    end
end

--当前背包是否已满
function RewardItemPopup:SelectCanPopUpBagMaxMessage()
    if IndicationManager.canPopUpBagMaxMessage then
        PopupTipPanel.ShowTip(GetLanguageStrById(11590))
        IndicationManager.canPopUpBagMaxMessage = false
    elseif IndicationManager.getRewardFromMailMessage then
        PopupTipPanel.ShowTip(GetLanguageStrById(11591))
        IndicationManager.getRewardFromMailMessage = false
    end
end

function RewardItemPopup:OnSortingOrderChange()
    if not itemDataList then
        return
    end
    for i = 1, #itemListPrefab do
        local view = itemListPrefab[i]
        local curItemData = itemDataList[i]
        view:OnOpen(true, curItemData, 0.7, false, true, false, self.sortingOrder)
    end
end

-- 根据物品列表数据显示物品
function RewardItemPopup:SetItemShow(drop)
    BagManager.OnShowTipDropNumZero(drop)
    if drop == nil then return end
    for i = 1, #itemDataList do
        itemDataList[i].itemConfig = itemConfig[itemDataList[i].sId]
    end
    self:ItemDataListSort(itemDataList)
    for i = 1, math.max(#itemDataList, #itemListPrefab) do
        local go = itemListPrefab[i]
        if not go then
            go = SubUIManager.Open(SubUIConfig.ItemView, this.dropGrid.transform)
            go.gameObject.name = "frame"..i
            itemListPrefab[i] = go
        end
        go.gameObject:SetActive(false)
    end

    callList:Clear()
    callList:Push(function ()
        if isOpenGeiSSRAvtivityTime then
            isOpenGeiSSRAvtivityTime:Stop()
            isOpenGeiSSRAvtivityTime = nil
        end
        isOpenGeiSSRAvtivityTime = Timer.New(function ()
            isPlayerAniEnd = true
            if isOpenGeiSSRAvtivity > 0 then
                HeroManager.DetectionOpenFiveStarActivity(isOpenGeiSSRAvtivity)
            end
        end, 0.5):Start()
        -- 在关卡界面获得装备 刷新下btview成员红点
        -- Game.GlobalEvent:DispatchEvent(GameEvent.Equip.EquipChange)
    end)
    for i = #itemDataList, 1, -1 do
        isPlayerAniEnd = false
        local view = itemListPrefab[i]
        local curItemData = itemDataList[i]
        view:OnOpen(true, curItemData, 0.7, false, true, false, self.sortingOrder)
        --经验
        if curItemData.sId == 17 then
            getExp = curItemData.num
        end
        --view.gameObject:SetActive(false)
        callList:Push(function ()
            local func = function()
                view.gameObject:SetActive(true)
                local btn = Util.GetGameObject(view.gameObject, "item/frame"):GetComponent("Button")
                btn.enabled = false
                PlayUIAnim(view.gameObject, function()
                    btn.enabled = true
                end)
                --改为后端更新
                -- this.SetItemData(itemDataList[i])
                Timer.New(function ()
                    isPopGetSSR = false
                    callList:Pop()()
                end, 0.05):Start()
            end
            if curItemData.configData and curItemData.itemType == 3 and curItemData.configData.Quality == 5 and showHero then
                func()
            elseif curItemData.configData and curItemData.itemType == 1 and
                    (curItemData.configData.ItemType == ItemType.Title or curItemData.configData.ItemType == ItemType.Ride or
                            curItemData.configData.ItemType == ItemType.Skin) then--皮肤 坐骑
                isPopGetSSR = true
                UIManager.OpenPanel(UIName.DropGetPlayerDecorateShopPanel,curItemData.backData, func)
            else
                func()
            end
        end)
    end
    callList:Pop()()
end

--存储本地
function RewardItemPopup.SetItemData(itemdata)
    if itemdata.itemType == 1 then
       --后端更新
    elseif itemdata.itemType == 2 then
        if bagType == 1 then
            EquipManager.UpdateEquipData(itemdata.backData)
        elseif bagType == 2 then
            EquipManager.InitMapShotTimeEquipBagData(itemdata.backData)
        end
    elseif itemdata.itemType == 3 then
        if bagType == 1 then
            HeroManager.UpdateHeroDatas(itemdata.backData,true)
        elseif bagType == 2 then
            HeroManager.InitMapShotTimeHeroBagData(itemdata.backData)
        end
    elseif itemdata.itemType == 4 then
        if bagType == 1 then
            TalismanManager.InitUpdateSingleTalismanData(itemdata.backData)
        elseif bagType == 2 then
            TalismanManager.InitMapShotTimeTalismanBagData(itemdata.backData)
        end
    elseif itemdata.itemType == 5 then
        if bagType == 1 then
            --SoulPrintManager.InitServerData(itemdata.data)
            EquipTreasureManager.InitSingleTreasureData(itemdata.backData)
        elseif bagType == 2 then
            --SoulPrintManager.InitMapShotTimeSoulPrintBagData(itemdata.backData)
            --SoulPrintManager.StoreData(itemdata.data)
        end
    elseif itemdata.itemType == 6 then
        if bagType == 1 then
            CombatPlanManager.UpdateSinglePlanData(itemdata.backData)
        end
    elseif itemdata.itemType == 7 then
        if bagType == 1 then
            MedalManager.AddMedal(itemdata.backData)
        end
    elseif itemdata.itemType == 8 then
        if bagType == 1 then
            AircraftCarrierManager.UpdateSkillData(itemdata.backData)
        end
    elseif itemdata.itemType == 9 then
        if bagType == 1 then
            Game.GlobalEvent:DispatchEvent(GameEvent.Title.RefreshTitleShowEvevt)
        end
    end
end

--关卡通关掉落时展示经验等级信息
function RewardItemPopup:ShowLvAndExp()
    if compShowType == 1 then
        this.title:SetActive(true)

        if getExp then
            local oldExp = PlayerManager.exp - getExp
            DoTween.To(DG.Tweening.Core.DOGetter_int(function()
                return 0
            end),DG.Tweening.Core.DOSetter_int(function(progress)
                this.exp.value = (oldExp + progress)/userLevelData[PlayerManager.level].Exp
                this.expText.text = (oldExp + progress).."/"..userLevelData[PlayerManager.level].Exp
            end), getExp, 0.7):SetEase(Ease.Linear)
            :OnComplete(function()
            end)
        end

        this.lv.text = PlayerManager.level
        this.lvUpImage:SetActive(FightPointPassManager.oldLevel<PlayerManager.level)
        this.headicon.sprite = GetPlayerHeadSprite(PlayerManager.head)
        this.headframe.sprite = GetPlayerHeadFrameSprite(PlayerManager.frame)
    end
end

--掉落物品排序
function RewardItemPopup:ItemDataListSort(itemDataList)
    table.sort(itemDataList, function(a, b)
        if a.itemConfig.Quantity == b.itemConfig.Quantity then
            if a.itemConfig.ItemType == b.itemConfig.ItemType then
               return a.itemConfig.Id < b.itemConfig.Id
            else
                return a.itemConfig.ItemType < b.itemConfig.ItemType
            end
        else
           return a.itemConfig.Quantity > b.itemConfig.Quantity
        end
    end)
end

--开始倒计时
function RewardItemPopup.BeginTimeDown()
    autoFightCurTime = autoFightTotalTime+1
    if not this.TimeCounter then
        this.TimeCounter = Timer.New(RewardItemPopup.TimeDown, 1, -1, true)
        this.TimeCounter:Start()
        RewardItemPopup.TimeDown()
    end
end

--继续挑战倒计时
function RewardItemPopup.TimeDown()
    this.nextStageTime.gameObject:SetActive(true)
   

    autoFightCurTime = autoFightCurTime - 1

    this.nextStageTime.text = string.format(GetLanguageStrById(50015),autoFightCurTime)

        if autoFightCurTime <= 1 then
            RewardItemPopup.NextStageClick()
            if autoFightCurTime <= 0 then
                RewardItemPopup.EndTimeDown()
            return
        end
        return
    end
end

--倒计时结束
function RewardItemPopup.EndTimeDown()
    this.nextStageTime.text = ""
    autoFightCurTime = autoFightTotalTime
    if this.TimeCounter then
        this.TimeCounter:Stop()
        this.TimeCounter = nil
    end
    UIManager.ClosePanel(UIName.FightEndLvUpPanel)
end

this.ExcuteNext = false
--继续挑战点击
function RewardItemPopup.NextStageClick()
    if this.ExcuteNext then return end
    if fightType == BATTLE_TYPE.Climb_Tower then
        local function funcFight()
            if BattlePanel then
                BattlePanel:ClosePanel()
            end
            this.ExcuteNext = true
            ClimbTowerManager.curFightId = ClimbTowerManager.curFightId + 1
            ClimbTowerManager.ExecuteFight(ClimbTowerManager.curFightId, function()
                if FormationPanelV2 then
                    FormationPanelV2:ClosePanel()
                end
                if RewardItemPopup then
                    RewardItemPopup:ClosePanel()
                end
            end)
        end
        if ClimbTowerManager.fightId == ClimbTowerManager.curFightId + 1 then --< 最新关 不消耗
            funcFight()
        else
            if ClimbTowerManager.GetCount(ClimbTowerManager.ClimbTowerType.Normal) > 0 then
                funcFight()
            else
                PopupTipPanel.ShowTip(GetLanguageStrById(11048))
                this.ExcuteNext = false
                isFirst = true
                return
            end
        end

    elseif fightType == BATTLE_TYPE.Climb_Tower_Advance then
        local function funcFight()
            if BattlePanel then
                BattlePanel:ClosePanel()
            end
            this.ExcuteNext = true
            ClimbTowerManager.curFightId_Advance = ClimbTowerManager.curFightId_Advance + 1
            ClimbTowerManager.ExecuteFightAdvance(ClimbTowerManager.curFightId_Advance, function()
                if FormationPanelV2 then
                    FormationPanelV2:ClosePanel()
                end
                if RewardItemPopup then
                    RewardItemPopup:ClosePanel()
                end
            end, false)
        end
        if ClimbTowerManager.fightId_Advance == ClimbTowerManager.curFightId_Advance + 1 then --< 最新关 不消耗
            funcFight()
        else
            if ClimbTowerManager.GetCount(ClimbTowerManager.ClimbTowerType.Advance) > 0 then
                funcFight()
            else
                PopupTipPanel.ShowTip(GetLanguageStrById(11048))
                this.ExcuteNext = false
                isFirst = true
                return
            end
        end
    elseif fightType == BATTLE_TYPE.DefenseTraining then
        FormationManager.curFormationIndex = FormationTypeDef.DEFENSE_TRAINING
        this.ExcuteNext = true
        DefenseTrainingManager.ExecuteFightBefore()
    elseif fightType == BATTLE_TYPE.STORY_FIGHT then
        FormationManager.curFormationIndex = FormationTypeDef.FORMATION_NORMAL
        this.ExcuteNext = true
        FightPointPassManager.ExecuteFightBattleBefore()
        local isPass = FightPointPassManager.IsCanFight(FightPointPassManager.curOpenFight)
        if isPass == false then
            this.RefreshBtnClick()
        end
    end
end

--三强争霸奖励
function RewardItemPopup:SetHegemonyData(fightId)
    local SupremacyConfig = ConfigManager.GetConfig(ConfigName.SupremacyConfig)
    local data = SupremacyConfig[fightId].Prop

    this.hegemonyTitle.sprite = Util.LoadSprite(SupremacyConfig[fightId].Title)
    this.prop1_name.text = GetLanguageStrById(PropertyConfig[data[1][1]].Info)
    this.prop2_name.text = GetLanguageStrById(PropertyConfig[data[2][1]].Info)
    this.prop1_Value.text = GetPropertyFormatStr(data[1][1],data[1][2])
    this.prop2_Value.text = GetPropertyFormatStr(data[2][1],data[2][2])
end

--跨服竞技场
function RewardItemPopup:SetLaddersData()
    local res = LaddersArenaManager.GetGightResult()
    local LeftName = Util.GetGameObject(this.laddersLeftIcon,"name")
    local LeftFlag = Util.GetGameObject(this.laddersLeftIcon,"flag")
    local LeftFlagScore = Util.GetGameObject(this.laddersLeftIcon,"flag/score")
    local LeftIntegral = Util.GetGameObject(this.laddersLeftIcon,"integral")

    local RightName = Util.GetGameObject(this.laddersRightIcon,"name")
    local RightFlag = Util.GetGameObject(this.laddersRightIcon,"flag")
    local RightFlagScore = Util.GetGameObject(this.laddersRightIcon,"flag/score")
    local RightIntegral = Util.GetGameObject(this.laddersRightIcon,"integral")

    --攻方
    if not leftPlayerHeadList then
        leftPlayerHeadList = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.laddersLeftIcon.transform)
    end
    leftPlayerHeadList:Reset()
    leftPlayerHeadList:SetScale(Vector3.one * 0.65)
    leftPlayerHeadList:SetHead(PlayerManager.head)
    leftPlayerHeadList:SetFrame(PlayerManager.frame)

    local oldRank = LaddersArenaManager.GetMyRank()
    if oldRank == 9999 then
        oldRank = 1000
    end

    local newScore = LaddersArenaManager.newScore 
    local score = oldRank-newScore

    if score > 0 then
        --排名上升
        LeftFlag:SetActive(true)
        LeftFlag:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_shangjiantou")
    elseif score == 0 then
        LeftFlag:SetActive(false)
    else
        --排名下降
        LeftFlag:SetActive(true)
        LeftFlag:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_xiajiantou")
        score = -score
    end
    LeftName:GetComponent("Text").text = PlayerManager.nickName
    if res == 0 then
        LeftIntegral:GetComponent("Text").text = GetLanguageStrById(12394)..LaddersArenaManager.GetMyRank()
    else
        LeftIntegral:GetComponent("Text").text = GetLanguageStrById(12394)..oldRank
    end
    LeftFlagScore:GetComponent("Text").text = LaddersArenaManager.newScore 

    --守方
    local defchange = LaddersArenaManager.defchange
    local data = LaddersArenaManager.enemy
    if not rightPlayerHeadList then
        rightPlayerHeadList = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.laddersRightIcon.transform)
    end
    rightPlayerHeadList:Reset()
    rightPlayerHeadList:SetScale(Vector3.one * 0.65)
    rightPlayerHeadList:SetHead(data.personInfo.head)
    rightPlayerHeadList:SetFrame(data.personInfo.headFrame)

    if defchange > 0 then
        --排名上升
        RightFlag:SetActive(true)
        RightFlag:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_shangjiantou")
    elseif defchange == 0 then
        RightFlag:SetActive(false)
    else
        --排名下降
        RightFlag:SetActive(true)
        RightFlag:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_xiajiantou")
        defchange = -defchange
    end

    if data.personInfo.uid < 10000 then
        RightName:GetComponent("Text").text = GetLanguageStrById(tonumber(data.personInfo.name))
    else
        RightName:GetComponent("Text").text = data.personInfo.name
    end
    
    local enemyScore = data.personInfo.rank
    RightIntegral:GetComponent("Text").text = GetLanguageStrById(12394)..enemyScore
    RightFlagScore:GetComponent("Text").text = data.personInfo.rank-LaddersArenaManager.defchange

    if res == 0 then
        LeftFlag:SetActive(false)
        RightFlag:SetActive(false)
    else
        -- if LaddersArenaManager.GetMyRank() == 9999 then
        --     LeftFlag:SetActive(false)
        --     RightFlag:SetActive(false)
        -- else
            LeftFlag:SetActive(true)
            RightFlag:SetActive(true)
        -- end
    end
    --this.hegemonyTitle.sprite=Util.LoadSprite(SupremacyConfig[fightId].Title)
end

return RewardItemPopup