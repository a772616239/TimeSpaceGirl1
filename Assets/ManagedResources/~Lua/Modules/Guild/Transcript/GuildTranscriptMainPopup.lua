require("Base/BasePanel")
GuildTranscriptMainPopup = Inherit(BasePanel)
local this = GuildTranscriptMainPopup
local guildCheckpointConfig = ConfigManager.GetConfig(ConfigName.GuildCheckpointConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local cutOpenIndex = 0
local monsterData
local cutOpenIndexConFig
local cutOpenIndexMonsterConFig
local itemList = {}--优化itemView使用
local sorting = 0
local curBuyIndex = 0
local oldSelceParent

--初始化组件（用于子类重写）
function GuildTranscriptMainPopup:InitComponent()
    --btn
    this.endNumBtn = Util.GetGameObject(self.gameObject,"bg/upPanel/endNumBtn")

    this.helpBtn = Util.GetGameObject(self.gameObject,"bg/HelpBtn")
    this.helpPos = this.helpBtn:GetComponent("RectTransform").localPosition

    this.rankBun = Util.GetGameObject(self.gameObject,"bg/rankBun")

    this.sendBtn = Util.GetGameObject(self.gameObject,"bg/sendBtn")

    this.backBtn = Util.GetGameObject(self.gameObject, "bg/downPanel/btnBack")
    this.quickWarbtn = Util.GetGameObject(self.gameObject,"bg/downPanel/quickWarbtn")
    this.warbtn = Util.GetGameObject(self.gameObject,"bg/downPanel/warbtn")

    this.attackInfoBtn = Util.GetGameObject(self.gameObject,"bg/upPanel/attackInfo")
    this.attackInfoText = Util.GetGameObject(this.attackInfoBtn,"attackInfoText/Text"):GetComponent("Text")--全军团成员攻击力+16%
    this.attackInfoTime = Util.GetGameObject(this.attackInfoBtn,"attackInfoTime"):GetComponent("Text")--（08:52:24后失效）
    this.attackInfoTextGo = Util.GetGameObject(this.attackInfoBtn,"attackInfoText")
    this.attackInfoTimeGO = Util.GetGameObject(this.attackInfoBtn,"attackInfoTime")

    this.endNumText = Util.GetGameObject(this.endNumBtn,"endNumText/Text"):GetComponent("Text")
    this.endNumBuyText = Util.GetGameObject(this.endNumBtn,"endNumBuyText/Text"):GetComponent("Text")
    
    --boss
    this.boss = Util.GetGameObject(self.gameObject,"bg/boss")
    this.bossHerolive = Util.GetGameObject(this.boss, "Mask/icon"):GetComponent("Image")

    this.bossHerohpPass = Util.GetGameObject(self.gameObject,"bg/hpbg/hpPass"):GetComponent("Image")
    this.bossHerohpPassText = Util.GetGameObject(self.gameObject,"bg/hpbg/hpText"):GetComponent("Text")

    --titlechapter
    this.SelectImage = Util.GetGameObject(self.gameObject, "bg/upChapterGo/SelectImage")
    local v2 = Util.GetGameObject(self.gameObject, "upChapterGo/upChapter"):GetComponent("RectTransform").rect
    this.titleScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "upChapterGo/upChapter").transform,
        Util.GetGameObject(self.gameObject, "upChapterGo/singleChapterPre"), nil, Vector2.New(v2.width, v2.height), 2, 1, Vector2.New(5,0))
    this.titleScrollView.moveTween.MomentumAmount = 1
    this.titleScrollView.moveTween.Strength = 1
    this.titleScrollView.transform:GetComponent("RectMask2D").enabled = false

    this.reward1 = Util.GetGameObject(self.gameObject, "bg/rewardGo/reward1")
    this.reward2 = Util.GetGameObject(self.gameObject, "bg/rewardGo/reward2")
    this.Empty = Util.GetGameObject(self.gameObject, "bg/rank/Empty")

    --rank
    this.rankList = Util.GetGameObject(self.gameObject, "bg/rank/rankList")
    this.ItemPre = Util.GetGameObject(self.gameObject, "bg/rank/ItemPre")
    local rect = this.rankList:GetComponent("RectTransform").rect
    this.rankScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,  this.rankList.transform,
        this.ItemPre, nil, Vector2.New(rect.width, rect.height), 1, 1, Vector2.New(0,0))
    this.rankScrollView.moveTween.MomentumAmount = 1
    this.rankScrollView.moveTween.Strength = 1

