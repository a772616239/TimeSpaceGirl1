ExpeditionManager = {};
local equipStarsConfig = ConfigManager.GetConfig(ConfigName.EquipStarsConfig)
local this = ExpeditionManager
this.nodeInfo = {}--所有节点信息
this.heroInfo = {}--己方英雄信息
this.lay = {}--阶段
this.allHoly = {}--激活的圣物
this.ResurgenceNum = 0--复活次数
this.curNodeInfo = {}--当前执行逻辑的节点信息
this.expeditionLeve = 0--猎妖之路阶段
this.NodeInfoIcon = {
    [ExpeditionNodeType.Jy] = "l_lieyaozhilu_zhandou02",--精英节点
    [ExpeditionNodeType.Boss] = "l_lieyaozhilu_zhandou03",--首领节点
    [ExpeditionNodeType.Resurgence] = "l_lieyaozhilu_fuhuoshenjing",--复活节点
    [ExpeditionNodeType.Reply] = "l_lieyaozhilu_shenminghuifu",-- 回复节点
    [ExpeditionNodeType.Common] = "l_lieyaozhilu_zhandou01",--普通节点
    [ExpeditionNodeType.Halidom] = "l_lieyaozhilu_shangwubaoxiang",-- 圣物节点
}
function this.Initialize()
end
--初始化远征数据
function this.InitExpeditionData(msg)
    
    
    
    this.curNodeInfo = {}
    this.nodeInfo = {}
    for i = 1, #msg.nodeInfo do
        local singleNodeInfo = {}
        local nodeInfo = msg.nodeInfo[i]
        singleNodeInfo.sortId = nodeInfo.sortId--节点id
        singleNodeInfo.lay = nodeInfo.lay--节点层
        singleNodeInfo.type = nodeInfo.type--节点类型
        singleNodeInfo.state = nodeInfo.state--节点状态 0未开启 1未通过 2未领取圣物 3已完成
        singleNodeInfo.bossTeaminfo = {}--节点队伍信息
        singleNodeInfo.bossTeaminfo.hero = {}--节点队伍信息  英雄
        
        if nodeInfo.bossTeaminfo then
            
            if nodeInfo.bossTeaminfo.hero and #nodeInfo.bossTeaminfo.hero > 0 then
                for k = 1, #nodeInfo.bossTeaminfo.hero do
                    local singleHero = {}
                    singleHero.heroTid = nodeInfo.bossTeaminfo.hero[k].heroTid
                    singleHero.star = nodeInfo.bossTeaminfo.hero[k].star
                    singleHero.level = nodeInfo.bossTeaminfo.hero[k].level
                    singleHero.remainHp = nodeInfo.bossTeaminfo.hero[k].remainHp
                    table.insert(singleNodeInfo.bossTeaminfo.hero,singleHero)
                end
            end
            singleNodeInfo.bossTeaminfo.PokemonInfos = {}--节点队伍信息  异妖
            if nodeInfo.bossTeaminfo.PokemonInfos and #nodeInfo.bossTeaminfo.PokemonInfos > 0 then
                
                for w = 1, #nodeInfo.bossTeaminfo.PokemonInfos do
                    table.insert(singleNodeInfo.bossTeaminfo.PokemonInfos,nodeInfo.bossTeaminfo.PokemonInfos[w])
                end
            end
        end
        singleNodeInfo.bossTeaminfo.totalForce = nodeInfo.bossTeaminfo.totalForce--tonumber(1000 .. i)--
        singleNodeInfo.bossTeaminfo.teamInfo = nodeInfo.bossTeaminfo.teamInfo--节点属性 招募试炼节点为怪物组id
        singleNodeInfo.holyEquipID = {}--圣物id
        if nodeInfo.holyEquipID then
            
            for j = 1, #nodeInfo.holyEquipID do
               table.insert(singleNodeInfo.holyEquipID,nodeInfo.holyEquipID[j])
            end
        end
        table.insert(this.nodeInfo,singleNodeInfo)
        this.SetCurNodeInfo(singleNodeInfo)
    end

    
    this.heroInfo = {}
    for i = 1, #msg.heroInfo do
        local singleHeroInfo = {}
        singleHeroInfo.heroId = msg.heroInfo[i].heroId--英雄动态id
        singleHeroInfo.remainHp = msg.heroInfo[i].remainHp--剩余血量
        
        --table.insert(this.heroInfo,singleHeroInfo)
        this.heroInfo[singleHeroInfo.heroId] =singleHeroInfo --msg.heroInfo[i].remainHp
    end

    this.lay = {}
    if msg.lay then
        for i = 1, #msg.lay do
            table.insert(this.lay,msg.lay[i])
        end
    end

    this.allHoly = {}
    if msg.equipIds then
        
        for i = 1, #msg.equipIds do
            local singleHalidomInfo = {}
            singleHalidomInfo.id = msg.equipIds[i].id--动态id
            singleHalidomInfo.equiptId = msg.equipIds[i].equiptId
            this.allHoly[singleHalidomInfo.id] =singleHalidomInfo
        end
    end
    --移除援助的英雄
    --if msg.removesHeroIds then
    --    this.DeleteHeroDatas(msg.removesHeroIds)
    --end
    --招募的英雄
    this.InitHeroDatas(msg.heroList)
    --装备
    this.InitEquipData(msg.equip)
    --宝器
    this.InitBaoDatas(msg.soulEquip)

    --猎妖开启时间
    this.startTime = msg.startTime
    this.RemainTimeDown()--开始计时间隔阶段
    if UIManager.IsOpen(UIName.ExpeditionMainPanel) then
        UIManager.OpenPanel(UIName.ExpeditionMainPanel)
    end
