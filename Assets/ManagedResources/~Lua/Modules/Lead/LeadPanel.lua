require("Base/BasePanel")
LeadPanel = Inherit(BasePanel)
local this = LeadPanel
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local MotherShipPlaneBlueprint = ConfigManager.GetConfig(ConfigName.MotherShipPlaneBlueprint)
local MotherShipConfig = ConfigManager.GetConfig(ConfigName.MotherShipConfig)--神眷者基础数据表

local ImageList={
    [1]="cn2-X1_qiyue_shengji_zh",
    [2]="cn2-X1_qiyue_jinjie_zh",

}

--初始化组件（用于子类重写）
function LeadPanel:InitComponent()
    this.skill = {}
    for i = 1, 4 do
        this.skill[i] = Util.GetGameObject(this.gameObject, "skill").transform:GetChild(i-1)
    end
    this.btnAssembly = Util.GetGameObject(this.gameObject, "btnAssembly")--装配

    this.Level = Util.GetGameObject(this.gameObject, "Level")

    this.btnList = Util.GetGameObject(this.gameObject, "btnList")
    this.btnHelp = Util.GetGameObject(this.gameObject, "btnHelp")

    this.normal = Util.GetGameObject(this.gameObject, "Research/normal")--普通
    this.privilege = Util.GetGameObject(this.gameObject, "Research/privilege")--特权

    this.btnUpLv = Util.GetGameObject(this.gameObject, "btnUpLv")--主角升级
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")

    this.attribute = Util.GetGameObject(this.gameObject, "attribute")--属性
    this.proPre = Util.GetGameObject(this.gameObject, "attribute/prefab")

    this.cost = Util.GetGameObject(this.gameObject, "cost")--属性

    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft})

    --红点
    this.btnAssemblyRedpoint = Util.GetGameObject(this.btnAssembly, "redpoint")--装配红点
    this.normalRedpoint = Util.GetGameObject(this.normal, "redpoint")--普通研发红点
    this.privilegeRedpoint = Util.GetGameObject(this.privilege, "redpoint")--普通研发红点
    this.btnUpLvRedpoint = Util.GetGameObject(this.btnUpLv, "redpoint")--升级红点

    --立绘
    this.manLive = Util.GetGameObject(this.gameObject, "live/spine/Nanzhu")
    this.womanLive = Util.GetGameObject(this.gameObject, "live/spine/Lvzhu")

    --特效
    this.effectLive = Util.GetGameObject(this.gameObject, "live/Cube"):GetComponent("MeshRenderer")
end

local redpoint = {
    RedPointType.Lead_Assembly,
    RedPointType.Lead_Normal,
    RedPointType.Lead_Privilege,
    RedPointType.Lead_UpLv
}

--绑定事件（用于子类重写）
function LeadPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnAssembly, function ()
        local data = AircraftCarrierManager.GetAllSkillData(true)
        if #data < 1 then
            PopupTipPanel.ShowTipByLanguageId(91000141)
            return
        end
        UIManager.OpenPanel(UIName.LeadAssemblyPanel)
    end)
    Util.AddClick(this.btnList, function ()
        NetManager.MotherShipBookSetRequest(function ()
            UIManager.OpenPanel(UIName.LeadGeneAtlaslPanel)
        end)
    end)
    Util.AddClick(this.btnHelp, function ()
        local pos = this.btnHelp.transform.localPosition
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.CVFAQ, pos.x, pos.y)
    end)
    Util.AddClick(this.normal, function ()
        UIManager.OpenPanel(UIName.LeadRAndDPanel, 0)
    end)
    Util.AddClick(this.privilege, function ()
        if AircraftCarrierManager.GetPrivilege() then
            UIManager.OpenPanel(UIName.LeadRAndDPanel, 1)
        else
            UIManager.OpenPanel(UIName.LeadGotoActivationPanel)
        end
    end)
    Util.AddClick(this.btnUpLv, function ()
        AircraftCarrierManager.LeadUpLv(function ()
            this.RefreshBasicAttributes()
        end)
    end)

    BindRedPointObject(redpoint[1], this.btnAssemblyRedpoint)
    BindRedPointObject(redpoint[2], this.normalRedpoint)
    BindRedPointObject(redpoint[3], this.privilegeRedpoint)
    BindRedPointObject(redpoint[4], this.btnUpLvRedpoint)
end

