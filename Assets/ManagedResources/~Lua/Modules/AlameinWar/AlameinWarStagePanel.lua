require("Base/BasePanel")
AlameinWarStagePanel = Inherit(BasePanel)
local this = AlameinWarStagePanel

local heroTData
local stageGo = {}
--初始化组件（用于子类重写）
function AlameinWarStagePanel:InitComponent()
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)

    this.choose = Util.GetGameObject(self.gameObject, "Root/Choose")
    this.backBtn = Util.GetGameObject(this.choose , "backBtn")
    this.btnhelp = Util.GetGameObject(this.choose , "btnhelp")
    this.helpPosition = this.btnhelp:GetComponent("RectTransform").localPosition

    this.Button = Util.GetGameObject(this.choose , "Times/Button")
    this.ChallengeTimes = Util.GetGameObject(this.choose , "Times/ChallengeTimes")
    this.LastBuyTimes = Util.GetGameObject(this.choose , "Times/LastBuyTimes")

    for i = 1, 10 do
        stageGo[i] = Util.GetGameObject(this.choose, "Stage/stage" .. tostring(i))
    end
    this.Select = Util.GetGameObject(this.choose, "Stage/Select")

    this.TitleTxt = Util.GetGameObject(this.choose, "title"):GetComponent("Text")
    this.LeftBtn = Util.GetGameObject(this.choose, "LeftBtn")
    this.RightBtn = Util.GetGameObject(this.choose, "RightBtn")

    this.ExpBar = Util.GetGameObject(this.choose, "BoxModel/ExpBar"):GetComponent("Slider")
    this.StarNum = Util.GetGameObject(this.choose, "BoxModel/Star/Num"):GetComponent("Text")
    this.boxs = {}
    this.boxs[1] = Util.GetGameObject(this.choose, "BoxModel/wood")
    this.boxs[2] = Util.GetGameObject(this.choose, "BoxModel/silver")
    this.boxs[3] = Util.GetGameObject(this.choose, "BoxModel/gold")

    this.challenge = Util.GetGameObject(self.gameObject, "Challenge")
    this.FightBtn = Util.GetGameObject(this.challenge, "btn")
    this.BossIcon = Util.GetGameObject(this.challenge, "BossIcon")
    this.StageTxt = Util.GetGameObject(this.challenge, "Stage"):GetComponent("Text")
    this.Power = Util.GetGameObject(this.challenge, "Power/Power"):GetComponent("Text")
    this.starTasks = {}
    for i = 1, 3 do
        this.starTasks[i] = Util.GetGameObject(this.challenge, "StarTask/Task" .. tostring(i))
    end
    this.RewardGrid = Util.GetGameObject(this.challenge, "Grid/RewardGrid")

    this.itemList = {}
end

--绑定事件（用于子类重写）
function AlameinWarStagePanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.Button, function()
        AlameinWarManager.BuyTimesBtn()
    end)

    Util.AddClick(this.LeftBtn, function()
        self:ClickLeft()
    end)

    Util.AddClick(this.RightBtn, function()
        self:ClickRight()
    end)

    Util.AddClick(this.btnhelp, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.ElAlamein,this.helpPosition.x,this.helpPosition.y) 
    end)
    
    Util.AddClick(this.challenge,function ()
        this.challenge:SetActive(false)
    end)
end

--添加事件监听（用于子类重写）
function AlameinWarStagePanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.AlameinWar.RefreshTimes, this.RefreshTimes, this)
end

--移除事件监听（用于子类重写）
function AlameinWarStagePanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.AlameinWar.RefreshTimes, this.RefreshTimes, this)
end

--界面打开时调用（用于子类重写）
function AlameinWarStagePanel:OnOpen(...)
    local args = {...}
    this.chapter = args[1]  
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AlameinWarStagePanel:OnShow()
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.AlameinWarPanel })
    this.UpdateMain(this.chapter==-1)
end

-- isEndFight 是否是最后位置
function AlameinWarStagePanel.UpdateMain(isEndFight)
    if isEndFight then
        this.chapter = #AlameinWarManager.chapters
    end
    this.stage = AlameinWarManager.GetInitStageByChapter(this.chapter)
    this:UpdateUI()
end

