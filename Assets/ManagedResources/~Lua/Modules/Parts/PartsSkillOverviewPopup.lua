require("Base/BasePanel")
PartsSkillOverviewPopup = Inherit(BasePanel)
local this = PartsSkillOverviewPopup
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local SkillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local PassiveSkillLogicConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local PassiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local curHeroData
local curPos
--初始化组件（用于子类重写）
function PartsSkillOverviewPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    this.scrollRoot = Util.GetGameObject(this.gameObject, "scroll")
    this.ScrollPre = Util.GetGameObject(this.gameObject, "ScrollPre")

    local w = this.scrollRoot.transform.rect.width
    local h = this.scrollRoot.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform, this.ScrollPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 10))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function PartsSkillOverviewPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function PartsSkillOverviewPopup:AddListener()
end

--移除事件监听（用于子类重写）
function PartsSkillOverviewPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function PartsSkillOverviewPopup:OnOpen(...)
    local args = {...}

    curHeroData = args[1]
    curPos = args[2]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PartsSkillOverviewPopup:OnShow()
    local skillList = HeroManager.GetHeroSkillSortList(curHeroData)
    local skillid = skillList[curPos].skillId
    
    this.curSkillLv = curHeroData.partsData[curPos].actualLv
    this.skillOrigin = tonumber(string.sub(tostring(skillid), 1, -2) .. "3")
    this._isPassivity = false
    if SkillLogicConfig[skillid] then
        this._isPassivity = false
    elseif PassiveSkillLogicConfig[skillid] then
        this._isPassivity = true
    end

    local data = {1, 2, 3, 4, 5}
    this.scrollView:SetData(data, function(index, root)
        this.SetUIWithData(root, data[index], index)
    end)
    this.scrollView:SetIndex(1)
end

function this.SetUIWithData(go, data, index)
    local icon = Util.GetGameObject(go, "icon")
    local Name = Util.GetGameObject(go, "Name")
    local Des = Util.GetGameObject(go, "Des")
    local Cur = Util.GetGameObject(go, "Cur")

    local skillid = this.skillOrigin + index
    local skillLogic
    local skillConfig
    if this._isPassivity then
        skillLogic = PassiveSkillLogicConfig[skillid]
        skillConfig = PassiveSkillConfig[skillid]
        Des:GetComponent("Text").text = GetSkillConfigDesc(skillConfig, false, 1)
    else
        skillLogic = SkillLogicConfig[skillid]
        skillConfig = SkillConfig[skillid]
        Des:GetComponent("Text").text = GetSkillConfigDesc(skillConfig)
    end
    
    icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
    Name:GetComponent("Text").text = GetLanguageStrById(skillConfig.Name) .. " Lv" .. skillLogic.Level

    Util.AddOnceClick(icon, function()
        local maxLv = HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id, curPos)
        local skillData = {}
        skillData.skillId = skillid
        skillData.skillConfig = skillConfig       
        UIManager.OpenPanel(UIName.SkillInfoPopup, skillData, 1, 10, maxLv, curPos, skillConfig.Level)
    end)

    Cur:SetActive(index == this.curSkillLv)
end

--界面关闭时调用（用于子类重写）
function PartsSkillOverviewPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function PartsSkillOverviewPopup:OnDestroy()
end

return PartsSkillOverviewPopup