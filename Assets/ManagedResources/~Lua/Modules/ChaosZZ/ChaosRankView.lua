--混乱之治排行榜相关
local this = {}
local sortingOrder = 0
function this:InitComponent(gameObject)
    this.gameObject = Util.GetGameObject(gameObject, "RankPanel")
    this.everyDayBtn=Util.GetGameObject(this.gameObject, "TopBtns/EveryBtn/tab")
    this.everyDayBtnParent=Util.GetGameObject(this.gameObject, "TopBtns/EveryBtn")
    this.everyDayBtnSelect=Util.GetGameObject(this.gameObject, "TopBtns/EveryBtn/tab/select")
    this.campBtn=Util.GetGameObject(this.gameObject, "TopBtns/CampBtn/tab")
    this.campBtnParent=Util.GetGameObject(this.gameObject, "TopBtns/CampBtn")
    this.campBtnSelect=Util.GetGameObject(this.gameObject, "TopBtns/CampBtn/tab/select")
    this.everyPanel = Util.GetGameObject(this.gameObject, "Content/Panel/EveryPanel")
    this.campPanel = Util.GetGameObject(this.gameObject, "Content/Panel/CampPanel")
    --
    this.scroll = Util.GetGameObject(this.gameObject, "Content/Panel/EveryPanel/MyBattleScrollView")
    this.prefab = Util.GetGameObject(this.gameObject, "Content/Panel/ItemPre")
    local v2 = this.scroll.transform.rect
    --每日积分
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        this.prefab, nil, Vector2.New(v2.width, v2.height), 1, 1, Vector2.New(5, 5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
    --阵营
     this.scrollCamp = Util.GetGameObject(this.gameObject, "Content/Panel/CampPanel/ManitoScrollView")
     this.scrollViewCamp = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollCamp.transform,
     this.prefab, nil, Vector2.New(v2.width, v2.height), 1, 1, Vector2.New(5, 5))
     this.scrollViewCamp.moveTween.MomentumAmount = 1
     this.scrollViewCamp.moveTween.Strength = 2
    ---
    this.diyiImg=Util.GetGameObject(this.gameObject, "Content/MyRankInfo/SortNum/SortNum_1"):GetComponent("Image")
    this.dierImg=Util.GetGameObject(this.gameObject,"Content/MyRankInfo/SortNum/SortNum_2"):GetComponent("Image")
    this.disanImg=Util.GetGameObject(this.gameObject, "Content/MyRankInfo/SortNum/SortNum_3"):GetComponent("Image")
    this.rankImg=Util.GetGameObject(this.gameObject, "Content/MyRankInfo/SortNum/SortNum_num")
    this.rankText=Util.GetGameObject(this.gameObject, "Content/MyRankInfo/SortNum/SortNum_num/TitleText"):GetComponent("Text")
    this.myScore=Util.GetGameObject(this.gameObject, "Content/MyRankInfo/infoGo/arenaScore"):GetComponent("Text")
    this.myZhanLi=Util.GetGameObject(this.gameObject, "Content/MyRankInfo/ZhanLiImage/ZhanLiValueText"):GetComponent("Text")
    --未上榜
    this.NoRankTip1=Util.GetGameObject(this.gameObject, "Content/MyRankInfo/Text")
    this.NoRankTip2=Util.GetGameObject(this.gameObject, "Content/MyRankInfo/nameText"):GetComponent("Text")
    this.NoRankTip3=Util.GetGameObject(this.gameObject, "Content/MyRankInfo/ZhanLiImage")
        --初始化直接隐藏
            this.NoRankTip1:SetActive(false)
            this.NoRankTip2.gameObject:SetActive(false)
            this.NoRankTip3:SetActive(false)
            this.myScore.gameObject:SetActive(false)
end

function this:BindEvent()
    Util.AddClick(this.everyDayBtn, function()
        if ChaosManager:GetIsOpen() then
            this:SwitchBtns(1)
        end
    end)
    Util.AddClick(this.campBtn, function()
        if ChaosManager:GetIsOpen() then
            this:SwitchBtns(2)
        end
    end)
end
--显示items  index 对应type
function this:SetEveryScroll(data)
    this.everyPanel:SetActive(true)
    this.campPanel:SetActive(false)
    this.scrollView:SetData(data, function(index, root)
        this:SetScrollItem(root, data[index], index)
    end)
