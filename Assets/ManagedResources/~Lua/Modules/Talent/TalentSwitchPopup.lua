require("Base/BasePanel")
TalentSwitchPopup = Inherit(BasePanel)
local this = TalentSwitchPopup

--> 技能没配表 固定 策划写表可走表
local skillIdArray = {{810101, 810102, 810103}, {}, {}, {}, {}}

local curHeroData
local pos
local curSelect
--初始化组件（用于子类重写）
function TalentSwitchPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")

    this.activeBtn = Util.GetGameObject(self.gameObject, "activeBtn")
    this.Skill = Util.GetGameObject(self.gameObject, "Skill")
    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition

    this.Text = Util.GetGameObject(self.gameObject, "GameObject/Image/Num"):GetComponent("Text")
    this.GameObject = Util.GetGameObject(self.gameObject, "GameObject")
    this.lvUpBtn = Util.GetGameObject(self.gameObject, "lvUpBtn")
end

--绑定事件（用于子类重写）
function TalentSwitchPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Talent,this.helpPosition.x,this.helpPosition.y)
    end)

    Util.AddClick(this.lvUpBtn, function()
        
        NetManager.InnateSkillActivateRequest(curHeroData.dynamicId, pos, skillIdArray[pos][curSelect], function(msg)            
            self:ClosePanel()
            HeroManager.SetHeroTalentData(curHeroData, msg)
            if RoleInfoPanel then
                RoleInfoPanel:UpdateTalentData()
            end
        end)
    end)
end

--添加事件监听（用于子类重写）
function TalentSwitchPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function TalentSwitchPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function TalentSwitchPopup:OnOpen(...)
    local args = {...}

    pos = args[1]
    curHeroData = args[2]
    curSelect = 1
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function TalentSwitchPopup:OnShow()
    this.Text.text = pos
    this.SetDownSkill()
    this.UpdateSelect()
end

function TalentSwitchPopup.UpdateSkill(skillid)
    local icon = Util.GetGameObject(this.Skill, "icon")
    local Name = Util.GetGameObject(this.Skill, "Name")
    local Des = Util.GetGameObject(this.Skill, "Des")


    local skillConfig = G_PassiveSkillConfig[skillid]
    local skillLogicInner = G_PassiveSkillLogicConfig[skillid]



    icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
    Name:GetComponent("Text").text = GetLanguageStrById(skillConfig.Name)
    Des:GetComponent("Text").text = GetSkillConfigDesc(skillConfig, false, 1)
    
    Util.AddOnceClick(icon, function()
        local skillData = {}
        skillData.skillId = skillid
        skillData.skillConfig = skillConfig       
        local panel = UIManager.OpenPanel(UIName.SkillInfoPopup, skillData, 1, nil, nil, 3, nil)
    end)
end

function TalentSwitchPopup.SetSkill(go, skillid)
    local icon = Util.GetGameObject(go, "icon")

    local skillConfig = G_PassiveSkillConfig[skillid]
    icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))

end

function TalentSwitchPopup.SetDownSkill()
    for i = 1, 3 do
        local go = Util.GetGameObject(this.gameObject, "GameObject/Skill (" .. tostring(i) .. ")")
        local skillid = skillIdArray[pos][i]
        this.SetSkill(go, skillid)

        Util.AddClick(Util.GetGameObject(go, "icon"), function()
            if curSelect ~= i then
                curSelect = i
                this.UpdateSelect()
            else
            end
        end)
    end
end

function TalentSwitchPopup.UpdateSelect()
    for i = 1, 3 do
        local go = Util.GetGameObject(this.gameObject, "GameObject/Skill (" .. tostring(i) .. ")")
        local skillid = skillIdArray[pos][i]
        Util.GetGameObject(go, "select"):SetActive(false)
        if curSelect == i then
            Util.GetGameObject(go, "select"):SetActive(true)

            this.UpdateSkill(skillid)
        end
    end
end

--界面关闭时调用（用于子类重写）
function TalentSwitchPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function TalentSwitchPopup:OnDestroy()

end

return TalentSwitchPopup