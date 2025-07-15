require("Base/BasePanel")
PokemonInfoPanel = Inherit(BasePanel)
local this = PokemonInfoPanel
--升级升星
local spiritAnimal = ConfigManager.GetConfig(ConfigName.SpiritAnimal)
local curPokemonData--当前灵兽信息
local curPokemonConFigData = {}
local leftPokemonData--左边预加载灵兽信息
local rightPokemonData--右边预加载灵兽信息
local pokemonDatas--所有灵兽list信息
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local heroRankupConfig = ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local curDataByListIndex--当前灵兽在 灵兽列表中的索引
local allAddProVal={}--所有属性加成值
local isClickLeftOrRightBtn = true--点击左右按钮切换灵兽播放动画状态
local upZhenDidis
local TabBox = require("Modules/Common/TabBox")
local _TabData={ [1] = { default = "m5_btn_fenye2", select = "m5_btn_fenye1", name = GetLanguageStrById(11097) },--m5
                 [2] = { default = "m5_btn_fenye2", select = "m5_btn_fenye1", name = GetLanguageStrById(12471) },--m5
}
local _TabFontColor = { default = Color.New(190 / 255, 190 / 255, 190 / 255, 1), --m5
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1)}
local curIndex = 0
local sortIndex=0
this.prefabs = {}
this.contents = {
    [1] = {view = require("Modules/Pokemon/view/PokemonInfoPanel_UpLv"), panelName = "PokemonInfoPanel_UpLv"},
    [2] = {view = require("Modules/Pokemon/view/PokemonInfoPanel_UpStar"), panelName = "PokemonInfoPanel_UpStar"},
}
local isHideLeftRihtBtn = false
local redPointList = {}
--初始化组件（用于子类重写）
function PokemonInfoPanel:InitComponent()
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.tabBox = Util.GetGameObject(self.transform, "TabBox")
   
    this.live2dRoot = Util.GetGameObject(self.gameObject, "live2dRoot")
    this.bg = Util.GetGameObject(self.gameObject, "bg")
    this.starGrid = Util.GetGameObject(self.transform, "starGrid/starGrid(Clone)")
   
    this.namne = Util.GetGameObject(self.transform, "nameInfo/nameText"):GetComponent("Text")
    this.sortText = Util.GetGameObject(self.transform, "nameInfo/sortText")
    this.upZhenImage = Util.GetGameObject(self.transform, "nameInfo/upZhenImage")

    this.leftBtn = Util.GetGameObject(self.transform, "leftBtn/GameObject")
    this.rightBtn = Util.GetGameObject(self.transform, "rightBtn/GameObject")

    this.curObj= Util.GetGameObject(self.transform, "curObj")
    this.leftObj= Util.GetGameObject(self.transform, "leftObj")
    this.rightObj= Util.GetGameObject(self.transform, "rightObj")

    this.nirvanaBtn=Util.GetGameObject(self.transform,"nirvanaBtn")
    this.replaceBtn=Util.GetGameObject(self.transform,"rightBtnList/replaceBtn")
    this.restBtn=Util.GetGameObject(self.transform,"rightBtnList/restBtn")

    this.dragView = SubUIManager.Open(SubUIConfig.DragView, self.gameObject.transform)
    this.dragView.transform:SetSiblingIndex(1)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft})
    screenAdapte(self.bg)
   
    this.trigger=Util.GetEventTriggerListener(this.dragView.gameObject)
    this.trigger.onBeginDrag = this.trigger.onBeginDrag + this.OnBeginDrag
    this.trigger.onDrag = this.trigger.onDrag + this.OnDrag
    this.trigger.onEndDrag = this.trigger.onEndDrag + this.OnEndDrag

    for i=1,#this.contents do
        this.prefabs[i]=Util.GetGameObject(self.gameObject,this.contents[i].panelName)
        this.contents[i].view:InitComponent(Util.GetGameObject(self.gameObject, "layout"))
    end
