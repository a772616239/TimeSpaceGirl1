require("Base/BasePanel")
PartsMainPopup = Inherit(BasePanel)
local this = PartsMainPopup
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local HeroRankupGroup = ConfigManager.GetConfig(ConfigName.HeroRankupGroup)
local AdjustConfig = ConfigManager.GetConfig(ConfigName.AdjustConfig)
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local SkillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local PassiveSkillLogicConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local PassiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local EquipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)

local curHeroData
local openThisPanel
local curHeroEquipDatas = {}
local curSelectEquipData
local curPos = 1
local isLock = false
local SpriteName="cn2-X1_zhushen_dengji_0"

--初始化组件（用于子类重写）
function PartsMainPopup:InitComponent()
    this.equipGo = {}
    for i = 1, 4 do
        this.equipGo[i] = Util.GetGameObject(this.transform, "Equips/Equip" .. i)
    end

    this.Unlock = Util.GetGameObject(this.gameObject, "Unlock")--未解锁
    this.CastGod = Util.GetGameObject(this.gameObject, "CastGod")--铸神
    this.Max = Util.GetGameObject(this.gameObject, "Max")--满级

    this.ItemGrid = Util.GetGameObject(this.gameObject, "ItemGrid")
    this.resetBtn = Util.GetGameObject(this.gameObject, "resetBtn")--重置
    this.previewBtn = Util.GetGameObject(this.gameObject, "previewBtn")--预览
    this.helpBtn = Util.GetGameObject(this.gameObject, "helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition
    this.UnlockOrCastGodBtn = Util.GetGameObject(this.gameObject, "UnlockOrCastGodBtn")--解锁或者铸神
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")

    this.curSelectHeroIds = {}
end

--绑定事件（用于子类重写）
function PartsMainPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.previewBtn, function()
        UIManager.OpenPanel(UIName.PartsSkillOverviewPopup, curHeroData, curPos)
    end)
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Parts,this.helpPosition.x,this.helpPosition.y)
    end)
    Util.AddClick(this.resetBtn, function()
        local heroPartsData = curHeroData.partsData[curPos]
        if heroPartsData.isUnLock == -1 then
            PopupTipPanel.ShowTipByLanguageId(22557)
            return
        end
        if heroPartsData.isUnLock == 0 then
            PopupTipPanel.ShowTipByLanguageId(22558)
            return
        end
        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.PartsReset, curHeroData, curPos)
    end)
end

--添加事件监听（用于子类重写）
function PartsMainPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Parts.FreshEquip, this.RreshEquip)
end

--移除事件监听（用于子类重写）
function PartsMainPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Parts.FreshEquip, this.RreshEquip)
end

--界面打开时调用（用于子类重写）
function PartsMainPopup:OnOpen(...)
    local args = {...}
    curHeroData = args[1]
    openThisPanel = args[2]

    this.curSelectHeroIds = {}
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PartsMainPopup:OnShow()
    curPos = 1
    NetManager.AdjustUnLockListRequest(curHeroData.dynamicId, function(msg)
    end)

    this.RreshEquip()
end

