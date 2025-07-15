--混乱之治挑战相关
local this = {}
local rankInfo={


    [1] = {
        campType=1,
        btn = nil,
        recommendImage  = nil,
        battleNum = nil,
        personNum = nil,
    },
    [2] = {
        campType=2,
        btn = nil,
        recommendImage  = nil,
        battleNum = nil,
        personNum = nil,
    },
    [3] = {
        campType=3,
        btn = nil,
        recommendImage  = nil,
        battleNum = nil,
        personNum = nil,
    }, 
}
local matchType = 1   -- 1免费    2付费
local matchTimeID = 520
local matchDiamodID = 521
local buyChanllengeNumID = 524
local itemsData ={}
local timeNum = 0
local piPeiData={}
local battleTeams={}
local isInBattle = false
function this:InitComponent(gameObject)
    this.gameObject = Util.GetGameObject(gameObject, "ChallengePanel")
    --topinfo
    this.titleBg = Util.GetGameObject(gameObject, "Top/TitleBg"):GetComponent("Image")
    this.campBg = Util.GetGameObject(gameObject, "Top/MyInfo/Top/BG"):GetComponent("Image")
    this.signImg = Util.GetGameObject(gameObject, "Top/MyInfo/Top/SignImg"):GetComponent("Image")
    this.rankImg = Util.GetGameObject(gameObject, "Top/MyInfo/Top/RankImg"):GetComponent("Image")
    this.zhiPeiBg = Util.GetGameObject(gameObject, "Top/MyInfo/Bottom/BG"):GetComponent("Image")
    this.zhipeiText = Util.GetGameObject(gameObject, "Top/MyInfo/Bottom/ZhipeiText"):GetComponent("Text")
    this.campText = Util.GetGameObject(gameObject, "Top/MyInfo/Bottom/CampText"):GetComponent("Text")
    this.campValueText = Util.GetGameObject(gameObject, "Top/MyInfo/Bottom/CampValueText"):GetComponent("Text")
    this.myText = Util.GetGameObject(gameObject, "Top/MyInfo/Bottom/MyText"):GetComponent("Text")
    this.myZhiPeiValue = Util.GetGameObject(gameObject, "Top/MyInfo/Bottom/MyZhiPeiValue"):GetComponent("Text")
    this.campNametext = Util.GetGameObject(gameObject, "Top/MyInfo/Top/CampNametext"):GetComponent("Text")
    this.campPersonNum = Util.GetGameObject(gameObject, "Top/MyInfo/Top/CampPersonNum"):GetComponent("Text")
    this.campRankText = Util.GetGameObject(gameObject, "Top/MyInfo/Top/CampRankText"):GetComponent("Text")
    -- right rankInfo
    this.rightTopBG = Util.GetGameObject(gameObject, "Top/Rank_twoInfo/RankBG"):GetComponent("Image")
    this.rightTopRankImg = Util.GetGameObject(gameObject, "Top/Rank_twoInfo/RankImg"):GetComponent("Image")
    this.rightTopName = Util.GetGameObject(gameObject, "Top/Rank_twoInfo/RankNametext"):GetComponent("Text")
    this.rightTopZhiPei = Util.GetGameObject(gameObject, "Top/Rank_twoInfo/Zhipei/Text"):GetComponent("Text")
    this.rightBottomBG = Util.GetGameObject(gameObject, "Top/Rank_threeInfo/RankBG"):GetComponent("Image")
    this.rightBottomRankImg = Util.GetGameObject(gameObject, "Top/Rank_threeInfo/RankImg"):GetComponent("Image")
    this.rightBottomName = Util.GetGameObject(gameObject, "Top/Rank_threeInfo/RankNametext"):GetComponent("Text")
    this.rightBottomZhiPei = Util.GetGameObject(gameObject, "Top/Rank_threeInfo/Zhipei/Text"):GetComponent("Text")
    --Btns
    this.helpBtn =  Util.GetGameObject(gameObject, "Top/RightBtn/HelpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition
    this.shopBtn =  Util.GetGameObject(gameObject, "Top/RightBtn/ShopBtn")
    this.mtchColling = Util.GetGameObject(gameObject, "Middle/Bottom/Btns/MtchColling") --消费匹配
    this.timeText = Util.GetGameObject(gameObject, "Middle/Bottom/Btns/MtchColling/MtchTimeText"):GetComponent("Text") --倒计时
    this.piPeiBtn = Util.GetGameObject(gameObject, "Middle/Bottom/Btns/PiPeiBtn") 
    this.buymatchBtn = Util.GetGameObject(gameObject, "Middle/Bottom/Btns/MtchColling/BuymatchBtn")
    this.buyImg = Util.GetGameObject(gameObject, "Middle/Bottom/Btns/MtchColling/BuymatchBtn/DimodImg"):GetComponent("Image")
    this.buyItemNum = Util.GetGameObject(gameObject, "Middle/Bottom/Btns/MtchColling/BuymatchBtn/Text"):GetComponent("Text")
    this.taskBtn = Util.GetGameObject(gameObject, "Middle/Bottom/CampBtn")
    this.taskBtnRedpot = Util.GetGameObject(gameObject, "Middle/Bottom/CampBtn/redpot")
    this.campBtn = Util.GetGameObject(gameObject, "Middle/Bottom/Btns/FsBtn")
    this.addBtn = Util.GetGameObject(gameObject, "Middle/Bottom/addBtn")


    --challenge nums
    this.challengeNum = Util.GetGameObject(gameObject, "Middle/Bottom/ChallengeNumText"):GetComponent("Text")
    this.residueBuyNum = Util.GetGameObject(gameObject, "Middle/Bottom/ShengyuNumText"):GetComponent("Text")
    --pipei View
    this.noPersonView = Util.GetGameObject(gameObject, "Middle/NoPerson")
    this.piPeiView = Util.GetGameObject(gameObject, "Middle/Content")
     
    this.mask = Util.GetGameObject(gameObject, "Middle/Content/Mask")
    this.maskTips = Util.GetGameObject(gameObject, "Middle/Content/Mask/Text1"):GetComponent("Text")
    --  huadong view
    this.scroll = Util.GetGameObject(self.piPeiView.gameObject, "MatchScrollView")
    this.prefab = Util.GetGameObject(self.piPeiView.gameObject, "MatchItem")
    local v2 = this.scroll.transform.rect
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        this.prefab, nil, Vector2.New(v2.width, v2.height), 1, 1, Vector2.New(5, 5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
   --zhi  hui
   this.buyMatchChildImg = Util.GetGameObject(gameObject, "Middle/Bottom/Btns/MtchColling/BuymatchBtn/ShuaImage")
   this.buyMatchDimodImg = Util.GetGameObject(gameObject, "Middle/Bottom/Btns/MtchColling/BuymatchBtn/DimodImg")
   this.campChildImg = Util.GetGameObject(gameObject, "Middle/Bottom/Btns/FsBtn/ShuaImage")
   this.piPeiChildImg = Util.GetGameObject(gameObject, "Middle/Bottom/Btns/PiPeiBtn/ShuaImage") 
   
end

function this:SetScroll()
    this.data = itemsData
    this.scrollView:SetData(this.data, function(index, root)
        this:SetScrollItem(root, this.data[index], index)
    end)
end
function this:SetChallangeStar(go,star)
    local star_1 = Util.GetGameObject(go, "Right/ChallengeOk/WinImg/xing_1")
    local star_2 = Util.GetGameObject(go, "Right/ChallengeOk/WinImg/xing_2")
    local star_3 = Util.GetGameObject(go, "Right/ChallengeOk/WinImg/xing_3")

    if star == 1 then
        star_1.gameObject:SetActive(true)
        star_2.gameObject:SetActive(false)
        star_3.gameObject:SetActive(false)
    elseif star == 2 then
        star_1.gameObject:SetActive(true)
        star_2.gameObject:SetActive(true)
        star_3.gameObject:SetActive(false)
    elseif star == 3 then
        star_1.gameObject:SetActive(true)
        star_2.gameObject:SetActive(true)
        star_3.gameObject:SetActive(true)
    end
end


--设置匹配item数据
function this:SetScrollItem(go, data, index)
      --设置头像
      local data = data
      local hedaParent = Util.GetGameObject(go.gameObject, "Head")
      local child  =   hedaParent.transform:GetChild(0)
      if child then
        destroy(child.gameObject)
      end
      
      local  playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, hedaParent.transform)
         playerHead:Reset()
         playerHead:SetScale(Vector3.one * 0.55)
         playerHead:SetHead(data.userSimpleInfo.headIcon)
         playerHead:SetFrame(data.userSimpleInfo.headFrame)
         playerHead:SetLevel(data.userSimpleInfo.level)
     
     local singnImg = Util.GetGameObject(go.gameObject, "SignImg"):GetComponent("Image")
     singnImg.sprite = Util.LoadSprite("cn2-X1_hunluanzhizhi_biaozhi_0"..data.userSimpleInfo.camp)  --
     local singnBg = Util.GetGameObject(go.gameObject, "SignBG"):GetComponent("Image")
     singnBg.sprite = Util.LoadSprite("cn2-X1_hunluanzhizhi_yansediban_0"..data.userSimpleInfo.camp)  --
      --Log("__________________data.userSimpleInfo.level   "..data.userSimpleInfo.level.."_______________    "..data.userSimpleInfo.camp)
     local name = Util.GetGameObject(go.gameObject, "nameText"):GetComponent("Text")
     name.text =SetRobotName(data.userSimpleInfo.userId, data.userSimpleInfo.nickName) 

     local zhanliValue = Util.GetGameObject(go.gameObject, "ZhanLiImage/ZhanLiValueText"):GetComponent("Text")
     for _index, _value in ipairs(data.userSimpleInfo.fightMap) do
        if _value.teamId == ChaosManager.zhanliTeamId then
             zhanliValue.text = _value.fight
            break
        end
     end    


     local zhiPeiValue = Util.GetGameObject(go, "ZhiPeiLi/ZhiPeiValueText"):GetComponent("Text")
     zhiPeiValue.text = data.score
      
   --right
     local resultTipText = Util.GetGameObject(go.gameObject, "ChallengeReward/Image/ChallengeText"):GetComponent("Text")
     local resultValueText = Util.GetGameObject(go.gameObject, "ChallengeReward/RewardValueText"):GetComponent("Text")
     local challengeOk = Util.GetGameObject(go.gameObject, "Right/ChallengeOk")
       local challengeBtn = Util.GetGameObject(go, "Right/ChallengeBtn")
        local playBtn = Util.GetGameObject(go, "Right/ChallengeOk/PlayButton")
    --    Log("____________________challengeBtn     "..challengeBtn.name)
      local WinView = Util.GetGameObject(go.gameObject, "ChallengeOk/WinImg")
      local loseView = Util.GetGameObject(go.gameObject, "ChallengeOk/LoseImg")
   
    
     if data.fightResult == 0  then  --没挑战
        challengeOk.gameObject:SetActive(false)
        challengeBtn.gameObject:SetActive(true)
        resultTipText.text = "挑战可得"
         resultValueText.text = "约+"..data.changeScore
         resultValueText.color = UIColor.WHITE
     elseif data.fightResult == 1 then  --胜利
        challengeOk.gameObject:SetActive(true)
        challengeBtn.gameObject:SetActive(false)
        resultTipText.text = "挑战结果"
        resultValueText.color = UIColor.GREEN
        resultValueText.text ="+"..data.changeScore
       WinView.gameObject:SetActive(true)
       loseView.gameObject:SetActive(false)
       this:SetChallangeStar(go,data.battleRecord.star)
     elseif data.fightResult == -1 then--失败
        challengeOk.gameObject:SetActive(true)
        challengeBtn.gameObject:SetActive(false)
        resultTipText.text = "挑战结果"
        resultValueText.color = UIColor.RED
         resultValueText.text ="-"..data.changeScore
        WinView.gameObject:SetActive(false)
        loseView.gameObject:SetActive(true)
     end
     
     Util.AddOnceClick(hedaParent, function()
        local  itemDa={}
        for k, value in ipairs(itemsData) do
           if k==index then
            itemDa = value
           end
         end 
         if itemDa.userSimpleInfo.userId > 100000 then  --非机器人设置详情页
            UIManager.OpenPanel(UIName.PlayerInfoPopup, itemDa.userSimpleInfo.userId, PLAYER_INFO_VIEW_TYPE.ChaosZZ,nil,PlayerInfoType.CSArena)
         else
            UIManager.OpenPanel(UIName.PlayerInfoPopup, itemDa.userSimpleInfo.userId, PLAYER_INFO_VIEW_TYPE.NORMAL,nil,PlayerInfoType.CSArena)   --机器人显示主线
         end   
    end)
     Util.AddClick(challengeBtn, function ()
       local  itemD={}
        for i, v in ipairs(itemsData) do
            if i==index then
                itemD = v
            end
         end    
       
            if this:isXiuZhan() then
                this:RefreshMaskView()
            else
                if ChaosManager:GetIsOpen() then
                    if ChaosManager.challengeNums > 0 then
                        ChaosManager:SetSelectData(itemD)    --设置选择挑战数据
                        ChaosManager:SetItemsData(itemsData)
                      
                        UIManager.OpenPanel(UIName.ChaosChangeStarPanel)
                    else
                        PopupTipPanel.ShowTip("挑战次数不足")
                    end
                end
            end
     end)
     
     Util.AddClick(playBtn, function()
        if ChaosManager:GetIsOpen() then
            local data ={}
            for _i, _v in ipairs(itemsData) do
                if _i==index then
                    data = _v
                end
              end    
            ChaosManager:SetSelectData(data)
    
            if BattleManager.IsInBackBattle() then
                return
            end
    
            if isInBattle then
                return
            end
            isInBattle = true
             local redData ={}
             local blueData ={}
    
             for index, value in ipairs(battleTeams) do
                 if value.uid == PlayerManager.uid then
                     redData = value
                     break
                 end
             end    
             for i, v in ipairs(battleTeams) do
                 if v.uid == data.userSimpleInfo.userId then
                     blueData = v
                     break
                 end
             end   
             
             BattleManager.GotoFight(function()
                 local structA = {
                     head = PlayerManager.head,
                     headFrame = PlayerManager.frame,
                     name = PlayerManager.nickName,
                     formationId = redData.team.formationId or 1,
                     investigateLevel = redData.investigateLevel 
                 }
                 local structB = {
                     head = data.userSimpleInfo.headIcon,
                     headFrame = data.userSimpleInfo.headFrame,
                     name = data.userSimpleInfo.nickName,
                     formationId = blueData.team.formationId or 1,
                     investigateLevel = blueData.investigateLevel
                 }
                 BattleManager.SetAgainstInfoData(nil, structA, structB)
             
                 LaddersArenaManager.drop = nil
                 
                 UIManager.OpenPanel(UIName.BattleStartPopup, function()
           
                        local fightData  = BattleManager.GetBattleServerData({fightData = data.battleRecord.fightData}, 1)
                   
                     local battlePanel = UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function ()
                         BattleRecordManager.SetBattleBothNameStr(PlayerManager.nickName.."|".. data.userSimpleInfo.nickName)
                        -- isInBattle = false
                     end)
                     battlePanel:ShowNameShow(data.userSimpleInfo.fightResult, nil)
                 end)
             end)
        end
       
    end)
  

   
