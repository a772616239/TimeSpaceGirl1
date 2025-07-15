require("Base/BasePanel")
local ArenaRecordPopup = Inherit(BasePanel)
local this = ArenaRecordPopup
local playerHeadList = {}

--初始化组件（用于子类重写）
function ArenaRecordPopup:InitComponent()
    this.close = Util.GetGameObject(self.transform, "bg/close")
    this.prefab = Util.GetGameObject(self.transform, "bg/prefab")
    this.noRole = Util.GetGameObject(self.gameObject,"bg/noRole")
	this.scroll = Util.GetGameObject(self.gameObject,"bg/scroll")

    local rootWidth = this.scroll.transform.rect.width
    local rootHeight = this.scroll.transform.rect.height
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
            this.prefab, nil, Vector2.New(rootWidth, rootHeight), 1, 1, Vector2.New(0, 10))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function ArenaRecordPopup:BindEvent()
    Util.AddClick(this.close, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ArenaRecordPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Arena.OnRecordDataChange, this.RefreshRecordList)
end

--移除事件监听（用于子类重写）
function ArenaRecordPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Arena.OnRecordDataChange, this.RefreshRecordList)
end

--界面打开时调用（用于子类重写）
function ArenaRecordPopup:OnOpen(...)
    -- 请求数据
    ArenaManager.RequestArenaRecord()
    -- 刷新显示
    this.RefreshRecordList()
end

-- 刷新记录列表
function this.RefreshRecordList()
    local recordList = ArenaManager.GetRecordList()
    this.noRole:SetActive(#recordList < 1)
    this.ScrollView:SetData(recordList, function (index, go)
        this.RankNodeAdapter(go, recordList[index])
    end)
end

local flagImg = {
    [0] = "cn2-X1_jinbiaosai_lose",
    [1] = "cn2-X1_jinbiaosai_win",
}
local arrowImg = {
    [0] = "cn2-X1_tongyong_xiajiantou",
    [1] = "cn2-X1_tongyong_shangjiantou",
}
-- 排名节点数据匹配
function this.RankNodeAdapter(root, data)
    root:SetActive(true)
    local left = Util.GetGameObject(root, "left")
    local leftName = Util.GetGameObject(root, "left/name"):GetComponent("Text")
    local leftFlag = Util.GetGameObject(root, "leftFlag"):GetComponent("Image")

    local right = Util.GetGameObject(root, "right")
    local rightName = Util.GetGameObject(root, "right/name"):GetComponent("Text")
    local rightFlag = Util.GetGameObject(root, "rightFlag"):GetComponent("Image")

    local time = Util.GetGameObject(root, "time"):GetComponent("Text")
    local score = Util.GetGameObject(root, "score/Text"):GetComponent("Text")--积分
    local result = Util.GetGameObject(root, "result"):GetComponent("Text")--结果
    local arrow = Util.GetGameObject(root, "score/arrows"):GetComponent("Image")

    leftName.text = SetRobotName(data.attackInfo.uid, data.attackInfo.name)
    rightName.text = PlayerManager.nickName
    time.text = GetDeltaTimeStr(data.attackTime)

    if data.fightResult == 0 then
        leftFlag.sprite = Util.LoadSprite(flagImg[1])
    else
        leftFlag.sprite = Util.LoadSprite(flagImg[0])
    end
    rightFlag.sprite = Util.LoadSprite(flagImg[data.fightResult])
    arrow.sprite = Util.LoadSprite(arrowImg[data.fightResult])

    result.text = data.fightResult == 1 and GetLanguageStrById(10091) or GetLanguageStrById(10092)
    score.text = data.myScoreChange
    local color = data.fightResult == 1 and UIColor.GREEN or UIColor.RED
    result.color = color
    score.color = color

    if not playerHeadList[root] then
        playerHeadList[root] = {}
    end
    if not playerHeadList[root][1] then
        playerHeadList[root][1] = SubUIManager.Open(SubUIConfig.PlayerHeadView, left.transform)
    end
    playerHeadList[root][1]:Reset()
    playerHeadList[root][1]:SetScale(Vector3.one * 0.6)
    playerHeadList[root][1]:SetHead(data.attackInfo.head)
    playerHeadList[root][1]:SetFrame(data.attackInfo.headFrame)
    playerHeadList[root][1]:SetUID(data.attackInfo.uid)
    if not playerHeadList[root][2] then
        playerHeadList[root][2] = SubUIManager.Open(SubUIConfig.PlayerHeadView, right.transform)
    end
    playerHeadList[root][2]:Reset()
    playerHeadList[root][2]:SetScale(Vector3.one * 0.6)
    playerHeadList[root][2]:SetHead(data.defenseInfo.head)
    playerHeadList[root][2]:SetFrame(data.defenseInfo.headFrame)
    playerHeadList[root][2]:SetUID(PlayerManager.uid)

    -- 给回放按钮添加事件
    local replay = Util.GetGameObject(root, "replay")
    Util.AddOnceClick(replay, function()
        BattleManager.GotoFight(function()
            local structA = {
                head = data.attackInfo.head,
                headFrame = data.attackInfo.headFrame,
                name = SetRobotName(data.attackInfo.uid, data.attackInfo.name),
                formationId = data.attackInfo.formationId or 1,
                investigateLevel = data.attackInfo.investigateLevel
            }
            local structB = {
                head = PlayerManager.head,
                headFrame = PlayerManager.frame,
                name = PlayerManager.nickName,
                formationId = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_ARENA_DEFEND).formationId,
                investigateLevel = FormationCenterManager.GetInvestigateLevel()
            }
            BattleManager.SetAgainstInfoData(BATTLE_TYPE.BACK, structA, structB)
            ArenaManager.RequestRecordFightData(data.fightResult, data.id, data.attackInfo.name .. "|".. PlayerManager.nickName, function()
                this:ClosePanel()
                local arg = {}
                arg.result = data.fightResult
                arg.blue = {}
                arg.blue.uid = data.attackInfo.uid
                arg.blue.name = SetRobotName(data.attackInfo.uid, data.attackInfo.name)
                arg.blue.head = data.attackInfo.head
                arg.blue.frame = data.attackInfo.headFrame
                arg.blue.deltaScore = -data.myScoreChange
                arg.red = {}
                arg.red.uid = PlayerManager.uid
                arg.red.name = PlayerManager.nickName
                arg.red.head = PlayerManager.head
                arg.red.frame = PlayerManager.frame
                arg.red.deltaScore = data.myScoreChange
                UIManager.OpenPanel(UIName.ArenaResultPopup, arg)
            end)
        end)
    end)
end

--界面关闭时调用（用于子类重写）
function ArenaRecordPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function ArenaRecordPopup:OnDestroy()
    playerHeadList = {}
end

return ArenaRecordPopup