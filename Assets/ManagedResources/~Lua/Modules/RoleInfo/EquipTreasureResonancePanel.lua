require("Base/BasePanel")
EquipTreasureResonancePanel = Inherit(BasePanel)
local this = EquipTreasureResonancePanel
local jewelConfig = ConfigManager.GetConfig(ConfigName.JewelConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local TabBox = require("Modules/Common/TabBox")
local _TabData={
    [1] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(11797) },
    [2] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(11798) },
}
local _TabFontColor = { default = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1)}
local curHeroData
local curTabIndex = 1--当前是强化  还是 精炼
local equipTreasureList = {}--宝器对象
local curJewelResonanceConfig--当前共鸣静态数据
local nextJewelResonanceConfig--下一共鸣静态数据
local curProList = {}--当前共鸣属性
local nextProList = {}--下一共鸣属性
--初始化组件（用于子类重写）
function EquipTreasureResonancePanel:InitComponent()
    this.TabCtrl = TabBox.New()
    this.tabBox = Util.GetGameObject(self.transform, "TabBox")
    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.curProListCurLv = Util.GetGameObject(self.transform, "materialImageBg/curProList/curLv"):GetComponent("Text")
    this.nextProListCurLv = Util.GetGameObject(self.transform, "materialImageBg/nextProList/curLv"):GetComponent("Text")
    this.nextProList = Util.GetGameObject(self.transform, "materialImageBg/nextProList")
    this.nextHint=Util.GetGameObject(self.transform, "materialImageBg/nextProList/Text"):GetComponent("Text")
    this.hintInfo=Util.GetGameObject(self.transform, "titleBg/hintInfo"):GetComponent("Text")
    for i = 1, 2 do
        equipTreasureList[i] = Util.GetGameObject(self.transform, "grid/equipTreasure ("..i..")")
        curProList[i] = Util.GetGameObject(self.transform, "materialImageBg/curProList/pro/Pro ("..i..")")
        nextProList[i] = Util.GetGameObject(self.transform, "materialImageBg/nextProList/pro/Pro ("..i..")")
    end
    this.targetObj=Util.GetGameObject(self.transform, "titleBg/Image (2)")
end

--绑定事件（用于子类重写）
function EquipTreasureResonancePanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function EquipTreasureResonancePanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Treasure.TreasureLvUp, this.CurrEquipDataChange)
end

--移除事件监听（用于子类重写）
function EquipTreasureResonancePanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Treasure.TreasureLvUp, this.CurrEquipDataChange)
end

function this.CurrEquipDataChange()
    this.OnShowData()
end
--界面打开时调用（用于子类重写）
function EquipTreasureResonancePanel:OnOpen(_curHeroData,_curTabIndex)
    curHeroData = _curHeroData
    curTabIndex = _curTabIndex or 1
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function EquipTreasureResonancePanel:OnShow()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:Init(this.tabBox, _TabData,curTabIndex)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)  
    this.OnShowData()
end

--限时内容
function this.OnShowData()
    --获取穿戴宝物强化/精炼的最小等级
    local minLv--最小等级
    for i = 1, #curHeroData.jewels do
        local curEquipTreasureData = EquipTreasureManager.GetSingleEquipTreasreData(curHeroData.jewels[i])
        if curTabIndex == 1 then
            if minLv then
                if curEquipTreasureData.lv < minLv then
                    minLv = curEquipTreasureData.lv
                end
            else
                minLv = curEquipTreasureData.lv
            end
            this.hintInfo.text=GetLanguageStrById(11799)
        elseif curTabIndex  == 2 then
            if minLv then
                if curEquipTreasureData.refineLv < minLv then
                    minLv = curEquipTreasureData.refineLv
                end
            else
                minLv = curEquipTreasureData.refineLv
            end
            this.hintInfo.text=GetLanguageStrById(11800)
        end
    end
    
    curJewelResonanceConfig = nil
    nextJewelResonanceConfig = nil
    local allCurTypeJewelResonanceConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.JewelResonanceConfig,"Type",curTabIndex)
    table.sort(allCurTypeJewelResonanceConfig,function(a,b)
        return a.SortId<b.SortId
    end)
    
    for i = 1, #allCurTypeJewelResonanceConfig do
        --获取当前强化/精炼 大师等级数据
        if allCurTypeJewelResonanceConfig[i].Level <= minLv then
            if curJewelResonanceConfig then
                if curJewelResonanceConfig.SortId < allCurTypeJewelResonanceConfig[i].SortId then
                    curJewelResonanceConfig = allCurTypeJewelResonanceConfig[i]
                end
            else
                curJewelResonanceConfig = allCurTypeJewelResonanceConfig[i]
            end
        end
        --获取下一级强化/精炼 大师等级数据
        if  allCurTypeJewelResonanceConfig[i].Level > minLv  then
            if curJewelResonanceConfig then
                if nextJewelResonanceConfig==nil then
                    if allCurTypeJewelResonanceConfig[i].SortId == curJewelResonanceConfig.SortId+1 then
                        nextJewelResonanceConfig = allCurTypeJewelResonanceConfig[i]
                    end
                end
            end
        end
    end
    --curJewelResonanceConfig = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.JewelResonanceConfig,"Type",curTabIndex,"SortId",nextJewelResonanceConfig.SortId - 1)
    for i = 1, #curHeroData.jewels do
        this.OnShowSingleEquipTreasure(equipTreasureList[i],curHeroData.jewels[i])
    end
    this.OnShowPro()
