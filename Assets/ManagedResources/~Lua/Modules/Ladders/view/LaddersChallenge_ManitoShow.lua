local this = {}
local _PlayerHeadList = {}
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
    NetManager.GetWorldArenaRecordInfoRequest(2,function (msg)
        local data = msg.wroldBattleRecord
        this.ScrollView:SetData(data, function (index, go)
            this.SingleDataShow(go, data[index])
        end)
        isInBattle = false
    end)
end

function this.SingleDataShow(go, data)
    local time = Util.GetGameObject(go, "time"):GetComponent("Text")
    local replayBtn = Util.GetGameObject(go, "replayBtn")
    local shareBtn = Util.GetGameObject(go, "shareBtn")

    local blueData = data.redEnemy --攻击方
    local redData = data.blueEnemy --防守方

    this:SetPlayerData(go, Util.GetGameObject(go, "left"), 1, blueData, data)
    this:SetPlayerData(go, Util.GetGameObject(go, "right"), 2, redData, data)

    time.text = GetTimeShow(data.attackTime)

    Util.AddOnceClick(replayBtn,function ()
        if BattleManager.IsInBackBattle() then
            return
        end

        if isInBattle then
            return
        end
        isInBattle = true
        BattleManager.GotoFight(function()
            local structB = {
                head = redData.personInfo.head,
                headFrame = redData.personInfo.frame,
                name = redData.personInfo.name,
                formationId = redData.personInfo.formationId or 1,
                investigateLevel = redData.personInfo.investigateLevel
            }
            local structA = {
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
        PopupTipPanel.ShowTip(GetLanguageStrById(10414))
    end)
end

function this:SetPlayerData(parent, go, index, data, allData)
    local icon = Util.GetGameObject(go, "icon")
    local name = Util.GetGameObject(go, "name"):GetComponent("Text")
    local flag = Util.GetGameObject(go, "flag"):GetComponent("Image")
    local ranking = Util.GetGameObject(go, "ranking"):GetComponent("Text")

    if not _PlayerHeadList[parent] then
        _PlayerHeadList[parent] = {}
    end
    if not _PlayerHeadList[parent][index] then
        _PlayerHeadList[parent][index] = SubUIManager.Open(SubUIConfig.PlayerHeadView, icon.transform)
    end
    _PlayerHeadList[parent][index]:Reset()
    _PlayerHeadList[parent][index]:SetScale(Vector3.one * 0.65)
    _PlayerHeadList[parent][index]:SetHead(data.personInfo.head)
    _PlayerHeadList[parent][index]:SetFrame(data.personInfo.headFrame)
    -- _PlayerHeadList[parent][index]:SetLevel(data.personInfo.level)

    if data.personInfo.servername ~= nil and data.personInfo.servername ~= "" then
        name.text = string.format("[%s]%s", data.personInfo.servername, data.personInfo.name)
    else
        if data.personInfo.uid < 10000 then
            name.text = GetLanguageStrById(data.personInfo.name)
        else
            name.text = data.personInfo.name
        end

    end

    local sprite
    if index == 1 then
        if allData.result == 1 then
            sprite = "cn2-X1_jinbiaosai_win"
        else
            sprite = "cn2-X1_jinbiaosai_lose"
        end
        ranking.text = GetLanguageStrById(12394) .. allData.rank
    elseif index == 2 then
        if allData.result == 0 then
            sprite = "cn2-X1_jinbiaosai_win"
        else
            sprite = "cn2-X1_jinbiaosai_lose"
        end
        ranking.text = GetLanguageStrById(12394) .. allData.actrank
    end
    flag.sprite = Util.LoadSprite(sprite)
end

function this:OnSortingOrderChange()
end

function this:OnClose()
end

function this:OnDestroy()
end

return this