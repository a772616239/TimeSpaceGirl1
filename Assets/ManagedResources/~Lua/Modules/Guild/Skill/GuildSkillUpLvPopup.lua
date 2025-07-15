require("Base/BasePanel")
GuildSkillUpLvPopup = Inherit(BasePanel)
local this = GuildSkillUpLvPopup
local TabBox = require("Modules/Common/TabBox")
local _TabData = { [1] = { default = "", select = "", name = GuildSkillType[1] },
                 [2] = { default = "", select = "", name = GuildSkillType[2] },
                 [3] = { default = "", select = "", name = GuildSkillType[3] },
                 [4] = { default = "", select = "", name = GuildSkillType[4]},
}
-- local _TabFontColor = { default = Color.New(160 / 255, 160 / 255, 160 / 255, 1),
--                         select = Color.New(224 / 255, 224 / 255, 161 / 255, 1)}
local skills = {}
local pros = {}
local materals = {}
local curIndex = 1
local curSeletSkill = {}
local allSkillData = {}
local materialNoId = 0
local endLv = 0
local isMaxLv = true
local proInfo = {
    [61] = GetLanguageStrById(11079),
    [62] = GetLanguageStrById(11080),
    [51] = GetLanguageStrById(11081),
    [52] = GetLanguageStrById(11082),
    [55] = GetLanguageStrById(11083),
    [56] = GetLanguageStrById(11084),
}
local tabRedPotList = {}
local effectList = {}
local sortingOrder
-- local oldWarPowerValue = 0
-- local newWarPowerValue = 0
--初始化组件（用于子类重写）
function GuildSkillUpLvPopup:InitComponent()
    this.tabBox = Util.GetGameObject(self.gameObject, "bg/TabBox")
    this.backBtn = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.btnUpLv = Util.GetGameObject(self.gameObject, "bg/btnUpLv")
    this.btnRest = Util.GetGameObject(self.gameObject, "bg/btnRest")
    this.helpBtn = Util.GetGameObject(self.gameObject,"bg/title/HelpBtn")
    this.helpPos = this.helpBtn:GetComponent("RectTransform").localPosition
    -- this.titleText = Util.GetGameObject(self.gameObject,"bg/titleText"):GetComponent("Text")
    this.skillAllLv = Util.GetGameObject(self.gameObject,"bg/title/skillAllLv"):GetComponent("Text")
    this.selectImage = Util.GetGameObject(self.gameObject,"bg/skills/selectImage")
    this.CurentPro = Util.GetGameObject(self.gameObject, "bg/skills/CurentPro"):GetComponent("Text")
    this.CurentProValue = Util.GetGameObject(self.gameObject, "bg/skills/CurentPro/value"):GetComponent("Text")
    this.effect = Util.GetGameObject(self.gameObject,"bg/skills/UI_effect_Guaid_BaoDian")

    for i = 1, 6 do
        skills[i] = Util.GetGameObject(self.gameObject,"bg/skills/frame"..i)
        pros[i] = Util.GetGameObject(self.gameObject,"bg/proScroll/grid/proVale" .. i)

        effectList[i] = newObject(this.effect)
        effectList[i].transform:SetParent(skills[i].transform)
        effectList[i].transform.localScale = Vector3.one
        effectList[i].transform.localPosition = Vector3.zero
        effectList[i]:SetActive(true)
        Util.GetGameObject(effectList[i], "partical_click2"):GetComponent("ParticleSystem"):Stop()
    end
    this.materialGrid = Util.GetGameObject(self.gameObject,"bg/materialGrid")
    for i = 1, 2 do
        materals[i] = Util.GetGameObject(self.gameObject,"bg/materialGrid/needGoldText"..i)
    end
    this.TabCtrl = TabBox.New()
end

