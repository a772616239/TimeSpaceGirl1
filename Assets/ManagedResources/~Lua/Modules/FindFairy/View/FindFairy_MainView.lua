----- 东海寻仙主面板 -----
local this = {}
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local artResourcesConfig =ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
--预告左右按钮类型
local NoticeBtnType={
    Left=1,
    Right=2
}
--预告信息提示图片
local NoticeInfoImage={"d_dhxx_benqi","d_dhxx_xaiqi"}

local sortingOrder = 0--层级

-- local onceData={}
-- local moreData={}
local heroData
--活动抽卡类型（动态的数据）
local recruitType={
    [1]=0,
    [2]=0
}
--按钮类型
local bType={
    Btn1=1,
    Btn10=2
}
--抽卡配置
local configure={
    privilegeId=32,
    btn={[bType.Btn1]={name="Btn1",isInfo=GetLanguageStrById(10644)},
         [bType.Btn10]={name="Btn10",isInfo=GetLanguageStrById(10645)}
    },
}
local btnList={}--抽卡按钮容器
function this:InitComponent(gameObject)
    this.gameObject=gameObject
    this.helpBtn=Util.GetGameObject(this.gameObject,"HelpBtn")
    this.helpPos=this.helpBtn:GetComponent("RectTransform").localPosition
    this.activityTime=Util.GetGameObject(this.gameObject,"ActivityTime"):GetComponent("Text")

    this.liveRoot=Util.GetGameObject(this.gameObject,"Live/LiveRoot")
    this.curLiveRoot=Util.GetGameObject(this.gameObject,"Live/LiveRoot/CurLiveRoot")
    this.nextLiveRoot=Util.GetGameObject(this.gameObject,"Live/LiveRoot/NextLiveRoot")
    this.qualityImage=Util.GetGameObject(this.gameObject,"Live/Quality"):GetComponent("Image")
    this.qualityNum=Util.GetGameObject(this.gameObject,"Live/Quality/DoubleText"):GetComponent("Text")
    this.proImage=Util.GetGameObject(this.gameObject,"Live/Pro"):GetComponent("Image")
    this.heroName=Util.GetGameObject(this.gameObject,"Live/NameBg/Name"):GetComponent("Text")
    this.click=Util.GetGameObject(this.gameObject,"Live/Quality/click")

    this.middleView=Util.GetGameObject(this.gameObject,"MiddleView")
    this.integralRewardBtn=Util.GetGameObject(this.middleView,"IntegralRewardBtn")--积分奖励按钮
    this.integralRewardBtnRedPoint=Util.GetGameObject(this.middleView,"IntegralRewardBtn/RedPoint"):GetComponent("Image")
    this.findRankBtn=Util.GetGameObject(this.middleView,"FindRankBtn")--寻仙榜按钮
    this.buyTip=Util.GetGameObject(this.middleView,"BuyTip/Text"):GetComponent("Text")--再次购买x次


    this.onceBtn=Util.GetGameObject(this.middleView,"OnceBtn")
    -- this.onceBtnTip=Util.GetGameObject(this.middleView,"OnceBtn/Consume/Text"):GetComponent("Text")
    -- this.onceBtnIcon=Util.GetGameObject(this.middleView,"OnceBtn/Consume/Image"):GetComponent("Image")
    this.onceBtnRedPoint=Util.GetGameObject(this.middleView,"OnceBtn/RedPoint"):GetComponent("Image")
    this.tenthBtn=Util.GetGameObject(this.middleView,"TenthBtn")
    -- this.tenthBtnTip=Util.GetGameObject(this.middleView,"TenthBtn/Consume/Text"):GetComponent("Text")
    -- this.tenthBtnIcon=Util.GetGameObject(this.middleView,"TenthBtn/Consume/Image"):GetComponent("Image")
    btnList[1]=this.onceBtn
    btnList[2]=this.tenthBtn

    this.bigRankBtn=Util.GetGameObject(this.middleView,"BigRankBtn")--排名大奖按钮
    this.imageTip2=Util.GetGameObject(this.middleView,"ImageTip/Tip2/Image"):GetComponent("Image")

    this.bottomView=Util.GetGameObject(this.gameObject,"BottomView")
    this.myScore=Util.GetGameObject(this.bottomView,"MyScore/Text"):GetComponent("Text")
    this.myRank=Util.GetGameObject(this.bottomView,"MyRank/Text"):GetComponent("Text")
    this.info=Util.GetGameObject(this.bottomView,"Info"):GetComponent("Text")
    this.curRewardRoot=Util.GetGameObject(this.bottomView,"CurRankReward/RewardRoot")--当前名次奖励根节点
    this.curRewardRootMask=Util.GetGameObject(this.bottomView,"CurRankReward/RewardRoot"):GetComponent("Image")--特效遮罩
    this.curRewardItemList={}

    this.scrollRoot=Util.GetGameObject(this.bottomView,"ScoreRanking/ScrollRoot")--寻仙积分排行榜滚动条根节点
    this.rankPre=Util.GetGameObject(this.bottomView,"ScoreRanking/RankPre")--排行条预设
    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollRoot.transform,this.rankPre, nil,--
            Vector2.New(this.scrollRoot.transform.rect.width,this.scrollRoot.transform.rect.height),1,1,Vector2.New(0,0))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.noticeView=Util.GetGameObject(this.gameObject,"NoticeView")
    this.leftBtn=Util.GetGameObject(this.noticeView,"LeftBtn")
    this.leftBtnBg=Util.GetGameObject(this.leftBtn,"Bg"):GetComponent("Image")
    this.rightBtn=Util.GetGameObject(this.noticeView,"RightBtn")
    this.rightBtnBg=Util.GetGameObject(this.rightBtn,"Bg"):GetComponent("Image")
    this.addNum=0 --切换按钮数据
    this.infoTipImage=Util.GetGameObject(this.noticeView,"InfoTip"):GetComponent("Image")
    this.curRankBtn=Util.GetGameObject(this.noticeView,"CurRankBtn")--本期排行

    this.btnPreview = Util.GetGameObject(this.gameObject, "btnPreview")

    -- 每次打开清理下重新加载
    FindFairyManager.rankRewardData={}
    FindFairyManager.SetRankRewardData()
    this.curHeroData={}
    this.nextHeroData={}

    -- 关于抽卡的LotterySetting数据
    local curActivityId=ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    recruitType[1]=ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"PerCount",1,"ActivityId",curActivityId).Id
    recruitType[2]=ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"PerCount",10,"ActivityId",curActivityId).Id
    -- onceData =ConfigManager.GetConfigData(ConfigName.LotterySetting, recruitType[1])
    -- moreData=ConfigManager.GetConfigData(ConfigName.LotterySetting,recruitType[2])
