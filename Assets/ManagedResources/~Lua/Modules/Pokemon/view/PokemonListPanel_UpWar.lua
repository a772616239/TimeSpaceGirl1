----- 选择出战灵兽 -----
local this = {}
local sortingOrder=0
local polemonList = {}
local spiritAnimal = ConfigManager.GetConfig(ConfigName.SpiritAnimal)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local curUpZhenPokemonData --替换时需要下阵的数据
local upZhenIndex
function this:InitComponent(gameObject)
   
    Util.GetGameObject(gameObject, "PokemonListPanel_UpWar/name"):GetComponent("Text").text = GetLanguageStrById(23100)--m5
   
    this.ItemPre = Util.GetGameObject(gameObject, "PokemonListPanel_UpWar/ItemPre")
    local v2 = Util.GetGameObject(gameObject, "PokemonListPanel_UpWar/ScrollParentView"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "PokemonListPanel_UpWar/ScrollParentView").transform,
            this.ItemPre, nil, Vector2.New(-v2.x*2, -v2.y*2), 1, 1, Vector2.New(0,-12))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.NoneImage = Util.GetGameObject(gameObject, "PokemonListPanel_UpWar/NoneImage")
    this.NoneImageText = Util.GetGameObject(gameObject, "PokemonListPanel_UpWar/NoneImage/TextImage/Text"):GetComponent("Text")
    this.NoneImageText.text = GetLanguageStrById(23101)--m5
end

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
local parent
function this:OnShow(_parent,_curUpZhenPokemonData,_upZhenIndex)
    parent = _parent
    curUpZhenPokemonData = _curUpZhenPokemonData
    upZhenIndex = _upZhenIndex
    if curUpZhenPokemonData then
        polemonList = PokemonManager.GetCanUpZhenPokemonDatas(curUpZhenPokemonData)
    else
        polemonList = PokemonManager.GetCanUpZhenPokemonDatas()
    end
    table.sort(polemonList, function(a,b) 
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
end)
    this.ScrollView:SetData(polemonList, function (index, go)
        this.SingleItemDataShow(go, polemonList[index])
    end)
    this.NoneImage:SetActive(#polemonList <= 0)
    -- this.ScrollView:ForeachItemGO(function(index, go)
    --     Timer.New(function()
    --         go.gameObject:SetActive(true)
    --         PlayUIAnim(go.gameObject)
    --     end, 0.001 * (index - 1)):Start()
    -- end)
end

function this.SingleItemDataShow(_go,_itemData)
    Util.GetGameObject(_go.transform,"frame"):GetComponent("Image").sprite=Util.LoadSprite(GetQuantityImageByquality(itemConfig[_itemData.id].Quantity))
    Util.GetGameObject(_go.transform,"icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(spiritAnimal[_itemData.id].Icon))
    Util.GetGameObject(_go.transform,"name"):GetComponent("Text").text=itemConfig[_itemData.id].Name
    Util.GetGameObject(_go.transform,"lv/Text"):GetComponent("Text").text=_itemData.lv
    local starSize = Vector2.New(50,50)
    SetHeroStars(Util.GetGameObject(_go.transform, "star/starGrid"), _itemData.star)
    Util.AddOnceClick(Util.GetGameObject(_go.transform,"upZhen"), function()
        if curUpZhenPokemonData then
            --替换  协议
            local oldWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            local pos = 0
            local allPokemonFormation = PokemonManager.GetAllPokemonFormationData()
            for i = 1, #allPokemonFormation do
                if allPokemonFormation[i].pokemonId and allPokemonFormation[i].pokemonId == curUpZhenPokemonData.dynamicId then
                    pos = allPokemonFormation[i].position 
                    allPokemonFormation[i].pokemonId = _itemData.dynamicId
                end
            end
            if pos > 0 then
                NetManager.ReplaceTeamPokemonInfoRequest(allPokemonFormation, function()
                    PokemonManager.RefreshPokemonFormation(allPokemonFormation)
                    local newWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
                    PokemonManager.PiaoWarPowerChange(oldWarPower,newWarPower)
                    Game.GlobalEvent:DispatchEvent(GameEvent.Pokemon.PokemonUpZhenRefresh)
                    FormationManager.CheckHeroIdExist()
                   local pokemonInfoPanem =  UIManager.GetOpenPanel(UIName.PokemonInfoPanel)
                    if pokemonInfoPanem then
                        pokemonInfoPanem.RefreshShow(_itemData,PokemonManager.GetPokemonUpZhenDatas())
                    end
                    parent:ClosePanel()
                end)
            end
        else
            --上阵  协议
            local oldWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            local curFormation = PokemonManager.GetAllPokemonFormationData()
            
            for i = 1, #curFormation do
                if curFormation[i] and curFormation[i].position and curFormation[i].position == upZhenIndex then
                        curFormation[i].pokemonId = _itemData.dynamicId
                        
                end
            end

            NetManager.ReplaceTeamPokemonInfoRequest(curFormation, function()
                
                if upZhenIndex then
                    PokemonManager.RefreshPokemonFormation(curFormation)
                end
                local newWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
                --飘战力
                PokemonManager.PiaoWarPowerChange(oldWarPower,newWarPower)
                parent:ClosePanel()
                Game.GlobalEvent:DispatchEvent(GameEvent.Pokemon.PokemonUpZhenRefresh)
                FormationManager.CheckHeroIdExist()
            end)
            -- local pokemonMainPanel = UIManager.GetOpenPanel(UIName.PokemonMainPanel)
            -- if pokemonMainPanel then
            --     pokemonMainPanel.ShowPokemonList()
            -- end
        end
    end)
    Util.AddOnceClick(Util.GetGameObject(_go.transform,"click"), function()
        UIManager.OpenPanel(UIName.PokemonInfoPanel,_itemData,{_itemData},true)
    end)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this