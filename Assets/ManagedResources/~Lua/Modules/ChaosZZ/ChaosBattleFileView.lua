--混乱之治奖励相关
local this = {}
local  myData ={}
local  maniData ={}
local  scoreData ={}
local  shoWviewType =1
local  battlePlayerData={}    --
local  battleTeams={}    --
local isInBattle = false
function this:InitComponent(gameObject)
    --topinfo
    this.gameObject = Util.GetGameObject(gameObject, "BattleFieldPanel")
    
    this.scroll = Util.GetGameObject(this.gameObject, "Content/Panel/MyBattlePanel/MyBattleScrollView")
    this.prefab_my = Util.GetGameObject(this.gameObject, "Content/Panel/MyBattleItem")
    local v2_my = this.scroll.transform.rect
    --我的记录
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
        this.prefab_my, nil, Vector2.New(v2_my.width, v2_my.height), 1, 1, Vector2.New(5, 5))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
    --大神风采
    this.prefab_mani = Util.GetGameObject(this.gameObject, "Content/Panel/ManitoItem")
    this.scroll2 = Util.GetGameObject(this.gameObject, "Content/Panel/ManitoPanel/ManitoScrollView")
    local v2_mani = this.scroll2.transform.rect
    this.scrollView2 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll2.transform,
    this.prefab_mani, nil, Vector2.New(v2_mani.width, v2_mani.height), 1, 1, Vector2.New(5, 5))
    this.scrollView2.moveTween.MomentumAmount = 1
    this.scrollView2.moveTween.Strength = 2


    this.myBtn =Util.GetGameObject(this.gameObject, "TopBtns/MyBtn/tab")
    this.myBtnSelect =Util.GetGameObject(this.gameObject, "TopBtns/MyBtn/tab/select")
    this.maniBtn=Util.GetGameObject(this.gameObject, "TopBtns/ManitoBtn/tab")
    this.maniBtnSelect=Util.GetGameObject(this.gameObject, "TopBtns/ManitoBtn/tab/select")


  
end
--显示items  index 对应type
function this:SetScroll(data)
    this.scroll2.gameObject:SetActive(false)   
    this.scroll.gameObject:SetActive(true)       
    this.scrollView:SetData(data, function(index, root)
        this:SetScrollItem(root, data[index], index)
    end)
end

function this:SetScrollMani(data)
    this.scroll2.gameObject:SetActive(true)   
    this.scroll.gameObject:SetActive(false)    
    this.scrollView2:SetData(data, function(index, root)
        this:SetScrollItem(root, data[index], index)
    end)
end

