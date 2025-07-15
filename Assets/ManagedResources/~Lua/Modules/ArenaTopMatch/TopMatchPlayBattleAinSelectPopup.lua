require("Base/BasePanel")
TopMatchPlayBattleAinSelectPopup = Inherit(BasePanel)
local this = TopMatchPlayBattleAinSelectPopup
local resultRes = {
    [0] = "cn2-X1_tongyong_fu",
    [1] = "cn2-X1_tongyong_sheng",
}

--初始化组件（用于子类重写）
function TopMatchPlayBattleAinSelectPopup:InitComponent()
    this.maskImage = Util.GetGameObject(self.transform, "maskImage")
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.title = Util.GetGameObject(self.transform, "Title"):GetComponent("Text")
    this.battleRecord = {}
    for i = 1, 3 do
        this.battleRecord[i] = Util.GetGameObject(self.transform, "content/pre ("..i..")")
    end
    this.playerHead = {}--玩家头像列表
end

--绑定事件（用于子类重写）
function TopMatchPlayBattleAinSelectPopup:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.maskImage, function ()
        self:ClosePanel()
    end)

end

--添加事件监听（用于子类重写）
function TopMatchPlayBattleAinSelectPopup:AddListener()

end

--移除事件监听（用于子类重写）
function TopMatchPlayBattleAinSelectPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function TopMatchPlayBattleAinSelectPopup:OnOpen(v)
    this.title.text = GetLanguageStrById(10146)
    for i = 1, 3 do
        local curPre = this.battleRecord[i]
        if curPre then
            if #v >= i then
                curPre:SetActive(true)
                this.SetPreShow(i,curPre,v[i])
            else
                curPre:SetActive(false)
            end
        end
    end
end
function this.SetPreShow(index,curPre,v)
    Util.GetGameObject(curPre, "titleText"):GetComponent("Text").text = string.format(GetLanguageStrById(12244), index)
    Util.AddOnceClick(Util.GetGameObject(curPre, "PlayBackBtn"), function ()
        this.SetPlayBack(v.fightResult,v.id,v.defInfo,v.attackInfo)
    end)

    this.SetHead( Util.GetGameObject(curPre, "attackInfo"),v.attackInfo,v.fightResult == 1)
    this.SetHead(Util.GetGameObject(curPre, "defInfo"),v.defInfo,v.fightResult == 0)
end
function this.SetHead(curPre,data,isShowWinImage)
    local head = Util.GetGameObject(curPre,"head")
    local name = Util.GetGameObject(curPre,"nameBg/Text"):GetComponent("Text")
    local winOrFail = Util.GetGameObject(curPre,"winOrFail"):GetComponent("Image")
    if isShowWinImage then
        winOrFail.sprite = Util.LoadSprite(resultRes[1])
    else
        winOrFail.sprite = Util.LoadSprite(resultRes[0])
    end
    if data then
        if not this.playerHead[curPre] then
            this.playerHead[curPre] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,head)
        end
        this.playerHead[curPre]:Reset()
        this.playerHead[curPre]:SetScale(Vector3.one*0.6)
        this.playerHead[curPre]:SetHead(data.head)
        this.playerHead[curPre]:SetFrame(data.headFrame)
        this.playerHead[curPre]:SetLevel(data.level)
        name.text = SetRobotName(data.uid, data.name)
        Util.AddOnceClick(head,function()
            UIManager.OpenPanel(UIName.PlayerInfoPopup, data.uid)
        end)
    else
        if this.playerHead[curPre] then
            this.playerHead[curPre] = nil
        end
        name.text = ""
    end
end
--设置战斗回放按钮
function this.SetPlayBack(fightResult, id, defInfo, attackInfo)
    if fightResult == -1 then
        PopupTipPanel.ShowTipByLanguageId(50234)
        return
    end
    -- playBackBtn:SetActive(_IsShowData and fightResult~=-1)
    -- Util.AddOnceClick(playBackBtn,function()
        --> fightInfo

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
    -- end)
end

--界面关闭时调用（用于子类重写）
function TopMatchPlayBattleAinSelectPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function TopMatchPlayBattleAinSelectPopup:OnDestroy()
   
end

return TopMatchPlayBattleAinSelectPopup