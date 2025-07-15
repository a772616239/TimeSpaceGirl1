----- 公会十绝阵排行弹窗 -----
require("Base/BasePanel")
local XuanYuanMirrorRankPopup = Inherit(BasePanel)
local this = XuanYuanMirrorRankPopup
this.playerScrollHead={}
local rewardList = {}
local itemList = {}
local myDemonsItemList = {}
local sorting = 0

function XuanYuanMirrorRankPopup:InitComponent()

    this.btnBack = Util.GetGameObject(this.gameObject,"BackMask")
	this.BackBtn = Util.GetGameObject(this.gameObject,"BackBtn")
    this.btnRank = Util.GetGameObject(this.gameObject, "btnRank")
    this.btnReward = Util.GetGameObject(this.gameObject,"btnReward")
    this.select = Util.GetGameObject(this.gameObject,"select")

    ---------------------------------排行
    this.rank = Util.GetGameObject(this.gameObject,"rank")
    this.empty = Util.GetGameObject(this.rank,"NoneImage")
    this.rankList = Util.GetGameObject(this.rank,"RankList")
    this.itemPre = Util.GetGameObject(this.rank,"ItemPre")

    --我的排名
    this.myRank = Util.GetGameObject(this.gameObject,"myrank")
    this.myName = Util.GetGameObject(this.myRank,"name"):GetComponent("Text")
    this.myNum = Util.GetGameObject(this.myRank,"integral"):GetComponent("Text")
    this.totalForce = Util.GetGameObject(this.myRank,"totalForce"):GetComponent("Text")
    this.head = Util.GetGameObject(this.myRank,"Head")
    local playerHead
    playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.head.transform)
    playerHead:Reset()
    playerHead:SetScale(Vector3.one * 0.55)
    playerHead:SetHead(PlayerManager.head)
    playerHead:SetFrame(PlayerManager.frame)

    local w = this.rankList.transform.rect.width
    local h = this.rankList.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.rankList.transform,this.itemPre, nil,
    Vector2.New(w, h),1,1,Vector2.New(0,10))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    ---------------------------------奖励
    this.rankReward = Util.GetGameObject(this.gameObject,"rankReward")
    this.rewardPre = Util.GetGameObject(this.rankReward, "ItemPre")
    this.rewardList = Util.GetGameObject(this.rankReward, "scroll").transform
    local rect = this.rewardList:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rewardList,
            this.rewardPre, nil, Vector2.New(rect.width, rect.height), 1, 1, Vector2.New(0,5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1

    this.myRecord = Util.GetGameObject(this.rankReward, "Record")
    this.mySortNum = Util.GetGameObject(this.myRecord, "SortNum")
    this.myDemons = Util.GetGameObject(this.myRecord, "Demons")

end

function XuanYuanMirrorRankPopup:BindEvent()
    Util.AddClick(this.btnBack,function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.BackBtn,function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.btnRank, function()
        -- UIManager.OpenPanel(UIName.XuanYuanMirrorRewardSortPopup)
        this.select:SetActive(true)
        Util.GetGameObject(this.btnReward,"select"):SetActive(false)
        this.rank:SetActive(true)
        this.rankReward:SetActive(false)
    end)
    Util.AddClick(this.btnReward, function()
        -- UIManager.OpenPanel(UIName.XuanYuanMirrorRewardSortPopup)
        this.select:SetActive(false)
        Util.GetGameObject(this.btnReward,"select"):SetActive(true)
        this.rank:SetActive(false)
        this.rankReward:SetActive(true)
    end)
end
function XuanYuanMirrorRankPopup:OnOpen(...)

end

function XuanYuanMirrorRankPopup:OnShow()
    this.RefreshRank()

    this.ShowCurIndexRewardData()
    NetManager.RequestRankInfo(RANK_TYPE.XUANYUANMIRROR_RANK, function(msg)
        this.SetRankDataShow(msg)
    end)
end
function XuanYuanMirrorRankPopup:OnSortingOrderChange()
    sorting = self.sortingOrder
end

function XuanYuanMirrorRankPopup:OnClose()
    this.empty:SetActive(false)
end

function XuanYuanMirrorRankPopup:OnDestroy()
    this.scrollView = nil

    itemList = {}
    myDemonsItemList = {}
end

--刷新排行榜 index当前排行类型索引
function this.RefreshRank()
    NetManager.RequestRankInfo(RANK_TYPE.XUANYUANMIRROR_RANK,function(msg)
        this.empty:SetActive(#msg.ranks <= 0)
        for i=1,#msg.ranks do
            
        end
        
        this.scrollView:SetData(msg.ranks,function(index,root)
            this.SetScrollPre(root,msg.ranks[index])
        end)
        this.scrollView:SetIndex(1)

        this.myRank.gameObject:SetActive((not msg.myRankInfo) or msg.myRankInfo.rank~=-1)
        if msg.myRankInfo and msg.myRankInfo.rank ~= -1 then
            this.SetMyRank(msg.myRankInfo)
        end        
    end)
end

--设置每条数据
function this.SetScrollPre(root,data,myRankData)

    local name=Util.GetGameObject(root,"name"):GetComponent("Text")
    local totalForce=Util.GetGameObject(root,"totalForce"):GetComponent("Text")
    local num=Util.GetGameObject(root,"num"):GetComponent("Text")
    this.SetRankingNum(root,data.rankInfo.rank,false)
    this.SetHeadInfo(root,data.head,data.headFrame,data.level)
    name.text=data.userName 
    totalForce.text= --[[GetLanguageStrById(12596)..]] data.force
    num.text = --[[GetLanguageStrById(12597)..]]data.rankInfo.param1
end

--设置我的名次
function this.SetMyRank(data,curRankType)
    this.SetRankingNum(this.myRank,data.rank,true)
    
    this.myName.text = PlayerManager.nickName
    this.myNum.text = data.param1
    this.totalForce.text=FormationManager.GetFormationPower(FormationTypeDef.Arden_MIRROR)--TODO战斗力计算暂定
end


--设置名次 isMy 是否是设置我的名次
function this.SetRankingNum(root,rank,isMy)
    local sortNumTabs={}
    for i = 1, 4 do
        sortNumTabs[i]=Util.GetGameObject(root,"SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if rank < 4 then
        sortNumTabs[rank]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        if rank > 100 and isMy then
            rank="100+"
        end
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rank
    end
end

--设置头像
function this.SetHeadInfo(root,head,frame,level)
    local headObj=Util.GetGameObject(root,"Head")
    if not this.playerScrollHead[root] then
        this.playerScrollHead[root]=CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,headObj)
    end
    this.playerScrollHead[root]:Reset()
    this.playerScrollHead[root]:SetHead(head)
    this.playerScrollHead[root]:SetFrame(frame)
    this.playerScrollHead[root]:SetLevel(level)
    this.playerScrollHead[root]:SetScale(Vector3.one*0.55)
end

--奖励相关
function this.SetRankDataShow(msg)
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] =  Util.GetGameObject(this.mySortNum, "SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
        this.myRecord.gameObject:SetActive(true)
        if msg.myRankInfo.rank < 4 and msg.myRankInfo.rank > 0 then
            sortNumTabs[msg.myRankInfo.rank]:SetActive(true)
        else
            sortNumTabs[4]:SetActive(true)
            Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = msg.myRankInfo.rank > 0 and msg.myRankInfo.rank or GetLanguageStrById(10094)
        end
    
    local myrewardConfig = nil
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.RaceTowerRewardConfig)) do
        table.insert(rewardList,configInfo)
        if msg.myRankInfo.rank <= configInfo.Section[2] and msg.myRankInfo.rank >= configInfo.Section[1] then
            myrewardConfig = configInfo
        end
    end
    if not myrewardConfig then
        this.myRecord:SetActive(false)
    else
        this.myRecord:SetActive(true)
        --我自己的排名展示
        for i = 1, #myDemonsItemList do
            myDemonsItemList[i].gameObject:SetActive(false)
        end
        for i = 1, #myrewardConfig.Reward do
            if myDemonsItemList[i] then
                myDemonsItemList[i]:OnOpen(false, myrewardConfig.Reward[i], 0.55,false,false,false,sorting)
            else
                myDemonsItemList[i] = SubUIManager.Open(SubUIConfig.ItemView, this.myDemons.transform)
                myDemonsItemList[i]:OnOpen(false, myrewardConfig.Reward[i], 0.55,false,false,false,sorting)
            end
            myDemonsItemList[i].gameObject:SetActive(true)
        end
    end   
