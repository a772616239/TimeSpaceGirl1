require("Base/BasePanel")
LaddersMainPanel = Inherit(BasePanel)
local this = LaddersMainPanel
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local buyTime--购买次数
local freeTime--免费次数
local RankPlayerHeadList = {}--排行玩家头像列表
local RewardList = {}--奖励列表
local RewardItemList = {}--奖励道具列表
local myRewardItemList = {}--我的奖励道具列表
local sorting = 0
local TabBox = require("Modules/Common/TabBox")
local tabData = {
    [1] = {
        default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", 
        select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", 
        name = GetLanguageStrById(10334),
        title = "cn2-X1_jingjichang_tiaozhanyeqian",
        },
    [2] = {
        default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", 
        select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", 
        name = GetLanguageStrById(10131),
        title = "cn2-X1_jingjichang_paihangjiangli"
        },
    [3] = {
        default = "cn2-X1_tongyong_fenlan_weixuanzhong_02", 
        select = "cn2-X1_tongyong_fenlan_yixuanzhong_02", 
        name = GetLanguageStrById(10080),
        title = "cn2-X1_jingjichang_richangjiangli"
    }
}
local rankImg = {
    "cn2-X1_tongyong_diyi",
    "cn2-X1_tongyong_dier",
    "cn2-X1_tongyong_disan"
}

--初始化组件（用于子类重写）
function LaddersMainPanel:InitComponent()
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, this.transform, { showType = UpViewOpenType.ShowLeft})

    this.down = Util.GetGameObject(this.gameObject, "down")
    this.backBtn = Util.GetGameObject(this.down, "backBtn")

    this.content = Util.GetGameObject(this.gameObject, "content")
    -------------------------------挑战-------------------------------
    this.challengePanel = Util.GetGameObject(this.gameObject, "content/challengePanel")

    this.players = {}
    for i = 1,5 do
        local player = Util.GetGameObject(this.challengePanel, "players/player"..i)
        table.insert(this.players, player)
    end

    this.rankNum = Util.GetGameObject(this.challengePanel, "rank/num"):GetComponent("Text")
    this.costIcon = Util.GetGameObject(this.challengePanel, "cost/icon"):GetComponent("Image")
    this.costName = Util.GetGameObject(this.challengePanel, "cost/Text"):GetComponent("Text")
    this.costNum = Util.GetGameObject(this.challengePanel, "cost/num"):GetComponent("Text")

    local btns = Util.GetGameObject(this.challengePanel, "challengePanel")
    this.helpBtn = Util.GetGameObject(btns, "helpBtn")--帮助
    this.kingBtn = Util.GetGameObject(btns, "kingBtn")--巅峰排行
    this.recordBtn = Util.GetGameObject(btns, "recordBtn")--挑战记录
    this.storeBtn = Util.GetGameObject(btns, "storeBtn")--商店

    ------challengeCount
    local challengeCount = Util.GetGameObject(this.challengePanel, "challengeCount")
    this.addtBtn = Util.GetGameObject(challengeCount, "count/addtBtn")
    this.numText = Util.GetGameObject(challengeCount, "count/num"):GetComponent("Text")
    this.buyNumText = Util.GetGameObject(challengeCount, "buyCount/num"):GetComponent("Text")

    this.refreshBtn = Util.GetGameObject(this.challengePanel, "refreshBtn")--刷新
    this.allChallengeBtn = Util.GetGameObject(this.challengePanel, "allChallengeBtn")--一键挑战

    -------------------------------排行-------------------------------
    this.rankPanel = Util.GetGameObject(this.gameObject, "content/rankPanel")

    this.rankScroll = Util.GetGameObject(this.rankPanel, "scroll")
    this.rankPrefab = Util.GetGameObject(this.rankPanel, "ItemPre")
    local rankV = this.rankScroll:GetComponent("RectTransform").rect
    this.rankScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rankScroll.transform,
            this.rankPrefab, nil, Vector2.New(rankV.width, rankV.height), 1, 1, Vector2.New(0,0))
    this.rankScrollView.moveTween.MomentumAmount = 1
    this.rankScrollView.moveTween.Strength = 1

    this.myRank = Util.GetGameObject(this.rankPanel, "myRank")

    -------------------------------奖励-------------------------------
    this.rewardPanel = Util.GetGameObject(this.gameObject, "content/rewardPanel")

    this.rewardScroll = Util.GetGameObject(this.rewardPanel, "scroll")
    this.rewardPrefab = Util.GetGameObject(this.rewardPanel, "ItemPre")
    local rewardV = this.rewardScroll:GetComponent("RectTransform").rect
    this.rewardScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rewardScroll.transform,
            this.rewardPrefab, nil, Vector2.New(rewardV.width, rewardV.height), 1, 1, Vector2.New(0,0))
    this.rewardScrollView.moveTween.MomentumAmount = 1
    this.rewardScrollView.moveTween.Strength = 1

    this.myReward = Util.GetGameObject(this.rewardPanel, "myReward")
