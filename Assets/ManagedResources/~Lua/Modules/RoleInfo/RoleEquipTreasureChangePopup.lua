require("Base/BasePanel")
RoleEquipTreasureChangePopup = Inherit(BasePanel)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local spcialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local this=RoleEquipTreasureChangePopup
local type--1 穿装备  2 卸装备 3 替换装备
local curHeroData
local curEquipData
local nextEquipData
local openThisPanel
local equipIdList
local equipDataList
local position
local curMainpropertyList={}
local nextMainPropertyList={}
local curPropertyList={}
local nextPropertyList={}
--初始化组件（用于子类重写）
function RoleEquipTreasureChangePopup:InitComponent()
    this.btnBack= Util.GetGameObject(self.transform, "btnBack")
    this.bg1= Util.GetGameObject(self.transform, "GameObject/bg1")
    this.desc1= Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/Text"):GetComponent("Text")
    this.currEquipProImg=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/proImg"):GetComponent("Image")
    this.curEquipName=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/name/text"):GetComponent("Text")
    this.curEquipFrame=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/frame"):GetComponent("Image")
    this.curEquipIcon=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/icon"):GetComponent("Image")
    this.curEquipTypeText=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/equipTypeText"):GetComponent("Text")
    this.curEquipLvText=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/lvTxt"):GetComponent("Text")
    this.curEquipRefineLvTxt=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/starTxt"):GetComponent("Text")
    this.curRefinePropertyTxt=Util.GetGameObject(self.transform, "GameObject/bg1/mainPro/Text2")
    this.curEquipBtns=Util.GetGameObject(self.transform, "GameObject/bg1/btns")
    this.curEquipBtnStrong=Util.GetGameObject(self.transform, "GameObject/bg1/btns/btnStrong")
    this.curEquipBtnRefine=Util.GetGameObject(self.transform, "GameObject/bg1/btns/btnRefine")
    this.curEquipBtnRemove=Util.GetGameObject(self.transform, "GameObject/bg1/btns/btnRemove")
    this.curEquipBtnAdd=Util.GetGameObject(self.transform, "GameObject/bg1/btns/btnAdd")
    this.curEquipBtnChange=Util.GetGameObject(self.transform, "GameObject/bg1/btns/btnChange")
    this.qualityText=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/qualityText"):GetComponent("Text")
    this.powerNum1=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/powerNum"):GetComponent("Text")
    this.powerUPorDown1=Util.GetGameObject(self.transform, "GameObject/bg1/equipInfo/powerUPorDown")
    this.propertyPre=Util.GetGameObject(self.transform, "GameObject/bg1/PropertyTxt")
    this.curEquipSign=Util.GetGameObject(self.transform, "GameObject/bg1/Text")
    this.curMainPropertyGrid=Util.GetGameObject(self.transform, "GameObject/bg1/mainPro/grid")
    this.nextMainPropertyGrid=Util.GetGameObject(self.transform, "GameObject/bg2/mainPro/grid")
    this.propertyPre:SetActive(false)
    this.curPropertyGrid=Util.GetGameObject(self.transform, "GameObject/bg1/grid")
    this.bg2= Util.GetGameObject(self.transform, "GameObject/bg2")
    this.nextPropertyGrid=Util.GetGameObject(self.transform, "GameObject/bg2/grid")
    this.nextRefinePropertyTxt=Util.GetGameObject(self.transform, "GameObject/bg2/mainPro/Text2")
    this.desc2= Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/Text"):GetComponent("Text")
    this.nextEquipName=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/name/text"):GetComponent("Text")
    this.nextEquipFrame=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/frame"):GetComponent("Image")
    this.nextEquipIcon=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/icon"):GetComponent("Image")
    this.nextEquipTypeText=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/equipTypeText"):GetComponent("Text")
    this.nextEquipLvText=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/lvTxt"):GetComponent("Text")
    this.nextEquipBtns=Util.GetGameObject(self.transform, "GameObject/bg2/btns")
    this.nextEquipBtns:SetActive(false)
    this.nextEquipProImg=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/proImg"):GetComponent("Image")
    this.nextEquipBtnStrong=Util.GetGameObject(self.transform, "GameObject/bg2/btns/btnStrong")
    this.nextEquipBtnRefine=Util.GetGameObject(self.transform, "GameObject/bg2/btns/btnRefine")
    this.nextEquipBtnRemove=Util.GetGameObject(self.transform, "GameObject/bg2/btns/btnRemove")
    this.nextEquipBtnAdd=Util.GetGameObject(self.transform, "GameObject/bg2/btns/btnAdd")
    this.nextEquipBtnChange=Util.GetGameObject(self.transform, "GameObject/bg2/btns/btnChange")
    this.qualityText2=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/qualityText"):GetComponent("Text")
    this.GameObject=Util.GetGameObject(self.transform, "GameObject")
    this.powerNum2=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/powerNum"):GetComponent("Text")
    this.powerUPorDown2=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/powerUPorDown")
    this.nextEquipRefineLvTxt=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/starTxt"):GetComponent("Text")
 