end
function this.OnShowSingleEquipTreasure(go,equipTreasureDid)
    local isMaxLv = false
    local curEquipTreasureData = EquipTreasureManager.GetSingleEquipTreasreData(equipTreasureDid)
    if not curEquipTreasureData then return end
    local configData = jewelConfig[curEquipTreasureData.id]
    Util.GetGameObject(go.transform,"equip/icon"):GetComponent("Image").sprite=Util.LoadSprite(curEquipTreasureData.icon)
    Util.GetGameObject(go.transform,"equip/proImage"):GetComponent("Image").sprite=Util.LoadSprite(GetProStrImageByProNum(configData.Race))
    Util.GetGameObject(go.transform,"equip/frame"):GetComponent("Image").sprite=Util.LoadSprite(curEquipTreasureData.frame)
    Util.GetGameObject(go.transform,"name"):GetComponent("Text").text = curEquipTreasureData.itemConfig.Name
    Util.GetGameObject(go.transform,"equip/strongLv"):GetComponent("Text").text = curEquipTreasureData.lv
    Util.GetGameObject(go.transform,"equip/refineLv"):GetComponent("Text").text = curEquipTreasureData.refineLv
    if curTabIndex  == 1 then
        if nextJewelResonanceConfig and nextJewelResonanceConfig.Level then
            if curEquipTreasureData.lv>=curEquipTreasureData.maxLv then
                Util.GetGameObject(go.transform,"btn/Text"):GetComponent("Text").text = GetLanguageStrById(11089)
            else
                Util.GetGameObject(go.transform,"btn/Text"):GetComponent("Text").text = GetLanguageStrById(11801)
            end
            Util.GetGameObject(go.transform,"progress"):GetComponent("Text").text = curEquipTreasureData.lv.."/"..nextJewelResonanceConfig.Level
            Util.GetGameObject(go.transform,"equip/proBar"):GetComponent("Image").fillAmount = curEquipTreasureData.lv/nextJewelResonanceConfig.Level
        else
            Util.GetGameObject(go.transform,"progress"):GetComponent("Text").text = GetLanguageStrById(11802)
            Util.GetGameObject(go.transform,"btn/Text"):GetComponent("Text").text = GetLanguageStrById(11089)
            Util.GetGameObject(go.transform,"equip/proBar"):GetComponent("Image").fillAmount =1
        end

        --点击强化按钮
        Util.AddOnceClick(Util.GetGameObject(go.transform,"btn"), function()
            if curEquipTreasureData.lv==curEquipTreasureData.maxLv then
                PopupTipPanel.ShowTipByLanguageId(11803)
                return
            end
            UIManager.OpenPanel(UIName.EquipTreasureStrongPopup,curEquipTreasureData,1)
        end)
      elseif  curTabIndex  == 2 then
        if nextJewelResonanceConfig and nextJewelResonanceConfig.Level then
            if curEquipTreasureData.refineLv>=curEquipTreasureData.maxRefineLv then
                Util.GetGameObject(go.transform,"btn/Text"):GetComponent("Text").text = GetLanguageStrById(11089)
            else
                Util.GetGameObject(go.transform,"btn/Text"):GetComponent("Text").text = GetLanguageStrById(11804)
            end
            Util.GetGameObject(go.transform,"progress"):GetComponent("Text").text = curEquipTreasureData.refineLv.."/"..nextJewelResonanceConfig.Level
            Util.GetGameObject(go.transform,"equip/proBar"):GetComponent("Image").fillAmount = curEquipTreasureData.refineLv/nextJewelResonanceConfig.Level
        else
            Util.GetGameObject(go.transform,"progress"):GetComponent("Text").text = GetLanguageStrById(11802)
            Util.GetGameObject(go.transform,"btn/Text"):GetComponent("Text").text = GetLanguageStrById(11089)
        end
        --点击精炼按钮
        Util.AddOnceClick(Util.GetGameObject(go.transform,"btn"), function()
            if curEquipTreasureData.refineLv==curEquipTreasureData.maxRefineLv then
                PopupTipPanel.ShowTipByLanguageId(11803)
                return
            end
            UIManager.OpenPanel(UIName.EquipTreasureStrongPopup,curEquipTreasureData,2)
        end)
    end