end

--绑定事件（用于子类重写）
function LaddersMainPanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        this:ClosePanel()
    end)
    --帮助
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.LaddersChallenge,
        this.helpBtn:GetComponent("RectTransform").localPosition.x + 450,
        this.helpBtn:GetComponent("RectTransform").localPosition.y + 300)
    end)
    --巅峰王者
    Util.AddClick(this.kingBtn, function()
        UIManager.OpenPanel(UIName.LaddersKingPanel)
    end)
    --挑战记录
    Util.AddClick(this.recordBtn, function()
        UIManager.OpenPanel(UIName.LaddersChallengeRecordPanel)
    end)
    --荣耀商店
    Util.AddClick(this.storeBtn, function()
        UIManager.OpenPanel(UIName.MainShopPanel, 64)
    end)
    --刷新
    Util.AddClick(this.refreshBtn, function()
        LaddersArenaManager.RequestNewArenaEnemy(function ()
            this.SetPanelData(1)
            PopupTipPanel.ShowTip(GetLanguageStrById(10088))
        end)
    end)

    --一键挑战
    Util.AddClick(this.allChallengeBtn, function()
        if LaddersArenaManager.GetStage() ~= 2 or LaddersArenaManager.Enterable() == -1 then
            PopupTipPanel.ShowTip(GetLanguageStrById(50178))
            return
        end

        --竞技场不是前一百名不让挑战
        local _, myRankInfo = ArenaManager.GetRankInfo()
        local myArenaRank = myRankInfo.personInfo.rank
        if myArenaRank > 100 or myArenaRank < 0 then
            PopupTipPanel.ShowTip(GetLanguageStrById(50301))
            return
        end

        local myRank = LaddersArenaManager.GetMyRank()
        if myRank == -1 or myRank == 9999 then
            PopupTipPanel.ShowTip(GetLanguageStrById(50166))--不可一键挑战
            return
        end
        if LaddersArenaManager.GetLeftTime() <= 0 then
            PopupTipPanel.ShowTip(GetLanguageStrById(10100))--活动已结束，不可挑战！
            return
        end
        if buyTime <= 0 and freeTime <= 0 then
            PopupTipPanel.ShowTip(GetLanguageStrById(10342))--今日剩余次数不足！
            return
        end
        if freeTime <= 0 then
            local costId, costNum = LaddersArenaManager.GetCost()
            MsgPanel.ShowTwo(string.format(GetLanguageStrById(50302),costNum), nil, function()
                local haveNum = BagManager.GetTotalItemNum(costId)
                if haveNum < costNum then
                    PopupTipPanel.ShowTip(GetLanguageStrById(10847))--所需物品不足
                    return
                end
                PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.BuyLADDERS, 1)
                LaddersArenaManager.RefreshLaddarsAckTimes(1)
                NetManager.GetWorldArenaChallengeRequest(FormationTypeDef.FORMATION_NORMAL,0,0,0,1,function (msg)
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
                        this.SetChallengeData()
                    end)
                end)
            end)
        else
            LaddersArenaManager.RefreshLaddarsAckTimes(1)
            NetManager.GetWorldArenaChallengeRequest(FormationTypeDef.FORMATION_NORMAL,0,0,0,1,function (msg)
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
                    this.SetChallengeData()
                    -- this.SetPlayerData()
                end)
            end)
        end
    end)

    --购买
    Util.AddClick(this.addtBtn, function()
        if LaddersArenaManager.GetFreeCount() <= 0 then
            local costId,costNum = LaddersArenaManager.GetCost()
            if costNum == nil then
                PopupTipPanel.ShowTip(GetLanguageStrById(10342))--今日剩余次数不足！
                return
            end
            MsgPanel.ShowTwo(string.format(GetLanguageStrById(50302),costNum), nil, function()
                local haveNum = BagManager.GetTotalItemNum(costId)
                 if haveNum < costNum then
                    PopupTipPanel.ShowTip(GetLanguageStrById(10847))
                    return
                 end
                 local storeData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.StoreConfig,"StoreId",7,"Limit",PRIVILEGE_TYPE.BuyLADDERS)--商店表数据
                 ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,storeData.Id,1,function() 
                    PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.BuyLADDERS, 1)
                    this.SetPanelData(1)
                 end)
            end)
        else
            PopupTipPanel.ShowTip(GetLanguageStrById(50303))
        end
    end)