end
--绑定事件（用于子类重写）
function GuildTranscriptMainPopup:BindEvent()
    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.GuildTranscripe, this.helpPos.x, this.helpPos.y+400)
    end)
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.warbtn,function()
        if GuildTranscriptManager.GetCanBattleCount() <= 0 then --今日已无剩余次数！
            if GuildTranscriptManager.GetCanBuyBattleCount() <= 0 then
                PopupTipPanel.ShowTipByLanguageId(10342)
            else--是否花费XX妖晶购买1次挑战次数并发起挑战？
                local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP, GuildTranscriptManager.shopGoodId, 1)
                local itemName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,costId).Name)
                if finalNum > BagManager.GetItemCountById(costId) then
                    PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11652),itemName))
                    return
                end

                UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.AlameinBuy,function()
                    ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,GuildTranscriptManager.shopGoodId,1,function()
                        PopupTipPanel.ShowTipByLanguageId(12328) 
                        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.GUILD_TRANSCRIPT,monsterData)
                        PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BUY_BATTLENUM, 1)--更新特权
                        this.ShowEndNumInfo()
                    end)
                end,16,string.format(GetLanguageStrById(12721),finalNum,itemName))

                -- MsgPanel.ShowTwo(string.format(GetLanguageStrById(12721),finalNum,itemName), nil, function()
                --     --买东西
                --     ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,GuildTranscriptManager.shopGoodId,1,function()
                --         PopupTipPanel.ShowTipByLanguageId(12328) 
                --         UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.GUILD_TRANSCRIPT,monsterData)
                --         PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BUY_BATTLENUM, 1)--更新特权
                --         this.ShowEndNumInfo()
                --     end)
                -- end)
            end
        else
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.GUILD_TRANSCRIPT,monsterData)
        end
    end)
    Util.AddClick(this.quickWarbtn,function()
        if GuildTranscriptManager.GetCanBattleCount() <= 0 then --今日已无剩余次数！
            if GuildTranscriptManager.GetCanBuyBattleCount() <= 0 then
                PopupTipPanel.ShowTipByLanguageId(10342)
            else--是否花费XX妖晶购买1次挑战次数并发起挑战？
                local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP, GuildTranscriptManager.shopGoodId, 1)
                local itemName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,costId).Name)
                if finalNum > BagManager.GetItemCountById(costId) then
                    PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11652),itemName))
                    return
                end

                UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.AlameinBuy,function()
                    ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,GuildTranscriptManager.shopGoodId,1,function()
                        PopupTipPanel.ShowTipByLanguageId(12330) 
                        PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BUY_BATTLENUM, 1)--更新特权
                        this.QuickWar()
                        this.ShowEndNumInfo()
                    end)
                end,16,string.format(GetLanguageStrById(12329),finalNum,itemName,GuildTranscriptManager.damage))

                -- --是否花费XX妖晶购买1次扫荡次数，本次扫荡伤害为XXXXXX
                -- MsgPanel.ShowTwo(string.format(GetLanguageStrById(12329),finalNum,itemName,GuildTranscriptManager.damage), nil, function()
                -- --买东西
                --     ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,GuildTranscriptManager.shopGoodId,1,function()
                --         PopupTipPanel.ShowTipByLanguageId(12330) 
                --         PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BUY_BATTLENUM, 1)--更新特权
                --         this.QuickWar()
                --         this.ShowEndNumInfo()
                --     end)
                -- end)
            end
        else
            -- UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.AlameinBuy,function()
            --     this.QuickWar()
            -- end,16,string.format(GetLanguageStrById(12331),GuildTranscriptManager.damage))

            MsgPanel.ShowTwo(string.format(GetLanguageStrById(12331),GuildTranscriptManager.damage), nil, function()
                this.QuickWar()
            end)
        end
    end)
    Util.AddClick(this.endNumBtn,function()
        local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP, GuildTranscriptManager.shopGoodId, 1)
        local itemName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,costId).Name)
        if finalNum > BagManager.GetItemCountById(costId) then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11652),GetLanguageStrById(itemName)) ) 
            return
        end
        if GuildTranscriptManager.GetCanBuyBattleCount() <= 0 then
            PopupTipPanel.ShowTipByLanguageId(11705)
            return
        end

        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.AlameinBuy,function()
            ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,GuildTranscriptManager.shopGoodId,1,function()
                PopupTipPanel.ShowTipByLanguageId(12328) 
                PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BUY_BATTLENUM, 1)--更新特权
                this.ShowEndNumInfo()
            end)
        end,16,string.format(GetLanguageStrById(12332),finalNum,GetLanguageStrById(itemName)))

        -- MsgPanel.ShowTwo(string.format( GetLanguageStrById(12332),finalNum,GetLanguageStrById(itemName)), nil, function()
        --     --买东西
        --     ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP,GuildTranscriptManager.shopGoodId,1,function()
        --         PopupTipPanel.ShowTipByLanguageId(12328) 
        --         PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BUY_BATTLENUM, 1)--更新特权
        --         this.ShowEndNumInfo()
        --     end)
        -- end)
    end)
    Util.AddClick(this.rankBun,function()
        UIManager.OpenPanel(UIName.GuildTranscriptRewardSortPanel,cutOpenIndex)
    end)
    Util.AddClick(this.sendBtn,function()
        local pos = MyGuildManager.GetMyPositionInGuild()
        if pos == GUILD_GRANT.MEMBER then
            PopupTipPanel.ShowTipByLanguageId(12333)
            return
        end
        if  cutOpenIndex ~= GuildTranscriptManager.GetCurBoss() then
            PopupTipPanel.ShowTipByLanguageId(12334)
            return
        end
         NetManager.GuildChallengeMessageResponse(function (msg)  
            local second = msg.nextTime - PlayerManager.serverTime
             if second <= 0 then
                 ChatManager.RequestSendGuildTranscript(function()
                 end)
                PopupTipPanel.ShowTipByLanguageId(12610)
             else
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12335),TimeToMS(second)))
             end
         end)
    end)
    Util.AddClick(this.attackInfoBtn,function()
        local curguildCheckpointConfig = guildCheckpointConfig[GuildTranscriptManager.GetCurBoss()]
        local nextBuyIndex = curBuyIndex + 1
        local itemId = curguildCheckpointConfig.AttributePromotePrice[1][1]
        local buyNum = curguildCheckpointConfig.AttributePromotePrice[2][nextBuyIndex]
        local itemName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,itemId).Name)
        if not buyNum then
            PopupTipPanel.ShowTipByLanguageId(12336)
            return
        end
        if buyNum > BagManager.GetItemCountById(itemId) then
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11652),GetLanguageStrById(itemName)) ) 
            return
        end
        if curguildCheckpointConfig.AttributePromotePrice[2][nextBuyIndex] then
            local addNum = ConfigManager.GetConfigData(ConfigName.FoodsConfig,curguildCheckpointConfig.AttributePromote[nextBuyIndex]).EffectPara
            -- MsgPanel.ShowTwo(string.format(GetLanguageStrById(12337),buyNum,itemName,math.floor(addNum[1][2]/100) ).."%", nil, function()
            --     --买东西
            --     NetManager.GuildChallengeBuyBuffRequest()
            -- end)

            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.AlameinBuy,function()
                NetManager.GuildChallengeBuyBuffRequest()
            end,16,string.format(GetLanguageStrById(12337),buyNum,itemName,math.floor(addNum[1][2]/100) ).."%")
        else
            PopupTipPanel.ShowTipByLanguageId(12338)
        end
    end)