function this:SetScrollItem(go, data, index)
      
     
      --Log("___________________ zhan  bao   "..data.attackerUser)
     if shoWviewType  == 2 then
        --大神风采
        local leftData={}
        local rightData={}
        for index, value in ipairs(battlePlayerData) do
            if value.userId == data.attackerUser then
                leftData = value
                break
            end
        end    
        for i, v in ipairs(battlePlayerData) do
            if v.userId == data.defenderUser then
                rightData = v
                break
            end
        end   
        if leftData.userId == nil   or rightData.userId == nil then
            -- body 
            return
        end
            local timeText = Util.GetGameObject(go, "TimeImage/TimeText"):GetComponent("Text")
        --    Log("_______________  abc  "..data.createTime)
        --    LogError(tonumber(data.createTime))
            timeText.text = GetTimeShow(data.createTime)
        --left
            local leftIcon = Util.GetGameObject(go, "LeftPlayerHead/icon"):GetComponent("Image")
            local  leftFrame = Util.GetGameObject(go, "LeftPlayerHead/frame"):GetComponent("Image")
            local  leftResultImg = Util.GetGameObject(go, "LeftPlayerHead/ResultImage"):GetComponent("Image")
            local  leftInfo = Util.GetGameObject(go, "LeftPlayerHead/PlayerInfoText"):GetComponent("Text")
            local leftHeadBtn = Util.GetGameObject(go, "LeftPlayerHead/Image")
            -- Log("#leftData      "..#leftData)
            -- Log(" leftData.userId      "..leftData.userId)
            if leftData.userId >= 10000 then
                Util.AddOnceClick(leftHeadBtn, function()
                    UIManager.OpenPanel(UIName.PlayerInfoPopup, leftData.userId, PLAYER_INFO_VIEW_TYPE.ChaosZZ,nil,PlayerInfoType.CSArena)
                end)
            end
            local _result = 0
            leftInfo.text = "["..leftData.serverId.."]"..leftData.nickName
         leftIcon.sprite= GetPlayerHeadSprite(leftData.headIcon)
         leftFrame.sprite= GetPlayerHeadSprite(leftData.headFrame)
         if leftData.userId == data.winnerUser then
            leftResultImg.sprite = Util.LoadSprite("cn2-X1_jinbiaosai_win")
            _result = 1
         else
            leftResultImg.sprite = Util.LoadSprite("cn2-X1_jinbiaosai_lose")
            _result =0
         end
        
            --right
            local   rightIcon = Util.GetGameObject(go, "RightPlayerHead/icon"):GetComponent("Image")
            local  rightFrame = Util.GetGameObject(go, "RightPlayerHead/frame"):GetComponent("Image")
            local  rightResultImg = Util.GetGameObject(go, "RightPlayerHead/ResultImage"):GetComponent("Image")
            local  rightInfo = Util.GetGameObject(go, "RightPlayerHead/PlayerInfoText"):GetComponent("Text")
            local rightHeadBtn = Util.GetGameObject(go, "RightPlayerHead/Image")
            if rightData.userId >= 10000 then
                Util.AddOnceClick(rightHeadBtn, function()
                    UIManager.OpenPanel(UIName.PlayerInfoPopup, rightData.userId, PLAYER_INFO_VIEW_TYPE.ChaosZZ,PlayerInfoType.CSArena)
                end)
            end
        rightIcon.sprite= GetPlayerHeadSprite(rightData.headIcon)
        rightFrame.sprite= GetPlayerHeadSprite(rightData.headFrame)
        rightInfo.text = "["..rightData.serverId.."]"..rightData.nickName
         if rightData.userId == data.winnerUser then
            rightResultImg.sprite = Util.LoadSprite("cn2-X1_jinbiaosai_win")
         else
            rightResultImg.sprite = Util.LoadSprite("cn2-X1_jinbiaosai_lose")
         end
           local leftTeam ={}
           local RightTeam ={}
            for index_, _value in ipairs(battleTeams) do
                if _value.uid == leftData.userId then
                    leftTeam = _value
                    break
                end
            end    
            for _i, _v in ipairs(battleTeams) do
                if _v.uid == rightData.userId then
                    RightTeam = _v
                    break
                end
            end   
         local  watchBtn = Util.GetGameObject(go, "Right/WatchBtn")
         
            --观战记录
            Util.AddOnceClick(watchBtn, function()
                if ChaosManager:GetIsOpen() then
                    if BattleManager.IsInBackBattle() then
                        return
                    end
            
                    if isInBattle then
                        return
                    end
                    isInBattle = true
    
                    BattleManager.GotoFight(function()
                        local structA = {
                            head = leftData.headIcon,
                            headFrame = leftData.headFrame,
                            name = leftData.nickName,
                            formationId = leftTeam.team.formationId,
                            
                            investigateLevel = leftTeam.investigateLevel 
                        }
                        local structB = {
                            head = rightData.headIcon,
                            headFrame = rightData.headFrame,
                            name = rightData.nickName,
                            formationId = RightTeam.team.formationId,
                            investigateLevel = RightTeam.investigateLevel
                        }
                        BattleManager.SetAgainstInfoData(nil, structA, structB)
                    
                        LaddersArenaManager.drop = nil
                
                        UIManager.OpenPanel(UIName.BattleStartPopup, function()
                            local fightData = BattleManager.GetBattleServerData({fightData = data.fightData}, 1)
                            local battlePanel = UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function ()
                                BattleRecordManager.SetBattleBothNameStr(leftData.nickName.."|"..rightData.nickName)
                                --isInBattle = false
                            end)
                            battlePanel:ShowNameShow(_result, nil)
                        end)
                    end)
                end
                
            end)
      
     elseif shoWviewType  == 1 then
        
        --我的记录
        local resultLoseImg = Util.GetGameObject(go, "Left/ResultBgImg/loseImg")
        local resultLoseText = Util.GetGameObject(go, "Left/ResultBgImg/ResultLoseText"):GetComponent("Text")
        local resultWinText = Util.GetGameObject(go, "Left/ResultBgImg/ResultWinText"):GetComponent("Text")
        local timeText = Util.GetGameObject(go, "Left/TimeText"):GetComponent("Text")
        local myzhipei = Util.GetGameObject(go, "Left/ZhiPeiImg/ChangeValueText"):GetComponent("Text")
        local result = 0
        timeText.text = GetTimeShow(data.createTime + 0)
        if data.defenderUser == data.winnerUser then
            result = 1
            myzhipei.text = "+"..data.changeScore
            resultWinText.gameObject:SetActive(true)
            resultLoseImg:SetActive(false)
            resultLoseText.gameObject:SetActive(false)
        else
            result = 0
            myzhipei.text = "-"..data.changeScore
            resultWinText.gameObject:SetActive(false)
            resultLoseImg:SetActive(true)
            resultLoseText.gameObject:SetActive(true)
            --设置星级
        end
        --对手
       
        -- local   icon = Util.GetGameObject(go, "Middle/PlayerHead/icon"):GetComponent("Image")
        -- local  frame = Util.GetGameObject(go, "Middle/PlayerHead/frame"):GetComponent("Image")
        local  campImage = Util.GetGameObject(go, "Middle/Image/CampImg"):GetComponent("Image")
        local  battleValue = Util.GetGameObject(go, "Middle/BattleValueText"):GetComponent("Text")
        local  zhipeiValue = Util.GetGameObject(go, "Middle/zhipeiBG/ZhiPeiValueText"):GetComponent("Text")
        local  nameText = Util.GetGameObject(go, "Middle/nameText"):GetComponent("Text")
        local  watchBtn = Util.GetGameObject(go, "Right/WatchBtn")
        for _index, _value in ipairs(scoreData) do
            if _value.userId == data.attackerUser then
                zhipeiValue.text =_value.score
                break
            end
        end   
        local  battleData = {}
                for index, value in ipairs(battlePlayerData) do
                    if value.userId == data.attackerUser then
                        battleData = value
                        break
                    end
                end  
                if battleData.userId == nil then
                    return
                end    
        local hedaParent = Util.GetGameObject(go.gameObject, "Middle/PlayerHead")
        local playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, hedaParent.transform)
            playerHead:Reset()
            playerHead:SetScale(Vector3.one * 0.4)
            playerHead:SetHead(battleData.headIcon)
            playerHead:SetFrame(battleData.headFrame)
            playerHead:SetClickedTypeId(PlayerInfoType.CSArena)
            playerHead:SetViewType(PLAYER_INFO_VIEW_TYPE.ChaosZZ)
            playerHead:SetUID(battleData.userId)
        battleValue.text = battleData.fightMap.fight
        
        nameText.text = SetRobotName(battleData.userId, battleData.nickName) 
        campImage.sprite =  Util.LoadSprite("cn2-X1_hunluanzhizhi_biaozhi_0"..battleData.camp)  
        local redData ={}
        local blueData ={}
        for index, value in ipairs(battleTeams) do
            if value.uid == data.defenderUser then
                redData = value
                break
            end
        end    
        for i, v in ipairs(battleTeams) do
            if v.uid == data.attackerUser then
                blueData = v
                break
            end
        end   
                --观战记录
                Util.AddOnceClick(watchBtn, function()
                    if ChaosManager:GetIsOpen() then
                        if BattleManager.IsInBackBattle() then
                            return
                        end
                
                        if isInBattle then
                            return
                        end
                        isInBattle = true
    
                        BattleManager.GotoFight(function()
                            local structB = {
                                head = PlayerManager.head,
                                headFrame = PlayerManager.frame,
                                name = PlayerManager.nickName,
                                formationId = redData.team.formationId or 1,
                                investigateLevel = redData.investigateLevel 
                            }
                            local structA = {
                                head = battleData.headIcon,
                                headFrame = battleData.headFrame,
                                name = battleData.nickName,
                                formationId = blueData.team.formationId or 1,
                                investigateLevel = blueData.investigateLevel
                            }
                            BattleManager.SetAgainstInfoData(nil, structA, structB)
                        
                            LaddersArenaManager.drop = nil
                    
                            UIManager.OpenPanel(UIName.BattleStartPopup, function()
                                local fightData = BattleManager.GetBattleServerData({fightData = data.fightData}, 1)
                                local battlePanel = UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function ()
                                    BattleRecordManager.SetBattleBothNameStr(PlayerManager.nickName.."|"..battleData.nickName)
                                   -- isInBattle = false
                                end)
                                battlePanel:ShowNameShow(result, nil)
                            end)
                        end)
                    end
                end)
         end
