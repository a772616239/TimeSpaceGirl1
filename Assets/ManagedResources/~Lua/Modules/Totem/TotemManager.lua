TotemManager = {}
local this = TotemManager
local allTotems = {}
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local expeditionTotemConfig = ConfigManager.GetConfig(ConfigName.ExpeditionTotemConfig)
local expeditionTotemTypeConfig = ConfigManager.GetConfig(ConfigName.ExpeditionTotemTypeConfig)
local Quality={[1]=GetLanguageStrById(23128),[2]=GetLanguageStrById(23129),[3]=GetLanguageStrById(23130)}
function this.Initialize()
end
--初始化所有图腾数据
function this.InitAllTotemData(_totemData)
    if _totemData == nil then
        return
    end
    for i = 1, #_totemData do
        this.InitSingleData(_totemData[i])
    end
end
--初始化单个图腾的数据
function this.InitSingleData(_Data)
    if _Data == nil then
        return
    end
    local single = {}
    local staticId = _Data.totemId
    local currConfig = expeditionTotemConfig[staticId]
    single.Totemconfig=currConfig
    single.id = staticId
    single.idDyn = currConfig.ItemId
    single.lv = currConfig.Level
    single.upHeroDid = nil
    single.step = currConfig.Step
    single.nextId = currConfig.NextId
    local totemItems= ConfigManager.GetAllConfigsDataByKey(ConfigName.ExpeditionTotemConfig,"ItemId",currConfig.ItemId)
    local attr={}
    for i = 1, #totemItems do
        local item= totemItems[i]
        if staticId>=item.Id then
            for j= 1, #item.Attr do
                if attr[item.Attr[j][1]] then
                    attr[item.Attr[j][1]]=attr[item.Attr[j][1]]+item.Attr[j][2]

                 else
                    attr[item.Attr[j][1]]=item.Attr[j][2]

                 end
            end

        else
            break
        end
     
    end

    single.attr=attr
    single.frame = GetQuantityImageByquality(currConfig.Color)
    single.name = itemConfig[currConfig.ItemId].Name
    single.itemConfig = itemConfig[currConfig.ItemId]
    single.icon = GetResourcePath(itemConfig[currConfig.ItemId].ResourceID)
    single.quality=Quality[currConfig.Step]


    allTotems[single.idDyn] = single
    
end

--穿戴图腾(初始化用)
function this.UpTotemData(_Id,heroId)
    local toTemId=expeditionTotemConfig[_Id].ItemId
    if allTotems[toTemId] then

        allTotems[toTemId].upHeroDid = heroId
    end
end
--卸下图腾
function this.DownTutemDataByHeroId(heroId)

    for k,v in pairs(allTotems)do
        if v.upHeroDid==heroId then
            allTotems[v.idDyn].upHeroDid =nil
            HeroManager.SetHeroTotemInfo(heroId,0)
        end 
    end
end
--穿戴图腾
function this.wearTotemData(_Id,heroId)
    local toTemId=expeditionTotemConfig[_Id].ItemId
    if allTotems[toTemId] then
        allTotems[toTemId].upHeroDid = heroId
        HeroManager.SetHeroTotemInfo(heroId,_Id)
    end
end


function this.GetTotemIdById(_Id)
    local toTemId=expeditionTotemConfig[_Id].ItemId
    return toTemId
end

function this.GetTotemById(_Id)
    local toTemData=expeditionTotemConfig[_Id]
    return toTemData
end

function this.GetTotemQualityById(stepId)
   
    return Quality[stepId]
end

--添加图腾
function this.AddTotem(newTotem)
    if newTotem then
        this.InitSingleData(newTotem)
    end
end

--删除图腾
function this.DeleteTotem(totemId)
    if totemId and allTotems[totemId] then
        allTotems[totemId]=nil
    end
end




--通过英雄id得到身上穿的图腾
function this.GetTotemDataByHeroId(heroId)
    for k,v in pairs(allTotems)do
        if v.upHeroDid==heroId then
            return v
        end 
    end
    return nil
end

