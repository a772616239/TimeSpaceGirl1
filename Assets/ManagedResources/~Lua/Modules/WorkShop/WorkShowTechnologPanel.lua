require("Base/BasePanel")
WorkShowTechnologPanel = Inherit(BasePanel)
local this = WorkShowTechnologPanel
local propertyConfig=ConfigManager.GetConfig(ConfigName.PropertyConfig)
local workShopSetting=ConfigManager.GetConfig(ConfigName.WorkShopSetting)
local heroPos=0
local isFirst = true
local cengPreList = {}
local effectList = {}
local effectItemList = {}
local callList = Stack.New()
local oldPowerNum = 0


--天赋书
local treeTabs = {}
local curTreeConfigData = nil
local curTreeSelectIndex = 0
local proList = {}
local treeIsCanUpLv = 0 --0 可以升级 1 材料不足 2 前置条件等级不足

local cursortingOrder

local isMaterialEnough = true
--天赋树长按升级
local _isClicked = false
this._isReqLvUp = false
local _isLongPress = false
this.isCanLongUpLv = true
--监听长按事件
local timePressStarted
local isTriggerLongClick = false--长按是否升过级
--初始化组件（用于子类重写）
function WorkShowTechnologPanel:InitComponent()

    cursortingOrder = 0
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    this.powerNum = Util.GetGameObject(self.transform, "powerBtn/value"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.selectImage = Util.GetGameObject(self.transform, "bg/selectImage")
    this.bg = Util.GetGameObject(self.transform, "bg")
    this.grid = Util.GetGameObject(self.transform, "rect/grid")
    for i = 1, 10 do
        cengPreList[i] = Util.GetGameObject(this.grid, "singlePre"..i)
    end
    this.bgeffect = Util.GetGameObject(self.transform, "bg/bgeffect")
    this.mask= Util.GetGameObject(self.transform, "mask")
    this.powerBtn = Util.GetGameObject(self.transform, "powerBtn")
    this.posImage = Util.GetGameObject(self.transform, "titleImage/posImage"):GetComponent("Image")
    this.posText = Util.GetGameObject(self.transform, "titleImage/posText"):GetComponent("Text")


    --天赋树
    this.showPanel1 = Util.GetGameObject(self.transform, "showPanel1")
    this.showPanel1selectBtn = Util.GetGameObject(self.transform, "showPanel1/Tabs/selectBtn")
    this.showPanel1materialsGrid = Util.GetGameObject(self.transform, "showPanel1/materialsInfo/materialsRect/materialsGrid")
    this.showPanel1SureBtn = Util.GetGameObject(self.transform, "showPanel1/sureBtn")
    this.upLvTrigger = Util.GetEventTriggerListener(this.showPanel1SureBtn)
    this.sureBtnParent = Util.GetGameObject(this.transform, "sureBtnParent")

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
end

--绑定事件（用于子类重写）
function WorkShowTechnologPanel:BindEvent()

    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function()
        PopupTipPanel.ShowTipByLanguageId(12067)
    end)
    Util.AddClick(this.powerBtn, function()
        UIManager.OpenPanel(UIName.WorkShopAttributeAdditionPanel,heroPos)
    end)


    for i = 1, 5 do
        Util.AddClick(treeTabs[i], function ()
            this.ShowTreePanel(i)
        end)
    end
    --天赋树升级按钮
    Util.AddClick(this.showPanel1SureBtn, function()
        if Time.realtimeSinceStartup - timePressStarted <= 0.4 then
            this.showPanel1SureBtnClickEvent(true)
        end
    end)

    this._onPointerDown = function(Pointgo, data)
        isTriggerLongClick = false
        _isClicked = true
        timePressStarted = Time.realtimeSinceStartup
    end

    this._onPointerUp = function(Pointgo, data)
       
        if _isLongPress and isTriggerLongClick then
                --连续升级抬起请求升级
                this.TreeLongLvUpClick()
        end
        _isClicked = false
        _isLongPress = false
    end
    this.upLvTrigger.onPointerDown = this.upLvTrigger.onPointerDown + this._onPointerDown
    this.upLvTrigger.onPointerUp = this.upLvTrigger.onPointerUp + this._onPointerUp


    Util.AddClick(this.showPanel1RefreshBtn, function()
        this.TreeRefreshBtnClick()
    end)
end

--添加事件监听（用于子类重写）
function WorkShowTechnologPanel:AddListener()

end

