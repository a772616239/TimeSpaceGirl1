require("Base/BasePanel")
RewardEquipSingleShowPopup = Inherit(BasePanel)
local this = RewardEquipSingleShowPopup
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local equipData
local func
local isRewardItemPop
local curSuitProGo = {}--当前套装属性对象
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local _MainProList = {}
local isShowfenjie = true
--初始化组件（用于子类重写）
function RewardEquipSingleShowPopup:InitComponent()
    this.eqiopName = Util.GetGameObject(self.transform, "bg/Content/armorInfo/name"):GetComponent("Text")
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    --装备详情
    this.icon = Util.GetGameObject(self.transform, "bg/Content/armorInfo/Item/icon"):GetComponent("Image")
    this.frame = Util.GetGameObject(self.transform, "bg/Content/armorInfo/Item/frame"):GetComponent("Image")
    this.equipType = Util.GetGameObject(self.transform, "bg/Content/armorInfo/equipType"):GetComponent("Text")

    this.equipInfoText = Util.GetGameObject(self.transform, "bg/Content/equipInfo/equipInfoText"):GetComponent("Text")
    this.powerNum = Util.GetGameObject(self.transform, "bg/Content/armorInfo/powerNumText/powerNum"):GetComponent("Text")
    this.star = Util.GetGameObject(self.transform, "bg/Content/armorInfo/Item/star")
    --装备属性
    this.equipOtherProPre=Util.GetGameObject(self.transform, "bg/Content/proPre")
    this.equipProGrid=Util.GetGameObject(self.transform, "bg/Content/proRect/proGrid")
    this.mainPro=Util.GetGameObject(self.transform, "bg/Content/mainPro")
    this.mainProGrid = Util.GetGameObject(self.transform, "bg/Content/mainPro/bg")
    this.mainProItem = Util.GetGameObject(self.transform, "bg/Content/mainPro/bg/proPre")
    this.mainProItem:SetActive(false)

    -- this.mainProName=Util.GetGameObject(self.transform, "Content/mainPro/bg/curProName"):GetComponent("Text")
    -- this.mainProVale=Util.GetGameObject(self.transform, "Content/mainPro/bg/curProName/curProVale"):GetComponent("Text")
    --装备获取途径
    --this.getTuPre=Util.GetGameObject(self.transform, "Content/bg/getTuPre")
    -- this.getTuGrid=Util.GetGameObject(self.transform, "Content/bg/scroll/grid")
    this.getTuGrid=Util.GetGameObject(self.transform, "bg/Content/scroll")
    --装备被动技能
    this.skillObject=Util.GetGameObject(self.transform, "bg/Content/skillObject")
    this.skillInfo=Util.GetGameObject(self.transform, "bg/Content/skillObject/skillInfo"):GetComponent("Text")
    this.skillObject:SetActive(false)
    --分解按钮
    -- this.btnSure = Util.GetGameObject(self.transform, "Content/bg/btnGrid/btnSure")
    -- this.btnJump = Util.GetGameObject(self.transform, "Content/bg/btnGrid/btnJump")
    this.btnSure = Util.GetGameObject(self.transform, "bg/Content/btnGrid/btnSure")
    this.btnJump = Util.GetGameObject(self.transform, "bg/Content/btnGrid/btnJump")
    this.btnLock = Util.GetGameObject(self.transform, "bg/Content/btnLock")
    this.upLockImage = Util.GetGameObject(self.transform, "bg/Content/btnLock/upLock")
    this.downLockImage = Util.GetGameObject(self.transform, "bg/Content/btnLock/downLock")

    this.BackMask = Util.GetGameObject(self.transform, "BackMask")
end

--绑定事件（用于子类重写）
function RewardEquipSingleShowPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
		self:ClosePanel()
    end)
    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.btnJump, function()
        if equipData.itemConfig then
            JumpManager.GoJump(equipData.itemConfig.UseJump)
        end
    end)
    Util.AddClick(this.btnSure, function()
        --数量大于1 ，弹选择框
        if BagManager.GetItemCountById(equipData.id) > 1 then
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.EquipSingleSell, equipData, func)
            this:ClosePanel()
        elseif BagManager.GetItemCountById(equipData.id) == 1 then
            --只有一个，分解品质大于4， 弹框
            if equipData.itemConfig.Quantity >= 4 then
                UIManager.OpenPanel(UIName.BagResolveAnCompoundPanel, 2, equipData.itemConfig.ItemBaseType, equipData, function () 
                    if func then
                        func()
                    end
                end)
            else
                local curResolveAllItemList={}
                local equip = {}
                equip.itemId = equipData.id
                equip.itemNum = 1
                table.insert(curResolveAllItemList,equip)
                local type = 1
                NetManager.UseAndPriceItemRequest(type,curResolveAllItemList,function (drop)
                    this.SendBackResolveReCallBack(drop)
                end)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(12265)
        end
    end)
    Util.AddClick(this.btnLock, function()
       self:OnLockClickEvent()
    end)
