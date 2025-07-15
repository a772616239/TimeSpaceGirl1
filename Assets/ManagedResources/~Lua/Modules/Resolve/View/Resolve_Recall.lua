----- 回溯 -----
local this = {}
local sortType=0
local sortingOrder=0
local tarHero={}--当前筛选后显示英雄列表
local selectHeroData={}--选择的英雄list did = data
local oldChoosed=nil--上一个选中英雄
local heroConfig=ConfigManager.GetConfig(ConfigName.HeroConfig)
local heroRankupConfig = ConfigManager.GetConfig(ConfigName.HeroRankupConfig)

local costItemId = 0

function this:InitComponent(gameObject)
    this.helpBtn=Util.GetGameObject(gameObject,"HelpBtn")
    this.helpPos=this.helpBtn:GetComponent("RectTransform").localPosition
    this.confirmBtn=Util.GetGameObject(gameObject,"ConfirmBtn")
    --道具数量信息
    this.usePropIcon=Util.GetGameObject(gameObject,"UseProps/Icon"):GetComponent("Image")
    this.usePropInfo=Util.GetGameObject(gameObject,"UseProps/Info"):GetComponent("Text")
    this.empty=Util.GetGameObject(gameObject,"Empty")

    this.cardPre = Util.GetGameObject(gameObject,"item")
    this.scrollbar = Util.GetGameObject(gameObject,"Scrollbar"):GetComponent("Scrollbar")
    local v21 = Util.GetGameObject(gameObject, "Content/Resolve_Recall/ItemListRoot"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "Content/Resolve_Recall/ItemListRoot").transform,
            this.cardPre, this.scrollbar, Vector2.New(-v21.x*2, -v21.y*2), 1, 5, Vector2.New(45,15))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

function this:BindEvent()
    Util.AddClick(this.helpBtn,function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Resolve_Recall,this.helpPos.x,this.helpPos.y)
    end)
    Util.AddClick(this.confirmBtn,function()
        if tonumber(LengthOfTable(selectHeroData))==0 then
            PopupTipPanel.ShowTipByLanguageId(11792)
        else
            if BagManager.GetItemCountById(costItemId)==0 then
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,costItemId)
                return
            end
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.ResolveRecall,
            HeroManager.GetHeroReturnItems(selectHeroData,GENERAL_POPUP_TYPE.ResolveRecall),selectHeroData)
        end
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(...)
    local args={...}
    sortingOrder =args[1]
    sortType =0


    this.SortTypeClick(sortType)
end

function this:OnClose()
    selectHeroData={}
    oldChoosed=nil
end

function this:OnDestroy()
end



