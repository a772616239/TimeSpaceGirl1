require("Base/BasePanel")
local PokemonMainPanel = Inherit(BasePanel)
local this = PokemonMainPanel
local PokemonList = {}
local PokemonGoList = {}
local PokemonGoListRedPoin = {}

local PokemonDataList = {}
local live2dList = {}
local dragViewListGo={}--dragView预设列表
local pokemonPosLocks = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSetting,1).BlockUnlockLevel
local spiritAnimal = ConfigManager.GetConfig(ConfigName.SpiritAnimal)
local canUpZhenPokemonList = {}
local isClick = true
this.trigger = {}
--初始化组件（用于子类重写）
function PokemonMainPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.btnHelp = Util.GetGameObject(self.transform, "btnhelp")  
    this.btnShop = Util.GetGameObject(self.transform, "btnEndRoot/btnShop")
    Util.GetGameObject(this.btnShop, "redPoint"):SetActive(false)
    this.btnInfo = Util.GetGameObject(self.transform, "btnEndRoot/btnInfo")
    this.btnInfoRed = Util.GetGameObject(this.btnInfo, "redPoint")
    this.btnWarAddPro = Util.GetGameObject(self.transform, "btnEndRoot/btnWarAddPro")
    Util.GetGameObject(this.btnWarAddPro, "redPoint"):SetActive(false)
    this.btnOut = Util.GetGameObject(self.transform, "btnEndRoot/btnOut")
    Util.GetGameObject(this.btnOut, "redPoint"):SetActive(false)
    this.btnFetter = Util.GetGameObject(self.transform, "btnEndRoot/btnFetter")
    this.btnFetterRed = Util.GetGameObject(this.btnFetter, "redPoint")
    this.btnPokemonList = Util.GetGameObject(self.transform, "btnEndRoot/btnPokemonList")
    this.btnPokemonListRed = Util.GetGameObject(this.btnPokemonList, "redPoint")
    Util.GetGameObject(this.btnPokemonList, "redPoint"):SetActive(false)
    this.line = Util.GetGameObject(self.transform,"lineParent/line")
    this.line:SetActive(false)
    this.roleGrid=Util.GetGameObject(this.gameObject,"lineParent")
    for i = 1, 6 do
        PokemonList[i] = Util.GetGameObject(self.transform, "PokemonList/singlePokemon (".. i ..")/singlePokemon")
        PokemonGoList[i] = Util.GetGameObject(PokemonList[i], "pokemon".. i)
        PokemonGoListRedPoin[i] = Util.GetGameObject(PokemonGoList[i], "redPoint")
        Util.GetGameObject( PokemonGoList[i], "upZhenInfo/titleImage/sortText"):GetComponent("Text").text = i
        Util.GetGameObject( PokemonGoList[i], "addInfo/addInfo/sortText"):GetComponent("Text").text = i

        if not dragViewListGo[i] then
            dragViewListGo[i] = SubUIManager.Open(SubUIConfig.DragView, PokemonList[i].transform)
        end
        dragViewListGo[i].gameObject.name="DragView"..i
        dragViewListGo[i].gameObject:SetActive(false)
        dragViewListGo[i]:SetScrollMouse(false)
        this.trigger[i]=Util.GetEventTriggerListener(dragViewListGo[i].gameObject)
        this.trigger[i].onPointerDown= this.trigger[i].onPointerDown+this.OnPointerDown
        this.trigger[i].onPointerUp= this.trigger[i].onPointerUp+this.OnPointerUp
        this.trigger[i].onEndDrag= this.trigger[i].onEndDrag+this.OnEndDrag
        this.trigger[i].onDrag=this.trigger[i].onDrag+this.OnDrag
        dragViewListGo[i]:SetDragGO(PokemonGoList[i])
    end

    this.root = Util.GetGameObject(this.gameObject,"root")
    -- this.callCount = Util.GetGameObject(self.transform, "callMonsterBtn/Text"):GetComponent("Text")
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })

end

--绑定事件（用于子类重写）
function PokemonMainPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)
    Util.AddClick(this.btnHelp, function()
        local pos = this.btnHelp.transform.localPosition
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.Pokemon, pos.x, pos.y)
    end)
    Util.AddClick(this.btnShop, function()
        JumpManager.GoJump(3002)
    end)
    Util.AddClick(this.btnInfo, function()
        UIManager.OpenPanel(UIName.PokemonSummonPanel)
    end)
    Util.AddClick(this.btnWarAddPro, function()
        -- UIManager.OpenPanel(UIName.HelpPopup)
        local AllPokemonFormationDids = PokemonManager.GetAllPokemonFormationDids() 
        if LengthOfTable(AllPokemonFormationDids) <= 0 then
            PopupTipPanel.ShowTipByLanguageId(23093) --m5
            return
        end
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.PokemonUpZhenAddPro,{})
    end)
    Util.AddClick(this.btnOut, function()
         UIManager.OpenPanel(UIName.ResolvePanel,5)
    end)
    Util.AddClick(this.btnFetter, function()
        UIManager.OpenPanel(UIName.PokemonListPanel,Pokemon_Popup_Type.PokemonListPanel_Fetter)
    end)
    Util.AddClick(this.btnPokemonList, function()
        UIManager.OpenPanel(UIName.PokemonListPanel,Pokemon_Popup_Type.PokemonListPanel_List)
    end)
    BindRedPointObject(RedPointType.Pokemon_Recruit, this.btnInfoRed)
    BindRedPointObject(RedPointType.Pokemon_Fetter, this.btnFetterRed)
    BindRedPointObject(RedPointType.Pokemon_ChipCompound, this.btnPokemonListRed)
end

--添加事件监听（用于子类重写）
function PokemonMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Pokemon.PokemonUpZhenRefresh,  this.ShowPokemonList)
end

--移除事件监听（用于子类重写）
function PokemonMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Pokemon.PokemonUpZhenRefresh,  this.ShowPokemonList)
end

--界面打开时调用（用于子类重写）
function PokemonMainPanel:OnOpen(...)
    -- 设置
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.LingShouUpLv })
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PokemonMainPanel:OnShow()
    this.ShowPokemonList()
    PokemonManager.CheckRedPointStatusPokemonMainCityRed()
end

local nextOpenLockIndex = 0
function this.ShowPokemonList()
    isClick = true
    this.line.transform:SetParent(this.roleGrid.transform)
    this.line.gameObject:SetActive(false)
    canUpZhenPokemonList = PokemonManager.GetCanUpZhenPokemonDatas()
    nextOpenLockIndex = 0
    PokemonDataList = PokemonManager.GetAllPokemonFormationData()
    for i = 1, #PokemonList do
        this.ShowSinglePokemonList(PokemonList[i],PokemonDataList[i],i)
    end
end

function this.SaveFormation()
    --保存编队
    
end