--添加事件监听（用于子类重写）
function LeadPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Lead.RefreshNormalProgress, this.SetNormalResearch)
    Game.GlobalEvent:AddEvent(GameEvent.Lead.RefreshPrivilegeProgress, this.SetPrivilegeResearch)
    Game.GlobalEvent:AddEvent(GameEvent.Lead.RefreshSkill, this.SetLeadSkill)
    Game.GlobalEvent:AddEvent(GameEvent.Lead.ResearchOver, this.ResearchOver)
    Game.GlobalEvent:AddEvent(GameEvent.Lead.RefreshInfo, this.RefreshBasicAttributes)
end

--移除事件监听（用于子类重写）
function LeadPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Lead.RefreshNormalProgress, this.SetNormalResearch)
    Game.GlobalEvent:RemoveEvent(GameEvent.Lead.RefreshPrivilegeProgress, this.SetPrivilegeResearch)
    Game.GlobalEvent:RemoveEvent(GameEvent.Lead.RefreshSkill, this.SetLeadSkill)
    Game.GlobalEvent:RemoveEvent(GameEvent.Lead.ResearchOver, this.ResearchOver)
    Game.GlobalEvent:RemoveEvent(GameEvent.Lead.RefreshInfo, this.RefreshBasicAttributes)
end

--界面打开时调用（用于子类重写）
function LeadPanel:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LeadPanel:OnShow()
    this.manLive:SetActive(PlayerManager.sex == ROLE_SEX.BOY)
    this.womanLive:SetActive(PlayerManager.sex == ROLE_SEX.SLUT)

    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main})
    this.RefreshBasicAttributes()
    this.SetNormalResearch()
    this.SetPrivilegeResearch()

    for i = 1, #redpoint do
        CheckRedPointStatus(redpoint[i])
    end
end

function LeadPanel:OnSortingOrderChange()
    this.effectLive.sortingOrder = self.sortingOrder + 50
end

--界面关闭时调用（用于子类重写）
function LeadPanel:OnClose()
end

local proGrid = {}
--界面销毁时调用（用于子类重写）
function LeadPanel:OnDestroy()
    for i = 1, #redpoint do
        ClearRedPointObject(redpoint[i])
    end
    SubUIManager.Close(this.UpView)
    SubUIManager.Close(this.HeadFrameView)
    proGrid = {}
end

--刷新基础属性
function this.RefreshBasicAttributes()
    this.SetLeadLevel()
    this.SetLeadSkill()
    this.SetProperty()
    this.SetLeadUpLv()
end

--设置主角等级
function this.SetLeadLevel()
    local lvTxt = Util.GetGameObject(this.Level, "lv"):GetComponent("Text")
    local maxLvTxt = Util.GetGameObject(this.Level, "maxLv"):GetComponent("Text")
    local classTxt = Util.GetGameObject(this.Level, "class"):GetComponent("Text")
    local curLv, maxLv, class, type = AircraftCarrierManager.GetLeadLvAndMaxLv()
    lvTxt.text = curLv
    maxLvTxt.text = "/"..maxLv
    classTxt.text = class
    this.btnUpLv:SetActive(curLv < maxLv)
    this.btnUpLv:GetComponent("Image").sprite = Util.LoadSprite(ImageList[type])
end

--设置主角技能
function this.SetLeadSkill()
    for i = 1, #redpoint do
        CheckRedPointStatus(redpoint[i])
    end
    for i = 1, 4 do
        local add = Util.GetGameObject(this.skill[i], "add")
        local lock = Util.GetGameObject(this.skill[i], "lock")
        local mask = Util.GetGameObject(this.skill[i], "mask")
        local icon = Util.GetGameObject(this.skill[i], "mask/icon"):GetComponent("Image")
        local level = Util.GetGameObject(this.skill[i], "level"):GetComponent("Image")

        local data
        for j = 1, #AircraftCarrierManager.LeadData.skill do
            if AircraftCarrierManager.LeadData.skill[j].sort == i then
                data = AircraftCarrierManager.LeadData.skill[j]
            end
        end
        if i > AircraftCarrierManager.GetOpenSlotMaxCnt() then
            lock:SetActive(true)
            add:SetActive(false)
            mask:SetActive(false)
            level.gameObject:SetActive(false)
        else
            lock:SetActive(false)
            if data then
                add:SetActive(false)
                mask:SetActive(true)
                level.gameObject:SetActive(true)
                local config = AircraftCarrierManager.GetSkillLvImgForId(data.cfgId)
                icon.sprite = SetIcon(data.cfgId)
                level.sprite = Util.LoadSprite(config.lvImg)
            else
                add:SetActive(true)
                mask:SetActive(false)
                level.gameObject:SetActive(false)
            end
        end
        Util.AddOnceClick(this.skill[i].gameObject, function()
            if add.gameObject.activeSelf then
                local data = AircraftCarrierManager.GetAllSkillData(true)
                if #data < 1 then
                    PopupTipPanel.ShowTipByLanguageId(91000141)
                    return
                end
                UIManager.OpenPanel(UIName.LeadAssemblyPanel)
                return
            end
            if lock.gameObject.activeSelf then
                local step = ConfigManager.TryGetConfigDataByKey(ConfigName.MotherShipConfig, "UnlockSite", i).Step
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(50372), step))
                -- PopupTipPanel.ShowTipByLanguageId(91000254)
                return
            end
            if not data then
                return
            end
            UIManager.OpenPanel(UIName.LeadGeneTopLevelPanel, data.id, data.cfgId, true, 3)
        end)
    end