end

--根据层级获取所有节点
function this.GetAllLayNodeList()
    local layNodeInfo = {}
    table.sort(this.nodeInfo, function(a, b)
        return a.sortId < b.sortId
    end)
    --自己加入第一层 初始节点
    local firstNodeData = {}
    firstNodeData.sortId = 0
    firstNodeData.lay = 1
    firstNodeData.type = ExpeditionNodeType.Star
    firstNodeData.state = 3
    firstNodeData.bossTeaminfo = {}--节点队伍信息
    firstNodeData.bossTeaminfo.hero = {}--节点队伍信息  英雄
    layNodeInfo[1] = {}
    table.insert(layNodeInfo[1],firstNodeData)
    --正常猎妖节点
    for i = 1, #this.nodeInfo do
        --组没成
        if layNodeInfo[this.nodeInfo[i].lay] == nil then
            layNodeInfo[this.nodeInfo[i].lay] = {}
            table.insert(layNodeInfo[this.nodeInfo[i].lay],this.nodeInfo[i])
            
        else
            table.insert(layNodeInfo[this.nodeInfo[i].lay],this.nodeInfo[i])
            
        end
    end
    return layNodeInfo
end
--获取宝箱数据
function this.GetAllNodeBoxnfoList()
    local curPassLay = 0--当前通关的层级
    for i = 1, #this.nodeInfo do
        if this.nodeInfo[i].state == 3 then
            if curPassLay < this.nodeInfo[i].lay then
                curPassLay = this.nodeInfo[i].lay
            end
        end
    end
    
    local layInfo = {}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ExpeditionFloorConfig)) do
        if v.TreasureBox then
            
            local curlayInfo = {}
            curlayInfo.ConFigData = v
            curlayInfo.state = 1-- 1 未达到
            if curPassLay >= v.Id then
                curlayInfo.state = 2--2 达到未领取
            end
            for j = 1, #this.lay do
                
                if this.lay[j] == v.Id then
                    curlayInfo.state = 3--3 已完成
                end
            end
            table.insert(layInfo,curlayInfo)
        end
    end
    return layInfo , curPassLay
end
--获取当前节点信息
function this.SetCurNodeInfo(singleNodeInfo)
    if singleNodeInfo.state == ExpeditionNodeState.Finish then
        if not this.curNodeInfo or not this.curNodeInfo.lay then
            this.curNodeInfo = singleNodeInfo
        elseif singleNodeInfo.lay > this.curNodeInfo.lay then
            this.curNodeInfo = singleNodeInfo
        end
    end
    --if singleNodeInfo.state == ExpeditionNodeState.NoGetEquip then--未选择圣物
    --    this.curNodeInfo = singleNodeInfo
    --end
    --local keys = GameDataBase.SheetBase.GetKeys(ConfigManager.GetConfig(ConfigName.ExpeditionFloorConfig))
    --if singleNodeInfo.state == 3 and singleNodeInfo.lay == #keys then--全部通关
    --    this.curNodeInfo = singleNodeInfo
    --end
