local ATM_EliminationView = {}
local this = ATM_EliminationView
-- Tab管理器
local ArenaTopMatchPanel = require("Modules/ArenaTopMatch/ArenaTopMatchPanel")
local TabBox = require("Modules/Common/TabBox")
local _TabData = {
    [1] = {txt = GetLanguageStrById(10150)},
    [2] = {txt = GetLanguageStrById(10151)},
}

--玩家状态
local PlayerState = {
    None = -1,
    Win = 1,
    Fail = 0,
}
--小组偏移值
local GroupIndex = 1
local GroupInfo = {GetLanguageStrById(10152),GetLanguageStrById(10153),GetLanguageStrById(10154),GetLanguageStrById(10155)}

local battleStage = 0
local battleTurn = 0
local battleState = 0
local _IsShowData = false

local CurTabIndex = 1--当前选中页签

---淘汰赛
--初始化组件（用于子类重写）
function ATM_EliminationView:InitComponent()
    this.panel = Util.GetGameObject(self.gameObject,"Panel")
    this.middle = Util.GetGameObject(this.panel,"Middle")

    this.thirtyTwoPre = Util.GetGameObject(this.middle,"ThirtyTwoPre")
    this.groupInfo = Util.GetGameObject(this.middle,"ThirtyTwoPre/GroupInfo"):GetComponent("Text")
    this.thirtyTwoList = {}
    local index = 0
    for i = 1, 7 do
        local pos = Util.GetGameObject(this.thirtyTwoPre,"Pos"..i)
        for j = 1, 2 do
            index = index + 1
            this.thirtyTwoList[index] = Util.GetGameObject(pos,"ItemPre"..j)
        end
    end

    this.playFlyAnim = Util.GetGameObject(this.middle,"ThirtyTwoPre"):GetComponent("PlayFlyAnim")

    this.leftBtn = Util.GetGameObject(this.middle,"ThirtyTwoPre/LeftBtn/GameObject")
    this.rightBtn = Util.GetGameObject(this.middle,"ThirtyTwoPre/RightBtn/GameObject")

    this.fourPre = Util.GetGameObject(this.middle,"FourPre")
    this.fourList = {}
    index = 0
    for i = 1, 6 do
        local pos = Util.GetGameObject(this.fourPre,"Pos"..i)
        for j = 1, 2 do
            index = index + 1
            this.fourList[index] = Util.GetGameObject(pos,"ItemPre"..j)
        end
    end
    this.empty = Util.GetGameObject(this.panel,"Empty")
    this.emptyInfo = Util.GetGameObject(this.panel,"Empty/Bg/Text"):GetComponent("Text")

    this.tabBox = Util.GetGameObject(this.panel,"TabBox")
    this.tabCtrl = TabBox.New()
    this.tabCtrl:SetTabAdapter(this.TabAdapter)
    this.tabCtrl:SetChangeTabCallBack(this.OnTabChange)
    this.tabCtrl:Init(this.tabBox, _TabData)
end

--绑定事件（用于子类重写）
function ATM_EliminationView:BindEvent()
    --左按钮
    Util.AddClick(this.leftBtn,function()
        GroupIndex = GroupIndex-1
        if GroupIndex < 1 then
            GroupIndex = 4
        end
        this.Set32Group(GroupIndex)
    end)
    --右按钮
    Util.AddClick(this.rightBtn,function()
        GroupIndex = GroupIndex + 1
        if GroupIndex > 4 then
            GroupIndex = 1
        end
        this.Set32Group(GroupIndex)
    end)
end

--添加事件监听（用于子类重写）
function ATM_EliminationView:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshBaseShow)
end

--移除事件监听（用于子类重写）
function ATM_EliminationView:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshBaseShow)
end

--界面打开时调用（用于子类重写）
function ATM_EliminationView:OnOpen(...)
    battleStage = ArenaTopMatchManager.GetBaseData().battleStage
    battleTurn = ArenaTopMatchManager.GetBaseData().battleTurn
    battleState = ArenaTopMatchManager.GetBaseData().battleState

    local isActive = ArenaTopMatchManager.IsTopMatchActive()
    _IsShowData = isActive and (battleStage == TOP_MATCH_STAGE.ELIMINATION or battleStage == TOP_MATCH_STAGE.OVER)
    this.empty:SetActive(not _IsShowData)
    this.middle:SetActive(_IsShowData)
    GroupIndex = 1

    if this.tabCtrl then
        this.tabCtrl:ChangeTab(1)
    end
    FixedUpdateBeat:Add(this.OnUpdate, self)
