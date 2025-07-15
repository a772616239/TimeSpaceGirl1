local TimeLimitedCall = quick_class("TimeLimitedCall")

local ActivityDetail = require("Modules/Operating/ActivityDetail")--活动详情
local RewardPreview = require("Modules/Operating/RewardPreview")--奖励预览
local sortingOrder = 0
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local privilegeConfig = ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
--按钮类型
local bType = {
    Btn1 = 1,
    Btn10 = 2
}
--type与lotterySetting表中的id对应
local btns = {[bType.Btn1]={name="btngroup/once",isInfo=GetLanguageStrById(10644),type=RecruitType.TimeLimitSingle}, [bType.Btn10]={name="btngroup/ten",isInfo=GetLanguageStrById(12182),type=RecruitType.TimeLimitTen}}

local tabs = {"btngroup/activity","btngroup/reward"}

local secectTab =-1

local hero = {[1]={name="Bg/hero1",id=10001,hero="x_xianshizaohuan_fx"},[2]={name="Bg/hero3",id=10041,hero="x_xianshizaohuan_ttjz"},[3]={name="Bg/hero2",id=10089,hero="x_xianshizaohuan_rd"}}
local curLv = 0   --当前阶段id
local itemView 

function TimeLimitedCall:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()

end
function TimeLimitedCall:InitComponent(gameObject)
    self.helpBtn = Util.GetGameObject(self.gameObject,"btngroup/help")
    self.helpPosition = self.helpBtn:GetComponent("RectTransform").localPosition
    self.activityBtn = Util.GetGameObject(self.gameObject,"btngroup/activity")
    self.rewardBtn = Util.GetGameObject(self.gameObject,"btngroup/reward")
    self.timeupdate = Util.GetGameObject(self.gameObject,"timeupdate"):GetComponent("Text")   --剩余时间
    self.upper = Util.GetGameObject(self.gameObject,"maxtimes/times"):GetComponent("Text")   ---召唤上限   
    self.slider = Util.GetGameObject(self.gameObject, "nextlevel/Slider"):GetComponent("Slider")    
    self.sliderText=Util.GetGameObject(self.gameObject,"nextlevel/Text"):GetComponent("Text")     
    self.curtext = Util.GetGameObject(self.gameObject, "curvalue/Text"):GetComponent("Text")    
    self.frame = Util.GetGameObject(self.gameObject, "curvalue/frame"):GetComponent("Image")    
    self.nextReward = Util.GetGameObject(self.gameObject, "nextlevel/reward")
    self.icon = Util.GetGameObject(self.frame.gameObject, "icon"):GetComponent("Image")    
    self.detail = Util.GetGameObject(self.gameObject, "detail")
    self.detail.gameObject:SetActive(false)
    self.reward = Util.GetGameObject(self.gameObject, "reward")  
    self.reward.gameObject:SetActive(false)
    self.getBtn = Util.GetGameObject(self.gameObject,"nextlevel")      
    self.effect = Util.GetGameObject(self.gameObject,"juneng_chenggong") 
    
    
    self.hero1 = Util.GetGameObject(self.gameObject,"Bg/hero1")   
    self.hero2 = Util.GetGameObject(self.gameObject,"Bg/hero2")   
    self.hero3 = Util.GetGameObject(self.gameObject,"Bg/hero3")  
    
    self.recruitTimeUpdate = Util.GetGameObject(self.gameObject,"recruitTimesUpdate/Text1"):GetComponent("Text")    --时间
    self.recruitTimesUpdate = Util.GetGameObject(self.gameObject,"recruitTimesUpdate/Text"):GetComponent("Text")    --剩余次数
end

function TimeLimitedCall:BindEvent()
    Util.AddClick(self.helpBtn, function()    
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.TimeLimitedCall,self.helpPosition.x,self.helpPosition.y) 
        --UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.TimeLimitedCall,self.helpPosition.x,self.helpPosition.y) 
    end)
    Util.AddClick(self.activityBtn, function() 
        secectTab = 1 
        self:RefreshTabBtn()
        ActivityDetail.new(self.detail,1,nil, self.sortingOrder) 
    end)

    Util.AddClick(self.rewardBtn, function() 
        secectTab = 2 
        self:RefreshTabBtn()
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fb = ConfigManager.GetConfigData(ConfigName.FakeBattle, 1001)
            local testFightData = {
                fightData = loadstring("return "..fb.FightData)(),
                fightSeed = fb.TimeSeed,
                fightType = 0,
                maxRound = 20
            }
            UIManager.OpenPanel(UIName.BattlePanel, testFightData, BATTLE_TYPE.Test)
        end)
    end)

    Util.AddClick(self.hero1, function()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, 10001, 5)
    end)
    Util.AddClick(self.hero2, function()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, 10089, 5)
    end)
    Util.AddClick(self.hero3, function()
        UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, 10041, 5)
    end)