end

function this:BindEvent()
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.FindFairy,this.helpPos.x,this.helpPos.y)
    end)
    --积分奖励按钮
    Util.AddClick(this.integralRewardBtn,function()
        this.curRewardRootMask.enabled=false
        UIManager.OpenPanel(UIName.FindFairyPopup,FIND_FAIRY_POPUP_TYPE.ScoreReward)
    end)
    --寻仙榜按钮
    Util.AddClick(this.findRankBtn,function()
        this.curRewardRootMask.enabled=false
        UIManager.OpenPanel(UIName.FindFairyPopup,FIND_FAIRY_POPUP_TYPE.FindFairyRecord)
    end)
    --出海一次按钮
    Util.AddClick(this.onceBtn,function()
        FindFairyManager.isGoToSea=true
        local d=RecruitManager.GetExpendData(recruitType[1])
        if BagManager.GetItemCountById(d[1])<d[2] and PrivilegeManager.GetPrivilegeRemainValue(32)<=0 then
            -- PopupTipPanel.ShowTip(itemConfig[d[1]].Name.."数量不足！")
            UIManager.OpenPanel(UIName.ShopExchangePopup, SHOP_TYPE.FUNCTION_SHOP, 10013, GetLanguageStrById(10646))
            return
        end
        RecruitManager.RecruitRequest(recruitType[1], function(msg)
            UIManager.OpenPanel(UIName.SecretBoxBuyOnePanel,msg.drop,recruitType[1])
        end,configure.privilegeId)
    end)
    --出海十次按钮
    Util.AddClick(this.tenthBtn,function()
        FindFairyManager.isGoToSea=true
        -- if PrivilegeManager.GetPrivilegeRemainValue(32)<=10 then
        --     if BagManager.GetItemCountById(87)<moreData.CostItem[1][2] then
        --         if BagManager.GetItemCountById(16)<moreData.CostItem[2][2] then
        --             UIManager.OpenPanel(UIName.ShopExchangePopup, SHOP_TYPE.FUNCTION_SHOP, 10013, "兑换妖晶")
        --             return
        --         end
        --     end
        -- end
        -- NetManager.RecruitRequest(recruitType[2],function(msg)
        --     UIManager.OpenPanel(UIName.SecretBoxBuyTenPanel,msg.drop,recruitType[2])
        -- end)
        local d=RecruitManager.GetExpendData(recruitType[2])
        if BagManager.GetItemCountById(d[1])<d[2] and PrivilegeManager.GetPrivilegeRemainValue(32)<=0 then
            -- PopupTipPanel.ShowTip(itemConfig[d[1]].Name.."数量不足！")
            UIManager.OpenPanel(UIName.ShopExchangePopup, SHOP_TYPE.FUNCTION_SHOP, 10013, GetLanguageStrById(10646))
            return
        end
        RecruitManager.RecruitRequest(recruitType[2], function(msg)
            UIManager.OpenPanel(UIName.SecretBoxBuyTenPanel,msg.drop,recruitType[2])
        end,configure.privilegeId)
    end)
    --排名大奖
    Util.AddClick(this.bigRankBtn,function()
        this.curRewardRootMask.enabled=false
        UIManager.OpenPanel(UIName.FindFairyPopup,FIND_FAIRY_POPUP_TYPE.BigRank)
    end)
    --本期排行
    Util.AddClick(this.curRankBtn,function()
        UIManager.OpenPanel(UIName.FindFairyPopup,FIND_FAIRY_POPUP_TYPE.CurScoreRank)
    end)
    --预告左按钮
    Util.AddClick(this.leftBtn,function()
        this.SwitchNoticeShow(NoticeBtnType.Left)
    end)
    --预告右按钮
    Util.AddClick(this.rightBtn,function()
        this.SwitchNoticeShow(NoticeBtnType.Right)
    end)
    --卡池预览按钮
    Util.AddClick(this.btnPreview, function ()
        UIManager.OpenPanel(UIName.RewardPreviewPopup, PRE_REWARD_POOL_TYPE.GHOST_FIND)
    end)
    --放大镜弹详情
    Util.AddClick(this.click, function ()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, heroData.Id, heroData.Star)
    end)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.FindFairy.RefreshRedPoint,this.CheckRedPoint)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.FindFairy.RefreshRedPoint,this.CheckRedPoint)