end

function ATM_EliminationView:OnSortingOrderChange(sortingOrder)
 
end

--界面关闭时调用（用于子类重写）
function ATM_EliminationView:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    FixedUpdateBeat:Remove(this.OnUpdate, self)
end

--界面销毁时调用（用于子类重写）
function ATM_EliminationView:OnDestroy()
end

function this.OnUpdate()
end

-- tab按钮自定义显示设置
function this.TabAdapter(tab, index, status)
    local default = Util.GetGameObject(tab, "default")
    local select = Util.GetGameObject(tab, "select")
    default:GetComponent("Text").text = _TabData[index].txt
    select:GetComponent("Text").text = _TabData[index].txt
    default:SetActive(status == "default")
    select:SetActive(status == "select")
    Util.GetGameObject(tab, "Image"):SetActive(status == "select")
end
-- tab改变回调事件
function this.OnTabChange(index, lastIndex)
    this.OnTabChangeView(index)
end

--主动切换页签显示
function this.OnTabChangeView(index)
    this.thirtyTwoPre:SetActive(index == 1)
    this.fourPre:SetActive(index ~= 1)
    if index == 1 then
        CurTabIndex = index
        this.emptyInfo.text = GetLanguageStrById(10159)
        ArenaTopMatchManager.Request_32_EliminationData(function()
            this.Set32Group(1)
        end)
        this.playFlyAnim:PlayAnim(true)
    else
        CurTabIndex = 2
        this.emptyInfo.text = GetLanguageStrById(10160)
        ArenaTopMatchManager.Request_4_EliminationData(function()
            this.Set4Group()
        end)
    end
end

--被动刷新页签显示
function this.RefreshBaseShow()
    battleStage = ArenaTopMatchManager.GetBaseData().battleStage
    battleTurn = ArenaTopMatchManager.GetBaseData().battleTurn
    battleState = ArenaTopMatchManager.GetBaseData().battleState
    
    local isActive = ArenaTopMatchManager.IsTopMatchActive()
    _IsShowData = isActive and (battleStage == TOP_MATCH_STAGE.ELIMINATION or battleStage == TOP_MATCH_STAGE.OVER)
    this.empty:SetActive(not _IsShowData)
    this.middle:SetActive(_IsShowData)
    
    this.thirtyTwoPre:SetActive(CurTabIndex == 1 and _IsShowData)
    this.fourPre:SetActive(CurTabIndex == 2 and _IsShowData)
    --竞猜按钮竞猜结束后未关闭
    if CurTabIndex == 1 then
        this.emptyInfo.text = GetLanguageStrById(10159)
        ArenaTopMatchManager.Request_32_EliminationData(function()
            this.Set32Group(GroupIndex)
        end)
        this.playFlyAnim:PlayAnim(true)
    elseif CurTabIndex == 2 then
        this.emptyInfo.text = GetLanguageStrById(10160)
        ArenaTopMatchManager.Request_4_EliminationData(function()
            this.Set4Group()
        end)
    end
end

--设置玩家页签状态
function this.SetPlayerState(obj1,obj2,data,func)
    Util.GetGameObject(obj1,"icon"):SetActive(true)
    Util.GetGameObject(obj1,"Line/Win"):SetActive(data.fightResult == PlayerState.Win)
    Util.GetGameObject(obj1,"Line/Fail"):SetActive(data.fightResult == PlayerState.Fail)
    Util.GetGameObject(obj1,"Name"):GetComponent("Text").text = SetRobotName(data.attackInfo.uid, data.attackInfo.name)
    Util.GetGameObject(obj1,"icon"):GetComponent("Image").sprite = GetPlayerHeadSprite(data.attackInfo.head)
    obj1:GetComponent("Image").sprite = GetPlayerHeadFrameSprite(data.attackInfo.headFrame)
    Util.GetGameObject(obj1,"lv"):GetComponent("Text").text = "Lv." .. data.attackInfo.level

    Util.GetGameObject(obj2,"icon"):SetActive(true)
    Util.GetGameObject(obj2,"Line/Win"):SetActive(data.fightResult == PlayerState.Fail)
    Util.GetGameObject(obj2,"Line/Fail"):SetActive(data.fightResult == PlayerState.Win)
    Util.GetGameObject(obj2,"Name"):GetComponent("Text").text = SetRobotName(data.defInfo.uid, data.defInfo.name)
    Util.GetGameObject(obj2,"icon"):GetComponent("Image").sprite = GetPlayerHeadSprite(data.defInfo.head)
    obj2:GetComponent("Image").sprite = GetPlayerHeadFrameSprite(data.defInfo.headFrame)
    Util.GetGameObject(obj2,"lv"):GetComponent("Text").text = "Lv." .. data.defInfo.level

    if data.fightResult == PlayerState.Win then
        obj1.transform:SetSiblingIndex(1)
        obj2.transform:SetSiblingIndex(0)
    else
        obj1.transform:SetSiblingIndex(0)
        obj2.transform:SetSiblingIndex(1)
    end
    if func then func() end
