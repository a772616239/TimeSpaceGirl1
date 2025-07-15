require("Base/BasePanel")
EquipTreasureStrongPopup = Inherit(BasePanel)
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local jewelConfig=ConfigManager.GetConfig(ConfigName.JewelConfig)
local this=EquipTreasureStrongPopup
local curEquipData
local properList={}
local costItemPreList={}
local haveTreasures={}
local type
local isMatEnough=true
local matId=0
local isCoinEnough=true
local isMax=false
local isEnough = false
--初始化组件（用于子类重写）
function EquipTreasureStrongPopup:InitComponent()
    this.btnBack= Util.GetGameObject(self.transform, "bg/btnBack")
    this.titleTxt=Util.GetGameObject(self.transform, "bg/name"):GetComponent("Text")
    this.equipFrame=Util.GetGameObject(self.transform, "bg/armorInfo/frame"):GetComponent("Image")
    this.equipIcon=Util.GetGameObject(self.transform, "bg/armorInfo/icon"):GetComponent("Image")
    this.equipName=Util.GetGameObject(self.transform, "bg/armorInfo/nameTxt"):GetComponent("Text")
    this.equipQuaTxt=Util.GetGameObject(self.transform, "bg/armorInfo/equipQuaText"):GetComponent("Text")
    this.btn_strong=Util.GetGameObject(self.transform, "bg/btnGrid/btnStrong")
    this.btn_refine=Util.GetGameObject(self.transform, "bg/btnGrid/btnRefine")
    this.btn_strongPage=Util.GetGameObject(self.transform, "bg/btnList/btnStrong")
    this.btn_refinePage=Util.GetGameObject(self.transform, "bg/btnList/btnRefine")
    this.coinImg=Util.GetGameObject(self.transform, "bg/coinImg"):GetComponent("Image")
    this.coinTxt=Util.GetGameObject(self.transform, "bg/coinNumTxt"):GetComponent("Text")
    this.coinBg=Util.GetGameObject(self.transform, "bg/coinBg")
    this.costItemPre=Util.GetGameObject(self.transform, "bg/costItemPre")
    this.costItemPre.gameObject:SetActive(false)
    this.properItemPre=Util.GetGameObject(self.transform, "bg/propertyPre")
    this.costItemGrid=Util.GetGameObject(self.transform, "bg/costGrid")
    this.propertyGrid=Util.GetGameObject(self.transform, "bg/scroll/grid")
    this.equipLvTxt=Util.GetGameObject(self.transform, "bg/armorInfo/lvTxt"):GetComponent("Text")
    this.equipRefineLvTxt=Util.GetGameObject(self.transform, "bg/armorInfo/refineLv"):GetComponent("Text")
    this.selectBtn=Util.GetGameObject(self.transform,"bg/btnList/selectBtn")
    this.lvTxt=Util.GetGameObject(self.transform,"bg/propertyPre/leftTxt"):GetComponent("Text")
    this.lvValueTxt=Util.GetGameObject(self.transform,"bg/propertyPre/rightTxt"):GetComponent("Text")
    this.proImg=Util.GetGameObject(self.transform,"bg/armorInfo/proImg"):GetComponent("Image")
    this.hintTxt=Util.GetGameObject(self.transform,"bg/hintTxt"):GetComponent("Text")



end

