require("Base/BasePanel")
local TabBox = require("Modules/Common/TabBox") -- 引用
AdjutantPanel = Inherit(BasePanel)
local this = AdjutantPanel

local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)

local selectGo = {}
local curIndex

--初始化组件（用于子类重写）
function AdjutantPanel:InitComponent()
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)
    this.backBtn = Util.GetGameObject(self.gameObject, "backBtn")

    --获取帮助按钮
    this.helpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition

    --信息
    this.roleImage = Util.GetGameObject(self.gameObject, "Info/role")
    local info = Util.GetGameObject(self.gameObject, "Info/info")
    this.icon = Util.GetGameObject(info, "icon"):GetComponent("Image")
    this.skillName = Util.GetGameObject(info, "skillName"):GetComponent("Text")
    this.connectLv = Util.GetGameObject(info, "connect/value"):GetComponent("Text")
    this.skillLv = Util.GetGameObject(info, "skill/value"):GetComponent("Text")
    this.giftLv = Util.GetGameObject(info, "gift/value"):GetComponent("Text")
    this.trainLv = Util.GetGameObject(info, "train/value"):GetComponent("Text")
    this.dec = Util.GetGameObject(info, "dec"):GetComponent("Text")
    this.name = Util.GetGameObject(info, "name"):GetComponent("Text")
    this.id = Util.GetGameObject(info, "id/num"):GetComponent("Text")

    --down
    local down = Util.GetGameObject(self.gameObject,"down")
    this.freeButton = Util.GetGameObject(down, "FreeButton")
    this.freeRedpoint = Util.GetGameObject(down, "FreeButton/redpoint")
    this.freeResetTimes = Util.GetGameObject(down, "FreeResetTimes"):GetComponent("Text")
    this.freeLastTimes = Util.GetGameObject(down, "FreeLastTimes"):GetComponent("Text")
    this.btnList =  Util.GetGameObject(down, "listBtn")--列表按钮
    this.btnOverview =  Util.GetGameObject(down, "overviewBtn")--总览按钮

    --btns
    this.btnConnect = Util.GetGameObject(self.gameObject, "btns/connect")
    this.btnSkill = Util.GetGameObject(self.gameObject, "btns/skill")
    this.btnGift = Util.GetGameObject(self.gameObject, "btns/gift")
    this.btnTrain = Util.GetGameObject(self.gameObject, "btns/train")

    --红点
    this.btnChatRedpot = Util.GetGameObject(self.gameObject, "btns/connect/redpoint")
    this.btnSkillRedpot = Util.GetGameObject(self.gameObject, "btns/skill/redpoint")
    this.btnGiftRedpot = Util.GetGameObject(self.gameObject, "btns/gift/redpoint")
    this.btnTrainRedpot = Util.GetGameObject(self.gameObject, "btns/train/redpoint")

    --选择头像
    this.pioneerListScroll = Util.GetGameObject(self.gameObject, "pioneerList/Scroll")
    this.pioneer = Util.GetGameObject(this.pioneerListScroll, "pro")
    local w = this.pioneerListScroll.transform.rect.width
    local h = this.pioneerListScroll.transform.rect.height
    this.pioneerList = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.pioneerListScroll.transform, this.pioneer, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 75))
    this.pioneerList.moveTween.MomentumAmount = 1
    this.pioneerList.moveTween.Strength = 2

    --列表
    this.listview = Util.GetGameObject(self.gameObject, "Listview")
    this.listviewPro = Util.GetGameObject(this.listview, "pro")
    this.listviewPro:SetActive(false)
    this.ListviewScroll = Util.GetGameObject(this.listview, "scroll")
    local w = this.ListviewScroll.transform.rect.width
    local h = this.ListviewScroll.transform.rect.height
    this.pioneerAll = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.ListviewScroll.transform, this.listviewPro, nil,
            Vector2.New(w, h), 1, 1, Vector2.New(0, 20))
    this.pioneerAll.moveTween.MomentumAmount = 1
    this.pioneerAll.moveTween.Strength = 2
    
    --总览
    this.overview = Util.GetGameObject(self.gameObject, "Overview")
    this.overviewPro = Util.GetGameObject(this.overview, "pro")
    this.ScrollStaticBase = Util.GetGameObject(this.overview, "ScrollStaticBase")
    local w = this.ScrollStaticBase.transform.rect.width
    local h = this.ScrollStaticBase.transform.rect.height
    this.scrollView_proBase = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.ScrollStaticBase.transform, this.overviewPro, nil,
            Vector2.New(w, h), 1, 2, Vector2.New(5, 5))
    this.scrollView_proBase.moveTween.MomentumAmount = 1
    this.scrollView_proBase.moveTween.Strength = 2
    this.scrollView_proBase.elastic = false

    --总览属性
    this.ScrollStaticPer = Util.GetGameObject(this.overview, "ScrollStaticPer")
    local w = this.ScrollStaticPer.transform.rect.width
    local h = this.ScrollStaticPer.transform.rect.height
    this.scrollView_proPer = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.ScrollStaticPer.transform, this.overviewPro, nil,
            Vector2.New(w, h), 1, 2, Vector2.New(5, 5))
    this.scrollView_proPer.moveTween.MomentumAmount = 1
    this.scrollView_proPer.moveTween.Strength = 2
    this.scrollView_proPer.elastic = false