end
function GuildTranscriptMainPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshGuildTranscript, this.ShowPanelData)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshGuildTranscriptBuff, this.ShowBuffData)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshGuildTranscripQuickBtn, this.ShowQuickBtnData)
end

--移除事件监听（用于子类重写）
function GuildTranscriptMainPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshGuildTranscript, this.ShowPanelData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshGuildTranscriptBuff, this.ShowBuffData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshGuildTranscripQuickBtn, this.ShowQuickBtnData)
end

--界面打开时调用（用于子类重写）
function GuildTranscriptMainPopup:OnOpen(_curIndex)
    GuildTranscriptManager.GetGuildChallengeInfoRequest()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildTranscriptMainPopup:OnShow()
    this.ShowBossInfo()
    this.ShowEndNumInfo()
end
function this.ShowPanelData()
    cutOpenIndex = GuildTranscriptManager.GetCurBoss()
    this.ShowTitleChapterInfo()
    this.ShowPanelInfo(cutOpenIndex)
end
function GuildTranscriptMainPopup:OnSortingOrderChange()
    for i, v in pairs(itemList) do
        for j = 1, #v do
            v[j]:SetEffectLayer(self.sortingOrder)
        end
    end
    sorting = self.sortingOrder

    self.gameObject:GetComponent("Canvas").sortingOrder = self.sortingOrder + 10
