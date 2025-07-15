local XiangYaoDuoBao= quick_class("XiangYaoDuoBao")
local this = XiangYaoDuoBao
local ActivityDetail = require("Modules/DynamicActivity/ActivityDetail")--活动详情
local lotterySetting=ConfigManager.GetConfig(ConfigName.LotterySetting)
local privilegeConfig=ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local artConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local artResourcesConfig =ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local SpiritAnimalConfig = ConfigManager.GetConfig(ConfigName.SpiritAnimal)

local activityId = 0
local singleRecruit = nil
local tenRecruit = nil
local sortingOrder = 0
local parent
local freeTime= 0 --免费抽取次数
local showData = {}
local rewardData = {}
local curScore = 0

local Live
local bgName
local RoleLiveGOGraphic

local ActData=nil
local LSrewardData=nil
--按钮类型
local bType={
    Btn1=1,
    Btn10=2
}
--type与lotterySetting表中的id对应
local btns={ [bType.Btn1]={name="Btn1",isInfo=GetLanguageStrById(10478)}, [bType.Btn10]={name="Btn10",isInfo=GetLanguageStrById(10479)}}

function XiangYaoDuoBao:ctor(mainPanel, gameObject)
    this.mainPanel = mainPanel
    this.gameObject = gameObject
    this:InitComponent(gameObject)
    this:BindEvent()

end
function XiangYaoDuoBao:InitComponent(gameObject)
    this.helpBtn = Util.GetGameObject(this.gameObject,"help")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    this.detailBtn = Util.GetGameObject(this.gameObject,"rightUp/detailBtn")
    this.btn = Util.GetGameObject(this.gameObject,"Btn")

    this.upper=Util.GetGameObject(this.gameObject,"time/times"):GetComponent("Text")   ---召唤上限
    this.tip1=Util.GetGameObject(this.gameObject,"bottom/Tip1"):GetComponent("Text")   ---刷新时间
    this.tip2=Util.GetGameObject(this.gameObject,"bottom/Tip2"):GetComponent("Text")   --妖晶限购
    this.btnGroup=Util.GetGameObject(this.gameObject,"bottom/btngroup")
    this.leftTime=Util.GetGameObject(this.gameObject,"bottom/lefttime"):GetComponent("Text")
    this.canGet=Util.GetGameObject(this.gameObject,"bottom/canGet"):GetComponent("Text")

    this.detail= Util.GetGameObject(this.gameObject, "detail")
    this.detail.gameObject:SetActive(false)

    this.grid = Util.GetGameObject(this.gameObject, "aniRoot")
    --mid
    this.progressValue = Util.GetGameObject(this.gameObject, "mid/progress/value"):GetComponent("Image")--fillAmount
    this.reward = Util.GetGameObject(this.gameObject, "mid/reward")
    this.value = Util.GetGameObject(this.gameObject, "mid/value")

    -- this.effect1 = Util.GetGameObject(this.gameObject, "Effect_xiaozhuanfeng_hit01")
    -- this.effect2 = Util.GetGameObject(this.gameObject, "Effect_xiaozhuanfeng_hit02")
    -- this.effect1:SetActive(false)
    -- this.effect2:SetActive(false)

end

function XiangYaoDuoBao:BindEvent()

    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.XiangYaoDuoBao,this.helpPosition.x,this.helpPosition.y)
    end)
    Util.AddClick(this.detailBtn, function()
        ActivityDetail.new(this.detail,4,nil,self.sortingOrder)
    end)
    Util.AddClick(this.btn,function ()
        local thread=coroutine.start(function()
            RoleLiveGOGraphic.AnimationState:SetAnimation(0, "shuajian", true)
            this.btn:SetActive(false)
            coroutine.wait(2.5)
            RoleLiveGOGraphic.AnimationState:SetAnimation(0, "idle", true)
            this.btn:SetActive(true)
        end)
    end)
end

