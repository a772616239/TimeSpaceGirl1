---勋章
MedalManager = {}
local this = MedalManager
local MedalConfig = ConfigManager.GetConfig(ConfigName.MedalConfig)
local MedalSuitConfig = ConfigManager.GetConfig(ConfigName.MedalSuitConfig)
local MedalSuitType = ConfigManager.GetConfig(ConfigName.MedalSuitType)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local Quality = {
    [3] = GetLanguageStrById(50312),
    [4] = GetLanguageStrById(50313),
    [5] = GetLanguageStrById(50314)}
this.allMedal = {}
local upMedalList = {}--所有英雄对应的勋章装备
local medalSiteList--玩家背包里拥有的勋章装备
this.randomProperty = {}--临时调教数据
this.count = 0--洗练次数

function this.Initialize()
end

--初始化英雄数据
function this.InitAllMedalData(_msg)
    if _msg.medal == nil then
        return
    end
    for i = 1, #_msg.medal do
        this.InitMedalData(_msg.medal[i])
    end
end

function this.InitMedalData(medalData)
    if medalData == nil then
        return
    end
    local medal = {}
    local staticId = medalData.medalId
    local MedalConfigData = MedalConfig[staticId]
    medal.id = staticId--静态id
    medal.medalConfig = MedalConfigData
    medal.suitId = MedalConfigData.Suit
    medal.idDyn = medalData.id
    medal.BasicProperty = MedalConfigData.BasicAttr
    medal.RandomProperty = medalData.myRandomProperty
    medal.refineAttrNum = medalData.refineAttrNum
    medal.icon = GetResourcePath(ItemConfig[medalData.medalId].ResourceID)
    medal.position = MedalConfigData.SiteType
    medal.itemConfig = ItemConfig[staticId]
    medal.upHeroDid = nil
    --v.itemConfig = ItemConfig[v.id]
    medal.frame = GetQuantityImageByquality(MedalConfigData.Quality)

    this.allMedal[medal.idDyn]=medal
end

--设置勋章穿戴的英雄
function this.UpMedalData(medalid,heroDid)
    if this.allMedal[medalid] then
        this.allMedal[medalid].upHeroDid = heroDid
    end
end
--通过site进行筛选勋章
function this.MedalDaraBySite(site,heroId)
    local medalList = {}
    for k,v in pairs(this.allMedal)do
        if v.position == site and v.upHeroDid ~= heroId and v.upHeroDid == nil then
            table.insert(medalList,v)
        end
    end
    table.sort(medalList,function (a,b)
        if a.medalConfig.Quality == b.medalConfig.Quality then
            return  a.medalConfig.Star > b.medalConfig.Star
        else
            return a.medalConfig.Quality > b.medalConfig.Quality
        end
    end)

    return medalList
end

--通过勋章套装类型进行筛选勋章
function this.MedalDaraByType(type)--0:全部  1-12 套装类型
    local medalList = {}
    if type == 0 then
        for k,v in pairs(this.allMedal)do
            --没有被装备&&可以合成
            if v.upHeroDid == nil and v.medalConfig.NextId ~= 0  then
                table.insert(medalList,v)
                table.sort(medalList,function (a,b)
                    if a.medalConfig.Quality == b.medalConfig.Quality then
                        if a.medalConfig.Star == b.medalConfig.Star then
                            return a.id > b.id
                        else
                            return a.medalConfig.Star > b.medalConfig.Star
                        end
                    else
                        return a.medalConfig.Quality > b.medalConfig.Quality
                    end
                end)
            end
        end
    else
        for k,v in pairs(this.allMedal)do
            --同一套装类型&&没有被装备&&可以合成
            if MedalSuitConfig[v.suitId].Type == type and v.upHeroDid == nil and v.medalConfig.NextId ~= 0 then
                table.insert(medalList,v)

                table.sort(medalList,function (a,b)
                    if a.medalConfig.Quality == b.medalConfig.Quality then
                        if a.medalConfig.Star == b.medalConfig.Star then
                            return a.id > b.id
                        else
                            return a.medalConfig.Star > b.medalConfig.Star
                        end
                    else
                        return a.medalConfig.Quality > b.medalConfig.Quality
                    end
                end)
            end
        end
    end
    return medalList