--刷新装备
function PartsMainPopup.RreshEquip()
    curHeroEquipDatas = {}
    for i = 1, #curHeroData.equipIdList do
        local equipData = EquipManager.GetSingleHeroSingleEquipData(curHeroData.equipIdList[i], curHeroData.dynamicId)
        if equipData ~= nil then
            curHeroEquipDatas[equipData.equipConfig.Position] = equipData
        end
    end

    for i = 1, 4 do
        local go = this.equipGo[i]
        local icon = Util.GetGameObject(go.transform, "icon")
        local star = Util.GetGameObject(go.transform, "star")
        local mask = Util.GetGameObject(go.transform, "mask")
        if curHeroEquipDatas[i] then
            icon:SetActive(true)
            star:SetActive(true)
            mask:SetActive(false)
            go:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(curHeroEquipDatas[i].equipConfig.Quality))
            icon:GetComponent("Image").sprite = Util.LoadSprite(curHeroEquipDatas[i].icon)
            EquipManager.SetEquipStarShow(star, curHeroEquipDatas[i].itemConfig.Id)
            -- if curHeroData.partsData[i].actualLv > 0 then
            --     Util.GetGameObject(go.transform, "lvup/Text"):GetComponent("Text").text = string.format(GetLanguageStrById(22559), curHeroData.partsData[i].actualLv)
            -- end
            
            -- go:GetComponent("Button").enabled = false
        else
            icon:SetActive(false)
            star:SetActive(false)
            mask:SetActive(true)
            go:GetComponent("Image").sprite = Util.LoadSprite("cn2-X1_tongyong_daojukuang_07")
            -- go:GetComponent("Button").enabled = true
        end
        Util.AddOnceClick(go, function()
            if curPos == i then
                if curHeroEquipDatas[i] then
                    curSelectEquipData = curHeroEquipDatas[i]                    
                    UIManager.OpenPanel(UIName.RoleEquipChangePopup, openThisPanel, 1, curHeroData, curHeroEquipDatas[i], i)
                else 
                    -- 如果没有装备跳出选装备界面
                    UIManager.OpenPanel(UIName.EquipSelectPopup, curHeroData, i, openThisPanel, nil)
                end
                return
            end
            curPos = i
            this.UpdateSelect()
        end)
    end

    this.UpdateSelect()
end

--铸神等级
function this.ShowAddLevel(curPos)
    local AddLevel = 0
    local curData = curHeroData.partsData[curPos]
    if curData.isUnLock > curData.actualLv then
        AddLevel = curData.actualLv 
    else
        AddLevel = curData.isUnLock
    end
    if AddLevel < 0 then AddLevel = 0 end
    return  AddLevel 
end


--更新选择
function PartsMainPopup.UpdateSelect()
    for i = 1, 4 do
        local go = this.equipGo[i]
        Util.GetGameObject(go, "select"):SetActive(curPos == i)
        local nowAddLevel=this.ShowAddLevel(i)
        if nowAddLevel > 0 then
            Util.GetGameObject(go, "AddLv"):SetActive(true)

            Util.GetGameObject(go, "AddLv"):GetComponent("Image").sprite = Util.LoadSprite(SpriteName..nowAddLevel)
        else
            Util.GetGameObject(go, "AddLv"):SetActive(false)
        end
    end

    this.Unlock:SetActive(false)
    this.CastGod:SetActive(false)
    this.Max:SetActive(false)
    if curHeroData.partsData and curHeroData.partsData[curPos] then
        if curHeroData.partsData[curPos].isUnLock == -1 then
            -- lock
            this.Unlock:SetActive(true)
            isLock = true
            this.SetUnlockUI()
        else
            -- unlock
            this.CastGod:SetActive(true)
            isLock = false
            this.SetCastGodUI()
        end
    end
end