--绑定事件（用于子类重写）
function EquipTreasureStrongPopup:BindEvent()
    --关闭按钮
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    --强化页签
    Util.AddClick(this.btn_strongPage, function()
        this.SetWindShow(1)
    end)
    --精炼页签
    Util.AddClick(this.btn_refinePage, function()
        this.SetWindShow(2)
    end)
    --强化按钮
    Util.AddClick(this.btn_strong, function()
        --如果强化界面 强化到最高等级谈提示  精炼界面 就切界面
        if  type==1 then
            if isMax then
                PopupTipPanel.ShowTipByLanguageId(11811)
                return
            end
        else
            this.SetWindShow(1)
            return
        end
        --材料是否足够
        if isMatEnough==false then
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,matId)
            return
        end
        --金币是否足够
        if isCoinEnough==false then
            PopupTipPanel.ShowTipByLanguageId(11812)
            return
        end
        NetManager.EquipTreasureBuildRequest(curEquipData.idDyn,1,nil,function (msg)
            EquipTreasureManager.ChangeTreasureLv(curEquipData.idDyn,type)
            this.SetWindShow(type)
            if isMax then
                PopupTipPanel.ShowTipByLanguageId(11813)
            else
                --PopupTipPanel.ShowTip("强化成功")
            end
            local oldWarPowerValue = EquipTreasureManager.CalculateWarForceBySid(curEquipData.id,curEquipData.lv - 1,curEquipData.refineLv)
            local newWarPowerValue = EquipTreasureManager.CalculateWarForceBySid(curEquipData.id,curEquipData.lv,curEquipData.refineLv)
            if oldWarPowerValue ~= newWarPowerValue then
                UIManager.OpenPanel(UIName.WarPowerChangeNotifyPanelV2,{oldValue = oldWarPowerValue,newValue = newWarPowerValue})
            end
            Game.GlobalEvent:DispatchEvent(GameEvent.Treasure.TreasureLvUp)
        end)
    end)

    --精炼按钮
    Util.AddClick(this.btn_refine, function()
        --如果精炼界面 精炼到最高等级谈提示 否 强化界面 就切界面
        if type==2 then
            if isMax then
                PopupTipPanel.ShowTipByLanguageId(11814)
                return
            end
        else
            this.SetWindShow(2)
            return
        end
        if isMatEnough==false then
            UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,matId)
            return
        end
        if isCoinEnough==false then
            PopupTipPanel.ShowTipByLanguageId(11812)
            return
        end
        local maters={}
        if haveTreasures then
            for i, v in pairs(haveTreasures) do
                local index=1
                if v.equip then
                    for i, value in pairs(v.equip) do
                        if #maters < v.needNum then
                            maters[index]=value.idDyn
                            index=index+1
                        end
                    end
                end
            end
        end
        NetManager.EquipTreasureBuildRequest(curEquipData.idDyn,2,maters,function (msg)
            if maters then
                for i = 1, #maters do
                    EquipTreasureManager.RemoveTreasureByIdDyn(maters[i])
                end
            end
            EquipTreasureManager.ChangeTreasureLv(curEquipData.idDyn,type)
            this.SetWindShow(type)
            if isMax then
                PopupTipPanel.ShowTipByLanguageId(11815)
            else
                --PopupTipPanel.ShowTip("精炼成功")
            end
            local oldWarPowerValue = EquipTreasureManager.CalculateWarForceBySid(curEquipData.id,curEquipData.lv ,curEquipData.refineLv - 1)
            local newWarPowerValue = EquipTreasureManager.CalculateWarForceBySid(curEquipData.id,curEquipData.lv,curEquipData.refineLv)
            -- if oldWarPowerValue ~= newWarPowerValue then
            --     UIManager.OpenPanel(UIName.WarPowerChangeNotifyPanelV2,{oldValue = oldWarPowerValue,newValue = newWarPowerValue})
            -- end
            RefreshPower(oldWarPowerValue, newWarPowerValue)
            Game.GlobalEvent:DispatchEvent(GameEvent.Treasure.TreasureLvUp)
        end)
        return
    end)
end

--界面打开时调用（用于子类重写）
function EquipTreasureStrongPopup:OnOpen(...)
    local datas={...}
    curEquipData=datas[1]
    type=datas[2]
    
end

function EquipTreasureStrongPopup:OnShow()
    this.SetWindShow(type)
end

