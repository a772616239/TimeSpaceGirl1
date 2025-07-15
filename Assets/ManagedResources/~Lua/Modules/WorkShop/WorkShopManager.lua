WorkShopManager = {}
local this = WorkShopManager
local GameSetting=ConfigManager.GetConfig(ConfigName.GameSetting)
local WorkShopEquipmentConfig = ConfigManager.GetConfig(ConfigName.WorkShopEquipmentConfig)
local WorkShopFoundationConfig = ConfigManager.GetConfig(ConfigName.WorkShopFoundationConfig)
local WorkShopRebuildConfig = ConfigManager.GetConfig(ConfigName.WorkShopRebuildConfig)
local WorkShopSetting=ConfigManager.GetConfig(ConfigName.WorkShopSetting)
local ItemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local EquipConfig=ConfigManager.GetConfig(ConfigName.EquipConfig)
local workShopTechnology=ConfigManager.GetConfig(ConfigName.WorkShopTechnology)
this.WorkShopData={}
this.FoodShopData={}
local lantuData={}--蓝图
this.unDetermined={}--待确认重铸装备
this.WorkShopTreeSinglePointLvEnd = {}--天赋树的每个天赋点等级上限
this.WorkShopTreeRefreshNum = 0--天赋树刷新次数
function this.Initialize()

end
--初始化装备数据
function this.InitWorkShopData(_msgData)--
    --待确认重铸装备
    this.unDetermined=_msgData.unDetermined
    --蓝图
 lantuData={}
    for i = 1, #_msgData.workShopUnLockInfo do
            for j = 1, #_msgData.workShopUnLockInfo[i].id do
                lantuData[_msgData.workShopUnLockInfo[i].id[j]]=WorkShopEquipmentConfig[_msgData.workShopUnLockInfo[i].id[j]].OpenRules[2]
            end
    end
    --工坊 基础信息
    for i = 1, #_msgData.workShopBaseInfo do
        if _msgData.workShopBaseInfo[i].type==1 then
            this.WorkShopData.lv=_msgData.workShopBaseInfo[i].levle
          elseif _msgData.workShopBaseInfo[i].type==2 then
            this.FoodShopData.exp=_msgData.workShopBaseInfo[i].exp
            this.FoodShopData.lv=_msgData.workShopBaseInfo[i].levle
        end
    end
    this.WorkShopData.maxLv=this.GetWorkShopMaxLv()
    this.WorkShopData.shopDraw=GameSetting[1].WorkShopDraw
    this.WorkShopData.welcomeStrList= string.split(GameSetting[1].WorkShopWelcome, "#")
    --天赋树
    this.WorkShopData.TechnologyDataList={}
    this.InitializeTechnologyDataList(_msgData.technologyInfo)
    --武器打造  防具打造
    this.WorkShopData.WorkShopEquipmenConfig={}
    for i, v in ConfigPairs(WorkShopEquipmentConfig) do
        if v.Type==1 then
            local curWorkShopEquipmendata={}
            curWorkShopEquipmendata.workShopData=v
            curWorkShopEquipmendata.itemData=EquipConfig[curWorkShopEquipmendata.workShopData.Id]
            if curWorkShopEquipmendata.itemData==nil then
            end
            curWorkShopEquipmendata.itemConfigData=ItemConfig[curWorkShopEquipmendata.workShopData.Id]
            curWorkShopEquipmendata.active=2--2  未解锁  1 已解锁
            curWorkShopEquipmendata.redPoint=false--2  未解锁  1 已解锁
            if lantuData then
                if lantuData[curWorkShopEquipmendata.workShopData.Id] then
                    curWorkShopEquipmendata.active=1
                    local time = tonumber(RedPointManager.PlayerPrefsGetStr("WorkShop"..curWorkShopEquipmendata.workShopData.Id))
                    
                    if time == 0 then
                        curWorkShopEquipmendata.redPoint = true
                    end
                end
            end
            if curWorkShopEquipmendata.workShopData.OpenRules[1] == 1 then
                if this.WorkShopData.lv >= curWorkShopEquipmendata.workShopData.OpenRules[2] then
                    curWorkShopEquipmendata.active=1
                    local time = tonumber(RedPointManager.PlayerPrefsGetStr("WorkShop"..curWorkShopEquipmendata.workShopData.Id))
                    
                    if time == 0 then
                        curWorkShopEquipmendata.redPoint = true
                    end
                end
            end
            table.insert(this.WorkShopData.WorkShopEquipmenConfig,curWorkShopEquipmendata)
        end
    end
    --装备洗练
    this.WorkShopData.WorkShopRebuildConfig={}
    for i, v in ConfigPairs(WorkShopRebuildConfig) do
        table.insert(this.WorkShopData.WorkShopRebuildConfig,v)
    end
    --工坊等级对装备主属性的加成的值
    this.WorkShopData.LvAddMainIdAndVales={}
    this.WorkShopData.LvAddMainIdAndVales=this.FunctionLvAddMainIdAndVales()
