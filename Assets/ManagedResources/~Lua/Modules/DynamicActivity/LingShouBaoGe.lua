local LingShouBaoGe= quick_class("LingShouBaoGe")
local this = LingShouBaoGe
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

local ActData=nil
local LSrewardData=nil
--按钮类型
local bType={
    Btn1=1,
    Btn10=2
}
--type与lotterySetting表中的id对应
local btns={ [bType.Btn1]={name="Btn1",isInfo=GetLanguageStrById(10644)}, [bType.Btn10]={name="Btn10",isInfo=GetLanguageStrById(12182)}}

function LingShouBaoGe:ctor(mainPanel, gameObject)
    this.mainPanel = mainPanel
    this.gameObject = gameObject
    this:InitComponent(gameObject)
    this:BindEvent()

end
function LingShouBaoGe:InitComponent(gameObject)
    this.helpBtn = Util.GetGameObject(this.gameObject,"help")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition

    this.preview = Util.GetGameObject(this.gameObject,"rightUp/preview")
    this.change = Util.GetGameObject(this.gameObject,"rightUp/change")
    this.detailBtn = Util.GetGameObject(this.gameObject,"rightUp/detailBtn")

    this.upper=Util.GetGameObject(this.gameObject,"bottom/times"):GetComponent("Text")   ---召唤上限
    this.tip1=Util.GetGameObject(this.gameObject,"bottom/Tip1"):GetComponent("Text")   ---刷新时间
    this.tip2=Util.GetGameObject(this.gameObject,"bottom/Tip2"):GetComponent("Text")   ---必出
    this.btnGroup=Util.GetGameObject(this.gameObject,"bottom/btngroup")
    this.leftTime=Util.GetGameObject(this.gameObject,"bottom/lefttime"):GetComponent("Text") 

    this.detail= Util.GetGameObject(this.gameObject, "detail")
    this.detail.gameObject:SetActive(false)

    this.grid = Util.GetGameObject(this.gameObject, "aniRoot")

    --mid
    this.progressValue = Util.GetGameObject(this.gameObject, "mid/progress/value"):GetComponent("Image")--fillAmount
    this.reward = Util.GetGameObject(this.gameObject, "mid/reward")
    this.value = Util.GetGameObject(this.gameObject, "mid/value")

end

function LingShouBaoGe:BindEvent()

    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.LingShouBaoGe,this.helpPosition.x,this.helpPosition.y)
    end)
    Util.AddClick(this.detailBtn, function()
        ActivityDetail.new(this.detail,3, nil, sortingOrder)
    end)
    Util.AddClick(this.change, function()
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.LingShouBaoGe,ActData,showData.monsterId,function()
            this:Refresh()
        end)
    end)

    Util.AddClick(this.preview, function()
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fdata, fseed = BattleManager.GetFakeBattleData(1006)
            local testFightData = {
            fightData = fdata,
            fightSeed = fseed,
            fightType = 0,
            maxRound = 20
            }
            UIManager.OpenPanel(UIName.BattlePanel, testFightData, BATTLE_TYPE.Test,function ()
                Timer.New(function ()
                    this:Refresh()
                end,3):Start()
            end)
        end)
    end)
end

function LingShouBaoGe:OnShow(_sortingOrder,_parent)
    parent =  _parent
    sortingOrder = _sortingOrder
    this.gameObject:SetActive(true)

    this:Refresh()
end

function LingShouBaoGe:Refresh()
    
    ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LingShouBaoGe)
    activityId = ActData.activityId
    LSrewardData = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",activityId)
    local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",activityId)
    singleRecruit = array[1]
    tenRecruit = array[2]
    this.change:SetActive(false)

    CheckRedPointStatus(RedPointType.LingShouBaoGe)
    this:refreshBtnShow()--刷新按钮显示
    this:TimeCountDown()--时间
    this:SetData()--加载界面数据立绘+进度条
end

