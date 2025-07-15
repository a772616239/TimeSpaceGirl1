require("Base/BasePanel")
WorkShopMainPanel = Inherit(BasePanel)
local this = WorkShopMainPanel
local propertyConfig=ConfigManager.GetConfig(ConfigName.PropertyConfig)
local workShopSetting=ConfigManager.GetConfig(ConfigName.WorkShopSetting)
local armorTabsStr = { GetLanguageStrById(12037), GetLanguageStrById(10429), GetLanguageStrById(10430) }--防具打造
local equipTabsStr = { GetLanguageStrById(12038), GetLanguageStrById(12039), GetLanguageStrById(12040), GetLanguageStrById(12041), GetLanguageStrById(12042) }--武器打造
local curActiveLanTuData = {}  --当前选择要解锁蓝图的数据
local selectEquipData  --装备重铸选择的装备数据
local selectDeleteEquipData  --装备重铸选择祭品的装备数据
local materialsDataList  --装备重铸消耗的材料
local proTypeId
local isShowAll
--天赋书
local treeTabs = {}
local openTreePanel = nil
local curTreeConfigData = nil
local curTreeSelectIndex = 0
local proList = {}
local treeIsCanUpLv = 0 --0 可以升级 1 材料不足 2 前置条件等级不足

local cursortingOrder

local isMaterialEnough = true
--从装备穿戴界面进入工坊界面需要英雄数据
local curHeroData = nil
local lockCompList = {}
local setRedPoint = {}

--天赋树长按升级
local _isClicked = false
this._isReqLvUp = false
local _isLongPress = false
this.isCanLongUpLv = true
--监听长按事件
local timePressStarted
this.priThread = nil
--初始化组件（用于子类重写）
function WorkShopMainPanel:InitComponent()

    cursortingOrder = 0
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition

    this.duihua = Util.GetGameObject(self.gameObject, "duihua/Text"):GetComponent("Text")
    this.expName = Util.GetGameObject(self.gameObject, "lvUpBtn/lv"):GetComponent("Text")
    --this.lvExp = Util.GetGameObject(self.transform, "lvExp"):GetComponent("Slider")
    this.lvUpBtn = Util.GetGameObject(self.transform, "lvUpBtn")
    this.btns = Util.GetGameObject(self.transform, "btns")

    -- 按钮
    this.treeBtn = Util.GetGameObject(self.transform, "btns/treeBtn")
    this.equipBtn = Util.GetGameObject(self.transform, "btns/equipBtn")
    this.armorBtn = Util.GetGameObject(self.transform, "btns/armorBtn")
    this.equipXiBtn = Util.GetGameObject(self.transform, "btns/equipXiBtn")
    --this.followUpBtn = Util.GetGameObject(self.transform, "btns/followUpBtn")
    this.treeagainBtn = Util.GetGameObject(self.transform, "btns/treeBtn/againBtn")
    this.equipagainBtn = Util.GetGameObject(self.transform, "btns/equipBtn/againBtn")
    this.armoragainBtn = Util.GetGameObject(self.transform, "btns/armorBtn/againBtn")
    this.equipXiagainBtn = Util.GetGameObject(self.transform, "btns/equipXiBtn/againBtn")
    --天赋树
    this.showPanel1 = Util.GetGameObject(self.transform, "showPanel1")
    this.showPanel1selectBtn = Util.GetGameObject(self.transform, "showPanel1/Tabs/selectBtn")
    this.showPanel1materialsGrid = Util.GetGameObject(self.transform, "showPanel1/materialsInfo/materialsRect/materialsGrid")
    this.showPanel1SureBtn = Util.GetGameObject(self.transform, "showPanel1/sureBtn")
    this.upLvTrigger = Util.GetEventTriggerListener(this.showPanel1SureBtn)

    this.showPanel1RefreshBtn = Util.GetGameObject(self.transform, "showPanel1/refreshBtn")
    this.showPanel1RefreshBtn = Util.GetGameObject(self.transform, "showPanel1/refreshBtn")
    this.treeIcon = Util.GetGameObject(self.transform, "showPanel1/info/bg/icon"):GetComponent("Image")
    this.treeName = Util.GetGameObject(self.transform, "showPanel1/info/name"):GetComponent("Text")
    this.treeLv = Util.GetGameObject(self.transform, "showPanel1/info/lv"):GetComponent("Text")
    this.treeLvMaxTiShiText = Util.GetGameObject(self.transform, "showPanel1/maxLvTiShiText")
    for i = 1, 3 do
        proList[i] = Util.GetGameObject(self.transform, "showPanel1/info/proList/pro"..i)
    end
    for i = 1, 5 do
        treeTabs[i] = Util.GetGameObject(self.transform, "showPanel1/Tabs/Btn"..i)
    end
    this.treeTishiText = Util.GetGameObject(self.transform, "showPanel1/info/tishiText")
    --打造装备
    this.selectBtn = Util.GetGameObject(self.transform, "showPanel2/selectBtn")
    this.showPanel2 = Util.GetGameObject(self.transform, "showPanel2")
    this.showPanel3 = Util.GetGameObject(self.transform, "showPanel3")
    this.btnPre = Util.GetGameObject(self.transform, "showPanel2/btnPre")
    this.btnGrid = Util.GetGameObject(self.transform, "showPanel2/btnList/btnGrid")
    this.infoPre = Util.GetGameObject(self.transform, "showPanel2/infoPre")
    this.infoGrid = Util.GetGameObject(self.transform, "showPanel2/infoRect/infoGrid")
    --装备重铸
    this.equipIcon = Util.GetGameObject(self.transform, "showPanel3/equipInfo/frame/icon")
    this.equipFrame = Util.GetGameObject(self.transform, "showPanel3/equipInfo/frame")
    this.equipAddBtn = Util.GetGameObject(self.transform, "showPanel3/equipInfo/add")
    this.equipMaterialsIcon = Util.GetGameObject(self.transform, "showPanel3/materialsEquipInfo/frame/icon")
    this.equipMaterialsFrame = Util.GetGameObject(self.transform, "showPanel3/materialsEquipInfo/frame")
    this.equipMaterialsAddBtn = Util.GetGameObject(self.transform, "showPanel3/materialsEquipInfo/add")
    this.itemPre = Util.GetGameObject(self.transform, "showPanel3/materialsInfo/itemPre")
    this.materialsGrid = Util.GetGameObject(self.transform, "showPanel3/materialsInfo/materialsRect/materialsGrid")
    this.yulanBtn = Util.GetGameObject(self.transform, "showPanel3/yulanBtn")
    this.sureBtn = Util.GetGameObject(self.transform, "showPanel3/sureBtn")
    this.equipPopu = Util.GetGameObject(self.transform, "equipPopu")
    this.equipPopuMask = Util.GetGameObject(self.transform, "equipPopu/mask")
    this.prpPre = Util.GetGameObject(self.transform, "equipPopu/proPre")
    this.prpGrid = Util.GetGameObject(self.transform, "equipPopu/proRect/proGrid")

    this.maskImage1=Util.GetGameObject(self.transform, "btns/treeBtn/maskImage")
    this.maskImage2=Util.GetGameObject(self.transform, "btns/equipBtn/maskImage")
    this.maskImage3=Util.GetGameObject(self.transform, "btns/armorBtn/maskImage")
    this.maskImage4=Util.GetGameObject(self.transform, "btns/equipXiBtn/maskImage")


    this.live = poolManager:LoadLive("live2d_c_jpw_0024",Util.GetTransform(self.transform, "bg/live"), Vector3.one, Vector3.zero)

    local SkeletonGraphic = this.live:GetComponent("SkeletonGraphic")
    local OnIdle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
    SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + OnIdle
    poolManager:SetLiveClearCall("live2d_c_jpw_0024", this.live, function ()
        SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - OnIdle
    end)

    this.bg = Util.GetGameObject(self.transform, "bg")
    screenAdapte(this.bg)

    --红点
    this.equipBtnRedPoint = Util.GetGameObject(self.transform, "btns/equipBtn/redPoint")
    this.armorBtnRedPoint = Util.GetGameObject(self.transform, "btns/armorBtn/redPoint")

    lockCompList = {
        [102] = {go = this.equipBtn, funcId = 2, btnBack = this.equipagainBtn},
        [103] = {go = this.armorBtn, funcId = 3, btnBack = this.armoragainBtn},
        [104] = {go = this.equipXiBtn, funcId = 4, btnBack = this.equipXiagainBtn},
        [101] = {go = this.treeBtn, funcId = 1, btnBack = this.treeagainBtn}
    }