end
--工坊等级对装备主属性的加成的值
function this.FunctionLvAddMainIdAndVales()
    local LvAddMainIdAndVales={}
    for i, v in ConfigPairs(WorkShopSetting) do
        if this.WorkShopData.lv >= v.Id and v.Id~=0 then
            LvAddMainIdAndVales[v.Promote[1]]=v.Promote[2]
        end
    end
    return LvAddMainIdAndVales
end
--更新工坊等级经验
function this.UpdataWorkShopLvAndExp()
    this.WorkShopData.lv = this.WorkShopData.lv+1
    Game.GlobalEvent:DispatchEvent(GameEvent.WorkShow.WorkShopLvChange)
    this.WorkShopData.LvAddMainIdAndVales=this.FunctionLvAddMainIdAndVales()
    this.UpdataWorkShopUpLvActiveState()
end
--更新武器 防具打造  蓝图激活
function this.UpdataWorkShopLanTuActiveState(_proTypeId,_workShopId,_itemId)
    if _proTypeId<=1 then
        for i = 1, #this.WorkShopData.FoundationConfig do
            if this.WorkShopData.FoundationConfig[i].workShopData.Id==_workShopId  then
                this.WorkShopData.FoundationConfig[i].active=1
                this.WorkShopData.FoundationConfig[i].redPoint = true
                lantuData[_workShopId]=_itemId
            end
        end
    else
        for i = 1, #this.WorkShopData.WorkShopEquipmenConfig do
            if this.WorkShopData.WorkShopEquipmenConfig[i].workShopData.Id==_workShopId  then
                this.WorkShopData.WorkShopEquipmenConfig[i].active=1
                this.WorkShopData.WorkShopEquipmenConfig[i].redPoint = true
                lantuData[_workShopId]=_itemId
            end
        end
    end
    CheckRedPointStatus(RedPointType.Refining_Weapon)
    CheckRedPointStatus(RedPointType.Refining_Armor)
end
--更新武器 防具打造  工坊升级
function this.UpdataWorkShopUpLvActiveState()
        for i = 1, #this.WorkShopData.WorkShopEquipmenConfig do
            if this.WorkShopData.WorkShopEquipmenConfig[i].workShopData.OpenRules[1] == 1  then
                if this.WorkShopData.WorkShopEquipmenConfig[i].workShopData.OpenRules[2] == this.WorkShopData.lv  then
                    this.WorkShopData.WorkShopEquipmenConfig[i].active=1
                    this.WorkShopData.WorkShopEquipmenConfig[i].redPoint = true
                end
            end
        end
    CheckRedPointStatus(RedPointType.Refining_Weapon)
    CheckRedPointStatus(RedPointType.Refining_Armor)
end
--更新武器 防具打造  红点状态 false
function this.UpdataWorkShopRedPointState(_proTypeId,_workShopId)
    if _proTypeId<=1 then
        for i = 1, #this.WorkShopData.FoundationConfig do
            if this.WorkShopData.FoundationConfig[i].workShopData.Id==_workShopId  then
                this.WorkShopData.FoundationConfig[i].redPoint = false
            end
        end
    else
        for i = 1, #this.WorkShopData.WorkShopEquipmenConfig do
            if this.WorkShopData.WorkShopEquipmenConfig[i].workShopData.Id==_workShopId  then
                this.WorkShopData.WorkShopEquipmenConfig[i].redPoint = false
            end
        end
    end
    CheckRedPointStatus(RedPointType.Refining_Weapon)
    CheckRedPointStatus(RedPointType.Refining_Armor)
end
--获取工坊最大等级
function this.GetWorkShopMaxLv()
    return #GameDataBase.SheetBase.GetKeys(WorkShopSetting)-1
end
--获取工坊最大等级
function this.GetWorkShopCurLvExp(_lv)
    return WorkShopSetting[_lv].Exp
