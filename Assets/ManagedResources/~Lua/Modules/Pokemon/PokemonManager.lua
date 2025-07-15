PokemonManager = {}
local this = PokemonManager
local spiritAnimal = ConfigManager.GetConfig(ConfigName.SpiritAnimal)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local spiritAnimalBook = ConfigManager.GetConfig(ConfigName.SpiritAnimalBook)
local pokemons = {}--灵兽数据
local pokemonFetter = {}--灵兽羁绊
local pokemonFormation = {}--灵兽编队
local pokemonGet = {} --已经获得过的灵兽
function this.Initialize()
    pokemonFormation = {}
    for i = 1, 6 do
        local teamInfo = {}
        teamInfo.pokemonId = nil
        teamInfo.position = i
        table.insert(pokemonFormation, teamInfo)
    end
    Game.GlobalEvent:AddEvent(GameEvent.Pokemon.PokemonChipRefresh, this.PokemonChipRefresh)
end
---------------------------------------------
--初始化灵兽数据
---------------------------------------------
function this.InitPokemonsData(_msgPokemonList)
    
    pokemons = {}
    for i = 1, #_msgPokemonList do
        this.UpdatePokemonDatas(_msgPokemonList[i])
    end
end

--刷新本地数据v   掉落时调用
function this.UpdatePokemonDatas(_msgPokemonData,isRefreshFetter)--单个掉落时 需要检测是否激活羁绊isRefreshFetter
    -- if true then
    --     return
    -- end
    local singPokemonData = {}
    
    singPokemonData.heroBackData = _msgPokemonData
    singPokemonData.id = _msgPokemonData.tempId
    singPokemonData.dynamicId = _msgPokemonData.id
    singPokemonData.star = _msgPokemonData.star
    singPokemonData.lv = _msgPokemonData.level
    if spiritAnimal[singPokemonData.id].Live <= 0 then return end
    singPokemonData.live = GetResourcePath(spiritAnimal[singPokemonData.id].Live)
    singPokemonData.scale = spiritAnimal[singPokemonData.id].Scale
    singPokemonData.position = spiritAnimal[singPokemonData.id].Position
    singPokemonData.config= spiritAnimal[_msgPokemonData.tempId]
    
    pokemons[singPokemonData.dynamicId] = singPokemonData
    if isRefreshFetter then
        this.GetPokemonRefreshFetter(singPokemonData.id)
        CheckRedPointStatus(RedPointType.Pokemon_Fetter)
    end
end

--获取当前灵兽数据
function this.GetSinglePokemonData(_did)
    if not _did then return nil end
    if pokemons[_did] then
       return  pokemons[_did]
    else
        return nil
    end
end
--获取所有灵兽数据
function this.GetPokemonDatas()
    local list = {}
    for k,v in pairs(pokemons) do
        table.insert(list, v)
    end
    -- 排序
    local AllPokemonFormationDids = PokemonManager.GetAllPokemonFormationDids()
    table.sort(list, function(a,b) 
        if AllPokemonFormationDids[a.dynamicId] and AllPokemonFormationDids[b.dynamicId] or not AllPokemonFormationDids[a.dynamicId] and not AllPokemonFormationDids[b.dynamicId]  then
            if spiritAnimal[a.id].Quality == spiritAnimal[b.id].Quality then
                if a.star == b.star then
                    if a.lv == b.lv then
                        return a.id < b.id
                    else
                        return a.lv > b.lv
                    end
                else
                    return a.star > b.star
                end
            else
                return spiritAnimal[a.id].Quality > spiritAnimal[b.id].Quality
            end
        else
            return AllPokemonFormationDids[a.dynamicId] and not AllPokemonFormationDids[b.dynamicId]
        end
    end)
    return list
end
--获取所有灵兽数据
function this.GetPokemonUpZhenDatas()
    local formationUpZhens = {}
    for i = 1, #pokemonFormation do
        if pokemons[pokemonFormation[i].pokemonId] then
            table.insert(formationUpZhens, pokemons[pokemonFormation[i].pokemonId])
        end
    end
    return formationUpZhens
end
--获取所有灵兽数据
function this.GetPokemonResolveDatas()
    local curAllPokemonList = {}
    local list=this.GetAllPokemonFormationDids()
    for key, value in pairs(pokemons) do
        if list and not list[value.dynamicId] then            
        
            table.insert(curAllPokemonList,value)       
        end          
    end
    return curAllPokemonList