end

function this.SetPlaySettingBack(playBackBtn,v,fightResult)
    playBackBtn:SetActive(_IsShowData and fightResult ~= -1)
    Util.AddOnceClick(playBackBtn,function()
        UIManager.OpenPanel(UIName.TopMatchPlayBattleAinSelectPopup,v)
    end)
end
--设置战斗回放按钮
function this.SetPlayBack(playBackBtn, fightResult, id, defInfo, attackInfo)
    playBackBtn:SetActive(_IsShowData and fightResult ~= -1)
    Util.AddOnceClick(playBackBtn, function()
        local structA = {
            head = attackInfo.head,
            headFrame = attackInfo.headFrame,
            name = SetRobotName(attackInfo.uid, attackInfo.name),
            formationId = attackInfo.teamFormation or 1,
            investigateLevel = attackInfo.investigateLevel
        }
        local structB = {
            head = defInfo.head,
            headFrame = defInfo.headFrame,
            name = SetRobotName(defInfo.uid, defInfo.name),
            formationId = defInfo.teamFormation or 1,
            investigateLevel = defInfo.investigateLevel
        }
        BattleManager.SetAgainstInfoRecordCommon(structA, structB)
        ArenaTopMatchManager.RequestRecordFightData(fightResult,id, attackInfo.name.."|"..defInfo.name,function()
            --构建显示结果数据(我永远在蓝方)
            local arg = {}
            arg.panelType = 1
            arg.result = fightResult
            arg.blue = {}
            arg.blue.uid = attackInfo.uid
            arg.blue.name = attackInfo.name
            arg.blue.head = attackInfo.head
            arg.blue.frame = attackInfo.headFrame
            arg.red = {}
            arg.red.uid = defInfo.uid
            arg.red.name = defInfo.name
            arg.red.head = defInfo.head
            arg.red.frame = defInfo.headFrame
            UIManager.OpenPanel(UIName.ArenaResultPopup, arg)
        end)
    end)
end
--设置竞猜按钮
function this.SetGuessBtn(guessBtn, isGUess)
    guessBtn:SetActive(battleStage == TOP_MATCH_STAGE.ELIMINATION and isGUess == 1)
    
    Util.AddOnceClick(guessBtn,function()
        if ArenaTopMatchPanel.TabCtrl then
            ArenaTopMatchPanel.TabCtrl:ChangeTab(2)
        end
    end)
end

--设置32强战斗组
function this.Set32Group(index)
    this.InitGroup(this.thirtyTwoList)
    this.groupInfo.text = GroupInfo[index]
    local data = {}
    for i, v in pairs(ArenaTopMatchManager.EliminationData_32) do
        if v._singleData.teamId == index then
            table.insert(data,v)
        end
    end

    -- 置空显示
    local cHead = Util.GetGameObject(this.thirtyTwoPre,"winer")
    this.SetChampionHead(cHead)

    for i, v in pairs(data) do
        local str
        if v._singleData.roundTImes == 8 then
            str = "Pos"..v._singleData.position.."/"
        end
        if v._singleData.roundTImes == 9 then
            str = "Pos"..(v._singleData.position + 4).."/"
        end
        if v._singleData.roundTImes == 10 then
            str = "Pos7/"
        end
        if v._singleData.roundTImes == 8 or v._singleData.roundTImes == 9 or v._singleData.roundTImes == 10 then
            local item1 = Util.GetGameObject(this.thirtyTwoPre,str .. "ItemPre1")
            local item2 = Util.GetGameObject(this.thirtyTwoPre,str .. "ItemPre2")
            local playBackBtn = Util.GetGameObject(this.thirtyTwoPre,str .. "PlayBackBtn")
            local guessBtn = Util.GetGameObject(this.thirtyTwoPre,str .. "GuessBtn")
            this.SetPlayerState(item1,item2,v._singleData)
            this.SetPlayBack(playBackBtn,v.fightResult,v.id,v.defInfo,v.attackInfo)
            this.SetPlaySettingBack(playBackBtn,v._listData,v._singleData.fightResult)
            this.SetGuessBtn(guessBtn,v._singleData.isGUess)

            this.SetChampionHead(cHead, v._singleData.fightResult, v._singleData.defInfo, v._singleData.attackInfo)
        end
    end