end
--获取工坊页签数据    _type   _proId  _tabsId
function this.GetWorkShopData(_type,_proId,_tabsId)
    if _type==1 then--工坊
        local workShopInfos={}
        if _proId==1 then
            for i = 1, #this.WorkShopData.FoundationConfig do
                if this.WorkShopData.FoundationConfig[i].workShopData.Sheet==_tabsId  then
                   table.insert(workShopInfos,this.WorkShopData.FoundationConfig[i])
                end
            end
        elseif _proId==2 then
            for i = 1, #this.WorkShopData.WorkShopEquipmenConfig do
                if this.WorkShopData.WorkShopEquipmenConfig[i].workShopData.Type==1  then--工坊
                    if this.WorkShopData.WorkShopEquipmenConfig[i].workShopData.FunctionStyle==1  then--武器打造 防具打造在一起
                        if this.WorkShopData.WorkShopEquipmenConfig[i].itemData.ProfessionLimit==_tabsId or  this.WorkShopData.WorkShopEquipmenConfig[i].itemData.ProfessionLimit==0 then
                            table.insert(workShopInfos,this.WorkShopData.WorkShopEquipmenConfig[i])
                        end
                    end
                end
            end
        elseif _proId==3 then
            for i = 1, #this.WorkShopData.WorkShopEquipmenConfig do
                if this.WorkShopData.WorkShopEquipmenConfig[i].workShopData.Type==1  then--工坊
                    if this.WorkShopData.WorkShopEquipmenConfig[i].workShopData.FunctionStyle==2  then--武器打造 防具打造在一起
                        if this.WorkShopData.WorkShopEquipmenConfig[i].itemData.Position==_tabsId or  this.WorkShopData.WorkShopEquipmenConfig[i].itemData.Position==0 then
                            table.insert(workShopInfos,this.WorkShopData.WorkShopEquipmenConfig[i])
                        end
                    end
                end
            end
        elseif _proId==4 then
        end
        table.sort(workShopInfos, function(a,b)
            if a.active == b.active then
                if a.itemData.Quality == b.itemData.Quality  then
                    return a.workShopData.Id < b.workShopData.Id
                else
                    return a.itemData.Quality < b.itemData.Quality
                end
            else
                return a.active < b.active
            end
        end)
        return workShopInfos
    elseif _type==2 then--百味居

    end

end
--背包获取蓝图是否已解锁
function this.GetLanTuIsOpenLock(_lanTuSId)--返回true时 表示蓝图已解锁 直接显示分解  false时 并返回 工坊条目id
    local lantuIsOpenData={}
    for k,v in pairs(lantuData) do
        if v==_lanTuSId then
            table.insert(lantuIsOpenData,true)
            for i2, v2 in ConfigPairs(WorkShopEquipmentConfig) do
                if v2.OpenRules[2]==_lanTuSId then
                    table.insert(lantuIsOpenData, i2)
                    return lantuIsOpenData
                end
            end
        end
    end
    for i, v in ConfigPairs(WorkShopEquipmentConfig) do
        if v.OpenRules[2]==_lanTuSId then
            table.insert(lantuIsOpenData,false)
            table.insert(lantuIsOpenData, i)
            return lantuIsOpenData
        end
    end
end

--检测武器、防具 打造的红点
function this.GetWorkShopRedPointState(_proTypeId)--1 武器打造 2 防具打造
    if _proTypeId == 1060 then
        _proTypeId = 1
        if ActTimeCtrlManager.SingleFuncState(102) == false then
            return false
        end
    else
        _proTypeId = 2
        if ActTimeCtrlManager.SingleFuncState(103) == false then
            return false
        end
    end
    for i = 1, #this.WorkShopData.WorkShopEquipmenConfig do
        if this.WorkShopData.WorkShopEquipmenConfig[i].workShopData.Type==1  then--工坊
            if this.WorkShopData.WorkShopEquipmenConfig[i].workShopData.FunctionStyle==_proTypeId  then--武器打造 防具打造在一起
                if this.WorkShopData.WorkShopEquipmenConfig[i].redPoint then
                    
                    return true
                end
            end
        end
    end
    
    return false
end