end
--获取当前节点信息
function this.GetCurNodeInfo()
    if not this.curNodeInfo or not this.curNodeInfo.lay then
        local allData = this.GetAllLayNodeList()
        this.curNodeInfo = allData[1][1]
    end
    return  this.curNodeInfo
end
--跟新节点信息
function this.UpdateNodeValue(nodeInfo)
    if nodeInfo then
        for i = 1, #nodeInfo do
            local nodeInfo = nodeInfo[i]
            for o = 1, #this.nodeInfo do
                if this.nodeInfo[o].sortId == nodeInfo.sortId then
                    --if nodeInfo.lay then this.nodeInfo[o].lay = nodeInfo.lay end
                    --if nodeInfo.type then this.nodeInfo[o].type = nodeInfo.type end
                    if nodeInfo.state then this.nodeInfo[o].state = nodeInfo.state end

                    if nodeInfo.bossTeaminfo then
                        if nodeInfo.bossTeaminfo.hero and #nodeInfo.bossTeaminfo.hero > 0 then
                            this.nodeInfo[o].bossTeaminfo.hero = {}--节点队伍信息  英雄
                            for k = 1, #nodeInfo.bossTeaminfo.hero do
                                local singleHero = {}
                                singleHero.heroTid = nodeInfo.bossTeaminfo.hero[k].heroTid
                                singleHero.star = nodeInfo.bossTeaminfo.hero[k].star
                                singleHero.level = nodeInfo.bossTeaminfo.hero[k].level
                                singleHero.remainHp = nodeInfo.bossTeaminfo.hero[k].remainHp
                                table.insert( this.nodeInfo[o].bossTeaminfo.hero,singleHero)
                            end
                        end
                        if nodeInfo.bossTeaminfo.PokemonInfos and #nodeInfo.bossTeaminfo.PokemonInfos > 0 then
                            this.nodeInfo[o].bossTeaminfo.PokemonInfos = {}--节点队伍信息  异妖
                            for w = 1, #nodeInfo.bossTeaminfo.PokemonInfos do
                                table.insert(this.nodeInfo[o].bossTeaminfo.PokemonInfos,nodeInfo.bossTeaminfo.PokemonInfos[w])
                            end
                        end
                        if nodeInfo.bossTeaminfo.totalForce and nodeInfo.bossTeaminfo.totalForce > 0 then
                            this.nodeInfo[o].bossTeaminfo.totalForce = nodeInfo.bossTeaminfo.totalForce
                        end
                    end
                    if nodeInfo.holyEquipID and #nodeInfo.holyEquipID > 0 then
                        this.nodeInfo[o].holyEquipID = {}
                        for j = 1, #nodeInfo.holyEquipID do
                            table.insert( this.nodeInfo[o].holyEquipID,nodeInfo.holyEquipID[j])
                        end
                    end
                    this.SetCurNodeInfo(this.nodeInfo[o])
                end
            end
        end
    end
end
--跟新英雄血量
function this.UpdateHeroHpValue(heroInfo)
    if heroInfo then
        for i = 1, #heroInfo do
            if this.heroInfo[heroInfo[i].heroId] then
                this.heroInfo[heroInfo[i].heroId].remainHp = heroInfo[i].remainHp
                
            else
                local singleHeroInfo = {}
                singleHeroInfo.heroId = heroInfo[i].heroId--英雄动态id
                singleHeroInfo.remainHp = heroInfo[i].remainHp--剩余血量
                
                this.heroInfo[singleHeroInfo.heroId] = singleHeroInfo
            end
        end
    end
end
--初始化英雄血量
function this.InitHeroHpValue(dynamicId)
    if dynamicId then
            if this.heroInfo[dynamicId] then
            else
                local singleHeroInfo = {}
                singleHeroInfo.heroId = dynamicId--英雄动态id
                singleHeroInfo.remainHp = 1--剩余血量
                
                this.heroInfo[singleHeroInfo.heroId] = singleHeroInfo
        end
    end
