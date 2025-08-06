
require("Base/BasePanel")
RecruitPanel = Inherit(BasePanel)
local this = RecruitPanel
--local preList
local i = 0
local canDrag = true
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
local AllActSetConfig = ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local privilegeConfig = ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local orginLayer = 0
this.isJump = false
local trigger = nil
local RRotstionAngleY = 0 -- 旋转角度Y
local RRotstionAngleX = 0 -- 旋转角度X


--抽卡类型
local rType = {
    Normal = 1,--普通
    Friend = 2,--友情
    Hero = 3--神将
}
--按钮类型
local bType = {
    Btn1 = 1,
    Btn10 = 2
}

--抽卡配置
local preConfigure = {
    [rType.Normal] = {
        bgAtlas = GetPictureFont("cn2-X1_zhaomu_putong"),
        privilegeId = 38,
        btn = {
            [bType.Btn1] = {name = "Btn1",isInfo = GetLanguageStrById(10644),type = RecruitType.NormalSingle},--按钮配置 若有字段 则显示组件并显示内容
            [bType.Btn10] = {name = "Btn10",isInfo = GetLanguageStrById(10645),type = RecruitType.NormalTen}
        },
    },
    [rType.Friend] = {bgAtlas = GetPictureFont("cn2-X1_zhaomu_youqing"),
        btn = {
            [bType.Btn1] = {name = "Btn1",isInfo = GetLanguageStrById(10644),type = RecruitType.FriendSingle},
            [bType.Btn10] = {name = "Btn10",isInfo = GetLanguageStrById(10645),type = RecruitType.FriendTen}
       },
    },
    [rType.Hero] = {bgAtlas = GetPictureFont("cn2-X1_zhaomu_gaoji"),
        privilegeId = 14,
        btn = {
            [bType.Btn1] = {name = "Btn1",isInfo = GetLanguageStrById(10644),type = RecruitType.Single},
            [bType.Btn10] = {name = "Btn10",isInfo = GetLanguageStrById(10645),type = RecruitType.Ten}
        },
    }
}
local preSelfIconBgConfigure = {
    [rType.Normal] = "cn2-X1_zhaomu_putong_ziyuan_di",
    [rType.Friend] = "cn2-X1_zhaomu_youqing_ziyuan_di",
    [rType.Hero] = "cn2-X1_zhaomu_gaoji_ziyuan_di",
}
--预设容器
local preList = {}
--倒计时容器
local timeList = {}

RecruitPanel.curIndex = 2
local TabBox = require("Modules/Common/TabBox")
local tabData = {
    [1] = {
        default = "cn2-X1_tongyong_fenlan_weixuanzhong", 
        select = "cn2-X1_tongyong_fenlan_yixuanzhong",
        name = GetLanguageStrById(22609),
        defaultTextColor = Color.New(255/255,255/255,255/255,50/255), selectTextColor = Color.white,
        title = "cn2-X1_zhaomu_choushici"
    },
    [2] = {
        default = "cn2-X1_tongyong_fenlan_weixuanzhong", 
        select = "cn2-X1_tongyong_fenlan_yixuanzhong",
        name = GetLanguageStrById(22610),
        defaultTextColor = Color.New(255/255,255/255,255/255,50/255), selectTextColor = Color.white,
        title = "cn2-X1_zhaomu_chouyici"
    }
}
local TextColor = {
    [1] = Color.New(18/255,143/255,121/255,100/255),
    [2] = Color.New(18/255,80/255,143/255,100/255),
    [3] = Color.New(118/255,7/255,162/255,100/255)
}