--移除事件监听（用于子类重写）
function WorkShowTechnologPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WorkShowTechnologPanel:OnOpen(_heroPos)


    heroPos = _heroPos and _heroPos or 1
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.FixforDan })
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function WorkShowTechnologPanel:OnShow()

    isFirst = true
    this.ShowTreePanel(heroPos)

    FixedUpdateBeat:Add(this.OnUpdate, self)
end
function this.OnUpdate()
    if _isClicked then
        if Time.realtimeSinceStartup - timePressStarted > 0.4 then

            _isLongPress = true
            if not this._isReqLvUp then

                this._isReqLvUp = true
                this.showPanel1SureBtnClickEvent(false)
            end
        end
    end
end
function WorkShowTechnologPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.gameObject, self.sortingOrder - cursortingOrder)
    cursortingOrder = self.sortingOrder
end
function this.CallShowPanelData(heroPos,selectUpLvTree)
    local newPowerNum = WorkShopManager.CalculateTreeWarForce(heroPos)
    -- if oldPowerNum ~= newPowerNum then
    --     UIManager.OpenPanel(UIName.WarPowerChangeNotifyPanelV2,{oldValue = oldPowerNum,newValue = newPowerNum})
    -- end
    RefreshPower(oldPowerNum, newPowerNum)
    this.ShowPanelData(heroPos,selectUpLvTree)
end
--设置英雄列表数据
function this.ShowPanelData(heroPos,selectUpLvTree)--selectUpLvTree 播放升级的特效
    --isFirst = true
    this.posImage.sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(heroPos))
    this.posText.text = GetJobStrByJobNum(heroPos)
    local curHeroPosAllData = WorkShopManager.GetTreeCurHeroPosAllData(heroPos)
    effectList = {}
    effectItemList = {}
    for i = 1, 10 do
        if #curHeroPosAllData >= i then
            effectList[i] = {}
            effectItemList[i] = {}
            cengPreList[i]:SetActive(true)
            this.ShowTreeDatas(cengPreList[i],curHeroPosAllData[i],i,selectUpLvTree)
        else
            cengPreList[i]:SetActive(false)
        end
    end
    this.CallBackListShow()