end
--初始化英雄血量
function this.DelHeroHpValue(heroInfo)
    if heroInfo then
        if this.heroInfo[heroInfo.dynamicId] then
            this.heroInfo[heroInfo.dynamicId] = nil
        end
    end
end
--跟新圣物
function this.UpdateHalidomValue(msg)
    if msg.equipIds then
        for i = 1, #msg.equipIds do
            local singleHalidomInfo = {}
            singleHalidomInfo.id = msg.equipIds[i].id--动态id
            singleHalidomInfo.equiptId = msg.equipIds[i].equiptId
            
            this.allHoly[singleHalidomInfo.id] =singleHalidomInfo
        end
    end
end

--更新宝箱
function this.UpdateBoxValue(layNum)
    table.insert(this.lay,layNum)
end


this.curAttackNodeInfo = {}
--开始战斗
function this.ExecuteFightBattle(_nodeId,_teamId,_expInfo, callBack)
    local num = 1
    if this.curAttackNodeInfo and this.curAttackNodeInfo.bossTeaminfo.teamInfo and this.curAttackNodeInfo.bossTeaminfo.teamInfo > 0 then
        num = 0
    else
        num = 1
    end
    NetManager.StartExpeditionBattleRequest(_nodeId, _teamId, _expInfo,function (msg)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg,num)
            for o = 1, #this.nodeInfo do
                if this.nodeInfo[o].sortId == _nodeId then
                    this.curAttackNodeInfo = this.nodeInfo[o]
                end
            end
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.EXECUTE_FIGHT, callBack)
        end)
    end)
end
function this.ExpeditionRrefreshFormation()
    local teamId = FormationTypeDef.EXPEDITION
    local newFormation = this.ExpeditionDeleteDeadRole()
    FormationManager.formationList[teamId] = newFormation
end
-- 远征删除编队中某一个成员的数据
function this.ExpeditionDeleteDeadRole()
    -- 死人后重组
    local newFormation = {} -- 编队界面的编队数据
    local curTeam = FormationManager.GetFormationByID(FormationTypeDef.EXPEDITION)
    -- 编队界面的数据
    newFormation.teamHeroInfos = {}
    newFormation.teamPokemonInfos = {}
    newFormation.teamId = FormationTypeDef.EXPEDITION
    newFormation.teamName = curTeam.teamName
    newFormation.teamPokemonInfos = curTeam.teamPokemonInfos
    -- 成员数据
    for i = 1, #curTeam.teamHeroInfos do
        local roleData = curTeam.teamHeroInfos[i]
        -- 如果队员没死翘翘了
        -- local curRoleHp = this.heroInfo[roleData.heroId].remainHp
        if this.heroInfo[roleData.heroId] and this.heroInfo[roleData.heroId].remainHp and this.heroInfo[roleData.heroId].remainHp > 0 then
            -- if curRoleHp > 0 then
            -- 编队界面数据重组
            table.insert(newFormation.teamHeroInfos, roleData)
        end
    end
    return newFormation
end

