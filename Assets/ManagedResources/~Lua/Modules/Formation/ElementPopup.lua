require("Base/BasePanel")
ElementPopup = Inherit(BasePanel)
local this = ElementPopup
local activeColor = "#FFD376FF"
local normalColor = "#C7B081FF"
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local elementalResonanceConfig = ConfigManager.GetConfig(ConfigName.ElementalResonanceConfig)

local openInBattle = false

function ElementPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "maskImage")
    this.title = Util.GetGameObject(self.gameObject, "bgImage/title/Text"):GetComponent("Text")
    this.descList = {}
    this.propList = {}
    this.activeBgList = {}
    this.ativeLightList = {}
    for i = 1, 6 do
        local panel = Util.GetGameObject(self.gameObject, "bgImage/elemental" .. i)
        this.propList[i] = {}
        this.propList[i] = {
                            [1] = Util.GetGameObject(panel, "panel/prop1"),
                            [2] = Util.GetGameObject(panel, "panel/prop2"),
                            [3]=Util.GetGameObject(panel,"panel/prop3")
                        }

        this.activeBgList[i] = Util.GetGameObject(panel, "bg")
        this.ativeLightList[i] = Util.GetGameObject(panel, "light")

        this.descList[i] = Util.GetGameObject(panel, "Text"):GetComponent("Text")
    end
end

function ElementPopup:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
end

function ElementPopup:OnSortingOrderChange()
end

function ElementPopup:AddListener()
end

function ElementPopup:RemoveListener()
end

function ElementPopup:OnOpen(data, lastOrder)
    openInBattle = false
    -- 设置4个
    this.SetNormal(data)
    -- 设置层级
    this.SheTaMaCengJi(lastOrder)
end
function ElementPopup:OnClose()
    if openInBattle then
        ElementPopup.transform:GetComponent("Canvas").sortingOrder = self.sortingOrder - 211
    end

    openInBattle = false
end

function ElementPopup:OnDestroy()
end




function this.SetNormal(data)
    this.title.text = data.title
   -- 设置属性文字
    for i = 1, 6 do
        local strColor = i == data.activeIndex and activeColor or normalColor
        for j = 1, #elementalResonanceConfig[i].Content do
            local strBeforeP =  propertyConfig[elementalResonanceConfig[i].Content[j][1]].Info
            local strBehindP =  elementalResonanceConfig[i].Content[j][2] / 100 .. "%"
            local prop2Str = strBeforeP .. "+" .. strBehindP
            this.propList[i][j]:SetActive(true)
            this.propList[i][j]:GetComponent("Text").text = string.format("<color=%s>%s</color>", strColor, prop2Str)
        end
    end

    -- 设置高亮
    for j = 1, 6 do
        local isActive = j == data.activeIndex
        if isActive then
            local colorStr = string.gsub(elementalResonanceConfig[j].String, GetLanguageStrById(10664), string.format(GetLanguageStrById(10665), activeColor))
            local replaceText = j < 3 and GetLanguageStrById(10666) or (j + 1) .. GetLanguageStrById(10667)
            this.descList[j].text = string.gsub(colorStr, replaceText, string.format("<color=%s>%s</color>", activeColor, replaceText))
        else
            this.descList[j].text = GetLanguageStrById(elementalResonanceConfig[j].String)
        end

        this.activeBgList[j]:SetActive(isActive)
        this.ativeLightList[j]:SetActive(isActive)
    end
end

function this.SheTaMaCengJi(lastOrder)
    
    -- 主要是战斗中的飘字
    if UIManager.IsOpen(UIName.BattlePanel) then
        openInBattle = true
        ElementPopup.transform:GetComponent("Canvas").sortingOrder = lastOrder + 211
    end
end

return ElementPopup