function this.ShowSinglePokemonList(go,singleData,liveIndex)
    local goParent = go.transform.parent.gameObject
    goParent:SetActive(true)
    local bgQuan = Util.GetGameObject(goParent, "bg/Image (1)")
    local upZhenInfo = Util.GetGameObject(go, "upZhenInfo")
    local addInfo = Util.GetGameObject(go, "addInfo")
    local lockInfo = Util.GetGameObject(go, "lockInfo")
    upZhenInfo:SetActive(false)
    addInfo:SetActive(false)
    lockInfo:SetActive(false)
    
    local state = 1--1 未解锁 隐藏 2 即将解锁 3 已解锁 未上阵 4 已解锁 已上阵
    if pokemonPosLocks[liveIndex] <= PlayerManager.level then
        state = 3
        if singleData and singleData.pokemonId then
            state = 4
        end
    else
        if nextOpenLockIndex <= 0 then
            nextOpenLockIndex = liveIndex
            state = 2
        end
    end
    bgQuan:SetActive(true)
    dragViewListGo[liveIndex].gameObject:SetActive(false)
    PokemonGoListRedPoin[liveIndex]:SetActive(false)
    if state == 1 then
        --什么都不用做
        go.transform.parent.gameObject:SetActive(false)
    elseif state == 2 then
        lockInfo:SetActive(true)
        Util.GetGameObject(go, "lockInfo/lockInfo/lvImage/Text"):GetComponent("Text").text = string.format(GetLanguageStrById(11947), pokemonPosLocks[liveIndex])
        Util.AddOnceClick( Util.GetGameObject(go, "lockInfo/lockInfo/lockClick"), function()
            PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11947), pokemonPosLocks[liveIndex]))
        end)
    elseif state == 3 then
        addInfo:SetActive(true)
        PokemonGoListRedPoin[liveIndex]:SetActive(#canUpZhenPokemonList > 0)
        Util.AddOnceClick( Util.GetGameObject(go, "addInfo/addInfo/addClick"..liveIndex), function()
            UIManager.OpenPanel(UIName.PokemonListPanel,Pokemon_Popup_Type.PokemonListPanel_UpWar,nil,liveIndex)
        end)
    elseif state == 4 then
        bgQuan:SetActive(false)
         local curData = PokemonManager.GetSinglePokemonData( singleData.pokemonId)
        dragViewListGo[liveIndex].gameObject:SetActive(true)
        local upLvRed = PokemonManager.GetSinglePokemonUpLvRedPoint(curData)
        local upStarRed = PokemonManager.GetSinglePokemonUpStarRedPoint(curData)
        
        PokemonGoListRedPoin[liveIndex]:SetActive(upLvRed or upStarRed)
        upZhenInfo:SetActive(true)
        local spiritAnimalConfig = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,curData.id)
        Util.GetGameObject(go, "upZhenInfo/titleImage/nameText"):GetComponent("Text").text =   GetStringByEquipQua(spiritAnimalConfig.Quality, spiritAnimalConfig.Name)
        Util.GetGameObject(go, "upZhenInfo/lvImage/Text"):GetComponent("Text").text = string.format(GetLanguageStrById(22318), curData.lv)
        local curPokemonLive = Util.GetGameObject(go, "upZhenInfo/pokemonLive")
         for key, value in pairs(live2dList) do
            if key == liveIndex then
                
                 poolManager:UnLoadLive(live2dList[key].name, live2dList[key].go, PoolManager.AssetType.GameObject)
                 live2dList[key] = nil
            end
         end
        local LiveName = curData.live
        this.LoadHerolive(LiveName,curPokemonLive)
        -- local live2d = poolManager:LoadLive(LiveName,  curPokemonLive.transform,Vector3.one *curData.scale * 0.4, Vector3.New(spiritAnimal[curData.id].littleScalePosition[1],spiritAnimal[curData.id].littleScalePosition[2],0))--curData.scale
        -- live2dList[liveIndex] = {name=curData.live, go=live2d}
        -- local SkeletonGraphic = live2d:GetComponent("SkeletonGraphic")
        -- local idle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
        -- SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
        local starSize = Vector2.New(65,65)
        PokemonManager.SetHeroStars(Util.GetGameObject(go, "upZhenInfo/starGrid/starGrid(Clone)"), curData.star)
        -- Util.AddOnceClick( Util.GetGameObject(go, "upZhenInfo/upZhenClick"), function()
        --     UIManager.OpenPanel(UIName.PokemonInfoPanel,curData,PokemonManager.GetPokemonUpZhenDatas())
        -- end)
          --英雄长按
          local heroClick=Util.GetGameObject(PokemonList[liveIndex],"DragView"..liveIndex)
        --   Util.AddLongPressClick(heroClick, function()
        --   end, 0.5)
            Util.AddOnceClick(heroClick, function()
                if isClick then
                    UIManager.OpenPanel(UIName.PokemonInfoPanel,curData,PokemonManager.GetPokemonUpZhenDatas())
                end
            end)
    end