end
--移除多个灵兽数据
function this.RemovePokemonData(ids)
if not ids then
    return
end
for i = 1,#ids do
    local id=ids[i]
    this.RemoveSinglePokemonData(id)
end
end
--获取当前可上阵的所有灵兽数据 curUpZhenPokemonData 如果不为空就时替换上阵操作
function this.GetCanUpZhenPokemonDatas(curUpZhenPokemonData)
    local upZhenSidList = this.GetAllPokemonFormationSids()
    local curAllPokemonList = {}
    for key, value in pairs(pokemons) do
        if not upZhenSidList[value.id] then
            table.insert(curAllPokemonList,value)
        end
        if curUpZhenPokemonData then
            if value.id == curUpZhenPokemonData.id and value.dynamicId ~= curUpZhenPokemonData.dynamicId then
                table.insert(curAllPokemonList,value)
            end
        end
    end
    return curAllPokemonList
end
--移除灵兽数据
function this.RemoveSinglePokemonData(_did)
    if not _did then return end
    if pokemons[_did] then
        pokemons[_did] = nil
    end
end
--前端刷新单个灵兽数据
function this.UpdateSinglePokemonData(_did,_lv,_star)
if not _did then return end
if pokemons[_did] then
    pokemons[_did].lv = _lv
    pokemons[_did].star = _star
end
end
--获取当前所有可吞卡灵兽数据
function this.GetNoUpLvPokemonData(_id,_did)
    local curAllPokemonList = {}
    local upZhenDids = this.GetAllPokemonFormationDids()
    for key, value in pairs(pokemons) do
        if not upZhenDids[value.dynamicId] and value.star <= 0 and value.lv <= 1 and value.id == _id and value.dynamicId ~= _did then
            table.insert(curAllPokemonList,value)
        end
    end
    return curAllPokemonList
end
--获取单个灵兽属性   (灵兽属性/编队人数       灵兽属性会平分给上阵的所有神将）
function this.GetSinglePokemonAddProData(_did,_star)--_star 传值的话就用此星级计算属性
    
    if not pokemons[_did] then return end
    
    local addAllProVal = {}
    local curPokeonData = pokemons[_did]
    local curPokemonConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,curPokeonData.id)
    local curPokemonLvConFig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.SpiritAnimalLevel,"Quality",curPokemonConFig.Quality,"Level",curPokeonData.lv)
    local curPokemonStarConFig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.SpiritAnimalStar,"Quality",curPokemonConFig.Quality,"Star",_star and _star or curPokeonData.star)
    --基础
    addAllProVal[HeroProType.Hp] = curPokemonConFig.Hp
    addAllProVal[HeroProType.Attack] = curPokemonConFig.Attack
    addAllProVal[HeroProType.PhysicalDefence] = curPokemonConFig.PhysicalDefence
    addAllProVal[HeroProType.MagicDefence] = curPokemonConFig.MagicDefence
    --升级
    for i = 1, #curPokemonLvConFig.CharacterLevelPara do
        local curPro = curPokemonLvConFig.CharacterLevelPara[i]
        if curPro[2] > 0 then
            if addAllProVal[curPro[1]] then
                addAllProVal[curPro[1]]=addAllProVal[curPro[1]]+curPro[2]
            else
                addAllProVal[curPro[1]]=curPro[2]
            end
        end
    end
    --升星 属性=（基础属性+等级属性）*（1+星级倍率）
    local StarPara = curPokemonStarConFig.StarPara/10000
    local addEndAllProVal = {}
    for key, value in pairs(addAllProVal) do
        addEndAllProVal[key] = math.floor(value * (1 + StarPara)) 
    end
    return addEndAllProVal
end