end
--绑定事件（用于子类重写）
function PokemonInfoPanel:BindEvent()
    for i = 1, #this.contents do
        this.contents[i].view:BindEvent()
    end
    Util.AddClick(this.BtnBack, function()
        -- PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    --左切换按钮
    Util.AddClick(this.leftBtn, function()
        this:LeftBtnOnClick()
    end)
    --右切换按钮
    Util.AddClick(this.rightBtn, function()
        this:RightBtnOnClick()
    end)
    Util.AddClick(this.dragView.gameObject, function()
        -- local SkeletonGraphic = this.curLiveObj:GetComponent("SkeletonGraphic")
        -- SkeletonGraphic.AnimationState:SetAnimation(0, "attack", false)
    end)
    --涅槃
    Util.AddClick(this.nirvanaBtn, function()
        if sortIndex>0 then
            PopupTipPanel.ShowTipByLanguageId(23090)
            return
        end
        if curPokemonData.lv==1 and curPokemonData.star <= 0 then
            PopupTipPanel.ShowTipByLanguageId(23091)
            return
        end

        local lv=curPokemonData.lv
        local star=curPokemonData.star
        local qua=curPokemonData.config.Quality
        --所有材料
        local allMaterials={}
        --升级消耗
        local lvConfig=ConfigManager.GetConfigDataByDoubleKey(ConfigName.SpiritAnimalLevel,"Level",lv,"Quality",qua)
        if lvConfig then
            local matrs=lvConfig.SumConsume
            if matrs then
            for i = 1, #matrs do
                local mat=matrs[i]
                table.insert(allMaterials,{mat[1],mat[2]})
            end
            end        
        end
        --升星消耗
        local lingshouConfig=ConfigManager.GetConfigData(ConfigName.SpiritAnimal,curPokemonData.id)
        if star>0 then
            local starConfig=ConfigManager.GetConfigDataByDoubleKey(ConfigName.SpiritAnimalStar,"Star",star,"Quality",qua)
            if starConfig then       
                --消耗本体数量,分解成碎片               
                if starConfig.SumItemNum>=1 then
                    table.insert(allMaterials,{curPokemonData.id,starConfig.SumItemNum})
                end
                local starMatrs=starConfig.SumConsume
                --消耗材料
                if starMatrs then
                    for i = 1, #starMatrs do
                    local starm=starMatrs[i]
                    table.insert(allMaterials,{starm[1],starm[2]})
                    end
                end
            end
        end       
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.PokemonResolve,lingshouConfig,allMaterials,function ()
            NetManager.PokemonBackRequest(curPokemonData.dynamicId,function(msg)
               -- this.OnClickTabBtn(curIndex)
                PopupTipPanel.ShowTipByLanguageId(23092)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                PokemonManager.UpdateSinglePokemonData(curPokemonData.dynamicId,1,0)   
                curPokemonData = PokemonManager.GetSinglePokemonData(curPokemonData.dynamicId)
                -- this.OnShowData()
                -- this.OnShowRedPoint()   
                this.contents[curIndex].view:OnShow(this,curPokemonData)            
            end)
        end)
    end)
    end)
    --替换
    Util.AddClick(this.replaceBtn, function()
        UIManager.OpenPanel(UIName.PokemonListPanel,Pokemon_Popup_Type.PokemonListPanel_UpWar,curPokemonData)
    end)
    --休息  下阵
    Util.AddClick(this.restBtn, function()
        --下阵协议
        local oldWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
        local curFormation = PokemonManager.GetAllPokemonFormationData()
        for i = 1, #curFormation do
            if curFormation[i] and curFormation[i].pokemonId and curFormation[i].pokemonId == curPokemonData.dynamicId then
                    curFormation[i].pokemonId = nil
            end
        end
        NetManager.ReplaceTeamPokemonInfoRequest(curFormation, function()
            PokemonManager.RefreshPokemonFormation(curFormation)
            local newWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            --飘战力
            PokemonManager.PiaoWarPowerChange(oldWarPower,newWarPower)
            pokemonDatas = {curPokemonData}
            isHideLeftRihtBtn = true
            this.leftBtn.transform.parent.gameObject:SetActive(false)
            this.rightBtn.transform.parent.gameObject:SetActive(false)
        end)
        this.OnShowData()
        -- this.OnShowRedPoint()
    end)
end

--添加事件监听（用于子类重写）
function PokemonInfoPanel:AddListener()
    for i = 1, #this.contents do
        this.contents[i].view:AddListener()
    end
end

--移除事件监听（用于子类重写）
function PokemonInfoPanel:RemoveListener()
    for i = 1, #this.contents do
        this.contents[i].view:RemoveListener()
    end
end

--界面打开时调用（用于子类重写）
function PokemonInfoPanel:OnOpen(_curPokemonData, _pokemonDatas,_isHideLeftRihtBtn)
    curPokemonData, pokemonDatas = _curPokemonData, _pokemonDatas
    isHideLeftRihtBtn = _isHideLeftRihtBtn or false
    curIndex = 1
    if isHideLeftRihtBtn then
        this.leftBtn.transform.parent.gameObject:SetActive(false)
        this.rightBtn.transform.parent.gameObject:SetActive(false)
    else
        this.leftBtn.transform.parent.gameObject:SetActive(true)
        this.rightBtn.transform.parent.gameObject:SetActive(true)
    end
