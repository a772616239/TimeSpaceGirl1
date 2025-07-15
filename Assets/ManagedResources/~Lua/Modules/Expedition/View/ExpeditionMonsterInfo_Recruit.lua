----- 远征招募节点弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0
local fun
--item容器
local itemList = {}
local monsterData = {}
local type = 1 --1 前往 2 放弃
local curSelectHero = nil
local oldSelectHeroGo = nil
local itemGrid = {}
function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    --this.power = Util.GetGameObject(gameObject, "power"):GetComponent("Text")
    this.sureBtn=Util.GetGameObject(gameObject,"sureBtn")
    this.sureBtnText=Util.GetGameObject(gameObject,"sureBtn/Text"):GetComponent("Text")
    this.Demons = Util.GetGameObject(gameObject, "demons")
    this.singlePre = Util.GetGameObject(gameObject, "itemPre")
    this.backBtn=Util.GetGameObject(gameObject,"BackBtn")
end

function this:BindEvent()
    Util.AddClick(this.sureBtn, function()
        this:BtnClickEvent()

    end)
    Util.AddClick(this.backBtn, function()
        parent:ClosePanel()
    end)
end
function this:BtnClickEvent()
    if type == 1 then
        parent:ClosePanel()
    elseif type == 2 then
        if curSelectHero then
            
            NetManager.HeroNodeRequest(monsterData.sortId,curSelectHero.id,function (msg)
                if msg.drop and msg.drop.Hero and msg.drop.Hero[1] then
                    ExpeditionManager.UpdateHeroDatas(msg.drop.Hero[1])
                end
                parent:ClosePanel()
                if fun then
                    fun()
                    fun = nil
                end
            end)
        else
            PopupTipPanel.ShowTipByLanguageId(10516)
        end
    end
end
function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    parent=_parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local args = {...}
    monsterData = args[1]
    type = args[2]
    
    fun = args[3]
    this.titleText.text=GetLanguageStrById(10517)
    if type == 1 then
        this.sureBtnText.text = GetLanguageStrById(10508)
    elseif type == 2 then
        this.sureBtnText.text = GetLanguageStrById(10517)
    end
    curSelectHero = nil
    oldSelectHeroGo = nil
    if monsterData == nil then LogError(GetLanguageStrById(10511)) return end
    for i = 1, 4 do
        if itemGrid[i] then
            itemGrid[i]:SetActive(false)
        end
    end
    NetManager.HeroNodeGetInfoRequest(monsterData.sortId,function (msg)
        
        this:FormationAdapter(msg)
    end)
end
-- 编队数据匹配
function this:FormationAdapter(msg)
    for i = 1, math.max(#msg.viewHeroInfo, #itemGrid) do
        local go = itemGrid[i]
        if not go then
            go = newObject(this.singlePre)
            go.transform:SetParent(this.Demons.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            itemGrid[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #msg.viewHeroInfo do
        local demon = itemGrid[i]
        demon:SetActive(true)
        local curData = msg.viewHeroInfo[i]
        local demonId = curData.hero.heroId
        local starGrid=Util.GetGameObject(demon, "starGrid")
        local proImage=Util.GetGameObject(demon, "heroShow/proIcon"):GetComponent("Image")
        Util.GetGameObject(demon, "heroShow/posIcon"):SetActive(false)
        --local posImage=Util.GetGameObject(demon, "heroShow/posIcon"):GetComponent("Image")
        local roleLevel=Util.GetGameObject(demon, "lvbg/levelText"):GetComponent("Text")
        local frameBtn=Util.GetGameObject(demon, "frame")
        if demonId then
            demon:SetActive(true)
            local demonData = ConfigManager.GetConfigData(ConfigName.HeroConfig, demonId)
            Util.GetGameObject(demon, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(demonData.Icon))
            local heroConFig = ConfigManager.GetConfigData(ConfigName.HeroConfig,demonId)
            Util.GetGameObject(demon, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConFig.Quality, curData.hero.star))
            Util.GetGameObject(demon, "nameText"):GetComponent("Text").text = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.HeroConfig,demonId).ReadingName)
            SetHeroStars(starGrid, curData.hero.star)
            proImage.sprite = Util.LoadSprite(GetProStrImageByProNum(demonData.PropertyName))
            --posImage.sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(demonData.Profession))
            roleLevel.text = curData.hero.level
            local choosed = Util.GetGameObject(demon, "selectImage")
            choosed:SetActive(false)
            Util.AddOnceClick(frameBtn, function()
                if type ~= 1 then
                    if curSelectHero == curData.hero then
                        choosed:SetActive(false)
                        curSelectHero = nil
                        oldSelectHeroGo = nil
                        return
                    end
                    curSelectHero = curData.hero
                    choosed:SetActive(true)
                    if oldSelectHeroGo then
                        Util.GetGameObject(oldSelectHeroGo, "selectImage"):SetActive(false)
                    end
                    oldSelectHeroGo  = demon
                end
            end)
            local heroData = {}
            Util.AddLongPressClick(frameBtn, function()
                heroData= GoodFriendManager.GetHeroDatas(curData.hero,curData.force,curData.SpecialEffects)
                GoodFriendManager.InitEquipData(curData.equip,heroData)
                GoodFriendManager.InitModelData(curData, heroData)
                UIManager.OpenPanel(UIName.RoleInfoPopup, heroData,true)
            end, 0.5)
        end
    end
end
function this:OnClose()

end
function this:OnDestroy()
    itemGrid = {}
end

return this