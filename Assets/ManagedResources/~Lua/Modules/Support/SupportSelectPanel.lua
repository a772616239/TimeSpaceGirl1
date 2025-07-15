require("Base/BasePanel")
SupportSelectPanel = Inherit(BasePanel)
local this = SupportSelectPanel

local artifactConfig = ConfigManager.GetConfig(ConfigName.ArtifactConfig)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
--初始化组件（用于子类重写）
function SupportSelectPanel:InitComponent()
    this.scrollRoot = Util.GetGameObject(this.gameObject, "Scroll")
    this.ItemPre = Util.GetGameObject(this.gameObject, "Scroll/ItemPre")
    this.BackBtn = Util.GetGameObject(this.gameObject, "Bg/BackBtn")
    this.BackMask = Util.GetGameObject(this.gameObject, "BackMask")

    local w = this.scrollRoot.transform.rect.width
    local h = this.scrollRoot.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform, this.ItemPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 10))
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    -- this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function SupportSelectPanel:BindEvent()
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function SupportSelectPanel:AddListener()
    
end

--移除事件监听（用于子类重写）
function SupportSelectPanel:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function SupportSelectPanel:OnOpen(...)
    local args = {...}
    this.teamId = args[1]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SupportSelectPanel:OnShow()
    self.supportId = SupportManager.GetFormationSupportId(this.teamId)
    local data = SupportManager.GetSelectData()
    -- local data = {1, 2, 3, 4, 5, 6, 7}
    this.scrollView:SetData(data, function(index, root)
        this:SetUIWithData(root, data[index])
    end)
    this.scrollView:SetIndex(1)
end

function SupportSelectPanel:SetUIWithData(go, data)
    local artifactData = artifactConfig[data.supportId]
    local Btn = Util.GetGameObject(go, "Btn")
    local BtnTxt = Util.GetGameObject(go, "Btn/Txt"):GetComponent("Text")
    local icon = Util.GetGameObject(go, "icon")
    icon:GetComponent("Image").sprite = Util.LoadSprite(artifactData.Head)
    local lv
    if SupportManager.GetSupportDatas().level > 1 then
        lv = "+" .. SupportManager.GetSupportDatas().level - 1
    else
        lv = ""
    end
    Util.GetGameObject(go, "name"):GetComponent("Text").text = GetLanguageStrById(artifactData.Name) .. lv

    local artifactSkillLv = 1
    if data.openStatus ~= 0 then
        artifactSkillLv = SupportManager.GetDataById(data.supportId).skillLevel
    end
    local configData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.ArtifactSkillConfig, "ArtifactId", data.supportId, "SkillLevel", artifactSkillLv)
    local skillData = skillConfig[configData.SkillId]
    local desc = GetSkillConfigDesc(skillData)

    Util.GetGameObject(go,"skill"):GetComponent("Text").text = GetLanguageStrById(skillData.Name) .. "  Lv" .. artifactSkillLv
    Util.GetGameObject(go, "skill/skillDesc"):GetComponent("Text").text = desc

    Util.SetGray(icon, data.openStatus == 0)

    if data.openStatus == 0 then
        --未激活
        BtnTxt.text = GetLanguageStrById(22298)
        Btn:GetComponent("Button").enabled = false
        Util.SetGray(icon, true)
        Util.SetGray(Btn, true)
    else
        --激活
        Btn:GetComponent("Button").enabled = true
        Util.SetGray(icon, false)
        Util.SetGray(Btn, false)

        if self.supportId == data.supportId then --已装备
            BtnTxt.text = GetLanguageStrById(22297)

            Util.AddOnceClick(Btn, function()
                SupportManager.SetFormationSupportId(this.teamId, 0)
                Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnSupportChange)
                self:ClosePanel()
            end)
        else
            BtnTxt.text = GetLanguageStrById(22296)

            Util.AddOnceClick(Btn, function()
                SupportManager.SetFormationSupportId(this.teamId, data.supportId)
                Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnSupportChange)
                self:ClosePanel()
            end)
        end
    end

end

--界面关闭时调用（用于子类重写）
function SupportSelectPanel:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function SupportSelectPanel:OnDestroy()

end

return SupportSelectPanel