end
function this.RefreshShow(_curPokemonData, _pokemonDatas)
    if this.leftLiveObj and leftPokemonData then
        poolManager:UnLoadLive(leftPokemonData.live, this.leftLiveObj)
        this.leftLiveObj = nil
    end
    if this.rightLiveObj and rightPokemonData then
        poolManager:UnLoadLive(rightPokemonData.live, this.rightLiveObj)
        this.rightLiveObj = nil
    end
    if this.curLiveObj and curPokemonData then
        poolManager:UnLoadLive(curPokemonData.live, this.curLiveObj)
        this.curLiveObj = nil
    end
    curPokemonData, pokemonDatas = _curPokemonData, _pokemonDatas
    this.OnShowData()
    this.contents[curIndex].view:OnShow(this,curPokemonData)
end
function PokemonInfoPanel:OnSortingOrderChange()
    for i = 1, #this.contents do
        this.contents[i].view:OnSortingOrderChange(self.sortingOrder)
    end
end

function PokemonInfoPanel:OnShow()
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData,curIndex)
    redPointList = {}
    for i = 1, #_TabData do
        local curTabBtn = Util.GetGameObject(this.tabBox, "box").transform:GetChild(i-1)
        redPointList[i] = Util.GetGameObject(curTabBtn, "Redpot")
    end
    this.OnShowData()
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    local tabImage = Util.GetGameObject(tab,"Image")
    tabImage:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabImage:GetComponent("Image"):SetNativeSize()
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
    -- tabImage.transform.localPosition = Vector3.New( tabImage.transform.localPosition.x, _TabImagePos[status], 0);
end
--切换视图
function this.SwitchView(index)
    --先执行上一面板关闭逻辑
    local oldSelect
    oldSelect, curIndex = curIndex, index
    for i = 1, #this.contents do
        if oldSelect~=0 then this.contents[oldSelect].view:OnClose() break end
    end
    --切换预设显隐
    for i = 1, #this.prefabs do
        this.prefabs[i].gameObject:SetActive(i == index)--切换子模块预设显隐
    end
    --区分显示
    if index==1 then
        this.UpView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.LingShouUpLv})
    elseif index==2 then
        this.UpView:OnOpen({showType = UpViewOpenType.ShowLeft, panelType = PanelType.LingShouUpStar})
    end
    --执行子模块初始化
    this.contents[index].view:OnShow(this,curPokemonData)
end

function this.OnShowData()
    isClickLeftOrRightBtn = true
    for i = 1, #pokemonDatas do
        if curPokemonData.dynamicId == pokemonDatas[i].dynamicId then
            curDataByListIndex = i
        end
    end
    this.UpdateLiveList()--加载当前 和 左右数据
    if this.leftLiveObj and leftPokemonData then
        poolManager:UnLoadLive(leftPokemonData.live, this.leftLiveObj)
        this.leftLiveObj = nil
    end
    if this.rightLiveObj and rightPokemonData then
        poolManager:UnLoadLive(rightPokemonData.live, this.rightLiveObj)
        this.rightLiveObj = nil
    end
    if this.curLiveObj and curPokemonData then
        poolManager:UnLoadLive(curPokemonData.live, this.curLiveObj)
        this.curLiveObj = nil
    end
    Util.ClearChild(this.curObj.transform)
    Util.ClearChild(this.leftObj.transform)
    Util.ClearChild(this.rightObj.transform)
    this.leftLiveObj = this.LoadHerolive(leftPokemonData,this.leftObj)
    this.rightLiveObj = this.LoadHerolive(rightPokemonData,this.rightObj)
    this.curLiveObj = this.LoadHerolive(curPokemonData,this.curObj)
    if this.curLiveObj then
        this.dragView.gameObject:SetActive(true)
        this.dragView:SetDragGO(this.curLiveObj)
    else
        this.dragView.gameObject:SetActive(false)
    end 
    curPokemonConFigData =  spiritAnimal[curPokemonData.id]
    this.UpdateHeroInfoData()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.LingShouUpLv })
    FixedUpdateBeat:Add(this.OnUpdate, self)--长按方法注册
    this.replaceBtn:SetActive(upZhenDidis[curPokemonData.dynamicId] ~= nil)
    this.restBtn:SetActive(upZhenDidis[curPokemonData.dynamicId] ~= nil)
    this.OnShowRedPoint()