end

function this.ShowTitleChapterInfo()
   local allConFigData = GuildTranscriptManager.GetAllConFigData()
   this.SelectImage:SetActive(false)
   this.titleScrollView:SetData(allConFigData, function (index, go)
        this.SingleChapterDataShow(go, allConFigData[index])
    end)    
    this.titleScrollView:SetIndex(cutOpenIndex)
end
local rankingInfo,myRankingInfo
local firstDamage = 0
function this.ShowRankingListInfo(rankingInfo, myRankingInfo)
    --rankingInfo,myRankingInfo-- = RankingManager.GetRankingInfo()
    
    this.Empty:SetActive(#rankingInfo == 0)
    this.rankList:SetActive(#rankingInfo ~= 0)
    if #rankingInfo > 0 then
        firstDamage =  rankingInfo[1].rankInfo.param1
    end
    this.rankScrollView :SetData(rankingInfo, function (index, go)
         this.SingleRankingInfoShow(go, rankingInfo[index])
     end)    
     this.rankScrollView:SetIndex(1)
 end
function this.SingleChapterDataShow(go,data)
    Util.GetGameObject(go,"title"):GetComponent("Text").text = GetLanguageStrById(data.Remarks)
    local lock = Util.GetGameObject(go,"lock")
    local mask = Util.GetGameObject(go,"mask")
    
    local monsterData = this.GetMonsterConfigDataById(data.MonsterId)
    if not monsterData then return end
    Util.GetGameObject(go,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig[monsterData.MonsterId].Icon))
    if  GuildTranscriptManager.GetCurBoss() > data.Id then--已打过
        Util.SetGray(go, true)
        lock:SetActive(false)
    elseif  GuildTranscriptManager.GetCurBoss() == data.Id then--已开启
        Util.SetGray(go, false)
        lock:SetActive(false)
    else--未开启
        Util.SetGray(go, false)
        lock:SetActive(true)
    end
    if  cutOpenIndex == data.Id then
        this.SetSelectImagePos(go)
    elseif oldSelceParent == go then
        this.SelectImage:SetActive(false)
    end
    Util.AddOnceClick(Util.GetGameObject(go,"click"),function()
        if data.Id > GuildTranscriptManager.GetCurBoss() then
            return  PopupTipPanel.ShowTipByLanguageId(12339)
        end
       this.ShowPanelInfo(data.Id)
       this.SetSelectImagePos(go)
    end)
end

function this.SingleRankingInfoShow(root,rankData)
    --排名
    local rank = rankData.rankInfo.rank
    local sortNumTabs={}
    for i = 1, 4 do
        sortNumTabs[i]=Util.GetGameObject(root,"SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if rank < 4 then
        sortNumTabs[rank]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        if rank > 100 then
            rank="100+"
        end
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rank
    end

    Util.GetGameObject(root, "name"):GetComponent("Text").text = rankData.userName
    Util.GetGameObject(root, "num"):GetComponent("Text").text = rankData.rankInfo.param1
    local clickBtn = Util.GetGameObject(root,"ClickBtn")
    Util.AddOnceClick(clickBtn,function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, rankData.uid)
    end)
end

function this.ShowPanelInfo(chapterId)
    cutOpenIndex = chapterId
    if this.curheroConfig then
        UnLoadHerolive(this.curheroConfig,this.curLiveObj)
        Util.ClearChild(this.bossHerolive.transform)
    end
    this.ShowQuickBtnData()
    this.ShowEndNumInfo()
    cutOpenIndexConFig =  guildCheckpointConfig[cutOpenIndex]
    cutOpenIndexMonsterConFig = this.GetMonsterConfigDataById(guildCheckpointConfig[cutOpenIndex].MonsterId) 
    this.ShowBossInfo()
    this.ShowRewardInfo()
end

function this.ShowQuickBtnData()
    local canSweep = GuildTranscriptManager.GetCanSweep() == 1 and true or false
    local isEqualityChapter = cutOpenIndex == GuildTranscriptManager.GetCurBoss() and true or false
    
    this.quickWarbtn:GetComponent("Button").enabled = canSweep and isEqualityChapter
    this.warbtn:GetComponent("Button").enabled = isEqualityChapter
    Util.SetGray(this.quickWarbtn,not (canSweep and isEqualityChapter))
    Util.SetGray(this.warbtn,not isEqualityChapter)
    
    RankingManager.GetRankingInfo(RANK_TYPE.GUILDTRANSCRIPT, function(rankingInfo, myRankingInfo)
        this.ShowRankingListInfo(rankingInfo, myRankingInfo)
    end, cutOpenIndex)
end
--显示boss立绘信息
function this.ShowBossInfo()
    if not cutOpenIndexMonsterConFig then return end
    this.curheroConfig = heroConfig[cutOpenIndexMonsterConFig.MonsterId]
    this.bossHerohpPass.fillAmount = GuildTranscriptManager.GetBlood()/10000
    this.bossHerohpPassText.text = GuildTranscriptManager.GetBlood()/100 .."%"
    if cutOpenIndex < GuildTranscriptManager.GetCurBoss() then
        this.bossHerohpPassText.text = GetLanguageStrById(12340)
        this.bossHerohpPass.fillAmount = 0
    end

    this.curLiveObj = LoadHerolive(this.curheroConfig,this.bossHerolive.transform)
end

function this.ShowRewardInfo()
    -- guildCheckpointConfig[cutOpenIndex]
    if not itemList[this.reward1.name] then
        itemList[this.reward1.name] = {}
    end
    if not itemList[this.reward2.name] then
        itemList[this.reward2.name] = {}
    end

    for i = 1, #itemList[this.reward1.name] do
        itemList[this.reward1.name][i].gameObject:SetActive(false)
    end
    for i = 1, #itemList[this.reward2.name] do
        itemList[this.reward2.name][i].gameObject:SetActive(false)
    end

    local reward1Data = ConfigManager.GetConfigData(ConfigName.RewardGroup,cutOpenIndexConFig.Reward).ShowItem
    local reward2Data = ConfigManager.GetConfigData(ConfigName.RewardGroup,cutOpenIndexConFig.KillReward).ShowItem

    for i = 1, #reward1Data do
        if itemList[this.reward1.name][i] then
            itemList[this.reward1.name][i]:OnOpen(false, reward1Data[i], 0.55,false,false,false,sorting)
        else
            itemList[this.reward1.name][i] = SubUIManager.Open(SubUIConfig.ItemView, this.reward1.transform)
            itemList[this.reward1.name][i]:OnOpen(false, reward1Data[i], 0.55,false,false,false,sorting)
        end
        itemList[this.reward1.name][i].gameObject:SetActive(true)
    end
    for i = 1, #reward2Data do
        if itemList[this.reward2.name][i] then
            itemList[this.reward2.name][i]:OnOpen(false, reward2Data[i], 0.55,false,false,false,sorting)
        else
            itemList[this.reward2.name][i] = SubUIManager.Open(SubUIConfig.ItemView, this.reward2.transform)
            itemList[this.reward2.name][i]:OnOpen(false, reward2Data[i], 0.55,false,false,false,sorting)
        end
        itemList[this.reward2.name][i].gameObject:SetActive(true)
    end
end

function this.GetMonsterConfigDataById(MonsterId)
    local monsterConFig = nil
    local monsterGrip = ConfigManager.GetConfigData(ConfigName.MonsterGroup,MonsterId)
    monsterData=MonsterId
    if not monsterGrip then return nil end
    local monsterId = 0
    for i = 1, #monsterGrip.Contents do
        if monsterId <= 0 then
            for j = 1, #monsterGrip.Contents[i] do
                if monsterGrip.Contents[i][j] > 0 then
                    monsterId =  monsterGrip.Contents[i][j]
                    break
                end
            end
        end
    end
    if monsterId <= 0 then return nil end
    local monsterData = ConfigManager.GetConfigData(ConfigName.MonsterConfig,monsterId)
    return monsterData
end
function this.ShowEndNumInfo()
    local num = GuildTranscriptManager.GetCanBattleCount()
    if num < 0 then num = 0 end
    this.endNumText.text = num----[[string.format(GetLanguageStrById(12341),]] GuildTranscriptManager.GetCanBattleCount()
    local num2 = GuildTranscriptManager.GetCanBuyBattleCount()
    if num2 < 0 then num2 = 0 end
    this.endNumBuyText.text = num2----[[GetLanguageStrById(12342) .. ]]GuildTranscriptManager.GetCanBuyBattleCount()
end
function this.QuickWar()
    GuildTranscriptManager.GuildChallengeRequest(1,function()
        this.ShowPanelData()
        this.ShowEndNumInfo()
        RankingManager.GetRankingInfo(RANK_TYPE.GUILDTRANSCRIPT,function(rankingInfo, myRankingInfo)
            this.ShowRankingListInfo(rankingInfo, myRankingInfo)
        end,GuildTranscriptManager.GetCurBoss())
    end)
end
function this.ShowBuffData()
    curBuyIndex = GuildTranscriptManager.GetbuffCount()
    local curguildCheckpointConfig = guildCheckpointConfig[GuildTranscriptManager.GetCurBoss()]
    local attackBuffNum = 0
    if curBuyIndex > 0 then
        local addNum = ConfigManager.GetConfigData(ConfigName.FoodsConfig,curguildCheckpointConfig.AttributePromote[curBuyIndex]).EffectPara
        attackBuffNum =  math.floor(addNum[1][2]/100) 
    end
    local GetbuffTime =  GuildTranscriptManager.GetbuffTime() > 0 and GuildTranscriptManager.GetbuffTime() - PlayerManager.serverTime or 0
    if attackBuffNum == 0 then
        --<color=#FCF5D3FF>%s</color>
        this.attackInfoText.text = "+0%"--GetLanguageStrById(12343)
    else
        this.attackInfoText.text = "+" .. --[[string.format(GetLanguageStrById(12344),]]attackBuffNum .."%"-- ).."%</color>"
    end
    this.RemainTimeDown(this.attackInfoTime, GetbuffTime)
end
this.timer = Timer.New()
--刷新倒计时显示
function this.RemainTimeDown(_timeTextExpert,timeDown)
    if timeDown > 0 then
        -- if this.attackInfoTimeGo then
        --     this.attackInfoTimeGo:SetActive(true)
        -- end
        if _timeTextExpert then
            _timeTextExpert.text =  this.TimeStampToDateString(timeDown)
        end
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            if _timeTextExpert then
                _timeTextExpert.text =  this.TimeStampToDateString(timeDown)
            end
            if timeDown < 0 then
                _timeTextExpert.text = ""
                -- if this.attackInfoTimeGo then
                --     this.attackInfoTimeGo:SetActive(false)
                -- end
                this.timer:Stop()
                this.timer = nil
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        _timeTextExpert.text = ""
    end
end
function this.TimeStampToDateString(second)
    return string.format(GetLanguageStrById(12345),TimeToHMS(second))
end

function this.SetSelectImagePos(parent)
    oldSelceParent = parent
    Util.SetGray(this.SelectImage,false)
    this.SelectImage:SetActive(true)
    this.SelectImage.transform:SetParent(Util.GetGameObject(parent, "GameObject").transform)
    this.SelectImage:GetComponent("RectTransform").localPosition = Vector3.zero
    this.SelectImage:GetComponent("RectTransform").localScale = Vector3.New(1,1,1)
end

--界面关闭时调用（用于子类重写）
function GuildTranscriptMainPopup:OnClose()
    UnLoadHerolive(this.curheroConfig,this.curLiveObj)
    Util.ClearChild(this.bossHerolive.transform)
end

--界面销毁时调用（用于子类重写）
function GuildTranscriptMainPopup:OnDestroy()
    itemList = {}
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

return GuildTranscriptMainPopup