end

--添加事件监听（用于子类重写）
function LaddersMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Ladders.RefreshItem, this.SetChallengeData)
end

--移除事件监听（用于子类重写）
function LaddersMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Ladders.RefreshItem, this.SetChallengeData)
end

--界面打开时调用（用于子类重写）
function LaddersMainPanel:OnOpen()
    this.nilData = {}
    for i = 1, 5 do
        local data = {
            personInfo = {
            uid = 10000,
            head = 0,
            headFrame = 0,
            userName = "",
            guildName = "",
            servername = "",
            name = GetLanguageStrById(50177),--虚位以待
            rank = GetLanguageStrById(50178),--每周六00:00开启
            totalForce = 0,
            }
        }
        table.insert(this.nilData, data)
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LaddersMainPanel:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.laddersChallenge})

    this.tabCtrl = TabBox.New()
    this.tabCtrl:SetTabAdapter(this.OnTabAdapter)
    this.tabCtrl:SetTabIsLockCheck(this.OnTabIsLockCheck)
    this.tabCtrl:SetChangeTabCallBack(this.OnChangeTab)
    this.tabCtrl:Init(this.down, tabData, 1)

    this.SetPanelData(1)
end

function LaddersMainPanel:OnSortingOrderChange()
    sorting = self.sortingOrder
end

--界面关闭时调用（用于子类重写）
function LaddersMainPanel:OnClose()
end
--界面销毁时调用（用于子类重写）
function LaddersMainPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    RankPlayerHeadList = {}
    RewardList = {}
    RewardItemList = {}
    myRewardItemList = {}
end

function LaddersMainPanel.OnTabAdapter(tab, index, status)
    local bg = tab:GetComponent("Image")
    local defaultTxt = Util.GetGameObject(tab, "default"):GetComponent("Text")
    local select = Util.GetGameObject(tab, "select"):GetComponent("Image")
    local selectTxt = Util.GetGameObject(tab, "select/Text"):GetComponent("Text")
    bg.sprite = Util.LoadSprite(tabData[index][status])
    defaultTxt.text = tabData[index].name
    select.sprite = Util.LoadSprite(tabData[index].title)
    selectTxt.text = tabData[index].name

    defaultTxt.gameObject:SetActive(status == "default")
    select.gameObject:SetActive(status == "select")
end

function LaddersMainPanel.OnTabIsLockCheck(index)
end

function LaddersMainPanel.OnChangeTab(index, lastIndex)
    this.ShowPanelIndex(index)
    this.SetPanelData(index)
end

--显示窗口
function LaddersMainPanel.ShowPanelIndex(index)
    for i = 1, this.content.transform.childCount do
        this.content.transform:GetChild(i - 1).gameObject:SetActive(false)
    end
    this.content.transform:GetChild(index - 1).gameObject:SetActive(true)
end

--设置窗口信息 1挑战 2排行 3奖励
function LaddersMainPanel.SetPanelData(index)
    if index == 1 then
        NetManager.GetWorldArenaInfoRequest(false,false,function(msg)
            this.SetChallengeData()
            this.SetPlayerData()
        end)
    elseif index == 2 then
        NetManager.RequestRankInfo(RANK_TYPE.LADDERSCHALLENGE, function(msg)
            --排行榜其他信息
            local dataList = msg.ranks
            this.rankScrollView:SetData(dataList, function (index, go)
                 this.SetRankData(go, dataList[index], index)
            end)

            --自身信息
            local myData = msg.myRankInfo
            this.SetMyRankData(myData)
        end)
    elseif index == 3 then
        RewardList = {}
        for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.SkyLadderReward)) do
            if configInfo.AwardsType == 1 then
                table.insert(RewardList,configInfo)
            end
        end
        this.rewardScrollView:SetData(RewardList, function (index, go)
            this.SetRewardDataShow(go, RewardList[index], index)
        end)
        local myRank = LaddersArenaManager.GetMyRank()
        --请求自身排行数据
        this.SetMyRewardData(myRank)
    end