end

--是否有匹配对手view
function this:SetMiddleView(data)
   if #data > 0 then
     itemsData = data
        this.noPersonView.gameObject:SetActive(false)
        this.piPeiView.gameObject:SetActive(true)
        this:SetScroll()
   else
    if this:isXiuZhan() then
        this.piPeiView.gameObject:SetActive(true)
    else
        this.piPeiView.gameObject:SetActive(false)
    end
        this.noPersonView.gameObject:SetActive(true)

   end
end



--刷新挑战次数
function this:RefreshChallengeNum()
      
        this.challengeNum.text  = ChaosManager.challengeNums
        this.residueBuyNum.text = ChaosManager.challengeBuyNums 
end
--g购买挑战
function this:BuyChallengeNum(data)
       if data then
            ChaosManager.challengeNums = data.challengeNums
            ChaosManager.challengeBuyNums = data.challengeBuyNums
            this.challengeNum.text  = data.challengeNums
            this.residueBuyNum.text = data.challengeBuyNums
       end    
end

function this:SetTopRank(data)
    local index = 0
    for k,v in ipairs(data.campSimpleInfos) do
        if v.camp ~= data.selfCamp then
            if index == 0 then
                this.rightTopBG.sprite =Util.LoadSprite("cn2-X1_hunluanzhizhi_zhenyingdiban_R"..v.camp)
                -- this.rightTopName.text = v.camp
                this:SetName(v.camp,this.rightTopName)
                 this.rightTopZhiPei.text = ChaosManager:UnitConversion(v.totalScore)
                 if k == 1 then
                    this.rightTopRankImg.sprite =  Util.LoadSprite("cn2-X1_tongyong_diyi")
                 elseif k  == 2 then
                    this.rightTopRankImg.sprite =  Util.LoadSprite("cn2-X1_tongyong_dier")
                 elseif k  == 3 then
                    this.rightTopRankImg.sprite =  Util.LoadSprite("cn2-X1_tongyong_disan")
                 end  
               
                index = index+1
            else
                this.rightBottomBG.sprite = Util.LoadSprite("cn2-X1_hunluanzhizhi_zhenyingdiban_R"..v.camp)
                 if k == 1 then
                    this.rightBottomRankImg.sprite =  Util.LoadSprite("cn2-X1_tongyong_diyi")
                 elseif k  == 2 then
                    this.rightBottomRankImg.sprite =  Util.LoadSprite("cn2-X1_tongyong_dier")
                 elseif k  == 3 then
                    this.rightBottomRankImg.sprite =  Util.LoadSprite("cn2-X1_tongyong_disan")
                 end  
                 --this.rightBottomName.text = v.camp
                 this:SetName(v.camp,this.rightBottomName)
                this.rightBottomZhiPei.text =ChaosManager:UnitConversion(v.totalScore)
            end
            
        end
    end    