end

function this:GetResultImg(result)
    if result == 0 then
        return "cn2-X1_jinbiaosai_lose"
    elseif result == 1 then
        return "cn2-X1_jinbiaosai_win"
    end
end

function this:BindEvent()
    Util.AddClick(this.myBtn, function()
        if ChaosManager:GetIsOpen() then
            shoWviewType = 1
            NetManager.CampWarBattleRecordGetReq(shoWviewType,function (msg)
                myData = msg.battleRecords
                battlePlayerData =msg.userSimpleInfos
                battleTeams = msg.hlTeamOneInfos
                scoreData = msg.scoreEntries
                this:SwitchBtns(1)
                this:SwitchView(1)
            end)
        end
        
    end)
    Util.AddClick(this.maniBtn, function()
        if ChaosManager:GetIsOpen() then
            shoWviewType = 2
            NetManager.CampWarBattleRecordGetReq(shoWviewType,function (msg)
                maniData = msg.battleRecords
                battlePlayerData =msg.userSimpleInfos
                battleTeams = msg.hlTeamOneInfos
                scoreData = msg.scoreEntries
                this:SwitchBtns(2)
                this:SwitchView(2)
            end)
        end   
    end)
   
end

function this:SwitchView(index)
    if index == 1 then
        this:SetScroll(myData)
        isInBattle = false
    elseif index == 2 then
        this:SetScrollMani(maniData)
        isInBattle = false
    end