end
--显示奖励
function this.ShowCurIndexRewardData()
    --curIndex
    rewardList = {}
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.RaceTowerRewardConfig)) do
        table.insert(rewardList,configInfo)      
    end
    this.ScrollView:SetData(rewardList, function (index, go)
        go:SetActive(true)
        this.SingleRewardDataShow(go, rewardList[index],index)
    end)
end

function this.SingleRewardDataShow(go,rewardConfig,index)
    if not itemList[go.name] then
        itemList[go.name] = {}
    end
    for i = 1, #itemList[go.name] do
        itemList[go.name][i].gameObject:SetActive(false)
    end
    for i = 1, #rewardConfig.Reward do
        if itemList[go.name][i] then
            itemList[go.name][i]:OnOpen(false, rewardConfig.Reward[i], 0.55,false,false,false,sorting)
        else
            itemList[go.name][i] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "Demons").transform)
            itemList[go.name][i]:OnOpen(false, rewardConfig.Reward[i], 0.55,false,false,false,sorting)
        end
        itemList[go.name][i].gameObject:SetActive(true)
    end
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] =  Util.GetGameObject(go, "SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if index < 4 then
        sortNumTabs[rewardConfig.Section[1]]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        local str = "+"
        if rewardConfig.Section[2] > 1 then
            str = "-"..rewardConfig.Section[2]
        end
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rewardConfig.Section[1]..str
    end
end


return XuanYuanMirrorRankPopup