--获取宝箱红点
function this.GetNodeBoxnIsShowRedPoint()
    --local curPassLay = this.curNodeInfo
    --local layInfo = {}
    --local keys = GameDataBase.SheetBase.GetKeys(ConfigManager.GetConfig(ConfigName.ExpeditionFloorConfig))
    --if curPassLay and curPassLay.lay then
    --    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ExpeditionFloorConfig)) do
    --        if v.TreasureBox then
    --            local curlayInfo = {}
    --            if curPassLay.lay > v.Id or (curPassLay.lay == #keys and curPassLay.state == ExpeditionNodeState.Finish)  then--打完最后一层
    --                curlayInfo.state = 2--2 达到未领取
    --            end
    --            for j = 1, #this.lay do
    --                if this.lay[j] == v.Id then
    --                    curlayInfo.state = 3--3 已完成
    --                end
    --            end
    --            table.insert(layInfo,curlayInfo)
    --        end
    --    end
    --    for i = 1, #layInfo do
    --        if layInfo[i].state == 2 then
    --            return true
    --        end
    --    end
    --end
    return false
end


--获取活动刷新红点
function this.GetActivityIsShowRedPoint(isFiveRefresh,value)
    if isFiveRefresh then
        if RedPointManager.PlayerPrefsGetStr(PlayerManager.uid.."Expedition") ~= "0" then
            RedPointManager.PlayerPrefsDeleteStr(PlayerManager.uid.."Expedition")
        end
        return true
    else
        if ActTimeCtrlManager.SingleFuncState(JumpType.Expedition) then
            if RedPointManager.PlayerPrefsGetStr(PlayerManager.uid.."Expedition") ~= "0" then
                return false
            else
                if value and value == "1" then
                    RedPointManager.PlayerPrefsSetStr(PlayerManager.uid.."Expedition",value)
                end
                return true
            end
        end
    end
    return false
end

function this.CalculateallHolyWarPower()
    local allHolyWarPower = 0--万分比
    local allAddWarPowerHoly = {}
    for i, v in pairs(this.allHoly) do
        local curHeffect = ConfigManager.GetConfigData(ConfigName.ExpeditionHolyConfig,v.equiptId).effect
        local curHForceType = ConfigManager.GetConfigData(ConfigName.ExpeditionHolyConfig,v.equiptId).ForceType
        if allAddWarPowerHoly[curHeffect] then
            if curHForceType > allAddWarPowerHoly[curHeffect] then
                allAddWarPowerHoly[curHeffect] = curHForceType
                
            end
        else
            
            allAddWarPowerHoly[curHeffect] = curHForceType
        end
    end
    for i, v in pairs(allAddWarPowerHoly) do
        allHolyWarPower = allHolyWarPower + v
    end
    
    return allHolyWarPower
end

--后端刷新大闹天空阶段 当阶段与现在的阶段不同时 请求当前节点所有数据
function this.RefreshCurExpeditionLeve(expeditionLeve)
    this.expeditionLeve = expeditionLeve
end

--红点
function this.GetActivityStarOpenRedPoint()
   return PlayerPrefs.GetInt(PlayerManager.uid.."Expedition", 0) == 0
end
--间隔倒计时
this.ExpeditionPanelIsOpen = 0-- 0 不在大闹天宫里  1 在玩大闹天宫
this.ExpeditionState = 0-- 1 正常阶段 2 间隔阶段 3 重置未初始阶段
function this.SetExpeditionState(state)
    this.ExpeditionState = state
end
function this.SetExpeditionPanelIsOpen(IsOpenState)
    this.ExpeditionPanelIsOpen = IsOpenState
end
this.timer = Timer.New()
function this.RemainTimeDown()
    local timeDown = ExpeditionManager.startTime + tonumber(ConfigManager.GetConfigData(ConfigName.GlobalSystemConfig,JumpType.Expedition).SeasonEnd) - GetTimeStamp()
    if timeDown > 0 then
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            if timeDown < 0 then
                if ExpeditionManager.ExpeditionState == 1 then
                    ExpeditionManager.SetExpeditionState(2)
                end
                this.RefreshPanelShowByState()
                this.timer:Stop()
                this.timer = nil
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        if ActTimeCtrlManager.SingleFuncState(JumpType.Expedition) then
            if ExpeditionManager.ExpeditionState == 1 then
                ExpeditionManager.SetExpeditionState(2)
                this.RefreshPanelShowByState()
            end
        end
    end
end
function this.RefreshPanelShowByState()
    if ExpeditionManager.ExpeditionPanelIsOpen == 1 and UIManager.IsOpen(UIName.ExpeditionMainPanel) then --not UIManager.IsOpen(UIName.BattlePanel) then
        PlayerManager.carbonType = 1
        if ExpeditionManager.ExpeditionState == 2 then
            UIManager.OpenPanel(UIName.CarbonTypePanelV2)
            PopupTipPanel.ShowTipByLanguageId(12195)
        elseif ExpeditionManager.ExpeditionState == 3 then
            UIManager.OpenPanel(UIName.CarbonTypePanelV2)
            PopupTipPanel.ShowTipByLanguageId(12195)
        end
    end
end
function this.GetHerosHaveIsDie()
    for i, v in pairs(ExpeditionManager.heroInfo) do
        if v.remainHp <= 0 then
            return true
        end
    end
    return false
end
---------------------------------------------------------------------远征背包-----------------------------------------------
--刷新本地数据
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
--this.heroDataLists = {}
local heroDatas = {}
function this.InitHeroDatas(heroList)
    heroDatas = {}
    if not heroList then return end
    for i = 1, #heroList do
        this.UpdateHeroDatas(heroList[i])
    end
end
function this.UpdateHeroDatas(_msgHeroData)
    local heroData = {}
    heroData.soulPrintList={}
    heroData.heroBackData=_msgHeroData
    heroData.dynamicId = _msgHeroData.id
    local _id = _msgHeroData.heroId
    heroData.id = _id
    heroData.star = _msgHeroData.star
    heroData.lv = _msgHeroData.level--30
    
    
    heroData.breakId=_msgHeroData.breakId
    heroData.upStarId=_msgHeroData.starBreakId
    
    heroData.createTime=_msgHeroData.createTimelocal
    heroData.lockState = _msgHeroData.lockState
    heroData.createtype = _msgHeroData.createtype
    local _configData = heroConfig[_id]
    heroData.heroConfig=heroConfig[_id]
    heroData.maxStar=_configData.MaxRank
    
    local actionPowerRormula= gameSetting[1].ActionPowerRormula
    heroData.actionPower=heroData.heroConfig.ActionPower+math.floor(((actionPowerRormula[1] * math.pow(heroData.lv, 3) + actionPowerRormula[2] * math.pow(heroData.lv, 2) + actionPowerRormula[3] * heroData.lv + actionPowerRormula[4])))--_msgHeroData.actionPower
    heroData.equipIdList=_msgHeroData.equipIdList
    heroData.jewels=_msgHeroData.jewels

    heroData.talismanList = _msgHeroData.especialEquipLevel --法宝等级
    if(#_msgHeroData.soulPos>=1) then
        local soulPrintList = {}
        for i,v in ipairs(_msgHeroData.soulPos) do
            local soulPrint = { equipId = v.equipId, position = v.position}
            SoulPrintManager.AddSoulPrintUpHeroDynamicId(v.equipId,heroData.dynamicId)
            table.insert(soulPrintList, soulPrint)
        end
        heroData.soulPrintList= soulPrintList
    end
    heroData.skillIdList={}--主动技
    HeroManager.UpdateSkillIdList(heroData)
    heroData.passiveSkillList = {}--被动技
    HeroManager.UpdatePassiveHeroSkill(heroData)
    heroData.hp = _configData.Hp
    heroData.attack = _configData.Attack
    heroData.pDef = _configData.PhysicalDefence
    heroData.mDef = _configData.MagicDefence
    heroData.speed = _configData.Speed
    heroData.live = GetResourcePath(_configData.Live)
    heroData.profession = _configData.Profession
    heroData.ProfessionResourceId= _configData.ProfessionResourceId
    if GetJobSpriteStrByJobNum(_configData.Profession) then
        heroData.professionIcon = GetJobSpriteStrByJobNum(_configData.Profession)
    else
        heroData.professionIcon = GetJobSpriteStrByJobNum(1)
    end
    heroData.name = _configData.ReadingName
    heroData.painting = GetResourcePath(_configData.Painting)
    heroData.icon = GetResourcePath(_configData.Icon)
    heroData.scale = _configData.Scale
    heroData.position = _configData.Position
    heroData.property = _configData.PropertyName
    heroData.sortId = #heroDatas+1
    --table.insert(this.heroDataLists, heroData)
    heroDatas[heroData.dynamicId]= heroData
    this.SetEquipUpHeroDid(heroData.equipIdList,heroData.dynamicId)
    this.SetEquipTreasureUpHeroDid(heroData.jewels,heroData.dynamicId)
    this.SetTalismanLv(heroData.dynamicId,heroData.talismanList)
    ExpeditionManager.InitHeroHpValue(heroData.dynamicId)
    heroData.warPower = HeroManager.CalculateHeroAllProValList(1, heroData, false)[HeroProType.WarPower]
    --this.SetSoulPrintUpHeroDid(heroData.soulPrintList,heroData.dynamicId)
    --this.GetSingleProScoreVal()
end
function this.SetEquipUpHeroDid(_equipids,_heroDid)
    for i = 1, #_equipids do
        EquipManager.SetEquipUpHeroDid(_equipids[i],_heroDid)
    end
end
function this.SetEquipTreasureUpHeroDid(_equipTreasureDids,_heroDid)
    for i = 1, #_equipTreasureDids do
        EquipTreasureManager.SetEquipTreasureUpHeroDid(_equipTreasureDids[i],_heroDid)
    end
end
--设置法宝等级
function this.SetTalismanLv(did,lv)
    heroDatas[did].talismanList=lv
end
--获取所有英雄信息
function this.GetAllHeroDatas(heros,_lvLimit)
    local lvLimit = 0
    local allUpZhenHeroList = FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_ENDLESS_MAP)
    if _lvLimit then lvLimit = _lvLimit end
    --local heros = {}
    for i, v in pairs(heroDatas) do
        if v.lv >= lvLimit or allUpZhenHeroList[v.dynamicId] then
            table.insert(heros,v)
        end
    end
    table.sort(heros, function(a,b) return a.sortId < b.sortId end)
    return heros
end

--通过属性筛选英雄
function this.GetHeroDataByProperty(heros,_property,_lvLimit)
    local lvLimit = 0
    local allUpZhenHeroList = FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_ENDLESS_MAP)
    if _lvLimit then lvLimit = _lvLimit end
    local index = 1
    if heros and #heros > 0 then
        index = index + #heros
    end
    for i, v in pairs(heroDatas) do
        if v.property == _property then
            if v.lv >= lvLimit or allUpZhenHeroList[v.dynamicId] then
                heros[index] = v
                index = index + 1
            end
        end
    end
    return heros