end

function this:OnShow(_sortingOrder)
    sortingOrder = _sortingOrder
    FindFairyManager.NoticeState=0--默认是活动状态(非预告状态)

    ---------------------
    RecruitManager.freeUseTimeList[32]=PrivilegeManager.GetPrivilegeRemainValue(32)
    ---------------------
    this.SetHeroInfo()
    if FindFairyManager.GetActivityTime()<=0 then
        this.OpenNotice()
        return
    end
    CheckRedPointStatus(RedPointType.FindFairy_OneView)

    this.TimeCountDown(FindFairyManager.GetActivityTime())
    this.GetRankRequest()
end

function this:OnClose()
    if this.liveNode then
        poolManager:UnLoadLive(this.liveName, this.liveNode)
        this.liveName=nil
    end
    if this.nextLiveNode then
        poolManager:UnLoadLive(this.nextLiveName, this.nextLiveNode)
        this.nextLiveName=nil
    end
end

function this:OnDestroy()
    this.scrollView=nil
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    btnList={}
end


--活动时间倒计时
function this.TimeCountDown(timeDown)
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    this.activityTime.text = GetLanguageStrById(10028)..TimeToDHMS(timeDown)
    this.timer = Timer.New(function()
        if timeDown < 1 then
            
            this.timer:Stop()
            this.timer = nil
            this.OpenNotice()
            return
            --this:ClosePanel()
        end
        timeDown = timeDown - 1
        this.activityTime.text = GetLanguageStrById(10028)..TimeToDHMS(timeDown)--DateUtils.GetTimeFormatV2
    end, 1, -1, true)
    this.timer:Start()
end

--获取排行请求
function this.GetRankRequest()
    NetManager.RequestRankInfo(RANK_TYPE.FINDFAIRY_RANK,function(msg)
        this.SetCurRankReward(msg.myRankInfo)
        this.SetScoreRankingList(msg.ranks)
        this.SetOtherShow()
    end,FindFairyManager.GetCurActivityId())
end

