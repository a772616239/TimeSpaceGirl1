----- 灵兽列表 和 合成 ----
local this = {}
local sortingOrder=0
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local spiritAnimal = ConfigManager.GetConfig(ConfigName.SpiritAnimal)
local TabBox = require("Modules/Common/TabBox")
local _TabData={ [1] = { default = "m5_btn_fenye_an-guajipaihangdi1", select = "m5_btn_fenye_liang-guajipaihangdi", name = GetLanguageStrById(12403) },--m5
                 [2] = { default = "m5_btn_fenye_an-guajipaihangdi1", select = "m5_btn_fenye_liang-guajipaihangdi", name = GetLanguageStrById(10219) },--m5
}
local _TabFontColor = { default = Color.New(190 / 255, 190 / 255, 190 / 255, 1), --m5
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1)}
local _TabImagePos = { default = -3,
                        select = -10}
local curIndex = 0
local pokemonList = {}
local pokemonChipList = {}
local AllPokemonFormationDids = {}
local redPointList = {}
function this:InitComponent(gameObject)
    this.ChipItemList={}--存储itemview 重复利用
    Util.GetGameObject(gameObject, "PokemonListPanel_List/name"):GetComponent("Text").text = GetLanguageStrById(12498)--m5
    this.tabBox = Util.GetGameObject(gameObject, "PokemonListPanel_List/TabBox")

    this.ScrollParentView1 = Util.GetGameObject(gameObject, "PokemonListPanel_List/ScrollParentView1")
    this.ScrollParentView2 = Util.GetGameObject(gameObject, "PokemonListPanel_List/ScrollParentView2")
   
    this.ItemPre1 = Util.GetGameObject(gameObject, "PokemonListPanel_List/ItemPre1")
    local v2 = this.ScrollParentView1:GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.ScrollParentView1.transform,
            this.ItemPre1, nil, Vector2.New(867.1, 1112.8), 1, 1, Vector2.New(0,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1

    this.ItemPre2 = Util.GetGameObject(gameObject, "PokemonListPanel_List/ItemPre2")
    local v2 = this.ScrollParentView2:GetComponent("RectTransform").rect
    this.ScrollView2 = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.ScrollParentView2.transform,
            this.ItemPre2, nil, Vector2.New(867.1, 1112.8), 1, 1, Vector2.New(0,0))
    this.ScrollView2.moveTween.MomentumAmount = 1
    this.ScrollView2.moveTween.Strength = 1

    this.NoneImage = Util.GetGameObject(gameObject, "PokemonListPanel_List/NoneImage")
    this.NoneImageText = Util.GetGameObject(gameObject, "PokemonListPanel_List/NoneImage/TextImage/Text"):GetComponent("Text")
end

function this:BindEvent()
   
    -- Util.AddClick(this.subtractBtn, function()
    --     this.CompoundNumChange(2)
    -- end)
end

function this:AddListener()
    
    Game.GlobalEvent:AddEvent(GameEvent.Pokemon.PokemonCompound, this.OnClickTabBtn,2)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Pokemon.PokemonCompound,this.OnClickTabBtn,2)
end


function this:OnShow(...)
    curIndex = 1
    sortingOrder =0
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData,curIndex)
    redPointList = {}
    for i = 1, #_TabData do
        local curTabBtn = Util.GetGameObject(this.tabBox, "box").transform:GetChild(i-1)
        redPointList[i] = Util.GetGameObject(curTabBtn, "Redpot")
    end
    pokemonChipList = BagManager.GetDataByItemType(ItemType.LingShouChip)
    this.PokemonChipDataSort(pokemonChipList)
    if redPointList[2] and redPointList[2].gameObject then
        redPointList[2]:SetActive(PokemonManager.PokemonChipCompoundRedPoint())
    end