end

--绑定事件（用于子类重写）
function WorkShopMainPanel:BindEvent()

    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    Util.AddClick(this.BtnBack, function()
        if UIManager.IsOpen(UIName.WorkShopEquipReforgePreviewPanel) then
            UIManager.ClosePanel(UIName.WorkShopEquipReforgePreviewPanel)
        end
        if UIManager.IsOpen(UIName.WorkShowTechnologPanel) then
            UIManager.ClosePanel(UIName.WorkShowTechnologPanel)
        end
        openTreePanel = nil
        self:ClosePanel()
    end)
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Work,this.helpPosition.x,this.helpPosition.y)
    end)
    for i = 1, 5 do
        Util.AddClick(treeTabs[i], function ()
            this.ShowTreePanel(i)
        end)
    end
    for i, v in pairs(lockCompList) do
        Util.AddClick(v.go, function ()
            local isOpen = ActTimeCtrlManager.SingleFuncState(i)
            if not isOpen then
                PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(i))
            else
                v.btnBack:SetActive(true)
                this:OnClickMianTabBtn(v.funcId, 1)
            end
        end)
    end

    --Util.AddClick(this.followUpBtn, function()
    --    PopupTipPanel.ShowTip("敬请期待！")
    --end)
    Util.AddClick(this.treeagainBtn, function()
        this:OnClickMianTabBtn(4, 2)
        UIManager.ClosePanel(UIName.WorkShowTechnologPanel)
        openTreePanel = nil
    end)
    Util.AddClick(this.equipagainBtn, function()
        this:OnClickMianTabBtn(4, 2)
    end)
    Util.AddClick(this.armoragainBtn, function()
        this:OnClickMianTabBtn(4, 2)
    end)
    Util.AddClick(this.equipXiagainBtn, function()
        this:OnClickMianTabBtn(4, 2)
    end)

    Util.AddClick(this.yulanBtn, function()
        if this.isSelectEquip == 1 then
            this:OnClickShowYuLan()
        else
            PopupTipPanel.ShowTipByLanguageId(12043)
        end
    end)
    Util.AddClick(this.equipPopuMask, function()
        this.equipPopu:SetActive(false)
    end)
    Util.AddClick(this.sureBtn, function()
       
        if isMaterialEnough then
            if selectEquipData ~= nil then
                if selectDeleteEquipData ~= nil then
                    NetManager.GetWorkShopEquipRebuildRequest(selectEquipData.did, selectDeleteEquipData.did, function(equipData)
                        UIManager.OpenPanel(UIName.WorkShopCastSuccessPanel, selectEquipData, equipData, this)
                    end)
                else
                    PopupTipPanel.ShowTipByLanguageId(12044)
                end
            else
                PopupTipPanel.ShowTipByLanguageId(12043)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(12045)
        end
    end)
    Util.AddClick(this.lvUpBtn, function()
        if WorkShopManager.WorkShopData.lv + 1 >= WorkShopManager.WorkShopData.maxLv then
            PopupTipPanel.ShowTipByLanguageId(12046)
        else
            UIManager.OpenPanel(UIName.WorkShopLvUpPanel,this)
        end
    end)
    --天赋树升级按钮
    Util.AddClick(this.showPanel1SureBtn, function()
        if Time.realtimeSinceStartup - timePressStarted <= 0.4 then
            this.showPanel1SureBtnClickEvent()
        end
    end)

    this._onPointerDown = function(Pointgo, data)
        _isClicked = true
        timePressStarted = Time.realtimeSinceStartup
    end

    this._onPointerUp = function(Pointgo, data)
        _isClicked = false
        _isLongPress = false
    end
    this.upLvTrigger.onPointerDown = this.upLvTrigger.onPointerDown + this._onPointerDown
    this.upLvTrigger.onPointerUp = this.upLvTrigger.onPointerUp + this._onPointerUp


    Util.AddClick(this.showPanel1RefreshBtn, function()
        this.TreeRefreshBtnClick()
    end)
    --武器、防具 按钮红点
    BindRedPointObject(RedPointType.Refining_Weapon, this.equipBtnRedPoint)
    BindRedPointObject(RedPointType.Refining_Armor, this.armorBtnRedPoint)
end
function this.OnUpdate()
    if _isClicked then
        if Time.realtimeSinceStartup - timePressStarted > 0.4 then

            _isLongPress = true
            if not this._isReqLvUp then

                this._isReqLvUp = true
                this:showPanel1SureBtnClickEvent()
            end
        end
    end