--设置界面显示 1.强化 2.精炼
function this.SetWindShow(_index)
    haveTreasures = {} 
    type=_index
    curEquipData = EquipTreasureManager.GetSingleEquipTreasreData(curEquipData.idDyn)
    isMatEnough=true
    isCoinEnough=true
    this.equipFrame.sprite=Util.LoadSprite(curEquipData.frame)
    this.equipIcon.sprite=Util.LoadSprite(curEquipData.icon)
    this.equipName.text=curEquipData.name
    this.proImg.sprite=Util.LoadSprite(curEquipData.proIcon)
    local items, coin
    if _index==1 then
        this.titleTxt.text=GetLanguageStrById(11816)
        this.btn_refine:SetActive(false)
        this.btn_strong:SetActive(true)
        this.SetBtnSelect(this.btn_strongPage)
        --显示属性
        this.lvTxt.text=string.format( GetLanguageStrById(11817),curEquipData.lv,curEquipData.maxLv)
         isMax =curEquipData.lv==curEquipData.maxLv
        if isMax then
            this.lvValueTxt.text = isMax and GetLanguageStrById(11089) or string.format( "%d/%d",curEquipData.lv,curEquipData.maxLv)
                --Util.GetGameObject(this.btn_strong,"Text"):GetComponent("Text").text="已达上限"
            --this.btn_refine.gameObject:SetActive(true)
            this.btn_strong.gameObject:SetActive(false)
        else
            Util.GetGameObject(this.btn_strong,"Text"):GetComponent("Text").text=GetLanguageStrById(11818)
            this.lvValueTxt.text = isMax and GetLanguageStrById(11089) or string.format( "%d/%d",curEquipData.lv+1,curEquipData.maxLv)
            this.btn_refine.gameObject:SetActive(false)
        end
        local info1=EquipTreasureManager.GetCurrLvAndNextLvPropertyValue(1,curEquipData.levelPool,curEquipData.lv)
        this.SetPropertyShow(info1)
        --显示消耗
        items,coin=this.GetCostItems(curEquipData.strongConfig)
        this.hintTxt.text=GetLanguageStrById(11819)

    else
        this.titleTxt.text=GetLanguageStrById(11820)
        this.btn_strong:SetActive(false)
        this.btn_refine:SetActive(true)
        this.SetBtnSelect(this.btn_refinePage)
        --显示属性
        this.lvTxt.text=string.format( GetLanguageStrById(11821),curEquipData.refineLv,curEquipData.maxRefineLv)
        isMax=curEquipData.refineLv==curEquipData.maxRefineLv
        if isMax then
            this.lvValueTxt.text = isMax and GetLanguageStrById(11089) or string.format( "%d/%s",curEquipData.refineLv,curEquipData.maxRefineLv)
            --Util.GetGameObject(this.btn_refine,"Text"):GetComponent("Text").text="已达上限"
            --this.btn_strong.gameObject:SetActive(true)
            this.btn_refine.gameObject:SetActive(false)
        else
            Util.GetGameObject(this.btn_refine,"Text"):GetComponent("Text").text=GetLanguageStrById(11822)
            this.btn_strong.gameObject:SetActive(false)
            this.lvValueTxt.text = isMax and GetLanguageStrById(11089) or string.format( "%d/%s",curEquipData.refineLv+1,curEquipData.maxRefineLv)
        end
        local info2=EquipTreasureManager.GetCurrLvAndNextLvPropertyValue(2,curEquipData.refinePool,curEquipData.refineLv)
        this.SetPropertyShow(info2)
        items,coin=this.GetCostItems(curEquipData.refineConfig)
        this.hintTxt.text=GetLanguageStrById(11823)
    end
    this.hintTxt.gameObject:SetActive(isMax)
    --显示消耗金币
    if coin and isMax==false then
        this.coinImg.gameObject:SetActive(true)
        this.coinTxt.gameObject:SetActive(true)
        this.coinBg.gameObject:SetActive(true)
        this.coinImg.sprite=Util.LoadSprite(coin.icon)
        if coin.isEnough then
            this.coinTxt.text=string.format("<color=#816D4E>%s</color>",coin.needNum)
        else
            isCoinEnough=false
            this.coinTxt.text=string.format("<color=#FF0000FF>%s</color>",coin.needNum)
        end
    else
        this.coinImg.gameObject:SetActive(false)
        this.coinTxt.gameObject:SetActive(false)
        this.coinBg.gameObject:SetActive(false)
    end
    --显示消耗物品
    if items and isMax==false then
        this.costItemGrid.gameObject:SetActive(true)
        local dataCount=table.getn(items)
        local preCount=table.getn(costItemPreList)
        for i = 1, dataCount-preCount do
            local pre=newObjToParent(this.costItemPre,this.costItemGrid)
            pre.transform.localScale = Vector3.one
            pre.transform.localPosition = Vector3.zero
            table.insert(costItemPreList,pre)
        end
        local index=1
        for i, v in pairs(items) do
            local obj=costItemPreList[index]
            obj.gameObject:SetActive(true)
            if v then
                obj.gameObject:SetActive(true)
            else
                obj.gameObject:SetActive(false)
            end
            Util.GetGameObject(obj,"iconBg"):GetComponent("Image").sprite=Util.LoadSprite(v.frame)
            Util.GetGameObject(obj,"icon"):GetComponent("Image").sprite=Util.LoadSprite(v.icon)
            if jewelConfig[v.id] then
                Util.GetGameObject(obj,"proImg"):SetActive(true)
                Util.GetGameObject(obj,"proImg"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(itemConfig[v.id].PropertyName))
            else
                Util.GetGameObject(obj,"proImg"):SetActive(false)
            end
            if v.isEnough then
                Util.GetGameObject(obj,"numTxt"):GetComponent("Text").text=string.format("<color=#816D4E>%s/%s</color>",v.haveNum,v.needNum)
            else
                --如果材料不足默认弹第一个不足的材料tip
                if isMatEnough then
                    isMatEnough=false
                    matId=v.id
                end
                Util.GetGameObject(obj,"numTxt"):GetComponent("Text").text=string.format("<color=#FF0000FF>%s/%s</color>",v.haveNum,v.needNum)
            end
            if v.id==curEquipData.id then
                if v.isEnough then
                    Util.GetGameObject(obj,"add").gameObject:SetActive(false)
                else
                    Util.GetGameObject(obj,"add").gameObject:SetActive(true)
                end
            else
                Util.GetGameObject(obj,"add").gameObject:SetActive(false)
            end
            Util.AddClick(Util.GetGameObject(obj,"icon"),function ()
                if jewelConfig[v.id] then
                    UIManager.OpenPanel(UIName.RewardTalismanSingleShowPopup,2,"",v.id,0,0)
                else
                    UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,v.id)
                end
            end)
            index=index+1
        end
        for i = 1,#costItemPreList do
            if i>=index then
                costItemPreList[i]:SetActive(false)
            end
        end
    else
    this.costItemGrid.gameObject:SetActive(false)
    end