function LingShouBaoGe:SetData()
    rewardData={}
    showData={}
    rewardData,showData,curScore = DynamicActivityManager.LingShouBuildData()

    --设置立绘
    bgName =  artConfig[SpiritAnimalConfig[showData.monsterId].Live].Name
    local pos = SpiritAnimalConfig[showData.monsterId].Position
    local scale = SpiritAnimalConfig[showData.monsterId].Scale
    -- if Live then
    --     poolManager:UnLoadLive(bgName, Live)
    -- end
    -- Live = poolManager:LoadLive(bgName, this.grid.transform, Vector3.one*scale*0.8, Vector2.New(pos[1],pos[2]+176))
    -- local RoleLiveGOGraphic = Live:GetComponent("SkeletonGraphic")
    -- RoleLiveGOGraphic.AnimationState:SetAnimation(0, "idle", true)
    if Live then
        destroy(Live)
    end
    Live = poolManager:LoadAsset(bgName, PoolManager.AssetType.GameObject)
    Live.transform:SetParent(this.grid.transform)
    Live.transform.localScale = Vector3.one --m5
    Live.transform.localPosition = Vector3.zero
    Live.name = "TestImg"
    local leftTime = lotterySetting[singleRecruit.Id].DiamondBoxContain[1][2] - ActData.value
    this.tip2.text = string.format(GetLanguageStrById(11480), leftTime, SpiritAnimalConfig[showData.monsterId].Name)
    
    --设置奖励
    this.progressValue.fillAmount = curScore/LSrewardData[#LSrewardData].Values[1][1]
    Util.GetGameObject(this.value, "num"):GetComponent("Text").text = curScore
    Util.GetGameObject(this.value, "tips"):GetComponent("Text").text = GetLanguageStrById(23039)

    for i = 1, this.reward.transform.childCount do
        local item = this.reward.transform:GetChild(i-1)
        Util.GetGameObject(item, "num/Text"):GetComponent("Text").text = LSrewardData[i].Reward[1][2]
        Util.GetGameObject(item, "Text"):GetComponent("Text").text = LSrewardData[i].Values[1][1]
        Util.GetGameObject(item, "icon"):GetComponent("Image").sprite = Util.LoadSprite(artConfig[SpiritAnimalConfig[showData.monsterId].Icon].Name)
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

function LingShouBaoGe:refreshBtnShow()
    --下方的数量显示
    local maxtimesId=lotterySetting[singleRecruit.Id].MaxTimes
    local curTimes=PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)
    this.upper.text = GetLanguageStrById(12225)..curTimes.."/"..privilegeConfig[maxtimesId].Condition[1][2]--召唤上限


    --是否是免费抽
    local freeTimesId=lotterySetting[singleRecruit.Id].FreeTimes
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
            info.text=" "..GetLanguageStrById(11759)
        else
            itemId = d[1]
            itemNum = d[2]
            icon.sprite = Util.LoadSprite(artResourcesConfig[itemConfig[itemId].ResourceID].Name)
            info.text = m.isInfo
            num.text = "x"..itemNum
        end

        Util.AddOnceClick(btn,function()
            local state = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..RecruitType.LingShowTen)
            if n == bType.Btn1 then
                if isFree then
                    self:Recruit(type,maxtimesId,0,0,state,freeTimesId)
                else
                    self:Recruit(type,maxtimesId,itemId,itemNum,state,freeTimesId)
                end
            elseif n==bType.Btn10 then
                self:Recruit(type,maxtimesId,itemId,itemNum,state,freeTimesId)
            end
        end)
    end
end

function LingShouBaoGe:Recruit(id,RecruitMaxtimesId,itemId,itemNum,state,freeTimesId)
    local generalType = id%2 == 0 and RecruitType.LingShowSingle or RecruitType.LingShowTen
    local num = id%2 == 0 and 1 or 10
    --是否超过每日最大上限
    if PrivilegeManager.GetPrivilegeRemainValue(RecruitMaxtimesId) < num then
        PopupTipPanel.ShowTipByLanguageId(11760)
        return
    end
    if itemId ~= 0 then
        if BagManager.GetItemCountById(itemId) < itemNum then
            PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[itemId].Name)..GetLanguageStrById(10492))
            return
        end
    end
    if itemId == 16 and state == 0 then
        UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,generalType,
            function()
                RecruitManager.RecruitRequest(id,function(msg)
                    PrivilegeManager.RefreshPrivilegeUsedTimes(RecruitMaxtimesId,num)
                    UIManager.OpenPanel(UIName.PokemonSingleResultPanel,id,msg.drop,activityId,function ()
                        this:Refresh()
                    end)
                end,freeTimesId,itemId,itemNum)
            end,itemNum)
    else
        RecruitManager.RecruitRequest(id, function(msg)
            PrivilegeManager.RefreshPrivilegeUsedTimes(RecruitMaxtimesId,num)
            UIManager.OpenPanel(UIName.PokemonSingleResultPanel,id,msg.drop,activityId,function ()
                this:Refresh()
            end)
        end,freeTimesId,itemId,itemNum)
    end
end

--- 将一段时间转换为天时分秒
function LingShouBaoGe:TimeToDHMS(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = math.floor(second % 60)
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    if day <= 0 and hour <= 0 then
        return string.format(GetLanguageStrById(12231),minute, sec)
    else
        return string.format(GetLanguageStrById(12232),day, hour)
    end
end

--刷新时间
function LingShouBaoGe:TimeCountDown()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end

    local timeDown = CalculateSecondsNowTo_N_OClock(24)
    this.tip1.text = TimeToHMS(timeDown)..GetLanguageStrById(12200)
    local timeDown2 = ActData.endTime - GetTimeStamp()
    this.leftTime.text = GetLanguageStrById(10028)..TimeToFelaxible(timeDown2)

    this.tip1.gameObject:SetActive(timeDown < timeDown2)

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
        this.tip1.text = TimeToHMS(timeDown)..GetLanguageStrById(12200)
        this.leftTime.text = GetLanguageStrById(10028)..TimeToFelaxible(timeDown2)
    end, 1, -1, true)
    this.timer:Start()
end

function LingShouBaoGe:OnHide()
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

function LingShouBaoGe:OnDestroy()
    if Live then
        poolManager:UnLoadLive(bgName, Live)
    end
    Live = nil
    ActivityDetail.OnDestroy()
end

--添加事件监听（用于子类重写）
function LingShouBaoGe:AddListener()
    
end

--移除事件监听（用于子类重写）
function LingShouBaoGe:RemoveListener()
    
end

return LingShouBaoGe