end

--绑定事件（用于子类重写）
function AdjutantPanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnConnect, function()
        UIManager.OpenPanel(UIName.AdjutantFuncPopup, 1, this.id.text)
    end)
    Util.AddClick(this.btnSkill, function()
        UIManager.OpenPanel(UIName.AdjutantFuncPopup, 2)
    end)
    Util.AddClick(this.btnGift, function()
        UIManager.OpenPanel(UIName.AdjutantFuncPopup, 3)
    end)
    Util.AddClick(this.btnTrain, function()
        UIManager.OpenPanel(UIName.AdjutantFuncPopup, 4)
    end)

    Util.AddClick(this.btnList, function()
        this.listview:SetActive(true)
        this.SetTabListUI()
    end)
    Util.AddClick(Util.GetGameObject(this.listview,"ListviewBack"), function()
        this.listview:SetActive(false)
    end)
    Util.AddClick(this.btnOverview, function()
        this.overview:SetActive(true)
        this.SetTabOverviewUI()
    end)
    Util.AddClick(Util.GetGameObject(this.overview,"BG"), function()
        this.overview:SetActive(false)
    end)

    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Adjutant,this.helpPosition.x,this.helpPosition.y)
    end)

    Util.AddClick(this.freeButton, function()
        if this.adjutantData.vigorTotal <= 0 then
            PopupTipPanel.ShowTipByLanguageId(22317)
        else
            -- 1单次、2以升级为目标次数
            -- 1消耗精力、2消耗物品
            local oldPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
            NetManager.GetAdjutantChat(0, 1, 1, function(msg)
                local oldLvArray = {}
                for i, v in ipairs(msg.adjutantChat) do
                    local adjutantData = AdjutantManager.GetOneAdjutantDataById(v.id)
                    table.insert(oldLvArray, adjutantData.chatLevel)
                end
                NetManager.GetAllAdjutantInfo(function()
                    UIManager.OpenPanel(UIName.AdjutantAutoChatShowPanel, oldLvArray, msg.adjutantChat)
                    this.ChatTimeCheck()
                    this.SetVigorUI()
                    CheckRedPointStatus(RedPointType.Adjutant_FreeButton)
                    RefreshPower(oldPower)
                end)
            end)
        end
    end)

    this.BindRedPoint()
end

--添加事件监听（用于子类重写）
function AdjutantPanel:AddListener()
end

--移除事件监听（用于子类重写）
function AdjutantPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function AdjutantPanel:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function AdjutantPanel:OnShow()
    curIndex = curIndex or 1
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.AdjutantPanel })

    this.adjutantData = AdjutantManager.GetAdjutantData()--已有先驱信息
    this.allAdjutantData = AdjutantManager.GetAllAdjutantArchiveData()--全部先驱信息

    this.ChatTimeCheck()
    this.SetVigorUI()
    this.SetIcon()
    this.SelectAdjutant(curIndex)

    AdjutantManager.CheckAllRedPoint()
end

--界面关闭时调用（用于子类重写）
function AdjutantPanel:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end

    if this.live then
        poolManager:UnLoadLive(this.liveName, this.live)
        Util.ClearChild(this.roleImage.transform)
        this.live = nil
    end
end

--界面销毁时调用（用于子类重写）
function AdjutantPanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
    this.ClearRedPoint()
    selectGo = {}
end