--设置解锁UI
function PartsMainPopup.SetUnlockUI()
    local skillList = HeroManager.GetHeroSkillSortList(curHeroData)
    if skillList[curPos] then
        local skillLogic
        local id = skillList[curPos].skillId
        if SkillLogicConfig[id] then --主动
            skillLogic = SkillLogicConfig[id]
        elseif PassiveSkillLogicConfig[id] then--被动
            skillLogic = PassiveSkillLogicConfig[id]
        end
        this.ItemGrid:SetActive(skillLogic.Level < 8)
        
        Util.GetGameObject(this.Unlock, "Bg/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillList[curPos].skillConfig.Icon))
        Util.GetGameObject(this.Unlock,"Bg/lv"):GetComponent("Text").text = skillLogic.Level

        --材料
        local rankUpGroupData = HeroRankupGroup[AdjustConfig[1].UnlockCost[1]]
        local data = {{}}
        data[1].frame = GetHeroQuantityImageByquality(nil, rankUpGroupData.StarLimit)
        data[1].icon = GetNoTargetHero(rankUpGroupData.StarLimit)
        data[1].num = GetNumUnenoughColor(LengthOfTable(this.curSelectHeroIds), AdjustConfig[1].UnlockCost[2])
        data[1].func = function ()
            UIManager.OpenPanel(UIName.PartsMeterialSelectPopup, this, rankUpGroupData.StarLimit, AdjustConfig[1].UnlockCost[2], curHeroData, rankUpGroupData.IsSameClan)
        end

        PartsMainPopup.RreshItem(data)

        PartsMainPopup.SetBtnClicked()
    else
        LogError("PartsMainPopup UpdateSelect NoSkill Error!")
    end
end

local materialsEnough = true
--设置铸神UI
function PartsMainPopup.SetCastGodUI()
    local skillList = HeroManager.GetHeroSkillSortList(curHeroData)
    if skillList[curPos] then
        local skillLogic
        local _isPassivity
        local skillId = skillList[curPos].skillId
        if SkillLogicConfig[skillId] then --主动
            skillLogic = SkillLogicConfig[skillId]
            _isPassivity = false
        elseif PassiveSkillLogicConfig[skillId] then --被动
            skillLogic = PassiveSkillLogicConfig[skillId]
            _isPassivity = true
        end

        local cur = Util.GetGameObject(this.CastGod, "cur")
        local next = Util.GetGameObject(this.CastGod, "next")
        local max = Util.GetGameObject(this.Max, "max")
        local desc = Util.GetGameObject(this.CastGod, "effect/Text"):GetComponent("Text")               

        this.Max:SetActive(skillLogic.Level >= 8)
        this.CastGod:SetActive(skillLogic.Level < 8)
        this.ItemGrid:SetActive(skillLogic.Level < 8)
        if skillLogic.Level >= 8 then
            this.SetSkill(max, skillId, _isPassivity)
        else
            local name = this.SetSkill(cur, skillId, _isPassivity)
            this.SetSkill(next, skillId + 1, _isPassivity)          
            desc.text = string.format(GetLanguageStrById(22553), GetLanguageStrById(name))
            --材料
            local materialLv
            local curData = curHeroData.partsData[curPos]
            if curData.isUnLock > curData.actualLv then
                materialLv = curData.actualLv 
            else
                materialLv = curData.isUnLock
            end

            materialsEnough = true
            local materialData = HeroManager.GetPartsConfigData(materialLv)
            local datas = {}
            for i = 1, 2 do
                local data = {}
                local itemId = materialData.cost[i][1]
                local cost = materialData.cost[i][2]
                local num = BagManager.GetItemCountById(itemId)
                local itemData = ItemConfig[itemId]
                data.frame = GetHeroQuantityImageByquality(itemData.Quantity)
                data.icon = GetResourcePath(itemData.ResourceID)
                data.num = GetNumUnenoughColor(num, cost, PrintWanNum2(num), PrintWanNum2(cost))
                data.func = function ()
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemId)
                end
                table.insert(datas, data)

                if num < cost then
                    materialsEnough = false
                end
            end
            PartsMainPopup.RreshItem(datas)

            if materialData.NextId == 0 then -- 理论进不到 还是判断下
                return
            end
            PartsMainPopup.SetBtnClicked()
        end
    end
end

--设置技能信息
function this.SetSkill(go, skillid, isPassivity)
    local skillConfig
    local skillLogicInner
    if isPassivity then
        skillConfig = PassiveSkillConfig[skillid]
        skillLogicInner = PassiveSkillLogicConfig[skillid]
    else
        skillConfig = SkillConfig[skillid]
        skillLogicInner = SkillLogicConfig[skillid]
    end

    Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillConfig.Icon))
    Util.GetGameObject(go, "Text"):GetComponent("Text").text = skillLogicInner.Level

    Util.AddOnceClick(go, function()
        local maxLv = HeroManager.GetHeroSkillMaxLevel(curHeroData.heroConfig.Id, curPos)
        local skillData = {}
        skillData.skillId = skillid
        skillData.skillConfig = skillConfig       
        UIManager.OpenPanel(UIName.SkillInfoPopup, skillData, 1, 10, maxLv, curPos, skillLogicInner.Level)
    end)

    return skillConfig.Name