end
function this.ShowTreeDatas(_go,curSingleHeroPosAllData,effectListIndex,selectUpLvTree)
    local itemList = {}
    local lineList = {}
    for i = 1, 10 do
        itemList[i] = Util.GetGameObject(_go.transform, "itemList/item"..i)
        lineList[i] = Util.GetGameObject(_go.transform, "bg/line/line"..i)
    end
   
    oldPowerNum = WorkShopManager.CalculateTreeWarForce(heroPos)
    this.powerNum.text = oldPowerNum
    effectList[effectListIndex][1]={}
    effectList[effectListIndex][2]={}
    effectList[effectListIndex][3]={}
    effectItemList[effectListIndex][1]={}
    effectItemList[effectListIndex][2]={}
    effectItemList[effectListIndex][3]={}
    for i = 1, #curSingleHeroPosAllData do
        local curData = curSingleHeroPosAllData[i]
        Util.GetGameObject(itemList[i].transform, "icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(curData.icon))--curData.icon
        local curTreePointLvEnd = workShopSetting[PlayerManager.level].TechnologyLevel--工坊解锁的等级上限--WorkShopManager.WorkShopData.lv
        local treePointLvEnd = WorkShopManager.WorkShopTreeSinglePointLvEnd[curData.conFigData.TechId]--次天赋点最终等级上限
        curTreePointLvEnd = curTreePointLvEnd > treePointLvEnd and treePointLvEnd or curTreePointLvEnd
        Util.GetGameObject(itemList[i].transform, "lv"):GetComponent("Text").text=curData.conFigData.Level.."/"..curTreePointLvEnd
        Util.GetGameObject(itemList[i].transform, "maxlv"):SetActive(curData.conFigData.Level >= treePointLvEnd)
        Util.GetGameObject(itemList[i].transform, "lv"):SetActive(curData.conFigData.Level < treePointLvEnd)
        local jieSuoEffect = Util.GetGameObject(lineList[i].transform, "jieSuoEffect")
        local lineEffect = Util.GetGameObject(lineList[i].transform, "lineEffect")
        lineEffect:SetActive(false)
        jieSuoEffect:SetActive(false)
        if isFirst then
                this.SetSelectImage(Util.GetGameObject(itemList[i].transform, "icon"))
                this.SetTreeLvUpMatial(curData)
            isFirst = false
        end
        Util.AddOnceClick( Util.GetGameObject(itemList[i].transform, "icon"), function()
                this.SetSelectImage(Util.GetGameObject(itemList[i].transform, "icon"))
            this.SetTreeLvUpMatial(curData)
        end)
        --单个层级置灰限制
        if tonumber(curData.Limitate) <= tonumber(PlayerManager.level) then--整层已开启--WorkShopManager.WorkShopData.lv
            --单个限制
            if curData.conFigData.OpenRules and curData.conFigData.OpenRules[1] then
                local curNeedLv  = WorkShopManager.GetHeroPosTreeSingleData(curData.conFigData.OpenRules[1])
                if curData.conFigData.Level > 0 or curNeedLv >= curData.conFigData.OpenRules[2] then--已开启
                    if curData.openState == false then
                        Util.SetGray(itemList[i], true)
                        lineList[i]:SetActive(false)
                        if i == 1 then
                            table.insert(effectList[effectListIndex][1],lineList[i])
                            table.insert(effectItemList[effectListIndex][1],itemList[i])
                        elseif i == 2 or i == 3 then
                            table.insert(effectList[effectListIndex][2],lineList[i])
                            table.insert(effectItemList[effectListIndex][2],itemList[i])
                        elseif i == 4 or i == 5 then
                            table.insert(effectList[effectListIndex][3],lineList[i])
                            table.insert(effectItemList[effectListIndex][3],itemList[i])
                        end
                        WorkShopManager.SetHeroPosTreeSingleDataOpenState(curData.conFigData.TechId,true)
                    else
                        Util.SetGray(itemList[i], false)
                        lineList[i]:SetActive(true)
                        if selectUpLvTree and curData.conFigData.TechId == selectUpLvTree.TechId then
                            jieSuoEffect:SetActive(true)
                        end
                    end
                else--未开启
                    if curData.openState == false then--从来没开启过
                        Util.SetGray(itemList[i], true)
                        lineList[i]:SetActive(false)
                    else
                        Util.SetGray(itemList[i], false)
                        lineList[i]:SetActive(true)
                    end
                end
            else
                Util.SetGray(itemList[i], false)
                lineList[i]:SetActive(true)
                if selectUpLvTree and curData.conFigData.TechId == selectUpLvTree.TechId then
                    jieSuoEffect:SetActive(true)
                end
            end
        else
            Util.SetGray(itemList[i], true)
            lineList[i]:SetActive(false)
        end
    end
    --整层是否解锁
    local mask = Util.GetGameObject(_go.transform,"mask")
    if tonumber(curSingleHeroPosAllData.Limitate) <= tonumber(PlayerManager.level) then--WorkShopManager.WorkShopData.lv
        mask:SetActive(false)
    else
        mask:SetActive(true)
        Util.GetGameObject(mask,"openlv/Text"):GetComponent("Text").text = GetLanguageStrById(12068).. curSingleHeroPosAllData.Limitate..GetLanguageStrById(12069)
        Util.AddOnceClick(mask, function()
            PopupTipPanel.ShowTip(GetLanguageStrById(12068).. curSingleHeroPosAllData.Limitate..GetLanguageStrById(12069))
        end)
    end
end
function this.SetSelectImage(btnTra)
    if btnTra then
        this.selectImage:SetActive(true)
        this.selectImage.transform:SetParent(btnTra.transform)
        this.selectImage.transform.localScale = Vector3.one
        this.selectImage.transform.localPosition = Vector3.zero
        Util.SetGray(this.selectImage, false)
    else
        this.selectImage.transform:SetParent(this.bg.transform)
        this.selectImage:SetActive(false)
    end
end
function this.CallBackListShow()
    if effectList and #effectList > 0 then
        local showList = {}
        local showItemList = {}
        if effectList and #effectList > 0 then
            for i = 1, #effectList do
                if effectList[i] and #effectList>0 then
                    for j = 1, #effectList[i] do
                        if effectList[i][j] and #effectList[i][j]>0 then
                            table.insert(showList,effectList[i][j])
                            table.insert(showItemList,effectItemList[i][j])
                        end
                    end
                end
            end
        end
        --_isClicked = false
        --this._isReqLvUp = false
        callList:Clear()
        callList:Push(function ()

            this.mask:SetActive(false)
            this.isCanLongUpLv = true
            this._isReqLvUp = false

        end)
        if #showList > 0 then
            _isClicked = false
        end
        for i = #showList, 1, -1 do
            this.isCanLongUpLv = false
            local view = showList[i]
            local viewItem = showItemList[i]
            callList:Push(function ()
                this.mask:SetActive(true)
                for j = 1, #view do
                    local jieSuoEffect = Util.GetGameObject(view[j].transform, "jieSuoEffect")
                    local lineEffect = Util.GetGameObject(view[j].transform, "lineEffect")
                    lineEffect:SetActive(false)
                    jieSuoEffect:SetActive(false)
                    lineEffect:SetActive(true)
                    Timer.New(function ()
                        view[j]:SetActive(true)
                        Timer.New(function ()
                            Util.SetGray(viewItem[j], false)
                            jieSuoEffect:SetActive(true)
                        end, 0.4):Start()
                    end, 1):Start()
                end
                local time2 = Timer.New(function ()
                    callList:Pop()()
                end, 1.5)
                time2:Start()
            end)
        end
        callList:Pop()()
    end
end
function this.showPanel1SureBtnClickEvent(isSingleLvUp)
    if treeIsCanUpLv == 0 and curTreeConfigData and this.isCanLongUpLv then
        if isSingleLvUp then

            NetManager.WorkShopTreeLvUpRequest(curTreeConfigData.TechId,curTreeConfigData.Level + 1, function()
                this.WorkShopTreeLvUpRequestDelMaterial(isSingleLvUp)
                FormationManager.UserPowerChanged()
            end)
        else
            isTriggerLongClick = true
            this.WorkShopTreeLvUpRequestDelMaterial(isSingleLvUp)
            --FormationManager.UserPowerChanged()
        end
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
--长按升级结束后请求协议
function this.TreeLongLvUpClick()
    NetManager.WorkShopTreeLvUpRequest(curTreeConfigData.TechId,curTreeConfigData.Level, function()
        --this.WorkShopTreeLvUpRequestDelMaterial()
        FormationManager.UserPowerChanged()
    end)
end
--天赋树
function this.ShowTreePanel(_tabsIndex)
    if this._isReqLvUp == false then
        curTreeSelectIndex = _tabsIndex
        heroPos = _tabsIndex
        isFirst = true
        this:SetTreeSelectBtn(curTreeSelectIndex)
        this.ShowPanelData(curTreeSelectIndex)
    end
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
                    Util.GetGameObject(proList[i], "nextVal"):SetActive(true)
                    Util.GetGameObject(proList[i], "Image"):SetActive(true)
                    Util.GetGameObject(proList[i], "nextVal"):GetComponent("Text").text = GetPropertyFormatStr(proType, nextTreeConfigData.Values[i][2])
                else
                    --Util.GetGameObject(proList[i], "nextVal"):GetComponent("Text").text = GetPropertyFormatStr(proType, curTreeConfigData.Values[i][2])
                    Util.GetGameObject(proList[i], "Image"):SetActive(false)
                    Util.GetGameObject(proList[i], "nextVal"):SetActive(false)
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
            --this.showPanel1SureBtn:SetActive(true)
            this.showPanel1SureBtn.transform:SetParent(this.showPanel1.transform)
        else
            this.showPanel1materialsGrid:SetActive(false)
            --this.showPanel1SureBtn:SetActive(false)
            this.showPanel1SureBtn.transform:SetParent(this.sureBtnParent.transform)
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
function this.WorkShopTreeLvUpRequestDelMaterial(isSingleLvUp)
    --PopupTipPanel.ShowTip("升级成功！")
    --扣除升级材料连续升级
    if isSingleLvUp == false then
        if curTreeConfigData.Consume and #curTreeConfigData.Consume>0 then
            for i = 1, #curTreeConfigData.Consume do
                BagManager.HeroLvUpUpdateItemsNum(curTreeConfigData.Consume[i][1],curTreeConfigData.Consume[i][2])
            end
        end
    end
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

        this.CallShowPanelData(curTreeSelectIndex,curTreeConfigData)

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
                    local str = GetLanguageStrById(12064)..materialConsumeNum..GetLanguageStrById(materialData.Name)..GetLanguageStrById(12065)
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
                            this.ShowPanelData(curTreeSelectIndex)
                        end)
                    end, GetLanguageStrById(10719), GetLanguageStrById(10720))
                end
            end
        end
    else
        PopupTipPanel.ShowTipByLanguageId(12070)
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
            --this.showPanel1SureBtn:SetActive(true)
            this.showPanel1SureBtn.transform:SetParent(this.showPanel1.transform)
        else
            this.showPanel1materialsGrid:SetActive(false)
            --this.showPanel1SureBtn:SetActive(false)
            this.showPanel1SureBtn.transform:SetParent(this.sureBtnParent.transform)
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
function WorkShowTechnologPanel:OnClose()

    this.SetSelectImage()
    FixedUpdateBeat:Remove(this.OnUpdate, self)
end

--界面销毁时调用（用于子类重写）
function WorkShowTechnologPanel:OnDestroy()

    SubUIManager.Close(this.UpView)
end

return WorkShowTechnologPanel