--获取单个灵兽属性   (灵兽属性/编队人数       灵兽属性会平分给上阵的所有神将）
function this.GetSinglePokemonAddProDataByLvAndStar(_did,_lv,_star)--_star 传值的话就用此星级计算属性
    local addAllProVal = {}
    local curPokemonConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,_did)
    local curPokemonLvConFig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.SpiritAnimalLevel,"Quality",curPokemonConFig.Quality,"Level",_lv)
    local curPokemonStarConFig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.SpiritAnimalStar,"Quality",curPokemonConFig.Quality,"Star",_star)
    --基础
    addAllProVal[HeroProType.Hp] = curPokemonConFig.Hp
    addAllProVal[HeroProType.Attack] = curPokemonConFig.Attack
    addAllProVal[HeroProType.PhysicalDefence] = curPokemonConFig.PhysicalDefence
    addAllProVal[HeroProType.MagicDefence] = curPokemonConFig.MagicDefence
    --升级
    for i = 1, #curPokemonLvConFig.CharacterLevelPara do
        local curPro = curPokemonLvConFig.CharacterLevelPara[i]
        if curPro[2] > 0 then
            if addAllProVal[curPro[1]] then
                addAllProVal[curPro[1]]=addAllProVal[curPro[1]]+curPro[2]
            else
                addAllProVal[curPro[1]]=curPro[2]
            end
        end
    end
    --升星 属性=（基础属性+等级属性）*（1+星级倍率）
    local StarPara = curPokemonStarConFig.StarPara/10000
    local addEndAllProVal = {}
    for key, value in pairs(addAllProVal) do
        addEndAllProVal[key] = value * (1 + StarPara)
    end
    return addEndAllProVal
end

--获取单个灵兽属性   (灵兽属性/编队人数       灵兽属性会平分给上阵的所有神将）
function this.GetSinglePokemonAddProDataBySid(_sid)
    local addAllProVal = {}
    local curPokemonConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,_sid)
    --基础
    addAllProVal[HeroProType.Hp] = curPokemonConFig.Hp
    addAllProVal[HeroProType.Attack] = curPokemonConFig.Attack
    addAllProVal[HeroProType.PhysicalDefence] = curPokemonConFig.PhysicalDefence
    addAllProVal[HeroProType.MagicDefence] = curPokemonConFig.MagicDefence
    return addAllProVal
end

--根据星级获得技能id
function this.GetCurStarSkillId(_sid,_star)
    local curConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,_sid)
    local skillId = nil
    if curConFig then
        for i = 1, #curConFig.SkillArray do
            if curConFig.SkillArray[i][1] == _star then
                skillId = curConFig.SkillArray[i][2]
            end
        end
    end
    return skillId
end


---------------------------------------------
--灵兽羁绊   (羁绊属性直接就是团队属性)
---------------------------------------------
function this.InitPokemonsGetrData(_msgPokemonGetList)
    
    pokemonGet = {}
    
    for i = 1, #_msgPokemonGetList do
        
        pokemonGet[_msgPokemonGetList[i]] = _msgPokemonGetList[i]
    end
end

function this.InitPokemonsFetterData(_msgPokemonFetterList)
    
    pokemonFetter = {}
    if not _msgPokemonFetterList then
        return
    end
    for i = 1, #_msgPokemonFetterList do
        this.UpdatePokemonFetterDatas(_msgPokemonFetterList[i])
    end
end

--刷新本地灵兽羁绊数据
function this.UpdatePokemonFetterDatas(_msgPokemonFetter)
    local singPokemonFetterData = {}
    pokemonFetter[_msgPokemonFetter] = _msgPokemonFetter
end

function this.GetAllPokemonFetterDatas()
    local SpiritAnimalBookList = {}
    local singPokemonFetterData = {}
    local curPokemonSidList = this.GetAllPokemonGetDatas()
    for k,v in ConfigPairs(ConfigManager.GetConfig(ConfigName.SpiritAnimalBook)) do
        local singPokemonFetterData = {}
        singPokemonFetterData.id = v.Id
        if pokemonFetter and pokemonFetter[singPokemonFetterData.id] then
            singPokemonFetterData.enabled = 1--已经激活的
        elseif this.IsCompound(v.Teamers,curPokemonSidList) then
            singPokemonFetterData.enabled = 0--可以激活的
        else
            singPokemonFetterData.enabled = -1--不能激活的
        end 
        table.insert(SpiritAnimalBookList,singPokemonFetterData)
    end
    
    return SpiritAnimalBookList
end

function this.GetAllPokemonGetDatas()
    return pokemonGet
end

--判断是否激活新的灵兽羁绊数据
function this.GetPokemonRefreshFetter(_sid)
    if pokemonGet[_sid] then
        return
    end
    pokemonGet[_sid] = _sid    
end

--获取所有的灵兽种类
function this.GetCurPokemonSidList()
    local curPokemonSidList = {}
    for key, value in pairs(pokemons) do
        curPokemonSidList[value.id] = value
    end
    return curPokemonSidList
end

