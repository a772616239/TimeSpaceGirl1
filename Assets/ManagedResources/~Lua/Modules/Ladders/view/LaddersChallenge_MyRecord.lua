local this = {}
local _PlayerHeadList = {}
local arrowImg = {
    "cn2-X1_tongyong_shangjiantou",
    "cn2-X1_tongyong_xiajiantou"
}
local isInBattle = false

function this:InitComponent(gameObject)
    this.scroll = Util.GetGameObject(gameObject, "scroll")
    this.prefab = Util.GetGameObject(gameObject, "prefab")

    local v = this.scroll:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
            this.prefab, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

function this:BindEvent()
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow()
    isInBattle = false
    NetManager.GetWorldArenaRecordInfoRequest(1,function (msg)
        local data = msg.wroldBattleRecord
        this.ScrollView:SetData(data, function (index, go)
            this.SingleDataShow(go, data[index])
        end)
    end)
end

function this.SingleDataShow(go,data)
    local icon = Util.GetGameObject(go, "icon")
    local name = Util.GetGameObject(go, "name"):GetComponent("Text")
    local power = Util.GetGameObject(go, "power/Text"):GetComponent("Text")
    local result = Util.GetGameObject(go, "result"):GetComponent("Text")--胜负
    local time = Util.GetGameObject(go, "time"):GetComponent("Text")
    local arrow = Util.GetGameObject(go, "arrow"):GetComponent("Image")
    local rankNum = Util.GetGameObject(go, "rank"):GetComponent("Text")

    local replayBtn = Util.GetGameObject(go, "replayBtn")
    local shareBtn = Util.GetGameObject(go, "shareBtn")

    local blueData = data.blueEnemy --防守方
    local redData = data.redEnemy --攻击方/我方
    local EnemyData = nil
    if blueData.personInfo.uid == PlayerManager.uid then
        EnemyData = redData
    elseif redData.personInfo.uid == PlayerManager.uid then
        EnemyData = blueData
    end

    if not _PlayerHeadList[go] then
        _PlayerHeadList[go] = SubUIManager.Open(SubUIConfig.PlayerHeadView, icon.transform)
    end
    _PlayerHeadList[go]:Reset()
    _PlayerHeadList[go]:SetScale(Vector3.one * 0.5)
    _PlayerHeadList[go]:SetHead(EnemyData.personInfo.head)
    _PlayerHeadList[go]:SetFrame(EnemyData.personInfo.headFrame)
    -- _PlayerHeadList[go]:SetLevel(myData.personInfo.level)

    if EnemyData.personInfo.servername ~= nil and EnemyData.personInfo.servername ~= "" then
        if EnemyData.personInfo.uid < 10000 then
            name.text = string.format("[%s]%s",EnemyData.personInfo.servername, GetLanguageStrById(tonumber(EnemyData.personInfo.name))) 
        else
            name.text = string.format("[%s]%s",EnemyData.personInfo.servername, EnemyData.personInfo.name)
        end
    else
        if EnemyData.personInfo.uid < 10000 then
            name.text = GetLanguageStrById(tonumber(EnemyData.personInfo.name))
        else
            name.text = EnemyData.personInfo.name
        end
    end


    power.text = EnemyData.personInfo.totalForce
    local type = nil

    local color = nil
    local resStr = nil
    if data.type == 2 then
        type = GetLanguageStrById(50305)--防守
        if data.result == 0 then
            resStr = GetLanguageStrById(50308)--成功
            color = "<color=#529764FF>%s%s</color>"
        elseif data.result == 1 then
            resStr = GetLanguageStrById(50307)--失败
            color = "<color=#FE5B4A>%s%s</color>"
        end
    elseif data.type == 1 then
        type = GetLanguageStrById(50306)--进攻
        if data.result == 0 then
            resStr = GetLanguageStrById(50307)--失败
            color = "<color=#FE5B4A>%s%s</color>"
        elseif data.result == 1 then
            resStr = GetLanguageStrById(50308)--成功
            color = "<color=#529764FF>%s%s</color>"
        end
    end

    result.text = string.format(color,type,resStr)
    time.text = GetTimeShow(data.attackTime)

    local rankTxt = nil
    local WinOrLose = 0
    if data.type == 2 then
        local rank = data.actoldrank - data.actrank
        if rank > 0 then
            WinOrLose = 1
            rankTxt = string.format(GetLanguageStrById(50309),data.actrank)--排名提升
        elseif rank == 0 then
            WinOrLose = 0
            rankTxt = string.format(GetLanguageStrById(50310))--排名不变
        elseif rank < 0 then
            WinOrLose = 2
            rankTxt = string.format(GetLanguageStrById(50311),data.actrank)--排名降低
        end
    elseif data.type == 1 then
        local rank = data.oldrank - data.rank
        if rank > 0 then
            WinOrLose = 1
            rankTxt = string.format(GetLanguageStrById(50309),data.rank)
        elseif rank == 0 then
            WinOrLose = 0
            rankTxt = string.format(GetLanguageStrById(50310))
        elseif rank < 0 then
            WinOrLose = 2
            rankTxt = string.format(GetLanguageStrById(50311),data.rank)
        end
    end
    rankNum.text = rankTxt
    arrow.gameObject:SetActive(WinOrLose ~= 0)
    if WinOrLose ~= 0 then
        arrow.sprite = Util.LoadSprite(arrowImg[WinOrLose])
    end

    Util.AddOnceClick(replayBtn,function ()
        if BattleManager.IsInBackBattle() then
            return
        end

        if isInBattle then
            return
        end
        isInBattle = true

        BattleManager.GotoFight(function()
            --  回放
            -- 请求开始播放回放
            -- isWin 战斗结果 1 胜利 0 失败
            -- fightData 战斗数据
            -- nameStr 交战双方名称
            -- doneFunc 战斗播放完成要回调的事件
            -- fightInfo
            local structA = {
                head = redData.personInfo.head,
                headFrame = redData.personInfo.frame,
                name = redData.personInfo.nickName,
                formationId = redData.personInfo.formationId or 1,
                investigateLevel = redData.personInfo.investigateLevel
            }
            local structB = {
                head = blueData.personInfo.head,
                headFrame = blueData.personInfo.headFrame,
                name = blueData.personInfo.name,
                formationId = blueData.personInfo.formationId or 1,
                investigateLevel = blueData.personInfo.investigateLevel
            }
            BattleManager.SetAgainstInfoData(nil, structA, structB)

            LaddersArenaManager.drop = nil

            UIManager.OpenPanel(UIName.BattleStartPopup, function()
                local fightData = BattleManager.GetBattleServerData({fightData = data.fightData}, 1)
                local battlePanel = UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function ()
                BattleRecordManager.SetBattleBothNameStr(redData.personInfo.name.."|"..blueData.personInfo.name)
                isInBattle = false
            end)
            battlePanel:ShowNameShow(data.result, nil)
            end)
        end)
    end)

    Util.AddOnceClick(shareBtn,function ()
    end)

end

function this:OnSortingOrderChange()
end

function this:OnClose()
end

function this:OnDestroy()
end

return this