function XiangYaoDuoBao:OnShow(_sortingOrder,_parent)
    local actId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.XiangYaoDuoBao)
    if not actId or actId <= 0 then return end
    parent =  _parent
    -- Util.AddParticleSortLayer(this.effect1, _sortingOrder - sortingOrder)
    -- Util.AddParticleSortLayer(this.effect2, _sortingOrder - sortingOrder)
    sortingOrder = sortingOrder
    this.gameObject:SetActive(true)

    this:Refresh()

    self.sortingOrder = _sortingOrder
end

function XiangYaoDuoBao:Refresh()
    ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.XiangYaoDuoBao)
    activityId = ActData.activityId
    LSrewardData = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",activityId)
    local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",activityId)
    singleRecruit = array[1]
    tenRecruit = array[2]

    CheckRedPointStatus(RedPointType.XiangYaoDuoBao)
    this:refreshBtnShow()--刷新按钮显示
    this:TimeCountDown()--时间
    this:SetData()--加载界面数据立绘+进度条
end

function XiangYaoDuoBao:SetData()
    rewardData={}
    showData={}
    rewardData,showData,curScore = DynamicActivityManager.XiangYaoBuildData()
    --设置立绘
    if Live then
        poolManager:UnLoadLive(bgName, Live)
    end
    bgName = "live2d_xiaozhuanfeng"
    Live = poolManager:LoadLive(bgName, this.grid.transform, Vector3.New(0.4,0.4,0.4), Vector2.New(0,-300))
    RoleLiveGOGraphic = Live:GetComponent("SkeletonGraphic")
    RoleLiveGOGraphic.AnimationState:SetAnimation(0, "idle", true)

    --设置奖励
    this.progressValue.fillAmount = curScore/LSrewardData[#LSrewardData].Values[1][1]
    Util.GetGameObject(this.value, "num"):GetComponent("Text").text = curScore
    Util.GetGameObject(this.value, "tips"):GetComponent("Text").text = GetLanguageStrById(12129)

    for i = 1, this.reward.transform.childCount do
        local item = this.reward.transform:GetChild(i-1)
        Util.GetGameObject(item, "num/Text"):GetComponent("Text").text = LSrewardData[i].Reward[1][2]
        Util.GetGameObject(item, "Text"):GetComponent("Text").text = LSrewardData[i].Values[1][1]

        Util.GetGameObject(item, "icon"):GetComponent("Image").sprite = Util.LoadSprite(artConfig[itemConfig[rewardData[i].iconId].ResourceID].Name)
        Util.GetGameObject(item, "red"):SetActive(rewardData[i].state == 1)
        local btn = Util.GetGameObject(item, "icon")
        Util.AddOnceClick(btn,function ()
            if rewardData[i].state == 1 then
                NetManager.GetActivityRewardRequest(rewardData[i].missionId,activityId,function (drop)
                    UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1,function ()
                        this:Refresh()
                    end)
                end)
            else
                UIManager.OpenPanel(UIName.RewardItemSingleShowPopup,LSrewardData[i].Reward[1][1],nil)
            end
        end)
    end

end