end

--结束研究
function this.ResearchOver(type)
    if type == 0 then
        this.SetNormalResearch()
    else
        this.SetPrivilegeResearch()
    end
end

--设置普通研究
function this.SetNormalResearch(progress)
    local slider = Util.GetGameObject(this.normal, "slider"):GetComponent("Image")
    local icon = Util.GetGameObject(this.normal, "icon"):GetComponent("Image")
    local data, max = AircraftCarrierManager.GetResearch(0)
    local time = AircraftCarrierManager.GetCurProgress(0)

    if data.curItemId == 0 then
        slider.fillAmount = 0
        icon.gameObject:SetActive(false)
    else
        slider.fillAmount = (progress and progress or time)/max
        icon.sprite = Util.LoadSprite(GetResourcePath(ItemConfig[MotherShipPlaneBlueprint[data.curItemId].ItemId].ResourceID))
        icon.gameObject:SetActive(true)
    end
end

--设置特权研究
function this.SetPrivilegeResearch(progress)
    local slider = Util.GetGameObject(this.privilege, "slider"):GetComponent("Image")
    local lock = Util.GetGameObject(this.privilege, "lock")
    local icon = Util.GetGameObject(this.privilege, "icon"):GetComponent("Image")

    local isActive = PrivilegeManager.GetPrivilegeOpenStatusById(60002)
    lock:SetActive(not isActive)
    if not isActive then
        slider.fillAmount = 0
        icon.gameObject:SetActive(false)
        return
    end
    local data, max = AircraftCarrierManager.GetResearch(1)
    local time = AircraftCarrierManager.GetCurProgress(1)
    if data.curItemId == 0 then
        slider.fillAmount = 0
        icon.gameObject:SetActive(false)
    else
        slider.fillAmount = (progress and progress or time)/max
        icon.sprite = Util.LoadSprite(GetResourcePath(ItemConfig[MotherShipPlaneBlueprint[data.curItemId].ItemId].ResourceID))
        icon.gameObject:SetActive(true)
    end
end

--设置主角属性
function this.SetProperty()
    local pros = AircraftCarrierManager.GetAllPro()
    local tempRet = {}
    for key, value in pairs(pros) do
        table.insert(tempRet, {id = key, value = value})
    end
    for i = 1, #tempRet do
        if not proGrid[i] then
            proGrid[i] = newObjToParent(this.proPre, this.attribute)
        end
        local proData = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyId", tempRet[i].id)
        Util.GetGameObject(proGrid[i], "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(proData.Icon))
        Util.GetGameObject(proGrid[i], "name"):GetComponent("Text").text = GetLanguageStrById(proData.Info)
        Util.GetGameObject(proGrid[i], "value"):GetComponent("Text").text = GetProDataStr(tempRet[i].id, tempRet[i].value)
        proGrid[i]:SetActive(true)
    end
end

--设置主角升级 10424 10425
function this.SetLeadUpLv()
    local cost = AircraftCarrierManager.GetCost()
    if not cost then
        this.cost:SetActive(false)
        this.btnUpLv:SetActive(false)
        return
    end
    for i = 1, 2 do
        local item = this.cost.transform:GetChild(i-1).gameObject
        local icon = Util.GetGameObject(item, "icon"):GetComponent("Image")
        local Text = Util.GetGameObject(item, "Text"):GetComponent("Text")
        local bagNum = BagManager.GetItemCountById(cost[i][1])
        icon.sprite = Util.LoadSprite(GetResourcePath(ItemConfig[cost[i][1]].ResourceID))
        Text.text = GetNumUnenoughColor(bagNum, cost[i][2], PrintWanNum2(bagNum), PrintWanNum2(cost[i][2]))
        ItemImageTips(cost[i][1], item)
    end
end

return LeadPanel