function AlameinWarStagePanel:UpdateUI()
    self:ChangeChapterUI(this.chapter)
    self:ChangeStageUI(this.stage)
    self:RefreshTimes()
    self:UpdateArrow()
end

function AlameinWarStagePanel:ChangeChapterUI(chapter)
    local stages = AlameinWarManager.chapters[chapter]
    if stages == nil then
        LogError("ChangeChapter Error!!!")
    end
    for i = 1, 10 do
        local Btn = Util.GetGameObject(stageGo[i], "Btn")
        if stages[i] then
            for j = 1, 3 do
                local star = Util.GetGameObject(stageGo[i], "Star/star" .. tostring(j))
                if j <= #stages[i].finishedStarIds then
                    star:SetActive(true)
                else
                    star:SetActive(false)
                end
            end
            Util.AddOnceClick(Btn, function()
                this.challenge:SetActive(true)
                this.stage = stages[i].cfgId
                self:ChangeStageUI(this.stage)
            end)
        else
            for j = 1, 3 do
                local star = Util.GetGameObject(stageGo[i], "Star/star" .. tostring(j))
                star:SetActive(false)
            end
            Util.AddOnceClick(Btn, function()

            end)
        end

        Util.GetGameObject(stageGo[i], "Image/Text"):GetComponent("Text").text = chapter .. "-" .. i
    end

    this.TitleTxt.text = string.format(GetLanguageStrById(22416), chapter)

    local totalStars = AlameinWarManager.GetChapterStars(chapter)
    this.StarNum.text = totalStars .. "/30"
    this.ExpBar.value = totalStars / 30

    for i = 1, 3 do
        local boxGo = this.boxs[i]
        local n = Util.GetGameObject(boxGo, "n")
        local o = Util.GetGameObject(boxGo, "o")
        local redPoint = Util.GetGameObject(boxGo, "redpoint")
        n:SetActive(false)
        o:SetActive(false)
        redPoint:SetActive(false)
        if totalStars >= AlameinWarManager.boxStarNum[i] then
            if AlameinWarManager.CheckBoxIsOpend(i, chapter) then
                -- opened
                o:SetActive(true)
            else
                -- can get
                n:SetActive(true)
                redPoint:SetActive(true)
                Util.AddOnceClick(n, function()
                    NetManager.AlameinBattleBoxGetRequest(chapter, i, function(msg)
                        AlameinWarManager.RequestMainData(function()
                            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
                                this:UpdateUI()
                            end)
                        end)
                    end)
                end)
            end
        else
            n:SetActive(true)
            -- no reached
            Util.AddOnceClick(n, function()
                PopupTipPanel.ShowTipByLanguageId(10348)
            end)
        end
    end
end

