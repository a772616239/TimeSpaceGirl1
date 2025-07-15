require("Base/BasePanel")
local ATMMyGuessHistoryPopup = Inherit(BasePanel)
local this = ATMMyGuessHistoryPopup
local _PlayerHeadList = {}

local resultIcon = {
    [-1] = {resPath = "r_gonghui_zhan"},
    [0] = {resPath = "UI_effect_JJC_JieSuan_ShiBai_png"},
    [1] = {resPath = "UI_effect_JJC_JieSuan_ShengLi_png"},
}
local stateConfig = {
    [0] = {name = GetLanguageStrById(10123), color = UIColor.GRAY},--即将开始
    [1] = {name = GetLanguageStrById(10132), color = UIColor.WHITE},--正在进行
    [2] = {name = GetLanguageStrById(10133), color = UIColor.GREEN},--竞猜成功
    [3] = {name = GetLanguageStrById(10134), color = UIColor.RED},--竞猜失败
}
local GUESS_COIN = ArenaTopMatchManager.GetGuessCoinID()

--初始化组件（用于子类重写）
function ATMMyGuessHistoryPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.title = Util.GetGameObject(self.transform, "Title"):GetComponent("Text")
    this.commonPanel = Util.GetGameObject(self.transform, "content/Common")
    this.rankPanel = Util.GetGameObject(self.transform, "content/Rank")
    this.emptyPanel = Util.GetGameObject(self.transform, "content/Empty")
    this.emptyText = Util.GetGameObject(self.transform, "content/Empty/Text"):GetComponent("Text")
    this.scrollRoot = Util.GetGameObject(self.transform, "content/Common/scrollpos")
    this.recordPre = Util.GetGameObject(this.scrollRoot, "guess")

    local rootWidth = this.scrollRoot.transform.rect.width
    local rootHeight = this.scrollRoot.transform.rect.height
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform,
            this.recordPre, nil, Vector2.New(rootWidth, rootHeight), 1, 1, Vector2.New(0,10))
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function ATMMyGuessHistoryPopup:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ATMMyGuessHistoryPopup:AddListener()
end

--移除事件监听（用于子类重写）
function ATMMyGuessHistoryPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ATMMyGuessHistoryPopup:OnOpen(...)
    -- 请求数据
    local dataList = ArenaTopMatchManager.GetBetHistory()
    if #dataList == 0 then
        this.emptyPanel:SetActive(true)
        this.commonPanel:SetActive(false)
        this.emptyText.text = GetLanguageStrById(10135)
    else
        this.emptyPanel:SetActive(false)
        this.commonPanel:SetActive(true)
        -- 设置数据
        this.ScrollView:SetData(dataList, function (index, go)
            this.RefreshData(go, dataList[index])
        end)
    end
    this.title.text = GetLanguageStrById(10136)
    this.rankPanel:SetActive(false)
end