end

function TimeLimitedCall:OnShow(_sortingOrder)
    sortingOrder = _sortingOrder
    self.gameObject:SetActive(true)
    local UpHero = RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.TIME_LIMITED_UP)
    table.sort(UpHero,function(a,b) return a.Reward[1] < b.Reward[1]  end)
    for n,m in ipairs(hero) do
        Util.GetGameObject(self.gameObject,m.name.."/hero"):GetComponent("Image").sprite = Util.LoadSprite(m.hero)
        local configinfo = ConfigManager.GetConfigDataByKey(ConfigName.HeroConfig, "Id", UpHero[n].Reward[1])  
        Util.GetGameObject(self.gameObject,m.name.."/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(configinfo.PropertyName))
        Util.GetGameObject(self.gameObject,m.name.."/name"):GetComponent("Text").text = GetLanguageStrById(configinfo.ReadingName)
        --SetHeroStars(Util.GetGameObject(self.gameObject,m.name.."/starlayout"),5)
    end

    secectTab=-1
    self:RefreshTabBtn()
    self:RefreshGetHeroTimes()
    self:TimeCountDown()   
    self:RefreshNextLevelReward() 

    self.sortingOrder = _sortingOrder
end


function TimeLimitedCall:RefreshTabBtn()
    for n, m in pairs(tabs) do
        if n ~= secectTab then
            Util.GetGameObject(self.gameObject,tabs[n].."/select").gameObject:SetActive(false)
        else
            Util.GetGameObject(self.gameObject,tabs[n].."/select").gameObject:SetActive(true)
        end
    end
end

function TimeLimitedCall:RefreshNextLevelReward()
    local curActivityId=0
    local curLvstate = 0
    local curTimes = 0
    curActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)     
    local  data1 = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",curActivityId)   --通过活动id获取阶段任务      
    local rewarditem
    for n,m in ipairs(data1) do     
        curTimes,curLvstate = self:GetMissionStateById(m.Id,curActivityId) 
        if(curTimes >= m.Values[1][1]) then                               
            if curLvstate == 0 then
                curLvstate = 0
                curLv = m.Id
                rewarditem = m
                break
            end
        else
            curLvstate = 2
            curLv = m.Id
            rewarditem = m
            break
        end
    end 
   --所有任务都已完成
    if not rewarditem then
        curLvstate = -1
        rewarditem = data1[#data1]
        curLv = data1[#data1].Id
    end
    OperatingManager.TimeLimitedTimes = curTimes
    if not itemView then
        itemView = SubUIManager.Open(SubUIConfig.ItemView,self.nextReward.transform)
    end
    itemView:OnOpen(false, {rewarditem.Reward[1][1],rewarditem.Reward[1][2]}, 0.73, false)
    itemView.gameObject:SetActive(true)
    Util.GetGameObject(itemView.gameObject,"item/frame"):GetComponent("Button").enabled = false
    if (curLvstate == 0) then
        -- self.slider.gameObject:SetActive(false)\
        local temp = curTimes <= rewarditem.Values[1][1] and curTimes or rewarditem.Values[1][1] 
        Util.GetGameObject(self.slider.gameObject,"Text"):GetComponent("Text").text = temp.."/"..rewarditem.Values[1][1]
        self.slider.value = temp /rewarditem.Values[1][1]
        local vec = self.sliderText.transform:GetComponent("RectTransform").anchoredPosition3D
        vec.y = 22.4
        self.sliderText.transform:GetComponent("RectTransform").anchoredPosition3D = vec
        self.sliderText.text = GetLanguageStrById(12183)     
        self.sliderText.fontSize = 26
        Util.AddOnceClick(self.getBtn,function() 
            NetManager.GetActivityRewardRequest(curLv, curActivityId,
            function(respond)    
                    UIManager.OpenPanel(UIName.RewardItemPopup, respond, 1)
                    self:RefreshNextLevelReward()
                    self:RefreshGetHeroTimes()
            end)
        end)
        self.effect.gameObject:SetActive(true)
    elseif (curLvstate == -1) then
        -- self.slider.gameObject:SetActive(false)
        -- self.sliderText.gameObject:SetActive(false)
        self.slider.value = 1
        Util.GetGameObject(self.slider.gameObject,"Text"):GetComponent("Text").text = "300/300"
        self.sliderText.text = GetLanguageStrById(12254)
        Util.AddOnceClick(self.getBtn,function() 
            RewardPreview.new(self.reward, sortingOrder)
         end)
    else 
        self.slider.gameObject:SetActive(true)
        Util.GetGameObject(self.slider.gameObject,"Text"):GetComponent("Text").text = curTimes.."/"..rewarditem.Values[1][1]
        local vec = self.sliderText.transform:GetComponent("RectTransform").anchoredPosition3D
        vec.y = 22.4
        self.sliderText.transform:GetComponent("RectTransform").anchoredPosition3D = vec
        self.sliderText.text = GetLanguageStrById(12184)..curTimes.."/"..rewarditem.Values[1][1]
        self.sliderText.fontSize = 26
        self.slider.value = curTimes / rewarditem.Values[1][1]
        self.effect.gameObject:SetActive(false)
        Util.AddOnceClick(self.getBtn,function() 
            RewardPreview.new(self.reward, sortingOrder)
         end)
    end

    local reMaintimes = ActivityGiftManager.GetActivityValueInfo(curActivityId)
    reMaintimes = ConfigManager.GetConfigData(ConfigName.LotterySpecialConfig,18).Count - reMaintimes
    if reMaintimes == 0 then 
        reMaintimes = ConfigManager.GetConfigData(ConfigName.LotterySpecialConfig,18).Count
    end
    self.recruitTimesUpdate.text = string.format(GetLanguageStrById(12229),reMaintimes)

    local info= ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FindFairy)
    info = info.endTime - PlayerManager.serverTime
    info = self:TimeToDHMS(info)  
    self.recruitTimeUpdate.text = string.format(GetLanguageStrById(12230)..info)
end
--- 将一段时间转换为天时分秒
function TimeLimitedCall:TimeToDHMS(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    if day <= 0 and hour <= 0 then
        return string.format(GetLanguageStrById(12231),minute, sec)
    else
        return string.format(GetLanguageStrById(12232),day, hour)
    end
end

function TimeLimitedCall:GetMissionStateById(num,activityId)
    local mission = ActivityGiftManager.GetActivityInfo(activityId,num)  --从后端获取到的阶段数据    
    return mission.progress,mission.state
end

--刷新剩余次数
function TimeLimitedCall:RefreshGetHeroTimes()
    local freeTimesId = lotterySetting[RecruitType.TimeLimitSingle].FreeTimes
    local maxtimesId = lotterySetting[RecruitType.TimeLimitSingle].MaxTimes  --lotterySetting表中的MaxTimes对应privilegeConfig表中的id       
    local curTimes = PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)
    self.curtext.text = curTimes
    self.upper.text = GetLanguageStrById(12225)..curTimes.."/"..privilegeConfig[maxtimesId].Condition[1][2]--特权上限
    self.timeupdate.gameObject:SetActive(true)
    local freeTime = 0
    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        RecruitManager.freeUseTimeList[freeTimesId] = freeTime
    end
    --按钮赋值
    for n, m in ipairs(btns) do
        local btn=Util.GetGameObject(self.gameObject,m.name)
        local redPot=Util.GetGameObject(btn.gameObject,"redPoint")
        local info=Util.GetGameObject(btn.gameObject,"layout/Text"):GetComponent("Text")
        local icon=Util.GetGameObject(btn.gameObject,"layout/icon"):GetComponent("Image")
        local num=Util.GetGameObject(btn.gameObject,"layout/num"):GetComponent("Text")

        --存在免费次数 并且 免费>=1 并且是1按钮
        local isFree = freeTime and freeTime >= 1 and n == bType.Btn1
        redPot.gameObject:SetActive(isFree)
        icon.gameObject:SetActive(not isFree)
        num.gameObject:SetActive(not isFree)
        if n == bType.Btn1 and isFree then
            self.timeupdate.gameObject:SetActive(false)
        end

        local itemId=0
        local itemNum=0
        local d,v1=RecruitManager.GetExpendData(m.type)
        if(isFree) then          
            info.text = GetLanguageStrById(11759)
        else
            itemId = d[1]
            itemNum = d[2]
            icon.sprite = Util.LoadSprite(artResourcesConfig[itemConfig[itemId].ResourceID].Name)
            info.text = m.isInfo
            num.text = tostring(itemNum)
        end

        Util.AddOnceClick(btn,function()
            if not isFree then
                if BagManager.GetItemCountById(itemId) < d[2] then
                    PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[itemId].Name)..GetLanguageStrById(10492))
                    return
                end
            end
            local state = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..RecruitType.TimeLimitTen)
            if n == bType.Btn1 then
                if PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId) + 1 > privilegeConfig[maxtimesId].Condition[1][2] then
                    PopupTipPanel.ShowTipByLanguageId(11760)
                    return
                end
                local recruitOne = function()
                    RecruitManager.RecruitRequest(m.type, function(msg)
                        PrivilegeManager.RefreshPrivilegeUsedTimes(maxtimesId,1)--记录抽卡次数
                        UIManager.OpenPanel(UIName.SingleRecruitPanel, msg.drop.Hero[1],m.type,bType.Btn1)
                        CheckRedPointStatus(RedPointType.TimeLimited)
                    end,freeTimesId)
                end
                if state == 0 and d[1] == 16 and not isFree then
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,RecruitType.TimeLimitSingle,recruitOne)
                else
                    recruitOne()
                end

            elseif n==bType.Btn10 then
                local lotterySettingConfig=G_LotterySetting[m.type]                
                local count=BagManager.GetItemCountById(lotterySettingConfig.CostItem[1][1])
                local singleCost=lotterySettingConfig.CostItem[2][2]/lotterySettingConfig.PerCount

                if count>lotterySettingConfig.PerCount then
                    count=lotterySettingConfig.PerCount
                end
                local deficiencyCount=lotterySettingConfig.PerCount-count
                if BagManager.GetItemCountById(d[1])<deficiencyCount*singleCost then
                    PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[d[1]].Name)..GetLanguageStrById(10492))
                    return
                end
                    

                if PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)+10>privilegeConfig[maxtimesId].Condition[1][2] then
                    PopupTipPanel.ShowTip(GetLanguageStrById(11760))
                    return
                end
                local recruitTen = function()
                    RecruitManager.RecruitRequest(m.type, function(msg)                  
                        PrivilegeManager.RefreshPrivilegeUsedTimes(maxtimesId,10)--记录抽卡次数                    
                        UIManager.OpenPanel(UIName.SingleRecruitPanel, msg.drop.Hero, m.type,bType.Btn10)
                        CheckRedPointStatus(RedPointType.TimeLimited)
                    end,freeTimesId)
                end
                if state==0 and d[1] ==16 and not isFree and BagManager.GetItemCountById(v1)>0 then
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,RecruitType.TimeLimitTen,recruitTen)
                elseif state==0 and d[1] ==16 and not isFree and BagManager.GetItemCountById(v1)<= 0 then
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,RecruitType.TimeLimitTen,recruitTen)
                else
                    recruitTen()
                end
            end
        end)
    end
end

--刷新时间
function TimeLimitedCall:TimeCountDown()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    local timeDown=CalculateSecondsNowTo_N_OClock(5)--ActivityGiftManager.GetTaskRemainTime(ActivityTypeDef.FindFairy)
    self.timeupdate.text = TimeToHMS(timeDown)..GetLanguageStrById(12200)
    self.timer = Timer.New(function()
        if timeDown < 1 then
            self.timer:Stop()
            self.timer = nil
            return
        end
        timeDown = timeDown - 1
        self.timeupdate.text = TimeToHMS(timeDown)..GetLanguageStrById(12200)
    end, 1, -1, true)
    self.timer:Start()
end

function TimeLimitedCall:OnHide()
    self.gameObject:SetActive(false)
    self.detail.gameObject:SetActive(false)
    self.reward.gameObject:SetActive(false)
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end

function TimeLimitedCall:OnDestroy()
    ActivityDetail.OnDestroy()
    RewardPreview.OnDestroy()
    itemView = nil
end

return TimeLimitedCall