end

function this:SwitchBtns(index)
    if index == 1 then
        this.maniBtnSelect:SetActive(false)
        this.myBtnSelect:SetActive(true)
        this:SetBtnShowLayer(1)
    elseif index==2 then
        this.maniBtnSelect:SetActive(true)
        this.myBtnSelect:SetActive(false)
        this:SetBtnShowLayer(2)
    end
end

function this:SetBtnShowLayer(index)
   local myBtn =Util.GetGameObject(this.gameObject, "TopBtns/MyBtn")
   local maniBtn=Util.GetGameObject(this.gameObject, "TopBtns/ManitoBtn")
    if index ==1 then
        myBtn.transform:SetSiblingIndex(3)
        maniBtn.transform:SetSiblingIndex(2)
    elseif index == 2 then
        myBtn.transform:SetSiblingIndex(2)
        maniBtn.transform:SetSiblingIndex(3)
    end
end
function this:RefreshView()
    NetManager.CampWarBattleRecordGetReq(shoWviewType,function (msg)
        myData = msg.battleRecords
        battlePlayerData =msg.userSimpleInfos
        battleTeams =msg.hlTeamOneInfos
        scoreData = msg.scoreEntries
        this:SwitchBtns(shoWviewType)
        this:SwitchView(shoWviewType)
        isInBattle = false
    end)
       
end
function this:AddListener()
   
end

function this:RemoveListener()
  
end
function this:OnDestroy()

end

return this