end

--设置挑战数据
function LaddersMainPanel.SetChallengeData()
    --积分
    this.costIcon.sprite = Util.LoadSprite(GetResourcePath(ItemConfig[103].ResourceID))
    this.costName.text = GetLanguageStrById(ItemConfig[103].Name)
    this.costNum.text = BagManager.GetItemCountById(103)

    --排名
    local myRank = LaddersArenaManager.GetMyRank()
    if myRank == -1 or myRank == 9999 or myRank == nil then
        this.rankNum.text = GetLanguageStrById(10041)--未上榜
    else
        this.rankNum.text = myRank
    end

    --挑战次数
    buyTime = PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.BuyLADDERS)
    freeTime = LaddersArenaManager.GetFreeCount()
    this.numText.text = freeTime
    this.buyNumText.text = buyTime
    if freeTime <= 0 and buyTime > 0 then
        Util.SetGray(this.addtBtn,false)
    else
        Util.SetGray(this.addtBtn,true)
    end
end

--设置挑战的玩家的数据
function LaddersMainPanel.SetPlayerData()
    local enemyList = LaddersArenaManager.GetEnemyList()
    if #enemyList == 0 then
        enemyList = this.nilData
    end
    for i = 1,#enemyList do
        local player = this.players[i]
        local head = Util.GetGameObject(player, "head"):GetComponent("Image")
        local icon = Util.GetGameObject(player, "head/icon"):GetComponent("Image")
        local name = Util.GetGameObject(player, "name"):GetComponent("Text")
        local rank = Util.GetGameObject(player, "rank"):GetComponent("Text")
        local power = Util.GetGameObject(player, "power/num"):GetComponent("Text")
        local challengeBtn = Util.GetGameObject(player, "challengeBtn")

        local data = enemyList[i]
        head.sprite = GetPlayerHeadFrameSprite(data.personInfo.headFrame)
        icon.sprite = GetPlayerHeadSprite(data.personInfo.head)
        if data.personInfo.servername ~= nil and data.personInfo.servername ~= "" then
            if data.personInfo.uid < 10000 then
                name.text = string.format("[%s]%s",data.personInfo.servername, GetLanguageStrById(tonumber(data.personInfo.name))) 
            else
                name.text = string.format("[%s]%s",data.personInfo.servername, data.personInfo.name)
            end
        else
            if data.personInfo.uid < 10000 then
                name.text = GetLanguageStrById(tonumber(data.personInfo.name))
            else
                name.text = data.personInfo.name
            end
        end
        if type(data.personInfo.rank) == "number" then
            rank.text = string.format(GetLanguageStrById(50157), data.personInfo.rank)
        else--假数据
            rank.text = data.personInfo.rank
        end
        power.text = data.personInfo.totalForce

        Util.AddOnceClick(challengeBtn,function()
            -- 1未开始 2战斗阶段 3膜拜阶段  Enterable -1不可参加
            if LaddersArenaManager.GetStage() ~= 2 or LaddersArenaManager.Enterable() == -1 then
                PopupTipPanel.ShowTip(GetLanguageStrById(50178))
                return
            end

            UIManager.OpenPanel(UIName.PlayerInfoPopup, data.personInfo.uid, PLAYER_INFO_VIEW_TYPE.LADDERSARENA, data.personInfo.serverid, PlayerInfoType.CSArena, i, function ()
                -- local storeData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.StoreConfig,"StoreId",7,"Limit",PRIVILEGE_TYPE.BuyLADDERS)--商店表数据

                --无剩余次数
                if buyTime <= 0 and freeTime <= 0 then
                    PopupTipPanel.ShowTip(GetLanguageStrById(10342))
                    return
                end

                --竞技场不是前一百名不让挑战
                local _, myRankInfo = ArenaManager.GetRankInfo()
                local myArenaRank = myRankInfo.personInfo.rank
                if myArenaRank > 100 or myArenaRank < 0 then
                    PopupTipPanel.ShowTip(GetLanguageStrById(50301))
                    return
                end
    
                --检测钻石数量
                -- local itemId = storeData.Cost[1][1] --消耗道具
                -- if BagManager.GetItemCountById(itemId) < storeData.Cost[2][4] and freeTime <= 0 then
                --     PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10343),GetLanguageStrById(itemConfig[itemId].Name)))
                --     return
                -- end

                if freeTime <= 0 then
                    -- local costId, costNum = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP, storeData.Id, 1)
                    local costId,costNum = LaddersArenaManager.GetCost()
                    MsgPanel.ShowTwo(string.format(GetLanguageStrById(50302), costNum), nil, function()
                        -- ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,storeData.Id,1,function() 
                            local haveNum = BagManager.GetTotalItemNum(costId)
                            if haveNum < costNum then
                                PopupTipPanel.ShowTip(GetLanguageStrById(10847))
                                return
                            end

                            if LaddersArenaManager.GetLeftTime() > 0  then
                                PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.BuyLADDERS, 1)
                                -- 敌方数据获取
                                local EnemyList = LaddersArenaManager.GetEnemyList()
                                if EnemyList[i] then
                                    LaddersArenaManager.RequestArenaChallenge(i,0,function ()
                                        this.SetChallengeData()
                                        this.SetPlayerData()
                                    end)
                                end
                            else
                                PopupTipPanel.ShowTip(GetLanguageStrById(10100))
                            end
                        -- end)
                    end)
                else
                    if LaddersArenaManager.GetLeftTime() > 0 then
                        -- 敌方数据获取
                        local EnemyList = LaddersArenaManager.GetEnemyList()
                        if EnemyList[i] then
                            LaddersArenaManager.RequestArenaChallenge(i, 0, function ()
                                this.SetChallengeData()
                                this.SetPlayerData()
                            end)
                        end
                    else
                        PopupTipPanel.ShowTip(GetLanguageStrById(10100))
                    end
                end
            end)
        end)
    end