--绑定事件（用于子类重写）
function GuildSkillUpLvPopup:BindEvent()
    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.GuildSkill,this.helpPos.x - 180 ,this.helpPos.y + 700)
    end)
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnUpLv,function()
        if materialNoId > 0  then
            PopupTipPanel.ShowTip(GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,materialNoId).Name)..GetLanguageStrById(11085))
            return
        end
        local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
        NetManager.SinGleGuildSkillUpLv(curIndex,function(msg)
            CheckRedPointStatus(RedPointType.Guild_Skill)
            PopupTipPanel.ShowTipByLanguageId(11086)
            Util.GetGameObject(effectList[curSeletSkill.id], "partical_click2"):GetComponent("ParticleSystem"):Play()
            GuildSkillManager.SetSkillDataLv(curIndex,curSeletSkill.id,curSeletSkill.level + 1)
            this.OnClickTabBtn(curIndex)
            this.RefreshTabRedPoint()
            -- newWarPowerValue = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            -- if oldWarPowerValue ~= newWarPowerValue then
            --     UIManager.OpenPanel(UIName.WarPowerChangeNotifyPanelV2,{oldValue = oldWarPowerValue,newValue = newWarPowerValue})
            --     Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnChangeName)
            --     oldWarPowerValue = newWarPowerValue
            -- end

            FormationManager.FlutterPower(oldPower)
            Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnChangeName)
        end)
    end)
    Util.AddClick(this.btnRest,function()
        if endLv <= 0 then
            PopupTipPanel.ShowTipByLanguageId(11087)
            return
        end

        local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.GuildSkill,
            GuildSkillManager.GetResetGetDrop(curIndex),curIndex,function()
                CheckRedPointStatus(RedPointType.Guild_Skill)
                GuildSkillManager.ResetGuildSkillData(curIndex)
                this.OnClickTabBtn(curIndex)
                this.RefreshTabRedPoint()

                local newPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
                if oldPower ~= newPower then
                    UIManager.OpenPanel(UIName.WarPowerChangeNotifyPanelV2,{oldValue = oldPower, newValue = newPower})
                end
                Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnChangeName)
        end)
    end)
end
--添加事件监听（用于子类重写）
function GuildSkillUpLvPopup:AddListener()
end

--移除事件监听（用于子类重写）
function GuildSkillUpLvPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GuildSkillUpLvPopup:OnOpen(_curIndex)
    curIndex = _curIndex or 1
    tabRedPotList = {}
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildSkillUpLvPopup:OnShow()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData, curIndex)
    -- oldWarPowerValue = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)

    for i = 1, #effectList do
        Util.GetGameObject(effectList[i], "partical_click2"):GetComponent("ParticleSystem"):Stop()
    end
end

function GuildSkillUpLvPopup:OnSortingOrderChange()
    sortingOrder = self.sortingOrder
    for index, value in ipairs(effectList) do
        value:GetComponent("SortingGroup").sortingOrder = sortingOrder + 10
    end
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local default = Util.GetGameObject(tab,"default")
    local select = Util.GetGameObject(tab,"select")

    Util.GetGameObject(default,"Text"):GetComponent("Text").text = _TabData[index].name
    Util.GetGameObject(select,"Text"):GetComponent("Text").text = _TabData[index].name

    default:SetActive(status == "default")
    select:SetActive(status == "select")

    Util.GetGameObject(tab, "RedPoint"):SetActive(GuildSkillManager.GuildSkillRedPoint(index))
    if #tabRedPotList < 4 then
        table.insert(tabRedPotList, Util.GetGameObject(tab, "RedPoint"))
    end
end

--切换视图
function this.SwitchView(index)
    this.OnClickTabBtn(index)
end

function this.OnClickTabBtn(index)
    --数据组拼
    curIndex = index
    GuildSkillManager.SetGuildSkillRedPlayers(curIndex,1)
    CheckRedPointStatus(RedPointType.Guild_Skill)
    isMaxLv = true
    allSkillData = GuildSkillManager.GetSkillDataByType(curIndex)
    curSeletSkill = allSkillData[1]
    for i = 1, #allSkillData do
        if curSeletSkill.level > allSkillData[i].level then
            curSeletSkill = allSkillData[i]
            isMaxLv = false
        end
    end
    local allCurSkillConfig = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.GuildTechnology,"Profession",curIndex,"TechId",curSeletSkill.id)
    if isMaxLv and curSeletSkill.level ~= #allCurSkillConfig - 1 then
        isMaxLv = false
    end
    this.ShowSkillsAndPros()--展示技能 展示属性
    this.ShowMaterials()--展示消耗材料 及 按钮状态
