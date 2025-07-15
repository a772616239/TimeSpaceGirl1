require("Base/BasePanel")
RoleEquipChangePopup = Inherit(BasePanel)
local this=RoleEquipChangePopup
local type--1 穿装备  2 卸装备 3 替换装备
local curHeroData
local curEquipData
-- local nextEquipData
local openThisPanel
local equipIdList
local equipDataList
local position
local curSuitProGo = {}--当前套装属性对象
-- local nextSuitProGo = {}--将要替换套装属性对象
local equipSuit = {}--当前英雄穿戴装备的套装信息    [suitId] = 件数
local equipSuiteConfig = ConfigManager.GetConfig(ConfigName.EquipSuiteConfig)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local _MainProList = {}
-- local _NextProList = {}
--初始化组件（用于子类重写）
function RoleEquipChangePopup:InitComponent()

    this.mask = Util.GetGameObject(self.transform, "mask")
	this.btnBack = Util.GetGameObject(self.transform, "btnBack")

    this.bg1 = Util.GetGameObject(self.transform, "Bg")
    this.desc1 = Util.GetGameObject(self.transform, "Bg/desc/text"):GetComponent("Text")
    this.curEquipName = Util.GetGameObject(self.transform, "Bg/equipInfo/name"):GetComponent("Text")
    --this.curEquipFrameBG=Util.GetGameObject(self.transform, "Bg/equipInfo/Item/frameBG"):GetComponent("Image")
    this.curEquipFrame = Util.GetGameObject(self.transform, "Bg/equipInfo/Item/frame"):GetComponent("Image")
    this.curEquipIcon = Util.GetGameObject(self.transform, "Bg/equipInfo/Item/icon"):GetComponent("Image")
    this.curEquipTypeText = Util.GetGameObject(self.transform, "Bg/equipInfo/equipTypeText"):GetComponent("Text")
    -- this.curEquipLvText=Util.GetGameObject(self.transform, "Bg/equipInfo/proGrid/equipLvText")
    -- this.curEquipLvText:SetActive(false)
    -- this.curEquipOrOkText=Util.GetGameObject(self.transform, "Bg/equipInfo/proGrid/equipOrOkText"):GetComponent("Text")
    -- this.curEquipPosText=Util.GetGameObject(self.transform, "Bg/equipInfo/proGrid/equipPosText"):GetComponent("Text")
    this.mainProGrid = Util.GetGameObject(self.transform, "Bg/mainPro/bg")
    this.mainProItem = Util.GetGameObject(self.transform, "Bg/mainPro/bg/proPre")
    this.mainProItem:SetActive(false)
    this.curotherProscroll = Util.GetGameObject(self.transform, "Bg/scroll")
    this.otherProPre = Util.GetGameObject(self.transform, "proPre")
    this.otherProGrid = Util.GetGameObject(self.transform, "Bg/scroll/grid")
    this.curCastInfo = Util.GetGameObject(self.transform, "Bg/castInfoObject/castInfo"):GetComponent("Text")
    this.castInfoObject = Util.GetGameObject(self.transform, "Bg/castInfoObject")
    this.castInfoObject:SetActive(false)
    this.curEquipBtnRefresh = Util.GetGameObject(self.transform, "Bg/btns/btnRefresh")
    this.curEquipBtnDown = Util.GetGameObject(self.transform, "Bg/btns/btnDown")
    this.curEquipBtnUp = Util.GetGameObject(self.transform, "Bg/btns/btnUp")
    this.curEquipText = Util.GetGameObject(self.transform, "Bg/btns/curEquipText")
    -- this.qualityText=Util.GetGameObject(self.transform, "Bg/equipInfo/qualityText"):GetComponent("Text")
    this.powerNum1 = Util.GetGameObject(self.transform, "Bg/equipInfo/Text/powerNum"):GetComponent("Text")
    -- this.powerUPorDown1=Util.GetGameObject(self.transform, "Bg/equipInfo/powerUPorDown")
    this.bg1Star = Util.GetGameObject(self.transform, "Bg/equipInfo/Item/star")

    this.btns = Util.GetGameObject(self.transform, "Bg/btns") --n1

    -- this.bg2= Util.GetGameObject(self.transform, "GameObject/bg2")
    -- this.desc2= Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/Text"):GetComponent("Text")
    -- this.nextEquipName=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/name/text"):GetComponent("Text")
    -- this.nextEquipFrame=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/frame"):GetComponent("Image")
    -- this.nextEquipIcon=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/icon"):GetComponent("Image")
    -- this.nextEquipTypeText=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/proGrid/equipTypeText"):GetComponent("Text")
    -- this.nextEquipLvText=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/proGrid/equipLvText")
    -- this.nextEquipLvText:SetActive(false)
    -- this.nextEquipOrOkText=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/proGrid/equipOrOkText"):GetComponent("Text")
    -- this.nextEquipPosText=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/proGrid/equipPosText"):GetComponent("Text")
    -- this.nextProGrid = Util.GetGameObject(self.transform, "GameObject/bg2/mainPro/bg")
    -- this.nextProItem = Util.GetGameObject(self.transform, "GameObject/bg2/mainPro/bg/curProName")
    -- this.nextProItem:SetActive(false)
    -- this.nexttherProscroll=Util.GetGameObject(self.transform, "GameObject/bg2/scroll")
    -- this.nextotherProPre=Util.GetGameObject(self.transform, "GameObject/bg2/otherPro")
    -- this.nextotherProGrid=Util.GetGameObject(self.transform, "GameObject/bg2/scroll/grid")
    -- this.nextCastInfo=Util.GetGameObject(self.transform, "GameObject/bg2/castInfoObject/castInfo"):GetComponent("Text")
    -- this.nextInfoObject=Util.GetGameObject(self.transform, "GameObject/bg2/castInfoObject")
    -- this.nextInfoObject:SetActive(false)
    -- this.nextEquipBtnRefresh=Util.GetGameObject(self.transform, "GameObject/bg2/btns/btnRefresh")
    -- this.nextEtnChange=Util.GetGameObject(self.transform, "GameObject/bg2/btns/btnChange")
    -- this.qualityText2=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/qualityText"):GetComponent("Text")
    -- this.GameObject=Util.GetGameObject(self.transform, "GameObject")
    -- this.powerNum2=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/powerNum"):GetComponent("Text")
    -- this.powerUPorDown2=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/powerUPorDown")
    -- this.bg2Star=Util.GetGameObject(self.transform, "GameObject/bg2/equipInfo/star")