end
--添加事件监听（用于子类重写）
function WorkShopMainPanel:AddListener()

    Game.GlobalEvent:AddEvent(GameEvent.WorkShow.WorkShopLvChange, this.UpdateLvAndExpVal)
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.UpdateBagGold)
end

--移除事件监听（用于子类重写）
function WorkShopMainPanel:RemoveListener()

    Game.GlobalEvent:RemoveEvent(GameEvent.WorkShow.WorkShopLvChange, this.UpdateLvAndExpVal)
    Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.UpdateBagGold)
end

--界面打开时调用（用于子类重写）
function WorkShopMainPanel:OnOpen(heroData)

    curHeroData = heroData

    -- 播放环境音
    SoundManager.PlayAmbient(SoundConfig.Ambient_WorkShop)
end
function WorkShopMainPanel:OnSortingOrderChange()
    for i = 1, 3 do
        Util.AddParticleSortLayer(Util.GetGameObject(proList[i].transform, "prop_effect"), self.sortingOrder - cursortingOrder)
        Util.GetGameObject(proList[i].transform, "prop_effect"):SetActive(false)
    end
    cursortingOrder = self.sortingOrder
end
function WorkShopMainPanel:OnShow()
    if curHeroData then
       
        this:OnClickMianTabBtn(4, 1)
    else
        this:OnClickMianTabBtn(4, 2)
    end

    this.live:GetComponent("SkeletonGraphic").AnimationState:SetAnimation(0, "come", false)
    local randomNum = math.random(1, #WorkShopManager.WorkShopData.welcomeStrList)
    this.duihua.text = WorkShopManager.WorkShopData.welcomeStrList[randomNum]
    this.level = WorkShopManager.WorkShopData.lv
    this.UpdateLvAndExpVal()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.IronResource })

    if WorkShopManager.unDetermined then
        if WorkShopManager.unDetermined.id and WorkShopManager.unDetermined.id ~= "" then
            UIManager.OpenPanel(UIName.WorkShopCastSuccessPanel, EquipManager.GetSingleEquipData(WorkShopManager.unDetermined.id), WorkShopManager.unDetermined, this)
        end
    end
    SoundManager.PlayMusic(SoundConfig.BGM_WorkShop)

    -- 刷新一下模块显示
    this.SetInitShow()
    FixedUpdateBeat:Add(this.OnUpdate, self)
end

function this.SetInitShow()
    for i, v in pairs(lockCompList) do
        ActTimeCtrlManager.SetFuncLockState(v.go, i, true,true)
    end
end

function this.UpdateLvAndExpVal()
    if WorkShopManager.WorkShopData.lv <= WorkShopManager.WorkShopData.maxLv then
        if WorkShopManager.WorkShopData.lv > this.level then
            UIManager.OpenPanel(UIName.WorkShopLevelUpNotifyPanel, { level = WorkShopManager.WorkShopData.lv })
        end
    end
    this.expName.text = WorkShopManager.WorkShopData.lv
    this.level = WorkShopManager.WorkShopData.lv
    --刷新工坊元素开启条件
    this:UpdatePanelData(proTypeId)
    this.SetInitShow()
end

--
function this:OnClickMianTabBtn(_proTypeId, _isShowAll)
    proTypeId = _proTypeId
    isShowAll = _isShowAll
    this.selectBtn.transform:SetParent(this.showPanel2.transform)
    this.btns.transform:GetChild(_proTypeId - 1).gameObject:SetActive(true)
    Util.GetGameObject(this.btns.transform:GetChild(_proTypeId - 1), "againBtn"):SetActive(true)
    for i = 1, this.btns.transform.childCount do
        if _isShowAll == 1 then
            this.showPanel1:SetActive(_proTypeId == 1)
            this.showPanel2:SetActive(_proTypeId == 2 or _proTypeId == 3)
            this.showPanel3:SetActive(_proTypeId == 4)
            if i ~= _proTypeId then
                this.btns.transform:GetChild(i - 1).gameObject:SetActive(false)
            end
        elseif _isShowAll == 2 then
            this.btns.transform:GetChild(i - 1).gameObject:SetActive(true)
            Util.GetGameObject(this.btns.transform:GetChild(i - 1), "againBtn"):SetActive(false)
            this.showPanel1:SetActive(false)
            this.showPanel2:SetActive(false)
            this.showPanel3:SetActive(false)
            for i = 1, 3 do
                Util.GetGameObject(proList[i].transform, "prop_effect"):SetActive(false)
            end
        end
    end
    this:UpdatePanelData(_proTypeId)

