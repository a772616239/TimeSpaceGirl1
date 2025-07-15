GuildSkillManager = {};
local this = GuildSkillManager
local guildTechnology = ConfigManager.GetConfig(ConfigName.GuildTechnology)
local allGuildSkillData = {}--后端所有数据  根据 Profession 存 二维数组
function this.Initialize()
    allGuildSkillData = {}
    for _, configInfo in ConfigPairs(guildTechnology) do
        if not allGuildSkillData[configInfo.Profession] then
            allGuildSkillData[configInfo.Profession] = {}
        end
        if not allGuildSkillData[configInfo.Profession][configInfo.TechId] then
            this.InitSingleData(configInfo.Profession,configInfo.TechId,0)
        end
    end
end
--初始化数据
function this.InitData(msg)
    this.SetAllGuildSkillRedPlayers()
    for i = 1, #msg.skill do
        local baceLv = math.floor(msg.skill[i].level/#allGuildSkillData[msg.skill[i].type])
        local addLv = msg.skill[i].level%#allGuildSkillData[msg.skill[i].type]
        for j = 1, #allGuildSkillData[msg.skill[i].type] do
            local curLv = baceLv
            if j <= addLv then
                curLv = curLv + 1
            end
            this.InitSingleData(msg.skill[i].type,j,curLv)
        end
    end
end
function this.InitSingleData(_Profession,_TechId,_level)
    
    local singleSkillData = {}
    singleSkillData.id = _TechId
    singleSkillData.level = _level
    singleSkillData.config = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.GuildTechnology,"Profession",_Profession,"TechId",singleSkillData.id,"Level",singleSkillData.level)
    allGuildSkillData[_Profession][_TechId] = singleSkillData
end
--获取一种类型的公会技能数据
function this.GetSkillDataByType(_Profession)
   return allGuildSkillData[_Profession]
end
--设置公会技能等级数据
function this.SetSkillDataLv(_Profession,_id,_lv)
    if allGuildSkillData[_Profession] and allGuildSkillData[_Profession][_id] then
        allGuildSkillData[_Profession][_id].level = _lv
        allGuildSkillData[_Profession][_id].config = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.GuildTechnology,"Profession",_Profession,"TechId",_id,"Level",_lv)
    end
end
--重置一种类型的公会技能数据
function this.ResetGuildSkillData(_Profession)
    for i = 1, #allGuildSkillData[_Profession] do
        allGuildSkillData[_Profession][i].level = 0
        allGuildSkillData[_Profession][i].config = ConfigManager.TryGetConfigDataByThreeKey(ConfigName.GuildTechnology,"Profession",_Profession,"TechId",i,"Level",0)
    end
end
--获取所有公会技能总等级
function this.GetAllGuildSkillLv(_Profession)
    local endLv = 0
    local maxLv = allGuildSkillData[_Profession][1].level
    local isEqualityLv = true
    for i = 1, #allGuildSkillData[_Profession] do
        endLv = endLv + allGuildSkillData[_Profession][i].level
        if maxLv ~= allGuildSkillData[_Profession][i].level then
            isEqualityLv = false
        end
        if maxLv < allGuildSkillData[_Profession][i].level then
            maxLv = allGuildSkillData[_Profession][i].level
        end
    end
    return endLv,isEqualityLv,maxLv
end
--获取所有返还材料
function this.GetResetGetDrop(_Profession)
    local drop = {}
    for i = 1, #allGuildSkillData[_Profession] do
        for _, configInfo in ConfigPairs(guildTechnology) do
            if configInfo.Profession == _Profession and configInfo.TechId == i and configInfo.Level < allGuildSkillData[_Profession][i].level then
                for j = 1, #configInfo.Consume do
                    if drop[configInfo.Consume[j][1]] then
                        drop[configInfo.Consume[j][1]].num =  drop[configInfo.Consume[j][1]].num + configInfo.Consume[j][2]
                    else
                        drop[configInfo.Consume[j][1]] = {id = configInfo.Consume[j][1],num = configInfo.Consume[j][2]}
                    end
                end
            end
        end

    end
    local drop2 = {}
    for i, v in pairs(drop) do
        v.num = math.floor(v.num * ConfigManager.GetConfigData(ConfigName.SpecialConfig,46).Value/10000)
        table.insert(drop2, v)
    end
    return drop2
end
--计算该定位的英雄加成
function this.HeroCalculateGuildSkillWarForce(_Profession)
    local addAllProVal={}
    for i = 1, #allGuildSkillData[_Profession] do
        local config = allGuildSkillData[_Profession][i].config
        if config.Values then
            if config.Values[2] > 0 then
                if addAllProVal[config.Values[1]] then
                    addAllProVal[config.Values[1]]=addAllProVal[config.Values[1]]+config.Values[2]
                else
                    addAllProVal[config.Values[1]]=config.Values[2]
                end
            end
        end
    end
    return addAllProVal
end
--公会技能红点
--设置所有技能红点数据
function this.SetAllGuildSkillRedPlayers()
    for i = 1, #GuildSkillType do
        this.SetGuildSkillRedPlayers(i,0)
    end
end
--刷新方法
function this.RefreshAllGuildSkillRedPoint()
    for i = 1, #GuildSkillType do
        local isShowRedPoint = this.GuildSkillRedPoint(i)
        if isShowRedPoint then
            return true
        end
    end
    return false
end
--1 已经查看过不需要显示新红点  0 显示红点
function this.SetGuildSkillRedPlayers(GuildSkillIndex,val)
    PlayerPrefs.SetInt(PlayerManager.uid..GuildSkillType[GuildSkillIndex], val)
end
function this.GuildSkillRedPoint(GuildSkillIndex)
    if not PlayerManager.familyId or PlayerManager.familyId == 0 then
        return false--未加入公会
    end
    
    local isShowRedPoint = PlayerPrefs.GetInt(PlayerManager.uid..GuildSkillType[GuildSkillIndex], 0)
    if isShowRedPoint == 1 then
        return false--已点击过页签
    end
    local allSkillData = GuildSkillManager.GetSkillDataByType(GuildSkillIndex)
    local curSeletSkill = allSkillData[1]
    local isMaxLv = true
    for i = 1, #allSkillData do
        if curSeletSkill.level > allSkillData[i].level then
            curSeletSkill = allSkillData[i]
            isMaxLv = false
        end
    end
    local allCurSkillConfig = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.GuildTechnology,"Profession",GuildSkillIndex,"TechId",curSeletSkill.id)
    if isMaxLv and curSeletSkill.level ~= #allCurSkillConfig - 1 then
        isMaxLv = false
    end
    if isMaxLv then
        return false --满级了
    end
    local isMaterial = true
    if curSeletSkill.config.Consume then
        for i = 1, #curSeletSkill.config.Consume do
            local itemData = curSeletSkill.config.Consume[i]
            if BagManager.GetItemCountById(itemData[1]) < itemData[2] then
                isMaterial = false
            end
        end
    end
    if isShowRedPoint == 0 and isMaterial then--1 已经查看过不需要显示新红点  0 显示红点
        return true
    end
    return false
end
return this