end

--绑定事件（用于子类重写）
function RoleEquipChangePopup:BindEvent()
 
	Util.AddClick(this.mask, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.curEquipBtnDown, function()
        equipIdList={}
        equipDataList={}
        table.insert(equipIdList,tostring(curEquipData.id))
        table.insert(equipDataList,curEquipData)
        
        
        

        --> par3 1装备 2宝物
        NetManager.EquipUnLoadOptRequest(curHeroData.dynamicId, equipIdList, 1, function ()
            self:ClosePanel()
            --> 客户端 1 穿单件装备  2 卸单件装备 3 替换单件装备 4 一键穿装备  5一键脱装备
            openThisPanel.UpdateEquipPosHeroData(1, 2, equipDataList)
        end)
    end)
    Util.AddClick(this.curEquipBtnUp, function()
        self:ClosePanel()
        UIManager.OpenPanel(UIName.EquipSelectPopup, curHeroData, position, openThisPanel)

        -- equipIdList={}
        -- equipDataList={}
        -- table.insert(equipIdList,tostring(curEquipData.id))
        -- table.insert(equipDataList,curEquipData)
        -- NetManager.EquipWearRequest(curHeroData.dynamicId,equipIdList,1,function ()
        --     self:ClosePanel()
        --     openThisPanel.UpdateEquipPosHeroData(1,type,equipDataList,0,position)
        -- end)
    end)
    -- Util.AddClick(this.nextEtnChange, function()
    --     equipIdList={}
    --     equipDataList={}
    --     table.insert(equipIdList,tostring(nextEquipData.id))
    --     table.insert(equipDataList,nextEquipData)
    --     NetManager.EquipWearRequest(curHeroData.dynamicId,equipIdList,1,function ()
    --         self:ClosePanel()
    --         openThisPanel.UpdateEquipPosHeroData(1,type,equipDataList,curEquipData,position)
    --     end)
    -- end)
end

--添加事件监听（用于子类重写）
function RoleEquipChangePopup:AddListener()

end

--移除事件监听（用于子类重写）
function RoleEquipChangePopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RoleEquipChangePopup:OnOpen(...)

    local data={...}
    openThisPanel=data[1]
    --> 1 卸下 更换  2 显示
    type = data[2]
    -- type=data[2]--1 穿戴  2  卸下 3 替换
    -- if type==1 or  type==2 then
    --     curHeroData=data[3]
    --     curEquipData=data[4]
    --     position=data[5]
    -- elseif type==3 then
    --     curHeroData=data[3]
    --     curEquipData=data[4]
    --     nextEquipData=data[5]
    --     position=data[6]
    -- end


    curHeroData=data[3]
    curEquipData=data[4]
    position=data[5]