end

--长按升级处理
function this.OnUpdate()
    for i = 1, #this.contents do
        this.contents[i].view.OnUpdate()
    end
end

--更新界面已存数据
function this.UpdateLiveList()
    local leftIndex = (curDataByListIndex - 1 > 0 and curDataByListIndex - 1 or #pokemonDatas)
    leftPokemonData = pokemonDatas[leftIndex]
    curPokemonData = pokemonDatas[curDataByListIndex]
    local rightIndex = (curDataByListIndex + 1 <= #pokemonDatas and curDataByListIndex + 1 or 1)
    rightPokemonData = pokemonDatas[rightIndex]
    
end
--根据界面数据加载动态立绘
function this.LoadHerolive(_heroData, _objPoint)
    -- TODO:动态加载立绘
    
    local roleStaticImg = poolManager:LoadAsset(GetResourcePath(spiritAnimal[_heroData.id].Live), PoolManager.AssetType.GameObject)
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
--更新灵兽情报数据
function this.UpdateHeroInfoData()
    if this.curLiveObj then
        this.dragView.gameObject:SetActive(true)
        this.dragView:SetDragGO(this.curLiveObj)
    else
        this.dragView.gameObject:SetActive(false)
    end 
    local starSize = Vector2.New(65,65)
    PokemonManager.SetHeroStars(this.starGrid, curPokemonData.star)
    --SetHeroStars(starGrid, heroData.star)
    --常规属性赋值
    upZhenDidis = PokemonManager.GetAllPokemonFormationDids()
    sortIndex = upZhenDidis[curPokemonData.dynamicId] and upZhenDidis[curPokemonData.dynamicId].position or 0
    this.namne.text = GetStringByEquipQua(curPokemonConFigData.Quality, curPokemonConFigData.Name)
    this.sortText:SetActive(sortIndex > 0)
    this.sortText:GetComponent("Text").text = sortIndex
    this.upZhenImage:SetActive(sortIndex > 0)
end


--右切换按钮点击
function this.RightBtnOnClick()
    if isClickLeftOrRightBtn == false then
        return
    end
    isClickLeftOrRightBtn = false
    this.rightBtn:GetComponent("Button").enabled = false
    local oldIndexConfigData = pokemonDatas[curDataByListIndex]
    curDataByListIndex = (curDataByListIndex + 1 <= #pokemonDatas and curDataByListIndex + 1 or 1)
    curPokemonData = pokemonDatas[curDataByListIndex]
    if this.leftLiveObj then
        poolManager:UnLoadLive(leftPokemonData.live, this.leftLiveObj)
        this.leftLiveObj = nil
    end
    this.curLiveObj.transform:SetParent(this.leftObj.transform)
    this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(Vector2.New(oldIndexConfigData.position[1],oldIndexConfigData.position[2]), 0.5, false):SetEase(Ease.Linear)
    this.rightLiveObj.transform:SetParent(this.curObj.transform)
    this.rightLiveObj:GetComponent("RectTransform"):DOAnchorPos(Vector2.New(rightPokemonData.position[1],rightPokemonData.position[2]), 0.5, false):OnComplete(function ()
        this:UpdateLiveList()
        this.leftLiveObj = this.curLiveObj
        this.curLiveObj = this.rightLiveObj
        this.rightLiveObj = this.LoadHerolive(rightPokemonData,this.rightObj)
        this.OnShowData()
        this.contents[curIndex].view:OnShow(this,curPokemonData)
        -- local SkeletonGraphic = this.curLiveObj:GetComponent("SkeletonGraphic")
        -- SkeletonGraphic.AnimationState:SetAnimation(0, "attack", false)
        this.rightBtn:GetComponent("Button").enabled = true
        isClickLeftOrRightBtn = true
    end):SetEase(Ease.Linear)
end
--左切换按钮点击
function this.LeftBtnOnClick()
    if isClickLeftOrRightBtn == false then
        return
    end
    isClickLeftOrRightBtn = false
    this.leftBtn:GetComponent("Button").enabled = false
    local oldIndexConfigData = pokemonDatas[curDataByListIndex]
    curDataByListIndex = (curDataByListIndex - 1 > 0 and curDataByListIndex - 1 or #pokemonDatas)
    curPokemonData = pokemonDatas[curDataByListIndex]
    if this.rightLiveObj then
        poolManager:UnLoadLive(rightPokemonData.live, this.rightLiveObj)
        this.rightLiveObj = nil
    end
    this.curLiveObj.transform:SetParent(this.rightObj.transform)
    this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(Vector2.New(oldIndexConfigData.position[1],oldIndexConfigData.position[2]), 0.5, false):SetEase(Ease.Linear)
    this.leftLiveObj.transform:SetParent(this.curObj.transform)
    this.leftLiveObj:GetComponent("RectTransform"):DOAnchorPos(Vector2.New(leftPokemonData.position[1],leftPokemonData.position[2]), 0.5, false):OnComplete(function ()
        this:UpdateLiveList()
        this.rightLiveObj = this.curLiveObj
        this.curLiveObj = this.leftLiveObj
        this.leftLiveObj = this.LoadHerolive(leftPokemonData,this.leftObj)
        this.OnShowData()
        this.contents[curIndex].view:OnShow(this,curPokemonData)
        -- local SkeletonGraphic = this.curLiveObj:GetComponent("SkeletonGraphic")
        -- SkeletonGraphic.AnimationState:SetAnimation(0, "attack", false)
        this.leftBtn:GetComponent("Button").enabled = true
        isClickLeftOrRightBtn = true
    end):SetEase(Ease.Linear)
end

function this.SortpokemonDatas(_pokemonDatas)
    --上阵最优先，星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_pokemonDatas, function(a, b)
        if a.heroConfig.Natural ==b.heroConfig.Natural then
            if a.star == b.star then
                if a.lv == b.lv then
                    return a.heroConfig.Id < b.heroConfig.Id
                else
                    return a.lv > b.lv
                end
            else
                return a.star > b.star
            end
        else
            return a.heroConfig.Natural > b.heroConfig.Natural
        end
    end)
end
local beginV3
local endV3
local distance
function this.OnBeginDrag(Pointgo, data)
    beginV3=this.curLiveObj.transform.anchoredPosition
end
function this.OnDrag(Pointgo, data)
    distance=Vector2.Distance(beginV3,this.curLiveObj.transform.anchoredPosition)
end
function this.OnEndDrag(Pointgo, data)
    endV3=this.curLiveObj.transform.anchoredPosition
    if distance>250 and endV3.x<0 then
        this:RightBtnOnClick()
    elseif distance>250 and endV3.x>0 then
        this:LeftBtnOnClick()
    else
        this.curLiveObj:GetComponent("RectTransform"):DOAnchorPos(Vector2.New(curPokemonData.position[1],curPokemonData.position[2]), 0.5, false):SetEase(Ease.Linear)
    end
    distance=0
end

--刷新页签红点方法
function this.RefreshRedPoint(tabType,isShow)
    
    if redPointList[tabType] and redPointList[tabType].gameObject then
        redPointList[tabType]:SetActive(isShow)
    end
end

function  this.OnShowRedPoint()
    if redPointList[1] and redPointList[1].gameObject then
        redPointList[1]:SetActive(PokemonManager.GetSinglePokemonUpLvRedPoint(curPokemonData))
    end
    if redPointList[2] and redPointList[2].gameObject then
        redPointList[2]:SetActive(PokemonManager.GetSinglePokemonUpStarRedPoint(curPokemonData))
    end
end
--界面关闭时调用（用于子类重写）
function PokemonInfoPanel:OnClose()
    for i = 1, #this.contents do
        this.contents[i].view:OnClose()
    end
    --this.globalcurPokemonData=nil
    if this.leftLiveObj and leftPokemonData then
        poolManager:UnLoadLive(leftPokemonData.live, this.leftLiveObj)
        this.leftLiveObj = nil
    end
    if this.rightLiveObj and rightPokemonData then
        poolManager:UnLoadLive(rightPokemonData.live, this.rightLiveObj)
        this.rightLiveObj = nil
    end
    if this.curLiveObj and curPokemonData then
        poolManager:UnLoadLive(curPokemonData.live, this.curLiveObj)
        this.curLiveObj = nil
    end
    this.leftBtn:GetComponent("Button").enabled = true
    this.rightBtn:GetComponent("Button").enabled = true
    FixedUpdateBeat:Remove(this.OnUpdate, self)
end

--界面销毁时调用（用于子类重写）
function PokemonInfoPanel:OnDestroy()
    redPointList = {}
    for i = 1, #this.contents do
        this.contents[i].view:OnDestroy()
    end
    this.pinjieList={}
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(SubUIConfig.DragView, this.dragView)
end
return PokemonInfoPanel