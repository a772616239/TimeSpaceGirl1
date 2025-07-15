require("Base/BasePanel")
CombatPlanSelectPopup = Inherit(BasePanel)
local this = CombatPlanSelectPopup
local WarWaySkillConfig = ConfigManager.GetConfig(ConfigName.WarWaySkillConfig)

--初始化组件（用于子类重写）
function CombatPlanSelectPopup:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnClose = Util.GetGameObject(self.gameObject, "btnClose")
    this.btn = Util.GetGameObject(self.gameObject, "bg/btn")


    this.Scroll = Util.GetGameObject(self.gameObject, "bg/Scroll")
    this.ScrollPre = Util.GetGameObject(self.gameObject, "bg/ScrollPre")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.ScrollPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 10))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.proScroll = {}

    this.no = Util.GetGameObject(self.gameObject,"bg/no")
end

--绑定事件（用于子类重写）
function CombatPlanSelectPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btn, function()
        UIManager.OpenPanel(UIName.JumpSelectPopup, false,6000086)
    end)
end

--添加事件监听（用于子类重写）
function CombatPlanSelectPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function CombatPlanSelectPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function CombatPlanSelectPopup:OnOpen(...)
    local args = {...}
    this.curHeroData = args[1]
    this.pos = args[2]          --5 6 位
    this.openParent = args[3]
    this.oldPlanDid = args[4]   --是否是替换
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function CombatPlanSelectPopup:OnShow()
    CombatPlanSelectPopup:RefreshScroll(1)
end

function CombatPlanSelectPopup:RefreshScroll(index)
    this.no:SetActive(true)
    local data = CombatPlanManager.GetPlanByType(2)
    this.scrollView:SetData(data, function(index, root)
        this.no:SetActive(false)
        self:FillItem(root, data[index])
    end)
    if index then
        this.scrollView:SetIndex(index)
    end
end

function CombatPlanSelectPopup:FillItem(go, data)
    --icon
    local bg = Util.GetGameObject(go, "Icon"):GetComponent("Image")
    local icon = Util.GetGameObject(go, "Icon/Image"):GetComponent("Image")
    local configData = G_CombatPlanConfig[data.combatPlanId]
    local qualityId = CombatPlanManager.SetQuality(data.quality)
    local bgStr = GetQuantityImageByquality(qualityId)
    bg.sprite = Util.LoadSprite(bgStr)
    icon.sprite = Util.LoadSprite(configData.Icon)

    --pro
    if not this.proScroll[go] then
        local pro = Util.GetGameObject(go, "pro")
        local ScrollPro = Util.GetGameObject(go, "ScrollPro")
        local w = ScrollPro.transform.rect.width
        local h = ScrollPro.transform.rect.height
        this.proScroll[go] = SubUIManager.Open(SubUIConfig.ScrollCycleView, ScrollPro.transform, pro, nil,
                Vector2.New(w, h), 1, 1, Vector2.New(0, 5))
        this.proScroll[go].gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
        this.proScroll[go].gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
        this.proScroll[go].gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
        this.proScroll[go].gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
        this.proScroll[go].moveTween.MomentumAmount = 1
        this.proScroll[go].moveTween.Strength = 2
    end
    
    this.proScroll[go]:SetData(data.property, function(index, root)
        CombatPlanSelectPopup.SetRemouldPro(root, data.property[index])
    end)
    this.proScroll[go]:SetIndex(1)

    --skill
    for i = 1, 2 do
        local skillName = Util.GetGameObject(go, "SkillName" .. tostring(i))
        local skillId = data.skill[i]
        local icon = Util.GetGameObject(go, "icon" .. tostring(i))
        if skillId then
            skillName:SetActive(true)
            icon:SetActive(true)

            local passivityConfig = G_PassiveSkillConfig[skillId]
            skillName:GetComponent("Text").text =  this.SetNameColor(GetLanguageStrById(passivityConfig.Name),WarWaySkillConfig[skillId].Level)
            icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(passivityConfig.Icon))

            Util.AddOnceClick(skillName, function()
                local heroSkill = {}
                heroSkill.skillId = skillId
                heroSkill.skillConfig = passivityConfig
                UIManager.OpenPanel(UIName.SkillInfoPopup, heroSkill, 1, nil, nil, 3, nil)
            end)
        else
            skillName:SetActive(false)
            icon:SetActive(false)
        end
    end

    local BtnSelect = Util.GetGameObject(go, "BtnSelect")
    Util.AddOnceClick(BtnSelect, function()
        if this.oldPlanDid then
            --替
            CombatPlanManager.ReplacePlan(this.curHeroData.dynamicId, this.oldPlanDid, data.id, this.pos - 4, function()
                this:ClosePanel()
                this.openParent.UpdateEquipPosHeroData(3, 3, data.id, this.oldPlanDid, this.pos)
            end)
        else
            --穿
            --位置传入1 2 位
            CombatPlanManager.UpPlan(this.curHeroData.dynamicId, data.id, this.pos - 4, function()
                this:ClosePanel()
                this.openParent.UpdateEquipPosHeroData(3, 1, data.id, nil, this.pos)
            end)
        end
    end)
end

function this.SetNameColor(_name,_level)
    if _level == 1 then
        return string.format("<color=#9fff88>%s</color>",_name)
    elseif _level == 2 then
        return string.format("<color=#88e4ff>%s</color>",_name)
    elseif _level == 3 then
        return string.format("<color=#f088ff>%s</color>",_name)
    elseif _level == 4 then
        return string.format("<color=#ffba88>%s</color>",_name)
    elseif _level == 5 then
        return string.format("<color=#ff6868>%s</color>",_name)
    else
        return _name
    end
end

function CombatPlanSelectPopup.SetRemouldPro(go, data)
    local proData = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyId", data.id)
    Util.GetGameObject(go, "proName"):GetComponent("Text").text = GetLanguageStrById(proData.Info)
    local txt = Util.GetGameObject(go, "proVale"):GetComponent("Text")
    if proData.Style == 1 then               --绝对值
        txt.text = "+"..GetPropertyFormatStr(1, data.value)
    elseif proData.Style == 2 then           --百分比
        txt.text = "+"..GetPropertyFormatStr(2, data.value)
    end

    Util.GetGameObject(go, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(proData.Icon))
end

--界面关闭时调用（用于子类重写）
function CombatPlanSelectPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function CombatPlanSelectPopup:OnDestroy()
    this.proScroll = {}
end

return CombatPlanSelectPopup