end

-- 通过套装类型获取套装静态表数据
function this.GetMedalSuitInfoByType(medalType)
    return ConfigManager.GetConfigDataByKey(ConfigName.MedalSuitType, "TypeId", medalType)
end

-- 通过套装类型获取套装静态表数据
function this.GetMedalSuitInfoById(suiuid)
    return ConfigManager.GetConfigDataByKey(ConfigName.MedalSuitConfig, "SuitId", suiuid)
end


--某一个英雄身上的勋章
function this.MedalDaraByHero(heroId)
    local medalList = {}
    for k,v in pairs(this.allMedal)do
        if v.upHeroDid == heroId then
            medalList[v.position] = v
        end
    end
    return medalList
end
--卸下某一个英雄身上的所有勋章
function this.DownMedalDaraByHero(heroId)
    for k,v in pairs(this.allMedal)do
        if v.upHeroDid == heroId then
            this.allMedal[v.idDyn].upHeroDid = nil
        end
    end
end
--给某一个英雄穿一组勋章
function this.WearMedalsByHero(heroId,medalListId)
    for k,v in ipairs(medalListId)do
        this.allMedal[v].upHeroDid = heroId
    end
end

--获得某一个勋章数据
function this.GetOneMedalData(id)
    if this.allMedal[id] then
        return this.allMedal[id]
    end
    LogRed("没有勋章"..id)
end
--获得某一个勋章穿戴的英雄ID
function this.GetOneheroIdData(id,heroId)
    if this.allMedal[id] then
        if this.allMedal[id].upHeroDid and this.allMedal[id].upHeroDid~=heroId  then
           return this.allMedal[id].upHeroDid
        else
            return 0
        end
    end
    LogRed("没有勋章"..id)
end

--获取全部已有勋章(不包括穿戴在英雄身上的)
function this.GetAllMedalData()
    local ret = {}
    for k, v in pairs(this.allMedal) do
        if v.upHeroDid == nil then
            -- v.itemConfig = ItemConfig[v.id]
            v.frame = GetQuantityImageByquality(v.medalConfig.Quality)
            --v.Quality =v.medalConfig.Quality
            table.insert(ret, v)
        end
    end
    -- table.sort(ret, function(a, b)
    --     return a.quality > b.quality
    -- end)

    return ret

    -- return this.allMedal
end


--删除勋章
function this.DeleteMedal(medalId)
   if medalId then
    this.allMedal[medalId] = nil
   end
end
--添加勋章
function this.AddMedal(newMedal)
    if newMedal then
        this.InitMedalData(newMedal)
        --this.allMedal[newMedal.idDyn]=newMedal
    end
 end

function this.CreateEmptyTable()
    local medal = {}
    medal.id = nil
    medal.medalId = nil
    --medal.suitId = {}
    --medal.property = {}
    --medal.myRandomProperty = {}
    medal.position = nil
    medal.refineAttrNum = 0
    return medal

