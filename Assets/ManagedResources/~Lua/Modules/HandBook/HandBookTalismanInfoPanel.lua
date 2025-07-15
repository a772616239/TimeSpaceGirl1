require("Base/BasePanel")
HandBookTalismanInfoPanel = Inherit(BasePanel)
local mainProGrid = {}
local otherProGrid = {}
local curTalismanId
local GetAllTalismanIds = {}
local index
local starType = 1--1 初始星级  2  满星
local WarPower = 0
local curStar = 0
local itemConfig = {}
local talismanConFig = {}
--初始化组件（用于子类重写）
function HandBookTalismanInfoPanel:InitComponent()

    self.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    self.btnStart = Util.GetGameObject(self.transform, "btnList/btnStart")
    self.btnMaxStar = Util.GetGameObject(self.transform, "btnList/btnMaxStar")
    self.leftBtn = Util.GetGameObject(self.transform, "leftBtn/GameObject")
    self.rightBtn = Util.GetGameObject(self.transform, "rightBtn/GameObject")
    self.selectBtn = Util.GetGameObject(self.transform, "btnList/selectBtn")

    self.haveAddImage = Util.GetGameObject(self.transform, "TalismanParent/haveAddImage"):GetComponent("Image")
    self.talismanIcon = Util.GetGameObject(self.transform, "TalismanParent/haveAddImage/icon"):GetComponent("Image")
    self.talismanName = Util.GetGameObject(self.transform, "TalismanParent/haveAddImage/name/name"):GetComponent("Text")
    self.talismanStarGrid = Util.GetGameObject(self.transform, "TalismanParent/haveAddImage/star")
    self.force = Util.GetGameObject(self.transform, "powerBtn/value"):GetComponent("Text")
    for i = 1, 2 do
        mainProGrid[i] = Util.GetGameObject(self.transform, "downGo/proGrid/mainPro/pro ("..i..")")
    end
    for i = 1, 2 do
        otherProGrid[i] = Util.GetGameObject(self.transform, "downGo/proGrid/otherPro/pro ("..i..")")
    end
    self.otherProGrid = Util.GetGameObject(self.transform, "downGo/proGrid/otherPro")
    self.skillInfoText = Util.GetGameObject(self.transform, "downGo/skillInfo/Text"):GetComponent("Text")

end

--绑定事件（用于子类重写）
function HandBookTalismanInfoPanel:BindEvent()

    Util.AddClick(self.BtnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.leftBtn, function()
        self:LeftBtnOnClick()
    end)

    Util.AddClick(self.rightBtn, function()
        self:RightBtnOnClick()
    end)
    Util.AddClick(self.btnStart, function()
        starType = 1
        self:SetSelectBtn(self.btnStart, GetLanguageStrById(11097))
        self:OnShowPanelData()
    end)
    Util.AddClick(self.btnMaxStar, function()
        starType = 2
        self:SetSelectBtn(self.btnMaxStar, GetLanguageStrById(11098))
        self:OnShowPanelData()
    end)
end

--添加事件监听（用于子类重写）
function HandBookTalismanInfoPanel:AddListener()

end

--移除事件监听（用于子类重写）
function HandBookTalismanInfoPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function HandBookTalismanInfoPanel:OnOpen(_curTalismanId)

    curTalismanId = _curTalismanId
    local GetAllTalismanDatas = {}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ItemConfig)) do
        if v.ItemType==14 then
            table.insert(GetAllTalismanDatas,v)
        end
    end
    GetAllTalismanIds = {}
    table.sort(GetAllTalismanDatas, function(a,b)
        if a.Quantity == b.Quantity then
            return a.Id < b.Id
        else
           return a.Quantity > b.Quantity
        end
    end)
    for i = 1, #GetAllTalismanDatas do
        table.insert(GetAllTalismanIds,GetAllTalismanDatas[i].Id)
    end
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function HandBookTalismanInfoPanel:OnShow()

    for i = 1, #GetAllTalismanIds do
        if curTalismanId == GetAllTalismanIds[i] then
            index = i
        end
    end
    starType = 1
    self:SetSelectBtn(self.btnStart, GetLanguageStrById(11097))
    self:OnShowPanelData()