end

function RoleEquipChangePopup:OnShow()
    if curHeroData then
        equipSuit = {}
        for i = 1, #curHeroData.equipIdList do
            --套装加成
            local curEquip = EquipManager.GetSingleEquipData(curHeroData.equipIdList[i])
            if equipSuit[curEquip.equipConfig.SuiteID] then
                equipSuit[curEquip.equipConfig.SuiteID] = equipSuit[curEquip.equipConfig.SuiteID] + 1
            else
                equipSuit[curEquip.equipConfig.SuiteID] = 1
            end
        end
    end

    this.curEquipText:SetActive(false)
    this.curEquipBtnDown:SetActive(true)
    this.curEquipBtnUp:SetActive(true)
    this.ShowCurEquipData(1)
    this.bg1:SetActive(true)
    if type==1 then
        this.btns:SetActive(true)
    elseif type==2 then
        this.btns:SetActive(false)
    end
end
function this.ShowCurEquipData(index)
    local equipConfigData=ConfigManager.GetConfigData(ConfigName.EquipConfig, curEquipData.id)
    local itemConfigData=ConfigManager.GetConfigData(ConfigName.ItemConfig, curEquipData.id)

    this.powerNum1.text = EquipManager.CalculateWarForce(curEquipData.id)

    EquipManager.SetEquipStarShow(this.bg1Star,curEquipData.id)

    this.desc1.text=GetLanguageStrById(itemConfigData.ItemDescribe)
    -- this.powerUPorDown1:SetActive(false) --n1
    -- if(nextEquipData~=nil and index==2) then
    --     if(EquipManager.CalculateWarForce(nextEquipData.id)<EquipManager.CalculateWarForce(curEquipData.id)) then
    --         this.powerUPorDown1:SetActive(true)
    --         this.powerUPorDown1:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[1])
    --     end
    --     if(EquipManager.CalculateWarForce(nextEquipData.id)>EquipManager.CalculateWarForce(curEquipData.id)) then
    --         this.powerUPorDown1:SetActive(true)
    --         this.powerUPorDown1:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[2])
    --     end
    -- end
    -- this.qualityText.text=GetStringByEquipQua(equipConfigData.Quality,GetQuaStringByEquipQua(equipConfigData.Quality)) --n1
    this.curEquipName.text = GetStringByEquipQua(equipConfigData.Quality, GetLanguageStrById(equipConfigData.Name))
    --this.curEquipFrameBG.sprite = Util.LoadSprite(curEquipData.frameBg)
    this.curEquipFrame.sprite = Util.LoadSprite(curEquipData.frame)
    this.curEquipIcon.sprite = Util.LoadSprite(curEquipData.icon)

    -- if curEquipData.skillId>0 then
    --    this.castInfoObject.gameObject:SetActive(true)
    --    --this.curCastInfo.text=HeroManager.passiveSkillConfig[equipConfigData.SkillId].Desc
    --    this.curCastInfo.text=ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, curEquipData.skillId).Desc
    -- else
    --    this.curCastInfo.text=""
    --    this.castInfoObject.gameObject:SetActive(false)
    -- end

    this.curEquipTypeText.text=string.format(GetLanguageStrById(11555),GetEquipPosStrByEquipPosNum(equipConfigData.Position))
    --if equipConfigData.IfClear==0 then
    --    this.curEquipLvText:GetComponent("Text").text="不可重铸"
    --    Util.AddOnceClick(this.curEquipBtnRefresh, function()
    --        PopupTipPanel.ShowTip("当前装备不可重铸！")
    --    end)
    --elseif equipConfigData.IfClear==1 then
    --    Util.AddOnceClick(this.curEquipBtnRefresh, function()
    --        local isOpen = ActTimeCtrlManager.SingleFuncState(5)
    --        if isOpen then
    --            this:ClosePanel()
    
    --            if ActTimeCtrlManager.SingleFuncState(104) then
    --                local workMainPanel = UIManager.OpenPanel(UIName.WorkShopMainPanel,curHeroData)
    --                workMainPanel:OnClickMianTabBtn(4, 1)
    --                workMainPanel.UpdateEquipPosHeroData(1,curEquipData,0,position)
    --            else
    --                PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(104))
    --            end
    --        else
    --            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(5))
    --        end
    --    end)
    --    this.curEquipLvText:GetComponent("Text").text="重铸等级："..curEquipData.resetLv
    --end

    local strPos=""
    if equipConfigData.ProfessionLimit==0 then
        strPos= GetLanguageStrById(11094)
    else
        strPos= GetLanguageStrById(11824)
    end
    -- this.curEquipPosText.text=string.format(strPos,GetJobStrByJobNum(equipConfigData.ProfessionLimit)) --n1
    --主属性
    for _, item in ipairs(_MainProList) do
        item:SetActive(false)
    end

    local mainAttribute=EquipManager.GetMainProList(equipConfigData)
    for index, prop in ipairs(mainAttribute) do
        local proConfigData = ConfigManager.GetConfigData(ConfigName.PropertyConfig, prop.propertyId)
        if proConfigData then
            if not _MainProList[index] then
                _MainProList[index] = newObjToParent(this.mainProItem, this.mainProGrid)
            end
            _MainProList[index]:SetActive(true)
            Util.GetGameObject(_MainProList[index], "curProIcon"):GetComponent("Image").sprite = Util.LoadSprite(proConfigData.Icon)
            Util.GetGameObject(_MainProList[index], "curProName"):GetComponent("Text").text = GetLanguageStrById(proConfigData.Info)
            local vText = Util.GetGameObject(_MainProList[index], "curProVale"):GetComponent("Text")
            if prop.propertyValue > 0 then
                vText.text = "+"..GetPropertyFormatStr(proConfigData.Style, prop.propertyValue)
            else 
                vText.text = GetPropertyFormatStr(proConfigData.Style, prop.propertyValue)
            end
        end
    end
    --套装属性
    if equipConfigData.SuiteID and equipConfigData.SuiteID > 0 then
        this.curotherProscroll:SetActive(true)
        local curSuitConFig = equipSuiteConfig[equipConfigData.SuiteID]
        if curSuitConFig then
            for i = 1, math.max(#curSuitConFig.SuiteValue, #curSuitProGo) do
                local go = curSuitProGo[i]
                if not go then
                    go = newObject(this.otherProPre)
                    go.transform:SetParent(this.otherProGrid.transform)
                    go.transform.localScale = Vector3.one
                    go.transform.localPosition = Vector3.zero
                    curSuitProGo[i] = go
                end
                go.gameObject:SetActive(false)
            end
            for i = 1, #curSuitConFig.SuiteValue do
                local go = curSuitProGo[i]
                go.gameObject:SetActive(true)
                --type=data[2]--1 穿戴  2  卸下 3 替换
                Util.GetGameObject(go.transform, "curProIcon"):GetComponent("Image").sprite = Util.LoadSprite(propertyConfig[curSuitConFig.SuiteValue[i][2]].Icon)
                Util.GetGameObject(go.transform, "curProName"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[curSuitConFig.SuiteValue[i][2]].Info) .." +"..GetPropertyFormatStr(propertyConfig[curSuitConFig.SuiteValue[i][2]].Style,curSuitConFig.SuiteValue[i][3])
                Util.GetGameObject(go.transform, "curProVale"):GetComponent("Text").text = "<color=#FFFFFF>(" .. curSuitConFig.SuiteValue[i][1] .. GetLanguageStrById(11095)
                -- if type == 2 then
                    if equipSuit[curSuitConFig.Id] and equipSuit[curSuitConFig.Id] >= curSuitConFig.SuiteValue[i][1] then--激活的要变颜色
                        Util.GetGameObject(go.transform, "curProName"):GetComponent("Text").text = "<color=#FFCC00>" .. GetLanguageStrById(propertyConfig[curSuitConFig.SuiteValue[i][2]].Info).." +"..GetPropertyFormatStr(propertyConfig[curSuitConFig.SuiteValue[i][2]].Style,curSuitConFig.SuiteValue[i][3]) .. "</color>"
                        Util.GetGameObject(go.transform, "curProVale"):GetComponent("Text").text = "<color=#FFCC00>(" .. curSuitConFig.SuiteValue[i][1] .. GetLanguageStrById(11095)
                    end
                -- end
            end
        end
    else
        this.curotherProscroll:SetActive(false)
    end


    --副属性
    --Util.ClearChild(this.otherProGrid.transform)
    --local equipCurAllPro={}
    --if #curEquipData.secondAttribute>0 then --
    --    this.curotherProscroll:SetActive(true)
    --    for i = 1, #curEquipData.secondAttribute do
    --        table.insert(equipCurAllPro,curEquipData.secondAttribute[i])
    --    end
    --    for i = 1, #equipCurAllPro do
    --        local go = newObject(this.otherProPre)
    --        go.transform:SetParent(this.otherProGrid.transform)
    --        go.transform.localScale = Vector3.one
    --        go.transform.localPosition = Vector3.zero
    --        go:SetActive(true)
    --        
    --        Util.GetGameObject(go.transform, "curProName"):GetComponent("Text").text =equipCurAllPro[i].PropertyConfig.Info
    --        Util.GetGameObject(go.transform, "curProVale"):GetComponent("Text").text = "+"..GetEquipPropertyFormatStr(equipCurAllPro[i].PropertyConfig.Style,equipCurAllPro[i].propertyValue)
    --
    --    end
    --else
    --    this.curotherProscroll:SetActive(false)
    --end

end
-- function this.NextCurEquipData()
--     local equipConfigData=ConfigManager.GetConfigData(ConfigName.EquipConfig, nextEquipData.id)
--     local itemConfigData=ConfigManager.GetConfigData(ConfigName.ItemConfig, nextEquipData.id)

--     this.powerNum2.text=EquipManager.CalculateWarForce(nextEquipData.id)
--     EquipManager.SetEquipStarShow(this.bg2Star,nextEquipData.id)
--     this.powerUPorDown2:SetActive(false)
--     if(EquipManager.CalculateWarForce(nextEquipData.id)>EquipManager.CalculateWarForce(curEquipData.id)) then
--         this.powerUPorDown2:SetActive(true)
--         this.powerUPorDown2:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[1])
--     end
--     if(EquipManager.CalculateWarForce(nextEquipData.id)<EquipManager.CalculateWarForce(curEquipData.id)) then
--         this.powerUPorDown2:SetActive(true)
--         this.powerUPorDown2:GetComponent("Image").sprite=Util.LoadSprite(PowerChangeIconDef[2])
--     end
--     this.qualityText2.text=GetStringByEquipQua(equipConfigData.Quality,GetQuaStringByEquipQua(equipConfigData.Quality))
--     this.nextEquipName.text=GetStringByEquipQua(equipConfigData.Quality,equipConfigData.Name)
--     this.desc2.text=itemConfigData.ItemDescribe
--     --if equipConfigData.IfClear==0 then
--     --    this.nextEquipLvText:GetComponent("Text").text="不可重铸"
--     --    Util.AddOnceClick(this.nextEquipBtnRefresh, function()
--     --        PopupTipPanel.ShowTip("当前装备不可重铸！")
--     --    end)
--     --elseif equipConfigData.IfClear==1 then
--     --    Util.AddOnceClick(this.nextEquipBtnRefresh, function()
--     --        local isOpen = ActTimeCtrlManager.SingleFuncState(5)
--     --        if isOpen then
--     --            this:ClosePanel()
--     
--     --            if ActTimeCtrlManager.SingleFuncState(104) then
--     --                local workMainPanel = UIManager.OpenPanel(UIName.WorkShopMainPanel,curHeroData)
--     --                workMainPanel:OnClickMianTabBtn(4, 1)
--     --                workMainPanel.UpdateEquipPosHeroData(1,nextEquipData,0,position)
--     --            else
--     --                PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(104))
--     --            end
--     --        else
--     --            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(5))
--     --        end
--     --    end)
--     --    this.nextEquipLvText:GetComponent("Text").text="重铸等级："..nextEquipData.resetLv
--     --end
--     this.nextEquipFrame.sprite = Util.LoadSprite(nextEquipData.frame)
--     this.nextEquipIcon.sprite = Util.LoadSprite(nextEquipData.icon)
--     --if nextEquipData.skillId>0 then
--     --    this.nextInfoObject.gameObject:SetActive(true)
--     --    --this.nextCastInfo.text=HeroManager.passiveSkillConfig[equipConfigData.SkillId].Desc
--     --    this.nextCastInfo.text=ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, nextEquipData.skillId).Desc
--     --else
--     --    this.nextCastInfo.text=""
--     --    this.nextInfoObject.gameObject:SetActive(false)
--     --end
--     this.nextEquipTypeText.text=string.format(GetLanguageStrById(11555),GetEquipPosStrByEquipPosNum(equipConfigData.Position))
--     local strPos=""
--     if equipConfigData.ProfessionLimit==0 then
--         strPos= GetLanguageStrById(11094)
--     else
--         strPos= GetLanguageStrById(11824)
--     end
--     this.nextEquipPosText.text=string.format(strPos,GetJobStrByJobNum(equipConfigData.ProfessionLimit))
--     --主属性
--     for _, item in ipairs(_NextProList) do
--         item:SetActive(false)
--     end

