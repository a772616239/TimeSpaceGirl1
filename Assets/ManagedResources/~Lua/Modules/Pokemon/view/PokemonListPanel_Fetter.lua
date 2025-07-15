----- 灵兽羁绊 -----
local this = {}
local sortingOrder=0
local curPokemonSidList = {}
local spiritAnimalBook = ConfigManager.GetConfig(ConfigName.SpiritAnimalBook)
local spiritAnimal = ConfigManager.GetConfig(ConfigName.SpiritAnimal)

local fetterPreList = {}
local fetterPreItemList = {}
local fetterPreAddList = {}
function this:InitComponent(gameObject)
    this.fetterPre = Util.GetGameObject(gameObject, "PokemonListPanel_Fetter/fetterPre")
    this.ScrollView = Util.GetGameObject(gameObject, "PokemonListPanel_Fetter/ScrollParentView")
    local v3 = this.ScrollView.transform.rect
    this.sv = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.ScrollView.transform,
        this.fetterPre, Vector2.New(1080, v3.height), 1,10)
    this.sv.moveTween.Strength = 2
    Util.GetGameObject(gameObject, "PokemonListPanel_Fetter/name"):GetComponent("Text").text = GetLanguageStrById(12493)--m5
end

   local sortList = {
       [1] = 0,
       [0] = 1,
       [-1] = -1
   }
function this:BindEvent()
   
end

function this:AddListener()
end

function this:RemoveListener()
end
local sortingOrder = 0
function this:OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
end
function this:OnShow(...)
    this.ShowPokemonFetterData()
end

function this.ShowPokemonFetterData()
    local curGetAllPokemonFetter = PokemonManager.GetAllPokemonFetterDatas()
    --m5
    for i,v in ipairs(curGetAllPokemonFetter) do
        
    end
    curPokemonSidList = PokemonManager.GetAllPokemonGetDatas()
    
    table.sort(curGetAllPokemonFetter, function(a,b)
        if sortList[a.enabled] == sortList[b.enabled] then
            return a.id < b.id
        else
            return sortList[a.enabled] > sortList[b.enabled]
        end
    end)
    this.sv:SetData(curGetAllPokemonFetter, function(dataIndex, go)
        this.SingleItemDataShow(go,curGetAllPokemonFetter[dataIndex])
        table.insert(fetterPreList,go)
    end)
end