--获取所有灵兽羁绊总和属性   (羁绊属性直接加在团队属性上）
function this.GetAllPokemonFetterAddPros()
    local addAllProVal = {}
    for key, value in pairs(pokemonFetter) do
        local curspiritAnimalBook = spiritAnimalBook[key]
        if curspiritAnimalBook and #curspiritAnimalBook.ActivePara > 0 then
            for i = 1, #curspiritAnimalBook.ActivePara do
                local curPro = curspiritAnimalBook.ActivePara[i]
                if curPro[2] > 0 then
                    if addAllProVal[curPro[1]] then
                        addAllProVal[curPro[1]]=addAllProVal[curPro[1]]+curPro[2]
                    else
                        addAllProVal[curPro[1]]=curPro[2]
                    end
                end
            end
        end
    end
    return addAllProVal
end
----获取所有灵兽羁绊总和静态战力
function this.GetAllPokemonFetterAddProsSWarPower()
    local addPowerVal = 0
    for key, value in pairs(pokemonFetter) do
        local curspiritAnimalBook = spiritAnimalBook[key]
        if curspiritAnimalBook and curspiritAnimalBook.ActiveForce > 0 then
            addPowerVal = addPowerVal + curspiritAnimalBook.ActiveForce
        end
    end
    return addPowerVal
end

---------------------------------------------
--灵兽编队
---------------------------------------------

--刷新本地灵兽编队数据
function this.UpdatePokemonFormationDatas(_msgPokemonFormationList)
    
    if not _msgPokemonFormationList then
        return
    end
    for i = 1, #_msgPokemonFormationList do
        
        pokemonFormation[_msgPokemonFormationList[i].position].pokemonId = _msgPokemonFormationList[i].pokemonId
    end
end
--获取变队形信息
function this.GetAllPokemonFormationData()
    -- for i = 1, #pokemonFormation do
    --     if pokemonFormation[i].pokemonId then
    
    --     end
    -- end
    return pokemonFormation
end
--获取编队灵兽静态id list
function this.GetAllPokemonFormationSids()
    local formationSids = {}
    for i = 1, #pokemonFormation do
        if pokemons[pokemonFormation[i].pokemonId] then
            formationSids[pokemons[pokemonFormation[i].pokemonId].id] = pokemons[pokemonFormation[i].pokemonId]
        end
    end
    return formationSids
end
--获取编队灵兽动态id list
function this.GetAllPokemonFormationDids()
    local formationDids = {}
    for i = 1, #pokemonFormation do
        if pokemons[pokemonFormation[i].pokemonId] then
            formationDids[pokemonFormation[i].pokemonId] = pokemonFormation[i]
        end
    end
    return formationDids
end
--获取灵兽编队属性
function this.GetPokemonFormationAddPro()
    local allPro = {}
    for key, value in pairs(pokemonFormation) do
        if value.pokemonId and pokemons[value.pokemonId] then
            local curPokemonAddPro = this.GetSinglePokemonAddProData(value.pokemonId)
            HeroManager.DoubleTableCompound(allPro, curPokemonAddPro)
        end
    end
    return allPro
end

--获取灵兽编队属性 在编队中的团队属性加成  除以英雄编队人数
function this.GetPokemonFormationTeamAddPro(heroFormationNum)
    local allPro = this.GetPokemonFormationAddPro()
    -- local formationHeros = FormationManager.GetWuJinFormationHeroIds(formationIndex) 
    -- local heroFormationNum = #formationHeros
    for key, value in pairs(allPro) do
        allPro[key] = math.floor(value/heroFormationNum)
    end
    return allPro
end

--刷新编队信息 type 1 上阵  2  下阵 3 替换（上阵）
function this.RefreshPokemonFormation(_pokemonFormation)
    for i = 1, #pokemonFormation do
        if _pokemonFormation[i] and _pokemonFormation[i].pokemonId then
            if i ==  _pokemonFormation[i].position then
                
                pokemonFormation[i].pokemonId = _pokemonFormation[i].pokemonId
            end
        end
    end
end

function this.PiaoWarPowerChange(oldWarPower,newWarPower)
    --飘战力
    
    -- if oldWarPower ~= newWarPower then
    --     UIManager.OpenPanel(UIName.WarPowerChangeNotifyPanelV2,{oldValue = oldWarPower,newValue = newWarPower})--,pos=Vector3.New(-467,837.2),duration=0.7,isShowBg=false,isShowOldNum=false,pivot=Vector2.New(0,0.5)})
    -- end
    RefreshPower(oldWarPower, newWarPower)