end
--显示items  index 对应type
function this:SetCampScroll(data)
    this.everyPanel:SetActive(false)
    this.campPanel:SetActive(true)
    this.scrollViewCamp:SetData(data, function(index, root)
        this:SetScrollItem(root, data[index], index)
    end)
end
this.playerHead = {}
function this:SetScrollItem(go, data, index)
    local hedaParent = Util.GetGameObject(go.gameObject, "Head")
    if not this.playerHead then
        this.playerHead = {}
    end
    if not this.playerHead[go] then
        this.playerHead[go] = SubUIManager.Open(SubUIConfig.PlayerHeadView, hedaParent.transform)
    end
             this.playerHead[go]:Reset()
             this.playerHead[go]:SetScale(Vector3.one * 0.6)
             this.playerHead[go]:SetHead(data.userSimpleInfo.headIcon)
             this.playerHead[go]:SetFrame(data.userSimpleInfo.headFrame)
             this.playerHead[go]:SetLevel(data.userSimpleInfo.level)
             if data.userSimpleInfo.userId >=10000 then
               this.playerHead[go]:SetViewType(PLAYER_INFO_VIEW_TYPE.ChaosZZ)
                this.playerHead[go]:SetClickedTypeId(PlayerInfoType.CSArena)
                this.playerHead[go]:SetUID(data.userSimpleInfo.userId)
             end
    local name = Util.GetGameObject(go.gameObject, "name"):GetComponent("Text")
    local zhanli = Util.GetGameObject(go.gameObject, "totalForce"):GetComponent("Text")
    local score = Util.GetGameObject(go.gameObject, "integral"):GetComponent("Text")
    local diyiImg = Util.GetGameObject(go.gameObject, "SortNum/SortNum_1")
    local dierImg = Util.GetGameObject(go.gameObject, "SortNum/SortNum_2")
    local disanImg = Util.GetGameObject(go.gameObject, "SortNum/SortNum_3")
    local Img = Util.GetGameObject(go.gameObject, "SortNum/SortNum_4")
    local rankTitle = Util.GetGameObject(go.gameObject, "SortNum/SortNum_4/TitleText"):GetComponent("Text")
    local signImg = Util.GetGameObject(go.gameObject, "SignImg"):GetComponent("Image")
    local signBgImg = Util.GetGameObject(go.gameObject, "SignBG"):GetComponent("Image")
    signBgImg.sprite = Util.LoadSprite("cn2-X1_hunluanzhizhi_yansediban_0"..data.userSimpleInfo.camp)  --
    signImg.sprite = Util.LoadSprite("cn2-X1_hunluanzhizhi_biaozhi_0"..data.userSimpleInfo.camp)  
    diyiImg:SetActive(false)
    dierImg:SetActive(false)
    disanImg:SetActive(false)
    Img:SetActive(false)

    if data.rank == 1 then
        diyiImg:SetActive(true)
    elseif data.rank == 2 then
        dierImg:SetActive(true)
    elseif data.rank == 3 then
        disanImg:SetActive(true)
    else
        Img:SetActive(true)
        rankTitle.text = data.rank
    end
    name.text = data.userSimpleInfo.nickName
    for _index, _value in ipairs(data.userSimpleInfo.fightMap) do
        if _value.teamId == ChaosManager.zhanliTeamId then
            zhanli.text = _value.fight
            break
        end
    end  
    score.text = data.score
   
 end
function this:SwitchView(index)
    NetManager.CampWarRankingListInfoGetReq(index, function(msg)
       if msg.rankingListInfo then
            local rankData = msg.rankingListInfo.top100
            table.sort(rankData,function(a,b) 
                return a.rank<b.rank
            end)
            if index == 1 then
                this:SetEveryScroll(rankData)
            elseif index == 2 then
                this:SetCampScroll(rankData)
            end
            local myData ={
                selfScore =0,
                selfRank = 0,
                selfZhanLi = 0, 
            }
            -- for _index, _value in ipairs(msg.rankingListInfo.top100) do
            --     if _value.userSimpleInfo.userId == PlayerManager.uid then
            --             for index, value in ipairs(_value.userSimpleInfo.fightMap) do
            --                 if value.teamId == ChaosManager.zhanliTeamId then
            --                     myData.selfZhanLi = value.fight
            --                     break
            --                 end
            --             end  
            --         break
            --     end
            -- end 
            myData.selfScore = msg.rankingListInfo.selfScore 
            myData.selfRank = msg.rankingListInfo.selfRank  
            myData.selfZhanLi = msg.rankingListInfo.selfFight 
            --战力
            this:SetMyInfo(myData)
        else
            Log(" 排行榜数据为空")
            this.NoRankTip1:SetActive(false)
            this.NoRankTip2.gameObject:SetActive(false)
            this.NoRankTip3:SetActive(false)
            this.myScore.gameObject:SetActive(false)
        end
        
   end)