end
--属性展示
function this.OnShowPro()
    local currLv=0
    if curJewelResonanceConfig and curJewelResonanceConfig.Level then
        for i = 1, #curJewelResonanceConfig.Property do
            Util.GetGameObject(curProList[i], "curProName"):GetComponent("Text").text  = propertyConfig[curJewelResonanceConfig.Property[i][1]].Info
            Util.GetGameObject(curProList[i], "curProVal"):GetComponent("Text").text  = GetPropertyFormatStr(propertyConfig[curJewelResonanceConfig.Property[i][1]].Style,curJewelResonanceConfig.Property[i][2])
        end
        currLv=curJewelResonanceConfig.Level
    else
        this.curProListCurLv.text = 0
        if nextJewelResonanceConfig and nextJewelResonanceConfig.Property then
            for i = 1, #nextJewelResonanceConfig.Property do
                Util.GetGameObject(curProList[i], "curProName"):GetComponent("Text").text  = propertyConfig[nextJewelResonanceConfig.Property[i][1]].Info
                Util.GetGameObject(curProList[i], "curProVal"):GetComponent("Text").text  = GetPropertyFormatStr(propertyConfig[nextJewelResonanceConfig.Property[i][1]].Style,0)
            end
        end
    end
    if curTabIndex==1 then
        this.curProListCurLv.text =string.format(GetLanguageStrById(11805),curJewelResonanceConfig.SortId)
    else
        this.curProListCurLv.text =string.format(GetLanguageStrById(11806),curJewelResonanceConfig.SortId)
    end
    if nextJewelResonanceConfig and nextJewelResonanceConfig.Level then
        this.nextProList:SetActive(true)
        this.targetObj.gameObject:SetActive(true)
        if curTabIndex==1 then
            this.nextProListCurLv.text = string.format(GetLanguageStrById(11807),nextJewelResonanceConfig.SortId)
            this.nextHint.text=string.format(GetLanguageStrById(11808),nextJewelResonanceConfig.Level)
        else
            this.nextProListCurLv.text = string.format(GetLanguageStrById(11809),nextJewelResonanceConfig.SortId)
            this.nextHint.text=string.format(GetLanguageStrById(11810),nextJewelResonanceConfig.Level)
        end

        for i = 1, #nextJewelResonanceConfig.Property do
            Util.GetGameObject(nextProList[i], "curProName"):GetComponent("Text").text  = propertyConfig[nextJewelResonanceConfig.Property[i][1]].Info
            Util.GetGameObject(nextProList[i], "curProVal"):GetComponent("Text").text  = GetPropertyFormatStr(propertyConfig[nextJewelResonanceConfig.Property[i][1]].Style,nextJewelResonanceConfig.Property[i][2])
        end
    else
        this.nextProList:SetActive(false)
        this.targetObj.gameObject:SetActive(false)
    end
end
-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    local tabImage = Util.GetGameObject(tab,"Image")
    tabImage:GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
end
--切换视图
function this.SwitchView(index)
    curTabIndex = index
    this.OnShowData()
end
--界面关闭时调用（用于子类重写）
function EquipTreasureResonancePanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function EquipTreasureResonancePanel:OnDestroy()
end

return EquipTreasureResonancePanel