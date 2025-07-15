require("Base/BasePanel")
RankingListMainPanel = Inherit(BasePanel)
local this = RankingListMainPanel
local curIndex = 1
local rankKingListGo = {}
local TabBox = require("Modules/Common/TabBox")
local _TabData = { [1] = { default = "N1_btn_tanke_xuanzhong", select = "N1_btn_tanke_xuanzhong",lock = "N1_btn_tanke_weixuanzhong", name = GetLanguageStrById(11707) },
                 [2] = { default = "N1_btn_tanke_xuanzhong", select = "N1_btn_tanke_xuanzhong",lock = "N1_btn_tanke_weixuanzhong", name = GetLanguageStrById(11708) },
}
local _TabFontColor = { default = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1),
                        lock = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
}
local ranks = {}
local proud = {}
this.playerScrollHead = {}--排行第一头像
local isFirstOn = true--是否首次打开页面

this.playerHeroListHead={}
this.playerHeroListGo={}
--初始化组件（用于子类重写）
function RankingListMainPanel:InitComponent()
    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")
    this.TabCtrl = TabBox.New()
    this.BackBtn = Util.GetGameObject(self.gameObject, "btnBack")
    this.ItemPre = Util.GetGameObject(self.gameObject, "bg/panel/ItemPre")
    this.grid = Util.GetGameObject(self.gameObject, "bg/panel/ScrollParentView/grid")
    this.mask = Util.GetGameObject(self.gameObject, "mask")
    this.playerHeroListHead={}
    this.playerHeroListGo={}

    --初始化排行奖励信息
    -- RankingManager.InitRankingRewardList()  
end

--绑定事件（用于子类重写）
function RankingListMainPanel:BindEvent()
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function RankingListMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.HorseRace.ShowHorseRace, RankingManager.RefreshInfo, nil)
    Game.GlobalEvent:AddEvent(GameEvent.HorseRace.ShowHorseRace,this.SwitchView, self)
end

--移除事件监听（用于子类重写）
function RankingListMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.HorseRace.ShowHorseRace, RankingManager.RefreshInfo, nil)
    Game.GlobalEvent:RemoveEvent(GameEvent.HorseRace.ShowHorseRace,this.SwitchView, self)
end

--界面打开时调用（用于子类重写）
function RankingListMainPanel:OnOpen(msg)
    ranks = msg.ranks 
    RankingManager.RefreshInfo()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RankingListMainPanel:OnShow() 
    if PlayerManager.familyId ~= 0 then
        NetManager.RequestMyGuildInfo( function() end)  --工会战信息获取
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.MianGuide.RefreshGuide)
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:SetTabIsLockCheck(this.PageTabIsLockCheck)
    this.TabCtrl:Init(this.tabBox, _TabData, curIndex)
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
    Util.GetGameObject(tab, "LockImage"):SetActive(status == "lock" )
end

-- tab可用性检测
function this.PageTabIsLockCheck(index)
    if index == 2 then
        return true, GetLanguageStrById(11709)
    else
        return false
    end
end