end

--绑定事件（用于子类重写）
function RoleEquipTreasureChangePopup:BindEvent()

    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.curEquipBtnRemove, function()

        equipIdList={}
        equipDataList={}
        table.insert(equipIdList,curEquipData.idDyn)
        table.insert(equipDataList,curEquipData)
        NetManager.EquipUnLoadOptRequest(curHeroData.dynamicId,equipIdList ,2,function ()
            self:ClosePanel()
            openThisPanel.UpdateEquipPosHeroData(2,type,equipDataList)
        end)
    end)
    Util.AddClick(this.curEquipBtnAdd, function()
        local config=spcialConfig[40]
        if config then
            local limits = string.split(config.Value, "|")
            if limits then
                local heroConfig=ConfigManager.GetConfigData(ConfigName.HeroConfig,curHeroData.id)
                local lvs=string.split(limits[1],"#")
                local stars=string.split(limits[2],"#")
                local lv=tonumber(lvs[2])
                if PlayerManager.level<lv then
                    PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11829),lv))
                    return
                else
                    local star=tonumber(stars[2])
                    if heroConfig~=nil and curHeroData.star< star then
                        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11830),star))
                        return
                    end
                end
            end
        end
        equipIdList={}
        equipDataList={}
        table.insert(equipIdList,curEquipData.idDyn)
        table.insert(equipDataList,curEquipData)
        NetManager.EquipWearRequest(curHeroData.dynamicId,equipIdList,2,function ()
            self:ClosePanel()
            openThisPanel.UpdateEquipPosHeroData(2,type,equipDataList,0,position)
        end)
    end)
    Util.AddClick(this.nextEquipBtnChange, function()
        equipIdList={}
        equipDataList={}
        table.insert(equipIdList,nextEquipData.idDyn)
        table.insert(equipDataList,nextEquipData)
        NetManager.EquipWearRequest(curHeroData.dynamicId,equipIdList,2,function ()
            self:ClosePanel()
            openThisPanel.UpdateEquipPosHeroData(2,type,equipDataList,curEquipData,position)
        end)
    end)

    Util.AddClick(this.nextEquipBtnStrong, function()        
        UIManager.OpenPanel(UIName.EquipTreasureStrongPopup,nextEquipData,1)
    end)
    Util.AddClick(this.curEquipBtnStrong, function()
        UIManager.OpenPanel(UIName.EquipTreasureStrongPopup,curEquipData,1)
    end)

    Util.AddClick(this.nextEquipBtnRefine, function()      
        UIManager.OpenPanel(UIName.EquipTreasureStrongPopup,nextEquipData,2)
    end)
    Util.AddClick(this.curEquipBtnRefine, function()      
        UIManager.OpenPanel(UIName.EquipTreasureStrongPopup,curEquipData,2)
    end)
end

--添加事件监听（用于子类重写）
function RoleEquipTreasureChangePopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Treasure.TreasureLvUp, this.CurrEquipDataChange)
end

--移除事件监听（用于子类重写）
function RoleEquipTreasureChangePopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Treasure.TreasureLvUp, this.CurrEquipDataChange)
end

function this.CurrEquipDataChange()
    --替换
    if type==3 then
        nextEquipData = EquipTreasureManager.GetSingleEquipTreasreData(nextEquipData.idDyn)
        this.NextCurEquipData()
    else
        curEquipData = EquipTreasureManager.GetSingleEquipTreasreData(curEquipData.idDyn)
        this.ShowCurEquipData()
    end

end


--界面打开时调用（用于子类重写）
function RoleEquipTreasureChangePopup:OnOpen(_openThisPanel,_type,_curHeroData,_curEquipData,_nextEquipData,_position)
    openThisPanel = _openThisPanel
    type = _type--1 穿戴  2  卸下 3 替换 4显示信息
    curHeroData = _curHeroData
    curEquipData = _curEquipData
    nextEquipData = _nextEquipData
    position = _position