end

function this:SetMyInfoImage(data,rank)
     this.titleBg.sprite =  Util.LoadSprite("cn2-X1_hunluanzhizhi_banner_0"..data.selfCamp)
     this.campBg.sprite =  Util.LoadSprite("cn2-X1_hunluanzhizhi_zhenyingdiban_0"..data.selfCamp)
     this.signImg.sprite =  Util.LoadSprite("cn2-X1_hunluanzhizhi_biaozhi_0"..data.selfCamp)   --
     if rank== 1 then
        this.rankImg.sprite =  Util.LoadSprite("cn2-X1_tongyong_diyi")
     elseif rank  == 2 then
        this.rankImg.sprite =  Util.LoadSprite("cn2-X1_tongyong_dier")
     elseif rank  == 3 then
        this.rankImg.sprite =  Util.LoadSprite("cn2-X1_tongyong_disan")
     end  
     this.zhiPeiBg.sprite =  Util.LoadSprite("cn2-X1_hunluanzhizhi_zhipeilidiban_0"..data.selfCamp)
     
end


--刷新顶部信息
function this:RefreshTopInfo()
    local data = ChaosManager:GetChallegeData()
    local myInfo = {}
    local myrank = 3
    if data then
        for k,v in ipairs(data.campSimpleInfos) do
            if v.camp == data.selfCamp then
                myInfo = v
                myrank = k
                break
            end
        end    
        --my 
        this.campValueText.text = ChaosManager:UnitConversion(myInfo.totalScore)
        this.myZhiPeiValue.text = data.selfScore
        this.campPersonNum.text = myInfo.totalNum
        ChaosManager.MyCampRank = myrank 
        this:SetMyInfoImage(data,myrank)
        this:SetTopRank(data)
       -- this.campNametext.text = myInfo.camp
        this:SetName(myInfo.camp,this.campNametext)
    end