function RecruitPanel:InitComponent()
    -- this.PlayerHeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.upView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft, panelType = PanelType.Recruit })
    this.UI = Util.GetGameObject(self.transform, "UI")
    this.backBtn = Util.GetGameObject(self.transform, "BackBtn/Btn")
    this.sliderText = Util.GetGameObject(self.transform, "rewardBox/content/Slider/numText"):GetComponent("Text")
    this.sliderMaxText = Util.GetGameObject(self.transform, "rewardBox/content/Slider/numMaxText"):GetComponent("Text")
    this.sliderVaule = Util.GetGameObject(self.transform, "rewardBox/content/Slider"):GetComponent("Slider")
    this.recommendBtn = Util.GetGameObject(self.transform, "RecommendBtn/Btn")
    this.recommendRedpoint = Util.GetGameObject(self.transform, "RecommendBtn/redpoint")

    this.previewBtn = Util.GetGameObject(this.gameObject, "PreviewBtn")--概率预览

    this.UI_effect_RecruitPanel_box_normal = Util.GetGameObject(self.transform, "rewardBox/content/UI_effect_RecruitPanel_box_normal")
    effectAdapte(Util.GetGameObject(this.UI_effect_RecruitPanel_box_normal, "quan01"))
    self.UI_effect_RecruitPanel_box_open = Util.GetGameObject(self.transform, "rewardBox/content/UI_effect_RecruitPanel_box_open")
    effectAdapte(Util.GetGameObject(self.UI_effect_RecruitPanel_box_open, "quan01"))
    effectAdapte(Util.GetGameObject(self.UI_effect_RecruitPanel_box_open, "quan02"))
    self.UI_effect_RecruitPanel_particle = Util.GetGameObject(self.transform, "UI_effect_RecruitPanel_particle")

    this.panel = Util.GetGameObject(this.gameObject,"UI/Panel")
    this.content = Util.GetGameObject(this.panel,"Content")--抽卡父节点
    this.pre = Util.GetGameObject(this.content,"Pre")--抽卡预设

    this.boxBtn = Util.GetGameObject(this.gameObject,"rewardBox/content/Slider/Background/Btn")
    this.upper = Util.GetGameObject(this.gameObject,"Upper/Num"):GetComponent("Text")--召唤上限

     --获取帮助按钮
    this.HelpBtn = Util.GetGameObject(self.gameObject,"HelpBtn")
    this.helpPosition = Vector3.New(this.HelpBtn:GetComponent("RectTransform").localPosition.x, this.HelpBtn:GetComponent("RectTransform").localPosition.y + 1000)
     --获取跳过动画按钮
    this.btnJump = Util.GetGameObject(self.gameObject, "btnJump")
    this.btnJumpChoose = Util.GetGameObject(self.gameObject, "btnJump/choose")

    this.choosePanel = Util.GetGameObject(self.gameObject,"choosePanel")
    this.generalBtn = Util.GetGameObject(self.gameObject, "choosePanel/tab")

    this.mask = Util.GetGameObject(this.choosePanel,"mask")
    this.box = Util.GetGameObject(this.choosePanel,"box")

    this.freeRedPot = Util.GetGameObject(this.choosePanel,"Redpot")--免费红点

    this.pos2 = this.mask.transform.position
    this.pos1 = this.generalBtn.transform.position

    this.Bg=Util.GetGameObject(self.gameObject,"Bg")

    this.InitComponentScene(self)
end

function RecruitPanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        RecruitPanel.curIndex=2
    end)
    --宝箱按钮
    Util.AddClick(this.boxBtn,function()
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitBox)
    end)
    --奖池预览按钮
    Util.AddClick(this.previewBtn, function()
        UIManager.OpenPanel(UIName.HeroPreviewPanel, 1, true)
    end)

    --推荐阵容
    Util.AddClick(this.recommendBtn, function ()
        -- UIManager.OpenPanel(UIName.GiveMePowerPanel)
        UIManager.OpenPanelWithSound(UIName.LineupRecommend)
     end)
    --跳过动画
     Util.AddClick(this.btnJump, function ()
        this.isJump = not this.isJump
        if this.isJump then
            this.btnJumpChoose:SetActive(true)
        else
            this.btnJumpChoose:SetActive(false)
        end
    end)

    Util.AddClick(this.generalBtn, function()
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GENERAL) then
            NetManager.GetGeneralData(function ()
                UIManager.OpenPanel(UIName.GeneralInfoPanel)
            end)
        else
            PopupTipPanel.ShowTip(ActTimeCtrlManager.GetFuncTip(FUNCTION_OPEN_TYPE.GENERAL))
        end
    end)

    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.Recruit,this.helpPosition.x,this.helpPosition.y)
    end)

    BindRedPointObject(RedPointType.LineupRecommend, this.recommendRedpoint)
end

function RecruitPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Recruit.OnRecruitRefreshData, this.UpdatePanelData)
end

function RecruitPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Recruit.OnRecruitRefreshData, this.UpdatePanelData)
end
function RecruitPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.UI_effect_RecruitPanel_box_normal, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(self.UI_effect_RecruitPanel_box_open, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(self.UI_effect_RecruitPanel_particle, self.sortingOrder - orginLayer)
    orginLayer = self.sortingOrder
end

function RecruitPanel:OnShow(...)
    CheckRedPointStatus(RedPointType.LineupRecommend)
    -- this.PlayerHeadFrameView:OnShow()
    this.upView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Recruit })

    this.UpdatePanelData()

    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.choosePanel, tabData, RecruitPanel.curIndex)

    this.TabCtrl:ChangeTab(RecruitPanel.curIndex)

    this.ShowScene()
    --SoundManager.PlayMusic(SoundConfig.BGM_Recruit)

    --读取本地是否跳过
    this.isJump = PlayerPrefs.GetInt(PlayerManager.uid .. "DrawJump") == 1
    this.btnJumpChoose:SetActive(this.isJump)

    self:OnInitTrigger()
end

local _index --抽卡下标
function RecruitPanel:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    RecruitPanel.curIndex = _index
    local value = 0
    if this.isJump then
        value = 1
    end
    PlayerPrefs.SetInt(PlayerManager.uid .. "DrawJump", value)
    this.CloseScene()
end

function RecruitPanel:OnInitTrigger()
    if not trigger then
        trigger = Util.GetEventTriggerListener(this.Bg)
        trigger.onBeginDrag = trigger.onBeginDrag + this.OnBeginDrag
        trigger.onDrag = trigger.onDrag + this.OnDrag
        trigger.onEndDrag = trigger.onEndDrag + this.OnEndDrag
    end
end

function RecruitPanel.OnDrag(p,d)
    if this.scene==nil then 
        return
    end
    
    if d.delta.x > 0 then--向左划
        if RRotstionAngleY >=10 then
            return
        end

        RRotstionAngleY = RRotstionAngleY+1*2
        this.scene.transform.localEulerAngles = Vector3.New(RRotstionAngleX,RRotstionAngleY,0)

        if RRotstionAngleX <=0 then
            return
        end
        RRotstionAngleX = RRotstionAngleX-0.1
        this.scene.transform.localEulerAngles = Vector3.New(RRotstionAngleX,RRotstionAngleY,0)
    elseif d.delta.x < 0 then--向右划
        if RRotstionAngleY <=-11 then
            return
        end

        RRotstionAngleY = RRotstionAngleY-1*2
        this.scene.transform.localEulerAngles = Vector3.New(RRotstionAngleX,RRotstionAngleY,0)

        if RRotstionAngleX >=1 then
            return
        end
        RRotstionAngleX = RRotstionAngleX+0.1
        this.scene.transform.localEulerAngles = Vector3.New(RRotstionAngleX,RRotstionAngleY,0)
    end

end

function RecruitPanel:OnDestroy()
    -- SubUIManager.Close(this.PlayerHeadFrameView)
    SubUIManager.Close(this.upView)
    preList = {}
    timeList = {}
    if this.liveNode then
        poolManager:UnLoadLive("live2d_npc_chouka", this.liveNode)
    end
    ClearRedPointObject(RedPointType.LineupRecommend, this.recommendRedpoint)
    this.isJump = false

    trigger.onBeginDrag = trigger.onBeginDrag - this.OnBeginDrag
    trigger.onDrag = trigger.onDrag - this.OnDrag
    trigger.onEndDrag = trigger.onEndDrag - this.OnEndDrag
    trigger = nil

end

function this.TabAdapter(tab,index,status)
    tab:GetComponent("Image").sprite = Util.LoadSprite(tabData[index][status])
    Util.GetGameObject(tab,"Text"):GetComponent("Text").text = tabData[index].name
    local title = Util.GetGameObject(tab,"title")
    title:GetComponent("Image").sprite = Util.LoadSprite(tabData[index].title)
    title:SetActive(false)
end