end
--设置我的信息
function this:SetMyInfo(infoData)
    if infoData.selfRank == 0 then
        this.NoRankTip1:SetActive(false)
        this.NoRankTip2.gameObject:SetActive(false)
        this.NoRankTip3:SetActive(false)
        this.myScore.gameObject:SetActive(false)
    else
        this.NoRankTip1:SetActive(true)
        this.NoRankTip2.gameObject:SetActive(true)
        this.NoRankTip3:SetActive(true)
        this.myScore.gameObject:SetActive(true)
    end
    --设置排名图片
   if infoData then
      if infoData.selfRank == 1 then
        this:SetHead()
        this:SetMyRankImg(1)
      elseif infoData.selfRank == 2 then
        this:SetHead()
        this:SetMyRankImg(2)
      elseif infoData.selfRank == 3 then
        this:SetHead()
        this:SetMyRankImg(3)
      elseif infoData.selfRank == 0 then
        this:SetMyRankImg(4)
        this.rankText.text = "未上榜"
      else
        this:SetHead()
        this:SetMyRankImg(4)
        this.rankText.text = infoData.selfRank
      end
      this.myScore.text = infoData.selfScore
      this.myZhanLi.text = infoData.selfZhanLi
      this.NoRankTip2.text = PlayerManager.nickName
   end
end

local myPlayerHead = nil
function this:SetHead()
    local hedaParent = Util.GetGameObject(this.gameObject, "Content/MyRankInfo/Head")
    Util.AddOnceClick(hedaParent, function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, PlayerManager.uid, PLAYER_INFO_VIEW_TYPE.ChaosZZ,nil,PlayerInfoType.CSArena)
    end)
    -- local child  =   hedaParent.transform:GetChild(0)
    -- if child then
    --   destroy(child.gameObject)
    -- end
    if not myPlayerHead then
        myPlayerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, hedaParent.transform)
    end

    myPlayerHead:Reset()
    myPlayerHead:SetScale(Vector3.one * 0.7)
    myPlayerHead:SetHead(PlayerManager.head)
    myPlayerHead:SetFrame(PlayerManager.frame) 
            --  Util.GetGameObject(playerHead.gameObject, "/Head")
end
function this:SetMyRankImg(index)

    this.diyiImg.gameObject:SetActive(index == 1)
    this.dierImg.gameObject:SetActive(index == 2)
    this.disanImg.gameObject:SetActive(index == 3)
    this.rankImg.gameObject:SetActive(index == 4)
end
--按钮状态切换
function this:SwitchBtns(index)
    if index == 1 then
        this.everyDayBtnSelect:SetActive(true)
        this.campBtnSelect:SetActive(false)
        this:SwitchView(1)
        this:SetBtnShowLayer(1)
    elseif index==2 then
        this.everyDayBtnSelect:SetActive(false)
        this.campBtnSelect:SetActive(true)
        this:SwitchView(2)
        this:SetBtnShowLayer(2)
    end
end
--1 每日   2阵营
function this:SetBtnShowLayer(index)

    if index ==1 then
        this.campBtnParent.transform:SetSiblingIndex(1)
        this.everyDayBtnParent.transform:SetSiblingIndex(2)
    elseif index == 2 then
        this.campBtnParent.transform:SetSiblingIndex(2)
        this.everyDayBtnParent.transform:SetSiblingIndex(1)
    end
end
function this:RefreshView()
    this:SwitchBtns(1)
end
function this:AddListener()
   
end

function this:RemoveListener()
  
end
function this:OnDestroy()
    this.playerHead = {}
    myPlayerHead = nil
end

return this
