require("Base/BasePanel")
RecordPopup = Inherit(BasePanel)
local this = RecordPopup
local _PlayerHeadList = {}
local isInBattle = false

local FIGHT_RESULT_CONFIG = {
    [-1] = {spriteName = ""},
    [0] = {spriteName = "cn2-X1_jinbiaosai_lose"},
    [1] = {spriteName = "cn2-X1_jinbiaosai_win"}
}
--初始化组件（用于子类重写）
function RecordPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.title = Util.GetGameObject(self.transform, "Title"):GetComponent("Text")
    this.commonPanel = Util.GetGameObject(self.transform, "content/Common")
    this.rankPanel = Util.GetGameObject(self.transform, "content/Rank")
    this.emptyPanel = Util.GetGameObject(self.transform, "content/Empty")
    this.emptyText = Util.GetGameObject(self.transform, "content/Empty/Text"):GetComponent("Text")
    this.scrollRoot = Util.GetGameObject(self.transform, "content/Common/scrollpos")
    this.recordPre = Util.GetGameObject(this.scrollRoot, "item")

    local rootWidth = this.scrollRoot.transform.rect.width
    local rootHeight = this.scrollRoot.transform.rect.height
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform,
            this.recordPre, nil, Vector2.New(rootWidth, rootHeight), 1, 1, Vector2.New(0,0))
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function RecordPopup:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)

end

--添加事件监听（用于子类重写）
function RecordPopup:AddListener()

end

--移除事件监听（用于子类重写）
function RecordPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RecordPopup:OnOpen(...)
    isInBattle = false

    -- 请求数据
    local dataList = ArenaTopMatchManager.GetBattleHistory()

    if #dataList == 0 then
        this.emptyPanel:SetActive(true)
        this.commonPanel:SetActive(false)
        this.emptyText.text = GetLanguageStrById(10145)
    else
        this.emptyPanel:SetActive(false)
        this.commonPanel:SetActive(true)
        -- 设置数据
        this.SetData(dataList)
    end
    this.title.text = GetLanguageStrById(10146)
    this.rankPanel:SetActive(false)
end

function this.SetData(data)
    local callBack = function (index, go)
        this.RefreshData(go, data[index])
    end
    this.ScrollView:SetData(data, callBack)
end