--     local mainAttribute=EquipManager.GetMainProList(equipConfigData)
--     for index, prop in ipairs(mainAttribute) do
--         local proConfigData = ConfigManager.GetConfigData(ConfigName.PropertyConfig, prop.propertyId)
--         if proConfigData then
--             if not _NextProList[index] then
--                 _NextProList[index] = newObjToParent(this.nextProItem, this.nextProGrid)
--             end
--             _NextProList[index]:SetActive(true)
--             _NextProList[index]:GetComponent("Text").text = proConfigData.Info
--             local vText = Util.GetGameObject(_NextProList[index], "curProVale"):GetComponent("Text")
--             if prop.propertyValue > 0 then
--                 vText.text = "+"..GetPropertyFormatStr(proConfigData.Style, prop.propertyValue)
--             else 
--                 vText.text = GetPropertyFormatStr(proConfigData.Style, prop.propertyValue)
--             end
--         end
--     end
--     --套装属性
--     if equipConfigData.SuiteID and equipConfigData.SuiteID > 0 then
--         this.nexttherProscroll:SetActive(true)
--         local curSuitConFig = equipSuiteConfig[equipConfigData.SuiteID]
--         if curSuitConFig then
--             for i = 1, math.max(#curSuitConFig.SuiteValue, #nextSuitProGo) do
--                 local go = nextSuitProGo[i]
--                 if not go then
--                     go = newObject(this.nextotherProPre)
--                     go.transform:SetParent(this.nextotherProGrid.transform)
--                     go.transform.localScale = Vector3.one
--                     go.transform.localPosition = Vector3.zero
--                     nextSuitProGo[i] = go
--                 end
--                 go.gameObject:SetActive(false)
--             end
--             for i = 1, #curSuitConFig.SuiteValue do
--                 local go = nextSuitProGo[i]
--                 go.gameObject:SetActive(true)
--                 --type=data[2]--1 穿戴  2  卸下 3 替换
--                 Util.GetGameObject(go.transform, "curProName"):GetComponent("Text").text = "<color=#B9AC97>" .. propertyConfig[curSuitConFig.SuiteValue[i][2]].Info .."+ "..curSuitConFig.SuiteValue[i][3].. "</color>"
--                 Util.GetGameObject(go.transform, "curProVale"):GetComponent("Text").text = "<color=#B9AC97>(+" .. curSuitConFig.SuiteValue[i][1] .. GetLanguageStrById(11095)
--             end
--         end
--     else
--         this.nexttherProscroll:SetActive(false)
--     end
--     --副属性
--     --Util.ClearChild(this.nextotherProGrid.transform)
--     --local equipCurAllPro={}
--     --if #nextEquipData.secondAttribute>0 then --
--     --    this.nexttherProscroll:SetActive(true)
--     --    for i = 1, #nextEquipData.secondAttribute do
--     --        table.insert(equipCurAllPro,nextEquipData.secondAttribute[i])
--     --    end
--     --    for i = 1, #equipCurAllPro do
--     --        local go = newObject(this.nextotherProPre)
--     --        go.transform:SetParent(this.nextotherProGrid.transform)
--     --        go.transform.localScale = Vector3.one
--     --        go.transform.localPosition = Vector3.zero
--     --        go:SetActive(true)
--     --        
--     --        Util.GetGameObject(go.transform, "curProName"):GetComponent("Text").text = equipCurAllPro[i].PropertyConfig.Info
--     --        Util.GetGameObject(go.transform, "curProVale"):GetComponent("Text").text = "+"..GetEquipPropertyFormatStr(equipCurAllPro[i].PropertyConfig.Style,equipCurAllPro[i].propertyValue)
--     --
--     --    end
--     --else
--     --    this.nexttherProscroll:SetActive(false)
--     --end

-- end
--界面关闭时调用（用于子类重写）
function RoleEquipChangePopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function RoleEquipChangePopup:OnDestroy()
    curSuitProGo = {}
    _MainProList = {}
    -- _NextProList = {}
end

return RoleEquipChangePopup