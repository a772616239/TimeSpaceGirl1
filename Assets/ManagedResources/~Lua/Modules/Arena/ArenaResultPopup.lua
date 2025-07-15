
require("Base/BasePanel")
local ArenaResultPopup = Inherit(BasePanel)
local this = ArenaResultPopup
local orginLayer
local fun = nil
--初始化组件（用于子类重写）
function ArenaResultPopup:InitComponent()
    orginLayer = 0
    this.mask = Util.GetGameObject(self.transform, "mask")
    this.win = Util.GetGameObject(self.transform, "win")
    this.lose = Util.GetGameObject(self.transform, "lose")
    this.winEffect = Util.GetGameObject(self.transform, "win/Effect")
    this.loseEffect = Util.GetGameObject(self.transform, "lose/Effect (1)")
    this.btnResult = Util.GetGameObject(self.transform, "btnResult")

    screenAdapte(this.winEffect)
    screenAdapte(this.loseEffect)
end

--绑定事件（用于子类重写）
function ArenaResultPopup:BindEvent()
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnResult, function()
        UIManager.OpenPanel(UIName.DamageResultPanel, this.realResult)
    end)
end

--添加事件监听（用于子类重写）
function ArenaResultPopup:AddListener()
end

--移除事件监听（用于子类重写）
function ArenaResultPopup:RemoveListener()
end

function ArenaResultPopup:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.winEffect, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.loseEffect, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

--界面打开时调用（用于子类重写）
function ArenaResultPopup:OnOpen(_args,_fun)
    SoundManager.PlaySound(SoundConfig.Sound_Arena_Result)

    -- local pack = {...}
    local args = _args
    fun = _fun
    if not args then return end

    this.realResult = args.result
    local panelType = args.panelType or 0
    local isWin = args.result == 1
    local blueInfo = args.blue
    local redInfo = args.red
    -- -- 如果我在防守方，交换数据，我要显示在蓝方
    -- if redInfo.uid == PlayerManager.uid then
    --     blueInfo = args.red
    --     redInfo = args.blue
    --     isWin = not isWin
    -- end

    this.win:SetActive(isWin)
    this.winEffect:SetActive(isWin)
    this.lose:SetActive(not isWin)
    this.loseEffect:SetActive(not isWin)
    local _CurPanel = isWin and this.win or this.lose

    local blueName = Util.GetGameObject(_CurPanel, "Left/Grade/name"):GetComponent("Text")
    local blueHeadIcon = Util.GetGameObject(_CurPanel, "Left/Grade/headIcon")
    local blueHeadBg = Util.GetGameObject(_CurPanel, "Left/Grade/headBg")
    local blueScore = Util.GetGameObject(_CurPanel, "Left/Grade/score")
    local blueResult = Util.GetGameObject(_CurPanel, "Left/result")

    local redName = Util.GetGameObject(_CurPanel, "Right/Grade/name"):GetComponent("Text")
    local redHeadIcon = Util.GetGameObject(_CurPanel, "Right/Grade/headIcon")
    local redHeadBg = Util.GetGameObject(_CurPanel, "Right/Grade/headBg")
    local redScore = Util.GetGameObject(_CurPanel, "Right/Grade/score")
    local redResult = Util.GetGameObject(_CurPanel, "Right/result")

    local bigResult = Util.GetGameObject(_CurPanel, "words"):GetComponent("Image")

    if blueInfo.uid == PlayerManager.uid then
        blueName.text = PlayerManager.nickName
    else
        blueName.text = SetRobotName(blueInfo.uid, blueInfo.name)
    end
    if redInfo.uid == PlayerManager.uid then
        redName.text = PlayerManager.nickName
    else
        redName.text = SetRobotName(redInfo.uid, redInfo.name)
    end

    blueHeadIcon:GetComponent("Image").sprite = GetPlayerHeadSprite(blueInfo.head)
    redHeadIcon:GetComponent("Image").sprite = GetPlayerHeadSprite(redInfo.head)
    blueHeadBg:GetComponent("Image").sprite = GetPlayerHeadFrameSprite(blueInfo.frame)
    redHeadBg:GetComponent("Image").sprite = GetPlayerHeadFrameSprite(redInfo.frame)

    -- 积分
    local bScore = blueInfo.deltaScore
    if bScore then
        blueScore:SetActive(true)
        local blueScoreColor = bScore >= 0 and UIColorStr.GREEN or UIColorStr.RED
        local blueScoreStr = bScore >= 0 and "+"..bScore or bScore
        blueScore:GetComponent("Text").text = string.format(GetLanguageStrById(10093), blueScoreColor, blueScoreStr)
    else
        blueScore:SetActive(false)
    end

    local rScore = redInfo.deltaScore
    if rScore then
        redScore:SetActive(true)
        local redScoreColor = rScore >= 0 and UIColorStr.GREEN or UIColorStr.RED
        local redScoreStr = rScore >= 0 and "+"..rScore or rScore
        redScore:GetComponent("Text").text = string.format(GetLanguageStrById(10093),redScoreColor, redScoreStr)
    else
        redScore:SetActive(false)
    end

    -- 判断显示类型
    if panelType == 0 then
        blueResult:SetActive(false)
        redResult:SetActive(false)
        bigResult.sprite = Util.LoadSprite(isWin and "cn2-X1_tongyong_shengli" or "cn2-X1_tongyong_shibai")
        bigResult:SetNativeSize()
    else
        blueResult:SetActive(true)
        redResult:SetActive(true)
        bigResult.sprite = Util.LoadSprite(isWin and "cn2-X1_tongyong_shengli" or "cn2-X1_tongyong_shibai")
        bigResult.transform.sizeDelta = Vector2.New(420, 420)
    end

    this._IsWin = isWin

    local isRecord, record = BattleRecordManager.isHaveRecord()
    this.btnResult:SetActive(isRecord)
end

--界面关闭时调用（用于子类重写）
function ArenaResultPopup:OnClose()
    if fun then
        fun()
        fun = nil
    end

    ArenaManager.RequestNextPageRank(true)
end

--界面销毁时调用（用于子类重写）
function ArenaResultPopup:OnDestroy()
end

return ArenaResultPopup