function this.RefreshData(go, itemData)
    --- 基础信息
    local match = Util.GetGameObject(go, "match"):GetComponent("Text")
    local result = Util.GetGameObject(go,"result"):GetComponent("Image")
    local result2 = Util.GetGameObject(go,"result2"):GetComponent("Image")
    local myHead = Util.GetGameObject(go, "myHead")
    local myName = Util.GetGameObject(go, "myHead/name"):GetComponent("Text")
    local otherHead = Util.GetGameObject(go, "otherHead")
    local otherName = Util.GetGameObject(go, "otherHead/name"):GetComponent("Text")
    local deltaScore = Util.GetGameObject(go, "score"):GetComponent("Text")

    local attInfo = itemData.blueEnemy.personInfo
    local defInfo = itemData.redEnemy.personInfo

    myName.text = SetRobotName(attInfo.uid, attInfo.name)
    otherName.text = SetRobotName(defInfo.uid, defInfo.name)

    match.text = ArenaTopMatchManager.GetTurnNameByRoundTimes(itemData.roundTimes)

    if not _PlayerHeadList[go] then
        _PlayerHeadList[go] = {}
    end
    if not _PlayerHeadList[go][1] then
        _PlayerHeadList[go][1] = SubUIManager.Open(SubUIConfig.PlayerHeadView, myHead.transform)
    end
    _PlayerHeadList[go][1]:Reset()
    _PlayerHeadList[go][1]:SetScale(Vector3.one * 0.65)
    _PlayerHeadList[go][1]:SetHead(attInfo.head)
    _PlayerHeadList[go][1]:SetFrame(attInfo.headFrame)
    _PlayerHeadList[go][1]:SetUID(attInfo.uid)

    if not _PlayerHeadList[go][2] then
        _PlayerHeadList[go][2] = SubUIManager.Open(SubUIConfig.PlayerHeadView, otherHead.transform)
    end
    _PlayerHeadList[go][2]:Reset()
    _PlayerHeadList[go][2]:SetScale(Vector3.one * 0.65)
    _PlayerHeadList[go][2]:SetHead(defInfo.head)
    _PlayerHeadList[go][2]:SetFrame(defInfo.headFrame)
    _PlayerHeadList[go][2]:SetUID(defInfo.uid)

    result.gameObject:SetActive(false)
    result2.gameObject:SetActive(false)
    local config = FIGHT_RESULT_CONFIG[itemData.fightResult]

    if config.spriteName ~= "" then
        result.gameObject:SetActive(true)
        result.sprite = Util.LoadSprite(config.spriteName)
        result2.gameObject:SetActive(true)
        if itemData.fightResult == 0 then
            result2.sprite = Util.LoadSprite(FIGHT_RESULT_CONFIG[1].spriteName)
        elseif itemData.fightResult == 1 then
            result2.sprite = Util.LoadSprite(FIGHT_RESULT_CONFIG[0].spriteName)
        end
    end

    local deltaIntegral = ArenaTopMatchManager.GetMatchDeltaIntegral()
    local maxRound = ArenaTopMatchManager.GetChooseMaxRound()
    if itemData.roundTimes <= maxRound then
        deltaScore.color = UIColor.GRAY
        if itemData.fightResult == 1 then
            deltaScore.text = "+" .. deltaIntegral
            deltaScore.color = UIColor.GREEN
            -- deltaScore.text = GetLanguageStrById(10147)
        elseif itemData.fightResult == 0 then
            -- deltaScore.text = "+0"--GetLanguageStrById(12207)
            deltaScore.color = UIColor.RED
            deltaScore.text = GetLanguageStrById(10147)
        elseif itemData.fightResult == -1 then
            deltaScore.text = ""
            deltaScore.text = ""
        end
    else
        -- deltaScore.text = ""
        deltaScore.text = GetLanguageStrById(10148)
        deltaScore.color = UIColor.GRAY
    end

    -- 给回放按钮添加事件
    local replay = Util.GetGameObject(go, "playbackBtn")
    replay:SetActive(itemData.fightResult ~= -1)
    Util.AddOnceClick(replay, function()
        if isInBattle then
            return
        end
        if BattleManager.IsInBackBattle() then
            return
        end
        isInBattle = true

        local structA = {
            head = attInfo.head,
            headFrame = attInfo.headFrame,
            name = SetRobotName(attInfo.uid, attInfo.name),
            formationId = attInfo.teamFormation or 1,
            investigateLevel = attInfo.investigateLevel
        }
        local structB = {
            head = defInfo.head,
            headFrame = defInfo.headFrame,
            name = SetRobotName(defInfo.uid, defInfo.name),
            formationId = defInfo.teamFormation or 1,
            investigateLevel = defInfo.investigateLevel
        }
        BattleManager.SetAgainstInfoRecordCommon(structA, structB)
        ArenaTopMatchManager.RequestRecordFightData(itemData.fightResult, itemData.id, attInfo.name.."|"..defInfo.name, function()
            this:ClosePanel()
            --构建显示结果数据
            local arg = {}
            arg.panelType = 1
            arg.result = itemData.fightResult
            arg.blue = {}
            arg.blue.uid = attInfo.uid
            arg.blue.name = attInfo.name
            arg.blue.head = attInfo.head
            arg.blue.frame = attInfo.headFrame
            arg.red = {}
            arg.red.uid = defInfo.uid
            arg.red.name = defInfo.name
            arg.red.head = defInfo.head
            arg.red.frame = defInfo.headFrame
            UIManager.OpenPanel(UIName.ArenaResultPopup, arg)
        end)
    end)
end

--界面关闭时调用（用于子类重写）
function RecordPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function RecordPopup:OnDestroy()
    for _, playerHead in pairs(_PlayerHeadList) do
        if playerHead[1] then
            playerHead[1]:Recycle()
        end
        if playerHead[2] then
            playerHead[2]:Recycle()
        end
    end
    _PlayerHeadList = {}

    this.ScrollView = nil

end

return RecordPopup