--设置英雄信息
function this.SetHeroInfo()
    --先清除一遍立绘 防止别的子活动结束时跳转至主面板 立绘未及时清理
    if this.liveNode then
        poolManager:UnLoadLive(this.liveName, this.liveNode)
        this.liveName=nil
    end
    if this.nextLiveNode then
        poolManager:UnLoadLive(this.nextLiveName, this.nextLiveNode)
        this.nextLiveName=nil
    end

    local curActivityId=ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    heroData=FindFairyManager.GetHeroData(curActivityId)
    this.curHeroData={}
    this.curHeroData=heroData
    --创建立绘
    -- if this.liveNode then
    --     poolManager:UnLoadLive(this.liveName, this.liveNode)
    --     this.liveName=nil
    -- end
    local artData=ConfigManager.GetConfigData(ConfigName.ArtResourcesConfig,heroData.Live)
    this.liveName = artData.Name
    this.liveNode = poolManager:LoadLive(this.liveName, this.curLiveRoot.transform, Vector3.one*heroData.Scale , Vector3.one)

    Util.AddOnceClick(this.curLiveRoot.gameObject,function()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup,false,heroData.Id,heroData.Star)
    end)

    this.proImage.sprite=Util.LoadSprite(GetProStrImageByProNum(heroData.PropertyName))
    this.heroName.text= GetLanguageStrById(this.curHeroData.ReadingName)
    this.qualityNum.text=heroData.Natural

    -- 显示Tip图片
    local showArt=ConfigManager.GetConfigData(ConfigName.GlobalActivity,curActivityId).ShowArt
    this.imageTip2.sprite=Util.LoadSprite(ConfigManager.GetConfigData(ConfigName.ArtResourcesConfig,showArt).Name)

    -- 卡池预览按钮
    this.btnPreview.gameObject:SetActive(true)
end

--设置杂项初始化
function this.SetOtherShow()
    local freeTime= PrivilegeManager.GetPrivilegeRemainValue(32)--寻仙免费次数

    --遍历抽卡类型（寻仙活动分多期开启，每期抽卡类型都不一样）
    for i, v in ipairs(recruitType) do
        local d=RecruitManager.GetExpendData(v) --动态地根据抽卡类型获取表数据
        local itemId,itemNum=d[1],d[2]
        local isFree=freeTime and freeTime >= 1 and i==bType.Btn1 or (FindFairyManager.myScore/10%15==0 and FindFairyManager.myScore~=0)--是否为免费
        local o=btnList[i]
        local num=Util.GetGameObject(o,"Consume/Text"):GetComponent("Text")
        local icon=Util.GetGameObject(o,"Consume/Image"):GetComponent("Image")

        icon.gameObject:SetActive(not isFree or i==bType.Btn10)
        if isFree and i==bType.Btn1 then
            num.text= string.format(GetLanguageStrById(10647),freeTime)
        else
            num.text=itemNum
            icon.sprite=Util.LoadSprite(artResourcesConfig[itemConfig[itemId].ResourceID].Name)
        end
    end
end

--设置当前名次奖励
function this.SetCurRankReward(myRankData)
    local myScore=tonumber(myRankData.param1)
    local myRank=tonumber(myRankData.rank)
    FindFairyManager.myScore=myScore --分数保存到本地

    this.info.enabled=myScore==-1
    if myScore==-1 then
        this.myScore.text=GetLanguageStrById(10648)
        this.buyTip.text=GetLanguageStrById(10649)
    else
        this.myScore.text=GetLanguageStrById(10650)..myScore.."</color>"
        local coefficient=ConfigManager.GetConfigData(ConfigName.LotterySpecialConfig,17).Count--保底数
        local count=coefficient- myScore/10%coefficient--计算再买X次必得
        this.buyTip.text=GetLanguageStrById(10651)..count..GetLanguageStrById(10652)
    end
    if myRank==-1 then this.myRank.text=GetLanguageStrById(10653) else this.myRank.text=GetLanguageStrById(10654)..myRank.."</color>" end

    for i = 1, #FindFairyManager.rankRewardData do
        --前3档奖励
        if myRank<=3 and i==myRank then
            FindFairyManager.ResetItemView(this.bottomView,this.curRewardRoot.transform,
                    this.curRewardItemList,3,0.9,sortingOrder,false,FindFairyManager.rankRewardData[i].RankingReward)
            --后续各档位奖励
        elseif myRank>3 and myRank>=FindFairyManager.rankRewardData[i].MinRank and myRank<=FindFairyManager.rankRewardData[i].MaxRank then
            FindFairyManager.ResetItemView(this.bottomView,this.curRewardRoot.transform,
                    this.curRewardItemList,3,0.9,sortingOrder,false,FindFairyManager.rankRewardData[i].RankingReward)
        end
    end
end

--设置寻仙积分排行榜
function this.SetScoreRankingList(data)
    this.scrollView:SetData(data,function(index,root)
        this.SetRankingListShow(root,data[index])
    end)
    this.scrollView:SetIndex(1)