--初始化天赋树
function this.InitializeTechnologyDataList(backTechnologyInfo)
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.WorkShopTechnologySetting)) do
        local curPosTechnologyData = {}--每个职业
        for j = 1, #v.RankNum do
            local curHierarchyTechnologyData = {}--每个层
            curHierarchyTechnologyData.Limitate = v.Limitate[j]
            for k = 1, #v.TechIdGroup[j] do
                local curTechnologyData = {}--每个技能点
                curTechnologyData.id = v.TechIdGroup[j][k]
                curTechnologyData.icon = v.IconGroup[j][k]
                curTechnologyData.Limitate = v.Limitate[j]
                curTechnologyData.conFigData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.WorkShopTechnology, "TechId", curTechnologyData.id, "Level", 0)
                curTechnologyData.openState = false
                table.insert(curHierarchyTechnologyData,curTechnologyData)
            end
            table.insert(curPosTechnologyData,curHierarchyTechnologyData)
        end
        table.insert(this.WorkShopData.TechnologyDataList,curPosTechnologyData)
    end
    if backTechnologyInfo then
        for h = 1, #backTechnologyInfo do
            for i = 1, #this.WorkShopData.TechnologyDataList do
                local curTechnologyDataList = this.WorkShopData.TechnologyDataList[i]
                for j = 1, #curTechnologyDataList do
                    local curTechnologyData = curTechnologyDataList[j]
                    for k = 1, #curTechnologyData do
                        local cursingleTechnologyData = curTechnologyData[k]
                        if backTechnologyInfo[h].techId == cursingleTechnologyData.id then
                            cursingleTechnologyData.conFigData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.WorkShopTechnology, "TechId", cursingleTechnologyData.id, "Level", backTechnologyInfo[h].levle)
                        end
                    end
                end
            end
        end
    end
    this.SetTreePointOpenState()
    this.GetAllTreeLvEndNum()

    local goods = ShopManager.GetShopItemData(SHOP_TYPE.FUNCTION_SHOP, 10011)
    if goods then
        this.WorkShopTreeRefreshNum = goods.buyNum
    else
        this.WorkShopTreeRefreshNum = 0
    end

end
--增加天赋树刷新次数
function this.SetTreeRefreshNum(_num)
    this.WorkShopTreeRefreshNum = this.WorkShopTreeRefreshNum + _num
end
--获取单个职业天赋书所有数据
function this.GetTreeCurHeroPosAllData(_heroPos)
    return  this.WorkShopData.TechnologyDataList[_heroPos]
end
--设置单个天赋点等级
function this.SetHeroPosTreeSingleDataLV(techId,lv)
    for i = 1, #this.WorkShopData.TechnologyDataList do
        local curTechnologyDataList = this.WorkShopData.TechnologyDataList[i]
        for j = 1, #curTechnologyDataList do
            local curTechnologyData = curTechnologyDataList[j]
            for k = 1, #curTechnologyData do
                local cursingleTechnologyData = curTechnologyData[k]
                if techId == cursingleTechnologyData.id then
                    cursingleTechnologyData.conFigData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.WorkShopTechnology, "TechId", cursingleTechnologyData.id, "Level", lv)
                end
            end
        end
    end
end
--设置单个天赋点等级
function this.SetHeroPosTreeSingleDataOpenState(techId,OpenState)
    for i = 1, #this.WorkShopData.TechnologyDataList do
        local curTechnologyDataList = this.WorkShopData.TechnologyDataList[i]
        for j = 1, #curTechnologyDataList do
            local curTechnologyData = curTechnologyDataList[j]
            for k = 1, #curTechnologyData do
                local cursingleTechnologyData = curTechnologyData[k]
                if techId == cursingleTechnologyData.id then
                    cursingleTechnologyData.openState = OpenState
                end
            end
        end
    end
end
--获取单个天赋点等级
function this.GetHeroPosTreeSingleData(techId)
    for i = 1, #this.WorkShopData.TechnologyDataList do
        local curTechnologyDataList = this.WorkShopData.TechnologyDataList[i]
        for j = 1, #curTechnologyDataList do
            local curTechnologyData = curTechnologyDataList[j]
            for k = 1, #curTechnologyData do
                local cursingleTechnologyData = curTechnologyData[k]
                if techId == cursingleTechnologyData.id then
                    return cursingleTechnologyData.conFigData.Level
                end
            end
        end
    end
end
--获取单个天赋点
function this.GetSingleTreeData(techId)
    for i = 1, #this.WorkShopData.TechnologyDataList do
        local curTechnologyDataList = this.WorkShopData.TechnologyDataList[i]
        for j = 1, #curTechnologyDataList do
            local curTechnologyData = curTechnologyDataList[j]
            for k = 1, #curTechnologyData do
                local cursingleTechnologyData = curTechnologyData[k]
                if techId == cursingleTechnologyData.id then
                    return cursingleTechnologyData
                end
            end
        end
    end
end
--重置单个职业所有天赋点
function this.RefreshCurHeroPosTreeAllData(professionId)
    local curTechnologyDataList = this.WorkShopData.TechnologyDataList[professionId]
    for j = 1, #curTechnologyDataList do
        local curTechnologyData = curTechnologyDataList[j]
        for k = 1, #curTechnologyData do
            local cursingleTechnologyData = curTechnologyData[k]
            cursingleTechnologyData.openState = false
            cursingleTechnologyData.conFigData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.WorkShopTechnology, "TechId", cursingleTechnologyData.id, "Level", 0)
        end
    end
