require("Base/BasePanel")
RankAllSeverRewardPanel = Inherit(BasePanel)
local this = RankAllSeverRewardPanel
local myRankingReward=ConfigManager.GetConfig(ConfigName.RankingRewardConfig)
local myRanktype = 0
local myrankNum = 0
--初始化组件（用于子类重写）
function RankAllSeverRewardPanel:InitComponent()    
   
    this.mask=Util.GetGameObject(self.gameObject, "BackMask")
    this.BackBtn=Util.GetGameObject(self.gameObject, "btnBack")
    this.topList=Util.GetGameObject(self.gameObject, "bg")
    this.rewardTip=Util.GetGameObject(this.topList, "title")
    --初始化获得或者加载前获得
    this.scrollParentView = Util.GetGameObject(self.gameObject,"ScrollParent/ScrollParentView")
    this.itemPre = Util.GetGameObject(this.scrollParentView,"ItemPre")
    this.effect = Util.GetGameObject(this.scrollParentView,"uI_effect_waiteclick")

    local v2 = Util.GetGameObject(self.gameObject, "ScrollParentView"):GetComponent("RectTransform").rect
    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollParentView.transform,this.itemPre,
            nil,Vector2.New(-v2.x*2, -v2.y*2),1,1,Vector2.New(0,10))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.istop=true
    this.playerHeroListHead = {}
    this.playerHeadList = {}    
    this.RewardItemListGo = {}
    this.effectList={}
    this.rewardTip:GetComponent("Text").text=GetLanguageStrById(10080)   
    myRanktype = 0
end

--绑定事件（用于子类重写）
function RankAllSeverRewardPanel:BindEvent()
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function RankAllSeverRewardPanel:AddListener()
end

--移除事件监听（用于子类重写）
function RankAllSeverRewardPanel:RemoveListener()
end

local UpdateTop={}
--界面打开时调用（用于子类重写）
function RankAllSeverRewardPanel:OnOpen(_rankType,funcFreshTop)    
    UpdateTop = funcFreshTop       
    -- 刷新数据
    myRanktype=0
    if _rankType==RANK_TYPE.FIGHT_LEVEL_RANK then
        myRanktype=1
    elseif _rankType==RANK_TYPE.FORCE_RANK or _rankType==RANK_TYPE.FORCE_CURR_RANK then 
        myRanktype=2
    elseif _rankType==RANK_TYPE.CLIMB_TOWER then
        myRanktype=3
    elseif _rankType==RANK_TYPE.HERO_FORCE_RANK then
        myRanktype=4
    end    
    
    this.RefreshTopInfo(myRanktype,_rankType)  
    myrankNum = _rankType
end

function this.UpdateMain() 
    this.RefreshTopInfo(myRanktype,myrankNum) 
end
this.isClickbtn=false
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RankAllSeverRewardPanel:OnShow()
    this.isClickbtn=false
end


function this.showTip()
    PopupTipPanel.ShowTip(GetLanguageStrById(11711))
    PopupTipPanel.ShowTip(GetLanguageStrById(11708))  --跨服排行榜
    PopupTipPanel.ShowTip(GetLanguageStrById(50177))  --虚位以待
end