end
function this:SetName(id,Text)
    if id == 1 then
        Text.text = "秩序阵营"
    elseif id==2 then
        Text.text = "混沌阵营"
    elseif id==3 then
        Text.text = "腐化阵营"
    end
end
--刷新顶部信息    1显示匹配   2显示付费
function this:RefreshBottomBtns(index)
    if index == 1 then
        this.mtchColling.gameObject:SetActive(false)
        this.piPeiBtn.gameObject:SetActive(true)
    elseif index == 2 then
        this.mtchColling.gameObject:SetActive(true)
        this.piPeiBtn.gameObject:SetActive(false)
    end
end
--
function this:InitBuyBtnInfo()
    local config = ChaosManager:GetSpecialConfigData()
   
    local splitData = string.split(config[matchDiamodID].Value,"#")
    local artResourcesConfig =  ChaosManager:GetArtResourcesConfigData()
    local  itemConfig =ChaosManager:GetItemConfigData()
    local index =splitData[1]+0
    local  resId = itemConfig[index].ResourceID
    local imgsprite= artResourcesConfig[resId].Name --消耗资源img  名字
    this.buyImg.sprite = Util.LoadSprite(imgsprite)
    this.buyItemNum.text = splitData[2]
end

function this:RefreshView()
    NetManager.CampWarInfoGetReq(function (msg)
        this:RefreshMaskView()
        this:RefreshChallengeNum()
        this:RefreshTopInfo()
        this:InitBuyBtnInfo()
        this:RefreshChallengeItems(msg)
        this:RefreshTime()
        isInBattle = false
    end)
   
    -- CheckRedPointStatus(RedPointType.Chaos_MainIcon)