end
--装备
function this.WearMedal(heroid, medalId,pos, func)
    local oldWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
    local medalList = this.MedalDaraByHero(heroid)
    if medalList[pos] then
        this.UnloadMedal(heroid,pos, medalList[pos].idDyn, func)--注意：这里卸载的是已装备的勋章id
    end
    NetManager.MedalWearRequest(heroid,medalId,pos,function() 
        if this.allMedal[medalId] then
            this.allMedal[medalId].upHeroDid =heroid
        end

        local curHeroData = HeroManager.GetSingleHeroData(heroid)
        local empty = this.CreateEmptyTable()
        empty.id = this.allMedal[medalId].idDyn
        empty.medalId = this.allMedal[medalId].id
        --empty.suitId = this.allMedal[medalId].suitId
        --empty.property = this.allMedal[medalId].BasicProperty
        empty.position = this.allMedal[medalId].position
        -- empty.refineAttrNum = 0

        local list = {}
        for k,v in ipairs(curHeroData.medal)do
             table.insert(list,v)
        end
        table.insert(list,empty)

        curHeroData.medal = list
        HeroManager.SetMedalHeroList(heroid,list)

        RoleInfoPanel:UpdatePanelData()
        RefreshPower(oldWarPower)

        if func then
            -- HeroManager.GetMedalHeroList(heroid)
            func()
        end
    end)
end

--卸下
function this.UnloadMedal(heroid,pos, medalId, func)
    local oldWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
    NetManager.MedalUnloadRequest(heroid,pos,medalId,function() 
        if this.allMedal[medalId] then
            this.allMedal[medalId].upHeroDid = nil
        end
        local curHeroData = HeroManager.GetSingleHeroData(heroid)
        for k,v in pairs(curHeroData.medal) do
            if v.id == medalId then
                --v = nil
                table.removebyvalue(curHeroData.medal,v)
                HeroManager.SetMedalHeroList(heroid,curHeroData.medal)
                break
            end
        end

        RoleInfoPanel:UpdatePanelData()
        RefreshPower(oldWarPower)
        if func then
            -- HeroManager.GetMedalHeroList(heroid)
            func()
        end
    end)
end

--转化
function this.ConversionMedal(_medalId,_confMedalId,_heroid,_site,iswear,func)
    --两种情况 从背包转化 从战车详情里面转化
    NetManager.MedalConversionRequest(_medalId,_confMedalId,_heroid,_site,function(msg) 
        local ConversionAfterMedal = msg.medal
        this.AddMedal(ConversionAfterMedal)--添加勋章
        this.DeleteMedal(_medalId)--从背包删除勋章
        if  iswear then
            if _site == this.allMedal[ConversionAfterMedal.id].position then
               --if this.allMedal[_medalId].position==this.allMedal[ConversionAfterMedal.id].position and iswear then
               this.allMedal[ConversionAfterMedal.id].upHeroDid = _heroid
            end
            RoleInfoPanel:UpdatePanelData()
        end
        if func then
            func()
        end
    end)
end

--调教
function this.RefineMedal(_medalId,_lockPropertyId,func)
    NetManager.MedalRefineRequest(_medalId,_lockPropertyId,function(msg) 
        this.allMedal[_medalId].refineAttrNum = this.allMedal[_medalId].refineAttrNum+1
        this.randomProperty = msg.property
        this.count = msg.refineAttrNum
        if func then
            func()
        end
    end)
end

--调教的临时数据
function this.RefineTempPropertyMedal(_medalId,func)
    NetManager.MedalRefineTempPropertyRequest(_medalId,function(msg)
        this.randomProperty = msg.property
        this.count = msg.refineAttrNum
        if func then
            func()
        end
    end)

end

--保存调教值
function this.SaveMedal(_medalId,func)
    NetManager.MedalRefineConfirmRequest(_medalId,function()
        this.allMedal[_medalId].RandomProperty = this.randomProperty
        -- local curHeroData = HeroManager.GetSingleHeroData(this.allMedal[_medalId].upHeroDid)
        -- for k,v in pairs(curHeroData.medal) do
        --     if v.id == _medalId then
        --         --v = nil
        --         v.myRandomProperty=this.randomProperty
        --         HeroManager.SetMedalHeroList(this.allMedal[_medalId].upHeroDid,curHeroData.medal)
        --         break
        --     end
        -- end

        this.randomProperty={}
        if func then
            func()
        end
    end)

end