--切换视图
function this.SwitchView(index)
    curIndex = index
    proud = RankingManager.GetRankProud()
    --先执行上一面板关闭逻辑
    local rankList = {}
    -- to do math.max(#rankKingListGo, #RankKingList)
    -- LogError("  "..#RankKingList.."add "..math.max(#rankKingListGo, #RankKingList))
    for i = 1,  math.max(#rankKingListGo, #RankKingList) do
        if RankKingList[i].isRankingMainPanelShow then
            local go = rankKingListGo[i]
            if not go then
                go = newObject(this.ItemPre)
                go.transform:SetParent(this.grid.transform)
                go.transform.localScale = Vector3.one
                go.transform.localPosition = Vector3.zero;
                rankKingListGo[i] = go
            end
            if isFirstOn then
                go.gameObject:SetActive(false)
            end
            rankList[i] = go
        end
    end

    -- rankList[5]=rankList[9] 1 2 3 4 9 
    local openlen=1
    for i = 1, #RankKingList do        
        if RankKingList[i].isRankingMainPanelShow then                  
                this.SingleRankKingListShow(i,openlen)
                openlen=openlen+1
        end
    end

    if isFirstOn then
        isFirstOn = false
        -- to do 解决id跳跃问题             5 6  7
        -- rankList[5]=rankList[9] 1 2 3 4 7 9 13
        local index =1
        local _ranklist={}
        for k,v in  pairs(rankList) do 
            if k==index then               
                _ranklist[k]=v
            else
                _ranklist[index]=rankList[k]
            end
            index=index+1
        end
        DelayCreation(_ranklist)
    end
end

function this.SingleRankKingListShow(index,openlen)
    local go = rankKingListGo[index]
    local sData = RankKingList[index]

    local dData = ranks[openlen]
    local proud = proud[sData.rankType]
    local boxred= RankingManager.IsRankingTopRed(sData.rankType)
    -- to do 测试数据

    Util.GetGameObject(go,"BG"):GetComponent("Image").sprite = Util.LoadSprite(sData.bgImage)
    -- Util.GetGameObject(go,"nameImage"):GetComponent("Image").sprite = Util.LoadSprite(sData.nameImage)

    Util.GetGameObject(go,"name"):GetComponent("Text").text = sData.name

    Util.GetGameObject(go,"hero"):SetActive(dData.uid ~= 0 )
    if dData.uid ~= 0  then
        this.SetInfoShow(Util.GetGameObject(go,"hero/infoGo"),dData,sData.rankType,Util.GetGameObject(go,"hero/nameText"))
        --头像
        local headObj=Util.GetGameObject(go,"hero/Head")
        local heroheadObj =Util.GetGameObject(go,"hero/HeroHead")
        if sData.rankType==RANK_TYPE.HERO_FORCE_RANK then
            headObj:SetActive(false)
            heroheadObj:SetActive(true)
            if not this.playerHeroListHead[index] then          
                this.playerHeroListHead[index]=SubUIManager.Open(SubUIConfig.ItemView,heroheadObj.transform)
            end
            this.playerHeroListHead[index]:OnOpen(false,{dData.heroTemplateId,dData.heroLevel,dData.heroStar,nil,dData.userName},0.8,false,false,false,false)
            this.playerHeroListHead[index].gameObject:GetComponent("RectTransform").anchoredPosition=Vector3.New(0,-10,0)
            this.playerHeroListGo[index]=this.playerHeroListHead[index].gameObject
            Util.GetGameObject(this.playerHeroListGo[index],"item/num"):SetActive(false) 
            local star=Util.GetGameObject(this.playerHeroListGo[index],"item/starGrid").gameObject
            SetHeroStars(star, dData.heroStar)
        else    
            headObj:SetActive(true)
            heroheadObj:SetActive(false)
            if not this.playerScrollHead[go] then
                this.playerScrollHead[go]=CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,headObj)
            end
            this.playerScrollHead[go]:Reset()     
            this.playerScrollHead[go]:SetHead(dData.head)
            this.playerScrollHead[go]:SetFrame(dData.headFrame)
            this.playerScrollHead[go]:SetLevel("LV." .. dData.level)
            this.playerScrollHead[go]:SetScale(Vector3.one*0.8)
        end
    end
    --膜拜
    local clickBtn = Util.GetGameObject(go,"clickBtn")
    local getRewardBtn = Util.GetGameObject(go,"getRewardBtn")
    --local getRewardBtnText = Util.GetGameObject(go,"getRewardBtn/Text"):GetComponent("Text")
    local getRewardSign = Util.GetGameObject(go,"getRewardBtn/taken")
    local getboxBtn = Util.GetGameObject(go,"getbox")   
    local getboxRedpoint=Util.GetGameObject(getboxBtn,"redPoint")
     -- 设置宝箱红点 msg.redPoint 通过协议获取红点数据
     getboxRedpoint:SetActive(boxred)
     -- 前端屏蔽 是否显示对应宝箱类型
     getboxBtn:SetActive(RankingManager.IsShowType(sData.rankType))
    -- n1 getRewardBtn:SetActive(dData.uid ~= 0 )
    -- Util.SetGray(getRewardBtn,proud ~= 0)
    Util.AddOnceClick(clickBtn, function()
        UIManager.OpenPanel(UIName.RankingSingleListPanel,sData)
        -- this.SwitchView(curIndex)
    end)
    Util.AddOnceClick(getboxBtn, function()   
        UIManager.OpenPanel(UIName.RankAllSeverRewardPanel,sData.rankType,function() 
            this.SwitchView(curIndex)
        end)        
        CheckRedPointStatus(RedPointType.RankingSort)
    end)

    if proud == 0 then--没有膜拜过
        getRewardBtn:GetComponent("Button").enabled = true
        Util.GetGameObject(go,"getRewardBtn/redPoint"):SetActive(true)
        getRewardSign:SetActive(false)
        Util.AddOnceClick(getRewardBtn, function()
            NetManager.RankProudRequest(sData.rankType,function ()
                RankingManager.SetSingleRankProud(sData.rankType,1)
                local spFata = ConfigManager.GetConfigData(ConfigName.SpecialConfig,50)
                local itemData = string.split(spFata.Value, "#")
                PopupTipPanel.ShowTip(GetLanguageStrById(11711)..GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,tonumber(itemData[1])).Name).."×"..itemData[2].."！")
                this.SwitchView(curIndex)
                CheckRedPointStatus(RedPointType.RankingSort)
            end)
        end)
    else
        getRewardBtn:GetComponent("Button").enabled = false
        getRewardBtn:GetComponent("Image").enabled = false
        getRewardSign:SetActive(true)
        -- getRewardBtnText.text = GetLanguageStrById(11712)
        Util.GetGameObject(go,"getRewardBtn/redPoint"):SetActive(false)
    end