function XiangYaoDuoBao:refreshBtnShow()
    --下方的数量显示
    local maxtimesId=singleRecruit.MaxTimes
    local curTimes=PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)
    this.upper.text = GetLanguageStrById(10483)..curTimes.."/"..privilegeConfig[maxtimesId].Condition[1][2]--召唤上限

    --下方的数量显示
    local curMoneyTimes=PrivilegeManager.GetPrivilegeRemainValue(singleRecruit.MoneyTimes)
    this.tip2.text = GetLanguageStrById(12130)..curMoneyTimes..GetLanguageStrById(10048)
    this.canGet.text = GetLanguageStrById(12131)..lotterySetting[singleRecruit.Id].DiamondBoxContain[1][2] - ActData.value..GetLanguageStrById(12132)

    --是否是免费抽
    local freeTimesId=singleRecruit.FreeTimes
    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        RecruitManager.freeUseTimeList[freeTimesId] = freeTime
    end
    --按钮赋值
    for n, m in ipairs(btns) do
        local btn = Util.GetGameObject(this.btnGroup,m.name)
        local redPot = Util.GetGameObject(btn.gameObject,"RedPoint")
        local info = Util.GetGameObject(btn.gameObject,"Content/Info"):GetComponent("Text")
        local icon = Util.GetGameObject(btn.gameObject,"Content/Icon"):GetComponent("Image")
        local num = Util.GetGameObject(btn.gameObject,"Content/Num"):GetComponent("Text")
        --存在免费次数 并且 免费>=1 并且是1按钮
        local isFree = freeTime and freeTime >= 1 and n == bType.Btn1
        redPot.gameObject:SetActive(isFree)
        icon.gameObject:SetActive(not isFree)
        num.gameObject:SetActive(not isFree)

        this.tip1.gameObject:SetActive(freeTime == 0)

        local itemId=0
        local itemNum=0
        local type = 0

        type = n == bType.Btn1 and singleRecruit.Id or tenRecruit.Id
        local d = RecruitManager.GetExpendData(type)

        if isFree then
            info.text=" "..GetLanguageStrById(10493)
        else
            itemId = d[1]
            itemNum = d[2]
            icon.sprite = Util.LoadSprite(artResourcesConfig[itemConfig[itemId].ResourceID].Name)
            info.text = m.isInfo
            num.text = "x"..itemNum
        end

        Util.AddOnceClick(btn,function()
            if not isFree then
                if BagManager.GetItemCountById(itemId)<d[2] then
                    PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[itemId].Name)..GetLanguageStrById(10486))
                    return
                end
            end
            local state = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..RecruitType.XiangYaoTen)
            if n==bType.Btn1 then
                if PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)+1>privilegeConfig[maxtimesId].Condition[1][2] then
                    PopupTipPanel.ShowTipByLanguageId(10485)
                    return
                end
                if d[1] == 16 and PrivilegeManager.GetPrivilegeUsedTimes(singleRecruit.MoneyTimes)+1>privilegeConfig[singleRecruit.MoneyTimes].Condition[1][2] and not isFree then
                    PopupTipPanel.ShowTipByLanguageId(11423)
                    return
                end
                local recruitOne = function()
                    RoleLiveGOGraphic.AnimationState:SetAnimation(0, "hit1", true)
                    -- this.effect1:SetActive(true)
                    this.mainPanel.mask:SetActive(true)
                    Timer.New(function ()
                        RoleLiveGOGraphic.AnimationState:SetAnimation(0, "idle", true)
                        -- this.effect1:SetActive(false)
                        this.mainPanel.mask:SetActive(false)
                        RecruitManager.RecruitRequest(singleRecruit.Id, function(msg)
                            PrivilegeManager.RefreshPrivilegeUsedTimes(maxtimesId,1)--记录抽卡次数
                            if not isFree and d[1] == 16 then
                                PrivilegeManager.RefreshPrivilegeUsedTimes(singleRecruit.MoneyTimes,1)--记录妖晶抽卡次数
                            end
                            UIManager.OpenPanel(UIName.SingleRecruitPanel, msg.drop.Hero[1],singleRecruit.Id,bType.Btn1,{RecruitType.XiangYaoSingle,RecruitType.XiangYaoTen})
                            CheckRedPointStatus(RedPointType.XiangYaoDuoBao)
                        end,freeTimesId)
                    end,1.2):Start()
                end
                if state==0 and d[1] == 16 and not isFree then
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,singleRecruit.Id,recruitOne)
                else
                    recruitOne()
                end

            elseif n==bType.Btn10 then
                if PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)+10>privilegeConfig[maxtimesId].Condition[1][2] then
                    PopupTipPanel.ShowTipByLanguageId(10485)
                    return
                end
                if d[1] == 16 and PrivilegeManager.GetPrivilegeUsedTimes(tenRecruit.MoneyTimes)+10>privilegeConfig[tenRecruit.MoneyTimes].Condition[1][2] then
                    PopupTipPanel.ShowTipByLanguageId(11423)
                    return
                end
                local recruitTen = function()
                    RoleLiveGOGraphic.AnimationState:SetAnimation(0, "hit3", true)
                    -- this.effect2:SetActive(true)
                    this.mainPanel.mask:SetActive(true)
                    Timer.New(function ()
                        RoleLiveGOGraphic.AnimationState:SetAnimation(0, "idle", true)
                        -- this.effect2:SetActive(false)
                        this.mainPanel.mask:SetActive(false)
                        RecruitManager.RecruitRequest(tenRecruit.Id, function(msg)
                            PrivilegeManager.RefreshPrivilegeUsedTimes(maxtimesId,10)--记录抽卡次数
                            if d[1] == 16 then
                                PrivilegeManager.RefreshPrivilegeUsedTimes(singleRecruit.MoneyTimes,10)--记录妖晶抽卡次数
                            end
                            UIManager.OpenPanel(UIName.SingleRecruitPanel, msg.drop.Hero,tenRecruit.Id,bType.Btn10,{RecruitType.XiangYaoTen,RecruitType.XiangYaoTen})
                            CheckRedPointStatus(RedPointType.XiangYaoDuoBao)
                        end,freeTimesId)
                    end,2.5):Start()
                end
                if state==0 and d[1] ==16 and not isFree then
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,tenRecruit.Id,recruitTen)
                else
                    recruitTen()
                end
            end
        end)
    end