end
--获取单个英雄数据
function this.GetSingleHeroData(heroDId)
    if heroDatas[heroDId] then
        
        return heroDatas[heroDId]
    end
    return nil
end
--删除本地英雄信息
function this.DeleteHeroDatas(heroDIds)
    if not heroDIds then return end
    for i = 1, #heroDIds do
        if heroDatas[heroDIds[i]] then
            --清除英雄装备上挂载的英雄did
            --local equips=heroDatas[heroDIds[i]].equipIdList
            --if equips and LengthOfTable(equips)>0 then
            --    for i = 1, LengthOfTable(equips) do
            --        if EquipManager.GetSingleEquipData(equips[i]) then
            --            EquipManager.GetSingleEquipData(equips[i]).upHeroDid="0"
            --        end
            --    end
            --end
            --清除英雄法宝上挂载的英雄did
            --local talismanList=heroDatas[heroDIds[i]].talismanList
            --if talismanList and LengthOfTable(talismanList)>0 then
            --    for i = 1, LengthOfTable(talismanList) do
            --        if TalismanManager.talismanTabs[talismanList[i]] then
            --            TalismanManager.talismanTabs[talismanList[i]].upHeroDid="0"
            --        end
            --    end
            --end
            --
            --清楚编队上的英雄
            FormationManager.AllFormationDeleCurHeroId(heroDIds[i])
            --清除英雄魂印上挂载的英雄did
            --SoulPrintManager.hasEquipSoulPrintId[heroDIds[i]]=nil
            --删除远征英雄数据
            ExpeditionManager.DelHeroHpValue(heroDatas[heroDIds[i]])
            --删除英雄
            heroDatas[heroDIds[i]]=nil
        end
    end