end

--设置排行数据
function LaddersMainPanel.SetRankData(go, data, rank)
    local head = Util.GetGameObject(go, "head")
    local name = Util.GetGameObject(go, "name"):GetComponent("Text")
    local power = Util.GetGameObject(go, "power/Text"):GetComponent("Text")
    local guild = Util.GetGameObject(go, "guild/Text"):GetComponent("Text")
    local rankImage = Util.GetGameObject(go, "rank/rank"):GetComponent("Image")
    local rankImage2 = Util.GetGameObject(go, "rank/rank2")

    rankImage.gameObject:SetActive(rank < 4)
    rankImage2:SetActive(not rankImage.gameObject.activeSelf)
    if rank < 4 then
        rankImage.sprite = Util.LoadSprite(rankImg[rank])
    else
        Util.GetGameObject(rankImage2, "Text"):GetComponent("Text").text = rank
    end

    if not RankPlayerHeadList[go] then
        RankPlayerHeadList[go] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
    end

    RankPlayerHeadList[go]:Reset()
    RankPlayerHeadList[go]:SetScale(Vector3.one * 0.6)
    RankPlayerHeadList[go]:SetHead(data.head)
    RankPlayerHeadList[go]:SetFrame(data.headFrame)
    RankPlayerHeadList[go]:SetLevel(data.level)
    RankPlayerHeadList[go]:SetUID(data.uid)
    RankPlayerHeadList[go]:SetClickedTypeId(PlayerInfoType.CSArena)

    name.text = SetRobotName(data.uid, data.userName)
    power.text = data.force
    local guildName = data.guildName
    if data.guildName == nil or data.guildName == "" then
        guildName = GetLanguageStrById(10094)
    end
    guild.text = guildName

    -- Util.AddOnceClick(head, function()
    --     UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
    -- end)
