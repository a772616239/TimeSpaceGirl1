require("Base/BasePanel")
FormationBuffPopup = Inherit(BasePanel)
local this = FormationBuffPopup

local FormationBuffConfig = ConfigManager.GetConfig(ConfigName.FormationBuffConfig)


local countryPic = {"cn2-X1_tongyong_zhenying_04",
                    "cn2-X1_tongyong_zhenying_02",
                    "cn2-X1_tongyong_zhenying_03",
                    "cn2-X1_tongyong_zhenying_06",
                    "cn2-X1_tongyong_zhenying_05",
                    GetPictureFont("cn2-X1_tongyong_zhenying_01"),}

--初始化组件（用于子类重写）
function FormationBuffPopup:InitComponent()
    this.maskImage = Util.GetGameObject(this.gameObject, "maskImage")
	this.btnback = Util.GetGameObject(this.gameObject, "btnback")


    
    -- this.effectPre = Util.GetGameObject(this.gameObject, "Bg/ScrollView/effectPre")
    this.effectGroupPre = Util.GetGameObject(this.gameObject, "Bg/ScrollView/effectGroupPre")
    this.Scroll = Util.GetGameObject(this.gameObject, "Bg/ScrollView/scroll")
    local w = this.Scroll.transform.rect.width
    local h = this.Scroll.transform.rect.height
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.Scroll.transform, this.effectGroupPre, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(5, -5), 1)
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function FormationBuffPopup:BindEvent()
    Util.AddClick(this.maskImage, function()
        this:ClosePanel()
    end)
	Util.AddClick(this.btnback, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function FormationBuffPopup:AddListener()
    
end

--移除事件监听（用于子类重写）
function FormationBuffPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function FormationBuffPopup:OnOpen(...)
    local args = {...}
    self.choosedList = args[1]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FormationBuffPopup:OnShow()
    -- local proBase = {1,2,3,4,5,6,7,8,9,10}

    -- local formationList = FormationManager.GetFormationByID(self.curTeamId)
    local elementIds = TeamInfosToElementIds(this.choosedList)
    local allElementData = FormationManager.GetOpenElement(elementIds)
    

    table.sort(allElementData, function(a, b)
        local isA = false
        local isB = false
        for i = 1, #a do
            if a[i].isOpen then
                isA = true
                break
            end
        end
        for i = 1, #b do
            if b[i].isOpen then
                isB = true
                break
            end
        end
        if (not isA and not isB) or (isA and isB) then
            return false
        else
            if isA and not isB then
                return true
            elseif not isA and isB then
                return false
            end
        end
        LogError("### allElementData error")
        return false
    end)
    
    this.scrollView:SetData(allElementData, function(index, root)
        self:SetUI(root, allElementData[index])
    end)
    this.scrollView:SetIndex(1)
end

function FormationBuffPopup:SetUI(go, data)
    local BuffSign = Util.GetGameObject(go, "BuffSign")
    local activated = Util.GetGameObject(go, "activated")
    local BuffTitle = Util.GetGameObject(go, "BuffTitle")
    local effectList = Util.GetGameObject(go, "effectList")

    local isModeOpen = false
    for i = 1, 6 do
        local fontGo = Util.GetGameObject(effectList, "effectPre" .. tostring(i))
        if data[i] then
            fontGo:SetActive(true)
            local desc = GetSkillConfigDesc(data[i].configData, not data[i].isOpen, 1)
            fontGo:GetComponent("Text").text = desc
            if data[i].isOpen then
                isModeOpen = true

                Util.SetGray(fontGo, false)
                fontGo:GetComponent("Text").color = Color.New(255/255, 209/255, 43/255, 1)
            else
                Util.SetGray(fontGo, true)
                fontGo:GetComponent("Text").color = Color.New(255/255, 255/255, 255/255, 1)
            end
        else
            fontGo:SetActive(false)
        end
    end

    if data[1] then
        BuffTitle:GetComponent("Text").text = GetLanguageStrById(data[1].configData.Name)
        BuffSign:GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(countryPic[data[1].configData.Type]))
    end
    
    if isModeOpen then
        activated:SetActive(true)
        Util.SetGray(BuffTitle, false)
        Util.SetGray(BuffSign, false)
    else
        activated:SetActive(false)
        Util.SetGray(BuffTitle, true)
        Util.SetGray(BuffSign, false)
    end
end

--界面关闭时调用（用于子类重写）
function FormationBuffPopup:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function FormationBuffPopup:OnDestroy()

end

return FormationBuffPopup