end
--点击(基础工坊)按钮刷新界面
function this:UpdatePanelData(_proTypeId)
    this.selectBtn.transform:SetParent(this.showPanel2.transform)
    curActiveLanTuData = {}
    if _proTypeId == 1 then
        this.ShowTreePanel(1)
    elseif _proTypeId == 2 then
        Util.ClearChild(this.btnGrid.transform)
        for i = 1, #equipTabsStr do
            local go = newObject(this.btnPre)
            go.transform:SetParent(this.btnGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero;
            go:SetActive(true)
            Util.GetGameObject(go.transform, "Text"):GetComponent("Text").text = equipTabsStr[i]
            Util.AddClick(Util.GetGameObject(go.transform, "cilck"), function()
                this:OnClickTabBtn(_proTypeId, i)
            end)
        end
        this:OnClickTabBtn(_proTypeId, 1)
    elseif _proTypeId == 3 then
        Util.ClearChild(this.btnGrid.transform)
        for i = 1, #armorTabsStr do
            local go = newObject(this.btnPre)
            go.transform:SetParent(this.btnGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero;
            go:SetActive(true)
            Util.GetGameObject(go.transform, "Text"):GetComponent("Text").text = armorTabsStr[i]
            Util.AddClick(Util.GetGameObject(go.transform, "cilck"), function()
                this:OnClickTabBtn(_proTypeId, i)
            end)
        end
        this:OnClickTabBtn(_proTypeId, 1)
    elseif _proTypeId == 4 then
        --装备重铸
        this.UpdateEquipPosHeroData(1, nil)
    end
end
--点击页签__根据sortType和职业属性/类型进行排序
function this:OnClickTabBtn(_proId, _tabsId)
   
    local infos = {}
    local curBtn = this.btnGrid.transform:GetChild(_tabsId - 1)
    if _proId == 1 then
        this:SetSelectBtn(curBtn, baseTabsStr[_tabsId])
        infos = WorkShopManager.GetWorkShopData(1, _proId, _tabsId)
        this:UpdataShowPanelData(_proId, infos)
    elseif _proId == 2 then
        this:SetSelectBtn(curBtn, equipTabsStr[_tabsId])
        infos = WorkShopManager.GetWorkShopData(1, _proId, _tabsId)
        this:UpdataShowPanelData(_proId, infos)
    elseif _proId == 3 then
        this:SetSelectBtn(curBtn, armorTabsStr[_tabsId])
        infos = WorkShopManager.GetWorkShopData(1, _proId, _tabsId + 1)
        this:UpdataShowPanelData(_proId, infos)
    else

    end
    this.selectBtn.gameObject:SetActive(true)
    -- this:SetRoleList(heros)
end
function this:SetSelectBtn(_btn, btnText)
    this.selectBtn.transform:SetParent(_btn.transform)
    this.selectBtn.transform.localScale = Vector3.one
    this.selectBtn.transform.localPosition = Vector3.zero;
    Util.GetGameObject(this.selectBtn.transform, "Text"):GetComponent("Text").text = btnText
end
function this:UpdataShowPanelData(_proId, _infos)
    Util.ClearChild(this.infoGrid.transform)
    for i = 1, #_infos do
        local go = newObject(this.infoPre)
        go.transform:SetParent(this.infoGrid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero;
        go:SetActive(true)
        Util.GetGameObject(go.transform, "name/Text"):GetComponent("Text").text = GetLanguageStrById(_infos[i].itemData.Name)
        Util.GetGameObject(go.transform, "infoText"):GetComponent("Text").text = _infos[i].workShopData.ShortDesc
        if _proId == 1 then
            Util.GetGameObject(go.transform, "frame/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(_infos[i].itemData.ResourceID))
            Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(_infos[i].itemData.Quantity))
        elseif _proId == 2 then
            Util.GetGameObject(go.transform, "frame/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(_infos[i].itemConfigData.ResourceID))
            Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(_infos[i].itemConfigData.Quantity))
        elseif _proId == 3 then
            Util.GetGameObject(go.transform, "frame/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(_infos[i].itemConfigData.ResourceID))
            Util.GetGameObject(go.transform, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(_infos[i].itemConfigData.Quantity))
        end

        if _infos[i].workShopData.OpenRules[1] == 1 then
            --工坊等级
            if WorkShopManager.WorkShopData.lv >= _infos[i].workShopData.OpenRules[2] then
                Util.GetGameObject(go.transform, "mask"):SetActive(false)  if _infos[i].redPoint == true then
                Util.GetGameObject(go.transform, "redPoint"):SetActive(true)
                if setRedPoint[_infos[i].workShopData.Id] == nil then

                    setRedPoint[_infos[i].workShopData.Id] = _infos[i].workShopData.Id
                end
            else
                Util.GetGameObject(go.transform, "redPoint"):SetActive(false)
            end
            else
                Util.GetGameObject(go.transform, "redPoint"):SetActive(false)
                Util.GetGameObject(go.transform, "mask"):SetActive(true)
                Util.GetGameObject(go.transform, "mask/mask/Text"):GetComponent("Text").text = GetLanguageStrById(12050) .. _infos[i].workShopData.OpenRules[2] .. GetLanguageStrById(12051)
            end
        elseif _infos[i].workShopData.OpenRules[1] == 2 then
            --蓝图
            if _infos[i].active == 1 then
                --已解锁
                Util.GetGameObject(go.transform, "mask"):SetActive(false)
                if _infos[i].redPoint == true then
                    Util.GetGameObject(go.transform, "redPoint"):SetActive(true)
                    if setRedPoint[_infos[i].workShopData.Id] == nil then

                        setRedPoint[_infos[i].workShopData.Id] = _infos[i].workShopData.Id
                    end
                else
                    Util.GetGameObject(go.transform, "redPoint"):SetActive(false)
                end
            elseif _infos[i].active == 2 then
                --未解锁
                Util.GetGameObject(go.transform, "redPoint"):SetActive(false)
                Util.GetGameObject(go.transform, "mask"):SetActive(true)
                local itemConfigData = ConfigManager.GetConfigData(ConfigName.ItemConfig, _infos[i].workShopData.OpenRules[2])
                if itemConfigData then
                    Util.GetGameObject(go.transform, "mask/mask/Text"):GetComponent("Text").text = GetLanguageStrById(10220) .. GetLanguageStrById(itemConfigData.Name) .. GetLanguageStrById(12052)
                end
            end
        end
        Util.AddClick(Util.GetGameObject(go.transform, "clickBtn"), function()
            if _proId == 1 then
                UIManager.OpenPanel(UIName.WorkShopMaterialsCompoundPanel, _infos[i].workShopData)
            elseif _proId == 2 then
                UIManager.OpenPanel(UIName.WorkShopArmorTwoPanel, _infos[i].workShopData, _proId, this)
            elseif _proId == 3 then
                UIManager.OpenPanel(UIName.WorkShopArmorTwoPanel, _infos[i].workShopData, _proId, this)
            end
        end)
        Util.AddClick(Util.GetGameObject(go.transform, "mask"), function()
            if _infos[i].workShopData.OpenRules[1] == 1 then
                --工坊等级
                PopupTipPanel.ShowTip(GetLanguageStrById(12050) .. _infos[i].workShopData.OpenRules[2] .. GetLanguageStrById(12051))
            elseif _infos[i].workShopData.OpenRules[1] == 2 then
                --蓝图
                UIManager.OpenPanel(UIName. WorkShopArmorOnePanel,1,1, _infos[i].workShopData.Id, this)
                curActiveLanTuData.data = _infos[i]
                curActiveLanTuData.go = go.transform
            end
        end)
    end
end
--装备重铸显示预览属性
function this:OnClickShowYuLan()
    UIManager.OpenPanel(UIName.WorkShopEquipReforgePreviewPanel, selectEquipData)
end
function this.CalculateQuJian(_Pool, _ProData)
    local curEquipPropertyPoolData = ConfigManager.GetConfigData(ConfigName.EquipPropertyPool, _Pool * 10000 + _ProData.propertyId)
    local curProAddVal = 0
    if WorkShopManager.WorkShopData.LvAddMainIdAndVales[_ProData.propertyId] then
        curProAddVal = WorkShopManager.WorkShopData.LvAddMainIdAndVales[_ProData.propertyId] / 100
    end
    local curProVal = {}
    table.insert(curProVal, curEquipPropertyPoolData.Min)
    table.insert(curProVal, curEquipPropertyPoolData.Max)
    if curProAddVal > 0 then
        for i = 1, 2 do
            curProVal[i] = math.floor(curProVal[i] * (1 + curProAddVal))
        end
    end
    return curProVal
end
--装备重铸刷新显示
function this.UpdateEquipPosHeroData(_type, _equipData)
    if _type == 1 then
        --1 请选择重铸装备  2 选择祭品装备
        selectEquipData = _equipData
        if _equipData ~= nil then
            if isShowAll == 1 then
                UIManager.OpenPanel(UIName.WorkShopEquipReforgePreviewPanel, selectEquipData)
            end
            this.isSelectEquip = 1
            this.equipIcon:SetActive(true)
            this.equipIcon:GetComponent("Image").sprite = Util.LoadSprite(_equipData.icon)
            Util.GetGameObject(this.equipAddBtn, "add/add"):SetActive(false)
            this.equipFrame:GetComponent("Image").sprite = Util.LoadSprite(_equipData.frame)
            Util.AddOnceClick(this.equipAddBtn, function()
                if #EquipManager.GetAllEquipDataIfClear() > 0 then
                    UIManager.OpenPanel(UIName.WorkShopEquipRebuildListPanel, 1, this, _equipData)
                else
                    PopupTipPanel.ShowTipByLanguageId(12053)
                end
            end)
            this.equipMaterialsIcon:SetActive(false)
            --this.equipMaterialsFrame:GetComponent("Image").sprite = Util.LoadSprite("r_characterbg_goden")
            Util.GetGameObject(this.equipMaterialsAddBtn, "add/add"):SetActive(true)
            this.equipMaterialsFrame:GetComponent("Image").sprite = Util.LoadSprite(_equipData.frame)
            selectDeleteEquipData=nil
            Util.AddOnceClick(this.equipMaterialsAddBtn, function()
                if #EquipManager.WorkShopGetEquipDataByEquipQuality(_equipData.equipConfig.Quality, _equipData.did) > 0 then
                    UIManager.OpenPanel(UIName.WorkShopEquipRebuildListPanel, 2, _equipData, this, nil)--selectDeleteEquipData
                else
                    PopupTipPanel.ShowTipByLanguageId(12054)
                end
            end)
            this.equipPopu:SetActive(false)
            materialsDataList = {}
           
            materialsDataList = WorkShopManager.WorkShopData.WorkShopRebuildConfig[_equipData.equipConfig.Quality - 1].SecondaryCost
            isMaterialEnough = true
           
            Util.ClearChild(this.materialsGrid.transform)
            for i = 1, #materialsDataList do
                local curItemData = ConfigManager.GetConfigData(ConfigName.ItemConfig, materialsDataList[i][1])
                local go = newObject(this.itemPre)
                go.transform:SetParent(this.materialsGrid.transform)
                go.transform.localScale = Vector3.one
                go.transform.localPosition = Vector3.zero;
                go:SetActive(true)
                if curItemData ~= nil then
                    Util.GetGameObject(go.transform, "icon"):SetActive(true)
                    Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(curItemData.ResourceID))
                    go.transform:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(curItemData.Quantity))
                end
                Util.GetGameObject(go.transform, "num"):SetActive(true)
                if BagManager.GetItemCountById(materialsDataList[i][1]) < materialsDataList[i][2] then
                    isMaterialEnough = false
                   
                    Util.GetGameObject(go.transform, "num"):GetComponent("Text").text = string.format("<color=#FF0000FF>%s</color>", materialsDataList[i][2])
                else
                    Util.GetGameObject(go.transform, "num"):GetComponent("Text").text = string.format("<color=#FFFFFFFF>%s</color>", materialsDataList[i][2])
                end
            end
        else
            if UIManager.IsOpen(UIName.WorkShopEquipReforgePreviewPanel) then
                UIManager.ClosePanel(UIName.WorkShopEquipReforgePreviewPanel)
            end
            this.isSelectEquip = 2
            this.equipFrame:GetComponent("Image").sprite = Util.LoadSprite("r_characterbg_goden")
            this.equipIcon:SetActive(false)
            Util.GetGameObject(this.equipAddBtn, "add/add"):SetActive(true)
            --this.equipFrame=
            Util.AddOnceClick(this.equipAddBtn, function()
                if #EquipManager.GetAllEquipDataIfClear() > 0 then
                    UIManager.OpenPanel(UIName.WorkShopEquipRebuildListPanel, 1, this, nil)
                else
                    PopupTipPanel.ShowTipByLanguageId(12053)
                end
            end)
            this.equipMaterialsIcon:SetActive(false)
            if selectEquipData ~=nil then
                this.equipMaterialsFrame:GetComponent("Image").sprite = Util.LoadSprite(selectEquipData.frame)
            else
                this.equipMaterialsFrame:GetComponent("Image").sprite = Util.LoadSprite("r_characterbg_goden")
            end
            Util.GetGameObject(this.equipMaterialsAddBtn, "add/add"):SetActive(true)
            --this.equipMaterialsFrame=
            Util.AddOnceClick(this.equipMaterialsAddBtn, function()
                if this.isSelectEquip == 2 then
                    --UIManager.OpenPanel(UIName.WorkShopEquipRebuildListPanel,2,nil,this,nil)
                    PopupTipPanel.ShowTipByLanguageId(12043)
                end
            end)
            this.equipPopu:SetActive(false)
            Util.ClearChild(this.materialsGrid.transform)
            for i = 1, 4 do
                local go = newObject(this.itemPre)
                go.transform:SetParent(this.materialsGrid.transform)
                go.transform.localScale = Vector3.one
                go.transform.localPosition = Vector3.zero;
                go:SetActive(true)
                Util.GetGameObject(go.transform, "icon"):SetActive(false)
                Util.GetGameObject(go.transform, "num"):SetActive(false)
            end
        end
    else
        selectDeleteEquipData = _equipData
        if _equipData ~= nil then
            this.equipMaterialsIcon:SetActive(true)
            this.equipMaterialsIcon:GetComponent("Image").sprite = Util.LoadSprite(_equipData.icon)
            Util.GetGameObject(this.equipMaterialsAddBtn, "add/add"):SetActive(false)
            this.equipMaterialsFrame:GetComponent("Image").sprite = Util.LoadSprite(_equipData.frame)
            Util.AddOnceClick(this.equipMaterialsAddBtn, function()
                if #EquipManager.WorkShopGetEquipDataByEquipQuality(selectEquipData.equipConfig.Quality, selectEquipData.did) > 0 then
                    UIManager.OpenPanel(UIName.WorkShopEquipRebuildListPanel, 2, selectEquipData, this, selectDeleteEquipData)
                else
                    PopupTipPanel.ShowTipByLanguageId(12054)
                end
            end)
        else

            this.equipMaterialsIcon:SetActive(false)
            if selectEquipData ~=nil then
                this.equipMaterialsFrame:GetComponent("Image").sprite = Util.LoadSprite(selectEquipData.frame)
            else
                this.equipMaterialsFrame:GetComponent("Image").sprite = Util.LoadSprite("r_characterbg_goden")
            end
            Util.GetGameObject(this.equipMaterialsAddBtn, "add/add"):SetActive(true)
            --this.equipMaterialsFrame:GetComponent("Image").sprite = Util.LoadSprite(selectEquipData.frame)
            Util.AddOnceClick(this.equipMaterialsAddBtn, function()
                if #EquipManager.WorkShopGetEquipDataByEquipQuality(selectEquipData.equipConfig.Quality, selectEquipData.did) > 0 then
                    UIManager.OpenPanel(UIName.WorkShopEquipRebuildListPanel, 2, selectEquipData, this, nil)
                else
                    PopupTipPanel.ShowTipByLanguageId(12054)
                end
            end)
        end

    end
end
--扣除解锁蓝图材料 并更新界面
function this.DeleteActiveLanTuData()
    WorkShopManager.UpdataWorkShopLanTuActiveState(proTypeId, curActiveLanTuData.data.workShopData.Id, curActiveLanTuData.data.workShopData.OpenRules[2])
    Util.GetGameObject(curActiveLanTuData.go, "mask"):SetActive(false)
    --if curActiveLanTuData.data then
    --    BagManager.UpdateItemsNum(curActiveLanTuData.data.workShopData.OpenRules[2], 1)
    --end
end
--扣除装备重铸材料
function this.DeleteEquipRebuildData(_equipData)
    if curHeroData ~= nil then
        if curHeroData.equipIdList[_equipData.id] then
            EquipManager.SetEquipUpHeroDid(_equipData.id, curHeroData)--从穿装备的时候直接重铸  得设置穿上英雄
        end
    end
    if selectDeleteEquipData ~= nil then

        --EquipManager.DeleteSingleEquip(selectDeleteEquipData.did)
        selectDeleteEquipData = {}
    end
    --if materialsDataList then
    --    for i = 1, #materialsDataList do
    
    --        BagManager.UpdateItemsNum(materialsDataList[i][1], materialsDataList[i][2])
    --    end
    --end
end
function this:SortDatas(_Datas)
    --星级优先，同星级等级优先，同星级同等级按sortId排序。排序时降序排序。
    table.sort(_Datas, function(a, b)
        if a.active == b.active then
            if a.itemData.Quality == b.itemData.Quality then
                return a.workShopData.Id > b.workShopData.Id
            else
                return a.itemData.Quality > b.itemData.Quality
            end
        else
            return a.active > b.active
        end
    end)
end
function this.showPanel1SureBtnClickEvent()
    if treeIsCanUpLv == 0 and curTreeConfigData and this.isCanLongUpLv then

        NetManager.WorkShopTreeLvUpRequest(curTreeConfigData.TechId, function()
            this.WorkShopTreeLvUpRequestDelMaterial()
            FormationManager.UserPowerChanged()
        end)
    elseif treeIsCanUpLv == 1 then
        PopupTipPanel.ShowTipByLanguageId(12045)
        _isClicked = false
        this._isReqLvUp = false
    elseif treeIsCanUpLv == 2 then
        local needConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.WorkShopTechnology, "TechId", curTreeConfigData.OpenRules[1], "Level", curTreeConfigData.OpenRules[2])
        if needConfig then
            PopupTipPanel.ShowTip(GetLanguageStrById(10657)..needConfig.Name..GetLanguageStrById(12057)..curTreeConfigData.OpenRules[2]..GetLanguageStrById(10072))
        end
        _isClicked = false
        this._isReqLvUp = false
    elseif treeIsCanUpLv == 3 then
        PopupTipPanel.ShowTipByLanguageId(12058)
        _isClicked = false
        this._isReqLvUp = false
    elseif treeIsCanUpLv == 4 then
        PopupTipPanel.ShowTipByLanguageId(12059)
        _isClicked = false
        this._isReqLvUp = false
    end
end
--天赋树
function this.ShowTreePanel(_tabsIndex)
    curTreeSelectIndex = _tabsIndex
    this:SetTreeSelectBtn(curTreeSelectIndex)
    --if openTreePanel then
    --    openTreePanel.ShowPanelData(curTreeSelectIndex)
    --else
        openTreePanel = UIManager.OpenPanel(UIName.WorkShowTechnologPanel,curTreeSelectIndex,this)
    --end
end
--天赋树设置职业按钮
function this:SetTreeSelectBtn(_tabsIndex)
    if _tabsIndex > 0 then
        this.showPanel1selectBtn:SetActive(true)
        this.showPanel1selectBtn.transform.localPosition = treeTabs[_tabsIndex].transform.localPosition
        Util.GetGameObject(this.showPanel1selectBtn.transform, "Text"):GetComponent("Text").text = HeroOccupationDef[_tabsIndex]
    else
        this.showPanel1selectBtn:SetActive(false)
    end
end
--天赋树实例化升级材料 升级信息
function this.SetTreeLvUpMatial(_data)
    treeIsCanUpLv = 0 --默认条件满足
    curTreeConfigData = _data.conFigData
    if curTreeConfigData then
        local curTreePointLvEnd = workShopSetting[PlayerManager.level].TechnologyLevel--工坊解锁的等级上限--WorkShopManager.WorkShopData.lv
        local treePointLvEnd = WorkShopManager.WorkShopTreeSinglePointLvEnd[curTreeConfigData.TechId]--次天赋点最终等级上限
        local nextTreeConfigData = {}
        if curTreeConfigData.Level+1 > treePointLvEnd then
            nextTreeConfigData = nil
        else
            nextTreeConfigData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.WorkShopTechnology, "TechId", curTreeConfigData.TechId, "Level", curTreeConfigData.Level+1)
        end

        curTreePointLvEnd = curTreePointLvEnd > treePointLvEnd and treePointLvEnd or curTreePointLvEnd


        this.treeIcon.sprite = Util.LoadSprite(GetResourcePath(_data.icon))--curData.icon
        this.treeName.text = curTreeConfigData.Name
        this.treeLv.text = curTreeConfigData.Level.."/"..curTreePointLvEnd
        this.treeLvMaxTiShiText:SetActive(curTreeConfigData.Level >= treePointLvEnd)
        for i = 1, 3 do
            if #curTreeConfigData.Values >= i then
                proList[i]:SetActive(true)
                Util.GetGameObject(proList[i].transform, "prop_effect"):SetActive(false)
                proList[i]:GetComponent("Text").text = propertyConfig[curTreeConfigData.Values[i][1]].Info
                local proType = propertyConfig[curTreeConfigData.Values[i][1]].Style
                Util.GetGameObject(proList[i], "curVal"):GetComponent("Text").text =GetPropertyFormatStr(proType, curTreeConfigData.Values[i][2])
                if nextTreeConfigData then
                    Util.GetGameObject(proList[i], "nextVal"):GetComponent("Text").text = GetPropertyFormatStr(proType, nextTreeConfigData.Values[i][2])
                else
                    Util.GetGameObject(proList[i], "nextVal"):GetComponent("Text").text = GetPropertyFormatStr(proType, curTreeConfigData.Values[i][2])
                    this.treeLv.text = GetLanguageStrById(11802)
                end
            else
                proList[i]:SetActive(false)
            end
        end
        --消耗材料显示
        if curTreeConfigData.Consume and curTreeConfigData.Consume[1] and curTreeConfigData.Consume[1][1] then
            Util.ClearChild(this.showPanel1materialsGrid.transform)
            for i = 1, #curTreeConfigData.Consume do
                    SubUIManager.Open(SubUIConfig.ItemView, this.showPanel1materialsGrid.transform,false,curTreeConfigData.Consume[i],0.95,true,true)
                    if BagManager.GetItemCountById(curTreeConfigData.Consume[i][1]) < curTreeConfigData.Consume[i][2] then
                        treeIsCanUpLv =  1
                    end
            end
            this.showPanel1materialsGrid:SetActive(true)
            this.showPanel1SureBtn:SetActive(true)
        else
            this.showPanel1materialsGrid:SetActive(false)
            this.showPanel1SureBtn:SetActive(false)
        end
        --是否可升级显示
        if tonumber(_data.Limitate) > tonumber(PlayerManager.level) then--整层未开启开启--WorkShopManager.WorkShopData.lv
            treeIsCanUpLv =  3
            Util.SetGray(this.showPanel1SureBtn, true)
            return
        end
        if curTreeConfigData.OpenRules and curTreeConfigData.OpenRules[1] then
            local curNeedLv  = WorkShopManager.GetHeroPosTreeSingleData(curTreeConfigData.OpenRules[1])
            if curNeedLv < curTreeConfigData.OpenRules[2] then
                treeIsCanUpLv =  2
                Util.SetGray(this.showPanel1SureBtn, true)
                this.treeTishiText:SetActive(true)
                local needConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.WorkShopTechnology, "TechId", curTreeConfigData.OpenRules[1], "Level", curTreeConfigData.OpenRules[2])
                if needConfig then
                    this.treeTishiText:GetComponent("Text").text = GetLanguageStrById(12060)..needConfig.Name..GetLanguageStrById(12057)..curTreeConfigData.OpenRules[2]..GetLanguageStrById(12061)
                end
                return
            end
        end
        --local curTreePointLvEnd = workShopSetting[WorkShopManager.WorkShopData.lv].TechnologyLevel
        --curTreeConfigData.Level.."/"..curTreePointLvEnd
        if curTreeConfigData.Level >= curTreePointLvEnd  then
            Util.SetGray(this.showPanel1SureBtn, true)
            this.treeTishiText:SetActive(true)
            if curTreeConfigData.Level >= treePointLvEnd then
                this.treeTishiText:GetComponent("Text").text = GetLanguageStrById(12062)
            else
                this.treeTishiText:GetComponent("Text").text = GetLanguageStrById(12063)
            end
            treeIsCanUpLv =  4
            return
        end
            this.treeTishiText:SetActive(false)
            Util.SetGray(this.showPanel1SureBtn, false)


        if tonumber(_data.Limitate) <= tonumber(PlayerManager.level) then--整层已开启--WorkShopManager.WorkShopData.lv
            if curTreeConfigData.OpenRules and curTreeConfigData.OpenRules[1] then
                local curNeedLv  = WorkShopManager.GetHeroPosTreeSingleData(curTreeConfigData.OpenRules[1])
                if curNeedLv >= curTreeConfigData.OpenRules[2] then
                    Util.SetGray(this.showPanel1SureBtn, false)
                    this.treeTishiText:SetActive(false)
                else
                    treeIsCanUpLv =  2
                    Util.SetGray(this.showPanel1SureBtn, true)
                    this.treeTishiText:SetActive(true)
                    local needConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.WorkShopTechnology, "TechId", curTreeConfigData.OpenRules[1], "Level", curTreeConfigData.OpenRules[2])
                    if needConfig then
                        this.treeTishiText:GetComponent("Text").text = GetLanguageStrById(12060)..needConfig.Name..GetLanguageStrById(12057)..curTreeConfigData.OpenRules[2]..GetLanguageStrById(12061)
                    end
                end
            else
                this.treeTishiText:SetActive(false)
                Util.SetGray(this.showPanel1SureBtn, false)
            end
        else
            treeIsCanUpLv =  3
            Util.SetGray(this.showPanel1SureBtn, true)
        end
    end
