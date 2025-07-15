----- 灵兽升级 -----
local this = {}
local sortingOrder=0
local isUpLvMaterials=true--升级 突破 材料是否充足
local lvUpShowProList={}--升级后展示的属性提升list

--长按升级状态
local _isClicked = false
local _isReqLvUp = false
local _isLongPress = false
this.timePressStarted = 0--监听长按事件
this.priThread = nil--协同程序播放升级属性提升值动画用
local isTriggerLongClick = false--长按是否升过级

local curPokemonData = {}
local proList = {}
local oldLv
local allAddProVal
local parent
local isMaterial = 0--升级材料是否充足
local isLvEnd = false--是否满级
local curUpLvConsume = {}--升级材料
function this:InitComponent(gameObject)
   --情报
   Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/Image/Text"):GetComponent("Text").text = GetLanguageStrById(11857)
   Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/Image (1)/Text"):GetComponent("Text").text = GetLanguageStrById(12485)
   Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/Image (2)/Text"):GetComponent("Text").text = GetLanguageStrById(11843)
   Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/tipText"):GetComponent("Text").text = GetLanguageStrById(23097)--m5
   Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/skill/skillName"):GetComponent("Text").text = GetLanguageStrById(12487)
    --技能
   this.skillIcon = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/skill/icon"):GetComponent("Image")
   this.skillLv = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/skill/skillImage/skillLv"):GetComponent("Text")
   this.skillClick = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/skill/skillClick")
   this.skillClick2 = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/skill/skillClick2")
   --属性
    for i = 1, 5 do
        proList[i] = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/pro/singlePro ("..i..")")
    end

   --升级
   this.upLvItemParent =  Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/upLvItemParent")
   this.upLvItemParentText =  Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/upLvItemParent/Text"):GetComponent("Text")
   this.materialView = SubUIManager.Open(SubUIConfig.ItemView, this.upLvItemParent.transform)
   this.upLvBtn = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/upLvBtn")
   this.upLvBtnRedPoint = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/upLvBtn/redPoint")
   this.upLvTrigger = Util.GetEventTriggerListener(this.upLvBtn)

   this.noUpLvText=Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/noUpLvText")
   this.lvUpGo=Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/lvUpGo")
   this.lvUpGoImage=Util.GetGameObject(gameObject,"PokemonInfoPanel_UpLv/lvUpGo/Image")

   for i = 1, 5 do
        lvUpShowProList[i]=Util.GetGameObject(this.lvUpGo.transform,"proPreParent/proPre"..i)
        lvUpShowProList[i]:SetActive(false)
   end
end

function this:BindEvent()
   --升级
   Util.AddClick(this.upLvBtn, function()
    if Time.realtimeSinceStartup - this.timePressStarted <= 0.4 then
        this.LvUpClick(true)
    end
end)
--长按升级按下状态
this._onPointerDown = function(Pointgo, data)
    -- isTriggerLongClick = false
    _isClicked = true
    this.timePressStarted = Time.realtimeSinceStartup
    oldLv = curPokemonData.lv
    allAddProVal = PokemonManager.GetSinglePokemonAddProData(curPokemonData.dynamicId)
end
--长按升级抬起状态
this._onPointerUp = function(Pointgo, data)
    
    if _isLongPress  then--and isTriggerLongClick
        --连续升级抬起请求升级
        
        this.LongLvUpClick(oldLv)
    end
    _isClicked = false
    _isLongPress = false
end
this.upLvTrigger.onPointerDown = this.upLvTrigger.onPointerDown + this._onPointerDown
this.upLvTrigger.onPointerUp = this.upLvTrigger.onPointerUp + this._onPointerUp
end

function this:AddListener()
    -- Game.GlobalEvent:AddEvent(GameEvent.Pokemon.PokemonMainPanelRefresh,  this.ShowPokemonInfo)
end

function this:RemoveListener()
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Pokemon.PokemonMainPanelRefresh,  this.ShowPokemonInfo)
end
local sortingOrder = 0
function this.OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
end
function this:OnShow(_parent,_pokemonData)
    parent = _parent
    curPokemonData = _pokemonData
    this.ShowPokemonInfo()
end


--长按升级处理
function this.OnUpdate()
    if _isClicked then
        if Time.realtimeSinceStartup - this.timePressStarted > 0.4 then
            _isLongPress = true
            
            if not _isReqLvUp then
                _isReqLvUp = true
                this.LvUpClick(false)
            end
        end
    end
end