end
function RoleEquipTreasureChangePopup:OnShow()
    this.bg1:SetActive(false)
    this.bg2:SetActive(false)
    this.curEquipBtns:SetActive(false)
    this.curEquipBtnStrong:SetActive(false)
    this.curEquipBtnRefine:SetActive(false)
    this.curEquipBtnRemove:SetActive(false)
    this.curEquipBtnAdd:SetActive(false)
    this.curEquipBtnChange:SetActive(false)
    this.nextEquipBtns:SetActive(false)
    this.nextEquipBtnStrong:SetActive(false)
    this.nextEquipBtnRefine:SetActive(false)
    this.nextEquipBtnRemove:SetActive(false)
    this.nextEquipBtnAdd:SetActive(false)
    this.nextEquipBtnChange:SetActive(false)
  if type==1 then
        this.ShowCurEquipData(1)
        this.bg1:SetActive(true)
        this.curEquipBtns:SetActive(true)
        this.curEquipBtnAdd:SetActive(true)
        this.curEquipBtnStrong:SetActive(true)
        this.curEquipBtnRefine:SetActive(true)
      this.curEquipSign.gameObject:SetActive(false)
    elseif type==2 then       
        this.ShowCurEquipData(2)
        this.bg1:SetActive(true)
        this.curEquipBtns:SetActive(true)
        this.curEquipBtnStrong:SetActive(true)
        this.curEquipBtnRefine:SetActive(true)
        this.curEquipBtnRemove:SetActive(true)
      this.curEquipSign.gameObject:SetActive(false)
    elseif type==3 then
        this.ShowCurEquipData(2)
        this.NextCurEquipData()
        this.curEquipSign.gameObject:SetActive(true)
        this.bg1:SetActive(true)
        this.bg2:SetActive(true)
        this.nextEquipBtns:SetActive(true)
        this.nextEquipBtnChange:SetActive(true)
        this.nextEquipBtnStrong:SetActive(true)
        this.nextEquipBtnRefine:SetActive(true)
  elseif type==4 then
      this.ShowCurEquipData(2)
      this.bg1:SetActive(true)
      this.curEquipBtns:SetActive(false)
      this.curEquipBtnStrong:SetActive(true)
      this.curEquipBtnRefine:SetActive(true)
      this.curEquipBtnRemove:SetActive(true)
      this.curEquipSign.gameObject:SetActive(false)
  end
end
function this.ShowCurEquipData()
    local equipConfigData=ConfigManager.GetConfigData(ConfigName.JewelConfig, curEquipData.id)
    local itemConfigData=ConfigManager.GetConfigData(ConfigName.ItemConfig, curEquipData.id)
    local curPower=EquipTreasureManager.CalculateWarForce(curEquipData.idDyn)
    this.powerNum1.text=curPower
    this.desc1.text=itemConfigData.ItemDescribe
    if type==3 and nextEquipData~=nil then
        local nextPower=EquipTreasureManager.CalculateWarForce(nextEquipData.idDyn)
        if(curPower>nextPower) then
            this.powerUPorDown1:SetActive(true)
            this.powerUPorDown1:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[1])
        elseif(curPower<nextPower )then
            this.powerUPorDown1:SetActive(true)
            this.powerUPorDown1:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[2])
        else
            this.powerUPorDown1:SetActive(false)
        end
    else
        this.powerUPorDown1:SetActive(false)
    end

    this.qualityText.text=GetStringByEquipQua(equipConfigData.Level,GetQuaStringByEquipQua(equipConfigData.Level))
    this.curEquipName.text=itemConfigData.Name
    this.curEquipTypeText.text=string.format(GetLanguageStrById(11831),EquipTreasureTypeStr[equipConfigData.Location])
    this.curEquipFrame.sprite = Util.LoadSprite(curEquipData.frame)
    this.curEquipIcon.sprite = Util.LoadSprite(curEquipData.icon)
    this.currEquipProImg.sprite=Util.LoadSprite(curEquipData.proIcon)
    local lv=curEquipData.lv
    if lv==0 then
        this.curEquipLvText.gameObject:SetActive(false)
    else
        this.curEquipLvText.gameObject:SetActive(true)
        this.curEquipLvText.text=lv
    end
     local refine=curEquipData.refineLv
    if refine==0 then
        this.curEquipRefineLvTxt.gameObject:SetActive(false)
    else
        this.curEquipRefineLvTxt.gameObject:SetActive(true)
        this.curEquipRefineLvTxt.text="+"..refine
    end
    local info=EquipTreasureManager.GetCurLvPropertyValue(1,curEquipData.levelPool,curEquipData.lv)
    this.SetPropertyShow(info,curMainpropertyList,this.curMainPropertyGrid)
    local info1=EquipTreasureManager.GetCurLvPropertyValue(2,curEquipData.refinePool,curEquipData.refineLv)
    if LengthOfTable(info1)==0 or info1==nil then
    this.curRefinePropertyTxt.gameObject:SetActive(false)
    this.curPropertyGrid.gameObject:SetActive(false)
    else
        this.curRefinePropertyTxt.gameObject:SetActive(true)
        this.curPropertyGrid.gameObject:SetActive(true)
        this.SetPropertyShow(info1,curPropertyList,this.curPropertyGrid)
    end