end

--界面关闭时调用（用于子类重写）
function RankingListMainPanel:OnClose()
    isFirstOn = true
    RankingManager.RefreshInfo()
    for k, v in ipairs(this.playerHeroListGo) do
        SubUIManager.Close(SubUIConfig.ItemView, v)
        GameObject.DestroyImmediate(v)
    end
    this.playerHeroListGo ={}
    this.playerHeroListHead ={}
end

--界面销毁时调用（用于子类重写）
function RankingListMainPanel:OnDestroy()
    for _, playerHead in ipairs(this.playerScrollHead) do
        playerHead:Recycle()
    end
    this.playerScrollHead = {}
    rankKingListGo = {}
end

function this.SetInfoShow(go,data,rankType,nameText)
    local fight = Util.GetGameObject(go,"fight")
    local warPower = Util.GetGameObject(go,"warPower")
    local trial = Util.GetGameObject(go,"trial")
    local climbTower = Util.GetGameObject(go, "climbTower")
    fight:SetActive(false)
    warPower:SetActive(false)
    trial:SetActive(false)
    climbTower:SetActive(false)
    if rankType == RANK_TYPE.FIGHT_LEVEL_RANK then
        fight:SetActive(true)
        if nameText then
            nameText:GetComponent("Text").text = data.userName
        end
        Util.GetGameObject(go,"fight"):GetComponent("Text").text = RankingManager.mainLevelConfig[data.rankInfo.param1].Name
    elseif rankType == RANK_TYPE.FORCE_CURR_RANK then
        warPower:SetActive(true)
        if nameText then
            nameText:GetComponent("Text").text = data.userName
        end
        Util.GetGameObject(go,"warPower/Text"):GetComponent("Text").text = data.rankInfo.param1--data.force
    elseif rankType == RANK_TYPE.GUILD_FORCE_RANK then
        warPower:SetActive(true)
        if nameText then
            nameText:GetComponent("Text").text = data.guildName
        end
        Util.GetGameObject(go,"warPower/Text"):GetComponent("Text").text =  data.rankInfo.param1
    elseif rankType == RANK_TYPE.MONSTER_RANK then
        trial:SetActive(true)
        if nameText then
            nameText:GetComponent("Text").text = data.userName
        end
        Util.GetGameObject(go,"trial/Text"):GetComponent("Text").text = data.rankInfo.param1
    elseif rankType == RANK_TYPE.CLIMB_TOWER then
        if data.rankInfo.param1 and data.rankInfo.param1 > 0 then
            climbTower:SetActive(true)
            if nameText then
                nameText:GetComponent("Text").text = data.userName
            end
            Util.GetGameObject(go, "climbTower/Text"):GetComponent("Text").text = data.rankInfo.param1
        end
    elseif rankType==RANK_TYPE.HERO_FORCE_RANK then
        -- 前五战力英雄数据 to do 服务端数据核对从 
        if data.rankInfo.rank and data.rankInfo.rank > 0 then
            warPower:SetActive(true)
            if nameText then
                nameText:GetComponent("Text").text = data.userName
            end
            Util.GetGameObject(go, "warPower/Text"):GetComponent("Text").text = data.rankInfo.param1
        end
    end
end

function this.SetHeroShow()
    -- 显示英雄头像 战斗力
    --  SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(bg, "bg/pos").transform)
    --  ItemView:OnOpen
    -- 显示英雄头像、英雄等级、英雄星级、英雄阵营，玩家名字

    -- dragViewListGo[i] = SubUIManager.Open(SubUIConfig.DragView, bgListGo[i].transform)
    -- 获取英雄数据 HeroManager.GetSingleHeroData(this.choosedList[j].heroId)
    -- 获取英雄名称 GetLanguageStrById(herodata.name)
    -- local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
    -- local itemData = itemConfig[itemId]
    -- local bagNum = BagManager.GetItemCountById(itemId)
    -- ItemImageTips(itemId, Util.GetGameObject(this.Connect, "Cost" .. i .. "/icon"))    
    -- 获取item信息 BagManager.GetItemCountById(this.handselData.ConsumeItem[1]) / this.handselData.ConsumeItem[2]
end

return RankingListMainPanel