end
--设置我的排行数据
function LaddersMainPanel.SetMyRankData(data)
    local head = Util.GetGameObject(this.myRank, "head")
    local name = Util.GetGameObject(this.myRank, "name"):GetComponent("Text")
    local power = Util.GetGameObject(this.myRank, "power/Text"):GetComponent("Text")
    local guild = Util.GetGameObject(this.myRank, "guild/Text"):GetComponent("Text")
    local score = Util.GetGameObject(this.myRank, "score/Text"):GetComponent("Text")
    local rankImage = Util.GetGameObject(this.myRank, "rank/rank"):GetComponent("Image")
    local rankImage2 = Util.GetGameObject(this.myRank, "rank/rank2")

    rankImage.gameObject:SetActive(data.rank < 4 and data.rank > 0)
    rankImage2:SetActive(not rankImage.gameObject.activeSelf)
    if data.rank < 4 and data.rank > 0 then
        rankImage.sprite = Util.LoadSprite(rankImg[data.rank])
    else
        local str
        if data.rank <= 0 or data.rank == 9999 then
            str = GetLanguageStrById(10041)
        else
            str = data.rank
        end
        Util.GetGameObject(rankImage2, "Text"):GetComponent("Text").text = str
    end

    local playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
    playerHead:Reset()
    playerHead:SetScale(Vector3.one * 0.6)
    playerHead:SetHead(PlayerManager.head)
    playerHead:SetFrame(PlayerManager.frame)
    playerHead:SetLevel(PlayerManager.level)

    name.text = PlayerManager.nickName
    power.text = data.param1
    if MyGuildManager.MyGuildInfo then
        guild.text = MyGuildManager.MyGuildInfo.name
    else
        guild.text = GetLanguageStrById(10094)
    end
    score.text = LaddersArenaManager.GetMaxRank()
end

--设置奖励信息
function LaddersMainPanel.SetRewardDataShow(go, data, rank)
    local rankImage = Util.GetGameObject(go, "rank/rank"):GetComponent("Image")
    local rankTxt = Util.GetGameObject(go, "rank/rank2"):GetComponent("Text")
    local content = Util.GetGameObject(go, "content")

    rankImage.gameObject:SetActive(rank < 4)
    rankTxt.gameObject:SetActive(not rankImage.gameObject.activeSelf)
    if rank < 4 then
        rankImage.sprite = Util.LoadSprite(rankImg[rank])
    else
        local str = "+"
        if data.Max > 1 then
            str = "-" .. data.Max
        end
        rankTxt.text = data.Min .. str
    end

    if not RewardItemList[go.name] then
        RewardItemList[go.name] = {}
    end
    for i = 1, #RewardItemList[go.name] do
        RewardItemList[go.name][i].gameObject:SetActive(false)
    end
    for i = 1, #data.RankAwards do
        if RewardItemList[go.name][i] then
            RewardItemList[go.name][i]:OnOpen(false, data.RankAwards[i], 0.6, false, false, false, sorting)
        else
            RewardItemList[go.name][i] = SubUIManager.Open(SubUIConfig.ItemView, content.transform)
            RewardItemList[go.name][i]:OnOpen(false, data.RankAwards[i], 0.6, false, false, false, sorting)
        end
        RewardItemList[go.name][i].gameObject:SetActive(true)
    end
end
--设置我的奖励信息
function LaddersMainPanel.SetMyRewardData(myRank)
    local rankImage = Util.GetGameObject(this.myReward, "rank/rank"):GetComponent("Image")
    local rankTxt = Util.GetGameObject(this.myReward, "rank/Text"):GetComponent("Text")
    local content = Util.GetGameObject(this.myReward, "content")

    if myRank == nil then myRank = -1 end
    if myRank < 4 and myRank > 0 then
        rankImage.gameObject:SetActive(true)
        rankTxt.gameObject:SetActive(false)
        rankImage.sprite = Util.LoadSprite(rankImg[myRank])
    else
        rankImage.gameObject:SetActive(false)
        rankTxt.gameObject:SetActive(true)
        rankTxt.text = (myRank > 0 and myRank ~= 9999) and myRank or GetLanguageStrById(10041)
    end

    local myRewardConfig = nil
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.SkyLadderReward)) do
        if configInfo.AwardsType == 1 then
            table.insert(RewardList,configInfo)
            if not myRewardConfig and myRank <= configInfo.Max and myRank >= configInfo.Min then
                myRewardConfig = configInfo
            end
        end
    end
    if not myRewardConfig then
        myRewardConfig = RewardList[#RewardList]
    end
    -- 我自己的排名展示
    for i = 1, #myRewardItemList do
        myRewardItemList[i].gameObject:SetActive(false)
    end
    for i = 1, #myRewardConfig.RankAwards do
        if myRewardItemList[i] then
            myRewardItemList[i]:OnOpen(false, myRewardConfig.RankAwards[i], 0.55,false,false,false,sorting)
        else
            myRewardItemList[i] = SubUIManager.Open(SubUIConfig.ItemView, content.transform)
            myRewardItemList[i]:OnOpen(false, myRewardConfig.RankAwards[i], 0.55,false,false,false,sorting)
        end
        myRewardItemList[i].gameObject:SetActive(true)
    end
end

return LaddersMainPanel