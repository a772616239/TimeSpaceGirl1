local TimeLimitedCall = quick_class("TimeLimitedCall")

local ActivityDetail = require("Modules/DynamicActivity/ActivityDetail")--活动详情
local RewardPreview = require("Modules/DynamicActivity/RewardPreview")--奖励预览
local sortingOrder = 0
local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
local privilegeConfig = ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local artResourcesConfig =ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local SpecialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
local parent 
local activityId = 0 
local singleRecruit = nil
local tenRecruit = nil
--按钮类型
local bType = {
    Btn1 = 1,
    Btn10 = 2
}
--type与lotterySetting表中的id对应
local btns = {
    [bType.Btn1] = { 
        name = "btngroup/once",isInfo = GetLanguageStrById(10644)
    },
    [bType.Btn10] = { 
        name = "btngroup/ten",isInfo = GetLanguageStrById(12182)}
    }
local curLv = 0--当前阶段id
local itemView
local isJump = false
function TimeLimitedCall:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
function TimeLimitedCall:InitComponent(gameObject)
    self.helpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    self.helpPosition = self.helpBtn:GetComponent("RectTransform").localPosition

    self.activityBtn = Util.GetGameObject(self.gameObject,"activityBtn")--活动详情
    self.rewardBtn = Util.GetGameObject(self.gameObject,"rewardBtn")--奖励预览

    self.timeUpdate = Util.GetGameObject(self.gameObject,"timeUpdate"):GetComponent("Text")--免费次数剩余刷新时间
    self.upper = Util.GetGameObject(self.gameObject,"maxtimes"):GetComponent("Text")--召唤上限 

    self.nextlevel = Util.GetGameObject(self.gameObject,"nextlevel")
    self.nextNum = Util.GetGameObject(self.gameObject,"nextlevel/nextNum/value"):GetComponent("Text")

    self.slider = Util.GetGameObject(self.nextlevel, "Slider"):GetComponent("Slider")
    self.sliderText = Util.GetGameObject(self.nextlevel,"Slider/Text"):GetComponent("Text")

    self.nextReward = Util.GetGameObject(self.nextlevel, "reward")--下一级奖励

    --活动详情
    self.detail = Util.GetGameObject(self.gameObject, "detail")
    self.detail.gameObject:SetActive(false)
    --奖励预览
    self.reward = Util.GetGameObject(self.gameObject, "reward")
    self.reward.gameObject:SetActive(false)

    self.jumpBtn = Util.GetGameObject(self.gameObject, "jumpBtn")--跳过动画
    self.jumpBtnChoose = Util.GetGameObject(self.gameObject, "jumpBtn/choose")
    
    self.effect = Util.GetGameObject(self.nextReward,"juneng_chenggong") 
    
    self.recruitTimeUpdate = Util.GetGameObject(self.gameObject,"time/timeText"):GetComponent("Text")--活动剩余时间
    self.recruitTimesUpdate = Util.GetGameObject(self.gameObject,"recruitTimesUpdate/Text"):GetComponent("Text")--保底剩余次数

    self.receiveAll = Util.GetGameObject(self.gameObject, "receiveAll")--全部领取完
end

function TimeLimitedCall:BindEvent()

    Util.AddClick(self.helpBtn, function()    
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.TimeLimitedCall,self.helpPosition.x,self.helpPosition.y) 
    end)
    Util.AddClick(self.rewardBtn, function() 
        ActivityDetail.new(self.detail,1, nil, sortingOrder) 
    end)

    -- Util.AddClick(self.rewardBtn, function()        
    --     UIManager.OpenPanel(UIName.BattleStartPopup, function ()
    --         local fb = ConfigManager.GetConfigData(ConfigName.FakeBattle, 1001)
    --         local testFightData = {
    --         fightData = loadstring("return "..fb.FightData)(),
    --         fightSeed = fb.TimeSeed,
    --         fightType = 0,
    --         maxRound = 20
    --         }
    --         UIManager.OpenPanel(UIName.BattlePanel, testFightData, BATTLE_TYPE.Test)
    --     end)
    -- end)

    --跳过动画
    Util.AddClick(self.jumpBtn, function ()
        isJump = not isJump   
        if isJump then
            self.jumpBtnChoose:SetActive(true)
        else
            self.jumpBtnChoose:SetActive(false)
        end
    end)

    Util.AddClick(self.activityBtn,function() 
        RewardPreview.new(self.reward, sortingOrder)
    end)