end
function this:RefreshMaskView()
    local config = ChaosManager:GetSpecialConfigData()
    local splitData = string.split(config[526].Value,"#")
    if this:isXiuZhan() then
        this.mask:SetActive(true)
        this:SetBtnInteractable(false)
        Log("休战期")
    else
        this.mask:SetActive(false)
        this:SetBtnInteractable(true)
        Log("非休战")
    end
    this.maskTips.text = "每日"..splitData[1].."点到"..splitData[2].."点为休战期"
end

function this:SetBtnInteractable(bol)
    this.campBtn:GetComponent("Button").interactable = bol
    this.taskBtn:GetComponent("Button").interactable = bol
    this.addBtn:GetComponent("Button").interactable = bol
    this.buymatchBtn:GetComponent("Button").interactable = bol
    this.buyMatchChildImg:GetComponent("Button").interactable = bol
    this.buyMatchDimodImg:GetComponent("Button").interactable = bol
    this.campChildImg:GetComponent("Button").interactable = bol
    this.piPeiChildImg:GetComponent("Button").interactable = bol
    this.piPeiBtn:GetComponent("Button").interactable = bol
end
function this:isXiuZhan()
    local config = ChaosManager:GetSpecialConfigData()
    local splitData = string.split(config[526].Value,"#")
    local time1 = Today_N_OClockTimeStamp(splitData[1])
    local time2 =  Today_N_OClockTimeStamp(splitData[2])
    local  serverTime = GetTimeStamp()
    if serverTime>= time1 and serverTime <= time2 then
       return true
    else
        return false
    end