end


---------------------------------------------
--红点检测
---------------------------------------------
--灵兽红点检测方法
function this.CheckRedPointStatusPokemonMainCityRed()
    
    CheckRedPointStatus(RedPointType.Pokemon_UpLv)
    CheckRedPointStatus(RedPointType.Pokemon_UpStar)
    CheckRedPointStatus(RedPointType.Pokemon_CanUpZhen)
    CheckRedPointStatus(RedPointType.Pokemon_ChipCompound)
    CheckRedPointStatus(RedPointType.Pokemon_Fetter)
    CheckRedPointStatus(RedPointType.Pokemon_Recruit)
end 
--上阵灵兽升级红点
function this.RefreshPokemonUpLvRedPoint()
    local isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.POKEMON)
    if not isOpen then
        return false
    end
    for i = 1, #pokemonFormation do
        if pokemonFormation[i] and pokemonFormation[i].pokemonId then
            local curPokemonData = pokemons[pokemonFormation[i].pokemonId]
            if curPokemonData then
                local singlePokemonPoint = this.GetSinglePokemonUpLvRedPoint(curPokemonData)
                if singlePokemonPoint then
                    
                    return true
                end
            end
        end
    end
    
    return false
end
--上阵灵兽升级红点2
function this.GetSinglePokemonUpLvRedPoint(curPokemonData)
    local pokemonConFig = spiritAnimal[curPokemonData.id]
    local upLvConFig = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.SpiritAnimalLevel,"Quality",pokemonConFig.Quality,"Level",curPokemonData.lv)
    if curPokemonData.lv < pokemonConFig.MaxLevel then
        local canUpLv = true
        for j = 1, #upLvConFig.Consume do
            local curMaterialBagNum = BagManager.GetItemCountById(upLvConFig.Consume[j][1])
            if curMaterialBagNum < upLvConFig.Consume[j][2] then
                canUpLv = false
            end
        end
        if canUpLv then
            return true
        end
    end
    return false
end
--上阵灵兽升星红点
function this.RefreshPokemonUpStarRedPoint()
    local isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.POKEMON)
    if not isOpen then
        return false
    end
    for i = 1, #pokemonFormation do
        if pokemonFormation[i] and pokemonFormation[i].pokemonId then
            local curPokemonData = pokemons[pokemonFormation[i].pokemonId]
            local singlePokemonPoint = this.GetSinglePokemonUpStarRedPoint(curPokemonData)
                if singlePokemonPoint then
                    
                    return true
                end
        end
    end
    
    return false
end
--上阵灵兽升星红点2
function this.GetSinglePokemonUpStarRedPoint(curPokemonData)
    if curPokemonData and curPokemonData.star < spiritAnimal[curPokemonData.id].MaxStar then
        local curUpStarConfig = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.SpiritAnimalStar,"Quality", spiritAnimal[curPokemonData.id].Quality, "Star", curPokemonData.star)
        if curUpStarConfig then
            local upStarMaterialsData = {{curPokemonData.id,curUpStarConfig.ConsumeItemNum}}
            for j = 1, #curUpStarConfig.ConsumeRes do
                table.insert(upStarMaterialsData,curUpStarConfig.ConsumeRes[j])
            end
            local isCanUpStar = true
            for k = 1, #upStarMaterialsData do
                if upStarMaterialsData[k] then
                    local configMaterialId = upStarMaterialsData[k][1]
                    local configMaterialNum = upStarMaterialsData[k][2]
                    local curMaterialBagNum
                    if k == 1 then--需要的灵兽
                        local NoUpLvPokemonData = PokemonManager.GetNoUpLvPokemonData(curPokemonData.id,curPokemonData.dynamicId)
                        curMaterialBagNum = LengthOfTable(NoUpLvPokemonData) 
                    elseif  k >= 2 then--需要的材料
                        curMaterialBagNum = BagManager.GetItemCountById(upStarMaterialsData[k][1])
                    end
                    if curMaterialBagNum < configMaterialNum then
                        isCanUpStar = false
                    end
                end
            end
            if isCanUpStar then
                return true
            end
        end
    end
    return false