function this.SwitchView(index)
    _index = index

    Util.GetGameObject(this.mask.gameObject,"Text"):GetComponent("Text").text = Util.GetGameObject(this.box.transform:GetChild(index-1),"Text"):GetComponent("Text").text
    Util.GetGameObject(this.mask.gameObject,"title"):GetComponent("Image").sprite = Util.GetGameObject(this.box.transform:GetChild(index-1),"title"):GetComponent("Image").sprite

    if index == 1 then
        this.mask.transform.position = this.pos1
        for i = 1, #preList do
            Util.GetGameObject(preList[i],"Btn10"):SetActive(true)
            Util.GetGameObject(preList[i],"Btn1"):SetActive(false)

            Util.GetGameObject(preList[i],"SelfIconBg"):SetActive(true)
            Util.GetGameObject(preList[i],"free"):SetActive(false)

            local SelfIconNum = Util.GetGameObject(preList[i],"SelfIconBg/Num"):GetComponent("Text")
            local SelfIcon = Util.GetGameObject(preList[i],"SelfIconBg/SelfIcon"):GetComponent("Image")
            if i == rType.Normal then
                SelfIconNum.text = lotterySetting[25].CostItem[1][2]
                Util.GetGameObject(preList[i],"Time"):SetActive(false)
            elseif i == rType.Friend then
                SelfIconNum.text = lotterySetting[23].CostItem[1][2]
            elseif i == rType.Hero then
                if BagManager.GetItemCountById(lotterySetting[11].CostItem[1][1]) >= lotterySetting[11].CostItem[1][2] then
                    SelfIconNum.text = lotterySetting[11].CostItem[1][2]
                    SelfIcon.sprite = Util.LoadSprite("cn2-X1_icon_item_zijingka")
                else 
                    SelfIconNum.text = lotterySetting[11].CostItem[2][2]
                    SelfIcon.sprite = Util.LoadSprite("cn2-X1_icon_item_zuanshi")
                end
                Util.GetGameObject(preList[i],"TenTip"):SetActive(true)
                Util.GetGameObject(preList[i],"Time"):SetActive(false)
            end
        end
    else
        this.mask.transform.position = this.pos2
        for i = 1, #preList do
            Util.GetGameObject(preList[i],"Btn1"):SetActive(true)
            Util.GetGameObject(preList[i],"Btn10"):SetActive(false)

            local SelfIconNum = Util.GetGameObject(preList[i],"SelfIconBg/Num"):GetComponent("Text")
            local SelfIcon = Util.GetGameObject(preList[i],"SelfIconBg/SelfIcon"):GetComponent("Image")
            if i == rType.Normal then
                SelfIconNum.text = lotterySetting[26].CostItem[1][2]
            elseif i == rType.Friend then
                SelfIconNum.text = lotterySetting[24].CostItem[1][2]
            elseif i == rType.Hero then
                if BagManager.GetItemCountById(lotterySetting[12].CostItem[1][1]) >= lotterySetting[12].CostItem[1][2] then
                    SelfIconNum.text = lotterySetting[12].CostItem[1][2]
                    SelfIcon.sprite = Util.LoadSprite("cn2-X1_icon_item_zijingka")
                else
                    SelfIconNum.text = lotterySetting[12].CostItem[2][2]
                    SelfIcon.sprite = Util.LoadSprite("cn2-X1_icon_item_zuanshi")
                end
                Util.GetGameObject(preList[i],"TenTip"):SetActive(false)
            end

            local freeTime = 0
            if preConfigure[i].privilegeId then--特权ID
                freeTime = PrivilegeManager.GetPrivilegeRemainValue(preConfigure[i].privilegeId)
                RecruitManager.freeUseTimeList[preConfigure[i].privilegeId] = freeTime--特权免费次数赋值
            end
            if freeTime > 0 and preList[i].transform:GetSiblingIndex() ~= rType.Friend then
                Util.GetGameObject(preList[i],"SelfIconBg"):SetActive(false)
                Util.GetGameObject(preList[i],"free"):SetActive(true)
                Util.GetGameObject(preList[i],"Time"):SetActive(false)
            else
                Util.GetGameObject(preList[i],"SelfIconBg"):SetActive(true)
                Util.GetGameObject(preList[i],"free"):SetActive(false)
                Util.GetGameObject(preList[i],"Time"):SetActive(true)
            end
        end
    end
end