end

function this:RefreshTime()
    if this.TimeCounter then
        this.TimeCounter:Stop()
        this.TimeCounter = nil
        timeNum = 0
    end
    this.TimeCounter = Timer.New(this.TimeUpdate, 1, -1, true)
    this.TimeCounter:Start()
    this:TimeUpdate()
end
--
function this:TimeUpdate()
    local specialConfigData =   ChaosManager:GetSpecialConfigData()  
    local startTime =ChaosManager.lastMatchTime
    local endTime = math.floor(GetTimeStamp()- startTime)  --服务器当前时间  减去点击匹配时的时间
    
    if endTime >= specialConfigData[matchTimeID].Value+0 then
        this:RefreshBottomBtns(1)
        matchType = 1
        if this.TimeCounter then
            this.TimeCounter:Stop()
            this.TimeCounter = nil
        end
    else
        timeNum = 0--timeNum + 1
        local leftTime = math.floor(specialConfigData[matchTimeID].Value + 0 - endTime)
        this:RefreshBottomBtns(2)
        matchType = 2
        this.timeText.text = TimeToHMS(leftTime)
    end
      

end
--匹配按钮点击
function this:PiPeiBtnOnclick()
    -- local time = ActTimeCtrlManager.GetActLeftTime(FUNCTION_OPEN_TYPE.ChaosZZ)
    -- if time <= 0 then
    --     PopupTipPanel.ShowTip(GetLanguageStrById(10029))
    --     return
    -- end
    local isMatch = this:GetMatchTimeOk()
    if isMatch then
        NetManager.CampWarMatchReq(matchType,function (msg)
            table.sort(msg.playerInfos, function(a,b) 
                return a.userSimpleInfo.userId < b.userSimpleInfo.userId 
            end)
            piPeiData={}
            piPeiData = msg.playerInfos
            battleTeams = ChaosManager:GetChaosTeams()
            this:SetMiddleView(msg.playerInfos)
            this:RefreshBottomBtns(2)
            this:RefreshTime()
        end)
    end