end
function this.NextCurEquipData()
    local equipConfigData=ConfigManager.GetConfigData(ConfigName.JewelConfig, nextEquipData.id)
    local itemConfigData=ConfigManager.GetConfigData(ConfigName.ItemConfig, nextEquipData.id)
    local nextPower=EquipTreasureManager.CalculateWarForce(nextEquipData.idDyn)
    local curPower=0
    if curEquipData~=nil then
       curPower=EquipTreasureManager.CalculateWarForce(curEquipData.idDyn)
    end
    this.powerNum2.text=nextPower
    this.powerUPorDown2:SetActive(false)
    if type==3 and curEquipData~=null then
        if nextPower>curPower then
            this.powerUPorDown2:SetActive(true)
            this.powerUPorDown2:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[1])
        elseif nextPower<curPower then
            this.powerUPorDown2:SetActive(true)
            this.powerUPorDown2:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[2])
        else
            this.powerUPorDown2:SetActive(false)
        end
    else
        this.powerUPorDown1:SetActive(false)
    end
    this.qualityText2.text=GetStringByEquipQua(equipConfigData.Level,GetQuaStringByEquipQua(equipConfigData.Level))
    this.nextEquipName.text=nextEquipData.name
    this.desc2.text=itemConfigData.ItemDescribe
    local lv=nextEquipData.lv
    if lv==0 then
        this.nextEquipLvText.gameObject:SetActive(false)
    else
        this.nextEquipLvText.gameObject:SetActive(true)
        this.nextEquipLvText.text=lv
    end
    local refine=nextEquipData.refineLv
    if refine==0 then
        this.nextEquipRefineLvTxt.gameObject:SetActive(false)
    else
        this.nextEquipRefineLvTxt.gameObject:SetActive(true)
        this.nextEquipRefineLvTxt.text="+" ..refine
    end
    this.nextEquipFrame.sprite = Util.LoadSprite(nextEquipData.frame)
    this.nextEquipIcon.sprite = Util.LoadSprite(nextEquipData.icon)
    this.nextEquipProImg.sprite=Util.LoadSprite(nextEquipData.proIcon)
    this.nextEquipTypeText.text=string.format(GetLanguageStrById(11831),EquipTreasureTypeStr[equipConfigData.Location])
    local info=EquipTreasureManager.GetCurLvPropertyValue(1,nextEquipData.levelPool,nextEquipData.lv)
    this.SetPropertyShow(info,nextMainPropertyList,this.nextMainPropertyGrid)
    local info1=EquipTreasureManager.GetCurLvPropertyValue(2,nextEquipData.refinePool,nextEquipData.refineLv)
    if LengthOfTable(info1)==0 or info1==nil then
        this.nextRefinePropertyTxt.gameObject:SetActive(false)
        this.nextPropertyGrid.gameObject:SetActive(false)
    else
        this.nextRefinePropertyTxt.gameObject:SetActive(true)
        this.nextPropertyGrid.gameObject:SetActive(true)
        this.SetPropertyShow(info1,nextPropertyList,this.nextPropertyGrid)
    end
end


function this.SetPropertyShow(_infos,_preList,_grid)
    local dataCount=LengthOfTable(_infos)
    local preCount=#_preList
    for i = 1, dataCount-preCount do
        local  go = newObject(this.propertyPre)
        go.transform:SetParent(_grid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go.gameObject:SetActive(false)
        table.insert(_preList,go)
    end
    local index=1
    for key, value in pairs(_infos) do
        local obj=_preList[index]
        local proper=propertyConfig[key]
        Util.GetGameObject(obj, "Text"):GetComponent("Text").text=proper.Info
        if proper.Style==1 then
            obj.transform:GetComponent("Text").text="              +".. value.currValue
        else
            obj.transform:GetComponent("Text").text="              +"..   value.currValue/100 .."%"
        end
        obj.gameObject:SetActive(true)
        index=index+1
    end
    for i = 1, #_preList do
        if i>=index then
            _preList[i]:SetActive(false)
        end
    end
end

--界面关闭时调用（用于子类重写）
function RoleEquipTreasureChangePopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function RoleEquipTreasureChangePopup:OnDestroy()
     type=0--1 穿装备  2 卸装备 3 替换装备
     curHeroData=nil
     curEquipData=nil
     nextEquipData=nil
     openThisPanel=nil
     equipIdList=nil
     equipDataList=nil
     position=0
     curMainpropertyList={}
     nextMainPropertyList={}
     curPropertyList={}
     nextPropertyList={}
end

return RoleEquipTreasureChangePopup