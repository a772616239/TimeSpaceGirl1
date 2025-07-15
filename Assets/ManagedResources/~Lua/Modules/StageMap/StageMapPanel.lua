require("Base/BasePanel")
StageMapPanel = Inherit(BasePanel)

local mainLevelSettingConfig = ConfigManager.GetConfig(ConfigName.MainLevelSettingConfig)

local this = StageMapPanel

local nodePreArray = {}
-->-247  spacing 200  width 47
local W = 347.5

local selectChapterIdx = 1

--初始化组件（用于子类重写）
function StageMapPanel:InitComponent()
    self.ctrl = Util.GetGameObject(self.gameObject, "bg/ctrl")
    self.backBtn = Util.GetGameObject(self.gameObject, "backBtn")
    self.Button = Util.GetGameObject(self.gameObject, "bg/Button")
    
    self.scroll = Util.GetGameObject(self.gameObject, "bg/bottom/mask/scroll")
    self.grid = Util.GetGameObject(self.gameObject, "bg/bottom/scroll/grid")
    self.Slider = Util.GetGameObject(self.gameObject, "bg/bottom/scroll/grid/Slider")
    self.originNode = Util.GetGameObject(self.gameObject, "bg/bottom/scroll/grid/originNode")
    self.nodePre = Util.GetGameObject(self.gameObject, "bg/bottom/nodePre")

    -- self.titleTxt = Util.GetGameObject(self.gameObject, "bg/infomation/title"):GetComponent("Text")
    self.contentTxt = Util.GetGameObject(self.gameObject, "bg/infomation/content"):GetComponent("Text")

    this.Slider:GetComponent("Slider").value = 0

    -- this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.transform)
    -- this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)
end

--绑定事件（用于子类重写）
function StageMapPanel:BindEvent()
    self.trigger = Util.GetEventTriggerListener(self.ctrl)
    self.moveTween = self.grid:GetComponent(typeof(UITweenSpring))
    if not self.moveTween then
        self.moveTween = self.grid:AddComponent(typeof(UITweenSpring))
    end
    self.moveTween.enabled = false

    local setPosFunc = function(v2)
        local av2 = this.grid.transform.anchoredPosition
        local dv2 = Vector2.New(math.clamp(v2.x + av2.x, -this.W, 0), av2.y)
        this.grid.transform.anchoredPosition = dv2
    end

    self.moveTween.OnUpdate = setPosFunc
    self.moveTween.OnMoveEnd = function()
        this:SetPos()
    end
    self.moveTween.MomentumAmount = 1
    self.moveTween.Strength = 2

    self.trigger.onBeginDrag = self.trigger.onBeginDrag + function(p, d)
        self.moveTween.enabled = true
        self.moveTween.Momentum = Vector3.zero
        self.moveTween.IsUseCallBack = false
    end
    self.trigger.onDrag = self.trigger.onDrag + function(p, d)
        self.moveTween:LerpMomentum(d.delta)
        setPosFunc(d.delta)
    end
    self.trigger.onEndDrag = self.trigger.onEndDrag + function(p, d)
        self.moveTween.IsUseCallBack = true
        setPosFunc(d.delta)
    end
    self.trigger.enabled = false

    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)

end

function StageMapPanel:SetPos(pos)
    local idx = pos
    if not pos then
        local oldpty = self.grid.transform.anchoredPosition.x
        idx = math.floor(math.abs(oldpty)/W)
        local fb = math.abs(oldpty)%W
        if fb > (W/2) then
            idx = idx + 1
        end
    end

    self.grid.transform.anchoredPosition = Vector2.New(-W * idx, 0)

    selectChapterIdx = idx + 1

    self:UpdateUI()
end

function StageMapPanel:GetPos(pos)
    local idx = pos
    if not pos then
        local oldpty = self.grid.transform.anchoredPosition.x
        idx = math.floor(math.abs(oldpty)/W)
        local fb = math.abs(oldpty)%W
        if fb > (W/2) then
            idx = idx + 1
        end
    end

    return Vector2.New(-W * idx, 0)
end