end

--装备
this.equipDatas = {}
local equipConfig = ConfigManager.GetConfig(ConfigName.EquipConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
function this.InitEquipData(_equipDatas)
    this.equipDatas = {}
    if not _equipDatas then return end
    for i = 1, #_equipDatas do
        this.InitUpdateEquipData(_equipDatas[i])
    end
end
function this.InitUpdateEquipData(_equipData)
    local equipdata={}
    equipdata.equipConfig = equipConfig[_equipData.equipId]
    if equipdata.equipConfig~=nil then       
        equipdata.itemConfig=itemConfig[equipdata.equipConfig.Id]
        equipdata.did = equipdata.equipConfig.Id
        equipdata.id =  equipdata.equipConfig.Id
        if itemConfig[equipdata.id] then
            equipdata.icon = GetResourcePath(itemConfig[equipdata.id].ResourceID)
        else

            return
        end
        equipdata.frame = GetQuantityImageByquality(equipdata.equipConfig.Quality)--ItemQuality[equipdata.equipConfig.Quality].icon
        equipdata.num=1
        equipdata.position=equipdata.equipConfig.Position
        equipdata.upHeroDid="0"
        local propList = {}
        for index, prop in ipairs(equipdata.equipConfig.Property) do
            propList[index] = {}
            propList[index].propertyId = prop[1]
            propList[index].propertyValue = prop[2]
            propList[index].PropertyConfig = propertyConfig[prop[1]]
        end
        equipdata.mainAttribute = propList
        equipdata.star = equipStarsConfig[equipdata.equipConfig.Star].Stars
        equipdata.backData=_equipData
        this.equipDatas[_equipData.id]=equipdata
    end
end
--设置装备穿戴的英雄
function this.SetEquipUpHeroDid(_equipid,_heroDid)
    if this.equipDatas[_equipid] then
        this.equipDatas[_equipid].upHeroDid=_heroDid
    end
end

--宝器
local jewelConfig = ConfigManager.GetConfig(ConfigName.JewelConfig)
local allTreasures = {}
function this.InitBaoDatas(_soulEquips)
    allTreasures = {}
    if not _soulEquips then return end
    for i = 1, #_soulEquips do
        this.InitSingleTreasureData(_soulEquips[i])
    end
end
--初始化单个宝物的数据
function this.InitSingleTreasureData(_singleData)
    if _singleData==nil then
        return
    end
    local single={}
    local staticId=_singleData.equipId
    local currJewel=jewelConfig[staticId]
    single.id=staticId
    single.idDyn=_singleData.id
    single.lv=_singleData.exp
    single.refineLv=_singleData.rebuildLevel
    single.maxLv=currJewel.Max[1]
    single.maxRefineLv=currJewel.Max[2]
    single.upHeroDid=""
    local quantity=currJewel.Level
    single.quantity=quantity
    single.frame=GetQuantityImageByquality(quantity)
    single.name=itemConfig[staticId].Name
    single.itemConfig=itemConfig[staticId]
    single.levelPool=currJewel.LevelupPool
    single.proIcon=GetProStrImageByProNum(currJewel.Race)
    single.refinePool=currJewel.RankupPool
    single.equipType=currJewel.Location
    if currJewel.Location==1 then
        single.type=GetLanguageStrById(10505)
    else
        single.type=GetLanguageStrById(10506)
    end
    single.icon=GetResourcePath(itemConfig[staticId].ResourceID)
    single.strongConfig=this.GetCurrTreasureLvConfig(1,currJewel.LevelupPool,_singleData.exp)
    single.refineConfig=this.GetCurrTreasureLvConfig(2,currJewel.RankupPool,_singleData.rebuildLevel)
    
    allTreasures[_singleData.id]=single
end
local jewerLevelUpConfig = ConfigManager.GetConfig(ConfigName.JewelRankupConfig)
--获取当前宝物升级数据
function this.GetCurrTreasureLvConfig(_type,_id,_lv)
    for _, configInfo in ConfigPairs(jewerLevelUpConfig) do
        if configInfo.Type==_type and configInfo.PoolID==_id and configInfo.Level==_lv then
            return configInfo
        end
    end
end
--根据动态id获取宝物
function this.GetSingleTreasureByIdDyn(_idDyn)
    if allTreasures==nil then
        return
    end
    return allTreasures[_idDyn]

end
--设置装备穿戴的英雄
function this.SetEquipTreasureUpHeroDid(_equipTreasureDid,_heroDid)
    if allTreasures[_equipTreasureDid] then
        allTreasures[_equipTreasureDid].upHeroDid=_heroDid
    end
end
---------------------------------------------------------------------远征背包-----------------------------------------------
return this