end

--刷新道具
function PartsMainPopup.RreshItem(data)
    for i = 1, 2 do
        Util.GetGameObject(this.ItemGrid,"Item" .. i):SetActive(false)
    end
    for i = 1, #data do
        local go = Util.GetGameObject(this.ItemGrid,"Item" .. i)
        local icon = Util.GetGameObject(go.transform,"icon"):GetComponent("Image")
        local num = Util.GetGameObject(go.transform,"num"):GetComponent("Text")

        go:GetComponent("Image").sprite = Util.LoadSprite(data[i].frame)
        icon.sprite = Util.LoadSprite(data[i].icon)
        num.text = data[i].num
        Util.AddOnceClick(go, data[i].func)
        
        go:SetActive(true)
    end
end

function PartsMainPopup.SetBtnClicked()
    if isLock then
        this.UnlockOrCastGodBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_zhushen_jiesuoanniu"))
    else
        this.UnlockOrCastGodBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_zhushen_zhushenanniu"))
    end
    Util.AddOnceClick(this.UnlockOrCastGodBtn, function()
        if isLock then
            local heroId = {}
            for k, v in pairs(this.curSelectHeroIds) do
                table.insert(heroId, v.dynamicId)
            end
            if #heroId < AdjustConfig[1].UnlockCost[2] then
                PopupTipPanel.ShowTipByLanguageId(12655)
                return
            end
            NetManager.AdjustUnLockRequest(curHeroData.dynamicId, curPos, heroId, function(msg)
                HeroManager.DeleteHeroDatas(heroId)
                this.curSelectHeroIds = {}
                HeroManager.PartsSetUnlockValue(curHeroData, curPos)
                this.RreshEquip()
                if msg.drop then
                       UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function() end)
                end
             
            end)
        else
            if this.Max.activeSelf then
                return
            end

            local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            local isHaveEquip = false
            for i = 1, #curHeroData.equipIdList do
                local equipId = tonumber(curHeroData.equipIdList[i])
                local equipConfig = EquipConfig[equipId]
                if equipConfig.Position == curPos then
                    local heroPartsData = curHeroData.partsData[equipConfig.Position]
                    if heroPartsData then
                        if equipConfig.IfAdjust == 0 then
                            PopupTipPanel.ShowTipByLanguageId(22554)
                            return
                        end
                        if heroPartsData.isUnLock >= equipConfig.Adjustlimit then
                            PopupTipPanel.ShowTipByLanguageId(22556)
                            return
                        end

                        isHaveEquip = true
                    end
                end
            end
            if not isHaveEquip then
                PopupTipPanel.ShowTipByLanguageId(22555)
                return
            end

            -- 材料
            if not materialsEnough then
                PopupTipPanel.ShowTipByLanguageId(10455)
                return
            end

            NetManager.AdjustLevelUpRequest(curHeroData.dynamicId, curPos, function()
                HeroManager.PartsSetLvUpValue(curHeroData, curPos)
                this.RreshEquip()
                openThisPanel:UpdatePanelData()
                local newPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
                -- if oldPower ~= newPower then
                --     UIManager.OpenPanel(UIName.WarPowerChangeNotifyPanelV2, {oldValue = oldPower, newValue = newPower})
                -- end
                RefreshPower(oldPower, newPower)
            end)
        end
    end)
end

function this.UpdateEquipPosHeroData(type,pos,equipList,curPosData,postion)
    PartsMainPopup.RreshEquip()
end

function PartsMainPopup:OnClose()
    curHeroEquipDatas = {}
    this.curSelectHeroIds = {}
end

--界面销毁时调用（用于子类重写）
function PartsMainPopup:OnDestroy()

end

return PartsMainPopup