end
--天赋树升级成功后回调
function this.WorkShopTreeLvUpRequestDelMaterial()
    --PopupTipPanel.ShowTip("升级成功！")
    --扣除升级材料
    --if curTreeConfigData.Consume and #curTreeConfigData.Consume>0 then
    --    for i = 1, #curTreeConfigData.Consume do
    --        BagManager.UpdateItemsNum(curTreeConfigData.Consume[i][1],curTreeConfigData.Consume[i][2])
    --    end
    --end
    --刷新当前界面天赋树数据 并 刷新界面
    --刷新manager数据
    WorkShopManager.SetHeroPosTreeSingleDataLV(curTreeConfigData.TechId,curTreeConfigData.Level+1)
    local curTreeData = WorkShopManager.GetSingleTreeData(curTreeConfigData.TechId)
    curTreeConfigData = curTreeData.conFigData
    this.SetTreeLvUpMatial(curTreeData)
    for i = 1, 3 do
        if #curTreeConfigData.Values >= i then
            Util.GetGameObject(proList[i].transform, "prop_effect"):SetActive(false)
            Util.GetGameObject(proList[i].transform, "prop_effect"):SetActive(true)
        end
    end
    --刷新WorkShowTechnologPanel 界面
    if openTreePanel then
        openTreePanel.CallShowPanelData(curTreeSelectIndex,curTreeConfigData)
    end
    --_isClicked = false
    this._isReqLvUp = false