end

function this:GetMatchTimeOk()
    --设置tips  返回是否可以匹配
         
     --判断玩法结束    “当前处于休战期，无法匹配”  
        if this:isXiuZhan() then
            PopupTipPanel.ShowTip("当前处于休战期，无法匹配")
            return false
        else
           return true
        end

end
--匹配购买按钮点击
function this:BuyMatchBtnOnclick()
    -- local time = ActTimeCtrlManager.GetActLeftTime(FUNCTION_OPEN_TYPE.ChaosZZ)
    -- if time <= 0 then
    --     PopupTipPanel.ShowTip(GetLanguageStrById(10029))
    --     return
    -- end
    local isMatch = this:GetMatchTimeOk()
    if not isMatch then
        return
    end
    local config = ChaosManager:GetSpecialConfigData()
   
    local splitData = string.split(config[matchDiamodID].Value,"#")
    local artResourcesConfig =  ChaosManager:GetArtResourcesConfigData()
    local  itemConfig =ChaosManager:GetItemConfigData()
    local index =splitData[1]+0
    local  resId = itemConfig[index].ResourceID
    local desc= artResourcesConfig[resId].Desc --消耗资源img  名
    local str = splitData[2]..desc.."刷新挑战列表"
  
    local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "HLChallenge")
    local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
    if isPopUp ~= currentTime then
        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Buy, resId, str,function(isShow)
            if isShow then
                local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "HLChallenge", currentTime)
            end
            matchType = 2
            NetManager.CampWarMatchReq(matchType,function (msg)
                table.sort(msg.playerInfos, function(a,b) 
                    return a.userSimpleInfo.userId < b.userSimpleInfo.userId
                end)
                -- 更新items  列表
                 piPeiData={}
                 piPeiData = msg.playerInfos
                 battleTeams = ChaosManager:GetChaosTeams()
                 this:SetMiddleView(msg.playerInfos)
            end)
        end)
    else
        matchType = 2
        NetManager.CampWarMatchReq(matchType,function (msg)
            table.sort(msg.playerInfos, function(a,b) 
                return a.userSimpleInfo.userId < b.userSimpleInfo.userId
            end)
            -- 更新items  列表
             piPeiData={}
             piPeiData = msg.playerInfos
             battleTeams = ChaosManager:GetChaosTeams()
             this:SetMiddleView(msg.playerInfos)
        end)
    end

end