function this.UpdatePanelData()
    local maxTimesId = lotterySetting[1].MaxTimes --特权上限ID
    --初始化组件
    for i, v in ipairs(preConfigure) do
        local o = preList[i]--抽卡类型
        if not o then
            o = newObjToParent(this.pre,this.content)
            o.name = "Pre"..i
            preList[i] = o
        end
        local bg = Util.GetGameObject(preList[i],"Bg"):GetComponent("Image")
        local time = Util.GetGameObject(preList[i],"Time"):GetComponent("Text")
        local SelfIconBg = Util.GetGameObject(preList[i],"SelfIconBg"):GetComponent("Image")
        local SelfIcon = Util.GetGameObject(preList[i],"SelfIconBg/SelfIcon"):GetComponent("Image")
        local TenTip = Util.GetGameObject(preList[i],"TenTip")
        local outline = Util.GetGameObject(preList[i],"chooseText"):GetComponent("UnityEngine.UI.Outline")
        outline.effectColor = TextColor[i]
        if i == rType.Hero then
            TenTip:SetActive(RecruitManager.isTenRecruit == 0)
        end
        
        bg.sprite = Util.LoadSprite(v.bgAtlas)
        local freeTime = 0
        if v.privilegeId then--特权ID
            freeTime = PrivilegeManager.GetPrivilegeRemainValue(v.privilegeId)
            RecruitManager.freeUseTimeList[v.privilegeId] = freeTime--特权免费次数赋值
            table.insert(timeList,{timeObj = time}) --将倒计时预设存入
        end
        time.gameObject:SetActive((not freeTime or freeTime <= 0) and i ~= rType.Friend) --若不存在数据 或没免费次数 显示倒计时
        local free = freeTime and freeTime >= 1
        this.freeRedPot:SetActive(free)

        --按钮赋值
        for n, m in ipairs(v.btn) do
            local btn = Util.GetGameObject(o,m.name)
            local info = Util.GetGameObject(o,m.name.."/Content/Info"):GetComponent("Text")
            local icon = Util.GetGameObject(o,m.name.."/Content/Icon"):GetComponent("Image")
            local num = Util.GetGameObject(o,m.name.."/Content/Num"):GetComponent("Text")

            --组件的显示 若上方有配置就显示 没配置不显示
            info.gameObject:SetActive(not not m.isInfo)
            --存在免费次数 并且 免费>=1 并且是1按钮
            local isFree = freeTime and freeTime >= 1 and n == bType.Btn1

            icon.gameObject:SetActive(not isFree or n == bType.Btn10 or i == rType.Friend)
            num.gameObject:SetActive(not isFree or n == bType.Btn10 or i == rType.Friend)
            info.text = m.isInfo and m.isInfo or ""

            this.itemId = 0
            local itemId = 0
            local itemNum = 0
            local d, v1 = RecruitManager.GetExpendData(m.type)
            -- redPot:SetActive(isFree or itemIsFree)
            if isFree then --若1按钮有免费次数 后面逻辑不走了
            else
                itemId = d[1]
                this.itemId = d[1]
                itemId = d[1]
                itemNum = d[2]
                icon.sprite = Util.LoadSprite(artResourcesConfig[itemConfig[itemId].ResourceID].Name)
                num.text = "×"..itemNum
            end
            Util.AddOnceClick(btn,function()
                local state = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..RecruitType.Ten)
                if n == bType.Btn1 then
                    if PrivilegeManager.GetPrivilegeUsedTimes(maxTimesId) + 1 > privilegeConfig[maxTimesId].Condition[1][2] then
                        PopupTipPanel.ShowTipByLanguageId(11760)
                        return
                    end
                    if BagManager.GetItemCountById(itemId) < itemNum and not isFree then
                        PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[d[1]].Name)..GetLanguageStrById(10492))
                        return
                    end
                    --抽卡
                    local recruitOne = function()
                        local recruitAction = function()
                            RecruitManager.RecruitRequest(m.type, function(msg)
                                PrivilegeManager.RefreshPrivilegeUsedTimes(v.privilegeId, 1)--记录抽卡次数
                                PrivilegeManager.RefreshPrivilegeUsedTimes(maxTimesId, 1)
                                UIManager.OpenPanel(UIName.SingleRecruitPanel, msg.drop.Hero[1], m.type, bType.Btn1, this.isJump)
                            end, v.privilegeId)
                        end
        
                        if this.isJump then
                            recruitAction()
                        else
                            this.ScenePlayAnim(recruitAction)
                        end
                    end
                    if state == 0 and d[1] == 16 and not isFree then
                        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Recruit, RecruitType.Single, recruitOne)
                    else
                        recruitOne()
                    end

                elseif n == bType.Btn10 then
                    local lotterySettingConfig = G_LotterySetting[m.type]
                    local count = BagManager.GetItemCountById(lotterySettingConfig.CostItem[1][1])
                    local singleCost = lotterySettingConfig.CostItem[1][2]/lotterySettingConfig.PerCount
                    
                    if lotterySettingConfig.CostItem[2] == nil then
                        if BagManager.GetItemCountById(d[1]) < lotterySettingConfig.PerCount then
                            PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[d[1]].Name)..GetLanguageStrById(10492))
                            return
                        end
                    else
                        if count > lotterySettingConfig.PerCount then
                            count = lotterySettingConfig.PerCount
                        end
                        local deficiencyCount = lotterySettingConfig.PerCount-count
                        if BagManager.GetItemCountById(d[1]) < deficiencyCount*singleCost then
                            PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[d[1]].Name)..GetLanguageStrById(10492))
                            return
                        end
                    end
                    local deficiencyCount = lotterySettingConfig.PerCount - count
                    if BagManager.GetItemCountById(d[1]) < deficiencyCount * singleCost then
                        PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[d[1]].Name)..GetLanguageStrById(10492))
                        return
                    end

                    if PrivilegeManager.GetPrivilegeUsedTimes(maxTimesId)+10 > privilegeConfig[maxTimesId].Condition[1][2] then
                        PopupTipPanel.ShowTipByLanguageId(11760)
                        return
                    end

                    if d[1] == 16 then
                        if BagManager.GetItemCountById(19) < 10 then
                            local num = 10 - BagManager.GetItemCountById(19)
                            if BagManager.GetItemCountById(d[1]) < (num * 200) then
                                PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[d[1]].Name)..GetLanguageStrById(10492))
                                return
                            end
                        end
                    end

                    --抽卡
                    local recruitTen = function()
                        local recruitAction = function()
                            RecruitManager.RecruitRequest(m.type, function(msg)
                                PrivilegeManager.RefreshPrivilegeUsedTimes(maxTimesId, 10)--记录抽卡次数
                                local heros = RecruitManager.RandomHerosSort(msg.drop.Hero)--随机排序
                                if this.isJump then
                                    UIManager.OpenPanel(UIName.TenRecruitPanel,heros,m.type,this.isJump)
                                else
                                    UIManager.OpenPanel(UIName.SingleRecruitPanel, heros, m.type,bType.Btn10)
                                end
                                if m.type == 11 then
                                    RecruitManager.isTenRecruit = 1
                                end
                            end, v.privilegeId)
                        end
                        if this.isJump then
                            recruitAction()
                        else
                            this.ScenePlayAnim(recruitAction)
                        end
                    end
                    if d[1] == 16 and not isFree and BagManager.GetItemCountById(v1) > 0 then
                        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.Recruit,RecruitType.Ten,recruitTen)
                    elseif state == 0 and d[1] == 16 and not isFree and BagManager.GetItemCountById(v1) <= 0 then
                        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.Recruit,RecruitType.Ten,recruitTen)
                    else
                        recruitTen()
                    end
                end
            end)
        end
        SelfIconBg.sprite = Util.LoadSprite(preSelfIconBgConfigure[i])
        SelfIcon.sprite = Util.LoadSprite(artResourcesConfig[itemConfig[this.itemId].ResourceID].Name)
    end

    this.TimeCountDown()

    local num = BagManager.GetItemCountById(lotterySetting[RecruitType.RecruitBox].CostItem[1][1])
    RecruitManager.isCanOpenBox = num >= lotterySetting[RecruitType.RecruitBox].CostItem[1][2]
    --进度条
    this.sliderText.text =  num
    this.sliderMaxText.text = "/".. lotterySetting[RecruitType.RecruitBox].CostItem[1][2]
    this.sliderVaule.value = 0.1 + num/lotterySetting[RecruitType.RecruitBox].CostItem[1][2]
    this.UI_effect_RecruitPanel_box_normal:SetActive(not RecruitManager.isCanOpenBox)
    this.upper.text = PrivilegeManager.GetPrivilegeUsedTimes(maxTimesId).."/"..privilegeConfig[maxTimesId].Condition[1][2]--特权上限
