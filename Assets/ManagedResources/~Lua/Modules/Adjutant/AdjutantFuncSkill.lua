
local this = {}

local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)

--初始化组件（用于子类重写）
function this:InitComponent(parentNode)
    this.parentNode = parentNode
    this.btn_upLvBtn = Util.GetGameObject(this.parentNode, "SkillDown/upLvBtn")
    this.btn_upLvBtnRedpot = Util.GetGameObject(this.parentNode, "SkillDown/upLvBtn/Redpot")

    this.SkillIcon = Util.GetGameObject(this.parentNode, "SkillIcon")
    this.SkillDescCur = Util.GetGameObject(this.parentNode, "SkillDescCur"):GetComponent("Text")
    this.SkillDescNext = Util.GetGameObject(this.parentNode, "SkillDown/SkillDescNext"):GetComponent("Text")
    this.Level = Util.GetGameObject(this.parentNode, "Level"):GetComponent("Text")
    this.SkillName = Util.GetGameObject(this.parentNode, "SkillName"):GetComponent("Text")

    this.SkillDown = Util.GetGameObject(this.parentNode, "SkillDown")
    this.MaxPic = Util.GetGameObject(this.parentNode, "MaxPic")
end

--绑定事件（用于子类重写）
function this:BindEvent()
end

--添加事件监听（用于子类重写）
function this:AddListener()
    -- Game.GlobalEvent:AddEvent(GameEvent.Adjutant.OnAdjutantChange,this.UpdateUI)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    -- Game.GlobalEvent:RemoveListener(GameEvent.Adjutant.OnAdjutantChange,self)
end

--界面打开时调用（用于子类重写）
function this:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow(fun)
    self.adjutantId = AdjutantManager.GetCurSelectAdjutantId()
    self:UpdateUI()
    --BindRedPointObject(RedPointType.Adjutant_Btn_SkillChild,this.btn_upLvBtnRedpot)
end

function this:UpdateUI()
    self.data = AdjutantManager.GetOneAdjutantDataById(self.adjutantId)
    local curLv = self.data.skillLevel
    local curLvData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantSkillConfig, "AdjutantId", self.adjutantId, "SkillLvl", curLv)
    this.SkillIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillConfig[curLvData.Skill_Id].Icon))
    this.SkillDescCur.text = GetSkillConfigDesc(skillConfig[curLvData.Skill_Id])--skillConfig[curLvData.Skill_Id].Desc
    this.Level.text = string.format(GetLanguageStrById(22309), curLv)
    this.SkillName.text = GetLanguageStrById(skillConfig[curLvData.Skill_Id].Name)

    if curLv >= AdjutantManager.GetMaxLimit(self.adjutantId, 2) then
        this.SkillDown:SetActive(false)
        this.MaxPic:SetActive(true)
        return
    else
        this.SkillDown:SetActive(true)
        this.MaxPic:SetActive(false)
    end

    local nextLv = self.data.skillLevel + 1
    Util.GetGameObject(this.parentNode, "SkillDown/Level"):GetComponent("Text").text = string.format(GetLanguageStrById(22309), nextLv)
    local nextLvData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantSkillConfig, "AdjutantId", self.adjutantId, "SkillLvl", nextLv)
    this.SkillDescNext.text = GetSkillConfigDesc(skillConfig[nextLvData.Skill_Id])--skillConfig[nextLvData.Skill_Id].Desc

    local enough = true
    for i = 1, 2 do
        local itemId = curLvData.Cost[i][1]
        local itemData = itemConfig[itemId]
        local bagNum = BagManager.GetItemCountById(itemId)
        Util.GetGameObject(this.parentNode, "SkillDown/Cost" .. i .. "/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
        local str
        if bagNum >= curLvData.Cost[i][2] then
            str = PrintWanNum(bagNum)
        else
            str = string.format("<color=#FF6868>%s</color>",PrintWanNum(bagNum))
        end

        Util.GetGameObject(this.parentNode, "SkillDown/Cost" .. i .. "/Num"):GetComponent("Text").text = str.."/"..PrintWanNum(curLvData.Cost[i][2])
        if bagNum < curLvData.Cost[i][2] then
            enough = false
        end
        ItemImageTips(itemId, Util.GetGameObject(this.parentNode, "SkillDown/Cost" .. i .. "/icon"))
    end

    Util.AddOnceClick(this.btn_upLvBtn, function()
        if enough then
            if self.data.chatLevel < curLvData.LimitLvl then
                -- PopupTipPanel.ShowTipByLanguageId(22316)
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(50241), curLvData.LimitLvl))
            else
                local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
                NetManager.GetAdjutantSkill(self.adjutantId, function()
                    NetManager.GetAllAdjutantInfo(function()    --< 需要重拉下数据 目前和后端这么定
                        self:UpdateUI()
                        RefreshPower(oldPower)
                        CheckRedPointStatus(RedPointType.Adjutant_Btn_Skill)
                        -- AdjutantPanel.SetTabAdjutantUI()
                    end)
                end)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(10073)
        end
    end)

    this.btn_upLvBtnRedpot:SetActive(AdjutantManager.IsSkillEnough(self.adjutantId))
end


--界面关闭时调用（用于子类重写）
function this:OnClose()
    --ClearRedPointObject(RedPointType.Adjutant_Btn_SkillChild,this.btn_upLvBtnRedpot)
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

return this