function AlameinWarStagePanel:ChangeStageUI(stageId)
    local stage = AlameinWarManager.stagesById[stageId]
    
    if this.live then
        UnLoadHerolive(heroTData,this.live)
        Util.ClearChild(this.BossIcon.transform)
    end

    local AlameinLevel = ConfigManager.GetConfig(ConfigName.AlameinLevel)
    local MonsterGroup = ConfigManager.GetConfig(ConfigName.MonsterGroup)
    local MonsterConfig  = ConfigManager.GetConfig(ConfigName.MonsterConfig)
    shoujun = AlameinLevel[stageId].MonsterGroup
    boss = MonsterGroup[shoujun].Contents[1][1]
    heroId = MonsterConfig[boss].MonsterId
    heroTData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroId)
    this.live = LoadHerolive(heroTData,this.BossIcon.transform)

    --> item
    local itemDatas = nil
    if stage.cfgId == AlameinWarManager.curFightCfgId then  --< 末关-1 应该不等
        itemDatas = stage.alameinConfig.FirstAward
    else
        itemDatas = stage.alameinConfig.AutoAward
    end

    for i = 1, #this.itemList do
        this.itemList[i].gameObject:SetActive(false)
    end
    for i = 1, #itemDatas do
        if this.itemList[i] == nil then
            this.itemList[i] = SubUIManager.Open(SubUIConfig.ItemView, this.RewardGrid.transform)
        end
        this.itemList[i]:OnOpen(false, {itemDatas[i][1], itemDatas[i][2]}, 0.77, nil, nil, nil, nil, nil)
        this.itemList[i].gameObject:SetActive(true)
    end
    if #stage.finishedStarIds == 3 then
        --> sweep
        this.FightBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_miwuzhizhan_saodang"))
        Util.AddOnceClick(this.FightBtn, function()
            if AlameinWarManager.challengeTimes <= 0 then
                PopupTipPanel.ShowTipByLanguageId(11048)
                return
            end
            NetManager.AlameinBattleSweepRequest(stage.cfgId, function(msg)
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1, function()
                end)
                AlameinWarManager.challengeTimes = AlameinWarManager.challengeTimes - 1
                Game.GlobalEvent:DispatchEvent(GameEvent.AlameinWar.RefreshTimes)
            end)
        end)
    else
        --> fight
        this.FightBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_miwuzhizhan_zhandou"))
        Util.AddOnceClick(this.FightBtn, function()
            if AlameinWarManager.challengeTimes <= 0 then
                PopupTipPanel.ShowTipByLanguageId(11048)
                return
            end
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ALAMEIN_WAR, stage.cfgId)
        end)
    end

    this.StageTxt.text = GetLanguageStrById(stage.alameinConfig.Name)
    this.Power.text = stage.alameinConfig.NeedFight
    
    --> startask
    for i = 1, #stage.alameinConfig.StarCondServer do
        local des = Util.GetGameObject(this.starTasks[i], "Des"):GetComponent("Text")
        local Star = Util.GetGameObject(this.starTasks[i], "Star")
        local taskid = stage.alameinConfig.StarCondServer[i][1]
        local StarCondServer = stage.alameinConfig.StarCondServer[i]

        local desstr = GVM.GetTaskById(taskid, unpack(StarCondServer, 2, #StarCondServer))
        des.text = desstr

        Star:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_miwuzhizhan_xingxingkong")
        local isFinished = false
        for j = 1, #stage.finishedStarIds do
            if stage.finishedStarIds[j] == taskid then
                isFinished = true
                Star:GetComponent("Image").sprite = Util.LoadSprite("cn2-x1_TB_xing_01")
                break
            end
        end
        -- Star:SetActive(isFinished)
    end
    
    local stageNum = string.sub(tostring(stage.cfgId), -2, -1)
    this.Select.transform:SetParent(Util.GetGameObject(stageGo[tonumber(stageNum)], "s").transform)
    this.Select.transform.localPosition = Vector3.zero
    this.Select.transform.localScale = Vector3.one
end

function AlameinWarStagePanel:RefreshTimes()
    -- local specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "AlameinTime")
    local upLimit = PrivilegeManager.GetPrivilegeNumber(40002)
    this.ChallengeTimes:GetComponent("Text").text = AlameinWarManager.challengeTimes .. "/" .. upLimit
    this.LastBuyTimes:GetComponent("Text").text = AlameinWarManager.residueBuyTimes
end

function AlameinWarStagePanel:ClickLeft()
    if this.chapter <= 1 then
        return
    end
    this.chapter = this.chapter - 1
    this.stage = AlameinWarManager.GetInitStageByChapter(this.chapter)
    self:UpdateUI()
    
end

function AlameinWarStagePanel:ClickRight()
    if this.chapter >= AlameinWarManager.GetMaxChapter() then
        return
    end
    this.chapter = this.chapter + 1
    this.stage = AlameinWarManager.GetInitStageByChapter(this.chapter)
    self:UpdateUI()
end

function AlameinWarStagePanel:UpdateArrow()
    this.LeftBtn:SetActive(true)
    this.RightBtn:SetActive(true)
    if this.chapter <= 1 then
        this.LeftBtn:SetActive(false)
    end

    if this.chapter >= AlameinWarManager.GetMaxChapter() then
        this.RightBtn:SetActive(false)
    end
end

--界面关闭时调用（用于子类重写）
function AlameinWarStagePanel:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function AlameinWarStagePanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    -- SubUIManager.Close(this.BtView)
    if this.live then
        UnLoadHerolive(heroTData,this.live)
        Util.ClearChild(this.BossIcon.transform)
    end

    this.itemList = {}
end

return AlameinWarStagePanel