end
function this.TreeRefreshBtnClick()
    --重置当前职业的天赋树，将消耗XX魂晶，同时返回升级消耗的材料和资源。
    local isHaveData = WorkShopManager.GetCurHeroPosTreeHaveData(curTreeConfigData.Profession)
    if isHaveData then
        local curRefreshStoreConFig = ConfigManager.GetConfigData(ConfigName.StoreConfig,10011)
        if curRefreshStoreConFig then
            local buyNum = WorkShopManager.WorkShopTreeRefreshNum >6 and 6 or WorkShopManager.WorkShopTreeRefreshNum
            if curRefreshStoreConFig.Cost and curRefreshStoreConFig.Cost[1][1] then
                local materialId = curRefreshStoreConFig.Cost[1][1]
                local materialData =  ConfigManager.GetConfigData(ConfigName.ItemConfig,materialId)
                local materialConsumeNum = curRefreshStoreConFig.Cost[2][buyNum+1]
                if materialData then
                    local str = GetLanguageStrById(12064)..materialConsumeNum..materialData.Name..GetLanguageStrById(12065)
                    MsgPanel.ShowTwo(str, function()end,function()
                        if BagManager.GetItemCountById(materialId) < materialConsumeNum  then
                            PopupTipPanel.ShowTipByLanguageId(12045)
                            return
                        end
                        NetManager.WorkShopTreeResetRequest(curTreeConfigData.Profession, function()
                            WorkShopManager.SetTreeRefreshNum(1)
                            --BagManager.UpdateItemsNum(materialId,materialConsumeNum)
                            WorkShopManager.RefreshCurHeroPosTreeAllData(curTreeConfigData.Profession)
                            local curTreeData = WorkShopManager.GetSingleTreeData(curTreeConfigData.TechId)
                            curTreeConfigData = curTreeData.conFigData
                            this.SetTreeLvUpMatial(curTreeData)
                            --WorkShopManager.SetHeroPosTreeSingleDataOpenState(curData.conFigData.TechId,true)
                            if openTreePanel then
                                openTreePanel.ShowPanelData(curTreeSelectIndex)
                            end
                            --FormationManager.UserPowerChanged()
                        end)
                    end, GetLanguageStrById(10719), GetLanguageStrById(10720))
                end
            end
        end
    else
        PopupTipPanel.ShowTipByLanguageId(12066)
    end