function this.BindRedPoint()
    BindRedPointObject(RedPointType.Adjutant_Btn_Chat,this.btnChatRedpot)
    BindRedPointObject(RedPointType.Adjutant_Btn_Skill,this.btnSkillRedpot)
    BindRedPointObject(RedPointType.Adjutant_Btn_Handsel,this.btnGiftRedpot)
    BindRedPointObject(RedPointType.Adjutant_Btn_Teach,this.btnTrainRedpot)
    BindRedPointObject(RedPointType.Adjutant_FreeButton,this.freeRedpoint)
end
function this.ClearRedPoint()
    ClearRedPointObject(RedPointType.Adjutant_Btn_Chat,this.btnChatRedpot)
    ClearRedPointObject(RedPointType.Adjutant_Btn_Skill,this.btnSkillRedpot)
    ClearRedPointObject(RedPointType.Adjutant_Btn_Handsel,this.btnGiftRedpot)
    ClearRedPointObject(RedPointType.Adjutant_Btn_Teach,this.btnTrainRedpot)
    ClearRedPointObject(RedPointType.Adjutant_FreeButton,this.freeRedpoint)
end

--精力
function this.SetVigorUI()
    this.adjutantData = AdjutantManager.GetAdjutantData()--已有先驱信息
    local upLimit = PrivilegeManager.GetPrivilegeNumber(PRIVILEGE_TYPE.AdjutantVigorLimit)
    this.freeLastTimes:GetComponent("Text").text = tostring(this.adjutantData.vigorTotal) .. "/" .. upLimit
end

--设置头像
function this.SetIcon()
    this.pioneerList:SetData(this.allAdjutantData, function(index, go)
        local allData = this.allAdjutantData[index]
        local data = nil
        for i = 1, #this.adjutantData.adjutants do
            if allData.AdjutantId == this.adjutantData.adjutants[i].id then
                data = this.adjutantData.adjutants[i]
            end
        end

        local icon = Util.GetGameObject(go,"icon"):GetComponent("Image")
        local unChecked = Util.GetGameObject(go, "unChecked")
        local select = Util.GetGameObject(go, "select")

        icon.sprite = Util.LoadSprite(GetResourceStr(allData.Head))

        local img = { unChecked = unChecked, select = select}
        if this.IsCanSeve(img) then
            table.insert(selectGo, img)
        end

        Util.AddOnceClick(icon.gameObject,function()
            if data ~= nil then
                this.SelectAdjutant(index)
            else
                PopupTipPanel.ShowTipByLanguageId(22622)
            end
        end)
    end)
end
--是否可以存储
function this.IsCanSeve(img)
    for i, v in ipairs(selectGo) do
        if v.unChecked == img.unChecked then
            return false
        end
    end
    return true
end
--选择先驱
function this.SelectAdjutant(index)
    curIndex = index
    for i = 1, #selectGo do
        selectGo[i].unChecked:SetActive(not i == index)
        selectGo[i].select:SetActive(i == index)
    end

    local allData = this.allAdjutantData[index]

    local data = {}
    for i = 1, #this.adjutantData.adjutants do
        if allData.AdjutantId == this.adjutantData.adjutants[i].id then
            data = this.adjutantData.adjutants[i]
        end
    end

    AdjutantManager.SetCurSelectAdjutantId(data.id)
    this.SetAdjutantData(allData, data)
end

--设置先驱信息
function this.SetAdjutantData(allData, data)
    if this.live then
        if this.liveName == allData.Image then
        else
            poolManager:UnLoadLive(this.liveName, this.live)
            Util.ClearChild(this.roleImage.transform)
            this.liveName = allData.Image
            this.live = poolManager:LoadLive(this.liveName, this.roleImage.transform, Vector3.one * allData.Scale, Vector3.New(allData.Pos[1], allData.Pos[2], 0))
        end
    else
        this.liveName = allData.Image
        this.live = poolManager:LoadLive(this.liveName, this.roleImage.transform, Vector3.one * allData.Scale, Vector3.New(allData.Pos[1], allData.Pos[2], 0))
    end
    this.name.text = GetLanguageStrById(allData.Name)
    this.id.text = data.id

    local skillData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantSkillConfig, "AdjutantId", allData.AdjutantId, "SkillLvl", data.skillLevel)
    if skillData~= nil then
        this.icon.sprite = Util.LoadSprite(GetResourcePath(skillConfig[skillData.Skill_Id].Icon))
        this.skillName.text = GetLanguageStrById(skillConfig[skillData.Skill_Id].Name)
        this.dec.text =  GetSkillConfigDesc(skillConfig[skillData.Skill_Id])

        this.connectLv.text = data.chatLevel
        this.giftLv.text = data.handselNum
        this.skillLv.text = data.skillLevel
        this.trainLv.text = data.teachLevel
    end