--宝物列表宝物数据显示
function this.SingleItemDataShow(_go,_fetterData)
    local config = spiritAnimalBook[_fetterData.id]
    Util.GetGameObject(_go.transform,"nameImage/nameText"):GetComponent("Text").text = config.Name
    Util.GetGameObject(_go.transform,"tipText"):GetComponent("Text").text=GetLanguageStrById(12494)--m5

    local itemList = Util.GetGameObject(_go.transform,"scroll/itemList")
    local item = Util.GetGameObject(_go.transform,"GameObject/frame")
    local add = Util.GetGameObject(_go.transform,"add")
    if not fetterPreItemList[_go] then
        fetterPreItemList[_go] ={}
    end
    if not fetterPreAddList[_go] then
        fetterPreAddList[_go] = {}
    end
    for k,v in pairs(fetterPreItemList[_go]) do
        v.gameObject:SetActive(false)
    end
    for k,v in pairs(fetterPreAddList[_go]) do
        v.gameObject:SetActive(false)
    end

    for k,v in ipairs(config.Teamers) do
        if not fetterPreItemList[_go][k] then
            fetterPreItemList[_go][k] = newObjToParent(item,itemList)
            fetterPreItemList[_go][k]:GetComponent("RectTransform").localScale = Vector3.New(0.6,0.6,0.6)
        end
        fetterPreItemList[_go][k].gameObject:SetActive(true)
        fetterPreItemList[_go][k]:GetComponent("Image").sprite = 
            Util.LoadSprite(GetQuantityImageByquality(ConfigManager.GetConfigData(ConfigName.SpiritAnimal,v).Quality))
        Util.GetGameObject(fetterPreItemList[_go][k],"icon"):GetComponent("Image").sprite = 
            Util.LoadSprite(GetResourcePath(spiritAnimal[v].Icon))
        Util.GetGameObject(fetterPreItemList[_go][k],"mask"):SetActive(curPokemonSidList[v] == nil)  
        Util.GetGameObject(fetterPreItemList[_go][k],"name"):GetComponent("Text").text = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,v).Name
        if config.Teamers[k + 1] then
            if not fetterPreAddList[_go][k] then
                fetterPreAddList[_go][k] = newObjToParent(add,itemList)
            end
            fetterPreAddList[_go][k].gameObject:SetActive(true)
        end
        Util.AddOnceClick(fetterPreItemList[_go][k], function()
            UIManager.OpenPanel(UIName.PokemonGetInfoPopup, false,v)
        end)
    end
    if _fetterData.enabled == 1 then
        Util.GetGameObject(_go.transform,"nextproValue"):GetComponent("Text").text = string.format("<color=#6D4528>%s</color>",GetLanguageStrById(12495))
    elseif _fetterData.enabled == 0 then 
        Util.GetGameObject(_go.transform,"nextproValue"):GetComponent("Text").text = string.format("<color=#6D4528>%s</color>",GetLanguageStrById(12496))
    else
        Util.GetGameObject(_go.transform,"nextproValue"):GetComponent("Text").text = string.format("<color=#6D4528>%s</color>",GetLanguageStrById(12496))
    end

    local proList = config.ActivePara
    for i = 1, 4 do
        local singlePro = Util.GetGameObject(_go.transform,"proList/pro (".. i ..")")
        if proList[i] then
            singlePro:SetActive(true)
            local proVal = proList[i]
            local tempData = ConfigManager.GetConfigData(ConfigName.PropertyConfig,proVal[1])
            local proName = tempData.Info
            if _fetterData.enabled == 1 then
                Util.GetGameObject(singlePro.transform,"proName"):GetComponent("Text").text = string.format("<color=#6D4528>%s</color>",proName)--m5
                Util.GetGameObject(singlePro.transform,"proValue"):GetComponent("Text").text = string.format("<color=#6D4528>+%s</color>",GetPropertyFormatStr(tempData.Style, proVal[2]))--m5
            elseif _fetterData.enabled == 0 then
                Util.GetGameObject(singlePro.transform,"proName"):GetComponent("Text").text = string.format("<color=#6D4528>%s</color>",proName)--m5
                Util.GetGameObject(singlePro.transform,"proValue"):GetComponent("Text").text = string.format("<color=#6D4528>+%s</color>",GetPropertyFormatStr(tempData.Style, proVal[2]))--m5
            else
                Util.GetGameObject(singlePro.transform,"proName"):GetComponent("Text").text = string.format("<color=#6D4528>%s</color>",proName)--m5
            Util.GetGameObject(singlePro.transform,"proValue"):GetComponent("Text").text = string.format("<color=#6D4528>+%s</color>",GetPropertyFormatStr(tempData.Style, proVal[2]))--m5
            end
        else
            singlePro:SetActive(false)
        end
    end
    Util.GetGameObject(_go.transform,"btn").gameObject:SetActive(_fetterData.enabled == 0)
    Util.AddOnceClick(Util.GetGameObject(_go.transform,"btn/compoundBtn"), function()
            local oldWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            NetManager.PokemonBookEnableRequest(_fetterData.id,function()
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12497),config.Name)) --m5
                PokemonManager.UpdatePokemonFetterDatas(_fetterData.id)
                this.ShowPokemonFetterData()
                FormationManager.CheckHeroIdExist()
                local newWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
                PokemonManager.PiaoWarPowerChange(oldWarPower,newWarPower)
            end)
    end)
end

function this:OnClose()
    CheckRedPointStatus(RedPointType.Pokemon_Fetter)
end

function this:OnDestroy()  
    fetterPreList = {}
    fetterPreItemList = {}
    fetterPreAddList = {}
    this.sv = {}
end

return this