--更新英雄升级材料显示
function this.ShowPokemonInfo()
    --属性
    local curAllPro = {}--加上等级
    local pokemonConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,curPokemonData.id)
    curAllPro[1] = {proName = GetLanguageStrById(10470),proValue = curPokemonData.lv.."/"..pokemonConFig.MaxLevel}
    local curPro = PokemonManager.GetSinglePokemonAddProData(curPokemonData.dynamicId)
    local index = 1
    for key, value in pairs(curPro) do
        local singleProData = {}
        singleProData.proName = ConfigManager.GetConfigData(ConfigName.PropertyConfig,key).Info
        singleProData.proValue = value
        index = index + 1
        curAllPro[index] = singleProData
    end
    local index = 0
    for key, value in pairs(curAllPro) do
        index = index + 1
        if proList[index] then
            Util.GetGameObject(proList[index], "Image"):GetComponent("Image").sprite = Util.LoadSprite(PropertyTypeIconDef[index])
            Util.GetGameObject(proList[index], "proName"):GetComponent("Text").text=curAllPro[key].proName
            Util.GetGameObject(proList[index], "proValue"):GetComponent("Text").text=curAllPro[key].proValue
        end
    end
    -- for i = 1, #proList do
    --     if PropertyTypeIconDef[i] then
    --         Util.GetGameObject(proList[i], "Image"):GetComponent("Image").sprite = Util.LoadSprite(PropertyTypeIconDef[i])
    --     end
    --     Util.GetGameObject(proList[i], "proName"):GetComponent("Text").text=curAllPro[i].proName
    --     Util.GetGameObject(proList[i], "proValue"):GetComponent("Text").text=curAllPro[i].proValue
    -- end
    --技能
    local curSkillId = PokemonManager.GetCurStarSkillId(curPokemonData.id,curPokemonData.star)
    
    local skillConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSkill,curSkillId)
    if skillConFig then
        this.skillIcon.sprite = Util.LoadSprite(GetResourcePath(skillConFig.Icon))
        this.skillLv.text = skillConFig.Level
    end
    Util.AddOnceClick(this.skillClick, function()
        UIManager.OpenPanel(UIName.PokemonSkillInfoPopup,curPokemonData.id,curPokemonData.lv,curPokemonData.star)
    end)
    Util.AddOnceClick(this.skillClick2, function()
        UIManager.OpenPanel(UIName.PokemonAllSkillInfoPopup,curPokemonData.id,curPokemonData.lv,curPokemonData.star)
    end)
    --升级消耗材料
    isMaterial = 0
    local upLvConFig = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.SpiritAnimalLevel,"Quality",pokemonConFig.Quality,"Level",curPokemonData.lv)
    isLvEnd = curPokemonData.lv >= pokemonConFig.MaxLevel
    this.noUpLvText:SetActive(isLvEnd)
    this.upLvItemParent:SetActive(not isLvEnd)
    this.upLvBtn:SetActive(not isLvEnd)
    if isLvEnd  then
        parent.RefreshRedPoint(1,false)
        this.upLvBtnRedPoint:SetActive(false)
        _isReqLvUp = false
        return
    end
    if upLvConFig.Consume then
        this.materialView:OnOpen(false, {upLvConFig.Consume[1][1],0}, 0.97)
    end
    curUpLvConsume = upLvConFig.Consume
    for i = 1, #curUpLvConsume do
        local curMaterialBagNum = BagManager.GetItemCountById(upLvConFig.Consume[i][1])
        if curMaterialBagNum >= upLvConFig.Consume[i][2] then
            this.upLvItemParentText.text = string.format("<color=#FFFFFF>%s/%s</color>",PrintWanNum2(curMaterialBagNum),PrintWanNum2(upLvConFig.Consume[i][2]))
        else
            isMaterial = upLvConFig.Consume[i][1]
            this.upLvItemParentText.text = string.format("<color=#FF0000>%s/%s</color>",PrintWanNum2(curMaterialBagNum),PrintWanNum2(upLvConFig.Consume[i][2]))
        end
    end
    if isMaterial ~= 0 then
        parent.RefreshRedPoint(1,false)
        this.upLvBtnRedPoint:SetActive(false)
    else
        parent.RefreshRedPoint(1,true)
        this.upLvBtnRedPoint:SetActive(true)
    end