--合成勋章
function this.CompoundMedal(_medalId,lockPropertyId,func)
    NetManager.MedalMergeRequest(_medalId,lockPropertyId,function(msg)
        local targetMedal = msg.medal

        this.AddMedal(targetMedal)
        for k,v in pairs(_medalId)do
            this.DeleteMedal(v)
        end
        PopupTipPanel.ShowTipByLanguageId(23063)
        if func then
            func()
        end
    end)

end

--售出勋章
function this.SellMedal(_medalId,func)
    NetManager.MedalSellRequest(_medalId,function(msg)
        this.DeleteMedal(_medalId)
        PopupTipPanel.ShowTipByLanguageId(23064)
        if func then
            func(msg)
        end
    end)
end


--勋章激活状态
function this.SuitHeroSuitActive(itemlist)
    local suit1 = 0--两件套装id
    local starNum1 = 0--两件套对应的星数

    local suit2 = 0--四件套装id
    local starNum2 = 0--四件套对应的星数
    local suit = {}

    local suitTypeList = {}--勋章分类List
    for k,v in pairs(itemlist) do    
        if v then
            local suitId = v.medalConfig.Suit
            local suitType = MedalSuitConfig[suitId].Type
            local suitIdList = {}
            if suitTypeList[suitType] then
                table.insert(suitTypeList[suitType].id,suitId)
                suitTypeList[suitType] = {["num"] = suitTypeList[suitType].num + 1,["id"] = suitTypeList[suitType].id}
            else
                table.insert(suitIdList,suitId)
                suitTypeList[suitType] = {["num"] = 1,["id"] = suitIdList}
            end
        end
    end

    local bestNum = 0 --最大数量
    local type = 0--suit类型
    for k,v in pairs(suitTypeList) do
          --k:typeID  v:num&id
          if v.num > bestNum then
            bestNum = v.num
            type = k
          end
    end

    if bestNum == 4 then
        local little,big = this:Star(suitTypeList,type)

        suit1 = big
        starNum1 = 2

        suit2 = little
        starNum2 = 4

        table.insert(suit,{suitId = suit1,num = starNum1})
        table.insert(suit,{suitId = suit2,num = starNum2})
    
        return suit
    end

    if bestNum == 3 then
        local little,big = this:Star(suitTypeList,type)

        suit1 = big
        starNum1 = 2

        table.insert(suit,{suitId=suit1,num=starNum1})
        return suit 
    end

    if bestNum == 2 then
        --TODO特殊情况 第二组数据判断是两件还是四件
        if LengthOfTable(suitTypeList) == 2 and LengthOfTable(itemlist) == 4 then
            --两组两件激活
            local isEnter = false
            for k,v in pairs(suitTypeList) do
                if isEnter then
                    local little,big = this:Star(suitTypeList,k)
                    suit1 = little
                    starNum1 = 2
                else
                    local little,big = this:Star(suitTypeList,k)
                    suit2 = little
                    starNum2 = 2
                    isEnter = true
                end

            end
            table.insert(suit,{suitId = suit1,num = starNum1})
            table.insert(suit,{suitId = suit2,num = starNum2})
            return suit
        else
            --一组两件激活
            local little,big = this:Star(suitTypeList,type)
            suit1 = little
            starNum1 = 2
            table.insert(suit,{suitId = suit1,num = starNum1})
            return suit
        end
    else
        --四种type 两件四件均不可激活
        return suit
    end
end

function this:Star(suitTypeList,type)
    local ids = suitTypeList[type].id--同一个type的所有Id
    local idSort = {}
    for k,v in pairs(ids) do
        local suitId = v
        table.insert(idSort,suitId)
    end
    table.sort(idSort, function(a, b)
         return a < b
    end)
    return idSort[1],idSort[LengthOfTable(ids) - 1]--最小和第二大
end

function this.GetQualityName(qualityId)
    return Quality[qualityId]
end

return this