end
function this.UpdateBagGold()
   
    if proTypeId == 1 then--天赋树
        --消耗材料显示
        if treeIsCanUpLv ==  1 then  treeIsCanUpLv = 0 end
        if curTreeConfigData.Consume and curTreeConfigData.Consume[1] and curTreeConfigData.Consume[1][1] then
            Util.ClearChild(this.showPanel1materialsGrid.transform)
            for i = 1, #curTreeConfigData.Consume do
                SubUIManager.Open(SubUIConfig.ItemView, this.showPanel1materialsGrid.transform,false,curTreeConfigData.Consume[i],0.95,true)
                if BagManager.GetItemCountById(curTreeConfigData.Consume[i][1]) < curTreeConfigData.Consume[i][2] then
                    treeIsCanUpLv =  1
                end
            end
            this.showPanel1materialsGrid:SetActive(true)
            this.showPanel1SureBtn:SetActive(true)
        else
            this.showPanel1materialsGrid:SetActive(false)
            this.showPanel1SureBtn:SetActive(false)
        end
    elseif proTypeId == 4 then--重铸
        if selectEquipData and selectEquipData.equipConfig then
            isMaterialEnough= true
            materialsDataList = {}
            materialsDataList = WorkShopManager.WorkShopData.WorkShopRebuildConfig[selectEquipData.equipConfig.Quality - 1].SecondaryCost
            Util.ClearChild(this.materialsGrid.transform)
            for i = 1, #materialsDataList do
                local curItemData = ConfigManager.GetConfigData(ConfigName.ItemConfig, materialsDataList[i][1])
                local go = newObject(this.itemPre)
                go.transform:SetParent(this.materialsGrid.transform)
                go.transform.localScale = Vector3.one
                go.transform.localPosition = Vector3.zero;
                go:SetActive(true)
                if curItemData ~= nil then
                    Util.GetGameObject(go.transform, "icon"):SetActive(true)
                    Util.GetGameObject(go.transform, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(curItemData.ResourceID))
                    go.transform:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(curItemData.Quantity))
                end
                Util.GetGameObject(go.transform, "num"):SetActive(true)
                if BagManager.GetItemCountById(materialsDataList[i][1]) < materialsDataList[i][2] then
                    isMaterialEnough = false
                    Util.GetGameObject(go.transform, "num"):GetComponent("Text").text = string.format("<color=#FF0000FF>%s</color>", materialsDataList[i][2])
                else
                    Util.GetGameObject(go.transform, "num"):GetComponent("Text").text = string.format("<color=#FFFFFFFF>%s</color>", materialsDataList[i][2])
                end
            end
        end
    end
end
--界面关闭时调用（用于子类重写）
function WorkShopMainPanel:OnClose()

    for i = 1, 3 do
        Util.GetGameObject(proList[i].transform, "prop_effect"):SetActive(false)
    end
    if setRedPoint and LengthOfTable(setRedPoint) > 0 then
        for i, v in pairs(setRedPoint) do
           
            RedPointManager.PlayerPrefsSetStr("WorkShop"..v, 1)
            WorkShopManager.UpdataWorkShopRedPointState(2,v)
        end
    end
    FixedUpdateBeat:Remove(this.OnUpdate, self)

    -- 环境音停止
    SoundManager.PauseAmbient()
end

--界面销毁时调用（用于子类重写）
function WorkShopMainPanel:OnDestroy()

    SubUIManager.Close(this.UpView)
    poolManager:UnLoadLive("live2d_c_jpw_0024", this.live)
    this.live = nil

    ClearRedPointObject(RedPointType.Refining_Weapon)
    ClearRedPointObject(RedPointType.Refining_Armor)
end

return WorkShopMainPanel