end
--展示技能
function this.ShowSkillsAndPros()
    -- this.titleText.text = GetLanguageStrById(11088).._TabData[curIndex].name
    local isEqualityLv,maxLv
    endLv,isEqualityLv,maxLv = GuildSkillManager.GetAllGuildSkillLv(curIndex)
    Util.SetGray(this.btnRest, endLv <= 0)
    this.materialGrid:SetActive(not isMaxLv)
    this.selectImage:SetActive(not isMaxLv)
    if isMaxLv then
        this.btnUpLv:GetComponent("Button").enabled = false
        Util.GetGameObject(this.btnUpLv,"Text"):GetComponent("Text").text = GetLanguageStrById(11089)
    else
        this.btnUpLv:GetComponent("Button").enabled = true
        Util.GetGameObject(this.btnUpLv,"Text"):GetComponent("Text").text = GetLanguageStrById(11090)
    end
    this.skillAllLv.text = GetLanguageStrById(11091).."<color=#FFD12B><size=46>"..endLv.."</size></color>"
        for i = 1, #allSkillData do
        local skillGo = skills[i]
        if skillGo then
            Util.GetGameObject(skillGo,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(allSkillData[i].config.Icon))
            Util.GetGameObject(skillGo,"lv"):GetComponent("Text").text = allSkillData[i].level
            if isEqualityLv then
                Util.SetGray(skillGo, true)
            elseif allSkillData[i].level > 0 and allSkillData[i].level >= maxLv then
                Util.SetGray(skillGo, false)
            else
                --if curSeletSkill.id == allSkillData[i].id then
                --    Util.SetGray(skillGo, false)
                --else
                Util.SetGray(skillGo, true)
                --end
            end
            end
        local proGo = pros[i]
        if proGo then
            local propertyConfig = ConfigManager.GetConfigData(ConfigName.PropertyConfig, allSkillData[i].config.Values[1])
            local proInfoStr = GetLanguageStrById(propertyConfig.Info)
            if proInfo[propertyConfig.PropertyId] then
                proInfoStr = proInfo[propertyConfig.PropertyId]
            end
            if curSeletSkill.id == allSkillData[i].id then
                local config = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.GuildTechnology,"Profession",curIndex,"TechId",curSeletSkill.id,"Level",curSeletSkill.level + 1)
               local addValue = ""
                if config then
                    addValue =  "+"..GetPropertyFormatStrOne(propertyConfig.Style, config.Values[2] - allSkillData[i].config.Values[2])
                end
                this.CurentPro.text = proInfoStr
                this.CurentProValue.text = addValue
                -- proGo:GetComponent("Text").text = proInfoStr.. "：" .. "\t\t" .. GetPropertyFormatStrOne(propertyConfig.Style, allSkillData[i].config.Values[2]) ..addValue
            -- else
            --     proGo:GetComponent("Text").text = proInfoStr.. "：" .. "\t\t" .. GetPropertyFormatStrOne(propertyConfig.Style, allSkillData[i].config.Values[2])
            end
            Util.GetGameObject(proGo,"name"):GetComponent("Text").text = proInfoStr
            Util.GetGameObject(proGo,"icon"):GetComponent("Image").sprite = Util.LoadSprite(propertyConfig.Icon)
            Util.GetGameObject(proGo,"value"):GetComponent("Text").text = "+"..GetPropertyFormatStrOne(propertyConfig.Style, allSkillData[i].config.Values[2])
        end
    end
end
--展示消耗材料 及 按钮状态
function this.ShowMaterials()
    materialNoId = 0
    this.selectImage.transform:SetParent(Util.GetGameObject(skills[curSeletSkill.id],"selectImageParent").transform)
    this.selectImage.transform.localScale = Vector3.one
    this.selectImage.transform.localPosition = Vector3.zero
    for i = 1, #materals do
        if curSeletSkill.config.Consume then
            if curSeletSkill.config.Consume[i] then
                local consume = curSeletSkill.config.Consume[i]
                local materalGo = materals[i]
                Util.GetGameObject(materalGo,"Image"):GetComponent("Image").sprite =
                Util.LoadSprite(GetResourcePath(ConfigManager.TryGetConfigData(ConfigName.ItemConfig,consume[1]).ResourceID))
                Util.GetGameObject(materalGo,"frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(ConfigManager.TryGetConfigData(ConfigName.ItemConfig,consume[1]).Quantity))
                Util.GetGameObject(materalGo,"Cost"):GetComponent("Text").text = PrintWanNum3(consume[2])
                if BagManager.GetItemCountById(consume[1]) >= consume[2] then
                    -- Util.GetGameObject(materalGo,"Cost"):GetComponent("Text").text ="<color=#FCEBCA>".. consume[2].."</color>"
                else
                    -- Util.GetGameObject(materalGo,"Cost"):GetComponent("Text").text ="<color=#C66366>".. consume[2].."</color>"
                    if materialNoId == 0 then
                        materialNoId = consume[1]
                    end
                end
                local bagNum = BagManager.GetItemCountById(consume[1])
                Util.GetGameObject(materalGo,"Cost"):GetComponent("Text").text = GetNumUnenoughColor(bagNum, consume[2], PrintWanNum2(bagNum), PrintWanNum2(consume[2]))
                Util.AddOnceClick(Util.GetGameObject(materalGo,"frame"),function ()
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,consume[1])
                end)
            else
                materals[i]:SetActive(false)
            end
        end
    end
end
function this.RefreshTabRedPoint()
    for i = 1, #tabRedPotList do
        tabRedPotList[i]:SetActive(GuildSkillManager.GuildSkillRedPoint(i))
    end
end
--界面关闭时调用（用于子类重写）
function GuildSkillUpLvPopup:OnClose()
    tabRedPotList = {}
end

--界面销毁时调用（用于子类重写）
function GuildSkillUpLvPopup:OnDestroy()
end

return GuildSkillUpLvPopup