--展示数据
function this.SortTypeClick(_sortType)
    selectHeroData={}

    tarHero={}
    tarHero=this.GetHeroData(_sortType)
    --设置empty
    this.empty:SetActive(#tarHero==0)
    --设置回溯按钮置灰
    --Util.SetGray(this.confirmBtn,tonumber(LengthOfTable(selectHeroData))==0)
    this.usePropIcon.enabled=tonumber(LengthOfTable(selectHeroData))~=0
    this.usePropInfo.enabled=tonumber(LengthOfTable(selectHeroData))==0

    this.usePropInfo.text=GetLanguageStrById(11793)
    this.usePropInfo.fontSize=25

    --设置英雄显示
    this.SortHeroDatas(tarHero)
    this.ScrollView:SetData(tarHero, function (index, go)
        this.SingleHeroDataShow(go, tarHero[index])
    end)
end

--获取筛选后的英雄数据
function this.GetHeroData(_sortType)
    local tempHeros={}
        local data=HeroManager.GetAllHeroDataMsinusUpWar(_sortType,1)
        for n=1,#data do
            tempHeros[#tempHeros+1]=data[n]
        end
    --根据元素筛选
    local heros={}
    if tempHeros and LengthOfTable(tempHeros)>0 then
        for i, v in pairs(tempHeros) do
            if _sortType ==0 then
                table.insert(heros,v)
            -- elseif _sortType>=7 then
              -- if v.star==_sortType-4 then
        --         table.insert(heros,v)
        --     end
            else
                if v.property==_sortType then   
                    table.insert(heros,v)
                end
            end
        end
    end
    --end
    return heros
end

--英雄单个数据展示
function this.SingleHeroDataShow(go,_heroData)
    local heroData = _heroData
    local _go = go
    Util.GetGameObject(_go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroData.heroConfig.Quality,heroData.star))
    Util.GetGameObject(_go.transform, "lv/Text"):GetComponent("Text").text = heroData.lv
    Util.GetGameObject(_go.transform, "Text"):GetComponent("Text").text = GetLanguageStrById(heroData.heroConfig.ReadingName)
    Util.GetGameObject(_go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroData.heroConfig.Icon))
    Util.GetGameObject(_go.transform, "posIcon"):SetActive(false)--:GetComponent("Image").sprite = Util.LoadSprite(heroData.professionIcon)
    Util.GetGameObject(_go.transform, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroData.heroConfig.PropertyName))
    --Util.GetGameObject(_go.transform, "heroStage"):GetComponent("Image").sprite = Util.LoadSprite(HeroStageSprite[heroData.heroConfig.HeroStage])
    local starGrid = Util.GetGameObject(_go.transform, "star")
    SetHeroStars(starGrid, heroData.star)
    local choosed =Util.GetGameObject(_go.transform, "choosed")
    local formationMask =Util.GetGameObject(_go.transform, "formationMask")
    formationMask:SetActive(heroData.isFormation ~= "" )
    local lockMask =Util.GetGameObject(_go.transform, "lockMask")
    lockMask:SetActive(heroData.lockState == 1)
    choosed:SetActive(selectHeroData[heroData.dynamicId] ~= nil)

    local cardclickBtn = Util.GetGameObject(_go.transform, "icon")
    Util.AddOnceClick(cardclickBtn, function()
        if oldChoosed then
            oldChoosed:SetActive(false)
        end
        if oldChoosed==choosed then
            --LogColor("green",GetLanguageStrById(11794))
            oldChoosed:SetActive(LengthOfTable(selectHeroData)==0)
            oldChoosed=nil
            selectHeroData={}
            if LengthOfTable(selectHeroData)==0 then
                this.usePropInfo.text=GetLanguageStrById(11793)
                this.usePropInfo.fontSize=25
            end
        else
            --LogColor("red",GetLanguageStrById(11795))
            choosed:SetActive(true)
            oldChoosed=choosed

            selectHeroData = {}
            selectHeroData[heroData.dynamicId]=heroData
            this.usePropInfo.fontSize=35
            --英雄消耗道具数量
            local heroUseCount=0
            local heroUseItemId=0

             --等表配全后再启用
            for k,v in pairs(selectHeroData) do
                local pId
                local curHeroData =HeroManager.GetSingleHeroData(v.dynamicId)
                if not curHeroData then return end
                if curHeroData.breakId == 0 then
                    pId=0
                else
                    pId= heroRankupConfig[curHeroData.breakId].Phase[2]
                end
                local heroReturnConfig = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.HeroReturn,"HeroId",curHeroData.id,"Star",pId)
                if not heroReturnConfig then
                    
                    heroUseCount= 50
                    heroUseItemId = 16
                else
                heroUseCount= heroReturnConfig.ReturnConsume[1][2]
                heroUseItemId = heroReturnConfig.ReturnConsume[1][1]
                end
                break
            end
            --持有道具数量
            costItemId = heroUseItemId
            local itemNum = BagManager.GetItemCountById(heroUseItemId)
            if heroUseItemId > 0 then
                this.usePropIcon.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,heroUseItemId).ResourceID))            
            end
            if itemNum<heroUseCount then
                this.usePropInfo.text="<color=red>   "..heroUseCount.."</color>"
            else
                this.usePropInfo.text="   "..heroUseCount
            end
        end

        --Util.SetGray(this.confirmBtn,LengthOfTable(selectHeroData)==0)
        this.usePropIcon.enabled=LengthOfTable(selectHeroData)~=0
    end)

    Util.AddOnceClick(formationMask, function()
        if heroData.isFormation ~= "" then
            -- 复位角色的状态
            MsgPanel.ShowTwo(GetLanguageStrById(11788)..heroData.isFormation..GetLanguageStrById(11789), nil, function()
                if heroData.isFormations[1] then
                    if heroData.isFormations[1] == FormationTypeDef.FORMATION_NORMAL then
                        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.SAVE_FORMATION)
                    elseif heroData.isFormations[1] == FormationTypeDef.FORMATION_ARENA_DEFEND then
                        JumpManager.GoJump(8001)
                    elseif heroData.isFormations[1] == FormationTypeDef.FORMATION_ENDLESS_MAP then
                        JumpManager.GoJump(57001)
                    elseif heroData.isFormations[1] == FormationTypeDef.EXPEDITION then
                        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.SAVE_FORMATION,FormationTypeDef.EXPEDITION)
                    elseif heroData.isFormations[1] == FormationTypeDef.ARENA_TOM_MATCH then
                        JumpManager.GoJump(57001)
                    end
                end
            end)
            return
        end
    end)
    Util.AddOnceClick(lockMask, function()
        if heroData.lockState == 1 then
            MsgPanel.ShowTwo(GetLanguageStrById(11790), nil, function()
                NetManager.HeroLockEvent(heroData.dynamicId,0,function ()
                    PopupTipPanel.ShowTipByLanguageId(11791)
                    HeroManager.UpdateSingleHeroLockState(heroData.dynamicId,0)
                    lockMask:SetActive(false)
                end)
            end)
            return
        end
    end)
end

--英雄排序
function this.SortHeroDatas(_heroDatas)
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_heroDatas, function(a, b)
        if a ==nil or b == nil then
            return
        end
        if a.isFormation == "" and b.isFormation == "" then
            if a.lockState == b.lockState then
                if a.heroConfig.Natural ==b.heroConfig.Natural then
                    if a.star == b.star then
                        if a.lv == b.lv then
                            return a.heroConfig.Id > b.heroConfig.Id
                        else
                            return a.lv < b.lv
                        end
                    else
                        return a.star < b.star
                    end
                else
                    return a.heroConfig.Natural < b.heroConfig.Natural
                end
            else
                return a.lockState < b.lockState
            end
        else
            return a.isFormation == ""  and not b.dynamicId ~= ""
        end
    end)
end

return this