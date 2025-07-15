require("Base/BasePanel")
RoleTalentPopup = Inherit(BasePanel)
local heroConfig,breakId,upStarId
local breakSkillDataList = {}
local upStarSkillDataList = {}
local passiveSkillLogicConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local passiveSkillConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local heroRankupConfig=ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
--初始化组件（用于子类重写）
function RoleTalentPopup:InitComponent()
    self.breakSkillGoList = {}
    self.upStarSkillGoList = {}
    self.BackMask = Util.GetGameObject(self.transform, "BackMask")
    self.breakOpenSkill =Util.GetGameObject(self.transform, "bg/breakOpenSkill")
    self.upStarOpenSkill =Util.GetGameObject(self.transform, "bg/upStarOpenSkill")
    self.breakSkillTextPre =Util.GetGameObject(self.transform, "bg/breakSkillTextPre")
    self.breakOpenSkillGrid =Util.GetGameObject(self.transform, "bg/breakOpenSkill/Mask")
    self.upStarSkillTextPre =Util.GetGameObject(self.transform, "bg/upStarSkillTextPre")
    self.upStarOpenSkill =Util.GetGameObject(self.transform, "bg/upStarOpenSkill/Mask")
end

--绑定事件（用于子类重写）
function RoleTalentPopup:BindEvent()
    Util.AddClick(self.BackMask, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function RoleTalentPopup:AddListener()
end

--移除事件监听（用于子类重写）
function RoleTalentPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
--传三个参数 是因为图鉴也要用
function RoleTalentPopup:OnOpen(_heroConfig,_breakId,_upStarId)
    heroConfig = _heroConfig
    breakId = _breakId
    upStarId = _upStarId
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RoleTalentPopup:OnShow()
    self:GetTalentDataShow()
end
function RoleTalentPopup:GetTalentDataShow()
    breakSkillDataList = {}
    upStarSkillDataList = {}
    if heroConfig.OpenPassiveSkillRules then
        for i = 1, #heroConfig.OpenPassiveSkillRules do
            
            if heroConfig.OpenPassiveSkillRules[i][1] == 1 then--突破
                local singSkillData = {}
                singSkillData.passiveSkillConfig = passiveSkillConfig[heroConfig.OpenPassiveSkillRules[i][3]]
                singSkillData.OpenPassiveSkillRules = heroConfig.OpenPassiveSkillRules[i]
                local titleStr  = NumToSimplenessFont[heroRankupConfig[heroConfig.OpenPassiveSkillRules[i][2]].Phase[2]] .. GetLanguageStrById(11864)
                local curBreakId = heroConfig.OpenPassiveSkillRules[i][2]
                if breakId >= curBreakId then
                    if breakSkillDataList[curBreakId] then
                        breakSkillDataList[curBreakId] = {index = curBreakId,str =  breakSkillDataList[curBreakId].str .. "　  <color=#66FF00>"..passiveSkillConfig[heroConfig.OpenPassiveSkillRules[i][3]].Desc.."</color>"}
                    else
                        breakSkillDataList[curBreakId] =  {index = curBreakId,str ="<color=#66FF00>"..titleStr..passiveSkillConfig[heroConfig.OpenPassiveSkillRules[i][3]].Desc.."</color>"}
                    end
                else
                    if breakSkillDataList[curBreakId] then
                        breakSkillDataList[curBreakId] = {index = curBreakId,str =breakSkillDataList[curBreakId].str .. "　<color=#B9AC97>"..passiveSkillConfig[heroConfig.OpenPassiveSkillRules[i][3]].Desc.."</color>"}
                    else
                        breakSkillDataList[curBreakId] =  {index = curBreakId,str ="<color=#B9AC97>"..titleStr..passiveSkillConfig[heroConfig.OpenPassiveSkillRules[i][3]].Desc.."</color>"}
                    end
                end
            else--升星
                local singSkillData = {}
                singSkillData.passiveSkillConfig = passiveSkillConfig[heroConfig.OpenPassiveSkillRules[i][3]]
                singSkillData.OpenPassiveSkillRules = heroConfig.OpenPassiveSkillRules[i]
                singSkillData.titleStr  = NumToSimplenessFont[heroRankupConfig[heroConfig.OpenPassiveSkillRules[i][2]].Phase[2]] .. GetLanguageStrById(11865)
                if upStarId >= heroConfig.OpenPassiveSkillRules[i][2] then
                    singSkillData.isOpen = true
                else
                    singSkillData.isOpen = false
                end
                table.insert(upStarSkillDataList,singSkillData)
            end
        end
    end
    local breakSkillDataList2 = {}
    for i, v in pairs(breakSkillDataList) do
        table.insert(breakSkillDataList2,v)
    end
    table.sort(breakSkillDataList2, function(a,b) return a.index<b.index end)
    for i = 1, math.max(#breakSkillDataList2, #self.breakSkillGoList) do
        local go = self.breakSkillGoList[i]
        if not go then
            go = newObject(self.breakSkillTextPre)
            go.transform:SetParent(self.breakOpenSkillGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            self.breakSkillGoList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #breakSkillDataList2 do
        local go = self.breakSkillGoList[i]
        go.gameObject:SetActive(true)
        go:GetComponent("Text").text = breakSkillDataList2[i].str
    end

    for i = 1, math.max(#upStarSkillDataList, #self.upStarSkillGoList) do
        local go = self.upStarSkillGoList[i]
        if not go then
            go = newObject(self.upStarSkillTextPre)
            go.transform:SetParent(self.upStarOpenSkill.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            self.upStarSkillGoList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #upStarSkillDataList do
        local go = self.upStarSkillGoList[i]
        go.gameObject:SetActive(true)

        local kongStr = ""
        if passiveSkillLogicConfig[upStarSkillDataList[i].passiveSkillConfig.Id].Judge == 1 then
            kongStr = "　　　"
        else
            kongStr = ""
        end
        if upStarSkillDataList[i].isOpen then
            go:GetComponent("Text").text = kongStr.."<color=#66FF00>"..upStarSkillDataList[i].titleStr..upStarSkillDataList[i].passiveSkillConfig.Desc.."</color>"
        else
            go:GetComponent("Text").text = kongStr.."<color=#B9AC97>"..upStarSkillDataList[i].titleStr..upStarSkillDataList[i].passiveSkillConfig.Desc.."</color>"
        end
        Util.GetGameObject(go.transform, "Image"):SetActive(passiveSkillLogicConfig[upStarSkillDataList[i].passiveSkillConfig.Id].Judge == 1)
    end

end
--界面关闭时调用（用于子类重写）
function RoleTalentPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function RoleTalentPopup:OnDestroy()
end

return RoleTalentPopup