end

function this.TimeCountDown()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    local timeDown = CalculateSecondsNowTo_N_OClock(24)
    timeList[1].timeObj.text = GetLanguageStrById(10028)..TimeToHMS(timeDown)
    timeList[2].timeObj.text = GetLanguageStrById(10028)..TimeToHMS(timeDown)
    this.timer = Timer.New(function()
        if timeDown < 1 then
            this.timer:Stop()
            this.timer = nil
            --结束逻辑
            return
        end
        timeDown = timeDown - 1
        timeList[1].timeObj.text = GetLanguageStrById(10028)..TimeToHMS(timeDown)
        timeList[2].timeObj.text = GetLanguageStrById(10028)..TimeToHMS(timeDown)
    end, 1, -1, true)
    this.timer:Start()
end

-----------------------------------抽卡场景-----------------------------------
function this.InitComponentScene(root)
    this.Mask = Util.GetGameObject(root.transform, "Mask")
    this.choukalihui = Util.GetGameObject(root.transform, "choukalihui"):GetComponent("SkeletonGraphic")

    if not this.sceneGameobject then
        local scenePrefab = resMgr:LoadAsset("ChoukaUIScene")
        this.sceneGameobject = GameObject.Instantiate(scenePrefab, nil)
        this.sceneGameobject.transform.localScale = Vector3.one
        this.animator = this.sceneGameobject:GetComponent("Animator")
    end
       
    this.scene=Util.GetGameObject(this.sceneGameobject, "Scene")