end
local sortingOrder = 0
function this:OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
end
function this.OnClickTabBtn(_curIndex)
    curIndex = _curIndex
    
    if curIndex == 1 then
        this.ScrollParentView1:SetActive(true)
        this.ScrollParentView2:SetActive(false)
        pokemonList = PokemonManager.GetPokemonDatas()
        this.PokemonDataSort(pokemonList)
        AllPokemonFormationDids = {}
        AllPokemonFormationDids = PokemonManager.GetAllPokemonFormationDids()
        this.ScrollView:SetData(pokemonList, function (index, go)
            this.SingPokemonDataShow(go, pokemonList[index])
        end)
        this.NoneImage:SetActive(#pokemonList <= 0)
        this.NoneImageText.text = GetLanguageStrById(12499)--m5
    elseif curIndex == 2 then
        this.ScrollParentView1:SetActive(false)
        this.ScrollParentView2:SetActive(true)
        pokemonChipList = BagManager.GetDataByItemType(ItemType.LingShouChip)
        this.PokemonChipDataSort(pokemonChipList)
        if redPointList[2] and redPointList[2].gameObject then
            redPointList[2]:SetActive(PokemonManager.PokemonChipCompoundRedPoint())
        end
        for key, value in pairs(this.ChipItemList) do
            value.gameObject:SetActive(false)
        end
        this.ScrollView2:SetData(pokemonChipList, function (index, go)
            this.SingPokemonChipDataShow(go, pokemonChipList[index])
        end)
        this.NoneImage:SetActive(#pokemonChipList <= 0)
        this.NoneImageText.text = GetLanguageStrById(23098)--m5
    end
    -- this.ScrollView:ForeachItemGO(function(index, go)
    --     Timer.New(function()
    --         go.gameObject:SetActive(true)
    --         PlayUIAnim(go.gameObject)
    --     end, 0.001 * (index - 1)):Start()
    -- end)
end


function this.SingPokemonDataShow(_go,_itemData)
    Util.GetGameObject(_go.transform,"frame"):GetComponent("Image").sprite=Util.LoadSprite(GetQuantityImageByquality(itemConfig[_itemData.id].Quantity))
    Util.GetGameObject(_go.transform,"icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(spiritAnimal[_itemData.id].Icon))
    Util.GetGameObject(_go.transform,"name"):GetComponent("Text").text=itemConfig[_itemData.id].Name
    Util.GetGameObject(_go.transform,"lv/Text"):GetComponent("Text").text=_itemData.lv

    if AllPokemonFormationDids[_itemData.dynamicId] then
        Util.GetGameObject(_go.transform,"Image"):SetActive(true)
        Util.GetGameObject(_go.transform,"Image (1)"):SetActive(false)
    else
        Util.GetGameObject(_go.transform,"Image"):SetActive(false)
        Util.GetGameObject(_go.transform,"Image (1)"):SetActive(true)
    end
    local starSize = Vector2.New(50,50)
    SetHeroStars(Util.GetGameObject(_go.transform, "star/starGrid"), _itemData.star)
    Util.AddOnceClick(Util.GetGameObject(_go.transform,"click"), function()
        local upZhenDids = PokemonManager.GetAllPokemonFormationDids()
        if upZhenDids[_itemData.dynamicId] then
            UIManager.OpenPanel(UIName.PokemonInfoPanel,_itemData,PokemonManager.GetPokemonUpZhenDatas())
        else
            UIManager.OpenPanel(UIName.PokemonInfoPanel,_itemData,{_itemData},true)
        end
    end)
end
function this.SingPokemonChipDataShow(_go,_itemData)
    if not this.ChipItemList[_go] then
        this.ChipItemList[_go] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetTransform(_go, "itemParent").transform)
    end   
    this.ChipItemList[_go]:OnOpen(false, { _itemData.id, 0 }, 0.9)
    this.ChipItemList[_go].gameObject:SetActive(true)

    Util.GetGameObject(_go.transform,"name"):GetComponent("Text").text=_itemData.itemConfig.Name
    Util.GetGameObject(_go.transform,"num/Text"):GetComponent("Text").text = BagManager.GetItemCountById(_itemData.id).."/".._itemData.itemConfig.UsePerCount
    local conmpoundNum = math.floor(BagManager.GetItemCountById(_itemData.id)/_itemData.itemConfig.UsePerCount)
    Util.GetGameObject(_go.transform,"compoundBtn/redPoint"):SetActive(conmpoundNum > 0)
    Util.AddOnceClick(Util.GetGameObject(_go.transform,"compoundBtn"), function()

        if conmpoundNum <= 0 then
            PopupTipPanel.ShowTipByLanguageId(23099)
            return
        end
        if  conmpoundNum <= 1  then
            local item={}
            item.itemId=_itemData.itemConfig.Id
            item.itemNum=_itemData.itemConfig.UsePerCount
            NetManager.HeroComposeRequest(item,function (drop)
                UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function ()
                    Game.GlobalEvent:DispatchEvent(GameEvent.Pokemon.PokemonCompound)
                end,nil,nil,nil,true)
            end)
        else

            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.PokemonCompound,_itemData)
        end
    end)
end
function this.PokemonDataSort(pokemonList)
    local AllPokemonFormationDids = PokemonManager.GetAllPokemonFormationDids()
    table.sort(pokemonList, function(a,b) 
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
end
function this.PokemonChipDataSort(pokemonChipList)
    table.sort(pokemonChipList, function(a,b) 
        if (BagManager.GetItemCountById(a.id) >= itemConfig[a.id].UsePerCount) and (BagManager.GetItemCountById(b.id) >= itemConfig[b.id].UsePerCount) or 
            (BagManager.GetItemCountById(a.id) < itemConfig[a.id].UsePerCount) and (BagManager.GetItemCountById(b.id) < itemConfig[b.id].UsePerCount)  then
            if itemConfig[a.id].Quantity == itemConfig[b.id].Quantity then
                return a.id < b.id
            else
                return itemConfig[a.id].Quantity > itemConfig[b.id].Quantity
            end  
        else
            return(BagManager.GetItemCountById(a.id) >= itemConfig[a.id].UsePerCount) and (BagManager.GetItemCountById(b.id) < itemConfig[b.id].UsePerCount)
        end
    end)
end
-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    local tabImage = Util.GetGameObject(tab,"Image")
    tabImage:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    -- tabImage:GetComponent("Image"):SetNativeSize()
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
    -- tabImage.transform.localPosition = Vector3.New( tabImage.transform.localPosition.x, _TabImagePos[status], 0);
end
--切换视图
function this.SwitchView(index)
    this.OnClickTabBtn(index)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this