end


--获取消耗物品数据
function this.GetCostItems(_config)
    if _config==nil then
        return
    end
    local config=_config
    local exps=config.UpExpend
    if exps==nil then
        return
    end
    local costCoin
    local items={}
    for i = 1,#exps do
        local id=exps[i][1]
        if itemConfig[id]then
            local item={}
            item.id=id
            item.icon=GetResourcePath(itemConfig[id].ResourceID)
            item.frame=GetQuantityImageByquality(itemConfig[id].Quantity)
            item.haveNum=BagManager.GetItemCountById(id)
            item.needNum=exps[i][2]
            item.isEnough=item.haveNum>=item.needNum
            --消耗金币
            if id==14 then
                costCoin=item
            else
                items[i]=item
            end
        end
    end
    if config.JewelExpend then
        for i = 1, #config.JewelExpend do
            local id=config.JewelExpend[i]
            local item={}
            --同类型宝物
            local type=id[1]
            if type==1 then
                item.id=curEquipData.id
                item.icon=curEquipData.icon
                item.frame=curEquipData.frame
                local equips,num=EquipTreasureManager.GetEnoughRefineTreasure(curEquipData.id,curEquipData.idDyn)
                if equips then
                    item.haveNum= num
                else
                    item.haveNum=0
                end
                item.needNum=id[2]
                local equipValue={}
                equipValue.equip=equips
                equipValue.needNum=id[2]
                --table.insert(haveTreasures,equipValue)
                haveTreasures[type]=equipValue
                if item.haveNum>=item.needNum then
                    item.isEnough=true
                else
                    item.isEnough=false
                    isEnough=false
                end
                items[#items+1]=item
            else
                item.id=type
                local config=itemConfig[type]
                if config then
                    item.icon=GetResourcePath(config.ResourceID)
                    item.frame=GetQuantityImageByquality(config.Quantity)
                    local equips,num=EquipTreasureManager.GetEnoughRefineTreasure(type,"cxvcbvbvnbn")
                    if equips then
                        item.haveNum= num
                    else
                        item.haveNum=0
                    end
                    local equipValue={}
                    equipValue.equip=equips
                    equipValue.needNum=id[2]
                    --table.insert(haveTreasures,equipValue)
                    haveTreasures[type]=equipValue
                    item.needNum=id[2]
                    if item.haveNum>=item.needNum then
                        item.isEnough=true
                    else
                        item.isEnough=false
                        isEnough=false
                    end
                    items[#items+1]=item
                end

            end
        end
    end
    return items,costCoin
end



--设置属性的显示
function this.SetPropertyShow(_infos)
    local dataCount=LengthOfTable(_infos)
    local preCount=#properList
    for i = 1, dataCount-preCount do
        local  go = newObject(this.properItemPre)
        go.transform:SetParent(this.propertyGrid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go.gameObject:SetActive(false)
        --properList[i] = go
        table.insert(properList,go)
    end
    local index=1
    for key, value in pairs(_infos) do
        local obj=properList[index]
        local proper=ConfigManager.GetConfigData(ConfigName.PropertyConfig,key)
        if proper.Style==1 then
            Util.GetGameObject(obj,"leftTxt"):GetComponent("Text").text=string.format("%s+%s",proper.Info,value.currValue)
            Util.GetGameObject(obj,"rightTxt"):GetComponent("Text").text= isMax and GetLanguageStrById(11089) or value.nextValue
        else
            Util.GetGameObject(obj,"leftTxt"):GetComponent("Text").text=proper.Info.."+"..value.currValue/100 .."%"
            Util.GetGameObject(obj,"rightTxt"):GetComponent("Text").text=isMax and GetLanguageStrById(11089) or value.nextValue/100 .."%"
        end
        obj.gameObject:SetActive(true)
        index=index+1
    end
    for i = 1, #properList do
        if i>=index then
            properList[i]:SetActive(false)
        end
    end
end

--设置物体选中
function this.SetBtnSelect(_parObj)
    Util.GetGameObject(this.selectBtn, "Text"):GetComponent("Text").text=Util.GetGameObject(_parObj, "Text"):GetComponent("Text").text
    this.selectBtn.transform:SetParent(_parObj.transform)
    this.selectBtn.transform.localScale = Vector3.one
    this.selectBtn.transform.localPosition=Vector3.zero
end

--界面关闭时调用（用于子类重写）
function EquipTreasureStrongPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function EquipTreasureStrongPopup:OnDestroy()
     curEquipData=nil
     properList={}
     costItemPreList={}
     isEnough=true
     haveTreasures={}
     type=0
     isMatEnough=false
     matId=0
     isCoinEnough=false
     isMax=false
end

return EquipTreasureStrongPopup