this.ranksTopDate={}
this.myRanksRewardDate={}
--刷新数据
function this.RefreshTopInfo(_myrank,sdata)
    this.ranksTopDate={}
    this.myRanksRewardDate={}
    -- this.ranksTopDate,this.myRanksRewardDate= RankingManager.GetRankingTopInfo()
    this.ranksTopDate,this.myRanksRewardDate= RankingManager.GetRankingTopInfoBytype(sdata,myRankingReward)
    this.scrollParentView:SetActive(#this.ranksTopDate ~= 0)

    local list = {}
    for uid,data in pairs(this.ranksTopDate) do
        local temp={
            uid=data[1].uid,
            userName=data[1].name,
            head=data[1].head,
            headFrame=data[1].headFrame,
            level=data[1].level,
            tipid=data[1].id,
            reachTime=data[1].time,
            isReward = this.IsInRewardedList(data[1].id),
            isLast=false          
        }
        table.insert(list, temp)
    end
    table.sort(list,function(a,b)
        return a.uid < b.uid
    end)
    -- 插入下一需要完成的任务
    if #list >= 0 then
        local _lastUid 
        local index = #list        
        if #list == 0 then
            _lastUid= _myrank*1000 + 1 
        else
            _lastUid= list[index].uid + 1
        end
        
        if ConfigManager.TryGetConfigData(ConfigName.RankingRewardConfig, _lastUid) ~=nil  then
            if myRankingReward[_lastUid].Type ~= nil and myRankingReward[_lastUid].Type == _myrank then
                local temp={
                    uid=0,
                    userName="",
                    head="",
                    headFrame="",
                    level=0,
                    tipid=_lastUid,
                    reachTime=0,
                    isLast=true           
                }
                table.insert(list, temp)
            end  
        end    
    end

    -- 排序 待领取 待完成 已领取
    table.sort(list,function(a,b)
        local aPick = a.tipid
        local bPick = b.tipid
        if a.isLast then aPick=aPick+100000 end
        if a.isReward then aPick=aPick+1000000 end
        if b.isLast then bPick=bPick+100000 end
        if b.isReward then bPick=bPick+1000000 end
        return aPick < bPick
    end)

    this.scrollView:SetData(list, function(index, root)
        this.ShowItemInfo(root, list[index],index)
    end)
    this.scrollParentView:SetActive(true)
    this.CheckIsTop()
end

-- 设置每条数据
function this.ShowItemInfo(go, data,index)

    this.SwitchGrid(go,data.isLast)

    if data.isLast then
        this.SetTipConfigData(go,data)
        this.getRewardList(go,data)
    else
        this.SetTipConfigData(go,data)
        this.AddPlayerInfoClick(go,data.uid)
        this.AddTopInfoClick(go,this.ranksTopDate[data.tipid])
        this.SetHeadInfo(go,data.userName, data.head , data.headFrame, data.level )
        this.getRewardList(go,data)
    end
    
end

function this.SwitchGrid(root,isLast)
    if isLast then
        Util.GetGameObject(root, "Received"):SetActive(false)
        Util.GetGameObject(root, "hero"):SetActive(false)
        Util.GetGameObject(root, "DetailBtn"):SetActive(false)

        local info=Util.GetGameObject(root, "contains/info")
        Util.GetGameObject(info, "name"):SetActive(false)
        
        local waite=Util.GetGameObject(info, "waite")       
        waite:SetActive(true)
        waite:GetComponent("Text").text= GetLanguageStrById(50177)
    else
        Util.GetGameObject(root, "hero"):SetActive(true)
        Util.GetGameObject(root, "DetailBtn"):SetActive(true)

        local info=Util.GetGameObject(root, "contains/info")
        Util.GetGameObject(info, "name"):SetActive(true)
        Util.GetGameObject(info, "waite"):SetActive(false)
    end
end

-- 是否在奖励列表中
function this.IsInRewardedList(_id)
    if #this.myRanksRewardDate>0 then
        for _,id in pairs(this.myRanksRewardDate) do
            if id==_id then
                return true
            end
        end
    end
    return false
end

--更新获取列表
function this.OnRecived(root,tipid)
    local getedreward=Util.GetGameObject(root, "Received").gameObject
    local go=Util.GetGameObject(root, "rewardList").gameObject
    go:SetActive(false)
    getedreward:SetActive(true)
    table.insert(this.myRanksRewardDate,tipid)
    RedpotManager.CheckRedPointStatus(RedPointType.RankReward)
end

--传入特效层级
local sortingOrder = 1
--玩家奖励信息
function this.getRewardList(root,data)
    local go=Util.GetGameObject(root, "rewardList").gameObject   
    local getedreward=Util.GetGameObject(root, "Received").gameObject  
     
    if this.IsInRewardedList(data.tipid) then
        getedreward:SetActive(true)
        go:SetActive(false)
    else
        getedreward:SetActive(false)
        go:SetActive(true)
    end    
    
    for i = 1, 4 do
        if this.RewardItemListGo[go] ==nil then
            this.RewardItemListGo[go]= {}
            this.effectList[go]={}
        end
        if  this.RewardItemListGo[go][i] == nil then
            this.RewardItemListGo[go][i] = SubUIManager.Open(SubUIConfig.ItemView, go.transform)     
            local effectParent=Util.GetGameObject(this.RewardItemListGo[go][i].gameObject,"item")
            this.effectList[go][i] = newObjToParent(this.effect,effectParent)
            -- this.effectList[go][i]
        end
        this.RewardItemListGo[go][i].gameObject:SetActive(false)
        this.effectList[go][i].gameObject:SetActive(false)
    end
    local reward=myRankingReward[data.tipid].Reward
    for i = 1, #reward do
        this.RewardItemListGo[go][i]:OnOpen(false, 
            {reward[i][1],reward[i][2]},
            0.7,false,false,false,sortingOrder)  

        this.RewardItemListGo[go][i].gameObject:SetActive(true)        
        local btn=Util.GetGameObject(this.RewardItemListGo[go][i].gameObject,"item/frame")
        local grid=go.transform.parent
        if not data.isLast then
           this.RegisterButtonGetReward( btn,data.tipid,grid)            
           this.effectList[go][i].gameObject:SetActive(true) 
        end
    end
    go:GetComponent("HorizontalLayoutGroup").enabled=true
end

--玩家Top信息弹窗
function this.AddPlayerInfoClick(root,uid)
    local clickBtn = Util.GetGameObject(root,"hero/Head")
    Util.AddOnceClick(clickBtn,function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, uid)
    end)