end
--可以上阵灵兽红点
function this.RefreshPokemonCanUpZhenRedPoint()
    local isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.POKEMON)
    if not isOpen then
        return false
    end
    local canPokemonList = this.GetCanUpZhenPokemonDatas()
    if #canPokemonList <= 0 then
        
        return false
    end
    local pokemonPosLocks = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSetting,1).BlockUnlockLevel
    for i = 1, 6 do
        local state = 1--1 未解锁 隐藏 2 即将解锁 3 已解锁 未上阵 4 已解锁 已上阵
        if pokemonPosLocks[i] <= PlayerManager.level then
            state = 3
            if pokemonFormation[i] and pokemonFormation[i].pokemonId then
                state = 4
            end
        else
            state = 2
        end
        if state == 3 and #canPokemonList > 0 then
            
            return true
        end
    end
    
    return false
end

--可激活的羁绊
function this.RefreshPokemonFetterRedPoint()
    local isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.POKEMON)
    if not isOpen then
        return false
    end
    local curGetAllPokemonFetter = this.GetAllPokemonFetterDatas()
    for k,v in ipairs(curGetAllPokemonFetter) do
        if v.enabled == 0 then
            
            return true
        end
    end
    
    return false
end
function this.IsCompound(Teamers,curPokemonSidList)
    local isCompound = true
    for k,v in ipairs(Teamers) do
        if curPokemonSidList[v] == nil then
            if isCompound then
                isCompound = false
                break
            end
        end
    end
    return isCompound
end
--免费抽卡次数
function this.RefreshPokemonRecruitRedPoint()
    local isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.POKEMON)
    if not isOpen then
        return false
    end
    --获取免费次数
    local currLottery= ConfigManager.GetConfigData(ConfigName.LotterySetting,RecruitType.LingShowSingle)
    local freeTimesId=currLottery.FreeTimes
    local  freeTime = 0
    if freeTimesId>0 then
        freeTime= PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
    end
    local isFree = freeTime and freeTime >= 1
    if isFree then
        
        return true
    else
        
        return false
    end
end
function this.PokemonChipRefresh()
    CheckRedPointStatus(RedPointType.Pokemon_ChipCompound)
end
--碎片可以合成红点
function this.PokemonChipCompoundRedPoint()
    local isOpen = ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.POKEMON)
    if not isOpen then
        return false
    end
    local pokemonChipList = BagManager.GetDataByItemType(ItemType.LingShouChip)
    if #pokemonChipList > 0 then
        for i = 1, #pokemonChipList do
            if BagManager.GetItemCountById(pokemonChipList[i].id) >= itemConfig[pokemonChipList[i].id].UsePerCount then
                
                return true
            end
        end
    end
    
    return false
end


function this.SetHeroStars(starPre,star)
    if star < 6 then
        for i = 1, 17 do            
            if i <= star then
                starPre.transform:GetChild(i - 1):GetComponent("Image").sprite = Util.LoadSprite(GetHeroStarImage[1])
                starPre.transform:GetChild(i - 1):GetComponent("RectTransform").sizeDelta = starSize
                starPre.transform:GetChild(i - 1).gameObject:SetActive(true)
            else
                starPre.transform:GetChild(i - 1).gameObject:SetActive(false)
            end
        end
    elseif star > 5 and star < 10 then
        for i = 1, 17 do            
            if i <= star - 5 then
                starPre.transform:GetChild(i - 1):GetComponent("Image").sprite = Util.LoadSprite(GetHeroStarImage[2])
                starPre.transform:GetChild(i - 1):GetComponent("RectTransform").sizeDelta = starSize
                starPre.transform:GetChild(i - 1).gameObject:SetActive(true)
            else
                starPre.transform:GetChild(i - 1).gameObject:SetActive(false)
            end
        end
    elseif star > 9 then  
        if type and type == 1 then
            for i = 1, 17 do     
                if i == star - 4 then   
                    starPre.transform:GetChild(i - 1).gameObject:SetActive(true) 
                else
                    starPre.transform:GetChild(i - 1).gameObject:SetActive(false)  
                end
            end
        elseif type and  type == 2 then
            for i = 1, 17 do           
                if i > 11 and i == star + 2 then   
                    starPre.transform:GetChild(i - 1).gameObject:SetActive(true) 
                else
                    starPre.transform:GetChild(i - 1).gameObject:SetActive(false) 
                end        
            end
        else
            for i = 1, 17 do     
                if i == star - 4 then   
                    starPre.transform:GetChild(i - 1).gameObject:SetActive(true) 
                else
                    starPre.transform:GetChild(i - 1).gameObject:SetActive(false)  
                end
            end
        end             
    end
end
return this