end
function this.SetRankingListShow(root,data)
    local line=Util.GetGameObject(root,"Line1"):GetComponent("Image")
    local rank=Util.GetGameObject(root,"Rank"):GetComponent("Text")
    local name=Util.GetGameObject(root,"Name"):GetComponent("Text")
    local score=Util.GetGameObject(root,"Score"):GetComponent("Text")

    line.enabled=data.rankInfo.rank==1--不是第一名时关闭线1
    rank.text=data.rankInfo.rank
    name.text=data.userName
    score.text=data.rankInfo.param1
end

--本地红点显隐
function this.CheckRedPoint()
    this.onceBtnRedPoint.enabled = FindFairyManager.CheckOnceSea()
    this.integralRewardBtnRedPoint.enabled =FindFairyManager.CheckRewardBtn()
end

--打开预告
function this.OpenNotice()
    FindFairyManager.NoticeState=1
    CheckRedPointStatus(RedPointType.FindFairy_OneView)
    --开闭显隐
    this.middleView:SetActive(false)
    this.bottomView:SetActive(false)
    this.noticeView:SetActive(true)
    this.SwitchNoticeShow(NoticeBtnType.Left)
    FindFairyPanel:NoticeCountDown(FindFairyManager.GetActivityTime()+86400)

    NetManager.GetFindFairyRequest(ActivityTypeDef.FindFairy,function(msg)
        this.activityTime.text=TimeStampToDateStr(tonumber(msg.time))

        local heroData=FindFairyManager.GetHeroData(msg.id)
        this.nextHeroData={}
        this.nextHeroData=heroData

        if this.nextLiveNode then
            poolManager:UnLoadLive(this.nextLiveName, this.liveNode)
            this.nextLiveName=nil
        end
        local artData=ConfigManager.GetConfigData(ConfigName.ArtResourcesConfig,heroData.Live)
        -- this.nextHeroName=heroData.ReadingName
        this.nextLiveName = artData.Name
        this.nextLiveNode = poolManager:LoadLive(this.nextLiveName, this.nextLiveRoot.transform, Vector3.one*heroData.Scale , Vector3.one)
    end)
end

--预告倒计时
function FindFairyPanel:NoticeCountDown(timeDown)
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    this.timer = Timer.New(function()
        if timeDown < 1 then
            this.timer:Stop()
            this.timer = nil
            self:ClosePanel()
            return
        end
        timeDown = timeDown - 1
        
    end, 1, -1, true)
    this.timer:Start()
end

--点击左右按钮 控制活动期内容切换
function this.SwitchNoticeShow(btnType)
    this.curRankBtn:SetActive(btnType==NoticeBtnType.Left)--本期排行
    this.activityTime.gameObject:SetActive(btnType==NoticeBtnType.Right)--活动时间
    this.leftBtn:GetComponent("Button").interactable=btnType==NoticeBtnType.Right--左按钮可点击
    this.rightBtn:GetComponent("Button").interactable=btnType==NoticeBtnType.Left--右按钮可点击
    Util.SetGray(this.leftBtn,btnType==NoticeBtnType.Left)
    Util.SetGray(this.rightBtn,btnType==NoticeBtnType.Right)

    if btnType==NoticeBtnType.Left then
        this.addNum=this.addNum-1
        if this.addNum<=0 then this.addNum=0 end
        this.btnPreview.gameObject:SetActive(true)
        this.infoTipImage.sprite=Util.LoadSprite(NoticeInfoImage[1])
        this.heroName.text=GetLanguageStrById(this.curHeroData.ReadingName)
        this.proImage.sprite=Util.LoadSprite(GetProStrImageByProNum(this.curHeroData.PropertyName))
        this.qualityNum.text=this.curHeroData.Natural
        this.liveRoot:GetComponent("RectTransform"):DOAnchorPosX(0, 0.5, true)
        this.activityTime.gameObject:GetComponent("RectTransform"):DOAnchorPosY(-575,0,true)
    elseif btnType==NoticeBtnType.Right then
        this.addNum=this.addNum+1
        if this.addNum>=1 then this.addNum=1 end
        this.btnPreview.gameObject:SetActive(false)
        this.infoTipImage.sprite=Util.LoadSprite(NoticeInfoImage[2])
        this.heroName.text=GetLanguageStrById(this.nextHeroData.ReadingName)
        this.proImage.sprite=Util.LoadSprite(GetProStrImageByProNum(this.nextHeroData.PropertyName))
        this.qualityNum.text=this.nextHeroData.Natural
        this.liveRoot:GetComponent("RectTransform"):DOAnchorPosX(-1500, 0.5, true)
        this.activityTime.gameObject:GetComponent("RectTransform"):DOAnchorPosY(-593.5,0,true)
    end
end

return this