end

--添加事件监听（用于子类重写）
function RewardEquipSingleShowPopup:AddListener()
end

--移除事件监听（用于子类重写）
function RewardEquipSingleShowPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function RewardEquipSingleShowPopup:OnOpen(_equipData, _func,_isRewardItemPop,_isShowfenjie)
    if not _equipData then
        return
    end
    equipData = _equipData
    func = _func
    isRewardItemPop = _isRewardItemPop and _isRewardItemPop or false
    isShowfenjie = not not (_isShowfenjie or false)
end
function RewardEquipSingleShowPopup:OnShow()
    --装备基础信息
    local equipConfigData = ConfigManager.GetConfigData(ConfigName.EquipConfig, tonumber(equipData.id))
    local itemConfigData = ConfigManager.GetConfigData(ConfigName.ItemConfig, tonumber(equipData.id))
    this.btnSure:SetActive(isShowfenjie)
    --local curEquipData = {}
    -- if func and itemConfigData.IfResolve==1 then
    --     curEquipData = EquipManager.GetSingleEquipData(equipData.id)
    --     -- if curEquipData and curEquipData.upHeroDid == "0" then
    --     --     this.btnSure:SetActive(true)
    --     -- end
    -- end
    -- if curEquipData then
    --     --this.upLockImage:SetActive(curEquipData.isLocked == 1)
    --     --this.downLockImage:SetActive(curEquipData.isLocked == 0)
    -- end
    -- this.equipQuaText.text = GetStringByEquipQua(equipConfigData.Quality,GetQuaStringByEquipQua(equipConfigData.Quality)) --n1

    this.eqiopName.text = GetStringByEquipQua(equipConfigData.Quality,GetLanguageStrById(equipConfigData.Name))

    --if equipConfigData.IfClear == 0 then
    --    this.equipRebuildLv:GetComponent("Text").text = "不可重铸"
    --elseif equipConfigData.IfClear == 1 then
    --    this.equipRebuildLv:GetComponent("Text").text = "重铸等级："..equipData.rebuildLevel
    --end
    this.frame.sprite = Util.LoadSprite(GetQuantityImageByquality(equipConfigData.Quality))
    this.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    this.equipInfoText.text = GetLanguageStrById(itemConfigData.ItemDescribe)
    
    this.powerNum.text = EquipManager.CalculateWarForce(equipData.id)
    EquipManager.SetEquipStarShow(this.star,equipConfigData.Id)

    this.btnJump:SetActive(itemConfigData.UseJump and itemConfigData.UseJump > 0 and BagManager.isBagPanel)

    local passiveCfg = {}
    if equipData.skillId and equipData.skillId > 0 then
        passiveCfg = ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, equipData.skillId)
    end
    if passiveCfg and equipData.skillId and equipData.skillId > 0 then
       this.skillObject:SetActive(true)
       this.skillInfo.text = GetLanguageStrById(passiveCfg.Desc)
    else
       this.skillObject:SetActive(false)
    end
    this.equipType.text = GetLanguageStrById(11093)..GetEquipPosStrByEquipPosNum(equipConfigData.Position)
    -- this.equipPos.text=string.format("职业限定：%s",GetJobStrByJobNum(equipConfigData.ProfessionLimit)) --装备关闭职业限定
    --装备属性
    for _, item in ipairs(_MainProList) do
        item:SetActive(false)
    end
    if equipConfigData.Property then
        this.mainPro:SetActive(true)
        for index, prop in ipairs(equipConfigData.Property) do
            local proConfigData = ConfigManager.GetConfigData(ConfigName.PropertyConfig, prop[1])
            if proConfigData then
                if not _MainProList[index] then
                    _MainProList[index] = newObjToParent(this.mainProItem, this.mainProGrid)
                end
                _MainProList[index]:SetActive(true)
                Util.GetGameObject(_MainProList[index], "curProName"):GetComponent("Text").text = GetLanguageStrById(proConfigData.Info)
                local vText = Util.GetGameObject(_MainProList[index], "curProVale"):GetComponent("Text")
                Util.GetGameObject(_MainProList[index], "curProIcon"):GetComponent("Image").sprite = Util.LoadSprite(proConfigData.Icon)
                -- if prop[2] > 0 then
                --     vText.text = "+"..GetPropertyFormatStr(proConfigData.Style, prop[2])
                -- else 
                    vText.text = "+"..GetPropertyFormatStr(proConfigData.Style, prop[2])
                -- end
            end
        end
    else
        this.mainPro:SetActive(false)
    end

    --套装属性
    if equipConfigData.SuiteID and equipConfigData.SuiteID > 0 then
        Util.GetGameObject(self.transform, "Content/proRect"):SetActive(true)
        local curSuitConFig = ConfigManager.GetConfigData(ConfigName.EquipSuiteConfig,equipConfigData.SuiteID)
        if curSuitConFig then
            for i = 1, math.max(#curSuitConFig.SuiteValue, #curSuitProGo) do
                local go = curSuitProGo[i]
                if not go then
                    go = newObject(this.equipOtherProPre)
                    go.transform:SetParent(this.equipProGrid.transform)
                    go.transform.localScale = Vector3.one
                    go.transform.localPosition = Vector3.zero
                    curSuitProGo[i] = go
                end
                go.gameObject:SetActive(false)
            end
            for i = 1, #curSuitConFig.SuiteValue do
                local go = curSuitProGo[i]
                go.gameObject:SetActive(true)
                Util.GetGameObject(go.transform, "proName"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[curSuitConFig.SuiteValue[i][2]].Info) .." +"..GetPropertyFormatStr(propertyConfig[curSuitConFig.SuiteValue[i][2]].Style,curSuitConFig.SuiteValue[i][3])
                Util.GetGameObject(go.transform, "proVale"):GetComponent("Text").text = "<color=#FFFFFF>(" .. curSuitConFig.SuiteValue[i][1] .. GetLanguageStrById(11095)
                Util.GetGameObject(go.transform, "curProIcon"):GetComponent("Image").sprite = Util.LoadSprite(propertyConfig[curSuitConFig.SuiteValue[i][2]].Icon)
            end
        end
    else
        Util.GetGameObject(self.transform, "Content/proRect"):SetActive(false)
    end
    --装备获得途径
    Util.ClearChild(this.getTuGrid.transform)
    local curitemData = itemConfig[tonumber(equipData.id)]
    if curitemData and curitemData.Jump then
        if curitemData.Jump and #curitemData.Jump > 0 then
            for i = 1, #curitemData.Jump do
                if isRewardItemPop then
                    SubUIManager.Open(SubUIConfig.JumpView, this.getTuGrid.transform, curitemData.Jump[i],false)
                else
                    SubUIManager.Open(SubUIConfig.JumpView, this.getTuGrid.transform, curitemData.Jump[i],true)
                end
            end
        end
    end
end

--道具 和 装备分解 发送请求后 回调
function this.SendBackResolveReCallBack(drop)
    local isShowReward=false
    if drop.itemlist~=nil and #drop.itemlist > 0 then
        for i = 1, #drop.itemlist do
            if drop.itemlist[i].itemNum > 0 then
                isShowReward=true
                break
            end
        end
    end
    if isShowReward then
        UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function ()
            BagManager.OnShowTipDropNumZero(drop)
        end)
    else
        BagManager.OnShowTipDropNumZero(drop)
    end
    if func then
        func()
    end
    this:ClosePanel()
end

function RewardEquipSingleShowPopup:OnLockClickEvent()
    if equipData and equipData.isLocked == 0 then--未上锁
        NetManager.EquipLockRequest({equipData.id}, 1,function ()
           this.upLockImage:SetActive(true)
           this.downLockImage:SetActive(false)
        end)
    elseif equipData and equipData.isLocked == 1 then--已上锁
        NetManager.EquipLockRequest({equipData.id}, 2,function ()
            this.upLockImage:SetActive(false)
            this.downLockImage:SetActive(true)
        end)
    end
end

--界面关闭时调用（用于子类重写）
function RewardEquipSingleShowPopup:OnClose()
    --if func then
    --    func()
    --end
end

--界面销毁时调用（用于子类重写）
function RewardEquipSingleShowPopup:OnDestroy()
    curSuitProGo = {}
    _MainProList = {}
end

return RewardEquipSingleShowPopup