end

--玩家信息弹窗
function this.AddTopInfoClick(root,rDate)
    local clickBtn = Util.GetGameObject(root,"DetailBtn")
    Util.GetGameObject(clickBtn,"detail"):GetComponent("Text").text=GetLanguageStrById(50203)
    Util.AddOnceClick(clickBtn,function()
        UIManager.OpenPanel(UIName.RankTopFivePanel, rDate)
    end)
end

function this.SetTipConfigData(go,data)
    local rewardTip = Util.GetGameObject(go,"titleImage/titleText")
    rewardTip:GetComponent("Text").text=GetLanguageStrById(myRankingReward[data.tipid].ContentsShow)
end

---------------------------事件-------------------------------------
function this.getInfo(go)
    Util.AddOnceClick(go, function()
        NetManager.RankingTakeRewardRequest(function(msg)
                if msg.drop then
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
                    if  UpdateTop then UpdateTop() end
                end
                this.UpdateMain()            
        end)
    end)
end

-- 获取奖励
function this.RegisterButtonGetReward(go,id,grid)
    Util.AddOnceClick(go, function()
        if this.isClickbtn then
            return
        end
        this.timer = Timer.New(function()
            this.isClickbtn=false
            if this.timer then
                this.timer:Stop()
                this.timer = nil
            end
        end, 1.3)
        this.timer:Start()
        this.isClickbtn=true
        NetManager.RankingTakeRewardRequest(id, function(msg)
                if msg.drop  then
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)                       
                    this.OnRecived(grid,id)
                end
                -- LogError("msg get id ".. id)
                this.UpdateMain()            
        end)
    end)
end

-- 头像
function this.SetHeadInfo(root, playerName, playerHead, playerFrame, PlayerLevel)
    local headpos = Util.GetGameObject(root,"Head")
    local name = Util.GetGameObject(root,"name"):GetComponent("Text")
    if not this.playerHeroListHead then
        this.playerHead = {}
    end
    if not this.playerHeroListHead[root] then
        this.playerHeroListHead[root] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    this.playerHeroListHead[root]:SetScale(Vector3.one * 0.5)
    name.text = playerName
    this.playerHeroListHead[root]:SetHead(playerHead)
    this.playerHeroListHead[root]:SetFrame(playerFrame)
    this.playerHeroListHead[root]:SetLevel(PlayerLevel)
end

function this.CheckIsTop()
    if this.istop then
        this.scrollView:SetIndex(1)
        this.istop = false
    end
end

--界面关闭时调用（用于子类重写）
function RankAllSeverRewardPanel:OnClose()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    if UpdateTop then UpdateTop() end
end

this.playerHeroListHead ={}
this.playerHeadList = {}
--界面销毁时调用（用于子类重写）
function RankAllSeverRewardPanel:OnDestroy()
    if this.playerHeroListHead~=nil then
        for _, playerHead in ipairs(this.playerHeadList) do
            playerHead:Recycle()
        end
    end
   this.playerHeroListHead ={}
   this.playerHeadList = {}
   this.scrollView = nil
end

return RankAllSeverRewardPanel