local img = {
    "cn2-X1_jinbiaosai_win",
    "cn2-X1_jinbiaosai_lose"
}
local txt = {
    string.format("<color=#88e4ff>%s</color> : ", GetLanguageStrById(10139)),
    string.format("<color=#ff6868>%s</color> : ", GetLanguageStrById(10140))
}
function this.RefreshData(go, itemData)
    --- 基础信息
    local head = {}
    local left = Util.GetGameObject(go, "left")
    head[1] = Util.GetGameObject(left, "pos")
    local leftName = Util.GetGameObject(left, "name"):GetComponent("Text")
    local leftResult = Util.GetGameObject(left, "result"):GetComponent("Image")

    local right = Util.GetGameObject(go, "right")
    head[2] = Util.GetGameObject(right, "pos")
    local rightName = Util.GetGameObject(right, "name"):GetComponent("Text")
    local rightResult = Util.GetGameObject(right, "result"):GetComponent("Image")

    local state = Util.GetGameObject(go, "state"):GetComponent("Text")--竞猜胜负
    local betNum = Util.GetGameObject(go, "betNum"):GetComponent("Text")--下注数量
    local getNum = Util.GetGameObject(go, "getNum"):GetComponent("Text")--赢得数量
    local title = Util.GetGameObject(go, "title"):GetComponent("Text")--标题

    local battleInfo = itemData.enemyPairInfo
    local personInfo = {
        [1] = battleInfo.blueEnemy.personInfo,
        [2] = battleInfo.redEnemy.personInfo,
    }

    leftName.text = SetRobotName(personInfo[1].uid, personInfo[1].name)
    rightName.text = SetRobotName(personInfo[2].uid, personInfo[2].name)

    title.text = ArenaTopMatchManager.GetTurnNameByRoundTimes(battleInfo.roundTimes)

    local index = itemData.betResult
    if itemData.betResult > 1 then--如果已下注
        if itemData.myWinCoins > 0 then--胜利
            index = 2
        else
            index = 3
        end
    end

    local config = stateConfig[index]
    state.text = config.name
    state.color = config.color

    -- 竞猜币
    Util.GetGameObject(getNum.gameObject, "Image"):GetComponent("Image").sprite = SetIcon(GUESS_COIN)

    if itemData.betResult == personInfo[1].uid then
        betNum.text = txt[1]..itemData.myBetCoins
    elseif itemData.betResult == personInfo[2].uid then
        betNum.text = txt[2]..itemData.myBetCoins
    else
        betNum.text = itemData.myBetCoins
    end
    getNum.text = (index == 1 or index == 0) and GetLanguageStrById(12207) or itemData.myWinCoins

    if index > 1 then
        leftResult.gameObject:SetActive(true)
        rightResult.gameObject:SetActive(true)
        if index == 2 then
            if itemData.betResult == personInfo[1].uid then
                leftResult.sprite = Util.LoadSprite(img[1])
                rightResult.sprite = Util.LoadSprite(img[2])
            elseif itemData.betResult == personInfo[2].uid then
                leftResult.sprite = Util.LoadSprite(img[2])
                rightResult.sprite = Util.LoadSprite(img[1])
            end
        elseif index == 3 then
            if itemData.betResult == personInfo[1].uid then
                leftResult.sprite = Util.LoadSprite(img[2])
                rightResult.sprite = Util.LoadSprite(img[1])
            elseif itemData.betResult == personInfo[2].uid then
                leftResult.sprite = Util.LoadSprite(img[1])
                rightResult.sprite = Util.LoadSprite(img[2])
            end
        end
    else
        leftResult.gameObject:SetActive(false)
        rightResult.gameObject:SetActive(false)
    end

    -- 头像
    if not _PlayerHeadList[go] then
        _PlayerHeadList[go] = {}
    end

    for i = 1, 2 do
        if not _PlayerHeadList[go][i] then
            _PlayerHeadList[go][i] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head[i].transform)
        end
        _PlayerHeadList[go][i]:Reset()
        _PlayerHeadList[go][i]:SetScale(Vector3.one * 0.6)
        _PlayerHeadList[go][i]:SetHead(personInfo[i].head)
        _PlayerHeadList[go][i]:SetFrame(personInfo[i].headFrame)
    end

    -- 给回放按钮添加事件
    local replay = Util.GetGameObject(go, "btn1")
    replay:SetActive(itemData.enemyPairInfo.fightResult ~= -1)
    Util.AddOnceClick(replay, function()
        local structA = {
            head = personInfo[1].head,
            headFrame = personInfo[1].headFrame,
            name = SetRobotName(personInfo[1].uid, personInfo[1].name),
            formationId = personInfo[1].teamFormation or 1,
            investigateLevel = personInfo[1].investigateLevel
        }
        local structB = {
            head = personInfo[2].head,
            headFrame = personInfo[2].headFrame,
            name = SetRobotName(personInfo[2].uid, personInfo[2].name),
            formationId = personInfo[2].teamFormation or 1,
            investigateLevel = personInfo[2].investigateLevel
        }
        BattleManager.SetAgainstInfoRecordCommon(structA, structB)
        ArenaTopMatchManager.RequestRecordFightData(itemData.enemyPairInfo.fightResult, itemData.enemyPairInfo.id, personInfo[1].name.."|"..personInfo[2].name, function()
            this:ClosePanel()
            --构建显示结果数据
            local arg = {}
            arg.panelType = 1
            arg.result = itemData.enemyPairInfo.fightResult
            arg.blue = {}
            arg.blue.uid = personInfo[1].uid
            arg.blue.name = personInfo[1].name
            arg.blue.head = personInfo[1].head
            arg.blue.frame = personInfo[1].headFrame
            arg.red = {}
            arg.red.uid = personInfo[2].uid
            arg.red.name = personInfo[2].name
            arg.red.head = personInfo[2].head
            arg.red.frame = personInfo[2].headFrame
            UIManager.OpenPanel(UIName.ArenaResultPopup, arg)
        end)
    end)
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ATMMyGuessHistoryPopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function ATMMyGuessHistoryPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function ATMMyGuessHistoryPopup:OnDestroy()
    for _, headList in pairs(_PlayerHeadList) do
        for _, playerHead in ipairs(headList) do
            playerHead:Recycle()
        end
    end
    _PlayerHeadList = {}

    this.ScrollView = nil
end

return ATMMyGuessHistoryPopup