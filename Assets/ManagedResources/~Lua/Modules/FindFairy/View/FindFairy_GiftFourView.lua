----- 东海寻仙-寻仙盛典 -----
local this = {}
local sortingOrder
local activeData={}
local itemList={}
--按钮图片
local StateImageName={
    "s_slbz_1anniuongse","s_slbz_1anniuhuangse","s_slbz_1anniuhuise"
}

function this:InitComponent(gameObject)
    this.gameObject = gameObject
    this.panel=Util.GetGameObject(gameObject,"Panel")
    this.rewardPre=Util.GetGameObject(this.panel,"RewardPre")
    this.scrollRoot=Util.GetGameObject(this.panel,"ScrollRoot")
    this.timeText=Util.GetGameObject(this.panel,"TimeText"):GetComponent("Text")
    this.timer = Timer.New()

    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollRoot.transform,
            this.rewardPre,nil,Vector2.New(this.scrollRoot.transform.rect.width,this.scrollRoot.transform.rect.height),
            1,1,Vector2.New(0,4))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

function this:BindEvent()

end

function this:AddListener()

end

function this:RemoveListener()

end

function this:OnShow(_sortingOrder)
    sortingOrder = _sortingOrder

    self:OnShowPanelData()
end

function this:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

function this:OnDestroy()
    this.scrollView=nil
end

--显示面板
function this:OnShowPanelData()
    activeData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FindFairyCeremony)
    self:RemainTimeDown(this.timeText,activeData.endTime - GetTimeStamp())
    if activeData == nil then return end

    local data=FindFairyManager.GetBtnDataState(ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairyCeremony))
    this.scrollView:SetData(data,function(index,root)
        self:SetShow(root,data[index])
    end)
    this.scrollView:SetIndex(1)
end

--显示每条数据
function this:SetShow(root,data)
    local title=Util.GetGameObject(root,"Title"):GetComponent("Text")
    local content=Util.GetGameObject(root,"Content")
    local stateBtn=Util.GetGameObject(root,"StateBtn")
    local stateButton=Util.GetGameObject(root,"StateBtn"):GetComponent("Button")
    local stateImage=Util.GetGameObject(root,"StateBtn"):GetComponent("Image")
    local stateBtnText=Util.GetGameObject(root,"StateBtn/Text"):GetComponent("Text")
    local progress=Util.GetGameObject(root,"Progress"):GetComponent("Text")
    local config = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig,data.missionId)

    title.text=config.ContentsShow
    FindFairyManager.ResetItemView(root,content.transform,itemList,4,0.9,sortingOrder,false,config.Reward)

    progress.text="("..data.value.."/"..config.Values[1][1]..")"
    progress.enabled= data.value<config.Values[1][1]

    if data.value>=config.Values[1][1] then --充够了
        if data.state==0 then
            stateBtnText.text=GetLanguageStrById(10022)
            stateImage.sprite=Util.LoadSprite(StateImageName[1])
            Util.AddOnceClick(stateBtn,function()
                NetManager.GetActivityRewardRequest(data.missionId,ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FindFairyCeremony), function(drop)
                    UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)
                    self:OnShowPanelData()
                end)
            end)
        else
            stateBtnText.text=GetLanguageStrById(10350)
        end
        stateButton.enabled=data.state==0
        Util.SetGray(stateBtn,data.state~=0)
        stateBtn:GetComponent("Button").interactable = data.state==0
    else
        --按钮重新设置属性
        stateButton.enabled=true
        Util.SetGray(stateBtn,false)
        stateBtn:GetComponent("Button").interactable = true
        stateBtnText.text=GetLanguageStrById(10023)
        stateImage.sprite=Util.LoadSprite(StateImageName[2])
        Util.AddOnceClick(stateBtn,function()
            UIManager.OpenPanel(UIName.MainRechargePanel, 1)
        end)
    end
end

--刷新倒计时显示
function this:RemainTimeDown(_timeTextExpert,timeDown)
    if timeDown > 0 then
        _timeTextExpert.enabled=true
        _timeTextExpert.text =   GetLanguageStrById(10028)..self:TimeStampToDateString(timeDown)
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            _timeTextExpert.text =   GetLanguageStrById(10028)..self:TimeStampToDateString(timeDown)
            if timeDown < 0 then
                _timeTextExpert.enabled=false
                this.timer:Stop()
                this.timer = nil
                -- PopupTipPanel.ShowTip("活动已结束！")
                -- require("Modules/FindFairy/FindFairyPanel"):OnShow()
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        _timeTextExpert.enabled=false
    end
end
function this:TimeStampToDateString(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format(GetLanguageStrById(10548),day, hour, minute, sec)
end

return this