end
function this.LoadHerolive(_heroData, _objPoint)
    -- TODO:动态加载立绘
    
    if Util.GetGameObject(_objPoint.transform, "TestImg") then
        destroy(Util.GetGameObject(_objPoint.transform, "TestImg"))
    end
    local roleStaticImg = poolManager:LoadAsset(_heroData, PoolManager.AssetType.GameObject)
    roleStaticImg.transform:SetParent(_objPoint.transform)
    roleStaticImg.transform.localScale = Vector3.one --m5
    roleStaticImg.transform.localPosition = Vector3.zero
    roleStaticImg.name = "TestImg"
    -- local testLive = poolManager:LoadAsset(GetResourcePath(spiritAnimal[_heroData.id].Live), PoolManager.AssetType.GameObject)
    -- testLive:parent
    -- local SkeletonGraphic = testLive:GetComponent("SkeletonGraphic")
    -- local idle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
    -- SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
    -- poolManager:SetLiveClearCall(GetResourcePath(spiritAnimal[_heroData.id].Live), testLive, function ()
    --     SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idle
    -- end)
    return roleStaticImg
end



--拖拽
function this.OnPointerDown(Pointgo,data)--按下
    local _j=tonumber(string.sub(Pointgo.transform.name,-1))
    local pokemonObj=Util.GetTransform(Pointgo.transform.parent,"pokemon".._j)
    pokemonObj:DOScale(Vector3.one * 1.2, 0.15)
    pokemonObj.transform:SetParent(this.root.transform)
    pokemonObj:GetComponent("Image").raycastTarget = false
end
function this.OnPointerUp(Pointgo,data)--抬起
    local _j=tonumber(string.sub(Pointgo.transform.name,-1))
    Util.Peer(Pointgo.transform,"Pos").transform:SetAsFirstSibling()
    local pokemonObj=Util.GetTransform(this.gameObject,"pokemon".._j)
    pokemonObj:DOScale(Vector3.one * 1, 0.15)
    pokemonObj.transform:SetParent(PokemonList[_j].transform)
    pokemonObj.transform:SetSiblingIndex(1)--SetAsFirstSibling()
    pokemonObj:GetComponent("Image").raycastTarget = false
end
function this.OnEndDrag(Pointgo,data)--结束拖动
    isClick = true
    local _j=tonumber(string.sub(Pointgo.transform.name,-1))
    local pokemonObj=Util.GetGameObject(this.gameObject,"pokemon".._j)
    if data.pointerEnter==nil then--防止拖到屏幕外
        pokemonObj.transform:DOAnchorPos(Vector3.one,0)
        pokemonObj.transform:SetParent(PokemonList[_j].transform)
        pokemonObj.transform:SetSiblingIndex(1)
        return
    end
    
    local _i=tonumber(string.sub(data.pointerEnter.gameObject.name,-1))
    local nameIn=data.pointerEnter.gameObject.name --进入的UI名
    local _num=string.sub(nameIn,5,-1)
    local itemName="item".._num

    local pokemonObj=Util.GetGameObject(this.gameObject,"pokemon".._j)
    pokemonObj:GetComponent("Image").raycastTarget = true
    pokemonObj.transform:DOScale(Vector3.one * 1, 0.15)
    pokemonObj.transform:DOAnchorPos(Vector3.one,0)
    pokemonObj.transform:SetParent(PokemonList[_j].transform)
    pokemonObj.transform:SetSiblingIndex(1)

    if _i==nil then
        _i=tonumber(string.sub(Pointgo.transform.name,-1))
    end
    if nameIn=="DragView".._i then --有人
        
        local curData
        local tarData
        for i, v in ipairs(PokemonDataList ) do
            if _j==v.position then
                curData=v.pokemonId
            end
            if _i==v.position then
                tarData=v.pokemonId
            end
        end
        for i, v in ipairs(PokemonDataList) do
            if _j==v.position then
                PokemonDataList[i].pokemonId=tarData
            end
            if _i==v.position then
                PokemonDataList[i].pokemonId=curData
            end
        end
    elseif nameIn=="addClick".._i  then
        local did
        for i, v in ipairs(PokemonDataList) do
            if _j==v.position then
                did=v.pokemonId
                v.pokemonId = nil
            end
        end
        for i, v in ipairs(PokemonDataList) do
            if _i==v.position then
                v.pokemonId=did
            end
        end
    end
    this.line.gameObject:SetActive(false)
    NetManager.ReplaceTeamPokemonInfoRequest(PokemonDataList, function()
        local oldWarPower = 0
        PokemonManager.RefreshPokemonFormation(PokemonDataList)
        local newWarPower = 0
        --飘战力
        PokemonManager.PiaoWarPowerChange(oldWarPower,newWarPower)
    end)
    this.ShowPokemonList()
