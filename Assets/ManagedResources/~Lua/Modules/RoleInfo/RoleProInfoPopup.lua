require("Base/BasePanel")
RoleProInfoPopup = Inherit(BasePanel)
local this = RoleProInfoPopup
--> 基础 特殊 加成 国战
local sDataTable = {
    [1] = {name = GetLanguageStrById(11857),showType = 1},
    [2] = {name = GetLanguageStrById(11858),showType = 2},
    [3] = {name = GetLanguageStrById(11859),showType = 3},
    [4] = {name = GetLanguageStrById(22287),showType = 4},
}
local allPro = {}--所有属性  三维数组
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local fristProGoList = {}
local secondProGoList = {}
local thirdlyProGoList = {}
local fourthProGoList = {}
local heroSConFig
local isShowGuild = true
--初始化组件（用于子类重写）
function RoleProInfoPopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.proPre1 = Util.GetGameObject(self.gameObject, "proPre1")
    this.proPre2 = Util.GetGameObject(self.gameObject, "proPre2")
    this.fristGrid = Util.GetGameObject(self.gameObject, "grid/ver/recordPer (1)/Mask")
    this.secondGrid = Util.GetGameObject(self.gameObject, "grid/ver/recordPer (2)/Mask")
    this.thirdlyGrid = Util.GetGameObject(self.gameObject, "grid/ver/recordPer (3)/Mask")
    this.fourthGrid = Util.GetGameObject(self.gameObject, "grid/ver/recordPer (4)/Mask")
end

--绑定事件（用于子类重写）
function RoleProInfoPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

local guildSkill = nil
--界面打开时调用（用于子类重写）
function RoleProInfoPopup:OnOpen(...)
    local data = {...}
    heroSConFig = data[2]
    isShowGuild = data[3]--图鉴不显示公会技能等级特殊操作
    guildSkill = data[4] and data[4] or nil--其他玩家公会技能等级特殊操作
    for i = 1, #sDataTable do
        allPro[i] = {}
    end
    --加基础 和 辅助属性
    for proId, val in pairs(data[1]) do
        if propertyConfig[proId] then
            -- 0不显示 1基础属性 2特殊属性 3争霸属性 4加成
            if propertyConfig[proId].IfShow > 0 then
                local curData = allPro[propertyConfig[proId].IfShow]
                local curLength = #curData > 0 and #curData or 1
                if not curData[curLength] then
                    curData[curLength] = {}
                    table.insert(curData[curLength], {proId = proId, proVal = val})
                elseif curData[curLength] and #curData[curLength] < 2 then
                    table.insert(curData[curLength],{proId = proId, proVal = val})
                elseif curData[curLength] and #curData[curLength] >= 2 then
                    curData[curLength + 1] = {}
                    table.insert(curData[curLength + 1],{proId = proId, proVal = val})
                end
            end
        end
    end
    --加公会技能特殊属性
    allPro[3][1] = {}
    local allLv = isShowGuild and GuildSkillManager.GetAllGuildSkillLv(heroSConFig.Profession) or 0
    if guildSkill then allLv = guildSkill end
    local id = heroSConFig.Profession
    table.insert(allPro[3][1],{proId = GetLanguageStrById(11088)..GuildSkillType[id], proVal = allLv})
    this.ShowPanelData()
end
function this.ShowPanelData()
    this.GridShowData(1,allPro[1],fristProGoList, this.proPre1,this.fristGrid)

    --特殊属性数据重组
    local list = {}
    for i = 1, #allPro[2] do
        table.insert(list, allPro[2][i][1])
        table.insert(list, allPro[2][i][2])
    end
    allPro[2] = list
    table.sort(allPro[2], function (a, b)
        return propertyConfig[a.proId].Sort < propertyConfig[b.proId].Sort
    end)

    local all = {}
    for i = 1, #allPro[2], 2 do
        list = {}
        list[1] = allPro[2][i]
        list[2] = allPro[2][i + 1]
        table.insert(all, list)
    end
    allPro[2] = all

    this.GridShowData(2,allPro[2],secondProGoList, this.proPre1,this.secondGrid)
    this.GridShowData(3,allPro[3],thirdlyProGoList, this.proPre2,this.thirdlyGrid)
    this.GridShowData(4,allPro[4],fourthProGoList, this.proPre1,this.fourthGrid)
end