function this:BindEvent()
    BindRedPointObject(RedPointType.Chaos_Task, this.taskBtnRedpot)
    Util.AddClick(this.taskBtn, function ()
        if ChaosManager:GetIsOpen() then
            UIManager.OpenPanel(UIName.ChaosTaskPanel)
        end 
     end)
    Util.AddClick(this.campBtn, function()
        if ChaosManager:GetIsOpen() then
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CHAOS_BATTLE)
        end
        
    end)
    Util.AddClick(this.helpBtn, function()
        if ChaosManager:GetIsOpen() then
            UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.ChaosHelp,this.helpPosition.x-190,this.helpPosition.y+870)  --添加混乱id
        end
        
    end)
    Util.AddClick(this.shopBtn, function()
        if ChaosManager:GetIsOpen() then
            JumpManager.GoJumpAppoint(JumpType.CampWarShop, {SHOP_TYPE.ITEM_SHOP})
        end
       
    end)
    Util.AddClick(this.piPeiBtn, function()
        if ChaosManager:GetIsOpen() then
            this:PiPeiBtnOnclick()
        end
        
    end)
    Util.AddClick(this.buymatchBtn, function()
        if ChaosManager:GetIsOpen() then
            this:BuyMatchBtnOnclick()
        end
       
    end)
    Util.AddClick(this.addBtn, function()
        -- local time = ActTimeCtrlManager.GetActLeftTime(FUNCTION_OPEN_TYPE.ChaosZZ)
        -- if time <= 0 then
        --     PopupTipPanel.ShowTip(GetLanguageStrById(10029))
        --     return
        -- end
        if ChaosManager:GetIsOpen() then
            local config = ChaosManager:GetSpecialConfigData()
   
            local splitData = string.split(config[buyChanllengeNumID].Value,"#")
            local artResourcesConfig =  ChaosManager:GetArtResourcesConfigData()
            local  itemConfig =ChaosManager:GetItemConfigData()
            local index =splitData[1]+0
            local  resId = itemConfig[index].ResourceID
            local desc= artResourcesConfig[resId].Desc --消耗资源img  名
            local str = splitData[2]..desc.."购买挑战次数"
            local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "BuyChallengeNum")
            local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
            if isPopUp ~= currentTime then
                UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Buy, resId, str,function(isShow)
                    if isShow then
                        local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                        RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. "BuyChallengeNum", currentTime)
                    end
                    if ChaosManager.challengeBuyNums > 0 then
                        NetManager.CampWarChallengeNumsBuyReq(function (msg)
                            this:BuyChallengeNum(msg)
                            PopupTipPanel.ShowTip("添加挑战次数成功")
                            CheckRedPointStatus(RedPointType.Chaos_Tab_Chanllege)
                        end)
                    else
                        PopupTipPanel.ShowTip("剩余购买次数不足")
                    end
                  
                end)
            else
                if ChaosManager.challengeBuyNums > 0 then
                    NetManager.CampWarChallengeNumsBuyReq(function (msg)
                        this:BuyChallengeNum(msg)
                        PopupTipPanel.ShowTip("添加挑战次数成功")
                        CheckRedPointStatus(RedPointType.Chaos_Tab_Chanllege)
                    end)
                else
                    PopupTipPanel.ShowTip("剩余购买次数不足")
                end
            end
        end
       
    end)
    
end
--挑战刷新
function this:RefreshChallengeItems(msg)
        battleTeams = ChaosManager:GetChaosTeams()
        table.sort(msg.campWarPlayerInfos, function(a,b) 
            return a.userSimpleInfo.userId < b.userSimpleInfo.userId
        end)
        this:SetMiddleView(msg.campWarPlayerInfos)
end
function this:AddListener()
   -- Game.GlobalEvent:AddEvent(GameEvent.Chaos.RefreshChallengeItems, this.RefreshChallengeItems)
end


function this:RemoveListener()
   -- Game.GlobalEvent:RemoveEvent(GameEvent.Chaos.RefreshChallengeItems, this.RefreshChallengeItems)
end
function this:OnDestroy()
    ClearRedPointObject(RedPointType.Chaos_Task, this.taskBtnRedpot)
    if this.TimeCounter then
        this.TimeCounter:Stop()
        this.TimeCounter = nil
    end
end

return this