end
function this.OnDrag(Pointgo,data)--拖动中
    isClick = false
    if data.pointerEnter==nil then--拖到屏幕外
        this.line.transform:SetParent(this.roleGrid.transform)
        this.line.gameObject:SetActive(false)
        return
    end
    local _i=tonumber(string.sub(data.pointerEnter.gameObject.name,-1))
    if _i==nil then _i=0 end
    local nameIn=data.pointerEnter.gameObject.name --进入的UI名
    
    this.line:SetActive(nameIn=="DragView".._i or nameIn=="singlePokemon (".._i..")" or nameIn=="addClick".._i)
    if nameIn=="DragView".._i then
        this.line.transform:SetParent(PokemonList[_i].transform)
        this.line:GetComponent("RectTransform").localPosition = Vector3.New(-17,-93,0) --m5
        this.line:GetComponent("RectTransform").localScale = Vector3.New(1,1,1)
    elseif nameIn=="singlePokemon (".._i..")" then
        this.line.transform:SetParent(PokemonList[_i].transform)
        this.line:GetComponent("RectTransform").localPosition = Vector3.New(-17,-93,0) --m5
        this.line:GetComponent("RectTransform").localScale = Vector3.New(1,1,1)
    elseif nameIn=="addClick".._i then
        this.line.transform:SetParent(PokemonList[_i].transform)
        this.line:GetComponent("RectTransform").localPosition = Vector3.New(-17,-93,0) --m5
        this.line:GetComponent("RectTransform").localScale = Vector3.New(1,1,1)
    else
        this.line.transform:SetParent(this.roleGrid.transform)
        this.line.gameObject:SetActive(false)
    end
    this.line.transform:SetAsFirstSibling()
    -- if panelType == FORMATION_TYPE.EXPEDITION or panelType == FORMATION_TYPE.CARBON then
    --     this.line.transform:DOAnchorPos(Vector3.New(0,15,0),0)
    -- else
    --     this.line.transform:DOAnchorPos(Vector3.New(0,30,0),0)
    -- end
end




--界面关闭时调用（用于子类重写）
function PokemonMainPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function PokemonMainPanel:OnDestroy()   
    ClearRedPointObject(RedPointType.Pokemon_Recruit, this.btnInfoRed)
    ClearRedPointObject(RedPointType.Pokemon_Fetter, this.btnFetterRed)
    ClearRedPointObject(RedPointType.Pokemon_ChipCompound, this.btnPokemonListRed)
    SubUIManager.Close(this.UpView)
    dragViewListGo={}
    for key, value in pairs(live2dList) do
        poolManager:UnLoadLive(live2dList[key].name, live2dList[key].go, PoolManager.AssetType.GameObject)
        live2dList[key] = nil
    end
end

return PokemonMainPanel