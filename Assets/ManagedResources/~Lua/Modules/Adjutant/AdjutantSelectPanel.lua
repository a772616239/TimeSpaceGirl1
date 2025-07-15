require("Base/BasePanel")
AdjutantSelectPanel = Inherit(BasePanel)
local this = AdjutantSelectPanel

local adjutantConfig = ConfigManager.GetConfig(ConfigName.AdjutantConfig)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)

--初始化组件（用于子类重写）
function AdjutantSelectPanel:InitComponent()
    this.scrollRoot = Util.GetGameObject(this.gameObject, "Scroll")
    this.ItemPre = Util.GetGameObject(this.gameObject, "Scroll/ItemPre")
    this.BackBtn = Util.GetGameObject(this.gameObject, "Bg/BackBtn")
    this.BackMask = Util.GetGameObject(this.gameObject, "BackMask")

    local w = this.scrollRoot.transform.rect.width
    local h = this.scrollRoot.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform, this.ItemPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 10))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function AdjutantSelectPanel:BindEvent()
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function AdjutantSelectPanel:AddListener()
end

--移除事件监听（用于子类重写）
function AdjutantSelectPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function AdjutantSelectPanel:OnOpen(...)
    local args = {...}
    this.teamId = args[1]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AdjutantSelectPanel:OnShow()
    NetManager.GetAllAdjutantInfo(function ()
        self.adjutantId = AdjutantManager.GetFormationAdjutantId(this.teamId)
        local data = AdjutantManager.GetConfigAdjutants()
        this.openStatus = {}
        for i, v in ipairs(data) do
            local isOpen = false
            for j, w in ipairs(AdjutantManager.GetAdjutantData().adjutants) do
                if w.id == v.AdjutantId then
                    isOpen = true
                end
            end
             table.insert(this.openStatus, isOpen)
        end
        -- local data = {1, 2, 3, 4, 5, 6, 7}
        this.scrollView:SetData(data, function(index, root)
            this:SetUIWithData(root, data[index], index)
        end)
        this.scrollView:SetIndex(1)
    end)
end

function AdjutantSelectPanel:SetUIWithData(go, data, index)
    local Btn = Util.GetGameObject(go, "Btn")
    local BtnTxt = Util.GetGameObject(go, "Btn/Txt"):GetComponent("Text")
    local head = Util.GetGameObject(go, "Image_Icon"):GetComponent("Image")
    local name = Util.GetGameObject(go, "Text_Title"):GetComponent("Text")
    local desc = Util.GetGameObject(go, "Text_Desc"):GetComponent("Text")
    head.sprite = Util.LoadSprite(data.Head)
    name.text = GetLanguageStrById(data.Name)

    Util.SetGray(head.gameObject, not this.openStatus[index])
    local lv = 1
    local alldata = AdjutantManager.GetAdjutantData().adjutants
    for i = 1, #alldata do
        if alldata[i].id == data.AdjutantId then
            lv = alldata[i].skillLevel
        end
    end
    local skillData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantSkillConfig, "AdjutantId", data.AdjutantId, "SkillLvl", lv)
    desc.text = GetSkillConfigDesc(skillConfig[skillData.Skill_Id])

    if not this.openStatus[index] then
        --未激活
        BtnTxt.text = GetLanguageStrById(22298)
        Btn:GetComponent("Button").enabled = false
        Util.SetGray(head.gameObject, true)
        Util.SetGray(Btn, true)
        Btn:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_anniu_bai")
    else
        --激活
        Btn:GetComponent("Button").enabled = true
        Util.SetGray(head.gameObject, false)
        Util.SetGray(Btn, false)
        
        if self.adjutantId == data.AdjutantId then --已装备
            BtnTxt.text = GetLanguageStrById(22297)
            Btn:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_anniu_bai")

            Util.AddOnceClick(Btn, function()
                AdjutantManager.SetFormationAdjutantId(this.teamId, 0)
                Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnAdjutantChange)
                self:ClosePanel()
            end)
        else
            BtnTxt.text = GetLanguageStrById(22296)
            Btn:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_anniu_bai")

            Util.AddOnceClick(Btn, function()
                AdjutantManager.SetFormationAdjutantId(this.teamId, data.AdjutantId)
                Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnAdjutantChange)
                self:ClosePanel()
            end)
        end
    end
end

--界面关闭时调用（用于子类重写）
function AdjutantSelectPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function AdjutantSelectPanel:OnDestroy()
end

return AdjutantSelectPanel