end

--设置4强战斗组
function this.Set4Group()
    this.InitGroup(this.fourList)
    local data = {}
    for i, v in pairs(ArenaTopMatchManager.EliminationData_4) do
        if v._singleData.teamId == 1 then
            table.insert(data,v)
        end
    end
    -- 置空显示
    local cHead = Util.GetGameObject(this.fourPre,"Pos3/Winner")
    this.SetChampionHead(cHead)

    for i, v in pairs(data) do
        local str
        if v._singleData.roundTImes == 11 then
            str = "Pos"..v._singleData.position.."/"
        end
        if v._singleData.roundTImes == 12 then
            str = "Pos3/"
        end
        if v._singleData.roundTImes == 11 or v._singleData.roundTImes == 12 then
            local item1 = Util.GetGameObject(this.fourPre,str .. "ItemPre1")
            local item2 = Util.GetGameObject(this.fourPre,str .. "ItemPre2")
            local playBackBtn = Util.GetGameObject(this.fourPre,str .. "PlayBackBtn")
            local guessBtn = Util.GetGameObject(this.fourPre,str .. "GuessBtn")
            this.SetPlayerState(item1,item2,v._singleData)
            this.SetPlayBack(playBackBtn,v.fightResult,v.id,v.defInfo,v.attackInfo)
            this.SetPlaySettingBack(playBackBtn,v._listData,v._singleData.fightResult)
            this.SetGuessBtn(guessBtn,v._singleData.isGUess)

            this.SetChampionHead(cHead, v._singleData.fightResult, v._singleData.defInfo, v._singleData.attackInfo)
        end
    end
end

--设置冠军的头像
function this.SetChampionHead(head, fightResult, defInfo, attackInfo)
    local headFrame = head:GetComponent("Image")
    local icon = Util.GetGameObject(head, "icon"):GetComponent("Image")
    local lv = Util.GetGameObject(head, "lv"):GetComponent("Text")
    local name = Util.GetGameObject(head, "Name"):GetComponent("Text")

    headFrame.sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
    if not fightResult or fightResult and fightResult == -1 then
        icon.gameObject:SetActive(false)
        lv.gameObject:SetActive(false)
        name.gameObject:SetActive(false)
        return
    end

    if (battleStage == TOP_MATCH_STAGE.ELIMINATION
        and battleTurn == ArenaTopMatchManager.GetEliminationMaxRound()
        and battleState == TOP_MATCH_TIME_STATE.OPEN_IN_END)    -- 最后一个阶段的结算阶段
        or battleStage == TOP_MATCH_STAGE.OVER  -- 已结束
        then
        icon.gameObject:SetActive(true)
        lv.gameObject:SetActive(true)
        name.gameObject:SetActive(true)
        local cInfo = fightResult == 1 and attackInfo or defInfo
        headFrame.sprite = GetPlayerHeadFrameSprite(cInfo.headFrame)
        icon.sprite = GetPlayerHeadSprite(cInfo.head)
        lv.text = cInfo.level
        name.text = SetRobotName(cInfo.uid, cInfo.name)
    else
        icon.gameObject:SetActive(false)
        lv.gameObject:SetActive(false)
        name.gameObject:SetActive(false)
    end
end

--初始化
function this.InitGroup(group)
    for i = 1, #group do
        group[i]:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
        Util.GetGameObject(group[i],"Line/Win"):SetActive(false)
        Util.GetGameObject(group[i],"Line/Fail"):SetActive(false)
        Util.GetGameObject(group[i],"icon"):SetActive(false)
        Util.GetGameObject(group[i],"Name"):GetComponent("Text").text = ""
        Util.GetGameObject(group[i],"lv"):GetComponent("Text").text = ""
    end
end

return ATM_EliminationView