end
--长按升级结束后请求协议
function this.LongLvUpClick(oldLv)
    local oldWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
    NetManager.UpPokemonLevelRequest(curPokemonData.dynamicId,curPokemonData.lv,oldLv,function (msg)
        PokemonManager.UpdateSinglePokemonData(curPokemonData.dynamicId,msg.level,curPokemonData.star)
        curPokemonData = PokemonManager.GetSinglePokemonData(curPokemonData.dynamicId)
        local allAddProValNet = PokemonManager.GetSinglePokemonAddProData(curPokemonData.dynamicId)
        this.ShowProAddVal(allAddProValNet)
        this.ShowPokemonInfo()
        _isReqLvUp = false
        local newWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
        PokemonManager.PiaoWarPowerChange(oldWarPower,newWarPower)
        FormationManager.CheckHeroIdExist()
    end)
end
--升级按钮点击事件处理
function this.LvUpClick(isSingleLvUp)
    --各种判断能否升级
    
    if isMaterial ~= 0 then
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12488), ConfigManager.GetConfigData(ConfigName.ItemConfig,isMaterial).Name))
        return
    end
    if isLvEnd then
        if not isSingleLvUp then
            this.LongLvUpClick(oldLv)
            _isClicked = false
            _isLongPress = false
        end
        return
    end
    if isSingleLvUp then
        allAddProVal = PokemonManager.GetSinglePokemonAddProData(curPokemonData.dynamicId)
        local oldWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
        NetManager.UpPokemonLevelRequest(curPokemonData.dynamicId,curPokemonData.lv + 1,curPokemonData.lv, function(msg)
            PokemonManager.UpdateSinglePokemonData(curPokemonData.dynamicId,msg.level,curPokemonData.star)
            curPokemonData = PokemonManager.GetSinglePokemonData(curPokemonData.dynamicId)
            local allAddProValNet = PokemonManager.GetSinglePokemonAddProData(curPokemonData.dynamicId)
            this.ShowProAddVal(allAddProValNet)
            this.ShowPokemonInfo()
            local newWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            PokemonManager.PiaoWarPowerChange(oldWarPower,newWarPower)
            FormationManager.CheckHeroIdExist()
        end)
    else
        --前端先扣除材料
        for i = 1, #curUpLvConsume do
            BagManager.HeroLvUpUpdateItemsNum(curUpLvConsume[i][1],curUpLvConsume[i][2])
        end
        PokemonManager.UpdateSinglePokemonData(curPokemonData.dynamicId,curPokemonData.lv + 1,curPokemonData.star)
        curPokemonData = PokemonManager.GetSinglePokemonData(curPokemonData.dynamicId)
        this.ShowPokemonInfo()
        _isReqLvUp = false
    end
end
--播放升级 属性提升动画
function this.ShowProAddVal(allAddProValNet)
    this.lvUpGo:SetActive(true)
    Util.GetGameObject(lvUpShowProList[1], "proPre/vale"):GetComponent("Text").text="+"..allAddProValNet[HeroProType.Attack]-allAddProVal[HeroProType.Attack]
    Util.GetGameObject(lvUpShowProList[2], "proPre/vale"):GetComponent("Text").text="+"..allAddProValNet[HeroProType.Hp]-allAddProVal[HeroProType.Hp]
    Util.GetGameObject(lvUpShowProList[3], "proPre/vale"):GetComponent("Text").text="+"..allAddProValNet[HeroProType.PhysicalDefence]-allAddProVal[HeroProType.PhysicalDefence]
    Util.GetGameObject(lvUpShowProList[4], "proPre/vale"):GetComponent("Text").text="+"..allAddProValNet[HeroProType.MagicDefence]-allAddProVal[HeroProType.MagicDefence]
    this.ThreadShowProAddVal()
end
function this.ThreadShowProAddVal()
    if this.priThread then
        coroutine.stop(this.priThread)
        this.priThread = nil
    end
    table.walk(lvUpShowProList, function(privilegeItem)
        privilegeItem:SetActive(false)
    end)
    this.priThread = coroutine.start(function()
        for i = 1, 4 do
            lvUpShowProList[i]:SetActive(false)
            PlayUIAnims(lvUpShowProList[i])
            coroutine.wait(0.04)
            lvUpShowProList[i]:SetActive(true)
            coroutine.wait(0.08)
        end
        this.lvUpGo:SetActive(false)
    end)
end

function this:OnClose()
    if this.priThread then
        coroutine.stop(this.priThread)
        this.priThread = nil
    end
end

function this:OnDestroy()
end

return this