end

function TimeLimitedCall:OnShow(_sortingOrder,_parent)
    parent =  _parent
    sortingOrder = _sortingOrder
    self.gameObject:SetActive(true)

    activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairy)
    local configData = ConfigManager.GetConfigDataByKey(ConfigName.AcitvityShow, "ActivityId", activityId)

    local array = ConfigManager.GetAllConfigsDataByKey(ConfigName.LotterySetting,"ActivityId",activityId)
    singleRecruit = array[1]
    tenRecruit = array[2]

    local UpHero = RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.TIME_LIMITED_UP)
    table.sort(UpHero,function(a,b) return a.Reward[1] < b.Reward[1] end)
    local idx = 1
    for n,m in ipairs(configData.Hero) do
        local configinfo = ConfigManager.GetConfigDataByKey(ConfigName.HeroConfig, "Id", m)
        local loadspr = GetProStrImageByProNum(configinfo.PropertyName)
        local hero = Util.GetGameObject(self.gameObject,"Bg/hero" .. idx)
        local icon = Util.GetGameObject(hero,"bg/icon")
        icon:GetComponent("Image").sprite = Util.LoadSprite(configData.Heroimg[idx])
        icon:GetComponent("Image"):SetNativeSize()
        icon:GetComponent("RectTransform").localScale = Vector3.one * tonumber(configData.HeroimgTransform[idx][1])
        icon:GetComponent("RectTransform").anchoredPosition = Vector2.New(configData.HeroimgTransform[idx][2],configData.HeroimgTransform[idx][3])

        Util.GetGameObject(hero,"nameBg/pro"):GetComponent("Image").sprite = Util.LoadSprite(loadspr)
        Util.GetGameObject(hero,"nameBg/name"):GetComponent("Text").text = GetLanguageStrById(configinfo.ReadingName)
        Util.AddOnceClick(hero, function()
            UIManager.OpenPanel(UIName.RoleGetInfoPopup, false, m, 5)
        end)
        idx = idx + 1
    end

    self:RefreshGetHeroTimes()
    self:TimeCountDown()   
    self:RefreshNextLevelReward() 
end

--刷新下一级奖励
function TimeLimitedCall:RefreshNextLevelReward()
    local curLvstate = 0
    local info = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FindFairy)
    local curTimes = 0
    local data1 = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",activityId)   --通过活动id获取阶段任务      
    local rewarditem
    for n,m in ipairs(data1) do     
        curTimes,curLvstate = self:GetMissionStateById(m.Id,activityId) 
        if curTimes >= m.Values[1][1] then                               
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
    itemView:OnOpen(false, {rewarditem.Reward[1][1],rewarditem.Reward[1][2]}, 0.55, false)
    itemView.gameObject:SetActive(true)
    Util.GetGameObject(itemView.gameObject,"item/frame"):GetComponent("Button").enabled = false

    self.nextlevel:SetActive(true)
    self.receiveAll:SetActive(false)
    if curLvstate == 0 then
        local temp = curTimes <= rewarditem.Values[1][1] and curTimes or rewarditem.Values[1][1] 
        self.sliderText.text = temp.."/"..rewarditem.Values[1][1]
        self.slider.value = temp /rewarditem.Values[1][1]
        self.nextNum.text = rewarditem.Values[1][1]
        Util.AddOnceClick(self.nextReward,function() 
            NetManager.GetActivityRewardRequest(curLv, activityId,
            function(respond)    
                UIManager.OpenPanel(UIName.RewardItemPopup, respond, 1)
                self:RefreshNextLevelReward()
                self:RefreshGetHeroTimes()
            end)
        end)
        self.effect.gameObject:SetActive(true)
    elseif curLvstate == -1 then
        self.nextlevel:SetActive(false)
        self.receiveAll:SetActive(true)
    else 
        self.slider.gameObject:SetActive(true)
        self.sliderText.text = curTimes.."/"..rewarditem.Values[1][1]
        self.slider.value = curTimes/rewarditem.Values[1][1]
        Util.GetGameObject(self.nextlevel,"nextNum/value"):GetComponent("Text").text = rewarditem.Values[1][1]
        self.effect.gameObject:SetActive(false)
    end

    local reMaintimes = info.value

    local totalTimes = ConfigManager.GetConfigDataByKey(ConfigName.LotterySpecialConfig,"Type",singleRecruit.MergePool).Count
    reMaintimes = totalTimes - reMaintimes
    if reMaintimes == 0 then 
        reMaintimes = totalTimes
    end

    self.recruitTimesUpdate.text = string.format(GetLanguageStrById(12229),reMaintimes)

    local timeDown = info.endTime - PlayerManager.serverTime
    self.recruitTimeUpdate.text = string.format(GetLanguageStrById(12230)..self:TimeToDHMS(timeDown))
    Timer.New(function()
        if not IsNull(self.recruitTimeUpdate)  then
            if timeDown < 1 then
                self.recruitTimeUpdate.text = string.format(GetLanguageStrById(12230)..self:TimeToDHMS(0))
            else
                timeDown = timeDown - 1
                self.recruitTimeUpdate.text = string.format(GetLanguageStrById(12230)..self:TimeToDHMS(timeDown))
            end
        end
    end, 1, -1, true):Start()