end
--获取此职业科技书是否升过级
function this.GetCurHeroPosTreeHaveData(professionId)
    local curTechnologyDataList = this.WorkShopData.TechnologyDataList[professionId]
    for j = 1, #curTechnologyDataList do
        local curTechnologyData = curTechnologyDataList[j]
        for k = 1, #curTechnologyData do
            local cursingleTechnologyData = curTechnologyData[k]
            if cursingleTechnologyData then
                if  cursingleTechnologyData.conFigData.Level > 0 then
                    return true
                end
            end
        end
    end
    return false
end
--计算战斗力
function  this.HeroCalculateTreeWarForce(_heroPos)
    local addAllProVal={}
    if this.WorkShopData and this.WorkShopData.TechnologyDataList then
        local curTechnologyDataList =  this.WorkShopData.TechnologyDataList[_heroPos]
        for j = 1, #curTechnologyDataList do
            local curTechnologyData = curTechnologyDataList[j]
            for k = 1, #curTechnologyData do
                local cursingleTechnologyData = curTechnologyData[k]
                if cursingleTechnologyData.conFigData and cursingleTechnologyData.conFigData.Values then
                    for i = 1, #cursingleTechnologyData.conFigData.Values do
                        local proId = cursingleTechnologyData.conFigData.Values[i][1]
                        local proVal = cursingleTechnologyData.conFigData.Values[i][2]
                        if proVal > 0 then
                            if addAllProVal[proId] then
                                addAllProVal[proId]=addAllProVal[proId]+proVal
                            else
                                addAllProVal[proId]=proVal
                            end
                        end
                    end
                end
            end
        end
    end
    return addAllProVal
end
--计算天赋树战斗力
function  this.CalculateTreeWarForce(_heroPos)
    local addAllProVal={}
    local curTechnologyDataList =  this.WorkShopData.TechnologyDataList[_heroPos]
    for j = 1, #curTechnologyDataList do
        local curTechnologyData = curTechnologyDataList[j]
        for k = 1, #curTechnologyData do
            local cursingleTechnologyData = curTechnologyData[k]
            if cursingleTechnologyData.conFigData and cursingleTechnologyData.conFigData.Values then
                for i = 1, #cursingleTechnologyData.conFigData.Values do
                    local proId = cursingleTechnologyData.conFigData.Values[i][1]
                    local proVal = cursingleTechnologyData.conFigData.Values[i][2]
                    if addAllProVal[proId] then
                        addAllProVal[proId]=addAllProVal[proId]+proVal
                    else
                        addAllProVal[proId]=proVal
                    end
                end
            end
        end
    end
    local powerEndVal=0
    for i, v in pairs(addAllProVal) do
        if v>0 then
            local curProConfigData = ConfigManager.GetConfigData(ConfigName.PropertyConfig,i)
            if curProConfigData then
                if curProConfigData.Style == 1 then
                    powerEndVal=powerEndVal+v*HeroManager.heroPropertyScore[i]
                else
                    powerEndVal=powerEndVal+v/10000*HeroManager.heroPropertyScore[i]
                end
            end
        end
    end
    return math.floor(powerEndVal)
end
--计算每个天赋点等级上限
function this.GetAllTreeLvEndNum()
    for i, v in ConfigPairs(workShopTechnology) do
        if this.WorkShopTreeSinglePointLvEnd[v.TechId] then
            if this.WorkShopTreeSinglePointLvEnd[v.TechId] < v.Level then
                this.WorkShopTreeSinglePointLvEnd[v.TechId] = v.Level
            end
        else
            this.WorkShopTreeSinglePointLvEnd[v.TechId] = v.Level
        end
    end
end
--
function this.SetTreePointOpenState()
    for i = 1, #this.WorkShopData.TechnologyDataList do
        local curTechnologyDataList = this.WorkShopData.TechnologyDataList[i]
        for j = 1, #curTechnologyDataList do
            local curTechnologyData = curTechnologyDataList[j]
            for k = 1, #curTechnologyData do
                local cursingleTechnologyData = curTechnologyData[k]
                if cursingleTechnologyData.conFigData and cursingleTechnologyData.conFigData.OpenRules and cursingleTechnologyData.conFigData.OpenRules[1] then
                    local curNeedLv  = WorkShopManager.GetHeroPosTreeSingleData(cursingleTechnologyData.conFigData.OpenRules[1])
                    if curNeedLv then
                        if cursingleTechnologyData.conFigData.Level > 0 or curNeedLv >= cursingleTechnologyData.conFigData.OpenRules[2] then--已开启
                            cursingleTechnologyData.openState = true
                        end
                    end
                end
            end
        end
    end
end
return this