function this.GridShowData(type,curAllPro,curProGoList,curPre,curGrid)
    for i = 1, math.max(#curAllPro, #curProGoList) do
        local go = curProGoList[i]
        if not go then
            go = newObject(curPre)
            go.transform:SetParent(curGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            curProGoList[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #curAllPro do
        this.SingleProShowData(type,curAllPro[i],curProGoList[i])
    end
end

function this.SingleProShowData(type,data,go)
    go:SetActive(true)
    if type == 3 then
        Util.GetGameObject(go, "proName"):GetComponent("Text").text = GetLanguageStrById(data[1].proId)..":"
        Util.GetGameObject(go, "proVale"):GetComponent("Text").text = "Lv."..data[1].proVal
        if guildSkill then
            Util.GetGameObject(go, "jumpBtn"):SetActive(false)
        else
            Util.GetGameObject(go, "jumpBtn"):SetActive(true)
        end
        Util.AddOnceClick(Util.GetGameObject(go, "jumpBtn"), function()
            JumpManager.GoJump(73001)
        end)
    else
        for i = 1, 2 do
            local curGo = go .transform:GetChild(i-1).gameObject
            if #data > 1 then
                curGo:SetActive(true)
                Util.GetGameObject(curGo, "proName"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[data[i].proId].Info)..":"
                local proVale = Util.GetGameObject(curGo, "proVale"):GetComponent("Text")
                if propertyConfig[data[i].proId].Style == 1 then--绝对值
                    proVale.text = GetPropertyFormatStr(propertyConfig[data[i].proId].Style, data[i].proVal)
                elseif propertyConfig[data[i].proId].Style == 2 then--百分百
                    -- 暴击默认 10% 前端加显示 
                    -- LogError("str:"..data[i].proId.."  ".. GetLanguageStrById(propertyConfig[data[i].proId].Info))
                    if data[i].proId == 55 then
                        proVale.text = GetPropertyFormatStr(propertyConfig[data[i].proId].Style, data[i].proVal*100 + 1000)
                    else
                        proVale.text = GetPropertyFormatStr(propertyConfig[data[i].proId].Style, data[i].proVal*100)
                    end
                    
                end
                Util.GetGameObject(curGo, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(propertyConfig[data[i].proId].Icon)
            else
                curGo:SetActive(false)
            end
        end
    end
end

--function this.ShowProValPanelData()
--  local allProKeys = {}
--    for k, v in pairs(allPro) do
--        if k ~= 1000 and (propertyConfig[k].IfShow == 0) then
--            local singleProData = {}
--            singleProData.id = k
--            singleProData.val = v
--            table.insert(allProKeys,singleProData)
--        end
--    end
--    table.sort(allProKeys, function (a,b)return a.id<b.id end)
--    for i = 1, #allProKeys do
--        local id = allProKeys[i].id
--        local val =  allProKeys[i].val
--            local go = allProGoList[i]
--            if not go then
--                go = newObject(this.proPre)
--                go.transform:SetParent(this.proValRect.transform)
--                go.transform.localScale = Vector3.one
--                go.transform.localPosition = Vector3.zero
--                go:SetActive(true)
--                allProGoList[i] = go
--            end
--            go:GetComponent("Text").text = propertyConfig[id].Info
--            if propertyConfig[id].Style==1 then--绝对值
--                Util.GetGameObject(go.transform, "proVal"):GetComponent("Text").text = GetPropertyFormatStr(propertyConfig[id].Style, val)
--            elseif propertyConfig[id].Style==2 then--百分百
--                Util.GetGameObject(go.transform, "proVal"):GetComponent("Text").text = GetPropertyFormatStr(propertyConfig[id].Style, val*100)
--            end
--    end
--    --加公会技能加成显示
--    local go = allProGoList[#allProKeys + 1]
--    if not go then
--        go = newObject(this.proPre)
--        go.transform:SetParent(this.proValRect.transform)
--        go.transform.localScale = Vector3.one
--        go.transform.localPosition = Vector3.zero
--        go:SetActive(true)
--        allProGoList[#allProKeys + 1] = go
--    end
--    go:GetComponent("Text").text = "公会技能-"..GuildSkillType[heroSConFig.Profession]
--    local allLv,isEqualityLv = GuildSkillManager.GetAllGuildSkillLv(heroSConFig.Profession)
--    Util.GetGameObject(go.transform, "proVal"):GetComponent("Text").text = allLv
--end

--界面关闭时调用（用于子类重写）
function RoleProInfoPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function RoleProInfoPopup:OnDestroy()
     fristProGoList = {}
     secondProGoList = {}
     thirdlyProGoList = {}
     fourthProGoList = {}
end

return RoleProInfoPopup