--获得某一个图腾数据
function this.GetOneTotemData(id)
    if allTotems[id] then
        return allTotems[id]
    end
    LogRed("没有图腾"..id)
end

--图腾升级
function this.TotemUpLevel(id,heroId)

    local totemId= this.GetTotemIdById(id)
    if allTotems[totemId] then
        local currConfig = expeditionTotemConfig[id+1]
        allTotems[totemId].Totemconfig=currConfig
        allTotems[totemId].id = id+1
        allTotems[totemId].idDyn = currConfig.ItemId
        allTotems[totemId].lv = currConfig.Level
        allTotems[totemId].upHeroDid = heroId
        allTotems[totemId].step = currConfig.Step

        for i = 1, #currConfig.Attr do

            if allTotems[totemId].attr[currConfig.Attr[i][1]] then

                allTotems[totemId].attr[currConfig.Attr[i][1]]=allTotems[totemId].attr[currConfig.Attr[i][1]]+currConfig.Attr[i][2]
            else
                allTotems[totemId].attr[currConfig.Attr[i][1]]=currConfig.Attr[i][2]
            end
        end

        allTotems[totemId].frame = GetQuantityImageByquality(currConfig.Color)
        allTotems[totemId].name = itemConfig[currConfig.ItemId].Name
        allTotems[totemId].itemConfig = itemConfig[currConfig.ItemId]
        allTotems[totemId].icon = GetResourcePath(itemConfig[currConfig.ItemId].ResourceID)
        allTotems[totemId].nextId = currConfig.NextId
        allTotems[totemId].quality=Quality[currConfig.Step]
        HeroManager.SetHeroTotemInfo(heroId,id+1)
        
    end
    
end

--重置
function this.TotemResetLevel(id,heroId,parent)

    local totemId= this.GetTotemIdById(id)
    if allTotems[totemId] then
        local initData= ConfigManager.GetConfigDataByKey("ExpeditionTotemConfig","ItemId",totemId)
        local currConfig = expeditionTotemConfig[initData.Id]
        allTotems[totemId].Totemconfig=currConfig
        allTotems[totemId].id = initData.Id
        allTotems[totemId].idDyn = currConfig.ItemId
        allTotems[totemId].lv = currConfig.Level
        allTotems[totemId].upHeroDid = heroId
        allTotems[totemId].step = currConfig.Step

        local attr={}
        for j= 1, #initData.Attr do
            if attr[initData.Attr[j][1]] then
                attr[initData.Attr[j][1]]=attr[initData.Attr[j][1]]+initData.Attr[j][2]
             else
                attr[initData.Attr[j][1]]=initData.Attr[j][2]
             end
        end
        
        allTotems[totemId].attr=attr
        allTotems[totemId].frame = GetQuantityImageByquality(currConfig.Color)
        allTotems[totemId].name = itemConfig[currConfig.ItemId].Name
        allTotems[totemId].itemConfig = itemConfig[currConfig.ItemId]
        allTotems[totemId].icon = GetResourcePath(itemConfig[currConfig.ItemId].ResourceID)
        allTotems[totemId].nextId = currConfig.NextId
        allTotems[totemId].quality=Quality[currConfig.Step]
    
        parent.totemId=initData.Id
        HeroManager.SetHeroTotemInfo(heroId,initData.Id)
    end
    
end



--获取全部已有图腾(包括穿戴在英雄身上的)
function this.GetAllTotemData()
    local allData = {}
    for k, v in pairs(allTotems) do
        --if v.upHeroDid == nil then
            table.insert(allData, v)
        --end
    end
    return allData
end

--没有获得的图腾
function this.GetAllNoHaveTotemData()
    local allData = {}
    for k, v in ConfigPairs(expeditionTotemTypeConfig) do
        if allData[v.ItemId] == nil and not this.TotemDataIsHave(v.ItemId)  then
            allData[v.ItemId]=v
        end
    end
    return allData
end
function this.TotemDataIsHave(itemId)
    local allData = {}
    for k, v in pairs(allTotems) do
        if v.idDyn == itemId then
            return true
        end
    end
    return false
end





 



return TotemManager