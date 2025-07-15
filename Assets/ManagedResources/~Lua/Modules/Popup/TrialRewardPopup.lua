----- 试练副本奖励弹窗 -----
require("Base/BasePanel")
local TrialRewardPopup = Inherit(BasePanel)
local this = TrialRewardPopup
local trialKillConfig=ConfigManager.GetConfig(ConfigName.TrialKillConfig)
local itemList={} --预设容器
local sortingOrder=0

local curRewardType = 1
local ActivityType = nil

local ActInfo = {}
local ActReward = {}
local func
function TrialRewardPopup:InitComponent()
    this.Mask=Util.GetGameObject(this.gameObject,"Mask")
	this.panel=Util.GetGameObject(this.gameObject,"Panel")
    this.backBtn=Util.GetGameObject(this.gameObject,"BackBtn")

    this.scroll=Util.GetGameObject(this.panel,"Scroll")
    this.pre=Util.GetGameObject(this.panel,"Scroll/Pre")
    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scroll.transform,this.pre, nil,
    Vector2.New(this.scroll.transform.rect.width,this.scroll.transform.rect.height),1,1,Vector2.New(0,10))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

function TrialRewardPopup:BindEvent()
    Util.AddClick(this.backBtn,function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
	    Util.AddClick(this.Mask,function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

function TrialRewardPopup:AddListener()
end

function TrialRewardPopup:RemoveListener()
end

function TrialRewardPopup:OnSortingOrderChange()
    sortingOrder = self.sortingOrder
end

function TrialRewardPopup:OnOpen(rewardType,activityType,activityId,_func)
    curRewardType = rewardType
    if rewardType == 1 then
        ActivityType = activityType
        ActInfo = ActivityGiftManager.GetActivityTypeInfo(activityType)--活动数据
        ActReward = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",activityId)
    elseif rewardType == 2 then
        -- body
    end
    if _func then
        func = _func
    end
end

function TrialRewardPopup:OnShow()
    this.RefreshPanel()
end

function TrialRewardPopup:OnClose()
    if func then
        func()
    end
end

function TrialRewardPopup:OnDestroy()
    this.scrollView=nil
    itemList={}
end


--刷新
function this.RefreshPanel()
    local d={}
    if curRewardType == 1 then
        d = ActReward
        this.scrollView:SetData(d,function(index,root)
            this.SetScrollPre2(root,d[index])
        end)
        this.scrollView:SetIndex(1)
    else  
       for _, configInfo in ConfigPairs(trialKillConfig) do
         table.insert(d, configInfo)
       end
       this.scrollView:SetData(d,function(index,root)
          this.SetScrollPre(root,d[index])
       end)
       this.scrollView:SetIndex(1)
   end
end

function this.GetState(missionId)
    for i = 1,#ActInfo.mission do
        if ActInfo.mission[i].missionId == missionId then
            return ActInfo.mission[i].state
        end
    end
    return 0
end

--设置每条数据
function this.SetScrollPre2(root,data)
    local info = Util.GetGameObject(root,"Title/Info"):GetComponent("Text")
    local grid = Util.GetGameObject(root,"Grid")
    local goBtn = Util.GetGameObject(root,"GoBtn")
    local getBtn = Util.GetGameObject(root,"GetBtn")
    local mask = Util.GetGameObject(root,"mask")

    info.text = GetLanguageStrById(data.ContentsShow)
    ResetItemView(root,grid.transform,itemList,#data.Reward,0.55,sortingOrder,false,data.Reward)

    --按钮状态
    local s = this.GetState(data.Id)

    --社稷大典需要根据贡献等级重构state
    if ActivityType == ActivityTypeDef.Celebration then
        local level = DynamicActivityManager.curLevel
        if s == 0 then
            if data.Sort <= level then
                s = 1
            else
                s = 2
            end
        else
            s = 0 
        end
    end

    goBtn:GetComponent("Button").interactable=s~=0
    if s == 0 then
        mask:SetActive(true)
        goBtn:SetActive(false)
        getBtn:SetActive(false)
    elseif s == 1 then
        -- goText.text="领取"
        mask:SetActive(false)
        goBtn:SetActive(false)
        getBtn:SetActive(true)
    elseif s == 2 then
        -- goText.text="前往"
        mask:SetActive(false)
        goBtn:SetActive(true)
        getBtn:SetActive(false)
    end

    Util.AddOnceClick(goBtn,function()
        PopupTipPanel.ShowTipByLanguageId(11482)
    end)
    Util.AddOnceClick(getBtn,function()
        NetManager.GetActivityRewardRequest(data.Id, ActInfo.activityId, function(_drop)
            UIManager.OpenPanel(UIName.RewardItemPopup, _drop, 1,function()
                this.RefreshPanel(false,true)
                CheckRedPointStatus(RedPointType.Celebration)
            end)
        end)
    end)
end
--设置每条数据
function this.SetScrollPre(root,data)
    local info=Util.GetGameObject(root,"Title/Info"):GetComponent("Text")
    local grid=Util.GetGameObject(root,"Grid")
    local goBtn=Util.GetGameObject(root,"GoBtn")
    local getBtn=Util.GetGameObject(root,"GetBtn")
    local mask=Util.GetGameObject(root,"mask")

    info.text=string.format( GetLanguageStrById(11616),data.Count,MapTrialManager.GetKilCount(),data.Count)
    ResetItemView(root,grid.transform,itemList,#data.BoxReward,0.55,sortingOrder,false,data.BoxReward)

    --按钮状态
    local s=MapTrialManager.GetTrialRewardState(data.Id)
    
    
    
    goBtn:GetComponent("Button").interactable=s~=0
    if s==0 then
        -- goText.text=GetLanguageStrById(10350)
        mask:SetActive(true)
        goBtn:SetActive(false)
        getBtn:SetActive(false)
    elseif s==1 then
        -- goText.text=GetLanguageStrById(10022)
        mask:SetActive(false)
        goBtn:SetActive(false)
        getBtn:SetActive(true)
    elseif s==2 then
        -- goText.text=GetLanguageStrById(10023)
        mask:SetActive(false)
        goBtn:SetActive(true)
        getBtn:SetActive(false)
    end

    Util.AddOnceClick(goBtn,function()
        this:ClosePanel()
    end)
    Util.AddOnceClick(getBtn,function()
        NetManager.RequestLevelReward(data.Id, function(msg)
            MapTrialManager.SetTrialRewardInfo(data.Id) --本地记录已领奖励信息
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                mask:SetActive(true)
                getBtn:SetActive(false)
                this.RefreshPanel()
                CheckRedPointStatus(RedPointType.TrialReward)
                CheckRedPointStatus(RedPointType.Trial)

                Game.GlobalEvent:DispatchEvent(GameEvent.TrialMap.UpdateBox)
            end)
        end)
    end)
end


return TrialRewardPopup