end

--将一段时间转换为天时分秒
function TimeLimitedCall:TimeToDHMS(second)
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

function TimeLimitedCall:GetMissionStateById(num,activityId)
    local mission = ActivityGiftManager.GetActivityInfo(activityId,num)  --从后端获取到的阶段数据    
    return mission.progress,mission.state
end

--刷新剩余次数
function TimeLimitedCall:RefreshGetHeroTimes()
    local freeTimesId = lotterySetting[singleRecruit.Id].FreeTimes
    local maxtimesId = lotterySetting[singleRecruit.Id].MaxTimes  --lotterySetting表中的MaxTimes对应privilegeConfig表中的id       
    -- local curTimes = PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)
    -- self.upper.text = GetLanguageStrById(12225)..curTimes.."/"..privilegeConfig[maxtimesId].Condition[1][2]--特权上限
    self.upper.text = GetLanguageStrById(50181) .. PrivilegeManager.dailyGemRandomTimes .. "/" .. SpecialConfig[500].Value
    local freeTime = 0
    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        RecruitManager.freeUseTimeList[freeTimesId] = freeTime
    end
    --按钮赋值
    for n, m in ipairs(btns) do
        local btn = Util.GetGameObject(self.gameObject,m.name)
        local redPot = Util.GetGameObject(btn.gameObject,"redPoint")
        -- local info = Util.GetGameObject(btn.gameObject,"mask/Text"):GetComponent("Text")
        local icon = Util.GetGameObject(btn.gameObject,"layout/icon"):GetComponent("Image")
        local num = Util.GetGameObject(btn.gameObject,"layout/num"):GetComponent("Text")

        --存在免费次数 并且 免费>=1 并且是1按钮
        local isFree = freeTime and freeTime >= 1 and n == bType.Btn1
        redPot.gameObject:SetActive(isFree)
        icon.gameObject:SetActive(not isFree)
        num.gameObject:SetActive(not isFree)
        if n == bType.Btn1 and isFree then
            self.timeUpdate.gameObject:SetActive(false)
            Util.GetGameObject(btn.gameObject,"free"):SetActive(true)
            Util.GetGameObject(btn.gameObject,"noFree"):SetActive(false)
        elseif n == bType.Btn1 and not isFree then
            self.timeUpdate.gameObject:SetActive(true)
            Util.GetGameObject(btn.gameObject,"free"):SetActive(false)
            Util.GetGameObject(btn.gameObject,"noFree"):SetActive(true)
        end

        local itemId = 0
        local itemNum = 0
        local type = 0
        if n == bType.Btn1 then
            type = singleRecruit.Id
        else
            type = tenRecruit.Id
        end
        local d,v1 = RecruitManager.GetExpendData(type)
        if isFree then          
            -- info.text = GetLanguageStrById(11759)
        else
            itemId = d[1]
            itemNum = d[2]
            icon.sprite = Util.LoadSprite(artResourcesConfig[itemConfig[itemId].ResourceID].Name)
            -- info.text = m.isInfo
            if itemId == 16 then
                num.text = tostring(itemNum)
            else
                num.text = BagManager.GetItemCountById(itemId).."/"..tostring(itemNum)
            end
        end

        Util.AddOnceClick(btn,function()
            local state_1 = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..singleRecruit.Id)
            local state_10 = PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_RecruitConfirm"..tenRecruit.Id)
            if n == bType.Btn1 then
                if not isFree then
                    if BagManager.GetItemCountById(itemId) < d[2] then
                        PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[itemId].Name)..GetLanguageStrById(10492))
                        return
                    end
                end
                if PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)+1 > privilegeConfig[maxtimesId].Condition[1][2] then
                    PopupTipPanel.ShowTip(GetLanguageStrById(11760))
                    return
                end
                local recruitOne = function()
                    RecruitManager.RecruitRequest(singleRecruit.Id, function(msg)
                        if isFree then
                            PrivilegeManager.RefreshPrivilegeUsedTimes(freeTimesId,1)--记录免费抽卡次数
                        end
                        PrivilegeManager.RefreshPrivilegeUsedTimes(maxtimesId,1)--记录抽卡次数
                        UIManager.OpenPanel(UIName.SingleRecruitPanel, msg.drop.Hero[1],singleRecruit.Id,bType.Btn1)
                        CheckRedPointStatus(RedPointType.TimeLimited)
                    end,freeTimesId)

                end
                if state_1 == 0 and d[1] == 16 and not isFree then
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.RecruitConfirm,singleRecruit.Id,recruitOne)
                else
                    recruitOne()
                end

            elseif n == bType.Btn10 then
                local lotterySettingConfig = G_LotterySetting[type]
                local count = BagManager.GetItemCountById(lotterySettingConfig.CostItem[1][1])
                local singleCost = lotterySettingConfig.CostItem[2][2]/lotterySettingConfig.PerCount
                if count > lotterySettingConfig.PerCount then
                    count = lotterySettingConfig.PerCount
                end
                local deficiencyCount = lotterySettingConfig.PerCount-count
                if BagManager.GetItemCountById(d[1]) < deficiencyCount*singleCost then
                    PopupTipPanel.ShowTip(GetLanguageStrById(itemConfig[d[1]].Name)..GetLanguageStrById(10492))
                    return
                end

                if PrivilegeManager.GetPrivilegeUsedTimes(maxtimesId)+10 > privilegeConfig[maxtimesId].Condition[1][2] then
                    PopupTipPanel.ShowTip(GetLanguageStrById(11760))
                    return
                end
                local recruitTen = function()
                    RecruitManager.RecruitRequest(tenRecruit.Id, function(msg)                  
                        PrivilegeManager.RefreshPrivilegeUsedTimes(maxtimesId,10)--记录抽卡次数
                        if isJump then
                            local heros = RecruitManager.RandomHerosSort(msg.drop.Hero)--随机排序
                            UIManager.OpenPanel(UIName.TenRecruitPanel,heros,tenRecruit.Id,isJump)
                        else
                            UIManager.OpenPanel(UIName.SingleRecruitPanel, msg.drop.Hero, tenRecruit.Id,bType.Btn10)
                        end
                        CheckRedPointStatus(RedPointType.TimeLimited)
                    end,freeTimesId)
                end
                if d[1] == 16 and not isFree and BagManager.GetItemCountById(v1)>0 then
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.Recruit,tenRecruit.Id,recruitTen)
                elseif state_10 == 0 and d[1] == 16 and not isFree and BagManager.GetItemCountById(v1) <= 0 then
                    UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.Recruit,tenRecruit.Id,recruitTen)
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
    local timeDown = CalculateSecondsNowTo_N_OClock(24)--ActivityGiftManager.GetTaskRemainTime(ActivityTypeDef.FindFairy)
    self.timeUpdate.text = TimeToHMS(timeDown)..GetLanguageStrById(12200)
    self.timer = Timer.New(function()
        if timeDown < 1 then
            self.timer:Stop()
            self.timer = nil
            parent:ClosePanel()
            return
        end
        timeDown = timeDown - 1
        self.timeUpdate.text = TimeToHMS(timeDown)..GetLanguageStrById(12200)
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
    ActivityDetail:OnDestroy()
    RewardPreview:OnDestroy()
    if itemView then
        SubUIManager.Close(itemView)
        itemView = nil
    end
    isJump = false
end

--添加事件监听（用于子类重写）
function TimeLimitedCall:AddListener()

end

--移除事件监听（用于子类重写）
function TimeLimitedCall:RemoveListener()

end

return TimeLimitedCall