end

function this.ShowScene()
    this.ScenePlayAnimReset()
    this.sceneGameobject:SetActive(true)
end

-- 点击抽卡时调用
function this.ScenePlayAnim(backAction)
    RecruitManager.isDraw = true
    this.Mask:SetActive(true)

    this.animator:SetBool("play",true)
    this.choukalihui.AnimationState:SetAnimation(0, "idle1", false)

    SoundManager.PlaySound(SoundConfig.Sound_Recruit_Anim)

    --3.6秒人物移动
    Timer.New(function ()
        this.choukalihui.transform:DOLocalMove(Vector2.New(1600,-496),0.6):OnComplete(function()        
            this.UI:SetActive(false)
            this.upView.gameObject:SetActive(false)
            -- this.PlayerHeadFrameView.gameObject:SetActive(false)
        end)
    end, 3.6):Start()
    --6.5秒动画结束s
    Timer.New(function ()
            backAction()            
    end, 6.8):Start()
    --7.5秒重置
    Timer.New(function ()        
        this.ScenePlayAnimReset()
    end, 7.5):Start()

    -- this.sceneTimer = Timer.New(function ()
    --     this.choukalihui.transform:DOLocalMove(Vector2.New(1600,-496),0.6):OnComplete(function()        
    --         -- backAction()            
    --         -- this.ScenePlayAnimReset()
    --     end)
    -- end, 3.6)
    -- this.sceneTimer:Start()
end

-- 动画重置
function this.ScenePlayAnimReset()
    -- if this.sceneTimer then
    --     this.sceneTimer:Stop()
    --     this.sceneTimer = nil
    -- end

    this.choukalihui.AnimationState:SetAnimation(0, "idle", true)
    this.choukalihui.transform.localPosition = Vector3.New(240,-496,0)

    this.animator:SetBool("play",false)

    this.UI:SetActive(true)
    this.upView.gameObject:SetActive(true)
    -- this.PlayerHeadFrameView.gameObject:SetActive(true)
    this.Mask:SetActive(false)
    RecruitManager.isDraw = false
end

function this.CloseScene()
    this.ScenePlayAnimReset()
    --resMgr:UnLoadAsset("ChoukaUIScene")
    this.sceneGameobject:SetActive(false)
    --this.sceneGameobject = nil
    --this.animator = nil
end
-----------------------------------END-----------------------------------

return RecruitPanel