function StageMapPanel:MoveChapter(v1, v2)
    self.grid.transform.anchoredPosition = Vector3.New(v1.x, v1.y, 0)
    self.grid.transform:DOLocalMove(v2, 1, false):SetEase(Ease.Linear):OnComplete(function()
        self:SetPos(this.chapterIdx - 1)
        FightPointPassManager.SetChapterOpenState(false)

        Timer.New(function()
            local curChapterId = mainLevelSettingConfig[this.chapterIdx].EventId
            UIManager.OpenPanel(UIName.FightPointPassMainPanel, function() 
                -- 章节解锁时添加对话
                StoryManager.EventTrigger(curChapterId)
            end)
        end, BattleLogic.GameDeltaTime*15):Start()

        
    end)
end

-- -- 刷新玩家信息显示
-- function StageMapPanel.FreshPlayerInfo()
--     this.level.text = PlayerManager.level
--     this.expSliderValue.value = PlayerManager.exp / PlayerManager.userLevelData[PlayerManager.level].Exp
--     this.playName.text = PlayerManager.nickName
--     this.teamPower.text = FormationManager.GetFormationPower(FormationManager.curFormationIndex)
-- end

--添加事件监听（用于子类重写）
function StageMapPanel:AddListener()
end

--移除事件监听（用于子类重写）
function StageMapPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function StageMapPanel:OnOpen(...)
    local args = {...}
    this.isAction = args[1]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function StageMapPanel:OnShow()
    Timer.New(function()
        this.W = this.originNode.transform.rect.width
        this.Slider.transform.sizeDelta = Vector2.New(this.W + W, 9)
        this.trigger.enabled = true
        self:SetSlider()

        if this.isAction then
            StageMapPanel:MoveChapter(self:GetPos(math.max(this.chapterIdx - 2, 0)), self:GetPos(math.max(this.chapterIdx - 1, 0)))
        else
            self:SetPos(this.chapterIdx - 1)
        end

        for i = 1, FightPointPassManager.maxChapterNum do
            if nodePreArray[i] then
                Util.SetGray(nodePreArray[i], i > this.chapterIdx)
            end
        end
    end, BattleLogic.GameDeltaTime*2):Start()

    for i = 1, FightPointPassManager.maxChapterNum do
        if not nodePreArray[i] then
            nodePreArray[i] = newObject(self.nodePre)
            nodePreArray[i]:SetActive(true)
            nodePreArray[i].name = "chapter_" .. tostring(i)
            nodePreArray[i].transform:SetParent(self.originNode.transform)
            nodePreArray[i].transform.localScale = Vector3.one
            nodePreArray[i].transform.localPosition = Vector3.zero

            Util.GetGameObject(nodePreArray[i], "num"):GetComponent("Text").text = string.format(GetLanguageStrById(22416), mainLevelSettingConfig[i].Id)
            Util.GetGameObject(nodePreArray[i], "Text"):GetComponent("Text").text = GetLanguageStrById(mainLevelSettingConfig[i].Name)
        end
    end
    -- FightPointPassManager.lastPassFightId = 13202

    -- this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.StageMap })
    -- this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.StageMap })

    -- if not this.playerHead then
    --     this.playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.headPos.transform)
    -- end
    -- this.playerHead:SetHead(PlayerManager.head)
    -- this.playerHead:SetFrame(PlayerManager.frame)
    -- StageMapPanel.FreshPlayerInfo()
end

function StageMapPanel:SetSlider()
    this.chapterIdx = 1
    local stageIdx = 1
    local chapterStageMax = 0
    for i = 1, FightPointPassManager.maxChapterNum do
        for j = 1, #mainLevelSettingConfig[i].SimpleLevel do

            if FightPointPassManager.curOpenFight == mainLevelSettingConfig[i].SimpleLevel[j] then
                this.chapterIdx = i
                stageIdx = j
                chapterStageMax = #mainLevelSettingConfig[i].SimpleLevel
            end
        end
    end

    local stagePercent = stageIdx / chapterStageMax

    this.Slider:GetComponent("Slider").value = (this.chapterIdx-1 + stagePercent) / FightPointPassManager.maxChapterNum
end

function StageMapPanel:UpdateUI()
    self.contentTxt.text = GetLanguageStrById(mainLevelSettingConfig[selectChapterIdx].info)
end

--界面关闭时调用（用于子类重写）
function StageMapPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function StageMapPanel:OnDestroy()
    if this.playerHead then
        this.playerHead:Recycle()
        this.playerHead = nil
    end
    nodePreArray = {}
end

return StageMapPanel