end

--列表
function this.SetTabListUI()
    this.pioneerAll:SetData(this.allAdjutantData, function(index, go)
        local allData = this.allAdjutantData[index]
        local data = this.adjutantData.adjutants[index]
        local skillData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantSkillConfig, "AdjutantId", allData.AdjutantId, "SkillLvl", 11)
        Util.GetGameObject(go,"headFrame/mask/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(allData.Picture))
        Util.GetGameObject(go,"skillFrame/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillConfig[skillData.Skill_Id].Icon))
        Util.GetGameObject(go,"name"):GetComponent("Text").text = GetLanguageStrById(allData.Name)
        Util.GetGameObject(go,"skillName"):GetComponent("Text").text = GetLanguageStrById(skillConfig[skillData.Skill_Id].Name)
        Util.GetGameObject(go,"dec"):GetComponent("Text").text = GetSkillConfigDesc(skillConfig[skillData.Skill_Id])
        Util.GetGameObject(go,"id"):GetComponent("Text").text = string.format(GetLanguageStrById(22306), allData.AdjutantId)
        if data then
            Util.GetGameObject(go,"connect/value"):GetComponent("Text").text = data.chatLevel
            Util.GetGameObject(go,"skill/value"):GetComponent("Text").text = data.skillLevel
            Util.GetGameObject(go,"gift/value"):GetComponent("Text").text = data.handselNum
            Util.GetGameObject(go,"train/value"):GetComponent("Text").text = data.teachLevel
        else
            Util.GetGameObject(go,"connect/value"):GetComponent("Text").text = 0
            Util.GetGameObject(go,"skill/value"):GetComponent("Text").text = 0
            Util.GetGameObject(go,"gift/value"):GetComponent("Text").text = 0
            Util.GetGameObject(go,"train/value"):GetComponent("Text").text = 0
        end
    end)
end

--总览属性
function this.SetTabOverviewUI()
    local proBase = AdjutantManager.GetAllAdjutantsProBase()
    this.scrollView_proBase:SetData(proBase, function(index, root)
        this.SetPro(root, proBase[index])
    end)
    this.scrollView_proBase:SetIndex(1)

    local proPer = AdjutantManager.GetAllAdjutantsProPer()

    this.scrollView_proPer:SetData(proPer, function(index, root)
        this.SetPro(root, proPer[index])
    end)
    this.scrollView_proPer:SetIndex(1)
end
--总览属性
function this.SetPro(go, data)
    go:SetActive(true)
    local proData = ConfigManager.GetConfigDataByKey(ConfigName.PropertyConfig, "PropertyId", data.id)
    Util.GetGameObject(go, "proName"):GetComponent("Text").text = GetLanguageStrById(proData.Info)
    local txt = Util.GetGameObject(go, "proVale"):GetComponent("Text")
    if proData.Style == 1 then--绝对值
        txt.text = "+"..GetPropertyFormatStr(1, data.value)
    elseif proData.Style == 2 then--百分比
        txt.text = "+"..GetPropertyFormatStr(2, data.value)
    end
    Util.GetGameObject(go, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourceStr(proData.Icon))
end

--自由沟通是否需要倒计时
function this.ChatTimeCheck()
    if AdjutantManager.GetAdjutantData().vigorTotal >= gameSetting[1].Vigor[2] then
        this.freeResetTimes.gameObject:SetActive(false)
        this.SetVigorUI()
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
    else
        this.TimeCountDownByS()
        this.freeResetTimes.gameObject:SetActive(true)
    end
end
--沟通倒计时
function this.TimeCountDownByS()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end

    local timeDown = gameSetting[1].Vigor[1] * 60 - (GetTimeStamp() - tonumber(AdjutantManager.GetAdjutantData().addVigorTime))
    this.freeResetTimes.text = string.format("(%s)", TimeToHMS(timeDown))
    this.timer = Timer.New(function()
        if timeDown <= 0 then
            this.timer:Stop()
            this.timer = nil
            NetManager.GetAllAdjutantInfo(function ()
                this.ChatTimeCheck()
                this.SetVigorUI()
            end)
            return
        end
        timeDown = timeDown - 1
        this.freeResetTimes.text = string.format("(%s)", TimeToHMS(timeDown))
    end, 1, -1, true)
    this.timer:Start()
end

return AdjutantPanel