end
function HandBookTalismanInfoPanel:OnShowPanelData()
    if starType == 1 then -- 初始星级
        curStar = TalismanManager.AllTalismanStartStar[curTalismanId]
        WarPower = TalismanManager.CalculateWarForceBySid(curTalismanId,curStar,0)
        itemConfig =  ConfigManager.GetConfigData(ConfigName.ItemConfig,curTalismanId)
        talismanConFig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana, "TalismanaId", curTalismanId, "Level", curStar)
    elseif starType == 2 then -- 满星级
        curStar = TalismanManager.AllTalismanEndStar[curTalismanId]
        WarPower = TalismanManager.CalculateWarForceBySid(curTalismanId,curStar,0)
        itemConfig =  ConfigManager.GetConfigData(ConfigName.ItemConfig,curTalismanId)
        talismanConFig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.EquipTalismana, "TalismanaId", curTalismanId, "Level", curStar)
    end
    self:OnShowTalismanlData()
end
function HandBookTalismanInfoPanel:OnShowTalismanlData()
    self.force.text = WarPower
    self.talismanIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig.ResourceID))
    self.haveAddImage.sprite = Util.LoadSprite(TalismanBubble[itemConfig.Quantity])
    self.talismanName.text = GetLanguageStrById(itemConfig.Name)
    SetHeroStars(self.talismanStarGrid, curStar)

    for i = 1, #mainProGrid do
        if #talismanConFig.Property >= i then
            mainProGrid[i]:SetActive(true)
            self:ShowSingleSkillData(1, mainProGrid[i],talismanConFig.Property[i])
        else
            mainProGrid[i]:SetActive(false)
        end
    end
    self.otherProGrid:SetActive(talismanConFig.SpecialProperty and #talismanConFig.SpecialProperty > 0)
    for i = 1, #otherProGrid do
        if talismanConFig.SpecialProperty and #talismanConFig.SpecialProperty >= i then
            otherProGrid[i]:SetActive(true)
            self:ShowSingleSkillData(2, otherProGrid[i],talismanConFig.SpecialProperty[i])
        else
            otherProGrid[i]:SetActive(false)
        end
    end
    local cfg = ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, talismanConFig.OpenSkillRules[1])
    self.skillInfoText.text = GetSkillConfigDesc(cfg)
end
function HandBookTalismanInfoPanel:ShowSingleSkillData(_type,_go,_curData,_nextData)
    if _type == 1 then--1  主属性
        local proConFig = ConfigManager.GetConfigData(ConfigName.PropertyConfig,_curData[1])
        Util.GetGameObject(_go.transform, "proName"):GetComponent("Text").text = proConFig.Info
        Util.GetGameObject(_go.transform, "proValue"):GetComponent("Text").text = GetEquipPropertyFormatStr(proConFig.Style,_curData[2])
        --Util.GetGameObject(_go.transform, "nextProValue"):GetComponent("Text").text = GetEquipPropertyFormatStr(proConFig.Style,_nextData[2])
    elseif _type == 2 then--1  副属性
        local proConFig = ConfigManager.GetConfigData(ConfigName.PropertyConfig,_curData[2])
        Util.GetGameObject(_go.transform, "proName"):GetComponent("Text").text = proConFig.Info.."("..HeroOccupationDef[_curData[1]].."):"
        Util.GetGameObject(_go.transform, "proValue"):GetComponent("Text").text = GetEquipPropertyFormatStr(proConFig.Style,_curData[3])
        --Util.GetGameObject(_go.transform, "nextProValue"):GetComponent("Text").text = GetEquipPropertyFormatStr(proConFig.Style,_nextData[3])
    end
end
--右切换按钮点击
function HandBookTalismanInfoPanel:RightBtnOnClick()
    index = (index + 1 <= #GetAllTalismanIds and index + 1 or 1)
    curTalismanId = GetAllTalismanIds[index]
    self:OnShowPanelData()
end
--左切换按钮点击
function HandBookTalismanInfoPanel:LeftBtnOnClick()
    index = (index - 1 > 0 and index - 1 or #GetAllTalismanIds)
    curTalismanId = GetAllTalismanIds[index]
    self:OnShowPanelData()
end
--页签选中效果设置
function HandBookTalismanInfoPanel:SetSelectBtn(_btn, btnText)
    self.selectBtn.transform:SetParent(_btn.transform)
    self.selectBtn.transform.localScale = Vector3.one
    self.selectBtn.transform.localPosition=Vector3.zero
    Util.GetGameObject(self.selectBtn.transform, "Text"):GetComponent("Text").text = btnText
end
function HandBookTalismanInfoPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function HandBookTalismanInfoPanel:OnDestroy()

end

return HandBookTalismanInfoPanel