end

--- 将一段时间转换为天时分秒
function XiangYaoDuoBao:TimeToDHMS(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = math.floor(second % 60)
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    if day <= 0 and hour <= 0 then
        return string.format(GetLanguageStrById(10472),minute, sec)
    else
        return string.format(GetLanguageStrById(10473),day, hour)
    end
end

--刷新时间
function XiangYaoDuoBao:TimeCountDown()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end

    local timeDown=CalculateSecondsNowTo_N_OClock(0)
    this.tip1.text = TimeToHMS(timeDown)..GetLanguageStrById(10488)
    local timeDown2 = ActData.endTime - GetTimeStamp()
    this.leftTime.text = GetLanguageStrById(10512)..TimeToFelaxible(timeDown2)

    this.tip1.gameObject:SetActive( (freeTime == 0) and (timeDown < timeDown2))

    this.timer = Timer.New(function()
        if timeDown < 1 then
            this.timer:Stop()
            this.timer = nil
            this:Refresh()
            return
        end
        if timeDown2 < 1 then
            this.timer:Stop()
            this.timer = nil
            parent:ClosePanel()
            return
        end
        timeDown = timeDown - 1
        timeDown2 = timeDown2 -1
        this.tip1.text = TimeToHMS(timeDown)..GetLanguageStrById(10488)
        this.leftTime.text = GetLanguageStrById(10023)..TimeToFelaxible(timeDown2)
    end, 1, -1, true)
    this.timer:Start()
end

function XiangYaoDuoBao:OnHide()
    if Live then
        poolManager:UnLoadLive(bgName, Live)
    end
    Live = nil
    this.gameObject:SetActive(false)
    this.detail.gameObject:SetActive(false)
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

function XiangYaoDuoBao:OnDestroy()
    if Live then
        poolManager:UnLoadLive(bgName, Live)
    end
    Live = nil
    ActivityDetail.OnDestroy()
end

--添加事件监听（用于子类重写）
function XiangYaoDuoBao:AddListener()
    
end

--移除事件监听（用于子类重写）
function XiangYaoDuoBao:RemoveListener()
    
end

return XiangYaoDuoBao